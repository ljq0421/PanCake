extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/four_area_workstation.tscn")
const PRODUCT_ID := &"product.packaged_drink.juice"
const EXPECTED_TRAY_SIZE := Vector2(364.0, 204.0)

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	await process_frame

	var pancake_tray := workstation.get_node("FiveAreaInfrastructure/Stations/PancakeHoldingTray") as TextureButton
	var drink_tray := workstation.get_node("FiveAreaInfrastructure/Stations/PackagedDrinkStation") as Control
	var drink_sources: Array = drink_tray.call("product_sources")
	_check(pancake_tray.size.is_equal_approx(EXPECTED_TRAY_SIZE), "pancake finished tray keeps the 364x204 reference size")
	_check(drink_tray.size.is_equal_approx(pancake_tray.size), "packaged-drink tray matches the pancake finished tray size")
	_check(drink_tray.scale.is_equal_approx(Vector2.ONE), "packaged-drink tray uses its authored size without an extra transform scale")
	_check(is_equal_approx(drink_tray.global_position.y, pancake_tray.global_position.y), "the two finished trays are horizontally aligned")
	_check(is_equal_approx(drink_tray.global_position.x, pancake_tray.global_position.x + pancake_tray.size.x), "packaged-drink tray sits immediately to the right without click-area overlap")
	_check(not drink_tray.get_global_rect().intersects(pancake_tray.get_global_rect()), "the two finished trays do not compete for pointer input")
	_check(drink_sources.size() == 1, "packaged-drink station exposes one juice tray source")
	for source_variant in drink_sources:
		var source := source_variant as Control
		_check(source != null and source.position.is_equal_approx(Vector2.ZERO) and source.size.is_equal_approx(drink_tray.size), "the runtime juice source fills the normalized tray rectangle")

	var empty_texture := load("res://resources/art/products/orange_juice/yinpin-v1.png") as Texture2D
	for stock_count in range(1, 11):
		var stock_texture := drink_tray.call("_stock_texture_for", PRODUCT_ID, stock_count) as Texture2D
		_check(stock_texture != null and stock_texture.get_size() == empty_texture.get_size(), "juice restock frame %d keeps the common tray canvas" % stock_count)

	root.size = Vector2i(970, 455)
	await process_frame
	_check(drink_tray.size.is_equal_approx(pancake_tray.size), "the two tray sizes remain equal at the captured 970x455 window ratio")
	_check(is_equal_approx(drink_tray.global_position.y, pancake_tray.global_position.y), "the two trays remain horizontally aligned at the captured 970x455 window ratio")
	_check(is_equal_approx(drink_tray.global_position.x, pancake_tray.global_position.x + pancake_tray.size.x), "the two trays remain adjacent at the captured 970x455 window ratio")

	workstation.queue_free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("PACKAGED_DRINK_TRAY_LAYOUT_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("PACKAGED_DRINK_TRAY_LAYOUT_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
