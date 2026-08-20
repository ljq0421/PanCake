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
	session.call("save_inventory", inventory)
	progression.set("coins", 100)
	progression.set("unlocked_automation_ids", {&"automation.fresh_soy_milk.auto_yellow_restock": true})
	session.call("advance_f3_production", 0.24)
	_check(int(session.call("inventory_snapshot").get("stock.fresh_soy_milk.yellow_bean", 0)) == 0, "auto restock waits for the full 0.25-second unit")
	session.call("advance_f3_production", 0.01)
	_check(int(session.call("inventory_snapshot").get("stock.fresh_soy_milk.yellow_bean", 0)) == 1 and int(progression.get("coins")) == 98, "auto restock buys one yellow bean at normal price after 0.25 seconds")

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
	progression.set("unlocked_recipe_ids", {&"recipe.pancake.base": true, &"recipe.youtiao.plain": true, &"recipe.fresh_soy_milk.yellow_bean": true})
	progression.set("unlocked_product_ids", {&"product.pancake.custom": true, &"product.youtiao.plain": true, &"product.fresh_soy_milk.yellow_bean": true})
	progression.set("unlocked_stock_ids", {&"stock.pancake.batter": true, &"stock.pancake.egg": true, &"stock.pancake.baocui": true, &"stock.pancake.scallion": true, &"stock.pancake.sauce.sweet_flour": true, &"stock.youtiao.plain_dough": true, &"stock.fresh_soy_milk.yellow_bean": true})


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
