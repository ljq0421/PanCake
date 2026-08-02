class_name StrokeSampler
extends RefCounted

var spacing: float
var _last_input := Vector2.ZERO
var _distance_since_sample := 0.0
var _started := false


func _init(sample_spacing: float = 2.0) -> void:
	spacing = maxf(sample_spacing, 0.001)


func begin(position: Vector2) -> PackedVector2Array:
	_started = true
	_last_input = position
	_distance_since_sample = 0.0
	return PackedVector2Array([position])


func sample_to(position: Vector2) -> PackedVector2Array:
	if not _started:
		return begin(position)
	var samples := PackedVector2Array()
	var segment_start := _last_input
	var remaining := segment_start.distance_to(position)
	if remaining <= 0.000001:
		_last_input = position
		return samples
	var direction := (position - segment_start) / remaining
	var distance_needed := spacing - _distance_since_sample
	while remaining + 0.000001 >= distance_needed:
		segment_start += direction * distance_needed
		samples.append(segment_start)
		remaining -= distance_needed
		_distance_since_sample = 0.0
		distance_needed = spacing
	_distance_since_sample += maxf(remaining, 0.0)
	_last_input = position
	return samples


func reset() -> void:
	_started = false
	_distance_since_sample = 0.0

