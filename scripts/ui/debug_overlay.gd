extends CanvasLayer

@export var workstation_path: NodePath

@onready var panel: PanelContainer = %DebugPanel
@onready var performance_label: Label = %PerformanceLabel
@onready var model_label: Label = %ModelLabel
@onready var cursor_label: Label = %CursorLabel
@onready var mode_label: Label = %ModeLabel
@onready var legend_label: Label = %LegendLabel
@onready var quick_end_business_day_button: Button = %QuickEndBusinessDayButton

var workstation: Workstation
var _refresh_elapsed := 0.0


func _ready() -> void:
	workstation = get_node(workstation_path) as Workstation
	process_mode = Node.PROCESS_MODE_ALWAYS
	quick_end_business_day_button.pressed.connect(_end_business_day_early_for_testing)
	_refresh_labels()


func _process(delta: float) -> void:
	_refresh_elapsed += delta
	if _refresh_elapsed >= 0.1:
		_refresh_elapsed = 0.0
		_refresh_labels()


func _unhandled_input(event: InputEvent) -> void:
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


func _end_business_day_early_for_testing() -> void:
	if workstation != null:
		workstation.end_business_day_early_for_testing()


func _refresh_labels() -> void:
	if workstation == null:
		return
	var surface: PancakeHeatmap = workstation.pancake_surface
	var model: PancakeModel = workstation.pancake_model
	if surface == null:
		var primary_griddle := workstation.get_node_or_null("FiveAreaInfrastructure/Stations/PancakeStation/MultiGriddleStation/Griddle01")
		if primary_griddle != null:
			surface = primary_griddle.get("pancake_surface") as PancakeHeatmap
			model = primary_griddle.get("pancake_model") as PancakeModel
	if surface == null or model == null:
		return
	quick_end_business_day_button.disabled = not workstation.can_end_business_day_early_for_testing()
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
