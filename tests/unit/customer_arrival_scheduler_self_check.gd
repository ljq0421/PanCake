extends SceneTree

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "test has the GameSession autoload")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	var opening_inventory: Dictionary = session.call("inventory_snapshot")
	for quantity in opening_inventory.values():
		_check(int(quantity) == 0, "new business starts with no automatically stocked inventory")
	var progression: RefCounted = session.call("progression_service")
	progression.call("complete_tutorial", &"area", &"area.pancake")
	var opening := Dictionary(session.call("customer_arrival_snapshot"))
	_check(StringName(opening.get("phase", &"")) == &"restocking" and is_equal_approx(float(opening.get("restock_remaining_seconds", 0.0)), 3.0), "new business opens with a three-second restock window")
	session.call("advance_customer_arrivals", 2.5)
	_check(Array(session.call("active_formal_orders")).is_empty(), "no customer appears before the restock window ends")
	var before_open := Dictionary(session.call("customer_arrival_snapshot"))
	_check(is_equal_approx(float(before_open.get("restock_remaining_seconds", 0.0)), 0.5), "restock countdown advances precisely")
	var first_result: Dictionary = session.call("advance_customer_arrivals", 0.5)
	_check(Array(first_result.get("entered_orders", [])).size() == 1 and Array(session.call("active_formal_orders")).size() == 1, "exactly one customer enters when restocking ends")
	_check(Array(session.call("waiting_formal_orders")).is_empty(), "walk-in flow never exposes a waiting queue")
	for _step in range(8):
		session.call("advance_customer_arrivals", 5.1)
	_check(Array(session.call("active_formal_orders")).size() == 5, "arrivals fill at most five on-floor service positions")
	var departed := Dictionary(Array(session.call("active_formal_orders")).front())
	session.call("abandon_formal_order", StringName(departed.get("order_id", &"")), &"test_departure")
	_check(Array(session.call("active_formal_orders")).size() == 4, "a departure leaves an empty on-floor position before the next arrival")
	var after_departure := Dictionary(session.call("customer_arrival_snapshot"))
	var delay := float(after_departure.get("next_arrival_remaining_seconds", -1.0))
	_check(delay >= 2.0 and delay <= 5.0, "departure schedules the next individual arrival within two to five seconds")
	session.call("advance_customer_arrivals", maxf(delay - 0.01, 0.0))
	_check(Array(session.call("active_formal_orders")).size() == 4, "next customer does not enter before its scheduled arrival")
	session.call("advance_customer_arrivals", 0.02)
	_check(Array(session.call("active_formal_orders")).size() == 5, "next customer enters after its scheduled arrival")
	session.call("end_business_day")
	_check(bool(Dictionary(session.call("begin_next_business_day")).get("success", false)), "next business day opens")
	var next_inventory: Dictionary = session.call("inventory_snapshot")
	for quantity in next_inventory.values():
		_check(int(quantity) == 0, "next business day does not automatically refill inventory")
	_check(Array(session.call("active_formal_orders")).is_empty(), "next business day starts with no visible customer")
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CUSTOMER_ARRIVAL_SCHEDULER_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("CUSTOMER_ARRIVAL_SCHEDULER_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
