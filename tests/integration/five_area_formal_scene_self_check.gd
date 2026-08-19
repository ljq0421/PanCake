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
	_check(fryer != null and fryer.black_sesame_tray != null and fryer.black_sesame_tray.texture != null, "black sesame tray is authored beside the fryer")
	_check(fryer != null and fryer.output_sources.size() == 4 and fryer.plate_sources.size() == 4 and fryer.prepared_slot != null and not fryer.prepared_slot.visible and fryer.waste_target != null, "cartoon fryer exposes four fryer and plate oil-stick sources while keeping the former storage control hidden")
	_check(fryer != null and fryer.product_visuals.size() == 4 and fryer.raised_basket_slots.size() == 4 and fryer.lowered_basket_slots.size() == 4, "cartoon fryer renders exactly four fixed fryer slots")
	_check(fryer != null and fryer.dough_visuals.size() == 4 and fryer.plate_product_visuals.size() == 4 and fryer.board_dough_slots.size() == 4 and fryer.plate_product_slots.size() == 4, "board and serving plate expose four scene-authored oil-stick positions")
	if fryer != null:
		var session: Node = root.get_node_or_null("GameSession")
		if session != null:
			var progression: RefCounted = session.call("progression_service")
			progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.youtiao": true})
			progression.set("unlocked_product_ids", {&"product.pancake.custom": true, &"product.youtiao.plain": true})
			fryer.set_workshop_preview(true)
			_check(fryer.black_sesame_tray.visible and is_equal_approx(fryer.black_sesame_tray.self_modulate.a, 0.42), "locked black sesame tray is translucent in the workshop preview")
			fryer.set_workshop_preview(false)
		fryer._machine = {"state": &"idle", "capacity": 4, "quantity": 0, "occupied_slot_indices": []}
		fryer._dough_stock = 4
		fryer._apply_snapshot()
		_check(_visible_count(fryer.dough_visuals) == 4 and fryer.dough_visuals[0].position == fryer.board_dough_slots[0].position, "four stocked dough units fill the scene-authored board positions")
		fryer._dough_stock = 3
		fryer._apply_snapshot()
		_check(_visible_count(fryer.dough_visuals) == 3, "consuming one dough unit removes one board visual")
		fryer._machine = {"state": &"ready_to_collect", "capacity": 4, "quantity": 4, "occupied_slot_indices": [0, 1, 2, 3]}
		fryer._plate_count = 0
		fryer._apply_snapshot()
		_check(_visible_count(fryer.plate_product_visuals) == 0, "finished youtiao remains in the basket until each stick is dragged to the plate")
		_check(fryer._can_drop_data(Vector2(470.0, 520.0), {"kind": &"product_source", "source_ref": {"source_kind": &"youtiao_fryer_slot", "source_index": 0}}), "a single finished fryer slot can be dropped on the serving plate")
		fryer._plate_count = 1
		fryer._apply_snapshot()
		_check(_visible_count(fryer.plate_product_visuals) == 1 and fryer.plate_product_visuals[0].position == fryer.plate_product_slots[0].position and fryer.plate_sources[0].visible, "storing one fried youtiao displays one draggable scene-positioned plate visual")
		if session != null:
			var progression: RefCounted = session.call("progression_service")
			var unlocked_products: Dictionary = Dictionary(progression.get("unlocked_product_ids"))
			unlocked_products[&"product.youtiao.sesame"] = true
			progression.set("unlocked_product_ids", unlocked_products)
			fryer.refresh_from_session()
			_check(fryer.black_sesame_tray.visible, "black sesame tray appears with the existing sesame oil-stick unlock")
			fryer._machine = {"state": &"ready_to_collect", "capacity": 4, "quantity": 1, "occupied_slot_indices": [0]}
			fryer._plate_count = 0
			_check(fryer._can_drop_data(fryer.black_sesame_tray.get_rect().get_center(), {"kind": &"product_source", "source_ref": {"source_kind": &"youtiao_fryer_slot", "source_index": 0}}), "a finished youtiao slot can be dropped onto the unlocked black sesame tray")
	workstation.queue_free()
	_finish()


func _visible_count(visuals: Array[TextureRect]) -> int:
	var count := 0
	for visual in visuals:
		if visual.visible:
			count += 1
	return count


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
