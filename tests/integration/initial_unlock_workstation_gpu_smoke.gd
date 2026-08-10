extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const SCREENSHOT_PATH := "res://tmp/validation/initial_unlock_workstation_gpu_1920x1080.png"
const SCREENSHOT_1280_PATH := "res://tmp/validation/initial_unlock_workstation_gpu_1280x720.png"
const REFILL_SCREENSHOT_PATH := "res://tmp/validation/workstation_hold_refill_gpu_1920x1080.png"
const EGG_CRACK_SCREENSHOT_PATH := "res://tmp/validation/egg_crack_above_griddle_gpu_1920x1080.png"

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("GPU smoke must run without --headless")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	var game_session := root.get_node_or_null("GameSession")
	if game_session != null:
		game_session.call("begin_new_game")
		game_session.call("credit_coins", 20)
		var initial_inventory: Dictionary = game_session.call("inventory_snapshot")
		initial_inventory["stock.pancake.egg"] = 2
		initial_inventory["stock.pancake.baocui"] = 2
		initial_inventory["stock.pancake.scallion"] = 2
		game_session.call("save_inventory", initial_inventory)
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	for _frame in 12:
		await process_frame
	var workstation := game.get_node("Workstation")
	var controller := workstation.get_node("SafeArea/PancakeWorkstationInteractionController")
	await process_frame
	await process_frame
	var feedback_progression: RefCounted = game_session.call("progression_service")
	var feedback_owned_growth: Dictionary = Dictionary(feedback_progression.get("owned_growth_ids")).duplicate(true)
	for growth_id in [&"growth.automation.pancake.press_once", &"growth.capacity.pancake_holding_tray.two_slots", &"growth.add_on.pancake.red_chili"]:
		feedback_owned_growth[growth_id] = true
	feedback_progression.set("owned_growth_ids", feedback_owned_growth)
	var feedback_unlocked_stock: Dictionary = Dictionary(feedback_progression.get("unlocked_stock_ids")).duplicate(true)
	feedback_unlocked_stock[&"stock.pancake.sauce.red_chili"] = true
	feedback_progression.set("unlocked_stock_ids", feedback_unlocked_stock)
	workstation.call("apply_progression_effects", game_session.call("five_area_progression_snapshot"))
	workstation.call("_refresh_pancake_holding_tray")
	var t_spreader := workstation.get_node("SafeArea/LeftRack/ScraperButton") as Button
	var automatic_brush := workstation.get_node("SafeArea/LeftRack/SauceBrushButton") as Button
	var press_spreader := workstation.get_node("SafeArea/LeftRack/PressSpreaderButton") as Button
	var legacy_automatic_brush := workstation.get_node("SafeArea/LeftRack/AutomaticSauceBrushButton") as Button
	var empty_holding_slot := workstation.get_node("SafeArea/PancakeHoldingTray/PancakeHoldingSlot01") as Button
	_check(t_spreader.visible and press_spreader.visible and not automatic_brush.visible and automatic_brush.disabled and not legacy_automatic_brush.visible, "the T spreader and independent press remain visible while both standalone sauce-brush controls stay outside the player path")
	var press_center := press_spreader.get_global_rect().get_center()
	_move_at(press_center)
	await process_frame
	var press_hovered := root.gui_get_hovered_control()
	_press_at(press_center)
	await process_frame
	_release_at(press_center)
	await process_frame
	_check(press_hovered == press_spreader, "the independent press owns its visible click region; hovered=%s" % str(press_hovered.get_path() if press_hovered != null else "none"))
	_check(not (workstation.get_node("SafeArea/BottomStrip/ToolStatusLabel") as Label).text.is_empty(), "real independent-press click outside its window gives player-visible guidance")
	var saved_order: Dictionary = workstation.p1_session.order.duplicate(true)
	workstation.pancake_model.coverage.fill(1.0)
	workstation.pancake_model.thickness.fill(0.5)
	workstation.pancake_model.changed.emit()
	workstation.p1_session.phase = P1Session.Phase.SAUCE_AND_FILLINGS
	workstation.call("_refresh_p1_ui")
	controller.call("_refresh_sauce_controls")
	var sweet_sauce_button := workstation.get_node("SafeArea/RightRack/SauceRefillButton") as Button
	var chili_sauce_button := workstation.get_node("SafeArea/RightRack/ChiliSauceRefillButton") as Button
	_check(chili_sauce_button.visible and not chili_sauce_button.disabled and chili_sauce_button.mouse_filter == Control.MOUSE_FILTER_STOP and is_equal_approx(chili_sauce_button.get_global_rect().end.x, sweet_sauce_button.get_global_rect().position.x), "unlocked chili owns an adjacent real hit region immediately left of sweet sauce")
	var chili_center := chili_sauce_button.get_global_rect().get_center()
	_move_at(chili_center)
	await process_frame
	var chili_hovered := root.gui_get_hovered_control()
	_press_at(chili_center)
	await process_frame
	_release_at(chili_center)
	await process_frame
	_check(
		chili_hovered == chili_sauce_button
		and workstation.current_sauce_type == &"red_chili"
		and float(workstation.sauce_tool_states[&"red_chili"].load) > 0.0
		and workstation.tool_controller.current_tool == ToolController.Tool.SAUCE_BRUSH
		and workstation.pancake_surface.cursor_is_sauce_brush
		and workstation.pancake_surface.cursor_sauce_color.is_equal_approx(Color(0.82, 0.055, 0.025, 0.98)),
		"without the automatic brush, real chili pointer release loads and equips the red manual brush; hovered=%s sauce=%s tool=%s load=%s squeezing=%s" % [
			str(chili_hovered.get_path() if chili_hovered != null else "none"),
			str(workstation.pancake_model.total_sauce(&"red_chili")),
			str(workstation.tool_controller.current_tool),
			str(workstation.sauce_tool_states[&"red_chili"].load),
			str(workstation.get("_squeezing_sauce")),
		]
	)
	var sauce_surface_center: Vector2 = workstation.pancake_surface.get_global_rect().get_center()
	await _slow_drag(sauce_surface_center - Vector2(35.0, 0.0), sauce_surface_center + Vector2(35.0, 0.0), 12)
	await process_frame
	_check(workstation.pancake_model.total_sauce(&"red_chili") > 0.0, "real pointer dragging the equipped red brush writes chili concentration into the pancake model")
	feedback_owned_growth[&"growth.automation.pancake.auto_sauce_brush"] = true
	feedback_progression.set("owned_growth_ids", feedback_owned_growth)
	workstation.call("apply_progression_effects", game_session.call("five_area_progression_snapshot"))
	var sweet_center := sweet_sauce_button.get_global_rect().get_center()
	_move_at(sweet_center)
	await process_frame
	var sweet_hovered := root.gui_get_hovered_control()
	_press_at(sweet_center)
	await process_frame
	_release_at(sweet_center)
	await process_frame
	_check(sweet_hovered == sweet_sauce_button and workstation.pancake_model.total_sauce(&"sweet_flour") > 0.0, "real sweet pointer release uses the same bottle-to-automatic-brush path")
	workstation.p1_session.start(saved_order)
	workstation.call("reset_pancake")
	_move_at(empty_holding_slot.get_global_rect().get_center())
	await process_frame
	_check(empty_holding_slot.disabled and empty_holding_slot.mouse_filter == Control.MOUSE_FILTER_IGNORE and root.gui_get_hovered_control() != empty_holding_slot, "holding slots are real-pointer display surfaces rather than delivery controls")
	var locked_click_layers := workstation.get_node("SafeArea/FiveAreaStationClickLayers") as Control
	for click_layer_name in [&"FreshSoyMilkLockedClickLayer", &"YoutiaoLockedClickLayer", &"PackagedDrinkLockedClickLayer", &"SteamerLockedClickLayer"]:
		var click_layer := locked_click_layers.get_node(NodePath(str(click_layer_name))) as Button
		_click_control(click_layer)
		await process_frame
		_check(not str(click_layer.get_meta(&"unlock_condition", "")).is_empty(), "real pointer click reaches %s and preserves its explicit lock condition" % click_layer_name)
	await RenderingServer.frame_post_draw
	var output_absolute := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(output_absolute.get_base_dir())
	var initial_image := root.get_texture().get_image()
	var save_error := initial_image.save_png(output_absolute)
	_check(save_error == OK and initial_image.get_size() == Vector2i(1920, 1080), "captured the untouched opening-day workstation in a real 1920x1080 GPU frame")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	for _frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var output_1280_absolute := ProjectSettings.globalize_path(SCREENSHOT_1280_PATH)
	var image_1280 := root.get_texture().get_image()
	var save_1280_error := image_1280.save_png(output_1280_absolute)
	_check(save_1280_error == OK and image_1280.get_size() == Vector2i(1280, 720), "captured the workstation layout in a real 1280x720 GPU frame")
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	for _frame in 6:
		await process_frame
	var discard := workstation.get_node("SafeArea/DiscardCurrentPancakeButton") as Button
	var discard_rect := Rect2(1450.0, 902.0, 150.0, 52.0)
	_check(discard != null and discard.get_global_rect().position.distance_to(discard_rect.position) <= 1.0 and discard.get_global_rect().size.distance_to(discard_rect.size) <= 1.0 and discard.get_global_rect().end.y <= 956.0, "discard-current-pancake is a real 150x52 control above, not over, the square material row")
	if discard != null:
		_move_at(discard.get_global_rect().get_center())
		await process_frame
		var discard_hovered := root.gui_get_hovered_control()
		_press_at(discard.get_global_rect().get_center())
		await process_frame
		_release_at(discard.get_global_rect().get_center())
		await process_frame
		_check(discard_hovered == discard and discard.visible and not discard.disabled, "real pointer click reaches the relocated redo control")
	var ladle := workstation.get_node("SafeArea/LeftRack/LadleButton") as Button
	var egg := workstation.get_node("SafeArea/IngredientRack/EggButton") as Button
	var baocui := workstation.get_node("SafeArea/IngredientRack/BaocuiButton") as Button
	var surface := workstation.get_node("SafeArea/PanBase/PancakeSurface") as Control
	var outside_pan_press := InputEventMouseButton.new()
	outside_pan_press.button_index = MOUSE_BUTTON_LEFT
	outside_pan_press.pressed = true
	outside_pan_press.position = Vector2(surface.size.x * 0.05, surface.size.y * 0.05)
	surface.call("_gui_input", outside_pan_press)
	_check(not bool(surface.get("pointer_pressed")), "the interactive pancake surface rejects a local click outside the elliptical cooking face")
	_click_control(ladle)
	await process_frame
	_check(bool(workstation.get("pour_used")), "real GUI click on the ladle performs the established automatic center pour")
	await _click_control_settled(press_spreader)
	await process_frame
	_check(
		workstation.p1_session.phase == P1Session.Phase.FIRST_SIDE and bool(workstation.get("_spread_shape_locked")),
		"one real independent-press click completes the pancake skin and enters the egg stage; visible=%s disabled=%s phase=%s status=%s" % [press_spreader.visible, press_spreader.disabled, workstation.p1_session.phase, (workstation.get_node("SafeArea/BottomStrip/ToolStatusLabel") as Label).text],
	)
	_check(float(workstation.pancake_model.calculate_summary().coverage_ratio) >= 0.79, "the real independent-press click creates complete standard coverage")
	var edge_global := surface.global_position + Vector2(surface.size.x * 0.10, surface.size.y * 0.50)
	var inner_global := surface.global_position + Vector2(surface.size.x * 0.22, surface.size.y * 0.50)
	await _slow_drag(edge_global, inner_global, 18)
	await process_frame
	var pointer_local: Vector2 = surface.get("pointer_local_position")
	_check(pointer_local.distance_to(Vector2(surface.size.x * 0.22, surface.size.y * 0.50)) < 3.0, "GPU pointer path reaches the scaled griddle edge and maps into local space")
	var off_center_egg_drop := surface.get_global_rect().get_center() + Vector2(72.0, 0.0)
	_drag(egg.get_global_rect().get_center(), off_center_egg_drop)
	await process_frame
	var ingredient_model: RefCounted = workstation.get("ingredient_model")
	_check(bool(ingredient_model.call("has_type", &"egg")), "real GUI drag places a direct ingredient on the scaled surface")
	var egg_crack_effect := workstation.get_node("SafeArea/PanBase/PancakeSurface/EggCrackEffect") as AnimatedSprite2D
	var egg_crack_artwork := workstation.get_node("SafeArea/PanBase/PancakeSurface/EggCrackArtwork") as Sprite2D
	var gpu_egg_placement: Dictionary = workstation.ingredient_model.placements.back()
	var gpu_egg_placement_position: Vector2 = gpu_egg_placement.get("position", Vector2.ZERO)
	var gpu_egg_grid_center := Vector2.ONE * float(workstation.pancake_model.grid_size - 1) * 0.5
	_check(gpu_egg_placement_position.is_equal_approx(gpu_egg_grid_center), "real off-center egg drop stores the egg ingredient at the fixed model center")
	_check(egg_crack_effect.visible and egg_crack_effect.position.is_equal_approx(Vector2(surface.size.x * 0.5, 0.0)) and egg_crack_artwork.position.is_equal_approx(surface.size * 0.5), "real off-center egg drop displays the lowered crack frames and raw egg at the fixed pancake center")
	await RenderingServer.frame_post_draw
	var egg_crack_output_absolute := ProjectSettings.globalize_path(EGG_CRACK_SCREENSHOT_PATH)
	var egg_crack_image := root.get_texture().get_image()
	var egg_crack_save_error := egg_crack_image.save_png(egg_crack_output_absolute)
	_check(egg_crack_save_error == OK and egg_crack_image.get_size() == Vector2i(1920, 1080), "captured the active above-griddle egg crack effect in a real GPU frame")
	_check(workstation.tool_controller.current_tool == ToolController.Tool.SCRAPER and t_spreader.button_pressed, "placing egg automatically restores the T spreader and never reuses the press")
	var stock_model: RefCounted = workstation.get("ingredient_stock_model")
	_check(int(stock_model.call("current", &"egg")) == 1, "short real GUI drag consumes exactly one visible egg portion")
	var flip_button := workstation.get_node("SafeArea/P1ControlBar/StepActionButton") as Button
	_move_at(flip_button.get_global_rect().get_center())
	await process_frame
	var flip_hovered := root.gui_get_hovered_control()
	await _click_control_settled(flip_button)
	await process_frame
	_check(flip_hovered == flip_button, "five-area passive station layer does not cover the real flip button")
	_check(workstation.pancake_model.is_flipped and workstation.p1_session.phase == P1Session.Phase.SAUCE_AND_FILLINGS, "real GPU pointer click completes the flip interaction")

	_check(bool(egg.get_meta(&"refill_enabled", false)), "the real main-game egg tray supports direct hold refill")
	_check(is_equal_approx(float(egg.get("hold_threshold_seconds")), 0.1), "the real main-game egg tray uses the 0.1-second hold threshold")
	_check(workstation.get_node_or_null("SafeArea/ExpansionLayout/RightZone/RefillDrawer") == null, "the real main-game workstation has no refill drawer")
	var egg_stock := &"stock.pancake.egg"
	var egg_unit_seconds := float(controller.get("_restock").call("status", egg_stock).unit_seconds)
	_check(is_equal_approx(egg_unit_seconds, 0.20), "real main-game egg refill uses the six-times-speed 0.20-second per-unit duration")
	var refill_service: RefCounted = controller.get("_restock")
	var egg_tray_center := egg.get_global_rect().get_center()
	_press_at(egg_tray_center)
	await process_frame
	var first_hold_started := await _wait_until(func() -> bool: return StringName(controller.get("_active_refill_stock_id")) == egg_stock, 0.50)
	_check(first_hold_started, "an unmoved real GUI press starts refill directly on the egg tray")
	var first_unit_completed := await _wait_until(func() -> bool: return int(stock_model.call("current", &"egg")) >= 2, 0.10 + egg_unit_seconds + 0.50)
	_release_at(egg_tray_center)
	await process_frame
	_check(first_unit_completed and int(stock_model.call("current", &"egg")) == 2, "continuous real-time hold adds exactly the first completed stock portion")

	_press_at(egg_tray_center)
	await process_frame
	var partial_hold_started := await _wait_until(func() -> bool: return StringName(controller.get("_active_refill_stock_id")) == egg_stock, 0.50)
	var partial_progress_reached := await _wait_until(
		func() -> bool: return float(refill_service.call("status", egg_stock).progress_seconds) >= egg_unit_seconds * 0.30,
		egg_unit_seconds,
	)
	var outside_tray := egg_tray_center + Vector2(-180.0, 0.0)
	_move_at(outside_tray)
	await process_frame
	_release_at(outside_tray)
	await process_frame
	var saved_progress := float(refill_service.call("status", egg_stock).progress_seconds)
	_check(partial_hold_started and partial_progress_reached and StringName(controller.get("_active_refill_stock_id")) == &"" and int(stock_model.call("current", &"egg")) == 2 and saved_progress >= egg_unit_seconds * 0.30 and saved_progress < egg_unit_seconds, "real GUI release outside the tray still stops refill and keeps unfinished time internally")
	_press_at(egg_tray_center)
	await process_frame
	var resumed_hold_started := await _wait_until(func() -> bool: return StringName(controller.get("_active_refill_stock_id")) == egg_stock, 0.50)
	var resumed_unit_completed := await _wait_until(func() -> bool: return int(stock_model.call("current", &"egg")) >= 3, egg_unit_seconds + 0.50)
	_release_at(egg_tray_center)
	await process_frame
	_check(resumed_hold_started and resumed_unit_completed and int(stock_model.call("current", &"egg")) == 3, "a later real GUI hold resumes the saved partial portion")
	var progression: Dictionary = game_session.call("five_area_progression_snapshot")
	_check(int(progression.get("coins", 0)) == 18, "two completed real-time portions deduct exactly two formal coins")
	var egg_artwork := egg.get_node("Artwork") as TextureRect
	_check(egg_artwork.texture != null and egg_artwork.texture.resource_path.ends_with("egg_stock_3_v1.png"), "the clickable egg well updates to the third real stock artwork after refill")

	await _slow_drag(baocui.get_global_rect().get_center(), surface.get_global_rect().get_center() + Vector2(40.0, 20.0), 24)
	await process_frame
	_check(bool(ingredient_model.call("has_type", &"baocui")), "slow real GUI drag still reaches the established griddle placement path")
	_check(not (egg.get_node("Label") as CanvasItem).visible and not (egg.get_node("EmptyLabel") as CanvasItem).visible, "direct ingredient container keeps player-visible text labels hidden")
	var refill_help := str(egg.get_meta(&"refill_help_text", ""))
	_check(refill_help.contains("每份") and refill_help.contains("当前") and not refill_help.contains("%") and not refill_help.contains("进度") and egg.tooltip_text.is_empty(), "tray hover help uses the off-worktop instruction strip for price, time, and capacity without refill progress")
	_check(_material_rail_has_eighteen_positions(workstation), "runtime material rail has exactly one fixed row of 18 wells")
	_check(_opening_day_material_controls_align(workstation), "opening-day ingredients stay fixed in Slots07-Slot09")
	var add_on_progression: RefCounted = game_session.call("progression_service")
	var add_on_unlocks: Dictionary = Dictionary(add_on_progression.get("unlocked_stock_ids")).duplicate(true)
	add_on_unlocks[&"stock.pancake.ham_sausage"] = true
	add_on_progression.set("unlocked_stock_ids", add_on_unlocks)
	controller.call("_on_progression_changed", game_session.call("five_area_progression_snapshot"))
	await process_frame
	var ham := workstation.get_node("SafeArea/IngredientRack/HamButton") as Button
	_check(ham.visible and StringName(ham.get_meta(&"material_slot_id", &"")) == &"slot.10", "the first later add-on compacts into Slot10 without moving Slots07-Slot09")
	_check(bool(ham.get_meta(&"refill_enabled", false)) and is_equal_approx(float(ham.get("hold_threshold_seconds")), 0.1), "the unlocked ham tray supports the shared hold-to-restock gesture")
	var coins_before_ham_refill := int(add_on_progression.get("coins"))
	var ham_tray_center := ham.get_global_rect().get_center()
	_press_at(ham_tray_center)
	await process_frame
	var ham_hold_started := await _wait_until(func() -> bool: return StringName(controller.get("_active_refill_stock_id")) == &"stock.pancake.ham_sausage", 0.50)
	var ham_unit_completed := await _wait_until(func() -> bool: return int(stock_model.call("current", &"ham_sausage")) >= 1, 0.85)
	_release_at(ham_tray_center)
	await process_frame
	_check(ham_hold_started and ham_unit_completed and int(add_on_progression.get("coins")) == coins_before_ham_refill - 2, "real stationary hold refills one ham portion and charges its exact price")
	refill_help = str(egg.get_meta(&"refill_help_text", ""))
	_move_at(egg_tray_center)
	await create_timer(0.25).timeout
	var instructions := workstation.get_node("SafeArea/BottomStrip/Instructions") as Label
	_check(instructions.text == refill_help, "real pointer hover displays refill help above the workstation")
	await RenderingServer.frame_post_draw
	var refill_output_absolute := ProjectSettings.globalize_path(REFILL_SCREENSHOT_PATH)
	var refill_image := root.get_texture().get_image()
	var refill_save_error := refill_image.save_png(refill_output_absolute)
	_check(refill_save_error == OK and refill_image.get_size() == Vector2i(1920, 1080), "captured the real main-game refill result in a 1920x1080 GPU frame")
	var session_progression: RefCounted = game_session.call("progression_service")
	var owned_growth: Dictionary = Dictionary(session_progression.get("owned_growth_ids")).duplicate(true)
	owned_growth[&"growth.capacity.pancake_holding_tray.two_slots"] = true
	session_progression.set("owned_growth_ids", owned_growth)
	var active_formal_order: Dictionary = game_session.call("active_formal_order")
	var target_order_id := StringName(active_formal_order.get("order_id", &""))
	var target_service_slot := int(active_formal_order.get("service_slot", 0))
	var active_item: Dictionary = Dictionary(Array(active_formal_order.get("items", []))[0])
	var tray_product := {
		"product_instance_id": &"gpu.route.pancake.1",
		"product_id": active_item.get("product_id", &"product.pancake.custom"),
		"heat_preference": active_item.get("heat_preference", &""),
		"ingredient_ids": Array(active_item.get("ingredient_ids", [])),
		"sauce_ids": Array(active_item.get("sauce_ids", [])),
		"score": 88.0,
	}
	var stored_for_route: Dictionary = game_session.call("store_pancake_product", tray_product)
	workstation.call("reset_pancake")
	workstation.call("_refresh_pancake_holding_tray")
	var holding_slot := workstation.get_node("SafeArea/PancakeHoldingTray/PancakeHoldingSlot01") as Button
	_check(bool(stored_for_route.get("success", false)) and holding_slot.visible and holding_slot.disabled and holding_slot.mouse_filter == Control.MOUSE_FILTER_IGNORE, "formal tray displays a stored pancake without becoming a delivery button")
	var customer_slot := workstation.get_node("SafeArea/CustomerStrip/CustomerSlot%d" % (target_service_slot + 1)) as Button
	_move_at(customer_slot.get_global_rect().get_center())
	await process_frame
	_click_control(customer_slot)
	await process_frame
	var order_after_customer_click: Dictionary = game_session.call("formal_order", target_order_id)
	var slots_after_customer_click: Array = Array(Dictionary(game_session.call("pancake_holding_tray_snapshot")).get("slots", []))
	_check(StringName(order_after_customer_click.get("state", &"")) != &"settled" and not slots_after_customer_click.is_empty() and not Dictionary(slots_after_customer_click[0]).is_empty(), "real customer click only focuses the order and does not deliver the displayed tray product")
	var order_dish_target := workstation.get_node("SafeArea/OrderCard/OrderDishTarget1") as Button
	_check(order_dish_target.disabled and order_dish_target.mouse_filter == Control.MOUSE_FILTER_IGNORE, "order-card product art is a read-only hint rather than a delivery target")
	_move_at(order_dish_target.get_global_rect().get_center())
	await process_frame
	_click_control(order_dish_target)
	await process_frame
	var order_after_tray_click: Dictionary = game_session.call("formal_order", target_order_id)
	var slots_after_tray_click: Array = Array(Dictionary(game_session.call("pancake_holding_tray_snapshot")).get("slots", []))
	var tray_click_is_read_only := StringName(order_after_tray_click.get("state", &"")) != &"settled" and not slots_after_tray_click.is_empty() and not Dictionary(slots_after_tray_click[0]).is_empty()
	_check(tray_click_is_read_only, "real order-icon click cannot route or consume a stored product; delivery requires physical drag to the customer tray")
	workstation.get("payment_coin_model").call("add_payment", 3)
	var payment_denominations: Array[int] = [2, 1]
	workstation._spawn_payment_flight(payment_denominations)
	workstation._pending_payment_sprites.append_array(workstation._payment_flight_sprites)
	workstation._payment_flight_sprites.clear()
	workstation._layout_pending_payment_sprites()
	var pending_coins: Array[TextureRect] = workstation._pending_payment_sprites
	var payment_strip := workstation.get_node("SafeArea/PaymentCollectionArea") as Button
	var non_coin_point := payment_strip.get_global_rect().get_center()
	_click_at(non_coin_point)
	await process_frame
	_check(int(workstation.payment_coin_model.pending_total) == 3 and pending_coins.size() == 2, "clicking empty space in the old payment strip does not collect coins")
	_click_control(pending_coins[0] as Control)
	await process_frame
	_check(int(workstation.payment_coin_model.pending_total) == 0 and workstation._pending_payment_sprites.is_empty(), "clicking a visible coin collects the pending payment")
	game.queue_free()
	await process_frame
	_finish(output_absolute, refill_output_absolute, egg_crack_output_absolute)


func _wait_until(condition: Callable, timeout_seconds: float) -> bool:
	var started_msec := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - started_msec) / 1000.0 < timeout_seconds:
		if bool(condition.call()):
			return true
		await process_frame
	return bool(condition.call())


func _click_control(control: Control) -> void:
	_click_at(control.get_global_rect().get_center())


func _click_control_settled(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	_move_at(position)
	await process_frame
	_press_at(position)
	await process_frame
	_release_at(position)


func _click_at(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion)
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = position
	pressed.global_position = position
	root.push_input(pressed)
	var released := InputEventMouseButton.new()
	released.button_index = MOUSE_BUTTON_LEFT
	released.pressed = false
	released.position = position
	released.global_position = position
	root.push_input(released)


func _press_at(position: Vector2) -> void:
	_move_at(position)
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = position
	pressed.global_position = position
	root.push_input(pressed)


func _move_at(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion)


func _release_at(position: Vector2) -> void:
	var released := InputEventMouseButton.new()
	released.button_index = MOUSE_BUTTON_LEFT
	released.pressed = false
	released.position = position
	released.global_position = position
	root.push_input(released)


func _drag(from: Vector2, to: Vector2) -> void:
	var move_start := InputEventMouseMotion.new()
	move_start.position = from
	move_start.global_position = from
	root.push_input(move_start)
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = from
	pressed.global_position = from
	root.push_input(pressed)
	for index in 9:
		var ratio := float(index + 1) / 9.0
		var point := from.lerp(to, ratio)
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion)
	var released := InputEventMouseButton.new()
	released.button_index = MOUSE_BUTTON_LEFT
	released.pressed = false
	released.position = to
	released.global_position = to
	root.push_input(released)


func _slow_drag(from: Vector2, to: Vector2, frames: int) -> void:
	var move_start := InputEventMouseMotion.new()
	move_start.position = from
	move_start.global_position = from
	root.push_input(move_start)
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = from
	pressed.global_position = from
	root.push_input(pressed)
	await process_frame
	for index in frames:
		var ratio := float(index + 1) / float(frames)
		var point := from.lerp(to, ratio)
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion)
		await process_frame
	_release_at(to)


func _material_rail_has_eighteen_positions(workstation: Node) -> bool:
	var dock := workstation.get_node_or_null("SafeArea/MaterialDock") as Control
	if dock == null or dock.get_child_count() != 18 or int(dock.get_meta(&"slot_count", 0)) != 18:
		return false
	for index in 18:
		var slot := dock.get_node_or_null("Slot%02d" % (index + 1)) as Control
		if slot == null or int(slot.get_meta(&"slot_index", 0)) != index + 1:
			return false
	return true


func _opening_day_material_controls_align(workstation: Node) -> bool:
	var rack := workstation.get_node_or_null("SafeArea/IngredientRack") as Control
	if rack == null or rack.position.distance_to(Vector2(648.0, 956.0)) > 1.0 or rack.size.distance_to(Vector2(305.0, 89.0)) > 1.0:
		return false
	var expected_rects := {
		"EggButton": Rect2(654.0, 956.0, 89.0, 89.0),
		"BaocuiButton": Rect2(759.0, 956.0, 89.0, 89.0),
		"ScallionButton": Rect2(864.0, 956.0, 89.0, 89.0),
	}
	for button_name in expected_rects:
		var ingredient := workstation.get_node_or_null("SafeArea/IngredientRack/%s" % button_name) as Control
		var expected: Rect2 = expected_rects[button_name]
		if ingredient == null or ingredient.get_global_rect().position.distance_to(expected.position) > 1.0 or ingredient.get_global_rect().size.distance_to(expected.size) > 1.0:
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish(output_absolute: String, refill_output_absolute: String, egg_crack_output_absolute: String) -> void:
	if _failures.is_empty():
		print("INITIAL_UNLOCK_WORKSTATION_GPU_SMOKE_PASS")
		print("INITIAL_SCREENSHOT=%s" % output_absolute)
		print("INITIAL_SCREENSHOT_1280=%s" % ProjectSettings.globalize_path(SCREENSHOT_1280_PATH))
		print("REFILL_SCREENSHOT=%s" % refill_output_absolute)
		print("EGG_CRACK_SCREENSHOT=%s" % egg_crack_output_absolute)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
