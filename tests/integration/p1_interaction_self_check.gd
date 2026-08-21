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
	game_session.call("set_business_paused", true)
	var elapsed_before_business_pause := workstation.p1_session.elapsed_seconds
	workstation._process(1.0)
	_check(is_equal_approx(workstation.p1_session.elapsed_seconds, elapsed_before_business_pause), "a persisted business pause also freezes the local pancake session clock")
	game_session.call("set_business_paused", false)
	var locked_copy := Workstation._pancake_availability_failure_text({"reason": &"recipe_locked"})
	_check(locked_copy == "煎饼基础配方未解锁，存档状态异常" and not locked_copy.contains("recipe_locked"), "pancake availability maps the internal recipe lock code to player-facing Chinese")
	_check(workstation.customer_portrait != null and workstation.order_amount_label != null and workstation.patience_bar != null, "P1 customer, order and patience nodes are stable scene content")
	var tutorial_patience_before := float(Dictionary(game_session.call("active_formal_order")).get("remaining_patience_seconds", 0.0))
	workstation._process(1.0)
	var tutorial_patience_after := float(Dictionary(game_session.call("active_formal_order")).get("remaining_patience_seconds", 0.0))
	_check(is_equal_approx(tutorial_patience_before, tutorial_patience_after) and workstation.patience_text_label.text == "教学单·不限时", "opening tutorial is visibly unlimited in both the formal service and pancake UI")
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
		not workstation.sauce_refill_button.get_global_rect().intersects(workstation.chili_sauce_refill_button.get_global_rect())
		and is_equal_approx(workstation.sauce_refill_button.get_global_rect().end.x, workstation.chili_sauce_refill_button.get_global_rect().position.x)
		and workstation.chili_sauce_refill_button.get_global_rect().size == Vector2(145.0, 74.0)
		and workstation.sauce_refill_button.get_global_rect().size == Vector2(145.0, 74.0),
		"sweet and chili bottles use adjacent non-overlapping left-to-right 145-by-74 hit regions"
	)
	var initial_renderer_diagnostics: Dictionary = workstation.pancake_surface.get_renderer_diagnostics()
	_check(initial_renderer_diagnostics.chili_sauce_texture != null and initial_renderer_diagnostics.fold_sweet_sauce_texture != null and initial_renderer_diagnostics.fold_chili_sauce_texture != null, "P1 renderer uploads independent sauce fields and fold alpha textures")
	await _test_unflipped_sauce_paths(workstation)
	var first_order_id := StringName(workstation.p1_session.order.get("id", &""))
	var first_payment_coins := int(workstation.p1_session.order.get("payment_coins", 0))
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
	_check(workstation.p1_session.phase == P1Session.Phase.FIRST_SIDE and workstation.step_action_button.visible and not workstation.step_action_button.disabled, "spreader release freezes the shape and exposes the existing flip action without requiring egg")
	_check(workstation.tool_controller.current_tool == ToolController.Tool.NONE and workstation.scraper_button.disabled, "the released batter spreader cannot keep shaping")
	var surface_center := workstation.pancake_surface.get_global_transform_with_canvas() * surface_local_center
	var egg_drop_local := surface_local_center + Vector2(-82.0, 0.0)
	var egg_drop_global := workstation.pancake_surface.get_global_transform_with_canvas() * egg_drop_local
	if DisplayServer.get_name() == "headless":
		var ingredient_press := InputEventMouseButton.new()
		ingredient_press.button_index = MOUSE_BUTTON_LEFT
		ingredient_press.pressed = true
		workstation._on_ingredient_gui_input(ingredient_press, IngredientModel.EGG)
		workstation._finish_ingredient_drag(egg_drop_global)
	else:
		await _drag_control_to(workstation.egg_button, egg_drop_global)
	_check(workstation.p1_session.phase == P1Session.Phase.FIRST_SIDE, "egg remains an optional order ingredient after the pancake shape is accepted")
	_check(workstation.ingredient_model.has_type(IngredientModel.EGG), "dragging from the ingredient rack onto the real pancake surface places business data")
	_check(workstation.pancake_model.has_egg() and workstation.egg_crack_effect.visible and not workstation.egg_crack_artwork.visible, "egg drop starts the non-looping two-frame crack effect before the raw-egg landing state")
	var fixed_egg_grid_center := Vector2.ONE * float(workstation.pancake_model.grid_size - 1) * 0.5
	var egg_placement: Dictionary = workstation.ingredient_model.placements.back()
	var egg_placement_position: Vector2 = egg_placement.get("position", Vector2.ZERO)
	_check(egg_placement_position.is_equal_approx(fixed_egg_grid_center) and _egg_field_centroid(workstation.pancake_model).distance_to(fixed_egg_grid_center) <= 1.0, "off-center egg drop resolves both ingredient data and liquid simulation to the fixed pancake center")
	_check(workstation.egg_crack_effect.position.is_equal_approx(Vector2(workstation.pancake_surface.size.x * 0.5, 0.0)) and workstation.egg_crack_artwork.position.is_equal_approx(surface_local_center), "crack frames use the lowered center stage and raw egg uses the fixed pancake center")
	await create_timer(0.36).timeout
	_check(not workstation.egg_crack_effect.visible and workstation.egg_crack_artwork.visible, "egg crack effect finishes into the existing raw-egg landing artwork")
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
	_check(workstation.pancake_model.is_flipped and workstation.p1_session.phase == P1Session.Phase.SECOND_SIDE, "step action flips into a separately cooking second-side stage")
	_check(
		workstation.tool_controller.current_tool == ToolController.Tool.NONE
		and not workstation.spreader_artwork.visible
		and not workstation.pancake_surface.cursor_is_t_spreader,
		"successful flip returns and hides the egg spreader"
	)
	_check(is_zero_approx(workstation.pancake_model.mean_side_doneness(true)), "the flipped side starts uncooked and requires its own cooking time")
	workstation._process(6.0)
	_check(not workstation.step_action_button.visible and workstation.p1_session.phase == P1Session.Phase.SECOND_SIDE, "second-side fire level has no confirmation gate")
	workstation.set_sauce_unlocked(OrderService.SAUCE_CHILI, true)
	_check(not workstation.sauce_refill_button.disabled and not workstation.chili_sauce_refill_button.disabled, "both sauce bottles respond immediately after flipping")
	if DisplayServer.get_name() == "headless":
		workstation.chili_sauce_refill_button.button_down.emit()
		workstation._process(0.5)
		workstation.chili_sauce_refill_button.button_up.emit()
	else:
		await _hold_control_with_process(workstation, workstation.chili_sauce_refill_button, 0.5)
	var chili_load := float(workstation.sauce_tool_state.load)
	_check(workstation.p1_session.phase == P1Session.Phase.SECOND_SIDE, "clicking a sauce bottle does not interrupt second-side cooking")
	_check(workstation.current_sauce_type == OrderService.SAUCE_CHILI and chili_load > 0.0 and workstation.sauce_blob_overlay.visible, "holding the chili bottle creates a visible chili blob on the pancake")
	_check(workstation.tool_controller.current_tool == ToolController.Tool.SAUCE_BRUSH and workstation.chili_sauce_refill_button.button_pressed and workstation.pancake_surface.cursor_is_sauce_brush, "releasing the chili bottle automatically equips the chili brush and brush cursor")
	var doneness_before_sauce := workstation.pancake_model.mean_side_doneness(true)
	workstation._process(15.0)
	_check(workstation.pancake_model.mean_side_doneness(true) > doneness_before_sauce, "second-side cooking continues while sauce is applied")
	if DisplayServer.get_name() == "headless":
		workstation.sauce_refill_button.button_down.emit()
		workstation._process(0.5)
		workstation.sauce_refill_button.button_up.emit()
	else:
		await _hold_control_with_process(workstation, workstation.sauce_refill_button, 0.5)
	var sweet_load_before_brush := float(workstation.sauce_tool_state.load)
	_check(sweet_load_before_brush > 0.0 and is_equal_approx(float(workstation.sauce_tool_states[OrderService.SAUCE_CHILI].load), chili_load), "sweet and chili squeeze amounts remain independent")
	_check(workstation.tool_controller.current_tool == ToolController.Tool.SAUCE_BRUSH and workstation.sauce_refill_button.button_pressed and not workstation.sauce_brush_button.visible, "releasing the sweet bottle selects its brush without exposing a separate brush button")
	if DisplayServer.get_name() == "headless":
		workstation._sauce_stroke_id = workstation.pancake_model.begin_sauce_stroke()
		workstation._apply_sauce_brush_sample(Vector2(64, 64))
	else:
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
	var sweet_total_before_auto := workstation.pancake_model.total_sauce(OrderService.SAUCE_SWEET)
	var chili_total_before_auto := workstation.pancake_model.total_sauce(OrderService.SAUCE_CHILI)
	workstation.set("_automatic_brush_owned", true)
	workstation._refresh_sauce_brush_upgrade_presentation()
	var automatic_sauce_inventory: Dictionary = game_session.call("inventory_snapshot")
	automatic_sauce_inventory["stock.pancake.sauce.red_chili"] = 4
	game_session.call("save_inventory", automatic_sauce_inventory)
	workstation._on_chili_sauce_squeeze_started()
	workstation._process(0.2)
	workstation._on_sauce_squeeze_ended()
	_check(workstation.tool_controller.current_tool == ToolController.Tool.NONE and workstation.pancake_model.total_sauce(OrderService.SAUCE_CHILI) > chili_total_before_auto, "automatic-brush ownership makes chili bottle release brush immediately and return to empty hands")
	_check(is_equal_approx(workstation.pancake_model.total_sauce(OrderService.SAUCE_SWEET), sweet_total_before_auto), "automatic brushing one bottle leaves the other sauce layer unchanged for two-sauce orders")
	await _place_ingredient_from_rack(workstation, workstation.baocui_button, IngredientModel.BAOCUI, surface_center + Vector2(-70, -30))
	await _place_ingredient_from_rack(workstation, workstation.scallion_button, IngredientModel.SCALLION, surface_center + Vector2(15, 65))
	await _place_ingredient_from_rack(workstation, workstation.baocui_button, IngredientModel.BAOCUI, surface_center + Vector2(70, -35))
	_check(
		workstation.ingredient_model.has_type(IngredientModel.BAOCUI)
		and workstation.ingredient_model.has_type(IngredientModel.SCALLION)
		and workstation.ingredient_model.count_type(IngredientModel.BAOCUI) == 2,
		"opening-day filling controls allow repeated portions after the filling phase unlocks"
	)
	var left_baocui_position: Vector2 = Dictionary(workstation.ingredient_model.placements[1]).get("position", Vector2.ZERO)
	var right_baocui_position: Vector2 = Dictionary(workstation.ingredient_model.placements[3]).get("position", Vector2.ZERO)
	_check(left_baocui_position.x < fixed_egg_grid_center.x - 10.0 and right_baocui_position.x > fixed_egg_grid_center.x + 10.0, "non-egg fillings keep their player-selected off-center drop positions")
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
	workstation.pancake_surface.force_texture_upload()
	var sauce_fold_textures: Dictionary = workstation.pancake_surface.get_renderer_diagnostics()
	var sweet_fold_image: Image = sauce_fold_textures.get("fold_sweet_sauce_image")
	var chili_fold_image: Image = sauce_fold_textures.get("fold_chili_sauce_image")
	_check(_maximum_alpha(sweet_fold_image) > 0.0 and _maximum_alpha(chili_fold_image) > 0.0, "sweet and chili folding textures carry transparent sauce coverage instead of opaque static color")
	_check(sweet_fold_image.get_pixel(0, 0) != chili_fold_image.get_pixel(0, 0), "sweet and chili folding textures keep visibly distinct base colors")
	workstation.fold_model.update_drag(Vector2(58, 64))
	await process_frame
	var moving_fold_diagnostics: Dictionary = workstation.fold_overlay.get_renderer_diagnostics()
	_check(int(moving_fold_diagnostics.get("sauce_front_strip_count", 0)) > 0 and not workstation.sauce_blob_overlay.visible, "a partially folded moving interior face keeps brushed sauce on its UV mesh while hiding the static sauce blob")
	workstation._on_cancel_requested()
	_fold_both(workstation)
	await process_frame
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
	var enclosed_fold_diagnostics: Dictionary = workstation.fold_overlay.get_renderer_diagnostics()
	_check(bool(enclosed_fold_diagnostics.get("sauce_hidden_enclosed", false)) and int(enclosed_fold_diagnostics.get("sauce_front_strip_count", -1)) == 0, "fully folded pancake hides both sauce textures inside the finished shape")
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
	_check(not workstation.serve_product_button.visible and not workstation.step_action_button.visible and not workstation.order_dish_buttons[0].disabled and workstation.order_dish_buttons[0].mouse_filter == Control.MOUSE_FILTER_STOP, "the ready pancake is delivered through the clickable order item")
	workstation._on_customer_slot_pressed(0)
	_check(workstation.p1_session.phase == P1Session.Phase.READY_TO_SERVE, "choosing the customer only focuses its order")
	var completed_order_id := StringName(workstation.get("_formal_order_id"))
	if DisplayServer.get_name() == "headless":
		workstation._on_order_dish_pressed(0)
	else:
		await _click_control(workstation.order_dish_buttons[0])
	var delivered_order := Dictionary(game_session.call("formal_order", completed_order_id))
	var tray_settlement: Dictionary = Dictionary(workstation.get("_pending_tray_settlement"))
	var tray_payment_amount := int(tray_settlement.get("earned_coins", 0))
	_check(StringName(delivered_order.get("state", &"")) == &"settled" and Array(Dictionary(Array(delivered_order.get("items", []))[0]).get("attached_products", [])).size() == 1, "clicking the order item consumes and settles exactly one ready pancake")
	_check(workstation.pancake_model.covered_cell_count() == 0 and workstation.ingredient_model.placements.is_empty(), "order-card delivery clears the delivered pancake from the griddle")
	_check(StringName(workstation.get("_formal_order_id")) != completed_order_id and workstation.p1_session.phase == P1Session.Phase.SPREAD, "the next customer starts immediately without waiting for coin collection")
	_check(
		workstation.get_node_or_null("SafeArea/PaymentCollectionArea") == null,
		"the obsolete broad payment-slot hit target has been removed"
	)
	_check(
		not bool(tray_settlement.get("order_success", true))
		and Array(tray_settlement.get("mismatch_reasons", [])).has("sauce_ids"),
		"a mismatched direct delivery reaches customer feedback and the bill without blocking the queue"
	)
	var next_order_id := StringName(workstation.p1_session.order.get("id", &""))
	_check(
		workstation.p1_session.phase == P1Session.Phase.SPREAD
		and str(next_order_id).begins_with("order.pancake.")
		and (workstation.pending_payment_button.visible == (tray_payment_amount > 0)),
		"next customer is active while only positive payments remain available for click collection"
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
		and workstation.daily_bill_stats_label.text.contains("收入 %d 金币" % tray_payment_amount)
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


func _prepare_first_side(workstation: Workstation) -> void:
	workstation.reset_pancake()
	_fill_product_base(workstation.pancake_model)
	workstation.pour_used = true
	workstation.set("_spread_shape_locked", true)
	workstation.p1_session.confirm_spread(workstation.pancake_model)
	workstation._refresh_p1_ui()


func _test_unflipped_sauce_paths(workstation: Workstation) -> void:
	_prepare_first_side(workstation)
	workstation.set_sauce_unlocked(OrderService.SAUCE_CHILI, true)
	_check(
		not workstation.sauce_refill_button.disabled
		and not workstation.chili_sauce_refill_button.disabled
		and workstation.step_action_button.visible,
		"both unlocked sauce bottles are available alongside flip after spreading"
	)
	workstation._on_sauce_squeeze_started()
	workstation._process(0.18)
	workstation._on_sauce_squeeze_ended()
	_check(
		workstation.p1_session.phase == P1Session.Phase.FIRST_SIDE
		and not workstation.pancake_model.is_flipped
		and workstation.step_action_button.visible
		and not workstation.step_action_button.disabled
		and workstation.tool_controller.current_tool == ToolController.Tool.SAUCE_BRUSH,
		"first manual sauce squeeze keeps flip available and equips the brush"
	)
	workstation._sauce_stroke_id = workstation.pancake_model.begin_sauce_stroke()
	workstation._apply_sauce_brush_sample(Vector2(64, 64))
	var sweet_total := workstation.pancake_model.total_sauce(OrderService.SAUCE_SWEET)
	workstation.set("_automatic_brush_owned", true)
	workstation._refresh_sauce_brush_upgrade_presentation()
	workstation._on_chili_sauce_squeeze_started()
	workstation._process(0.18)
	workstation._on_sauce_squeeze_ended()
	_check(
		sweet_total > 0.0
		and workstation.pancake_model.total_sauce(OrderService.SAUCE_CHILI) > 0.0
		and workstation.p1_session.phase == P1Session.Phase.FIRST_SIDE
		and workstation.step_action_button.visible
		and not workstation.step_action_button.disabled,
		"manual sweet sauce and automatic chili sauce both preserve the available flip action"
	)
	workstation._advance_p1_step()
	_check(
		workstation.pancake_model.is_flipped
		and workstation.p1_session.phase == P1Session.Phase.SECOND_SIDE
		and workstation.step_action_button.visible,
		"sauce-covered pancake can still flip into second-side cooking"
	)
	var fold_edge := Vector2(workstation.pancake_surface.size.x * 0.12, workstation.pancake_surface.size.y * 0.5)
	workstation._on_pointer_started(fold_edge)
	_check(workstation.p1_session.phase == P1Session.Phase.FOLD and workstation.fold_model.active_region != PancakeFoldModel.REGION_NONE, "grabbing the edge starts folding after the sauce-covered flip")
	workstation._on_cancel_requested()

	workstation.set("_automatic_brush_owned", false)
	workstation._refresh_sauce_brush_upgrade_presentation()
	_prepare_first_side(workstation)
	var surface_center := workstation.pancake_surface.get_global_transform_with_canvas() * (workstation.pancake_surface.size * 0.5)
	await _place_ingredient_from_rack(workstation, workstation.baocui_button, IngredientModel.BAOCUI, surface_center + Vector2(-45.0, -20.0))
	_check(
		workstation.p1_session.phase == P1Session.Phase.FIRST_SIDE
		and not workstation.pancake_model.is_flipped
		and not workstation.sauce_refill_button.disabled
		and workstation.step_action_button.visible
		and workstation.step_action_button.disabled
		and workstation.step_action_button.tooltip_text.contains("小料"),
		"placing a topping first keeps first-side cooking and sauce available while leaving a visible disabled flip explanation"
	)
	workstation._on_sauce_squeeze_started()
	workstation._process(0.12)
	workstation._on_sauce_squeeze_ended()
	_check(float(workstation.sauce_tool_states[OrderService.SAUCE_SWEET].get("load")) > 0.0, "sauce can still be added after a pre-flip topping")

	workstation.reset_pancake()
	workstation.set("_automatic_brush_owned", false)
	workstation._refresh_sauce_brush_upgrade_presentation()


func _egg_field_centroid(model: PancakeModel) -> Vector2:
	var weighted_position := Vector2.ZERO
	var total_weight := 0.0
	for index in model.egg_white.size():
		var weight := float(model.egg_white[index]) + float(model.egg_yolk[index])
		if weight <= 0.0:
			continue
		weighted_position += Vector2(index % model.grid_size, floori(float(index) / float(model.grid_size))) * weight
		total_weight += weight
	return weighted_position / maxf(total_weight, 0.000001)


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


func _maximum_alpha(image: Image) -> float:
	var maximum := 0.0
	for y in image.get_height():
		for x in image.get_width():
			maximum = maxf(maximum, image.get_pixel(x, y).a)
	return maximum


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
