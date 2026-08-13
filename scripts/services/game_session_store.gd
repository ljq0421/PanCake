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
const SETTINGS_PATH := "user://project_cake_settings.cfg"
const SAVE_VERSION := 3
const SAVE_KIND := "five_area_v1"
const ORDER_PROMOTIONS_KEY := "pending_order_promotions"
const BUSINESS_DAY_DURATION_SECONDS := 120.0
const PROGRESSION_SERVICE := preload("res://scripts/services/five_area_progression_service.gd")
const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const PANCAKE_HOLDING_TRAY_MODEL := preload("res://scripts/gameplay/pancake_holding_tray_model.gd")
const FIVE_AREA_ORDER_SERVICE := preload("res://scripts/services/five_area_order_service.gd")
const FIVE_AREA_PRODUCTION_SERVICE := preload("res://scripts/services/five_area_production_service.gd")
const FIVE_AREA_PANCAKE_ORDER_GENERATOR := preload("res://scripts/services/five_area_pancake_order_generator.gd")
const FIVE_AREA_PLAYABLE_ORDER_GENERATOR := preload("res://scripts/services/five_area_playable_order_generator.gd")
const BUSINESS_REPORT_SERVICE := preload("res://scripts/services/business_report_service.gd")
const DAILY_GOAL_SERVICE := preload("res://scripts/services/daily_goal_service.gd")
const ATTENTION_SERVICE := preload("res://scripts/services/attention_service.gd")
const PREPARED_PRODUCT_SLOT_CAPACITY := 6
const PACKAGED_DRINK_SPLIT_MIGRATION_VERSION := 1
const PACKAGED_DRINK_SPLIT_MIGRATION_KEY := "packaged_drink_split_migration_version"
const PACKAGED_DRINK_SPLIT_PENDING_KEY := "packaged_drink_split_migration_pending"
const PACKAGED_DRINK_SUSPENDED_TIER_KEY := "packaged_drink_suspended_heater_tier"
const PACKAGED_DRINK_HEATER_MODEL := preload("res://scripts/gameplay/packaged_drink_heater_model.gd")
const PREPARED_PRODUCT_SLOT_DEFINITIONS := {
	&"slot.04": {"product_id": &"product.youtiao.plain", "recipe_id": &"recipe.youtiao.plain"},
	&"slot.05": {"product_id": &"product.youtiao.oil_cake", "recipe_id": &"recipe.youtiao.oil_cake"},
	&"slot.06": {"product_id": &"product.youtiao.sugar_oil_cake", "recipe_id": &"recipe.youtiao.sugar_oil_cake"},
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
	&"youtiao": &"stock.pancake.youtiao",
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
var _production_service: RefCounted
var _business_report_service: RefCounted
var _daily_goal_service: RefCounted
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
		"business_day_remaining_seconds": BUSINESS_DAY_DURATION_SECONDS,
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
		PACKAGED_DRINK_SPLIT_MIGRATION_KEY: PACKAGED_DRINK_SPLIT_MIGRATION_VERSION,
		PACKAGED_DRINK_SPLIT_PENDING_KEY: false,
		PACKAGED_DRINK_SUSPENDED_TIER_KEY: -1,
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


func mark_session_left() -> void:
	if not has_save():
		return
	_save_data["business_paused"] = true
	_sync_progression_to_save()
	_sync_pancake_holding_tray_to_save()
	_sync_formal_orders_to_save()
	_sync_production_to_save()
	_sync_business_services_to_save()
	_touch_and_write()


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


func ensure_active_playable_order() -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_progression()
	_ensure_order_service()
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
	var queue_target := 4 if tutorial_owns_storefront else FIVE_AREA_ORDER_SERVICE.MAX_OPEN_ORDERS
	var needed := maxi(queue_target - queue.size(), 0)
	if needed <= 0:
		return {"success": true, "created": false, "order": active_formal_order(), "active_orders": active_formal_orders(), "queue": queue}
	var next_sequence := maxi(int(_save_data.get("order_sequence", 0)), 0) + 1
	var promotion_context := _active_order_promotion_context()
	if promotion_context.is_empty():
		promotion_context = _tutorial_promotion_context(queue, tutorial_kind, tutorial_id, tutorial_generated_today)
	var generated_batch: Dictionary = FIVE_AREA_PLAYABLE_ORDER_GENERATOR.generate_queue_candidates(
		five_area_progression_snapshot(),
		inventory_snapshot(),
		int(_save_data.get("order_rng_seed", 1)),
		next_sequence,
		needed,
		int(_progression.get("current_day")),
		int(_save_data.get("tutorial_order_generated_day", 0)),
		promotion_context,
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
		_sync_formal_orders_to_save()
		_touch_and_write()
		order_changed.emit({"active": Dictionary(result.get("order", {})).duplicate(true), "queue": Array(result.get("queue", [])).duplicate(true)})
	result["order"] = active_formal_order()
	result["active_orders"] = active_formal_orders()
	return result


func _queue_contains_tutorial(queue: Array) -> bool:
	for order_variant in queue:
		if not StringName(_tutorial_identity_for_order(Dictionary(order_variant)).get("tutorial_id", &"")).is_empty():
			return true
	return false


func _active_order_promotion_context() -> Dictionary:
	var promotions := Array(_save_data.get(ORDER_PROMOTIONS_KEY, []))
	for promotion_variant in promotions:
		var promotion := Dictionary(promotion_variant)
		var remaining := clampi(int(promotion.get("remaining_orders", 0)), 0, 3)
		if remaining <= 0:
			continue
		return {
			"kind": StringName(promotion.get("kind", &"")),
			"target_id": StringName(promotion.get("target_id", &"")),
			"source_growth_id": StringName(promotion.get("source_growth_id", &"")),
			"next_index": 3 - remaining,
		}
	return {}


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
	promotions.append(promotion.duplicate(true))
	_save_data[ORDER_PROMOTIONS_KEY] = promotions


func _enqueue_growth_order_promotions(activated_growth_ids: Array) -> void:
	for growth_id_variant in activated_growth_ids:
		var growth_id := StringName(growth_id_variant)
		# Area/device teaching owns its own three-order follow-up window. Keeping
		# it out of the content queue prevents the tutorial product from jumping
		# ahead of an independently unlocked recipe or topping on the same day.
		if str(growth_id).begins_with("growth.area.") or str(growth_id).begins_with("growth.equipment."):
			continue
		var definition := CATALOG.growth_definition(growth_id)
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
	_ensure_order_service()
	return Array(_order_service.call("waiting_orders")).duplicate(true)


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
	if expired_results.is_empty():
		_save_data["formal_orders"] = formal_order_snapshot()
	else:
		var refill := ensure_active_playable_order()
		result["refill"] = refill
	result["active_orders"] = active_formal_orders()
	return result


func preview_formal_order_refusal(order_id: StringName) -> Dictionary:
	_ensure_order_service()
	return Dictionary(_order_service.call("preview_refusal", order_id)).duplicate(true)


func refuse_formal_order(order_id: StringName) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_order_service()
	var result: Dictionary = _order_service.call("refuse_order", order_id)
	if bool(result.get("success", false)) and not bool(result.get("already_settled", false)):
		_finalize_failed_formal_order(result)
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
		progression_changed.emit(five_area_progression_snapshot())
		order_changed.emit({})
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


## Moves exactly one available product into the requested order-card item.
## Product mismatches are intentionally reported but never used as blockers.
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
	product["reservation_origin"] = _normalized_product_source_ref(source_ref)
	product["return_policy"] = &"return_stock" if StringName(source_ref.get("source_kind", &"")) == &"inventory" else &"waste_only"
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


func remove_staged_product(order_id: StringName, item_index: int, disposition: StringName) -> Dictionary:
	if disposition not in [&"return_stock", &"waste"]:
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
	var candidate := Dictionary(products.back())
	if disposition == &"return_stock":
		if StringName(candidate.get("return_policy", &"waste_only")) != &"return_stock" or StringName(candidate.get("area_id", &"")) != &"area.packaged_drink" or StringName(candidate.get("temperature_mode", &"")) != &"room_temperature":
			return {"success": false, "reason": &"return_not_allowed"}
		var return_status := _preview_staged_stock_return(candidate)
		if not bool(return_status.get("success", false)):
			return return_status
	var rollback := _tray_transaction_snapshot()
	var removed := Dictionary(_order_service.call("remove_attached_product", order_id, item_index))
	if not bool(removed.get("success", false)):
		return removed
	var product := Dictionary(removed.get("product", {}))
	var disposition_result: Dictionary
	if disposition == &"return_stock":
		disposition_result = _return_staged_drink_to_stock(product)
	else:
		disposition_result = Dictionary(_production_service.call("record_staged_waste", product, &"tray_correction"))
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
	var product_id := StringName(source_ref.get("product_id", &""))
	match source_kind:
		&"inventory":
			var definition := CATALOG.product_definition(product_id)
			if StringName(definition.get("area_id", &"")) != &"area.packaged_drink":
				return {"success": false, "reason": &"invalid_inventory_product"}
			var stock_id := StringName(definition.get("stock_id", &""))
			if stock_id.is_empty() or int(inventory_snapshot().get(str(stock_id), 0)) <= 0:
				return {"success": false, "reason": &"insufficient_stock", "stock_id": stock_id}
			return {"success": true, "product": {"product_instance_id": &"preview.inventory", "area_id": &"area.packaged_drink", "product_id": product_id, "temperature_mode": &"room_temperature", "ingredient_ids": PackedStringArray(), "sauce_ids": PackedStringArray(), "status": &"available"}}
		&"heater_slot":
			return Dictionary(_production_service.call("preview_collect_drink", source_index))
		&"youtiao_output":
			return Dictionary(_production_service.call("preview_collect_batch", &"device.youtiao_fryer", 1, source_index))
		&"prepared_product_slot":
			return preview_take_prepared_product(StringName(source_ref.get("source_slot_id", &"")))
		&"soy_output":
			return Dictionary(_production_service.call("preview_collect_soy_output", source_index)) if source_index >= 0 else Dictionary(_production_service.call("preview_collect_soy", 1))
		&"steamer_layer":
			return Dictionary(_production_service.call("preview_collect_steamer", source_index))
		&"pancake_holding":
			var tray_preview := Dictionary(_pancake_holding_tray.call("preview_serve", source_index, order_item))
			if bool(tray_preview.get("success", false)):
				tray_preview["product"] = Dictionary(tray_preview.get("product", {})).duplicate(true)
			return tray_preview
		&"pancake_ready":
			var ready_product := Dictionary(source_ref.get("product", {})).duplicate(true)
			return {"success": not ready_product.is_empty(), "reason": &"" if not ready_product.is_empty() else &"pancake_not_ready", "product": ready_product}
		_:
			return {"success": false, "reason": &"unsupported_product_source", "source_kind": source_kind}


func _collect_product_source(source_ref: Dictionary, order_item: Dictionary) -> Dictionary:
	var source_kind := StringName(source_ref.get("source_kind", &""))
	var source_index := int(source_ref.get("source_index", -1))
	match source_kind:
		&"inventory": return Dictionary(_production_service.call("create_room_temperature_drink", StringName(source_ref.get("product_id", &""))))
		&"heater_slot": return Dictionary(_production_service.call("collect_drink", source_index))
		&"youtiao_output": return Dictionary(_production_service.call("collect_batch", &"device.youtiao_fryer", 1, source_index))
		&"prepared_product_slot": return take_prepared_product(StringName(source_ref.get("source_slot_id", &"")))
		&"soy_output": return Dictionary(_production_service.call("collect_soy_output", source_index)) if source_index >= 0 else Dictionary(_production_service.call("collect_soy", 1))
		&"steamer_layer": return Dictionary(_production_service.call("collect_steamer", source_index))
		&"pancake_holding":
			var served := Dictionary(_pancake_holding_tray.call("serve", source_index, order_item))
			if bool(served.get("success", false)):
				served["product"] = Dictionary(served.get("served_product", {})).duplicate(true)
			return served
		&"pancake_ready":
			var product := Dictionary(source_ref.get("product", {})).duplicate(true)
			var consumed_stock_ids: Array[StringName] = [&"stock.pancake.batter"]
			for stock_value in Array(product.get("sauce_ids", [])):
				var stock_id := StringName(stock_value)
				if not stock_id.is_empty():
					consumed_stock_ids.append(stock_id)
			var consumed := consume_inventory_stock_ids(consumed_stock_ids)
			if not bool(consumed.get("success", false)):
				return consumed
			return {"success": true, "product": product, "consumed_stock_ids": consumed_stock_ids}
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


func _preview_staged_stock_return(product: Dictionary) -> Dictionary:
	var definition := CATALOG.product_definition(StringName(product.get("product_id", &"")))
	var stock_id := StringName(definition.get("stock_id", &""))
	if stock_id.is_empty():
		return {"success": false, "reason": &"return_stock_missing"}
	var status := five_area_restock_status(stock_id)
	if not bool(status.get("success", false)):
		return status
	if int(status.get("current_stock", 0)) >= int(status.get("capacity", 0)):
		return {"success": false, "reason": &"stock_capacity_full", "stock_id": stock_id}
	return {"success": true, "stock_id": stock_id}


func _return_staged_drink_to_stock(product: Dictionary) -> Dictionary:
	var preview := _preview_staged_stock_return(product)
	if not bool(preview.get("success", false)):
		return preview
	var stock_id := StringName(preview.get("stock_id", &""))
	var inventory := inventory_snapshot()
	inventory[str(stock_id)] = int(inventory.get(str(stock_id), 0)) + 1
	var saved := save_inventory(inventory)
	if bool(saved.get("success", false)):
		saved["stock_id"] = stock_id
	return saved


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


func f3_machine_snapshot(device_id: StringName) -> Dictionary:
	_ensure_production_service()
	return Dictionary(_production_service.call("machine_snapshot", device_id)).duplicate(true)


func advance_f3_production(delta: float) -> void:
	if not has_save() or delta <= 0.0 or get_tree().paused or is_business_paused():
		return
	_ensure_progression()
	if not bool(_progression.get("day_open")):
		return
	_ensure_production_service()
	_production_service.call("advance_time", delta)
	_sync_production_to_save()
	production_changed.emit(five_area_production_snapshot())


func load_f3_drink(slot_index: int, product_id: StringName, order_id: StringName = &"") -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_production_service()
	var result: Dictionary = _production_service.call("load_drink", slot_index, product_id)
	if bool(result.get("success", false)):
		_mark_f3_order_started(order_id, StringName("device.packaged_drink_heater.slot.%d" % slot_index))
		_sync_production_to_save()
		_touch_and_write()
		production_changed.emit(five_area_production_snapshot())
	return result


func deliver_room_temperature_drink(order_id: StringName, item_index: int, product_id: StringName) -> Dictionary:
	return stage_product_to_order({"source_kind": &"inventory", "source_index": -1, "product_id": product_id}, order_id, item_index)


func deliver_heated_drink(slot_index: int, order_id: StringName, item_index: int) -> Dictionary:
	_ensure_production_service()
	var preview: Dictionary = _production_service.call("preview_collect_drink", slot_index)
	if not bool(preview.get("success", false)):
		return preview
	return stage_product_to_order({"source_kind": &"heater_slot", "source_index": slot_index, "product_id": StringName(Dictionary(preview.get("product", {})).get("product_id", &""))}, order_id, item_index)


func discard_f3_drink(slot_index: int) -> Dictionary:
	_ensure_production_service()
	var result: Dictionary = _production_service.call("discard_drink", slot_index)
	if bool(result.get("success", false)):
		_sync_production_to_save()
		_touch_and_write()
		production_changed.emit(five_area_production_snapshot())
	return result


func reheat_f3_drink(slot_index: int) -> Dictionary:
	_ensure_production_service()
	var result: Dictionary = _production_service.call("reheat_drink", slot_index)
	if bool(result.get("success", false)):
		_sync_production_to_save()
		_touch_and_write()
		production_changed.emit(five_area_production_snapshot())
	return result


func discard_product_source(source_ref: Dictionary) -> Dictionary:
	if not bool(source_ref.get("discardable", false)):
		return {"success": false, "reason": &"source_not_discardable"}
	match StringName(source_ref.get("source_kind", &"")):
		&"heater_slot":
			return discard_f3_drink(int(source_ref.get("source_index", -1)))
		&"soy_output":
			return discard_f4_soy(int(source_ref.get("source_index", -1)))
		&"youtiao_output":
			return discard_ready_youtiao(int(source_ref.get("source_index", -1)))
		&"steamer_layer":
			return discard_f4_steamer(int(source_ref.get("source_index", -1)))
		&"prepared_product_slot":
			return discard_prepared_product(StringName(source_ref.get("source_slot_id", &"")))
	return {"success": false, "reason": &"unsupported_product_source"}


func discard_ready_youtiao(source_index: int = -1) -> Dictionary:
	_ensure_production_service()
	var result: Dictionary = _production_service.call("discard_ready_youtiao", source_index)
	if bool(result.get("success", false)):
		_persist_production_change()
	return result


func discard_prepared_product(slot_id: StringName) -> Dictionary:
	var preview := preview_take_prepared_product(slot_id)
	if not bool(preview.get("success", false)):
		return preview
	var slots := prepared_product_slots_snapshot()
	var products: Array = Array(slots.get(str(slot_id), [])).duplicate(true)
	var product := Dictionary(products.pop_front()).duplicate(true)
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


func confirm_and_run_youtiao_auto_load(recipe_id: StringName, quantity: int) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_production_service()
	var confirmed: Dictionary = _production_service.call("confirm_youtiao_job_profile", recipe_id, quantity)
	if not bool(confirmed.get("success", false)):
		return confirmed
	var result: Dictionary = _production_service.call("run_confirmed_youtiao_auto_load")
	result["job_profile"] = Dictionary(confirmed.get("job_profile", {})).duplicate(true)
	# Confirmation is itself durable profile state. Persist it even when execution
	# fails; load_batch already rolls the fryer back before returning any stock
	# failure, so this path never deducts inventory on a failed load.
	_sync_production_to_save()
	_touch_and_write()
	production_changed.emit(five_area_production_snapshot())
	return result


func perform_f3_youtiao_action(action_id: StringName) -> Dictionary:
	_ensure_production_service()
	var result: Dictionary = _production_service.call("perform_action", &"device.youtiao_fryer", action_id)
	if bool(result.get("success", false)):
		_sync_production_to_save()
		_touch_and_write()
		production_changed.emit(five_area_production_snapshot())
	return result


func deliver_f3_youtiao(order_id: StringName, item_index: int) -> Dictionary:
	var order := formal_order(order_id)
	var items := Array(order.get("items", []))
	if item_index < 0 or item_index >= items.size():
		return {"success": false, "reason": &"order_item_missing"}
	var product_id := StringName(Dictionary(items[item_index]).get("product_id", &""))
	var output_ref := {"source_kind": &"youtiao_output", "source_index": -1, "product_id": product_id}
	var output_preview := preview_stage_product_to_order(output_ref, order_id, item_index)
	if bool(output_preview.get("success", false)) and StringName(Dictionary(output_preview.get("product", {})).get("product_id", &"")) == product_id:
		return stage_product_to_order(output_ref, order_id, item_index)
	var slot_id := _prepared_slot_id_for_product(product_id)
	if slot_id.is_empty():
		return {"success": false, "reason": &"prepared_product_slot_missing", "product_id": product_id}
	return stage_product_to_order({"source_kind": &"prepared_product_slot", "source_slot_id": slot_id, "source_index": -1, "product_id": product_id}, order_id, item_index)


func preview_take_ready_youtiao_for_pancake() -> Dictionary:
	_ensure_production_service()
	var preview := Dictionary(_production_service.call("preview_collect_batch", &"device.youtiao_fryer", 1))
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
	var collected := Dictionary(_production_service.call("collect_batch", &"device.youtiao_fryer", 1))
	if bool(collected.get("success", false)):
		_persist_production_change()
	return collected


func discard_f3_youtiao() -> Dictionary:
	_ensure_production_service()
	var result: Dictionary = _production_service.call("discard_batch", &"device.youtiao_fryer")
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
		_mark_f3_order_started(order_id, &"device.fresh_soy_milk_machine")
		_persist_production_change()
	return result


func perform_f4_soy_action(action_id: StringName) -> Dictionary:
	_ensure_production_service()
	var result: Dictionary = _production_service.call("perform_soy_action", action_id)
	if bool(result.get("success", false)):
		_persist_production_change()
	return result


func deliver_f4_soy(order_id: StringName, item_index: int, output_slot_index: int = -1) -> Dictionary:
	_ensure_production_service()
	var preview: Dictionary = _production_service.call("preview_collect_soy_output", output_slot_index) if output_slot_index >= 0 else _production_service.call("preview_collect_soy", 1)
	if not bool(preview.get("success", false)):
		return preview
	return stage_product_to_order({"source_kind": &"soy_output", "source_index": output_slot_index, "product_id": StringName(Dictionary(preview.get("product", {})).get("product_id", &""))}, order_id, item_index)


func discard_f4_soy(output_slot_index: int = -1) -> Dictionary:
	_ensure_production_service()
	var result: Dictionary = _production_service.call("discard_soy_output", output_slot_index) if output_slot_index >= 0 else _production_service.call("discard_soy")
	if bool(result.get("success", false)):
		_persist_production_change()
	return result


func load_f4_steamer_layer(layer_index: int, recipe_id: StringName, quantity: int = 1, order_id: StringName = &"") -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_production_service()
	var result: Dictionary = _production_service.call("load_steamer_layer", layer_index, recipe_id, quantity)
	if bool(result.get("success", false)):
		_mark_f3_order_started(order_id, StringName("device.steamer.layer.%d" % layer_index))
		_persist_production_change()
	return result


func perform_f4_steamer_action(layer_index: int, action_id: StringName) -> Dictionary:
	_ensure_production_service()
	var result: Dictionary = _production_service.call("perform_steamer_action", layer_index, action_id)
	if bool(result.get("success", false)):
		_persist_production_change()
	return result


func deliver_f4_steamer(layer_index: int, order_id: StringName, item_index: int) -> Dictionary:
	_ensure_production_service()
	var preview: Dictionary = _production_service.call("preview_collect_steamer", layer_index)
	if not bool(preview.get("success", false)):
		return preview
	return stage_product_to_order({"source_kind": &"steamer_layer", "source_index": layer_index, "product_id": StringName(Dictionary(preview.get("product", {})).get("product_id", &""))}, order_id, item_index)


func discard_f4_steamer(layer_index: int) -> Dictionary:
	_ensure_production_service()
	var result: Dictionary = _production_service.call("discard_steamer", layer_index)
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
	var result: Dictionary = _order_service.call("settle_order", order_id)
	if bool(result.get("success", false)):
		_sync_formal_orders_to_save()
		_touch_and_write()
	return result


func settle_f3_order(order_id: StringName, submit_incomplete: bool = false) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_order_service()
	_ensure_progression()
	var order := formal_order(order_id)
	if StringName(order.get("order_id", &"")) != order_id:
		return {"success": false, "reason": &"order_not_active"}
	var settlement: Dictionary = _order_service.call("settle_order", order_id, submit_incomplete)
	if not bool(settlement.get("success", false)):
		return settlement
	if bool(settlement.get("already_settled", false)):
		return settlement
	var settlement_id := StringName(settlement.get("settlement_id", &"settlement.%s" % order_id))
	var mastery_results: Array[Dictionary] = []
	var items: Array = Array(order.get("items", []))
	var item_results: Array = Array(settlement.get("item_results", []))
	var all_grades := PackedStringArray()
	var base_coins := 0
	for item_index in range(item_results.size()):
		var item: Dictionary = Dictionary(items[item_index]) if item_index < items.size() else {}
		var item_result: Dictionary = Dictionary(item_results[item_index])
		var product: Dictionary = Dictionary(item_result.get("product", {}))
		var area_id := StringName(item.get("area_id", product.get("area_id", &"")))
		var grade := StringName(product.get("grade", &"A" if area_id == &"area.packaged_drink" else &"waste"))
		all_grades.append(str(grade))
		var mastery_payload := {
			"settlement_id": StringName("%s.item.%d" % [settlement_id, item_index]),
			"grade": grade,
			"correct_temperature": area_id == &"area.packaged_drink" and bool(item_result.get("success", false)),
		}
		mastery_results.append(Dictionary(_progression.call("record_area_result", area_id, mastery_payload)))
		if bool(settlement.get("order_success", false)):
			var product_definition := CATALOG.product_definition(StringName(item.get("product_id", &"")))
			base_coins += maxi(int(product_definition.get("base_sell_price", 0)), 0) * maxi(int(item.get("quantity", 1)), 1)
	# The playable-order generator owns an explicit whole-order quote, including
	# pancake prices and multi-item multipliers. Ad-hoc and restored orders that
	# have no explicit quote keep the catalog-price compatibility path above.
	if bool(settlement.get("order_success", false)):
		var order_metadata := Dictionary(order.get("metadata", {}))
		var legacy_order := Dictionary(order_metadata.get("legacy_order", {}))
		if order_metadata.has("base_coins"):
			base_coins = maxi(int(order_metadata.get("base_coins", base_coins)), 0)
		elif legacy_order.has("payment_coins"):
			base_coins = maxi(int(legacy_order.get("payment_coins", base_coins)), 0)
	var reputation_delta := _f3_reputation_delta(bool(settlement.get("order_success", false)), all_grades)
	_progression.set("reputation", maxi(int(_progression.get("reputation")) + reputation_delta, 0))
	var tutorial_identity := _tutorial_identity_for_order(order)
	var tutorial_kind := StringName(tutorial_identity.get("kind", &""))
	var tutorial_id := StringName(tutorial_identity.get("tutorial_id", &""))
	var tutorial_completion := {}
	var tutorial_failure := {}
	if bool(settlement.get("order_success", false)) and not tutorial_id.is_empty():
		tutorial_completion = _progression.call("complete_tutorial", tutorial_kind, tutorial_id)
	elif not bool(settlement.get("order_success", false)) and not tutorial_id.is_empty():
		tutorial_failure = _progression.call("record_tutorial_failure", tutorial_kind, tutorial_id)
	var today_orders: Array = Array(_save_data.get("today_orders", [])).duplicate(true)
	var primary_item: Dictionary = Dictionary(items[0]) if not items.is_empty() else {}
	today_orders.append({
		"order_id": str(order_id),
		"title": _formal_order_title(order),
		"area_id": str(primary_item.get("area_id", &"")),
		"score": 100 if bool(settlement.get("order_success", false)) else 0,
		"grade": "A" if bool(settlement.get("order_success", false)) else "C",
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
	_touch_and_write()
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
		"collected": base_coins <= 0,
		"created_at_unix": int(Time.get_unix_time_from_system()),
	}
	_save_data["pending_tray_payments"] = pending_payments
	settlement["reputation_delta"] = reputation_delta
	settlement["tutorial_completion"] = tutorial_completion
	settlement["tutorial_failure"] = tutorial_failure
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
			"grade": all_grades[0] if not all_grades.is_empty() else &"C",
			"complexity": order.get("complexity", &"single"),
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
	order_changed.emit({})
	order_settled.emit(settlement.duplicate(true))
	return settlement


func _finalize_failed_formal_order(result: Dictionary) -> void:
	_ensure_progression()
	var reputation_delta := int(result.get("reputation_delta", -2))
	_progression.set("reputation", maxi(int(_progression.get("reputation")) + reputation_delta, 0))
	var order := Dictionary(result.get("order", {}))
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
	_touch_and_write()
	result["tutorial_failure"] = tutorial_failure
	var terminal_state := StringName(result.get("terminal_state", result.get("reason", &"failed")))
	_record_business_event({
		"event_id": StringName("order.%s.%s" % [str(result.get("order_id", &"unknown")), str(terminal_state)]),
		"kind": &"refusal" if terminal_state == &"refused" else &"order_failure",
		"area_id": teaching_area_id if not teaching_area_id.is_empty() else _formal_order_area_id(order),
		"source_id": StringName(result.get("order_id", &"")),
		"quantity": 1,
		"reputation_delta": reputation_delta,
		"details": {"terminal_state": terminal_state},
	})
	_sync_business_services_to_save()
	_touch_and_write()
	progression_changed.emit(five_area_progression_snapshot())
	order_changed.emit({})
	order_settled.emit(result.duplicate(true))


func _formal_order_area_id(order: Dictionary) -> StringName:
	var items: Array = Array(order.get("items", []))
	return &"" if items.is_empty() else StringName(Dictionary(items[0]).get("area_id", &""))


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
	var unlocked := bool(_progression.call("owns_recipe", recipe_id))
	var slots := prepared_product_slots_snapshot()
	var products: Array = Array(slots.get(str(slot_id), []))
	return {
		"success": unlocked,
		"reason": &"" if unlocked else &"recipe_locked",
		"slot_id": slot_id,
		"product_id": StringName(definition.get("product_id", &"")),
		"recipe_id": recipe_id,
		"capacity": PREPARED_PRODUCT_SLOT_CAPACITY,
		"count": products.size(),
		"products": products.duplicate(true),
	}


func preview_store_ready_youtiao(slot_id: StringName) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_production_service()
	var status := prepared_product_slot_status(slot_id)
	if not bool(status.get("success", false)):
		return status
	if int(status.get("count", 0)) >= int(status.get("capacity", PREPARED_PRODUCT_SLOT_CAPACITY)):
		return {"success": false, "reason": &"prepared_product_slot_full", "slot_id": slot_id}
	var preview := Dictionary(_production_service.call("preview_collect_batch", &"device.youtiao_fryer", 1))
	if not bool(preview.get("success", false)):
		return preview
	var product := Dictionary(preview.get("product", {})).duplicate(true)
	if StringName(product.get("product_id", &"")) != StringName(status.get("product_id", &"")):
		return {"success": false, "reason": &"prepared_product_slot_mismatch", "slot_id": slot_id, "product": product}
	return {"success": true, "reason": &"", "slot_id": slot_id, "product": product}


func store_ready_youtiao_in_prepared_slot(slot_id: StringName) -> Dictionary:
	var preview := preview_store_ready_youtiao(slot_id)
	if not bool(preview.get("success", false)):
		return preview
	var production_rollback := five_area_production_snapshot()
	var collected := Dictionary(_production_service.call("collect_batch", &"device.youtiao_fryer", 1))
	if not bool(collected.get("success", false)):
		return collected
	var product := Dictionary(collected.get("product", {})).duplicate(true)
	var expected_product_id := StringName(Dictionary(preview.get("product", {})).get("product_id", &""))
	if StringName(product.get("product_id", &"")) != expected_product_id:
		_production_service.call("load_snapshot", production_rollback)
		return {"success": false, "reason": &"prepared_product_changed"}
	var stored := _append_prepared_product(slot_id, product)
	if not bool(stored.get("success", false)):
		_production_service.call("load_snapshot", production_rollback)
		return stored
	_sync_production_to_save()
	_touch_and_write()
	production_changed.emit(five_area_production_snapshot())
	prepared_product_slots_changed.emit(prepared_product_slots_snapshot())
	return {"success": true, "reason": &"", "slot_id": slot_id, "product": product, "count": stored.get("count", 0)}


func preview_take_prepared_product(slot_id: StringName) -> Dictionary:
	var status := prepared_product_slot_status(slot_id)
	if not bool(status.get("success", false)):
		return status
	var products: Array = Array(status.get("products", []))
	if products.is_empty():
		return {"success": false, "reason": &"prepared_product_slot_empty", "slot_id": slot_id}
	return {"success": true, "reason": &"", "slot_id": slot_id, "product": Dictionary(products[0]).duplicate(true)}


func take_prepared_product(slot_id: StringName) -> Dictionary:
	var preview := preview_take_prepared_product(slot_id)
	if not bool(preview.get("success", false)):
		return preview
	var slots := prepared_product_slots_snapshot()
	var products: Array = Array(slots.get(str(slot_id), [])).duplicate(true)
	var product := Dictionary(products.pop_front()).duplicate(true)
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
	if StringName(product.get("product_id", &"")) != StringName(status.get("product_id", &"")):
		return {"success": false, "reason": &"prepared_product_slot_mismatch", "slot_id": slot_id}
	var slots := prepared_product_slots_snapshot()
	var products: Array = Array(slots.get(str(slot_id), [])).duplicate(true)
	if products.size() >= PREPARED_PRODUCT_SLOT_CAPACITY:
		return {"success": false, "reason": &"prepared_product_slot_full", "slot_id": slot_id}
	products.append(product.duplicate(true))
	slots[str(slot_id)] = products
	_save_data["prepared_product_slots"] = _normalize_prepared_product_slots(slots)
	return {"success": true, "reason": &"", "slot_id": slot_id, "count": products.size()}


func inventory_snapshot() -> Dictionary:
	if not has_save():
		return _new_inventory_snapshot()
	return Dictionary(_save_data.get("inventory", {})).duplicate(true)


func five_area_restock_status(stock_id: StringName) -> Dictionary:
	_ensure_progression()
	var definition := CATALOG.stock_definition(stock_id)
	if definition.is_empty():
		return {"success": false, "reason": &"unknown_stock", "stock_id": stock_id}
	if StringName(definition.get("category", &"")) == &"prepared_add_on":
		return {"success": false, "reason": &"restock_unavailable", "stock_id": stock_id}
	if not _progression.call("owns_stock", stock_id):
		return {"success": false, "reason": &"stock_locked", "stock_id": stock_id}
	var inventory := inventory_snapshot()
	var key := str(stock_id)
	var capacity := maxi(int(definition.get("restock_capacity", 0)), 0)
	capacity = maxi(capacity, int(_progression.get("stock_capacity")))
	if capacity <= 0:
		return {"success": false, "reason": &"restock_unavailable", "stock_id": stock_id}
	var unit_seconds := maxf(float(definition.get("refill_seconds", 0.0)), 0.001)
	return {
		"success": true,
		"reason": &"",
		"stock_id": stock_id,
		"area_id": StringName(definition.get("area_id", &"")),
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
		_touch_and_write()
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


func growth_recommendations(limit_total: int = 3) -> Dictionary:
	_ensure_progression()
	return Dictionary(_progression.call("growth_recommendations", limit_total)).duplicate(true)


func growth_purchase_status(growth_id: StringName) -> Dictionary:
	_ensure_progression()
	return Dictionary(_progression.call("purchase_status", growth_id)).duplicate(true)


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
			return "声誉 %d/%d" % [int(requirement.get("current_reputation", 0)), int(requirement.get("min_reputation", 0))]
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
			return "已解锁区域 %d/%d" % [int(requirement.get("current_area_count", 0)), int(requirement.get("required_area_count", 5))]
		&"unknown_growth":
			return "成长配置"
	return str(requirement.get("reason", &"条件"))


static func _area_status_label(area_id: StringName) -> String:
	return {
		&"area.pancake": "煎饼",
		&"area.packaged_drink": "成品饮品",
		&"area.youtiao": "油条",
		&"area.fresh_soy_milk": "现磨豆浆",
		&"area.steamer": "蒸笼",
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
	return result


func abandon_formal_order(order_id: StringName, reason: StringName = &"refused") -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_order_service()
	var result: Dictionary = _order_service.call("abandon_order", order_id, reason)
	if bool(result.get("success", false)):
		_sync_formal_orders_to_save()
		_touch_and_write()
	return result


func end_business_day(cutoff: Dictionary = {}) -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_progression()
	_ensure_order_service()
	var day_was_open := bool(_progression.get("day_open"))
	var normalized_cutoff := cutoff.duplicate(true)
	var cutoff_reason := StringName(normalized_cutoff.get("reason", &"manual_early_end"))
	if cutoff_reason.is_empty():
		cutoff_reason = &"manual_early_end"
	var open_order_count := Array(_order_service.call("queue_snapshot")).size()
	var abandoned := {"success": true}
	if open_order_count > 0:
		abandoned = Dictionary(_order_service.call("abandon_all_open_orders", cutoff_reason))
	_sync_formal_orders_to_save()
	if not day_was_open:
		# Repeated/direct calls still enforce an empty queue, but must not rewrite
		# the original cutoff reason or close the report and production state twice.
		_touch_and_write()
		var already_closed_bill := today_bill()
		already_closed_bill["success"] = true
		return already_closed_bill
	normalized_cutoff["reason"] = cutoff_reason
	normalized_cutoff["unserved_customer_count"] = open_order_count
	normalized_cutoff["formal_order_abandoned"] = open_order_count > 0 and bool(abandoned.get("success", false))
	_save_data["day_open"] = false
	_progression.call("set_day_open", false)
	if bool(_save_data.get(PACKAGED_DRINK_SPLIT_PENDING_KEY, false)):
		_sync_progression_to_save()
		_sync_production_to_save()
		_apply_packaged_drink_split_migration_to_save()
		_progression = PROGRESSION_SERVICE.new(Dictionary(_save_data.get("progression", {})))
		_production_service = FIVE_AREA_PRODUCTION_SERVICE.new(self, Dictionary(_save_data.get("production", {})))
		_configure_service_connections()
	_save_data["today_cutoff"] = normalized_cutoff
	_save_data["business_day_remaining_seconds"] = 0.0
	_ensure_pancake_holding_tray()
	var tray_waste: Array = _pancake_holding_tray.call("clear_for_day_end")
	for waste_index in range(tray_waste.size()):
		var waste := Dictionary(tray_waste[waste_index])
		_record_business_event({
			"event_id": _next_ledger_event_id(&"tray_day_end"),
			"kind": &"waste",
			"area_id": &"area.pancake",
			"source_id": &"pancake_holding_tray",
			"quantity": 1,
			"details": {"reason": &"day_end", "attributed_cost": int(waste.get("material_cost", 0))},
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
	_sync_progression_to_save()
	var bill := today_bill()
	bill["tray_waste"] = tray_waste
	bill["prepared_product_slot_waste"] = prepared_slot_waste
	bill["success"] = true
	_ensure_business_services()
	var ledger_bill: Dictionary = _business_report_service.call("close_day")
	for key in ledger_bill:
		bill[key] = ledger_bill[key]
	_save_data["last_bill"] = bill.duplicate(true)
	_sync_business_services_to_save()
	_touch_and_write()
	return bill


func begin_next_business_day() -> Dictionary:
	if not has_save():
		return {"success": false, "reason": &"no_active_save"}
	_ensure_progression()
	var result: Dictionary = _progression.call("begin_next_business_day")
	if not bool(result.get("success", false)):
		return result
	if Array(result.get("activated_growth_ids", [])).has(&"growth.equipment.packaged_drink.basic") or Array(result.get("activated_growth_ids", [])).has("growth.equipment.packaged_drink.basic"):
		var suspended_tier := int(_save_data.get(PACKAGED_DRINK_SUSPENDED_TIER_KEY, -1))
		if suspended_tier >= 0:
			var restored_tiers := Dictionary(_progression.get("device_tiers")).duplicate(true)
			restored_tiers[&"device.packaged_drink_heater"] = maxi(suspended_tier, 0)
			_progression.set("device_tiers", restored_tiers)
			_save_data[PACKAGED_DRINK_SUSPENDED_TIER_KEY] = -1
			result["restored_packaged_drink_heater_tier"] = suspended_tier
	_save_data["day_open"] = true
	_save_data["business_day_remaining_seconds"] = BUSINESS_DAY_DURATION_SECONDS
	_save_data["today_orders"] = []
	_save_data["today_reputation_delta"] = 0
	_save_data["today_cutoff"] = {}
	_save_data["business_paused"] = false
	_save_data["pancake_orders_issued_today"] = 0
	_progression.call("advance_tutorial_for_new_business_day")
	_replenish_daily_pancake_consumables()
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
	inventory_changed.emit(inventory_snapshot())
	progression_changed.emit(five_area_progression_snapshot())
	daily_goal_changed.emit(current_daily_goal())
	return result


func _replenish_daily_pancake_consumables() -> void:
	var inventory := inventory_snapshot()
	for stock_id in DAILY_PANCAKE_CONSUMABLE_STOCK:
		if not bool(_progression.call("owns_stock", stock_id)):
			continue
		var key := str(stock_id)
		inventory[key] = maxi(int(inventory.get(key, 0)), int(DAILY_PANCAKE_CONSUMABLE_STOCK[stock_id]))
	_save_data["inventory"] = _normalize_inventory(inventory)


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
	# Tutorial completion is about finishing the guided interaction path.  Its
	# score still enters mastery/billing, but it is not a pass/fail gate.
	var formal_teaching_area_id: StringName = &""
	if not formal_order_id.is_empty():
		var formal_orders := Dictionary(formal_order_snapshot().get("orders", {}))
		var formal_order := Dictionary(formal_orders.get(formal_order_id, formal_orders.get(str(formal_order_id), {})))
		formal_teaching_area_id = StringName(formal_order.get("teaching_area_id", Dictionary(formal_order.get("metadata", {})).get("teaching_area_id", &"")))
	if not formal_teaching_area_id.is_empty():
		tutorial_completion = _progression.call("complete_tutorial", &"area", formal_teaching_area_id)
	elif bool(order.get("tutorial_no_countdown", false)):
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
	return bill


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
	var save_text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(save_text)
	if parsed is Dictionary and int(parsed.get("version", 0)) == SAVE_VERSION and str(parsed.get("save_kind", "")) == SAVE_KIND:
		_save_data = parsed.duplicate(true)
		_ensure_save_shape()
		return
	# Development saves are deliberately incompatible with the five-area model.
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
	_save_data["inventory"] = _normalize_inventory(Dictionary(_save_data.get("inventory", {})))
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
	if not _save_data.has("order_sequence"):
		_save_data["order_sequence"] = maxi(int(Dictionary(_save_data.get("formal_orders", {})).get("sequence", 0)), 0)
	if not _save_data.has("tutorial_order_generated_day"):
		_save_data["tutorial_order_generated_day"] = 0
	if not _save_data.has(ORDER_PROMOTIONS_KEY):
		_save_data[ORDER_PROMOTIONS_KEY] = []
	if not _save_data.has(RECONCILED_FORMAL_ORDER_IDS_KEY):
		_save_data[RECONCILED_FORMAL_ORDER_IDS_KEY] = []
	_prepare_packaged_drink_split_migration()


func _prepare_packaged_drink_split_migration() -> void:
	if int(_save_data.get(PACKAGED_DRINK_SPLIT_MIGRATION_KEY, 0)) >= PACKAGED_DRINK_SPLIT_MIGRATION_VERSION:
		return
	var progression := Dictionary(_save_data.get("progression", {}))
	var unlocked_areas := PackedStringArray(Array(progression.get("unlocked_area_ids", [])))
	var device_tiers := Dictionary(progression.get("device_tiers", {}))
	var owned_growth_ids := PackedStringArray(Array(progression.get("owned_growth_ids", [])))
	var owns_packaged_drink := unlocked_areas.has("area.packaged_drink")
	var owns_legacy_heater := device_tiers.has("device.packaged_drink_heater") or device_tiers.has(&"device.packaged_drink_heater")
	var already_split := owned_growth_ids.has("growth.equipment.packaged_drink.basic")
	if not owns_packaged_drink or not owns_legacy_heater or already_split:
		_save_data[PACKAGED_DRINK_SPLIT_MIGRATION_KEY] = PACKAGED_DRINK_SPLIT_MIGRATION_VERSION
		_save_data[PACKAGED_DRINK_SPLIT_PENDING_KEY] = false
		if not _save_data.has(PACKAGED_DRINK_SUSPENDED_TIER_KEY):
			_save_data[PACKAGED_DRINK_SUSPENDED_TIER_KEY] = -1
		return
	if bool(_save_data.get("day_open", true)):
		_save_data[PACKAGED_DRINK_SPLIT_PENDING_KEY] = true
		_save_data[PACKAGED_DRINK_SUSPENDED_TIER_KEY] = -1
		return
	_apply_packaged_drink_split_migration_to_save()


func _apply_packaged_drink_split_migration_to_save() -> void:
	var progression := Dictionary(_save_data.get("progression", {})).duplicate(true)
	var device_tiers := Dictionary(progression.get("device_tiers", {})).duplicate(true)
	var suspended_tier := int(device_tiers.get("device.packaged_drink_heater", device_tiers.get(&"device.packaged_drink_heater", 0)))
	device_tiers.erase("device.packaged_drink_heater")
	device_tiers.erase(&"device.packaged_drink_heater")
	progression["device_tiers"] = device_tiers
	var tutorial := Dictionary(progression.get("tutorial", {})).duplicate(true)
	var completed_devices := PackedStringArray(Array(tutorial.get("completed_device_ids", [])))
	if completed_devices.has("device.packaged_drink_heater"):
		completed_devices.remove_at(completed_devices.find("device.packaged_drink_heater"))
	tutorial["completed_device_ids"] = completed_devices
	var queued_devices := PackedStringArray(Array(tutorial.get("queue_device_ids", [])))
	if queued_devices.has("device.packaged_drink_heater"):
		queued_devices.remove_at(queued_devices.find("device.packaged_drink_heater"))
	tutorial["queue_device_ids"] = queued_devices
	if StringName(tutorial.get("active_kind", &"")) == &"device" and StringName(tutorial.get("active_id", &"")) == &"device.packaged_drink_heater":
		tutorial["active_kind"] = &""
		tutorial["active_id"] = &""
	progression["tutorial"] = tutorial
	_save_data["progression"] = progression

	var inventory := Dictionary(_save_data.get("inventory", {})).duplicate(true)
	var production := Dictionary(_save_data.get("production", {})).duplicate(true)
	var heater := Dictionary(production.get("packaged_drink_heater", {}))
	for slot_value in Array(heater.get("slots", [])):
		var slot := Dictionary(slot_value)
		if StringName(slot.get("state", &"locked")) in [&"locked", &"empty"]:
			continue
		var product := CATALOG.product_definition(StringName(slot.get("product_id", &"")))
		var stock_id := StringName(product.get("stock_id", &""))
		if not stock_id.is_empty():
			var key := str(stock_id)
			inventory[key] = maxi(int(inventory.get(key, 0)), 0) + 1
	production["packaged_drink_heater"] = PACKAGED_DRINK_HEATER_MODEL.new().snapshot()
	_save_data["inventory"] = inventory
	_save_data["production"] = production
	_save_data[PACKAGED_DRINK_SUSPENDED_TIER_KEY] = maxi(suspended_tier, 0)
	_save_data[PACKAGED_DRINK_SPLIT_PENDING_KEY] = false
	_save_data[PACKAGED_DRINK_SPLIT_MIGRATION_KEY] = PACKAGED_DRINK_SPLIT_MIGRATION_VERSION


static func _empty_prepared_product_slots() -> Dictionary:
	return {
		"slot.04": [],
		"slot.05": [],
		"slot.06": [],
	}


static func _prepared_slot_id_for_product(product_id: StringName) -> StringName:
	for slot_id in PREPARED_PRODUCT_SLOT_DEFINITIONS:
		if StringName(Dictionary(PREPARED_PRODUCT_SLOT_DEFINITIONS[slot_id]).get("product_id", &"")) == product_id:
			return StringName(slot_id)
	return &""


static func _normalize_prepared_product_slots(value: Dictionary) -> Dictionary:
	var normalized := _empty_prepared_product_slots()
	for slot_id in PREPARED_PRODUCT_SLOT_DEFINITIONS:
		var products: Array = []
		for product_variant in Array(value.get(str(slot_id), value.get(slot_id, []))):
			var product := Dictionary(product_variant).duplicate(true)
			if product.is_empty() or StringName(product.get("product_id", &"")) != StringName(Dictionary(PREPARED_PRODUCT_SLOT_DEFINITIONS[slot_id]).get("product_id", &"")):
				continue
			products.append(product)
			if products.size() >= PREPARED_PRODUCT_SLOT_CAPACITY:
				break
		normalized[str(slot_id)] = products
	return normalized


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
