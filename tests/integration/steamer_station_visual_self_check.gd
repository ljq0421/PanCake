extends SceneTree

const STEAMER_SCENE := preload("res://scenes/gameplay/steamer_station.tscn")

const GENERATED_ASSETS := [
	["res://resources/art/workstation/expansion/machines/steamer_tier_1_base_body_five_area_v3.png", Vector2i(1024, 512)],
	["res://resources/art/workstation/expansion/machines/steamer_tier_1_basket_layer_five_area_v3.png", Vector2i(1024, 512)],
	["res://resources/art/workstation/expansion/machines/steamer_tier_1_lid_closed_five_area_v3.png", Vector2i(1024, 512)],
	["res://resources/art/workstation/expansion/machines/steamer_tier_1_lid_open_five_area_v3.png", Vector2i(1024, 512)],
	["res://resources/art/workstation/expansion/machines/steamer_tier_2_base_body_five_area_v3.png", Vector2i(1024, 512)],
	["res://resources/art/workstation/expansion/machines/steamer_tier_2_basket_layer_five_area_v3.png", Vector2i(1024, 512)],
	["res://resources/art/workstation/expansion/machines/steamer_tier_2_lid_closed_five_area_v3.png", Vector2i(1024, 512)],
	["res://resources/art/workstation/expansion/machines/steamer_tier_2_lid_open_five_area_v3.png", Vector2i(1024, 512)],
	["res://resources/art/workstation/expansion/machines/steamer_tier_3_base_body_five_area_v3.png", Vector2i(1024, 512)],
	["res://resources/art/workstation/expansion/machines/steamer_tier_3_basket_layer_five_area_v3.png", Vector2i(1024, 512)],
	["res://resources/art/workstation/expansion/machines/steamer_tier_3_lid_closed_five_area_v3.png", Vector2i(1024, 512)],
	["res://resources/art/workstation/expansion/machines/steamer_tier_3_lid_open_five_area_v3.png", Vector2i(1024, 512)],
	["res://resources/art/products/steamer/mantou_overcooked_five_area_v2.png", Vector2i(256, 256)],
	["res://resources/art/products/steamer/vegetable_bun_overcooked_five_area_v2.png", Vector2i(256, 256)],
	["res://resources/art/products/steamer/meat_bun_overcooked_five_area_v2.png", Vector2i(256, 256)],
	["res://resources/art/effects/steamer/steamer_steam_puff_five_area_v2.png", Vector2i(256, 256)],
	["res://resources/art/effects/steamer/steamer_burnt_smoke_puff_five_area_v2.png", Vector2i(256, 256)],
]

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var view := STEAMER_SCENE.instantiate()
	root.add_child(view)
	await process_frame
	if view.get_script() == null:
		_check(false, "steamer station script loads without parse errors")
		view.queue_free()
		_finish()
		return
	_check_assets(view)
	_check_tier_layouts(view)
	_check_state_visuals(view)
	await _check_intents_and_click_guard(view)
	view.queue_free()
	await process_frame
	_finish()


func _check_assets(view: Node) -> void:
	_check(view.base_textures.size() == 3, "three steamer bases are wired")
	_check(view.basket_textures.size() == 3, "three reusable baskets are wired")
	_check(view.closed_lid_textures.size() == 3, "three closed lids are wired")
	_check(view.open_lid_textures.size() == 3, "three open lids are wired")
	_check(view.overcooked_food_textures.size() == 3, "three overcooked foods are wired")
	_check(view.steam_texture != null and view.smoke_texture != null, "steam and burnt-smoke textures are wired")
	for entry in GENERATED_ASSETS:
		var path := String(entry[0])
		var expected_size := Vector2i(entry[1])
		_check(ResourceLoader.exists(path), "%s imports as a Godot resource" % path)
		var texture := load(path) as Texture2D
		_check(texture != null, "%s resolves to Texture2D" % path)
		if texture != null:
			_check(Vector2i(texture.get_width(), texture.get_height()) == expected_size, "%s keeps expected dimensions" % path)
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		_check(not image.is_empty(), "%s can be decoded" % path)
		if image.is_empty():
			continue
		var corners := [Vector2i.ZERO, Vector2i(image.get_width() - 1, 0), Vector2i(0, image.get_height() - 1), image.get_size() - Vector2i.ONE]
		for corner in corners:
			_check(image.get_pixelv(corner).a <= 0.02, "%s has transparent canvas corners" % path)


func _check_tier_layouts(view: Node) -> void:
	for tier in range(3):
		var capacity: int = [1, 2, 4][tier]
		view.apply_snapshot(_snapshot(tier, _empty_layers(capacity)))
		var visible_layers := 0
		for visual in view.layer_visuals:
			visible_layers += 1 if visual.visible else 0
		_check(visible_layers == capacity, "tier %d renders %d independent layers" % [tier + 1, capacity])
		var visible_hit_regions: int = view.layer_hit_buttons.filter(func(button: Button): return button.visible).size()
		_check(visible_hit_regions == capacity, "tier %d exposes one direct click region per visible basket" % [tier + 1])
		_check(view.base_visual.visible and view.closed_lid_visual.visible, "tier %d renders a modular base and lid" % [tier + 1])
		_check(not view.machine_stage.clip_contents or _visible_components_fit_stage(view), "tier %d closed composition stays inside 430x250 station" % [tier + 1])


func _check_state_visuals(view: Node) -> void:
	var layers := [
		_layer(&"loaded", &"recipe.steamer.mantou", 100.0),
		_layer(&"steaming", &"recipe.steamer.vegetable_bun", 100.0, 4.0, 10.0),
		_layer(&"ready_safe", &"recipe.steamer.meat_bun", 100.0, 8.0, 8.0),
		_layer(&"overcooking", &"recipe.steamer.mantou", 65.0, 8.0, 8.0),
	]
	view.apply_snapshot(_snapshot(2, layers))
	for index in range(4):
		_check(view.layer_foods[index].visible, "active layer %d shows its food" % [index + 1])
	_check(not view.progress_rings[0].visible, "loaded layer does not show a cooking progress ring")
	_check(view.progress_rings[1].visible and is_equal_approx(float(view.progress_rings[1].get("progress_value")), 40.0), "steaming layer shows elapsed progress")
	_check(view.progress_rings[2].visible and is_equal_approx(float(view.progress_rings[2].get("progress_value")), 100.0), "ready layer shows completed progress")
	_check(view.progress_rings[3].visible and is_equal_approx(float(view.progress_rings[3].get("progress_value")), 65.0), "overcooking layer shows remaining quality")
	_check(view.steam_puffs[0].visible and view.steam_puffs[1].visible and not view.steam_puffs[2].visible, "overcooking uses its distinct two-puff steam profile")
	_check(view.layer_foods[3].texture == view.cooked_food_textures[0], "overcooking keeps the mature food as its blend base")
	_check(view.layer_overcooked_foods[3].visible and is_equal_approx(view.layer_overcooked_foods[3].modulate.a, 0.875), "overcooking continuously blends toward the terminal art from quality")
	view.apply_snapshot(_snapshot(2, [_layer(&"spoiled", &"recipe.steamer.meat_bun", 0.0), _layer(&"empty"), _layer(&"empty"), _layer(&"empty")]))
	_check(view.smoke_puff.visible, "spoiled state shows burnt smoke")
	_check(view.layer_overcooked_foods[0].visible and is_equal_approx(view.layer_overcooked_foods[0].modulate.a, 1.0), "spoiled state fully covers the mature base with overcooked food")


func _check_intents_and_click_guard(view: Node) -> void:
	var intents: Array[Dictionary] = []
	view.intent_requested.connect(func(intent: Dictionary): intents.append(intent.duplicate(true)))
	view.set_locked(false)
	view.set_interaction_enabled(true)
	view.apply_snapshot(_snapshot(0, [_layer(&"empty")]))
	view.layer_hit_buttons[0].pressed.emit()
	view.layer_hit_buttons[0].pressed.emit()
	_check(bool(view.get("_animation_busy")), "load animation raises the click guard immediately")
	await create_timer(0.80).timeout
	_check(intents.size() == 1 and StringName(intents[0].get("action_id", &"")) == &"load", "rapid double-click emits one load intent")
	_check(not bool(view.get("_animation_busy")), "click guard clears after the 0.66 second presentation sequence")
	view.apply_snapshot(_snapshot(0, [_layer(&"loaded", &"recipe.steamer.mantou")]))
	view.call("_request_layer_intent", 0)
	_check(intents.size() == 2 and StringName(intents[1].get("action_id", &"")) == &"start", "loaded layer starts without inventing an open business state")
	view.apply_snapshot(_snapshot(0, [_layer(&"ready_safe", &"recipe.steamer.mantou")]))
	view.call("_request_layer_intent", 0)
	await create_timer(0.90).timeout
	_check(intents.size() == 3 and StringName(intents[2].get("action_id", &"")) == &"collect", "ready food opens, exits, and emits collect")
	view.apply_snapshot(_snapshot(0, [_layer(&"spoiled", &"recipe.steamer.mantou", 0.0)]))
	view.call("_request_layer_intent", 0)
	await create_timer(0.90).timeout
	_check(intents.size() == 4 and StringName(intents[3].get("action_id", &"")) == &"discard", "spoiled food opens, exits toward waste, and emits discard")
	view.apply_snapshot(_snapshot(0, [_layer(&"empty")]))
	view.layer_hit_buttons[0].pressed.emit()
	await create_timer(0.05).timeout
	view.apply_snapshot(_snapshot(0, [_layer(&"ready_safe", &"recipe.steamer.vegetable_bun")]))
	_check(not bool(view.get("_animation_busy")), "a newer steamer snapshot cancels the expanded presentation immediately")
	_check(view.closed_lid_visual.visible and not view.open_lid_visual.visible and not view.action_food.visible, "cancelled steamer feedback converges to the newest stacked state")
	await create_timer(0.80).timeout
	_check(intents.size() == 4, "cancelled steamer feedback cannot emit a stale intent")


func _visible_components_fit_stage(view: Node) -> bool:
	var stage_rect := Rect2(Vector2.ZERO, view.machine_stage.size)
	var subject_rects: Array[Rect2] = [view.call("_base_rect"), view.call("_closed_lid_rect")]
	for index in range(int(view.call("_layer_capacity"))):
		subject_rects.append(view.call("_layer_rect", index))
	for subject_rect in subject_rects:
		if not stage_rect.encloses(subject_rect):
			return false
	return true


func _snapshot(tier: int, layers: Array) -> Dictionary:
	return {
		"owned": true,
		"tier": tier,
		"layer_capacity": [1, 2, 4][tier],
		"layers": layers,
		"unlocked_recipe_ids": [&"recipe.steamer.mantou", &"recipe.steamer.vegetable_bun", &"recipe.steamer.meat_bun"],
	}


func _empty_layers(capacity: int) -> Array:
	var layers: Array = []
	for index in range(4):
		layers.append(_layer(&"empty" if index < capacity else &"locked"))
	return layers


func _layer(state: StringName, recipe_id: StringName = &"", quality: float = 100.0, elapsed: float = 0.0, duration: float = 8.0) -> Dictionary:
	return {
		"state": state,
		"recipe_id": recipe_id,
		"quantity": 0 if state in [&"empty", &"locked"] else 1,
		"quality": quality,
		"elapsed_seconds": elapsed,
		"duration_seconds": duration,
		"completed_elapsed_seconds": 0.0,
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("STEAMER_STATION_VISUAL_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("STEAMER_STATION_VISUAL_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
