class_name CartoonYoutiaoFryerToggle
extends Control

## Self-contained interaction for the left-side fryer prop. It does not alter
## the production model owned by the existing DirectYoutiaoStation.

const FRY_SECONDS := 10.0
const SAFE_LIFT_SECONDS := 5.0
const BURN_SECONDS := 10.0
const DRAIN_SECONDS := 2.0

enum FryState {IDLE, LOADED, FRYING, GOLDEN, DRAINING, READY_TO_SERVE, BURNT}

@export var lowered_machine_texture: Texture2D
@export var raised_machine_texture: Texture2D
@export var raw_youtiao_texture: Texture2D
@export var golden_youtiao_texture: Texture2D
@export var burnt_youtiao_texture: Texture2D

@onready var fryer_visual: TextureRect = %FryerVisual
@onready var dough_visual: TextureRect = %DoughVisual
@onready var product_visual: TextureRect = %ProductVisual
@onready var plate_product_visual: TextureRect = %PlateProductVisual
@onready var drag_visual: TextureRect = %DragVisual
@onready var status_label: Label = %StatusLabel

var _state := FryState.IDLE
var _fry_elapsed := 0.0
var _ready_elapsed := 0.0
var _drain_elapsed := 0.0
var _drag_kind := &""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_reset_idle()


func _process(delta: float) -> void:
	match _state:
		FryState.FRYING:
			_fry_elapsed += maxf(delta, 0.0)
			status_label.text = "油炸中 %d%%" % roundi(clampf(_fry_elapsed / FRY_SECONDS, 0.0, 1.0) * 100.0)
			if _fry_elapsed >= FRY_SECONDS:
				_state = FryState.GOLDEN
				_ready_elapsed = 0.0
				product_visual.texture = golden_youtiao_texture
				status_label.text = "油条已金黄，点击油条机抬起沥网"
		FryState.GOLDEN:
			_ready_elapsed += maxf(delta, 0.0)
			if _ready_elapsed >= SAFE_LIFT_SECONDS + BURN_SECONDS:
				_state = FryState.BURNT
				product_visual.texture = burnt_youtiao_texture
				status_label.text = "油条已炸糊，点击油条机重新开始"
			elif _ready_elapsed >= SAFE_LIFT_SECONDS:
				status_label.text = "油条快炸糊了，请立即点击油条机抬起沥网"
		FryState.DRAINING:
			_drain_elapsed += maxf(delta, 0.0)
			if _drain_elapsed >= DRAIN_SECONDS:
				_state = FryState.READY_TO_SERVE
				status_label.text = "沥油完成，拖拽金黄油条到空盘中"


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
	if _state == FryState.IDLE and dough_visual.get_rect().has_point(point):
		_drag_kind = &"dough"
		drag_visual.texture = raw_youtiao_texture
		drag_visual.position = point - drag_visual.size * 0.5
		drag_visual.visible = true
		dough_visual.visible = false
		return
	if _state == FryState.READY_TO_SERVE and product_visual.get_rect().has_point(point):
		_drag_kind = &"product"
		drag_visual.texture = golden_youtiao_texture
		drag_visual.position = point - drag_visual.size * 0.5
		drag_visual.visible = true
		product_visual.visible = false


func _finish_drag_or_click(point: Vector2) -> void:
	if _drag_kind == &"dough":
		drag_visual.visible = false
		if fryer_visual.get_rect().has_point(point):
			_load_dough()
		else:
			dough_visual.visible = true
	elif _drag_kind == &"product":
		drag_visual.visible = false
		if _plate_rect().has_point(point):
			_serve_product()
		else:
			product_visual.visible = true
	else:
		if fryer_visual.get_rect().has_point(point):
			_on_machine_clicked()
	_drag_kind = &""


func _load_dough() -> void:
	_state = FryState.LOADED
	fryer_visual.texture = raised_machine_texture
	product_visual.visible = false
	status_label.text = "面坯已入篮，点击油条机放下沥网开始油炸"


func _on_machine_clicked() -> void:
	match _state:
		FryState.LOADED:
			_state = FryState.FRYING
			_fry_elapsed = 0.0
			fryer_visual.texture = lowered_machine_texture
			product_visual.texture = raw_youtiao_texture
			product_visual.visible = true
			status_label.text = "沥网已放下，开始油炸"
		FryState.GOLDEN:
			_state = FryState.DRAINING
			_drain_elapsed = 0.0
			fryer_visual.texture = raised_machine_texture
			status_label.text = "沥网已抬起，正在沥油"
		FryState.BURNT:
			_reset_idle()


func _serve_product() -> void:
	plate_product_visual.texture = golden_youtiao_texture
	plate_product_visual.visible = true
	_state = FryState.IDLE
	fryer_visual.texture = raised_machine_texture
	dough_visual.visible = true
	product_visual.visible = false
	status_label.text = "金黄油条已放入盘中，可继续制作"


func _reset_idle() -> void:
	_state = FryState.IDLE
	_fry_elapsed = 0.0
	_ready_elapsed = 0.0
	_drain_elapsed = 0.0
	_drag_kind = &""
	fryer_visual.texture = raised_machine_texture
	dough_visual.visible = true
	product_visual.visible = false
	drag_visual.visible = false
	status_label.text = "拖拽案板上的油条面坯到油条机"


func _plate_rect() -> Rect2:
	return Rect2(Vector2(340.0, 440.0), Vector2(260.0, 210.0))
