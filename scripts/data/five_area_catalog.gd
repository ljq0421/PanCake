class_name FiveAreaCatalog
extends RefCounted

## Static five-area source of truth.  Runtime services own availability, stock
## counts and pending purchases; this catalog intentionally contains no save/UI
## state.

const BALANCE_VERSION := 3
const PANCAKE_WIDE_SPREADER_WIDTH_MULTIPLIER := 1.65

const AREA_IDS: Array[StringName] = [
	&"area.pancake",
	&"area.packaged_drink",
	&"area.youtiao",
	&"area.fresh_soy_milk",
	&"area.steamer",
]

## Physical counter order is deliberately different from the progression order.
const PHYSICAL_AREA_IDS: Array[StringName] = [
	&"area.fresh_soy_milk",
	&"area.youtiao",
	&"area.pancake",
	&"area.packaged_drink",
	&"area.steamer",
]
const UNLOCK_AREA_IDS: Array[StringName] = [
	&"area.pancake",
	&"area.packaged_drink",
	&"area.youtiao",
	&"area.fresh_soy_milk",
	&"area.steamer",
]

const AREA_DEFINITIONS := {
	&"area.pancake": {"label": "煎饼", "physical_index": 2, "unlock_index": 0, "device_id": &"device.pancake_griddle"},
	&"area.packaged_drink": {"label": "成品饮品", "physical_index": 3, "unlock_index": 1, "device_id": &"device.packaged_drink_heater"},
	&"area.youtiao": {"label": "油条", "physical_index": 1, "unlock_index": 2, "device_id": &"device.youtiao_fryer"},
	&"area.fresh_soy_milk": {"label": "现磨豆浆", "physical_index": 0, "unlock_index": 3, "device_id": &"device.fresh_soy_milk_machine"},
	&"area.steamer": {"label": "蒸品", "physical_index": 4, "unlock_index": 4, "device_id": &"device.steamer"},
}

const DEVICE_DEFINITIONS := {
	&"device.pancake_griddle": {
		"area_id": &"area.pancake",
		"tiers": [
			{"tier": 0, "label": "基础煎饼鏊子", "heat_window_bonus": 0.0, "reheat_seconds": 0.0},
			{"tier": 1, "label": "宽容火候煎饼鏊子", "heat_window_bonus": 0.12, "reheat_seconds": 0.0},
			{"tier": 2, "label": "快速回温煎饼鏊子", "heat_window_bonus": 0.12, "reheat_seconds": 1.0},
		],
	},
	&"device.packaged_drink_heater": {
		"area_id": &"area.packaged_drink",
		"tiers": [
			{"tier": 0, "label": "基础饮品加热器", "capacity": 1, "duration_seconds": 2.0, "hot_window_seconds": 8.0, "infinite_hold": false},
			{"tier": 1, "label": "双位快速饮品加热器", "capacity": 2, "duration_seconds": 1.0, "hot_window_seconds": 8.0, "infinite_hold": false},
			{"tier": 2, "label": "四位恒温饮品加热器", "capacity": 4, "duration_seconds": 1.0, "hot_window_seconds": 0.0, "infinite_hold": true},
		],
	},
	&"device.youtiao_fryer": {
		"area_id": &"area.youtiao",
		"tiers": [
			{"tier": 0, "label": "基础油条炸锅", "capacity": 2, "duration_seconds": 12.0, "safe_seconds": 5.0, "decay_seconds": 10.0, "drain_seconds": 2.0},
			{"tier": 1, "label": "快速油条炸锅", "capacity": 2, "duration_seconds": 9.0, "safe_seconds": 5.0, "decay_seconds": 10.0, "drain_seconds": 2.0},
			{"tier": 2, "label": "四份油条炸锅", "capacity": 4, "duration_seconds": 9.0, "safe_seconds": 5.0, "decay_seconds": 10.0, "drain_seconds": 2.0},
		],
	},
	&"device.fresh_soy_milk_machine": {
		"area_id": &"area.fresh_soy_milk",
		"tiers": [
			{"tier": 0, "label": "基础豆浆机", "capacity": 2, "duration_seconds": 5.0, "safe_seconds": 5.0, "decay_seconds": 10.0, "output_capacity": 0, "infinite_hold": false},
			{"tier": 1, "label": "快速豆浆机", "capacity": 2, "duration_seconds": 3.0, "safe_seconds": 5.0, "decay_seconds": 10.0, "output_capacity": 0, "infinite_hold": false},
			{"tier": 2, "label": "四杯保温豆浆机", "capacity": 4, "duration_seconds": 3.0, "safe_seconds": 0.0, "decay_seconds": 0.0, "output_capacity": 4, "infinite_hold": true},
		],
	},
	&"device.steamer": {
		"area_id": &"area.steamer",
		"tiers": [
			{"tier": 0, "label": "基础单层蒸笼", "layers": 1, "duration_multiplier": 1.0, "safe_seconds": 5.0, "decay_seconds": 10.0, "infinite_hold": false},
			{"tier": 1, "label": "快速双层蒸笼", "layers": 2, "duration_multiplier": 0.75, "safe_seconds": 5.0, "decay_seconds": 10.0, "infinite_hold": false},
			{"tier": 2, "label": "独立停汽四层蒸笼", "layers": 4, "duration_multiplier": 0.75, "safe_seconds": 0.0, "decay_seconds": 0.0, "infinite_hold": true},
		],
	},
}

## The three opening-day ingredients keep their authored Slot07-Slot09 wells.
## Later unlocked add-ons are compacted into these wells in priority order.
## Sauce inventory is a countertop input and must never be assigned a material slot.
const PANCAKE_ADD_ON_SLOT_PRIORITY: Array[StringName] = [
	&"slot.10", &"slot.11", &"slot.12", &"slot.06", &"slot.13", &"slot.05", &"slot.14",
]
const PANCAKE_ADD_ON_DISPLAY_ORDER: Array[StringName] = [
	&"stock.pancake.ham_sausage",
	&"stock.pancake.meat_floss",
	&"stock.pancake.coriander",
	&"stock.pancake.preserved_mustard",
	&"stock.pancake.pork_tenderloin",
]
const MATERIAL_SLOT_DEFINITIONS := {
	&"slot.01": {"index": 1, "area_id": &"area.fresh_soy_milk", "kind": &"stock", "stock_id": &"stock.fresh_soy_milk.yellow_bean"},
	&"slot.02": {"index": 2, "area_id": &"area.fresh_soy_milk", "kind": &"stock", "stock_id": &"stock.fresh_soy_milk.black_bean"},
	&"slot.03": {"index": 3, "area_id": &"area.youtiao", "kind": &"stock", "stock_id": &"stock.youtiao.plain_dough"},
	&"slot.04": {"index": 4, "area_id": &"area.pancake", "kind": &"reserved", "reservation_id": &"reservation.pancake.future_01"},
	&"slot.05": {"index": 5, "area_id": &"area.pancake", "kind": &"dynamic_add_on"},
	&"slot.06": {"index": 6, "area_id": &"area.pancake", "kind": &"dynamic_add_on"},
	&"slot.07": {"index": 7, "area_id": &"area.pancake", "kind": &"stock", "stock_id": &"stock.pancake.egg"},
	&"slot.08": {"index": 8, "area_id": &"area.pancake", "kind": &"stock", "stock_id": &"stock.pancake.baocui"},
	&"slot.09": {"index": 9, "area_id": &"area.pancake", "kind": &"stock", "stock_id": &"stock.pancake.scallion"},
	&"slot.10": {"index": 10, "area_id": &"area.pancake", "kind": &"dynamic_add_on"},
	&"slot.11": {"index": 11, "area_id": &"area.pancake", "kind": &"dynamic_add_on"},
	&"slot.12": {"index": 12, "area_id": &"area.pancake", "kind": &"dynamic_add_on"},
	&"slot.13": {"index": 13, "area_id": &"area.pancake", "kind": &"dynamic_add_on"},
	&"slot.14": {"index": 14, "area_id": &"area.pancake", "kind": &"dynamic_add_on"},
	&"slot.15": {"index": 15, "area_id": &"area.pancake", "kind": &"reserved", "reservation_id": &"reservation.pancake.future_05"},
	&"slot.16": {"index": 16, "area_id": &"area.packaged_drink", "kind": &"stock", "stock_id": &"stock.packaged_drink.milk"},
	&"slot.17": {"index": 17, "area_id": &"area.steamer", "kind": &"stock", "stock_id": &"stock.steamer.vegetable_bun"},
	&"slot.18": {"index": 18, "area_id": &"area.steamer", "kind": &"stock", "stock_id": &"stock.steamer.mantou"},
}

const STOCK_DEFINITIONS := {
	&"stock.pancake.batter": {"label": "面糊", "area_id": &"area.pancake", "category": &"base", "refill_seconds": 0.25, "restock_unit_cost": 1, "restock_capacity": 6, "material_slot_id": &""},
	&"stock.pancake.egg": {"area_id": &"area.pancake", "category": &"add_on", "refill_seconds": 0.20, "restock_unit_cost": 1, "restock_capacity": 6, "material_slot_id": &"slot.07"},
	&"stock.pancake.baocui": {"area_id": &"area.pancake", "category": &"add_on", "refill_seconds": 0.225, "restock_unit_cost": 1, "restock_capacity": 6, "material_slot_id": &"slot.08"},
	&"stock.pancake.scallion": {"area_id": &"area.pancake", "category": &"add_on", "refill_seconds": 0.1666667, "restock_unit_cost": 1, "restock_capacity": 6, "material_slot_id": &"slot.09"},
	&"stock.pancake.sauce.sweet_flour": {"label": "甜面酱", "area_id": &"area.pancake", "category": &"sauce", "refill_seconds": 0.25, "restock_unit_cost": 1, "restock_capacity": 6, "material_slot_id": &"", "surface_input_id": &"ui.pancake.sweet_flour_sauce_brush"},
	&"stock.pancake.sauce.red_chili": {"label": "辣酱", "area_id": &"area.pancake", "category": &"sauce", "refill_seconds": 0.25, "restock_unit_cost": 1, "restock_capacity": 6, "material_slot_id": &"", "surface_input_id": &"ui.pancake.red_chili_sauce_brush"},
	&"stock.pancake.ham_sausage": {"area_id": &"area.pancake", "category": &"add_on", "refill_seconds": 0.25, "restock_unit_cost": 2, "restock_capacity": 6, "material_slot_id": &""},
	&"stock.pancake.meat_floss": {"area_id": &"area.pancake", "category": &"add_on", "refill_seconds": 0.25, "restock_unit_cost": 2, "restock_capacity": 6, "material_slot_id": &""},
	&"stock.pancake.pork_tenderloin": {"area_id": &"area.pancake", "category": &"add_on", "refill_seconds": 0.25, "restock_unit_cost": 3, "restock_capacity": 6, "material_slot_id": &""},
	&"stock.pancake.coriander": {"area_id": &"area.pancake", "category": &"add_on", "refill_seconds": 0.25, "restock_unit_cost": 1, "restock_capacity": 6, "material_slot_id": &""},
	&"stock.pancake.preserved_mustard": {"area_id": &"area.pancake", "category": &"add_on", "refill_seconds": 0.25, "restock_unit_cost": 1, "restock_capacity": 6, "material_slot_id": &""},
	&"stock.packaged_drink.milk": {"label": "纯牛奶", "area_id": &"area.packaged_drink", "category": &"finished_drink", "refill_seconds": 0.50, "restock_unit_cost": 1, "restock_capacity": 6, "material_slot_id": &"slot.16"},
	&"stock.packaged_drink.soy_milk": {"label": "成品豆奶", "area_id": &"area.packaged_drink", "category": &"finished_drink", "refill_seconds": 0.50, "restock_unit_cost": 2, "restock_capacity": 6, "material_slot_id": &""},
	&"stock.packaged_drink.walnut": {"label": "核桃乳", "area_id": &"area.packaged_drink", "category": &"finished_drink", "refill_seconds": 0.50, "restock_unit_cost": 3, "restock_capacity": 6, "material_slot_id": &""},
	&"stock.packaged_drink.black_sesame": {"label": "黑芝麻乳", "area_id": &"area.packaged_drink", "category": &"finished_drink", "refill_seconds": 0.50, "restock_unit_cost": 4, "restock_capacity": 6, "material_slot_id": &""},
	&"stock.youtiao.plain_dough": {"label": "原味油条面胚", "area_id": &"area.youtiao", "category": &"dough", "refill_seconds": 1.50, "restock_unit_cost": 2, "restock_capacity": 6, "material_slot_id": &"slot.03"},
	&"stock.youtiao.oil_cake_dough": {"label": "油饼面胚", "area_id": &"area.youtiao", "category": &"dough", "refill_seconds": 1.50, "restock_unit_cost": 3, "restock_capacity": 6, "material_slot_id": &""},
	&"stock.youtiao.sugar_oil_cake_dough": {"label": "糖油饼面胚", "area_id": &"area.youtiao", "category": &"dough", "refill_seconds": 1.50, "restock_unit_cost": 4, "restock_capacity": 6, "material_slot_id": &""},
	&"stock.fresh_soy_milk.yellow_bean": {"label": "黄豆", "area_id": &"area.fresh_soy_milk", "category": &"bean", "refill_seconds": 1.50, "restock_unit_cost": 2, "restock_capacity": 6, "material_slot_id": &"slot.01"},
	&"stock.fresh_soy_milk.black_bean": {"label": "黑豆", "area_id": &"area.fresh_soy_milk", "category": &"bean", "refill_seconds": 1.50, "restock_unit_cost": 3, "restock_capacity": 6, "material_slot_id": &"slot.02"},
	&"stock.fresh_soy_milk.red_bean": {"label": "红豆", "area_id": &"area.fresh_soy_milk", "category": &"bean", "refill_seconds": 1.50, "restock_unit_cost": 4, "restock_capacity": 6, "material_slot_id": &""},
	&"stock.fresh_soy_milk.multigrain": {"label": "五谷豆料", "area_id": &"area.fresh_soy_milk", "category": &"bean", "refill_seconds": 1.50, "restock_unit_cost": 5, "restock_capacity": 6, "material_slot_id": &""},
	&"stock.steamer.mantou": {"label": "馒头半成品", "area_id": &"area.steamer", "category": &"semi_product", "refill_seconds": 1.50, "restock_unit_cost": 2, "restock_capacity": 6, "material_slot_id": &"slot.18"},
	&"stock.steamer.vegetable_bun": {"label": "菜包半成品", "area_id": &"area.steamer", "category": &"semi_product", "refill_seconds": 1.50, "restock_unit_cost": 3, "restock_capacity": 6, "material_slot_id": &"slot.17"},
	&"stock.steamer.meat_bun": {"label": "肉包半成品", "area_id": &"area.steamer", "category": &"semi_product", "refill_seconds": 1.50, "restock_unit_cost": 4, "restock_capacity": 6, "material_slot_id": &""},
}

const ADD_ON_DEFINITIONS := {
	&"stock.pancake.egg": {}, &"stock.pancake.baocui": {}, &"stock.pancake.scallion": {},
	&"stock.pancake.ham_sausage": {}, &"stock.pancake.meat_floss": {}, &"stock.pancake.pork_tenderloin": {},
	&"stock.pancake.coriander": {}, &"stock.pancake.preserved_mustard": {},
}
const SAUCE_DEFINITIONS := {
	&"stock.pancake.sauce.sweet_flour": {},
	&"stock.pancake.sauce.red_chili": {},
}

const RECIPE_DEFINITIONS := {
	&"recipe.pancake.base": {"area_id": &"area.pancake", "product_id": &"product.pancake.custom", "stock_ids": [&"stock.pancake.batter", &"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.scallion", &"stock.pancake.sauce.sweet_flour"]},
	&"recipe.packaged_drink.milk": {"label": "纯牛奶", "area_id": &"area.packaged_drink", "product_id": &"product.packaged_drink.milk", "stock_ids": [&"stock.packaged_drink.milk"]},
	&"recipe.packaged_drink.soy_milk": {"label": "成品豆奶", "area_id": &"area.packaged_drink", "product_id": &"product.packaged_drink.soy_milk", "stock_ids": [&"stock.packaged_drink.soy_milk"]},
	&"recipe.packaged_drink.walnut": {"label": "核桃乳", "area_id": &"area.packaged_drink", "product_id": &"product.packaged_drink.walnut", "stock_ids": [&"stock.packaged_drink.walnut"]},
	&"recipe.packaged_drink.black_sesame": {"label": "黑芝麻乳", "area_id": &"area.packaged_drink", "product_id": &"product.packaged_drink.black_sesame", "stock_ids": [&"stock.packaged_drink.black_sesame"]},
	&"recipe.youtiao.plain": {"label": "原味油条", "area_id": &"area.youtiao", "product_id": &"product.youtiao.plain", "stock_ids": [&"stock.youtiao.plain_dough"]},
	&"recipe.youtiao.oil_cake": {"label": "油饼", "area_id": &"area.youtiao", "product_id": &"product.youtiao.oil_cake", "stock_ids": [&"stock.youtiao.oil_cake_dough"]},
	&"recipe.youtiao.sugar_oil_cake": {"label": "糖油饼", "area_id": &"area.youtiao", "product_id": &"product.youtiao.sugar_oil_cake", "stock_ids": [&"stock.youtiao.sugar_oil_cake_dough"]},
	&"recipe.fresh_soy_milk.yellow_bean": {"label": "黄豆豆浆", "area_id": &"area.fresh_soy_milk", "product_id": &"product.fresh_soy_milk.yellow_bean", "stock_ids": [&"stock.fresh_soy_milk.yellow_bean"]},
	&"recipe.fresh_soy_milk.black_bean": {"label": "黑豆豆浆", "area_id": &"area.fresh_soy_milk", "product_id": &"product.fresh_soy_milk.black_bean", "stock_ids": [&"stock.fresh_soy_milk.black_bean"]},
	&"recipe.fresh_soy_milk.red_bean": {"label": "红豆豆浆", "area_id": &"area.fresh_soy_milk", "product_id": &"product.fresh_soy_milk.red_bean", "stock_ids": [&"stock.fresh_soy_milk.red_bean"]},
	&"recipe.fresh_soy_milk.multigrain": {"label": "五谷豆浆", "area_id": &"area.fresh_soy_milk", "product_id": &"product.fresh_soy_milk.multigrain", "stock_ids": [&"stock.fresh_soy_milk.multigrain"]},
	&"recipe.steamer.mantou": {"label": "馒头", "area_id": &"area.steamer", "product_id": &"product.steamer.mantou", "stock_ids": [&"stock.steamer.mantou"], "duration_seconds": 10.0},
	&"recipe.steamer.vegetable_bun": {"label": "菜包", "area_id": &"area.steamer", "product_id": &"product.steamer.vegetable_bun", "stock_ids": [&"stock.steamer.vegetable_bun"], "duration_seconds": 12.0},
	&"recipe.steamer.meat_bun": {"label": "肉包", "area_id": &"area.steamer", "product_id": &"product.steamer.meat_bun", "stock_ids": [&"stock.steamer.meat_bun"], "duration_seconds": 14.0},
}

const PRODUCT_DEFINITIONS := {
	&"product.pancake.custom": {"area_id": &"area.pancake", "recipe_id": &"recipe.pancake.base"},
	&"product.packaged_drink.milk": {"label": "纯牛奶", "area_id": &"area.packaged_drink", "recipe_id": &"recipe.packaged_drink.milk", "stock_id": &"stock.packaged_drink.milk", "base_sell_price": 3, "order_weight": 100, "can_heat": true},
	&"product.packaged_drink.soy_milk": {"label": "成品豆奶", "area_id": &"area.packaged_drink", "recipe_id": &"recipe.packaged_drink.soy_milk", "stock_id": &"stock.packaged_drink.soy_milk", "base_sell_price": 5, "order_weight": 70, "can_heat": true},
	&"product.packaged_drink.walnut": {"label": "核桃乳", "area_id": &"area.packaged_drink", "recipe_id": &"recipe.packaged_drink.walnut", "stock_id": &"stock.packaged_drink.walnut", "base_sell_price": 7, "order_weight": 70, "can_heat": true},
	&"product.packaged_drink.black_sesame": {"label": "黑芝麻乳", "area_id": &"area.packaged_drink", "recipe_id": &"recipe.packaged_drink.black_sesame", "stock_id": &"stock.packaged_drink.black_sesame", "base_sell_price": 9, "order_weight": 40, "can_heat": true},
	&"product.youtiao.plain": {"label": "原味油条", "area_id": &"area.youtiao", "recipe_id": &"recipe.youtiao.plain", "base_sell_price": 6, "order_weight": 100},
	&"product.youtiao.oil_cake": {"label": "油饼", "area_id": &"area.youtiao", "recipe_id": &"recipe.youtiao.oil_cake", "base_sell_price": 8, "order_weight": 70},
	&"product.youtiao.sugar_oil_cake": {"label": "糖油饼", "area_id": &"area.youtiao", "recipe_id": &"recipe.youtiao.sugar_oil_cake", "base_sell_price": 11, "order_weight": 40},
	&"product.fresh_soy_milk.yellow_bean": {"label": "黄豆豆浆", "area_id": &"area.fresh_soy_milk", "recipe_id": &"recipe.fresh_soy_milk.yellow_bean", "base_sell_price": 7, "order_weight": 100},
	&"product.fresh_soy_milk.black_bean": {"label": "黑豆豆浆", "area_id": &"area.fresh_soy_milk", "recipe_id": &"recipe.fresh_soy_milk.black_bean", "base_sell_price": 9, "order_weight": 70},
	&"product.fresh_soy_milk.red_bean": {"label": "红豆豆浆", "area_id": &"area.fresh_soy_milk", "recipe_id": &"recipe.fresh_soy_milk.red_bean", "base_sell_price": 11, "order_weight": 70},
	&"product.fresh_soy_milk.multigrain": {"label": "五谷豆浆", "area_id": &"area.fresh_soy_milk", "recipe_id": &"recipe.fresh_soy_milk.multigrain", "base_sell_price": 14, "order_weight": 40},
	&"product.steamer.mantou": {"label": "馒头", "area_id": &"area.steamer", "recipe_id": &"recipe.steamer.mantou", "base_sell_price": 6, "order_weight": 100},
	&"product.steamer.vegetable_bun": {"label": "菜包", "area_id": &"area.steamer", "recipe_id": &"recipe.steamer.vegetable_bun", "base_sell_price": 9, "order_weight": 70},
	&"product.steamer.meat_bun": {"label": "肉包", "area_id": &"area.steamer", "recipe_id": &"recipe.steamer.meat_bun", "base_sell_price": 12, "order_weight": 40},
}

const AUTOMATION_DEFINITIONS := {
	&"automation.youtiao.auto_lift": {"area_id": &"area.youtiao"},
	&"automation.youtiao.auto_load": {"area_id": &"area.youtiao"},
	&"automation.fresh_soy_milk.auto_water_start": {"area_id": &"area.fresh_soy_milk"},
	&"automation.fresh_soy_milk.auto_cup_rack": {"area_id": &"area.fresh_soy_milk"},
	&"automation.pancake.auto_sauce_brush": {"area_id": &"area.pancake"},
	&"automation.pancake.press_once": {"area_id": &"area.pancake"},
}
const RESTOCK_DEFINITIONS := {"stock_definition_is_source": true}
## Purchase channels are intentionally independent: one installation and one
## content purchase can be pending for the following business day.
const GROWTH_DEFINITIONS := {
	&"growth.tool.pancake.wide_spreader": {"label": "宽幅摊饼器", "purchase_slot": &"install", "kind": &"tool", "price": 12, "min_day": 2, "requires_area_id": &"area.pancake"},
	&"growth.add_on.pancake.red_chili": {"label": "辣椒酱", "purchase_slot": &"content", "kind": &"stock_unlock", "price": 8, "min_reputation": 10, "requires_area_id": &"area.pancake", "unlock_stock_ids": [&"stock.pancake.sauce.red_chili"]},
	&"growth.add_on.pancake.ham_sausage": {"label": "火腿肠", "purchase_slot": &"content", "kind": &"stock_unlock", "price": 12, "min_day": 4, "requires_area_id": &"area.pancake", "unlock_stock_ids": [&"stock.pancake.ham_sausage"]},
	&"growth.equipment.pancake.intermediate": {"label": "宽容火候鏊子", "purchase_slot": &"install", "kind": &"device_tier", "price": 24, "requires_area_id": &"area.pancake", "requires_mastery": {&"area.pancake": {"a_grade": 2}}, "device_id": &"device.pancake_griddle", "target_tier": 1},
	&"growth.add_on.pancake.meat_floss": {"label": "肉松", "purchase_slot": &"content", "kind": &"stock_unlock", "price": 18, "min_reputation": 45, "requires_area_id": &"area.pancake", "unlock_stock_ids": [&"stock.pancake.meat_floss"]},
	&"growth.capacity.pancake_holding_tray.two_slots": {"label": "两格成品暂存托盘", "purchase_slot": &"content", "kind": &"pancake_holding_tray", "price": 32, "min_day": 8, "requires_area_id": &"area.pancake", "requires_tutorial_area_id": &"area.youtiao"},
	&"growth.add_on.pancake.coriander": {"label": "香菜", "purchase_slot": &"content", "kind": &"stock_unlock", "price": 10, "min_day": 8, "requires_area_id": &"area.pancake", "unlock_stock_ids": [&"stock.pancake.coriander"]},
	&"growth.add_on.pancake.preserved_mustard": {"label": "榨菜", "purchase_slot": &"content", "kind": &"stock_unlock", "price": 12, "min_reputation": 100, "requires_area_id": &"area.pancake", "unlock_stock_ids": [&"stock.pancake.preserved_mustard"]},
	&"growth.add_on.pancake.pork_tenderloin": {"label": "里脊肉", "purchase_slot": &"content", "kind": &"stock_unlock", "price": 28, "min_day": 10, "requires_area_id": &"area.pancake", "unlock_stock_ids": [&"stock.pancake.pork_tenderloin"]},
	&"growth.automation.pancake.auto_sauce_brush": {"label": "自动酱刷", "purchase_slot": &"install", "kind": &"automation", "price": 36, "requires_area_id": &"area.pancake", "requires_mastery": {&"area.pancake": {"a_grade": 5}}, "automation_id": &"automation.pancake.auto_sauce_brush"},
	&"growth.equipment.pancake.advanced": {"label": "快速回温鏊子", "purchase_slot": &"install", "kind": &"device_tier", "price": 48, "requires_area_id": &"area.pancake", "requires_all_areas": true, "requires_mastery": {&"area.pancake": {"a_grade": 10}}, "device_id": &"device.pancake_griddle", "target_tier": 2},
	&"growth.automation.pancake.press_once": {"label": "单次标准摊面", "purchase_slot": &"install", "kind": &"automation", "price": 60, "requires_area_id": &"area.pancake", "requires_all_areas": true, "requires_growth_ids": [&"growth.tool.pancake.wide_spreader", &"growth.equipment.pancake.intermediate", &"growth.automation.pancake.auto_sauce_brush"], "requires_mastery": {&"area.pancake": {"a_grade": 20}}, "automation_id": &"automation.pancake.press_once"},
	&"growth.capacity.stock.intermediate": {"label": "库存容量10", "purchase_slot": &"content", "kind": &"stock_capacity", "price": 20, "min_reputation": 80, "requires_area_id": &"area.pancake", "target_capacity": 10},
	&"growth.capacity.stock.advanced": {"label": "库存容量14", "purchase_slot": &"content", "kind": &"stock_capacity", "price": 40, "min_reputation": 200, "requires_area_id": &"area.pancake", "requires_all_areas": true, "requires_growth_ids": [&"growth.capacity.stock.intermediate"], "target_capacity": 14},
	&"growth.area.packaged_drink": {"label": "成品饮品柜", "purchase_slot": &"install", "kind": &"area_unlock", "price": 30, "requires_area_id": &"area.pancake", "requires_tutorial_area_id": &"area.pancake", "requires_mastery": {&"area.pancake": {"qualified": 6}}, "area_id": &"area.packaged_drink", "device_id": &"device.packaged_drink_heater", "target_tier": 0, "unlock_recipe_ids": [&"recipe.packaged_drink.milk"], "unlock_product_ids": [&"product.packaged_drink.milk"], "unlock_stock_ids": [&"stock.packaged_drink.milk"]},
	&"growth.product.packaged_drink.soy_milk": {"label": "成品豆奶", "purchase_slot": &"content", "kind": &"recipe_unlock", "price": 12, "min_reputation": 30, "requires_area_id": &"area.packaged_drink", "unlock_recipe_ids": [&"recipe.packaged_drink.soy_milk"], "unlock_product_ids": [&"product.packaged_drink.soy_milk"], "unlock_stock_ids": [&"stock.packaged_drink.soy_milk"]},
	&"growth.equipment.packaged_drink.intermediate": {"label": "双位快速饮品加热器", "purchase_slot": &"install", "kind": &"device_tier", "price": 24, "requires_area_id": &"area.packaged_drink", "requires_mastery": {&"area.packaged_drink": {"correct_temperature": 6}}, "device_id": &"device.packaged_drink_heater", "target_tier": 1},
	&"growth.product.packaged_drink.walnut": {"label": "核桃乳", "purchase_slot": &"content", "kind": &"recipe_unlock", "price": 18, "min_day": 11, "requires_area_id": &"area.packaged_drink", "unlock_recipe_ids": [&"recipe.packaged_drink.walnut"], "unlock_product_ids": [&"product.packaged_drink.walnut"], "unlock_stock_ids": [&"stock.packaged_drink.walnut"]},
	&"growth.product.packaged_drink.black_sesame": {"label": "黑芝麻乳", "purchase_slot": &"content", "kind": &"recipe_unlock", "price": 24, "min_reputation": 160, "requires_area_id": &"area.packaged_drink", "unlock_recipe_ids": [&"recipe.packaged_drink.black_sesame"], "unlock_product_ids": [&"product.packaged_drink.black_sesame"], "unlock_stock_ids": [&"stock.packaged_drink.black_sesame"]},
	&"growth.equipment.packaged_drink.advanced": {"label": "四位恒温饮品加热器", "purchase_slot": &"install", "kind": &"device_tier", "price": 48, "requires_area_id": &"area.packaged_drink", "requires_all_areas": true, "requires_mastery": {&"area.packaged_drink": {"correct_streak_best": 8}}, "device_id": &"device.packaged_drink_heater", "target_tier": 2},
	&"growth.area.youtiao": {"label": "油条炸锅", "purchase_slot": &"install", "kind": &"area_unlock", "price": 60, "min_reputation": 60, "requires_area_id": &"area.packaged_drink", "requires_tutorial_area_id": &"area.packaged_drink", "area_id": &"area.youtiao", "device_id": &"device.youtiao_fryer", "target_tier": 0, "unlock_recipe_ids": [&"recipe.youtiao.plain"], "unlock_product_ids": [&"product.youtiao.plain"], "unlock_stock_ids": [&"stock.youtiao.plain_dough"]},
	&"growth.assist.youtiao.temperature_indicator": {"label": "油温区间提示", "purchase_slot": &"install", "kind": &"assist", "price": 16, "min_reputation": 70, "requires_area_id": &"area.youtiao", "assist_id": &"assist.youtiao.temperature_indicator"},
	&"growth.recipe.youtiao.oil_cake": {"label": "油饼", "purchase_slot": &"content", "kind": &"recipe_unlock", "price": 18, "min_day": 7, "requires_area_id": &"area.youtiao", "unlock_recipe_ids": [&"recipe.youtiao.oil_cake"], "unlock_product_ids": [&"product.youtiao.oil_cake"], "unlock_stock_ids": [&"stock.youtiao.oil_cake_dough"]},
	&"growth.equipment.youtiao.intermediate": {"label": "快速油条炸锅", "purchase_slot": &"install", "kind": &"device_tier", "price": 42, "requires_area_id": &"area.youtiao", "requires_mastery": {&"area.youtiao": {"qualified": 6}}, "device_id": &"device.youtiao_fryer", "target_tier": 1},
	&"growth.recipe.youtiao.sugar_oil_cake": {"label": "糖油饼", "purchase_slot": &"content", "kind": &"recipe_unlock", "price": 24, "min_reputation": 140, "requires_area_id": &"area.youtiao", "unlock_recipe_ids": [&"recipe.youtiao.sugar_oil_cake"], "unlock_product_ids": [&"product.youtiao.sugar_oil_cake"], "unlock_stock_ids": [&"stock.youtiao.sugar_oil_cake_dough"]},
	&"growth.automation.youtiao.auto_lift": {"label": "熟成自动升篮", "purchase_slot": &"install", "kind": &"automation", "price": 54, "requires_area_id": &"area.youtiao", "requires_all_areas": true, "requires_mastery": {&"area.youtiao": {"a_grade": 5}}, "automation_id": &"automation.youtiao.auto_lift"},
	&"growth.equipment.youtiao.advanced": {"label": "四份油条炸锅", "purchase_slot": &"install", "kind": &"device_tier", "price": 72, "requires_area_id": &"area.youtiao", "requires_all_areas": true, "requires_mastery": {&"area.youtiao": {"a_grade": 8}}, "device_id": &"device.youtiao_fryer", "target_tier": 2},
	&"growth.automation.youtiao.auto_load": {"label": "已确认批次自动装载", "purchase_slot": &"install", "kind": &"automation", "price": 66, "requires_area_id": &"area.youtiao", "requires_all_areas": true, "requires_growth_ids": [&"growth.automation.youtiao.auto_lift"], "requires_mastery": {&"area.youtiao": {"a_grade": 10}}, "automation_id": &"automation.youtiao.auto_load"},
	&"growth.area.fresh_soy_milk": {"label": "现磨豆浆机", "purchase_slot": &"install", "kind": &"area_unlock", "price": 90, "min_day": 10, "requires_area_id": &"area.youtiao", "requires_tutorial_area_id": &"area.youtiao", "area_id": &"area.fresh_soy_milk", "device_id": &"device.fresh_soy_milk_machine", "target_tier": 0, "unlock_recipe_ids": [&"recipe.fresh_soy_milk.yellow_bean"], "unlock_product_ids": [&"product.fresh_soy_milk.yellow_bean"], "unlock_stock_ids": [&"stock.fresh_soy_milk.yellow_bean"]},
	&"growth.recipe.fresh_soy_milk.black_bean": {"label": "黑豆豆浆", "purchase_slot": &"content", "kind": &"recipe_unlock", "price": 18, "min_day": 10, "requires_area_id": &"area.fresh_soy_milk", "unlock_recipe_ids": [&"recipe.fresh_soy_milk.black_bean"], "unlock_product_ids": [&"product.fresh_soy_milk.black_bean"], "unlock_stock_ids": [&"stock.fresh_soy_milk.black_bean"]},
	&"growth.equipment.fresh_soy_milk.intermediate": {"label": "快速豆浆机", "purchase_slot": &"install", "kind": &"device_tier", "price": 54, "requires_area_id": &"area.fresh_soy_milk", "requires_mastery": {&"area.fresh_soy_milk": {"qualified": 6}}, "device_id": &"device.fresh_soy_milk_machine", "target_tier": 1},
	&"growth.recipe.fresh_soy_milk.red_bean": {"label": "红豆豆浆", "purchase_slot": &"content", "kind": &"recipe_unlock", "price": 24, "min_reputation": 150, "requires_area_id": &"area.fresh_soy_milk", "unlock_recipe_ids": [&"recipe.fresh_soy_milk.red_bean"], "unlock_product_ids": [&"product.fresh_soy_milk.red_bean"], "unlock_stock_ids": [&"stock.fresh_soy_milk.red_bean"]},
	&"growth.recipe.fresh_soy_milk.multigrain": {"label": "五谷豆浆", "purchase_slot": &"content", "kind": &"recipe_unlock", "price": 30, "min_day": 16, "requires_area_id": &"area.fresh_soy_milk", "unlock_recipe_ids": [&"recipe.fresh_soy_milk.multigrain"], "unlock_product_ids": [&"product.fresh_soy_milk.multigrain"], "unlock_stock_ids": [&"stock.fresh_soy_milk.multigrain"]},
	&"growth.automation.fresh_soy_milk.auto_water_start": {"label": "自动加水启动", "purchase_slot": &"install", "kind": &"automation", "price": 60, "requires_area_id": &"area.fresh_soy_milk", "requires_all_areas": true, "requires_mastery": {&"area.fresh_soy_milk": {"a_grade": 5}}, "automation_id": &"automation.fresh_soy_milk.auto_water_start"},
	&"growth.equipment.fresh_soy_milk.advanced": {"label": "四杯保温豆浆机", "purchase_slot": &"install", "kind": &"device_tier", "price": 84, "requires_area_id": &"area.fresh_soy_milk", "requires_all_areas": true, "requires_mastery": {&"area.fresh_soy_milk": {"a_grade": 8}}, "device_id": &"device.fresh_soy_milk_machine", "target_tier": 2},
	&"growth.automation.fresh_soy_milk.auto_cup_rack": {"label": "自动接杯架", "purchase_slot": &"install", "kind": &"automation", "price": 72, "requires_area_id": &"area.fresh_soy_milk", "requires_all_areas": true, "requires_growth_ids": [&"growth.automation.fresh_soy_milk.auto_water_start"], "requires_mastery": {&"area.fresh_soy_milk": {"a_grade": 10}}, "automation_id": &"automation.fresh_soy_milk.auto_cup_rack"},
	&"growth.area.steamer": {"label": "多层蒸笼", "purchase_slot": &"install", "kind": &"area_unlock", "price": 120, "requires_area_id": &"area.fresh_soy_milk", "requires_tutorial_area_id": &"area.fresh_soy_milk", "requires_mastery": {&"area.fresh_soy_milk": {"qualified": 4}}, "area_id": &"area.steamer", "device_id": &"device.steamer", "target_tier": 0, "unlock_recipe_ids": [&"recipe.steamer.mantou"], "unlock_product_ids": [&"product.steamer.mantou"], "unlock_stock_ids": [&"stock.steamer.mantou"]},
	&"growth.recipe.steamer.vegetable_bun": {"label": "菜包", "purchase_slot": &"content", "kind": &"recipe_unlock", "price": 24, "min_day": 15, "requires_area_id": &"area.steamer", "unlock_recipe_ids": [&"recipe.steamer.vegetable_bun"], "unlock_product_ids": [&"product.steamer.vegetable_bun"], "unlock_stock_ids": [&"stock.steamer.vegetable_bun"]},
	&"growth.equipment.steamer.intermediate": {"label": "快速双层蒸笼", "purchase_slot": &"install", "kind": &"device_tier", "price": 66, "requires_area_id": &"area.steamer", "requires_mastery": {&"area.steamer": {"qualified": 9}}, "device_id": &"device.steamer", "target_tier": 1},
	&"growth.recipe.steamer.meat_bun": {"label": "肉包", "purchase_slot": &"content", "kind": &"recipe_unlock", "price": 36, "min_reputation": 200, "requires_area_id": &"area.steamer", "unlock_recipe_ids": [&"recipe.steamer.meat_bun"], "unlock_product_ids": [&"product.steamer.meat_bun"], "unlock_stock_ids": [&"stock.steamer.meat_bun"]},
	&"growth.equipment.steamer.advanced": {"label": "独立停汽四层蒸笼", "purchase_slot": &"install", "kind": &"device_tier", "price": 108, "requires_area_id": &"area.steamer", "requires_mastery": {&"area.steamer": {"a_grade": 8}}, "device_id": &"device.steamer", "target_tier": 2},
}
## Day-end growth follows this authored route exactly.  Purchase eligibility
## changes the card state, never its position in the queue.
const FIXED_GROWTH_ROUTE: Array[StringName] = [
	&"growth.tool.pancake.wide_spreader",
	&"growth.add_on.pancake.red_chili",
	&"growth.area.packaged_drink",
	&"growth.equipment.pancake.intermediate",
	&"growth.add_on.pancake.ham_sausage",
	&"growth.product.packaged_drink.soy_milk",
	&"growth.equipment.packaged_drink.intermediate",
	&"growth.add_on.pancake.meat_floss",
	&"growth.area.youtiao",
	&"growth.assist.youtiao.temperature_indicator",
	&"growth.recipe.youtiao.oil_cake",
	&"growth.capacity.stock.intermediate",
	&"growth.equipment.youtiao.intermediate",
	&"growth.add_on.pancake.coriander",
	&"growth.area.fresh_soy_milk",
	&"growth.recipe.fresh_soy_milk.black_bean",
	&"growth.equipment.fresh_soy_milk.intermediate",
	&"growth.capacity.pancake_holding_tray.two_slots",
	&"growth.add_on.pancake.preserved_mustard",
	&"growth.product.packaged_drink.walnut",
	&"growth.area.steamer",
	&"growth.recipe.steamer.vegetable_bun",
	&"growth.equipment.steamer.intermediate",
	&"growth.add_on.pancake.pork_tenderloin",
	&"growth.recipe.youtiao.sugar_oil_cake",
	&"growth.recipe.fresh_soy_milk.red_bean",
	&"growth.product.packaged_drink.black_sesame",
	&"growth.recipe.steamer.meat_bun",
	&"growth.recipe.fresh_soy_milk.multigrain",
	&"growth.automation.pancake.auto_sauce_brush",
	&"growth.equipment.pancake.advanced",
	&"growth.automation.pancake.press_once",
	&"growth.capacity.stock.advanced",
	&"growth.equipment.packaged_drink.advanced",
	&"growth.automation.youtiao.auto_lift",
	&"growth.equipment.youtiao.advanced",
	&"growth.automation.youtiao.auto_load",
	&"growth.automation.fresh_soy_milk.auto_water_start",
	&"growth.equipment.fresh_soy_milk.advanced",
	&"growth.automation.fresh_soy_milk.auto_cup_rack",
	&"growth.equipment.steamer.advanced",
]
const MASTERY_DEFINITIONS := {
	&"area.pancake": {"qualified_key": &"qualified", "a_grade_key": &"a_grade", "bronze": {"qualified": 8, "a_grade": 2}, "silver": {"qualified": 20, "a_grade": 8}, "gold": {"qualified": 50, "a_grade": 25}},
	&"area.packaged_drink": {"qualified_key": &"correct_temperature", "a_grade_key": &"correct_streak_best", "bronze": {"qualified": 6, "a_grade": 2}, "silver": {"qualified": 20, "a_grade": 8}, "gold": {"qualified": 50, "a_grade": 25}},
	&"area.youtiao": {"qualified_key": &"qualified", "a_grade_key": &"a_grade", "bronze": {"qualified": 4, "a_grade": 1}, "silver": {"qualified": 20, "a_grade": 8}, "gold": {"qualified": 50, "a_grade": 25}},
	&"area.fresh_soy_milk": {"qualified_key": &"qualified", "a_grade_key": &"a_grade", "bronze": {"qualified": 4, "a_grade": 1}, "silver": {"qualified": 20, "a_grade": 8}, "gold": {"qualified": 50, "a_grade": 25}},
	&"area.steamer": {"qualified_key": &"qualified", "a_grade_key": &"a_grade", "bronze": {"qualified": 6, "a_grade": 2}, "silver": {"qualified": 20, "a_grade": 8}, "gold": {"qualified": 50, "a_grade": 25}},
}
const ORDER_BALANCE := {"complexity_percent": {&"single": 72, &"double": 20, &"triple": 8}, "temperature_heated_percent": 35, "queue_size": 4}
const REPUTATION_BALANCE := {&"all_a": 4, &"all_ab": 3, &"has_c": 1, &"failure": -2, &"unstarted_refusal": -1}
const DAILY_GOAL_DEFINITIONS := {
	&"goal.signature.pancake_three_a": {"area_id": &"area.pancake", "target": 3, "event_kind": &"sale", "requires_grade": &"A", "reward_coins": 18, "reward_reputation": 2},
	&"goal.signature.packaged_drink_four_correct": {"area_id": &"area.packaged_drink", "target": 4, "event_kind": &"sale", "requires_correct_temperature": true, "reward_coins": 16, "reward_reputation": 2},
	&"goal.signature.youtiao_four_no_burn": {"area_id": &"area.youtiao", "target": 4, "event_kind": &"sale", "requires_min_grade": &"B", "fails_on": &"waste", "reward_coins": 22, "reward_reputation": 2},
	&"goal.signature.fresh_soy_milk_four_no_spoil": {"area_id": &"area.fresh_soy_milk", "target": 4, "event_kind": &"sale", "requires_min_grade": &"B", "fails_on": &"waste", "reward_coins": 24, "reward_reputation": 2},
	&"goal.signature.steamer_four_no_spoil": {"area_id": &"area.steamer", "target": 4, "event_kind": &"sale", "requires_min_grade": &"B", "fails_on": &"waste", "reward_coins": 28, "reward_reputation": 3},
	&"goal.signature.combo_two_no_failure": {"area_id": &"", "target": 2, "event_kind": &"sale", "requires_complexity": &"double", "fails_on": &"order_failure", "reward_coins": 20, "reward_reputation": 2},
}
## Orders are authored with stable inventory IDs.  UI adapters may translate
## them to the legacy pancake simulation IDs, but eligibility never comes from
## visible material slots or widget state.
const PANCAKE_ORDER_TEMPLATES := {
	&"order.pancake.classic": {"title": "经典杂粮煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.scallion"], "sauce_stock_ids": [&"stock.pancake.sauce.sweet_flour"], "heat_preference": &"golden", "time_limit": 72.0, "payment_coins": 3, "customer_line": "来一份经典的，薄脆和葱花都要。"},
	&"order.pancake.chili_ham": {"title": "香辣火腿煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.ham_sausage"], "sauce_stock_ids": [&"stock.pancake.sauce.red_chili"], "heat_preference": &"well_done", "time_limit": 76.0, "payment_coins": 12, "customer_line": "火腿加辣酱，边缘煎香一点。"},
	&"order.pancake.double_sauce": {"title": "双酱全料煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.ham_sausage", &"stock.pancake.scallion"], "sauce_stock_ids": [&"stock.pancake.sauce.sweet_flour", &"stock.pancake.sauce.red_chili"], "heat_preference": &"golden", "time_limit": 82.0, "payment_coins": 22, "customer_line": "两种酱都刷，配料给我放匀。"},
	&"order.pancake.scallion_light": {"title": "葱香少料煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.scallion"], "sauce_stock_ids": [&"stock.pancake.sauce.sweet_flour"], "heat_preference": &"light", "time_limit": 68.0, "payment_coins": 5, "customer_line": "这份不加薄脆，饼皮嫩一点就好。"},
	&"order.pancake.meat_floss_sweet": {"title": "甜酱肉松煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.meat_floss", &"stock.pancake.scallion"], "sauce_stock_ids": [&"stock.pancake.sauce.sweet_flour"], "heat_preference": &"golden", "time_limit": 84.0, "payment_coins": 28, "customer_line": "肉松铺匀些，甜酱和葱花都要。"},
	&"order.pancake.tenderloin_double_sauce": {"title": "双酱里脊煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.pork_tenderloin", &"stock.pancake.scallion"], "sauce_stock_ids": [&"stock.pancake.sauce.sweet_flour", &"stock.pancake.sauce.red_chili"], "heat_preference": &"well_done", "time_limit": 88.0, "payment_coins": 36, "customer_line": "里脊配双酱，饼皮要结实一点。"},
	&"order.pancake.coriander": {"title": "香菜薄脆煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.coriander"], "sauce_stock_ids": [&"stock.pancake.sauce.sweet_flour"], "heat_preference": &"golden", "time_limit": 78.0, "payment_coins": 10, "customer_line": "薄脆和香菜都要，刷甜面酱。"},
	&"order.pancake.preserved_mustard": {"title": "榨菜辣酱煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.preserved_mustard"], "sauce_stock_ids": [&"stock.pancake.sauce.red_chili"], "heat_preference": &"golden", "time_limit": 78.0, "payment_coins": 11, "customer_line": "加榨菜，刷辣酱。"},
}

static func area_definition(area_id: StringName) -> Dictionary:
	return _copy_definition(AREA_DEFINITIONS, area_id)

static func device_definition(device_id: StringName) -> Dictionary:
	return _copy_definition(DEVICE_DEFINITIONS, device_id)

static func device_tier(device_id: StringName, tier: int) -> Dictionary:
	var definition := device_definition(device_id)
	for candidate in definition.get("tiers", []):
		if int(candidate.get("tier", 0)) == tier:
			return candidate.duplicate(true)
	return {}

static func stock_definition(stock_id: StringName) -> Dictionary:
	return _copy_definition(STOCK_DEFINITIONS, stock_id)

static func material_slot_definition(slot_id: StringName) -> Dictionary:
	return _copy_definition(MATERIAL_SLOT_DEFINITIONS, slot_id)

static func recipe_definition(recipe_id: StringName) -> Dictionary:
	return _copy_definition(RECIPE_DEFINITIONS, recipe_id)

static func product_definition(product_id: StringName) -> Dictionary:
	return _copy_definition(PRODUCT_DEFINITIONS, product_id)

static func growth_definition(growth_id: StringName) -> Dictionary:
	return _copy_definition(GROWTH_DEFINITIONS, growth_id)

static func pancake_order_template(template_id: StringName) -> Dictionary:
	return _copy_definition(PANCAKE_ORDER_TEMPLATES, template_id)

static func daily_goal_definition(goal_id: StringName) -> Dictionary:
	return _copy_definition(DAILY_GOAL_DEFINITIONS, goal_id)


static func mastery_definition(area_id: StringName) -> Dictionary:
	return _copy_definition(MASTERY_DEFINITIONS, area_id)

static func area_ids() -> Array[StringName]:
	return AREA_IDS.duplicate()

static func stock_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for stock_id in STOCK_DEFINITIONS.keys():
		ids.append(stock_id)
	return ids

static func growth_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for growth_id in GROWTH_DEFINITIONS.keys():
		ids.append(growth_id)
	return ids

static func validate_catalog() -> PackedStringArray:
	var errors := PackedStringArray()
	if AREA_IDS.size() != 5 or PHYSICAL_AREA_IDS.size() != 5 or UNLOCK_AREA_IDS.size() != 5:
		errors.append("Five area orders must each contain exactly five areas.")
	for area_id in AREA_IDS:
		if not AREA_DEFINITIONS.has(area_id):
			errors.append("Missing area definition: %s" % area_id)
		elif not DEVICE_DEFINITIONS.has(AREA_DEFINITIONS[area_id].get("device_id", &"")):
			errors.append("Missing device for area: %s" % area_id)
		if not MASTERY_DEFINITIONS.has(area_id):
			errors.append("Missing mastery definition: %s" % area_id)
	for slot_index in range(1, 19):
		var slot_id := StringName("slot.%02d" % slot_index)
		if not MATERIAL_SLOT_DEFINITIONS.has(slot_id):
			errors.append("Missing material slot: %s" % slot_id)
			continue
		var slot: Dictionary = MATERIAL_SLOT_DEFINITIONS[slot_id]
		if int(slot.get("index", 0)) != slot_index:
			errors.append("Incorrect slot index: %s" % slot_id)
		if slot.get("kind", &"") == &"stock":
			var stock_id: StringName = slot.get("stock_id", &"")
			if not STOCK_DEFINITIONS.has(stock_id):
				errors.append("Unknown stock in material slot: %s" % slot_id)
			elif STOCK_DEFINITIONS[stock_id].get("material_slot_id", &"") != slot_id:
				errors.append("Stock to slot mismatch: %s" % stock_id)
		elif slot.get("kind", &"") == &"dynamic_add_on":
			if not PANCAKE_ADD_ON_SLOT_PRIORITY.has(slot_id):
				errors.append("Unexpected dynamic pancake add-on slot: %s" % slot_id)
		elif slot.get("kind", &"") != &"reserved":
			errors.append("Unknown material slot kind: %s" % slot_id)
	for stock_id in PANCAKE_ADD_ON_DISPLAY_ORDER:
		if not STOCK_DEFINITIONS.has(stock_id) or STOCK_DEFINITIONS[stock_id].get("material_slot_id", &"") != &"":
			errors.append("Pancake add-on must use dynamic slot priority: %s" % stock_id)
	for stock_id in SAUCE_DEFINITIONS.keys():
		if not STOCK_DEFINITIONS.has(stock_id) or STOCK_DEFINITIONS[stock_id].get("material_slot_id", &"") != &"":
			errors.append("Sauce must not occupy a material slot: %s" % stock_id)
	for recipe_id in RECIPE_DEFINITIONS:
		var recipe: Dictionary = RECIPE_DEFINITIONS[recipe_id]
		if not AREA_DEFINITIONS.has(recipe.get("area_id", &"")):
			errors.append("Recipe has unknown area: %s" % recipe_id)
		if not PRODUCT_DEFINITIONS.has(recipe.get("product_id", &"")):
			errors.append("Recipe has unknown product: %s" % recipe_id)
		for stock_id in recipe.get("stock_ids", []):
			if not STOCK_DEFINITIONS.has(stock_id):
				errors.append("Recipe has unknown stock: %s" % recipe_id)
	for product_id in PRODUCT_DEFINITIONS:
		var product: Dictionary = PRODUCT_DEFINITIONS[product_id]
		if not AREA_DEFINITIONS.has(product.get("area_id", &"")):
			errors.append("Product has unknown area: %s" % product_id)
		if not RECIPE_DEFINITIONS.has(product.get("recipe_id", &"")):
			errors.append("Product has unknown recipe: %s" % product_id)
		if product.get("area_id", &"") == &"area.packaged_drink" and not STOCK_DEFINITIONS.has(product.get("stock_id", &"")):
			errors.append("Packaged drink has unknown stock: %s" % product_id)
	for device_id in DEVICE_DEFINITIONS:
		var seen_tiers := PackedInt32Array()
		for tier_definition in Array(DEVICE_DEFINITIONS[device_id].get("tiers", [])):
			var tier := int(Dictionary(tier_definition).get("tier", -1))
			if seen_tiers.has(tier):
				errors.append("Device has duplicate tier: %s/%d" % [device_id, tier])
			seen_tiers.append(tier)
		for required_tier in [0, 1, 2]:
			if not seen_tiers.has(required_tier):
				errors.append("Device is missing tier: %s/%d" % [device_id, required_tier])
	if GROWTH_DEFINITIONS.size() != 41:
		errors.append("Five-area growth catalog must contain exactly 41 definitions.")
	if FIXED_GROWTH_ROUTE.size() != GROWTH_DEFINITIONS.size():
		errors.append("Fixed growth route must cover every growth definition exactly once.")
	var routed_growth_ids: Dictionary = {}
	for route_index in FIXED_GROWTH_ROUTE.size():
		var routed_growth_id := FIXED_GROWTH_ROUTE[route_index]
		if not GROWTH_DEFINITIONS.has(routed_growth_id):
			errors.append("Fixed growth route contains unknown item: %s" % routed_growth_id)
		if routed_growth_ids.has(routed_growth_id):
			errors.append("Fixed growth route contains duplicate item: %s" % routed_growth_id)
		routed_growth_ids[routed_growth_id] = route_index
	for growth_id in GROWTH_DEFINITIONS:
		var growth: Dictionary = GROWTH_DEFINITIONS[growth_id]
		if not routed_growth_ids.has(growth_id):
			errors.append("Growth is missing from fixed route: %s" % growth_id)
		if growth.get("purchase_slot", &"") != &"install" and growth.get("purchase_slot", &"") != &"content":
			errors.append("Growth has invalid purchase slot: %s" % growth_id)
		if not AREA_DEFINITIONS.has(growth.get("requires_area_id", &"")):
			errors.append("Growth has unknown required area: %s" % growth_id)
		if int(growth.get("price", -1)) < 0 or str(growth.get("kind", "")).is_empty():
			errors.append("Growth is missing price or kind: %s" % growth_id)
		for required_growth_id in growth.get("requires_growth_ids", []):
			if not GROWTH_DEFINITIONS.has(required_growth_id):
				errors.append("Growth has unknown prerequisite: %s" % growth_id)
			elif routed_growth_ids.has(growth_id) and routed_growth_ids.has(required_growth_id) and int(routed_growth_ids[required_growth_id]) >= int(routed_growth_ids[growth_id]):
				errors.append("Growth prerequisite appears too late in fixed route: %s requires %s" % [growth_id, required_growth_id])
		for product_id in growth.get("unlock_product_ids", []):
			if not PRODUCT_DEFINITIONS.has(product_id):
				errors.append("Growth unlocks unknown product: %s" % growth_id)
		for recipe_id in growth.get("unlock_recipe_ids", []):
			if not RECIPE_DEFINITIONS.has(recipe_id):
				errors.append("Growth unlocks unknown recipe: %s" % growth_id)
		for stock_id in growth.get("unlock_stock_ids", []):
			if not STOCK_DEFINITIONS.has(stock_id):
				errors.append("Growth unlocks unknown stock: %s" % growth_id)
		var automation_id: StringName = growth.get("automation_id", &"")
		if not automation_id.is_empty() and not AUTOMATION_DEFINITIONS.has(automation_id):
			errors.append("Growth unlocks unknown automation: %s" % growth_id)
		var target_device_id: StringName = growth.get("device_id", &"")
		if not target_device_id.is_empty() and growth.has("target_tier") and device_tier(target_device_id, int(growth.get("target_tier", 0))).is_empty():
			errors.append("Growth targets unknown device tier: %s" % growth_id)
	if PRODUCT_DEFINITIONS[&"product.packaged_drink.soy_milk"].get("area_id", &"") == PRODUCT_DEFINITIONS[&"product.fresh_soy_milk.yellow_bean"].get("area_id", &""):
		errors.append("Packaged soy milk and fresh soy milk must remain separate products.")
	if DAILY_GOAL_DEFINITIONS.is_empty() or ORDER_BALANCE.is_empty() or REPUTATION_BALANCE.is_empty():
		errors.append("Five-area balance and daily goal definitions must not be empty.")
	for template_id in PANCAKE_ORDER_TEMPLATES:
		var template: Dictionary = PANCAKE_ORDER_TEMPLATES[template_id]
		var sauce_ids: Array = Array(template.get("sauce_stock_ids", []))
		if sauce_ids.size() > 2:
			errors.append("Pancake order exceeds two-sauce maximum: %s" % template_id)
		for stock_id in Array(template.get("ingredient_stock_ids", [])) + sauce_ids:
			if not STOCK_DEFINITIONS.has(stock_id):
				errors.append("Pancake order has unknown stock: %s" % template_id)
	return errors

static func _copy_definition(source: Dictionary, definition_id: StringName) -> Dictionary:
	if not source.has(definition_id):
		return {}
	return source[definition_id].duplicate(true)
