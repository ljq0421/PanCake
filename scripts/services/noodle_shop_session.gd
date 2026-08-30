class_name NoodleShopSession
extends RefCounted

signal changed(snapshot: Dictionary)
signal order_changed(order: Dictionary)
signal payment_ready(payment: Dictionary)
signal day_ended(bill: Dictionary)

const CATALOG := preload("res://scripts/data/noodle_shop_catalog.gd")
const MODEL := preload("res://scripts/gameplay/noodle_bowl_model.gd")
const SCORER := preload("res://scripts/gameplay/noodle_scorer.gd")
const ORDER_PROVIDER := preload("res://scripts/services/noodle_order_provider.gd")

const FIRST_DAY_SECONDS := 60.0
const NORMAL_DAY_SECONDS := 120.0
const CUSTOMER_IDS: Array[StringName] = [
	&"customer_01", &"customer_02", &"customer_03", &"customer_04", &"customer_05",
	&"customer_06", &"customer_07", &"customer_08", &"customer_09", &"customer_10",
	&"customer_11", &"customer_12", &"customer_13", &"customer_14", &"customer_15",
	&"customer_16", &"customer_17", &"customer_18", &"customer_19", &"customer_20",
]

var coins := 0
var current_day := 1
var day_open := true
var business_paused := true
var remaining_seconds := FIRST_DAY_SECONDS
var tutorial_completed := false
var owned_growth_ids: Dictionary = {}
var pending_growth_ids: Array[StringName] = []
var unlocked_recipe_ids: Dictionary = {CATALOG.RECIPE_CLEAR: true}
var inventory: Dictionary = {str(CATALOG.STOCK_TOMATO): 0, str(CATALOG.STOCK_ZHAJIANG): 0}
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


func _init(snapshot: Dictionary = {}) -> void:
	if not snapshot.is_empty():
		load_snapshot(snapshot)


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
	unlocked_recipe_ids = {CATALOG.RECIPE_CLEAR: true}
	for value in Array(source.get("unlocked_recipe_ids", [])):
		unlocked_recipe_ids[StringName(value)] = true
	inventory = {str(CATALOG.STOCK_TOMATO): 0, str(CATALOG.STOCK_ZHAJIANG): 0}
	for stock_id in inventory.keys():
		inventory[stock_id] = maxi(int(Dictionary(source.get("inventory", {})).get(stock_id, 0)), 0)
	active_order = Dictionary(source.get("active_order", {})).duplicate(true)
	_normalize_restored_active_order()
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


func _normalize_restored_active_order() -> void:
	if active_order.is_empty():
		return
	var recipe_id := StringName(active_order.get("recipe_id", CATALOG.RECIPE_CLEAR))
	var recipe := CATALOG.recipe(recipe_id)
	if recipe.is_empty():
		active_order.clear()
		return
	active_order["recipe_id"] = recipe_id
	active_order["product_id"] = recipe.get("product_id", &"")
	active_order["noodle_profile_id"] = recipe.get("profile_id", &"standard")
	active_order["required_batch_count"] = CATALOG.TARGET_BATCH_COUNT
	active_order["broth_id"] = recipe.get("broth_id", &"")
	active_order["topping_ids"] = Array(recipe.get("topping_ids", [])).duplicate()
	# JSON serializes Vector2 values textually. Rebuild this public order field
	# from the stable recipe definition so a resumed order keeps its exact type.
	active_order["drain_target"] = Vector2(float(recipe.get("drain_min", 0.0)), float(recipe.get("drain_max", 99.0)))
	active_order["time_limit"] = float(recipe.get("time_limit", 30.0))
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
	var recipe_id := CATALOG.RECIPE_CLEAR
	var tutorial := not tutorial_completed
	if not tutorial:
		var available := unlocked_recipe_ids.keys()
		available.sort_custom(func(left, right): return str(left) < str(right))
		if not available.is_empty():
			recipe_id = StringName(available[recipe_cursor % available.size()])
			recipe_cursor += 1
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


func begin_active_recipe() -> Dictionary:
	if active_order.is_empty():
		return {"success": false, "reason": &"no_active_order"}
	if StringName(production.get("state")) != &"idle":
		return {"success": false, "reason": &"production_already_started"}
	var recipe_id := StringName(active_order.get("recipe_id", &""))
	var stock_ids := Array(CATALOG.recipe(recipe_id).get("stock_ids", []))
	for value in stock_ids:
		var stock_id := str(value)
		if int(inventory.get(stock_id, 0)) <= 0:
			return {"success": false, "reason": &"insufficient_stock", "stock_id": StringName(stock_id)}
	for value in stock_ids:
		var stock_id := str(value)
		inventory[stock_id] = int(inventory.get(stock_id, 0)) - 1
	var result := Dictionary(production.call("begin", recipe_id))
	changed.emit(snapshot())
	return result


func advance(delta: float) -> Dictionary:
	if business_paused or not day_open:
		return {"success": true, "changed": false, "expired_now": false}
	var step := maxf(delta, 0.0)
	if StringName(production.get("state")) != &"idle":
		production.call("advance", step)
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
				"success": true,
				"changed": true,
				"expired_now": true,
				"customer_left_now": customer_left_now,
				"abandoned_order": abandoned_order,
				"reputation_delta": -2 if customer_left_now else 0,
				"bill": bill,
			}
	changed.emit(snapshot())
	return {
		"success": true,
		"changed": step > 0.0,
		"expired_now": false,
		"customer_left_now": customer_left_now,
		"abandoned_order": abandoned_order,
		"reputation_delta": -2 if customer_left_now else 0,
	}


func record_stroke(distance: float, duration: float) -> Dictionary:
	var result := Dictionary(production.call("record_stroke", distance, duration))
	if bool(result.get("success", false)):
		changed.emit(snapshot())
	return result


func lift_basket() -> Dictionary:
	var result := Dictionary(production.call("lift_basket"))
	if bool(result.get("success", false)):
		changed.emit(snapshot())
	return result


func return_basket_to_pot() -> Dictionary:
	var result := Dictionary(production.call("return_to_pot"))
	if bool(result.get("success", false)):
		changed.emit(snapshot())
	return result


func transfer_to_bowl() -> Dictionary:
	var result := Dictionary(production.call("transfer_to_bowl"))
	if bool(result.get("success", false)):
		changed.emit(snapshot())
	return result


func set_broth(broth_id: StringName) -> Dictionary:
	var result := Dictionary(production.call("set_broth", broth_id))
	if bool(result.get("success", false)):
		changed.emit(snapshot())
	return result


func add_topping(topping_id: StringName) -> Dictionary:
	var result := Dictionary(production.call("add_topping", topping_id))
	if bool(result.get("success", false)):
		changed.emit(snapshot())
	return result


func serve_bowl() -> Dictionary:
	if active_order.is_empty():
		return {"success": false, "reason": &"no_active_order"}
	if StringName(production.get("state")) != &"bowled":
		return {"success": false, "reason": &"bowl_not_ready"}
	var score := Dictionary(SCORER.evaluate(
		production.call("snapshot"),
		owns_growth(CATALOG.GROWTH_SHARP_KNIFE),
		owns_growth(CATALOG.GROWTH_STABLE_BASKET)
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
		"success": true,
		"coins": coins,
		"collected_coins": int(collected.get("coins", 0)),
		"completed_tutorial_now": completed_tutorial_now,
	}


func refuse_order() -> Dictionary:
	if active_order.is_empty():
		return {"success": false, "reason": &"no_active_order"}
	if bool(active_order.get("tutorial_no_countdown", false)):
		return {"success": false, "reason": &"tutorial_order_cannot_be_refused"}
	var refused := active_order.duplicate(true)
	var production_started := StringName(production.get("state")) != &"idle"
	var reputation_delta := -2 if production_started else -1
	today_reputation_delta += reputation_delta
	active_order.clear()
	production = MODEL.new()
	order_changed.emit({})
	changed.emit(snapshot())
	return {
		"success": true,
		"order": refused,
		"production_started": production_started,
		"reputation_delta": reputation_delta,
	}


func discard_bowl() -> Dictionary:
	if StringName(production.get("state")) == &"idle":
		return {"success": false, "reason": &"no_production"}
	var discarded := Dictionary(production.call("snapshot")).duplicate(true)
	production = MODEL.new()
	changed.emit(snapshot())
	return {"success": true, "discarded": discarded}


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
		if not owns_growth(StringName(value)) and not pending_growth_ids.has(StringName(value)):
			return {"success": false, "reason": &"missing_prerequisite", "growth_id": StringName(value)}
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
		"day": current_day,
		"reason": reason,
		"orders_completed": today_results.size(),
		"revenue": revenue,
		"reputation_delta": today_reputation_delta,
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
