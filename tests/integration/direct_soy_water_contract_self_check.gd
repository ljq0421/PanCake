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
	var loaded := Dictionary(session.call("load_f4_soy", &"recipe.fresh_soy_milk.yellow_bean", 1))
	station.refresh_from_session()
	_check(bool(loaded.get("success", false)) and not station.water_button.disabled and station.start_button.disabled, "loaded soy enables water but cannot start early")
	var watered := Dictionary(session.call("perform_f4_soy_action", &"add_water"))
	station.refresh_from_session()
	var snapshot := Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine"))
	_check(bool(watered.get("success", false)) and StringName(snapshot.get("state", &"")) == &"water_added" and station.water_button.disabled and not station.start_button.disabled, "water_added is the shared model and direct-UI start contract")
	var started := Dictionary(session.call("perform_f4_soy_action", &"start"))
	station.refresh_from_session()
	_check(bool(started.get("success", false)) and StringName(Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine")).get("state", &"")) == &"grinding" and station.start_button.disabled, "start consumes water_added and enters grinding")
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
