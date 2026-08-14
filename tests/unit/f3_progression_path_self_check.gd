extends SceneTree

const SERVICE := preload("res://scripts/services/five_area_progression_service.gd")
var _failures: Array[String] = []


func _initialize() -> void:
	var locked: RefCounted = SERVICE.new({"coins": 500, "current_day": 3, "reputation": 19, "area_mastery_details": {"area.pancake": {"qualified": 6}}, "tutorial": {"completed_area_ids": ["area.pancake"], "queue_area_ids": [], "active_kind": "", "active_id": ""}})
	_check(bool(locked.call("purchase_status", &"growth.area.packaged_drink").get("can_purchase", false)), "drink area uses six qualified pancakes plus pancake tutorial instead of reputation")
	_check(bool(locked.call("purchase", &"growth.area.packaged_drink").get("success", false)), "drink area purchase opens at Q6 with the pancake tutorial complete")
	locked.call("set_day_open", false)
	locked.call("begin_next_business_day")
	_check(locked.call("owns_area", &"area.packaged_drink") and not locked.call("owns_device", &"device.packaged_drink_heater") and locked.call("owns_product", &"product.packaged_drink.milk"), "drink cabinet activation grants milk but leaves the heater independently locked")
	locked.call("advance_tutorial_for_new_business_day")
	locked.call("complete_tutorial", &"area", &"area.packaged_drink")
	_check(bool(locked.call("purchase", &"growth.equipment.packaged_drink.basic").get("success", false)), "completed cabinet teaching unlocks the separate 12-coin base heater purchase")
	locked.call("set_day_open", false)
	locked.call("begin_next_business_day")
	_check(locked.call("owns_device", &"device.packaged_drink_heater") and int(locked.call("device_tier", &"device.packaged_drink_heater")) == 0, "base heater activates at tier zero on the following day")
	var first: Dictionary = locked.call("record_area_result", &"area.packaged_drink", {"settlement_id": &"settlement.drink.1", "correct_temperature": true})
	var duplicate: Dictionary = locked.call("record_area_result", &"area.packaged_drink", {"settlement_id": &"settlement.drink.1", "correct_temperature": true})
	_check(int(first.get("mastery_gained", 0)) == 1 and not bool(duplicate.get("changed", true)) and int(locked.call("mastery_value", &"area.packaged_drink")) == 1, "drink mastery deduplicates settlement IDs")
	locked.call("record_area_result", &"area.packaged_drink", {"settlement_id": &"settlement.drink.fail", "correct_temperature": false})
	_check(int(Dictionary(locked.call("mastery_snapshot", &"area.packaged_drink")).get("correct_streak_current", -1)) == 0, "drink failure resets only the current streak")

	var drink_path: RefCounted = SERVICE.new({"coins": 500, "current_day": 10, "reputation": 200, "owned_growth_ids": ["growth.equipment.packaged_drink.basic"], "unlocked_area_ids": ["area.pancake", "area.packaged_drink"], "unlocked_recipe_ids": ["recipe.pancake.base", "recipe.packaged_drink.milk"], "unlocked_product_ids": ["product.pancake.custom", "product.packaged_drink.milk"], "unlocked_stock_ids": ["stock.packaged_drink.milk"], "device_tiers": {"device.pancake_griddle": 1, "device.packaged_drink_heater": 0}, "area_mastery_details": {"area.packaged_drink": {"correct_temperature": 10, "correct_streak_current": 3, "correct_streak_best": 3}}, "tutorial": {"completed_area_ids": ["area.pancake", "area.packaged_drink"], "completed_device_ids": ["device.packaged_drink_heater"], "queue_area_ids": [], "active_kind": "", "active_id": ""}})
	_check(bool(drink_path.call("purchase_status", &"growth.product.packaged_drink.soy_milk").get("can_purchase", false)), "soy milk content opens at reputation 30")
	_check(bool(drink_path.call("purchase_status", &"growth.equipment.packaged_drink.intermediate").get("can_purchase", false)), "intermediate drink heater opens at six correct-temperature results")
	_check(drink_path.call("purchase_status", &"growth.product.packaged_drink.walnut").get("reason") == &"day_requirement", "walnut drink remains locked before business day 11")
	drink_path.set("current_day", 11)
	_check(bool(drink_path.call("purchase_status", &"growth.product.packaged_drink.walnut").get("can_purchase", false)), "walnut drink opens on business day 11")
	_check(bool(drink_path.call("purchase_status", &"growth.area.youtiao").get("can_purchase", false)), "youtiao area opens at reputation 60 only after both cabinet and heater tutorials")
	var heater_tutorial_missing: RefCounted = SERVICE.new(drink_path.call("snapshot"))
	heater_tutorial_missing.set("tutorial_completed_device_ids", {})
	var blocked_youtiao := Dictionary(heater_tutorial_missing.call("purchase_status", &"growth.area.youtiao"))
	_check(not bool(blocked_youtiao.get("can_purchase", true)) and StringName(blocked_youtiao.get("required_tutorial_device_id", &"")) == &"device.packaged_drink_heater", "youtiao cannot bypass the unfinished hot-drink tutorial")

	var advanced: RefCounted = SERVICE.new({"coins": 500, "current_day": 30, "reputation": 300, "owned_growth_ids": ["growth.automation.youtiao.auto_lift"], "unlocked_area_ids": ["area.pancake", "area.packaged_drink", "area.youtiao", "area.fresh_soy_milk", "area.steamer"], "area_mastery_details": {"area.packaged_drink": {"correct_temperature": 30, "correct_streak_best": 8}, "area.youtiao": {"qualified": 25, "a_grade": 10}}, "tutorial": {"completed_area_ids": ["area.pancake", "area.packaged_drink", "area.youtiao"], "queue_area_ids": [], "active_kind": "", "active_id": ""}})
	_check(bool(advanced.call("purchase_status", &"growth.equipment.packaged_drink.advanced").get("can_purchase", false)), "advanced drink heater requires all areas and a best correct streak of eight")
	_check(bool(advanced.call("purchase_status", &"growth.equipment.youtiao.advanced").get("can_purchase", false)), "advanced fryer opens at eight A-grade youtiao with all areas")
	_check(advanced.call("purchase_status", &"growth.automation.youtiao.auto_load").get("reason") == &"unknown_growth", "retired youtiao auto load is absent")
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("F3_PROGRESSION_PATH_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("F3_PROGRESSION_PATH_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
