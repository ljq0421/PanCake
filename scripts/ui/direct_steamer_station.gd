class_name DirectSteamerStation
extends Control

signal status_message(message: String)

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const PRODUCT_VISUALS := preload("res://scripts/ui/five_area_product_visuals.gd")
const RECIPE_IDS: Array[StringName] = [&"recipe.steamer.mantou", &"recipe.steamer.vegetable_bun", &"recipe.steamer.meat_bun"]
const STOCK_IDS: Array[StringName] = [&"stock.steamer.mantou", &"stock.steamer.vegetable_bun", &"stock.steamer.meat_bun"]

@onready var input_sources: Array[ProductDragSource] = [%Input01, %Input02, %Input03]
@onready var input_counts: Array[Label] = [%Count01, %Count02, %Count03]
@onready var restock_buttons: Array[RestockHoldButton] = [%Restock01, %Restock02, %Restock03]
@onready var layer_targets: Array[SteamerLayerDropTarget] = [%Layer01, %Layer02, %Layer03, %Layer04]
@onready var layer_outputs: Array[ProductDragSource] = [%LayerOutput01, %LayerOutput02, %LayerOutput03, %LayerOutput04]
@onready var layer_starts: Array[Button] = [$Layer01/StartButton, $Layer02/StartButton, $Layer03/StartButton, $Layer04/StartButton]
@onready var layer_labels: Array[Label] = [%LayerLabel01, %LayerLabel02, %LayerLabel03, %LayerLabel04]
@onready var lock_cover: Button = %LockCover

var _refresh_elapsed := 0.0


func _ready() -> void:
	for target in layer_targets:
		target.layer_feedback.connect(_on_layer_feedback)
	for button in restock_buttons:
		button.restock_feedback.connect(_on_restock_feedback)
	lock_cover.pressed.connect(_on_lock_cover_pressed)
	refresh_from_session()


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
		layer_outputs[layer_index].configure({"source_kind": &"steamer_layer", "source_index": layer_index, "product_id": product_id}, PRODUCT_VISUALS.texture_for(product_id), state in [&"ready_safe", &"overcooking"], "从该层拖到顾客托盘")
		layer_outputs[layer_index].visible = state in [&"ready_safe", &"overcooking"]
		layer_labels[layer_index].text = _layer_state_text(state)


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


static func _layer_state_text(state: StringName) -> String:
	return {
		&"empty": "空层",
		&"loaded": "待启动",
		&"steaming": "蒸制中",
		&"ready_safe": "熟成",
		&"overcooking": "过熟中",
		&"spoiled": "已损坏",
	}.get(state, "锁定")
