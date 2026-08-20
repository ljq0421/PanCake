extends CanvasLayer

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const AREA_LABELS := {
	&"area.pancake": "煎饼",
	&"area.youtiao": "油条",
	&"area.fresh_soy_milk": "现磨豆浆",
}

@export var workstation_path: NodePath

@onready var panel: PanelContainer = %DebugPanel
@onready var performance_label: Label = %PerformanceLabel
@onready var model_label: Label = %ModelLabel
@onready var cursor_label: Label = %CursorLabel
@onready var mode_label: Label = %ModeLabel
@onready var legend_label: Label = %LegendLabel
@onready var progression_label: Label = %ProgressionLabel
@onready var feedback_label: Label = %FeedbackLabel
@onready var quick_end_business_day_button: Button = %QuickEndBusinessDayButton
@onready var add_coins_button: Button = %AddCoinsButton
@onready var add_reputation_button: Button = %AddReputationButton

var workstation: Workstation
var game_session: Node
var _refresh_elapsed := 0.0
var _mastery_buttons: Dictionary = {}
var _tier_buttons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	if not OS.is_debug_build():
		set_process(false)
		set_process_unhandled_input(false)
		return
	workstation = get_node(workstation_path) as Workstation
	game_session = get_node_or_null("/root/GameSession")
	quick_end_business_day_button.pressed.connect(_end_business_day_early_for_testing)
	add_coins_button.pressed.connect(_grant_progression.bind(1000, 0, &"", 0, 0))
	add_reputation_button.pressed.connect(_grant_progression.bind(0, 20, &"", 0, 0))
	_bind_area_buttons()
	_refresh_labels()


func _bind_area_buttons() -> void:
	var button_names := {
		&"area.pancake": {
			"qualified": &"PancakeQualifiedButton",
			"a_grade": &"PancakeAGradeButton",
			"tiers": [&"PancakeTier0Button"],
		},
	&"area.youtiao": {
		"qualified": &"YoutiaoQualifiedButton",
		"a_grade": &"YoutiaoAGradeButton",
		"tiers": [&"YoutiaoTier0Button"],
	},
		&"area.fresh_soy_milk": {
			"qualified": &"SoyQualifiedButton",
			"a_grade": &"SoyAGradeButton",
			"tiers": [&"SoyTier0Button", &"SoyTier1Button", &"SoyTier2Button"],
		},
	}
	for area_id_variant in button_names:
		var area_id := StringName(area_id_variant)
		var names := Dictionary(button_names[area_id])
		var qualified_button := get_node("%%%s" % str(names.get("qualified", &""))) as Button
		var a_grade_button := get_node("%%%s" % str(names.get("a_grade", &""))) as Button
		qualified_button.pressed.connect(_grant_progression.bind(0, 0, area_id, 5, 0))
		a_grade_button.pressed.connect(_grant_progression.bind(0, 0, area_id, 0, 5))
		_mastery_buttons[area_id] = [qualified_button, a_grade_button]
		var tier_row: Array[Button] = []
		var tier_names := Array(names.get("tiers", []))
		for tier in tier_names.size():
			var tier_button := get_node("%%%s" % str(tier_names[tier])) as Button
			tier_button.pressed.connect(_advance_to_tier.bind(area_id, tier))
			tier_row.append(tier_button)
		_tier_buttons[area_id] = tier_row


func _process(delta: float) -> void:
	_refresh_elapsed += delta
	if _refresh_elapsed >= 0.1:
		_refresh_elapsed = 0.0
		_refresh_labels()


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or workstation == null:
		return
	if event.is_action_pressed(&"toggle_debug"):
		panel.visible = not panel.visible
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"reset_pancake"):
		workstation.reset_pancake()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1:
				workstation.set_heatmap_field(PancakeHeatmap.VIEW_APPEARANCE)
			KEY_2:
				workstation.set_heatmap_field(PancakeModel.FIELD_THICKNESS)
			KEY_3:
				workstation.set_heatmap_field(PancakeModel.FIELD_WETNESS)
			KEY_4:
				workstation.set_heatmap_field(PancakeModel.FIELD_DONENESS)
			KEY_5:
				workstation.set_heatmap_field(PancakeModel.FIELD_DAMAGE)
			KEY_6:
				workstation.set_heatmap_field(PancakeModel.FIELD_SAUCE_CONCENTRATION)


func _grant_progression(coins_delta: int, reputation_delta: int, area_id: StringName, qualified_delta: int, a_grade_delta: int) -> void:
	if game_session == null or not game_session.has_method("debug_grant_progression"):
		_set_feedback("调试进度服务不可用", true)
		return
	var result: Dictionary = game_session.call("debug_grant_progression", coins_delta, reputation_delta, area_id, qualified_delta, a_grade_delta)
	_set_feedback(_debug_result_text(result), not bool(result.get("success", false)))
	if bool(result.get("success", false)) and workstation != null:
		workstation.refresh_progression_ui_after_debug("调试资源已写入当前存档")
	_refresh_labels()


func _advance_to_tier(area_id: StringName, target_tier: int) -> void:
	if game_session == null or not game_session.has_method("debug_advance_to_device_tier"):
		_set_feedback("调试等级服务不可用", true)
		return
	var result: Dictionary = game_session.call("debug_advance_to_device_tier", area_id, target_tier)
	_set_feedback(_debug_result_text(result), not bool(result.get("success", false)))
	if bool(result.get("success", false)) and workstation != null:
		workstation.refresh_progression_ui_after_debug("已推进至%s T%d；开始下一天后测试" % [AREA_LABELS.get(area_id, area_id), target_tier])
	_refresh_labels()


func _end_business_day_early_for_testing() -> void:
	if workstation != null:
		workstation.end_business_day_early_for_testing()
		_set_feedback("已按测试路径结束营业，可使用等级推进与解锁补齐", false)


func _refresh_labels() -> void:
	if workstation == null:
		return
	quick_end_business_day_button.disabled = not workstation.can_end_business_day_early_for_testing()
	_refresh_progression_controls()
	var surface: PancakeHeatmap = workstation.pancake_surface
	var model: PancakeModel = workstation.pancake_model
	if surface == null:
		var primary_griddle := workstation.get_node_or_null("FiveAreaInfrastructure/Stations/PancakeStation/MultiGriddleStation/Griddle01")
		if primary_griddle != null:
			surface = primary_griddle.get("pancake_surface") as PancakeHeatmap
			model = primary_griddle.get("pancake_model") as PancakeModel
	if surface == null or model == null:
		performance_label.text = "FPS %d" % Engine.get_frames_per_second()
		model_label.text = "煎饼模型当前不可用"
		cursor_label.text = "—"
		return
	var summary := model.calculate_summary()
	performance_label.text = "FPS %d  |  model update %d us  |  revision %d" % [
		Engine.get_frames_per_second(), model.last_update_usec, model.revision
	]
	model_label.text = "Grid %dx%d  |  cover %.1f%%  |  mean thickness %.3f  |  damage %.1f%%" % [
		model.grid_size,
		model.grid_size,
		float(summary.coverage_ratio) * 100.0,
		float(summary.mean_thickness),
		float(summary.damage_ratio) * 100.0,
	]
	var mouse_local := surface.get_local_mouse_position()
	var grid_cell := PancakeSpace.local_to_grid(mouse_local, surface.size, model.grid_size)
	cursor_label.text = "Pan local (%.1f, %.1f)  ->  grid (%d, %d)" % [
		mouse_local.x, mouse_local.y, grid_cell.x, grid_cell.y
	]
	var field := surface.heatmap_field
	mode_label.text = "当前显示：%s" % _field_display_name(field)
	legend_label.text = _field_legend(field)


func _refresh_progression_controls() -> void:
	if game_session == null or not game_session.has_method("five_area_progression_snapshot"):
		progression_label.text = "当前没有可用存档"
		return
	var snapshot: Dictionary = game_session.call("five_area_progression_snapshot")
	var unlocked_areas := Array(snapshot.get("unlocked_area_ids", []))
	var device_tiers := Dictionary(snapshot.get("device_tiers", {}))
	var details_by_area := Dictionary(snapshot.get("area_mastery_details", {}))
	var pending := not StringName(snapshot.get("pending_install_purchase", &"")).is_empty() or not StringName(snapshot.get("pending_content_purchase", &"")).is_empty()
	var summary_lines := PackedStringArray([
		"营业日 %d · 金币 %d · 口碑 %d" % [int(snapshot.get("current_day", 1)), int(snapshot.get("coins", 0)), int(snapshot.get("reputation", 0))],
	])
	var report_open := workstation.daily_bill_panel != null and workstation.daily_bill_panel.visible
	for area_id in CATALOG.AREA_IDS:
		var area_definition := CATALOG.area_definition(area_id)
		var device_id := StringName(area_definition.get("device_id", &""))
		var owned := unlocked_areas.has(area_id) or unlocked_areas.has(str(area_id))
		var tier := int(device_tiers.get(device_id, device_tiers.get(str(device_id), 0))) if owned else -1
		var details := Dictionary(details_by_area.get(area_id, details_by_area.get(str(area_id), {})))
		summary_lines.append("%s：%s · 合格 %d · A级 %d" % [
			AREA_LABELS.get(area_id, area_id),
			"T%d" % tier if owned else "未解锁",
			int(details.get("qualified", 0)),
			int(details.get("a_grade", 0)),
		])
		for mastery_button in Array(_mastery_buttons.get(area_id, [])):
			(mastery_button as Button).disabled = not owned
		var tier_row: Array = Array(_tier_buttons.get(area_id, []))
		for target_tier in tier_row.size():
			var tier_button := tier_row[target_tier] as Button
			tier_button.disabled = not report_open or pending or target_tier <= tier
			tier_button.tooltip_text = "仅可在营业总结中向前推进" if not report_open else ("先进入下一天激活已预订项" if pending else "推进到正式路线中的%s T%d" % [AREA_LABELS.get(area_id, area_id), target_tier])
	progression_label.text = "\n".join(summary_lines)


func _debug_result_text(result: Dictionary) -> String:
	if bool(result.get("success", false)):
		if not bool(result.get("changed", true)):
			return "状态已达到，无需修改"
		return "调试修改成功，已写入当前存档"
	match StringName(result.get("reason", &"unknown")):
		&"business_day_open": return "请先结束当前营业日"
		&"pending_purchase_exists": return "已有预订项，请先开始下一营业日完成激活"
		&"area_locked": return "该区域尚未解锁"
		&"downgrade_not_allowed": return "测试等级只允许向前推进，不允许降级"
		&"debug_tools_unavailable": return "该功能只在 Debug 构建可用"
		&"no_active_save": return "当前没有可修改的存档"
	return "调试修改失败：%s" % str(result.get("reason", "unknown"))


func _set_feedback(message: String, is_error: bool) -> void:
	feedback_label.text = message
	feedback_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.38) if is_error else Color(0.48, 1.0, 0.72))


func _field_display_name(field: StringName) -> String:
	match field:
		PancakeHeatmap.VIEW_APPEARANCE:
			return "直观面饼"
		PancakeModel.FIELD_THICKNESS:
			return "厚度调试"
		PancakeModel.FIELD_WETNESS:
			return "湿度调试"
		PancakeModel.FIELD_DONENESS:
			return "成熟度调试"
		PancakeModel.FIELD_DAMAGE:
			return "破损调试"
		PancakeModel.FIELD_SAUCE_CONCENTRATION:
			return "酱料浓度调试"
		_:
			return String(field)


func _field_legend(field: StringName) -> String:
	match field:
		PancakeHeatmap.VIEW_APPEARANCE:
			return "亮黄湿润 · 金褐成熟 · 深褐焦化 · 鏊面透出=破洞"
		PancakeModel.FIELD_THICKNESS:
			return "深蓝=少 · 青色=适中 · 红色=厚"
		PancakeModel.FIELD_WETNESS:
			return "深色=已凝固 · 亮蓝=湿润"
		PancakeModel.FIELD_DONENESS:
			return "浅色=未熟 · 深褐=成熟/焦化"
		PancakeModel.FIELD_DAMAGE:
			return "暗色=完整 · 红色=接近破洞"
		PancakeModel.FIELD_SAUCE_CONCENTRATION:
			return "浅黄=缺酱 · 红褐=适中 · 深褐=过量"
		_:
			return "1 直观 · 2 厚度 · 3 湿度 · 4 成熟度 · 5 破损 · 6 酱料"
