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
	for index in range(11):
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
		&"growth.recipe.fresh_soy_milk.black_bean",
		&"growth.equipment.fresh_soy_milk.intermediate",
	], "mid-route window unlocks soy first, then its ingredient and machine upgrade")
	_check(not soy_tickets[0].disabled and soy_tickets[1].disabled and soy_tickets[2].disabled, "soy content and machine upgrades wait until the soy area is actually installed")
	_check(_all_active_text(soy_tickets), "soy growth window contains only active three-area content")
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
