extends SceneTree

const CATALOG := preload("res://scripts/data/workstation_expansion_catalog.gd")
const PROGRESSION_SERVICE := preload("res://scripts/services/workstation_progression_service.gd")
const REFILL_SERVICE := preload("res://scripts/services/hold_refill_service.gd")
const PRODUCTION_SERVICE := preload("res://scripts/services/expansion_production_service.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	_check_progression_and_pending_activation()
	_check_automation_consumes_stock_and_time()
	_check_hold_refill_accounting()
	_check_capacity_upgrade_preserves_state()
	_finish()


func _ready_progression(coins: int = 1000) -> RefCounted:
	var state: RefCounted = PROGRESSION_SERVICE.new()
	state.set("coins", coins)
	state.set("current_day", 20)
	state.set("reputation", 500)
	state.call("set_metric", &"lifetime_orders", 100)
	state.call("set_metric", &"soy_good", 100)
	state.call("set_metric", &"expanded_good", 100)
	state.call("set_metric", &"manual_spread_good", 100)
	return state


func _check_progression_and_pending_activation() -> void:
	var state := _ready_progression()
	_check(state.call("owns", CATALOG.TOOL_SPREADER_BASIC), "basic spreader is permanently owned at start")
	_check(state.call("owns", CATALOG.TOOL_SAUCE_BRUSH_MANUAL), "manual sauce brush is permanently owned at start")
	_check(int(state.get("inventory").call("current", CATALOG.STOCK_HAM_SAUSAGE)) == 0, "ham sausage has no opening-day stock before it is unlocked")
	_check(CATALOG.item_effect(CATALOG.TOOL_SPREADER_WIDE).width_multiplier == 1.35, "wide spreader exposes queryable effect data")
	_check(CATALOG.item_effect(CATALOG.TOOL_PRESS).uses_per_pancake == 1, "press tool exposes one-use-per-pancake effect")
	_check(_reason(state.call("purchase", CATALOG.UPGRADE_SOY_INTERMEDIATE)) == &"missing_previous_tier", "equipment tiers cannot be skipped")
	var coins_before: int = state.get("coins")
	var base_purchase: Dictionary = state.call("purchase", CATALOG.UPGRADE_SOY_BASIC)
	_check(bool(base_purchase.success) and not state.call("owns_equipment", CATALOG.DEVICE_SOY_MILK), "purchase is pending until the next business day")
	_check(int(state.get("coins")) == coins_before - int(CATALOG.purchase_definition(CATALOG.UPGRADE_SOY_BASIC).price), "pending purchase charges exactly once")
	_check(_reason(state.call("purchase", CATALOG.TOOL_SPREADER_WIDE)) == &"pending_purchase_exists", "only one growth purchase may be pending")
	state.call("begin_next_business_day")
	_check(state.call("owns_equipment", CATALOG.DEVICE_SOY_MILK) and int(state.call("equipment_tier", CATALOG.DEVICE_SOY_MILK)) == CATALOG.TIER_BASIC, "base equipment activates next day")
	_check(bool(state.call("purchase", CATALOG.UPGRADE_SOY_INTERMEDIATE).success), "intermediate tier is purchasable after base activation")
	state.call("begin_next_business_day")
	_check(int(state.call("equipment_tier", CATALOG.DEVICE_SOY_MILK)) == CATALOG.TIER_INTERMEDIATE, "intermediate equipment activates in order")
	_check(bool(state.call("purchase", CATALOG.UPGRADE_SOY_ADVANCED).success), "advanced tier follows intermediate")
	state.call("begin_next_business_day")
	_check(not state.call("owns", CATALOG.AUTO_SOY_LOAD), "advanced equipment does not grant automation for free")
	_check(bool(state.call("purchase", CATALOG.AUTO_SOY_LOAD).success), "automatic loading is an independent purchase")
	state.call("begin_next_business_day")
	_check(state.call("owns", CATALOG.AUTO_SOY_LOAD), "independent automation activates next day")


func _check_automation_consumes_stock_and_time() -> void:
	var state := _ready_progression()
	_check(bool(state.call("purchase", CATALOG.UPGRADE_SOY_BASIC).success), "automation fixture can buy base soy equipment")
	state.call("begin_next_business_day")
	_check(bool(state.call("purchase", CATALOG.AUTO_SOY_LOAD).success), "automation fixture can buy auto load")
	state.call("begin_next_business_day")
	var stock: RefCounted = state.get("inventory")
	stock.call("set_current", CATALOG.STOCK_SOY_YELLOW, 5)
	var production: RefCounted = PRODUCTION_SERVICE.new(state)
	var loaded: Dictionary = production.call("automated_load", CATALOG.DEVICE_SOY_MILK, CATALOG.RECIPE_SOY_YELLOW, 2)
	_check(bool(loaded.success) and int(stock.call("current", CATALOG.STOCK_SOY_YELLOW)) == 3, "automatic loading consumes one raw item per output")
	_check(_reason(production.call("start", CATALOG.DEVICE_SOY_MILK)) == &"missing_required_action", "automation does not erase unrelated required actions")
	production.call("perform_action", CATALOG.DEVICE_SOY_MILK, CATALOG.ACTION_ADD_WATER)
	_check(bool(production.call("start", CATALOG.DEVICE_SOY_MILK).success), "automatically loaded batch can start normally")
	production.call("advance_time", 15.99)
	_check(not bool(production.call("machine_snapshot", CATALOG.DEVICE_SOY_MILK).has_output), "automation does not create output before processing time")
	production.call("advance_time", 0.01)
	_check(bool(production.call("machine_snapshot", CATALOG.DEVICE_SOY_MILK).has_output), "automation still uses the full processing duration")


func _check_hold_refill_accounting() -> void:
	var state := _ready_progression(100)
	var stock: RefCounted = state.get("inventory")
	stock.call("set_current", CATALOG.STOCK_EGG, 0)
	stock.call("set_current", CATALOG.STOCK_BAOCUI, 0)
	var refill: RefCounted = REFILL_SERVICE.new(state)
	var definition: Dictionary = CATALOG.refill_definition(CATALOG.STOCK_EGG)
	var unit_time: float = float(definition.unit_seconds)
	var unit_cost: int = int(definition.unit_cost)
	var coins_before: int = state.get("coins")
	refill.call("advance_hold", CATALOG.STOCK_EGG, unit_time * 0.4)
	_check(int(stock.call("current", CATALOG.STOCK_EGG)) == 0 and int(state.get("coins")) == coins_before, "short hold neither adds stock nor charges")
	var partial_progress: float = float(state.call("refill_progress_for", CATALOG.STOCK_EGG))
	refill.call("release", CATALOG.STOCK_EGG)
	_check(is_equal_approx(float(state.call("refill_progress_for", CATALOG.STOCK_EGG)), partial_progress), "release permanently preserves partial progress")
	refill.call("advance_hold", CATALOG.STOCK_BAOCUI, float(CATALOG.refill_definition(CATALOG.STOCK_BAOCUI).unit_seconds) * 0.25)
	_check(is_equal_approx(float(state.call("refill_progress_for", CATALOG.STOCK_EGG)), partial_progress), "switching refill entries preserves the previous entry progress")
	refill.call("advance_hold", CATALOG.STOCK_EGG, unit_time * 0.6)
	_check(int(stock.call("current", CATALOG.STOCK_EGG)) == 1 and int(state.get("coins")) == coins_before - unit_cost, "segmented hold completes one unit and charges once")
	refill.call("advance_hold", CATALOG.STOCK_EGG, unit_time * 2.5)
	_check(int(stock.call("current", CATALOG.STOCK_EGG)) == 3, "one hold can refill multiple units")
	_check(int(state.get("coins")) == coins_before - unit_cost * 3, "multi-unit refill charges exactly completed units")
	_check(is_equal_approx(float(state.call("refill_progress_for", CATALOG.STOCK_EGG)), unit_time * 0.5), "multi-unit refill preserves unfinished next-unit progress")

	stock.call("set_current", CATALOG.STOCK_EGG, int(stock.call("capacity", CATALOG.STOCK_EGG)) - 1)
	state.call("set_refill_progress", CATALOG.STOCK_EGG, 0.0)
	var capacity_coins: int = state.get("coins")
	var stopped: Dictionary = refill.call("advance_hold", CATALOG.STOCK_EGG, unit_time * 4.0)
	_check(_reason(stopped) == &"capacity_reached" and int(state.get("coins")) == capacity_coins - unit_cost, "capacity stop completes and charges only the available slot")
	_check(is_zero_approx(float(state.call("refill_progress_for", CATALOG.STOCK_EGG))), "time after automatic capacity stop is not banked")

	stock.call("set_current", CATALOG.STOCK_EGG, 0)
	state.call("set_refill_progress", CATALOG.STOCK_EGG, unit_time * 0.3)
	state.set("coins", unit_cost - 1)
	var poor: Dictionary = refill.call("advance_hold", CATALOG.STOCK_EGG, unit_time)
	_check(_reason(poor) == &"insufficient_coins" and int(stock.call("current", CATALOG.STOCK_EGG)) == 0, "insufficient funds stop before another unit")
	_check(is_equal_approx(float(state.call("refill_progress_for", CATALOG.STOCK_EGG)), unit_time * 0.3), "insufficient funds do not swallow saved progress")
	_check(int(state.get("coins")) == unit_cost - 1, "insufficient funds do not deduct coins")


func _check_capacity_upgrade_preserves_state() -> void:
	var state := _ready_progression()
	var stock: RefCounted = state.get("inventory")
	stock.call("set_current", CATALOG.STOCK_HAM_SAUSAGE, 6)
	state.call("set_refill_progress", CATALOG.STOCK_HAM_SAUSAGE, 0.75)
	_check(bool(state.call("purchase", CATALOG.INGREDIENT_BOX_INTERMEDIATE).success), "intermediate ingredient box is purchasable")
	state.call("begin_next_business_day")
	_check(int(stock.call("capacity", CATALOG.STOCK_HAM_SAUSAGE)) == 10, "intermediate ingredient box capacity is ten")
	_check(int(stock.call("current", CATALOG.STOCK_HAM_SAUSAGE)) == 6, "capacity upgrade preserves current inventory")
	_check(is_equal_approx(float(state.call("refill_progress_for", CATALOG.STOCK_HAM_SAUSAGE)), 0.75), "capacity upgrade preserves refill progress")
	_check(bool(state.call("purchase", CATALOG.INGREDIENT_BOX_ADVANCED).success), "advanced ingredient box follows intermediate")
	state.call("begin_next_business_day")
	_check(int(stock.call("capacity", CATALOG.STOCK_HAM_SAUSAGE)) == 14, "advanced ingredient box capacity is fourteen")
	var restored: RefCounted = PROGRESSION_SERVICE.new(state.call("snapshot"))
	var restored_stock: RefCounted = restored.get("inventory")
	_check(int(restored_stock.call("capacity", CATALOG.STOCK_HAM_SAUSAGE)) == 14, "new-format state snapshot restores the active capacity tier")
	_check(int(restored_stock.call("current", CATALOG.STOCK_HAM_SAUSAGE)) == 6, "new-format state snapshot restores current inventory")
	_check(is_equal_approx(float(restored.call("refill_progress_for", CATALOG.STOCK_HAM_SAUSAGE)), 0.75), "new-format state snapshot restores refill progress")


func _reason(result: Dictionary) -> StringName:
	return result.get("reason", &"") as StringName


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PROGRESSION_REFILL_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
