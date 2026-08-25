extends SceneTree

const GENERATOR = preload("res://scripts/services/five_area_pancake_order_generator.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var day_one := {
		"unlocked_stock_ids": [&"stock.pancake.batter", &"stock.pancake.egg"],
	}
	var tutorial := {"active_kind": &"area", "active_id": &"area.pancake"}
	var first: Dictionary = GENERATOR.generate(day_one, tutorial, 0)
	var first_order: Dictionary = first.get("order", {})
	_check(bool(first.get("success", false)) and bool(first_order.get("tutorial_no_countdown", false)) and StringName(first_order.get("id", &"")) == &"order.pancake.egg" and Array(first_order.get("sauces", [])).is_empty(), "pancake area tutorial uses the unlocked egg-only order")
	var normal: Dictionary = GENERATOR.generate(day_one, {}, 0)
	var normal_order: Dictionary = normal.get("order", {})
	_check(bool(normal.get("success", false)) and StringName(normal_order.get("id", &"")) == &"order.pancake.egg", "locked ingredients never enter the day-one order pool")
	var sweet_unlocked := day_one.duplicate(true)
	sweet_unlocked["unlocked_stock_ids"].append(&"stock.pancake.sauce.sweet_flour")
	_check(GENERATOR._eligible_template_ids(sweet_unlocked).has(&"order.pancake.egg_sweet"), "sweet-flour unlock adds the egg-and-sauce order")
	var baocui_unlocked := sweet_unlocked.duplicate(true)
	baocui_unlocked["unlocked_stock_ids"].append(&"stock.pancake.baocui")
	_check(GENERATOR._eligible_template_ids(baocui_unlocked).has(&"order.pancake.crisp"), "baocui unlock adds the crisp order")
	var scallion_unlocked := baocui_unlocked.duplicate(true)
	scallion_unlocked["unlocked_stock_ids"].append(&"stock.pancake.scallion")
	_check(GENERATOR._eligible_template_ids(scallion_unlocked).has(&"order.pancake.classic"), "scallion unlock restores the classic order")
	var fully_unlocked := day_one.duplicate(true)
	fully_unlocked["unlocked_stock_ids"] += [&"stock.pancake.sauce.sweet_flour", &"stock.pancake.baocui", &"stock.pancake.scallion", &"stock.pancake.sauce.red_chili", &"stock.pancake.ham_sausage", &"stock.pancake.meat_floss", &"stock.pancake.pork_tenderloin", &"stock.pancake.coriander", &"stock.pancake.preserved_mustard"]
	var found_double_sauce := false
	for cursor in 16:
		var candidate: Dictionary = GENERATOR.generate(fully_unlocked, {}, cursor)
		var order: Dictionary = candidate.get("order", {})
		_check(Array(order.get("sauces", [])).size() <= 2, "formal pancake generator never asks for a third sauce")
		found_double_sauce = found_double_sauce or Array(order.get("sauces", [])).size() == 2
	_check(found_double_sauce, "confirmed double-sauce template remains eligible after its content unlocks")
	var recipe_unlocked := fully_unlocked.duplicate(true)
	recipe_unlocked["unlocked_recipe_ids"] = [&"recipe.pancake.base", &"recipe.youtiao.plain"]
	var found_youtiao_order := false
	for cursor in 20:
		var candidate: Dictionary = GENERATOR.generate(recipe_unlocked, {}, cursor)
		var order: Dictionary = candidate.get("order", {})
		if StringName(order.get("id", &"")) != &"order.pancake.youtiao_scallion":
			continue
		found_youtiao_order = PackedStringArray(order.get("ingredients", PackedStringArray())) == PackedStringArray(["egg", "youtiao", "scallion"]) and PackedStringArray(order.get("sauces", PackedStringArray())) == PackedStringArray(["sweet_flour"]) and int(order.get("payment_coins", 0)) == 12 and is_equal_approx(float(order.get("time_limit", 0.0)), 72.0)
	_check(found_youtiao_order, "plain-youtiao recipe unlock enables the egg+youtiao+scallion+sweet-sauce order")
	var recipe_locked_youtiao := GENERATOR._eligible_template_ids(fully_unlocked)
	_check(not recipe_locked_youtiao.has(&"order.pancake.youtiao_scallion"), "youtiao pancake order stays ineligible before the plain-youtiao recipe unlock")
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
