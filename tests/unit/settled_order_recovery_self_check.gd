extends SceneTree

const GAME_SESSION_STORE := preload("res://scripts/services/game_session_store.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var store := GAME_SESSION_STORE.new()
	store.call("begin_new_game")
	var legacy_order := {
		"id": &"order.recovery",
		"title": "恢复订单",
		"ingredients": [&"egg", &"baocui", &"scallion"],
		"sauces": [&"sweet_flour"],
		"heat_preference": &"golden",
		"payment_coins": 3,
	}
	var opened: Dictionary = store.call("open_pancake_order", legacy_order)
	var formal_order_id: StringName = Dictionary(opened.get("order", {})).get("order_id", &"")
	var product := {
		"product_instance_id": &"product.recovery.1",
		"product_id": &"product.pancake.custom",
		"heat_preference": &"golden",
		"ingredient_ids": [&"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.scallion"],
		"sauce_ids": [&"stock.pancake.sauce.sweet_flour"],
		"score": 80.0,
		"material_cost": 2,
	}
	_check(bool(opened.get("success", false)), "test creates a formal pancake order")
	_check(bool(store.call("attach_formal_order_product", formal_order_id, 0, product).get("success", false)), "test attaches a product before simulating the interrupted tail")
	_check(bool(store.call("settle_formal_order", formal_order_id).get("success", false)), "test persists the formal settlement")
	var initial_coins := int(Dictionary(store.call("five_area_progression_snapshot")).get("coins", 0))
	store.call("_reconcile_unrecorded_settled_orders")
	store.call("_reconcile_unrecorded_settled_orders")
	_check(int(Dictionary(store.call("today_bill")).get("order_count", 0)) == 1, "startup reconciliation records a settled order once")
	_check(int(Dictionary(store.call("five_area_progression_snapshot")).get("coins", 0)) == initial_coins + 3, "startup reconciliation credits a lost payment exactly once")
	var completed_order: Dictionary = Array(Dictionary(store.call("today_bill")).get("orders", []))[0]
	_check(StringName(completed_order.get("formal_order_id", &"")) == formal_order_id, "the recovered bill row records its formal order ID")
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SETTLED_ORDER_RECOVERY_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("SETTLED_ORDER_RECOVERY_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
