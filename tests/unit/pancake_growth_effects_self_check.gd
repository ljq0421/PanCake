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
	press_model.call("add_batter", Vector2(31, 31), 7.5, 10.0)
	press_model.call("advance_solidification", 0.75)
	press_model.call("advance_cooking", 0.75, 0.5)
	var mass_before := float(press_model.call("total_thickness"))
	var pressed: Dictionary = press_model.call("apply_standard_press_spread")
	var mass_after := float(press_model.call("total_thickness"))
	var pressed_coverage: PackedFloat32Array = press_model.get("coverage")
	var pressed_thickness: PackedFloat32Array = press_model.get("thickness")
	var pressed_damage: PackedFloat32Array = press_model.get("damage")
	var min_thickness := INF
	var max_thickness := 0.0
	var max_damage := 0.0
	for index in pressed_coverage.size():
		max_damage = maxf(max_damage, pressed_damage[index])
		if pressed_coverage[index] <= 0.0:
			continue
		min_thickness = minf(min_thickness, pressed_thickness[index])
		max_thickness = maxf(max_thickness, pressed_thickness[index])
	_check(bool(pressed.get("success", false)) and float(pressed.get("coverage_ratio", 0.0)) >= 0.79, "press automation creates a complete centered pancake skin")
	_check(is_equal_approx(mass_before, mass_after), "press automation preserves the poured batter mass")
	_check(max_thickness - min_thickness <= 0.00001, "press automation produces uniform thickness")
	_check(max_damage <= 0.0 and press_model.call("validate").is_empty(), "press automation removes holes and damage without corrupting simulation fields")
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
