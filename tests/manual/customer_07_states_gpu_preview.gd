extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const OUTPUT_DIR := "res://tmp/validation/customer_07_states_v4_colorlocked_gpu"
const STATES := [
	{
		"name": &"neutral",
		"atlas": "customer_07_neutral_v4_chinese.png",
		"region": Rect2(489, 110, 541, 867),
	},
	{
		"name": &"impatient",
		"atlas": "customer_07_impatient_v4_colorlocked.png",
		"region": Rect2(489, 110, 540, 867),
	},
	{
		"name": &"satisfied",
		"atlas": "customer_07_satisfied_v4_colorlocked.png",
		"region": Rect2(489, 110, 540, 867),
	},
	{
		"name": &"accepting_bag",
		"atlas": "customer_07_accepting_bag_v4_colorlocked.png",
		"region": Rect2(467, 85, 593, 906),
	},
	{
		"name": &"paying_coins",
		"atlas": "customer_07_paying_coins_v4_colorlocked.png",
		"region": Rect2(398, 79, 702, 884),
	},
]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_failures.append("Customer states preview must run without --headless")
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
	workstation.customer_queue.call("restore_active_customer", {}, &"customer_07")
	var portrait := workstation.get_node_or_null("SafeArea/CustomerPortrait") as TextureRect
	if portrait == null:
		_failures.append("CustomerPortrait is missing")
		_finish()
		return
	for state_data in STATES:
		var state: StringName = state_data["name"]
		workstation.call("_set_customer_portrait_state", state)
		for _frame in 3:
			await process_frame
		_check(portrait.texture != null, "%s portrait loads in the real workstation" % state)
		if portrait.texture != null:
			_check(portrait.texture.resource_path.ends_with("customer_07_%s_cropped.tres" % state), "%s uses the customer_07 runtime AtlasTexture" % state)
			_check(portrait.texture.region == state_data["region"], "%s preserves the old Atlas crop and anchor" % state)
			var atlas := portrait.texture.get("atlas") as Texture2D
			_check(atlas != null and atlas.resource_path.ends_with(state_data["atlas"]), "%s resolves the expected v4 PNG" % state)
		await RenderingServer.frame_post_draw
		var path := ProjectSettings.globalize_path("%s/customer_07_%s_v4_gpu_1920x1080.png" % [OUTPUT_DIR, state])
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
		print("CUSTOMER_07_STATES_GPU_PREVIEW_PASS")
		quit(0)
		return
	printerr("CUSTOMER_07_STATES_GPU_PREVIEW_FAIL\n" + "\n".join(_failures))
	quit(1)
