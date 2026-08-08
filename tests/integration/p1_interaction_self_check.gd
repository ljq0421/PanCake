extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const PAYMENT_COIN_MODEL := preload("res://scripts/gameplay/payment_coin_model.gd")

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
	_check(workstation.customer_portrait != null and workstation.order_amount_label != null and workstation.patience_bar != null, "P1 customer, order and patience nodes are stable scene content")
	_check(workstation.customer_portrait.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "cropped customer artwork keeps its original proportions")
	var pan_base := workstation.get_node("SafeArea/PanBase") as Control
	_check(
		workstation.customer_portrait.texture.resource_path.ends_with("_cropped.tres")
		and Rect2(workstation.customer_portrait.position, workstation.customer_portrait.size) == Rect2(800.0, 222.0, 270.0, 406.0),
		"cropped customer artwork uses the initial-unlock customer bay"
	)
	_check(
		pan_base != null
		and pan_base.position.distance_to(Vector2(750.0, 562.0)) <= 1.0
		and pan_base.size.distance_to(Vector2(420.0, 382.0)) <= 1.0,
		"griddle container uses the confirmed twenty-percent-smaller initial-unlock geometry"
	)
	_check(workstation.ingredient_layer != null and workstation.egg_button != null and workstation.scallion_button != null, "P1 ingredient rack and pancake layer are stable scene content")
	_check(workstation.chili_sauce_refill_button != null and workstation.heat_slider != null and not workstation.heat_slider.visible and not workstation.heat_slider.editable and is_equal_approx(workstation.p1_session.heat_level, 0.50), "P1 owns two-sauce selection while griddle heat stays fixed at its default")
	_check(
		not workstation.sauce_refill_button.get_global_rect().intersects(workstation.chili_sauce_refill_button.get_global_rect()),
		"sweet and chili bottle hit regions do not overlap"
	)
	_check(workstation.pancake_surface.get_renderer_diagnostics().chili_sauce_texture != null, "P1 renderer uploads the independent chili-sauce field")
	var first_order_id := StringName(workstation.p1_session.order.get("id", &""))
	var first_payment_coins := int(workstation.p1_session.order.get("payment_coins", 0))
	var first_payment_denominations: Array[int] = PAYMENT_COIN_MODEL.decompose(first_payment_coins)
	_check(
		str(first_order_id).begins_with("order.pancake.")
		and first_payment_coins > 0
		and workstation.order_coin_icon.visible
		and workstation.order_amount_label.text == str(first_payment_coins)
		and workstation.order_dish_icons[0].visible,
		"first customer receives a concrete data-driven order"
	)
	_check(not workstation.step_action_button.visible and workstation.step_action_button.text != "完成摊饼", "spreading adds no explicit completion action")
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
	var surface_local_center := workstation.pancake_surface.size * 0.5
	workstation._on_pointer_ended(surface_local_center)
	workstation._refresh_p1_ui()
	_check(workstation.p1_session.phase == P1Session.Phase.SPREAD and not workstation.step_action_button.visible, "spreader release freezes the shape without exposing a completion button")
	_check(workstation.tool_controller.current_tool == ToolController.Tool.NONE and workstation.scraper_button.disabled, "the released batter spreader cannot keep shaping")
	var surface_center := workstation.pancake_surface.get_global_transform_with_canvas() * surface_local_center
	if DisplayServer.get_name() == "headless":
		var ingredient_press := InputEventMouseButton.new()
		ingredient_press.button_index = MOUSE_BUTTON_LEFT
		ingredient_press.pressed = true
		workstation._on_ingredient_gui_input(ingredient_press, IngredientModel.EGG)
		workstation._finish_ingredient_drag(surface_center)
	else:
		await _drag_control_to(workstation.egg_button, surface_center)
	_check(workstation.p1_session.phase == P1Session.Phase.FIRST_SIDE, "the same egg interaction implicitly accepts the current pancake shape")
	_check(workstation.ingredient_model.has_type(IngredientModel.EGG), "dragging from the ingredient rack onto the real pancake surface places business data")
	_check(workstation.pancake_model.has_egg() and workstation.egg_crack_artwork.visible, "egg drop creates the liquid simulation and visible raw-egg landing state")
	_check(workstation.tool_controller.current_tool == ToolController.Tool.SCRAPER, "egg drop automatically selects the existing T-shaped spreader")
	workstation._refresh_p1_ui()
	_check(
		not workstation.step_action_button.disabled
		and workstation.step_action_button.text.contains("尚未就绪")
		and workstation.step_action_button.tooltip_text.contains("降低"),
		"the real flip control remains enabled before readiness and warns about the order-rating penalty"
	)
	_spread_egg_with_workstation(workstation)
	var egg_summary := workstation.pancake_model.calculate_egg_spread_summary()
	_check(workstation.pancake_model.yolk_broken and not workstation.egg_crack_artwork.visible, "real workstation spread samples break the yolk and replace the landing sprite with the grid layer")
	_check(float(egg_summary.coverage_ratio) >= workstation.parameters.egg_minimum_spread_coverage, "continuous T-spreader input reaches the model-backed egg coverage gate")
	workstation.pancake_surface.force_texture_upload()
	_check(workstation.pancake_surface.get_renderer_diagnostics().egg_texture != null, "renderer uploads the spread egg field")
	workstation.pancake_model.doneness.fill(0.62)
	workstation.step_action_button.pressed.emit()
	_check(workstation.pancake_model.is_flipped and workstation.p1_session.phase == P1Session.Phase.SAUCE_AND_FILLINGS, "step action flips and immediately enters sauce and fillings")
	_check(
		workstation.tool_controller.current_tool == ToolController.Tool.NONE
		and not workstation.spreader_artwork.visible
		and not workstation.pancake_surface.cursor_is_t_spreader,
		"successful flip returns and hides the egg spreader"
	)
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
	await _place_ingredient_from_rack(workstation, workstation.scallion_button, IngredientModel.SCALLION, surface_center + Vector2(15, 65))
	await _place_ingredient_from_rack(workstation, workstation.baocui_button, IngredientModel.BAOCUI, surface_center + Vector2(70, -35))
	_check(
		workstation.ingredient_model.has_type(IngredientModel.BAOCUI)
		and workstation.ingredient_model.has_type(IngredientModel.SCALLION)
		and workstation.ingredient_model.count_type(IngredientModel.BAOCUI) == 2,
		"opening-day filling controls allow repeated portions after the filling phase unlocks"
	)
	_check(not workstation.ham_button.visible and workstation.ham_button.disabled, "locked ham remains absent and non-interactive on the opening-day workstation")
	workstation.ingredient_model.placements[1]["position"] = Vector2(28, 56)
	workstation.ingredient_model.placements[2]["position"] = Vector2(100, 58)
	workstation.ingredient_model.changed.emit()
	workstation.step_action_button.pressed.emit()
	_check(workstation.p1_session.phase == P1Session.Phase.FOLD and workstation.tool_controller.current_tool == ToolController.Tool.FOLD, "step action enters the continuous folding path")
	workstation.tool_controller.clear_tool()
	var fold_edge := Vector2(workstation.pancake_surface.size.x * 0.12, workstation.pancake_surface.size.y * 0.5)
	workstation._on_pointer_started(fold_edge)
	_check(workstation.tool_controller.current_tool == ToolController.Tool.FOLD and workstation.fold_model.active_region != PancakeFoldModel.REGION_NONE, "an exposed pancake edge starts folding without an extra fold-tool click")
	workstation._on_cancel_requested()
	_fold_both(workstation)
	_check(
		workstation.ingredient_layer.visual_alpha_for(IngredientModel.BAOCUI) <= 0.001
		and workstation.ingredient_layer.visual_alpha_for(IngredientModel.SCALLION) <= 0.001,
		"all opening-day fillings are visually enclosed after both pancake sides are folded"
	)
	var surface_material := workstation.pancake_visual.material as ShaderMaterial
	_check(
		not workstation.sauce_blob_overlay.visible
		and is_equal_approx(float(surface_material.get_shader_parameter(&"fillings_enclosed")), 1.0),
		"folding both sides encloses sauce blobs and the brushed sauce layer"
	)
	_check(workstation.p1_session.phase == P1Session.Phase.PACKAGE and not workstation.bag_button.disabled, "intact folds unlock normal packaging")
	_check(
		workstation.packaging_choices.visible
		and not workstation.bag_button.get_global_rect().intersects(workstation.get_node("SafeArea/IngredientRack").get_global_rect()),
		"contextual packaging choices stay off the right-hand ingredient trays"
	)
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
		workstation._current_payment_amount == first_payment_coins
		and workstation._payment_flight_sprites.size() == first_payment_denominations.size()
		and workstation._current_payment_denominations == first_payment_denominations
		and workstation.customer_portrait.texture.resource_path.ends_with("customer_01_paying_coins_cropped.tres"),
		"customer payment uses the dedicated paying artwork and starts the order's denomination coin flights"
	)
	workstation._complete_payment_animation()
	var next_order_id := StringName(workstation.p1_session.order.get("id", &""))
	_check(
		workstation.p1_session.phase == P1Session.Phase.SPREAD
		and str(next_order_id).begins_with("order.pancake.")
		and workstation.payment_coin_model.pending_total == first_payment_coins
		and workstation.payment_coin_model.pending_denominations == first_payment_denominations
		and workstation._pending_payment_sprites.size() == first_payment_denominations.size()
		and not workstation.payment_collection_area.visible
		and workstation.order_summary_card.visible,
		"settled denomination coins remain individually clickable while the next customer starts automatically"
	)
	for coin in workstation._pending_payment_sprites:
		_check(coin.mouse_filter == Control.MOUSE_FILTER_STOP and coin.gui_input.is_connected(workstation._on_payment_coin_gui_input), "each visible denomination coin owns its exact click target")
	_check(
		not workstation.payment_collection_area.pressed.is_connected(workstation._collect_payment)
		and not workstation.payment_collection_area.mouse_entered.is_connected(workstation._collect_payment),
		"no broad payment-slot hit target or hover collection path remains"
	)
	var customer_before_collection := Dictionary(workstation.customer_queue.current_customer()).duplicate(true)
	var waiting_before_collection := Array(workstation.customer_queue.waiting_customers()).duplicate(true)
	var portrait_before_collection := workstation.customer_portrait.texture.resource_path
	if DisplayServer.get_name() == "headless":
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		workstation._pending_payment_sprites[0].gui_input.emit(click)
	else:
		await _click_control(workstation._pending_payment_sprites[0])
	_check(
		workstation.p1_session.phase == P1Session.Phase.SPREAD
		and StringName(workstation.p1_session.order.get("id", &"")) == next_order_id
		and workstation.payment_coin_model.pending_total == 0
		and workstation._pending_payment_sprites.is_empty()
		and not workstation.payment_collection_area.visible
		and workstation.customer_queue.current_customer() == customer_before_collection
		and workstation.customer_queue.waiting_customers() == waiting_before_collection
		and workstation.customer_portrait.texture.resource_path == portrait_before_collection,
		"clicking a visible coin collects every pending coin without changing the active customer"
	)
	_check(workstation.customer_line_label.visible and workstation.phase_label.visible, "the next customer order stays actionable behind the optional previous-order summary")
	workstation._set_customer_portrait_state(P1Session.REACTION_VERY_UNHAPPY)
	var current_customer_id := str(workstation.customer_queue.current_customer().get("id", &"customer_01"))
	_check(
		workstation.customer_portrait.texture.resource_path.ends_with("%s_impatient_cropped.tres" % current_customer_id)
		and workstation.customer_portrait.modulate.g < 0.8,
		"the stronger unhappy state keeps the impatient face and adds a visibly intensified reaction"
	)
	workstation._set_customer_portrait_state(P1Session.REACTION_NEUTRAL)
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
		StringName(workstation.p1_session.order.get("id", &"")) == next_order_id
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
		and workstation.daily_bill_stats_label.text.contains("收入 %d 金币" % first_payment_coins)
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
	var surface_center := workstation.pancake_surface.size * 0.5
	workstation._on_pointer_started(surface_center)
	for ring in 4:
		var radius := 6.0 + float(ring) * 9.0
		for step in 36:
			var angle := TAU * float(step) / 36.0
			var radial := Vector2(cos(angle), sin(angle) * workstation.parameters.pan_height_ratio)
			workstation._process_scraper(center + radial * radius, 1.0 / 60.0)
	workstation._on_pointer_ended(surface_center)


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
