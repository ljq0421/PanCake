extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")

class StubSession extends Node:
	var inventory := {
		"stock.packaged_drink.milk": 0,
		"stock.youtiao.plain_dough": 0,
		"stock.fresh_soy_milk.yellow_bean": 0,
	}
	var machines := {
		&"device.youtiao_fryer": {"state": &"idle"},
		&"device.fresh_soy_milk_machine": {"state": &"idle"},
	}
	var prepared_counts := {}
	var active_order := {}

	func inventory_snapshot() -> Dictionary:
		return inventory.duplicate(true)

	func f3_machine_snapshot(device_id: StringName) -> Dictionary:
		return Dictionary(machines.get(device_id, {})).duplicate(true)

	func prepared_product_slot_status(slot_id: StringName) -> Dictionary:
		return {"success": true, "count": int(prepared_counts.get(slot_id, 0))}

	func active_formal_order() -> Dictionary:
		return active_order.duplicate(true)

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	await process_frame
	var stub := StubSession.new()
	root.add_child(stub)

	var guide := Dictionary(workstation.call("_tutorial_guide_for_area", stub, &"area.youtiao"))
	_check(guide.get("target") == workstation.cartoon_youtiao_fryer.start_button and str(guide.get("message", "")).contains("长按油条机"), "zero-stock youtiao tutorial points to direct fryer loading")
	stub.inventory["stock.youtiao.plain_dough"] = 1
	guide = Dictionary(workstation.call("_tutorial_guide_for_area", stub, &"area.youtiao"))
	_check(guide.get("target") == workstation.cartoon_youtiao_fryer.start_button and str(guide.get("message", "")).contains("长按油条机"), "stocked youtiao tutorial keeps direct fryer loading guidance")
	stub.machines[&"device.youtiao_fryer"] = {"state": &"loaded"}
	_check(Dictionary(workstation.call("_tutorial_guide_for_area", stub, &"area.youtiao")).get("target") == workstation.cartoon_youtiao_fryer.start_button, "loaded youtiao points to start")
	stub.machines[&"device.youtiao_fryer"] = {"state": &"frying"}
	_check(Dictionary(workstation.call("_tutorial_guide_for_area", stub, &"area.youtiao")).get("target") == workstation.cartoon_youtiao_fryer.state_label, "frying wait points to the device state")
	stub.machines[&"device.youtiao_fryer"] = {"state": &"ready_to_collect"}
	_check(Dictionary(workstation.call("_tutorial_guide_for_area", stub, &"area.youtiao")).get("target") == workstation.cartoon_youtiao_fryer.output_sources[0], "ready youtiao points to the first independently draggable fryer slot")
	stub.machines[&"device.youtiao_fryer"] = {"state": &"burnt"}
	_check(Dictionary(workstation.call("_tutorial_guide_for_area", stub, &"area.youtiao")).get("target") == workstation.cartoon_youtiao_fryer.waste_source, "burnt youtiao points to the dedicated whole-batch waste source")

	var youtiao_target := _bind_centered_tutorial_order(workstation, stub, &"area.youtiao", &"product.youtiao.plain")
	stub.prepared_counts[&"slot.04"] = 1
	guide = Dictionary(workstation.call("_tutorial_guide_for_area", stub, &"area.youtiao"))
	_check(guide.get("target") == youtiao_target, "stored youtiao points to the real centered customer-card delivery target")
	workstation.customer_service_slots[2].call("bind_order", {}, null, [], [], 0)
	_check(Dictionary(workstation.call("_tutorial_guide_for_area", stub, &"area.youtiao")).get("target") == null, "tutorial delivery safely waits while the customer card is not bound")

	stub.machines[&"device.fresh_soy_milk_machine"] = {"state": &"ready"}
	stub.prepared_counts.clear()
	_check(Dictionary(workstation.call("_tutorial_guide_for_area", stub, &"area.fresh_soy_milk")).get("target") == workstation.fresh_soy_station.cup_stack, "ready soy points to the physical cup stack")
	stub.machines[&"device.fresh_soy_milk_machine"] = {"state": &"held_empty"}
	_check(Dictionary(workstation.call("_tutorial_guide_for_area", stub, &"area.fresh_soy_milk")).get("target") == workstation.fresh_soy_station.nozzle_button, "placed soy cup points to the real dispenser nozzle")
	stub.machines[&"device.fresh_soy_milk_machine"] = {"state": &"filled"}
	_check(Dictionary(workstation.call("_tutorial_guide_for_area", stub, &"area.fresh_soy_milk")).get("target") == workstation.fresh_soy_station.sugar_jar, "filled soy points to the sugar-selection control")
	var soy_target := _bind_centered_tutorial_order(workstation, stub, &"area.fresh_soy_milk", &"product.fresh_soy_milk.yellow_bean")
	_check(workstation.call("_tutorial_delivery_target", stub, &"area.fresh_soy_milk") == soy_target, "finished soy resolves to the real centered customer-card delivery target")
	var pancake_target := _bind_centered_tutorial_order(workstation, stub, &"area.pancake", &"product.pancake.custom")
	_check(workstation.call("_tutorial_delivery_target", stub, &"area.pancake") == pancake_target, "ready pancake resolves through the same real customer-card target")
	var griddle := workstation.multi_griddle_station.units[0] as CompactGriddleUnit
	var pancake_guide := Dictionary(workstation.call("_tutorial_guide_for_area", stub, &"area.pancake"))
	_check(pancake_guide.get("target") != griddle and str(pancake_guide.get("message", "")).contains("第1步"), "idle pancake tutorial points to the batter-ladle step instead of the whole station")
	griddle.begin_order({})
	griddle.use_press_spreader()
	_check(bool(Dictionary(griddle.pancake_model.crack_egg(Vector2(31, 31))).get("success", false)), "tutorial fixture adds the required egg before checking flip guidance")
	pancake_guide = Dictionary(workstation.call("_tutorial_guide_for_area", stub, &"area.pancake"))
	_check(pancake_guide.get("target") == griddle.heat_status_label and str(pancake_guide.get("message", "")).contains("火候计时"), "first side before readiness points to the visible heat timer")
	griddle.pancake_model.advance_cooking(4.0, 1.25)
	griddle.first_side_seconds = 4.0
	griddle.call("_refresh_heat_visual")
	pancake_guide = Dictionary(workstation.call("_tutorial_guide_for_area", stub, &"area.pancake"))
	_check(pancake_guide.get("target") == griddle.main_action and str(pancake_guide.get("message", "")).contains("现在可翻面"), "recommended first-side heat points the tutorial arrow at flip")
	griddle.pancake_model.advance_cooking(10.0, 1.25)
	griddle.first_side_seconds = 14.0
	griddle.call("_refresh_heat_visual")
	pancake_guide = Dictionary(workstation.call("_tutorial_guide_for_area", stub, &"area.pancake"))
	_check(bool(Dictionary(griddle.cooking_heat_status()).get("charred", false)) and str(pancake_guide.get("message", "")).contains("焦糊"), "overcooked first side visibly warns of charring and reduced heat score")
	var overlay := workstation.tutorial_guide_overlay as Control
	workstation.set_process(false)
	var guide_target := griddle.main_action as Control
	overlay.call("show_guide", guide_target, "点击打包")
	await process_frame
	var guide_arrow := overlay.get_node("GuideArrow") as Control
	var target_highlight := overlay.get_node("TargetHighlight") as Control
	var guide_bubble := overlay.get_node("GuideBubble") as Control
	var guide_label := overlay.get_node("GuideBubble/GuideLabel") as Control
	_check(
		overlay.visible
		and target_highlight.visible
		and guide_arrow.visible
		and guide_bubble.visible
		and target_highlight.size.x > guide_target.size.x
		and target_highlight.size.y > guide_target.size.y
		and guide_arrow.size.x > 0.0
		and guide_bubble.size.x > 0.0,
		"guide keeps the highlight, arrow, and text callout positioned for the active target",
	)
	_check(
		overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and target_highlight.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and guide_arrow.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and guide_bubble.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and guide_label.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"guide highlight, arrow, and callout never intercept input",
	)

	stub.queue_free()
	workstation.queue_free()
	_finish()


func _bind_centered_tutorial_order(workstation: Node, stub: StubSession, area_id: StringName, product_id: StringName) -> Control:
	stub.active_order = {
		"order_id": &"order.tutorial",
		"state": &"active",
		"tutorial_no_countdown": true,
		"items": [{
			"area_id": area_id,
			"product_id": product_id,
			"quantity": 1,
			"prepared_product_instance_ids": [],
		}],
	}
	var centered_slot: Control = workstation.customer_service_slots[2]
	centered_slot.call("bind_order", stub.active_order, null, [null], [], 0)
	return centered_slot.item_buttons[0] as Control


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("FIVE_AREA_TUTORIAL_GUIDE_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("FIVE_AREA_TUTORIAL_GUIDE_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
