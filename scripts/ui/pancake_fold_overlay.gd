class_name PancakeFoldOverlay
extends Control

signal fold_completion_finished
signal fold_landing_finished
signal package_reveal_finished

const FOLD_MODEL_SCRIPT := preload("res://scripts/gameplay/pancake_fold_model.gd")
const FOLD_COMPLETION_MIN_DURATION := 0.06
const FOLD_COMPLETION_MAX_DURATION := 0.24
const AUTOMATIC_FOLD_COMPLETION_DURATION := 0.18
const FOLD_SETTLE_DURATION := 0.12
const PACKAGE_REVEAL_DURATION := 0.24
const FOLD_MESH_COLUMNS := 28
const FOLD_PROFILE_STEPS := 56
const FOLD_EARLY_BEND_RATIO := 0.58
const FOLD_LANDED_BEND_RATIO := 0.22
const FOLD_HEIGHT_SCREEN_FACTOR := 0.15
const FOLD_VISIBLE_COVERAGE_MIN := 0.02
const FOLD_VISIBLE_DAMAGE_MAX := 0.98

@export var pancake_front_texture: Texture2D
@export var pancake_back_texture: Texture2D
@export var pancake_edge_texture: Texture2D
@export var paper_bag_package_texture: Texture2D

var fold_model: RefCounted
var guides_visible := false
var hovered_region: StringName = FOLD_MODEL_SCRIPT.REGION_NONE
var automatic_pending_region: StringName = FOLD_MODEL_SCRIPT.REGION_NONE
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
var _package_tween: Tween
var _fold_sweet_sauce_texture: Texture2D
var _fold_chili_sauce_texture: Texture2D
var _last_sauce_front_strip_count := 0
var _last_sauce_hidden_back_strip_count := 0
var _last_sauce_hidden_enclosed := false
var _cached_model_instance_id := 0
var _cached_model_revision := -1
var _cached_control_size := Vector2.ZERO
var _cached_geometry: Dictionary = {}
var _cached_source_profiles: Dictionary = {}
var _cached_fold_profiles: Dictionary = {}
var _geometry_scan_count := 0
var _source_profile_build_count := 0
var _fold_profile_build_count := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_fold_model(value: RefCounted) -> void:
	if fold_model != null and fold_model.changed.is_connected(_on_fold_changed):
		fold_model.changed.disconnect(_on_fold_changed)
	if _fold_tween != null and _fold_tween.is_running():
		_fold_tween.kill()
	if _package_tween != null and _package_tween.is_running():
		_package_tween.kill()
	_animated_region = FOLD_MODEL_SCRIPT.REGION_NONE
	_animated_progress = 0.0
	_settle_phase = 1.0
	fold_model = value
	_invalidate_fold_geometry_cache()
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


func set_hovered_region(value: StringName) -> void:
	if value == hovered_region:
		return
	hovered_region = value
	queue_redraw()


func set_automatic_pending_region(value: StringName) -> void:
	if value == automatic_pending_region:
		return
	automatic_pending_region = value
	queue_redraw()


func set_fold_sauce_textures(sweet_texture: Texture2D, chili_texture: Texture2D) -> void:
	_fold_sweet_sauce_texture = sweet_texture
	_fold_chili_sauce_texture = chili_texture
	queue_redraw()


func get_renderer_diagnostics() -> Dictionary:
	return {
		"fold_sweet_sauce_texture": _fold_sweet_sauce_texture,
		"fold_chili_sauce_texture": _fold_chili_sauce_texture,
		"sauce_front_strip_count": _last_sauce_front_strip_count,
		"sauce_hidden_back_strip_count": _last_sauce_hidden_back_strip_count,
		"sauce_hidden_enclosed": _last_sauce_hidden_enclosed,
		"geometry_scan_count": _geometry_scan_count,
		"source_profile_build_count": _source_profile_build_count,
		"fold_profile_build_count": _fold_profile_build_count,
	}


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
		if _package_tween != null and _package_tween.is_running():
			_package_tween.kill()
		if package_result == FOLD_MODEL_SCRIPT.PACKAGE_NONE:
			_package_reveal = 0.0
		else:
			_package_reveal = 0.0
			_package_tween = create_tween()
			_package_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_package_tween.tween_method(_set_package_reveal, 0.0, 1.0, PACKAGE_REVEAL_DURATION)
			_package_tween.finished.connect(_on_package_reveal_finished)
	queue_redraw()


func _start_fold_landing(region: StringName, from_progress: float) -> void:
	if _fold_tween != null and _fold_tween.is_running():
		_fold_tween.kill()
	_animated_region = region
	_animated_progress = clampf(from_progress, 0.0, 1.0)
	_settle_phase = 0.0
	var reduce_motion := _should_reduce_motion()
	var remaining_progress := 1.0 - _animated_progress
	var fold_result: Dictionary = fold_model.get_region_result(region) if fold_model != null else {}
	var maximum_duration: float = AUTOMATIC_FOLD_COMPLETION_DURATION if bool(fold_result.get("automatic", false)) else FOLD_COMPLETION_MAX_DURATION
	var completion_duration := 0.0 if is_zero_approx(remaining_progress) else lerpf(
		FOLD_COMPLETION_MIN_DURATION,
		maximum_duration,
		remaining_progress
	)
	if reduce_motion:
		completion_duration = minf(completion_duration, FOLD_COMPLETION_MIN_DURATION)
	_fold_tween = create_tween()
	_fold_tween.tween_method(_set_animated_progress, _animated_progress, 1.0, completion_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fold_tween.tween_callback(fold_completion_finished.emit)
	if reduce_motion:
		_fold_tween.tween_callback(_set_settle_phase.bind(1.0))
	else:
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
	fold_landing_finished.emit()


func is_fold_animation_active() -> bool:
	return _animated_region != FOLD_MODEL_SCRIPT.REGION_NONE


func _set_package_reveal(value: float) -> void:
	_package_reveal = clampf(value, 0.0, 1.0)
	queue_redraw()


func _on_package_reveal_finished() -> void:
	_package_reveal = 1.0
	queue_redraw()
	package_reveal_finished.emit()


func _draw() -> void:
	_last_sauce_front_strip_count = 0
	_last_sauce_hidden_back_strip_count = 0
	_last_sauce_hidden_enclosed = false
	if fold_model == null or fold_model.pancake_model == null:
		return
	if fold_model.package_result != FOLD_MODEL_SCRIPT.PACKAGE_NONE:
		# Packaging is a strict visual handoff: once the bag enters, none of the
		# folded-pancake artwork is drawn behind it.
		_draw_package()
		return
	# Whichever flap landed first remains visible until the opposite flap reaches
	# its tail. Each tail is clipped against that moving opposite outer edge.
	_draw_region(FOLD_MODEL_SCRIPT.REGION_LEFT, -INF, left_fold_clip_max_x())
	_draw_region(FOLD_MODEL_SCRIPT.REGION_RIGHT, right_fold_clip_min_x(), INF)
	# Keep threshold and hand-off feedback above the moving flap so the green
	# armed line and orange automatic target cannot disappear under the mesh.
	if guides_visible:
		_draw_guides()


func left_fold_clip_max_x() -> float:
	if fold_model == null or not fold_model.is_region_folded(FOLD_MODEL_SCRIPT.REGION_LEFT):
		return INF
	var right_progress := 0.0
	if fold_model.active_region == FOLD_MODEL_SCRIPT.REGION_RIGHT:
		right_progress = float(fold_model.drag_progress)
	elif _animated_region == FOLD_MODEL_SCRIPT.REGION_RIGHT:
		right_progress = _animated_progress
	elif fold_model.is_region_folded(FOLD_MODEL_SCRIPT.REGION_RIGHT):
		right_progress = 1.0
	else:
		return INF
	return right_fold_outer_edge_x(right_progress)


func right_fold_outer_edge_x(progress: float) -> float:
	return _fold_outer_edge_x(FOLD_MODEL_SCRIPT.REGION_RIGHT, progress, true)


func right_fold_clip_min_x() -> float:
	if fold_model == null or not fold_model.is_region_folded(FOLD_MODEL_SCRIPT.REGION_RIGHT):
		return -INF
	var left_progress := 0.0
	if fold_model.active_region == FOLD_MODEL_SCRIPT.REGION_LEFT:
		left_progress = float(fold_model.drag_progress)
	elif _animated_region == FOLD_MODEL_SCRIPT.REGION_LEFT:
		left_progress = _animated_progress
	elif fold_model.is_region_folded(FOLD_MODEL_SCRIPT.REGION_LEFT):
		left_progress = 1.0
	else:
		return -INF
	return left_fold_outer_edge_x(left_progress)


func left_fold_outer_edge_x(progress: float) -> float:
	return _fold_outer_edge_x(FOLD_MODEL_SCRIPT.REGION_LEFT, progress, false)


func _fold_outer_edge_x(region: StringName, progress: float, find_maximum: bool) -> float:
	if fold_model == null or fold_model.pancake_model == null:
		return INF if find_maximum else -INF
	var profile := _build_fold_profile(region, progress)
	if not bool(profile.get("has_coverage", false)):
		return INF if find_maximum else -INF
	var edge_x := -INF if find_maximum else INF
	for step in range(FOLD_PROFILE_STEPS + 1):
		var source_span := _source_fold_span(
			region,
			float(step) / float(FOLD_PROFILE_STEPS),
			profile
		)
		for point in source_span:
			var transformed_x := _transform_fold_point(point, progress, profile).x
			edge_x = maxf(edge_x, transformed_x) if find_maximum else minf(edge_x, transformed_x)
	return edge_x


func _draw_guides() -> void:
	var geometry := _pancake_geometry()
	if not bool(geometry.get("has_coverage", false)):
		return
	var left_x: float = size.x * float(fold_model.pancake_model.parameters.fold_left_line_ratio)
	var right_x: float = size.x * float(fold_model.pancake_model.parameters.fold_right_line_ratio)
	var left_span := _guide_span(left_x, geometry)
	var right_span := _guide_span(right_x, geometry)
	if not fold_model.is_region_folded(FOLD_MODEL_SCRIPT.REGION_LEFT):
		_draw_fold_line(FOLD_MODEL_SCRIPT.REGION_LEFT, left_x, left_span)
	if not fold_model.is_region_folded(FOLD_MODEL_SCRIPT.REGION_RIGHT):
		_draw_fold_line(FOLD_MODEL_SCRIPT.REGION_RIGHT, right_x, right_span)
	var center: Vector2 = geometry.center
	var radii: Vector2 = geometry.radii
	if not fold_model.is_region_folded(FOLD_MODEL_SCRIPT.REGION_LEFT):
		_draw_grab_affordance(FOLD_MODEL_SCRIPT.REGION_LEFT, center, radii)
	if not fold_model.is_region_folded(FOLD_MODEL_SCRIPT.REGION_RIGHT):
		_draw_grab_affordance(FOLD_MODEL_SCRIPT.REGION_RIGHT, center, radii)


func _draw_fold_line(region: StringName, line_x: float, span: Vector2) -> void:
	var active: bool = fold_model.active_region == region
	var armed: bool = active and bool(fold_model.crossed_fold_line)
	var automatic: bool = automatic_pending_region == region
	var color := Color(0.98, 0.91, 0.42, 0.90)
	var width := 4.0
	if armed:
		color = Color(0.42, 1.0, 0.60, 1.0)
		width = 8.0
	elif automatic:
		color = Color(1.0, 0.70, 0.24, 1.0)
		width = 6.0
	elif active:
		width = 6.0
	_draw_dashed_line(Vector2(line_x, span.x), Vector2(line_x, span.y), color, width)


func _draw_grab_affordance(region: StringName, center: Vector2, radii: Vector2) -> void:
	var left := region == FOLD_MODEL_SCRIPT.REGION_LEFT
	var anchor := center + Vector2((-1.0 if left else 1.0) * radii.x * 0.90, 0.0)
	var hovered: bool = hovered_region == region
	var automatic: bool = automatic_pending_region == region
	var color := Color(0.45, 0.94, 0.94, 0.98)
	if automatic:
		color = Color(1.0, 0.70, 0.24, 1.0)
	var radius := size.x * (0.060 if hovered or automatic else 0.052)
	var from_angle := -1.38 if left else PI - 1.38
	var to_angle := 1.38 if left else PI + 1.38
	var halo := color
	halo.a = 0.20
	draw_arc(anchor, radius, from_angle, to_angle, 28, halo, 20.0, true)
	draw_arc(anchor, radius, from_angle, to_angle, 28, color, 13.0 if hovered or automatic else 9.0, true)


func _draw_region(region: StringName, clip_min_x: float = -INF, clip_max_x: float = INF) -> void:
	var folded: bool = fold_model.is_region_folded(region)
	var active: bool = fold_model.active_region == region
	var animated: bool = _animated_region == region
	if not folded and not active and not animated:
		return
	var progress: float = _animated_progress if animated else (1.0 if folded else float(fold_model.drag_progress))
	var profile := _build_fold_profile(region, progress)
	if not bool(profile.get("has_coverage", false)):
		return
	var source_polygon := _segment_polygon(region, profile)
	var flap_polygon := _transform_polygon(source_polygon, progress, profile)
	var result: Dictionary = fold_model.get_region_result(region)
	var severity := int(result.get("severity", 0)) if folded else 0
	var flap_color := Color(1.0, 0.98, 0.91, 0.99)
	if severity == 1:
		flap_color = Color(0.92, 0.72, 0.48, 0.99)
	elif severity >= 2:
		flap_color = Color(0.76, 0.43, 0.31, 0.99)
	_draw_flap_shadow(flap_polygon, region, progress, profile, clip_min_x, clip_max_x)
	_draw_curved_flap(region, progress, flap_color, profile, clip_min_x, clip_max_x)
	if is_inf(clip_min_x) and is_inf(clip_max_x):
		_draw_arc_highlight(region, progress, profile)
	_draw_fold_crease(region, progress, severity)
	if not is_inf(clip_min_x) or not is_inf(clip_max_x):
		return
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
	profile: Dictionary,
	clip_min_x: float = -INF,
	clip_max_x: float = INF
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
		var clipped_shadow := _clip_polygon_horizontal(shadow_quad, PackedVector2Array(), PackedColorArray(), clip_min_x, clip_max_x)
		var clipped_shadow_points: PackedVector2Array = clipped_shadow.points
		if clipped_shadow_points.size() < 3:
			continue
		draw_colored_polygon(clipped_shadow_points, Color(0.13, 0.045, 0.012, alpha))


func _draw_curved_flap(
	region: StringName,
	progress: float,
	tint: Color,
	profile: Dictionary,
	clip_min_x: float = -INF,
	clip_max_x: float = INF
) -> void:
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
		var front_facing := cos(midpoint_angle) >= 0.0
		var texture := pancake_front_texture if front_facing else pancake_back_texture
		var clipped_surface := _clip_polygon_horizontal(folded_quad, uvs, colors, clip_min_x, clip_max_x)
		var clipped_points: PackedVector2Array = clipped_surface.points
		if clipped_points.size() < 3:
			continue
		var clipped_uvs: PackedVector2Array = clipped_surface.uvs
		var clipped_colors: PackedColorArray = clipped_surface.colors
		if texture == null:
			draw_colored_polygon(clipped_points, color0 * Color(0.93, 0.62, 0.23, 1.0))
		else:
			draw_polygon(clipped_points, clipped_colors, clipped_uvs, texture)
		var sauce_textures_available: bool = _fold_sweet_sauce_texture != null or _fold_chili_sauce_texture != null
		var enclosed: bool = fold_model.is_region_folded(FOLD_MODEL_SCRIPT.REGION_LEFT) and fold_model.is_region_folded(FOLD_MODEL_SCRIPT.REGION_RIGHT)
		var moving_interior_face: bool = (fold_model.active_region == region or _animated_region == region) and front_facing
		if enclosed:
			_last_sauce_hidden_enclosed = sauce_textures_available
		elif moving_interior_face and sauce_textures_available:
			# Sauce shares the same curved-strip lighting as the pancake beneath it.
			# A flat white modulation makes it read as a new opaque cover layer.
			var sauce_color0 := _fold_surface_color(Color.WHITE, angle0)
			var sauce_color1 := _fold_surface_color(Color.WHITE, angle1)
			var sauce_colors := PackedColorArray([sauce_color0, sauce_color1, sauce_color1, sauce_color0])
			if _fold_sweet_sauce_texture != null:
				draw_polygon(clipped_points, sauce_colors, clipped_uvs, _fold_sweet_sauce_texture)
			if _fold_chili_sauce_texture != null:
				draw_polygon(clipped_points, sauce_colors, clipped_uvs, _fold_chili_sauce_texture)
			_last_sauce_front_strip_count += 1
		elif sauce_textures_available:
			_last_sauce_hidden_back_strip_count += 1


func _clip_polygon_horizontal(
	points: PackedVector2Array,
	uvs: PackedVector2Array,
	colors: PackedColorArray,
	clip_min_x: float,
	clip_max_x: float
) -> Dictionary:
	var clipped := {"points": points, "uvs": uvs, "colors": colors}
	if not is_inf(clip_min_x):
		clipped = _clip_polygon_x(clipped.points, clipped.uvs, clipped.colors, clip_min_x, true)
	if not is_inf(clip_max_x):
		clipped = _clip_polygon_x(clipped.points, clipped.uvs, clipped.colors, clip_max_x, false)
	return clipped


func _clip_polygon_x(
	points: PackedVector2Array,
	uvs: PackedVector2Array,
	colors: PackedColorArray,
	clip_x: float,
	keep_greater: bool
) -> Dictionary:
	if points.is_empty():
		return {"points": points, "uvs": uvs, "colors": colors}
	var clipped_points := PackedVector2Array()
	var clipped_uvs := PackedVector2Array()
	var clipped_colors := PackedColorArray()
	for index in points.size():
		var previous_index := posmod(index - 1, points.size())
		var previous_point := points[previous_index]
		var current_point := points[index]
		var previous_inside := previous_point.x >= clip_x if keep_greater else previous_point.x <= clip_x
		var current_inside := current_point.x >= clip_x if keep_greater else current_point.x <= clip_x
		if previous_inside != current_inside:
			var denominator := current_point.x - previous_point.x
			var ratio := 0.0 if is_zero_approx(denominator) else clampf((clip_x - previous_point.x) / denominator, 0.0, 1.0)
			clipped_points.append(previous_point.lerp(current_point, ratio))
			if not uvs.is_empty():
				clipped_uvs.append(uvs[previous_index].lerp(uvs[index], ratio))
			if not colors.is_empty():
				clipped_colors.append(colors[previous_index].lerp(colors[index], ratio))
		if current_inside:
			clipped_points.append(current_point)
			if not uvs.is_empty():
				clipped_uvs.append(uvs[index])
			if not colors.is_empty():
				clipped_colors.append(colors[index])
	return {"points": clipped_points, "uvs": clipped_uvs, "colors": clipped_colors}


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


func _segment_polygon(region: StringName, profile: Dictionary) -> PackedVector2Array:
	var points := PackedVector2Array()
	# Trace the actual grid-derived upper edge outwards and the lower edge back
	# towards the crease. This keeps missing corners and hand-spread wobble in
	# the lifted silhouette instead of replacing them with an ideal ellipse.
	for column in range(FOLD_MESH_COLUMNS + 1):
		var distance_ratio := float(column) / float(FOLD_MESH_COLUMNS)
		points.append(_source_fold_span(region, distance_ratio, profile)[0])
	for column in range(FOLD_MESH_COLUMNS, -1, -1):
		var distance_ratio := float(column) / float(FOLD_MESH_COLUMNS)
		points.append(_source_fold_span(region, distance_ratio, profile)[1])
	return points


func _invalidate_fold_geometry_cache() -> void:
	_cached_model_instance_id = 0
	_cached_model_revision = -1
	_cached_control_size = Vector2.ZERO
	_cached_geometry.clear()
	_cached_source_profiles.clear()
	_cached_fold_profiles.clear()


func _ensure_fold_geometry_cache_current() -> void:
	if fold_model == null or fold_model.pancake_model == null:
		_invalidate_fold_geometry_cache()
		return
	var model: PancakeModel = fold_model.pancake_model
	var model_instance_id := int(model.get_instance_id())
	var model_revision := int(model.revision)
	if (
		model_instance_id == _cached_model_instance_id
		and model_revision == _cached_model_revision
		and size.is_equal_approx(_cached_control_size)
	):
		return
	_cached_model_instance_id = model_instance_id
	_cached_model_revision = model_revision
	_cached_control_size = size
	_cached_geometry.clear()
	_cached_source_profiles.clear()
	_cached_fold_profiles.clear()


func _pancake_geometry() -> Dictionary:
	_ensure_fold_geometry_cache_current()
	if not _cached_geometry.is_empty():
		return _cached_geometry
	var model: PancakeModel = fold_model.pancake_model
	var minimum := Vector2i(model.grid_size, model.grid_size)
	var maximum := Vector2i(-1, -1)
	_geometry_scan_count += 1
	for y in model.grid_size:
		for x in model.grid_size:
			var index: int = y * int(model.grid_size) + x
			if not _is_visible_pancake_cell(model, index):
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x:
		_cached_geometry = {
			"center": size * 0.5,
			"radii": Vector2.ZERO,
			"has_coverage": false,
		}
		return _cached_geometry
	var grid_extent := Vector2(maximum - minimum + Vector2i.ONE)
	var center_grid := Vector2(minimum + maximum) * 0.5 + Vector2(0.5, 0.5)
	var center_local := Vector2(center_grid.x / float(model.grid_size) * size.x, center_grid.y / float(model.grid_size) * size.y)
	var radii_local := Vector2(
		grid_extent.x / float(model.grid_size) * size.x,
		grid_extent.y / float(model.grid_size) * size.y
	) * 0.5
	_cached_geometry = {"center": center_local, "radii": radii_local, "has_coverage": true}
	return _cached_geometry


func _transform_polygon(source: PackedVector2Array, progress: float, profile: Dictionary) -> PackedVector2Array:
	var transformed := PackedVector2Array()
	for point in source:
		transformed.append(_transform_fold_point(point, progress, profile))
	return transformed


func get_fold_arc_profile(region: StringName, progress: float) -> PackedVector2Array:
	if fold_model == null or fold_model.pancake_model == null:
		return PackedVector2Array()
	var profile := _build_fold_profile(region, progress)
	if not bool(profile.get("has_coverage", false)):
		return PackedVector2Array()
	var points: PackedVector2Array = profile.points
	return points.duplicate()


func get_fold_source_span(region: StringName, distance_ratio: float) -> PackedVector2Array:
	if fold_model == null or fold_model.pancake_model == null:
		return PackedVector2Array()
	var profile := _build_fold_profile(region, 0.0)
	if not bool(profile.get("has_coverage", false)):
		return PackedVector2Array()
	return PackedVector2Array(_source_fold_span(region, distance_ratio, profile))


func _build_fold_profile(region: StringName, progress: float) -> Dictionary:
	_ensure_fold_geometry_cache_current()
	var line_ratio: float = fold_model.pancake_model.parameters.fold_left_line_ratio if region == FOLD_MODEL_SCRIPT.REGION_LEFT else fold_model.pancake_model.parameters.fold_right_line_ratio
	var clamped_progress := clampf(progress, 0.0, 1.0)
	var cached_profile := Dictionary(_cached_fold_profiles.get(region, {}))
	if (
		not cached_profile.is_empty()
		and is_equal_approx(float(cached_profile.get("line_ratio", -1.0)), line_ratio)
		and is_equal_approx(float(cached_profile.get("progress", -1.0)), clamped_progress)
	):
		return cached_profile
	var source_profile := _source_profile_for_region(region, line_ratio)
	var line_x: float = source_profile.line_x
	var center: Vector2 = source_profile.center
	var side: float = source_profile.side
	var flap_width: float = source_profile.flap_width
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
	var profile := source_profile.duplicate(false)
	profile["progress"] = clamped_progress
	profile["x_offsets"] = x_offsets
	profile["heights"] = heights
	profile["angles"] = angles
	profile["points"] = points
	_cached_fold_profiles[region] = profile
	_fold_profile_build_count += 1
	return profile


func _source_profile_for_region(region: StringName, line_ratio: float) -> Dictionary:
	_ensure_fold_geometry_cache_current()
	var cached_profile := Dictionary(_cached_source_profiles.get(region, {}))
	if (
		not cached_profile.is_empty()
		and is_equal_approx(float(cached_profile.get("line_ratio", -1.0)), line_ratio)
	):
		return cached_profile
	var line_x := size.x * line_ratio
	var geometry := _pancake_geometry()
	var center: Vector2 = geometry.center
	var radii: Vector2 = geometry.radii
	var side := -1.0 if region == FOLD_MODEL_SCRIPT.REGION_LEFT else 1.0
	var outer_x := center.x + side * radii.x
	var flap_width := maxf(absf(outer_x - line_x), 1.0)
	var source_tops := PackedFloat32Array()
	var source_bottoms := PackedFloat32Array()
	for step in range(FOLD_PROFILE_STEPS + 1):
		var source_ratio := float(step) / float(FOLD_PROFILE_STEPS)
		var source_x := line_x + side * flap_width * source_ratio
		var source_span := _coverage_span_at_x(source_x, region, geometry)
		source_tops.append(source_span.x)
		source_bottoms.append(source_span.y)
	# The simulation grid is intentionally coarse enough to be affordable. A
	# short weighted filter reproduces the shader's linear sampling at the rim,
	# while broad missing corners and hand-made asymmetry remain intact.
	source_tops = _smooth_contour(source_tops, 2)
	source_bottoms = _smooth_contour(source_bottoms, 2)
	var profile := {
		"region": region,
		"line_ratio": line_ratio,
		"has_coverage": bool(geometry.get("has_coverage", false)),
		"line_x": line_x,
		"center": center,
		"radii": radii,
		"side": side,
		"flap_width": flap_width,
		"source_tops": source_tops,
		"source_bottoms": source_bottoms,
	}
	_cached_source_profiles[region] = profile
	_source_profile_build_count += 1
	return profile


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
	var line_x: float = profile.line_x
	var side: float = profile.side
	var flap_width: float = profile.flap_width
	var ratio := clampf(distance_ratio, 0.0, 1.0)
	var x := line_x + side * flap_width * ratio
	var top := _profile_value(profile.source_tops, ratio)
	var bottom := _profile_value(profile.source_bottoms, ratio)
	return [Vector2(x, top), Vector2(x, bottom)]


func _coverage_span_at_x(local_x: float, region: StringName, geometry: Dictionary) -> Vector2:
	var center: Vector2 = geometry.center
	if not bool(geometry.get("has_coverage", false)):
		return Vector2(center.y, center.y)
	var model = fold_model.pancake_model
	var side := -1.0 if region == FOLD_MODEL_SCRIPT.REGION_LEFT else 1.0
	var sample_x := clampf(local_x - side * 0.01, 0.0, maxf(size.x - 0.01, 0.0))
	var grid_x := clampi(floori(sample_x / maxf(size.x, 1.0) * float(model.grid_size)), 0, model.grid_size - 1)
	var top_y: int = model.grid_size
	var bottom_y: int = -1
	for grid_y in model.grid_size:
		var index: int = grid_y * model.grid_size + grid_x
		if not _is_visible_pancake_cell(model, index):
			continue
		top_y = mini(top_y, grid_y)
		bottom_y = maxi(bottom_y, grid_y)
	if bottom_y < top_y:
		return Vector2(center.y, center.y)
	return Vector2(
		float(top_y) / float(model.grid_size) * size.y,
		float(bottom_y + 1) / float(model.grid_size) * size.y
	)


func _is_visible_pancake_cell(model: PancakeModel, index: int) -> bool:
	return model.coverage[index] > FOLD_VISIBLE_COVERAGE_MIN and model.damage[index] < FOLD_VISIBLE_DAMAGE_MAX


func _profile_value(values: PackedFloat32Array, distance_ratio: float) -> float:
	var cursor := clampf(distance_ratio, 0.0, 1.0) * float(FOLD_PROFILE_STEPS)
	var low := mini(int(floor(cursor)), FOLD_PROFILE_STEPS)
	var high := mini(low + 1, FOLD_PROFILE_STEPS)
	return lerpf(values[low], values[high], cursor - float(low))


func _profile_angle(profile: Dictionary, distance_ratio: float) -> float:
	var angles: PackedFloat32Array = profile.angles
	return _profile_value(angles, distance_ratio)


func _smooth_contour(values: PackedFloat32Array, passes: int) -> PackedFloat32Array:
	var smoothed := values.duplicate()
	for pass_index in maxi(passes, 0):
		var previous := smoothed
		smoothed = previous.duplicate()
		for index in range(1, previous.size() - 1):
			smoothed[index] = (
				previous[index - 1]
				+ previous[index] * 2.0
				+ previous[index + 1]
			) * 0.25
	return smoothed


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
	var left_distance := absf(line_x - size.x * float(fold_model.pancake_model.parameters.fold_left_line_ratio))
	var right_distance := absf(line_x - size.x * float(fold_model.pancake_model.parameters.fold_right_line_ratio))
	var region: StringName = FOLD_MODEL_SCRIPT.REGION_LEFT if left_distance <= right_distance else FOLD_MODEL_SCRIPT.REGION_RIGHT
	return _coverage_span_at_x(line_x, region, geometry)


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
	var eased_reveal := 1.0 - pow(1.0 - _package_reveal, 3.0)
	var reduce_motion := _should_reduce_motion()
	var reveal_scale := lerpf(0.96 if reduce_motion else 0.84, 1.0, eased_reveal)
	var side := minf(size.x, size.y) * 0.82 * reveal_scale
	var downward_entry := Vector2(0.0, lerpf(4.0 if reduce_motion else 24.0, 0.0, eased_reveal))
	var rect := Rect2(size * 0.5 - Vector2.ONE * side * 0.5 + downward_entry, Vector2.ONE * side)
	# Start fully opaque so the retired pancake state cannot show through while
	# the bag moves and scales into its resting position.
	draw_texture_rect(texture, rect, false, Color.WHITE)


func current_package_texture() -> Texture2D:
	var package_result: StringName = fold_model.package_result if fold_model != null else FOLD_MODEL_SCRIPT.PACKAGE_NONE
	return package_texture_for(package_result)


func package_texture_for(package_result: StringName) -> Texture2D:
	match package_result:
		FOLD_MODEL_SCRIPT.PACKAGE_BAG:
			return paper_bag_package_texture
		_:
			return null


func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float = 4.0) -> void:
	var length := from.distance_to(to)
	var direction := from.direction_to(to)
	var cursor := 0.0
	while cursor < length:
		var segment_end := minf(cursor + 14.0, length)
		draw_line(from + direction * cursor, from + direction * segment_end, color, width, true)
		cursor += 25.0


func _should_reduce_motion() -> bool:
	return DisplayServer.has_method(&"accessibility_should_reduce_motion") \
		and bool(DisplayServer.call(&"accessibility_should_reduce_motion"))


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if not result.is_empty():
		result.append(result[0])
	return result
