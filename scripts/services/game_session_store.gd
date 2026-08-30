extends Node

signal settings_changed(current_settings: Dictionary)
signal coins_changed(current_coins: int)
signal progression_changed(snapshot: Dictionary)
signal inventory_changed(snapshot: Dictionary)
signal production_changed(snapshot: Dictionary)
signal order_changed(snapshot: Dictionary)
signal order_settled(result: Dictionary)
signal daily_goal_changed(snapshot: Dictionary)
signal business_ledger_changed(snapshot: Dictionary)
signal prepared_product_slots_changed(snapshot: Dictionary)

const SAVE_PATH := "user://project_cake_save.json"
const SOY_TEST_SAVE_PATH := "user://project_cake_soy_test_save.json"
const SETTINGS_PATH := "user://project_cake_settings.cfg"
const SAVE_WRITE_MERGE_SECONDS := 2.0
const SAVE_TEMP_SUFFIX := ".tmp"
const SAVE_BACKUP_SUFFIX := ".bak"
## The four-area/single-griddle contract intentionally starts a fresh
## development save lineage.  Any earlier development save is discarded rather
## than being partially migrated into a different economy.
const SAVE_VERSION := 10
const SAVE_KIND := "breakfast_stall_four_area_v1"
const ORDER_PROMOTIONS_KEY := "pending_order_promotions"
const SPECIAL_CUSTOMER_STATE_KEY := "special_customer_state"
const FIRST_BUSINESS_DAY_DURATION_SECONDS := 60.0
const BUSINESS_DAY_DURATION_SECONDS := 120.0
const OPENING_RESTOCK_SECONDS := 5.0
## Walk-in pressure grows only when both the calendar and the available
## production footprint can support it.  The physical storefront still owns
## five slots, but a new player is never asked to manage all five at once.
const CUSTOMER_ARRIVAL_WINDOWS_BY_CAPACITY := {
	2: Vector2(10.0, 14.0),
	3: Vector2(8.0, 12.0),
	4: Vector2(6.0, 9.0),
	5: Vector2(4.5, 7.0),
}
const CUSTOMER_PATIENCE_BASE_GRACE_SECONDS := 16.0
const CUSTOMER_PATIENCE_FIRST_DAY_BONUS_SECONDS := 8.0
const CUSTOMER_PATIENCE_QUEUE_GRACE_SECONDS := 10.0
const CUSTOMER_SERVICE_ESTIMATE_SECONDS := {
	&"area.pancake": 66.0,
	&"area.youtiao": 18.0,
	&"area.fresh_soy_milk": 16.0,
	&"area.packaged_drink": 8.0,
}
const CONSOLATION_PAYMENT_COINS := 1
const PROGRESSION_SERVICE := preload("res://scripts/services/five_area_progression_service.gd")
const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const PANCAKE_HOLDING_TRAY_MODEL := preload("res://scripts/gameplay/pancake_holding_tray_model.gd")
const PANCAKE_SCORER := preload("res://scripts/gameplay/pancake_scorer.gd")
const FIVE_AREA_ORDER_SERVICE := preload("res://scripts/services/five_area_order_service.gd")
const FIVE_AREA_PRODUCTION_SERVICE := preload("res://scripts/services/five_area_production_service.gd")
const FIVE_AREA_PANCAKE_ORDER_GENERATOR := preload("res://scripts/services/five_area_pancake_order_generator.gd")
const FIVE_AREA_PLAYABLE_ORDER_GENERATOR := preload("res://scripts/services/five_area_playable_order_generator.gd")
const SPECIAL_CUSTOMER_CATALOG := preload("res://scripts/data/special_customer_catalog.gd")
const SPECIAL_CUSTOMER_SETTLEMENT := preload("res://scripts/services/special_customer_settlement.gd")
const BUSINESS_REPORT_SERVICE := preload("res://scripts/services/business_report_service.gd")
const DAILY_GOAL_SERVICE := preload("res://scripts/services/daily_goal_service.gd")
const ATTENTION_SERVICE := preload("res://scripts/services/attention_service.gd")
const PREPARED_PRODUCT_SLOT_DEFINITIONS := {
	&"slot.04": {
		"product_id": &"product.youtiao.plain",
		"recipe_id": &"recipe.youtiao.plain",
		"requires_growth_id": &"growth.capacity.youtiao_finished_tray",
		"accepted_product_ids": [&"product.youtiao.plain"],
	},
	&"slot.chicken": {
		"product_id": &"product.chicken.cutlet",
		"recipe_id": &"recipe.chicken.cutlet",
		"requires_growth_id": &"growth.capacity.chicken_finished_tray",
		"accepted_product_ids": [&"product.chicken.cutlet"],
	},
}
const DEBUG_TIER_GROWTH_IDS := {
	&"area.pancake": [&""],
	&"area.youtiao": [&"growth.area.youtiao"],
	&"area.fresh_soy_milk": [&"growth.area.fresh_soy_milk"],
}
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
	&"youtiao": &"stock.pancake.youtiao",
}
const RECONCILED_FORMAL_ORDER_IDS_KEY := "reconciled_formal_order_ids"
const DEFAULT_SETTINGS := {
	"master_volume": 80.0,
	"sfx_volume": 85.0,
	"fullscreen": false,
	"ui_scale": 100.0,
	"drag_sensitivity": 100.0,
	"key_bindings": {
		"tool_ladle": KEY_1,
		"tool_spreader": KEY_2,
		"tool_sauce_brush": KEY_3,
		"tool_fold_package": KEY_4,
	},
}

var _save_data: Dictionary = {}
var _active_save_path := SAVE_PATH
var _active_settings_path := SETTINGS_PATH
var _settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var _progression: RefCounted
var _pancake_holding_tray: RefCounted
var _order_service: RefCounted
var _production_service: RefCounted
var _business_report_service: RefCounted
var _daily_goal_service: RefCounted
var _incompatible_development_save_removed := false
var _save_write_count := 0
var _save_dirty := false
var _save_flush_elapsed := 0.0
var _scene_binding_save_batch_active := false
var _scene_binding_save_pending := false
var _scene_binding_save_snapshot: Dictionary = {}
var _scene_binding_save_dirty_before_batch := false
var _scene_binding_save_flush_elapsed_before_batch := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_save()
	_restore_progression()
	_reconcile_completed_tutorial_order()
	_reconcile_unrecorded_settled_orders()
	# Customer arrivals are durable state and resume from the saved countdown.
	# Do not synthesize a queue while loading a scene: a newly opened shop must
	# remain empty through its opening restock window.
	_load_settings()
	apply_settings()


func _process(delta: float) -> void:
	if not _save_dirty or _scene_binding_save_batch_active:
		return
	_save_flush_elapsed += maxf(delta, 0.0)
	if _save_flush_elapsed >= SAVE_WRITE_MERGE_SECONDS:
		_write_save()


func _exit_tree() -> void:
	flush_pending_save()


func has_save() -> bool:
	return not _save_data.is_empty() and int(_save_data.get("version", 0)) == SAVE_VERSION and str(_save_data.get("save_kind", "")) == SAVE_KIND


func is_five_area_save_active() -> bool:
	return has_save()


## Canonical public name for the current four-area save contract.
func is_four_area_save_active() -> bool:
	return has_save()


func open_soy_test_profile() -> Dictionary:
	# Keep the developer-facing soy test save in a separate user:// file.  The
	# normal save remains loaded at startup and is never overwritten by the
	# start-menu test-profile shortcut.
	_active_save_path = SOY_TEST_SAVE_PATH
	var result := begin_new_game()
	if not bool(result.get("success", false)):
		return result
	var progression := progression_service()
	progression.set("unlocked_area_ids", {
		&"area.pancake": true,
		&"area.fresh_soy_milk": true,
	})
	progression.set("device_tiers", {
		&"device.pancake_griddle": 0,
		&"device.fresh_soy_milk_machine": 0,
	})
	progression.set("unlocked_recipe_ids", {
		&"recipe.pancake.base": true,
		&"recipe.fresh_soy_milk.yellow_bean": true,
	})
	progression.set("unlocked_product_ids", {
		&"product.pancake.custom": true,
		&"product.fresh_soy_milk.yellow_bean": true,
	})
	_sync_progression_to_save()
	_production_service = null
	_ensure_production_service()
	var order_result := open_formal_order([{
		"area_id": &"area.fresh_soy_milk",
		"product_id": &"product.fresh_soy_milk.yellow_bean",
		"quantity": 1,
		"ingredient_ids": PackedStringArray(),
		"sauce_ids": PackedStringArray(),
		"sugar_servings": 0,
	}], {"patience_seconds": 120.0, "base_coins": 7})
	if not bool(order_result.get("success", false)):
		return order_result
	_sync_production_to_save()
	_touch_and_write()
	return {"success": true, "profile": &"soy_test"}


func uses_five_area_progression() -> bool:
	return true


## Canonical public name for the current four-area progression contract.
func uses_four_area_progression() -> bool:
	return true


func incompatible_development_save_was_removed() -> bool:
	return _incompatible_development_save_removed


func begin_new_game() -> Dictionary:
	var now := int(Time.get_unix_time_from_system())
	_progression = PROGRESSION_SERVICE.new()
	_pancake_holding_tray = PANCAKE_HOLDING_TRAY_MODEL.new()
	_order_service = FIVE_AREA_ORDER_SERVICE.new()
	_production_service = FIVE_AREA_PRODUCTION_SERVICE.new(self)
	_business_report_service = BUSINESS_REPORT_SERVICE.new()
	_business_report_service.call("begin_day", 1)
	_daily_goal_service = DAILY_GOAL_SERVICE.new()
	_save_data = {
		"version": SAVE_VERSION,
		"save_kind": SAVE_KIND,
		"started_at_unix": now,
		"last_played_at_unix": now,
		"day_open": true,
		"business_paused": false,
		"business_day_remaining_seconds": FIRST_BUSINESS_DAY_DURATION_SECONDS,
		"customer_arrival": _new_customer_arrival_state(now),
		"orders_completed": 0,
		"today_orders": [],
		"today_reputation_delta": 0,
		"today_cutoff": {},
		"progression": _progression.call("snapshot"),
		"inventory": _new_inventory_snapshot(),
		"restock_progress": {},
		"pending_tray_payments": {},
		"prepared_product_slots": _empty_prepared_product_slots(),
		"pancake_holding_tray": PANCAKE_HOLDING_TRAY_MODEL.new().snapshot(),
		"formal_orders": FIVE_AREA_ORDER_SERVICE.new().snapshot(),
		"production": _production_service.call("snapshot"),
		"today_ledger": _business_report_service.call("snapshot"),
		"daily_goal": _daily_goal_service.call("snapshot"),
		"last_bill": {},
		"ledger_event_sequence": 0,
		RECONCILED_FORMAL_ORDER_IDS_KEY: [],
		"pancake_order_cursor": 0,
		"pancake_orders_issued_today": 0,
		"order_rng_seed": now,
		"order_sequence": 0,
		"tutorial_order_generated_day": 0,
		ORDER_PROMOTIONS_KEY: [],
		SPECIAL_CUSTOMER_STATE_KEY: SPECIAL_CUSTOMER_CATALOG.default_state(1),
	}
	_configure_service_connections()
	_write_save()
	progression_changed.emit(five_area_progression_snapshot())
	inventory_changed.emit(inventory_snapshot())
	production_changed.emit(five_area_production_snapshot())
	prepared_product_slots_changed.emit(prepared_product_slots_snapshot())
	return {"success": true, "snapshot": _save_data.duplicate(true)}


func continue_game() -> bool:
	if not has_save():
		return false
	_save_data["last_played_at_unix"] = int(Time.get_unix_time_from_system())
	_save_data["business_paused"] = true
	_write_save()
	return true


func begin_scene_binding_save_batch() -> bool:
	if _scene_binding_save_batch_active:
		return false
	_scene_binding_save_batch_active = true
	_scene_binding_save_pending = false
	_scene_binding_save_snapshot = _save_data.duplicate(true)
	_scene_binding_save_dirty_before_batch = _save_dirty
	_scene_binding_save_flush_elapsed_before_batch = _save_flush_elapsed
	return true


func commit_scene_binding_save_batch() -> void:
	if not _scene_binding_save_batch_active:
		return
	var should_write := _scene_binding_save_pending
	_scene_binding_save_active_reset()
	if should_write:
		_write_save()


func rollback_scene_binding_save_batch() -> void:
	if not _scene_binding_save_batch_active:
		return
	_save_data = _scene_binding_save_snapshot.duplicate(true)
	_scene_binding_save_pending = false
	_save_dirty = _scene_binding_save_dirty_before_batch
	_save_flush_elapsed = _scene_binding_save_flush_elapsed_before_batch
	_restore_progression()
	_scene_binding_save_active_reset()


func _scene_binding_save_active_reset() -> void:
	_scene_binding_save_batch_active = false
	_scene_binding_save_pending = false
	_scene_binding_save_snapshot.clear()
	_scene_binding_save_dirty_before_batch = false
	_scene_binding_save_flush_elapsed_before_batch = 0.0


func business_day_remaining_seconds() -> float:
	var duration_seconds := business_day_duration_seconds()
	if not has_save():
		return duration_seconds
	return clampf(float(_save_data.get("business_day_remaining_seconds", duration_seconds)), 0.0, duration_seconds)


func business_day_duration_seconds() -> float:
	# Day one starts with an unlimited tutorial. Once it is completed, the
	# already-prepared one-minute countdown begins; later days use the normal
	# two-minute service window.
	if _progression != null and int(_progression.get("current_day")) == 1:
		return FIRST_BUSINESS_DAY_DURATION_SECONDS
	return BUSINESS_DAY_DURATION_SECONDS


func set_business_day_remaining_seconds(remaining_seconds: float) -> void:
	if not has_save():
		return
	_save_data["business_day_remaining_seconds"] = clampf(remaining_seconds, 0.0, business_day_duration_seconds())
	_touch_and_write()


func resume_summary() -> String:
	if not has_save():
		return "还没有营业记录，新游戏会从第一位顾客开始。"
	var timestamp := int(_save_data.get("last_played_at_unix", 0))
	var orders := int(_save_data.get("orders_completed", 0))
	return "上次营业  %s  ·  已完成 %d 单" % [_format_timestamp(timestamp), orders]


func reset_incompatible_development_save() -> Dictionary:
	_save_data.clear()
	_save_dirty = false
	_save_flush_elapsed = 0.0
	_progression = PROGRESSION_SERVICE.new()
	var absolute_path := ProjectSettings.globalize_path(_active_save_path)
	var removed := false
	if FileAccess.file_exists(_active_save_path):
		removed = DirAccess.remove_absolute(absolute_path) == OK
	_remove_file_if_present(absolute_path + SAVE_TEMP_SUFFIX)
	_remove_file_if_present(absolute_path + SAVE_BACKUP_SUFFIX)
	_incompatible_development_save_removed = removed
	return {"success": removed or not FileAccess.file_exists(_active_save_path), "removed": removed}


func progression_service() -> RefCounted:
	_ensure_progression()
	return _progression


func order_service() -> RefCounted:
	_ensure_order_service()
	return _order_service


func production_service() -> RefCounted:
	_ensure_production_service()
	return _production_service


func business_report_service() -> RefCounted:
	_ensure_business_services()
	return _business_report_service


func daily_goal_service() -> RefCounted:
	_ensure_business_services()
	return _daily_goal_service


func current_daily_goal() -> Dictionary:
	_ensure_business_services()
	return Dictionary(_daily_goal_service.call("current_goal")).duplicate(true)


func is_business_paused() -> bool:
	return bool(_save_data.get("business_paused", false))


func set_business_paused(paused: bool) -> void:
	if not has_save() or is_business_paused() == paused:
		return
	_save_data["business_paused"] = paused
	_touch_and_write()


## The opening window and the next independent walk-in are durable business
## state.  Keeping this outside the order service prevents scene reloads from
## silently filling the storefront.
func customer_arrival_snapshot() -> Dictionary:
	if not has_save():
		return _new_customer_arrival_state(1)
	return _normalized_customer_arrival_state(Dictionary(_save_data.get("customer_arrival", {})))


func is_opening_restock_active() -> bool:
	return StringName(customer_arrival_snapshot().get("phase", &"")) == &"restocking"


func customer_pressure_snapshot() -> Dictionary:
	_ensure_progression()
	var progression_snapshot := five_area_progression_snapshot()
	var current_day := maxi(int(progression_snapshot.get("current_day", 1)), 1)
	var unlocked_area_count := maxi(Array(progression_snapshot.get("unlocked_area_ids", [])).size(), 1)
	# Day 1 is capped at two. Each later day may add one position, while each
	# unlocked production area after pancake permits one further position.
	var capacity := clampi(mini(current_day + 1, unlocked_area_count + 2), 2, FIVE_AREA_ORDER_SERVICE.MAX_ACTIVE_CUSTOMERS)
	var arrival_window: Vector2 = CUSTOMER_ARRIVAL_WINDOWS_BY_CAPACITY.get(capacity, Vector2(10.0, 14.0))
	return {
		"capacity": capacity,
		"current_day": current_day,
		"unlocked_area_count": unlocked_area_count,
		"arrival_min_seconds": arrival_window.x,
		"arrival_max_seconds": arrival_window.y,
	}


func advance_customer_arrivals(delta: float) -> Dictionary:
	if not has_save() or delta <= 0.0 or get_tree().paused or is_business_paused():
		return {"success": true, "changed": false, "state": customer_arrival_snapshot(), "entered_orders": []}
	_ensure_progression()
	if not bool(_progression.get("day_open")):
		return {"success": true, "changed": false, "state": customer_arrival_snapshot(), "entered_orders": []}
	_ensure_order_service()
	var before := customer_arrival_snapshot()
	var state := before.duplicate(true)
	var entered_orders: Array[Dictionary] = []
	var changed := false
	if StringName(state.get("phase", &"restocking")) == &"restocking":
		state["restock_remaining_seconds"] = maxf(float(state.get("restock_remaining_seconds", OPENING_RESTOCK_SECONDS)) - delta, 0.0)
		changed = not is_equal_approx(float(state["restock_remaining_seconds"]), float(before.get("restock_remaining_seconds", OPENING_RESTOCK_SECONDS)))
		if float(state["restock_remaining_seconds"]) <= 0.0:
			state["phase"] = &"open"
			state["next_arrival_remaining_seconds"] = -1.0
			changed = true
			var first_arrival := ensure_active_playable_order(1)
			for order_variant in Array(first_arrival.get("created_orders", [])):
				entered_orders.append(Dictionary(order_variant).duplicate(true))
			_schedule_next_customer_arrival(state)
	else:
		var active_count := active_formal_orders().size()
		var capacity := int(customer_pressure_snapshot().get("capacity", 2))
		if active_count >= capacity:
			if float(state.get("next_arrival_remaining_seconds", -1.0)) >= 0.0:
				state["next_arrival_remaining_seconds"] = -1.0
				changed = true
		else:
			if float(state.get("next_arrival_remaining_seconds", -1.0)) < 0.0:
				_schedule_next_customer_arrival(state)
				changed = true
			else:
				state["next_arrival_remaining_seconds"] = maxf(float(state["next_arrival_remaining_seconds"]) - delta, 0.0)
				changed = true
				if float(state["next_arrival_remaining_seconds"]) <= 0.0:
					var arrival := ensure_active_playable_order(active_count + 1)
					for order_variant in Array(arrival.get("created_orders", [])):
						entered_orders.append(Dictionary(order_variant).duplicate(true))
					_schedule_next_customer_arrival(state)
	if changed:
		_save_data["customer_arrival"] = _normalized_customer_arrival_state(state)
		# Persist at visible whole-second boundaries and all phase transitions.
		var phase_changed := StringName(before.get("phase", &"")) != StringName(state.get("phase", &""))
		var before_remaining := float(before.get("restock_remaining_seconds", before.get("next_arrival_remaining_seconds", 0.0))) if StringName(before.get("phase", &"")) == &"restocking" else float(before.get("next_arrival_remaining_seconds", 0.0))
		var after_remaining := float(state.get("restock_remaining_seconds", state.get("next_arrival_remaining_seconds", 0.0))) if StringName(state.get("phase", &"")) == &"restocking" else float(state.get("next_arrival_remaining_seconds", 0.0))
		if phase_changed or ceili(before_remaining) != ceili(after_remaining) or not entered_orders.is_empty():
			_touch_and_write()
	return {"success": true, "changed": changed, "state": customer_arrival_snapshot(), "entered_orders": entered_orders}


func _new_customer_arrival_state(seed: int) -> Dictionary:
	return {
		"phase": &"restocking",
		"restock_remaining_seconds": OPENING_RESTOCK_SECONDS,
		"next_arrival_remaining_seconds": -1.0,
		"rng_state": maxi(abs(seed), 1),
	}


func _normalized_customer_arrival_state(source: Dictionary) -> Dictionary:
	var phase := StringName(source.get("phase", &"restocking"))
	if phase not in [&"restocking", &"open"]:
		phase = &"restocking"
	return {
		"phase": phase,
		"restock_remaining_seconds": clampf(float(source.get("restock_remaining_seconds", OPENING_RESTOCK_SECONDS)), 0.0, OPENING_RESTOCK_SECONDS),
		"next_arrival_remaining_seconds": maxf(float(source.get("next_arrival_remaining_seconds", -1.0)), -1.0),
		"rng_state": maxi(abs(int(source.get("rng_state", _save_data.get("order_rng_seed", 1)))), 1),
	}


func _schedule_next_customer_arrival(state: Dictionary) -> void:
	var pressure := customer_pressure_snapshot()
	if active_formal_orders().size() >= int(pressure.get("capacity", 2)):
		state["next_arrival_remaining_seconds"] = -1.0
		return
	var rng_state := maxi(abs(int(state.get("rng_state", 1))), 1)
	rng_state = int((rng_state * 1103515245 + 12345) & 0x7fffffff)
	state["rng_state"] = maxi(rng_state, 1)
	var minimum := float(pressure.get("arrival_min_seconds", 10.0))
	var maximum := maxf(float(pressure.get("arrival_max_seconds", 14.0)), minimum)
	var span_milliseconds := maxi(roundi((maximum - minimum) * 1000.0), 0)
	state["next_arrival_remaining_seconds"] = minimum + float(rng_state % (span_milliseconds + 1)) / 1000.0


func mark_session_left() -> void:
	if not has_save():
		return
	_save_data["business_paused"] = true
	_sync_progression_to_save()
	_sync_pancake_holding_tray_to_save()
	_sync_formal_orders_to_save()
	_sync_production_to_save()
	_sync_business_services_to_save()
	_touch_and_write(true)


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
	# A region/device tutorial is reserved for the first queue position so the
	# player receives the new-area guidance before any normal order that day.
	# A single active tutorial still cannot duplicate across the rest of the day.
	if issued_today != 0:
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


func ensure_active_playable_order(target_size: int = FIVE_AREA_ORDER_SERVICE.MAX_ACTIVE_CUSTOMERS) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_progression()
	_ensure_order_service()
	_reconcile_completed_tutorial_order()
	if not bool(_progression.get("day_open")):
		return {"success": false, "reason": &"business_day_closed"}
	var queue: Array = Array(_order_service.call("queue_snapshot"))
	var tutorial := Dictionary(_progression.call("tutorial_snapshot"))
	var tutorial_kind := StringName(tutorial.get("active_kind", &""))
	var tutorial_id := StringName(tutorial.get("active_id", &""))
	var current_day := int(_progression.get("current_day"))
	var tutorial_generated_today := int(_save_data.get("tutorial_order_generated_day", 0)) == current_day
	var queue_is_generated_ordinary := not queue.is_empty()
	for queued_order_variant in queue:
		var queued_order := Dictionary(queued_order_variant)
		var queued_identity := _tutorial_identity_for_order(queued_order)
		var queued_metadata := Dictionary(queued_order.get("metadata", {}))
		if not StringName(queued_identity.get("tutorial_id", &"")).is_empty() or not queued_metadata.has("generated_sequence"):
			queue_is_generated_ordinary = false
			break
	# Older and early-end saves can carry a full ordinary queue across the day
	# boundary.  A newly active tutorial owns the storefront, so discard that
	# stale queue before the size check can return it as the new day's first order.
	if (
		not tutorial_id.is_empty()
		and not tutorial_generated_today
		and _formal_order_for_tutorial(tutorial_kind, tutorial_id).is_empty()
		and queue_is_generated_ordinary
	):
		_order_service.call("abandon_all_open_orders", &"tutorial_day_priority")
		_sync_formal_orders_to_save()
		_touch_and_write()
		queue.clear()
	var tutorial_owns_storefront := (not tutorial_id.is_empty() and not tutorial_generated_today) or _queue_contains_tutorial(queue)
	# A tutorial is the sole customer. Normal walk-ins are scheduled one at a
	# time, never pre-created as a hidden waiting queue.
	var pressure_capacity := int(customer_pressure_snapshot().get("capacity", 2))
	var queue_target := 1 if tutorial_owns_storefront else clampi(target_size, 1, mini(FIVE_AREA_ORDER_SERVICE.MAX_OPEN_ORDERS, pressure_capacity))
	var needed := maxi(queue_target - queue.size(), 0)
	if needed <= 0:
		return {"success": true, "created": false, "order": active_formal_order(), "active_orders": active_formal_orders(), "queue": queue}
	var next_sequence := maxi(int(_save_data.get("order_sequence", 0)), 0) + 1
	var promotion_context := _active_order_promotion_context()
	if promotion_context.is_empty():
		promotion_context = _tutorial_promotion_context(queue, tutorial_kind, tutorial_id, tutorial_generated_today)
	var special_context := {
		"special_state": Dictionary(_save_data.get(SPECIAL_CUSTOMER_STATE_KEY, {})).duplicate(true),
		"queue_has_special_customer": _queue_contains_special_customer(queue),
	}
	var generated_batch: Dictionary = FIVE_AREA_PLAYABLE_ORDER_GENERATOR.generate_queue_candidates(
		five_area_progression_snapshot(),
		inventory_snapshot(),
		int(_save_data.get("order_rng_seed", 1)),
		next_sequence,
		needed,
		int(_progression.get("current_day")),
		int(_save_data.get("tutorial_order_generated_day", 0)),
		promotion_context,
		special_context,
	)
	if not bool(generated_batch.get("success", false)):
		if not queue.is_empty():
			return {"success": true, "created": false, "order": active_formal_order(), "active_orders": active_formal_orders(), "queue": queue, "needs_candidates": needed, "deferred_reason": generated_batch.get("reason", &"no_eligible_playable_order")}
		return generated_batch
	var candidates: Array = Array(generated_batch.get("candidates", []))
	for candidate_index in range(candidates.size()):
		var candidate := Dictionary(candidates[candidate_index]).duplicate(true)
		var metadata := Dictionary(candidate.get("metadata", {})).duplicate(true)
		metadata["generated_sequence"] = next_sequence + candidate_index
		candidate["metadata"] = metadata
		candidate = _apply_customer_patience_policy(candidate, queue.size() + candidate_index)
		candidates[candidate_index] = candidate
	var result: Dictionary = _order_service.call("ensure_queue", queue_target, candidates)
	if not bool(result.get("success", false)):
		return result
	if bool(result.get("created", false)):
		if not promotion_context.is_empty():
			_enqueue_generated_tutorial_promotions(candidates)
		_consume_generated_order_promotions(candidates)
		_save_data["order_sequence"] = next_sequence + candidates.size() - 1
		if int(generated_batch.get("tutorial_generated_day", 0)) > 0:
			_save_data["tutorial_order_generated_day"] = int(generated_batch.get("tutorial_generated_day", 0))
		_save_data[SPECIAL_CUSTOMER_STATE_KEY] = Dictionary(generated_batch.get("special_state", _save_data.get(SPECIAL_CUSTOMER_STATE_KEY, {}))).duplicate(true)
		_sync_formal_orders_to_save()
		_touch_and_write()
		order_changed.emit({"active": Dictionary(result.get("order", {})).duplicate(true), "queue": Array(result.get("queue", [])).duplicate(true)})
	result["order"] = active_formal_order()
	result["active_orders"] = active_formal_orders()
	return result


func _apply_customer_patience_policy(candidate: Dictionary, queue_ahead: int) -> Dictionary:
	var adjusted := candidate.duplicate(true)
	var metadata := Dictionary(adjusted.get("metadata", {})).duplicate(true)
	if bool(metadata.get("tutorial_no_countdown", false)):
		return adjusted
	var estimate := _estimated_order_service_seconds(Array(adjusted.get("items", [])))
	var current_day := int(customer_pressure_snapshot().get("current_day", 1))
	var first_day_bonus := CUSTOMER_PATIENCE_FIRST_DAY_BONUS_SECONDS if current_day == 1 else 0.0
	var queue_grace := float(maxi(queue_ahead, 0)) * CUSTOMER_PATIENCE_QUEUE_GRACE_SECONDS
	var policy_patience := estimate + CUSTOMER_PATIENCE_BASE_GRACE_SECONDS + first_day_bonus + queue_grace
	metadata["estimated_service_seconds"] = estimate
	metadata["queue_grace_seconds"] = queue_grace
	metadata["patience_seconds"] = snappedf(maxf(float(metadata.get("patience_seconds", 0.0)), policy_patience), 0.1)
	adjusted["metadata"] = metadata
	return adjusted


func _estimated_order_service_seconds(items: Array) -> float:
	var area_totals := {}
	for item_variant in items:
		var item := Dictionary(item_variant)
		var area_id := StringName(item.get("area_id", &""))
		var unit_seconds := float(CUSTOMER_SERVICE_ESTIMATE_SECONDS.get(area_id, 12.0))
		var quantity := maxi(int(item.get("quantity", 1)), 1)
		# Additional portions share setup/cooking work, but still add handling time.
		var item_seconds := unit_seconds * (1.0 + 0.35 * float(quantity - 1))
		area_totals[area_id] = float(area_totals.get(area_id, 0.0)) + item_seconds
	var serial_total := 0.0
	var longest_area := 0.0
	for area_seconds_variant in area_totals.values():
		var area_seconds := float(area_seconds_variant)
		serial_total += area_seconds
		longest_area = maxf(longest_area, area_seconds)
	# Different stations can overlap, while the longest lane remains critical.
	return snappedf(longest_area + 0.4 * maxf(serial_total - longest_area, 0.0), 0.1)


## Keep the shop populated independently of whichever scene happened to
## settle, refuse, or expire the preceding order. This belongs to GameSession,
## not a workstation callback, because the queue is durable business state.
func _replenish_playable_order_queue() -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_progression()
	if not bool(_progression.get("day_open")):
		return {"success": false, "reason": &"business_day_closed"}
	var state := customer_arrival_snapshot()
	if StringName(state.get("phase", &"")) != &"open":
		return {"success": true, "scheduled": false, "state": state}
	if active_formal_orders().size() >= int(customer_pressure_snapshot().get("capacity", 2)):
		return {"success": true, "scheduled": false, "state": state}
	if float(state.get("next_arrival_remaining_seconds", -1.0)) < 0.0:
		_schedule_next_customer_arrival(state)
		_save_data["customer_arrival"] = _normalized_customer_arrival_state(state)
		_touch_and_write()
	return {"success": true, "scheduled": true, "state": customer_arrival_snapshot()}


func _queue_contains_tutorial(queue: Array) -> bool:
	for order_variant in queue:
		if not StringName(_tutorial_identity_for_order(Dictionary(order_variant)).get("tutorial_id", &"")).is_empty():
			return true
	return false


func _queue_contains_special_customer(queue: Array) -> bool:
	for order_variant in queue:
		var order := Dictionary(order_variant)
		if not StringName(order.get("special_customer_id", Dictionary(order.get("metadata", {})).get("special_customer_id", &""))).is_empty():
			return true
	return false


func _active_order_promotion_context() -> Dictionary:
	var promotions := Array(_save_data.get(ORDER_PROMOTIONS_KEY, []))
	var newest_legacy_promotion := {}
	for promotion_variant in promotions:
		var promotion := Dictionary(promotion_variant)
		var remaining := clampi(int(promotion.get("remaining_orders", 0)), 0, 3)
		if remaining <= 0:
			continue
		var context := {
			"kind": StringName(promotion.get("kind", &"")),
			"target_id": StringName(promotion.get("target_id", &"")),
			"source_growth_id": StringName(promotion.get("source_growth_id", &"")),
			"next_index": 3 - remaining,
		}
		if bool(promotion.get("latest_first", false)):
			return context
		# Versions before latest-first promotion order appended items to the
		# back. Preserve the intended newest-unlock behaviour when loading one
		# of those saves by keeping its last pending item as a fallback.
		newest_legacy_promotion = context
	return newest_legacy_promotion


func _enqueue_generated_tutorial_promotions(candidates: Array) -> void:
	for candidate_variant in candidates:
		var metadata := Dictionary(Dictionary(candidate_variant).get("metadata", {}))
		var tutorial_id := StringName(metadata.get("tutorial_id", &""))
		if tutorial_id.is_empty():
			continue
		_enqueue_order_promotion({
			"kind": StringName(metadata.get("tutorial_kind", &"area")),
			"target_id": tutorial_id,
			"source_growth_id": StringName("tutorial:%s" % tutorial_id),
			"remaining_orders": 3,
		})


func _consume_generated_order_promotions(candidates: Array) -> void:
	var counts := {}
	for candidate_variant in candidates:
		var metadata := Dictionary(Dictionary(candidate_variant).get("metadata", {}))
		var source_growth_id := StringName(metadata.get("promotion_source_growth_id", &""))
		if source_growth_id.is_empty():
			continue
		counts[source_growth_id] = int(counts.get(source_growth_id, 0)) + 1
	var promotions := Array(_save_data.get(ORDER_PROMOTIONS_KEY, [])).duplicate(true)
	for index in range(promotions.size()):
		var promotion := Dictionary(promotions[index]).duplicate(true)
		var source_growth_id := StringName(promotion.get("source_growth_id", &""))
		promotion["remaining_orders"] = maxi(int(promotion.get("remaining_orders", 0)) - int(counts.get(source_growth_id, 0)), 0)
		promotions[index] = promotion
	while not promotions.is_empty() and int(Dictionary(promotions[0]).get("remaining_orders", 0)) <= 0:
		promotions.pop_front()
	_save_data[ORDER_PROMOTIONS_KEY] = promotions


func _enqueue_order_promotion(promotion: Dictionary) -> void:
	var source_growth_id := StringName(promotion.get("source_growth_id", &""))
	var promotions := Array(_save_data.get(ORDER_PROMOTIONS_KEY, [])).duplicate(true)
	for existing_variant in promotions:
		if StringName(Dictionary(existing_variant).get("source_growth_id", &"")) == source_growth_id:
			return
	# A new unlock should be visible in the next customer order. This matters
	# when debug progression (or a recovered save) activates several upgrades at
	# once: a FIFO queue made the latest topping wait behind every earlier
	# promotion, so customers could keep ordering plain pancakes despite the
	# newly available ingredient.
	var newest_promotion := promotion.duplicate(true)
	newest_promotion["latest_first"] = true
	promotions.push_front(newest_promotion)
	_save_data[ORDER_PROMOTIONS_KEY] = promotions


func _enqueue_growth_order_promotions(activated_growth_ids: Array) -> void:
	for growth_id_variant in activated_growth_ids:
		var growth_id := StringName(growth_id_variant)
		# Area/device teaching owns its own three-order follow-up window. Keeping
		# it out of the content queue prevents the tutorial product from jumping
		# ahead of an independently unlocked recipe or topping on the same day.
		if str(growth_id).begins_with("growth.area."):
			continue
		var definition := CATALOG.growth_definition(growth_id)
		# The dual-basket fryer is both an equipment upgrade and a chicken-cutlet
		# content unlock. It still skips the old equipment tutorial, but its newly
		# unlocked product must receive the regular three-order introduction.
		if str(growth_id).begins_with("growth.equipment.") and Array(definition.get("unlock_product_ids", [])).is_empty():
			continue
		var product_ids := Array(definition.get("unlock_product_ids", []))
		if not product_ids.is_empty():
			_enqueue_order_promotion({"kind": &"product", "target_id": StringName(product_ids[0]), "source_growth_id": growth_id, "remaining_orders": 3})
			continue
		for recipe_id_variant in Array(definition.get("unlock_recipe_ids", [])):
			var product_id := StringName(CATALOG.recipe_definition(StringName(recipe_id_variant)).get("product_id", &""))
			if not product_id.is_empty():
				_enqueue_order_promotion({"kind": &"product", "target_id": product_id, "source_growth_id": growth_id, "remaining_orders": 3})
				break
		if not Array(definition.get("unlock_recipe_ids", [])).is_empty():
			continue
		for stock_id_variant in Array(definition.get("unlock_stock_ids", [])):
			var stock_id := StringName(stock_id_variant)
			var category := StringName(CATALOG.stock_definition(stock_id).get("category", &""))
			if category == &"add_on" or category == &"sauce":
				_enqueue_order_promotion({"kind": &"pancake_stock", "target_id": stock_id, "source_growth_id": growth_id, "remaining_orders": 3})
				break


func _tutorial_promotion_context(
	queue: Array,
	tutorial_kind: StringName,
	tutorial_id: StringName,
	tutorial_generated_today: bool
) -> Dictionary:
	if tutorial_id.is_empty() or not tutorial_generated_today:
		return {}
	var tutorial_present := false
	var generated_indices := {}
	for order_variant in queue:
		var order := Dictionary(order_variant)
		var identity := _tutorial_identity_for_order(order)
		if (
			StringName(identity.get("kind", &"")) == tutorial_kind
			and StringName(identity.get("tutorial_id", &"")) == tutorial_id
		):
			tutorial_present = true
		var metadata := Dictionary(order.get("metadata", {}))
		if (
			StringName(metadata.get("promotion_tutorial_kind", &"")) == tutorial_kind
			and StringName(metadata.get("promotion_tutorial_id", &"")) == tutorial_id
		):
			generated_indices[int(metadata.get("promotion_index", 0))] = true
	if not tutorial_present:
		return {}
	var next_index := 0
	while next_index < 3 and generated_indices.has(next_index + 1):
		next_index += 1
	return {
		"tutorial_kind": tutorial_kind,
		"tutorial_id": tutorial_id,
		"next_index": next_index,
	}


func waiting_formal_orders() -> Array[Dictionary]:
	# New customers are never generated ahead of their visual arrival.
	return []


func advance_formal_order_patience(delta: float) -> Dictionary:
	if not has_save() or delta <= 0.0 or get_tree().paused or is_business_paused():
		return {"success": true, "changed": false}
	_ensure_progression()
	if not bool(_progression.get("day_open")):
		return {"success": true, "changed": false}
	_ensure_order_service()
	var result: Dictionary = _order_service.call("advance_patience", delta)
	var expired_results: Array = Array(result.get("expired_results", []))
	if bool(result.get("changed", false)) or not expired_results.is_empty():
		_sync_formal_orders_to_save()
	for expired_variant in expired_results:
		var expired: Dictionary = Dictionary(expired_variant)
		if not bool(expired.get("already_settled", false)):
			_finalize_failed_formal_order(expired)
	if not expired_results.is_empty():
		var refill := _replenish_playable_order_queue()
		result["refill"] = refill
		# Expiration/refill changes the active set after OrderService produced its
		# result, so only that rare path needs a fresh snapshot. On normal timer
		# frames the service result is already current; cloning all orders again was
		# pure per-frame overhead on the native drag path.
		result["active_orders"] = active_formal_orders()
	return result


func preview_formal_order_refusal(order_id: StringName) -> Dictionary:
	_ensure_order_service()
	var order := formal_order(order_id)
	if not StringName(_tutorial_identity_for_order(order).get("tutorial_id", &"")).is_empty():
		return {"success": false, "reason": &"tutorial_order_cannot_be_refused"}
	return Dictionary(_order_service.call("preview_refusal", order_id)).duplicate(true)


func refuse_formal_order(order_id: StringName) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_order_service()
	var order := formal_order(order_id)
	if not StringName(_tutorial_identity_for_order(order).get("tutorial_id", &"")).is_empty():
		return {"success": false, "reason": &"tutorial_order_cannot_be_refused"}
	var result: Dictionary = _order_service.call("refuse_order", order_id)
	if bool(result.get("success", false)) and not bool(result.get("already_settled", false)):
		_finalize_failed_formal_order(result)
		result["refill"] = _replenish_playable_order_queue()
	return result


func skip_active_area_tutorial() -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_progression()
	var tutorial := Dictionary(_progression.call("tutorial_snapshot"))
	var kind := StringName(tutorial.get("active_kind", &""))
	var tutorial_id := StringName(tutorial.get("active_id", &""))
	if kind not in [&"area", &"device"] or tutorial_id.is_empty():
		return {"success": false, "reason": &"tutorial_not_active"}
	var active := _formal_order_for_tutorial(kind, tutorial_id)
	if not active.is_empty():
		var abandoned := abandon_formal_order(StringName(active.get("order_id", &"")), &"tutorial_skipped")
		if not bool(abandoned.get("success", false)):
			return abandoned
	var result: Dictionary = _progression.call("skip_tutorial", kind, tutorial_id)
	if bool(result.get("success", false)):
		_sync_progression_to_save()
		_touch_and_write()
		result["refill"] = _replenish_playable_order_queue()
		progression_changed.emit(five_area_progression_snapshot())
		order_changed.emit({})
	return result


func record_active_tutorial_action(action_id: StringName) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_progression()
	var tutorial := Dictionary(_progression.call("tutorial_snapshot"))
	var kind := StringName(tutorial.get("active_kind", &""))
	var tutorial_id := StringName(tutorial.get("active_id", &""))
	if tutorial_id.is_empty():
		return {"success": false, "reason": &"tutorial_not_active"}
	var result := Dictionary(_progression.call("record_tutorial_action", kind, tutorial_id, action_id))
	if bool(result.get("success", false)):
		_sync_progression_to_save()
		_touch_and_write()
		progression_changed.emit(five_area_progression_snapshot())
	return result


func open_formal_order(items: Array, metadata: Dictionary = {}) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_order_service()
	var result: Dictionary = _order_service.call("open_order", items, metadata)
	if bool(result.get("success", false)):
		_save_data["order_sequence"] = maxi(int(_save_data.get("order_sequence", 0)), int(Dictionary(result.get("order", {})).get("sequence", 0)))
		_sync_formal_orders_to_save()
		_touch_and_write()
		order_changed.emit(Dictionary(result.get("order", {})).duplicate(true))
	return result


func formal_order_snapshot() -> Dictionary:
	_ensure_order_service()
	return Dictionary(_order_service.call("snapshot")).duplicate(true)


func active_formal_order() -> Dictionary:
	_ensure_order_service()
	return Dictionary(_order_service.call("active_order")).duplicate(true)


func active_formal_orders() -> Array[Dictionary]:
	_ensure_order_service()
	return Array(_order_service.call("active_orders")).duplicate(true)


func formal_order(order_id: StringName) -> Dictionary:
	_ensure_order_service()
	return Dictionary(_order_service.call("order_by_id", order_id)).duplicate(true)


func _formal_order_for_tutorial(kind: StringName, tutorial_id: StringName) -> Dictionary:
	for order in active_formal_orders():
		var identity := _tutorial_identity_for_order(order)
		if StringName(identity.get("kind", &"")) == kind and StringName(identity.get("tutorial_id", &"")) == tutorial_id:
			return order
	return {}


func _tutorial_identity_for_order(order: Dictionary) -> Dictionary:
	var metadata := Dictionary(order.get("metadata", {}))
	var kind := StringName(order.get("tutorial_kind", metadata.get("tutorial_kind", &"")))
	var tutorial_id := StringName(order.get("tutorial_id", metadata.get("tutorial_id", &"")))
	var legacy_area_id := StringName(order.get("teaching_area_id", metadata.get("teaching_area_id", &"")))
	if tutorial_id.is_empty() and not legacy_area_id.is_empty():
		kind = &"area"
		tutorial_id = legacy_area_id
	return {"kind": kind, "tutorial_id": tutorial_id, "teaching_area_id": legacy_area_id}


func _order_is_tutorial(order: Dictionary) -> bool:
	return not StringName(_tutorial_identity_for_order(order).get("tutorial_id", &"")).is_empty()


func _record_tutorial_delivery_completed(order: Dictionary) -> void:
	if not _order_is_tutorial(order):
		return
	_ensure_progression()
	var identity := _tutorial_identity_for_order(order)
	var kind := StringName(identity.get("kind", &""))
	var tutorial_id := StringName(identity.get("tutorial_id", &""))
	if tutorial_id.is_empty():
		return
	_progression.call("record_tutorial_action", kind, tutorial_id, &"delivery_attempted")


func begin_formal_order_serving(order_id: StringName) -> Dictionary:
	_ensure_order_service()
	var result: Dictionary = _order_service.call("begin_serving", order_id)
	if bool(result.get("success", false)):
		_sync_formal_orders_to_save()
		_touch_and_write()
		order_changed.emit({"active_orders": active_formal_orders()})
	return result


func cancel_formal_order_serving(order_id: StringName) -> Dictionary:
	_ensure_order_service()
	var result: Dictionary = _order_service.call("cancel_serving", order_id)
	if bool(result.get("success", false)) and bool(result.get("changed", false)):
		_sync_formal_orders_to_save()
		_touch_and_write()
		order_changed.emit({"active_orders": active_formal_orders()})
	return result


func attach_formal_order_product(order_id: StringName, item_index: int, product: Dictionary) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_order_service()
	var preview := Dictionary(_order_service.call("preview_attach_product", order_id, item_index, product))
	if not bool(preview.get("success", false)):
		return preview
	var result: Dictionary = _order_service.call("attach_product", order_id, item_index, product)
	if bool(result.get("success", false)):
		_sync_formal_orders_to_save()
		_touch_and_write()
	return result


func preview_attach_formal_order_product(order_id: StringName, item_index: int, product: Dictionary) -> Dictionary:
	_ensure_order_service()
	return Dictionary(_order_service.call("preview_attach_product", order_id, item_index, product)).duplicate(true)


## Read-only validation for one available product against an order-card item.
## Callers use this to prefer a matching source without consuming inventory.
func preview_stage_product_to_order(source_ref: Dictionary, order_id: StringName, item_index: int) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_order_service()
	_ensure_production_service()
	_ensure_pancake_holding_tray()
	var order := formal_order(order_id)
	var items := Array(order.get("items", []))
	if item_index < 0 or item_index >= items.size() or StringName(order.get("state", &"")) not in [&"active", &"serving"]:
		return {"success": false, "reason": &"order_not_active"}
	var item := Dictionary(items[item_index])
	var source_preview := _preview_product_source(source_ref, item)
	if not bool(source_preview.get("success", false)):
		return source_preview
	var preview_product := Dictionary(source_preview.get("product", {})).duplicate(true)
	var expected_source_product_id := StringName(source_ref.get("product_id", &""))
	if not expected_source_product_id.is_empty() and StringName(preview_product.get("product_id", &"")) != expected_source_product_id:
		return {"success": false, "reason": &"source_product_changed"}
	if StringName(preview_product.get("status", &"")) in [&"reserved", &"consumed", &"wasted"]:
		return {"success": false, "reason": &"product_terminal_state"}
	var order_preview := Dictionary(_order_service.call("preview_attach_product", order_id, item_index, preview_product))
	if not bool(order_preview.get("success", false)):
		return order_preview
	return {
		"success": true,
		"product": preview_product,
		"will_match": bool(order_preview.get("will_match", false)),
		"mismatch_reasons": order_preview.get("mismatch_reasons", PackedStringArray()),
		"source_ref": _normalized_product_source_ref(source_ref),
	}


func preview_packaged_drink_inventory(stock_id: StringName, product_id: StringName) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_progression()
	_ensure_production_service()
	var definition := CATALOG.product_definition(product_id)
	var recipe := CATALOG.recipe_definition(StringName(definition.get("recipe_id", &"")))
	if definition.is_empty() or recipe.is_empty() or StringName(definition.get("area_id", &"")) != &"area.packaged_drink" or not Array(recipe.get("stock_ids", [])).has(stock_id):
		return {"success": false, "reason": &"invalid_packaged_drink_source"}
	if not bool(_progression.call("owns_area", &"area.packaged_drink")) or not bool(_progression.call("owns_product", product_id)) or not bool(_progression.call("owns_stock", stock_id)):
		return {"success": false, "reason": &"stock_locked", "stock_id": stock_id}
	var inventory := inventory_snapshot()
	if int(inventory.get(str(stock_id), 0)) <= 0:
		return {"success": false, "reason": &"insufficient_stock", "stock_id": stock_id}
	var generated := Dictionary(_production_service.call("packaged_drink_product", product_id, false))
	return generated if bool(generated.get("success", false)) else {"success": false, "reason": generated.get("reason", &"packaged_drink_unavailable")}


func take_packaged_drink_inventory(stock_id: StringName, product_id: StringName) -> Dictionary:
	var preview := preview_packaged_drink_inventory(stock_id, product_id)
	if not bool(preview.get("success", false)):
		return preview
	var consumed := consume_inventory_stock_ids([stock_id])
	if not bool(consumed.get("success", false)):
		return consumed
	var generated := Dictionary(_production_service.call("packaged_drink_product", product_id, true))
	if not bool(generated.get("success", false)):
		restore_inventory_stock_ids([stock_id])
		return {"success": false, "reason": generated.get("reason", &"packaged_drink_unavailable")}
	var product := Dictionary(generated.get("product", {})).duplicate(true)
	return {"success": true, "product": product, "consumed_stock_ids": PackedStringArray([str(stock_id)])}


## Moves exactly one available product into the requested order-card item.
## Mismatches remain deliverable, including during tutorials: completing the
## guided production and delivery steps is sufficient to finish a tutorial.
func stage_product_to_order(source_ref: Dictionary, order_id: StringName, item_index: int) -> Dictionary:
	var source_preview := preview_stage_product_to_order(source_ref, order_id, item_index)
	if not bool(source_preview.get("success", false)):
		return source_preview
	_ensure_order_service()
	_ensure_production_service()
	_ensure_pancake_holding_tray()
	var order := formal_order(order_id)
	var items := Array(order.get("items", []))
	if item_index < 0 or item_index >= items.size():
		return {"success": false, "reason": &"order_not_active"}
	var item := Dictionary(items[item_index])
	var expected_source_product_id := StringName(source_ref.get("product_id", &""))
	var rollback := _tray_transaction_snapshot()
	var collected := _collect_product_source(source_ref, item)
	if not bool(collected.get("success", false)):
		return collected
	var product := Dictionary(collected.get("product", {})).duplicate(true)
	if product.is_empty():
		_restore_tray_transaction(rollback)
		return {"success": false, "reason": &"source_returned_no_product"}
	if not expected_source_product_id.is_empty() and StringName(product.get("product_id", &"")) != expected_source_product_id:
		_restore_tray_transaction(rollback)
		return {"success": false, "reason": &"source_product_changed"}
	product = _score_pancake_for_delivery(product, order, item)
	product["reservation_origin"] = _normalized_product_source_ref(source_ref)
	product["return_policy"] = &"waste_only"
	var attached := Dictionary(_order_service.call("attach_product", order_id, item_index, product))
	if not bool(attached.get("success", false)):
		_restore_tray_transaction(rollback)
		return {"success": false, "reason": &"stage_rollback", "attach_result": attached}
	_order_service.call("mark_production_started", order_id, _product_source_instance_id(source_ref))
	_persist_tray_transaction()
	return {
		"success": true,
		"product": product,
		"order_result": attached,
		"will_match": bool(source_preview.get("will_match", false)),
		"mismatch_reasons": source_preview.get("mismatch_reasons", PackedStringArray()),
	}


func _score_pancake_for_delivery(product: Dictionary, order: Dictionary, item: Dictionary) -> Dictionary:
	if StringName(product.get("product_id", &"")) != &"product.pancake.custom":
		return product
	if Dictionary(product.get("serving_score_basis", {})).is_empty():
		return product
	var configured_patience := float(order.get("patience_seconds", 0.0))
	var patience_seconds := configured_patience if configured_patience > 0.0 else 72.0
	var tutorial_no_countdown := bool(order.get("tutorial_no_countdown", false))
	var remaining_patience := patience_seconds
	if configured_patience > 0.0:
		remaining_patience = clampf(float(order.get("remaining_patience_seconds", patience_seconds)), 0.0, patience_seconds)
	var elapsed_seconds := 0.0 if tutorial_no_countdown else maxf(patience_seconds - remaining_patience, 0.0)
	var patience_ratio := 1.0 if tutorial_no_countdown else remaining_patience / patience_seconds
	var scoring_order := {
		"heat_preference": StringName(item.get("heat_preference", &"golden")),
		"ingredients": _legacy_pancake_ids(item.get("ingredient_ids", []), LEGACY_PANCAKE_STOCK_IDS),
		"sauces": _legacy_pancake_ids(item.get("sauce_ids", []), LEGACY_PANCAKE_SAUCE_STOCK_IDS),
		"time_limit": patience_seconds,
		"sauce_intensity_multiplier": float(item.get("sauce_intensity_multiplier", 1.0)),
	}
	var result := Dictionary(PANCAKE_SCORER.evaluate_stored_product(
		product,
		scoring_order,
		elapsed_seconds,
		patience_ratio,
	))
	if result.is_empty():
		return product
	var scored_product := product.duplicate(true)
	var final_score := float(result.get("score", product.get("score", 0.0)))
	scored_product["score"] = final_score
	scored_product["grade"] = _grade_for_score(final_score)
	scored_product["dimension_scores"] = Dictionary(result.get("dimensions", {})).duplicate(true)
	scored_product["feedback"] = str(result.get("feedback", product.get("feedback", "")))
	scored_product["tags"] = Array(result.get("tags", [])).duplicate()
	var heat_feedback := PANCAKE_SCORER.heat_feedback_for_metrics(Dictionary(result.get("metrics", {})))
	scored_product["heat_matches_requested_preference"] = PANCAKE_SCORER.heat_matches_preference_metrics(Dictionary(result.get("metrics", {})))
	if heat_feedback.is_empty():
		scored_product.erase("heat_feedback")
	else:
		scored_product["heat_feedback"] = heat_feedback
	scored_product["special_evaluation"] = Dictionary(result.get("special_evaluation", product.get("special_evaluation", {}))).duplicate(true)
	return scored_product


static func _legacy_pancake_ids(stock_values: Variant, legacy_to_stock: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	for stock_value in Array(stock_values):
		var stock_id := StringName(stock_value)
		for legacy_value in legacy_to_stock.keys():
			var legacy_id := StringName(legacy_value)
			if stock_id == StringName(legacy_to_stock[legacy_value]) or stock_id == legacy_id:
				result.append(str(legacy_id))
				break
	return result


func remove_staged_product(order_id: StringName, item_index: int, disposition: StringName) -> Dictionary:
	if disposition != &"waste":
		return {"success": false, "reason": &"invalid_disposition"}
	_ensure_order_service()
	_ensure_production_service()
	var order := formal_order(order_id)
	var items := Array(order.get("items", []))
	if item_index < 0 or item_index >= items.size() or StringName(order.get("state", &"")) not in [&"active", &"serving"]:
		return {"success": false, "reason": &"order_not_active"}
	var products := Array(Dictionary(items[item_index]).get("attached_products", []))
	if products.is_empty():
		var legacy_product := Dictionary(Dictionary(items[item_index]).get("attached_product", {}))
		if not legacy_product.is_empty():
			products.append(legacy_product)
	if products.is_empty():
		return {"success": false, "reason": &"tray_slot_empty"}
	var rollback := _tray_transaction_snapshot()
	var removed := Dictionary(_order_service.call("remove_attached_product", order_id, item_index))
	if not bool(removed.get("success", false)):
		return removed
	var product := Dictionary(removed.get("product", {}))
	var disposition_result := Dictionary(_production_service.call("record_staged_waste", product, &"tray_correction"))
	if not bool(disposition_result.get("success", false)):
		_restore_tray_transaction(rollback)
		return {"success": false, "reason": &"remove_rollback", "disposition_result": disposition_result}
	_persist_tray_transaction()
	return {"success": true, "product": product, "disposition": disposition, "disposition_result": disposition_result}


func complete_order_delivery(order_id: StringName) -> Dictionary:
	var order := formal_order(order_id)
	if order.is_empty() or StringName(order.get("state", &"")) not in [&"active", &"serving"]:
		return {"success": false, "reason": &"order_not_active"}
	var missing_items: Array[Dictionary] = []
	for item_index in range(Array(order.get("items", [])).size()):
		var item := Dictionary(Array(order.get("items", []))[item_index])
		var placed := Array(item.get("prepared_product_instance_ids", [])).size()
		var required := maxi(int(item.get("quantity", 1)), 1)
		if placed < required:
			missing_items.append({"item_index": item_index, "product_id": StringName(item.get("product_id", &"")), "missing_quantity": required - placed})
	if not missing_items.is_empty():
		return {"success": false, "reason": &"tray_incomplete", "missing_items": missing_items}
	return settle_f3_order(order_id, false)


## Compatibility shim for saves, fixtures, and older callers that still use
## the retired physical customer-tray name.
func handoff_order_tray(order_id: StringName) -> Dictionary:
	return complete_order_delivery(order_id)


func pending_tray_payment(settlement_id: StringName) -> Dictionary:
	return Dictionary(Dictionary(_save_data.get("pending_tray_payments", {})).get(str(settlement_id), {})).duplicate(true)


func pending_tray_payments() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for payment_value in Dictionary(_save_data.get("pending_tray_payments", {})).values():
		var payment := Dictionary(payment_value).duplicate(true)
		if payment.is_empty() or bool(payment.get("collected", false)):
			continue
		result.append(payment)
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.get("created_at_unix", 0)) < int(right.get("created_at_unix", 0))
	)
	return result


func pending_order_payments() -> Array[Dictionary]:
	return pending_tray_payments()


func collect_all_pending_order_payments() -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_progression()
	var payments := Dictionary(_save_data.get("pending_tray_payments", {})).duplicate(true)
	var collected_ids := PackedStringArray()
	var total_amount := 0
	var collected_at := int(Time.get_unix_time_from_system())
	for key_value in payments.keys():
		var key := str(key_value)
		var payment := Dictionary(payments.get(key, {})).duplicate(true)
		if payment.is_empty() or bool(payment.get("collected", false)):
			continue
		total_amount += maxi(int(payment.get("amount", 0)), 0)
		payment["collected"] = true
		payment["collected_at_unix"] = collected_at
		payments[key] = payment
		collected_ids.append(StringName(payment.get("settlement_id", key)))
	if collected_ids.is_empty():
		return {"success": true, "already_collected": true, "amount": 0, "settlement_ids": collected_ids}
	_progression.set("coins", int(_progression.get("coins")) + total_amount)
	_save_data["pending_tray_payments"] = payments
	_sync_progression_to_save()
	_touch_and_write()
	coins_changed.emit(int(_progression.get("coins")))
	progression_changed.emit(five_area_progression_snapshot())
	return {"success": true, "amount": total_amount, "settlement_ids": collected_ids}


func collect_tray_payment(settlement_id: StringName) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_progression()
	var payments := Dictionary(_save_data.get("pending_tray_payments", {})).duplicate(true)
	var key := str(settlement_id)
	var payment := Dictionary(payments.get(key, {})).duplicate(true)
	if payment.is_empty():
		return {"success": false, "reason": &"payment_not_found"}
	if bool(payment.get("collected", false)):
		return {"success": true, "already_collected": true, "amount": int(payment.get("amount", 0))}
	var amount := maxi(int(payment.get("amount", 0)), 0)
	_progression.set("coins", int(_progression.get("coins")) + amount)
	payment["collected"] = true
	payment["collected_at_unix"] = int(Time.get_unix_time_from_system())
	payments[key] = payment
	_save_data["pending_tray_payments"] = payments
	_sync_progression_to_save()
	_touch_and_write()
	coins_changed.emit(int(_progression.get("coins")))
	progression_changed.emit(five_area_progression_snapshot())
	return {"success": true, "amount": amount, "payment": payment.duplicate(true)}


func _preview_product_source(source_ref: Dictionary, order_item: Dictionary) -> Dictionary:
	var source_kind := StringName(source_ref.get("source_kind", &""))
	var source_index := int(source_ref.get("source_index", -1))
	match source_kind:
		&"prepared_product_slot":
			return preview_take_prepared_product(StringName(source_ref.get("source_slot_id", &"")), int(source_ref.get("source_index", 0)))
		&"youtiao_fryer_slot":
			# Finished sticks remain valid delivery stock while they are still in
			# the raised fryer basket.  The source index is the authored basket
			# position, so a direct handoff removes exactly the stick the player
			# dragged instead of reflowing the remaining batch.
			if source_index < 0:
				return {"success": false, "reason": &"invalid_youtiao_fryer_slot"}
			return Dictionary(_production_service.call("preview_collect_batch", &"device.youtiao_fryer", 1, source_index))
		&"fryer_slot":
			if source_index < 0:
				return {"success": false, "reason": &"invalid_fryer_slot"}
			return Dictionary(_production_service.call("preview_collect_batch", &"device.youtiao_fryer", 1, source_index, StringName(source_ref.get("lane_id", &"left"))))
		&"soy_output":
			return Dictionary(_production_service.call("preview_collect_soy_output", source_index)) if source_index >= 0 else Dictionary(_production_service.call("preview_collect_soy", 1))
		&"soy_cup":
			return Dictionary(_production_service.call("preview_soy_cup", source_index)) if source_index >= 0 else Dictionary(_production_service.call("preview_soy_cup"))
		&"pancake_holding":
			var tray_preview := Dictionary(_pancake_holding_tray.call("preview_serve", source_index, order_item))
			if bool(tray_preview.get("success", false)):
				tray_preview["product"] = Dictionary(tray_preview.get("product", {})).duplicate(true)
			return tray_preview
		&"pancake_ready":
			var ready_product := Dictionary(source_ref.get("product", {})).duplicate(true)
			return {"success": not ready_product.is_empty(), "reason": &"" if not ready_product.is_empty() else &"pancake_not_ready", "product": ready_product}
		&"pancake_griddle_ready":
			return preview_pancake_griddle_ready(source_index)
		&"packaged_drink_inventory":
			return preview_packaged_drink_inventory(StringName(source_ref.get("stock_id", &"")), StringName(source_ref.get("product_id", &"")))
		_:
			return {"success": false, "reason": &"unsupported_product_source", "source_kind": source_kind}


func _collect_product_source(source_ref: Dictionary, order_item: Dictionary) -> Dictionary:
	var source_kind := StringName(source_ref.get("source_kind", &""))
	var source_index := int(source_ref.get("source_index", -1))
	match source_kind:
		&"prepared_product_slot": return take_prepared_product(StringName(source_ref.get("source_slot_id", &"")), int(source_ref.get("source_index", 0)))
		&"youtiao_fryer_slot":
			if source_index < 0:
				return {"success": false, "reason": &"invalid_youtiao_fryer_slot"}
			return Dictionary(_production_service.call("collect_batch", &"device.youtiao_fryer", 1, source_index))
		&"fryer_slot":
			if source_index < 0:
				return {"success": false, "reason": &"invalid_fryer_slot"}
			return Dictionary(_production_service.call("collect_batch", &"device.youtiao_fryer", 1, source_index, StringName(source_ref.get("lane_id", &"left"))))
		&"soy_output": return Dictionary(_production_service.call("collect_soy_output", source_index)) if source_index >= 0 else Dictionary(_production_service.call("collect_soy", 1))
		&"soy_cup": return Dictionary(_production_service.call("take_soy_cup", source_index)) if source_index >= 0 else Dictionary(_production_service.call("take_soy_cup"))
		&"pancake_holding":
			var served := Dictionary(_pancake_holding_tray.call("serve", source_index, order_item))
			if bool(served.get("success", false)):
				served["product"] = Dictionary(served.get("served_product", {})).duplicate(true)
			return served
		&"pancake_ready":
			var product := Dictionary(source_ref.get("product", {})).duplicate(true)
			var consumed_stock_ids: Array[StringName] = []
			for stock_value in Array(product.get("sauce_ids", [])):
				var stock_id := StringName(stock_value)
				if not stock_id.is_empty():
					consumed_stock_ids.append(stock_id)
			var consumed := consume_inventory_stock_ids(consumed_stock_ids)
			if not bool(consumed.get("success", false)):
				return consumed
			return {"success": true, "product": product, "consumed_stock_ids": consumed_stock_ids}
		&"pancake_griddle_ready": return take_pancake_griddle_ready(source_index)
		&"packaged_drink_inventory": return take_packaged_drink_inventory(StringName(source_ref.get("stock_id", &"")), StringName(source_ref.get("product_id", &"")))
		_: return {"success": false, "reason": &"unsupported_product_source", "source_kind": source_kind}


func _normalized_product_source_ref(source_ref: Dictionary) -> Dictionary:
	return {
		"source_kind": StringName(source_ref.get("source_kind", &"")),
		"source_index": int(source_ref.get("source_index", -1)),
		"source_slot_id": StringName(source_ref.get("source_slot_id", &"")),
		"product_id": StringName(source_ref.get("product_id", &"")),
	}


func _product_source_instance_id(source_ref: Dictionary) -> StringName:
	if StringName(source_ref.get("source_kind", &"")) == &"prepared_product_slot":
		return StringName("prepared_product_slot.%s" % str(source_ref.get("source_slot_id", &"")))
	return StringName("%s.%d" % [str(source_ref.get("source_kind", &"source")), int(source_ref.get("source_index", -1))])


func _tray_transaction_snapshot() -> Dictionary:
	_ensure_business_services()
	return {
		"inventory": inventory_snapshot(),
		"production": five_area_production_snapshot(),
		"orders": formal_order_snapshot(),
		"pancake_holding_tray": pancake_holding_tray_snapshot(),
		"prepared_product_slots": prepared_product_slots_snapshot(),
		"business_report": Dictionary(_business_report_service.call("snapshot")).duplicate(true),
	}


func _restore_tray_transaction(rollback: Dictionary) -> void:
	_order_service.call("load_snapshot", Dictionary(rollback.get("orders", {})))
	_production_service.call("load_snapshot", Dictionary(rollback.get("production", {})))
	_pancake_holding_tray.call("load_snapshot", Dictionary(rollback.get("pancake_holding_tray", {})))
	_business_report_service.call("load_snapshot", Dictionary(rollback.get("business_report", {})))
	_save_data["inventory"] = _normalize_inventory(Dictionary(rollback.get("inventory", {})))
	_save_data["prepared_product_slots"] = _normalize_prepared_product_slots(Dictionary(rollback.get("prepared_product_slots", {})))
	_persist_tray_transaction()
	inventory_changed.emit(inventory_snapshot())
	prepared_product_slots_changed.emit(prepared_product_slots_snapshot())


func _persist_tray_transaction() -> void:
	_sync_formal_orders_to_save()
	_sync_production_to_save()
	_sync_pancake_holding_tray_to_save()
	_sync_business_services_to_save()
	_touch_and_write()
	order_changed.emit({"active_orders": active_formal_orders()})
	production_changed.emit(five_area_production_snapshot())


func formal_order_delivery_item_index(order_id: StringName, product: Dictionary) -> int:
	_ensure_order_service()
	return int(_order_service.call("best_delivery_item_index", order_id, product))


func mark_formal_order_production_started(order_id: StringName, source_instance_id: StringName) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_order_service()
	var result: Dictionary = _order_service.call("mark_production_started", order_id, source_instance_id)
	if bool(result.get("success", false)):
		_sync_formal_orders_to_save()
		_touch_and_write()
		order_changed.emit(active_formal_order())
	return result


func five_area_production_snapshot() -> Dictionary:
	_ensure_production_service()
	return Dictionary(_production_service.call("snapshot")).duplicate(true)


func four_area_production_snapshot() -> Dictionary:
	return five_area_production_snapshot()


func five_area_pancake_griddles_snapshot() -> Dictionary:
	_ensure_production_service()
	return Dictionary(_production_service.call("pancake_griddles_snapshot")).duplicate(true)


func pancake_griddles_snapshot() -> Dictionary:
	return five_area_pancake_griddles_snapshot()


func save_five_area_pancake_griddles(value: Dictionary) -> Dictionary:
	_ensure_production_service()
	var result := Dictionary(_production_service.call("set_pancake_griddles_snapshot", value))
	if bool(result.get("success", false)):
		_sync_production_to_save()
		_touch_and_write()
		production_changed.emit(five_area_production_snapshot())
	return result


func save_pancake_griddles(value: Dictionary) -> Dictionary:
	return save_five_area_pancake_griddles(value)


func preview_pancake_griddle_ready(source_index: int) -> Dictionary:
	_ensure_production_service()
	return Dictionary(_production_service.call("preview_pancake_griddle_ready", source_index))


func take_pancake_griddle_ready(source_index: int) -> Dictionary:
	_ensure_production_service()
	var result := Dictionary(_production_service.call("take_pancake_griddle_ready", source_index))
	if bool(result.get("success", false)):
		_sync_production_to_save()
	return result


func f3_machine_snapshot(device_id: StringName) -> Dictionary:
	_ensure_production_service()
	return Dictionary(_production_service.call("machine_snapshot", device_id)).duplicate(true)


func production_machine_snapshot(device_id: StringName) -> Dictionary:
	return f3_machine_snapshot(device_id)


func youtiao_auto_lift_enabled() -> bool:
	_ensure_production_service()
	return bool(_production_service.call("youtiao_auto_lift_enabled"))


func set_youtiao_auto_lift_enabled(enabled: bool) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_production_service()
	var result := Dictionary(_production_service.call("set_youtiao_auto_lift_enabled", enabled))
	if bool(result.get("success", false)):
		_sync_production_to_save()
		_touch_and_write()
		production_changed.emit(five_area_production_snapshot())
	return result


func advance_f3_production(delta: float) -> void:
	if not has_save() or delta <= 0.0 or get_tree().paused or is_business_paused():
		return
	_ensure_progression()
	if not bool(_progression.get("day_open")):
		return
	_ensure_production_service()
	if not bool(_production_service.call("advance_time", delta)):
		return
	_sync_production_to_save()
	production_changed.emit(five_area_production_snapshot())


func advance_production(delta: float) -> void:
	advance_f3_production(delta)


func discard_product_source(source_ref: Dictionary) -> Dictionary:
	if not bool(source_ref.get("discardable", false)):
		return {"success": false, "reason": &"source_not_discardable"}
	match StringName(source_ref.get("source_kind", &"")):
		&"soy_output", &"soy_cup":
			return discard_f4_soy(int(source_ref.get("source_index", -1)))
		&"youtiao_batch":
			return discard_f3_youtiao()
		&"youtiao_fryer_slot":
			return discard_f3_youtiao()
		&"fryer_slot":
			return discard_fryer_batch(StringName(source_ref.get("lane_id", &"left")))
		&"prepared_product_slot":
			return discard_prepared_product(StringName(source_ref.get("source_slot_id", &"")), int(source_ref.get("source_index", 0)))
		&"pancake_holding":
			return discard_pancake_holding(int(source_ref.get("source_index", -1)))
		&"pancake_griddle_ready":
			return discard_pancake_griddle_ready(Dictionary(source_ref.get("product", {})))
	return {"success": false, "reason": &"unsupported_product_source"}


func discard_prepared_product(slot_id: StringName, source_index: int = 0) -> Dictionary:
	var preview := preview_take_prepared_product(slot_id, source_index)
	if not bool(preview.get("success", false)):
		return preview
	var slots := prepared_product_slots_snapshot()
	var products: Array = Array(slots.get(str(slot_id), [])).duplicate(true)
	var product := Dictionary(products.pop_at(int(preview.get("source_index", 0)))).duplicate(true)
	_ensure_production_service()
	var waste := Dictionary(_production_service.call("record_staged_waste", product, &"prepared_youtiao_discarded"))
	if not bool(waste.get("success", false)):
		return waste
	slots[str(slot_id)] = products
	_save_data["prepared_product_slots"] = _normalize_prepared_product_slots(slots)
	_sync_production_to_save()
	_touch_and_write()
	production_changed.emit(five_area_production_snapshot())
	prepared_product_slots_changed.emit(prepared_product_slots_snapshot())
	return {"success": true, "reason": &"", "slot_id": slot_id, "product": product, "count": products.size(), "waste": waste.get("waste", {})}


func discard_pancake_holding(slot_index: int) -> Dictionary:
	_ensure_pancake_holding_tray()
	var result := Dictionary(_pancake_holding_tray.call("discard", slot_index, &"pancake_holding_discarded"))
	if not bool(result.get("success", false)):
		return result
	var product := Dictionary(Dictionary(result.get("waste", {})).get("product", {}))
	_ensure_production_service()
	var waste := Dictionary(_production_service.call("record_staged_waste", product, &"pancake_holding_discarded"))
	if not bool(waste.get("success", false)):
		return waste
	_sync_pancake_holding_tray_to_save()
	_sync_production_to_save()
	_touch_and_write()
	production_changed.emit(five_area_production_snapshot())
	return {"success": true, "product": product, "waste": waste.get("waste", {})}


func discard_pancake_griddle_ready(product: Dictionary) -> Dictionary:
	if product.is_empty():
		return {"success": false, "reason": &"pancake_product_missing"}
	_ensure_production_service()
	var waste := Dictionary(_production_service.call("record_staged_waste", product, &"pancake_griddle_discarded"))
	if not bool(waste.get("success", false)):
		return waste
	_sync_production_to_save()
	_touch_and_write()
	production_changed.emit(five_area_production_snapshot())
	return {"success": true, "product": product, "waste": waste.get("waste", {})}


func load_f3_youtiao(recipe_id: StringName, quantity: int, order_id: StringName = &"") -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_production_service()
	var result: Dictionary = _production_service.call("load_batch", &"device.youtiao_fryer", recipe_id, quantity)
	if bool(result.get("success", false)):
		_mark_f3_order_started(order_id, &"device.youtiao_fryer")
		_sync_production_to_save()
		_touch_and_write()
		production_changed.emit(five_area_production_snapshot())
	return result


func load_f3_chicken(quantity: int, order_id: StringName = &"") -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_production_service()
	var result: Dictionary = _production_service.call("load_batch", &"device.youtiao_fryer", &"recipe.chicken.cutlet", quantity, &"right")
	if bool(result.get("success", false)):
		_mark_f3_order_started(order_id, &"device.youtiao_fryer")
		_sync_production_to_save()
		_touch_and_write()
		production_changed.emit(five_area_production_snapshot())
	return result


func load_youtiao(recipe_id: StringName, quantity: int, order_id: StringName = &"") -> Dictionary:
	return load_f3_youtiao(recipe_id, quantity, order_id)


func perform_f3_youtiao_action(action_id: StringName) -> Dictionary:
	_ensure_production_service()
	var result: Dictionary = _production_service.call("perform_action", &"device.youtiao_fryer", action_id)
	if bool(result.get("success", false)):
		_sync_production_to_save()
		_touch_and_write()
		production_changed.emit(five_area_production_snapshot())
	return result


func perform_f3_chicken_action(action_id: StringName) -> Dictionary:
	_ensure_production_service()
	var result: Dictionary = _production_service.call("perform_action", &"device.youtiao_fryer", action_id, &"right")
	if bool(result.get("success", false)):
		_sync_production_to_save()
		_touch_and_write()
		production_changed.emit(five_area_production_snapshot())
	return result


func perform_youtiao_action(action_id: StringName) -> Dictionary:
	return perform_f3_youtiao_action(action_id)


func deliver_f3_youtiao(order_id: StringName, item_index: int) -> Dictionary:
	var order := formal_order(order_id)
	var items := Array(order.get("items", []))
	if item_index < 0 or item_index >= items.size():
		return {"success": false, "reason": &"order_item_missing"}
	var product_id := StringName(Dictionary(items[item_index]).get("product_id", &""))
	var slot_id := _prepared_slot_id_for_product(product_id)
	if slot_id.is_empty():
		return {"success": false, "reason": &"prepared_product_slot_missing", "product_id": product_id}
	return stage_product_to_order({"source_kind": &"prepared_product_slot", "source_slot_id": slot_id, "source_index": -1, "product_id": product_id}, order_id, item_index)


func deliver_youtiao(order_id: StringName, item_index: int) -> Dictionary:
	return deliver_f3_youtiao(order_id, item_index)


func preview_take_youtiao_fryer_slot(slot_index: int) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	if slot_index < 0:
		return {"success": false, "reason": &"invalid_youtiao_fryer_slot"}
	_ensure_production_service()
	var preview := Dictionary(_production_service.call("preview_collect_batch", &"device.youtiao_fryer", 1, slot_index))
	if not bool(preview.get("success", false)):
		return preview
	if StringName(Dictionary(preview.get("product", {})).get("product_id", &"")) != &"product.youtiao.plain":
		return {"success": false, "reason": &"not_pancake_ingredient"}
	return preview


func take_youtiao_fryer_slot(slot_index: int) -> Dictionary:
	var preview := preview_take_youtiao_fryer_slot(slot_index)
	if not bool(preview.get("success", false)):
		return preview
	var collected := Dictionary(_production_service.call("collect_batch", &"device.youtiao_fryer", 1, slot_index))
	if bool(collected.get("success", false)):
		_sync_production_to_save()
		_touch_and_write()
		production_changed.emit(five_area_production_snapshot())
	return collected


func preview_take_ready_youtiao_for_pancake() -> Dictionary:
	var preview := preview_take_prepared_product(&"slot.04")
	if not bool(preview.get("success", false)):
		return preview
	var product := Dictionary(preview.get("product", {}))
	if StringName(product.get("product_id", &"")) != &"product.youtiao.plain":
		return {"success": false, "reason": &"not_pancake_ingredient", "product_id": product.get("product_id", &"")}
	return preview


func take_ready_youtiao_for_pancake() -> Dictionary:
	var preview := preview_take_ready_youtiao_for_pancake()
	if not bool(preview.get("success", false)):
		return preview
	return take_prepared_product(&"slot.04")


func discard_f3_youtiao() -> Dictionary:
	return discard_fryer_batch(&"left")


func discard_fryer_batch(lane_id: StringName) -> Dictionary:
	_ensure_production_service()
	var result: Dictionary = _production_service.call("discard_batch", &"device.youtiao_fryer", lane_id)
	if bool(result.get("success", false)):
		_sync_production_to_save()
		_touch_and_write()
		production_changed.emit(five_area_production_snapshot())
	return result


func discard_f3_youtiao_slot(slot_index: int) -> Dictionary:
	return discard_fryer_slot(&"left", slot_index)


func discard_fryer_slot(lane_id: StringName, slot_index: int) -> Dictionary:
	_ensure_production_service()
	var result: Dictionary = _production_service.call("discard_youtiao_slot", slot_index, lane_id)
	if bool(result.get("success", false)):
		_sync_production_to_save()
		_touch_and_write()
		production_changed.emit(five_area_production_snapshot())
	return result


func load_f4_soy(recipe_id: StringName, quantity: int, order_id: StringName = &"") -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_production_service()
	var result: Dictionary = _production_service.call("load_soy_batch", recipe_id, quantity)
	if bool(result.get("success", false)):
		_persist_production_change()
	return result


func add_f4_soy_ingredient(stock_id: StringName) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_production_service()
	var result: Dictionary = _production_service.call("add_soy_ingredient", stock_id)
	if bool(result.get("success", false)):
		_persist_production_change()
	return result


func load_fresh_soy_milk(recipe_id: StringName, quantity: int, order_id: StringName = &"") -> Dictionary:
	return load_f4_soy(recipe_id, quantity, order_id)


func perform_f4_soy_action(action_id: StringName) -> Dictionary:
	_ensure_production_service()
	var result: Dictionary = _production_service.call("perform_soy_action", action_id)
	if bool(result.get("success", false)):
		_persist_production_change()
	return result


func take_f4_soy_empty_cup() -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_production_service()
	var result: Dictionary = _production_service.call("take_soy_empty_cup")
	if bool(result.get("success", false)):
		_persist_production_change()
	return result


func perform_fresh_soy_milk_action(action_id: StringName) -> Dictionary:
	return perform_f4_soy_action(action_id)


func select_f4_soy_flavor(recipe_id: StringName) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_production_service()
	var result: Dictionary = _production_service.call("select_soy_recipe", recipe_id)
	if bool(result.get("success", false)):
		_persist_production_change()
	return result


func fill_f4_soy_empty_cup(held_seconds: float, outlet_index: int = 0) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_production_service()
	var result: Dictionary = _production_service.call("fill_soy_empty_cup", held_seconds, outlet_index)
	if bool(result.get("success", false)):
		_persist_production_change()
	return result


func add_f4_soy_sugar(cup_index: int = 0) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_production_service()
	var result: Dictionary = _production_service.call("add_soy_sugar", cup_index)
	if bool(result.get("success", false)):
		_persist_production_change()
	return result


func deliver_f4_soy(order_id: StringName, item_index: int, output_slot_index: int = -1) -> Dictionary:
	_ensure_production_service()
	var preview: Dictionary = Dictionary(_production_service.call("preview_soy_cup", output_slot_index)) if output_slot_index >= 0 else Dictionary(_production_service.call("preview_soy_cup"))
	if not bool(preview.get("success", false)):
		return preview
	return stage_product_to_order({"source_kind": &"soy_cup", "source_index": output_slot_index, "product_id": StringName(Dictionary(preview.get("product", {})).get("product_id", &""))}, order_id, item_index)


func deliver_fresh_soy_milk(order_id: StringName, item_index: int, output_slot_index: int = -1) -> Dictionary:
	return deliver_f4_soy(order_id, item_index, output_slot_index)


func discard_f4_soy(output_slot_index: int = -1) -> Dictionary:
	_ensure_production_service()
	var result: Dictionary = _production_service.call("discard_soy", output_slot_index)
	if bool(result.get("success", false)):
		_persist_production_change()
	return result


func five_area_attention() -> Array[Dictionary]:
	_ensure_production_service()
	_ensure_pancake_holding_tray()
	var soy_snapshot := Dictionary(_production_service.call("machine_snapshot", &"device.fresh_soy_milk_machine"))
	return ATTENTION_SERVICE.build_attention(
		Dictionary(_production_service.call("all_machine_snapshots")),
		Array(soy_snapshot.get("output_rack", [])),
		pancake_holding_tray_snapshot()
	)


func four_area_attention() -> Array[Dictionary]:
	return five_area_attention()


func _collect_and_attach_product(order_id: StringName, item_index: int, preview: Dictionary, collect_method: String, arguments: Array) -> Dictionary:
	if not bool(preview.get("success", false)):
		return preview
	var order_preview := preview_attach_formal_order_product(order_id, item_index, Dictionary(preview.get("product", {})))
	if not bool(order_preview.get("success", false)):
		return order_preview
	var rollback := five_area_production_snapshot()
	var collected: Dictionary = _production_service.callv(collect_method, arguments)
	if not bool(collected.get("success", false)):
		return collected
	var product := Dictionary(collected.get("product", {}))
	var attached := attach_formal_order_product(order_id, item_index, product)
	if not bool(attached.get("success", false)):
		_production_service.call("load_snapshot", rollback)
		return {"success": false, "reason": &"delivery_rollback", "attach_result": attached}
	_persist_production_change()
	return {"success": true, "product": product, "order_result": attached, "will_match": order_preview.get("will_match", false), "mismatch_reasons": order_preview.get("mismatch_reasons", PackedStringArray())}


func _persist_production_change() -> void:
	_sync_production_to_save()
	_touch_and_write()
	production_changed.emit(five_area_production_snapshot())


func settle_formal_order(order_id: StringName) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_order_service()
	var order := formal_order(order_id)
	if _order_is_tutorial(order):
		return settle_f3_order(order_id, false)
	var result: Dictionary = _order_service.call("settle_order", order_id)
	if bool(result.get("success", false)):
		_sync_formal_orders_to_save()
		_touch_and_write()
		if not bool(result.get("already_settled", false)):
			result["refill"] = _replenish_playable_order_queue()
	return result


func settle_f3_order(order_id: StringName, submit_incomplete: bool = false) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_order_service()
	_ensure_progression()
	var order := formal_order(order_id)
	if StringName(order.get("order_id", &"")) != order_id:
		return {"success": false, "reason": &"order_not_active"}
	_record_tutorial_delivery_completed(order)
	var settlement: Dictionary = _order_service.call("settle_order", order_id, submit_incomplete)
	if not bool(settlement.get("success", false)):
		return settlement
	if bool(settlement.get("already_settled", false)):
		return settlement
	var settlement_id := StringName(settlement.get("settlement_id", &"settlement.%s" % order_id))
	var mastery_results: Array[Dictionary] = []
	var items: Array = Array(order.get("items", []))
	var item_results: Array = Array(settlement.get("item_results", []))
	var review_items := _formal_order_review_items(order, item_results)
	var all_grades := PackedStringArray()
	var base_coins := 0
	for item_index in range(item_results.size()):
		var item: Dictionary = Dictionary(items[item_index]) if item_index < items.size() else {}
		var item_result: Dictionary = Dictionary(item_results[item_index])
		var product: Dictionary = Dictionary(item_result.get("product", {}))
		var area_id := StringName(item.get("area_id", product.get("area_id", &"")))
		var grade := StringName(product.get("grade", _grade_for_score(float(product.get("score", 0.0)))))
		var delivered_products := Array(item_result.get("products", []))
		if delivered_products.is_empty() and not product.is_empty():
			delivered_products.append(product)
		for delivered_product_variant in delivered_products:
			var delivered_product := Dictionary(delivered_product_variant)
			all_grades.append(str(delivered_product.get("grade", _grade_for_score(float(delivered_product.get("score", 0.0))))))
		var mastery_payload := {
			"settlement_id": StringName("%s.item.%d" % [settlement_id, item_index]),
			"grade": grade,
		}
		mastery_results.append(Dictionary(_progression.call("record_area_result", area_id, mastery_payload)))
	for review_item_value in review_items:
		var review_item := Dictionary(review_item_value)
		if bool(review_item.get("qualified", false)):
			base_coins += maxi(int(review_item.get("payment_coins", 0)), 0)
	all_grades = SPECIAL_CUSTOMER_SETTLEMENT.adjusted_grades(order, all_grades, item_results)
	var normal_reputation_delta := _f3_reputation_delta(bool(settlement.get("order_success", false)), all_grades)
	var all_review_items_qualified := not review_items.is_empty()
	for review_item_value in review_items:
		if not bool(Dictionary(review_item_value).get("qualified", false)):
			all_review_items_qualified = false
			break
	# Special rewards remain a whole-order privilege. A mixed-quality order can
	# still pay its qualified products, but never receives a perfect-order bonus.
	var special_economics := SPECIAL_CUSTOMER_SETTLEMENT.calculate(
		order,
		all_review_items_qualified,
		all_grades,
		base_coins,
		normal_reputation_delta,
		item_results,
	)
	base_coins = int(special_economics.get("earned_coins", base_coins))
	var reputation_delta := int(special_economics.get("reputation_delta", normal_reputation_delta))
	settlement["review_items"] = review_items
	var qualified_item_count := 0
	for review_item_value in review_items:
		if bool(Dictionary(review_item_value).get("qualified", false)):
			qualified_item_count += 1
	settlement["qualified_item_count"] = qualified_item_count
	settlement["special_customer_id"] = special_economics.get("special_customer_id", &"")
	settlement["special_outcome"] = special_economics.get("outcome", &"ordinary")
	settlement["perfect_achieved"] = bool(special_economics.get("perfect_achieved", false))
	settlement["perfect_bonus_coins"] = int(special_economics.get("perfect_bonus_coins", 0))
	settlement["consolation_coins"] = 0
	_progression.set("reputation", maxi(int(_progression.get("reputation")) + reputation_delta, 0))
	var tutorial_identity := _tutorial_identity_for_order(order)
	var tutorial_kind := StringName(tutorial_identity.get("kind", &""))
	var tutorial_id := StringName(tutorial_identity.get("tutorial_id", &""))
	var tutorial_completion := {}
	# A tutorial finishes once its guided delivery steps are complete. The
	# tutorial does not impose a separate recipe-match gate on that progress.
	if not tutorial_id.is_empty():
		tutorial_completion = _progression.call("complete_tutorial", tutorial_kind, tutorial_id)
	var today_orders: Array = Array(_save_data.get("today_orders", [])).duplicate(true)
	var primary_item: Dictionary = Dictionary(items[0]) if not items.is_empty() else {}
	var reported_grade := _worst_grade(all_grades) if bool(settlement.get("order_success", false)) else &"C"
	today_orders.append({
		"order_id": str(order_id),
		"title": _formal_order_title(order),
		"area_id": str(primary_item.get("area_id", &"")),
		"score": {&"A": 95, &"B": 78, &"C": 55}.get(reported_grade, 0),
		"grade": str(reported_grade),
		"coins": base_coins,
		"cost": 0,
		"profit": base_coins,
		"formal_order_id": str(order_id),
		"result": settlement.duplicate(true),
	})
	_save_data["today_orders"] = today_orders
	_save_data["orders_completed"] = int(_save_data.get("orders_completed", 0)) + 1
	_save_data["today_reputation_delta"] = int(_save_data.get("today_reputation_delta", 0)) + reputation_delta
	_sync_formal_orders_to_save()
	_sync_progression_to_save()
	# Keep formal settlement, special bonus, pending cash, bill row, and ledger
	# event in one durable write below.  Persisting here used to leave a crash
	# window where the order was settled but its collectible coins were missing.
	coins_changed.emit(int(_progression.get("coins")))
	progression_changed.emit(five_area_progression_snapshot())
	settlement["mastery_results"] = mastery_results
	settlement["earned_coins"] = base_coins
	settlement["payment_pending"] = base_coins > 0
	var pending_payments := Dictionary(_save_data.get("pending_tray_payments", {})).duplicate(true)
	pending_payments[str(settlement_id)] = {
		"settlement_id": settlement_id,
		"order_id": order_id,
		"amount": base_coins,
		"special_customer_id": settlement.get("special_customer_id", &""),
		"perfect_bonus_coins": settlement.get("perfect_bonus_coins", 0),
		"collected": base_coins <= 0,
		"created_at_unix": int(Time.get_unix_time_from_system()),
	}
	_save_data["pending_tray_payments"] = pending_payments
	settlement["reputation_delta"] = reputation_delta
	settlement["tutorial_completion"] = tutorial_completion
	_record_business_event({
		"event_id": StringName("%s.sale" % settlement_id),
		"kind": &"sale" if bool(settlement.get("order_success", false)) else &"order_failure",
		"area_id": StringName(primary_item.get("area_id", &"")),
		"source_id": order_id,
		"quantity": maxi(items.size(), 1),
		"coins_delta": base_coins,
		"reputation_delta": reputation_delta,
		"details": {
			"terminal_state": settlement.get("terminal_state", &"completed"),
			"grade": reported_grade,
			"complexity": order.get("complexity", &"single"),
			"special_customer_id": settlement.get("special_customer_id", &""),
			"special_outcome": settlement.get("special_outcome", &"ordinary"),
			"perfect_bonus_coins": settlement.get("perfect_bonus_coins", 0),
			"consolation_coins": 0,
		},
	})
	for item_index in range(mastery_results.size()):
		var mastery_result := Dictionary(mastery_results[item_index])
		var item := Dictionary(items[item_index]) if item_index < items.size() else {}
		_record_business_event({
			"event_id": StringName("%s.mastery.%d" % [settlement_id, item_index]),
			"kind": &"mastery",
			"area_id": StringName(item.get("area_id", &"")),
			"source_id": order_id,
			"quantity": 1,
			"details": {"delta": int(mastery_result.get("delta", 0))},
		})
	_sync_business_services_to_save()
	_touch_and_write()
	settlement["refill"] = _replenish_playable_order_queue()
	order_changed.emit({})
	order_settled.emit(settlement.duplicate(true))
	return settlement


func _finalize_failed_formal_order(result: Dictionary) -> void:
	_ensure_progression()
	var order := Dictionary(result.get("order", {}))
	var reputation_delta := SPECIAL_CUSTOMER_SETTLEMENT.failure_reputation_delta(order, int(result.get("reputation_delta", -2)))
	result["reputation_delta"] = reputation_delta
	result["special_customer_id"] = StringName(order.get("special_customer_id", Dictionary(order.get("metadata", {})).get("special_customer_id", &"")))
	result["special_outcome"] = &"negative_review" if reputation_delta == -4 else &"failed"
	_progression.set("reputation", maxi(int(_progression.get("reputation")) + reputation_delta, 0))
	var tutorial_identity := _tutorial_identity_for_order(order)
	var tutorial_kind := StringName(result.get("tutorial_kind", tutorial_identity.get("kind", &"")))
	var tutorial_id := StringName(result.get("tutorial_id", tutorial_identity.get("tutorial_id", &"")))
	var teaching_area_id := StringName(tutorial_identity.get("teaching_area_id", &""))
	var tutorial_failure := {}
	if not tutorial_id.is_empty():
		tutorial_failure = _progression.call("record_tutorial_failure", tutorial_kind, tutorial_id)
	var today_orders: Array = Array(_save_data.get("today_orders", [])).duplicate(true)
	today_orders.append({
		"order_id": str(result.get("order_id", &"")),
		"title": _formal_order_title(order),
		"area_id": str(teaching_area_id if not teaching_area_id.is_empty() else _formal_order_area_id(order)),
		"score": 0,
		"grade": "失败",
		"coins": 0,
		"cost": 0,
		"profit": 0,
		"formal_order_id": str(result.get("order_id", &"")),
		"result": result.duplicate(true),
	})
	_save_data["today_orders"] = today_orders
	_save_data["today_reputation_delta"] = int(_save_data.get("today_reputation_delta", 0)) + reputation_delta
	_sync_formal_orders_to_save()
	_sync_progression_to_save()
	result["tutorial_failure"] = tutorial_failure
	var terminal_state := StringName(result.get("terminal_state", result.get("reason", &"failed")))
	_record_business_event({
		"event_id": StringName("order.%s.%s" % [str(result.get("order_id", &"unknown")), str(terminal_state)]),
		"kind": &"refusal" if terminal_state == &"refused" else &"order_failure",
		"area_id": teaching_area_id if not teaching_area_id.is_empty() else _formal_order_area_id(order),
		"source_id": StringName(result.get("order_id", &"")),
		"quantity": 1,
		"reputation_delta": reputation_delta,
		"details": {
			"terminal_state": terminal_state,
			"special_customer_id": result.get("special_customer_id", &""),
			"special_outcome": result.get("special_outcome", &"failed"),
		},
	})
	_sync_business_services_to_save()
	_touch_and_write()
	progression_changed.emit(five_area_progression_snapshot())
	order_changed.emit({})
	order_settled.emit(result.duplicate(true))


func _formal_order_area_id(order: Dictionary) -> StringName:
	var items: Array = Array(order.get("items", []))
	return &"" if items.is_empty() else StringName(Dictionary(items[0]).get("area_id", &""))


static func _worst_grade(grades: PackedStringArray) -> StringName:
	var worst := &"A"
	var worst_rank := 0
	var ranks := {&"A": 0, &"B": 1, &"C": 2, &"waste": 3}
	for grade_variant in grades:
		var grade := StringName(grade_variant)
		var rank := int(ranks.get(grade, 3))
		if rank > worst_rank:
			worst = grade
			worst_rank = rank
	return worst if not grades.is_empty() else &"C"


func _formal_order_title(order: Dictionary) -> String:
	var metadata := Dictionary(order.get("metadata", {}))
	var legacy := Dictionary(metadata.get("legacy_order", {}))
	if not legacy.is_empty():
		return str(legacy.get("title", "煎饼订单"))
	var items: Array = Array(order.get("items", []))
	if items.is_empty():
		return "正式订单"
	var product := CATALOG.product_definition(StringName(Dictionary(items[0]).get("product_id", &"")))
	return "%s订单" % str(product.get("label", "正式商品"))


func _formal_order_review_items(order: Dictionary, item_results: Array) -> Array[Dictionary]:
	var review_items: Array[Dictionary] = []
	var items := Array(order.get("items", []))
	for item_index in range(items.size()):
		var item := Dictionary(items[item_index])
		var item_result := Dictionary(item_results[item_index]) if item_index < item_results.size() else {}
		var product_results := Array(item_result.get("product_results", []))
		if product_results.is_empty():
			for product_value in Array(item_result.get("products", [])):
				product_results.append({
					"product": Dictionary(product_value).duplicate(true),
					"mismatch_reasons": Array(item_result.get("mismatch_reasons", [])).duplicate(),
				})
			if product_results.is_empty():
				product_results.append({"product": {}, "mismatch_reasons": PackedStringArray(["missing_order_item"])})
		var unit_price := _formal_item_unit_price(order, item)
		for product_index in range(product_results.size()):
			var product_result := Dictionary(product_results[product_index])
			var product := Dictionary(product_result.get("product", {})).duplicate(true)
			var mismatch_reasons := PackedStringArray(product_result.get("mismatch_reasons", PackedStringArray()))
			var score := _formal_review_score(product, mismatch_reasons)
			var hard_failure := _formal_review_is_hard_failure(mismatch_reasons)
			var qualified := not hard_failure and score >= 60.0
			var expected_product_id := StringName(item.get("product_id", &""))
			var actual_product_id := StringName(product.get("product_id", expected_product_id))
			review_items.append({
				"item_index": item_index,
				"product_index": product_index,
				"expected_product_id": expected_product_id,
				"actual_product_id": actual_product_id,
				"product": product,
				"order_item": item.duplicate(true),
				"mismatch_reasons": mismatch_reasons,
				"score": score,
				"qualified": qualified,
				"payment_coins": floori(float(unit_price) * score / 100.0) if qualified else 0,
				"feedback": _formal_review_feedback(expected_product_id, actual_product_id, item, product, mismatch_reasons, score),
			})
	return review_items


func _formal_item_unit_price(order: Dictionary, item: Dictionary) -> int:
	if item.has("base_price_coins"):
		return maxi(int(item.get("base_price_coins", 0)), 0)
	var product_id := StringName(item.get("product_id", &""))
	var catalog_price := maxi(int(CATALOG.product_definition(product_id).get("base_sell_price", 0)), 0)
	if catalog_price > 0:
		return catalog_price
	if product_id != &"product.pancake.custom":
		return 0
	var template_id := StringName(item.get("pancake_template_id", &""))
	var template := CATALOG.pancake_order_template(template_id)
	if not template.is_empty():
		return maxi(int(template.get("payment_coins", 0)), 0)
	var legacy_order := Dictionary(Dictionary(order.get("metadata", {})).get("legacy_order", {}))
	return maxi(int(legacy_order.get("payment_coins", 0)), 0)


static func _formal_review_score(product: Dictionary, mismatch_reasons: PackedStringArray) -> float:
	if _formal_review_is_hard_failure(mismatch_reasons):
		return 0.0
	if product.has("score"):
		return clampf(float(product.get("score", 0.0)), 0.0, 100.0)
	if product.has("quality"):
		return clampf(float(product.get("quality", 0.0)), 0.0, 100.0)
	return 100.0


static func _formal_review_is_hard_failure(mismatch_reasons: PackedStringArray) -> bool:
	return mismatch_reasons.has("product_id") \
		or mismatch_reasons.has("incomplete_quantity") \
		or mismatch_reasons.has("missing_order_item")
static func _formal_review_feedback(expected_product_id: StringName, actual_product_id: StringName, order_item: Dictionary, product: Dictionary, mismatch_reasons: PackedStringArray, score: float) -> String:
	var expected_label := _formal_review_product_label(expected_product_id)
	var actual_label := _formal_review_product_label(actual_product_id)
	if mismatch_reasons.has("product_id"):
		return "实送%s，与订单要求的%s不符" % [actual_label, expected_label]
	if mismatch_reasons.has("incomplete_quantity") or mismatch_reasons.has("missing_order_item"):
		return "%s未按订单交齐：订单要%s，实际未交付" % [expected_label, expected_label]
	if not mismatch_reasons.is_empty():
		return "%s不符合订单要求：%s" % [expected_label, "；".join(_formal_review_mismatch_details(order_item, product, mismatch_reasons))]
	if score < 60.0:
		return "%s评分未达60分，本份不付款" % expected_label
	return "%s符合订单要求" % expected_label


static func _formal_review_mismatch_details(order_item: Dictionary, product: Dictionary, mismatch_reasons: PackedStringArray) -> PackedStringArray:
	var details := PackedStringArray()
	if mismatch_reasons.has("heat_preference"):
		var expected_heat := _formal_review_heat_label(StringName(order_item.get("heat_preference", &"golden")))
		var actual_heat := str(product.get("heat_feedback", ""))
		if actual_heat.is_empty() and product.has("heat_preference"):
			actual_heat = _formal_review_heat_label(StringName(product.get("heat_preference", &"")))
		if actual_heat.is_empty():
			actual_heat = "未达到%s火候" % expected_heat
		details.append("火候订单要%s，实际%s" % [expected_heat, actual_heat])
	if mismatch_reasons.has("ingredient_ids"):
		details.append("配料订单要%s，实际%s" % [
			_formal_review_stock_list(order_item.get("ingredient_ids", [])),
			_formal_review_stock_list(product.get("ingredient_ids", [])),
		])
	if mismatch_reasons.has("sauce_ids"):
		details.append("酱料订单要%s，实际%s" % [
			_formal_review_stock_list(order_item.get("sauce_ids", [])),
			_formal_review_stock_list(product.get("sauce_ids", [])),
		])
	if mismatch_reasons.has("temperature_mode"):
		details.append("温度订单要%s，实际%s" % [
			_formal_review_temperature_label(StringName(order_item.get("temperature_mode", &"room_temperature"))),
			_formal_review_temperature_label(StringName(product.get("temperature_mode", &"room_temperature"))),
		])
	if mismatch_reasons.has("sugar_servings"):
		details.append("糖量订单要%s，实际%s" % [
			_formal_review_sugar_label(int(order_item.get("sugar_servings", 0))),
			_formal_review_sugar_label(int(product.get("sugar_servings", 0))),
		])
	if details.is_empty():
		details.append("实际成品与订单配置不同")
	return details


static func _formal_review_stock_list(stock_values: Variant) -> String:
	var ordered_labels := PackedStringArray()
	var counts := {}
	for stock_value in Array(stock_values):
		var label := _formal_review_stock_label(StringName(stock_value))
		if label.is_empty():
			continue
		if not counts.has(label):
			ordered_labels.append(label)
			counts[label] = 0
		counts[label] = int(counts[label]) + 1
	var display_labels := PackedStringArray()
	for label in ordered_labels:
		var count := int(counts[label])
		display_labels.append(label if count == 1 else "%s×%d" % [label, count])
	return "不加" if display_labels.is_empty() else "、".join(display_labels)


static func _formal_review_stock_label(stock_id: StringName) -> String:
	var catalog_label := str(CATALOG.stock_definition(stock_id).get("label", ""))
	if not catalog_label.is_empty():
		return catalog_label
	return {
		&"stock.pancake.egg": "鸡蛋",
		&"stock.pancake.baocui": "薄脆",
		&"stock.pancake.scallion": "葱花",
		&"stock.pancake.ham_sausage": "火腿",
		&"stock.pancake.meat_floss": "肉松",
		&"stock.pancake.coriander": "香菜",
	}.get(stock_id, "未知配料")


static func _formal_review_heat_label(preference: StringName) -> String:
	return {
		&"light": "嫩一点",
		&"golden": "金黄",
		&"well_done": "焦香一点",
	}.get(preference, "指定")


static func _formal_review_temperature_label(temperature: StringName) -> String:
	return {
		&"heated": "热饮",
		&"iced": "冰饮",
		&"room_temperature": "常温",
		&"normal": "常温",
	}.get(temperature, "指定温度")


static func _formal_review_sugar_label(servings: int) -> String:
	return "不加糖" if servings <= 0 else "%d份糖" % servings

static func _formal_review_product_label(product_id: StringName) -> String:
	if product_id == &"product.pancake.custom":

		return "煎饼"
	return str(CATALOG.product_definition(product_id).get("label", "餐品"))


func pancake_holding_tray_snapshot() -> Dictionary:
	_ensure_pancake_holding_tray()
	return Dictionary(_pancake_holding_tray.call("snapshot")).duplicate(true)


func pancake_holding_tray_slot_count() -> int:
	_ensure_progression()
	if bool(_progression.call("owns_growth", &"growth.capacity.pancake_holding_tray.second_slot")):
		return 2
	if bool(_progression.call("owns_growth", &"growth.capacity.pancake_holding_tray.first_slot")):
		return 1
	return 0


func store_pancake_product(product: Dictionary) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_progression()
	var unlocked_slot_count := pancake_holding_tray_slot_count()
	if unlocked_slot_count == 0:
		return {"success": false, "reason": &"tray_locked"}
	_ensure_pancake_holding_tray()
	var result: Dictionary = _pancake_holding_tray.call("store", product, unlocked_slot_count)
	if bool(result.get("success", false)):
		_sync_pancake_holding_tray_to_save()
		_touch_and_write()
	return result


## Moves a completed griddle pancake into the holding tray as one save-state
## transaction.  The visual griddle is cleared by the caller only after this
## returns success, so a full tray or stale source never loses the pancake.
func store_pancake_griddle_ready_in_holding_tray(source_index: int) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_progression()
	var unlocked_slot_count := pancake_holding_tray_slot_count()
	if unlocked_slot_count == 0:
		return {"success": false, "reason": &"tray_locked"}
	_ensure_pancake_holding_tray()
	_ensure_production_service()
	var preview := Dictionary(_production_service.call("preview_pancake_griddle_ready", source_index))
	if not bool(preview.get("success", false)):
		return preview
	var tray_before := pancake_holding_tray_snapshot()
	var production_before := five_area_production_snapshot()
	var stored := Dictionary(_pancake_holding_tray.call("store", Dictionary(preview.get("product", {})), unlocked_slot_count))
	if not bool(stored.get("success", false)):
		return stored
	var taken := Dictionary(_production_service.call("take_pancake_griddle_ready", source_index))
	if not bool(taken.get("success", false)):
		_pancake_holding_tray.call("load_snapshot", tray_before)
		_production_service.call("load_snapshot", production_before)
		return taken
	_sync_pancake_holding_tray_to_save()
	_sync_production_to_save()
	_touch_and_write()
	production_changed.emit(five_area_production_snapshot())
	return {
		"success": true,
		"source_index": source_index,
		"slot_index": int(stored.get("slot_index", -1)),
		"product": Dictionary(taken.get("product", {})).duplicate(true),
	}


func preview_pancake_tray_delivery(slot_index: int, order: Dictionary) -> Dictionary:
	_ensure_pancake_holding_tray()
	return Dictionary(_pancake_holding_tray.call("preview_serve", slot_index, order)).duplicate(true)


func serve_pancake_tray_delivery(slot_index: int, order: Dictionary) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_pancake_holding_tray()
	var result: Dictionary = _pancake_holding_tray.call("serve", slot_index, order)
	if bool(result.get("success", false)):
		_sync_pancake_holding_tray_to_save()
		_touch_and_write()
	return result


func advance_pancake_holding_tray(delta: float) -> void:
	if not has_save() or delta <= 0.0 or get_tree().paused or is_business_paused():
		return
	_ensure_pancake_holding_tray()
	_pancake_holding_tray.call("advance_time", delta)
	_sync_pancake_holding_tray_to_save()


func five_area_progression_snapshot() -> Dictionary:
	_ensure_progression()
	return Dictionary(_progression.call("snapshot")).duplicate(true)


func four_area_progression_snapshot() -> Dictionary:
	return five_area_progression_snapshot()


func prepared_product_slots_snapshot() -> Dictionary:
	if not has_save():
		return _empty_prepared_product_slots()
	return _normalize_prepared_product_slots(Dictionary(_save_data.get("prepared_product_slots", {})))


func prepared_product_slot_status(slot_id: StringName) -> Dictionary:
	var definition := Dictionary(PREPARED_PRODUCT_SLOT_DEFINITIONS.get(slot_id, {}))
	if definition.is_empty():
		return {"success": false, "reason": &"unknown_prepared_product_slot", "slot_id": slot_id}
	_ensure_progression()
	var recipe_id := StringName(definition.get("recipe_id", &""))
	var required_growth_id := StringName(definition.get("requires_growth_id", &""))
	var recipe_unlocked := bool(_progression.call("owns_recipe", recipe_id))
	var tray_unlocked := required_growth_id.is_empty() or bool(_progression.call("owns_growth", required_growth_id))
	var unlocked := recipe_unlocked and tray_unlocked
	var slots := prepared_product_slots_snapshot()
	var products: Array = Array(slots.get(str(slot_id), []))
	var capacity_per_product := _prepared_product_capacity_per_product()
	var capacity := _prepared_product_slot_capacity(slot_id)
	return {
		"success": unlocked,
		"reason": &"" if unlocked else &"finished_tray_locked" if not tray_unlocked else &"recipe_locked",
		"slot_id": slot_id,
		"product_id": StringName(definition.get("product_id", &"")),
		"recipe_id": recipe_id,
		"requires_growth_id": required_growth_id,
		"capacity": capacity,
		"capacity_per_product": capacity_per_product,
		"count": products.size(),
		"products": products.duplicate(true),
	}


func preview_store_ready_fryer_batch(slot_id: StringName, lane_id: StringName = &"left") -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_production_service()
	var status := prepared_product_slot_status(slot_id)
	if not bool(status.get("success", false)):
		return status
	var machine := Dictionary(_production_service.call("machine_snapshot", &"device.youtiao_fryer"))
	var lanes := Dictionary(machine.get("lanes", {}))
	var lane := Dictionary(lanes.get(lane_id, machine))
	var quantity := maxi(int(lane.get("quantity", 0)), 0)
	if quantity <= 0:
		return {"success": false, "reason": &"product_not_ready", "slot_id": slot_id, "lane_id": lane_id}
	var preview := Dictionary(_production_service.call("preview_collect_batch", &"device.youtiao_fryer", quantity, -1, lane_id))
	if not bool(preview.get("success", false)):
		return preview
	var product := Dictionary(preview.get("product", {})).duplicate(true)
	var product_id := StringName(product.get("product_id", &""))
	if not _prepared_product_slot_accepts_product(slot_id, product_id):
		return {"success": false, "reason": &"prepared_product_slot_mismatch", "slot_id": slot_id, "product": product}
	var products: Array = Array(status.get("products", []))
	var capacity_per_product := int(status.get("capacity_per_product", status.get("capacity", 0)))
	var available_capacity := maxi(capacity_per_product - _prepared_product_count(products, product_id), 0)
	if quantity > available_capacity:
		return {
			"success": false,
			"reason": &"prepared_product_slot_full",
			"slot_id": slot_id,
			"product_id": product_id,
			"required_capacity": quantity,
			"available_capacity": available_capacity,
			"missing_capacity": quantity - available_capacity,
		}
	return {"success": true, "reason": &"", "slot_id": slot_id, "product": product, "quantity": quantity, "lane_id": lane_id}


func store_ready_fryer_batch(slot_id: StringName, lane_id: StringName = &"left") -> Dictionary:
	var preview := preview_store_ready_fryer_batch(slot_id, lane_id)
	if not bool(preview.get("success", false)):
		return preview
	var production_rollback := five_area_production_snapshot()
	var slots_rollback := prepared_product_slots_snapshot()
	var quantity := int(preview.get("quantity", 0))
	var collected := Dictionary(_production_service.call("collect_batch", &"device.youtiao_fryer", quantity, -1, lane_id))
	if not bool(collected.get("success", false)):
		return collected
	var expected_product_id := StringName(Dictionary(preview.get("product", {})).get("product_id", &""))
	var products: Array = Array(collected.get("products", [])).duplicate(true)
	if products.size() != quantity:
		_production_service.call("load_snapshot", production_rollback)
		return {"success": false, "reason": &"prepared_product_changed"}
	for product_value in products:
		if StringName(Dictionary(product_value).get("product_id", &"")) != expected_product_id:
			_production_service.call("load_snapshot", production_rollback)
			return {"success": false, "reason": &"prepared_product_changed"}
	var slots := slots_rollback.duplicate(true)
	var stored_products: Array = Array(slots.get(str(slot_id), [])).duplicate(true)
	stored_products.append_array(products)
	slots[str(slot_id)] = stored_products
	_save_data["prepared_product_slots"] = _normalize_prepared_product_slots(slots)
	_sync_production_to_save()
	_touch_and_write()
	production_changed.emit(five_area_production_snapshot())
	prepared_product_slots_changed.emit(prepared_product_slots_snapshot())
	return {"success": true, "reason": &"", "slot_id": slot_id, "products": products, "stored_quantity": quantity, "count": stored_products.size(), "lane_id": lane_id}


func store_ready_fryer_batch_to_available_capacity(slot_id: StringName, lane_id: StringName = &"left") -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_production_service()
	var status := prepared_product_slot_status(slot_id)
	if not bool(status.get("success", false)):
		return status
	var machine := Dictionary(_production_service.call("machine_snapshot", &"device.youtiao_fryer"))
	var lanes := Dictionary(machine.get("lanes", {}))
	var lane := Dictionary(lanes.get(lane_id, machine))
	var ready_quantity := maxi(int(lane.get("quantity", 0)), 0)
	if ready_quantity <= 0:
		return {"success": false, "reason": &"product_not_ready", "slot_id": slot_id, "lane_id": lane_id}
	var product_preview := Dictionary(_production_service.call("preview_collect_batch", &"device.youtiao_fryer", 1, -1, lane_id))
	if not bool(product_preview.get("success", false)):
		return product_preview
	var expected_product := Dictionary(product_preview.get("product", {})).duplicate(true)
	var product_id := StringName(expected_product.get("product_id", &""))
	if not _prepared_product_slot_accepts_product(slot_id, product_id):
		return {"success": false, "reason": &"prepared_product_slot_mismatch", "slot_id": slot_id, "product": expected_product}
	var stored_products: Array = Array(status.get("products", [])).duplicate(true)
	var capacity_per_product := int(status.get("capacity_per_product", status.get("capacity", 0)))
	var available_capacity := maxi(capacity_per_product - _prepared_product_count(stored_products, product_id), 0)
	if available_capacity <= 0:
		return {"success": false, "reason": &"prepared_product_slot_full", "slot_id": slot_id, "product_id": product_id, "available_capacity": 0}
	var quantity := mini(ready_quantity, available_capacity)
	var production_rollback := five_area_production_snapshot()
	var slots_rollback := prepared_product_slots_snapshot()
	var collected := Dictionary(_production_service.call("collect_batch", &"device.youtiao_fryer", quantity, -1, lane_id))
	if not bool(collected.get("success", false)):
		return collected
	var products: Array = Array(collected.get("products", [])).duplicate(true)
	if products.size() != quantity or not products.all(func(product: Dictionary) -> bool: return StringName(product.get("product_id", &"")) == product_id):
		_production_service.call("load_snapshot", production_rollback)
		return {"success": false, "reason": &"prepared_product_changed"}
	var slots := slots_rollback.duplicate(true)
	stored_products = Array(slots.get(str(slot_id), [])).duplicate(true)
	stored_products.append_array(products)
	slots[str(slot_id)] = stored_products
	_save_data["prepared_product_slots"] = _normalize_prepared_product_slots(slots)
	_sync_production_to_save()
	_touch_and_write()
	production_changed.emit(five_area_production_snapshot())
	prepared_product_slots_changed.emit(prepared_product_slots_snapshot())
	return {"success": true, "reason": &"", "slot_id": slot_id, "products": products, "stored_quantity": quantity, "remaining_quantity": ready_quantity - quantity, "count": stored_products.size(), "lane_id": lane_id}


func preview_store_ready_youtiao_batch(slot_id: StringName) -> Dictionary:
	return preview_store_ready_fryer_batch(slot_id, &"left")


func store_ready_youtiao_batch(slot_id: StringName) -> Dictionary:
	return store_ready_fryer_batch(slot_id, &"left")


func preview_store_ready_youtiao_slot(slot_id: StringName, source_index: int) -> Dictionary:
	return preview_store_ready_fryer_slot(slot_id, &"left", source_index)


func preview_store_ready_fryer_slot(slot_id: StringName, lane_id: StringName, source_index: int) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_production_service()
	var status := prepared_product_slot_status(slot_id)
	if not bool(status.get("success", false)):
		return status
	var preview := Dictionary(_production_service.call("preview_collect_batch", &"device.youtiao_fryer", 1, source_index, lane_id))
	if not bool(preview.get("success", false)):
		return preview
	var product := Dictionary(preview.get("product", {}))
	var final_product_id := StringName(product.get("product_id", &""))
	if not _prepared_product_slot_accepts_product(slot_id, final_product_id):
		return {"success": false, "reason": &"prepared_product_slot_mismatch", "slot_id": slot_id}
	var products: Array = Array(status.get("products", []))
	var capacity_per_product := int(status.get("capacity_per_product", status.get("capacity", 0)))
	if _prepared_product_count(products, final_product_id) >= capacity_per_product:
		return {"success": false, "reason": &"prepared_product_slot_full", "slot_id": slot_id, "product_id": final_product_id}
	return {"success": true, "reason": &"", "slot_id": slot_id, "product": product, "source_index": source_index, "final_product_id": final_product_id}


func store_ready_youtiao_slot(slot_id: StringName, source_index: int) -> Dictionary:
	return store_ready_fryer_slot(slot_id, &"left", source_index)


func store_ready_fryer_slot(slot_id: StringName, lane_id: StringName, source_index: int) -> Dictionary:
	var preview := preview_store_ready_fryer_slot(slot_id, lane_id, source_index)
	if not bool(preview.get("success", false)):
		return preview
	var final_product_id := StringName(preview.get("final_product_id", &""))
	var production_rollback := five_area_production_snapshot()
	var slots_rollback := prepared_product_slots_snapshot()
	var collected := Dictionary(_production_service.call("collect_batch", &"device.youtiao_fryer", 1, source_index, lane_id))
	if not bool(collected.get("success", false)):
		return collected
	var product := Dictionary(collected.get("product", {}))
	if StringName(product.get("product_id", &"")) != final_product_id:
		_production_service.call("load_snapshot", production_rollback)
		return {"success": false, "reason": &"prepared_product_changed"}
	var slots := slots_rollback.duplicate(true)
	var stored_products: Array = Array(slots.get(str(slot_id), [])).duplicate(true)
	stored_products.append(product)
	slots[str(slot_id)] = stored_products
	_save_data["prepared_product_slots"] = _normalize_prepared_product_slots(slots)
	_sync_production_to_save()
	_touch_and_write()
	production_changed.emit(five_area_production_snapshot())
	prepared_product_slots_changed.emit(prepared_product_slots_snapshot())
	return {"success": true, "reason": &"", "slot_id": slot_id, "product": product, "source_index": source_index, "count": stored_products.size()}


func preview_store_ready_youtiao(slot_id: StringName) -> Dictionary:
	return preview_store_ready_youtiao_batch(slot_id)


func store_ready_youtiao_in_prepared_slot(slot_id: StringName) -> Dictionary:
	return store_ready_youtiao_batch(slot_id)


func preview_take_prepared_product(slot_id: StringName, source_index: int = 0) -> Dictionary:
	var status := prepared_product_slot_status(slot_id)
	if not bool(status.get("success", false)):
		return status
	var products: Array = Array(status.get("products", []))
	if products.is_empty():
		return {"success": false, "reason": &"prepared_product_slot_empty", "slot_id": slot_id}
	var resolved_index := 0 if source_index < 0 else source_index
	if resolved_index >= products.size():
		return {"success": false, "reason": &"prepared_product_slot_index_invalid", "slot_id": slot_id, "source_index": source_index}
	return {"success": true, "reason": &"", "slot_id": slot_id, "source_index": resolved_index, "product": Dictionary(products[resolved_index]).duplicate(true)}


func take_prepared_product(slot_id: StringName, source_index: int = 0) -> Dictionary:
	var preview := preview_take_prepared_product(slot_id, source_index)
	if not bool(preview.get("success", false)):
		return preview
	var slots := prepared_product_slots_snapshot()
	var products: Array = Array(slots.get(str(slot_id), [])).duplicate(true)
	var product := Dictionary(products.pop_at(int(preview.get("source_index", 0)))).duplicate(true)
	slots[str(slot_id)] = products
	_save_data["prepared_product_slots"] = _normalize_prepared_product_slots(slots)
	_touch_and_write()
	prepared_product_slots_changed.emit(prepared_product_slots_snapshot())
	return {"success": true, "reason": &"", "slot_id": slot_id, "product": product, "count": products.size()}


func clear_prepared_product_slots(persist: bool = true) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save", "products": []}
	var products: Array = []
	var slots := prepared_product_slots_snapshot()
	for slot_id in PREPARED_PRODUCT_SLOT_DEFINITIONS:
		for product_variant in Array(slots.get(str(slot_id), [])):
			var product := Dictionary(product_variant).duplicate(true)
			product["source_slot_id"] = slot_id
			products.append(product)
	_save_data["prepared_product_slots"] = _empty_prepared_product_slots()
	if persist:
		_touch_and_write()
	prepared_product_slots_changed.emit(prepared_product_slots_snapshot())
	return {"success": true, "reason": &"", "products": products}


func _append_prepared_product(slot_id: StringName, product: Dictionary) -> Dictionary:
	var status := prepared_product_slot_status(slot_id)
	if not bool(status.get("success", false)):
		return status
	var product_id := StringName(product.get("product_id", &""))
	if not _prepared_product_slot_accepts_product(slot_id, product_id):
		return {"success": false, "reason": &"prepared_product_slot_mismatch", "slot_id": slot_id}
	var slots := prepared_product_slots_snapshot()
	var products: Array = Array(slots.get(str(slot_id), [])).duplicate(true)
	var capacity_per_product := int(status.get("capacity_per_product", status.get("capacity", 0)))
	if _prepared_product_count(products, product_id) >= capacity_per_product:
		return {"success": false, "reason": &"prepared_product_slot_full", "slot_id": slot_id, "product_id": product_id}
	products.append(product.duplicate(true))
	slots[str(slot_id)] = products
	_save_data["prepared_product_slots"] = _normalize_prepared_product_slots(slots)
	return {"success": true, "reason": &"", "slot_id": slot_id, "count": products.size()}


static func _prepared_product_slot_accepts_product(slot_id: StringName, product_id: StringName) -> bool:
	var definition := Dictionary(PREPARED_PRODUCT_SLOT_DEFINITIONS.get(slot_id, {}))
	if definition.is_empty() or product_id.is_empty():
		return false
	var accepted_product_ids := Array(definition.get("accepted_product_ids", [definition.get("product_id", &"")]))
	return accepted_product_ids.has(product_id)


static func _prepared_product_count(products: Array, product_id: StringName) -> int:
	var result := 0
	for product_value in products:
		if StringName(Dictionary(product_value).get("product_id", &"")) == product_id:
			result += 1
	return result


func inventory_snapshot() -> Dictionary:
	if not has_save():
		return _new_inventory_snapshot()
	return Dictionary(_save_data.get("inventory", {})).duplicate(true)


func five_area_restock_status(stock_id: StringName) -> Dictionary:
	_ensure_progression()
	var definition := CATALOG.stock_definition(stock_id)
	if definition.is_empty():
		return {"success": false, "reason": &"unknown_stock", "stock_id": stock_id}
	if bool(definition.get("unlimited", false)):
		return {"success": false, "reason": &"restock_unnecessary", "stock_id": stock_id}
	if StringName(definition.get("category", &"")) == &"prepared_add_on":
		return {"success": false, "reason": &"restock_unavailable", "stock_id": stock_id}
	if not _progression.call("owns_stock", stock_id):
		return {"success": false, "reason": &"stock_locked", "stock_id": stock_id}
	var inventory := inventory_snapshot()
	var key := str(stock_id)
	var capacity := _restock_capacity(stock_id, definition)
	if capacity <= 0:
		return {"success": false, "reason": &"restock_unavailable", "stock_id": stock_id}
	var unit_seconds := maxf(float(definition.get("refill_seconds", 0.0)), 0.001)
	var progress_seconds := maxf(float(Dictionary(_save_data.get("restock_progress", {})).get(key, 0.0)), 0.0)
	return {
		"success": true,
		"reason": &"",
		"stock_id": stock_id,
		"area_id": StringName(definition.get("area_id", &"")),
		"unit_cost": maxi(int(definition.get("restock_unit_cost", 0)), 0),
		"unit_seconds": unit_seconds,
		"current_stock": maxi(int(inventory.get(key, 0)), 0),
		"capacity": capacity,
		# The hold indicator represents how full the physical stock container is,
		# rather than the fraction of the next individual refill unit being held.
		"container_fill_ratio": clampf(float(maxi(int(inventory.get(key, 0)), 0)) / float(capacity), 0.0, 1.0),
		"progress_seconds": progress_seconds,
		"progress_ratio": clampf(progress_seconds / unit_seconds, 0.0, 1.0),
		"coins": maxi(int(_progression.get("coins")), 0),
	}


func restock_status(stock_id: StringName) -> Dictionary:
	return five_area_restock_status(stock_id)


func cancel_five_area_restock_hold(stock_id: StringName) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save", "stock_id": stock_id}
	var key := str(stock_id)
	var progress_by_stock := Dictionary(_save_data.get("restock_progress", {})).duplicate(true)
	var cancelled_seconds := maxf(float(progress_by_stock.get(key, 0.0)), 0.0)
	if cancelled_seconds <= 0.0:
		return {"success": true, "stock_id": stock_id, "cancelled_seconds": 0.0}
	progress_by_stock[key] = 0.0
	_save_data["restock_progress"] = progress_by_stock
	_touch_and_write()
	return {"success": true, "stock_id": stock_id, "cancelled_seconds": cancelled_seconds}


func cancel_restock_hold(stock_id: StringName) -> Dictionary:
	return cancel_five_area_restock_hold(stock_id)


func opening_restock_tasks() -> Array[Dictionary]:
	var tasks: Array[Dictionary] = []
	if not has_save():
		return tasks
	_ensure_progression()
	var inventory := inventory_snapshot()
	for stock_id in CATALOG.OPENING_RESTOCK_DISPLAY_ORDER:
		if not bool(_progression.call("owns_stock", stock_id)):
			continue
		var definition := CATALOG.stock_definition(stock_id)
		if definition.is_empty() or StringName(definition.get("category", &"")) == &"prepared_add_on":
			continue
		var unlimited := bool(definition.get("unlimited", false))
		var capacity := 0 if unlimited else _restock_capacity(stock_id, definition)
		if not unlimited and capacity <= 0:
			continue
		var target := 0 if unlimited else mini(capacity, 3)
		var current := 0 if unlimited else maxi(int(inventory.get(str(stock_id), 0)), 0)
		tasks.append({
			"id": stock_id,
			"label": str(definition.get("label", str(stock_id))),
			"current": current,
			"target": target,
			"completed": unlimited or current >= target,
			"is_next": false,
			"is_unlimited": unlimited,
		})
	var next_assigned := false
	for task in tasks:
		if not next_assigned and not bool(task.get("completed", false)):
			task["is_next"] = true
			next_assigned = true
	return tasks


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
	if completed_units > 0:
		_sync_progression_to_save()
		_record_business_event({
			"event_id": _next_ledger_event_id(&"restock"),
			"kind": &"stock_cost",
			"area_id": StringName(status.get("area_id", &"")),
			"source_id": stock_id,
			"quantity": completed_units,
			"coins_delta": -charged_coins,
			"details": {"unit_cost": unit_cost, "counts_cash_cost": true},
		})
		_sync_business_services_to_save()
		# Gesture progress is transient. Persist once per completed unit batch,
		# never once per frame while the progress ring is still filling.
		_touch_and_write()
		coins_changed.emit(int(_progression.get("coins")))
		inventory_changed.emit(inventory_snapshot())
		progression_changed.emit(five_area_progression_snapshot())
	var result_status := five_area_restock_status(stock_id)
	return _five_area_restock_result(result_status, true, reason, completed_units, charged_coins)


func advance_restock_hold(stock_id: StringName, delta: float) -> Dictionary:
	return advance_five_area_restock_hold(stock_id, delta)


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
	var consumable_stock_ids: Array[StringName] = []
	for stock_id in stock_ids:
		if bool(CATALOG.stock_definition(stock_id).get("unlimited", false)):
			continue
		consumable_stock_ids.append(stock_id)
	if consumable_stock_ids.is_empty():
		return {"success": true, "inventory": inventory_snapshot(), "consumed_stock_ids": []}
	var required := {}
	for stock_id in consumable_stock_ids:
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
		saved["consumed_stock_ids"] = consumable_stock_ids.duplicate()
	return saved


func restore_inventory_stock_ids(stock_ids: Array[StringName]) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_progression()
	var restored_stock_ids: Array[StringName] = []
	var inventory := inventory_snapshot()
	for stock_id in stock_ids:
		var definition := CATALOG.stock_definition(stock_id)
		if definition.is_empty() or bool(definition.get("unlimited", false)):
			continue
		var key := str(stock_id)
		var capacity := _restock_capacity(stock_id, definition)
		if int(inventory.get(key, 0)) >= capacity:
			continue
		inventory[key] = int(inventory.get(key, 0)) + 1
		restored_stock_ids.append(stock_id)
	var saved := save_inventory(inventory)
	if bool(saved.get("success", false)):
		saved["restored_stock_ids"] = restored_stock_ids
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


func growth_recommendations(limit_total: int = 3) -> Dictionary:
	_ensure_progression()
	return Dictionary(_progression.call("growth_recommendations", limit_total)).duplicate(true)


func growth_overview() -> Array[Dictionary]:
	_ensure_progression()
	var result: Array[Dictionary] = []
	for item in Array(_progression.call("growth_overview")):
		result.append(Dictionary(item).duplicate(true))
	return result


func growth_purchase_status(growth_id: StringName) -> Dictionary:
	_ensure_progression()
	return Dictionary(_progression.call("purchase_status", growth_id)).duplicate(true)


func debug_grant_progression(
	coins_delta: int = 0,
	reputation_delta: int = 0,
	area_id: StringName = &"",
	qualified_delta: int = 0,
	a_grade_delta: int = 0
) -> Dictionary:
	var unavailable := _debug_tools_unavailable_result()
	if not unavailable.is_empty():
		return unavailable
	_ensure_progression()
	var before := five_area_progression_snapshot()
	if coins_delta < 0 or reputation_delta < 0 or qualified_delta < 0 or a_grade_delta < 0:
		return _debug_result(false, &"negative_debug_delta", before)
	if not area_id.is_empty() and not CATALOG.AREA_IDS.has(area_id):
		return _debug_result(false, &"unknown_area", before, {"area_id": area_id})
	if area_id.is_empty() and (qualified_delta > 0 or a_grade_delta > 0):
		return _debug_result(false, &"mastery_area_required", before)
	if not area_id.is_empty() and not bool(_progression.call("owns_area", area_id)):
		return _debug_result(false, &"area_locked", before, {"area_id": area_id})

	_progression.set("coins", int(_progression.get("coins")) + coins_delta)
	_progression.set("reputation", int(_progression.get("reputation")) + reputation_delta)
	if not area_id.is_empty() and (qualified_delta > 0 or a_grade_delta > 0):
		var details_by_area := Dictionary(_progression.get("area_mastery_details")).duplicate(true)
		var mastery_by_area := Dictionary(_progression.get("area_mastery")).duplicate(true)
		var details: Dictionary = Dictionary(_progression.call("mastery_snapshot", area_id)).duplicate(true)
		details["qualified"] = int(details.get("qualified", 0)) + qualified_delta + a_grade_delta
		details["a_grade"] = int(details.get("a_grade", 0)) + a_grade_delta
		details["qualified"] = maxi(int(details.get("qualified", 0)), int(details.get("a_grade", 0)))
		details_by_area[area_id] = details
		mastery_by_area[area_id] = int(details.get("qualified", 0))
		_progression.set("area_mastery_details", details_by_area)
		_progression.set("area_mastery", mastery_by_area)
	_debug_persist_progression(false)
	return _debug_result(true, &"", before, {
		"changed": coins_delta > 0 or reputation_delta > 0 or qualified_delta > 0 or a_grade_delta > 0,
		"area_id": area_id,
	})


func debug_advance_to_device_tier(area_id: StringName, target_tier: int) -> Dictionary:
	var unavailable := _debug_tools_unavailable_result()
	if not unavailable.is_empty():
		return unavailable
	_ensure_progression()
	var before := five_area_progression_snapshot()
	if bool(_progression.get("day_open")):
		return _debug_result(false, &"business_day_open", before, {"area_id": area_id, "target_tier": target_tier})
	if not DEBUG_TIER_GROWTH_IDS.has(area_id) or target_tier < 0 or target_tier >= Array(DEBUG_TIER_GROWTH_IDS[area_id]).size():
		return _debug_result(false, &"unknown_device_tier", before, {"area_id": area_id, "target_tier": target_tier})
	if not Array(before.get("pending_growth_ids", [])).is_empty():
		return _debug_result(false, &"pending_purchase_exists", before, {"area_id": area_id, "target_tier": target_tier})
	var area_definition := CATALOG.area_definition(area_id)
	var device_id := StringName(area_definition.get("device_id", &""))
	var area_owned := bool(_progression.call("owns_area", area_id))
	var current_tier := int(_progression.call("device_tier", device_id)) if area_owned else -1
	if target_tier < current_tier:
		return _debug_result(false, &"downgrade_not_allowed", before, {
			"area_id": area_id,
			"current_tier": current_tier,
			"target_tier": target_tier,
		})
	if target_tier == current_tier:
		var stock_changed := _debug_fill_owned_stock_to_capacity()
		if stock_changed:
			_debug_persist_progression(true)
		return _debug_result(true, &"already_reached", before, {
			"changed": stock_changed,
			"area_id": area_id,
			"current_tier": current_tier,
			"target_tier": target_tier,
		})

	var target_growth_id := StringName(Array(DEBUG_TIER_GROWTH_IDS[area_id])[target_tier])
	if target_growth_id.is_empty():
		return _debug_result(true, &"already_reached", before, {
			"changed": false,
			"area_id": area_id,
			"current_tier": current_tier,
			"target_tier": target_tier,
		})
	var target_route_index := CATALOG.GROWTH_DISPLAY_ORDER.find(target_growth_id)
	if target_route_index < 0:
		return _debug_result(false, &"target_not_in_growth_route", before, {"growth_id": target_growth_id})

	var preview: RefCounted = PROGRESSION_SERVICE.new(before)
	preview.call("set_day_open", false)
	var purchased_growth_ids: Array[StringName] = []
	var activated_growth_ids: Array[StringName] = []
	for route_index in range(target_route_index + 1):
		var growth_id: StringName = CATALOG.GROWTH_DISPLAY_ORDER[route_index]
		if bool(preview.call("owns_growth", growth_id)):
			continue
		var attempts := 0
		while not bool(preview.call("owns_growth", growth_id)):
			attempts += 1
			if attempts > CATALOG.GROWTH_DISPLAY_ORDER.size() + 4:
				return _debug_result(false, &"debug_progression_stalled", before, {"growth_id": growth_id})
			var status: Dictionary = preview.call("purchase_status", growth_id)
			if bool(status.get("pending_activation", false)):
				var advanced := _debug_advance_preview_day(preview, activated_growth_ids)
				if not bool(advanced.get("success", false)):
					return _debug_result(false, StringName(advanced.get("reason", &"debug_day_advance_failed")), before, {"growth_id": growth_id})
				continue
			var prepared := _debug_prepare_growth_on(preview, growth_id, activated_growth_ids)
			if not bool(prepared.get("success", false)):
				return _debug_result(false, StringName(prepared.get("reason", &"requirements_unavailable")), before, {
					"growth_id": growth_id,
					"details": prepared,
				})
			status = preview.call("purchase_status", growth_id)
			if not bool(status.get("can_purchase", false)):
				return _debug_result(false, StringName(status.get("reason", &"purchase_unavailable")), before, {
					"growth_id": growth_id,
					"details": status,
				})
			var purchase: Dictionary = preview.call("purchase", growth_id)
			if not bool(purchase.get("success", false)):
				return _debug_result(false, StringName(purchase.get("reason", &"purchase_failed")), before, {"growth_id": growth_id})
			purchased_growth_ids.append(growth_id)
			break

	while not Array(Dictionary(preview.call("snapshot")).get("pending_growth_ids", [])).is_empty():
		var advanced := _debug_advance_preview_day(preview, activated_growth_ids)
		if not bool(advanced.get("success", false)):
			return _debug_result(false, StringName(advanced.get("reason", &"debug_day_advance_failed")), before, {"growth_id": target_growth_id})

	if not bool(preview.call("owns_area", area_id)) or int(preview.call("device_tier", device_id)) < target_tier:
		return _debug_result(false, &"target_tier_not_reached", before, {"growth_id": target_growth_id})
	preview.call("set_day_open", false)
	_progression.call("load_snapshot", preview.call("snapshot"))
	_progression.call("set_day_open", false)
	_save_data["day_open"] = false
	_provision_activated_stock(activated_growth_ids)
	_enqueue_growth_order_promotions(activated_growth_ids)
	_debug_fill_owned_stock_to_capacity()
	_debug_persist_progression(true)
	return _debug_result(true, &"", before, {
		"changed": true,
		"area_id": area_id,
		"target_tier": target_tier,
		"growth_id": target_growth_id,
		"purchased_growth_ids": purchased_growth_ids,
		"affected_growth_ids": activated_growth_ids,
	})


func _debug_tools_unavailable_result() -> Dictionary:
	if not OS.is_debug_build():
		return _debug_result(false, &"debug_tools_unavailable", {})
	if not has_save():
		return _debug_result(false, &"no_active_save", {})
	return {}


func _debug_result(success: bool, reason: StringName, before: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var result := {
		"success": success,
		"reason": reason,
		"before": before.duplicate(true),
		"after": five_area_progression_snapshot() if has_save() else before.duplicate(true),
		"changed": false,
		"affected_growth_ids": [],
	}
	for key in extra:
		result[key] = extra[key]
	return result


func _debug_persist_progression(emit_inventory: bool) -> void:
	_save_data["day_open"] = bool(_progression.get("day_open"))
	_sync_progression_to_save()
	_touch_and_write()
	coins_changed.emit(int(_progression.get("coins")))
	progression_changed.emit(five_area_progression_snapshot())
	if emit_inventory:
		inventory_changed.emit(inventory_snapshot())


func _debug_prepare_growth_on(progression: RefCounted, growth_id: StringName, activated_growth_ids: Array[StringName]) -> Dictionary:
	var definition := CATALOG.growth_definition(growth_id)
	if definition.is_empty():
		return {"success": false, "reason": &"unknown_growth", "growth_id": growth_id}
	var min_day := maxi(int(definition.get("min_day", 1)), 1)
	while int(progression.get("current_day")) < min_day:
		var advanced := _debug_advance_preview_day(progression, activated_growth_ids)
		if not bool(advanced.get("success", false)):
			return advanced

	var required_area := StringName(definition.get("requires_area_id", &""))
	if not required_area.is_empty() and not bool(progression.call("owns_area", required_area)):
		return {"success": false, "reason": &"area_locked", "required_area_id": required_area}
	for required_growth_variant in Array(definition.get("requires_growth_ids", [])):
		var required_growth_id := StringName(required_growth_variant)
		if not bool(progression.call("owns_growth", required_growth_id)):
			return {"success": false, "reason": &"growth_requirement", "required_growth_id": required_growth_id}
	if bool(definition.get("requires_all_areas", false)):
		for area_id in CATALOG.UNLOCK_AREA_IDS:
			if not bool(progression.call("owns_area", area_id)):
				return {"success": false, "reason": &"all_areas_requirement", "required_area_id": area_id}

	var tutorial_area_id := StringName(definition.get("requires_tutorial_area_id", &""))
	if not tutorial_area_id.is_empty():
		_debug_complete_tutorial_on(progression, &"area", tutorial_area_id)
	var tutorial_device_id := StringName(definition.get("requires_tutorial_device_id", &""))
	if not tutorial_device_id.is_empty():
		_debug_complete_tutorial_on(progression, &"device", tutorial_device_id)

	var mastery_requirements := Dictionary(definition.get("requires_mastery", {}))
	for mastery_area_variant in mastery_requirements:
		var mastery_area_id := StringName(mastery_area_variant)
		if not bool(progression.call("owns_area", mastery_area_id)):
			return {"success": false, "reason": &"area_locked", "required_area_id": mastery_area_id}
		_debug_complete_tutorial_on(progression, &"area", mastery_area_id)
		var details_by_area := Dictionary(progression.get("area_mastery_details")).duplicate(true)
		var mastery_by_area := Dictionary(progression.get("area_mastery")).duplicate(true)
		var details: Dictionary = Dictionary(progression.call("mastery_snapshot", mastery_area_id)).duplicate(true)
		var required_values := Dictionary(mastery_requirements[mastery_area_variant])
		for metric_variant in required_values:
			var metric := str(metric_variant)
			details[metric] = maxi(int(details.get(metric, 0)), int(required_values[metric_variant]))
		details["qualified"] = maxi(int(details.get("qualified", 0)), int(details.get("a_grade", 0)))
		details_by_area[mastery_area_id] = details
		mastery_by_area[mastery_area_id] = int(details.get("qualified", 0))
		progression.set("area_mastery_details", details_by_area)
		progression.set("area_mastery", mastery_by_area)

	progression.set("reputation", maxi(int(progression.get("reputation")), int(definition.get("min_reputation", 0))))
	progression.set("coins", maxi(int(progression.get("coins")), int(definition.get("price", 0))))
	return {"success": true, "growth_id": growth_id}


func _debug_advance_preview_day(progression: RefCounted, activated_growth_ids: Array[StringName]) -> Dictionary:
	progression.call("set_day_open", false)
	var result: Dictionary = progression.call("begin_next_business_day")
	if not bool(result.get("success", false)):
		return result
	for growth_id_variant in Array(result.get("activated_growth_ids", [])):
		var growth_id := StringName(growth_id_variant)
		if not activated_growth_ids.has(growth_id):
			activated_growth_ids.append(growth_id)
	progression.call("advance_tutorial_for_new_business_day")
	progression.call("set_day_open", false)
	return result


func _debug_complete_tutorial_on(progression: RefCounted, kind: StringName, tutorial_id: StringName) -> void:
	if tutorial_id.is_empty():
		return
	var snapshot: Dictionary = progression.call("snapshot")
	var tutorial := Dictionary(snapshot.get("tutorial", {})).duplicate(true)
	var completed_key := "completed_area_ids" if kind == &"area" else "completed_device_ids"
	var queue_key := "queue_area_ids" if kind == &"area" else "queue_device_ids"
	var completed := Array(tutorial.get(completed_key, [])).duplicate()
	if not completed.has(tutorial_id) and not completed.has(str(tutorial_id)):
		completed.append(tutorial_id)
	var queue := Array(tutorial.get(queue_key, [])).duplicate()
	queue.erase(tutorial_id)
	queue.erase(str(tutorial_id))
	tutorial[completed_key] = completed
	tutorial[queue_key] = queue
	if StringName(tutorial.get("active_kind", &"")) == kind and StringName(tutorial.get("active_id", &"")) == tutorial_id:
		tutorial["active_kind"] = &""
		tutorial["active_id"] = &""
	var failures := Dictionary(tutorial.get("failure_count_by_id", {})).duplicate(true)
	failures.erase(tutorial_id)
	failures.erase(str(tutorial_id))
	tutorial["failure_count_by_id"] = failures
	snapshot["tutorial"] = tutorial
	progression.call("load_snapshot", snapshot)


func _debug_fill_owned_stock_to_capacity() -> bool:
	var inventory := inventory_snapshot()
	var before := inventory.duplicate(true)
	for stock_id in CATALOG.stock_ids():
		if not bool(_progression.call("owns_stock", stock_id)):
			continue
		var definition := CATALOG.stock_definition(stock_id)
		var capacity := _restock_capacity(stock_id, definition)
		if capacity > 0:
			inventory[str(stock_id)] = capacity
	_save_data["inventory"] = _normalize_inventory(inventory)
	return before != _save_data["inventory"]


func growth_missing_requirements(growth_id: StringName) -> String:
	var status := growth_purchase_status(growth_id)
	var definition := CATALOG.growth_definition(growth_id)
	var label := str(definition.get("label", growth_id))
	if bool(status.get("already_owned", false)):
		return "%s 已解锁" % label
	if bool(status.get("pending_activation", false)):
		return "%s 已预订，将在下一营业日生效" % label
	var explanations := PackedStringArray()
	for requirement_value in Array(status.get("missing_requirements", [])):
		var explanation := _growth_requirement_status_text(Dictionary(requirement_value))
		if not explanation.is_empty() and not explanations.has(explanation):
			explanations.append(explanation)
	if explanations.is_empty():
		return "%s：购买条件已满足，请在日结成长购买中预订" % label
	return "%s 缺少：%s" % [label, "；".join(explanations)]


static func _growth_requirement_status_text(requirement: Dictionary) -> String:
	match StringName(requirement.get("reason", &"")):
		&"purchase_slot_occupied":
			return "购买位已被 %s 占用" % str(CATALOG.growth_definition(StringName(requirement.get("pending_growth_id", &""))).get("label", requirement.get("pending_growth_id", &"")))
		&"area_locked":
			return "区域 %s" % _area_status_label(StringName(requirement.get("required_area_id", &"")))
		&"growth_requirement":
			return str(CATALOG.growth_definition(StringName(requirement.get("required_growth_id", &""))).get("label", requirement.get("required_growth_id", &"")))
		&"day_requirement":
			return "营业日 %d/%d" % [int(requirement.get("current_day", 1)), int(requirement.get("min_day", 1))]
		&"reputation_requirement":
			return "口碑 %d/%d" % [int(requirement.get("current_reputation", 0)), int(requirement.get("min_reputation", 0))]
		&"insufficient_coins":
			return "金币 %d/%d" % [int(requirement.get("current_coins", 0)), int(requirement.get("price", 0))]
		&"tutorial_requirement":
			return "%s教学完成" % _area_status_label(StringName(requirement.get("required_tutorial_area_id", requirement.get("requires_tutorial_area_id", &""))))
		&"mastery_requirement":
			return "%s%s %d/%d" % [
				_area_status_label(StringName(requirement.get("mastery_area_id", &""))),
				_mastery_metric_status_label(StringName(requirement.get("mastery_metric", &"qualified"))),
				int(requirement.get("current_mastery", 0)),
				int(requirement.get("required_mastery", 0)),
			]
		&"all_areas_requirement":
			return "已解锁区域 %d/%d" % [int(requirement.get("current_area_count", 0)), int(requirement.get("required_area_count", 3))]
		&"unknown_growth":
			return "成长配置"
	return str(requirement.get("reason", &"条件"))


static func _area_status_label(area_id: StringName) -> String:
	return {
		&"area.pancake": "煎饼",
		&"area.youtiao": "油条",
		&"area.fresh_soy_milk": "现磨豆浆",
	}.get(area_id, str(area_id))


static func _mastery_metric_status_label(metric: StringName) -> String:
	return {
		&"qualified": "合格数",
		&"a_grade": "A级数",
		&"correct_temperature": "正确温度单",
		&"correct_streak_best": "最高连对",
	}.get(metric, str(metric))


func abandon_active_formal_order(reason: StringName = &"business_day_expired") -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_order_service()
	var is_hard_cutoff := reason in [&"business_day_expired", &"timer_expired"]
	var result: Dictionary = _order_service.call("abandon_all_open_orders", reason) if is_hard_cutoff else _order_service.call("abandon_active_order", reason)
	if bool(result.get("success", false)):
		_sync_formal_orders_to_save()
		_touch_and_write()
		if not is_hard_cutoff:
			result["refill"] = _replenish_playable_order_queue()
	return result


func abandon_formal_order(order_id: StringName, reason: StringName = &"refused") -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_order_service()
	var result: Dictionary = _order_service.call("abandon_order", order_id, reason)
	if bool(result.get("success", false)):
		_sync_formal_orders_to_save()
		_touch_and_write()
		if reason not in [&"business_day_expired", &"timer_expired", &"tutorial_skipped"]:
			result["refill"] = _replenish_playable_order_queue()
	return result


func end_business_day(cutoff: Dictionary = {}) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_progression()
	_ensure_order_service()
	# A collectible payment belongs to the business day that earned it.  Clear it
	# at the persistence boundary as well as in the workstation UI, so a scene
	# reload or a non-visual caller can never carry yesterday's coins forward.
	var day_end_payment_collection := collect_all_pending_order_payments()
	var day_was_open := bool(_progression.get("day_open"))
	var normalized_cutoff := cutoff.duplicate(true)
	var cutoff_reason := StringName(normalized_cutoff.get("reason", &"manual_early_end"))
	if cutoff_reason.is_empty():
		cutoff_reason = &"manual_early_end"
	var open_order_count := Array(_order_service.call("queue_snapshot")).size()
	var abandoned_product_waste: Array[Dictionary] = []
	if day_was_open:
		abandoned_product_waste = _open_order_attached_products()
	var abandoned := {"success": true}
	if open_order_count > 0:
		abandoned = Dictionary(_order_service.call("abandon_all_open_orders", cutoff_reason))
	_sync_formal_orders_to_save()
	if not day_was_open:
		# Repeated/direct calls still enforce an empty queue, but must not rewrite
		# the original cutoff reason or close the report and production state twice.
		_touch_and_write()
		var already_closed_bill := Dictionary(_save_data.get("last_bill", {})).duplicate(true)
		if already_closed_bill.is_empty():
			already_closed_bill = today_bill()
		already_closed_bill["success"] = true
		return already_closed_bill
	normalized_cutoff["reason"] = cutoff_reason
	normalized_cutoff["unserved_customer_count"] = open_order_count
	normalized_cutoff["formal_order_abandoned"] = open_order_count > 0 and bool(abandoned.get("success", false))
	_save_data["day_open"] = false
	_progression.call("set_day_open", false)
	_save_data["today_cutoff"] = normalized_cutoff
	_save_data["business_day_remaining_seconds"] = 0.0
	for product_variant in abandoned_product_waste:
		var product := Dictionary(product_variant)
		_record_business_event({
			"event_id": _next_ledger_event_id(&"abandoned_product_day_end"),
			"kind": &"waste",
			"area_id": StringName(product.get("area_id", &"")),
			"source_id": &"unsettled_customer_order",
			"quantity": 1,
			"details": {
				"reason": &"day_end_unsold_product",
				"product_id": StringName(product.get("product_id", &"")),
				"attributed_cost": maxi(int(product.get("material_cost", 0)), 0),
			},
		})
	_ensure_production_service()
	var production_clear := Dictionary(_production_service.call("clear_for_day_end"))
	var production_waste: Array = Array(production_clear.get("waste", []))
	_sync_production_to_save()
	_ensure_pancake_holding_tray()
	var tray_waste: Array = _pancake_holding_tray.call("clear_for_day_end")
	for waste_index in range(tray_waste.size()):
		var waste := Dictionary(tray_waste[waste_index])
		var product := Dictionary(waste.get("product", {}))
		_record_business_event({
			"event_id": _next_ledger_event_id(&"tray_day_end"),
			"kind": &"waste",
			"area_id": &"area.pancake",
			"source_id": &"pancake_holding_tray",
			"quantity": 1,
			"details": {"reason": &"day_end", "attributed_cost": maxi(int(product.get("material_cost", 0)), 0)},
		})
	_sync_pancake_holding_tray_to_save()
	var prepared_clear := clear_prepared_product_slots(false)
	var prepared_slot_waste: Array = Array(prepared_clear.get("products", []))
	for product_variant in prepared_slot_waste:
		var product := Dictionary(product_variant)
		_record_business_event({
			"event_id": _next_ledger_event_id(&"prepared_slot_day_end"),
			"kind": &"waste",
			"area_id": &"area.youtiao",
			"source_id": StringName(product.get("source_slot_id", &"prepared_product_slot")),
			"quantity": 1,
			"details": {
				"reason": &"day_end",
				"product_id": StringName(product.get("product_id", &"")),
				"attributed_cost": maxi(int(product.get("material_cost", 0)), 0),
			},
		})
	var inventory_waste := _clear_inventory_for_day_end()
	_sync_progression_to_save()
	var bill := today_bill()
	bill["day_end_payment_collection"] = day_end_payment_collection.duplicate(true)
	bill["tray_waste"] = tray_waste
	bill["prepared_product_slot_waste"] = prepared_slot_waste
	bill["abandoned_product_waste"] = abandoned_product_waste
	bill["production_waste"] = production_waste
	bill["inventory_waste"] = inventory_waste
	bill["success"] = true
	_ensure_business_services()
	var ledger_bill: Dictionary = _business_report_service.call("close_day")
	for key in ledger_bill:
		bill[key] = ledger_bill[key]
	_save_data["last_bill"] = bill.duplicate(true)
	_sync_business_services_to_save()
	_touch_and_write()
	return bill


func _open_order_attached_products() -> Array[Dictionary]:
	var products: Array[Dictionary] = []
	var order_snapshot := formal_order_snapshot()
	var orders := Dictionary(order_snapshot.get("orders", {}))
	for order_value in orders.values():
		var order := Dictionary(order_value)
		if StringName(order.get("state", &"")) not in [&"active", &"serving", &"waiting"]:
			continue
		for item_value in Array(order.get("items", [])):
			var item := Dictionary(item_value)
			for product_value in Array(item.get("attached_products", [])):
				var product := Dictionary(product_value).duplicate(true)
				if not product.is_empty():
					products.append(product)
	return products


func _clear_inventory_for_day_end() -> Array[Dictionary]:
	var inventory := inventory_snapshot()
	var waste_rows: Array[Dictionary] = []
	for stock_id in CATALOG.stock_ids():
		var key := str(stock_id)
		var quantity := maxi(int(inventory.get(key, 0)), 0)
		if quantity <= 0:
			continue
		var definition := CATALOG.stock_definition(stock_id)
		var unit_cost := maxi(int(definition.get("restock_unit_cost", 0)), 0)
		var row := {
			"stock_id": stock_id,
			"quantity": quantity,
			"unit_cost": unit_cost,
			"attributed_cost": unit_cost * quantity,
		}
		waste_rows.append(row)
		_record_business_event({
			"event_id": _next_ledger_event_id(&"inventory_day_end"),
			"kind": &"waste",
			"area_id": StringName(definition.get("area_id", &"")),
			"source_id": stock_id,
			"quantity": quantity,
			"details": {
				"reason": &"day_end_remaining_stock",
				"stock_id": stock_id,
				"unit_cost": unit_cost,
				"attributed_cost": unit_cost * quantity,
			},
		})
		inventory[key] = 0
	_save_data["inventory"] = _normalize_inventory(inventory)
	_save_data["restock_progress"] = {}
	inventory_changed.emit(inventory_snapshot())
	return waste_rows


func begin_next_business_day() -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_progression()
	var result: Dictionary = _progression.call("begin_next_business_day")
	if not bool(result.get("success", false)):
		return result
	_ensure_order_service()
	# A day boundary cannot carry visible customers into the next opening window.
	if not Array(_order_service.call("queue_snapshot")).is_empty():
		_order_service.call("abandon_all_open_orders", &"new_business_day_reset")
		_sync_formal_orders_to_save()
	_save_data["day_open"] = true
	_save_data["business_day_remaining_seconds"] = business_day_duration_seconds()
	_save_data["customer_arrival"] = _new_customer_arrival_state(
		maxi(int(_save_data.get("order_rng_seed", 1)) + int(_progression.get("current_day")), 1)
	)
	_save_data["today_orders"] = []
	_save_data["today_reputation_delta"] = 0
	_save_data["today_cutoff"] = {}
	_save_data["business_paused"] = false
	_save_data["pancake_orders_issued_today"] = 0
	_progression.call("advance_tutorial_for_new_business_day")
	_save_data[SPECIAL_CUSTOMER_STATE_KEY] = SPECIAL_CUSTOMER_CATALOG.normalize_state(
		Dictionary(_save_data.get(SPECIAL_CUSTOMER_STATE_KEY, {})),
		int(_progression.get("current_day")),
	)
	result["restock_required_ids"] = _provision_activated_stock(Array(result.get("activated_growth_ids", [])))
	_enqueue_growth_order_promotions(Array(result.get("activated_growth_ids", [])))
	_sync_progression_to_save()
	_ensure_production_service()
	_sync_production_to_save()
	_ensure_business_services()
	_business_report_service.call("begin_day", int(_progression.get("current_day")))
	_daily_goal_service.call("begin_day", _daily_goal_context())
	_sync_business_services_to_save()
	_touch_and_write()
	result["customer_arrival"] = customer_arrival_snapshot()
	inventory_changed.emit(inventory_snapshot())
	progression_changed.emit(five_area_progression_snapshot())
	daily_goal_changed.emit(current_daily_goal())
	return result


func _provision_activated_stock(activated_growth_ids: Array) -> PackedStringArray:
	var inventory := inventory_snapshot()
	var restock_required := PackedStringArray()
	for growth_id_variant in activated_growth_ids:
		var definition := CATALOG.growth_definition(StringName(growth_id_variant))
		for stock_id_variant in Array(definition.get("unlock_stock_ids", [])):
			var stock_id := StringName(stock_id_variant)
			var stock_definition := CATALOG.stock_definition(stock_id)
			var capacity := maxi(int(stock_definition.get("restock_capacity", 0)), 0)
			if capacity > 0:
				var key := str(stock_id)
				# Newly activated stock containers always begin empty.  Every
				# ingredient, including eggs, follows the same player-driven
				# restock flow at the start of its activation day.
				inventory[key] = maxi(int(inventory.get(key, 0)), 0)
				if int(inventory[key]) <= 0 and not restock_required.has(key):
					restock_required.append(key)
	_save_data["inventory"] = _normalize_inventory(inventory)
	return restock_required


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
	# Legacy callers can still report a tutorial outcome. Once the delivery flow
	# is settled, recipe matching does not keep the tutorial open.
	var formal_teaching_area_id: StringName = &""
	var formal_tutorial_order_settled := false
	if not formal_order_id.is_empty():
		var formal_orders := Dictionary(formal_order_snapshot().get("orders", {}))
		var formal_order := Dictionary(formal_orders.get(formal_order_id, formal_orders.get(str(formal_order_id), {})))
		formal_teaching_area_id = StringName(formal_order.get("teaching_area_id", Dictionary(formal_order.get("metadata", {})).get("teaching_area_id", &"")))
		formal_tutorial_order_settled = StringName(formal_order.get("state", &"")) == &"settled"
	if not formal_teaching_area_id.is_empty() and formal_tutorial_order_settled:
		tutorial_completion = _progression.call("complete_tutorial", &"area", formal_teaching_area_id)
	elif bool(order.get("tutorial_no_countdown", false)):
		var legacy_kind := StringName(order.get("tutorial_kind", &""))
		var legacy_id := StringName(order.get("tutorial_id", &""))
		tutorial_completion = _progression.call("complete_tutorial", legacy_kind, legacy_id)
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
	var ledger_id := StringName("order.%s.sale" % (str(formal_order_id) if not formal_order_id.is_empty() else str(_save_data.get("orders_completed", 0))))
	_record_business_event({
		"event_id": ledger_id,
		"kind": &"sale",
		"area_id": area_id,
		"source_id": formal_order_id,
		"quantity": 1,
		"coins_delta": payment_coins,
		"reputation_delta": reputation_delta,
		"details": {
			"grade": StringName(settled_result.get("grade", &"C")),
			"terminal_state": &"completed",
			"complexity": &"single",
		},
	})
	_record_business_event({
		"event_id": StringName("%s.mastery" % ledger_id),
		"kind": &"mastery",
		"area_id": area_id,
		"source_id": formal_order_id,
		"quantity": 1,
		"details": {"delta": int(mastery_result.get("delta", 0))},
	})
	_sync_progression_to_save()
	_sync_business_services_to_save()
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
	var bill := {
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
	_ensure_business_services()
	var ledger_bill: Dictionary = _business_report_service.call("build_bill")
	for key in ledger_bill:
		bill[key] = ledger_bill[key]
	bill["sold_material_cost"] = total_cost
	bill["total_cost"] = total_cost + maxi(int(bill.get("waste_cost", 0)), 0)
	bill["total_profit"] = total_coins - int(bill["total_cost"])
	return bill


func get_settings() -> Dictionary:
	return _settings.duplicate(true)


func save_settings(
	master_volume: float,
	sfx_volume: float,
	fullscreen: bool,
	ui_scale: float = -1.0,
	drag_sensitivity: float = -1.0,
	key_bindings: Dictionary = {},
) -> Dictionary:
	var next_bindings := _normalized_key_bindings(
		key_bindings if not key_bindings.is_empty() else Dictionary(_settings.get("key_bindings", DEFAULT_SETTINGS.key_bindings))
	)
	var conflict := _key_binding_conflict(next_bindings)
	if not conflict.is_empty():
		return {"success": false, "reason": &"key_binding_conflict", "actions": conflict}
	var next_ui_scale := float(_settings.get("ui_scale", 100.0)) if ui_scale < 0.0 else _normalized_ui_scale(ui_scale)
	var next_drag_sensitivity := float(_settings.get("drag_sensitivity", 100.0)) if drag_sensitivity < 0.0 else clampf(drag_sensitivity, 50.0, 150.0)
	var next_settings := {
		"master_volume": clampf(master_volume, 0.0, 100.0),
		"sfx_volume": clampf(sfx_volume, 0.0, 100.0),
		"fullscreen": fullscreen,
		"ui_scale": next_ui_scale,
		"drag_sensitivity": next_drag_sensitivity,
		"key_bindings": next_bindings,
	}
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", next_settings.master_volume)
	config.set_value("audio", "sfx_volume", next_settings.sfx_volume)
	config.set_value("display", "fullscreen", next_settings.fullscreen)
	config.set_value("display", "ui_scale", next_settings.ui_scale)
	config.set_value("input", "drag_sensitivity", next_settings.drag_sensitivity)
	config.set_value("input", "key_bindings", next_settings.key_bindings)
	var save_error := config.save(_active_settings_path)
	if save_error != OK:
		return {"success": false, "reason": &"settings_write_failed", "error": save_error}
	_settings = next_settings
	apply_settings()
	return {"success": true, "settings": get_settings()}


func default_key_bindings() -> Dictionary:
	return Dictionary(DEFAULT_SETTINGS.key_bindings).duplicate(true)


func key_binding_display_name(action_id: StringName) -> String:
	return {
		&"tool_ladle": "面糊勺",
		&"tool_spreader": "摊饼器/压饼器",
		&"tool_sauce_brush": "酱刷",
		&"tool_fold_package": "折叠/包装",
	}.get(action_id, str(action_id))


func apply_settings() -> void:
	_set_bus_volume(&"Master", float(_settings.master_volume))
	_set_bus_volume(&"SFX", float(_settings.sfx_volume))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if bool(_settings.fullscreen) else DisplayServer.WINDOW_MODE_WINDOWED)
	_apply_key_bindings(Dictionary(_settings.get("key_bindings", DEFAULT_SETTINGS.key_bindings)))
	settings_changed.emit(get_settings())


func _load_save() -> void:
	_save_data.clear()
	_recover_interrupted_save_write()
	if not FileAccess.file_exists(_active_save_path):
		return
	var file := FileAccess.open(_active_save_path, FileAccess.READ)
	if file == null:
		return
	var save_text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(save_text)
	if parsed is Dictionary and int(parsed.get("version", 0)) == SAVE_VERSION and str(parsed.get("save_kind", "")) == SAVE_KIND:
		_save_data = Dictionary(parsed).duplicate(true)
		_ensure_save_shape()
		return
	# All prior development saves are intentionally incompatible with the
	# four-area/single-griddle economy.
	# Resetting avoids ambiguous refunds and hidden retired content in snapshots.
	reset_incompatible_development_save()


func _restore_progression() -> void:
	var stored_progression := Dictionary(_save_data.get("progression", {})).duplicate(true)
	_progression = PROGRESSION_SERVICE.new(stored_progression) if has_save() else PROGRESSION_SERVICE.new()
	if has_save():
		var normalized_progression := Dictionary(_progression.call("snapshot")).duplicate(true)
		if normalized_progression != stored_progression:
			_save_data["progression"] = normalized_progression
			_write_save()
	_pancake_holding_tray = PANCAKE_HOLDING_TRAY_MODEL.new(Dictionary(_save_data.get("pancake_holding_tray", {})))
	_order_service = FIVE_AREA_ORDER_SERVICE.new(Dictionary(_save_data.get("formal_orders", {})))
	_production_service = FIVE_AREA_PRODUCTION_SERVICE.new(self, Dictionary(_save_data.get("production", {})))
	_business_report_service = BUSINESS_REPORT_SERVICE.new(Dictionary(_save_data.get("today_ledger", {})))
	_daily_goal_service = DAILY_GOAL_SERVICE.new(Dictionary(_save_data.get("daily_goal", {})))
	_configure_service_connections()


func _ensure_progression() -> void:
	if _progression == null:
		_restore_progression()


func _ensure_pancake_holding_tray() -> void:
	if _pancake_holding_tray == null:
		_pancake_holding_tray = PANCAKE_HOLDING_TRAY_MODEL.new(Dictionary(_save_data.get("pancake_holding_tray", {})))


func _ensure_order_service() -> void:
	if _order_service == null:
		_order_service = FIVE_AREA_ORDER_SERVICE.new(Dictionary(_save_data.get("formal_orders", {})))


func _ensure_production_service() -> void:
	_ensure_progression()
	if _production_service == null:
		_production_service = FIVE_AREA_PRODUCTION_SERVICE.new(self, Dictionary(_save_data.get("production", {})))
	else:
		_production_service.call("configure", _progression, self)
	_configure_service_connections()


func _ensure_business_services() -> void:
	if _business_report_service == null:
		_business_report_service = BUSINESS_REPORT_SERVICE.new(Dictionary(_save_data.get("today_ledger", {})))
	if _daily_goal_service == null:
		_daily_goal_service = DAILY_GOAL_SERVICE.new(Dictionary(_save_data.get("daily_goal", {})))


func _configure_service_connections() -> void:
	if _production_service != null and not _production_service.is_connected("waste_recorded", _on_production_waste_recorded):
		_production_service.connect("waste_recorded", _on_production_waste_recorded)


func _on_production_waste_recorded(entry: Dictionary) -> void:
	_record_business_event({
		"event_id": _next_ledger_event_id(&"production_waste"),
		"kind": &"waste",
		"area_id": StringName(entry.get("area_id", &"")),
		"source_id": StringName(entry.get("device_id", entry.get("source_id", &""))),
		"quantity": maxi(int(entry.get("quantity", 1)), 1),
		"details": {
			"reason": entry.get("reason", &"discarded"),
			"attributed_cost": maxi(int(entry.get("material_cost", entry.get("attributed_cost", 0))), 0),
		},
	})
	_sync_business_services_to_save()


func _record_business_event(event: Dictionary) -> Dictionary:
	_ensure_business_services()
	var recorded: Dictionary = _business_report_service.call("record_event", event)
	if not bool(recorded.get("changed", false)):
		return recorded
	var normalized := Dictionary(recorded.get("event", event))
	var goal_result: Dictionary = _daily_goal_service.call("record_business_event", normalized)
	if bool(goal_result.get("completed", false)):
		_apply_daily_goal_reward(goal_result)
	_sync_business_services_to_save()
	business_ledger_changed.emit(Dictionary(_business_report_service.call("snapshot")).duplicate(true))
	daily_goal_changed.emit(current_daily_goal())
	return recorded


func _apply_daily_goal_reward(request: Dictionary) -> void:
	var reward_event_id := StringName(request.get("reward_event_id", &""))
	if reward_event_id.is_empty():
		return
	var marked: Dictionary = _daily_goal_service.call("mark_rewarded", reward_event_id)
	if not bool(marked.get("changed", false)):
		return
	_ensure_progression()
	_progression.set("coins", int(_progression.get("coins")) + maxi(int(request.get("reward_coins", 0)), 0))
	_progression.set("reputation", maxi(int(_progression.get("reputation")) + maxi(int(request.get("reward_reputation", 0)), 0), 0))
	_sync_progression_to_save()
	coins_changed.emit(int(_progression.get("coins")))
	progression_changed.emit(five_area_progression_snapshot())


func _daily_goal_context() -> Dictionary:
	_ensure_progression()
	var progression_snapshot := five_area_progression_snapshot()
	var tutorial := Dictionary(progression_snapshot.get("tutorial", {}))
	return {
		"current_day": int(progression_snapshot.get("current_day", 1)),
		"unlocked_area_ids": progression_snapshot.get("unlocked_area_ids", []),
		"tutorial_completed_area_ids": tutorial.get("completed_area_ids", []),
		"specialization": progression_snapshot.get("specialization", {}),
		"order_rng_seed": int(_save_data.get("order_rng_seed", 1)),
	}


func _next_ledger_event_id(prefix: StringName) -> StringName:
	var sequence := maxi(int(_save_data.get("ledger_event_sequence", 0)), 0) + 1
	_save_data["ledger_event_sequence"] = sequence
	return StringName("day.%d.%s.%d" % [int(_progression.get("current_day")) if _progression != null else 1, str(prefix), sequence])


func _sync_business_services_to_save() -> void:
	if not has_save():
		return
	_ensure_business_services()
	_save_data["today_ledger"] = Dictionary(_business_report_service.call("snapshot")).duplicate(true)
	_save_data["daily_goal"] = Dictionary(_daily_goal_service.call("snapshot")).duplicate(true)


func _sync_progression_to_save() -> void:
	if has_save():
		_save_data["progression"] = five_area_progression_snapshot()


func _sync_pancake_holding_tray_to_save() -> void:
	if has_save():
		_save_data["pancake_holding_tray"] = pancake_holding_tray_snapshot()


func _sync_formal_orders_to_save() -> void:
	if has_save():
		_save_data["formal_orders"] = formal_order_snapshot()


func _sync_production_to_save() -> void:
	if has_save() and _production_service != null:
		_save_data["production"] = Dictionary(_production_service.call("snapshot")).duplicate(true)


func _mark_f3_order_started(order_id: StringName, source_id: StringName) -> void:
	if not order_id.is_empty():
		mark_formal_order_production_started(order_id, source_id)


func _ensure_save_shape() -> void:
	var inventory_source := Dictionary(_save_data.get("inventory", {})).duplicate(true)
	var retired_sauce_stock := maxi(
		int(inventory_source.get("stock.pancake.sauce.red_chili", 0)),
		int(inventory_source.get("stock.pancake.sauce.tomato", 0)),
	)
	if retired_sauce_stock > int(inventory_source.get("stock.pancake.sauce.sweet_flour", 0)):
		inventory_source["stock.pancake.sauce.sweet_flour"] = retired_sauce_stock
	_save_data["inventory"] = _normalize_inventory(inventory_source)
	_save_data["prepared_product_slots"] = _normalize_prepared_product_slots(Dictionary(_save_data.get("prepared_product_slots", {})))
	if not _save_data.has("restock_progress"):
		_save_data["restock_progress"] = {}
	if not _save_data.has("pending_tray_payments"):
		_save_data["pending_tray_payments"] = {}
	if not _save_data.has("day_open"):
		_save_data["day_open"] = true
	if not _save_data.has("business_paused"):
		_save_data["business_paused"] = false
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
	_save_data["formal_orders"] = _normalize_formal_orders_for_active_catalog(Dictionary(_save_data.get("formal_orders", {})))
	if not _save_data.has("production"):
		_save_data["production"] = FIVE_AREA_PRODUCTION_SERVICE.new().snapshot()
	if not _save_data.has("today_ledger"):
		var ledger := BUSINESS_REPORT_SERVICE.new()
		ledger.call("begin_day", int(Dictionary(_save_data.get("progression", {})).get("current_day", 1)))
		_save_data["today_ledger"] = ledger.call("snapshot")
	if not _save_data.has("daily_goal"):
		_save_data["daily_goal"] = DAILY_GOAL_SERVICE.new().snapshot()
	if not _save_data.has("last_bill"):
		_save_data["last_bill"] = {}
	if not _save_data.has("ledger_event_sequence"):
		_save_data["ledger_event_sequence"] = 0
	if not _save_data.has("pancake_order_cursor"):
		_save_data["pancake_order_cursor"] = 0
	if not _save_data.has("pancake_orders_issued_today"):
		_save_data["pancake_orders_issued_today"] = 0
	if not _save_data.has("order_rng_seed"):
		_save_data["order_rng_seed"] = maxi(int(_save_data.get("started_at_unix", 1)), 1)
	if not _save_data.has("customer_arrival"):
		var existing_queue_size := Array(Dictionary(_save_data.get("formal_orders", {})).get("queue_order_ids", [])).size()
		var arrival_state := _new_customer_arrival_state(int(_save_data.get("order_rng_seed", 1)))
		# Preserve an already-running legacy day rather than deleting its visible
		# customers during migration. New business days always start in restocking.
		if existing_queue_size > 0:
			arrival_state["phase"] = &"open"
			arrival_state["restock_remaining_seconds"] = 0.0
		_save_data["customer_arrival"] = arrival_state
	if not _save_data.has("order_sequence"):
		_save_data["order_sequence"] = maxi(int(Dictionary(_save_data.get("formal_orders", {})).get("sequence", 0)), 0)
	if not _save_data.has("tutorial_order_generated_day"):
		_save_data["tutorial_order_generated_day"] = 0
	if not _save_data.has(ORDER_PROMOTIONS_KEY):
		_save_data[ORDER_PROMOTIONS_KEY] = []
	_save_data[ORDER_PROMOTIONS_KEY] = _normalize_order_promotions(Array(_save_data.get(ORDER_PROMOTIONS_KEY, [])))
	_save_data[SPECIAL_CUSTOMER_STATE_KEY] = SPECIAL_CUSTOMER_CATALOG.normalize_state(
		Dictionary(_save_data.get(SPECIAL_CUSTOMER_STATE_KEY, {})),
		int(Dictionary(_save_data.get("progression", {})).get("current_day", 1)),
	)
	if not _save_data.has(RECONCILED_FORMAL_ORDER_IDS_KEY):
		_save_data[RECONCILED_FORMAL_ORDER_IDS_KEY] = []


func _normalize_formal_orders_for_active_catalog(value: Dictionary) -> Dictionary:
	var normalized := value.duplicate(true)
	var orders := Dictionary(normalized.get("orders", {})).duplicate(true)
	var retired_order_ids := {}
	for raw_order_id in orders:
		var order := Dictionary(orders[raw_order_id]).duplicate(true)
		var contains_retired_product := false
		for item_variant in Array(order.get("items", [])):
			var product_id := StringName(Dictionary(item_variant).get("product_id", &""))
			if not product_id.is_empty() and CATALOG.product_definition(product_id).is_empty():
				contains_retired_product = true
				break
		if not contains_retired_product:
			continue
		retired_order_ids[str(raw_order_id)] = true
		order["state"] = &"abandoned"
		order["status"] = &"failed"
		order["abandon_reason"] = &"retired_content"
		orders[raw_order_id] = order
	normalized["orders"] = orders
	normalized["active_order_ids"] = _without_retired_order_ids(normalized.get("active_order_ids", []), retired_order_ids)
	normalized["queue_order_ids"] = _without_retired_order_ids(normalized.get("queue_order_ids", []), retired_order_ids)
	var active_ids := Array(normalized.get("active_order_ids", []))
	normalized["active_order_id"] = str(active_ids[0]) if not active_ids.is_empty() else ""
	return normalized


static func _without_retired_order_ids(values: Variant, retired_order_ids: Dictionary) -> PackedStringArray:
	var kept := PackedStringArray()
	for value in Array(values):
		if not retired_order_ids.has(str(value)):
			kept.append(str(value))
	return kept


static func _normalize_order_promotions(values: Array) -> Array:
	var normalized: Array = []
	for value in values:
		var promotion := Dictionary(value).duplicate(true)
		var kind := StringName(promotion.get("kind", &""))
		var target_id := StringName(promotion.get("target_id", &""))
		var target_exists := (
			(kind == &"product" and not CATALOG.product_definition(target_id).is_empty())
			or (kind == &"pancake_stock" and not CATALOG.stock_definition(target_id).is_empty())
			or (kind == &"area" and not CATALOG.area_definition(target_id).is_empty())
		)
		if target_exists and int(promotion.get("remaining_orders", 0)) > 0:
			normalized.append(promotion)
	return normalized


static func _empty_prepared_product_slots() -> Dictionary:
	return {
		"slot.04": [],
		"slot.chicken": [],
	}


static func _prepared_slot_id_for_product(product_id: StringName) -> StringName:
	for slot_id in PREPARED_PRODUCT_SLOT_DEFINITIONS:
		var definition := Dictionary(PREPARED_PRODUCT_SLOT_DEFINITIONS[slot_id])
		var accepted_product_ids := Array(definition.get("accepted_product_ids", [definition.get("product_id", &"")]))
		if accepted_product_ids.has(product_id):
			return StringName(slot_id)
	return &""


func _normalize_prepared_product_slots(value: Dictionary) -> Dictionary:
	var normalized := _empty_prepared_product_slots()
	var capacity_per_product := _prepared_product_capacity_per_product()
	for slot_id in PREPARED_PRODUCT_SLOT_DEFINITIONS:
		var products: Array = []
		var counts_by_product: Dictionary = {}
		for product_variant in Array(value.get(str(slot_id), value.get(slot_id, []))):
			var product := Dictionary(product_variant).duplicate(true)
			var product_id := StringName(product.get("product_id", &""))
			if product.is_empty() or not _prepared_product_slot_accepts_product(StringName(slot_id), product_id):
				continue
			if int(counts_by_product.get(product_id, 0)) >= capacity_per_product:
				continue
			products.append(product)
			counts_by_product[product_id] = int(counts_by_product.get(product_id, 0)) + 1
		normalized[str(slot_id)] = products
	return normalized


func _prepared_product_capacity_per_product() -> int:
	_ensure_progression()
	var tier := int(_progression.call("device_tier", &"device.youtiao_fryer"))
	return maxi(int(CATALOG.device_tier(&"device.youtiao_fryer", tier).get("capacity", 4)), 0)


func _prepared_product_slot_capacity(slot_id: StringName) -> int:
	var definition := Dictionary(PREPARED_PRODUCT_SLOT_DEFINITIONS.get(slot_id, {}))
	var accepted_product_ids := Array(definition.get("accepted_product_ids", [definition.get("product_id", &"")]))
	return _prepared_product_capacity_per_product() * accepted_product_ids.size()


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


## Repair a settled tutorial after an interrupted save. Tutorial completion is
## based on completing the guided delivery flow, not recipe matching.
func _reconcile_completed_tutorial_order() -> void:
	if not has_save():
		return
	_ensure_progression()
	_ensure_order_service()
	var tutorial := Dictionary(_progression.call("tutorial_snapshot"))
	var tutorial_kind := StringName(tutorial.get("active_kind", &""))
	var tutorial_id := StringName(tutorial.get("active_id", &""))
	if tutorial_id.is_empty():
		return
	var formal_orders := Dictionary(Dictionary(_order_service.call("snapshot")).get("orders", {}))
	for order_variant in formal_orders.values():
		var order := Dictionary(order_variant)
		var identity := _tutorial_identity_for_order(order)
		if (
			StringName(order.get("state", &"")) != &"settled"
			or StringName(order.get("status", &"")) not in [&"completed", &"failed"]
			or StringName(identity.get("kind", &"")) != tutorial_kind
			or StringName(identity.get("tutorial_id", &"")) != tutorial_id
		):
			continue
		var completed := Dictionary(_progression.call("complete_tutorial", tutorial_kind, tutorial_id))
		if bool(completed.get("success", false)):
			_sync_progression_to_save()
			var arrival_state := customer_arrival_snapshot()
			if StringName(arrival_state.get("phase", &"")) == &"open" and float(arrival_state.get("next_arrival_remaining_seconds", -1.0)) < 0.0:
				_schedule_next_customer_arrival(arrival_state)
				_save_data["customer_arrival"] = _normalized_customer_arrival_state(arrival_state)
			_touch_and_write()
		return


func _new_inventory_snapshot() -> Dictionary:
	var inventory := {}
	for stock_id in CATALOG.stock_ids():
		inventory[str(stock_id)] = 0
	return inventory


func _normalize_inventory(source: Dictionary) -> Dictionary:
	var normalized := _new_inventory_snapshot()
	for stock_id in CATALOG.stock_ids():
		var key := str(stock_id)
		if bool(CATALOG.stock_definition(stock_id).get("unlimited", false)):
			normalized[key] = 0
			continue
		if source.has(key):
			var quantity := maxi(int(source[key]), 0)
			if bool(CATALOG.stock_definition(stock_id).get("fixed_restock_capacity", false)):
				quantity = mini(quantity, maxi(int(CATALOG.stock_definition(stock_id).get("restock_capacity", 0)), 0))
			normalized[key] = quantity
	return normalized


func _restock_capacity(_stock_id: StringName, definition: Dictionary) -> int:
	var base_capacity := maxi(int(definition.get("restock_capacity", 0)), 0)
	if bool(definition.get("fixed_restock_capacity", false)):
		return base_capacity
	return maxi(base_capacity, int(_progression.get("stock_capacity")))


func _stable_pancake_stock_ids(source_ids: Array, mapping: Dictionary) -> PackedStringArray:
	var stable_ids := PackedStringArray()
	for source_id in source_ids:
		var requested: StringName = StringName(source_id)
		var stable_id: StringName = requested if str(requested).begins_with("stock.") else mapping.get(requested, &"")
		if not stable_id.is_empty():
			stable_ids.append(str(stable_id))
	return stable_ids


func _touch_and_write(immediate := false) -> void:
	_save_data["last_played_at_unix"] = int(Time.get_unix_time_from_system())
	# Start the merge window on the first dirty mutation only. Business time is
	# persisted once per second, so resetting this timer for every later mutation
	# would otherwise prevent the two-second safety write from ever firing.
	if not _save_dirty:
		_save_flush_elapsed = 0.0
	_save_dirty = true
	if _scene_binding_save_batch_active:
		_scene_binding_save_pending = true
	elif immediate:
		_write_save()


func flush_pending_save() -> bool:
	if not _save_dirty:
		return true
	if _scene_binding_save_batch_active:
		_scene_binding_save_pending = true
		return false
	return _write_save()


func _write_save() -> bool:
	if _scene_binding_save_batch_active:
		_scene_binding_save_pending = true
		_save_dirty = true
		return false
	var save_error := _atomic_store_text(_active_save_path, JSON.stringify(_save_data))
	if save_error != OK:
		_save_dirty = true
		push_warning("Could not write ProjectCake save data: %s" % error_string(save_error))
		return false
	_save_dirty = false
	_save_flush_elapsed = 0.0
	_save_write_count += 1
	return true


func _atomic_store_text(path: String, contents: String) -> Error:
	var absolute_path := ProjectSettings.globalize_path(path)
	var temp_path := absolute_path + SAVE_TEMP_SUFFIX
	var backup_path := absolute_path + SAVE_BACKUP_SUFFIX
	_remove_file_if_present(temp_path)
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(contents)
	file.flush()
	file.close()

	var had_previous := FileAccess.file_exists(path)
	if had_previous:
		_remove_file_if_present(backup_path)
		var backup_error := DirAccess.rename_absolute(absolute_path, backup_path)
		if backup_error != OK:
			_remove_file_if_present(temp_path)
			return backup_error

	var replace_error := DirAccess.rename_absolute(temp_path, absolute_path)
	if replace_error != OK:
		if had_previous and FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_path, absolute_path)
		_remove_file_if_present(temp_path)
		return replace_error
	_remove_file_if_present(backup_path)
	return OK


func _recover_interrupted_save_write() -> void:
	var absolute_path := ProjectSettings.globalize_path(_active_save_path)
	var temp_path := absolute_path + SAVE_TEMP_SUFFIX
	var backup_path := absolute_path + SAVE_BACKUP_SUFFIX
	if FileAccess.file_exists(_active_save_path):
		_remove_file_if_present(temp_path)
		_remove_file_if_present(backup_path)
		return
	if FileAccess.file_exists(temp_path):
		if DirAccess.rename_absolute(temp_path, absolute_path) == OK:
			_remove_file_if_present(backup_path)
			return
	if FileAccess.file_exists(backup_path):
		DirAccess.rename_absolute(backup_path, absolute_path)


func _remove_file_if_present(absolute_path: String) -> void:
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _load_settings() -> void:
	_settings = DEFAULT_SETTINGS.duplicate(true)
	var config := ConfigFile.new()
	if config.load(_active_settings_path) != OK:
		return
	_settings.master_volume = clampf(float(config.get_value("audio", "master_volume", DEFAULT_SETTINGS.master_volume)), 0.0, 100.0)
	_settings.sfx_volume = clampf(float(config.get_value("audio", "sfx_volume", DEFAULT_SETTINGS.sfx_volume)), 0.0, 100.0)
	_settings.fullscreen = bool(config.get_value("display", "fullscreen", DEFAULT_SETTINGS.fullscreen))
	_settings.ui_scale = _normalized_ui_scale(float(config.get_value("display", "ui_scale", DEFAULT_SETTINGS.ui_scale)))
	_settings.drag_sensitivity = clampf(float(config.get_value("input", "drag_sensitivity", DEFAULT_SETTINGS.drag_sensitivity)), 50.0, 150.0)
	_settings.key_bindings = _normalized_key_bindings(Dictionary(config.get_value("input", "key_bindings", DEFAULT_SETTINGS.key_bindings)))
	if not _key_binding_conflict(Dictionary(_settings.key_bindings)).is_empty():
		_settings.key_bindings = Dictionary(DEFAULT_SETTINGS.key_bindings).duplicate(true)


static func _normalized_ui_scale(value: float) -> float:
	var choices: Array[float] = [100.0, 125.0, 150.0]
	var closest: float = choices[0]
	for choice: float in choices:
		if absf(value - choice) < absf(value - closest):
			closest = choice
	return closest


static func _normalized_key_bindings(value: Dictionary) -> Dictionary:
	var result := Dictionary(DEFAULT_SETTINGS.key_bindings).duplicate(true)
	for action_value in result.keys():
		var action := str(action_value)
		var requested := int(value.get(action, value.get(StringName(action), result[action_value])))
		if requested > 0:
			result[action] = requested
	return result


static func _key_binding_conflict(bindings: Dictionary) -> PackedStringArray:
	var by_key := {}
	for action_value in bindings:
		var action := str(action_value)
		var keycode := int(bindings[action_value])
		if by_key.has(keycode):
			return PackedStringArray([str(by_key[keycode]), action])
		by_key[keycode] = action
	return PackedStringArray()


static func _apply_key_bindings(bindings: Dictionary) -> void:
	for action_value in bindings:
		var action := StringName(action_value)
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event := InputEventKey.new()
		event.physical_keycode = int(bindings[action_value])
		InputMap.action_add_event(action, event)


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


func _quality_adjusted_formal_quote(order: Dictionary, item_results: Array, quoted_coins: int) -> int:
	var items := Array(order.get("items", []))
	var raw_total := 0.0
	var adjusted_total := 0.0
	var premium := bool(_progression.call("owns_growth", &"growth.pricing.fresh_soy_milk.premium"))
	for item_index in range(items.size()):
		var item := Dictionary(items[item_index])
		var catalog_price := int(CATALOG.product_definition(StringName(item.get("product_id", &""))).get("base_sell_price", 0))
		var unit_price := float(item.get("base_price_coins", catalog_price))
		var item_quantity := maxi(int(item.get("quantity", 1)), 1)
		var raw_item := unit_price * float(item_quantity)
		raw_total += raw_item
		if StringName(item.get("area_id", &"")) != &"area.fresh_soy_milk":
			adjusted_total += raw_item
			continue
		var result := Dictionary(item_results[item_index]) if item_index < item_results.size() else {}
		var products := Array(result.get("products", []))
		if products.is_empty() and not Dictionary(result.get("product", {})).is_empty():
			products.append(Dictionary(result.get("product", {})))
		var soy_adjusted := 0.0
		for product_value in products:
			soy_adjusted += unit_price * float(Dictionary(product_value).get("quality_multiplier", 1.0))
		if products.size() < item_quantity:
			soy_adjusted += unit_price * float(item_quantity - products.size())
		if premium:
			soy_adjusted *= 1.3
		adjusted_total += soy_adjusted
	if raw_total <= 0.0:
		return maxi(quoted_coins, 0)
	var combo_multiplier := float(quoted_coins) / raw_total
	return maxi(roundi(adjusted_total * combo_multiplier), 0)


static func _has_delivered_formal_product(item_results: Array) -> bool:
	for item_result_value in item_results:
		var item_result := Dictionary(item_result_value)
		if not Array(item_result.get("products", [])).is_empty() or not Dictionary(item_result.get("product", {})).is_empty():
			return true
	return false


func _f3_reputation_delta(order_success: bool, grades: PackedStringArray) -> int:
	if not order_success:
		return -2
	var has_b := false
	var has_c := false
	for grade in grades:
		if grade == "C":
			has_c = true
		elif grade == "B":
			has_b = true
		elif grade != "A":
			# A prematurely released cup can reach the waste threshold while still
			# matching the requested flavour and sweetness. It must never receive
			# the all-A reputation reward.
			has_c = true
	if has_c:
		return 1
	if has_b:
		return 3
	return 4


func _grade_for_score(score: float) -> String:
	if score >= 85.0:
		return "A"
	if score >= 65.0:
		return "B"
	return "C"
