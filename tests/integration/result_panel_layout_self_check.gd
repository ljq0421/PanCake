extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const SCREENSHOT_PATH := "res://tmp/validation/result_panel_layout_1210x582.png"

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		root.size = Vector2i(1210, 582)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1210, 582))
	await process_frame
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	for _frame in 6:
		await process_frame
	var workstation := game.get_node("Workstation")
	workstation._populate_result({
		"score": 51.0,
		"feedback": "鸡蛋有些地方堆得太厚，画圈时再连续、均匀一些。",
		"dimensions": {
			"integrity": 100.0,
			"thickness": 0.0,
			"heat": 55.0,
			"egg": 54.0,
			"sauce": 10.0,
			"ingredients": 95.0,
			"fold": 2.0,
			"order": 76.0,
			"time": 100.0,
		},
		"tags": ["鸡蛋偏厚", "摊制不均"],
	})
	workstation._order_summary_visible = true
	workstation._result_detail_open = false
	workstation._refresh_p1_ui()
	workstation.summary_view_button.pressed.emit()
	for _frame in 4:
		await process_frame

	var panel: Control = workstation.result_panel
	var panel_rect := panel.get_global_rect()
	var viewport_rect := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	_check(panel.is_visible_in_tree(), "view-order action opens the result panel")
	_check(viewport_rect.encloses(panel_rect), "the complete result panel remains inside the 1210x582 expanded viewport")
	for node_name in ["ResultTitleLabel", "ResultDetailLabel", "DimensionGrid", "ResultTagsLabel", "PaymentDisplay", "NextOrderButton"]:
		var control := workstation.get_node("%" + node_name) as Control
		_check(control.is_visible_in_tree(), "%s remains visible" % node_name)
		_check(panel_rect.encloses(control.get_global_rect()), "%s remains inside the result panel" % node_name)

	var station_artwork := workstation.get_node_or_null("FiveAreaInfrastructure/Stations") as CanvasItem
	_check(station_artwork != null, "formal three-area workstation content is present")
	if station_artwork != null:
		_check(
			panel.z_index > _maximum_effective_z_index(station_artwork),
			"result panel renders above every workstation foreground layer"
		)

	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var output_absolute := ProjectSettings.globalize_path(SCREENSHOT_PATH)
		DirAccess.make_dir_recursive_absolute(output_absolute.get_base_dir())
		var save_error := root.get_texture().get_image().save_png(output_absolute)
		_check(save_error == OK, "GPU validation screenshot was saved")

	game.queue_free()
	await process_frame
	if _failures.is_empty():
		print("RESULT_PANEL_LAYOUT_SELF_CHECK PASS")
		quit()
	else:
		for failure in _failures:
			push_error("FAIL: %s" % failure)
		quit(1)


func _maximum_effective_z_index(item: CanvasItem, parent_z := 0) -> int:
	var effective_z := item.z_index + parent_z if item.z_as_relative else item.z_index
	var maximum := effective_z
	for child in item.get_children():
		if child is CanvasItem:
			maximum = maxi(maximum, _maximum_effective_z_index(child as CanvasItem, effective_z))
	return maximum


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
