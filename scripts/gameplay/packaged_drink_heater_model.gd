class_name PackagedDrinkHeaterModel
extends RefCounted

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const DEVICE_ID := &"device.packaged_drink_heater"
const AREA_ID := &"area.packaged_drink"
const MAX_SLOTS := 4
const INPUT_GRACE_SECONDS := 0.3

const STATE_LOCKED := &"locked"
const STATE_EMPTY := &"empty"
const STATE_HEATING := &"heating"
const STATE_READY_HOT := &"ready_hot"
const STATE_COOLED := &"cooled"

var owned := false
var tier := 0
var _slots: Array[Dictionary] = []


func _init(next_tier: int = 0, is_owned: bool = false) -> void:
	_reset_slots()
	if is_owned:
		configure_owned(next_tier)


func configure_owned(next_tier: int) -> Dictionary:
	if CATALOG.device_tier(DEVICE_ID, next_tier).is_empty():
		return _failure(&"invalid_device_tier")
	owned = true
	tier = next_tier
	_refresh_slot_locks()
	return _success({"tier": tier, "capacity": capacity()})


func configure_locked() -> Dictionary:
	owned = false
	tier = 0
	_reset_slots()
	return _success()


func capacity() -> int:
	if not owned:
		return 0
	return int(CATALOG.device_tier(DEVICE_ID, tier).get("capacity", 0))


func load_product(slot_index: int, product_id: StringName) -> Dictionary:
	var validation := _validate_active_slot(slot_index)
	if not bool(validation.get("success", false)):
		return validation
	var slot := _slots[slot_index]
	if slot.get("state", STATE_LOCKED) != STATE_EMPTY:
		return _failure(&"slot_occupied", {"slot_index": slot_index})
	var product := CATALOG.product_definition(product_id)
	if product.is_empty() or product.get("area_id", &"") != AREA_ID or not bool(product.get("can_heat", false)):
		return _failure(&"product_not_heatable", {"product_id": product_id})
	slot = _empty_slot(STATE_HEATING)
	slot["product_id"] = product_id
	_slots[slot_index] = slot
	return _success({"slot_index": slot_index, "product_id": product_id, "state": STATE_HEATING})


func advance_time(delta: float) -> void:
	var step := maxf(delta, 0.0)
	if not owned or step <= 0.0:
		return
	var definition := CATALOG.device_tier(DEVICE_ID, tier)
	var duration := float(definition.get("duration_seconds", 0.0))
	var hot_window := float(definition.get("hot_window_seconds", 0.0))
	var infinite_hold := bool(definition.get("infinite_hold", false))
	for slot_index in range(capacity()):
		var slot := _slots[slot_index]
		var remaining := step
		if slot.get("state", STATE_EMPTY) == STATE_HEATING:
			var until_ready := maxf(duration - float(slot.get("elapsed_seconds", 0.0)), 0.0)
			var applied := minf(remaining, until_ready)
			slot["elapsed_seconds"] = float(slot.get("elapsed_seconds", 0.0)) + applied
			remaining -= applied
			if float(slot.get("elapsed_seconds", 0.0)) + 0.000001 >= duration:
				slot["elapsed_seconds"] = duration
				slot["state"] = STATE_READY_HOT
				slot["hot_elapsed_seconds"] = 0.0
		if slot.get("state", STATE_EMPTY) == STATE_READY_HOT and not infinite_hold and remaining > 0.0:
			slot["hot_elapsed_seconds"] = float(slot.get("hot_elapsed_seconds", 0.0)) + remaining
			if float(slot.get("hot_elapsed_seconds", 0.0)) > hot_window:
				slot["state"] = STATE_COOLED
		_slots[slot_index] = slot


func preview_collect(slot_index: int) -> Dictionary:
	var validation := _validate_active_slot(slot_index)
	if not bool(validation.get("success", false)):
		return validation
	var slot := _slots[slot_index]
	var state: StringName = slot.get("state", STATE_EMPTY)
	if state == STATE_HEATING:
		return _failure(&"drink_still_heating", {"slot_index": slot_index})
	if state != STATE_READY_HOT and state != STATE_COOLED:
		return _failure(&"no_hot_drink", {"slot_index": slot_index})
	var definition := CATALOG.device_tier(DEVICE_ID, tier)
	if state == STATE_COOLED:
		var hot_window := float(definition.get("hot_window_seconds", 0.0))
		if float(slot.get("hot_elapsed_seconds", 0.0)) > hot_window + INPUT_GRACE_SECONDS:
			return _failure(&"drink_cooled", {"slot_index": slot_index})
	return _success({
		"slot_index": slot_index,
		"product_id": slot.get("product_id", &""),
		"temperature_mode": &"heated",
		"quality": 100.0,
		"grade": &"A",
	})


func collect(slot_index: int) -> Dictionary:
	var preview := preview_collect(slot_index)
	if not bool(preview.get("success", false)):
		return preview
	_slots[slot_index] = _empty_slot(STATE_EMPTY)
	return preview


func reheat(slot_index: int) -> Dictionary:
	var validation := _validate_active_slot(slot_index)
	if not bool(validation.get("success", false)):
		return validation
	var slot := _slots[slot_index]
	if slot.get("state", STATE_EMPTY) != STATE_COOLED:
		return _failure(&"reheat_not_available", {"slot_index": slot_index})
	var product_id := StringName(slot.get("product_id", &""))
	slot = _empty_slot(STATE_HEATING)
	slot["product_id"] = product_id
	_slots[slot_index] = slot
	return _success({"slot_index": slot_index, "product_id": product_id, "state": STATE_HEATING})


func discard(slot_index: int) -> Dictionary:
	var validation := _validate_active_slot(slot_index)
	if not bool(validation.get("success", false)):
		return validation
	var slot := _slots[slot_index]
	if slot.get("state", STATE_EMPTY) != STATE_COOLED:
		return _failure(&"discard_not_available", {"slot_index": slot_index})
	var product_id: StringName = slot.get("product_id", &"")
	_slots[slot_index] = _empty_slot(STATE_EMPTY)
	return _success({"slot_index": slot_index, "product_id": product_id, "waste_reason": &"cooled_drink"})


func slot_snapshot(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return {}
	return _snapshot_slot(_slots[slot_index])


func snapshot() -> Dictionary:
	var visible_slots: Array[Dictionary] = []
	for slot in _slots:
		visible_slots.append(_snapshot_slot(slot))
	return {
		"device_id": DEVICE_ID,
		"owned": owned,
		"tier": tier,
		"capacity": capacity(),
		"slots": visible_slots,
	}


func _snapshot_slot(source: Dictionary) -> Dictionary:
	var result := source.duplicate(true)
	var definition := CATALOG.device_tier(DEVICE_ID, tier) if owned else {}
	var infinite_hold := bool(definition.get("infinite_hold", false))
	var hot_window := float(definition.get("hot_window_seconds", 0.0))
	result["infinite_hold"] = infinite_hold
	result["hot_remaining_seconds"] = 0.0
	if StringName(result.get("state", STATE_LOCKED)) == STATE_READY_HOT:
		result["hot_remaining_seconds"] = 0.0 if infinite_hold else maxf(hot_window - float(result.get("hot_elapsed_seconds", 0.0)), 0.0)
	return result


func load_snapshot(value: Dictionary) -> Dictionary:
	_reset_slots()
	if value.is_empty() or not bool(value.get("owned", false)):
		return _success()
	var configured := configure_owned(int(value.get("tier", 0)))
	if not bool(configured.get("success", false)):
		return configured
	var saved_slots: Array = Array(value.get("slots", []))
	for slot_index in range(mini(saved_slots.size(), MAX_SLOTS)):
		if slot_index >= capacity():
			break
		var source := Dictionary(saved_slots[slot_index])
		var state := StringName(source.get("state", STATE_EMPTY))
		if state not in [STATE_EMPTY, STATE_HEATING, STATE_READY_HOT, STATE_COOLED]:
			state = STATE_EMPTY
		var restored := _empty_slot(state)
		restored["product_id"] = StringName(source.get("product_id", &""))
		restored["elapsed_seconds"] = maxf(float(source.get("elapsed_seconds", 0.0)), 0.0)
		restored["hot_elapsed_seconds"] = maxf(float(source.get("hot_elapsed_seconds", 0.0)), 0.0)
		if state != STATE_EMPTY and CATALOG.product_definition(restored["product_id"]).is_empty():
			restored = _empty_slot(STATE_EMPTY)
		_slots[slot_index] = restored
	_refresh_slot_locks()
	return _success()


func _validate_active_slot(slot_index: int) -> Dictionary:
	if not owned:
		return _failure(&"equipment_not_owned")
	if slot_index < 0 or slot_index >= capacity():
		return _failure(&"slot_locked", {"slot_index": slot_index, "capacity": capacity()})
	return _success()


func _reset_slots() -> void:
	_slots.clear()
	for _slot_index in range(MAX_SLOTS):
		_slots.append(_empty_slot(STATE_LOCKED))


func _refresh_slot_locks() -> void:
	for slot_index in range(MAX_SLOTS):
		if slot_index < capacity():
			if _slots[slot_index].get("state", STATE_LOCKED) == STATE_LOCKED:
				_slots[slot_index] = _empty_slot(STATE_EMPTY)
		elif _slots[slot_index].get("state", STATE_LOCKED) != STATE_LOCKED:
			_slots[slot_index] = _empty_slot(STATE_LOCKED)


static func _empty_slot(state: StringName) -> Dictionary:
	return {"state": state, "product_id": &"", "elapsed_seconds": 0.0, "hot_elapsed_seconds": 0.0}


static func _success(extra: Dictionary = {}) -> Dictionary:
	var result := {"success": true, "reason": &""}
	result.merge(extra, true)
	return result


static func _failure(reason: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"success": false, "reason": reason}
	result.merge(extra, true)
	return result
