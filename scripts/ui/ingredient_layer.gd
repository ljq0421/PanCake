class_name IngredientLayer
extends Control

const FOLD_MODEL_SCRIPT := preload("res://scripts/gameplay/pancake_fold_model.gd")
const YOUTIAO_TEXTURE := preload("res://resources/art/products/youtiao/plain_youtiao_v1_five_area_v2.png")

@export var egg_texture: Texture2D
@export var baocui_texture: Texture2D
@export var ham_texture: Texture2D
@export var scallion_texture: Texture2D
@export var meat_floss_texture: Texture2D
@export var pork_tenderloin_texture: Texture2D
@export var coriander_texture: Texture2D
@export var preserved_mustard_texture: Texture2D

var model: IngredientModel
var fold_model: RefCounted
var _left_fold_progress := 0.0
var _right_fold_progress := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func set_model(value: IngredientModel) -> void:
	if model != null and model.changed.is_connected(_rebuild_sprites):
		model.changed.disconnect(_rebuild_sprites)
	model = value
	if model != null:
		model.changed.connect(_rebuild_sprites)
	_rebuild_sprites()


func set_fold_model(value: RefCounted) -> void:
	if fold_model != null and fold_model.changed.is_connected(_refresh_fold_visibility):
		fold_model.changed.disconnect(_refresh_fold_visibility)
	fold_model = value
	if fold_model != null:
		fold_model.changed.connect(_refresh_fold_visibility)
	_refresh_fold_visibility()


func _rebuild_sprites() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if model == null:
		return
	for placement in model.placements:
		# Egg is rendered from PancakeModel's liquid layer so its spread shape and score share one source of truth.
		if placement.type == IngredientModel.EGG:
			continue
		var sprite := Sprite2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.texture = texture_for(placement.type)
		var grid_maximum := 127.0
		if fold_model != null and fold_model.pancake_model != null:
			grid_maximum = maxf(float(fold_model.pancake_model.grid_size - 1), 1.0)
		sprite.position = (placement.position as Vector2) / grid_maximum * size
		sprite.rotation = float(placement.rotation)
		sprite.scale = Vector2.ONE * _scale_for(placement.type)
		sprite.modulate = Color(0.90, 0.90, 0.90, 1.0) if bool(placement.damaged) else Color.WHITE
		sprite.set_meta(&"ingredient_type", placement.type)
		sprite.set_meta(&"grid_x", float((placement.position as Vector2).x))
		add_child(sprite)
	_apply_fold_visibility()


func _refresh_fold_visibility() -> void:
	_left_fold_progress = 0.0
	_right_fold_progress = 0.0
	if fold_model != null and fold_model.pancake_model != null:
		_left_fold_progress = 1.0 if fold_model.is_region_folded(FOLD_MODEL_SCRIPT.REGION_LEFT) else 0.0
		_right_fold_progress = 1.0 if fold_model.is_region_folded(FOLD_MODEL_SCRIPT.REGION_RIGHT) else 0.0
		if fold_model.active_region == FOLD_MODEL_SCRIPT.REGION_LEFT:
			_left_fold_progress = float(fold_model.drag_progress)
		elif fold_model.active_region == FOLD_MODEL_SCRIPT.REGION_RIGHT:
			_right_fold_progress = float(fold_model.drag_progress)
	_apply_fold_visibility()


func _apply_fold_visibility() -> void:
	if fold_model == null or fold_model.pancake_model == null:
		return
	var grid_maximum := maxf(float(fold_model.pancake_model.grid_size - 1), 1.0)
	var left_line := float(fold_model.pancake_model.parameters.fold_left_line_ratio) * grid_maximum
	var right_line := float(fold_model.pancake_model.parameters.fold_right_line_ratio) * grid_maximum
	# A flap covers both its source cells and its landing cells.  Hiding only the
	# source side lets fillings in the middle show through the folded pancake.
	var left_landing_edge := lerpf(left_line, minf(grid_maximum, left_line * 2.0), _left_fold_progress)
	var right_landing_edge := lerpf(right_line, maxf(0.0, right_line * 2.0 - grid_maximum), _right_fold_progress)
	var fillings_enclosed: bool = (
		fold_model.is_region_folded(FOLD_MODEL_SCRIPT.REGION_LEFT)
		and fold_model.is_region_folded(FOLD_MODEL_SCRIPT.REGION_RIGHT)
	)
	for child in get_children():
		var sprite := child as Sprite2D
		if sprite == null or not sprite.has_meta(&"grid_x"):
			continue
		var grid_x := float(sprite.get_meta(&"grid_x"))
		var fold_progress := _fold_occlusion_progress(
			grid_x,
			left_line,
			right_line,
			left_landing_edge,
			right_landing_edge
		)
		var color := sprite.modulate
		color.a = 0.0 if fillings_enclosed else 1.0 - clampf(fold_progress, 0.0, 1.0)
		sprite.modulate = color


func _fold_occlusion_progress(
	grid_x: float,
	left_line: float,
	right_line: float,
	left_landing_edge: float,
	right_landing_edge: float
) -> float:
	var progress := 0.0
	# The lifted source is no longer visible, and the space below the landed flap
	# is covered as the fold travels inwards.
	if grid_x <= maxf(left_line, left_landing_edge):
		progress = maxf(progress, _left_fold_progress)
	if grid_x >= minf(right_line, right_landing_edge):
		progress = maxf(progress, _right_fold_progress)
	return progress


func visual_alpha_for(ingredient_type: StringName) -> float:
	for child in get_children():
		var sprite := child as Sprite2D
		if sprite != null and sprite.has_meta(&"ingredient_type") and StringName(str(sprite.get_meta(&"ingredient_type"))) == ingredient_type:
			return sprite.modulate.a
	return 0.0


func texture_for(ingredient_type: StringName) -> Texture2D:
	match ingredient_type:
		IngredientModel.EGG:
			return egg_texture
		IngredientModel.BAOCUI:
			return baocui_texture
		IngredientModel.HAM_SAUSAGE:
			return ham_texture
		IngredientModel.SCALLION:
			return scallion_texture
		IngredientModel.MEAT_FLOSS:
			return meat_floss_texture
		IngredientModel.PORK_TENDERLOIN:
			return pork_tenderloin_texture
		IngredientModel.CORIANDER:
			return coriander_texture
		IngredientModel.PRESERVED_MUSTARD:
			return preserved_mustard_texture
		IngredientModel.YOUTIAO:
			return YOUTIAO_TEXTURE
	return null


func _scale_for(ingredient_type: StringName) -> float:
	match ingredient_type:
		IngredientModel.EGG:
			return 0.14
		IngredientModel.BAOCUI:
			return 0.16
		IngredientModel.HAM_SAUSAGE:
			return 0.13
		IngredientModel.SCALLION:
			return 0.11
		IngredientModel.MEAT_FLOSS:
			return 0.16
		IngredientModel.PORK_TENDERLOIN:
			return 0.13
		IngredientModel.CORIANDER:
			return 0.11
		IngredientModel.PRESERVED_MUSTARD:
			return 0.12
		IngredientModel.YOUTIAO:
			# The five-area source is 256 px wide. Match the visible footprint of
			# the broken baocui sheet instead of retaining the legacy 768 px scale.
			return 0.78
	return 0.12
