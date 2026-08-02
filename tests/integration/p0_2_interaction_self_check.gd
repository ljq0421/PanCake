extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var workstation := main.get_node("Workstation") as Workstation
	workstation.set_process(false)
	var surface := workstation.pancake_surface
	_check(workstation.warning_tone != null, "workstation scene contains procedural pre-hole warning audio")
	_check(surface.heatmap_field == PancakeHeatmap.VIEW_APPEARANCE, "player sees intuitive pancake view by default")

	workstation.ladle_button.pressed.emit()
	_check(workstation.tool_controller.current_tool == ToolController.Tool.SCRAPER, "clicking automatic pour immediately equips the T-shaped spreader")
	var poured_snapshot := workstation.pancake_model.snapshot()
	var mass_after_first_pour := workstation.pancake_model.total_thickness()
	_check(workstation.pancake_model.total_thickness() > 0.0, "one ladle-button click deposits the calibrated batter charge")
	_check(mass_after_first_pour >= 2500.0 and mass_after_first_pour <= 2700.0, "automatic batter mass stays within the full-griddle calibration range")
	_check(float(workstation.pancake_model.calculate_summary().coverage_ratio) > 0.0, "automatic pour creates a central batter mound")
	_check(workstation.pancake_model.get_field_value(PancakeModel.FIELD_THICKNESS, Vector2i(64, 64)) > 0.0, "automatic pour is centered on the griddle")
	_check(workstation.pour_used, "automatic pour permanently consumes the one-pour allowance")
	_check(workstation.ladle_button.disabled, "ladle button locks after first pour")

	workstation.ladle_button.pressed.emit()
	_check(is_equal_approx(workstation.pancake_model.total_thickness(), mass_after_first_pour), "second ladle-button press cannot add batter")

	workstation.scraper_button.pressed.emit()
	_check(workstation.tool_controller.current_tool == ToolController.Tool.SCRAPER, "clicking spreader button selects the T-shaped spreader")
	surface.pointer_local_position = Vector2(300, 300)
	workstation._update_spreader_artwork(0.0)
	_check(workstation.spreader_artwork.visible, "formal spreader artwork becomes visible over the griddle")
	_check(workstation.spreader_artwork.texture.resource_path == "res://resources/art/workstation/tools/batter_spreader_v1.png", "T-shaped spreader uses the approved artwork")
	_check(workstation.parameters.spreader_min_circularity <= 0.20, "spreading accepts a very loose curved gesture instead of requiring a near-perfect circle")
	_check(workstation.parameters.spreader_inward_tolerance >= 16.0, "spreading tolerates broad inward hand wobble")
	_check(workstation.parameters.spreader_direction_grace_samples >= 4, "several brief off-angle samples receive direction grace")
	workstation._spreader_speed_initialized = false
	workstation._spreader_speed_band = Workstation.SPREADER_SPEED_MEDIUM
	workstation._update_spreader_speed(2.0, 1.0 / 60.0)
	_check(workstation._spreader_speed_label() == "慢", "wide speed bands classify an intentionally slow circle")
	workstation._update_spreader_speed(3.0, 1.0 / 60.0)
	_check(workstation._spreader_speed_label() == "慢", "speed hysteresis prevents small hand jitter from immediately changing bands")
	workstation._update_spreader_speed(6.4, 0.5)
	_check(workstation._spreader_speed_label() == "适中", "smoothed speed passes through the medium band instead of jumping directly")
	workstation._update_spreader_speed(8.0, 0.5)
	_check(workstation._spreader_speed_label() == "快", "sustained fast circling reaches the thick-pancake band")
	workstation._spreader_angle_initialized = false
	surface.pointer_local_position = Vector2(400, 300)
	workstation._update_spreader_artwork(0.0)
	var rotation_before_dead_zone := workstation.spreader_artwork.rotation
	surface.pointer_local_position = Vector2(300, 300) + Vector2.from_angle(0.08) * 100.0
	workstation._update_spreader_artwork(1.0 / 60.0)
	_check(is_equal_approx(workstation.spreader_artwork.rotation, rotation_before_dead_zone), "small pointer-angle jitter stays inside the T-spreader rotation dead zone")
	var rotation_before := workstation.spreader_artwork.rotation
	surface.pointer_local_position = Vector2(300, 100)
	workstation._update_spreader_artwork(1.0 / 60.0)
	var rotation_step := absf(wrapf(workstation.spreader_artwork.rotation - rotation_before, -PI, PI))
	_check(rotation_step <= workstation.parameters.spreader_max_turn_rate / 60.0 + 0.0001, "T-spreader turn rate is capped instead of snapping to the pointer radius")
	_press_surface(surface, Vector2(320, 300))
	for frame in range(1, 61):
		var position := Vector2(320, 300).lerp(Vector2(430, 300), float(frame) / 60.0)
		_move_surface(surface, position)
		workstation._process(1.0 / 60.0)
	_release_surface(surface, Vector2(430, 300))
	var straight_snapshot := workstation.pancake_model.snapshot()
	_check(_max_difference(poured_snapshot.thickness, straight_snapshot.thickness) < 0.0001, "straight outward dragging does not replace the required circular spreading motion")

	var pan_center := Vector2(300, 300)
	_press_surface(surface, pan_center + Vector2(40, 0))
	for frame in range(1, 81):
		var angle := float(frame) * 0.012
		var radius := 40.0 + float(frame)
		var loose_curve := pan_center + Vector2(cos(angle) * radius, sin(angle) * radius * workstation.parameters.pan_height_ratio)
		_move_surface(surface, loose_curve)
		workstation._process(1.0 / 60.0)
	_release_surface(surface, surface.pointer_local_position)
	var loose_curve_snapshot := workstation.pancake_model.snapshot()
	_check(_max_difference(straight_snapshot.thickness, loose_curve_snapshot.thickness) > 0.0001, "a loose outward curve is accepted without requiring a near-perfect circle")

	var spiral_start := pan_center + Vector2(24, 0)
	_press_surface(surface, spiral_start)
	for frame in range(1, 181):
		var progress := float(frame) / 180.0
		var angle := progress * TAU * 2.4
		var radius := lerpf(24.0, 150.0, progress)
		var position := pan_center + Vector2(cos(angle) * radius, sin(angle) * radius * workstation.parameters.pan_height_ratio)
		_move_surface(surface, position)
		workstation._process(1.0 / 60.0)
	_release_surface(surface, surface.pointer_local_position)
	var scraped_snapshot := workstation.pancake_model.snapshot()
	_check(_max_difference(straight_snapshot.thickness, scraped_snapshot.thickness) > 0.0001, "center-outward circular motion changes the pancake thickness distribution")
	_check(surface.cursor_is_t_spreader, "active spreading tool keeps the T-spreader cursor mode")

	_cancel_surface(surface, surface.pointer_local_position)
	_check(workstation.tool_controller.current_tool == ToolController.Tool.NONE, "right mouse returns current tool")
	_check(not workstation.spreader_artwork.visible, "returning the spreader hides its artwork")
	_check(not surface.pointer_pressed, "release/cancel leaves no stuck pointer state")
	_check(workstation.pancake_model.validate().is_empty(), "scene interaction leaves model fields valid")
	workstation.reset_pancake()
	_check(not workstation.pour_used and not workstation.ladle_button.disabled, "reset restores the single pour allowance")

	main.queue_free()
	await process_frame
	await process_frame
	await process_frame
	_finish()


func _press_surface(surface: PancakeHeatmap, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	surface._gui_input(event)


func _move_surface(surface: PancakeHeatmap, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	surface._gui_input(event)


func _release_surface(surface: PancakeHeatmap, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = position
	surface._gui_input(event)


func _cancel_surface(surface: PancakeHeatmap, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = position
	surface._gui_input(event)


func _max_difference(first: PackedFloat32Array, second: PackedFloat32Array) -> float:
	var difference := 0.0
	for index in first.size():
		difference = maxf(difference, absf(first[index] - second[index]))
	return difference


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("P0.2 interaction self-check PASS")
		quit(0)
	else:
		print("P0.2 interaction self-check FAIL (%d)" % _failures.size())
		quit(1)
