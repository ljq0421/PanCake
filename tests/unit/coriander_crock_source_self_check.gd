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
	var visual := workstation.get_node_or_null("SafeArea/JianbingStallArtwork/PancakeWorktopHotspots/CorianderTray/Visual") as TextureRect
	var fryer := workstation.get_node_or_null("FiveAreaInfrastructure/Stations/CartoonYoutiaoFryer") as Control
	_check(source != null and not source.disabled and not source.hold_enabled, "the unlocked unlimited coriander tray remains clickable without a restock gesture")
	_check(visual != null and visual.texture != null and visual.texture.resource_path.ends_with("xiangcai-v1.png"), "coriander uses the revised static tray artwork")
	_check(fryer != null and fryer.visible, "the unlocked fryer is visible beside the coriander crock")
	if source != null:
		source.begin_gesture(Vector2.ZERO)
		source.advance_gesture(0.42)
		_check(not source.is_hold_active(), "holding unlimited coriander never starts replenishment")
		source.end_gesture()
	var restock_status := Dictionary(session.call("five_area_restock_status", STOCK_ID))
	_check(not bool(restock_status.get("success", false)) and StringName(restock_status.get("reason", &"")) == &"restock_unnecessary", "coriander rejects paid restocking as unnecessary")
	_check(int(Dictionary(session.call("inventory_snapshot")).get(str(STOCK_ID), 0)) == 0, "unlimited coriander remains outside managed inventory")
	workstation.queue_free()
	await process_frame
	_finish()


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
