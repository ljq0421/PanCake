class_name NoodleOrderProvider
extends RefCounted

const CATALOG := preload("res://scripts/data/noodle_shop_catalog.gd")


static func create_order(
	recipe_id: StringName,
	order_sequence: int,
	customer_id: StringName,
	tutorial: bool,
) -> Dictionary:
	var recipe := CATALOG.recipe(recipe_id)
	if recipe.is_empty():
		return {"success": false, "reason": &"unknown_recipe"}
	return {
		"success": true,
		"order": {
			"order_id": StringName("noodle.order.%06d" % maxi(order_sequence, 1)),
			"customer_id": customer_id,
			"recipe_id": recipe_id,
			"product_id": recipe.get("product_id", &""),
			"title": recipe.get("label", "刀削面"),
			"noodle_profile_id": recipe.get("profile_id", &"standard"),
			"required_batch_count": CATALOG.TARGET_BATCH_COUNT,
			"broth_id": recipe.get("broth_id", &""),
			"topping_ids": Array(recipe.get("topping_ids", [])).duplicate(),
			"drain_target": Vector2(float(recipe.get("drain_min", 0.0)), float(recipe.get("drain_max", 99.0))),
			"time_limit": float(recipe.get("time_limit", 30.0)),
			"base_coins": int(recipe.get("sell_price", 1)),
			"tutorial_no_countdown": tutorial,
			"patience_seconds": 45.0,
			"remaining_patience_seconds": 45.0,
		},
	}
