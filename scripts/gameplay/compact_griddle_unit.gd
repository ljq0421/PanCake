class_name CompactGriddleUnit
extends Control

signal main_action_requested(unit_index: int)
signal status_message_requested(message: String)
signal transient_warning_requested(message: String)
signal packaging_finished(unit_index: int)
signal fold_feedback_requested(unit_index: int, feedback_kind: StringName)
signal ready_product_clicked(source_ref: Dictionary)

const GRID_SIZE := 64
const REFERENCE_GRID_SIZE := 128.0
const PANCAKE_MODEL_SCRIPT := preload("res://scripts/simulation/pancake_model.gd")
const INGREDIENT_MODEL_SCRIPT := preload("res://scripts/gameplay/ingredient_model.gd")
const FOLD_MODEL_SCRIPT := preload("res://scripts/gameplay/pancake_fold_model.gd")
const P1_SESSION_SCRIPT := preload("res://scripts/gameplay/p1_session.gd")
const PANCAKE_SCORER_SCRIPT := preload("res://scripts/gameplay/pancake_scorer.gd")
const COOKING_STAGE_BAR_SCRIPT := preload("res://scripts/ui/cooking_stage_bar.gd")
const READY_DRAG_TEXTURE := preload("res://resources/art/workstation/packaging/paper_bag_package_v1.png")
const PANCAKE_PACKAGE_INGREDIENT_GRID := preload("res://scripts/ui/pancake_package_ingredient_grid.gd")
const PHYSICAL_HOVER_MODULATE := Color(1.18, 1.13, 0.96, 1.0)
const SPREADER_NORMAL := preload("res://resources/art/workstation/tools/batter_spreader_upgrade_v1_five_area_v2.png")
const SPREADER_WIDE := preload("res://resources/art/workstation/tools/batter_spreader_upgrade_v1_five_area_v2.png")
const SAUCE_BRUSH_TEXTURE := preload("res://resources/art/workstation/tools/sauce_brush_v1_five_area_v2.png")
const DISABLE_SPREADER_VISUAL_ARGUMENT := "--disable-spreader-visual"
const HARDWARE_SPREADER_CURSOR_SIZE := Vector2i(96, 96)
const HARDWARE_SPREADER_SOURCE_OFFSET := Vector2(19.0, 113.0)
const SAUCE_BRUSH_ART_ROTATION_OFFSET := 1.02
const MIN_BATTER_AMOUNT := 1.5
const STANDARD_BATTER_AMOUNT := 4.0
const MAX_BATTER_AMOUNT := 6.5
const INITIAL_BATTER_AMOUNT := STANDARD_BATTER_AMOUNT
const INITIAL_BATTER_RADIUS := 14.0
const SPREADER_SAMPLE_SPACING := 2.5
## Each compact radial sample already sweeps from the pan center to the current
## contact point. Replaying every interpolated pointer sample in one frame can
## turn a single fast move into a 40+ ms feedback loop, so only the newest path
## representative is simulated; pointer sampling remains fully event-driven.
const MAX_SPREAD_SIMULATION_SAMPLES_PER_FRAME := 1
const HEAT_SUITABLE_MIN := PANCAKE_SCORER_SCRIPT.HEAT_SUITABLE_MIN
const HEAT_CHARRED_MIN := PANCAKE_SCORER_SCRIPT.HEAT_CHARRED_MIN
## The non-burning upgrade must stop just below the exclusive charred boundary.
const NON_BURNING_DONENESS_CAP := HEAT_CHARRED_MIN - 0.001
## The fast-cook griddle is intentionally a second-stage upgrade.  It halves
## real-time cooking waits while the non-burning cap still protects the result.
const FAST_COOK_HEAT_MULTIPLIER := 2.0
## A single pointer sample used to invoke the full field simulation once per
## radial segment (up to fourteen times). Representative weighted anchors keep
## the same total spread force without stalling the input frame.
const MAX_RADIAL_SWEEP_ANCHORS := 3
const EGG_SAMPLE_SPACING := 3.0
const SPREADER_CENTER_DEAD_ZONE := 4.0
const SPREADER_INWARD_TOLERANCE := 20.0
const SPREADER_DIRECTION_GRACE_SAMPLES := 12
const SPREADER_SPEED_SMOOTHING_SECONDS := 0.14
const SPREADER_ROTATION_RESPONSE_SECONDS := 0.10
const SPREADER_MAX_TURN_RATE := 8.0
const SPREADER_ROTATION_DEAD_ZONE := 0.06
const SPREADER_SPEED_SLOW := -1
const SPREADER_SPEED_MEDIUM := 0
const SPREADER_SPEED_FAST := 1
## Manual batter spreading is intentionally a gesture check, not a precision
## simulation challenge. Once the held spreader travels almost one complete
## revolution in either direction, the batter is normalized into the standard
## pancake shape. The small tolerance keeps players from having to land on the
## exact pixel where the circle began.
const SPREADER_CIRCLE_REQUIRED_ANGLE := TAU * 0.90
const EGG_CRACK_EFFECT_BASE_SCALE := Vector2(0.45, 0.45)
const EGG_SHELL_CLEARANCE := 60.0
## EggShellVisual crops a 128 px-tall texture and renders at 0.45 scale. Move
## its center by the half-height too, so its *bottom edge* remains 60 px above
## the pancake instead of appearing to rest on it.
const EGG_SHELL_HALF_HEIGHT := 28.8
const EGG_CRACK_STAGE_OFFSET := Vector2(0.0, -(EGG_SHELL_CLEARANCE + EGG_SHELL_HALF_HEIGHT))
const EGG_LIQUID_FALL_DURATION := 0.22
const EGG_INTACT_VISUAL_SCALE := Vector2(0.25, 0.25)
const SURFACE_ACTION_NONE: StringName = &""
const SURFACE_ACTION_POUR_BATTER: StringName = &"pour_batter"
const SURFACE_ACTION_SPREAD_BATTER: StringName = &"spread_batter"
const SURFACE_ACTION_SPREAD_EGG: StringName = &"spread_egg"
const SURFACE_ACTION_BRUSH_SAUCE: StringName = &"brush_sauce"
const AUTO_FOLD_PAUSE_DURATION := 0.03
const BATTER_POUR_RATE := 5.0
const MIN_BATTER_POUR_AMOUNT := 1.5
const MIN_BATTER_POUR_RADIUS := 4.0
const MAX_BATTER_POUR_RADIUS := float(GRID_SIZE) * 0.5 - 1.0
const BEST_BATTER_INNER_RADIUS := INITIAL_BATTER_RADIUS - 2.0
const BEST_BATTER_OUTER_RADIUS := INITIAL_BATTER_RADIUS

enum State { IDLE, BATTER, FIRST_SIDE, SECOND_SIDE, GARNISH, FOLDING, READY }

@onready var state_label: Label = %StateLabel
@onready var griddle_art: TextureRect = %GriddleArt
@onready var pancake_surface: PancakeHeatmap = %PancakeSurface
@onready var pancake_visual: TextureRect = %PancakeVisual
@onready var ingredient_layer: IngredientLayer = %IngredientLayer
@onready var fold_overlay: PancakeFoldOverlay = %PancakeFoldOverlay
@onready var egg_crack_effect: AnimatedSprite2D = %EggCrackEffect
@onready var egg_shell_visual: Sprite2D = %EggShellVisual
@onready var egg_intact_visual: Sprite2D = %EggIntactVisual
@onready var egg_intact_visual_second: Sprite2D = %EggIntactVisualSecond
@onready var sauce_brush_artwork: Sprite2D = %SauceBrushArtwork
@onready var package_visual: TextureRect = %PackageVisual
@onready var main_action: Button = %MainAction
@onready var heat_bar = %HeatBar
@onready var heat_status_label: Label = %HeatStatusLabel

var unit_index := 0
var state: State = State.IDLE
var order: Dictionary = {}
var first_side_seconds := 0.0
var second_side_seconds := 0.0
var fold_steps := 0
var applied_sauce_ids := PackedStringArray()
var applied_ingredient_ids := PackedStringArray()
## Set only after the automation has completed its physical spreading pass.
## This persists so delayed delivery cannot lose the upgrade's quality benefit.
var egg_automation_applied := false
## Set when the automatic sauce pass completes; retained for customer review.
var sauce_automation_applied := false
## The measured ladle and press together guarantee the standard pancake thickness.
var automatic_batter_ladle_applied := false
var press_spreader_applied := false
var ready_product: Dictionary = {}
var upgrade_locked := false
var _non_burning_upgrade_enabled := false
var _fast_cook_upgrade_enabled := false
var pancake_model: PancakeModel = PANCAKE_MODEL_SCRIPT.new(GRID_SIZE, _compact_pancake_parameters())
var ingredient_model: IngredientModel = INGREDIENT_MODEL_SCRIPT.new()
var fold_model: PancakeFoldModel = FOLD_MODEL_SCRIPT.new(pancake_model, ingredient_model)
var p1_session: P1Session = P1_SESSION_SCRIPT.new()
var _spread_previous_grid := Vector2.ZERO
var _spread_has_previous := false
var _display_name := "主鏊"
var _package_selection_outline: Panel
var _package_ingredient_grid: PancakePackageIngredientGrid
var _surface_action: StringName = SURFACE_ACTION_NONE
var _surface_stock_id: StringName = &""
var _surface_changed := false
var _surface_width_multiplier := 1.0
var _sauce_stroke_id := -1
var _batter_pour_center := Vector2.ZERO
var _batter_pour_amount := 0.0
var _batter_thickness_warning_sent := false
var _batter_ladle_armed := false
var _last_tool_direction := Vector2(0.45, 0.89).normalized()
var _scrape_sampler := StrokeSampler.new(SPREADER_SAMPLE_SPACING)
var _egg_sampler := StrokeSampler.new(EGG_SAMPLE_SPACING)
var _previous_scrape_sample := Vector2.ZERO
var _last_process_grid_position := Vector2.ZERO
var _spreader_max_radius := 0.0
var _spreader_direction_grace_remaining := 0
var _spreader_smoothed_angular_speed := 0.0
var _spreader_speed_initialized := false
var _spreader_speed_band := SPREADER_SPEED_MEDIUM
var _spreader_smoothed_angle := 0.0
var _spreader_angle_initialized := false
var _spreader_circle_progress := 0.0
var _spreader_circle_direction := 0.0
var _spreader_circle_previous_angle := 0.0
var _spreader_circle_has_previous := false
var _egg_crack_tween: Tween
var _egg_liquid_falling := false
var _intact_egg_local_override := Vector2.ZERO
var _has_intact_egg_local_override := false
var spreader_visual_enabled := true
var _hardware_spreader_cursor_normal: Texture2D
var _hardware_spreader_cursor_wide: Texture2D
var _hardware_spreader_cursor_hotspot := Vector2.ZERO
var _hardware_spreader_cursor_active := false
var _hardware_spreader_cursor_is_wide := false
var _packaging_pending := false
var _automatic_fold_pending_region: StringName = FOLD_MODEL_SCRIPT.REGION_NONE
var _automatic_fold_tween: Tween
var _fold_threshold_feedback_region: StringName = FOLD_MODEL_SCRIPT.REGION_NONE
var _suppress_fold_threshold_feedback := false
var _package_hover_rest_modulate := Color.WHITE
var _package_hovered := false


static func _compact_pancake_parameters() -> PancakeSimulationParameters:
	var compact_parameters := PancakeSimulationParameters.new()
	var spatial_scale := float(GRID_SIZE) / REFERENCE_GRID_SIZE
	compact_parameters.grid_size = GRID_SIZE
	# aozi-v1's usable iron surface is approximately 405 px wide by 305 px
	# tall. Keep rendering, simulation, hit-testing and folding on that ellipse.
	compact_parameters.pan_height_ratio = 0.75
	compact_parameters.scraper_width *= spatial_scale
	compact_parameters.spreader_bar_thickness *= spatial_scale
	compact_parameters.scraper_sample_spacing *= spatial_scale
	compact_parameters.scraper_push_distance *= spatial_scale
	return compact_parameters


func _ready() -> void:
	main_action.pressed.connect(func() -> void: main_action_requested.emit(unit_index))
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_create_package_selection_outline()
	_ensure_package_ingredient_grid()
	pancake_surface.set_model(pancake_model)
	ingredient_layer.set_model(ingredient_model)
	ingredient_layer.set_fold_model(fold_model)
	fold_overlay.set_fold_model(fold_model)
	fold_overlay.set_fold_sauce_textures(
		pancake_surface.fold_sweet_sauce_texture(),
		pancake_surface.fold_chili_sauce_texture(),
	)
	fold_model.changed.connect(_refresh_fold_visual)
	fold_overlay.fold_completion_finished.connect(_on_fold_completion_finished)
	fold_overlay.fold_landing_finished.connect(_on_fold_landing_finished)
	fold_overlay.package_reveal_finished.connect(_on_package_reveal_finished)
	pancake_surface.pointer_started.connect(_on_surface_pointer_started)
	pancake_surface.pointer_ended.connect(_on_surface_pointer_ended)
	pancake_surface.cancel_requested.connect(_cancel_surface_action)
	egg_crack_effect.animation_finished.connect(_on_egg_crack_animation_finished)
	_build_hardware_spreader_cursors()
	set_spreader_visual_enabled(not OS.get_cmdline_user_args().has(DISABLE_SPREADER_VISUAL_ARGUMENT))
	_refresh_intact_egg_visual()
	_refresh_ui()


func _process(delta: float) -> void:
	var step := maxf(delta, 0.0)
	_update_fold_hover_affordance()
	if _batter_ladle_armed:
		_process_batter_ladle_drag(step)
	elif pancake_surface.pointer_pressed:
		# Never rely solely on _gui_input during a held gesture. Other visual
		# layers can receive mouse motion, while the viewport position is always
		# current in PancakeSurface's local coordinate system.
		var live_pointer_position := pancake_surface.sync_pointer_to_viewport()
		_update_surface_tool_artwork(live_pointer_position, step)
		match _surface_action:
			SURFACE_ACTION_POUR_BATTER:
				_process_batter_pour(step)
			SURFACE_ACTION_SPREAD_BATTER:
				_process_manual_spread(step)
			SURFACE_ACTION_SPREAD_EGG:
				_process_egg_spread(step)
			SURFACE_ACTION_BRUSH_SAUCE:
				_process_sauce_brush()
	if state == State.FIRST_SIDE:
		first_side_seconds += step
		_apply_cooking_doneness_cap()
		pancake_model.advance_cooking(step, _effective_cooking_heat())
		p1_session.advance_elapsed_time(step)
		_refresh_heat_visual()
	elif state == State.SECOND_SIDE:
		second_side_seconds += step
		_apply_cooking_doneness_cap()
		pancake_model.advance_cooking(step, _effective_cooking_heat())
		p1_session.advance_elapsed_time(step)
		_refresh_heat_visual()


func _exit_tree() -> void:
	_cancel_automatic_fold()
	_deactivate_hardware_spreader_cursor()


func _process_batter_ladle_drag(delta: float) -> void:
	var local_position := pancake_surface.get_local_mouse_position()
	# The surface's pointer state is authoritative once GUI input has started the
	# pour. Keep the Input singleton as a release fallback for gestures that end
	# over another control, but do not let a missed global button-state sample
	# cancel a valid surface press before its first simulation frame.
	if not pancake_surface.pointer_pressed and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if _surface_action == SURFACE_ACTION_POUR_BATTER:
			_on_surface_pointer_ended(local_position)
		# Picking up the basic ladle and pouring are two separate gestures. A
		# click on the holder must keep the ladle in hand until the player starts
		# a press on an empty griddle (or explicitly cancels the held tool).
		return
	if _surface_action == SURFACE_ACTION_NONE:
		if not PancakeSpace.is_inside_pan(local_position, pancake_surface.size, pancake_model.parameters.pan_height_ratio):
			return
		_on_surface_pointer_started(local_position)
	if _surface_action == SURFACE_ACTION_POUR_BATTER:
		pancake_surface.pointer_local_position = local_position
		_process_batter_pour(delta)


func configure(index: int, display_name: String = "") -> void:
	unit_index = index
	_display_name = display_name if not display_name.is_empty() else "鏊子 %d" % (unit_index + 1)


func display_name() -> String:
	return _display_name


func set_upgrade_locked(value: bool) -> void:
	upgrade_locked = value
	process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
	if is_node_ready():
		_refresh_ui()


func set_non_burning_upgrade_enabled(value: bool) -> void:
	_non_burning_upgrade_enabled = value
	_apply_cooking_doneness_cap()
	if value:
		_cap_existing_doneness()
	if is_node_ready():
		_refresh_heat_visual()


func non_burning_upgrade_enabled() -> bool:
	return _non_burning_upgrade_enabled


func set_fast_cook_upgrade_enabled(value: bool) -> void:
	_fast_cook_upgrade_enabled = value


func _effective_cooking_heat() -> float:
	return p1_session.heat_level * (FAST_COOK_HEAT_MULTIPLIER if _fast_cook_upgrade_enabled else 1.0)


func _apply_cooking_doneness_cap() -> void:
	# A protected pancake can remain undercooked, but cannot enter the shared
	# charred band.
	pancake_model.cooking_doneness_cap = NON_BURNING_DONENESS_CAP if _non_burning_upgrade_enabled else 1.0


func _cap_existing_doneness() -> void:
	var doneness_cap := pancake_model.cooking_doneness_cap
	var changed := false
	for index in pancake_model.cell_count:
		if pancake_model.doneness[index] > doneness_cap:
			pancake_model.doneness[index] = doneness_cap
			changed = true
		if pancake_model.back_doneness[index] > doneness_cap:
			pancake_model.back_doneness[index] = doneness_cap
			changed = true
	if changed:
		pancake_model.changed.emit()


func set_spreader_visual_enabled(value: bool) -> void:
	spreader_visual_enabled = value
	if not is_instance_valid(pancake_surface):
		return
	# The spreader uses the operating-system cursor in normal mode, and no custom
	# cursor at all in the A/B mode. Neither path draws a canvas cursor ring.
	pancake_surface.spreader_cursor_visual_enabled = false
	if not value:
		_deactivate_hardware_spreader_cursor()
	pancake_surface.queue_redraw()


func _build_hardware_spreader_cursors() -> void:
	_hardware_spreader_cursor_normal = _scaled_cursor_texture(SPREADER_NORMAL)
	_hardware_spreader_cursor_wide = _scaled_cursor_texture(SPREADER_WIDE)
	var source_size := Vector2(SPREADER_NORMAL.get_size())
	if source_size.x > 0.0 and source_size.y > 0.0:
		var source_hotspot := source_size * 0.5 - HARDWARE_SPREADER_SOURCE_OFFSET
		_hardware_spreader_cursor_hotspot = source_hotspot / source_size * Vector2(HARDWARE_SPREADER_CURSOR_SIZE)
		_hardware_spreader_cursor_hotspot = _hardware_spreader_cursor_hotspot.clamp(
			Vector2.ZERO,
			Vector2(HARDWARE_SPREADER_CURSOR_SIZE - Vector2i.ONE)
		)


func _scaled_cursor_texture(source: Texture2D) -> Texture2D:
	var image := source.get_image()
	if image == null or image.is_empty():
		return null
	image.resize(HARDWARE_SPREADER_CURSOR_SIZE.x, HARDWARE_SPREADER_CURSOR_SIZE.y, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)


func _update_hardware_spreader_cursor(active: bool) -> void:
	if not active or not spreader_visual_enabled:
		_deactivate_hardware_spreader_cursor()
		return
	var use_wide := _surface_width_multiplier > 1.0
	var cursor_texture := _hardware_spreader_cursor_wide if use_wide else _hardware_spreader_cursor_normal
	if cursor_texture == null:
		_deactivate_hardware_spreader_cursor()
		return
	if _hardware_spreader_cursor_active and _hardware_spreader_cursor_is_wide == use_wide:
		return
	Input.set_custom_mouse_cursor(cursor_texture, Input.CURSOR_ARROW, _hardware_spreader_cursor_hotspot)
	_hardware_spreader_cursor_active = true
	_hardware_spreader_cursor_is_wide = use_wide


func _deactivate_hardware_spreader_cursor() -> void:
	if not _hardware_spreader_cursor_active:
		return
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	_hardware_spreader_cursor_active = false
	_hardware_spreader_cursor_is_wide = false


func begin_order(value: Dictionary, batter_amount: float = STANDARD_BATTER_AMOUNT, used_automatic_batter_ladle: bool = false) -> void:
	reset_unit()
	order = value.duplicate(true)
	_apply_cooking_doneness_cap()
	p1_session.start(order)
	state = State.BATTER
	automatic_batter_ladle_applied = used_automatic_batter_ladle
	_seed_initial_batter_if_needed(batter_amount)
	_refresh_ui()


func begin_batter_pour(value: Dictionary) -> Dictionary:
	if state != State.IDLE:
		return {"success": false, "reason": &"griddle_busy"}
	reset_unit()
	order = value.duplicate(true)
	_apply_cooking_doneness_cap()
	p1_session.start(order)
	state = State.BATTER
	_batter_ladle_armed = true
	_batter_pour_amount = 0.0
	_refresh_ui()
	return {"success": true}


func set_batter_ladle_armed(value: bool) -> void:
	_batter_ladle_armed = value
	if is_node_ready():
		_refresh_ui()


func use_press_spreader() -> Dictionary:
	if state != State.BATTER:
		return {"success": false, "reason": &"wrong_stage", "message": "倒入面糊后、进入煎制前才能使用压饼器"}
	var pressed := Dictionary(pancake_model.apply_standard_press_spread())
	if not bool(pressed.get("success", false)):
		return {"success": false, "reason": &"no_batter", "message": "当前没有可压平的面糊"}
	var confirmed := Dictionary(p1_session.confirm_spread(pancake_model))
	if not bool(confirmed.get("success", false)):
		return {"success": false, "reason": &"press_incomplete", "message": "压饼未能形成可煎制的完整饼皮"}
	press_spreader_applied = true
	state = State.FIRST_SIDE
	if is_node_ready():
		pancake_surface.force_texture_upload()
		_refresh_ui()
	return {"success": true, "coverage_ratio": float(pressed.get("coverage_ratio", 0.0))}


func advance_main() -> Dictionary:
	match state:
		State.BATTER:
			return {"success": false, "message": "拿着摊饼器绕鏊面转一圈即可摊好"}
		State.FIRST_SIDE:
			if pancake_model.covered_cell_count() <= 0:
				return {"success": false, "message": "鏊面还没有完整饼皮"}
			var first_side_heat := cooking_heat_status()
			_stop_egg_crack_effect()
			pancake_model.flip(false)
			p1_session.phase = P1Session.Phase.SECOND_SIDE
			state = State.SECOND_SIDE
			_refresh_ui()
			var result_message := "鏊子%d已翻面，继续观察第二面" % (unit_index + 1)
			if bool(first_side_heat.get("charred", false)):
				result_message = "鏊子%d已翻面，但第一面已焦糊，火候分会降低" % (unit_index + 1)
			elif bool(first_side_heat.get("flip_ready", false)):
				result_message = "鏊子%d在建议火候翻面，继续观察第二面" % (unit_index + 1)
			return {"success": true, "message": result_message}
		State.SECOND_SIDE:
			return begin_automatic_pack()
		State.GARNISH:
			return begin_automatic_pack()
		State.FOLDING:
			return {"success": false, "message": "正在自动折叠并装入纸袋"}
		State.READY:
			return {"success": false, "message": "成品已在鏊子上，可拖到任意匹配订单"}
	return {"success": false, "message": "先给空鏊子添面糊"}


func next_sauce_id() -> StringName:
	for value in Array(order.get("sauce_ids", [])):
		var stock_id := StringName(value)
		if _applied_stock_portion_count(applied_sauce_ids, stock_id) < _ordered_stock_portion_count("sauce_ids", stock_id):
			return stock_id
	return &""


func next_ingredient_id() -> StringName:
	for value in Array(order.get("ingredient_ids", [])):
		var stock_id := StringName(value)
		if _applied_stock_portion_count(applied_ingredient_ids, stock_id) < _ordered_stock_portion_count("ingredient_ids", stock_id):
			return stock_id
	return &""


func apply_sauce(stock_id: StringName) -> void:
	if stock_id.is_empty() or _applied_stock_portion_count(applied_sauce_ids, stock_id) >= IngredientModel.MAX_PORTIONS_PER_TYPE:
		return
	var sauce_type := &"sweet_flour"
	var stroke_id := pancake_model.begin_sauce_stroke()
	var center := Vector2.ONE * float(pancake_model.grid_size - 1) * 0.5
	for offset in [-0.22, -0.08, 0.08, 0.22]:
		pancake_model.apply_sauce_sample(center + Vector2(float(pancake_model.grid_size) * offset, 0.0), 0.24, 4.5, stroke_id, 2147483647, sauce_type)
	applied_sauce_ids.append(str(stock_id))
	_refresh_ui()


func validate_sauce_prime(stock_id: StringName) -> Dictionary:
	if stock_id != &"stock.pancake.sauce.sweet_flour":
		return {"success": false, "reason": &"not_pancake_sauce"}
	if not pancake_model.is_flipped or state not in [State.SECOND_SIDE, State.GARNISH]:
		return {"success": false, "reason": &"wrong_stage", "stock_id": stock_id}
	if state == State.SECOND_SIDE and p1_session.phase != P1Session.Phase.SECOND_SIDE:
		return {"success": false, "reason": &"wrong_stage", "stock_id": stock_id}
	if state == State.GARNISH and p1_session.phase != P1Session.Phase.SAUCE_AND_FILLINGS:
		return {"success": false, "reason": &"wrong_stage", "stock_id": stock_id}
	if _applied_stock_portion_count(applied_sauce_ids, stock_id) >= IngredientModel.MAX_PORTIONS_PER_TYPE:
		return {"success": false, "reason": &"portion_limit", "stock_id": stock_id}
	var grid_position := _nearest_valid_sauce_grid_position()
	if grid_position.x < 0.0:
		return {"success": false, "reason": &"outside_pancake", "stock_id": stock_id}
	return {"success": true, "stock_id": stock_id, "grid_position": grid_position}


func prime_sauce(stock_id: StringName, validation: Dictionary = {}) -> Dictionary:
	var checked := validation if bool(validation.get("success", false)) else validate_sauce_prime(stock_id)
	if not bool(checked.get("success", false)):
		return checked
	# Sauce remains available during either cooking side and does not confirm
	# the fire level or stop the cooking timer.
	var grid_position := Vector2(checked.get("grid_position", Vector2.ONE * float(pancake_model.grid_size - 1) * 0.5))
	var sauce_type: StringName = &"sweet_flour"
	var stroke_id := pancake_model.begin_sauce_stroke()
	var result := Dictionary(pancake_model.apply_sauce_sample(grid_position, 0.38, 6.0, stroke_id, 2147483647, sauce_type))
	if int(result.get("changed_cells", 0)) <= 0:
		return {"success": false, "reason": &"outside_pancake", "stock_id": stock_id}
	applied_sauce_ids.append(str(stock_id))
	_surface_action = SURFACE_ACTION_BRUSH_SAUCE
	_surface_stock_id = stock_id
	_surface_changed = false
	_sauce_stroke_id = -1
	_spread_has_previous = false
	if is_node_ready():
		pancake_surface.force_texture_upload()
		_refresh_surface_cursor()
		_refresh_ui()
	return {"success": true, "stock_id": stock_id, "grid_position": grid_position}


func apply_sauce_automatically(stock_id: StringName, validation: Dictionary = {}) -> Dictionary:
	var checked := validation if bool(validation.get("success", false)) else validate_sauce_prime(stock_id)
	if not bool(checked.get("success", false)):
		return checked
	# Automatic sauce follows the same rule as manual sauce during cooking.
	var sauce_type: StringName = &"sweet_flour"
	# Each accepted portion is another full pass.  Reapplying the single-portion
	# target made a double-sauce order score as two portions while looking exactly
	# like one; retain both portions in the concentration field for rendering and
	# scoring alike.
	var requested_portions := _applied_stock_portion_count(applied_sauce_ids, stock_id) + 1
	var target_concentration := pancake_model.parameters.sauce_target_concentration * float(requested_portions)
	var result := Dictionary(pancake_model.apply_uniform_sauce(target_concentration, sauce_type))
	if int(result.get("covered_cells", 0)) <= 0:
		return {"success": false, "reason": &"outside_pancake", "stock_id": stock_id}
	applied_sauce_ids.append(str(stock_id))
	sauce_automation_applied = true
	_reset_surface_action()
	if is_node_ready():
		pancake_surface.force_texture_upload()
		_refresh_ui()
	return {"success": true, "stock_id": stock_id, "automated": true, "changed_cells": int(result.get("changed_cells", 0))}


func apply_ingredient(stock_id: StringName) -> void:
	if stock_id.is_empty() or _applied_stock_portion_count(applied_ingredient_ids, stock_id) >= IngredientModel.MAX_PORTIONS_PER_TYPE:
		return
	var ingredient_type := _ingredient_type_for_stock(stock_id)
	if ingredient_type.is_empty():
		return
	var placement_index := applied_ingredient_ids.size()
	var center := Vector2.ONE * float(pancake_model.grid_size - 1) * 0.5
	var offset := Vector2(float((placement_index % 3) - 1) * 7.0, float((placement_index / 3) - 1) * 5.0)
	var placed := ingredient_model.place(ingredient_type, center + offset, float(placement_index) * 0.35, pancake_model)
	if bool(placed.get("success", false)):
		applied_ingredient_ids.append(str(stock_id))
	_refresh_ui()


func garnish_complete() -> bool:
	return next_sauce_id().is_empty() and next_ingredient_id().is_empty()


func confirm_second_side_for_followup() -> Dictionary:
	if state == State.SECOND_SIDE:
		p1_session.finish_cooking(pancake_model)
		state = State.GARNISH
		_refresh_ui()
		return {"success": true, "transitioned": true}
	if state in [State.GARNISH, State.FOLDING]:
		return {"success": true, "transitioned": false}
	return {"success": false, "reason": &"wrong_stage"}


func begin_garnish_without_flip() -> Dictionary:
	return {"success": false, "reason": &"must_flip_first"}


func begin_automatic_pack() -> Dictionary:
	if not pancake_model.is_flipped or state not in [State.SECOND_SIDE, State.GARNISH]:
		return {"success": false, "reason": &"must_flip_first", "message": "面饼翻面后才能打包"}
	if _automatic_fold_pending_region != FOLD_MODEL_SCRIPT.REGION_NONE or fold_overlay.is_fold_animation_active() or _packaging_pending:
		return {"success": false, "reason": &"packaging_pending", "message": "正在自动折叠并装入纸袋"}
	var previous_state := state
	var previous_phase := p1_session.phase
	if state == State.SECOND_SIDE:
		var cooking_result := Dictionary(p1_session.finish_cooking(pancake_model))
		if not bool(cooking_result.get("success", false)):
			return cooking_result.merged({"message": str(cooking_result.get("reason", "当前无法打包"))}, true)
	var phase_result := Dictionary(p1_session.begin_folding())
	if not bool(phase_result.get("success", false)):
		p1_session.phase = previous_phase
		return phase_result.merged({"message": str(phase_result.get("reason", "当前无法打包"))}, true)
	state = State.FOLDING
	_automatic_fold_pending_region = FOLD_MODEL_SCRIPT.REGION_RIGHT
	_suppress_fold_threshold_feedback = true
	var fold_result := Dictionary(fold_model.fold_automatically(FOLD_MODEL_SCRIPT.REGION_LEFT))
	_suppress_fold_threshold_feedback = false
	if not bool(fold_result.get("committed", false)):
		_automatic_fold_pending_region = FOLD_MODEL_SCRIPT.REGION_NONE
		state = previous_state
		p1_session.phase = previous_phase
		_refresh_ui()
		return fold_result.merged({"message": str(fold_result.get("reason", "自动折叠未完成"))}, true)
	fold_steps = fold_model.completed_fold_count()
	fold_feedback_requested.emit(unit_index, &"automatic_fold")
	_refresh_ui()
	return {"success": true, "action": &"pack", "message": "鏊子%d正在自动折叠并打包" % (unit_index + 1)}


func _fold_grid_position(local_position: Vector2) -> Vector2:
	# Folding is a visual gesture, so retain sub-cell pointer precision. Using the
	# integer simulation grid here makes the flap jump once per 6.25 px.
	return PancakeSpace.local_to_grid_position(
		local_position,
		pancake_surface.size,
		pancake_model.grid_size,
	)


func mark_ready(product: Dictionary) -> void:
	ready_product = product.duplicate(true)
	_packaging_pending = false
	state = State.READY
	_refresh_ui()


func _on_fold_completion_finished() -> void:
	if _automatic_fold_pending_region != FOLD_MODEL_SCRIPT.REGION_NONE and fold_model.completed_fold_count() == 1:
		_schedule_automatic_fold()


func _on_fold_landing_finished() -> void:
	if not _packaging_pending or fold_model.completed_fold_count() < 2:
		return
	_begin_paper_bag_packaging()


func _schedule_automatic_fold() -> void:
	if _automatic_fold_pending_region == FOLD_MODEL_SCRIPT.REGION_NONE:
		return
	if _automatic_fold_tween != null and _automatic_fold_tween.is_running():
		_automatic_fold_tween.kill()
	_automatic_fold_tween = create_tween()
	_automatic_fold_tween.tween_interval(AUTO_FOLD_PAUSE_DURATION)
	_automatic_fold_tween.tween_callback(_perform_automatic_fold)


func _perform_automatic_fold() -> void:
	var region := _automatic_fold_pending_region
	if region == FOLD_MODEL_SCRIPT.REGION_NONE or state != State.FOLDING:
		return
	_automatic_fold_pending_region = FOLD_MODEL_SCRIPT.REGION_NONE
	_suppress_fold_threshold_feedback = true
	var result := Dictionary(fold_model.fold_automatically(region))
	_suppress_fold_threshold_feedback = false
	if not bool(result.get("committed", false)):
		status_message_requested.emit(str(result.get("reason", "自动折叠未完成")))
		_refresh_ui()
		return
	fold_steps = fold_model.completed_fold_count()
	p1_session.mark_ready_for_package()
	_packaging_pending = true
	fold_feedback_requested.emit(unit_index, &"automatic_fold")
	status_message_requested.emit("鏊子%d另一侧已自动接力折叠，正在落稳" % (unit_index + 1))
	_refresh_ui()


func _cancel_automatic_fold() -> void:
	if _automatic_fold_tween != null and _automatic_fold_tween.is_running():
		_automatic_fold_tween.kill()
	_automatic_fold_tween = null
	_automatic_fold_pending_region = FOLD_MODEL_SCRIPT.REGION_NONE


func _remaining_unfolded_region() -> StringName:
	if not fold_model.is_region_folded(FOLD_MODEL_SCRIPT.REGION_LEFT):
		return FOLD_MODEL_SCRIPT.REGION_LEFT
	if not fold_model.is_region_folded(FOLD_MODEL_SCRIPT.REGION_RIGHT):
		return FOLD_MODEL_SCRIPT.REGION_RIGHT
	return FOLD_MODEL_SCRIPT.REGION_NONE


func _update_fold_hover_affordance() -> void:
	fold_overlay.set_hovered_region(FOLD_MODEL_SCRIPT.REGION_NONE)
	pancake_surface.mouse_default_cursor_shape = Control.CURSOR_ARROW


func _begin_paper_bag_packaging() -> void:
	if not _packaging_pending or fold_model.package_result == PancakeFoldModel.PACKAGE_BAG:
		return
	var package_result := Dictionary(fold_model.package_with(PancakeFoldModel.PACKAGE_BAG))
	if not bool(package_result.get("success", false)):
		_packaging_pending = false
		status_message_requested.emit(str(package_result.get("reason", "纸袋包装失败")))
		_refresh_ui()
		return
	p1_session.mark_packaged()
	status_message_requested.emit("鏊子%d正在装入纸袋" % (unit_index + 1))
	_refresh_ui()


func _on_package_reveal_finished() -> void:
	if not _packaging_pending or fold_model.package_result != PancakeFoldModel.PACKAGE_BAG:
		return
	_packaging_pending = false
	packaging_finished.emit(unit_index)


func _resume_loaded_packaging() -> void:
	if not _packaging_pending:
		return
	if fold_model.package_result == PancakeFoldModel.PACKAGE_BAG:
		_on_package_reveal_finished()
	else:
		_begin_paper_bag_packaging()


func is_reserving_batter() -> bool:
	return state != State.IDLE


func is_reserving_sauce(stock_id: StringName) -> bool:
	return state != State.IDLE and applied_sauce_ids.has(str(stock_id))


func _applied_stock_portion_count(stock_ids: PackedStringArray, stock_id: StringName) -> int:
	var count := 0
	for value in stock_ids:
		if StringName(value) == stock_id:
			count += 1
	return count


func _ordered_stock_portion_count(order_key: String, stock_id: StringName) -> int:
	var count := 0
	for value in Array(order.get(order_key, [])):
		if StringName(value) == stock_id:
			count += 1
	return count


func source_ref() -> Dictionary:
	if state != State.READY or ready_product.is_empty():
		return {}
	return {
		"source_kind": &"pancake_griddle_ready",
		"source_index": unit_index,
		"product_id": &"product.pancake.custom",
		"product": ready_product.duplicate(true),
		"discardable": true,
	}


func set_ready_product_selected(value: bool) -> void:
	if _package_selection_outline != null:
		_package_selection_outline.visible = value and state == State.READY


func _gui_input(event: InputEvent) -> void:
	if state != State.READY or ready_product.is_empty():
		return
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	var local_position: Vector2 = package_visual.get_global_transform_with_canvas().affine_inverse() * event.global_position
	if not Rect2(Vector2.ZERO, package_visual.size).has_point(local_position):
		return
	ready_product_clicked.emit(source_ref())
	accept_event()


func _on_mouse_entered() -> void:
	if state != State.READY or not package_visual.visible:
		return
	_package_hovered = true
	_package_hover_rest_modulate = package_visual.self_modulate
	package_visual.self_modulate = _package_hover_rest_modulate * PHYSICAL_HOVER_MODULATE


func _on_mouse_exited() -> void:
	if not _package_hovered:
		return
	package_visual.self_modulate = _package_hover_rest_modulate
	_package_hovered = false


func _create_package_selection_outline() -> void:
	_package_selection_outline = Panel.new()
	_package_selection_outline.name = "SelectionOutline"
	_package_selection_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_package_selection_outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 0)
	_package_selection_outline.z_index = 100
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.76, 0.18, 0.12)
	style.border_color = Color("ffe17a")
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.expand_margin_left = 5.0
	style.expand_margin_top = 5.0
	style.expand_margin_right = 5.0
	style.expand_margin_bottom = 5.0
	_package_selection_outline.add_theme_stylebox_override("panel", style)
	_package_selection_outline.visible = false
	package_visual.add_child(_package_selection_outline)


func _refresh_package_recipe_markers() -> void:
	var ingredient_grid := _ensure_package_ingredient_grid()
	ingredient_grid.configure(ready_product)
	ingredient_grid.visible = state == State.READY and not ready_product.is_empty()


func _ensure_package_ingredient_grid() -> PancakePackageIngredientGrid:
	if _package_ingredient_grid != null and is_instance_valid(_package_ingredient_grid):
		return _package_ingredient_grid
	_package_ingredient_grid = PANCAKE_PACKAGE_INGREDIENT_GRID.new()
	_package_ingredient_grid.name = "PancakePackageIngredientGrid"
	_package_ingredient_grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 0)
	_package_ingredient_grid.z_index = 10
	package_visual.add_child(_package_ingredient_grid)
	return _package_ingredient_grid


func _get_drag_data(_at_position: Vector2) -> Variant:
	var source := source_ref()
	if source.is_empty():
		return null
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(84.0, 84.0)
	preview.texture = READY_DRAG_TEXTURE
	preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	return {"kind": &"product_source", "source_ref": source}


func total_cook_seconds() -> float:
	return first_side_seconds + second_side_seconds


func snapshot() -> Dictionary:
	return {
		"version": 5,
		"source_index": unit_index,
		"state": int(state),
		"order": order.duplicate(true),
		"first_side_seconds": first_side_seconds,
		"second_side_seconds": second_side_seconds,
		"fold_steps": fold_steps,
		"applied_sauce_ids": applied_sauce_ids.duplicate(),
		"applied_ingredient_ids": applied_ingredient_ids.duplicate(),
		"egg_automation_applied": egg_automation_applied,
		"sauce_automation_applied": sauce_automation_applied,
		"automatic_batter_ladle_applied": automatic_batter_ladle_applied,
		"press_spreader_applied": press_spreader_applied,
		"ready_product": ready_product.duplicate(true),
		"packaging_pending": _packaging_pending,
		"automatic_fold_pending_region": _automatic_fold_pending_region,
		"pancake_model": pancake_model.snapshot(),
		"ingredient_model": ingredient_model.snapshot(),
		"fold_model": fold_model.snapshot(),
		"p1_session": p1_session.snapshot(),
	}


func load_snapshot(value: Dictionary) -> Dictionary:
	_cancel_automatic_fold()
	_clear_intact_egg_visuals()
	var pancake_result: Dictionary = pancake_model.load_snapshot(Dictionary(value.get("pancake_model", {})))
	if not bool(pancake_result.get("success", false)):
		return pancake_result
	var ingredient_result: Dictionary = ingredient_model.load_snapshot(Dictionary(value.get("ingredient_model", {})))
	if not bool(ingredient_result.get("success", false)):
		return ingredient_result
	fold_model.set_model(pancake_model)
	fold_model.set_ingredient_model(ingredient_model)
	var fold_result: Dictionary = fold_model.load_snapshot(Dictionary(value.get("fold_model", {})))
	if not bool(fold_result.get("success", false)):
		return fold_result
	p1_session.load_snapshot(Dictionary(value.get("p1_session", {})))
	state = clampi(int(value.get("state", State.IDLE)), State.IDLE, State.READY)
	order = Dictionary(value.get("order", {})).duplicate(true)
	_apply_cooking_doneness_cap()
	if _non_burning_upgrade_enabled:
		_cap_existing_doneness()
	first_side_seconds = maxf(float(value.get("first_side_seconds", 0.0)), 0.0)
	second_side_seconds = maxf(float(value.get("second_side_seconds", 0.0)), 0.0)
	fold_steps = clampi(int(value.get("fold_steps", 0)), 0, 2)
	applied_sauce_ids = PackedStringArray(Array(value.get("applied_sauce_ids", [])))
	applied_ingredient_ids = PackedStringArray(Array(value.get("applied_ingredient_ids", [])))
	egg_automation_applied = bool(value.get("egg_automation_applied", false))
	sauce_automation_applied = bool(value.get("sauce_automation_applied", false))
	automatic_batter_ladle_applied = bool(value.get("automatic_batter_ladle_applied", false))
	press_spreader_applied = bool(value.get("press_spreader_applied", false))
	ready_product = Dictionary(value.get("ready_product", {})).duplicate(true)
	_packaging_pending = bool(value.get("packaging_pending", false))
	_automatic_fold_pending_region = StringName(value.get("automatic_fold_pending_region", FOLD_MODEL_SCRIPT.REGION_NONE))
	if _automatic_fold_pending_region not in [FOLD_MODEL_SCRIPT.REGION_NONE, FOLD_MODEL_SCRIPT.REGION_LEFT, FOLD_MODEL_SCRIPT.REGION_RIGHT]:
		_automatic_fold_pending_region = FOLD_MODEL_SCRIPT.REGION_NONE
	if state == State.FOLDING and fold_model.completed_fold_count() == 1 and _automatic_fold_pending_region == FOLD_MODEL_SCRIPT.REGION_NONE:
		_automatic_fold_pending_region = _remaining_unfolded_region()
	if state == State.FOLDING and fold_model.completed_fold_count() >= 2 and ready_product.is_empty():
		_packaging_pending = true
	if is_node_ready():
		pancake_surface.set_model(pancake_model)
		ingredient_layer.set_model(ingredient_model)
		ingredient_layer.set_fold_model(fold_model)
		fold_overlay.set_fold_model(fold_model)
		_seed_initial_batter_if_needed()
		_refresh_fold_visual()
		_restore_intact_egg_visuals_from_snapshot()
		_refresh_intact_egg_visual()
		_refresh_ui()
		if _packaging_pending:
			call_deferred("_resume_loaded_packaging")
		elif _automatic_fold_pending_region != FOLD_MODEL_SCRIPT.REGION_NONE:
			call_deferred("_schedule_automatic_fold")
	return {"success": true}


func reset_unit() -> void:
	_cancel_automatic_fold()
	state = State.IDLE
	order.clear()
	first_side_seconds = 0.0
	second_side_seconds = 0.0
	fold_steps = 0
	applied_sauce_ids = PackedStringArray()
	applied_ingredient_ids = PackedStringArray()
	egg_automation_applied = false
	sauce_automation_applied = false
	automatic_batter_ladle_applied = false
	press_spreader_applied = false
	ready_product.clear()
	_packaging_pending = false
	_fold_threshold_feedback_region = FOLD_MODEL_SCRIPT.REGION_NONE
	pancake_model.reset()
	ingredient_model.reset()
	fold_model.reset()
	_clear_intact_egg_visuals()
	p1_session.start({})
	_stop_egg_crack_effect()
	_scrape_sampler.reset()
	_egg_sampler.reset()
	_batter_pour_amount = 0.0
	_batter_pour_center = Vector2.ZERO
	_batter_thickness_warning_sent = false
	_batter_ladle_armed = false
	_spread_has_previous = false
	_reset_surface_action()
	if is_node_ready():
		_refresh_intact_egg_visual()
		_refresh_ui()


func _on_surface_pointer_started(local_position: Vector2) -> void:
	if upgrade_locked:
		return
	var station := get_parent()
	if station == null or not station.has_method("begin_surface_action"):
		return
	var action_result := Dictionary(station.call("begin_surface_action", unit_index, local_position))
	if not bool(action_result.get("success", false)):
		return
	_surface_action = StringName(action_result.get("action", _surface_action))
	_surface_stock_id = StringName(action_result.get("stock_id", &""))
	_surface_width_multiplier = maxf(float(action_result.get("width_multiplier", 1.0)), 1.0)
	_surface_changed = false
	var radial := local_position - pancake_surface.size * 0.5
	if radial.length_squared() > 0.0001:
		_last_tool_direction = radial.normalized()
	var grid_position := Vector2(PancakeSpace.local_to_grid(local_position, pancake_surface.size, pancake_model.grid_size))
	if _surface_action in [SURFACE_ACTION_SPREAD_BATTER, SURFACE_ACTION_SPREAD_EGG]:
		if _surface_action == SURFACE_ACTION_SPREAD_BATTER:
			_scrape_sampler.begin(grid_position)
		else:
			_egg_sampler.begin(grid_position)
		_previous_scrape_sample = grid_position
		_last_process_grid_position = grid_position
		_spreader_max_radius = _pan_polar_offset(grid_position).length()
		_spreader_direction_grace_remaining = 0
		_spreader_speed_initialized = false
		_spreader_speed_band = SPREADER_SPEED_MEDIUM
		if _surface_action == SURFACE_ACTION_SPREAD_BATTER:
			_begin_spreader_circle_tracking(grid_position)
		pancake_surface.spreader_motion_valid = false
	elif _surface_action == SURFACE_ACTION_POUR_BATTER:
		_set_batter_pour_center(local_position)
		_batter_pour_amount = 0.0
	if _surface_action == SURFACE_ACTION_BRUSH_SAUCE:
		_sauce_stroke_id = pancake_model.begin_sauce_stroke()
		_surface_changed = _apply_sauce_sample(grid_position) or _surface_changed
	_spread_previous_grid = grid_position
	_spread_has_previous = true
	_refresh_surface_cursor()
	_update_surface_tool_artwork(local_position, 0.0)


func _on_surface_pointer_ended(_local_position: Vector2) -> void:
	_spread_has_previous = false
	_scrape_sampler.reset()
	_egg_sampler.reset()
	_spreader_angle_initialized = false
	_spreader_speed_initialized = false
	pancake_surface.spreader_motion_valid = false
	if _surface_action == SURFACE_ACTION_POUR_BATTER:
		_surface_changed = _batter_pour_amount >= MIN_BATTER_POUR_AMOUNT
		_batter_ladle_armed = false
		_refresh_ui()
		if not _surface_changed:
			pancake_model.reset()
			_refresh_ui()
	elif _surface_action == SURFACE_ACTION_SPREAD_BATTER and state == State.BATTER:
		status_message_requested.emit("还没转满一圈，再拿起摊饼器绕鏊面转一圈")
	var station := get_parent()
	if station != null and station.has_method("complete_surface_action"):
		station.call("complete_surface_action", unit_index, _surface_action, _surface_changed)
	_reset_surface_action()


func _process_batter_pour(delta: float) -> void:
	if state != State.BATTER:
		return
	# Keep the stream under the ladle throughout the held gesture rather than
	# locking it to the point where the player first pressed the griddle.
	_set_batter_pour_center(pancake_surface.pointer_local_position)
	var remaining_radius_growth := MAX_BATTER_POUR_RADIUS - (MIN_BATTER_POUR_RADIUS + _batter_pour_amount)
	if remaining_radius_growth <= 0.0:
		return
	var addition := minf(BATTER_POUR_RATE * maxf(delta, 0.0), remaining_radius_growth)
	if addition <= 0.0:
		return
	_batter_pour_amount += addition
	var pour_radius := minf(MIN_BATTER_POUR_RADIUS + _batter_pour_amount, MAX_BATTER_POUR_RADIUS)
	pancake_model.add_batter(_batter_pour_center, addition, pour_radius)
	if _batter_pour_amount > MAX_BATTER_AMOUNT and not _batter_thickness_warning_sent:
		_batter_thickness_warning_sent = true
		transient_warning_requested.emit("面饼可能偏厚")
	var thickness_warning := " · 面饼可能偏厚" if _batter_pour_amount > MAX_BATTER_AMOUNT else ""
	state_label.text = "正在倒入面糊 %.1f%s · 拖动勺子可调整落点，松开后放回" % [_batter_pour_amount, thickness_warning]


func _set_batter_pour_center(local_position: Vector2) -> void:
	if not PancakeSpace.is_inside_pan(local_position, pancake_surface.size, pancake_model.parameters.pan_height_ratio):
		return
	_batter_pour_center = Vector2(PancakeSpace.local_to_grid(local_position, pancake_surface.size, pancake_model.grid_size))


func _process_manual_spread(delta: float) -> void:
	if state != State.BATTER:
		return
	var current := Vector2(PancakeSpace.local_to_grid(pancake_surface.pointer_local_position, pancake_surface.size, pancake_model.grid_size))
	var circle_completed := _track_spreader_circle(current)
	var samples := _limit_spread_samples(_scrape_sampler.sample_to(current))
	var previous_polar := _pan_polar_offset(_last_process_grid_position)
	var current_polar := _pan_polar_offset(current)
	var angular_delta := absf(wrapf(current_polar.angle() - previous_polar.angle(), -PI, PI))
	var raw_angular_speed := angular_delta / maxf(delta, 0.000001)
	_update_spreader_speed(raw_angular_speed, delta)
	var effect_speed := _spreader_effect_speed()
	var applied_sample := false
	for sample in samples:
		var previous_offset := _pan_polar_offset(_previous_scrape_sample)
		var sample_offset := _pan_polar_offset(sample)
		var motion_distance := previous_offset.distance_to(sample_offset)
		if motion_distance <= 0.0001 or previous_offset.length() <= SPREADER_CENTER_DEAD_ZONE or sample_offset.length() <= SPREADER_CENTER_DEAD_ZONE:
			_previous_scrape_sample = sample
			continue
		var sample_angle_delta := absf(wrapf(sample_offset.angle() - previous_offset.angle(), -PI, PI))
		var tangential_distance := sample_angle_delta * (previous_offset.length() + sample_offset.length()) * 0.5
		var circularity := tangential_distance / motion_distance
		var moving_too_far_inward := sample_offset.length() + SPREADER_INWARD_TOLERANCE < _spreader_max_radius
		var circular_motion := circularity >= pancake_model.parameters.spreader_min_circularity
		if moving_too_far_inward:
			_spreader_direction_grace_remaining = 0
			_previous_scrape_sample = sample
			continue
		if circular_motion:
			_spreader_direction_grace_remaining = SPREADER_DIRECTION_GRACE_SAMPLES
		elif _spreader_direction_grace_remaining > 0:
			_spreader_direction_grace_remaining -= 1
		else:
			_previous_scrape_sample = sample
			continue
		var outward_direction := Vector2.from_angle(_spreader_smoothed_angle)
		var changed := _apply_radial_batter_sweep(sample, outward_direction, effect_speed)
		_previous_scrape_sample = sample
		_spreader_max_radius = maxf(_spreader_max_radius, sample_offset.length())
		_surface_changed = changed or _surface_changed
		applied_sample = changed or applied_sample
	_last_process_grid_position = current
	pancake_surface.spreader_motion_valid = applied_sample
	pancake_surface.queue_redraw()
	if circle_completed:
		_complete_manual_spread_circle()
	elif is_node_ready():
		var progress_percent := roundi(clampf(_spreader_circle_progress / SPREADER_CIRCLE_REQUIRED_ANGLE, 0.0, 1.0) * 100.0)
		state_label.text = "拿着摊饼器绕一圈 %d%%" % progress_percent


func _begin_spreader_circle_tracking(grid_position: Vector2) -> void:
	_spreader_circle_progress = 0.0
	_spreader_circle_direction = 0.0
	var polar := _pan_polar_offset(grid_position)
	_spreader_circle_has_previous = polar.length() > SPREADER_CENTER_DEAD_ZONE
	if _spreader_circle_has_previous:
		_spreader_circle_previous_angle = polar.angle()


func _track_spreader_circle(grid_position: Vector2) -> bool:
	var polar := _pan_polar_offset(grid_position)
	if polar.length() <= SPREADER_CENTER_DEAD_ZONE:
		_spreader_circle_has_previous = false
		return false
	var current_angle := polar.angle()
	if not _spreader_circle_has_previous:
		_spreader_circle_previous_angle = current_angle
		_spreader_circle_has_previous = true
		return false
	var angle_delta := wrapf(current_angle - _spreader_circle_previous_angle, -PI, PI)
	_spreader_circle_previous_angle = current_angle
	if absf(angle_delta) <= 0.001:
		return false
	var movement_direction := signf(angle_delta)
	if is_zero_approx(_spreader_circle_direction):
		_spreader_circle_direction = movement_direction
	if movement_direction == _spreader_circle_direction:
		_spreader_circle_progress += absf(angle_delta)
	else:
		# Small corrections are harmless, but moving back and forth cannot be
		# mistaken for completing a circle.
		_spreader_circle_progress = maxf(_spreader_circle_progress - absf(angle_delta), 0.0)
		if is_zero_approx(_spreader_circle_progress):
			_spreader_circle_direction = movement_direction
	return _spreader_circle_progress >= SPREADER_CIRCLE_REQUIRED_ANGLE


func _complete_manual_spread_circle() -> void:
	var spread_result := Dictionary(pancake_model.apply_standard_press_spread())
	if not bool(spread_result.get("success", false)):
		return
	var confirmed := Dictionary(p1_session.confirm_spread(pancake_model))
	if not bool(confirmed.get("success", false)):
		return
	_surface_changed = true
	state = State.FIRST_SIDE
	pancake_surface.force_texture_upload()
	status_message_requested.emit("鏊子%d已摊成完整饼皮，开始煎第一面" % (unit_index + 1))
	_refresh_ui()


func _limit_spread_samples(raw_samples: PackedVector2Array) -> PackedVector2Array:
	var budget := maxi(MAX_SPREAD_SIMULATION_SAMPLES_PER_FRAME, 1)
	if raw_samples.size() <= budget:
		return raw_samples
	# Prefer the newest points. They keep the simulated contact aligned with the
	# visible tool and collapse any backlog instead of carrying lag into later frames.
	var limited := PackedVector2Array()
	var first_index := raw_samples.size() - budget
	for sample_index in range(first_index, raw_samples.size()):
		limited.append(raw_samples[sample_index])
	return limited


func _apply_radial_batter_sweep(sample: Vector2, outward_direction: Vector2, effect_speed: float) -> bool:
	var pan_center := Vector2.ONE * (float(pancake_model.grid_size) - 1.0) * 0.5
	var radial_distance := pan_center.distance_to(sample)
	var segment_count := maxi(1, ceili(radial_distance / SPREADER_SAMPLE_SPACING))
	var anchor_count := segment_count + 1
	var total_anchor_weight := float(anchor_count * (anchor_count + 1)) * 0.5
	var anchor_group_size := maxi(1, ceili(float(anchor_count) / float(MAX_RADIAL_SWEEP_ANCHORS)))
	var changed := false
	# Apply weighted representative anchors instead of simulating every radial
	# segment. The original weights are summed per group, so a long sweep keeps
	# its total flattening and transfer strength while avoiding input-frame spikes.
	for group_start in range(0, anchor_count, anchor_group_size):
		var group_end := mini(group_start + anchor_group_size, anchor_count)
		var represented_anchor_index := (group_start + group_end - 1) / 2
		var represented_count := group_end - group_start
		var group_weight := float(represented_count * (2 * anchor_count - group_start - group_end + 1)) * 0.5
		var progress := float(represented_anchor_index) / float(segment_count)
		var anchor := pan_center.lerp(sample, progress)
		var anchor_strength := group_weight / total_anchor_weight
		var result := Dictionary(pancake_model.apply_scraper_sample(
			anchor,
			outward_direction,
			effect_speed,
			_surface_width_multiplier,
			anchor_strength,
			true
		))
		changed = int(result.get("changed_cells", 0)) > 0 or changed
	return changed


func _seed_initial_batter_if_needed(batter_amount: float = STANDARD_BATTER_AMOUNT) -> void:
	if state != State.BATTER or pancake_model.covered_cell_count() > 0:
		return
	var center := Vector2.ONE * (float(pancake_model.grid_size) - 1.0) * 0.5
	pancake_model.add_batter(center, clampf(batter_amount, MIN_BATTER_AMOUNT, MAX_BATTER_AMOUNT), INITIAL_BATTER_RADIUS)
	if is_node_ready():
		pancake_surface.force_texture_upload()


func _pan_polar_offset(grid_position: Vector2) -> Vector2:
	var center := Vector2(pancake_model.grid_size - 1, pancake_model.grid_size - 1) * 0.5
	var offset := grid_position - center
	return Vector2(offset.x, offset.y / maxf(pancake_model.parameters.pan_height_ratio, 0.01))


func _update_spreader_speed(raw_angular_speed: float, delta: float) -> void:
	if not _spreader_speed_initialized:
		_spreader_smoothed_angular_speed = raw_angular_speed
		_spreader_speed_initialized = true
	else:
		var blend := 1.0 - exp(-delta / SPREADER_SPEED_SMOOTHING_SECONDS)
		_spreader_smoothed_angular_speed = lerpf(_spreader_smoothed_angular_speed, raw_angular_speed, blend)
	var hysteresis := pancake_model.parameters.spreader_speed_hysteresis
	match _spreader_speed_band:
		SPREADER_SPEED_SLOW:
			if _spreader_smoothed_angular_speed > pancake_model.parameters.spreader_slow_angular_speed + hysteresis:
				_spreader_speed_band = SPREADER_SPEED_MEDIUM
		SPREADER_SPEED_FAST:
			if _spreader_smoothed_angular_speed < pancake_model.parameters.spreader_fast_angular_speed - hysteresis:
				_spreader_speed_band = SPREADER_SPEED_MEDIUM
		_:
			if _spreader_smoothed_angular_speed < pancake_model.parameters.spreader_slow_angular_speed - hysteresis:
				_spreader_speed_band = SPREADER_SPEED_SLOW
			elif _spreader_smoothed_angular_speed > pancake_model.parameters.spreader_fast_angular_speed + hysteresis:
				_spreader_speed_band = SPREADER_SPEED_FAST


func _spreader_effect_speed() -> float:
	match _spreader_speed_band:
		SPREADER_SPEED_SLOW:
			return pancake_model.parameters.spreader_slow_effect_speed
		SPREADER_SPEED_FAST:
			return pancake_model.parameters.spreader_fast_effect_speed
		_:
			return pancake_model.parameters.spreader_medium_effect_speed


func _limit_egg_samples(raw_samples: PackedVector2Array) -> PackedVector2Array:
	var budget := maxi(pancake_model.parameters.egg_max_samples_per_frame, 1)
	if raw_samples.size() <= budget:
		return raw_samples
	var limited := PackedVector2Array()
	for sample_index in budget:
		var source_index := roundi(float(sample_index) * float(raw_samples.size() - 1) / float(maxi(budget - 1, 1)))
		limited.append(raw_samples[source_index])
	return limited


func _process_egg_spread(delta: float) -> void:
	var current := Vector2(PancakeSpace.local_to_grid(pancake_surface.pointer_local_position, pancake_surface.size, pancake_model.grid_size))
	var samples := _limit_egg_samples(_egg_sampler.sample_to(current))
	var previous_polar := _pan_polar_offset(_last_process_grid_position)
	var current_polar := _pan_polar_offset(current)
	var angular_delta := absf(wrapf(current_polar.angle() - previous_polar.angle(), -PI, PI))
	_update_spreader_speed(angular_delta / maxf(delta, 0.000001), delta)
	var result := Dictionary(pancake_model.apply_egg_spreader_path(samples, _spreader_effect_speed(), _surface_width_multiplier))
	var changed := int(result.get("changed_cells", 0)) > 0
	_surface_changed = changed or _surface_changed
	if changed:
		_finish_egg_spread_visuals()
	if not samples.is_empty():
		_previous_scrape_sample = samples[samples.size() - 1]
	_last_process_grid_position = current
	pancake_surface.spreader_motion_valid = changed
	pancake_surface.queue_redraw()


func _play_egg_crack_effect(local_position: Vector2) -> void:
	# A quick second drop should land the first egg before the next egg starts
	# falling, so two completed fried eggs remain visible until spreading begins.
	if _egg_liquid_falling:
		_complete_egg_liquid_fall()
	_stop_egg_crack_effect()
	_preserve_current_intact_egg_visual()
	_intact_egg_local_override = local_position
	_has_intact_egg_local_override = true
	var crack_position := local_position + EGG_CRACK_STAGE_OFFSET
	# The shell opens and remains at the upper crack position. The liquid is a
	# separate visual so it can fall to the actual pancake drop point.
	egg_shell_visual.position = crack_position
	egg_shell_visual.scale = EGG_CRACK_EFFECT_BASE_SCALE * 0.78
	egg_shell_visual.visible = true
	egg_intact_visual.position = crack_position
	egg_intact_visual.scale = EGG_INTACT_VISUAL_SCALE * 0.78
	egg_intact_visual.modulate = Color(1.0, 1.0, 1.0, 0.0)
	egg_intact_visual.visible = true
	_egg_liquid_falling = true
	# EggCrackEffect contains both shells and egg liquid, which would show a
	# second egg above the pan. The shell-only crop below supplies the opening
	# visual instead.
	egg_crack_effect.visible = false
	_egg_crack_tween = create_tween()
	_egg_crack_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_egg_crack_tween.parallel().tween_property(egg_shell_visual, "scale", EGG_CRACK_EFFECT_BASE_SCALE, 0.12)
	_egg_crack_tween.parallel().tween_property(egg_intact_visual, "position", local_position, EGG_LIQUID_FALL_DURATION)
	_egg_crack_tween.parallel().tween_property(egg_intact_visual, "scale", EGG_INTACT_VISUAL_SCALE, EGG_LIQUID_FALL_DURATION)
	_egg_crack_tween.parallel().tween_property(egg_intact_visual, "modulate", Color.WHITE, EGG_LIQUID_FALL_DURATION * 0.65)
	_egg_crack_tween.tween_callback(_complete_egg_liquid_fall)


func _on_egg_crack_animation_finished() -> void:
	# The shell remains above the griddle while the egg liquid finishes falling.
	egg_crack_effect.visible = false


func _complete_egg_liquid_fall() -> void:
	_egg_liquid_falling = false
	if is_instance_valid(egg_shell_visual):
		egg_shell_visual.visible = false
	_refresh_intact_egg_visual()


func _stop_egg_crack_effect() -> void:
	if _egg_crack_tween != null and _egg_crack_tween.is_valid():
		_egg_crack_tween.kill()
	_egg_crack_tween = null
	_egg_liquid_falling = false
	if is_instance_valid(egg_crack_effect):
		egg_crack_effect.stop()
		egg_crack_effect.frame = 0
		egg_crack_effect.visible = false
		egg_crack_effect.rotation = 0.0
		egg_crack_effect.scale = EGG_CRACK_EFFECT_BASE_SCALE
	if is_instance_valid(egg_shell_visual):
		egg_shell_visual.visible = false
	if is_instance_valid(egg_intact_visual):
		egg_intact_visual.modulate = Color.WHITE
	if is_instance_valid(egg_intact_visual_second):
		egg_intact_visual_second.modulate = Color.WHITE


func _preserve_current_intact_egg_visual() -> void:
	if not is_instance_valid(egg_intact_visual) or not egg_intact_visual.visible:
		return
	if not is_instance_valid(egg_intact_visual_second):
		return
	# The primary sprite performs the falling animation for the newest egg. Keep
	# the earlier complete egg in a lower visual layer until both are spread.
	egg_intact_visual_second.position = egg_intact_visual.position
	egg_intact_visual_second.scale = egg_intact_visual.scale
	egg_intact_visual_second.modulate = Color.WHITE
	egg_intact_visual_second.visible = true


func _clear_intact_egg_visuals() -> void:
	_has_intact_egg_local_override = false
	if is_instance_valid(egg_intact_visual):
		egg_intact_visual.visible = false
	if is_instance_valid(egg_intact_visual_second):
		egg_intact_visual_second.visible = false


func _finish_egg_spread_visuals() -> void:
	_stop_egg_crack_effect()
	_clear_intact_egg_visuals()
	_refresh_intact_egg_visual()


func auto_spread_egg() -> Dictionary:
	if not pancake_model.has_egg() or not pancake_model.egg_is_on_visible_side():
		return {"success": false, "reason": &"egg_unavailable"}
	var center := Vector2(pancake_model.grid_size - 1, pancake_model.grid_size - 1) * 0.5
	var maximum_radius := float(pancake_model.grid_size) * 0.34
	var samples := PackedVector2Array()
	for ring_ratio in [0.16, 0.30, 0.46, 0.62, 0.78]:
		for step in 24:
			var angle := TAU * float(step) / 24.0
			var radial := Vector2.from_angle(angle)
			samples.append(center + radial * maximum_radius * float(ring_ratio))
	var result := Dictionary(pancake_model.apply_egg_spreader_path(samples, pancake_model.parameters.spreader_medium_effect_speed, 1.0))
	if int(result.get("changed_cells", 0)) <= 0:
		return result.merged({"success": false, "reason": &"egg_spread_unchanged"}, true)
	_finish_egg_spread_visuals()
	egg_automation_applied = true
	pancake_surface.queue_redraw()
	_refresh_ui()
	return result.merged({"success": true}, true)


func _refresh_intact_egg_visual() -> void:
	if not is_node_ready():
		return
	if _egg_liquid_falling:
		return
	var show_intact := (
		pancake_model.has_egg()
		and pancake_model.egg_state == PancakeModel.EggState.CRACKED
		# A spread first egg keeps the shared liquid field visible while the second
		# egg lands.  The local override identifies that newest, still-intact egg.
		and (not pancake_model.yolk_broken or _has_intact_egg_local_override)
		and pancake_model.egg_is_on_visible_side()
		and not egg_crack_effect.visible
	)
	egg_intact_visual.visible = show_intact
	if not show_intact:
		if is_instance_valid(egg_intact_visual_second):
			egg_intact_visual_second.visible = false
		return
	if _has_intact_egg_local_override:
		egg_intact_visual.position = _intact_egg_local_override
	else:
		var egg_center := pancake_model.egg_visual_center()
		egg_intact_visual.position = (egg_center + Vector2(0.5, 0.5)) / float(pancake_model.grid_size) * pancake_surface.size
	egg_intact_visual.scale = EGG_INTACT_VISUAL_SCALE


func _restore_intact_egg_visuals_from_snapshot() -> void:
	_clear_intact_egg_visuals()
	if (
		not pancake_model.has_egg()
		or pancake_model.egg_state != PancakeModel.EggState.CRACKED
		or not pancake_model.egg_is_on_visible_side()
	):
		return
	var egg_positions: Array[Vector2] = []
	for placement in ingredient_model.placements:
		if StringName(placement.get("type", &"")) == IngredientModel.EGG:
			egg_positions.append(Vector2(placement.get("position", Vector2.ZERO)))
	if egg_positions.is_empty():
		return
	_intact_egg_local_override = (egg_positions.back() + Vector2(0.5, 0.5)) / float(pancake_model.grid_size) * pancake_surface.size
	_has_intact_egg_local_override = true
	if egg_positions.size() < 2 or pancake_model.yolk_broken or not is_instance_valid(egg_intact_visual_second):
		return
	egg_intact_visual_second.position = (egg_positions[egg_positions.size() - 2] + Vector2(0.5, 0.5)) / float(pancake_model.grid_size) * pancake_surface.size
	egg_intact_visual_second.scale = EGG_INTACT_VISUAL_SCALE
	egg_intact_visual_second.modulate = Color.WHITE
	egg_intact_visual_second.visible = true


func _process_sauce_brush() -> void:
	var current := Vector2(PancakeSpace.local_to_grid(pancake_surface.pointer_local_position, pancake_surface.size, pancake_model.grid_size))
	if _spread_has_previous:
		var movement := current - _spread_previous_grid
		if movement.length_squared() > 0.0001:
			_last_tool_direction = movement.normalized()
	_surface_changed = _apply_sauce_sample(current) or _surface_changed
	_spread_previous_grid = current
	_spread_has_previous = true


func _apply_sauce_sample(grid_position: Vector2) -> bool:
	if _sauce_stroke_id < 0 or _surface_stock_id.is_empty():
		return false
	var sauce_type: StringName = &"sweet_flour"
	var result := Dictionary(pancake_model.apply_sauce_sample(grid_position, 0.18, 3.8, _sauce_stroke_id, 2147483647, sauce_type))
	var changed := bool(result.get("success", false)) or int(result.get("changed_cells", 0)) > 0
	return changed


func _nearest_valid_sauce_grid_position() -> Vector2:
	var center := Vector2.ONE * float(pancake_model.grid_size - 1) * 0.5
	var nearest := Vector2(-1.0, -1.0)
	var nearest_distance_squared := INF
	for y in pancake_model.grid_size:
		for x in pancake_model.grid_size:
			var grid_position := Vector2(x, y)
			if not pancake_model.is_inside_pan(grid_position):
				continue
			var cell_index := pancake_model.index_of(Vector2i(x, y))
			if cell_index < 0 or pancake_model.coverage[cell_index] <= 0.0:
				continue
			if pancake_model.damage[cell_index] >= pancake_model.parameters.hole_damage_threshold:
				continue
			var distance_squared := center.distance_squared_to(grid_position)
			if distance_squared < nearest_distance_squared:
				nearest_distance_squared = distance_squared
				nearest = grid_position
	return nearest


func validate_ingredient_drop(source_ref: Dictionary, local_position: Vector2) -> Dictionary:
	if upgrade_locked:
		return {"success": false, "reason": &"griddle_locked"}
	var stock_id := _stock_id_from_source(source_ref)
	var ingredient_type := _ingredient_type_for_stock(stock_id)
	if ingredient_type.is_empty():
		return {"success": false, "reason": &"not_pancake_ingredient"}
	if ingredient_model.count_type(ingredient_type) >= IngredientModel.MAX_PORTIONS_PER_TYPE:
		return {"success": false, "reason": &"portion_limit", "stock_id": stock_id}
	if ingredient_type == IngredientModel.EGG and state != State.FIRST_SIDE:
		return {"success": false, "reason": &"wrong_stage", "stock_id": stock_id}
	if ingredient_type != IngredientModel.EGG and (not pancake_model.is_flipped or state not in [State.SECOND_SIDE, State.GARNISH]):
		return {"success": false, "reason": &"wrong_stage", "stock_id": stock_id}
	# Keep the continuous cursor position for the visual placement.  The
	# ingredient layer maps grid coordinates from 0..grid_size - 1 back to the
	# pancake surface, so storing a rounded cell here made every dropped item
	# visibly snap a few pixels away from its drag preview.
	var grid_maximum := float(pancake_model.grid_size - 1)
	var grid_position := local_position / pancake_surface.size * grid_maximum
	# Worktop taps deliberately target the middle of the pancake.  Without a
	# repeat offset, a second portion would be added successfully but render
	# exactly on top of the first one.  Preserve a precise drag location, while
	# giving a centre-tapped repeat portion its own authored, visible spot.
	grid_position = _resolve_repeat_portion_position(ingredient_type, grid_position)
	var cell := Vector2i(roundi(grid_position.x), roundi(grid_position.y))
	var cell_index := pancake_model.index_of(cell)
	if cell_index < 0 or not pancake_model.is_inside_pan(grid_position):
		return {"success": false, "reason": &"outside_pancake", "stock_id": stock_id}
	if pancake_model.coverage[cell_index] <= 0.0 or pancake_model.damage[cell_index] >= pancake_model.parameters.hole_damage_threshold:
		return {"success": false, "reason": &"outside_pancake", "stock_id": stock_id}
	if ingredient_type == IngredientModel.EGG:
		var crack_preview := Dictionary(pancake_model.can_crack_egg(grid_position))
		if not bool(crack_preview.get("success", false)):
			return crack_preview.merged({"stock_id": stock_id, "grid_position": grid_position}, true)
	var resolved_local_position := grid_position / maxf(grid_maximum, 1.0) * pancake_surface.size
	return {"success": true, "stock_id": stock_id, "ingredient_type": ingredient_type, "product_id": StringName(source_ref.get("product_id", &"")), "grid_position": grid_position, "local_position": resolved_local_position}


func _resolve_repeat_portion_position(ingredient_type: StringName, requested_position: Vector2) -> Vector2:
	var portion_index := ingredient_model.count_type(ingredient_type)
	if portion_index <= 0:
		return requested_position
	var center := Vector2.ONE * float(pancake_model.grid_size - 1) * 0.5
	# A manually placed repeat portion should remain exactly where the player
	# dropped it. Only the centre tap used by the shared ingredient sources is
	# fanned out for readability.
	if requested_position.distance_to(center) > 1.0:
		return requested_position
	# Use different, ingredient-aware directions. Large artwork such as crisp and
	# pork floss stays near the middle; compact garnish and the second egg can be
	# moved farther without extending beyond the elliptical pancake.
	var repeat_offset := _repeat_portion_offset(ingredient_type)
	var candidate := center + repeat_offset
	var cell_index := pancake_model.index_of(Vector2i(roundi(candidate.x), roundi(candidate.y)))
	if (
		cell_index >= 0
		and pancake_model.is_inside_pan(candidate)
		and pancake_model.coverage[cell_index] > 0.0
		and pancake_model.damage[cell_index] < pancake_model.parameters.hole_damage_threshold
	):
		return candidate
	return requested_position


func _repeat_portion_offset(ingredient_type: StringName) -> Vector2:
	match ingredient_type:
		IngredientModel.EGG:
			return Vector2(18.0, -4.0)
		IngredientModel.BAOCUI:
			return Vector2(5.0, 0.0)
		IngredientModel.MEAT_FLOSS:
			return Vector2(6.0, 0.0)
		IngredientModel.HAM_SAUSAGE:
			return Vector2(-12.0, 0.0)
		IngredientModel.SCALLION:
			return Vector2(15.0, 0.0)
		IngredientModel.CORIANDER:
			return Vector2(-14.0, 0.0)
	return Vector2(6.0, 0.0)


func place_validated_ingredient(validation: Dictionary) -> Dictionary:
	if not bool(validation.get("success", false)):
		return validation
	var stock_id := StringName(validation.get("stock_id", &""))
	var ingredient_type := StringName(validation.get("ingredient_type", &""))
	var grid_position := Vector2(validation.get("grid_position", Vector2.ZERO))
	# The native drag preview is upright. Preserve that orientation after release
	# so an ingredient never visibly snaps to a different angle when it lands.
	var placed := Dictionary(ingredient_model.place(ingredient_type, grid_position, 0.0, pancake_model, StringName(validation.get("product_id", &""))))
	if not bool(placed.get("success", false)):
		return placed
	if ingredient_type == IngredientModel.EGG:
		var cracked := Dictionary(pancake_model.crack_egg(grid_position))
		if not bool(cracked.get("success", false)):
			return cracked
		var local_position := Vector2(validation.get("local_position", PancakeSpace.grid_to_local(Vector2i(grid_position), pancake_surface.size, pancake_model.grid_size)))
		_play_egg_crack_effect(local_position)
	applied_ingredient_ids.append(str(stock_id))
	_refresh_ui()
	return {"success": true, "stock_id": stock_id, "ingredient_type": ingredient_type}


func can_apply_sauce_at(local_position: Vector2) -> bool:
	if not pancake_model.is_flipped or state not in [State.SECOND_SIDE, State.GARNISH]:
		return false
	var grid_position := Vector2(PancakeSpace.local_to_grid(local_position, pancake_surface.size, pancake_model.grid_size))
	var cell := Vector2i(roundi(grid_position.x), roundi(grid_position.y))
	var cell_index := pancake_model.index_of(cell)
	return (
		cell_index >= 0
		and pancake_model.is_inside_pan(grid_position)
		and pancake_model.coverage[cell_index] > 0.0
		and pancake_model.damage[cell_index] < pancake_model.parameters.hole_damage_threshold
	)


func cancel_held_tool() -> void:
	_batter_ladle_armed = false
	_reset_surface_action()
	if is_node_ready():
		_refresh_ui()


func can_accept_pancake_surface_drop(source_ref: Dictionary, local_position: Vector2) -> bool:
	var station := get_parent()
	return station != null and station.has_method("can_drop_on_unit") and bool(station.call("can_drop_on_unit", unit_index, source_ref, local_position))


func can_preview_pancake_surface_drop(source_ref: Dictionary, local_position: Vector2) -> bool:
	var station := get_parent()
	return station != null and station.has_method("can_preview_drop_on_unit") and bool(station.call("can_preview_drop_on_unit", unit_index, source_ref, local_position))


func accept_pancake_surface_drop(source_ref: Dictionary, local_position: Vector2) -> void:
	var station := get_parent()
	if station != null and station.has_method("drop_on_unit"):
		station.call("drop_on_unit", unit_index, source_ref, local_position)


func _stock_id_from_source(source_ref: Dictionary) -> StringName:
	if StringName(source_ref.get("product_id", &"")) == &"product.youtiao.plain":
		return &"stock.pancake.youtiao"
	return StringName(source_ref.get("stock_id", &""))


func _cancel_surface_action() -> void:
	var station := get_parent()
	if _surface_action.is_empty() and station != null and station.has_method("clear_held_tool"):
		station.call("clear_held_tool")
	elif station != null and station.has_method("complete_surface_action"):
		station.call("complete_surface_action", unit_index, _surface_action, _surface_changed)
	_reset_surface_action()


func _reset_surface_action() -> void:
	_surface_action = SURFACE_ACTION_NONE
	_surface_stock_id = &""
	_surface_changed = false
	_surface_width_multiplier = 1.0
	_sauce_stroke_id = -1
	_spread_has_previous = false
	_scrape_sampler.reset()
	_egg_sampler.reset()
	_spreader_angle_initialized = false
	_spreader_speed_initialized = false
	_spreader_circle_progress = 0.0
	_spreader_circle_direction = 0.0
	_spreader_circle_has_previous = false
	pancake_surface.spreader_motion_valid = false
	_refresh_surface_cursor()
	_refresh_tool_artwork_visibility()


func _refresh_surface_cursor() -> void:
	if not is_node_ready():
		return
	pancake_surface.cursor_visual_enabled = _surface_action in [
		SURFACE_ACTION_SPREAD_BATTER,
		SURFACE_ACTION_SPREAD_EGG,
		SURFACE_ACTION_BRUSH_SAUCE,
	]
	pancake_surface.cursor_is_t_spreader = _surface_action in [SURFACE_ACTION_SPREAD_BATTER, SURFACE_ACTION_SPREAD_EGG]
	pancake_surface.cursor_is_sauce_brush = _surface_action == SURFACE_ACTION_BRUSH_SAUCE
	pancake_surface.cursor_radius_pixels = 16.0 * _surface_width_multiplier
	pancake_surface.cursor_sauce_color = Color(0.34, 0.08, 0.035, 0.98)
	pancake_surface.queue_redraw()


func _update_surface_tool_artwork(local_position: Vector2, delta: float = 0.0) -> void:
	if not is_node_ready():
		return
	var inside_pan := PancakeSpace.is_inside_pan(local_position, pancake_surface.size, pancake_model.parameters.pan_height_ratio)
	var spreading := _surface_action in [SURFACE_ACTION_SPREAD_BATTER, SURFACE_ACTION_SPREAD_EGG]
	var brushing := _surface_action == SURFACE_ACTION_BRUSH_SAUCE
	var spreader_active := spreading and inside_pan
	# Hardware cursors are composited by the operating system and therefore do
	# not wait for the game canvas or mutate a Sprite2D transform while moving.
	sauce_brush_artwork.visible = brushing and inside_pan
	# Direction is part of the simulation contract, not the sprite. Keep updating
	# it in the no-visual A/B mode so the test changes rendering only.
	if spreader_active:
		var radial := local_position - pancake_surface.size * 0.5
		if radial.length_squared() > 0.01:
			var target_angle := Vector2(radial.x, radial.y / maxf(pancake_model.parameters.pan_height_ratio, 0.01)).angle()
			if not _spreader_angle_initialized or delta <= 0.0:
				_spreader_smoothed_angle = target_angle
				_spreader_angle_initialized = true
			else:
				var response_blend := 1.0 - exp(-delta / SPREADER_ROTATION_RESPONSE_SECONDS)
				var target_delta := wrapf(target_angle - _spreader_smoothed_angle, -PI, PI)
				if absf(target_delta) > SPREADER_ROTATION_DEAD_ZONE:
					var effective_delta := target_delta - signf(target_delta) * SPREADER_ROTATION_DEAD_ZONE
					var maximum_step := SPREADER_MAX_TURN_RATE * delta
					_spreader_smoothed_angle = wrapf(
						_spreader_smoothed_angle + clampf(effective_delta * response_blend, -maximum_step, maximum_step),
						-PI,
						PI
					)
			pancake_surface.spreader_radial_angle = _spreader_smoothed_angle
	_update_hardware_spreader_cursor(spreader_active)
	if sauce_brush_artwork.visible:
		sauce_brush_artwork.texture = SAUCE_BRUSH_TEXTURE
		sauce_brush_artwork.rotation = _last_tool_direction.angle() + SAUCE_BRUSH_ART_ROTATION_OFFSET
	_update_surface_tool_position(local_position)


func _update_surface_tool_position(local_position: Vector2) -> void:
	if sauce_brush_artwork.visible:
		sauce_brush_artwork.position = local_position


func _refresh_tool_artwork_visibility() -> void:
	if not is_node_ready():
		return
	_deactivate_hardware_spreader_cursor()
	sauce_brush_artwork.visible = false


func _refresh_ui() -> void:
	if not is_node_ready():
		return
	griddle_art.modulate = Color(0.55, 0.50, 0.44, 0.78) if upgrade_locked else Color.WHITE
	if upgrade_locked:
		state_label.text = "升级鏊台后解锁"
		pancake_surface.visible = false
		package_visual.visible = false
		main_action.visible = false
		heat_bar.visible = false
		heat_status_label.visible = false
		return
	# Batter is now added by the ladle holder on the main worktop. This button
	# remains only for the later flip action.
	main_action.visible = state in [State.FIRST_SIDE, State.SECOND_SIDE, State.GARNISH]
	var active := state != State.IDLE or _batter_ladle_armed
	pancake_surface.visible = active and state != State.READY
	pancake_surface.batter_pour_guide_visible = _batter_ladle_armed
	pancake_surface.batter_pour_guide_center = pancake_surface.size * 0.5
	pancake_surface.batter_pour_guide_inner_radius_pixels = BEST_BATTER_INNER_RADIUS / float(GRID_SIZE) * pancake_surface.size.x
	pancake_surface.batter_pour_guide_outer_radius_pixels = BEST_BATTER_OUTER_RADIUS / float(GRID_SIZE) * pancake_surface.size.x
	pancake_surface.queue_redraw()
	package_visual.visible = state == State.READY
	_refresh_package_recipe_markers()
	fold_overlay.set_package_recipe_product(ready_product if not ready_product.is_empty() else {
		"ingredient_ids": applied_ingredient_ids,
		"sauce_ids": applied_sauce_ids,
	})
	if _package_selection_outline != null:
		_package_selection_outline.visible = _package_selection_outline.visible and package_visual.visible
	match state:
		State.IDLE:
			state_label.text = "长按鏊面倒入面糊" if _batter_ladle_armed else "空闲 · 使用面糊勺加面糊"
		State.BATTER:
			state_label.text = "拿着摊饼器绕鏊面转一圈"
			main_action.text = "手动摊面中"
		State.FIRST_SIDE:
			state_label.text = "第一面 %.1f秒 · 可加鸡蛋，完成后翻面" % first_side_seconds
			main_action.text = "翻面"
		State.SECOND_SIDE:
			state_label.text = "第二面 %.1f秒 · 可加酱加料，完成后打包" % second_side_seconds
			main_action.text = "打包"
		State.GARNISH:
			state_label.text = "可继续加酱加料，完成后打包"
			main_action.text = "打包"
		State.FOLDING:
			if _packaging_pending:
				state_label.text = "折叠完成 · 正在装入纸袋"
			elif _automatic_fold_pending_region != FOLD_MODEL_SCRIPT.REGION_NONE:
				state_label.text = "正在自动折叠煎饼"
			else:
				state_label.text = "正在自动折叠并打包"
		State.READY:
			state_label.text = "成品待交付 · 点击煎饼后点订单"
			main_action.text = "点击纸袋煎饼交付"
	main_action.disabled = state not in [State.FIRST_SIDE, State.SECOND_SIDE, State.GARNISH]
	main_action.mouse_filter = Control.MOUSE_FILTER_IGNORE if main_action.disabled else Control.MOUSE_FILTER_STOP
	fold_overlay.set_guides_visible(false)
	fold_overlay.set_automatic_pending_region(_automatic_fold_pending_region)
	_refresh_intact_egg_visual()
	_refresh_heat_visual()


func _refresh_fold_visual() -> void:
	if not is_node_ready():
		return
	var active_region: StringName = fold_model.active_region
	if active_region == FOLD_MODEL_SCRIPT.REGION_NONE:
		_fold_threshold_feedback_region = FOLD_MODEL_SCRIPT.REGION_NONE
	elif (
		fold_model.crossed_fold_line
		and _fold_threshold_feedback_region != active_region
		and not _suppress_fold_threshold_feedback
	):
		_fold_threshold_feedback_region = active_region
		fold_feedback_requested.emit(unit_index, &"snap_threshold")
	var left_progress := 1.0 if fold_model.is_region_folded(PancakeFoldModel.REGION_LEFT) else 0.0
	var right_progress := 1.0 if fold_model.is_region_folded(PancakeFoldModel.REGION_RIGHT) else 0.0
	if fold_model.active_region == PancakeFoldModel.REGION_LEFT:
		left_progress = float(fold_model.drag_progress)
	elif fold_model.active_region == PancakeFoldModel.REGION_RIGHT:
		right_progress = float(fold_model.drag_progress)
	pancake_surface.set_fold_visual_state(
		left_progress,
		right_progress,
		fold_model.package_result != PancakeFoldModel.PACKAGE_NONE,
	)


func _refresh_heat_visual() -> void:
	if not is_node_ready():
		return
	if _non_burning_upgrade_enabled:
		_apply_cooking_doneness_cap()
		_cap_existing_doneness()
	var heat_status := cooking_heat_status()
	var cooking := bool(heat_status.get("cooking", false))
	heat_bar.visible = true
	heat_status_label.visible = true
	var heat_window := heat_window()
	if not cooking:
		var inactive_text := "火候 · 已结束" if state in [State.GARNISH, State.FOLDING, State.READY] else "火候 · 未开始"
		heat_bar.configure(0.0, heat_window.x, heat_window.y, false, &"", inactive_text)
		heat_status_label.modulate = Color.WHITE
		heat_status_label.text = inactive_text
		return
	var visible_side_doneness := float(heat_status.get("doneness", 0.0))
	var charred := bool(heat_status.get("charred", false))
	var heat_stage := StringName(heat_status.get("heat_stage", COOKING_STAGE_BAR_SCRIPT.STAGE_YELLOW))
	var status_text := _heat_status_text(heat_status)
	heat_bar.configure(
		visible_side_doneness,
		heat_window.x,
		heat_window.y,
		true,
		COOKING_STAGE_BAR_SCRIPT.STAGE_RED if heat_stage == COOKING_STAGE_BAR_SCRIPT.STAGE_RED else &"",
		status_text,
	)
	heat_status_label.modulate = Color(1.0, 0.50, 0.32, 1.0) if charred else Color.WHITE
	heat_status_label.text = status_text


func cooking_heat_status() -> Dictionary:
	var cooking := state in [State.FIRST_SIDE, State.SECOND_SIDE]
	if not cooking:
		return {"cooking": false, "phase": &"", "seconds": 0.0, "doneness": 0.0, "flip_ready": false, "charred": false}
	var first_side := state == State.FIRST_SIDE
	var visible_side_doneness := pancake_model.mean_side_doneness(pancake_model.is_flipped)
	var heat_window := heat_window()
	var heat_stage := heat_stage_for_doneness(visible_side_doneness, heat_window)
	return {
		"cooking": true,
		"phase": &"first_side" if first_side else &"second_side",
		"seconds": first_side_seconds if first_side else second_side_seconds,
		"doneness": visible_side_doneness,
		"flip_ready": first_side and visible_side_doneness >= P1Session.RECOMMENDED_FLIP_DONENESS,
		"charred": heat_stage == COOKING_STAGE_BAR_SCRIPT.STAGE_RED,
		"target": (heat_window.x + heat_window.y) * 0.5,
		"green_start": heat_window.x,
		"green_end": heat_window.y,
		"heat_stage": heat_stage,
	}


func _heat_status_text(heat_status: Dictionary) -> String:
	var is_first_side := StringName(heat_status.get("phase", &"")) == &"first_side"
	var side_label := "第一面" if is_first_side else "第二面"
	var seconds := float(heat_status.get("seconds", 0.0))
	var doneness_percent := roundi(float(heat_status.get("doneness", 0.0)) * 100.0)
	if bool(heat_status.get("charred", false)):
		return "%s %.1f秒 · 已焦糊 · %d%%" % [side_label, seconds, doneness_percent]
	var stage_text: String = str({
		COOKING_STAGE_BAR_SCRIPT.STAGE_YELLOW: "未熟",
		COOKING_STAGE_BAR_SCRIPT.STAGE_GREEN: "火候合适",
		COOKING_STAGE_BAR_SCRIPT.STAGE_RED: "焦糊",
	}.get(StringName(heat_status.get("heat_stage", COOKING_STAGE_BAR_SCRIPT.STAGE_YELLOW)), "未熟"))
	if is_first_side and bool(heat_status.get("flip_ready", false)):
		return "%s %.1f秒 · %s %d%% · 可翻面" % [side_label, seconds, stage_text, doneness_percent]
	return "%s %.1f秒 · %s · %d%%" % [side_label, seconds, stage_text, doneness_percent]


static func heat_window() -> Vector2:
	return Vector2(HEAT_SUITABLE_MIN, HEAT_CHARRED_MIN)


static func heat_stage_for_doneness(doneness: float, heat_window: Vector2) -> StringName:
	if doneness < heat_window.x:
		return COOKING_STAGE_BAR_SCRIPT.STAGE_YELLOW
	if doneness < heat_window.y:
		return COOKING_STAGE_BAR_SCRIPT.STAGE_GREEN
	return COOKING_STAGE_BAR_SCRIPT.STAGE_RED


static func _ingredient_type_for_stock(stock_id: StringName) -> StringName:
	return {
		&"stock.pancake.egg": IngredientModel.EGG,
		&"stock.pancake.baocui": IngredientModel.BAOCUI,
		&"stock.pancake.ham_sausage": IngredientModel.HAM_SAUSAGE,
		&"stock.pancake.scallion": IngredientModel.SCALLION,
		&"stock.pancake.meat_floss": IngredientModel.MEAT_FLOSS,
		&"stock.pancake.pork_tenderloin": IngredientModel.PORK_TENDERLOIN,
		&"stock.pancake.coriander": IngredientModel.CORIANDER,
		&"stock.pancake.preserved_mustard": IngredientModel.PRESERVED_MUSTARD,
		&"stock.pancake.youtiao": IngredientModel.YOUTIAO,
	}.get(stock_id, &"")
