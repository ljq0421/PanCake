extends SceneTree

const SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := FileAccess.get_file_as_string("res://scenes/gameplay/five_area_workstation.tscn")
	var fryer_scene_source := FileAccess.get_file_as_string("res://scenes/gameplay/cartoon_youtiao_fryer_toggle.tscn")
	var fryer_script_source := FileAccess.get_file_as_string("res://scripts/ui/cartoon_youtiao_fryer_toggle.gd")
	_check(not source.contains("direct_youtiao_station.tscn"), "retired direct fryer is not referenced by the live scene")
	var workstation := SCENE.instantiate()
	root.add_child(workstation)
	await process_frame
	var stations := workstation.get_node_or_null("FiveAreaInfrastructure/Stations") as Control
	_check(stations != null, "live shop exposes its station container")
	for station_name in [&"CartoonYoutiaoFryer", &"FreshSoyMilkStation", &"PackagedDrinkStation"]:
		_check(stations != null and stations.get_node_or_null(NodePath(str(station_name))) != null, "%s is present" % station_name)
	var pancake_station := workstation.get_node_or_null("SafeArea/JianbingStallArtwork") as Control
	_check(pancake_station != null and pancake_station.get_node_or_null("MultiGriddleStation") != null, "the unified pancake station owns its physical griddle")
	_check(stations != null and stations.get_node_or_null("PancakeStation") == null, "the former split pancake station wrapper is absent")
	_check(stations != null and stations.get_node_or_null("WasteBasket") != null, "the shared waste basket may coexist with production workstations")
	for retired_name in [&"YoutiaoStation", &"SteamerStation"]:
		_check(stations != null and stations.get_node_or_null(NodePath(str(retired_name))) == null, "%s is absent" % retired_name)
	var drinks := stations.get_node_or_null("PackagedDrinkStation") as Control if stations != null else null
	_check(drinks != null and drinks.has_signal("status_message") and drinks.call("product_sources").size() == 1, "visible packaged-drink station exposes one future-extensible juice lane")
	var fryer := stations.get_node_or_null("CartoonYoutiaoFryer") as CartoonYoutiaoFryerToggle if stations != null else null
	_check(fryer != null and fryer.has_signal("status_message"), "cartoon fryer exposes workstation status messages")
	_check(fryer != null and fryer.youtiao_progress_bar != null and fryer.chicken_progress_bar != null and fryer.youtiao_progress_bar.size.y >= 20.0 and fryer.chicken_progress_bar.size.y >= 20.0, "cartoon fryer authors clear independent progress bars for both cooking lanes")
	_check(fryer != null and fryer.plain_tray != null and fryer.chicken_tray != null and fryer.get_node_or_null("SesameTray") == null, "plain oil-strip and chicken-cutlet serving trays are authored beside the fryer, without the retired sesame tray")
	_check(fryer != null and not fryer_scene_source.contains("ChickenCutletRaw") and not source.contains("name=\"ChickenCutletRaw\""), "chicken has no separate raw-material restock region")
	_check(fryer != null and fryer.basket_products.name == &"LeftBasket" and fryer.chicken_basket_products.name == &"RightBasket" and fryer.fryer_layout_player.get_parent() == fryer.fryer_assembly, "the authored fryer assembly owns explicit left/right basket groups and its layout player")
	_check(fryer != null and [&"basic_raised", &"basic_lowered", &"advanced_raised", &"advanced_lowered", &"dual_both_raised", &"dual_left_lowered", &"dual_right_lowered", &"dual_both_lowered"].all(func(animation_name: StringName) -> bool: return fryer.fryer_layout_player.has_animation(animation_name)), "the scene authors every single- and dual-basket layout state")
	_check(fryer_scene_source.contains("FryerLayoutPlayer") and not fryer_script_source.contains("basket_products.position =") and not fryer_script_source.contains("chicken_basket_products.position =") and not fryer_script_source.contains("fryer_visual.size ="), "runtime code selects authored layout states without overwriting scene positions or sizes")
	_check(fryer != null and fryer.burnt_batch_source.get_parent() == fryer.fryer_visual, "the full-fryer burnt drag target inherits the authored fryer visual rectangle")
	_check(fryer != null and fryer.plain_tray.size == Vector2(235.0, 185.0), "the reusable plain tray preserves its live authored size")
	_check(fryer != null and fryer.output_sources.size() == 8 and fryer.plate_sources.size() == 8 and fryer.waste_source != null and fryer.get_node_or_null("PreparedPlain") == null and fryer.get_node_or_null("WasteTarget") == null, "cartoon fryer exposes both independently authored fryer lanes and serving trays")
	_check(fryer != null and fryer.output_sources.all(func(source: ProductDragSource) -> bool: return source.z_index > fryer.plain_tray.artwork.z_index), "finished youtiao drag sources render above serving-tray artwork")
	_check(fryer != null and fryer.fryer_slot_sources.all(func(source: ProductDragSource) -> bool: return source.native_drag_enabled and is_equal_approx(source.drag_threshold_pixels, 4.0)) and fryer.chicken_slot_sources.all(func(source: ProductDragSource) -> bool: return not source.native_drag_enabled) and fryer.plate_sources.all(func(source: ProductDragSource) -> bool: return source.native_drag_enabled and is_equal_approx(source.drag_threshold_pixels, 4.0)), "finished youtiao supports click-to-collect and dragging while chicken keeps click-to-collect")
	_check(fryer != null and fryer.plain_tray.product_sources.all(func(source: ProductDragSource) -> bool: return source._drop_forward_target == fryer.plain_tray), "stored oil strips forward drops to the plain serving-tray component")
	_check(fryer != null and fryer.output_sources.size() == 8 and fryer.fryer_slot_sources.all(func(source: ProductDragSource) -> bool: return source.get_parent() == fryer.basket_products) and fryer.chicken_slot_sources.all(func(source: ProductDragSource) -> bool: return source.get_parent() == fryer.chicken_basket_products), "two basket-product groups each own four visible click targets")
	_check(fryer != null and fryer.plain_tray.product_sources.size() == 4, "the reusable plain tray exposes four oil-stick positions")
	if fryer != null:
		var pancake_click_requests: Array[Dictionary] = []
		var capture_pancake_click := func(source_ref: Dictionary) -> void: pancake_click_requests.append(source_ref.duplicate(true))
		fryer.youtiao_add_to_pancake_requested.connect(capture_pancake_click)
		fryer._on_fryer_product_short_clicked({"source_kind": &"youtiao_fryer_slot", "source_index": 0, "product_id": &"product.youtiao.plain"})
		fryer._on_plain_tray_product_short_clicked({"source_kind": &"prepared_product_slot", "source_slot_id": &"slot.04", "source_index": 0, "product_id": &"product.youtiao.plain"})
		fryer.youtiao_add_to_pancake_requested.disconnect(capture_pancake_click)
		_check(pancake_click_requests.size() == 1, "prepared-tray youtiao clicks request one-click pancake placement while fryer clicks collect to the tray")
		var session: Node = root.get_node_or_null("GameSession")
		if session != null:
			var progression: RefCounted = session.call("progression_service")
			progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.youtiao": true})
			progression.set("unlocked_product_ids", {&"product.pancake.custom": true, &"product.youtiao.plain": true})
			fryer.set_workshop_preview(true)
			_check(fryer.get_node_or_null("SesameTray") == null, "workshop preview does not recreate the retired sesame tray")
			_check(not fryer.chicken_tray.visible, "advanced-youtiao workshop preview keeps chicken equipment locked")
			fryer.set_workshop_preview(false)
			fryer._machine = {"state": &"ready_to_collect", "capacity": 4, "quantity": 1, "occupied_slot_indices": [0]}
			fryer._apply_snapshot()
			_check(not fryer.plain_tray.visible and not fryer._can_drop_data(Vector2(260.0, 420.0), {"kind": &"product_source", "source_ref": {"source_kind": &"youtiao_fryer_slot", "source_index": 0}}), "before the finished tray unlock, fried youtiao stays in the raised filter basket")
			progression.set("owned_growth_ids", {&"growth.capacity.youtiao_finished_tray": true})
			fryer.refresh_from_session()
		fryer._machine = {"state": &"ready_to_collect", "capacity": 4, "quantity": 4, "occupied_slot_indices": [0, 1, 2, 3]}
		fryer._plate_count = 0
		fryer._apply_snapshot()
		_check(_visible_count(fryer.plate_sources) == 0, "finished youtiao remains in the basket until the player uses or stores it")
		_check(fryer.plain_tray._can_drop_data(fryer.plain_tray.size * 0.5, {"kind": &"product_source", "source_ref": {"source_kind": &"youtiao_fryer_slot", "source_index": 0, "product_id": &"product.youtiao.plain"}}), "finished fryer youtiao can still be dragged to the serving plate")
		fryer._plate_products = [{"product_id": &"product.youtiao.plain"}]
		fryer._plate_count = 1
		fryer._apply_snapshot()
		_check(_visible_count(fryer.plate_sources) == 1 and fryer.plain_tray.product_sources[0].visible and fryer.plain_tray.product_sources[0].position == fryer.plain_tray.slot_origin, "storing one fried youtiao displays one draggable product in the reusable plain tray")
		_check(fryer.plate_sources[0]._can_drop_data(fryer.plate_sources[0].size * 0.5, {"kind": &"product_source", "source_ref": {"source_kind": &"youtiao_fryer_slot", "source_index": 0, "product_id": &"product.youtiao.plain"}}), "dropping onto a stored oil strip forwards to the reusable serving tray")
		fryer._chicken_unlocked = true
		fryer._machine = {
			"state": &"idle",
			"capacity": 4,
			"quantity": 0,
			"tier": 2,
			"occupied_slot_indices": [],
			"lanes": {
				&"right": {"state": &"burnt", "capacity": 4, "quantity": 2, "occupied_slot_indices": [0, 1]},
			},
		}
		fryer._apply_snapshot()
		var burnt_chicken_source := fryer.chicken_slot_sources[0]
		var burnt_chicken_ref := burnt_chicken_source.source_ref()
		_check(
			burnt_chicken_source.visible
			and not burnt_chicken_source.disabled
			and burnt_chicken_source.native_drag_enabled
			and burnt_chicken_source.mouse_filter == Control.MOUSE_FILTER_STOP
			and bool(burnt_chicken_ref.get("discardable", false))
			and workstation.waste_area._can_drop_data(workstation.waste_area.size * 0.5, {"kind": &"product_source", "source_ref": burnt_chicken_ref}),
			"a burnt chicken cutlet can be dragged from the right filter to discard its entire batch",
		)
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
