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
	_check_full_state(artwork.get_node("PancakeWorktopHotspots/ScallionTray/Visual") as IngredientTrayVisual, "scallion jar")
	_check_full_state(artwork.get_node("PancakeWorktopHotspots/CorianderTray/Visual") as IngredientTrayVisual, "coriander jar")
	_check(
		(artwork.get_node("PancakeWorktopHotspots/EggCarton/Visual/Contents") as TextureRect).texture == worktop.egg_content_textures.back(),
		"workshop preview shows a full egg carton"
	)
	_check(
		(artwork.get_node("PancakeWorktopHotspots/BaocuiBasket/Visual") as TextureRect).texture == worktop.baocui_basket_textures.back(),
		"workshop preview shows a full crisp basket"
	)
	worktop.set_workshop_preview(false)
	artwork.queue_free()
	_finish()


func _check_full_state(visual: IngredientTrayVisual, label: String) -> void:
	_check(visual != null and visual.texture == visual.state_textures.back(), "workshop preview shows a full %s" % label)


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
