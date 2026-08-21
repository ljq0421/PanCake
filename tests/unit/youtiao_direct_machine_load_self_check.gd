extends SceneTree

const FRYER_SCENE := preload("res://scenes/gameplay/cartoon_youtiao_fryer_toggle.tscn")


class FakeGameSession extends Node:
	var inventory := {"stock.youtiao.plain_dough": 2}
	var coins := 10
	var finished_tray_unlocked := true
	var machine := {
		"state": &"idle",
		"capacity": 4,
		"quantity": 0,
		"tier": 0,
		"occupied_slot_indices": [],
	}

	func f3_machine_snapshot(_device_id: StringName) -> Dictionary:
		return machine.duplicate(true)

	func five_area_progression_snapshot() -> Dictionary:
		return {
			"unlocked_area_ids": [&"area.youtiao"],
			"unlocked_product_ids": [],
			"owned_growth_ids": [&"growth.capacity.youtiao_finished_tray"] if finished_tray_unlocked else [],
		}

	func inventory_snapshot() -> Dictionary:
		return inventory.duplicate(true)

	func prepared_product_slot_status(_slot_id: StringName) -> Dictionary:
		return {"count": 0, "capacity": 4, "products": []}

	func load_f3_youtiao(_recipe_id: StringName, quantity: int) -> Dictionary:
		if int(inventory.get("stock.youtiao.plain_dough", 0)) < quantity:
			return {"success": false, "reason": &"insufficient_stock"}
		inventory["stock.youtiao.plain_dough"] = int(inventory.get("stock.youtiao.plain_dough", 0)) - quantity
		machine["quantity"] = int(machine.get("quantity", 0)) + quantity
		machine["state"] = &"loaded"
		machine["occupied_slot_indices"] = range(int(machine.get("quantity", 0)))
		return {"success": true, "reason": &""}

	func five_area_restock_status(_stock_id: StringName) -> Dictionary:
		return {
			"success": true,
			"reason": &"",
			"current_stock": int(inventory.get("stock.youtiao.plain_dough", 0)),
			"capacity": 4,
			"coins": coins,
			"unit_cost": 2,
		}

	func advance_five_area_restock_hold(_stock_id: StringName, delta: float) -> Dictionary:
		if delta < 0.25 or coins < 2:
			return {"success": false, "reason": &"insufficient_coins", "completed_units": 0, "auto_stopped": true}
		inventory["stock.youtiao.plain_dough"] = int(inventory.get("stock.youtiao.plain_dough", 0)) + 1
		coins -= 2
		return {"success": true, "reason": &"", "completed_units": 1, "auto_stopped": false}


var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var existing_session := root.get_node_or_null("GameSession")
	if existing_session != null:
		existing_session.name = "OriginalGameSession"
	var session := FakeGameSession.new()
	session.name = "GameSession"
	root.add_child(session)
	var fryer := FRYER_SCENE.instantiate()
	root.add_child(fryer)

	fryer.call("_begin_machine_gesture")
	fryer.call("_advance_machine_hold", 0.20)
	fryer.call("_advance_machine_hold", 0.25)
	_check(int(session.machine.get("quantity", 0)) == 1, "holding the fryer directly loads an existing dough blank")
	_check(int(session.inventory.get("stock.youtiao.plain_dough", 0)) == 1, "direct loading consumes the existing dough blank")

	session.inventory["stock.youtiao.plain_dough"] = 0
	fryer.call("refresh_from_session")
	fryer.call("_begin_machine_gesture")
	fryer.call("_advance_machine_hold", 0.20)
	fryer.call("_advance_machine_hold", 0.25)
	_check(int(session.machine.get("quantity", 0)) == 2, "holding the fryer restocks and loads a dough blank when stock is empty")
	_check(int(session.inventory.get("stock.youtiao.plain_dough", 0)) == 0 and session.coins == 8, "automatic restock charges once and leaves no board inventory behind")

	session.machine["state"] = &"ready_to_collect"
	session.machine["quantity"] = 1
	session.machine["occupied_slot_indices"] = [0]
	session.finished_tray_unlocked = false
	fryer.call("refresh_from_session")
	var finished_stick := {"kind": &"product_source", "source_ref": {"source_kind": &"youtiao_fryer_slot", "source_index": 0}}
	_check(not bool(fryer.call("_can_drop_data", Vector2(260.0, 420.0), finished_stick)) and not fryer.plate_visual.visible, "a fried youtiao remains on the filter basket while the serving tray is locked")
	session.finished_tray_unlocked = true
	fryer.call("refresh_from_session")
	_check(bool(fryer.call("_can_drop_data", Vector2(260.0, 420.0), finished_stick)), "the visible upper-left portion of the serving plate accepts a finished youtiao")

	fryer.queue_free()
	session.queue_free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("YOUTIAO_DIRECT_MACHINE_LOAD_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("YOUTIAO_DIRECT_MACHINE_LOAD_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
