extends SceneTree

const GENERATOR := preload("res://scripts/services/five_area_playable_order_generator.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession is available")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	var progression: RefCounted = session.call("progression_service")
	_configure_full_soy(progression)
	var order_service: RefCounted = session.call("order_service")
	order_service.call("abandon_all_open_orders", &"test_setup")

	var inventory := Dictionary(session.call("inventory_snapshot"))
	inventory["stock.fresh_soy_milk.yellow_bean"] = 0
	inventory["stock.fresh_soy_milk.black_bean"] = 4
	inventory["stock.fresh_soy_milk.red_bean"] = 4
	session.call("save_inventory", inventory)
	progression.set("coins", 100)
	progression.set("unlocked_automation_ids", {&"automation.fresh_soy_milk.auto_yellow_restock": true})
	session.call("advance_f3_production", 0.24)
	_check(int(session.call("inventory_snapshot").get("stock.fresh_soy_milk.yellow_bean", 0)) == 0, "auto restock waits for the full 0.25-second unit")
	session.call("advance_f3_production", 0.01)
	_check(int(session.call("inventory_snapshot").get("stock.fresh_soy_milk.yellow_bean", 0)) == 1 and int(progression.get("coins")) == 98, "auto restock buys one yellow bean at normal price after 0.25 seconds")

	progression.set("unlocked_automation_ids", {&"automation.fresh_soy_milk.auto_production": true})
	var black_item := {"area_id": &"area.fresh_soy_milk", "product_id": &"product.fresh_soy_milk.black_bean", "quantity": 1, "ingredient_ids": PackedStringArray(), "sauce_ids": PackedStringArray()}
	var first := Dictionary(session.call("open_formal_order", [black_item], {"patience_seconds": 9.0, "base_coins": 9}))
	var second := Dictionary(session.call("open_formal_order", [black_item], {"patience_seconds": 15.0, "base_coins": 9}))
	session.call("open_formal_order", [{"area_id": &"area.fresh_soy_milk", "product_id": &"product.fresh_soy_milk.yellow_bean", "quantity": 1, "ingredient_ids": PackedStringArray(), "sauce_ids": PackedStringArray()}], {"patience_seconds": 25.0, "base_coins": 7})
	_check(bool(first.get("success", false)) and bool(second.get("success", false)), "automation test opens two black-bean demands")
	session.call("advance_f3_production", 0.01)
	var machine := Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine"))
	_check(StringName(machine.get("state", &"")) == &"grinding" and StringName(machine.get("recipe_id", &"")) == &"recipe.fresh_soy_milk.black_bean" and int(machine.get("quantity", 0)) == 2, "auto production prioritizes the least-patient uncovered demand and batches matching orders")
	_check(int(session.call("inventory_snapshot").get("stock.fresh_soy_milk.black_bean", 0)) == 2, "auto production consumes exactly the batched bean quantity")

	var generation_progression := Dictionary(progression.call("snapshot"))
	var saw_two := false
	var saw_three := false
	for seed in range(24):
		var candidate := Dictionary(GENERATOR._product_candidate(&"area.fresh_soy_milk", &"product.fresh_soy_milk.multigrain", generation_progression, seed, 3, false))
		var ids := PackedStringArray(Dictionary(Array(candidate.get("items", []))[0]).get("ingredient_ids", PackedStringArray()))
		saw_two = saw_two or ids.size() == 2
		saw_three = saw_three or ids.size() == 3
		var repeated := Dictionary(GENERATOR._product_candidate(&"area.fresh_soy_milk", &"product.fresh_soy_milk.multigrain", generation_progression, seed, 3, false))
		_check(ids == PackedStringArray(Dictionary(Array(repeated.get("items", []))[0]).get("ingredient_ids", PackedStringArray())), "multigrain composition is deterministic for seed %d" % seed)
	_check(saw_two and saw_three, "multigrain order generation covers deterministic two-bean and three-bean combinations")

	var combo_order := {"items": [
		{"area_id": &"area.pancake", "product_id": &"product.pancake.custom", "quantity": 1, "base_price_coins": 23},
		{"area_id": &"area.fresh_soy_milk", "product_id": &"product.fresh_soy_milk.yellow_bean", "quantity": 1, "base_price_coins": 7},
	]}
	var combo_results := [
		{"products": [{"quality_multiplier": 1.0}]},
		{"products": [{"quality_multiplier": 0.5}]},
	]
	progression.set("owned_growth_ids", {})
	_check(int(session.call("_quality_adjusted_formal_quote", combo_order, combo_results, 35)) == 31, "C-quality multiplier changes only the soy part of a custom-pancake combo quote")
	progression.set("owned_growth_ids", {&"growth.pricing.fresh_soy_milk.premium": true})
	_check(int(session.call("_quality_adjusted_formal_quote", combo_order, combo_results, 35)) == 32, "soy premium multiplies only the adjusted soy part by 1.3 without doubling multigrain")
	_finish()


func _configure_full_soy(progression: RefCounted) -> void:
	progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.youtiao": true, &"area.fresh_soy_milk": true})
	progression.set("device_tiers", {&"device.pancake_griddle": 0, &"device.youtiao_fryer": 0, &"device.fresh_soy_milk_machine": 0})
	progression.set("unlocked_recipe_ids", {&"recipe.pancake.base": true, &"recipe.youtiao.plain": true, &"recipe.fresh_soy_milk.yellow_bean": true, &"recipe.fresh_soy_milk.black_bean": true, &"recipe.fresh_soy_milk.red_bean": true, &"recipe.fresh_soy_milk.multigrain": true})
	progression.set("unlocked_product_ids", {&"product.pancake.custom": true, &"product.youtiao.plain": true, &"product.fresh_soy_milk.yellow_bean": true, &"product.fresh_soy_milk.black_bean": true, &"product.fresh_soy_milk.red_bean": true, &"product.fresh_soy_milk.multigrain": true})
	progression.set("unlocked_stock_ids", {&"stock.pancake.batter": true, &"stock.pancake.egg": true, &"stock.pancake.baocui": true, &"stock.pancake.scallion": true, &"stock.pancake.sauce.sweet_flour": true, &"stock.youtiao.plain_dough": true, &"stock.fresh_soy_milk.yellow_bean": true, &"stock.fresh_soy_milk.black_bean": true, &"stock.fresh_soy_milk.red_bean": true})


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("FRESH_SOY_MILK_AUTOMATION_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("FRESH_SOY_MILK_AUTOMATION_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
