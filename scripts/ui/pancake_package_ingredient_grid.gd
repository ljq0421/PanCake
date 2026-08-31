class_name PancakePackageIngredientGrid
extends Control

## One deterministic visual legend for every packaged pancake. The component is
## drawn in the bag's local coordinates, so it follows the same scale and
## transform on a griddle, in the holding tray, during packaging, and in flight.
const REFERENCE_SIZE := Vector2(164.0, 164.0)
const GRID_ORIGIN := Vector2(45.0, 62.0)
const CELL_SIZE := Vector2(22.0, 22.0)
const CELL_GAP := 2.0
# The front of the bag is a slightly left-leaning plane, rather than a
# screen-aligned rectangle.  These axes project the legend onto that plane.
# Keeping this affine transform inside the component means every reuse site
# receives the same bag-aligned composition.
const BAG_FACE_X_AXIS := Vector2(0.90, 0.015)
const BAG_FACE_Y_AXIS := Vector2(-0.05, 0.86)
const ITEM_IDS: Array[StringName] = [
	&"stock.pancake.egg",
	&"stock.pancake.baocui",
	&"stock.pancake.meat_floss",
	&"stock.pancake.ham_sausage",
	&"stock.pancake.sauce.sweet_flour",
	&"stock.pancake.scallion",
	&"stock.pancake.coriander",
	&"stock.pancake.youtiao",
]
const ITEM_TEXTURES := {
	&"stock.pancake.egg": preload("res://resources/art/ingredients/egg/egg_intact_raw_v1_five_area_v2.png"),
	&"stock.pancake.baocui": preload("res://resources/art/ingredients/baocui/baocui_intact_v1.png"),
	&"stock.pancake.meat_floss": preload("res://resources/art/ingredients/meat_floss/meat_floss_pile_v1.png"),
	&"stock.pancake.ham_sausage": preload("res://resources/art/ingredients/ham_sausage/ham_sausage_slices_v1.png"),
	&"stock.pancake.sauce.sweet_flour": preload("res://resources/art/ingredients/condiments/sweet-bean-sauce-jar-no-brush.png"),
	&"stock.pancake.scallion": preload("res://resources/art/ingredients/scallion/scallion_scattered_v1_five_area_v2.png"),
	&"stock.pancake.coriander": preload("res://resources/art/ingredients/coriander/coriander_scattered_five_area_v2.png"),
	&"stock.pancake.youtiao": preload("res://resources/art/products/youtiao/plain_youtiao_v1_five_area_v3.png"),
}
const SELECTED_BACKGROUND := Color(1.0, 0.94, 0.78, 0.94)
const SELECTED_BORDER := Color(0.34, 0.14, 0.04, 0.94)
const UNSELECTED_BACKGROUND := Color(0.18, 0.10, 0.05, 0.50)
const UNSELECTED_BORDER := Color(0.48, 0.27, 0.12, 0.62)
const CHECK_GREEN := Color(0.20, 0.64, 0.26, 1.0)

var _selected_ids := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func configure(product: Dictionary) -> void:
	var next_selected := selected_item_ids(product)
	if _selected_ids == next_selected:
		return
	_selected_ids = next_selected
	queue_redraw()


func selected_item_ids_snapshot() -> Dictionary:
	return _selected_ids.duplicate(true)


static func selected_item_ids(product: Dictionary) -> Dictionary:
	var selected := {}
	for stock_group in [Array(product.get("ingredient_ids", [])), Array(product.get("sauce_ids", []))]:
		for stock_value in stock_group:
			var stock_id := StringName(stock_value)
			if ITEM_IDS.has(stock_id):
				selected[stock_id] = true
	return selected


func _draw() -> void:
	var scale_factor := minf(size.x / REFERENCE_SIZE.x, size.y / REFERENCE_SIZE.y)
	if scale_factor <= 0.0:
		return
	var offset := (size - REFERENCE_SIZE * scale_factor) * 0.5
	var bag_face_transform := Transform2D(
		BAG_FACE_X_AXIS * scale_factor,
		BAG_FACE_Y_AXIS * scale_factor,
		offset + GRID_ORIGIN * scale_factor,
	)
	draw_set_transform_matrix(bag_face_transform)
	for item_index in ITEM_IDS.size():
		var stock_id := ITEM_IDS[item_index]
		var column := item_index % 3
		var row := item_index / 3
		var cell_rect := Rect2(
			Vector2(float(column) * (CELL_SIZE.x + CELL_GAP), float(row) * (CELL_SIZE.y + CELL_GAP)),
			CELL_SIZE,
		)
		var selected := _selected_ids.has(stock_id)
		draw_rect(cell_rect, SELECTED_BACKGROUND if selected else UNSELECTED_BACKGROUND, true)
		draw_rect(cell_rect, SELECTED_BORDER if selected else UNSELECTED_BORDER, false, 1.2, true)
		var icon_rect := cell_rect.grow(-2.5)
		var texture := ITEM_TEXTURES.get(stock_id) as Texture2D
		if texture != null:
			draw_texture_rect(texture, icon_rect, false, Color.WHITE if selected else Color(0.72, 0.66, 0.56, 0.50))
		if selected:
			_draw_check(cell_rect)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_check(cell_rect: Rect2) -> void:
	var center := cell_rect.position + Vector2(cell_rect.size.x * 0.78, cell_rect.size.y * 0.76)
	var radius := 4.5
	draw_circle(center, radius, CHECK_GREEN)
	draw_line(center + Vector2(-2.2, -0.1), center + Vector2(-0.6, 1.8), Color.WHITE, 1.5, true)
	draw_line(center + Vector2(-0.6, 1.8), center + Vector2(2.8, -2.2), Color.WHITE, 1.5, true)
