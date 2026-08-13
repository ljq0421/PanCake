extends SceneTree

const OUTPUT_DIR := "res://tmp/validation/customer_19_states_v1_gpu_atlas"
const CUSTOMER_TEXTURES := {
	&"neutral": preload("res://resources/art/customers/customer_19/customer_19_neutral_cropped.tres"),
	&"impatient": preload("res://resources/art/customers/customer_19/customer_19_impatient_cropped.tres"),
	&"satisfied": preload("res://resources/art/customers/customer_19/customer_19_satisfied_cropped.tres"),
	&"accepting_bag": preload("res://resources/art/customers/customer_19/customer_19_accepting_bag_cropped.tres"),
	&"paying_coins": preload("res://resources/art/customers/customer_19/customer_19_paying_coins_cropped.tres"),
}

var _state: StringName = &"neutral"
var _failures: Array[String] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var state_index := args.find("--state")
	if state_index >= 0 and state_index + 1 < args.size():
		_state = StringName(args[state_index + 1])
	if not CUSTOMER_TEXTURES.has(_state):
		_failures.append("Unsupported customer_19 state: %s" % _state)
		_finish()
		return
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_failures.append("Atlas visual preview must run without --headless")
		_finish()
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(canvas)
	var backdrop := ColorRect.new()
	backdrop.color = Color("f5ead5")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(backdrop)
	var portrait := TextureRect.new()
	portrait.position = Vector2(850.0, 128.0)
	portrait.size = Vector2(220.0, 332.0)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = CUSTOMER_TEXTURES[_state]
	canvas.add_child(portrait)
	for _frame in 24:
		await process_frame
	await RenderingServer.frame_post_draw
	print("DISPLAY_SERVER=%s" % DisplayServer.get_name())
	print("RENDERING_METHOD=%s" % RenderingServer.get_current_rendering_method())
	print("VIDEO_ADAPTER=%s" % RenderingServer.get_video_adapter_name())
	_check(portrait.texture != null, "%s AtlasTexture is assigned to a live TextureRect" % _state)
	var path := ProjectSettings.globalize_path("%s/customer_19_%s_atlas_1920x1080.png" % [OUTPUT_DIR, _state])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var image := root.get_texture().get_image()
	_check(image.save_png(path) == OK and image.get_size() == Vector2i(1920, 1080), "%s captures a live D3D12 AtlasTexture frame" % _state)
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CUSTOMER_19_ATLAS_GPU_VISUAL_PREVIEW_PASS state=%s" % _state)
		quit(0)
		return
	printerr("CUSTOMER_19_ATLAS_GPU_VISUAL_PREVIEW_FAIL\n" + "\n".join(_failures))
	quit(1)
