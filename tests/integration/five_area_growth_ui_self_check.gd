extends SceneTree

const WORKSTATION_SCENE = preload("res://scenes/gameplay/initial_unlock_workstation.tscn")
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession exists for growth UI")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	var progression: RefCounted = session.call("progression_service")
	progression.set("coins", 100)
	progression.set("current_day", 3)
	var settlement: Dictionary = session.call("record_order_completed", {"id": "pancake-a", "title": "煎饼教学单"}, {"area_id": &"area.pancake", "score": 90.0}, 5)
	_check(int(Dictionary(settlement.get("mastery", {})).get("mastery_gained", 0)) == 1 and int(progression.get("reputation")) == 4, "order result awards pancake mastery and reputation")
	_check(int(progression.get("coins")) == 100, "order settlement does not double-credit uncollected payment")
	session.call("credit_coins", 5)
	_check(int(progression.get("coins")) == 105, "payment collection credits coins exactly once")
	progression.set("reputation", 20)
	progression.set("area_mastery", {&"area.pancake": 6})
	progression.set("area_mastery_details", {
		&"area.pancake": {"qualified": 6, "a_grade": 1},
	})
	progression.set("tutorial_completed_area_ids", {&"area.pancake": true})
	var station = WORKSTATION_SCENE.instantiate()
	root.add_child(station)
	await process_frame
	await process_frame
	station.call("end_business_day")
	_check(station.get_node("SafeArea/DailyBillPanel").visible, "day-end bill opens the existing growth UI")
	var ticket_1 := station.get_node("SafeArea/DailyBillPanel/Margin/VBox/GrowthTickets/GrowthTicket1") as Button
	var ticket_2 := station.get_node("SafeArea/DailyBillPanel/Margin/VBox/GrowthTickets/GrowthTicket2") as Button
	var ticket_3 := station.get_node("SafeArea/DailyBillPanel/Margin/VBox/GrowthTickets/GrowthTicket3") as Button
	_check("安装位" in ticket_1.text and "内容位" in ticket_3.text, "growth UI exposes separate install and content purchase slots")
	_check(not "growth." in ticket_1.text and not "金币" in ticket_1.text, "growth tickets show localized names without exposing the purchase cost")
	_check(station.global_status_label.text.contains("金币 105") and station.global_status_label.text.contains("营业日 3") and station.global_status_label.text.contains("声誉 20"), "workstation status strip renders the current coins, business day, and reputation")
	_check(station.call("_growth_ticket_status_text", {"reason": &"day_requirement", "min_day": 4}).contains("3/4"), "day-gated growth status shows completed and required business days")
	_check(bool(session.call("purchase_growth", &"growth.area.packaged_drink").get("success", false)), "install purchase accepted from settlement state")
	_check(bool(session.call("purchase_growth", &"growth.add_on.pancake.red_chili").get("success", false)), "content purchase accepted alongside install state")
	station.call("_refresh_growth_section")
	_check("已购买" in ticket_1.text and "成品饮品柜" in ticket_1.text and ticket_1.disabled, "purchased installation slot keeps the purchased item instead of changing to another recommendation")
	_check(ticket_2.visible and ticket_2.disabled and "已选择安装" in ticket_2.text, "the second installation candidate remains visible but explains that the installation slot is already selected")
	_check("已购买" in ticket_3.text and "辣椒酱" in ticket_3.text and ticket_3.disabled, "purchased content slot keeps the purchased item instead of changing to another recommendation")
	station.call("_open_unlock_progress")
	var unlock_panel := station.get_node("SafeArea/UnlockProgressPanel") as PanelContainer
	var unlock_label := station.get_node("SafeArea/UnlockProgressPanel/Margin/VBox/Scroll/UnlockProgressLabel") as Label
	_check(unlock_panel.visible and unlock_label.text.contains("已解锁安装") and unlock_label.text.contains("明日生效") and unlock_label.text.contains("成品饮品柜"), "unlock-progress view separates active unlocks from tomorrow's pending purchases")
	station.call("_close_unlock_progress")
	var pending: Dictionary = session.call("five_area_progression_snapshot")
	_check(str(pending.get("pending_install_purchase", "")) == "growth.area.packaged_drink" and str(pending.get("pending_content_purchase", "")) == "growth.add_on.pancake.red_chili", "two pending purchases are presented as independent state")
	_check(bool(session.call("begin_next_business_day").get("success", false)), "next day activates both purchases")
	station.queue_free()
	await process_frame
	var refreshed_station = WORKSTATION_SCENE.instantiate()
	root.add_child(refreshed_station)
	await process_frame
	await process_frame
	var drink_lock := refreshed_station.get_node("SafeArea/FiveAreaStationArtwork/PackagedDrinkLock") as CanvasItem
	var drink_placeholder := refreshed_station.get_node("SafeArea/FiveAreaStationArtwork/PackagedDrinkPlaceholder") as CanvasItem
	var drink_click := refreshed_station.get_node("SafeArea/FiveAreaStationClickLayers/PackagedDrinkLockedClickLayer") as Button
	_check(not drink_lock.visible and drink_placeholder.visible and drink_click.disabled, "scene reload replaces the activated packaged-drink lock with the explicit UI art placeholder")
	refreshed_station.call("_open_unlock_progress")
	var activated_unlock_label := refreshed_station.get_node("SafeArea/UnlockProgressPanel/Margin/VBox/Scroll/UnlockProgressLabel") as Label
	_check(
		activated_unlock_label.text.contains("成品饮品柜")
		and activated_unlock_label.text.contains("辣椒酱")
		and activated_unlock_label.text.contains("安装：无")
		and activated_unlock_label.text.contains("内容：无"),
		"unlock-progress view lists activated install/content purchases and clears the pending section"
	)
	refreshed_station.queue_free()
	_finish()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("FIVE_AREA_GROWTH_UI_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("FIVE_AREA_GROWTH_UI_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
