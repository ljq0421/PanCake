class_name DirectYoutiaoStation
extends Control

signal status_message(message: String)

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const AUTO_LIFT := &"automation.youtiao.auto_lift"
const AUTO_LOAD := &"automation.youtiao.auto_load"
const TEMPERATURE_ASSIST := &"assist.youtiao.temperature_indicator"
const RECIPE_IDS: Array[StringName] = [&"recipe.youtiao.plain", &"recipe.youtiao.oil_cake", &"recipe.youtiao.sugar_oil_cake"]
const STOCK_IDS: Array[StringName] = [&"stock.youtiao.plain_dough", &"stock.youtiao.oil_cake_dough", &"stock.youtiao.sugar_oil_cake_dough"]

@export var body_textures: Array[Texture2D] = []
@export var lowered_basket_textures: Array[Texture2D] = []
@export var raised_basket_textures: Array[Texture2D] = []
@export var raw_food_textures: Array[Texture2D] = []
@export var cooked_food_textures: Array[Texture2D] = []
@export var auto_lift_texture: Texture2D
@export var auto_load_texture: Texture2D
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
@onready var auto_load_visual: TextureRect = %AutoLoadFeederVisual
@onready var food_slots: Array[Control] = [%FoodSlot01, %FoodSlot02, %FoodSlot03, %FoodSlot04]
@onready var raw_food_visuals: Array[TextureRect] = [%RawFood01, %RawFood02, %RawFood03, %RawFood04]
@onready var cooked_food_visuals: Array[TextureRect] = [%CookedFood01, %CookedFood02, %CookedFood03, %CookedFood04]
@onready var sizzle_layer: Control = $MachineStage/ArtRoot/SizzleLayer
@onready var sizzle_visuals: Array[TextureRect] = [%SizzleBubbles01, %SizzleBubbles02]
@onready var oil_drips_visual: TextureRect = %OilDripsVisual
@onready var burnt_smoke_visual: TextureRect = %BurntSmokeVisual
@onready var temperature_range_bar: YoutiaoTemperatureRangeBar = %TemperatureRangeBar
@onready var start_button: Button = %StartButton
@onready var lift_button: Button = %LiftButton
@onready var output_sources: Array[ProductDragSource] = [%OutputSlot01, %OutputSlot02, %OutputSlot03, %OutputSlot04]
# Compatibility for old tests and non-UI callers that only need a representative source.
@onready var output_source: ProductDragSource = %OutputSlot01
@onready var state_label: Label = %StateLabel
@onready var quantity_label: Label = %QuantityLabel
@onready var auto_load_panel: Panel = %AutoLoadPanel
@onready var auto_minus_button: Button = %AutoMinusButton
@onready var auto_plus_button: Button = %AutoPlusButton
@onready var auto_quantity_label: Label = %AutoQuantityLabel
@onready var auto_confirm_button: Button = %AutoConfirmButton
@onready var prepared_slots: Array[PreparedProductSlot] = [%PreparedPlain, %PreparedOilCake, %PreparedSugarOilCake]
@onready var lock_cover: Button = %LockCover

var _machine: Dictionary = {}
var _inventory: Dictionary = {}
var _unlocked_recipe_ids: Array = []
var _selected_recipe_id: StringName = RECIPE_IDS[0]
var _selected_quantity := 1
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
	auto_minus_button.pressed.connect(_change_auto_quantity.bind(-1))
	auto_plus_button.pressed.connect(_change_auto_quantity.bind(1))
	auto_confirm_button.pressed.connect(_confirm_auto_load)
	lock_cover.pressed.connect(_on_lock_cover_pressed)
	for slot in prepared_slots:
		slot.store_completed.connect(_on_prepared_store_completed)
	auto_lift_visual.texture = auto_lift_texture
	auto_load_visual.texture = auto_load_texture
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
	_unlocked_recipe_ids = unlocked_recipes.duplicate()
	_inventory = Dictionary(session.call("inventory_snapshot"))
	var snapshot := Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer"))
	snapshot["unlocked_recipe_ids"] = unlocked_recipes.duplicate()
	snapshot["unlocked_automation_ids"] = Array(progression.get("unlocked_automation_ids", [])).duplicate()
	snapshot["owned_assist_ids"] = Array(progression.get("owned_assist_ids", [])).duplicate()
	lock_cover.visible = not unlocked_area
	_apply_machine_snapshot(snapshot)
	_refresh_prepared_slots(session)
	_refresh_controls()


func apply_visual_snapshot(snapshot: Dictionary, inventory: Dictionary = {}) -> void:
	_session_refresh_enabled = false
	_inventory = inventory.duplicate(true)
	_unlocked_recipe_ids = Array(snapshot.get("unlocked_recipe_ids", RECIPE_IDS)).duplicate()
	lock_cover.visible = not bool(snapshot.get("owned", false))
	_apply_machine_snapshot(snapshot, true)
	_refresh_controls()


func resume_session_refresh() -> void:
	_session_refresh_enabled = true
	refresh_from_session()


func _refresh_prepared_slots(session: Node) -> void:
	for slot in prepared_slots:
		var status := Dictionary(session.call("prepared_product_slot_status", slot.slot_id))
		slot.configure_count(int(status.get("count", 0)), StringName(status.get("reason", &"")) != &"recipe_locked")


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
	auto_load_visual.visible = _owns_automation(AUTO_LOAD)
	_layout_food(tier, state, basket_is_raised)
	sizzle_layer.visible = state == &"frying"
	oil_drips_visual.visible = state == &"draining"
	burnt_smoke_visual.visible = state == &"burnt"
	var recipe_id := StringName(_machine.get("recipe_id", &""))
	var product_id := StringName(CATALOG.recipe_definition(recipe_id).get("product_id", &""))
	var occupied_slots := _occupied_slots()
	var recipe_index := maxi(RECIPE_IDS.find(recipe_id), 0)
	var drag_texture := _texture_at(cooked_food_textures, recipe_index) if state not in [&"loaded", &"frying"] else _texture_at(raw_food_textures, recipe_index)
	for slot_index in range(output_sources.size()):
		var source := output_sources[slot_index]
		var occupied := occupied_slots.has(slot_index)
		var hint := "可交付、暂存，或逐份拖到废弃区" if state == &"ready_to_collect" else "当前内容只能逐份拖到废弃区"
		source.configure({"source_kind": &"youtiao_output", "source_index": slot_index, "product_id": product_id, "discardable": true}, drag_texture, occupied, hint)
		source.self_modulate = Color(1.0, 1.0, 1.0, 0.01)
	temperature_range_bar.apply_snapshot(_machine, _owns_assist(TEMPERATURE_ASSIST))


func _layout_food(tier: int, state: StringName, basket_is_raised: bool) -> void:
	var recipe_id := StringName(_machine.get("recipe_id", _selected_recipe_id))
	var recipe_index := RECIPE_IDS.find(recipe_id)
	if recipe_index < 0:
		recipe_index = 0
	var occupied_slots := _occupied_slots()
	var rects := _food_rects(tier, basket_is_raised)
	var cooking_ratio := _cooking_ratio(tier, state)
	var cooked_color := _cooked_color(state)
	for index in range(food_slots.size()):
		var slot := food_slots[index]
		slot.visible = occupied_slots.has(index) and state not in [&"idle", &"unowned"]
		if not slot.visible:
			continue
		slot.position = rects[index].position
		slot.size = rects[index].size
		slot.pivot_offset = slot.size * 0.5
		slot.scale = Vector2.ONE * lerpf(0.86, 1.05, cooking_ratio)
		slot.modulate = Color.WHITE
		var raw_visual := raw_food_visuals[index]
		var cooked_visual := cooked_food_visuals[index]
		raw_visual.texture = _texture_at(raw_food_textures, recipe_index)
		cooked_visual.texture = _texture_at(cooked_food_textures, recipe_index)
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
	state_label.text = "油条炸锅 · %s" % _state_text(state)
	quantity_label.text = "×%d" % int(_machine.get("quantity", 0)) if int(_machine.get("quantity", 0)) > 0 else ""
	auto_load_panel.visible = owned and _owns_automation(AUTO_LOAD)
	auto_quantity_label.text = str(_selected_quantity)
	var max_quantity := _max_auto_quantity()
	auto_minus_button.disabled = _selected_quantity <= 1
	auto_plus_button.disabled = max_quantity <= 0 or _selected_quantity >= max_quantity
	auto_confirm_button.disabled = not _can_confirm_auto_load()


func select_recipe(recipe_id: StringName) -> bool:
	if not RECIPE_IDS.has(recipe_id) or not _contains_id(_unlocked_recipe_ids, recipe_id):
		status_message.emit("该面胚配方尚未解锁")
		return false
	_selected_recipe_id = recipe_id
	_selected_quantity = clampi(_selected_quantity, 1, maxi(_max_auto_quantity(), 1))
	_refresh_controls()
	status_message.emit("自动投胚配方已选择：%s" % _recipe_label(recipe_id))
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


func _change_auto_quantity(delta: int) -> void:
	_selected_quantity = clampi(_selected_quantity + delta, 1, maxi(_max_auto_quantity(), 1))
	_refresh_controls()


func _confirm_auto_load() -> void:
	if not _can_confirm_auto_load():
		return
	var session := get_node_or_null("/root/GameSession")
	var before_slots := _occupied_slots()
	var result: Dictionary = session.call("confirm_and_run_youtiao_auto_load", _selected_recipe_id, _selected_quantity) if session != null else {"success": false, "reason": &"no_game_session"}
	refresh_from_session()
	if not bool(result.get("success", false)):
		status_message.emit("自动装载未执行，库存未扣除：%s" % str(result.get("reason", &"unknown")))
		return
	var after_slots := _occupied_slots()
	status_message.emit("自动投胚器已装载 %d 份" % maxi(after_slots.size() - before_slots.size(), 0))
	_animate_newly_loaded_slots(before_slots, Vector2(66.0, 22.0))


func _can_confirm_auto_load() -> bool:
	if not _owns_automation(AUTO_LOAD) or _max_auto_quantity() <= 0:
		return false
	var state := StringName(_machine.get("state", &"unowned"))
	if state not in [&"idle", &"loaded"]:
		return false
	if state == &"loaded" and StringName(_machine.get("recipe_id", &"")) != _selected_recipe_id:
		return false
	return _selected_quantity <= _max_auto_quantity()


func _max_auto_quantity() -> int:
	var state := StringName(_machine.get("state", &"unowned"))
	if state not in [&"idle", &"loaded"]:
		return 0
	if state == &"loaded" and StringName(_machine.get("recipe_id", &"")) != _selected_recipe_id:
		return 0
	var capacity := int(_machine.get("capacity", 0))
	var remaining := maxi(capacity - int(_machine.get("quantity", 0)), 0)
	var recipe_index := RECIPE_IDS.find(_selected_recipe_id)
	var stock := int(_inventory.get(str(STOCK_IDS[recipe_index]), 0)) if recipe_index >= 0 else 0
	return mini(remaining, stock)


func _animate_loaded_slot(slot_index: int, start_position: Vector2) -> void:
	if slot_index < 0 or slot_index >= food_slots.size() or not food_slots[slot_index].visible:
		return
	var slot := food_slots[slot_index]
	var target := slot.position
	slot.position = start_position - slot.size * 0.5
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
	var duration := float(CATALOG.device_tier(&"device.youtiao_fryer", tier).get("duration_seconds", 12.0))
	return clampf(float(_machine.get("cooking_elapsed_seconds", 0.0)) / maxf(duration, 0.001), 0.0, 1.0)


func _cooked_color(state: StringName) -> Color:
	if state == &"burnt":
		return Color(0.22, 0.14, 0.08, 1.0)
	if state == &"overcooking":
		var loss := clampf((100.0 - float(_machine.get("quality", 100.0))) / 40.0, 0.0, 1.0)
		return Color.WHITE.lerp(Color(0.58, 0.28, 0.10, 1.0), loss)
	return Color.WHITE


static func _food_rects(tier: int, raised: bool) -> Array[Rect2]:
	if tier < 2:
		var y := 16.0 if raised else 38.0
		return [Rect2(116, y, 38, 30), Rect2(158, y, 38, 30), Rect2(), Rect2()]
	if raised:
		return [Rect2(111, 5, 32, 29), Rect2(136, 5, 32, 29), Rect2(161, 5, 32, 29), Rect2(186, 5, 32, 29)]
	return [Rect2(96, 40, 32, 29), Rect2(130, 40, 32, 29), Rect2(164, 40, 32, 29), Rect2(198, 40, 32, 29)]


static func _front_clip_top(tier: int, raised: bool) -> float:
	var clamped_tier := clampi(tier, 0, 2)
	return [44.0, 45.0, 32.0][clamped_tier] if raised else [64.0, 64.0, 66.0][clamped_tier]


static func _snapshot_signature(snapshot: Dictionary) -> String:
	return "%s|%d|%s|%d|%s|%s|%s" % [
		str(snapshot.get("state", &"unowned")),
		int(snapshot.get("tier", 0)),
		str(snapshot.get("recipe_id", &"")),
		int(snapshot.get("quantity", 0)),
		str(Array(snapshot.get("occupied_slot_indices", []))),
		str(Array(snapshot.get("unlocked_automation_ids", []))),
		str(Array(snapshot.get("owned_assist_ids", []))),
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


static func _recipe_label(recipe_id: StringName) -> String:
	return {
		&"recipe.youtiao.plain": "原味油条",
		&"recipe.youtiao.oil_cake": "油饼",
		&"recipe.youtiao.sugar_oil_cake": "糖油饼",
	}.get(recipe_id, str(recipe_id))


static func _state_text(state: StringName) -> String:
	return {
		&"idle": "空炸篮",
		&"loaded": "面胚已装入",
		&"frying": "炸制中",
		&"ready_safe": "可升篮",
		&"overcooking": "即将过火",
		&"draining": "沥油中",
		&"ready_to_collect": "可逐份取出",
		&"burnt": "已焦糊，需报废",
	}.get(state, "未安装")
