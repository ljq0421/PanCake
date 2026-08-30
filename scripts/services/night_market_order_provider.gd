class_name NightMarketOrderProvider
extends RefCounted

const CATALOG := preload("res://scripts/data/night_market_catalog.gd")


static func create_order(recipe_id: StringName, sequence: int, customer_id: StringName, tutorial: bool = false) -> Dictionary:
	var resolved_id := CATALOG.RECIPE_TUTORIAL if tutorial else recipe_id
	var recipe := CATALOG.recipe(resolved_id)
	if recipe.is_empty():
		return {"success": false, "reason": &"unknown_recipe"}
	var item_ids := Array(recipe.get("item_ids", [])).duplicate()
	return {
		"success": true,
		"order": {
			"order_id": StringName("night.order.%04d" % sequence),
			"recipe_id": resolved_id,
			"title": str(recipe.get("label", "夜宵订单")),
			"customer_id": customer_id,
			"item_ids": item_ids,
			"time_limit": float(recipe.get("time_limit", 48.0)),
			"base_coins": int(recipe.get("sell_price", 1)),
			"remaining_patience_seconds": float(recipe.get("time_limit", 48.0)),
			"tutorial_no_countdown": tutorial,
		},
	}
