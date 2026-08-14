extends SceneTree

const STATION_SCENE := preload("res://scenes/gameplay/direct_youtiao_station.tscn")
const RECIPE_ID := &"recipe.youtiao.plain"
const AUTO_LIFT := &"automation.youtiao.auto_lift"
const TEMP_ASSIST := &"assist.youtiao.temperature_indicator"
const GENERATED_ASSETS := [
	["res://resources/art/workstation/expansion/machines/youtiao_fryer_tier_1_body_v2_chinese.png", Vector2i(1024, 512)],
	["res://resources/art/workstation/expansion/machines/youtiao_fryer_tier_1_lowered_v2_chinese.png", Vector2i(1024, 512)],
	["res://resources/art/workstation/expansion/machines/youtiao_fryer_tier_1_raised_v2_chinese.png", Vector2i(1024, 512)],
	["res://resources/art/workstation/expansion/machines/youtiao_fryer_tier_1_body_five_area_v4.png", Vector2i(1024, 512)],
	["res://resources/art/workstation/expansion/machines/youtiao_fryer_tier_1_basket_lowered_five_area_v4.png", Vector2i(1024, 512)],
	["res://resources/art/workstation/expansion/machines/youtiao_fryer_tier_1_basket_raised_five_area_v4.png", Vector2i(1024, 512)],
	["res://resources/art/workstation/expansion/machines/youtiao_fryer_tier_2_body_five_area_v4.png", Vector2i(1024, 512)],
	["res://resources/art/workstation/expansion/machines/youtiao_fryer_tier_2_basket_lowered_five_area_v4.png", Vector2i(1024, 512)],
	["res://resources/art/workstation/expansion/machines/youtiao_fryer_tier_2_basket_raised_five_area_v4.png", Vector2i(1024, 512)],
	["res://resources/art/workstation/expansion/machines/youtiao_fryer_tier_3_body_five_area_v4.png", Vector2i(1024, 512)],
	["res://resources/art/workstation/expansion/machines/youtiao_fryer_tier_3_basket_lowered_five_area_v4.png", Vector2i(1024, 512)],
	["res://resources/art/workstation/expansion/machines/youtiao_fryer_tier_3_basket_raised_five_area_v4.png", Vector2i(1024, 512)],
	["res://resources/art/workstation/expansion/machines/youtiao_auto_lift_arm_five_area_v4.png", Vector2i(1024, 512)],
	["res://resources/art/effects/youtiao/youtiao_sizzle_bubbles_five_area_v4.png", Vector2i(256, 256)],
	["res://resources/art/effects/youtiao/youtiao_oil_drips_five_area_v4.png", Vector2i(256, 256)],
]

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var station := STATION_SCENE.instantiate()
	root.add_child(station)
	await process_frame
	_check_assets(station)
	_check_tiers_and_recipes(station)
	_check_states(station)
	_check_automation_layers(station)
	station.call("_animate_start_feedback")
	await process_frame
	station.apply_visual_snapshot(_snapshot(0, &"idle"), _inventory())
	_check(station.machine_stage.scale.is_equal_approx(Vector2.ONE), "a newer business snapshot cancels and resets an in-flight presentation tween")
	station.queue_free()
	await process_frame
	_finish()


func _check_assets(station: Node) -> void:
	_check(station.body_textures.size() == 3 and station.lowered_basket_textures.size() == 3 and station.raised_basket_textures.size() == 3, "three tiers each wire a body, lowered basket, and raised basket")
	_check(station.body_textures[1] != station.body_textures[0] and station.lowered_basket_textures[1] != station.lowered_basket_textures[0] and station.raised_basket_textures[1] != station.raised_basket_textures[0], "intermediate fryer owns dedicated body, lowered-basket, and raised-basket art")
	_check(station.body_textures[1].resource_path.ends_with("youtiao_fryer_tier_1_body_v2_chinese.png") and station.lowered_basket_textures[1].resource_path.ends_with("youtiao_fryer_tier_1_lowered_v2_chinese.png") and station.raised_basket_textures[1].resource_path.ends_with("youtiao_fryer_tier_1_raised_v2_chinese.png"), "intermediate fryer binds the new Chinese-style three-state set")
	_check(station.raw_food_textures.size() == 1 and station.cooked_food_textures.size() == 1, "the formal fryer binds only the oil-strip raw and cooked textures")
	_check(station.auto_lift_texture != null and station.sizzle_texture != null and station.oil_drips_texture != null, "auto-lift and loop effects are scene-bound")
	for entry in GENERATED_ASSETS:
		var path := String(entry[0])
		var expected_size := Vector2i(entry[1])
		_check(ResourceLoader.exists(path), "%s imports as a Godot resource" % path)
		var texture := load(path) as Texture2D
		_check(texture != null and Vector2i(texture.get_width(), texture.get_height()) == expected_size, "%s keeps its registered dimensions" % path)
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		_check(not image.is_empty() and image.get_format() in [Image.FORMAT_RGBA8, Image.FORMAT_RGBAF, Image.FORMAT_RGBAH], "%s decodes as RGBA" % path)
		if image.is_empty():
			continue
		for corner in [Vector2i.ZERO, Vector2i(image.get_width() - 1, 0), Vector2i(0, image.get_height() - 1), image.get_size() - Vector2i.ONE]:
			_check(image.get_pixelv(corner).a <= 0.02, "%s has a transparent canvas corner" % path)


func _check_tiers_and_recipes(station: Node) -> void:
	for tier in range(3):
		var capacity: int = [4, 6, 8][tier]
		station.apply_visual_snapshot(_snapshot(tier, &"loaded", RECIPE_ID, capacity), _inventory())
		_check(station.body_visual.texture == station.body_textures[tier], "tier %d selects its own modular body" % [tier + 1])
		_check(station.lowered_basket_visual.texture == station.lowered_basket_textures[tier], "tier %d selects its own lowered basket" % [tier + 1])
		_check(station.lowered_basket_front_visual.texture == station.lowered_basket_visual.texture and is_equal_approx(station.lowered_basket_front_clip.position.y, DirectYoutiaoStation._front_clip_top(tier, false)), "tier %d reuses the exact lowered basket pixels for its front occluder" % [tier + 1])
		_check(_visible_food_count(station) == capacity, "tier %d renders its %d-serving physical capacity" % [tier + 1, capacity])
		_check_food_layout(station, tier, false)
		station.apply_visual_snapshot(_snapshot(tier, &"ready_to_collect", RECIPE_ID, capacity), _inventory())
		_check_food_layout(station, tier, true)
	station.apply_visual_snapshot(_snapshot(0, &"loaded", RECIPE_ID, 1), _inventory())
	_check(station.raw_food_visuals[0].texture == station.raw_food_textures[0], "loaded oil strip uses its dough texture")
	station.apply_visual_snapshot(_snapshot(0, &"ready_safe", RECIPE_ID, 1), _inventory())
	_check(station.cooked_food_visuals[0].texture == station.cooked_food_textures[0], "ready oil strip uses its cooked texture")


func _check_states(station: Node) -> void:
	station.apply_visual_snapshot(_snapshot(0, &"idle"), _inventory())
	_check(station.lowered_basket_visual.visible and station.lowered_basket_front_clip.visible and not station.raised_basket_visual.visible and not station.raised_basket_front_clip.visible and _visible_food_count(station) == 0, "idle shows an empty lowered basket with its matching front occluder")
	station.apply_visual_snapshot(_snapshot(0, &"loaded", RECIPE_ID, 4), _inventory())
	_check(_visible_food_count(station) == 4 and station.raw_food_visuals[0].modulate.a > 0.99 and station.cooked_food_visuals[0].modulate.a < 0.01, "loaded shows four raw portions in the basic basket")
	station.apply_visual_snapshot(_snapshot(0, &"frying", RECIPE_ID, 4, 5.0), _inventory())
	_check(station.sizzle_layer.visible and station.raw_food_visuals[0].modulate.a > 0.1 and station.cooked_food_visuals[0].modulate.a > 0.1, "frying crossfades raw to cooked while staggered bubbles loop")
	station.apply_visual_snapshot(_snapshot(0, &"ready_safe", RECIPE_ID, 4), _inventory())
	_check(not station.lift_button.disabled and station.cooked_food_visuals[0].modulate.a > 0.99, "ready-safe gives a strong lift affordance with cooked food")
	station.apply_visual_snapshot(_snapshot(0, &"overcooking", RECIPE_ID, 4, 10.0, 8.0, 72.0), _inventory())
	_check(station.cooked_food_visuals[0].modulate.g < 0.8, "overcooking darkens the product according to quality")
	station.apply_visual_snapshot(_snapshot(0, &"burnt", RECIPE_ID, 4, 10.0, 15.0, 0.0), _inventory())
	_check(station.burnt_smoke_visual.visible and station.lift_button.disabled and not station.output_sources[0].disabled and not station.output_sources[3].disabled and StringName(station.output_sources[0].source_ref().get("source_kind", &"")) == &"youtiao_batch", "burnt content exposes one whole-batch waste action from every visible strip")
	_check(station.get_node_or_null("DiscardBatchButton") == null, "youtiao station no longer exposes a whole-batch discard button")
	station.apply_visual_snapshot(_snapshot(0, &"draining", RECIPE_ID, 4), _inventory())
	_check(station.raised_basket_visual.visible and station.raised_basket_front_clip.visible and not station.lowered_basket_visual.visible and not station.lowered_basket_front_clip.visible and station.raised_basket_front_visual.texture == station.raised_basket_visual.texture and station.oil_drips_visual.visible, "draining raises food between the exact raised-basket base and front pixels while oil drips loop")
	station.apply_visual_snapshot(_snapshot(0, &"ready_to_collect", RECIPE_ID, 4), _inventory())
	_check(station.raised_basket_visual.visible and not station.output_sources[0].disabled and not station.output_sources[3].disabled and _visible_food_count(station) == 4, "ready-to-collect keeps the high basket and whole-batch drag sources")
	var hole_snapshot := _snapshot(0, &"ready_to_collect", RECIPE_ID, 1)
	hole_snapshot["occupied_slot_indices"] = [1]
	station.apply_visual_snapshot(hole_snapshot, _inventory())
	_check(not station.food_slots[0].visible and station.food_slots[1].visible, "a partial collection snapshot keeps the right slot in place")
	station.apply_visual_snapshot(_snapshot(0, &"idle"), _inventory())
	_check(_visible_food_count(station) == 0 and station.lowered_basket_visual.visible, "the final collection snapshot restores the empty low basket")


func _check_automation_layers(station: Node) -> void:
	station.apply_visual_snapshot(_snapshot(0, &"idle"), _inventory())
	_check(not station.auto_lift_visual.visible and not station.auto_lift_toggle.visible, "unowned auto-lift stays hidden")
	station.apply_visual_snapshot(_snapshot(0, &"idle", &"", 0, 0.0, 0.0, 100.0, [AUTO_LIFT], [], false), _inventory())
	_check(station.auto_lift_visual.visible and station.auto_lift_toggle.visible and not station.auto_lift_toggle.button_pressed and station.auto_lift_visual.modulate.r < 0.5, "owned auto-lift can remain visibly disabled")
	station.apply_visual_snapshot(_snapshot(0, &"idle", &"", 0, 0.0, 0.0, 100.0, [AUTO_LIFT], [], true), _inventory())
	_check(station.auto_lift_toggle.button_pressed and station.auto_lift_visual.modulate.r > 0.99, "enabled auto-lift exposes its active toggle and arm")
	station.apply_visual_snapshot(_snapshot(2, &"idle", &"", 0, 0.0, 0.0, 100.0, [AUTO_LIFT], [TEMP_ASSIST], true), _inventory())
	_check(station.temperature_range_bar.visible, "the purchased oil-temperature assist uses its code-drawn range bar")


func _snapshot(tier: int, state: StringName, recipe_id: StringName = &"", quantity: int = 0, cooking: float = 0.0, completed: float = 0.0, quality: float = 100.0, automations: Array = [], assists: Array = [], auto_lift_enabled: bool = false) -> Dictionary:
	return {
		"owned": true,
		"tier": tier,
		"capacity": [4, 6, 8][tier],
		"state": state,
		"recipe_id": recipe_id,
		"quantity": quantity,
		"cooking_elapsed_seconds": cooking,
		"completed_elapsed_seconds": completed,
		"draining_elapsed_seconds": 0.0,
		"quality": quality,
		"unlocked_recipe_ids": [RECIPE_ID],
		"unlocked_automation_ids": automations,
		"owned_assist_ids": assists,
		"auto_lift_enabled": auto_lift_enabled,
	}


static func _inventory() -> Dictionary:
	return {
		"stock.youtiao.plain_dough": 8,
	}


static func _visible_food_count(station: Node) -> int:
	return station.food_slots.filter(func(slot: Control): return slot.visible).size()


func _check_food_layout(station: Node, tier: int, raised: bool) -> void:
	var capacity: int = [4, 6, 8][tier]
	var rects := DirectYoutiaoStation._food_rects(tier, raised)
	var basket_bounds := Rect2(118.0, 20.0, 112.0, 65.0)
	var row_positions: Array[float] = []
	for index in range(capacity):
		var rect := rects[index] as Rect2
		_check(basket_bounds.has_point(rect.position) and basket_bounds.has_point(rect.end - Vector2(0.01, 0.01)), "tier %d %s slot %d stays inside the physical basket bounds" % [tier + 1, "raised" if raised else "lowered", index + 1])
		for other_index in range(index):
			_check(not rect.intersects(rects[other_index]), "tier %d %s slots %d and %d do not overlap" % [tier + 1, "raised" if raised else "lowered", other_index + 1, index + 1])
		if not row_positions.any(func(value: float): return is_equal_approx(value, rect.position.y)):
			row_positions.append(rect.position.y)
		var slot := station.food_slots[index] as Control
		var global_center: Vector2 = slot.get_global_transform_with_canvas() * (slot.size * 0.5)
		var stage_center: Vector2 = station.machine_stage.get_global_transform_with_canvas().affine_inverse() * global_center
		_check(stage_center.distance_to(rect.get_center()) < 0.25, "tier %d %s slot %d converts from basket space without scale offset" % [tier + 1, "raised" if raised else "lowered", index + 1])
	_check(row_positions.size() == 2, "tier %d %s capacity uses a two-row basket grid" % [tier + 1, "raised" if raised else "lowered"])


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("YOUTIAO_STATION_VISUAL_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("YOUTIAO_STATION_VISUAL_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
