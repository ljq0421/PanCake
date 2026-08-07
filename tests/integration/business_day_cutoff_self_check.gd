extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/initial_unlock_workstation.tscn")
const MAIN_SCENE := preload("res://scenes/main/main.tscn")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_session := root.get_node_or_null("GameSession")
	_check(game_session != null, "GameSession autoload is available")
	if game_session == null:
		_finish()
		return
	game_session.call("begin_new_game")
	var workstation: Workstation = WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	await process_frame
	_check(workstation.business_day_timer_label == workstation.get_node("SafeArea/BusinessDayTimerLabel") and workstation.business_day_timer_label.visible, "initial-unlock gameplay scene owns the visible business countdown")
	workstation.business_day_timer.set("remaining_seconds", 0.05)
	workstation._process(0.1)
	var bill: Dictionary = game_session.call("today_bill")
	var cutoff: Dictionary = Dictionary(bill.get("cutoff", {}))
	_check(workstation.daily_bill_panel.visible and workstation.business_day_closed_shield.visible, "hard cutoff blocks workstation input and opens the daily bill")
	_check(StringName(cutoff.get("reason", &"")) == &"timer_expired" and int(cutoff.get("unserved_customer_count", 0)) >= 1, "hard cutoff records unserved queued customers in the daily bill")
	_check(Dictionary(game_session.call("active_formal_order")).is_empty(), "hard cutoff abandons the active formal order instead of allowing overtime settlement")
	_check(is_zero_approx(float(game_session.call("business_day_remaining_seconds"))), "hard cutoff persists zero remaining business time")
	workstation.queue_free()
	game_session.call("begin_new_game")
	var main: Control = MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	var quick_end_button := main.get_node("DebugOverlay/Root/DebugPanel/Labels/QuickEndBusinessDayButton") as Button
	quick_end_button.emit_signal("pressed")
	await process_frame
	var early_end_bill: Dictionary = game_session.call("today_bill")
	var early_end_cutoff: Dictionary = Dictionary(early_end_bill.get("cutoff", {}))
	_check(StringName(early_end_cutoff.get("reason", &"")) == &"test_early_end", "debug quick-end button records a distinct test early-end cutoff")
	_check(main.workstation.daily_bill_panel.visible and main.workstation.business_day_closed_shield.visible, "debug quick-end button opens the normal daily bill and locks the workstation")
	_check(Dictionary(game_session.call("active_formal_order")).is_empty(), "debug quick-end button abandons the active formal order")
	_check(is_zero_approx(float(game_session.call("business_day_remaining_seconds"))), "debug quick-end button persists zero remaining business time")
	main.queue_free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("BUSINESS_DAY_CUTOFF_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("BUSINESS_DAY_CUTOFF_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
