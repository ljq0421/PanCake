extends Control

@onready var pause_panel: PanelContainer = %PausePanel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_log_info(&"bootstrap", "M0 main scene started with Mobile renderer")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause_game"):
		get_tree().paused = not get_tree().paused
		pause_panel.visible = get_tree().paused
		get_viewport().set_input_as_handled()


func _log_info(category: StringName, message: String) -> void:
	var logger := get_node_or_null("/root/AppLog")
	if logger != null and logger.has_method("info"):
		logger.info(category, message)
	else:
		print("[ProjectCake][%s] %s" % [category, message])
