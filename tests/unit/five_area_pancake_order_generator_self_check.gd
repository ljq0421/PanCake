extends SceneTree

const GENERATOR = preload("res://scripts/services/five_area_pancake_order_generator.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var day_one := {
		"unlocked_stock_ids": [&"stock.pancake.batter", &"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.scallion", &"stock.pancake.sauce.sweet_flour"],
	}
	var tutorial := {"active_kind": &"area", "active_id": &"area.pancake"}
	var first: Dictionary = GENERATOR.generate(day_one, tutorial, 0)
	var first_order: Dictionary = first.get("order", {})
	_check(bool(first.get("success", false)) and bool(first_order.get("tutorial_no_countdown", false)) and Array(first_order.get("sauces", [])).size() == 1, "pancake area tutorial uses an unlocked no-countdown base order")
	var normal: Dictionary = GENERATOR.generate(day_one, {}, 0)
	var normal_order: Dictionary = normal.get("order", {})
	_check(bool(normal.get("success", false)) and normal_order.get("id", &"") in [&"order.pancake.classic", &"order.pancake.scallion_light"], "locked add-ons and chili never enter the day-one order pool")
	var fully_unlocked := day_one.duplicate(true)
	fully_unlocked["unlocked_stock_ids"] += [&"stock.pancake.sauce.red_chili", &"stock.pancake.ham_sausage", &"stock.pancake.meat_floss", &"stock.pancake.pork_tenderloin", &"stock.pancake.coriander", &"stock.pancake.preserved_mustard"]
	var found_double_sauce := false
	for cursor in 16:
		var candidate: Dictionary = GENERATOR.generate(fully_unlocked, {}, cursor)
		var order: Dictionary = candidate.get("order", {})
		_check(Array(order.get("sauces", [])).size() <= 2, "formal pancake generator never asks for a third sauce")
		found_double_sauce = found_double_sauce or Array(order.get("sauces", [])).size() == 2
	_check(found_double_sauce, "confirmed double-sauce template remains eligible after its content unlocks")
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("FIVE_AREA_PANCAKE_ORDER_GENERATOR_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("FIVE_AREA_PANCAKE_ORDER_GENERATOR_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
