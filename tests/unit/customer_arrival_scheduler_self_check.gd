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
	_check_completed_delivery_ends_tutorial(session)
	session.call("begin_new_game")
	var opening_inventory: Dictionary = session.call("inventory_snapshot")
	for quantity in opening_inventory.values():
		_check(int(quantity) == 0, "new business starts with no automatically stocked inventory")
	var progression: RefCounted = session.call("progression_service")
	progression.call("complete_tutorial", &"area", &"area.pancake")
	var opening := Dictionary(session.call("customer_arrival_snapshot"))
	_check(StringName(opening.get("phase", &"")) == &"restocking" and is_equal_approx(float(opening.get("restock_remaining_seconds", 0.0)), 5.0), "new business opens with a five-second restock window")
	session.call("advance_customer_arrivals", 4.5)
	_check(Array(session.call("active_formal_orders")).is_empty(), "no customer appears before the restock window ends")
	var before_open := Dictionary(session.call("customer_arrival_snapshot"))
	_check(is_equal_approx(float(before_open.get("restock_remaining_seconds", 0.0)), 0.5), "restock countdown advances precisely")
	var first_result: Dictionary = session.call("advance_customer_arrivals", 0.5)
	_check(Array(first_result.get("entered_orders", [])).size() == 1 and Array(session.call("active_formal_orders")).size() == 1, "exactly one customer enters when restocking ends")
	_check(Array(session.call("waiting_formal_orders")).is_empty(), "walk-in flow never exposes a waiting queue")
	var first_order := Dictionary(Array(session.call("active_formal_orders")).front())
	var first_metadata := Dictionary(first_order.get("metadata", {}))
	_check(
		float(first_metadata.get("estimated_service_seconds", 0.0)) > 0.0
		and float(first_order.get("patience_seconds", 0.0)) >= float(first_metadata.get("estimated_service_seconds", 0.0)) + 24.0,
		"generated customer patience covers estimated production time plus first-day grace",
	)
	var first_pressure := Dictionary(session.call("customer_pressure_snapshot"))
	_check(int(first_pressure.get("capacity", 0)) == 2, "the first business day exposes at most two customer positions")
	var second_arrival_delay := float(Dictionary(session.call("customer_arrival_snapshot")).get("next_arrival_remaining_seconds", -1.0))
	_check(second_arrival_delay >= 10.0 and second_arrival_delay <= 14.0, "first-day arrivals are spaced ten to fourteen seconds apart")
	session.call("advance_customer_arrivals", second_arrival_delay + 0.01)
	_check(Array(session.call("active_formal_orders")).size() == 2, "the second first-day customer arrives on schedule")
	session.call("advance_customer_arrivals", 30.0)
	_check(Array(session.call("active_formal_orders")).size() == 2 and float(Dictionary(session.call("customer_arrival_snapshot")).get("next_arrival_remaining_seconds", 0.0)) < 0.0, "walk-ins pause while the staged customer capacity is full")
	var departed := Dictionary(Array(session.call("active_formal_orders")).front())
	session.call("abandon_formal_order", StringName(departed.get("order_id", &"")), &"test_departure")
	_check(Array(session.call("active_formal_orders")).size() == 1, "a departure leaves an empty on-floor position before the next arrival")
	var after_departure := Dictionary(session.call("customer_arrival_snapshot"))
	var delay := float(after_departure.get("next_arrival_remaining_seconds", -1.0))
	_check(delay >= 10.0 and delay <= 14.0, "departure resumes the first-day arrival window")
	session.call("advance_customer_arrivals", maxf(delay - 0.01, 0.0))
	_check(Array(session.call("active_formal_orders")).size() == 1, "next customer does not enter before its scheduled arrival")
	session.call("advance_customer_arrivals", 0.02)
	_check(Array(session.call("active_formal_orders")).size() == 2, "next customer enters after its scheduled arrival")
	session.call("end_business_day")
	_check(bool(Dictionary(session.call("begin_next_business_day")).get("success", false)), "next business day opens")
	_check(int(Dictionary(session.call("customer_pressure_snapshot")).get("capacity", 0)) == 3, "day two raises a one-area shop to three customer positions")
	progression.set("current_day", 3)
	progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.youtiao": true})
	_check(int(Dictionary(session.call("customer_pressure_snapshot")).get("capacity", 0)) == 4, "day three plus a second production area raises capacity to four")
	progression.set("current_day", 4)
	progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.youtiao": true, &"area.fresh_soy_milk": true})
	_check(int(Dictionary(session.call("customer_pressure_snapshot")).get("capacity", 0)) == 5, "later play plus three production areas unlocks all five positions")
	var next_inventory: Dictionary = session.call("inventory_snapshot")
	for quantity in next_inventory.values():
		_check(int(quantity) == 0, "next business day does not automatically refill inventory")
	_check(Array(session.call("active_formal_orders")).is_empty(), "next business day starts with no visible customer")
	_finish()


func _check_completed_delivery_ends_tutorial(session: Node) -> void:
	session.call("begin_new_game")
	session.call("advance_customer_arrivals", 5.0)
	var tutorial_order := Dictionary(session.call("active_formal_order"))
	var tutorial_order_id := StringName(tutorial_order.get("order_id", &""))
	_check(not tutorial_order_id.is_empty() and bool(tutorial_order.get("tutorial_no_countdown", false)), "opening arrival is the unlimited pancake tutorial")
	var refusal_preview := Dictionary(session.call("preview_formal_order_refusal", tutorial_order_id))
	var refused := Dictionary(session.call("refuse_formal_order", tutorial_order_id))
	_check(
		not bool(refusal_preview.get("success", false))
		and StringName(refusal_preview.get("reason", &"")) == &"tutorial_order_cannot_be_refused"
		and not bool(refused.get("success", false))
		and StringName(refused.get("reason", &"")) == &"tutorial_order_cannot_be_refused",
		"tutorial customer cannot be previewed or submitted as a refused order"
	)
	var attached := Dictionary(session.call("attach_formal_order_product", tutorial_order_id, 0, {
		"product_instance_id": &"test.wrong_tutorial_pancake",
		"product_id": &"product.pancake.custom",
		"area_id": &"area.pancake",
		"heat_preference": &"charred",
		"ingredient_ids": [],
		"sauce_ids": [],
		"score": 1.0,
		"grade": &"C",
	}))
	var after_wrong := Dictionary(session.call("formal_order", tutorial_order_id))
	_check(
		bool(attached.get("success", false))
		and not bool(attached.get("will_match", true))
		and Array(Dictionary(Array(after_wrong.get("items", []))[0]).get("prepared_product_instance_ids", [])).size() == 1,
		"tutorial delivery accepts a completed guided product without recipe-match blocking"
	)
	var settlement := Dictionary(session.call("settle_f3_order", tutorial_order_id))
	var tutorial := Dictionary(Dictionary(session.call("five_area_progression_snapshot")).get("tutorial", {}))
	_check(
		bool(settlement.get("success", false))
		and bool(Dictionary(settlement.get("tutorial_completion", {})).get("success", false))
		and StringName(Dictionary(tutorial.get("final_outcome_by_id", {})).get("area.pancake", &"")) == &"completed"
		and StringName(tutorial.get("active_id", &"")).is_empty(),
		"a settled guided delivery completes the tutorial without recipe validation"
	)
	var progression: RefCounted = session.call("progression_service")
	progression.set("tutorial_completed_area_ids", {})
	progression.set("tutorial_active_kind", &"area")
	progression.set("tutorial_active_id", &"area.pancake")
	session.call("_sync_progression_to_save")
	session.call("_reconcile_completed_tutorial_order")
	var reconciled_tutorial := Dictionary(Dictionary(session.call("five_area_progression_snapshot")).get("tutorial", {}))
	_check(
		StringName(reconciled_tutorial.get("active_id", &"")).is_empty()
		and PackedStringArray(reconciled_tutorial.get("completed_area_ids", PackedStringArray())).has("area.pancake"),
		"a legacy save with a settled tutorial order repairs itself to completed on load"
	)
	var arrival := Dictionary(session.call("customer_arrival_snapshot"))
	var delay := float(arrival.get("next_arrival_remaining_seconds", -1.0))
	_check(delay >= 10.0 and delay <= 14.0, "completed tutorial schedules the first ordinary customer at the gentler first-day pace")
	session.call("advance_customer_arrivals", delay + 0.01)
	var ordinary_orders := Array(session.call("active_formal_orders"))
	_check(ordinary_orders.size() == 1 and not bool(Dictionary(ordinary_orders.front()).get("tutorial_no_countdown", true)), "ordinary customer arrives after the completed tutorial")


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
