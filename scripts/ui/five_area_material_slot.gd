class_name FiveAreaMaterialSlot
extends ProductDragSource

@export var stock_id: StringName
@export var recipe_id: StringName
@export var product_id: StringName
@export var source_kind: StringName
@export var material_texture: Texture2D
@export var material_label := ""
@export var reserved := false
@export var unlimited := false

var _display_count := 0
var _display_capacity := 6
var _display_unlocked := false


func _ready() -> void:
	hold_enabled = not unlimited
	hold_threshold_seconds = 0.2
	cancel_pending_on_mouse_exit = true
	super._ready()


func apply_state(count: int, unlocked: bool, capacity: int = 6) -> void:
	var source := {
		"source_kind": source_kind,
		"source_index": -1,
		"stock_id": stock_id,
		"recipe_id": recipe_id,
		"product_id": product_id,
	}
	var can_interact := unlocked and not reserved
	# A locked slot must not leak its future material artwork below the opaque
	# lock layer.  Supplying no texture also keeps the slot honest if the lock
	# artwork is temporarily hidden during a refresh.
	configure(source, material_texture if can_interact else null, can_interact, _hint_text(count, capacity, can_interact))
	set_drag_available(can_interact and (unlimited or count > 0))
	_display_count = count
	_display_capacity = capacity
	_display_unlocked = can_interact
	self_modulate = Color.WHITE if can_interact else Color(0.40, 0.34, 0.28, 0.72)
	queue_redraw()


func _draw() -> void:
	if not _display_unlocked:
		return
	var font := ThemeDB.fallback_font
	var font_size := 14 if size.y >= 70.0 else 11
	var text := "充足" if unlimited else "%d/%d" % [_display_count, _display_capacity]
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var position := Vector2((size.x - text_size.x) * 0.5, size.y - 5.0)
	draw_string(font, position + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.18, 0.08, 0.02, 0.92))
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.91, 0.66, 1.0))


func _hint_text(count: int, capacity: int, unlocked: bool) -> String:
	if not unlocked:
		return "该材料格尚未解锁"
	if unlimited:
		return "%s：供应充足，无需补货" % material_label
	if count <= 0:
		return "%s：长按 0.2 秒补货" % material_label
	if count >= capacity:
		return "%s：库存已满；点击直接投入当前设备" % material_label
	return "%s：点击直接投入当前设备；原地长按补货" % material_label
