extends Node

signal settings_changed(current_settings: Dictionary)
signal coins_changed(current_coins: int)
signal progression_changed(snapshot: Dictionary)
signal inventory_changed(snapshot: Dictionary)

const SAVE_PATH := "user://project_cake_save.json"
const SETTINGS_PATH := "user://project_cake_settings.cfg"
const SAVE_VERSION := 3
const SAVE_KIND := "five_area_v1"
const BUSINESS_DAY_DURATION_SECONDS := 120.0
const PROGRESSION_SERVICE := preload("res://scripts/services/five_area_progression_service.gd")
const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const PANCAKE_HOLDING_TRAY_MODEL := preload("res://scripts/gameplay/pancake_holding_tray_model.gd")
const FIVE_AREA_ORDER_SERVICE := preload("res://scripts/services/five_area_order_service.gd")
const FIVE_AREA_PANCAKE_ORDER_GENERATOR := preload("res://scripts/services/five_area_pancake_order_generator.gd")
const LEGACY_PANCAKE_STOCK_IDS := {
	&"egg": &"stock.pancake.egg",
	&"baocui": &"stock.pancake.baocui",
	&"scallion": &"stock.pancake.scallion",
	&"ham_sausage": &"stock.pancake.ham_sausage",
	&"meat_floss": &"stock.pancake.meat_floss",
	&"pork_tenderloin": &"stock.pancake.pork_tenderloin",
	&"coriander": &"stock.pancake.coriander",
	&"preserved_mustard": &"stock.pancake.preserved_mustard",
}
const LEGACY_PANCAKE_SAUCE_STOCK_IDS := {
	&"sweet_flour": &"stock.pancake.sauce.sweet_flour",
	&"red_chili": &"stock.pancake.sauce.red_chili",
}
const PANCAKE_LEGACY_TO_STABLE_STOCK_IDS := {
	&"egg": &"stock.pancake.egg",
	&"baocui": &"stock.pancake.baocui",
	&"ham_sausage": &"stock.pancake.ham_sausage",
	&"scallion": &"stock.pancake.scallion",
	&"meat_floss": &"stock.pancake.meat_floss",
	&"pork_tenderloin": &"stock.pancake.pork_tenderloin",
	&"coriander": &"stock.pancake.coriander",
	&"preserved_mustard": &"stock.pancake.preserved_mustard",
}
const DAILY_PANCAKE_CONSUMABLE_STOCK := {
	&"stock.pancake.batter": 6,
	&"stock.pancake.sauce.sweet_flour": 6,
	&"stock.pancake.sauce.red_chili": 6,
}
const RECONCILED_FORMAL_ORDER_IDS_KEY := "reconciled_formal_order_ids"
const DEFAULT_SETTINGS := {
	"master_volume": 80.0,
	"sfx_volume": 85.0,
	"fullscreen": false,
}

var _save_data: Dictionary = {}
var _settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var _progression: RefCounted
var _pancake_holding_tray: RefCounted
var _order_service: RefCounted
var _incompatible_development_save_removed := false


func _ready() -> void:
	_load_save()
	_restore_progression()
	_reconcile_unrecorded_settled_orders()
	_load_settings()
	apply_settings()


func has_save() -> bool:
	return not _save_data.is_empty() and int(_save_data.get("version", 0)) == SAVE_VERSION and str(_save_data.get("save_kind", "")) == SAVE_KIND


func is_five_area_save_active() -> bool:
	return has_save()


func uses_five_area_progression() -> bool:
	return true


func incompatible_development_save_was_removed() -> bool:
	return _incompatible_development_save_removed


func begin_new_game() -> Dictionary:
	var now := int(Time.get_unix_time_from_system())
	_progression = PROGRESSION_SERVICE.new()
	_pancake_holding_tray = PANCAKE_HOLDING_TRAY_MODEL.new()
	_order_service = FIVE_AREA_ORDER_SERVICE.new()
	_save_data = {
		"version": SAVE_VERSION,
		"save_kind": SAVE_KIND,
		"started_at_unix": now,
		"last_played_at_unix": now,
		"day_open": true,
		"business_day_remaining_seconds": BUSINESS_DAY_DURATION_SECONDS,
		"orders_completed": 0,
		"today_orders": [],
		"today_reputation_delta": 0,
		"today_cutoff": {},
		"progression": _progression.call("snapshot"),
		"inventory": _new_inventory_snapshot(),
		"restock_progress": {},
		"pancake_holding_tray": PANCAKE_HOLDING_TRAY_MODEL.new().snapshot(),
		"formal_orders": FIVE_AREA_ORDER_SERVICE.new().snapshot(),
		RECONCILED_FORMAL_ORDER_IDS_KEY: [],
		"pancake_order_cursor": 0,
		"pancake_orders_issued_today": 0,
	}
	_write_save()
	progression_changed.emit(five_area_progression_snapshot())
	inventory_changed.emit(inventory_snapshot())
	return {"success": true, "snapshot": _save_data.duplicate(true)}


func continue_game() -> bool:
	if not has_save():
		return false
	_save_data["last_played_at_unix"] = int(Time.get_unix_time_from_system())
	_write_save()
	return true


func business_day_remaining_seconds() -> float:
	if not has_save():
		return BUSINESS_DAY_DURATION_SECONDS
	return clampf(float(_save_data.get("business_day_remaining_seconds", BUSINESS_DAY_DURATION_SECONDS)), 0.0, BUSINESS_DAY_DURATION_SECONDS)


func set_business_day_remaining_seconds(remaining_seconds: float) -> void:
	if not has_save():
		return
	_save_data["business_day_remaining_seconds"] = clampf(remaining_seconds, 0.0, BUSINESS_DAY_DURATION_SECONDS)
	_touch_and_write()


func resume_summary() -> String:
	if not has_save():
		return "还没有营业记录，新游戏会从第一位顾客开始。"
	var timestamp := int(_save_data.get("last_played_at_unix", 0))
	var orders := int(_save_data.get("orders_completed", 0))
	return "上次营业  %s  ·  已完成 %d 单" % [_format_timestamp(timestamp), orders]


func reset_incompatible_development_save() -> Dictionary:
	_save_data.clear()
	_progression = PROGRESSION_SERVICE.new()
	var absolute_path := ProjectSettings.globalize_path(SAVE_PATH)
	var removed := false
	if FileAccess.file_exists(SAVE_PATH):
		removed = DirAccess.remove_absolute(absolute_path) == OK
	_incompatible_development_save_removed = removed
	return {"success": removed or not FileAccess.file_exists(SAVE_PATH), "removed": removed}


func progression_service() -> RefCounted:
	_ensure_progression()
	return _progression


func order_service() -> RefCounted:
	_ensure_order_service()
	return _order_service


func open_pancake_order(template: Dictionary) -> Dictionary:
	var ingredient_ids := _stable_pancake_stock_ids(Array(template.get("ingredients", template.get("ingredient_ids", []))), LEGACY_PANCAKE_STOCK_IDS)
	var sauce_ids := _stable_pancake_stock_ids(Array(template.get("sauces", template.get("sauce_ids", []))), LEGACY_PANCAKE_SAUCE_STOCK_IDS)
	return open_formal_order([{
		"area_id": &"area.pancake",
		"product_id": &"product.pancake.custom",
		"quantity": 1,
		"temperature_mode": &"normal",
		"pancake_template_id": StringName(template.get("id", &"")),
		"ingredient_ids": ingredient_ids,
		"sauce_ids": sauce_ids,
		"heat_preference": StringName(template.get("heat_preference", &"")),
	}], {"legacy_order": template.duplicate(true)})


func next_filtered_pancake_order() -> Dictionary:
	if not has_save():
		return {}
	_ensure_progression()
	var issued_today := maxi(int(_save_data.get("pancake_orders_issued_today", 0)), 0)
	var tutorial: Dictionary = Dictionary(_progression.call("tutorial_snapshot"))
	# A region/device tutorial is reserved for the second queue position.  The
	# first customer remains a normal order and a single active tutorial cannot
	# duplicate across the rest of the day.
	if issued_today != 1:
		tutorial = {}
	var generated: Dictionary = FIVE_AREA_PANCAKE_ORDER_GENERATOR.generate(
		five_area_progression_snapshot(),
		tutorial,
		int(_save_data.get("pancake_order_cursor", 0))
	)
	if not bool(generated.get("success", false)):
		return {}
	_save_data["pancake_order_cursor"] = int(generated.get("next_cursor", 0))
	_save_data["pancake_orders_issued_today"] = issued_today + 1
	_touch_and_write()
	return Dictionary(generated.get("order", {})).duplicate(true)


func open_formal_order(items: Array, metadata: Dictionary = {}) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_order_service()
	var result: Dictionary = _order_service.call("open_order", items, metadata)
	if bool(result.get("success", false)):
		_sync_formal_orders_to_save()
		_touch_and_write()
	return result


func formal_order_snapshot() -> Dictionary:
	_ensure_order_service()
	return Dictionary(_order_service.call("snapshot")).duplicate(true)


func active_formal_order() -> Dictionary:
	_ensure_order_service()
	return Dictionary(_order_service.call("active_order")).duplicate(true)


func attach_formal_order_product(order_id: StringName, item_index: int, product: Dictionary) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_order_service()
	var result: Dictionary = _order_service.call("attach_product", order_id, item_index, product)
	if bool(result.get("success", false)):
		_sync_formal_orders_to_save()
		_touch_and_write()
	return result


func settle_formal_order(order_id: StringName) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_order_service()
	var result: Dictionary = _order_service.call("settle_order", order_id)
	if bool(result.get("success", false)):
		_sync_formal_orders_to_save()
		_touch_and_write()
	return result


func pancake_holding_tray_snapshot() -> Dictionary:
	_ensure_pancake_holding_tray()
	return Dictionary(_pancake_holding_tray.call("snapshot")).duplicate(true)


func store_pancake_product(product: Dictionary) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_progression()
	if not bool(_progression.call("owns_growth", &"growth.capacity.pancake_holding_tray.two_slots")):
		return {"success": false, "reason": &"tray_locked"}
	_ensure_pancake_holding_tray()
	var result: Dictionary = _pancake_holding_tray.call("store", product)
	if bool(result.get("success", false)):
		_sync_pancake_holding_tray_to_save()
		_touch_and_write()
	return result


func preview_pancake_tray_delivery(slot_index: int, order: Dictionary) -> Dictionary:
	_ensure_pancake_holding_tray()
	return Dictionary(_pancake_holding_tray.call("preview_serve_matching", slot_index, order)).duplicate(true)


func serve_pancake_tray_delivery(slot_index: int, order: Dictionary) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_pancake_holding_tray()
	var result: Dictionary = _pancake_holding_tray.call("serve_matching", slot_index, order)
	if bool(result.get("success", false)):
		_sync_pancake_holding_tray_to_save()
		_touch_and_write()
	return result


func advance_pancake_holding_tray(delta: float) -> void:
	if not has_save():
		return
	_ensure_pancake_holding_tray()
	_pancake_holding_tray.call("advance_time", delta)
	_sync_pancake_holding_tray_to_save()


func five_area_progression_snapshot() -> Dictionary:
	_ensure_progression()
	return Dictionary(_progression.call("snapshot")).duplicate(true)


func inventory_snapshot() -> Dictionary:
	if not has_save():
		return _new_inventory_snapshot()
	return Dictionary(_save_data.get("inventory", {})).duplicate(true)


func five_area_restock_status(stock_id: StringName) -> Dictionary:
	_ensure_progression()
	var definition := CATALOG.stock_definition(stock_id)
	if definition.is_empty():
		return {"success": false, "reason": &"unknown_stock", "stock_id": stock_id}
	if not _progression.call("owns_stock", stock_id):
		return {"success": false, "reason": &"stock_locked", "stock_id": stock_id}
	var inventory := inventory_snapshot()
	var key := str(stock_id)
	var capacity := maxi(int(definition.get("restock_capacity", 0)), 0)
	if capacity <= 0:
		return {"success": false, "reason": &"restock_unavailable", "stock_id": stock_id}
	var unit_seconds := maxf(float(definition.get("refill_seconds", 0.0)), 0.001)
	return {
		"success": true,
		"reason": &"",
		"stock_id": stock_id,
		"unit_cost": maxi(int(definition.get("restock_unit_cost", 0)), 0),
		"unit_seconds": unit_seconds,
		"current_stock": maxi(int(inventory.get(key, 0)), 0),
		"capacity": capacity,
		"progress_seconds": maxf(float(Dictionary(_save_data.get("restock_progress", {})).get(key, 0.0)), 0.0),
		"coins": maxi(int(_progression.get("coins")), 0),
	}


func advance_five_area_restock_hold(stock_id: StringName, delta: float) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save", "stock_id": stock_id}
	var status := five_area_restock_status(stock_id)
	if not bool(status.get("success", false)):
		return status
	var current := int(status.get("current_stock", 0))
	var capacity := int(status.get("capacity", 0))
	var unit_cost := int(status.get("unit_cost", 0))
	var unit_seconds := float(status.get("unit_seconds", 0.001))
	if current >= capacity:
		return _five_area_restock_result(status, false, &"capacity_reached", 0, 0)
	if int(_progression.get("coins")) < unit_cost:
		return _five_area_restock_result(status, false, &"insufficient_coins", 0, 0)
	var progress_by_stock := Dictionary(_save_data.get("restock_progress", {})).duplicate(true)
	var stock_key := str(stock_id)
	var progress := maxf(float(progress_by_stock.get(stock_key, 0.0)), 0.0) + maxf(delta, 0.0)
	var inventory := inventory_snapshot()
	var completed_units := 0
	var charged_coins := 0
	var reason: StringName = &""
	while progress + 0.0000001 >= unit_seconds:
		current = maxi(int(inventory.get(stock_key, 0)), 0)
		if current >= capacity:
			reason = &"capacity_reached"
			progress = 0.0
			break
		if int(_progression.get("coins")) < unit_cost:
			reason = &"insufficient_coins"
			progress = 0.0
			break
		inventory[stock_key] = current + 1
		_progression.set("coins", int(_progression.get("coins")) - unit_cost)
		progress = maxf(progress - unit_seconds, 0.0)
		completed_units += 1
		charged_coins += unit_cost
	if reason.is_empty() and int(inventory.get(stock_key, 0)) >= capacity:
		reason = &"capacity_reached"
		progress = 0.0
	progress_by_stock[stock_key] = progress
	_save_data["inventory"] = _normalize_inventory(inventory)
	_save_data["restock_progress"] = progress_by_stock
	_sync_progression_to_save()
	_touch_and_write()
	if completed_units > 0:
		coins_changed.emit(int(_progression.get("coins")))
		inventory_changed.emit(inventory_snapshot())
		progression_changed.emit(five_area_progression_snapshot())
	var result_status := five_area_restock_status(stock_id)
	return _five_area_restock_result(result_status, true, reason, completed_units, charged_coins)


func stable_pancake_stock_id(ingredient_id: StringName) -> StringName:
	return PANCAKE_LEGACY_TO_STABLE_STOCK_IDS.get(ingredient_id, &"") as StringName


func _five_area_restock_result(status: Dictionary, success: bool, reason: StringName, completed_units: int, charged_coins: int) -> Dictionary:
	var result := status.duplicate(true)
	result["success"] = success
	result["reason"] = reason
	result["completed_units"] = completed_units
	result["charged_coins"] = charged_coins
	result["auto_stopped"] = not reason.is_empty()
	return result


func pancake_legacy_inventory_snapshot() -> Dictionary:
	var inventory := inventory_snapshot()
	var legacy_snapshot := {}
	for legacy_id in LEGACY_PANCAKE_STOCK_IDS:
		legacy_snapshot[str(legacy_id)] = int(inventory.get(str(LEGACY_PANCAKE_STOCK_IDS[legacy_id]), 0))
	return legacy_snapshot


func save_pancake_legacy_inventory(snapshot: Dictionary) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	var inventory := inventory_snapshot()
	for legacy_id in LEGACY_PANCAKE_STOCK_IDS:
		var key := str(legacy_id)
		if snapshot.has(key):
			inventory[str(LEGACY_PANCAKE_STOCK_IDS[legacy_id])] = maxi(int(snapshot[key]), 0)
	return save_inventory(inventory)


func consume_inventory_stock_ids(stock_ids: Array[StringName]) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	var required := {}
	for stock_id in stock_ids:
		required[stock_id] = int(required.get(stock_id, 0)) + 1
	var inventory := inventory_snapshot()
	for stock_id in required:
		var key := str(stock_id)
		if int(inventory.get(key, 0)) < int(required[stock_id]):
			return {"success": false, "reason": &"insufficient_stock", "stock_id": stock_id, "required": required[stock_id], "current": int(inventory.get(key, 0))}
	for stock_id in required:
		var key := str(stock_id)
		inventory[key] = int(inventory[key]) - int(required[stock_id])
	var saved := save_inventory(inventory)
	if bool(saved.get("success", false)):
		saved["consumed_stock_ids"] = stock_ids.duplicate()
	return saved


func unlocked_ingredient_ids() -> Array[StringName]:
	_ensure_progression()
	var result: Array[StringName] = []
	for legacy_id in LEGACY_PANCAKE_STOCK_IDS:
		if bool(_progression.call("owns_stock", LEGACY_PANCAKE_STOCK_IDS[legacy_id])):
			result.append(legacy_id)
	return result


func save_inventory(snapshot: Dictionary) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	var normalized := _normalize_inventory(snapshot)
	_save_data["inventory"] = normalized
	_touch_and_write()
	inventory_changed.emit(normalized.duplicate(true))
	return {"success": true, "inventory": normalized.duplicate(true)}


func credit_coins(amount: int) -> int:
	if not has_save():
		return 0
	_ensure_progression()
	_progression.set("coins", int(_progression.get("coins")) + maxi(amount, 0))
	_sync_progression_to_save()
	_touch_and_write()
	coins_changed.emit(int(_progression.get("coins")))
	progression_changed.emit(five_area_progression_snapshot())
	return int(_progression.get("coins"))


func purchase_growth(growth_id: StringName) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_progression()
	var result: Dictionary = _progression.call("purchase", growth_id)
	if bool(result.get("success", false)):
		_sync_progression_to_save()
		_touch_and_write()
		coins_changed.emit(int(_progression.get("coins")))
		progression_changed.emit(five_area_progression_snapshot())
	return result


func growth_recommendations(limit_per_slot: int = 3) -> Dictionary:
	_ensure_progression()
	return Dictionary(_progression.call("growth_recommendations", limit_per_slot)).duplicate(true)


func growth_purchase_status(growth_id: StringName) -> Dictionary:
	_ensure_progression()
	return Dictionary(_progression.call("purchase_status", growth_id)).duplicate(true)


func abandon_active_formal_order(reason: StringName = &"business_day_expired") -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_order_service()
	var result: Dictionary = _order_service.call("abandon_active_order", reason)
	if bool(result.get("success", false)):
		_sync_formal_orders_to_save()
		_touch_and_write()
	return result


func end_business_day(cutoff: Dictionary = {}) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_progression()
	_save_data["day_open"] = false
	_progression.call("set_day_open", false)
	_save_data["today_cutoff"] = cutoff.duplicate(true)
	if StringName(cutoff.get("reason", &"")) == &"timer_expired":
		_save_data["business_day_remaining_seconds"] = 0.0
	_ensure_pancake_holding_tray()
	var tray_waste: Array = _pancake_holding_tray.call("clear_for_day_end")
	_sync_pancake_holding_tray_to_save()
	_sync_progression_to_save()
	_touch_and_write()
	var bill := today_bill()
	bill["tray_waste"] = tray_waste
	bill["success"] = true
	return bill


func begin_next_business_day() -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_progression()
	var result: Dictionary = _progression.call("begin_next_business_day")
	if not bool(result.get("success", false)):
		return result
	_save_data["day_open"] = true
	_save_data["business_day_remaining_seconds"] = BUSINESS_DAY_DURATION_SECONDS
	_save_data["today_orders"] = []
	_save_data["today_reputation_delta"] = 0
	_save_data["today_cutoff"] = {}
	_save_data["pancake_orders_issued_today"] = 0
	_progression.call("advance_tutorial_for_new_business_day")
	_replenish_daily_pancake_consumables()
	_provision_activated_stock(Array(result.get("activated_growth_ids", [])))
	_sync_progression_to_save()
	_touch_and_write()
	inventory_changed.emit(inventory_snapshot())
	progression_changed.emit(five_area_progression_snapshot())
	return result


func _replenish_daily_pancake_consumables() -> void:
	var inventory := inventory_snapshot()
	for stock_id in DAILY_PANCAKE_CONSUMABLE_STOCK:
		if not bool(_progression.call("owns_stock", stock_id)):
			continue
		var key := str(stock_id)
		inventory[key] = maxi(int(inventory.get(key, 0)), int(DAILY_PANCAKE_CONSUMABLE_STOCK[stock_id]))
	_save_data["inventory"] = _normalize_inventory(inventory)


func _provision_activated_stock(activated_growth_ids: Array) -> void:
	var inventory := inventory_snapshot()
	for growth_id_variant in activated_growth_ids:
		var definition := CATALOG.growth_definition(StringName(growth_id_variant))
		for stock_id_variant in Array(definition.get("unlock_stock_ids", [])):
			var stock_id := StringName(stock_id_variant)
			var stock_definition := CATALOG.stock_definition(stock_id)
			var capacity := maxi(int(stock_definition.get("restock_capacity", 0)), 0)
			if capacity > 0:
				var key := str(stock_id)
				inventory[key] = maxi(int(inventory.get(key, 0)), capacity)
	_save_data["inventory"] = _normalize_inventory(inventory)


func record_order_completed(order: Dictionary = {}, result: Dictionary = {}, earned_coins: int = 0, formal_order_id: StringName = &"") -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_progression()
	var settled_result := result.duplicate(true)
	var area_id: StringName = settled_result.get("area_id", &"area.pancake")
	settled_result["area_id"] = area_id
	if str(settled_result.get("grade", "")).is_empty():
		settled_result["grade"] = _grade_for_score(float(settled_result.get("score", 0.0)))
	var mastery_result: Dictionary = _progression.call("record_area_result", area_id, settled_result)
	var tutorial_completion := {}
	if bool(order.get("tutorial_no_countdown", false)) and float(settled_result.get("score", 0.0)) >= 70.0:
		tutorial_completion = _progression.call("complete_tutorial", StringName(order.get("tutorial_kind", &"")), StringName(order.get("tutorial_id", &"")))
	var payment_coins := maxi(earned_coins, 0)
	var material_cost := maxi(int(settled_result.get("material_cost", 0)), 0)
	var reputation_delta := _reputation_delta_for_result(settled_result)
	_progression.set("reputation", maxi(int(_progression.get("reputation")) + reputation_delta, 0))
	var today_orders: Array = Array(_save_data.get("today_orders", [])).duplicate(true)
	var completed_order := {
		"order_id": str(order.get("id", "unknown")),
		"title": str(order.get("title", "煎饼订单")),
		"area_id": str(area_id),
		"score": roundi(float(settled_result.get("score", 0.0))),
		"grade": str(settled_result.get("grade", "C")),
		"coins": payment_coins,
		"cost": material_cost,
		"profit": payment_coins - material_cost,
		"result": settled_result,
	}
	if not formal_order_id.is_empty():
		completed_order["formal_order_id"] = str(formal_order_id)
	today_orders.append(completed_order)
	_save_data["today_orders"] = today_orders
	_save_data["orders_completed"] = int(_save_data.get("orders_completed", 0)) + 1
	_save_data["today_reputation_delta"] = int(_save_data.get("today_reputation_delta", 0)) + reputation_delta
	_sync_progression_to_save()
	_touch_and_write()
	coins_changed.emit(int(_progression.get("coins")))
	progression_changed.emit(five_area_progression_snapshot())
	# Payment coins are credited only when the player collects the visual payment.
	return {"success": true, "mastery": mastery_result, "tutorial_completion": tutorial_completion, "pending_payment_coins": payment_coins, "reputation_delta": reputation_delta}


func today_bill() -> Dictionary:
	if not has_save():
		return {"day": 1, "orders": [], "order_count": 0, "total_coins": 0, "average_score": 0.0, "reputation_delta": 0}
	var orders: Array = Array(_save_data.get("today_orders", [])).duplicate(true)
	var total_coins := 0
	var total_cost := 0
	var total_score := 0.0
	for entry in orders:
		total_coins += int(entry.get("coins", 0))
		total_cost += maxi(int(entry.get("cost", 0)), 0)
		total_score += float(entry.get("score", 0.0))
	return {
		"day": int(_progression.get("current_day")),
		"orders": orders,
		"order_count": orders.size(),
		"total_coins": total_coins,
		"total_cost": total_cost,
		"total_profit": total_coins - total_cost,
		"average_score": total_score / maxf(float(orders.size()), 1.0),
		"reputation_delta": int(_save_data.get("today_reputation_delta", 0)),
		"cutoff": Dictionary(_save_data.get("today_cutoff", {})).duplicate(true),
	}


func get_settings() -> Dictionary:
	return _settings.duplicate(true)


func save_settings(master_volume: float, sfx_volume: float, fullscreen: bool) -> void:
	_settings = {"master_volume": clampf(master_volume, 0.0, 100.0), "sfx_volume": clampf(sfx_volume, 0.0, 100.0), "fullscreen": fullscreen}
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", _settings.master_volume)
	config.set_value("audio", "sfx_volume", _settings.sfx_volume)
	config.set_value("display", "fullscreen", _settings.fullscreen)
	config.save(SETTINGS_PATH)
	apply_settings()


func apply_settings() -> void:
	_set_bus_volume(&"Master", float(_settings.master_volume))
	_set_bus_volume(&"SFX", float(_settings.sfx_volume))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if bool(_settings.fullscreen) else DisplayServer.WINDOW_MODE_WINDOWED)
	settings_changed.emit(get_settings())


func _load_save() -> void:
	_save_data.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and int(parsed.get("version", 0)) == SAVE_VERSION and str(parsed.get("save_kind", "")) == SAVE_KIND:
		_save_data = parsed.duplicate(true)
		_ensure_save_shape()
		return
	# Development saves are deliberately incompatible with the five-area model.
	reset_incompatible_development_save()


func _restore_progression() -> void:
	_progression = PROGRESSION_SERVICE.new(Dictionary(_save_data.get("progression", {}))) if has_save() else PROGRESSION_SERVICE.new()
	_pancake_holding_tray = PANCAKE_HOLDING_TRAY_MODEL.new(Dictionary(_save_data.get("pancake_holding_tray", {})))
	_order_service = FIVE_AREA_ORDER_SERVICE.new(Dictionary(_save_data.get("formal_orders", {})))


func _ensure_progression() -> void:
	if _progression == null:
		_restore_progression()


func _ensure_pancake_holding_tray() -> void:
	if _pancake_holding_tray == null:
		_pancake_holding_tray = PANCAKE_HOLDING_TRAY_MODEL.new(Dictionary(_save_data.get("pancake_holding_tray", {})))


func _ensure_order_service() -> void:
	if _order_service == null:
		_order_service = FIVE_AREA_ORDER_SERVICE.new(Dictionary(_save_data.get("formal_orders", {})))


func _sync_progression_to_save() -> void:
	if has_save():
		_save_data["progression"] = five_area_progression_snapshot()


func _sync_pancake_holding_tray_to_save() -> void:
	if has_save():
		_save_data["pancake_holding_tray"] = pancake_holding_tray_snapshot()


func _sync_formal_orders_to_save() -> void:
	if has_save():
		_save_data["formal_orders"] = formal_order_snapshot()


func _ensure_save_shape() -> void:
	_save_data["inventory"] = _normalize_inventory(Dictionary(_save_data.get("inventory", {})))
	if not _save_data.has("restock_progress"):
		_save_data["restock_progress"] = {}
	if not _save_data.has("day_open"):
		_save_data["day_open"] = true
	if not _save_data.has("business_day_remaining_seconds"):
		_save_data["business_day_remaining_seconds"] = BUSINESS_DAY_DURATION_SECONDS
	if not _save_data.has("today_orders"):
		_save_data["today_orders"] = []
	if not _save_data.has("today_reputation_delta"):
		_save_data["today_reputation_delta"] = 0
	if not _save_data.has("today_cutoff"):
		_save_data["today_cutoff"] = {}
	if not _save_data.has("pancake_holding_tray"):
		_save_data["pancake_holding_tray"] = PANCAKE_HOLDING_TRAY_MODEL.new().snapshot()
	if not _save_data.has("formal_orders"):
		_save_data["formal_orders"] = FIVE_AREA_ORDER_SERVICE.new().snapshot()
	if not _save_data.has("pancake_order_cursor"):
		_save_data["pancake_order_cursor"] = 0
	if not _save_data.has("pancake_orders_issued_today"):
		_save_data["pancake_orders_issued_today"] = 0
	if not _save_data.has(RECONCILED_FORMAL_ORDER_IDS_KEY):
		_save_data[RECONCILED_FORMAL_ORDER_IDS_KEY] = []


func _reconcile_unrecorded_settled_orders() -> void:
	if not has_save():
		return
	# A payment callback can stop after the formal order is durable but before
	# the daily bill and collected coins are written.  The formal settlement is
	# authoritative, so repair that missing tail once at startup.
	var reconciled_ids := PackedStringArray(Array(_save_data.get(RECONCILED_FORMAL_ORDER_IDS_KEY, [])))
	var recorded_formal_ids := {}
	var legacy_record_counts := {}
	for completed_order_value in Array(_save_data.get("today_orders", [])):
		var completed_order: Dictionary = Dictionary(completed_order_value)
		var recorded_formal_id := StringName(completed_order.get("formal_order_id", &""))
		if not recorded_formal_id.is_empty():
			recorded_formal_ids[recorded_formal_id] = true
			continue
		var legacy_order_id := str(completed_order.get("order_id", ""))
		legacy_record_counts[legacy_order_id] = int(legacy_record_counts.get(legacy_order_id, 0)) + 1
	var formal_orders: Dictionary = Dictionary(Dictionary(_save_data.get("formal_orders", {})).get("orders", {}))
	var settled_orders: Array[Dictionary] = []
	for raw_formal_order_id in formal_orders:
		var formal_order_id := StringName(raw_formal_order_id)
		var formal_order: Dictionary = Dictionary(formal_orders[raw_formal_order_id])
		if StringName(formal_order.get("state", &"")) == &"settled":
			settled_orders.append({"order_id": formal_order_id, "order": formal_order})
	settled_orders.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(Dictionary(left.get("order", {})).get("sequence", 0)) < int(Dictionary(right.get("order", {})).get("sequence", 0))
	)
	var reconciliation_changed := false
	for entry in settled_orders:
		var formal_order_id: StringName = entry.get("order_id", &"")
		if reconciled_ids.has(str(formal_order_id)) or recorded_formal_ids.has(formal_order_id):
			continue
		var formal_order: Dictionary = Dictionary(entry.get("order", {}))
		var legacy_order: Dictionary = Dictionary(Dictionary(formal_order.get("metadata", {})).get("legacy_order", {}))
		var legacy_order_id := str(legacy_order.get("id", ""))
		# Older saves do not have formal-order IDs on daily-bill rows.  Consume a
		# matching legacy row once so that upgrading cannot pay it a second time.
		if not legacy_order_id.is_empty() and int(legacy_record_counts.get(legacy_order_id, 0)) > 0:
			legacy_record_counts[legacy_order_id] = int(legacy_record_counts[legacy_order_id]) - 1
			reconciled_ids.append(str(formal_order_id))
			reconciliation_changed = true
			continue
		var items: Array = Array(formal_order.get("items", []))
		var product: Dictionary = Dictionary(items[0].get("attached_product", {})) if not items.is_empty() else {}
		if legacy_order.is_empty() or product.is_empty():
			continue
		var score := float(product.get("score", 0.0))
		var recovered_result := {
			"area_id": product.get("area_id", &"area.pancake"),
			"product_id": product.get("product_id", &"product.pancake.custom"),
			"score": score,
			"grade": _grade_for_score(score),
			"dimensions": Dictionary(product.get("dimension_scores", {})).duplicate(true),
			"material_cost": int(product.get("material_cost", 0)),
			"feedback": "已恢复中断前完成的订单",
		}
		var payment_coins := maxi(int(legacy_order.get("payment_coins", 0)), 0)
		record_order_completed(legacy_order, recovered_result, payment_coins, formal_order_id)
		credit_coins(payment_coins)
		reconciled_ids.append(str(formal_order_id))
		reconciliation_changed = true
	if reconciliation_changed:
		_save_data[RECONCILED_FORMAL_ORDER_IDS_KEY] = reconciled_ids
		_touch_and_write()


func _new_inventory_snapshot() -> Dictionary:
	var inventory := {}
	for stock_id in CATALOG.stock_ids():
		inventory[str(stock_id)] = 0
	for stock_id in [&"stock.pancake.batter", &"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.scallion", &"stock.pancake.sauce.sweet_flour"]:
		inventory[str(stock_id)] = 6
	return inventory


func _normalize_inventory(source: Dictionary) -> Dictionary:
	var normalized := _new_inventory_snapshot()
	for stock_id in CATALOG.stock_ids():
		var key := str(stock_id)
		if source.has(key):
			normalized[key] = maxi(int(source[key]), 0)
	return normalized


func _stable_pancake_stock_ids(source_ids: Array, mapping: Dictionary) -> PackedStringArray:
	var stable_ids := PackedStringArray()
	for source_id in source_ids:
		var requested: StringName = StringName(source_id)
		var stable_id: StringName = requested if str(requested).begins_with("stock.") else mapping.get(requested, &"")
		if not stable_id.is_empty():
			stable_ids.append(str(stable_id))
	return stable_ids


func _touch_and_write() -> void:
	_save_data["last_played_at_unix"] = int(Time.get_unix_time_from_system())
	_write_save()


func _write_save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write ProjectCake save data")
		return
	file.store_string(JSON.stringify(_save_data, "\t"))


func _load_settings() -> void:
	_settings = DEFAULT_SETTINGS.duplicate(true)
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	_settings.master_volume = clampf(float(config.get_value("audio", "master_volume", DEFAULT_SETTINGS.master_volume)), 0.0, 100.0)
	_settings.sfx_volume = clampf(float(config.get_value("audio", "sfx_volume", DEFAULT_SETTINGS.sfx_volume)), 0.0, 100.0)
	_settings.fullscreen = bool(config.get_value("display", "fullscreen", DEFAULT_SETTINGS.fullscreen))


func _set_bus_volume(bus_name: StringName, percent: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var normalized := clampf(percent / 100.0, 0.0, 1.0)
	AudioServer.set_bus_mute(bus_index, normalized <= 0.0001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(normalized, 0.0001)))


func _format_timestamp(timestamp: int) -> String:
	if timestamp <= 0:
		return "未知时间"
	var datetime := Time.get_datetime_dict_from_unix_time(timestamp)
	return "%04d/%02d/%02d  %02d:%02d" % [datetime.year, datetime.month, datetime.day, datetime.hour, datetime.minute]


func _reputation_delta_for_result(result: Dictionary) -> int:
	var grade := str(result.get("grade", ""))
	if grade == "A":
		return 4
	if grade == "B":
		return 2
	return 0


func _grade_for_score(score: float) -> String:
	if score >= 85.0:
		return "A"
	if score >= 65.0:
		return "B"
	return "C"
