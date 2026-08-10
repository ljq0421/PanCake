extends SceneTree

var _failures: Array[String] = []


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
	progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.packaged_drink": true, &"area.youtiao": true})
	progression.set("device_tiers", {&"device.pancake_griddle": 1, &"device.packaged_drink_heater": 0, &"device.youtiao_fryer": 0})
	progression.set("unlocked_recipe_ids", {&"recipe.pancake.base": true, &"recipe.packaged_drink.milk": true, &"recipe.youtiao.plain": true})
	progression.set("unlocked_product_ids", {&"product.pancake.custom": true, &"product.packaged_drink.milk": true, &"product.youtiao.plain": true})
	progression.set("unlocked_stock_ids", {&"stock.packaged_drink.milk": true, &"stock.youtiao.plain_dough": true})
	progression.set("tutorial_completed_area_ids", {&"area.pancake": true, &"area.packaged_drink": true, &"area.youtiao": true})
	var inventory: Dictionary = session.call("inventory_snapshot")
	inventory["stock.packaged_drink.milk"] = 3
	inventory["stock.youtiao.plain_dough"] = 3
	session.call("save_inventory", inventory)

	var opened: Dictionary = session.call("open_formal_order", [
		{"area_id": &"area.packaged_drink", "product_id": &"product.packaged_drink.milk", "quantity": 1, "temperature_mode": &"heated"},
		{"area_id": &"area.youtiao", "product_id": &"product.youtiao.plain", "quantity": 1, "temperature_mode": &"room_temperature"},
	], {"source": &"f3_self_check"})
	var order_id: StringName = Dictionary(opened.get("order", {})).get("order_id", &"")
	_check(bool(session.call("load_f3_drink", 0, &"product.packaged_drink.milk", order_id).get("success", false)), "loading drink atomically consumes one stock")
	_check(int(Dictionary(session.call("inventory_snapshot")).get("stock.packaged_drink.milk", 0)) == 2, "drink inventory decrements once")
	_check(bool(session.call("load_f3_youtiao", &"recipe.youtiao.plain", 2, order_id).get("success", false)), "partial fryer batch atomically consumes requested quantity")
	_check(int(Dictionary(session.call("inventory_snapshot")).get("stock.youtiao.plain_dough", 0)) == 1, "youtiao inventory decrements by batch quantity")
	session.call("perform_f3_youtiao_action", &"start")
	session.call("advance_f3_production", 2.0)
	var parallel_fryer: Dictionary = session.call("f3_machine_snapshot", &"device.youtiao_fryer")
	_check(StringName(parallel_fryer.get("state", &"")) == &"frying" and is_equal_approx(float(parallel_fryer.get("cooking_elapsed_seconds", 0.0)), 2.0), "one production tick advances drink heater and fryer in parallel")
	_check(bool(session.call("deliver_heated_drink", 0, order_id, 0).get("success", false)), "ready heated drink attaches to selected matching order item")
	session.call("advance_f3_production", 10.0)
	session.call("perform_f3_youtiao_action", &"lift")
	session.call("advance_f3_production", 2.0)
	_check(bool(session.call("store_ready_youtiao_in_prepared_slot", &"slot.04").get("success", false)), "ready youtiao moves from the raised basket into Slot04 before delivery")
	var delivered_youtiao: Dictionary = session.call("deliver_f3_youtiao", order_id, 1)
	_check(bool(delivered_youtiao.get("success", false)) and int(Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer")).get("quantity", 0)) == 1 and int(Dictionary(session.call("prepared_product_slot_status", &"slot.04")).get("count", -1)) == 0, "one FIFO Slot04 youtiao is delivered while extra output keeps occupying fryer")
	var settled: Dictionary = session.call("settle_f3_order", order_id)
	_check(bool(settled.get("order_success", false)) and int(settled.get("earned_coins", 0)) == 9 and int(settled.get("reputation_delta", 0)) == 4, "F3 multi-item settlement updates exact product revenue and reputation")
	_check(int(progression.call("mastery_value", &"area.packaged_drink")) == 1 and int(progression.call("mastery_value", &"area.youtiao")) == 1, "settlement advances drink and youtiao mastery once")

	var mismatch_order: Dictionary = session.call("open_formal_order", [{"area_id": &"area.packaged_drink", "product_id": &"product.packaged_drink.milk", "quantity": 1, "temperature_mode": &"room_temperature"}])
	var mismatch_id: StringName = Dictionary(mismatch_order.get("order", {})).get("order_id", &"")
	_check(bool(session.call("load_f3_drink", 0, &"product.packaged_drink.milk", mismatch_id).get("success", false)), "second drink can enter empty heater")
	session.call("advance_f3_production", 2.0)
	var mismatch: Dictionary = session.call("deliver_heated_drink", 0, mismatch_id, 0)
	_check(bool(mismatch.get("success", false)) and not bool(mismatch.get("will_match", true)) and Array(mismatch.get("mismatch_reasons", [])).has("temperature_mode") and StringName(Dictionary(Array(Dictionary(session.call("f3_machine_snapshot", &"device.packaged_drink_heater")).get("slots", []))[0]).get("state", &"")) == &"empty", "temperature mismatch is visible on the tray and removes the physical heater output")
	_check(bool(session.call("remove_staged_product", mismatch_id, 0, &"waste").get("success", false)), "heated mismatch is explicitly dragged from tray to waste")
	var production: Dictionary = session.call("five_area_production_snapshot")
	_check(Array(production.get("waste_events", [])).size() == 1, "tray discard records one heated-drink waste event")
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("F3_PRODUCTION_ORDER_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("F3_PRODUCTION_ORDER_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
