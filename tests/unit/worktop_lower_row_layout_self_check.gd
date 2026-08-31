extends SceneTree

const ARTWORK_SCENE := preload("res://scenes/gameplay/jianbing_stall_artwork.tscn")
const WORKSTATION_SCENE := preload("res://scenes/gameplay/four_area_workstation.tscn")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var artwork := ARTWORK_SCENE.instantiate()
	root.add_child(artwork)
	var worktop := artwork.get_node("PancakeWorktopHotspots") as Control
	_check_tool_source(worktop, &"BatterLadleSource", Rect2(977.0, 872.5, 206.0, 171.0))
	_check_tool_source(worktop, &"SpreaderSource", Rect2(1125.0, 878.0, 160.0, 160.0))

	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	await process_frame
	var holding_tray := workstation.get_node("FiveAreaInfrastructure/Stations/PancakeHoldingTray") as TextureButton
	_check(holding_tray.position.is_equal_approx(Vector2(1258.0, 875.0)), "finished tray uses the authored lower-row position")
	_check(holding_tray.size.is_equal_approx(Vector2(364.0, 204.0)), "moving the finished tray preserves its authored size and click surface")
	for source_index in range(1, 4):
		var source := holding_tray.get_node("PancakeHoldingSource%02d" % source_index) as Control
		_check(source != null and source.scale.is_equal_approx(Vector2(1.066666, 1.066666)) and source.z_index == source_index, "finished tray keeps stacked product hotspot %d at the authored scale and layer" % source_index)

	artwork.queue_free()
	workstation.queue_free()
	_finish()


func _check_tool_source(worktop: Control, source_name: StringName, expected_rect: Rect2) -> void:
	var source := worktop.get_node(str(source_name)) as Control
	var visual := source.get_node("Visual") as TextureRect
	var hotspot := source.get_node("HitButton") as Control
	_check(source.position.is_equal_approx(expected_rect.position) and source.size.is_equal_approx(expected_rect.size), "%s uses the authored lower-row rectangle" % source_name)
	_check(visual.get_global_rect().is_equal_approx(source.get_global_rect()), "%s artwork follows the moved parent" % source_name)
	_check(hotspot.get_global_rect().is_equal_approx(source.get_global_rect()), "%s click hotspot follows the moved parent" % source_name)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("WORKTOP_LOWER_ROW_LAYOUT_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("WORKTOP_LOWER_ROW_LAYOUT_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
