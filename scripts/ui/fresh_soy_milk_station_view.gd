class_name FreshSoyMilkStationView
extends "res://scripts/ui/five_area_station_view.gd"

const RECIPE_IDS: Array[StringName] = [
	&"recipe.fresh_soy_milk.yellow_bean",
	&"recipe.fresh_soy_milk.black_bean",
	&"recipe.fresh_soy_milk.red_bean",
	&"recipe.fresh_soy_milk.multigrain",
]

@onready var state_label: Label = %StateLabel
@onready var recipe_buttons: Array[Button] = [%YellowBeanButton, %BlackBeanButton, %RedBeanButton, %MultigrainButton]
@onready var load_button: Button = %LoadButton
@onready var water_button: Button = %WaterButton
@onready var start_button: Button = %StartButton
@onready var collect_button: Button = %CollectButton
@onready var output_buttons: Array[Button] = [%OutputSlot01, %OutputSlot02, %OutputSlot03, %OutputSlot04]

var _selected_recipe_id: StringName = RECIPE_IDS[0]


func _ready() -> void:
	for index in range(recipe_buttons.size()):
		recipe_buttons[index].pressed.connect(func(recipe_index := index): _select_recipe(recipe_index))
	load_button.pressed.connect(func(): request_intent(&"load", {"recipe_id": _selected_recipe_id, "quantity": 1}))
	water_button.pressed.connect(func(): request_intent(&"add_water"))
	start_button.pressed.connect(func(): request_intent(&"start"))
	collect_button.pressed.connect(_request_machine_collect)
	for index in range(output_buttons.size()):
		output_buttons[index].pressed.connect(func(slot_index := index): _request_output(slot_index))
	_refresh_from_snapshot()


func _select_recipe(index: int) -> void:
	if index < 0 or index >= RECIPE_IDS.size() or recipe_buttons[index].disabled:
		return
	_selected_recipe_id = RECIPE_IDS[index]
	_refresh_from_snapshot()


func _request_machine_collect() -> void:
	if StringName(_snapshot.get("state", &"")) == &"spoiled":
		request_intent(&"discard", {"slot_index": -1})
	else:
		request_intent(&"collect", {"quantity": 1})


func _request_output(slot_index: int) -> void:
	var rack := Array(_snapshot.get("output_rack", []))
	var cup := Dictionary(rack[slot_index]) if slot_index >= 0 and slot_index < rack.size() else {}
	if StringName(cup.get("state", &"")) == &"spoiled":
		request_intent(&"discard", {"slot_index": slot_index})
	else:
		request_intent(&"collect_output", {"slot_index": slot_index})


func _refresh_from_snapshot() -> void:
	if not is_node_ready():
		return
	var state := StringName(_snapshot.get("state", &"unowned"))
	state_label.text = "现磨豆浆 · %s" % _state_label(state)
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
	load_button.disabled = not enabled or state != &"idle"
	water_button.disabled = not enabled or state != &"loaded"
	start_button.disabled = not enabled or state != &"water_added"
	collect_button.text = "丢弃废料" if state == &"spoiled" else "接杯"
	collect_button.disabled = not enabled or state not in [&"ready_safe", &"overcooking", &"spoiled"]
	var rack := Array(_snapshot.get("output_rack", []))
	for index in range(output_buttons.size()):
		var cup := Dictionary(rack[index]) if index < rack.size() else {}
		output_buttons[index].text = "杯位%d · %s" % [index + 1, "空" if cup.is_empty() else _state_label(StringName(cup.get("state", &"ready_safe")))]
		output_buttons[index].disabled = not enabled or cup.is_empty()


func _state_label(state: StringName) -> String:
	return {
		&"unowned": "未安装",
		&"idle": "待机",
		&"loaded": "已选豆料",
		&"water_added": "已加水",
		&"grinding": "研磨中",
		&"ready_safe": "可接杯",
		&"overcooking": "即将变质",
		&"spoiled": "已变质",
	}.get(state, str(state))
