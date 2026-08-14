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
	slot.bind_order(order, null, [null], [], 17)
	_check(slot.order_title.text == "完美完成可得 ×17 金币", "order card top displays the exact perfect-completion quote")
	_check(not slot.coin_label.visible, "order card removes the duplicate lower coin amount")
	_check(slot.portrait.z_index < 0 and slot.portrait_button.z_index < 0 and slot.get_node("OrderPanel").z_index > 0 and slot.get_node_or_null("FocusFrame") == null, "portrait and transparent portrait hit area render behind all order-card controls without a customer focus frame")
	_check(slot.portrait_button.mouse_filter == Control.MOUSE_FILTER_STOP and slot.card_focus_button.mouse_filter == Control.MOUSE_FILTER_STOP, "portrait and order card keep separate explicit click targets")
	_check(slot.mouse_filter == Control.MOUSE_FILTER_IGNORE, "customer slot shell cannot cover unrelated foreground controls")
	var special_order := {
		"order_id": &"order.special.ui",
		"customer_id": &"customer_special_glutton",
		"special_customer_id": &"special.glutton",
		"special_title": "超能吃大胃王",
		"special_rule_text": "至少两类餐品 · 共3份 · 完成金币+20%",
		"perfect_quote_coins": 18,
		"patience_seconds": 150.0,
		"remaining_patience_seconds": 150.0,
		"items": [{"product_id": &"product.pancake.custom", "quantity": 3, "prepared_product_instance_ids": []}],
	}
	slot.bind_order(special_order, null, [null], [], 18)
	_check(slot.special_title.visible and slot.special_title.text == "超能吃大胃王" and slot.special_rule.visible and slot.special_rule.text.find("共3份") >= 0, "special title and rule summary come from static order-card labels")
	_check(slot.quantity_labels[0].visible and slot.quantity_labels[0].text == "0/3", "quantity progress begins at zero of three")
	for delivered_count in [1, 2, 3]:
		special_order["items"][0]["prepared_product_instance_ids"] = range(delivered_count)
		slot.bind_order(special_order, null, [null], [], 18)
		var expected := "✓" if delivered_count == 3 else "%d/3" % delivered_count
		_check(slot.quantity_labels[0].text == expected, "quantity progress renders %s" % expected)
	var requested: Array = []
	slot.delivery_requested.connect(func(order_id: StringName, item_index: int): requested.append([order_id, item_index]))
	special_order["items"][0]["prepared_product_instance_ids"] = []
	slot.bind_order(special_order, null, [null], [], 18)
	slot.item_buttons[0].pressed.emit()
	_check(requested == [[&"order.special.ui", 0]], "special card preserves the exact order_id and item_index click route")
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
