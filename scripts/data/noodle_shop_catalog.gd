class_name NoodleShopCatalog
extends RefCounted

const CHAPTER_ID := &"chapter.noodle_shop"
const BREAKFAST_CHAPTER_ID := &"chapter.breakfast_stall"
const AREA_ID := &"area.noodle_shop"

const TARGET_BATCH_COUNT := 6
const MIN_LIFT_BATCH_COUNT := 4
const MIN_STROKE_DISTANCE := 90.0
const THICK_SPEED_MAX := 520.0
const STANDARD_SPEED_MAX := 900.0

const RECIPE_CLEAR := &"recipe.noodle.clear_broth"
const RECIPE_TOMATO := &"recipe.noodle.tomato_egg"
const RECIPE_ZHAJIANG := &"recipe.noodle.zhajiang"

const PRODUCT_CLEAR := &"product.noodle.clear_broth"
const PRODUCT_TOMATO := &"product.noodle.tomato_egg"
const PRODUCT_ZHAJIANG := &"product.noodle.zhajiang"

const STOCK_TOMATO := &"stock.noodle.tomato_egg"
const STOCK_ZHAJIANG := &"stock.noodle.zhajiang"

const GROWTH_TOMATO := &"growth.noodle.recipe.tomato_egg"
const GROWTH_SHARP_KNIFE := &"growth.noodle.tool.sharp_knife"
const GROWTH_ZHAJIANG := &"growth.noodle.recipe.zhajiang"
const GROWTH_STABLE_BASKET := &"growth.noodle.tool.stable_basket"

const RECIPE_DEFINITIONS := {
	RECIPE_CLEAR: {
		"label": "清汤刀削面",
		"product_id": PRODUCT_CLEAR,
		"profile_id": &"standard",
		"broth_id": &"broth.clear",
		"topping_ids": [&"topping.scallion"],
		"drain_min": 0.4,
		"drain_max": 1.0,
		"time_limit": 28.0,
		"sell_price": 10,
		"stock_ids": [],
	},
	RECIPE_TOMATO: {
		"label": "番茄鸡蛋刀削面",
		"product_id": PRODUCT_TOMATO,
		"profile_id": &"thin",
		"broth_id": &"broth.tomato",
		"topping_ids": [&"topping.tomato_egg"],
		"drain_min": 0.4,
		"drain_max": 1.0,
		"time_limit": 32.0,
		"sell_price": 16,
		"stock_ids": [STOCK_TOMATO],
	},
	RECIPE_ZHAJIANG: {
		"label": "炸酱刀削面",
		"product_id": PRODUCT_ZHAJIANG,
		"profile_id": &"thick",
		"broth_id": &"broth.none",
		"topping_ids": [&"topping.zhajiang", &"topping.cucumber"],
		"drain_min": 1.2,
		"drain_max": 2.0,
		"time_limit": 36.0,
		"sell_price": 22,
		"stock_ids": [STOCK_ZHAJIANG],
	},
}

const STOCK_DEFINITIONS := {
	STOCK_TOMATO: {"label": "番茄鸡蛋浇头", "unit_cost": 2, "capacity": 6},
	STOCK_ZHAJIANG: {"label": "炸酱", "unit_cost": 3, "capacity": 6},
}

const GROWTH_DEFINITIONS := {
	GROWTH_TOMATO: {
		"label": "番茄鸡蛋配方",
		"price": 10,
		"unlock_recipe_id": RECIPE_TOMATO,
		"requires_growth_ids": [],
	},
	GROWTH_SHARP_KNIFE: {
		"label": "锋利削面刀",
		"price": 30,
		"requires_growth_ids": [],
	},
	GROWTH_ZHAJIANG: {
		"label": "炸酱配方",
		"price": 24,
		"unlock_recipe_id": RECIPE_ZHAJIANG,
		"requires_growth_ids": [GROWTH_TOMATO],
	},
	GROWTH_STABLE_BASKET: {
		"label": "稳定面篮",
		"price": 45,
		"requires_growth_ids": [],
	},
}

const GROWTH_DISPLAY_ORDER: Array[StringName] = [
	GROWTH_TOMATO,
	GROWTH_SHARP_KNIFE,
	GROWTH_ZHAJIANG,
	GROWTH_STABLE_BASKET,
]

static func recipe(recipe_id: StringName) -> Dictionary:
	return Dictionary(RECIPE_DEFINITIONS.get(recipe_id, {})).duplicate(true)


static func stock(stock_id: StringName) -> Dictionary:
	return Dictionary(STOCK_DEFINITIONS.get(stock_id, {})).duplicate(true)


static func growth(growth_id: StringName) -> Dictionary:
	return Dictionary(GROWTH_DEFINITIONS.get(growth_id, {})).duplicate(true)


static func thickness_for_speed(speed: float) -> StringName:
	if speed < THICK_SPEED_MAX:
		return &"thick"
	if speed <= STANDARD_SPEED_MAX:
		return &"standard"
	return &"thin"


static func cook_window(profile_id: StringName, stable_basket: bool = false) -> Vector2:
	var window := Vector2(3.0, 7.0)
	if profile_id == &"thin":
		window = Vector2(2.0, 5.0)
	elif profile_id == &"thick":
		window = Vector2(4.0, 9.0)
	if stable_basket:
		window.y += 0.8
	return window


static func recipe_ids() -> Array[StringName]:
	return [RECIPE_CLEAR, RECIPE_TOMATO, RECIPE_ZHAJIANG]

