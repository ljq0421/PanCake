class_name HandoffTraySlot
extends PanelContainer

signal product_source_dropped(source_ref: Dictionary, item_index: int)
signal staged_drag_started(item_index: int)

const PRODUCT_VISUALS := preload("res://scripts/ui/five_area_product_visuals.gd")

@export var item_index := 0
@export var drag_threshold_pixels := 10.0

@onready var request_icon: TextureRect = $RequestIcon
@onready var actual_icon: TextureRect = $ActualIcon
@onready var quantity_label: Label = $QuantityLabel
@onready var mismatch_mark: Label = $MismatchMark

var _order_id: StringName = &""
var _item: Dictionary = {}
var _products: Array[Dictionary] = []
var _press_position := Vector2.ZERO
var _pressed_for_drag := false


func configure(order_id: StringName, item: Dictionary) -> void:
	_order_id = order_id
	_item = item.duplicate(true)
	_products.clear()
	for product_value in Array(item.get("attached_products", [])):
		_products.append(Dictionary(product_value).duplicate(true))
	if _products.is_empty():
		var legacy_product := Dictionary(item.get("attached_product", {})).duplicate(true)
		if not legacy_product.is_empty():
			_products.append(legacy_product)
	var requested_product_id := StringName(item.get("product_id", &""))
	request_icon.texture = PRODUCT_VISUALS.texture_for(requested_product_id, StringName(item.get("temperature_mode", &"room_temperature")))
	request_icon.visible = request_icon.texture != null
	actual_icon.texture = null
	actual_icon.visible = not _products.is_empty()
	if not _products.is_empty():
		var actual: Dictionary = _products.back()
		actual_icon.texture = PRODUCT_VISUALS.texture_for(StringName(actual.get("product_id", &"")), StringName(actual.get("temperature_mode", &"room_temperature")))
		actual_icon.visible = actual_icon.texture != null
	var required := maxi(int(item.get("quantity", 1)), 1)
	quantity_label.text = "%d/%d" % [_products.size(), required]
	mismatch_mark.visible = _has_visible_mismatch(item, _products)
	tooltip_text = "请求剪影与实际餐品同时保留；拖出餐品可退货或废弃。"


func clear_slot() -> void:
	configure(&"", {})
	request_icon.visible = false
	quantity_label.text = "—"


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and StringName(Dictionary(data).get("kind", &"")) == &"product_source" and not _order_id.is_empty()


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	product_source_dropped.emit(Dictionary(Dictionary(data).get("source_ref", {})).duplicate(true), item_index)


func _gui_input(event: InputEvent) -> void:
	if _products.is_empty():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed_for_drag = true
			_press_position = event.position
		else:
			_pressed_for_drag = false
	elif event is InputEventMouseMotion and _pressed_for_drag and event.position.distance_to(_press_position) > drag_threshold_pixels:
		_pressed_for_drag = false
		var product: Dictionary = _products.back()
		var preview := TextureRect.new()
		preview.texture = actual_icon.texture
		preview.custom_minimum_size = Vector2(72.0, 72.0)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		force_drag({"kind": &"staged_product", "order_id": _order_id, "item_index": item_index, "product": product.duplicate(true)}, preview)
		staged_drag_started.emit(item_index)
		accept_event()


static func _has_visible_mismatch(item: Dictionary, products: Array[Dictionary]) -> bool:
	for product in products:
		if StringName(product.get("product_id", &"")) != StringName(item.get("product_id", &"")):
			return true
		if StringName(item.get("area_id", &"")) != &"area.pancake" and StringName(product.get("temperature_mode", &"room_temperature")) != StringName(item.get("temperature_mode", &"room_temperature")):
			return true
	return false
