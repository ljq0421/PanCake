extends SceneTree

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(
		int(CATALOG.product_definition(&"product.fresh_soy_milk.yellow_bean").get("material_cost", 0)) == 2,
		"yellow-soy material cost remains configured",
	)
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
	progression.set("unlocked_stock_ids", {&"stock.youtiao.plain_dough": true})
	progression.set("owned_growth_ids", {&"growth.capacity.pancake_holding_tray.two_slots": true, &"growth.capacity.youtiao_finished_tray": true})

	var inventory := Dictionary(session.call("inventory_snapshot"))
	for stock_id in inventory.keys():
		inventory[stock_id] = 0
	inventory["stock.pancake.egg"] = 2
	inventory["stock.pancake.scallion"] = 3
	inventory["stock.youtiao.plain_dough"] = 3
	session.call("save_inventory", inventory)
	var griddle_snapshot := {
		"version": 1,
		"griddle_count": 1,
		"active_index": 0,
		"product_sequence": 2,
		"slots": [
			{
				"state": 6,
				"applied_ingredient_ids": PackedStringArray(["stock.pancake.egg", "stock.pancake.scallion"]),
				"applied_sauce_ids": PackedStringArray(["stock.pancake.sauce.sweet_flour"]),
				"ready_product": {
					"product_instance_id": &"day.end.griddle.pancake",
					"area_id": &"area.pancake",
					"product_id": &"product.pancake.custom",
					"material_cost": 4,
				},
			},
		],
	}
	session.call("save_five_area_pancake_griddles", griddle_snapshot)
	var youtiao_load := Dictionary(session.call("load_f3_youtiao", &"recipe.youtiao.plain", 1))
	_check(bool(youtiao_load.get("success", false)), "fixture loads one machine work-in-progress batch")
	var soy_empty_cup := Dictionary(session.call("take_f4_soy_empty_cup"))
	var soy_filled_cup := Dictionary(session.call("fill_f4_soy_empty_cup", 1.0))
	_check(bool(soy_empty_cup.get("success", false)) and bool(soy_filled_cup.get("success", false)), "fixture prepares one finished soy cup")
	var tray_product := {
		"product_instance_id": &"day.end.tray.pancake",
		"area_id": &"area.pancake",
		"product_id": &"product.pancake.custom",
		"material_cost": 4,
		"score": 90.0,
	}
	var tray_store := Dictionary(session.call("store_pancake_product", tray_product))
	_check(bool(tray_store.get("success", false)), "fixture stores one finished pancake in the holding tray")
	var staged_product := {
		"product_instance_id": &"day.end.staged.youtiao",
		"area_id": &"area.youtiao",
		"product_id": &"product.youtiao.plain",
		"material_cost": 2,
		"status": &"available",
	}
	session.call("_append_prepared_product", &"slot.04", staged_product)
	session.call("_append_prepared_product", &"slot.04", {
		"product_instance_id": &"day.end.prepared.youtiao",
		"area_id": &"area.youtiao",
		"product_id": &"product.youtiao.plain",
		"material_cost": 2,
		"status": &"available",
	})
	var opened := Dictionary(session.call("open_formal_order", [{"area_id": &"area.youtiao", "product_id": &"product.youtiao.plain", "quantity": 1}]))
	var order_id := StringName(Dictionary(opened.get("order", {})).get("order_id", &""))
	var staged := Dictionary(session.call("stage_product_to_order", {"source_kind": &"prepared_product_slot", "source_slot_id": &"slot.04", "source_index": -1, "product_id": &"product.youtiao.plain"}, order_id, 0))
	_check(bool(staged.get("success", false)), "fixture stages one finished product onto an unsettled customer order")
	var sold := Dictionary(session.call("record_order_completed", {"id": &"day.end.sold", "title": "已售煎饼"}, {
		"area_id": &"area.pancake",
		"score": 90.0,
		"grade": &"A",
		"material_cost": 3,
	}, 8))
	_check(bool(sold.get("success", false)), "fixture records one sold product with a non-zero material cost")
	var coins_before_day_end := int(Dictionary(session.call("five_area_progression_snapshot")).get("coins", 0))
	var pending_payments_before_day_end := Array(session.call("pending_order_payments"))
	var pending_payment_total := 0
	for payment_value in pending_payments_before_day_end:
		pending_payment_total += int(Dictionary(payment_value).get("amount", 0))

	var bill := Dictionary(session.call("end_business_day"))
	_check(
		Array(session.call("pending_order_payments")).is_empty()
		and int(Dictionary(session.call("five_area_progression_snapshot")).get("coins", 0)) == coins_before_day_end + pending_payment_total,
		"day end automatically collects every pending payment before the next business day",
	)
	_check(
		int(Dictionary(bill.get("day_end_payment_collection", {})).get("amount", -1)) == pending_payment_total,
		"day-end bill records the unified payment collection",
	)
	var cleared_inventory := Dictionary(session.call("inventory_snapshot"))
	_check(cleared_inventory.values().all(func(value): return int(value) == 0), "day end clears every remaining stock lane")
	_check(StringName(Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer")).get("state", &"")) == &"idle", "day end clears youtiao work in progress")
	var soy_after_day_end := Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine"))
	_check(StringName(soy_after_day_end.get("cup_state", &"")) == &"ready" and Dictionary(soy_after_day_end.get("cup", {})).is_empty(), "day end clears finished soy cups")
	_check(Array(Dictionary(session.call("five_area_pancake_griddles_snapshot")).get("slots", [])).is_empty(), "day end clears pancake work in progress")
	_check(Array(Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine")).get("output_rack", [])).all(func(value): return Dictionary(value).is_empty()), "day end clears finished soy output")
	_check(Array(Dictionary(session.call("pancake_holding_tray_snapshot")).get("slots", [])).all(func(value): return Dictionary(value).is_empty()), "day end clears finished pancakes from the holding tray")
	_check(Array(Dictionary(session.call("prepared_product_slots_snapshot")).get("slot.04", [])).is_empty(), "day end clears finished youtiao from prepared slots")
	_check(Array(session.call("active_formal_orders")).is_empty(), "day end clears all unsettled customer orders")
	_check(Array(bill.get("inventory_waste", [])).size() == 3, "day end exposes every non-empty leftover stock row")
	_check(Array(bill.get("production_waste", [])).size() == 3, "day end exposes work in progress and finished machine output")
	_check(Array(bill.get("tray_waste", [])).size() == 1, "day end exposes finished pancake holding waste")
	_check(Array(bill.get("prepared_product_slot_waste", [])).size() == 1, "day end exposes finished youtiao holding waste")
	_check(Array(bill.get("abandoned_product_waste", [])).size() == 1, "day end counts a staged but unsettled product as unsold waste")
	_check(int(bill.get("sold_material_cost", -1)) == 3 and int(bill.get("waste_cost", 0)) == 25 and int(bill.get("total_cost", 0)) == 28 and int(bill.get("total_profit", 0)) == -20, "sold material and unsold waste enter daily cost exactly once")
	var repeated := Dictionary(session.call("end_business_day"))
	_check(int(repeated.get("waste_cost", 0)) == 25 and int(repeated.get("total_cost", 0)) == 28, "repeated day end does not duplicate clearance cost")
	_check(int(repeated.get("event_count", -1)) == int(bill.get("event_count", -2)), "repeated day end does not append ledger events")
	_check(Array(repeated.get("inventory_waste", [])) == Array(bill.get("inventory_waste", [])), "repeated day end preserves inventory waste details")
	_check(Array(repeated.get("production_waste", [])) == Array(bill.get("production_waste", [])), "repeated day end preserves production waste details")
	_check(Array(repeated.get("tray_waste", [])) == Array(bill.get("tray_waste", [])), "repeated day end preserves tray waste details")
	_check(Array(repeated.get("prepared_product_slot_waste", [])) == Array(bill.get("prepared_product_slot_waste", [])), "repeated day end preserves prepared-product waste details")
	_check(Array(repeated.get("abandoned_product_waste", [])) == Array(bill.get("abandoned_product_waste", [])), "repeated day end preserves abandoned-product waste details")
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
