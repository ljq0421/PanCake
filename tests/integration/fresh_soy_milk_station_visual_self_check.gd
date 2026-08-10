extends SceneTree

const SOY_SCENE := preload("res://scenes/gameplay/fresh_soy_milk_station.tscn")
const RECIPE_IDS := [
	&"recipe.fresh_soy_milk.yellow_bean",
	&"recipe.fresh_soy_milk.black_bean",
	&"recipe.fresh_soy_milk.red_bean",
	&"recipe.fresh_soy_milk.multigrain",
]
const AUTO_RACK := &"automation.fresh_soy_milk.auto_cup_rack"

const GENERATED_ASSETS := [
	["res://resources/art/workstation/expansion/machines/soy_milk_machine_tier_1_body_v3.png", Vector2i(1024, 512)],
	["res://resources/art/workstation/expansion/machines/soy_milk_machine_tier_1_lid_closed_v3.png", Vector2i(1024, 512)],
	["res://resources/art/workstation/expansion/machines/soy_milk_machine_tier_1_lid_open_v3.png", Vector2i(1024, 512)],
	["res://resources/art/workstation/expansion/machines/soy_milk_machine_tier_2_body_v3.png", Vector2i(1024, 512)],
	["res://resources/art/workstation/expansion/machines/soy_milk_machine_tier_2_lid_closed_v3.png", Vector2i(1024, 512)],
	["res://resources/art/workstation/expansion/machines/soy_milk_machine_tier_2_lid_open_v3.png", Vector2i(1024, 512)],
	["res://resources/art/workstation/expansion/machines/soy_milk_machine_tier_3_body_v3.png", Vector2i(1024, 512)],
	["res://resources/art/workstation/expansion/machines/soy_milk_machine_tier_3_lid_closed_v3.png", Vector2i(1024, 512)],
	["res://resources/art/workstation/expansion/machines/soy_milk_machine_tier_3_lid_open_v3.png", Vector2i(1024, 512)],
	["res://resources/art/products/soy_milk/soy_milk_cup_empty_v3.png", Vector2i(256, 256)],
	["res://resources/art/products/soy_milk/soy_milk_cup_yellow_bean_v3.png", Vector2i(256, 256)],
	["res://resources/art/products/soy_milk/soy_milk_cup_black_bean_v3.png", Vector2i(256, 256)],
	["res://resources/art/products/soy_milk/soy_milk_cup_red_bean_v3.png", Vector2i(256, 256)],
	["res://resources/art/products/soy_milk/soy_milk_cup_multigrain_v3.png", Vector2i(256, 256)],
	["res://resources/art/workstation/expansion/machines/soy_milk_auto_cup_rack_empty_v3.png", Vector2i(1024, 512)],
	["res://resources/art/effects/soy_milk/soy_milk_water_pour_v3.png", Vector2i(256, 256)],
	["res://resources/art/effects/soy_milk/soy_milk_liquid_stream_v3.png", Vector2i(256, 256)],
	["res://resources/art/effects/soy_milk/soy_milk_spoiled_vapor_v3.png", Vector2i(256, 256)],
]

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var view := SOY_SCENE.instantiate()
	root.add_child(view)
	view.size = Vector2(430, 270)
	view.set_locked(false)
	view.set_interaction_enabled(true)
	await process_frame
	_check_assets(view)
	_check_tiers_and_states(view)
	await _check_intents_and_click_guard(view)
	view.queue_free()
	await process_frame
	_finish()


func _check_assets(view: Node) -> void:
	_check(view.body_textures.size() == 3, "three soy machine bodies are wired")
	_check(view.closed_lid_textures.size() == 3 and view.open_lid_textures.size() == 3, "three closed and open soy lids are wired")
	_check(view.ingredient_textures.size() == 4 and view.cup_textures.size() == 5, "four ingredients and five reusable cups are wired")
	_check(view.auto_rack_texture != null and view.water_texture != null and view.stream_texture != null and view.spoiled_vapor_texture != null, "rack and action effects are wired")
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
		for corner in [Vector2i.ZERO, Vector2i(image.get_width() - 1, 0), Vector2i(0, image.get_height() - 1), image.get_size() - Vector2i.ONE]:
			_check(image.get_pixelv(corner).a <= 0.02, "%s has transparent canvas corners" % path)


func _check_tiers_and_states(view: Node) -> void:
	for tier in range(3):
		view.apply_snapshot(_snapshot(tier, &"idle"))
		_check(view.machine_rig.visible and view.body_visual.visible, "tier %d renders its modular machine body" % [tier + 1])
		_check(view.closed_lid_visual.visible and not view.open_lid_visual.visible, "tier %d idle state uses the closed lid" % [tier + 1])
		var visible_cups: int = view.machine_cups.filter(func(cup: TextureRect): return cup.visible).size()
		_check(visible_cups == (4 if tier == 2 else 1), "tier %d shows its physical empty cup positions" % [tier + 1])

	view.apply_snapshot(_snapshot(0, &"loaded", &"recipe.fresh_soy_milk.black_bean", 1))
	_check(view.open_lid_visual.visible and not view.closed_lid_visual.visible, "loaded state keeps the hopper visibly open")
	_check(view.ingredient_visual.visible and view.ingredient_visual.texture == view.ingredient_textures[1], "loaded state identifies the selected bean material")
	view.apply_snapshot(_snapshot(0, &"water_added", &"recipe.fresh_soy_milk.black_bean", 1))
	_check(view.closed_lid_visual.visible and not view.ingredient_visual.visible, "water-added state closes the lid without adding a business state")
	view.apply_snapshot(_snapshot(0, &"ready_safe", &"recipe.fresh_soy_milk.red_bean", 2))
	_check(view.machine_cups[0].texture == view.cup_textures[3] and view.steam_effect.visible, "ready state shows the matching filled cup and hot steam")
	_check(view.quantity_label.visible and view.quantity_label.text == "×2", "single serving bay preserves batch quantity readability")
	view.apply_snapshot(_snapshot(0, &"spoiled", &"recipe.fresh_soy_milk.yellow_bean", 1))
	_check(view.spoiled_vapor.visible and not view.steam_effect.visible, "spoiled state replaces fresh steam with sour vapor")

	var full_rack := [
		_rack_cup(&"recipe.fresh_soy_milk.yellow_bean"),
		_rack_cup(&"recipe.fresh_soy_milk.black_bean"),
		_rack_cup(&"recipe.fresh_soy_milk.red_bean"),
		_rack_cup(&"recipe.fresh_soy_milk.multigrain"),
	]
	view.apply_snapshot(_snapshot(2, &"blocked", &"recipe.fresh_soy_milk.multigrain", 4, [AUTO_RACK], full_rack))
	_check(view.rack_panel.visible and not view.rack_missing_label.visible, "auto rack is visible only when installed")
	_check(view.output_buttons.all(func(button: Button): return button.icon != null), "blocked rack visibly contains all four cups")
	_check(view.rack_visual.modulate.r > view.rack_visual.modulate.g, "blocked rack uses its red alert treatment")
	view.apply_snapshot(_snapshot(2, &"idle"))
	_check(not view.rack_panel.visible and view.rack_missing_label.visible, "equipment tier does not silently include the automation rack")


func _check_intents_and_click_guard(view: Node) -> void:
	var intents: Array[Dictionary] = []
	view.intent_requested.connect(func(intent: Dictionary): intents.append(intent.duplicate(true)))
	view.apply_snapshot(_snapshot(0, &"idle"))
	view.load_button.pressed.emit()
	view.load_button.pressed.emit()
	_check(bool(view.get("_animation_busy")), "load feedback raises the double-click guard immediately")
	await create_timer(0.58).timeout
	_check(intents.size() == 1 and StringName(intents[0].get("action_id", &"")) == &"load", "rapid double-click emits one load intent after open-and-load feedback")
	view.apply_snapshot(_snapshot(0, &"loaded", &"recipe.fresh_soy_milk.yellow_bean", 1))
	view.water_button.pressed.emit()
	await create_timer(0.55).timeout
	_check(intents.size() == 2 and StringName(intents[1].get("action_id", &"")) == &"add_water", "water feedback emits add_water without inventing a lid state")
	view.apply_snapshot(_snapshot(0, &"water_added", &"recipe.fresh_soy_milk.yellow_bean", 1))
	view.start_button.pressed.emit()
	await create_timer(0.48).timeout
	_check(intents.size() == 3 and StringName(intents[2].get("action_id", &"")) == &"start", "start feedback emits the existing start intent")
	view.apply_snapshot(_snapshot(0, &"ready_safe", &"recipe.fresh_soy_milk.yellow_bean", 1))
	view.collect_button.pressed.emit()
	await create_timer(0.40).timeout
	_check(intents.size() == 4 and StringName(intents[3].get("action_id", &"")) == &"collect", "filled cup exits and emits collect")
	view.apply_snapshot(_snapshot(0, &"idle"))
	view.load_button.pressed.emit()
	await create_timer(0.05).timeout
	view.apply_snapshot(_snapshot(0, &"ready_safe", &"recipe.fresh_soy_milk.red_bean", 1))
	_check(not bool(view.get("_animation_busy")), "a newer soy snapshot cancels the in-flight presentation immediately")
	_check(view.closed_lid_visual.visible and not view.open_lid_visual.visible and view.machine_cups[0].texture == view.cup_textures[3], "cancelled soy feedback converges to the newest final state")
	await create_timer(0.55).timeout
	_check(intents.size() == 4, "cancelled soy feedback cannot emit a stale intent")


func _snapshot(tier: int, state: StringName, recipe_id: StringName = &"", quantity: int = 0, automations: Array = [], rack: Array = [{}, {}, {}, {}]) -> Dictionary:
	return {
		"owned": true,
		"tier": tier,
		"capacity": [2, 2, 4][tier],
		"state": state,
		"recipe_id": recipe_id,
		"quantity": quantity,
		"quality": 100.0 if state != &"spoiled" else 0.0,
		"output_rack": rack,
		"unlocked_recipe_ids": RECIPE_IDS,
		"unlocked_automation_ids": automations,
	}


func _rack_cup(recipe_id: StringName) -> Dictionary:
	return {"recipe_id": recipe_id, "state": &"ready_safe", "quality": 100.0}


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("FRESH_SOY_MILK_STATION_VISUAL_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("FRESH_SOY_MILK_STATION_VISUAL_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
