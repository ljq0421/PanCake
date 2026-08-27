extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	await process_frame
	workstation.set_process(false)

	var overlay := workstation.tutorial_guide_overlay as Control
	var target := Control.new()
	target.position = Vector2(520.0, 360.0)
	target.size = Vector2(120.0, 72.0)
	target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	workstation.add_child(target)
	overlay.call("show_guide", target, "点击启动")

	var highlight := overlay.get_node("TargetHighlight") as Control
	var arrow := overlay.get_node("GuideArrow") as Control
	var bubble := overlay.get_node("GuideBubble") as Control
	var highlight_alpha_before := highlight.modulate.a
	overlay.call("_process", 0.2)
	var target_local_rect := Rect2(
		target.get_global_rect().position - overlay.get_global_rect().position,
		target.get_global_rect().size,
	)

	_check(overlay.visible and highlight.visible and arrow.visible and bubble.visible, "tutorial guide shows highlight, arrow, and callout together")
	_check(highlight.get_rect().encloses(target_local_rect), "tutorial highlight encloses the active material target")
	_check(not is_equal_approx(highlight.modulate.a, highlight_alpha_before), "tutorial highlight uses a visible breathing pulse")
	_check(
		overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and highlight.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and arrow.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and bubble.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"tutorial visuals never intercept gameplay input",
	)
	target.position = Vector2(1870.0, 360.0)
	target.size = Vector2(42.0, 72.0)
	overlay.call("show_guide", target, "这是一个较长的教程步骤提示，用来确认靠近屏幕边缘时文字气泡仍会完整显示，并且自动换行。")
	overlay.call("_process", 0.1)
	var overlay_bounds := Rect2(Vector2.ZERO, overlay.size)
	_check(overlay_bounds.encloses(bubble.get_rect()), "tutorial callout stays inside the viewport near an edge target")
	_check(bubble.size.y > 68.0, "long tutorial copy expands the callout height instead of clipping")

	overlay.call("hide_guide")
	_check(not overlay.visible, "tutorial visuals hide together when no target is active")
	workstation.queue_free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("TUTORIAL_GUIDE_HIGHLIGHT_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("TUTORIAL_GUIDE_HIGHLIGHT_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
