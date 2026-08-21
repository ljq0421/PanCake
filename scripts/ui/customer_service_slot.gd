class_name CustomerServiceSlot
extends Control

const PATIENCE_BAR_STYLE := preload("res://scripts/ui/patience_bar_style.gd")
const ORDER_CARD_BACKGROUNDS := {
	1: preload("res://resources/art/ui/order/order_card_product_rows_1_v1.png"),
	2: preload("res://resources/art/ui/order/order_card_product_rows_2_v1.png"),
	3: preload("res://resources/art/ui/order/order_card_product_rows_3_v1.png"),
}
const CARD_WIDTH := 300.0
const BACKGROUND_HEIGHTS := {1: 300.0, 2: 450.0, 3: 450.0}
const ART_ROW_Y := {
	1: [84.0],
	2: [85.0, 248.0],
	3: [64.0, 181.0, 298.0],
}
const PRODUCT_SLOT_SIZE := Vector2(62.0, 62.0)
const INGREDIENT_SLOT_SIZE := Vector2(54.0, 54.0)
const PRODUCT_X := 32.0
const INGREDIENT_X := 94.0
const INGREDIENT_COLUMN_SPACING := 60.0
const INGREDIENT_LINE_SPACING := 62.0
const INGREDIENTS_PER_LINE := 3

signal focus_requested(order_id: StringName)
signal delivery_requested(order_id: StringName, item_index: int)
signal product_dropped(order_id: StringName, item_index: int, source_ref: Dictionary)

@onready var portrait: TextureRect = %Portrait
@onready var portrait_button: Button = %PortraitButton
@onready var card_focus_button: Button = %CardFocusButton
@onready var order_panel: Control = %OrderPanel
@onready var card_background: TextureRect = %CardBackground
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


func _ready() -> void:
	portrait_button.pressed.connect(_request_focus)
	card_focus_button.pressed.connect(_request_focus)
	for item_index in range(item_buttons.size()):
		item_buttons[item_index].pressed.connect(_request_delivery.bind(item_index))
		if item_buttons[item_index].has_signal("product_source_dropped"):
			item_buttons[item_index].connect("product_source_dropped", _on_product_source_dropped)


func bind_order(order: Dictionary, customer_texture: Texture2D, item_textures: Array, requirement_groups: Array, perfect_quote: int) -> void:
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
	_layout_order_rows(items, requirement_groups)
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
	coin_label.visible = false
	var unlimited := bool(order.get("tutorial_no_countdown", false))
	var total := maxf(float(order.get("patience_seconds", 0.0)), 0.001)
	var remaining := maxf(float(order.get("remaining_patience_seconds", total)), 0.0)
	var ratio := 1.0 if unlimited else clampf(remaining / total, 0.0, 1.0)
	patience_bar.visible = not unlimited
	patience_bar.value = ratio * 100.0
	_patience_bar_tier = PATIENCE_BAR_STYLE.apply(patience_bar, ratio, _patience_bar_tier)
	patience_label.text = "教学单 · 不限时" if unlimited else "耐心 %d 秒" % ceili(remaining)


func _layout_order_rows(items: Array, requirement_groups: Array) -> void:
	var item_count := clampi(items.size(), 1, item_buttons.size())
	card_background.texture = ORDER_CARD_BACKGROUNDS[item_count] as Texture2D
	card_background.size = Vector2(CARD_WIDTH, float(BACKGROUND_HEIGHTS[item_count]))
	order_panel.size = card_background.size
	card_focus_button.size = order_panel.size
	var row_positions: Array = ART_ROW_Y[item_count]
	var has_wrapped_ingredients := false
	for group_value in requirement_groups:
		if Array(group_value).size() > INGREDIENTS_PER_LINE:
			has_wrapped_ingredients = true
			break
	var next_row_y := float(row_positions[0])
	var requirement_index := 0
	for item_index in range(item_buttons.size()):
		var has_item := item_index < items.size()
		item_buttons[item_index].visible = has_item
		if not has_item:
			continue
		var group: Array = Array(requirement_groups[item_index]) if item_index < requirement_groups.size() else []
		var line_count := maxi(1, ceili(float(group.size()) / float(INGREDIENTS_PER_LINE)))
		var row_y := next_row_y if has_wrapped_ingredients else float(row_positions[item_index])
		_layout_product_slot(item_index, row_y)
		for group_index in range(group.size()):
			var panel := _ensure_requirement_slot(requirement_index)
			var line_index := group_index / INGREDIENTS_PER_LINE
			var column_index := group_index % INGREDIENTS_PER_LINE
			_layout_requirement_slot(panel, requirement_index, Vector2(
				INGREDIENT_X + float(column_index) * INGREDIENT_COLUMN_SPACING,
				row_y + float(line_index) * INGREDIENT_LINE_SPACING,
			))
			var requirement := Dictionary(group[group_index])
			requirement_icons[requirement_index].texture = requirement.get("texture") as Texture2D
			panel.tooltip_text = "需要加热" if StringName(requirement.get("kind", &"")) == &"heated" else str(requirement.get("display_name", "配料要求"))
			requirement_index += 1
		next_row_y = row_y + float(line_count) * INGREDIENT_LINE_SPACING + 16.0
	for empty_index in range(requirement_index, requirement_panels.size()):
		requirement_panels[empty_index].visible = false
		requirement_icons[empty_index].texture = null
	if has_wrapped_ingredients:
		var required_height := next_row_y + 22.0
		if required_height > order_panel.size.y:
			order_panel.size.y = required_height
			card_background.size.y = required_height
			card_focus_button.size = order_panel.size


func _layout_product_slot(item_index: int, row_y: float) -> void:
	var button := item_buttons[item_index]
	button.position = Vector2(PRODUCT_X, row_y)
	button.size = PRODUCT_SLOT_SIZE
	var icon := item_icons[item_index]
	icon.set_anchors_preset(Control.PRESET_TOP_LEFT)
	icon.position = Vector2.ZERO
	icon.size = PRODUCT_SLOT_SIZE
	var quantity := quantity_labels[item_index]
	quantity.position = Vector2(0.0, PRODUCT_SLOT_SIZE.y - 24.0)
	quantity.size = Vector2(PRODUCT_SLOT_SIZE.x, 24.0)


func _ensure_requirement_slot(index: int) -> Panel:
	if index < requirement_panels.size():
		return requirement_panels[index]
	var panel := Panel.new()
	panel.name = "RequirementExtra%d" % (index + 1)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	order_panel.add_child(panel)
	var icon := TextureRect.new()
	icon.name = "RequirementIconExtra%d" % (index + 1)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	panel.add_child(icon)
	requirement_panels.append(panel)
	requirement_icons.append(icon)
	return panel


func _layout_requirement_slot(panel: Panel, index: int, position_value: Vector2) -> void:
	panel.visible = true
	panel.position = position_value
	panel.size = INGREDIENT_SLOT_SIZE
	panel.theme_override_styles.panel = _ingredient_slot_style()
	var icon := requirement_icons[index]
	icon.set_anchors_preset(Control.PRESET_TOP_LEFT)
	icon.position = Vector2(7.0, 7.0)
	icon.size = Vector2(40.0, 40.0)


func _ingredient_slot_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.94, 0.78, 0.96)
	style.border_color = Color(0.23, 0.11, 0.04, 1.0)
	style.set_border_width_all(3)
	style.corner_radius_top_left = 27
	style.corner_radius_top_right = 27
	style.corner_radius_bottom_right = 27
	style.corner_radius_bottom_left = 27
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
