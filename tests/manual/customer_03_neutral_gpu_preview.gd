extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const SCREENSHOT_PATH := "res://tmp/validation/customer_03_neutral_v2_qstyle_cropped_gpu_1920x1080.png"
const EXPECTED_REGION := Rect2(296, 194, 432, 938)

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
	var service_slot := workstation.get_node_or_null("SafeArea/ServiceCustomer1") as Control
	var portrait := service_slot.get_node_or_null("Portrait") as TextureRect if service_slot != null else null
	if portrait == null:
		_failures.append("ServiceCustomer1/Portrait is missing")
		_finish()
		return
	for service_slot_name in [&"ServiceCustomer2", &"ServiceCustomer3", &"ServiceCustomer4", &"ServiceCustomer5"]:
		var other_slot := workstation.get_node_or_null("SafeArea/%s" % service_slot_name) as CanvasItem
		if other_slot != null:
			other_slot.visible = false
	service_slot.visible = true
	portrait.visible = true
	portrait.texture = load("res://resources/art/customers/customer_03/customer_03_neutral_cropped.tres") as Texture2D
	var order_panel := service_slot.get_node_or_null("OrderPanel") as CanvasItem
	if order_panel != null:
		order_panel.visible = false
	for _frame in 3:
		await process_frame
	_check(portrait != null and portrait.texture != null, "customer_03 neutral portrait loads in the real workstation")
	if portrait != null and portrait.texture != null:
		_check(portrait.texture.resource_path.ends_with("customer_03_neutral_cropped.tres"), "runtime uses the customer_03 neutral AtlasTexture")
		var atlas := portrait.texture.get("atlas") as Texture2D
		_check(atlas != null and atlas.resource_path.ends_with("customer_03_neutral_v2_qstyle.png"), "AtlasTexture resolves the selected v2 qstyle PNG")
		_check(portrait.texture.get("region") == EXPECTED_REGION, "AtlasTexture uses the approved half-body crop")
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
		print("CUSTOMER_03_NEUTRAL_GPU_PREVIEW_PASS")
		quit(0)
		return
	printerr("CUSTOMER_03_NEUTRAL_GPU_PREVIEW_FAIL\n" + "\n".join(_failures))
	quit(1)
