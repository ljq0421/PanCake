extends SceneTree

const SESSION := preload("res://scripts/services/noodle_shop_session.gd")
const CATALOG := preload("res://scripts/data/noodle_shop_catalog.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session: RefCounted = SESSION.new()
	var opened := Dictionary(session.call("ensure_active_order"))
	_check(bool(opened.get("success", false)) and bool(Dictionary(opened.get("order", {})).get("tutorial_no_countdown", false)), "first noodle order is an unlimited tutorial")
	_check(StringName(Dictionary(session.call("refuse_order")).get("reason", &"")) == &"tutorial_order_cannot_be_refused", "tutorial order cannot be refused")
	_check(bool(session.call("begin_active_recipe").get("success", false)), "tutorial recipe starts without managed stock")
	for index in 6:
		session.call("advance", 0.5)
		session.call("record_stroke", 140.0, 0.2)
	session.call("advance", 3.0)
	session.call("lift_basket")
	session.call("advance", 0.6)
	session.call("transfer_to_bowl")
	session.call("set_broth", &"broth.clear")
	session.call("add_topping", &"topping.scallion")
	var served := Dictionary(session.call("serve_bowl"))
	_check(bool(served.get("success", false)) and int(served.get("payment_coins", 0)) == 10, "perfect tutorial creates ten-coin payment")
	var collected := Dictionary(session.call("collect_payment"))
	_check(bool(collected.get("completed_tutorial_now", false)) and int(session.get("coins")) == 10, "collecting tutorial payment starts the timed day")
	session.call("set_business_paused", false)
	session.call("advance", 1.0)
	_check(is_equal_approx(float(session.get("remaining_seconds")), 59.0), "timer advances only after tutorial collection")
	session.call("end_day", &"manual")
	var purchase := Dictionary(session.call("purchase_growth", CATALOG.GROWTH_TOMATO))
	_check(bool(purchase.get("success", false)) and int(session.get("coins")) == 0, "tomato recipe is bought with noodle-shop coins")
	session.call("begin_next_day")
	_check(bool(Dictionary(session.get("unlocked_recipe_ids")).get(CATALOG.RECIPE_TOMATO, false)), "pending recipe activates next day")
	session.call("ensure_active_order")
	var refused := Dictionary(session.call("refuse_order"))
	_check(bool(refused.get("success", false)) and int(refused.get("reputation_delta", 0)) == -1, "ordinary untouched order can be refused with the shared lifecycle penalty")
	var restored: RefCounted = SESSION.new(session.call("snapshot"))
	_check(Dictionary(restored.call("snapshot")) == Dictionary(session.call("snapshot")), "noodle session restores all independent state")
	restored.call("set_business_paused", false)
	restored.set("active_order", {
		"order_id": &"noodle.order.patience",
		"tutorial_no_countdown": false,
		"remaining_patience_seconds": 0.1,
	})
	var abandoned := Dictionary(restored.call("advance", 0.2))
	_check(bool(abandoned.get("customer_left_now", false)) and int(abandoned.get("reputation_delta", 0)) == -2 and Dictionary(restored.get("active_order")).is_empty(), "expired patience removes the customer and records the shared-reputation penalty")
	var growth_session: RefCounted = SESSION.new()
	growth_session.set("day_open", false)
	growth_session.set("coins", 120)
	_check(StringName(Dictionary(growth_session.call("purchase_growth", CATALOG.GROWTH_ZHAJIANG)).get("reason", &"")) == &"missing_prerequisite", "zhajiang recipe requires the tomato-egg recipe")
	_check(bool(Dictionary(growth_session.call("purchase_growth", CATALOG.GROWTH_TOMATO)).get("success", false)), "tomato-egg recipe costs ten coins")
	_check(bool(Dictionary(growth_session.call("purchase_growth", CATALOG.GROWTH_ZHAJIANG)).get("success", false)), "zhajiang recipe can queue after its prerequisite")
	_check(bool(Dictionary(growth_session.call("purchase_growth", CATALOG.GROWTH_SHARP_KNIFE)).get("success", false)) and bool(Dictionary(growth_session.call("purchase_growth", CATALOG.GROWTH_STABLE_BASKET)).get("success", false)) and int(growth_session.get("coins")) == 11, "the four authored growth prices total 109 coins and all queue for next day")
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("NOODLE_SHOP_SESSION_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("NOODLE_SHOP_SESSION_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
