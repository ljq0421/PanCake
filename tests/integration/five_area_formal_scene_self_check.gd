extends SceneTree

const SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := FileAccess.get_file_as_string("res://scenes/gameplay/five_area_workstation.tscn")
	_check(not source.contains("direct_youtiao_station.tscn"), "retired direct fryer is not referenced by the live scene")
	var workstation := SCENE.instantiate()
	root.add_child(workstation)
	await process_frame
	var stations := workstation.get_node_or_null("FiveAreaInfrastructure/Stations") as Control
	_check(stations != null and stations.get_child_count() == 3, "live shop has exactly three production workstations")
	for station_name in [&"CartoonYoutiaoFryer", &"PancakeStation", &"FreshSoyMilkStation"]:
		_check(stations != null and stations.get_node_or_null(NodePath(str(station_name))) != null, "%s is present" % station_name)
	for retired_name in [&"YoutiaoStation", &"SteamerStation", &"PackagedDrinkStation"]:
		_check(stations != null and stations.get_node_or_null(NodePath(str(retired_name))) == null, "%s is absent" % retired_name)
	var fryer := stations.get_node_or_null("CartoonYoutiaoFryer") as CartoonYoutiaoFryerToggle if stations != null else null
	_check(fryer != null and fryer.has_signal("status_message"), "cartoon fryer exposes workstation status messages")
	_check(fryer != null and fryer.output_sources.size() == 1 and fryer.prepared_slot != null and fryer.waste_target != null, "cartoon fryer exposes batch storage and disposal contracts")
	_check(fryer != null and fryer.product_visuals.size() == 8 and fryer.plate_product_visuals.size() == 8, "cartoon fryer renders every supported capacity slot")
	workstation.queue_free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("THREE_WORKSTATION_FORMAL_SCENE_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("THREE_WORKSTATION_FORMAL_SCENE_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
