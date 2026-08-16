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
]
const MACHINE_TIER_0_TEXTURE := preload("res://resources/art/workstation/expansion/machines/soy_milk_machine_tier_0_v2_chinese.png")
const MACHINE_TIER_1_TEXTURE := preload("res://resources/art/workstation/expansion/machines/soy_milk_machine_tier_1_v1_chinese.png")
const MACHINE_TIER_2_TEXTURE := preload("res://resources/art/workstation/expansion/machines/soy_milk_machine_tier_2_v1_chinese.png")
const MACHINE_ATLAS_REGION := Rect2(332, 30, 360, 458)
const INGREDIENT_TEXTURES: Array[Texture2D] = [
	preload("res://resources/art/ingredients/soybean/yellow_soybean_portion_v2_five_area_v2.png"),
	preload("res://resources/art/ingredients/beans/black_bean_portion_v1_five_area_v2.png"),
	preload("res://resources/art/ingredients/beans/red_bean_portion_v1_five_area_v2.png"),
]
const CUP_TEXTURES: Array[Texture2D] = [
	preload("res://resources/art/products/soy_milk/soy_milk_cup_yellow_bean_v3.png"),
	preload("res://resources/art/products/soy_milk/soy_milk_cup_black_bean_v3.png"),
	preload("res://resources/art/products/soy_milk/soy_milk_cup_red_bean_v3.png"),
	preload("res://resources/art/products/soy_milk/soy_milk_cup_multigrain_v3.png"),
]
const EMPTY_CUP_TEXTURE := preload("res://resources/art/products/soy_milk/soy_milk_cup_empty_v3.png")

@onready var water_button: Button = %WaterButton
@onready var start_button: Button = %StartButton
@onready var clear_hopper_button: Button = %ClearHopperButton
@onready var machine_art: TextureRect = $Machine
@onready var machine_output: ProductDragSource = %MachineOutput
@onready var rack_outputs: Array[ProductDragSource] = [%RackOutput01, %RackOutput02, %RackOutput03, %RackOutput04]
@onready var state_label: Label = %StateLabel
@onready var hopper_summary: Label = %HopperSummary
@onready var water_meter: ProgressBar = %WaterMeter
@onready var water_marker: ColorRect = %WaterMarker
@onready var water_guide_zones: Control = %WaterGuideZones
@onready var production_progress: ProgressBar = %ProductionProgress
@onready var automation_status: Label = %AutomationStatus
@onready var visual_rig: Control = %VisualRig
@onready var closed_lid_visual: TextureRect = %ClosedLidVisual
@onready var open_lid_visual: TextureRect = %OpenLidVisual
@onready var ingredient_visual: TextureRect = %IngredientVisual
@onready var water_effect: TextureRect = %WaterEffect
@onready var stream_effect: TextureRect = %StreamEffect
@onready var machine_cup_visual: TextureRect = %MachineCupVisual
@onready var steam_effect: TextureRect = %SteamEffect
@onready var spoiled_vapor: TextureRect = %SpoiledVapor
@onready var rack_spoiled_vapor: TextureRect = %RackSpoiledVapor
@onready var lock_cover: Button = %LockCover

var _refresh_elapsed := 0.0
var _machine_art_by_tier: Dictionary = {}
var _last_state: StringName = &"unowned"
var _last_rack_count := 0
var _visual_time := 0.0
var _machine_rest_position := Vector2.ZERO


func _ready() -> void:
	_machine_art_by_tier = {
		0: _atlas_crop(MACHINE_TIER_0_TEXTURE),
		1: _atlas_crop(MACHINE_TIER_1_TEXTURE),
		2: _atlas_crop(MACHINE_TIER_2_TEXTURE),
	}
	water_button.pressed.connect(_toggle_water)
	start_button.pressed.connect(_perform_action.bind(&"start"))
	clear_hopper_button.pressed.connect(_perform_action.bind(&"clear_hopper"))
	lock_cover.pressed.connect(_on_lock_cover_pressed)
	_machine_rest_position = machine_art.position
	refresh_from_session()


func _process(delta: float) -> void:
	_visual_time += maxf(delta, 0.0)
	var grinding := _last_state == &"grinding"
	machine_art.position = _machine_rest_position + Vector2(sin(_visual_time * 32.0) * 1.8, 0.0) if grinding else _machine_rest_position
	if steam_effect.visible:
		steam_effect.position.y = 76.0 + sin(_visual_time * 2.8) * 3.0
	if spoiled_vapor.visible:
		spoiled_vapor.position.y = 68.0 + sin(_visual_time * 2.1) * 3.0
	if rack_spoiled_vapor.visible:
		rack_spoiled_vapor.position.y = 106.0 + sin(_visual_time * 2.4) * 2.0
	_refresh_elapsed += delta
	if _refresh_elapsed >= 0.10:
		_refresh_elapsed = 0.0
		refresh_from_session()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and StringName(Dictionary(data).get("kind", &"")) == &"product_source" and StringName(Dictionary(Dictionary(data).get("source_ref", {})).get("source_kind", &"")) == &"soy_ingredient"


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var source_ref := Dictionary(Dictionary(data).get("source_ref", {}))
	var session := get_node_or_null("/root/GameSession")
	var result: Dictionary = session.call("add_f4_soy_ingredient", StringName(source_ref.get("stock_id", &""))) if session != null else {"success": false, "reason": &"no_game_session"}
	status_message.emit("豆料已倒入料口" if bool(result.get("success", false)) else "豆料回到原位：%s" % str(result.get("reason", &"unknown")))
	if bool(result.get("success", false)):
		_animate_ingredient_load(StringName(source_ref.get("stock_id", &"")))
	refresh_from_session()


func refresh_from_session() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return
	var progression := Dictionary(session.call("five_area_progression_snapshot"))
	var unlocked_area := Array(progression.get("unlocked_area_ids", [])).has("area.fresh_soy_milk")
	var machine := Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine"))
	# The stall artwork provides the closed-machine presentation.  Keep this
	# operational overlay out of view until the soy station is actually owned.
	visible = unlocked_area
	_refresh_machine_artwork(int(machine.get("tier", 0)))
	lock_cover.visible = false
	var state := StringName(machine.get("state", &"unowned"))
	var water_filling := bool(machine.get("water_filling", false))
	water_button.disabled = state != &"loaded"
	water_button.text = "停水" if water_filling else "注水"
	start_button.disabled = state != &"water_added"
	var auto_cup_owned := _contains_id(Array(progression.get("unlocked_automation_ids", [])), &"automation.fresh_soy_milk.auto_cup_rack")
	clear_hopper_button.visible = unlocked_area
	clear_hopper_button.disabled = state != &"loaded" or water_filling
	var recipe_id := StringName(machine.get("recipe_id", &""))
	var product_id := StringName(CATALOG.recipe_definition(recipe_id).get("product_id", &""))
	var machine_spoiled := state == &"spoiled"
	var machine_cup_ready := state in [&"ready_safe", &"overcooking"]
	machine_output.configure({"source_kind": &"soy_output", "source_index": -1, "product_id": product_id, "discardable": machine_spoiled}, PRODUCT_VISUALS.texture_for(product_id), machine_cup_ready or machine_spoiled, "豆浆已变质，请拖到垃圾桶丢弃" if machine_spoiled else "成品杯可直接拖拽交付")
	machine_output.visible = machine_cup_ready or machine_spoiled
	var rack := Array(machine.get("output_rack", []))
	var spoiled_rack_present := false
	var rack_count := 0
	for rack_index in range(rack_outputs.size()):
		var cup := Dictionary(rack[rack_index]) if rack_index < rack.size() else {}
		var cup_spoiled := StringName(cup.get("state", &"")) == &"spoiled"
		spoiled_rack_present = spoiled_rack_present or cup_spoiled
		if not cup.is_empty():
			rack_count += 1
		var rack_recipe_id := StringName(cup.get("recipe_id", &""))
		var rack_product_id := StringName(CATALOG.recipe_definition(rack_recipe_id).get("product_id", &""))
		rack_outputs[rack_index].configure({"source_kind": &"soy_output", "source_index": rack_index, "product_id": rack_product_id, "discardable": cup_spoiled}, PRODUCT_VISUALS.texture_for(rack_product_id), not cup.is_empty(), "豆浆已变质，请拖到垃圾桶丢弃" if cup_spoiled else "接杯架成品；正式订单开放后点击订单商品交付")
		rack_outputs[rack_index].visible = not cup.is_empty()
	_refresh_visual_layers(state, recipe_id, machine_spoiled, spoiled_rack_present, machine_cup_ready, unlocked_area)
	if _last_state == &"grinding" and state in [&"ready_safe", &"overcooking", &"blocked"]:
		_animate_dispense()
	if rack_count > _last_rack_count:
		_animate_rack_transfer()
	_last_state = state
	_last_rack_count = rack_count
	state_label.text = "豆浆已变质，请拖到废弃区" if machine_spoiled or spoiled_rack_present else _timed_state_text(state, machine)
	_refresh_operation_summary(machine, progression)


func _refresh_machine_artwork(machine_tier: int) -> void:
	machine_art.texture = _machine_art_by_tier.get(machine_tier, _machine_art_by_tier[0]) as AtlasTexture


static func _atlas_crop(source: Texture2D) -> AtlasTexture:
	var cropped := AtlasTexture.new()
	cropped.atlas = source
	cropped.region = MACHINE_ATLAS_REGION
	return cropped


func _perform_action(action_id: StringName) -> void:
	var session := get_node_or_null("/root/GameSession")
	var result: Dictionary = session.call("perform_f4_soy_action", action_id) if session != null else {"success": false, "reason": &"no_game_session"}
	status_message.emit("料仓已清空并计入废弃" if action_id == &"clear_hopper" and bool(result.get("success", false)) else "豆浆机已启动" if action_id == &"start" and bool(result.get("success", false)) else "设备没有动作：%s" % str(result.get("reason", &"unknown")))
	if bool(result.get("success", false)):
		_animate_start() if action_id == &"start" else _animate_water_and_close()
	refresh_from_session()


func _toggle_water() -> void:
	var session := get_node_or_null("/root/GameSession")
	var machine := Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine")) if session != null else {}
	var action := &"stop_water" if bool(machine.get("water_filling", false)) else &"start_water"
	var result: Dictionary = session.call("perform_f4_soy_action", action) if session != null else {"success": false, "reason": &"no_game_session"}
	if bool(result.get("success", false)):
		status_message.emit("水量 %.0f · %s级" % [float(result.get("water_value", 0.0)), str(result.get("grade", "注水中"))])
		_animate_water_and_close()
	else:
		status_message.emit("注水没有动作：%s" % str(result.get("reason", &"unknown")))
	refresh_from_session()


func _refresh_visual_layers(state: StringName, recipe_id: StringName, machine_spoiled: bool, rack_spoiled: bool, manual_cup_ready: bool, unlocked_area: bool) -> void:
	var recipe_index := maxi(RECIPE_IDS.find(recipe_id), 0)
	closed_lid_visual.visible = state != &"loaded"
	open_lid_visual.visible = state == &"loaded"
	machine_cup_visual.texture = CUP_TEXTURES[recipe_index] if manual_cup_ready or machine_spoiled else EMPTY_CUP_TEXTURE
	machine_cup_visual.visible = unlocked_area
	steam_effect.visible = state in [&"ready_safe", &"overcooking", &"blocked"]
	spoiled_vapor.visible = machine_spoiled
	rack_spoiled_vapor.visible = rack_spoiled


static func _contains_id(values: Array, expected: StringName) -> bool:
	return values.has(expected) or values.has(str(expected))


func _animate_ingredient_load(stock_id: StringName) -> void:
	var recipe_index := maxi(STOCK_IDS.find(stock_id), 0)
	ingredient_visual.texture = INGREDIENT_TEXTURES[recipe_index]
	ingredient_visual.position = Vector2(128.0, 4.0)
	ingredient_visual.modulate = Color.WHITE
	ingredient_visual.visible = true
	open_lid_visual.visible = true
	closed_lid_visual.visible = false
	var tween := create_tween().set_parallel(true)
	tween.tween_property(ingredient_visual, "position", Vector2(128.0, 70.0), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(ingredient_visual, "modulate:a", 0.0, 0.28)
	tween.chain().tween_callback(func(): ingredient_visual.visible = false)


func _animate_water_and_close() -> void:
	water_effect.position = Vector2(44.0, 30.0)
	water_effect.modulate.a = 0.0
	water_effect.visible = true
	var tween := create_tween()
	tween.tween_property(water_effect, "modulate:a", 1.0, 0.08)
	tween.tween_interval(0.18)
	tween.tween_property(water_effect, "modulate:a", 0.0, 0.10)
	tween.tween_callback(func(): water_effect.visible = false)


func _animate_start() -> void:
	visual_rig.pivot_offset = visual_rig.size * 0.5
	var tween := create_tween()
	tween.tween_property(visual_rig, "scale", Vector2(1.025, 0.975), 0.08)
	tween.tween_property(visual_rig, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _animate_dispense() -> void:
	stream_effect.position = Vector2(143.0, 92.0)
	stream_effect.modulate.a = 0.0
	stream_effect.visible = true
	machine_cup_visual.scale = Vector2(0.7, 0.7)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(stream_effect, "modulate:a", 1.0, 0.10)
	tween.tween_property(machine_cup_visual, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(0.16)
	tween.chain().tween_property(stream_effect, "modulate:a", 0.0, 0.10)
	tween.chain().tween_callback(func(): stream_effect.visible = false)


func _animate_rack_transfer() -> void:
	for source in rack_outputs:
		if source.visible:
			source.pivot_offset = source.size * 0.5
			source.scale = Vector2(0.72, 0.72)
			create_tween().tween_property(source, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
		&"water_added": "水已加入",
		&"grinding": "研磨中",
		&"ready_safe": "豆浆可取",
		&"overcooking": "即将变质",
		&"blocked": "接杯架已满",
		&"spoiled": "豆浆已变质",
	}.get(state, "")


static func _timed_state_text(state: StringName, machine: Dictionary) -> String:
	if state == &"loaded" and bool(machine.get("water_filling", false)):
		return "注水中 · %.0f" % float(machine.get("water_value", 0.0))
	if state == &"grinding":
		return "制作中 · %d秒" % _display_seconds(float(machine.get("seconds_to_ready", 0.0)))
	if state in [&"ready_safe", &"overcooking"]:
		if bool(machine.get("infinite_hold", false)):
			return "保温中"
		var seconds := _display_seconds(float(machine.get("seconds_to_loss", 0.0)))
		return "可取 · %d秒后变质" % seconds if state == &"ready_safe" else "变质中 · 剩余%d秒" % seconds
	return _state_text(state)


func _refresh_operation_summary(machine: Dictionary, progression: Dictionary) -> void:
	var counts := Dictionary(machine.get("ingredient_counts", {}))
	var parts := PackedStringArray()
	for stock_id in STOCK_IDS:
		var count := int(counts.get(stock_id, counts.get(str(stock_id), 0)))
		if count > 0:
			parts.append("%s×%d" % [str(CATALOG.stock_definition(stock_id).get("label", "豆料")), count])
	hopper_summary.text = "料仓：空" if parts.is_empty() else "料仓：%s" % " + ".join(parts)
	water_meter.value = float(machine.get("water_value", 0.0))
	water_marker.position.x = 8.0 + clampf(float(machine.get("water_value", 0.0)), 0.0, 100.0) * 2.87
	water_meter.tooltip_text = "绿区45–60 / 黄区25–44、61–80 / 其余红区"
	water_guide_zones.modulate.a = 1.0 if bool(machine.get("water_guide_enabled", false)) else 0.38
	var duration := float(machine.get("duration_seconds", 0.0))
	production_progress.value = 0.0 if duration <= 0.0 else clampf(float(machine.get("elapsed_seconds", 0.0)) / duration * 100.0, 0.0, 100.0)
	var automation_ids := Array(progression.get("unlocked_automation_ids", []))
	var status := PackedStringArray()
	if _contains_id(automation_ids, &"automation.fresh_soy_milk.auto_yellow_restock"):
		status.append("补货")
	if _contains_id(automation_ids, &"automation.fresh_soy_milk.auto_cup_rack"):
		status.append("接杯")
	if _contains_id(automation_ids, &"automation.fresh_soy_milk.auto_production"):
		status.append("生产")
	if _contains_id(Array(progression.get("owned_growth_ids", [])), &"growth.quality.fresh_soy_milk.max"):
		status.append("品质MAX")
	automation_status.text = "自动化：关" if status.is_empty() else "自动化：%s" % " / ".join(status)


static func _display_seconds(value: float) -> int:
	return maxi(int(ceil(maxf(value, 0.0))), 0)
