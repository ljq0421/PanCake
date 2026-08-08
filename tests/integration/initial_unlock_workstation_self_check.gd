extends SceneTree

const SCENE_PATH := "res://scenes/gameplay/initial_unlock_workstation.tscn"
const CATALOG := preload("res://scripts/data/workstation_expansion_catalog.gd")
const CENTRAL_PAN_BAY := Rect2(640.0, 500.0, 620.0, 420.0)
const STARTER_SLOT_RECTS := {
	&"egg": Rect2(6.0, 0.0, 89.0, 89.0),
	&"baocui": Rect2(111.0, 0.0, 89.0, 89.0),
	&"scallion": Rect2(216.0, 0.0, 89.0, 89.0),
}

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_session := root.get_node_or_null("GameSession")
	if game_session != null:
		game_session.call("begin_new_game")
	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "initial-unlock workstation loads with its scene-owned art")
	if packed == null:
		_finish()
		return
	var workstation := packed.instantiate()
	root.add_child(workstation)
	await process_frame
	await process_frame
	_check_five_zone_layout(workstation)
	_check_order_card_runtime_content(workstation)
	_check_material_grid(workstation)
	_check_opening_day_controls(workstation)
	_check_player_feedback_controls(workstation, game_session)
	_check_no_egg_waffle_data(workstation)
	workstation.queue_free()
	await process_frame
	_finish()


func _check_five_zone_layout(workstation: Node) -> void:
	var background := workstation.get_node_or_null("SafeArea/BackgroundArtwork") as TextureRect
	_check(background != null and background.texture != null and background.texture.get_size() == Vector2(1920.0, 1080.0) and background.texture.resource_path.ends_with("workstation_18_single_row_1920x1080_v6.png"), "the 1920x1080 enhanced-divider tabletop background is the active workstation map")
	_check(workstation.get_node_or_null("SafeArea/ExpansionLayout") == null and workstation.get_node_or_null("SafeArea/LegacyFiveZonePrototype") == null and workstation.get_node_or_null("SafeArea/LegacyMaterialDockPrototype") == null, "retired 12-slot, three-device, and prototype overlay nodes are removed from the formal scene")
	var station_art := workstation.get_node_or_null("SafeArea/FiveAreaStationArtwork") as Control
	var station_hits := workstation.get_node_or_null("SafeArea/FiveAreaStationClickLayers") as Control
	_check(station_art != null and station_hits != null, "five-bay map uses scene-owned artwork and separate hit areas")
	for art_name in [&"FreshSoyMilkMachine", &"FreshSoyMilkLock", &"YoutiaoFryer", &"YoutiaoLock", &"PackagedDrinkLock", &"SteamerLock"]:
		var art := workstation.get_node_or_null("SafeArea/FiveAreaStationArtwork/%s" % art_name) as TextureRect
		_check(art != null and art.texture != null, "%s is a real workstation artwork layer" % art_name)
	var expected_locked_areas := {
		&"FreshSoyMilkLockedClickLayer": &"area.fresh_soy_milk",
		&"YoutiaoLockedClickLayer": &"area.youtiao",
		&"PackagedDrinkLockedClickLayer": &"area.packaged_drink",
		&"SteamerLockedClickLayer": &"area.steamer",
	}
	for button_name in expected_locked_areas:
		var button := workstation.get_node_or_null("SafeArea/FiveAreaStationClickLayers/%s" % button_name) as Button
		_check(button != null and not button.disabled and StringName(button.get_meta(&"area_id", &"")) == expected_locked_areas[button_name] and not str(button.get_meta(&"unlock_condition", "")).is_empty() and button.get_meta(&"locked_art_path", NodePath()) != NodePath(), "%s remains click-targetable with a stable area ID and explicit unlock condition" % button_name)
	var soy_lock_button := workstation.get_node_or_null("SafeArea/FiveAreaStationClickLayers/FreshSoyMilkLockedClickLayer") as Button
	var soy_lock_art := workstation.get_node_or_null("SafeArea/FiveAreaStationArtwork/FreshSoyMilkLock") as Control
	if soy_lock_button != null:
		soy_lock_button.emit_signal("pressed")
	_check(soy_lock_art != null and soy_lock_art.scale.x < 1.0, "clicking a locked station produces physical lock-art feedback without a UI overlay")
	var pan_base := workstation.get_node_or_null("SafeArea/PanBase") as Control
	var pancake_surface := workstation.get_node_or_null("SafeArea/PanBase/PancakeSurface") as Control
	var sweet_flour_sauce_brush := workstation.get_node_or_null("SafeArea/LeftRack/SauceBrushButton") as Button
	var griddle := workstation.get_node_or_null("SafeArea/PanBase/GriddleArtwork") as Sprite2D
	_check(pan_base != null and pancake_surface != null and StringName(pancake_surface.get_meta(&"area_id", &"")) == &"area.pancake" and bool(pancake_surface.get_meta(&"station_click_layer", false)) and Rect2(pan_base.position, pan_base.size).intersects(CENTRAL_PAN_BAY) and _rect_matches(pan_base, Rect2(750.0, 562.0, 420.0, 382.0)) and _rect_matches(pancake_surface, Rect2(40.0, 40.0, 340.0, 340.0)) and griddle != null and griddle.texture != null and griddle.texture.resource_path.ends_with("griddle_base_angled_ellipse_v3.png") and griddle.scale == Vector2(0.41, 0.41), "the centered pancake surface is the fifth stable area click layer")
	_check(sweet_flour_sauce_brush != null and StringName(sweet_flour_sauce_brush.get_meta(&"stock_id", &"")) == &"sweet_flour_sauce" and bool(sweet_flour_sauce_brush.get_meta(&"station_click_layer", false)), "SweetFlourSauceBrush is the established LeftRack sauce input and is not a material slot")
	var customer := workstation.get_node_or_null("SafeArea/CustomerPortrait") as Control
	var order_card := workstation.get_node_or_null("SafeArea/OrderCard") as Control
	_check(_rect_matches(customer, Rect2(800.0, 222.0, 270.0, 406.0)), "customer remains close while ending above the countertop edge")
	_check(_rect_matches(order_card, Rect2(1240.0, 190.0, 300.0, 370.0)) and order_card.texture != null and order_card.texture.resource_path.ends_with("order_card_multi_dish_v3.png"), "the compact multi-dish order card is positioned beside the customer without covering the tutorial strip")
	var payment_coin := workstation.get_node_or_null("SafeArea/OrderCard/OrderCoinIcon") as TextureRect
	var payment_amount := workstation.get_node_or_null("SafeArea/OrderCard/OrderAmountLabel") as Label
	var heart := workstation.get_node_or_null("SafeArea/OrderCard/OrderHeartFill") as Polygon2D
	var order_patience := workstation.get_node_or_null("SafeArea/OrderCard/OrderPatienceBar") as ProgressBar
	_check(payment_coin != null and payment_amount != null and heart != null and order_patience != null, "order card owns scene-defined payment and patience widgets")
	_check(heart != null and heart.position.distance_to(Vector2(56.0, 289.0)) <= 0.05 and heart.polygon.size() >= 12 and _rect_matches(order_patience, Rect2(84.0, 288.0, 156.0, 13.0)), "heart and patience fills align with the compact card's printed inner slots")
	for icon_index in 8:
		var icon := workstation.get_node_or_null("SafeArea/OrderCard/OrderIngredient%02d" % (icon_index + 1)) as TextureRect
		_check(icon != null, "OrderIngredient%02d is a stable ingredient slot" % (icon_index + 1))


func _check_order_card_runtime_content(workstation: Node) -> void:
	var coin := workstation.get_node_or_null("SafeArea/OrderCard/OrderCoinIcon") as TextureRect
	var amount := workstation.get_node_or_null("SafeArea/OrderCard/OrderAmountLabel") as Label
	var first_dish := workstation.get_node_or_null("SafeArea/OrderCard/OrderDish1") as TextureRect
	var second_dish := workstation.get_node_or_null("SafeArea/OrderCard/OrderDish2") as TextureRect
	var heart := workstation.get_node_or_null("SafeArea/OrderCard/OrderHeartFill") as Polygon2D
	var patience := workstation.get_node_or_null("SafeArea/OrderCard/OrderPatienceBar") as ProgressBar
	_check(coin != null and coin.visible and coin.texture != null and amount != null and not amount.text.is_empty(), "runtime order data fills the coin and amount in the card header")
	_check(first_dish != null and first_dish.visible and first_dish.texture != null and second_dish != null and not second_dish.visible, "a current single-dish order fills only the first of two reserved dish wells")
	var visible_ingredients := 0
	for icon_index in 8:
		var icon := workstation.get_node_or_null("SafeArea/OrderCard/OrderIngredient%02d" % (icon_index + 1)) as TextureRect
		if icon != null and icon.visible and icon.texture != null:
			visible_ingredients += 1
	_check(visible_ingredients > 0 and visible_ingredients <= 4, "runtime single-dish ingredients occupy only that dish's four color-grouped hint slots")
	_check(heart != null and heart.visible and patience != null and patience.visible and is_equal_approx(float(workstation.p1_session.order.get("time_limit", 0.0)), 108.0), "the first-customer tutorial keeps the compact order card and uses the 1.5x formal patience countdown")


func _check_material_grid(workstation: Node) -> void:
	var material_dock := workstation.get_node_or_null("SafeArea/MaterialDock") as Control
	var artwork := workstation.get_node_or_null("SafeArea/LockedIngredientArtwork") as Control
	var hit_areas := workstation.get_node_or_null("SafeArea/LockedIngredientInteractions") as Control
	_check(material_dock != null and material_dock.get_child_count() == 18 and int(material_dock.get_meta(&"slot_count", 0)) == 18 and StringName(material_dock.get_meta(&"layout", &"")) == &"single_row", "MaterialDock owns exactly one fixed row of 18 stable slots")
	for index in 18:
		var slot := material_dock.get_node_or_null("Slot%02d" % (index + 1)) as Control if material_dock != null else null
		_check(slot != null and int(slot.get_meta(&"slot_index", 0)) == index + 1 and _rect_matches(slot, Rect2(slot.position.x, 956.0, 89.0, 89.0)), "MaterialDock Slot%02d is present as a 89x89 bottom-aligned square" % (index + 1))
	_check(artwork != null and hit_areas != null, "ingredient row has dedicated artwork and click layers")
	var sauce_button := workstation.get_node_or_null("SafeArea/RightRack/SauceRefillButton") as Control
	var sauce_overlaps_slot := false
	if sauce_button != null and material_dock != null:
		for slot in material_dock.get_children():
			if sauce_button.get_global_rect().intersects((slot as Control).get_global_rect()):
				sauce_overlaps_slot = true
				break
	_check(sauce_button != null and not sauce_overlaps_slot, "sweet flour sauce remains a countertop control and does not occupy an ingredient slot")
	_check(workstation.get_node_or_null("SafeArea/DailyBillPanel/Margin/VBox/GrowthMessageLabel") == null, "daily bill removes the obsolete install/content empty-state label")
	if material_dock == null or artwork == null or hit_areas == null:
		return
	_check(artwork.get_child_count() == 15 and hit_areas.get_child_count() == 15, "18 physical ingredient wells resolve to 3 starters and 15 locked positions")
	for locked_index in [1, 2, 3, 4, 5, 6, 10, 11, 12, 13, 14, 15, 16, 17, 18]:
		var art := artwork.get_node_or_null("Slot%02d" % locked_index) as TextureRect
		var hit := hit_areas.get_node_or_null("Slot%02dLockedButton" % locked_index) as Button
		_check(art != null and art.texture != null and hit != null and not hit.disabled, "locked ingredient slot %02d has art and a click target" % locked_index)
	for prompt_path in ["Slot04LockedButton/PromptLabel", "Slot10LockedButton/PromptLabel"]:
		var prompt := hit_areas.get_node_or_null(prompt_path) as Label
		_check(prompt != null and not prompt.visible and prompt.text.is_empty(), "locked future ingredients do not reserve a named text placeholder")


func _check_opening_day_controls(workstation: Node) -> void:
	var rack := workstation.get_node_or_null("SafeArea/IngredientRack") as Control
	_check(_rect_matches(rack, Rect2(648.0, 956.0, 305.0, 89.0)), "the scene keeps one stable ingredient-control parent")
	var discard := workstation.get_node_or_null("SafeArea/DiscardCurrentPancakeButton") as Button
	_check(_rect_matches(discard, Rect2(1450.0, 902.0, 150.0, 52.0)), "discard-current-pancake stays above the square material row without covering a slot")
	var controls := {
		&"egg": workstation.get_node_or_null("SafeArea/IngredientRack/EggButton") as Control,
		&"scallion": workstation.get_node_or_null("SafeArea/IngredientRack/ScallionButton") as Control,
		&"baocui": workstation.get_node_or_null("SafeArea/IngredientRack/BaocuiButton") as Control,
	}
	for ingredient_id in STARTER_SLOT_RECTS:
		var control: Control = controls[ingredient_id]
		_check(control != null and control.visible and _rect_matches(control, STARTER_SLOT_RECTS[ingredient_id]), "%s occupies its opening-day priority well" % ingredient_id)
	_check(StringName(controls[&"egg"].get_meta(&"material_slot_id", &"")) == &"slot.07", "egg remains in its dedicated Slot07")
	_check(StringName(controls[&"baocui"].get_meta(&"material_slot_id", &"")) == &"slot.08" and StringName(controls[&"scallion"].get_meta(&"material_slot_id", &"")) == &"slot.09", "baocui and scallion remain fixed in Slot08-Slot09")
	var unlocked: Array = workstation.get_meta("unlocked_ingredient_ids", [])
	_check(unlocked == [&"egg", &"baocui", &"scallion"], "only egg, baocui, and scallion are ingredient unlocks on day one")
	var chili := workstation.get_node_or_null("SafeArea/RightRack/ChiliSauceRefillButton") as CanvasItem
	_check(chili != null and not chili.visible, "chili sauce remains unavailable on day one")


func _check_player_feedback_controls(workstation: Node, game_session: Node) -> void:
	workstation.apply_progression_effects({
		"owned_growth_ids": [&"growth.automation.pancake.press_once", &"growth.automation.pancake.auto_sauce_brush"],
		"device_tiers": {&"device.pancake_griddle": 2},
	})
	var spreader_button := workstation.get_node_or_null("SafeArea/LeftRack/ScraperButton") as Button
	var sauce_button := workstation.get_node_or_null("SafeArea/LeftRack/SauceBrushButton") as Button
	var press_button := workstation.get_node_or_null("SafeArea/LeftRack/PressSpreaderButton") as Button
	var legacy_auto_button := workstation.get_node_or_null("SafeArea/LeftRack/AutomaticSauceBrushButton") as Button
	_check(spreader_button != null and spreader_button.visible and (spreader_button.get_node("Label") as Label).text.contains("摊饼器"), "the T-shaped spreader remains available after buying the press")
	_check(press_button != null and press_button.visible and not press_button.disabled and press_button.text == "压饼器", "the press has its own visible one-shot control")
	_check(sauce_button != null and sauce_button.visible and not sauce_button.disabled and (sauce_button.get_node("Label") as Label).text == "自动酱刷", "the automatic brush upgrade replaces the existing sauce-brush control")
	_check(legacy_auto_button != null and not legacy_auto_button.visible, "the duplicate automatic-brush control stays hidden")
	_check((workstation.get_node("SafeArea/BottomStrip") as Control).visible, "the shared interaction feedback strip is visible during normal play")
	if press_button != null:
		press_button.emit_signal("pressed")
	_check(not (workstation.get_node("SafeArea/BottomStrip/ToolStatusLabel") as Label).text.is_empty(), "clicking a press tool outside its window gives a visible instruction")
	workstation.call("_auto_pour_center")
	var elapsed_before_press := float(workstation.p1_session.elapsed_seconds)
	var press_result: Dictionary = workstation.call("use_press_spreader")
	_check(bool(press_result.get("success", false)) and workstation.p1_session.phase == P1Session.Phase.FIRST_SIDE, "pressing poured batter completes the pancake skin and enters the egg stage")
	_check(bool(workstation.get("_spread_shape_locked")) and workstation.tool_controller.current_tool == ToolController.Tool.NONE, "successful press locks the finished skin without manual spreading")
	workstation.pancake_model.crack_egg(Vector2(workstation.pancake_model.grid_size, workstation.pancake_model.grid_size) * 0.5)
	workstation.call("_refresh_p1_ui")
	if spreader_button != null:
		spreader_button.emit_signal("pressed")
	_check(workstation.tool_controller.current_tool == ToolController.Tool.SCRAPER, "the T-shaped spreader remains selectable for the egg stage after pressing the batter")
	_check(float(press_result.get("coverage_ratio", 0.0)) >= 0.79 and is_equal_approx(float(workstation.p1_session.elapsed_seconds), elapsed_before_press + 1.2), "pressing creates full standard coverage and keeps its time cost")
	var repeat_result: Dictionary = workstation.call("use_press_spreader")
	_check(not bool(repeat_result.get("success", false)) and StringName(repeat_result.get("reason", &"")) == &"already_used", "the press remains limited to once per pancake")
	if sauce_button != null:
		sauce_button.emit_signal("pressed")
	_check((workstation.get_node("SafeArea/BottomStrip/ToolStatusLabel") as Label).text.contains("翻面后"), "clicking the automatic sauce brush outside its window explains when it can be used")
	_check((workstation.get_node("SafeArea/GlobalStatusLabel") as Label).text.contains("熟练度（煎饼）"), "the persistent top status explicitly shows pancake mastery")
	var bill_size_before := (workstation.get_node("SafeArea/DailyBillPanel") as Control).size
	workstation.call("_refresh_growth_section", "已扣费并预订：对应购买位将在明日激活。")
	_check((workstation.get_node("SafeArea/DailyBillPanel") as Control).size == bill_size_before, "growth selection text does not stretch the daily bill panel")
	var heat_slider := workstation.get_node("SafeArea/P1ControlBar/HeatSlider") as HSlider
	_check(not heat_slider.visible and not heat_slider.editable and is_equal_approx(float(workstation.p1_session.heat_level), 0.50), "griddle heat is fixed at the current 50-percent default and is not adjustable")
	if game_session != null:
		var progression: RefCounted = game_session.call("progression_service")
		progression.set("owned_growth_ids", {&"growth.capacity.pancake_holding_tray.two_slots": true})
		workstation.call("_refresh_pancake_holding_tray")
		var production_phase_before: int = int(workstation.p1_session.phase)
		var pancake_mass_before: float = float(workstation.pancake_model.total_thickness())
		var stored: Dictionary = Dictionary(game_session.call("store_pancake_product", {
			"product_instance_id": &"product_instance.integration.tray_mismatch",
			"product_id": &"product.pancake.custom",
			"heat_preference": &"well_done",
			"ingredient_ids": [],
			"sauce_ids": [],
			"fold_snapshot": {"package_result": &"paper_bag"},
			"dimension_scores": {},
			"score": 90.0,
		}))
		workstation.call("_refresh_pancake_holding_tray")
		workstation.call("_serve_pancake_from_holding_tray", 0)
		_check(bool(Dictionary(stored).get("success", false)) and workstation.p1_session.phase == P1Session.Phase.HANDOFF, "a mismatched tray pancake can start delivery while another pancake is in progress")
		_check(is_equal_approx(workstation.pancake_model.total_thickness(), pancake_mass_before), "starting tray delivery does not mutate the pancake on the griddle")
		workstation.p1_session.begin_payment()
		workstation.p1_session.finish_payment()
		workstation.call("_finalize_completed_payment", workstation.p1_session.result.duplicate(true))
		_check(workstation.p1_session.phase == production_phase_before and is_equal_approx(workstation.pancake_model.total_thickness(), pancake_mass_before), "the next customer resumes the exact griddle phase and pancake mass after tray payment")
	var tray_slot := workstation.get_node_or_null("SafeArea/PancakeHoldingTray/PancakeHoldingSlot01") as Button
	_check(tray_slot != null and tray_slot.visible and not tray_slot.disabled, "empty holding slots remain clickable to explain how to store and deliver a pancake")
	if tray_slot != null:
		tray_slot.emit_signal("pressed")
	_check(not (workstation.get_node("SafeArea/BottomStrip/ToolStatusLabel") as Label).text.is_empty(), "clicking an empty holding slot gives a visible storage instruction")


func _check_no_egg_waffle_data(workstation: Node) -> void:
	_check(not CATALOG.DEVICE_DEFINITIONS.has(&"egg_waffle_machine"), "egg-waffle device has been removed from the expansion catalog")
	_check(workstation.get_node_or_null("SafeArea/ExpansionLayout/DeviceSlots/EggWaffleMachineSlot") == null, "scene has no egg-waffle device slot")


func _rect_matches(control: Control, expected: Rect2) -> bool:
	return control != null and control.position.distance_to(expected.position) <= 0.05 and control.size.distance_to(expected.size) <= 0.05


func _global_rects_match(first: Control, second: Control) -> bool:
	return first != null and second != null \
		and first.get_global_rect().position.distance_to(second.get_global_rect().position) <= 1.0 \
		and first.get_global_rect().size.distance_to(second.get_global_rect().size) <= 1.0


func _global_rect_matches(control: Control, expected: Rect2) -> bool:
	return control != null and control.get_global_rect().position.distance_to(expected.position) <= 0.05 \
		and control.get_global_rect().size.distance_to(expected.size) <= 0.05


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("INITIAL_UNLOCK_WORKSTATION_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
