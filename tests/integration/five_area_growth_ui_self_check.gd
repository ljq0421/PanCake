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
	progression.set("coins", 5)
	progression.set("reputation", 0)
	progression.set("area_mastery", {&"area.pancake": 0})
	progression.set("area_mastery_details", {&"area.pancake": {"qualified": 0, "a_grade": 0}})
	progression.set("tutorial_completed_area_ids", {})
	var guarantee_station = WORKSTATION_SCENE.instantiate()
	root.add_child(guarantee_station)
	await process_frame
	await process_frame
	guarantee_station.call("end_business_day")
	var guarantee_tickets := _growth_tickets(guarantee_station)
	_check(_ticket_ids(guarantee_tickets) == [&"growth.tool.pancake.wide_spreader", &"growth.add_on.pancake.red_chili", &"growth.area.packaged_drink"], "coin guarantee keeps the first fixed-route three-card window")
	_check(guarantee_tickets[0].disabled and "[安装位 · 金币保底]" in guarantee_tickets[0].text and "金币 5/12" in guarantee_tickets[0].text, "all-locked day end visibly marks the frontier and shows the real coin gap")
	_check("金币保底项" in guarantee_tickets[0].tooltip_text and "只差金币" in guarantee_tickets[0].tooltip_text and "营业日" not in guarantee_tickets[0].tooltip_text, "guarantee tooltip replaces non-coin gates instead of mixing them with the coin requirement")
	_check(not "金币保底" in guarantee_tickets[1].text and not "金币保底" in guarantee_tickets[2].text, "only one of the three day-end cards is the coin guarantee")
	progression.set("coins", 20)
	guarantee_station.call("_refresh_growth_section")
	_check(not guarantee_tickets[0].disabled and "金币 20/12 · 可预订，明日生效" in guarantee_tickets[0].text and "支付 12 金币" in guarantee_tickets[0].tooltip_text, "sufficient balance makes the guaranteed card clickable with matching price copy")
	guarantee_tickets[0].emit_signal("pressed")
	await process_frame
	var guaranteed_pending: Dictionary = session.call("five_area_progression_snapshot")
	_check(str(guaranteed_pending.get("pending_install_purchase", "")) == "growth.tool.pancake.wide_spreader" and int(guaranteed_pending.get("coins", 0)) == 8, "clicking the guaranteed card charges its catalog price and reserves the install slot")
	_check(guarantee_tickets[0].disabled and "已预订：宽幅摊饼器" in guarantee_tickets[0].text and "金币保底" not in guarantee_tickets[0].text, "purchased guarantee refreshes into the normal pending state")
	guarantee_station.queue_free()
	await process_frame

	session.call("begin_new_game")
	progression = session.call("progression_service")
	progression.set("coins", 100)
	progression.set("reputation", 20)
	progression.set("area_mastery", {&"area.pancake": 0})
	progression.set("area_mastery_details", {&"area.pancake": {"qualified": 0, "a_grade": 0}})
	progression.set("tutorial_completed_area_ids", {&"area.pancake": true})
	var day_one_station = WORKSTATION_SCENE.instantiate()
	root.add_child(day_one_station)
	await process_frame
	await process_frame
	day_one_station.call("end_business_day")
	var day_one_tickets := _growth_tickets(day_one_station)
	_check(day_one_tickets.size() == 3 and day_one_station.get_node_or_null("SafeArea/DailyBillPanel/Margin/VBox/GrowthTickets/GrowthTicket4") == null, "day-end growth UI contains exactly three ticket nodes")
	_check(_ticket_ids(day_one_tickets) == [&"growth.tool.pancake.wide_spreader", &"growth.add_on.pancake.red_chili", &"growth.area.packaged_drink"], "day-one UI follows the first fixed-route batch")
	_check(day_one_tickets[0].disabled and not day_one_tickets[1].disabled and day_one_tickets[2].disabled, "day-one preview independently reflects day, reputation, and mastery gates")
	_check("营业日 1/2" in day_one_tickets[0].text and "可预订，明日生效" in day_one_tickets[1].text and "煎饼合格数 0/6" in day_one_tickets[2].text, "first cards visibly mix business-day, reputation-ready, and qualified-count progress")
	_check(not "金币保底" in day_one_tickets[0].text, "an existing purchasable content card prevents unnecessary coin guarantee activation")
	_check("营业日 1/2" in day_one_tickets[0].tooltip_text and "煎饼合格数" not in day_one_tickets[0].tooltip_text and "金币 100/12" not in day_one_tickets[0].tooltip_text, "wide spreader tooltip lists only its real unmet D2 requirement")
	_check("暂不满足条件" not in day_one_tickets[0].text and "暂不满足条件" not in day_one_tickets[0].tooltip_text, "growth UI no longer uses the ambiguous fallback")
	day_one_station.queue_free()
	await process_frame

	session.call("begin_new_game")
	progression = session.call("progression_service")
	progression.set("coins", 105)
	progression.set("current_day", 3)
	progression.set("reputation", 20)
	progression.set("area_mastery", {&"area.pancake": 6})
	progression.set("area_mastery_details", {&"area.pancake": {"qualified": 6, "a_grade": 1}})
	progression.set("tutorial_completed_area_ids", {&"area.pancake": true})
	var station = WORKSTATION_SCENE.instantiate()
	root.add_child(station)
	await process_frame
	await process_frame
	station.call("end_business_day")
	var tickets := _growth_tickets(station)
	_check(_ticket_ids(tickets) == [&"growth.tool.pancake.wide_spreader", &"growth.add_on.pancake.red_chili", &"growth.area.packaged_drink"], "eligible state keeps the same fixed-route window")
	for ticket in tickets:
		_check(not ticket.disabled and "可预订，明日生效" in ticket.text and ticket.tooltip_text == "可预订，明日生效", "can_purchase card, tooltip, and button state agree")
	_check(station.call("_growth_ticket_status_text", {"reason": &"day_requirement", "current_day": 3, "min_day": 4}) == "营业日 3/4", "day gap uses x/y progress")
	_check(station.call("_growth_ticket_status_text", {"reason": &"insufficient_coins", "current_coins": 5, "price": 12}) == "金币 5/12", "coin gap uses x/y progress")
	_check(station.call("_growth_ticket_status_text", {"reason": &"reputation_requirement", "current_reputation": 10, "min_reputation": 20}) == "声誉 10/20", "reputation gap uses x/y progress")
	_check(station.call("_growth_ticket_status_text", {"reason": &"mastery_requirement", "mastery_area_id": &"area.pancake", "mastery_metric": &"qualified", "current_mastery": 4, "required_mastery": 6}) == "煎饼合格数 4/6", "mastery gap uses localized x/y progress")
	_check(station.call("_growth_ticket_status_text", {"reason": &"all_areas_requirement", "current_area_count": 3, "required_area_count": 5}) == "区域 3/5", "area gap uses x/y progress")
	_check("成长配置异常，无法预订" in str(station.call("_growth_ticket_status_text", {"reason": &"unexpected"})), "unknown growth state becomes a visible configuration error")

	_check(bool(session.call("purchase_growth", &"growth.area.packaged_drink").get("success", false)), "install purchase is accepted")
	_check(bool(session.call("purchase_growth", &"growth.add_on.pancake.red_chili").get("success", false)), "content purchase is accepted in parallel")
	station.call("_refresh_growth_section")
	_check(_ticket_ids(tickets) == [&"growth.tool.pancake.wide_spreader", &"growth.add_on.pancake.red_chili", &"growth.area.packaged_drink"], "pending purchases do not move or replace route cards")
	_check(tickets[0].disabled and "该购买位已预订：成品饮品柜" in tickets[0].text and "该购买位已预订：成品饮品柜" in tickets[0].tooltip_text, "occupied install slot names its actual pending item")
	_check(tickets[1].disabled and "已预订：辣椒酱" in tickets[1].text and "明日生效" in tickets[1].tooltip_text, "pending content card remains visible until activation")
	_check(tickets[2].disabled and "已预订：成品饮品柜" in tickets[2].text and "明日生效" in tickets[2].tooltip_text, "pending install card remains visible until activation")
	var pending: Dictionary = session.call("five_area_progression_snapshot")
	_check(str(pending.get("pending_install_purchase", "")) == "growth.area.packaged_drink" and str(pending.get("pending_content_purchase", "")) == "growth.add_on.pancake.red_chili", "install and content pending slots coexist")
	_check(bool(session.call("begin_next_business_day").get("success", false)), "next business day activates both pending purchases")
	station.call("_refresh_growth_section")
	_check(_ticket_ids(tickets) == [&"growth.tool.pancake.wide_spreader", &"growth.equipment.pancake.intermediate", &"growth.add_on.pancake.ham_sausage"], "activated cards leave the queue and expose the next fixed-route items")
	station.queue_free()
	await process_frame

	var refreshed_station = WORKSTATION_SCENE.instantiate()
	root.add_child(refreshed_station)
	await process_frame
	await process_frame
	var drink_lock := refreshed_station.get_node("SafeArea/FiveAreaStationArtwork/PackagedDrinkLock") as CanvasItem
	var drink_click := refreshed_station.get_node("SafeArea/FiveAreaStationClickLayers/PackagedDrinkLockedClickLayer") as Button
	var chili_button := refreshed_station.get_node("SafeArea/RightRack/ChiliSauceRefillButton") as Button
	_check(not drink_lock.visible and not drink_click.disabled, "activated packaged-drink area is available after scene reload")
	refreshed_station.p1_session.phase = P1Session.Phase.SAUCE_AND_FILLINGS
	refreshed_station.call("_refresh_p1_ui")
	refreshed_station.get_node("SafeArea/PancakeWorkstationInteractionController").call("_refresh_sauce_controls")
	var sweet_button := refreshed_station.get_node("SafeArea/RightRack/SauceRefillButton") as Button
	_check(chili_button.visible and not chili_button.disabled and chili_button.mouse_filter == Control.MOUSE_FILTER_STOP, "activated chili sauce is a usable input control")
	_check(is_equal_approx(chili_button.get_global_rect().end.x, sweet_button.get_global_rect().position.x) and not chili_button.get_global_rect().intersects(sweet_button.get_global_rect()), "activated chili sauce keeps a real adjacent hit region beside sweet sauce")
	refreshed_station.queue_free()
	_finish()


func _growth_tickets(station: Node) -> Array[Button]:
	return [
		station.get_node("SafeArea/DailyBillPanel/Margin/VBox/GrowthTickets/GrowthTicket1") as Button,
		station.get_node("SafeArea/DailyBillPanel/Margin/VBox/GrowthTickets/GrowthTicket2") as Button,
		station.get_node("SafeArea/DailyBillPanel/Margin/VBox/GrowthTickets/GrowthTicket3") as Button,
	]


func _ticket_ids(tickets: Array[Button]) -> Array[StringName]:
	var result: Array[StringName] = []
	for ticket in tickets:
		result.append(StringName(ticket.get_meta(&"growth_item_id", &"")))
	return result


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
