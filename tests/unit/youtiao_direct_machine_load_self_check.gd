extends SceneTree

const FRYER_SCENE := preload("res://scenes/gameplay/cartoon_youtiao_fryer_toggle.tscn")


class FakeGameSession extends Node:
	signal prepared_product_slots_changed(snapshot: Dictionary)

	var load_calls := 0
	var machine := {
		"state": &"idle", "capacity": 4, "quantity": 0, "tier": 0,
		"occupied_slot_indices": [],
	}

	func f3_machine_snapshot(_device_id: StringName) -> Dictionary:
		return machine.duplicate(true)

	func five_area_progression_snapshot() -> Dictionary:
		return {"unlocked_area_ids": [&"area.youtiao"], "unlocked_product_ids": [&"product.youtiao.plain"], "owned_growth_ids": []}

	func inventory_snapshot() -> Dictionary:
		return {"stock.youtiao.plain_dough": 0}

	func prepared_product_slot_status(_slot_id: StringName) -> Dictionary:
		return {"count": 0, "capacity": 0, "entries": [], "products": []}

	func load_f3_youtiao(_recipe_id: StringName, quantity: int) -> Dictionary:
		load_calls += 1
		machine["quantity"] = quantity
		machine["state"] = &"loaded"
		machine["occupied_slot_indices"] = range(quantity)
		return {"success": true}

	func perform_f3_youtiao_action(action_id: StringName) -> Dictionary:
		if action_id == &"start" and StringName(machine.get("state", &"")) == &"loaded":
			machine["state"] = &"frying"
			return {"success": true}
		return {"success": false, "reason": &"invalid_equipment_state"}

	func five_area_restock_status(_stock_id: StringName) -> Dictionary:
		return {"success": true, "current_stock": 0, "capacity": 4, "coins": 0, "unit_cost": 0}

	func cancel_five_area_restock_hold(_stock_id: StringName) -> Dictionary:
		return {"success": true}


var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_session := root.get_node_or_null("GameSession")
	if original_session != null:
		original_session.name = "OriginalGameSession"
	var session := FakeGameSession.new()
	session.name = "GameSession"
	root.add_child(session)
	var fryer := FRYER_SCENE.instantiate() as CartoonYoutiaoFryerToggle
	fryer.direct_single_delivery_only = true
	root.add_child(fryer)
	await process_frame

	fryer.call("_perform_machine_click")
	_check(session.load_calls == 0 and int(session.machine.get("quantity", -1)) == 0, "short click cannot load an empty base fryer")
	fryer.call("_begin_machine_gesture")
	fryer.call("_advance_machine_hold", 0.45)
	_check(session.load_calls == 1 and int(session.machine.get("quantity", 0)) == 4, "one long press fills all four dough positions")
	fryer.call("_perform_machine_click")
	_check(StringName(session.machine.get("state", &"")) == &"frying", "clicking the loaded fryer starts cooking")

	session.machine["state"] = &"ready_to_collect"
	session.machine["quantity"] = 4
	session.machine["occupied_slot_indices"] = [0, 1, 2, 3]
	fryer.refresh_from_session()
	var messages: Array[String] = []
	fryer.status_message.connect(func(message: String) -> void: messages.append(message))
	fryer.call("_on_fryer_output_short_clicked", {"source_index": 0, "product_id": &"product.youtiao.plain"})
	_check(int(session.machine.get("quantity", 0)) == 4 and not messages.is_empty() and messages.back().contains("拖动一根"), "finished sticks are taken one at a time by dragging, never batch-collected")

	fryer.baked_into_workbench_artwork = true
	fryer.call("_clear_machine_hover_preview")
	_check(is_zero_approx(fryer.fryer_visual.self_modulate.a), "baked fryer art stays transparent during hover feedback")
	fryer.queue_free()
	session.queue_free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("YOUTIAO_DIRECT_MACHINE_LOAD_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("YOUTIAO_DIRECT_MACHINE_LOAD_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
