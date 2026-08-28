extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")

var failures := PackedStringArray()
var product_sequence := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession exists for pancake two-click delivery")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	session.call("set_business_paused", true)
	_complete_initial_pancake_tutorial(session)
	_unlock_pancake_holding_tray(session)
	_clear_orders(session)

	var plain_item := _pancake_item(&"golden")
	var first_order := _open_order(session, plain_item, &"two_click_griddle")
	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	await process_frame
	await process_frame
	_prepare_ready_pancake(workstation, plain_item)
	var first_order_id := StringName(first_order.get("order_id", &""))
	workstation.call("_on_customer_service_delivery_requested", first_order_id, 0)
	_check(
		StringName(Dictionary(session.call("formal_order", first_order_id)).get("state", &"")) in [&"active", &"serving"]
		and not workstation.multi_griddle_station.ready_source_refs().is_empty(),
		"an unselected griddle pancake is not auto-delivered by the order icon"
	)

	var griddle_source := Dictionary(workstation.multi_griddle_station.ready_source_refs()[0])
	workstation.call("_on_pancake_delivery_source_clicked", griddle_source)
	_check(not Dictionary(workstation.get("_selected_pancake_delivery_source_ref")).is_empty(), "clicking a packaged griddle pancake selects it")
	workstation.call("_on_pancake_delivery_source_clicked", griddle_source)
	_check(Dictionary(workstation.get("_selected_pancake_delivery_source_ref")).is_empty(), "clicking the same pancake cancels selection")
	var switch_product := Dictionary(session.call("store_pancake_product", _pancake_product(&"golden")))
	workstation.call("_refresh_pancake_holding_tray")
	var switch_source: ProductDragSource = workstation.pancake_holding_sources[0]
	var switch_ref := Dictionary(switch_source.source_ref())
	workstation.call("_on_pancake_delivery_source_clicked", griddle_source)
	workstation.call("_on_pancake_delivery_source_clicked", switch_ref)
	_check(
		bool(switch_product.get("success", false))
		and StringName(Dictionary(workstation.get("_selected_pancake_delivery_source_ref")).get("source_kind", &"")) == &"pancake_holding",
		"clicking another ready pancake switches the selected delivery source"
	)
	workstation.call("_on_pancake_delivery_source_clicked", griddle_source)
	workstation.call("_on_customer_service_delivery_requested", first_order_id, 0)
	_check(
		StringName(Dictionary(session.call("formal_order", first_order_id)).get("state", &"")) == &"settled"
		and workstation.multi_griddle_station.ready_source_refs().is_empty()
		and Dictionary(workstation.get("_selected_pancake_delivery_source_ref")).is_empty(),
		"the selected griddle pancake is delivered exactly once and selection clears"
	)

	var mismatch_item := _pancake_item(&"well_done")
	var second_order := _open_order(session, mismatch_item, &"two_click_holding")
	workstation.call("_refresh_pancake_holding_tray")
	var holding_source: ProductDragSource = workstation.pancake_holding_sources[0]
	_check(holding_source.visible and not holding_source.native_drag_enabled, "holding-tray pancake is clickable and no longer starts native delivery drag")
	var holding_ref := Dictionary(holding_source.source_ref())
	workstation.call("_on_pancake_delivery_source_clicked", holding_ref)
	var discarded := Dictionary(session.call("discard_product_source", holding_ref))
	workstation.call("_refresh_pancake_drag_sources")
	workstation.call("_refresh_selected_pancake_delivery_source")
	_check(bool(discarded.get("success", false)) and Dictionary(workstation.get("_selected_pancake_delivery_source_ref")).is_empty(), "selection clears when its stored pancake is no longer available")
	var stored := Dictionary(session.call("store_pancake_product", _pancake_product(&"golden")))
	workstation.call("_refresh_pancake_holding_tray")
	holding_ref = Dictionary(holding_source.source_ref())
	workstation.call("_on_pancake_delivery_source_clicked", holding_ref)
	workstation.call("_on_customer_service_product_dropped", StringName(second_order.get("order_id", &"")), 0, holding_ref)
	_check(
		not Dictionary(Array(Dictionary(session.call("pancake_holding_tray_snapshot")).get("slots", []))[0]).is_empty(),
		"dragging a pancake to its order icon is rejected without consuming it"
	)
	workstation.call("_on_customer_service_delivery_requested", StringName(second_order.get("order_id", &"")), 0)
	var settled_mismatch := Dictionary(session.call("formal_order", StringName(second_order.get("order_id", &""))))
	_check(
		bool(stored.get("success", false))
		and StringName(settled_mismatch.get("state", &"")) == &"settled"
		and Dictionary(Array(Dictionary(session.call("pancake_holding_tray_snapshot")).get("slots", []))[0]).is_empty(),
		"the selected mismatched holding-tray pancake still delivers and is consumed"
	)

	workstation.queue_free()
	_finish()


func _pancake_item(heat_preference: StringName) -> Dictionary:
	return {
		"area_id": &"area.pancake",
		"product_id": &"product.pancake.custom",
		"quantity": 1,
		"heat_preference": heat_preference,
		"ingredient_ids": PackedStringArray(),
		"sauce_ids": PackedStringArray(),
	}


func _pancake_product(heat_preference: StringName) -> Dictionary:
	product_sequence += 1
	return {
		"product_instance_id": StringName("test.two_click.%d" % product_sequence),
		"area_id": &"area.pancake",
		"product_id": &"product.pancake.custom",
		"heat_preference": heat_preference,
		"ingredient_ids": PackedStringArray(),
		"sauce_ids": PackedStringArray(),
		"score": 100.0,
		"status": &"available",
		"serving_score_basis": {"version": 2, "intrinsic_dimensions": {}, "heat_moments": {}, "sauce_results": {}, "sauce_profiles": {}},
	}


func _prepare_ready_pancake(workstation: Node, item: Dictionary) -> void:
	var unit: Node = workstation.multi_griddle_station.units[0]
	unit.mark_ready(_pancake_product(StringName(item.get("heat_preference", &"golden"))))
	workstation.multi_griddle_station.call("_sync_snapshot_to_session")


func _open_order(session: Node, item: Dictionary, source: StringName) -> Dictionary:
	return Dictionary(Dictionary(session.call("open_formal_order", [item], {"source": source, "patience_seconds": 120.0})).get("order", {}))


func _unlock_pancake_holding_tray(session: Node) -> void:
	var progression: RefCounted = session.call("progression_service")
	var owned := Dictionary(progression.get("owned_growth_ids"))
	owned[&"growth.capacity.pancake_holding_tray.two_slots"] = true
	progression.set("owned_growth_ids", owned)
	session.call("_sync_progression_to_save")


func _complete_initial_pancake_tutorial(session: Node) -> void:
	var progression: RefCounted = session.call("progression_service")
	progression.set("tutorial_completed_area_ids", {&"area.pancake": true})
	progression.set("tutorial_queue_area_ids", [])
	progression.set("tutorial_active_kind", &"")
	progression.set("tutorial_active_id", &"")
	session.call("_sync_progression_to_save")


func _clear_orders(session: Node) -> void:
	for order_value in Array(session.call("active_formal_orders")) + Array(session.call("waiting_formal_orders")):
		var order_id := StringName(Dictionary(order_value).get("order_id", &""))
		if not order_id.is_empty():
			session.call("abandon_formal_order", order_id, &"two_click_fixture")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("PANCAKE_TWO_CLICK_DELIVERY_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("PANCAKE_TWO_CLICK_DELIVERY_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
