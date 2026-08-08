class_name FreshSoyMilkMachineModel
extends RefCounted

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const DEVICE_ID := &"device.fresh_soy_milk_machine"
const AREA_ID := &"area.fresh_soy_milk"
const OUTPUT_CAPACITY := 4

const STATE_UNOWNED := &"unowned"
const STATE_IDLE := &"idle"
const STATE_LOADED := &"loaded"
const STATE_WATER_ADDED := &"water_added"
const STATE_GRINDING := &"grinding"
const STATE_READY_SAFE := &"ready_safe"
const STATE_OVERCOOKING := &"overcooking"
const STATE_BLOCKED := &"blocked"
const STATE_SPOILED := &"spoiled"

var owned := false
var tier := 0
var state: StringName = STATE_UNOWNED
var recipe_id: StringName = &""
var quantity := 0
var elapsed_seconds := 0.0
var completed_elapsed_seconds := 0.0
var quality := 100.0
var _output_rack: Array[Dictionary] = [{}, {}, {}, {}]


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
	return _success()


func capacity() -> int:
	return int(_tier_definition().get("capacity", 0)) if owned else 0


func load_recipe(next_recipe_id: StringName, next_quantity: int) -> Dictionary:
	if not owned:
		return _failure(&"device_unowned")
	if state != STATE_IDLE:
		return _failure(&"machine_busy")
	var recipe := CATALOG.recipe_definition(next_recipe_id)
	if StringName(recipe.get("area_id", &"")) != AREA_ID:
		return _failure(&"invalid_recipe")
	if next_quantity <= 0 or next_quantity > capacity():
		return _failure(&"invalid_quantity", {"capacity": capacity()})
	recipe_id = next_recipe_id
	quantity = next_quantity
	elapsed_seconds = 0.0
	completed_elapsed_seconds = 0.0
	quality = 100.0
	state = STATE_LOADED
	return _success({"recipe_id": recipe_id, "quantity": quantity})


func add_water() -> Dictionary:
	if state != STATE_LOADED:
		return _failure(&"water_not_available")
	state = STATE_WATER_ADDED
	return _success()


func start() -> Dictionary:
	if state != STATE_WATER_ADDED:
		return _failure(&"start_not_available")
	state = STATE_GRINDING
	return _success()


func advance_time(delta: float, auto_cup_rack: bool = false) -> void:
	var step := maxf(delta, 0.0)
	if step <= 0.0 or not owned:
		return
	_advance_output_rack(step)
	if state == STATE_BLOCKED and auto_cup_rack:
		state = STATE_READY_SAFE
		_move_completed_batch_to_rack()
		if state == STATE_BLOCKED:
			return
	var tier_definition := _tier_definition()
	if state == STATE_GRINDING:
		elapsed_seconds += step
		if elapsed_seconds >= float(tier_definition.get("duration_seconds", 5.0)):
			state = STATE_READY_SAFE
			completed_elapsed_seconds = 0.0
			if auto_cup_rack:
				_move_completed_batch_to_rack()
	elif state == STATE_READY_SAFE or state == STATE_OVERCOOKING:
		if bool(tier_definition.get("infinite_hold", false)):
			return
		completed_elapsed_seconds += step
		var safe_seconds := float(tier_definition.get("safe_seconds", 5.0))
		var decay_seconds := maxf(float(tier_definition.get("decay_seconds", 10.0)), 0.001)
		if completed_elapsed_seconds > safe_seconds:
			state = STATE_OVERCOOKING
			quality = clampf(100.0 - 40.0 * ((completed_elapsed_seconds - safe_seconds) / decay_seconds), 0.0, 100.0)
			if completed_elapsed_seconds >= safe_seconds + decay_seconds:
				quality = 0.0
				state = STATE_SPOILED
		if auto_cup_rack and state != STATE_SPOILED:
			_move_completed_batch_to_rack()


func preview_collect(quantity_to_collect: int = 1) -> Dictionary:
	if state not in [STATE_READY_SAFE, STATE_OVERCOOKING]:
		return _failure(&"collect_not_available")
	if quantity_to_collect <= 0 or quantity_to_collect > quantity:
		return _failure(&"invalid_quantity")
	return _success(_product_payload(quantity_to_collect, quality))


func collect(quantity_to_collect: int = 1) -> Dictionary:
	var result := preview_collect(quantity_to_collect)
	if not bool(result.get("success", false)):
		return result
	quantity -= quantity_to_collect
	result["remaining_quantity"] = quantity
	if quantity <= 0:
		_reset_idle()
	return result


func collect_output(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= OUTPUT_CAPACITY or _output_rack[slot_index].is_empty():
		return _failure(&"output_slot_empty")
	var cup := _output_rack[slot_index].duplicate(true)
	if StringName(cup.get("state", &"")) == STATE_SPOILED:
		return _failure(&"output_spoiled")
	_output_rack[slot_index] = {}
	if state == STATE_BLOCKED:
		state = STATE_READY_SAFE
		_move_completed_batch_to_rack()
	return _success(_product_payload(1, float(cup.get("quality", 100.0)), StringName(cup.get("recipe_id", &""))))


func discard() -> Dictionary:
	if state != STATE_SPOILED:
		return _failure(&"discard_not_available")
	var result := _success({"recipe_id": recipe_id, "quantity": quantity, "waste_reason": &"soy_spoiled"})
	_reset_idle()
	return result


func discard_output(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= OUTPUT_CAPACITY or _output_rack[slot_index].is_empty():
		return _failure(&"output_slot_empty")
	var cup := _output_rack[slot_index].duplicate(true)
	_output_rack[slot_index] = {}
	if state == STATE_BLOCKED:
		state = STATE_READY_SAFE
		_move_completed_batch_to_rack()
	return _success({"recipe_id": cup.get("recipe_id", &""), "quantity": 1, "waste_reason": &"soy_output_discarded"})


func output_rack_snapshot() -> Array[Dictionary]:
	return _output_rack.duplicate(true)


func snapshot() -> Dictionary:
	return {
		"device_id": DEVICE_ID,
		"owned": owned,
		"tier": tier,
		"capacity": capacity(),
		"state": state,
		"recipe_id": recipe_id,
		"quantity": quantity,
		"elapsed_seconds": elapsed_seconds,
		"completed_elapsed_seconds": completed_elapsed_seconds,
		"quality": quality,
		"seconds_to_loss": _seconds_to_loss(),
		"output_rack": output_rack_snapshot(),
	}


func load_snapshot(value: Dictionary) -> Dictionary:
	owned = false
	tier = 0
	state = STATE_UNOWNED
	_reset_values()
	_output_rack = [{}, {}, {}, {}]
	if value.is_empty() or not bool(value.get("owned", false)):
		return _success()
	var configured := configure_owned(int(value.get("tier", 0)))
	if not bool(configured.get("success", false)):
		return configured
	var restored_state := StringName(value.get("state", STATE_IDLE))
	if restored_state not in [STATE_IDLE, STATE_LOADED, STATE_WATER_ADDED, STATE_GRINDING, STATE_READY_SAFE, STATE_OVERCOOKING, STATE_BLOCKED, STATE_SPOILED]:
		restored_state = STATE_IDLE
	state = restored_state
	recipe_id = StringName(value.get("recipe_id", &""))
	quantity = clampi(int(value.get("quantity", 0)), 0, capacity())
	elapsed_seconds = maxf(float(value.get("elapsed_seconds", 0.0)), 0.0)
	completed_elapsed_seconds = maxf(float(value.get("completed_elapsed_seconds", 0.0)), 0.0)
	quality = clampf(float(value.get("quality", 100.0)), 0.0, 100.0)
	var restored_rack := Array(value.get("output_rack", []))
	for index in range(mini(restored_rack.size(), OUTPUT_CAPACITY)):
		_output_rack[index] = Dictionary(restored_rack[index]).duplicate(true)
	if state != STATE_IDLE and (quantity <= 0 or CATALOG.recipe_definition(recipe_id).is_empty()):
		_reset_idle()
	return _success()


func _move_completed_batch_to_rack() -> void:
	var empty_indices: Array[int] = []
	for index in range(OUTPUT_CAPACITY):
		if _output_rack[index].is_empty():
			empty_indices.append(index)
	if empty_indices.size() < quantity:
		state = STATE_BLOCKED
		return
	for cup_index in range(quantity):
		_output_rack[empty_indices[cup_index]] = {"recipe_id": recipe_id, "quality": quality, "age_seconds": 0.0, "state": STATE_READY_SAFE, "seconds_to_loss": 15.0}
	_reset_idle()


func _advance_output_rack(step: float) -> void:
	for index in range(OUTPUT_CAPACITY):
		var cup := _output_rack[index]
		if cup.is_empty() or StringName(cup.get("state", &"")) == STATE_SPOILED:
			continue
		cup["age_seconds"] = float(cup.get("age_seconds", 0.0)) + step
		var age := float(cup["age_seconds"])
		cup["seconds_to_loss"] = maxf(15.0 - age, 0.0)
		cup["quality"] = clampf(100.0 - 40.0 * maxf(age - 5.0, 0.0) / 10.0, 0.0, 100.0)
		if age >= 15.0:
			cup["state"] = STATE_SPOILED
			cup["quality"] = 0.0
		elif age > 5.0:
			cup["state"] = STATE_OVERCOOKING
		_output_rack[index] = cup


func _product_payload(product_quantity: int, product_quality: float, source_recipe_id: StringName = &"") -> Dictionary:
	var resolved_recipe := recipe_id if source_recipe_id.is_empty() else source_recipe_id
	var recipe := CATALOG.recipe_definition(resolved_recipe)
	return {"recipe_id": resolved_recipe, "product_id": StringName(recipe.get("product_id", &"")), "quantity": product_quantity, "quality": product_quality, "grade": _grade_for_quality(product_quality), "temperature_mode": &"room_temperature"}


func _seconds_to_loss() -> float:
	if state not in [STATE_READY_SAFE, STATE_OVERCOOKING]:
		return 0.0
	if bool(_tier_definition().get("infinite_hold", false)):
		return 999999.0
	return maxf(float(_tier_definition().get("safe_seconds", 5.0)) + float(_tier_definition().get("decay_seconds", 10.0)) - completed_elapsed_seconds, 0.0)


func _tier_definition() -> Dictionary:
	return CATALOG.device_tier(DEVICE_ID, tier)


func _reset_idle() -> void:
	state = STATE_IDLE
	_reset_values()


func _reset_values() -> void:
	recipe_id = &""
	quantity = 0
	elapsed_seconds = 0.0
	completed_elapsed_seconds = 0.0
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
