extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const SCREENSHOT_PATH := "res://tmp/validation/three_area_multi_griddle_gpu_1920x1080.png"

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
	units[2].call("apply_sauce", &"stock.pancake.sauce.sweet_flour")
	units[2].call("apply_ingredient", &"stock.pancake.egg")
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
	for index in 3:
		var unit := units[index] as Control
		_check(unit.visible and multi.get_global_rect().encloses(unit.get_global_rect()), "griddle %d remains fully inside the pancake operation region" % (index + 1))
	_check(station.get_node_or_null("FiveAreaInfrastructure/Stations/PackagedDrinkStation") == null, "packaged-drink region is absent")
	_check(station.get_node_or_null("FiveAreaInfrastructure/Stations/SteamerStation") == null, "steamer region is absent")

	await RenderingServer.frame_post_draw
	var output_absolute := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(output_absolute.get_base_dir())
	var image := root.get_texture().get_image()
	var save_error := image.save_png(output_absolute)
	_check(save_error == OK and image.get_size() == Vector2i(1920, 1080), "captured a real 1920x1080 GPU frame")
	game.queue_free()
	await process_frame
	_finish(output_absolute)


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
