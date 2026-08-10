extends SceneTree

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession is available for the playable order loop")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	var progression: RefCounted = session.call("progression_service")
	_unlock_three_areas(progression)
	_set_active_tutorial(progression, &"area.packaged_drink", [&"area.pancake"])
	var inventory: Dictionary = session.call("inventory_snapshot")
	inventory["stock.packaged_drink.milk"] = 0
	inventory["stock.youtiao.plain_dough"] = 1
	session.call("save_inventory", inventory)

	var drink_opened: Dictionary = session.call("ensure_active_playable_order")
	var drink_order := Dictionary(drink_opened.get("order", {}))
	var drink_id := StringName(drink_order.get("order_id", &""))
	var drink_item := Dictionary(Array(drink_order.get("items", []))[0]) if not Array(drink_order.get("items", [])).is_empty() else {}
	_check(bool(drink_opened.get("success", false)) and _area_id(drink_order) == &"area.packaged_drink" and StringName(drink_order.get("teaching_area_id", &"")) == &"area.packaged_drink", "zero stock still opens the protected drink teaching customer")
	_check(Array(drink_order.get("items", [])).size() == 1 and StringName(drink_item.get("product_id", &"")) == &"product.packaged_drink.milk" and StringName(drink_item.get("temperature_mode", &"")) == &"room_temperature", "drink teaching customer orders only one room-temperature packaged milk")
	_check(Array(session.call("active_formal_orders")).size() == 1 and Array(session.call("waiting_formal_orders")).size() == 3, "drink teaching exclusively occupies the store while normal customers wait")
	inventory["stock.packaged_drink.milk"] = 1
	session.call("save_inventory", inventory)
	_check(StringName(Dictionary(session.call("active_formal_order")).get("order_id", &"")) == drink_id, "restocking preserves the already visible drink teaching customer")
	_check(bool(Dictionary(session.call("deliver_room_temperature_drink", drink_id, 0, &"product.packaged_drink.milk")).get("success", false)), "room-temperature drink is delivered through the formal teaching order")
	var drink_settlement: Dictionary = session.call("settle_f3_order", drink_id)
	_check(bool(drink_settlement.get("order_success", false)) and int(drink_settlement.get("earned_coins", 0)) == 3, "drink teaching settles with its catalog revenue")
	_check(int(progression.call("mastery_value", &"area.packaged_drink")) == 1 and Array(Dictionary(progression.call("tutorial_snapshot")).get("completed_area_ids", [])).has("area.packaged_drink"), "drink settlement updates temperature mastery and completes teaching")

	_set_active_tutorial(progression, &"area.youtiao", [&"area.pancake", &"area.packaged_drink"])
	# Teaching priority is per day. Move to a new day without exercising the
	# growth purchase surface so this integration remains about order routing.
	session.call("abandon_active_formal_order", &"business_day_expired")
	progression.set("current_day", int(progression.get("current_day")) + 1)
	var youtiao_opened: Dictionary = session.call("ensure_active_playable_order")
	var youtiao_order := Dictionary(youtiao_opened.get("order", {}))
	var youtiao_id := StringName(youtiao_order.get("order_id", &""))
	_check(_area_id(youtiao_order) == &"area.youtiao" and bool(youtiao_order.get("tutorial_no_countdown", false)) and is_equal_approx(float(youtiao_order.get("patience_seconds", 0.0)), 36.0), "next-day youtiao teaching routes as an unlimited-time tutorial order")
	_check(bool(Dictionary(session.call("load_f3_youtiao", &"recipe.youtiao.plain", 1, youtiao_id)).get("success", false)), "starting the youtiao batch consumes its teaching stock")
	session.call("perform_f3_youtiao_action", &"start")
	session.call("advance_f3_production", 12.0)
	session.call("perform_f3_youtiao_action", &"lift")
	session.call("advance_f3_production", 2.0)
	_check(bool(Dictionary(session.call("store_ready_youtiao_in_prepared_slot", &"slot.04")).get("success", false)), "finished youtiao first enters its fixed prepared-product slot")
	_check(bool(Dictionary(session.call("deliver_f3_youtiao", youtiao_id, 0)).get("success", false)), "Slot04 youtiao attaches to its generated formal order")
	var youtiao_settlement: Dictionary = session.call("settle_f3_order", youtiao_id)
	_check(bool(youtiao_settlement.get("order_success", false)) and int(youtiao_settlement.get("earned_coins", 0)) == 6, "youtiao teaching settles with its catalog revenue")
	_check(int(progression.call("mastery_value", &"area.youtiao")) == 1, "youtiao settlement advances qualified mastery")

	var next_order_result: Dictionary = session.call("ensure_active_playable_order")
	var next_order := Dictionary(next_order_result.get("order", {}))
	_check(bool(next_order_result.get("success", false)) and _is_supported(_area_id(next_order)) and Array(next_order.get("items", [])).size() == 1, "settlement advances to another supported single-item formal order")
	var reputation_before_refusal := int(progression.get("reputation"))
	var next_order_id := StringName(next_order.get("order_id", &""))
	var refusal_preview: Dictionary = session.call("preview_formal_order_refusal", next_order_id)
	var refused: Dictionary = session.call("refuse_formal_order", next_order_id)
	_check(int(refusal_preview.get("reputation_delta", 0)) == -1 and StringName(refused.get("terminal_state", &"")) == &"refused", "an unstarted normal order can be previewed and formally refused")
	_check(int(progression.get("reputation")) == reputation_before_refusal - 1, "formal refusal applies its reputation loss exactly once")
	var bill: Dictionary = session.call("today_bill")
	_check(int(bill.get("order_count", 0)) == 3 and int(bill.get("total_coins", 0)) == 9, "successful and refused orders enter the daily bill exactly once without refusal revenue")
	_check_active_f3_restore(session)
	_check_deterministic_reload(session)
	_finish()


func _check_active_f3_restore(session: Node) -> void:
	# Direct restore fixtures own their queue. Clear the normal four-card queue
	# left by the preceding live-loop assertions before opening a targeted order.
	session.call("abandon_active_formal_order", &"business_day_expired")
	var inventory: Dictionary = session.call("inventory_snapshot")
	inventory["stock.packaged_drink.milk"] = 2
	inventory["stock.youtiao.plain_dough"] = 2
	session.call("save_inventory", inventory)

	var drink_opened: Dictionary = session.call("open_formal_order", [{
		"area_id": &"area.packaged_drink",
		"product_id": &"product.packaged_drink.milk",
		"quantity": 1,
		"temperature_mode": &"heated",
	}], {"patience_seconds": 24.0})
	var drink_id := StringName(Dictionary(drink_opened.get("order", {})).get("order_id", &""))
	session.call("load_f3_drink", 0, &"product.packaged_drink.milk", drink_id)
	session.call("advance_f3_production", 0.75)
	session.call("advance_formal_order_patience", 5.5)
	session.call("_restore_progression")
	var restored_drink: Dictionary = session.call("active_formal_order")
	var restored_heater: Dictionary = session.call("f3_machine_snapshot", &"device.packaged_drink_heater")
	var restored_slot := Dictionary(Array(restored_heater.get("slots", []))[0])
	_check(
		StringName(restored_drink.get("order_id", &"")) == drink_id
		and is_equal_approx(float(restored_drink.get("remaining_patience_seconds", 0.0)), 18.5)
		and StringName(restored_slot.get("state", &"")) == &"heating"
		and is_equal_approx(float(restored_slot.get("elapsed_seconds", 0.0)), 0.75),
		"active heated-drink order, patience, and heater state survive save restoration"
	)
	session.call("abandon_active_formal_order", &"restore_check_complete")
	session.call("discard_f3_drink", 0)

	var youtiao_opened: Dictionary = session.call("open_formal_order", [{
		"area_id": &"area.youtiao",
		"product_id": &"product.youtiao.plain",
		"quantity": 1,
		"temperature_mode": &"room_temperature",
	}], {"patience_seconds": 36.0})
	var youtiao_id := StringName(Dictionary(youtiao_opened.get("order", {})).get("order_id", &""))
	session.call("load_f3_youtiao", &"recipe.youtiao.plain", 1, youtiao_id)
	session.call("perform_f3_youtiao_action", &"start")
	session.call("advance_f3_production", 1.25)
	session.call("advance_formal_order_patience", 4.0)
	session.call("_restore_progression")
	var restored_youtiao: Dictionary = session.call("active_formal_order")
	var restored_fryer: Dictionary = session.call("f3_machine_snapshot", &"device.youtiao_fryer")
	_check(
		StringName(restored_youtiao.get("order_id", &"")) == youtiao_id
		and is_equal_approx(float(restored_youtiao.get("remaining_patience_seconds", 0.0)), 32.0)
		and StringName(restored_fryer.get("state", &"")) == &"frying"
		and is_equal_approx(float(restored_fryer.get("cooking_elapsed_seconds", 0.0)), 1.25),
		"active youtiao order, patience, and fryer state survive save restoration"
	)


func _check_deterministic_reload(session: Node) -> void:
	session.call("begin_new_game")
	var progression: RefCounted = session.call("progression_service")
	progression.set("tutorial_completed_area_ids", {&"area.pancake": true})
	progression.set("tutorial_queue_area_ids", [])
	progression.set("tutorial_active_kind", &"")
	progression.set("tutorial_active_id", &"")
	# This fixture edits the progression service directly, so persist that edit
	# before taking the branch snapshot just as the public progression APIs do.
	session.call("_sync_progression_to_save")
	var first_opened: Dictionary = session.call("ensure_active_playable_order")
	var first_order := Dictionary(first_opened.get("order", {}))
	session.call("advance_formal_order_patience", 7.0)
	var saved_branch := Dictionary(session.get("_save_data")).duplicate(true)
	var first_id := StringName(first_order.get("order_id", &""))
	session.call("refuse_formal_order", first_id)
	var expected_next := Dictionary(Dictionary(session.call("ensure_active_playable_order")).get("order", {}))

	session.set("_save_data", saved_branch.duplicate(true))
	session.call("_restore_progression")
	var restored_first: Dictionary = session.call("active_formal_order")
	_check(
		StringName(restored_first.get("order_id", &"")) == first_id
		and is_equal_approx(float(restored_first.get("remaining_patience_seconds", 0.0)), 65.0),
		"reload restores the existing active order instead of generating it again"
	)
	session.call("refuse_formal_order", first_id)
	var actual_next := Dictionary(Dictionary(session.call("ensure_active_playable_order")).get("order", {}))
	var expected_signature := _order_signature(expected_next)
	var actual_signature := _order_signature(actual_next)
	_check(
		actual_signature == expected_signature,
		"the order after reload matches the same saved seed and sequence branch"
	)


func _order_signature(order: Dictionary) -> Dictionary:
	var item := Dictionary(Array(order.get("items", []))[0]) if not Array(order.get("items", [])).is_empty() else {}
	var metadata := Dictionary(order.get("metadata", {}))
	var legacy := Dictionary(metadata.get("legacy_order", {}))
	return {
		"area_id": StringName(item.get("area_id", &"")),
		"product_id": StringName(item.get("product_id", &"")),
		"temperature_mode": StringName(item.get("temperature_mode", &"")),
		"pancake_template_id": StringName(item.get("pancake_template_id", legacy.get("id", &""))),
		"generated_sequence": int(metadata.get("generated_sequence", -1)),
	}


func _unlock_three_areas(progression: RefCounted) -> void:
	progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.packaged_drink": true, &"area.youtiao": true})
	progression.set("device_tiers", {&"device.pancake_griddle": 1, &"device.packaged_drink_heater": 0, &"device.youtiao_fryer": 0})
	progression.set("unlocked_recipe_ids", {&"recipe.pancake.base": true, &"recipe.packaged_drink.milk": true, &"recipe.youtiao.plain": true})
	progression.set("unlocked_product_ids", {&"product.pancake.custom": true, &"product.packaged_drink.milk": true, &"product.youtiao.plain": true})
	progression.set("unlocked_stock_ids", {
		&"stock.pancake.batter": true, &"stock.pancake.egg": true, &"stock.pancake.baocui": true,
		&"stock.pancake.scallion": true, &"stock.pancake.sauce.sweet_flour": true,
		&"stock.packaged_drink.milk": true, &"stock.youtiao.plain_dough": true,
	})


func _set_active_tutorial(progression: RefCounted, area_id: StringName, completed: Array) -> void:
	var completed_set := {}
	for completed_id in completed:
		completed_set[StringName(completed_id)] = true
	progression.set("tutorial_completed_area_ids", completed_set)
	progression.set("tutorial_queue_area_ids", [area_id])
	progression.set("tutorial_active_kind", &"area")
	progression.set("tutorial_active_id", area_id)


func _area_id(order: Dictionary) -> StringName:
	var items: Array = Array(order.get("items", []))
	return &"" if items.is_empty() else StringName(Dictionary(items[0]).get("area_id", &""))


func _is_supported(area_id: StringName) -> bool:
	return area_id in [&"area.pancake", &"area.packaged_drink", &"area.youtiao"]


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("THREE_PLAYABLE_AREA_ORDER_LOOP_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
