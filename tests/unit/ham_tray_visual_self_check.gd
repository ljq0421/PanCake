extends SceneTree

const ARTWORK_SCENE := preload("res://scenes/gameplay/jianbing_stall_artwork.tscn")
const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const STOCK_ID := &"stock.pancake.ham_sausage"

var failures := PackedStringArray()


func _initialize() -> void:
	var artwork := ARTWORK_SCENE.instantiate()
	var visual := artwork.get_node("PancakeWorktopHotspots/HamSource/Visual") as IngredientTrayVisual
	_check(int(CATALOG.stock_definition(STOCK_ID).get("restock_capacity", 0)) == 10, "ham restock capacity is ten")
	_check(visual.full_quantity == 10, "ham visual full quantity is ten")
	_check(visual.empty_texture != null and visual.empty_texture.resource_path.ends_with("empty-square-ingredient-tray-v1.png"), "ham uses the revised empty tray")
	_check(visual.state_textures.size() == 10, "ham tray exposes all ten stock states")
	visual._base_texture = visual.empty_texture
	for state_index in range(visual.state_textures.size()):
		var texture := visual.state_textures[state_index]
		var expected_path := "res://resources/art/ingredients/ham_sausage/huotui-v1-%d.png" % (state_index + 1)
		_check(texture != null and texture.resource_path == expected_path, "ham stock %d uses its matching huotui-v1 artwork" % (state_index + 1))
		_check(texture != null and texture.get_size() == Vector2(256, 256), "ham stock %d uses the authored 256-pixel canvas" % (state_index + 1))
		_check(visual._state_texture_for_quantity(state_index + 1) == texture, "ham stock %d selects its matching visual state" % (state_index + 1))
	artwork.free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("HAM_TRAY_VISUAL_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("HAM_TRAY_VISUAL_SELF_CHECK_FAIL\n%s" % "\n".join(failures))
	quit(1)
