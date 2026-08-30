class_name FiveAreaCatalog
extends RefCounted

## Static four-area source of truth. Runtime services own availability, stock
## counts and pending purchases; this catalog intentionally contains no save/UI
## state.

const BALANCE_VERSION := 10

const AREA_IDS: Array[StringName] = [
	&"area.pancake",
	&"area.youtiao",
	&"area.fresh_soy_milk",
	&"area.packaged_drink",
]

## Physical counter order is deliberately different from the progression order.
const PHYSICAL_AREA_IDS: Array[StringName] = [
	&"area.fresh_soy_milk",
	&"area.pancake",
	&"area.youtiao",
	&"area.packaged_drink",
]
const UNLOCK_AREA_IDS: Array[StringName] = [
	&"area.pancake",
	&"area.youtiao",
	&"area.fresh_soy_milk",
	&"area.packaged_drink",
]

const AREA_DEFINITIONS := {
	&"area.pancake": {"label": "煎饼", "physical_index": 1, "unlock_index": 0, "device_id": &"device.pancake_griddle"},
	&"area.youtiao": {"label": "油条", "physical_index": 2, "unlock_index": 1, "device_id": &"device.youtiao_fryer"},
	&"area.fresh_soy_milk": {"label": "现磨豆浆", "physical_index": 0, "unlock_index": 2, "device_id": &"device.fresh_soy_milk_machine"},
	&"area.packaged_drink": {"label": "成品饮品", "physical_index": 3, "unlock_index": 3, "device_id": &"device.packaged_drink_rack"},
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
			{"tier": 2, "label": "双篮炸锅", "capacity": 4, "duration_seconds": 10.0, "safe_seconds": 5.0, "decay_seconds": 10.0, "drain_seconds": 2.0},
		],
	},
	&"device.fresh_soy_milk_machine": {
		"area_id": &"area.fresh_soy_milk",
		"tiers": [
			{"tier": 0, "label": "初级豆浆机", "soy_reservoir_capacity": 2, "full_cup_seconds": 0.8},
		],
	},
	&"device.packaged_drink_rack": {
		"area_id": &"area.packaged_drink",
		"tiers": [
			{"tier": 0, "label": "成品饮品架", "capacity": 6},
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
	&"stock.pancake.egg": {"area_id": &"area.pancake", "category": &"add_on", "refill_seconds": 0.15, "restock_unit_cost": 1, "restock_capacity": 10, "material_slot_id": &"slot.07"},
	&"stock.pancake.baocui": {"area_id": &"area.pancake", "category": &"add_on", "refill_seconds": 0.15, "restock_unit_cost": 1, "restock_capacity": 10, "material_slot_id": &"slot.08"},
	&"stock.pancake.scallion": {"area_id": &"area.pancake", "category": &"add_on", "unlimited": true, "restock_unit_cost": 1, "restock_capacity": 0, "material_slot_id": &"slot.09"},
	# Keep this stable ID so existing runtime save and order contracts continue to
	# resolve, while all player-facing text identifies the single shared sauce.
	# The shared sauce jar is a station fixture: it never needs stocking and does
	# not add a replenishment cost to the finished pancake.
	&"stock.pancake.sauce.sweet_flour": {"label": "秘制酱料", "area_id": &"area.pancake", "category": &"sauce", "unlimited": true, "restock_unit_cost": 0, "restock_capacity": 0, "material_slot_id": &"", "surface_input_id": &"ui.pancake.secret_sauce_brush"},
	&"stock.pancake.ham_sausage": {"area_id": &"area.pancake", "category": &"add_on", "refill_seconds": 0.15, "restock_unit_cost": 2, "restock_capacity": 10, "material_slot_id": &""},
	&"stock.pancake.meat_floss": {"area_id": &"area.pancake", "category": &"add_on", "refill_seconds": 0.15, "restock_unit_cost": 2, "restock_capacity": 10, "material_slot_id": &""},
	&"stock.pancake.coriander": {"area_id": &"area.pancake", "category": &"add_on", "unlimited": true, "restock_unit_cost": 1, "restock_capacity": 0, "material_slot_id": &""},
	# A stable order/simulation identifier for the processed plain youtiao.
	# Capacity stays zero so it can never enter the paid ordinary-restock path.
	&"stock.pancake.youtiao": {"label": "油条", "area_id": &"area.pancake", "category": &"prepared_add_on", "restock_unit_cost": 2, "restock_capacity": 0, "material_slot_id": &""},
	# The physical board has four authored dough positions. Keep its stock cap
	# fixed at four even after the shared pantry-capacity growth upgrades.
	&"stock.youtiao.plain_dough": {"label": "油条面胚", "area_id": &"area.youtiao", "category": &"dough", "refill_seconds": 0.15, "restock_unit_cost": 2, "restock_capacity": 4, "fixed_restock_capacity": true, "material_slot_id": &"slot.04"},
	&"stock.chicken.cutlet_raw": {"label": "鸡排", "area_id": &"area.youtiao", "category": &"dough", "refill_seconds": 0.15, "restock_unit_cost": 4, "restock_capacity": 4, "fixed_restock_capacity": true, "material_slot_id": &""},
	&"stock.packaged_drink.juice": {"label": "果汁", "area_id": &"area.packaged_drink", "category": &"packaged_drink", "refill_seconds": 0.15, "restock_unit_cost": 1, "restock_capacity": 10, "material_slot_id": &""},
}

## Stable left-to-right workbench order used by the opening checklist.  The
## checklist filters this list against progression ownership at runtime.
const OPENING_RESTOCK_DISPLAY_ORDER: Array[StringName] = [
	&"stock.pancake.batter",
	&"stock.pancake.sauce.sweet_flour",
	&"stock.pancake.egg",
	&"stock.pancake.baocui",
	&"stock.pancake.scallion",
	&"stock.pancake.ham_sausage",
	&"stock.pancake.meat_floss",
	&"stock.pancake.coriander",
	&"stock.youtiao.plain_dough",
	&"stock.chicken.cutlet_raw",
	&"stock.packaged_drink.juice",
]

const ADD_ON_DEFINITIONS := {
	&"stock.pancake.egg": {}, &"stock.pancake.baocui": {}, &"stock.pancake.scallion": {},
	&"stock.pancake.ham_sausage": {}, &"stock.pancake.meat_floss": {}, &"stock.pancake.coriander": {}, &"stock.pancake.youtiao": {},
}
const SAUCE_DEFINITIONS := {
	&"stock.pancake.sauce.sweet_flour": {},
}

const RECIPE_DEFINITIONS := {
	&"recipe.pancake.base": {"area_id": &"area.pancake", "product_id": &"product.pancake.custom", "stock_ids": [&"stock.pancake.batter", &"stock.pancake.egg"]},
	&"recipe.youtiao.plain": {"label": "油条", "area_id": &"area.youtiao", "product_id": &"product.youtiao.plain", "stock_ids": [&"stock.youtiao.plain_dough"]},
	&"recipe.chicken.cutlet": {"label": "炸鸡排", "area_id": &"area.youtiao", "product_id": &"product.chicken.cutlet", "stock_ids": [&"stock.chicken.cutlet_raw"], "duration_seconds": 12.0},
	# Soy milk is ready-made at the serving station.  Flavour buttons unlock
	# recipes, not managed beans, so none of them may enter restock or slots.
	&"recipe.fresh_soy_milk.yellow_bean": {"label": "黄豆豆浆", "area_id": &"area.fresh_soy_milk", "product_id": &"product.fresh_soy_milk.yellow_bean", "stock_ids": []},
	&"recipe.packaged_drink.juice": {"label": "果汁", "area_id": &"area.packaged_drink", "product_id": &"product.packaged_drink.juice", "stock_ids": [&"stock.packaged_drink.juice"]},
}

const PRODUCT_DEFINITIONS := {
	&"product.pancake.custom": {"area_id": &"area.pancake", "recipe_id": &"recipe.pancake.base"},
	&"product.youtiao.plain": {"label": "油条", "area_id": &"area.youtiao", "recipe_id": &"recipe.youtiao.plain", "base_sell_price": 9, "order_weight": 60},
	&"product.chicken.cutlet": {"label": "炸鸡排", "area_id": &"area.youtiao", "recipe_id": &"recipe.chicken.cutlet", "base_sell_price": 24, "order_weight": 25},
	&"product.fresh_soy_milk.yellow_bean": {"label": "黄豆豆浆", "area_id": &"area.fresh_soy_milk", "recipe_id": &"recipe.fresh_soy_milk.yellow_bean", "base_sell_price": 9, "material_cost": 2, "order_weight": 60},
	&"product.packaged_drink.juice": {"label": "果汁", "area_id": &"area.packaged_drink", "recipe_id": &"recipe.packaged_drink.juice", "base_sell_price": 9, "material_cost": 1, "order_weight": 60},
}

## Customer-facing prices. Pancakes always start with a 2-coin plain pancake;
## listed add-ons are charged per portion, while the shared secret sauce is free.
const PANCAKE_BASE_SELL_PRICE := 6
const PANCAKE_ADD_ON_SELL_PRICES := {
	&"stock.pancake.egg": 6,
	&"stock.pancake.baocui": 3,
	&"stock.pancake.scallion": 3,
	&"stock.pancake.coriander": 3,
	&"stock.pancake.ham_sausage": 12,
	&"stock.pancake.meat_floss": 12,
	&"stock.pancake.youtiao": 9,
}
const SOY_MILK_SELL_PRICES := {
	&"plain": 9,
	&"sugared": 12,
}

const AUTOMATION_DEFINITIONS := {
	&"automation.pancake.auto_batter_ladle": {"area_id": &"area.pancake"},
	&"automation.pancake.press_once": {"area_id": &"area.pancake"},
	&"automation.pancake.non_burning_griddle": {"area_id": &"area.pancake"},
	&"automation.pancake.fast_cook_griddle": {"area_id": &"area.pancake"},
	&"automation.pancake.one_click_egg": {"area_id": &"area.pancake"},
	&"automation.youtiao.auto_lift": {"area_id": &"area.youtiao"},
	&"automation.fresh_soy_milk.auto_fill": {"area_id": &"area.fresh_soy_milk"},
	&"automation.fresh_soy_milk.double_fill": {"area_id": &"area.fresh_soy_milk"},
}
const RESTOCK_DEFINITIONS := {"stock_definition_is_source": true}
const GROWTH_DEFINITIONS := {
	&"growth.add_on.pancake.egg": {"label":"鸡蛋", "kind":&"stock_unlock", "price":10, "requires_area_id":&"area.pancake", "unlock_stock_ids":[&"stock.pancake.egg"], "anchor_id":&"pancake.egg"},
	&"growth.automation.pancake.one_click_egg": {"label":"一键打蛋", "kind":&"automation", "price":60, "requires_area_id":&"area.pancake", "requires_growth_ids":[&"growth.add_on.pancake.egg"], "automation_id":&"automation.pancake.one_click_egg", "anchor_id":&"pancake.egg"},
	&"growth.add_on.pancake.baocui": {"label":"薄脆", "kind":&"stock_unlock", "price":30, "requires_area_id":&"area.pancake", "unlock_stock_ids":[&"stock.pancake.baocui"], "anchor_id":&"pancake.baocui"},
	&"growth.add_on.pancake.scallion": {"label":"香葱罐", "kind":&"stock_unlock", "price":50, "requires_area_id":&"area.pancake", "unlock_stock_ids":[&"stock.pancake.scallion"], "anchor_id":&"pancake.scallion"},
	&"growth.add_on.pancake.ham_sausage": {"label":"火腿", "kind":&"stock_unlock", "price":80, "requires_area_id":&"area.pancake", "requires_growth_ids":[&"growth.add_on.pancake.meat_floss"], "unlock_stock_ids":[&"stock.pancake.ham_sausage"], "anchor_id":&"pancake.ham"},
	&"growth.add_on.pancake.coriander": {"label":"香菜", "kind":&"stock_unlock", "price":50, "requires_area_id":&"area.pancake", "requires_growth_ids":[&"growth.add_on.pancake.scallion"], "unlock_stock_ids":[&"stock.pancake.coriander"], "anchor_id":&"pancake.coriander"},
	&"growth.add_on.pancake.meat_floss": {"label":"肉松", "kind":&"stock_unlock", "price":80, "requires_area_id":&"area.pancake", "requires_growth_ids":[&"growth.add_on.pancake.baocui"], "unlock_stock_ids":[&"stock.pancake.meat_floss"], "anchor_id":&"pancake.meat_floss"},
	&"growth.automation.pancake.auto_batter_ladle": {"label":"定量面糊勺", "kind":&"automation", "price":120, "requires_area_id":&"area.pancake", "automation_id":&"automation.pancake.auto_batter_ladle", "anchor_id":&"pancake.ladle"},
	&"growth.automation.pancake.press_once": {"label":"压饼器", "kind":&"automation", "price":120, "requires_area_id":&"area.pancake", "automation_id":&"automation.pancake.press_once", "anchor_id":&"pancake.press"},
	&"growth.automation.pancake.non_burning_griddle": {"label":"不会糊的煎饼鏊子", "kind":&"automation", "price":180, "requires_area_id":&"area.pancake", "requires_growth_ids":[&"growth.automation.pancake.auto_batter_ladle", &"growth.automation.pancake.press_once"], "automation_id":&"automation.pancake.non_burning_griddle", "anchor_id":&"pancake.griddle"},
	&"growth.automation.pancake.fast_cook_griddle": {"label":"快熟煎饼鏊子", "kind":&"automation", "price":240, "requires_area_id":&"area.pancake", "requires_growth_ids":[&"growth.automation.pancake.non_burning_griddle"], "automation_id":&"automation.pancake.fast_cook_griddle", "anchor_id":&"pancake.griddle"},
	&"growth.capacity.pancake_holding_tray.first_slot": {"label":"煎饼暂存盘", "kind":&"storage", "price":40, "requires_area_id":&"area.pancake", "anchor_id":&"pancake.holding_tray.first"},
	&"growth.area.youtiao": {"label":"油条炸锅", "kind":&"area_unlock", "price":200, "requires_area_id":&"area.pancake", "requires_growth_ids":[&"growth.add_on.pancake.egg", &"growth.add_on.pancake.baocui", &"growth.add_on.pancake.scallion", &"growth.add_on.pancake.ham_sausage", &"growth.add_on.pancake.coriander", &"growth.add_on.pancake.meat_floss"], "area_id":&"area.youtiao", "device_id":&"device.youtiao_fryer", "target_tier":0, "unlock_recipe_ids":[&"recipe.youtiao.plain"], "unlock_product_ids":[&"product.youtiao.plain"], "unlock_stock_ids":[&"stock.youtiao.plain_dough"], "anchor_id":&"youtiao.fryer"},
	&"growth.capacity.youtiao_finished_tray": {"label":"油条成品盘", "kind":&"storage", "price":50, "requires_area_id":&"area.youtiao", "requires_growth_ids":[&"growth.area.youtiao"], "anchor_id":&"youtiao.finished_tray"},
	&"growth.equipment.youtiao.advanced": {"label":"高级油条机", "kind":&"device_tier", "price":250, "requires_area_id":&"area.youtiao", "device_id":&"device.youtiao_fryer", "target_tier":1, "automation_id":&"automation.youtiao.auto_lift", "anchor_id":&"youtiao.advanced"},
	&"growth.equipment.youtiao.dual_basket": {"label":"双篮炸锅", "kind":&"device_tier", "price":350, "requires_area_id":&"area.youtiao", "requires_growth_ids":[&"growth.equipment.youtiao.advanced"], "device_id":&"device.youtiao_fryer", "target_tier":2, "unlock_recipe_ids":[&"recipe.chicken.cutlet"], "unlock_product_ids":[&"product.chicken.cutlet"], "unlock_stock_ids":[&"stock.chicken.cutlet_raw"], "anchor_id":&"youtiao.dual_basket"},
	&"growth.capacity.chicken_finished_tray": {"label":"鸡排成品盘", "kind":&"storage", "price":60, "requires_area_id":&"area.youtiao", "requires_growth_ids":[&"growth.equipment.youtiao.dual_basket"], "anchor_id":&"youtiao.chicken_finished_tray"},
	&"growth.area.fresh_soy_milk": {"label":"初级豆浆机", "kind":&"area_unlock", "price":200, "requires_area_id":&"area.pancake", "requires_growth_ids":[&"growth.add_on.pancake.egg", &"growth.add_on.pancake.baocui", &"growth.add_on.pancake.scallion", &"growth.add_on.pancake.ham_sausage", &"growth.add_on.pancake.coriander", &"growth.add_on.pancake.meat_floss"], "area_id":&"area.fresh_soy_milk", "device_id":&"device.fresh_soy_milk_machine", "target_tier":0, "unlock_recipe_ids":[&"recipe.fresh_soy_milk.yellow_bean"], "unlock_product_ids":[&"product.fresh_soy_milk.yellow_bean"], "anchor_id":&"soy.machine"},
	&"growth.assist.fresh_soy_milk.sugar": {"label":"加糖罐", "kind":&"assist", "price":50, "requires_area_id":&"area.fresh_soy_milk", "assist_id":&"assist.fresh_soy_milk.sugar", "anchor_id":&"soy.sugar"},
	&"growth.automation.fresh_soy_milk.auto_fill": {"label":"中级豆浆机", "kind":&"automation", "price":250, "requires_area_id":&"area.fresh_soy_milk", "automation_id":&"automation.fresh_soy_milk.auto_fill", "anchor_id":&"soy.auto_fill"},
	&"growth.automation.fresh_soy_milk.advanced": {"label":"高级豆浆机", "kind":&"automation", "price":350, "requires_area_id":&"area.fresh_soy_milk", "requires_growth_ids":[&"growth.automation.fresh_soy_milk.auto_fill"], "automation_id":&"automation.fresh_soy_milk.double_fill", "anchor_id":&"soy.advanced"},
	&"growth.area.packaged_drink": {"label":"成品饮品架", "kind":&"area_unlock", "price":200, "requires_area_id":&"area.fresh_soy_milk", "area_id":&"area.packaged_drink", "device_id":&"device.packaged_drink_rack", "target_tier":0, "unlock_recipe_ids":[&"recipe.packaged_drink.juice"], "unlock_product_ids":[&"product.packaged_drink.juice"], "unlock_stock_ids":[&"stock.packaged_drink.juice"], "anchor_id":&"packaged_drink.rack"},
}
## Stable visual order for the upgrade workshop. It is not a purchase route.
const GROWTH_DISPLAY_ORDER: Array[StringName] = [
	&"growth.add_on.pancake.egg", &"growth.automation.pancake.one_click_egg", &"growth.add_on.pancake.baocui", &"growth.add_on.pancake.scallion", &"growth.automation.pancake.auto_batter_ladle", &"growth.add_on.pancake.meat_floss", &"growth.add_on.pancake.ham_sausage", &"growth.add_on.pancake.coriander", &"growth.automation.pancake.press_once", &"growth.automation.pancake.non_burning_griddle", &"growth.automation.pancake.fast_cook_griddle", &"growth.capacity.pancake_holding_tray.first_slot",
	&"growth.area.youtiao", &"growth.capacity.youtiao_finished_tray", &"growth.equipment.youtiao.advanced", &"growth.equipment.youtiao.dual_basket", &"growth.capacity.chicken_finished_tray",
	&"growth.area.fresh_soy_milk", &"growth.assist.fresh_soy_milk.sugar", &"growth.automation.fresh_soy_milk.auto_fill", &"growth.automation.fresh_soy_milk.advanced",
	&"growth.area.packaged_drink",
]
const MASTERY_DEFINITIONS := {
	&"area.pancake": {"qualified_key": &"qualified", "a_grade_key": &"a_grade", "bronze": {"qualified": 8, "a_grade": 2}, "silver": {"qualified": 20, "a_grade": 8}, "gold": {"qualified": 50, "a_grade": 25}},
	&"area.youtiao": {"qualified_key": &"qualified", "a_grade_key": &"a_grade", "bronze": {"qualified": 4, "a_grade": 1}, "silver": {"qualified": 20, "a_grade": 8}, "gold": {"qualified": 50, "a_grade": 25}},
	&"area.fresh_soy_milk": {"qualified_key": &"qualified", "a_grade_key": &"a_grade", "bronze": {"qualified": 4, "a_grade": 1}, "silver": {"qualified": 20, "a_grade": 8}, "gold": {"qualified": 50, "a_grade": 25}},
	&"area.packaged_drink": {"qualified_key": &"qualified", "a_grade_key": &"a_grade", "bronze": {"qualified": 4, "a_grade": 1}, "silver": {"qualified": 20, "a_grade": 8}, "gold": {"qualified": 50, "a_grade": 25}},
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
	&"goal.signature.packaged_drink_four": {"area_id": &"area.packaged_drink", "target": 4, "event_kind": &"sale", "requires_min_grade": &"B", "reward_coins": 20, "reward_reputation": 2},
	&"goal.signature.combo_two_no_failure": {"area_id": &"", "target": 2, "event_kind": &"sale", "requires_complexity": &"double", "fails_on": &"order_failure", "reward_coins": 20, "reward_reputation": 2},
}
## Orders are authored with stable inventory IDs.  UI adapters may translate
## them to the legacy pancake simulation IDs, but eligibility never comes from
## visible material slots or widget state.
const PANCAKE_ORDER_TEMPLATES := {
	&"order.pancake.egg": {"title": "鸡蛋煎饼", "ingredient_stock_ids": [&"stock.pancake.egg"], "sauce_stock_ids": [], "heat_preference": &"golden", "time_limit": 68.0, "payment_coins": 12, "customer_line": "来一份鸡蛋煎饼，不加其他小料。"},
	&"order.pancake.double_egg_plain": {"title": "双蛋煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.egg"], "sauce_stock_ids": [], "heat_preference": &"golden", "time_limit": 72.0, "payment_coins": 18, "customer_line": "来一份双蛋煎饼，别加其他小料。"},
	&"order.pancake.no_egg_plain": {"title": "无蛋煎饼", "ingredient_stock_ids": [], "sauce_stock_ids": [], "heat_preference": &"golden", "time_limit": 64.0, "payment_coins": 6, "customer_line": "来一份无蛋煎饼，什么小料和酱都不加。"},
	&"order.pancake.no_egg_secret": {"title": "秘制酱料煎饼", "ingredient_stock_ids": [], "sauce_stock_ids": [&"stock.pancake.sauce.sweet_flour"], "heat_preference": &"golden", "time_limit": 66.0, "payment_coins": 6, "customer_line": "先来一份刷秘制酱料的无蛋煎饼。"},
	&"order.pancake.egg_sweet": {"title": "鸡蛋秘制酱料煎饼", "ingredient_stock_ids": [&"stock.pancake.egg"], "sauce_stock_ids": [&"stock.pancake.sauce.sweet_flour"], "heat_preference": &"golden", "time_limit": 70.0, "payment_coins": 12, "customer_line": "鸡蛋煎饼刷秘制酱料就好。"},
	&"order.pancake.crisp": {"title": "薄脆煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.baocui"], "sauce_stock_ids": [&"stock.pancake.sauce.sweet_flour"], "heat_preference": &"golden", "time_limit": 72.0, "payment_coins": 15, "customer_line": "加薄脆，刷秘制酱料，不要葱。"},
	&"order.pancake.classic": {"title": "经典杂粮煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.scallion"], "sauce_stock_ids": [&"stock.pancake.sauce.sweet_flour"], "heat_preference": &"golden", "time_limit": 72.0, "payment_coins": 18, "customer_line": "来一份经典的，薄脆和葱花都要。"},
	&"order.pancake.double_egg": {"title": "双蛋薄脆煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.scallion"], "sauce_stock_ids": [&"stock.pancake.sauce.sweet_flour"], "heat_preference": &"golden", "time_limit": 78.0, "payment_coins": 24, "customer_line": "鸡蛋加双份，薄脆和葱花照常。"},
	&"order.pancake.chili_simple": {"title": "葱香薄脆煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.scallion"], "sauce_stock_ids": [&"stock.pancake.sauce.sweet_flour"], "heat_preference": &"golden", "time_limit": 74.0, "payment_coins": 18, "customer_line": "薄脆和葱花都要，刷秘制酱料。"},
	&"order.pancake.chili_ham": {"title": "火腿薄脆煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.ham_sausage"], "sauce_stock_ids": [&"stock.pancake.sauce.sweet_flour"], "heat_preference": &"well_done", "time_limit": 76.0, "payment_coins": 27, "customer_line": "火腿薄脆，刷秘制酱料，边缘煎香一点。"},
	&"order.pancake.double_sauce": {"title": "全料秘制煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.ham_sausage", &"stock.pancake.scallion"], "sauce_stock_ids": [&"stock.pancake.sauce.sweet_flour"], "heat_preference": &"golden", "time_limit": 82.0, "payment_coins": 30, "customer_line": "刷秘制酱料，配料给我放匀。"},
	&"order.pancake.scallion_light": {"title": "葱香少料煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.scallion"], "sauce_stock_ids": [&"stock.pancake.sauce.sweet_flour"], "heat_preference": &"light", "time_limit": 68.0, "payment_coins": 15, "customer_line": "这份不加薄脆，饼皮嫩一点就好。"},
	&"order.pancake.meat_floss_sweet": {"title": "秘制肉松煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.meat_floss", &"stock.pancake.scallion"], "sauce_stock_ids": [&"stock.pancake.sauce.sweet_flour"], "heat_preference": &"golden", "time_limit": 84.0, "payment_coins": 30, "customer_line": "肉松铺匀些，秘制酱料和葱花都要。"},
	&"order.pancake.double_meat_floss": {"title": "双份肉松煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.meat_floss", &"stock.pancake.meat_floss", &"stock.pancake.scallion"], "sauce_stock_ids": [&"stock.pancake.sauce.sweet_flour"], "heat_preference": &"golden", "time_limit": 86.0, "payment_coins": 42, "customer_line": "肉松请给我加两份，秘制酱料和葱花都要。"},
	&"order.pancake.extra_sweet_sauce": {"title": "多秘制酱料煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.scallion"], "sauce_stock_ids": [&"stock.pancake.sauce.sweet_flour", &"stock.pancake.sauce.sweet_flour"], "heat_preference": &"golden", "time_limit": 76.0, "payment_coins": 18, "customer_line": "秘制酱料加双份，薄脆和葱花都要。"},
	&"order.pancake.coriander": {"title": "香菜薄脆煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.coriander"], "sauce_stock_ids": [&"stock.pancake.sauce.sweet_flour"], "heat_preference": &"golden", "time_limit": 78.0, "payment_coins": 18, "customer_line": "薄脆和香菜都要，刷秘制酱料。"},
	&"order.pancake.tomato_ham": {"title": "火腿薄脆煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.ham_sausage"], "sauce_stock_ids": [&"stock.pancake.sauce.sweet_flour"], "heat_preference": &"golden", "time_limit": 78.0, "payment_coins": 27, "customer_line": "火腿薄脆，刷秘制酱料。"},
	&"order.pancake.youtiao_scallion": {"title": "油条葱香煎饼", "ingredient_stock_ids": [&"stock.pancake.egg", &"stock.pancake.youtiao", &"stock.pancake.scallion"], "sauce_stock_ids": [&"stock.pancake.sauce.sweet_flour"], "requires_recipe_ids": [&"recipe.youtiao.plain"], "heat_preference": &"golden", "time_limit": 72.0, "payment_coins": 24, "customer_line": "加一根油条、葱花和秘制酱料。"},
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
	var template := _copy_definition(PANCAKE_ORDER_TEMPLATES, template_id)
	if not template.is_empty():
		template["payment_coins"] = pancake_order_price(template)
	return template


static func pancake_order_price(template: Dictionary) -> int:
	var total := PANCAKE_BASE_SELL_PRICE
	for stock_id_variant in Array(template.get("ingredient_stock_ids", [])):
		var stock_id := StringName(stock_id_variant)
		total += int(PANCAKE_ADD_ON_SELL_PRICES.get(stock_id, 0))
	return total


static func soy_milk_sell_price(sugar_servings: int, _temperature_mode: StringName = &"room_temperature") -> int:
	var has_sugar := sugar_servings > 0
	if has_sugar:
		return int(SOY_MILK_SELL_PRICES[&"sugared"])
	return int(SOY_MILK_SELL_PRICES[&"plain"])

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
	if AREA_IDS.size() != 4 or PHYSICAL_AREA_IDS.size() != 4 or UNLOCK_AREA_IDS.size() != 4:
		errors.append("Four-area orders must each contain exactly four areas.")
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
		var required_tiers := [0] if device_id in [&"device.pancake_griddle", &"device.fresh_soy_milk_machine", &"device.packaged_drink_rack"] else [0, 1, 2]
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
		errors.append("Four-area balance and daily goal definitions must not be empty.")
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
		for ingredient_stock_id_variant in Array(template.get("ingredient_stock_ids", [])):
			var ingredient_stock_id := StringName(ingredient_stock_id_variant)
			if not PANCAKE_ADD_ON_SELL_PRICES.has(ingredient_stock_id):
				errors.append("Pancake order has no sell price for ingredient: %s" % ingredient_stock_id)
		if int(template.get("payment_coins", -1)) != pancake_order_price(template):
			errors.append("Pancake order payment does not match price rules: %s" % template_id)
	return errors

static func _copy_definition(source: Dictionary, definition_id: StringName) -> Dictionary:
	if not source.has(definition_id):
		return {}
	return source[definition_id].duplicate(true)
