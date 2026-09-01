class_name PackagedDrinkStation
extends Control

signal status_message(message: String)
signal audio_cue_requested(cue: StringName)

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const EMPTY_JUICE_TRAY_TEXTURE := preload("res://resources/art/workstation/containers/p1/container-l-empty-p1-v2-transparent.png")
const JUICE_DRAG_PREVIEW_TEXTURE := preload("res://resources/art/products/orange_juice/boxed_orange_juice_v1.png")
const CONTAINER_TREATMENT := preload("res://resources/materials/workbench_container_treatment.tres")
const MAX_REPRESENTATIVE_ITEMS := 5

var _lock_cover: Button
var _sources: Array[ProductDragSource] = []
var _representatives: Dictionary = {}
var _count_badges: Dictionary = {}
var _refresh_elapsed := 0.0


func _ready() -> void:
	resized.connect(_sync_surface_layout)
	_build_surface()
	_sync_surface_layout()
	refresh_from_session()


func _process(delta: float) -> void:
	_refresh_elapsed += maxf(delta, 0.0)
	if _refresh_elapsed >= 0.10:
		_refresh_elapsed = 0.0
		refresh_from_session()


func product_sources() -> Array[ProductDragSource]:
	return _sources.duplicate()


func refresh_from_session() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return
	var progression := Dictionary(session.call("five_area_progression_snapshot"))
	var area_unlocked := Array(progression.get("unlocked_area_ids", [])).has("area.packaged_drink")
	var unlocked_products := Array(progression.get("unlocked_product_ids", []))
	var inventory := Dictionary(session.call("inventory_snapshot"))
	_lock_cover.visible = not area_unlocked
	_lock_cover.disabled = area_unlocked
	var product_ids := _area_product_ids()
	for index in range(_sources.size()):
		var source := _sources[index]
		var product_id := product_ids[index] if index < product_ids.size() else &""
		var product := CATALOG.product_definition(product_id)
		var recipe := CATALOG.recipe_definition(StringName(product.get("recipe_id", &"")))
		var stock_ids := Array(recipe.get("stock_ids", []))
		var stock_id := StringName(stock_ids[0]) if not stock_ids.is_empty() else &""
		var count := maxi(int(inventory.get(str(stock_id), 0)), 0)
		var capacity := int(Dictionary(session.call("five_area_restock_status", stock_id)).get("capacity", 6)) if not stock_id.is_empty() else 6
		var product_unlocked := area_unlocked and _id_in(unlocked_products, product_id)
		source.visible = product_unlocked
		source.configure({"source_kind": &"packaged_drink_inventory", "source_index": index, "stock_id": stock_id, "product_id": product_id}, EMPTY_JUICE_TRAY_TEXTURE, product_unlocked, _lane_hint(product, count, capacity, product_unlocked))
		source.set_drag_preview_texture(JUICE_DRAG_PREVIEW_TEXTURE)
		source.set_drag_preview_text("")
		source.set_drag_preview_size(Vector2(96.0, 96.0))
		source.set_drag_available(product_unlocked and count > 0)
		_refresh_representative_overlay(source, count, capacity, product_unlocked)


func _build_surface() -> void:
	for index in range(_area_product_ids().size()):
		var source := ProductDragSource.new()
		source.name = "DrinkLane%02d" % (index + 1)
		source.position = Vector2.ZERO
		source.size = size
		source.material = CONTAINER_TREATMENT
		source.ignore_texture_size = true
		source.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		source.set_meta(&"workbench_container_size_class", "L")
		source.hold_enabled = true
		source.hold_threshold_seconds = 0.20
		source.cancel_pending_on_mouse_exit = false
		source.hold_requested.connect(_on_lane_hold_requested)
		source.hold_advanced.connect(_on_lane_hold_advanced)
		source.drag_started.connect(_on_lane_drag_started)
		add_child(source)
		_sources.append(source)
		_build_representative_overlay(source)
	_lock_cover = Button.new()
	_lock_cover.position = Vector2(10, 42)
	_lock_cover.size = Vector2(size.x - 20, size.y - 50)
	_lock_cover.text = "成品饮品区尚未解锁"
	_lock_cover.tooltip_text = "完成豆浆教学并获得 4 单合格豆浆后，可在成长工坊购买"
	_lock_cover.add_theme_font_size_override("font_size", 18)
	_lock_cover.pressed.connect(_on_lock_cover_pressed)
	add_child(_lock_cover)


func _sync_surface_layout() -> void:
	for source in _sources:
		source.position = Vector2.ZERO
		source.size = size
		_layout_representative_overlay(source)
	if _lock_cover != null:
		_lock_cover.position = Vector2(10.0, 42.0)
		_lock_cover.size = Vector2(maxf(size.x - 20.0, 1.0), maxf(size.y - 50.0, 1.0))


func _area_product_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for raw_product_id in CATALOG.PRODUCT_DEFINITIONS:
		var product_id := StringName(raw_product_id)
		if StringName(CATALOG.product_definition(product_id).get("area_id", &"")) == &"area.packaged_drink":
			ids.append(product_id)
	ids.sort()
	return ids


func _on_lane_hold_requested(source_ref: Dictionary) -> void:
	var source := _source_for_ref(source_ref)
	var session := get_node_or_null("/root/GameSession")
	if source == null or session == null:
		return
	var status := Dictionary(session.call("five_area_restock_status", StringName(source_ref.get("stock_id", &""))))
	if bool(status.get("success", false)) and int(status.get("current_stock", 0)) < int(status.get("capacity", 0)) and int(status.get("coins", 0)) >= int(status.get("unit_cost", 0)):
		source.accept_hold()
		source.set_hold_progress(float(status.get("container_fill_ratio", 0.0)))
		status_message.emit("持续长按补充果汁；每瓶消耗 1 金币")
		return
	source.reject_hold()
	status_message.emit("果汁无法补货：库存已满或金币不足")


func _on_lane_hold_advanced(source_ref: Dictionary, delta: float) -> void:
	var source := _source_for_ref(source_ref)
	var session := get_node_or_null("/root/GameSession")
	if source == null or session == null:
		return
	var result := Dictionary(session.call("advance_five_area_restock_hold", StringName(source_ref.get("stock_id", &"")), delta))
	source.set_hold_progress(float(result.get("container_fill_ratio", 0.0)))
	if int(result.get("completed_units", 0)) > 0:
		audio_cue_requested.emit(&"drink_restock")
		status_message.emit("果汁补货 +%d" % int(result.get("completed_units", 0)))
	if bool(result.get("auto_stopped", false)) or not bool(result.get("success", false)):
		source.reject_hold()
	refresh_from_session()


func _on_lane_drag_started(_source_ref: Dictionary) -> void:
	audio_cue_requested.emit(&"drink_pickup")


func _on_lock_cover_pressed() -> void:
	var session := get_node_or_null("/root/GameSession")
	status_message.emit(str(session.call("growth_missing_requirements", &"growth.area.packaged_drink")) if session != null and session.has_method("growth_missing_requirements") else "成品饮品区尚未解锁")


func _source_for_ref(source_ref: Dictionary) -> ProductDragSource:
	var index := int(source_ref.get("source_index", -1))
	return _sources[index] if index >= 0 and index < _sources.size() else null


static func _id_in(values: Array, expected: StringName) -> bool:
	return values.has(expected) or values.has(str(expected))


func _build_representative_overlay(source: ProductDragSource) -> void:
	var visuals: Array[TextureRect] = []
	for item_index in MAX_REPRESENTATIVE_ITEMS:
		var visual := TextureRect.new()
		visual.name = "Representative%02d" % (item_index + 1)
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual.texture = JUICE_DRAG_PREVIEW_TEXTURE
		visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		source.add_child(visual)
		visuals.append(visual)
	_representatives[source.get_instance_id()] = visuals
	var badge := Label.new()
	badge.name = "CountBadge"
	badge.z_index = 20
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override(&"font_size", 22)
	badge.add_theme_color_override(&"font_outline_color", Color(0.16, 0.055, 0.01, 0.98))
	badge.add_theme_constant_override(&"outline_size", 5)
	source.add_child(badge)
	_count_badges[source.get_instance_id()] = badge
	_layout_representative_overlay(source)


func _layout_representative_overlay(source: ProductDragSource) -> void:
	var visuals := Array(_representatives.get(source.get_instance_id(), []))
	var item_size := Vector2(62.0, 96.0)
	var spacing := 48.0
	var row_width := item_size.x + spacing * maxf(visuals.size() - 1, 0)
	var origin := Vector2((source.size.x - row_width) * 0.5, maxf(source.size.y - 132.0, 20.0))
	for item_index in visuals.size():
		var visual := visuals[item_index] as TextureRect
		visual.position = origin + Vector2(item_index * spacing, 0.0)
		visual.size = item_size
	var badge := _count_badges.get(source.get_instance_id()) as Label
	if badge != null:
		badge.position = Vector2(maxf(source.size.x - 116.0, 0.0), 18.0)
		badge.size = Vector2(100.0, 40.0)


func _refresh_representative_overlay(source: ProductDragSource, count: int, capacity: int, unlocked: bool) -> void:
	var visuals := Array(_representatives.get(source.get_instance_id(), []))
	var visible_count := 0
	if unlocked and count > 0:
		visible_count = 2 if count <= 2 else 4 if count < capacity else MAX_REPRESENTATIVE_ITEMS
	for item_index in visuals.size():
		(visuals[item_index] as TextureRect).visible = item_index < visible_count
	var badge := _count_badges.get(source.get_instance_id()) as Label
	if badge == null:
		return
	badge.visible = unlocked
	badge.text = "缺货 0" if count <= 0 else "×%d" % count
	badge.add_theme_color_override(&"font_color", Color("ff8f78") if count <= 0 else Color("ffd06a") if count <= 2 else Color("fff1bd"))
	badge.tooltip_text = "库存 %d/%d" % [count, capacity]


static func _lane_hint(product: Dictionary, count: int, capacity: int, unlocked: bool) -> String:
	if not unlocked:
		return "该饮品尚未解锁"
	if count <= 0:
		return "%s已售罄：长按补货" % str(product.get("label", "饮品"))
	if count >= capacity:
		return "%s库存充足：拖到顾客订单交付" % str(product.get("label", "饮品"))
	return "%s：拖动交付；长按补货（%d/%d）" % [str(product.get("label", "饮品")), count, capacity]
