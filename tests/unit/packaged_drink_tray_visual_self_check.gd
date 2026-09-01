extends SceneTree

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const STATION_SCRIPT := preload("res://scripts/ui/packaged_drink_station.gd")
const PRODUCT_ID := &"product.packaged_drink.juice"
const STOCK_ID := &"stock.packaged_drink.juice"

var failures := PackedStringArray()


func _initialize() -> void:
	_check(int(CATALOG.stock_definition(STOCK_ID).get("restock_capacity", 0)) == 10, "juice restock capacity is ten")
	_check(STATION_SCRIPT.EMPTY_JUICE_TRAY_TEXTURE.resource_path.ends_with("container-l-empty-p1-v2-transparent.png"), "empty juice stock uses the P1 L container artwork")
	_check(STATION_SCRIPT.EMPTY_JUICE_TRAY_TEXTURE.get_size().x > STATION_SCRIPT.EMPTY_JUICE_TRAY_TEXTURE.get_size().y, "P1 empty juice tray keeps a horizontal authored canvas")
	_check(STATION_SCRIPT.MAX_REPRESENTATIVE_ITEMS == 5, "juice inventory is capped at five representative cartons")
	var station: Node = load("res://scenes/gameplay/packaged_drink_station.tscn").instantiate()
	station.call("_build_surface")
	var source := station.product_sources()[0] as ProductDragSource
	var representatives := source.find_children("Representative*", "TextureRect", false, false)
	var badge := source.get_node("CountBadge") as Label
	_check(representatives.size() == 5, "juice tray builds a fixed representative set instead of ten count-specific trays")
	station.call("_refresh_representative_overlay", source, 10, 10, true)
	_check(representatives.all(func(item: Node) -> bool: return (item as TextureRect).visible), "full stock shows five representative cartons")
	_check(badge.text == "×10", "real stock remains visible as a quantity badge")
	station.call("_refresh_representative_overlay", source, 0, 10, true)
	_check(representatives.all(func(item: Node) -> bool: return not (item as TextureRect).visible), "empty stock keeps the tray clear")
	_check(badge.text == "缺货 0", "empty stock uses text as well as warning colour")
	station.free()
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
