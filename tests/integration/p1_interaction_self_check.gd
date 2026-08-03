extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_session := root.get_node_or_null("GameSession")
	if game_session != null:
		game_session.call("begin_new_game")
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
	_check(workstation.customer_portrait.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "cropped customer artwork keeps its original proportions")
	var pan_base := workstation.get_node("SafeArea/PanBase") as Control
	_check(
		workstation.customer_portrait.texture.resource_path.ends_with("_cropped.tres")
		and absf(workstation.customer_portrait.position.y + workstation.customer_portrait.size.y - 460.0) <= 1.0,
		"cropped customer artwork reaches the reference counter edge"
	)
	_check(
		pan_base != null and absf(pan_base.position.y - 455.0) <= 1.0 and absf(pan_base.size.y - 585.0) <= 1.0,
		"griddle container keeps the reference slot gap without exceeding the worktop"
	)
	_check(workstation.ingredient_layer != null and workstation.egg_button != null and workstation.scallion_button != null, "P1 ingredient rack and pancake layer are stable scene content")
	_check(workstation.chili_sauce_refill_button != null and workstation.heat_slider != null, "P1 owns two-sauce selection and fire control")
	_check(
		not workstation.sauce_refill_button.get_global_rect().intersects(workstation.chili_sauce_refill_button.get_global_rect()),
		"sweet and chili bottle hit regions do not overlap"
	)
	_check(workstation.pancake_surface.get_renderer_diagnostics().chili_sauce_texture != null, "P1 renderer uploads the independent chili-sauce field")
	_check(workstation.p1_session.order.id == &"classic" and workstation.order_text_label.text.contains("经典杂粮煎饼"), "first customer receives a concrete verifiable order")
	_check(not workstation.step_action_button.visible and workstation.step_action_button.text != "确认面饼", "the player is not asked to confirm a sufficiently spread pancake")
	if DisplayServer.get_name() == "headless":
		workstation._select_ladle()
	else:
		await _click_control(workstation.ladle_button)
	_check(workstation.pour_used, "automatic pour is reachable through the overlapping tool racks")
	workstation.tool_controller.clear_tool()
	if DisplayServer.get_name() == "headless":
		workstation._select_scraper()
	else:
		await _click_control(workstation.scraper_button)
	_check(workstation.tool_controller.current_tool == ToolController.Tool.SCRAPER, "the T-shaped spreader can be selected")

	_fill_product_base(workstation.pancake_model)
	workstation.pour_used = true
	workstation._on_pointer_ended(Vector2(300, 300))
	_check(workstation.p1_session.phase == P1Session.Phase.FIRST_SIDE, "releasing a sufficiently spread pancake automatically enters first-side cooking")
	var surface_center := workstation.pancake_surface.get_global_transform_with_canvas() * Vector2(300, 300)
	if DisplayServer.get_name() == "headless":
		var ingredient_press := InputEventMouseButton.new()
		ingredient_press.button_index = MOUSE_BUTTON_LEFT
		ingredient_press.pressed = true
		workstation._on_ingredient_gui_input(ingredient_press, IngredientModel.EGG)
		workstation._finish_ingredient_drag(surface_center)
	else:
		await _drag_control_to(workstation.egg_button, surface_center)
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
	_check(workstation.pancake_model.is_flipped and workstation.p1_session.phase == P1Session.Phase.SAUCE_AND_FILLINGS, "step action flips and immediately enters sauce and fillings")
	_check(is_equal_approx(workstation.pancake_model.mean_side_doneness(true), workstation.pancake_model.mean_side_doneness(false)), "quick flip settles the second-side heat without waiting")
	_check(not workstation.sauce_refill_button.disabled and not workstation.chili_sauce_refill_button.disabled, "both sauce bottles respond immediately after flipping")
	if DisplayServer.get_name() == "headless":
		workstation.chili_sauce_refill_button.button_down.emit()
		workstation._process(0.5)
		workstation.chili_sauce_refill_button.button_up.emit()
	else:
		await _hold_control_with_process(workstation, workstation.chili_sauce_refill_button, 0.5)
	var chili_load := float(workstation.sauce_tool_state.load)
	_check(workstation.p1_session.phase == P1Session.Phase.SAUCE_AND_FILLINGS, "clicking a sauce bottle stays in the immediate post-flip sauce stage")
	_check(workstation.current_sauce_type == OrderService.SAUCE_CHILI and chili_load > 0.0 and workstation.sauce_blob_overlay.visible, "holding the chili bottle creates a visible chili blob on the pancake")
	var doneness_before_sauce := workstation.pancake_model.mean_side_doneness(true)
	workstation._process(15.0)
	_check(is_equal_approx(workstation.pancake_model.mean_side_doneness(true), doneness_before_sauce), "sauce and filling time no longer burns the finished pancake")
	if DisplayServer.get_name() == "headless":
		workstation.sauce_refill_button.button_down.emit()
		workstation._process(0.5)
		workstation.sauce_refill_button.button_up.emit()
	else:
		await _hold_control_with_process(workstation, workstation.sauce_refill_button, 0.5)
	var sweet_load_before_brush := float(workstation.sauce_tool_state.load)
	_check(sweet_load_before_brush > 0.0 and is_equal_approx(float(workstation.sauce_tool_states[OrderService.SAUCE_CHILI].load), chili_load), "sweet and chili squeeze amounts remain independent")
	if DisplayServer.get_name() == "headless":
		workstation.sauce_brush_button.pressed.emit()
		workstation._sauce_stroke_id = workstation.pancake_model.begin_sauce_stroke()
		workstation._apply_sauce_brush_sample(Vector2(64, 64))
	else:
		await _click_control(workstation.sauce_brush_button)
		_send_mouse_motion(surface_center, 0)
		await process_frame
		_send_mouse_button(surface_center, true)
		await process_frame
		_send_mouse_motion(surface_center + Vector2(36.0, 0.0), MOUSE_BUTTON_MASK_LEFT)
		workstation._process(1.0 / 60.0)
		await process_frame
		_send_mouse_button(surface_center + Vector2(36.0, 0.0), false)
		await process_frame
	_check(workstation.pancake_model.total_sauce() > 0.0 and float(workstation.sauce_tool_state.load) < sweet_load_before_brush, "the sauce brush consumes and spreads the squeezed sweet sauce")
	await _place_ingredient_from_rack(workstation, workstation.baocui_button, IngredientModel.BAOCUI, surface_center + Vector2(-70, -30))
	await _place_ingredient_from_rack(workstation, workstation.ham_button, IngredientModel.HAM_SAUSAGE, surface_center + Vector2(55, -20))
	await _place_ingredient_from_rack(workstation, workstation.scallion_button, IngredientModel.SCALLION, surface_center + Vector2(15, 65))
	_check(
		workstation.ingredient_model.has_type(IngredientModel.BAOCUI)
		and workstation.ingredient_model.has_type(IngredientModel.HAM_SAUSAGE)
		and workstation.ingredient_model.has_type(IngredientModel.SCALLION),
		"all filling controls can place their ingredients after the filling phase unlocks"
	)
	workstation.step_action_button.pressed.emit()
	_check(workstation.p1_session.phase == P1Session.Phase.FOLD and workstation.tool_controller.current_tool == ToolController.Tool.FOLD, "step action enters the continuous folding path")
	workstation.tool_controller.clear_tool()
	if DisplayServer.get_name() == "headless":
		workstation._select_fold()
	else:
		await _click_control(workstation.fold_button)
	_check(workstation.tool_controller.current_tool == ToolController.Tool.FOLD, "the fold spatula can be selected when folding is available")
	_fold_both(workstation)
	_check(workstation.p1_session.phase == P1Session.Phase.PACKAGE and not workstation.bag_button.disabled, "intact folds unlock normal packaging")
	_check(workstation.packaging_choices.visible and workstation.bag_button.global_position.x < 600.0, "contextual packaging choices stay off the six right-hand ingredient slots")
	workstation.bag_button.pressed.emit()
	_check(workstation.p1_session.phase == P1Session.Phase.READY_TO_SERVE, "paper bag completes packaging without a rescue penalty")
	_check(
		workstation.fold_overlay.current_package_texture().resource_path.ends_with("paper_bag_package_v1.png"),
		"paper-bag completion renders its dedicated finished-product artwork"
	)
	_check(workstation.serve_product_button.visible and not workstation.step_action_button.visible, "packaged product itself becomes the explicit customer-handoff target")
	workstation.serve_product_button.pressed.emit()
	_check(workstation.p1_session.phase == P1Session.Phase.HANDOFF and workstation.handoff_product_sprite.visible, "clicking the bag starts the visible handoff instead of opening evaluation")
	_check(not workstation.pancake_visual.visible and not workstation.ingredient_layer.visible, "handoff clears the delivered pancake and fillings from the griddle")
	_check(not workstation.result_panel.visible and not workstation.order_summary_card.visible, "handoff does not force an evaluation panel")
	workstation._complete_handoff_animation()
	_check(
		workstation.p1_session.phase == P1Session.Phase.PAYMENT
		and workstation.customer_portrait.texture.resource_path.ends_with("customer_01_accepting_bag_cropped.tres"),
		"customer acceptance uses the dedicated bag-holding artwork"
	)
	workstation._show_customer_payment()
	_check(
		workstation.payment_sprite.visible
		and workstation.customer_portrait.texture.resource_path.ends_with("customer_01_paying_coins_cropped.tres"),
		"customer payment uses the dedicated paying artwork and starts a visible coin flight"
	)
	workstation._complete_payment_animation()
	_check(
		workstation.p1_session.phase == P1Session.Phase.RESULT
		and workstation.p1_session.order.id == &"classic"
		and workstation.payment_sprite.visible
		and workstation.payment_collection_area.visible
		and workstation.order_summary_card.visible,
		"settled coins remain in the payment slot until the player collects them"
	)
	var settled_coin_rect := Rect2(workstation.payment_sprite.position, workstation.payment_sprite.size)
	var payment_slot_inner_rect := Rect2(workstation.payment_collection_area.position, workstation.payment_collection_area.size)
	_check(
		not workstation.result_panel.visible
		and payment_slot_inner_rect.encloses(settled_coin_rect),
		"large evaluation stays closed and the waiting coin remains fully inside the interactive payment slot"
	)
	_check(
		workstation.payment_collection_area.mouse_entered.is_connected(workstation._collect_payment)
		and workstation.payment_collection_area.gui_input.is_connected(workstation._on_payment_collection_gui_input),
		"the payment slot accepts both mouse sweep and click collection paths"
	)
	workstation.payment_collection_area.mouse_entered.emit()
	_check(
		workstation.p1_session.phase == P1Session.Phase.SPREAD
		and workstation.p1_session.order.id == &"chili_ham"
		and not workstation.payment_sprite.visible
		and not workstation.payment_collection_area.visible
		and workstation.customer_queue.current_customer().id == &"customer_02"
		and workstation.customer_queue.waiting_customers()[0].id == &"customer_03"
		and workstation.customer_queue.waiting_customers()[1].id == &"customer_01"
		and workstation.customer_portrait.texture.resource_path.ends_with("customer_02_neutral_cropped.tres")
		and workstation.waiting_customer_portraits[0].texture.resource_path.ends_with("customer_03_neutral_cropped.tres")
		and workstation.waiting_customer_portraits[1].texture.resource_path.ends_with("customer_01_neutral_cropped.tres"),
		"sweeping the payment slot collects all coins and advances the visible customer queue"
	)
	_check(workstation.customer_line_label.visible and workstation.phase_label.visible, "the next customer order stays actionable behind the optional previous-order summary")
	workstation.summary_view_button.pressed.emit()
	_check(
		workstation.payment_display.is_visible_in_tree()
		and workstation.heat_score_label.is_visible_in_tree()
		and workstation.egg_score_label.is_visible_in_tree()
		and workstation.heat_score_label.text.contains("火候")
		and workstation.egg_score_label.text.contains("摊蛋"),
		"optional order details retain all runtime score dimensions"
	)
	workstation.next_order_button.pressed.emit()
	_check(not workstation.result_panel.visible and workstation.order_summary_card.visible, "closing optional details returns to the non-blocking compact summary")
	workstation.summary_dismiss_button.pressed.emit()
	_check(
		workstation.p1_session.order.id == &"chili_ham"
		and workstation.pancake_model.covered_cell_count() == 0
		and workstation.pancake_visual.visible
		and workstation.ingredient_layer.visible
		and not workstation.order_summary_card.visible,
		"dismissing the previous summary only clears feedback; the next customer was already active"
	)
	workstation.end_business_day()
	_check(
		workstation.daily_bill_panel.visible
		and workstation.daily_bill_stats_label.text.contains("完成 1 单")
		and workstation.daily_bill_stats_label.text.contains("收入 3 金币")
		and workstation.daily_bill_rows.get_child_count() == 4,
		"ending business opens a read-only today bill with one aligned ledger row"
	)

	main.queue_free()
	await process_frame
	await process_frame
	_finish()


func _click_control(control: Control) -> void:
	var center := control.get_global_rect().get_center()
	_send_mouse_motion(center, 0)
	await process_frame
	_send_mouse_button(center, true)
	await process_frame
	_send_mouse_button(center, false)
	await process_frame


func _drag_control_to(control: Control, target: Vector2) -> void:
	var start := control.get_global_rect().get_center()
	_send_mouse_motion(start, 0)
	await process_frame
	_send_mouse_button(start, true)
	await process_frame
	_send_mouse_motion(target, MOUSE_BUTTON_MASK_LEFT)
	await process_frame
	_send_mouse_button(target, false)
	await process_frame


func _hold_control_with_process(workstation: Workstation, control: Control, seconds: float) -> void:
	var center := control.get_global_rect().get_center()
	_send_mouse_motion(center, 0)
	await process_frame
	_send_mouse_button(center, true)
	await process_frame
	workstation._process(seconds)
	_send_mouse_button(center, false)
	await process_frame


func _place_ingredient_from_rack(workstation: Workstation, control: Control, ingredient_type: StringName, target: Vector2) -> void:
	if DisplayServer.get_name() == "headless":
		var ingredient_press := InputEventMouseButton.new()
		ingredient_press.button_index = MOUSE_BUTTON_LEFT
		ingredient_press.pressed = true
		workstation._on_ingredient_gui_input(ingredient_press, ingredient_type)
		workstation._finish_ingredient_drag(target)
	else:
		await _drag_control_to(control, target)


func _send_mouse_button(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	root.push_input(event)


func _send_mouse_motion(position: Vector2, button_mask: MouseButtonMask) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.button_mask = button_mask
	root.push_input(event)


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
	for ring in 4:
		var radius := 6.0 + float(ring) * 9.0
		for step in 36:
			var angle := TAU * float(step) / 36.0
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
