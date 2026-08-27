extends Control

## Standalone art-composition preview.  It deliberately does not touch the
## gameplay scene or GameSession, so the new visual direction can be judged in
## isolation before the production workstation is migrated.

const TIER_NAMES := ["初级豆浆机", "中级豆浆机", "高级豆浆机"]
const YOUTIAO_NAMES := ["油条面坯", "原味油条", "烧焦油条"]

@onready var tier_label: Label = %TierLabel
@onready var food_label: Label = %FoodLabel
@onready var hint_label: Label = %HintLabel
@onready var machines: Array[TextureRect] = [%SoyMilkBasic, %SoyMilkMid, %SoyMilkAdvanced]
@onready var fryers: Array[TextureRect] = [%FryerBasicRaised, %FryerBasicLowered, %FryerAdvancedRaised, %FryerAdvancedLowered]
@onready var youtiao_variants: Array[TextureRect] = [%YoutiaoDough, %YoutiaoPlain, %YoutiaoBurnt]

var _machine_tier := 2
var _youtiao_variant := 1
var _advanced_fryer := true
var _fryer_lowered := false


func _ready() -> void:
	%SoyMilkButton.pressed.connect(_cycle_machine_tier)
	%FryerButton.pressed.connect(_toggle_fryer)
	%YoutiaoButton.pressed.connect(_cycle_youtiao)
	_apply_preview(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_left"):
		_machine_tier = posmod(_machine_tier - 1, machines.size())
		_apply_preview()
	elif event.is_action_pressed(&"ui_right"):
		_cycle_machine_tier()
	elif event.is_action_pressed(&"ui_accept"):
		_toggle_fryer()
	elif event.is_action_pressed(&"ui_up"):
		_cycle_youtiao()


func _cycle_machine_tier() -> void:
	_machine_tier = (_machine_tier + 1) % machines.size()
	_apply_preview()


func _toggle_fryer() -> void:
	_fryer_lowered = not _fryer_lowered
	_apply_preview()


func _cycle_youtiao() -> void:
	_youtiao_variant = (_youtiao_variant + 1) % youtiao_variants.size()
	_apply_preview()


func _apply_preview(initial: bool = false) -> void:
	for index in machines.size():
		machines[index].visible = index == _machine_tier
	for index in fryers.size():
		fryers[index].visible = index == _fryer_index()
	for index in youtiao_variants.size():
		youtiao_variants[index].visible = index == _youtiao_variant

	tier_label.text = "豆浆档 · %s" % TIER_NAMES[_machine_tier]
	food_label.text = "油条出品 · %s" % YOUTIAO_NAMES[_youtiao_variant]
	hint_label.text = "炸篮%s · 点击按钮或使用 ← → / 空格 / ↑ 切换" % ("已落下" if _fryer_lowered else "已抬起")
	if not initial:
		_pulse_active_art()


func _fryer_index() -> int:
	if _advanced_fryer:
		return 3 if _fryer_lowered else 2
	return 1 if _fryer_lowered else 0


func _pulse_active_art() -> void:
	var active_nodes: Array[CanvasItem] = [machines[_machine_tier], fryers[_fryer_index()], youtiao_variants[_youtiao_variant]]
	for art in active_nodes:
		art.scale = Vector2(0.96, 0.96)
		var tween := create_tween()
		tween.tween_property(art, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
