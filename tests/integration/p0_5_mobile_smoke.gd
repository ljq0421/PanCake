extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const FOLD_MODEL_SCRIPT := preload("res://scripts/gameplay/pancake_fold_model.gd")


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
	_fill_uniform_pancake(workstation.pancake_model)
	_sculpt_irregular_left_edge(workstation.pancake_model)
	workstation.pour_used = true
	workstation.fold_button.pressed.emit()
	var capture_directory := ProjectSettings.globalize_path("res://tmp/validation")
	DirAccess.make_dir_recursive_absolute(capture_directory)

	# Hold a real drag at mid-fold for one rendered frame so the validation
	# artifact covers the flexible in-motion silhouette, not only the result.
	var preview_start := Vector2(110, 300)
	var preview_midpoint := Vector2(205, 300)
	_press_surface(surface, preview_start)
	_move_surface(workstation, surface, preview_start, preview_midpoint, 45)
	await process_frame
	var motion_path := capture_directory.path_join("p0_5_folding_motion.png")
	if root.get_texture().get_image().save_png(motion_path) != OK:
		push_error("Failed to save P0.5 folding-motion capture")
		quit(1)
		return
	_release_surface(surface, preview_midpoint)
	await process_frame
	_fill_uniform_pancake(workstation.pancake_model)

	var drag_started := Time.get_ticks_usec()
	_drag_surface(workstation, surface, Vector2(110, 300), Vector2(300, 300), 90)
	var drag_usec := Time.get_ticks_usec() - drag_started
	await create_timer(0.60).timeout
	drag_started = Time.get_ticks_usec()
	_drag_surface(workstation, surface, Vector2(490, 300), Vector2(300, 300), 90)
	drag_usec += Time.get_ticks_usec() - drag_started
	await create_timer(0.60).timeout
	if workstation.fold_model.completed_fold_count() != 2 or workstation.paper_sleeve_button.disabled or workstation.tray_button.disabled:
		push_error("P0.5 intact fold smoke-check FAIL")
		quit(1)
		return
	var folded_path := capture_directory.path_join("p0_5_folded.png")
	if root.get_texture().get_image().save_png(folded_path) != OK:
		push_error("Failed to save P0.5 folded capture")
		quit(1)
		return
	workstation.paper_sleeve_button.pressed.emit()
	await create_timer(0.32).timeout
	var sleeve_path := capture_directory.path_join("p0_5_sleeve.png")
	if root.get_texture().get_image().save_png(sleeve_path) != OK:
		push_error("Failed to save P0.5 reinforced-sleeve capture")
		quit(1)
		return

	workstation.reset_pancake()
	_fill_uniform_pancake(workstation.pancake_model)
	workstation.pour_used = true
	_set_hole(workstation.pancake_model, Vector2i(25, 64))
	workstation.fold_button.pressed.emit()
	_drag_surface(workstation, surface, Vector2(110, 300), Vector2(300, 300), 90)
	await process_frame
	await process_frame
	if workstation.fold_model.maximum_severity() != 2 or not workstation.paper_sleeve_button.disabled or workstation.tray_button.disabled:
		push_error("P0.5 severe fold rescue smoke-check FAIL")
		quit(1)
		return
	var torn_path := capture_directory.path_join("p0_5_torn.png")
	if root.get_texture().get_image().save_png(torn_path) != OK:
		push_error("Failed to save P0.5 torn capture")
		quit(1)
		return

	workstation.tray_button.pressed.emit()
	await create_timer(0.32).timeout
	var tray_path := capture_directory.path_join("p0_5_tray.png")
	if root.get_texture().get_image().save_png(tray_path) != OK:
		push_error("Failed to save P0.5 tray capture")
		quit(1)
		return

	var frame_msec := PackedFloat32Array()
	var previous_frame_usec := Time.get_ticks_usec()
	for frame in 120:
		await process_frame
		var now_usec := Time.get_ticks_usec()
		frame_msec.append(float(now_usec - previous_frame_usec) / 1000.0)
		previous_frame_usec = now_usec
	frame_msec.sort()
	var p95 := frame_msec[mini(floori(float(frame_msec.size()) * 0.95), frame_msec.size() - 1)]
	if p95 > 25.0:
		push_error("P0.5 rendered fold workload missed 60 FPS target: p95 %.2f ms" % p95)
		quit(1)
		return
	print("Mobile P0.5 fold-render smoke-check PASS (180 drag frames %.3f ms/frame CPU, render p95 %.2f ms)" % [float(drag_usec) / 1000.0 / 180.0, p95])
	print("Validation captures: %s, %s, %s, %s" % [motion_path, folded_path, torn_path, tray_path])
	main.queue_free()
	await process_frame
	await process_frame
	quit(0)


func _fill_uniform_pancake(model: PancakeModel) -> void:
	var center := Vector2(model.grid_size - 1, model.grid_size - 1) * 0.5
	for index in model.cell_count:
		model.coverage[index] = 0.0
		model.thickness[index] = 0.0
		model.wetness[index] = 0.0
		model.doneness[index] = 0.0
		model.damage[index] = 0.0
		model.sauce_concentration[index] = 0.0
	for y in model.grid_size:
		for x in model.grid_size:
			if not model.is_inside_pan(Vector2(x, y), 0.86):
				continue
			var index := y * model.grid_size + x
			model.coverage[index] = 1.0
			model.thickness[index] = 0.55
			model.wetness[index] = 0.20
			model.doneness[index] = 0.55
			model.sauce_concentration[index] = 0.35
	model.revision += 1
	model.changed.emit()


func _set_hole(model: PancakeModel, cell: Vector2i) -> void:
	var index := model.index_of(cell)
	model.coverage[index] = 0.0
	model.thickness[index] = 0.0
	model.damage[index] = 1.0
	model.revision += 1
	model.changed.emit()


func _sculpt_irregular_left_edge(model: PancakeModel) -> void:
	# Deterministic hand-spread wobble for the visual artifact: the lifted flap
	# must retain this missing upper edge instead of becoming an ideal half-disc.
	for x in range(22, 34):
		var distance_from_center := absf(float(x) - 27.5) / 5.5
		var trim_cells := 4 + roundi((1.0 - distance_from_center) * 6.0)
		var removed := 0
		for y in model.grid_size:
			var index := y * model.grid_size + x
			if model.coverage[index] <= 0.0:
				continue
			model.coverage[index] = 0.0
			model.thickness[index] = 0.0
			model.wetness[index] = 0.0
			removed += 1
			if removed >= trim_cells:
				break
	model.revision += 1
	model.changed.emit()


func _drag_surface(workstation: Workstation, surface: PancakeHeatmap, start: Vector2, finish: Vector2, frames: int) -> void:
	_press_surface(surface, start)
	_move_surface(workstation, surface, start, finish, frames)
	_release_surface(surface, finish)


func _press_surface(surface: PancakeHeatmap, position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = position
	surface._gui_input(press)


func _move_surface(workstation: Workstation, surface: PancakeHeatmap, start: Vector2, finish: Vector2, frames: int) -> void:
	for frame in range(1, frames + 1):
		var motion := InputEventMouseMotion.new()
		motion.position = start.lerp(finish, float(frame) / float(frames))
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		surface._gui_input(motion)
		workstation._process(1.0 / 120.0)


func _release_surface(surface: PancakeHeatmap, position: Vector2) -> void:
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = position
	surface._gui_input(release)
