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
	var tray := workstation.get_node_or_null("FiveAreaInfrastructure/CustomerHandoffTray")
	var tray_slots := workstation.get_node_or_null("FiveAreaInfrastructure/CustomerHandoffTray/TrayBody/TraySlots")
	_check(tray != null and tray_slots != null and tray_slots.get_child_count() == 3, "customer handoff tray owns exactly three physical item slots")
	var tray_handle := workstation.get_node_or_null("FiveAreaInfrastructure/CustomerHandoffTray/TrayHandle") as Control
	var customer_target := workstation.get_node_or_null("FiveAreaInfrastructure/CustomerHandoffTray/CustomerDropTarget") as Control
	_check(customer_target != null, "whole tray has a stable customer handoff target")
	_check(tray_handle != null and tray_handle.size.x >= 64.0 and tray_handle.size.y >= 64.0 and customer_target != null and customer_target.size.x >= 64.0 and customer_target.size.y >= 64.0, "tray handoff controls keep 64px-class authored hit areas")
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
	for child_name in [&"Lane01", &"Lane02", &"Lane03", &"Lane04", &"Restock01", &"Restock02", &"Restock03", &"Restock04", &"HeaterSlot01", &"HeaterSlot02", &"HeaterSlot03", &"HeaterSlot04"]:
		var control := drink.get_node_or_null(NodePath(str(child_name))) as Control if drink != null else null
		_check(control != null and control.size.x >= 64.0 and control.size.y >= 64.0, "drink station %s keeps a 64px-class authored hit area" % child_name)
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
