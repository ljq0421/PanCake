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
	_check(fryer != null and fryer.black_sesame_tray != null, "black sesame tray is authored beside the fryer")
	_check(fryer != null and fryer.output_sources.size() == 4 and fryer.plate_sources.size() == 8 and fryer.prepared_slot != null and not fryer.prepared_slot.visible and fryer.waste_target != null, "cartoon fryer exposes four fryer sources and eight stored-product sources across two trays while keeping the former storage control hidden")
	_check(fryer != null and fryer.output_sources.all(func(source: ProductDragSource) -> bool: return source.z_index > fryer.black_sesame_tray.z_index), "finished youtiao drag sources render above the black sesame tray")
	_check(fryer != null and fryer.output_sources.all(func(source: ProductDragSource) -> bool: return is_equal_approx(source.drag_threshold_pixels, 4.0)) and fryer.plate_sources.all(func(source: ProductDragSource) -> bool: return is_equal_approx(source.drag_threshold_pixels, 4.0)), "oil-strip sources start dragging with a short movement")
	_check(fryer != null and fryer.plate_sources.all(func(source: ProductDragSource) -> bool: return source._drop_forward_target == fryer), "stored oil strips forward drops to their serving tray")
	_check(fryer != null and fryer.product_visuals.size() == 4 and fryer.raised_basket_slots.size() == 4 and fryer.lowered_basket_slots.size() == 4, "cartoon fryer renders exactly four fixed fryer slots")
	_check(fryer != null and fryer.plate_product_visuals.size() == 8 and fryer.plate_product_slots.size() == 4 and fryer.sesame_tray_product_slots.size() == 4, "serving and sesame trays each expose four oil-stick positions backed by eight stored-product visuals")
	if fryer != null:
		var session: Node = root.get_node_or_null("GameSession")
		if session != null:
			var progression: RefCounted = session.call("progression_service")
			progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.youtiao": true})
			progression.set("unlocked_product_ids", {&"product.pancake.custom": true, &"product.youtiao.plain": true})
			fryer.set_workshop_preview(true)
			_check(fryer.black_sesame_tray.visible and fryer.black_sesame_tray.texture != null and is_equal_approx(fryer.black_sesame_tray.self_modulate.a, 0.42), "locked black sesame tray is lazily loaded and translucent in the workshop preview")
			fryer.set_workshop_preview(false)
			fryer._machine = {"state": &"ready_to_collect", "capacity": 4, "quantity": 1, "occupied_slot_indices": [0]}
			fryer._apply_snapshot()
			_check(not fryer.plate_visual.visible and not fryer._can_drop_data(Vector2(470.0, 520.0), {"kind": &"product_source", "source_ref": {"source_kind": &"youtiao_fryer_slot", "source_index": 0}}), "before the finished tray unlock, fried youtiao stays in the raised filter basket")
			progression.set("owned_growth_ids", {&"growth.capacity.youtiao_finished_tray": true})
			fryer.refresh_from_session()
		fryer._machine = {"state": &"ready_to_collect", "capacity": 4, "quantity": 4, "occupied_slot_indices": [0, 1, 2, 3]}
		fryer._plate_count = 0
		fryer._apply_snapshot()
		_check(_visible_count(fryer.plate_product_visuals) == 0, "finished youtiao remains in the basket until each stick is dragged to the plate")
		_check(fryer._can_drop_data(fryer.plate_visual.get_rect().get_center(), {"kind": &"product_source", "source_ref": {"source_kind": &"youtiao_fryer_slot", "source_index": 0}}), "a single finished fryer slot can be dropped on the serving plate")
		fryer._plate_count = 1
		fryer._apply_snapshot()
		_check(_visible_count(fryer.plate_product_visuals) == 1 and fryer.plate_product_visuals[0].position == fryer.plate_product_slots[0].position and fryer.plate_sources[0].visible, "storing one fried youtiao displays one draggable scene-positioned plate visual")
		_check(fryer.plate_sources[0]._can_drop_data(fryer.plate_sources[0].size * 0.5, {"kind": &"product_source", "source_ref": {"source_kind": &"youtiao_fryer_slot", "source_index": 0}}), "a stored oil strip does not block dropping another fryer stick on the serving plate")
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
			fryer._plate_products = [{"product_id": &"product.youtiao.sesame"}]
			fryer._plate_count = 1
			fryer._apply_snapshot()
			_check(fryer.plate_product_visuals[0].visible and fryer.black_sesame_tray.get_rect().has_point(fryer.plate_product_visuals[0].get_rect().get_center()) and fryer.plate_product_visuals[0].z_index > fryer.black_sesame_tray.z_index, "sesame youtiao remains visibly above the sesame tray as its finished-product plate")
			_check(fryer.plate_sources[0].visible and fryer.plate_sources[0].z_index > fryer.black_sesame_tray.z_index and StringName(fryer.plate_sources[0].source_ref().get("product_id", &"")) == &"product.youtiao.sesame", "sesame tray product remains directly draggable to service")
	var game_session := root.get_node_or_null("GameSession")
	var griddle := workstation.multi_griddle_station as MultiGriddleStation
	var top_warning := workstation.get_node_or_null("SafeArea/TopWarningLabel") as Label
	_check(top_warning != null and not top_warning.visible, "top warning starts hidden")
	if griddle != null:
		griddle.transient_warning_requested.emit("面饼可能偏厚")
		await process_frame
		_check(top_warning != null and top_warning.visible and top_warning.text == "面饼可能偏厚", "griddle warning appears at the top of the shop")
		await create_timer(FiveAreaWorkstation.TOP_WARNING_DURATION_SECONDS + FiveAreaWorkstation.TOP_WARNING_FADE_SECONDS + 0.10).timeout
		_check(top_warning != null and not top_warning.visible, "top warning automatically fades away after the configured duration")
	if game_session != null and griddle != null:
		game_session.call("begin_new_game")
		griddle.bind_session(game_session)
		griddle.reset_all()
		griddle.call("_on_main_action", 0)
		_check(griddle.units[0].state == CompactGriddleUnit.State.BATTER, "fixture leaves an unfinished pancake on the live griddle")
		workstation.end_business_day({"reason": &"test_early_end"})
		await create_timer(1.1).timeout
		var saved_griddles := Dictionary(game_session.call("five_area_pancake_griddles_snapshot"))
		var saved_slots := Array(saved_griddles.get("slots", []))
		_check(griddle.units[0].state == CompactGriddleUnit.State.IDLE and (saved_slots.is_empty() or int(Dictionary(saved_slots[0]).get("state", -1)) == CompactGriddleUnit.State.IDLE), "day end clears the live unfinished pancake before it can resave during the workshop")
		_check(bool(Dictionary(game_session.call("begin_next_business_day")).get("success", false)) and griddle.units[0].state == CompactGriddleUnit.State.IDLE, "next business day never restores an unfinished pancake")
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
