extends SceneTree

const SCENE := preload("res://scenes/gameplay/cartoon_breakfast_workstation.tscn")
const CAPTURE_ROOT := "res://tmp/validation/cartoon_breakfast"
const STATES := [
	{"name": "initial", "areas": [&"area.pancake"], "texture": "xiaoliao-1.png"},
	{"name": "youtiao_only", "areas": [&"area.pancake", &"area.youtiao"], "texture": "zhaguo-1.png"},
	{"name": "drinks_only", "areas": [&"area.pancake", &"area.fresh_soy_milk", &"area.packaged_drink"], "texture": "doujiang-2.png"},
	{"name": "all_unlocked", "areas": [&"area.pancake", &"area.youtiao", &"area.fresh_soy_milk", &"area.packaged_drink"], "texture": "shebei-2.png"},
]
const SIZES := [Vector2i(1920, 1080), Vector2i(1280, 720)]

var _failures: Array[String] = []
var _outputs: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("CARTOON_BREAKFAST_LAYOUT_GPU_SMOKE_FAIL\nGPU mode required")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var session := root.get_node_or_null("GameSession")
	if session == null:
		_check(false, "GameSession is available")
		_finish()
		return
	session.call("begin_new_game")
	var customer_item := {
		"area_id": &"area.pancake",
		"product_id": &"product.pancake.custom",
		"quantity": 1,
		"ingredient_ids": PackedStringArray(),
		"sauce_ids": PackedStringArray(),
	}
	for customer_index in 4:
		var opened := Dictionary(session.call("open_formal_order", [customer_item.duplicate(true)], {"source": &"cartoon_layout_gpu_smoke", "patience_seconds": 120.0}))
		_check(bool(opened.get("success", false)), "customer %d opens in one of the four service slots" % (customer_index + 1))
	var workstation := SCENE.instantiate() as CartoonBreakfastWorkstation
	root.add_child(workstation)
	for _frame in range(6):
		await process_frame

	for state_value in STATES:
		var state := Dictionary(state_value)
		_apply_state(session, workstation, Array(state.get("areas", [])))
		for size_value in SIZES:
			var capture_size := Vector2i(size_value)
			DisplayServer.window_set_size(capture_size)
			for _frame in range(5):
				await process_frame
			_check(workstation.cartoon_artwork.texture.resource_path.ends_with(str(state.get("texture", ""))), "%s selects its approved art plate" % state.get("name", "state"))
			_check(workstation.cartoon_artwork.mouse_filter == Control.MOUSE_FILTER_IGNORE and workstation.fryer_state_artwork.mouse_filter == Control.MOUSE_FILTER_IGNORE, "decorative art remains pointer-transparent at %s" % capture_size)
			await RenderingServer.frame_post_draw
			var path := "%s/%s_%dx%d.png" % [CAPTURE_ROOT, state.get("name", "state"), capture_size.x, capture_size.y]
			var absolute := ProjectSettings.globalize_path(path)
			DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
			var image := root.get_texture().get_image()
			_check(image.save_png(absolute) == OK and image.get_size() == capture_size and image.get_used_rect().has_area(), "%s captures at %s" % [state.get("name", "state"), capture_size])
			_outputs.append(absolute)

	workstation.queue_free()
	await process_frame
	_finish()


func _apply_state(session: Node, workstation: CartoonBreakfastWorkstation, area_values: Array) -> void:
	var areas := {}
	for area_id in area_values:
		areas[StringName(area_id)] = true
	var progression := session.call("progression_service") as RefCounted
	progression.set("unlocked_area_ids", areas)
	workstation.call("apply_progression_effects", progression.call("snapshot"))
	workstation.call("_refresh_cartoon_presentation", true)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CARTOON_BREAKFAST_LAYOUT_GPU_SMOKE_PASS")
		for output in _outputs:
			print("CARTOON_BREAKFAST_SCREENSHOT=%s" % output)
		quit(0)
		return
	printerr("CARTOON_BREAKFAST_LAYOUT_GPU_SMOKE_FAIL\n" + "\n".join(_failures))
	quit(1)
