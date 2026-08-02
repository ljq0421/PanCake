class_name TimedStrokeSampler
extends RefCounted

var step_seconds: float
var _last_input := Vector2.ZERO
var _time_since_sample := 0.0
var _started := false


func _init(sample_step_seconds: float = 1.0 / 120.0) -> void:
	step_seconds = maxf(sample_step_seconds, 0.0001)


func begin(position: Vector2) -> void:
	_started = true
	_last_input = position
	_time_since_sample = 0.0


func sample_to(position: Vector2, delta_seconds: float) -> PackedVector2Array:
	if not _started:
		begin(position)
	var samples := PackedVector2Array()
	var safe_delta := maxf(delta_seconds, 0.0)
	if safe_delta <= 0.0:
		_last_input = position
		return samples
	var segment_start := _last_input
	var remaining_time := safe_delta
	var time_needed := step_seconds - _time_since_sample
	while remaining_time + 0.0000001 >= time_needed:
		var fraction := time_needed / remaining_time
		segment_start = segment_start.lerp(position, fraction)
		samples.append(segment_start)
		remaining_time -= time_needed
		_time_since_sample = 0.0
		time_needed = step_seconds
	_time_since_sample += maxf(remaining_time, 0.0)
	_last_input = position
	return samples


func reset() -> void:
	_started = false
	_time_since_sample = 0.0

