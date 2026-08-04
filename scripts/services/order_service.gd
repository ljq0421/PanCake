class_name OrderService
extends RefCounted

const SAUCE_SWEET: StringName = &"sweet_flour"
const SAUCE_CHILI: StringName = &"red_chili"

const ORDERS: Array[Dictionary] = [
	{
		"id": &"classic",
		"title": "经典杂粮煎饼",
		"ingredients": [IngredientModel.EGG, IngredientModel.BAOCUI, IngredientModel.SCALLION],
		"sauces": [SAUCE_SWEET],
		"heat_preference": &"golden",
		"time_limit": 72.0,
		"payment_coins": 3,
		"customer_line": "来一份经典的，薄脆和葱花都要。",
	},
	{
		"id": &"chili_ham",
		"title": "香辣火腿煎饼",
		"ingredients": [IngredientModel.EGG, IngredientModel.BAOCUI, IngredientModel.HAM_SAUSAGE],
		"sauces": [SAUCE_CHILI],
		"heat_preference": &"well_done",
		"time_limit": 76.0,
		"payment_coins": 12,
		"customer_line": "火腿加辣酱，边缘煎香一点。",
	},
	{
		"id": &"double_sauce",
		"title": "双酱全料煎饼",
		"ingredients": [IngredientModel.EGG, IngredientModel.BAOCUI, IngredientModel.HAM_SAUSAGE, IngredientModel.SCALLION],
		"sauces": [SAUCE_SWEET, SAUCE_CHILI],
		"heat_preference": &"golden",
		"time_limit": 82.0,
		"payment_coins": 22,
		"customer_line": "两种酱都刷，配料给我放匀。",
	},
	{
		"id": &"scallion_light",
		"title": "葱香少料煎饼",
		"ingredients": [IngredientModel.EGG, IngredientModel.SCALLION],
		"sauces": [SAUCE_SWEET],
		"heat_preference": &"light",
		"time_limit": 68.0,
		"payment_coins": 5,
		"customer_line": "不要火腿和薄脆，嫩一点就好。",
	},
]

var _cursor := 0
var _active_orders: Array[Dictionary] = []


func _init(unlocked_ingredient_ids: Array[StringName] = IngredientModel.TYPES) -> void:
	for order in ORDERS:
		var available := true
		for ingredient_id in Array(order.get("ingredients", [])):
			if not unlocked_ingredient_ids.has(StringName(ingredient_id)):
				available = false
				break
		if available:
			_active_orders.append(order)
	if _active_orders.is_empty():
		_active_orders.append(ORDERS[0])


func next_order() -> Dictionary:
	var order := order_at(_cursor)
	_cursor = (_cursor + 1) % _active_orders.size()
	return order


func order_at(index: int) -> Dictionary:
	return _active_orders[posmod(index, _active_orders.size())].duplicate(true)


static func sauce_display_name(sauce_type: StringName) -> String:
	return "甜面酱" if sauce_type == SAUCE_SWEET else "辣椒酱"


static func format_requirements(order: Dictionary) -> String:
	var ingredient_names := PackedStringArray()
	for ingredient_type in order.get("ingredients", []):
		ingredient_names.append(IngredientModel.display_name(ingredient_type))
	var sauce_names := PackedStringArray()
	for sauce_type in order.get("sauces", []):
		sauce_names.append(sauce_display_name(sauce_type))
	var heat_label: String = str({&"light": "嫩火", &"golden": "金黄", &"well_done": "偏香脆"}.get(order.get("heat_preference", &"golden"), "金黄"))
	return "%s\n配料：%s\n酱料：%s · 火候：%s" % [order.title, "、".join(ingredient_names), "、".join(sauce_names), heat_label]
