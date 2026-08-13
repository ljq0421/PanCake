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
	_check_egg_crack_staging(workstation)
	_check_hud_layout(workstation)
	_check_customer_and_summary_layout(workstation)
	_check_ingredient_drag_visuals(workstation)
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
	_check(background != null and background.texture != null and background.texture.get_size() == Vector2(1920.0, 1080.0) and background.texture.resource_path.ends_with("workstation_18_single_row_1920x1080_v8_chinese.png"), "the 1920x1080 Chinese-style tabletop background preview is the active workstation map")
	_check(workstation.get_node_or_null("SafeArea/ExpansionLayout") == null and workstation.get_node_or_null("SafeArea/LegacyFiveZonePrototype") == null and workstation.get_node_or_null("SafeArea/LegacyMaterialDockPrototype") == null, "retired 12-slot, three-device, and prototype overlay nodes are removed from the formal scene")
	var station_art := workstation.get_node_or_null("SafeArea/FiveAreaStationArtwork") as Control
	var station_hits := workstation.get_node_or_null("SafeArea/FiveAreaStationClickLayers") as Control
	_check(station_art != null and station_hits != null, "five-bay map uses scene-owned artwork and separate hit areas")
	for art_name in [&"FreshSoyMilkMachine", &"FreshSoyMilkLock", &"YoutiaoFryer", &"YoutiaoLock", &"PackagedDrinkLock", &"SteamerLock"]:
		var art := workstation.get_node_or_null("SafeArea/FiveAreaStationArtwork/%s" % art_name) as TextureRect
		_check(art != null and art.texture != null, "%s is a real workstation artwork layer" % art_name)
	var youtiao_fryer := workstation.get_node_or_null("SafeArea/FiveAreaStationArtwork/YoutiaoFryer") as TextureRect
	_check(youtiao_fryer != null and youtiao_fryer.texture != null and youtiao_fryer.texture.resource_path.ends_with("youtiao_fryer_tier_1_five_area_v3.png"), "the unlocked youtiao bay uses the approved simplified beginner fryer artwork")
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
	var egg_crack_effect := workstation.get_node_or_null("SafeArea/PanBase/PancakeSurface/EggCrackEffect") as AnimatedSprite2D
	_check(pan_base != null and pancake_surface != null and StringName(pancake_surface.get_meta(&"area_id", &"")) == &"area.pancake" and bool(pancake_surface.get_meta(&"station_click_layer", false)) and Rect2(pan_base.position, pan_base.size).intersects(CENTRAL_PAN_BAY) and _rect_matches(pan_base, Rect2(750.0, 562.0, 420.0, 382.0)) and _rect_matches(pancake_surface, Rect2(40.0, 40.0, 340.0, 340.0)) and griddle != null and griddle.texture != null and griddle.texture.resource_path.contains("griddle_base_angled_ellipse") and griddle.scale.x > 0.0 and griddle.scale.y > 0.0, "the centered pancake surface is the fifth stable area click layer")
	_check(sweet_flour_sauce_brush != null and StringName(sweet_flour_sauce_brush.get_meta(&"stock_id", &"")) == &"sweet_flour_sauce" and bool(sweet_flour_sauce_brush.get_meta(&"station_click_layer", false)), "SweetFlourSauceBrush is the established LeftRack sauce input and is not a material slot")
	_check(egg_crack_effect != null and egg_crack_effect.sprite_frames != null and egg_crack_effect.sprite_frames.get_frame_count(&"crack") == 2 and not egg_crack_effect.sprite_frames.get_animation_loop(&"crack"), "egg crack effect owns two non-looping scene-bound frames")
	if egg_crack_effect != null and egg_crack_effect.sprite_frames != null:
		var crack_frame_one := egg_crack_effect.sprite_frames.get_frame_texture(&"crack", 0)
		var crack_frame_two := egg_crack_effect.sprite_frames.get_frame_texture(&"crack", 1)
		_check(crack_frame_one != null and crack_frame_one.resource_path.ends_with("egg_cracked_raw_v1_five_area_v2.png") and crack_frame_two != null and crack_frame_two.resource_path.ends_with("egg_cracked_raw_v2_five_area_v2.png"), "egg crack effect binds the two approved 256-by-256 artwork assets in order")
	var customer := workstation.get_node_or_null("SafeArea/CustomerPortrait") as Control
	var order_card := workstation.get_node_or_null("SafeArea/OrderCard") as Control
	_check(_rect_matches(customer, Rect2(800.0, 222.0, 270.0, 406.0)), "initial-unlock compatibility scene keeps its single tutorial customer close to the counter")
	_check(_rect_matches(order_card, Rect2(1240.0, 190.0, 300.0, 370.0)) and order_card.texture != null and order_card.texture.resource_path.ends_with("order_card_multi_dish_v4_chinese_ui.png"), "initial-unlock compatibility scene uses the current compact Chinese order card without covering the tutorial strip")
	var payment_coin := workstation.get_node_or_null("SafeArea/OrderCard/OrderCoinIcon") as TextureRect
	var payment_amount := workstation.get_node_or_null("SafeArea/OrderCard/OrderAmountLabel") as Label
	var heart := workstation.get_node_or_null("SafeArea/OrderCard/OrderHeartFill") as Polygon2D
	var order_patience := workstation.get_node_or_null("SafeArea/OrderCard/OrderPatienceBar") as ProgressBar
	_check(payment_coin != null and payment_amount != null and heart != null and order_patience != null, "order card owns scene-defined payment and patience widgets")
	_check(heart != null and heart.position.distance_to(Vector2(56.0, 289.0)) <= 0.05 and heart.polygon.size() >= 12 and _rect_matches(order_patience, Rect2(84.0, 288.0, 156.0, 13.0)), "heart and patience fills align with the compact card's printed inner slots")
	for icon_index in 8:
		var icon := workstation.get_node_or_null("SafeArea/OrderCard/OrderIngredient%02d" % (icon_index + 1)) as TextureRect
		_check(icon != null, "OrderIngredient%02d is a stable ingredient slot" % (icon_index + 1))


func _check_egg_crack_staging(workstation: Node) -> void:
	var pancake_surface := workstation.get_node("SafeArea/PanBase/PancakeSurface") as Control
	var egg_crack_effect := pancake_surface.get_node("EggCrackEffect") as AnimatedSprite2D
	var egg_crack_artwork := pancake_surface.get_node("EggCrackArtwork") as Sprite2D
	var fixed_landing_position := pancake_surface.size * 0.5
	var expected_stage_position := Vector2(fixed_landing_position.x, 0.0)
	workstation.call("_play_egg_crack_effect", fixed_landing_position)
	_check(egg_crack_effect.position.is_equal_approx(expected_stage_position), "egg crack effect uses the lowered fixed stage at the horizontal center of the griddle")
	_check(egg_crack_artwork.position.is_equal_approx(fixed_landing_position), "raw egg landing artwork uses the fixed pancake center")
	workstation.call("_stop_egg_crack_effect")
	var parameters: RefCounted = workstation.get("parameters")
	var pancake_top := pancake_surface.size.y * 0.5 - pancake_surface.size.x * float(parameters.get("pan_height_ratio")) * 0.5
	var frame_texture := egg_crack_effect.sprite_frames.get_frame_texture(&"crack", 0)
	var maximum_effect_top := expected_stage_position.y - frame_texture.get_height() * 0.55 * 1.10 * 0.5
	var maximum_effect_bottom := expected_stage_position.y + frame_texture.get_height() * 0.55 * 1.10 * 0.5
	_check(not pancake_surface.clip_contents and maximum_effect_top < 0.0 and maximum_effect_bottom > pancake_top, "lowered egg crack effect can extend above the control while reaching the pancake's upper edge at maximum rebound scale")
	_check(not egg_crack_effect.visible and not egg_crack_artwork.visible, "stopping the staged crack effect clears both transient egg visuals")


func _check_hud_layout(workstation: Node) -> void:
	var customer_strip := workstation.get_node("SafeArea/CustomerStrip") as Control
	var title := workstation.get_node("SafeArea/CustomerStrip/Title") as Control
	var timer := workstation.get_node("SafeArea/BusinessDayTimerLabel") as Control
	var global_status := workstation.get_node("SafeArea/GlobalStatusLabel") as Control
	var bottom_strip := workstation.get_node("SafeArea/BottomStrip") as Control
	var phase_label := workstation.get_node("SafeArea/PhaseLabel") as Control
	var p1_controls := workstation.get_node("SafeArea/P1ControlBar") as Control
	var customer := workstation.get_node("SafeArea/CustomerPortrait") as Control
	var customer_line := workstation.get_node("SafeArea/CustomerLineLabel") as Control
	var order_card := workstation.get_node("SafeArea/OrderCard") as Control
	var pan := workstation.get_node("SafeArea/PanBase") as Control
	var left_rack := workstation.get_node("SafeArea/LeftRack") as Panel
	var right_rack := workstation.get_node("SafeArea/RightRack") as Panel
	var tray := workstation.get_node("SafeArea/PancakeHoldingTray") as Control
	var store_button := workstation.get_node("SafeArea/StorePancakeButton") as Control
	_check(_rect_matches(customer_strip, Rect2(100.0, 20.0, 1720.0, 112.0)) and not title.get_global_rect().intersects(timer.get_global_rect()), "customer-strip title and business timer occupy separate rows")
	_check(not customer_strip.get_global_rect().intersects(global_status.get_global_rect()), "global status uses its own narrow row below the customer strip")
	_check(not bottom_strip.get_global_rect().intersects(customer.get_global_rect()) and not bottom_strip.get_global_rect().intersects(order_card.get_global_rect()), "left feedback region does not cover the customer or order card")
	_check(bottom_strip.get_global_rect().encloses(phase_label.get_global_rect()) and bottom_strip.get_global_rect().encloses(p1_controls.get_global_rect()), "phase and P1 controls stay inside the left feedback region")
	_check(customer_line.get_global_rect().end.x <= customer.get_global_rect().position.x and not customer_line.get_global_rect().intersects(bottom_strip.get_global_rect()), "customer dialogue is constrained to the customer's left side")
	_check(left_rack.mouse_filter == Control.MOUSE_FILTER_IGNORE and right_rack.mouse_filter == Control.MOUSE_FILTER_IGNORE and left_rack.get_theme_stylebox("panel") is StyleBoxEmpty and right_rack.get_theme_stylebox("panel") is StyleBoxEmpty, "rack parents are transparent input-ignoring layout nodes")
	for tool_path in ["SafeArea/LeftRack/LadleButton", "SafeArea/LeftRack/ScraperButton", "SafeArea/LeftRack/SauceBrushButton"]:
		var tool := workstation.get_node(tool_path) as Control
		_check(not tool.get_global_rect().intersects(pan.get_global_rect()), "%s does not cover the griddle" % tool.name)
	_check(_rect_matches(right_rack, Rect2(815.0, 870.0, 290.0, 74.0)), "the sauce strip overlays only the griddle lower edge above the material row")
	var sweet_sauce := workstation.get_node("SafeArea/RightRack/SauceRefillButton") as Control
	var chili_sauce := workstation.get_node("SafeArea/RightRack/ChiliSauceRefillButton") as Control
	_check(_rect_matches(sweet_sauce, Rect2(0.0, 0.0, 145.0, 74.0)) and _rect_matches(chili_sauce, Rect2(145.0, 0.0, 145.0, 74.0)), "sweet sauce stays left and chili sauce stays right inside the overlay strip")
	_check(_rect_matches(store_button, Rect2(1182.0, 800.0, 122.0, 42.0)) and _rect_matches(tray, Rect2(1182.0, 846.0, 122.0, 98.0)), "holding controls form a compact vertical region beside the griddle")
	var tray_clear := not tray.get_global_rect().intersects(pan.get_global_rect())
	for slot_index in 18:
		tray_clear = tray_clear and not tray.get_global_rect().intersects((workstation.get_node("SafeArea/MaterialDock/Slot%02d" % (slot_index + 1)) as Control).get_global_rect())
	for sauce_path in ["SafeArea/LeftRack/SauceBrushButton", "SafeArea/RightRack/SauceRefillButton", "SafeArea/RightRack/ChiliSauceRefillButton"]:
		tray_clear = tray_clear and not tray.get_global_rect().intersects((workstation.get_node(sauce_path) as Control).get_global_rect())
	_check(tray_clear, "holding tray does not cover the griddle, sauce, or material row")


func _check_customer_and_summary_layout(workstation: Node) -> void:
	var customer_strip := workstation.get_node("SafeArea/CustomerStrip") as Control
	var slots: Array[Button] = [
		workstation.get_node("SafeArea/CustomerStrip/CustomerSlot1") as Button,
		workstation.get_node("SafeArea/CustomerStrip/CustomerSlot2") as Button,
		workstation.get_node("SafeArea/CustomerStrip/CustomerSlot3") as Button,
	]
	_check(slots.all(func(slot: Button) -> bool: return slot != null and customer_strip.get_global_rect().encloses(slot.get_global_rect()) and slot.get_node_or_null("Patience") is ProgressBar), "customer strip owns three clickable scene nodes with independent patience bars; strip=%s slots=%s" % [customer_strip.get_global_rect(), slots.map(func(slot: Button): return slot.get_global_rect())])
	var summary := workstation.get_node("SafeArea/OrderSummaryCard") as Control
	var status := workstation.get_node("SafeArea/GlobalStatusLabel") as Control
	var bottom := workstation.get_node("SafeArea/BottomStrip") as Control
	summary.visible = true
	_check(_rect_matches(summary, Rect2(1090.0, 136.0, 730.0, 58.0)) and not summary.get_global_rect().intersects(status.get_global_rect()) and not summary.get_global_rect().intersects(bottom.get_global_rect()), "compact previous-order card occupies the right side of the global row without covering production feedback; summary=%s status=%s bottom=%s" % [summary.get_global_rect(), status.get_global_rect(), bottom.get_global_rect()])
	workstation.set("_order_summary_visible", true)
	workstation.set("_result_detail_open", false)
	_check(not bool(workstation.call("_formal_order_time_paused")), "opening the compact previous-order summary does not pause customer patience")
	workstation.set("_result_detail_open", true)
	_check(not bool(workstation.call("_formal_order_time_paused")), "opening previous-order details does not pause customer patience")
	workstation.set("_result_detail_open", false)
	workstation.set("_order_summary_visible", false)
	summary.visible = false


func _check_ingredient_drag_visuals(workstation: Node) -> void:
	var layer := workstation.get_node("SafeArea/PanBase/PancakeSurface/IngredientLayer") as IngredientLayer
	var preview := workstation.get_node("SafeArea/IngredientDragPreview") as TextureRect
	var result_panel := workstation.get_node("SafeArea/ResultPanel") as Control
	for ingredient_type in IngredientModel.TYPES:
		_check(layer.texture_for(ingredient_type) != null, "%s has a non-empty shared drag and pancake texture" % IngredientModel.display_name(ingredient_type))
	_check(preview.z_index > (workstation.get_node("SafeArea/IngredientRack") as Control).z_index and preview.z_index < result_panel.z_index, "ingredient drag preview renders above the workstation controls and below modal details")
	var before_stock: int = int(workstation.ingredient_stock_model.current(IngredientModel.CORIANDER))
	workstation.set("_ingredient_drag_type", IngredientModel.CORIANDER)
	preview.texture = layer.texture_for(IngredientModel.CORIANDER)
	preview.visible = true
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(640.0, 420.0)
	workstation.call("_input", motion)
	_check(preview.visible and preview.global_position.distance_to(motion.position - preview.size * 0.5) <= 0.05, "recognized ingredient drag preview remains visible and follows the pointer")
	var cancel := InputEventMouseButton.new()
	cancel.button_index = MOUSE_BUTTON_RIGHT
	cancel.pressed = true
	workstation.call("_input", cancel)
	_check(not preview.visible and preview.texture == null and workstation.ingredient_stock_model.current(IngredientModel.CORIANDER) == before_stock, "cancel immediately hides the drag preview without consuming stock")


func _check_order_card_runtime_content(workstation: Node) -> void:
	var coin := workstation.get_node_or_null("SafeArea/OrderCard/OrderCoinIcon") as TextureRect
	var amount := workstation.get_node_or_null("SafeArea/OrderCard/OrderAmountLabel") as Label
	var first_dish := workstation.get_node_or_null("SafeArea/OrderCard/OrderDish1") as TextureRect
	var second_dish := workstation.get_node_or_null("SafeArea/OrderCard/OrderDish2") as TextureRect
	var third_dish := workstation.get_node_or_null("SafeArea/OrderCard/OrderDish3") as TextureRect
	var first_dish_target := workstation.get_node_or_null("SafeArea/OrderCard/OrderDishTarget1") as Button
	var second_dish_target := workstation.get_node_or_null("SafeArea/OrderCard/OrderDishTarget2") as Button
	var third_dish_target := workstation.get_node_or_null("SafeArea/OrderCard/OrderDishTarget3") as Button
	var heart := workstation.get_node_or_null("SafeArea/OrderCard/OrderHeartFill") as Polygon2D
	var patience := workstation.get_node_or_null("SafeArea/OrderCard/OrderPatienceBar") as ProgressBar
	var legacy_patience := workstation.get_node_or_null("SafeArea/PatienceBar") as ProgressBar
	_check(first_dish_target != null and second_dish_target != null and third_dish_target != null and first_dish_target.get_global_rect() == first_dish.get_global_rect() and second_dish_target.get_global_rect() == second_dish.get_global_rect() and third_dish_target.get_global_rect() == third_dish.get_global_rect(), "order card owns three scene-authored product hint wells")
	_check(first_dish_target.disabled and second_dish_target.disabled and third_dish_target.disabled and first_dish_target.mouse_filter == Control.MOUSE_FILTER_IGNORE and second_dish_target.mouse_filter == Control.MOUSE_FILTER_IGNORE and third_dish_target.mouse_filter == Control.MOUSE_FILTER_IGNORE, "all order-card item wells are read-only and cannot deliver products")
	workstation.call("_on_order_dish_pressed", 1)
	_check((workstation.get_node("SafeArea/BottomStrip/ToolStatusLabel") as Label).text.contains("空"), "clicking an empty order-card item gives a concrete reason")
	workstation.call("_on_order_dish_pressed", 0)
	_check((workstation.get_node("SafeArea/BottomStrip/ToolStatusLabel") as Label).text.contains("五区域"), "legacy base scene points delivery to the live five-area order-card route")
	var patience_text := workstation.get_node_or_null("SafeArea/PatienceTextLabel") as Label
	_check(coin != null and coin.visible and coin.texture != null and amount != null and not amount.text.is_empty(), "runtime order data fills the coin and amount in the card header")
	_check(first_dish != null and first_dish.visible and first_dish.texture != null and second_dish != null and not second_dish.visible and third_dish != null and not third_dish.visible, "a current single-dish order fills only the first of three reserved dish wells")
	var visible_ingredients := 0
	for icon_index in 8:
		var icon := workstation.get_node_or_null("SafeArea/OrderCard/OrderIngredient%02d" % (icon_index + 1)) as TextureRect
		if icon != null and icon.visible and icon.texture != null:
			visible_ingredients += 1
	_check(visible_ingredients > 0 and visible_ingredients <= 8, "runtime single-dish ingredients and sauces stay within that dish's compact requirement group")
	_check(heart != null and not heart.visible and patience != null and not patience.visible and legacy_patience != null and not legacy_patience.visible and patience_text != null and not patience_text.visible and bool(workstation.p1_session.order.get("tutorial_no_countdown", false)), "the first tutorial hides every patience and heart countdown visual")


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
	_check(sauce_button != null and not sauce_button.visible and sauce_button.disabled and sauce_button.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the automatic brush upgrade moves onto sauce-bottle release instead of replacing the hidden brush control")
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
	_check(sauce_button != null and not sauce_button.visible and sauce_button.disabled and sauce_button.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the separate sauce-brush button is removed from the player interaction path")
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
		workstation.call("_on_customer_slot_pressed", 0)
		_check(bool(Dictionary(stored).get("success", false)) and workstation.p1_session.phase == production_phase_before, "clicking the focused customer does not deliver the displayed tray pancake")
		workstation.call("_on_order_dish_pressed", 0)
		_check(workstation.p1_session.phase == production_phase_before and (workstation.get_node("SafeArea/BottomStrip/ToolStatusLabel") as Label).text.contains("五区域"), "legacy base-scene order card cannot start delivery while production continues")
		_check(is_equal_approx(workstation.pancake_model.total_thickness(), pancake_mass_before), "read-only order card does not mutate the pancake on the griddle")
	var tray_slot := workstation.get_node_or_null("SafeArea/PancakeHoldingTray/PancakeHoldingSlot02") as Button
	_check(tray_slot != null and tray_slot.visible and tray_slot.disabled and tray_slot.mouse_filter == Control.MOUSE_FILTER_IGNORE, "empty holding slots remain visible but cannot become delivery controls")


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
