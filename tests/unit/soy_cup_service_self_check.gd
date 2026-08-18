extends SceneTree

const MODEL := preload("res://scripts/gameplay/fresh_soy_milk_machine_model.gd")
const ORDERS := preload("res://scripts/services/five_area_order_service.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	var machine: RefCounted = MODEL.new(0, true)
	_check(bool(machine.call("take_empty_cup").get("success", false)), "player can take an empty soy cup")
	var partial := Dictionary(machine.call("fill_held_cup", 0.2))
	var partial_cup := Dictionary(partial.get("cup", {}))
	_check(float(partial.get("fill_ratio", 1.0)) < 1.0 and float(partial_cup.get("quality_multiplier", 1.0)) < 1.0, "early release creates a partial cup with reduced payout")
	_check(bool(machine.call("add_sugar").get("success", false)) and bool(machine.call("add_sugar").get("success", false)), "filled cup accepts one or two sugar servings")
	_check(StringName(machine.call("add_sugar").get("reason", &"")) == &"sugar_limit_reached", "a cup cannot exceed two sugar servings")
	var two_sugar := Dictionary(machine.call("preview_cup").get("product", {}))
	_check(int(two_sugar.get("sugar_servings", 0)) == 2, "cup preserves the multi-sugar selection")
	_check(bool(machine.call("take_filled_cup").get("success", false)) and StringName(machine.call("snapshot").get("cup_state", &"")) == &"ready", "delivery collection clears the serving position")

	var full_machine: RefCounted = MODEL.new(0, true)
	full_machine.call("take_empty_cup")
	var full := Dictionary(full_machine.call("fill_held_cup", 0.8))
	_check(bool(full.get("is_full", false)) and is_equal_approx(float(full.get("fill_ratio", 0.0)), 1.0), "holding the spout for 0.8 seconds fills the cup")

	var flavour_machine: RefCounted = MODEL.new(0, true)
	_check(StringName(flavour_machine.call("select_recipe", &"recipe.fresh_soy_milk.black_bean").get("reason", &"")) == &"soy_flavor_locked", "base machine only exposes yellow-soy flavour")
	flavour_machine.call("configure_available_recipes", [&"recipe.fresh_soy_milk.yellow_bean", &"recipe.fresh_soy_milk.black_bean"])
	_check(bool(flavour_machine.call("select_recipe", &"recipe.fresh_soy_milk.black_bean").get("success", false)), "unlocked flavour button can select black-soy output")
	flavour_machine.call("take_empty_cup")
	var black_cup := Dictionary(flavour_machine.call("fill_held_cup", 0.8).get("cup", {}))
	_check(StringName(black_cup.get("product_id", &"")) == &"product.fresh_soy_milk.black_bean", "selected flavour is preserved in the served cup")

	var assisted_machine: RefCounted = MODEL.new(0, true)
	assisted_machine.call("configure_upgrades", true, true, true)
	assisted_machine.call("take_empty_cup")
	var assisted_cup := Dictionary(assisted_machine.call("fill_held_cup", 0.1).get("cup", {}))
	_check(is_equal_approx(float(assisted_cup.get("fill_ratio", 0.0)), 0.125) and float(assisted_cup.get("quality", 0.0)) < 100.0, "manual release keeps its exact pour level even when legacy automation is enabled")

	var orders: RefCounted = ORDERS.new()
	var opened := Dictionary(orders.call("open_order", [{
		"area_id": &"area.fresh_soy_milk",
		"product_id": &"product.fresh_soy_milk.yellow_bean",
		"sugar_servings": 1,
	}]))
	var order_id := StringName(Dictionary(opened.get("order", {})).get("order_id", &""))
	var wrong_sweetness := {"product_instance_id": &"soy.wrong", "product_id": &"product.fresh_soy_milk.yellow_bean", "sugar_servings": 0}
	var normal_sugar := {"product_instance_id": &"soy.right", "product_id": &"product.fresh_soy_milk.yellow_bean", "sugar_servings": 1}
	_check(PackedStringArray(orders.call("preview_attach_product", order_id, 0, wrong_sweetness).get("mismatch_reasons", [])).has("sugar_servings"), "wrong sweetness is an order mismatch")
	_check(bool(orders.call("preview_attach_product", order_id, 0, normal_sugar).get("will_match", false)), "matching sweetness is accepted")

	if failures.is_empty():
		print("SOY_CUP_SERVICE_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures.append(message)
