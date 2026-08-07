extends SceneTree

const DRINK_SCENE := preload("res://scenes/gameplay/stations/packaged_drink_station.tscn")
const YOUTIAO_SCENE := preload("res://scenes/gameplay/stations/youtiao_station.tscn")
const WORKBENCH_SCENE := preload("res://scenes/gameplay/f3_stations_workbench.tscn")
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var drink := DRINK_SCENE.instantiate()
	root.add_child(drink)
	_check(drink.has_signal("intent_requested"), "drink station exposes intent signal")
	for path in ["Margin/Content/ProductShelf/MilkButton", "Margin/Content/HeaterSlots/HeaterSlot1", "Margin/Content/HeaterSlots/HeaterSlot4", "LockOverlay"]:
		_check(drink.has_node(path), "drink station keeps stable node %s" % path)
	drink.call("apply_snapshot", {"machine": {"tier": 2, "slots": [{"state": &"empty"}, {"state": &"empty"}, {"state": &"empty"}, {"state": &"empty"}]}, "inventory": {"stock.packaged_drink.milk": 2}, "unlocked_product_ids": ["product.packaged_drink.milk"], "order_id": &"order.test", "item_index": 0, "order_item": {"product_id": &"product.packaged_drink.milk", "temperature_mode": &"heated"}})
	drink.call("set_locked", false, "")
	_check("高级" in (drink.get_node("Margin/Content/Header/TierLabel") as Label).text, "drink station renders advanced tier")
	_check(not (drink.get_node("Margin/Content/HeaterSlots/HeaterSlot4") as Button).disabled, "advanced drink slot four is interactive")
	drink.queue_free()

	var youtiao := YOUTIAO_SCENE.instantiate()
	root.add_child(youtiao)
	_check(youtiao.has_signal("intent_requested"), "youtiao station exposes intent signal")
	for path in ["Margin/Content/RecipeShelf/PlainButton", "Margin/Content/ActionRow/StartButton", "Margin/Content/ActionRow/LiftButton", "LockOverlay"]:
		_check(youtiao.has_node(path), "youtiao station keeps stable node %s" % path)
	youtiao.call("apply_snapshot", {"machine": {"tier": 0, "capacity": 2, "state": &"ready_safe", "quality": 100.0}, "inventory": {"stock.youtiao.plain_dough": 2}, "unlocked_recipe_ids": ["recipe.youtiao.plain"], "order_id": &"order.test", "item_index": 0, "order_item": {"product_id": &"product.youtiao.plain"}})
	youtiao.call("set_locked", false, "")
	_check(not (youtiao.get_node("Margin/Content/ActionRow/LiftButton") as Button).disabled, "ready youtiao exposes manual lift")
	youtiao.queue_free()

	var workbench := WORKBENCH_SCENE.instantiate()
	root.add_child(workbench)
	_check(workbench.has_node("SafeArea/Content/Stations/PackagedDrinkStation") and workbench.has_node("SafeArea/Content/Stations/YoutiaoStation"), "F3 workbench owns both stable station instances")
	workbench.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("F3_STATION_SCENE_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("F3_STATION_SCENE_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)

