class_name NightMarketSession
extends RefCounted

signal changed(snapshot: Dictionary)
signal order_changed(order: Dictionary)
signal payment_ready(payment: Dictionary)
signal day_ended(bill: Dictionary)

const CATALOG := preload("res://scripts/data/night_market_catalog.gd")
const MODEL := preload("res://scripts/gameplay/night_market_production_model.gd")
const SCORER := preload("res://scripts/gameplay/night_market_scorer.gd")
const ORDER_PROVIDER := preload("res://scripts/services/night_market_order_provider.gd")

const FIRST_DAY_SECONDS := 60.0
const NORMAL_DAY_SECONDS := 120.0
const INTRO_TIMED_RECIPE_SEQUENCE: Array[StringName] = [
	CATALOG.RECIPE_LAMB,
	CATALOG.RECIPE_LOTUS,
	CATALOG.RECIPE_BASIC_COMBO,
]
const CUSTOMER_IDS: Array[StringName] = [
	&"customer_01", &"customer_02", &"customer_03", &"customer_04", &"customer_05",
	&"customer_06", &"customer_07", &"customer_08", &"customer_09", &"customer_10",
	&"customer_11", &"customer_12", &"customer_13", &"customer_14", &"customer_15",
]

var coins := 0
var current_day := 1
var day_open := true
var business_paused := true
var remaining_seconds := FIRST_DAY_SECONDS
var tutorial_completed := false
var owned_growth_ids: Dictionary = {}
var pending_growth_ids: Array[StringName] = []
var unlocked_recipe_ids: Dictionary = {
	CATALOG.RECIPE_LAMB: true,
	CATALOG.RECIPE_LOTUS: true,
	CATALOG.RECIPE_BASIC_COMBO: true,
}
var inventory: Dictionary = {str(CATALOG.STOCK_CHICKEN): 0, str(CATALOG.STOCK_POTATO): 0}
var active_order: Dictionary = {}
var pending_payment: Dictionary = {}
var today_results: Array[Dictionary] = []
var last_bill: Dictionary = {}
var orders_completed := 0
var order_sequence := 0
var customer_cursor := 0
var recipe_cursor := 0
var today_reputation_delta := 0
var production: RefCounted = MODEL.new()


func _init(source: Dictionary = {}) -> void:
	if not source.is_empty():
		load_snapshot(source)


func snapshot() -> Dictionary:
	return {
		"version": 1,
		"coins": coins,
		"current_day": current_day,
		"day_open": day_open,
		"business_paused": business_paused,
		"remaining_seconds": remaining_seconds,
		"tutorial_completed": tutorial_completed,
		"owned_growth_ids": owned_growth_ids.keys(),
		"pending_growth_ids": PackedStringArray(pending_growth_ids.map(func(value): return str(value))),
		"unlocked_recipe_ids": unlocked_recipe_ids.keys(),
		"inventory": inventory.duplicate(true),
		"active_order": active_order.duplicate(true),
		"pending_payment": pending_payment.duplicate(true),
		"today_results": today_results.duplicate(true),
		"last_bill": last_bill.duplicate(true),
		"orders_completed": orders_completed,
		"order_sequence": order_sequence,
		"customer_cursor": customer_cursor,
		"recipe_cursor": recipe_cursor,
		"today_reputation_delta": today_reputation_delta,
		"production": production.call("snapshot"),
	}


func load_snapshot(source: Dictionary) -> Dictionary:
	coins = maxi(int(source.get("coins", 0)), 0)
	current_day = maxi(int(source.get("current_day", 1)), 1)
	day_open = bool(source.get("day_open", true))
	business_paused = bool(source.get("business_paused", true))
	remaining_seconds = clampf(float(source.get("remaining_seconds", FIRST_DAY_SECONDS if current_day == 1 else NORMAL_DAY_SECONDS)), 0.0, FIRST_DAY_SECONDS if current_day == 1 else NORMAL_DAY_SECONDS)
	tutorial_completed = bool(source.get("tutorial_completed", false))
	owned_growth_ids.clear()
	for value in Array(source.get("owned_growth_ids", [])):
		owned_growth_ids[StringName(value)] = true
	pending_growth_ids.clear()
	for value in Array(source.get("pending_growth_ids", [])):
		var growth_id := StringName(value)
		if not pending_growth_ids.has(growth_id):
			pending_growth_ids.append(growth_id)
	unlocked_recipe_ids = {
		CATALOG.RECIPE_LAMB: true,
		CATALOG.RECIPE_LOTUS: true,
		CATALOG.RECIPE_BASIC_COMBO: true,
	}
	for value in Array(source.get("unlocked_recipe_ids", [])):
		unlocked_recipe_ids[StringName(value)] = true
	_maybe_unlock_premium_combo()
	inventory = {str(CATALOG.STOCK_CHICKEN): 0, str(CATALOG.STOCK_POTATO): 0}
	var restored_inventory := Dictionary(source.get("inventory", {}))
	for stock_id in inventory.keys():
		inventory[stock_id] = clampi(int(restored_inventory.get(stock_id, 0)), 0, int(CATALOG.stock(StringName(stock_id)).get("capacity", 6)))
	active_order = Dictionary(source.get("active_order", {})).duplicate(true)
	_normalize_active_order()
	pending_payment = Dictionary(source.get("pending_payment", {})).duplicate(true)
	today_results.clear()
	for value in Array(source.get("today_results", [])):
		today_results.append(Dictionary(value).duplicate(true))
	last_bill = Dictionary(source.get("last_bill", {})).duplicate(true)
	orders_completed = maxi(int(source.get("orders_completed", 0)), 0)
	order_sequence = maxi(int(source.get("order_sequence", 0)), 0)
	customer_cursor = maxi(int(source.get("customer_cursor", 0)), 0)
	recipe_cursor = maxi(int(source.get("recipe_cursor", 0)), 0)
	today_reputation_delta = int(source.get("today_reputation_delta", 0))
	production = MODEL.new(Dictionary(source.get("production", {})))
	return {"success": true, "snapshot": snapshot()}


func _normalize_active_order() -> void:
	if active_order.is_empty():
		return
	var recipe_id := StringName(active_order.get("recipe_id", CATALOG.RECIPE_TUTORIAL))
	var recipe := CATALOG.recipe(recipe_id)
	if recipe.is_empty():
		active_order.clear()
		return
	active_order["recipe_id"] = recipe_id
	active_order["item_ids"] = Array(recipe.get("item_ids", [])).duplicate()
	active_order["time_limit"] = float(recipe.get("time_limit", 48.0))
	active_order["base_coins"] = int(recipe.get("sell_price", 1))


func set_business_paused(paused: bool) -> void:
	business_paused = paused
	changed.emit(snapshot())


func ensure_active_order() -> Dictionary:
	if not pending_payment.is_empty():
		return {"success": false, "reason": &"payment_pending"}
	if not active_order.is_empty():
		return {"success": true, "created": false, "order": active_order.duplicate(true)}
	if not day_open:
		return {"success": false, "reason": &"business_day_closed"}
	var tutorial := not tutorial_completed
	var recipe_id := CATALOG.RECIPE_TUTORIAL
	if not tutorial:
		recipe_id = _next_timed_recipe_id()
	order_sequence += 1
	var customer_id := CUSTOMER_IDS[customer_cursor % CUSTOMER_IDS.size()]
	customer_cursor += 1
	var provided := ORDER_PROVIDER.create_order(recipe_id, order_sequence, customer_id, tutorial)
	if not bool(provided.get("success", false)):
		return provided
	active_order = Dictionary(provided.get("order", {})).duplicate(true)
	order_changed.emit(active_order.duplicate(true))
	changed.emit(snapshot())
	return {"success": true, "created": true, "order": active_order.duplicate(true)}


func _next_timed_recipe_id() -> StringName:
	if recipe_cursor < INTRO_TIMED_RECIPE_SEQUENCE.size():
		var introductory_recipe := INTRO_TIMED_RECIPE_SEQUENCE[recipe_cursor]
		recipe_cursor += 1
		return introductory_recipe
	var available := unlocked_recipe_ids.keys()
	available.sort_custom(func(left, right): return str(left) < str(right))
	if available.is_empty():
		recipe_cursor += 1
		return CATALOG.RECIPE_LAMB
	# Continue after the introductory combo instead of immediately repeating it.
	# Newly unlocked recipes still join the same deterministic rotation.
	var combo_index := available.find(CATALOG.RECIPE_BASIC_COMBO)
	var rotation_start := combo_index + 1 if combo_index >= 0 else 0
	var rotation_offset := recipe_cursor - INTRO_TIMED_RECIPE_SEQUENCE.size()
	var recipe_id := StringName(available[(rotation_start + rotation_offset) % available.size()])
	recipe_cursor += 1
	return recipe_id


func advance(delta: float) -> Dictionary:
	if business_paused or not day_open:
		return {"success": true, "changed": false, "expired_now": false}
	var step := maxf(delta, 0.0)
	if production.call("has_production"):
		production.call("advance", step, owns_growth(CATALOG.GROWTH_THERMOSTATIC_FRYER))
	else:
		# Oil temperature is still a live station state before food enters.
		production.call("advance", step, owns_growth(CATALOG.GROWTH_THERMOSTATIC_FRYER))
	var customer_left_now := false
	var abandoned_order: Dictionary = {}
	if not active_order.is_empty() and not bool(active_order.get("tutorial_no_countdown", false)):
		active_order["remaining_patience_seconds"] = maxf(float(active_order.get("remaining_patience_seconds", 0.0)) - step, 0.0)
		if is_zero_approx(float(active_order.get("remaining_patience_seconds", 0.0))):
			customer_left_now = true
			abandoned_order = active_order.duplicate(true)
			today_reputation_delta -= 2
			active_order.clear()
			production = MODEL.new()
			order_changed.emit({})
	if tutorial_completed:
		remaining_seconds = maxf(remaining_seconds - step, 0.0)
		if remaining_seconds <= 0.0:
			var bill := end_day(&"timer_expired")
			return {
				"success": true, "changed": true, "expired_now": true,
				"customer_left_now": customer_left_now, "abandoned_order": abandoned_order,
				"reputation_delta": -2 if customer_left_now else 0, "bill": bill,
			}
	changed.emit(snapshot())
	return {
		"success": true, "changed": step > 0.0, "expired_now": false,
		"customer_left_now": customer_left_now, "abandoned_order": abandoned_order,
		"reputation_delta": -2 if customer_left_now else 0,
	}


func add_grill_skewer(item_id: StringName, zone_id: StringName) -> Dictionary:
	var stock_result := _consume_item_stock(item_id)
	if not bool(stock_result.get("success", false)):
		return stock_result
	var result := Dictionary(production.call("add_grill_skewer", item_id, zone_id))
	if not bool(result.get("success", false)):
		_refund_item_stock(item_id)
	else:
		changed.emit(snapshot())
	return result


func flip_grill_slot(slot_index: int) -> Dictionary:
	return _production_mutation("flip_grill_slot", [slot_index])


func plate_grill_slot(slot_index: int) -> Dictionary:
	return _production_mutation("plate_grill_slot", [slot_index])


func add_fryer_item(item_id: StringName) -> Dictionary:
	var stock_result := _consume_item_stock(item_id)
	if not bool(stock_result.get("success", false)):
		return stock_result
	var result := Dictionary(production.call("add_fryer_item", item_id))
	if not bool(result.get("success", false)):
		_refund_item_stock(item_id)
	else:
		changed.emit(snapshot())
	return result


func set_fryer_power(power_id: StringName) -> Dictionary:
	return _production_mutation("set_fryer_power", [power_id])


func lower_fryer() -> Dictionary:
	return _production_mutation("lower_fryer")


func lift_fryer() -> Dictionary:
	return _production_mutation("lift_fryer")


func plate_fryer() -> Dictionary:
	return _production_mutation("plate_fryer")


func season_last(seasoning_id: StringName) -> Dictionary:
	return _production_mutation("season_last_unseasoned", [seasoning_id])


func serve_plate() -> Dictionary:
	if active_order.is_empty():
		return {"success": false, "reason": &"no_active_order"}
	var production_snapshot := Dictionary(production.call("snapshot"))
	if Array(production_snapshot.get("plate_items", [])).is_empty():
		return {"success": false, "reason": &"plate_empty"}
	var score := Dictionary(SCORER.evaluate(
		production_snapshot,
		active_order,
		owns_growth(CATALOG.GROWTH_EMBER_BAFFLE),
		owns_growth(CATALOG.GROWTH_THERMOSTATIC_FRYER)
	))
	var base_coins := maxi(int(active_order.get("base_coins", 1)), 1)
	var payment_coins := maxi(roundi(float(base_coins) * (0.55 + 0.45 * float(score.get("overall_score", 0.0)) / 100.0)), 1)
	if bool(active_order.get("tutorial_no_countdown", false)):
		payment_coins = base_coins
	var grade := str(score.get("grade", "D"))
	var reputation_delta: int = int({"A": 4, "B": 3, "C": 1, "D": -2}.get(grade, -2))
	var result := {
		"success": true,
		"settlement_id": StringName("settlement.%s" % str(active_order.get("order_id", ""))),
		"order": active_order.duplicate(true),
		"score": score,
		"grade": grade,
		"payment_coins": payment_coins,
		"reputation_delta": reputation_delta,
		"tutorial": bool(active_order.get("tutorial_no_countdown", false)),
	}
	today_results.append(result.duplicate(true))
	today_reputation_delta += reputation_delta
	pending_payment = {
		"payment_id": StringName("payment.%s" % str(active_order.get("order_id", ""))),
		"coins": payment_coins,
		"tutorial": result["tutorial"],
		"result": result.duplicate(true),
	}
	active_order.clear()
	payment_ready.emit(pending_payment.duplicate(true))
	order_changed.emit({})
	changed.emit(snapshot())
	return result


func collect_payment() -> Dictionary:
	if pending_payment.is_empty():
		return {"success": false, "reason": &"no_pending_payment"}
	var collected := pending_payment.duplicate(true)
	coins += maxi(int(collected.get("coins", 0)), 0)
	orders_completed += 1
	var completed_tutorial_now := bool(collected.get("tutorial", false)) and not tutorial_completed
	if completed_tutorial_now:
		tutorial_completed = true
	pending_payment.clear()
	production = MODEL.new()
	changed.emit(snapshot())
	return {
		"success": true, "coins": coins, "collected_coins": int(collected.get("coins", 0)),
		"completed_tutorial_now": completed_tutorial_now,
	}


func refuse_order() -> Dictionary:
	if active_order.is_empty():
		return {"success": false, "reason": &"no_active_order"}
	if bool(active_order.get("tutorial_no_countdown", false)):
		return {"success": false, "reason": &"tutorial_order_cannot_be_refused"}
	var refused := active_order.duplicate(true)
	var started := bool(production.call("has_production"))
	var reputation_delta := -2 if started else -1
	today_reputation_delta += reputation_delta
	active_order.clear()
	production = MODEL.new()
	order_changed.emit({})
	changed.emit(snapshot())
	return {"success": true, "order": refused, "production_started": started, "reputation_delta": reputation_delta}


func discard_production() -> Dictionary:
	if not bool(production.call("has_production")):
		return {"success": false, "reason": &"no_production"}
	var result := Dictionary(production.call("discard_all"))
	changed.emit(snapshot())
	return result


func restock(stock_id: StringName) -> Dictionary:
	var definition := CATALOG.stock(stock_id)
	if definition.is_empty():
		return {"success": false, "reason": &"unknown_stock"}
	var key := str(stock_id)
	var capacity := int(definition.get("capacity", 0))
	if int(inventory.get(key, 0)) >= capacity:
		return {"success": false, "reason": &"stock_full"}
	var cost := int(definition.get("unit_cost", 0))
	if coins < cost:
		return {"success": false, "reason": &"insufficient_coins"}
	coins -= cost
	inventory[key] = int(inventory.get(key, 0)) + 1
	changed.emit(snapshot())
	return {"success": true, "coins": coins, "stock_id": stock_id, "current": inventory[key], "capacity": capacity}


func purchase_growth(growth_id: StringName) -> Dictionary:
	if day_open:
		return {"success": false, "reason": &"business_day_open"}
	var definition := CATALOG.growth(growth_id)
	if definition.is_empty():
		return {"success": false, "reason": &"unknown_growth"}
	if owns_growth(growth_id) or pending_growth_ids.has(growth_id):
		return {"success": false, "reason": &"already_owned"}
	for value in Array(definition.get("requires_growth_ids", [])):
		var required := StringName(value)
		if not owns_growth(required) and not pending_growth_ids.has(required):
			return {"success": false, "reason": &"missing_prerequisite", "growth_id": required}
	var price := int(definition.get("price", 0))
	if coins < price:
		return {"success": false, "reason": &"insufficient_coins"}
	coins -= price
	pending_growth_ids.append(growth_id)
	changed.emit(snapshot())
	return {"success": true, "charged_coins": price, "activates_on_day": current_day + 1}


func growth_overview() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for growth_id in CATALOG.GROWTH_DISPLAY_ORDER:
		var definition := CATALOG.growth(growth_id)
		definition["growth_id"] = growth_id
		definition["owned"] = owns_growth(growth_id)
		definition["pending"] = pending_growth_ids.has(growth_id)
		definition["can_afford"] = coins >= int(definition.get("price", 0))
		result.append(definition)
	return result


func owns_growth(growth_id: StringName) -> bool:
	return bool(owned_growth_ids.get(growth_id, false))


func end_day(reason: StringName = &"manual") -> Dictionary:
	if not day_open:
		return last_bill.duplicate(true)
	if not pending_payment.is_empty():
		collect_payment()
	var revenue := 0
	for value in today_results:
		revenue += int(Dictionary(value).get("payment_coins", 0))
	last_bill = {
		"day": current_day, "reason": reason, "orders_completed": today_results.size(),
		"revenue": revenue, "reputation_delta": today_reputation_delta,
		"results": today_results.duplicate(true),
	}
	day_open = false
	business_paused = true
	remaining_seconds = 0.0
	active_order.clear()
	pending_payment.clear()
	production = MODEL.new()
	for key in inventory.keys():
		inventory[key] = 0
	day_ended.emit(last_bill.duplicate(true))
	changed.emit(snapshot())
	return last_bill.duplicate(true)


func begin_next_day() -> Dictionary:
	if day_open:
		return {"success": false, "reason": &"business_day_open"}
	for growth_id in pending_growth_ids:
		owned_growth_ids[growth_id] = true
		var recipe_id := StringName(CATALOG.growth(growth_id).get("unlock_recipe_id", &""))
		if not recipe_id.is_empty():
			unlocked_recipe_ids[recipe_id] = true
	pending_growth_ids.clear()
	_maybe_unlock_premium_combo()
	current_day += 1
	day_open = true
	business_paused = true
	remaining_seconds = NORMAL_DAY_SECONDS
	today_results.clear()
	today_reputation_delta = 0
	last_bill.clear()
	active_order.clear()
	pending_payment.clear()
	production = MODEL.new()
	changed.emit(snapshot())
	return {"success": true, "day": current_day, "snapshot": snapshot()}


func milestone_progress() -> Dictionary:
	var owned_count := 0
	for growth_id in CATALOG.GROWTH_DISPLAY_ORDER:
		if owns_growth(growth_id):
			owned_count += 1
	return {"owned_growth_count": owned_count, "required_growth_count": CATALOG.GROWTH_DISPLAY_ORDER.size(), "complete": owned_count == CATALOG.GROWTH_DISPLAY_ORDER.size()}


func _maybe_unlock_premium_combo() -> void:
	if bool(unlocked_recipe_ids.get(CATALOG.RECIPE_CHICKEN, false)) and bool(unlocked_recipe_ids.get(CATALOG.RECIPE_POTATO, false)):
		unlocked_recipe_ids[CATALOG.RECIPE_PREMIUM_COMBO] = true


func _consume_item_stock(item_id: StringName) -> Dictionary:
	var stock_id := _stock_for_item(item_id)
	if stock_id.is_empty():
		return {"success": true, "managed": false}
	var key := str(stock_id)
	if int(inventory.get(key, 0)) <= 0:
		return {"success": false, "reason": &"insufficient_stock", "stock_id": stock_id}
	inventory[key] = int(inventory.get(key, 0)) - 1
	return {"success": true, "managed": true, "stock_id": stock_id}


func _refund_item_stock(item_id: StringName) -> void:
	var stock_id := _stock_for_item(item_id)
	if stock_id.is_empty():
		return
	var key := str(stock_id)
	inventory[key] = mini(int(inventory.get(key, 0)) + 1, int(CATALOG.stock(stock_id).get("capacity", 6)))


func _stock_for_item(item_id: StringName) -> StringName:
	if item_id == CATALOG.ITEM_CHICKEN:
		return CATALOG.STOCK_CHICKEN
	if item_id == CATALOG.ITEM_POTATO:
		return CATALOG.STOCK_POTATO
	return &""


func _production_mutation(method_name: StringName, arguments: Array = []) -> Dictionary:
	var result := Dictionary(production.callv(method_name, arguments))
	if bool(result.get("success", false)):
		changed.emit(snapshot())
	return result
