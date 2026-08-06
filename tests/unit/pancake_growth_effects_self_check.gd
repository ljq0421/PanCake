extends SceneTree

const MODEL = preload("res://scripts/simulation/pancake_model.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var protected_model: RefCounted = MODEL.new(32)
	protected_model.call("add_batter", Vector2(15, 15), 1.0, 12.0)
	protected_model.set("cooking_doneness_cap", 0.64)
	protected_model.call("advance_cooking", 90.0, 1.25)
	_check(float(protected_model.call("mean_side_doneness", false)) <= 0.641, "intermediate griddle cap prevents pancake surface from burning beyond its target")
	var press_model: RefCounted = MODEL.new(64)
	press_model.call("add_batter", Vector2(31, 31), 1.0, 9.0)
	var pressed: Dictionary = press_model.call("apply_standard_press_spread")
	_check(int(pressed.get("changed_cells", 0)) > 0, "press automation produces a standard spread through the simulation model")
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PANCAKE_GROWTH_EFFECTS_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("PANCAKE_GROWTH_EFFECTS_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
