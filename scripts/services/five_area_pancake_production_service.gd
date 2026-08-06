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
	return {
		"product_instance_id": &"product_instance.pancake.%d" % _product_sequence,
		"product_id": &"product.pancake.custom",
		"source_order_template_id": StringName(order.get("id", &"")),
		"heat_preference": StringName(order.get("heat_preference", &"")),
		"ingredient_ids": ingredient_ids,
		"sauce_ids": sauce_ids,
		"fold_snapshot": fold_snapshot.duplicate(true),
		"dimension_scores": Dictionary(score_result.get("dimensions", {})).duplicate(true),
		"score": float(score_result.get("score", 0.0)),
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
	return {
		"success": true,
		"area_id": &"area.pancake",
		"recipe_id": &"recipe.pancake.base",
		"product_id": &"product.pancake.custom",
		"consumed_stock_ids": consumed,
		"product": create_product_snapshot(score_result, order, fold_snapshot),
	}
