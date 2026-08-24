extends SceneTree

const FOLD_MODEL_SCRIPT := preload("res://scripts/gameplay/pancake_fold_model.gd")
const INGREDIENT_LAYER_SCRIPT := preload("res://scripts/ui/ingredient_layer.gd")
const FOLD_OVERLAY_SCRIPT := preload("res://scripts/ui/pancake_fold_overlay.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	_run()


func _run() -> void:
	_test_drag_must_cross_fold_line()
	_test_fold_profile_reuses_static_geometry()
	_test_fold_occludes_landing_area_fillings()
	_test_right_then_left_uses_the_mirrored_clip()
	_test_material_conditions_create_distinct_results()
	_test_damage_keeps_its_regional_effect()
	_test_rescue_paths_never_dead_end()
	_finish()


func _test_fold_profile_reuses_static_geometry() -> void:
	var model := _uniform_pancake(64, 0.55, 0.55)
	var fold: RefCounted = FOLD_MODEL_SCRIPT.new(model)
	var overlay: PancakeFoldOverlay = FOLD_OVERLAY_SCRIPT.new()
	overlay.size = Vector2(400.0, 400.0)
	overlay.set_fold_model(fold)
	for progress in [0.20, 0.45, 0.70, 0.95]:
		overlay.left_fold_outer_edge_x(progress)
		overlay.right_fold_outer_edge_x(progress)
	var diagnostics := overlay.get_renderer_diagnostics()
	_check(
		int(diagnostics.geometry_scan_count) == 1
		and int(diagnostics.source_profile_build_count) == 2,
		"moving fold profiles reuse one grid scan and one static contour per side",
	)
	model.revision += 1
	overlay.left_fold_outer_edge_x(0.50)
	diagnostics = overlay.get_renderer_diagnostics()
	_check(
		int(diagnostics.geometry_scan_count) == 2,
		"fold geometry cache invalidates when the pancake model revision changes",
	)
	overlay.free()


func _test_drag_must_cross_fold_line() -> void:
	var model := _uniform_pancake(64, 0.55, 0.55)
	var fold: RefCounted = FOLD_MODEL_SCRIPT.new(model)
	var change_events := []
	fold.changed.connect(func() -> void: change_events.append(true))
	_check(fold.begin_drag(Vector2(8, 32)), "left covered edge can be grabbed")
	var cancelled: Dictionary = fold.release_drag(Vector2(20, 32))
	_check(not bool(cancelled.committed) and fold.completed_fold_count() == 0, "releasing before the fold line does not commit")
	_check(fold.begin_drag(Vector2(8, 32)), "cancelled fold remains retryable")
	fold.update_drag(Vector2(18, 32))
	_check(float(fold.drag_progress) > 0.0 and not fold.is_region_folded(FOLD_MODEL_SCRIPT.REGION_LEFT), "drag updates deformation before release without auto-completing")
	var change_count_after_move := change_events.size()
	fold.update_drag(Vector2(18, 32))
	_check(change_events.size() == change_count_after_move, "an unchanged fold pointer does not request another redraw")
	var committed: Dictionary = fold.release_drag(Vector2(34, 32))
	_check(bool(committed.committed) and committed.outcome == FOLD_MODEL_SCRIPT.OUTCOME_INTACT, "crossing the line and releasing commits an intact fold")


func _test_fold_occludes_landing_area_fillings() -> void:
	var model := _uniform_pancake(64, 0.55, 0.55)
	var ingredients := IngredientModel.new()
	var layer: IngredientLayer = INGREDIENT_LAYER_SCRIPT.new()
	layer.size = Vector2(600.0, 600.0)
	_check(
		bool(ingredients.place(IngredientModel.BAOCUI, Vector2(12, 32), 0.0, model).success)
		and bool(ingredients.place(IngredientModel.SCALLION, Vector2(32, 32), 0.0, model).success),
		"test fillings can be placed on the flap source and its landing area"
	)
	var fold: RefCounted = FOLD_MODEL_SCRIPT.new(model, ingredients)
	layer.set_model(ingredients)
	layer.set_fold_model(fold)
	_fold_left(fold)
	_check(
		layer.visual_alpha_for(IngredientModel.BAOCUI) <= 0.001
		and layer.visual_alpha_for(IngredientModel.SCALLION) <= 0.001,
		"a completed left fold hides fillings from both the lifted flap and its covered landing area"
	)
	layer.free()


func _test_right_then_left_uses_the_mirrored_clip() -> void:
	var model := _uniform_pancake(64, 0.55, 0.55)
	var fold: RefCounted = FOLD_MODEL_SCRIPT.new(model)
	var overlay: PancakeFoldOverlay = FOLD_OVERLAY_SCRIPT.new()
	overlay.size = Vector2(600.0, 600.0)
	root.add_child(overlay)
	overlay.set_fold_model(fold)
	_fold_right(fold)
	_check(
		is_inf(overlay.right_fold_clip_min_x()),
		"a completed right flap remains whole until the moving left flap reaches its tail"
	)
	_check(fold.begin_drag(Vector2(8, 32)), "left edge is available after a completed right fold")
	fold.update_drag(Vector2(18, 32))
	var moving_left_edge := overlay.left_fold_outer_edge_x(float(fold.drag_progress))
	var landed_left_edge := overlay.left_fold_outer_edge_x(1.0)
	_check(
		is_equal_approx(overlay.right_fold_clip_min_x(), moving_left_edge),
		"the moving left flap clips the right tail at its current outer edge"
	)
	_check(
		moving_left_edge < landed_left_edge - 1.0,
		"the mirrored right-tail clip advances progressively as the left flap folds inward"
	)
	overlay.queue_free()


func _test_material_conditions_create_distinct_results() -> void:
	var thick_model := _uniform_pancake(64, 1.8, 0.55)
	var thick_fold: RefCounted = FOLD_MODEL_SCRIPT.new(thick_model)
	var thick_result := _fold_left(thick_fold)
	_check(thick_result.outcome == FOLD_MODEL_SCRIPT.OUTCOME_THICK, "an obviously thick flap produces a bulged fold")

	var brittle_model := _uniform_pancake(64, 0.55, 0.95)
	var brittle_fold: RefCounted = FOLD_MODEL_SCRIPT.new(brittle_model)
	var brittle_result := _fold_left(brittle_fold)
	_check(brittle_result.outcome == FOLD_MODEL_SCRIPT.OUTCOME_BRITTLE, "an overcooked flap produces a brittle crack")

	var torn_model := _uniform_pancake(64, 0.55, 0.55)
	_set_hole(torn_model, Vector2i(12, 32))
	var torn_fold: RefCounted = FOLD_MODEL_SCRIPT.new(torn_model)
	var torn_result := _fold_left(torn_fold)
	_check(torn_result.outcome == FOLD_MODEL_SCRIPT.OUTCOME_TORN and int(torn_result.severity) == 2, "a pre-existing hole produces a severe tear")


func _test_damage_keeps_its_regional_effect() -> void:
	var model := _uniform_pancake(64, 0.55, 0.55)
	_set_hole(model, Vector2i(52, 32))
	var fold: RefCounted = FOLD_MODEL_SCRIPT.new(model)
	var left_result := _fold_left(fold)
	var right_result := _fold_right(fold)
	_check(left_result.outcome == FOLD_MODEL_SCRIPT.OUTCOME_INTACT, "a right-side hole does not incorrectly damage the left fold")
	_check(right_result.outcome == FOLD_MODEL_SCRIPT.OUTCOME_TORN, "the same hole is retained when its right-side region folds")


func _test_rescue_paths_never_dead_end() -> void:
	var minor_model := _uniform_pancake(64, 0.55, 0.95)
	var minor_fold: RefCounted = FOLD_MODEL_SCRIPT.new(minor_model)
	_fold_left(minor_fold)
	_fold_right(minor_fold)
	_check(minor_fold.can_use_sleeve(), "two minor cracked folds can be rescued with a paper sleeve")
	var sleeve: Dictionary = minor_fold.package_with(FOLD_MODEL_SCRIPT.PACKAGE_SLEEVE)
	_check(bool(sleeve.success) and float(sleeve.structure_penalty) > 0.0, "paper sleeve rescue records a permanent structure penalty")

	var severe_model := _uniform_pancake(64, 0.55, 0.55)
	_set_hole(severe_model, Vector2i(12, 32))
	var severe_fold: RefCounted = FOLD_MODEL_SCRIPT.new(severe_model)
	_fold_left(severe_fold)
	_check(not severe_fold.can_use_sleeve() and severe_fold.can_use_tray(), "a severe first-fold tear exposes the tray rescue without requiring another fold")
	var tray: Dictionary = severe_fold.package_with(FOLD_MODEL_SCRIPT.PACKAGE_TRAY)
	_check(bool(tray.success) and float(tray.portability_penalty) >= 0.70, "tray rescue completes with a large portability penalty")
	severe_fold.reset()
	_check(severe_fold.completed_fold_count() == 0 and severe_fold.package_result == FOLD_MODEL_SCRIPT.PACKAGE_NONE, "reset always escapes a completed or failed fold state")


func _uniform_pancake(size: int, cell_thickness: float, cell_doneness: float) -> PancakeModel:
	var model := PancakeModel.new(size)
	var center := Vector2(size - 1, size - 1) * 0.5
	for y in size:
		for x in size:
			if not model.is_inside_pan(Vector2(x, y), 0.86):
				continue
			var index := y * size + x
			model.coverage[index] = 1.0
			model.thickness[index] = cell_thickness
			model.doneness[index] = cell_doneness
	return model


func _set_hole(model: PancakeModel, cell: Vector2i) -> void:
	var index := model.index_of(cell)
	model.coverage[index] = 0.0
	model.thickness[index] = 0.0
	model.damage[index] = 1.0


func _fold_left(fold: RefCounted) -> Dictionary:
	_check(fold.begin_drag(Vector2(8, 32)), "left edge is available for the test fold")
	return fold.release_drag(Vector2(34, 32))


func _fold_right(fold: RefCounted) -> Dictionary:
	_check(fold.begin_drag(Vector2(55, 32)), "right edge is available for the test fold")
	return fold.release_drag(Vector2(30, 32))


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("P0.5 fold self-check PASS")
		quit(0)
	else:
		print("P0.5 fold self-check FAIL (%d)" % _failures.size())
		quit(1)
