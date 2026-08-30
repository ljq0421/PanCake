class_name NightMarketProductionModel
extends RefCounted

const CATALOG := preload("res://scripts/data/night_market_catalog.gd")
const GRILL_SLOT_COUNT := 6
const FRYER_POWER_SETPOINTS := {
	&"low": 160.0,
	&"standard": 178.0,
	&"high": 195.0,
}

var grill_slots: Array = []
var fryer: Dictionary = {}
var fryer_power := &"standard"
var oil_temperature := 170.0
var plate_items: Array = []
var elapsed_seconds := 0.0


func _init(source: Dictionary = {}) -> void:
	_reset_grill()
	_reset_fryer()
	if not source.is_empty():
		load_snapshot(source)


func _reset_grill() -> void:
	grill_slots.clear()
	for _index in GRILL_SLOT_COUNT:
		grill_slots.append({})


func _reset_fryer() -> void:
	fryer = {
		"item_id": &"",
		"count": 0,
		"state": &"raised",
		"cook_seconds": 0.0,
		"temperature_total": 0.0,
		"temperature_seconds": 0.0,
		"low_temp_seconds": 0.0,
		"high_temp_seconds": 0.0,
		"drain_seconds": 0.0,
		"reimmersions": 0,
	}


func snapshot() -> Dictionary:
	return {
		"version": 1,
		"grill_slots": grill_slots.duplicate(true),
		"fryer": fryer.duplicate(true),
		"fryer_power": fryer_power,
		"oil_temperature": oil_temperature,
		"plate_items": plate_items.duplicate(true),
		"elapsed_seconds": elapsed_seconds,
	}


func load_snapshot(source: Dictionary) -> Dictionary:
	_reset_grill()
	var restored_slots := Array(source.get("grill_slots", []))
	for index in mini(restored_slots.size(), GRILL_SLOT_COUNT):
		var restored := Dictionary(restored_slots[index]).duplicate(true)
		if not restored.is_empty() and CATALOG.item(StringName(restored.get("item_id", &""))).get("line", &"") == CATALOG.LINE_GRILL:
			restored["item_id"] = StringName(restored.get("item_id", &""))
			restored["zone_id"] = CATALOG.zone_for_slot(index)
			restored["side"] = StringName(restored.get("side", &"front"))
			grill_slots[index] = restored
	_reset_fryer()
	var restored_fryer := Dictionary(source.get("fryer", {}))
	for key in fryer.keys():
		if restored_fryer.has(key):
			fryer[key] = restored_fryer[key]
	fryer["item_id"] = StringName(fryer.get("item_id", &""))
	fryer["state"] = StringName(fryer.get("state", &"raised"))
	fryer_power = StringName(source.get("fryer_power", &"standard"))
	if not FRYER_POWER_SETPOINTS.has(fryer_power):
		fryer_power = &"standard"
	oil_temperature = clampf(float(source.get("oil_temperature", 170.0)), 20.0, 240.0)
	plate_items.clear()
	for value in Array(source.get("plate_items", [])):
		var item := Dictionary(value).duplicate(true)
		item["item_id"] = StringName(item.get("item_id", &""))
		item["line"] = StringName(item.get("line", &""))
		item["seasoning_id"] = StringName(item.get("seasoning_id", &""))
		plate_items.append(item)
	elapsed_seconds = maxf(float(source.get("elapsed_seconds", 0.0)), 0.0)
	return {"success": true, "snapshot": snapshot()}


func advance(delta: float, thermostat: bool = false) -> Dictionary:
	var step := maxf(delta, 0.0)
	if is_zero_approx(step):
		return {"success": true, "changed": false}
	elapsed_seconds += step
	var target := float(FRYER_POWER_SETPOINTS.get(fryer_power, 178.0))
	var approach_rate := 28.0 if thermostat else 14.0
	oil_temperature = move_toward(oil_temperature, target, approach_rate * step)
	for index in grill_slots.size():
		var skewer := Dictionary(grill_slots[index])
		if skewer.is_empty():
			continue
		var side := StringName(skewer.get("side", &"front"))
		var key := "front_heat" if side == &"front" else "back_heat"
		var zone := StringName(skewer.get("zone_id", CATALOG.zone_for_slot(index)))
		skewer[key] = float(skewer.get(key, 0.0)) + float(CATALOG.HEAT_RATES.get(zone, 7.0)) * step
		skewer["total_seconds"] = float(skewer.get("total_seconds", 0.0)) + step
		grill_slots[index] = skewer
	if StringName(fryer.get("state", &"raised")) == &"cooking":
		var cook_factor := 0.62 if oil_temperature < 160.0 else 1.22 if oil_temperature > 190.0 else 1.0
		fryer["cook_seconds"] = float(fryer.get("cook_seconds", 0.0)) + step * cook_factor
		fryer["temperature_total"] = float(fryer.get("temperature_total", 0.0)) + oil_temperature * step
		fryer["temperature_seconds"] = float(fryer.get("temperature_seconds", 0.0)) + step
		if oil_temperature < 160.0:
			fryer["low_temp_seconds"] = float(fryer.get("low_temp_seconds", 0.0)) + step
		elif oil_temperature > 190.0:
			fryer["high_temp_seconds"] = float(fryer.get("high_temp_seconds", 0.0)) + step
	elif StringName(fryer.get("state", &"raised")) == &"draining":
		fryer["drain_seconds"] = float(fryer.get("drain_seconds", 0.0)) + step
	return {"success": true, "changed": true, "snapshot": snapshot()}


func add_grill_skewer(item_id: StringName, zone_id: StringName) -> Dictionary:
	var definition := CATALOG.item(item_id)
	if StringName(definition.get("line", &"")) != CATALOG.LINE_GRILL:
		return {"success": false, "reason": &"not_grill_item"}
	var slot_indices := Array(CATALOG.ZONE_SLOT_INDICES.get(zone_id, []))
	for raw_index in slot_indices:
		var index := int(raw_index)
		if Dictionary(grill_slots[index]).is_empty():
			grill_slots[index] = {
				"item_id": item_id,
				"zone_id": zone_id,
				"side": &"front",
				"front_heat": 0.0,
				"back_heat": 0.0,
				"total_seconds": 0.0,
				"reheated": false,
			}
			return {"success": true, "slot_index": index, "skewer": Dictionary(grill_slots[index]).duplicate(true)}
	return {"success": false, "reason": &"grill_zone_full", "zone_id": zone_id}


func flip_grill_slot(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= grill_slots.size() or Dictionary(grill_slots[slot_index]).is_empty():
		return {"success": false, "reason": &"empty_grill_slot"}
	var skewer := Dictionary(grill_slots[slot_index])
	skewer["side"] = &"back" if StringName(skewer.get("side", &"front")) == &"front" else &"front"
	grill_slots[slot_index] = skewer
	return {"success": true, "slot_index": slot_index, "side": skewer["side"]}


func plate_grill_slot(slot_index: int) -> Dictionary:
	if plate_items.size() >= 2:
		return {"success": false, "reason": &"plate_full"}
	if slot_index < 0 or slot_index >= grill_slots.size() or Dictionary(grill_slots[slot_index]).is_empty():
		return {"success": false, "reason": &"empty_grill_slot"}
	var skewer := Dictionary(grill_slots[slot_index]).duplicate(true)
	var plated := {
		"item_id": StringName(skewer.get("item_id", &"")),
		"line": CATALOG.LINE_GRILL,
		"front_heat": float(skewer.get("front_heat", 0.0)),
		"back_heat": float(skewer.get("back_heat", 0.0)),
		"zone_id": StringName(skewer.get("zone_id", &"medium")),
		"total_seconds": float(skewer.get("total_seconds", 0.0)),
		"reheated": bool(skewer.get("reheated", false)),
		"seasoning_id": &"",
	}
	plate_items.append(plated)
	grill_slots[slot_index] = {}
	return {"success": true, "plate_index": plate_items.size() - 1, "item": plated.duplicate(true)}


func add_fryer_item(item_id: StringName) -> Dictionary:
	var definition := CATALOG.item(item_id)
	if StringName(definition.get("line", &"")) != CATALOG.LINE_FRYER:
		return {"success": false, "reason": &"not_fryer_item"}
	if StringName(fryer.get("state", &"raised")) != &"raised":
		return {"success": false, "reason": &"fryer_basket_not_raised"}
	var existing := StringName(fryer.get("item_id", &""))
	if not existing.is_empty() and existing != item_id:
		return {"success": false, "reason": &"mixed_fryer_batch"}
	if int(fryer.get("count", 0)) >= 2:
		return {"success": false, "reason": &"fryer_basket_full"}
	fryer["item_id"] = item_id
	fryer["count"] = int(fryer.get("count", 0)) + 1
	return {"success": true, "count": int(fryer["count"]), "item_id": item_id}


func set_fryer_power(power_id: StringName) -> Dictionary:
	if not FRYER_POWER_SETPOINTS.has(power_id):
		return {"success": false, "reason": &"unknown_fryer_power"}
	fryer_power = power_id
	return {"success": true, "power_id": fryer_power, "setpoint": FRYER_POWER_SETPOINTS[fryer_power]}


func lower_fryer() -> Dictionary:
	var state := StringName(fryer.get("state", &"raised"))
	if int(fryer.get("count", 0)) <= 0:
		return {"success": false, "reason": &"empty_fryer_basket"}
	if state == &"cooking":
		return {"success": false, "reason": &"fryer_already_lowered"}
	if state == &"draining":
		if int(fryer.get("reimmersions", 0)) >= 1:
			return {"success": false, "reason": &"fryer_reimmersion_used"}
		fryer["reimmersions"] = int(fryer.get("reimmersions", 0)) + 1
		fryer["drain_seconds"] = 0.0
	fryer["state"] = &"cooking"
	return {"success": true, "state": &"cooking"}


func lift_fryer() -> Dictionary:
	if StringName(fryer.get("state", &"raised")) != &"cooking":
		return {"success": false, "reason": &"fryer_not_cooking"}
	fryer["state"] = &"draining"
	fryer["drain_seconds"] = 0.0
	return {"success": true, "state": &"draining"}


func plate_fryer() -> Dictionary:
	if plate_items.size() >= 2:
		return {"success": false, "reason": &"plate_full"}
	if StringName(fryer.get("state", &"raised")) != &"draining" or int(fryer.get("count", 0)) <= 0:
		return {"success": false, "reason": &"fryer_not_draining"}
	var temperature_seconds := maxf(float(fryer.get("temperature_seconds", 0.0)), 0.001)
	var plated := {
		"item_id": StringName(fryer.get("item_id", &"")),
		"line": CATALOG.LINE_FRYER,
		"cook_seconds": float(fryer.get("cook_seconds", 0.0)),
		"average_temperature": float(fryer.get("temperature_total", 0.0)) / temperature_seconds,
		"low_temp_seconds": float(fryer.get("low_temp_seconds", 0.0)),
		"high_temp_seconds": float(fryer.get("high_temp_seconds", 0.0)),
		"drain_seconds": float(fryer.get("drain_seconds", 0.0)),
		"reimmersed": int(fryer.get("reimmersions", 0)) > 0,
		"total_seconds": float(fryer.get("cook_seconds", 0.0)) + float(fryer.get("drain_seconds", 0.0)),
		"seasoning_id": &"",
	}
	plate_items.append(plated)
	_reset_fryer()
	return {"success": true, "plate_index": plate_items.size() - 1, "item": plated.duplicate(true)}


func season_last_unseasoned(seasoning_id: StringName) -> Dictionary:
	for reverse_index in range(plate_items.size() - 1, -1, -1):
		var plated := Dictionary(plate_items[reverse_index])
		if StringName(plated.get("seasoning_id", &"")).is_empty():
			plated["seasoning_id"] = seasoning_id
			plate_items[reverse_index] = plated
			return {"success": true, "plate_index": reverse_index, "item": plated.duplicate(true)}
	return {"success": false, "reason": &"no_unseasoned_item"}


func has_production() -> bool:
	if not plate_items.is_empty() or int(fryer.get("count", 0)) > 0:
		return true
	for value in grill_slots:
		if not Dictionary(value).is_empty():
			return true
	return false


func discard_all() -> Dictionary:
	var discarded := snapshot()
	_reset_grill()
	_reset_fryer()
	plate_items.clear()
	elapsed_seconds = 0.0
	return {"success": true, "discarded": discarded}
