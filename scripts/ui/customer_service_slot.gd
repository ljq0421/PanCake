class_name CustomerServiceSlot
extends Control

const PATIENCE_BAR_STYLE := preload("res://scripts/ui/patience_bar_style.gd")
const CARD_WIDTH := 300.0
const CARD_HEIGHT_BY_ITEM_COUNT := {1: 160.0, 2: 240.0, 3: 320.0}
const ROW_TOP := 48.0
const ROW_HEIGHT := 72.0
const ROW_GAP := 8.0
const INGREDIENT_COLUMNS := 4
const INGREDIENTS_PER_ITEM := 8

signal focus_requested(order_id: StringName)
signal delivery_requested(order_id: StringName, item_index: int)
signal product_dropped(order_id: StringName, item_index: int, source_ref: Dictionary)

@onready var portrait: TextureRect = %Portrait
@onready var portrait_button: Button = %PortraitButton
@onready var order_panel: Control = $OrderPanel
@onready var card_background: TextureRect = %CardBackground
@onready var card_focus_button: Button = %CardFocusButton
@onready var order_title: Label = %OrderTitle
@onready var special_title: Label = %SpecialTitle
@onready var special_rule: Label = %SpecialRule
@onready var item_buttons: Array[Button] = [%ItemButton1, %ItemButton2, %ItemButton3]
@onready var item_icons: Array[TextureRect] = [%ItemIcon1, %ItemIcon2, %ItemIcon3]
@onready var quantity_labels: Array[Label] = [%Quantity1, %Quantity2, %Quantity3]
@onready var requirement_panels: Array[Panel] = [%Requirement1, %Requirement2, %Requirement3, %Requirement4, %Requirement5, %Requirement6, %Requirement7, %Requirement8]
@onready var requirement_icons: Array[TextureRect] = [%RequirementIcon1, %RequirementIcon2, %RequirementIcon3, %RequirementIcon4, %RequirementIcon5, %RequirementIcon6, %RequirementIcon7, %RequirementIcon8]
@onready var coin_label: Label = %CoinLabel
@onready var patience_bar: ProgressBar = %PatienceBar
@onready var patience_label: Label = %PatienceLabel

var _order_id: StringName = &""
var _patience_bar_tier := -1
var _simple_card_background: Panel
var _row_panels: Array[Panel] = []
var _product_frames: Array[Panel] = []
var _ingredient_icons_by_item: Array = []


func _ready() -> void:
	_create_simple_card_controls()
	portrait_button.pressed.connect(_request_focus)
	card_focus_button.pressed.connect(_request_focus)
	for item_index in range(item_buttons.size()):
		item_buttons[item_index].pressed.connect(_request_delivery.bind(item_index))
		if item_buttons[item_index].has_signal("product_source_dropped"):
			item_buttons[item_index].connect("product_source_dropped", _on_product_source_dropped)


func bind_order(order: Dictionary, customer_texture: Texture2D, item_textures: Array, requirements_by_item: Array, perfect_quote: int) -> void:
	_order_id = StringName(order.get("order_id", &""))
	visible = not _order_id.is_empty()
	if not visible:
		return
	portrait.texture = customer_texture
	var special_customer_id := StringName(order.get("special_customer_id", Dictionary(order.get("metadata", {})).get("special_customer_id", &"")))
	var title_text := str(order.get("special_title", Dictionary(order.get("metadata", {})).get("special_title", "")))
	var rule_text := str(order.get("special_rule_text", Dictionary(order.get("metadata", {})).get("special_rule_text", "")))
	special_title.visible = not special_customer_id.is_empty()
	special_title.text = title_text
	special_rule.visible = not special_customer_id.is_empty()
	special_rule.text = rule_text
	order_title.text = "完美完成可得 ×%d 金币" % maxi(perfect_quote, 0)
	var items := Array(order.get("items", []))
	if items.size() > item_buttons.size():
		items.resize(item_buttons.size())
	_apply_simple_card_layout(items.size())
	for item_index in range(item_buttons.size()):
		var has_item := item_index < items.size() and item_index < item_textures.size()
		item_buttons[item_index].visible = has_item
		quantity_labels[item_index].visible = false
		if not has_item:
			continue
		var item := Dictionary(items[item_index])
		var attached_count := Array(item.get("prepared_product_instance_ids", [])).size()
		var required_count := maxi(int(item.get("quantity", 1)), 1)
		var completed := attached_count >= required_count
		item_buttons[item_index].disabled = completed
		item_buttons[item_index].tooltip_text = "该商品已交付" if completed else "把匹配成品拖到这里交付"
		item_icons[item_index].texture = item_textures[item_index] as Texture2D
		item_icons[item_index].modulate = Color(0.55, 0.55, 0.55, 0.72) if completed else Color.WHITE
		quantity_labels[item_index].visible = required_count > 1
		quantity_labels[item_index].text = "✓" if completed else "%d/%d" % [mini(attached_count, required_count), required_count]
	_bind_requirements_by_item(requirements_by_item)
	coin_label.visible = false
	var unlimited := bool(order.get("tutorial_no_countdown", false))
	var total := maxf(float(order.get("patience_seconds", 0.0)), 0.001)
	var remaining := maxf(float(order.get("remaining_patience_seconds", total)), 0.0)
	var ratio := 1.0 if unlimited else clampf(remaining / total, 0.0, 1.0)
	patience_bar.visible = not unlimited
	patience_bar.value = ratio * 100.0
	_patience_bar_tier = PATIENCE_BAR_STYLE.apply(patience_bar, ratio, _patience_bar_tier)
	patience_label.text = "教学单 · 不限时" if unlimited else "耐心 %d 秒" % ceili(remaining)


func _create_simple_card_controls() -> void:
	# This card deliberately uses plain Godot controls instead of a painted card image.
	card_background.visible = false
	for panel in requirement_panels:
		panel.visible = false
	_simple_card_background = Panel.new()
	_simple_card_background.name = "SimpleCardBackground"
	_simple_card_background.z_index = -3
	_simple_card_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_simple_card_background.add_theme_stylebox_override("panel", _simple_style(Color("fff7df"), Color("5d3a1a"), 3, 12))
	order_panel.add_child(_simple_card_background)
	order_panel.move_child(_simple_card_background, 0)
	for item_index in range(item_buttons.size()):
		var row := Panel.new()
		row.name = "OrderRow%d" % (item_index + 1)
		row.z_index = -2
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_stylebox_override("panel", _simple_style(Color("fffdf3"), Color("c89b56"), 2, 8))
		order_panel.add_child(row)
		_row_panels.append(row)
		var product_frame := Panel.new()
		product_frame.name = "ProductFrame%d" % (item_index + 1)
		product_frame.z_index = -1
		product_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		product_frame.add_theme_stylebox_override("panel", _simple_style(Color("fff0b5"), Color("6e451f"), 2, 5))
		order_panel.add_child(product_frame)
		_product_frames.append(product_frame)
		var ingredient_icons: Array[TextureRect] = []
		for ingredient_index in range(INGREDIENTS_PER_ITEM):
			var ingredient_slot := Panel.new()
			ingredient_slot.name = "IngredientSlot%d_%d" % [item_index + 1, ingredient_index + 1]
			ingredient_slot.z_index = -1
			ingredient_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ingredient_slot.add_theme_stylebox_override("panel", _simple_style(Color("fffdf3"), Color("6e451f"), 2, 999))
			var ingredient_icon := TextureRect.new()
			ingredient_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ingredient_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 3)
			ingredient_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ingredient_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ingredient_slot.add_child(ingredient_icon)
			order_panel.add_child(ingredient_slot)
			ingredient_icons.append(ingredient_icon)
		_ingredient_icons_by_item.append(ingredient_icons)


func _apply_simple_card_layout(item_count: int) -> void:
	var visible_item_count := clampi(item_count, 1, item_buttons.size())
	var extra_special_height := 18.0 if special_title.visible else 0.0
	var card_height := float(CARD_HEIGHT_BY_ITEM_COUNT[visible_item_count]) + extra_special_height
	order_panel.size = Vector2(CARD_WIDTH, card_height)
	_simple_card_background.position = Vector2.ZERO
	_simple_card_background.size = order_panel.size
	order_title.position = Vector2(14.0, 8.0)
	order_title.size = Vector2(272.0, 22.0)
	special_title.position = Vector2(14.0, 27.0)
	special_title.size = Vector2(272.0, 18.0)
	special_rule.position = Vector2(14.0, card_height - 47.0)
	special_rule.size = Vector2(272.0, 17.0)
	patience_bar.position = Vector2(70.0, card_height - 26.0)
	patience_bar.size = Vector2(190.0, 16.0)
	patience_label.position = Vector2(70.0, card_height - 26.0)
	patience_label.size = Vector2(190.0, 16.0)
	for item_index in range(item_buttons.size()):
		var row_top := ROW_TOP + item_index * (ROW_HEIGHT + ROW_GAP) + extra_special_height
		var is_visible := item_index < visible_item_count
		_row_panels[item_index].position = Vector2(12.0, row_top)
		_row_panels[item_index].size = Vector2(276.0, ROW_HEIGHT)
		_row_panels[item_index].visible = is_visible
		_product_frames[item_index].position = Vector2(22.0, row_top + 10.0)
		_product_frames[item_index].size = Vector2(52.0, 52.0)
		_product_frames[item_index].visible = is_visible
		item_buttons[item_index].position = Vector2(24.0, row_top + 12.0)
		item_buttons[item_index].size = Vector2(48.0, 48.0)
		quantity_labels[item_index].position = Vector2(5.0, 42.0)
		quantity_labels[item_index].size = Vector2(45.0, 20.0)
		var ingredient_icons: Array = _ingredient_icons_by_item[item_index]
		for ingredient_index in range(ingredient_icons.size()):
			var ingredient_icon := ingredient_icons[ingredient_index] as TextureRect
			var ingredient_slot := ingredient_icon.get_parent() as Panel
			var column := ingredient_index % INGREDIENT_COLUMNS
			var ingredient_row := ingredient_index / INGREDIENT_COLUMNS
			ingredient_slot.position = Vector2(99.0 + column * 42.0, row_top + 9.0 + ingredient_row * 31.0)
			ingredient_slot.size = Vector2(26.0, 26.0)
			ingredient_slot.visible = false


func _bind_requirements_by_item(requirements_by_item: Array) -> void:
	for item_index in range(_ingredient_icons_by_item.size()):
		var item_requirements: Array = Array(requirements_by_item[item_index]) if item_index < requirements_by_item.size() else []
		if item_requirements.size() > INGREDIENTS_PER_ITEM:
			item_requirements.resize(INGREDIENTS_PER_ITEM)
		var ingredient_icons: Array = _ingredient_icons_by_item[item_index]
		for ingredient_index in range(ingredient_icons.size()):
			var ingredient_icon := ingredient_icons[ingredient_index] as TextureRect
			var ingredient_slot := ingredient_icon.get_parent() as Panel
			var has_requirement := item_buttons[item_index].visible and ingredient_index < item_requirements.size()
			ingredient_slot.visible = has_requirement
			if not has_requirement:
				ingredient_icon.texture = null
				ingredient_slot.tooltip_text = ""
				continue
			var requirement := Dictionary(item_requirements[ingredient_index])
			ingredient_icon.texture = requirement.get("texture") as Texture2D
			ingredient_slot.tooltip_text = "需要加热" if StringName(requirement.get("kind", &"")) == &"heated" else str(requirement.get("display_name", "配料要求"))


func _simple_style(background: Color, border: Color, border_width: int, corner_radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	return style


func delivery_target(order_id: StringName, item_index: int) -> Control:
	if _order_id != order_id or item_index < 0 or item_index >= item_buttons.size():
		return null
	var target := item_buttons[item_index]
	return target if target.visible and not target.disabled else null


func _request_focus() -> void:
	if not _order_id.is_empty():
		focus_requested.emit(_order_id)


func _request_delivery(item_index: int) -> void:
	if not _order_id.is_empty():
		delivery_requested.emit(_order_id, item_index)


func _on_product_source_dropped(item_index: int, source_ref: Dictionary) -> void:
	if not _order_id.is_empty():
		product_dropped.emit(_order_id, item_index, source_ref.duplicate(true))
