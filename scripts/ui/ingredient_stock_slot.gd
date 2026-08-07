class_name IngredientStockSlot
extends Button

signal drag_requested(ingredient_type: StringName, press_position: Vector2)
signal hold_requested(ingredient_type: StringName)
signal hold_advanced(ingredient_type: StringName, delta: float)
signal hold_released(ingredient_type: StringName)

@export var ingredient_type: StringName
@export var stock_textures: Array[Texture2D] = []
@export var drag_threshold_pixels := 10.0
@export var hold_threshold_seconds := 0.2

@onready var artwork: TextureRect = $Artwork
@onready var empty_label: Label = $EmptyLabel

enum GestureState {
	IDLE,
	PENDING,
	HOLDING,
}

var _gesture_state := GestureState.IDLE
var _press_position := Vector2.ZERO
var _hold_elapsed := 0.0


func _ready() -> void:
	set_process(false)
	set_process_input(false)


func _process(delta: float) -> void:
	advance_gesture(delta)


func _input(event: InputEvent) -> void:
	if _gesture_state == GestureState.IDLE:
		return
	if event is InputEventMouseMotion:
		update_gesture((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			end_gesture()


func _gui_input(event: InputEvent) -> void:
	if disabled or not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.pressed:
		begin_gesture(get_viewport().get_mouse_position())
	else:
		end_gesture()
	accept_event()


func begin_gesture(viewport_position: Vector2) -> void:
	if disabled or _gesture_state != GestureState.IDLE:
		return
	_gesture_state = GestureState.PENDING
	_press_position = viewport_position
	_hold_elapsed = 0.0
	set_process(true)
	set_process_input(true)


func update_gesture(viewport_position: Vector2) -> void:
	if _gesture_state != GestureState.PENDING:
		return
	if viewport_position.distance_to(_press_position) <= drag_threshold_pixels:
		return
	var drag_origin := _press_position
	_reset_gesture()
	drag_requested.emit(ingredient_type, drag_origin)


func advance_gesture(delta: float) -> void:
	if _gesture_state == GestureState.HOLDING:
		hold_advanced.emit(ingredient_type, maxf(delta, 0.0))
		return
	if _gesture_state != GestureState.PENDING:
		return
	_hold_elapsed += maxf(delta, 0.0)
	if _hold_elapsed + 0.000001 < hold_threshold_seconds:
		return
	set_process(false)
	if bool(get_meta(&"refill_enabled", false)):
		hold_requested.emit(ingredient_type)


func accept_hold() -> void:
	if _gesture_state != GestureState.PENDING:
		return
	_gesture_state = GestureState.HOLDING
	set_process(true)
	set_process_input(true)


func reject_hold() -> void:
	_reset_gesture()


func stop_hold() -> void:
	_reset_gesture()


func end_gesture() -> void:
	var was_holding := _gesture_state == GestureState.HOLDING
	_reset_gesture()
	if was_holding:
		hold_released.emit(ingredient_type)


func is_hold_active() -> bool:
	return _gesture_state == GestureState.HOLDING


func _reset_gesture() -> void:
	_gesture_state = GestureState.IDLE
	_hold_elapsed = 0.0
	set_process(false)
	set_process_input(false)
	set_pressed_no_signal(false)


func set_stock_quantity(quantity: int) -> void:
	var clamped := clampi(quantity, 0, stock_textures.size())
	if stock_textures.is_empty():
		artwork.visible = false
		empty_label.visible = true
		empty_label.text = "%s\n%s" % [IngredientModel.display_name(ingredient_type), "%d份" % maxi(quantity, 0) if quantity > 0 else "缺货"]
		return
	artwork.visible = clamped > 0
	empty_label.visible = clamped == 0
	if clamped > 0:
		artwork.texture = stock_textures[clamped - 1]
