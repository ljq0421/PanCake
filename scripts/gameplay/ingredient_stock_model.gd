class_name IngredientStockModel
extends RefCounted

signal changed(ingredient_type: StringName, current_stock: int)

const CAPACITY := 6

var _stock := {}


func _init(snapshot: Dictionary = {}) -> void:
	for ingredient_type in IngredientModel.TYPES:
		_stock[ingredient_type] = CAPACITY
	load_snapshot(snapshot)


func current(ingredient_type: StringName) -> int:
	return int(_stock.get(ingredient_type, 0))


func has_stock(ingredient_type: StringName) -> bool:
	return current(ingredient_type) > 0


func consume(ingredient_type: StringName) -> bool:
	if not IngredientModel.TYPES.has(ingredient_type) or not has_stock(ingredient_type):
		return false
	_stock[ingredient_type] = current(ingredient_type) - 1
	changed.emit(ingredient_type, current(ingredient_type))
	return true


func refill(ingredient_type: StringName) -> bool:
	if not IngredientModel.TYPES.has(ingredient_type) or current(ingredient_type) >= CAPACITY:
		return false
	_stock[ingredient_type] = CAPACITY
	changed.emit(ingredient_type, CAPACITY)
	return true


func snapshot() -> Dictionary:
	var result := {}
	for ingredient_type in IngredientModel.TYPES:
		result[str(ingredient_type)] = current(ingredient_type)
	return result


func load_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	for ingredient_type in IngredientModel.TYPES:
		var key := str(ingredient_type)
		_stock[ingredient_type] = clampi(int(snapshot.get(key, snapshot.get(ingredient_type, CAPACITY))), 0, CAPACITY)
