extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession exists")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	var progression: RefCounted = session.call("progression_service")
	progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.youtiao": true, &"area.fresh_soy_milk": true})
	progression.set("device_tiers", {&"device.pancake_griddle": 0, &"device.youtiao_fryer": 0, &"device.fresh_soy_milk_machine": 0})
	progression.set("unlocked_recipe_ids", {&"recipe.pancake.base": true, &"recipe.youtiao.plain": true, &"recipe.fresh_soy_milk.yellow_bean": true})
	progression.set("unlocked_product_ids", {&"product.pancake.custom": true, &"product.youtiao.plain": true, &"product.fresh_soy_milk.yellow_bean": true})
	progression.set("unlocked_stock_ids", {&"stock.youtiao.plain_dough": true, &"stock.fresh_soy_milk.yellow_bean": true})

	var inventory := Dictionary(session.call("inventory_snapshot"))
	for stock_id in inventory.keys():
		inventory[stock_id] = 0
	inventory["stock.pancake.egg"] = 2
	inventory["stock.pancake.scallion"] = 3
	inventory["stock.youtiao.plain_dough"] = 3
	inventory["stock.fresh_soy_milk.yellow_bean"] = 2
	session.call("save_inventory", inventory)
	var griddle_snapshot := {
		"version": 1,
		"griddle_count": 1,
		"active_index": 0,
		"product_sequence": 1,
		"slots": [{
			"state": 1,
			"applied_ingredient_ids": PackedStringArray(),
			"applied_sauce_ids": PackedStringArray(),
			"ready_product": {},
		}],
	}
	session.call("save_five_area_pancake_griddles", griddle_snapshot)
	var youtiao_load := Dictionary(session.call("load_f3_youtiao", &"recipe.youtiao.plain", 1))
	var soy_load := Dictionary(session.call("load_f4_soy", &"recipe.fresh_soy_milk.yellow_bean", 1))
	_check(bool(youtiao_load.get("success", false)) and bool(soy_load.get("success", false)), "fixture loads two machine work-in-progress batches")
	var staged_product := {
		"product_instance_id": &"day.end.staged.youtiao",
		"area_id": &"area.youtiao",
		"product_id": &"product.youtiao.plain",
		"material_cost": 2,
		"status": &"available",
	}
	session.call("_append_prepared_product", &"slot.04", staged_product)
	var opened := Dictionary(session.call("open_formal_order", [{"area_id": &"area.youtiao", "product_id": &"product.youtiao.plain", "quantity": 1}]))
	var order_id := StringName(Dictionary(opened.get("order", {})).get("order_id", &""))
	var staged := Dictionary(session.call("stage_product_to_order", {"source_kind": &"prepared_product_slot", "source_slot_id": &"slot.04", "source_index": -1, "product_id": &"product.youtiao.plain"}, order_id, 0))
	_check(bool(staged.get("success", false)), "fixture stages one finished product onto an unsettled customer order")

	var bill := Dictionary(session.call("end_business_day"))
	var cleared_inventory := Dictionary(session.call("inventory_snapshot"))
	_check(cleared_inventory.values().all(func(value): return int(value) == 0), "day end clears every remaining stock lane")
	_check(StringName(Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer")).get("state", &"")) == &"idle", "day end clears youtiao work in progress")
	_check(StringName(Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine")).get("state", &"")) == &"idle", "day end clears soy work in progress")
	_check(Array(Dictionary(session.call("five_area_pancake_griddles_snapshot")).get("slots", [])).is_empty(), "day end clears pancake work in progress")
	_check(Array(bill.get("inventory_waste", [])).size() == 4, "day end exposes every non-empty leftover stock row")
	_check(Array(bill.get("production_waste", [])).size() == 3, "day end exposes pancake, youtiao, and soy production waste")
	_check(Array(bill.get("abandoned_product_waste", [])).size() == 1, "day end counts a staged but unsettled product as unsold waste")
	_check(int(bill.get("waste_cost", 0)) == 18 and int(bill.get("total_cost", 0)) == 18 and int(bill.get("total_profit", 0)) == -18, "leftovers and unsold work enter daily cost exactly once")
	var repeated := Dictionary(session.call("end_business_day"))
	_check(int(repeated.get("waste_cost", 0)) == 18 and int(repeated.get("total_cost", 0)) == 18, "repeated day end does not duplicate clearance cost")
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("DAY_END_CLEARANCE_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("DAY_END_CLEARANCE_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
