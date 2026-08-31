extends SceneTree

const SCENE := preload("res://scenes/main/noodle_shop_main.tscn")
const CATALOG := preload("res://scripts/data/five_area_catalog.gd")

const CAPTURES := [
	{"size": Vector2i(1920, 1080), "path": "res://tmp/validation/noodle_shop_result_gpu_1920x1080.png"},
	{"size": Vector2i(1280, 720), "path": "res://tmp/validation/noodle_shop_result_gpu_1280x720.png"},
]

var _failures: Array[String] = []
var _session: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("NOODLE_SHOP_GPU_SMOKE_FAIL\nGPU smoke must run without --headless")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	_session = root.get_node_or_null("GameSession")
	_check(_session != null, "campaign session exists for noodle GPU smoke")
	if _session == null:
		_finish(PackedStringArray())
		return
	_session.set("_active_save_path", "user://noodle_shop_gpu_smoke.json")
	_session.call("begin_new_game")
	_unlock_noodle_chapter()
	_session.call("select_chapter", _session.NOODLE_CHAPTER_ID)
	var scene := SCENE.instantiate()
	root.add_child(scene)
	for _frame in 6:
		await process_frame
	var station := scene.get_node("Workstation") as NoodleShopWorkstation
	var gesture := station.get_node("GestureSurface") as NoodleGestureSurface
	var begin_button := station.get_node("ActionsPanel/Scroll/Actions/BeginButton") as Button
	var lift_button := station.get_node("ActionsPanel/Scroll/Actions/CookRow/LiftButton") as Button
	var bowl_button := station.get_node("ActionsPanel/Scroll/Actions/CookRow/BowlButton") as Button
	var broth_button := station.get_node("ActionsPanel/Scroll/Actions/BrothRow/ClearBrothButton") as Button
	var topping_button := station.get_node("ActionsPanel/Scroll/Actions/ToppingGrid/ScallionButton") as Button
	var serve_button := station.get_node("ActionsPanel/Scroll/Actions/ServeButton") as Button
	_check(gesture != null and not begin_button.disabled, "tutorial renders an interactive dough, pot and start action")
	_check(
		gesture.has_formal_art()
		and (station.get_node("Backdrop") as TextureRect).texture.resource_path == "res://resources/art/noodle_shop/background/noodle_shop_interior_background-v1.png",
		"runtime binds the authored noodle interior and all workstation art layers",
	)
	await _click_control(begin_button)
	for _stroke in 6:
		await _perform_shaving_gesture(gesture)
	var production := Dictionary(Dictionary(_session.call("noodle_shop_snapshot")).get("production", {}))
	_check(Array(production.get("batches", [])).size() == 6, "six real pointer gestures are captured at the pot mouth")
	await create_timer(3.0).timeout
	await _click_control(lift_button)
	await create_timer(0.6).timeout
	production = Dictionary(Dictionary(_session.call("noodle_shop_snapshot")).get("production", {}))
	_check(StringName(production.get("state", &"")) == &"lifted" and float(production.get("drain_seconds", 0.0)) >= 0.4, "basket lift enters the visible drain phase")
	await _click_control(bowl_button)
	await _click_control(broth_button)
	await _click_control(topping_button)
	await _click_control(serve_button)
	var result_panel := station.get_node("ResultPanel") as Control
	_check(result_panel.visible and "分" in (station.get_node("ResultPanel/Layout/ResultTitle") as Label).text, "broth, topping and delivery open the scored result panel")
	_check(
		(station.get_node("KnifeAudio") as AudioStreamPlayer).stream != null
		and (station.get_node("BasketAudio") as AudioStreamPlayer).stream != null
		and (station.get_node("ServeAudio") as AudioStreamPlayer).stream != null
		and (station.get_node("PaymentAudio") as AudioStreamPlayer).stream != null,
		"knife, basket, serving and payment feedback have authored audio streams",
	)
	var output_paths := PackedStringArray()
	for capture_value in CAPTURES:
		var capture := Dictionary(capture_value)
		var capture_size := Vector2i(capture.get("size", Vector2i.ZERO))
		DisplayServer.window_set_size(capture_size)
		for _frame in 4:
			await process_frame
		var visible_rect := root.get_visible_rect()
		_check(visible_rect.encloses(result_panel.get_global_rect()), "result panel stays inside the %dx%d viewport" % [capture_size.x, capture_size.y])
		_check(visible_rect.encloses(gesture.get_global_rect()), "gesture worktop stays inside the %dx%d viewport" % [capture_size.x, capture_size.y])
		var output_absolute := ProjectSettings.globalize_path(str(capture.get("path", "")))
		DirAccess.make_dir_recursive_absolute(output_absolute.get_base_dir())
		var image := root.get_texture().get_image()
		var save_error := image.save_png(output_absolute)
		_check(save_error == OK and image.get_size() == capture_size, "noodle result captures at %dx%d" % [capture_size.x, capture_size.y])
		output_paths.append(output_absolute)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	for _frame in 3:
		await process_frame
	await _click_control(station.get_node("ResultPanel/Layout/ResultCloseButton") as Button)
	await _click_control(station.get_node("ActionsPanel/Scroll/Actions/CollectButton") as Button)
	_check(int(Dictionary(_session.call("noodle_shop_snapshot")).get("coins", -1)) == 10, "real result-to-payment flow collects the tutorial price")
	scene.queue_free()
	await process_frame
	_finish(output_paths)


func _perform_shaving_gesture(control: Control) -> void:
	var start := control.get_global_transform_with_canvas() * Vector2(260.0, 340.0)
	var finish := control.get_global_transform_with_canvas() * Vector2(820.0, 285.0)
	await _move_pointer(start)
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = start
	pressed.global_position = start
	root.push_input(pressed, true)
	await process_frame
	for step in range(1, 7):
		await create_timer(0.125).timeout
		await _move_pointer(start.lerp(finish, float(step) / 6.0))
	var released := InputEventMouseButton.new()
	released.button_index = MOUSE_BUTTON_LEFT
	released.pressed = false
	released.position = finish
	released.global_position = finish
	root.push_input(released, true)
	await process_frame


func _click_control(control: Control) -> void:
	var position := control.get_global_transform_with_canvas() * (control.size * 0.5)
	await _move_pointer(position)
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = position
	pressed.global_position = position
	root.push_input(pressed, true)
	await process_frame
	var released := InputEventMouseButton.new()
	released.button_index = MOUSE_BUTTON_LEFT
	released.pressed = false
	released.position = position
	released.global_position = position
	root.push_input(released, true)
	await process_frame


func _move_pointer(position: Vector2) -> void:
	var logical_size := root.get_visible_rect().size
	var window_size := Vector2(DisplayServer.window_get_size())
	var window_position := position
	if logical_size.x > 0.0 and logical_size.y > 0.0:
		window_position *= window_size / logical_size
	Input.warp_mouse(window_position)
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion, true)
	await process_frame


func _unlock_noodle_chapter() -> void:
	var progression: RefCounted = _session.call("progression_service")
	var unlocked_areas := {}
	var mastery := {}
	var mastery_details := {}
	var tutorials := {}
	for area_id in CATALOG.AREA_IDS:
		unlocked_areas[area_id] = true
		tutorials[area_id] = true
		var qualified := 8 if area_id == &"area.pancake" else 4
		var a_grade := 2 if area_id == &"area.pancake" else 1
		mastery[area_id] = qualified
		mastery_details[area_id] = {"qualified": qualified, "a_grade": a_grade}
	progression.set("unlocked_area_ids", unlocked_areas)
	progression.set("tutorial_completed_area_ids", tutorials)
	progression.set("area_mastery", mastery)
	progression.set("area_mastery_details", mastery_details)
	progression.set("day_open", false)
	_session.set("_save_data", Dictionary(_session.get("_save_data")).merged({"day_open": false}, true))
	_session.call("_sync_progression_to_save")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish(output_paths: PackedStringArray) -> void:
	if _failures.is_empty():
		print("NOODLE_SHOP_GPU_SMOKE_PASS")
		for output_path in output_paths:
			print("NOODLE_SHOP_SCREENSHOT=%s" % output_path)
		quit(0)
		return
	printerr("NOODLE_SHOP_GPU_SMOKE_FAIL\n" + "\n".join(_failures))
	quit(1)
