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
	progression.set("reputation", 20)
	progression.set("area_mastery", {&"area.pancake": 0})
	progression.set("area_mastery_details", {
		&"area.pancake": {"qualified": 0, "a_grade": 0},
	})
	progression.set("tutorial_completed_area_ids", {&"area.pancake": true})
	var day_one_station = WORKSTATION_SCENE.instantiate()
	root.add_child(day_one_station)
	await process_frame
	await process_frame
	day_one_station.call("end_business_day")
	var day_one_ticket_1 := day_one_station.get_node("SafeArea/DailyBillPanel/Margin/VBox/GrowthTickets/GrowthTicket1") as Button
	var day_one_ticket_2 := day_one_station.get_node("SafeArea/DailyBillPanel/Margin/VBox/GrowthTickets/GrowthTicket2") as Button
	var day_one_ticket_3 := day_one_station.get_node("SafeArea/DailyBillPanel/Margin/VBox/GrowthTickets/GrowthTicket3") as Button
	_check(day_one_station.get_node_or_null("SafeArea/DailyBillPanel/Margin/VBox/GrowthTickets/GrowthTicket4") == null, "day-end growth UI contains only three ticket nodes")
	_check("宽幅摊饼器" in day_one_ticket_1.text and "辣椒酱" in day_one_ticket_2.text and "成品饮品柜" in day_one_ticket_3.text, "day-one UI previews the two D2 pancake goals and the D3 drink-area goal")
	_check(day_one_ticket_1.disabled and day_one_ticket_2.disabled and day_one_ticket_3.disabled, "day-one preview does not allow early D2 or D3 purchases")
	_check("1/2" in day_one_ticket_1.text and "1/2" in day_one_ticket_2.text and "1/3" in day_one_ticket_3.text, "day-one cards show their real purchase-day gaps instead of a remote-area lock")
	_check("熟练度" in day_one_ticket_1.tooltip_text or "熟练度" in day_one_ticket_2.tooltip_text, "day-one tooltip keeps the full mastery requirement list")
	day_one_station.queue_free()
	await process_frame

	session.call("begin_new_game")
	progression = session.call("progression_service")
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
	_check("安装位" in ticket_1.text and "内容位" in ticket_2.text and "安装位" in ticket_3.text, "three-card growth UI exposes both independent purchase slots")
	_check(is_equal_approx(ticket_1.size.x, ticket_2.size.x) and is_equal_approx(ticket_2.size.x, ticket_3.size.x), "the three total growth choices have equal widths")
	_check(not "growth." in ticket_1.text and not "金币" in ticket_1.text, "growth tickets show localized names without exposing the purchase cost")
	_check(station.global_status_label.text.contains("金币 105") and station.global_status_label.text.contains("营业日 3") and station.global_status_label.text.contains("声誉 20"), "workstation status strip renders the current coins, business day, and reputation")
	_check(station.call("_growth_ticket_status_text", {"reason": &"day_requirement", "current_day": 3, "min_day": 4}).contains("3/4"), "day-gated growth status shows completed and required business days")
	var tutorial_help := str(station.call("_growth_ticket_status_text", {"reason": &"tutorial_requirement", "requires_tutorial_area_id": &"area.pancake"}))
	_check(tutorial_help.contains("第 1 位顾客") and not tutorial_help.contains("70"), "tutorial-gated growth explains the first-customer tutorial without a score gate")
	_check(bool(session.call("purchase_growth", &"growth.area.packaged_drink").get("success", false)), "install purchase accepted from settlement state")
	_check(bool(session.call("purchase_growth", &"growth.add_on.pancake.red_chili").get("success", false)), "content purchase accepted alongside install state")
	station.call("_refresh_growth_section")
	_check("已购买" in ticket_1.text and "成品饮品柜" in ticket_1.text and ticket_1.disabled, "purchased installation slot keeps the purchased item instead of changing to another recommendation")
	_check("已购买" in ticket_2.text and "辣椒酱" in ticket_2.text and ticket_2.disabled, "purchased content slot keeps the purchased item in the three-card list")
	_check(ticket_3.visible and ticket_3.disabled and "该购买位已有预订" in ticket_3.text, "the remaining installation goal stays visible with the compact occupied-slot status")
	_check("已选择安装" in ticket_3.tooltip_text, "the occupied installation candidate keeps the full selected-item explanation in its tooltip")
	station.call("_open_unlock_progress")
	var unlock_panel := station.get_node("SafeArea/UnlockProgressPanel") as PanelContainer
	var unlock_label := station.get_node("SafeArea/UnlockProgressPanel/Margin/VBox/Scroll/UnlockProgressLabel") as Label
	_check(unlock_panel.visible and unlock_label.text.contains("已解锁安装") and unlock_label.text.contains("明日生效") and unlock_label.text.contains("成品饮品柜"), "unlock-progress view separates active unlocks from tomorrow's pending purchases")
	station.call("_close_unlock_progress")
	var pending: Dictionary = session.call("five_area_progression_snapshot")
	_check(str(pending.get("pending_install_purchase", "")) == "growth.area.packaged_drink" and str(pending.get("pending_content_purchase", "")) == "growth.add_on.pancake.red_chili", "two pending purchases are presented as independent state")
	_check(bool(session.call("begin_next_business_day").get("success", false)), "next day activates both purchases")
	progression.set("area_mastery", {&"area.pancake": 6, &"area.packaged_drink": 3})
	progression.set("area_mastery_details", {
		&"area.pancake": {"qualified": 6, "a_grade": 1},
		&"area.packaged_drink": {"correct_temperature": 3, "correct_streak_current": 2, "correct_streak_best": 3},
	})
	station.queue_free()
	await process_frame
	var refreshed_station = WORKSTATION_SCENE.instantiate()
	root.add_child(refreshed_station)
	await process_frame
	await process_frame
	var drink_lock := refreshed_station.get_node("SafeArea/FiveAreaStationArtwork/PackagedDrinkLock") as CanvasItem
	var drink_placeholder := refreshed_station.get_node("SafeArea/FiveAreaStationArtwork/PackagedDrinkPlaceholder") as CanvasItem
	var drink_click := refreshed_station.get_node("SafeArea/FiveAreaStationClickLayers/PackagedDrinkLockedClickLayer") as Button
	var chili_button := refreshed_station.get_node("SafeArea/RightRack/ChiliSauceRefillButton") as Button
	_check(not drink_lock.visible and drink_placeholder.visible and not drink_click.disabled, "scene reload replaces the activated packaged-drink lock and keeps the drink area click-targetable")
	drink_click.emit_signal("pressed")
	await process_frame
	var f3_overlay := refreshed_station.get_node("F3StationOverlay") as Control
	var drink_station := refreshed_station.get_node("F3StationOverlay/F3StationsWorkbench/SafeArea/Content/Stations/PackagedDrinkStation") as Control
	var milk_button := drink_station.get_node("Margin/Content/ProductShelf/MilkButton") as Button
	var mastery_label := drink_station.get_node("Margin/Content/MasteryLabel") as Label
	_check(f3_overlay.visible and milk_button.text.contains("纯牛奶") and not milk_button.text.contains("未解锁"), "clicking the activated area opens the sellable drink shelf with the starter product")
	_check(mastery_label.text.contains("正确温度 3") and mastery_label.text.contains("最高连对 3"), "the drink shelf presents its temperature and streak mastery")
	refreshed_station.call("_close_f3_station")
	_check(not f3_overlay.visible and refreshed_station.global_status_label.text.contains("熟练度（饮品正确温度）3"), "the main status strip also exposes drink mastery after unlock")
	_check(chili_button.visible and chili_button.mouse_filter == Control.MOUSE_FILTER_STOP, "activated chili sauce appears as a usable sauce control")
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
