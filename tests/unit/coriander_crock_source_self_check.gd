extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")
const STOCK_ID := &"stock.pancake.coriander"

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession is available")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	var progression: RefCounted = session.call("progression_service")
	progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.youtiao": true})
	progression.set("unlocked_recipe_ids", {&"recipe.pancake.base": true, &"recipe.youtiao.plain": true})
	progression.set("unlocked_stock_ids", {&"stock.pancake.batter": true, &"stock.pancake.egg": true, &"stock.pancake.baocui": true, &"stock.pancake.scallion": true, &"stock.pancake.sauce.sweet_flour": true, STOCK_ID: true, &"stock.youtiao.plain_dough": true})
	progression.set("coins", 10)
	session.call("_sync_progression_to_save")
	var inventory := Dictionary(session.call("inventory_snapshot"))
	inventory[str(STOCK_ID)] = 0
	session.call("save_inventory", inventory)

	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	for _frame in range(4):
		await process_frame
	var source := workstation.get_node_or_null("SafeArea/JianbingStallArtwork/PancakeWorktopHotspots/CorianderTray/Hotspot") as ProductDragSource
	var fryer := workstation.get_node_or_null("FiveAreaInfrastructure/Stations/CartoonYoutiaoFryer") as Control
	_check(source != null and not source.disabled, "an empty unlocked coriander crock remains clickable")
	_check(fryer != null and fryer.visible, "the unlocked fryer is visible beside the coriander crock")
	if source != null:
		await _hold_control(source)
		await process_frame
		var replenished := Dictionary(session.call("inventory_snapshot"))
		_check(int(replenished.get(str(STOCK_ID), 0)) == 1, "holding the coriander crock works while the fryer is visible")
	workstation.queue_free()
	await process_frame
	_finish()


func _hold_control(control: Control) -> void:
	var position := root.get_final_transform() * control.get_global_rect().get_center()
	Input.warp_mouse(position)
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)
	await process_frame
	_check(root.gui_get_hovered_control() == control, "real pointer reaches the coriander crock instead of the fryer")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = position
	press.global_position = position
	root.push_input(press)
	await create_timer(0.54).timeout
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = position
	release.global_position = position
	root.push_input(release)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("CORIANDER_CROCK_SOURCE_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("CORIANDER_CROCK_SOURCE_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
