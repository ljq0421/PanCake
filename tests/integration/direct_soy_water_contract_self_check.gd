extends SceneTree

const STATION_SCENE := preload("res://scenes/gameplay/direct_soy_station.tscn")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession is available")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	var progression: RefCounted = session.call("progression_service")
	progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.fresh_soy_milk": true})
	progression.set("device_tiers", {&"device.pancake_griddle": 0, &"device.fresh_soy_milk_machine": 0})
	progression.set("unlocked_recipe_ids", {&"recipe.fresh_soy_milk.yellow_bean": true})
	progression.set("unlocked_product_ids", {&"product.fresh_soy_milk.yellow_bean": true})
	progression.set("unlocked_stock_ids", {&"stock.fresh_soy_milk.yellow_bean": true})
	var inventory := Dictionary(session.call("inventory_snapshot"))
	inventory["stock.fresh_soy_milk.yellow_bean"] = 1
	session.call("save_inventory", inventory)

	var station := STATION_SCENE.instantiate()
	root.add_child(station)
	await process_frame
	_check(station.get_node_or_null("Ingredient01") == null and station.get_node_or_null("Restock01") == null, "direct soy scene owns no duplicate tabletop ingredient or restock controls")
	_check(station.get_node_or_null("VisualRig/OpenLidVisual") != null and station.get_node_or_null("VisualRig/IngredientVisual") != null and station.get_node_or_null("VisualRig/WaterEffect") != null and station.get_node_or_null("VisualRig/StreamEffect") != null and station.get_node_or_null("VisualRig/MachineCupVisual") != null and station.get_node_or_null("VisualRig/SteamEffect") != null and station.get_node_or_null("VisualRig/SpoiledVapor") != null, "direct soy scene pre-creates all operation and spoil effect layers")
	_check(station.get_node_or_null("HopperSummary") != null and station.get_node_or_null("ClearHopperButton") != null and station.get_node_or_null("WaterMeter") != null and station.get_node_or_null("ProductionProgress") != null and station.get_node_or_null("AutomationStatus") != null, "direct soy scene pre-creates v5 operation-state controls")
	var loaded := Dictionary(session.call("add_f4_soy_ingredient", &"stock.fresh_soy_milk.yellow_bean"))
	station.refresh_from_session()
	_check(bool(loaded.get("success", false)) and not station.water_button.disabled and station.start_button.disabled, "loaded soy enables water but cannot start early")
	var water_started := Dictionary(session.call("perform_f4_soy_action", &"start_water"))
	session.call("advance_f3_production", 1.0)
	var watered := Dictionary(session.call("perform_f4_soy_action", &"stop_water"))
	station.refresh_from_session()
	var snapshot := Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine"))
	_check(bool(water_started.get("success", false)) and bool(watered.get("success", false)) and is_equal_approx(float(snapshot.get("water_value", 0.0)), 50.0) and StringName(snapshot.get("water_grade", &"")) == &"A" and StringName(snapshot.get("state", &"")) == &"water_added" and station.water_button.disabled and not station.start_button.disabled, "two-click water control stops in the green A-grade band")
	var started := Dictionary(session.call("perform_f4_soy_action", &"start"))
	station.refresh_from_session()
	_check(bool(started.get("success", false)) and StringName(Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine")).get("state", &"")) == &"grinding" and station.start_button.disabled, "start consumes water_added and enters grinding")
	session.call("advance_f3_production", 2.0)
	station.refresh_from_session()
	var grinding_snapshot := Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine"))
	_check(is_equal_approx(float(grinding_snapshot.get("seconds_to_ready", -1.0)), 3.0) and station.state_label.text == "制作中 · 3秒", "direct soy station displays its remaining production countdown")
	session.call("advance_f3_production", 3.0)
	station.refresh_from_session()
	var ready_without_cup := Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine"))
	_check(StringName(ready_without_cup.get("state", &"")) == &"ready_safe" and not bool(ready_without_cup.get("manual_cup_ready", true)) and station.machine_output.visible and station.state_label.text == "可取 · 15秒后变质", "finished soy automatically exposes one deliverable machine cup")
	session.call("advance_f3_production", 16.0)
	station.refresh_from_session()
	var spoiled_source := Dictionary(station.machine_output.call("source_ref"))
	_check(StringName(Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine")).get("state", &"")) == &"spoiled" and bool(spoiled_source.get("discardable", false)) and station.state_label.text == "豆浆已变质，请拖到废弃区", "spoiled machine batch is draggable, not deliverable, and shows the discard prompt")
	var discarded := Dictionary(session.call("discard_product_source", spoiled_source))
	_check(bool(discarded.get("success", false)) and StringName(Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine")).get("state", &"")) == &"idle", "unified product-source disposal clears the spoiled machine batch after a successful transaction")
	station.queue_free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("DIRECT_SOY_WATER_CONTRACT_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("DIRECT_SOY_WATER_CONTRACT_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
