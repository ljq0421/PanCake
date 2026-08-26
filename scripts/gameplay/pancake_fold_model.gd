class_name PancakeFoldModel
extends RefCounted

signal changed

const REGION_NONE: StringName = &"none"
const REGION_LEFT: StringName = &"left"
const REGION_RIGHT: StringName = &"right"

const OUTCOME_NONE: StringName = &"none"
const OUTCOME_INTACT: StringName = &"intact"
const OUTCOME_THICK: StringName = &"thick_bulge"
const OUTCOME_BRITTLE: StringName = &"brittle_crack"
const OUTCOME_TORN: StringName = &"torn"

const PACKAGE_NONE: StringName = &"none"
const PACKAGE_BAG: StringName = &"paper_bag"

var pancake_model: PancakeModel
var ingredient_model: IngredientModel
var active_region: StringName = REGION_NONE
var drag_progress := 0.0
var crossed_fold_line := false
var package_result: StringName = PACKAGE_NONE

var _drag_start := Vector2.ZERO
var _fold_results: Dictionary = {}


func _init(model: PancakeModel = null, ingredients: IngredientModel = null) -> void:
	pancake_model = model
	ingredient_model = ingredients
	reset()


func set_model(model: PancakeModel) -> void:
	pancake_model = model
	reset()


func set_ingredient_model(value: IngredientModel) -> void:
	ingredient_model = value
	changed.emit()


func reset() -> void:
	active_region = REGION_NONE
	drag_progress = 0.0
	crossed_fold_line = false
	package_result = PACKAGE_NONE
	_drag_start = Vector2.ZERO
	_fold_results = {
		REGION_LEFT: _empty_result(),
		REGION_RIGHT: _empty_result(),
	}
	changed.emit()


func snapshot() -> Dictionary:
	return {
		"version": 1,
		"active_region": active_region,
		"drag_progress": drag_progress,
		"crossed_fold_line": crossed_fold_line,
		"package_result": package_result,
		"drag_start": [_drag_start.x, _drag_start.y],
		"fold_results": _fold_results.duplicate(true),
	}


func load_snapshot(value: Dictionary) -> Dictionary:
	active_region = StringName(value.get("active_region", REGION_NONE))
	if active_region not in [REGION_NONE, REGION_LEFT, REGION_RIGHT]:
		active_region = REGION_NONE
	drag_progress = clampf(float(value.get("drag_progress", 0.0)), 0.0, 1.0)
	crossed_fold_line = bool(value.get("crossed_fold_line", false))
	package_result = StringName(value.get("package_result", PACKAGE_NONE))
	# Normalize removed rescue-package values from older saves to the single
	# supported paper-bag result.
	if package_result in [&"paper_sleeve", &"tray"]:
		package_result = PACKAGE_BAG
	elif package_result not in [PACKAGE_NONE, PACKAGE_BAG]:
		package_result = PACKAGE_NONE
	var drag_values := Array(value.get("drag_start", []))
	_drag_start = Vector2(float(drag_values[0]), float(drag_values[1])) if drag_values.size() == 2 else Vector2.ZERO
	_fold_results = Dictionary(value.get("fold_results", {})).duplicate(true)
	for region in [REGION_LEFT, REGION_RIGHT]:
		if not _fold_results.has(region) and not _fold_results.has(str(region)):
			_fold_results[region] = _empty_result()
	changed.emit()
	return {"success": true}


func begin_drag(grid_position: Vector2) -> bool:
	if pancake_model == null or package_result != PACKAGE_NONE:
		return false
	var ratio := grid_position.x / maxf(float(pancake_model.grid_size - 1), 1.0)
	var candidate := REGION_NONE
	if ratio <= pancake_model.parameters.fold_grab_edge_ratio:
		candidate = REGION_LEFT
	elif ratio >= 1.0 - pancake_model.parameters.fold_grab_edge_ratio:
		candidate = REGION_RIGHT
	if candidate == REGION_NONE or is_region_folded(candidate) or not _has_covered_near(grid_position):
		return false
	active_region = candidate
	_drag_start = grid_position
	drag_progress = 0.0
	crossed_fold_line = false
	changed.emit()
	return true


func update_drag(grid_position: Vector2) -> void:
	if active_region == REGION_NONE or pancake_model == null:
		return
	var line_x := _fold_line_x(active_region)
	var next_progress := drag_progress
	var next_crossed_fold_line := crossed_fold_line
	if active_region == REGION_LEFT:
		var destination_x := 2.0 * line_x - _drag_start.x
		next_progress = clampf(inverse_lerp(_drag_start.x, maxf(destination_x, line_x + 1.0), grid_position.x), 0.0, 1.0)
		next_crossed_fold_line = grid_position.x >= line_x
	else:
		var destination_x := 2.0 * line_x - _drag_start.x
		next_progress = clampf(inverse_lerp(_drag_start.x, minf(destination_x, line_x - 1.0), grid_position.x), 0.0, 1.0)
		next_crossed_fold_line = grid_position.x <= line_x
	if is_equal_approx(next_progress, drag_progress) and next_crossed_fold_line == crossed_fold_line:
		return
	drag_progress = next_progress
	crossed_fold_line = next_crossed_fold_line
	changed.emit()


func release_drag(grid_position: Vector2) -> Dictionary:
	if active_region == REGION_NONE:
		return {"committed": false, "reason": "没有抓住可折叠边缘"}
	update_drag(grid_position)
	var region := active_region
	if not crossed_fold_line:
		cancel_drag()
		return {"committed": false, "reason": "需要拖过折线后再松开"}
	var result := _evaluate_region(region)
	result["folded"] = true
	_fold_results[region] = result
	active_region = REGION_NONE
	drag_progress = 0.0
	crossed_fold_line = false
	changed.emit()
	return result.merged({"committed": true, "region": region})


func cancel_drag() -> void:
	active_region = REGION_NONE
	drag_progress = 0.0
	crossed_fold_line = false
	changed.emit()


func is_region_folded(region: StringName) -> bool:
	return bool((_fold_results.get(region, {}) as Dictionary).get("folded", false))


func get_region_result(region: StringName) -> Dictionary:
	return (_fold_results.get(region, _empty_result()) as Dictionary).duplicate(true)


func completed_fold_count() -> int:
	return int(is_region_folded(REGION_LEFT)) + int(is_region_folded(REGION_RIGHT))


func maximum_severity() -> int:
	var severity := 0
	for region in [REGION_LEFT, REGION_RIGHT]:
		severity = maxi(severity, int((_fold_results[region] as Dictionary).get("severity", 0)))
	return severity


func can_use_bag() -> bool:
	return package_result == PACKAGE_NONE and completed_fold_count() == 2


func package_with(method: StringName) -> Dictionary:
	if method == PACKAGE_BAG and can_use_bag():
		package_result = PACKAGE_BAG
		changed.emit()
		return {"success": true, "method": method, "structure_penalty": 0.0, "portability_penalty": 0.0}
	return {"success": false, "method": method, "reason": "完成两侧折叠后会自动装入纸袋"}


func result_label(result: Dictionary) -> String:
	match result.get("outcome", OUTCOME_NONE) as StringName:
		OUTCOME_INTACT:
			return "折叠完整"
		OUTCOME_THICK:
			return "局部过厚，折痕鼓起"
		OUTCOME_BRITTLE:
			return "火候过脆，折线开裂"
		OUTCOME_TORN:
			return "薄区或破洞沿折线撕裂"
		_:
			return "尚未折叠"


func _evaluate_region(region: StringName) -> Dictionary:
	var line_x := floori(_fold_line_x(region))
	var covered_cells := 0
	var thickness_total := 0.0
	var thick_cells := 0
	var thin_cells := 0
	var brittle_cells := 0
	var damaged_cells := 0
	var hole_cells := 0
	for y in pancake_model.grid_size:
		for x in pancake_model.grid_size:
			if (region == REGION_LEFT and x > line_x) or (region == REGION_RIGHT and x < line_x):
				continue
			var index := y * pancake_model.grid_size + x
			if pancake_model.coverage[index] <= 0.0 and pancake_model.damage[index] < pancake_model.parameters.hole_damage_threshold:
				continue
			covered_cells += 1
			var cell_thickness := pancake_model.thickness[index]
			var cell_damage := pancake_model.damage[index]
			thickness_total += cell_thickness
			if cell_thickness >= pancake_model.parameters.fold_thick_threshold:
				thick_cells += 1
			if cell_thickness <= pancake_model.parameters.fold_thin_threshold:
				thin_cells += 1
			if pancake_model.doneness[index] >= pancake_model.parameters.fold_brittle_doneness:
				brittle_cells += 1
			if cell_damage >= pancake_model.parameters.fold_damage_threshold:
				damaged_cells += 1
			if cell_damage >= pancake_model.parameters.hole_damage_threshold:
				hole_cells += 1
	var divisor := maxf(float(covered_cells), 1.0)
	var metrics := {
		"covered_cells": covered_cells,
		"mean_thickness": thickness_total / divisor,
		"thick_ratio": float(thick_cells) / divisor,
		"thin_ratio": float(thin_cells) / divisor,
		"brittle_ratio": float(brittle_cells) / divisor,
		"damage_ratio": float(damaged_cells) / divisor,
		"hole_cells": hole_cells,
	}
	var ingredient_metrics := {"count": 0, "structural_load": 0.0, "wetness": 0.0}
	if ingredient_model != null:
		ingredient_metrics = ingredient_model.placement_metrics_for_region(region, float(line_x))
	metrics["ingredient_count"] = int(ingredient_metrics.count)
	metrics["ingredient_load"] = float(ingredient_metrics.structural_load)
	metrics["ingredient_wetness"] = float(ingredient_metrics.wetness)
	var outcome := OUTCOME_INTACT
	var severity := 0
	if hole_cells > 0 or float(metrics.damage_ratio) >= pancake_model.parameters.fold_severe_ratio or float(metrics.thin_ratio) >= 0.35:
		outcome = OUTCOME_TORN
		severity = 2
	elif float(metrics.brittle_ratio) >= pancake_model.parameters.fold_failure_ratio:
		outcome = OUTCOME_BRITTLE
		severity = 1
	elif float(metrics.thick_ratio) >= pancake_model.parameters.fold_failure_ratio or float(metrics.ingredient_load) >= pancake_model.parameters.fold_ingredient_load_threshold:
		outcome = OUTCOME_THICK
		severity = 1
	return {"folded": true, "outcome": outcome, "severity": severity, "metrics": metrics}


func _has_covered_near(grid_position: Vector2) -> bool:
	var radius := maxi(roundi(float(pancake_model.grid_size) * 0.07), 2)
	var center := Vector2i(roundi(grid_position.x), roundi(grid_position.y))
	for y in range(maxi(center.y - radius, 0), mini(center.y + radius, pancake_model.grid_size - 1) + 1):
		for x in range(maxi(center.x - radius, 0), mini(center.x + radius, pancake_model.grid_size - 1) + 1):
			if pancake_model.coverage[y * pancake_model.grid_size + x] > 0.0:
				return true
	return false


func _fold_line_x(region: StringName) -> float:
	var ratio := pancake_model.parameters.fold_left_line_ratio if region == REGION_LEFT else pancake_model.parameters.fold_right_line_ratio
	return ratio * float(pancake_model.grid_size - 1)


func _empty_result() -> Dictionary:
	return {"folded": false, "outcome": OUTCOME_NONE, "severity": 0, "metrics": {}}
