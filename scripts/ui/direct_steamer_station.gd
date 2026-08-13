class_name DirectSteamerStation
extends Control

signal status_message(message: String)

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const PRODUCT_VISUALS := preload("res://scripts/ui/five_area_product_visuals.gd")
const RECIPE_IDS: Array[StringName] = [&"recipe.steamer.mantou", &"recipe.steamer.vegetable_bun", &"recipe.steamer.meat_bun"]
const STOCK_IDS: Array[StringName] = [&"stock.steamer.mantou", &"stock.steamer.vegetable_bun", &"stock.steamer.meat_bun"]
const LID_TRANSITION_SECONDS := 0.22
const MACHINE_DISPLAY_WIDTH := 300.0
const MACHINE_DISPLAY_BOTTOM := 217.0
const CLOSED_MACHINE_TEXTURES: Array[Texture2D] = [
	preload("res://resources/art/workstation/expansion/machines/steamer_tier_1_closed_five_area_v6_chinese.png"),
	preload("res://resources/art/workstation/expansion/machines/steamer_tier_2_closed_five_area_v6_chinese.png"),
	preload("res://resources/art/workstation/expansion/machines/steamer_tier_3_closed_five_area_v6_chinese.png"),
]
const OPEN_MACHINE_TEXTURES: Array[Texture2D] = [
	preload("res://resources/art/workstation/expansion/machines/steamer_tier_1_open_five_area_v6_chinese.png"),
	preload("res://resources/art/workstation/expansion/machines/steamer_tier_2_open_five_area_v6_chinese.png"),
	preload("res://resources/art/workstation/expansion/machines/steamer_tier_3_open_five_area_v6_chinese.png"),
]
const MACHINE_BOUNDS: Array[Rect2] = [
	Rect2(159, 645, 706, 883),
	Rect2(159, 492, 706, 1036),
	Rect2(159, 20, 706, 1508),
]

@onready var input_sources: Array[ProductDragSource] = [%Input01, %Input02, %Input03]
@onready var input_counts: Array[Label] = [%Count01, %Count02, %Count03]
@onready var restock_buttons: Array[RestockHoldButton] = [%Restock01, %Restock02, %Restock03]
@onready var layer_targets: Array[SteamerLayerDropTarget] = [%Layer01, %Layer02, %Layer03, %Layer04]
@onready var layer_outputs: Array[ProductDragSource] = [%LayerOutput01, %LayerOutput02, %LayerOutput03, %LayerOutput04]
@onready var layer_starts: Array[Button] = [$Layer01/StartButton, $Layer02/StartButton, $Layer03/StartButton, $Layer04/StartButton]
@onready var layer_labels: Array[Label] = [%LayerLabel01, %LayerLabel02, %LayerLabel03, %LayerLabel04]
@onready var closed_machine_visual: TextureRect = %ClosedMachineVisual
@onready var open_machine_visual: TextureRect = %OpenMachineVisual
@onready var lock_cover: Button = %LockCover

var _refresh_elapsed := 0.0
var _active_lid_drags := 0
var _art_signature := Vector3i(-1, -1, -1)
var _lid_is_open := false
var _lid_tween: Tween


func _ready() -> void:
	for source in input_sources + layer_outputs:
		source.drag_started.connect(_on_steamer_drag_started)
		source.drag_ended.connect(_on_steamer_drag_ended)
	for target in layer_targets:
		target.layer_feedback.connect(_on_layer_feedback)
	for button in restock_buttons:
		button.restock_feedback.connect(_on_restock_feedback)
	lock_cover.pressed.connect(_on_lock_cover_pressed)
	refresh_from_session()


func _exit_tree() -> void:
	_cancel_lid_tween()


func _process(delta: float) -> void:
	_refresh_elapsed += delta
	if _refresh_elapsed >= 0.10:
		_refresh_elapsed = 0.0
		refresh_from_session()


func refresh_from_session() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return
	var progression := Dictionary(session.call("five_area_progression_snapshot"))
	var unlocked_area := Array(progression.get("unlocked_area_ids", [])).has("area.steamer")
	var unlocked_recipes := PackedStringArray(Array(progression.get("unlocked_recipe_ids", [])))
	var inventory := Dictionary(session.call("inventory_snapshot"))
	var machine := Dictionary(session.call("f3_machine_snapshot", &"device.steamer"))
	_apply_snapshot(machine, unlocked_area, unlocked_recipes, inventory)


func apply_visual_snapshot(machine: Dictionary, unlocked_area: bool = true, unlocked_recipes: PackedStringArray = PackedStringArray(["recipe.steamer.mantou", "recipe.steamer.vegetable_bun", "recipe.steamer.meat_bun"]), inventory: Dictionary = {}) -> void:
	_apply_snapshot(machine, unlocked_area, unlocked_recipes, inventory)


func _apply_snapshot(machine: Dictionary, unlocked_area: bool, unlocked_recipes: PackedStringArray, inventory: Dictionary) -> void:
	_refresh_machine_art(int(machine.get("tier", 0)), int(machine.get("layer_capacity", 0)), unlocked_area)
	lock_cover.visible = not unlocked_area
	for index in range(RECIPE_IDS.size()):
		var recipe_id := RECIPE_IDS[index]
		var product_id := StringName(CATALOG.recipe_definition(recipe_id).get("product_id", &""))
		var count := int(inventory.get(str(STOCK_IDS[index]), 0))
		var unlocked := unlocked_area and unlocked_recipes.has(str(recipe_id))
		input_sources[index].configure({"source_kind": &"steamer_input", "source_index": index, "product_id": product_id, "recipe_id": recipe_id}, input_sources[index].texture_normal, unlocked and count > 0, "拖入指定蒸笼层")
		input_sources[index].visible = unlocked
		input_counts[index].text = str(count) if unlocked else "锁"
		restock_buttons[index].configure(STOCK_IDS[index], unlocked, "按住补充半成品")
	var layers := Array(machine.get("layers", []))
	for layer_index in range(layer_targets.size()):
		var layer := Dictionary(layers[layer_index]) if layer_index < layers.size() else {"state": &"locked"}
		var state := StringName(layer.get("state", &"locked"))
		var recipe_id := StringName(layer.get("recipe_id", &""))
		var product_id := StringName(CATALOG.recipe_definition(recipe_id).get("product_id", &""))
		layer_targets[layer_index].visible = state != &"locked"
		layer_starts[layer_index].visible = state == &"loaded"
		var output_visible := state in [&"ready_safe", &"overcooking", &"spoiled"]
		var hint := "已蒸坏，只能拖到废弃区" if state == &"spoiled" else "可交付，也可拖到废弃区"
		layer_outputs[layer_index].configure({"source_kind": &"steamer_layer", "source_index": layer_index, "product_id": product_id, "discardable": true}, PRODUCT_VISUALS.texture_for(product_id), output_visible, hint)
		layer_outputs[layer_index].visible = output_visible
		layer_labels[layer_index].text = _layer_state_text(state, layer)


func _on_layer_feedback(result: Dictionary) -> void:
	status_message.emit("蒸笼部件已动作" if bool(result.get("success", false)) else "操作未完成：%s" % str(result.get("reason", &"unknown")))
	refresh_from_session()


func _on_restock_feedback(result: Dictionary) -> void:
	if int(result.get("completed_units", 0)) > 0:
		status_message.emit("蒸品半成品补货 +%d" % int(result.get("completed_units", 0)))


func _on_lock_cover_pressed() -> void:
	var session := get_node_or_null("/root/GameSession")
	var message := "蒸笼区域未解锁"
	if session != null and session.has_method("growth_missing_requirements"):
		message = str(session.call("growth_missing_requirements", &"growth.area.steamer"))
	status_message.emit(message)


func _refresh_machine_art(machine_tier: int, capacity: int, unlocked: bool) -> void:
	var tier := clampi(machine_tier, 0, 2)
	closed_machine_visual.texture = _atlas_crop(CLOSED_MACHINE_TEXTURES[tier], MACHINE_BOUNDS[tier])
	open_machine_visual.texture = _atlas_crop(OPEN_MACHINE_TEXTURES[tier], MACHINE_BOUNDS[tier])
	_layout_machine_visual(MACHINE_BOUNDS[tier])
	var signature := Vector3i(tier, capacity, 1 if unlocked else 0)
	if signature != _art_signature:
		_art_signature = signature
		_active_lid_drags = 0
		_set_lid_open(false, true)
	closed_machine_visual.visible = unlocked
	if not unlocked:
		open_machine_visual.visible = false


func _layout_machine_visual(region: Rect2) -> void:
	var display_height := MACHINE_DISPLAY_WIDTH * region.size.y / region.size.x
	var left := (size.x - MACHINE_DISPLAY_WIDTH) * 0.5
	for visual in [closed_machine_visual, open_machine_visual]:
		visual.position = Vector2(left, MACHINE_DISPLAY_BOTTOM - display_height)
		visual.size = Vector2(MACHINE_DISPLAY_WIDTH, display_height)


func _on_steamer_drag_started(_source_ref: Dictionary) -> void:
	if not closed_machine_visual.visible:
		return
	_active_lid_drags += 1
	_set_lid_open(true)


func _on_steamer_drag_ended(_source_ref: Dictionary, _successful: bool) -> void:
	_active_lid_drags = maxi(_active_lid_drags - 1, 0)
	if _active_lid_drags == 0:
		_set_lid_open(false)


func _set_lid_open(value: bool, immediate: bool = false) -> void:
	_lid_is_open = value and closed_machine_visual.visible
	_cancel_lid_tween()
	if immediate:
		closed_machine_visual.modulate.a = 0.0 if _lid_is_open else 1.0
		open_machine_visual.modulate.a = 1.0 if _lid_is_open else 0.0
		open_machine_visual.visible = _lid_is_open
		return
	open_machine_visual.visible = true
	_lid_tween = create_tween().set_parallel(true)
	_lid_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_lid_tween.tween_property(closed_machine_visual, "modulate:a", 0.0 if _lid_is_open else 1.0, LID_TRANSITION_SECONDS)
	_lid_tween.tween_property(open_machine_visual, "modulate:a", 1.0 if _lid_is_open else 0.0, LID_TRANSITION_SECONDS)
	_lid_tween.finished.connect(_on_lid_transition_finished.bind(_lid_is_open), CONNECT_ONE_SHOT)


func _on_lid_transition_finished(open_at_completion: bool) -> void:
	if open_at_completion != _lid_is_open:
		return
	if not _lid_is_open:
		open_machine_visual.visible = false
	_lid_tween = null


func _cancel_lid_tween() -> void:
	if _lid_tween != null and _lid_tween.is_valid():
		_lid_tween.kill()
	_lid_tween = null


func is_lid_open() -> bool:
	return _lid_is_open


static func _atlas_crop(source: Texture2D, region: Rect2) -> AtlasTexture:
	var cropped := AtlasTexture.new()
	cropped.atlas = source
	cropped.region = region
	return cropped


static func _layer_state_text(state: StringName, layer: Dictionary = {}) -> String:
	if state == &"steaming":
		return "蒸制中 · %d秒" % _display_seconds(float(layer.get("seconds_to_ready", 0.0)))
	if state in [&"ready_safe", &"overcooking"]:
		if bool(layer.get("infinite_hold", false)):
			return "保温中"
		var seconds := _display_seconds(float(layer.get("seconds_to_loss", 0.0)))
		return "成熟 · %d秒后蒸坏" % seconds if state == &"ready_safe" else "过熟中 · 剩余%d秒" % seconds
	return {
		&"empty": "空层",
		&"loaded": "待启动",
		&"spoiled": "已蒸坏 · 拖到废弃区",
	}.get(state, "锁定")


static func _display_seconds(value: float) -> int:
	return maxi(int(ceil(maxf(value, 0.0))), 0)
