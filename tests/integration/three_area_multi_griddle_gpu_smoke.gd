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
	_check(multi.get_node_or_null("Background") == null, "multi-griddle station renders without the redundant outer brown frame")
	var units: Array = multi.get("units")
	var legacy_controls_stayed_hidden := true
	for _refresh_index in 12:
		station.call("_refresh_p1_ui")
		await process_frame
		legacy_controls_stayed_hidden = legacy_controls_stayed_hidden and not (station.get_node("SafeArea/P1ControlBar") as Control).visible and not (station.get_node("SafeArea/PhaseLabel") as Control).visible
	_check(legacy_controls_stayed_hidden, "repeated P1 refreshes never flash the legacy heat or phase controls in multi-griddle mode")
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
	var baocui_slot := multi.get_node("SharedToolTray/WorktopSlot07/BaocuiSlot") as FiveAreaMaterialSlot
	var baocui_source := baocui_slot.source_ref()
	var baocui_center := baocui_slot.get_global_rect().get_center()
	var baocui_drop_center := (unit_two.pancake_surface as Control).get_global_rect().get_center() + Vector2(8.0, 0.0)
	_move_at(baocui_center)
	_press_at(baocui_center)
	await process_frame
	_move_at(baocui_drop_center, MOUSE_BUTTON_MASK_LEFT)
	await process_frame
	_check(root.gui_is_dragging() and root.gui_get_drag_data() is Dictionary, "real pointer drag starts from physical worktop slot 07")
	var drag_payload := Dictionary(root.gui_get_drag_data())
	_check(StringName(Dictionary(drag_payload.get("source_ref", {})).get("stock_id", &"")) == &"stock.pancake.baocui", "physical slot 07 drag carries the baocui stock identity")
	_check(unit_two.pancake_surface._can_drop_data(unit_two.pancake_surface.size * 0.5 + Vector2(8.0, 0.0), drag_payload), "real baocui drag is accepted by the target griddle hit layer")
	unit_two.pancake_surface._drop_data(unit_two.pancake_surface.size * 0.5 + Vector2(8.0, 0.0), drag_payload)
	_release_at(baocui_drop_center)
	await process_frame
	_check(unit_two.applied_ingredient_ids.has("stock.pancake.baocui"), "real pointer drag places baocui on the selected griddle")
	units[2].call("_refresh_ui")
	multi.call("_on_shared_tool_selected", &"stock.pancake.sauce.sweet_flour")
	var brush_center := (unit_two.pancake_surface as Control).get_global_rect().get_center()
	_move_at(brush_center)
	_press_at(brush_center)
	await process_frame
	_check(unit_two.sauce_brush_artwork.visible and (root.gui_get_hovered_control() == unit_two.pancake_surface), "real pointer press on the compact surface shows the authored sauce brush on the true hit layer; visible=%s hovered=%s action=%s selected=%s" % [unit_two.sauce_brush_artwork.visible, str(root.gui_get_hovered_control().get_path() if root.gui_get_hovered_control() != null else "none"), str(unit_two.get("_surface_action")), str(multi.get("_selected_tool"))])
	_release_at(brush_center)
	await process_frame
	_check(not unit_two.sauce_brush_artwork.visible, "real sauce brush hides on pointer release")
	var fold_button := unit_two.fold_action as Button
	var fold_center := fold_button.get_global_rect().get_center()
	_move_at(fold_center)
	_press_at(fold_center)
	_release_at(fold_center)
	await process_frame
	_check(unit_two.fold_steps == 1, "real pointer click folds the enlarged griddle once")
	_move_at(fold_center)
	_press_at(fold_center)
	_release_at(fold_center)
	await process_frame
	_check(unit_two.fold_steps == 2, "real pointer click completes the second fold and packaging step")
	var spread_unit: Node = units[0]
	spread_unit.call("reset_unit")
	spread_unit.call("begin_order", order)
	multi.call("_on_shared_tool_selected", &"tool.pancake.spreader")
	var spread_center := (spread_unit.pancake_surface as Control).get_global_rect().get_center()
	_move_at(spread_center)
	_press_at(spread_center)
	await process_frame
	var spread_target := spread_center + Vector2(22.0, 0.0)
	_move_at(spread_target, MOUSE_BUTTON_MASK_LEFT)
	await process_frame
	_check(spread_unit.spreader_artwork.visible and spread_unit.spreader_artwork.position.distance_to(spread_unit.pancake_surface.pointer_local_position) < 1.0, "real pointer drag shows the authored spreader at the compact-pan contact point")
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
	_check(tray.visible and tray.get_node_or_null("Background") == null and tray.get_node_or_null("PhysicalToolRow") == null, "pancake tools render directly in the authored worktop without a dark second tray")
	_check(tray.get_global_rect().position.x == 341.0 and tray.get_global_rect().end.x == 1580.0 and tray.get_global_rect().position.y == 956.0, "pancake tools occupy exact physical worktop slots 04 through 15")
	_check(not tray.get_global_rect().intersects(soy.get_global_rect()) and not tray.get_global_rect().intersects(youtiao.get_global_rect()), "shared tray does not enter soy or youtiao hit regions")
	var previous_slot_rect := Rect2()
	for slot_offset in 12:
		var host := tray.get_node("WorktopSlot%02d" % (slot_offset + 4)) as Control
		_check(host.get_global_rect().size == Vector2(89.0, 89.0), "worktop slot %02d keeps the physical 89x89 visible and hit region" % (slot_offset + 4))
		if slot_offset > 0:
			_check(not previous_slot_rect.intersects(host.get_global_rect()), "worktop slots %02d and %02d do not overlap input" % [slot_offset + 3, slot_offset + 4])
		previous_slot_rect = host.get_global_rect()
	baocui_slot = tray.get_node("WorktopSlot07/BaocuiSlot") as FiveAreaMaterialSlot
	_check(baocui_slot.material_texture.resource_path == "res://resources/art/ingredients/baocui/baocui_intact_v1.png", "physical worktop slot 07 displays real baocui artwork")
	var youtiao_slots: Array[Node] = station.get("youtiao_dough_slots")
	_check(youtiao_slots[0].get_global_rect().position.x == 1595.0 and youtiao_slots[2].get_global_rect().end.x == 1893.0, "youtiao dough aligns to worktop slots 16 through 18")
	_check(units[0].position.x == 390.0 and units[1].position.x == 0.0 and units[2].position.x == 780.0, "logical griddles render center, left, right without slot reordering")
	for index in 3:
		var unit := units[index] as Control
		_check(unit.visible and multi.get_global_rect().encloses(unit.get_global_rect()), "griddle %d remains fully inside the pancake operation region" % (index + 1))
		var surface := unit.get_node("PancakeSurface") as PancakeHeatmap
		var material := (surface.get_node("PancakeVisual") as TextureRect).material as ShaderMaterial
		_check(unit.get_node_or_null("Frame") == null and unit.griddle_art.size.is_equal_approx(Vector2(405.6, 213.2)), "griddle %d uses the 1.3x ellipse without a rectangular frame" % (index + 1))
		_check(surface.size.is_equal_approx(Vector2(278.2, 278.2)) and not surface.draw_pan_outline and surface.elliptical_hit_test, "griddle %d uses the enlarged aligned outline-free elliptical surface" % (index + 1))
		_check(material != null and material.shader.resource_path == "res://resources/shaders/pancake_surface.gdshader", "griddle %d uses the production pancake shader instead of raw field pixels" % (index + 1))
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
	_release_at(spread_target)
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


func _move_at(position: Vector2, button_mask: int = 0) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	motion.button_mask = button_mask
	root.push_input(motion)


func _press_at(position: Vector2) -> void:
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = position
	pressed.global_position = position
	root.push_input(pressed)


func _release_at(position: Vector2) -> void:
	var released := InputEventMouseButton.new()
	released.button_index = MOUSE_BUTTON_LEFT
	released.pressed = false
	released.position = position
	released.global_position = position
	root.push_input(released)


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
