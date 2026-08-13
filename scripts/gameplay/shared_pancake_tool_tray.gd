class_name SharedPancakeToolTray
extends Control

signal tool_selected(tool_id: StringName)
signal status_message(message: String)

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const SPREADER_NORMAL := preload("res://resources/art/workstation/tools/batter_spreader_v1_five_area_v2.png")
const SPREADER_WIDE := preload("res://resources/art/workstation/tools/batter_spreader_upgrade_v1_five_area_v2.png")
const LOCK_TEXTURE := preload("res://resources/art/workstation/material_slots/individual/slot_05_locked_v1_five_area_v2.png")
const SLOT_DEFINITIONS := [
	{"name": "BatterSlot", "label": "面糊桶", "stock_id": &"stock.pancake.batter", "source_kind": &"pancake_shared_batter", "texture": preload("res://resources/art/workstation/tools/batter_ladle_v1_five_area_v2.png"), "native_drag": false},
	{ "name": "EggSlot", "label": "鸡蛋", "stock_id": &"stock.pancake.egg", "source_kind": &"pancake_shared_ingredient", "texture": preload("res://resources/art/ingredients/egg/egg_whole_v1_five_area_v2.png")},
	{ "name": "BaocuiSlot", "label": "薄脆", "stock_id": &"stock.pancake.baocui", "source_kind": &"pancake_shared_ingredient", "texture": preload("res://resources/art/ingredients/baocui/baocui_intact_v1_five_area_v2.png")},
	{ "name": "ScallionSlot", "label": "葱花", "stock_id": &"stock.pancake.scallion", "source_kind": &"pancake_shared_ingredient", "texture": preload("res://resources/art/ingredients/scallion/scallion_pile_v1_five_area_v2.png")},
	{ "name": "HamSlot", "label": "火腿", "stock_id": &"stock.pancake.ham_sausage", "source_kind": &"pancake_shared_ingredient", "texture": preload("res://resources/art/ingredients/ham_sausage/ham_sausage_whole_v1_five_area_v2.png")},
	{ "name": "FlossSlot", "label": "肉松", "stock_id": &"stock.pancake.meat_floss", "source_kind": &"pancake_shared_ingredient", "texture": preload("res://resources/art/ingredients/meat_floss/meat_floss_pile_v1_five_area_v2.png")},
	{ "name": "CorianderSlot", "label": "香菜", "stock_id": &"stock.pancake.coriander", "source_kind": &"pancake_shared_ingredient", "texture": preload("res://resources/art/ingredients/coriander/coriander_pile_five_area_v2.png")},
	{ "name": "MustardSlot", "label": "榨菜", "stock_id": &"stock.pancake.preserved_mustard", "source_kind": &"pancake_shared_ingredient", "texture": preload("res://resources/art/ingredients/preserved_mustard/preserved_mustard_pile_five_area_v2.png")},
	{ "name": "TenderloinSlot", "label": "里脊", "stock_id": &"stock.pancake.pork_tenderloin", "source_kind": &"pancake_shared_ingredient", "texture": preload("res://resources/art/ingredients/pork_tenderloin/pork_tenderloin_portion_v1_five_area_v2.png")},
	{ "name": "SweetSauceSlot", "label": "甜面酱", "stock_id": &"stock.pancake.sauce.sweet_flour", "source_kind": &"pancake_shared_sauce", "texture": preload("res://resources/art/workstation/material_slots/individual/slot_04_sweet_flour_sauce_v1_five_area_v2.png"), "native_drag": false},
	{ "name": "ChiliSauceSlot", "label": "辣酱", "stock_id": &"stock.pancake.sauce.red_chili", "source_kind": &"pancake_shared_sauce", "texture": preload("res://resources/art/workstation/textures/red_chili_sauce_texture_v1_five_area_v2.png"), "native_drag": false},
]

var _session: Node
var _stock_slots: Array[FiveAreaMaterialSlot] = []
var _slot_by_stock := {}
var _spreader_button: TextureButton
var _selected_tool: StringName = &""
var _refresh_elapsed := 0.0


func _ready() -> void:
	_build_tray()
	set_process(true)


func bind_session(session: Node) -> void:
	_session = session
	refresh_from_session()


func set_selected_tool(tool_id: StringName) -> void:
	_selected_tool = tool_id
	_refresh_selection_visuals()


func selected_tool() -> StringName:
	return _selected_tool


func refresh_from_session() -> void:
	var inventory := Dictionary(_session.call("inventory_snapshot")) if _session != null and _session.has_method("inventory_snapshot") else {}
	var progression: RefCounted = _session.call("progression_service") if _session != null and _session.has_method("progression_service") else null
	for slot in _stock_slots:
		var stock_id := slot.stock_id
		var unlocked := progression != null and bool(progression.call("owns_stock", stock_id))
		var definition := CATALOG.stock_definition(stock_id)
		var capacity := maxi(int(definition.get("restock_capacity", 6)), 1)
		if progression != null:
			capacity = maxi(capacity, int(progression.get("stock_capacity")))
		var count := maxi(int(inventory.get(str(stock_id), 0)), 0)
		slot.apply_state(count, unlocked, capacity)
		var lock_visual := slot.get_node_or_null("LockVisual") as TextureRect
		if lock_visual != null:
			lock_visual.visible = not unlocked
	var wide := progression != null and bool(progression.call("owns_growth", &"growth.tool.pancake.wide_spreader"))
	_spreader_button.texture_normal = SPREADER_WIDE if wide else SPREADER_NORMAL
	_spreader_button.tooltip_text = "宽幅摊饼器：落点更宽" if wide else "T形摊饼器：点选后在任意已解锁鏊面画圈"
	_refresh_selection_visuals()


func _process(delta: float) -> void:
	_refresh_elapsed += maxf(delta, 0.0)
	if _refresh_elapsed >= 0.2:
		_refresh_elapsed = 0.0
		refresh_from_session()


func _build_tray() -> void:
	var background := Panel.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.095, 0.035, 0.98)
	style.border_color = Color(0.93, 0.63, 0.25, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	background.add_theme_stylebox_override("panel", style)
	add_child(background)

	var row := HBoxContainer.new()
	row.name = "PhysicalToolRow"
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 7)
	row.add_theme_constant_override("separation", 4)
	add_child(row)

	_add_stock_slot(row, SLOT_DEFINITIONS[0])
	_spreader_button = TextureButton.new()
	_spreader_button.name = "SpreaderButton"
	_spreader_button.custom_minimum_size = Vector2(88.0, 96.0)
	_spreader_button.ignore_texture_size = true
	_spreader_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_spreader_button.texture_normal = SPREADER_NORMAL
	_spreader_button.toggle_mode = true
	_spreader_button.pressed.connect(func() -> void:
		tool_selected.emit(&"tool.pancake.spreader")
		status_message.emit("已拿起摊饼器；在目标鏊面按住画圈")
	)
	_add_caption(_spreader_button, "摊饼器")
	row.add_child(_spreader_button)
	for index in range(1, SLOT_DEFINITIONS.size()):
		_add_stock_slot(row, SLOT_DEFINITIONS[index])


func _add_stock_slot(row: HBoxContainer, definition: Dictionary) -> void:
	var slot := FiveAreaMaterialSlot.new()
	slot.name = str(definition.get("name", "MaterialSlot"))
	slot.custom_minimum_size = Vector2(88.0, 96.0)
	slot.ignore_texture_size = true
	slot.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	slot.stock_id = StringName(definition.get("stock_id", &""))
	slot.source_kind = StringName(definition.get("source_kind", &"pancake_shared_ingredient"))
	slot.material_texture = definition.get("texture") as Texture2D
	slot.material_label = str(definition.get("label", ""))
	slot.native_drag_enabled = bool(definition.get("native_drag", true))
	slot.short_clicked.connect(_on_slot_short_clicked.bind(slot))
	slot.hold_requested.connect(_on_hold_requested.bind(slot))
	slot.hold_advanced.connect(_on_hold_advanced.bind(slot))
	slot.hold_released.connect(_on_hold_released.bind(slot))
	_add_caption(slot, slot.material_label)
	var lock_visual := TextureRect.new()
	lock_visual.name = "LockVisual"
	lock_visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lock_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_visual.texture = LOCK_TEXTURE
	lock_visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock_visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.add_child(lock_visual)
	row.add_child(slot)
	_stock_slots.append(slot)
	_slot_by_stock[str(slot.stock_id)] = slot


func _add_caption(parent: Control, caption: String) -> void:
	var label := Label.new()
	label.name = "Caption"
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_top = -24.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.78, 1.0))
	parent.add_child(label)


func _on_slot_short_clicked(source_ref: Dictionary, _slot: FiveAreaMaterialSlot) -> void:
	var source_kind := StringName(source_ref.get("source_kind", &""))
	var stock_id := StringName(source_ref.get("stock_id", &""))
	if source_kind == &"pancake_shared_sauce":
		tool_selected.emit(stock_id)
		status_message.emit("已拿起%s酱刷；在加料阶段的目标鏊面连续刷涂" % _stock_label(stock_id))
	elif source_kind == &"pancake_shared_batter":
		status_message.emit("点击空鏊的“添面糊”；长按面糊桶可补货")


func _on_hold_requested(source_ref: Dictionary, slot: FiveAreaMaterialSlot) -> void:
	if _session == null or not _session.has_method("five_area_restock_status"):
		slot.reject_hold()
		return
	var status := Dictionary(_session.call("five_area_restock_status", StringName(source_ref.get("stock_id", &""))))
	if bool(status.get("success", false)) and int(status.get("current_stock", 0)) < int(status.get("capacity", 0)):
		slot.accept_hold()
		status_message.emit("持续按住补货；每完成一份才扣金币")
	else:
		slot.reject_hold()
		status_message.emit(_restock_failure_text(StringName(status.get("reason", &"")), status))


func _on_hold_advanced(source_ref: Dictionary, delta: float, slot: FiveAreaMaterialSlot) -> void:
	if _session == null or not _session.has_method("advance_five_area_restock_hold"):
		slot.reject_hold()
		return
	var result := Dictionary(_session.call("advance_five_area_restock_hold", StringName(source_ref.get("stock_id", &"")), delta))
	if int(result.get("completed_units", 0)) > 0:
		status_message.emit("%s补货 +%d" % [_stock_label(StringName(source_ref.get("stock_id", &""))), int(result.get("completed_units", 0))])
	if bool(result.get("auto_stopped", false)):
		slot.reject_hold()
		status_message.emit(_restock_failure_text(StringName(result.get("reason", &"")), result))
	refresh_from_session()


func _on_hold_released(_source_ref: Dictionary, _slot: FiveAreaMaterialSlot) -> void:
	refresh_from_session()


func _refresh_selection_visuals() -> void:
	if _spreader_button != null:
		_spreader_button.set_pressed_no_signal(_selected_tool == &"tool.pancake.spreader")
		_spreader_button.self_modulate = Color(1.18, 1.12, 0.72, 1.0) if _selected_tool == &"tool.pancake.spreader" else Color.WHITE
	for stock_key in _slot_by_stock:
		var slot := _slot_by_stock[stock_key] as FiveAreaMaterialSlot
		if slot != null and slot._display_unlocked:
			slot.self_modulate = Color(1.18, 1.12, 0.72, 1.0) if str(_selected_tool) == stock_key else Color.WHITE


func _stock_label(stock_id: StringName) -> String:
	var slot := _slot_by_stock.get(str(stock_id)) as FiveAreaMaterialSlot
	if slot != null and not slot.material_label.is_empty():
		return slot.material_label
	var label := str(CATALOG.stock_definition(stock_id).get("label", ""))
	return label if not label.is_empty() else str(stock_id)


static func _restock_failure_text(reason: StringName, status: Dictionary) -> String:
	match reason:
		&"stock_locked": return "该材料尚未解锁"
		&"capacity_reached": return "材料槽已满"
		&"insufficient_coins": return "余额不足：每份需要%d金币" % int(status.get("unit_cost", 0))
	return "当前无法补货"
