extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var workstation := main.get_node("Workstation") as Workstation
	var elapsed_before_pause := workstation.p1_session.elapsed_seconds
	paused = true
	await process_frame
	await process_frame
	await process_frame
	paused = false
	_check(is_equal_approx(workstation.p1_session.elapsed_seconds, elapsed_before_pause), "pausing the scene tree freezes cooking time and customer patience")
	workstation.set_process(false)
	_check(workstation.customer_portrait != null and workstation.order_text_label != null and workstation.patience_bar != null, "P1 customer, order and patience nodes are stable scene content")
	_check(workstation.ingredient_layer != null and workstation.egg_button != null and workstation.scallion_button != null, "P1 ingredient rack and pancake layer are stable scene content")
	_check(workstation.chili_sauce_refill_button != null and workstation.heat_slider != null, "P1 owns two-sauce selection and fire control")
	_check(workstation.pancake_surface.get_renderer_diagnostics().chili_sauce_texture != null, "P1 renderer uploads the independent chili-sauce field")
	_check(workstation.p1_session.order.id == &"classic" and workstation.order_text_label.text.contains("经典杂粮煎饼"), "first customer receives a concrete verifiable order")

	_fill_product_base(workstation.pancake_model)
	workstation.pour_used = true
	_check(bool(workstation.p1_session.confirm_spread(workstation.pancake_model).success), "real workstation session accepts a sufficiently spread pancake")
	var ingredient_press := InputEventMouseButton.new()
	ingredient_press.button_index = MOUSE_BUTTON_LEFT
	ingredient_press.pressed = true
	workstation._on_ingredient_gui_input(ingredient_press, IngredientModel.EGG)
	var surface_center := workstation.pancake_surface.get_global_transform_with_canvas() * Vector2(300, 300)
	workstation._finish_ingredient_drag(surface_center)
	_check(workstation.ingredient_model.has_type(IngredientModel.EGG), "dragging from the ingredient rack onto the real pancake surface places business data")
	_check(workstation.pancake_model.has_egg() and workstation.egg_crack_artwork.visible, "egg drop creates the liquid simulation and visible raw-egg landing state")
	_check(workstation.tool_controller.current_tool == ToolController.Tool.SCRAPER, "egg drop automatically selects the existing T-shaped spreader")
	workstation.step_action_button.pressed.emit()
	_check(not workstation.pancake_model.is_flipped and workstation.p1_session.phase == P1Session.Phase.FIRST_SIDE, "flip remains blocked until the egg has actually been spread")
	_spread_egg_with_workstation(workstation)
	var egg_summary := workstation.pancake_model.calculate_egg_spread_summary()
	_check(workstation.pancake_model.yolk_broken and not workstation.egg_crack_artwork.visible, "real workstation spread samples break the yolk and replace the landing sprite with the grid layer")
	_check(float(egg_summary.coverage_ratio) >= workstation.parameters.egg_minimum_spread_coverage, "continuous T-spreader input reaches the model-backed egg coverage gate")
	workstation.pancake_surface.force_texture_upload()
	_check(workstation.pancake_surface.get_renderer_diagnostics().egg_texture != null, "renderer uploads the spread egg field")
	workstation.pancake_model.doneness.fill(0.62)
	workstation.step_action_button.pressed.emit()
	_check(workstation.pancake_model.is_flipped and workstation.p1_session.phase == P1Session.Phase.SECOND_SIDE, "step action performs the guarded real flip path")
	workstation.pancake_model.back_doneness.fill(0.62)
	workstation.step_action_button.pressed.emit()
	_check(workstation.p1_session.phase == P1Session.Phase.SAUCE_AND_FILLINGS, "second-side completion unlocks sauces and fillings")

	workstation.chili_sauce_refill_button.button_down.emit()
	workstation._process(0.5)
	workstation.chili_sauce_refill_button.button_up.emit()
	_check(workstation.current_sauce_type == OrderService.SAUCE_CHILI and float(workstation.sauce_tool_state.load) > 0.0, "holding the chili bottle selects and fills the chili brush path")
	workstation._select_sauce_type(OrderService.SAUCE_SWEET)
	workstation.pancake_model.sauce_concentration.fill(0.35)
	workstation.ingredient_model.place(IngredientModel.BAOCUI, Vector2(62, 56), 0.0, workstation.pancake_model)
	workstation.ingredient_model.place(IngredientModel.SCALLION, Vector2(68, 70), 0.0, workstation.pancake_model)
	workstation.step_action_button.pressed.emit()
	_check(workstation.p1_session.phase == P1Session.Phase.FOLD and workstation.tool_controller.current_tool == ToolController.Tool.FOLD, "step action enters the continuous folding path")
	_fold_both(workstation)
	_check(workstation.p1_session.phase == P1Session.Phase.PACKAGE and not workstation.bag_button.disabled, "intact folds unlock normal packaging")
	workstation.bag_button.pressed.emit()
	_check(workstation.p1_session.phase == P1Session.Phase.READY_TO_SERVE, "paper bag completes packaging without a rescue penalty")
	workstation.step_action_button.pressed.emit()
	_check(workstation.p1_session.phase == P1Session.Phase.RESULT and workstation.result_panel.visible, "serve action opens the model-backed evaluation result")
	_check(
		workstation.payment_display.is_visible_in_tree()
		and workstation.heat_score_label.is_visible_in_tree()
		and workstation.egg_score_label.is_visible_in_tree()
		and workstation.heat_score_label.text.contains("火候")
		and workstation.egg_score_label.text.contains("摊蛋"),
		"result includes visible payment feedback and all runtime score dimensions"
	)
	workstation.next_order_button.pressed.emit()
	_check(workstation.p1_session.order.id == &"chili_ham" and workstation.pancake_model.covered_cell_count() == 0, "collecting payment resets production and advances to the next order")

	main.queue_free()
	await process_frame
	await process_frame
	_finish()


func _fill_product_base(model: PancakeModel) -> void:
	for y in model.grid_size:
		for x in model.grid_size:
			if not model.is_inside_pan(Vector2(x, y), 0.84):
				continue
			var index := y * model.grid_size + x
			model.coverage[index] = 1.0
			model.thickness[index] = 0.42
			model.wetness[index] = 0.20
	model.revision += 1
	model.changed.emit()


func _fold_both(workstation: Workstation) -> void:
	workstation.fold_model.begin_drag(Vector2(12, 64))
	workstation.fold_model.release_drag(Vector2(70, 64))
	workstation.fold_model.begin_drag(Vector2(116, 64))
	workstation.fold_model.release_drag(Vector2(58, 64))


func _spread_egg_with_workstation(workstation: Workstation) -> void:
	var center := Vector2(workstation.pancake_model.grid_size - 1, workstation.pancake_model.grid_size - 1) * 0.5
	workstation._on_pointer_started(Vector2(300, 300))
	for ring in 10:
		var radius := 6.0 + float(ring) * 4.2
		for step in 56:
			var angle := TAU * float(step) / 56.0
			var radial := Vector2(cos(angle), sin(angle) * workstation.parameters.pan_height_ratio)
			workstation._process_scraper(center + radial * radius, 1.0 / 60.0)
	workstation._on_pointer_ended(Vector2(300, 300))


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("P1 interaction self-check PASS")
		quit(0)
	else:
		print("P1 interaction self-check FAIL (%d)" % _failures.size())
		quit(1)
