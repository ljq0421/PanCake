extends SceneTree

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var target := StagedProductDropTarget.new()
	var hint := Label.new()
	hint.name = "Hint"
	target.add_child(hint)
	root.add_child(target)
	await process_frame
	_check(not hint.visible, "waste-basket instructions stay hidden outside interaction")
	target.emit_signal("mouse_entered")
	_check(hint.visible and hint.text == "拖入报废\n长按清空鏊面", "hover reveals both waste-basket actions")
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	target.call("_gui_input", pressed)
	target.call("_process", 0.3)
	_check(hint.visible and "%" in hint.text, "holding the basket replaces instructions with clear progress")
	target.emit_signal("mouse_exited")
	_check(not hint.visible, "leaving the basket cancels and hides the transient instructions")
	target.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("STAGED_PRODUCT_DROP_TARGET_HINT_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("STAGED_PRODUCT_DROP_TARGET_HINT_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
