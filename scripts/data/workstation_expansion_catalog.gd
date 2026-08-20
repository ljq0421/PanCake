extends RefCounted

# The catalog intentionally contains only the remaining five-zone roadmap data.
# Egg-waffle equipment and its recipes were retired with the opening-workstation redesign.
const TIER_BASIC := 0
const TIER_INTERMEDIATE := 1
const TIER_ADVANCED := 2

const DEVICE_SOY_MILK: StringName = &"soy_milk_machine"
const DEVICE_YOUTIAO: StringName = &"youtiao_fryer"

const RECIPE_SOY_YELLOW: StringName = &"soy_milk.yellow_bean"
const RECIPE_SOY_RED: StringName = &"soy_milk.red_bean"
const RECIPE_SOY_BLACK: StringName = &"soy_milk.black_bean"
const RECIPE_YOUTIAO_PLAIN: StringName = &"youtiao.plain"

const ACTION_ADD_WATER: StringName = &"add_water"
const ACTION_DRAIN_OIL: StringName = &"drain_oil"

const TOOL_SPREADER_BASIC: StringName = &"tool.spreader.basic"
const TOOL_SPREADER_WIDE: StringName = &"tool.spreader.wide"
const WIDE_SPREADER_WIDTH_MULTIPLIER := 1.65
const TOOL_PRESS: StringName = &"tool.spreader.press_once"
const TOOL_SAUCE_BRUSH_MANUAL: StringName = &"tool.sauce_brush.manual"
const TOOL_SAUCE_BRUSH_AUTO: StringName = &"tool.sauce_brush.automatic"
const INGREDIENT_BOX_BASIC: StringName = &"capacity.ingredient_box.basic"
const INGREDIENT_BOX_INTERMEDIATE: StringName = &"capacity.ingredient_box.intermediate"
const INGREDIENT_BOX_ADVANCED: StringName = &"capacity.ingredient_box.advanced"
const UNLOCK_INGREDIENT_HAM: StringName = &"ingredient_unlock.ham_sausage"
const UNLOCK_INGREDIENT_MEAT_FLOSS: StringName = &"ingredient_unlock.meat_floss"
const UNLOCK_INGREDIENT_PORK_TENDERLOIN: StringName = &"ingredient_unlock.pork_tenderloin"
const STALL_FIXED: StringName = &"stall.fixed_shop"

const UPGRADE_SOY_BASIC: StringName = &"equipment.soy_milk.basic"
const UPGRADE_SOY_INTERMEDIATE: StringName = &"equipment.soy_milk.intermediate"
const UPGRADE_SOY_ADVANCED: StringName = &"equipment.soy_milk.advanced"
const UPGRADE_YOUTIAO_BASIC: StringName = &"equipment.youtiao.basic"
const UPGRADE_YOUTIAO_INTERMEDIATE: StringName = &"equipment.youtiao.intermediate"
const UPGRADE_YOUTIAO_ADVANCED: StringName = &"equipment.youtiao.advanced"

const AUTO_SOY_LOAD: StringName = &"automation.soy_milk.auto_load"
const AUTO_SOY_EXTRACT: StringName = &"automation.soy_milk.auto_extract"

const UNLOCK_RECIPE_SOY_RED: StringName = &"recipe_unlock.soy_milk.red_bean"
const UNLOCK_RECIPE_SOY_BLACK: StringName = &"recipe_unlock.soy_milk.black_bean"

const STOCK_EGG: StringName = &"egg"
const STOCK_BAOCUI: StringName = &"baocui"
const STOCK_HAM_SAUSAGE: StringName = &"ham_sausage"
const STOCK_SCALLION: StringName = &"scallion"
const STOCK_MEAT_FLOSS: StringName = &"meat_floss"
const STOCK_PORK_TENDERLOIN: StringName = &"pork_tenderloin"
const STOCK_SOY_YELLOW: StringName = &"raw.soy.yellow_bean"
const STOCK_SOY_RED: StringName = &"raw.soy.red_bean"
const STOCK_SOY_BLACK: StringName = &"raw.soy.black_bean"
const STOCK_YOUTIAO_PLAIN: StringName = &"raw.youtiao.plain_dough"

const QUALITY_INITIAL := 100.0
const QUALITY_SAFE_SECONDS := 5.0
const QUALITY_DECAY_PER_SECOND_PLACEHOLDER := 2.0

const DEVICE_DEFINITIONS := {
	DEVICE_SOY_MILK: {
		"label": "现磨豆浆机",
		"tiers": [
			{"capacity": 2, "duration_seconds": 16.0, "purchase_price": 30, "infinite_hold": true},
			{"capacity": 2, "duration_seconds": 12.0, "purchase_price": 24, "infinite_hold": true},
			{"capacity": 4, "duration_seconds": 12.0, "purchase_price": 54, "infinite_hold": true},
		],
		"required_before_start": [ACTION_ADD_WATER],
		"required_before_collect": [],
	},
	DEVICE_YOUTIAO: {
		"label": "油条锅",
		"tiers": [
			{"capacity": 4, "duration_seconds": 10.0, "purchase_price": 60, "infinite_hold": false},
			{"capacity": 6, "duration_seconds": 8.0, "purchase_price": 48, "infinite_hold": false},
			{"capacity": 8, "duration_seconds": 6.0, "purchase_price": 84, "infinite_hold": true},
		],
		"required_before_start": [],
		"required_before_collect": [ACTION_DRAIN_OIL],
	},
}

const RECIPE_DEFINITIONS := {
	RECIPE_SOY_YELLOW: {"kind": &"main", "device_id": DEVICE_SOY_MILK, "label": "黄豆豆浆", "stock_id": STOCK_SOY_YELLOW, "unlock_item": &""},
	RECIPE_SOY_RED: {"kind": &"main", "device_id": DEVICE_SOY_MILK, "label": "红豆豆浆", "stock_id": STOCK_SOY_RED, "unlock_item": UNLOCK_RECIPE_SOY_RED},
	RECIPE_SOY_BLACK: {"kind": &"main", "device_id": DEVICE_SOY_MILK, "label": "黑豆豆浆", "stock_id": STOCK_SOY_BLACK, "unlock_item": UNLOCK_RECIPE_SOY_BLACK},
	RECIPE_YOUTIAO_PLAIN: {"kind": &"main", "device_id": DEVICE_YOUTIAO, "label": "油条", "stock_id": STOCK_YOUTIAO_PLAIN, "unlock_item": &""},
}

const ITEM_EFFECTS := {
	TOOL_SPREADER_BASIC: {"manual": true, "width_multiplier": 1.0},
	TOOL_SPREADER_WIDE: {"manual": true, "width_multiplier": WIDE_SPREADER_WIDTH_MULTIPLIER},
	TOOL_PRESS: {"automatic_standard_spread": true, "uses_per_pancake": 1, "consumable": false},
	TOOL_SAUCE_BRUSH_MANUAL: {"manual": true},
	TOOL_SAUCE_BRUSH_AUTO: {"automatic_order_sauce": true, "still_consumes_sauce": true, "still_uses_time": true},
	INGREDIENT_BOX_BASIC: {"capacity": 6},
	INGREDIENT_BOX_INTERMEDIATE: {"capacity": 10},
	INGREDIENT_BOX_ADVANCED: {"capacity": 14},
	AUTO_SOY_LOAD: {"action": &"auto_load", "device_id": DEVICE_SOY_MILK, "consumes_input": true},
	AUTO_SOY_EXTRACT: {"action": &"auto_extract", "device_id": DEVICE_SOY_MILK},
}

const PURCHASE_DEFINITIONS := {
	TOOL_SPREADER_WIDE: {"kind": &"owned_item", "price": 12, "requires_owned": TOOL_SPREADER_BASIC, "min_day": 2, "min_reputation": 10, "metric": &"lifetime_orders", "metric_value": 4},
	TOOL_PRESS: {"kind": &"owned_item", "price": 80, "requires_owned": TOOL_SPREADER_BASIC, "min_day": 15, "min_reputation": 240, "metric": &"manual_spread_good", "metric_value": 30},
	TOOL_SAUCE_BRUSH_AUTO: {"kind": &"owned_item", "price": 48, "requires_owned": TOOL_SAUCE_BRUSH_MANUAL, "min_day": 9, "min_reputation": 120, "metric": &"expanded_good", "metric_value": 14},
	INGREDIENT_BOX_INTERMEDIATE: {"kind": &"ingredient_box", "price": 30, "target_tier": TIER_INTERMEDIATE, "requires_owned": INGREDIENT_BOX_BASIC, "min_day": 6, "min_reputation": 70},
	INGREDIENT_BOX_ADVANCED: {"kind": &"ingredient_box", "price": 65, "target_tier": TIER_ADVANCED, "requires_owned": INGREDIENT_BOX_INTERMEDIATE, "min_day": 14, "min_reputation": 220},
	UNLOCK_INGREDIENT_HAM: {"kind": &"ingredient_unlock", "price": 18, "min_day": 3, "min_reputation": 20, "metric": &"average_score", "metric_value": 65},
	UNLOCK_INGREDIENT_MEAT_FLOSS: {"kind": &"ingredient_unlock", "price": 32, "min_day": 8, "metric": &"youtiao_good", "metric_value": 4},
	UNLOCK_INGREDIENT_PORK_TENDERLOIN: {"kind": &"ingredient_unlock", "price": 50, "min_day": 9, "metric": &"expanded_good", "metric_value": 14},
	STALL_FIXED: {"kind": &"stall", "price": 120, "target_tier": 1, "min_day": 14, "min_reputation": 220, "metric": &"all_equipment_good", "metric_value": 2},
	UPGRADE_SOY_BASIC: {"kind": &"equipment", "price": 30, "device_id": DEVICE_SOY_MILK, "target_tier": TIER_BASIC, "min_day": 4, "min_reputation": 35, "metric": &"lifetime_orders", "metric_value": 12},
	UPGRADE_SOY_INTERMEDIATE: {"kind": &"equipment", "price": 24, "device_id": DEVICE_SOY_MILK, "target_tier": TIER_INTERMEDIATE, "metric": &"soy_good", "metric_value": 4},
	UPGRADE_SOY_ADVANCED: {"kind": &"equipment", "price": 54, "device_id": DEVICE_SOY_MILK, "target_tier": TIER_ADVANCED, "min_day": 14, "min_reputation": 220},
	UPGRADE_YOUTIAO_BASIC: {"kind": &"equipment", "price": 60, "device_id": DEVICE_YOUTIAO, "target_tier": TIER_BASIC, "min_day": 7, "min_reputation": 85, "metric": &"lifetime_orders", "metric_value": 22},
	UPGRADE_YOUTIAO_INTERMEDIATE: {"kind": &"equipment", "price": 48, "device_id": DEVICE_YOUTIAO, "target_tier": TIER_INTERMEDIATE, "metric": &"youtiao_good", "metric_value": 4},
	UPGRADE_YOUTIAO_ADVANCED: {"kind": &"equipment", "price": 84, "device_id": DEVICE_YOUTIAO, "target_tier": TIER_ADVANCED, "min_day": 14, "min_reputation": 220},
	AUTO_SOY_LOAD: {"kind": &"owned_item", "price": 60, "requires_equipment": DEVICE_SOY_MILK},
	AUTO_SOY_EXTRACT: {"kind": &"owned_item", "price": 72, "requires_equipment": DEVICE_SOY_MILK},
	UNLOCK_RECIPE_SOY_RED: {"kind": &"owned_item", "price": 16, "requires_equipment": DEVICE_SOY_MILK},
	UNLOCK_RECIPE_SOY_BLACK: {"kind": &"owned_item", "price": 24, "requires_equipment": DEVICE_SOY_MILK},
}

const PURCHASE_PRESENTATION := {
	TOOL_SPREADER_WIDE: {"label": "宽头摊饼器", "category": "工具", "description": "手动摊面有效宽度 +65%；仍需连续绕圈摊开。"},
	TOOL_PRESS: {"label": "单次压饼器", "category": "工具", "description": "倒入面糊后，每张饼可点击一次形成完整饼皮并进入放鸡蛋步骤。"},
	TOOL_SAUCE_BRUSH_AUTO: {"label": "自动刷酱", "category": "工具", "description": "点击酱料后自动均匀刷好。"},
	UPGRADE_SOY_BASIC: {"label": "现磨豆浆机", "category": "设备", "description": "解锁豆浆区。"},
	UPGRADE_YOUTIAO_BASIC: {"label": "油条锅", "category": "设备", "description": "解锁油条区。"},
}

const REFILL_DEFINITIONS := {
	STOCK_EGG: {"unit_cost": 1, "unit_seconds": 0.20},
	STOCK_BAOCUI: {"unit_cost": 1, "unit_seconds": 0.225},
	STOCK_HAM_SAUSAGE: {"unit_cost": 2, "unit_seconds": 0.2666667},
	STOCK_SCALLION: {"unit_cost": 1, "unit_seconds": 0.1666667},
	STOCK_MEAT_FLOSS: {"unit_cost": 2, "unit_seconds": 0.24},
	STOCK_PORK_TENDERLOIN: {"unit_cost": 3, "unit_seconds": 0.28},
	STOCK_SOY_YELLOW: {"unit_cost": 1, "unit_seconds": 1.25},
	STOCK_SOY_RED: {"unit_cost": 2, "unit_seconds": 1.45},
	STOCK_SOY_BLACK: {"unit_cost": 2, "unit_seconds": 1.55},
	STOCK_YOUTIAO_PLAIN: {"unit_cost": 2, "unit_seconds": 0.25},
}

static func device_tier(device_id: StringName, tier: int) -> Dictionary:
	var device: Dictionary = DEVICE_DEFINITIONS.get(device_id, {})
	var tiers: Array = device.get("tiers", [])
	if tier < 0 or tier >= tiers.size():
		return {}
	var result: Dictionary = tiers[tier].duplicate(true)
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

static func purchase_presentation(item_id: StringName) -> Dictionary:
	return Dictionary(PURCHASE_PRESENTATION.get(item_id, {"label": str(item_id), "category": "成长", "description": "下个营业日生效。"})).duplicate(true)

static func purchase_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for item_id in PURCHASE_DEFINITIONS:
		result.append(item_id)
	return result

static func item_effect(item_id: StringName) -> Dictionary:
	return Dictionary(ITEM_EFFECTS.get(item_id, {})).duplicate(true)

static func refill_definition(stock_id: StringName) -> Dictionary:
	return Dictionary(REFILL_DEFINITIONS.get(stock_id, {})).duplicate(true)

static func stock_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for stock_id in REFILL_DEFINITIONS:
		result.append(stock_id)
	return result

static func starter_ingredient_ids() -> Array[StringName]:
	return [STOCK_EGG, STOCK_BAOCUI, STOCK_SCALLION]

static func ingredient_unlock_item(stock_id: StringName) -> StringName:
	return {
		STOCK_HAM_SAUSAGE: UNLOCK_INGREDIENT_HAM,
		STOCK_MEAT_FLOSS: UNLOCK_INGREDIENT_MEAT_FLOSS,
		STOCK_PORK_TENDERLOIN: UNLOCK_INGREDIENT_PORK_TENDERLOIN,
	}.get(stock_id, &"")

static func automation_for(device_id: StringName, action: StringName) -> StringName:
	for item_id in ITEM_EFFECTS:
		var effect: Dictionary = ITEM_EFFECTS[item_id]
		if effect.get("device_id", &"") == device_id and effect.get("action", &"") == action:
			return item_id
	return &""
