class_name NightMarketCatalog
extends RefCounted

const CHAPTER_ID := &"chapter.night_market"
const NOODLE_CHAPTER_ID := &"chapter.noodle_shop"
const AREA_ID := &"area.night_market"

const LINE_GRILL := &"grill"
const LINE_FRYER := &"fryer"

const ZONE_LOW := &"low"
const ZONE_MEDIUM := &"medium"
const ZONE_HIGH := &"high"
const HEAT_RATES := {ZONE_LOW: 4.0, ZONE_MEDIUM: 7.0, ZONE_HIGH: 11.0}
const ZONE_SLOT_INDICES := {
	ZONE_LOW: [0, 1],
	ZONE_MEDIUM: [2, 3],
	ZONE_HIGH: [4, 5],
}

const ITEM_LAMB := &"item.night.grill.lamb"
const ITEM_CHICKEN := &"item.night.grill.chicken"
const ITEM_LOTUS := &"item.night.fryer.lotus"
const ITEM_POTATO := &"item.night.fryer.potato"

const SEASONING_CUMIN := &"seasoning.night.cumin"
const SEASONING_CHILI := &"seasoning.night.chili"
const SEASONING_SALT_PEPPER := &"seasoning.night.salt_pepper"
const SEASONING_PLUM := &"seasoning.night.plum"

const RECIPE_TUTORIAL := &"recipe.night.tutorial_combo"
const RECIPE_LAMB := &"recipe.night.grill.lamb"
const RECIPE_LOTUS := &"recipe.night.fryer.lotus"
const RECIPE_BASIC_COMBO := &"recipe.night.combo.basic"
const RECIPE_CHICKEN := &"recipe.night.grill.chicken"
const RECIPE_POTATO := &"recipe.night.fryer.potato"
const RECIPE_PREMIUM_COMBO := &"recipe.night.combo.premium"

const STOCK_CHICKEN := &"stock.night.chicken"
const STOCK_POTATO := &"stock.night.potato"

const GROWTH_CHICKEN := &"growth.night.recipe.chicken"
const GROWTH_EMBER_BAFFLE := &"growth.night.tool.ember_baffle"
const GROWTH_POTATO := &"growth.night.recipe.potato"
const GROWTH_THERMOSTATIC_FRYER := &"growth.night.tool.thermostatic_fryer"

const ITEM_DEFINITIONS := {
	ITEM_LAMB: {
		"label": "羊肉串", "line": LINE_GRILL, "seasoning_id": SEASONING_CUMIN,
		"target_min": 45.0, "target_max": 68.0, "ideal_zone": ZONE_MEDIUM, "ideal_seconds": 15.0,
	},
	ITEM_CHICKEN: {
		"label": "鸡肉串", "line": LINE_GRILL, "seasoning_id": SEASONING_CHILI,
		"target_min": 48.0, "target_max": 70.0, "ideal_zone": ZONE_HIGH, "ideal_seconds": 12.0,
	},
	ITEM_LOTUS: {
		"label": "炸藕片", "line": LINE_FRYER, "seasoning_id": SEASONING_SALT_PEPPER,
		"cook_min": 4.5, "cook_max": 7.0, "temp_min": 170.0, "temp_max": 185.0,
		"drain_min": 0.8, "drain_max": 1.8, "ideal_seconds": 7.0,
	},
	ITEM_POTATO: {
		"label": "炸薯片", "line": LINE_FRYER, "seasoning_id": SEASONING_PLUM,
		"cook_min": 3.8, "cook_max": 6.0, "temp_min": 165.0, "temp_max": 180.0,
		"drain_min": 1.2, "drain_max": 2.2, "ideal_seconds": 6.5,
	},
}

const RECIPE_DEFINITIONS := {
	RECIPE_TUTORIAL: {
		"label": "新手双拼", "sell_price": 18, "time_limit": 60.0,
		"item_ids": [ITEM_LAMB, ITEM_LOTUS],
	},
	RECIPE_LAMB: {
		"label": "孜然羊肉串", "sell_price": 12, "time_limit": 38.0,
		"item_ids": [ITEM_LAMB],
	},
	RECIPE_LOTUS: {
		"label": "椒盐炸藕片", "sell_price": 10, "time_limit": 36.0,
		"item_ids": [ITEM_LOTUS],
	},
	RECIPE_BASIC_COMBO: {
		"label": "灯火基础双拼", "sell_price": 22, "time_limit": 48.0,
		"item_ids": [ITEM_LAMB, ITEM_LOTUS],
	},
	RECIPE_CHICKEN: {
		"label": "香辣鸡肉串", "sell_price": 16, "time_limit": 38.0,
		"item_ids": [ITEM_CHICKEN],
	},
	RECIPE_POTATO: {
		"label": "甘梅炸薯片", "sell_price": 14, "time_limit": 36.0,
		"item_ids": [ITEM_POTATO],
	},
	RECIPE_PREMIUM_COMBO: {
		"label": "灯火招牌双拼", "sell_price": 28, "time_limit": 52.0,
		"item_ids": [ITEM_CHICKEN, ITEM_POTATO],
	},
}

const STOCK_DEFINITIONS := {
	STOCK_CHICKEN: {"label": "鸡肉串", "unit_cost": 2, "capacity": 6, "item_id": ITEM_CHICKEN},
	STOCK_POTATO: {"label": "薯片串", "unit_cost": 2, "capacity": 6, "item_id": ITEM_POTATO},
}

const GROWTH_DEFINITIONS := {
	GROWTH_CHICKEN: {
		"label": "香辣鸡肉串配方", "price": 12, "unlock_recipe_id": RECIPE_CHICKEN,
		"requires_growth_ids": [],
	},
	GROWTH_EMBER_BAFFLE: {
		"label": "余火挡板", "price": 28, "requires_growth_ids": [],
	},
	GROWTH_POTATO: {
		"label": "甘梅炸薯片配方", "price": 20, "unlock_recipe_id": RECIPE_POTATO,
		"requires_growth_ids": [GROWTH_CHICKEN],
	},
	GROWTH_THERMOSTATIC_FRYER: {
		"label": "恒温炸锅", "price": 44, "requires_growth_ids": [],
	},
}

const GROWTH_DISPLAY_ORDER: Array[StringName] = [
	GROWTH_CHICKEN,
	GROWTH_EMBER_BAFFLE,
	GROWTH_POTATO,
	GROWTH_THERMOSTATIC_FRYER,
]


static func item(item_id: StringName) -> Dictionary:
	return Dictionary(ITEM_DEFINITIONS.get(item_id, {})).duplicate(true)


static func recipe(recipe_id: StringName) -> Dictionary:
	return Dictionary(RECIPE_DEFINITIONS.get(recipe_id, {})).duplicate(true)


static func stock(stock_id: StringName) -> Dictionary:
	return Dictionary(STOCK_DEFINITIONS.get(stock_id, {})).duplicate(true)


static func growth(growth_id: StringName) -> Dictionary:
	return Dictionary(GROWTH_DEFINITIONS.get(growth_id, {})).duplicate(true)


static func zone_for_slot(slot_index: int) -> StringName:
	if slot_index < 2:
		return ZONE_LOW
	if slot_index < 4:
		return ZONE_MEDIUM
	return ZONE_HIGH


static func item_label(item_id: StringName) -> String:
	return str(item(item_id).get("label", str(item_id)))


static func seasoning_label(seasoning_id: StringName) -> String:
	return {
		SEASONING_CUMIN: "孜然",
		SEASONING_CHILI: "辣椒面",
		SEASONING_SALT_PEPPER: "椒盐",
		SEASONING_PLUM: "甘梅粉",
	}.get(seasoning_id, str(seasoning_id))
