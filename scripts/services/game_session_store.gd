extends Node

signal settings_changed(current_settings: Dictionary)

const SAVE_PATH := "user://project_cake_save.json"
const SETTINGS_PATH := "user://project_cake_settings.cfg"
const SAVE_VERSION := 1
const DEFAULT_ORDER_COINS := 3
const DEFAULT_INGREDIENT_STOCK := {
	"egg": 6,
	"baocui": 6,
	"ham_sausage": 6,
	"scallion": 6,
}
const DEFAULT_SETTINGS := {
	"master_volume": 80.0,
	"sfx_volume": 85.0,
	"fullscreen": false,
}

var _save_data: Dictionary = {}
var _settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)


func _ready() -> void:
	_load_save()
	_load_settings()
	apply_settings()


func has_save() -> bool:
	return not _save_data.is_empty() and int(_save_data.get("version", 0)) == SAVE_VERSION


func begin_new_game() -> void:
	var now := int(Time.get_unix_time_from_system())
	_save_data = {
		"version": SAVE_VERSION,
		"started_at_unix": now,
		"last_played_at_unix": now,
		"orders_completed": 0,
		"current_day": 1,
		"day_open": true,
		"today_orders": [],
		"ingredient_stock": DEFAULT_INGREDIENT_STOCK.duplicate(true),
	}
	_write_save()


func continue_game() -> bool:
	if not has_save():
		return false
	_save_data["last_played_at_unix"] = int(Time.get_unix_time_from_system())
	_write_save()
	return true


func mark_session_left() -> void:
	if not has_save():
		return
	_save_data["last_played_at_unix"] = int(Time.get_unix_time_from_system())
	_write_save()


func record_order_completed(order: Dictionary = {}, result: Dictionary = {}, earned_coins: int = DEFAULT_ORDER_COINS) -> void:
	if not has_save():
		return
	_ensure_day_fields()
	_save_data["orders_completed"] = int(_save_data.get("orders_completed", 0)) + 1
	var entry := {
		"order_id": str(order.get("id", "unknown")),
		"title": str(order.get("title", "未命名订单")),
		"score": roundi(float(result.get("score", 0.0))),
		"feedback": str(result.get("feedback", "")),
		"tags": Array(result.get("tags", [])),
		"coins": maxi(earned_coins, 0),
		"completed_at_unix": int(Time.get_unix_time_from_system()),
	}
	var today_orders: Array = _save_data.get("today_orders", [])
	today_orders.append(entry)
	_save_data["today_orders"] = today_orders
	_save_data["last_played_at_unix"] = int(Time.get_unix_time_from_system())
	_write_save()


func today_bill() -> Dictionary:
	if not has_save():
		return {"day": 1, "orders": [], "order_count": 0, "total_coins": 0, "average_score": 0.0}
	_ensure_day_fields()
	var orders: Array = Array(_save_data.get("today_orders", [])).duplicate(true)
	var total_coins := 0
	var total_score := 0.0
	for entry in orders:
		total_coins += int(entry.get("coins", 0))
		total_score += float(entry.get("score", 0.0))
	return {
		"day": int(_save_data.get("current_day", 1)),
		"orders": orders,
		"order_count": orders.size(),
		"total_coins": total_coins,
		"average_score": total_score / maxf(float(orders.size()), 1.0),
	}


func ingredient_stock_snapshot() -> Dictionary:
	if not has_save():
		return DEFAULT_INGREDIENT_STOCK.duplicate(true)
	_ensure_day_fields()
	return Dictionary(_save_data.get("ingredient_stock", DEFAULT_INGREDIENT_STOCK)).duplicate(true)


func save_ingredient_stock(snapshot: Dictionary) -> void:
	if not has_save():
		return
	var sanitized := {}
	for ingredient_id in DEFAULT_INGREDIENT_STOCK:
		sanitized[ingredient_id] = clampi(int(snapshot.get(ingredient_id, DEFAULT_INGREDIENT_STOCK[ingredient_id])), 0, 6)
	_save_data["ingredient_stock"] = sanitized
	_save_data["last_played_at_unix"] = int(Time.get_unix_time_from_system())
	_write_save()


func end_business_day() -> Dictionary:
	if not has_save():
		return today_bill()
	_ensure_day_fields()
	_save_data["day_open"] = false
	_save_data["last_bill"] = today_bill()
	_save_data["last_played_at_unix"] = int(Time.get_unix_time_from_system())
	_write_save()
	return Dictionary(_save_data["last_bill"]).duplicate(true)


func resume_summary() -> String:
	if not has_save():
		return "还没有营业记录，新游戏会从第一位顾客开始。"
	var timestamp := int(_save_data.get("last_played_at_unix", 0))
	var orders := int(_save_data.get("orders_completed", 0))
	return "上次营业  %s  ·  已完成 %d 单" % [_format_timestamp(timestamp), orders]


func get_settings() -> Dictionary:
	return _settings.duplicate(true)


func save_settings(master_volume: float, sfx_volume: float, fullscreen: bool) -> void:
	_settings = {
		"master_volume": clampf(master_volume, 0.0, 100.0),
		"sfx_volume": clampf(sfx_volume, 0.0, 100.0),
		"fullscreen": fullscreen,
	}
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", _settings.master_volume)
	config.set_value("audio", "sfx_volume", _settings.sfx_volume)
	config.set_value("display", "fullscreen", _settings.fullscreen)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Could not save ProjectCake settings: %s" % error_string(error))
	apply_settings()


func apply_settings() -> void:
	_set_bus_volume(&"Master", float(_settings.master_volume))
	_set_bus_volume(&"SFX", float(_settings.sfx_volume))
	if DisplayServer.get_name() != "headless":
		var target_mode := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(_settings.fullscreen) else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != target_mode:
			DisplayServer.window_set_mode(target_mode)
	settings_changed.emit(get_settings())


func _load_save() -> void:
	_save_data.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and int(parsed.get("version", 0)) == SAVE_VERSION:
		_save_data = parsed
		_ensure_day_fields()


func _ensure_day_fields() -> void:
	if _save_data.is_empty():
		return
	if not _save_data.has("current_day"):
		_save_data["current_day"] = 1
	if not _save_data.has("day_open"):
		_save_data["day_open"] = true
	if not _save_data.has("today_orders"):
		_save_data["today_orders"] = []
	if not _save_data.has("ingredient_stock"):
		_save_data["ingredient_stock"] = DEFAULT_INGREDIENT_STOCK.duplicate(true)


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
