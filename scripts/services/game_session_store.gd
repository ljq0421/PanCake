extends Node

signal settings_changed(current_settings: Dictionary)
signal coins_changed(current_coins: int)
signal progression_changed(snapshot: Dictionary)
signal inventory_changed(snapshot: Dictionary)

const SAVE_PATH := "user://project_cake_save.json"
const SETTINGS_PATH := "user://project_cake_settings.cfg"
const SAVE_VERSION := 3
const SAVE_KIND := "five_area_v1"
const PROGRESSION_SERVICE := preload("res://scripts/services/five_area_progression_service.gd")
const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const PANCAKE_HOLDING_TRAY_MODEL := preload("res://scripts/gameplay/pancake_holding_tray_model.gd")
const FIVE_AREA_ORDER_SERVICE := preload("res://scripts/services/five_area_order_service.gd")
const LEGACY_PANCAKE_STOCK_IDS := {
	&"egg": &"stock.pancake.egg",
	&"baocui": &"stock.pancake.baocui",
	&"scallion": &"stock.pancake.scallion",
	&"ham_sausage": &"stock.pancake.ham_sausage",
	&"meat_floss": &"stock.pancake.meat_floss",
	&"pork_tenderloin": &"stock.pancake.pork_tenderloin",
}
const LEGACY_PANCAKE_SAUCE_STOCK_IDS := {
	&"sweet_flour": &"stock.pancake.sauce.sweet_flour",
	&"red_chili": &"stock.pancake.sauce.red_chili",
}
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
		"orders_completed": 0,
		"today_orders": [],
		"today_reputation_delta": 0,
		"progression": _progression.call("snapshot"),
		"inventory": _new_inventory_snapshot(),
		"restock_progress": {},
		"pancake_holding_tray": PANCAKE_HOLDING_TRAY_MODEL.new().snapshot(),
		"formal_orders": FIVE_AREA_ORDER_SERVICE.new().snapshot(),
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


## Kept temporarily so unrelated title UI can query a snapshot.  It is no
## longer a write path for the retired three-device adapter.
func workstation_progression_snapshot() -> Dictionary:
	return five_area_progression_snapshot()


func inventory_snapshot() -> Dictionary:
	if not has_save():
		return _new_inventory_snapshot()
	return Dictionary(_save_data.get("inventory", {})).duplicate(true)


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


func save_workstation_progression(_retired_snapshot: Dictionary) -> Dictionary:
	return {"success": false, "reason": &"retired_legacy_progression_write"}


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


func end_business_day() -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_progression()
	_save_data["day_open"] = false
	_progression.call("set_day_open", false)
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
	_save_data["today_orders"] = []
	_save_data["today_reputation_delta"] = 0
	_sync_progression_to_save()
	_touch_and_write()
	progression_changed.emit(five_area_progression_snapshot())
	return result


func record_order_completed(order: Dictionary = {}, result: Dictionary = {}, earned_coins: int = 0) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_progression()
	var settled_result := result.duplicate(true)
	var area_id: StringName = settled_result.get("area_id", &"area.pancake")
	settled_result["area_id"] = area_id
	if str(settled_result.get("grade", "")).is_empty():
		settled_result["grade"] = _grade_for_score(float(settled_result.get("score", 0.0)))
	var mastery_result: Dictionary = _progression.call("record_area_result", area_id, settled_result)
	var payment_coins := maxi(earned_coins, 0)
	var reputation_delta := _reputation_delta_for_result(settled_result)
	_progression.set("reputation", maxi(int(_progression.get("reputation")) + reputation_delta, 0))
	var today_orders: Array = Array(_save_data.get("today_orders", [])).duplicate(true)
	today_orders.append({
		"order_id": str(order.get("id", "unknown")),
		"title": str(order.get("title", "煎饼订单")),
		"area_id": str(area_id),
		"score": roundi(float(settled_result.get("score", 0.0))),
		"grade": str(settled_result.get("grade", "C")),
		"coins": payment_coins,
		"result": settled_result,
	})
	_save_data["today_orders"] = today_orders
	_save_data["orders_completed"] = int(_save_data.get("orders_completed", 0)) + 1
	_save_data["today_reputation_delta"] = int(_save_data.get("today_reputation_delta", 0)) + reputation_delta
	_sync_progression_to_save()
	_touch_and_write()
	coins_changed.emit(int(_progression.get("coins")))
	progression_changed.emit(five_area_progression_snapshot())
	# Payment coins are credited only when the player collects the visual payment.
	return {"success": true, "mastery": mastery_result, "pending_payment_coins": payment_coins, "reputation_delta": reputation_delta}


func today_bill() -> Dictionary:
	if not has_save():
		return {"day": 1, "orders": [], "order_count": 0, "total_coins": 0, "average_score": 0.0, "reputation_delta": 0}
	var orders: Array = Array(_save_data.get("today_orders", [])).duplicate(true)
	var total_coins := 0
	var total_score := 0.0
	for entry in orders:
		total_coins += int(entry.get("coins", 0))
		total_score += float(entry.get("score", 0.0))
	return {
		"day": int(_progression.get("current_day")),
		"orders": orders,
		"order_count": orders.size(),
		"total_coins": total_coins,
		"average_score": total_score / maxf(float(orders.size()), 1.0),
		"reputation_delta": int(_save_data.get("today_reputation_delta", 0)),
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
	if not _save_data.has("today_orders"):
		_save_data["today_orders"] = []
	if not _save_data.has("today_reputation_delta"):
		_save_data["today_reputation_delta"] = 0
	if not _save_data.has("pancake_holding_tray"):
		_save_data["pancake_holding_tray"] = PANCAKE_HOLDING_TRAY_MODEL.new().snapshot()
	if not _save_data.has("formal_orders"):
		_save_data["formal_orders"] = FIVE_AREA_ORDER_SERVICE.new().snapshot()


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
