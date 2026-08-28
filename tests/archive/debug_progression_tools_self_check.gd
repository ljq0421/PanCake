extends SceneTree

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession autoload exists for debug progression tools")
	if session == null:
		_finish()
		return
	_check(OS.is_debug_build(), "self-check runs in a debug build")

	session.call("begin_new_game")
	var grant := Dictionary(session.call("debug_grant_progression", 1000, 20, &"area.pancake", 0, 5))
	var grant_after := Dictionary(grant.get("after", {}))
	var pancake_details := Dictionary(Dictionary(grant_after.get("area_mastery_details", {})).get("area.pancake", {}))
	_check(bool(grant.get("success", false)) and int(grant_after.get("coins", 0)) == 1000 and int(grant_after.get("reputation", 0)) == 20, "debug grant persists coins and reputation")
	_check(int(pancake_details.get("qualified", 0)) == 5 and int(pancake_details.get("a_grade", 0)) == 5, "A-grade debug results also increase qualified mastery")
	var qualified := Dictionary(session.call("debug_grant_progression", 0, 0, &"area.pancake", 5, 0))
	var qualified_details := Dictionary(Dictionary(Dictionary(qualified.get("after", {})).get("area_mastery_details", {})).get("area.pancake", {}))
	_check(int(qualified_details.get("qualified", 0)) == 10 and int(qualified_details.get("a_grade", 0)) == 5, "qualified-only debug results preserve A-grade mastery")
	var locked_mastery := Dictionary(session.call("debug_grant_progression", 0, 0, &"area.youtiao", 5, 0))
	_check(not bool(locked_mastery.get("success", false)) and StringName(locked_mastery.get("reason", &"")) == &"area_locked", "locked areas reject direct mastery grants")
	session.call("end_business_day", {"reason": &"test_early_end"})

	var tier_cases := [
		{&"area_id": &"area.pancake", &"tier": 0},
		{&"area_id": &"area.youtiao", &"tier": 0},
		{&"area_id": &"area.fresh_soy_milk", &"tier": 0},
		{&"area_id": &"area.fresh_soy_milk", &"tier": 1},
		{&"area_id": &"area.fresh_soy_milk", &"tier": 2},
	]
	for tier_case in tier_cases:
		session.call("begin_new_game")
		session.call("end_business_day", {"reason": &"test_early_end"})
		var area_id := StringName(tier_case[&"area_id"])
		var target_tier := int(tier_case[&"tier"])
		var result := Dictionary(session.call("debug_advance_to_device_tier", area_id, target_tier))
		var progression: RefCounted = session.call("progression_service")
		var device_id := StringName(CATALOG.area_definition(area_id).get("device_id", &""))
		_check(bool(result.get("success", false)), "%s T%d checkpoint succeeds" % [area_id, target_tier])
		_check(bool(progression.call("owns_area", area_id)) and int(progression.call("device_tier", device_id)) == target_tier, "%s T%d checkpoint reaches its exact device tier" % [area_id, target_tier])
		var repeated := Dictionary(session.call("debug_advance_to_device_tier", area_id, target_tier))
		_check(bool(repeated.get("success", false)) and not bool(repeated.get("changed", true)), "%s T%d repeated checkpoint is idempotent" % [area_id, target_tier])
		var inventory := Dictionary(session.call("inventory_snapshot"))
		for stock_id in CATALOG.stock_ids():
			if bool(progression.call("owns_stock", stock_id)) and int(CATALOG.stock_definition(stock_id).get("restock_capacity", 0)) > 0:
				_check(int(inventory.get(str(stock_id), 0)) > 0, "%s T%d fills unlocked stock %s for immediate operation testing" % [area_id, target_tier, stock_id])

	session.call("begin_new_game")
	session.call("end_business_day", {"reason": &"test_early_end"})
	var removed_tier := Dictionary(session.call("debug_advance_to_device_tier", &"area.youtiao", 1))
	_check(not bool(removed_tier.get("success", true)) and StringName(removed_tier.get("reason", &"")) == &"unknown_device_tier", "debug checkpoints reject removed youtiao capacity tiers")

	session.call("_write_save")
	session.call("_load_save")
	session.call("_restore_progression")
	var restored: RefCounted = session.call("progression_service")
	_check(int(restored.call("device_tier", &"device.youtiao_fryer")) == 0, "four-slot youtiao checkpoint survives save reload")
	session.call("reset_incompatible_development_save")
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("DEBUG_PROGRESSION_TOOLS_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("DEBUG_PROGRESSION_TOOLS_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
