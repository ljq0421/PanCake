extends SceneTree

## Covers the live workstation update loop, not merely the scheduler service.
## A fresh day must move from the five-second opening restock phase to a
## visible, focused tutorial customer without a manual scheduler call.

const MAIN_SCENE := preload("res://scenes/main/main.tscn")

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "test has the GameSession autoload")
	if session == null:
		_finish()
		return
	var started: Dictionary = session.call("begin_new_game")
	_check(bool(started.get("success", false)), "new business day starts")
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await create_timer(6.0).timeout
	await process_frame
	var orders: Array = Array(session.call("active_formal_orders"))
	var workstation := game.get_node_or_null("Workstation")
	_check(orders.size() == 1, "the live scene creates the first customer after opening restock")
	_check(workstation != null, "main scene has a workstation")
	if workstation != null:
		var slots := Array(workstation.get("customer_service_slots"))
		var visible_slots := 0
		for slot_variant in slots:
			if (slot_variant as Control).visible:
				visible_slots += 1
		_check(visible_slots == 1, "the first customer is visible in a service slot")
	game.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CUSTOMER_ARRIVAL_LIVE_SCENE_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("CUSTOMER_ARRIVAL_LIVE_SCENE_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
