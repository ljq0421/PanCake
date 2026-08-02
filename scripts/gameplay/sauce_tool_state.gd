class_name SauceToolState
extends RefCounted

var capacity: float
var load: float


func _init(brush_capacity: float = 1.0) -> void:
	capacity = maxf(brush_capacity, 0.001)
	reset()


func reset() -> void:
	load = 0.0


func add(amount: float) -> float:
	var previous := load
	load = minf(load + maxf(amount, 0.0), capacity)
	return load - previous


func consume(requested_amount: float) -> float:
	var consumed := minf(maxf(requested_amount, 0.0), load)
	load -= consumed
	return consumed


func load_ratio() -> float:
	return clampf(load / capacity, 0.0, 1.0)
