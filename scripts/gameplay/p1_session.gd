class_name P1Session
extends RefCounted

signal changed

const IMPATIENT_RATIO_THRESHOLD := 0.30
const SATISFIED_SCORE_THRESHOLD := 70.0
const MINIMUM_FLIP_DONENESS := 0.30
const REACTION_NEUTRAL: StringName = &"neutral"
const REACTION_IMPATIENT: StringName = &"impatient"
const REACTION_SATISFIED: StringName = &"satisfied"
const REACTION_VERY_UNHAPPY: StringName = &"very_unhappy"

enum Phase {
	SPREAD,
	FIRST_SIDE,
	SECOND_SIDE,
	SAUCE_AND_FILLINGS,
	FOLD,
	PACKAGE,
	READY_TO_SERVE,
	HANDOFF,
	PAYMENT,
	RESULT,
}

var order: Dictionary = {}
var phase: Phase = Phase.SPREAD
var elapsed_seconds := 0.0
var patience_seconds := 72.0
var heat_level := 0.50
var result: Dictionary = {}
var payment_ready := false
var impatient_at_handoff := false
var has_patience_countdown := true


func start(next_order: Dictionary) -> void:
	order = next_order.duplicate(true)
	phase = Phase.SPREAD
	elapsed_seconds = 0.0
	patience_seconds = float(order.get("time_limit", 72.0))
	has_patience_countdown = not bool(order.get("tutorial_no_countdown", false))
	heat_level = 0.50
	result.clear()
	payment_ready = false
	impatient_at_handoff = false
	changed.emit()


func advance_time(delta: float) -> void:
	if phase in [Phase.HANDOFF, Phase.PAYMENT, Phase.RESULT]:
		return
	var safe_delta := maxf(delta, 0.0)
	elapsed_seconds += safe_delta
	if has_patience_countdown:
		patience_seconds = maxf(patience_seconds - safe_delta, 0.0)
	changed.emit()


func patience_ratio() -> float:
	if not has_patience_countdown:
		return 1.0
	return clampf(patience_seconds / maxf(float(order.get("time_limit", 72.0)), 0.001), 0.0, 1.0)


func is_impatient_now() -> bool:
	return patience_ratio() <= IMPATIENT_RATIO_THRESHOLD


func post_handoff_reaction() -> StringName:
	if result.is_empty():
		return REACTION_NEUTRAL
	var dissatisfied := float(result.get("score", 0.0)) < SATISFIED_SCORE_THRESHOLD
	if impatient_at_handoff and dissatisfied:
		return REACTION_VERY_UNHAPPY
	if impatient_at_handoff or dissatisfied:
		return REACTION_IMPATIENT
	return REACTION_SATISFIED


func confirm_spread(model: PancakeModel) -> Dictionary:
	if model.covered_cell_count() <= 0:
		return {"success": false, "reason": "当前没有可继续制作的面饼"}
	phase = Phase.FIRST_SIDE
	changed.emit()
	return {"success": true}


func request_flip(model: PancakeModel, ingredients: IngredientModel) -> Dictionary:
	var readiness := flip_readiness(model, ingredients)
	if not bool(readiness.get("success", false)):
		return readiness
	model.flip(true)
	phase = Phase.SAUCE_AND_FILLINGS
	changed.emit()
	return {"success": true}


func flip_readiness(model: PancakeModel, ingredients: IngredientModel) -> Dictionary:
	if phase != Phase.FIRST_SIDE:
		return {"success": false, "reason": "当前还不能翻面"}
	if model.mean_side_doneness(false) < MINIMUM_FLIP_DONENESS:
		return {"success": false, "reason": "底面还太生，颜色转金黄后再翻"}
	return {"success": true}


func finish_cooking(model: PancakeModel) -> Dictionary:
	if phase == Phase.SAUCE_AND_FILLINGS:
		return {"success": true}
	if phase != Phase.SECOND_SIDE:
		return {"success": false, "reason": "需要先完成翻面"}
	phase = Phase.SAUCE_AND_FILLINGS
	changed.emit()
	return {"success": true}


func begin_folding() -> Dictionary:
	if phase != Phase.SAUCE_AND_FILLINGS and phase != Phase.FOLD:
		return {"success": false, "reason": "完成翻面后才能折叠"}
	phase = Phase.FOLD
	changed.emit()
	return {"success": true}


func mark_ready_for_package() -> Dictionary:
	if phase != Phase.FOLD:
		return {"success": false, "reason": "需要先完成折叠"}
	phase = Phase.PACKAGE
	changed.emit()
	return {"success": true}


func mark_packaged() -> Dictionary:
	if phase != Phase.PACKAGE:
		return {"success": false, "reason": "需要先选择有效包装"}
	phase = Phase.READY_TO_SERVE
	changed.emit()
	return {"success": true}


func begin_handoff(score_result: Dictionary) -> Dictionary:
	if phase != Phase.READY_TO_SERVE:
		return {"success": false, "reason": "成品尚未完成包装，不能递给顾客"}
	result = score_result.duplicate(true)
	impatient_at_handoff = is_impatient_now()
	phase = Phase.HANDOFF
	changed.emit()
	return {"success": true}


func begin_handoff_from_tray(score_result: Dictionary) -> Dictionary:
	if phase != Phase.SPREAD:
		return {"success": false, "reason": "当前订单正在制作，不能直接交付托盘成品"}
	result = score_result.duplicate(true)
	impatient_at_handoff = is_impatient_now()
	phase = Phase.HANDOFF
	changed.emit()
	return {"success": true}


func begin_payment() -> Dictionary:
	if phase != Phase.HANDOFF:
		return {"success": false, "reason": "顾客尚未接到餐品"}
	phase = Phase.PAYMENT
	changed.emit()
	return {"success": true}


func finish_payment() -> Dictionary:
	if phase != Phase.PAYMENT:
		return {"success": false, "reason": "顾客尚未完成付款"}
	phase = Phase.RESULT
	payment_ready = true
	changed.emit()
	return {"success": true}


func phase_label() -> String:
	match phase:
		Phase.SPREAD:
			return "摊开面糊"
		Phase.FIRST_SIDE:
			return "打蛋、摊蛋并观察第一面火候"
		Phase.SECOND_SIDE:
			return "翻面完成，准备刷酱"
		Phase.SAUCE_AND_FILLINGS:
			return "刷酱并摆放配料"
		Phase.FOLD:
			return "拖动饼皮完成折叠"
		Phase.PACKAGE:
			return "选择包装"
		Phase.READY_TO_SERVE:
			return "点击成品递给顾客"
		Phase.HANDOFF:
			return "顾客正在接餐"
		Phase.PAYMENT:
			return "顾客正在付款"
		Phase.RESULT:
			return "本单已结算"
	return "制作中"
