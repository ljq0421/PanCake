extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/four_area_workstation.tscn")
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
	var tutorial_workstation: Workstation = WORKSTATION_SCENE.instantiate()
	root.add_child(tutorial_workstation)
	await process_frame
	tutorial_workstation._process(5.0)
	var tutorial_order := Dictionary(game_session.call("active_formal_order"))
	_check(bool(tutorial_order.get("tutorial_no_countdown", false)), "new game opens with a restock window before the unlimited tutorial arrives")
	_check(is_equal_approx(float(tutorial_workstation.business_day_timer.get("remaining_seconds")), 60.0), "first business day starts with a one-minute countdown held for the unlimited tutorial")
	tutorial_workstation.business_day_timer.set("remaining_seconds", 44.25)
	game_session.call("set_business_day_remaining_seconds", 44.25)
	tutorial_workstation._process(1.25)
	_check(is_equal_approx(float(tutorial_workstation.business_day_timer.get("remaining_seconds")), 44.25), "tutorial order does not consume in-memory business time")
	_check(is_equal_approx(float(game_session.call("business_day_remaining_seconds")), 44.25), "tutorial order does not persist a lower business time")
	_check(tutorial_workstation.business_day_timer_label.text == "教学中", "tutorial order replaces the business countdown with the exact teaching label")
	var skipped := Dictionary(game_session.call("skip_active_area_tutorial"))
	_check(bool(skipped.get("success", false)), "tutorial can be skipped before testing countdown resume")
	tutorial_workstation._process(1.0)
	_check(float(tutorial_workstation.business_day_timer.get("remaining_seconds")) < 44.25 and tutorial_workstation.business_day_timer_label.text.begins_with("营业倒计时"), "business countdown resumes from the preserved time after tutorial exit")
	tutorial_workstation.queue_free()
	await process_frame
	game_session.call("begin_new_game")
	_prepare_five_normal_orders(game_session)
	var workstation: Workstation = WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	await process_frame
	_check(workstation.business_day_timer_label == workstation.get_node("SafeArea/BusinessDayTimerLabel") and workstation.business_day_timer_label.visible, "initial-unlock gameplay scene owns the visible business countdown")
	workstation.business_day_timer.set("remaining_seconds", 0.05)
	workstation._process(0.1)
	var bill: Dictionary = game_session.call("today_bill")
	var cutoff: Dictionary = Dictionary(bill.get("cutoff", {}))
	_check(workstation.daily_bill_panel.visible and workstation.business_day_closed_shield.visible, "hard cutoff blocks workstation input and opens the daily bill")
	workstation._open_upgrade_workshop()
	await process_frame
	_check(workstation._upgrade_workshop != null and workstation._upgrade_workshop.visible and not workstation.daily_bill_panel.visible and not workstation.business_day_closed_shield.visible, "upgrade workshop replaces the daily-bill shield instead of dimming the formal workstation preview")
	workstation._close_upgrade_workshop()
	_check(workstation.daily_bill_panel.visible and workstation.business_day_closed_shield.visible, "returning from the upgrade workshop restores the daily-bill shield")
	_check(StringName(cutoff.get("reason", &"")) == &"timer_expired" and int(cutoff.get("unserved_customer_count", 0)) == 5, "hard cutoff records all five on-floor customers in the daily bill")
	_check(Array(game_session.call("active_formal_orders")).is_empty() and Array(game_session.call("waiting_formal_orders")).is_empty(), "hard cutoff abandons every active and waiting formal order instead of allowing overtime settlement")
	_check(is_zero_approx(float(game_session.call("business_day_remaining_seconds"))), "hard cutoff persists zero remaining business time")
	game_session.call("end_business_day", {"reason": &"manual_early_end"})
	var repeated_cutoff: Dictionary = Dictionary(Dictionary(game_session.call("today_bill")).get("cutoff", {}))
	_check(StringName(repeated_cutoff.get("reason", &"")) == &"timer_expired" and int(repeated_cutoff.get("unserved_customer_count", 0)) == 5, "repeated day-end calls preserve the original cutoff reason and unserved count")
	workstation.queue_free()
	game_session.call("begin_new_game")
	_prepare_five_normal_orders(game_session)
	var main: Control = MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	var quick_end_button := main.get_node("DebugOverlay").get_node("%QuickEndBusinessDayButton") as Button
	quick_end_button.emit_signal("pressed")
	await process_frame
	var early_end_bill: Dictionary = game_session.call("today_bill")
	var early_end_cutoff: Dictionary = Dictionary(early_end_bill.get("cutoff", {}))
	_check(StringName(early_end_cutoff.get("reason", &"")) == &"test_early_end", "debug quick-end button records a distinct test early-end cutoff")
	_check(main.workstation.daily_bill_panel.visible and main.workstation.business_day_closed_shield.visible, "debug quick-end button opens the normal daily bill and locks the workstation")
	_check(int(early_end_cutoff.get("unserved_customer_count", 0)) == 5, "debug quick-end records all on-floor customers")
	_check(Array(game_session.call("active_formal_orders")).is_empty() and Array(game_session.call("waiting_formal_orders")).is_empty(), "debug quick-end button abandons every active and waiting formal order")
	_check(is_zero_approx(float(game_session.call("business_day_remaining_seconds"))), "debug quick-end button persists zero remaining business time")
	main.queue_free()
	await process_frame

	game_session.call("begin_new_game")
	_prepare_five_normal_orders(game_session)
	var manual_main: Control = MAIN_SCENE.instantiate()
	root.add_child(manual_main)
	await process_frame
	await process_frame
	_check(Array(game_session.call("active_formal_orders")).size() == 5 and Array(game_session.call("waiting_formal_orders")).is_empty(), "pause-menu scenario starts with five on-floor customers and no waiting queue")
	manual_main.call("_set_paused", true)
	var manual_end_button := manual_main.get_node("%EndBusinessButton") as Button
	manual_end_button.emit_signal("pressed")
	await process_frame
	var manual_bill: Dictionary = game_session.call("today_bill")
	var manual_cutoff: Dictionary = Dictionary(manual_bill.get("cutoff", {}))
	_check(not paused and not manual_main.get_node("%PausePanel").visible, "pause-menu early end exits pause state before closing the workstation")
	_check(StringName(manual_cutoff.get("reason", &"")) == &"manual_early_end" and int(manual_cutoff.get("unserved_customer_count", 0)) == 5, "pause-menu early end records five unserved customers with the stable manual reason")
	_check(Array(game_session.call("active_formal_orders")).is_empty() and Array(game_session.call("waiting_formal_orders")).is_empty(), "pause-menu early end clears every active and waiting formal order")
	_check(manual_main.workstation.daily_bill_panel.visible and manual_main.workstation.business_day_closed_shield.visible, "pause-menu early end opens the daily bill and locks the workstation")
	_check("提前打烊，未服务 5 位" in manual_main.workstation.daily_bill_stats_label.text, "manual daily bill visibly reports all unserved customers")
	manual_main.queue_free()
	_finish()


func _prepare_five_normal_orders(game_session: Node) -> void:
	var progression: RefCounted = game_session.call("progression_service")
	progression.call("complete_tutorial", &"area", &"area.pancake")
	# This cutoff fixture intentionally exercises the fully expanded storefront;
	# first-day pressure is covered by customer_arrival_scheduler_self_check.
	progression.set("current_day", 4)
	progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.youtiao": true, &"area.fresh_soy_milk": true})
	progression.set("tutorial_completed_area_ids", {&"area.pancake": true, &"area.youtiao": true, &"area.fresh_soy_milk": true})
	game_session.call("advance_customer_arrivals", 5.0)
	for _arrival in 4:
		var delay := float(Dictionary(game_session.call("customer_arrival_snapshot")).get("next_arrival_remaining_seconds", -1.0))
		game_session.call("advance_customer_arrivals", delay + 0.01)


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
