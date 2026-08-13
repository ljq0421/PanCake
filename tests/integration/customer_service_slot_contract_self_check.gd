extends SceneTree

const SCENE := preload("res://scenes/gameplay/customer_service_slot.tscn")

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var slot := SCENE.instantiate()
	root.add_child(slot)
	await process_frame
	var order := {
		"order_id": &"order.quote.contract",
		"customer_id": &"customer_01",
		"base_coins": 17,
		"patience_seconds": 60.0,
		"remaining_patience_seconds": 60.0,
		"items": [{"product_id": &"product.packaged_drink.milk", "quantity": 1, "prepared_product_instance_ids": []}],
		"metadata": {"legacy_order": {"title": "this must not replace the quote"}},
	}
	slot.bind_order(order, true, null, [null], [], 17)
	_check(slot.order_title.text == "完美完成可得 ×17 金币", "order card top displays the exact perfect-completion quote")
	_check(not slot.coin_label.visible, "order card removes the duplicate lower coin amount")
	_check(slot.portrait.z_index < 0 and slot.portrait_button.z_index < 0 and slot.get_node("OrderPanel").z_index > 0 and slot.focus_frame.z_index > slot.get_node("OrderPanel").z_index, "portrait and transparent portrait hit area render behind all order-card controls")
	_check(slot.portrait_button.mouse_filter == Control.MOUSE_FILTER_STOP and slot.card_focus_button.mouse_filter == Control.MOUSE_FILTER_STOP, "portrait and order card keep separate explicit click targets")
	_check(slot.mouse_filter == Control.MOUSE_FILTER_IGNORE, "customer slot shell cannot cover unrelated foreground controls")
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession is available for quote-to-settlement verification")
	if session != null:
		session.call("begin_new_game")
		var opened := Dictionary(session.call("open_formal_order", [{"area_id": &"area.packaged_drink", "product_id": &"product.packaged_drink.milk", "quantity": 1, "temperature_mode": &"room_temperature"}], {"base_coins": 17, "patience_seconds": 60.0}))
		var formal_order := Dictionary(opened.get("order", {}))
		var formal_id := StringName(formal_order.get("order_id", &""))
		var attached := Dictionary(session.call("attach_formal_order_product", formal_id, 0, {"product_instance_id": &"product.quote.contract", "product_id": &"product.packaged_drink.milk", "area_id": &"area.packaged_drink", "temperature_mode": &"room_temperature", "grade": &"A", "quality": 100.0}))
		var settlement := Dictionary(session.call("settle_f3_order", formal_id)) if bool(attached.get("success", false)) else {}
		_check(bool(settlement.get("success", false)) and int(settlement.get("earned_coins", -1)) == 17, "the amount displayed as the perfect quote equals the pending amount created by successful settlement")
	slot.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("CUSTOMER_SERVICE_SLOT_CONTRACT_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("CUSTOMER_SERVICE_SLOT_CONTRACT_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
