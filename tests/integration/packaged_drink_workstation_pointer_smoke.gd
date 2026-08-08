extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Packaged-drink workstation pointer smoke must run without --headless")
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
	progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.packaged_drink": true})
	progression.set("device_tiers", {&"device.pancake_griddle": 1, &"device.packaged_drink_heater": 0})
	progression.set("unlocked_recipe_ids", {&"recipe.pancake.base": true, &"recipe.packaged_drink.milk": true})
	progression.set("unlocked_product_ids", {&"product.pancake.custom": true, &"product.packaged_drink.milk": true})
	progression.set("unlocked_stock_ids", {
		&"stock.pancake.batter": true, &"stock.pancake.egg": true, &"stock.pancake.baocui": true,
		&"stock.pancake.scallion": true, &"stock.pancake.sauce.sweet_flour": true,
		&"stock.packaged_drink.milk": true,
	})
	progression.set("area_mastery", {&"area.packaged_drink": 4})
	progression.set("area_mastery_details", {
		&"area.packaged_drink": {"correct_temperature": 4, "correct_streak_current": 2, "correct_streak_best": 3},
	})
	progression.set("tutorial_completed_area_ids", {&"area.pancake": true})
	progression.set("tutorial_queue_area_ids", [&"area.packaged_drink"])
	progression.set("tutorial_active_kind", &"area")
	progression.set("tutorial_active_id", &"area.packaged_drink")
	var inventory: Dictionary = session.call("inventory_snapshot")
	inventory["stock.packaged_drink.milk"] = 1
	session.call("save_inventory", inventory)
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	for _frame in 12:
		await process_frame
	var workstation := game.get_node("Workstation")
	var drink_click := workstation.get_node("SafeArea/FiveAreaStationClickLayers/PackagedDrinkLockedClickLayer") as Button
	_check(not drink_click.disabled, "the unlocked packaged-drink bay remains pointer-interactive")
	var overlay := workstation.get_node("F3StationOverlay") as Control
	var drink_station := workstation.get_node("F3StationOverlay/F3StationsWorkbench/SafeArea/Content/Stations/PackagedDrinkStation")
	var milk_button := drink_station.get_node("Margin/Content/ProductShelf/MilkButton") as Button
	var mastery_label := drink_station.get_node("Margin/Content/MasteryLabel") as Label
	var close_button := workstation.get_node("F3StationOverlay/CloseButton") as Button
	var settle_button := workstation.get_node("F3StationOverlay/F3StationsWorkbench/SafeArea/Content/OrderTargetBar/SettleOrderButton") as Button
	var generated_order: Dictionary = session.call("active_formal_order")
	var generated_id := StringName(generated_order.get("order_id", &""))
	_check(overlay.visible and _area_id(generated_order) == &"area.packaged_drink", "generated drink teaching automatically routes the main workstation to the production overlay")
	_check(not milk_button.disabled and milk_button.text.contains("纯牛奶"), "the opened shelf exposes the unlocked starter drink")
	_check(mastery_label.text.contains("正确温度 4") and mastery_label.text.contains("当前连对 2"), "the opened shelf exposes drink mastery")
	_check(not close_button.get_global_rect().intersects(settle_button.get_global_rect()), "the return control does not cover order submission")
	await _click_control(close_button)
	_check(not overlay.visible, "the real return button closes the production overlay")
	await _click_control(drink_click)
	_check(overlay.visible, "a real click on the unlocked main-workstation bay reopens the generated order")
	await _click_control(milk_button)
	await _click_control(settle_button)
	for _frame in 3:
		await process_frame
	var next_order: Dictionary = session.call("active_formal_order")
	var tutorial := Dictionary(progression.call("tutorial_snapshot"))
	_check(not generated_id.is_empty() and StringName(next_order.get("order_id", &"")) != generated_id, "pointer delivery and settlement advance the deterministic formal order stream")
	_check(int(progression.call("mastery_value", &"area.packaged_drink")) == 5 and Array(tutorial.get("completed_area_ids", [])).has("area.packaged_drink"), "real pointer settlement updates drink mastery and completes teaching")
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


func _area_id(order: Dictionary) -> StringName:
	var items: Array = Array(order.get("items", []))
	return &"" if items.is_empty() else StringName(Dictionary(items[0]).get("area_id", &""))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PACKAGED_DRINK_WORKSTATION_POINTER_SMOKE_PASS")
		quit(0)
		return
	printerr("PACKAGED_DRINK_WORKSTATION_POINTER_SMOKE_FAIL\n" + "\n".join(_failures))
	quit(1)
