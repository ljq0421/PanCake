extends SceneTree

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const WORKSTATION_SCENE := preload("res://scenes/gameplay/four_area_workstation.tscn")
const SCREENSHOT_PATH := "res://tmp/validation/workbench_p1_full_unlock_1920x1080.png"

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("WORKBENCH_P1_FULL_UNLOCK_GPU_SMOKE_FAIL\nGPU mode required")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession is available")
	if session == null:
		_finish("")
		return
	_setup_full_unlock(session)
	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	for _frame in 8:
		await process_frame
	workstation.set_process(false)
	workstation.set("_restore_customer_layout_without_entrance", true)
	workstation.set("_customer_service_slot_signatures", {})
	workstation.call("_refresh_customer_service_slots", _preview_orders())
	for _frame in 8:
		await process_frame

	var griddle_art := workstation.get_node("SafeArea/JianbingStallArtwork/MultiGriddleStation/Griddle01/GriddleArt") as TextureRect
	var pancake_surface := workstation.get_node("SafeArea/JianbingStallArtwork/MultiGriddleStation/Griddle01/PancakeSurface") as Control
	var soy_station := workstation.get_node("FiveAreaInfrastructure/Stations/FreshSoyMilkStation") as DirectSoyStation
	var soy_art := soy_station.get_node("MachineAssembly/SoyMilkDispenser") as TextureRect
	var fryer := workstation.get_node("FiveAreaInfrastructure/Stations/CartoonYoutiaoFryer") as CartoonYoutiaoFryerToggle
	var fifth_customer := workstation.get_node("SafeArea/ServiceCustomer5") as Control
	var background := workstation.get_node("SafeArea/BackgroundArtwork") as TextureRect
	var drink_source := workstation.packaged_drink_station.product_sources()[0] as ProductDragSource
	var egg_visual := workstation.get_node("SafeArea/JianbingStallArtwork/PancakeWorktopHotspots/EggCarton/Visual") as TextureRect
	var ham_visual := workstation.get_node("SafeArea/JianbingStallArtwork/PancakeWorktopHotspots/HamSource/Visual") as IngredientTrayVisual
	var floss_visual := workstation.get_node("SafeArea/JianbingStallArtwork/PancakeWorktopHotspots/PorkFlossSource/Visual") as IngredientTrayVisual
	var zone_backdrop := workstation.get_node("SafeArea/WorkstationZoneBackdrop") as WorkbenchZoneBackdrop

	_check(griddle_art.size == Vector2(455, 302) and pancake_surface.size == Vector2(314, 314), "griddle shell is smaller while the usable surface remains full-size")
	_check(soy_station.visible and soy_art.size == Vector2(315, 300), "fully unlocked soy machine uses the reduced footprint")
	_check(fryer.visible and fryer.fryer_visual.material != null, "fully unlocked fryer uses the lowered-panel material")
	_check(background.material != null, "worktop contrast treatment is active")
	var fifth_portrait := fifth_customer.get_node("Portrait") as TextureRect
	var fifth_painted_rect := _painted_texture_rect(fifth_portrait)
	var soy_painted_rect := _painted_texture_rect(soy_art)
	_check(Rect2(Vector2.ZERO, Vector2(1920, 1080)).encloses(soy_painted_rect), "soy machine painted body stays inside the 1920x1080 viewport")
	_check(fifth_customer.visible and (fifth_customer.get_node("OrderPanel") as Control).visible, "the full-unlock capture renders a real fifth customer and order card")
	_check(not fifth_painted_rect.intersects(soy_painted_rect), "reduced soy machine painted body does not overlap the fifth customer portrait (portrait=%s soy=%s)" % [fifth_painted_rect, soy_painted_rect])
	_check(drink_source.find_children("Representative*", "TextureRect", false, false).size() == 5 and (drink_source.get_node("CountBadge") as Label).text == "×10", "packaged drinks use representative cartons plus a real quantity badge")
	_check(egg_visual.texture.resource_path.ends_with("container-m-egg-full-p1-v2-transparent.png") and not (egg_visual.get_node("InventoryCountBadge") as Label).visible, "egg inventory uses one P1 representative tray without a numeric small-ingredient label")
	_check(ham_visual.texture == ham_visual.state_textures.back() and not (ham_visual.get_node("InventoryCountBadge") as Label).visible, "ham inventory uses one representative tray without a numeric small-ingredient label")
	_check(floss_visual.texture == floss_visual.state_textures.back() and not (floss_visual.get_node("InventoryCountBadge") as Label).visible, "meat-floss inventory uses one representative tray without a numeric small-ingredient label")
	_check(soy_station.cup_stack.texture_normal.resource_path.ends_with("soy_milk_plastic_cup_stack_4_v3_bold_cartoon_transparent.png") and (soy_station.cup_stack.get_node("InventoryCountBadge") as Label).text == "×8", "soy cups use a four-cup representative stack plus the real quantity badge")
	_check(zone_backdrop.active_zone_id() == &"area.pancake", "the first focused order highlights the matching pancake work zone")
	var pancake_zone := zone_backdrop.zone_polygon(&"area.pancake")
	_check(pancake_zone.size() == 4 and pancake_zone[0].x > pancake_zone[3].x and pancake_zone[1].x > pancake_zone[2].x, "work-zone frames converge toward the tabletop vanishing point instead of using front-view rectangles")
	_check((workstation.get_node("SafeArea/AttentionRail/Attention02") as Label).visible == false and (workstation.get_node("SafeArea/AttentionRail/Attention03") as Label).visible == false, "top HUD reserves one reminder entry instead of a competing reminder row")

	await RenderingServer.frame_post_draw
	var output_absolute := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(output_absolute.get_base_dir())
	var screenshot := root.get_texture().get_image()
	_check(screenshot.save_png(output_absolute) == OK and screenshot.get_size() == Vector2i(1920, 1080), "full-unlock P1 frame captures at 1920x1080")
	workstation.queue_free()
	await process_frame
	_finish(output_absolute)


func _setup_full_unlock(session: Node) -> void:
	session.call("begin_new_game")
	var progression: RefCounted = session.call("progression_service")
	var areas := {}
	for area_id in CATALOG.AREA_IDS:
		areas[area_id] = true
	var stocks := {}
	for stock_id in CATALOG.STOCK_DEFINITIONS:
		stocks[stock_id] = true
	var recipes := {}
	for recipe_id in CATALOG.RECIPE_DEFINITIONS:
		recipes[recipe_id] = true
	var products := {}
	for product_id in CATALOG.PRODUCT_DEFINITIONS:
		products[product_id] = true
	var growth := {}
	for growth_id in CATALOG.GROWTH_DISPLAY_ORDER:
		growth[growth_id] = true
	var automation := {}
	for automation_id in CATALOG.AUTOMATION_DEFINITIONS:
		automation[automation_id] = true
	progression.set("coins", 999)
	progression.set("unlocked_area_ids", areas)
	progression.set("unlocked_stock_ids", stocks)
	progression.set("unlocked_recipe_ids", recipes)
	progression.set("unlocked_product_ids", products)
	progression.set("owned_growth_ids", growth)
	progression.set("unlocked_automation_ids", automation)
	progression.set("owned_assist_ids", {&"assist.fresh_soy_milk.sugar": true})
	progression.set("device_tiers", {&"device.pancake_griddle": 0, &"device.youtiao_fryer": 2, &"device.fresh_soy_milk_machine": 0, &"device.packaged_drink_rack": 0})
	progression.set("tutorial_completed_area_ids", areas.duplicate(true))
	session.call("_sync_progression_to_save")
	session.set("_production_service", null)
	session.call("_ensure_production_service")
	var inventory := Dictionary(session.call("inventory_snapshot"))
	for stock_id in CATALOG.STOCK_DEFINITIONS:
		if not bool(Dictionary(CATALOG.STOCK_DEFINITIONS[stock_id]).get("unlimited", false)):
			inventory[str(stock_id)] = int(Dictionary(CATALOG.STOCK_DEFINITIONS[stock_id]).get("restock_capacity", 4))
	session.call("save_inventory", inventory)
	var order_service: RefCounted = session.call("order_service")
	order_service.call("abandon_all_open_orders", &"p1_full_unlock_capture")
	var order_items := [
		{"area_id": &"area.pancake", "product_id": &"product.pancake.custom", "quantity": 1, "ingredient_ids": PackedStringArray(), "sauce_ids": PackedStringArray()},
		{"area_id": &"area.youtiao", "product_id": &"product.youtiao.plain", "quantity": 1},
		{"area_id": &"area.fresh_soy_milk", "product_id": &"product.fresh_soy_milk.yellow_bean", "quantity": 1, "sugar_servings": 0},
		{"area_id": &"area.packaged_drink", "product_id": &"product.packaged_drink.juice", "quantity": 1},
		{"area_id": &"area.youtiao", "product_id": &"product.chicken.cutlet", "quantity": 1},
	]
	for item in order_items:
		session.call("open_formal_order", [item], {"patience_seconds": 120.0, "tutorial_no_countdown": true})


func _preview_orders() -> Array:
	var products := [
		{"area_id": &"area.pancake", "product_id": &"product.pancake.custom", "quantity": 1, "prepared_product_instance_ids": []},
		{"area_id": &"area.youtiao", "product_id": &"product.youtiao.plain", "quantity": 1, "prepared_product_instance_ids": []},
		{"area_id": &"area.fresh_soy_milk", "product_id": &"product.fresh_soy_milk.yellow_bean", "quantity": 1, "prepared_product_instance_ids": []},
		{"area_id": &"area.packaged_drink", "product_id": &"product.packaged_drink.juice", "quantity": 1, "prepared_product_instance_ids": []},
		{"area_id": &"area.youtiao", "product_id": &"product.chicken.cutlet", "quantity": 1, "prepared_product_instance_ids": []},
	]
	var orders: Array = []
	for slot_index in 5:
		orders.append({
			"order_id": StringName("p1.full.%d" % slot_index),
			"service_slot": slot_index,
			"customer_id": StringName("customer_%02d" % (slot_index + 1)),
			"patience_seconds": 120.0,
			"remaining_patience_seconds": 120.0 - slot_index * 9.0,
			"perfect_quote_coins": 12,
			"items": [Dictionary(products[slot_index]).duplicate(true)],
		})
	return orders


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _painted_texture_rect(texture_rect: TextureRect) -> Rect2:
	if texture_rect == null or texture_rect.texture == null:
		return Rect2()
	var image := texture_rect.texture.get_image()
	if image == null or image.is_empty():
		return texture_rect.get_global_rect()
	var used := image.get_used_rect()
	var texture_size := Vector2(image.get_size())
	var scale_factor := minf(texture_rect.size.x / texture_size.x, texture_rect.size.y / texture_size.y)
	var drawn_size := texture_size * scale_factor
	var draw_offset := (texture_rect.size - drawn_size) * 0.5
	return Rect2(texture_rect.global_position + draw_offset + Vector2(used.position) * scale_factor, Vector2(used.size) * scale_factor)


func _finish(output_absolute: String) -> void:
	if failures.is_empty():
		print("WORKBENCH_P1_FULL_UNLOCK_GPU_SMOKE_PASS")
		print("WORKBENCH_P1_FULL_UNLOCK_SCREENSHOT=%s" % output_absolute)
		quit(0)
		return
	printerr("WORKBENCH_P1_FULL_UNLOCK_GPU_SMOKE_FAIL\n%s" % "\n".join(failures))
	quit(1)
