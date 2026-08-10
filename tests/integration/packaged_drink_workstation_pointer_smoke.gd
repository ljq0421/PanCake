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
	var heater_source := drink_station.get_node("HeaterSlot01/HeaterSource01") as Control
	var return_target := drink_station.get_node("CabinetReturnTarget") as Control
	var tray := workstation.get_node("FiveAreaInfrastructure/CustomerHandoffTray")
	var tray_slot_1 := tray.get_node("TrayBody/TraySlots/TraySlot01") as Control
	var tray_slot_2 := tray.get_node("TrayBody/TraySlots/TraySlot02") as Control
	var tray_handle := tray.get_node("TrayHandle") as Control
	var customer_target := tray.get_node("CustomerDropTarget") as Control
	var missing_label := tray.get_node("MissingLabel") as Label
	var payment_button := workstation.get_node("FiveAreaInfrastructure/TrayPaymentButton") as Button

	_check(workstation.get_node_or_null("F3StationOverlay") == null, "formal runtime contains no production overlay")
	_check(workstation.find_child("CloseButton", true, false) == null, "formal runtime contains no production close button")
	_check(lane.visible and lane.get_global_rect().size.x >= 64.0 and lane.get_global_rect().size.y >= 64.0, "physical milk lane is visible and owns a 64px-class hit target")
	_check(tray.visible and tray_slot_1.visible and tray_slot_2.visible and tray.get("_order_id") == order_id, "shared tray is focused on the active two-item order without opening another page")
	_check(tray_handle.get_global_rect().size.y >= 64.0 and customer_target.get_global_rect().size.y >= 64.0, "whole-tray handle and customer target retain 64px-class pointer regions")

	var stock_before_invalid := int(Dictionary(session.call("inventory_snapshot")).get("stock.packaged_drink.milk", 0))
	await _slow_drag(lane.get_global_rect().get_center(), Vector2(70.0, 300.0), 18)
	for _frame in 3:
		await process_frame
	_check(int(Dictionary(session.call("inventory_snapshot")).get("stock.packaged_drink.milk", 0)) == stock_before_invalid, "invalid physical release returns the drink without consuming inventory")

	await _slow_drag(lane.get_global_rect().get_center(), tray_slot_1.get_global_rect().get_center(), 22)
	for _frame in 4:
		await process_frame
	var staged_room_order := Dictionary(session.call("formal_order", order_id))
	_check(_attached_count(staged_room_order, 0) == 1 and int(Dictionary(session.call("inventory_snapshot")).get("stock.packaged_drink.milk", 0)) == 3, "real pointer drag moves one room-temperature package from its lane into exact tray slot 1")

	await _slow_drag(tray_slot_1.get_global_rect().get_center(), return_target.get_global_rect().position + Vector2(22.0, 18.0), 18)
	for _frame in 4:
		await process_frame
	_check(_attached_count(Dictionary(session.call("formal_order", order_id)), 0) == 0 and int(Dictionary(session.call("inventory_snapshot")).get("stock.packaged_drink.milk", 0)) == 4, "real pointer drag takes an unheated package back from the tray to the cabinet")

	await _slow_drag(lane.get_global_rect().get_center(), tray_slot_1.get_global_rect().get_center(), 22)
	for _frame in 3:
		await process_frame
	await _slow_drag(tray_handle.get_global_rect().get_center(), customer_target.get_global_rect().get_center(), 18)
	for _frame in 4:
		await process_frame
	_check(not payment_button.visible and missing_label.text.contains("第2格缺1"), "incomplete whole-tray drag rebounds and lists the exact missing slot")

	await _slow_drag(lane.get_global_rect().get_center(), heater_slot.get_global_rect().get_center(), 22)
	for _frame in 3:
		await process_frame
	_check(int(Dictionary(session.call("inventory_snapshot")).get("stock.packaged_drink.milk", 0)) == 2, "real pointer drag consumes one package only after the heater accepts it")
	# Use the longest supported starter duration so this remains valid if a
	# restored save normalizes the device back to its tier-0 two-second heater.
	session.call("advance_f3_production", 2.2)
	var heater_ui_ready := await _wait_until(func() -> bool: return heater_source.is_visible_in_tree() and not heater_source.disabled, 1.0)
	_check(heater_ui_ready, "heated package becomes a physical draggable output while all other stations remain on screen")
	await _slow_drag(heater_source.get_global_rect().get_center(), tray_slot_2.get_global_rect().get_center(), 22)
	for _frame in 4:
		await process_frame
	var staged_hot_order := Dictionary(session.call("formal_order", order_id))
	_check(_attached_count(staged_hot_order, 1) == 1 and _attached_temperature(staged_hot_order, 1) == &"heated", "real pointer drag moves the completed heated drink into exact tray slot 2")

	await _capture(SCREENSHOT_1920, Vector2i(1920, 1080), "captured the five-area entity shop with the completed shared tray at 1920x1080")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	for _frame in 8:
		await process_frame
	await _capture(SCREENSHOT_1280, Vector2i(1280, 720), "captured the same five-area entity shop at 1280x720")
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	for _frame in 8:
		await process_frame

	var coins_before := int(Dictionary(session.call("five_area_progression_snapshot")).get("coins", 0))
	await _slow_drag(tray_handle.get_global_rect().get_center(), customer_target.get_global_rect().get_center(), 18)
	for _frame in 5:
		await process_frame
	_check(payment_button.visible and Array(session.call("pending_tray_payments")).size() == 1, "real whole-tray drag hands the complete meal to the customer and creates physical payment")
	_move_at(payment_button.get_global_rect().get_center())
	var payment_hovered := await _wait_until(func() -> bool: return root.gui_get_hovered_control() == payment_button, 1.0)
	_check(payment_hovered, "physical customer payment owns the pointer before coin collection")
	await _click_control(payment_button)
	for _frame in 5:
		await process_frame
	_check(not payment_button.visible and int(Dictionary(session.call("five_area_progression_snapshot")).get("coins", 0)) > coins_before, "real pointer click collects customer coins exactly after tray handoff")
	_check(StringName(Dictionary(session.call("formal_order", order_id)).get("state", &"")) == &"settled", "physical tray route settles the deterministic order")

	game.queue_free()
	await process_frame
	_finish()


func _unlock_packaged_drink(session: Node) -> void:
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
	progression.set("tutorial_completed_area_ids", {&"area.pancake": true, &"area.packaged_drink": true})
	progression.set("tutorial_queue_area_ids", [])
	progression.set("tutorial_active_kind", &"")
	progression.set("tutorial_active_id", &"")
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
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.relative = relative
	root.push_input(motion)


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
