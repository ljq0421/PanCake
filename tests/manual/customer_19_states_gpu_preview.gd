extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const OUTPUT_DIR := "res://tmp/validation/customer_19_states_v1_gpu_retry"
const STATES := [&"neutral", &"impatient", &"satisfied", &"accepting_bag", &"paying_coins"]
const EXPECTED_FILES := {
	&"neutral": "customer_19_neutral_v1_keyclean.png",
	&"impatient": "customer_19_impatient_v1.png",
	&"satisfied": "customer_19_satisfied_v1.png",
	&"accepting_bag": "customer_19_accepting_bag_v1.png",
	&"paying_coins": "customer_19_paying_coins_v1.png",
}
const EXPECTED_REGIONS := {
	&"neutral": Rect2(533, 89, 459, 851),
	&"impatient": Rect2(538, 80, 445, 857),
	&"satisfied": Rect2(551, 91, 434, 813),
	&"accepting_bag": Rect2(513, 67, 492, 907),
	&"paying_coins": Rect2(438, 89, 599, 846),
}

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_failures.append("Customer state preview must run without --headless")
		_finish()
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	print("DISPLAY_SERVER=%s" % DisplayServer.get_name())
	print("RENDERING_METHOD=%s" % RenderingServer.get_current_rendering_method())
	print("VIDEO_ADAPTER=%s" % RenderingServer.get_video_adapter_name())
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
	workstation.customer_queue.call("restore_active_customer", {}, &"customer_19")
	var portrait := workstation.get_node_or_null("SafeArea/CustomerPortrait") as TextureRect
	if portrait == null:
		_failures.append("CustomerPortrait is missing")
		_finish()
		return
	for node_path in [&"SafeArea/OrderCard", &"SafeArea/TutorialGuideOverlay", &"SafeArea/ServiceCustomer1", &"SafeArea/ServiceCustomer2", &"SafeArea/ServiceCustomer3"]:
		var node := workstation.get_node_or_null(NodePath(node_path)) as CanvasItem
		if node != null:
			node.visible = false
	portrait.visible = true
	portrait.modulate = Color.WHITE
	for state in STATES:
		workstation.call("_set_customer_portrait_state", state)
		for _frame in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		_check(portrait.texture != null and portrait.texture.resource_path.ends_with("customer_19_%s_cropped.tres" % state), "%s loads customer_19 AtlasTexture" % state)
		if portrait.texture != null:
			var atlas := portrait.texture.get("atlas") as Texture2D
			_check(atlas != null and atlas.resource_path.ends_with(String(EXPECTED_FILES[state])), "%s resolves its final PNG" % state)
			_check(portrait.texture.get("region") == EXPECTED_REGIONS[state], "%s preserves its verified crop region" % state)
		await RenderingServer.frame_post_draw
		var path := ProjectSettings.globalize_path("%s/customer_19_%s_v1_1920x1080.png" % [OUTPUT_DIR, state])
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var image := root.get_texture().get_image()
		_check(image.save_png(path) == OK and image.get_size() == Vector2i(1920, 1080), "%s captures a real 1920x1080 GPU frame" % state)
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CUSTOMER_19_STATES_GPU_PREVIEW_PASS")
		quit(0)
		return
	printerr("CUSTOMER_19_STATES_GPU_PREVIEW_FAIL\n" + "\n".join(_failures))
	quit(1)
