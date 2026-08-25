class_name FiveAreaCatalog
extends RefCounted

## Static three-area source of truth. Runtime services own availability, stock
## counts and pending purchases; this catalog intentionally contains no save/UI
## state.

const BALANCE_VERSION := 9
const PANCAKE_WIDE_SPREADER_WIDTH_MULTIPLIER := 1.65

const AREA_IDS: Array[StringName] = [
	&"area.pancake",
	&"area.youtiao",
	&"area.fresh_soy_milk",
]

## Physical counter order is deliberately different from the progression order.
const PHYSICAL_AREA_IDS: Array[StringName] = [
	&"area.fresh_soy_milk",
	&"area.pancake",
	&"area.youtiao",
]
const UNLOCK_AREA_IDS: Array[StringName] = [
	&"area.pancake",
	&"area.youtiao",
	&"area.fresh_soy_milk",
]

const AREA_DEFINITIONS := {
	&"area.pancake": {"label": "煎饼", "physical_index": 1, "unlock_index": 0, "device_id": &"device.pancake_griddle"},
	&"area.youtiao": {"label": "油条", "physical_index": 2, "unlock_index": 1, "device_id": &"device.youtiao_fryer"},
	&"area.fresh_soy_milk": {"label": "现磨豆浆", "physical_index": 0, "unlock_index": 2, "device_id": &"device.fresh_soy_milk_machine"},
}

const DEVICE_DEFINITIONS := {
	&"device.pancake_griddle": {
		"area_id": &"area.pancake",
		"tiers": [
			{"tier": 0, "label": "单张煎饼鏊子", "griddle_count": 1, "heat_window_bonus": 0.0, "reheat_seconds": 0.0},
		],
	},
	&"device.youtiao_fryer": {
		"area_id": &"area.youtiao",
		"tiers": [
			{"tier": 0, "label": "四格油条炸锅", "capacity": 4, "duration_seconds": 10.0, "safe_seconds": 5.0, "decay_seconds": 10.0, "drain_seconds": 2.0},
			{"tier": 1, "label": "高级油条机", "capacity": 4, "duration_seconds": 10.0, "safe_seconds": 5.0, "decay_seconds": 10.0, "drain_seconds": 2.0},
		],
	},
	&"device.fresh_soy_milk_machine": {
		"area_id": &"area.fresh_soy_milk",
		"tiers": [
			{"tier": 0, "label": "初级豆浆机", "soy_reservoir_capacity": 2, "full_cup_seconds": 0.8},
		],
	},
}

## The three opening-day ingredients keep their authored Slot07-Slot09 wells.
## Later unlocked add-ons are compacted into these wells in priority order.
## Sauce inventory is a countertop input and must never be assigned a material slot.
const PANCAKE_ADD_ON_SLOT_PRIORITY: Array[StringName] = [
	&"slot.10", &"slot.11", &"slot.12", &"slot.13", &"slot.14",
]
const PANCAKE_ADD_ON_DISPLAY_ORDER: Array[StringName] = [
	&"stock.pancake.ham_sausage",
	&"stock.pancake.meat_floss",
	&"stock.pancake.coriander",
]
const MATERIAL_SLOT_DEFINITIONS := {
	# Bean stock wells were retired with the serving-only soy workflow.  Keep
	# their physical positions explicitly reserved for future station artwork.
	&"slot.01": {"index": 1, "area_id": &"area.fresh_soy_milk", "kind": &"reserved", "reservation_id": &"reservation.fresh_soy_milk.future_01"},
	&"slot.02": {"index": 2, "area_id": &"area.fresh_soy_milk", "kind": &"reserved", "reservation_id": &"reservation.fresh_soy_milk.future_02"},
	&"slot.03": {"index": 3, "area_id": &"area.fresh_soy_milk", "kind": &"reserved", "reservation_id": &"reservation.fresh_soy_milk.future_03"},
	&"slot.04": {"index": 4, "area_id": &"area.youtiao", "kind": &"stock", "stock_id": &"stock.youtiao.plain_dough"},
	&"slot.07": {"index": 7, "area_id": &"area.pancake", "kind": &"stock", "stock_id": &"stock.pancake.egg"},
	&"slot.08": {"index": 8, "area_id": &"area.pancake", "kind": &"stock", "stock_id": &"stock.pancake.baocui"},
	&"slot.09": {"index": 9, "area_id": &"area.pancake", "kind": &"stock", "stock_id": &"stock.pancake.scallion"},
	&"slot.10": {"index": 10, "area_id": &"area.pancake", "kind": &"dynamic_add_on"},
	&"slot.11": {"index": 11, "area_id": &"area.pancake", "kind": &"dynamic_add_on"},
	&"slot.12": {"index": 12, "area_id": &"area.pancake", "kind": &"dynamic_add_on"},
	&"slot.13": {"index": 13, "area_id": &"area.pancake", "kind": &"dynamic_add_on"},
	&"slot.14": {"index": 14, "area_id": &"area.pancake", "kind": &"dynamic_add_on"},
	&"slot.15": {"index": 15, "area_id": &"area.pancake", "kind": &"reserved", "reservation_id": &"reservation.pancake.future_05"},
}

const STOCK_DEFINITIONS := {
	# Batter is always available at the pancake station. Keep its stable ID and
	# unit cost for recipes/accounting, but never expose it as managed inventory.
	&"stock.pancake.batter": {"label": "面糊", "area_id": &"area.pancake", "category": &"base", "unlimited": true, "restock_unit_cost": 1, "restock_capacity": 0, "material_slot_id": &""},
	&"stock.pancake.egg": {"area_id": &"area.pancake", "category": &"add_on", "refill_seconds": 0.20, "restock_unit_cost": 1, "restock_capacity": 6, "material_slot_id": &"slot.07"},
	&"stock.pancake.baocui": {"area_id": &"area.pancake", "category": &"add_on", "refill_seconds": 0.225, "restock_unit_cost": 1, "restock_capacity": 6, "material_slot_id": &"slot.08"},
	&"stock.pancake.scallion": {"area_id": &"area.pancake", "category": &"add_on", "refill_seconds": 0.1666667, "restock_unit_cost": 1, "restock_capacity": 6, "material_slot_id": &"slot.09"},
	&"stock.pancake.sauce.sweet_flour": {"label": "甜面酱", "area_id": &"area.pancake", "category": &"sauce", "refill_seconds": 0.25, "restock_unit_cost": 1, "restock_capacity": 6, "material_slot_id": &"", "surface_input_id": &"ui.pancake.sweet_flour_sauce_brush"},
	&"stock.pancake.sauce.red_chili": {"label": "辣酱", "area_id": &"area.pancake", "category": &"sauce", "refill_seconds": 0.25, "restock_unit_cost": 1, "restock_capacity": 6, "material_slot_id": &"", "surface_input_id": &"ui.pancake.red_chili_sauce_brush"},
	&"stock.pancake.sauce.tomato": {"label": "番茄酱", "area_id": &"area.pancake", "category": &"sauce", "refill_seconds": 0.25, "restock_unit_cost": 1, "restock_capacity": 6, "material_slot_id": &"", "surface_input_id": &"ui.pancake.tomato_sauce_brush"},
	&"stock.pancake.ham_sausage": {"area_id": &"area.pancake", "category": &"add_on", "refill_seconds": 0.25, "restock_unit_cost": 2, "restock_capacity": 6, "material_slot_id": &""},
	&"stock.pancake.meat_floss": {"area_id": &"area.pancake", "category": &"add_on", "refill_seconds": 0.25, "restock_unit_cost": 2, "restock_capacity": 6, "material_slot_id": &""},
	&"stock.pancake.coriander": {"area_id": &"area.pancake", "category": &"add_on", "refill_seconds": 0.25, "restock_unit_cost": 1, "restock_capacity": 6, "material_slot_id": &""},
	# A stable order/simulation identifier for the processed plain youtiao.
	# Capacity stays zero so it can never enter the paid ordinary-restock path.
	&"stock.pancake.youtiao": {"label": "油条", "area_id": &"area.pancake", "category": &"prepared_add_on", "restock_unit_cost": 2, "restock_capacity": 0, "material_slot_id": &""},
	# The physical board has four authored dough positions. Keep its stock cap
	# fixed at four even after the shared pantry-capacity growth upgrades.
	&"stock.youtiao.plain_dough": {"label": "油条面胚", "area_id": &"area.youtiao", "category": &"dough", "refill_seconds": 0.25, "restock_unit_cost": 2, "restock_capacity": 4, "fixed_restock_capacity": true, "material_slot_id": &"slot.04"},
}

const ADD_ON_DEFINITIONS := {
	&"stock.pancake.egg": {}, &"stock.pancake.baocui": {}, &"stock.pancake.scallion": {},
	&"stock.pancake.ham_sausage": {}, &"stock.pancake.meat_floss": {}, &"stock.pancake.coriander": {}, &"stock.pancake.youtiao": {},
}
const SAUCE_DEFINITIONS := {
	&"stock.pancake.sauce.sweet_flour": {},
	&"stock.pancake.sauce.red_chili": {},
	&"stock.pancake.sauce.tomato": {},
}

const RECIPE_DEFINITIONS := {
	&"recipe.pancake.base": {"area_id": &"area.pancake", "product_id": &"product.pancake.custom", "stock_ids": [&"stock.pancake.batter", &"stock.pancake.egg"]},
	&"recipe.youtiao.plain": {"label": "油条", "area_id": &"area.youtiao", "product_id": &"product.youtiao.plain", "stock_ids": [&"stock.youtiao.plain_dough"]},
	&"recipe.youtiao.sesame": {"label": "芝麻油条", "area_id": &"area.youtiao", "product_id": &"product.youtiao.sesame", "stock_ids": [&"stock.youtiao.plain_dough"]},
	# Soy milk is ready-made at the serving station.  Flavour buttons unlock
	# recipes, not managed beans, so none of them may enter restock or slots.
	&"recipe.fresh_soy_milk.yellow_bean": {"label": "黄豆豆浆", "area_id": &"area.fresh_soy_milk", "product_id": &"product.fresh_soy_milk.yellow_bean", "stock_ids": []},
}

const PRODUCT_DEFINITIONS := {
	&"product.pancake.custom": {"area_id": &"area.pancake", "recipe_id": &"recipe.pancake.base"},
	&"product.youtiao.plain": {"label": "油条", "area_id": &"area.youtiao", "recipe_id": &"recipe.youtiao.plain", "base_sell_price": 6, "order_weight": 60},
	&"product.youtiao.sesame": {"label": "芝麻油条", "area_id": &"area.youtiao", "recipe_id": &"recipe.youtiao.sesame", "base_sell_price": 7, "order_weight": 25},
	&"product.fresh_soy_milk.yellow_bean": {"label": "黄豆豆浆", "area_id": &"area.fresh_soy_milk", "recipe_id": &"recipe.fresh_soy_milk.yellow_bean", "base_sell_price": 7, "material_cost": 2, "order_weight": 60},
}

const AUTOMATION_DEFINITIONS := {
	&"automation.pancake.auto_batter_ladle": {"area_id": &"area.pancake"},
	&"automation.pancake.press_once": {"area_id": &"area.pancake"},
	&"automation.pancake.auto_sauce_brush": {"area_id": &"area.pancake"},
	&"automation.youtiao.auto_lift": {"area_id": &"area.youtiao"},
	&"automation.fresh_soy_milk.auto_fill": {"area_id": &"area.fresh_soy_milk"},
	&"automation.fresh_soy_milk.double_fill": {"area_id": &"area.fresh_soy_milk"},
}
const RESTOCK_DEFINITIONS := {"stock_definition_is_source": true}
const GROWTH_DEFINITIONS := {
	&"growth.add_on.pancake.sweet_flour": {"label":"甜面酱", "kind":&"stock_unlock", "price":6, "requires_area_id":&"area.pancake", "requires_mastery":{&"area.pancake":{"qualified":2}}, "unlock_stock_ids":[&"stock.pancake.sauce.sweet_flour"], "anchor_id":&"pancake.sweet_flour"},
	&"growth.add_on.pancake.baocui": {"label":"薄脆", "kind":&"stock_unlock", "price":8, "requires_area_id":&"area.pancake", "requires_mastery":{&"area.pancake":{"qualified":4}}, "unlock_stock_ids":[&"stock.pancake.baocui"], "anchor_id":&"pancake.baocui"},
	&"growth.add_on.pancake.scallion": {"label":"香葱罐", "kind":&"stock_unlock", "price":8, "requires_area_id":&"area.pancake", "requires_mastery":{&"area.pancake":{"qualified":6}}, "unlock_stock_ids":[&"stock.pancake.scallion"], "anchor_id":&"pancake.scallion"},
	&"growth.tool.pancake.wide_spreader": {"label":"宽幅摊饼器", "kind":&"tool", "price":12, "min_day":2, "requires_area_id":&"area.pancake", "anchor_id":&"pancake.spreader"},
	&"growth.add_on.pancake.red_chili": {"label":"辣椒酱", "kind":&"stock_unlock", "price":8, "min_reputation":10, "requires_area_id":&"area.pancake", "unlock_stock_ids":[&"stock.pancake.sauce.red_chili"], "anchor_id":&"pancake.chili"},
	&"growth.add_on.pancake.ham_sausage": {"label":"火腿", "kind":&"stock_unlock", "price":12, "min_day":4, "requires_area_id":&"area.pancake", "unlock_stock_ids":[&"stock.pancake.ham_sausage"], "anchor_id":&"pancake.ham"},
	&"growth.add_on.pancake.coriander": {"label":"香菜", "kind":&"stock_unlock", "price":10, "min_day":6, "requires_area_id":&"area.pancake", "unlock_stock_ids":[&"stock.pancake.coriander"], "anchor_id":&"pancake.coriander"},
	&"growth.add_on.pancake.meat_floss": {"label":"肉松", "kind":&"stock_unlock", "price":18, "min_reputation":45, "requires_area_id":&"area.pancake", "unlock_stock_ids":[&"stock.pancake.meat_floss"], "anchor_id":&"pancake.meat_floss"},
	&"growth.add_on.pancake.tomato": {"label":"番茄酱", "kind":&"stock_unlock", "price":14, "min_day":8, "requires_area_id":&"area.pancake", "unlock_stock_ids":[&"stock.pancake.sauce.tomato"], "anchor_id":&"pancake.tomato"},
	&"growth.automation.pancake.auto_batter_ladle": {"label":"定量面糊勺", "kind":&"automation", "price":20, "requires_area_id":&"area.pancake", "requires_mastery":{&"area.pancake":{"a_grade":3}}, "automation_id":&"automation.pancake.auto_batter_ladle", "anchor_id":&"pancake.ladle"},
	&"growth.automation.pancake.press_once": {"label":"压饼器", "kind":&"automation", "price":36, "requires_area_id":&"area.pancake", "requires_mastery":{&"area.pancake":{"a_grade":5}}, "requires_growth_ids":[&"growth.tool.pancake.wide_spreader"], "automation_id":&"automation.pancake.press_once", "anchor_id":&"pancake.press"},
	&"growth.automation.pancake.auto_sauce_brush": {"label":"自动刷酱", "kind":&"automation", "price":48, "requires_area_id":&"area.pancake", "requires_mastery":{&"area.pancake":{"a_grade":8}}, "automation_id":&"automation.pancake.auto_sauce_brush", "anchor_id":&"pancake.brush"},
	&"growth.area.youtiao": {"label":"油条炸锅", "kind":&"area_unlock", "price":30, "min_reputation":20, "requires_area_id":&"area.pancake", "requires_mastery":{&"area.pancake":{"qualified":6}}, "area_id":&"area.youtiao", "device_id":&"device.youtiao_fryer", "target_tier":0, "unlock_recipe_ids":[&"recipe.youtiao.plain"], "unlock_product_ids":[&"product.youtiao.plain"], "unlock_stock_ids":[&"stock.youtiao.plain_dough"], "anchor_id":&"youtiao.fryer"},
	&"growth.capacity.youtiao_finished_tray": {"label":"油条成品盘", "kind":&"storage", "price":12, "requires_area_id":&"area.youtiao", "requires_growth_ids":[&"growth.area.youtiao"], "anchor_id":&"youtiao.finished_tray"},
	&"growth.flavor.youtiao.sesame": {"label":"芝麻油条", "kind":&"recipe_unlock", "price":12, "requires_area_id":&"area.youtiao", "requires_growth_ids":[&"growth.capacity.youtiao_finished_tray"], "requires_mastery":{&"area.youtiao":{"qualified":2}}, "unlock_recipe_ids":[&"recipe.youtiao.sesame"], "unlock_product_ids":[&"product.youtiao.sesame"], "anchor_id":&"youtiao.sesame"},
	&"growth.equipment.youtiao.advanced": {"label":"高级油条机", "kind":&"device_tier", "price":36, "requires_area_id":&"area.youtiao", "requires_mastery":{&"area.youtiao":{"qualified":6}}, "device_id":&"device.youtiao_fryer", "target_tier":1, "automation_id":&"automation.youtiao.auto_lift", "anchor_id":&"youtiao.advanced"},
	&"growth.area.fresh_soy_milk": {"label":"初级豆浆机", "kind":&"area_unlock", "price":60, "min_day":7, "min_reputation":60, "requires_area_id":&"area.youtiao", "requires_mastery":{&"area.youtiao":{"qualified":4}}, "area_id":&"area.fresh_soy_milk", "device_id":&"device.fresh_soy_milk_machine", "target_tier":0, "unlock_recipe_ids":[&"recipe.fresh_soy_milk.yellow_bean"], "unlock_product_ids":[&"product.fresh_soy_milk.yellow_bean"], "anchor_id":&"soy.machine"},
	&"growth.assist.fresh_soy_milk.sugar": {"label":"加糖罐", "kind":&"assist", "price":12, "requires_area_id":&"area.fresh_soy_milk", "requires_mastery":{&"area.fresh_soy_milk":{"qualified":2}}, "assist_id":&"assist.fresh_soy_milk.sugar", "anchor_id":&"soy.sugar"},
	&"growth.assist.fresh_soy_milk.ice": {"label":"加冰盒", "kind":&"assist", "price":18, "requires_area_id":&"area.fresh_soy_milk", "requires_mastery":{&"area.fresh_soy_milk":{"qualified":4}}, "assist_id":&"assist.fresh_soy_milk.ice", "anchor_id":&"soy.ice"},
	&"growth.automation.fresh_soy_milk.auto_fill": {"label":"中级豆浆机", "kind":&"automation", "price":64, "requires_area_id":&"area.fresh_soy_milk", "requires_mastery":{&"area.fresh_soy_milk":{"a_grade":4}}, "automation_id":&"automation.fresh_soy_milk.auto_fill", "anchor_id":&"soy.auto_fill"},
	&"growth.automation.fresh_soy_milk.advanced": {"label":"高级豆浆机", "kind":&"automation", "price":80, "requires_area_id":&"area.fresh_soy_milk", "requires_mastery":{&"area.fresh_soy_milk":{"a_grade":10}}, "requires_growth_ids":[&"growth.automation.fresh_soy_milk.auto_fill"], "automation_id":&"automation.fresh_soy_milk.double_fill", "anchor_id":&"soy.advanced"},
}
## Stable visual order for the upgrade workshop. It is not a purchase route.
const GROWTH_DISPLAY_ORDER: Array[StringName] = [
	&"growth.add_on.pancake.sweet_flour", &"growth.add_on.pancake.baocui", &"growth.add_on.pancake.scallion", &"growth.tool.pancake.wide_spreader", &"growth.automation.pancake.auto_batter_ladle", &"growth.add_on.pancake.red_chili", &"growth.add_on.pancake.ham_sausage", &"growth.add_on.pancake.coriander", &"growth.add_on.pancake.meat_floss", &"growth.add_on.pancake.tomato", &"growth.automation.pancake.press_once", &"growth.automation.pancake.auto_sauce_brush",
	&"growth.area.youtiao", &"growth.capacity.youtiao_finished_tray", &"growth.flavor.youtiao.sesame", &"growth.equipment.youtiao.advanced",
	&"growth.area.fresh_soy_milk", &"growth.assist.fresh_soy_milk.sugar", &"growth.assist.fresh_soy_milk.ice", &"growth.automation.fresh_soy_milk.auto_fill", &"growth.automation.fresh_soy_milk.advanced",
]
const MASTERY_DEFINITIONS := {
	&"area.pancake": {"qualified_key": &"qualified", "a_grade_key": &"a_grade", "bronze": {"qualified": 8, "a_grade": 2}, "silver": {"qualified": 20, "a_grade": 8}, "gold": {"qualified": 50, "a_grade": 25}},
	&"area.youtiao": {"qualified_key": &"qualified", "a_grade_key": &"a_grade", "bronze": {"qualified": 4, "a_grade": 1}, "silver": {"qualified": 20, "a_grade": 8}, "gold": {"qualified": 50, "a_grade": 25}},
	&"area.fresh_soy_milk": {"qualified_key": &"qualified", "a_grade_key": &"a_grade", "bronze": {"qualified": 4, "a_grade": 1}, "silver": {"qualified": 20, "a_grade": 8}, "gold": {"qualified": 50, "a_grade": 25}},
}
const ORDER_BALANCE := {
	"youtiao_stage": {"pancake_main_percent": 75, "youtiao_single_percent": 25, "pancake_adds_youtiao_percent": 30},
	"three_area_stage": {"pancake_main_percent": 70, "youtiao_single_percent": 15, "soy_single_percent": 15, "pancake_plain_percent": 55, "pancake_one_side_percent": 35, "pancake_two_sides_percent": 10},
	"queue_size": 3,
}
const REPUTATION_BALANCE := {&"all_a": 4, &"all_ab": 3, &"has_c": 1, &"failure": -2, &"unstarted_refusal": -1}
const DAILY_GOAL_DEFINITIONS := {
	&"goal.signature.pancake_three_a": {"area_id": &"area.pancake", "target": 3, "event_kind": &"sale", "requires_grade": &"A", "reward_coins": 18, "reward_reputation": 2},
	&"goal.signature.youtiao_four_no_burn": {"area_id": &"area.youtiao", "target": 4, "event_kind": &"sale", "requires_min_grade": &"B", "fails_on": &"waste", "reward_coins": 22, "reward_reputation": 2},
	&"goal.signature.fresh_soy_milk_four_no_spoil": {"area_id": &"area.fresh_soy_milk", "target": 4, "event_kind": &"sale", "requires_min_grade": &"B", "fails_on": &"waste", "reward_coins": 24, "reward_reputation": 2},
	&"goal.signature.combo_two_no_failure": {"area_id": &"", "target": 2, "event_kind": &"sale", "requires_complexity": &"double", "fails_on": &"order_failure", "reward_coins": 20, "reward_reputation": 2},
}
## Orders are authored with stable inventory IDs.  UI adapters may translate
## them to the legacy pancake simulation IDs, but eligibility never comes from
## visible material slots or widget state.
const PANCAKE_ORDER_TEMPLATES := {
	&"order.pancake.egg": {"title": "鸡蛋煎饼", "ingredient_stock_ids": [&"stock.pancake.egg"], "sauce_stock_ids": [], "heat_preference": &"golden", "time_limit": 68.0, "payment_coins": 3, "customer_line": "来一份鸡蛋煎饼，不加其他小料。"},
	&"order.pancake.egg_sweet": {"title": "鸡蛋甜面酱煎饼", "ingredient_stock_ids": [&"stock.pancake.egg"], "sauce_stock_ids": [&"stock.pancake.sauce.sweet_flour"], "heat_preference": &"golden", "time_limit": 70.0, "payment_coins": 4, "customer_line": "鸡蛋煎饼刷甜面酱就好。"},
	&"order.pancake.crisp": {"title": "薄脆煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.baocui"], "sauce_stock_ids": [&"stock.pancake.sauce.sweet_flour"], "heat_preference": &"golden", "time_limit": 72.0, "payment_coins": 5, "customer_line": "加薄脆，刷甜面酱，不要葱。"},
	&"order.pancake.classic": {"title": "经典杂粮煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.scallion"], "sauce_stock_ids": [&"stock.pancake.sauce.sweet_flour"], "heat_preference": &"golden", "time_limit": 72.0, "payment_coins": 3, "customer_line": "来一份经典的，薄脆和葱花都要。"},
	&"order.pancake.double_egg": {"title": "双蛋薄脆煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.scallion"], "sauce_stock_ids": [&"stock.pancake.sauce.sweet_flour"], "heat_preference": &"golden", "time_limit": 78.0, "payment_coins": 5, "customer_line": "鸡蛋加双份，薄脆和葱花照常。"},
	&"order.pancake.chili_simple": {"title": "香辣薄脆煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.scallion"], "sauce_stock_ids": [&"stock.pancake.sauce.red_chili"], "heat_preference": &"golden", "time_limit": 74.0, "payment_coins": 8, "customer_line": "薄脆和葱花都要，刷辣酱。"},
	&"order.pancake.chili_ham": {"title": "香辣火腿煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.ham_sausage"], "sauce_stock_ids": [&"stock.pancake.sauce.red_chili"], "heat_preference": &"well_done", "time_limit": 76.0, "payment_coins": 12, "customer_line": "火腿加辣酱，边缘煎香一点。"},
	&"order.pancake.double_sauce": {"title": "双酱全料煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.ham_sausage", &"stock.pancake.scallion"], "sauce_stock_ids": [&"stock.pancake.sauce.sweet_flour", &"stock.pancake.sauce.red_chili"], "heat_preference": &"golden", "time_limit": 82.0, "payment_coins": 22, "customer_line": "两种酱都刷，配料给我放匀。"},
	&"order.pancake.scallion_light": {"title": "葱香少料煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.scallion"], "sauce_stock_ids": [&"stock.pancake.sauce.sweet_flour"], "heat_preference": &"light", "time_limit": 68.0, "payment_coins": 5, "customer_line": "这份不加薄脆，饼皮嫩一点就好。"},
	&"order.pancake.meat_floss_sweet": {"title": "甜酱肉松煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.meat_floss", &"stock.pancake.scallion"], "sauce_stock_ids": [&"stock.pancake.sauce.sweet_flour"], "heat_preference": &"golden", "time_limit": 84.0, "payment_coins": 28, "customer_line": "肉松铺匀些，甜酱和葱花都要。"},
	&"order.pancake.double_meat_floss": {"title": "双份肉松煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.meat_floss", &"stock.pancake.meat_floss", &"stock.pancake.scallion"], "sauce_stock_ids": [&"stock.pancake.sauce.sweet_flour"], "heat_preference": &"golden", "time_limit": 86.0, "payment_coins": 31, "customer_line": "肉松请给我加两份，甜面酱和葱花都要。"},
	&"order.pancake.extra_sweet_sauce": {"title": "多甜面酱煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.scallion"], "sauce_stock_ids": [&"stock.pancake.sauce.sweet_flour", &"stock.pancake.sauce.sweet_flour"], "heat_preference": &"golden", "time_limit": 76.0, "payment_coins": 6, "customer_line": "甜面酱加双份，薄脆和葱花都要。"},
	&"order.pancake.coriander": {"title": "香菜薄脆煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.coriander"], "sauce_stock_ids": [&"stock.pancake.sauce.sweet_flour"], "heat_preference": &"golden", "time_limit": 78.0, "payment_coins": 10, "customer_line": "薄脆和香菜都要，刷甜面酱。"},
	&"order.pancake.tomato_ham": {"title": "番茄火腿煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.ham_sausage"], "sauce_stock_ids": [&"stock.pancake.sauce.tomato"], "heat_preference": &"golden", "time_limit": 78.0, "payment_coins": 14, "customer_line": "火腿薄脆，刷番茄酱。"},
	&"order.pancake.youtiao_scallion": {"title": "油条葱香煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.youtiao", &"stock.pancake.scallion"], "sauce_stock_ids": [&"stock.pancake.sauce.sweet_flour"], "requires_recipe_ids": [&"recipe.youtiao.plain"], "heat_preference": &"golden", "time_limit": 72.0, "payment_coins": 12, "customer_line": "加一根油条、葱花和甜面酱。"},
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
		var definition: Dictionary = STOCK_DEFINITIONS[stock_id]
		if AREA_IDS.has(StringName(definition.get("area_id", &""))):
			ids.append(stock_id)
	return ids

static func growth_ids() -> Array[StringName]:
	return GROWTH_DISPLAY_ORDER.duplicate()

static func validate_catalog() -> PackedStringArray:
	var errors := PackedStringArray()
	if AREA_IDS.size() != 3 or PHYSICAL_AREA_IDS.size() != 3 or UNLOCK_AREA_IDS.size() != 3:
		errors.append("Three-area orders must each contain exactly three areas.")
	for area_id in AREA_IDS:
		if not AREA_DEFINITIONS.has(area_id):
			errors.append("Missing area definition: %s" % area_id)
		elif not DEVICE_DEFINITIONS.has(AREA_DEFINITIONS[area_id].get("device_id", &"")):
			errors.append("Missing device for area: %s" % area_id)
		if not MASTERY_DEFINITIONS.has(area_id):
			errors.append("Missing mastery definition: %s" % area_id)
	for slot_index in range(1, 16):
		var slot_id := StringName("slot.%02d" % slot_index)
		if not MATERIAL_SLOT_DEFINITIONS.has(slot_id):
			if slot_index in [5, 6]:
				continue
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
		elif slot.get("kind", &"") == &"split_stock":
			var stock_ids := Array(slot.get("stock_ids", []))
			if stock_ids.size() != 2:
				errors.append("Split stock slot must author two cells: %s" % slot_id)
			for stock_id_value in stock_ids:
				var stock_id := StringName(stock_id_value)
				if stock_id != &"" and (not STOCK_DEFINITIONS.has(stock_id) or STOCK_DEFINITIONS[stock_id].get("material_slot_id", &"") != slot_id):
					errors.append("Split stock to slot mismatch: %s" % stock_id)
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
		if not AREA_IDS.has(StringName(recipe.get("area_id", &""))):
			continue
		if not PRODUCT_DEFINITIONS.has(recipe.get("product_id", &"")):
			errors.append("Recipe has unknown product: %s" % recipe_id)
		for stock_id in recipe.get("stock_ids", []):
			if not STOCK_DEFINITIONS.has(stock_id):
				errors.append("Recipe has unknown stock: %s" % recipe_id)
	for product_id in PRODUCT_DEFINITIONS:
		var product: Dictionary = PRODUCT_DEFINITIONS[product_id]
		if not AREA_IDS.has(StringName(product.get("area_id", &""))):
			continue
		if not RECIPE_DEFINITIONS.has(product.get("recipe_id", &"")):
			errors.append("Product has unknown recipe: %s" % product_id)
	for device_id in DEVICE_DEFINITIONS:
		if not AREA_IDS.has(StringName(Dictionary(DEVICE_DEFINITIONS[device_id]).get("area_id", &""))):
			continue
		var seen_tiers := PackedInt32Array()
		for tier_definition in Array(DEVICE_DEFINITIONS[device_id].get("tiers", [])):
			var tier := int(Dictionary(tier_definition).get("tier", -1))
			if seen_tiers.has(tier):
				errors.append("Device has duplicate tier: %s/%d" % [device_id, tier])
			seen_tiers.append(tier)
		var required_tiers := [0] if device_id in [&"device.pancake_griddle", &"device.fresh_soy_milk_machine"] else [0, 1]
		for required_tier in required_tiers:
			if not seen_tiers.has(required_tier):
				errors.append("Device is missing tier: %s/%d" % [device_id, required_tier])
	if GROWTH_DISPLAY_ORDER.is_empty():
		errors.append("Growth workshop display order must not be empty.")
	var routed_growth_ids: Dictionary = {}
	for route_index in GROWTH_DISPLAY_ORDER.size():
		var routed_growth_id := GROWTH_DISPLAY_ORDER[route_index]
		if not GROWTH_DEFINITIONS.has(routed_growth_id):
			errors.append("Display order contains unknown item: %s" % routed_growth_id)
		if routed_growth_ids.has(routed_growth_id):
			errors.append("Display order contains duplicate item: %s" % routed_growth_id)
		routed_growth_ids[routed_growth_id] = route_index
	for growth_id in GROWTH_DISPLAY_ORDER:
		var growth: Dictionary = GROWTH_DEFINITIONS[growth_id]
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
	if DAILY_GOAL_DEFINITIONS.is_empty() or ORDER_BALANCE.is_empty() or REPUTATION_BALANCE.is_empty():
		errors.append("Three-area balance and daily goal definitions must not be empty.")
	for template_id in PANCAKE_ORDER_TEMPLATES:
		var template: Dictionary = PANCAKE_ORDER_TEMPLATES[template_id]
		var sauce_ids: Array = Array(template.get("sauce_stock_ids", []))
		var portion_counts := {}
		for stock_id_variant in Array(template.get("ingredient_stock_ids", [])) + sauce_ids:
			var portion_id := StringName(stock_id_variant)
			portion_counts[portion_id] = int(portion_counts.get(portion_id, 0)) + 1
			if int(portion_counts[portion_id]) > 2:
				errors.append("Pancake order exceeds two portions for %s: %s" % [portion_id, template_id])
		var unique_sauces := {}
		for sauce_id in sauce_ids:
			unique_sauces[StringName(sauce_id)] = true
		if unique_sauces.size() > 2:
			errors.append("Pancake order exceeds two sauce types: %s" % template_id)
		for stock_id in Array(template.get("ingredient_stock_ids", [])) + sauce_ids:
			if not STOCK_DEFINITIONS.has(stock_id):
				errors.append("Pancake order has unknown stock: %s" % template_id)
	return errors

static func _copy_definition(source: Dictionary, definition_id: StringName) -> Dictionary:
	if not source.has(definition_id):
		return {}
	return source[definition_id].duplicate(true)
