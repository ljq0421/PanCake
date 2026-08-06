extends SceneTree

const PAGE_SCENE := preload("res://scenes/main/main_page_prototype.tscn")
const INITIAL_SCREENSHOT_PATH := "res://tmp/validation/main_page_prototype_initial_1920x1080.png"
const CLICKED_SCREENSHOT_PATH := "res://tmp/validation/main_page_prototype_clicked_1920x1080.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Main-page visual smoke must run without --headless")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	var page := PAGE_SCENE.instantiate()
	root.add_child(page)
	for _frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var initial_output := ProjectSettings.globalize_path(INITIAL_SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(initial_output.get_base_dir())
	var initial_image := root.get_texture().get_image()
	if initial_image.save_png(initial_output) != OK or initial_image.get_size() != Vector2i(1920, 1080):
		push_error("Could not capture the initial 1920x1080 main-page prototype")
		quit(1)
		return
	var batter_source := page.get_node("Worktop/BatterSourceButton") as Button
	_click(batter_source)
	await process_frame
	if StringName(page.get("last_clicked_tool")) != &"batter_ladle":
		push_error("Real GUI click did not reach the pancake batter source")
		quit(1)
		return
	var dim_sum := page.get_node("Worktop/DimSumStation") as Button
	_click(dim_sum)
	await process_frame
	if StringName(page.get("selected_station_id")) != &"dim_sum":
		push_error("Real GUI click did not reach the dim-sum station")
		quit(1)
		return
	var locked_slot := page.get_node("MaterialDock/Slots/RedBean") as Button
	_click(locked_slot)
	await process_frame
	if StringName(page.get("last_clicked_slot")) != &"red_bean":
		push_error("Real GUI click did not reach the material dock")
		quit(1)
		return
	await RenderingServer.frame_post_draw
	var output_absolute := ProjectSettings.globalize_path(CLICKED_SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(output_absolute.get_base_dir())
	var image := root.get_texture().get_image()
	var save_error := image.save_png(output_absolute)
	if save_error != OK or image.get_size() != Vector2i(1920, 1080):
		push_error("Could not capture the 1920x1080 main-page prototype")
		quit(1)
		return
	print("MAIN_PAGE_PROTOTYPE_VISUAL_SMOKE_PASS")
	print("INITIAL_SCREENSHOT=%s" % initial_output)
	print("CLICKED_SCREENSHOT=%s" % output_absolute)
	page.queue_free()
	await process_frame
	quit(0)


func _click(control: Control) -> void:
	var center := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	root.push_input(motion)
	var pressed_event := InputEventMouseButton.new()
	pressed_event.button_index = MOUSE_BUTTON_LEFT
	pressed_event.pressed = true
	pressed_event.position = center
	pressed_event.global_position = center
	root.push_input(pressed_event)
	var released_event := InputEventMouseButton.new()
	released_event.button_index = MOUSE_BUTTON_LEFT
	released_event.pressed = false
	released_event.position = center
	released_event.global_position = center
	root.push_input(released_event)
