extends RefCounted

const CATALOG := preload("res://scripts/data/workstation_expansion_catalog.gd")

const STATE_UNOWNED: StringName = &"unowned"
const STATE_IDLE: StringName = &"idle"
const STATE_LOADING: StringName = &"loading"
const STATE_PROCESSING: StringName = &"processing"
const STATE_SAFE_HOLD: StringName = &"completed_safe_period"
const STATE_DECAYING: StringName = &"quality_decaying"
const STATE_HOLDING: StringName = &"infinite_hold"

var device_id: StringName
var tier := CATALOG.TIER_BASIC
var owned := false
var state: StringName = STATE_UNOWNED
var recipe_id: StringName = &""
var loaded_quantity := 0
var processing_elapsed := 0.0
var completed_elapsed := 0.0
var quality := CATALOG.QUALITY_INITIAL
var _actions := {}


func _init(next_device_id: StringName, next_tier: int = CATALOG.TIER_BASIC, is_owned: bool = false) -> void:
	device_id = next_device_id
	if is_owned:
		configure_owned(next_tier)


func configure_owned(next_tier: int) -> void:
	if CATALOG.device_tier(device_id, next_tier).is_empty():
		return
	owned = true
	tier = next_tier
	if state == STATE_UNOWNED:
		state = STATE_IDLE


func load_input(next_recipe_id: StringName, quantity: int = 1) -> Dictionary:
	if not owned:
		return _failure(&"equipment_not_owned")
	if state == STATE_PROCESSING:
		return _failure(&"processing_in_progress")
	if has_output():
		return _failure(&"finished_output_occupies_capacity")
	if state != STATE_IDLE and state != STATE_LOADING:
		return _failure(&"invalid_equipment_state")
	if quantity <= 0:
		return _failure(&"invalid_quantity")
	var recipe: Dictionary = CATALOG.recipe_definition(next_recipe_id)
	if recipe.is_empty() or recipe.get("kind", &"") != &"main" or recipe.get("device_id", &"") != device_id:
		return _failure(&"invalid_main_recipe")
	if not recipe_id.is_empty() and recipe_id != next_recipe_id:
		return _failure(&"mixed_main_recipe")
	var capacity := capacity()
	if loaded_quantity + quantity > capacity:
		return _failure(&"capacity_exceeded", {"capacity": capacity, "loaded_quantity": loaded_quantity})
	recipe_id = next_recipe_id
	loaded_quantity += quantity
	state = STATE_LOADING
	return _success({"loaded_quantity": loaded_quantity, "remaining_capacity": capacity - loaded_quantity})


func perform_action(action: StringName) -> Dictionary:
	if not owned:
		return _failure(&"equipment_not_owned")
	var definition := CATALOG.device_definition(device_id)
	var before_start: Array = definition.get("required_before_start", [])
	var before_collect: Array = definition.get("required_before_collect", [])
	if before_start.has(action):
		if state != STATE_LOADING:
			return _failure(&"action_not_available")
		_actions[action] = true
		return _success({"action": action})
	if before_collect.has(action):
		if not has_output():
			return _failure(&"action_not_available")
		_actions[action] = true
		return _success({"action": action})
	return _failure(&"unsupported_action")


func start() -> Dictionary:
	if not owned:
		return _failure(&"equipment_not_owned")
	if state == STATE_PROCESSING:
		return _failure(&"processing_in_progress")
	if has_output():
		return _failure(&"finished_output_occupies_capacity")
	if loaded_quantity <= 0 or state == STATE_IDLE:
		return _failure(&"empty_equipment")
	if state != STATE_LOADING:
		return _failure(&"invalid_equipment_state")
	var missing := _missing_actions(CATALOG.device_definition(device_id).get("required_before_start", []))
	if not missing.is_empty():
		return _failure(&"missing_required_action", {"missing_actions": missing})
	state = STATE_PROCESSING
	processing_elapsed = 0.0
	completed_elapsed = 0.0
	quality = float(tier_definition().get("initial_quality", CATALOG.QUALITY_INITIAL))
	return _success({"duration_seconds": duration_seconds(), "quantity": loaded_quantity})


func advance_time(delta: float) -> void:
	var remaining_delta := maxf(delta, 0.0)
	if remaining_delta <= 0.0:
		return
	if state == STATE_PROCESSING:
		var until_complete := maxf(duration_seconds() - processing_elapsed, 0.0)
		var applied := minf(remaining_delta, until_complete)
		processing_elapsed += applied
		remaining_delta -= applied
		if processing_elapsed + 0.000001 < duration_seconds():
			return
		processing_elapsed = duration_seconds()
		completed_elapsed = 0.0
		state = STATE_HOLDING if bool(tier_definition().get("infinite_hold", false)) else STATE_SAFE_HOLD
	if has_output() and remaining_delta > 0.0:
		completed_elapsed += remaining_delta
		_update_completed_quality()


func collect(quantity: int = 1) -> Dictionary:
	if not owned:
		return _failure(&"equipment_not_owned")
	if state == STATE_PROCESSING:
		return _failure(&"processing_in_progress")
	if not has_output():
		return _failure(&"no_finished_output")
	if quantity <= 0 or quantity > loaded_quantity:
		return _failure(&"invalid_collection_quantity")
	var missing := _missing_actions(CATALOG.device_definition(device_id).get("required_before_collect", []))
	if not missing.is_empty():
		return _failure(&"missing_required_action", {"missing_actions": missing})
	var product := {
		"status": &"extracted",
		"device_id": device_id,
		"recipe_id": recipe_id,
		"quantity": quantity,
		"quality": quality,
		"completed_elapsed": completed_elapsed,
		"add_ons": [],
	}
	loaded_quantity -= quantity
	var remaining_quantity := loaded_quantity
	if loaded_quantity <= 0:
		_reset_to_idle()
	return _success({
		"product": product,
		"released_quantity": quantity,
		"remaining_quantity": remaining_quantity,
		"remaining_occupied_capacity": remaining_quantity,
	})


func capacity() -> int:
	return int(tier_definition().get("capacity", 0))


func duration_seconds() -> float:
	return float(tier_definition().get("duration_seconds", 0.0))


func tier_definition() -> Dictionary:
	return CATALOG.device_tier(device_id, tier)


func has_output() -> bool:
	return state in [STATE_SAFE_HOLD, STATE_DECAYING, STATE_HOLDING] and loaded_quantity > 0


func snapshot() -> Dictionary:
	return {
		"device_id": device_id,
		"tier": tier,
		"owned": owned,
		"state": state,
		"recipe_id": recipe_id,
		"loaded_quantity": loaded_quantity,
		"capacity": capacity(),
		"processing_elapsed": processing_elapsed,
		"duration_seconds": duration_seconds(),
		"completed_elapsed": completed_elapsed,
		"quality": quality,
		"has_output": has_output(),
		"actions": _actions.duplicate(true),
	}


static func decorate_product(product: Dictionary, add_on_id: StringName) -> Dictionary:
	var definition := CATALOG.recipe_definition(add_on_id)
	if definition.is_empty() or definition.get("kind", &"") != &"add_on":
		return {"success": false, "reason": &"invalid_add_on"}
	if product.get("status", &"") != &"extracted" or product.get("device_id", &"") != definition.get("device_id", &""):
		return {"success": false, "reason": &"add_on_not_compatible"}
	var result := product.duplicate(true)
	var add_ons: Array = result.get("add_ons", [])
	if not add_ons.has(add_on_id):
		add_ons.append(add_on_id)
	result["add_ons"] = add_ons
	return {"success": true, "product": result}


func _update_completed_quality() -> void:
	var definition := tier_definition()
	if bool(definition.get("infinite_hold", false)):
		state = STATE_HOLDING
		quality = float(definition.get("initial_quality", CATALOG.QUALITY_INITIAL))
		return
	var safe_seconds := float(definition.get("safe_seconds", CATALOG.QUALITY_SAFE_SECONDS))
	if completed_elapsed <= safe_seconds + 0.0000001:
		state = STATE_SAFE_HOLD
		quality = float(definition.get("initial_quality", CATALOG.QUALITY_INITIAL))
		return
	state = STATE_DECAYING
	var decay_time := completed_elapsed - safe_seconds
	quality = clampf(
		float(definition.get("initial_quality", CATALOG.QUALITY_INITIAL))
		- decay_time * float(definition.get("decay_per_second", CATALOG.QUALITY_DECAY_PER_SECOND_PLACEHOLDER)),
		0.0,
		100.0
	)


func _missing_actions(required: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for action in required:
		if not bool(_actions.get(action, false)):
			result.append(action)
	return result


func _reset_to_idle() -> void:
	state = STATE_IDLE
	recipe_id = &""
	loaded_quantity = 0
	processing_elapsed = 0.0
	completed_elapsed = 0.0
	quality = CATALOG.QUALITY_INITIAL
	_actions.clear()


func _success(extra: Dictionary = {}) -> Dictionary:
	var result := {"success": true, "reason": &""}
	result.merge(extra, true)
	return result


func _failure(reason: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"success": false, "reason": reason}
	result.merge(extra, true)
	return result
