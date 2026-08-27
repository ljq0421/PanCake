extends SceneTree

const ARTWORK_SCENE := preload("res://scenes/gameplay/jianbing_stall_artwork.tscn")

var failures := PackedStringArray()


func _initialize() -> void:
	var artwork := ARTWORK_SCENE.instantiate()
	var hotspots := artwork.get_node("PancakeWorktopHotspots") as PancakeWorktopHotspots
	var meat_floss_visual := artwork.get_node("PancakeWorktopHotspots/PorkFlossSource/Visual") as IngredientTrayVisual
	var ham_visual := artwork.get_node("PancakeWorktopHotspots/HamSource/Visual") as IngredientTrayVisual
	_check(hotspots.baocui_tray_textures.size() == meat_floss_visual.state_textures.size(), "crisp and meat-floss trays expose the same number of stock states")
	_check(hotspots.baocui_tray_textures.size() == ham_visual.state_textures.size(), "crisp and ham trays expose the same number of stock states")
	for state_index in range(hotspots.baocui_tray_textures.size()):
		var crisp_texture := hotspots.baocui_tray_textures[state_index]
		var meat_floss_texture := meat_floss_visual.state_textures[state_index]
		var ham_texture := ham_visual.state_textures[state_index]
		_check(crisp_texture.get_size() == meat_floss_texture.get_size(), "crisp tray state %d matches the meat-floss tray canvas" % (state_index + 1))
		_check(crisp_texture.get_size() == ham_texture.get_size(), "crisp tray state %d matches the ham tray canvas" % (state_index + 1))
		_check(crisp_texture.get_image().get_used_rect() == meat_floss_texture.get_image().get_used_rect(), "crisp tray state %d keeps the same plate bounds as meat floss" % (state_index + 1))
		_check(crisp_texture.get_image().get_used_rect() == ham_texture.get_image().get_used_rect(), "crisp tray state %d keeps the same plate bounds as ham" % (state_index + 1))
	artwork.free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("BAOCUI_TRAY_SCALE_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("BAOCUI_TRAY_SCALE_SELF_CHECK_FAIL\n%s" % "\n".join(failures))
	quit(1)
