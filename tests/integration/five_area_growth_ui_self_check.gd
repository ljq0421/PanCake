extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")
const CATALOG := preload("res://scripts/data/five_area_catalog.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession exists for three-area growth UI")
	if session == null:
		_finish()
		return

	session.call("begin_new_game")
	var progression: RefCounted = session.call("progression_service")
	progression.set("coins", 100)
	progression.set("reputation", 20)
	progression.set("tutorial_completed_area_ids", {&"area.pancake": true})
	var starter_station := WORKSTATION_SCENE.instantiate()
	root.add_child(starter_station)
	await process_frame
	await process_frame
	starter_station.call("end_business_day")
	var starter_tickets := _growth_tickets(starter_station)
	_check(starter_tickets.size() == 3, "day-end growth panel keeps a focused three-card window")
	_check(_ticket_ids(starter_tickets) == [
		&"growth.tool.pancake.wide_spreader",
		&"growth.add_on.pancake.red_chili",
		&"growth.add_on.pancake.ham_sausage",
	], "opening route focuses on pancake handling and add-ons before another area")
	_check(starter_tickets[0].disabled and not starter_tickets[1].disabled and starter_tickets[2].disabled, "each opening growth card reflects its own day and reputation gates")
	_check(_all_active_text(starter_tickets), "opening growth cards contain no retired drink or steamer copy")
	starter_tickets[1].emit_signal("pressed")
	await process_frame
	var pending: Dictionary = session.call("five_area_progression_snapshot")
	_check(StringName(pending.get("pending_content_purchase", &"")) == &"growth.add_on.pancake.red_chili", "purchasing a pancake add-on reserves the content slot")
	_check(starter_tickets[1].disabled, "pending add-on remains visible and cannot be charged twice")
	starter_station.queue_free()
	await process_frame

	session.call("begin_new_game")
	progression = session.call("progression_service")
	progression.set("coins", 500)
	progression.set("current_day", 12)
	progression.set("reputation", 120)
	progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.youtiao": true})
	progression.set("tutorial_completed_area_ids", {&"area.pancake": true, &"area.youtiao": true})
	progression.set("area_mastery_details", {
		&"area.pancake": {"qualified": 20, "a_grade": 8},
		&"area.youtiao": {"qualified": 6, "a_grade": 2},
	})
	var route: Array[StringName] = CATALOG.growth_ids()
	var owned := {}
	var soy_area_index := route.find(&"growth.area.fresh_soy_milk")
	_check(soy_area_index >= 0, "growth route contains the stable soy area unlock")
	for index in range(maxi(soy_area_index, 0)):
		owned[route[index]] = true
	progression.set("owned_growth_ids", owned)
	var soy_station := WORKSTATION_SCENE.instantiate()
	root.add_child(soy_station)
	await process_frame
	await process_frame
	soy_station.call("end_business_day")
	var soy_tickets := _growth_tickets(soy_station)
	_check(_ticket_ids(soy_tickets) == [
		&"growth.area.fresh_soy_milk",
		&"growth.assist.fresh_soy_milk.sugar",
		&"growth.assist.fresh_soy_milk.ice",
	], "mid-route window unlocks soy and its remaining serving assists")
	_check(not soy_tickets[0].disabled and soy_tickets[1].disabled and soy_tickets[2].disabled, "soy serving upgrades wait until the soy area is actually installed")
	_check(_all_active_text(soy_tickets), "soy growth window contains only active three-area content")
	soy_station.call("_open_upgrade_workshop")
	await process_frame
	var workshop := soy_station.get_node_or_null("SafeArea/UpgradeWorkshopOverlay") as UpgradeWorkshopOverlay
	var soy_purchase_target := workshop.get_node_or_null("UpgradeProps/WorkshopProp_growth_area_fresh_soy_milk") as Button if workshop != null else null
	_check(soy_purchase_target != null and soy_purchase_target.visible, "workshop exposes a visible soy-machine purchase target")
	_check(soy_purchase_target != null and (soy_purchase_target.get_node_or_null("ConditionTag") as Label).text.begins_with("初级豆浆机"), "soy-machine purchase target has the basic-machine label")
	if soy_purchase_target != null:
		soy_purchase_target.emit_signal("pressed")
		await process_frame
		var buy_button := workshop.get_node_or_null("DetailPanel/BuyButton") as Button
		_check(buy_button != null and not buy_button.disabled, "soy-machine detail enables reservation when its conditions are met")
		if buy_button != null and not buy_button.disabled:
			buy_button.emit_signal("pressed")
			await process_frame
			soy_station.call("_refresh_formal_area_visibility")
			await process_frame
			var soy_preview := soy_station.get_node_or_null("FiveAreaInfrastructure/Stations/FreshSoyMilkStation") as Control
			_check(soy_preview != null and soy_preview.visible and is_equal_approx(soy_preview.modulate.a, 0.42), "reserved soy machine remains a translucent workshop preview until next day")
	soy_station.queue_free()
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


func _all_active_text(tickets: Array[Button]) -> bool:
	for ticket in tickets:
		var copy := ticket.text + " " + ticket.tooltip_text
		if "成品饮品" in copy or "蒸笼" in copy or "蒸品" in copy:
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("THREE_AREA_GROWTH_UI_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("THREE_AREA_GROWTH_UI_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
