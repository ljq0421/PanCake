@tool
class_name YoutiaoTrayView
extends Control

signal product_drag_ended(source_ref: Dictionary, successful: bool)
signal tray_clicked

@export var destination_product_id: StringName = &"product.youtiao.plain"
@export var prepared_slot_id: StringName = &"slot.04"
@export var accepted_fryer_lane_id: StringName = &"left"
@export var product_hint := "从成品盘拖成品到出餐位"
@export var slot_origin := Vector2(48.0, 62.0)
@export var slot_step := Vector2(44.0, 0.0)
@export var slot_size := Vector2(48.0, 104.0)
@export_range(1, 4, 1) var slot_columns := 4

@onready var artwork: TextureRect = %Artwork
@onready var product_sources: Array[ProductDragSource] = [
	%ProductSource1,
	%ProductSource2,
	%ProductSource3,
	%ProductSource4,
]

var _drop_enabled := false
var _editor_layout_signature := 0
var _tray_click_press_position := Vector2.ZERO
var _tray_click_pending := false


func _ready() -> void:
	_apply_slot_layout()
	set_process(Engine.is_editor_hint())
	if Engine.is_editor_hint():
		_editor_layout_signature = _layout_signature()
		for source in product_sources:
			source.visible = false
			source.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	for source in product_sources:
		source.z_index = artwork.z_index + 1
		source.native_drag_enabled = true
		source.drag_threshold_pixels = 4.0
		source.set_drop_forward_target(self)
		source.drag_ended.connect(_on_product_drag_ended)
		_hide_source(source)


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	var signature := _layout_signature()
	if signature == _editor_layout_signature:
		return
	_editor_layout_signature = signature
	_apply_slot_layout()


func set_artwork_texture(value: Texture2D) -> void:
	artwork.texture = value


func set_drop_enabled(value: bool) -> void:
	_drop_enabled = value


func preview_products(product_texture: Texture2D, count: int = 4) -> void:
	_apply_slot_layout()
	for slot_index in range(product_sources.size()):
		var source := product_sources[slot_index]
		source.texture_normal = product_texture
		source.texture_disabled = product_texture
		source.disabled = true
		source.mouse_filter = Control.MOUSE_FILTER_IGNORE
		source.visible = slot_index < clampi(count, 0, product_sources.size())


func configure_products(entries: Array[Dictionary], product_texture: Texture2D, interaction_enabled: bool) -> void:
	_apply_slot_layout()
	for slot_index in range(product_sources.size()):
		var source := product_sources[slot_index]
		if slot_index >= entries.size():
			_hide_source(source)
			continue
		var entry := entries[slot_index]
		var source_index := int(entry.get("source_index", -1))
		var product_id := StringName(entry.get("product_id", &""))
		source.self_modulate = Color.WHITE
		source.configure({
			"source_kind": &"prepared_product_slot",
			"source_slot_id": prepared_slot_id,
			"source_index": source_index,
			"product_id": product_id,
			"discardable": true,
		}, product_texture, interaction_enabled, product_hint)
		source.set_alpha_hit_regions([{"texture": product_texture, "rect": Rect2(Vector2.ZERO, source.size)}])
		source.mouse_filter = Control.MOUSE_FILTER_STOP if interaction_enabled else Control.MOUSE_FILTER_IGNORE
		source.visible = true


func contains_canvas_point(canvas_point: Vector2) -> bool:
	var local_point := get_global_transform_with_canvas().affine_inverse() * canvas_point
	return Rect2(Vector2.ZERO, size).has_point(local_point)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# Finished food is collected by clicking the matching tray, never by
	# dragging it from the filter. Keeping this false also prevents a product
	# source nested in the tray from forwarding a fryer drop back to the tray.
	return false


func _gui_input(event: InputEvent) -> void:
	if not _drop_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_tray_click_pending = true
			_tray_click_press_position = event.position
		else:
			if _tray_click_pending and event.position.distance_to(_tray_click_press_position) <= 4.0:
				tray_clicked.emit()
			accept_event()
			_tray_click_pending = false
	elif event is InputEventMouseMotion and _tray_click_pending and event.position.distance_to(_tray_click_press_position) > 4.0:
		_tray_click_pending = false


func _apply_slot_layout() -> void:
	var columns := maxi(slot_columns, 1)
	for slot_index in range(product_sources.size()):
		var source := product_sources[slot_index]
		var column := slot_index % columns
		var row := slot_index / columns
		source.position = slot_origin + Vector2(slot_step.x * float(column), slot_step.y * float(row))
		source.size = slot_size


func _layout_signature() -> int:
	return [slot_origin, slot_step, slot_size, slot_columns].hash()


func _hide_source(source: ProductDragSource) -> void:
	source.configure({}, null, false)
	source.set_alpha_hit_regions([])
	source.mouse_filter = Control.MOUSE_FILTER_IGNORE
	source.visible = false


func _on_product_drag_ended(source_ref: Dictionary, successful: bool) -> void:
	product_drag_ended.emit(source_ref, successful)
