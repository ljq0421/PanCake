extends SceneTree

const MODEL = preload("res://scripts/simulation/pancake_model.gd")
const CATALOG = preload("res://scripts/data/workstation_expansion_catalog.gd")

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
	_check(is_equal_approx(float(CATALOG.item_effect(CATALOG.TOOL_SPREADER_WIDE).get("width_multiplier", 0.0)), 1.65), "wide spreader catalog grants a clearly larger 65% coverage width")
	var basic_model: RefCounted = MODEL.new(128)
	var wide_model: RefCounted = MODEL.new(128)
	for model in [basic_model, wide_model]:
		model.call("add_batter", Vector2(63, 63), 3.0, 36.0)
	var basic_result: Dictionary = basic_model.call("apply_scraper_sample", Vector2(63, 63), Vector2.RIGHT, 72.0, 1.0)
	var wide_result: Dictionary = wide_model.call("apply_scraper_sample", Vector2(63, 63), Vector2.RIGHT, 72.0, CATALOG.WIDE_SPREADER_WIDTH_MULTIPLIER)
	_check(int(wide_result.get("changed_cells", 0)) > int(basic_result.get("changed_cells", 0)), "wide spreader affects more batter cells than the base tool with one matching stroke")
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
