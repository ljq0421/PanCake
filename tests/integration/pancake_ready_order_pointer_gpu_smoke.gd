extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const FOLD_MODEL := preload("res://scripts/gameplay/pancake_fold_model.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Ready-pancake pointer smoke must run without --headless")
		quit(1)
		return
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession exists for the ready-pancake pointer route")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	for _frame in 12:
		await process_frame
	var workstation := game.get_node("Workstation")
	var order := Dictionary(session.call("active_formal_order"))
	var order_id := StringName(order.get("order_id", &""))
	var customer_id := StringName(order.get("customer_id", &""))
	workstation.p1_session.phase = P1Session.Phase.FOLD
	var package_ready := Dictionary(workstation.p1_session.mark_ready_for_package())
	workstation.fold_model.package_result = FOLD_MODEL.PACKAGE_BAG
	var packaged := Dictionary(workstation.p1_session.mark_packaged())
	workstation.call("_refresh_pancake_drag_sources")
	workstation.call("_refresh_formal_shell")
	await process_frame
	var source_ref := Dictionary(workstation.get("_ready_pancake_source_ref"))
	var order_item := Dictionary(Array(order.get("items", []))[0])
	var source_product := Dictionary(source_ref.get("product", {})).duplicate(true)
	for field in [&"product_id", &"temperature_mode", &"heat_preference", &"ingredient_ids", &"sauce_ids"]:
		if order_item.has(field):
			source_product[field] = order_item[field]
	source_ref["product"] = source_product
	workstation.set("_ready_pancake_source_ref", source_ref)
	var inventory := Dictionary(session.call("inventory_snapshot"))
	inventory["stock.pancake.batter"] = 1
	for sauce_id_variant in Array(source_product.get("sauce_ids", [])):
		inventory[str(StringName(sauce_id_variant))] = 1
	session.call("save_inventory", inventory)
	var batter_before := int(Dictionary(session.call("inventory_snapshot")).get("stock.pancake.batter", 0))
	var order_target := workstation.get_node("SafeArea/OrderCard/OrderDishTarget1") as Button
	_check(
		bool(package_ready.get("success", false))
		and bool(packaged.get("success", false))
		and workstation.p1_session.phase == P1Session.Phase.READY_TO_SERVE
		and not source_ref.is_empty(),
		"finishing the package creates one authoritative ready-pancake source"
	)
	_check(not order_target.disabled and order_target.mouse_filter == Control.MOUSE_FILTER_STOP, "tutorial-highlighted order art remains a real pointer target")
	await _click_control(order_target)
	await process_frame
	await process_frame
	var settled := Dictionary(session.call("formal_order", order_id))
	var next_order := Dictionary(session.call("active_formal_order"))
	var settlement := Dictionary(workstation.get("_pending_tray_settlement"))
	var tutorial := Dictionary(Dictionary(session.call("five_area_progression_snapshot")).get("tutorial", {}))
	var batter_after := int(Dictionary(session.call("inventory_snapshot")).get("stock.pancake.batter", 0))
	_check(
		StringName(settled.get("state", &"")) == &"settled"
		and bool(settlement.get("order_success", false))
		and batter_after == batter_before - 1
		and workstation.p1_session.phase == P1Session.Phase.SPREAD
		and Dictionary(workstation.get("_ready_pancake_source_ref")).is_empty(),
		"one real pointer click consumes and clears exactly one packaged pancake"
	)
	_check(
		not next_order.is_empty()
		and StringName(next_order.get("order_id", &"")) != order_id
		and StringName(next_order.get("customer_id", &"")) != customer_id
		and Array(tutorial.get("completed_area_ids", [])).has("area.pancake"),
		"tutorial settlement immediately focuses a different normal customer"
	)
	game.queue_free()
	await process_frame
	_finish()


func _click_control(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion)
	await process_frame
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = position
	pressed.global_position = position
	root.push_input(pressed)
	await process_frame
	var released := InputEventMouseButton.new()
	released.button_index = MOUSE_BUTTON_LEFT
	released.pressed = false
	released.position = position
	released.global_position = position
	root.push_input(released)
	await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PANCAKE_READY_ORDER_POINTER_GPU_SMOKE_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
