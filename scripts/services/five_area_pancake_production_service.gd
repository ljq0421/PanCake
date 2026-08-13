class_name FiveAreaPancakeProductionService
extends RefCounted

## Bridges the existing mouse-driven pancake simulation to five-area inventory.
## The simulation owns quality; this service owns stable product/accounting IDs.

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const LEGACY_INGREDIENT_TO_STOCK := {
	&"egg": &"stock.pancake.egg",
	&"baocui": &"stock.pancake.baocui",
	&"scallion": &"stock.pancake.scallion",
	&"ham_sausage": &"stock.pancake.ham_sausage",
	&"meat_floss": &"stock.pancake.meat_floss",
	&"pork_tenderloin": &"stock.pancake.pork_tenderloin",
	&"coriander": &"stock.pancake.coriander",
	&"preserved_mustard": &"stock.pancake.preserved_mustard",
	&"youtiao": &"stock.pancake.youtiao",
}
const LEGACY_SAUCE_TO_STOCK := {
	&"sweet_flour": &"stock.pancake.sauce.sweet_flour",
	&"red_chili": &"stock.pancake.sauce.red_chili",
}

var _session: Node
var _product_sequence := 0


func _init(session: Node) -> void:
	_session = session


func can_produce() -> Dictionary:
	if _session == null or not _session.has_method("progression_service"):
		return {"success": false, "reason": &"no_game_session"}
	var progression: RefCounted = _session.call("progression_service")
	if not bool(progression.call("owns_area", &"area.pancake")) or not bool(progression.call("owns_recipe", &"recipe.pancake.base")):
		return {"success": false, "reason": &"recipe_locked"}
	if _session.has_method("inventory_snapshot"):
		var inventory: Dictionary = _session.call("inventory_snapshot")
		if int(inventory.get("stock.pancake.batter", 0)) <= 0:
			return {"success": false, "reason": &"insufficient_stock", "stock_id": &"stock.pancake.batter"}
	return {"success": true}


func formal_order_from_legacy(order: Dictionary) -> Dictionary:
	var ingredient_ids := PackedStringArray()
	for ingredient_id in Array(order.get("ingredients", [])):
		var stock_id: StringName = LEGACY_INGREDIENT_TO_STOCK.get(StringName(ingredient_id), &"")
		if not stock_id.is_empty():
			ingredient_ids.append(str(stock_id))
	var sauce_ids := PackedStringArray()
	for sauce_id in Array(order.get("sauces", [])):
		var stock_id: StringName = LEGACY_SAUCE_TO_STOCK.get(StringName(sauce_id), &"")
		if not stock_id.is_empty():
			sauce_ids.append(str(stock_id))
	return {"order_id": StringName(order.get("id", &"")), "product_id": &"product.pancake.custom", "heat_preference": StringName(order.get("heat_preference", &"")), "ingredient_ids": ingredient_ids, "sauce_ids": sauce_ids}


func create_product_snapshot(score_result: Dictionary, order: Dictionary, fold_snapshot: Dictionary = {}) -> Dictionary:
	_product_sequence += 1
	var ingredient_ids := PackedStringArray()
	for ingredient_id in Array(score_result.get("applied_ingredient_ids", [])):
		var stock_id: StringName = LEGACY_INGREDIENT_TO_STOCK.get(StringName(ingredient_id), &"")
		if not stock_id.is_empty():
			ingredient_ids.append(str(stock_id))
	var sauce_ids := PackedStringArray()
	for sauce_id in Array(score_result.get("applied_sauce_ids", [])):
		var stock_id: StringName = LEGACY_SAUCE_TO_STOCK.get(StringName(sauce_id), &"")
		if not stock_id.is_empty():
			sauce_ids.append(str(stock_id))
	var ingredient_cost_stock_ids := _ingredient_cost_stock_ids(score_result, ingredient_ids)
	var cost_stock_ids := _cost_stock_ids(ingredient_cost_stock_ids, sauce_ids)
	return {
		"product_instance_id": &"product_instance.pancake.%d" % _product_sequence,
		"product_id": &"product.pancake.custom",
		"heat_preference": _actual_heat_preference(score_result),
		"ingredient_ids": ingredient_ids,
		"sauce_ids": sauce_ids,
		"cost_stock_ids": cost_stock_ids,
		"material_cost": _material_cost(cost_stock_ids),
		"fold_snapshot": fold_snapshot.duplicate(true),
		"dimension_scores": _intrinsic_dimensions(score_result),
		"score": _intrinsic_score(score_result),
		"serving_score_basis": Dictionary(score_result.get("serving_score_basis", {})).duplicate(true),
		"special_evaluation": Dictionary(score_result.get("special_evaluation", {})).duplicate(true),
	}


func settle_completed_pancake(score_result: Dictionary, order: Dictionary = {}, fold_snapshot: Dictionary = {}) -> Dictionary:
	var availability := can_produce()
	if not bool(availability.get("success", false)):
		return availability
	var consumed: Array[StringName] = [&"stock.pancake.batter"]
	for sauce_id in Array(score_result.get("applied_sauce_ids", [])):
		var stock_id: StringName = LEGACY_SAUCE_TO_STOCK.get(StringName(sauce_id), &"")
		if not stock_id.is_empty():
			consumed.append(stock_id)
	var accounting: Dictionary = _session.call("consume_inventory_stock_ids", consumed)
	if not bool(accounting.get("success", false)):
		return accounting
	var product := create_product_snapshot(score_result, order, fold_snapshot)
	return {
		"success": true,
		"area_id": &"area.pancake",
		"recipe_id": &"recipe.pancake.base",
		"product_id": &"product.pancake.custom",
		"consumed_stock_ids": consumed,
		"cost_stock_ids": product.get("cost_stock_ids", PackedStringArray()),
		"material_cost": int(product.get("material_cost", 0)),
		"product": product,
	}


func _actual_heat_preference(score_result: Dictionary) -> StringName:
	var basis := Dictionary(score_result.get("serving_score_basis", {}))
	var moments := Dictionary(basis.get("heat_moments", {}))
	if moments.is_empty():
		return StringName(score_result.get("actual_heat_preference", &"golden"))
	var mean_heat := (float(moments.get("mean_front", 0.64)) + float(moments.get("mean_back", 0.64))) * 0.5
	if mean_heat < 0.56:
		return &"light"
	if mean_heat >= 0.70:
		return &"well_done"
	return &"golden"


func _intrinsic_dimensions(score_result: Dictionary) -> Dictionary:
	var basis := Dictionary(score_result.get("serving_score_basis", {}))
	var intrinsic := Dictionary(basis.get("intrinsic_dimensions", {})).duplicate(true)
	if intrinsic.is_empty():
		intrinsic = Dictionary(score_result.get("dimensions", {})).duplicate(true)
	return intrinsic


func _intrinsic_score(score_result: Dictionary) -> float:
	var dimensions := _intrinsic_dimensions(score_result)
	if dimensions.is_empty():
		return float(score_result.get("score", 0.0))
	var total := 0.0
	for value in dimensions.values():
		total += float(value)
	return total / maxf(float(dimensions.size()), 1.0)


func _cost_stock_ids(ingredient_ids: PackedStringArray, sauce_ids: PackedStringArray) -> PackedStringArray:
	var stock_ids := PackedStringArray(["stock.pancake.batter"])
	stock_ids.append_array(ingredient_ids)
	stock_ids.append_array(sauce_ids)
	return stock_ids


func _ingredient_cost_stock_ids(score_result: Dictionary, fallback_ids: PackedStringArray) -> PackedStringArray:
	var quantities := Dictionary(score_result.get("applied_ingredient_quantities", {}))
	if quantities.is_empty():
		return fallback_ids
	var stock_ids := PackedStringArray()
	for ingredient_type in IngredientModel.ALL_TYPES:
		var stock_id: StringName = LEGACY_INGREDIENT_TO_STOCK.get(ingredient_type, &"")
		if stock_id.is_empty():
			continue
		var portions := maxi(int(quantities.get(ingredient_type, quantities.get(str(ingredient_type), 0))), 0)
		for _portion in portions:
			stock_ids.append(str(stock_id))
	return stock_ids


func _material_cost(stock_ids: PackedStringArray) -> int:
	var total := 0
	for stock_id in stock_ids:
		var definition := CATALOG.stock_definition(StringName(stock_id))
		total += maxi(int(definition.get("restock_unit_cost", 0)), 0)
	return total
