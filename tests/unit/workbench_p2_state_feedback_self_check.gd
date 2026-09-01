extends SceneTree

const BADGE_SCRIPT := preload("res://scripts/ui/workbench_state_badge.gd")
const WORKSTATION_SCENE := preload("res://scenes/gameplay/four_area_workstation.tscn")
const HOVER_SCRIPT := preload("res://scripts/ui/workstation_physical_hover.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	_check_state_contract()
	_check_state_derivation()
	_check_reminder_track()
	_check_hover_and_selection_contract()
	_check_muted_visual_contract()
	_finish()


func _check_state_contract() -> void:
	for state_key in [
		BADGE_SCRIPT.STATE_DEFAULT,
		BADGE_SCRIPT.STATE_HOVER,
		BADGE_SCRIPT.STATE_SELECTED,
		BADGE_SCRIPT.STATE_ACTIVE,
		BADGE_SCRIPT.STATE_COMPLETE,
		BADGE_SCRIPT.STATE_RISK,
		BADGE_SCRIPT.STATE_SHORTAGE,
		BADGE_SCRIPT.STATE_UNAVAILABLE,
	]:
		var presentation := Dictionary(BADGE_SCRIPT.STATE_PRESENTATION.get(state_key, {}))
		_check(not str(presentation.get("icon", "")).is_empty(), "%s state has a non-colour icon" % state_key)
		_check(presentation.has("color") and presentation.has("border"), "%s state has foreground and border treatment" % state_key)


func _check_state_derivation() -> void:
	_check(StringName(BADGE_SCRIPT.griddle_state({"state": 2}, {"cooking": true, "doneness": 0.5}).state) == BADGE_SCRIPT.STATE_ACTIVE, "griddle cooking maps to active")
	_check(StringName(BADGE_SCRIPT.griddle_state({"state": 6}).state) == BADGE_SCRIPT.STATE_COMPLETE, "packaged pancake maps to complete")
	_check(StringName(BADGE_SCRIPT.griddle_state({"state": 2}, {"charred": true}).state) == BADGE_SCRIPT.STATE_RISK, "charred pancake maps to risk")
	_check(StringName(BADGE_SCRIPT.fryer_state({"owned": true, "state": &"frying"}).state) == BADGE_SCRIPT.STATE_ACTIVE, "frying lane maps to active")
	_check(StringName(BADGE_SCRIPT.fryer_state({"owned": true, "state": &"ready_to_collect"}).state) == BADGE_SCRIPT.STATE_COMPLETE, "ready fryer maps to complete")
	_check(StringName(BADGE_SCRIPT.fryer_state({"owned": true, "state": &"overcooking"}).state) == BADGE_SCRIPT.STATE_RISK, "overcooking fryer maps to risk")
	_check(StringName(BADGE_SCRIPT.fryer_state({"owned": true, "state": &"idle"}, true).state) == BADGE_SCRIPT.STATE_SHORTAGE, "empty fryer stock maps to shortage")
	_check(StringName(BADGE_SCRIPT.soy_state({"owned": true, "cup_state": &"held_empty"}).state) == BADGE_SCRIPT.STATE_ACTIVE, "soy filling maps to active")
	_check(StringName(BADGE_SCRIPT.soy_state({"owned": true, "cup_state": &"filled"}).state) == BADGE_SCRIPT.STATE_COMPLETE, "filled soy cup maps to complete")
	_check(StringName(BADGE_SCRIPT.soy_state({"owned": true, "cup_state": &"ready"}, true).state) == BADGE_SCRIPT.STATE_SHORTAGE, "empty cup stack maps to shortage")
	_check(StringName(BADGE_SCRIPT.packaged_drink_state(true, 0, 10).state) == BADGE_SCRIPT.STATE_SHORTAGE, "empty drink rack maps to shortage")
	_check("×10" in str(BADGE_SCRIPT.packaged_drink_state(true, 10, 10).detail), "drink-ready state includes a textual quantity")


func _check_reminder_track() -> void:
	var workstation := WORKSTATION_SCENE.instantiate()
	workstation.call("_apply_attention_entries", [
		{"status_key": &"youtiao_overcooking", "severity": &"red", "seconds_to_irreversible_loss": 5.0},
	])
	workstation.call("_push_recent_reminder", "豆浆接满，可以交付", &"info")
	workstation.call("_push_recent_reminder", "果汁缺货，请长按补货", &"red")
	workstation.call("_push_recent_reminder", "煎饼已完成包装", &"info")
	var rail := workstation.get_node("FiveAreaInfrastructure/AttentionRail") as Control
	var visible_count := 0
	for child in rail.get_children():
		if (child as Label).visible:
			visible_count += 1
	_check(visible_count == 3, "attention track displays no more than three chips including urgent state")
	_check((rail.get_child(0) as Label).text.begins_with("紧急"), "urgent device loss remains first")
	_check("缺货" in (rail.get_child(1) as Label).text or "完成" in (rail.get_child(1) as Label).text, "recent transient feedback remains readable after its popup")
	workstation.free()


func _check_hover_and_selection_contract() -> void:
	var helper := HOVER_SCRIPT.new() as WorkstationPhysicalHover
	var control := Button.new()
	var visual := ColorRect.new()
	helper.call("_on_mouse_entered", control, visual)
	_check(StringName(control.get_meta(&"workbench_visual_state", &"")) == &"hover", "physical hover exposes a shared state marker")
	helper.call("_on_mouse_exited", control, visual)
	_check(StringName(control.get_meta(&"workbench_visual_state", &"")) == &"default", "physical hover restores default state")
	var source := ProductDragSource.new()
	source.set_selection_highlight(true)
	_check(StringName(source.get_meta(&"workbench_visual_state", &"")) == &"selected", "selected product exposes the shared gold-selection state")
	source.free()
	visual.free()
	control.free()
	helper.free()


func _check_muted_visual_contract() -> void:
	var master_index := AudioServer.get_bus_index(&"Master")
	var previous_mute := AudioServer.is_bus_mute(master_index)
	AudioServer.set_bus_mute(master_index, true)
	var badge := BADGE_SCRIPT.new() as WorkbenchStateBadge
	badge.call("_ready")
	badge.set_state(BADGE_SCRIPT.STATE_RISK, "炸锅 · 过火风险")
	_check(badge.state_key() == BADGE_SCRIPT.STATE_RISK and "过火" in badge.detail_text(), "risk remains explicit while all audio is muted")
	_check(str(Dictionary(BADGE_SCRIPT.STATE_PRESENTATION[BADGE_SCRIPT.STATE_RISK]).get("icon", "")) == "!", "muted risk state keeps its non-colour warning icon")
	AudioServer.set_bus_mute(master_index, previous_mute)
	badge.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("WORKBENCH_P2_STATE_FEEDBACK_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("WORKBENCH_P2_STATE_FEEDBACK_SELF_CHECK_FAIL\n%s" % "\n".join(failures))
	quit(1)
