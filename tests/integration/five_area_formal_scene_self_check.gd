extends SceneTree

const SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var workstation := SCENE.instantiate()
	root.add_child(workstation)
	await process_frame
	_check(workstation is Workstation, "formal five-area scene preserves the playable pancake controller contract")
	var material_dock := workstation.get_node_or_null("SafeArea/MaterialDock")
	_check(material_dock != null and material_dock.get_child_count() == 18, "formal five-area scene keeps eighteen fixed material slots")
	var infrastructure := workstation.get_node_or_null("FiveAreaInfrastructure")
	_check(infrastructure != null and infrastructure.mouse_filter == Control.MOUSE_FILTER_IGNORE, "formal infrastructure leaves pointer routing to physical child objects")
	var stations := workstation.get_node_or_null("FiveAreaInfrastructure/Stations")
	_check(stations != null and stations.get_child_count() == 5 and stations.mouse_filter == Control.MOUSE_FILTER_IGNORE, "formal scene owns five permanent station roots without covering pancake controls")
	for station_name in [&"FreshSoyMilkStation", &"YoutiaoStation", &"PancakeStation", &"PackagedDrinkStation", &"SteamerStation"]:
		_check(stations != null and stations.get_node_or_null(NodePath(str(station_name))) != null, "%s is a stable same-screen station" % station_name)
	_check(workstation.get_node_or_null("FiveAreaInfrastructure/CustomerHandoffTray") == null, "retired customer handoff tray is absent from the live five-area scene")
	for station_name in [&"FreshSoyMilkStation", &"YoutiaoStation", &"PackagedDrinkStation", &"SteamerStation"]:
		var station := workstation.get_node("FiveAreaInfrastructure/Stations/%s" % station_name) as Control
		var lock_cover := station.get("lock_cover") as Button
		_check(lock_cover != null and lock_cover.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s full lock cover cannot steal pointer input from authored workstation controls" % station_name)
	_check(not bool(workstation.youtiao_station.call("_has_point", Vector2(153.0, 274.0))), "youtiao shell passes the lower sauce-rack overlap through")
	_check(bool(workstation.youtiao_station.call("_has_point", Vector2(153.0, 90.0))), "youtiao shell retains its physical basket drop target")
	var holding_tray := workstation.get_node_or_null("SafeArea/PancakeHoldingTray")
	_check(holding_tray != null and holding_tray.get_child_count() >= 3, "independent two-slot pancake holding tray remains in the live scene")
	var pending_payment := workstation.get_node_or_null("FiveAreaInfrastructure/PendingPaymentButton") as Button
	_check(pending_payment != null, "scene owns a tray-independent pending-payment control")
	_check(workstation.get_node_or_null("FiveAreaInfrastructure/WasteArea") != null, "shop floor owns a visible staged-product waste target")
	_check(workstation.get_node_or_null("F3StationOverlay") == null, "production overlay was removed from the formal scene")
	_check(workstation.find_child("CloseButton", true, false) == null, "production close button was removed from the formal scene")
	_check(workstation.get_node_or_null("SafeArea/PatienceTextLabel") != null, "formal workstation owns a stable numeric patience label")
	var attention := workstation.get_node_or_null("FiveAreaInfrastructure/AttentionRail")
	_check(attention != null and attention.get_child_count() == 3, "formal scene owns three stable attention rows")
	var recommendations := workstation.get_node_or_null("SafeArea/DailyBillPanel/Margin/VBox/GrowthTickets")
	_check(recommendations != null and recommendations.get_child_count() == 3, "formal daily bill owns the three fixed-route recommendations")
	var soy := workstation.get_node_or_null("FiveAreaInfrastructure/Stations/FreshSoyMilkStation")
	var drink := workstation.get_node_or_null("FiveAreaInfrastructure/Stations/PackagedDrinkStation")
	var steamer := workstation.get_node_or_null("FiveAreaInfrastructure/Stations/SteamerStation")
	_check(soy != null and soy.has_signal("status_message") and soy.has_method("refresh_from_session"), "soy machine exposes direct physical interaction state")
	var soy_machine := soy.get_node_or_null("Machine") as TextureRect if soy != null else null
	var soy_machine_texture := soy_machine.texture as AtlasTexture if soy_machine != null else null
	_check(soy_machine != null and Rect2(soy_machine.position, soy_machine.size) == Rect2(73.0, 8.0, 160.0, 200.0), "soy machine uses the enlarged 160-by-200 authored display rect")
	_check(soy_machine_texture != null and soy_machine_texture.region == Rect2(332.0, 30.0, 360.0, 458.0), "soy machine crops the transparent source margins instead of scaling empty pixels")
	var soy_water := soy.get_node_or_null("WaterButton") as Button if soy != null else null
	var soy_start := soy.get_node_or_null("StartButton") as Button if soy != null else null
	var soy_output := soy.get_node_or_null("MachineOutput") as Control if soy != null else null
	var soy_state := soy.get_node_or_null("StateLabel") as Label if soy != null else null
	_check(soy_water != null and Rect2(soy_water.position, soy_water.size) == Rect2(12.0, 72.0, 68.0, 58.0), "soy water control stays beside the enlarged machine")
	_check(soy_start != null and Rect2(soy_start.position, soy_start.size) == Rect2(226.0, 72.0, 68.0, 58.0), "soy start control stays beside the enlarged machine")
	_check(soy_output != null and Rect2(soy_output.position, soy_output.size) == Rect2(78.0, 110.0, 76.0, 74.0), "soy output hit target follows the enlarged cup position")
	_check(soy_state != null and Rect2(soy_state.position, soy_state.size) == Rect2(28.0, 268.0, 250.0, 30.0), "soy state text moves below the enlarged machine and output rack")
	_check(steamer != null and steamer.has_signal("status_message") and steamer.has_method("refresh_from_session"), "steamer exposes direct layer interaction state")
	_check(soy != null and soy.get_node_or_null("RackOutput01") != null and soy.get_node_or_null("RackOutput04") != null, "soy station prebuilds four draggable output-rack positions")
	_check(steamer != null and steamer.get_node_or_null("Layer01") != null and steamer.get_node_or_null("Layer04") != null, "steamer prebuilds four independent physical layers")
	for child_name in [&"Lane01", &"Lane02", &"Lane03", &"Lane04", &"HeaterSlot01", &"HeaterSlot02", &"HeaterSlot03", &"HeaterSlot04"]:
		var control := drink.get_node_or_null(NodePath(str(child_name))) as Control if drink != null else null
		var minimum_size := Vector2(110.0, 46.0) if str(child_name).begins_with("Lane") else Vector2(64.0, 64.0)
		_check(control != null and control.size.x >= minimum_size.x and control.size.y >= minimum_size.y, "drink station %s keeps its authored interaction target" % child_name)
	for restock_name in [&"Restock01", &"Restock02", &"Restock03", &"Restock04"]:
		_check(drink.get_node_or_null(NodePath(str(restock_name))) == null, "drink station removes legacy %s button" % restock_name)
	for slot_name in [&"YoutiaoDoughPlain", &"YoutiaoDoughOilCake", &"YoutiaoDoughSugar"]:
		var material_slot := workstation.get_node_or_null("SafeArea/%s" % slot_name) as Control
		_check(material_slot != null and material_slot.size == Vector2(89.0, 89.0), "%s is a full bottom-dock dough source" % slot_name)
	for slot_name in [&"SoySplitYellow", &"SoySplitBlack", &"SoySplitRed", &"SoySplitMultigrain", &"SoySplitReserved02", &"SoySplitReserved03"]:
		_check(workstation.get_node_or_null("SafeArea/%s" % slot_name) != null, "%s is preauthored instead of runtime-created" % slot_name)
	for slot_index in range(4, 7):
		var legacy_slot := workstation.get_node_or_null("SafeArea/PreparedProductSlot%02d" % slot_index) as Control
		_check(legacy_slot == null, "legacy Slot%02d output is absent and cannot receive new products" % slot_index)
	for removed_name in [&"Dough01", &"Dough02", &"Dough03", &"DoughCount01", &"DoughCount02", &"DoughCount03", &"Restock01", &"Restock02", &"Restock03"]:
		_check(workstation.youtiao_station.get_node_or_null(NodePath(str(removed_name))) == null, "youtiao station removes duplicated tabletop %s" % removed_name)
	for removed_name in [&"Ingredient01", &"Ingredient02", &"Ingredient03", &"Ingredient04", &"Count01", &"Count02", &"Count03", &"Count04", &"Restock01", &"Restock02", &"Restock03", &"Restock04"]:
		_check(soy.get_node_or_null(NodePath(str(removed_name))) == null, "soy station removes duplicated tabletop %s" % removed_name)
	var art_root := workstation.get_node_or_null("FiveAreaInfrastructure/Stations/YoutiaoStation/MachineStage/ArtRoot") as Control
	_check(art_root != null and art_root.scale.is_equal_approx(Vector2(1.35, 1.35)), "youtiao machine art stack is uniformly enlarged 1.35x")
	var machine_stage := workstation.get_node_or_null("FiveAreaInfrastructure/Stations/YoutiaoStation/MachineStage") as Control
	_check(machine_stage != null and machine_stage.position.is_equal_approx(Vector2(-12.0, 52.0)) and machine_stage.size.is_equal_approx(Vector2(330.0, 176.0)), "youtiao machine stage uses the lowered enlarged authored rect")
	_check(machine_stage != null and not machine_stage.clip_contents, "youtiao machine stage leaves the enlarged artwork unclipped")
	var basic_lowered: Array[Rect2] = [Rect2(116, 38, 38, 30), Rect2(158, 38, 38, 30), Rect2(), Rect2()]
	var basic_raised: Array[Rect2] = [Rect2(116, 16, 38, 30), Rect2(158, 16, 38, 30), Rect2(), Rect2()]
	var advanced_lowered: Array[Rect2] = [Rect2(96, 40, 32, 29), Rect2(130, 40, 32, 29), Rect2(164, 40, 32, 29), Rect2(198, 40, 32, 29)]
	var advanced_raised: Array[Rect2] = [Rect2(111, 5, 32, 29), Rect2(136, 5, 32, 29), Rect2(161, 5, 32, 29), Rect2(186, 5, 32, 29)]
	_check(DirectYoutiaoStation._food_rects(0, false) == basic_lowered and DirectYoutiaoStation._food_rects(1, false) == basic_lowered, "basic and intermediate lowered baskets keep two non-overlapping food slots inside the basket")
	_check(DirectYoutiaoStation._food_rects(0, true) == basic_raised and DirectYoutiaoStation._food_rects(1, true) == basic_raised, "basic and intermediate raised baskets keep two non-overlapping food slots inside the basket")
	_check(DirectYoutiaoStation._food_rects(2, false) == advanced_lowered, "advanced lowered basket keeps all four food slots inside the basket")
	_check(DirectYoutiaoStation._food_rects(2, true) == advanced_raised, "advanced raised basket keeps all four food slots inside the basket")
	_check([DirectYoutiaoStation._front_clip_top(0, false), DirectYoutiaoStation._front_clip_top(1, false), DirectYoutiaoStation._front_clip_top(2, false)] == [64.0, 64.0, 66.0], "all lowered basket front-wall clip lines remain registered to their tier artwork")
	_check([DirectYoutiaoStation._front_clip_top(0, true), DirectYoutiaoStation._front_clip_top(1, true), DirectYoutiaoStation._front_clip_top(2, true)] == [44.0, 45.0, 32.0], "all raised basket front-wall clip lines remain registered to their tier artwork")
	var food_layer := art_root.get_node_or_null("FoodLayer") as Control
	var lowered_basket := art_root.get_node_or_null("LoweredBasketVisual") as Control
	var raised_basket := art_root.get_node_or_null("RaisedBasketVisual") as Control
	var lowered_basket_front := art_root.get_node_or_null("LoweredBasketFrontClip") as Control
	var raised_basket_front := art_root.get_node_or_null("RaisedBasketFrontClip") as Control
	var sizzle_layer := art_root.get_node_or_null("SizzleLayer") as Control
	var oil_drips := art_root.get_node_or_null("OilDripsVisual") as Control
	var burnt_smoke := art_root.get_node_or_null("BurntSmokeVisual") as Control
	_check(food_layer != null and lowered_basket != null and raised_basket != null and food_layer.z_index > lowered_basket.z_index and food_layer.z_index > raised_basket.z_index, "youtiao food renders above both full basket artworks")
	_check(lowered_basket_front != null and raised_basket_front != null and lowered_basket_front.clip_contents and raised_basket_front.clip_contents and lowered_basket_front.z_index > food_layer.z_index and raised_basket_front.z_index > food_layer.z_index, "exact basket front walls render above food and clip it naturally inside the basket")
	_check(food_layer != null and sizzle_layer != null and oil_drips != null and burnt_smoke != null and sizzle_layer.z_index > lowered_basket_front.z_index and sizzle_layer.z_index > raised_basket_front.z_index and oil_drips.z_index > sizzle_layer.z_index and burnt_smoke.z_index > oil_drips.z_index, "youtiao cooking effects remain above the basket front-wall occluders")
	var tutorial_overlay := workstation.get_node_or_null("TutorialGuideOverlay") as Control
	_check(tutorial_overlay != null and tutorial_overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE and tutorial_overlay.get_node_or_null("TargetHighlight") != null and tutorial_overlay.get_node_or_null("GuideBubble") != null, "fixed nonblocking tutorial overlay is preauthored in the scene")
	workstation.queue_free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("FIVE_AREA_FORMAL_SCENE_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("FIVE_AREA_FORMAL_SCENE_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
