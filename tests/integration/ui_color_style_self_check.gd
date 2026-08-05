extends SceneTree

const START_MENU_SCENE := preload("res://scenes/main/start_menu.tscn")
const GAME_SCENE := preload("res://scenes/main/main.tscn")

const DEEP_TEAL := Color(0.045, 0.09, 0.10, 1.0)
const SECONDARY_TEAL := Color(0.075, 0.14, 0.15, 1.0)
const INTERACTIVE_TEAL := Color(0.10, 0.36, 0.31, 1.0)
const INTERACTIVE_HOVER := Color(0.14, 0.46, 0.38, 1.0)
const PROGRESS_GREEN := Color(0.25, 0.72, 0.57, 1.0)
const GOLD := Color(1.0, 0.82, 0.44, 1.0)

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var menu := START_MENU_SCENE.instantiate()
	root.add_child(menu)
	await process_frame
	_check_style_rgb(menu.get_node("Content/Layout/MenuPanel"), &"panel", DEEP_TEAL, "start menu uses the canonical deep-teal surface")
	_check_style_rgb(menu.get_node("Content/Layout/MenuPanel/Menu/ContinueButton"), &"normal", INTERACTIVE_TEAL, "start-menu primary action uses canonical interactive teal")
	menu.queue_free()
	await process_frame

	var game := GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var workstation := game.get_node("Workstation")

	_check_style_rgb(game.get_node("PausePanel"), &"panel", DEEP_TEAL, "pause panel matches the start-menu surface")
	_check_style_rgb(game.get_node("PausePanel/Content/ResumeButton"), &"normal", INTERACTIVE_TEAL, "pause action matches the start-menu primary action")
	_check_style_rgb(game.get_node("PausePanel/Content/ResumeButton"), &"hover", INTERACTIVE_HOVER, "pause hover uses canonical interaction highlight")
	_check_border_rgb(game.get_node("PausePanel"), &"panel", GOLD, "pause panel uses the canonical gold emphasis border")

	_check_style_rgb(workstation.get_node("SafeArea/CustomerStrip"), &"panel", DEEP_TEAL, "customer HUD uses the canonical deep-teal surface")
	_check_style_rgb(workstation.get_node("SafeArea/P1ControlBar"), &"panel", DEEP_TEAL, "gameplay control bar uses the canonical deep-teal surface")
	_check_style_rgb(workstation.get_node("SafeArea/ResultPanel"), &"panel", DEEP_TEAL, "result panel uses the canonical deep-teal surface")
	_check_style_rgb(workstation.get_node("SafeArea/DailyBillPanel"), &"panel", DEEP_TEAL, "daily bill uses the canonical deep-teal surface")
	_check_border_rgb(workstation.get_node("SafeArea/ResultPanel"), &"panel", GOLD, "result panel uses the canonical gold emphasis border")
	_check_style_rgb(workstation.get_node("SafeArea/PatienceBar"), &"background", SECONDARY_TEAL, "patience track uses the secondary teal")
	_check_style_rgb(workstation.get_node("SafeArea/PatienceBar"), &"fill", PROGRESS_GREEN, "patience fill uses the shared progress green")
	_check_style_rgb(workstation.get_node("SafeArea/P1ControlBar/StepActionButton"), &"normal", INTERACTIVE_TEAL, "gameplay primary action uses canonical interactive teal")
	_check_style_rgb(workstation.get_node("SafeArea/P1ControlBar/StepActionButton"), &"hover", INTERACTIVE_HOVER, "gameplay primary action hover uses canonical interaction highlight")
	_check_style_rgb(workstation.get_node("SafeArea/P1ControlBar/HeatSlider"), &"grabber_area", PROGRESS_GREEN, "heat slider uses the shared progress green")

	game.queue_free()
	await process_frame
	_finish()


func _check_style_rgb(control: Control, style_name: StringName, expected: Color, description: String) -> void:
	var style := control.get_theme_stylebox(style_name) as StyleBoxFlat
	_check(style != null and _same_rgb(style.bg_color, expected), description)


func _check_border_rgb(control: Control, style_name: StringName, expected: Color, description: String) -> void:
	var style := control.get_theme_stylebox(style_name) as StyleBoxFlat
	_check(style != null and _same_rgb(style.border_color, expected), description)


func _same_rgb(actual: Color, expected: Color) -> bool:
	return (
		is_equal_approx(actual.r, expected.r)
		and is_equal_approx(actual.g, expected.g)
		and is_equal_approx(actual.b, expected.b)
	)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("UI_COLOR_STYLE_SELF_CHECK_PASS")
		quit(0)
	else:
		print("UI_COLOR_STYLE_SELF_CHECK_FAIL (%d)" % _failures.size())
		quit(1)

