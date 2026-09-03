class_name DailyGoalService
extends RefCounted

signal daily_goal_changed(snapshot: Dictionary)
signal daily_goal_completed(result: Dictionary)

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")

var _goal: Dictionary = {}


func _init(initial_snapshot: Dictionary = {}) -> void:
	if not initial_snapshot.is_empty():
		load_snapshot(initial_snapshot)


func begin_day(context: Dictionary) -> Dictionary:
	var day := maxi(int(context.get("current_day", 1)), 1)
	if int(_goal.get("day", 0)) == day:
		return {"success": true, "created": false, "goal": current_goal()}
	_goal.clear()
	# Daily goals are outside the cartoon breakfast v1 scope.
	if CATALOG.CARTOON_BREAKFAST_V1:
		daily_goal_changed.emit({})
		return {"success": true, "created": false, "reason": &"feature_disabled", "goal": {}}
	if not _all_areas_ready(context):
		daily_goal_changed.emit({})
		return {"success": true, "created": false, "reason": &"five_areas_not_ready", "goal": {}}
	var candidates: Array[StringName] = []
	var specialization := Dictionary(context.get("specialization", {}))
	for goal_key in CATALOG.DAILY_GOAL_DEFINITIONS:
		var goal_id := StringName(goal_key)
		var definition := CATALOG.daily_goal_definition(goal_id)
		var area_id := StringName(definition.get("area_id", &""))
		if area_id.is_empty():
			continue
		if _specialization_rank(StringName(specialization.get(str(area_id), specialization.get(area_id, &"unrated")))) >= 2:
			candidates.append(goal_id)
	if candidates.is_empty():
		candidates.append(&"goal.signature.combo_two_no_failure")
	candidates.sort()
	var seed := int(context.get("order_rng_seed", 1))
	var index := _roll(seed, day, candidates.size())
	var selected := candidates[index]
	var definition := CATALOG.daily_goal_definition(selected)
	_goal = {
		"goal_id": selected,
		"day": day,
		"area_id": StringName(definition.get("area_id", &"")),
		"progress": 0,
		"target": maxi(int(definition.get("target", 1)), 1),
		"failed_condition": false,
		"completed": false,
		"rewarded": false,
		"reward_event_id": StringName("daily_goal.%d.%s" % [day, str(selected)]),
	}
	daily_goal_changed.emit(current_goal())
	return {"success": true, "created": true, "goal": current_goal()}


func record_business_event(event: Dictionary) -> Dictionary:
	if _goal.is_empty() or bool(_goal.get("completed", false)) or bool(_goal.get("failed_condition", false)):
		return {"success": true, "changed": false, "goal": current_goal()}
	var definition := CATALOG.daily_goal_definition(StringName(_goal.get("goal_id", &"")))
	var kind := StringName(event.get("kind", &""))
	var details := Dictionary(event.get("details", {}))
	if kind == StringName(definition.get("fails_on", &"__none__")):
		_goal["failed_condition"] = true
		daily_goal_changed.emit(current_goal())
		return {"success": true, "changed": true, "failed": true, "goal": current_goal()}
	if kind != StringName(definition.get("event_kind", &"sale")):
		return {"success": true, "changed": false, "goal": current_goal()}
	var required_area := StringName(definition.get("area_id", &""))
	if not required_area.is_empty() and StringName(event.get("area_id", &"")) != required_area:
		return {"success": true, "changed": false, "goal": current_goal()}
	if definition.has("requires_grade") and StringName(details.get("grade", &"")) != StringName(definition.get("requires_grade", &"")):
		return {"success": true, "changed": false, "goal": current_goal()}
	if definition.has("requires_min_grade") and _grade_rank(StringName(details.get("grade", &""))) < _grade_rank(StringName(definition.get("requires_min_grade", &"B"))):
		return {"success": true, "changed": false, "goal": current_goal()}
	if bool(definition.get("requires_correct_temperature", false)) and not bool(details.get("correct_temperature", false)):
		return {"success": true, "changed": false, "goal": current_goal()}
	if definition.has("requires_complexity") and StringName(details.get("complexity", &"")) != StringName(definition.get("requires_complexity", &"")):
		return {"success": true, "changed": false, "goal": current_goal()}
	_goal["progress"] = mini(int(_goal.get("progress", 0)) + maxi(int(event.get("quantity", 1)), 1), int(_goal.get("target", 1)))
	if int(_goal["progress"]) >= int(_goal.get("target", 1)):
		_goal["completed"] = true
		var result := _reward_request(definition)
		daily_goal_completed.emit(result.duplicate(true))
		daily_goal_changed.emit(current_goal())
		return result
	daily_goal_changed.emit(current_goal())
	return {"success": true, "changed": true, "goal": current_goal()}


func mark_rewarded(reward_event_id: StringName) -> Dictionary:
	if _goal.is_empty() or not bool(_goal.get("completed", false)):
		return {"success": false, "reason": &"goal_not_completed"}
	if StringName(_goal.get("reward_event_id", &"")) != reward_event_id:
		return {"success": false, "reason": &"reward_event_mismatch"}
	if bool(_goal.get("rewarded", false)):
		return {"success": true, "changed": false, "already_rewarded": true}
	_goal["rewarded"] = true
	daily_goal_changed.emit(current_goal())
	return {"success": true, "changed": true}


func current_goal() -> Dictionary:
	return _goal.duplicate(true)


func snapshot() -> Dictionary:
	return {"version": 1, "goal": current_goal()}


func load_snapshot(value: Dictionary) -> Dictionary:
	_goal = Dictionary(value.get("goal", value)).duplicate(true)
	if not _goal.is_empty() and CATALOG.daily_goal_definition(StringName(_goal.get("goal_id", &""))).is_empty():
		_goal.clear()
	return {"success": true, "goal": current_goal()}


func _reward_request(definition: Dictionary) -> Dictionary:
	return {
		"success": true,
		"changed": true,
		"completed": true,
		"reward_event_id": StringName(_goal.get("reward_event_id", &"")),
		"reward_coins": maxi(int(definition.get("reward_coins", 0)), 0),
		"reward_reputation": maxi(int(definition.get("reward_reputation", 0)), 0),
		"goal": current_goal(),
	}


static func _all_areas_ready(context: Dictionary) -> bool:
	var unlocked := _id_set(context.get("unlocked_area_ids", []))
	var completed := _id_set(context.get("tutorial_completed_area_ids", []))
	for area_id in CATALOG.AREA_IDS:
		if not unlocked.has(area_id) or not completed.has(area_id):
			return false
	return true


static func _id_set(values: Variant) -> Dictionary:
	var result := {}
	for value in Array(values):
		result[StringName(value)] = true
	return result


static func _roll(seed: int, day: int, upper_bound: int) -> int:
	if upper_bound <= 1:
		return 0
	var value := int(seed) & 0x7fffffff
	value = int((value * 1103515245 + day * 2654435761 + 19349663) & 0x7fffffff)
	return posmod(value, upper_bound)


static func _specialization_rank(level: StringName) -> int:
	return {&"unrated": 0, &"bronze": 1, &"silver": 2, &"gold": 3}.get(level, 0)


static func _grade_rank(grade: StringName) -> int:
	return {&"waste": 0, &"C": 1, &"B": 2, &"A": 3}.get(grade, 0)
