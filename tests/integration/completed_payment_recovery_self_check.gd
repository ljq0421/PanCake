extends SceneTree

const SCENE := preload("res://scenes/gameplay/initial_unlock_workstation.tscn")
const SESSION := preload("res://scripts/gameplay/p1_session.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_session := root.get_node_or_null("GameSession")
	_check(game_session != null, "test has the GameSession autoload")
	if game_session == null:
		_finish()
		return
	game_session.call("begin_new_game")
	var legacy_order := {
		"id": &"order.recovery",
		"ingredients": [&"egg", &"baocui", &"scallion"],
		"sauces": [&"sweet_flour"],
		"heat_preference": &"golden",
		"time_limit": 72.0,
		"payment_coins": 3,
	}
	var opened: Dictionary = game_session.call("open_pancake_order", legacy_order)
	var settled_order_id: StringName = Dictionary(opened.get("order", {})).get("order_id", &"")
	var product := {
		"product_instance_id": &"product.recovery.1",
		"product_id": &"product.pancake.custom",
		"heat_preference": &"golden",
		"ingredient_ids": [&"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.scallion"],
		"sauce_ids": [&"stock.pancake.sauce.sweet_flour"],
	}
	_check(bool(opened.get("success", false)), "test creates a formal pancake order")
	_check(bool(game_session.call("attach_formal_order_product", settled_order_id, 0, product).get("success", false)), "test attaches the completed pancake")
	_check(bool(game_session.call("settle_formal_order", settled_order_id).get("success", false)), "test persists the formal settlement before the callback tail")
	var workstation := SCENE.instantiate()
	root.add_child(workstation)
	await process_frame
	workstation.set("_formal_order_id", settled_order_id)
	workstation.p1_session.phase = SESSION.Phase.RESULT
	workstation.p1_session.result = {"score": 80.0, "feedback": "已完成"}
	workstation.set("_current_payment_amount", 3)
	workstation.call("_recover_completed_payment_if_needed")
	_check(int(Dictionary(game_session.call("today_bill")).get("order_count", 0)) == 1, "a persisted formal settlement records the completed order exactly once")
	_check(workstation.p1_session.phase == SESSION.Phase.SPREAD, "a recovered completed payment advances to the next customer instead of remaining in RESULT")
	var interrupted_order_id: StringName = Dictionary(game_session.call("active_formal_order")).get("order_id", &"")
	var interrupted_order: Dictionary = workstation.p1_session.order.duplicate(true)
	workstation.p1_session.phase = SESSION.Phase.RESULT
	workstation.p1_session.result = {
		"score": 50.0,
		"feedback": "结算中断",
		"applied_ingredient_ids": Array(interrupted_order.get("ingredients", [])),
		"applied_sauce_ids": Array(interrupted_order.get("sauces", [])),
	}
	workstation.call("_recover_completed_payment_if_needed")
	var recovered_snapshot: Dictionary = game_session.call("formal_order_snapshot")
	var recovered_order: Dictionary = Dictionary(Dictionary(recovered_snapshot.get("orders", {})).get(str(interrupted_order_id), {}))
	_check(StringName(recovered_order.get("state", &"")) == &"settled", "an unsettled paid order finishes its durable formal settlement")
	_check(int(Dictionary(game_session.call("today_bill")).get("order_count", 0)) == 2, "an unsettled paid order is recorded once instead of being discarded")
	_check(workstation.p1_session.phase == SESSION.Phase.SPREAD, "recovery advances to the next customer instead of replaying the paid order")
	var closing_order: Dictionary = workstation.p1_session.order.duplicate(true)
	workstation.p1_session.phase = SESSION.Phase.RESULT
	workstation.p1_session.result = {
		"score": 60.0,
		"feedback": "打烊前已付款",
		"applied_ingredient_ids": Array(closing_order.get("ingredients", [])),
		"applied_sauce_ids": Array(closing_order.get("sauces", [])),
	}
	workstation.set("_current_payment_amount", int(closing_order.get("payment_coins", 3)))
	workstation.set("_business_day_expiration_pending", true)
	workstation.call("_recover_completed_payment_if_needed")
	_check(bool(workstation.get("_business_day_closed")), "an expired timer waits for the paid order tail and then closes the business day")
	_check(workstation.daily_bill_panel.visible, "finishing the paid order at cutoff opens the daily bill instead of leaving RESULT on screen")
	_check(int(Dictionary(game_session.call("today_bill")).get("order_count", 0)) == 3, "the cutoff order is included in the daily bill")
	workstation.queue_free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("COMPLETED_PAYMENT_RECOVERY_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("COMPLETED_PAYMENT_RECOVERY_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
