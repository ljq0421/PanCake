class_name DirectSoyStation
extends Control

signal status_message(message: String)

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const PRODUCT_VISUALS := preload("res://scripts/ui/five_area_product_visuals.gd")
const RECIPE_IDS: Array[StringName] = [
	&"recipe.fresh_soy_milk.yellow_bean",
	&"recipe.fresh_soy_milk.black_bean",
	&"recipe.fresh_soy_milk.red_bean",
	&"recipe.fresh_soy_milk.multigrain",
]
const STOCK_IDS: Array[StringName] = [
	&"stock.fresh_soy_milk.yellow_bean",
	&"stock.fresh_soy_milk.black_bean",
	&"stock.fresh_soy_milk.red_bean",
	&"stock.fresh_soy_milk.multigrain",
]

@onready var ingredient_sources: Array[ProductDragSource] = [%Ingredient01, %Ingredient02, %Ingredient03, %Ingredient04]
@onready var ingredient_counts: Array[Label] = [%Count01, %Count02, %Count03, %Count04]
@onready var restock_buttons: Array[RestockHoldButton] = [%Restock01, %Restock02, %Restock03, %Restock04]
@onready var water_button: Button = %WaterButton
@onready var start_button: Button = %StartButton
@onready var machine_output: ProductDragSource = %MachineOutput
@onready var rack_outputs: Array[ProductDragSource] = [%RackOutput01, %RackOutput02, %RackOutput03, %RackOutput04]
@onready var state_label: Label = %StateLabel
@onready var lock_cover: Button = %LockCover

var _refresh_elapsed := 0.0


func _ready() -> void:
	water_button.pressed.connect(_perform_action.bind(&"add_water"))
	start_button.pressed.connect(_perform_action.bind(&"start"))
	for button in restock_buttons:
		button.restock_feedback.connect(_on_restock_feedback)
	lock_cover.pressed.connect(_on_lock_cover_pressed)
	refresh_from_session()


func _process(delta: float) -> void:
	_refresh_elapsed += delta
	if _refresh_elapsed >= 0.10:
		_refresh_elapsed = 0.0
		refresh_from_session()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and StringName(Dictionary(data).get("kind", &"")) == &"product_source" and StringName(Dictionary(Dictionary(data).get("source_ref", {})).get("source_kind", &"")) == &"soy_ingredient"


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var source_ref := Dictionary(Dictionary(data).get("source_ref", {}))
	var session := get_node_or_null("/root/GameSession")
	var result: Dictionary = session.call("load_f4_soy", StringName(source_ref.get("recipe_id", &"")), 1) if session != null else {"success": false, "reason": &"no_game_session"}
	status_message.emit("豆料已倒入料口" if bool(result.get("success", false)) else "豆料回到原位：%s" % str(result.get("reason", &"unknown")))
	refresh_from_session()


func refresh_from_session() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return
	var progression := Dictionary(session.call("five_area_progression_snapshot"))
	var unlocked_area := Array(progression.get("unlocked_area_ids", [])).has("area.fresh_soy_milk")
	var unlocked_recipes := PackedStringArray(Array(progression.get("unlocked_recipe_ids", [])))
	var inventory := Dictionary(session.call("inventory_snapshot"))
	var machine := Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine"))
	lock_cover.visible = not unlocked_area
	for index in range(RECIPE_IDS.size()):
		var recipe_id := RECIPE_IDS[index]
		var product_id := StringName(CATALOG.recipe_definition(recipe_id).get("product_id", &""))
		var count := int(inventory.get(str(STOCK_IDS[index]), 0))
		var unlocked := unlocked_area and unlocked_recipes.has(str(recipe_id))
		ingredient_sources[index].configure({"source_kind": &"soy_ingredient", "source_index": index, "product_id": product_id, "recipe_id": recipe_id}, ingredient_sources[index].texture_normal, unlocked and count > 0, "拖入豆浆机料口")
		ingredient_sources[index].visible = unlocked
		ingredient_counts[index].text = str(count) if unlocked else "锁"
		restock_buttons[index].configure(STOCK_IDS[index], unlocked, "按住补充豆料")
	var state := StringName(machine.get("state", &"unowned"))
	water_button.disabled = state != &"loaded"
	start_button.disabled = state not in [&"watered", &"loaded"]
	var recipe_id := StringName(machine.get("recipe_id", &""))
	var product_id := StringName(CATALOG.recipe_definition(recipe_id).get("product_id", &""))
	machine_output.configure({"source_kind": &"soy_output", "source_index": -1, "product_id": product_id}, PRODUCT_VISUALS.texture_for(product_id), state in [&"ready_safe", &"overcooking"], "成品已到出杯口；正式订单开放后点击订单商品交付")
	machine_output.visible = state in [&"ready_safe", &"overcooking"]
	var rack := Array(machine.get("output_rack", []))
	for rack_index in range(rack_outputs.size()):
		var cup := Dictionary(rack[rack_index]) if rack_index < rack.size() else {}
		var rack_recipe_id := StringName(cup.get("recipe_id", &""))
		var rack_product_id := StringName(CATALOG.recipe_definition(rack_recipe_id).get("product_id", &""))
		rack_outputs[rack_index].configure({"source_kind": &"soy_output", "source_index": rack_index, "product_id": rack_product_id}, PRODUCT_VISUALS.texture_for(rack_product_id), not cup.is_empty(), "接杯架成品；正式订单开放后点击订单商品交付")
		rack_outputs[rack_index].visible = not cup.is_empty()
	state_label.text = _state_text(state)


func _perform_action(action_id: StringName) -> void:
	var session := get_node_or_null("/root/GameSession")
	var result: Dictionary = session.call("perform_f4_soy_action", action_id) if session != null else {"success": false, "reason": &"no_game_session"}
	status_message.emit("已加水" if action_id == &"add_water" and bool(result.get("success", false)) else "豆浆机已启动" if bool(result.get("success", false)) else "设备没有动作：%s" % str(result.get("reason", &"unknown")))
	refresh_from_session()


func _on_restock_feedback(result: Dictionary) -> void:
	if int(result.get("completed_units", 0)) > 0:
		status_message.emit("豆料补货 +%d" % int(result.get("completed_units", 0)))


func _on_lock_cover_pressed() -> void:
	var session := get_node_or_null("/root/GameSession")
	var message := "现磨豆浆区域未解锁"
	if session != null and session.has_method("growth_missing_requirements"):
		message = str(session.call("growth_missing_requirements", &"growth.area.fresh_soy_milk"))
	status_message.emit(message)


static func _state_text(state: StringName) -> String:
	return {
		&"idle": "料口空",
		&"loaded": "豆料已装入",
		&"watered": "水已加入",
		&"grinding": "研磨中",
		&"ready_safe": "豆浆可取",
		&"overcooking": "即将变质",
		&"blocked": "接杯架已满",
		&"spoiled": "豆浆已变质",
	}.get(state, "未安装")
