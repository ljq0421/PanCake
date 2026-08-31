class_name FiveAreaPancakeOrderGenerator
extends RefCounted

## Converts stable five-area order definitions into the existing pancake
## simulator contract.  Eligibility is derived exclusively from progression
## ownership; physical material-slot visibility and inventory quantity are not
## used to decide whether a customer can request an order.

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const STABLE_TO_LEGACY_INGREDIENT := {
	&"stock.pancake.egg": &"egg",
	&"stock.pancake.baocui": &"baocui",
	&"stock.pancake.scallion": &"scallion",
	&"stock.pancake.ham_sausage": &"ham_sausage",
	&"stock.pancake.meat_floss": &"meat_floss",
	&"stock.pancake.pork_tenderloin": &"pork_tenderloin",
	&"stock.pancake.coriander": &"coriander",
	&"stock.pancake.preserved_mustard": &"preserved_mustard",
	&"stock.pancake.youtiao": &"youtiao",
}
const STABLE_TO_LEGACY_SAUCE := {
	&"stock.pancake.sauce.sweet_flour": &"sweet_flour",
}
const MAX_SAUCE_REQUIREMENTS := 2


static func generate(progression_snapshot: Dictionary, tutorial: Dictionary, cursor: int) -> Dictionary:
	var tutorial_order := _tutorial_order(progression_snapshot, tutorial)
	if not tutorial_order.is_empty():
		return {"success": true, "order": tutorial_order, "next_cursor": cursor}
	var eligible := _eligible_template_ids(progression_snapshot)
	if eligible.is_empty():
		return {"success": false, "reason": &"no_eligible_pancake_order"}
	var index := posmod(cursor, eligible.size())
	var order := _legacy_order(eligible[index])
	return {"success": true, "order": order, "next_cursor": cursor + 1}


static func generate_for_template(progression_snapshot: Dictionary, template_id: StringName) -> Dictionary:
	if not _eligible_template_ids(progression_snapshot).has(template_id):
		return {"success": false, "reason": &"pancake_template_not_eligible", "template_id": template_id}
	return {"success": true, "order": _legacy_order(template_id), "next_cursor": 0}


static func _tutorial_order(progression_snapshot: Dictionary, tutorial: Dictionary) -> Dictionary:
	var active_kind := StringName(tutorial.get("active_kind", &""))
	var active_id := StringName(tutorial.get("active_id", &""))
	if active_kind.is_empty() or active_id.is_empty():
		return {}
	# This generator only owns pancake training.  Other area generators will
	# consume their own queued tutorial IDs when those areas are implemented.
	if active_kind != &"area" or active_id != &"area.pancake":
		return {}
	if not _owns_all(progression_snapshot, [&"stock.pancake.sauce.sweet_flour"]):
		return {}
	var order := _legacy_order(&"order.pancake.no_egg_secret")
	order["tutorial_no_countdown"] = true
	order["tutorial_kind"] = active_kind
	order["tutorial_id"] = active_id
	order["tutorial_guide"] = "新手指引：按顺序完成这张无蛋秘制煎饼；教学单不计倒计时。"
	return order


static func _eligible_template_ids(progression_snapshot: Dictionary) -> Array[StringName]:
	var ids: Array[StringName] = []
	for template_key in CATALOG.PANCAKE_ORDER_TEMPLATES.keys():
		var template_id := StringName(template_key)
		var template := CATALOG.pancake_order_template(template_id)
		var required := Array(template.get("ingredient_stock_ids", [])) + Array(template.get("sauce_stock_ids", []))
		if Array(template.get("sauce_stock_ids", [])).size() > MAX_SAUCE_REQUIREMENTS:
			continue
		var ordinary_required: Array = []
		for stock_id_variant in required:
			var stock_id := StringName(stock_id_variant)
			if StringName(CATALOG.stock_definition(stock_id).get("category", &"")) != &"prepared_add_on":
				ordinary_required.append(stock_id)
		if _owns_all(progression_snapshot, ordinary_required) and _owns_all_recipes(progression_snapshot, Array(template.get("requires_recipe_ids", []))):
			ids.append(template_id)
	ids.sort()
	return ids


static func _owns_all(progression_snapshot: Dictionary, stock_ids: Array) -> bool:
	var owned := {}
	for stock_id in Array(progression_snapshot.get("unlocked_stock_ids", [])):
		owned[StringName(stock_id)] = true
	for stock_id_variant in stock_ids:
		if not bool(owned.get(StringName(stock_id_variant), false)):
			return false
	return true


static func _owns_all_recipes(progression_snapshot: Dictionary, recipe_ids: Array) -> bool:
	var owned := {}
	for recipe_id in Array(progression_snapshot.get("unlocked_recipe_ids", [])):
		owned[StringName(recipe_id)] = true
	for recipe_id_variant in recipe_ids:
		if not bool(owned.get(StringName(recipe_id_variant), false)):
			return false
	return true


static func _legacy_order(template_id: StringName) -> Dictionary:
	var template := CATALOG.pancake_order_template(template_id)
	var ingredients := PackedStringArray()
	for stock_id_variant in Array(template.get("ingredient_stock_ids", [])):
		var ingredient_id: StringName = STABLE_TO_LEGACY_INGREDIENT.get(StringName(stock_id_variant), &"")
		if not StringName(ingredient_id).is_empty():
			ingredients.append(str(ingredient_id))
	var sauces := PackedStringArray()
	for stock_id_variant in Array(template.get("sauce_stock_ids", [])):
		var sauce_id: StringName = STABLE_TO_LEGACY_SAUCE.get(StringName(stock_id_variant), &"")
		if not StringName(sauce_id).is_empty():
			sauces.append(str(sauce_id))
	return {
		"id": template_id,
		"title": template.get("title", "煎饼订单"),
		"ingredients": ingredients,
		"sauces": sauces,
		"time_limit": float(template.get("time_limit", 72.0)),
		"payment_coins": int(template.get("payment_coins", 1)),
		"customer_line": template.get("customer_line", "请按订单制作。"),
	}
