extends SceneTree

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const PROGRESSION := preload("res://scripts/services/five_area_progression_service.gd")
const WORKSTATION_SCENE := preload("res://scenes/gameplay/four_area_workstation.tscn")

const AREA_ID := &"area.packaged_drink"
const GROWTH_ID := &"growth.area.packaged_drink"
const PRODUCT_ID := &"product.packaged_drink.juice"
const STOCK_ID := &"stock.packaged_drink.juice"

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(CATALOG.validate_catalog().is_empty(), "four-area catalog stays internally valid")
	_check(CATALOG.AREA_IDS == [&"area.pancake", &"area.youtiao", &"area.fresh_soy_milk", AREA_ID], "packaged drinks are the fourth formal area")
	var drink_growth := CATALOG.growth_definition(GROWTH_ID)
	_check(int(drink_growth.get("price", 0)) == 80 and StringName(drink_growth.get("requires_area_id", &"")) == &"area.fresh_soy_milk" and not drink_growth.has("requires_tutorial_area_id") and not drink_growth.has("requires_mastery"), "juice rack requires only the unlocked soy area and 80 coins")
	var progression := PROGRESSION.new({
		"coins": 80,
		"current_day": 8,
		"unlocked_area_ids": [&"area.pancake", &"area.youtiao", &"area.fresh_soy_milk"],
		"unlocked_recipe_ids": [&"recipe.pancake.base", &"recipe.fresh_soy_milk.yellow_bean"],
		"unlocked_product_ids": [&"product.pancake.custom", &"product.fresh_soy_milk.yellow_bean"],
		"device_tiers": {&"device.pancake_griddle": 0, &"device.youtiao_fryer": 0, &"device.fresh_soy_milk_machine": 0},
		"area_mastery_details": {},
		"tutorial": {"completed_area_ids": [&"area.pancake"], "queue_area_ids": [], "active_kind": &"", "active_id": &""},
	})
	var purchased := Dictionary(progression.purchase(GROWTH_ID))
	_check(bool(purchased.get("success", false)) and not progression.owns_area(AREA_ID), "juice rack purchase remains pending until the next business day")
	progression.set_day_open(false)
	var activated := Dictionary(progression.begin_next_business_day())
	_check(bool(activated.get("success", false)) and progression.owns_area(AREA_ID) and progression.owns_product(PRODUCT_ID) and progression.owns_stock(STOCK_ID), "next day activates juice area, product and stock")
	progression.advance_tutorial_for_new_business_day()
	_check(StringName(Dictionary(progression.tutorial_snapshot()).get("active_id", &"")) == AREA_ID, "activated juice area immediately enters its teaching order")

	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession autoload exists")
	if session != null:
		session.call("begin_new_game")
		_unlock_juice(session)
		var workstation := WORKSTATION_SCENE.instantiate()
		root.add_child(workstation)
		await process_frame
		var station := workstation.get_node_or_null("FiveAreaInfrastructure/Stations/PackagedDrinkStation") as Control
		var lane_sources: Array = station.call("product_sources") if station != null else []
		_check(station != null and station.visible and lane_sources.size() == 1 and lane_sources[0].visible and lane_sources[0] is TextureButton, "right-bottom juice station exposes one physical juice-tray source after unlock")
		_check(FiveAreaProductVisuals.texture_for(PRODUCT_ID).resource_path.ends_with("boxed_orange_juice_v1.png"), "juice orders use the boxed orange-juice product art")
		var station_inventory := Dictionary(session.call("inventory_snapshot"))
		station_inventory[str(STOCK_ID)] = 0
		session.call("save_inventory", station_inventory)
		station.call("refresh_from_session")
		var tray_source := lane_sources[0] as ProductDragSource if not lane_sources.is_empty() else null
		_check(tray_source != null and tray_source.texture_normal != null and tray_source.texture_normal.resource_path.ends_with("yinpin-v1.png"), "zero juice stock displays the revised empty physical tray")
		var empty_tray_size := (load("res://resources/art/products/orange_juice/yinpin-v1.png") as Texture2D).get_size()
		var filled_tray_size := (load("res://resources/art/products/orange_juice/yinpin-v1-1.png") as Texture2D).get_size()
		_check(empty_tray_size == filled_tray_size, "empty and filled juice trays keep the same authored canvas size")
		station_inventory[str(STOCK_ID)] = 10
		session.call("save_inventory", station_inventory)
		station.call("refresh_from_session")
		_check(tray_source != null and tray_source.texture_normal != null and tray_source.texture_normal.resource_path.ends_with("yinpin-v1-10.png"), "ten juice boxes display the authored full physical tray art")
		var uses_all_stock_frames := true
		for stock_count in range(1, 11):
			var stock_texture := station.call("_stock_texture_for", PRODUCT_ID, stock_count) as Texture2D
			uses_all_stock_frames = uses_all_stock_frames and stock_texture != null and stock_texture.resource_path.ends_with("yinpin-v1-%d.png" % stock_count)
		_check(uses_all_stock_frames, "juice inventory one through ten maps to its matching authored stock frame")
		var soy_cups := workstation.get_node_or_null("FiveAreaInfrastructure/Stations/FreshSoyMilkStation/CupStack") as Control
		_check(station != null and soy_cups != null and not station.get_global_rect().intersects(soy_cups.get_global_rect()), "juice lane stays below the soy cup interaction region")
		var soy_station := workstation.get_node_or_null("FiveAreaInfrastructure/Stations/FreshSoyMilkStation") as Control
		_check(station != null and soy_station != null and not station.get_global_rect().intersects(soy_station.get_global_rect()), "juice station avoids the soy station input bounds")
		workstation.queue_free()
		await process_frame
		session.call("begin_new_game")
		var locked_workstation := WORKSTATION_SCENE.instantiate()
		root.add_child(locked_workstation)
		await process_frame
		var locked_station := locked_workstation.get_node_or_null("FiveAreaInfrastructure/Stations/PackagedDrinkStation") as Control
		_check(locked_station != null and not locked_station.visible, "locked packaged-drink area does not expose the live formal workstation tray")
		locked_workstation.queue_free()
		await process_frame
		_unlock_juice(session)
		var order_service: RefCounted = session.call("order_service")
		order_service.call("abandon_all_open_orders", &"packaged_drink_fixture")
		var inventory := Dictionary(session.call("inventory_snapshot"))
		inventory[str(STOCK_ID)] = 0
		session.call("save_inventory", inventory)
		session.call("credit_coins", 6)
		var status := Dictionary(session.call("five_area_restock_status", STOCK_ID))
		_check(int(status.get("capacity", 0)) == 10 and int(status.get("unit_cost", 0)) == 1, "juice uses ten-box, one-coin restock rules")
		var partial := Dictionary(session.call("advance_five_area_restock_hold", STOCK_ID, float(status.get("unit_seconds", 0.2)) * 0.5))
		_check(int(partial.get("completed_units", 0)) == 0 and float(Dictionary(session.call("five_area_restock_status", STOCK_ID)).get("progress_seconds", 0.0)) > 0.0, "juice partial refill progress is retained")
		var completed := Dictionary(session.call("advance_five_area_restock_hold", STOCK_ID, float(status.get("unit_seconds", 0.2)) * 0.5))
		_check(int(completed.get("completed_units", 0)) == 1 and int(Dictionary(session.call("inventory_snapshot")).get(str(STOCK_ID), 0)) == 1, "juice restock completes one inventory bottle")
		var item := {"area_id": AREA_ID, "product_id": PRODUCT_ID, "quantity": 1, "temperature_mode": &"room_temperature"}
		var opened := Dictionary(session.call("open_formal_order", [item], {"tutorial_no_countdown": true}))
		var order_id := StringName(Dictionary(opened.get("order", {})).get("order_id", &""))
		var source := {"source_kind": &"packaged_drink_inventory", "source_index": 0, "stock_id": STOCK_ID, "product_id": PRODUCT_ID}
		var preview := Dictionary(session.call("preview_stage_product_to_order", source, order_id, 0))
		_check(bool(preview.get("success", false)), "available juice previews as a deliverable product: %s" % str(preview.get("reason", &"")))
		var staged := Dictionary(session.call("stage_product_to_order", source, order_id, 0))
		_check(bool(staged.get("success", false)) and int(Dictionary(session.call("inventory_snapshot")).get(str(STOCK_ID), 0)) == 0, "successful juice delivery atomically consumes one bottle: %s" % str(staged.get("reason", &"")))
		var repeat := Dictionary(session.call("stage_product_to_order", source, order_id, 0))
		_check(not bool(repeat.get("success", false)), "empty juice lane cannot create a phantom second delivery")
		var settlement := Dictionary(session.call("complete_order_delivery", order_id))
		var mastery_details: Dictionary = Dictionary(session.call("five_area_progression_snapshot")).get("area_mastery_details", {})
		var drink_mastery: Dictionary = Dictionary(mastery_details.get(AREA_ID, {}))
		_check(bool(settlement.get("success", false)) and int(drink_mastery.get("qualified", 0)) >= 1, "completed juice order awards the normal packaged-drink mastery result")
		session.call("advance_five_area_restock_hold", STOCK_ID, float(status.get("unit_seconds", 0.2)))
		var click_workstation := WORKSTATION_SCENE.instantiate()
		root.add_child(click_workstation)
		await process_frame
		var click_opened := Dictionary(session.call("open_formal_order", [item], {"tutorial_no_countdown": true}))
		var click_order := Dictionary(click_opened.get("order", {}))
		click_workstation.call("_focus_formal_order", click_order)
		click_workstation.call("_on_order_dish_pressed", 0)
		_check(int(Dictionary(session.call("inventory_snapshot")).get(str(STOCK_ID), 0)) == 0, "order-card click delivery consumes exactly one juice bottle")
		click_workstation.queue_free()
		await process_frame
		_test_legacy_migration(session)
	_finish()


func _unlock_juice(session: Node) -> void:
	var progression: RefCounted = session.call("progression_service")
	var areas := Dictionary(progression.get("unlocked_area_ids")); areas[AREA_ID] = true; progression.set("unlocked_area_ids", areas)
	var recipes := Dictionary(progression.get("unlocked_recipe_ids")); recipes[&"recipe.packaged_drink.juice"] = true; progression.set("unlocked_recipe_ids", recipes)
	var products := Dictionary(progression.get("unlocked_product_ids")); products[PRODUCT_ID] = true; progression.set("unlocked_product_ids", products)
	var stocks := Dictionary(progression.get("unlocked_stock_ids")); stocks[STOCK_ID] = true; progression.set("unlocked_stock_ids", stocks)
	var devices := Dictionary(progression.get("device_tiers")); devices[&"device.packaged_drink_rack"] = 0; progression.set("device_tiers", devices)
	session.call("_sync_progression_to_save")


func _test_legacy_migration(session: Node) -> void:
	session.set("_save_data", {"progression": {"unlocked_area_ids": [&"area.pancake", AREA_ID], "unlocked_product_ids": [&"product.pancake.custom", &"product.packaged_drink.milk"]}, "inventory": {"stock.packaged_drink.milk": 6}})
	session.call("_migrate_retired_packaged_drink_state")
	var migrated := Dictionary(session.get("_save_data"))
	_check(not Array(Dictionary(migrated.get("progression", {})).get("unlocked_area_ids", [])).has(AREA_ID) and not Dictionary(migrated.get("inventory", {})).has("stock.packaged_drink.milk"), "legacy packaged-drink unlock and milk stock reset for the juice route")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PACKAGED_DRINK_JUICE_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
