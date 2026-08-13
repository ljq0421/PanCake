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
	var locked_station = WORKSTATION_SCENE.instantiate()
	root.add_child(locked_station)
	await process_frame
	await process_frame
	locked_station.call("end_business_day")
	var locked_tickets := _growth_tickets(locked_station)
	var locked_ids_before := _ticket_ids(locked_tickets)
	_check(locked_ids_before == [&"growth.tool.pancake.wide_spreader", &"growth.add_on.pancake.red_chili", &"growth.area.packaged_drink"], "all-locked day end keeps the first fixed-route three-card window")
	_check(locked_tickets[0].disabled and "[安装位]" in locked_tickets[0].text and "营业日 1/2" in locked_tickets[0].text, "all-locked day end shows the frontier's real primary requirement")
	_check("营业日 1/2" in locked_tickets[0].tooltip_text and "金币 5/12" in locked_tickets[0].tooltip_text, "all-locked frontier tooltip preserves every real unmet requirement")
	progression.set("coins", 20)
	locked_station.call("_refresh_growth_section")
	_check(locked_tickets[0].disabled and "营业日 1/2" in locked_tickets[0].text and "金币 20/12" not in locked_tickets[0].tooltip_text, "sufficient balance does not bypass the remaining day requirement")
	locked_tickets[0].emit_signal("pressed")
	await process_frame
	var locked_snapshot: Dictionary = session.call("five_area_progression_snapshot")
	_check(str(locked_snapshot.get("pending_install_purchase", "")).is_empty() and int(locked_snapshot.get("coins", 0)) == 20, "pressing a locked card cannot charge coins or reserve its slot")
	_check(_ticket_ids(locked_tickets) == locked_ids_before and locked_tickets[0].disabled and "营业日 1/2" in locked_tickets[0].text, "rejected purchase keeps the fixed cards and real condition unchanged")
	locked_station.queue_free()
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
	_check("营业日 1/2" in day_one_tickets[0].tooltip_text and "煎饼合格数" not in day_one_tickets[0].tooltip_text and "金币 100/12" not in day_one_tickets[0].tooltip_text, "wide spreader tooltip lists only its real unmet D2 requirement")
	_check("暂不满足条件" not in day_one_tickets[0].text and "暂不满足条件" not in day_one_tickets[0].tooltip_text, "growth UI no longer uses the ambiguous fallback")
	day_one_station.queue_free()
	await process_frame

	session.call("begin_new_game")
	progression = session.call("progression_service")
	progression.set("coins", 844)
	progression.set("reputation", 1004)
	progression.set("current_day", 12)
	progression.set("unlocked_area_ids", {
		&"area.pancake": true,
		&"area.packaged_drink": true,
		&"area.youtiao": true,
	})
	progression.set("owned_growth_ids", {
		&"growth.tool.pancake.wide_spreader": true,
		&"growth.add_on.pancake.red_chili": true,
		&"growth.area.packaged_drink": true,
		&"growth.equipment.packaged_drink.basic": true,
		&"growth.equipment.pancake.intermediate": true,
		&"growth.add_on.pancake.ham_sausage": true,
		&"growth.product.packaged_drink.soy_milk": true,
		&"growth.equipment.packaged_drink.intermediate": true,
		&"growth.add_on.pancake.meat_floss": true,
		&"growth.assist.youtiao.temperature_indicator": true,
	})
	progression.set("tutorial_completed_area_ids", {&"area.pancake": true, &"area.packaged_drink": true})
	progression.set("tutorial_completed_device_ids", {})
	progression.set("tutorial_queue_area_ids", [])
	progression.set("tutorial_active_kind", &"device")
	progression.set("tutorial_active_id", &"device.packaged_drink_heater")
	var oil_cake_station = WORKSTATION_SCENE.instantiate()
	root.add_child(oil_cake_station)
	await process_frame
	await process_frame
	oil_cake_station.call("end_business_day")
	var oil_cake_tickets := _growth_tickets(oil_cake_station)
	_check(_ticket_ids(oil_cake_tickets) == [&"growth.area.youtiao", &"growth.recipe.youtiao.oil_cake", &"growth.capacity.stock.intermediate"], "attachment state renders the fryer, oil-cake, and stock-capacity cards in fixed order")
	_check(oil_cake_tickets[0].disabled and "需完成饮品加热教学" in oil_cake_tickets[0].text and not oil_cake_tickets[1].disabled and not oil_cake_tickets[2].disabled, "attachment state shows the real independent conditions before reserving oil cake")
	var fryer_text_before := oil_cake_tickets[0].text
	var fryer_tooltip_before := oil_cake_tickets[0].tooltip_text
	oil_cake_tickets[1].emit_signal("pressed")
	await process_frame
	var oil_cake_pending: Dictionary = session.call("five_area_progression_snapshot")
	_check(int(oil_cake_pending.get("coins", 0)) == 826 and str(oil_cake_pending.get("pending_content_purchase", "")) == "growth.recipe.youtiao.oil_cake", "oil-cake UI reservation charges 18 coins and occupies only the content slot")
	_check(oil_cake_tickets[0].disabled and oil_cake_tickets[0].text == fryer_text_before and oil_cake_tickets[0].tooltip_text == fryer_tooltip_before, "oil-cake reservation leaves the fryer's tutorial condition unchanged")
	_check(oil_cake_tickets[1].disabled and "已预订：油饼" in oil_cake_tickets[1].text and "明日生效" in oil_cake_tickets[1].tooltip_text, "selected oil cake refreshes into the pending state")
	_check(oil_cake_tickets[2].disabled and "该购买位已预订：油饼" in oil_cake_tickets[2].text and "该购买位已预订：油饼" in oil_cake_tickets[2].tooltip_text, "other content growth reflects the occupied content slot")
	oil_cake_station.queue_free()
	await process_frame

	session.call("begin_new_game")
	progression = session.call("progression_service")
	progression.set("coins", 105)
	progression.set("current_day", 3)
	progression.set("reputation", 20)
	progression.set("area_mastery", {&"area.pancake": 6})
	progression.set("area_mastery_details", {&"area.pancake": {"qualified": 6, "a_grade": 1}})
	_check(bool(Dictionary(progression.call("complete_tutorial", &"area", &"area.pancake")).get("success", false)), "eligible fixture completes the opening pancake tutorial through the progression API")
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
	_check(station.call("_growth_ticket_status_text", {"reason": &"tutorial_requirement", "required_tutorial_device_id": &"device.packaged_drink_heater"}) == "先完成饮品加热教学：安装基础加热器后的第 1 位顾客会点一份加热纯牛奶，完成加热与交付即可。", "device tutorial gap explains the concrete hot-drink teaching order")
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
	_check(Array(session.call("active_formal_orders")).is_empty() and Array(session.call("waiting_formal_orders")).is_empty(), "next-day activation begins with no cross-day customer orders")
	var stale_order_ids: Array[StringName] = []
	for stale_index in 4:
		var stale_opened: Dictionary = session.call("open_formal_order", [{
			"area_id": &"area.pancake",
			"product_id": &"product.pancake.custom",
			"quantity": 1,
			"temperature_mode": &"room_temperature",
		}], {"source": &"legacy_cross_day_order", "legacy_index": stale_index, "generated_sequence": stale_index + 1})
		stale_order_ids.append(StringName(Dictionary(stale_opened.get("order", {})).get("order_id", &"")))
	_check(Array(session.call("active_formal_orders")).size() == 3 and Array(session.call("waiting_formal_orders")).size() == 1, "affected-save fixture contains three old active customers and one old waiting candidate")
	station.call("_refresh_growth_section")
	_check(_ticket_ids(tickets) == [&"growth.tool.pancake.wide_spreader", &"growth.equipment.packaged_drink.basic", &"growth.equipment.pancake.intermediate"], "activated cards leave the queue and expose the new base-heater route step")
	station.queue_free()
	await process_frame

	var refreshed_station = WORKSTATION_SCENE.instantiate()
	root.add_child(refreshed_station)
	await process_frame
	await process_frame
	var tutorial_orders: Array = Array(session.call("active_formal_orders"))
	var waiting_after_tutorial: Array = Array(session.call("waiting_formal_orders"))
	var drink_tutorial: Dictionary = Dictionary(tutorial_orders[0]) if not tutorial_orders.is_empty() else {}
	var drink_tutorial_items: Array = Array(drink_tutorial.get("items", []))
	var drink_tutorial_item: Dictionary = Dictionary(drink_tutorial_items[0]) if not drink_tutorial_items.is_empty() else {}
	_check(tutorial_orders.size() == 1 and waiting_after_tutorial.size() == 3, "repaired drink teaching order exclusively occupies the storefront with three normal candidates waiting")
	_check(StringName(drink_tutorial.get("tutorial_kind", &"")) == &"area" and StringName(drink_tutorial.get("tutorial_id", &"")) == &"area.packaged_drink", "first refreshed order is the packaged-drink area tutorial")
	_check(drink_tutorial_items.size() == 1 and StringName(drink_tutorial_item.get("product_id", &"")) == &"product.packaged_drink.milk" and StringName(drink_tutorial_item.get("temperature_mode", &"")) == &"room_temperature", "packaged-drink tutorial requests exactly one room-temperature milk")
	_check(bool(drink_tutorial.get("tutorial_no_countdown", false)), "packaged-drink tutorial remains exempt from the customer countdown")
	for stale_order_id in stale_order_ids:
		var stale_order: Dictionary = session.call("formal_order", stale_order_id)
		_check(StringName(stale_order.get("state", &"")) == &"abandoned" and StringName(stale_order.get("abandon_reason", &"")) == &"tutorial_day_priority", "affected-save repair abandons stale order %s before generating teaching" % stale_order_id)
	var drink_lock := refreshed_station.get_node("SafeArea/FiveAreaStationArtwork/PackagedDrinkLock") as CanvasItem
	var drink_click := refreshed_station.get_node("SafeArea/FiveAreaStationClickLayers/PackagedDrinkLockedClickLayer") as Button
	var chili_button := refreshed_station.get_node("SafeArea/RightRack/ChiliSauceRefillButton") as Button
	_check(not drink_lock.visible and not drink_click.disabled, "activated packaged-drink area is available after scene reload")
	refreshed_station.p1_session.phase = P1Session.Phase.SAUCE_AND_FILLINGS
	refreshed_station.call("_refresh_p1_ui")
	refreshed_station.get_node("SafeArea/PancakeWorkstationInteractionController").call("_refresh_sauce_controls")
	var sweet_button := refreshed_station.get_node("SafeArea/RightRack/SauceRefillButton") as Button
	_check(chili_button.visible and not chili_button.disabled and chili_button.mouse_filter == Control.MOUSE_FILTER_STOP, "activated chili sauce is a usable input control")
	_check(is_equal_approx(sweet_button.get_global_rect().end.x, chili_button.get_global_rect().position.x) and not chili_button.get_global_rect().intersects(sweet_button.get_global_rect()), "activated chili sauce keeps a real adjacent hit region to the right of sweet sauce")
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
