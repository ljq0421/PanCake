class_name PancakeHoldingTrayModel
extends RefCounted

signal changed(snapshot: Dictionary)

const SLOT_COUNT := 2
const AGING_SECONDS := 20.0
const EXPIRED_SECONDS := 60.0

var _slots: Array[Dictionary] = [{}, {}]


func _init(snapshot: Dictionary = {}) -> void:
	load_snapshot(snapshot)


func snapshot() -> Dictionary:
	var slots: Array[Dictionary] = []
	for slot in _slots:
		slots.append(slot.duplicate(true))
	return {"slot_count": SLOT_COUNT, "slots": slots}


func load_snapshot(value: Dictionary) -> void:
	_slots = [{}, {}]
	var source_slots: Array = Array(value.get("slots", []))
	for index in mini(source_slots.size(), SLOT_COUNT):
		var candidate := Dictionary(source_slots[index]).duplicate(true)
		if _is_valid_product(candidate):
			candidate["age_seconds"] = clampf(float(candidate.get("age_seconds", 0.0)), 0.0, EXPIRED_SECONDS)
			_slots[index] = candidate


func slot_snapshot(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return {}
	return _slot_presentation(_slots[slot_index])


func store(product_snapshot: Dictionary) -> Dictionary:
	if not _is_valid_product(product_snapshot):
		return {"success": false, "reason": &"invalid_product_snapshot"}
	for slot in _slots:
		if StringName(slot.get("product_instance_id", &"")) == StringName(product_snapshot.get("product_instance_id", &"")):
			return {"success": false, "reason": &"duplicate_product_instance"}
	for index in SLOT_COUNT:
		if _slots[index].is_empty():
			var stored := product_snapshot.duplicate(true)
			stored["age_seconds"] = 0.0
			_slots[index] = stored
			_emit_changed()
			return {"success": true, "slot_index": index, "product": _slot_presentation(stored)}
	return {"success": false, "reason": &"capacity_full"}


func advance_time(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	if is_zero_approx(safe_delta):
		return
	var changed_any := false
	for index in SLOT_COUNT:
		if _slots[index].is_empty():
			continue
		var old_age := float(_slots[index].get("age_seconds", 0.0))
		_slots[index]["age_seconds"] = minf(old_age + safe_delta, EXPIRED_SECONDS)
		changed_any = true
	if changed_any:
		_emit_changed()


func preview_serve_matching(slot_index: int, order: Dictionary) -> Dictionary:
	if slot_index < 0 or slot_index >= SLOT_COUNT or _slots[slot_index].is_empty():
		return {"success": false, "reason": &"empty_slot"}
	var product := _slots[slot_index]
	if float(product.get("age_seconds", 0.0)) >= EXPIRED_SECONDS:
		return {"success": false, "reason": &"product_expired"}
	var mismatch_reasons := _mismatch_reasons(product, order)
	if not mismatch_reasons.is_empty():
		return {"success": false, "reason": &"product_mismatch", "mismatch_reasons": mismatch_reasons}
	var penalty := freshness_penalty(float(product.get("age_seconds", 0.0)))
	var final_score := maxf(float(product.get("score", 0.0)) - penalty, 0.0)
	return {"success": true, "slot_index": slot_index, "product": _slot_presentation(product), "freshness_penalty": penalty, "final_score": final_score, "grade": grade_for_score(final_score)}


func serve_matching(slot_index: int, order: Dictionary) -> Dictionary:
	var preview := preview_serve_matching(slot_index, order)
	if not bool(preview.get("success", false)):
		return preview
	_slots[slot_index] = {}
	_emit_changed()
	preview["served_product"] = preview.get("product", {}).duplicate(true)
	return preview


func discard(slot_index: int, reason: StringName = &"discarded") -> Dictionary:
	if slot_index < 0 or slot_index >= SLOT_COUNT or _slots[slot_index].is_empty():
		return {"success": false, "reason": &"empty_slot"}
	var discarded := _slot_presentation(_slots[slot_index])
	_slots[slot_index] = {}
	_emit_changed()
	return {"success": true, "waste": {"reason": reason, "product": discarded}}


func clear_for_day_end() -> Array[Dictionary]:
	var waste: Array[Dictionary] = []
	for index in SLOT_COUNT:
		if _slots[index].is_empty():
			continue
		waste.append({"reason": &"day_end_clear", "product": _slot_presentation(_slots[index])})
		_slots[index] = {}
	if not waste.is_empty():
		_emit_changed()
	return waste


static func freshness_penalty(age_seconds: float) -> float:
	if age_seconds <= AGING_SECONDS:
		return 0.0
	return clampf((age_seconds - AGING_SECONDS) / (EXPIRED_SECONDS - AGING_SECONDS) * 20.0, 0.0, 20.0)


static func grade_for_score(score: float) -> StringName:
	if score >= 85.0:
		return &"A"
	if score >= 70.0:
		return &"B"
	if score >= 60.0:
		return &"C"
	return &"D"


func _mismatch_reasons(product: Dictionary, order: Dictionary) -> PackedStringArray:
	var reasons := PackedStringArray()
	if StringName(product.get("product_id", &"")) != StringName(order.get("product_id", &"product.pancake.custom")):
		reasons.append("product_id")
	if StringName(product.get("heat_preference", &"")) != StringName(order.get("heat_preference", &"")):
		reasons.append("heat_preference")
	if not _same_id_set(product.get("ingredient_ids", []), order.get("ingredient_ids", [])):
		reasons.append("ingredient_ids")
	if not _same_id_set(product.get("sauce_ids", []), order.get("sauce_ids", [])):
		reasons.append("sauce_ids")
	return reasons


static func _same_id_set(left: Variant, right: Variant) -> bool:
	var left_ids := PackedStringArray()
	var right_ids := PackedStringArray()
	for value in Array(left):
		left_ids.append(str(value))
	for value in Array(right):
		right_ids.append(str(value))
	left_ids.sort()
	right_ids.sort()
	return left_ids == right_ids


static func _is_valid_product(product: Dictionary) -> bool:
	return StringName(product.get("product_instance_id", &"")).is_empty() == false and StringName(product.get("product_id", &"")) == &"product.pancake.custom"


func _slot_presentation(slot: Dictionary) -> Dictionary:
	if slot.is_empty():
		return {"state": &"empty"}
	var result := slot.duplicate(true)
	var age := float(result.get("age_seconds", 0.0))
	result["state"] = &"fresh" if age < AGING_SECONDS else (&"aging" if age < EXPIRED_SECONDS else &"expired")
	result["freshness_penalty"] = freshness_penalty(age)
	return result


func _emit_changed() -> void:
	changed.emit(snapshot())
