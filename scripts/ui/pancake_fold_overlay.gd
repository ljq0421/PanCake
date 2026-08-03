class_name PancakeFoldOverlay
extends Control

const FOLD_MODEL_SCRIPT := preload("res://scripts/gameplay/pancake_fold_model.gd")
const FOLD_COMPLETION_MIN_DURATION := 0.14
const FOLD_COMPLETION_MAX_DURATION := 0.30
const FOLD_SETTLE_DURATION := 0.42
const FOLD_MESH_COLUMNS := 28
const FOLD_PROFILE_STEPS := 56
const FOLD_EARLY_BEND_RATIO := 0.58
const FOLD_LANDED_BEND_RATIO := 0.22
const FOLD_HEIGHT_SCREEN_FACTOR := 0.15

@export var pancake_front_texture: Texture2D
@export var pancake_back_texture: Texture2D
@export var pancake_edge_texture: Texture2D
@export var paper_bag_package_texture: Texture2D
@export var reinforced_sleeve_package_texture: Texture2D
@export var serving_tray_package_texture: Texture2D

var fold_model: RefCounted
var guides_visible := false
var _last_package_result: StringName = FOLD_MODEL_SCRIPT.PACKAGE_NONE
var _package_reveal := 0.0
var _last_active_region: StringName = FOLD_MODEL_SCRIPT.REGION_NONE
var _last_drag_progress := 0.0
var _folded_snapshot := {
	FOLD_MODEL_SCRIPT.REGION_LEFT: false,
	FOLD_MODEL_SCRIPT.REGION_RIGHT: false,
}
var _animated_region: StringName = FOLD_MODEL_SCRIPT.REGION_NONE
var _animated_progress := 0.0
var _settle_phase := 1.0
var _fold_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_fold_model(value: RefCounted) -> void:
	if fold_model != null and fold_model.changed.is_connected(_on_fold_changed):
		fold_model.changed.disconnect(_on_fold_changed)
	fold_model = value
	if fold_model != null:
		fold_model.changed.connect(_on_fold_changed)
		_last_package_result = fold_model.package_result
		_package_reveal = 1.0 if _last_package_result != FOLD_MODEL_SCRIPT.PACKAGE_NONE else 0.0
		_last_active_region = fold_model.active_region
		_last_drag_progress = float(fold_model.drag_progress)
		for region in [FOLD_MODEL_SCRIPT.REGION_LEFT, FOLD_MODEL_SCRIPT.REGION_RIGHT]:
			_folded_snapshot[region] = fold_model.is_region_folded(region)
	queue_redraw()


func set_guides_visible(value: bool) -> void:
	guides_visible = value
	queue_redraw()


func _on_fold_changed() -> void:
	if fold_model == null:
		queue_redraw()
		return
	var newly_folded: StringName = FOLD_MODEL_SCRIPT.REGION_NONE
	for region in [FOLD_MODEL_SCRIPT.REGION_LEFT, FOLD_MODEL_SCRIPT.REGION_RIGHT]:
		var folded_now: bool = fold_model.is_region_folded(region)
		if folded_now and not bool(_folded_snapshot.get(region, false)):
			newly_folded = region
		_folded_snapshot[region] = folded_now
	if fold_model.active_region != FOLD_MODEL_SCRIPT.REGION_NONE:
		_last_active_region = fold_model.active_region
		_last_drag_progress = float(fold_model.drag_progress)
		if _fold_tween != null and _fold_tween.is_running():
			_fold_tween.kill()
		_animated_region = FOLD_MODEL_SCRIPT.REGION_NONE
		_settle_phase = 1.0
	elif newly_folded != FOLD_MODEL_SCRIPT.REGION_NONE:
		_start_fold_landing(newly_folded, _last_drag_progress if _last_active_region == newly_folded else 1.0)
		_last_active_region = FOLD_MODEL_SCRIPT.REGION_NONE
		_last_drag_progress = 0.0
	var package_result: StringName = fold_model.package_result if fold_model != null else FOLD_MODEL_SCRIPT.PACKAGE_NONE
	if package_result != _last_package_result:
		_last_package_result = package_result
		if package_result == FOLD_MODEL_SCRIPT.PACKAGE_NONE:
			_package_reveal = 0.0
		else:
			_package_reveal = 0.0
			var tween := create_tween()
			tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_method(_set_package_reveal, 0.0, 1.0, 0.28)
	queue_redraw()


func _start_fold_landing(region: StringName, from_progress: float) -> void:
	if _fold_tween != null and _fold_tween.is_running():
		_fold_tween.kill()
	_animated_region = region
	_animated_progress = clampf(from_progress, 0.0, 1.0)
	_settle_phase = 0.0
	var completion_duration := lerpf(
		FOLD_COMPLETION_MAX_DURATION,
		FOLD_COMPLETION_MIN_DURATION,
		_animated_progress
	)
	_fold_tween = create_tween()
	_fold_tween.tween_method(_set_animated_progress, _animated_progress, 1.0, completion_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fold_tween.tween_method(_set_settle_phase, 0.0, 1.0, FOLD_SETTLE_DURATION).set_trans(Tween.TRANS_LINEAR)
	_fold_tween.finished.connect(_finish_fold_landing)


func _set_animated_progress(value: float) -> void:
	_animated_progress = clampf(value, 0.0, 1.0)
	queue_redraw()


func _set_settle_phase(value: float) -> void:
	_settle_phase = clampf(value, 0.0, 1.0)
	queue_redraw()


func _finish_fold_landing() -> void:
	_animated_region = FOLD_MODEL_SCRIPT.REGION_NONE
	_animated_progress = 0.0
	_settle_phase = 1.0
	queue_redraw()


func is_fold_animation_active() -> bool:
	return _animated_region != FOLD_MODEL_SCRIPT.REGION_NONE


func _set_package_reveal(value: float) -> void:
	_package_reveal = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	if fold_model == null or fold_model.pancake_model == null:
		return
	if fold_model.package_result != FOLD_MODEL_SCRIPT.PACKAGE_NONE:
		_draw_package()
		return
	if guides_visible:
		_draw_guides()
	_draw_region(FOLD_MODEL_SCRIPT.REGION_LEFT)
	_draw_region(FOLD_MODEL_SCRIPT.REGION_RIGHT)


func _draw_guides() -> void:
	var left_x: float = size.x * float(fold_model.pancake_model.parameters.fold_left_line_ratio)
	var right_x: float = size.x * float(fold_model.pancake_model.parameters.fold_right_line_ratio)
	var geometry := _pancake_geometry()
	var left_span := _guide_span(left_x, geometry)
	var right_span := _guide_span(right_x, geometry)
	var guide_color := Color(0.98, 0.91, 0.42, 0.90)
	_draw_dashed_line(Vector2(left_x, left_span.x), Vector2(left_x, left_span.y), guide_color)
	_draw_dashed_line(Vector2(right_x, right_span.x), Vector2(right_x, right_span.y), guide_color)
	var center: Vector2 = geometry.center
	var radii: Vector2 = geometry.radii
	if not fold_model.is_region_folded(FOLD_MODEL_SCRIPT.REGION_LEFT):
		draw_arc(center - Vector2(radii.x * 0.92, 0.0), size.x * 0.040, -1.2, 1.2, 20, Color(0.45, 0.94, 0.94, 0.95), 5.0, true)
	if not fold_model.is_region_folded(FOLD_MODEL_SCRIPT.REGION_RIGHT):
		draw_arc(center + Vector2(radii.x * 0.92, 0.0), size.x * 0.040, PI - 1.2, PI + 1.2, 20, Color(0.45, 0.94, 0.94, 0.95), 5.0, true)


func _draw_region(region: StringName) -> void:
	var folded: bool = fold_model.is_region_folded(region)
	var active: bool = fold_model.active_region == region
	var animated: bool = _animated_region == region
	if not folded and not active and not animated:
		return
	var progress: float = _animated_progress if animated else (1.0 if folded else float(fold_model.drag_progress))
	var source_polygon := _segment_polygon(region)
	var flap_polygon := _transform_polygon(source_polygon, region, progress)
	var result: Dictionary = fold_model.get_region_result(region)
	var severity := int(result.get("severity", 0)) if folded else 0
	var flap_color := Color(1.0, 0.98, 0.91, 0.99)
	if severity == 1:
		flap_color = Color(0.92, 0.72, 0.48, 0.99)
	elif severity >= 2:
		flap_color = Color(0.76, 0.43, 0.31, 0.99)
	var profile := _build_fold_profile(region, progress)
	_draw_flap_shadow(flap_polygon, region, progress, profile)
	_draw_curved_flap(region, progress, flap_color, profile)
	_draw_arc_highlight(region, progress, profile)
	_draw_fold_crease(region, progress, severity)
	var edge_color := Color(0.29, 0.13, 0.045, 0.78)
	if pancake_edge_texture != null:
		edge_color = Color(0.34, 0.15, 0.04, 0.78)
	# The open arc is the exposed pancake rim. Closing this path would paint a
	# rigid dark rectangle along the fold line and make the flap read as card.
	draw_polyline(flap_polygon, edge_color, 2.4, true)
	draw_polyline(flap_polygon, Color(1.0, 0.74, 0.26, 0.16), 1.0, true)
	if folded and severity > 0:
		_draw_cracks(flap_polygon, severity)


func _draw_flap_shadow(
	_flap_polygon: PackedVector2Array,
	region: StringName,
	progress: float,
	profile: Dictionary
) -> void:
	var lift := sin(clampf(progress, 0.0, 1.0) * PI)
	var direction := -1.0 if region == FOLD_MODEL_SCRIPT.REGION_LEFT else 1.0
	var settle_wave := _settle_wave(region)
	var heights: PackedFloat32Array = profile.heights
	var maximum_height := 0.0
	for height in heights:
		maximum_height = maxf(maximum_height, height)
	var flap_width: float = profile.flap_width
	var offset := Vector2(
		direction * (4.0 + maximum_height * flap_width * 0.06),
		5.0 + maximum_height * flap_width * 0.16 + lift * 5.0 + absf(settle_wave) * 4.0
	)
	var alpha := 0.10 + lift * 0.18 + absf(settle_wave) * 0.06
	# The curved outline may loop back near the crease and is therefore not one
	# simple polygon. Shadow the same strips as the surface to keep triangulation
	# valid throughout the roll-over.
	for column in FOLD_MESH_COLUMNS:
		var t0 := float(column) / float(FOLD_MESH_COLUMNS)
		var t1 := float(column + 1) / float(FOLD_MESH_COLUMNS)
		var source_quad := _source_fold_strip(region, t0, t1, profile)
		var shadow_quad := PackedVector2Array()
		for source_point in source_quad:
			shadow_quad.append(_transform_fold_point(source_point, progress, profile) + offset)
		draw_colored_polygon(shadow_quad, Color(0.13, 0.045, 0.012, alpha))


func _draw_curved_flap(region: StringName, progress: float, tint: Color, profile: Dictionary) -> void:
	# Each strip receives its own projected position, face texture, and lighting.
	# A single polygon can only interpolate between its outline vertices, which
	# makes the fold read as a rigid card even when the silhouette is softened.
	for column in FOLD_MESH_COLUMNS:
		var t0 := float(column) / float(FOLD_MESH_COLUMNS)
		var t1 := float(column + 1) / float(FOLD_MESH_COLUMNS)
		var source_quad := _source_fold_strip(region, t0, t1, profile)
		var folded_quad := PackedVector2Array()
		var uvs := PackedVector2Array()
		for source_point in source_quad:
			folded_quad.append(_transform_fold_point(source_point, progress, profile))
			uvs.append(Vector2(
				clampf(source_point.x / maxf(size.x, 1.0), 0.0, 1.0),
				clampf(source_point.y / maxf(size.y, 1.0), 0.0, 1.0)
			))
		var angle0 := _profile_angle(profile, t0)
		var angle1 := _profile_angle(profile, t1)
		var color0 := _fold_surface_color(tint, angle0)
		var color1 := _fold_surface_color(tint, angle1)
		var colors := PackedColorArray([color0, color1, color1, color0])
		var midpoint_angle := _profile_angle(profile, (t0 + t1) * 0.5)
		var texture := pancake_front_texture if cos(midpoint_angle) >= 0.0 else pancake_back_texture
		if texture == null:
			draw_colored_polygon(folded_quad, color0 * Color(0.93, 0.62, 0.23, 1.0))
		else:
			draw_polygon(folded_quad, colors, uvs, texture)


func _draw_arc_highlight(region: StringName, progress: float, profile: Dictionary) -> void:
	var total_angle := clampf(progress, 0.0, 1.0) * PI
	if total_angle < 0.38:
		return
	var target_angle := minf(total_angle * 0.72, 1.22)
	var best_t := 0.0
	var best_delta := INF
	for step in FOLD_PROFILE_STEPS + 1:
		var t := float(step) / float(FOLD_PROFILE_STEPS)
		var delta := absf(_profile_angle(profile, t) - target_angle)
		if delta < best_delta:
			best_delta = delta
			best_t = t
	var source_span := _source_fold_span(region, best_t, profile)
	var from := _transform_fold_point(source_span[0], progress, profile)
	var to := _transform_fold_point(source_span[1], progress, profile)
	var strength := sin(clampf(progress, 0.0, 1.0) * PI) * 0.22 + smoothstep(0.72, 1.0, progress) * 0.12
	draw_line(from, to, Color(1.0, 0.86, 0.52, strength), 3.0, true)


func _draw_fold_crease(region: StringName, progress: float, severity: int) -> void:
	var line_ratio: float = fold_model.pancake_model.parameters.fold_left_line_ratio if region == FOLD_MODEL_SCRIPT.REGION_LEFT else fold_model.pancake_model.parameters.fold_right_line_ratio
	var line_x := size.x * line_ratio
	var span := _guide_span(line_x, _pancake_geometry())
	var lift := sin(clampf(progress, 0.0, 1.0) * PI)
	var crease_strength := clampf(lift * 0.92 + smoothstep(0.80, 1.0, progress) * 0.24, 0.0, 1.0)
	if crease_strength <= 0.01:
		return
	var from := Vector2(line_x, span.x + 5.0)
	var to := Vector2(line_x, span.y - 5.0)
	var shadow_color := Color(0.20, 0.075, 0.022, (0.25 + float(severity) * 0.10) * crease_strength)
	var highlight_color := Color(1.0, 0.82, 0.40, 0.24 * crease_strength)
	var highlight_offset := -3.0 if region == FOLD_MODEL_SCRIPT.REGION_LEFT else 3.0
	draw_line(from, to, shadow_color, 7.0 + lift * 3.0, true)
	draw_line(from + Vector2(highlight_offset, 0.0), to + Vector2(highlight_offset, 0.0), highlight_color, 2.0, true)


func _segment_polygon(region: StringName) -> PackedVector2Array:
	var geometry := _pancake_geometry()
	var center: Vector2 = geometry.center
	var radii: Vector2 = geometry.radii
	var line_ratio: float = fold_model.pancake_model.parameters.fold_left_line_ratio if region == FOLD_MODEL_SCRIPT.REGION_LEFT else fold_model.pancake_model.parameters.fold_right_line_ratio
	var line_x := size.x * line_ratio
	var dx := clampf((line_x - center.x) / maxf(radii.x, 0.001), -0.999, 0.999)
	var base_angle := acos(dx)
	var points := PackedVector2Array()
	var steps := 18
	if region == FOLD_MODEL_SCRIPT.REGION_LEFT:
		var top_angle := TAU - base_angle
		for step in range(steps + 1):
			var angle := lerpf(top_angle, base_angle, float(step) / float(steps))
			points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	else:
		var top_angle := TAU - base_angle
		for step in range(steps + 1):
			var angle := lerpf(top_angle, TAU + base_angle, float(step) / float(steps))
			points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points


func _pancake_geometry() -> Dictionary:
	var model = fold_model.pancake_model
	var minimum := Vector2i(model.grid_size, model.grid_size)
	var maximum := Vector2i(-1, -1)
	for y in model.grid_size:
		for x in model.grid_size:
			var index: int = y * int(model.grid_size) + x
			if model.coverage[index] <= 0.0 and model.damage[index] < model.parameters.hole_damage_threshold:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x:
		return {
			"center": size * 0.5,
			"radii": Vector2(size.x * 0.36, size.y * 0.36 * model.parameters.pan_height_ratio),
		}
	var grid_extent := Vector2(maximum - minimum + Vector2i.ONE)
	var center_grid := Vector2(minimum + maximum) * 0.5 + Vector2(0.5, 0.5)
	var center_local := Vector2(center_grid.x / float(model.grid_size) * size.x, center_grid.y / float(model.grid_size) * size.y)
	var radii_local := Vector2(
		grid_extent.x / float(model.grid_size) * size.x,
		grid_extent.y / float(model.grid_size) * size.y
	) * 0.5
	return {"center": center_local, "radii": radii_local}


func _transform_polygon(source: PackedVector2Array, region: StringName, progress: float) -> PackedVector2Array:
	var profile := _build_fold_profile(region, progress)
	var transformed := PackedVector2Array()
	for point in source:
		transformed.append(_transform_fold_point(point, progress, profile))
	return transformed


func get_fold_arc_profile(region: StringName, progress: float) -> PackedVector2Array:
	if fold_model == null or fold_model.pancake_model == null:
		return PackedVector2Array()
	return _build_fold_profile(region, progress).points


func _build_fold_profile(region: StringName, progress: float) -> Dictionary:
	var line_ratio: float = fold_model.pancake_model.parameters.fold_left_line_ratio if region == FOLD_MODEL_SCRIPT.REGION_LEFT else fold_model.pancake_model.parameters.fold_right_line_ratio
	var line_x := size.x * line_ratio
	var geometry := _pancake_geometry()
	var center: Vector2 = geometry.center
	var radii: Vector2 = geometry.radii
	var side := -1.0 if region == FOLD_MODEL_SCRIPT.REGION_LEFT else 1.0
	var outer_x := center.x + side * radii.x
	var flap_width := maxf(absf(outer_x - line_x), 1.0)
	var clamped_progress := clampf(progress, 0.0, 1.0)
	var total_angle := clamped_progress * PI
	var landing := smoothstep(0.35, 1.0, clamped_progress)
	var bend_ratio := lerpf(FOLD_EARLY_BEND_RATIO, FOLD_LANDED_BEND_RATIO, landing)
	var x_offsets := PackedFloat32Array([0.0])
	var heights := PackedFloat32Array([0.0])
	var angles := PackedFloat32Array([0.0])
	var points := PackedVector2Array([Vector2(line_x, center.y)])
	var x_offset := 0.0
	var height := 0.0
	for step in range(1, FOLD_PROFILE_STEPS + 1):
		var t0 := float(step - 1) / float(FOLD_PROFILE_STEPS)
		var t1 := float(step) / float(FOLD_PROFILE_STEPS)
		var midpoint := (t0 + t1) * 0.5
		var midpoint_angle := total_angle * smoothstep(0.0, bend_ratio, midpoint)
		var segment_length := t1 - t0
		x_offset += cos(midpoint_angle) * segment_length
		height += sin(midpoint_angle) * segment_length
		var angle := total_angle * smoothstep(0.0, bend_ratio, t1)
		x_offsets.append(x_offset)
		heights.append(height)
		angles.append(angle)
		points.append(Vector2(
			line_x + side * flap_width * x_offset,
			center.y - flap_width * height * FOLD_HEIGHT_SCREEN_FACTOR
		))
	return {
		"region": region,
		"line_x": line_x,
		"center": center,
		"radii": radii,
		"side": side,
		"flap_width": flap_width,
		"progress": clamped_progress,
		"x_offsets": x_offsets,
		"heights": heights,
		"angles": angles,
		"points": points,
	}


func _transform_fold_point(source_point: Vector2, progress: float, profile: Dictionary) -> Vector2:
	var line_x: float = profile.line_x
	var center: Vector2 = profile.center
	var radii: Vector2 = profile.radii
	var side: float = profile.side
	var flap_width: float = profile.flap_width
	var distance_ratio := clampf(absf(source_point.x - line_x) / flap_width, 0.0, 1.0)
	var x_offset := _profile_value(profile.x_offsets, distance_ratio)
	var height := _profile_value(profile.heights, distance_ratio)
	var clamped_progress := clampf(progress, 0.0, 1.0)
	var lift := sin(clamped_progress * PI)
	var final_softness := smoothstep(0.76, 1.0, clamped_progress)
	var settle_wave := _settle_wave(profile.region)
	var vertical_ratio := clampf((source_point.y - center.y) / maxf(radii.y, 1.0), -1.0, 1.0)
	var rounded_scale := 1.0 - lift * (0.055 + distance_ratio * 0.040)
	rounded_scale -= final_softness * sin(distance_ratio * PI) * 0.020
	rounded_scale -= absf(settle_wave) * 0.020
	var moved_x := line_x + side * flap_width * x_offset
	moved_x = line_x + (moved_x - line_x) * (1.0 + settle_wave * 0.035)
	# Project the physical lift slightly upward on screen. The profile itself is
	# still driven by the same fold progress, so input and simulation stay pure.
	var moved_y := center.y + (source_point.y - center.y) * rounded_scale
	moved_y -= flap_width * height * FOLD_HEIGHT_SCREEN_FACTOR
	var pillow := final_softness * distance_ratio * (1.0 - distance_ratio)
	moved_y += vertical_ratio * radii.y * pillow * 0.045
	return Vector2(moved_x, moved_y)


func _source_fold_strip(region: StringName, t0: float, t1: float, profile: Dictionary) -> PackedVector2Array:
	var span0 := _source_fold_span(region, t0, profile)
	var span1 := _source_fold_span(region, t1, profile)
	return PackedVector2Array([span0[0], span1[0], span1[1], span0[1]])


func _source_fold_span(_region: StringName, distance_ratio: float, profile: Dictionary) -> Array[Vector2]:
	var center: Vector2 = profile.center
	var radii: Vector2 = profile.radii
	var line_x: float = profile.line_x
	var side: float = profile.side
	var flap_width: float = profile.flap_width
	var x := line_x + side * flap_width * clampf(distance_ratio, 0.0, 1.0)
	var normalized_x := clampf((x - center.x) / maxf(radii.x, 1.0), -1.0, 1.0)
	var half_height := radii.y * sqrt(maxf(1.0 - normalized_x * normalized_x, 0.0))
	return [Vector2(x, center.y - half_height), Vector2(x, center.y + half_height)]


func _profile_value(values: PackedFloat32Array, distance_ratio: float) -> float:
	var cursor := clampf(distance_ratio, 0.0, 1.0) * float(FOLD_PROFILE_STEPS)
	var low := mini(int(floor(cursor)), FOLD_PROFILE_STEPS)
	var high := mini(low + 1, FOLD_PROFILE_STEPS)
	return lerpf(values[low], values[high], cursor - float(low))


func _profile_angle(profile: Dictionary, distance_ratio: float) -> float:
	var angles: PackedFloat32Array = profile.angles
	return _profile_value(angles, distance_ratio)


func _fold_surface_color(tint: Color, angle: float) -> Color:
	var facing := absf(cos(angle))
	var brightness := 0.70 + facing * 0.30
	var rounded_highlight := pow(maxf(sin(angle - 0.22), 0.0), 7.0) * 0.18
	brightness += rounded_highlight
	return Color(
		minf(tint.r * brightness, 1.0),
		minf(tint.g * brightness, 1.0),
		minf(tint.b * brightness, 1.0),
		tint.a
	)


func _settle_wave(region: StringName) -> float:
	if _animated_region != region or _animated_progress < 0.98:
		return 0.0
	var damping := pow(1.0 - _settle_phase, 1.55)
	return sin(_settle_phase * TAU * 1.65) * damping


func _guide_span(line_x: float, geometry: Dictionary) -> Vector2:
	var center: Vector2 = geometry.center
	var radii: Vector2 = geometry.radii
	var normalized_x := clampf((line_x - center.x) / maxf(radii.x, 0.001), -1.0, 1.0)
	var half_height := radii.y * sqrt(maxf(1.0 - normalized_x * normalized_x, 0.0))
	return Vector2(center.y - half_height, center.y + half_height)


func _draw_cracks(polygon: PackedVector2Array, severity: int) -> void:
	if polygon.is_empty():
		return
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		bounds = bounds.expand(point)
	var center := bounds.get_center()
	var main_fissure := PackedVector2Array([
		center + Vector2(-bounds.size.x * 0.12, -bounds.size.y * 0.18),
		center + Vector2(-bounds.size.x * 0.05, -bounds.size.y * 0.08),
		center + Vector2(bounds.size.x * 0.045, -bounds.size.y * 0.015),
		center + Vector2(-bounds.size.x * 0.015, bounds.size.y * 0.095),
		center + Vector2(bounds.size.x * 0.035, bounds.size.y * 0.20),
	])
	var upper_branch := PackedVector2Array([
		main_fissure[1],
		center + Vector2(-bounds.size.x * 0.17, -bounds.size.y * 0.12),
		center + Vector2(-bounds.size.x * 0.23, -bounds.size.y * 0.16),
	])
	var side_branch := PackedVector2Array([
		main_fissure[2],
		center + Vector2(bounds.size.x * 0.14, bounds.size.y * 0.035),
		center + Vector2(bounds.size.x * 0.21, bounds.size.y * 0.075),
	])
	_draw_crumb_fissure(main_fissure, 1.75)
	_draw_crumb_fissure(upper_branch, 1.25)
	_draw_crumb_fissure(side_branch, 1.15)
	if severity >= 2:
		var lower_branch := PackedVector2Array([
			main_fissure[3],
			center + Vector2(-bounds.size.x * 0.12, bounds.size.y * 0.15),
			center + Vector2(-bounds.size.x * 0.19, bounds.size.y * 0.21),
		])
		var hairline := PackedVector2Array([
			main_fissure[0],
			center + Vector2(-bounds.size.x * 0.02, -bounds.size.y * 0.23),
			center + Vector2(bounds.size.x * 0.025, -bounds.size.y * 0.27),
		])
		_draw_crumb_fissure(lower_branch, 1.30)
		_draw_crumb_fissure(hairline, 0.95)


func _draw_crumb_fissure(points: PackedVector2Array, dark_width: float) -> void:
	if points.size() < 2:
		return
	# A soft golden crumb edge under a narrow toasted split matches the painted
	# pores and scorch marks in the pancake textures. Pure black, wide strokes
	# read as UI symbols instead of cracks in cooked batter.
	var crumb_edge := Color(1.0, 0.68, 0.25, 0.34)
	var toasted_split := Color(0.30, 0.105, 0.030, 0.80)
	draw_polyline(points, crumb_edge, dark_width + 2.5, true)
	draw_polyline(points, toasted_split, dark_width, true)
	for endpoint in [points[0], points[points.size() - 1]]:
		draw_circle(endpoint, dark_width * 0.72, toasted_split)


func _draw_package() -> void:
	var texture := current_package_texture()
	if texture == null:
		return
	var reveal_scale := lerpf(0.72, 1.0, _package_reveal)
	var side := minf(size.x, size.y) * 0.82 * reveal_scale
	var rect := Rect2(size * 0.5 - Vector2.ONE * side * 0.5, Vector2.ONE * side)
	var opacity := smoothstep(0.0, 0.35, _package_reveal)
	draw_texture_rect(texture, rect, false, Color(1.0, 1.0, 1.0, opacity))


func current_package_texture() -> Texture2D:
	var package_result: StringName = fold_model.package_result if fold_model != null else FOLD_MODEL_SCRIPT.PACKAGE_NONE
	match package_result:
		FOLD_MODEL_SCRIPT.PACKAGE_BAG:
			return paper_bag_package_texture
		FOLD_MODEL_SCRIPT.PACKAGE_SLEEVE:
			return reinforced_sleeve_package_texture
		FOLD_MODEL_SCRIPT.PACKAGE_TRAY:
			return serving_tray_package_texture
		_:
			return null


func _draw_dashed_line(from: Vector2, to: Vector2, color: Color) -> void:
	var length := from.distance_to(to)
	var direction := from.direction_to(to)
	var cursor := 0.0
	while cursor < length:
		var segment_end := minf(cursor + 14.0, length)
		draw_line(from + direction * cursor, from + direction * segment_end, color, 4.0, true)
		cursor += 25.0


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if not result.is_empty():
		result.append(result[0])
	return result
