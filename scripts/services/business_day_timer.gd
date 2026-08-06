class_name BusinessDayTimer
extends RefCounted

## Business time advances only while the workstation scene is running.  It is
## deliberately not derived from wall-clock time, so pausing or leaving the
## game cannot consume a player's operating day offline.

const DEFAULT_DURATION_SECONDS := 120.0
const WARNING_THRESHOLD_SECONDS := 10.0

var duration_seconds := DEFAULT_DURATION_SECONDS
var remaining_seconds := DEFAULT_DURATION_SECONDS
var expired := false
var warning_started := false


func _init(duration: float = DEFAULT_DURATION_SECONDS) -> void:
	duration_seconds = maxf(duration, 0.0)
	remaining_seconds = duration_seconds


func advance(delta: float) -> Dictionary:
	if expired:
		return snapshot(false, false)
	var previous_remaining := remaining_seconds
	remaining_seconds = maxf(remaining_seconds - maxf(delta, 0.0), 0.0)
	var warning_started_now := not warning_started and previous_remaining > WARNING_THRESHOLD_SECONDS and remaining_seconds <= WARNING_THRESHOLD_SECONDS
	if warning_started_now:
		warning_started = true
	var expired_now := remaining_seconds <= 0.0
	if expired_now:
		expired = true
	return snapshot(warning_started_now, expired_now)


func snapshot(warning_started_now: bool = false, expired_now: bool = false) -> Dictionary:
	return {
		"duration_seconds": duration_seconds,
		"remaining_seconds": remaining_seconds,
		"remaining_whole_seconds": ceili(remaining_seconds),
		"warning_active": remaining_seconds <= WARNING_THRESHOLD_SECONDS and not expired,
		"warning_started_now": warning_started_now,
		"expired": expired,
		"expired_now": expired_now,
	}
