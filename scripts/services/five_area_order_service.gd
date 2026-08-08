class_name FiveAreaOrderService
extends RefCounted

signal queue_changed(snapshot: Array[Dictionary])
signal order_settled(result: Dictionary)

## Formal order state is UI-independent.  Stage 7 will replace only candidate
## generation/tutorial selection, not the persisted order transaction.

## Pancake production currently supports sweet-flour and red-chili sauce.  The
## formal contract nevertheless owns the upper bound so a malformed order can
## never introduce a third sauce when more sauce content is added later.
const MAX_SAUCE_REQUIREMENTS_PER_ITEM := 2

var _orders: Dictionary = {}
var _active_order_id: StringName = &""
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
	if _queue_order_ids.size() >= 4:
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
		var sauce_ids := _normalized_ids(item.get("sauce_ids", []))
		if sauce_ids.size() > MAX_SAUCE_REQUIREMENTS_PER_ITEM:
			return {
				"success": false,
				"reason": &"too_many_sauce_requirements",
				"max_sauce_requirements": MAX_SAUCE_REQUIREMENTS_PER_ITEM,
				"requested_sauce_count": sauce_ids.size(),
			}
		item["quantity"] = maxi(int(item.get("quantity", 1)), 1)
		var normalized_temperature := normalized_temperature_mode(item.get("temperature_mode", &"room_temperature"))
		if normalized_temperature.is_empty():
			return {"success": false, "reason": &"invalid_temperature_mode", "value": item.get("temperature_mode")}
		item["temperature_mode"] = normalized_temperature
		item["sauce_ids"] = sauce_ids
		item["prepared_product_instance_ids"] = PackedStringArray()
		normalized_items.append(item)
	var initial_state := &"active" if _active_order_id.is_empty() else &"waiting"
	var tutorial_no_countdown := _metadata_has_no_countdown(metadata)
	var complexity := &"single"
	if normalized_items.size() == 2:
		complexity = &"double"
	elif normalized_items.size() >= 3:
		complexity = &"triple"
	var order: Dictionary = {
		"order_id": order_id,
		"sequence": _sequence,
		"complexity": complexity,
		"state": initial_state,
		"status": initial_state,
		"items": normalized_items,
		"patience_seconds": maxf(float(metadata.get("patience_seconds", 0.0)), 0.0),
		"remaining_patience_seconds": maxf(float(metadata.get("patience_seconds", 0.0)), 0.0),
		"teaching_area_id": StringName(metadata.get("teaching_area_id", &"")),
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
		_active_order_id = order_id
	queue_changed.emit(queue_snapshot())
	return {"success": true, "order": order.duplicate(true)}


func active_order() -> Dictionary:
	return {} if _active_order_id.is_empty() else Dictionary(_orders.get(_active_order_id, {})).duplicate(true)


func current_order() -> Dictionary:
	return active_order()


func waiting_orders() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for order_id in _queue_order_ids:
		if order_id == _active_order_id or not _orders.has(order_id):
			continue
		var order := Dictionary(_orders[order_id])
		if StringName(order.get("state", &"")) == &"waiting":
			result.append(order.duplicate(true))
	return result


func ensure_queue(target_size: int = 4, generated_candidates: Variant = {}) -> Dictionary:
	var requested_size := clampi(target_size, 1, 4)
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
	if not _active_order_id.is_empty():
		return {"success": false, "reason": &"active_order_exists"}
	if not _orders.has(order_id) or not _queue_order_ids.has(order_id):
		return {"success": false, "reason": &"order_not_waiting"}
	var order := Dictionary(_orders[order_id])
	if StringName(order.get("state", &"")) != &"waiting":
		return {"success": false, "reason": &"order_not_waiting"}
	order["state"] = &"active"
	order["status"] = &"active"
	_orders[order_id] = order
	_active_order_id = order_id
	queue_changed.emit(queue_snapshot())
	return {"success": true, "order": order.duplicate(true)}


func snapshot() -> Dictionary:
	return {
		"version": 3,
		"sequence": _sequence,
		"active_order_id": str(_active_order_id),
		"queue_order_ids": PackedStringArray(_queue_order_ids.map(func(value): return str(value))),
		"orders": _orders.duplicate(true),
		"settled_order_ids": _settled_order_ids.keys(),
		"terminal_results": _terminal_results.duplicate(true),
	}


func advance_patience(delta: float) -> Dictionary:
	if delta <= 0.0 or _active_order_id.is_empty() or not _orders.has(_active_order_id):
		return {"success": true, "changed": false, "order": active_order()}
	var order: Dictionary = _orders[_active_order_id]
	if bool(order.get("tutorial_no_countdown", false)):
		return {"success": true, "changed": false, "expired": false, "order": order.duplicate(true)}
	var remaining := maxf(float(order.get("remaining_patience_seconds", order.get("patience_seconds", 0.0))) - delta, 0.0)
	order["remaining_patience_seconds"] = snappedf(remaining, 0.1)
	_orders[_active_order_id] = order
	if remaining > 0.0:
		return {"success": true, "changed": true, "expired": false, "order": order.duplicate(true)}
	return _finish_failure(_active_order_id, &"expired", &"patience_expired", -2)


func advance_time(delta: float) -> Array[Dictionary]:
	var result := advance_patience(delta)
	return [result] if bool(result.get("changed", false)) or result.has("terminal_state") else []


func preview_refusal(order_id: StringName) -> Dictionary:
	if order_id.is_empty() or order_id != _active_order_id or not _orders.has(order_id):
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
	var reserved_product := product.duplicate(true)
	reserved_product["status"] = &"reserved"
	reserved_product["owner_order_id"] = order_id
	item["attached_product"] = reserved_product
	items[item_index] = item
	order["items"] = items
	_orders[order_id] = order
	return {"success": true, "will_match": preview.get("will_match", false), "mismatch_reasons": preview.get("mismatch_reasons", PackedStringArray())}


func mark_production_started(order_id: StringName, source_instance_id: StringName) -> Dictionary:
	if order_id.is_empty() or order_id != _active_order_id or not _orders.has(order_id):
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
	if order.is_empty() or order_id != _active_order_id:
		return {"success": false, "reason": &"order_not_active"}
	var item_results: Array = []
	var all_reasons := PackedStringArray()
	for item_value in Array(order.get("items", [])):
		var item: Dictionary = Dictionary(item_value)
		var attached: Array = Array(item.get("prepared_product_instance_ids", []))
		if attached.size() < int(item.get("quantity", 1)) and not submit_incomplete:
			return {"success": false, "reason": &"missing_order_item"}
		var product: Dictionary = Dictionary(item.get("attached_product", {})).duplicate(true)
		var reasons := PackedStringArray(["missing_order_item"]) if product.is_empty() else _product_mismatch_reasons(item, product)
		if attached.size() < int(item.get("quantity", 1)):
			reasons.append("incomplete_quantity")
		all_reasons.append_array(reasons)
		item_results.append({"product_id": item.get("product_id", &""), "success": reasons.is_empty(), "mismatch_reasons": reasons, "product": product})
	var success := all_reasons.is_empty()
	for item_index in range(item_results.size()):
		var result_entry: Dictionary = item_results[item_index]
		var finalized_product: Dictionary = Dictionary(result_entry.get("product", {})).duplicate(true)
		if not finalized_product.is_empty():
			finalized_product["status"] = &"consumed" if success else &"wasted"
			result_entry["product"] = finalized_product
			item_results[item_index] = result_entry
			var stored_item: Dictionary = Array(order.get("items", []))[item_index]
			stored_item["attached_product"] = finalized_product
			var stored_items: Array = Array(order.get("items", [])).duplicate(true)
			stored_items[item_index] = stored_item
			order["items"] = stored_items
	var settlement_id := StringName("settlement.%s" % order_id)
	_settled_order_ids[order_id] = true
	order["state"] = &"settled"
	order["status"] = &"completed" if success else &"failed"
	_orders[order_id] = order
	_active_order_id = &""
	var result := {"success": true, "settlement_id": settlement_id, "order_id": order_id, "order_success": success, "mismatch_reasons": all_reasons, "item_results": item_results, "terminal_state": &"completed" if success else &"failed"}
	_terminal_results[order_id] = result.duplicate(true)
	_remove_from_queue(order_id)
	_activate_next_waiting()
	queue_changed.emit(queue_snapshot())
	order_settled.emit(result.duplicate(true))
	return result


func abandon_active_order(reason: StringName = &"business_day_expired") -> Dictionary:
	if _active_order_id.is_empty() or not _orders.has(_active_order_id):
		return {"success": false, "reason": &"order_not_active"}
	var order: Dictionary = _orders[_active_order_id]
	order["state"] = &"abandoned"
	order["status"] = &"expired" if reason == &"business_day_expired" else &"failed"
	order["abandon_reason"] = reason
	_orders[_active_order_id] = order
	var abandoned_order_id := _active_order_id
	_active_order_id = &""
	_remove_from_queue(abandoned_order_id)
	var abandoned_waiting := PackedStringArray()
	if reason == &"business_day_expired":
		for waiting_id in _queue_order_ids.duplicate():
			var waiting := Dictionary(_orders.get(waiting_id, {}))
			waiting["state"] = &"abandoned"
			waiting["status"] = &"expired"
			waiting["abandon_reason"] = reason
			_orders[waiting_id] = waiting
			abandoned_waiting.append(str(waiting_id))
		_queue_order_ids.clear()
	else:
		_activate_next_waiting()
	queue_changed.emit(queue_snapshot())
	return {"success": true, "order_id": abandoned_order_id, "abandoned_waiting_order_ids": abandoned_waiting, "reason": reason}


func _finish_failure(order_id: StringName, terminal_state: StringName, reason: StringName, reputation_delta: int) -> Dictionary:
	if _terminal_results.has(order_id):
		var previous: Dictionary = Dictionary(_terminal_results[order_id]).duplicate(true)
		previous["already_settled"] = true
		return previous
	if order_id.is_empty() or order_id != _active_order_id or not _orders.has(order_id):
		return {"success": false, "reason": &"order_not_active"}
	var order: Dictionary = _orders[order_id]
	var stored_items: Array = Array(order.get("items", [])).duplicate(true)
	for item_index in range(stored_items.size()):
		var item: Dictionary = Dictionary(stored_items[item_index])
		var product := Dictionary(item.get("attached_product", {})).duplicate(true)
		if not product.is_empty():
			product["status"] = &"wasted"
			item["attached_product"] = product
			stored_items[item_index] = item
	order["items"] = stored_items
	order["state"] = terminal_state
	order["status"] = terminal_state
	order["failure_reason"] = reason
	_orders[order_id] = order
	_active_order_id = &""
	var result := {
		"success": true,
		"settlement_id": StringName("settlement.%s" % order_id),
		"order_id": order_id,
		"order_success": false,
		"terminal_state": terminal_state,
		"reason": reason,
		"reputation_delta": reputation_delta,
		"teaching_area_id": StringName(order.get("teaching_area_id", &"")),
		"production_started": bool(order.get("production_started", false)),
		"order": order.duplicate(true),
	}
	_terminal_results[order_id] = result.duplicate(true)
	_remove_from_queue(order_id)
	_activate_next_waiting()
	queue_changed.emit(queue_snapshot())
	order_settled.emit(result.duplicate(true))
	return result


func _active_item(order_id: StringName, item_index: int) -> Dictionary:
	if order_id.is_empty() or order_id != _active_order_id or not _orders.has(order_id):
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
	return reasons


static func normalized_temperature_mode(value: Variant) -> StringName:
	var normalized := StringName(value)
	if normalized.is_empty() or normalized == &"normal" or normalized == &"room_temperature":
		return &"room_temperature"
	if normalized == &"heated":
		return &"heated"
	return &""


static func _same_ids(left: Variant, right: Variant) -> bool:
	return _normalized_ids(left) == _normalized_ids(right)


static func _normalized_ids(source: Variant) -> PackedStringArray:
	var ids := PackedStringArray(Array(source).map(func(value): return str(value)))
	ids.sort()
	return ids


func _restore(source: Dictionary) -> void:
	_sequence = maxi(int(source.get("sequence", 0)), 0)
	_active_order_id = StringName(source.get("active_order_id", &""))
	_orders.clear()
	for raw_order_id in Dictionary(source.get("orders", {})):
		var order_id: StringName = StringName(raw_order_id)
		var order := Dictionary(source["orders"][raw_order_id]).duplicate(true)
		var metadata := Dictionary(order.get("metadata", {}))
		var tutorial_no_countdown := bool(order.get("tutorial_no_countdown", false)) or not StringName(order.get("teaching_area_id", &"")).is_empty() or _metadata_has_no_countdown(metadata)
		order["tutorial_no_countdown"] = tutorial_no_countdown
		if tutorial_no_countdown:
			order["remaining_patience_seconds"] = maxf(float(order.get("patience_seconds", order.get("remaining_patience_seconds", 0.0))), 0.0)
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
	if _active_order_id.is_empty() or not _orders.has(_active_order_id):
		_active_order_id = &""
		_activate_next_waiting()


func _metadata_has_no_countdown(metadata: Dictionary) -> bool:
	return (
		bool(metadata.get("tutorial_no_countdown", false))
		or not StringName(metadata.get("teaching_area_id", &"")).is_empty()
		or bool(Dictionary(metadata.get("legacy_order", {})).get("tutorial_no_countdown", false))
	)


func _remove_from_queue(order_id: StringName) -> void:
	_queue_order_ids.erase(order_id)


func _activate_next_waiting() -> void:
	if not _active_order_id.is_empty():
		return
	for order_id in _queue_order_ids:
		if not _orders.has(order_id):
			continue
		var order := Dictionary(_orders[order_id])
		if StringName(order.get("state", &"")) != &"waiting":
			continue
		order["state"] = &"active"
		order["status"] = &"active"
		_orders[order_id] = order
		_active_order_id = order_id
		return
