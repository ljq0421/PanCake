extends Control

@onready var workstation: NoodleShopWorkstation = %Workstation
@onready var pause_dim: ColorRect = %PauseDim
@onready var pause_panel: PanelContainer = %PausePanel
@onready var resume_button: Button = %ResumeButton
@onready var end_business_button: Button = %EndBusinessButton
@onready var main_menu_button: Button = %MainMenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	resume_button.pressed.connect(_resume_game)
	end_business_button.pressed.connect(_end_business_day)
	main_menu_button.pressed.connect(_return_to_start_menu)
	workstation.daily_bill_closed.connect(_return_to_start_menu)
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.call("set_business_paused", false)
		session.call("commit_scene_binding_save_batch")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause_game"):
		if not get_tree().paused and workstation.is_blocking_modal_open():
			get_viewport().set_input_as_handled()
			return
		_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	pause_dim.visible = paused
	pause_panel.visible = paused
	if paused:
		resume_button.grab_focus()


func _resume_game() -> void:
	_set_paused(false)


func _end_business_day() -> void:
	_set_paused(false)
	workstation.end_business_day_early()


func _return_to_start_menu() -> void:
	_set_paused(false)
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.call("mark_session_left")
	var error := get_tree().change_scene_to_file("res://scenes/main/start_menu.tscn")
	if error != OK:
		push_error("Could not return to start menu: %s" % error_string(error))
