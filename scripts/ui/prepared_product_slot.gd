class_name PreparedProductSlot
extends Button

signal drag_requested(ingredient_type: StringName, press_position: Vector2)
signal store_completed(result: Dictionary)

@export var slot_id: StringName
@export var product_id: StringName
@export var ingredient_type: StringName
@export var product_texture: Texture2D
@export var allow_pancake_drag := false
@export var drag_threshold_pixels := 10.0

@onready var artwork: TextureRect = $Artwork
@onready var count_label: Label = $CountLabel

var _count := 0
var _unlocked := false
var _press_pending := false
var _press_position := Vector2.ZERO


func _ready() -> void:
	artwork.texture = product_texture
	_refresh_visual()


func configure_count(count: int, unlocked: bool) -> void:
	_count = clampi(count, 0, 6)
	_unlocked = unlocked
	_refresh_visual()


func _refresh_visual() -> void:
	if not is_node_ready():
		return
	artwork.visible = true
	artwork.modulate = Color.WHITE if _count > 0 else Color(1.0, 1.0, 1.0, 0.28)
	count_label.text = "%d/6" % _count if _unlocked else "未解锁"
	tooltip_text = (
		"拖入匹配炸物；拖出原味油条可加入煎饼" if allow_pancake_drag and _unlocked
		else "拖入匹配炸物" if _unlocked
		else "对应炸物配方尚未解锁"
	)
	if _unlocked:
		tooltip_text = "可拖到制作区使用，也可拖到废弃区逐份丢弃" if allow_pancake_drag else "可拖到废弃区逐份丢弃"
	mouse_default_cursor_shape = Control.CURSOR_DRAG if _count > 0 else Control.CURSOR_POINTING_HAND


func _gui_input(event: InputEvent) -> void:
	if _count <= 0 or not _unlocked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_pending = true
			_press_position = get_viewport().get_mouse_position()
		else:
			_press_pending = false
	elif event is InputEventMouseMotion and _press_pending:
		var current := get_viewport().get_mouse_position()
		if current.distance_to(_press_position) > drag_threshold_pixels:
			_press_pending = false
			if allow_pancake_drag:
				drag_requested.emit(ingredient_type, _press_position)
			var preview := TextureRect.new()
			preview.texture = product_texture
			preview.custom_minimum_size = Vector2(64.0, 64.0)
			preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			force_drag({
				"kind": &"product_source",
				"source_ref": {
					"source_kind": &"prepared_product_slot",
					"source_slot_id": slot_id,
					"source_index": -1,
					"product_id": product_id,
					"discardable": true,
				},
			}, preview)
			accept_event()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var payload := Dictionary(data)
	if StringName(payload.get("kind", &"")) != &"product_source":
		return false
	var source_ref := Dictionary(payload.get("source_ref", {}))
	return (
		_unlocked
		and _count < 6
		and StringName(source_ref.get("source_kind", &"")) == &"youtiao_output"
		and StringName(source_ref.get("product_id", &"")) == product_id
	)


func _drop_data(_at_position: Vector2, _data: Variant) -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null or not session.has_method("store_ready_youtiao_in_prepared_slot"):
		store_completed.emit({"success": false, "reason": &"no_game_session"})
		return
	var result: Dictionary = session.call("store_ready_youtiao_in_prepared_slot", slot_id)
	store_completed.emit(result)
