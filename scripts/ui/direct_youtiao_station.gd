class_name DirectYoutiaoStation
extends Control

signal status_message(message: String)

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const AUTO_LIFT := &"automation.youtiao.auto_lift"
const TEMPERATURE_ASSIST := &"assist.youtiao.temperature_indicator"
const RECIPE_ID := &"recipe.youtiao.plain"

@export var body_textures: Array[Texture2D] = []
@export var lowered_basket_textures: Array[Texture2D] = []
@export var raised_basket_textures: Array[Texture2D] = []
@export var raw_food_textures: Array[Texture2D] = []
@export var cooked_food_textures: Array[Texture2D] = []
@export var auto_lift_texture: Texture2D
@export var sizzle_texture: Texture2D
@export var oil_drips_texture: Texture2D
@export var burnt_smoke_texture: Texture2D

@onready var machine_stage: Control = %MachineStage
@onready var body_visual: TextureRect = %BodyVisual
@onready var lowered_basket_visual: TextureRect = %LoweredBasketVisual
@onready var raised_basket_visual: TextureRect = %RaisedBasketVisual
@onready var lowered_basket_front_clip: Control = %LoweredBasketFrontClip
@onready var lowered_basket_front_visual: TextureRect = %LoweredBasketFrontVisual
@onready var raised_basket_front_clip: Control = %RaisedBasketFrontClip
@onready var raised_basket_front_visual: TextureRect = %RaisedBasketFrontVisual
@onready var auto_lift_visual: TextureRect = %AutoLiftArmVisual
@onready var food_layer: Control = $MachineStage/ArtRoot/FoodLayer
@onready var food_slots: Array[Control] = [%FoodSlot01, %FoodSlot02, %FoodSlot03, %FoodSlot04, %FoodSlot05, %FoodSlot06, %FoodSlot07, %FoodSlot08]
@onready var raw_food_visuals: Array[TextureRect] = [%RawFood01, %RawFood02, %RawFood03, %RawFood04, %RawFood05, %RawFood06, %RawFood07, %RawFood08]
@onready var cooked_food_visuals: Array[TextureRect] = [%CookedFood01, %CookedFood02, %CookedFood03, %CookedFood04, %CookedFood05, %CookedFood06, %CookedFood07, %CookedFood08]
@onready var sizzle_layer: Control = $MachineStage/ArtRoot/SizzleLayer
@onready var sizzle_visuals: Array[TextureRect] = [%SizzleBubbles01, %SizzleBubbles02]
@onready var oil_drips_visual: TextureRect = %OilDripsVisual
@onready var burnt_smoke_visual: TextureRect = %BurntSmokeVisual
@onready var temperature_range_bar: YoutiaoTemperatureRangeBar = %TemperatureRangeBar
@onready var start_button: Button = %StartButton
@onready var lift_button: Button = %LiftButton
@onready var auto_lift_toggle: CheckButton = %AutoLiftToggle
@onready var output_sources: Array[ProductDragSource] = [%OutputSlot01, %OutputSlot02, %OutputSlot03, %OutputSlot04, %OutputSlot05, %OutputSlot06, %OutputSlot07, %OutputSlot08]
# Compatibility for old tests and non-UI callers that only need a representative source.
@onready var output_source: ProductDragSource = %OutputSlot01
@onready var state_label: Label = %StateLabel
@onready var quantity_label: Label = %QuantityLabel
@onready var prepared_slots: Array[PreparedProductSlot] = [%PreparedPlain]
@onready var lock_cover: Button = %LockCover

var _machine: Dictionary = {}
var _inventory: Dictionary = {}
var _unlocked_recipe_ids: Array = []
var _selected_recipe_id: StringName = RECIPE_ID
var _refresh_elapsed := 0.0
var _visual_time := 0.0
var _session_refresh_enabled := true
var _structural_signature := ""
var _visual_tweens: Array[Tween] = []
var _sizzle_rest_positions: Array[Vector2] = []
var _drips_rest_position := Vector2.ZERO
var _raised_basket_front_rest_position := Vector2(0.0, 44.0)


func _ready() -> void:
	start_button.pressed.connect(_perform_action.bind(&"start"))
	lift_button.pressed.connect(_perform_action.bind(&"lift"))
	auto_lift_toggle.toggled.connect(_on_auto_lift_toggled)
	lock_cover.pressed.connect(_on_lock_cover_pressed)
	for slot in prepared_slots:
		slot.store_completed.connect(_on_prepared_store_completed)
	auto_lift_visual.texture = auto_lift_texture
	for visual in sizzle_visuals:
		visual.texture = sizzle_texture
		_sizzle_rest_positions.append(visual.position)
	oil_drips_visual.texture = oil_drips_texture
	burnt_smoke_visual.texture = burnt_smoke_texture
	_drips_rest_position = oil_drips_visual.position
	refresh_from_session()


func _process(delta: float) -> void:
	_visual_time += maxf(delta, 0.0)
	_update_looping_effects()
	if not _session_refresh_enabled:
		return
	_refresh_elapsed += delta
	if _refresh_elapsed >= 0.10:
		_refresh_elapsed = 0.0
		refresh_from_session()


func _has_point(point: Vector2) -> bool:
	# The formal workstation places the pancake sauce rack over the lower part
	# of this station's rectangular shell. Only the authored basket stage needs
	# root-level drop input; child buttons keep their own exact hit regions.
	return Rect2(machine_stage.position, machine_stage.size).has_point(point)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and StringName(Dictionary(data).get("kind", &"")) == &"product_source" and StringName(Dictionary(Dictionary(data).get("source_ref", {})).get("source_kind", &"")) == &"youtiao_dough"


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var source_ref := Dictionary(Dictionary(data).get("source_ref", {}))
	var session := get_node_or_null("/root/GameSession")
	var before_slots := _occupied_slots()
	var result: Dictionary = session.call("load_f3_youtiao", StringName(source_ref.get("recipe_id", &"")), 1) if session != null else {"success": false, "reason": &"no_game_session"}
	refresh_from_session()
	if bool(result.get("success", false)):
		status_message.emit("面胚已放入炸篮")
		_animate_newly_loaded_slots(before_slots, at_position - machine_stage.position)
	else:
		status_message.emit("面胚回到原位：%s" % str(result.get("reason", &"unknown")))


func refresh_from_session() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return
	var progression := Dictionary(session.call("five_area_progression_snapshot"))
	var unlocked_area := _contains_id(Array(progression.get("unlocked_area_ids", [])), &"area.youtiao")
	var unlocked_recipes := Array(progression.get("unlocked_recipe_ids", []))
	# The fryer is represented by the permanent stall artwork before purchase;
	# do not place a second, "not installed" UI on top of it.
	visible = unlocked_area
	_unlocked_recipe_ids = unlocked_recipes.duplicate()
	_inventory = Dictionary(session.call("inventory_snapshot"))
	var snapshot := Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer"))
	snapshot["unlocked_recipe_ids"] = unlocked_recipes.duplicate()
	snapshot["unlocked_automation_ids"] = Array(progression.get("unlocked_automation_ids", [])).duplicate()
	snapshot["auto_lift_enabled"] = bool(session.call("youtiao_auto_lift_enabled"))
	snapshot["owned_assist_ids"] = Array(progression.get("owned_assist_ids", [])).duplicate()
	lock_cover.visible = false
	_apply_machine_snapshot(snapshot)
	_refresh_prepared_slots(session)
	_refresh_controls()


func apply_visual_snapshot(snapshot: Dictionary, inventory: Dictionary = {}) -> void:
	_session_refresh_enabled = false
	_inventory = inventory.duplicate(true)
	_unlocked_recipe_ids = Array(snapshot.get("unlocked_recipe_ids", [RECIPE_ID])).duplicate()
	visible = bool(snapshot.get("owned", false))
	lock_cover.visible = false
	_apply_machine_snapshot(snapshot, true)
	_refresh_controls()


func resume_session_refresh() -> void:
	_session_refresh_enabled = true
	refresh_from_session()


func _refresh_prepared_slots(session: Node) -> void:
	for slot in prepared_slots:
		var status := Dictionary(session.call("prepared_product_slot_status", slot.slot_id))
		slot.configure_count(int(status.get("count", 0)), StringName(status.get("reason", &"")) != &"recipe_locked", int(status.get("capacity", 4)))


func _on_prepared_store_completed(result: Dictionary) -> void:
	status_message.emit("炸物已放入匹配暂存格" if bool(result.get("success", false)) else "未能放入暂存格，炸锅成品已保留：%s" % str(result.get("reason", &"unknown")))
	refresh_from_session()


func _apply_machine_snapshot(snapshot: Dictionary, force: bool = false) -> void:
	var signature := _snapshot_signature(snapshot)
	if force or signature != _structural_signature:
		_cancel_visual_feedback()
		_structural_signature = signature
	_machine = snapshot.duplicate(true)
	_render_machine()
	_refresh_controls()


func _render_machine() -> void:
	if not is_node_ready():
		return
	var state := StringName(_machine.get("state", &"unowned"))
	var tier := clampi(int(_machine.get("tier", 0)), 0, 2)
	var owned := bool(_machine.get("owned", false)) and state != &"unowned" and not lock_cover.visible
	machine_stage.visible = owned
	if not owned:
		return
	body_visual.texture = _texture_at(body_textures, tier)
	lowered_basket_visual.texture = _texture_at(lowered_basket_textures, tier)
	raised_basket_visual.texture = _texture_at(raised_basket_textures, tier)
	lowered_basket_front_visual.texture = lowered_basket_visual.texture
	raised_basket_front_visual.texture = raised_basket_visual.texture
	_layout_basket_front_clips(tier)
	body_visual.modulate = Color.WHITE
	lowered_basket_visual.modulate = Color.WHITE
	raised_basket_visual.modulate = Color.WHITE
	var basket_is_raised := state in [&"draining", &"ready_to_collect"]
	lowered_basket_visual.visible = not basket_is_raised
	raised_basket_visual.visible = basket_is_raised
	lowered_basket_front_clip.visible = not basket_is_raised
	raised_basket_front_clip.visible = basket_is_raised
	auto_lift_visual.visible = _owns_automation(AUTO_LIFT)
	auto_lift_visual.modulate = Color.WHITE if bool(_machine.get("auto_lift_enabled", false)) else Color(0.42, 0.42, 0.42, 0.72)
	_layout_food(tier, state, basket_is_raised)
	sizzle_layer.visible = state == &"frying"
	oil_drips_visual.visible = state == &"draining"
	burnt_smoke_visual.visible = state == &"burnt"
	var recipe_id := StringName(_machine.get("recipe_id", &""))
	var product_id := StringName(CATALOG.recipe_definition(recipe_id).get("product_id", &""))
	var occupied_slots := _occupied_slots()
	var drag_texture := _texture_at(cooked_food_textures, 0) if state not in [&"loaded", &"frying"] else _texture_at(raw_food_textures, 0)
	var batch_available := not occupied_slots.is_empty() and state not in [&"idle", &"unowned", &"draining"]
	for slot_index in range(output_sources.size()):
		var source := output_sources[slot_index]
		var occupied := occupied_slots.has(slot_index)
		var hint := "拖动任意一根，整锅收纳到成品区" if state == &"ready_to_collect" else "拖到废弃区将整锅报废"
		source.configure({"source_kind": &"youtiao_batch", "source_index": -1, "product_id": product_id, "quantity": occupied_slots.size(), "discardable": true}, drag_texture, occupied and batch_available, hint)
		source.self_modulate = Color(1.0, 1.0, 1.0, 0.01)
	temperature_range_bar.apply_snapshot(_machine, _owns_assist(TEMPERATURE_ASSIST))


func _layout_food(tier: int, state: StringName, basket_is_raised: bool) -> void:
	var occupied_slots := _occupied_slots()
	var rects := _food_rects(tier, basket_is_raised)
	var cooking_ratio := _cooking_ratio(tier, state)
	var cooked_color := _cooked_color(state)
	for index in range(food_slots.size()):
		var slot := food_slots[index]
		slot.visible = occupied_slots.has(index) and state not in [&"idle", &"unowned"]
		if not slot.visible:
			continue
		var local_rect := _stage_rect_to_food_layer(rects[index])
		slot.position = local_rect.position
		slot.size = local_rect.size
		slot.pivot_offset = slot.size * 0.5
		slot.scale = Vector2.ONE * lerpf(0.86, 1.05, cooking_ratio)
		slot.modulate = Color.WHITE
		var raw_visual := raw_food_visuals[index]
		var cooked_visual := cooked_food_visuals[index]
		raw_visual.texture = _texture_at(raw_food_textures, 0)
		cooked_visual.texture = _texture_at(cooked_food_textures, 0)
		var raw_alpha := 1.0 - cooking_ratio if state == &"frying" else 1.0 if state == &"loaded" else 0.0
		var cooked_alpha := cooking_ratio if state == &"frying" else 0.0 if state == &"loaded" else 1.0
		raw_visual.modulate = Color(1.0, 1.0, 1.0, raw_alpha)
		cooked_visual.modulate = Color(cooked_color.r, cooked_color.g, cooked_color.b, cooked_alpha)


func _layout_basket_front_clips(tier: int) -> void:
	_layout_basket_front_clip(lowered_basket_front_clip, lowered_basket_front_visual, _front_clip_top(tier, false))
	_layout_basket_front_clip(raised_basket_front_clip, raised_basket_front_visual, _front_clip_top(tier, true))
	_raised_basket_front_rest_position = raised_basket_front_clip.position


func _layout_basket_front_clip(clip: Control, visual: TextureRect, clip_top: float) -> void:
	clip.position = Vector2(0.0, clip_top)
	clip.size = Vector2(machine_stage.size.x, machine_stage.size.y - clip_top)
	visual.position = Vector2(0.0, -clip_top)
	visual.size = machine_stage.size


func _refresh_controls() -> void:
	if not is_node_ready():
		return
	var state := StringName(_machine.get("state", &"unowned"))
	var owned := bool(_machine.get("owned", false)) and not lock_cover.visible
	start_button.disabled = not owned or state != &"loaded"
	lift_button.text = "升篮"
	lift_button.disabled = not owned or state not in [&"ready_safe", &"overcooking"]
	var owns_auto_lift := owned and _owns_automation(AUTO_LIFT)
	auto_lift_toggle.visible = owns_auto_lift
	auto_lift_toggle.set_pressed_no_signal(owns_auto_lift and bool(_machine.get("auto_lift_enabled", false)))
	auto_lift_toggle.text = "自动升篮：开" if auto_lift_toggle.button_pressed else "自动升篮：关"
	state_label.text = "油条炸锅 · %s" % _state_text(state)
	var quantity := int(_machine.get("quantity", 0))
	quantity_label.text = "%d/%d" % [quantity, int(_machine.get("capacity", 0))] if quantity > 0 else ""


func select_recipe(recipe_id: StringName) -> bool:
	if recipe_id != RECIPE_ID or not _contains_id(_unlocked_recipe_ids, recipe_id):
		status_message.emit("该面胚配方尚未解锁")
		return false
	_selected_recipe_id = recipe_id
	_refresh_controls()
	status_message.emit("已选择油条面胚")
	return true


func _perform_action(action_id: StringName) -> void:
	var session := get_node_or_null("/root/GameSession")
	var result: Dictionary = session.call("perform_f3_youtiao_action", action_id) if session != null else {"success": false, "reason": &"no_game_session"}
	refresh_from_session()
	if bool(result.get("success", false)):
		status_message.emit("炸篮已启动" if action_id == &"start" else "炸篮已升起，正在沥油")
		if action_id == &"start":
			_animate_start_feedback()
		elif action_id == &"lift":
			_animate_lift_feedback()
	else:
		status_message.emit("设备没有动作：%s" % str(result.get("reason", &"unknown")))


func _on_auto_lift_toggled(enabled: bool) -> void:
	var session := get_node_or_null("/root/GameSession")
	var result: Dictionary = session.call("set_youtiao_auto_lift_enabled", enabled) if session != null else {"success": false, "reason": &"no_game_session"}
	refresh_from_session()
	if bool(result.get("success", false)):
		status_message.emit("自动升篮已开启" if enabled else "自动升篮已关闭")
	else:
		status_message.emit("自动升篮未能切换：%s" % str(result.get("reason", &"unknown")))


func _animate_loaded_slot(slot_index: int, start_position: Vector2) -> void:
	if slot_index < 0 or slot_index >= food_slots.size() or not food_slots[slot_index].visible:
		return
	var slot := food_slots[slot_index]
	var target := slot.position
	var local_start := _stage_point_to_food_layer(start_position)
	slot.position = local_start - slot.size * 0.5
	slot.modulate = Color(1.0, 1.0, 1.0, 0.15)
	slot.scale = Vector2.ONE * 0.55
	var tween := _new_visual_tween().set_parallel(true)
	tween.tween_property(slot, "position", target, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(slot, "scale", Vector2.ONE * 0.86, 0.24)
	tween.tween_property(slot, "modulate:a", 1.0, 0.16)


func _animate_newly_loaded_slots(before_slots: Array[int], start_position: Vector2) -> void:
	for index in _occupied_slots():
		if not before_slots.has(index):
			_animate_loaded_slot(index, start_position + Vector2(index * 3.0, 0.0))


func _animate_start_feedback() -> void:
	machine_stage.pivot_offset = machine_stage.size * 0.5
	var tween := _new_visual_tween()
	tween.tween_property(machine_stage, "scale", Vector2(1.025, 0.975), 0.08)
	tween.tween_property(machine_stage, "scale", Vector2.ONE, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _animate_lift_feedback() -> void:
	if not raised_basket_visual.visible:
		return
	raised_basket_visual.position = Vector2(0.0, 20.0)
	raised_basket_visual.modulate.a = 0.45
	raised_basket_front_clip.position = _raised_basket_front_rest_position + Vector2(0.0, 20.0)
	raised_basket_front_clip.modulate.a = 0.45
	var tween := _new_visual_tween().set_parallel(true)
	tween.tween_property(raised_basket_visual, "position", Vector2.ZERO, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(raised_basket_visual, "modulate:a", 1.0, 0.18)
	tween.tween_property(raised_basket_front_clip, "position", _raised_basket_front_rest_position, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(raised_basket_front_clip, "modulate:a", 1.0, 0.18)


func _update_looping_effects() -> void:
	if not is_node_ready():
		return
	for index in range(sizzle_visuals.size()):
		var visual := sizzle_visuals[index]
		if not visual.visible:
			continue
		var phase := _visual_time * 6.2 + float(index) * 2.1
		visual.position = _sizzle_rest_positions[index] + Vector2(0.0, sin(phase) * 2.5)
		visual.modulate.a = 0.54 + (sin(phase + 0.7) + 1.0) * 0.18
	if oil_drips_visual.visible:
		var drip_phase := fposmod(_visual_time * 1.7, 1.0)
		oil_drips_visual.position = _drips_rest_position + Vector2(0.0, drip_phase * 7.0)
		oil_drips_visual.modulate.a = 1.0 - drip_phase * 0.55
	if burnt_smoke_visual.visible:
		burnt_smoke_visual.position.y = -10.0 + sin(_visual_time * 2.2) * 3.0
		burnt_smoke_visual.modulate.a = 0.62 + sin(_visual_time * 2.7) * 0.13
	var state := StringName(_machine.get("state", &""))
	if state in [&"ready_safe", &"overcooking"] and not lift_button.disabled:
		var pulse := 0.76 + (sin(_visual_time * 6.5) + 1.0) * 0.12
		lift_button.modulate = Color(1.0, pulse, 0.62, 1.0)
	else:
		lift_button.modulate = Color.WHITE
	if state == &"overcooking":
		var heat_pulse := 0.76 + (sin(_visual_time * 7.0) + 1.0) * 0.10
		var base_color := _cooked_color(state)
		for visual in cooked_food_visuals:
			if visual.get_parent().visible:
				visual.modulate = Color(base_color.r, base_color.g * heat_pulse, base_color.b, visual.modulate.a)


func _cancel_visual_feedback() -> void:
	for tween in _visual_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_visual_tweens.clear()
	if is_node_ready():
		machine_stage.scale = Vector2.ONE
		raised_basket_visual.position = Vector2.ZERO
		raised_basket_visual.modulate = Color.WHITE
		raised_basket_front_clip.position = _raised_basket_front_rest_position
		raised_basket_front_clip.modulate = Color.WHITE


func _new_visual_tween() -> Tween:
	var tween := create_tween()
	_visual_tweens.append(tween)
	return tween


func _on_lock_cover_pressed() -> void:
	var session := get_node_or_null("/root/GameSession")
	var message := "油条区域未解锁"
	if session != null and session.has_method("growth_missing_requirements"):
		message = str(session.call("growth_missing_requirements", &"growth.area.youtiao"))
	status_message.emit(message)


func _cooking_ratio(tier: int, state: StringName) -> float:
	if state != &"frying":
		return 0.0 if state == &"loaded" else 1.0
	var duration := float(CATALOG.device_tier(&"device.youtiao_fryer", tier).get("duration_seconds", 10.0))
	return clampf(float(_machine.get("cooking_elapsed_seconds", 0.0)) / maxf(duration, 0.001), 0.0, 1.0)


func _cooked_color(state: StringName) -> Color:
	if state == &"burnt":
		return Color(0.22, 0.14, 0.08, 1.0)
	if state == &"overcooking":
		var loss := clampf((100.0 - float(_machine.get("quality", 100.0))) / 40.0, 0.0, 1.0)
		return Color.WHITE.lerp(Color(0.58, 0.28, 0.10, 1.0), loss)
	return Color.WHITE


func _stage_rect_to_food_layer(stage_rect: Rect2) -> Rect2:
	var local_start := _stage_point_to_food_layer(stage_rect.position)
	var local_end := _stage_point_to_food_layer(stage_rect.end)
	return Rect2(local_start, local_end - local_start)


func _stage_point_to_food_layer(stage_point: Vector2) -> Vector2:
	var canvas_point: Vector2 = machine_stage.get_global_transform_with_canvas() * stage_point
	return food_layer.get_global_transform_with_canvas().affine_inverse() * canvas_point


static func _food_rects(tier: int, raised: bool) -> Array[Rect2]:
	var clamped_tier := clampi(tier, 0, 2)
	var columns: int = [2, 3, 4][clamped_tier]
	var slot_size: Vector2 = [Vector2(30, 22), Vector2(26, 21), Vector2(24, 20)][clamped_tier]
	var column_gap: float = [10.0, 6.0, 4.0][clamped_tier]
	var row_gap := 4.0
	var center_x := 174.0
	var total_width := float(columns) * slot_size.x + float(columns - 1) * column_gap
	var start_x := center_x - total_width * 0.5
	var start_y := 25.0 if raised else 35.0
	var result: Array[Rect2] = []
	for row in range(2):
		for column in range(columns):
			result.append(Rect2(
				Vector2(start_x + float(column) * (slot_size.x + column_gap), start_y + float(row) * (slot_size.y + row_gap)),
				slot_size,
			))
	while result.size() < 8:
		result.append(Rect2())
	return result


static func _front_clip_top(tier: int, raised: bool) -> float:
	var clamped_tier := clampi(tier, 0, 2)
	return [44.0, 45.0, 32.0][clamped_tier] if raised else [64.0, 64.0, 66.0][clamped_tier]


static func _snapshot_signature(snapshot: Dictionary) -> String:
	return "%s|%d|%s|%d|%s|%s|%s|%s" % [
		str(snapshot.get("state", &"unowned")),
		int(snapshot.get("tier", 0)),
		str(snapshot.get("recipe_id", &"")),
		int(snapshot.get("quantity", 0)),
		str(Array(snapshot.get("occupied_slot_indices", []))),
		str(Array(snapshot.get("unlocked_automation_ids", []))),
		str(Array(snapshot.get("owned_assist_ids", []))),
		str(bool(snapshot.get("auto_lift_enabled", false))),
	]


func _occupied_slots() -> Array[int]:
	var result: Array[int] = []
	if _machine.has("occupied_slot_indices"):
		for value in Array(_machine.get("occupied_slot_indices", [])):
			result.append(int(value))
	else:
		for slot_index in range(clampi(int(_machine.get("quantity", 0)), 0, food_slots.size())):
			result.append(slot_index)
	return result


func _owns_automation(automation_id: StringName) -> bool:
	return _contains_id(Array(_machine.get("unlocked_automation_ids", [])), automation_id)


func _owns_assist(assist_id: StringName) -> bool:
	return _contains_id(Array(_machine.get("owned_assist_ids", [])), assist_id)


static func _contains_id(values: Array, expected: StringName) -> bool:
	return values.has(expected) or values.has(str(expected))


static func _texture_at(textures: Array[Texture2D], index: int) -> Texture2D:
	return textures[index] if index >= 0 and index < textures.size() else null


static func _state_text(state: StringName) -> String:
	return {
		&"idle": "空炸篮",
		&"loaded": "面胚已装入",
		&"frying": "炸制中",
		&"ready_safe": "可升篮",
		&"overcooking": "即将过火",
		&"draining": "沥油中",
		&"ready_to_collect": "整锅可收纳",
		&"burnt": "已焦糊，需报废",
	}.get(state, "")
