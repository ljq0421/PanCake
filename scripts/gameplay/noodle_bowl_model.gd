class_name NoodleBowlModel
extends RefCounted

const CATALOG := preload("res://scripts/data/noodle_shop_catalog.gd")

var state: StringName = &"idle"
var recipe_id: StringName = &""
var elapsed_seconds := 0.0
var drain_seconds := 0.0
var batches: Array[Dictionary] = []
var broth_id: StringName = &""
var topping_ids: Array[StringName] = []
var reboiled := false
var undercook_repair_cap := 100.0


func _init(snapshot: Dictionary = {}) -> void:
	if not snapshot.is_empty():
		load_snapshot(snapshot)


func begin(next_recipe_id: StringName) -> Dictionary:
	if CATALOG.recipe(next_recipe_id).is_empty():
		return {"success": false, "reason": &"unknown_recipe"}
	state = &"shaving"
	recipe_id = next_recipe_id
	elapsed_seconds = 0.0
	drain_seconds = 0.0
	batches.clear()
	broth_id = &""
	topping_ids.clear()
	reboiled = false
	undercook_repair_cap = 100.0
	return {"success": true, "snapshot": snapshot()}


func advance(delta: float) -> Dictionary:
	var step := maxf(delta, 0.0)
	if state in [&"shaving", &"cooking"]:
		elapsed_seconds += step
		for index in range(batches.size()):
			batches[index]["cook_seconds"] = float(batches[index].get("cook_seconds", 0.0)) + step
	elif state == &"lifted":
		elapsed_seconds += step
		drain_seconds += step
	elif state == &"bowled":
		elapsed_seconds += step
	return snapshot()


func record_stroke(distance: float, duration: float) -> Dictionary:
	if state not in [&"shaving", &"cooking"]:
		return {"success": false, "reason": &"basket_not_in_pot"}
	if distance < CATALOG.MIN_STROKE_DISTANCE:
		return {"success": false, "reason": &"stroke_too_short", "minimum_distance": CATALOG.MIN_STROKE_DISTANCE}
	if duration <= 0.0:
		return {"success": false, "reason": &"invalid_duration"}
	var speed := distance / duration
	var thickness_id := CATALOG.thickness_for_speed(speed)
	var interval := 0.0
	if not batches.is_empty():
		interval = maxf(elapsed_seconds - float(batches.back().get("created_at", 0.0)), 0.0)
	var batch := {
		"index": batches.size(),
		"created_at": elapsed_seconds,
		"distance": distance,
		"duration": duration,
		"speed": speed,
		"thickness_id": thickness_id,
		"interval_seconds": interval,
		"cook_seconds": 0.0,
	}
	batches.append(batch)
	state = &"cooking"
	return {"success": true, "batch": batch.duplicate(true), "batch_count": batches.size()}


func lift_basket() -> Dictionary:
	if state not in [&"shaving", &"cooking"]:
		return {"success": false, "reason": &"basket_not_in_pot"}
	if batches.size() < CATALOG.MIN_LIFT_BATCH_COUNT:
		return {"success": false, "reason": &"too_few_batches", "minimum": CATALOG.MIN_LIFT_BATCH_COUNT}
	state = &"lifted"
	drain_seconds = 0.0
	return {"success": true, "snapshot": snapshot()}


func return_to_pot() -> Dictionary:
	if state != &"lifted":
		return {"success": false, "reason": &"basket_not_lifted"}
	state = &"cooking"
	drain_seconds = 0.0
	reboiled = true
	undercook_repair_cap = minf(undercook_repair_cap, 85.0)
	return {"success": true, "snapshot": snapshot()}


func transfer_to_bowl() -> Dictionary:
	if state != &"lifted":
		return {"success": false, "reason": &"basket_not_lifted"}
	state = &"bowled"
	return {"success": true, "snapshot": snapshot()}


func set_broth(next_broth_id: StringName) -> Dictionary:
	if state != &"bowled":
		return {"success": false, "reason": &"no_bowled_noodles"}
	if not topping_ids.is_empty():
		return {"success": false, "reason": &"bowl_already_mixed"}
	broth_id = next_broth_id
	return {"success": true, "snapshot": snapshot()}


func add_topping(topping_id: StringName) -> Dictionary:
	if state != &"bowled":
		return {"success": false, "reason": &"no_bowled_noodles"}
	if not topping_ids.has(topping_id):
		topping_ids.append(topping_id)
	return {"success": true, "snapshot": snapshot()}


func snapshot() -> Dictionary:
	return {
		"version": 1,
		"state": state,
		"recipe_id": recipe_id,
		"elapsed_seconds": elapsed_seconds,
		"drain_seconds": drain_seconds,
		"batches": batches.duplicate(true),
		"broth_id": broth_id,
		"topping_ids": PackedStringArray(topping_ids.map(func(value): return str(value))),
		"reboiled": reboiled,
		"undercook_repair_cap": undercook_repair_cap,
	}


func load_snapshot(source: Dictionary) -> Dictionary:
	state = StringName(source.get("state", &"idle"))
	recipe_id = StringName(source.get("recipe_id", &""))
	elapsed_seconds = maxf(float(source.get("elapsed_seconds", 0.0)), 0.0)
	drain_seconds = maxf(float(source.get("drain_seconds", 0.0)), 0.0)
	batches.clear()
	for value in Array(source.get("batches", [])):
		batches.append(Dictionary(value).duplicate(true))
	topping_ids.clear()
	for value in Array(source.get("topping_ids", [])):
		topping_ids.append(StringName(value))
	broth_id = StringName(source.get("broth_id", &""))
	reboiled = bool(source.get("reboiled", false))
	undercook_repair_cap = clampf(float(source.get("undercook_repair_cap", 100.0)), 0.0, 100.0)
	return {"success": true, "snapshot": snapshot()}

