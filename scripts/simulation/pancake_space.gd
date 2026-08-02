class_name PancakeSpace
extends RefCounted


static func local_to_grid(local_position: Vector2, view_size: Vector2, grid_size: int) -> Vector2i:
	if grid_size <= 0 or view_size.x <= 0.0 or view_size.y <= 0.0:
		return Vector2i(-1, -1)
	var normalized := local_position / view_size
	var cell := Vector2i(floori(normalized.x * grid_size), floori(normalized.y * grid_size))
	return Vector2i(clampi(cell.x, 0, grid_size - 1), clampi(cell.y, 0, grid_size - 1))


static func local_to_grid_position(local_position: Vector2, view_size: Vector2, grid_size: int) -> Vector2:
	if grid_size <= 0 or view_size.x <= 0.0 or view_size.y <= 0.0:
		return Vector2(-1.0, -1.0)
	var normalized := local_position / view_size
	return Vector2(
		clampf(normalized.x * float(grid_size), 0.0, float(grid_size - 1)),
		clampf(normalized.y * float(grid_size), 0.0, float(grid_size - 1))
	)


static func grid_to_local(cell: Vector2i, view_size: Vector2, grid_size: int) -> Vector2:
	if grid_size <= 0:
		return Vector2.ZERO
	return (Vector2(cell) + Vector2(0.5, 0.5)) / float(grid_size) * view_size


static func is_inside_pan(local_position: Vector2, view_size: Vector2, height_ratio: float, radius_scale: float = 1.0) -> bool:
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return false
	var center := view_size * 0.5
	var safe_height_ratio := clampf(height_ratio, 0.01, 1.0)
	var safe_radius_scale := maxf(radius_scale, 0.001)
	var radii := Vector2(view_size.x * 0.5, view_size.y * 0.5 * safe_height_ratio) * safe_radius_scale
	var normalized := (local_position - center) / radii
	return normalized.length_squared() <= 1.0
