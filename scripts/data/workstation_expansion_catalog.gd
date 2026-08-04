extends RefCounted

const TIER_BASIC := 0
const TIER_INTERMEDIATE := 1
const TIER_ADVANCED := 2

const DEVICE_SOY_MILK: StringName = &"soy_milk_machine"
const DEVICE_YOUTIAO: StringName = &"youtiao_fryer"
const DEVICE_EGG_WAFFLE: StringName = &"egg_waffle_machine"

const RECIPE_SOY_YELLOW: StringName = &"soy_milk.yellow_bean"
const RECIPE_SOY_RED: StringName = &"soy_milk.red_bean"
const RECIPE_SOY_BLACK: StringName = &"soy_milk.black_bean"
const RECIPE_YOUTIAO_PLAIN: StringName = &"youtiao.plain"
const RECIPE_YOUTIAO_SESAME: StringName = &"youtiao.sesame"
const RECIPE_YOUTIAO_SCALLION: StringName = &"youtiao.scallion"
const RECIPE_EGG_WAFFLE_PLAIN: StringName = &"egg_waffle.plain_batter"
const ADD_ON_STRAWBERRY: StringName = &"egg_waffle.add_on.strawberry_sauce"
const ADD_ON_CHOCOLATE: StringName = &"egg_waffle.add_on.chocolate_sauce"

const ACTION_ADD_WATER: StringName = &"add_water"
const ACTION_CLOSE_LID: StringName = &"close_lid"
const ACTION_CONTROL_TEMPERATURE: StringName = &"control_temperature"
const ACTION_OPEN_LID: StringName = &"open_lid"
const ACTION_DRAIN_OIL: StringName = &"drain_oil"

const TOOL_SPREADER_BASIC: StringName = &"tool.spreader.basic"
const TOOL_SPREADER_WIDE: StringName = &"tool.spreader.wide"
const TOOL_PRESS: StringName = &"tool.spreader.press_once"
const TOOL_SAUCE_BRUSH_MANUAL: StringName = &"tool.sauce_brush.manual"
const TOOL_SAUCE_BRUSH_AUTO: StringName = &"tool.sauce_brush.automatic"
const INGREDIENT_BOX_BASIC: StringName = &"capacity.ingredient_box.basic"
const INGREDIENT_BOX_INTERMEDIATE: StringName = &"capacity.ingredient_box.intermediate"
const INGREDIENT_BOX_ADVANCED: StringName = &"capacity.ingredient_box.advanced"

const UPGRADE_SOY_BASIC: StringName = &"equipment.soy_milk.basic"
const UPGRADE_SOY_INTERMEDIATE: StringName = &"equipment.soy_milk.intermediate"
const UPGRADE_SOY_ADVANCED: StringName = &"equipment.soy_milk.advanced"
const UPGRADE_YOUTIAO_BASIC: StringName = &"equipment.youtiao.basic"
const UPGRADE_YOUTIAO_INTERMEDIATE: StringName = &"equipment.youtiao.intermediate"
const UPGRADE_YOUTIAO_ADVANCED: StringName = &"equipment.youtiao.advanced"
const UPGRADE_EGG_WAFFLE_BASIC: StringName = &"equipment.egg_waffle.basic"
const UPGRADE_EGG_WAFFLE_INTERMEDIATE: StringName = &"equipment.egg_waffle.intermediate"
const UPGRADE_EGG_WAFFLE_ADVANCED: StringName = &"equipment.egg_waffle.advanced"

const AUTO_SOY_LOAD: StringName = &"automation.soy_milk.auto_load"
const AUTO_SOY_EXTRACT: StringName = &"automation.soy_milk.auto_extract"
const AUTO_YOUTIAO_LOAD: StringName = &"automation.youtiao.auto_load"
const AUTO_YOUTIAO_EXTRACT: StringName = &"automation.youtiao.auto_extract"
const AUTO_EGG_WAFFLE_LOAD: StringName = &"automation.egg_waffle.auto_load"
const AUTO_EGG_WAFFLE_OPEN: StringName = &"automation.egg_waffle.auto_open_lid"
const AUTO_EGG_WAFFLE_EXTRACT: StringName = &"automation.egg_waffle.auto_extract"

const UNLOCK_RECIPE_SOY_RED: StringName = &"recipe_unlock.soy_milk.red_bean"
const UNLOCK_RECIPE_SOY_BLACK: StringName = &"recipe_unlock.soy_milk.black_bean"
const UNLOCK_RECIPE_YOUTIAO_SESAME: StringName = &"recipe_unlock.youtiao.sesame"
const UNLOCK_RECIPE_YOUTIAO_SCALLION: StringName = &"recipe_unlock.youtiao.scallion"
const UNLOCK_ADD_ON_STRAWBERRY: StringName = &"recipe_unlock.egg_waffle.strawberry_sauce"
const UNLOCK_ADD_ON_CHOCOLATE: StringName = &"recipe_unlock.egg_waffle.chocolate_sauce"

const STOCK_EGG: StringName = &"egg"
const STOCK_BAOCUI: StringName = &"baocui"
const STOCK_HAM_SAUSAGE: StringName = &"ham_sausage"
const STOCK_SCALLION: StringName = &"scallion"
const STOCK_SOY_YELLOW: StringName = &"raw.soy.yellow_bean"
const STOCK_SOY_RED: StringName = &"raw.soy.red_bean"
const STOCK_SOY_BLACK: StringName = &"raw.soy.black_bean"
const STOCK_YOUTIAO_PLAIN: StringName = &"raw.youtiao.plain_dough"
const STOCK_YOUTIAO_SESAME: StringName = &"raw.youtiao.sesame_dough"
const STOCK_YOUTIAO_SCALLION: StringName = &"raw.youtiao.scallion_dough"
const STOCK_EGG_WAFFLE_BATTER: StringName = &"raw.egg_waffle.plain_batter"
const STOCK_STRAWBERRY_SAUCE: StringName = &"raw.egg_waffle.strawberry_sauce"
const STOCK_CHOCOLATE_SAUCE: StringName = &"raw.egg_waffle.chocolate_sauce"

# The decay rate remains a balancing parameter. The 0-100 range matches PancakeScorer.
const QUALITY_INITIAL := 100.0
const QUALITY_SAFE_SECONDS := 5.0
const QUALITY_DECAY_PER_SECOND_PLACEHOLDER := 2.0

const DEVICE_DEFINITIONS := {
	DEVICE_SOY_MILK: {
		"label": "豆浆机",
		"tiers": [
			{"capacity": 2, "duration_seconds": 16.0, "purchase_price": 30, "infinite_hold": true},
			{"capacity": 2, "duration_seconds": 12.0, "purchase_price": 24, "infinite_hold": true},
			{"capacity": 4, "duration_seconds": 12.0, "purchase_price": 54, "infinite_hold": true},
		],
		"required_before_start": [ACTION_ADD_WATER],
		"required_before_collect": [],
	},
	DEVICE_YOUTIAO: {
		"label": "炸油条机",
		"tiers": [
			{"capacity": 2, "duration_seconds": 12.0, "purchase_price": 60, "infinite_hold": false},
			{"capacity": 2, "duration_seconds": 9.0, "purchase_price": 48, "infinite_hold": false},
			{"capacity": 4, "duration_seconds": 9.0, "purchase_price": 84, "infinite_hold": true},
		],
		"required_before_start": [],
		"required_before_collect": [ACTION_DRAIN_OIL],
	},
	DEVICE_EGG_WAFFLE: {
		"label": "鸡蛋仔机器",
		"tiers": [
			{"capacity": 1, "duration_seconds": 20.0, "purchase_price": 90, "infinite_hold": false},
			{"capacity": 1, "duration_seconds": 15.0, "purchase_price": 66, "infinite_hold": false},
			{"capacity": 2, "duration_seconds": 15.0, "purchase_price": 108, "infinite_hold": true},
		],
		"required_before_start": [ACTION_CLOSE_LID, ACTION_CONTROL_TEMPERATURE],
		"required_before_collect": [ACTION_OPEN_LID],
	},
}

const RECIPE_DEFINITIONS := {
	RECIPE_SOY_YELLOW: {"kind": &"main", "device_id": DEVICE_SOY_MILK, "label": "黄豆豆浆", "stock_id": STOCK_SOY_YELLOW, "unlock_item": &""},
	RECIPE_SOY_RED: {"kind": &"main", "device_id": DEVICE_SOY_MILK, "label": "红豆豆浆", "stock_id": STOCK_SOY_RED, "unlock_item": UNLOCK_RECIPE_SOY_RED},
	RECIPE_SOY_BLACK: {"kind": &"main", "device_id": DEVICE_SOY_MILK, "label": "黑豆豆浆", "stock_id": STOCK_SOY_BLACK, "unlock_item": UNLOCK_RECIPE_SOY_BLACK},
	RECIPE_YOUTIAO_PLAIN: {"kind": &"main", "device_id": DEVICE_YOUTIAO, "label": "原味油条", "stock_id": STOCK_YOUTIAO_PLAIN, "unlock_item": &""},
	RECIPE_YOUTIAO_SESAME: {"kind": &"main", "device_id": DEVICE_YOUTIAO, "label": "芝麻油条", "stock_id": STOCK_YOUTIAO_SESAME, "unlock_item": UNLOCK_RECIPE_YOUTIAO_SESAME},
	RECIPE_YOUTIAO_SCALLION: {"kind": &"main", "device_id": DEVICE_YOUTIAO, "label": "葱香油条", "stock_id": STOCK_YOUTIAO_SCALLION, "unlock_item": UNLOCK_RECIPE_YOUTIAO_SCALLION},
	RECIPE_EGG_WAFFLE_PLAIN: {"kind": &"main", "device_id": DEVICE_EGG_WAFFLE, "label": "原味鸡蛋仔", "stock_id": STOCK_EGG_WAFFLE_BATTER, "unlock_item": &""},
	ADD_ON_STRAWBERRY: {"kind": &"add_on", "device_id": DEVICE_EGG_WAFFLE, "label": "草莓酱", "stock_id": STOCK_STRAWBERRY_SAUCE, "unlock_item": UNLOCK_ADD_ON_STRAWBERRY},
	ADD_ON_CHOCOLATE: {"kind": &"add_on", "device_id": DEVICE_EGG_WAFFLE, "label": "巧克力酱", "stock_id": STOCK_CHOCOLATE_SAUCE, "unlock_item": UNLOCK_ADD_ON_CHOCOLATE},
}

const ITEM_EFFECTS := {
	TOOL_SPREADER_BASIC: {"manual": true, "width_multiplier": 1.0},
	TOOL_SPREADER_WIDE: {"manual": true, "width_multiplier": 1.35},
	TOOL_PRESS: {"automatic_standard_spread": true, "uses_per_pancake": 1, "consumable": false},
	TOOL_SAUCE_BRUSH_MANUAL: {"manual": true},
	TOOL_SAUCE_BRUSH_AUTO: {"automatic_order_sauce": true, "still_consumes_sauce": true, "still_uses_time": true},
	INGREDIENT_BOX_BASIC: {"capacity": 6},
	INGREDIENT_BOX_INTERMEDIATE: {"capacity": 10},
	INGREDIENT_BOX_ADVANCED: {"capacity": 14},
	AUTO_SOY_LOAD: {"action": &"auto_load", "device_id": DEVICE_SOY_MILK, "consumes_input": true},
	AUTO_SOY_EXTRACT: {"action": &"auto_extract", "device_id": DEVICE_SOY_MILK},
	AUTO_YOUTIAO_LOAD: {"action": &"auto_load", "device_id": DEVICE_YOUTIAO, "consumes_input": true},
	AUTO_YOUTIAO_EXTRACT: {"action": &"auto_extract", "device_id": DEVICE_YOUTIAO},
	AUTO_EGG_WAFFLE_LOAD: {"action": &"auto_load", "device_id": DEVICE_EGG_WAFFLE, "consumes_input": true},
	AUTO_EGG_WAFFLE_OPEN: {"action": &"auto_open_lid", "device_id": DEVICE_EGG_WAFFLE},
	AUTO_EGG_WAFFLE_EXTRACT: {"action": &"auto_extract", "device_id": DEVICE_EGG_WAFFLE},
}

const PURCHASE_DEFINITIONS := {
	TOOL_SPREADER_WIDE: {"kind": &"owned_item", "price": 12, "requires_owned": TOOL_SPREADER_BASIC, "min_day": 2, "min_reputation": 10, "metric": &"lifetime_orders", "metric_value": 4},
	TOOL_PRESS: {"kind": &"owned_item", "price": 80, "requires_owned": TOOL_SPREADER_BASIC, "min_day": 15, "min_reputation": 240, "metric": &"manual_spread_good", "metric_value": 30},
	TOOL_SAUCE_BRUSH_AUTO: {"kind": &"owned_item", "price": 48, "requires_owned": TOOL_SAUCE_BRUSH_MANUAL, "min_day": 9, "min_reputation": 120, "metric": &"expanded_good", "metric_value": 14},
	INGREDIENT_BOX_INTERMEDIATE: {"kind": &"ingredient_box", "price": 30, "target_tier": TIER_INTERMEDIATE, "requires_owned": INGREDIENT_BOX_BASIC, "min_day": 6, "min_reputation": 70},
	INGREDIENT_BOX_ADVANCED: {"kind": &"ingredient_box", "price": 65, "target_tier": TIER_ADVANCED, "requires_owned": INGREDIENT_BOX_INTERMEDIATE, "min_day": 14, "min_reputation": 220},
	UPGRADE_SOY_BASIC: {"kind": &"equipment", "price": 30, "device_id": DEVICE_SOY_MILK, "target_tier": TIER_BASIC, "min_day": 4, "min_reputation": 35, "metric": &"lifetime_orders", "metric_value": 12},
	UPGRADE_SOY_INTERMEDIATE: {"kind": &"equipment", "price": 24, "device_id": DEVICE_SOY_MILK, "target_tier": TIER_INTERMEDIATE, "metric": &"soy_good", "metric_value": 4},
	UPGRADE_SOY_ADVANCED: {"kind": &"equipment", "price": 54, "device_id": DEVICE_SOY_MILK, "target_tier": TIER_ADVANCED, "min_day": 14, "min_reputation": 220},
	UPGRADE_YOUTIAO_BASIC: {"kind": &"equipment", "price": 60, "device_id": DEVICE_YOUTIAO, "target_tier": TIER_BASIC, "min_day": 7, "min_reputation": 85, "metric": &"lifetime_orders", "metric_value": 22},
	UPGRADE_YOUTIAO_INTERMEDIATE: {"kind": &"equipment", "price": 48, "device_id": DEVICE_YOUTIAO, "target_tier": TIER_INTERMEDIATE, "metric": &"youtiao_good", "metric_value": 4},
	UPGRADE_YOUTIAO_ADVANCED: {"kind": &"equipment", "price": 84, "device_id": DEVICE_YOUTIAO, "target_tier": TIER_ADVANCED, "min_day": 14, "min_reputation": 220},
	UPGRADE_EGG_WAFFLE_BASIC: {"kind": &"equipment", "price": 90, "device_id": DEVICE_EGG_WAFFLE, "target_tier": TIER_BASIC, "min_day": 10, "min_reputation": 140, "metric": &"soy_youtiao_good", "metric_value": 6},
	UPGRADE_EGG_WAFFLE_INTERMEDIATE: {"kind": &"equipment", "price": 66, "device_id": DEVICE_EGG_WAFFLE, "target_tier": TIER_INTERMEDIATE, "metric": &"egg_waffle_good", "metric_value": 8},
	UPGRADE_EGG_WAFFLE_ADVANCED: {"kind": &"equipment", "price": 108, "device_id": DEVICE_EGG_WAFFLE, "target_tier": TIER_ADVANCED, "min_day": 14, "min_reputation": 220},
	AUTO_SOY_LOAD: {"kind": &"owned_item", "price": 60, "requires_equipment": DEVICE_SOY_MILK},
	AUTO_SOY_EXTRACT: {"kind": &"owned_item", "price": 72, "requires_equipment": DEVICE_SOY_MILK},
	AUTO_YOUTIAO_LOAD: {"kind": &"owned_item", "price": 72, "requires_equipment": DEVICE_YOUTIAO},
	AUTO_YOUTIAO_EXTRACT: {"kind": &"owned_item", "price": 86, "requires_equipment": DEVICE_YOUTIAO},
	AUTO_EGG_WAFFLE_LOAD: {"kind": &"owned_item", "price": 96, "requires_equipment": DEVICE_EGG_WAFFLE},
	AUTO_EGG_WAFFLE_OPEN: {"kind": &"owned_item", "price": 70, "requires_equipment": DEVICE_EGG_WAFFLE},
	AUTO_EGG_WAFFLE_EXTRACT: {"kind": &"owned_item", "price": 112, "requires_equipment": DEVICE_EGG_WAFFLE},
	UNLOCK_RECIPE_SOY_RED: {"kind": &"owned_item", "price": 16, "requires_equipment": DEVICE_SOY_MILK},
	UNLOCK_RECIPE_SOY_BLACK: {"kind": &"owned_item", "price": 24, "requires_equipment": DEVICE_SOY_MILK},
	UNLOCK_RECIPE_YOUTIAO_SESAME: {"kind": &"owned_item", "price": 18, "requires_equipment": DEVICE_YOUTIAO},
	UNLOCK_RECIPE_YOUTIAO_SCALLION: {"kind": &"owned_item", "price": 24, "requires_equipment": DEVICE_YOUTIAO},
	UNLOCK_ADD_ON_STRAWBERRY: {"kind": &"owned_item", "price": 22, "requires_equipment": DEVICE_EGG_WAFFLE},
	UNLOCK_ADD_ON_CHOCOLATE: {"kind": &"owned_item", "price": 30, "requires_equipment": DEVICE_EGG_WAFFLE},
}

# Prices and timings are deliberately centralized placeholders pending economy calibration.
const REFILL_DEFINITIONS := {
	STOCK_EGG: {"unit_cost": 1, "unit_seconds": 1.20},
	STOCK_BAOCUI: {"unit_cost": 1, "unit_seconds": 1.35},
	STOCK_HAM_SAUSAGE: {"unit_cost": 2, "unit_seconds": 1.60},
	STOCK_SCALLION: {"unit_cost": 1, "unit_seconds": 1.00},
	STOCK_SOY_YELLOW: {"unit_cost": 1, "unit_seconds": 1.25},
	STOCK_SOY_RED: {"unit_cost": 2, "unit_seconds": 1.45},
	STOCK_SOY_BLACK: {"unit_cost": 2, "unit_seconds": 1.55},
	STOCK_YOUTIAO_PLAIN: {"unit_cost": 2, "unit_seconds": 1.50},
	STOCK_YOUTIAO_SESAME: {"unit_cost": 2, "unit_seconds": 1.65},
	STOCK_YOUTIAO_SCALLION: {"unit_cost": 2, "unit_seconds": 1.70},
	STOCK_EGG_WAFFLE_BATTER: {"unit_cost": 3, "unit_seconds": 1.80},
	STOCK_STRAWBERRY_SAUCE: {"unit_cost": 2, "unit_seconds": 1.25},
	STOCK_CHOCOLATE_SAUCE: {"unit_cost": 2, "unit_seconds": 1.25},
}


static func device_tier(device_id: StringName, tier: int) -> Dictionary:
	var device: Dictionary = DEVICE_DEFINITIONS.get(device_id, {})
	var tiers: Array = device.get("tiers", [])
	if tier < 0 or tier >= tiers.size():
		return {}
	var result: Dictionary = tiers[tier]
	result = result.duplicate(true)
	result["safe_seconds"] = QUALITY_SAFE_SECONDS
	result["initial_quality"] = QUALITY_INITIAL
	result["decay_per_second"] = QUALITY_DECAY_PER_SECOND_PLACEHOLDER
	return result


static func device_definition(device_id: StringName) -> Dictionary:
	return Dictionary(DEVICE_DEFINITIONS.get(device_id, {})).duplicate(true)


static func recipe_definition(recipe_id: StringName) -> Dictionary:
	return Dictionary(RECIPE_DEFINITIONS.get(recipe_id, {})).duplicate(true)


static func main_recipe_ids(device_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for recipe_id in RECIPE_DEFINITIONS:
		var definition: Dictionary = RECIPE_DEFINITIONS[recipe_id]
		if definition.get("device_id", &"") == device_id and definition.get("kind", &"") == &"main":
			result.append(recipe_id)
	return result


static func purchase_definition(item_id: StringName) -> Dictionary:
	return Dictionary(PURCHASE_DEFINITIONS.get(item_id, {})).duplicate(true)


static func item_effect(item_id: StringName) -> Dictionary:
	return Dictionary(ITEM_EFFECTS.get(item_id, {})).duplicate(true)


static func refill_definition(stock_id: StringName) -> Dictionary:
	return Dictionary(REFILL_DEFINITIONS.get(stock_id, {})).duplicate(true)


static func stock_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for stock_id in REFILL_DEFINITIONS:
		result.append(stock_id)
	return result


static func automation_for(device_id: StringName, action: StringName) -> StringName:
	for item_id in ITEM_EFFECTS:
		var effect: Dictionary = ITEM_EFFECTS[item_id]
		if effect.get("device_id", &"") == device_id and effect.get("action", &"") == action:
			return item_id
	return &""
