extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const OUTPUT_DIR := "res://tmp/validation/customer_05_states_v4_gpu"
const STATES := [&"impatient", &"satisfied", &"accepting_bag", &"paying_coins"]
const EXPECTED_REGIONS := [
	Rect2(536, 87, 451, 890),
	Rect2(535, 85, 452, 892),
	Rect2(534, 75, 461, 901),
	Rect2(440, 63, 627, 914),
]

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
	workstation.customer_queue.call("restore_active_customer", {}, &"customer_05")
	var portrait := workstation.get_node_or_null("SafeArea/CustomerPortrait") as TextureRect
	if portrait == null:
		_failures.append("CustomerPortrait is missing")
		_finish()
		return
	for index in STATES.size():
		var state: StringName = STATES[index]
		workstation.call("_set_customer_portrait_state", state)
		for _frame in 3:
			await process_frame
		_check(portrait.texture != null, "%s state loads a portrait texture" % state)
		if portrait.texture != null:
			_check(portrait.texture.resource_path.ends_with("customer_05_%s_cropped.tres" % state), "%s uses the existing customer_05 AtlasTexture" % state)
			var atlas := portrait.texture.get("atlas") as Texture2D
			_check(atlas != null and atlas.resource_path.ends_with("customer_05_%s_v4_chinese.png" % state), "%s AtlasTexture resolves the new v4 PNG" % state)
			_check(portrait.texture.get("region") == EXPECTED_REGIONS[index], "%s preserves the old crop and anchor contract" % state)
		await RenderingServer.frame_post_draw
		var path := ProjectSettings.globalize_path("%s/customer_05_%s_v4_chinese_1920x1080.png" % [OUTPUT_DIR, state])
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var image := root.get_texture().get_image()
		_check(image.save_png(path) == OK and image.get_size() == Vector2i(1920, 1080), "%s captures a real 1920x1080 GPU workstation frame" % state)
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CUSTOMER_05_STATES_GPU_PREVIEW_PASS")
		quit(0)
		return
	printerr("CUSTOMER_05_STATES_GPU_PREVIEW_FAIL\n" + "\n".join(_failures))
	quit(1)
