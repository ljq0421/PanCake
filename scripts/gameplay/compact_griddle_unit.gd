class_name CompactGriddleUnit
extends Control

signal main_action_requested(unit_index: int)
signal status_message_requested(message: String)

const GRID_SIZE := 64
const REFERENCE_GRID_SIZE := 128.0
const PANCAKE_MODEL_SCRIPT := preload("res://scripts/simulation/pancake_model.gd")
const INGREDIENT_MODEL_SCRIPT := preload("res://scripts/gameplay/ingredient_model.gd")
const FOLD_MODEL_SCRIPT := preload("res://scripts/gameplay/pancake_fold_model.gd")
const P1_SESSION_SCRIPT := preload("res://scripts/gameplay/p1_session.gd")
const READY_DRAG_TEXTURE := preload("res://resources/art/workstation/packaging/paper_bag_package_v1.png")
const SPREADER_NORMAL := preload("res://resources/art/workstation/tools/batter_spreader_v1_five_area_v2.png")
const SPREADER_WIDE := preload("res://resources/art/workstation/tools/batter_spreader_upgrade_v1_five_area_v2.png")
const SAUCE_BRUSH_TEXTURE := preload("res://resources/art/workstation/tools/sauce_brush_v1_five_area_v2.png")
const SPREADER_ART_ROTATION_OFFSET := 1.124
const SAUCE_BRUSH_ART_ROTATION_OFFSET := 1.02
const INITIAL_BATTER_AMOUNT := 4.0
const INITIAL_BATTER_RADIUS := 14.0
const SPREADER_SAMPLE_SPACING := 2.5
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
const EGG_CRACK_EFFECT_BASE_SCALE := Vector2(0.45, 0.45)
const EGG_CRACK_FALL_DISTANCE := 34.0
const EGG_INTACT_VISUAL_SCALE := Vector2(0.25, 0.25)
const SURFACE_ACTION_NONE: StringName = &""
const SURFACE_ACTION_SPREAD_BATTER: StringName = &"spread_batter"
const SURFACE_ACTION_SPREAD_EGG: StringName = &"spread_egg"
const SURFACE_ACTION_BRUSH_SAUCE: StringName = &"brush_sauce"
const SURFACE_ACTION_FOLD: StringName = &"fold"

enum State { IDLE, BATTER, FIRST_SIDE, SECOND_SIDE, GARNISH, FOLDING, READY }

@onready var title_label: Label = %TitleLabel
@onready var state_label: Label = %StateLabel
@onready var griddle_art: TextureRect = %GriddleArt
@onready var pancake_surface: PancakeHeatmap = %PancakeSurface
@onready var pancake_visual: TextureRect = %PancakeVisual
@onready var ingredient_layer: IngredientLayer = %IngredientLayer
@onready var fold_overlay: PancakeFoldOverlay = %PancakeFoldOverlay
@onready var egg_crack_effect: AnimatedSprite2D = %EggCrackEffect
@onready var egg_intact_visual: Sprite2D = %EggIntactVisual
@onready var spreader_artwork: Sprite2D = %SpreaderArtwork
@onready var sauce_brush_artwork: Sprite2D = %SauceBrushArtwork
@onready var package_visual: TextureRect = %PackageVisual
@onready var main_action: Button = %MainAction
@onready var heat_bar: ProgressBar = %HeatBar

var unit_index := 0
var state: State = State.IDLE
var order: Dictionary = {}
var first_side_seconds := 0.0
var second_side_seconds := 0.0
var fold_steps := 0
var applied_sauce_ids := PackedStringArray()
var applied_ingredient_ids := PackedStringArray()
var ready_product: Dictionary = {}
var upgrade_locked := false
var pancake_model: PancakeModel = PANCAKE_MODEL_SCRIPT.new(GRID_SIZE, _compact_pancake_parameters())
var ingredient_model: IngredientModel = INGREDIENT_MODEL_SCRIPT.new()
var fold_model: PancakeFoldModel = FOLD_MODEL_SCRIPT.new(pancake_model, ingredient_model)
var p1_session: P1Session = P1_SESSION_SCRIPT.new()
var _spread_previous_grid := Vector2.ZERO
var _spread_has_previous := false
var _display_name := "主鏊"
var _surface_action: StringName = SURFACE_ACTION_NONE
var _surface_stock_id: StringName = &""
var _surface_changed := false
var _surface_width_multiplier := 1.0
var _sauce_stroke_id := -1
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
var _egg_crack_tween: Tween
var _intact_egg_local_override := Vector2.ZERO
var _has_intact_egg_local_override := false


static func _compact_pancake_parameters() -> PancakeSimulationParameters:
	var compact_parameters := PancakeSimulationParameters.new()
	var spatial_scale := float(GRID_SIZE) / REFERENCE_GRID_SIZE
	compact_parameters.grid_size = GRID_SIZE
	compact_parameters.scraper_width *= spatial_scale
	compact_parameters.spreader_bar_thickness *= spatial_scale
	compact_parameters.scraper_sample_spacing *= spatial_scale
	compact_parameters.scraper_push_distance *= spatial_scale
	return compact_parameters


func _ready() -> void:
	main_action.pressed.connect(func() -> void: main_action_requested.emit(unit_index))
	pancake_surface.set_model(pancake_model)
	ingredient_layer.set_model(ingredient_model)
	ingredient_layer.set_fold_model(fold_model)
	fold_overlay.set_fold_model(fold_model)
	fold_overlay.set_fold_sauce_textures(
		pancake_surface.fold_sweet_sauce_texture(),
		pancake_surface.fold_chili_sauce_texture(),
	)
	fold_model.changed.connect(_refresh_fold_visual)
	pancake_surface.pointer_started.connect(_on_surface_pointer_started)
	pancake_surface.pointer_ended.connect(_on_surface_pointer_ended)
	pancake_surface.cancel_requested.connect(_cancel_surface_action)
	egg_crack_effect.animation_finished.connect(_on_egg_crack_animation_finished)
	_refresh_intact_egg_visual()
	_refresh_ui()


func _process(delta: float) -> void:
	var step := maxf(delta, 0.0)
	if pancake_surface.pointer_pressed:
		_update_surface_tool_artwork(pancake_surface.pointer_local_position, step)
		match _surface_action:
			SURFACE_ACTION_SPREAD_BATTER:
				_process_manual_spread(step)
			SURFACE_ACTION_SPREAD_EGG:
				_process_egg_spread(step)
			SURFACE_ACTION_BRUSH_SAUCE:
				_process_sauce_brush()
			SURFACE_ACTION_FOLD:
				fold_model.update_drag(Vector2(PancakeSpace.local_to_grid(
					pancake_surface.pointer_local_position,
					pancake_surface.size,
					pancake_model.grid_size,
				)))
	if state == State.FIRST_SIDE:
		first_side_seconds += step
		pancake_model.advance_cooking(step, p1_session.heat_level)
		p1_session.advance_elapsed_time(step)
		_refresh_heat_visual()
	elif state == State.SECOND_SIDE:
		second_side_seconds += step
		pancake_model.advance_cooking(step, p1_session.heat_level)
		p1_session.advance_elapsed_time(step)
		_refresh_heat_visual()


func configure(index: int, display_name: String = "") -> void:
	unit_index = index
	_display_name = display_name if not display_name.is_empty() else "鏊子 %d" % (unit_index + 1)
	if is_node_ready():
		title_label.text = _display_name


func set_upgrade_locked(value: bool) -> void:
	upgrade_locked = value
	process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
	if is_node_ready():
		_refresh_ui()


func begin_order(value: Dictionary) -> void:
	reset_unit()
	order = value.duplicate(true)
	p1_session.start(order)
	state = State.BATTER
	_seed_initial_batter_if_needed()
	_refresh_ui()


func advance_main() -> Dictionary:
	match state:
		State.BATTER:
			return {"success": false, "message": "按住鏊面画圈摊开；覆盖成形后松开"}
		State.FIRST_SIDE:
			if pancake_model.covered_cell_count() <= 0:
				return {"success": false, "message": "鏊面还没有完整饼皮"}
			_stop_egg_crack_effect()
			pancake_model.flip(true)
			p1_session.phase = P1Session.Phase.SECOND_SIDE
			state = State.SECOND_SIDE
			_refresh_ui()
			return {"success": true, "message": "鏊子%d已翻面，继续观察第二面" % (unit_index + 1)}
		State.SECOND_SIDE:
			return {"success": false, "message": "第二面继续受热；刷酱、放料或抓边折叠时确认火候"}
		State.GARNISH:
			return {"success": false, "message": "可继续加酱加料，也可直接抓住饼边折叠"}
		State.FOLDING:
			return {"success": false, "message": "抓住另一侧饼边，拖过折线后松开"}
		State.READY:
			return {"success": false, "message": "成品已在鏊子上，可拖到任意匹配订单"}
	return {"success": false, "message": "先给空鏊子添面糊"}


func next_sauce_id() -> StringName:
	for value in Array(order.get("sauce_ids", [])):
		var stock_id := StringName(value)
		if not applied_sauce_ids.has(str(stock_id)):
			return stock_id
	return &""


func next_ingredient_id() -> StringName:
	for value in Array(order.get("ingredient_ids", [])):
		var stock_id := StringName(value)
		if not applied_ingredient_ids.has(str(stock_id)):
			return stock_id
	return &""


func apply_sauce(stock_id: StringName) -> void:
	if stock_id.is_empty() or applied_sauce_ids.has(str(stock_id)):
		return
	var sauce_type := &"red_chili" if stock_id == &"stock.pancake.sauce.red_chili" else &"sweet_flour"
	var stroke_id := pancake_model.begin_sauce_stroke()
	var center := Vector2.ONE * float(pancake_model.grid_size - 1) * 0.5
	for offset in [-0.22, -0.08, 0.08, 0.22]:
		pancake_model.apply_sauce_sample(center + Vector2(float(pancake_model.grid_size) * offset, 0.0), 0.24, 4.5, stroke_id, 2147483647, sauce_type)
	applied_sauce_ids.append(str(stock_id))
	_refresh_ui()


func validate_sauce_prime(stock_id: StringName) -> Dictionary:
	if stock_id not in [&"stock.pancake.sauce.sweet_flour", &"stock.pancake.sauce.red_chili"]:
		return {"success": false, "reason": &"not_pancake_sauce"}
	if state not in [State.FIRST_SIDE, State.SECOND_SIDE, State.GARNISH]:
		return {"success": false, "reason": &"wrong_stage", "stock_id": stock_id}
	if state == State.FIRST_SIDE and p1_session.phase != P1Session.Phase.FIRST_SIDE:
		return {"success": false, "reason": &"wrong_stage", "stock_id": stock_id}
	if state == State.SECOND_SIDE and p1_session.phase != P1Session.Phase.SECOND_SIDE:
		return {"success": false, "reason": &"wrong_stage", "stock_id": stock_id}
	if state == State.GARNISH and p1_session.phase != P1Session.Phase.SAUCE_AND_FILLINGS:
		return {"success": false, "reason": &"wrong_stage", "stock_id": stock_id}
	if applied_sauce_ids.has(str(stock_id)):
		return {"success": false, "reason": &"duplicate_sauce", "stock_id": stock_id}
	var grid_position := _nearest_valid_sauce_grid_position()
	if grid_position.x < 0.0:
		return {"success": false, "reason": &"outside_pancake", "stock_id": stock_id}
	return {"success": true, "stock_id": stock_id, "grid_position": grid_position}


func prime_sauce(stock_id: StringName, validation: Dictionary = {}) -> Dictionary:
	var checked := validation if bool(validation.get("success", false)) else validate_sauce_prime(stock_id)
	if not bool(checked.get("success", false)):
		return checked
	var preparation: Dictionary
	if state == State.FIRST_SIDE:
		preparation = begin_garnish_without_flip()
	elif state == State.SECOND_SIDE:
		preparation = confirm_second_side_for_followup()
	else:
		preparation = {"success": true}
	if not bool(preparation.get("success", false)):
		return preparation
	var grid_position := Vector2(checked.get("grid_position", Vector2.ONE * float(pancake_model.grid_size - 1) * 0.5))
	var sauce_type: StringName = &"red_chili" if stock_id == &"stock.pancake.sauce.red_chili" else &"sweet_flour"
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


func apply_ingredient(stock_id: StringName) -> void:
	if stock_id.is_empty() or applied_ingredient_ids.has(str(stock_id)):
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
	if state == State.GARNISH:
		return {"success": true, "without_flip": true, "already_active": true}
	if state != State.FIRST_SIDE:
		return {"success": false, "reason": &"wrong_stage"}
	var preparation := Dictionary(p1_session.begin_sauce_and_fillings_without_flip())
	if not bool(preparation.get("success", false)):
		return preparation
	state = State.GARNISH
	_refresh_ui()
	return preparation


func begin_manual_fold(local_position: Vector2) -> Dictionary:
	if state not in [State.SECOND_SIDE, State.GARNISH, State.FOLDING]:
		return {"success": false, "reason": &"wrong_stage"}
	var grid_position := Vector2(PancakeSpace.local_to_grid(local_position, pancake_surface.size, pancake_model.grid_size))
	if not fold_model.begin_drag(grid_position):
		return {"success": false, "reason": &"not_fold_edge"}
	var followup := confirm_second_side_for_followup()
	if not bool(followup.get("success", false)):
		fold_model.cancel_drag()
		return followup
	if state == State.GARNISH:
		var phase_result := Dictionary(p1_session.begin_folding())
		if not bool(phase_result.get("success", false)):
			fold_model.cancel_drag()
			return phase_result
		state = State.FOLDING
	_surface_action = SURFACE_ACTION_FOLD
	_refresh_ui()
	return {"success": true, "action": SURFACE_ACTION_FOLD}


func mark_ready(product: Dictionary) -> void:
	ready_product = product.duplicate(true)
	state = State.READY
	_refresh_ui()


func is_reserving_batter() -> bool:
	return state != State.IDLE


func is_reserving_sauce(stock_id: StringName) -> bool:
	return state != State.IDLE and applied_sauce_ids.has(str(stock_id))


func source_ref() -> Dictionary:
	if state != State.READY or ready_product.is_empty():
		return {}
	return {
		"source_kind": &"pancake_griddle_ready",
		"source_index": unit_index,
		"product_id": &"product.pancake.custom",
		"product": ready_product.duplicate(true),
	}


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
		"version": 1,
		"source_index": unit_index,
		"state": int(state),
		"order": order.duplicate(true),
		"first_side_seconds": first_side_seconds,
		"second_side_seconds": second_side_seconds,
		"fold_steps": fold_steps,
		"applied_sauce_ids": applied_sauce_ids.duplicate(),
		"applied_ingredient_ids": applied_ingredient_ids.duplicate(),
		"ready_product": ready_product.duplicate(true),
		"pancake_model": pancake_model.snapshot(),
		"ingredient_model": ingredient_model.snapshot(),
		"fold_model": fold_model.snapshot(),
		"p1_session": p1_session.snapshot(),
	}


func load_snapshot(value: Dictionary) -> Dictionary:
	_has_intact_egg_local_override = false
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
	first_side_seconds = maxf(float(value.get("first_side_seconds", 0.0)), 0.0)
	second_side_seconds = maxf(float(value.get("second_side_seconds", 0.0)), 0.0)
	fold_steps = clampi(int(value.get("fold_steps", 0)), 0, 2)
	applied_sauce_ids = PackedStringArray(Array(value.get("applied_sauce_ids", [])))
	applied_ingredient_ids = PackedStringArray(Array(value.get("applied_ingredient_ids", [])))
	ready_product = Dictionary(value.get("ready_product", {})).duplicate(true)
	if is_node_ready():
		pancake_surface.set_model(pancake_model)
		ingredient_layer.set_model(ingredient_model)
		ingredient_layer.set_fold_model(fold_model)
		fold_overlay.set_fold_model(fold_model)
		_seed_initial_batter_if_needed()
		_refresh_fold_visual()
		_refresh_intact_egg_visual()
		_refresh_ui()
	return {"success": true}


func reset_unit() -> void:
	state = State.IDLE
	order.clear()
	first_side_seconds = 0.0
	second_side_seconds = 0.0
	fold_steps = 0
	applied_sauce_ids = PackedStringArray()
	applied_ingredient_ids = PackedStringArray()
	ready_product.clear()
	pancake_model.reset()
	ingredient_model.reset()
	fold_model.reset()
	_has_intact_egg_local_override = false
	p1_session.start({})
	_stop_egg_crack_effect()
	_scrape_sampler.reset()
	_egg_sampler.reset()
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
		pancake_surface.spreader_motion_valid = false
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
	if _surface_action == SURFACE_ACTION_SPREAD_BATTER and state == State.BATTER:
		var confirmed := p1_session.confirm_spread(pancake_model)
		if bool(confirmed.get("success", false)):
			state = State.FIRST_SIDE
			_refresh_ui()
	elif _surface_action == SURFACE_ACTION_FOLD and fold_model.active_region != PancakeFoldModel.REGION_NONE:
		var grid_position := Vector2(PancakeSpace.local_to_grid(_local_position, pancake_surface.size, pancake_model.grid_size))
		var fold_result := Dictionary(fold_model.release_drag(grid_position))
		_surface_changed = bool(fold_result.get("committed", false))
		if _surface_changed:
			fold_steps = fold_model.completed_fold_count()
			if fold_steps >= 2:
				p1_session.mark_ready_for_package()
				fold_model.package_with(PancakeFoldModel.PACKAGE_BAG)
				p1_session.mark_packaged()
				status_message_requested.emit("鏊子%d两面折叠完成，纸袋包装就绪" % (unit_index + 1))
			else:
				status_message_requested.emit("鏊子%d%s；再折另一侧" % [unit_index + 1, fold_model.result_label(fold_result)])
		else:
			status_message_requested.emit(str(fold_result.get("reason", "折叠未完成")))
		_refresh_ui()
	var station := get_parent()
	if station != null and station.has_method("complete_surface_action"):
		station.call("complete_surface_action", unit_index, _surface_action, _surface_changed)
	_reset_surface_action()


func _process_manual_spread(delta: float) -> void:
	var current := Vector2(PancakeSpace.local_to_grid(pancake_surface.pointer_local_position, pancake_surface.size, pancake_model.grid_size))
	var samples := _scrape_sampler.sample_to(current)
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


func _apply_radial_batter_sweep(sample: Vector2, outward_direction: Vector2, effect_speed: float) -> bool:
	var pan_center := Vector2.ONE * (float(pancake_model.grid_size) - 1.0) * 0.5
	var radial_distance := pan_center.distance_to(sample)
	var segment_count := maxi(1, ceili(radial_distance / SPREADER_SAMPLE_SPACING))
	var anchor_count := segment_count + 1
	var total_anchor_weight := float(anchor_count * (anchor_count + 1)) * 0.5
	var changed := false
	# Work from the contact point back toward the center. Newly pushed batter is
	# therefore not picked up and pushed repeatedly during the same pointer sample.
	for anchor_index in range(segment_count, -1, -1):
		var progress := float(anchor_index) / float(segment_count)
		var anchor := pan_center.lerp(sample, progress)
		var anchor_strength := float(anchor_count - anchor_index) / total_anchor_weight
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


func _seed_initial_batter_if_needed() -> void:
	if state != State.BATTER or pancake_model.covered_cell_count() > 0:
		return
	var center := Vector2.ONE * (float(pancake_model.grid_size) - 1.0) * 0.5
	pancake_model.add_batter(center, INITIAL_BATTER_AMOUNT, INITIAL_BATTER_RADIUS)
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
		_stop_egg_crack_effect()
		_has_intact_egg_local_override = false
		_refresh_intact_egg_visual()
	if not samples.is_empty():
		_previous_scrape_sample = samples[samples.size() - 1]
	_last_process_grid_position = current
	pancake_surface.spreader_motion_valid = changed
	pancake_surface.queue_redraw()


func _play_egg_crack_effect(local_position: Vector2) -> void:
	_stop_egg_crack_effect()
	_intact_egg_local_override = local_position
	_has_intact_egg_local_override = true
	egg_intact_visual.visible = false
	egg_crack_effect.position = local_position - Vector2(0.0, EGG_CRACK_FALL_DISTANCE)
	egg_crack_effect.frame = 0
	egg_crack_effect.rotation = -0.10
	egg_crack_effect.scale = EGG_CRACK_EFFECT_BASE_SCALE * 0.82
	egg_crack_effect.visible = true
	egg_crack_effect.play(&"crack")
	_egg_crack_tween = create_tween()
	_egg_crack_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_egg_crack_tween.parallel().tween_property(egg_crack_effect, "position", local_position, 0.18)
	_egg_crack_tween.parallel().tween_property(egg_crack_effect, "scale", EGG_CRACK_EFFECT_BASE_SCALE * 1.10, 0.16)
	_egg_crack_tween.parallel().tween_property(egg_crack_effect, "rotation", 0.055, 0.16)
	_egg_crack_tween.tween_property(egg_crack_effect, "scale", EGG_CRACK_EFFECT_BASE_SCALE, 0.16)
	_egg_crack_tween.parallel().tween_property(egg_crack_effect, "rotation", 0.0, 0.16)


func _on_egg_crack_animation_finished() -> void:
	_stop_egg_crack_effect()
	_refresh_intact_egg_visual()


func _stop_egg_crack_effect() -> void:
	if _egg_crack_tween != null and _egg_crack_tween.is_valid():
		_egg_crack_tween.kill()
	_egg_crack_tween = null
	if is_instance_valid(egg_crack_effect):
		egg_crack_effect.stop()
		egg_crack_effect.frame = 0
		egg_crack_effect.visible = false
		egg_crack_effect.rotation = 0.0
		egg_crack_effect.scale = EGG_CRACK_EFFECT_BASE_SCALE


func _refresh_intact_egg_visual() -> void:
	if not is_node_ready():
		return
	var show_intact := (
		pancake_model.has_egg()
		and pancake_model.egg_state == PancakeModel.EggState.CRACKED
		and not pancake_model.yolk_broken
		and pancake_model.egg_is_on_visible_side()
		and not egg_crack_effect.visible
	)
	egg_intact_visual.visible = show_intact
	if not show_intact:
		return
	if _has_intact_egg_local_override:
		egg_intact_visual.position = _intact_egg_local_override
	else:
		var egg_center := pancake_model.egg_visual_center()
		egg_intact_visual.position = (egg_center + Vector2(0.5, 0.5)) / float(pancake_model.grid_size) * pancake_surface.size
	egg_intact_visual.scale = EGG_INTACT_VISUAL_SCALE


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
	var sauce_type: StringName = &"red_chili" if _surface_stock_id == &"stock.pancake.sauce.red_chili" else &"sweet_flour"
	var result := Dictionary(pancake_model.apply_sauce_sample(grid_position, 0.18, 3.8, _sauce_stroke_id, 2147483647, sauce_type))
	var changed := bool(result.get("success", false)) or int(result.get("changed_cells", 0)) > 0
	if changed and not applied_sauce_ids.has(str(_surface_stock_id)):
		applied_sauce_ids.append(str(_surface_stock_id))
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
	if ingredient_model.has_type(ingredient_type):
		return {"success": false, "reason": &"duplicate_ingredient", "stock_id": stock_id}
	if ingredient_type == IngredientModel.EGG and state not in [State.FIRST_SIDE, State.SECOND_SIDE]:
		return {"success": false, "reason": &"wrong_stage", "stock_id": stock_id}
	if ingredient_type != IngredientModel.EGG and state not in [State.FIRST_SIDE, State.SECOND_SIDE, State.GARNISH]:
		return {"success": false, "reason": &"wrong_stage", "stock_id": stock_id}
	var grid_position := Vector2(PancakeSpace.local_to_grid(local_position, pancake_surface.size, pancake_model.grid_size))
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
	return {"success": true, "stock_id": stock_id, "ingredient_type": ingredient_type, "grid_position": grid_position, "local_position": local_position}


func place_validated_ingredient(validation: Dictionary) -> Dictionary:
	if not bool(validation.get("success", false)):
		return validation
	var stock_id := StringName(validation.get("stock_id", &""))
	var ingredient_type := StringName(validation.get("ingredient_type", &""))
	var grid_position := Vector2(validation.get("grid_position", Vector2.ZERO))
	var placed := Dictionary(ingredient_model.place(ingredient_type, grid_position, float(applied_ingredient_ids.size()) * 0.35, pancake_model))
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
	if state not in [State.FIRST_SIDE, State.SECOND_SIDE, State.GARNISH]:
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
	_reset_surface_action()


func can_accept_pancake_surface_drop(source_ref: Dictionary, local_position: Vector2) -> bool:
	var station := get_parent()
	return station != null and station.has_method("can_drop_on_unit") and bool(station.call("can_drop_on_unit", unit_index, source_ref, local_position))


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
	pancake_surface.spreader_motion_valid = false
	_refresh_surface_cursor()
	_refresh_tool_artwork_visibility()


func _refresh_surface_cursor() -> void:
	if not is_node_ready():
		return
	pancake_surface.cursor_is_t_spreader = _surface_action in [SURFACE_ACTION_SPREAD_BATTER, SURFACE_ACTION_SPREAD_EGG]
	pancake_surface.cursor_is_sauce_brush = _surface_action == SURFACE_ACTION_BRUSH_SAUCE
	pancake_surface.cursor_radius_pixels = 16.0 * _surface_width_multiplier
	pancake_surface.cursor_sauce_color = Color(0.82, 0.10, 0.04, 0.98) if _surface_stock_id == &"stock.pancake.sauce.red_chili" else Color(0.34, 0.08, 0.035, 0.98)
	pancake_surface.queue_redraw()


func _update_surface_tool_artwork(local_position: Vector2, delta: float = 0.0) -> void:
	if not is_node_ready():
		return
	var inside_pan := PancakeSpace.is_inside_pan(local_position, pancake_surface.size, pancake_model.parameters.pan_height_ratio)
	var spreading := _surface_action in [SURFACE_ACTION_SPREAD_BATTER, SURFACE_ACTION_SPREAD_EGG]
	var brushing := _surface_action == SURFACE_ACTION_BRUSH_SAUCE
	spreader_artwork.visible = spreading and inside_pan
	sauce_brush_artwork.visible = brushing and inside_pan
	if spreader_artwork.visible:
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
		spreader_artwork.texture = SPREADER_WIDE if _surface_width_multiplier > 1.0 else SPREADER_NORMAL
		spreader_artwork.position = local_position
		spreader_artwork.rotation = _spreader_smoothed_angle + SPREADER_ART_ROTATION_OFFSET
	if sauce_brush_artwork.visible:
		sauce_brush_artwork.texture = SAUCE_BRUSH_TEXTURE
		sauce_brush_artwork.position = local_position
		sauce_brush_artwork.rotation = _last_tool_direction.angle() + SAUCE_BRUSH_ART_ROTATION_OFFSET


func _refresh_tool_artwork_visibility() -> void:
	if not is_node_ready():
		return
	spreader_artwork.visible = false
	sauce_brush_artwork.visible = false


func _refresh_ui() -> void:
	if not is_node_ready():
		return
	title_label.text = _display_name
	griddle_art.modulate = Color(0.55, 0.50, 0.44, 0.78) if upgrade_locked else Color.WHITE
	if upgrade_locked:
		state_label.text = "升级鏊台后解锁"
		pancake_surface.visible = false
		package_visual.visible = false
		main_action.visible = false
		heat_bar.value = 0.0
		return
	main_action.visible = state in [State.IDLE, State.FIRST_SIDE]
	var active := state != State.IDLE
	pancake_surface.visible = active and state != State.READY
	package_visual.visible = state == State.READY
	match state:
		State.IDLE:
			state_label.text = "空闲 · 点击添面糊"
			main_action.text = "添面糊"
		State.BATTER:
			state_label.text = "按住鏊面画圈摊开"
			main_action.text = "手动摊面中"
		State.FIRST_SIDE:
			state_label.text = "第一面 %.1f秒 · 可直接加料（交付-12分）" % first_side_seconds
			main_action.text = "翻面"
		State.SECOND_SIDE:
			state_label.text = "第二面 %.1f秒 · 后续操作确认火候" % second_side_seconds
		State.GARNISH:
			state_label.text = "未翻面备料 · 可加料折叠，交付-12分" if not pancake_model.is_flipped else "可继续加料，也可直接抓边折叠"
			main_action.text = "等待备料"
		State.FOLDING:
			state_label.text = "手动折叠 %d/2 · 抓另一侧饼边" % fold_steps
		State.READY:
			state_label.text = "成品待自由交付"
			main_action.text = "拖到匹配订单"
	main_action.disabled = state not in [State.IDLE, State.FIRST_SIDE]
	main_action.mouse_filter = Control.MOUSE_FILTER_IGNORE if main_action.disabled else Control.MOUSE_FILTER_STOP
	fold_overlay.set_guides_visible(state in [State.GARNISH, State.FOLDING])
	_refresh_intact_egg_visual()
	_refresh_heat_visual()


func _refresh_fold_visual() -> void:
	if not is_node_ready():
		return
	var left_progress := 1.0 if fold_model.is_region_folded(PancakeFoldModel.REGION_LEFT) else 0.0
	var right_progress := 1.0 if fold_model.is_region_folded(PancakeFoldModel.REGION_RIGHT) else 0.0
	if fold_model.active_region == PancakeFoldModel.REGION_LEFT:
		left_progress = float(fold_model.drag_progress)
	elif fold_model.active_region == PancakeFoldModel.REGION_RIGHT:
		right_progress = float(fold_model.drag_progress)
	pancake_surface.set_fold_visual_state(left_progress, right_progress, fold_model.package_result != PancakeFoldModel.PACKAGE_NONE)


func _refresh_heat_visual() -> void:
	if not is_node_ready():
		return
	var summary := pancake_model.calculate_summary()
	var doneness := maxf(float(summary.get("mean_doneness", 0.0)), float(summary.get("mean_back_doneness", 0.0)))
	heat_bar.value = clampf(doneness * 100.0, 0.0, 100.0)
	if state == State.FIRST_SIDE:
		state_label.text = "第一面 %.1f秒 · 可直接加料（交付-12分）" % first_side_seconds
	elif state == State.SECOND_SIDE:
		state_label.text = "第二面 %.1f秒" % second_side_seconds


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
