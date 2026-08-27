extends SceneTree

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
	session.call("begin_new_game")
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	for _frame in 4:
		await process_frame
	var workstation := game.get_node("Workstation")
	var station: Control = workstation.multi_griddle_station
	var unit: Node = station.units[0]
	station.call("_on_main_action", 0)
	unit.call("mark_ready", {
		"product_instance_id": &"test.opening_prepared_pancake",
		"product_id": &"product.pancake.custom",
		"area_id": &"area.pancake",
		"status": &"available",
	})
	station.call("_sync_snapshot_to_session")
	var prepared_snapshot := Dictionary(unit.snapshot())
	_check(unit.state == CompactGriddleUnit.State.READY, "a pancake can be completed during the opening restock window")

	# Drive the exact workstation arrival path: it both opens the storefront and
	# focuses the first generated order in the same frame.
	workstation.call("_process", 5.0)
	var preserved_snapshot := Dictionary(unit.snapshot())
	_check(Array(session.call("active_formal_orders")).size() == 1, "the first customer enters when restocking ends")
	_check(
		unit.state == CompactGriddleUnit.State.READY
		and preserved_snapshot == prepared_snapshot,
		"focusing the first customer preserves production completed during restocking",
	)
	var saved_slots := Array(Dictionary(session.call("five_area_pancake_griddles_snapshot")).get("slots", []))
	_check(
		not saved_slots.is_empty() and int(Dictionary(saved_slots[0]).get("state", -1)) == CompactGriddleUnit.State.READY,
		"the preserved opening production remains durable in the session snapshot",
	)
	game.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("OPENING_RESTOCK_PRODUCTION_PRESERVATION_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("OPENING_RESTOCK_PRODUCTION_PRESERVATION_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
