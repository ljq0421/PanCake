class_name IngredientLayer
extends Control

@export var egg_texture: Texture2D
@export var baocui_texture: Texture2D
@export var ham_texture: Texture2D
@export var scallion_texture: Texture2D

var model: IngredientModel


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


func _rebuild_sprites() -> void:
	for child in get_children():
		child.queue_free()
	if model == null:
		return
	for placement in model.placements:
		# Egg is rendered from PancakeModel's liquid layer so its spread shape and score share one source of truth.
		if placement.type == IngredientModel.EGG:
			continue
		var sprite := Sprite2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.texture = _texture_for(placement.type)
		sprite.position = (placement.position as Vector2) / 127.0 * size
		sprite.rotation = float(placement.rotation)
		sprite.scale = Vector2.ONE * _scale_for(placement.type)
		sprite.modulate = Color(0.90, 0.90, 0.90, 1.0) if bool(placement.damaged) else Color.WHITE
		add_child(sprite)


func _texture_for(ingredient_type: StringName) -> Texture2D:
	match ingredient_type:
		IngredientModel.EGG:
			return egg_texture
		IngredientModel.BAOCUI:
			return baocui_texture
		IngredientModel.HAM_SAUSAGE:
			return ham_texture
		IngredientModel.SCALLION:
			return scallion_texture
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
	return 0.12
