extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	await process_frame
	var hotspots := workstation.get_node_or_null("FiveAreaInfrastructure/PancakeWorktopHotspots") as PancakeWorktopHotspots
	var crock := workstation.get_node_or_null("SafeArea/JianbingStallArtwork/HerbMetalTray") as IngredientTrayVisual
	var coriander_crock := workstation.get_node_or_null("SafeArea/JianbingStallArtwork/CorianderMetalTray") as TextureRect
	var source := hotspots.get_node_or_null("ScallionHotspot") as ProductDragSource if hotspots != null else null
	_check(crock != null, "the workbench includes a dedicated scallion crock visual")
	_check(source != null and source.hold_enabled and source.native_drag_enabled, "the crock keeps shared drag-to-griddle and hold-to-restock gestures")
	if crock != null:
		_check(crock.state_textures.size() == 3, "the crock has empty, half-full, and full state textures")
		_check(crock._state_texture_for_quantity(0).resource_path.ends_with("scallion-crock-empty.png"), "zero scallion stock shows the empty crock")
		_check(crock._state_texture_for_quantity(1).resource_path.ends_with("scallion-crock-half.png"), "partial scallion stock shows the half-full crock")
		_check(crock._state_texture_for_quantity(6).resource_path.ends_with("scallion-crock-full.png"), "full scallion stock shows the full crock")
	if crock != null and source != null:
		_check(crock.get_global_rect() == source.get_global_rect(), "crock artwork and interaction target share the HerbMetalTray placement")
		_check(coriander_crock != null and crock.size == coriander_crock.size, "scallion crock uses the same on-workbench size as the coriander crock")
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
