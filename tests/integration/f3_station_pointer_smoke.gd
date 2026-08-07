extends SceneTree

const WORKBENCH_SCENE := preload("res://scenes/gameplay/f3_stations_workbench.tscn")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("F3 pointer smoke must run without --headless")
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
	var progression: RefCounted = session.call("progression_service")
	progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.packaged_drink": true, &"area.youtiao": true})
	progression.set("device_tiers", {&"device.pancake_griddle": 1, &"device.packaged_drink_heater": 0, &"device.youtiao_fryer": 0})
	progression.set("unlocked_recipe_ids", {&"recipe.pancake.base": true, &"recipe.packaged_drink.milk": true, &"recipe.youtiao.plain": true})
	progression.set("unlocked_product_ids", {&"product.pancake.custom": true, &"product.packaged_drink.milk": true, &"product.youtiao.plain": true})
	progression.set("unlocked_stock_ids", {&"stock.packaged_drink.milk": true, &"stock.youtiao.plain_dough": true})
	progression.set("tutorial_completed_area_ids", {&"area.pancake": true, &"area.packaged_drink": true, &"area.youtiao": true})
	var inventory: Dictionary = session.call("inventory_snapshot")
	inventory["stock.packaged_drink.milk"] = 3
	inventory["stock.youtiao.plain_dough"] = 2
	session.call("save_inventory", inventory)

	var room_order: Dictionary = session.call("open_formal_order", [{
		"area_id": &"area.packaged_drink",
		"product_id": &"product.packaged_drink.milk",
		"quantity": 1,
		"temperature_mode": &"room_temperature",
	}])
	_check(bool(room_order.get("success", false)), "room-temperature drink order opens")
	var workbench := WORKBENCH_SCENE.instantiate()
	root.add_child(workbench)
	for _frame in 5:
		await process_frame

	var drink := workbench.get_node("SafeArea/Content/Stations/PackagedDrinkStation")
	var milk_button := drink.get_node("Margin/Content/ProductShelf/MilkButton") as Button
	var heater_slot := drink.get_node("Margin/Content/HeaterSlots/HeaterSlot1") as Button
	_check(not milk_button.disabled, "unlocked drink product is pointer-interactive")
	await _click_control(milk_button)
	await process_frame
	var room_item := Dictionary(Array(Dictionary(session.call("active_formal_order")).get("items", []))[0])
	var room_delivered := Array(room_item.get("prepared_product_instance_ids", [])).size() == 1
	_check(room_delivered, "real product click directly delivers a matching room-temperature drink")
	_check(int(Dictionary(session.call("inventory_snapshot")).get("stock.packaged_drink.milk", 0)) == 2, "room-temperature pointer delivery deducts exactly one stock")
	await _click_control(workbench.get_node("SafeArea/Content/OrderTargetBar/SettleOrderButton"))
	await process_frame
	_check(Dictionary(session.call("active_formal_order")).is_empty(), "real settle button closes the completed room-temperature order")
	if not room_delivered or not Dictionary(session.call("active_formal_order")).is_empty():
		workbench.queue_free()
		await process_frame
		_finish()
		return

	var multi_order: Dictionary = session.call("open_formal_order", [
		{
			"area_id": &"area.packaged_drink",
			"product_id": &"product.packaged_drink.milk",
			"quantity": 1,
			"temperature_mode": &"heated",
		},
		{
			"area_id": &"area.youtiao",
			"product_id": &"product.youtiao.plain",
			"quantity": 1,
			"temperature_mode": &"room_temperature",
		},
	])
	_check(bool(multi_order.get("success", false)), "heated-drink and youtiao order opens")
	if not bool(multi_order.get("success", false)):
		workbench.queue_free()
		await process_frame
		_finish()
		return
	workbench.call("refresh_from_session")
	await process_frame
	await _click_control(milk_button)
	await process_frame
	_check(StringName(Dictionary(Array(Dictionary(session.call("f3_machine_snapshot", &"device.packaged_drink_heater")).get("slots", []))[0]).get("state", &"")) == &"empty", "heated product selection does not bypass the explicit heater click")
	await _click_control(heater_slot)
	await process_frame
	_check(StringName(Dictionary(Array(Dictionary(session.call("f3_machine_snapshot", &"device.packaged_drink_heater")).get("slots", []))[0]).get("state", &"")) == &"heating", "real heater-slot click loads the selected drink")
	session.call("advance_f3_production", 2.05)
	await process_frame
	await _click_control(heater_slot)
	await process_frame
	var heated_item := Dictionary(Array(Dictionary(session.call("active_formal_order")).get("items", []))[0])
	_check(Array(heated_item.get("prepared_product_instance_ids", [])).size() == 1, "real ready-slot click delivers the heated drink")

	var order_item_2 := workbench.get_node("SafeArea/Content/OrderTargetBar/OrderItem2") as Button
	await _click_control(order_item_2)
	await process_frame
	var youtiao := workbench.get_node("SafeArea/Content/Stations/YoutiaoStation")
	var plain_button := youtiao.get_node("Margin/Content/RecipeShelf/PlainButton") as Button
	var load_button := youtiao.get_node("Margin/Content/LoadRow/LoadButton") as Button
	var start_button := youtiao.get_node("Margin/Content/ActionRow/StartButton") as Button
	var lift_button := youtiao.get_node("Margin/Content/ActionRow/LiftButton") as Button
	var collect_button := youtiao.get_node("Margin/Content/ActionRow/CollectButton") as Button
	await _click_control(plain_button)
	await process_frame
	await _click_control(load_button)
	await process_frame
	await _click_control(start_button)
	await process_frame
	_check(StringName(Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer")).get("state", &"")) == &"frying", "real youtiao buttons select, load, and start the batch")
	session.call("advance_f3_production", 12.05)
	await process_frame
	await _click_control(lift_button)
	await process_frame
	_check(StringName(Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer")).get("state", &"")) == &"draining", "real lift click moves a cooked batch into draining")
	session.call("advance_f3_production", 2.05)
	await process_frame
	await _click_control(collect_button)
	await process_frame
	var completed_items: Array = Array(Dictionary(session.call("active_formal_order")).get("items", []))
	var youtiao_item := Dictionary(completed_items[1])
	_check(Array(youtiao_item.get("prepared_product_instance_ids", [])).size() == 1, "real collect click delivers one drained youtiao to the selected order item")
	_check(int(Dictionary(session.call("inventory_snapshot")).get("stock.youtiao.plain_dough", 0)) == 1, "youtiao pointer path consumes exactly one dough stock")

	workbench.queue_free()
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
		print("F3_STATION_POINTER_SMOKE_PASS")
		quit(0)
		return
	printerr("F3_STATION_POINTER_SMOKE_FAIL\n" + "\n".join(_failures))
	quit(1)
