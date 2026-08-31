class_name PlaytestTelemetry
extends RefCounted

## Local, opt-in playtest telemetry. It records gameplay identifiers and
## numerical outcomes only; no account, machine, input text, or network data is
## collected. Each event is flushed immediately so a forced exit keeps evidence.

const SCHEMA_VERSION := 1
const DEFAULT_ROOT := "user://playtest-results"

var _enabled := false
var _session_id := ""
var _output_directory := ""
var _events_path := ""
var _summary_path := ""
var _events_file: FileAccess
var _started_unix := 0
var _started_usec := 0
var _sequence := 0
var _summary: Dictionary = {}


func configure_from_args(args: PackedStringArray, metadata: Dictionary = {}) -> Dictionary:
	var enabled := false
	var output := ""
	var label := ""
	for value in args:
		var argument := str(value)
		if argument == "--playtest-telemetry":
			enabled = true
		elif argument.begins_with("--playtest-output="):
			output = argument.trim_prefix("--playtest-output=")
		elif argument.begins_with("--playtest-session="):
			label = argument.trim_prefix("--playtest-session=")
	if not enabled:
		return {"success": true, "enabled": false}
	return start_session(output, label, metadata)


func start_session(output_directory: String = "", label: String = "", metadata: Dictionary = {}) -> Dictionary:
	if _enabled:
		return {"success": false, "reason": &"session_already_started", "output_directory": _output_directory}
	_started_unix = int(Time.get_unix_time_from_system())
	_started_usec = Time.get_ticks_usec()
	_session_id = _session_identifier(label)
	var requested_directory := output_directory.strip_edges()
	if requested_directory.is_empty():
		requested_directory = DEFAULT_ROOT.path_join(_session_id)
	_output_directory = _absolute_path(requested_directory)
	var directory_error := DirAccess.make_dir_recursive_absolute(_output_directory)
	if directory_error != OK:
		return {"success": false, "reason": &"cannot_create_output_directory", "error": directory_error, "output_directory": _output_directory}
	_events_path = _output_directory.path_join("events.jsonl")
	_summary_path = _output_directory.path_join("summary.json")
	_events_file = FileAccess.open(_events_path, FileAccess.WRITE)
	if _events_file == null:
		return {"success": false, "reason": &"cannot_open_event_log", "error": FileAccess.get_open_error(), "events_path": _events_path}
	_summary = {
		"schema_version": SCHEMA_VERSION,
		"session_id": _session_id,
		"started_at_unix": _started_unix,
		"ended_at_unix": 0,
		"event_count": 0,
		"events_by_kind": {},
		"chapters": {},
		"metadata": _json_safe(metadata),
	}
	_enabled = true
	record(&"session_started", metadata)
	return status()


func is_enabled() -> bool:
	return _enabled


func status() -> Dictionary:
	return {
		"success": true,
		"enabled": _enabled,
		"session_id": _session_id,
		"output_directory": _output_directory,
		"events_path": _events_path,
		"summary_path": _summary_path,
		"event_count": _sequence,
	}


func record(kind: StringName, payload: Dictionary = {}) -> Dictionary:
	if not _enabled or _events_file == null:
		return {"success": false, "reason": &"telemetry_disabled"}
	var safe_payload := Dictionary(_json_safe(payload))
	var event := {
		"schema_version": SCHEMA_VERSION,
		"sequence": _sequence,
		"kind": str(kind),
		"unix_time": int(Time.get_unix_time_from_system()),
		"elapsed_seconds": maxf(float(Time.get_ticks_usec() - _started_usec) / 1000000.0, 0.0),
		"payload": safe_payload,
	}
	_events_file.store_line(JSON.stringify(event, "", true))
	_events_file.flush()
	_sequence += 1
	_update_summary(kind, safe_payload)
	_write_summary()
	return {"success": true, "sequence": int(event.get("sequence", 0)), "event": event}


func finish(final_metadata: Dictionary = {}) -> Dictionary:
	if not _enabled:
		return status()
	record(&"session_finished", final_metadata)
	_summary["ended_at_unix"] = int(Time.get_unix_time_from_system())
	_summary["duration_seconds"] = maxf(float(Time.get_ticks_usec() - _started_usec) / 1000000.0, 0.0)
	_write_summary()
	if _events_file != null:
		_events_file.close()
		_events_file = null
	_enabled = false
	return status()


func _update_summary(kind: StringName, payload: Dictionary) -> void:
	_summary["event_count"] = _sequence
	var counts := Dictionary(_summary.get("events_by_kind", {})).duplicate(true)
	counts[str(kind)] = int(counts.get(str(kind), 0)) + 1
	_summary["events_by_kind"] = counts
	var chapter_id := str(payload.get("chapter_id", ""))
	if chapter_id.is_empty():
		return
	var chapters := Dictionary(_summary.get("chapters", {})).duplicate(true)
	var chapter := Dictionary(chapters.get(chapter_id, {
		"orders_settled": 0,
		"orders_succeeded": 0,
		"orders_failed": 0,
		"special_orders": 0,
		"score_total": 0.0,
		"scored_orders": 0,
		"average_score": 0.0,
		"payment_coins": 0,
		"reputation_delta": 0,
		"days_ended": 0,
		"growth_purchases": 0,
		"refusals": 0,
		"abandonments": 0,
	})).duplicate(true)
	match kind:
		&"order_settled":
			chapter["orders_settled"] = int(chapter.get("orders_settled", 0)) + 1
			var succeeded := bool(payload.get("success", false))
			var outcome_key := "orders_succeeded" if succeeded else "orders_failed"
			chapter[outcome_key] = int(chapter.get(outcome_key, 0)) + 1
			if not str(payload.get("special_customer_id", "")).is_empty():
				chapter["special_orders"] = int(chapter.get("special_orders", 0)) + 1
			if payload.has("overall_score"):
				chapter["score_total"] = float(chapter.get("score_total", 0.0)) + float(payload.get("overall_score", 0.0))
				chapter["scored_orders"] = int(chapter.get("scored_orders", 0)) + 1
			chapter["payment_coins"] = int(chapter.get("payment_coins", 0)) + int(payload.get("payment_coins", 0))
			chapter["reputation_delta"] = int(chapter.get("reputation_delta", 0)) + int(payload.get("reputation_delta", 0))
		&"day_ended":
			chapter["days_ended"] = int(chapter.get("days_ended", 0)) + 1
		&"growth_purchased":
			if bool(payload.get("success", false)):
				chapter["growth_purchases"] = int(chapter.get("growth_purchases", 0)) + 1
		&"order_refused":
			chapter["refusals"] = int(chapter.get("refusals", 0)) + 1
		&"order_abandoned":
			chapter["abandonments"] = int(chapter.get("abandonments", 0)) + 1
	var scored_orders := int(chapter.get("scored_orders", 0))
	chapter["average_score"] = float(chapter.get("score_total", 0.0)) / float(scored_orders) if scored_orders > 0 else 0.0
	chapter["last_day"] = int(payload.get("day", chapter.get("last_day", 0)))
	chapter["last_coins"] = int(payload.get("coins", chapter.get("last_coins", 0)))
	chapter["last_global_reputation"] = int(payload.get("global_reputation", chapter.get("last_global_reputation", 0)))
	chapter["last_owned_growth_count"] = int(payload.get("owned_growth_count", chapter.get("last_owned_growth_count", 0)))
	chapters[chapter_id] = chapter
	_summary["chapters"] = chapters


func _write_summary() -> void:
	var file := FileAccess.open(_summary_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_summary, "\t", true))
	file.close()


static func _absolute_path(path: String) -> String:
	if path.begins_with("user://") or path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)
	return path.simplify_path()


static func _session_identifier(label: String) -> String:
	var timestamp := Time.get_datetime_string_from_system(false, false).replace(":", "").replace("-", "")
	var clean_label := ""
	for character in label.strip_edges():
		if character.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789_-":
			clean_label += character
	if clean_label.is_empty():
		return timestamp
	return "%s_%s" % [timestamp, clean_label.left(40)]


static func _json_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var safe_dictionary := {}
			for key in Dictionary(value).keys():
				safe_dictionary[str(key)] = _json_safe(Dictionary(value)[key])
			return safe_dictionary
		TYPE_ARRAY:
			var safe_array := []
			for item in Array(value):
				safe_array.append(_json_safe(item))
			return safe_array
		TYPE_PACKED_STRING_ARRAY:
			return Array(value).map(func(item): return str(item))
		TYPE_STRING_NAME:
			return str(value)
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return {"x": value.x, "y": value.y}
		TYPE_VECTOR3, TYPE_VECTOR3I:
			return {"x": value.x, "y": value.y, "z": value.z}
	return value
