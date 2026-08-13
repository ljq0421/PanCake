extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const SCREENSHOT_SPECS := [
	{"size": Vector2i(1920, 1080), "path": "res://tmp/validation/three_area_multi_griddle_gpu_1920x1080.png"},
	{"size": Vector2i(1366, 768), "path": "res://tmp/validation/three_area_multi_griddle_gpu_1366x768.png"},
	{"size": Vector2i(1280, 720), "path": "res://tmp/validation/three_area_multi_griddle_gpu_1280x720.png"},
]

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("THREE_AREA_MULTI_GRIDDLE_GPU_SMOKE_FAIL\nGPU smoke must run without --headless")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession is available")
	if session == null:
		_finish("")
		return
	session.call("begin_new_game")
	var progression: RefCounted = session.call("progression_service")
	progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.youtiao": true, &"area.fresh_soy_milk": true})
	progression.set("device_tiers", {&"device.pancake_griddle": 2, &"device.youtiao_fryer": 2, &"device.fresh_soy_milk_machine": 2})
	progression.set("tutorial_completed_area_ids", {&"area.pancake": true, &"area.youtiao": true, &"area.fresh_soy_milk": true})
	progression.set("tutorial_queue_area_ids", [])
	progression.set("tutorial_active_kind", &"")
	progression.set("tutorial_active_id", &"")
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	for _frame in 10:
		await process_frame
	var station := game.get_node("Workstation")
	station.call("apply_progression_effects", session.call("five_area_progression_snapshot"))
	station.call("_refresh_multi_griddle_mode")
	var multi: Control = station.get_node("FiveAreaInfrastructure/Stations/PancakeStation/MultiGriddleStation")
	multi.call("set_griddle_count", 3)
	var units: Array = multi.get("units")
	var order := {
		"product_id": &"product.pancake.custom",
		"heat_preference": &"golden",
		"ingredient_ids": PackedStringArray(["stock.pancake.egg", "stock.pancake.baocui"]),
		"sauce_ids": PackedStringArray(["stock.pancake.sauce.sweet_flour"]),
		"time_limit": 72.0,
	}
	_prepare_surface(units[0], order, 2, 2.2, 0.0)
	_prepare_surface(units[1], order, 3, 2.7, 1.8)
	_prepare_surface(units[2], order, 4, 2.9, 2.5)
	var unit_two: Node = units[2]
	multi.call("_on_shared_tool_selected", &"stock.pancake.sauce.sweet_flour")
	unit_two.call("_on_surface_pointer_started", unit_two.pancake_surface.size * 0.5)
	unit_two.call("_on_surface_pointer_ended", unit_two.pancake_surface.size * 0.5)
	multi.call("drop_on_unit", 2, {"source_kind": &"pancake_shared_ingredient", "stock_id": &"stock.pancake.baocui"}, unit_two.pancake_surface.size * 0.5 + Vector2(8.0, 0.0))
	units[2].call("_refresh_ui")
	for _frame in 4:
		await process_frame

	var stations := station.get_node("FiveAreaInfrastructure/Stations") as Control
	var soy := stations.get_node("FreshSoyMilkStation") as Control
	var pancake := stations.get_node("PancakeStation") as Control
	var youtiao := stations.get_node("YoutiaoStation") as Control
	_check(stations.get_child_count() == 3, "runtime infrastructure has exactly three operating stations")
	_check(soy.visible and pancake.visible and youtiao.visible and multi.visible, "soy, pancake and youtiao stations are all visible")
	_check(multi.call("griddle_count") == 3, "advanced pancake station exposes three direct-operation griddles")
	_check(not soy.get_global_rect().intersects(pancake.get_global_rect()) and not pancake.get_global_rect().intersects(youtiao.get_global_rect()), "the three operating regions do not overlap")
	_check(soy.get_global_rect().end.x < pancake.get_global_rect().position.x and pancake.get_global_rect().end.x < youtiao.get_global_rect().position.x, "the visual order is soy, pancake, youtiao")
	_check(not (station.get_node("FiveAreaInfrastructure/WasteArea") as Control).visible, "legacy global waste target does not cover a compact griddle")
	_check(not (station.get_node("SafeArea/DiscardCurrentPancakeButton") as Control).visible, "legacy single-griddle redo button does not cover the third griddle")
	var old_rack := station.get_node("SafeArea/IngredientRack") as Control
	_check(not old_rack.visible and old_rack.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_DISABLED, "legacy single-griddle topping drag layer is hidden and input-disabled")
	var old_material_dock := station.get_node("SafeArea/MaterialDock") as Control
	_check(not old_material_dock.visible and old_material_dock.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_DISABLED, "legacy material-slot and transparent lock layers are hidden and input-disabled")
	var tray := multi.get_node("SharedToolTray") as Control
	var tray_row := tray.get_node("PhysicalToolRow") as HBoxContainer
	_check(tray.visible and tray_row.get_child_count() == 12, "shared physical tray exposes batter, spreader, eight toppings, and two sauces")
	_check(tray.get_global_rect().position.x >= 350.0 and tray.get_global_rect().end.x <= 1550.0 and tray.get_global_rect().position.y >= 940.0, "shared tray occupies the pancake-only bottom worktop band")
	_check(not tray.get_global_rect().intersects(soy.get_global_rect()) and not tray.get_global_rect().intersects(youtiao.get_global_rect()), "shared tray does not enter soy or youtiao hit regions")
	_check(units[0].position.x == 390.0 and units[1].position.x == 0.0 and units[2].position.x == 780.0, "logical griddles render center, left, right without slot reordering")
	for index in 3:
		var unit := units[index] as Control
		_check(unit.visible and multi.get_global_rect().encloses(unit.get_global_rect()), "griddle %d remains fully inside the pancake operation region" % (index + 1))
	_check(station.get_node_or_null("FiveAreaInfrastructure/Stations/PackagedDrinkStation") == null, "packaged-drink region is absent")
	_check(station.get_node_or_null("FiveAreaInfrastructure/Stations/SteamerStation") == null, "steamer region is absent")

	var captured_paths := PackedStringArray()
	for screenshot_spec in SCREENSHOT_SPECS:
		var requested_size: Vector2i = screenshot_spec["size"]
		DisplayServer.window_set_size(requested_size)
		for _frame in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var output_absolute := ProjectSettings.globalize_path(str(screenshot_spec["path"]))
		DirAccess.make_dir_recursive_absolute(output_absolute.get_base_dir())
		var image := root.get_texture().get_image()
		var save_error := image.save_png(output_absolute)
		_check(save_error == OK and image.get_size() == requested_size, "captured a real %dx%d GPU frame" % [requested_size.x, requested_size.y])
		captured_paths.append(output_absolute)
	game.queue_free()
	await process_frame
	_finish(",".join(captured_paths))


func _prepare_surface(unit: Node, order: Dictionary, state: int, first_seconds: float, second_seconds: float) -> void:
	unit.call("begin_order", order)
	unit.pancake_model.coverage.fill(1.0)
	unit.pancake_model.thickness.fill(0.55)
	unit.pancake_model.wetness.fill(0.18)
	unit.pancake_model.advance_cooking(first_seconds, unit.p1_session.heat_level)
	unit.first_side_seconds = first_seconds
	if state >= 3:
		unit.pancake_model.flip(true)
		unit.p1_session.phase = P1Session.Phase.SECOND_SIDE
		unit.pancake_model.advance_cooking(second_seconds, unit.p1_session.heat_level)
		unit.second_side_seconds = second_seconds
	if state >= 4:
		unit.p1_session.finish_cooking(unit.pancake_model)
	unit.state = state
	unit.pancake_model.changed.emit()
	unit.call("_refresh_ui")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish(output_absolute: String) -> void:
	if failures.is_empty():
		print("THREE_AREA_MULTI_GRIDDLE_GPU_SMOKE_PASS")
		print("THREE_AREA_SCREENSHOT=%s" % output_absolute)
		quit(0)
		return
	printerr("THREE_AREA_MULTI_GRIDDLE_GPU_SMOKE_FAIL\n" + "\n".join(failures))
	quit(1)
