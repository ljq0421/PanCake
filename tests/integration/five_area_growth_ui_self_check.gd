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
	var station = WORKSTATION_SCENE.instantiate()
	root.add_child(station)
	await process_frame
	await process_frame
	station.call("end_business_day")
	_check(station.get_node("SafeArea/DailyBillPanel").visible, "day-end bill opens the existing growth UI")
	var ticket_1 := station.get_node("SafeArea/DailyBillPanel/Margin/VBox/GrowthTickets/GrowthTicket1") as Button
	var ticket_3 := station.get_node("SafeArea/DailyBillPanel/Margin/VBox/GrowthTickets/GrowthTicket3") as Button
	_check("安装位" in ticket_1.text and "内容位" in ticket_3.text, "growth UI exposes separate install and content purchase slots")
	_check(bool(session.call("purchase_growth", &"growth.area.packaged_drink").get("success", false)), "install purchase accepted from settlement state")
	_check(bool(session.call("purchase_growth", &"growth.add_on.pancake.red_chili").get("success", false)), "content purchase accepted alongside install state")
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
	var drink_click := refreshed_station.get_node("SafeArea/FiveAreaStationClickLayers/PackagedDrinkLockedClickLayer") as Button
	_check(not drink_lock.visible and drink_click.disabled, "scene reload refreshes activated packaged-drink lock state")
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
