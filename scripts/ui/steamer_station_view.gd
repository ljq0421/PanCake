class_name SteamerStationView
extends "res://scripts/ui/five_area_station_view.gd"

const RECIPE_IDS: Array[StringName] = [
	&"recipe.steamer.mantou",
	&"recipe.steamer.vegetable_bun",
	&"recipe.steamer.meat_bun",
]

@onready var state_label: Label = %StateLabel
@onready var recipe_buttons: Array[Button] = [%MantouButton, %VegetableBunButton, %MeatBunButton]
@onready var layer_buttons: Array[Button] = [%Layer01, %Layer02, %Layer03, %Layer04]

var _selected_recipe_id: StringName = RECIPE_IDS[0]


func _ready() -> void:
	for index in range(recipe_buttons.size()):
		recipe_buttons[index].pressed.connect(func(recipe_index := index): _select_recipe(recipe_index))
	for index in range(layer_buttons.size()):
		layer_buttons[index].pressed.connect(func(layer_index := index): _request_layer_intent(layer_index))
	_refresh_from_snapshot()


func _select_recipe(index: int) -> void:
	if index < 0 or index >= RECIPE_IDS.size() or recipe_buttons[index].disabled:
		return
	_selected_recipe_id = RECIPE_IDS[index]
	_refresh_from_snapshot()


func _request_layer_intent(layer_index: int) -> void:
	var layers := Array(_snapshot.get("layers", []))
	var layer := Dictionary(layers[layer_index]) if layer_index < layers.size() else {}
	var state := StringName(layer.get("state", &"locked"))
	match state:
		&"empty": request_intent(&"load", {"layer_index": layer_index, "recipe_id": _selected_recipe_id, "quantity": 1})
		&"loaded": request_intent(&"start", {"layer_index": layer_index})
		&"ready_safe", &"overcooking": request_intent(&"collect", {"layer_index": layer_index})
		&"spoiled": request_intent(&"discard", {"layer_index": layer_index})


func _refresh_from_snapshot() -> void:
	if not is_node_ready():
		return
	var enabled := _interaction_enabled and not _locked
	var unlocked_recipes: Array = Array(_snapshot.get("unlocked_recipe_ids", []))
	if not unlocked_recipes.has(str(_selected_recipe_id)) and not unlocked_recipes.has(_selected_recipe_id):
		for recipe_id in RECIPE_IDS:
			if unlocked_recipes.has(str(recipe_id)) or unlocked_recipes.has(recipe_id):
				_selected_recipe_id = recipe_id
				break
	for index in range(recipe_buttons.size()):
		var recipe_id := RECIPE_IDS[index]
		var unlocked := unlocked_recipes.has(str(recipe_id)) or unlocked_recipes.has(recipe_id)
		recipe_buttons[index].disabled = not enabled or not unlocked
		recipe_buttons[index].button_pressed = recipe_id == _selected_recipe_id
	state_label.text = "多层蒸笼 · %d层" % int(_snapshot.get("layer_capacity", 0))
	var layers := Array(_snapshot.get("layers", []))
	for index in range(layer_buttons.size()):
		var layer := Dictionary(layers[index]) if index < layers.size() else {}
		var state := StringName(layer.get("state", &"locked"))
		layer_buttons[index].text = "第%d层 · %s" % [index + 1, _state_label(state)]
		layer_buttons[index].disabled = not enabled or state in [&"locked", &"steaming"]


func _state_label(state: StringName) -> String:
	return {
		&"locked": "未开放",
		&"empty": "空",
		&"loaded": "已上料",
		&"steaming": "蒸制中",
		&"ready_safe": "已熟",
		&"overcooking": "即将过熟",
		&"spoiled": "已浪费",
	}.get(state, str(state))
