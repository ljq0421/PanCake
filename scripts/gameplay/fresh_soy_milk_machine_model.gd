class_name FreshSoyMilkMachineModel
extends RefCounted

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const DEVICE_ID := &"device.fresh_soy_milk_machine"
const AREA_ID := &"area.fresh_soy_milk"
const OUTPUT_CAPACITY := 4
const WATER_UNITS_PER_SECOND := 50.0

const YELLOW_STOCK := &"stock.fresh_soy_milk.yellow_bean"
const BLACK_STOCK := &"stock.fresh_soy_milk.black_bean"
const RED_STOCK := &"stock.fresh_soy_milk.red_bean"
const BEAN_STOCK_IDS: Array[StringName] = [YELLOW_STOCK, BLACK_STOCK, RED_STOCK]

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
var ingredient_counts: Dictionary = {}
var water_filling := false
var water_value := 0.0
var water_grade: StringName = &""
var quality_multiplier := 1.0
var elapsed_seconds := 0.0
var completed_elapsed_seconds := 0.0
var quality := 100.0
var manual_cup_ready := false # v4 snapshot compatibility; cups are now automatic.
var water_guide_enabled := false
var quality_max_enabled := false
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


func configure_upgrades(has_water_guide: bool, has_quality_max: bool) -> void:
	water_guide_enabled = has_water_guide
	quality_max_enabled = has_quality_max


func capacity() -> int:
	return int(_tier_definition().get("capacity", 0)) if owned else 0


func add_ingredient(stock_id: StringName) -> Dictionary:
	if not owned:
		return _failure(&"device_unowned")
	if state not in [STATE_IDLE, STATE_LOADED] or water_filling:
		return _failure(&"hopper_locked")
	if not BEAN_STOCK_IDS.has(stock_id):
		return _failure(&"invalid_soy_ingredient", {"stock_id": stock_id})
	var next_count := int(ingredient_counts.get(stock_id, 0)) + 1
	if next_count > capacity():
		return _failure(&"batch_capacity_reached", {"capacity": capacity()})
	ingredient_counts[stock_id] = next_count
	state = STATE_LOADED
	_resolve_batch()
	return _success({
		"stock_id": stock_id,
		"ingredient_counts": ingredient_counts.duplicate(true),
		"recipe_id": recipe_id,
		"quantity": quantity,
		"batch_complete": not recipe_id.is_empty(),
	})


func load_recipe(next_recipe_id: StringName, next_quantity: int) -> Dictionary:
	# Compatibility entry point for simple recipes. Multigrain must be composed
	# through add_ingredient so its actual ingredient_ids are never fabricated.
	if state != STATE_IDLE:
		return _failure(&"machine_busy")
	var recipe := CATALOG.recipe_definition(next_recipe_id)
	var stocks := Array(recipe.get("stock_ids", []))
	if StringName(recipe.get("area_id", &"")) != AREA_ID:
		return _failure(&"invalid_recipe")
	if stocks.size() != 1:
		return _failure(&"multigrain_composition_required")
	if next_quantity <= 0 or next_quantity > capacity():
		return _failure(&"invalid_quantity", {"capacity": capacity()})
	ingredient_counts[StringName(stocks[0])] = next_quantity
	state = STATE_LOADED
	_resolve_batch()
	return _success({"recipe_id": recipe_id, "quantity": quantity})


func clear_hopper() -> Dictionary:
	if state != STATE_LOADED or water_filling or ingredient_counts.is_empty():
		return _failure(&"clear_hopper_not_available")
	var cleared := ingredient_counts.duplicate(true)
	var units := 0
	for count in cleared.values():
		units += int(count)
	_reset_idle()
	return _success({"ingredient_counts": cleared, "quantity": units, "waste_reason": &"soy_hopper_cleared"})


func start_water() -> Dictionary:
	if state != STATE_LOADED or water_filling or recipe_id.is_empty() or quantity <= 0:
		return _failure(&"water_not_available")
	if quality_max_enabled:
		_apply_water_result(52.5)
		return _success({"water_value": water_value, "grade": water_grade, "quality_multiplier": quality_multiplier, "skipped": true})
	water_filling = true
	water_value = 0.0
	return _success({"water_value": water_value})


func stop_water() -> Dictionary:
	if state != STATE_LOADED or not water_filling:
		return _failure(&"water_stop_not_available")
	water_filling = false
	_apply_water_result(water_value)
	return _success({"water_value": water_value, "grade": water_grade, "quality_multiplier": quality_multiplier})


func add_water() -> Dictionary:
	# Retained for tutorial/save adapters. A single action means stopping at the
	# center of the green band, not bypassing the quality system.
	if state != STATE_LOADED or water_filling or recipe_id.is_empty():
		return _failure(&"water_not_available")
	_apply_water_result(52.5)
	return _success({"water_value": water_value, "grade": water_grade, "quality_multiplier": quality_multiplier})


func start() -> Dictionary:
	if state == STATE_LOADED and quality_max_enabled and not water_filling:
		_apply_water_result(52.5)
	if state != STATE_WATER_ADDED:
		return _failure(&"start_not_available")
	state = STATE_GRINDING
	return _success({"duration_seconds": production_duration_seconds()})


func production_duration_seconds() -> float:
	var base := 5.0
	if recipe_id in [&"recipe.fresh_soy_milk.black_bean", &"recipe.fresh_soy_milk.red_bean"]:
		base = 6.0
	elif recipe_id == &"recipe.fresh_soy_milk.multigrain":
		base = 7.0
	return maxf(base - float(tier), 1.0)


func advance_time(delta: float, auto_cup_rack: bool = false) -> void:
	var step := maxf(delta, 0.0)
	if step <= 0.0 or not owned:
		return
	_advance_output_rack(step)
	if state == STATE_LOADED and water_filling:
		water_value = minf(water_value + step * WATER_UNITS_PER_SECOND, 100.0)
		if water_value >= 100.0:
			water_filling = false
			_apply_water_result(100.0)
		return
	if state == STATE_BLOCKED and auto_cup_rack:
		state = STATE_READY_SAFE
		_move_completed_batch_to_rack()
		if state == STATE_BLOCKED:
			return
	var remaining := step
	if state == STATE_GRINDING:
		var duration := production_duration_seconds()
		var applied := minf(remaining, maxf(duration - elapsed_seconds, 0.0))
		elapsed_seconds += applied
		remaining -= applied
		if elapsed_seconds + 0.000001 >= duration:
			elapsed_seconds = duration
			state = STATE_READY_SAFE
			completed_elapsed_seconds = 0.0
			manual_cup_ready = false
			if auto_cup_rack:
				_move_completed_batch_to_rack()
	if remaining > 0.0 and state in [STATE_READY_SAFE, STATE_OVERCOOKING]:
		if bool(_tier_definition().get("infinite_hold", false)):
			return
		completed_elapsed_seconds += remaining
		var safe_seconds := float(_tier_definition().get("safe_seconds", 5.0))
		var decay_seconds := maxf(float(_tier_definition().get("decay_seconds", 10.0)), 0.001)
		if completed_elapsed_seconds > safe_seconds:
			state = STATE_OVERCOOKING
			quality = clampf(_quality_for_water_grade(water_grade) - 40.0 * ((completed_elapsed_seconds - safe_seconds) / decay_seconds), 0.0, 100.0)
			if completed_elapsed_seconds >= safe_seconds + decay_seconds:
				quality = 0.0
				state = STATE_SPOILED
		if auto_cup_rack and state != STATE_SPOILED:
			_move_completed_batch_to_rack()


func preview_collect(quantity_to_collect: int = 1) -> Dictionary:
	if state not in [STATE_READY_SAFE, STATE_OVERCOOKING]:
		return _failure(&"collect_not_available")
	if quantity_to_collect != 1 or quantity_to_collect > quantity:
		return _failure(&"invalid_quantity")
	return _success(_product_payload(quantity_to_collect, quality))


func collect(quantity_to_collect: int = 1) -> Dictionary:
	var result := preview_collect(quantity_to_collect)
	if not bool(result.get("success", false)):
		return result
	quantity -= quantity_to_collect
	for stock_id in ingredient_counts.keys():
		ingredient_counts[stock_id] = maxi(int(ingredient_counts[stock_id]) - quantity_to_collect, 0)
	result["remaining_quantity"] = quantity
	if quantity <= 0:
		_reset_idle()
	return result


func fill_manual_cup() -> Dictionary:
	return _failure(&"manual_cup_removed")


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
	return _success(_product_payload_from_cup(cup))


func discard() -> Dictionary:
	if state != STATE_SPOILED:
		return _failure(&"discard_not_available")
	var result := _success({"recipe_id": recipe_id, "quantity": quantity, "ingredient_counts": ingredient_counts.duplicate(true), "waste_reason": &"soy_spoiled"})
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
	return _success({"recipe_id": cup.get("recipe_id", &""), "ingredient_ids": cup.get("ingredient_ids", PackedStringArray()), "quantity": 1, "waste_reason": &"soy_output_discarded"})


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
		"batch_quantity": quantity,
		"ingredient_counts": ingredient_counts.duplicate(true),
		"ingredient_ids": _product_ingredient_ids(),
		"water_filling": water_filling,
		"water_value": water_value,
		"water_grade": water_grade,
		"water_zone": water_zone(water_value),
		"water_guide_enabled": water_guide_enabled,
		"quality_max_enabled": quality_max_enabled,
		"quality_multiplier": quality_multiplier,
		"elapsed_seconds": elapsed_seconds,
		"duration_seconds": production_duration_seconds() if not recipe_id.is_empty() else 0.0,
		"completed_elapsed_seconds": completed_elapsed_seconds,
		"quality": quality,
		"manual_cup_ready": false,
		"seconds_to_ready": maxf(production_duration_seconds() - elapsed_seconds, 0.0) if state == STATE_GRINDING else 0.0,
		"seconds_to_loss": _seconds_to_loss(),
		"infinite_hold": bool(_tier_definition().get("infinite_hold", false)),
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
	ingredient_counts = Dictionary(value.get("ingredient_counts", {})).duplicate(true)
	# V5 saves always have ingredient_counts. Keep a narrow fallback for tests
	# that construct snapshots directly; SAVE_VERSION prevents v4 game migration.
	if ingredient_counts.is_empty() and restored_state != STATE_IDLE:
		var old_recipe := CATALOG.recipe_definition(StringName(value.get("recipe_id", &"")))
		var old_stocks := Array(old_recipe.get("stock_ids", []))
		if old_stocks.size() == 1:
			ingredient_counts[StringName(old_stocks[0])] = maxi(int(value.get("quantity", 0)), 0)
	_resolve_batch()
	water_filling = bool(value.get("water_filling", false))
	water_value = clampf(float(value.get("water_value", 0.0)), 0.0, 100.0)
	water_grade = StringName(value.get("water_grade", &""))
	quality_multiplier = float(value.get("quality_multiplier", _multiplier_for_grade(water_grade)))
	elapsed_seconds = maxf(float(value.get("elapsed_seconds", 0.0)), 0.0)
	completed_elapsed_seconds = maxf(float(value.get("completed_elapsed_seconds", 0.0)), 0.0)
	quality = clampf(float(value.get("quality", _quality_for_water_grade(water_grade))), 0.0, 100.0)
	var restored_rack := Array(value.get("output_rack", []))
	for index in range(mini(restored_rack.size(), OUTPUT_CAPACITY)):
		_output_rack[index] = Dictionary(restored_rack[index]).duplicate(true)
	if state != STATE_IDLE and (quantity <= 0 or recipe_id.is_empty()):
		_reset_idle()
	return _success()


func water_zone(value: float) -> StringName:
	if value >= 45.0 and value <= 60.0:
		return &"green"
	if (value >= 25.0 and value <= 44.999999) or (value >= 60.000001 and value <= 80.0):
		return &"yellow"
	return &"red"


func _apply_water_result(value: float) -> void:
	water_value = clampf(value, 0.0, 100.0)
	water_grade = _grade_for_water_value(water_value)
	if quality_max_enabled:
		water_grade = &"A"
		water_value = 52.5
	quality_multiplier = _multiplier_for_grade(water_grade)
	quality = _quality_for_water_grade(water_grade)
	state = STATE_WATER_ADDED


func _resolve_batch() -> void:
	var active: Array[StringName] = []
	for stock_id in BEAN_STOCK_IDS:
		if int(ingredient_counts.get(stock_id, 0)) > 0:
			active.append(stock_id)
	recipe_id = &""
	quantity = 0
	if active.size() == 1:
		recipe_id = _simple_recipe_for_stock(active[0])
		quantity = int(ingredient_counts[active[0]])
	elif active.size() >= 2:
		var common_count := int(ingredient_counts[active[0]])
		var equal := common_count > 0
		for stock_id in active:
			if int(ingredient_counts[stock_id]) != common_count:
				equal = false
				break
		if equal:
			recipe_id = &"recipe.fresh_soy_milk.multigrain"
			quantity = common_count


func _move_completed_batch_to_rack() -> void:
	var empty_indices: Array[int] = []
	for index in range(OUTPUT_CAPACITY):
		if _output_rack[index].is_empty():
			empty_indices.append(index)
	if empty_indices.size() < quantity:
		state = STATE_BLOCKED
		return
	var infinite_hold := bool(_tier_definition().get("infinite_hold", false))
	for cup_index in range(quantity):
		_output_rack[empty_indices[cup_index]] = {
			"recipe_id": recipe_id,
			"ingredient_ids": _product_ingredient_ids(),
			"quality": quality,
			"grade": _grade_for_quality(quality),
			"quality_multiplier": quality_multiplier,
			"age_seconds": 0.0,
			"state": STATE_READY_SAFE,
			"seconds_to_loss": 0.0 if infinite_hold else 15.0,
			"infinite_hold": infinite_hold,
		}
	_reset_idle()


func _advance_output_rack(step: float) -> void:
	for index in range(OUTPUT_CAPACITY):
		var cup := _output_rack[index]
		if cup.is_empty() or bool(cup.get("infinite_hold", false)) or StringName(cup.get("state", &"")) == STATE_SPOILED:
			continue
		cup["age_seconds"] = float(cup.get("age_seconds", 0.0)) + step
		var age := float(cup["age_seconds"])
		cup["seconds_to_loss"] = maxf(15.0 - age, 0.0)
		cup["quality"] = clampf(float(cup.get("quality", 100.0)) - 40.0 * maxf(age - 5.0, 0.0) / 10.0, 0.0, 100.0)
		cup["grade"] = _grade_for_quality(float(cup["quality"]))
		if age >= 15.0:
			cup["state"] = STATE_SPOILED
			cup["quality"] = 0.0
			cup["grade"] = &"waste"
		elif age > 5.0:
			cup["state"] = STATE_OVERCOOKING
		_output_rack[index] = cup


func _product_payload(product_quantity: int, product_quality: float) -> Dictionary:
	var recipe := CATALOG.recipe_definition(recipe_id)
	return {
		"recipe_id": recipe_id,
		"product_id": StringName(recipe.get("product_id", &"")),
		"quantity": product_quantity,
		"quality": product_quality,
		"grade": _grade_for_quality(product_quality),
		"quality_multiplier": quality_multiplier,
		"ingredient_ids": _product_ingredient_ids(),
		"temperature_mode": &"room_temperature",
	}


func _product_payload_from_cup(cup: Dictionary) -> Dictionary:
	var cup_recipe := StringName(cup.get("recipe_id", &""))
	var recipe := CATALOG.recipe_definition(cup_recipe)
	return {
		"recipe_id": cup_recipe,
		"product_id": StringName(recipe.get("product_id", &"")),
		"quantity": 1,
		"quality": float(cup.get("quality", 100.0)),
		"grade": StringName(cup.get("grade", _grade_for_quality(float(cup.get("quality", 100.0))))),
		"quality_multiplier": float(cup.get("quality_multiplier", 1.0)),
		"ingredient_ids": PackedStringArray(cup.get("ingredient_ids", PackedStringArray())),
		"temperature_mode": &"room_temperature",
	}


func _product_ingredient_ids() -> PackedStringArray:
	if recipe_id != &"recipe.fresh_soy_milk.multigrain":
		return PackedStringArray()
	var result := PackedStringArray()
	for stock_id in BEAN_STOCK_IDS:
		if int(ingredient_counts.get(stock_id, 0)) > 0:
			result.append(str(stock_id))
	return result


func _seconds_to_loss() -> float:
	if state not in [STATE_READY_SAFE, STATE_OVERCOOKING] or bool(_tier_definition().get("infinite_hold", false)):
		return 0.0
	return maxf(float(_tier_definition().get("safe_seconds", 5.0)) + float(_tier_definition().get("decay_seconds", 10.0)) - completed_elapsed_seconds, 0.0)


func _tier_definition() -> Dictionary:
	return CATALOG.device_tier(DEVICE_ID, tier)


func _reset_idle() -> void:
	state = STATE_IDLE
	_reset_values()


func _reset_values() -> void:
	recipe_id = &""
	quantity = 0
	ingredient_counts = {}
	water_filling = false
	water_value = 0.0
	water_grade = &""
	quality_multiplier = 1.0
	elapsed_seconds = 0.0
	completed_elapsed_seconds = 0.0
	quality = 100.0
	manual_cup_ready = false


static func _simple_recipe_for_stock(stock_id: StringName) -> StringName:
	match stock_id:
		YELLOW_STOCK: return &"recipe.fresh_soy_milk.yellow_bean"
		BLACK_STOCK: return &"recipe.fresh_soy_milk.black_bean"
		RED_STOCK: return &"recipe.fresh_soy_milk.red_bean"
	return &""


static func _grade_for_water_value(value: float) -> StringName:
	if value >= 45.0 and value <= 60.0:
		return &"A"
	if (value >= 25.0 and value < 45.0) or (value > 60.0 and value <= 80.0):
		return &"B"
	return &"C"


static func _multiplier_for_grade(grade: StringName) -> float:
	match grade:
		&"A": return 1.2
		&"B": return 1.0
		&"C": return 0.5
	return 1.0


static func _quality_for_water_grade(grade: StringName) -> float:
	match grade:
		&"A": return 100.0
		&"B": return 80.0
		&"C": return 60.0
	return 100.0


static func _grade_for_quality(value: float) -> StringName:
	if value >= 90.0:
		return &"A"
	if value >= 75.0:
		return &"B"
	if value >= 50.0:
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
