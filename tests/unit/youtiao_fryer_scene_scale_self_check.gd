extends SceneTree

const FRYER_SCENE := preload("res://scenes/gameplay/cartoon_youtiao_fryer_toggle.tscn")
const LAYOUT_NAMES: Array[StringName] = [
	&"basic_raised",
	&"basic_lowered",
	&"advanced_raised",
	&"advanced_lowered",
	&"dual_both_raised",
	&"dual_left_lowered",
	&"dual_right_lowered",
	&"dual_both_lowered",
]
const DUAL_BASKET_POSITIONS := {
	&"dual_both_raised": [Vector2(5.0, 148.0), Vector2(128.0, 148.0)],
	&"dual_left_lowered": [Vector2(3.0, 184.0), Vector2(127.0, 148.0)],
	&"dual_right_lowered": [Vector2(-1.0, 148.0), Vector2(133.0, 184.0)],
	&"dual_both_lowered": [Vector2(3.0, 184.0), Vector2(133.0, 184.0)],
}
const LEFT_BASKET_SCALES := {
	&"basic_raised": Vector2(0.65, 0.65),
	&"basic_lowered": Vector2(0.65, 0.65),
	&"advanced_raised": Vector2(0.5, 0.5),
	&"advanced_lowered": Vector2(0.5, 0.5),
	&"dual_both_raised": Vector2(0.5, 0.5),
	&"dual_left_lowered": Vector2(0.5, 0.5),
	&"dual_right_lowered": Vector2(0.5, 0.5),
	&"dual_both_lowered": Vector2(0.5, 0.5),
}

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var fryer := FRYER_SCENE.instantiate() as CartoonYoutiaoFryerToggle
	root.add_child(fryer)
	_check(fryer.fryer_assembly.position == Vector2(80.0, -10.0), "the fryer assembly is authored fifty pixels farther right")
	_check(fryer.basket_products.scale == Vector2(0.65, 0.65) and fryer.chicken_basket_products.scale == Vector2(0.5, 0.5) and fryer.chicken_slot_sources.all(func(source: ProductDragSource) -> bool: return source.scale == Vector2(0.8, 0.8)), "the active basic youtiao group uses its enlarged scale while the chicken group keeps the original dual-fryer scale")
	_check(fryer.plain_tray.size == Vector2(235.0, 185.0) and fryer.chicken_tray.size == Vector2(235.0, 185.0) and fryer.plain_tray.scale == Vector2(1.2, 1.2) and fryer.plain_tray.scale == fryer.chicken_tray.scale, "the two finished-product trays share one enlarged size and scale")
	_check(fryer.plain_tray.position.is_equal_approx(Vector2(3.0, 420.0)) and fryer.chicken_tray.position.is_equal_approx(Vector2(232.0, 420.0)), "the two finished-product trays preserve their current authored positions")
	_check(fryer.plain_tray.slot_origin == Vector2(48.0, 43.0) and fryer.plain_tray.slot_step == Vector2(34.0, 0.0) and fryer.plain_tray.slot_size == Vector2(34.0, 79.0) and fryer.plain_tray.slot_columns == 4, "the finished youtiao row moves eight units left and eight units up")
	_check(fryer.chicken_tray.slot_origin == Vector2(70.0, 45.0) and fryer.chicken_tray.slot_step == Vector2(48.0, 24.0) and fryer.chicken_tray.slot_size == Vector2(47.5, 47.5) and fryer.chicken_tray.slot_columns == 2, "the four finished chicken portions use a vertically tightened authored two-by-two grid")
	var expected_chicken_positions := [Vector2(70.0, 45.0), Vector2(118.0, 45.0), Vector2(70.0, 69.0), Vector2(118.0, 69.0)]
	for source_index in range(fryer.chicken_tray.product_sources.size()):
		_check(fryer.chicken_tray.product_sources[source_index].position == expected_chicken_positions[source_index], "chicken tray slot %d stays in its two-by-two grid cell" % source_index)
	for tray: YoutiaoTrayView in [fryer.plain_tray, fryer.chicken_tray]:
		for source in tray.product_sources:
			var source_rect := source.get_rect()
			_check(source_rect.position.x >= 0.0 and source_rect.position.y >= 0.0 and source_rect.end.x <= tray.size.x and source_rect.end.y <= tray.size.y, "%s keeps every authored product slot inside the tray" % tray.name)
	for layout_name in LAYOUT_NAMES:
		var animation := fryer.fryer_layout_player.get_animation(layout_name)
		var scale_track := animation.find_track(NodePath(".:scale"), Animation.TYPE_VALUE) if animation != null else -1
		var basket_scale_track := animation.find_track(NodePath("LeftBasket:scale"), Animation.TYPE_VALUE) if animation != null else -1
		_check(scale_track >= 0, "%s authors the shared fryer-assembly scale" % layout_name)
		_check(basket_scale_track >= 0 and animation.track_get_key_value(basket_scale_track, 0) == LEFT_BASKET_SCALES[layout_name], "%s owns its tier-isolated left-basket scale" % layout_name)
		if scale_track >= 0:
			var expected_scale := Vector2(1.5, 1.5) if layout_name.begins_with("dual_") else Vector2(1.1, 1.1)
			_check(animation.track_get_key_count(scale_track) == 1 and animation.track_get_key_value(scale_track, 0) == expected_scale, "%s preserves its authored tier scale" % layout_name)
		if DUAL_BASKET_POSITIONS.has(layout_name):
			var expected_positions: Array = DUAL_BASKET_POSITIONS[layout_name]
			var left_track := animation.find_track(NodePath("LeftBasket:position"), Animation.TYPE_VALUE)
			var right_track := animation.find_track(NodePath("RightBasket:position"), Animation.TYPE_VALUE)
			_check(left_track >= 0 and animation.track_get_key_value(left_track, 0) == expected_positions[0], "%s keeps oil strips centered in the left basket" % layout_name)
			_check(right_track >= 0 and animation.track_get_key_value(right_track, 0) == expected_positions[1], "%s keeps chicken cutlets centered in the right basket" % layout_name)

	fryer.call("_apply_fryer_layout", true, false, true, false)
	_check(fryer.fryer_assembly.scale == Vector2(1.5, 1.5), "the authored dual layout scales the complete dual-fryer assembly to 1.5")
	fryer.call("_apply_fryer_layout", false, false, false, false)
	_check(fryer.fryer_assembly.scale == Vector2(1.1, 1.1), "returning to a basic layout restores its independent authored scale")

	var transfer_texture := GradientTexture2D.new()
	for source in fryer.fryer_slot_sources:
		source.texture_normal = transfer_texture
		source.visible = false
	# Sparse slots are possible after individual drag delivery. The transfer must
	# animate the two visible products, not assume that occupied indices are dense.
	fryer.fryer_slot_sources[1].visible = true
	fryer.fryer_slot_sources[3].visible = true
	fryer.call("_play_batch_to_finished_tray", false, 2, 0)
	var transfer_ghosts := fryer.get_children().filter(func(child: Node) -> bool: return child.has_meta(&"spatial_flight_effect"))
	_check(transfer_ghosts.size() == 2, "two sparse ready oil strips receive two staggered filter-to-tray flights")
	var first_transfer_position := (transfer_ghosts[0] as Control).position if not transfer_ghosts.is_empty() else Vector2.ZERO
	await create_timer(0.38).timeout
	await process_frame
	_check(
		not transfer_ghosts.is_empty()
		and is_instance_valid(transfer_ghosts[0])
		and (transfer_ghosts[0] as Control).position.distance_to(first_transfer_position) > 8.0,
		"the first oil strip is visibly in flight before the staggered transfer finishes",
	)
	await create_timer(0.58).timeout
	_check(fryer.get_children().all(func(child: Node) -> bool: return not child.has_meta(&"spatial_flight_effect")), "all filter-to-tray transfer ghosts clean themselves up")

	fryer.queue_free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("YOUTIAO_FRYER_SCENE_SCALE_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("YOUTIAO_FRYER_SCENE_SCALE_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
