class_name Workstation
extends Control

signal daily_bill_closed

const SAUCE_TOOL_STATE_SCRIPT := preload("res://scripts/gameplay/sauce_tool_state.gd")
const PANCAKE_SCORER_SCRIPT := preload("res://scripts/gameplay/pancake_scorer.gd")
const FOLD_MODEL_SCRIPT := preload("res://scripts/gameplay/pancake_fold_model.gd")
const INGREDIENT_MODEL_SCRIPT := preload("res://scripts/gameplay/ingredient_model.gd")
const INGREDIENT_STOCK_MODEL_SCRIPT := preload("res://scripts/gameplay/ingredient_stock_model.gd")
const ORDER_SERVICE_SCRIPT := preload("res://scripts/services/order_service.gd")
const CUSTOMER_QUEUE_SERVICE_SCRIPT := preload("res://scripts/services/customer_queue_service.gd")
const P1_SESSION_SCRIPT := preload("res://scripts/gameplay/p1_session.gd")
const PAYMENT_COIN_MODEL_SCRIPT := preload("res://scripts/gameplay/payment_coin_model.gd")
const CUSTOMER_TEXTURES := {
	&"customer_01": {
		&"neutral": preload("res://resources/art/customers/customer_01/customer_01_neutral_cropped.tres"),
		&"impatient": preload("res://resources/art/customers/customer_01/customer_01_impatient_cropped.tres"),
		&"satisfied": preload("res://resources/art/customers/customer_01/customer_01_satisfied_cropped.tres"),
		&"accepting_bag": preload("res://resources/art/customers/customer_01/customer_01_accepting_bag_cropped.tres"),
		&"paying_coins": preload("res://resources/art/customers/customer_01/customer_01_paying_coins_cropped.tres"),
	},
	&"customer_02": {
		&"neutral": preload("res://resources/art/customers/customer_02/customer_02_neutral_cropped.tres"),
		&"impatient": preload("res://resources/art/customers/customer_02/customer_02_impatient_cropped.tres"),
		&"satisfied": preload("res://resources/art/customers/customer_02/customer_02_satisfied_cropped.tres"),
		&"accepting_bag": preload("res://resources/art/customers/customer_02/customer_02_accepting_bag_cropped.tres"),
		&"paying_coins": preload("res://resources/art/customers/customer_02/customer_02_paying_coins_cropped.tres"),
	},
	&"customer_03": {
		&"neutral": preload("res://resources/art/customers/customer_03/customer_03_neutral_cropped.tres"),
		&"impatient": preload("res://resources/art/customers/customer_03/customer_03_impatient_cropped.tres"),
		&"satisfied": preload("res://resources/art/customers/customer_03/customer_03_satisfied_cropped.tres"),
		&"accepting_bag": preload("res://resources/art/customers/customer_03/customer_03_accepting_bag_cropped.tres"),
		&"paying_coins": preload("res://resources/art/customers/customer_03/customer_03_paying_coins_cropped.tres"),
	},
}
const DEFAULT_ORDER_COINS := 3
const PAYMENT_SLOT_COIN_SIZE := Vector2(48.0, 48.0)
const PAYMENT_COIN_START_POSITION := Vector2(842.0, 312.0)
const PAYMENT_COIN_START_SIZE := Vector2(82.0, 82.0)
const PAYMENT_SLOT_ORIGIN := Vector2(600.0, 474.0)
const PAYMENT_SLOT_COLUMN_SPACING := 44.0
const PAYMENT_SLOT_ROW_SPACING := 24.0
const PAYMENT_SLOT_MAX_COLUMNS := 20
const PAYMENT_COIN_TEXTURES := {
	1: preload("res://resources/art/payments/coin_1_v1.png"),
	2: preload("res://resources/art/payments/coin_2_v1.png"),
	5: preload("res://resources/art/payments/coin_5_v1.png"),
	10: preload("res://resources/art/payments/coin_10_v1.png"),
	20: preload("res://resources/art/payments/coin_20_v1.png"),
}
const SPREADER_ART_ROTATION_OFFSET := 1.124
const SPREADER_SPEED_SLOW := -1
const SPREADER_SPEED_MEDIUM := 0
const SPREADER_SPEED_FAST := 1

@export var parameters: PancakeSimulationParameters

@onready var pancake_surface: PancakeHeatmap = %PancakeSurface
@onready var pancake_visual: TextureRect = %PancakeVisual
@onready var tool_controller: ToolController = %ToolController
@onready var ladle_button: Button = %LadleButton
@onready var scraper_button: Button = %ScraperButton
@onready var sauce_brush_button: Button = %SauceBrushButton
@onready var sauce_refill_button: Button = %SauceRefillButton
@onready var sauce_status_label: Label = %SauceStatusLabel
@onready var fold_button: Button = %FoldButton
@onready var paper_sleeve_button: Button = %PaperSleeveButton
@onready var tray_button: Button = %TrayButton
@onready var fold_status_label: Label = %FoldStatusLabel
@onready var fold_overlay: Control = %PancakeFoldOverlay
@onready var spreader_artwork: Sprite2D = %SpreaderArtwork
@onready var tool_status_label: Label = %ToolStatusLabel
@onready var warning_label: Label = %WarningLabel
@onready var warning_tone: AudioStreamPlayer = %DamageWarningTone
@onready var surface_readout_label: Label = %SurfaceReadoutLabel
@onready var chili_sauce_refill_button: Button = %ChiliSauceRefillButton
@onready var ingredient_layer: IngredientLayer = %IngredientLayer
@onready var sauce_blob_overlay: Control = %SauceBlobOverlay
@onready var egg_crack_artwork: Sprite2D = %EggCrackArtwork
@onready var ingredient_drag_preview: TextureRect = %IngredientDragPreview
@onready var egg_button: Button = %EggButton
@onready var baocui_button: Button = %BaocuiButton
@onready var ham_button: Button = %HamButton
@onready var scallion_button: Button = %ScallionButton
@onready var egg_restock_button: Button = %EggRestockButton
@onready var baocui_restock_button: Button = %BaocuiRestockButton
@onready var ham_restock_button: Button = %HamRestockButton
@onready var scallion_restock_button: Button = %ScallionRestockButton
@onready var customer_portrait: TextureRect = %CustomerPortrait
@onready var queue_status_label: Label = %QueueStatusLabel
@onready var waiting_customer_portraits: Array[TextureRect] = [%WaitingCustomer1, %WaitingCustomer2]
@onready var customer_line_label: Label = %CustomerLineLabel
@onready var order_text_label: Label = %OrderTextLabel
@onready var patience_bar: ProgressBar = %PatienceBar
@onready var phase_label: Label = %PhaseLabel
@onready var heat_slider: HSlider = %HeatSlider
@onready var heat_label: Label = %HeatLabel
@onready var step_action_button: Button = %StepActionButton
@onready var packaging_choices: Control = %PackagingChoices
@onready var bag_button: Button = %BagButton
@onready var serve_button: Button = %ServeButton
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_title_label: Label = %ResultTitleLabel
@onready var result_detail_label: Label = %ResultDetailLabel
@onready var result_tags_label: Label = %ResultTagsLabel
@onready var integrity_score_label: Label = %IntegrityScoreLabel
@onready var thickness_score_label: Label = %ThicknessScoreLabel
@onready var heat_score_label: Label = %HeatScoreLabel
@onready var egg_score_label: Label = %EggScoreLabel
@onready var sauce_score_label: Label = %SauceScoreLabel
@onready var ingredient_score_label: Label = %IngredientScoreLabel
@onready var fold_score_label: Label = %FoldScoreLabel
@onready var order_score_label: Label = %OrderScoreLabel
@onready var time_score_label: Label = %TimeScoreLabel
@onready var next_order_button: Button = %NextOrderButton
@onready var payment_sprite: TextureRect = %PaymentSprite
@onready var payment_coin_layer: Control = %PaymentCoinLayer
@onready var payment_collection_area: Button = %PaymentCollectionArea
@onready var payment_display: TextureRect = %PaymentDisplay
@onready var kitchen_audio: AudioStreamPlayer = %KitchenAudio
@onready var p1_control_bar: Panel = %P1ControlBar
@onready var serve_product_button: Button = %ServeProductButton
@onready var handoff_product_sprite: TextureRect = %HandoffProductSprite
@onready var order_summary_card: PanelContainer = %OrderSummaryCard
@onready var summary_score_label: Label = %SummaryScoreLabel
@onready var summary_feedback_label: Label = %SummaryFeedbackLabel
@onready var summary_view_button: Button = %SummaryViewButton
@onready var summary_dismiss_button: Button = %SummaryDismissButton
@onready var daily_bill_panel: PanelContainer = %DailyBillPanel
@onready var daily_bill_title_label: Label = %DailyBillTitleLabel
@onready var daily_bill_stats_label: Label = %DailyBillStatsLabel
@onready var daily_bill_rows: GridContainer = %DailyBillRows
@onready var daily_bill_close_button: Button = %DailyBillCloseButton

var pancake_model: PancakeModel
var _scrape_sampler: StrokeSampler
var _egg_sampler: StrokeSampler
var _sauce_sampler: StrokeSampler
var _previous_scrape_sample := Vector2.ZERO
var _last_process_grid_position := Vector2.ZERO
var _spreader_max_radius := 0.0
var _spreader_direction_grace_remaining := 0
var _spreader_smoothed_angular_speed := 0.0
var _spreader_speed_initialized := false
var _spreader_speed_band := SPREADER_SPEED_MEDIUM
var _spreader_smoothed_angle := 0.0
var _spreader_angle_initialized := false
var _spread_shape_locked := false
var _simulation_accumulator := 0.0
var pour_used := false
var sauce_tool_state: RefCounted
var sauce_tool_states: Dictionary = {}
var _last_sauce_evaluation: Dictionary = {}
var _sauce_stroke_id := 0
var _squeezing_sauce := false
var fold_model: RefCounted
var ingredient_model: IngredientModel
var ingredient_stock_model
var order_service: OrderService
var customer_queue: RefCounted
var p1_session: P1Session
var payment_coin_model: RefCounted
var current_sauce_type: StringName = OrderService.SAUCE_SWEET
var _ingredient_drag_type: StringName = &""
var _ingredient_drag_start := Vector2.ZERO
var _last_sizzle_msec := -10000
var _audio_update_accumulator := 0.0
var _result_detail_open := false
var _order_summary_visible := false
var _handoff_tween: Tween
var _payment_tween: Tween
var _payment_waiting_collection := false
var _payment_animation_active := false
var _current_payment_amount := 0
var _current_payment_denominations: Array[int] = []
var _payment_flight_sprites: Array[TextureRect] = []
var _pending_payment_sprites: Array[TextureRect] = []
var _customer_reaction_tween: Tween
var _customer_visual_state: StringName = &""


func _ready() -> void:
	if parameters == null:
		parameters = PancakeSimulationParameters.new()
	pancake_model = PancakeModel.new(parameters.grid_size, parameters)
	ingredient_model = INGREDIENT_MODEL_SCRIPT.new()
	ingredient_stock_model = INGREDIENT_STOCK_MODEL_SCRIPT.new(_saved_ingredient_stock())
	fold_model = FOLD_MODEL_SCRIPT.new(pancake_model, ingredient_model)
	var unlocked_ingredient_ids: Array[StringName] = IngredientModel.TYPES.duplicate()
	if has_meta(&"unlocked_ingredient_ids"):
		unlocked_ingredient_ids.clear()
		for ingredient_id in Array(get_meta(&"unlocked_ingredient_ids")):
			unlocked_ingredient_ids.append(StringName(ingredient_id))
	order_service = ORDER_SERVICE_SCRIPT.new(unlocked_ingredient_ids)
	customer_queue = CUSTOMER_QUEUE_SERVICE_SCRIPT.new(order_service)
	p1_session = P1_SESSION_SCRIPT.new()
	payment_coin_model = PAYMENT_COIN_MODEL_SCRIPT.new()
	_scrape_sampler = StrokeSampler.new(parameters.scraper_sample_spacing)
	_egg_sampler = StrokeSampler.new(parameters.egg_sample_spacing)
	_sauce_sampler = StrokeSampler.new(parameters.sauce_sample_spacing)
	sauce_tool_states = {
		OrderService.SAUCE_SWEET: SAUCE_TOOL_STATE_SCRIPT.new(parameters.sauce_brush_capacity),
		OrderService.SAUCE_CHILI: SAUCE_TOOL_STATE_SCRIPT.new(parameters.sauce_brush_capacity),
	}
	sauce_tool_state = sauce_tool_states[current_sauce_type]
	pancake_surface.heatmap_update_hz = parameters.heatmap_update_hz
	pancake_surface.render_texture_size = parameters.render_texture_size
	pancake_surface.set_model(pancake_model)
	ingredient_layer.set_model(ingredient_model)
	ingredient_layer.set_fold_model(fold_model)
	fold_overlay.set_fold_model(fold_model)
	pancake_surface.pointer_started.connect(_on_pointer_started)
	pancake_surface.pointer_ended.connect(_on_pointer_ended)
	pancake_surface.cancel_requested.connect(_on_cancel_requested)
	ladle_button.pressed.connect(_select_ladle)
	scraper_button.pressed.connect(_select_scraper)
	sauce_brush_button.pressed.connect(_select_sauce_brush)
	sauce_refill_button.button_down.connect(_on_sauce_squeeze_started)
	sauce_refill_button.button_up.connect(_on_sauce_squeeze_ended)
	chili_sauce_refill_button.button_down.connect(_on_chili_sauce_squeeze_started)
	chili_sauce_refill_button.button_up.connect(_on_sauce_squeeze_ended)
	fold_button.pressed.connect(_select_fold)
	paper_sleeve_button.pressed.connect(_use_paper_sleeve)
	tray_button.pressed.connect(_use_tray)
	bag_button.pressed.connect(_use_bag)
	serve_product_button.pressed.connect(_serve_order)
	next_order_button.pressed.connect(_close_result_detail)
	summary_view_button.pressed.connect(_open_result_detail)
	summary_dismiss_button.pressed.connect(_dismiss_order_summary)
	payment_collection_area.pressed.connect(_collect_payment)
	payment_collection_area.mouse_entered.connect(_collect_payment)
	daily_bill_close_button.pressed.connect(_close_daily_bill)
	step_action_button.pressed.connect(_advance_p1_step)
	heat_slider.value_changed.connect(_on_heat_changed)
	_connect_ingredient_slot(egg_button, IngredientModel.EGG)
	_connect_ingredient_slot(baocui_button, IngredientModel.BAOCUI)
	_connect_ingredient_slot(ham_button, IngredientModel.HAM_SAUSAGE)
	_connect_ingredient_slot(scallion_button, IngredientModel.SCALLION)
	ingredient_stock_model.changed.connect(_on_ingredient_stock_changed)
	fold_model.changed.connect(_refresh_fold_ui)
	tool_controller.tool_changed.connect(_on_tool_changed)
	p1_session.changed.connect(_refresh_p1_ui)
	p1_session.start(customer_queue.current_customer().order)
	_on_tool_changed(tool_controller.current_tool)
	_update_sauce_status()
	_refresh_fold_ui()
	_refresh_ingredient_stock_ui()
	_refresh_p1_ui()
	_log_info(&"workstation", "PancakeModel ready: %dx%d" % [parameters.grid_size, parameters.grid_size])


func _process(delta: float) -> void:
	_update_surface_readout()
	_update_spreader_artwork(delta)
	if p1_session != null and not _result_detail_open:
		p1_session.advance_time(delta)
	if _squeezing_sauce:
		sauce_tool_state.add(parameters.sauce_squeeze_rate * delta)
		_refresh_sauce_load_display()
	_simulation_accumulator += delta
	while _simulation_accumulator + 0.000001 >= parameters.simulation_step_seconds:
		if pour_used and not _folding_locks_preparation() and _is_active_cooking_phase():
			pancake_model.advance_cooking(parameters.simulation_step_seconds, p1_session.heat_level)
		else:
			pancake_model.advance_solidification(parameters.simulation_step_seconds)
		_simulation_accumulator -= parameters.simulation_step_seconds
	_update_cooking_audio(delta)
	if not pancake_surface.pointer_pressed:
		return
	if not PancakeSpace.is_inside_pan(pancake_surface.pointer_local_position, pancake_surface.size, parameters.pan_height_ratio):
		return
	var grid_position := PancakeSpace.local_to_grid_position(
		pancake_surface.pointer_local_position, pancake_surface.size, pancake_model.grid_size
	)
	match tool_controller.current_tool:
		ToolController.Tool.SCRAPER:
			_process_scraper(grid_position, delta)
		ToolController.Tool.SAUCE_BRUSH:
			_process_sauce_brush(grid_position)
		ToolController.Tool.FOLD:
			fold_model.update_drag(grid_position)


func reset_pancake() -> void:
	pancake_model.reset()
	ingredient_model.reset()
	pancake_visual.visible = true
	ingredient_layer.visible = true
	sauce_blob_overlay.visible = true
	pour_used = false
	_spread_shape_locked = false
	ladle_button.disabled = false
	pancake_surface.clear_trace()
	pancake_surface.pointer_pressed = false
	_scrape_sampler.reset()
	_egg_sampler.reset()
	_sauce_sampler.reset()
	for state in sauce_tool_states.values():
		state.reset()
	current_sauce_type = OrderService.SAUCE_SWEET
	sauce_tool_state = sauce_tool_states[current_sauce_type]
	_squeezing_sauce = false
	_sauce_stroke_id = 0
	fold_model.reset()
	_audio_update_accumulator = 0.0
	kitchen_audio.call("set_sizzle", false, 0.0)
	if p1_session != null:
		p1_session.start(p1_session.order)
	tool_controller.clear_tool()
	warning_label.text = "当前无破洞风险"
	warning_label.modulate = Color(0.76, 0.92, 0.76)
	_update_sauce_status()
	result_panel.visible = false
	order_summary_card.visible = false
	payment_sprite.visible = false
	handoff_product_sprite.visible = false
	serve_product_button.visible = false
	fold_overlay.visible = true
	_result_detail_open = false
	ingredient_drag_preview.visible = false
	egg_crack_artwork.visible = false
	_ingredient_drag_type = &""
	_log_info(&"simulation", "Pancake grid reset in %d us" % pancake_model.last_update_usec)


func set_heatmap_field(field_name: StringName) -> void:
	pancake_surface.set_heatmap_field(field_name)


func pan_local_to_grid(local_position: Vector2) -> Vector2i:
	return PancakeSpace.local_to_grid(local_position, pancake_surface.size, pancake_model.grid_size)


func _process_scraper(grid_position: Vector2, delta: float) -> void:
	if p1_session.phase == P1Session.Phase.FIRST_SIDE:
		_process_egg_scraper(grid_position, delta)
		return
	if p1_session.phase != P1Session.Phase.SPREAD:
		pancake_surface.spreader_motion_valid = false
		tool_status_label.text = "当前步骤不需要使用 T 形摊面器"
		return
	var samples := _scrape_sampler.sample_to(grid_position)
	var previous_polar := _pan_polar_offset(_last_process_grid_position)
	var current_polar := _pan_polar_offset(grid_position)
	var angular_delta := absf(wrapf(current_polar.angle() - previous_polar.angle(), -PI, PI))
	var raw_angular_speed := angular_delta / maxf(delta, 0.000001)
	_update_spreader_speed(raw_angular_speed, delta)
	var effect_speed := _spreader_effect_speed()
	var applied_sample := false
	for sample in samples:
		var previous_offset := _pan_polar_offset(_previous_scrape_sample)
		var sample_offset := _pan_polar_offset(sample)
		var motion_distance := previous_offset.distance_to(sample_offset)
		if motion_distance <= 0.0001 or sample_offset.length() <= 1.0:
			_previous_scrape_sample = sample
			continue
		var sample_angle_delta := absf(wrapf(sample_offset.angle() - previous_offset.angle(), -PI, PI))
		var tangential_distance := sample_angle_delta * (previous_offset.length() + sample_offset.length()) * 0.5
		var circularity := tangential_distance / motion_distance
		var moving_too_far_inward := sample_offset.length() + parameters.spreader_inward_tolerance < _spreader_max_radius
		var circular_motion := circularity >= parameters.spreader_min_circularity
		if moving_too_far_inward:
			_spreader_direction_grace_remaining = 0
			_previous_scrape_sample = sample
			continue
		if circular_motion:
			_spreader_direction_grace_remaining = parameters.spreader_direction_grace_samples
		elif _spreader_direction_grace_remaining > 0:
			_spreader_direction_grace_remaining -= 1
		else:
			_previous_scrape_sample = sample
			continue
		var outward_direction := Vector2.from_angle(_spreader_smoothed_angle)
		var result := pancake_model.apply_scraper_sample(sample, outward_direction, effect_speed)
		_previous_scrape_sample = sample
		_spreader_max_radius = maxf(_spreader_max_radius, sample_offset.length())
		applied_sample = true
		_update_damage_warning(float(result.peak_damage), int(result.new_holes))
	_last_process_grid_position = grid_position
	pancake_surface.spreader_motion_valid = applied_sample
	if applied_sample:
		tool_status_label.text = "正在摊饼：速度%s（%s）" % [_spreader_speed_label(), _spreader_thickness_label()]
		var now := Time.get_ticks_msec()
		if now - _last_sizzle_msec > 180:
			_last_sizzle_msec = now
			kitchen_audio.call("play_cue", &"scrape")
	else:
		tool_status_label.text = "T形摊饼器：请绕鏊心画圈并逐步向外"
	pancake_surface.queue_redraw()


func _process_egg_scraper(grid_position: Vector2, delta: float) -> void:
	if not pancake_model.has_egg():
		pancake_surface.spreader_motion_valid = false
		tool_status_label.text = "先把完整鸡蛋拖到饼面，再用 T 形摊面器摊开"
		return
	var raw_samples := _egg_sampler.sample_to(grid_position)
	var samples := _limit_egg_samples(raw_samples)
	var previous_polar := _pan_polar_offset(_last_process_grid_position)
	var current_polar := _pan_polar_offset(grid_position)
	var angular_delta := absf(wrapf(current_polar.angle() - previous_polar.angle(), -PI, PI))
	var raw_angular_speed := angular_delta / maxf(delta, 0.000001)
	_update_spreader_speed(raw_angular_speed, delta)
	var effect_speed := _spreader_effect_speed()
	var result := pancake_model.apply_egg_spreader_path(samples, effect_speed)
	var applied_sample := int(result.changed_cells) > 0
	if not samples.is_empty():
		_previous_scrape_sample = samples[samples.size() - 1]
	_last_process_grid_position = grid_position
	pancake_surface.spreader_motion_valid = applied_sample
	if applied_sample:
		egg_crack_artwork.visible = false
		var egg_summary := pancake_model.calculate_egg_spread_summary()
		var set_hint := " · 已凝固，移动很慢" if pancake_model.egg_state == PancakeModel.EggState.SET else ""
		tool_status_label.text = "正在摊蛋：覆盖 %d%% · 均匀 %d%%%s" % [
			roundi(float(egg_summary.coverage_ratio) * 100.0),
			roundi(float(egg_summary.uniformity) * 100.0),
			set_hint,
		]
		var now := Time.get_ticks_msec()
		if now - _last_sizzle_msec > 180:
			_last_sizzle_msec = now
			kitchen_audio.call("play_cue", &"scrape")
	else:
		tool_status_label.text = "让 T 形横杆接触蛋液并连续画圈"
	pancake_surface.queue_redraw()


func _process_sauce_brush(grid_position: Vector2) -> void:
	var samples := _sauce_sampler.sample_to(grid_position)
	for sample in samples:
		_apply_sauce_brush_sample(sample)
	_last_process_grid_position = grid_position


func _apply_sauce_brush_sample(grid_position: Vector2) -> void:
	var covered_cells := pancake_model.covered_cell_count()
	if covered_cells <= 0:
		return
	var load_per_cell := parameters.sauce_brush_capacity / float(covered_cells)
	var maximum_cells := floori(float(sauce_tool_state.load) / maxf(load_per_cell, 0.000001))
	if maximum_cells <= 0:
		tool_status_label.text = "饼面没有待刷的酱料：先点击或按住右侧酱瓶挤酱"
		return
	var result := pancake_model.apply_sauce_sample(
		grid_position,
		parameters.sauce_layer_concentration,
		parameters.sauce_brush_radius,
		_sauce_stroke_id,
		maximum_cells,
		current_sauce_type
	)
	sauce_tool_state.consume(float(result.newly_layered_cells) * load_per_cell)
	if int(result.newly_layered_cells) > 0:
		kitchen_audio.call("play_cue", &"sauce")
	_refresh_sauce_load_display()


func _on_pointer_started(local_position: Vector2) -> void:
	var grid_position := PancakeSpace.local_to_grid_position(local_position, pancake_surface.size, pancake_model.grid_size)
	_last_process_grid_position = grid_position
	match tool_controller.current_tool:
		ToolController.Tool.LADLE:
			pancake_surface.pointer_pressed = false
			tool_status_label.text = "无需点击鏊面；面糊勺按钮会自动定量倒在正中"
		ToolController.Tool.SCRAPER:
			if p1_session.phase == P1Session.Phase.FIRST_SIDE:
				_egg_sampler.begin(grid_position)
			else:
				_scrape_sampler.begin(grid_position)
			_previous_scrape_sample = grid_position
			_spreader_max_radius = _pan_polar_offset(grid_position).length()
			_spreader_direction_grace_remaining = 0
			_spreader_speed_initialized = false
			_spreader_speed_band = SPREADER_SPEED_MEDIUM
			pancake_surface.spreader_motion_valid = false
		ToolController.Tool.SAUCE_BRUSH:
			_sauce_sampler.begin(grid_position)
			_sauce_stroke_id = pancake_model.begin_sauce_stroke()
			_apply_sauce_brush_sample(grid_position)
		ToolController.Tool.FOLD:
			if not fold_model.begin_drag(grid_position):
				pancake_surface.pointer_pressed = false
				tool_status_label.text = "请抓住尚未折叠的左侧或右侧饼皮边缘"
		_:
			tool_status_label.text = "请先点击左侧工具"


func _on_pointer_ended(local_position: Vector2) -> void:
	var finished_spread_shape := (
		tool_controller.current_tool == ToolController.Tool.SCRAPER
		and p1_session != null
		and p1_session.phase == P1Session.Phase.SPREAD
	)
	if tool_controller.current_tool == ToolController.Tool.FOLD and fold_model.active_region != FOLD_MODEL_SCRIPT.REGION_NONE:
		var grid_position := PancakeSpace.local_to_grid_position(local_position, pancake_surface.size, pancake_model.grid_size)
		var result: Dictionary = fold_model.release_drag(grid_position)
		if bool(result.get("committed", false)):
			tool_status_label.text = fold_model.result_label(result)
			kitchen_audio.call("play_cue", &"fold")
		else:
			tool_status_label.text = str(result.get("reason", "折叠未完成"))
	_scrape_sampler.reset()
	_egg_sampler.reset()
	_sauce_sampler.reset()
	if finished_spread_shape:
		_spread_shape_locked = true
		tool_controller.clear_tool()
		tool_status_label.text = "面饼形状已固定；直接选择配料或下一项操作"
		_refresh_p1_ui()
	_update_sauce_status()


func _on_cancel_requested() -> void:
	tool_controller.clear_tool()
	fold_model.cancel_drag()
	_scrape_sampler.reset()
	_egg_sampler.reset()
	_sauce_sampler.reset()
	_update_sauce_status()


func _select_ladle() -> void:
	if _folding_locks_preparation():
		tool_status_label.text = "折叠已经开始；按 R 重置后才能返回制作步骤"
		return
	if pour_used:
		tool_status_label.text = "面糊已自动倒完；本张饼不能再次加面"
		return
	_auto_pour_center()


func _select_scraper() -> void:
	if _folding_locks_preparation():
		tool_status_label.text = "折叠已经开始；不能再使用刮板"
		return
	if not _scraper_can_act():
		tool_status_label.text = "当前步骤不需要使用 T 形摊面器"
		return
	tool_controller.select_tool(ToolController.Tool.SCRAPER)


func _select_sauce_brush() -> void:
	if _folding_locks_preparation():
		tool_status_label.text = "折叠已经开始；不能再刷酱"
		return
	if not _confirm_spread_for_next_action():
		return
	if p1_session == null or p1_session.phase != P1Session.Phase.SAUCE_AND_FILLINGS:
		tool_status_label.text = "翻面后即可刷酱"
		return
	if float(sauce_tool_state.load) <= 0.0:
		tool_status_label.text = "先点击或按住甜面酱/辣椒酱，把酱挤到饼面"
		return
	tool_controller.select_tool(ToolController.Tool.SAUCE_BRUSH)


func _select_fold() -> void:
	if pancake_model.covered_cell_count() <= 0:
		fold_button.button_pressed = false
		tool_status_label.text = "当前没有可折叠的面饼"
		return
	if not _confirm_spread_for_next_action():
		fold_button.button_pressed = false
		return
	if fold_model.package_result != FOLD_MODEL_SCRIPT.PACKAGE_NONE or fold_model.completed_fold_count() >= 2:
		fold_button.button_pressed = false
		tool_status_label.text = "折叠阶段已完成；请选择可用包装或按 R 重置"
		return
	if p1_session != null and p1_session.phase == P1Session.Phase.SAUCE_AND_FILLINGS:
		var phase_result := p1_session.begin_folding()
		if not bool(phase_result.success):
			tool_status_label.text = str(phase_result.reason)
			return
	tool_controller.select_tool(ToolController.Tool.FOLD)


func _on_sauce_squeeze_started() -> void:
	_select_sauce_type(OrderService.SAUCE_SWEET)
	_begin_sauce_squeeze()


func _on_chili_sauce_squeeze_started() -> void:
	_select_sauce_type(OrderService.SAUCE_CHILI)
	_begin_sauce_squeeze()


func _begin_sauce_squeeze() -> void:
	if _folding_locks_preparation():
		_squeezing_sauce = false
		tool_status_label.text = "折叠已经开始；不能再挤酱"
		return
	if not _confirm_spread_for_next_action():
		_squeezing_sauce = false
		return
	if p1_session != null and p1_session.phase == P1Session.Phase.SECOND_SIDE:
		var cooking_result := p1_session.finish_cooking(pancake_model)
		if not bool(cooking_result.success):
			_squeezing_sauce = false
			tool_status_label.text = "%s；达到火候后直接点击酱瓶即可刷酱" % str(cooking_result.reason)
			return
		_refresh_p1_ui()
	if p1_session == null or p1_session.phase != P1Session.Phase.SAUCE_AND_FILLINGS:
		_squeezing_sauce = false
		tool_status_label.text = "翻面后再挤酱"
		return
	_squeezing_sauce = true
	sauce_tool_state.add(parameters.sauce_squeeze_initial_amount)
	tool_status_label.text = "正在挤%s：按住越久，饼面上的酱越多" % OrderService.sauce_display_name(current_sauce_type)
	_refresh_sauce_load_display()


func _on_sauce_squeeze_ended() -> void:
	if not _squeezing_sauce:
		return
	_squeezing_sauce = false
	tool_status_label.text = "%s已挤到饼面：待刷量 %d%%；现在拿酱刷摊开" % [OrderService.sauce_display_name(current_sauce_type), roundi(sauce_tool_state.load_ratio() * 100.0)]
	_refresh_sauce_load_display()


func _on_tool_changed(tool: ToolController.Tool) -> void:
	var preparation_locked := _folding_locks_preparation()
	var sauce_phase_locked := p1_session == null or p1_session.phase != P1Session.Phase.SAUCE_AND_FILLINGS
	ladle_button.disabled = pour_used or preparation_locked
	ladle_button.button_pressed = false
	scraper_button.disabled = preparation_locked or not _scraper_can_act()
	scraper_button.button_pressed = tool == ToolController.Tool.SCRAPER and not preparation_locked
	sauce_brush_button.disabled = preparation_locked or sauce_phase_locked
	sauce_brush_button.button_pressed = tool == ToolController.Tool.SAUCE_BRUSH and not preparation_locked
	sauce_refill_button.disabled = preparation_locked or sauce_phase_locked
	chili_sauce_refill_button.disabled = preparation_locked or sauce_phase_locked
	fold_button.disabled = fold_model.package_result != FOLD_MODEL_SCRIPT.PACKAGE_NONE or fold_model.completed_fold_count() >= 2
	fold_button.button_pressed = tool == ToolController.Tool.FOLD and not fold_button.disabled
	fold_overlay.set_guides_visible(tool == ToolController.Tool.FOLD and not fold_button.disabled)
	tool_status_label.text = "当前工具：%s" % tool_controller.display_name()
	match tool:
		ToolController.Tool.LADLE:
			pancake_surface.cursor_radius_pixels = parameters.pour_radius / float(parameters.grid_size) * pancake_surface.size.x
			pancake_surface.cursor_is_t_spreader = false
		ToolController.Tool.SCRAPER:
			pancake_surface.cursor_radius_pixels = parameters.scraper_width * 0.5 / float(parameters.grid_size) * pancake_surface.size.x
			pancake_surface.cursor_is_t_spreader = true
		ToolController.Tool.SAUCE_BRUSH:
			pancake_surface.cursor_radius_pixels = parameters.sauce_brush_radius / float(parameters.grid_size) * pancake_surface.size.x
			pancake_surface.cursor_is_t_spreader = false
		ToolController.Tool.FOLD:
			pancake_surface.cursor_radius_pixels = 18.0
			pancake_surface.cursor_is_t_spreader = false
		_:
			pancake_surface.cursor_radius_pixels = 8.0
			pancake_surface.cursor_is_t_spreader = false
	if tool != ToolController.Tool.SCRAPER:
		_spreader_angle_initialized = false
		_spreader_speed_initialized = false
	_update_spreader_artwork(0.0)
	pancake_surface.queue_redraw()
	_refresh_fold_ui()


func _update_spreader_artwork(delta: float) -> void:
	var spreader_selected := tool_controller.current_tool == ToolController.Tool.SCRAPER
	var pointer_inside := PancakeSpace.is_inside_pan(
		pancake_surface.pointer_local_position,
		pancake_surface.size,
		parameters.pan_height_ratio
	)
	spreader_artwork.visible = spreader_selected and pointer_inside
	if not spreader_artwork.visible:
		return
	var contact_position := pancake_surface.pointer_local_position
	var radial := contact_position - pancake_surface.size * 0.5
	if radial.length_squared() > 0.01:
		var target_angle := radial.angle()
		if not _spreader_angle_initialized or delta <= 0.0:
			_spreader_smoothed_angle = target_angle
			_spreader_angle_initialized = true
		else:
			var response_blend := 1.0 - exp(-delta / maxf(parameters.spreader_rotation_response_seconds, 0.001))
			var target_delta := wrapf(target_angle - _spreader_smoothed_angle, -PI, PI)
			if absf(target_delta) > parameters.spreader_rotation_dead_zone:
				var effective_delta := target_delta - signf(target_delta) * parameters.spreader_rotation_dead_zone
				var maximum_step := parameters.spreader_max_turn_rate * delta
				_spreader_smoothed_angle = wrapf(
					_spreader_smoothed_angle + clampf(effective_delta * response_blend, -maximum_step, maximum_step),
					-PI,
					PI
				)
		pancake_surface.spreader_radial_angle = _spreader_smoothed_angle
	spreader_artwork.position = contact_position
	spreader_artwork.rotation = pancake_surface.spreader_radial_angle + SPREADER_ART_ROTATION_OFFSET


func _update_spreader_speed(raw_angular_speed: float, delta: float) -> void:
	if not _spreader_speed_initialized:
		_spreader_smoothed_angular_speed = raw_angular_speed
		_spreader_speed_initialized = true
	else:
		var blend := 1.0 - exp(-delta / maxf(parameters.spreader_speed_smoothing_seconds, 0.001))
		_spreader_smoothed_angular_speed = lerpf(_spreader_smoothed_angular_speed, raw_angular_speed, blend)
	var hysteresis := parameters.spreader_speed_hysteresis
	match _spreader_speed_band:
		SPREADER_SPEED_SLOW:
			if _spreader_smoothed_angular_speed > parameters.spreader_slow_angular_speed + hysteresis:
				_spreader_speed_band = SPREADER_SPEED_MEDIUM
		SPREADER_SPEED_FAST:
			if _spreader_smoothed_angular_speed < parameters.spreader_fast_angular_speed - hysteresis:
				_spreader_speed_band = SPREADER_SPEED_MEDIUM
		_:
			if _spreader_smoothed_angular_speed < parameters.spreader_slow_angular_speed - hysteresis:
				_spreader_speed_band = SPREADER_SPEED_SLOW
			elif _spreader_smoothed_angular_speed > parameters.spreader_fast_angular_speed + hysteresis:
				_spreader_speed_band = SPREADER_SPEED_FAST


func _spreader_effect_speed() -> float:
	match _spreader_speed_band:
		SPREADER_SPEED_SLOW:
			return parameters.spreader_slow_effect_speed
		SPREADER_SPEED_FAST:
			return parameters.spreader_fast_effect_speed
		_:
			return parameters.spreader_medium_effect_speed


func _spreader_speed_label() -> String:
	match _spreader_speed_band:
		SPREADER_SPEED_SLOW:
			return "慢"
		SPREADER_SPEED_FAST:
			return "快"
		_:
			return "适中"


func _spreader_thickness_label() -> String:
	match _spreader_speed_band:
		SPREADER_SPEED_SLOW:
			return "偏薄"
		SPREADER_SPEED_FAST:
			return "偏厚"
		_:
			return "标准厚度"


func _use_paper_sleeve() -> void:
	var result: Dictionary = fold_model.package_with(FOLD_MODEL_SCRIPT.PACKAGE_SLEEVE)
	if bool(result.get("success", false)):
		tool_controller.clear_tool()
		tool_status_label.text = "纸套挽救完成：结构轻度降分"
		p1_session.mark_packaged()
	else:
		tool_status_label.text = str(result.get("reason", "纸套当前不可用"))


func _use_tray() -> void:
	var result: Dictionary = fold_model.package_with(FOLD_MODEL_SCRIPT.PACKAGE_TRAY)
	if bool(result.get("success", false)):
		tool_controller.clear_tool()
		tool_status_label.text = "托盘挽救完成：结构与便携性大幅降分"
		p1_session.mark_packaged()
	else:
		tool_status_label.text = str(result.get("reason", "托盘当前不可用"))


func _use_bag() -> void:
	var result: Dictionary = fold_model.package_with(FOLD_MODEL_SCRIPT.PACKAGE_BAG)
	if bool(result.get("success", false)):
		tool_controller.clear_tool()
		tool_status_label.text = "纸袋包装完成：可以出餐"
		p1_session.mark_packaged()
	else:
		tool_status_label.text = str(result.get("reason", "纸袋只适用于完整折叠"))


func _refresh_fold_ui() -> void:
	if not is_instance_valid(fold_status_label):
		return
	var left_visual_progress := 1.0 if fold_model.is_region_folded(FOLD_MODEL_SCRIPT.REGION_LEFT) else 0.0
	var right_visual_progress := 1.0 if fold_model.is_region_folded(FOLD_MODEL_SCRIPT.REGION_RIGHT) else 0.0
	if fold_model.active_region == FOLD_MODEL_SCRIPT.REGION_LEFT:
		left_visual_progress = float(fold_model.drag_progress)
	elif fold_model.active_region == FOLD_MODEL_SCRIPT.REGION_RIGHT:
		right_visual_progress = float(fold_model.drag_progress)
	pancake_surface.set_fold_visual_state(
		left_visual_progress,
		right_visual_progress,
		fold_model.package_result != FOLD_MODEL_SCRIPT.PACKAGE_NONE
	)
	var left: Dictionary = fold_model.get_region_result(FOLD_MODEL_SCRIPT.REGION_LEFT)
	var right: Dictionary = fold_model.get_region_result(FOLD_MODEL_SCRIPT.REGION_RIGHT)
	var left_text: String = fold_model.result_label(left) if bool(left.get("folded", false)) else "待折"
	var right_text: String = fold_model.result_label(right) if bool(right.get("folded", false)) else "待折"
	if fold_model.package_result == FOLD_MODEL_SCRIPT.PACKAGE_SLEEVE:
		fold_status_label.text = "折叠完成 · 已用纸套挽救"
	elif fold_model.package_result == FOLD_MODEL_SCRIPT.PACKAGE_TRAY:
		fold_status_label.text = "折叠失败 · 已改用托盘出餐"
	elif fold_model.package_result == FOLD_MODEL_SCRIPT.PACKAGE_BAG:
		fold_status_label.text = "折叠完整 · 已装入纸袋"
	else:
		fold_status_label.text = "左：%s · 右：%s" % [left_text, right_text]
	paper_sleeve_button.disabled = not fold_model.can_use_sleeve()
	tray_button.disabled = not fold_model.can_use_tray()
	var preparation_locked := _folding_locks_preparation()
	var sauce_phase_locked := p1_session == null or p1_session.phase != P1Session.Phase.SAUCE_AND_FILLINGS
	ladle_button.disabled = pour_used or preparation_locked
	scraper_button.disabled = preparation_locked or not _scraper_can_act()
	sauce_brush_button.disabled = preparation_locked or sauce_phase_locked
	sauce_refill_button.disabled = preparation_locked or sauce_phase_locked
	chili_sauce_refill_button.disabled = preparation_locked or sauce_phase_locked
	fold_button.disabled = fold_model.package_result != FOLD_MODEL_SCRIPT.PACKAGE_NONE or fold_model.completed_fold_count() >= 2
	bag_button.disabled = not fold_model.can_use_bag()
	if fold_model.completed_fold_count() >= 2 and fold_model.package_result == FOLD_MODEL_SCRIPT.PACKAGE_NONE and p1_session.phase == P1Session.Phase.FOLD:
		p1_session.mark_ready_for_package()
	fold_overlay.queue_redraw()


func _folding_locks_preparation() -> bool:
	return fold_model != null and (fold_model.completed_fold_count() > 0 or fold_model.package_result != FOLD_MODEL_SCRIPT.PACKAGE_NONE)


func _scraper_can_act() -> bool:
	if p1_session == null or pancake_model == null:
		return true
	if p1_session.phase == P1Session.Phase.SPREAD:
		return not _spread_shape_locked
	return p1_session.phase == P1Session.Phase.FIRST_SIDE and pancake_model.has_egg()


func _is_active_cooking_phase() -> bool:
	return p1_session != null and p1_session.phase in [
		P1Session.Phase.SPREAD,
		P1Session.Phase.FIRST_SIDE,
		P1Session.Phase.SECOND_SIDE,
	]


func _confirm_spread_for_next_action() -> bool:
	if p1_session == null or p1_session.phase != P1Session.Phase.SPREAD:
		return true
	var result := p1_session.confirm_spread(pancake_model)
	if not bool(result.get("success", false)):
		tool_status_label.text = str(result.get("reason", "请先倒入面糊"))
		return false
	tool_controller.clear_tool()
	_refresh_p1_ui()
	return true


func _auto_pour_center() -> void:
	var center := Vector2(pancake_model.grid_size - 1, pancake_model.grid_size - 1) * 0.5
	pancake_model.add_batter(center, parameters.automatic_pour_amount, parameters.automatic_pour_radius)
	pour_used = true
	_spread_shape_locked = false
	ladle_button.disabled = true
	tool_controller.select_tool(ToolController.Tool.SCRAPER)
	tool_status_label.text = "面糊已自动定量倒在鏊心；请直接画圈摊开"
	kitchen_audio.call("play_cue", &"pour")
	_refresh_p1_ui()


func _update_cooking_audio(delta: float) -> void:
	_audio_update_accumulator += delta
	if _audio_update_accumulator < 0.12:
		return
	_audio_update_accumulator = fmod(_audio_update_accumulator, 0.12)
	var cooking_phase := p1_session != null and p1_session.phase in [
		P1Session.Phase.SPREAD,
		P1Session.Phase.FIRST_SIDE,
		P1Session.Phase.SECOND_SIDE,
	]
	if not pour_used or not cooking_phase or p1_session.heat_level <= 0.02:
		kitchen_audio.call("set_sizzle", false, 0.0)
		return
	var summary := pancake_model.calculate_summary()
	var moisture := clampf(float(summary.mean_wetness), 0.0, 1.0)
	var heat := clampf(p1_session.heat_level, 0.0, 1.0)
	var intensity := clampf((0.24 + heat * 0.76) * lerpf(0.38, 1.0, moisture), 0.0, 1.0)
	kitchen_audio.call("set_sizzle", true, intensity)


func _update_surface_readout() -> void:
	var local_position := pancake_surface.pointer_local_position
	if not PancakeSpace.is_inside_pan(local_position, pancake_surface.size, parameters.pan_height_ratio):
		surface_readout_label.text = "把鼠标移入鏊面，可直接查看当前位置的面糊状态"
		return
	var cell := pan_local_to_grid(local_position)
	var covered := pancake_model.get_field_value(PancakeModel.FIELD_COVERAGE, cell)
	var cell_thickness := pancake_model.get_field_value(PancakeModel.FIELD_THICKNESS, cell)
	var cell_damage := pancake_model.get_field_value(PancakeModel.FIELD_DAMAGE, cell)
	var sauce := pancake_model.get_field_value(PancakeModel.FIELD_SAUCE_CONCENTRATION, cell)
	var chili_sauce := pancake_model.get_field_value(PancakeModel.FIELD_CHILI_SAUCE_CONCENTRATION, cell)
	var doneness := pancake_model.visible_doneness_at(pancake_model.index_of(cell))
	var description := "无面糊"
	if cell_damage >= parameters.hole_damage_threshold:
		description = "破洞"
	elif covered > 0.0:
		if cell_thickness < 0.12:
			description = "偏薄"
		elif cell_thickness < 0.45:
			description = "适中"
		elif cell_thickness < 0.9:
			description = "偏厚"
		else:
			description = "很厚"
	var pour_state := "面糊已倒完" if pour_used else "尚可倒面"
	surface_readout_label.text = "当前位置：%s（厚 %.2f · 火 %.2f · 甜酱 %.2f · 辣酱 %.2f） · %s" % [description, cell_thickness, doneness, sauce, chili_sauce, pour_state]


func _refresh_sauce_load_display() -> void:
	var score_text := "--"
	if not _last_sauce_evaluation.is_empty():
		score_text = "%d" % roundi(float(_last_sauce_evaluation.score))
	var sweet_state: RefCounted = sauce_tool_states.get(OrderService.SAUCE_SWEET)
	var chili_state: RefCounted = sauce_tool_states.get(OrderService.SAUCE_CHILI)
	var sweet_ratio: float = sweet_state.load_ratio() if sweet_state != null else 0.0
	var chili_ratio: float = chili_state.load_ratio() if chili_state != null else 0.0
	sauce_blob_overlay.call("set_amounts", sweet_ratio, chili_ratio)
	sauce_status_label.text = "%s · 饼面待刷 %d%% · 酱料评分 %s" % [OrderService.sauce_display_name(current_sauce_type), roundi(sauce_tool_state.load_ratio() * 100.0), score_text]


func _update_sauce_status() -> void:
	_last_sauce_evaluation = PANCAKE_SCORER_SCRIPT.evaluate_sauce_type(pancake_model, current_sauce_type)
	_refresh_sauce_load_display()


func _update_damage_warning(peak_damage: float, new_holes: int) -> void:
	if new_holes > 0:
		warning_label.text = "已刮破：继续刮会扩大破洞"
		warning_label.modulate = Color(1.0, 0.35, 0.28)
		warning_tone.call("trigger", true)
	elif peak_damage >= 0.65:
		warning_label.text = "危险：该区域即将破洞"
		warning_label.modulate = Color(1.0, 0.72, 0.20)
		warning_tone.call("trigger", false)
	elif peak_damage >= 0.25:
		warning_label.text = "提示：薄区正在受损"
		warning_label.modulate = Color(1.0, 0.90, 0.52)
	else:
		warning_label.text = "当前无破洞风险"
		warning_label.modulate = Color(0.76, 0.92, 0.76)


func _select_sauce_type(sauce_type: StringName) -> void:
	if not sauce_tool_states.has(sauce_type):
		return
	current_sauce_type = sauce_type
	sauce_tool_state = sauce_tool_states[sauce_type]
	_sauce_stroke_id = pancake_model.begin_sauce_stroke()
	_update_sauce_status()


func _on_heat_changed(value: float) -> void:
	if p1_session == null:
		return
	p1_session.heat_level = clampf(value / 100.0, 0.0, 1.0)
	p1_session.changed.emit()


func _advance_p1_step() -> void:
	var action_result := {"success": false, "reason": "当前步骤尚未完成"}
	match p1_session.phase:
		P1Session.Phase.SPREAD:
			tool_status_label.text = "摊好后直接选择鸡蛋或下一项操作"
			return
		P1Session.Phase.FIRST_SIDE:
			action_result = p1_session.request_flip(pancake_model, ingredient_model)
			if bool(action_result.success):
				tool_controller.clear_tool()
				tool_status_label.text = "翻面完成：现在直接挤酱并放入小料"
				kitchen_audio.call("play_cue", &"flip")
		P1Session.Phase.SECOND_SIDE:
			action_result = p1_session.finish_cooking(pancake_model)
			if bool(action_result.success):
				tool_status_label.text = "火候确认：现在刷酱并放入订单配料"
		P1Session.Phase.SAUCE_AND_FILLINGS:
			action_result = p1_session.begin_folding()
			if bool(action_result.success):
				_select_fold()
		P1Session.Phase.FOLD, P1Session.Phase.PACKAGE:
			tool_status_label.text = "先完成两侧折叠，再选择纸袋、纸套或托盘"
		P1Session.Phase.READY_TO_SERVE:
			tool_status_label.text = "点击鏊子上的包装成品，把餐递给顾客"
			return
		P1Session.Phase.HANDOFF, P1Session.Phase.PAYMENT:
			tool_status_label.text = "顾客正在接餐并付款"
			return
		P1Session.Phase.RESULT:
			tool_status_label.text = "可查看本单小结，或继续接待下一位顾客"
			return
	if not bool(action_result.get("success", false)):
		tool_status_label.text = str(action_result.get("reason", "当前步骤尚未完成"))
	_refresh_p1_ui()


func _on_ingredient_gui_input(event: InputEvent, ingredient_type: StringName) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	_begin_ingredient_drag(ingredient_type, get_viewport().get_mouse_position())


func _connect_ingredient_slot(slot: Button, ingredient_type: StringName) -> void:
	if slot.has_signal("drag_requested"):
		slot.connect("drag_requested", _begin_ingredient_drag)
	else:
		slot.gui_input.connect(_on_ingredient_gui_input.bind(ingredient_type))


func _begin_ingredient_drag(ingredient_type: StringName, press_position: Vector2) -> void:
	if not _confirm_spread_for_next_action():
		return
	if not ingredient_stock_model.has_stock(ingredient_type):
		tool_status_label.text = "%s托盘已经空了，请原地长按当前小料盘补货" % IngredientModel.display_name(ingredient_type)
		return
	if ingredient_model.has_type(ingredient_type):
		tool_status_label.text = "%s已经放过一份" % IngredientModel.display_name(ingredient_type)
		return
	if p1_session.phase != P1Session.Phase.FIRST_SIDE and p1_session.phase != P1Session.Phase.SAUCE_AND_FILLINGS:
		tool_status_label.text = "当前步骤不能放配料"
		return
	_ingredient_drag_type = ingredient_type
	_ingredient_drag_start = press_position
	ingredient_drag_preview.texture = _ingredient_texture(ingredient_type)
	ingredient_drag_preview.visible = true
	ingredient_drag_preview.global_position = _ingredient_drag_start - ingredient_drag_preview.size * 0.5
	tool_status_label.text = "拖动%s到饼面后松开" % IngredientModel.display_name(ingredient_type)


func _input(event: InputEvent) -> void:
	if _ingredient_drag_type == &"":
		return
	if event is InputEventMouseMotion:
		ingredient_drag_preview.global_position = event.position - ingredient_drag_preview.size * 0.5
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_ingredient_drag(event.position)
		get_viewport().set_input_as_handled()


func _finish_ingredient_drag(viewport_position: Vector2) -> void:
	ingredient_drag_preview.visible = false
	var spent_ingredient := _ingredient_drag_type
	if not ingredient_stock_model.consume(spent_ingredient):
		tool_status_label.text = "%s托盘已经空了，无法继续放置" % IngredientModel.display_name(spent_ingredient)
		_ingredient_drag_type = &""
		_refresh_p1_ui()
		return
	var local_position := pancake_surface.get_global_transform_with_canvas().affine_inverse() * viewport_position
	if not PancakeSpace.is_inside_pan(local_position, pancake_surface.size, parameters.pan_height_ratio):
		tool_status_label.text = "配料没有落在鏊面内，本次用料已损耗"
		_ingredient_drag_type = &""
		return
	var grid_position := PancakeSpace.local_to_grid_position(local_position, pancake_surface.size, pancake_model.grid_size)
	var rotation := (viewport_position - _ingredient_drag_start).angle()
	var result := {"success": false, "reason": "配料未能放置"}
	if _ingredient_drag_type == IngredientModel.EGG:
		var egg_validation := pancake_model.can_crack_egg(grid_position)
		if bool(egg_validation.success):
			result = ingredient_model.place(_ingredient_drag_type, grid_position, rotation, pancake_model)
			if bool(result.success):
				var crack_result := pancake_model.crack_egg(grid_position)
				if not bool(crack_result.success):
					result = crack_result
		else:
			result = egg_validation
	else:
		result = ingredient_model.place(_ingredient_drag_type, grid_position, rotation, pancake_model)
	if bool(result.success):
		if _ingredient_drag_type == IngredientModel.EGG:
			egg_crack_artwork.position = local_position
			egg_crack_artwork.rotation = 0.0
			egg_crack_artwork.visible = true
			tool_controller.select_tool(ToolController.Tool.SCRAPER)
			tool_status_label.text = "鸡蛋已打入；用 T 形摊面器连续画圈摊开蛋黄和蛋白"
		else:
			tool_status_label.text = "%s已放到饼面，可继续调整下一种配料" % IngredientModel.display_name(_ingredient_drag_type)
	else:
		tool_status_label.text = "%s；本次用料已损耗" % str(result.reason)
	_ingredient_drag_type = &""
	_refresh_p1_ui()


func _ingredient_texture(ingredient_type: StringName) -> Texture2D:
	match ingredient_type:
		IngredientModel.EGG:
			return ingredient_layer.egg_texture
		IngredientModel.BAOCUI:
			return ingredient_layer.baocui_texture
		IngredientModel.HAM_SAUSAGE:
			return ingredient_layer.ham_texture
		IngredientModel.SCALLION:
			return ingredient_layer.scallion_texture
	return null


func _saved_ingredient_stock() -> Dictionary:
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("ingredient_stock_snapshot"):
		return Dictionary(session.call("ingredient_stock_snapshot"))
	return {}


func _persist_ingredient_stock() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("save_ingredient_stock"):
		session.call("save_ingredient_stock", ingredient_stock_model.snapshot())


func _on_ingredient_stock_changed(_ingredient_type: StringName, _current_stock: int) -> void:
	_refresh_ingredient_stock_ui()
	_persist_ingredient_stock()
	_refresh_p1_ui()


func _restock_ingredient(ingredient_type: StringName) -> void:
	if not ingredient_stock_model.refill(ingredient_type):
		tool_status_label.text = "%s托盘现在是满的" % IngredientModel.display_name(ingredient_type)
		return
	tool_status_label.text = "%s已从备料容器补满" % IngredientModel.display_name(ingredient_type)


func _refresh_ingredient_stock_ui() -> void:
	var slots := {
		IngredientModel.EGG: egg_button,
		IngredientModel.BAOCUI: baocui_button,
		IngredientModel.HAM_SAUSAGE: ham_button,
		IngredientModel.SCALLION: scallion_button,
	}
	var restock_buttons := {
		IngredientModel.EGG: egg_restock_button,
		IngredientModel.BAOCUI: baocui_restock_button,
		IngredientModel.HAM_SAUSAGE: ham_restock_button,
		IngredientModel.SCALLION: scallion_restock_button,
	}
	for ingredient_type in IngredientModel.TYPES:
		var current_stock: int = ingredient_stock_model.current(ingredient_type)
		(slots[ingredient_type] as Button).call("set_stock_quantity", current_stock)
		var restock_button := restock_buttons[ingredient_type] as Button
		var legacy_rack_visible := (restock_button.get_parent() as CanvasItem).visible
		restock_button.disabled = not legacy_rack_visible or current_stock >= INGREDIENT_STOCK_MODEL_SCRIPT.CAPACITY
		restock_button.mouse_filter = Control.MOUSE_FILTER_STOP if legacy_rack_visible else Control.MOUSE_FILTER_IGNORE
		restock_button.tooltip_text = "托盘已满" if legacy_rack_visible and restock_button.disabled else ""


func _serve_order() -> void:
	if p1_session.phase != P1Session.Phase.READY_TO_SERVE:
		tool_status_label.text = "完成折叠和包装后，点击鏊子上的成品出餐"
		return
	var score_result := PANCAKE_SCORER_SCRIPT.evaluate_order(
		pancake_model,
		ingredient_model,
		fold_model,
		p1_session.order,
		p1_session.elapsed_seconds,
		p1_session.patience_ratio()
	)
	var handoff_result := p1_session.begin_handoff(score_result)
	if not bool(handoff_result.get("success", false)):
		tool_status_label.text = str(handoff_result.get("reason", "当前不能递餐"))
		return
	_populate_result(score_result)
	serve_product_button.visible = false
	handoff_product_sprite.texture = fold_overlay.current_package_texture()
	handoff_product_sprite.position = Vector2(810.0, 590.0)
	handoff_product_sprite.size = Vector2(300.0, 300.0)
	handoff_product_sprite.modulate = Color.WHITE
	handoff_product_sprite.visible = true
	fold_overlay.visible = false
	pancake_visual.visible = false
	ingredient_layer.visible = false
	sauce_blob_overlay.visible = false
	egg_crack_artwork.visible = false
	tool_status_label.text = "正在把餐递给顾客"
	if _handoff_tween != null and _handoff_tween.is_valid():
		_handoff_tween.kill()
	_handoff_tween = create_tween()
	_handoff_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_handoff_tween.parallel().tween_property(handoff_product_sprite, "position", Vector2(885.0, 255.0), 0.48)
	_handoff_tween.parallel().tween_property(handoff_product_sprite, "size", Vector2(150.0, 150.0), 0.48)
	_handoff_tween.parallel().tween_property(handoff_product_sprite, "modulate:a", 0.25, 0.48)
	_handoff_tween.tween_callback(_complete_handoff_animation)
	kitchen_audio.call("set_sizzle", false, 0.0)
	kitchen_audio.call("play_cue", &"serve")
	_refresh_p1_ui()


func _complete_handoff_animation() -> void:
	if p1_session.phase != P1Session.Phase.HANDOFF:
		return
	handoff_product_sprite.visible = false
	var payment_result := p1_session.begin_payment()
	if not bool(payment_result.get("success", false)):
		return
	var reaction := p1_session.post_handoff_reaction()
	_set_customer_portrait_state(&"accepting_bag" if reaction == P1Session.REACTION_SATISFIED else reaction)
	tool_status_label.text = "顾客已经接到纸袋"
	var hold_tween := create_tween()
	hold_tween.tween_interval(0.55)
	hold_tween.tween_callback(_show_customer_payment)


func _show_customer_payment() -> void:
	if p1_session.phase != P1Session.Phase.PAYMENT or _payment_animation_active:
		return
	var reaction := p1_session.post_handoff_reaction()
	_set_customer_portrait_state(&"paying_coins" if reaction == P1Session.REACTION_SATISFIED else reaction)
	_current_payment_amount = _order_payment_coins(p1_session.order)
	_current_payment_denominations = PAYMENT_COIN_MODEL_SCRIPT.decompose(_current_payment_amount)
	_payment_animation_active = true
	_spawn_payment_flight(_current_payment_denominations)
	tool_status_label.text = "顾客正在支付 %d 金币" % _current_payment_amount
	if _payment_tween != null and _payment_tween.is_valid():
		_payment_tween.kill()
	_payment_tween = create_tween()
	_payment_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_payment_tween.set_parallel(true)
	for index in _payment_flight_sprites.size():
		var coin := _payment_flight_sprites[index]
		var delay := float(index) * 0.06
		_payment_tween.tween_property(coin, "position", _payment_coin_target(payment_coin_model.pending_denominations.size() + index), 0.55).set_delay(delay)
		_payment_tween.tween_property(coin, "size", PAYMENT_SLOT_COIN_SIZE, 0.55).set_delay(delay)
	_payment_tween.chain().tween_callback(_complete_payment_animation)


func _complete_payment_animation() -> void:
	if p1_session.phase != P1Session.Phase.PAYMENT or not _payment_animation_active:
		return
	_payment_animation_active = false
	var payment_result := p1_session.finish_payment()
	if not bool(payment_result.get("success", false)):
		return
	var game_session := get_node_or_null("/root/GameSession")
	if game_session != null:
		game_session.call("record_order_completed", p1_session.order, p1_session.result, _current_payment_amount)
	summary_score_label.text = "本单 %d分 · +%d金币" % [roundi(float(p1_session.result.get("score", 0.0))), _current_payment_amount]
	summary_feedback_label.text = str(p1_session.result.get("feedback", "本单已完成"))
	_result_detail_open = false
	_order_summary_visible = true
	payment_coin_model.add_payment(_current_payment_amount)
	_pending_payment_sprites.append_array(_payment_flight_sprites)
	_payment_flight_sprites.clear()
	_layout_pending_payment_sprites()
	_current_payment_denominations.clear()
	_current_payment_amount = 0
	_payment_waiting_collection = payment_coin_model.has_pending()
	payment_collection_area.visible = true
	payment_collection_area.tooltip_text = "待收取 %d 金币：点击或将鼠标扫过收款槽" % payment_coin_model.pending_total
	_start_next_order()
	tool_status_label.text = "下一位顾客已到摊前；收款槽中待收取 %d 金币" % payment_coin_model.pending_total


func _collect_payment() -> void:
	if not payment_coin_model.has_pending():
		return
	var collected: int = int(payment_coin_model.collect_all())
	_payment_waiting_collection = false
	payment_collection_area.visible = false
	for coin in _pending_payment_sprites:
		if is_instance_valid(coin):
			coin.queue_free()
	_pending_payment_sprites.clear()
	var game_session := get_node_or_null("/root/GameSession")
	if game_session != null and game_session.has_method("credit_coins"):
		game_session.call("credit_coins", collected)
	tool_status_label.text = "已一次收取 %d 金币；当前顾客订单继续" % collected


func _spawn_payment_flight(denominations: Array[int]) -> void:
	_payment_flight_sprites.clear()
	for index in denominations.size():
		var denomination := denominations[index]
		var coin := payment_sprite.duplicate() as TextureRect
		coin.name = "PaymentCoin%d_%d" % [denomination, payment_coin_layer.get_child_count()]
		coin.unique_name_in_owner = false
		coin.texture = PAYMENT_COIN_TEXTURES[denomination]
		coin.position = PAYMENT_COIN_START_POSITION + Vector2(float(index) * 24.0, float(index % 2) * 10.0)
		coin.size = PAYMENT_COIN_START_SIZE
		coin.modulate = Color.WHITE
		coin.visible = true
		payment_coin_layer.add_child(coin)
		_payment_flight_sprites.append(coin)


func _layout_pending_payment_sprites() -> void:
	for index in _pending_payment_sprites.size():
		var coin := _pending_payment_sprites[index]
		if is_instance_valid(coin):
			coin.position = _payment_coin_target(index)
			coin.size = PAYMENT_SLOT_COIN_SIZE


func _payment_coin_target(index: int) -> Vector2:
	var column := index % PAYMENT_SLOT_MAX_COLUMNS
	var row := floori(float(index) / float(PAYMENT_SLOT_MAX_COLUMNS)) % 2
	return PAYMENT_SLOT_ORIGIN + Vector2(float(column) * PAYMENT_SLOT_COLUMN_SPACING, float(row) * PAYMENT_SLOT_ROW_SPACING)


func _order_payment_coins(order: Dictionary) -> int:
	return maxi(int(order.get("payment_coins", DEFAULT_ORDER_COINS)), 1)


func _populate_result(score_result: Dictionary) -> void:
	result_title_label.text = "顾客评价 · %d分" % roundi(float(score_result.score))
	var dimensions: Dictionary = score_result.dimensions
	result_detail_label.text = str(score_result.feedback)
	integrity_score_label.text = "完整度  %d" % roundi(float(dimensions.integrity))
	thickness_score_label.text = "厚薄  %d" % roundi(float(dimensions.thickness))
	heat_score_label.text = "火候  %d" % roundi(float(dimensions.heat))
	egg_score_label.text = "摊蛋  %d" % roundi(float(dimensions.egg))
	sauce_score_label.text = "酱料  %d" % roundi(float(dimensions.sauce))
	ingredient_score_label.text = "配料  %d" % roundi(float(dimensions.ingredients))
	fold_score_label.text = "折叠  %d" % roundi(float(dimensions.fold))
	order_score_label.text = "订单  %d" % roundi(float(dimensions.order))
	time_score_label.text = "时间  %d" % roundi(float(dimensions.time))
	var result_tags: String = " · ".join(score_result.tags)
	result_tags_label.text = "亮点与问题：%s" % (result_tags if not result_tags.is_empty() else "暂无")


func _start_next_order() -> void:
	reset_pancake()
	var next_customer: Dictionary = customer_queue.advance_queue()
	p1_session.start(next_customer.order)
	_refresh_p1_ui()


func _open_result_detail() -> void:
	if not _order_summary_visible:
		return
	_result_detail_open = true
	_refresh_p1_ui()


func _close_result_detail() -> void:
	_result_detail_open = false
	_refresh_p1_ui()


func _dismiss_order_summary() -> void:
	_order_summary_visible = false
	_result_detail_open = false
	_refresh_p1_ui()


func end_business_day() -> void:
	var game_session := get_node_or_null("/root/GameSession")
	var bill := {"day": 1, "orders": [], "order_count": 0, "total_coins": 0, "average_score": 0.0}
	if game_session != null:
		bill = game_session.call("end_business_day")
	_populate_daily_bill(bill)
	result_panel.visible = false
	order_summary_card.visible = false
	daily_bill_panel.visible = true


func _populate_daily_bill(bill: Dictionary) -> void:
	daily_bill_title_label.text = "第%d日 · 今日账单" % int(bill.get("day", 1))
	daily_bill_stats_label.text = "完成 %d 单 · 收入 %d 金币 · 平均 %d分" % [
		int(bill.get("order_count", 0)),
		int(bill.get("total_coins", 0)),
		roundi(float(bill.get("average_score", 0.0))),
	]
	for child in daily_bill_rows.get_children():
		child.queue_free()
	var entries: Array = bill.get("orders", [])
	if entries.is_empty():
		_add_bill_row("—", "今天还没有完成订单", "—", "0金币")
		return
	for index in entries.size():
		var entry: Dictionary = entries[index]
		_add_bill_row(
			str(index + 1),
			str(entry.get("title", "未命名订单")),
			"%d分" % int(entry.get("score", 0)),
			"+%d金币" % int(entry.get("coins", 0))
		)


func _add_bill_row(index_text: String, title_text: String, score_text: String, income_text: String) -> void:
	var values := [index_text, title_text, score_text, income_text]
	var widths := [100.0, 480.0, 140.0, 170.0]
	for column in values.size():
		var label := Label.new()
		label.custom_minimum_size = Vector2(widths[column], 46.0)
		label.text = values[column]
		label.add_theme_font_size_override("font_size", 19)
		label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.79))
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if column == 1 else (HORIZONTAL_ALIGNMENT_RIGHT if column == 3 else HORIZONTAL_ALIGNMENT_CENTER)
		daily_bill_rows.add_child(label)


func _close_daily_bill() -> void:
	daily_bill_panel.visible = false
	daily_bill_closed.emit()


func _refresh_p1_ui() -> void:
	if p1_session == null or p1_session.order.is_empty():
		return
	order_text_label.text = OrderService.format_requirements(p1_session.order)
	customer_line_label.text = "“%s”" % str(p1_session.order.customer_line)
	patience_bar.value = p1_session.patience_ratio() * 100.0
	phase_label.text = "当前步骤：%s · 已用时 %.0f秒" % [p1_session.phase_label(), p1_session.elapsed_seconds]
	heat_label.text = "火力 %d%%" % roundi(p1_session.heat_level * 100.0)
	if not heat_slider.has_focus():
		heat_slider.value = p1_session.heat_level * 100.0
	match p1_session.phase:
		P1Session.Phase.SPREAD:
			step_action_button.text = ""
		P1Session.Phase.FIRST_SIDE:
			step_action_button.text = "翻面"
		P1Session.Phase.SECOND_SIDE:
			step_action_button.text = "确认火候"
		P1Session.Phase.SAUCE_AND_FILLINGS:
			step_action_button.text = "开始折叠"
		P1Session.Phase.FOLD, P1Session.Phase.PACKAGE:
			step_action_button.text = "完成折叠并选择包装"
		P1Session.Phase.READY_TO_SERVE:
			step_action_button.text = ""
		P1Session.Phase.HANDOFF, P1Session.Phase.PAYMENT:
			step_action_button.text = ""
		P1Session.Phase.RESULT:
			step_action_button.text = ""
	serve_button.visible = false
	var packaging_phase := p1_session.phase == P1Session.Phase.PACKAGE
	packaging_choices.visible = packaging_phase
	heat_label.visible = not packaging_phase
	heat_slider.visible = not packaging_phase
	step_action_button.visible = p1_session.phase in [
		P1Session.Phase.FIRST_SIDE,
		P1Session.Phase.SECOND_SIDE,
		P1Session.Phase.SAUCE_AND_FILLINGS,
		P1Session.Phase.FOLD,
	]
	step_action_button.disabled = false
	serve_product_button.visible = p1_session.phase == P1Session.Phase.READY_TO_SERVE
	var transaction_phase := p1_session.phase in [P1Session.Phase.HANDOFF, P1Session.Phase.PAYMENT, P1Session.Phase.RESULT]
	p1_control_bar.visible = not transaction_phase and not _result_detail_open
	result_panel.visible = _result_detail_open
	order_summary_card.visible = _order_summary_visible and not _result_detail_open
	customer_line_label.visible = not _result_detail_open
	phase_label.visible = not _result_detail_open
	if p1_session.phase == P1Session.Phase.RESULT:
		_set_customer_portrait_state(p1_session.post_handoff_reaction())
	elif p1_session.phase not in [P1Session.Phase.HANDOFF, P1Session.Phase.PAYMENT] and p1_session.is_impatient_now():
		_set_customer_portrait_state(P1Session.REACTION_IMPATIENT)
	elif p1_session.phase not in [P1Session.Phase.HANDOFF, P1Session.Phase.PAYMENT]:
		_set_customer_portrait_state(P1Session.REACTION_NEUTRAL)
	_refresh_customer_queue()
	var spread_can_continue := p1_session.phase == P1Session.Phase.SPREAD and pancake_model.covered_cell_count() > 0
	egg_button.disabled = false
	scraper_button.disabled = _folding_locks_preparation() or not _scraper_can_act()
	baocui_button.disabled = false
	ham_button.disabled = not ham_button.visible
	scallion_button.disabled = false
	var sauce_phase_locked := p1_session.phase != P1Session.Phase.SAUCE_AND_FILLINGS
	var sauce_action_locked := sauce_phase_locked and not spread_can_continue
	sauce_brush_button.disabled = sauce_action_locked or _folding_locks_preparation()
	sauce_refill_button.disabled = sauce_action_locked or _folding_locks_preparation()
	chili_sauce_refill_button.disabled = sauce_action_locked or _folding_locks_preparation()


func _current_customer_texture(state: StringName) -> Texture2D:
	var customer_id := StringName(customer_queue.current_customer().get("id", &"customer_01"))
	var customer_textures: Dictionary = CUSTOMER_TEXTURES.get(customer_id, CUSTOMER_TEXTURES[&"customer_01"])
	return customer_textures.get(state, customer_textures[&"neutral"])


func _set_customer_portrait_state(state: StringName) -> void:
	var texture_state := P1Session.REACTION_IMPATIENT if state == P1Session.REACTION_VERY_UNHAPPY else state
	var target_texture := _current_customer_texture(texture_state)
	if _customer_visual_state == state and customer_portrait.texture == target_texture:
		return
	_customer_visual_state = state
	if _customer_reaction_tween != null and _customer_reaction_tween.is_valid():
		_customer_reaction_tween.kill()
	customer_portrait.texture = target_texture
	customer_portrait.pivot_offset = customer_portrait.size * 0.5
	customer_portrait.rotation = 0.0
	customer_portrait.modulate = Color.WHITE
	if state != P1Session.REACTION_VERY_UNHAPPY:
		return
	customer_portrait.modulate = Color(1.0, 0.68, 0.68, 1.0)
	_customer_reaction_tween = create_tween()
	_customer_reaction_tween.tween_property(customer_portrait, "rotation", 0.035, 0.06)
	_customer_reaction_tween.tween_property(customer_portrait, "rotation", -0.035, 0.08)
	_customer_reaction_tween.tween_property(customer_portrait, "rotation", 0.025, 0.07)
	_customer_reaction_tween.tween_property(customer_portrait, "rotation", -0.018, 0.07)
	_customer_reaction_tween.tween_property(customer_portrait, "rotation", 0.0, 0.08)


func _refresh_customer_queue() -> void:
	var waiting: Array = customer_queue.waiting_customers()
	queue_status_label.text = "排队中 · %d位" % waiting.size()
	for index in waiting_customer_portraits.size():
		var portrait := waiting_customer_portraits[index]
		portrait.visible = index < waiting.size()
		if portrait.visible:
			var customer_id := StringName(waiting[index].get("id", &"customer_01"))
			var customer_textures: Dictionary = CUSTOMER_TEXTURES.get(customer_id, CUSTOMER_TEXTURES[&"customer_01"])
			portrait.texture = customer_textures[&"neutral"]


func _log_info(category: StringName, message: String) -> void:
	var logger := get_node_or_null("/root/AppLog")
	if logger != null and logger.has_method("info"):
		logger.info(category, message)
	else:
		print("[ProjectCake][%s] %s" % [category, message])


func _pan_polar_offset(grid_position: Vector2) -> Vector2:
	var center := Vector2(pancake_model.grid_size - 1, pancake_model.grid_size - 1) * 0.5
	var offset := grid_position - center
	return Vector2(offset.x, offset.y / maxf(parameters.pan_height_ratio, 0.01))


func _limit_egg_samples(raw_samples: PackedVector2Array) -> PackedVector2Array:
	var budget := maxi(parameters.egg_max_samples_per_frame, 1)
	if raw_samples.size() <= budget:
		return raw_samples
	var limited := PackedVector2Array()
	for sample_index in budget:
		var source_index := roundi(float(sample_index) * float(raw_samples.size() - 1) / float(maxi(budget - 1, 1)))
		limited.append(raw_samples[source_index])
	return limited
