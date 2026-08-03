extends Control

const GAME_SCENE := "res://scenes/main/main.tscn"

@onready var continue_button: Button = %ContinueButton
@onready var new_game_button: Button = %NewGameButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var resume_label: Label = %ResumeLabel
@onready var settings_overlay: Control = %SettingsOverlay
@onready var master_slider: HSlider = %MasterSlider
@onready var master_value_label: Label = %MasterValueLabel
@onready var sfx_slider: HSlider = %SfxSlider
@onready var sfx_value_label: Label = %SfxValueLabel
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var settings_cancel_button: Button = %SettingsCancelButton
@onready var settings_save_button: Button = %SettingsSaveButton
@onready var new_game_overlay: Control = %NewGameOverlay
@onready var new_game_cancel_button: Button = %NewGameCancelButton
@onready var new_game_confirm_button: Button = %NewGameConfirmButton

var _session: Node


func _ready() -> void:
	_session = get_node_or_null("/root/GameSession")
	if _session == null:
		push_error("GameSession autoload is required by the start menu")
		continue_button.disabled = true
		new_game_button.disabled = true
		return
	continue_button.pressed.connect(_continue_game)
	new_game_button.pressed.connect(_request_new_game)
	settings_button.pressed.connect(_open_settings)
	quit_button.pressed.connect(_quit_game)
	settings_cancel_button.pressed.connect(_close_settings)
	settings_save_button.pressed.connect(_save_settings)
	new_game_cancel_button.pressed.connect(_close_new_game_confirmation)
	new_game_confirm_button.pressed.connect(_start_new_game)
	master_slider.value_changed.connect(_on_master_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	_refresh_save_state()
	call_deferred("_focus_primary_action")


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if settings_overlay.visible:
		_close_settings()
	elif new_game_overlay.visible:
		_close_new_game_confirmation()
	else:
		quit_button.grab_focus()
	get_viewport().set_input_as_handled()


func _refresh_save_state() -> void:
	continue_button.disabled = not bool(_session.call("has_save"))
	resume_label.text = str(_session.call("resume_summary"))


func _focus_primary_action() -> void:
	if bool(_session.call("has_save")):
		continue_button.grab_focus()
	else:
		new_game_button.grab_focus()


func _continue_game() -> void:
	if bool(_session.call("continue_game")):
		_open_game_scene()
	else:
		_refresh_save_state()


func _request_new_game() -> void:
	if not bool(_session.call("has_save")):
		_start_new_game()
		return
	new_game_overlay.visible = true
	new_game_confirm_button.grab_focus()


func _start_new_game() -> void:
	_session.call("begin_new_game")
	_open_game_scene()


func _open_game_scene() -> void:
	var error := get_tree().change_scene_to_file(GAME_SCENE)
	if error != OK:
		push_error("Could not open gameplay scene: %s" % error_string(error))


func _open_settings() -> void:
	var current: Dictionary = _session.call("get_settings")
	master_slider.value = float(current.master_volume)
	sfx_slider.value = float(current.sfx_volume)
	fullscreen_check.button_pressed = bool(current.fullscreen)
	_update_volume_labels()
	settings_overlay.visible = true
	master_slider.grab_focus()


func _close_settings() -> void:
	settings_overlay.visible = false
	settings_button.grab_focus()


func _save_settings() -> void:
	_session.call("save_settings", master_slider.value, sfx_slider.value, fullscreen_check.button_pressed)
	_close_settings()


func _on_master_volume_changed(_value: float) -> void:
	_update_volume_labels()


func _on_sfx_volume_changed(_value: float) -> void:
	_update_volume_labels()


func _update_volume_labels() -> void:
	master_value_label.text = "%d%%" % roundi(master_slider.value)
	sfx_value_label.text = "%d%%" % roundi(sfx_slider.value)


func _close_new_game_confirmation() -> void:
	new_game_overlay.visible = false
	new_game_button.grab_focus()


func _quit_game() -> void:
	get_tree().quit()
