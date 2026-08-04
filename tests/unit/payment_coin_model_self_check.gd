extends SceneTree

const PAYMENT_COIN_MODEL_SCRIPT := preload("res://scripts/gameplay/payment_coin_model.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	var model: RefCounted = PAYMENT_COIN_MODEL_SCRIPT.new()
	_check(PAYMENT_COIN_MODEL_SCRIPT.decompose(3) == [2, 1], "three coins decompose into visible 2 and 1 denominations")
	_check(PAYMENT_COIN_MODEL_SCRIPT.decompose(12) == [10, 2], "twelve coins decompose into visible 10 and 2 denominations")
	_check(PAYMENT_COIN_MODEL_SCRIPT.decompose(22) == [20, 2], "twenty-two coins decompose into visible 20 and 2 denominations")
	for denomination in PAYMENT_COIN_MODEL_SCRIPT.DENOMINATIONS:
		_check(PAYMENT_COIN_MODEL_SCRIPT.decompose(denomination) == [denomination], "denomination %d has an exact one-coin representation" % denomination)
	model.add_payment(3)
	model.add_payment(12)
	_check(model.pending_total == 15 and model.pending_denominations == [2, 1, 10, 2], "uncollected payments accumulate independently across orders")
	_check(model.collect_all() == 15 and not model.has_pending(), "collect-all returns the full pending amount and clears the slot")
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("PAYMENT_COIN_MODEL_SELF_CHECK_PASS")
		quit(0)
		return
	push_error("Payment coin model self-check failed: %s" % ", ".join(_failures))
	quit(1)
