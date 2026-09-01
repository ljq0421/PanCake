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
	_check(slot.patience_bar.get_theme_stylebox(&"fill").bg_color == Color("6eaa78"), "patience above 60 percent renders green")
	order["remaining_patience_seconds"] = 60.0 * 0.60
	slot.bind_order(order, null, [null], [], 17)
	_check(slot.patience_bar.get_theme_stylebox(&"fill").bg_color == Color("e9b44f"), "patience from 31 to 60 percent renders yellow")
	order["remaining_patience_seconds"] = 60.0 * 0.30
	slot.bind_order(order, null, [null], [], 17)
	_check(slot.patience_bar.get_theme_stylebox(&"fill").bg_color == Color("dc5a3e"), "patience at 30 percent or below renders red")
	order["remaining_patience_seconds"] = 60.0
	slot.bind_order(order, null, [null], [], 17)
	_check(slot.order_title.text == "17", "order card top displays the exact perfect-completion quote")
	var two_item_order := order.duplicate(true)
	two_item_order["items"] = [
		{"product_id": &"product.pancake.custom", "quantity": 1, "prepared_product_instance_ids": []},
		{"product_id": &"product.youtiao.plain", "quantity": 1, "prepared_product_instance_ids": []},
	]
	slot.bind_order(two_item_order, null, [null, null], [[], []], 17)
	_check(
		slot.get_node("OrderPanel").size == Vector2(264.0, 282.0)
		and slot.patience_bar.position == Vector2(64.5, 256.5)
		and slot.patience_bar.size == Vector2(187.5, 13.5)
		and is_equal_approx(slot.patience_bar.value, 100.0),
		"a normal item and a pancake each receive their own 60-pixel block above the fixed progress footer",
	)
	var multi_item_order := order.duplicate(true)
	multi_item_order["items"] = [
		{"product_id": &"product.pancake.custom", "quantity": 1, "prepared_product_instance_ids": []},
		{"product_id": &"product.youtiao.plain", "quantity": 1, "prepared_product_instance_ids": []},
		{"product_id": &"product.packaged_drink.milk", "quantity": 1, "prepared_product_instance_ids": []},
	]
	var eight_ingredients: Array = []
	for ingredient_index in 8:
		eight_ingredients.append({"display_name": "配料%d" % ingredient_index})
	slot.bind_order(multi_item_order, null, [null, null, null], [eight_ingredients, [], []], 17)
	_check(
		slot.get_node("OrderPanel").size == Vector2(264.0, 287.0)
		and slot.item_buttons[0].visible
		and slot.item_buttons[1].visible
		and slot.item_buttons[2].visible
		and slot.patience_bar.position == Vector2(64.5, 261.5)
		and slot.patience_bar.size == Vector2(187.5, 13.5)
		and is_equal_approx(slot.patience_bar.value, 100.0)
		and slot.get_node("OrderPanel/IngredientSlot1_8").visible,
		"two ordinary products share one row while the pancake keeps its eight requirements in a dedicated block",
	)
	_check(
		slot.item_buttons[0].position == Vector2(9.0, 153.0)
		and slot.item_buttons[1].position == Vector2(17.1, 55.05)
		and slot.item_buttons[2].position == Vector2(99.6, 55.05)
		and slot.item_icons[0].position == Vector2.ZERO and slot.item_icons[0].size == slot.item_buttons[0].size
		and slot.item_icons[1].position == Vector2.ZERO and slot.item_icons[1].size == slot.item_buttons[1].size
		and slot.item_icons[2].position == Vector2.ZERO and slot.item_icons[2].size == slot.item_buttons[2].size,
		"ordinary items share a three-slot row while the pancake target stays centered in its own block",
	)
	slot.bind_order(order, null, [null], [[]], 17)
	_check(
		slot.get_node("OrderPanel").size == Vector2(264.0, 186.0)
		and slot.item_buttons[0].visible
		and not slot.item_buttons[1].visible
		and not slot.item_buttons[2].visible,
		"a one-product order collapses the simple card to one row",
	)
	var one_item_card := slot.get_node("OrderPanel") as Control
	_check(
		one_item_card.position.is_equal_approx(Vector2(-6.0, 68.28))
		and is_equal_approx(one_item_card.get_rect().end.y, slot.portrait.position.y - slot.portrait.size.y * 0.3 - 14.0),
		"the variable-height order card is centered immediately above the customer's head",
	)
	_check(slot.portrait.z_index < 0 and slot.get_node("OrderPanel").z_index > 0 and slot.get_node_or_null("PortraitButton") == null and slot.get_node_or_null("FocusFrame") == null, "portrait renders behind the order-card controls without an unused portrait click target")
	_check(slot.portrait.position.is_equal_approx(Vector2(12.0, 380.0)) and slot.portrait.size.is_equal_approx(Vector2(228.0, 372.4)) and slot.portrait.scale.is_equal_approx(Vector2(1.3, 1.3)), "customer portrait rests at the lowered worktop-facing service position at 1.3x visual scale")
	_check(slot.card_focus_button.mouse_filter == Control.MOUSE_FILTER_STOP, "the order card retains its explicit focus click target")
	var item_hover_style := slot.item_buttons[0].get_theme_stylebox(&"hover") as StyleBoxFlat
	var item_focus_style := slot.item_buttons[0].get_theme_stylebox(&"focus") as StyleBoxFlat
	_check(
		not slot.item_buttons[0].flat
		and slot.item_buttons[0].focus_mode == Control.FOCUS_ALL
		and item_hover_style != null and item_hover_style.border_width_left == 3
		and item_focus_style != null and item_focus_style.border_color == Color("ffd166"),
		"each order item exposes a visible hover and keyboard-focus delivery target",
	)
	var patience_fill := slot.patience_bar.get_theme_stylebox(&"fill") as StyleBoxFlat
	_check(slot.patience_bar.position == Vector2(64.5, 160.5) and slot.patience_bar.size == Vector2(187.5, 13.5) and is_equal_approx(slot.patience_bar.value, 100.0) and patience_fill != null and patience_fill.corner_radius_top_left == 5 and patience_fill.corner_radius_bottom_right == 5, "a full one-item order uses a pill-shaped fill inside the drawn card footer")
	var expanded_order := order.duplicate(true)
	expanded_order["items"] = [
		{"area_id": &"area.packaged_drink", "product_id": &"product.packaged_drink.milk", "quantity": 1, "prepared_product_instance_ids": []},
		{"area_id": &"area.packaged_drink", "product_id": &"product.packaged_drink.soy_milk", "quantity": 1, "prepared_product_instance_ids": []},
		{"area_id": &"area.youtiao", "product_id": &"product.youtiao.plain", "quantity": 1, "prepared_product_instance_ids": []},
		{"area_id": &"area.fresh_soy_milk", "product_id": &"product.fresh_soy_milk.yellow_bean", "quantity": 1, "prepared_product_instance_ids": []},
	]
	slot.bind_order(expanded_order, null, [null, null, null, null], [[], [], [], []], 17)
	_check(slot.item_buttons.size() == 4 and slot.get_node("OrderPanel").size == Vector2(264.0, 282.0) and slot.item_buttons[3].position == Vector2(17.1, 151.05), "four ordinary products add a second three-slot row instead of dropping the fourth item")
	var nine_requirements: Array = []
	for ingredient_index in 9:
		nine_requirements.append({"display_name": "配料%d" % ingredient_index})
	slot.bind_order({
		"order_id": &"order.tall.pancake",
		"patience_seconds": 60.0,
		"remaining_patience_seconds": 60.0,
		"items": [{"area_id": &"area.pancake", "product_id": &"product.pancake.custom", "quantity": 1, "prepared_product_instance_ids": []}],
	}, null, [null], [nine_requirements], 17)
	_check(slot.get_node("OrderPanel").size == Vector2(264.0, 232.0) and slot.get_node("OrderPanel/IngredientSlot1_9").visible, "a third pancake ingredient row expands its dedicated block to 136 pixels")
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
	var special_card_size: Vector2 = slot.get_node("OrderPanel").size
	_check(slot.special_title.visible and slot.special_title.text == "超能吃大胃王" and not slot.special_rule.visible and slot.card_focus_button.tooltip_text.find("共3份") >= 0, "special card keeps the customer identity visible while moving its full rule into progressive disclosure")
	slot.card_focus_button.grab_focus()
	_check(slot.special_rule.visible and slot.special_rule.text.find("共3份") >= 0 and slot.get_node("OrderPanel").size == special_card_size, "keyboard focus reveals the special rule without moving the card layout")
	slot.card_focus_button.release_focus()
	slot.call("_sync_special_rule_visibility_from_input")
	_check(not slot.special_rule.visible and slot.get_node("OrderPanel").size == special_card_size, "leaving the card hides secondary rules without collapsing the reserved row")
	_check(slot.quantity_labels[0].visible and slot.quantity_labels[0].text == "0/3", "quantity progress begins at zero of three")
	for delivered_count in [1, 2, 3]:
		special_order["items"][0]["prepared_product_instance_ids"] = range(delivered_count)
		slot.bind_order(special_order, null, [null], [], 18)
		var expected := "✓" if delivered_count == 3 else "%d/3" % delivered_count
		_check(slot.quantity_labels[0].text == expected, "quantity progress renders %s" % expected)
	var completed_single_order := order.duplicate(true)
	completed_single_order["items"] = [{"product_id": &"product.packaged_drink.milk", "quantity": 1, "prepared_product_instance_ids": [&"product.single.done"]}]
	slot.bind_order(completed_single_order, null, [null], [], 17)
	_check(slot.quantity_labels[0].visible and slot.quantity_labels[0].text == "✓" and slot.item_buttons[0].disabled, "a completed single-quantity item keeps an explicit completion mark")
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
		var opened := Dictionary(session.call("open_formal_order", [{"area_id": &"area.packaged_drink", "product_id": &"product.packaged_drink.juice", "quantity": 1, "temperature_mode": &"room_temperature"}], {"base_coins": 17, "patience_seconds": 60.0}))
		var formal_order := Dictionary(opened.get("order", {}))
		var formal_id := StringName(formal_order.get("order_id", &""))
		var attached := Dictionary(session.call("attach_formal_order_product", formal_id, 0, {"product_instance_id": &"product.quote.contract", "product_id": &"product.packaged_drink.juice", "area_id": &"area.packaged_drink", "temperature_mode": &"room_temperature", "grade": &"A", "quality": 100.0}))
		var settlement := Dictionary(session.call("settle_f3_order", formal_id)) if bool(attached.get("success", false)) else {}
		_check(bool(settlement.get("success", false)) and int(settlement.get("earned_coins", -1)) == 9, "the pending payment uses the qualified item's authored unit price instead of the old whole-order quote")
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
