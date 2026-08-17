extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Pancake worktop sauce pointer smoke must run with a display")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession exists")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	var inventory := Dictionary(session.call("inventory_snapshot"))
	inventory["stock.pancake.sauce.sweet_flour"] = 2
	session.call("save_inventory", inventory)
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	for _frame in 12:
		await process_frame
	var workstation := game.get_node("Workstation")
	var station: Control = workstation.multi_griddle_station
	var unit: Node = station.units[0]
	station.clear_held_tool()
	unit.reset_unit()
	unit.begin_order({})
	unit.state = CompactGriddleUnit.State.FIRST_SIDE
	unit.p1_session.phase = P1Session.Phase.FIRST_SIDE
	var sweet := workstation.get_node("FiveAreaInfrastructure/PancakeWorktopHotspots/SweetSauceHotspot") as ProductDragSource
	var hit := workstation.get_node("FiveAreaInfrastructure/PancakeWorktopHotspots/SweetSauceHotspotHitButton") as Button
	var hotspots := hit.get_parent()
	var short_clicks := [0]
	sweet.short_clicked.connect(func(_source_ref: Dictionary) -> void: short_clicks[0] += 1)
	var before := int(Dictionary(session.call("inventory_snapshot")).get("stock.pancake.sauce.sweet_flour", 0))
	await _hover_control(hit)
	_check(root.gui_get_hovered_control() == hit, "the authored transparent sauce button owns the rendered jar hit area")
	_check(not sweet.disabled, "the sweet-sauce source is enabled")
	hotspots.call("_on_sauce_hit_button_down", sweet)
	hotspots.call("_on_sauce_hit_button_up", sweet)
	await process_frame
	_check(short_clicks[0] == 1, "the authored sauce button routes one short click")
	_check(unit.applied_sauce_ids.has("stock.pancake.sauce.sweet_flour"), "the sauce click places sweet sauce on the pancake")
	_check(int(Dictionary(session.call("inventory_snapshot")).get("stock.pancake.sauce.sweet_flour", 0)) == before - 1, "the sauce click consumes one sweet-sauce unit")
	_check(unit.pancake_surface.cursor_is_sauce_brush, "the sauce click arms the sauce brush")
	game.queue_free()
	await process_frame
	_finish()


func _hover_control(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion)
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("PANCAKE_WORKTOP_SAUCE_POINTER_GPU_SMOKE_PASS")
		quit(0)
		return
	printerr("PANCAKE_WORKTOP_SAUCE_POINTER_GPU_SMOKE_FAIL\n" + "\n".join(failures))
	quit(1)
