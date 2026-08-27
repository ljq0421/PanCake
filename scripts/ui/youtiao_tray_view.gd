@tool
class_name YoutiaoTrayView
extends Control

signal fryer_slot_drop_requested(source_index: int, destination_product_id: StringName)
signal product_drag_ended(source_ref: Dictionary, successful: bool)

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
	if not _drop_enabled or not (data is Dictionary):
		return false
	var payload := Dictionary(data)
	if StringName(payload.get("kind", &"")) != &"product_source":
		return false
	var source_ref := Dictionary(payload.get("source_ref", {}))
	if StringName(source_ref.get("product_id", &"")) != destination_product_id:
		return false
	var source_kind := StringName(source_ref.get("source_kind", &""))
	if source_kind == &"youtiao_fryer_slot":
		return accepted_fryer_lane_id == &"left"
	return (
		source_kind == &"fryer_slot"
		and StringName(source_ref.get("lane_id", &"")) == accepted_fryer_lane_id
	)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var source_ref := Dictionary(Dictionary(data).get("source_ref", {}))
	fryer_slot_drop_requested.emit(int(source_ref.get("source_index", -1)), destination_product_id)


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
