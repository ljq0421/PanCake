class_name SteamerLayersModel
extends RefCounted

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const DEVICE_ID := &"device.steamer"
const AREA_ID := &"area.steamer"
const MAX_LAYERS := 4

const STATE_LOCKED := &"locked"
const STATE_EMPTY := &"empty"
const STATE_LOADED := &"loaded"
const STATE_STEAMING := &"steaming"
const STATE_READY_SAFE := &"ready_safe"
const STATE_OVERCOOKING := &"overcooking"
const STATE_SPOILED := &"spoiled"

var owned := false
var tier := 0
var _layers: Array[Dictionary] = []


func _init(next_tier: int = 0, is_owned: bool = false) -> void:
	_reset_layers()
	if is_owned:
		configure_owned(next_tier)


func configure_owned(next_tier: int) -> Dictionary:
	if CATALOG.device_tier(DEVICE_ID, next_tier).is_empty():
		return _failure(&"invalid_device_tier")
	owned = true
	tier = next_tier
	_refresh_layer_locks()
	return _success()


func layer_capacity() -> int:
	return int(_tier_definition().get("layers", 0)) if owned else 0


func load_layer(layer_index: int, recipe_id: StringName, quantity: int = 1) -> Dictionary:
	var validation := _validate_layer(layer_index)
	if not bool(validation.get("success", false)):
		return validation
	var layer := _layers[layer_index]
	if StringName(layer.get("state", &"")) != STATE_EMPTY:
		return _failure(&"layer_busy")
	var recipe := CATALOG.recipe_definition(recipe_id)
	if StringName(recipe.get("area_id", &"")) != AREA_ID:
		return _failure(&"invalid_recipe")
	if quantity <= 0:
		return _failure(&"invalid_quantity")
	layer = _empty_layer(STATE_LOADED, layer_index)
	layer["recipe_id"] = recipe_id
	layer["quantity"] = quantity
	layer["duration_seconds"] = float(recipe.get("duration_seconds", 10.0)) * float(_tier_definition().get("duration_multiplier", 1.0))
	_layers[layer_index] = layer
	return _success({"layer": layer.duplicate(true)})


func start_layer(layer_index: int) -> Dictionary:
	var validation := _validate_layer(layer_index)
	if not bool(validation.get("success", false)):
		return validation
	var layer := _layers[layer_index]
	if StringName(layer.get("state", &"")) != STATE_LOADED:
		return _failure(&"start_not_available")
	layer["state"] = STATE_STEAMING
	_layers[layer_index] = layer
	return _success()


func advance_time(delta: float) -> void:
	var step := maxf(delta, 0.0)
	if step <= 0.0 or not owned:
		return
	var tier_definition := _tier_definition()
	for layer_index in range(layer_capacity()):
		var layer := _layers[layer_index]
		var state := StringName(layer.get("state", &""))
		if state == STATE_STEAMING:
			layer["elapsed_seconds"] = float(layer.get("elapsed_seconds", 0.0)) + step
			if float(layer["elapsed_seconds"]) >= float(layer.get("duration_seconds", 10.0)):
				layer["state"] = STATE_READY_SAFE
				layer["completed_elapsed_seconds"] = 0.0
		elif state == STATE_READY_SAFE or state == STATE_OVERCOOKING:
			if bool(tier_definition.get("infinite_hold", false)):
				_layers[layer_index] = layer
				continue
			layer["completed_elapsed_seconds"] = float(layer.get("completed_elapsed_seconds", 0.0)) + step
			var safe_seconds := float(tier_definition.get("safe_seconds", 5.0))
			var decay_seconds := maxf(float(tier_definition.get("decay_seconds", 10.0)), 0.001)
			if float(layer["completed_elapsed_seconds"]) > safe_seconds:
				layer["state"] = STATE_OVERCOOKING
				layer["quality"] = clampf(100.0 - 40.0 * ((float(layer["completed_elapsed_seconds"]) - safe_seconds) / decay_seconds), 0.0, 100.0)
				if float(layer["completed_elapsed_seconds"]) >= safe_seconds + decay_seconds:
					layer["state"] = STATE_SPOILED
					layer["quality"] = 0.0
		_layers[layer_index] = layer


func preview_collect(layer_index: int) -> Dictionary:
	var validation := _validate_layer(layer_index)
	if not bool(validation.get("success", false)):
		return validation
	var layer := _layers[layer_index]
	if StringName(layer.get("state", &"")) not in [STATE_READY_SAFE, STATE_OVERCOOKING]:
		return _failure(&"collect_not_available")
	var recipe := CATALOG.recipe_definition(StringName(layer.get("recipe_id", &"")))
	return _success({"layer_index": layer_index, "recipe_id": layer.get("recipe_id", &""), "product_id": recipe.get("product_id", &""), "quantity": int(layer.get("quantity", 1)), "quality": float(layer.get("quality", 100.0)), "grade": _grade_for_quality(float(layer.get("quality", 100.0))), "temperature_mode": &"room_temperature"})


func collect(layer_index: int) -> Dictionary:
	var result := preview_collect(layer_index)
	if not bool(result.get("success", false)):
		return result
	_layers[layer_index] = _empty_layer(STATE_EMPTY, layer_index)
	return result


func discard(layer_index: int) -> Dictionary:
	var validation := _validate_layer(layer_index)
	if not bool(validation.get("success", false)):
		return validation
	var layer := _layers[layer_index]
	if StringName(layer.get("state", &"")) == STATE_EMPTY:
		return _failure(&"discard_not_available")
	var result := _success({"layer_index": layer_index, "recipe_id": layer.get("recipe_id", &""), "quantity": int(layer.get("quantity", 0)), "waste_reason": &"steamer_discarded"})
	_layers[layer_index] = _empty_layer(STATE_EMPTY, layer_index)
	return result


func layer_snapshot(layer_index: int) -> Dictionary:
	if layer_index < 0 or layer_index >= MAX_LAYERS:
		return {}
	var layer := _layers[layer_index].duplicate(true)
	var state := StringName(layer.get("state", &""))
	if state in [STATE_READY_SAFE, STATE_OVERCOOKING]:
		if bool(_tier_definition().get("infinite_hold", false)):
			layer["seconds_to_loss"] = 999999.0
		else:
			layer["seconds_to_loss"] = maxf(float(_tier_definition().get("safe_seconds", 5.0)) + float(_tier_definition().get("decay_seconds", 10.0)) - float(layer.get("completed_elapsed_seconds", 0.0)), 0.0)
	else:
		layer["seconds_to_loss"] = 0.0
	return layer


func snapshot() -> Dictionary:
	var layers: Array[Dictionary] = []
	for layer_index in range(MAX_LAYERS):
		layers.append(layer_snapshot(layer_index))
	return {"device_id": DEVICE_ID, "owned": owned, "tier": tier, "layer_capacity": layer_capacity(), "layers": layers}


func load_snapshot(value: Dictionary) -> Dictionary:
	owned = false
	tier = 0
	_reset_layers()
	if value.is_empty() or not bool(value.get("owned", false)):
		return _success()
	var configured := configure_owned(int(value.get("tier", 0)))
	if not bool(configured.get("success", false)):
		return configured
	var restored_layers := Array(value.get("layers", []))
	for layer_index in range(mini(restored_layers.size(), MAX_LAYERS)):
		if layer_index >= layer_capacity():
			break
		var source := Dictionary(restored_layers[layer_index])
		var state := StringName(source.get("state", STATE_EMPTY))
		if state not in [STATE_EMPTY, STATE_LOADED, STATE_STEAMING, STATE_READY_SAFE, STATE_OVERCOOKING, STATE_SPOILED]:
			state = STATE_EMPTY
		var layer := _empty_layer(state, layer_index)
		layer["recipe_id"] = StringName(source.get("recipe_id", &""))
		layer["quantity"] = maxi(int(source.get("quantity", 0)), 0)
		layer["duration_seconds"] = maxf(float(source.get("duration_seconds", 0.0)), 0.0)
		layer["elapsed_seconds"] = maxf(float(source.get("elapsed_seconds", 0.0)), 0.0)
		layer["completed_elapsed_seconds"] = maxf(float(source.get("completed_elapsed_seconds", 0.0)), 0.0)
		layer["quality"] = clampf(float(source.get("quality", 100.0)), 0.0, 100.0)
		if state != STATE_EMPTY and (layer["quantity"] <= 0 or CATALOG.recipe_definition(layer["recipe_id"]).is_empty()):
			layer = _empty_layer(STATE_EMPTY, layer_index)
		_layers[layer_index] = layer
	return _success()


func _validate_layer(layer_index: int) -> Dictionary:
	if not owned:
		return _failure(&"device_unowned")
	if layer_index < 0 or layer_index >= layer_capacity():
		return _failure(&"layer_locked", {"layer_capacity": layer_capacity()})
	return _success()


func _tier_definition() -> Dictionary:
	return CATALOG.device_tier(DEVICE_ID, tier)


func _reset_layers() -> void:
	_layers.clear()
	for layer_index in range(MAX_LAYERS):
		_layers.append(_empty_layer(STATE_LOCKED, layer_index))


func _refresh_layer_locks() -> void:
	for layer_index in range(MAX_LAYERS):
		var unlocked := layer_index < layer_capacity()
		var layer := _layers[layer_index]
		if unlocked and StringName(layer.get("state", &"")) == STATE_LOCKED:
			_layers[layer_index] = _empty_layer(STATE_EMPTY, layer_index)
		elif not unlocked:
			_layers[layer_index] = _empty_layer(STATE_LOCKED, layer_index)


static func _empty_layer(state: StringName, layer_index: int) -> Dictionary:
	return {"layer_index": layer_index, "state": state, "recipe_id": &"", "quantity": 0, "duration_seconds": 0.0, "elapsed_seconds": 0.0, "completed_elapsed_seconds": 0.0, "quality": 100.0}


static func _grade_for_quality(value: float) -> StringName:
	if value >= 90.0:
		return &"A"
	if value >= 75.0:
		return &"B"
	if value >= 60.0:
		return &"C"
	return &"waste"


static func _success(extra: Dictionary = {}) -> Dictionary:
	var result := {"success": true, "reason": &""}
	result.merge(extra, true)
	return result


static func _failure(reason: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"success": false, "reason": reason}
	result.merge(extra, true)
	return result
