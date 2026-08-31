extends Control

const GAME_SCENE := "res://scenes/main/main.tscn"
const SETTINGS_PANEL_SCRIPT := preload("res://scripts/ui/game_settings_panel.gd")
const UI_SCALE_APPLIER := preload("res://scripts/ui/ui_scale_applier.gd")

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
@onready var shops_button: Button = %ShopsButton
@onready var chapter_overlay: Control = %ChapterOverlay
@onready var breakfast_shop_button: Button = %BreakfastShopButton
@onready var noodle_shop_button: Button = %NoodleShopButton
@onready var night_market_shop_button: Button = %NightMarketShopButton
@onready var breakfast_shop_status: Label = %BreakfastShopStatus
@onready var noodle_shop_status: Label = %NoodleShopStatus
@onready var night_market_shop_status: Label = %NightMarketShopStatus
@onready var chapter_hint: Label = %ChapterHint
@onready var chapter_close_button: Button = %ChapterCloseButton

var _session: Node
var _loading := false
var _load_request_started := false
var _pending_new_game := false
var _loading_path := GAME_SCENE
var _shared_settings_panel: GameSettingsPanel


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
	shops_button.pressed.connect(_open_chapter_select)
	breakfast_shop_button.pressed.connect(_select_breakfast_shop)
	noodle_shop_button.pressed.connect(_select_noodle_shop)
	night_market_shop_button.pressed.connect(_select_night_market_shop)
	chapter_close_button.pressed.connect(_close_chapter_select)
	quit_button.pressed.connect(_quit_game)
	new_game_cancel_button.pressed.connect(_close_new_game_confirmation)
	new_game_confirm_button.pressed.connect(_start_new_game)
	settings_overlay.visible = false
	chapter_overlay.visible = false
	_shared_settings_panel = SETTINGS_PANEL_SCRIPT.new()
	add_child(_shared_settings_panel)
	_shared_settings_panel.closed.connect(_on_shared_settings_closed)
	var settings_signal := Signal(_session, &"settings_changed")
	if not settings_signal.is_connected(_apply_ui_settings):
		settings_signal.connect(_apply_ui_settings)
	_apply_ui_settings(Dictionary(_session.call("get_settings")))
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
	if _shared_settings_panel != null and _shared_settings_panel.is_open():
		_close_settings()
	elif chapter_overlay.visible:
		_close_chapter_select()
	elif new_game_overlay.visible:
		_close_new_game_confirmation()
	else:
		quit_button.grab_focus()
	get_viewport().set_input_as_handled()


func _refresh_save_state() -> void:
	continue_button.disabled = not bool(_session.call("has_save"))
	shops_button.disabled = not bool(_session.call("has_save"))
	resume_label.text = str(_session.call("resume_summary"))
	_refresh_chapter_cards()


func _focus_primary_action() -> void:
	if bool(_session.call("has_save")):
		continue_button.grab_focus()
	else:
		new_game_button.grab_focus()


func _continue_game() -> void:
	if not bool(_session.call("has_save")):
		_refresh_save_state()
		return
	var active_id := StringName(_session.call("active_chapter_id"))
	_begin_game_load(false, str(_session.call("chapter_scene_path", active_id)))


func _request_new_game() -> void:
	if not bool(_session.call("has_save")):
		_start_new_game()
		return
	new_game_overlay.visible = true
	new_game_confirm_button.grab_focus()


func _start_new_game() -> void:
	_begin_game_load(true, GAME_SCENE)


func _open_chapter_select() -> void:
	if not bool(_session.call("has_save")):
		return
	_refresh_chapter_cards()
	chapter_overlay.visible = true
	var active_id := StringName(_session.call("active_chapter_id"))
	if active_id == _session.NOODLE_CHAPTER_ID:
		noodle_shop_button.grab_focus()
	elif active_id == _session.NIGHT_MARKET_CHAPTER_ID:
		night_market_shop_button.grab_focus()
	else:
		breakfast_shop_button.grab_focus()


func _close_chapter_select() -> void:
	chapter_overlay.visible = false
	shops_button.grab_focus()


func _select_breakfast_shop() -> void:
	_select_shop(_session.BREAKFAST_CHAPTER_ID)


func _select_noodle_shop() -> void:
	_select_shop(_session.NOODLE_CHAPTER_ID)


func _select_night_market_shop() -> void:
	_select_shop(_session.NIGHT_MARKET_CHAPTER_ID)


func _select_shop(chapter_id: StringName) -> void:
	var result := Dictionary(_session.call("select_chapter", chapter_id))
	if not bool(result.get("success", false)):
		chapter_hint.text = "请先结束当前店铺的营业日。" if StringName(result.get("reason", &"")) == &"business_day_open" else "这家铺子还没有解锁。"
		_refresh_chapter_cards()
		return
	chapter_overlay.visible = false
	_begin_game_load(false, str(result.get("scene_path", GAME_SCENE)))


func _refresh_chapter_cards() -> void:
	if _session == null or not bool(_session.call("has_save")):
		return
	var breakfast := Dictionary(_session.call("chapter_status", _session.BREAKFAST_CHAPTER_ID))
	var noodle := Dictionary(_session.call("chapter_status", _session.NOODLE_CHAPTER_ID))
	var night_market := Dictionary(_session.call("chapter_status", _session.NIGHT_MARKET_CHAPTER_ID))
	var active_id := StringName(_session.call("active_chapter_id"))
	var active_status := breakfast
	if active_id == _session.NOODLE_CHAPTER_ID:
		active_status = noodle
	elif active_id == _session.NIGHT_MARKET_CHAPTER_ID:
		active_status = night_market
	var blocks_switch := bool(active_status.get("day_open", false))
	breakfast_shop_button.text = "继续煎饼铺" if active_id == _session.BREAKFAST_CHAPTER_ID else "进入煎饼铺"
	noodle_shop_button.text = "继续刀削面馆" if active_id == _session.NOODLE_CHAPTER_ID else "进入刀削面馆"
	night_market_shop_button.text = "继续灯火串铺" if active_id == _session.NIGHT_MARKET_CHAPTER_ID else "进入灯火串铺"
	breakfast_shop_button.disabled = blocks_switch and active_id != _session.BREAKFAST_CHAPTER_ID
	noodle_shop_button.disabled = not bool(noodle.get("unlocked", false)) or (blocks_switch and active_id != _session.NOODLE_CHAPTER_ID)
	night_market_shop_button.disabled = not bool(night_market.get("unlocked", false)) or (blocks_switch and active_id != _session.NIGHT_MARKET_CHAPTER_ID)
	var special_customer_progress := str(_session.call("special_customer_reputation_summary"))
	breakfast_shop_status.text = "第 %d 日 · %d 金币%s\n%s" % [
		int(breakfast.get("current_day", 1)),
		int(breakfast.get("coins", 0)),
		" · 营业中" if bool(breakfast.get("day_open", false)) else "",
		special_customer_progress,
	]
	if bool(noodle.get("unlocked", false)):
		noodle_shop_status.text = "第 %d 日 · %d 金币%s" % [int(noodle.get("current_day", 1)), int(noodle.get("coins", 0)), " · 营业中" if bool(noodle.get("day_open", false)) else ""] if bool(noodle.get("initialized", false)) else "已解锁 · 首次进入将开始教学"
	else:
		var progress := Dictionary(noodle.get("unlock_progress", {}))
		noodle_shop_status.text = "未解锁 · 四区 %d/4 · 铜牌 %d/4" % [int(progress.get("unlocked_area_count", 0)), int(progress.get("bronze_area_count", 0))]
	if bool(night_market.get("unlocked", false)):
		night_market_shop_status.text = "第 %d 日 · %d 金币%s" % [int(night_market.get("current_day", 1)), int(night_market.get("coins", 0)), " · 营业中" if bool(night_market.get("day_open", false)) else ""] if bool(night_market.get("initialized", false)) else "已解锁 · 首次进入将开始双火线教学"
	else:
		var night_progress := Dictionary(night_market.get("unlock_progress", {}))
		night_market_shop_status.text = "未解锁 · 面馆成长 %d/%d" % [int(night_progress.get("owned_growth_count", 0)), int(night_progress.get("required_growth_count", 4))]
	chapter_hint.text = "当前店铺营业中，结束本日后才能切换。" if blocks_switch else "选择一家已解锁的铺子开始营业。"


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
	shops_button.disabled = disabled or not bool(_session.call("has_save"))
	quit_button.disabled = disabled
	new_game_cancel_button.disabled = disabled
	new_game_confirm_button.disabled = disabled
	breakfast_shop_button.disabled = disabled
	noodle_shop_button.disabled = disabled
	night_market_shop_button.disabled = disabled
	chapter_close_button.disabled = disabled
	if not disabled:
		_refresh_chapter_cards()


func _open_settings() -> void:
	_shared_settings_panel.open_with_session(_session)


func _close_settings() -> void:
	if _shared_settings_panel != null and _shared_settings_panel.is_open():
		_shared_settings_panel.close_without_saving()
	else:
		settings_button.grab_focus()


func _save_settings() -> void:
	_session.call("save_settings", master_slider.value, sfx_slider.value, fullscreen_check.button_pressed)
	_close_settings()


func _on_shared_settings_closed(_saved: bool) -> void:
	settings_button.grab_focus()


func _apply_ui_settings(settings: Dictionary) -> void:
	UI_SCALE_APPLIER.apply_to(self, float(settings.get("ui_scale", 100.0)))


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
