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
	_check(stations != null, "live shop exposes its station container")
	for station_name in [&"CartoonYoutiaoFryer", &"FreshSoyMilkStation"]:
		_check(stations != null and stations.get_node_or_null(NodePath(str(station_name))) != null, "%s is present" % station_name)
	var pancake_station := workstation.get_node_or_null("SafeArea/JianbingStallArtwork") as Control
	_check(pancake_station != null and pancake_station.get_node_or_null("MultiGriddleStation") != null, "the unified pancake station owns its physical griddle")
	_check(stations != null and stations.get_node_or_null("PancakeStation") == null, "the former split pancake station wrapper is absent")
	_check(stations != null and stations.get_node_or_null("WasteBasket") != null, "the shared waste basket may coexist with production workstations")
	for retired_name in [&"YoutiaoStation", &"SteamerStation", &"PackagedDrinkStation"]:
		_check(stations != null and stations.get_node_or_null(NodePath(str(retired_name))) == null, "%s is absent" % retired_name)
	var fryer := stations.get_node_or_null("CartoonYoutiaoFryer") as CartoonYoutiaoFryerToggle if stations != null else null
	_check(fryer != null and fryer.has_signal("status_message"), "cartoon fryer exposes workstation status messages")
	_check(fryer != null and fryer.plain_tray != null and fryer.sesame_tray != null, "plain and sesame serving trays are reusable authored components beside the fryer")
	_check(fryer != null and fryer.plain_tray.size == Vector2(278.0, 237.0) and fryer.sesame_tray.size == Vector2(219.0, 206.0), "each reusable tray instance preserves its independently authored size")
	_check(fryer != null and fryer.output_sources.size() == 4 and fryer.plate_sources.size() == 8 and fryer.waste_source != null and fryer.get_node_or_null("PreparedPlain") == null and fryer.get_node_or_null("WasteTarget") == null, "cartoon fryer exposes authored fryer/tray sources without the former hidden storage and duplicate waste controls")
	_check(fryer != null and fryer.output_sources.all(func(source: ProductDragSource) -> bool: return source.z_index > fryer.sesame_tray.artwork.z_index), "finished youtiao drag sources render above serving-tray artwork")
	_check(fryer != null and fryer.output_sources.all(func(source: ProductDragSource) -> bool: return is_equal_approx(source.drag_threshold_pixels, 4.0)) and fryer.plate_sources.all(func(source: ProductDragSource) -> bool: return is_equal_approx(source.drag_threshold_pixels, 4.0)), "oil-strip sources start dragging with a short movement")
	_check(fryer != null and fryer.plain_tray.product_sources.all(func(source: ProductDragSource) -> bool: return source._drop_forward_target == fryer.plain_tray) and fryer.sesame_tray.product_sources.all(func(source: ProductDragSource) -> bool: return source._drop_forward_target == fryer.sesame_tray), "stored oil strips forward drops to their owning serving-tray component")
	_check(fryer != null and fryer.output_sources.size() == 4 and fryer.output_sources.all(func(source: ProductDragSource) -> bool: return source.get_parent() == fryer.basket_products), "one basket-products group owns exactly four visible-and-draggable fryer slots")
	_check(fryer != null and fryer.plain_tray.product_sources.size() == 4 and fryer.sesame_tray.product_sources.size() == 4, "the reusable plain and sesame tray components each expose four oil-stick positions")
	if fryer != null:
		var session: Node = root.get_node_or_null("GameSession")
		if session != null:
			var progression: RefCounted = session.call("progression_service")
			progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.youtiao": true})
			progression.set("unlocked_product_ids", {&"product.pancake.custom": true, &"product.youtiao.plain": true})
			fryer.set_workshop_preview(true)
			_check(fryer.sesame_tray.visible and fryer.sesame_tray.artwork.texture != null and is_equal_approx(fryer.sesame_tray.self_modulate.a, 0.42), "locked black sesame tray is lazily loaded and translucent in the workshop preview")
			fryer.set_workshop_preview(false)
			fryer._machine = {"state": &"ready_to_collect", "capacity": 4, "quantity": 1, "occupied_slot_indices": [0]}
			fryer._apply_snapshot()
			_check(not fryer.plain_tray.visible and not fryer._can_drop_data(Vector2(260.0, 420.0), {"kind": &"product_source", "source_ref": {"source_kind": &"youtiao_fryer_slot", "source_index": 0}}), "before the finished tray unlock, fried youtiao stays in the raised filter basket")
			progression.set("owned_growth_ids", {&"growth.capacity.youtiao_finished_tray": true})
			fryer.refresh_from_session()
		fryer._machine = {"state": &"ready_to_collect", "capacity": 4, "quantity": 4, "occupied_slot_indices": [0, 1, 2, 3]}
		fryer._plate_count = 0
		fryer._apply_snapshot()
		_check(_visible_count(fryer.plate_sources) == 0, "finished youtiao remains in the basket until each stick is dragged to the plate")
		_check(fryer._can_drop_data(fryer.plain_tray.position + fryer.plain_tray.size * 0.5, {"kind": &"product_source", "source_ref": {"source_kind": &"youtiao_fryer_slot", "source_index": 0}}), "a single finished fryer slot can be dropped on the serving plate")
		fryer._plate_products = [{"product_id": &"product.youtiao.plain"}]
		fryer._plate_count = 1
		fryer._apply_snapshot()
		_check(_visible_count(fryer.plate_sources) == 1 and fryer.plain_tray.product_sources[0].visible and fryer.plain_tray.product_sources[0].position == fryer.plain_tray.slot_origin, "storing one fried youtiao displays one draggable product in the reusable plain tray")
		_check(fryer.plate_sources[0]._can_drop_data(fryer.plate_sources[0].size * 0.5, {"kind": &"product_source", "source_ref": {"source_kind": &"youtiao_fryer_slot", "source_index": 0}}), "a stored oil strip does not block dropping another fryer stick on the serving plate")
		if session != null:
			var progression: RefCounted = session.call("progression_service")
			var unlocked_products: Dictionary = Dictionary(progression.get("unlocked_product_ids"))
			unlocked_products[&"product.youtiao.sesame"] = true
			progression.set("unlocked_product_ids", unlocked_products)
			fryer.refresh_from_session()
			_check(fryer.sesame_tray.visible, "black sesame tray appears with the existing sesame oil-stick unlock")
			fryer._machine = {"state": &"ready_to_collect", "capacity": 4, "quantity": 1, "occupied_slot_indices": [0]}
			fryer._plate_count = 0
			_check(fryer._can_drop_data(fryer.sesame_tray.position + fryer.sesame_tray.size * 0.5, {"kind": &"product_source", "source_ref": {"source_kind": &"youtiao_fryer_slot", "source_index": 0}}), "a finished youtiao slot can be dropped onto the unlocked black sesame tray")
			fryer._plate_products = [{"product_id": &"product.youtiao.sesame"}]
			fryer._plate_count = 1
			fryer._apply_snapshot()
			var sesame_source := fryer.sesame_tray.product_sources[0] as ProductDragSource
			_check(sesame_source.visible and Rect2(Vector2.ZERO, fryer.sesame_tray.size).has_point(sesame_source.get_rect().get_center()) and sesame_source.z_index > fryer.sesame_tray.artwork.z_index, "sesame youtiao remains visibly above its reusable serving-tray artwork")
			_check(sesame_source.visible and StringName(sesame_source.source_ref().get("product_id", &"")) == &"product.youtiao.sesame", "sesame tray product remains directly draggable to service")
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


func _visible_count(visuals: Array) -> int:
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
		print("LIVE_WORKSTATION_FORMAL_SCENE_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("LIVE_WORKSTATION_FORMAL_SCENE_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
