extends SceneTree

const ARTWORK_SCENE := preload("res://scenes/gameplay/jianbing_stall_artwork.tscn")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var artwork := ARTWORK_SCENE.instantiate() as Control
	root.add_child(artwork)
	await process_frame
	await process_frame
	var worktop := artwork.get_node("PancakeWorktopHotspots") as PancakeWorktopHotspots
	worktop.bind_session(root.get_node("GameSession"))
	worktop.set_workshop_preview(true)
	await process_frame

	_check_full_state(artwork.get_node("PancakeWorktopHotspots/PorkFlossSource/Visual") as IngredientTrayVisual, "meat floss tray")
	_check_full_state(artwork.get_node("PancakeWorktopHotspots/HamSource/Visual") as IngredientTrayVisual, "ham tray")
	_check_static_state(artwork.get_node("PancakeWorktopHotspots/ScallionTray/Visual") as IngredientTrayVisual, "container-s-scallion-p1-v2-transparent.png", "scallion tray")
	_check_static_state(artwork.get_node("PancakeWorktopHotspots/CorianderTray/Visual") as IngredientTrayVisual, "container-s-coriander-p1-v2-transparent.png", "coriander tray")
	_check(
		(artwork.get_node("PancakeWorktopHotspots/EggCarton/Visual") as TextureRect).texture == worktop.egg_content_textures.back(),
		"workshop preview shows a full egg carton"
	)
	var egg_contents := artwork.get_node("PancakeWorktopHotspots/EggCarton/Visual/Contents") as TextureRect
	_check(not egg_contents.visible and egg_contents.texture == null, "workshop preview does not reuse the legacy egg overlay")
	_check(
		(artwork.get_node("PancakeWorktopHotspots/BaocuiBasket/Visual") as TextureRect).texture == worktop.baocui_tray_textures.back(),
		"workshop preview shows a full crisp tray"
	)
	worktop.set_workshop_preview(false)
	artwork.queue_free()
	_finish()


func _check_full_state(visual: IngredientTrayVisual, label: String) -> void:
	_check(visual != null and visual.texture == visual.state_textures.back(), "workshop preview shows a full %s" % label)


func _check_static_state(visual: IngredientTrayVisual, expected_filename: String, label: String) -> void:
	_check(visual != null and visual.state_textures.is_empty() and visual.texture != null and visual.texture.resource_path.ends_with(expected_filename), "workshop preview shows the static unlimited %s" % label)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("UPGRADE_WORKSHOP_STOCK_PREVIEW_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("UPGRADE_WORKSHOP_STOCK_PREVIEW_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
