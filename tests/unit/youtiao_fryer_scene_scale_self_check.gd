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
	&"dual_both_raised": [Vector2(5.0, 126.0), Vector2(128.0, 126.0)],
	&"dual_left_lowered": [Vector2(3.0, 168.0), Vector2(127.0, 126.0)],
	&"dual_right_lowered": [Vector2(-1.0, 126.0), Vector2(133.0, 168.0)],
	&"dual_both_lowered": [Vector2(3.0, 168.0), Vector2(133.0, 168.0)],
}

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var fryer := FRYER_SCENE.instantiate() as CartoonYoutiaoFryerToggle
	root.add_child(fryer)
	_check(fryer.fryer_assembly.position == Vector2(80.0, -10.0), "the fryer assembly is authored fifty pixels farther right")
	_check(fryer.basket_products.scale == Vector2(0.5, 0.5) and fryer.chicken_basket_products.scale == Vector2(0.5, 0.5) and fryer.chicken_slot_sources.all(func(source: ProductDragSource) -> bool: return source.scale == Vector2(0.8, 0.8)), "both filter-basket food groups fit inside their authored wells at one effective scale")
	_check(fryer.plain_tray.size == Vector2(219.0, 170.0) and fryer.chicken_tray.size == Vector2(219.0, 170.0) and fryer.plain_tray.scale == fryer.chicken_tray.scale, "the two finished-product trays share one size and scale")
	for layout_name in LAYOUT_NAMES:
		var animation := fryer.fryer_layout_player.get_animation(layout_name)
		var scale_track := animation.find_track(NodePath(".:scale"), Animation.TYPE_VALUE) if animation != null else -1
		_check(scale_track >= 0, "%s authors the shared fryer-assembly scale" % layout_name)
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
