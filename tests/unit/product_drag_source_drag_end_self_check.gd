extends SceneTree

const SOURCE_SCRIPT := preload("res://scripts/ui/product_drag_source.gd")

var failures := PackedStringArray()
var ended_events: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var source := TextureButton.new()
	source.set_script(SOURCE_SCRIPT)
	root.add_child(source)
	await process_frame
	source.configure({"source_kind": &"steamer_input", "source_index": 0}, null, true)
	source.drag_ended.connect(func(source_ref: Dictionary, successful: bool): ended_events.append({"source_ref": source_ref, "successful": successful}))
	source.set("_native_drag_in_progress", true)
	source.notification(Control.NOTIFICATION_DRAG_END)
	source.notification(Control.NOTIFICATION_DRAG_END)
	_check(ended_events.size() == 1, "one native drag emits exactly one drag_ended event")
	if ended_events.size() == 1:
		_check(StringName(Dictionary(ended_events[0]["source_ref"]).get("source_kind", &"")) == &"steamer_input", "drag_ended preserves the source reference")
		_check(not bool(ended_events[0]["successful"]), "a synthetic drag end without a drop reports cancellation")
	source.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("PRODUCT_DRAG_SOURCE_DRAG_END_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("PRODUCT_DRAG_SOURCE_DRAG_END_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
