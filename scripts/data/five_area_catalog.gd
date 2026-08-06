class_name FiveAreaCatalog
extends RefCounted

## Static five-area source of truth.  Runtime services own availability, stock
## counts and pending purchases; this catalog intentionally contains no save/UI
## state.

const BALANCE_VERSION := 1

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
	&"device.pancake_griddle": {"area_id": &"area.pancake", "tiers": [{"tier": 1, "label": "基础煎饼鏊子"}, {"tier": 2, "label": "双温煎饼鏊子"}]},
	&"device.packaged_drink_heater": {"area_id": &"area.packaged_drink", "tiers": [{"tier": 1, "label": "基础饮品机"}, {"tier": 2, "label": "恒温饮品机"}]},
	&"device.youtiao_fryer": {"area_id": &"area.youtiao", "tiers": [{"tier": 1, "label": "基础油锅"}, {"tier": 2, "label": "双槽油锅"}]},
	&"device.fresh_soy_milk_machine": {"area_id": &"area.fresh_soy_milk", "tiers": [{"tier": 1, "label": "基础豆浆机"}, {"tier": 2, "label": "快速豆浆机"}]},
	&"device.steamer": {"area_id": &"area.steamer", "tiers": [{"tier": 1, "label": "基础蒸箱"}, {"tier": 2, "label": "双层蒸箱"}]},
}

## Slot 11-15 are intentionally reservations, not inventory.  Sauce inventory
## is a countertop input and must never be assigned a material slot.
const MATERIAL_SLOT_DEFINITIONS := {
	&"slot.01": {"index": 1, "area_id": &"area.fresh_soy_milk", "kind": &"stock", "stock_id": &"stock.fresh_soy_milk.yellow_bean"},
	&"slot.02": {"index": 2, "area_id": &"area.fresh_soy_milk", "kind": &"stock", "stock_id": &"stock.fresh_soy_milk.black_bean"},
	&"slot.03": {"index": 3, "area_id": &"area.youtiao", "kind": &"stock", "stock_id": &"stock.youtiao.plain_dough"},
	&"slot.04": {"index": 4, "area_id": &"area.pancake", "kind": &"stock", "stock_id": &"stock.pancake.meat_floss"},
	&"slot.05": {"index": 5, "area_id": &"area.pancake", "kind": &"stock", "stock_id": &"stock.pancake.ham_sausage"},
	&"slot.06": {"index": 6, "area_id": &"area.pancake", "kind": &"stock", "stock_id": &"stock.pancake.coriander"},
	&"slot.07": {"index": 7, "area_id": &"area.pancake", "kind": &"stock", "stock_id": &"stock.pancake.egg"},
	&"slot.08": {"index": 8, "area_id": &"area.pancake", "kind": &"stock", "stock_id": &"stock.pancake.baocui"},
	&"slot.09": {"index": 9, "area_id": &"area.pancake", "kind": &"stock", "stock_id": &"stock.pancake.scallion"},
	&"slot.10": {"index": 10, "area_id": &"area.pancake", "kind": &"stock", "stock_id": &"stock.pancake.pork_tenderloin"},
	&"slot.11": {"index": 11, "area_id": &"area.pancake", "kind": &"reserved", "reservation_id": &"reservation.pancake.future_01"},
	&"slot.12": {"index": 12, "area_id": &"area.pancake", "kind": &"reserved", "reservation_id": &"reservation.pancake.future_02"},
	&"slot.13": {"index": 13, "area_id": &"area.pancake", "kind": &"reserved", "reservation_id": &"reservation.pancake.future_03"},
	&"slot.14": {"index": 14, "area_id": &"area.pancake", "kind": &"reserved", "reservation_id": &"reservation.pancake.future_04"},
	&"slot.15": {"index": 15, "area_id": &"area.pancake", "kind": &"reserved", "reservation_id": &"reservation.pancake.future_05"},
	&"slot.16": {"index": 16, "area_id": &"area.packaged_drink", "kind": &"stock", "stock_id": &"stock.packaged_drink.milk"},
	&"slot.17": {"index": 17, "area_id": &"area.steamer", "kind": &"stock", "stock_id": &"stock.steamer.vegetable_bun"},
	&"slot.18": {"index": 18, "area_id": &"area.steamer", "kind": &"stock", "stock_id": &"stock.steamer.mantou"},
}

const STOCK_DEFINITIONS := {
	&"stock.pancake.batter": {"area_id": &"area.pancake", "category": &"base", "refill_seconds": 0.25, "material_slot_id": &""},
	&"stock.pancake.egg": {"area_id": &"area.pancake", "category": &"add_on", "refill_seconds": 0.25, "material_slot_id": &"slot.07"},
	&"stock.pancake.baocui": {"area_id": &"area.pancake", "category": &"add_on", "refill_seconds": 0.25, "material_slot_id": &"slot.08"},
	&"stock.pancake.scallion": {"area_id": &"area.pancake", "category": &"add_on", "refill_seconds": 0.25, "material_slot_id": &"slot.09"},
	&"stock.pancake.sauce.sweet_flour": {"area_id": &"area.pancake", "category": &"sauce", "refill_seconds": 0.25, "material_slot_id": &"", "surface_input_id": &"ui.pancake.sweet_flour_sauce_brush"},
	&"stock.pancake.sauce.red_chili": {"area_id": &"area.pancake", "category": &"sauce", "refill_seconds": 0.25, "material_slot_id": &"", "surface_input_id": &"ui.pancake.red_chili_sauce_brush"},
	&"stock.pancake.ham_sausage": {"area_id": &"area.pancake", "category": &"add_on", "refill_seconds": 0.25, "material_slot_id": &"slot.05"},
	&"stock.pancake.meat_floss": {"area_id": &"area.pancake", "category": &"add_on", "refill_seconds": 0.25, "material_slot_id": &"slot.04"},
	&"stock.pancake.pork_tenderloin": {"area_id": &"area.pancake", "category": &"add_on", "refill_seconds": 0.25, "material_slot_id": &"slot.10"},
	&"stock.pancake.coriander": {"area_id": &"area.pancake", "category": &"add_on", "refill_seconds": 0.25, "material_slot_id": &"slot.06"},
	&"stock.pancake.preserved_mustard": {"area_id": &"area.pancake", "category": &"add_on", "refill_seconds": 0.25, "material_slot_id": &""},
	&"stock.packaged_drink.milk": {"area_id": &"area.packaged_drink", "category": &"ingredient", "refill_seconds": 0.50, "material_slot_id": &"slot.16"},
	&"stock.packaged_drink.soy_milk": {"area_id": &"area.packaged_drink", "category": &"ingredient", "refill_seconds": 0.50, "material_slot_id": &""},
	&"stock.packaged_drink.walnut": {"area_id": &"area.packaged_drink", "category": &"ingredient", "refill_seconds": 0.50, "material_slot_id": &""},
	&"stock.packaged_drink.black_sesame": {"area_id": &"area.packaged_drink", "category": &"ingredient", "refill_seconds": 0.50, "material_slot_id": &""},
	&"stock.youtiao.plain_dough": {"area_id": &"area.youtiao", "category": &"dough", "refill_seconds": 1.50, "material_slot_id": &"slot.03"},
	&"stock.youtiao.oil_cake_dough": {"area_id": &"area.youtiao", "category": &"dough", "refill_seconds": 1.50, "material_slot_id": &""},
	&"stock.youtiao.sugar_oil_cake_dough": {"area_id": &"area.youtiao", "category": &"dough", "refill_seconds": 1.50, "material_slot_id": &""},
	&"stock.fresh_soy_milk.yellow_bean": {"area_id": &"area.fresh_soy_milk", "category": &"bean", "refill_seconds": 1.50, "material_slot_id": &"slot.01"},
	&"stock.fresh_soy_milk.black_bean": {"area_id": &"area.fresh_soy_milk", "category": &"bean", "refill_seconds": 1.50, "material_slot_id": &"slot.02"},
	&"stock.fresh_soy_milk.red_bean": {"area_id": &"area.fresh_soy_milk", "category": &"bean", "refill_seconds": 1.50, "material_slot_id": &""},
	&"stock.fresh_soy_milk.multigrain": {"area_id": &"area.fresh_soy_milk", "category": &"bean", "refill_seconds": 1.50, "material_slot_id": &""},
	&"stock.steamer.mantou": {"area_id": &"area.steamer", "category": &"semi_product", "refill_seconds": 1.50, "material_slot_id": &"slot.18"},
	&"stock.steamer.vegetable_bun": {"area_id": &"area.steamer", "category": &"semi_product", "refill_seconds": 1.50, "material_slot_id": &"slot.17"},
	&"stock.steamer.meat_bun": {"area_id": &"area.steamer", "category": &"semi_product", "refill_seconds": 1.50, "material_slot_id": &""},
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
	&"recipe.packaged_drink.milk": {"area_id": &"area.packaged_drink", "product_id": &"product.packaged_drink.milk", "stock_ids": [&"stock.packaged_drink.milk"]},
	&"recipe.packaged_drink.soy_milk": {"area_id": &"area.packaged_drink", "product_id": &"product.packaged_drink.soy_milk", "stock_ids": [&"stock.packaged_drink.soy_milk"]},
	&"recipe.packaged_drink.walnut": {"area_id": &"area.packaged_drink", "product_id": &"product.packaged_drink.walnut", "stock_ids": [&"stock.packaged_drink.walnut"]},
	&"recipe.packaged_drink.black_sesame": {"area_id": &"area.packaged_drink", "product_id": &"product.packaged_drink.black_sesame", "stock_ids": [&"stock.packaged_drink.black_sesame"]},
	&"recipe.youtiao.plain": {"area_id": &"area.youtiao", "product_id": &"product.youtiao.plain", "stock_ids": [&"stock.youtiao.plain_dough"]},
	&"recipe.youtiao.oil_cake": {"area_id": &"area.youtiao", "product_id": &"product.youtiao.oil_cake", "stock_ids": [&"stock.youtiao.oil_cake_dough"]},
	&"recipe.youtiao.sugar_oil_cake": {"area_id": &"area.youtiao", "product_id": &"product.youtiao.sugar_oil_cake", "stock_ids": [&"stock.youtiao.sugar_oil_cake_dough"]},
	&"recipe.fresh_soy_milk.yellow_bean": {"area_id": &"area.fresh_soy_milk", "product_id": &"product.fresh_soy_milk.yellow_bean", "stock_ids": [&"stock.fresh_soy_milk.yellow_bean"]},
	&"recipe.fresh_soy_milk.black_bean": {"area_id": &"area.fresh_soy_milk", "product_id": &"product.fresh_soy_milk.black_bean", "stock_ids": [&"stock.fresh_soy_milk.black_bean"]},
	&"recipe.fresh_soy_milk.red_bean": {"area_id": &"area.fresh_soy_milk", "product_id": &"product.fresh_soy_milk.red_bean", "stock_ids": [&"stock.fresh_soy_milk.red_bean"]},
	&"recipe.fresh_soy_milk.multigrain": {"area_id": &"area.fresh_soy_milk", "product_id": &"product.fresh_soy_milk.multigrain", "stock_ids": [&"stock.fresh_soy_milk.multigrain"]},
	&"recipe.steamer.mantou": {"area_id": &"area.steamer", "product_id": &"product.steamer.mantou", "stock_ids": [&"stock.steamer.mantou"]},
	&"recipe.steamer.vegetable_bun": {"area_id": &"area.steamer", "product_id": &"product.steamer.vegetable_bun", "stock_ids": [&"stock.steamer.vegetable_bun"]},
	&"recipe.steamer.meat_bun": {"area_id": &"area.steamer", "product_id": &"product.steamer.meat_bun", "stock_ids": [&"stock.steamer.meat_bun"]},
}

const PRODUCT_DEFINITIONS := {
	&"product.pancake.custom": {"area_id": &"area.pancake", "recipe_id": &"recipe.pancake.base"},
	&"product.packaged_drink.milk": {"area_id": &"area.packaged_drink", "recipe_id": &"recipe.packaged_drink.milk"},
	&"product.packaged_drink.soy_milk": {"area_id": &"area.packaged_drink", "recipe_id": &"recipe.packaged_drink.soy_milk"},
	&"product.packaged_drink.walnut": {"area_id": &"area.packaged_drink", "recipe_id": &"recipe.packaged_drink.walnut"},
	&"product.packaged_drink.black_sesame": {"area_id": &"area.packaged_drink", "recipe_id": &"recipe.packaged_drink.black_sesame"},
	&"product.youtiao.plain": {"area_id": &"area.youtiao", "recipe_id": &"recipe.youtiao.plain"},
	&"product.youtiao.oil_cake": {"area_id": &"area.youtiao", "recipe_id": &"recipe.youtiao.oil_cake"},
	&"product.youtiao.sugar_oil_cake": {"area_id": &"area.youtiao", "recipe_id": &"recipe.youtiao.sugar_oil_cake"},
	&"product.fresh_soy_milk.yellow_bean": {"area_id": &"area.fresh_soy_milk", "recipe_id": &"recipe.fresh_soy_milk.yellow_bean"},
	&"product.fresh_soy_milk.black_bean": {"area_id": &"area.fresh_soy_milk", "recipe_id": &"recipe.fresh_soy_milk.black_bean"},
	&"product.fresh_soy_milk.red_bean": {"area_id": &"area.fresh_soy_milk", "recipe_id": &"recipe.fresh_soy_milk.red_bean"},
	&"product.fresh_soy_milk.multigrain": {"area_id": &"area.fresh_soy_milk", "recipe_id": &"recipe.fresh_soy_milk.multigrain"},
	&"product.steamer.mantou": {"area_id": &"area.steamer", "recipe_id": &"recipe.steamer.mantou"},
	&"product.steamer.vegetable_bun": {"area_id": &"area.steamer", "recipe_id": &"recipe.steamer.vegetable_bun"},
	&"product.steamer.meat_bun": {"area_id": &"area.steamer", "recipe_id": &"recipe.steamer.meat_bun"},
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
	&"growth.tool.pancake.wide_spreader": {"purchase_slot": &"install", "kind": &"tool", "price": 12, "min_day": 2, "requires_area_id": &"area.pancake"},
	&"growth.add_on.pancake.red_chili": {"purchase_slot": &"content", "kind": &"stock_unlock", "price": 8, "min_day": 2, "requires_area_id": &"area.pancake", "unlock_stock_ids": [&"stock.pancake.sauce.red_chili"]},
	&"growth.add_on.pancake.ham_sausage": {"purchase_slot": &"content", "kind": &"stock_unlock", "price": 12, "min_day": 4, "requires_area_id": &"area.pancake", "unlock_stock_ids": [&"stock.pancake.ham_sausage"]},
	&"growth.equipment.pancake.intermediate": {"purchase_slot": &"install", "kind": &"device_tier", "price": 24, "min_day": 4, "requires_area_id": &"area.pancake", "device_id": &"device.pancake_griddle", "target_tier": 2},
	&"growth.add_on.pancake.meat_floss": {"purchase_slot": &"content", "kind": &"stock_unlock", "price": 18, "min_day": 6, "requires_area_id": &"area.pancake", "unlock_stock_ids": [&"stock.pancake.meat_floss"]},
	&"growth.capacity.pancake_holding_tray.two_slots": {"purchase_slot": &"content", "kind": &"pancake_holding_tray", "price": 32, "min_day": 8, "requires_area_id": &"area.pancake"},
	&"growth.add_on.pancake.coriander": {"purchase_slot": &"content", "kind": &"stock_unlock", "price": 10, "min_day": 8, "requires_area_id": &"area.pancake", "unlock_stock_ids": [&"stock.pancake.coriander"]},
	&"growth.add_on.pancake.pork_tenderloin": {"purchase_slot": &"content", "kind": &"stock_unlock", "price": 28, "min_day": 10, "requires_area_id": &"area.pancake", "unlock_stock_ids": [&"stock.pancake.pork_tenderloin"]},
	&"growth.automation.pancake.auto_sauce_brush": {"purchase_slot": &"install", "kind": &"automation", "price": 36, "min_day": 12, "requires_area_id": &"area.pancake", "automation_id": &"automation.pancake.auto_sauce_brush"},
	&"growth.area.packaged_drink": {"purchase_slot": &"install", "kind": &"area_unlock", "price": 30, "min_day": 3, "requires_area_id": &"area.pancake", "area_id": &"area.packaged_drink", "device_id": &"device.packaged_drink_heater", "unlock_recipe_ids": [&"recipe.packaged_drink.milk"], "unlock_stock_ids": [&"stock.packaged_drink.milk"]},
	&"growth.product.packaged_drink.soy_milk": {"purchase_slot": &"content", "kind": &"recipe_unlock", "price": 12, "min_day": 3, "requires_area_id": &"area.packaged_drink", "unlock_recipe_ids": [&"recipe.packaged_drink.soy_milk"], "unlock_stock_ids": [&"stock.packaged_drink.soy_milk"]},
	&"growth.area.youtiao": {"purchase_slot": &"install", "kind": &"area_unlock", "price": 60, "min_day": 6, "requires_area_id": &"area.packaged_drink", "area_id": &"area.youtiao", "device_id": &"device.youtiao_fryer", "unlock_recipe_ids": [&"recipe.youtiao.plain"], "unlock_stock_ids": [&"stock.youtiao.plain_dough"]},
	&"growth.recipe.youtiao.oil_cake": {"purchase_slot": &"content", "kind": &"recipe_unlock", "price": 18, "min_day": 6, "requires_area_id": &"area.youtiao", "unlock_recipe_ids": [&"recipe.youtiao.oil_cake"], "unlock_stock_ids": [&"stock.youtiao.oil_cake_dough"]},
	&"growth.area.fresh_soy_milk": {"purchase_slot": &"install", "kind": &"area_unlock", "price": 90, "min_day": 10, "requires_area_id": &"area.youtiao", "area_id": &"area.fresh_soy_milk", "device_id": &"device.fresh_soy_milk_machine", "unlock_recipe_ids": [&"recipe.fresh_soy_milk.yellow_bean"], "unlock_stock_ids": [&"stock.fresh_soy_milk.yellow_bean"]},
	&"growth.recipe.fresh_soy_milk.black_bean": {"purchase_slot": &"content", "kind": &"recipe_unlock", "price": 18, "min_day": 10, "requires_area_id": &"area.fresh_soy_milk", "unlock_recipe_ids": [&"recipe.fresh_soy_milk.black_bean"], "unlock_stock_ids": [&"stock.fresh_soy_milk.black_bean"]},
	&"growth.area.steamer": {"purchase_slot": &"install", "kind": &"area_unlock", "price": 120, "min_day": 14, "requires_area_id": &"area.fresh_soy_milk", "area_id": &"area.steamer", "device_id": &"device.steamer", "unlock_recipe_ids": [&"recipe.steamer.mantou"], "unlock_stock_ids": [&"stock.steamer.mantou"]},
	&"growth.recipe.steamer.vegetable_bun": {"purchase_slot": &"content", "kind": &"recipe_unlock", "price": 24, "min_day": 14, "requires_area_id": &"area.steamer", "unlock_recipe_ids": [&"recipe.steamer.vegetable_bun"], "unlock_stock_ids": [&"stock.steamer.vegetable_bun"]},
}
const MASTERY_DEFINITIONS := {}
const ORDER_BALANCE := {}
const REPUTATION_BALANCE := {}
const DAILY_GOAL_DEFINITIONS := {}
const PANCAKE_ORDER_TEMPLATES := {}

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
		elif slot.get("kind", &"") != &"reserved":
			errors.append("Unknown material slot kind: %s" % slot_id)
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
	for growth_id in GROWTH_DEFINITIONS:
		var growth: Dictionary = GROWTH_DEFINITIONS[growth_id]
		if growth.get("purchase_slot", &"") != &"install" and growth.get("purchase_slot", &"") != &"content":
			errors.append("Growth has invalid purchase slot: %s" % growth_id)
		if not AREA_DEFINITIONS.has(growth.get("requires_area_id", &"")):
			errors.append("Growth has unknown required area: %s" % growth_id)
	return errors

static func _copy_definition(source: Dictionary, definition_id: StringName) -> Dictionary:
	if not source.has(definition_id):
		return {}
	return source[definition_id].duplicate(true)
