extends SceneTree

const ARTWORK_SCENE := preload("res://scenes/gameplay/jianbing_stall_artwork.tscn")
const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const STOCK_ID := &"stock.pancake.baocui"

var failures := PackedStringArray()


func _initialize() -> void:
	var artwork := ARTWORK_SCENE.instantiate()
	var hotspots := artwork.get_node("PancakeWorktopHotspots") as PancakeWorktopHotspots
	var visual := artwork.get_node("PancakeWorktopHotspots/BaocuiBasket/Visual") as TextureRect
	_check(int(CATALOG.stock_definition(STOCK_ID).get("restock_capacity", 0)) == 10, "crisp restock capacity is ten")
	_check(hotspots.baocui_tray_textures.size() == 10, "crisp tray exposes all ten stock states")
	for state_index in range(hotspots.baocui_tray_textures.size()):
		var crisp_texture := hotspots.baocui_tray_textures[state_index]
		_check(crisp_texture != null and (state_index == 9 or crisp_texture.get_size() == Vector2(256, 256)), "partial crisp state %d keeps its legacy canvas while full stock uses the P1 M master" % (state_index + 1))
		hotspots._update_baocui_inventory_visual(state_index + 1)
		_check(visual.texture == crisp_texture, "crisp stock %d selects its matching visual state" % (state_index + 1))
	_check(visual.size.is_equal_approx(Vector2(176.0, 96.0)), "crisp stock states share the P1 M display rectangle")
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
