class_name IngredientStockModel
extends RefCounted

signal changed(ingredient_type: StringName, current_stock: int)

const CAPACITY := 6

var _stock := {}
var _capacities := {}
var _ingredient_types: Array[StringName] = []


func _init(
	snapshot: Dictionary = {},
	ingredient_types: Array[StringName] = IngredientModel.TYPES,
	default_capacity: int = CAPACITY,
	start_full: bool = true
) -> void:
	_ingredient_types = ingredient_types.duplicate()
	for ingredient_type in _ingredient_types:
		_capacities[ingredient_type] = maxi(default_capacity, 0)
		_stock[ingredient_type] = capacity(ingredient_type) if start_full else 0
	load_snapshot(snapshot)


func current(ingredient_type: StringName) -> int:
	return int(_stock.get(ingredient_type, 0))


func capacity(ingredient_type: StringName) -> int:
	return int(_capacities.get(ingredient_type, 0))


func has_ingredient(ingredient_type: StringName) -> bool:
	return _ingredient_types.has(ingredient_type)


func has_stock(ingredient_type: StringName) -> bool:
	return current(ingredient_type) > 0


func consume(ingredient_type: StringName) -> bool:
	if not has_ingredient(ingredient_type) or not has_stock(ingredient_type):
		return false
	_stock[ingredient_type] = current(ingredient_type) - 1
	changed.emit(ingredient_type, current(ingredient_type))
	return true


func consume_many(ingredient_type: StringName, quantity: int) -> bool:
	if quantity <= 0 or not has_ingredient(ingredient_type) or current(ingredient_type) < quantity:
		return false
	_stock[ingredient_type] = current(ingredient_type) - quantity
	changed.emit(ingredient_type, current(ingredient_type))
	return true


func add_one(ingredient_type: StringName) -> bool:
	if not has_ingredient(ingredient_type) or current(ingredient_type) >= capacity(ingredient_type):
		return false
	_stock[ingredient_type] = current(ingredient_type) + 1
	changed.emit(ingredient_type, current(ingredient_type))
	return true


func refill(ingredient_type: StringName) -> bool:
	if not has_ingredient(ingredient_type) or current(ingredient_type) >= capacity(ingredient_type):
		return false
	_stock[ingredient_type] = capacity(ingredient_type)
	changed.emit(ingredient_type, current(ingredient_type))
	return true


func set_current(ingredient_type: StringName, quantity: int) -> bool:
	if not has_ingredient(ingredient_type):
		return false
	var next_quantity := clampi(quantity, 0, capacity(ingredient_type))
	if current(ingredient_type) == next_quantity:
		return true
	_stock[ingredient_type] = next_quantity
	changed.emit(ingredient_type, current(ingredient_type))
	return true


func set_capacity(ingredient_type: StringName, next_capacity: int) -> bool:
	if not has_ingredient(ingredient_type) or next_capacity < 0:
		return false
	if capacity(ingredient_type) == next_capacity:
		return true
	_capacities[ingredient_type] = next_capacity
	_stock[ingredient_type] = mini(current(ingredient_type), next_capacity)
	changed.emit(ingredient_type, current(ingredient_type))
	return true


func set_capacity_for_all(next_capacity: int) -> void:
	for ingredient_type in _ingredient_types:
		set_capacity(ingredient_type, next_capacity)


func snapshot() -> Dictionary:
	var result := {}
	for ingredient_type in _ingredient_types:
		result[str(ingredient_type)] = current(ingredient_type)
	return result


func load_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	for ingredient_type in _ingredient_types:
		var key := str(ingredient_type)
		if snapshot.has(key) or snapshot.has(ingredient_type):
			_stock[ingredient_type] = clampi(int(snapshot.get(key, snapshot.get(ingredient_type, current(ingredient_type)))), 0, capacity(ingredient_type))
