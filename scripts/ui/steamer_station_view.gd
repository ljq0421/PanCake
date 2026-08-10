class_name SteamerStationView
extends "res://scripts/ui/five_area_station_view.gd"

const RECIPE_IDS: Array[StringName] = [
	&"recipe.steamer.mantou",
	&"recipe.steamer.vegetable_bun",
	&"recipe.steamer.meat_bun",
]

const OPEN_SECONDS := 0.22
const FOOD_SECONDS := 0.22
const CLOSE_SECONDS := 0.22
const MAX_LAYERS := 4

## Alpha-subject bounds inside the generated 1024x512 component canvases.
## Keeping this registration data here lets the scene place independently
## generated parts without destructively repacking the source PNGs.
const BASE_BOUNDS := [
	Rect2(238, 200, 549, 300),
	Rect2(283, 220, 458, 280),
	Rect2(255, 250, 514, 250),
]
const BASKET_BOUNDS := [
	Rect2(326, 205, 373, 210),
	Rect2(379, 205, 266, 200),
	Rect2(328, 230, 369, 180),
]
const CLOSED_LID_BOUNDS := [
	Rect2(340, 115, 344, 150),
	Rect2(350, 108, 323, 145),
	Rect2(342, 108, 341, 145),
]
const OPEN_LID_BOUNDS := [
	Rect2(272, 70, 479, 280),
	Rect2(278, 70, 467, 270),
	Rect2(308, 65, 408, 280),
]

const STATE_COLORS := {
	&"locked": Color("79736d"),
	&"empty": Color("f0d5a4"),
	&"loaded": Color("f4c95d"),
	&"steaming": Color("8ed6eb"),
	&"ready_safe": Color("8bd17c"),
	&"overcooking": Color("ff9f43"),
	&"spoiled": Color("a76a5b"),
}

@export var closed_machine_textures: Array[Texture2D] = []
@export var base_textures: Array[Texture2D] = []
@export var basket_textures: Array[Texture2D] = []
@export var closed_lid_textures: Array[Texture2D] = []
@export var open_lid_textures: Array[Texture2D] = []
@export var loaded_food_textures: Array[Texture2D] = []
@export var cooked_food_textures: Array[Texture2D] = []
@export var overcooked_food_textures: Array[Texture2D] = []
@export var steam_texture: Texture2D
@export var smoke_texture: Texture2D

@onready var state_label: Label = %StateLabel
@onready var recipe_buttons: Array[Button] = [%MantouButton, %VegetableBunButton, %MeatBunButton]
@onready var layer_buttons: Array[Button] = [%Layer01, %Layer02, %Layer03, %Layer04]
@onready var machine_stage: Control = %MachineStage
@onready var closed_machine: TextureRect = %ClosedMachine
@onready var base_visual: TextureRect = %BaseVisual
@onready var layer_visuals: Array[TextureRect] = [%LayerVisual01, %LayerVisual02, %LayerVisual03, %LayerVisual04]
@onready var layer_foods: Array[TextureRect] = [%LayerFood01, %LayerFood02, %LayerFood03, %LayerFood04]
@onready var layer_overcooked_foods: Array[TextureRect] = [%LayerOvercookedFood01, %LayerOvercookedFood02, %LayerOvercookedFood03, %LayerOvercookedFood04]
@onready var progress_rings: Array[Control] = [%LayerProgress01, %LayerProgress02, %LayerProgress03, %LayerProgress04]
@onready var layer_hit_buttons: Array[Button] = [%LayerHit01, %LayerHit02, %LayerHit03, %LayerHit04]
@onready var closed_lid_visual: TextureRect = %ClosedLidVisual
@onready var open_lid_visual: TextureRect = %OpenLidVisual
@onready var action_food: TextureRect = %ActionFood
@onready var action_overcooked_food: TextureRect = %ActionOvercookedFood
@onready var steam_puffs: Array[TextureRect] = [%SteamPuff01, %SteamPuff02, %SteamPuff03]
@onready var smoke_puff: TextureRect = %SmokePuff
@onready var busy_label: Label = %BusyLabel

var _selected_recipe_id: StringName = RECIPE_IDS[0]
var _animation_busy := false
var _visual_time := 0.0
var _steam_motion_speed := 1.8
var _feedback_serial := 0
var _visual_tweens: Array[Tween] = []
var _layer_subject_rects: Array[Rect2] = []


func _ready() -> void:
	for index in range(recipe_buttons.size()):
		recipe_buttons[index].pressed.connect(func(recipe_index := index): _select_recipe(recipe_index))
	for index in range(layer_buttons.size()):
		layer_buttons[index].pressed.connect(func(layer_index := index): _request_layer_intent(layer_index))
		layer_hit_buttons[index].pressed.connect(func(layer_index := index): _request_layer_intent(layer_index))
	for puff in steam_puffs:
		puff.texture = steam_texture
	smoke_puff.texture = smoke_texture
	_refresh_from_snapshot()


func _process(delta: float) -> void:
	_visual_time += maxf(delta, 0.0)
	_animate_state_effects()


func _select_recipe(index: int) -> void:
	if index < 0 or index >= RECIPE_IDS.size() or recipe_buttons[index].disabled:
		return
	_selected_recipe_id = RECIPE_IDS[index]
	_refresh_from_snapshot()


func apply_snapshot(snapshot: Dictionary) -> void:
	_cancel_visual_feedback()
	super.apply_snapshot(snapshot)


func _request_layer_intent(layer_index: int) -> void:
	if _animation_busy or layer_index < 0 or layer_index >= MAX_LAYERS:
		return
	var layers := Array(_snapshot.get("layers", []))
	var layer := Dictionary(layers[layer_index]) if layer_index < layers.size() else {}
	var state := StringName(layer.get("state", &"locked"))
	match state:
		&"empty":
			_play_layer_action(layer_index, &"load", _selected_recipe_id)
		&"loaded":
			request_intent(&"start", {"layer_index": layer_index})
			_play_start_feedback(layer_index)
		&"ready_safe", &"overcooking":
			_play_layer_action(layer_index, &"collect", StringName(layer.get("recipe_id", &"")))
		&"spoiled":
			_play_layer_action(layer_index, &"discard", StringName(layer.get("recipe_id", &"")))


func _play_layer_action(layer_index: int, action_id: StringName, recipe_id: StringName) -> void:
	_cancel_visual_feedback()
	_feedback_serial += 1
	var serial := _feedback_serial
	_animation_busy = true
	busy_label.visible = true
	_refresh_controls()
	var layers := Array(_snapshot.get("layers", []))
	var layer := Dictionary(layers[layer_index]) if layer_index < layers.size() else {}
	var state := StringName(layer.get("state", &"empty"))
	var quality := float(layer.get("quality", 100.0))
	_prepare_action_food(recipe_id, state, quality, layer_index)
	await _animate_open(layer_index)
	if not _feedback_is_current(serial):
		return
	if action_id == &"load":
		await _animate_food_into_tray(layer_index)
		if not _feedback_is_current(serial):
			return
		request_intent(&"load", {"layer_index": layer_index, "recipe_id": recipe_id, "quantity": 1})
		if not _feedback_is_current(serial):
			return
	else:
		action_food.visible = true
		if state in [&"overcooking", &"spoiled"]:
			action_overcooked_food.visible = true
		await get_tree().create_timer(0.10).timeout
		if not _feedback_is_current(serial):
			return
		await _animate_food_out(action_id)
		if not _feedback_is_current(serial):
			return
		request_intent(action_id, {"layer_index": layer_index})
		if not _feedback_is_current(serial):
			return
	await _animate_close()
	if not _feedback_is_current(serial):
		return
	_visual_tweens.clear()
	_animation_busy = false
	busy_label.visible = false
	_refresh_from_snapshot()


func _play_start_feedback(layer_index: int) -> void:
	if layer_index < 0 or layer_index >= layer_visuals.size():
		return
	var visual := layer_visuals[layer_index]
	var tween := _new_visual_tween()
	tween.tween_property(visual, "modulate", Color("fff1a8"), 0.10)
	tween.tween_property(visual, "modulate", Color.WHITE, 0.16)


func _prepare_action_food(recipe_id: StringName, state: StringName, quality: float, layer_index: int) -> void:
	var recipe_index := RECIPE_IDS.find(recipe_id)
	if recipe_index < 0:
		recipe_index = 0
	action_food.texture = loaded_food_textures[recipe_index] if state in [&"empty", &"loaded"] else cooked_food_textures[recipe_index]
	action_overcooked_food.texture = overcooked_food_textures[recipe_index]
	action_food.modulate = Color.WHITE
	action_overcooked_food.modulate = Color(1, 1, 1, clampf((100.0 - quality) / 40.0, 0.0, 1.0))
	action_food.visible = false
	action_overcooked_food.visible = false
	var target := _action_food_target(layer_index)
	action_food.position = target
	action_overcooked_food.position = target


func _animate_open(layer_index: int) -> void:
	closed_machine.visible = false
	base_visual.visible = true
	for index in range(layer_visuals.size()):
		layer_visuals[index].visible = index < _layer_capacity()
	var selected := layer_visuals[layer_index]
	selected.z_index = 30
	var tween := _new_visual_tween().set_parallel(true)
	tween.tween_property(selected, "position", selected.position + Vector2(0, 24), OPEN_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for index in range(layer_index + 1, _layer_capacity()):
		tween.tween_property(layer_visuals[index], "position", layer_visuals[index].position + Vector2(0, -9), OPEN_SECONDS)
	if layer_index == _layer_capacity() - 1:
		closed_lid_visual.visible = false
		open_lid_visual.visible = true
		open_lid_visual.modulate.a = 0.0
		tween.tween_property(open_lid_visual, "modulate:a", 1.0, OPEN_SECONDS)
		tween.tween_property(open_lid_visual, "position", open_lid_visual.position + Vector2(0, -10), OPEN_SECONDS)
	else:
		tween.tween_property(closed_lid_visual, "position", closed_lid_visual.position + Vector2(0, -9), OPEN_SECONDS)
	await tween.finished


func _animate_food_into_tray(layer_index: int) -> void:
	var target := _action_food_target(layer_index) + Vector2(0, 18)
	action_food.position = Vector2(-48, target.y - 18)
	action_food.modulate.a = 0.0
	action_food.visible = true
	var tween := _new_visual_tween().set_parallel(true)
	tween.tween_property(action_food, "position", target, FOOD_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(action_food, "modulate:a", 1.0, FOOD_SECONDS * 0.6)
	await tween.finished


func _animate_food_out(action_id: StringName) -> void:
	var target := Vector2(machine_stage.size.x + 24, 20) if action_id == &"collect" else Vector2(machine_stage.size.x * 0.5, machine_stage.size.y + 40)
	var tween := _new_visual_tween().set_parallel(true)
	tween.tween_property(action_food, "position", target, FOOD_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(action_food, "modulate:a", 0.0, FOOD_SECONDS)
	if action_overcooked_food.visible:
		tween.tween_property(action_overcooked_food, "position", target, FOOD_SECONDS)
		tween.tween_property(action_overcooked_food, "modulate:a", 0.0, FOOD_SECONDS)
	await tween.finished


func _animate_close() -> void:
	var tween := _new_visual_tween().set_parallel(true)
	for index in range(_layer_capacity()):
		var destination := _node_position_for_subject(layer_visuals[index], BASKET_BOUNDS[_tier_index()], _layer_subject_rects[index])
		tween.tween_property(layer_visuals[index], "position", destination, CLOSE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	var lid_rect := _closed_lid_rect()
	tween.tween_property(closed_lid_visual, "position", _node_position_for_subject(closed_lid_visual, CLOSED_LID_BOUNDS[_tier_index()], lid_rect), CLOSE_SECONDS)
	tween.tween_property(open_lid_visual, "modulate:a", 0.0, CLOSE_SECONDS * 0.6)
	await tween.finished
	open_lid_visual.visible = false
	closed_lid_visual.visible = true
	action_food.visible = false
	action_overcooked_food.visible = false
	for visual in layer_visuals:
		visual.z_index = 10 + layer_visuals.find(visual)


func _cancel_visual_feedback() -> void:
	_feedback_serial += 1
	for tween in _visual_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_visual_tweens.clear()
	_animation_busy = false
	if is_node_ready():
		busy_label.visible = false


func _feedback_is_current(serial: int) -> bool:
	return serial == _feedback_serial


func _new_visual_tween() -> Tween:
	var tween := create_tween()
	_visual_tweens.append(tween)
	return tween


func _refresh_from_snapshot() -> void:
	if not is_node_ready():
		return
	_refresh_controls()
	if not _animation_busy:
		_layout_machine()
		_refresh_layer_state_visuals()


func _refresh_controls() -> void:
	var enabled := _interaction_enabled and not _locked and not _animation_busy
	var unlocked_recipes: Array = Array(_snapshot.get("unlocked_recipe_ids", []))
	if not _contains_id(unlocked_recipes, _selected_recipe_id):
		for recipe_id in RECIPE_IDS:
			if _contains_id(unlocked_recipes, recipe_id):
				_selected_recipe_id = recipe_id
				break
	for index in range(recipe_buttons.size()):
		var recipe_id := RECIPE_IDS[index]
		var unlocked := _contains_id(unlocked_recipes, recipe_id)
		recipe_buttons[index].disabled = not enabled or not unlocked
		recipe_buttons[index].button_pressed = recipe_id == _selected_recipe_id
	state_label.text = "多层蒸笼 · %d层" % _layer_capacity()
	var layers := Array(_snapshot.get("layers", []))
	for index in range(layer_buttons.size()):
		var layer := Dictionary(layers[index]) if index < layers.size() else {}
		var state := StringName(layer.get("state", &"locked"))
		layer_buttons[index].text = "第%d层 · %s" % [index + 1, _state_label(state)]
		layer_buttons[index].disabled = not enabled or state in [&"locked", &"steaming"]
		layer_buttons[index].modulate = Color.WHITE if state == &"locked" else STATE_COLORS.get(state, Color.WHITE)
		layer_hit_buttons[index].disabled = layer_buttons[index].disabled
		layer_hit_buttons[index].tooltip_text = layer_buttons[index].text


func _layout_machine() -> void:
	var tier := _tier_index()
	var capacity := _layer_capacity()
	closed_machine.visible = false
	base_visual.visible = capacity > 0
	base_visual.texture = _texture_at(base_textures, tier)
	closed_lid_visual.texture = _texture_at(closed_lid_textures, tier)
	open_lid_visual.texture = _texture_at(open_lid_textures, tier)
	_set_subject_rect(base_visual, BASE_BOUNDS[tier], _base_rect())
	_layer_subject_rects.clear()
	for index in range(MAX_LAYERS):
		var visible := index < capacity
		layer_visuals[index].visible = visible
		layer_foods[index].visible = false
		layer_overcooked_foods[index].visible = false
		progress_rings[index].visible = false
		layer_hit_buttons[index].visible = visible
		if not visible:
			continue
		layer_visuals[index].texture = _texture_at(basket_textures, tier)
		var subject_rect := _layer_rect(index)
		_layer_subject_rects.append(subject_rect)
		_set_subject_rect(layer_visuals[index], BASKET_BOUNDS[tier], subject_rect)
		layer_visuals[index].z_index = 10 + index
		layer_hit_buttons[index].position = subject_rect.position + Vector2(0, 3)
		layer_hit_buttons[index].size = Vector2(subject_rect.size.x, maxf(subject_rect.size.y - 6.0, 16.0))
	closed_lid_visual.visible = capacity > 0
	open_lid_visual.visible = false
	open_lid_visual.modulate = Color.WHITE
	_set_subject_rect(closed_lid_visual, CLOSED_LID_BOUNDS[tier], _closed_lid_rect())
	_set_subject_rect(open_lid_visual, OPEN_LID_BOUNDS[tier], _open_lid_rect())
	action_food.visible = false
	action_overcooked_food.visible = false
	if capacity <= 0 and closed_machine_textures.size() > tier:
		closed_machine.texture = closed_machine_textures[tier]
		closed_machine.visible = true


func _refresh_layer_state_visuals() -> void:
	var layers := Array(_snapshot.get("layers", []))
	for index in range(MAX_LAYERS):
		if index >= _layer_capacity():
			continue
		var layer := Dictionary(layers[index]) if index < layers.size() else {}
		var state := StringName(layer.get("state", &"empty"))
		var recipe_index := RECIPE_IDS.find(StringName(layer.get("recipe_id", &"")))
		var color: Color = STATE_COLORS.get(state, Color.WHITE)
		layer_visuals[index].modulate = Color.WHITE.lerp(color, 0.16 if state != &"empty" else 0.0)
		if recipe_index >= 0 and state not in [&"empty", &"locked"]:
			layer_foods[index].texture = _state_food_texture(recipe_index, state, float(layer.get("quality", 100.0)))
			layer_foods[index].modulate = Color.WHITE
			layer_foods[index].position = Vector2(machine_stage.size.x - 45, _layer_subject_rects[index].position.y + 1)
			layer_foods[index].visible = true
			if state in [&"overcooking", &"spoiled"]:
				var overcooked_mix := 1.0 if state == &"spoiled" else clampf((100.0 - float(layer.get("quality", 100.0))) / 40.0, 0.0, 1.0)
				layer_overcooked_foods[index].texture = _texture_at(overcooked_food_textures, recipe_index)
				layer_overcooked_foods[index].position = layer_foods[index].position
				layer_overcooked_foods[index].modulate = Color(1, 1, 1, overcooked_mix)
				layer_overcooked_foods[index].visible = overcooked_mix > 0.0
		progress_rings[index].position = Vector2(machine_stage.size.x - 48, _layer_subject_rects[index].position.y - 2)
		progress_rings[index].size = Vector2(40, 40)
		progress_rings[index].call("set_visual", state, _layer_progress(layer, state))
		progress_rings[index].visible = state in [&"steaming", &"ready_safe", &"overcooking"]
	_refresh_effect_visibility(layers)


func _refresh_effect_visibility(layers: Array) -> void:
	var steam_mode: int = 0
	var has_smoke := false
	for raw_layer in layers:
		var state := StringName(Dictionary(raw_layer).get("state", &""))
		if state == &"steaming":
			steam_mode = maxi(steam_mode, 1)
		elif state == &"ready_safe":
			steam_mode = maxi(steam_mode, 2)
		elif state == &"overcooking":
			steam_mode = 3
		has_smoke = has_smoke or state == &"spoiled"
	var puff_count: int = [0, 1, 3, 2][steam_mode]
	var puff_color: Color = [Color.WHITE, Color("eefaff"), Color("ffffff"), Color("f2d7be")][steam_mode]
	_steam_motion_speed = float([1.8, 1.8, 2.8, 2.2][steam_mode])
	for index in range(steam_puffs.size()):
		steam_puffs[index].visible = index < puff_count
		steam_puffs[index].position = Vector2(machine_stage.size.x * 0.40 + index * 31, 2 + index * 5)
		var puff_scale: float = float([0.85, 1.05, 1.0][mini(index, 2)]) if steam_mode == 2 else 0.90 if steam_mode == 1 else 1.0
		steam_puffs[index].scale = Vector2.ONE * puff_scale
		steam_puffs[index].modulate = puff_color
	smoke_puff.visible = has_smoke
	smoke_puff.position = Vector2(machine_stage.size.x * 0.5 - 24, 1)


func _animate_state_effects() -> void:
	for index in range(steam_puffs.size()):
		var puff := steam_puffs[index]
		if not puff.visible:
			continue
		puff.position.y = 3.0 + index * 5.0 + sin(_visual_time * _steam_motion_speed + index) * 3.0
		puff.modulate.a = 0.48 + 0.20 * sin(_visual_time * (_steam_motion_speed + 0.6) + index * 0.8)
	if smoke_puff.visible:
		smoke_puff.position.y = 2.0 + sin(_visual_time * 1.8) * 3.0
		smoke_puff.modulate.a = 0.72 + 0.12 * sin(_visual_time * 2.1)
	var layers := Array(_snapshot.get("layers", []))
	for index in range(mini(layers.size(), layer_visuals.size())):
		var state := StringName(Dictionary(layers[index]).get("state", &""))
		if state in [&"ready_safe", &"overcooking"] and not _animation_busy:
			var pulse := 0.10 + 0.08 * (sin(_visual_time * 5.0 + index) + 1.0)
			layer_visuals[index].modulate = Color.WHITE.lerp(STATE_COLORS[state], pulse)


func _base_rect() -> Rect2:
	return [Rect2(18, 88, 256, 72), Rect2(20, 96, 252, 64), Rect2(20, 102, 252, 58)][_tier_index()]


func _layer_rect(index: int) -> Rect2:
	var tier: int = _tier_index()
	var specs: Dictionary = [
		{"width": 238.0, "height": 45.0, "bottom": 94.0, "step": 34.0},
		{"width": 226.0, "height": 36.0, "bottom": 103.0, "step": 30.0},
		{"width": 218.0, "height": 28.0, "bottom": 108.0, "step": 22.0},
	][tier]
	var width: float = float(specs["width"])
	var height: float = float(specs["height"])
	var bottom: float = float(specs["bottom"]) - float(index) * float(specs["step"])
	return Rect2((machine_stage.size.x - width) * 0.5, bottom - height, width, height)


func _closed_lid_rect() -> Rect2:
	var tier: int = _tier_index()
	var top_layer: Rect2 = _layer_rect(maxi(_layer_capacity() - 1, 0))
	var width: float = [230.0, 220.0, 212.0][tier]
	var height: float = [29.0, 28.0, 24.0][tier]
	return Rect2((machine_stage.size.x - width) * 0.5, top_layer.position.y - height * 0.55, width, height)


func _open_lid_rect() -> Rect2:
	var closed_rect := _closed_lid_rect()
	return Rect2(closed_rect.position + Vector2(8, -13), Vector2(closed_rect.size.x * 0.88, closed_rect.size.y * 1.65))


func _set_subject_rect(node: TextureRect, source_bounds: Rect2, desired_bounds: Rect2) -> void:
	if node.texture == null or source_bounds.size.x <= 0.0 or source_bounds.size.y <= 0.0:
		return
	var texture_size := Vector2(node.texture.get_size())
	var scale_xy := desired_bounds.size / source_bounds.size
	node.size = texture_size * scale_xy
	node.position = desired_bounds.position - source_bounds.position * scale_xy


func _node_position_for_subject(node: TextureRect, source_bounds: Rect2, desired_bounds: Rect2) -> Vector2:
	if node.texture == null:
		return node.position
	var scale_xy := desired_bounds.size / source_bounds.size
	return desired_bounds.position - source_bounds.position * scale_xy


func _action_food_target(layer_index: int) -> Vector2:
	var rect := _layer_subject_rects[layer_index] if layer_index >= 0 and layer_index < _layer_subject_rects.size() else Rect2(100, 70, 80, 40)
	return Vector2(rect.get_center().x - 30, rect.position.y - 11)


func _state_food_texture(recipe_index: int, state: StringName, quality: float) -> Texture2D:
	if state in [&"loaded", &"steaming"]:
		return _texture_at(loaded_food_textures, recipe_index)
	return _texture_at(cooked_food_textures, recipe_index)


func _layer_progress(layer: Dictionary, state: StringName) -> float:
	if state == &"steaming":
		var duration := maxf(float(layer.get("duration_seconds", 1.0)), 0.001)
		return clampf(float(layer.get("elapsed_seconds", 0.0)) / duration * 100.0, 0.0, 100.0)
	if state == &"ready_safe":
		return 100.0
	if state == &"overcooking":
		return clampf(float(layer.get("quality", 100.0)), 0.0, 100.0)
	return 0.0


func _tier_index() -> int:
	return clampi(int(_snapshot.get("tier", 0)), 0, 2)


func _layer_capacity() -> int:
	return clampi(int(_snapshot.get("layer_capacity", 0)), 0, MAX_LAYERS)


func _contains_id(values: Array, expected: StringName) -> bool:
	return values.has(expected) or values.has(str(expected))


func _texture_at(textures: Array[Texture2D], index: int) -> Texture2D:
	return textures[index] if index >= 0 and index < textures.size() else null


func _state_label(state: StringName) -> String:
	return {
		&"locked": "未开放",
		&"empty": "空",
		&"loaded": "已装料",
		&"steaming": "蒸制中",
		&"ready_safe": "已熟",
		&"overcooking": "即将过熟",
		&"spoiled": "已损坏",
	}.get(state, str(state))
