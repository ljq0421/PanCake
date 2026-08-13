class_name YoutiaoFryerModel
extends RefCounted

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const DEVICE_ID := &"device.youtiao_fryer"
const AREA_ID := &"area.youtiao"

const STATE_UNOWNED := &"unowned"
const STATE_IDLE := &"idle"
const STATE_LOADED := &"loaded"
const STATE_FRYING := &"frying"
const STATE_READY_SAFE := &"ready_safe"
const STATE_OVERCOOKING := &"overcooking"
const STATE_DRAINING := &"draining"
const STATE_READY_TO_COLLECT := &"ready_to_collect"
const STATE_BURNT := &"burnt"

var owned := false
var tier := 0
var state: StringName = STATE_UNOWNED
var recipe_id: StringName = &""
var quantity := 0
var occupied_slot_indices: Array[int] = []
var cooking_elapsed_seconds := 0.0
var completed_elapsed_seconds := 0.0
var draining_elapsed_seconds := 0.0
var quality := 100.0


func _init(next_tier: int = 0, is_owned: bool = false) -> void:
	if is_owned:
		configure_owned(next_tier)


func configure_owned(next_tier: int) -> Dictionary:
	if CATALOG.device_tier(DEVICE_ID, next_tier).is_empty():
		return _failure(&"invalid_device_tier")
	owned = true
	tier = next_tier
	if state == STATE_UNOWNED:
		state = STATE_IDLE
	return _success({"tier": tier, "capacity": capacity()})


func capacity() -> int:
	return int(_tier_definition().get("capacity", 0)) if owned else 0


func load_recipe(next_recipe_id: StringName, next_quantity: int) -> Dictionary:
	if not owned:
		return _failure(&"equipment_not_owned")
	if state not in [STATE_IDLE, STATE_LOADED]:
		return _failure(&"invalid_equipment_state")
	if next_quantity <= 0:
		return _failure(&"invalid_quantity")
	var recipe := CATALOG.recipe_definition(next_recipe_id)
	if recipe.is_empty() or recipe.get("area_id", &"") != AREA_ID:
		return _failure(&"invalid_recipe")
	if state == STATE_LOADED and recipe_id != next_recipe_id:
		return _failure(&"mixed_recipe")
	if quantity + next_quantity > capacity():
		return _failure(&"capacity_exceeded", {"capacity": capacity(), "loaded_quantity": quantity})
	recipe_id = next_recipe_id
	for slot_index in range(capacity()):
		if occupied_slot_indices.has(slot_index):
			continue
		occupied_slot_indices.append(slot_index)
		if occupied_slot_indices.size() >= quantity + next_quantity:
			break
	occupied_slot_indices.sort()
	quantity = occupied_slot_indices.size()
	state = STATE_LOADED
	return _success({"recipe_id": recipe_id, "loaded_quantity": quantity, "remaining_capacity": capacity() - quantity, "occupied_slot_indices": occupied_slot_indices.duplicate()})


func start() -> Dictionary:
	if not owned:
		return _failure(&"equipment_not_owned")
	if state != STATE_LOADED or quantity <= 0:
		return _failure(&"batch_not_loaded")
	state = STATE_FRYING
	cooking_elapsed_seconds = 0.0
	completed_elapsed_seconds = 0.0
	draining_elapsed_seconds = 0.0
	quality = 100.0
	return _success({"duration_seconds": float(_tier_definition().get("duration_seconds", 0.0)), "quantity": quantity})


func advance_time(delta: float, auto_lift: bool = false) -> void:
	var remaining := maxf(delta, 0.0)
	if not owned or remaining <= 0.0:
		return
	var definition := _tier_definition()
	var duration := float(definition.get("duration_seconds", 0.0))
	var safe_seconds := float(definition.get("safe_seconds", 0.0))
	var decay_seconds := float(definition.get("decay_seconds", 10.0))
	var drain_seconds := float(definition.get("drain_seconds", 2.0))
	if state == STATE_FRYING:
		var until_ready := maxf(duration - cooking_elapsed_seconds, 0.0)
		var applied := minf(remaining, until_ready)
		cooking_elapsed_seconds += applied
		remaining -= applied
		if cooking_elapsed_seconds + 0.000001 >= duration:
			cooking_elapsed_seconds = duration
			state = STATE_READY_SAFE
			completed_elapsed_seconds = 0.0
			if auto_lift:
				lift()
	if state == STATE_READY_SAFE and remaining > 0.0:
		if auto_lift:
			lift()
		else:
			var until_decay := maxf(safe_seconds - completed_elapsed_seconds, 0.0)
			var applied := minf(remaining, until_decay)
			completed_elapsed_seconds += applied
			remaining -= applied
			if completed_elapsed_seconds + 0.000001 >= safe_seconds and remaining > 0.0:
				state = STATE_OVERCOOKING
	if state == STATE_OVERCOOKING and remaining > 0.0:
		var decay_elapsed := maxf(completed_elapsed_seconds - safe_seconds, 0.0)
		var until_burnt := maxf(decay_seconds - decay_elapsed, 0.0)
		var applied := minf(remaining, until_burnt)
		completed_elapsed_seconds += applied
		remaining -= applied
		decay_elapsed = maxf(completed_elapsed_seconds - safe_seconds, 0.0)
		quality = clampf(100.0 - 40.0 * decay_elapsed / maxf(decay_seconds, 0.001), 60.0, 100.0)
		if decay_elapsed + 0.000001 >= decay_seconds:
			state = STATE_BURNT
			quality = 0.0
	if state == STATE_DRAINING and remaining > 0.0:
		var until_collected := maxf(drain_seconds - draining_elapsed_seconds, 0.0)
		var applied := minf(remaining, until_collected)
		draining_elapsed_seconds += applied
		if draining_elapsed_seconds + 0.000001 >= drain_seconds:
			draining_elapsed_seconds = drain_seconds
			state = STATE_READY_TO_COLLECT


func lift() -> Dictionary:
	if state != STATE_READY_SAFE and state != STATE_OVERCOOKING:
		return _failure(&"lift_not_available")
	state = STATE_DRAINING
	draining_elapsed_seconds = 0.0
	return _success({"quality": quality})


func preview_collect(collect_quantity: int = 1) -> Dictionary:
	if state != STATE_READY_TO_COLLECT:
		return _failure(&"product_not_ready")
	if collect_quantity <= 0 or collect_quantity > quantity:
		return _failure(&"invalid_quantity", {"available_quantity": quantity})
	return _success({
		"recipe_id": recipe_id,
		"product_id": CATALOG.recipe_definition(recipe_id).get("product_id", &""),
		"quantity": collect_quantity,
		"quality": quality,
		"grade": _grade_for_quality(quality),
		"temperature_mode": &"room_temperature",
	})


func preview_collect_slot(slot_index: int) -> Dictionary:
	if not occupied_slot_indices.has(slot_index):
		return _failure(&"output_slot_empty", {"source_index": slot_index})
	var result := preview_collect(1)
	if bool(result.get("success", false)):
		result["source_index"] = slot_index
	return result


func collect(collect_quantity: int = 1) -> Dictionary:
	var preview := preview_collect(collect_quantity)
	if not bool(preview.get("success", false)):
		return preview
	for slot_index in occupied_slot_indices.duplicate().slice(0, collect_quantity):
		occupied_slot_indices.erase(slot_index)
	quantity = occupied_slot_indices.size()
	preview["remaining_quantity"] = quantity
	preview["occupied_slot_indices"] = occupied_slot_indices.duplicate()
	if quantity <= 0:
		_reset_idle()
	return preview


func collect_slot(slot_index: int) -> Dictionary:
	var result := preview_collect_slot(slot_index)
	if not bool(result.get("success", false)):
		return result
	occupied_slot_indices.erase(slot_index)
	quantity = occupied_slot_indices.size()
	result["remaining_quantity"] = quantity
	result["occupied_slot_indices"] = occupied_slot_indices.duplicate()
	if quantity <= 0:
		_reset_idle()
	return result


func discard() -> Dictionary:
	if state in [STATE_UNOWNED, STATE_IDLE] or quantity <= 0:
		return _failure(&"discard_not_available")
	var discarded_state := state
	var discarded_recipe := recipe_id
	var discarded_quantity := quantity
	_reset_idle()
	return _success({
		"recipe_id": discarded_recipe,
		"quantity": discarded_quantity,
		"discarded_state": discarded_state,
		"waste_reason": &"burnt_batch" if discarded_state == STATE_BURNT else &"youtiao_batch_discarded",
	})


func discard_slot(slot_index: int) -> Dictionary:
	if state in [STATE_UNOWNED, STATE_IDLE] or not occupied_slot_indices.has(slot_index):
		return _failure(&"discard_not_available", {"source_index": slot_index})
	var discarded_state := state
	var discarded_recipe := recipe_id
	occupied_slot_indices.erase(slot_index)
	quantity = occupied_slot_indices.size()
	var result := _success({
		"recipe_id": discarded_recipe,
		"quantity": 1,
		"source_index": slot_index,
		"remaining_quantity": quantity,
		"occupied_slot_indices": occupied_slot_indices.duplicate(),
		"discarded_state": discarded_state,
		"waste_reason": &"burnt_batch" if discarded_state == STATE_BURNT else &"youtiao_slot_discarded",
	})
	if quantity <= 0:
		_reset_idle()
	return result


func snapshot() -> Dictionary:
	return {
		"device_id": DEVICE_ID,
		"owned": owned,
		"tier": tier,
		"capacity": capacity(),
		"state": state,
		"recipe_id": recipe_id,
		"quantity": quantity,
		"occupied_slot_indices": occupied_slot_indices.duplicate(),
		"cooking_elapsed_seconds": cooking_elapsed_seconds,
		"completed_elapsed_seconds": completed_elapsed_seconds,
		"draining_elapsed_seconds": draining_elapsed_seconds,
		"quality": quality,
	}


func load_snapshot(value: Dictionary) -> Dictionary:
	owned = false
	state = STATE_UNOWNED
	_reset_values()
	if value.is_empty() or not bool(value.get("owned", false)):
		return _success()
	var configured := configure_owned(int(value.get("tier", 0)))
	if not bool(configured.get("success", false)):
		return configured
	var restored_state := StringName(value.get("state", STATE_IDLE))
	if restored_state not in [STATE_IDLE, STATE_LOADED, STATE_FRYING, STATE_READY_SAFE, STATE_OVERCOOKING, STATE_DRAINING, STATE_READY_TO_COLLECT, STATE_BURNT]:
		restored_state = STATE_IDLE
	state = restored_state
	recipe_id = StringName(value.get("recipe_id", &""))
	var restored_quantity := clampi(int(value.get("quantity", 0)), 0, capacity())
	occupied_slot_indices.clear()
	if value.has("occupied_slot_indices"):
		for slot_value in Array(value.get("occupied_slot_indices", [])):
			var slot_index := int(slot_value)
			if slot_index >= 0 and slot_index < capacity() and not occupied_slot_indices.has(slot_index):
				occupied_slot_indices.append(slot_index)
	else:
		for slot_index in range(restored_quantity):
			occupied_slot_indices.append(slot_index)
	occupied_slot_indices.sort()
	quantity = occupied_slot_indices.size()
	cooking_elapsed_seconds = maxf(float(value.get("cooking_elapsed_seconds", 0.0)), 0.0)
	completed_elapsed_seconds = maxf(float(value.get("completed_elapsed_seconds", 0.0)), 0.0)
	draining_elapsed_seconds = maxf(float(value.get("draining_elapsed_seconds", 0.0)), 0.0)
	quality = clampf(float(value.get("quality", 100.0)), 0.0, 100.0)
	if state != STATE_IDLE and (quantity <= 0 or CATALOG.recipe_definition(recipe_id).is_empty()):
		_reset_idle()
	return _success()


func _tier_definition() -> Dictionary:
	return CATALOG.device_tier(DEVICE_ID, tier)


func _reset_idle() -> void:
	state = STATE_IDLE
	_reset_values()


func _reset_values() -> void:
	recipe_id = &""
	quantity = 0
	occupied_slot_indices.clear()
	cooking_elapsed_seconds = 0.0
	completed_elapsed_seconds = 0.0
	draining_elapsed_seconds = 0.0
	quality = 100.0


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
