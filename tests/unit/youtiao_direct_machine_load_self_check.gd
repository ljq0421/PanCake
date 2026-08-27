extends SceneTree

const FRYER_SCENE := preload("res://scenes/gameplay/cartoon_youtiao_fryer_toggle.tscn")


class FakeGameSession extends Node:
	signal prepared_product_slots_changed(snapshot: Dictionary)

	var inventory := {"stock.youtiao.plain_dough": 2}
	var coins := 10
	var finished_tray_unlocked := true
	var machine_snapshot_calls := 0
	var prepared_products: Array[Dictionary] = []
	var machine := {
		"state": &"idle",
		"capacity": 4,
		"quantity": 0,
		"tier": 0,
		"occupied_slot_indices": [],
	}

	func f3_machine_snapshot(_device_id: StringName) -> Dictionary:
		machine_snapshot_calls += 1
		return machine.duplicate(true)

	func five_area_progression_snapshot() -> Dictionary:
		return {
			"unlocked_area_ids": [&"area.youtiao"],
			"unlocked_product_ids": [&"product.youtiao.plain"],
			"owned_growth_ids": [&"growth.capacity.youtiao_finished_tray"] if finished_tray_unlocked else [],
		}

	func inventory_snapshot() -> Dictionary:
		return inventory.duplicate(true)

	func prepared_product_slot_status(_slot_id: StringName) -> Dictionary:
		return {"count": prepared_products.size(), "capacity": 8, "capacity_per_product": 4, "products": prepared_products.duplicate(true)}

	func load_f3_youtiao(_recipe_id: StringName, quantity: int) -> Dictionary:
		if int(inventory.get("stock.youtiao.plain_dough", 0)) < quantity:
			return {"success": false, "reason": &"insufficient_stock"}
		inventory["stock.youtiao.plain_dough"] = int(inventory.get("stock.youtiao.plain_dough", 0)) - quantity
		machine["quantity"] = int(machine.get("quantity", 0)) + quantity
		machine["state"] = &"loaded"
		machine["occupied_slot_indices"] = range(int(machine.get("quantity", 0)))
		return {"success": true, "reason": &""}

	func store_ready_youtiao_slot(_slot_id: StringName, source_index: int) -> Dictionary:
		var occupied := Array(machine.get("occupied_slot_indices", []))
		if StringName(machine.get("state", &"")) != &"ready_to_collect" or not occupied.has(source_index):
			return {"success": false, "reason": &"invalid_equipment_state"}
		var product_id := &"product.youtiao.plain"
		prepared_products.append({"product_id": product_id})
		occupied.erase(source_index)
		machine["occupied_slot_indices"] = occupied
		machine["quantity"] = occupied.size()
		prepared_product_slots_changed.emit({})
		return {"success": true, "reason": &"", "product_id": product_id}

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
	_check(not bool(fryer.call("_can_drop_data", Vector2(260.0, 420.0), finished_stick)) and not fryer.plain_tray.visible, "a fried youtiao remains on the filter basket while the serving tray is locked")
	session.finished_tray_unlocked = true
	fryer.call("refresh_from_session")
	var plain_tray_drop_point: Vector2 = fryer.plain_tray.position + fryer.plain_tray.size * fryer.plain_tray.scale * 0.5
	_check(bool(fryer.call("_can_drop_data", plain_tray_drop_point, finished_stick)), "the visible upper-left portion of the serving plate accepts a finished youtiao")
	_check(not fryer.call("_requires_timed_session_refresh"), "a ready fryer stops rebuilding drag sources before a serving-tray drag")
	var ready_snapshot_calls := session.machine_snapshot_calls
	for _tick in 8:
		fryer.call("_process", 0.11)
	_check(session.machine_snapshot_calls == ready_snapshot_calls, "a ready fryer performs no periodic session snapshots while its output is draggable")

	# Prepared products may be consumed by the pancake station rather than by the
	# fryer itself. Keep that presentation event-driven without touching a live
	# native drag control until Godot has completed the drag.
	session.prepared_products = [{"product_id": &"product.youtiao.plain"}]
	session.prepared_product_slots_changed.emit({})
	_check(fryer.plate_sources[0].visible, "an external prepared-slot update refreshes the finished plate without polling")
	var plate_source := fryer.plate_sources[0] as ProductDragSource
	plate_source.set("_native_drag_in_progress", true)
	ready_snapshot_calls = session.machine_snapshot_calls
	session.prepared_products.clear()
	session.prepared_product_slots_changed.emit({})
	_check(session.machine_snapshot_calls == ready_snapshot_calls and plate_source.visible, "an external slot update does not reconfigure a live drag source")
	plate_source.set("_native_drag_in_progress", false)
	plate_source.drag_ended.emit(plate_source.source_ref(), true)
	await process_frame
	_check(session.machine_snapshot_calls == ready_snapshot_calls + 1 and not plate_source.visible, "the deferred slot refresh runs immediately after native drag completion")
	fryer._machine["state"] = &"draining"
	_check(bool(fryer.call("_requires_timed_session_refresh")), "a draining fryer continues to refresh until its output becomes draggable")

	# Each tier/state combination owns one explicit assembly layout. Moving that
	# profile moves all four visible-and-draggable products together.
	session.machine["state"] = &"loaded"
	session.machine["quantity"] = 1
	session.machine["occupied_slot_indices"] = [0]
	session.machine["tier"] = 0
	fryer.call("refresh_from_session")
	var basic_raised_position: Vector2 = fryer.basket_products.position
	session.machine["tier"] = 1
	fryer.call("refresh_from_session")
	_check(fryer.fryer_layout_player.current_animation == &"advanced_raised" and fryer.basket_products.position == Vector2(55.0, 152.0) and fryer.basket_products.position != basic_raised_position, "advanced raised fryer selects its authored scene layout")
	session.machine["state"] = &"frying"
	fryer.call("refresh_from_session")
	_check(fryer.fryer_layout_player.current_animation == &"advanced_lowered" and fryer.basket_products.position == Vector2(55.0, 205.0) and fryer.fryer_slot_sources.all(func(source: ProductDragSource) -> bool: return source.get_parent() == fryer.basket_products), "advanced lowered fryer selects the authored four-slot basket layout")
	session.machine["state"] = &"ready_safe"
	session.machine["tier"] = 0
	fryer.call("refresh_from_session")
	_check(fryer.fryer_visual.texture == fryer.lowered_machine_texture and fryer.fryer_layout_player.current_animation == &"basic_lowered" and fryer.basket_products.position == Vector2(55.0, 190.0), "basic fryer stays in its authored lowered layout while waiting for the player to lift its finished batch")
	session.machine["state"] = &"draining"
	fryer.call("refresh_from_session")
	_check(fryer.fryer_visual.texture == fryer.raised_machine_texture and fryer.fryer_layout_player.current_animation == &"basic_raised" and fryer.basket_products.position == Vector2(55.0, 136.0) and fryer.fryer_visual.scale == Vector2.ONE, "basic fryer selects its authored raised layout only after lifting")
	var authored_left_slot_rect: Rect2 = fryer.fryer_slot_sources[0].get_rect()
	var authored_right_slot_rect: Rect2 = fryer.chicken_slot_sources[0].get_rect()
	fryer.call("_apply_fryer_layout", true, false, true, false)
	_check(fryer.fryer_layout_player.current_animation == &"dual_both_raised" and fryer.basket_products.position == Vector2(5.0, 126.0) and fryer.chicken_basket_products.position == Vector2(128.0, 126.0), "dual fryer selects the scene-authored both-raised layout")
	fryer.call("_apply_fryer_layout", true, true, true, false)
	_check(fryer.fryer_layout_player.current_animation == &"dual_left_lowered" and fryer.basket_products.position == Vector2(3.0, 168.0) and fryer.chicken_basket_products.position == Vector2(127.0, 126.0), "dual fryer lowers only the left authored basket group")
	fryer.call("_apply_fryer_layout", true, false, true, true)
	_check(fryer.fryer_layout_player.current_animation == &"dual_right_lowered" and fryer.basket_products.position == Vector2(-1.0, 126.0) and fryer.chicken_basket_products.position == Vector2(133.0, 168.0), "dual fryer lowers only the right authored basket group")
	fryer.call("_apply_fryer_layout", true, true, true, true)
	_check(fryer.fryer_layout_player.current_animation == &"dual_both_lowered" and fryer.basket_products.position == Vector2(3.0, 168.0) and fryer.chicken_basket_products.position == Vector2(133.0, 168.0), "dual fryer selects the scene-authored both-lowered layout")
	_check(fryer.fryer_slot_sources[0].get_rect() == authored_left_slot_rect and fryer.chicken_slot_sources[0].get_rect() == authored_right_slot_rect, "layout state changes preserve per-item size and position authored in the scene")
	session.machine["state"] = &"ready_to_collect"
	session.machine["quantity"] = 1
	session.machine["occupied_slot_indices"] = [0]
	session.prepared_products.clear()
	fryer.call("refresh_from_session")
	fryer.plain_tray.call("_drop_data", Vector2.ZERO, {"kind": &"product_source", "source_ref": {"source_kind": &"youtiao_fryer_slot", "source_index": 0}})
	_check(session.prepared_products.size() == 1 and StringName(session.prepared_products[0].get("product_id", &"")) == &"product.youtiao.plain", "the reusable plain tray routes a fryer-slot drop through the existing storage transaction")
	_check(fryer.get_node_or_null("SesameTray") == null, "the retired sesame serving tray is absent")
	fryer.editor_preview_tier = 1
	fryer.editor_preview_state = 3
	fryer.editor_preview_trays = true
	fryer.call("_apply_editor_preview")
	_check(fryer.fryer_visual.texture == fryer.advanced_lowered_machine_texture and fryer.fryer_layout_player.current_animation == &"advanced_lowered" and fryer.basket_products.position == Vector2(55.0, 205.0) and fryer.fryer_slot_sources.all(func(source: ProductDragSource) -> bool: return source.visible), "the editor preview exposes the authored advanced lowered alignment without running production")
	_check(fryer.plain_tray.visible and fryer.plain_tray.product_sources.all(func(source: ProductDragSource) -> bool: return source.visible), "the editor preview displays the reusable plain serving tray and all authored slots")

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
