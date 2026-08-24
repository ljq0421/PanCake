extends SceneTree

const GRIDDLE_SCENE := preload("res://scenes/gameplay/compact_griddle_unit.tscn")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var unit := GRIDDLE_SCENE.instantiate() as CompactGriddleUnit
	unit.position = Vector2(137.0, 83.0)
	unit.scale = Vector2(0.76, 0.76)
	root.add_child(unit)
	await process_frame
	var expected_initial_visual_state := not OS.get_cmdline_user_args().has(CompactGriddleUnit.DISABLE_SPREADER_VISUAL_ARGUMENT)
	_check(unit.spreader_visual_enabled == expected_initial_visual_state, "command-line flag selects the no-spreader-visual A/B mode")
	unit.set_spreader_visual_enabled(true)

	unit.state = CompactGriddleUnit.State.BATTER
	unit.pancake_surface.visible = true
	unit._surface_action = CompactGriddleUnit.SURFACE_ACTION_SPREAD_BATTER
	unit.call("_refresh_surface_cursor")
	_check(unit.pancake_surface.cursor_visual_enabled, "active hand tools enable their on-pancake cursor cue")
	unit.pancake_surface.pointer_pressed = true
	unit.call("_update_surface_tool_artwork", unit.pancake_surface.size * 0.5, 0.0)

	var target_local := unit.pancake_surface.size * Vector2(0.71, 0.42)
	var target_viewport: Vector2 = unit.pancake_surface.get_global_transform_with_canvas() * target_local
	var motion := InputEventMouseMotion.new()
	motion.position = target_viewport
	motion.global_position = target_viewport
	unit.pancake_surface._input(motion)

	_check(unit.pancake_surface.pointer_local_position.is_equal_approx(target_local), "raw viewport motion is converted into the exact pancake-surface coordinate")
	unit.call("_update_surface_tool_artwork", unit.pancake_surface.pointer_local_position, 1.0 / 60.0)
	_check(not unit.spreader_artwork.visible, "normal spread interaction no longer draws a software Sprite2D spreader")
	_check(unit._hardware_spreader_cursor_active, "normal spread interaction activates the hardware spreader cursor")
	_check(not unit.pancake_surface.spreader_cursor_visual_enabled, "hardware cursor mode does not also draw the custom canvas cursor ring")
	var raw_spread_samples := PackedVector2Array([Vector2.ONE, Vector2.ONE * 2.0, Vector2.ONE * 3.0, Vector2.ONE * 4.0])
	var limited_spread_samples: PackedVector2Array = unit.call("_limit_spread_samples", raw_spread_samples)
	_check(limited_spread_samples.size() == 1, "one frame never replays an unbounded backlog of spread simulation samples")
	_check(limited_spread_samples[0].is_equal_approx(raw_spread_samples[-1]), "spread simulation keeps the newest pointer sample when coalescing a fast move")
	unit.set_spreader_visual_enabled(false)
	unit.call("_update_surface_tool_artwork", target_local, 1.0 / 60.0)
	_check(not unit.spreader_artwork.visible, "no-visual test mode hides the spreader artwork")
	_check(not unit.pancake_surface.spreader_cursor_visual_enabled, "no-visual test mode hides the custom spreader cursor ring")
	_check(not unit._hardware_spreader_cursor_active, "no-visual test mode restores the normal operating-system cursor")
	unit.pancake_model.reset()
	unit.pancake_model.add_batter(Vector2.ONE * 31.5, 4.0, 14.0)
	var revision_before_hidden_spread := unit.pancake_model.revision
	var hidden_spread_changed := bool(unit.call("_apply_radial_batter_sweep", Vector2(48.0, 32.0), Vector2.RIGHT, 70.0))
	_check(hidden_spread_changed and unit.pancake_model.revision > revision_before_hidden_spread, "no-visual test mode keeps the spread simulation functional")
	_test_fold_pointer_precision(unit)
	_test_dropped_ingredient_orientation(unit)
	_test_small_topping_visual_scale()

	unit.call("_reset_surface_action")
	_check(not unit.pancake_surface.cursor_visual_enabled, "idle and ingredient-drag states do not leave a stale canvas cursor ring")
	unit.pancake_surface.pointer_pressed = false
	unit.queue_free()
	await process_frame
	_finish()


func _test_fold_pointer_precision(unit: CompactGriddleUnit) -> void:
	var cell_width := unit.pancake_surface.size.x / float(unit.pancake_model.grid_size)
	var first_local := Vector2(cell_width * 8.10, unit.pancake_surface.size.y * 0.5)
	var second_local := Vector2(cell_width * 8.20, unit.pancake_surface.size.y * 0.5)
	var first_grid: Vector2 = unit.call("_fold_grid_position", first_local)
	var second_grid: Vector2 = unit.call("_fold_grid_position", second_local)
	_check(
		floori(first_grid.x) == floori(second_grid.x) and second_grid.x > first_grid.x,
		"fold input preserves pointer movement within one simulation-grid cell",
	)


func _test_dropped_ingredient_orientation(unit: CompactGriddleUnit) -> void:
	unit.reset_unit()
	unit.begin_order({})
	unit.state = CompactGriddleUnit.State.FIRST_SIDE
	# Reproduce the old failure: any previously applied ingredient made the next
	# manually dropped topping rotate by 0.35 radians when it landed.
	unit.applied_ingredient_ids.append("stock.pancake.egg")
	var center := unit.pancake_surface.size * 0.5
	var validation := Dictionary(unit.validate_ingredient_drop({
		"source_kind": &"pancake_shared_ingredient",
		"stock_id": &"stock.pancake.baocui",
	}, center))
	var result := Dictionary(unit.place_validated_ingredient(validation))
	var placement := Dictionary(unit.ingredient_model.placements.back()) if not unit.ingredient_model.placements.is_empty() else {}
	_check(bool(result.get("success", false)), "a valid manually dragged topping still lands on the pancake")
	_check(is_zero_approx(float(placement.get("rotation", INF))), "a manually dragged topping keeps the drag preview orientation after release")


func _test_small_topping_visual_scale() -> void:
	var expected_scales := {
		IngredientModel.BAOCUI: 0.16,
		IngredientModel.HAM_SAUSAGE: 0.32,
		IngredientModel.SCALLION: 0.56,
		IngredientModel.MEAT_FLOSS: 0.36,
		IngredientModel.PORK_TENDERLOIN: 0.104,
		IngredientModel.CORIANDER: 0.56,
		IngredientModel.PRESERVED_MUSTARD: 0.096,
	}
	for ingredient_type_variant in expected_scales:
		var ingredient_type := StringName(ingredient_type_variant)
		var expected_scale := float(expected_scales[ingredient_type_variant])
		_check(
			is_equal_approx(IngredientLayer.visual_scale_for(ingredient_type), expected_scale),
			"%s visual scale is reduced to 80 percent" % ingredient_type,
		)
	_check(is_equal_approx(IngredientLayer.visual_scale_for(IngredientModel.EGG), 0.14), "egg visual size is not changed by the small-topping scale")
	_check(is_equal_approx(IngredientLayer.visual_scale_for(IngredientModel.YOUTIAO), 0.78), "youtiao visual size is not changed by the small-topping scale")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("COMPACT_GRIDDLE_POINTER_FOLLOW_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("COMPACT_GRIDDLE_POINTER_FOLLOW_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
