extends SceneTree

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const STATION_SCENE := preload("res://scenes/gameplay/packaged_drink_station.tscn")
const STOCK_ID := &"stock.packaged_drink.juice"

var _failures: Array[String] = []


func _initialize() -> void:
	var definition := CATALOG.stock_definition(STOCK_ID)
	_check(bool(definition.get("unlimited", false)) and int(definition.get("restock_capacity", -1)) == 0, "boxed juice is unlimited and has no refill capacity")
	var station := STATION_SCENE.instantiate() as PackagedDrinkStation
	station.call("_build_surface")
	var source := station.product_sources()[0] as ProductDragSource
	var representatives := source.find_children("Representative*", "TextureRect", false, false)
	var badge := source.get_node("CountBadge") as Label
	station.call("_refresh_representative_overlay", source, 5, 5, true, true)
	_check(representatives.size() == 5 and representatives.all(func(item: Node) -> bool: return (item as TextureRect).visible), "unlimited tray shows a stable set of five cartons")
	_check(not badge.visible, "unlimited tray never shows a stock count")
	station.free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PACKAGED_DRINK_TRAY_VISUAL_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("PACKAGED_DRINK_TRAY_VISUAL_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
