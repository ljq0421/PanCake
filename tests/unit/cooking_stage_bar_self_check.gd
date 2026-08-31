extends SceneTree

const BAR := preload("res://scripts/ui/cooking_stage_bar.gd")
const GRIDDLE := preload("res://scripts/gameplay/compact_griddle_unit.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var bar = BAR.new()
	bar.configure(0.0, 0.40, 0.60, false, &"", "火候 · 未开始")
	_check(bar.current_stage() == BAR.STAGE_INACTIVE and bar.tooltip_text == "火候 · 未开始", "inactive cooking bars keep a readable grey-state description")
	bar.configure(0.20, 0.40, 0.60, true)
	_check(bar.current_stage() == BAR.STAGE_YELLOW, "progress before the ideal window is yellow")
	bar.configure(0.40, 0.40, 0.60, true)
	_check(bar.current_stage() == BAR.STAGE_GREEN, "the lower ideal boundary is green")
	bar.configure(0.60, 0.40, 0.60, true)
	_check(bar.current_stage() == BAR.STAGE_GREEN, "the upper ideal boundary remains green")
	bar.configure(0.61, 0.40, 0.60, true)
	_check(bar.current_stage() == BAR.STAGE_RED, "progress after the ideal window is red")
	bar.configure(0.50, 0.40, 0.60, true, BAR.STAGE_RED)
	_check(bar.current_stage() == BAR.STAGE_RED, "an explicit danger state overrides the pointer segment")

	var suitable := GRIDDLE.heat_window()
	_check(suitable.is_equal_approx(Vector2(0.25, 0.75)), "all pancakes use the shared 0.25-0.75 suitable window")
	_check(GRIDDLE.heat_stage_for_doneness(0.249, suitable) == BAR.STAGE_YELLOW, "doneness below 0.25 is undercooked")
	_check(GRIDDLE.heat_stage_for_doneness(0.25, suitable) == BAR.STAGE_GREEN, "the lower suitable boundary is inclusive")
	_check(GRIDDLE.heat_stage_for_doneness(0.749, suitable) == BAR.STAGE_GREEN, "doneness below 0.75 remains suitable")
	_check(GRIDDLE.heat_stage_for_doneness(0.75, suitable) == BAR.STAGE_RED, "the 0.75 charred boundary is exclusive from the suitable window")
	bar.free()

	if _failures.is_empty():
		print("COOKING_STAGE_BAR_SELF_CHECK_PASS")
		quit(0)
	else:
		printerr("COOKING_STAGE_BAR_SELF_CHECK_FAIL\n" + "\n".join(_failures))
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
