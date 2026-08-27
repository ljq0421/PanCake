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
@onready var loading_overlay: Control = %LoadingOverlay
@onready var loading_status_label: Label = %LoadingStatusLabel
@onready var loading_progress: ProgressBar = %LoadingProgress
@onready var loading_detail_label: Label = %LoadingDetailLabel

var _session: Node
var _loading := false
var _load_request_started := false
var _pending_new_game := false
var _loading_path := GAME_SCENE


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
	if event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed and event.alt_pressed and event.keycode == KEY_J:
		if _loading:
			get_viewport().set_input_as_handled()
			return
		var result := Dictionary(_session.call("open_soy_test_profile"))
		if bool(result.get("success", false)):
			_begin_game_load(false)
		else:
			resume_label.text = "豆浆测试档创建失败，请重试。"
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if _loading:
		get_viewport().set_input_as_handled()
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
	if not bool(_session.call("has_save")):
		_refresh_save_state()
		return
	_begin_game_load(false)


func _request_new_game() -> void:
	if not bool(_session.call("has_save")):
		_start_new_game()
		return
	new_game_overlay.visible = true
	new_game_confirm_button.grab_focus()


func _start_new_game() -> void:
	_begin_game_load(true)


func _begin_game_load(start_new_game: bool, path_override: String = "") -> void:
	if _loading:
		return
	_loading = true
	_load_request_started = false
	_pending_new_game = start_new_game
	_loading_path = path_override if not path_override.is_empty() else GAME_SCENE
	new_game_overlay.visible = false
	loading_status_label.text = "正在准备摊位…"
	loading_detail_label.text = "整理设备与顾客档案"
	loading_progress.value = 0.0
	loading_overlay.visible = true
	_set_menu_actions_disabled(true)
	call_deferred("_request_game_scene_after_frame")


func _request_game_scene_after_frame() -> void:
	await get_tree().process_frame
	if not _loading:
		return
	if not ResourceLoader.exists(_loading_path, "PackedScene"):
		_fail_game_load("摊位准备失败，请重试。")
		return
	var error := ResourceLoader.load_threaded_request(_loading_path, "PackedScene", true)
	if error != OK:
		_fail_game_load("摊位准备失败，请重试。")
		return
	_load_request_started = true


func _process(_delta: float) -> void:
	if not _loading or not _load_request_started:
		return
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(_loading_path, progress)
	if not progress.is_empty():
		var percent := clampf(float(progress[0]), 0.0, 1.0)
		loading_progress.value = percent * 100.0
		loading_detail_label.text = "已完成 %d%%" % roundi(percent * 100.0)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	if status != ResourceLoader.THREAD_LOAD_LOADED:
		_fail_game_load("摊位准备失败，请重试。")
		return
	var packed_scene := ResourceLoader.load_threaded_get(_loading_path) as PackedScene
	if packed_scene == null:
		_fail_game_load("摊位准备失败，请重试。")
		return
	_load_request_started = false
	if not bool(_session.call("begin_scene_binding_save_batch")):
		_fail_game_load("摊位状态正忙，请重试。")
		return
	if _pending_new_game:
		var result := Dictionary(_session.call("begin_new_game"))
		if not bool(result.get("success", false)):
			_fail_game_load("新游戏初始化失败，请重试。")
			return
	elif not bool(_session.call("has_save")):
		_fail_game_load("没有可继续的营业记录。")
		return
	elif not bool(_session.call("continue_game")):
		_fail_game_load("无法恢复营业记录，请重试。")
		return
	loading_progress.value = 100.0
	loading_detail_label.text = "准备完成"
	var error := get_tree().change_scene_to_packed(packed_scene)
	if error != OK:
		_fail_game_load("无法进入摊位，请重试。")
		push_error("Could not open gameplay scene: %s" % error_string(error))


func _fail_game_load(message: String) -> void:
	if _session != null and _session.has_method("rollback_scene_binding_save_batch"):
		_session.call("rollback_scene_binding_save_batch")
	_loading = false
	_load_request_started = false
	_pending_new_game = false
	loading_overlay.visible = false
	_set_menu_actions_disabled(false)
	_refresh_save_state()
	resume_label.text = message
	call_deferred("_focus_primary_action")


func _set_menu_actions_disabled(disabled: bool) -> void:
	continue_button.disabled = disabled or not bool(_session.call("has_save"))
	new_game_button.disabled = disabled
	settings_button.disabled = disabled
	quit_button.disabled = disabled
	new_game_cancel_button.disabled = disabled
	new_game_confirm_button.disabled = disabled


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
