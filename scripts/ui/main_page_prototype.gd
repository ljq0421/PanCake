class_name MainPagePrototype
extends Control

const START_MENU_SCENE := "res://scenes/main/start_menu.tscn"

@onready var soy_milk_button: Button = %SoyMilkStation
@onready var youtiao_button: Button = %YoutiaoStation
@onready var pancake_button: Button = %PancakeStation
@onready var finished_drink_button: Button = %FinishedDrinkStation
@onready var dim_sum_button: Button = %DimSumStation
@onready var feedback_label: Label = %FeedbackLabel
@onready var pause_overlay: Control = %PauseOverlay
@onready var settings_overlay: Control = %SettingsOverlay
@onready var resume_button: Button = %ResumeButton
@onready var return_button: Button = %ReturnButton
@onready var close_settings_button: Button = %CloseSettingsButton
@onready var coin_label: Label = $Header/CoinPill/Label
@onready var reputation_label: Label = $Header/MoodPill/Label
@onready var business_day_label: Label = $Header/ComboPill/Label

var selected_station_id: StringName = &"pancake"
var last_clicked_slot: StringName = &""
var last_clicked_tool: StringName = &""

var _station_copy := {
	&"soy_milk": {
		"title": "现磨豆浆台",
		"body": "点击选择现磨豆浆机。后续在这里完成选豆、加水、磨煮与接杯。流程功能尚未接入。",
	},
	&"youtiao": {
		"title": "油条台",
		"body": "油条位于煎饼左侧、豆浆右侧；成品后续可直接加入煎饼。",
	},
	&"pancake": {
		"title": "煎饼操作台 · 固定居中",
		"body": "左侧面糊桶负责舀取面糊，右侧工具位提供摊饼器和甜面酱刷；折叠直接拖动饼皮边缘完成。当前只验证入口与点击反馈。",
	},
	&"finished_drinks": {
		"title": "成品饮品柜",
		"body": "在售饮品自动摆进柜内；下方只保留 1×1 补货箱。订单明确标注“加热”时才进入加热位。流程尚未接入。",
	},
	&"dim_sum": {
		"title": "多层蒸笼",
		"body": "选择已包好的馒头、菜包或肉包半成品，按层码放并分别判断熟度。流程功能尚未接入。",
	},
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bind_station(soy_milk_button, &"soy_milk")
	_bind_station(youtiao_button, &"youtiao")
	_bind_station(pancake_button, &"pancake")
	_bind_station(finished_drink_button, &"finished_drinks")
	_bind_station(dim_sum_button, &"dim_sum")
	for tool in get_tree().get_nodes_in_group(&"main_page_pancake_tool"):
		if tool is Button:
			(tool as Button).pressed.connect(_on_pancake_tool_pressed.bind(tool))
	for slot in get_tree().get_nodes_in_group(&"main_page_material_slot"):
		if slot is Button:
			(slot as Button).pressed.connect(_on_material_slot_pressed.bind(slot))
	for order_card in get_tree().get_nodes_in_group(&"main_page_order_card"):
		if order_card is Button:
			(order_card as Button).pressed.connect(_on_order_card_pressed.bind(order_card))
	%PauseButton.pressed.connect(_open_pause)
	%SettingsButton.pressed.connect(_open_settings)
	resume_button.pressed.connect(_close_pause)
	return_button.pressed.connect(_return_to_start_menu)
	close_settings_button.pressed.connect(_close_settings)
	_bind_global_status()
	_refresh_global_status()
	_select_station(&"pancake")


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if settings_overlay.visible:
		_close_settings()
	elif pause_overlay.visible:
		_close_pause()
	else:
		_open_pause()
	get_viewport().set_input_as_handled()


func _bind_station(button: Button, station_id: StringName) -> void:
	button.pressed.connect(_select_station.bind(station_id))


func _select_station(station_id: StringName) -> void:
	selected_station_id = station_id
	var buttons := {
		&"soy_milk": soy_milk_button,
		&"youtiao": youtiao_button,
		&"pancake": pancake_button,
		&"finished_drinks": finished_drink_button,
		&"dim_sum": dim_sum_button,
	}
	for key in buttons:
		(buttons[key] as Button).button_pressed = key == station_id
	var copy: Dictionary = _station_copy[station_id]
	feedback_label.text = "已选择：%s" % copy.title


func _on_material_slot_pressed(slot: Button) -> void:
	last_clicked_slot = StringName(str(slot.get_meta(&"slot_id", "")))
	var display_name := str(slot.get_meta(&"display_name", slot.text))
	var station_name := str(slot.get_meta(&"station_name", "材料区"))
	if bool(slot.get_meta(&"locked", false)):
		feedback_label.text = "%s · %s：后续升级解锁" % [station_name, display_name]
	else:
		feedback_label.text = "%s · 已选材料：%s" % [station_name, display_name]
func _on_pancake_tool_pressed(tool: Button) -> void:
	last_clicked_tool = StringName(str(tool.get_meta(&"tool_id", "")))
	feedback_label.text = "煎饼 · 已选择：%s（制作流程尚未接入）" % str(tool.get_meta(&"display_name", tool.text))


func _on_order_card_pressed(order_card: Button) -> void:
	feedback_label.text = "已查看订单：%s" % str(order_card.get_meta(&"order_name", "顾客订单"))


func _open_pause() -> void:
	pause_overlay.visible = true
	get_tree().paused = true
	resume_button.grab_focus()


func _close_pause() -> void:
	get_tree().paused = false
	pause_overlay.visible = false
	%PauseButton.grab_focus()


func _open_settings() -> void:
	settings_overlay.visible = true
	close_settings_button.grab_focus()


func _close_settings() -> void:
	settings_overlay.visible = false
	%SettingsButton.grab_focus()


func _return_to_start_menu() -> void:
	get_tree().paused = false
	var error := get_tree().change_scene_to_file(START_MENU_SCENE)
	if error != OK:
		push_error("Could not return to start menu: %s" % error_string(error))


func _bind_global_status() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return
	var callback := Callable(self, "_on_global_status_changed")
	for signal_name in [&"coins_changed", &"progression_changed"]:
		if session.has_signal(signal_name) and not session.is_connected(signal_name, callback):
			session.connect(signal_name, callback)


func _on_global_status_changed(_value: Variant = null) -> void:
	_refresh_global_status()


func _refresh_global_status() -> void:
	var session := get_node_or_null("/root/GameSession")
	var snapshot: Dictionary = {}
	if session != null and session.has_method("five_area_progression_snapshot"):
		snapshot = Dictionary(session.call("five_area_progression_snapshot"))
	coin_label.text = "金币  %d" % int(snapshot.get("coins", 0))
	reputation_label.text = "声誉  %d" % int(snapshot.get("reputation", 0))
	business_day_label.text = "营业日  %d" % int(snapshot.get("current_day", 1))
