extends SceneTree

const GRIDDLE_SCENE := preload("res://scenes/gameplay/compact_griddle_unit.tscn")
const FRYER_SCENE := preload("res://scenes/gameplay/cartoon_youtiao_fryer_toggle.tscn")
const BAR := preload("res://scripts/ui/cooking_stage_bar.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var griddle := GRIDDLE_SCENE.instantiate() as CompactGriddleUnit
	root.add_child(griddle)
	await process_frame
	griddle.pancake_model.coverage.fill(1.0)
	griddle.pancake_model.doneness.fill(0.48)
	griddle.pancake_model.cooking_exposure_seconds.fill(0.0)
	griddle.order = {"heat_preference": &"light"}
	griddle.state = CompactGriddleUnit.State.FIRST_SIDE
	griddle.call("_refresh_heat_visual")
	_check(griddle.heat_bar.visible and griddle.heat_bar.current_stage() == BAR.STAGE_GREEN, "a light-order pancake is green at its requested target")
	_check(griddle.heat_status_label.text.contains("火候正好"), "pancake green state is also stated in text")

	griddle.order = {"heat_preference": &"well_done"}
	griddle.call("_refresh_heat_visual")
	_check(griddle.heat_bar.current_stage() == BAR.STAGE_YELLOW and griddle.heat_status_label.text.contains("偏生"), "the same doneness remains yellow for a well-done order")
	griddle.pancake_model.doneness.fill(0.90)
	griddle.call("_refresh_heat_visual")
	_check(griddle.heat_bar.current_stage() == BAR.STAGE_RED and griddle.heat_status_label.text.contains("过火风险"), "pancake doneness beyond the order window is red with matching text")
	griddle.pancake_model.doneness.fill(0.93)
	griddle.pancake_model.cooking_exposure_seconds.fill(8.0)
	griddle.call("_refresh_heat_visual")
	_check(griddle.heat_bar.current_stage() == BAR.STAGE_RED and griddle.heat_status_label.text.contains("已焦糊"), "visible charring forces the pancake bar and copy to red danger")
	griddle.call("set_non_burning_upgrade_enabled", true)
	griddle.call("_refresh_heat_visual")
	_check(not bool(griddle.call("cooking_heat_status").get("charred", true)) and griddle.heat_status_label.text.contains("过火风险"), "non-burning griddle caps an overcooked pancake below the charred state")
	griddle.state = CompactGriddleUnit.State.IDLE
	griddle.call("_refresh_heat_visual")
	_check(griddle.heat_bar.visible and griddle.heat_bar.current_stage() == BAR.STAGE_INACTIVE and griddle.heat_status_label.text.contains("未开始"), "an unlocked idle griddle keeps a grey progress bar in place")

	var fryer := FRYER_SCENE.instantiate() as CartoonYoutiaoFryerToggle
	root.add_child(fryer)
	await process_frame
	var left := _lane(&"recipe.youtiao.plain", &"frying", 9.0, 0.0)
	var right := _lane(&"recipe.chicken.cutlet", &"frying", 11.0, 0.0)
	_apply_fryer_lanes(fryer, left, right, true)
	_check(fryer.youtiao_progress_bar.current_stage() == BAR.STAGE_YELLOW, "youtiao remains yellow before ten seconds")
	_check(fryer.chicken_progress_bar.current_stage() == BAR.STAGE_YELLOW, "chicken remains yellow before twelve seconds")

	left = _lane(&"recipe.youtiao.plain", &"ready_safe", 10.0, 0.0)
	right = _lane(&"recipe.chicken.cutlet", &"ready_safe", 12.0, 4.5)
	_apply_fryer_lanes(fryer, left, right, true)
	_check(fryer.youtiao_progress_bar.current_stage() == BAR.STAGE_GREEN and fryer.youtiao_progress_label.text.contains("最佳起锅"), "ready youtiao enters its green lift window")
	_check(fryer.chicken_progress_bar.current_stage() == BAR.STAGE_GREEN and fryer.chicken_progress_label.text.contains("最佳起锅") and fryer.chicken_progress_bar.tooltip_text.contains("剩余0.5秒"), "chicken tracks its independent five-second green window")

	left = _lane(&"recipe.youtiao.plain", &"overcooking", 10.0, 5.1, 96.0)
	right = _lane(&"recipe.chicken.cutlet", &"frying", 12.0, 0.0)
	_apply_fryer_lanes(fryer, left, right, true)
	_check(fryer.youtiao_progress_bar.current_stage() == BAR.STAGE_RED and fryer.youtiao_progress_label.text.contains("过火风险"), "youtiao turns red immediately after its safe window")
	_check(fryer.chicken_progress_bar.current_stage() == BAR.STAGE_GREEN, "the chicken lane stays independently green while youtiao is red")

	right = _lane(&"recipe.chicken.cutlet", &"idle", 0.0, 0.0)
	_apply_fryer_lanes(fryer, left, right, true)
	_check(fryer.chicken_progress_bar.visible and fryer.chicken_progress_bar.current_stage() == BAR.STAGE_INACTIVE, "an unlocked idle chicken lane remains visible in grey")
	_apply_fryer_lanes(fryer, left, right, false)
	_check(not fryer.chicken_progress_bar.visible and not fryer.chicken_progress_label.visible, "the chicken progress row stays hidden before dual-basket unlock")
	_check(griddle.heat_bar.size.y >= 20.0 and fryer.youtiao_progress_bar.size.y >= 20.0, "all cooking bars use a clearly readable authored height")

	griddle.queue_free()
	fryer.queue_free()
	await process_frame
	if _failures.is_empty():
		print("COOKING_PROGRESS_UI_SELF_CHECK_PASS")
		quit(0)
	else:
		printerr("COOKING_PROGRESS_UI_SELF_CHECK_FAIL\n" + "\n".join(_failures))
		quit(1)


func _apply_fryer_lanes(fryer: CartoonYoutiaoFryerToggle, left: Dictionary, right: Dictionary, chicken_unlocked: bool) -> void:
	var machine := left.duplicate(true)
	machine["owned"] = true
	machine["tier"] = 2
	machine["capacity"] = 4
	machine["quantity"] = 1
	machine["occupied_slot_indices"] = [0]
	machine["lanes"] = {&"left": left, &"right": right}
	fryer._machine = machine
	fryer._chicken_unlocked = chicken_unlocked
	fryer._workshop_preview = false
	fryer.call("_apply_snapshot")


func _lane(recipe_id: StringName, state: StringName, cooking: float, completed: float, quality: float = 100.0) -> Dictionary:
	return {
		"owned": true,
		"capacity": 4,
		"state": state,
		"recipe_id": recipe_id,
		"quantity": 1,
		"occupied_slot_indices": [0],
		"cooking_elapsed_seconds": cooking,
		"completed_elapsed_seconds": completed,
		"draining_elapsed_seconds": 0.0,
		"quality": quality,
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
