extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession is available")
	if session != null:
		session.call("begin_new_game")
		var progression: RefCounted = session.call("progression_service")
		var unlocked_stocks := Dictionary(progression.get("unlocked_stock_ids")).duplicate(true)
		unlocked_stocks[&"stock.pancake.scallion"] = true
		progression.set("unlocked_stock_ids", unlocked_stocks)
		session.call("_sync_progression_to_save")
		var inventory := Dictionary(session.call("inventory_snapshot"))
		inventory["stock.pancake.scallion"] = 1
		session.call("save_inventory", inventory)
	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	for _frame in 3:
		await process_frame
	var hotspots := workstation.get_node_or_null("SafeArea/JianbingStallArtwork/PancakeWorktopHotspots") as PancakeWorktopHotspots
	var crock := hotspots.get_node_or_null("ScallionTray/Visual") as IngredientTrayVisual if hotspots != null else null
	var coriander_crock := hotspots.get_node_or_null("CorianderTray/Visual") as TextureRect if hotspots != null else null
	var source := hotspots.get_node_or_null("ScallionTray/Hotspot") as ProductDragSource if hotspots != null else null
	var coriander_source := hotspots.get_node_or_null("CorianderTray/Hotspot") as ProductDragSource if hotspots != null else null
	var spreader_source := hotspots.get_node_or_null("SpreaderSource/HitButton") as AlphaTextureHitButton if hotspots != null else null
	var spreader_holder := hotspots.get_node_or_null("SpreaderSource/Visual") as TextureRect if hotspots != null else null
	_check(crock != null, "the workbench includes a dedicated scallion crock visual")
	_check(source != null and source.hold_enabled and not source.native_drag_enabled, "the crock uses click-to-add and hold-to-restock gestures")
	if crock != null:
		_check(crock.state_textures.size() == 3, "the crock has empty, half-full, and full state textures")
		_check(crock._state_texture_for_quantity(0).resource_path.ends_with("scallion-crock-empty.png"), "zero scallion stock shows the empty crock")
		_check(crock._state_texture_for_quantity(1).resource_path.ends_with("scallion-crock-half.png"), "partial scallion stock shows the half-full crock")
		_check(crock._state_texture_for_quantity(6).resource_path.ends_with("scallion-crock-full.png"), "full scallion stock shows the full crock")
	if crock != null and source != null:
		_check(crock.get_global_rect() == source.get_global_rect(), "crock artwork and interaction target share the ScallionTray placement")
		_check(crock.size.x > 0.0 and crock.size.y > 0.0, "scallion crock keeps a non-empty authored interaction footprint")
	if coriander_crock != null and coriander_source != null:
		_check(coriander_crock.get_global_rect() == coriander_source.get_global_rect(), "coriander crock artwork and interaction target share the CorianderTray placement")
		_check(coriander_crock.get_node_or_null("Contents") == null, "state-texture coriander crock keeps no redundant contents layer")
	if crock != null and source != null and spreader_source != null:
		var pointer_position := root.get_final_transform() * source.get_global_rect().get_center()
		Input.warp_mouse(pointer_position)
		var motion := InputEventMouseMotion.new()
		motion.position = pointer_position
		motion.global_position = pointer_position
		Input.parse_input_event(motion)
		await process_frame
		_check(root.gui_get_hovered_control() == source, "real pointer input reaches the scallion crock even near the spreader")
	if spreader_source != null and spreader_holder != null:
		_check(spreader_source.get_global_rect() == spreader_holder.get_global_rect(), "spreader hotspot matches its visible holder")
	workstation.queue_free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("SCALLION_CROCK_INVENTORY_VISUAL_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("SCALLION_CROCK_INVENTORY_VISUAL_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
