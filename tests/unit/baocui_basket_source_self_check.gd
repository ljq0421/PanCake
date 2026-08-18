extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")
const STOCK_ID := &"stock.pancake.baocui"

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
	progression.set("unlocked_stock_ids", {STOCK_ID: true})
	progression.set("coins", 10)
	session.call("_sync_progression_to_save")
	var inventory := Dictionary(session.call("inventory_snapshot"))
	inventory[str(STOCK_ID)] = 0
	session.call("save_inventory", inventory)

	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	for _frame in range(4):
		await process_frame
	var basket_component := workstation.get_node_or_null("SafeArea/JianbingStallArtwork/PancakeWorktopHotspots/BaocuiBasket") as Control
	var basket := basket_component.get_node_or_null("Hotspot") as ProductDragSource if basket_component != null else null
	_check(basket_component != null and basket != null, "BaocuiBasket owns the shared worktop source")
	if basket != null:
		_check(not basket.disabled, "an empty unlocked basket remains clickable for restocking")
		await _hold_control(basket)
		await process_frame
		var replenished := Dictionary(session.call("inventory_snapshot"))
		_check(int(replenished.get(str(STOCK_ID), 0)) == 1, "holding an empty basket replenishes one crisp through real pointer input")
		var contents := basket_component.get_node_or_null("Contents") as TextureRect
		_check(contents != null and contents.get_parent() == basket_component and contents.visible and contents.texture != null, "one-crisp artwork appears in the managed basket contents layer after restocking")
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
	var hovered := root.gui_get_hovered_control()
	_check(hovered == control, "real pointer reaches the BaocuiBasket hotspot")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = position
	press.global_position = position
	root.push_input(press)
	# 0.2 seconds enters restock mode, then the configured 0.225-second
	# per-crisp restock duration completes the first unit.
	await create_timer(0.52).timeout
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
		print("PANCAKE_WORKTOP_BAOCUI_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("PANCAKE_WORKTOP_BAOCUI_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
