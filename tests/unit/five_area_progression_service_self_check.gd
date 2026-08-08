extends SceneTree

const SERVICE = preload("res://scripts/services/five_area_progression_service.gd")
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var day_one = SERVICE.new({
		"coins": 100,
		"reputation": 20,
		"current_day": 1,
		"unlocked_area_ids": [&"area.pancake"],
		"area_mastery_details": {&"area.pancake": {"qualified": 6, "a_grade": 1}},
		"tutorial": {"completed_area_ids": [&"area.pancake"], "queue_area_ids": [], "active_kind": &"", "active_id": &""},
	})
	var day_one_recommendations: Dictionary = day_one.growth_recommendations(3)
	var day_one_items: Array = Array(day_one_recommendations.get("recommended", []))
	_check(_growth_ids(day_one_items) == [&"growth.tool.pancake.wide_spreader", &"growth.add_on.pancake.red_chili", &"growth.area.packaged_drink"], "day-one settlement recommends the two D2 pancake goals and the D3 next-area goal")
	_check(day_one_items.size() == 3 and Array(day_one_recommendations.get("install", [])).size() == 2 and Array(day_one_recommendations.get("content", [])).size() == 1, "recommendation limit applies to the total across both purchase slots")
	for item_variant in day_one_items:
		var item := Dictionary(item_variant)
		_check(not bool(item.get("can_purchase", true)) and StringName(item.get("reason", &"")) == &"day_requirement", "day-one recommendation remains locked by its D2 or D3 purchase day")
		_check(not Array(item.get("missing_requirements", [])).is_empty(), "locked recommendation retains its complete requirement list")

	var day_two = SERVICE.new({
		"coins": 100,
		"reputation": 20,
		"current_day": 2,
		"unlocked_area_ids": [&"area.pancake"],
		"area_mastery_details": {&"area.pancake": {"qualified": 6, "a_grade": 1}},
		"tutorial": {"completed_area_ids": [&"area.pancake"], "queue_area_ids": [], "active_kind": &"", "active_id": &""},
	})
	var day_two_items: Array = Array(day_two.growth_recommendations(3).get("recommended", []))
	_check(bool(Dictionary(day_two_items[0]).get("can_purchase", false)) and bool(Dictionary(day_two_items[1]).get("can_purchase", false)), "D2 permits the qualified spreader and chili purchases")
	_check(StringName(Dictionary(day_two_items[2]).get("reason", &"")) == &"day_requirement", "the drink area remains locked until its D3 purchase day")
	_check(bool(day_two.purchase(&"growth.tool.pancake.wide_spreader").get("success", false)) and bool(day_two.purchase(&"growth.add_on.pancake.red_chili").get("success", false)), "D2 accepts one installation and one content purchase")
	day_two.set_day_open(false)
	var day_three_activation: Dictionary = day_two.begin_next_business_day()
	_check(bool(day_three_activation.get("success", false)) and int(day_three_activation.get("current_day", 0)) == 3, "D2 purchases activate on D3")

	var day_three = SERVICE.new({
		"coins": 100,
		"reputation": 20,
		"current_day": 3,
		"unlocked_area_ids": [&"area.pancake"],
		"area_mastery_details": {&"area.pancake": {"qualified": 6, "a_grade": 1}},
		"tutorial": {"completed_area_ids": [&"area.pancake"], "queue_area_ids": [], "active_kind": &"", "active_id": &""},
	})
	_check(bool(day_three.purchase_status(&"growth.area.packaged_drink").get("can_purchase", false)), "drink area opens for purchase on D3 when reputation, tutorial, and mastery are ready")

	var drink_stage = SERVICE.new({
		"coins": 500,
		"reputation": 60,
		"current_day": 6,
		"unlocked_area_ids": [&"area.pancake", &"area.packaged_drink"],
		"owned_growth_ids": [&"growth.tool.pancake.wide_spreader", &"growth.add_on.pancake.red_chili", &"growth.area.packaged_drink"],
		"area_mastery_details": {&"area.pancake": {"qualified": 6}, &"area.packaged_drink": {"correct_temperature": 4}},
		"tutorial": {"completed_area_ids": [&"area.pancake", &"area.packaged_drink"], "queue_area_ids": [], "active_kind": &"", "active_id": &""},
	})
	var drink_stage_ids := _growth_ids(Array(drink_stage.growth_recommendations(3).get("recommended", [])))
	_check(drink_stage_ids.has(&"growth.area.youtiao") and not drink_stage_ids.has(&"growth.area.fresh_soy_milk") and not drink_stage_ids.has(&"growth.area.steamer"), "recommendations advance only to the immediate next area")
	var youtiao_stage_ids := _path_stage_ids(
		[&"area.pancake", &"area.packaged_drink", &"area.youtiao"],
		[&"growth.area.packaged_drink", &"growth.area.youtiao"]
	)
	_check(youtiao_stage_ids.has(&"growth.area.fresh_soy_milk") and not youtiao_stage_ids.has(&"growth.area.steamer"), "youtiao stage advances to fresh soy milk without skipping to steamer")
	var soy_stage_ids := _path_stage_ids(
		[&"area.pancake", &"area.packaged_drink", &"area.youtiao", &"area.fresh_soy_milk"],
		[&"growth.area.packaged_drink", &"growth.area.youtiao", &"growth.area.fresh_soy_milk"]
	)
	_check(soy_stage_ids.has(&"growth.area.steamer"), "fresh-soy-milk stage advances to the final steamer area")

	var progression = SERVICE.new()
	var tutorial: Dictionary = progression.tutorial_snapshot()
	_check(tutorial.get("active_kind", &"") == &"area" and tutorial.get("active_id", &"") == &"area.pancake", "new progression begins with the pancake-area tutorial")
	_check(bool(progression.complete_tutorial(&"area", &"area.pancake").get("success", false)), "area tutorial completion is persisted by stable area ID")
	progression.coins = 100
	progression.reputation = 20
	progression.current_day = 3
	progression.area_mastery = {&"area.pancake": 6}
	progression.area_mastery_details = {&"area.pancake": {"qualified": 6, "a_grade": 0}}
	var install = progression.purchase(&"growth.area.packaged_drink")
	_check(install.get("success") and progression.coins == 70, "installation purchase charges immediately")
	var content = progression.purchase(&"growth.add_on.pancake.red_chili")
	_check(content.get("success") and progression.coins == 62, "content purchase may coexist with installation pending")
	_check(progression.purchase(&"growth.tool.pancake.wide_spreader").get("reason") == &"purchase_slot_occupied", "second installation pending is rejected")
	_check(not progression.begin_next_business_day().get("success"), "activation requires business day to be closed")
	progression.set_day_open(false)
	var activation = progression.begin_next_business_day()
	_check(activation.get("success") and progression.owns_area(&"area.packaged_drink"), "installation activates the following day")
	_check(progression.owns_stock(&"stock.pancake.sauce.red_chili"), "content activates the following day")
	_check(progression.pending_install_purchase.is_empty() and progression.pending_content_purchase.is_empty(), "activation clears both pending slots")
	var restored = SERVICE.new(progression.snapshot())
	_check(restored.owns_area(&"area.packaged_drink") and restored.owns_stock(&"stock.pancake.sauce.red_chili"), "snapshot restores activation state")
	var rollback = SERVICE.new({"coins": 50, "current_day": 4, "day_open": false, "pending_install_purchase": "growth.missing", "pending_content_purchase": ""})
	var rollback_before := rollback.snapshot()
	_check(not rollback.begin_next_business_day().get("success") and rollback.snapshot() == rollback_before, "invalid pending activation rolls back atomically")
	var press_locked = SERVICE.new({"coins": 100, "current_day": 20, "owned_growth_ids": [], "unlocked_area_ids": [&"area.pancake"]})
	_check(press_locked.purchase_status(&"growth.automation.pancake.press_once").get("reason") == &"growth_requirement", "press automation requires every confirmed pancake tool/device/automation prerequisite")
	var press_ready = SERVICE.new({"coins": 100, "current_day": 20, "owned_growth_ids": [&"growth.tool.pancake.wide_spreader", &"growth.equipment.pancake.intermediate", &"growth.automation.pancake.auto_sauce_brush"], "unlocked_area_ids": [&"area.pancake"]})
	var press_purchase: Dictionary = press_ready.purchase(&"growth.automation.pancake.press_once")
	_check(bool(press_purchase.get("success", false)) and int(press_purchase.get("charged_coins", 0)) == 60, "press automation costs the confirmed 60 coins after all prerequisites")
	if _failures.is_empty():
		print("FIVE_AREA_PROGRESSION_SERVICE_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("FIVE_AREA_PROGRESSION_SERVICE_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _growth_ids(items: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for item_variant in items:
		result.append(StringName(Dictionary(item_variant).get("growth_id", &"")))
	return result


func _path_stage_ids(unlocked_areas: Array[StringName], owned_growths: Array[StringName]) -> Array[StringName]:
	var completed_tutorials := unlocked_areas.duplicate()
	var stage = SERVICE.new({
		"coins": 1000,
		"reputation": 999,
		"current_day": 30,
		"unlocked_area_ids": unlocked_areas,
		"owned_growth_ids": owned_growths,
		"area_mastery_details": {
			&"area.pancake": {"qualified": 99, "a_grade": 99},
			&"area.packaged_drink": {"correct_temperature": 99},
			&"area.youtiao": {"qualified": 99, "a_grade": 99},
			&"area.fresh_soy_milk": {"qualified": 99, "a_grade": 99},
		},
		"tutorial": {"completed_area_ids": completed_tutorials, "queue_area_ids": [], "active_kind": &"", "active_id": &""},
	})
	return _growth_ids(Array(stage.growth_recommendations(3).get("recommended", [])))
