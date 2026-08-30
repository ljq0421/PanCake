extends SceneTree

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const STATION_SCRIPT := preload("res://scripts/ui/packaged_drink_station.gd")
const PRODUCT_ID := &"product.packaged_drink.juice"
const STOCK_ID := &"stock.packaged_drink.juice"

var failures := PackedStringArray()


func _initialize() -> void:
	_check(int(CATALOG.stock_definition(STOCK_ID).get("restock_capacity", 0)) == 10, "juice restock capacity is ten")
	_check(STATION_SCRIPT.EMPTY_JUICE_TRAY_TEXTURE.resource_path.ends_with("yinpin-v1.png"), "empty juice stock uses the revised finished-drink tray")
	_check(STATION_SCRIPT.EMPTY_JUICE_TRAY_TEXTURE.get_size() == Vector2(419, 256), "empty juice tray uses the authored canvas")
	_check(STATION_SCRIPT.JUICE_STOCK_TEXTURES.size() == 10, "juice tray exposes all ten stock states")
	for stock_count in range(1, 11):
		var texture := STATION_SCRIPT._stock_texture_for(PRODUCT_ID, stock_count) as Texture2D
		var expected_path := "res://resources/art/products/orange_juice/yinpin-v1-%d.png" % stock_count
		_check(texture != null and texture.resource_path == expected_path, "juice stock %d uses its matching yinpin-v1 artwork" % stock_count)
		_check(texture != null and texture.get_size() == Vector2(419, 256), "juice stock %d uses the authored canvas" % stock_count)
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("PACKAGED_DRINK_TRAY_VISUAL_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("PACKAGED_DRINK_TRAY_VISUAL_SELF_CHECK_FAIL\n%s" % "\n".join(failures))
	quit(1)
