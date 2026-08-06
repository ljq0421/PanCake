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
}
const STABLE_TO_LEGACY_SAUCE := {
	&"stock.pancake.sauce.sweet_flour": &"sweet_flour",
	&"stock.pancake.sauce.red_chili": &"red_chili",
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


static func _tutorial_order(progression_snapshot: Dictionary, tutorial: Dictionary) -> Dictionary:
	var active_kind := StringName(tutorial.get("active_kind", &""))
	var active_id := StringName(tutorial.get("active_id", &""))
	if active_kind.is_empty() or active_id.is_empty():
		return {}
	# This generator only owns pancake training.  Other area generators will
	# consume their own queued tutorial IDs when those areas are implemented.
	if active_kind == &"area" and active_id != &"area.pancake":
		return {}
	if active_kind == &"device" and active_id != &"device.pancake_griddle":
		return {}
	if not _owns_all(progression_snapshot, [&"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.scallion", &"stock.pancake.sauce.sweet_flour"]):
		return {}
	var order := _legacy_order(&"order.pancake.classic")
	order["tutorial_no_countdown"] = true
	order["tutorial_kind"] = active_kind
	order["tutorial_id"] = active_id
	order["tutorial_guide"] = "新手指引：按顺序完成这张基础煎饼；教学单不计倒计时。" if active_kind == &"area" else "新手指引：试用新鏊子完成基础煎饼；教学单不计倒计时。"
	return order


static func _eligible_template_ids(progression_snapshot: Dictionary) -> Array[StringName]:
	var ids: Array[StringName] = []
	for template_key in CATALOG.PANCAKE_ORDER_TEMPLATES.keys():
		var template_id := StringName(template_key)
		var template := CATALOG.pancake_order_template(template_id)
		var required := Array(template.get("ingredient_stock_ids", [])) + Array(template.get("sauce_stock_ids", []))
		if Array(template.get("sauce_stock_ids", [])).size() > MAX_SAUCE_REQUIREMENTS:
			continue
		if _owns_all(progression_snapshot, required):
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
		"heat_preference": template.get("heat_preference", &"golden"),
		"time_limit": float(template.get("time_limit", 72.0)),
		"payment_coins": int(template.get("payment_coins", 1)),
		"customer_line": template.get("customer_line", "请按订单制作。"),
	}
