class_name FiveAreaOrderService
extends RefCounted

## Formal order state is UI-independent.  Stage 7 will replace only candidate
## generation/tutorial selection, not the persisted order transaction.

## Pancake production currently supports sweet-flour and red-chili sauce.  The
## formal contract nevertheless owns the upper bound so a malformed order can
## never introduce a third sauce when more sauce content is added later.
const MAX_SAUCE_REQUIREMENTS_PER_ITEM := 2

var _orders: Dictionary = {}
var _active_order_id: StringName = &""
var _sequence: int = 0
var _settled_order_ids: Dictionary = {}


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
	if not _active_order_id.is_empty():
		return {"success": false, "reason": &"active_order_exists"}
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
		item["sauce_ids"] = sauce_ids
		item["prepared_product_instance_ids"] = PackedStringArray()
		normalized_items.append(item)
	var order: Dictionary = {
		"order_id": order_id,
		"sequence": _sequence,
		"complexity": &"single" if normalized_items.size() == 1 else &"multi_item",
		"state": &"active",
		"items": normalized_items,
		"metadata": metadata.duplicate(true),
	}
	_orders[order_id] = order
	_active_order_id = order_id
	return {"success": true, "order": order.duplicate(true)}


func active_order() -> Dictionary:
	return {} if _active_order_id.is_empty() else Dictionary(_orders.get(_active_order_id, {})).duplicate(true)


func snapshot() -> Dictionary:
	return {
		"version": 1,
		"sequence": _sequence,
		"active_order_id": str(_active_order_id),
		"orders": _orders.duplicate(true),
		"settled_order_ids": _settled_order_ids.keys(),
	}


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
	item["attached_product"] = product.duplicate(true)
	items[item_index] = item
	order["items"] = items
	_orders[order_id] = order
	return {"success": true, "will_match": preview.get("will_match", false), "mismatch_reasons": preview.get("mismatch_reasons", PackedStringArray())}


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
		var product: Dictionary = Dictionary(item.get("attached_product", {}))
		var reasons := PackedStringArray(["missing_order_item"]) if product.is_empty() else _product_mismatch_reasons(item, product)
		if attached.size() < int(item.get("quantity", 1)):
			reasons.append("incomplete_quantity")
		all_reasons.append_array(reasons)
		item_results.append({"product_id": item.get("product_id", &""), "success": reasons.is_empty(), "mismatch_reasons": reasons, "product": product})
	var success := all_reasons.is_empty()
	var settlement_id := StringName("settlement.%s" % order_id)
	_settled_order_ids[order_id] = true
	order["state"] = &"settled"
	_orders[order_id] = order
	_active_order_id = &""
	return {"success": true, "settlement_id": settlement_id, "order_success": success, "mismatch_reasons": all_reasons, "item_results": item_results}


func abandon_active_order(reason: StringName = &"business_day_expired") -> Dictionary:
	if _active_order_id.is_empty() or not _orders.has(_active_order_id):
		return {"success": false, "reason": &"order_not_active"}
	var order: Dictionary = _orders[_active_order_id]
	order["state"] = &"abandoned"
	order["abandon_reason"] = reason
	_orders[_active_order_id] = order
	var abandoned_order_id := _active_order_id
	_active_order_id = &""
	return {"success": true, "order_id": abandoned_order_id, "reason": reason}


func _active_item(order_id: StringName, item_index: int) -> Dictionary:
	if order_id.is_empty() or order_id != _active_order_id or not _orders.has(order_id):
		return {}
	var items: Array = _orders[order_id].get("items", [])
	return {} if item_index < 0 or item_index >= items.size() else Dictionary(items[item_index])


func _product_mismatch_reasons(item: Dictionary, product: Dictionary) -> PackedStringArray:
	var reasons := PackedStringArray()
	if StringName(product.get("product_id", &"")) != StringName(item.get("product_id", &"")):
		reasons.append("product_id")
	if StringName(product.get("heat_preference", &"")) != StringName(item.get("heat_preference", &"")):
		reasons.append("heat_preference")
	if not _same_ids(product.get("ingredient_ids", []), item.get("ingredient_ids", [])):
		reasons.append("ingredient_ids")
	if not _same_ids(product.get("sauce_ids", []), item.get("sauce_ids", [])):
		reasons.append("sauce_ids")
	return reasons


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
		_orders[order_id] = Dictionary(source["orders"][raw_order_id]).duplicate(true)
	_settled_order_ids.clear()
	for raw_order_id in Array(source.get("settled_order_ids", [])):
		_settled_order_ids[StringName(raw_order_id)] = true
	if _active_order_id.is_empty() or not _orders.has(_active_order_id):
		_active_order_id = &""
