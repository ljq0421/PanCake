class_name DirectSoyStation
extends Control

signal status_message(message: String)

const PLASTIC_CUP_TEXTURE := preload("res://resources/art/products/soy_milk/soy_milk_plastic_cup_empty_cartoon_v3_512.png")
const SUGAR_JAR_TEXTURE := preload("res://assets/jianbing-stall/sugar-jar-for-soy-milk.png")
const MANUAL_DISPENSER_TEXTURE := preload("res://assets/jianbing-stall/soy-milk-dispenser.png")
const AUTO_FILL_DISPENSER_TEXTURE := preload("res://assets/jianbing-stall/automatic-soy-milk-dispenser-transparent.png")
const ADVANCED_DISPENSER_TEXTURE := preload("res://assets/jianbing-stall/automatic-soy-milk-dispenser-two-outlets-transparent.png")
const FULL_CUP_SECONDS := 0.8
const EMPTY_CUP_POSITION := Vector2(193.0, 316.0)
const SINGLE_DISPENSING_CUP_POSITION := Vector2(193.0, 318.0)
const DUAL_LEFT_CUP_POSITION := Vector2(145.0, 318.0)
const DUAL_RIGHT_CUP_POSITION := Vector2(240.0, 318.0)
# Measured on soy-milk-dispenser.png.  This is the lower opening of the tap,
# not the handle or its mounting point.
const DISPENSER_NOZZLE_OUTLET_TEXTURE_POSITION := Vector2(615.0, 1000.0)
const AUTO_FILL_NOZZLE_OUTLET_TEXTURE_POSITION := Vector2(573.0, 1040.0)
const ADVANCED_LEFT_NOZZLE_OUTLET_TEXTURE_POSITION := Vector2(488.0, 980.0)
const ADVANCED_RIGHT_NOZZLE_OUTLET_TEXTURE_POSITION := Vector2(730.0, 980.0)
const SUGAR_JAR_SPOUT := Vector2(345.0, 347.0)
const ICE_TRAY_SCOOP := Vector2(342.0, 242.0)
const WORKSHOP_LOCKED_AREA_MODULATE := Color(1.0, 1.0, 1.0, 0.42)
const FLAVOR_RECIPES: Array[StringName] = [
	&"recipe.fresh_soy_milk.yellow_bean",
]

@onready var machine_output: ProductDragSource = %MachineOutput
@onready var queued_cup_preview: TextureRect = %QueuedCupPreview
@onready var queued_cup_button: AlphaTextureHitButton = %QueuedCupButton
@onready var cup_selection_frame: Panel = %CupSelectionFrame
@onready var nozzle_button: Button = %NozzleButton
@onready var sugar_jar_visual: TextureRect = $SoyMilkSugarJar
@onready var sugar_jar: AlphaTextureHitButton = %SugarJar
@onready var ice_tray_visual: TextureRect = %IceTrayVisual
@onready var ice_button: AlphaTextureHitButton = %IceButton
@onready var soy_milk_dispenser: TextureRect = $SoyMilkDispenser
@onready var state_label: Label = %StateLabel
@onready var cup_detail_label: Label = %CupDetailLabel
@onready var dispense_progress: ProgressBar = %DispenseProgress
@onready var dispense_effect: SoyDispenseEffect = %DispenseEffect
@onready var queued_cup_effect: SoyDispenseEffect = %QueuedCupEffect
@onready var sugar_label: Label = %SugarLabel
@onready var flavor_menu: MenuButton = %FlavorMenu

# Kept for the common workstation product-source collector. The retired cup
# rack deliberately has no hidden output slots in the new interaction.
var rack_outputs: Array[ProductDragSource] = []
var lock_cover: Control = null
var _filling := false
var _held_seconds := 0.0
var _fill_guide_enabled := false
var _auto_fill_enabled := false
var _double_fill_enabled := false
var _workshop_preview := false
var _selected_cup_index := 0
var _displayed_machine_tier := 0


func _ready() -> void:
	# Ingredient controls sit exactly over the visible artwork; their alpha-aware
	# hit test ignores transparent canvas margins.
	nozzle_button.size = Vector2(112.0, 100.0)
	flavor_menu.position = Vector2(10.0, 12.0)
	flavor_menu.size = Vector2(106.0, 30.0)
	sugar_jar.position = sugar_jar_visual.position
	sugar_jar.size = sugar_jar_visual.size
	ice_button.position = ice_tray_visual.position
	ice_button.size = ice_tray_visual.size
	machine_output.short_clicked.connect(_on_cup_short_clicked)
	queued_cup_button.pressed.connect(_on_queued_cup_pressed)
	nozzle_button.button_down.connect(_on_nozzle_down)
	nozzle_button.button_up.connect(_on_nozzle_up)
	nozzle_button.pressed.connect(_on_nozzle_pressed)
	sugar_jar.pressed.connect(_on_sugar_jar_pressed)
	ice_button.pressed.connect(_on_ice_button_pressed)
	flavor_menu.get_popup().id_pressed.connect(_on_flavor_selected)
	refresh_from_session()


func _process(delta: float) -> void:
	if not _filling:
		return
	_held_seconds += maxf(delta, 0.0)
	dispense_progress.value = clampf(_held_seconds / FULL_CUP_SECONDS * 100.0, 0.0, 100.0)
	dispense_effect.set_dispense_state(true, dispense_progress.value / 100.0, _liquid_color_for_recipe(_selected_recipe_id()))
	if dispense_progress.value >= 100.0:
		state_label.text = "已满杯 · 继续按住会溢出"
	else:
		state_label.text = "接浆中 · %d%%" % roundi(dispense_progress.value) if _fill_guide_enabled else "接浆中"


func refresh_from_session() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return
	var progression := Dictionary(session.call("five_area_progression_snapshot"))
	var area_unlocked := Array(progression.get("unlocked_area_ids", [])).has("area.fresh_soy_milk")
	visible = _workshop_preview or area_unlocked
	modulate = WORKSHOP_LOCKED_AREA_MODULATE if _workshop_preview and not area_unlocked else Color.WHITE
	if not visible:
		return
	var machine := Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine"))
	# Keep ownership separate from the workshop's ghost prop.  The workshop
	# always previews the next purchasable machine instead of skipping straight
	# to the final dual-outlet model.
	var double_fill_owned := bool(machine.get("double_fill_enabled", false))
	var auto_fill_owned := bool(machine.get("auto_fill_enabled", false))
	_displayed_machine_tier = _workshop_preview_tier(area_unlocked, auto_fill_owned, double_fill_owned) if _workshop_preview else _owned_machine_tier(auto_fill_owned, double_fill_owned)
	if _workshop_preview:
		machine["available_recipe_ids"] = FLAVOR_RECIPES.duplicate()
		machine["sugar_enabled"] = true
		machine["ice_enabled"] = true
		machine["auto_fill_enabled"] = true
		machine["double_fill_enabled"] = true
		machine["fill_guide_enabled"] = true
	var cup_state := StringName(machine.get("cup_state", &"ready"))
	var cup := Dictionary(machine.get("cup", {}))
	var queued_cups := Array(machine.get("queued_cups", []))
	var ready_cup_count := int(machine.get("ready_cup_count", 0))
	if cup_state != &"filled" or _selected_cup_index >= ready_cup_count:
		_selected_cup_index = 0
	var selected_cup := _cup_at_index(cup, queued_cups, _selected_cup_index)
	var product_id := StringName(cup.get("product_id", &"product.fresh_soy_milk.yellow_bean"))
	var fill_ratio := float(cup.get("fill_ratio", 0.0))
	var selected_fill_ratio := float(selected_cup.get("fill_ratio", 0.0))
	var sugar_servings := int(selected_cup.get("sugar_servings", 0))
	var sugar_enabled := bool(machine.get("sugar_enabled", false))
	var ice_enabled := bool(machine.get("ice_enabled", false))
	_fill_guide_enabled = bool(machine.get("fill_guide_enabled", false))
	_auto_fill_enabled = bool(machine.get("auto_fill_enabled", false))
	_double_fill_enabled = bool(machine.get("double_fill_enabled", false))
	soy_milk_dispenser.texture = _texture_for_machine_tier(_displayed_machine_tier)
	# A locked area is faded by the station itself. Once the basic machine is
	# installed, fade only the next machine tier being previewed.
	soy_milk_dispenser.self_modulate = WORKSHOP_LOCKED_AREA_MODULATE if _workshop_preview and area_unlocked and not double_fill_owned else Color.WHITE
	_refresh_machine_geometry()
	dispense_progress.visible = _fill_guide_enabled and not _workshop_preview
	var selected_recipe_id := StringName(machine.get("recipe_id", &"recipe.fresh_soy_milk.yellow_bean"))
	_refresh_flavor_menu(Array(machine.get("available_recipe_ids", [selected_recipe_id])), selected_recipe_id, cup_state == &"ready")
	_filling = _filling and cup_state == &"held_empty"
	if not _filling:
		dispense_progress.value = 0.0
		if cup_state == &"filled":
			dispense_effect.set_filled_cup(fill_ratio, _liquid_color_for_recipe(StringName(cup.get("recipe_id", selected_recipe_id))))
		else:
			dispense_effect.set_filled_cup(0.0, _liquid_color_for_recipe(selected_recipe_id))
	var queued_cup := _cup_at_index(cup, queued_cups, 1)
	queued_cup_effect.set_filled_cup(float(queued_cup.get("fill_ratio", 0.0)) if cup_state == &"filled" and ready_cup_count > 1 else 0.0, _liquid_color_for_recipe(StringName(queued_cup.get("recipe_id", selected_recipe_id))))
	if cup_state == &"ready":
		machine_output.configure({"source_kind": &"soy_empty_cup"}, PLASTIC_CUP_TEXTURE, true, "点击取一个空杯")
		machine_output.set_drag_available(false)
		machine_output.position = _active_cup_position()
		state_label.text = "① 点击取空杯"
		cup_detail_label.text = "%s · 0 / 1 / 2 份糖" % _recipe_label(selected_recipe_id)
	elif cup_state == &"held_empty":
		machine_output.configure({"source_kind": &"soy_empty_cup"}, PLASTIC_CUP_TEXTURE, false, "双杯已就位，请点击双出浆口" if _double_fill_enabled else "空杯已拿起，请点击自动出浆口" if _auto_fill_enabled else "空杯已拿起，请按住出浆口")
		machine_output.position = _active_cup_position()
		state_label.text = "② 点击双出浆口自动接满两杯" if _double_fill_enabled else "② 点击出浆口自动满杯" if _auto_fill_enabled else "② 按住出浆口接豆浆" if not _filling else state_label.text
		cup_detail_label.text = "一次自动接满两杯豆浆" if _double_fill_enabled else "自动接满一杯豆浆" if _auto_fill_enabled else "松开即出杯；满杯需要 0.8 秒"
	else:
		machine_output.configure({"source_kind": &"soy_cup", "product_id": product_id}, PLASTIC_CUP_TEXTURE, true, "拖到订单商品交付")
		machine_output.set_drag_available(true)
		machine_output.position = _active_cup_position()
		var fill_percent := roundi(selected_fill_ratio * 100.0)
		state_label.text = "③ 已选第%d杯；点击糖罐或冰盒加料" % (_selected_cup_index + 1) if ready_cup_count > 1 else "③ 已选豆浆；点击糖罐或冰盒加料"
		var temperature_label := "冰镇" if StringName(selected_cup.get("temperature_mode", &"room_temperature")) == &"iced" else "常温"
		cup_detail_label.text = "第%d杯 · %s · %s · %d%% 满杯" % [_selected_cup_index + 1, _recipe_label(StringName(selected_cup.get("recipe_id", selected_recipe_id))), temperature_label, fill_percent]
	queued_cup_preview.visible = cup_state == &"filled" and ready_cup_count > 1
	queued_cup_preview.position = DUAL_RIGHT_CUP_POSITION
	queued_cup_button.visible = queued_cup_preview.visible
	queued_cup_button.disabled = not queued_cup_button.visible
	queued_cup_button.position = DUAL_RIGHT_CUP_POSITION
	queued_cup_button.size = queued_cup_preview.size
	_update_cup_selection_frame(cup_state == &"filled", ready_cup_count)
	sugar_jar_visual.visible = sugar_enabled
	sugar_jar.visible = sugar_enabled
	sugar_label.visible = sugar_enabled
	sugar_jar.disabled = not sugar_enabled or cup_state != &"filled" or sugar_servings >= 2
	sugar_jar.tooltip_text = "给第%d杯加糖（最多两份）" % (_selected_cup_index + 1) if not sugar_jar.disabled else "请先接好豆浆" if cup_state != &"filled" else "第%d杯已是多糖" % (_selected_cup_index + 1)
	sugar_label.text = "糖：%s" % ["无糖", "正常糖（1份）", "多糖（2份）"][clampi(sugar_servings, 0, 2)]
	ice_tray_visual.visible = ice_enabled
	ice_button.visible = ice_enabled
	ice_button.disabled = not ice_enabled or cup_state != &"filled" or StringName(selected_cup.get("temperature_mode", &"room_temperature")) == &"iced"
	ice_button.tooltip_text = "给第%d杯加冰" % (_selected_cup_index + 1) if not ice_button.disabled else "第%d杯已加冰" % (_selected_cup_index + 1) if StringName(selected_cup.get("temperature_mode", &"room_temperature")) == &"iced" else "请先接好豆浆"
	nozzle_button.disabled = cup_state != &"held_empty"
	nozzle_button.tooltip_text = "点击同时接满两杯豆浆" if _double_fill_enabled else "点击自动接满一杯豆浆" if _auto_fill_enabled else "按住出浆口接浆"
	if _workshop_preview:
		# The author-positioned dispenser, cup, sugar jar and ice box remain;
		# operating instructions and progress are intentionally absent.
		state_label.visible = false
		cup_detail_label.visible = false
		sugar_label.visible = false
		flavor_menu.visible = false
		nozzle_button.disabled = true
		machine_output.mouse_filter = Control.MOUSE_FILTER_IGNORE
		queued_cup_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sugar_jar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ice_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flavor_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		state_label.visible = true
		cup_detail_label.visible = true
		sugar_label.visible = sugar_enabled
		flavor_menu.visible = true
		machine_output.mouse_filter = Control.MOUSE_FILTER_STOP
		queued_cup_button.mouse_filter = Control.MOUSE_FILTER_STOP if queued_cup_button.visible else Control.MOUSE_FILTER_IGNORE
		sugar_jar.mouse_filter = Control.MOUSE_FILTER_STOP
		ice_button.mouse_filter = Control.MOUSE_FILTER_STOP
		flavor_menu.mouse_filter = Control.MOUSE_FILTER_STOP


func set_workshop_preview(enabled: bool) -> void:
	_workshop_preview = enabled
	refresh_from_session()


func _on_cup_short_clicked(_source_ref: Dictionary) -> void:
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		var machine := Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine"))
		if StringName(machine.get("cup_state", &"ready")) == &"filled":
			_select_cup(0)
			return
	var result: Dictionary = session.call("take_f4_soy_empty_cup") if session != null else {"success": false, "reason": &"no_game_session"}
	var success_message := "双杯已就位，点击双出浆口同时接满" if _double_fill_enabled else "空杯已拿起，点击自动豆浆机出浆口接浆" if _auto_fill_enabled else "空杯已拿起，按住豆浆机出浆口接浆"
	status_message.emit(success_message if bool(result.get("success", false)) else "无法取杯：%s" % str(result.get("reason", &"unknown")))
	refresh_from_session()


func _on_queued_cup_pressed() -> void:
	_select_cup(1)


func _select_cup(cup_index: int) -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return
	var machine := Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine"))
	var ready_cup_count := int(machine.get("ready_cup_count", 0))
	if StringName(machine.get("cup_state", &"ready")) != &"filled" or cup_index < 0 or cup_index >= ready_cup_count:
		return
	_selected_cup_index = cup_index
	status_message.emit("已选第%d杯豆浆" % (_selected_cup_index + 1))
	refresh_from_session()


func _on_nozzle_down() -> void:
	if nozzle_button.disabled:
		return
	if _auto_fill_enabled:
		return
	_filling = true
	_held_seconds = 0.0
	dispense_progress.value = 0.0
	dispense_effect.set_dispense_state(true, 0.0, _liquid_color_for_recipe(_selected_recipe_id()))


func _on_nozzle_pressed() -> void:
	if not nozzle_button.disabled and _auto_fill_enabled:
		_fill_cup_automatically()


func _on_nozzle_up() -> void:
	if not _filling:
		return
	_filling = false
	var session := get_node_or_null("/root/GameSession")
	var result: Dictionary = session.call("fill_f4_soy_empty_cup", _held_seconds) if session != null else {"success": false, "reason": &"no_game_session"}
	if bool(result.get("success", false)):
		var ratio := float(result.get("fill_ratio", 0.0))
		status_message.emit("满杯黄豆豆浆" if ratio >= 0.999 else "未接满（%d%%），收益和口碑将降低" % roundi(ratio * 100.0))
	else:
		status_message.emit("接浆失败：%s" % str(result.get("reason", &"unknown")))
	refresh_from_session()


func _fill_cup_automatically() -> void:
	var session := get_node_or_null("/root/GameSession")
	var result: Dictionary = session.call("fill_f4_soy_empty_cup", FULL_CUP_SECONDS) if session != null else {"success": false, "reason": &"no_game_session"}
	if bool(result.get("success", false)):
		status_message.emit("高级豆浆机已同时接满两杯" if _double_fill_enabled else "自动豆浆机已接满一杯")
	else:
		status_message.emit("自动接浆失败：%s" % str(result.get("reason", &"unknown")))
	refresh_from_session()


func _on_sugar_jar_pressed() -> void:
	var session := get_node_or_null("/root/GameSession")
	var result: Dictionary = session.call("add_f4_soy_sugar", _selected_cup_index) if session != null else {"success": false, "reason": &"no_game_session"}
	if bool(result.get("success", false)):
		var servings := int(result.get("sugar_servings", 0))
		_selected_cup_effect().play_sugar_add(SUGAR_JAR_SPOUT)
		status_message.emit("第%d杯已加正常糖" % (_selected_cup_index + 1) if servings == 1 else "第%d杯已加多糖" % (_selected_cup_index + 1))
	else:
		status_message.emit("无法加糖：%s" % str(result.get("reason", &"unknown")))
	refresh_from_session()


func _on_ice_button_pressed() -> void:
	var session := get_node_or_null("/root/GameSession")
	var result: Dictionary = session.call("add_f4_soy_ice", _selected_cup_index) if session != null else {"success": false, "reason": &"no_game_session"}
	if bool(result.get("success", false)):
		_selected_cup_effect().play_ice_add(ICE_TRAY_SCOOP)
		status_message.emit("第%d杯已加冰" % (_selected_cup_index + 1))
	else:
		status_message.emit("无法加冰：%s" % str(result.get("reason", &"unknown")))
	refresh_from_session()


func _refresh_flavor_menu(raw_recipe_ids: Array, selected_recipe_id: StringName, can_select: bool) -> void:
	var popup := flavor_menu.get_popup()
	popup.clear()
	var available: Array[StringName] = []
	for raw_recipe_id in raw_recipe_ids:
		var recipe_id := StringName(raw_recipe_id)
		if FLAVOR_RECIPES.has(recipe_id):
			available.append(recipe_id)
	for recipe_id in available:
		popup.add_item(_recipe_label(recipe_id), FLAVOR_RECIPES.find(recipe_id))
	flavor_menu.disabled = not can_select or available.size() <= 1
	flavor_menu.text = "%s ▾" % _recipe_label(selected_recipe_id)
	flavor_menu.tooltip_text = "当前仅供应黄豆豆浆"


func _on_flavor_selected(index: int) -> void:
	if index < 0 or index >= FLAVOR_RECIPES.size():
		return
	var session := get_node_or_null("/root/GameSession")
	var recipe_id := FLAVOR_RECIPES[index]
	var result: Dictionary = session.call("select_f4_soy_flavor", recipe_id) if session != null else {"success": false, "reason": &"no_game_session"}
	status_message.emit("已选择%s" % _recipe_label(recipe_id) if bool(result.get("success", false)) else "无法切换口味：%s" % str(result.get("reason", &"unknown")))
	refresh_from_session()


static func _recipe_label(recipe_id: StringName) -> String:
	return {
		&"recipe.fresh_soy_milk.yellow_bean": "黄豆豆浆",
	}.get(recipe_id, "黄豆豆浆")


func _selected_recipe_id() -> StringName:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return &"recipe.fresh_soy_milk.yellow_bean"
	return StringName(Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine")).get("recipe_id", &"recipe.fresh_soy_milk.yellow_bean"))


static func _liquid_color_for_recipe(recipe_id: StringName) -> Color:
	return {
		&"recipe.fresh_soy_milk.yellow_bean": Color("f4d99c"),
	}.get(recipe_id, Color("f4d99c"))


func _nozzle_outlet_position() -> Vector2:
	# The dispenser uses KEEP_ASPECT_COVERED. Resolve any source-image crop
	# before converting its verified source-pixel outlet into station coordinates.
	var outlet := ADVANCED_LEFT_NOZZLE_OUTLET_TEXTURE_POSITION if _displayed_machine_tier >= 2 else AUTO_FILL_NOZZLE_OUTLET_TEXTURE_POSITION if _displayed_machine_tier == 1 else DISPENSER_NOZZLE_OUTLET_TEXTURE_POSITION
	return _texture_position_to_station(outlet)


func _texture_position_to_station(texture_position: Vector2) -> Vector2:
	var texture_size := soy_milk_dispenser.texture.get_size()
	var display_size := soy_milk_dispenser.size
	var scale := maxf(display_size.x / texture_size.x, display_size.y / texture_size.y)
	var drawn_size := texture_size * scale
	var crop_offset := (display_size - drawn_size) * 0.5
	return soy_milk_dispenser.position + crop_offset + texture_position * scale


func _active_cup_position() -> Vector2:
	return DUAL_LEFT_CUP_POSITION if _displayed_machine_tier >= 2 else SINGLE_DISPENSING_CUP_POSITION


func _refresh_machine_geometry() -> void:
	var outlet := _nozzle_outlet_position()
	nozzle_button.position = Vector2(
		clampf(outlet.x - nozzle_button.size.x * 0.5, 0.0, size.x - nozzle_button.size.x),
		clampf(outlet.y - nozzle_button.size.y, 0.0, size.y - nozzle_button.size.y)
	)
	dispense_effect.configure_geometry(Rect2(_active_cup_position(), machine_output.size), outlet)
	var queued_outlet := _texture_position_to_station(ADVANCED_RIGHT_NOZZLE_OUTLET_TEXTURE_POSITION) if _displayed_machine_tier >= 2 else outlet
	queued_cup_effect.configure_geometry(Rect2(DUAL_RIGHT_CUP_POSITION, machine_output.size), queued_outlet)


func _update_cup_selection_frame(has_filled_cup: bool, ready_cup_count: int) -> void:
	cup_selection_frame.visible = has_filled_cup and ready_cup_count > 0
	if not cup_selection_frame.visible:
		return
	var cup_position := DUAL_RIGHT_CUP_POSITION if _selected_cup_index == 1 else _active_cup_position()
	cup_selection_frame.position = cup_position - Vector2(4.0, 4.0)
	cup_selection_frame.size = machine_output.size + Vector2(8.0, 8.0)


func _selected_cup_effect() -> SoyDispenseEffect:
	return queued_cup_effect if _selected_cup_index == 1 else dispense_effect


static func _cup_at_index(active_cup: Dictionary, queued_cups: Array, cup_index: int) -> Dictionary:
	if cup_index == 0:
		return active_cup
	var queued_index := cup_index - 1
	if queued_index < 0 or queued_index >= queued_cups.size():
		return {}
	return Dictionary(queued_cups[queued_index])


static func _owned_machine_tier(auto_fill_owned: bool, double_fill_owned: bool) -> int:
	if double_fill_owned:
		return 2
	if auto_fill_owned:
		return 1
	return 0


static func _workshop_preview_tier(area_unlocked: bool, auto_fill_owned: bool, double_fill_owned: bool) -> int:
	if not area_unlocked:
		return 0
	if not auto_fill_owned:
		return 1
	if not double_fill_owned:
		return 2
	return 2


static func _texture_for_machine_tier(tier: int) -> Texture2D:
	match tier:
		1:
			return AUTO_FILL_DISPENSER_TEXTURE
		2:
			return ADVANCED_DISPENSER_TEXTURE
		_:
			return MANUAL_DISPENSER_TEXTURE
