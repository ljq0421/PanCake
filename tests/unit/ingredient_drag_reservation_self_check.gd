extends SceneTree

const STATION_SCENE := preload("res://scenes/gameplay/multi_griddle_station.tscn")
const HOTSPOTS_SCRIPT := preload("res://scripts/ui/pancake_worktop_hotspots.gd")
const DRAG_SOURCE_SCRIPT := preload("res://scripts/ui/product_drag_source.gd")
const STOCK_ID := &"stock.pancake.baocui"


class FakeProgression:
	extends RefCounted

	var stock_capacity := 6

	func owns_stock(_stock_id: StringName) -> bool:
		return true

	func owns_growth(_growth_id: StringName) -> bool:
		return false


class FakeSession:
	extends Node

	var progression := FakeProgression.new()
	var inventory := {str(STOCK_ID): 1}

	func progression_service() -> RefCounted:
		return progression

	func inventory_snapshot() -> Dictionary:
		return inventory.duplicate(true)

	func consume_inventory_stock_ids(stock_ids: Array) -> Dictionary:
		for stock_id in stock_ids:
			if int(inventory.get(str(stock_id), 0)) <= 0:
				return {"success": false, "reason": &"insufficient_stock"}
		for stock_id in stock_ids:
			var key := str(stock_id)
			inventory[key] = int(inventory.get(key, 0)) - 1
		return {"success": true}

	func restore_inventory_stock_ids(stock_ids: Array) -> Dictionary:
		for stock_id in stock_ids:
			var key := str(stock_id)
			inventory[key] = int(inventory.get(key, 0)) + 1
		return {"success": true}


var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := FakeSession.new()
	root.add_child(session)
	var station := STATION_SCENE.instantiate()
	station.name = &"MultiGriddleStation"
	root.add_child(station)
	await process_frame
	station.bind_session(session)

	var hotspots := HOTSPOTS_SCRIPT.new()
	hotspots.name = &"PancakeWorktopHotspots"
	hotspots.griddle_station_path = NodePath("../MultiGriddleStation")
	var basket := Control.new()
	basket.name = &"BaocuiBasket"
	var visual := TextureRect.new()
	visual.name = &"Visual"
	basket.add_child(visual)
	var source := DRAG_SOURCE_SCRIPT.new() as ProductDragSource
	source.name = &"Hotspot"
	source.size = Vector2(100.0, 100.0)
	basket.add_child(source)
	hotspots.add_child(basket)
	hotspots.baocui_basket_textures = [_solid_texture(Color.ORANGE)]
	root.add_child(hotspots)
	await process_frame
	hotspots.bind_session(session)

	_start_drag(source)
	await process_frame
	_check(int(session.inventory.get(str(STOCK_ID), -1)) == 0, "drag start immediately removes one crisp from inventory")
	_check(visual.texture == HOTSPOTS_SCRIPT.BAOCUI_EMPTY_BASKET, "drag start immediately shows one fewer crisp in the basket")

	source.drag_ended.emit(source.source_ref(), false)
	await process_frame
	_check(int(session.inventory.get(str(STOCK_ID), -1)) == 1, "an unsuccessful drag restores its reserved crisp")
	_check(visual.texture == hotspots.baocui_basket_textures.front(), "an unsuccessful drag restores the basket artwork")

	var unit: CompactGriddleUnit = station.units[0]
	unit.begin_order({})
	unit.state = CompactGriddleUnit.State.FIRST_SIDE
	_start_drag(source)
	var placed := Dictionary(station.drop_on_unit(0, source.source_ref(), unit.pancake_surface.size * 0.5))
	_check(bool(placed.get("success", false)), "the last reserved crisp can still be placed after visible inventory reaches zero")
	_check(int(session.inventory.get(str(STOCK_ID), -1)) == 0, "a successful drop does not consume the reserved crisp twice")
	_check(unit.ingredient_model.count_type(IngredientModel.BAOCUI) == 1, "the reserved crisp reaches the pancake model")

	hotspots.queue_free()
	station.queue_free()
	session.queue_free()
	_finish()


func _start_drag(source: ProductDragSource) -> void:
	source.begin_gesture(Vector2.ZERO)
	source.update_gesture(Vector2(source.drag_threshold_pixels + 1.0, 0.0), false)


func _solid_texture(color: Color) -> Texture2D:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("INGREDIENT_DRAG_RESERVATION_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("INGREDIENT_DRAG_RESERVATION_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
