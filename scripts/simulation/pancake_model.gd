class_name PancakeModel
extends RefCounted

signal changed

const FIELD_COVERAGE: StringName = &"coverage"
const FIELD_THICKNESS: StringName = &"thickness"
const FIELD_WETNESS: StringName = &"wetness"
const FIELD_DONENESS: StringName = &"doneness"
const FIELD_DAMAGE: StringName = &"damage"
const FIELD_SAUCE_CONCENTRATION: StringName = &"sauce_concentration"
const FIELD_CHILI_SAUCE_CONCENTRATION: StringName = &"chili_sauce_concentration"
const FIELD_EGG_WHITE: StringName = &"egg_white"
const FIELD_EGG_YOLK: StringName = &"egg_yolk"
const FIELD_EGG_DONENESS: StringName = &"egg_doneness"
const FIELD_NAMES: Array[StringName] = [
	FIELD_COVERAGE,
	FIELD_THICKNESS,
	FIELD_WETNESS,
	FIELD_DONENESS,
	FIELD_DAMAGE,
	FIELD_SAUCE_CONCENTRATION,
	FIELD_CHILI_SAUCE_CONCENTRATION,
	FIELD_EGG_WHITE,
	FIELD_EGG_YOLK,
	FIELD_EGG_DONENESS,
]
const SCRAPER_FAN_ANGLES: Array[float] = [-0.55, -0.28, 0.0, 0.0, 0.0, 0.28, 0.55]
const SCRAPER_PUSH_FRACTIONS: Array[float] = [0.78, 0.88, 0.42, 0.70, 1.0, 0.88, 0.78]
const SCRAPER_PUSH_WEIGHTS: Array[float] = [0.10, 0.13, 0.12, 0.17, 0.25, 0.13, 0.10]

enum EggState {
	NONE,
	CRACKED,
	SPREADING,
	SET,
}

var grid_size: int
var cell_count: int
var last_update_usec: int = 0
var revision: int = 0
var parameters: PancakeSimulationParameters

var coverage := PackedFloat32Array()
var thickness := PackedFloat32Array()
var wetness := PackedFloat32Array()
var doneness := PackedFloat32Array()
var back_doneness := PackedFloat32Array()
var damage := PackedFloat32Array()
var scrape_stress := PackedFloat32Array()
var sauce_concentration := PackedFloat32Array()
var chili_sauce_concentration := PackedFloat32Array()
var egg_white := PackedFloat32Array()
var egg_yolk := PackedFloat32Array()
var egg_doneness := PackedFloat32Array()
var egg_state: EggState = EggState.NONE
var yolk_broken := false
var is_flipped := false
var _sauce_footprint_stamp := PackedInt32Array()
var _sauce_stroke_serial := 0
var _sauce_sample_serial := 0
var _sauce_previous_sample_serial := -1
var _sauce_active_stroke_id := 0
var _egg_source_stamp := PackedInt32Array()
var _egg_sample_serial := 0
var _egg_delta_stamp := PackedInt32Array()
var _egg_white_deltas := PackedFloat32Array()
var _egg_yolk_deltas := PackedFloat32Array()
var _egg_cooked_mass_deltas := PackedFloat32Array()
var _egg_delta_serial := 0


func _init(size: int = 256, simulation_parameters: PancakeSimulationParameters = null) -> void:
	grid_size = maxi(size, 1)
	cell_count = grid_size * grid_size
	parameters = simulation_parameters if simulation_parameters != null else PancakeSimulationParameters.new()
	_allocate_fields()
	reset()


func _allocate_fields() -> void:
	coverage.resize(cell_count)
	thickness.resize(cell_count)
	wetness.resize(cell_count)
	doneness.resize(cell_count)
	back_doneness.resize(cell_count)
	damage.resize(cell_count)
	scrape_stress.resize(cell_count)
	sauce_concentration.resize(cell_count)
	chili_sauce_concentration.resize(cell_count)
	egg_white.resize(cell_count)
	egg_yolk.resize(cell_count)
	egg_doneness.resize(cell_count)
	_sauce_footprint_stamp.resize(cell_count)
	_egg_source_stamp.resize(cell_count)
	_egg_delta_stamp.resize(cell_count)
	_egg_white_deltas.resize(cell_count)
	_egg_yolk_deltas.resize(cell_count)
	_egg_cooked_mass_deltas.resize(cell_count)


func reset() -> void:
	var started := Time.get_ticks_usec()
	coverage.fill(0.0)
	thickness.fill(0.0)
	wetness.fill(0.0)
	doneness.fill(0.0)
	back_doneness.fill(0.0)
	damage.fill(0.0)
	scrape_stress.fill(0.0)
	sauce_concentration.fill(0.0)
	chili_sauce_concentration.fill(0.0)
	egg_white.fill(0.0)
	egg_yolk.fill(0.0)
	egg_doneness.fill(0.0)
	egg_state = EggState.NONE
	yolk_broken = false
	is_flipped = false
	_sauce_footprint_stamp.fill(-1)
	_sauce_stroke_serial = 0
	_sauce_sample_serial = 0
	_sauce_previous_sample_serial = -1
	_sauce_active_stroke_id = 0
	_egg_source_stamp.fill(-1)
	_egg_sample_serial = 0
	_egg_delta_stamp.fill(-1)
	_egg_white_deltas.fill(0.0)
	_egg_yolk_deltas.fill(0.0)
	_egg_cooked_mass_deltas.fill(0.0)
	_egg_delta_serial = 0
	last_update_usec = Time.get_ticks_usec() - started
	revision += 1
	changed.emit()


func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size and cell.y < grid_size


func index_of(cell: Vector2i) -> int:
	if not is_in_bounds(cell):
		return -1
	return cell.y * grid_size + cell.x


func get_field_value(field_name: StringName, cell: Vector2i) -> float:
	var index := index_of(cell)
	if index < 0:
		return 0.0
	match field_name:
		FIELD_COVERAGE:
			return coverage[index]
		FIELD_THICKNESS:
			return thickness[index]
		FIELD_WETNESS:
			return wetness[index]
		FIELD_DONENESS:
			return doneness[index]
		FIELD_DAMAGE:
			return damage[index]
		FIELD_SAUCE_CONCENTRATION:
			return sauce_concentration[index]
		FIELD_CHILI_SAUCE_CONCENTRATION:
			return chili_sauce_concentration[index]
		FIELD_EGG_WHITE:
			return egg_white[index]
		FIELD_EGG_YOLK:
			return egg_yolk[index]
		FIELD_EGG_DONENESS:
			return egg_doneness[index]
		_:
			return 0.0


func apply_debug_stamp(center: Vector2i, radius: float, thickness_delta: float, damage_delta: float = 0.0) -> int:
	# Diagnostic injection only. P0.2 pour/spreading physics must not depend on this helper.
	var started := Time.get_ticks_usec()
	var safe_radius := maxf(radius, 0.5)
	var min_x := maxi(floori(center.x - safe_radius), 0)
	var max_x := mini(ceili(center.x + safe_radius), grid_size - 1)
	var min_y := maxi(floori(center.y - safe_radius), 0)
	var max_y := mini(ceili(center.y + safe_radius), grid_size - 1)
	var changed_cells := 0
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var distance := Vector2(x, y).distance_to(Vector2(center))
			if distance > safe_radius:
				continue
			var falloff := 1.0 - distance / safe_radius
			var index := y * grid_size + x
			if not is_zero_approx(thickness_delta):
				thickness[index] = clampf(thickness[index] + thickness_delta * falloff, 0.0, 4.0)
				coverage[index] = 1.0 if thickness[index] > 0.001 else 0.0
				wetness[index] = maxf(wetness[index], clampf(0.55 + falloff * 0.45, 0.0, 1.0))
			if not is_zero_approx(damage_delta):
				damage[index] = clampf(damage[index] + damage_delta * falloff, 0.0, 1.0)
				if damage[index] >= 0.95:
					coverage[index] = 0.0
					thickness[index] = 0.0
			changed_cells += 1
	last_update_usec = Time.get_ticks_usec() - started
	if changed_cells > 0:
		revision += 1
		changed.emit()
	return changed_cells


func add_batter(center: Vector2, amount: float, radius: float = -1.0) -> int:
	var started := Time.get_ticks_usec()
	var safe_radius := radius if radius > 0.0 else parameters.pour_radius
	var min_x := maxi(floori(center.x - safe_radius), 0)
	var max_x := mini(ceili(center.x + safe_radius), grid_size - 1)
	var min_y := maxi(floori(center.y - safe_radius), 0)
	var max_y := mini(ceili(center.y + safe_radius), grid_size - 1)
	var changed_cells := 0
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var cell_position := Vector2(x, y)
			if not is_inside_pan(cell_position):
				continue
			var distance := cell_position.distance_to(center)
			if distance > safe_radius:
				continue
			var normalized_distance := distance / maxf(safe_radius, 0.001)
			var falloff := (1.0 - normalized_distance * normalized_distance)
			falloff *= falloff
			var index := y * grid_size + x
			var addition := maxf(amount, 0.0) * falloff
			if addition <= 0.0:
				continue
			thickness[index] = minf(thickness[index] + addition, parameters.maximum_thickness)
			coverage[index] = 1.0
			wetness[index] = maxf(wetness[index], 0.98)
			changed_cells += 1
	last_update_usec = Time.get_ticks_usec() - started
	_commit_change(changed_cells)
	return changed_cells


func advance_solidification(delta_seconds: float) -> int:
	var started := Time.get_ticks_usec()
	var changed_cells := 0
	var safe_delta := maxf(delta_seconds, 0.0)
	for index in cell_count:
		if coverage[index] <= 0.0 or wetness[index] <= 0.0:
			continue
		var thickness_resistance := clampf(thickness[index], 0.25, 2.0)
		wetness[index] = maxf(wetness[index] - parameters.solidification_rate * safe_delta / thickness_resistance, 0.0)
		changed_cells += 1
	last_update_usec = Time.get_ticks_usec() - started
	_commit_change(changed_cells)
	return changed_cells


func advance_cooking(delta_seconds: float, heat_level: float = 0.65) -> int:
	var started := Time.get_ticks_usec()
	var changed_cells := 0
	var safe_delta := maxf(delta_seconds, 0.0)
	var safe_heat := clampf(heat_level, 0.0, 1.25)
	var target_field := back_doneness if is_flipped else doneness
	var center := Vector2(grid_size - 1, grid_size - 1) * 0.5
	var radii := Vector2(float(grid_size) * 0.5, float(grid_size) * 0.5 * parameters.pan_height_ratio)
	var egg_amount_total := 0.0
	var egg_doneness_total := 0.0
	for index in cell_count:
		if coverage[index] <= 0.0:
			continue
		var position := Vector2(index % grid_size, index / grid_size)
		var normalized_radius := ((position - center) / radii).length()
		var edge_factor := lerpf(1.0, 1.0 + parameters.edge_cooking_boost, smoothstep(0.55, 1.0, normalized_radius))
		var thickness_resistance := clampf(0.45 + thickness[index] * 0.75, 0.45, 2.4)
		var cooking_delta := parameters.cooking_rate * safe_heat * edge_factor * safe_delta / thickness_resistance
		target_field[index] = minf(target_field[index] + cooking_delta, 1.0)
		wetness[index] = maxf(wetness[index] - parameters.solidification_rate * safe_delta / thickness_resistance, 0.0)
		var egg_amount := egg_white[index] + egg_yolk[index]
		if egg_amount >= parameters.egg_coverage_minimum:
			var egg_cooking_delta := parameters.egg_cooking_rate * safe_heat * edge_factor * safe_delta
			egg_doneness[index] = minf(egg_doneness[index] + egg_cooking_delta, 1.0)
			egg_amount_total += egg_amount
			egg_doneness_total += egg_doneness[index] * egg_amount
		changed_cells += 1
	if egg_amount_total > 0.0 and egg_doneness_total / egg_amount_total >= 0.82:
		egg_state = EggState.SET
	last_update_usec = Time.get_ticks_usec() - started
	_commit_change(changed_cells)
	return changed_cells


func can_crack_egg(center: Vector2) -> Dictionary:
	if has_egg():
		return {"success": false, "reason": "鸡蛋已经打入饼面"}
	if not is_inside_pan(center):
		return {"success": false, "reason": "请把鸡蛋打在鏊面内"}
	var cell := Vector2i(roundi(center.x), roundi(center.y))
	var index := index_of(cell)
	if index < 0 or coverage[index] <= 0.0 or damage[index] >= parameters.hole_damage_threshold:
		return {"success": false, "reason": "鸡蛋必须打在完整饼皮上"}
	return {"success": true}


func crack_egg(center: Vector2) -> Dictionary:
	var started := Time.get_ticks_usec()
	var validation := can_crack_egg(center)
	if not bool(validation.success):
		return validation
	var white_radius := parameters.egg_initial_white_radius
	var yolk_radius := parameters.egg_initial_yolk_radius
	var maximum_radius := maxf(white_radius, yolk_radius)
	var min_x := maxi(floori(center.x - maximum_radius), 0)
	var max_x := mini(ceili(center.x + maximum_radius), grid_size - 1)
	var min_y := maxi(floori(center.y - maximum_radius), 0)
	var max_y := mini(ceili(center.y + maximum_radius), grid_size - 1)
	var changed_cells := 0
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var position := Vector2(x, y)
			var index := y * grid_size + x
			if coverage[index] <= 0.0 or damage[index] >= parameters.hole_damage_threshold:
				continue
			var offset := position - center
			# A small deterministic asymmetry keeps the initial puddle from reading as a perfect circle.
			var white_distance := Vector2(offset.x * 0.90, offset.y * 1.08).length()
			if white_distance <= white_radius:
				var normalized_white := white_distance / maxf(white_radius, 0.001)
				var white_falloff := pow(1.0 - normalized_white * normalized_white, 2.0)
				egg_white[index] = minf(
					egg_white[index] + parameters.egg_initial_white_amount * white_falloff,
					parameters.egg_maximum_concentration
				)
				changed_cells += 1
			var yolk_center := center + Vector2(yolk_radius * 0.25, -yolk_radius * 0.12)
			var yolk_distance := position.distance_to(yolk_center)
			if yolk_distance <= yolk_radius:
				var normalized_yolk := yolk_distance / maxf(yolk_radius, 0.001)
				var yolk_falloff := pow(1.0 - normalized_yolk * normalized_yolk, 2.0)
				egg_yolk[index] = minf(
					egg_yolk[index] + parameters.egg_initial_yolk_amount * yolk_falloff,
					parameters.egg_maximum_concentration
				)
	egg_state = EggState.CRACKED
	yolk_broken = false
	last_update_usec = Time.get_ticks_usec() - started
	_commit_change(changed_cells)
	return {"success": true, "changed_cells": changed_cells, "egg_amount": total_egg_amount()}


func has_egg() -> bool:
	return egg_state != EggState.NONE and total_egg_amount() > 0.0


func total_egg_amount() -> float:
	var total := 0.0
	for index in cell_count:
		total += egg_white[index] + egg_yolk[index]
	return total


func apply_egg_spreader_sample(center: Vector2, direction: Vector2, speed_cells_per_second: float, commit_change: bool = true, width_multiplier: float = 1.0) -> Dictionary:
	var started := Time.get_ticks_usec()
	if egg_state == EggState.NONE or is_flipped:
		return {"changed_cells": 0, "moved_mass": 0.0, "yolk_broken": yolk_broken}
	var safe_direction := direction.normalized()
	if safe_direction.is_zero_approx():
		return {"changed_cells": 0, "moved_mass": 0.0, "yolk_broken": yolk_broken}
	var radius := parameters.scraper_width * 0.5 * maxf(width_multiplier, 0.1)
	var bar_half_thickness := parameters.spreader_bar_thickness * 0.5
	var crossbar_direction := safe_direction.orthogonal()
	var speed_factor := clampf(1.08 - maxf(speed_cells_per_second, 0.0) / 260.0, 0.32, 1.0)
	var affected_indices := PackedInt32Array()
	var moved_mass := 0.0
	_egg_sample_serial += 1
	_egg_delta_serial += 1
	var crossbar_steps := ceili(radius)
	var radial_steps := ceili(bar_half_thickness)
	for crossbar_step in range(-crossbar_steps, crossbar_steps + 1):
		# The crossbar is wider than one grid cell. Sampling every other cell through
		# its thickness keeps continuous strokes responsive without changing the
		# visible footprint or the mass-conserving destination fan.
		for radial_step in range(-radial_steps, radial_steps + 1, 2):
			var sample_position := center + crossbar_direction * float(crossbar_step) + safe_direction * float(radial_step)
			var source_cell := Vector2i(roundi(sample_position.x), roundi(sample_position.y))
			if not is_in_bounds(source_cell):
				continue
			var source_index := index_of(source_cell)
			if _egg_source_stamp[source_index] == _egg_sample_serial:
				continue
			_egg_source_stamp[source_index] = _egg_sample_serial
			var source_position := Vector2(source_cell)
			if not is_inside_pan(source_position):
				continue
			if coverage[source_index] <= 0.0 or damage[source_index] >= parameters.hole_damage_threshold:
				continue
			var source_white := egg_white[source_index]
			var source_yolk := egg_yolk[source_index]
			var source_total := source_white + source_yolk
			if source_total < parameters.egg_coverage_minimum:
				continue
			var crossbar_falloff := 1.0 - absf(float(crossbar_step)) / maxf(radius, 0.001)
			var radial_falloff := 1.0 - absf(float(radial_step)) / maxf(bar_half_thickness, 0.001)
			var liquid_factor := maxf(pow(1.0 - clampf(egg_doneness[source_index], 0.0, 1.0), 1.6), 0.08)
			var transfer_factor := parameters.egg_spread_transfer_ratio * crossbar_falloff * radial_falloff * liquid_factor * speed_factor
			var moved_white := source_white * transfer_factor
			# The yolk ruptures under the crossbar and disperses faster than the more fluid white.
			var moved_yolk := source_yolk * minf(transfer_factor * 2.0, 1.0)
			var moved := moved_white + moved_yolk
			if moved <= 0.000001:
				continue
			var moved_cooked_mass := moved * egg_doneness[source_index]
			if _egg_delta_stamp[source_index] != _egg_delta_serial:
				_egg_delta_stamp[source_index] = _egg_delta_serial
				_egg_white_deltas[source_index] = 0.0
				_egg_yolk_deltas[source_index] = 0.0
				_egg_cooked_mass_deltas[source_index] = 0.0
				affected_indices.append(source_index)
			_egg_white_deltas[source_index] -= moved_white
			_egg_yolk_deltas[source_index] -= moved_yolk
			_egg_cooked_mass_deltas[source_index] -= moved_cooked_mass
			if moved_yolk > 0.000001:
				yolk_broken = true
			for band_index in SCRAPER_FAN_ANGLES.size():
				var distance_scale := parameters.egg_spread_push_distance * SCRAPER_PUSH_FRACTIONS[band_index]
				var fan_direction := safe_direction.rotated(SCRAPER_FAN_ANGLES[band_index])
				var target_position := Vector2i(source_position + fan_direction * distance_scale)
				if not is_in_bounds(target_position) or not is_inside_pan(Vector2(target_position)):
					continue
				var target_index := index_of(target_position)
				if coverage[target_index] <= 0.0 or damage[target_index] >= parameters.hole_damage_threshold:
					continue
				var portion := SCRAPER_PUSH_WEIGHTS[band_index]
				if _egg_delta_stamp[target_index] != _egg_delta_serial:
					_egg_delta_stamp[target_index] = _egg_delta_serial
					_egg_white_deltas[target_index] = 0.0
					_egg_yolk_deltas[target_index] = 0.0
					_egg_cooked_mass_deltas[target_index] = 0.0
					affected_indices.append(target_index)
				_egg_white_deltas[target_index] += moved_white * portion
				_egg_yolk_deltas[target_index] += moved_yolk * portion
				_egg_cooked_mass_deltas[target_index] += moved_cooked_mass * portion
			moved_mass += moved
	for index in affected_indices:
		var old_total := egg_white[index] + egg_yolk[index]
		var old_cooked_mass := old_total * egg_doneness[index]
		egg_white[index] = clampf(egg_white[index] + _egg_white_deltas[index], 0.0, parameters.egg_maximum_concentration)
		egg_yolk[index] = clampf(egg_yolk[index] + _egg_yolk_deltas[index], 0.0, parameters.egg_maximum_concentration)
		var new_total := egg_white[index] + egg_yolk[index]
		if new_total <= 0.000001:
			egg_doneness[index] = 0.0
		else:
			var new_cooked_mass := clampf(old_cooked_mass + _egg_cooked_mass_deltas[index], 0.0, new_total)
			egg_doneness[index] = new_cooked_mass / new_total
	if moved_mass > 0.0 and egg_state != EggState.SET:
		egg_state = EggState.SPREADING
	last_update_usec = Time.get_ticks_usec() - started
	if commit_change:
		_commit_change(affected_indices.size())
	return {
		"changed_cells": affected_indices.size(),
		"moved_mass": moved_mass,
		"yolk_broken": yolk_broken,
	}


func apply_egg_spreader_path(samples: PackedVector2Array, speed_cells_per_second: float, width_multiplier: float = 1.0) -> Dictionary:
	var started := Time.get_ticks_usec()
	var changed_cells := 0
	var moved_mass := 0.0
	var center := Vector2(grid_size - 1, grid_size - 1) * 0.5
	for sample in samples:
		var offset := sample - center
		var polar_offset := Vector2(offset.x, offset.y / maxf(parameters.pan_height_ratio, 0.01))
		if polar_offset.length() <= 1.0:
			continue
		var result := apply_egg_spreader_sample(sample, polar_offset.normalized(), speed_cells_per_second, false, width_multiplier)
		changed_cells += int(result.changed_cells)
		moved_mass += float(result.moved_mass)
	if changed_cells > 0:
		_commit_change(changed_cells)
	last_update_usec = Time.get_ticks_usec() - started
	return {
		"changed_cells": changed_cells,
		"moved_mass": moved_mass,
		"yolk_broken": yolk_broken,
	}


func calculate_egg_spread_summary() -> Dictionary:
	var pancake_cells := 0
	var egg_cells := 0
	var concentration_total := 0.0
	var concentration_squared_total := 0.0
	var actual_concentration_total := 0.0
	var excessive_cells := 0
	var doneness_mass_total := 0.0
	var egg_mass_total := 0.0
	var scoring_concentration_cap := maxf(parameters.egg_coverage_minimum * 8.0, 0.04)
	for index in cell_count:
		if coverage[index] <= 0.0 or damage[index] >= parameters.hole_damage_threshold:
			continue
		pancake_cells += 1
		var concentration := egg_white[index] + egg_yolk[index]
		if concentration < parameters.egg_coverage_minimum:
			continue
		egg_cells += 1
		var scoring_concentration := minf(concentration, scoring_concentration_cap)
		concentration_total += scoring_concentration
		concentration_squared_total += scoring_concentration * scoring_concentration
		actual_concentration_total += concentration
		if concentration > scoring_concentration_cap * 2.0:
			excessive_cells += 1
		egg_mass_total += concentration
		doneness_mass_total += concentration * egg_doneness[index]
	var coverage_ratio := float(egg_cells) / maxf(float(pancake_cells), 1.0)
	var mean_scoring_concentration := concentration_total / maxf(float(egg_cells), 1.0)
	var mean_concentration := actual_concentration_total / maxf(float(egg_cells), 1.0)
	var concentration_variance := maxf(
		concentration_squared_total / maxf(float(egg_cells), 1.0) - mean_scoring_concentration * mean_scoring_concentration,
		0.0
	)
	var coefficient_of_variation := sqrt(concentration_variance) / maxf(mean_scoring_concentration, 0.001)
	var excessive_ratio := float(excessive_cells) / maxf(float(egg_cells), 1.0)
	var uniformity := 1.0 - clampf(coefficient_of_variation / maxf(parameters.egg_uniformity_cv_limit, 0.001), 0.0, 1.0)
	uniformity *= 1.0 - excessive_ratio * 0.45
	var coverage_quality := clampf(coverage_ratio / maxf(parameters.egg_target_spread_coverage, 0.001), 0.0, 1.0)
	var yolk_factor := 1.0 if yolk_broken else 0.55
	var score := 100.0 * clampf((coverage_quality * 0.68 + uniformity * 0.32) * yolk_factor, 0.0, 1.0)
	var tags := PackedStringArray()
	if egg_cells <= 0:
		tags.append("没有鸡蛋层")
	elif not yolk_broken:
		tags.append("蛋黄没有摊开")
	if coverage_ratio < parameters.egg_minimum_spread_coverage:
		tags.append("鸡蛋覆盖不足")
	elif excessive_ratio > 0.32:
		tags.append("鸡蛋局部堆积")
	elif uniformity < 0.46:
		tags.append("鸡蛋厚薄不均")
	elif coverage_ratio >= parameters.egg_target_spread_coverage and uniformity >= 0.68:
		tags.append("鸡蛋摊得均匀")
	return {
		"score": score,
		"coverage_ratio": coverage_ratio,
		"uniformity": uniformity,
		"mean_concentration": mean_concentration,
		"excessive_ratio": excessive_ratio,
		"mean_doneness": doneness_mass_total / maxf(egg_mass_total, 0.001),
		"yolk_broken": yolk_broken,
		"tags": tags,
	}


func is_egg_spread_enough() -> bool:
	var summary := calculate_egg_spread_summary()
	return has_egg() and yolk_broken and float(summary.coverage_ratio) >= parameters.egg_minimum_spread_coverage


func flip(complete_back_side_immediately: bool = false) -> void:
	is_flipped = not is_flipped
	if complete_back_side_immediately:
		for index in cell_count:
			if coverage[index] > 0.0:
				back_doneness[index] = maxf(back_doneness[index], doneness[index])
	revision += 1
	changed.emit()


func visible_doneness_at(index: int) -> float:
	if index < 0 or index >= cell_count:
		return 0.0
	return back_doneness[index] if is_flipped else doneness[index]


func mean_side_doneness(back_side: bool) -> float:
	var field := back_doneness if back_side else doneness
	var total := 0.0
	var count := 0
	for index in cell_count:
		if coverage[index] <= 0.0:
			continue
		total += field[index]
		count += 1
	return total / maxf(float(count), 1.0)


func apply_scraper_sample(center: Vector2, direction: Vector2, speed_cells_per_second: float, width_multiplier: float = 1.0) -> Dictionary:
	var started := Time.get_ticks_usec()
	var safe_direction := direction.normalized()
	if safe_direction.is_zero_approx():
		return {"changed_cells": 0, "moved_mass": 0.0, "new_holes": 0, "peak_damage": 0.0}
	var radius := parameters.scraper_width * 0.5 * maxf(width_multiplier, 0.1)
	var bar_half_thickness := parameters.spreader_bar_thickness * 0.5
	var crossbar_direction := safe_direction.orthogonal()
	var min_x := maxi(floori(center.x - radius), 0)
	var max_x := mini(ceili(center.x + radius), grid_size - 1)
	var min_y := maxi(floori(center.y - radius), 0)
	var max_y := mini(ceili(center.y + radius), grid_size - 1)
	var speed_factor := clampf(1.12 - maxf(speed_cells_per_second, 0.0) / 220.0, 0.32, 1.0)
	var deltas: Dictionary = {}
	var moved_mass := 0.0
	var source_indices := PackedInt32Array()
	var source_total := 0.0
	var source_wetness_total := 0.0
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var source_position := Vector2(x, y)
			var source_offset := source_position - center
			if not is_inside_pan(source_position) or absf(source_offset.dot(crossbar_direction)) > radius or absf(source_offset.dot(safe_direction)) > bar_half_thickness:
				continue
			var source_index := y * grid_size + x
			if coverage[source_index] <= 0.0 or thickness[source_index] <= 0.0:
				continue
			source_indices.append(source_index)
			source_total += thickness[source_index]
			source_wetness_total += wetness[source_index]
	if not source_indices.is_empty():
		var source_mean := source_total / float(source_indices.size())
		var mean_wetness := source_wetness_total / float(source_indices.size())
		var flatten_strength := parameters.scraper_flatten_strength * (0.15 + mean_wetness * 0.85) * speed_factor
		for source_index in source_indices:
			deltas[source_index] = (source_mean - thickness[source_index]) * flatten_strength
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var source_position := Vector2(x, y)
			if not is_inside_pan(source_position):
				continue
			var source_offset := source_position - center
			var crossbar_distance := absf(source_offset.dot(crossbar_direction))
			var radial_distance := absf(source_offset.dot(safe_direction))
			if crossbar_distance > radius or radial_distance > bar_half_thickness:
				continue
			var source_index := y * grid_size + x
			if coverage[source_index] <= 0.0 or thickness[source_index] <= 0.0:
				continue
			var crossbar_falloff := 1.0 - crossbar_distance / maxf(radius, 0.001)
			var radial_falloff := 1.0 - radial_distance / maxf(bar_half_thickness, 0.001)
			var falloff := crossbar_falloff * radial_falloff
			var liquid_factor := clampf(wetness[source_index], 0.0, 1.0)
			var effectiveness := (0.15 + liquid_factor * 0.85) * speed_factor
			var moved := thickness[source_index] * parameters.scraper_transfer_ratio * falloff * effectiveness
			if moved <= 0.000001:
				continue
			if parameters.scraper_push_distance <= 0.0:
				continue
			deltas[source_index] = float(deltas.get(source_index, 0.0)) - moved
			for band_index in SCRAPER_FAN_ANGLES.size():
				var distance_scale := parameters.scraper_push_distance * SCRAPER_PUSH_FRACTIONS[band_index]
				var fan_direction := safe_direction.rotated(SCRAPER_FAN_ANGLES[band_index])
				var target_position := Vector2i(Vector2(x, y) + fan_direction * distance_scale)
				var portion := moved * SCRAPER_PUSH_WEIGHTS[band_index]
				if not is_in_bounds(target_position) or not is_inside_pan(Vector2(target_position)):
					# Portions pushed over the pan edge are deliberately lost as flying edges.
					continue
				var target_index := index_of(target_position)
				deltas[target_index] = float(deltas.get(target_index, 0.0)) + portion
			moved_mass += moved
	var affected_indices: Array = deltas.keys()
	affected_indices.sort()
	for index_variant in affected_indices:
		var index: int = index_variant
		thickness[index] = clampf(thickness[index] + float(deltas[index]), 0.0, parameters.maximum_thickness)
	var new_holes := 0
	var peak_damage := 0.0
	for index_variant in affected_indices:
		var index: int = index_variant
		if thickness[index] > parameters.minimum_covered_thickness:
			coverage[index] = 1.0
		else:
			coverage[index] = 0.0
		if thickness[index] <= parameters.thin_damage_threshold:
			var speed_stress := clampf(maxf(speed_cells_per_second, 0.0) / 120.0, 0.35, 1.5)
			scrape_stress[index] = minf(scrape_stress[index] + 0.035 * speed_stress, 2.0)
			if scrape_stress[index] > 0.28:
				var previous_damage := damage[index]
				damage[index] = clampf(damage[index] + (scrape_stress[index] - 0.28) * 0.06, 0.0, 1.0)
				if previous_damage < parameters.hole_damage_threshold and damage[index] >= parameters.hole_damage_threshold:
					new_holes += 1
			if damage[index] >= parameters.hole_damage_threshold:
				coverage[index] = 0.0
				thickness[index] = 0.0
		peak_damage = maxf(peak_damage, damage[index])
	last_update_usec = Time.get_ticks_usec() - started
	_commit_change(affected_indices.size())
	return {
		"changed_cells": affected_indices.size(),
		"moved_mass": moved_mass,
		"new_holes": new_holes,
		"peak_damage": peak_damage,
	}


func apply_standard_press_spread() -> Dictionary:
	var center := Vector2(grid_size - 1, grid_size - 1) * 0.5
	var changed_cells := 0
	var moved_mass := 0.0
	var new_holes := 0
	for ring_radius in [0.0, 5.0, 10.0, 15.0, 20.0, 25.0]:
		var sample_count := 1 if ring_radius <= 0.0 else 16
		for sample_index in sample_count:
			var direction: Vector2 = Vector2.RIGHT.rotated(TAU * float(sample_index) / float(sample_count))
			var sample: Vector2 = center + direction * float(ring_radius)
			var result := apply_scraper_sample(sample, direction, 72.0, 1.35)
			changed_cells += int(result.get("changed_cells", 0))
			moved_mass += float(result.get("moved_mass", 0.0))
			new_holes += int(result.get("new_holes", 0))
	return {"changed_cells": changed_cells, "moved_mass": moved_mass, "new_holes": new_holes}


func begin_sauce_stroke() -> int:
	_sauce_stroke_serial += 1
	_sauce_active_stroke_id = _sauce_stroke_serial
	_sauce_previous_sample_serial = -1
	return _sauce_stroke_serial


func apply_sauce_sample(center: Vector2, layer_amount: float, radius: float, stroke_id: int, maximum_new_cells: int = 2147483647, sauce_type: StringName = &"sweet_flour") -> Dictionary:
	var started := Time.get_ticks_usec()
	var safe_amount := maxf(layer_amount, 0.0)
	var safe_radius := maxf(radius, 0.5)
	var cell_budget := maxi(maximum_new_cells, 0)
	if safe_amount <= 0.0 or cell_budget <= 0:
		return {"changed_cells": 0, "newly_layered_cells": 0, "deposited_sauce": 0.0, "peak_concentration": 0.0}
	if stroke_id != _sauce_active_stroke_id:
		_sauce_active_stroke_id = stroke_id
		_sauce_previous_sample_serial = -1
	_sauce_sample_serial += 1
	var current_sample_serial := _sauce_sample_serial
	var min_x := maxi(floori(center.x - safe_radius), 0)
	var max_x := mini(ceili(center.x + safe_radius), grid_size - 1)
	var min_y := maxi(floori(center.y - safe_radius), 0)
	var max_y := mini(ceili(center.y + safe_radius), grid_size - 1)
	var changed_cells := 0
	var deposited_sauce := 0.0
	var peak_concentration := 0.0
	var target_field := chili_sauce_concentration if sauce_type == &"red_chili" else sauce_concentration
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var index := y * grid_size + x
			if coverage[index] <= 0.0 or damage[index] >= parameters.hole_damage_threshold:
				continue
			if Vector2(x, y).distance_squared_to(center) > safe_radius * safe_radius:
				continue
			var was_inside_previous_sample := _sauce_previous_sample_serial >= 0 and _sauce_footprint_stamp[index] == _sauce_previous_sample_serial
			_sauce_footprint_stamp[index] = current_sample_serial
			if was_inside_previous_sample or changed_cells >= cell_budget:
				continue
			var previous := target_field[index]
			target_field[index] = minf(previous + safe_amount, parameters.sauce_maximum_concentration)
			deposited_sauce += target_field[index] - previous
			peak_concentration = maxf(peak_concentration, target_field[index])
			changed_cells += 1
	_sauce_previous_sample_serial = current_sample_serial
	last_update_usec = Time.get_ticks_usec() - started
	_commit_change(changed_cells)
	return {
		"changed_cells": changed_cells,
		"newly_layered_cells": changed_cells,
		"deposited_sauce": deposited_sauce,
		"peak_concentration": peak_concentration,
	}


func is_inside_pan(cell_position: Vector2, radius_scale: float = 1.0) -> bool:
	var center := Vector2(grid_size - 1, grid_size - 1) * 0.5
	var safe_radius_scale := maxf(radius_scale, 0.001)
	var radii := Vector2(float(grid_size) * 0.5, float(grid_size) * 0.5 * parameters.pan_height_ratio) * safe_radius_scale
	var normalized := (cell_position - center) / radii
	return normalized.length_squared() <= 1.0


func total_thickness() -> float:
	var total := 0.0
	for value in thickness:
		total += value
	return total


func total_sauce(sauce_type: StringName = &"sweet_flour") -> float:
	var total := 0.0
	var field := chili_sauce_concentration if sauce_type == &"red_chili" else sauce_concentration
	for value in field:
		total += value
	return total


func covered_cell_count() -> int:
	var count := 0
	for value in coverage:
		if value > 0.0:
			count += 1
	return count


func snapshot() -> Dictionary:
	return {
		"grid_size": grid_size,
		"revision": revision,
		"coverage": coverage.duplicate(),
		"thickness": thickness.duplicate(),
		"wetness": wetness.duplicate(),
		"doneness": doneness.duplicate(),
		"back_doneness": back_doneness.duplicate(),
		"damage": damage.duplicate(),
		"scrape_stress": scrape_stress.duplicate(),
		"sauce_concentration": sauce_concentration.duplicate(),
		"chili_sauce_concentration": chili_sauce_concentration.duplicate(),
		"egg_white": egg_white.duplicate(),
		"egg_yolk": egg_yolk.duplicate(),
		"egg_doneness": egg_doneness.duplicate(),
		"egg_state": egg_state,
		"yolk_broken": yolk_broken,
		"is_flipped": is_flipped,
	}


func calculate_summary() -> Dictionary:
	var covered_cells := 0
	var pan_cells := 0
	var thickness_total := 0.0
	var wetness_total := 0.0
	var doneness_total := 0.0
	var damaged_cells := 0
	var sauce_total := 0.0
	var sauce_covered_cells := 0
	var sauce_excess_cells := 0
	var chili_sauce_total := 0.0
	var chili_sauce_covered_cells := 0
	for index in cell_count:
		var cell := Vector2(index % grid_size, index / grid_size)
		if is_inside_pan(cell):
			pan_cells += 1
		if coverage[index] > 0.0:
			covered_cells += 1
			thickness_total += thickness[index]
			wetness_total += wetness[index]
			doneness_total += doneness[index]
			sauce_total += sauce_concentration[index]
			chili_sauce_total += chili_sauce_concentration[index]
			if sauce_concentration[index] >= parameters.sauce_missing_threshold:
				sauce_covered_cells += 1
			if sauce_concentration[index] > parameters.sauce_excess_threshold:
				sauce_excess_cells += 1
			if chili_sauce_concentration[index] >= parameters.sauce_missing_threshold:
				chili_sauce_covered_cells += 1
		if damage[index] > 0.0:
			damaged_cells += 1
	var divisor := maxf(float(covered_cells), 1.0)
	var egg_summary := calculate_egg_spread_summary()
	return {
		"coverage_ratio": float(covered_cells) / maxf(float(pan_cells), 1.0),
		"mean_thickness": thickness_total / divisor,
		"mean_wetness": wetness_total / divisor,
		"mean_doneness": doneness_total / divisor,
		"mean_back_doneness": mean_side_doneness(true),
		"damage_ratio": float(damaged_cells) / maxf(float(pan_cells), 1.0),
		"mean_sauce_concentration": sauce_total / divisor,
		"sauce_coverage_ratio": float(sauce_covered_cells) / divisor,
		"sauce_excess_ratio": float(sauce_excess_cells) / divisor,
		"mean_chili_sauce_concentration": chili_sauce_total / divisor,
		"chili_sauce_coverage_ratio": float(chili_sauce_covered_cells) / divisor,
		"egg_spread_score": float(egg_summary.score),
		"egg_coverage_ratio": float(egg_summary.coverage_ratio),
		"egg_uniformity": float(egg_summary.uniformity),
		"mean_egg_doneness": float(egg_summary.mean_doneness),
	}


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var fields := _all_fields()
	var field_names: Array[StringName] = FIELD_NAMES.duplicate()
	field_names.insert(4, &"back_doneness")
	field_names.append(&"scrape_stress")
	for field_index in field_names.size():
		var field_name := field_names[field_index]
		var field: PackedFloat32Array = fields[field_index]
		if field.size() != cell_count:
			errors.append("%s size is %d, expected %d" % [field_name, field.size(), cell_count])
			continue
		for index in field.size():
			var value := field[index]
			if is_nan(value) or is_inf(value):
				errors.append("%s[%d] is not finite" % [field_name, index])
				break
			if value < 0.0:
				errors.append("%s[%d] is negative" % [field_name, index])
				break
	return errors


func _all_fields() -> Array:
	return [
		coverage,
		thickness,
		wetness,
		doneness,
		back_doneness,
		damage,
		sauce_concentration,
		chili_sauce_concentration,
		egg_white,
		egg_yolk,
		egg_doneness,
		scrape_stress,
	]


func _commit_change(changed_cells: int) -> void:
	if changed_cells <= 0:
		return
	revision += 1
	changed.emit()
