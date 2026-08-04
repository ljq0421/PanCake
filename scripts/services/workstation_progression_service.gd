extends RefCounted

const CATALOG := preload("res://scripts/data/workstation_expansion_catalog.gd")
const INGREDIENT_STOCK_MODEL := preload("res://scripts/gameplay/ingredient_stock_model.gd")

var coins := 0
var reputation := 0
var current_day := 1
var metrics := {}
var equipment_levels := {}
var equipment_batches := {}
var owned_items := {}
var pending_purchase: StringName = &""
var refill_progress := {}
var inventory: RefCounted
var stall_tier := 0


func _init(snapshot: Dictionary = {}) -> void:
	inventory = INGREDIENT_STOCK_MODEL.new({}, CATALOG.stock_ids(), 6, false)
	owned_items[CATALOG.TOOL_SPREADER_BASIC] = true
	owned_items[CATALOG.TOOL_SAUCE_BRUSH_MANUAL] = true
	owned_items[CATALOG.INGREDIENT_BOX_BASIC] = true
	for stock_id in [CATALOG.STOCK_EGG, CATALOG.STOCK_BAOCUI, CATALOG.STOCK_SCALLION]:
		inventory.call("set_current", stock_id, 6)
	if not snapshot.is_empty():
		load_snapshot(snapshot)


func owns(item_id: StringName) -> bool:
	return bool(owned_items.get(item_id, false))


func owns_equipment(device_id: StringName) -> bool:
	return equipment_tier(device_id) >= CATALOG.TIER_BASIC


func equipment_tier(device_id: StringName) -> int:
	return int(equipment_levels.get(device_id, -1))


func set_metric(metric_id: StringName, value: int) -> void:
	metrics[metric_id] = maxi(value, 0)


func metric(metric_id: StringName) -> int:
	return int(metrics.get(metric_id, 0))


func purchase(item_id: StringName) -> Dictionary:
	var definition := CATALOG.purchase_definition(item_id)
	if definition.is_empty():
		return _failure(&"unknown_purchase")
	var kind: StringName = definition.get("kind", &"")
	if kind == &"equipment":
		var device_id: StringName = definition.get("device_id", &"")
		var target_tier := int(definition.get("target_tier", -1))
		var current_tier := equipment_tier(device_id)
		if current_tier >= target_tier:
			return _failure(&"already_owned")
		if target_tier != current_tier + 1:
			return _failure(&"missing_previous_tier", {"required_tier": target_tier - 1})
	elif owns(item_id):
		return _failure(&"already_owned")
	if not pending_purchase.is_empty():
		return _failure(&"pending_purchase_exists", {"pending_purchase": pending_purchase})
	var requirement_failure := _check_requirements(definition)
	if not requirement_failure.is_empty():
		return requirement_failure
	var price := int(definition.get("price", 0))
	if coins < price:
		return _failure(&"insufficient_coins", {"required_coins": price, "current_coins": coins})
	coins -= price
	pending_purchase = item_id
	return _success({"item_id": item_id, "charged_coins": price, "activates_on_day": current_day + 1})


func purchase_status(item_id: StringName) -> Dictionary:
	var definition := CATALOG.purchase_definition(item_id)
	if definition.is_empty():
		return {"item_id": item_id, "known": false, "can_purchase": false, "status_text": "未知成长项"}
	var presentation := CATALOG.purchase_presentation(item_id)
	var price := int(definition.get("price", 0))
	var already_owned := _purchase_is_owned(item_id, definition)
	var missing := _missing_requirement_texts(definition)
	var is_pending := pending_purchase == item_id
	var another_pending := not pending_purchase.is_empty() and not is_pending
	var affordable := coins >= price
	var can_purchase := not already_owned and not is_pending and not another_pending and missing.is_empty() and affordable
	var status_text := "现在可买 · 明日生效"
	if already_owned:
		status_text = "已拥有"
	elif is_pending:
		status_text = "已盖章：明日装上"
	elif another_pending:
		status_text = "今日已选择其他成长"
	elif not missing.is_empty():
		status_text = "还需 " + "、".join(missing)
	elif not affordable:
		status_text = "还差 %d 金币" % (price - coins)
	return {
		"item_id": item_id,
		"known": true,
		"label": str(presentation.get("label", item_id)),
		"category": str(presentation.get("category", "成长")),
		"description": str(presentation.get("description", "")),
		"price": price,
		"already_owned": already_owned,
		"pending": is_pending,
		"affordable": affordable,
		"missing_requirements": missing,
		"can_purchase": can_purchase,
		"status_text": status_text,
	}


func growth_recommendations(limit: int = 3) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for item_id in CATALOG.purchase_ids():
		var status := purchase_status(item_id)
		if bool(status.get("already_owned", false)):
			continue
		var rank := 0
		if bool(status.get("pending", false)):
			rank = -10000
		elif bool(status.get("can_purchase", false)):
			rank = 0
		else:
			rank = Array(status.get("missing_requirements", [])).size() * 100
			if not bool(status.get("affordable", false)):
				rank += 20
			var definition := CATALOG.purchase_definition(item_id)
			rank += maxi(int(definition.get("min_day", 1)) - current_day, 0) * 5
		status["recommendation_rank"] = rank
		candidates.append(status)
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_rank := int(left.get("recommendation_rank", 0))
		var right_rank := int(right.get("recommendation_rank", 0))
		if left_rank == right_rank:
			return int(left.get("price", 0)) < int(right.get("price", 0))
		return left_rank < right_rank
	)
	var result: Array[Dictionary] = []
	for index in mini(maxi(limit, 0), candidates.size()):
		result.append(candidates[index])
	return result


func begin_next_business_day() -> Dictionary:
	var activated: StringName = pending_purchase
	if not activated.is_empty():
		_apply_purchase(activated)
		pending_purchase = &""
	current_day += 1
	return {"success": true, "activated_item": activated, "current_day": current_day}


func debit(amount: int) -> bool:
	if amount < 0 or coins < amount:
		return false
	coins -= amount
	return true


func credit(amount: int) -> void:
	coins += maxi(amount, 0)


func ingredient_box_capacity() -> int:
	if owns(CATALOG.INGREDIENT_BOX_ADVANCED):
		return 14
	if owns(CATALOG.INGREDIENT_BOX_INTERMEDIATE):
		return 10
	return 6


func is_recipe_unlocked(recipe_id: StringName) -> bool:
	var definition := CATALOG.recipe_definition(recipe_id)
	if definition.is_empty():
		return false
	var unlock_item: StringName = definition.get("unlock_item", &"")
	return unlock_item.is_empty() or owns(unlock_item)


func unlocked_ingredient_ids() -> Array[StringName]:
	var result := CATALOG.starter_ingredient_ids()
	for stock_id in [CATALOG.STOCK_HAM_SAUSAGE, CATALOG.STOCK_MEAT_FLOSS, CATALOG.STOCK_PORK_TENDERLOIN]:
		var unlock_item := CATALOG.ingredient_unlock_item(stock_id)
		if not unlock_item.is_empty() and owns(unlock_item):
			result.append(stock_id)
	return result


func refill_progress_for(stock_id: StringName) -> float:
	return maxf(float(refill_progress.get(stock_id, 0.0)), 0.0)


func set_refill_progress(stock_id: StringName, seconds: float) -> void:
	if not CATALOG.refill_definition(stock_id).is_empty():
		refill_progress[stock_id] = maxf(seconds, 0.0)


func snapshot() -> Dictionary:
	var equipment := {}
	for device_id in equipment_levels:
		equipment[str(device_id)] = int(equipment_levels[device_id])
	var items := PackedStringArray()
	for item_id in owned_items:
		if bool(owned_items[item_id]):
			items.append(str(item_id))
	var progress := {}
	for stock_id in refill_progress:
		progress[str(stock_id)] = float(refill_progress[stock_id])
	var metric_snapshot := {}
	for metric_id in metrics:
		metric_snapshot[str(metric_id)] = int(metrics[metric_id])
	var batch_snapshot := {}
	for device_id in equipment_batches:
		batch_snapshot[str(device_id)] = Dictionary(equipment_batches[device_id]).duplicate(true)
	return {
		"coins": coins,
		"reputation": reputation,
		"current_day": current_day,
		"metrics": metric_snapshot,
		"equipment_levels": equipment,
		"equipment_batches": batch_snapshot,
		"owned_items": items,
		"pending_purchase": str(pending_purchase),
		"stall_tier": stall_tier,
		"ingredient_stock": inventory.call("snapshot"),
		"refill_progress": progress,
	}


func load_snapshot(snapshot: Dictionary) -> void:
	coins = maxi(int(snapshot.get("coins", 0)), 0)
	reputation = maxi(int(snapshot.get("reputation", 0)), 0)
	current_day = maxi(int(snapshot.get("current_day", 1)), 1)
	metrics.clear()
	for metric_id in Dictionary(snapshot.get("metrics", {})):
		metrics[StringName(metric_id)] = maxi(int(snapshot.metrics[metric_id]), 0)
	equipment_levels.clear()
	for device_id in Dictionary(snapshot.get("equipment_levels", {})):
		equipment_levels[StringName(device_id)] = clampi(int(snapshot.equipment_levels[device_id]), CATALOG.TIER_BASIC, CATALOG.TIER_ADVANCED)
	equipment_batches.clear()
	for device_id in Dictionary(snapshot.get("equipment_batches", {})):
		equipment_batches[StringName(device_id)] = Dictionary(snapshot.equipment_batches[device_id]).duplicate(true)
	owned_items.clear()
	for item_id in Array(snapshot.get("owned_items", [])):
		owned_items[StringName(item_id)] = true
	# New-format snapshots are authoritative; only invariant starter ownership is enforced.
	owned_items[CATALOG.TOOL_SPREADER_BASIC] = true
	owned_items[CATALOG.TOOL_SAUCE_BRUSH_MANUAL] = true
	owned_items[CATALOG.INGREDIENT_BOX_BASIC] = true
	pending_purchase = StringName(snapshot.get("pending_purchase", ""))
	stall_tier = clampi(int(snapshot.get("stall_tier", 0)), 0, 1)
	refill_progress.clear()
	for stock_id in Dictionary(snapshot.get("refill_progress", {})):
		set_refill_progress(StringName(stock_id), float(snapshot.refill_progress[stock_id]))
	var target_capacity := ingredient_box_capacity()
	var capacity_changed := false
	for stock_id in CATALOG.stock_ids():
		if int(inventory.call("capacity", stock_id)) != target_capacity:
			capacity_changed = true
			break
	if capacity_changed:
		inventory.call("set_capacity_for_all", target_capacity)
	inventory.call("load_snapshot", Dictionary(snapshot.get("ingredient_stock", {})))


func _check_requirements(definition: Dictionary) -> Dictionary:
	var required_item: StringName = definition.get("requires_owned", &"")
	if not required_item.is_empty() and not owns(required_item):
		return _failure(&"missing_required_item", {"required_item": required_item})
	var required_equipment: StringName = definition.get("requires_equipment", &"")
	if not required_equipment.is_empty() and not owns_equipment(required_equipment):
		return _failure(&"equipment_not_owned", {"device_id": required_equipment})
	var minimum_day := int(definition.get("min_day", 1))
	if current_day < minimum_day:
		return _failure(&"day_requirement_not_met", {"required_day": minimum_day})
	var minimum_reputation := int(definition.get("min_reputation", 0))
	if reputation < minimum_reputation:
		return _failure(&"reputation_requirement_not_met", {"required_reputation": minimum_reputation})
	var metric_id: StringName = definition.get("metric", &"")
	var metric_value := int(definition.get("metric_value", 0))
	if not metric_id.is_empty() and metric(metric_id) < metric_value:
		return _failure(&"metric_requirement_not_met", {"metric": metric_id, "required_value": metric_value})
	return {}


func _purchase_is_owned(item_id: StringName, definition: Dictionary) -> bool:
	if definition.get("kind", &"") == &"equipment":
		return equipment_tier(definition.get("device_id", &"")) >= int(definition.get("target_tier", -1))
	if definition.get("kind", &"") == &"stall":
		return stall_tier >= int(definition.get("target_tier", 1))
	return owns(item_id)


func _missing_requirement_texts(definition: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var required_item: StringName = definition.get("requires_owned", &"")
	if not required_item.is_empty() and not owns(required_item):
		result.append("先拥有%s" % CATALOG.purchase_presentation(required_item).get("label", str(required_item)))
	var required_equipment: StringName = definition.get("requires_equipment", &"")
	if not required_equipment.is_empty() and not owns_equipment(required_equipment):
		result.append("先解锁%s" % _device_label(required_equipment))
	var kind: StringName = definition.get("kind", &"")
	if kind == &"equipment":
		var device_id: StringName = definition.get("device_id", &"")
		var target_tier := int(definition.get("target_tier", -1))
		if target_tier > equipment_tier(device_id) + 1:
			result.append("先完成上一档设备")
	var minimum_day := int(definition.get("min_day", 1))
	if current_day < minimum_day:
		result.append("第%d天" % minimum_day)
	var minimum_reputation := int(definition.get("min_reputation", 0))
	if reputation < minimum_reputation:
		result.append("声誉%d（当前%d）" % [minimum_reputation, reputation])
	var metric_id: StringName = definition.get("metric", &"")
	var metric_value := int(definition.get("metric_value", 0))
	if not metric_id.is_empty() and metric(metric_id) < metric_value:
		result.append("%s%d（当前%d）" % [_metric_label(metric_id), metric_value, metric(metric_id)])
	return result


func _metric_label(metric_id: StringName) -> String:
	var labels := {
		&"lifetime_orders": "累计完成订单",
		&"average_score": "平均分",
		&"manual_spread_good": "手工摊饼良好次数",
		&"expanded_good": "扩展小料良好次数",
		&"soy_good": "豆浆良好次数",
		&"youtiao_good": "油条良好次数",
		&"egg_waffle_good": "鸡蛋仔良好次数",
		&"soy_youtiao_good": "豆浆与油条良好次数",
		&"all_equipment_good": "三类设备良好次数",
	}
	return str(labels.get(metric_id, str(metric_id)))


func _device_label(device_id: StringName) -> String:
	var labels := {
		CATALOG.DEVICE_SOY_MILK: "豆浆机",
		CATALOG.DEVICE_YOUTIAO: "炸油条机",
		CATALOG.DEVICE_EGG_WAFFLE: "鸡蛋仔机",
	}
	return str(labels.get(device_id, str(device_id)))


func _apply_purchase(item_id: StringName) -> void:
	var definition := CATALOG.purchase_definition(item_id)
	var kind: StringName = definition.get("kind", &"")
	if kind == &"equipment":
		equipment_levels[definition.get("device_id", &"")] = int(definition.get("target_tier", CATALOG.TIER_BASIC))
		return
	owned_items[item_id] = true
	if kind == &"stall":
		stall_tier = int(definition.get("target_tier", 1))
		return
	if kind == &"ingredient_box":
		inventory.call("set_capacity_for_all", int(CATALOG.item_effect(item_id).get("capacity", ingredient_box_capacity())))


func _success(extra: Dictionary = {}) -> Dictionary:
	var result := {"success": true, "reason": &""}
	result.merge(extra, true)
	return result


func _failure(reason: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"success": false, "reason": reason}
	result.merge(extra, true)
	return result
