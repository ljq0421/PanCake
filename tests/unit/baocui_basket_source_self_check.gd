extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/four_area_workstation.tscn")
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
	var visual := basket_component.get_node_or_null("Visual") as TextureRect if basket_component != null else null
	_check(basket_component != null and basket != null, "BaocuiBasket owns the shared worktop source")
	var hotspot_controller := basket_component.get_parent() as PancakeWorktopHotspots if basket_component != null else null
	_check(hotspot_controller != null and hotspot_controller.baocui_tray_textures.size() == 10, "the crisp tray has one complete-tray texture for each of the ten stock states")
	var restock_status := Dictionary(session.call("five_area_restock_status", STOCK_ID))
	_check(int(restock_status.get("capacity", 0)) == 10, "the crisp restock capacity is ten")
	var legacy_texture_size: Vector2 = hotspot_controller.baocui_tray_textures.front().get_size() if hotspot_controller != null and not hotspot_controller.baocui_tray_textures.is_empty() else Vector2.ZERO
	_check(legacy_texture_size == Vector2(256, 256), "legacy partial crisp states retain their authored 256-pixel canvas")
	if hotspot_controller != null:
		for texture_index in range(hotspot_controller.baocui_tray_textures.size()):
			var expected_path := "res://resources/art/workstation/containers/p1/container-m-baocui-full-p1-v2-transparent.png" if texture_index == 9 else "res://resources/art/ingredients/baocui/baocui-v1-%d.png" % (texture_index + 1)
			var texture := hotspot_controller.baocui_tray_textures[texture_index]
			_check(texture != null and texture.resource_path == expected_path, "crisp tray state %d uses its matching authored artwork" % (texture_index + 1))
			_check(texture != null and (texture_index == 9 or texture.get_size() == legacy_texture_size), "partial crisp state %d keeps the legacy canvas while full stock uses the P1 M master" % (texture_index + 1))
		_check(visual != null and visual.size.is_equal_approx(Vector2(176.0, 96.0)), "all crisp stock art is normalized into the P1 M display rectangle")
	if basket != null:
		_check(not basket.disabled, "an empty unlocked basket remains clickable for restocking")
		_check(not basket._has_point(Vector2.ZERO), "transparent margin outside the crisp-basket artwork is not clickable")
		await _hold_control(basket)
		await process_frame
		var replenished := Dictionary(session.call("inventory_snapshot"))
		_check(int(replenished.get(str(STOCK_ID), 0)) == 1, "holding an empty basket replenishes one crisp through real pointer input")
		_check(visual != null and hotspot_controller != null and visual.texture == hotspot_controller.baocui_tray_textures.front(), "one-crisp tray artwork appears after restocking")
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
	# 0.2 seconds enters restock mode, then the current 0.15-second per-crisp
	# duration completes exactly one committed unit; the remainder is cancelled.
	await create_timer(0.42).timeout
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
