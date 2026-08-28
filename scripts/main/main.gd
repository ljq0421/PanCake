extends Control

const SETTINGS_PANEL_SCRIPT := preload("res://scripts/ui/game_settings_panel.gd")
const UI_SCALE_APPLIER := preload("res://scripts/ui/ui_scale_applier.gd")

@onready var pause_dim: ColorRect = %PauseDim
@onready var pause_panel: PanelContainer = %PausePanel
@onready var resume_button: Button = %ResumeButton
@onready var end_business_button: Button = %EndBusinessButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var workstation: Workstation = $Workstation

var _settings_button: Button
var _shared_settings_panel: GameSettingsPanel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	resume_button.pressed.connect(_resume_game)
	end_business_button.pressed.connect(_end_business_day)
	main_menu_button.pressed.connect(_return_to_start_menu)
	_settings_button = Button.new()
	_settings_button.text = "设置"
	_settings_button.custom_minimum_size = Vector2(0, 54)
	_settings_button.add_theme_font_size_override(&"font_size", 24)
	$PausePanel/Content.add_child(_settings_button)
	$PausePanel/Content.move_child(_settings_button, main_menu_button.get_index())
	_settings_button.pressed.connect(_open_settings)
	_shared_settings_panel = SETTINGS_PANEL_SCRIPT.new()
	add_child(_shared_settings_panel)
	_shared_settings_panel.closed.connect(_on_settings_closed)
	workstation.daily_bill_closed.connect(_return_to_start_menu)
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("set_business_paused"):
		session.call("set_business_paused", false)
	if session != null and session.has_method("commit_scene_binding_save_batch"):
		session.call("commit_scene_binding_save_batch")
	if session != null:
		var settings_signal := Signal(session, &"settings_changed")
		if not settings_signal.is_connected(_apply_ui_settings):
			settings_signal.connect(_apply_ui_settings)
		_apply_ui_settings(Dictionary(session.call("get_settings")))
	_log_info(&"bootstrap", "M0 main scene started with Mobile renderer")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause_game"):
		if _shared_settings_panel != null and _shared_settings_panel.is_open():
			_shared_settings_panel.close_without_saving()
			get_viewport().set_input_as_handled()
			return
		if not get_tree().paused and _workstation_has_blocking_modal():
			get_viewport().set_input_as_handled()
			return
		_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


func _set_paused(paused: bool) -> void:
	if paused and _workstation_has_blocking_modal():
		return
	get_tree().paused = paused
	pause_dim.visible = paused
	pause_panel.visible = paused
	if paused:
		resume_button.grab_focus()
	else:
		get_viewport().gui_release_focus()


func _workstation_has_blocking_modal() -> bool:
	return (
		workstation != null
		and workstation.has_method(&"is_blocking_modal_open")
		and bool(workstation.call(&"is_blocking_modal_open"))
	)


func _resume_game() -> void:
	_set_paused(false)


func _open_settings() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return
	pause_panel.visible = false
	_shared_settings_panel.open_with_session(session)


func _on_settings_closed(_saved: bool) -> void:
	pause_panel.visible = true
	_settings_button.grab_focus()


func _apply_ui_settings(settings: Dictionary) -> void:
	UI_SCALE_APPLIER.apply_to(pause_panel, float(settings.get("ui_scale", 100.0)))


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


func _log_info(category: StringName, message: String) -> void:
	var logger := get_node_or_null("/root/AppLog")
	if logger != null and logger.has_method("info"):
		logger.info(category, message)
	else:
		print("[ProjectCake][%s] %s" % [category, message])
