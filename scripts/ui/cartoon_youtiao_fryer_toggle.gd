class_name CartoonYoutiaoFryerToggle
extends Control

## Self-contained interaction for the left-side fryer prop. It does not alter
## the production model owned by the existing DirectYoutiaoStation.

const FRY_SECONDS := 10.0
const SAFE_LIFT_SECONDS := 5.0
const BURN_SECONDS := 10.0
const DRAIN_SECONDS := 2.0
const BATCH_CAPACITY := 2
const RAISED_PRODUCT_POSITIONS := [Vector2(225.0, 68.0), Vector2(310.0, 68.0)]
const LOWERED_PRODUCT_POSITIONS := [Vector2(225.0, 132.0), Vector2(310.0, 132.0)]
const GOLDEN_TINT := Color(1.0, 0.8, 0.3, 1.0)

enum FryState {IDLE, LOADED, FRYING, GOLDEN, DRAINING, READY_TO_SERVE, BURNT}

@export var lowered_machine_texture: Texture2D
@export var raised_machine_texture: Texture2D
@export var raw_youtiao_texture: Texture2D
@export var golden_youtiao_texture: Texture2D
@export var burnt_youtiao_texture: Texture2D
@export var reduce_motion := false

@onready var fryer_visual: TextureRect = %FryerVisual
@onready var dough_visuals: Array[TextureRect] = [%DoughVisual1, %DoughVisual2]
@onready var product_visuals: Array[TextureRect] = [%ProductVisual1, %ProductVisual2]
@onready var plate_product_visuals: Array[TextureRect] = [%PlateProductVisual1, %PlateProductVisual2]
@onready var drag_visual: TextureRect = %DragVisual
@onready var status_label: Label = %StatusLabel

var _state := FryState.IDLE
var _fry_elapsed := 0.0
var _ready_elapsed := 0.0
var _drain_elapsed := 0.0
var _loaded_count := 0
var _served_count := 0
var _finished_texture: Texture2D
var _finished_is_golden := false
var _drag_kind := &""
var _drag_item_index := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	for visual in product_visuals:
		visual.pivot_offset = visual.size * 0.5
	_reset_idle()


func _process(delta: float) -> void:
	match _state:
		FryState.FRYING:
			_fry_elapsed += maxf(delta, 0.0)
			_update_frying_visuals()
			if _fry_elapsed >= FRY_SECONDS:
				_state = FryState.GOLDEN
				_ready_elapsed = 0.0
				_finished_texture = golden_youtiao_texture
				_finished_is_golden = true
				_set_batch_golden_appearance()
				status_label.text = "油条已金黄，点击油条机抬起沥网"
		FryState.GOLDEN:
			_ready_elapsed += maxf(delta, 0.0)
			if _ready_elapsed >= SAFE_LIFT_SECONDS + BURN_SECONDS:
				_state = FryState.BURNT
				_finished_texture = burnt_youtiao_texture
				_finished_is_golden = false
				_set_batch_appearance(burnt_youtiao_texture)
				status_label.text = "油条已炸糊，点击油条机抬起沥网"
			elif _ready_elapsed >= SAFE_LIFT_SECONDS:
				status_label.text = "油条快炸糊了，请立即点击油条机抬起沥网"
		FryState.DRAINING:
			_drain_elapsed += maxf(delta, 0.0)
			if _drain_elapsed >= DRAIN_SECONDS:
				_state = FryState.READY_TO_SERVE
				status_label.text = "沥油完成，逐根拖拽油条到盘中"


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag_or_click(event.position)
		else:
			_finish_drag_or_click(event.position)
		accept_event()
	elif event is InputEventMouseMotion and not _drag_kind.is_empty():
		drag_visual.position = event.position - drag_visual.size * 0.5
		accept_event()


func _begin_drag_or_click(point: Vector2) -> void:
	if _state == FryState.IDLE or _state == FryState.LOADED:
		var dough_index := _visible_item_at(dough_visuals, point)
		if dough_index >= 0:
			_begin_drag(&"dough", dough_index, raw_youtiao_texture, point)
			return
	if _state == FryState.READY_TO_SERVE:
		if _served_count >= BATCH_CAPACITY:
			status_label.text = "盘子已放满两根油条"
			return
		var product_index := _visible_item_at(product_visuals, point)
		if product_index >= 0:
			_begin_drag(&"product", product_index, _finished_texture, point)


func _finish_drag_or_click(point: Vector2) -> void:
	if _drag_kind == &"dough":
		drag_visual.visible = false
		if fryer_visual.get_rect().has_point(point):
			_load_dough(_drag_item_index, drag_visual.position, true)
		else:
			dough_visuals[_drag_item_index].visible = true
	elif _drag_kind == &"product":
		drag_visual.visible = false
		if _plate_rect().has_point(point) and _served_count < BATCH_CAPACITY:
			_serve_product(_drag_item_index, drag_visual.position, true)
		else:
			product_visuals[_drag_item_index].visible = true
	else:
		if fryer_visual.get_rect().has_point(point):
			_on_machine_clicked()
	_drag_kind = &""
	_drag_item_index = -1


func _begin_drag(kind: StringName, item_index: int, texture: Texture2D, point: Vector2) -> void:
	_drag_kind = kind
	_drag_item_index = item_index
	drag_visual.texture = texture
	drag_visual.modulate = GOLDEN_TINT if kind == &"product" and _finished_is_golden else Color.WHITE
	drag_visual.position = point - drag_visual.size * 0.5
	drag_visual.visible = true
	if kind == &"dough":
		dough_visuals[item_index].visible = false
	else:
		product_visuals[item_index].visible = false


func _load_dough(dough_index := -1, source_position := Vector2.ZERO, animate := false) -> void:
	if _loaded_count >= BATCH_CAPACITY:
		return
	if dough_index < 0:
		dough_index = _first_visible_index(dough_visuals)
	if dough_index < 0 or (not dough_visuals[dough_index].visible and not animate):
		return
	var product_visual := product_visuals[_loaded_count]
	dough_visuals[dough_index].visible = false
	product_visual.texture = raw_youtiao_texture
	product_visual.modulate = Color.WHITE
	product_visual.scale = Vector2.ONE
	product_visual.visible = true
	_loaded_count += 1
	var target_position := product_visual.position
	if animate:
		product_visual.position = source_position
	_animate_to_position(product_visual, target_position, animate)
	_state = FryState.LOADED
	fryer_visual.texture = raised_machine_texture
	if _loaded_count == BATCH_CAPACITY:
		status_label.text = "两根面坯已入篮，点击油条机放下沥网开始油炸"
	else:
		status_label.text = "面坯已入篮，可继续拖入第 2 根，或点击油条机开始油炸"


func _on_machine_clicked() -> void:
	match _state:
		FryState.LOADED:
			_state = FryState.FRYING
			_fry_elapsed = 0.0
			fryer_visual.texture = lowered_machine_texture
			_move_batch_to(LOWERED_PRODUCT_POSITIONS, true)
			_set_batch_appearance(raw_youtiao_texture)
			status_label.text = "沥网已放下，油条开始油炸"
		FryState.GOLDEN, FryState.BURNT:
			_state = FryState.DRAINING
			_drain_elapsed = 0.0
			fryer_visual.texture = raised_machine_texture
			_move_batch_to(RAISED_PRODUCT_POSITIONS, true)
			status_label.text = "沥网已抬起，正在沥油"


func _serve_product(product_index := -1, source_position := Vector2.ZERO, animate := false) -> void:
	if _served_count >= BATCH_CAPACITY:
		return
	if product_index < 0:
		product_index = _first_visible_index(product_visuals)
	if product_index < 0:
		return
	var plate_visual := plate_product_visuals[_served_count]
	plate_visual.texture = _finished_texture
	plate_visual.modulate = GOLDEN_TINT if _finished_is_golden else Color.WHITE
	plate_visual.scale = Vector2.ONE
	plate_visual.visible = true
	product_visuals[product_index].visible = false
	_served_count += 1
	var target_position := plate_visual.position
	if animate:
		plate_visual.position = source_position
	_animate_to_position(plate_visual, target_position, animate)
	if _first_visible_index(product_visuals) >= 0:
		status_label.text = "已放入第 %d 根，继续拖拽另一根油条到盘中" % _served_count
		return
	_loaded_count = 0
	_state = FryState.IDLE
	fryer_visual.texture = raised_machine_texture
	if _served_count == BATCH_CAPACITY:
		status_label.text = "盘子已放满两根油条"
	elif _first_visible_index(dough_visuals) >= 0:
		status_label.text = "油条已入盘，可继续拖拽案板上的面坯"
	else:
		status_label.text = "油条已入盘"


func _update_frying_visuals() -> void:
	var progress := clampf(_fry_elapsed / FRY_SECONDS, 0.0, 1.0)
	var tint := Color.WHITE if progress < 0.55 else GOLDEN_TINT
	var pulse := 1.0 if reduce_motion else 1.0 + sin(_fry_elapsed * 8.0) * 0.025
	for item_index in _loaded_count:
		var product_visual := product_visuals[item_index]
		product_visual.texture = raw_youtiao_texture
		product_visual.modulate = tint
		product_visual.scale = Vector2.ONE * pulse
	var stage := "油温加热中" if progress < 0.55 else "油条正在上色"
	status_label.text = "%s %d%%" % [stage, roundi(progress * 100.0)]


func _set_batch_appearance(texture: Texture2D) -> void:
	for item_index in _loaded_count:
		var product_visual := product_visuals[item_index]
		product_visual.texture = texture
		product_visual.modulate = Color.WHITE
		product_visual.scale = Vector2.ONE
		product_visual.visible = true


func _set_batch_golden_appearance() -> void:
	for item_index in _loaded_count:
		var product_visual := product_visuals[item_index]
		product_visual.texture = raw_youtiao_texture
		product_visual.modulate = GOLDEN_TINT
		product_visual.scale = Vector2.ONE
		product_visual.visible = true


func _move_batch_to(positions: Array, should_animate: bool) -> void:
	for item_index in _loaded_count:
		_animate_to_position(product_visuals[item_index], positions[item_index], should_animate)


func _animate_to_position(visual: TextureRect, target_position: Vector2, should_animate: bool) -> void:
	if not should_animate or reduce_motion:
		visual.position = target_position
		return
	var final_modulate := visual.modulate
	visual.modulate = Color(final_modulate.r, final_modulate.g, final_modulate.b, 0.72)
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(visual, "position", target_position, 0.24)
	tween.tween_property(visual, "modulate", final_modulate, 0.18)


func _visible_item_at(items: Array[TextureRect], point: Vector2) -> int:
	for item_index in items.size():
		if items[item_index].visible and items[item_index].get_rect().has_point(point):
			return item_index
	return -1


func _first_visible_index(items: Array[TextureRect]) -> int:
	for item_index in items.size():
		if items[item_index].visible:
			return item_index
	return -1


func _reset_idle() -> void:
	_state = FryState.IDLE
	_fry_elapsed = 0.0
	_ready_elapsed = 0.0
	_drain_elapsed = 0.0
	_loaded_count = 0
	_served_count = 0
	_finished_texture = golden_youtiao_texture
	_finished_is_golden = false
	_drag_kind = &""
	_drag_item_index = -1
	fryer_visual.texture = raised_machine_texture
	for dough_visual in dough_visuals:
		dough_visual.visible = true
	for item_index in product_visuals.size():
		var product_visual := product_visuals[item_index]
		product_visual.position = RAISED_PRODUCT_POSITIONS[item_index]
		product_visual.visible = false
		product_visual.modulate = Color.WHITE
		product_visual.scale = Vector2.ONE
	for plate_visual in plate_product_visuals:
		plate_visual.visible = false
	drag_visual.visible = false
	drag_visual.modulate = Color.WHITE
	status_label.text = "拖拽案板上的两根油条面坯到油条机"


func _plate_rect() -> Rect2:
	return Rect2(Vector2(340.0, 440.0), Vector2(260.0, 210.0))
