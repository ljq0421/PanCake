extends SceneTree

## P0 public-contract seed.  The companion existing-save check is deliberately
## launched by a separate Godot process with this script's test profile.
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession public service is available")
	if session == null:
		_finish()
		return

	var started := Dictionary(session.begin_new_game())
	_check(bool(started.get("success", false)) and bool(session.is_four_area_save_active()), "a blank profile starts the four-area save contract")
	_check(Array(session.opening_restock_tasks()).size() > 0 and bool(session.is_opening_restock_active()), "first day begins in the restock window")

	var arrivals := Dictionary(session.advance_customer_arrivals(5.1))
	var order := Dictionary(session.active_formal_order())
	var order_id := StringName(order.get("order_id", &""))
	var item := Dictionary(Array(order.get("items", []))[0]) if not Array(order.get("items", [])).is_empty() else {}
	_check(bool(arrivals.get("success", false)) and not order_id.is_empty() and StringName(item.get("area_id", &"")) == &"area.pancake", "opening restock leads to the first pancake order")

	var product := {
		"product_instance_id": &"p0.first_day.pancake",
		"area_id": &"area.pancake",
		"product_id": &"product.pancake.custom",
		"heat_preference": StringName(item.get("heat_preference", &"golden")),
		"ingredient_ids": Array(item.get("ingredient_ids", [])).duplicate(),
		"sauce_ids": Array(item.get("sauce_ids", [])).duplicate(),
		"material_cost": 0,
		"status": &"available",
	}
	var saved_griddle := Dictionary(session.save_pancake_griddles({
		"version": 2,
		"griddle_count": 1,
		"active_index": 0,
		"product_sequence": 1,
		"slots": [{"state": 6, "ready_product": product}],
	}))
	_check(bool(saved_griddle.get("success", false)) and int(session.pancake_griddles_snapshot().get("griddle_count", 0)) == 1, "the public single-griddle snapshot accepts exactly one ready pancake")
	var staged := Dictionary(session.stage_product_to_order({"source_kind": &"pancake_griddle_ready", "source_index": 0, "product_id": &"product.pancake.custom"}, order_id, 0))
	var settled := Dictionary(session.complete_order_delivery(order_id))
	var payment := Dictionary(session.collect_all_pending_order_payments())
	_check(bool(staged.get("success", false)) and bool(settled.get("success", false)) and int(payment.get("amount", 0)) > 0, "first pancake is staged, delivered, and paid through public session calls")

	session.credit_coins(10)
	var growth := Dictionary(session.purchase_growth(&"growth.add_on.pancake.egg"))
	_check(bool(growth.get("success", false)), "first-day coins can reserve the next-day egg growth")
	var next_arrival := Dictionary(session.advance_customer_arrivals(5.1))
	_check(not Array(session.active_formal_orders()).is_empty() and bool(next_arrival.get("success", false)), "a new customer is available before the game is saved")
	session.mark_session_left()
	_check(bool(session.is_business_paused()), "first-day profile is persisted as a paused continue-game save")
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("FOUR_AREA_FIRST_DAY_E2E_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("FOUR_AREA_FIRST_DAY_E2E_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
