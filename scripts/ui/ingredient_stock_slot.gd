class_name IngredientStockSlot
extends Button

@export var ingredient_type: StringName
@export var stock_textures: Array[Texture2D] = []

@onready var artwork: TextureRect = $Artwork
@onready var empty_label: Label = $EmptyLabel


func set_stock_quantity(quantity: int) -> void:
	var clamped := clampi(quantity, 0, stock_textures.size())
	artwork.visible = clamped > 0
	empty_label.visible = clamped == 0
	if clamped > 0:
		artwork.texture = stock_textures[clamped - 1]
