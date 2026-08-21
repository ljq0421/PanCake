class_name CustomerServiceSlot
extends Control

const PATIENCE_BAR_STYLE := preload("res://scripts/ui/patience_bar_style.gd")

signal focus_requested(order_id: StringName)
signal delivery_requested(order_id: StringName, item_index: int)
signal product_dropped(order_id: StringName, item_index: int, source_ref: Dictionary)

@onready var portrait: TextureRect = %Portrait
@onready var portrait_button: Button = %PortraitButton
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


func _ready() -> void:
	portrait_button.pressed.connect(_request_focus)
	card_focus_button.pressed.connect(_request_focus)
	for item_index in range(item_buttons.size()):
		item_buttons[item_index].pressed.connect(_request_delivery.bind(item_index))
		if item_buttons[item_index].has_signal("product_source_dropped"):
			item_buttons[item_index].connect("product_source_dropped", _on_product_source_dropped)


func bind_order(order: Dictionary, customer_texture: Texture2D, item_textures: Array, requirements: Array, perfect_quote: int) -> void:
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
	for requirement_index in range(requirement_panels.size()):
		var has_requirement := requirement_index < requirements.size()
		requirement_panels[requirement_index].visible = has_requirement
		if not has_requirement:
			continue
		var requirement := Dictionary(requirements[requirement_index])
		requirement_icons[requirement_index].texture = requirement.get("texture") as Texture2D
		requirement_panels[requirement_index].tooltip_text = "需要加热" if StringName(requirement.get("kind", &"")) == &"heated" else str(requirement.get("display_name", "配料要求"))
	coin_label.visible = false
	var unlimited := bool(order.get("tutorial_no_countdown", false))
	var total := maxf(float(order.get("patience_seconds", 0.0)), 0.001)
	var remaining := maxf(float(order.get("remaining_patience_seconds", total)), 0.0)
	var ratio := 1.0 if unlimited else clampf(remaining / total, 0.0, 1.0)
	patience_bar.visible = not unlimited
	patience_bar.value = ratio * 100.0
	_patience_bar_tier = PATIENCE_BAR_STYLE.apply(patience_bar, ratio, _patience_bar_tier)
	patience_label.text = "教学单 · 不限时" if unlimited else "耐心 %d 秒" % ceili(remaining)


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
