class_name FryerLaneModel
extends RefCounted

## One independently controlled basket in the combined youtiao/chicken fryer.
## The owning model decides which recipes may enter each lane.

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")

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
var state: StringName = STATE_UNOWNED
var recipe_id: StringName = &""
var quantity := 0
var occupied_slot_indices: Array[int] = []
var cooking_elapsed_seconds := 0.0
var completed_elapsed_seconds := 0.0
var draining_elapsed_seconds := 0.0
var quality := 100.0
var _definition: Dictionary = {}


func configure_owned(definition: Dictionary) -> Dictionary:
	if int(definition.get("capacity", 0)) <= 0:
		return _failure(&"invalid_device_tier")
	owned = true
	_definition = definition.duplicate(true)
	if state == STATE_UNOWNED:
		state = STATE_IDLE
	return _success({"capacity": capacity()})


func configure_unowned() -> void:
	owned = false
	state = STATE_UNOWNED
	_definition.clear()
	_reset_values()


func capacity() -> int:
	return int(_definition.get("capacity", 0)) if owned else 0


func load_recipe(next_recipe_id: StringName, next_quantity: int) -> Dictionary:
	if not owned:
		return _failure(&"equipment_not_owned")
	if state not in [STATE_IDLE, STATE_LOADED]:
		return _failure(&"invalid_equipment_state")
	if next_quantity <= 0:
		return _failure(&"invalid_quantity")
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
	return _success({"duration_seconds": _duration_seconds(), "quantity": quantity})


func advance_time(delta: float, auto_lift: bool = false) -> void:
	var remaining := maxf(delta, 0.0)
	if not owned or remaining <= 0.0:
		return
	var duration := _duration_seconds()
	var safe_seconds := float(_definition.get("safe_seconds", 0.0))
	var decay_seconds := float(_definition.get("decay_seconds", 10.0))
	var drain_seconds := float(_definition.get("drain_seconds", 2.0))
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
	if state not in [STATE_READY_SAFE, STATE_OVERCOOKING]:
		return _failure(&"lift_not_available")
	state = STATE_DRAINING
	draining_elapsed_seconds = 0.0
	return _success({"quality": quality})


func preview_collect(collect_quantity: int = 1) -> Dictionary:
	if state != STATE_READY_TO_COLLECT:
		return _failure(&"product_not_ready")
	if collect_quantity <= 0 or collect_quantity > quantity:
		return _failure(&"invalid_quantity", {"available_quantity": quantity})
	return _success({"recipe_id": recipe_id, "product_id": CATALOG.recipe_definition(recipe_id).get("product_id", &""), "quantity": collect_quantity, "quality": quality, "grade": _grade_for_quality(quality), "temperature_mode": &"room_temperature"})


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
	var result := _success({"recipe_id": recipe_id, "quantity": quantity, "discarded_state": state, "waste_reason": &"burnt_batch" if state == STATE_BURNT else &"fryer_batch_discarded"})
	_reset_idle()
	return result


func discard_slot(slot_index: int) -> Dictionary:
	if state in [STATE_UNOWNED, STATE_IDLE] or not occupied_slot_indices.has(slot_index):
		return _failure(&"discard_not_available", {"source_index": slot_index})
	var result := _success({"recipe_id": recipe_id, "quantity": 1, "source_index": slot_index, "discarded_state": state, "waste_reason": &"burnt_batch" if state == STATE_BURNT else &"fryer_slot_discarded"})
	occupied_slot_indices.erase(slot_index)
	quantity = occupied_slot_indices.size()
	result["remaining_quantity"] = quantity
	result["occupied_slot_indices"] = occupied_slot_indices.duplicate()
	if quantity <= 0:
		_reset_idle()
	return result


func snapshot() -> Dictionary:
	return {"owned": owned, "capacity": capacity(), "state": state, "recipe_id": recipe_id, "quantity": quantity, "occupied_slot_indices": occupied_slot_indices.duplicate(), "cooking_elapsed_seconds": cooking_elapsed_seconds, "completed_elapsed_seconds": completed_elapsed_seconds, "draining_elapsed_seconds": draining_elapsed_seconds, "quality": quality}


func load_snapshot(value: Dictionary) -> Dictionary:
	_reset_values()
	if not owned or value.is_empty() or not bool(value.get("owned", true)):
		state = STATE_IDLE if owned else STATE_UNOWNED
		return _success()
	var restored_state := StringName(value.get("state", STATE_IDLE))
	if restored_state not in [STATE_IDLE, STATE_LOADED, STATE_FRYING, STATE_READY_SAFE, STATE_OVERCOOKING, STATE_DRAINING, STATE_READY_TO_COLLECT, STATE_BURNT]:
		restored_state = STATE_IDLE
	state = restored_state
	recipe_id = StringName(value.get("recipe_id", &""))
	var restored_quantity := clampi(int(value.get("quantity", 0)), 0, capacity())
	for slot_value in Array(value.get("occupied_slot_indices", [])):
		var slot_index := int(slot_value)
		if slot_index >= 0 and slot_index < capacity() and not occupied_slot_indices.has(slot_index):
			occupied_slot_indices.append(slot_index)
	if occupied_slot_indices.is_empty():
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


func _duration_seconds() -> float:
	return float(CATALOG.recipe_definition(recipe_id).get("duration_seconds", _definition.get("duration_seconds", 0.0)))


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
