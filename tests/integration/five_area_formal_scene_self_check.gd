extends SceneTree

const SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var workstation := SCENE.instantiate()
	root.add_child(workstation)
	await process_frame
	_check(workstation is Workstation, "three-area scene preserves the playable pancake controller contract")
	var infrastructure := workstation.get_node_or_null("FiveAreaInfrastructure") as Control
	_check(infrastructure != null and infrastructure.mouse_filter == Control.MOUSE_FILTER_IGNORE, "shop infrastructure leaves pointer routing to physical controls")
	var stations := workstation.get_node_or_null("FiveAreaInfrastructure/Stations") as Control
	_check(stations != null and stations.get_child_count() == 3, "shop owns exactly three permanent area roots")
	for station_name in [&"FreshSoyMilkStation", &"PancakeStation", &"YoutiaoStation"]:
		_check(stations != null and stations.get_node_or_null(NodePath(str(station_name))) != null, "%s is a stable same-screen station" % station_name)
	for removed_name in [&"PackagedDrinkStation", &"SteamerStation"]:
		_check(stations != null and stations.get_node_or_null(NodePath(str(removed_name))) == null, "%s is absent from the live shop" % removed_name)
	var soy := stations.get_node_or_null("FreshSoyMilkStation") as Control if stations != null else null
	var pancake := stations.get_node_or_null("PancakeStation") as Control if stations != null else null
	var youtiao := stations.get_node_or_null("YoutiaoStation") as Control if stations != null else null
	_check(soy != null and Rect2(soy.position, soy.size) == Rect2(8.0, 610.0, 352.0, 340.0), "soy machine owns the widened left area")
	_check(pancake != null and Rect2(pancake.position, pancake.size) == Rect2(370.0, 610.0, 1170.0, 340.0), "pancake operation owns the large center area")
	_check(youtiao != null and Rect2(youtiao.position, youtiao.size) == Rect2(1552.0, 610.0, 360.0, 340.0), "youtiao fryer owns the right area")
	var multi := workstation.get_node_or_null("FiveAreaInfrastructure/Stations/PancakeStation/MultiGriddleStation") as Control
	_check(multi != null and multi.has_method("set_griddle_count") and multi.has_method("ready_source_refs"), "multi-griddle station exposes its direct-operation contract")
	for unit_name in [&"Griddle01", &"Griddle02", &"Griddle03"]:
		var unit := multi.get_node_or_null(NodePath(str(unit_name))) if multi != null else null
		_check(unit != null and unit.has_method("begin_order") and unit.has_method("advance_main"), "%s is preauthored as an independent griddle" % unit_name)
	_check(workstation.get_node_or_null("FiveAreaInfrastructure/CustomerHandoffTray") == null, "retired handoff tray remains absent")
	_check(workstation.get_node_or_null("F3StationOverlay") == null, "production overlay remains absent")
	_check(workstation.get_node_or_null("FiveAreaInfrastructure/WasteArea") != null, "shop keeps a visible waste target")
	var holding_tray := workstation.get_node_or_null("SafeArea/PancakeHoldingTray")
	_check(holding_tray != null and holding_tray.get_child_count() >= 3, "pancake holding tray remains available")
	var pending_payment := workstation.get_node_or_null("FiveAreaInfrastructure/PendingPaymentButton") as Button
	_check(pending_payment != null, "shop owns a pending-payment control")
	_check(soy != null and soy.has_signal("status_message") and soy.has_method("refresh_from_session"), "soy machine remains directly operable")
	_check(youtiao != null and youtiao.has_signal("status_message") and youtiao.has_method("refresh_from_session"), "youtiao fryer remains directly operable")
	_check(soy != null and soy.get_node_or_null("RackOutput01") != null and soy.get_node_or_null("RackOutput04") != null, "soy station prebuilds four output-rack positions")
	for slot_name in [&"YoutiaoDoughPlain", &"YoutiaoDoughOilCake", &"YoutiaoDoughSugar"]:
		var material_slot := workstation.get_node_or_null("SafeArea/%s" % slot_name) as Control
		_check(material_slot != null and material_slot.size == Vector2(89.0, 89.0), "%s remains a direct dough source" % slot_name)
	for slot_name in [&"SoySplitYellow", &"SoySplitBlack", &"SoySplitRed", &"SoySplitMultigrain", &"SoySplitReserved02", &"SoySplitReserved03"]:
		_check(workstation.get_node_or_null("SafeArea/%s" % slot_name) != null, "%s stays authored in the scene" % slot_name)
	var tutorial_overlay := workstation.get_node_or_null("TutorialGuideOverlay") as Control
	_check(tutorial_overlay != null and tutorial_overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "tutorial overlay remains nonblocking")
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
