extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")

class StubSession extends Node:
	var inventory := {
		"stock.packaged_drink.milk": 0,
		"stock.youtiao.plain_dough": 0,
		"stock.fresh_soy_milk.yellow_bean": 0,
		"stock.steamer.mantou": 0,
	}
	var machines := {
		&"device.youtiao_fryer": {"state": &"idle"},
		&"device.fresh_soy_milk_machine": {"state": &"idle"},
		&"device.steamer": {"layers": [{"state": &"empty"}]},
	}

	func inventory_snapshot() -> Dictionary:
		return inventory.duplicate(true)

	func f3_machine_snapshot(device_id: StringName) -> Dictionary:
		return Dictionary(machines.get(device_id, {})).duplicate(true)

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
	_check(guide.get("target") == workstation.youtiao_dough_slots[0] and str(guide.get("message", "")).contains("长按"), "zero-stock youtiao tutorial points to bottom restock")
	stub.inventory["stock.youtiao.plain_dough"] = 1
	guide = Dictionary(workstation.call("_tutorial_guide_for_area", stub, &"area.youtiao"))
	_check(guide.get("target") == workstation.youtiao_dough_slots[0] and str(guide.get("message", "")).contains("拖入"), "stocked youtiao tutorial keeps the target and switches to drag wording")
	stub.machines[&"device.youtiao_fryer"] = {"state": &"loaded"}
	_check(Dictionary(workstation.call("_tutorial_guide_for_area", stub, &"area.youtiao")).get("target") == workstation.youtiao_station.start_button, "loaded youtiao points to start")
	stub.machines[&"device.youtiao_fryer"] = {"state": &"frying"}
	_check(Dictionary(workstation.call("_tutorial_guide_for_area", stub, &"area.youtiao")).get("target") == workstation.youtiao_station.state_label, "frying wait points to the device state")
	stub.machines[&"device.youtiao_fryer"] = {"state": &"ready_to_collect"}
	_check(Dictionary(workstation.call("_tutorial_guide_for_area", stub, &"area.youtiao")).get("target") == workstation.order_dish_buttons[0], "ready youtiao points to order click delivery")

	stub.machines[&"device.fresh_soy_milk_machine"] = {"state": &"loaded"}
	_check(Dictionary(workstation.call("_tutorial_guide_for_area", stub, &"area.fresh_soy_milk")).get("target") == workstation.fresh_soy_station.water_button, "loaded soy points to add water")
	stub.machines[&"device.fresh_soy_milk_machine"] = {"state": &"water_added"}
	_check(Dictionary(workstation.call("_tutorial_guide_for_area", stub, &"area.fresh_soy_milk")).get("target") == workstation.fresh_soy_station.start_button, "water_added soy points to start")
	stub.machines[&"device.fresh_soy_milk_machine"] = {"state": &"grinding"}
	_check(Dictionary(workstation.call("_tutorial_guide_for_area", stub, &"area.fresh_soy_milk")).get("target") == workstation.fresh_soy_station.state_label, "grinding wait points to soy state")

	stub.machines[&"device.steamer"] = {"layers": [{"state": &"loaded"}]}
	_check(Dictionary(workstation.call("_tutorial_guide_for_area", stub, &"area.steamer")).get("target") == workstation.steamer_station.layer_starts[0], "loaded steamer points to the matching layer start")
	var overlay := workstation.tutorial_guide_overlay as Control
	overlay.call("show_guide", workstation.youtiao_station.start_button, "点击启动")
	await process_frame
	_check(overlay.visible and overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE and overlay.get_node("TargetHighlight").mouse_filter == Control.MOUSE_FILTER_IGNORE and overlay.get_node("GuideBubble").mouse_filter == Control.MOUSE_FILTER_IGNORE, "guide highlight, arrow shell, and callout never intercept input")

	stub.queue_free()
	workstation.queue_free()
	_finish()


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
