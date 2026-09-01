class_name BusinessReportService
extends RefCounted

signal ledger_changed(snapshot: Dictionary)

const EVENT_KINDS := [
	&"sale", &"stock_cost", &"waste", &"order_failure", &"refusal",
	&"reputation", &"mastery",
]

var _day := 1
var _events: Array[Dictionary] = []
var _event_ids: Dictionary = {}
var _closed := false


func _init(initial_snapshot: Dictionary = {}) -> void:
	if not initial_snapshot.is_empty():
		load_snapshot(initial_snapshot)


func begin_day(day: int) -> void:
	_day = maxi(day, 1)
	_events.clear()
	_event_ids.clear()
	_closed = false
	ledger_changed.emit(snapshot())


func record_event(event: Dictionary) -> Dictionary:
	if _closed:
		return {"success": false, "reason": &"ledger_closed"}
	var normalized := _normalize_event(event)
	if normalized.is_empty():
		return {"success": false, "reason": &"invalid_ledger_event"}
	var event_id := StringName(normalized.get("event_id", &""))
	if _event_ids.has(event_id):
		return {"success": true, "changed": false, "reason": &"already_recorded", "event_id": event_id}
	_event_ids[event_id] = true
	_events.append(normalized)
	ledger_changed.emit(snapshot())
	return {"success": true, "changed": true, "event": normalized.duplicate(true)}


func build_bill() -> Dictionary:
	var revenue := 0
	var cash_cost := 0
	var reputation_delta := 0
	var waste_cost := 0
	var waste_by_area := {}
	var order_states := {}
	var mastery_by_area := {}
	for event in _events:
		var kind := StringName(event.get("kind", &""))
		var area_key := str(event.get("area_id", &""))
		var coins_delta := int(event.get("coins_delta", 0))
		var details := Dictionary(event.get("details", {}))
		if kind == &"sale":
			revenue += maxi(coins_delta, 0)
			var terminal_state := str(details.get("terminal_state", "completed"))
			order_states[terminal_state] = int(order_states.get(terminal_state, 0)) + 1
		elif kind == &"stock_cost" or bool(details.get("counts_cash_cost", false)):
			# Replenishment is an operating cost even though it no longer removes
			# spendable coins immediately.  Keep the legacy coins_delta fallback so
			# previously saved ledger entries remain reportable.
			cash_cost += maxi(int(details.get("operating_cost", -coins_delta)), 0)
		elif kind == &"waste":
			var attributed_cost := maxi(int(details.get("attributed_cost", 0)), 0)
			waste_cost += attributed_cost
			waste_by_area[area_key] = int(waste_by_area.get(area_key, 0)) + attributed_cost
		elif kind == &"order_failure" or kind == &"refusal":
			var state := str(details.get("terminal_state", kind))
			order_states[state] = int(order_states.get(state, 0)) + 1
		elif kind == &"mastery":
			mastery_by_area[area_key] = int(mastery_by_area.get(area_key, 0)) + int(details.get("delta", 0))
		reputation_delta += int(event.get("reputation_delta", 0))
	return {
		"day": _day,
		"closed": _closed,
		"event_count": _events.size(),
		"revenue": revenue,
		"cash_cost": cash_cost,
		"net_profit": revenue - cash_cost,
		"reputation_delta": reputation_delta,
		"waste_cost": waste_cost,
		"waste_by_area": waste_by_area,
		"order_states": order_states,
		"mastery_by_area": mastery_by_area,
		"events": _events.duplicate(true),
	}


func snapshot() -> Dictionary:
	return {"version": 1, "day": _day, "closed": _closed, "events": _events.duplicate(true)}


func load_snapshot(value: Dictionary) -> Dictionary:
	_day = maxi(int(value.get("day", 1)), 1)
	_closed = bool(value.get("closed", false))
	_events.clear()
	_event_ids.clear()
	for raw_event in Array(value.get("events", [])):
		var normalized := _normalize_event(Dictionary(raw_event))
		if normalized.is_empty():
			continue
		var event_id := StringName(normalized.get("event_id", &""))
		if _event_ids.has(event_id):
			continue
		_event_ids[event_id] = true
		_events.append(normalized)
	return {"success": true, "event_count": _events.size()}


func close_day() -> Dictionary:
	_closed = true
	var bill := build_bill()
	ledger_changed.emit(snapshot())
	return bill


static func _normalize_event(source: Dictionary) -> Dictionary:
	var event_id := StringName(source.get("event_id", &""))
	var kind := StringName(source.get("kind", &""))
	if event_id.is_empty() or not EVENT_KINDS.has(kind):
		return {}
	return {
		"event_id": event_id,
		"kind": kind,
		"area_id": StringName(source.get("area_id", &"")),
		"source_id": StringName(source.get("source_id", &"")),
		"quantity": maxi(int(source.get("quantity", 0)), 0),
		"coins_delta": int(source.get("coins_delta", 0)),
		"reputation_delta": int(source.get("reputation_delta", 0)),
		"details": Dictionary(source.get("details", {})).duplicate(true),
	}
