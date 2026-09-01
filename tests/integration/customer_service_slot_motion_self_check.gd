extends SceneTree

const SCENE := preload("res://scenes/gameplay/customer_service_slot.tscn")
const WORKSTATION_SCRIPT := preload("res://scripts/gameplay/workstation.gd")
const PORTRAIT_REST_SCALE := Vector2(1.3, 1.3)

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
		second_next_entrance_msec - first_next_entrance_msec >= 80
		and third_next_entrance_msec - second_next_entrance_msec >= 80,
		"grouped customer entrances reserve a subtle eighty-millisecond stagger",
	)
	entrance_scheduler.free()
	var restored_slot := SCENE.instantiate()
	root.add_child(restored_slot)
	await process_frame
	var restored_portrait_rest_position: Vector2 = restored_slot.portrait.position
	restored_slot.restore_order(_order(&"order.motion.restored"), null, [null], [[]], 5)
	_check(
		restored_slot.visible
		and not restored_slot.is_presentation_transitioning()
		and restored_slot.portrait.position == restored_portrait_rest_position
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
	var far_right_rest_position: Vector2 = far_right_slot.portrait.position
	far_right_slot.present_order(_order(&"order.motion.far_right"), null, [null], [[]], 5, false)
	await process_frame
	_check(
		far_right_slot.portrait.global_position.x > 0.0
		and far_right_slot.portrait.position.y > far_right_rest_position.y
		and far_right_slot.portrait.scale.x < PORTRAIT_REST_SCALE.x,
		"a far-right customer approaches locally from behind the counter instead of crossing the viewport",
	)
	await _wait(0.90)
	_check(not far_right_slot.is_presentation_transitioning(), "local approach duration is independent of the service slot's screen position")
	far_right_slot.queue_free()
	await process_frame
	var slot := SCENE.instantiate()
	root.add_child(slot)
	await process_frame
	var portrait_rest_position: Vector2 = slot.portrait.position
	var first_order := _order(&"order.motion.first")
	slot.present_order(first_order, null, [null], [[]], 5, false)
	await process_frame
	_check(slot.visible and slot.is_presentation_transitioning(), "a newly assigned customer enters through the presentation transition")
	_check(
		slot.portrait.position.x == portrait_rest_position.x
		and slot.portrait.position.y > portrait_rest_position.y
		and slot.portrait.scale.x < PORTRAIT_REST_SCALE.x,
		"normal-motion entry starts below and slightly behind the authored service pose",
	)
	_check(
		_is_order_card_above_head(slot)
		and slot.get_node("OrderPanel").visible
		and slot.get_node("OrderPanel").modulate.a < 1.0,
		"the order card stays above the customer's head while visually withheld during approach",
	)
	await _wait(0.15)
	_check(
		slot.portrait.position.y > portrait_rest_position.y
		and slot.portrait.position.y < portrait_rest_position.y + 56.0
		and is_zero_approx(slot.portrait.rotation),
		"normal-motion entry continuously settles toward the counter without a lateral step cycle",
	)
	await _wait(0.75)
	_check(
		not slot.is_presentation_transitioning()
		and slot.portrait.position == portrait_rest_position
		and slot.portrait.scale == PORTRAIT_REST_SCALE
		and _is_order_card_above_head(slot)
		and slot.get_node("OrderPanel").scale == Vector2.ONE
		and is_equal_approx(slot.portrait.modulate.a, 1.0)
		and is_equal_approx(slot.get_node("OrderPanel").modulate.a, 1.0)
		and slot.get_node("OrderPanel").visible,
		"entry restores the customer and head-mounted card positions at full opacity",
	)
	var second_order := _order(&"order.motion.second")
	slot.present_order(second_order, null, [null], [[]], 6, false)
	await process_frame
	_check(slot.card_focus_button.mouse_filter == Control.MOUSE_FILTER_IGNORE and slot.item_buttons[0].mouse_filter == Control.MOUSE_FILTER_IGNORE, "outgoing customer cards ignore input immediately")
	_check(slot.portrait.position.y > portrait_rest_position.y and slot.portrait.modulate.a < 1.0, "normal-motion exit retreats behind the counter")
	_check(slot.get_node("OrderPanel").visible and slot.get_node("OrderPanel").modulate.a < 1.0, "the outgoing order card retires visually after interaction is disabled")
	await _wait(0.85)
	_check(StringName(slot.get("_order_id")) == &"order.motion.second", "the next customer binds only after the previous customer exits")
	await _wait(0.85)
	_check(not slot.is_presentation_transitioning() and slot.card_focus_button.mouse_filter == Control.MOUSE_FILTER_STOP and slot.item_buttons[0].mouse_filter == Control.MOUSE_FILTER_STOP, "the arriving customer restores card and delivery interaction after entry")
	var third_order := _order(&"order.motion.third")
	var fourth_order := _order(&"order.motion.fourth")
	slot.present_order(third_order, null, [null], [[]], 7, false)
	slot.present_order(fourth_order, null, [null], [[]], 8, false)
	await _wait(1.70)
	_check(StringName(slot.get("_order_id")) == &"order.motion.fourth" and not slot.is_presentation_transitioning(), "rapid replacements retain only the latest requested customer")
	var interrupted_slot := SCENE.instantiate()
	root.add_child(interrupted_slot)
	await process_frame
	interrupted_slot.present_order(_order(&"order.motion.interrupted.first"), null, [null], [[]], 5, false)
	await _wait(0.10)
	var interrupted_position_before_retarget: Vector2 = interrupted_slot.portrait.position
	interrupted_slot.present_order(_order(&"order.motion.interrupted.second"), null, [null], [[]], 6, false)
	await process_frame
	_check(
		interrupted_slot.portrait.position.distance_to(interrupted_position_before_retarget) < 20.0,
		"an interrupted entrance retargets from its current pose without teleporting to the service position",
	)
	await _wait(1.70)
	_check(StringName(interrupted_slot.get("_order_id")) == &"order.motion.interrupted.second" and not interrupted_slot.is_presentation_transitioning(), "an interrupted entrance still completes the latest replacement")
	interrupted_slot.queue_free()
	await process_frame
	var reduced_order := _order(&"order.motion.reduced")
	slot.present_order(reduced_order, null, [null], [[]], 9, true)
	await process_frame
	_check(
		slot.portrait.position == portrait_rest_position
		and slot.portrait.scale == PORTRAIT_REST_SCALE
		and slot.get_node("OrderPanel").scale == Vector2.ONE,
		"reduced motion keeps both customer layers stationary and unscaled",
	)
	await _wait(0.25)
	_check(
		StringName(slot.get("_order_id")) == &"order.motion.reduced"
		and slot.is_presentation_transitioning()
		and slot.get_node("OrderPanel").visible
		and slot.get_node("OrderPanel").modulate.a < 1.0,
		"the replacement order remains visually withheld while its reduced-motion customer fades in",
	)
	await _wait(0.25)
	_check(StringName(slot.get("_order_id")) == &"order.motion.reduced" and not slot.is_presentation_transitioning() and _is_order_card_above_head(slot) and slot.get_node("OrderPanel").visible, "reduced motion restores the order above the customer's head after arrival")
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


func _is_order_card_above_head(slot: CustomerServiceSlot) -> bool:
	var panel := slot.get_node("OrderPanel") as Control
	var portrait_rest_position := slot.get("_portrait_rest_position") as Vector2
	var expected_position := Vector2(
		portrait_rest_position.x + (slot.portrait.size.x - panel.size.x) * 0.5,
		portrait_rest_position.y - slot.portrait.size.y * (PORTRAIT_REST_SCALE.y - 1.0) - panel.size.y - 14.0,
	)
	return panel.position.is_equal_approx(expected_position)


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
