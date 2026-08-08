class_name FiveAreaStationView
extends PanelContainer

signal intent_requested(intent: Dictionary)

var _snapshot: Dictionary = {}
var _locked := true
var _interaction_enabled := true


func apply_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	_refresh_from_snapshot()


func set_locked(locked: bool) -> void:
	_locked = locked
	_refresh_from_snapshot()


func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	_refresh_from_snapshot()


func request_intent(action_id: StringName, payload: Dictionary = {}) -> void:
	if _locked or not _interaction_enabled:
		return
	var intent := payload.duplicate(true)
	intent["action_id"] = action_id
	intent_requested.emit(intent)


func _refresh_from_snapshot() -> void:
	pass
