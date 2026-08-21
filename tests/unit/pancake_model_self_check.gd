extends SceneTree

var _failures := PackedStringArray()


func _initialize() -> void:
	_run()


func _run() -> void:
	_test_field_allocation_and_reset()
	_test_deterministic_debug_input()
	_test_bounds_and_finite_values()
	_test_per_side_cooking_exposure()
	_test_snapshot_is_detached()
	_test_summary_contract()
	_finish()


func _test_field_allocation_and_reset() -> void:
	var model := PancakeModel.new(32)
	_check(model.cell_count == 1024, "32x32 model allocates 1024 cells")
	_check(model.coverage.size() == 1024, "coverage field is allocated")
	model.apply_debug_stamp(Vector2i(16, 16), 5.0, 0.5, 0.25)
	model.reset()
	for field_name in PancakeModel.FIELD_NAMES:
		_check(is_zero_approx(model.get_field_value(field_name, Vector2i(16, 16))), "%s resets to zero" % field_name)


func _test_deterministic_debug_input() -> void:
	var first := PancakeModel.new(48)
	var second := PancakeModel.new(48)
	var path := [Vector2i(8, 8), Vector2i(14, 12), Vector2i(22, 20), Vector2i(30, 30)]
	for cell in path:
		first.apply_debug_stamp(cell, 4.5, 0.22)
		second.apply_debug_stamp(cell, 4.5, 0.22)
	first.apply_debug_stamp(Vector2i(20, 20), 3.0, 0.0, 0.35)
	second.apply_debug_stamp(Vector2i(20, 20), 3.0, 0.0, 0.35)
	var a := first.snapshot()
	var b := second.snapshot()
	_check(a.coverage == b.coverage, "same diagnostic input produces identical coverage")
	_check(a.thickness == b.thickness, "same diagnostic input produces identical thickness")
	_check(a.damage == b.damage, "same diagnostic input produces identical damage")


func _test_bounds_and_finite_values() -> void:
	var model := PancakeModel.new(16)
	model.apply_debug_stamp(Vector2i(-4, -4), 10.0, 0.4)
	model.apply_debug_stamp(Vector2i(20, 20), 10.0, 0.4, 0.2)
	_check(model.index_of(Vector2i(-1, 0)) == -1, "negative grid coordinate is rejected")
	_check(model.index_of(Vector2i(16, 0)) == -1, "upper grid coordinate is rejected")
	_check(model.validate().is_empty(), "clipped writes leave all fields finite and valid")


func _test_per_side_cooking_exposure() -> void:
	var model := PancakeModel.new(16)
	var center := Vector2i(8, 8)
	var center_index := model.index_of(center)
	model.apply_debug_stamp(center, 3.0, 0.20)
	model.advance_cooking(7.9, 0.5)
	_check(is_equal_approx(model.cooking_exposure_seconds[center_index], 7.9), "front-side exposure preserves uncapped seconds before the eight-second char gate")
	_check(is_zero_approx(model.back_cooking_exposure_seconds[center_index]), "front-side cooking does not advance second-side exposure")
	model.flip(false)
	model.advance_cooking(2.0, 0.5)
	_check(is_equal_approx(model.cooking_exposure_seconds[center_index], 7.9) and is_equal_approx(model.back_cooking_exposure_seconds[center_index], 2.0), "each side records independent cooking exposure")
	var restored := PancakeModel.new(16)
	var loaded := restored.load_snapshot(model.snapshot())
	_check(bool(loaded.success) and is_equal_approx(restored.back_cooking_exposure_seconds[center_index], 2.0), "cooking exposure survives a snapshot round trip")


func _test_snapshot_is_detached() -> void:
	var model := PancakeModel.new(8)
	model.apply_debug_stamp(Vector2i(4, 4), 2.0, 0.5)
	var copy: Dictionary = model.snapshot()
	var copied_thickness: PackedFloat32Array = copy.thickness
	copied_thickness[model.index_of(Vector2i(4, 4))] = 99.0
	_check(model.get_field_value(PancakeModel.FIELD_THICKNESS, Vector2i(4, 4)) < 4.1, "snapshot arrays do not mutate live model")


func _test_summary_contract() -> void:
	var model := PancakeModel.new(16)
	model.apply_debug_stamp(Vector2i(8, 8), 4.0, 0.5)
	var summary := model.calculate_summary()
	_check(summary.has("coverage_ratio"), "summary exposes coverage for future scorer")
	_check(summary.has("mean_thickness"), "summary exposes thickness for future scorer")
	_check(float(summary.coverage_ratio) > 0.0, "summary reads live grid data")


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("PancakeModel self-check PASS")
		quit(0)
	else:
		print("PancakeModel self-check FAIL (%d)" % _failures.size())
		quit(1)
