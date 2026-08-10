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
	_check(steamer != null and steamer.has_signal("status_message") and steamer.has_method("refresh_from_session"), "steamer exposes direct layer interaction state")
	_check(soy != null and soy.get_node_or_null("RackOutput01") != null and soy.get_node_or_null("RackOutput04") != null, "soy station prebuilds four draggable output-rack positions")
	_check(steamer != null and steamer.get_node_or_null("Layer01") != null and steamer.get_node_or_null("Layer04") != null, "steamer prebuilds four independent physical layers")
	for child_name in [&"Lane01", &"Lane02", &"Lane03", &"Lane04", &"HeaterSlot01", &"HeaterSlot02", &"HeaterSlot03", &"HeaterSlot04"]:
		var control := drink.get_node_or_null(NodePath(str(child_name))) as Control if drink != null else null
		var minimum_size := Vector2(110.0, 46.0) if str(child_name).begins_with("Lane") else Vector2(64.0, 64.0)
		_check(control != null and control.size.x >= minimum_size.x and control.size.y >= minimum_size.y, "drink station %s keeps its authored interaction target" % child_name)
	for restock_name in [&"Restock01", &"Restock02", &"Restock03", &"Restock04"]:
		_check(drink.get_node_or_null(NodePath(str(restock_name))) == null, "drink station removes legacy %s button" % restock_name)
	for slot_index in range(4, 7):
		var prepared_slot := workstation.get_node_or_null("SafeArea/PreparedProductSlot%02d" % slot_index) as Control
		_check(prepared_slot != null and prepared_slot.size == Vector2(89.0, 89.0), "Slot%02d owns a fixed prepared-product interaction" % slot_index)
		_check(bool(prepared_slot.get("allow_pancake_drag")) == (slot_index == 4), "only Slot04 exposes prepared product as a pancake add-on")
	var art_root := workstation.get_node_or_null("FiveAreaInfrastructure/Stations/YoutiaoStation/MachineStage/ArtRoot") as Control
	_check(art_root != null and art_root.scale.is_equal_approx(Vector2(1.35, 1.35)), "youtiao machine art stack is uniformly enlarged 1.35x")
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
