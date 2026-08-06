extends SceneTree

const BUSINESS_DAY_TIMER := preload("res://scripts/services/business_day_timer.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var timer: RefCounted = BUSINESS_DAY_TIMER.new(120.0)
	var before_warning: Dictionary = timer.call("advance", 109.0)
	_check(int(before_warning.get("remaining_whole_seconds", -1)) == 11 and not bool(before_warning.get("warning_active", true)), "two-minute day has no warning before the final ten seconds")
	var warning: Dictionary = timer.call("advance", 1.0)
	_check(bool(warning.get("warning_started_now", false)) and int(warning.get("remaining_whole_seconds", -1)) == 10, "warning starts exactly at ten seconds")
	var expiry: Dictionary = timer.call("advance", 10.0)
	_check(bool(expiry.get("expired_now", false)) and bool(expiry.get("expired", false)) and int(expiry.get("remaining_whole_seconds", -1)) == 0, "timer reaches a hard zero without overtime")
	_check(not bool(timer.call("advance", 1.0).get("expired_now", true)), "expiry is emitted only once")
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("BUSINESS_DAY_TIMER_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("BUSINESS_DAY_TIMER_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
