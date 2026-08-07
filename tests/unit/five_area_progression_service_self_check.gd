extends SceneTree

const SERVICE = preload("res://scripts/services/five_area_progression_service.gd")
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
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
