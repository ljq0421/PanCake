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
		"id": &"ham_crisp",
		"title": "火腿薄脆煎饼",
		"ingredients": [IngredientModel.EGG, IngredientModel.BAOCUI, IngredientModel.HAM_SAUSAGE],
		"sauces": [SAUCE_SWEET],
		"heat_preference": &"well_done",
		"time_limit": 76.0,
		"payment_coins": 12,
		"customer_line": "火腿薄脆，刷秘制酱料，边缘煎香一点。",
	},
	{
		"id": &"double_sauce",
		"title": "全料秘制煎饼",
		"ingredients": [IngredientModel.EGG, IngredientModel.BAOCUI, IngredientModel.HAM_SAUSAGE, IngredientModel.SCALLION],
		"sauces": [SAUCE_SWEET],
		"heat_preference": &"golden",
		"time_limit": 82.0,
		"payment_coins": 22,
		"customer_line": "刷秘制酱料，配料给我放匀。",
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
	{
		"id": &"meat_floss_sweet",
		"title": "秘制肉松煎饼",
		"ingredients": [IngredientModel.EGG, IngredientModel.BAOCUI, IngredientModel.MEAT_FLOSS, IngredientModel.SCALLION],
		"sauces": [SAUCE_SWEET],
		"heat_preference": &"golden",
		"time_limit": 84.0,
		"payment_coins": 28,
		"customer_line": "肉松铺匀些，秘制酱料和葱花都要。",
	},
	{
		"id": &"tenderloin_secret_sauce",
		"title": "秘制里脊煎饼",
		"ingredients": [IngredientModel.EGG, IngredientModel.PORK_TENDERLOIN, IngredientModel.SCALLION],
		"sauces": [SAUCE_SWEET],
		"heat_preference": &"well_done",
		"time_limit": 88.0,
		"payment_coins": 36,
		"customer_line": "里脊配秘制酱料，饼皮要结实一点。",
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
	return "秘制酱料" if sauce_type == SAUCE_SWEET else "未知酱料"


static func format_requirements(order: Dictionary) -> String:
	var ingredient_names := PackedStringArray()
	var ingredient_counts := {}
	for ingredient_type in order.get("ingredients", []):
		ingredient_counts[ingredient_type] = int(ingredient_counts.get(ingredient_type, 0)) + 1
	for ingredient_type in ingredient_counts:
		var portions := int(ingredient_counts[ingredient_type])
		var label := IngredientModel.display_name(ingredient_type)
		ingredient_names.append(label if portions == 1 else "%s×%d" % [label, portions])
	var sauce_names := PackedStringArray()
	var sauce_counts := {}
	for sauce_type in order.get("sauces", []):
		sauce_counts[sauce_type] = int(sauce_counts.get(sauce_type, 0)) + 1
	for sauce_type in sauce_counts:
		var portions := int(sauce_counts[sauce_type])
		var label := sauce_display_name(sauce_type)
		sauce_names.append(label if portions == 1 else "%s×%d" % [label, portions])
	var heat_label: String = str({&"light": "嫩火", &"golden": "金黄", &"well_done": "偏香脆"}.get(order.get("heat_preference", &"golden"), "金黄"))
	return "%s\n配料：%s\n酱料：%s · 火候：%s" % [order.title, "、".join(ingredient_names), "、".join(sauce_names), heat_label]
