extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const SCREENSHOT_PATH := "res://tmp/validation/customer_04_neutral_v4_chinese_gpu_1920x1080.png"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_failures.append("Customer neutral preview must run without --headless")
		_finish()
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	var session := root.get_node_or_null("GameSession")
	if session == null:
		_failures.append("GameSession is missing")
		_finish()
		return
	session.call("begin_new_game")
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	for _frame in 12:
		await process_frame
	var workstation := game.get_node_or_null("Workstation")
	if workstation == null:
		_failures.append("Workstation is missing")
		_finish()
		return
	workstation.set_process(false)
	workstation._formal_order_id = &""
	workstation.customer_queue.call("restore_active_customer", {}, &"customer_04")
	workstation.call("_set_customer_portrait_state", &"neutral")
	for _frame in 3:
		await process_frame
	var portrait := workstation.get_node_or_null("SafeArea/CustomerPortrait") as TextureRect
	_check(portrait != null and portrait.texture != null, "customer_04 neutral portrait loads in the real workstation")
	if portrait != null and portrait.texture != null:
		_check(portrait.texture.resource_path.ends_with("customer_04_neutral_cropped.tres"), "runtime uses the customer_04 neutral AtlasTexture")
		_check(portrait.texture.region == Rect2(508, 81, 505, 895), "AtlasTexture preserves the legacy customer_04 crop and anchor contract")
		var atlas := portrait.texture.get("atlas") as Texture2D
		_check(atlas != null and atlas.resource_path.ends_with("customer_04_neutral_v4_chinese.png"), "AtlasTexture resolves the new v4 neutral PNG")
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var image := root.get_texture().get_image()
	_check(image.save_png(path) == OK and image.get_size() == Vector2i(1920, 1080), "captured a real 1920x1080 GPU workstation frame")
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CUSTOMER_04_NEUTRAL_GPU_PREVIEW_PASS")
		quit(0)
		return
	printerr("CUSTOMER_04_NEUTRAL_GPU_PREVIEW_FAIL\n" + "\n".join(_failures))
	quit(1)
