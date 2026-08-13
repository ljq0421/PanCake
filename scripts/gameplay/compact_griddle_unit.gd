class_name CompactGriddleUnit
extends Control

signal main_action_requested(unit_index: int)
signal sauce_action_requested(unit_index: int)
signal ingredient_action_requested(unit_index: int)
signal fold_action_requested(unit_index: int)
signal discard_requested(unit_index: int)

const GRID_SIZE := 64
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
const SURFACE_ACTION_NONE: StringName = &""
const SURFACE_ACTION_SPREAD_BATTER: StringName = &"spread_batter"
const SURFACE_ACTION_SPREAD_EGG: StringName = &"spread_egg"
const SURFACE_ACTION_BRUSH_SAUCE: StringName = &"brush_sauce"

enum State { IDLE, BATTER, FIRST_SIDE, SECOND_SIDE, GARNISH, FOLDING, READY }

@onready var title_label: Label = %TitleLabel
@onready var state_label: Label = %StateLabel
@onready var griddle_art: TextureRect = %GriddleArt
@onready var pancake_surface: PancakeHeatmap = %PancakeSurface
@onready var pancake_visual: TextureRect = %PancakeVisual
@onready var ingredient_layer: IngredientLayer = %IngredientLayer
@onready var spreader_artwork: Sprite2D = %SpreaderArtwork
@onready var sauce_brush_artwork: Sprite2D = %SauceBrushArtwork
@onready var package_visual: TextureRect = %PackageVisual
@onready var main_action: Button = %MainAction
@onready var sauce_action: Button = %SauceAction
@onready var ingredient_action: Button = %IngredientAction
@onready var fold_action: Button = %FoldAction
@onready var discard_action: Button = %DiscardAction
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
var pancake_model: PancakeModel = PANCAKE_MODEL_SCRIPT.new(GRID_SIZE)
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


func _ready() -> void:
	main_action.pressed.connect(func() -> void: main_action_requested.emit(unit_index))
	sauce_action.pressed.connect(func() -> void: sauce_action_requested.emit(unit_index))
	ingredient_action.pressed.connect(func() -> void: ingredient_action_requested.emit(unit_index))
	fold_action.pressed.connect(func() -> void: fold_action_requested.emit(unit_index))
	discard_action.pressed.connect(func() -> void: discard_requested.emit(unit_index))
	pancake_surface.set_model(pancake_model)
	ingredient_layer.set_model(ingredient_model)
	ingredient_layer.set_fold_model(fold_model)
	pancake_surface.pointer_started.connect(_on_surface_pointer_started)
	pancake_surface.pointer_ended.connect(_on_surface_pointer_ended)
	pancake_surface.cancel_requested.connect(_cancel_surface_action)
	_refresh_ui()


func _process(delta: float) -> void:
	var step := maxf(delta, 0.0)
	if pancake_surface.pointer_pressed:
		_update_surface_tool_artwork(pancake_surface.pointer_local_position)
		match _surface_action:
			SURFACE_ACTION_SPREAD_BATTER:
				_process_manual_spread(step)
			SURFACE_ACTION_SPREAD_EGG:
				_process_egg_spread(step)
			SURFACE_ACTION_BRUSH_SAUCE:
				_process_sauce_brush()
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
	_refresh_ui()


func advance_main() -> Dictionary:
	match state:
		State.BATTER:
			return {"success": false, "message": "按住鏊面画圈摊开；覆盖成形后松开"}
		State.FIRST_SIDE:
			if pancake_model.covered_cell_count() <= 0:
				return {"success": false, "message": "鏊面还没有完整饼皮"}
			pancake_model.flip(true)
			p1_session.phase = P1Session.Phase.SECOND_SIDE
			state = State.SECOND_SIDE
			_refresh_ui()
			return {"success": true, "message": "鏊子%d已翻面，继续观察第二面" % (unit_index + 1)}
		State.SECOND_SIDE:
			p1_session.finish_cooking(pancake_model)
			state = State.GARNISH
			_refresh_ui()
			return {"success": true, "message": "鏊子%d火候已确认，按订单加酱和小料" % (unit_index + 1)}
		State.GARNISH:
			return {"success": false, "message": "先补齐订单要求的酱料和小料，再折叠"}
		State.FOLDING:
			return {"success": false, "message": "继续点击折叠/装袋完成出餐"}
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


func advance_fold() -> Dictionary:
	if state == State.GARNISH:
		p1_session.begin_folding()
		_fold_region(PancakeFoldModel.REGION_LEFT)
		state = State.FOLDING
		fold_steps = 1
		_refresh_ui()
		return {"success": true, "ready": false, "message": "第一折完成；再折一次并装袋"}
	if state == State.FOLDING:
		_fold_region(PancakeFoldModel.REGION_RIGHT)
		fold_steps = 2
		p1_session.mark_ready_for_package()
		fold_model.package_with(PancakeFoldModel.PACKAGE_BAG)
		p1_session.mark_packaged()
		return {"success": true, "ready": true, "message": "折叠完成，纸袋包装就绪"}
	return {"success": false, "ready": false, "message": "火候确认并加完料后才能折叠"}


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
	p1_session.start({})
	_spread_has_previous = false
	_reset_surface_action()
	if is_node_ready():
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
	_surface_action = StringName(action_result.get("action", &""))
	_surface_stock_id = StringName(action_result.get("stock_id", &""))
	_surface_width_multiplier = maxf(float(action_result.get("width_multiplier", 1.0)), 1.0)
	_surface_changed = false
	var radial := local_position - pancake_surface.size * 0.5
	if radial.length_squared() > 0.0001:
		_last_tool_direction = radial.normalized()
	var grid_position := Vector2(PancakeSpace.local_to_grid(local_position, pancake_surface.size, pancake_model.grid_size))
	if _surface_action == SURFACE_ACTION_SPREAD_BATTER and pancake_model.covered_cell_count() <= 0:
		_surface_changed = pancake_model.add_batter(grid_position, 1.35, 8.0) > 0
	elif _surface_action == SURFACE_ACTION_BRUSH_SAUCE:
		_sauce_stroke_id = pancake_model.begin_sauce_stroke()
		_surface_changed = _apply_sauce_sample(grid_position) or _surface_changed
	_spread_previous_grid = grid_position
	_spread_has_previous = true
	_refresh_surface_cursor()
	_update_surface_tool_artwork(local_position)


func _on_surface_pointer_ended(_local_position: Vector2) -> void:
	_spread_has_previous = false
	if _surface_action == SURFACE_ACTION_SPREAD_BATTER and state == State.BATTER:
		var summary := pancake_model.calculate_summary()
		if float(summary.get("coverage_ratio", 0.0)) < 0.48:
			state_label.text = "继续画圈 · 当前覆盖%d%%" % roundi(float(summary.get("coverage_ratio", 0.0)) * 100.0)
		else:
			var confirmed := p1_session.confirm_spread(pancake_model)
			if bool(confirmed.get("success", false)):
				state = State.FIRST_SIDE
				_refresh_ui()
	var station := get_parent()
	if station != null and station.has_method("complete_surface_action"):
		station.call("complete_surface_action", unit_index, _surface_action, _surface_changed)
	_reset_surface_action()


func _process_manual_spread(delta: float) -> void:
	var current := Vector2(PancakeSpace.local_to_grid(pancake_surface.pointer_local_position, pancake_surface.size, pancake_model.grid_size))
	if not _spread_has_previous:
		_spread_previous_grid = current
		_spread_has_previous = true
	var movement: Vector2 = current - _spread_previous_grid
	var direction: Vector2 = movement.normalized() if movement.length_squared() > 0.0001 else Vector2.RIGHT
	if movement.length_squared() > 0.0001:
		_last_tool_direction = direction
	var speed: float = movement.length() / maxf(delta, 0.001)
	var result := Dictionary(pancake_model.apply_scraper_sample(current, direction, speed, _surface_width_multiplier))
	_surface_changed = bool(result.get("success", false)) or int(result.get("changed_cells", 0)) > 0 or _surface_changed
	_spread_previous_grid = current


func _process_egg_spread(delta: float) -> void:
	var current := Vector2(PancakeSpace.local_to_grid(pancake_surface.pointer_local_position, pancake_surface.size, pancake_model.grid_size))
	if not _spread_has_previous:
		_spread_previous_grid = current
		_spread_has_previous = true
	var movement := current - _spread_previous_grid
	var direction: Vector2 = movement.normalized() if movement.length_squared() > 0.0001 else Vector2.RIGHT
	if movement.length_squared() > 0.0001:
		_last_tool_direction = direction
	var speed: float = movement.length() / maxf(delta, 0.001)
	var result := Dictionary(pancake_model.apply_egg_spreader_sample(current, direction, speed, true, _surface_width_multiplier))
	_surface_changed = bool(result.get("success", false)) or int(result.get("changed_cells", 0)) > 0 or _surface_changed
	_spread_previous_grid = current


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


func validate_ingredient_drop(source_ref: Dictionary, local_position: Vector2) -> Dictionary:
	if upgrade_locked:
		return {"success": false, "reason": &"griddle_locked"}
	var stock_id := _stock_id_from_source(source_ref)
	var ingredient_type := _ingredient_type_for_stock(stock_id)
	if ingredient_type.is_empty():
		return {"success": false, "reason": &"not_pancake_ingredient"}
	if ingredient_model.has_type(ingredient_type):
		return {"success": false, "reason": &"duplicate_ingredient", "stock_id": stock_id}
	if ingredient_type == IngredientModel.EGG and state != State.FIRST_SIDE:
		return {"success": false, "reason": &"wrong_stage", "stock_id": stock_id}
	if ingredient_type != IngredientModel.EGG and state != State.GARNISH:
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
	return {"success": true, "stock_id": stock_id, "ingredient_type": ingredient_type, "grid_position": grid_position}


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
	applied_ingredient_ids.append(str(stock_id))
	_refresh_ui()
	return {"success": true, "stock_id": stock_id, "ingredient_type": ingredient_type}


func can_apply_sauce_at(local_position: Vector2) -> bool:
	if state != State.GARNISH:
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


func _update_surface_tool_artwork(local_position: Vector2) -> void:
	if not is_node_ready():
		return
	var inside_pan := PancakeSpace.is_inside_pan(local_position, pancake_surface.size, pancake_model.parameters.pan_height_ratio)
	var spreading := _surface_action in [SURFACE_ACTION_SPREAD_BATTER, SURFACE_ACTION_SPREAD_EGG]
	var brushing := _surface_action == SURFACE_ACTION_BRUSH_SAUCE
	spreader_artwork.visible = spreading and inside_pan
	sauce_brush_artwork.visible = brushing and inside_pan
	if spreader_artwork.visible:
		spreader_artwork.texture = SPREADER_WIDE if _surface_width_multiplier > 1.0 else SPREADER_NORMAL
		spreader_artwork.position = local_position
		spreader_artwork.rotation = _last_tool_direction.angle() + SPREADER_ART_ROTATION_OFFSET
	if sauce_brush_artwork.visible:
		sauce_brush_artwork.texture = SAUCE_BRUSH_TEXTURE
		sauce_brush_artwork.position = local_position
		sauce_brush_artwork.rotation = _last_tool_direction.angle() + SAUCE_BRUSH_ART_ROTATION_OFFSET


func _refresh_tool_artwork_visibility() -> void:
	if not is_node_ready():
		return
	spreader_artwork.visible = false
	sauce_brush_artwork.visible = false


func _fold_region(region: StringName) -> void:
	var center_y := float(pancake_model.grid_size - 1) * 0.5
	if region == PancakeFoldModel.REGION_LEFT:
		fold_model.begin_drag(Vector2(1.0, center_y))
		fold_model.release_drag(Vector2(float(pancake_model.grid_size) * 0.70, center_y))
	else:
		fold_model.begin_drag(Vector2(float(pancake_model.grid_size - 2), center_y))
		fold_model.release_drag(Vector2(float(pancake_model.grid_size) * 0.30, center_y))


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
		sauce_action.visible = false
		ingredient_action.visible = false
		fold_action.visible = false
		discard_action.visible = false
		heat_bar.value = 0.0
		return
	main_action.visible = true
	var active := state != State.IDLE
	pancake_surface.visible = active and state != State.READY
	package_visual.visible = state == State.READY
	discard_action.visible = active
	match state:
		State.IDLE:
			state_label.text = "空闲 · 点击添面糊"
			main_action.text = "添面糊"
		State.BATTER:
			state_label.text = "按住鏊面画圈摊开"
			main_action.text = "手动摊面中"
		State.FIRST_SIDE:
			state_label.text = "第一面 %.1f秒" % first_side_seconds
			main_action.text = "翻面"
		State.SECOND_SIDE:
			state_label.text = "第二面 %.1f秒" % second_side_seconds
			main_action.text = "确认火候"
		State.GARNISH:
			state_label.text = "加酱 %d/%d · 加料 %d/%d" % [applied_sauce_ids.size(), Array(order.get("sauce_ids", [])).size(), applied_ingredient_ids.size(), Array(order.get("ingredient_ids", [])).size()]
			main_action.text = "等待备料"
		State.FOLDING:
			state_label.text = "折叠 %d/2" % fold_steps
			main_action.text = "继续折叠"
		State.READY:
			state_label.text = "成品待自由交付"
			main_action.text = "拖到匹配订单"
	main_action.disabled = state in [State.BATTER, State.GARNISH, State.FOLDING, State.READY]
	main_action.mouse_filter = Control.MOUSE_FILTER_IGNORE if main_action.disabled else Control.MOUSE_FILTER_STOP
	sauce_action.visible = false
	ingredient_action.visible = false
	fold_action.visible = state in [State.GARNISH, State.FOLDING]
	sauce_action.text = "加酱 ✓" if next_sauce_id().is_empty() else "挤下一种酱"
	ingredient_action.text = "小料 ✓" if next_ingredient_id().is_empty() else "放下一种料"
	fold_action.text = "折叠" if state == State.GARNISH else "二折并装袋"
	_refresh_heat_visual()


func _refresh_heat_visual() -> void:
	if not is_node_ready():
		return
	var summary := pancake_model.calculate_summary()
	var doneness := maxf(float(summary.get("mean_doneness", 0.0)), float(summary.get("mean_back_doneness", 0.0)))
	heat_bar.value = clampf(doneness * 100.0, 0.0, 100.0)
	if state == State.FIRST_SIDE:
		state_label.text = "第一面 %.1f秒" % first_side_seconds
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
