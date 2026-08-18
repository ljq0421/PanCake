extends SceneTree

const SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var formal_source := FileAccess.get_file_as_string("res://scenes/gameplay/five_area_workstation.tscn")
	_check(not formal_source.contains("initial_unlock_workstation.tscn") and formal_source.contains("[node name=\"Workstation\" type=\"Control\""), "formal three-area scene owns a standalone Workstation root instead of inheriting the retired workstation")
	var workstation := SCENE.instantiate()
	root.add_child(workstation)
	await process_frame
	_check(workstation is Workstation, "three-area scene preserves the playable pancake controller contract")
	var infrastructure := workstation.get_node_or_null("FiveAreaInfrastructure") as Control
	_check(infrastructure != null and infrastructure.mouse_filter == Control.MOUSE_FILTER_IGNORE, "shop infrastructure leaves pointer routing to physical controls")
	var stations := workstation.get_node_or_null("FiveAreaInfrastructure/Stations") as Control
	_check(stations != null and stations.get_child_count() == 4, "shop owns three production stations plus the left-side fryer visual")
	for station_name in [&"FreshSoyMilkStation", &"PancakeStation", &"YoutiaoStation"]:
		_check(stations != null and stations.get_node_or_null(NodePath(str(station_name))) != null, "%s is a stable same-screen station" % station_name)
	for removed_name in [&"PackagedDrinkStation", &"SteamerStation"]:
		_check(stations != null and stations.get_node_or_null(NodePath(str(removed_name))) == null, "%s is absent from the live shop" % removed_name)
	var soy := stations.get_node_or_null("FreshSoyMilkStation") as Control if stations != null else null
	var pancake := stations.get_node_or_null("PancakeStation") as Control if stations != null else null
	var youtiao := stations.get_node_or_null("YoutiaoStation") as Control if stations != null else null
	var cartoon_fryer := stations.get_node_or_null("CartoonYoutiaoFryer") as Control if stations != null else null
	_check(soy != null and Rect2(soy.position, soy.size) == Rect2(8.0, 448.0, 352.0, 340.0), "soy controls align with the left-hand stall artwork")
	_check(pancake != null and Rect2(pancake.position, pancake.size) == Rect2(370.0, 520.0, 1170.0, 340.0), "pancake operation aligns with the centered griddle artwork")
	_check(youtiao != null and Rect2(youtiao.position, youtiao.size) == Rect2(1552.0, 430.0, 360.0, 340.0), "fryer controls align with the right-hand stall artwork")
	_check(cartoon_fryer != null and Rect2(cartoon_fryer.position, cartoon_fryer.size) == Rect2(30.0, 550.0, 600.0, 800.0), "cartoon fryer occupies the left-side workbench space at 2× scale")
	if cartoon_fryer != null:
		var cartoon_machine := cartoon_fryer.get_node_or_null("FryerVisual") as TextureRect
		var dough_one := cartoon_fryer.get_node_or_null("DoughVisual1") as TextureRect
		var dough_two := cartoon_fryer.get_node_or_null("DoughVisual2") as TextureRect
		var cartoon_product_one := cartoon_fryer.get_node_or_null("ProductVisual1") as TextureRect
		var cartoon_product_two := cartoon_fryer.get_node_or_null("ProductVisual2") as TextureRect
		var plate_product_one := cartoon_fryer.get_node_or_null("PlateProductVisual1") as TextureRect
		var plate_product_two := cartoon_fryer.get_node_or_null("PlateProductVisual2") as TextureRect
		cartoon_fryer.set("reduce_motion", true)
		_check(cartoon_machine != null and cartoon_machine.texture == cartoon_fryer.get("raised_machine_texture"), "cartoon fryer starts with the drain raised")
		_check(dough_one != null and dough_one.visible and dough_two != null and dough_two.visible, "cutting board starts with two raw youtiao dough pieces")
		cartoon_fryer.call("_load_dough")
		cartoon_fryer.call("_load_dough")
		_check(cartoon_product_one != null and cartoon_product_one.visible and cartoon_product_one.texture == cartoon_fryer.get("raw_youtiao_texture") and cartoon_product_two != null and cartoon_product_two.visible and cartoon_product_two.texture == cartoon_fryer.get("raw_youtiao_texture"), "both raw dough pieces remain visible in the raised fryer before lowering the drain")
		_check(cartoon_product_one.position == Vector2(225.0, 68.0) and cartoon_product_two.position == Vector2(310.0, 68.0), "raised drain positions both raw dough pieces in the center of its basket")
		cartoon_fryer.call("_on_machine_clicked")
		_check(cartoon_machine.texture == cartoon_fryer.get("lowered_machine_texture"), "clicking the loaded fryer lowers its drain and starts frying")
		_check(cartoon_product_one.position == Vector2(225.0, 132.0) and cartoon_product_two.position == Vector2(310.0, 132.0), "lowered drain positions both youtiao inside the oil basket")
		cartoon_fryer.call("_process", 6.0)
		_check(cartoon_product_one.texture == cartoon_fryer.get("golden_youtiao_texture") and cartoon_product_two.texture == cartoon_fryer.get("golden_youtiao_texture"), "frying visibly transitions both youtiao from raw dough to golden")
		cartoon_fryer.call("_process", 4.0)
		cartoon_fryer.call("_on_machine_clicked")
		_check(cartoon_machine.texture == cartoon_fryer.get("raised_machine_texture"), "clicking the golden fryer raises its drain")
		_check(cartoon_product_one.position == Vector2(225.0, 68.0) and cartoon_product_two.position == Vector2(310.0, 68.0), "raised drain returns both golden youtiao to the center of its basket")
		cartoon_fryer.call("_process", 2.0)
		cartoon_fryer.call("_serve_product")
		cartoon_fryer.call("_serve_product")
		_check(plate_product_one.visible and plate_product_one.texture == cartoon_fryer.get("golden_youtiao_texture") and plate_product_two.visible and plate_product_two.texture == cartoon_fryer.get("golden_youtiao_texture"), "the plate accepts two finished golden youtiao")
		cartoon_fryer.call("_reset_idle")
		cartoon_fryer.call("_load_dough")
		cartoon_fryer.call("_load_dough")
		cartoon_fryer.call("_on_machine_clicked")
		cartoon_fryer.call("_process", 10.0)
		cartoon_fryer.call("_process", 5.0)
		cartoon_fryer.call("_process", 10.0)
		_check(cartoon_product_one.texture == cartoon_fryer.get("burnt_youtiao_texture") and cartoon_product_two.texture == cartoon_fryer.get("burnt_youtiao_texture"), "leaving the batch down too long burns both youtiao")
		cartoon_fryer.call("_on_machine_clicked")
		_check(cartoon_machine.texture == cartoon_fryer.get("raised_machine_texture") and cartoon_product_one.visible and cartoon_product_two.visible, "raising the drain keeps the burnt youtiao visible")
	var multi := workstation.get_node_or_null("FiveAreaInfrastructure/Stations/PancakeStation/MultiGriddleStation") as Control
	_check(multi != null and multi.has_method("set_griddle_count") and multi.has_method("ready_source_refs"), "multi-griddle station exposes its direct-operation contract")
	var worktop_hotspots := workstation.get_node_or_null("FiveAreaInfrastructure/PancakeWorktopHotspots") as Control
	_check(worktop_hotspots != null and worktop_hotspots.get_parent() == infrastructure and worktop_hotspots.get_index() > stations.get_index(), "pancake worktop hotspots are above the station input subtree")
	if worktop_hotspots != null:
		_check(worktop_hotspots.get_node_or_null("EggHotspot") != null and Rect2(worktop_hotspots.get_node("EggHotspot").position, worktop_hotspots.get_node("EggHotspot").size) == Rect2(920.0, 435.0, 170.0, 190.0), "egg hotspot is enlarged above the griddle edge")
		_check(Rect2(worktop_hotspots.get_node("SweetSauceHotspot").position, worktop_hotspots.get_node("SweetSauceHotspot").size) == Rect2(1235.0, 495.0, 200.0, 140.0), "sweet sauce hotspot remains a separate generous click target")
		_check(Rect2(worktop_hotspots.get_node("ChiliSauceHotspot").position, worktop_hotspots.get_node("ChiliSauceHotspot").size) == Rect2(1235.0, 635.0, 200.0, 160.0), "chili sauce hotspot remains separate from sweet sauce")
	var unit := multi.get_node_or_null("Griddle01") if multi != null else null
	_check(unit != null and unit.has_method("begin_order") and unit.has_method("advance_main"), "the single centered griddle remains directly operable")
	_check(multi != null and multi.get_node_or_null("Griddle02") == null and multi.get_node_or_null("Griddle03") == null and multi.call("griddle_count") == 1, "the live shop cannot expand beyond one griddle")
	var artwork := workstation.get_node_or_null("SafeArea/JianbingStallArtwork") as Control
	_check(artwork != null and artwork.mouse_filter == Control.MOUSE_FILTER_IGNORE and artwork.get_node_or_null("SoyMilkDispenser") != null and artwork.get_node_or_null("YoutiaoFryer") != null, "stall artwork is present and cannot intercept gameplay input")
	var safe_area := workstation.get_node_or_null("SafeArea") as Control
	_check(worktop_hotspots != null and safe_area != null and worktop_hotspots.position == safe_area.position and worktop_hotspots.size == safe_area.size, "worktop hotspots share the centered 1920x1080 artwork coordinate space")
	if worktop_hotspots != null:
		_check(is_equal_approx(worktop_hotspots.anchor_left, 0.5) and is_equal_approx(worktop_hotspots.anchor_right, 0.5), "worktop hotspots stay centered when an expanded-aspect window adds side margins")
	_check(workstation.get_node_or_null("FiveAreaInfrastructure/CustomerHandoffTray") == null, "retired handoff tray remains absent")
	_check(workstation.get_node_or_null("F3StationOverlay") == null, "production overlay remains absent")
	_check(workstation.get_node_or_null("FiveAreaInfrastructure/WasteArea") == null, "retired global waste target is absent; each griddle owns discard")
	for removed_path in [
		"ToolController",
		"SafeArea/OrderCard",
		"SafeArea/PanBase",
		"SafeArea/IngredientRack",
		"SafeArea/LeftRack",
		"SafeArea/RightRack",
		"SafeArea/MaterialDock",
		"SafeArea/PancakeHoldingTray",
		"SafeArea/FiveAreaStationArtwork",
		"SafeArea/FiveAreaStationClickLayers",
		"SafeArea/P1ControlBar",
		"SafeArea/DiscardCurrentPancakeButton",
	]:
		_check(workstation.get_node_or_null(removed_path) == null, "%s is physically absent instead of hidden" % removed_path)
	for slot_index in range(5, 19):
		_check(workstation.get_node_or_null("SafeArea/LockedIngredientArtwork/Slot%02d" % slot_index) == null, "retired lock artwork slot %02d is absent" % slot_index)
		_check(workstation.get_node_or_null("SafeArea/LockedIngredientInteractions/Slot%02dLockedButton" % slot_index) == null, "retired lock interaction slot %02d is absent" % slot_index)
	var pending_payment := workstation.get_node_or_null("FiveAreaInfrastructure/PendingPaymentButton") as Button
	_check(pending_payment != null, "shop owns a pending-payment control")
	_check(soy != null and soy.has_signal("status_message") and soy.has_method("refresh_from_session"), "soy machine remains directly operable")
	_check(youtiao != null and youtiao.has_signal("status_message") and youtiao.has_method("refresh_from_session"), "youtiao fryer remains directly operable")
	_check(soy != null and soy.get_node_or_null("RackOutput01") == null and soy.get_node_or_null("RackOutput04") == null and soy.get_node_or_null("FlavorMenu") != null, "soy station retires cup rack and exposes the future flavour-button entry point")
	var youtiao_material_slot := workstation.get_node_or_null("SafeArea/YoutiaoDoughPlain") as Control
	_check(youtiao_material_slot != null and youtiao_material_slot.size == Vector2(298.0, 89.0), "one wide oil-strip dough source replaces the former three-product row")
	_check(workstation.get_node_or_null("SafeArea/YoutiaoDoughOilCake") == null and workstation.get_node_or_null("SafeArea/YoutiaoDoughSugar") == null, "retired fryer dough sources are physically absent")
	for slot_name in [&"SoyFullYellow", &"SoyFullBlack", &"SoyFullRed"]:
		_check(workstation.get_node_or_null("SafeArea/%s" % slot_name) != null, "%s remains a full-size fixed bean source" % slot_name)
	for slot_name in [&"SoySplitYellow", &"SoySplitBlack", &"SoySplitRed", &"SoySplitMultigrain", &"SoySplitReserved02", &"SoySplitReserved03"]:
		_check(workstation.get_node_or_null("SafeArea/%s" % slot_name) == null, "%s retired split source is physically absent" % slot_name)
	var tutorial_overlay := workstation.get_node_or_null("TutorialGuideOverlay") as Control
	_check(tutorial_overlay != null and tutorial_overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "tutorial overlay remains nonblocking")
	workstation.size = Vector2(2304.0, 1080.0)
	await process_frame
	_check(worktop_hotspots != null and safe_area != null and worktop_hotspots.get_global_rect() == safe_area.get_global_rect(), "expanded-aspect windows keep worktop hotspots aligned with the centered artwork")
	_check(pancake != null and safe_area != null and pancake.global_position == safe_area.global_position + Vector2(370.0, 520.0), "expanded-aspect windows keep the griddle station fixed to the workbench")
	workstation.queue_free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("THREE_AREA_FORMAL_SCENE_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("THREE_AREA_FORMAL_SCENE_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
