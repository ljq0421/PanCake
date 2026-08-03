extends SceneTree

var _failures := PackedStringArray()


func _initialize() -> void:
	var stock := IngredientStockModel.new()
	for ingredient_type in IngredientModel.TYPES:
		_check(stock.current(ingredient_type) == 6, "%s starts with six visual stock states" % ingredient_type)
	for _index in 6:
		_check(stock.consume(IngredientModel.EGG), "available egg stock can be consumed")
	_check(stock.current(IngredientModel.EGG) == 0, "six attempts empty the egg tray")
	_check(not stock.consume(IngredientModel.EGG), "empty stock cannot become negative")
	_check(stock.refill(IngredientModel.EGG) and stock.current(IngredientModel.EGG) == 6, "matching restock fills the tray")

	var loaded := IngredientStockModel.new({"egg": -4, "baocui": 2, "ham_sausage": 99})
	_check(loaded.current(IngredientModel.EGG) == 0, "loaded stock clamps below zero")
	_check(loaded.current(IngredientModel.BAOCUI) == 2, "loaded stock preserves valid remaining quantity")
	_check(loaded.current(IngredientModel.HAM_SAUSAGE) == 6, "loaded stock clamps above capacity")
	_check(loaded.current(IngredientModel.SCALLION) == 6, "missing old-save stock defaults to full")

	if _failures.is_empty():
		print("INGREDIENT_STOCK_SELF_CHECK_PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
