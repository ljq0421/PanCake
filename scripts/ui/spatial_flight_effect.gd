class_name SpatialFlightEffect
extends RefCounted

## A short, non-blocking spatial handoff used when business state changes
## immediately but the player still needs to see where the product went.
const FLIGHT_SECONDS := 0.72
const REDUCED_FADE_SECONDS := 0.16
const MIN_ARC_HEIGHT := 28.0
const MAX_ARC_HEIGHT := 84.0
const ARC_DISTANCE_RATIO := 0.16
const END_SIZE_RATIO := 0.72
const FADE_START_PROGRESS := 0.72
const PANCAKE_PACKAGE_INGREDIENT_GRID := preload("res://scripts/ui/pancake_package_ingredient_grid.gd")


static func play(
	parent: Control,
	texture: Texture2D,
	source_canvas_rect: Rect2,
	target_canvas_rect: Rect2,
	delay_seconds: float = 0.0,
	reduce_motion: bool = false,
	z_index: int = 250,
	pancake_product: Dictionary = {},
	preserve_source_size: bool = false
) -> Tween:
	if parent == null or texture == null:
		return null
	var parent_inverse := parent.get_global_transform_with_canvas().affine_inverse()
	var source_center := parent_inverse * source_canvas_rect.get_center()
	var target_center := parent_inverse * target_canvas_rect.get_center()
	var start_size := source_canvas_rect.size if preserve_source_size else _sanitized_size(source_canvas_rect.size)
	var target_size := _sanitized_size(target_canvas_rect.size)
	var end_size := start_size if preserve_source_size else _fit_end_size(start_size, target_size)
	var ghost := TextureRect.new()
	ghost.name = "SpatialFlightGhost"
	ghost.set_meta(&"spatial_flight_effect", true)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.texture = texture
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost.z_index = z_index
	ghost.size = start_size
	ghost.position = source_center - start_size * 0.5
	parent.add_child(ghost)
	if not pancake_product.is_empty():
		var ingredient_grid := PANCAKE_PACKAGE_INGREDIENT_GRID.new()
		ingredient_grid.name = "PancakePackageIngredientGrid"
		ingredient_grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 0)
		ingredient_grid.z_index = 1
		ingredient_grid.configure(pancake_product)
		ghost.add_child(ingredient_grid)

	var tween := parent.create_tween()
	if delay_seconds > 0.0:
		tween.tween_interval(delay_seconds)
	if reduce_motion:
		tween.tween_property(ghost, "modulate:a", 0.0, REDUCED_FADE_SECONDS).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	else:
		var distance := source_center.distance_to(target_center)
		var arc_height := clampf(distance * ARC_DISTANCE_RATIO, MIN_ARC_HEIGHT, MAX_ARC_HEIGHT)
		var control_point := source_center.lerp(target_center, 0.5) - Vector2(0.0, arc_height)
		var update_flight := func(progress: float) -> void:
			if not is_instance_valid(ghost):
				return
			var one_minus := 1.0 - progress
			var center := one_minus * one_minus * source_center \
				+ 2.0 * one_minus * progress * control_point \
				+ progress * progress * target_center
			var current_size := start_size.lerp(end_size, progress)
			ghost.size = current_size
			ghost.position = center - current_size * 0.5
			ghost.modulate.a = 1.0 if progress <= FADE_START_PROGRESS else lerpf(
				1.0,
				0.18,
				(progress - FADE_START_PROGRESS) / (1.0 - FADE_START_PROGRESS)
			)
		tween.tween_method(update_flight, 0.0, 1.0, FLIGHT_SECONDS).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(ghost.queue_free)
	return tween


static func canvas_rect(control: Control) -> Rect2:
	if control == null:
		return Rect2()
	var transform := control.get_global_transform_with_canvas()
	var top_left := transform * Vector2.ZERO
	var bottom_right := transform * control.size
	return Rect2(top_left, bottom_right - top_left).abs()


static func _sanitized_size(value: Vector2) -> Vector2:
	return Vector2(clampf(value.x, 28.0, 132.0), clampf(value.y, 28.0, 132.0))


static func _fit_end_size(start_size: Vector2, target_size: Vector2) -> Vector2:
	var maximum := target_size * 0.82
	var desired := start_size * END_SIZE_RATIO
	var ratio := minf(maximum.x / desired.x, maximum.y / desired.y)
	return desired * minf(ratio, 1.0)
