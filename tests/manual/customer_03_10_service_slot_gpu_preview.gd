extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const OUTPUT_DIR := "res://tmp/validation/customer_03_10_service_slot_v2_neutral_gpu"
const CASES := {
	&"customer_03": {"file": "customer_03_neutral_v2_qstyle.png", "region": Rect2(296, 194, 432, 938)},
	&"customer_04": {"file": "customer_04_neutral_v2_qstyle.png", "region": Rect2(230, 139, 564, 1161)},
	&"customer_05": {"file": "customer_05_neutral_v2_qstyle.png", "region": Rect2(281, 173, 461, 1011)},
	&"customer_06": {"file": "customer_06_neutral_v2_qstyle.png", "region": Rect2(273, 163, 472, 968)},
	&"customer_07": {"file": "customer_07_neutral_v2_qstyle.png", "region": Rect2(176, 165, 656, 1065)},
	&"customer_08": {"file": "customer_08_neutral_v2_qstyle.png", "region": Rect2(465, 77, 466, 966)},
	&"customer_09": {"file": "customer_09_neutral_v2_qstyle.png", "region": Rect2(287, 108, 548, 1222)},
	&"customer_10": {"file": "customer_10_neutral_v2_qstyle.png", "region": Rect2(399, 40, 612, 1074)},
}

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_failures.append("Customer service-slot preview must run without --headless")
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
	var service_slot := workstation.get_node_or_null("SafeArea/ServiceCustomer1") as Control if workstation != null else null
	var portrait := service_slot.get_node_or_null("Portrait") as TextureRect if service_slot != null else null
	if portrait == null:
		_failures.append("ServiceCustomer1/Portrait is missing")
		_finish()
		return
	workstation.set_process(false)
	for service_slot_name in [&"ServiceCustomer2", &"ServiceCustomer3", &"ServiceCustomer4", &"ServiceCustomer5"]:
		var other_slot := workstation.get_node_or_null("SafeArea/%s" % service_slot_name) as CanvasItem
		if other_slot != null:
			other_slot.visible = false
	service_slot.visible = true
	portrait.visible = true
	var order_panel := service_slot.get_node_or_null("OrderPanel") as CanvasItem
	if order_panel != null:
		order_panel.visible = false
	for customer_id in CASES:
		var expected: Dictionary = CASES[customer_id]
		portrait.texture = load("res://resources/art/customers/%s/%s_neutral_cropped.tres" % [customer_id, customer_id]) as Texture2D
		for _frame in 3:
			await process_frame
		var atlas_texture := portrait.texture as AtlasTexture
		_check(atlas_texture != null, "%s neutral AtlasTexture loads" % customer_id)
		if atlas_texture != null:
			_check(atlas_texture.region == expected["region"], "%s uses the approved portrait crop" % customer_id)
			_check(atlas_texture.atlas != null and atlas_texture.atlas.resource_path.ends_with(expected["file"]), "%s resolves its selected v2 qstyle PNG" % customer_id)
		await RenderingServer.frame_post_draw
		var path := ProjectSettings.globalize_path("%s/%s_neutral_1920x1080.png" % [OUTPUT_DIR, customer_id])
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var image := root.get_texture().get_image()
		_check(image.save_png(path) == OK and image.get_size() == Vector2i(1920, 1080), "%s captures a real 1920x1080 service-slot frame" % customer_id)
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CUSTOMER_03_10_SERVICE_SLOT_GPU_PREVIEW_PASS")
		quit(0)
		return
	printerr("CUSTOMER_03_10_SERVICE_SLOT_GPU_PREVIEW_FAIL\n" + "\n".join(_failures))
	quit(1)
