class_name CustomerPortraitCatalog
extends RefCounted

const DEFAULT_CUSTOMER_ID := &"customer_01"
const NEUTRAL_STATE := &"neutral"
# Keep portrait loading in sync with the playable ordinary-customer pool.
const CUSTOMER_IDS: Array[StringName] = [
	&"customer_01", &"customer_02", &"customer_03", &"customer_04", &"customer_05", &"customer_06",
]
const STATES: Array[StringName] = [
	NEUTRAL_STATE,
	&"impatient",
	&"satisfied",
	&"accepting_bag",
	&"paying_coins",
	&"angry",
]
const REACTION_STATES: Array[StringName] = [
	&"impatient",
	&"satisfied",
	&"accepting_bag",
	&"paying_coins",
	&"angry",
]
const MAX_IN_FLIGHT := 2

var _cache: Dictionary = {}
var _visible_customer_ids: Dictionary = {}
var _queued_paths: Array[String] = []
var _queued_keys: Dictionary = {}
var _pending_by_path: Dictionary = {}
var _failed_keys: Dictionary = {}
var _reaction_prewarm_enabled := false


func resource_path_for(customer_id: StringName, state: StringName) -> String:
	var stable_customer_id := _normalized_customer_id(customer_id)
	return "res://resources/art/cartoon/customer-%d.png" % (CUSTOMER_IDS.find(stable_customer_id) + 1)


func texture_for(customer_id: StringName, state: StringName) -> Texture2D:
	var stable_customer_id := _normalized_customer_id(customer_id)
	var stable_state := state if STATES.has(state) else NEUTRAL_STATE
	var key := _cache_key(stable_customer_id, stable_state)
	if _cache.has(key):
		return _cache[key] as Texture2D
	var cartoon_texture := _cartoon_texture_for(stable_customer_id, stable_state)
	if cartoon_texture != null:
		_cache[key] = cartoon_texture
		return cartoon_texture
	if stable_state != NEUTRAL_STATE:
		_queue_state(stable_customer_id, stable_state)
		return _load_neutral(stable_customer_id)
	return _load_neutral(stable_customer_id)


func set_visible_customers(customer_ids: Array[StringName]) -> void:
	var next_visible := {}
	for customer_id in customer_ids:
		next_visible[_normalized_customer_id(customer_id)] = true
	_visible_customer_ids = next_visible
	_prune_cache()
	_prune_queue()
	if _reaction_prewarm_enabled:
		_queue_visible_reactions()


func enable_reaction_prewarm() -> void:
	if _reaction_prewarm_enabled:
		return
	_reaction_prewarm_enabled = true
	_queue_visible_reactions()


func poll() -> bool:
	var changed := false
	for path_variant in _pending_by_path.keys():
		var path := str(path_variant)
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		var metadata := Dictionary(_pending_by_path[path]).duplicate()
		_pending_by_path.erase(path)
		var key := str(metadata.get("key", ""))
		var customer_id := StringName(metadata.get("customer_id", DEFAULT_CUSTOMER_ID))
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var texture := ResourceLoader.load_threaded_get(path) as Texture2D
			if texture != null and _visible_customer_ids.has(customer_id):
				_cache[key] = texture
				changed = true
		else:
			_failed_keys[key] = true
	_start_queued_requests()
	return changed


func has_cached(customer_id: StringName, state: StringName) -> bool:
	return _cache.has(_cache_key(_normalized_customer_id(customer_id), state if STATES.has(state) else NEUTRAL_STATE))


func cached_resource_count() -> int:
	return _cache.size()


func pending_resource_count() -> int:
	return _queued_paths.size() + _pending_by_path.size()


func finish_pending() -> void:
	_queued_paths.clear()
	_queued_keys.clear()
	for path_variant in _pending_by_path.keys():
		var path := str(path_variant)
		var status := ResourceLoader.load_threaded_get_status(path)
		# Teardown must not synchronously drain an in-flight texture request. In
		# headless/dummy rendering that blocking get can try to initialize a texture
		# after the rendering storage is already shutting down, producing a null
		# texture error. Loaded requests are safe to consume; in-flight requests are
		# process-global and may simply be discarded with this catalog.
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			ResourceLoader.load_threaded_get(path)
	_pending_by_path.clear()


func _load_neutral(customer_id: StringName) -> Texture2D:
	var key := _cache_key(customer_id, NEUTRAL_STATE)
	if _cache.has(key):
		return _cache[key] as Texture2D
	var texture := load(resource_path_for(customer_id, NEUTRAL_STATE)) as Texture2D
	if texture == null and customer_id != DEFAULT_CUSTOMER_ID:
		return _load_neutral(DEFAULT_CUSTOMER_ID)
	if texture != null:
		_cache[key] = texture
	return texture


func _queue_state(customer_id: StringName, state: StringName) -> void:
	var key := _cache_key(customer_id, state)
	if _cache.has(key) or _queued_keys.has(key) or _failed_keys.has(key):
		return
	var cartoon_texture := _cartoon_texture_for(customer_id, state)
	if cartoon_texture != null:
		_cache[key] = cartoon_texture
		return
	var path := resource_path_for(customer_id, state)
	if _pending_by_path.has(path):
		return
	_queued_paths.append(path)
	_queued_keys[key] = {
		"key": key,
		"customer_id": customer_id,
		"state": state,
	}


func _queue_visible_reactions() -> void:
	for customer_id_variant in _visible_customer_ids:
		var customer_id := StringName(customer_id_variant)
		for state in REACTION_STATES:
			_queue_state(customer_id, state)
	_start_queued_requests()


func _start_queued_requests() -> void:
	while _pending_by_path.size() < MAX_IN_FLIGHT and not _queued_paths.is_empty():
		var path: String = _queued_paths.pop_front()
		var metadata := Dictionary(_queued_keys.get(_key_for_path(path), {}))
		if metadata.is_empty():
			metadata = _metadata_for_path(path)
		var key := str(metadata.get("key", ""))
		_queued_keys.erase(key)
		var customer_id := StringName(metadata.get("customer_id", DEFAULT_CUSTOMER_ID))
		if not _visible_customer_ids.has(customer_id):
			continue
		var error := ResourceLoader.load_threaded_request(path, "Texture2D")
		if error == OK:
			_pending_by_path[path] = metadata
		else:
			_failed_keys[key] = true


func _prune_cache() -> void:
	for key_variant in _cache.keys():
		var key := str(key_variant)
		var customer_id := StringName(key.get_slice(":", 0))
		if not _visible_customer_ids.has(customer_id):
			_cache.erase(key)


func _prune_queue() -> void:
	var retained_paths: Array[String] = []
	var retained_keys := {}
	for path in _queued_paths:
		var metadata := _metadata_for_path(path)
		var customer_id := StringName(metadata.get("customer_id", DEFAULT_CUSTOMER_ID))
		if not _visible_customer_ids.has(customer_id):
			continue
		retained_paths.append(path)
		retained_keys[str(metadata.get("key", ""))] = metadata
	_queued_paths = retained_paths
	_queued_keys = retained_keys


func _metadata_for_path(path: String) -> Dictionary:
	for metadata_variant in _queued_keys.values():
		var metadata := Dictionary(metadata_variant)
		var customer_id := StringName(metadata.get("customer_id", DEFAULT_CUSTOMER_ID))
		var state := StringName(metadata.get("state", NEUTRAL_STATE))
		if resource_path_for(customer_id, state) == path:
			return metadata
	return {}


func _key_for_path(path: String) -> String:
	var metadata := _metadata_for_path(path)
	return str(metadata.get("key", ""))


func _normalized_customer_id(customer_id: StringName) -> StringName:
	return customer_id if CUSTOMER_IDS.has(customer_id) else DEFAULT_CUSTOMER_ID


func _cartoon_texture_for(customer_id: StringName, state: StringName) -> Texture2D:
	var atlas := load(resource_path_for(customer_id, state)) as Texture2D
	if atlas == null:
		return null
	var half_size := Vector2(atlas.get_width() / 2.0, atlas.get_height() / 2.0)
	var stable_state := state if STATES.has(state) else NEUTRAL_STATE
	var cell := Vector2i(1, 0)
	if stable_state == &"impatient":
		cell = Vector2i(0, 1)
	elif stable_state == &"angry":
		cell = Vector2i(1, 1)
	elif stable_state in [&"satisfied", &"accepting_bag", &"paying_coins"]:
		cell = Vector2i(0, 0)
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = Rect2(Vector2(cell) * half_size, half_size)
	texture.filter_clip = true
	return texture


func _cache_key(customer_id: StringName, state: StringName) -> String:
	return "%s:%s" % [customer_id, state]
