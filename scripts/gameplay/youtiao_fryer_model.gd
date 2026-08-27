class_name YoutiaoFryerModel
extends RefCounted

## Compatibility façade for the fryer. Legacy members and methods address the
## left/youtiao basket; new callers select an explicit lane.

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const LANE_MODEL := preload("res://scripts/gameplay/fryer_lane_model.gd")
const DEVICE_ID := &"device.youtiao_fryer"
const AREA_ID := &"area.youtiao"
const LANE_YOUTIAO := &"left"
const LANE_CHICKEN := &"right"
const CHICKEN_RECIPE_ID := &"recipe.chicken.cutlet"

var owned := false
var tier := 0
var _left = LANE_MODEL.new()
var _right = LANE_MODEL.new()

var state: StringName:
	get: return _left.state
var recipe_id: StringName:
	get: return _left.recipe_id
var quantity: int:
	get: return _left.quantity
var occupied_slot_indices: Array[int]:
	get: return _left.occupied_slot_indices
var cooking_elapsed_seconds: float:
	get: return _left.cooking_elapsed_seconds
var completed_elapsed_seconds: float:
	get: return _left.completed_elapsed_seconds
var draining_elapsed_seconds: float:
	get: return _left.draining_elapsed_seconds
var quality: float:
	get: return _left.quality


func _init(next_tier: int = 0, is_owned: bool = false) -> void:
	if is_owned:
		configure_owned(next_tier)


func configure_owned(next_tier: int) -> Dictionary:
	var definition := CATALOG.device_tier(DEVICE_ID, next_tier)
	if definition.is_empty():
		return _failure(&"invalid_device_tier")
	owned = true
	tier = next_tier
	_left.configure_owned(definition)
	if tier >= 2:
		_right.configure_owned(definition)
	else:
		_right.configure_unowned()
	return _success({"tier": tier, "capacity": capacity()})


func capacity() -> int:
	return _left.capacity()


func lane_enabled(lane_id: StringName) -> bool:
	return _lane(lane_id).owned if _is_lane_id(lane_id) else false


func lane_snapshot(lane_id: StringName) -> Dictionary:
	if not _is_lane_id(lane_id):
		return {"lane_id": lane_id, "owned": false, "state": &"unsupported"}
	var value: Dictionary = _lane(lane_id).snapshot()
	value["lane_id"] = lane_id
	return value


func load_lane_recipe(lane_id: StringName, next_recipe_id: StringName, next_quantity: int) -> Dictionary:
	if not owned:
		return _failure(&"equipment_not_owned")
	if not lane_enabled(lane_id):
		return _failure(&"lane_not_unlocked", {"lane_id": lane_id})
	var recipe := CATALOG.recipe_definition(next_recipe_id)
	if recipe.is_empty() or StringName(recipe.get("area_id", &"")) != AREA_ID or not _recipe_allowed_in_lane(lane_id, next_recipe_id):
		return _failure(&"invalid_recipe", {"lane_id": lane_id, "recipe_id": next_recipe_id})
	return _lane(lane_id).load_recipe(next_recipe_id, next_quantity)


func start_lane(lane_id: StringName) -> Dictionary:
	if not lane_enabled(lane_id):
		return _failure(&"lane_not_unlocked", {"lane_id": lane_id})
	return _lane(lane_id).start()


func advance_lanes(delta: float, auto_lift: bool = false) -> void:
	for lane_id in [LANE_YOUTIAO, LANE_CHICKEN]:
		if lane_enabled(lane_id):
			_lane(lane_id).advance_time(delta, auto_lift)


func lift_lane(lane_id: StringName) -> Dictionary:
	if not lane_enabled(lane_id):
		return _failure(&"lane_not_unlocked", {"lane_id": lane_id})
	return _lane(lane_id).lift()


func preview_collect_lane(lane_id: StringName, collect_quantity: int = 1) -> Dictionary:
	return _lane_result(lane_id, "preview_collect", [collect_quantity])


func preview_collect_lane_slot(lane_id: StringName, slot_index: int) -> Dictionary:
	return _lane_result(lane_id, "preview_collect_slot", [slot_index])


func collect_lane(lane_id: StringName, collect_quantity: int = 1) -> Dictionary:
	return _lane_result(lane_id, "collect", [collect_quantity])


func collect_lane_slot(lane_id: StringName, slot_index: int) -> Dictionary:
	return _lane_result(lane_id, "collect_slot", [slot_index])


func discard_lane(lane_id: StringName) -> Dictionary:
	return _lane_result(lane_id, "discard", [])


func discard_lane_slot(lane_id: StringName, slot_index: int) -> Dictionary:
	return _lane_result(lane_id, "discard_slot", [slot_index])


# Legacy left-lane surface.
func load_recipe(next_recipe_id: StringName, next_quantity: int) -> Dictionary:
	return load_lane_recipe(LANE_YOUTIAO, next_recipe_id, next_quantity)

func start() -> Dictionary:
	return start_lane(LANE_YOUTIAO)

func advance_time(delta: float, auto_lift: bool = false) -> void:
	advance_lanes(delta, auto_lift)

func lift() -> Dictionary:
	return lift_lane(LANE_YOUTIAO)

func preview_collect(collect_quantity: int = 1) -> Dictionary:
	return preview_collect_lane(LANE_YOUTIAO, collect_quantity)

func preview_collect_slot(slot_index: int) -> Dictionary:
	return preview_collect_lane_slot(LANE_YOUTIAO, slot_index)

func collect(collect_quantity: int = 1) -> Dictionary:
	return collect_lane(LANE_YOUTIAO, collect_quantity)

func collect_slot(slot_index: int) -> Dictionary:
	return collect_lane_slot(LANE_YOUTIAO, slot_index)

func discard() -> Dictionary:
	return discard_lane(LANE_YOUTIAO)

func discard_slot(slot_index: int) -> Dictionary:
	return discard_lane_slot(LANE_YOUTIAO, slot_index)


func snapshot() -> Dictionary:
	var left := lane_snapshot(LANE_YOUTIAO)
	# Preserve top-level fields so current saves/tests and legacy consumers remain
	# valid while lanes are adopted incrementally.
	left.merge({"device_id": DEVICE_ID, "owned": owned, "tier": tier, "lanes": {LANE_YOUTIAO: left.duplicate(true), LANE_CHICKEN: lane_snapshot(LANE_CHICKEN)}}, true)
	return left


func load_snapshot(value: Dictionary) -> Dictionary:
	owned = false
	tier = 0
	_left.configure_unowned()
	_right.configure_unowned()
	if value.is_empty() or not bool(value.get("owned", false)):
		return _success()
	var configured := configure_owned(int(value.get("tier", 0)))
	if not bool(configured.get("success", false)):
		return configured
	var saved_lanes := Dictionary(value.get("lanes", {}))
	_left.load_snapshot(Dictionary(saved_lanes.get(LANE_YOUTIAO, value)))
	if lane_enabled(LANE_CHICKEN):
		_right.load_snapshot(Dictionary(saved_lanes.get(LANE_CHICKEN, {})))
	return _success()


func _lane_result(lane_id: StringName, method: String, arguments: Array) -> Dictionary:
	if not lane_enabled(lane_id):
		return _failure(&"lane_not_unlocked", {"lane_id": lane_id})
	var result: Dictionary = _lane(lane_id).callv(method, arguments)
	result["lane_id"] = lane_id
	return result


func _lane(lane_id: StringName) -> RefCounted:
	return _right if lane_id == LANE_CHICKEN else _left


static func _is_lane_id(lane_id: StringName) -> bool:
	return lane_id in [LANE_YOUTIAO, LANE_CHICKEN]


static func _recipe_allowed_in_lane(lane_id: StringName, candidate_recipe_id: StringName) -> bool:
	return candidate_recipe_id == CHICKEN_RECIPE_ID if lane_id == LANE_CHICKEN else candidate_recipe_id != CHICKEN_RECIPE_ID


static func _success(extra: Dictionary = {}) -> Dictionary:
	var result := {"success": true, "reason": &""}
	result.merge(extra, true)
	return result


static func _failure(reason: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"success": false, "reason": reason}
	result.merge(extra, true)
	return result
