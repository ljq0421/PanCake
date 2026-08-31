extends SceneTree

const EFFECT := preload("res://scripts/ui/spatial_flight_effect.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var host := Control.new()
	host.size = Vector2(800.0, 600.0)
	root.add_child(host)
	await process_frame
	var texture := GradientTexture2D.new()
	var source := Rect2(80.0, 420.0, 72.0, 96.0)
	var target := Rect2(610.0, 120.0, 64.0, 64.0)
	var tween := EFFECT.play(host, texture, source, target)
	var ghost := host.get_node_or_null("SpatialFlightGhost") as TextureRect
	_check(tween != null and ghost != null, "a spatial handoff creates one non-blocking visual ghost")
	var initial_position := ghost.position if ghost != null else Vector2.ZERO
	await create_timer(0.36).timeout
	await process_frame
	_check(
		ghost != null and is_instance_valid(ghost) and ghost.position.distance_to(initial_position) > 8.0,
		"the normal-motion ghost follows a continuous spatial path toward the destination",
	)
	await create_timer(0.42).timeout
	_check(host.get_node_or_null("SpatialFlightGhost") == null, "the normal-motion ghost cleans itself up after the 720ms handoff")
	var pancake := {"ingredient_ids": [&"stock.pancake.egg", &"stock.pancake.baocui"], "sauce_ids": [&"stock.pancake.sauce.sweet_flour"]}
	var pancake_source := Rect2(80.0, 420.0, 176.0, 176.0)
	EFFECT.play(host, texture, pancake_source, target, 0.0, false, 250, pancake, true)
	var pancake_ghost := host.get_node_or_null("SpatialFlightGhost") as TextureRect
	_check(pancake_ghost != null and pancake_ghost.size.is_equal_approx(pancake_source.size) and pancake_ghost.get_node_or_null("PancakePackageIngredientGrid") is PancakePackageIngredientGrid, "pancake handoff preserves its source size and carries the checked ingredient grid")
	await create_timer(0.36).timeout
	_check(pancake_ghost != null and is_instance_valid(pancake_ghost) and pancake_ghost.size.is_equal_approx(pancake_source.size), "pancake handoff never shrinks while crossing the delivery arc")
	await create_timer(0.42).timeout
	_check(host.get_node_or_null("SpatialFlightGhost") == null, "the full-size pancake handoff also cleans itself up")

	EFFECT.play(host, texture, source, target, 0.0, true)
	var reduced_ghost := host.get_node_or_null("SpatialFlightGhost") as TextureRect
	var reduced_position := reduced_ghost.position if reduced_ghost != null else Vector2.ZERO
	await create_timer(0.08).timeout
	_check(
		reduced_ghost != null and is_instance_valid(reduced_ghost) and reduced_ghost.position == reduced_position and reduced_ghost.modulate.a < 1.0,
		"reduced motion keeps the product stationary and uses opacity-only feedback",
	)
	await create_timer(0.12).timeout
	_check(host.get_node_or_null("SpatialFlightGhost") == null, "the reduced-motion ghost also cleans itself up")
	host.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("SPATIAL_FLIGHT_EFFECT_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("SPATIAL_FLIGHT_EFFECT_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
