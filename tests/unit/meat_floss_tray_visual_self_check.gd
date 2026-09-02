extends SceneTree

const ARTWORK_SCENE := preload("res://scenes/gameplay/jianbing_stall_artwork.tscn")
const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const STOCK_ID := &"stock.pancake.meat_floss"

var failures := PackedStringArray()


func _initialize() -> void:
	var artwork := ARTWORK_SCENE.instantiate()
	var visual := artwork.get_node("PancakeWorktopHotspots/PorkFlossSource/Visual") as IngredientTrayVisual
	_check(int(CATALOG.stock_definition(STOCK_ID).get("restock_capacity", 0)) == 10, "meat-floss restock capacity is ten")
	_check(visual.full_quantity == 10, "meat-floss visual full quantity is ten")
	_check(visual.empty_texture != null and visual.empty_texture.resource_path.ends_with("empty-square-ingredient-tray-v1.png"), "meat floss uses the revised empty tray")
	_check(visual.state_textures.size() == 10, "meat-floss tray exposes all ten stock states")
	visual._base_texture = visual.empty_texture
	for state_index in range(visual.state_textures.size()):
		var texture := visual.state_textures[state_index]
		var expected_path := "res://resources/art/workstation/containers/p1/container-m-pork-floss-full-p1-v2-transparent.png" if state_index == 9 else "res://resources/art/ingredients/meat_floss/rousong-v1-%d.png" % (state_index + 1)
		_check(texture != null and texture.resource_path == expected_path, "meat-floss stock %d uses its matching authored artwork" % (state_index + 1))
		_check(texture != null and (state_index == 9 or texture.get_size() == Vector2(256, 256)), "partial meat-floss state %d keeps its legacy canvas while full stock uses the P1 M master" % (state_index + 1))
		_check(visual._state_texture_for_quantity(state_index + 1) == visual.state_textures.back(), "meat-floss stock %d keeps one representative full-looking master" % (state_index + 1))
	_check(visual._state_texture_for_quantity(0) == visual.empty_texture, "zero meat-floss stock uses the empty tray")
	_check(visual.size.is_equal_approx(Vector2(176.0, 96.0)), "meat-floss stock states share the P1 M display rectangle")
	artwork.free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("MEAT_FLOSS_TRAY_VISUAL_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("MEAT_FLOSS_TRAY_VISUAL_SELF_CHECK_FAIL\n%s" % "\n".join(failures))
	quit(1)
