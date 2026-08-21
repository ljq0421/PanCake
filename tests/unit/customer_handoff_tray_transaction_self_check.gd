extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession autoload exists")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	_unlock_test_products(session)
	var inventory := Dictionary(session.call("inventory_snapshot"))
	inventory["stock.packaged_drink.milk"] = 5
	inventory["stock.packaged_drink.soy_milk"] = 2
	inventory["stock.pancake.batter"] = 3
	session.call("save_inventory", inventory)

	var room_order: Dictionary = session.call("open_formal_order", [{
		"area_id": &"area.packaged_drink",
		"product_id": &"product.packaged_drink.milk",
		"quantity": 2,
		"temperature_mode": &"room_temperature",
	}], {"base_coins": 6, "source": &"tray_transaction_test"})
	var room_order_id := StringName(Dictionary(room_order.get("order", {})).get("order_id", &""))
	var milk_source := {"source_kind": &"inventory", "source_index": 0, "product_id": &"product.packaged_drink.milk"}
	var soy_source := {"source_kind": &"inventory", "source_index": 1, "product_id": &"product.packaged_drink.soy_milk"}
	var first_stage: Dictionary = session.call("stage_product_to_order", milk_source, room_order_id, 0)
	var wrong_stage: Dictionary = session.call("stage_product_to_order", soy_source, room_order_id, 0)
	_check(bool(first_stage.get("success", false)) and bool(first_stage.get("will_match", false)), "matching room-temperature drink stages to the exact tray slot")
	_check(bool(wrong_stage.get("success", false)) and not bool(wrong_stage.get("will_match", true)) and Array(wrong_stage.get("mismatch_reasons", [])).has("product_id"), "wrong product still enters the requested slot and reports its mismatch")
	var stock_after_two := Dictionary(session.call("inventory_snapshot"))
	_check(int(stock_after_two.get("stock.packaged_drink.milk", 0)) == 4 and int(stock_after_two.get("stock.packaged_drink.soy_milk", 0)) == 1, "staging removes one physical unit from each source lane")
	var full_rejection: Dictionary = session.call("stage_product_to_order", milk_source, room_order_id, 0)
	_check(StringName(full_rejection.get("reason", &"")) == &"capacity_full" and int(Dictionary(session.call("inventory_snapshot")).get("stock.packaged_drink.milk", 0)) == 4, "full tray slot rejects before consuming source inventory")
	var returned: Dictionary = session.call("remove_staged_product", room_order_id, 0, &"return_stock")
	_check(bool(returned.get("success", false)) and int(Dictionary(session.call("inventory_snapshot")).get("stock.packaged_drink.soy_milk", 0)) == 2, "unheated packaged drink can return from tray to its original stock lane")
	var second_stage: Dictionary = session.call("stage_product_to_order", milk_source, room_order_id, 0)
	_check(bool(second_stage.get("success", false)), "same tray slot accepts the second requested physical unit after correction")

	var coins_before := int(Dictionary(session.call("five_area_progression_snapshot")).get("coins", 0))
	var handed_off: Dictionary = session.call("handoff_order_tray", room_order_id)
	var settlement_id := StringName(handed_off.get("settlement_id", &""))
	_check(bool(handed_off.get("success", false)) and bool(handed_off.get("order_success", false)) and not settlement_id.is_empty(), "complete stacked tray hands off through the formal settlement")
	_check(int(Dictionary(session.call("five_area_progression_snapshot")).get("coins", 0)) == coins_before and Array(session.call("pending_tray_payments")).size() == 1, "handoff creates a pending physical payment without auto-collecting coins")
	var collected: Dictionary = session.call("collect_tray_payment", settlement_id)
	var collected_again: Dictionary = session.call("collect_tray_payment", settlement_id)
	_check(bool(collected.get("success", false)) and int(Dictionary(session.call("five_area_progression_snapshot")).get("coins", 0)) == coins_before + int(collected.get("amount", 0)), "click collection credits the pending customer payment")
	_check(bool(collected_again.get("already_collected", false)) and int(Dictionary(session.call("five_area_progression_snapshot")).get("coins", 0)) == coins_before + int(collected.get("amount", 0)), "repeated coin collection cannot duplicate payment")
	_check(StringName(session.call("handoff_order_tray", room_order_id).get("reason", &"")) == &"order_not_active", "settled tray cannot be handed off a second time")

	var heated_order: Dictionary = session.call("open_formal_order", [{
		"area_id": &"area.packaged_drink",
		"product_id": &"product.packaged_drink.milk",
		"quantity": 1,
		"temperature_mode": &"heated",
	}])
	var heated_order_id := StringName(Dictionary(heated_order.get("order", {})).get("order_id", &""))
	var wrong_temperature: Dictionary = session.call("stage_product_to_order", milk_source, heated_order_id, 0)
	_check(bool(wrong_temperature.get("success", false)) and not bool(wrong_temperature.get("will_match", true)) and Array(wrong_temperature.get("mismatch_reasons", [])).has("temperature_mode"), "room-temperature drink can enter a heated request and remains a settlement-visible mistake")
	_check(bool(session.call("remove_staged_product", heated_order_id, 0, &"return_stock").get("success", false)), "unprocessed mismatched drink remains returnable before handoff")
	var incomplete: Dictionary = session.call("handoff_order_tray", heated_order_id)
	_check(StringName(incomplete.get("reason", &"")) == &"tray_incomplete" and int(Dictionary(Array(incomplete.get("missing_items", []))[0]).get("missing_quantity", 0)) == 1, "incomplete tray rebounds with an exact missing quantity")

	var consolation_order: Dictionary = session.call("open_formal_order", [{
		"area_id": &"area.packaged_drink",
		"product_id": &"product.packaged_drink.milk",
		"quantity": 1,
		"temperature_mode": &"heated",
	}], {"base_coins": 6})
	var consolation_order_id := StringName(Dictionary(consolation_order.get("order", {})).get("order_id", &""))
	var consolation_stage: Dictionary = session.call("stage_product_to_order", milk_source, consolation_order_id, 0)
	var consolation_settlement: Dictionary = session.call("handoff_order_tray", consolation_order_id)
	_check(
		bool(consolation_stage.get("success", false))
		and not bool(consolation_settlement.get("order_success", true))
		and int(consolation_settlement.get("earned_coins", 0)) == 1
		and int(consolation_settlement.get("consolation_coins", 0)) == 1
		and bool(consolation_settlement.get("payment_pending", false)),
		"a delivered but low-scoring order creates one collectible consolation coin"
	)
	var consolation_payment: Dictionary = session.call("collect_tray_payment", StringName(consolation_settlement.get("settlement_id", &"")))
	_check(bool(consolation_payment.get("success", false)) and int(consolation_payment.get("amount", 0)) == 1, "the consolation coin can be collected exactly like an ordinary payment")

	var pancake_order: Dictionary = session.call("open_formal_order", [{
		"area_id": &"area.pancake",
		"product_id": &"product.pancake.custom",
		"quantity": 1,
		"temperature_mode": &"normal",
	}])
	var pancake_order_id := StringName(Dictionary(pancake_order.get("order", {})).get("order_id", &""))
	var pancake_product := {
		"product_instance_id": &"test.pancake.ready.001",
		"area_id": &"area.pancake",
		"product_id": &"product.pancake.custom",
		"temperature_mode": &"normal",
		"ingredient_ids": PackedStringArray(),
		"sauce_ids": PackedStringArray(),
		"status": &"available",
		"quality": 82.0,
		"material_cost": 1,
	}
	var pancake_source := {"source_kind": &"pancake_ready", "source_index": -1, "product_id": &"product.pancake.custom", "product": pancake_product}
	var pancake_stage: Dictionary = session.call("stage_product_to_order", pancake_source, pancake_order_id, 0)
	var blocked_return: Dictionary = session.call("remove_staged_product", pancake_order_id, 0, &"return_stock")
	_check(bool(pancake_stage.get("success", false)) and StringName(blocked_return.get("reason", &"")) == &"return_not_allowed", "processed food cannot be silently returned to inventory")
	var waste_before := Array(Dictionary(session.call("five_area_production_snapshot")).get("waste_events", [])).size()
	var discarded: Dictionary = session.call("remove_staged_product", pancake_order_id, 0, &"waste")
	var waste_after := Array(Dictionary(session.call("five_area_production_snapshot")).get("waste_events", [])).size()
	_check(bool(discarded.get("success", false)) and waste_after == waste_before + 1, "processed staged food only leaves through the visible waste transaction")

	var restore_order: Dictionary = session.call("open_formal_order", [{
		"area_id": &"area.packaged_drink",
		"product_id": &"product.packaged_drink.milk",
		"quantity": 1,
		"temperature_mode": &"room_temperature",
	}])
	var restore_order_id := StringName(Dictionary(restore_order.get("order", {})).get("order_id", &""))
	_check(bool(session.call("stage_product_to_order", milk_source, restore_order_id, 0).get("success", false)), "restore fixture stages one inventory product")
	var saved_state := Dictionary(session.get("_save_data")).duplicate(true)
	var saved_inventory := Dictionary(session.call("inventory_snapshot"))
	session.set("_order_service", null)
	session.set("_production_service", null)
	session.set("_pancake_holding_tray", null)
	session.set("_save_data", saved_state)
	session.call("_restore_progression")
	var restored_order := Dictionary(session.call("formal_order", restore_order_id))
	var restored_products := Array(Dictionary(Array(restored_order.get("items", []))[0]).get("attached_products", []))
	_check(restored_products.size() == 1 and Dictionary(session.call("inventory_snapshot")) == saved_inventory, "save restore preserves one authoritative staged instance without duplicating or losing stock")

	var rollback_snapshot: Dictionary = session.call("_tray_transaction_snapshot")
	var rollback_inventory := Dictionary(session.call("inventory_snapshot"))
	rollback_inventory["stock.packaged_drink.milk"] = 0
	session.call("save_inventory", rollback_inventory)
	session.call("_restore_tray_transaction", rollback_snapshot)
	_check(Dictionary(session.call("inventory_snapshot")) == Dictionary(rollback_snapshot.get("inventory", {})), "tray transaction rollback restores the complete inventory snapshot atomically")
	_finish()


func _unlock_test_products(session: Node) -> void:
	var progression: RefCounted = session.call("progression_service")
	var areas := Dictionary(progression.get("unlocked_area_ids"))
	areas[&"area.packaged_drink"] = true
	progression.set("unlocked_area_ids", areas)
	var recipes := Dictionary(progression.get("unlocked_recipe_ids"))
	for recipe_id in [&"recipe.packaged_drink.milk", &"recipe.packaged_drink.soy_milk"]:
		recipes[recipe_id] = true
	progression.set("unlocked_recipe_ids", recipes)
	var products := Dictionary(progression.get("unlocked_product_ids"))
	for product_id in [&"product.packaged_drink.milk", &"product.packaged_drink.soy_milk"]:
		products[product_id] = true
	progression.set("unlocked_product_ids", products)
	var stocks := Dictionary(progression.get("unlocked_stock_ids"))
	for stock_id in [&"stock.packaged_drink.milk", &"stock.packaged_drink.soy_milk"]:
		stocks[stock_id] = true
	progression.set("unlocked_stock_ids", stocks)
	var tiers := Dictionary(progression.get("device_tiers"))
	tiers[&"device.packaged_drink_heater"] = 0
	progression.set("device_tiers", tiers)
	session.call("_sync_progression_to_save")
	session.set("_production_service", null)
	session.call("_ensure_production_service")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CUSTOMER_HANDOFF_TRAY_TRANSACTION_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("CUSTOMER_HANDOFF_TRAY_TRANSACTION_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
