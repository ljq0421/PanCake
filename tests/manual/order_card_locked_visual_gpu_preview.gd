extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const SCREENSHOT_PATH := "res://tmp/validation/order_card_locked_visual_gpu_1920x1080.png"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Order-card lock preview must run without --headless")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	var session := root.get_node_or_null("GameSession")
	if session == null:
		_failures.append("GameSession is missing")
		_finish("")
		return
	session.call("begin_new_game")
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	for _frame in 12:
		await process_frame
	var workstation := game.get_node("Workstation")
	workstation.set_process(false)
	workstation.call("_refresh_order_card_ui", {
		"items": [{
			"area_id": &"area.pancake",
			"product_id": &"product.pancake.custom",
			"quantity": 1,
			"ingredient_ids": [
				&"stock.pancake.egg",
				&"stock.pancake.baocui",
				&"stock.pancake.scallion",
			],
		}, {
			"area_id": &"area.packaged_drink",
			"product_id": &"product.packaged_drink.soy_milk",
			"quantity": 1,
			"temperature_mode": &"heated",
			"ingredient_ids": [],
		}],
		"metadata": {"base_coins": 8},
	}, 1.0)
	for _frame in 4:
		await process_frame
	var heat_icon := workstation.get_node("SafeArea/OrderCard/OrderIngredient04") as TextureRect
	var heat_background := workstation.get_node("SafeArea/OrderCard/OrderHeatBackground04") as Panel
	_check(heat_icon.visible and heat_icon.texture != null and heat_background.visible, "heated combo is visible in order-card slot 4")
	for station_name in [&"FreshSoyMilkStation", &"YoutiaoStation", &"PackagedDrinkStation", &"SteamerStation"]:
		var lock_cover := workstation.get_node("FiveAreaInfrastructure/Stations/%s/LockCover" % station_name) as Button
		_check(lock_cover.visible, "%s remains covered in the opening-day GPU frame" % station_name)
	await RenderingServer.frame_post_draw
	var output_absolute := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(output_absolute.get_base_dir())
	var image := root.get_texture().get_image()
	var save_error := image.save_png(output_absolute)
	_check(save_error == OK and image.get_size() == Vector2i(1920, 1080), "captured a real 1920x1080 GPU frame")
	_finish(output_absolute)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish(output_absolute: String) -> void:
	if _failures.is_empty():
		print("ORDER_CARD_LOCKED_VISUAL_GPU_PREVIEW_PASS")
		print("SCREENSHOT=%s" % output_absolute)
		quit(0)
		return
	printerr("ORDER_CARD_LOCKED_VISUAL_GPU_PREVIEW_FAIL\n" + "\n".join(_failures))
	quit(1)
