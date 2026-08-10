class_name FreshSoyMilkStationView
extends "res://scripts/ui/five_area_station_view.gd"

const RECIPE_IDS: Array[StringName] = [
	&"recipe.fresh_soy_milk.yellow_bean",
	&"recipe.fresh_soy_milk.black_bean",
	&"recipe.fresh_soy_milk.red_bean",
	&"recipe.fresh_soy_milk.multigrain",
]
const AUTO_WATER_START := &"automation.fresh_soy_milk.auto_water_start"
const AUTO_CUP_RACK := &"automation.fresh_soy_milk.auto_cup_rack"
const OPEN_SECONDS := 0.18
const TRANSFER_SECONDS := 0.22
const CLOSE_SECONDS := 0.18

const BODY_BOUNDS := [
	Rect2(323, 35, 378, 470),
	Rect2(320, 35, 383, 470),
	Rect2(242, 52, 539, 455),
]
const CLOSED_LID_BOUNDS := [
	Rect2(350, 35, 324, 140),
	Rect2(372, 35, 280, 140),
	Rect2(307, 32, 410, 145),
]
const OPEN_LID_BOUNDS := [
	Rect2(312, 34, 400, 223),
	Rect2(312, 32, 400, 225),
	Rect2(351, 25, 322, 250),
]

@export var body_textures: Array[Texture2D] = []
@export var closed_lid_textures: Array[Texture2D] = []
@export var open_lid_textures: Array[Texture2D] = []
@export var ingredient_textures: Array[Texture2D] = []
@export var cup_textures: Array[Texture2D] = []
@export var auto_rack_texture: Texture2D
@export var water_texture: Texture2D
@export var stream_texture: Texture2D
@export var steam_texture: Texture2D
@export var spoiled_vapor_texture: Texture2D

@onready var state_label: Label = %StateLabel
@onready var busy_label: Label = %BusyLabel
@onready var recipe_buttons: Array[Button] = [%YellowBeanButton, %BlackBeanButton, %RedBeanButton, %MultigrainButton]
@onready var load_button: Button = %LoadButton
@onready var water_button: Button = %WaterButton
@onready var start_button: Button = %StartButton
@onready var collect_button: Button = %CollectButton
@onready var rack_panel: Control = %RackPanel
@onready var rack_missing_label: Label = %RackMissingLabel
@onready var rack_visual: TextureRect = %RackVisual
@onready var output_buttons: Array[Button] = [%OutputSlot01, %OutputSlot02, %OutputSlot03, %OutputSlot04]
@onready var machine_stage: Control = %MachineStage
@onready var machine_rig: Control = %MachineRig
@onready var body_visual: TextureRect = %BodyVisual
@onready var closed_lid_visual: TextureRect = %ClosedLidVisual
@onready var open_lid_visual: TextureRect = %OpenLidVisual
@onready var machine_cups: Array[TextureRect] = [%MachineCup01, %MachineCup02, %MachineCup03, %MachineCup04]
@onready var ingredient_visual: TextureRect = %IngredientVisual
@onready var water_effect: TextureRect = %WaterEffect
@onready var stream_effect: TextureRect = %StreamEffect
@onready var steam_effect: TextureRect = %SteamEffect
@onready var spoiled_vapor: TextureRect = %SpoiledVapor
@onready var quantity_label: Label = %QuantityLabel

var _selected_recipe_id: StringName = RECIPE_IDS[0]
var _animation_busy := false
var _visual_time := 0.0
var _last_state: StringName = &"unowned"
var _closed_lid_rest_position := Vector2.ZERO
var _open_lid_rest_position := Vector2.ZERO
var _feedback_serial := 0
var _visual_tweens: Array[Tween] = []


func _ready() -> void:
	for index in range(recipe_buttons.size()):
		recipe_buttons[index].pressed.connect(func(recipe_index := index): _select_recipe(recipe_index))
	load_button.pressed.connect(_play_load_action)
	water_button.pressed.connect(_play_water_action)
	start_button.pressed.connect(_play_start_action)
	collect_button.pressed.connect(_play_collect_action)
	for index in range(output_buttons.size()):
		output_buttons[index].pressed.connect(func(slot_index := index): _play_output_action(slot_index))
	water_effect.texture = water_texture
	stream_effect.texture = stream_texture
	steam_effect.texture = steam_texture
	spoiled_vapor.texture = spoiled_vapor_texture
	rack_visual.texture = auto_rack_texture
	_refresh_from_snapshot()


func _process(delta: float) -> void:
	_visual_time += maxf(delta, 0.0)
	var state := StringName(_snapshot.get("state", &"unowned"))
	if not _animation_busy:
		machine_rig.position.x = sin(_visual_time * 31.0) * 1.8 if state == &"grinding" else 0.0
	if steam_effect.visible:
		steam_effect.position.y = 42.0 + sin(_visual_time * 2.6) * 3.0
		steam_effect.modulate.a = 0.60 + sin(_visual_time * 3.2) * 0.16
	if spoiled_vapor.visible:
		spoiled_vapor.position.y = 30.0 + sin(_visual_time * 2.0) * 2.5
	if state == &"overcooking" and not _animation_busy:
		var pulse := 0.82 + (sin(_visual_time * 6.0) + 1.0) * 0.09
		for cup in machine_cups:
			if cup.visible:
				cup.modulate = Color(1.0, pulse, 0.72, 1.0)


func _select_recipe(index: int) -> void:
	if index < 0 or index >= RECIPE_IDS.size() or recipe_buttons[index].disabled:
		return
	_selected_recipe_id = RECIPE_IDS[index]
	_refresh_from_snapshot()


func apply_snapshot(snapshot: Dictionary) -> void:
	_cancel_visual_feedback()
	super.apply_snapshot(snapshot)


func _play_load_action() -> void:
	if _animation_busy or load_button.disabled:
		return
	var serial := _begin_feedback("自动开盖并装入豆料…")
	await _animate_open()
	if not _feedback_is_current(serial):
		return
	await _animate_ingredient_into_hopper()
	if not _feedback_is_current(serial):
		return
	request_intent(&"load", {"recipe_id": _selected_recipe_id, "quantity": 1})
	if not _feedback_is_current(serial):
		return
	if _owns_automation(AUTO_WATER_START):
		await _animate_water_pour()
		if not _feedback_is_current(serial):
			return
		await _animate_close()
		if not _feedback_is_current(serial):
			return
		await _animate_machine_start()
	_finish_feedback(serial)


func _play_water_action() -> void:
	if _animation_busy or water_button.disabled:
		return
	var serial := _begin_feedback("加水并盖好顶盖…")
	await _animate_water_pour()
	if not _feedback_is_current(serial):
		return
	request_intent(&"add_water")
	if not _feedback_is_current(serial):
		return
	await _animate_close()
	_finish_feedback(serial)


func _play_start_action() -> void:
	if _animation_busy or start_button.disabled:
		return
	var serial := _begin_feedback("启动研磨…")
	request_intent(&"start")
	if not _feedback_is_current(serial):
		return
	await _animate_close()
	if not _feedback_is_current(serial):
		return
	await _animate_machine_start()
	_finish_feedback(serial)


func _play_collect_action() -> void:
	if _animation_busy or collect_button.disabled:
		return
	var state := StringName(_snapshot.get("state", &""))
	var action_id := &"discard" if state == &"spoiled" else &"collect"
	var serial := _begin_feedback("丢弃变质豆浆…" if action_id == &"discard" else "取出豆浆…")
	var cup := _first_visible_machine_cup()
	if cup != null:
		var target := Vector2(machine_stage.size.x * 0.5, machine_stage.size.y + 38.0) if action_id == &"discard" else Vector2(machine_stage.size.x + 35.0, 22.0)
		var tween := _new_visual_tween().set_parallel(true)
		tween.tween_property(cup, "position", target, TRANSFER_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(cup, "modulate:a", 0.0, TRANSFER_SECONDS)
		await tween.finished
		if not _feedback_is_current(serial):
			return
	request_intent(action_id, {"slot_index": -1, "quantity": 1})
	if not _feedback_is_current(serial):
		return
	_finish_feedback(serial)


func _play_output_action(slot_index: int) -> void:
	if _animation_busy or slot_index < 0 or slot_index >= output_buttons.size() or output_buttons[slot_index].disabled:
		return
	var rack := Array(_snapshot.get("output_rack", []))
	var cup := Dictionary(rack[slot_index]) if slot_index < rack.size() else {}
	var action_id := &"discard" if StringName(cup.get("state", &"")) == &"spoiled" else &"collect_output"
	var serial := _begin_feedback("清理接杯架…" if action_id == &"discard" else "从接杯架取杯…")
	var button := output_buttons[slot_index]
	button.pivot_offset = button.size * 0.5
	var tween := _new_visual_tween().set_parallel(true)
	tween.tween_property(button, "scale", Vector2(1.18, 1.18), 0.10)
	tween.tween_property(button, "modulate:a", 0.20, TRANSFER_SECONDS)
	await tween.finished
	if not _feedback_is_current(serial):
		return
	request_intent(action_id, {"slot_index": slot_index})
	if not _feedback_is_current(serial):
		return
	button.scale = Vector2.ONE
	button.modulate = Color.WHITE
	_finish_feedback(serial)


func _begin_feedback(message: String) -> int:
	_cancel_visual_feedback()
	_feedback_serial += 1
	_animation_busy = true
	busy_label.text = message
	busy_label.visible = true
	_refresh_controls()
	return _feedback_serial


func _finish_feedback(serial: int) -> void:
	if not _feedback_is_current(serial):
		return
	_visual_tweens.clear()
	_animation_busy = false
	busy_label.visible = false
	_refresh_from_snapshot()


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


func _animate_open() -> void:
	closed_lid_visual.visible = false
	open_lid_visual.visible = true
	open_lid_visual.position = _open_lid_rest_position + Vector2(0, 10)
	open_lid_visual.modulate = Color(1, 1, 1, 0)
	var tween := _new_visual_tween().set_parallel(true)
	tween.tween_property(open_lid_visual, "position", _open_lid_rest_position, OPEN_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(open_lid_visual, "modulate:a", 1.0, OPEN_SECONDS)
	await tween.finished


func _animate_close() -> void:
	closed_lid_visual.visible = true
	closed_lid_visual.position = _closed_lid_rest_position + Vector2(0, -5)
	closed_lid_visual.modulate = Color(1, 1, 1, 0)
	var tween := _new_visual_tween().set_parallel(true)
	tween.tween_property(open_lid_visual, "modulate:a", 0.0, CLOSE_SECONDS * 0.75)
	tween.tween_property(closed_lid_visual, "position", _closed_lid_rest_position, CLOSE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(closed_lid_visual, "modulate:a", 1.0, CLOSE_SECONDS)
	await tween.finished
	open_lid_visual.visible = false
	ingredient_visual.visible = false


func _animate_ingredient_into_hopper() -> void:
	var recipe_index := maxi(RECIPE_IDS.find(_selected_recipe_id), 0)
	ingredient_visual.texture = _texture_at(ingredient_textures, recipe_index)
	ingredient_visual.position = Vector2(-52, 36)
	ingredient_visual.modulate = Color(1, 1, 1, 0)
	ingredient_visual.visible = true
	var tween := _new_visual_tween().set_parallel(true)
	tween.tween_property(ingredient_visual, "position", Vector2(122, 8), TRANSFER_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(ingredient_visual, "modulate:a", 1.0, TRANSFER_SECONDS * 0.65)
	await tween.finished


func _animate_water_pour() -> void:
	water_effect.position = Vector2(116, -20)
	water_effect.modulate = Color(1, 1, 1, 0)
	water_effect.visible = true
	var tween := _new_visual_tween()
	tween.set_parallel(true)
	tween.tween_property(water_effect, "position", Vector2(120, 3), TRANSFER_SECONDS)
	tween.tween_property(water_effect, "modulate:a", 1.0, TRANSFER_SECONDS * 0.45)
	await tween.finished
	var fade := _new_visual_tween()
	fade.tween_property(water_effect, "modulate:a", 0.0, 0.10)
	await fade.finished
	water_effect.visible = false


func _animate_machine_start() -> void:
	machine_rig.position = Vector2.ZERO
	var tween := _new_visual_tween()
	for offset in [2.5, -2.5, 2.0, -2.0, 0.0]:
		tween.tween_property(machine_rig, "position:x", offset, 0.045)
	await tween.finished


func _play_ready_feedback() -> void:
	if _animation_busy or not is_node_ready():
		return
	stream_effect.position = Vector2(132, 35)
	stream_effect.modulate = Color(1, 1, 1, 0)
	stream_effect.visible = true
	var tween := _new_visual_tween()
	tween.tween_property(stream_effect, "modulate:a", 1.0, 0.10)
	tween.tween_interval(0.18)
	tween.tween_property(stream_effect, "modulate:a", 0.0, 0.12)
	await tween.finished
	stream_effect.visible = false


func _refresh_from_snapshot() -> void:
	if not is_node_ready():
		return
	var previous_state := _last_state
	var state := StringName(_snapshot.get("state", &"unowned"))
	_last_state = state
	_refresh_controls()
	if not _animation_busy:
		_layout_machine()
	if previous_state == &"grinding" and state in [&"ready_safe", &"overcooking", &"blocked"]:
		_play_ready_feedback.call_deferred()


func _refresh_controls() -> void:
	var state := StringName(_snapshot.get("state", &"unowned"))
	state_label.text = "现磨豆浆 · %s" % _state_label(state)
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
	load_button.disabled = not enabled or state != &"idle"
	water_button.disabled = not enabled or state != &"loaded"
	start_button.disabled = not enabled or state != &"water_added"
	collect_button.text = "丢弃废料" if state == &"spoiled" else "接杯"
	collect_button.disabled = not enabled or state not in [&"ready_safe", &"overcooking", &"spoiled"]
	_refresh_rack_controls(enabled, state)


func _layout_machine() -> void:
	var tier := _tier_index()
	var state := StringName(_snapshot.get("state", &"unowned"))
	machine_rig.visible = state != &"unowned" and not _locked
	if not machine_rig.visible:
		return
	machine_rig.position = Vector2.ZERO
	body_visual.texture = _texture_at(body_textures, tier)
	closed_lid_visual.texture = _texture_at(closed_lid_textures, tier)
	open_lid_visual.texture = _texture_at(open_lid_textures, tier)
	_set_subject_rect(body_visual, BODY_BOUNDS[tier], _body_rect())
	_set_subject_rect(closed_lid_visual, CLOSED_LID_BOUNDS[tier], _closed_lid_rect())
	_set_subject_rect(open_lid_visual, OPEN_LID_BOUNDS[tier], _open_lid_rect())
	_closed_lid_rest_position = closed_lid_visual.position
	_open_lid_rest_position = open_lid_visual.position
	var lid_open := state == &"loaded"
	closed_lid_visual.visible = not lid_open
	closed_lid_visual.modulate = Color.WHITE
	open_lid_visual.visible = lid_open
	open_lid_visual.modulate = Color.WHITE

	var recipe_id := StringName(_snapshot.get("recipe_id", _selected_recipe_id))
	if recipe_id.is_empty():
		recipe_id = _selected_recipe_id
	var recipe_index := maxi(RECIPE_IDS.find(recipe_id), 0)
	var ready := state in [&"ready_safe", &"overcooking", &"blocked", &"spoiled"]
	var cup_texture := _texture_at(cup_textures, recipe_index + 1) if ready else _texture_at(cup_textures, 0)
	_layout_machine_cups(tier, cup_texture, state)

	ingredient_visual.texture = _texture_at(ingredient_textures, recipe_index)
	ingredient_visual.position = Vector2(122, 8)
	ingredient_visual.modulate = Color.WHITE
	ingredient_visual.visible = state == &"loaded"
	water_effect.visible = false
	stream_effect.visible = false
	steam_effect.visible = state in [&"ready_safe", &"overcooking", &"blocked"]
	steam_effect.position = Vector2(118, 42)
	steam_effect.modulate = Color.WHITE
	spoiled_vapor.visible = state == &"spoiled"
	spoiled_vapor.position = Vector2(112, 30)
	spoiled_vapor.modulate = Color.WHITE
	body_visual.modulate = Color(1.0, 0.82, 0.75) if state == &"blocked" else Color.WHITE
	_configure_rack_visual(state)


func _layout_machine_cups(tier: int, texture: Texture2D, state: StringName) -> void:
	var quantity := maxi(int(_snapshot.get("quantity", 0)), 0)
	var cup_rects: Array[Rect2]
	if tier < 2:
		cup_rects = [Rect2(116, 73, 55, 67)]
	else:
		cup_rects = [
			Rect2(101, 73, 34, 42), Rect2(145, 73, 34, 42),
			Rect2(88, 94, 43, 51), Rect2(143, 94, 43, 51),
		]
	var visible_count := cup_rects.size()
	if state in [&"ready_safe", &"overcooking", &"blocked", &"spoiled"] and tier >= 2:
		visible_count = clampi(quantity, 1, 4)
	for index in range(machine_cups.size()):
		var cup := machine_cups[index]
		cup.visible = index < visible_count
		if not cup.visible:
			continue
		cup.texture = texture
		cup.position = cup_rects[index].position
		cup.size = cup_rects[index].size
		cup.modulate = Color(0.63, 0.60, 0.52, 1.0) if state == &"spoiled" else Color.WHITE
	quantity_label.visible = quantity > visible_count
	quantity_label.text = "×%d" % quantity
	quantity_label.position = Vector2(172, 111)


func _refresh_rack_controls(enabled: bool, machine_state: StringName) -> void:
	var rack := Array(_snapshot.get("output_rack", []))
	var show_rack := _owns_automation(AUTO_CUP_RACK)
	if not show_rack:
		for raw_cup in rack:
			show_rack = show_rack or not Dictionary(raw_cup).is_empty()
	rack_panel.visible = show_rack
	rack_missing_label.visible = not show_rack
	for index in range(output_buttons.size()):
		var cup := Dictionary(rack[index]) if index < rack.size() else {}
		var button := output_buttons[index]
		button.icon = null if cup.is_empty() else _cup_texture_for_recipe(StringName(cup.get("recipe_id", &"")))
		button.text = "·" if cup.is_empty() else ""
		button.tooltip_text = "杯位%d · %s" % [index + 1, "空" if cup.is_empty() else _state_label(StringName(cup.get("state", &"ready_safe")))]
		button.disabled = not enabled or cup.is_empty()
		button.modulate = Color(1.0, 0.62, 0.62) if machine_state == &"blocked" else Color.WHITE


func _configure_rack_visual(state: StringName) -> void:
	rack_visual.modulate = Color(1.0, 0.58, 0.58) if state == &"blocked" else Color.WHITE


func _first_visible_machine_cup() -> TextureRect:
	for cup in machine_cups:
		if cup.visible:
			return cup
	return null


func _cup_texture_for_recipe(recipe_id: StringName) -> Texture2D:
	var recipe_index := RECIPE_IDS.find(recipe_id)
	return _texture_at(cup_textures, recipe_index + 1) if recipe_index >= 0 else _texture_at(cup_textures, 0)


func _body_rect() -> Rect2:
	return [Rect2(84, 3, 122, 138), Rect2(82, 3, 124, 138), Rect2(61, 8, 170, 134)][_tier_index()]


func _closed_lid_rect() -> Rect2:
	return [Rect2(88, 2, 116, 32), Rect2(92, 2, 108, 32), Rect2(59, 3, 174, 36)][_tier_index()]


func _open_lid_rect() -> Rect2:
	return [Rect2(115, -2, 104, 58), Rect2(115, -2, 104, 58), Rect2(132, -3, 103, 76)][_tier_index()]


func _set_subject_rect(node: TextureRect, source_bounds: Rect2, desired_bounds: Rect2) -> void:
	if node.texture == null or source_bounds.size.x <= 0.0 or source_bounds.size.y <= 0.0:
		return
	var texture_size := Vector2(node.texture.get_size())
	var scale_xy := desired_bounds.size / source_bounds.size
	node.size = texture_size * scale_xy
	node.position = desired_bounds.position - source_bounds.position * scale_xy


func _tier_index() -> int:
	return clampi(int(_snapshot.get("tier", 0)), 0, 2)


func _owns_automation(automation_id: StringName) -> bool:
	return _contains_id(Array(_snapshot.get("unlocked_automation_ids", [])), automation_id)


func _contains_id(values: Array, expected: StringName) -> bool:
	return values.has(expected) or values.has(str(expected))


func _texture_at(textures: Array[Texture2D], index: int) -> Texture2D:
	return textures[index] if index >= 0 and index < textures.size() else null


func _state_label(state: StringName) -> String:
	return {
		&"unowned": "未安装",
		&"idle": "待机",
		&"loaded": "已装豆料",
		&"water_added": "已加水",
		&"grinding": "研磨中",
		&"ready_safe": "可接杯",
		&"overcooking": "即将变质",
		&"blocked": "接杯架已满",
		&"spoiled": "已变质",
	}.get(state, str(state))
