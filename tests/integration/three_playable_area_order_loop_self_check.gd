extends SceneTree

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession is available for the three-station order loop")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	var progression: RefCounted = session.call("progression_service")
	_unlock_three_areas(progression)
	var inventory: Dictionary = session.call("inventory_snapshot")
	inventory["stock.fresh_soy_milk.yellow_bean"] = 2
	inventory["stock.youtiao.plain_dough"] = 2
	session.call("save_inventory", inventory)

	_set_active_tutorial(progression, &"area.fresh_soy_milk", [&"area.pancake", &"area.youtiao"])
	var soy_opened: Dictionary = session.call("ensure_active_playable_order")
	var soy_order := Dictionary(soy_opened.get("order", {}))
	var soy_id := StringName(soy_order.get("order_id", &""))
	var soy_items := Array(soy_order.get("items", []))
	var soy_item := Dictionary(soy_items[0]) if not soy_items.is_empty() else {}
	_check(bool(soy_opened.get("success", false)) and _area_id(soy_order) == &"area.fresh_soy_milk" and StringName(soy_order.get("teaching_area_id", &"")) == &"area.fresh_soy_milk", "soy teaching opens the protected third-station customer")
	_check(soy_items.size() == 1 and StringName(soy_item.get("product_id", &"")) == &"product.fresh_soy_milk.yellow_bean" and bool(soy_order.get("tutorial_no_countdown", false)), "soy teaching requests one unlimited-time yellow-bean cup")
	_check(Array(session.call("active_formal_orders")).size() == 1 and Array(session.call("waiting_formal_orders")).size() == 3, "new-area teaching exclusively occupies the store while normal customers wait")
	_check(bool(Dictionary(session.call("load_f4_soy", &"recipe.fresh_soy_milk.yellow_bean", 1, soy_id)).get("success", false)), "soy teaching consumes one bean portion")
	_check(bool(Dictionary(session.call("perform_f4_soy_action", &"add_water")).get("success", false)), "soy keeps a direct add-water action")
	_check(bool(Dictionary(session.call("perform_f4_soy_action", &"start")).get("success", false)), "soy keeps a direct grind-start action")
	session.call("advance_f3_production", 5.1)
	_check(StringName(Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine")).get("state", &"")) == &"ready_safe", "base soy machine produces its cup automatically")
	_check(bool(Dictionary(session.call("deliver_f4_soy", soy_id, 0)).get("success", false)), "fresh soy stages from its real output to the teaching order")
	var soy_settlement: Dictionary = session.call("complete_order_delivery", soy_id)
	_check(bool(soy_settlement.get("order_success", false)) and int(soy_settlement.get("earned_coins", 0)) == 8, "A-grade soy teaching applies its 1.2 quality multiplier")
	_check(int(progression.call("mastery_value", &"area.fresh_soy_milk")) == 1 and Array(Dictionary(progression.call("tutorial_snapshot")).get("completed_area_ids", [])).has("area.fresh_soy_milk"), "soy settlement advances mastery and completes teaching")

	session.call("abandon_active_formal_order", &"business_day_expired")
	_set_active_tutorial(progression, &"area.youtiao", [&"area.pancake", &"area.fresh_soy_milk"])
	progression.set("current_day", int(progression.get("current_day")) + 1)
	var youtiao_opened: Dictionary = session.call("ensure_active_playable_order")
	var youtiao_order := Dictionary(youtiao_opened.get("order", {}))
	var youtiao_id := StringName(youtiao_order.get("order_id", &""))
	_check(_area_id(youtiao_order) == &"area.youtiao" and bool(youtiao_order.get("tutorial_no_countdown", false)), "youtiao teaching routes as the protected second-station order")
	_check(bool(Dictionary(session.call("load_f3_youtiao", &"recipe.youtiao.plain", 1, youtiao_id)).get("success", false)), "youtiao teaching consumes one dough portion")
	session.call("perform_f3_youtiao_action", &"start")
	session.call("advance_f3_production", 10.0)
	session.call("perform_f3_youtiao_action", &"lift")
	session.call("advance_f3_production", 2.0)
	var stored_youtiao := Dictionary(session.call("store_ready_youtiao_batch", &"slot.04"))
	_check(bool(stored_youtiao.get("success", false)) and bool(Dictionary(session.call("deliver_f3_youtiao", youtiao_id, 0)).get("success", false)), "finished youtiao is stored as a whole batch before one unit is staged to its teaching order")
	var youtiao_settlement: Dictionary = session.call("complete_order_delivery", youtiao_id)
	_check(bool(youtiao_settlement.get("order_success", false)) and int(youtiao_settlement.get("earned_coins", 0)) == 6, "youtiao teaching settles at its catalog revenue")
	_check(int(progression.call("mastery_value", &"area.youtiao")) == 1, "youtiao settlement advances qualified mastery")

	var next_order_result: Dictionary = session.call("ensure_active_playable_order")
	var next_order := Dictionary(next_order_result.get("order", {}))
	_check(bool(next_order_result.get("success", false)) and _is_supported(_area_id(next_order)) and Array(session.call("active_formal_orders")).size() == 3, "normal play restores a three-customer queue containing only supported stations")
	var reputation_before_refusal := int(progression.get("reputation"))
	var next_order_id := StringName(next_order.get("order_id", &""))
	var refused: Dictionary = session.call("refuse_formal_order", next_order_id)
	_check(StringName(refused.get("terminal_state", &"")) == &"refused" and int(progression.get("reputation")) == reputation_before_refusal - 1, "an unstarted normal order can still be refused exactly once")
	var bill: Dictionary = session.call("today_bill")
	_check(int(bill.get("order_count", 0)) == 3 and int(bill.get("total_coins", 0)) == 14, "quality-adjusted soy, youtiao, and refusal enter the daily bill without refusal revenue")
	_check_active_production_restore(session)
	_check_deterministic_reload(session)
	session.call("reset_incompatible_development_save")
	_finish()


func _check_active_production_restore(session: Node) -> void:
	session.call("abandon_active_formal_order", &"business_day_expired")
	var inventory: Dictionary = session.call("inventory_snapshot")
	inventory["stock.fresh_soy_milk.yellow_bean"] = 2
	inventory["stock.youtiao.plain_dough"] = 2
	session.call("save_inventory", inventory)
	var soy_opened: Dictionary = session.call("open_formal_order", [{"area_id": &"area.fresh_soy_milk", "product_id": &"product.fresh_soy_milk.yellow_bean", "quantity": 1, "temperature_mode": &"room_temperature"}], {"patience_seconds": 24.0})
	var soy_id := StringName(Dictionary(soy_opened.get("order", {})).get("order_id", &""))
	session.call("load_f4_soy", &"recipe.fresh_soy_milk.yellow_bean", 1, soy_id)
	session.call("perform_f4_soy_action", &"add_water")
	session.call("perform_f4_soy_action", &"start")
	session.call("advance_f3_production", 0.75)
	session.call("advance_formal_order_patience", 5.5)
	session.call("_restore_progression")
	var restored_soy_order: Dictionary = session.call("active_formal_order")
	var restored_soy: Dictionary = session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine")
	_check(StringName(restored_soy_order.get("order_id", &"")) == soy_id and is_equal_approx(float(restored_soy_order.get("remaining_patience_seconds", 0.0)), 18.5) and StringName(restored_soy.get("state", &"")) == &"grinding" and is_equal_approx(float(restored_soy.get("elapsed_seconds", 0.0)), 0.75), "active soy order, patience, and grinder state survive restoration")
	session.call("abandon_active_formal_order", &"restore_check_complete")
	session.call("discard_f4_soy")

	var youtiao_opened: Dictionary = session.call("open_formal_order", [{"area_id": &"area.youtiao", "product_id": &"product.youtiao.plain", "quantity": 1, "temperature_mode": &"room_temperature"}], {"patience_seconds": 36.0})
	var youtiao_id := StringName(Dictionary(youtiao_opened.get("order", {})).get("order_id", &""))
	session.call("load_f3_youtiao", &"recipe.youtiao.plain", 1, youtiao_id)
	session.call("perform_f3_youtiao_action", &"start")
	session.call("advance_f3_production", 1.25)
	session.call("advance_formal_order_patience", 4.0)
	session.call("_restore_progression")
	var restored_youtiao_order: Dictionary = session.call("active_formal_order")
	var restored_fryer: Dictionary = session.call("f3_machine_snapshot", &"device.youtiao_fryer")
	_check(StringName(restored_youtiao_order.get("order_id", &"")) == youtiao_id and is_equal_approx(float(restored_youtiao_order.get("remaining_patience_seconds", 0.0)), 32.0) and StringName(restored_fryer.get("state", &"")) == &"frying" and is_equal_approx(float(restored_fryer.get("cooking_elapsed_seconds", 0.0)), 1.25), "active youtiao order, patience, and fryer state survive restoration")


func _check_deterministic_reload(session: Node) -> void:
	session.call("begin_new_game")
	var progression: RefCounted = session.call("progression_service")
	progression.set("tutorial_completed_area_ids", {&"area.pancake": true})
	progression.set("tutorial_queue_area_ids", [])
	progression.set("tutorial_active_kind", &"")
	progression.set("tutorial_active_id", &"")
	session.call("_sync_progression_to_save")
	var first_order := Dictionary(Dictionary(session.call("ensure_active_playable_order")).get("order", {}))
	session.call("advance_formal_order_patience", 7.0)
	var expected_remaining := float(Dictionary(session.call("active_formal_order")).get("remaining_patience_seconds", 0.0))
	var saved_branch := Dictionary(session.get("_save_data")).duplicate(true)
	var first_id := StringName(first_order.get("order_id", &""))
	session.call("refuse_formal_order", first_id)
	var expected_next := Dictionary(Dictionary(session.call("ensure_active_playable_order")).get("order", {}))
	session.set("_save_data", saved_branch.duplicate(true))
	session.call("_restore_progression")
	var restored_first: Dictionary = session.call("active_formal_order")
	_check(StringName(restored_first.get("order_id", &"")) == first_id and is_equal_approx(float(restored_first.get("remaining_patience_seconds", 0.0)), expected_remaining), "reload restores the existing active order and its exact patience instead of regenerating it")
	session.call("refuse_formal_order", first_id)
	var actual_next := Dictionary(Dictionary(session.call("ensure_active_playable_order")).get("order", {}))
	_check(_order_signature(actual_next) == _order_signature(expected_next), "the order after reload follows the same saved seed and sequence branch")


func _order_signature(order: Dictionary) -> Dictionary:
	var item := Dictionary(Array(order.get("items", []))[0]) if not Array(order.get("items", [])).is_empty() else {}
	var metadata := Dictionary(order.get("metadata", {}))
	var legacy := Dictionary(metadata.get("legacy_order", {}))
	return {"area_id": StringName(item.get("area_id", &"")), "product_id": StringName(item.get("product_id", &"")), "temperature_mode": StringName(item.get("temperature_mode", &"")), "pancake_template_id": StringName(item.get("pancake_template_id", legacy.get("id", &""))), "generated_sequence": int(metadata.get("generated_sequence", -1))}


func _unlock_three_areas(progression: RefCounted) -> void:
	progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.youtiao": true, &"area.fresh_soy_milk": true})
	progression.set("device_tiers", {&"device.pancake_griddle": 2, &"device.youtiao_fryer": 0, &"device.fresh_soy_milk_machine": 0})
	progression.set("unlocked_recipe_ids", {&"recipe.pancake.base": true, &"recipe.youtiao.plain": true, &"recipe.fresh_soy_milk.yellow_bean": true})
	progression.set("unlocked_product_ids", {&"product.pancake.custom": true, &"product.youtiao.plain": true, &"product.fresh_soy_milk.yellow_bean": true})
	progression.set("unlocked_stock_ids", {&"stock.pancake.batter": true, &"stock.pancake.egg": true, &"stock.pancake.baocui": true, &"stock.pancake.scallion": true, &"stock.pancake.sauce.sweet_flour": true, &"stock.youtiao.plain_dough": true, &"stock.fresh_soy_milk.yellow_bean": true})
	progression.set("owned_growth_ids", {&"growth.capacity.youtiao_finished_tray": true})


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
	return area_id in [&"area.pancake", &"area.youtiao", &"area.fresh_soy_milk"]


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
