extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/initial_unlock_workstation.tscn")
const CATALOG := preload("res://scripts/data/workstation_expansion_catalog.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession autoload is available")
	if session == null:
		_finish()
		return
	session.begin_new_game()
	var progression: RefCounted = session.progression_service()
	progression.set("coins", 50)
	progression.set("reputation", 10)
	progression.set("current_day", 2)
	progression.call("set_metric", &"lifetime_orders", 4)
	session.save_workstation_progression(progression.call("snapshot"))

	var recommendations: Array = session.growth_recommendations(3)
	_check(recommendations.size() == 3, "daily growth service returns at most three deterministic recommendations")
	_check(StringName(recommendations[0].get("item_id", "")) == CATALOG.TOOL_SPREADER_WIDE, "an immediately eligible upgrade is recommended first")
	_check(bool(recommendations[0].get("can_purchase", false)), "eligible and affordable recommendation can be purchased")
	_check(not Array(recommendations[1].get("missing_requirements", [])).is_empty(), "locked recommendation exposes exact missing requirements")

	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	await process_frame
	await process_frame
	workstation.call("end_business_day")
	var panel := workstation.get_node("SafeArea/DailyBillPanel") as Control
	var first_ticket := workstation.get_node("SafeArea/DailyBillPanel/Margin/VBox/GrowthTickets/GrowthTicket1") as Button
	var next_day_button := workstation.get_node("SafeArea/DailyBillPanel/Margin/VBox/GrowthActions/BeginNextDayButton") as Button
	_check(panel.visible, "end business opens the combined bill and growth ledger")
	_check("加宽刮板" in first_ticket.text and not first_ticket.disabled, "first growth ticket renders the recommended purchase and remains actionable")
	_check("购买后第3天生效" in (workstation.get_node("SafeArea/DailyBillPanel/Margin/VBox/GrowthBalanceLabel") as Label).text, "growth ledger states the activation day before purchase")

	first_ticket.emit_signal("pressed")
	await process_frame
	var after_purchase: Dictionary = session.workstation_progression_snapshot()
	_check(StringName(after_purchase.get("pending_purchase", "")) == CATALOG.TOOL_SPREADER_WIDE, "ticket purchase persists one pending growth choice")
	_check("明日装上" in first_ticket.text, "purchased ticket receives the next-day stamp")
	_check("确认选择" in next_day_button.text, "next-day action distinguishes a confirmed purchase from skipping")
	for button_name in ["GrowthTicket1", "GrowthTicket2", "GrowthTicket3"]:
		var button := workstation.get_node("SafeArea/DailyBillPanel/Margin/VBox/GrowthTickets/" + button_name) as Button
		_check(button.disabled, "%s is disabled after today's one purchase" % button_name)

	var next_day: Dictionary = session.begin_next_business_day()
	_check(bool(next_day.get("success", false)) and int(next_day.get("current_day", 0)) == 3, "next-day transition advances the business day")
	_check(session.progression_service().call("owns", CATALOG.TOOL_SPREADER_WIDE), "pending growth activates exactly at the next business day")
	workstation.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	_failures.append(description)
	push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("DAILY_GROWTH_SELF_CHECK_PASS")
		quit(0)
		return
	print("DAILY_GROWTH_SELF_CHECK_FAIL: %s" % ", ".join(_failures))
	quit(1)
