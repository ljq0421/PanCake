extends SceneTree

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession autoload exists")
	if session == null:
		_finish()
		return
	session.call("reset_incompatible_development_save")
	var legacy_file := FileAccess.open(session.SAVE_PATH, FileAccess.WRITE)
	if legacy_file != null:
		legacy_file.store_string(JSON.stringify({
			"version": 4,
			"save_kind": "breakfast_stall_v1",
			"progression": {"coins": 999, "unlocked_area_ids": ["area.pancake", "area.packaged_drink", "area.steamer"]},
		}))
		legacy_file.close()
		session.call("_load_save")
		_check(not FileAccess.file_exists(session.SAVE_PATH), "v4 development save is removed instead of migrating retired multigrain stock or batches")
	else:
		print("INFO: user:// unavailable; disk incompatibility assertion skipped")
	var new_game := Dictionary(session.call("begin_new_game"))
	_check(bool(new_game.get("success", false)) and bool(session.call("has_save")), "new breakfast-stall save is created")
	_check(is_equal_approx(float(session.call("business_day_remaining_seconds")), 60.0), "first business day prepares a one-minute timer while the tutorial remains unlimited")
	_check(Dictionary(new_game.get("snapshot", {})).has("special_customer_state"), "new save includes optional deterministic special-customer state")
	var compact_file := FileAccess.open(session.SAVE_PATH, FileAccess.READ)
	if compact_file != null:
		var compact_text := compact_file.get_as_text()
		compact_file.close()
		_check("\n" not in compact_text and "\t" not in compact_text, "save JSON is written without pretty-print whitespace")
		_check(JSON.parse_string(compact_text) is Dictionary, "compact save JSON remains readable without a migration")
	var save_without_special_state := Dictionary(session.get("_save_data")).duplicate(true)
	save_without_special_state.erase("special_customer_state")
	session.set("_save_data", save_without_special_state)
	session.call("_ensure_save_shape")
	_check(Dictionary(session.get("_save_data")).has("special_customer_state") and int(Dictionary(session.get("_save_data")).get("version", 0)) == session.SAVE_VERSION, "current save shape restores optional special state without changing identity")
	_check(session.SAVE_VERSION >= 5 and session.SAVE_KIND == "breakfast_stall_v1", "save identity marks the current three-area breakfast-stall model")
	var retired_order_snapshot := {
		"version": 7,
		"active_order_id": "legacy.sesame",
		"active_order_ids": ["legacy.sesame"],
		"queue_order_ids": ["legacy.sesame"],
		"orders": {"legacy.sesame": {"state": &"active", "items": [{"area_id": &"area.youtiao", "product_id": &"product.youtiao.sesame"}]}},
	}
	var normalized_retired_orders := Dictionary(session.call("_normalize_formal_orders_for_active_catalog", retired_order_snapshot))
	var normalized_retired_promotions := Array(session.call("_normalize_order_promotions", [{"kind": &"product", "target_id": &"product.youtiao.sesame", "remaining_orders": 3}]))
	_check(Array(normalized_retired_orders.get("active_order_ids", [])).is_empty() and StringName(Dictionary(Dictionary(normalized_retired_orders.get("orders", {})).get("legacy.sesame", {})).get("state", &"")) == &"abandoned", "save normalization retires an active sesame-youtiao order")
	_check(normalized_retired_promotions.is_empty(), "save normalization removes pending sesame-youtiao promotions")
	var progression: RefCounted = session.call("progression_service")
	_check(bool(progression.call("owns_area", &"area.pancake")) and not bool(progression.call("owns_area", &"area.youtiao")) and not bool(progression.call("owns_area", &"area.fresh_soy_milk")), "new save opens only pancake area")
	var inventory := Dictionary(session.call("inventory_snapshot"))
	_check(inventory.has("stock.pancake.batter") and inventory.has("stock.youtiao.plain_dough") and not inventory.has("stock.fresh_soy_milk.yellow_bean"), "serving-only soy station does not create managed bean inventory")
	_check(int(inventory.get("stock.pancake.egg", -1)) == 6 and int(inventory.get("stock.pancake.baocui", -1)) == 0 and int(inventory.get("stock.pancake.scallion", -1)) == 0 and int(inventory.get("stock.pancake.sauce.sweet_flour", -1)) == 0, "new save starts with only the egg ingredient stocked and unlocked")
	for retired_stock in ["stock.packaged_drink.milk", "stock.packaged_drink.soy_milk", "stock.steamer.mantou", "stock.steamer.vegetable_bun"]:
		_check(not inventory.has(retired_stock), "%s is absent from the new inventory" % retired_stock)
	var production := Dictionary(session.call("five_area_production_snapshot"))
	_check(production.has("youtiao_fryer") and production.has("fresh_soy_milk_machine"), "production save retains youtiao and soy machine state")
	_check(not production.has("packaged_drink_heater") and not production.has("steamer"), "production save excludes retired machines")
	var first_order := Dictionary(session.call("ensure_active_playable_order"))
	_check(bool(first_order.get("success", false)), "new save can generate its first playable customer")
	var first_items := Array(Dictionary(session.call("active_formal_order")).get("items", []))
	_check(first_items.size() == 1 and StringName(Dictionary(first_items[0]).get("pancake_template_id", &"")) == &"order.pancake.egg", "new save begins with an egg-only pancake order")
	for order_value in Array(session.call("active_formal_orders")):
		for item_value in Array(Dictionary(order_value).get("items", [])):
			var area_id := StringName(Dictionary(item_value).get("area_id", &""))
			_check(area_id in [&"area.pancake", &"area.youtiao", &"area.fresh_soy_milk"], "generated formal orders stay inside three active areas")
	var settled_first := Dictionary(session.call("settle_f3_order", StringName(Dictionary(session.call("active_formal_order")).get("order_id", &"")), true))
	var replenished_open_count := Array(session.call("active_formal_orders")).size() + Array(session.call("waiting_formal_orders")).size()
	_check(
		bool(settled_first.get("success", false))
		and bool(Dictionary(settled_first.get("refill", {})).get("success", false))
		and replenished_open_count > 0,
		"settling a formal order replenishes the durable customer queue without a workstation callback"
	)
	progression.coins = 200
	progression.reputation = 30
	progression.current_day = 4
	progression.area_mastery_details = {&"area.pancake": {"qualified": 6, "a_grade": 4}}
	progression.tutorial_completed_area_ids = {&"area.pancake": true}
	progression.tutorial_active_kind = &""
	progression.tutorial_active_id = &""
	_check(bool(session.call("purchase_growth", &"growth.area.youtiao").get("success", false)), "session persists youtiao installation purchase")
	for order_value in Array(session.call("active_formal_orders")):
		session.call("abandon_formal_order", StringName(Dictionary(order_value).get("order_id", &"")), &"test_cleanup")
	session.call("end_business_day")
	var next_day := Dictionary(session.call("begin_next_business_day"))
	var next_day_open_orders := Array(session.call("active_formal_orders")).size() + Array(session.call("waiting_formal_orders")).size()
	_check(
		bool(next_day.get("success", false))
		and bool(Dictionary(next_day.get("customer_queue", {})).get("success", false))
		and next_day_open_orders > 0
		and is_equal_approx(float(session.call("business_day_remaining_seconds")), session.BUSINESS_DAY_DURATION_SECONDS)
		and bool(progression.call("owns_area", &"area.youtiao")),
		"later business days restore the normal duration, activate youtiao, and immediately generate visible customers"
	)
	session.call("_write_save")
	session.call("_load_save")
	session.call("_restore_progression")
	var restored: RefCounted = session.call("progression_service")
	_check(bool(restored.call("owns_area", &"area.youtiao")) and not bool(restored.call("owns_area", &"area.packaged_drink")), "save reload restores active area and never revives retired area")
	var restored_inventory := Dictionary(session.call("inventory_snapshot"))
	_check(not restored_inventory.has("stock.packaged_drink.milk") and not restored_inventory.has("stock.steamer.mantou"), "save reload keeps retired stock filtered")
	var soy_test_profile := Dictionary(session.call("open_soy_test_profile"))
	var soy_test_order := Dictionary(session.call("active_formal_order"))
	var soy_test_items := Array(soy_test_order.get("items", []))
	var soy_test_progression: RefCounted = session.call("progression_service")
	_check(bool(soy_test_profile.get("success", false)) and not bool(soy_test_progression.call("owns_assist", &"assist.fresh_soy_milk.sugar")), "soy test profile leaves the sugar jar locked")
	_check(soy_test_items.size() == 1 and int(Dictionary(soy_test_items[0]).get("sugar_servings", -1)) == 0, "locked sugar jar never creates a sweetened soy test order")
	session.call("reset_incompatible_development_save")
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("THREE_AREA_GAME_SESSION_STORE_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("THREE_AREA_GAME_SESSION_STORE_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
