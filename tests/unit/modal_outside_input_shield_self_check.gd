extends SceneTree

const SHIELD := preload("res://scripts/ui/modal_outside_input_shield.gd")


func _initialize() -> void:
	var safe_area := Control.new()
	safe_area.size = Vector2(1920, 1080)
	root.add_child(safe_area)
	var panel := Control.new()
	panel.name = "DailyBillPanel"
	panel.position = Vector2(330, 80)
	panel.size = Vector2(1260, 820)
	safe_area.add_child(panel)
	var shield := SHIELD.new()
	shield.size = safe_area.size
	shield.excluded_control_path = NodePath("../DailyBillPanel")
	safe_area.add_child(shield)
	if shield._has_point(Vector2(100, 100)) and not shield._has_point(Vector2(400, 100)) and not shield._has_point(Vector2(1589, 899)) and shield._has_point(Vector2(1600, 900)):
		print("MODAL_OUTSIDE_INPUT_SHIELD_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("MODAL_OUTSIDE_INPUT_SHIELD_SELF_CHECK_FAIL")
	quit(1)
