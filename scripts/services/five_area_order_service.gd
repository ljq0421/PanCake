class_name FiveAreaOrderService
extends RefCounted

signal queue_changed(snapshot: Array[Dictionary])
signal order_settled(result: Dictionary)

const SPECIALS := preload("res://scripts/data/special_customer_catalog.gd")

## Formal order state is UI-independent.  Stage 7 will replace only candidate
## generation/tutorial selection, not the persisted order transaction.

## Pancake production currently supports sweet-flour and red-chili sauce.  The
## formal contract nevertheless owns the upper bound so a malformed order can
## never introduce a third sauce when more sauce content is added later.
const MAX_SAUCE_TYPES_PER_ITEM := 2
const MAX_PORTIONS_PER_REQUIREMENT := 2
## The storefront has five physical service positions.  Orders are created
## only as a customer walks in, so there is no hidden waiting queue.
const MAX_OPEN_ORDERS := 5
const MAX_ACTIVE_CUSTOMERS := 5
const CUSTOMER_IDS: Array[StringName] = [
	&"customer_01",
	&"customer_02",
	&"customer_03",
	&"customer_04",
	&"customer_05",
	&"customer_06",
	&"customer_07",
	&"customer_08",
	&"customer_09",
	&"customer_10",
	&"customer_11",
	&"customer_12",
	&"customer_13",
	&"customer_14",
	&"customer_15",
	&"customer_16",
	&"customer_17",
	&"customer_18",
	&"customer_19",
	&"customer_20",
]
const LEGACY_CUSTOMER_COUNT_BEFORE_POOL_EXPANSION := 10

var _orders: Dictionary = {}
var _active_order_ids: Array[StringName] = []
var _queue_order_ids: Array[StringName] = []
var _sequence: int = 0
var _settled_order_ids: Dictionary = {}
var _terminal_results: Dictionary = {}


func _init(initial_snapshot: Dictionary = {}) -> void:
	_restore(initial_snapshot)


func open_pancake_order(template: Dictionary) -> Dictionary:
	return open_order([{
		"area_id": &"area.pancake",
		"product_id": &"product.pancake.custom",
		"quantity": 1,
		"temperature_mode": &"normal",
		"pancake_template_id": StringName(template.get("id", &"")),
		"ingredient_ids": Array(template.get("ingredient_ids", [])),
		"sauce_ids": Array(template.get("sauce_ids", [])),
		"heat_preference": StringName(template.get("heat_preference", &"")),
	}], {"legacy_order": template.duplicate(true)})


## Items are stable data records: area/product/quantity plus product-specific
## matching attributes.  A route attaches a produced instance to one item.
func open_order(items: Array, metadata: Dictionary = {}) -> Dictionary:
	if _queue_order_ids.size() >= MAX_OPEN_ORDERS:
		return {"success": false, "reason": &"queue_full"}
	if items.is_empty():
		return {"success": false, "reason": &"missing_order_items"}
	_sequence += 1
	var order_id: StringName = StringName("runtime.order.%06d" % _sequence)
	var normalized_items: Array = []
	for source_item in items:
		var item: Dictionary = Dictionary(source_item).duplicate(true)
		if StringName(item.get("area_id", &"")).is_empty() or StringName(item.get("product_id", &"")).is_empty():
			return {"success": false, "reason": &"invalid_order_item"}
		var ingredient_ids := _normalized_ids(item.get("ingredient_ids", []))
		var ingredient_overage := _first_over_portioned_id(ingredient_ids)
		if not ingredient_overage.is_empty():
			return {
				"success": false,
				"reason": &"too_many_ingredient_portions",
				"ingredient_id": ingredient_overage,
				"max_portions": MAX_PORTIONS_PER_REQUIREMENT,
			}
		var sauce_ids := _normalized_ids(item.get("sauce_ids", []))
		var sauce_overage := _first_over_portioned_id(sauce_ids)
		if not sauce_overage.is_empty():
			return {
				"success": false,
				"reason": &"too_many_sauce_portions",
				"sauce_id": sauce_overage,
				"max_portions": MAX_PORTIONS_PER_REQUIREMENT,
			}
		if _unique_id_count(sauce_ids) > MAX_SAUCE_TYPES_PER_ITEM:
			return {
				"success": false,
				"reason": &"too_many_sauce_requirements",
				"max_sauce_requirements": MAX_SAUCE_TYPES_PER_ITEM,
				"requested_sauce_count": _unique_id_count(sauce_ids),
			}
		item["quantity"] = maxi(int(item.get("quantity", 1)), 1)
		var normalized_temperature := normalized_temperature_mode(item.get("temperature_mode", &"room_temperature"))
		if normalized_temperature.is_empty():
			return {"success": false, "reason": &"invalid_temperature_mode", "value": item.get("temperature_mode")}
		item["temperature_mode"] = normalized_temperature
		item["ingredient_ids"] = ingredient_ids
		item["sauce_ids"] = sauce_ids
		item["prepared_product_instance_ids"] = PackedStringArray()
		item["attached_products"] = []
		normalized_items.append(item)
	var tutorial_no_countdown := _metadata_has_no_countdown(metadata)
	var initial_state := &"active" if _can_activate_new_order(tutorial_no_countdown) else &"waiting"
	var complexity := &"single"
	if normalized_items.size() == 2:
		complexity = &"double"
	elif normalized_items.size() >= 3:
		complexity = &"triple"
	var requested_customer_id := StringName(metadata.get("customer_id", &""))
	var customer_id := customer_id_for_sequence(_sequence)
	if SPECIALS.is_special_id(StringName(metadata.get("special_customer_id", &""))) and not requested_customer_id.is_empty():
		customer_id = requested_customer_id
	var order: Dictionary = {
		"order_id": order_id,
		"sequence": _sequence,
		"complexity": complexity,
		"state": initial_state,
		"status": initial_state,
		"service_slot": -1,
		"customer_id": customer_id,
		"special_customer_id": StringName(metadata.get("special_customer_id", &"")),
		"special_title": str(metadata.get("special_title", "")),
		"special_rule_text": str(metadata.get("special_rule_text", "")),
		"customer_line": str(metadata.get("customer_line", "")),
		"perfect_quote_coins": maxi(int(metadata.get("perfect_quote_coins", metadata.get("base_coins", 1))), 0),
		"items": normalized_items,
		"patience_seconds": maxf(float(metadata.get("patience_seconds", 0.0)), 0.0),
		"remaining_patience_seconds": maxf(float(metadata.get("patience_seconds", 0.0)), 0.0),
		"teaching_area_id": StringName(metadata.get("teaching_area_id", &"")),
		"tutorial_kind": StringName(metadata.get("tutorial_kind", &"")),
		"tutorial_id": StringName(metadata.get("tutorial_id", &"")),
		"tutorial_no_countdown": tutorial_no_countdown,
		"base_coins": maxi(int(metadata.get("base_coins", 1)), 1),
		"reward_multiplier": float(metadata.get("reward_multiplier", 1.0)),
		"production_started": false,
		"production_source_ids": PackedStringArray(),
		"metadata": metadata.duplicate(true),
	}
	_orders[order_id] = order
	_queue_order_ids.append(order_id)
	if initial_state == &"active":
		_activate_order_in_slot(order_id, _first_free_service_slot())
	queue_changed.emit(queue_snapshot())
	return {"success": true, "order": Dictionary(_orders[order_id]).duplicate(true)}


func active_order() -> Dictionary:
	var orders := active_orders()
	return {} if orders.is_empty() else orders.front()


func active_orders() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for order_id in _active_order_ids:
		if _orders.has(order_id):
			result.append(Dictionary(_orders[order_id]).duplicate(true))
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left.get("service_slot", 99)) < int(right.get("service_slot", 99)))
	return result


func order_by_id(order_id: StringName) -> Dictionary:
	return Dictionary(_orders.get(order_id, {})).duplicate(true)


func current_order() -> Dictionary:
	return active_order()


func waiting_orders() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for order_id in _queue_order_ids:
		if _active_order_ids.has(order_id) or not _orders.has(order_id):
			continue
		var order := Dictionary(_orders[order_id])
		if StringName(order.get("state", &"")) == &"waiting":
			result.append(order.duplicate(true))
	return result


func ensure_queue(target_size: int = 4, generated_candidates: Variant = {}) -> Dictionary:
	var requested_size := clampi(target_size, 1, MAX_OPEN_ORDERS)
	var candidates: Array = Array(generated_candidates) if generated_candidates is Array else ([generated_candidates] if generated_candidates is Dictionary and not Dictionary(generated_candidates).is_empty() else [])
	var created_orders: Array[Dictionary] = []
	for raw_candidate in candidates:
		if _queue_order_ids.size() >= requested_size:
			break
		var candidate := Dictionary(raw_candidate)
		var opened := open_order(Array(candidate.get("items", [])), Dictionary(candidate.get("metadata", {})))
		if not bool(opened.get("success", false)):
			return opened
		created_orders.append(Dictionary(opened.get("order", {})).duplicate(true))
	if _queue_order_ids.is_empty() and candidates.is_empty():
		return {"success": false, "reason": &"missing_generated_candidate"}
	return {
		"success": true,
		"created": not created_orders.is_empty(),
		"created_orders": created_orders,
		"order": active_order(),
		"queue": queue_snapshot(),
		"needs_candidates": maxi(requested_size - _queue_order_ids.size(), 0),
	}


func queue_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for order_id in _queue_order_ids:
		if _orders.has(order_id):
			result.append(Dictionary(_orders[order_id]).duplicate(true))
	return result


func activate_order(order_id: StringName) -> Dictionary:
	if not _orders.has(order_id) or not _queue_order_ids.has(order_id):
		return {"success": false, "reason": &"order_not_waiting"}
	var order := Dictionary(_orders[order_id])
	if StringName(order.get("state", &"")) != &"waiting":
		return {"success": false, "reason": &"order_not_waiting"}
	if not _can_activate_new_order(bool(order.get("tutorial_no_countdown", false))):
		return {"success": false, "reason": &"active_capacity_full"}
	_activate_order_in_slot(order_id, _first_free_service_slot())
	queue_changed.emit(queue_snapshot())
	return {"success": true, "order": Dictionary(_orders[order_id]).duplicate(true)}


func snapshot() -> Dictionary:
	return {
		"version": 7,
		"sequence": _sequence,
		"active_order_id": str(_active_order_ids.front()) if not _active_order_ids.is_empty() else "",
		"active_order_ids": PackedStringArray(_active_order_ids.map(func(value): return str(value))),
		"queue_order_ids": PackedStringArray(_queue_order_ids.map(func(value): return str(value))),
		"orders": _orders.duplicate(true),
		"settled_order_ids": _settled_order_ids.keys(),
		"terminal_results": _terminal_results.duplicate(true),
	}


func load_snapshot(source: Dictionary) -> Dictionary:
	_restore(source)
	return {"success": true, "snapshot": snapshot()}


func advance_patience(delta: float) -> Dictionary:
	var changed_order_ids := PackedStringArray()
	var expired_results: Array[Dictionary] = []
	if delta > 0.0:
		for order_id in _active_order_ids.duplicate():
			if not _orders.has(order_id):
				continue
			var order: Dictionary = _orders[order_id]
			if StringName(order.get("state", &"")) == &"serving" or bool(order.get("tutorial_no_countdown", false)):
				continue
			var remaining := maxf(float(order.get("remaining_patience_seconds", order.get("patience_seconds", 0.0))) - delta, 0.0)
			# Keep the authoritative timer at full precision. Presentation code may
			# round whole seconds, but feeding a rounded value back into the next
			# frame makes small deltas stall and produces visible bar jumps.
			order["remaining_patience_seconds"] = remaining
			_orders[order_id] = order
			changed_order_ids.append(str(order_id))
			if remaining <= 0.0:
				expired_results.append(_finish_failure(order_id, &"expired", &"patience_expired", -2))
	return {
		"success": true,
		"changed": not changed_order_ids.is_empty(),
		"changed_order_ids": changed_order_ids,
		"expired_results": expired_results,
		"active_orders": active_orders(),
	}


func advance_time(delta: float) -> Array[Dictionary]:
	var result := advance_patience(delta)
	return Array(result.get("expired_results", []))


func preview_refusal(order_id: StringName) -> Dictionary:
	if not _is_active_order(order_id) or StringName(Dictionary(_orders[order_id]).get("state", &"")) == &"serving":
		return {"success": false, "reason": &"order_not_active"}
	var order: Dictionary = _orders[order_id]
	var reputation_delta := -2 if bool(order.get("production_started", false)) else -1
	return {
		"success": true,
		"order_id": order_id,
		"production_started": bool(order.get("production_started", false)),
		"reputation_delta": reputation_delta,
	}


func refuse_order(order_id: StringName) -> Dictionary:
	if _terminal_results.has(order_id):
		var previous: Dictionary = Dictionary(_terminal_results[order_id]).duplicate(true)
		previous["already_settled"] = true
		return previous
	var preview := preview_refusal(order_id)
	if not bool(preview.get("success", false)):
		return preview
	return _finish_failure(order_id, &"refused", &"stock_refusal", int(preview.get("reputation_delta", -1)))


func preview_attach_product(order_id: StringName, item_index: int, product: Dictionary) -> Dictionary:
	var item := _active_item(order_id, item_index)
	if item.is_empty():
		return {"success": false, "reason": &"order_not_active"}
	if Array(item.get("prepared_product_instance_ids", [])).size() >= int(item.get("quantity", 1)):
		return {"success": false, "reason": &"capacity_full"}
	var reasons := _product_mismatch_reasons(item, product)
	return {"success": true, "will_match": reasons.is_empty(), "mismatch_reasons": reasons}


func attach_product(order_id: StringName, item_index: int, product: Dictionary) -> Dictionary:
	var preview := preview_attach_product(order_id, item_index, product)
	if not bool(preview.get("success", false)):
		return preview
	# A manually produced wrong product still has to reach settlement so the
	# player receives the intended low-score/order-mismatch result.  Tray UI
	# performs a stricter preview before removing a stored product.
	var order: Dictionary = _orders[order_id]
	var items: Array = Array(order.get("items", [])).duplicate(true)
	var item: Dictionary = items[item_index]
	var ids: PackedStringArray = item.get("prepared_product_instance_ids", PackedStringArray())
	ids.append(str(product.get("product_instance_id", "")))
	item["prepared_product_instance_ids"] = ids
	item["attached_quantity"] = ids.size()
	var reserved_product := product.duplicate(true)
	reserved_product["status"] = &"reserved"
	reserved_product["owner_order_id"] = order_id
	var attached_products := _item_products(item)
	attached_products.append(reserved_product)
	item["attached_products"] = attached_products
	# Keep the legacy field readable while older UI and report paths are retired.
	item["attached_product"] = reserved_product
	items[item_index] = item
	order["items"] = items
	_orders[order_id] = order
	return {"success": true, "will_match": preview.get("will_match", false), "mismatch_reasons": preview.get("mismatch_reasons", PackedStringArray())}


func preview_order_match(order_id: StringName) -> Dictionary:
	if not _is_active_order(order_id):
		return {"success": false, "reason": &"order_not_active"}
	var order: Dictionary = _orders[order_id]
	var all_reasons := PackedStringArray()
	for item_value in Array(order.get("items", [])):
		var item := Dictionary(item_value)
		var products := _item_products(item)
		var required := maxi(int(item.get("quantity", 1)), 1)
		if products.size() < required:
			all_reasons.append("missing_order_item")
		for product_value in products:
			all_reasons.append_array(_product_mismatch_reasons(item, Dictionary(product_value)))
	return {
		"success": true,
		"will_match": all_reasons.is_empty(),
		"mismatch_reasons": all_reasons,
	}


func remove_attached_product(order_id: StringName, item_index: int, product_instance_id: StringName = &"") -> Dictionary:
	var item := _active_item(order_id, item_index)
	if item.is_empty():
		return {"success": false, "reason": &"order_not_active"}
	var products := _item_products(item)
	if products.is_empty():
		return {"success": false, "reason": &"tray_slot_empty"}
	var remove_index := products.size() - 1
	if not product_instance_id.is_empty():
		remove_index = -1
		for index in range(products.size()):
			if StringName(products[index].get("product_instance_id", &"")) == product_instance_id:
				remove_index = index
				break
		if remove_index < 0:
			return {"success": false, "reason": &"staged_product_not_found"}
	var removed: Dictionary = products[remove_index].duplicate(true)
	products.remove_at(remove_index)
	var order: Dictionary = _orders[order_id]
	var items: Array = Array(order.get("items", [])).duplicate(true)
	item = Dictionary(items[item_index]).duplicate(true)
	item["attached_products"] = products
	var ids := PackedStringArray()
	for staged_product in products:
		ids.append(str(staged_product.get("product_instance_id", "")))
	item["prepared_product_instance_ids"] = ids
	item["attached_quantity"] = ids.size()
	if products.is_empty():
		item.erase("attached_product")
	else:
		item["attached_product"] = products.back().duplicate(true)
	items[item_index] = item
	order["items"] = items
	_orders[order_id] = order
	removed["status"] = &"removed_from_tray"
	removed.erase("owner_order_id")
	return {"success": true, "product": removed, "remaining_quantity": products.size()}


func best_delivery_item_index(order_id: StringName, product: Dictionary) -> int:
	if not _is_active_order(order_id):
		return -1
	var fallback_index := -1
	var items: Array = Array(Dictionary(_orders[order_id]).get("items", []))
	for item_index in range(items.size()):
		var item := Dictionary(items[item_index])
		var attached_count := Array(item.get("prepared_product_instance_ids", [])).size()
		if attached_count >= int(item.get("quantity", 1)):
			continue
		if fallback_index < 0:
			fallback_index = item_index
		if _product_mismatch_reasons(item, product).is_empty():
			return item_index
	return fallback_index


func mark_production_started(order_id: StringName, source_instance_id: StringName) -> Dictionary:
	if not _is_active_order(order_id):
		return {"success": false, "reason": &"order_not_active"}
	var order: Dictionary = _orders[order_id]
	var sources: PackedStringArray = order.get("production_source_ids", PackedStringArray())
	if not source_instance_id.is_empty() and not sources.has(str(source_instance_id)):
		sources.append(str(source_instance_id))
	order["production_started"] = true
	order["production_source_ids"] = sources
	_orders[order_id] = order
	return {"success": true, "changed": true, "order_id": order_id, "production_source_ids": sources}


func settle_order(order_id: StringName, submit_incomplete: bool = false) -> Dictionary:
	if _settled_order_ids.has(order_id):
		# Settlement may be retried after the order state has already been
		# persisted.  It must not create a second settlement, but callers also
		# must not be left in a completed-payment screen with no way forward.
		return {"success": true, "already_settled": true, "settlement_id": StringName("settlement.%s" % order_id)}
	var order: Dictionary = _orders.get(order_id, {})
	if order.is_empty() or not _is_active_order(order_id):
		return {"success": false, "reason": &"order_not_active"}
	var item_results: Array = []
	var all_reasons := PackedStringArray()
	for item_value in Array(order.get("items", [])):
		var item: Dictionary = Dictionary(item_value)
		var attached: Array = Array(item.get("prepared_product_instance_ids", []))
		if attached.size() < int(item.get("quantity", 1)) and not submit_incomplete:
			return {"success": false, "reason": &"missing_order_item"}
		var products := _item_products(item)
		var reasons := PackedStringArray(["missing_order_item"]) if products.is_empty() else PackedStringArray()
		for product in products:
			reasons.append_array(_product_mismatch_reasons(item, product))
		if attached.size() < int(item.get("quantity", 1)):
			reasons.append("incomplete_quantity")
		all_reasons.append_array(reasons)
		item_results.append({
			"product_id": item.get("product_id", &""),
			"requested_sugar_servings": int(item.get("sugar_servings", 0)),
			"requested_temperature_mode": item.get("temperature_mode", &"room_temperature"),
			"success": reasons.is_empty(),
			"mismatch_reasons": reasons,
			"product": products.front().duplicate(true) if not products.is_empty() else {},
			"products": products,
		})
	var success := all_reasons.is_empty()
	for item_index in range(item_results.size()):
		var result_entry: Dictionary = item_results[item_index]
		var finalized_products: Array = []
		for product_value in Array(result_entry.get("products", [])):
			var finalized_product := Dictionary(product_value).duplicate(true)
			finalized_product["status"] = &"consumed" if success else &"wasted"
			finalized_products.append(finalized_product)
		if not finalized_products.is_empty():
			result_entry["product"] = Dictionary(finalized_products.front()).duplicate(true)
			result_entry["products"] = finalized_products
			item_results[item_index] = result_entry
			var stored_item: Dictionary = Array(order.get("items", []))[item_index]
			stored_item["attached_product"] = Dictionary(finalized_products.back()).duplicate(true)
			stored_item["attached_products"] = finalized_products
			var stored_items: Array = Array(order.get("items", [])).duplicate(true)
			stored_items[item_index] = stored_item
			order["items"] = stored_items
	var settlement_id := StringName("settlement.%s" % order_id)
	_settled_order_ids[order_id] = true
	order["state"] = &"settled"
	order["status"] = &"completed" if success else &"failed"
	_orders[order_id] = order
	var result := {"success": true, "settlement_id": settlement_id, "order_id": order_id, "order_success": success, "mismatch_reasons": all_reasons, "item_results": item_results, "terminal_state": &"completed" if success else &"failed"}
	_terminal_results[order_id] = result.duplicate(true)
	var departing_customer_id := StringName(order.get("customer_id", &""))
	var departing_tutorial := bool(order.get("tutorial_no_countdown", false))
	_remove_from_queue(order_id)
	_fill_active_slots(departing_customer_id if departing_tutorial else &"")
	queue_changed.emit(queue_snapshot())
	order_settled.emit(result.duplicate(true))
	return result


func abandon_active_order(reason: StringName = &"business_day_expired") -> Dictionary:
	var current := active_order()
	if current.is_empty():
		return {"success": false, "reason": &"order_not_active"}
	return abandon_order(StringName(current.get("order_id", &"")), reason)


func abandon_order(order_id: StringName, reason: StringName = &"business_day_expired") -> Dictionary:
	if not _is_active_order(order_id):
		return {"success": false, "reason": &"order_not_active"}
	var order: Dictionary = _orders[order_id]
	order["state"] = &"abandoned"
	order["status"] = &"expired" if reason == &"business_day_expired" else &"failed"
	order["abandon_reason"] = reason
	_orders[order_id] = order
	_remove_from_queue(order_id)
	var abandoned_waiting := PackedStringArray()
	if reason == &"business_day_expired":
		for waiting_id in _queue_order_ids.duplicate():
			var waiting := Dictionary(_orders.get(waiting_id, {}))
			waiting["state"] = &"abandoned"
			waiting["status"] = &"expired"
			waiting["abandon_reason"] = reason
			_orders[waiting_id] = waiting
			abandoned_waiting.append(str(waiting_id))
		_active_order_ids.clear()
		_queue_order_ids.clear()
	else:
		_fill_active_slots()
	queue_changed.emit(queue_snapshot())
	return {"success": true, "order_id": order_id, "abandoned_waiting_order_ids": abandoned_waiting, "reason": reason}


func abandon_all_open_orders(reason: StringName = &"business_day_expired") -> Dictionary:
	var abandoned_active := PackedStringArray()
	for order_id in _active_order_ids.duplicate():
		if not _orders.has(order_id):
			continue
		var order: Dictionary = _orders[order_id]
		order["state"] = &"abandoned"
		order["status"] = &"expired" if reason == &"business_day_expired" else &"failed"
		order["abandon_reason"] = reason
		_orders[order_id] = order
		abandoned_active.append(str(order_id))
	var abandoned_waiting := PackedStringArray()
	for order_id in _queue_order_ids:
		if _active_order_ids.has(order_id) or not _orders.has(order_id):
			continue
		var waiting: Dictionary = _orders[order_id]
		waiting["state"] = &"abandoned"
		waiting["status"] = &"expired"
		waiting["abandon_reason"] = reason
		_orders[order_id] = waiting
		abandoned_waiting.append(str(order_id))
	_active_order_ids.clear()
	_queue_order_ids.clear()
	queue_changed.emit([])
	return {"success": true, "abandoned_active_order_ids": abandoned_active, "abandoned_waiting_order_ids": abandoned_waiting, "reason": reason}


func begin_serving(order_id: StringName) -> Dictionary:
	if not _is_active_order(order_id):
		return {"success": false, "reason": &"order_not_active"}
	var order: Dictionary = _orders[order_id]
	order["state"] = &"serving"
	order["status"] = &"serving"
	_orders[order_id] = order
	queue_changed.emit(queue_snapshot())
	return {"success": true, "order": order.duplicate(true)}


func cancel_serving(order_id: StringName) -> Dictionary:
	if not _is_active_order(order_id):
		return {"success": false, "reason": &"order_not_active"}
	var order: Dictionary = _orders[order_id]
	if StringName(order.get("state", &"")) != &"serving":
		return {"success": true, "changed": false, "order": order.duplicate(true)}
	order["state"] = &"active"
	order["status"] = &"active"
	_orders[order_id] = order
	queue_changed.emit(queue_snapshot())
	return {"success": true, "changed": true, "order": order.duplicate(true)}


func _finish_failure(order_id: StringName, terminal_state: StringName, reason: StringName, reputation_delta: int) -> Dictionary:
	if _terminal_results.has(order_id):
		var previous: Dictionary = Dictionary(_terminal_results[order_id]).duplicate(true)
		previous["already_settled"] = true
		return previous
	if not _is_active_order(order_id):
		return {"success": false, "reason": &"order_not_active"}
	var order: Dictionary = _orders[order_id]
	var stored_items: Array = Array(order.get("items", [])).duplicate(true)
	for item_index in range(stored_items.size()):
		var item: Dictionary = Dictionary(stored_items[item_index])
		var products := _item_products(item)
		for product_index in range(products.size()):
			var product := products[product_index].duplicate(true)
			product["status"] = &"wasted"
			products[product_index] = product
		if not products.is_empty():
			item["attached_products"] = products
			item["attached_product"] = products.back().duplicate(true)
			stored_items[item_index] = item
	order["items"] = stored_items
	order["state"] = terminal_state
	order["status"] = terminal_state
	order["failure_reason"] = reason
	_orders[order_id] = order
	var result := {
		"success": true,
		"settlement_id": StringName("settlement.%s" % order_id),
		"order_id": order_id,
		"order_success": false,
		"terminal_state": terminal_state,
		"reason": reason,
		"reputation_delta": reputation_delta,
		"teaching_area_id": StringName(order.get("teaching_area_id", &"")),
		"tutorial_kind": StringName(order.get("tutorial_kind", &"")),
		"tutorial_id": StringName(order.get("tutorial_id", &"")),
		"production_started": bool(order.get("production_started", false)),
		"order": order.duplicate(true),
	}
	_terminal_results[order_id] = result.duplicate(true)
	_remove_from_queue(order_id)
	_fill_active_slots()
	queue_changed.emit(queue_snapshot())
	order_settled.emit(result.duplicate(true))
	return result


func _active_item(order_id: StringName, item_index: int) -> Dictionary:
	if not _is_active_order(order_id):
		return {}
	var items: Array = _orders[order_id].get("items", [])
	return {} if item_index < 0 or item_index >= items.size() else Dictionary(items[item_index])


func _product_mismatch_reasons(item: Dictionary, product: Dictionary) -> PackedStringArray:
	var reasons := PackedStringArray()
	if StringName(product.get("product_id", &"")) != StringName(item.get("product_id", &"")):
		reasons.append("product_id")
	var area_id := StringName(item.get("area_id", &""))
	if area_id == &"area.pancake":
		if StringName(product.get("heat_preference", &"")) != StringName(item.get("heat_preference", &"")):
			reasons.append("heat_preference")
	else:
		var expected_temperature := normalized_temperature_mode(item.get("temperature_mode", &"room_temperature"))
		var actual_temperature := normalized_temperature_mode(product.get("temperature_mode", &"room_temperature"))
		if expected_temperature.is_empty() or actual_temperature.is_empty() or actual_temperature != expected_temperature:
			reasons.append("temperature_mode")
	if not _same_ids(product.get("ingredient_ids", []), item.get("ingredient_ids", [])):
		reasons.append("ingredient_ids")
	if not _same_ids(product.get("sauce_ids", []), item.get("sauce_ids", [])):
		reasons.append("sauce_ids")
	if area_id == &"area.fresh_soy_milk" and int(product.get("sugar_servings", 0)) != int(item.get("sugar_servings", 0)):
		reasons.append("sugar_servings")
	return reasons


func _item_products(item: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for product_value in Array(item.get("attached_products", [])):
		var product := Dictionary(product_value).duplicate(true)
		if not product.is_empty():
			result.append(product)
	if result.is_empty():
		var legacy_product := Dictionary(item.get("attached_product", {})).duplicate(true)
		if not legacy_product.is_empty():
			result.append(legacy_product)
	return result


static func normalized_temperature_mode(value: Variant) -> StringName:
	var normalized := StringName(value)
	if normalized.is_empty() or normalized == &"normal" or normalized == &"room_temperature":
		return &"room_temperature"
	if normalized == &"heated":
		return &"heated"
	if normalized == &"iced":
		# Older saves may contain soy orders generated before iced soy was retired.
		# Serve them as room-temperature orders rather than leaving them impossible.
		return &"room_temperature"
	return &""


static func _same_ids(left: Variant, right: Variant) -> bool:
	return _normalized_ids(left) == _normalized_ids(right)


static func _normalized_ids(source: Variant) -> PackedStringArray:
	var ids := PackedStringArray(Array(source).map(func(value): return str(value)))
	ids.sort()
	return ids


static func _first_over_portioned_id(ids: PackedStringArray) -> StringName:
	var counts := {}
	for id in ids:
		counts[id] = int(counts.get(id, 0)) + 1
		if int(counts[id]) > MAX_PORTIONS_PER_REQUIREMENT:
			return StringName(id)
	return &""


static func _unique_id_count(ids: PackedStringArray) -> int:
	var unique := {}
	for id in ids:
		unique[id] = true
	return unique.size()


func _restore(source: Dictionary) -> void:
	var source_version := int(source.get("version", 0))
	_sequence = maxi(int(source.get("sequence", 0)), 0)
	_active_order_ids.clear()
	_orders.clear()
	for raw_order_id in Dictionary(source.get("orders", {})):
		var order_id: StringName = StringName(raw_order_id)
		var order := Dictionary(source["orders"][raw_order_id]).duplicate(true)
		var metadata := Dictionary(order.get("metadata", {}))
		var restored_customer_id := StringName(order.get("customer_id", &""))
		if source_version < 5:
			order["customer_id"] = legacy_customer_id_for_sequence(int(order.get("sequence", 1)))
		elif not CUSTOMER_IDS.has(restored_customer_id) and StringName(metadata.get("special_customer_id", &"")).is_empty():
			order["customer_id"] = customer_id_for_sequence(int(order.get("sequence", 1)))
		order["special_customer_id"] = StringName(order.get("special_customer_id", metadata.get("special_customer_id", &"")))
		order["special_title"] = str(order.get("special_title", metadata.get("special_title", "")))
		order["special_rule_text"] = str(order.get("special_rule_text", metadata.get("special_rule_text", "")))
		order["customer_line"] = str(order.get("customer_line", metadata.get("customer_line", "")))
		order["perfect_quote_coins"] = maxi(int(order.get("perfect_quote_coins", metadata.get("perfect_quote_coins", order.get("base_coins", 0)))), 0)
		var legacy_teaching_area_id := StringName(order.get("teaching_area_id", metadata.get("teaching_area_id", &"")))
		var tutorial_kind := StringName(order.get("tutorial_kind", metadata.get("tutorial_kind", &"")))
		var tutorial_id := StringName(order.get("tutorial_id", metadata.get("tutorial_id", &"")))
		if tutorial_id.is_empty() and not legacy_teaching_area_id.is_empty():
			tutorial_kind = &"area"
			tutorial_id = legacy_teaching_area_id
		order["teaching_area_id"] = legacy_teaching_area_id
		order["tutorial_kind"] = tutorial_kind
		order["tutorial_id"] = tutorial_id
		var tutorial_no_countdown := bool(order.get("tutorial_no_countdown", false)) or not tutorial_id.is_empty() or _metadata_has_no_countdown(metadata)
		order["tutorial_no_countdown"] = tutorial_no_countdown
		if tutorial_no_countdown:
			order["remaining_patience_seconds"] = maxf(float(order.get("patience_seconds", order.get("remaining_patience_seconds", 0.0))), 0.0)
		var restored_items: Array = Array(order.get("items", [])).duplicate(true)
		for item_index in range(restored_items.size()):
			var item := Dictionary(restored_items[item_index]).duplicate(true)
			item["temperature_mode"] = normalized_temperature_mode(item.get("temperature_mode", &"room_temperature"))
			var restored_products := _item_products(item)
			var restored_ids := PackedStringArray()
			for product_index in range(restored_products.size()):
				var product := restored_products[product_index].duplicate(true)
				if not product.has("reservation_origin"):
					product["reservation_origin"] = {"source_kind": &"legacy", "source_index": -1, "product_id": StringName(product.get("product_id", &""))}
				if not product.has("return_policy"):
					product["return_policy"] = &"waste_only"
				restored_products[product_index] = product
				restored_ids.append(str(product.get("product_instance_id", "")))
			item["attached_products"] = restored_products
			item["prepared_product_instance_ids"] = restored_ids
			item["attached_quantity"] = restored_ids.size()
			if restored_products.is_empty():
				item.erase("attached_product")
			else:
				item["attached_product"] = restored_products.back().duplicate(true)
			restored_items[item_index] = item
		order["items"] = restored_items
		_orders[order_id] = order
	_queue_order_ids.clear()
	for raw_order_id in Array(source.get("queue_order_ids", [])):
		var queued_id := StringName(raw_order_id)
		if _orders.has(queued_id) and not _queue_order_ids.has(queued_id):
			_queue_order_ids.append(queued_id)
	if _queue_order_ids.is_empty():
		var restorable: Array[Dictionary] = []
		for order_id in _orders:
			var order := Dictionary(_orders[order_id])
			if StringName(order.get("state", &"")) in [&"active", &"waiting"]:
				restorable.append({"order_id": order_id, "sequence": int(order.get("sequence", 0))})
		restorable.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left.get("sequence", 0)) < int(right.get("sequence", 0)))
		for entry in restorable:
			_queue_order_ids.append(StringName(entry.get("order_id", &"")))
	_settled_order_ids.clear()
	for raw_order_id in Array(source.get("settled_order_ids", [])):
		_settled_order_ids[StringName(raw_order_id)] = true
	_terminal_results.clear()
	for raw_order_id in Dictionary(source.get("terminal_results", {})):
		_terminal_results[StringName(raw_order_id)] = Dictionary(source["terminal_results"][raw_order_id]).duplicate(true)
	var restored_active_ids: Array[StringName] = []
	for raw_order_id in Array(source.get("active_order_ids", [])):
		var restored_id := StringName(raw_order_id)
		if _orders.has(restored_id) and _queue_order_ids.has(restored_id) and not restored_active_ids.has(restored_id):
			restored_active_ids.append(restored_id)
	if restored_active_ids.is_empty():
		var legacy_active_id := StringName(source.get("active_order_id", &""))
		if _orders.has(legacy_active_id) and _queue_order_ids.has(legacy_active_id):
			restored_active_ids.append(legacy_active_id)
	for order_id in _queue_order_ids:
		if restored_active_ids.size() >= MAX_ACTIVE_CUSTOMERS:
			break
		if restored_active_ids.has(order_id) or not _orders.has(order_id):
			continue
		var candidate: Dictionary = _orders[order_id]
		if not restored_active_ids.is_empty() and _active_ids_include_tutorial(restored_active_ids):
			break
		if bool(candidate.get("tutorial_no_countdown", false)):
			if restored_active_ids.is_empty():
				restored_active_ids.append(order_id)
			break
		restored_active_ids.append(order_id)
	for order_id in _queue_order_ids:
		if not _orders.has(order_id):
			continue
		var order: Dictionary = _orders[order_id]
		if restored_active_ids.has(order_id):
			var slot := restored_active_ids.find(order_id)
			order["service_slot"] = slot
			if StringName(order.get("state", &"")) != &"serving":
				order["state"] = &"active"
				order["status"] = &"active"
			_active_order_ids.append(order_id)
		else:
			order["state"] = &"waiting"
			order["status"] = &"waiting"
			order["service_slot"] = -1
		_orders[order_id] = order
	_fill_active_slots()


func _metadata_has_no_countdown(metadata: Dictionary) -> bool:
	return (
		bool(metadata.get("tutorial_no_countdown", false))
		or not StringName(metadata.get("teaching_area_id", &"")).is_empty()
		or not StringName(metadata.get("tutorial_id", &"")).is_empty()
		or bool(Dictionary(metadata.get("legacy_order", {})).get("tutorial_no_countdown", false))
	)


func _remove_from_queue(order_id: StringName) -> void:
	_queue_order_ids.erase(order_id)
	_active_order_ids.erase(order_id)


func _activate_next_waiting() -> void:
	_fill_active_slots()


func _fill_active_slots(avoid_first_customer_id: StringName = &"") -> void:
	if _active_ids_include_tutorial(_active_order_ids):
		return
	# A tutorial owns the whole storefront.  When it leaves, activate a waiting
	# normal customer with a visibly different identity into service slot zero
	# before filling the remaining slots in queue order.  Existing persisted
	# customer IDs are preserved; only activation order changes.
	if _active_order_ids.is_empty() and not avoid_first_customer_id.is_empty():
		for order_id in _queue_order_ids:
			if not _orders.has(order_id):
				continue
			var candidate := Dictionary(_orders[order_id])
			if (
				StringName(candidate.get("state", &"")) == &"waiting"
				and not bool(candidate.get("tutorial_no_countdown", false))
				and StringName(candidate.get("customer_id", &"")) != avoid_first_customer_id
			):
				_activate_order_in_slot(order_id, _first_free_service_slot())
				break
	for order_id in _queue_order_ids:
		if _active_order_ids.size() >= MAX_ACTIVE_CUSTOMERS:
			return
		if _active_order_ids.has(order_id):
			continue
		if not _orders.has(order_id):
			continue
		var order := Dictionary(_orders[order_id])
		if StringName(order.get("state", &"")) != &"waiting":
			continue
		var tutorial := bool(order.get("tutorial_no_countdown", false))
		if tutorial and not _active_order_ids.is_empty():
			return
		_activate_order_in_slot(order_id, _first_free_service_slot())
		if tutorial:
			return


func _activate_order_in_slot(order_id: StringName, slot: int) -> void:
	if not _orders.has(order_id) or slot < 0 or slot >= MAX_ACTIVE_CUSTOMERS:
		return
	var order: Dictionary = _orders[order_id]
	order["state"] = &"active"
	order["status"] = &"active"
	order["service_slot"] = slot
	var customer_id := StringName(order.get("customer_id", &""))
	if not CUSTOMER_IDS.has(customer_id) and StringName(order.get("special_customer_id", Dictionary(order.get("metadata", {})).get("special_customer_id", &""))).is_empty():
		order["customer_id"] = customer_id_for_sequence(int(order.get("sequence", 1)))
	_orders[order_id] = order
	if not _active_order_ids.has(order_id):
		_active_order_ids.append(order_id)


func _can_activate_new_order(tutorial: bool) -> bool:
	if tutorial:
		return _active_order_ids.is_empty()
	return _active_order_ids.size() < MAX_ACTIVE_CUSTOMERS and not _active_ids_include_tutorial(_active_order_ids)


func _first_free_service_slot() -> int:
	for slot in MAX_ACTIVE_CUSTOMERS:
		var occupied := false
		for order_id in _active_order_ids:
			if _orders.has(order_id) and int(Dictionary(_orders[order_id]).get("service_slot", -1)) == slot:
				occupied = true
				break
		if not occupied:
			return slot
	return -1


func _is_active_order(order_id: StringName) -> bool:
	return not order_id.is_empty() and _active_order_ids.has(order_id) and _orders.has(order_id)


static func customer_id_for_sequence(sequence: int) -> StringName:
	var normalized_sequence := maxi(sequence, 1)
	return CUSTOMER_IDS[(normalized_sequence - 1) % CUSTOMER_IDS.size()]


static func legacy_customer_id_for_sequence(sequence: int) -> StringName:
	var normalized_sequence := maxi(sequence, 1)
	return CUSTOMER_IDS[(normalized_sequence - 1) % LEGACY_CUSTOMER_COUNT_BEFORE_POOL_EXPANSION]


func _active_ids_include_tutorial(order_ids: Array[StringName]) -> bool:
	for order_id in order_ids:
		if _orders.has(order_id) and bool(Dictionary(_orders[order_id]).get("tutorial_no_countdown", false)):
			return true
	return false
