extends SceneTree

const GRIDDLE_SCENE := preload("res://scenes/gameplay/compact_griddle_unit.tscn")
const FRYER_SCENE := preload("res://scenes/gameplay/cartoon_youtiao_fryer_toggle.tscn")
const BAR := preload("res://scripts/ui/cooking_stage_bar.gd")
const PANCAKE_SCORER := preload("res://scripts/gameplay/pancake_scorer.gd")

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
	griddle.state = CompactGriddleUnit.State.FIRST_SIDE
	griddle.call("_refresh_heat_visual")
	_check(griddle.heat_bar.visible and griddle.heat_bar.current_stage() == BAR.STAGE_GREEN, "a pancake inside the shared suitable band is green")
	_check(griddle.heat_status_label.text.contains("火候合适"), "pancake suitable state is also stated in text")

	griddle.pancake_model.doneness.fill(0.75)
	griddle.call("_refresh_heat_visual")
	_check(griddle.heat_bar.current_stage() == BAR.STAGE_RED and griddle.heat_status_label.text.contains("已焦糊"), "the 0.75 boundary enters the red charred stage")
	griddle.call("set_non_burning_upgrade_enabled", true)
	griddle.call("_refresh_heat_visual")
	_check(
		not bool(griddle.call("cooking_heat_status").get("charred", true))
		and griddle.heat_bar.current_stage() == BAR.STAGE_GREEN
		and griddle.heat_status_label.text.contains("火候合适")
		and is_equal_approx(float(griddle.pancake_model.cooking_doneness_cap), 0.749),
		"non-burning griddle caps an overcooked pancake just below the shared charred boundary",
	)
	griddle.pancake_model.doneness.fill(0.20)
	griddle.call("_refresh_heat_visual")
	_check(griddle.heat_status_label.text.contains("未熟") and not griddle.heat_status_label.text.contains("焦糊"), "the shared low stage is described as undercooked")
	_check(
		PANCAKE_SCORER.heat_feedback_for_metrics({
			"mean_front_doneness": 0.20,
			"mean_back_doneness": 0.20,
			"non_burning_griddle_applied": true,
		}) == "正面未熟、反面未熟",
		"protected pancake delivery feedback identifies both undercooked sides",
	)
	griddle.state = CompactGriddleUnit.State.IDLE
	griddle.call("_refresh_heat_visual")
	_check(griddle.heat_bar.visible and griddle.heat_bar.current_stage() == BAR.STAGE_INACTIVE and griddle.heat_status_label.text.contains("未开始"), "an unlocked idle griddle keeps a grey progress bar in place")

	var basic_speed_griddle := GRIDDLE_SCENE.instantiate() as CompactGriddleUnit
	var fast_speed_griddle := GRIDDLE_SCENE.instantiate() as CompactGriddleUnit
	root.add_child(basic_speed_griddle)
	root.add_child(fast_speed_griddle)
	await process_frame
	_prepare_cooking_speed_sample(basic_speed_griddle)
	_prepare_cooking_speed_sample(fast_speed_griddle)
	fast_speed_griddle.call("set_non_burning_upgrade_enabled", true)
	fast_speed_griddle.call("set_fast_cook_upgrade_enabled", true)
	basic_speed_griddle.call("_process", 0.5)
	fast_speed_griddle.call("_process", 0.5)
	var basic_doneness := float(basic_speed_griddle.pancake_model.mean_side_doneness(false))
	var fast_doneness := float(fast_speed_griddle.pancake_model.mean_side_doneness(false))
	_check(is_equal_approx(fast_doneness, basic_doneness * CompactGriddleUnit.FAST_COOK_HEAT_MULTIPLIER), "fast-cook griddle doubles cooking progress for the same real time")
	fast_speed_griddle.call("_process", 60.0)
	_check(float(fast_speed_griddle.pancake_model.mean_side_doneness(false)) < CompactGriddleUnit.heat_window().y, "fast-cook griddle retains the non-burning shared ceiling")

	var fryer := FRYER_SCENE.instantiate() as CartoonYoutiaoFryerToggle
	root.add_child(fryer)
	await process_frame
	var left := _lane(&"recipe.youtiao.plain", &"frying", 9.0, 0.0)
	var right := _lane(&"recipe.chicken.cutlet", &"frying", 11.0, 0.0)
	_apply_fryer_lanes(fryer, left, right, true)
	_check(fryer.youtiao_progress_bar.current_stage() == BAR.STAGE_YELLOW, "youtiao remains yellow before ten seconds")
	_check(fryer.chicken_progress_bar.current_stage() == BAR.STAGE_YELLOW, "chicken remains yellow before twelve seconds")
	_check_frying_hover_copy(fryer, 0.25, "youtiao frying hover shows frying status")
	_check_frying_hover_copy(fryer, 0.75, "chicken frying hover shows frying status")

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
	basic_speed_griddle.queue_free()
	fast_speed_griddle.queue_free()
	fryer.queue_free()
	await process_frame
	if _failures.is_empty():
		print("COOKING_PROGRESS_UI_SELF_CHECK_PASS")
		quit(0)
	else:
		printerr("COOKING_PROGRESS_UI_SELF_CHECK_FAIL\n" + "\n".join(_failures))
		quit(1)


func _prepare_cooking_speed_sample(griddle: CompactGriddleUnit) -> void:
	griddle.pancake_model.coverage.fill(1.0)
	griddle.pancake_model.thickness.fill(0.5)
	griddle.pancake_model.doneness.fill(0.0)
	griddle.pancake_model.back_doneness.fill(0.0)
	griddle.state = CompactGriddleUnit.State.FIRST_SIDE
	griddle.p1_session.heat_level = 0.5


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


func _check_frying_hover_copy(fryer: CartoonYoutiaoFryerToggle, horizontal_ratio: float, message: String) -> void:
	var visual_point := Vector2(fryer.fryer_visual.size.x * horizontal_ratio, fryer.fryer_visual.size.y * 0.5)
	var point := fryer.get_global_transform_with_canvas().affine_inverse() * (fryer.fryer_visual.get_global_transform_with_canvas() * visual_point)
	fryer.call("_update_machine_hover_preview", point)
	_check(fryer.tooltip_text == "炸制中", message)


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
