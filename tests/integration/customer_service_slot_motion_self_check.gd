extends SceneTree

const SCENE := preload("res://scenes/gameplay/customer_service_slot.tscn")
const WORKSTATION_SCRIPT := preload("res://scripts/gameplay/workstation.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var entrance_scheduler := WORKSTATION_SCRIPT.new()
	entrance_scheduler.call("_reserve_customer_entrance_delay_seconds")
	var first_next_entrance_msec := int(entrance_scheduler.get("_next_customer_entrance_msec"))
	entrance_scheduler.call("_reserve_customer_entrance_delay_seconds")
	var second_next_entrance_msec := int(entrance_scheduler.get("_next_customer_entrance_msec"))
	entrance_scheduler.call("_reserve_customer_entrance_delay_seconds")
	var third_next_entrance_msec := int(entrance_scheduler.get("_next_customer_entrance_msec"))
	_check(
		second_next_entrance_msec - first_next_entrance_msec >= 1000
		and third_next_entrance_msec - second_next_entrance_msec >= 1000,
		"all customer entrances reserve start times at least one second apart",
	)
	entrance_scheduler.free()
	var restored_slot := SCENE.instantiate()
	root.add_child(restored_slot)
	await process_frame
	restored_slot.restore_order(_order(&"order.motion.restored"), null, [null], [[]], 5)
	_check(
		restored_slot.visible
		and not restored_slot.is_presentation_transitioning()
		and restored_slot.portrait.position == Vector2(12.0, 140.0)
		and is_zero_approx(restored_slot.portrait.rotation)
		and is_equal_approx(restored_slot.portrait.modulate.a, 1.0)
		and restored_slot.get_node("OrderPanel").visible
		and restored_slot.card_focus_button.mouse_filter == Control.MOUSE_FILTER_STOP,
		"a continued-game customer restores in place with its saved order and no arrival animation",
	)
	restored_slot.queue_free()
	await process_frame
	var far_right_slot := SCENE.instantiate()
	far_right_slot.position = Vector2(1280.0, 150.0)
	root.add_child(far_right_slot)
	await process_frame
	far_right_slot.present_order(_order(&"order.motion.far_right"), null, [null], [[]], 5, false)
	await process_frame
	_check(far_right_slot.portrait.global_position.x < 0.0, "a far-right customer starts beyond the viewport's far-left edge")
	await _wait(1.30)
	_check(far_right_slot.is_presentation_transitioning(), "a far-right customer remains walking instead of accelerating to reach its slot")
	far_right_slot.queue_free()
	await process_frame
	var slot := SCENE.instantiate()
	root.add_child(slot)
	await process_frame
	var first_order := _order(&"order.motion.first")
	slot.present_order(first_order, null, [null], [[]], 5, false)
	await process_frame
	_check(slot.visible and slot.is_presentation_transitioning(), "a newly assigned customer enters through the presentation transition")
	_check(slot.portrait.global_position.x < 0.0, "normal-motion entry starts every portrait beyond the viewport's far-left edge")
	_check(is_equal_approx(slot.portrait.modulate.a, 1.0), "normal-motion entry keeps the walking portrait fully opaque")
	_check(slot.get_node("OrderPanel").position == Vector2(155.0, -2.0) and not slot.get_node("OrderPanel").visible, "the order stays hidden while its customer is walking in")
	await _wait(0.25)
	_check(slot.portrait.position.y < 140.0 or absf(slot.portrait.rotation) > 0.001, "normal-motion entry applies a visible simulated walking gait")
	await _wait(1.30)
	_check(
		not slot.is_presentation_transitioning()
		and slot.portrait.position == Vector2(12.0, 140.0)
		and slot.get_node("OrderPanel").position == Vector2(155.0, -2.0)
		and is_equal_approx(slot.portrait.modulate.a, 1.0)
		and is_equal_approx(slot.get_node("OrderPanel").modulate.a, 1.0)
		and slot.get_node("OrderPanel").visible,
		"entry restores the authored positions and full opacity",
	)
	var second_order := _order(&"order.motion.second")
	slot.present_order(second_order, null, [null], [[]], 6, false)
	await process_frame
	_check(slot.card_focus_button.mouse_filter == Control.MOUSE_FILTER_IGNORE and slot.item_buttons[0].mouse_filter == Control.MOUSE_FILTER_IGNORE, "outgoing customer cards ignore input immediately")
	_check(is_equal_approx(slot.portrait.modulate.a, 1.0), "normal-motion exit keeps the walking portrait fully opaque")
	_check(slot.get_node("OrderPanel").position == Vector2(155.0, -2.0) and is_equal_approx(slot.get_node("OrderPanel").modulate.a, 1.0), "the order card does not drift with the departing customer")
	await _wait(1.20)
	_check(StringName(slot.get("_order_id")) == &"order.motion.second", "the next customer binds only after the previous customer exits")
	await _wait(1.30)
	_check(not slot.is_presentation_transitioning() and slot.card_focus_button.mouse_filter == Control.MOUSE_FILTER_STOP and slot.item_buttons[0].mouse_filter == Control.MOUSE_FILTER_STOP, "the arriving customer restores card and delivery interaction after entry")
	var third_order := _order(&"order.motion.third")
	var fourth_order := _order(&"order.motion.fourth")
	slot.present_order(third_order, null, [null], [[]], 7, false)
	slot.present_order(fourth_order, null, [null], [[]], 8, false)
	await _wait(2.50)
	_check(StringName(slot.get("_order_id")) == &"order.motion.fourth" and not slot.is_presentation_transitioning(), "rapid replacements retain only the latest requested customer")
	var reduced_order := _order(&"order.motion.reduced")
	slot.present_order(reduced_order, null, [null], [[]], 9, true)
	await process_frame
	_check(slot.portrait.position == Vector2(12.0, 140.0) and slot.get_node("OrderPanel").position == Vector2(155.0, -2.0), "reduced motion keeps both customer layers stationary")
	await _wait(0.75)
	_check(StringName(slot.get("_order_id")) == &"order.motion.reduced" and slot.is_presentation_transitioning() and not slot.get_node("OrderPanel").visible, "the replacement order stays hidden after its reduced-motion customer takes over")
	await _wait(0.75)
	_check(StringName(slot.get("_order_id")) == &"order.motion.reduced" and not slot.is_presentation_transitioning() and slot.get_node("OrderPanel").visible, "reduced motion shows the order only after the customer finishes arriving")
	slot.queue_free()
	await process_frame
	_finish()


func _order(order_id: StringName) -> Dictionary:
	return {
		"order_id": order_id,
		"customer_id": &"customer_01",
		"patience_seconds": 60.0,
		"remaining_patience_seconds": 60.0,
		"items": [{"product_id": &"product.packaged_drink.milk", "quantity": 1, "prepared_product_instance_ids": []}],
	}


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("CUSTOMER_SERVICE_SLOT_MOTION_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("CUSTOMER_SERVICE_SLOT_MOTION_SELF_CHECK_FAIL\\n" + "\\n".join(failures))
	quit(1)
