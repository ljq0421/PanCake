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
const SINGLE_BASKET_STATION_OFFSET := Vector2(180.0, 0.0)
const POSITIONED_SINGLE_BASKET_STATES: Array[StringName] = [
	&"loaded", &"frying", &"ready_safe", &"burnt", &"ready_to_collect",
]

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var fryer := FRYER_SCENE.instantiate() as CartoonYoutiaoFryerToggle
	root.add_child(fryer)
	fryer.single_basket_station_offset = SINGLE_BASKET_STATION_OFFSET
	fryer.call("_ensure_visual_resources")
	var authored_station_position := fryer.position
	for tier in [0, 1]:
		for state in POSITIONED_SINGLE_BASKET_STATES:
			fryer._machine = {
				"tier": tier,
				"state": state,
				"capacity": 2,
				"quantity": 2,
				"occupied_slot_indices": [0, 1],
			}
			fryer.call("_apply_snapshot")
			_check(fryer.position.is_equal_approx(authored_station_position + SINGLE_BASKET_STATION_OFFSET), "tier %d keeps the complete %s fryer state shifted right with its root" % [tier, state])
			_check(fryer.fryer_assembly.position == Vector2(80.0, -10.0) and fryer.youtiao_progress_label.position.is_equal_approx(Vector2(30.0, 10.0)), "tier %d %s leaves internal cooker and progress layouts untouched" % [tier, state])
	fryer._machine = {"tier": 2, "state": &"ready_to_collect", "capacity": 4, "quantity": 2, "occupied_slot_indices": [0, 1]}
	fryer.call("_apply_snapshot")
	_check(fryer.position.is_equal_approx(authored_station_position), "tier 2 dual-basket fryer retains its authored station position")
	fryer._machine = {"tier": 0, "state": &"idle", "capacity": 2, "quantity": 0, "occupied_slot_indices": []}
	fryer.call("_apply_snapshot")
	_check(fryer.fryer_assembly.position == Vector2(80.0, -10.0), "the fryer assembly is authored fifty pixels farther right")
	_check(fryer.basket_products.scale == Vector2(0.65, 0.65) and fryer.chicken_basket_products.scale == Vector2(0.5, 0.5) and fryer.chicken_slot_sources.all(func(source: ProductDragSource) -> bool: return source.scale == Vector2(0.8, 0.8)), "the active basic youtiao group uses its enlarged scale while the chicken group keeps the original dual-fryer scale")
	_check(fryer.shared_tray != null and fryer.shared_tray.source_capacity == 16, "one shared 2x8 finished-product tray replaces the two separate plates")
	_check(fryer.shared_tray.product_sources.size() == 16, "shared tray creates sixteen reusable product sources")
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
