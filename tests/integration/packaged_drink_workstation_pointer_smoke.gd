extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const SCREENSHOT_1920 := "res://tmp/validation/five_area_entity_shop_gpu_1920x1080.png"
const SCREENSHOT_1280 := "res://tmp/validation/five_area_entity_shop_gpu_1280x720.png"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Five-area physical pointer smoke must run without --headless")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession is available")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	_unlock_packaged_drink(session, false)
	var zero_inventory := Dictionary(session.call("inventory_snapshot"))
	zero_inventory["stock.packaged_drink.milk"] = 0
	session.call("save_inventory", zero_inventory)
	var tutorial_opened := Dictionary(session.call("ensure_active_playable_order"))
	var tutorial_game := MAIN_SCENE.instantiate()
	root.add_child(tutorial_game)
	for _frame in 14:
		await process_frame
	var tutorial_workstation := tutorial_game.get_node("Workstation")
	var tutorial_order := Dictionary(tutorial_opened.get("order", {}))
	_check(bool(tutorial_opened.get("success", false)) and Array(tutorial_order.get("items", [])).size() == 1 and Array(session.call("active_formal_orders")).size() == 1, "zero-stock drink tutorial appears as the store's only active customer")
	_check(tutorial_workstation.tool_status_label.text == "饮品教学：先长按纯牛奶补货，再点击订单商品交付", "zero-stock drink tutorial gives the exact player-facing restock instruction")
	tutorial_game.queue_free()
	await process_frame

	session.call("begin_new_game")
	_unlock_packaged_drink(session)
	var inventory := Dictionary(session.call("inventory_snapshot"))
	inventory["stock.packaged_drink.milk"] = 4
	session.call("save_inventory", inventory)
	var opened: Dictionary = session.call("open_formal_order", [
		{
			"area_id": &"area.packaged_drink",
			"product_id": &"product.packaged_drink.milk",
			"quantity": 1,
			"temperature_mode": &"room_temperature",
		},
		{
			"area_id": &"area.packaged_drink",
			"product_id": &"product.packaged_drink.milk",
			"quantity": 1,
			"temperature_mode": &"heated",
		},
	], {"base_coins": 8, "source": &"five_area_pointer_smoke", "tutorial_no_countdown": true})
	var order := Dictionary(opened.get("order", {}))
	var order_id := StringName(order.get("order_id", &""))
	_check(bool(opened.get("success", false)) and not order_id.is_empty(), "a deterministic two-item physical order opens before the shop scene")

	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	for _frame in 14:
		await process_frame
	var workstation := game.get_node("Workstation")
	var drink_station := workstation.get_node("FiveAreaInfrastructure/Stations/PackagedDrinkStation")
	var lane := drink_station.get_node("Lane01") as Control
	var heater_slot := drink_station.get_node("HeaterSlot01") as Control
	var heater_source := drink_station.get_node("HeaterSlot01/HeaterSource01") as TextureButton
	var heater_state := drink_station.get_node("HeaterSlot01/HeaterState01") as Label
	var first_order_target := workstation.get_node("SafeArea/OrderCard/OrderDishTarget1") as Button
	var second_order_target := workstation.get_node("SafeArea/OrderCard/OrderDishTarget2") as Button
	var payment_button := workstation.get_node("FiveAreaInfrastructure/PendingPaymentButton") as Button

	_check(workstation.get_node_or_null("F3StationOverlay") == null, "formal runtime contains no production overlay")
	_check(workstation.find_child("CloseButton", true, false) == null, "formal runtime contains no production close button")
	_check(workstation.get_node_or_null("FiveAreaInfrastructure/CustomerHandoffTray") == null, "formal runtime contains no customer handoff tray")
	_check(lane.visible and lane.get_global_rect().size.x >= 110.0 and lane.get_global_rect().size.y >= 52.0, "physical milk lane spans the former product-plus-restock hit area")
	_check(drink_station.get_node_or_null("Restock01") == null and drink_station.get_node_or_null("Restock02") == null and drink_station.get_node_or_null("Restock03") == null and drink_station.get_node_or_null("Restock04") == null, "the display rack contains no separate restock buttons")
	_check(not first_order_target.disabled and not second_order_target.disabled, "both incomplete order-card products expose real pointer targets")
	_check(StringName(workstation.get("_formal_order_id")) == order_id, "the deterministic drink customer is already the focused current order")

	_move_at(first_order_target.get_global_rect().get_center())
	await process_frame
	var first_target_hovered := root.gui_get_hovered_control()
	_check(first_target_hovered == first_order_target, "room-temperature order icon owns the real pointer before delivery; hovered=%s visible=%s filter=%s rect=%s" % [str(first_target_hovered.get_path() if first_target_hovered != null else "none"), first_order_target.is_visible_in_tree(), first_order_target.mouse_filter, first_order_target.get_global_rect()])
	await _click_control(first_order_target)
	for _frame in 4:
		await process_frame
	var staged_room_order := Dictionary(session.call("formal_order", order_id))
	_check(_attached_count(staged_room_order, 0) == 1 and int(Dictionary(session.call("inventory_snapshot")).get("stock.packaged_drink.milk", 0)) == 3, "real order-card click moves one room-temperature package from its lane into exact item 1")
	_check(first_order_target.disabled and not second_order_target.disabled and not payment_button.visible, "first completed item disables while incomplete order waits for item 2 without paying early")
	var stock_before_invalid := int(Dictionary(session.call("inventory_snapshot")).get("stock.packaged_drink.milk", 0))
	await _slow_drag(lane.get_global_rect().get_center(), Vector2(70.0, 300.0), 18)
	for _frame in 3:
		await process_frame
	_check(int(Dictionary(session.call("inventory_snapshot")).get("stock.packaged_drink.milk", 0)) == stock_before_invalid, "invalid physical release returns the drink without consuming inventory")

	await _slow_drag(lane.get_global_rect().get_center(), heater_slot.get_global_rect().get_center(), 22)
	for _frame in 3:
		await process_frame
	_check(int(Dictionary(session.call("inventory_snapshot")).get("stock.packaged_drink.milk", 0)) == 2, "real pointer drag consumes one package only after the heater accepts it")
	var countdown_visible := await _wait_until(func() -> bool: return heater_state.text.ends_with("秒") and heater_state.text != "0.0秒", 1.0)
	var countdown_before := heater_state.text
	_check(countdown_visible and heater_slot.get_theme_stylebox("panel") == drink_station.get("heater_heating_style"), "heating slot shows a remaining-seconds countdown with its authored heating style")
	session.call("advance_f3_production", 0.35)
	var countdown_decreased := await _wait_until(func() -> bool: return heater_state.text.ends_with("秒") and heater_state.text != countdown_before, 1.0)
	_check(countdown_decreased, "visible heater countdown decreases instead of counting elapsed time upward")
	# Use the longest supported starter duration so this remains valid if a
	# restored save normalizes the device back to its tier-0 two-second heater.
	session.call("advance_f3_production", 2.2)
	var heater_ui_ready := await _wait_until(func() -> bool: return heater_source.is_visible_in_tree() and not heater_source.disabled and heater_state.text == "已加热", 1.0)
	_check(heater_ui_ready and heater_slot.get_theme_stylebox("panel") == drink_station.get("heater_ready_style") and heater_source.texture_normal != null, "completed drink shows the heated art, explicit label, and warm ready style")

	await _capture(SCREENSHOT_1920, Vector2i(1920, 1080), "captured the five-area entity shop with room-temperature delivery and heated output ready at 1920x1080")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	for _frame in 8:
		await process_frame
	await _capture(SCREENSHOT_1280, Vector2i(1280, 720), "captured the same five-area entity shop at 1280x720")
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	for _frame in 8:
		await process_frame

	var coins_before := int(Dictionary(session.call("five_area_progression_snapshot")).get("coins", 0))
	_move_at(second_order_target.get_global_rect().get_center())
	await process_frame
	var second_target_hovered := root.gui_get_hovered_control()
	_check(second_target_hovered == second_order_target, "heated order icon owns the real pointer before delivery; hovered=%s visible=%s filter=%s rect=%s" % [str(second_target_hovered.get_path() if second_target_hovered != null else "none"), second_order_target.is_visible_in_tree(), second_order_target.mouse_filter, second_order_target.get_global_rect()])
	await _click_control(second_order_target)
	for _frame in 5:
		await process_frame
	var staged_hot_order := Dictionary(session.call("formal_order", order_id))
	_check(_attached_count(staged_hot_order, 1) == 1 and _attached_temperature(staged_hot_order, 1) == &"heated", "real order-card click consumes the completed heated drink into exact item 2")
	_check(payment_button.visible and Array(session.call("pending_order_payments")).size() == 1, "last real order-card click creates a durable physical payment")
	_check(StringName(staged_hot_order.get("state", &"")) == &"settled" and StringName(workstation.get("_formal_order_id")) != order_id, "last product click settles the order and starts the next customer before collection")
	_move_at(payment_button.get_global_rect().get_center())
	var payment_hovered := await _wait_until(func() -> bool: return root.gui_get_hovered_control() == payment_button, 1.0)
	_check(payment_hovered, "pending customer payment owns the pointer before coin collection")
	await _click_control(payment_button)
	for _frame in 5:
		await process_frame
	_check(not payment_button.visible and int(Dictionary(session.call("five_area_progression_snapshot")).get("coins", 0)) > coins_before, "real pointer click collects all pending customer coins exactly once")

	var stock_before_restock := int(Dictionary(session.call("inventory_snapshot")).get("stock.packaged_drink.milk", 0))
	_press_at(lane.get_global_rect().get_center())
	await _wait_seconds(0.65)
	_release_at(lane.get_global_rect().get_center())
	for _frame in 3:
		await process_frame
	var stock_after_restock := int(Dictionary(session.call("inventory_snapshot")).get("stock.packaged_drink.milk", 0))
	_check(stock_after_restock == stock_before_restock + 1, "real hold on the drink lane adds exactly one drink")
	await _slow_drag(lane.get_global_rect().get_center(), Vector2(70.0, 300.0), 18)
	for _frame in 3:
		await process_frame
	_check(int(Dictionary(session.call("inventory_snapshot")).get("stock.packaged_drink.milk", 0)) == stock_after_restock, "lane hold-to-restock does not mask a later lane drag")

	await _slow_drag(lane.get_global_rect().get_center(), heater_slot.get_global_rect().get_center(), 22)
	for _frame in 3:
		await process_frame
	session.call("advance_f3_production", 11.0)
	var cooled_visible := await _wait_until(func() -> bool: return heater_state.text == "已冷却", 1.0)
	_check(cooled_visible and heater_slot.get_theme_stylebox("panel") == drink_station.get("heater_cooled_style") and "废弃区" in heater_slot.tooltip_text, "cooled drink is visually distinct and explains its discard route")

	game.queue_free()
	await process_frame
	_finish()


func _unlock_packaged_drink(session: Node, tutorial_completed: bool = true) -> void:
	var progression: RefCounted = session.call("progression_service")
	var areas := Dictionary(progression.get("unlocked_area_ids"))
	areas[&"area.packaged_drink"] = true
	progression.set("unlocked_area_ids", areas)
	var products := Dictionary(progression.get("unlocked_product_ids"))
	products[&"product.packaged_drink.milk"] = true
	progression.set("unlocked_product_ids", products)
	var recipes := Dictionary(progression.get("unlocked_recipe_ids"))
	recipes[&"recipe.packaged_drink.milk"] = true
	progression.set("unlocked_recipe_ids", recipes)
	var stocks := Dictionary(progression.get("unlocked_stock_ids"))
	stocks[&"stock.packaged_drink.milk"] = true
	progression.set("unlocked_stock_ids", stocks)
	var tiers := Dictionary(progression.get("device_tiers"))
	tiers[&"device.packaged_drink_heater"] = 1
	progression.set("device_tiers", tiers)
	progression.set("tutorial_completed_area_ids", {&"area.pancake": true, &"area.packaged_drink": true} if tutorial_completed else {&"area.pancake": true})
	progression.set("tutorial_queue_area_ids", [] if tutorial_completed else [&"area.packaged_drink"])
	progression.set("tutorial_active_kind", &"" if tutorial_completed else &"area")
	progression.set("tutorial_active_id", &"" if tutorial_completed else &"area.packaged_drink")
	session.call("_sync_progression_to_save")
	session.set("_production_service", null)
	session.call("_ensure_production_service")


func _attached_count(order: Dictionary, item_index: int) -> int:
	var items := Array(order.get("items", []))
	if item_index < 0 or item_index >= items.size():
		return 0
	return Array(Dictionary(items[item_index]).get("attached_products", [])).size()


func _attached_temperature(order: Dictionary, item_index: int) -> StringName:
	var items := Array(order.get("items", []))
	if item_index < 0 or item_index >= items.size():
		return &""
	var products := Array(Dictionary(items[item_index]).get("attached_products", []))
	if products.is_empty():
		return &""
	return StringName(Dictionary(products.back()).get("temperature_mode", &""))


func _slow_drag(from: Vector2, to: Vector2, steps: int) -> void:
	_move_at(from)
	await process_frame
	_press_at(from)
	await process_frame
	for step in range(1, steps + 1):
		var point := from.lerp(to, float(step) / float(steps))
		_move_at(point, Vector2(1.0, 0.0))
		await process_frame
	_release_at(to)
	await process_frame


func _click_control(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	_move_at(point)
	await process_frame
	_press_at(point)
	await process_frame
	_release_at(point)
	await process_frame


func _move_at(point: Vector2, relative: Vector2 = Vector2.ZERO) -> void:
	Input.warp_mouse(point)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.relative = relative
	Input.parse_input_event(motion)


func _press_at(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = point
	event.global_position = point
	root.push_input(event)


func _release_at(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = point
	event.global_position = point
	root.push_input(event)


func _capture(path: String, expected_size: Vector2i, message: String) -> void:
	await RenderingServer.frame_post_draw
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var image := root.get_texture().get_image()
	_check(image.save_png(absolute) == OK and image.get_size() == expected_size, message)


func _wait_until(predicate: Callable, timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			return true
		await process_frame
	return bool(predicate.call())


func _wait_seconds(seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PACKAGED_DRINK_WORKSTATION_POINTER_SMOKE_PASS")
		quit(0)
		return
	printerr("PACKAGED_DRINK_WORKSTATION_POINTER_SMOKE_FAIL\n" + "\n".join(_failures))
	quit(1)
