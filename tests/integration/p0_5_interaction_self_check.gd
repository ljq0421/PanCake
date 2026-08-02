extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const FOLD_MODEL_SCRIPT := preload("res://scripts/gameplay/pancake_fold_model.gd")

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
	_fill_uniform_pancake(workstation.pancake_model)

	_check(workstation.fold_button != null and workstation.fold_overlay != null, "workstation scene owns stable fold controls and overlay")
	_check(workstation.paper_sleeve_button != null and workstation.tray_button != null, "workstation scene owns both rescue choices")
	workstation.fold_button.pressed.emit()
	_check(workstation.tool_controller.current_tool == ToolController.Tool.FOLD, "fold button selects the continuous fold tool")
	_check(bool(workstation.fold_overlay.guides_visible), "fold tool exposes visible fold lines and edge handles")

	_press_surface(surface, Vector2(110, 300))
	_move_surface(surface, Vector2(180, 300))
	workstation._process(1.0 / 60.0)
	_check(float(workstation.fold_model.drag_progress) > 0.0 and workstation.fold_model.completed_fold_count() == 0, "mouse movement deforms the flap before release")
	_move_surface(surface, Vector2(300, 300))
	workstation._process(1.0 / 60.0)
	_release_surface(surface, Vector2(300, 300))
	_check(workstation.fold_model.is_region_folded(FOLD_MODEL_SCRIPT.REGION_LEFT), "dragging the left edge over its line commits the left fold")
	_check(workstation.scraper_button.disabled and workstation.sauce_brush_button.disabled, "starting a fold locks earlier preparation tools")

	_press_surface(surface, Vector2(490, 300))
	_move_surface(surface, Vector2(300, 300))
	workstation._process(1.0 / 60.0)
	_release_surface(surface, Vector2(300, 300))
	_check(workstation.fold_model.is_region_folded(FOLD_MODEL_SCRIPT.REGION_RIGHT), "dragging the right edge over its line commits the right fold")
	_check(not workstation.paper_sleeve_button.disabled and not workstation.tray_button.disabled, "completed non-severe folds expose both safe completion choices")
	workstation.paper_sleeve_button.pressed.emit()
	_check(workstation.fold_model.package_result == FOLD_MODEL_SCRIPT.PACKAGE_SLEEVE, "paper sleeve completes the real workstation path")

	workstation.reset_pancake()
	_fill_uniform_pancake(workstation.pancake_model)
	_set_hole(workstation.pancake_model, Vector2i(25, 64))
	workstation.fold_button.pressed.emit()
	_drag_surface(workstation, surface, Vector2(110, 300), Vector2(300, 300))
	_check(workstation.fold_model.maximum_severity() == 2, "a hole in the dragged region creates a severe workstation fold failure")
	_check(workstation.paper_sleeve_button.disabled and not workstation.tray_button.disabled, "severe failure disables sleeve but immediately enables tray")
	workstation.tray_button.pressed.emit()
	_check(workstation.fold_model.package_result == FOLD_MODEL_SCRIPT.PACKAGE_TRAY, "tray rescues a severe failure without a dead end")
	workstation.reset_pancake()
	_check(workstation.fold_model.completed_fold_count() == 0 and workstation.tool_controller.current_tool == ToolController.Tool.NONE, "R/reset clears folding, packaging, pointer, and tool state")

	main.queue_free()
	await process_frame
	await process_frame
	_finish()


func _fill_uniform_pancake(model: PancakeModel) -> void:
	var center := Vector2(model.grid_size - 1, model.grid_size - 1) * 0.5
	for y in model.grid_size:
		for x in model.grid_size:
			if not model.is_inside_pan(Vector2(x, y), 0.86):
				continue
			var index := y * model.grid_size + x
			model.coverage[index] = 1.0
			model.thickness[index] = 0.55
			model.wetness[index] = 0.25
			model.doneness[index] = 0.55
	model.revision += 1
	model.changed.emit()


func _set_hole(model: PancakeModel, cell: Vector2i) -> void:
	var index := model.index_of(cell)
	model.coverage[index] = 0.0
	model.thickness[index] = 0.0
	model.damage[index] = 1.0
	model.revision += 1
	model.changed.emit()


func _drag_surface(workstation: Workstation, surface: PancakeHeatmap, start: Vector2, finish: Vector2) -> void:
	_press_surface(surface, start)
	_move_surface(surface, finish)
	workstation._process(1.0 / 60.0)
	_release_surface(surface, finish)


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


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("P0.5 interaction self-check PASS")
		quit(0)
	else:
		print("P0.5 interaction self-check FAIL (%d)" % _failures.size())
		quit(1)
