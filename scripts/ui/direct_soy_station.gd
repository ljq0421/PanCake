class_name DirectSoyStation
extends Control

signal status_message(message: String)

const PLASTIC_CUP_TEXTURE := preload("res://resources/art/products/soy_milk/soy_milk_plastic_cup_empty_cartoon_v3_512.png")
const SUGAR_JAR_TEXTURE := preload("res://assets/jianbing-stall/sugar-jar-for-soy-milk.png")
const MANUAL_DISPENSER_TEXTURE := preload("res://assets/jianbing-stall/soy-milk-dispenser.png")
const AUTO_DISPENSER_TEXTURE := preload("res://assets/jianbing-stall/automatic-soy-milk-dispenser-two-outlets-transparent.png")
const FULL_CUP_SECONDS := 0.8
const EMPTY_CUP_POSITION := Vector2(20.0, 316.0)
const DISPENSING_CUP_POSITION := Vector2(105.0, 318.0)
# Measured on soy-milk-dispenser.png.  This is the lower opening of the tap,
# not the handle or its mounting point.
const DISPENSER_NOZZLE_OUTLET_TEXTURE_POSITION := Vector2(464.0, 1000.0)
# The upgraded prop has two visible outlets.  The left one is the active
# single-cup outlet; the current automatic workflow still serves one cup at a
# time, so its stream/effect remains deliberately anchored there.
const AUTO_DISPENSER_NOZZLE_OUTLET_TEXTURE_POSITION := Vector2(428.0, 1033.0)
const SUGAR_JAR_SPOUT := Vector2(345.0, 347.0)
const WORKSHOP_LOCKED_AREA_MODULATE := Color(1.0, 1.0, 1.0, 0.42)
# The visible jar belongs to this station, while its transparent button keeps
# a slightly forgiving hit area instead of relying on the pixel edge.
const SUGAR_JAR_HIT_RECT := Rect2(264.0, 316.0, 146.0, 144.0)
const FLAVOR_RECIPES: Array[StringName] = [
	&"recipe.fresh_soy_milk.yellow_bean",
	&"recipe.fresh_soy_milk.black_bean",
	&"recipe.fresh_soy_milk.red_bean",
]

@onready var machine_output: ProductDragSource = %MachineOutput
@onready var nozzle_button: Button = %NozzleButton
@onready var sugar_jar: TextureButton = %SugarJar
@onready var ice_button: Button = %IceButton
@onready var soy_milk_dispenser: TextureRect = $SoyMilkDispenser
@onready var state_label: Label = %StateLabel
@onready var cup_detail_label: Label = %CupDetailLabel
@onready var dispense_progress: ProgressBar = %DispenseProgress
@onready var dispense_effect: SoyDispenseEffect = %DispenseEffect
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
var _workshop_preview := false


func _ready() -> void:
	# These hit regions are intentionally transparent: sibling station artwork
	# remains the visual source of truth for the dispenser and sugar jar.
	nozzle_button.position = Vector2(108.0, 230.0)
	nozzle_button.size = Vector2(112.0, 100.0)
	flavor_menu.position = Vector2(10.0, 12.0)
	flavor_menu.size = Vector2(106.0, 30.0)
	sugar_jar.position = SUGAR_JAR_HIT_RECT.position
	sugar_jar.size = SUGAR_JAR_HIT_RECT.size
	dispense_effect.configure_geometry(Rect2(DISPENSING_CUP_POSITION, machine_output.size), _nozzle_outlet_position())
	machine_output.short_clicked.connect(_on_cup_short_clicked)
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
	var auto_fill_owned := bool(machine.get("auto_fill_enabled", false))
	if _workshop_preview:
		machine["available_recipe_ids"] = FLAVOR_RECIPES.duplicate()
		machine["sugar_enabled"] = true
		machine["ice_enabled"] = true
		machine["auto_fill_enabled"] = true
		machine["fill_guide_enabled"] = true
	var cup_state := StringName(machine.get("cup_state", &"ready"))
	var cup := Dictionary(machine.get("cup", {}))
	var product_id := StringName(cup.get("product_id", &"product.fresh_soy_milk.yellow_bean"))
	var fill_ratio := float(cup.get("fill_ratio", 0.0))
	var sugar_servings := int(cup.get("sugar_servings", 0))
	var sugar_enabled := bool(machine.get("sugar_enabled", false))
	var ice_enabled := bool(machine.get("ice_enabled", false))
	_fill_guide_enabled = bool(machine.get("fill_guide_enabled", false))
	_auto_fill_enabled = bool(machine.get("auto_fill_enabled", false))
	soy_milk_dispenser.texture = AUTO_DISPENSER_TEXTURE if _auto_fill_enabled else MANUAL_DISPENSER_TEXTURE
	# The workshop always previews the automatic dispenser so it can act as the
	# upgrade target.  Until the player owns that upgrade, keep only this future
	# machine translucent; the already-unlocked manual dispenser stays opaque.
	soy_milk_dispenser.self_modulate = WORKSHOP_LOCKED_AREA_MODULATE if _workshop_preview and not auto_fill_owned else Color.WHITE
	dispense_effect.configure_geometry(Rect2(DISPENSING_CUP_POSITION, machine_output.size), _nozzle_outlet_position())
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
	if cup_state == &"ready":
		machine_output.configure({"source_kind": &"soy_empty_cup"}, PLASTIC_CUP_TEXTURE, true, "点击取一个空杯")
		machine_output.set_drag_available(false)
		machine_output.position = EMPTY_CUP_POSITION
		state_label.text = "① 点击取空杯"
		cup_detail_label.text = "%s · 0 / 1 / 2 份糖" % _recipe_label(selected_recipe_id)
	elif cup_state == &"held_empty":
		machine_output.configure({"source_kind": &"soy_empty_cup"}, PLASTIC_CUP_TEXTURE, false, "空杯已拿起，请点击自动出浆口" if _auto_fill_enabled else "空杯已拿起，请按住出浆口")
		machine_output.position = DISPENSING_CUP_POSITION
		state_label.text = "② 点击出浆口自动满杯" if _auto_fill_enabled else "② 按住出浆口接豆浆" if not _filling else state_label.text
		cup_detail_label.text = "自动接满一杯豆浆" if _auto_fill_enabled else "松开即出杯；满杯需要 0.8 秒"
	else:
		machine_output.configure({"source_kind": &"soy_cup", "product_id": product_id}, PLASTIC_CUP_TEXTURE, true, "拖到订单商品交付")
		machine_output.set_drag_available(true)
		machine_output.position = DISPENSING_CUP_POSITION
		var fill_percent := roundi(fill_ratio * 100.0)
		state_label.text = "③ 加糖或拖杯交付"
		cup_detail_label.text = "%s · %d%% 满杯" % [_recipe_label(StringName(cup.get("recipe_id", selected_recipe_id))), fill_percent]
	sugar_jar.visible = sugar_enabled
	sugar_label.visible = sugar_enabled
	sugar_jar.disabled = not sugar_enabled or cup_state != &"filled" or sugar_servings >= 2
	sugar_jar.tooltip_text = "成品杯加糖（最多两份）" if not sugar_jar.disabled else "请先接好豆浆" if cup_state != &"filled" else "已是多糖"
	sugar_label.text = "糖：%s" % ["无糖", "正常糖（1份）", "多糖（2份）"][clampi(sugar_servings, 0, 2)]
	ice_button.visible = ice_enabled
	ice_button.disabled = not ice_enabled or cup_state != &"filled" or StringName(cup.get("temperature_mode", &"room_temperature")) == &"iced"
	nozzle_button.disabled = cup_state != &"held_empty"
	nozzle_button.tooltip_text = "点击自动接满一杯豆浆" if _auto_fill_enabled else "按住出浆口接浆"
	if _workshop_preview:
		# The author-positioned dispenser, cup, sugar jar and ice box remain;
		# operating instructions and progress are intentionally absent.
		state_label.visible = false
		cup_detail_label.visible = false
		sugar_label.visible = false
		flavor_menu.visible = false
		nozzle_button.disabled = true
		machine_output.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sugar_jar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ice_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flavor_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		state_label.visible = true
		cup_detail_label.visible = true
		sugar_label.visible = sugar_enabled
		flavor_menu.visible = true
		machine_output.mouse_filter = Control.MOUSE_FILTER_STOP
		sugar_jar.mouse_filter = Control.MOUSE_FILTER_STOP
		ice_button.mouse_filter = Control.MOUSE_FILTER_STOP
		flavor_menu.mouse_filter = Control.MOUSE_FILTER_STOP


func set_workshop_preview(enabled: bool) -> void:
	_workshop_preview = enabled
	refresh_from_session()


func _on_cup_short_clicked(_source_ref: Dictionary) -> void:
	var session := get_node_or_null("/root/GameSession")
	var result: Dictionary = session.call("take_f4_soy_empty_cup") if session != null else {"success": false, "reason": &"no_game_session"}
	var success_message := "空杯已拿起，点击自动豆浆机出浆口接浆" if _auto_fill_enabled else "空杯已拿起，按住豆浆机出浆口接浆"
	status_message.emit(success_message if bool(result.get("success", false)) else "无法取杯：%s" % str(result.get("reason", &"unknown")))
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
		status_message.emit("自动豆浆机已接满一杯")
	else:
		status_message.emit("自动接浆失败：%s" % str(result.get("reason", &"unknown")))
	refresh_from_session()


func _on_sugar_jar_pressed() -> void:
	var session := get_node_or_null("/root/GameSession")
	var result: Dictionary = session.call("add_f4_soy_sugar") if session != null else {"success": false, "reason": &"no_game_session"}
	if bool(result.get("success", false)):
		var servings := int(result.get("sugar_servings", 0))
		dispense_effect.play_sugar_add(SUGAR_JAR_SPOUT)
		status_message.emit("已加正常糖" if servings == 1 else "已加多糖")
	else:
		status_message.emit("无法加糖：%s" % str(result.get("reason", &"unknown")))
	refresh_from_session()


func _on_ice_button_pressed() -> void:
	var session := get_node_or_null("/root/GameSession")
	var result: Dictionary = session.call("add_f4_soy_ice") if session != null else {"success": false, "reason": &"no_game_session"}
	status_message.emit("已加冰" if bool(result.get("success", false)) else "无法加冰：%s" % str(result.get("reason", &"unknown")))
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
	flavor_menu.tooltip_text = "选择已解锁的豆浆口味" if available.size() > 1 else "升级口味按钮后可选择黑豆和红豆"


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
		&"recipe.fresh_soy_milk.black_bean": "黑豆豆浆",
		&"recipe.fresh_soy_milk.red_bean": "红豆豆浆",
	}.get(recipe_id, "黄豆豆浆")


func _selected_recipe_id() -> StringName:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return &"recipe.fresh_soy_milk.yellow_bean"
	return StringName(Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine")).get("recipe_id", &"recipe.fresh_soy_milk.yellow_bean"))


static func _liquid_color_for_recipe(recipe_id: StringName) -> Color:
	return {
		&"recipe.fresh_soy_milk.yellow_bean": Color("f4d99c"),
		&"recipe.fresh_soy_milk.black_bean": Color("8f7a63"),
		&"recipe.fresh_soy_milk.red_bean": Color("d89a74"),
	}.get(recipe_id, Color("f4d99c"))


func _nozzle_outlet_position() -> Vector2:
	# The dispenser uses KEEP_ASPECT_COVERED. Resolve any source-image crop
	# before converting its verified source-pixel outlet into station coordinates.
	var texture_size := soy_milk_dispenser.texture.get_size()
	var display_size := soy_milk_dispenser.size
	var scale := maxf(display_size.x / texture_size.x, display_size.y / texture_size.y)
	var drawn_size := texture_size * scale
	var crop_offset := (display_size - drawn_size) * 0.5
	var outlet := AUTO_DISPENSER_NOZZLE_OUTLET_TEXTURE_POSITION if _auto_fill_enabled else DISPENSER_NOZZLE_OUTLET_TEXTURE_POSITION
	return soy_milk_dispenser.position + crop_offset + outlet * scale
