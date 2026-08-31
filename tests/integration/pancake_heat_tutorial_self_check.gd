extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/four_area_workstation.tscn")

class StubSession extends Node:
	func inventory_snapshot() -> Dictionary:
		return {}

	func active_formal_order() -> Dictionary:
		return {}

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	await process_frame
	var session := StubSession.new()
	root.add_child(session)
	var griddle := workstation.multi_griddle_station.units[0] as CompactGriddleUnit

	var guide := Dictionary(workstation.call("_tutorial_guide_for_area", session, &"area.pancake"))
	_check(guide.get("target") != griddle and str(guide.get("message", "")).contains("第1步"), "idle tutorial points at the batter-ladle step rather than the full griddle")

	griddle.begin_order({})
	var pressed := Dictionary(griddle.use_press_spreader())
	_check(bool(pressed.get("success", false)) and griddle.state == CompactGriddleUnit.State.FIRST_SIDE, "fixture reaches first-side cooking before testing the flip timer")
	_check(bool(Dictionary(griddle.pancake_model.crack_egg(Vector2(31, 31))).get("success", false)) and griddle.pancake_model.has_egg(), "fixture adds the tutorial egg before testing the flip timer")
	guide = Dictionary(workstation.call("_tutorial_guide_for_area", session, &"area.pancake"))
	_check(guide.get("target") == griddle.heat_status_label and str(guide.get("message", "")).contains("火候计时"), "first side below the recommended heat points at the visible heat timer")

	griddle.pancake_model.advance_cooking(4.0, 1.25)
	griddle.first_side_seconds = 4.0
	griddle.call("_refresh_heat_visual")
	guide = Dictionary(workstation.call("_tutorial_guide_for_area", session, &"area.pancake"))
	_check(guide.get("target") == griddle.main_action and str(guide.get("message", "")).contains("现在可翻面"), "recommended first-side heat points at the flip control")

	griddle.pancake_model.advance_cooking(10.0, 1.25)
	griddle.first_side_seconds = 14.0
	griddle.call("_refresh_heat_visual")
	guide = Dictionary(workstation.call("_tutorial_guide_for_area", session, &"area.pancake"))
	_check(bool(Dictionary(griddle.cooking_heat_status()).get("charred", false)), "overcooked first side is recognized as charred")
	_check(str(griddle.heat_status_label.text).contains("焦糊") and str(guide.get("message", "")).contains("火候分已下降"), "charred first side shows its visible quality consequence and urgent flip guidance")

	session.queue_free()
	workstation.queue_free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("PANCAKE_HEAT_TUTORIAL_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("PANCAKE_HEAT_TUTORIAL_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
