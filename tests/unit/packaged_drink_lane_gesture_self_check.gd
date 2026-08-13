extends SceneTree

var _failures: Array[String] = []
var _hold_started := 0
var _hold_delta := 0.0
var _drag_started := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var lane := ProductDragSource.new()
	root.add_child(lane)
	lane.hold_enabled = true
	lane.hold_threshold_seconds = 0.1
	lane.configure({"source_kind": &"inventory", "source_index": 0, "product_id": &"product.packaged_drink.milk"}, null, true)
	lane.hold_requested.connect(_on_hold_requested.bind(lane))
	lane.hold_advanced.connect(_on_hold_advanced)
	lane.drag_started.connect(func(_source_ref: Dictionary): _drag_started += 1)

	lane.set_drag_available(false)
	lane.begin_gesture(Vector2.ZERO)
	lane.advance_gesture(0.099)
	_check(_hold_started == 0, "drink lane does not restock before 0.1 seconds")
	lane.advance_gesture(0.001)
	lane.advance_gesture(0.25)
	_check(_hold_started == 1 and is_equal_approx(_hold_delta, 0.25), "empty drink lane enters hold restock at 0.1 seconds")
	lane.update_gesture(Vector2(30.0, 0.0), false)
	_check(_drag_started == 0 and lane.is_hold_active(), "restocking hold cannot turn into a drag")
	lane.end_gesture()

	lane.set_drag_available(true)
	lane.begin_gesture(Vector2.ZERO)
	lane.advance_gesture(0.05)
	lane.update_gesture(Vector2(10.01, 0.0), false)
	_check(_drag_started == 1 and not lane.is_hold_active(), "stocked drink moves over 10px before 0.1 seconds and starts drag")

	lane.begin_gesture(Vector2.ZERO)
	lane.advance_gesture(0.1)
	lane.advance_gesture(0.2)
	_check(_hold_started == 2 and lane.is_hold_active(), "stationary stocked drink still enters the accepted long-hold refill path")
	lane.update_gesture(Vector2(18.0, 0.0), false)
	_check(_drag_started == 2 and not lane.is_hold_active(), "slow drag movement supersedes an already accepted refill hold")

	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession exists")
	if session != null:
		session.call("begin_new_game")
		var progression: RefCounted = session.call("progression_service")
		progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.packaged_drink": true})
		progression.set("unlocked_recipe_ids", {&"recipe.pancake.base": true, &"recipe.packaged_drink.milk": true})
		progression.set("unlocked_product_ids", {&"product.pancake.custom": true, &"product.packaged_drink.milk": true})
		progression.set("unlocked_stock_ids", {&"stock.packaged_drink.milk": true})
		progression.set("coins", 10)
		var inventory := Dictionary(session.call("inventory_snapshot"))
		inventory["stock.packaged_drink.milk"] = 0
		session.call("save_inventory", inventory)
		var partial := Dictionary(session.call("advance_five_area_restock_hold", &"stock.packaged_drink.milk", 0.2))
		var completed := Dictionary(session.call("advance_five_area_restock_hold", &"stock.packaged_drink.milk", 0.3))
		_check(int(partial.get("completed_units", -1)) == 0 and is_equal_approx(float(partial.get("progress_seconds", 0.0)), 0.2) and int(completed.get("completed_units", 0)) == 1, "released drink restock retains partial progress until the next hold")
		var continuous := Dictionary(session.call("advance_five_area_restock_hold", &"stock.packaged_drink.milk", 1.0))
		_check(int(continuous.get("completed_units", 0)) == 2 and int(Dictionary(session.call("inventory_snapshot")).get("stock.packaged_drink.milk", 0)) == 3, "continuous drink hold completes one bottle every 0.5 seconds")
		inventory = Dictionary(session.call("inventory_snapshot"))
		inventory["stock.packaged_drink.milk"] = 6
		session.call("save_inventory", inventory)
		var coins_before := int(progression.get("coins"))
		var full := Dictionary(session.call("advance_five_area_restock_hold", &"stock.packaged_drink.milk", 0.5))
		_check(full.get("reason") == &"capacity_reached" and int(progression.get("coins")) == coins_before, "full drink lane stops without charging")
		inventory["stock.packaged_drink.milk"] = 0
		session.call("save_inventory", inventory)
		progression.set("coins", 0)
		var broke := Dictionary(session.call("advance_five_area_restock_hold", &"stock.packaged_drink.milk", 0.5))
		_check(broke.get("reason") == &"insufficient_coins" and int(Dictionary(session.call("inventory_snapshot")).get("stock.packaged_drink.milk", 0)) == 0, "insufficient coins stops drink restock without inventory change")
	lane.queue_free()
	_finish()


func _on_hold_requested(_source_ref: Dictionary, lane: ProductDragSource) -> void:
	_hold_started += 1
	lane.accept_hold()


func _on_hold_advanced(_source_ref: Dictionary, delta: float) -> void:
	_hold_delta += delta


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PACKAGED_DRINK_LANE_GESTURE_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("PACKAGED_DRINK_LANE_GESTURE_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
