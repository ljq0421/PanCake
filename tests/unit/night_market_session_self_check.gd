extends SceneTree

const SESSION := preload("res://scripts/services/night_market_session.gd")
const CATALOG := preload("res://scripts/data/night_market_catalog.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session: RefCounted = SESSION.new()
	var opened := Dictionary(session.call("ensure_active_order"))
	var order := Dictionary(opened.get("order", {}))
	_check(bool(opened.get("success", false)) and bool(order.get("tutorial_no_countdown", false)), "first night-market order is an unlimited tutorial")
	_check(Array(order.get("item_ids", [])) == [CATALOG.ITEM_LAMB, CATALOG.ITEM_LOTUS], "tutorial teaches one grilled and one fried skewer")
	_check(StringName(Dictionary(session.call("refuse_order")).get("reason", &"")) == &"tutorial_order_cannot_be_refused", "tutorial order cannot be refused")
	session.call("add_grill_skewer", CATALOG.ITEM_LAMB, CATALOG.ZONE_MEDIUM)
	session.call("advance", 7.0)
	session.call("flip_grill_slot", 2)
	session.call("advance", 7.0)
	session.call("plate_grill_slot", 2)
	session.call("season_last", CATALOG.SEASONING_CUMIN)
	session.call("add_fryer_item", CATALOG.ITEM_LOTUS)
	session.call("lower_fryer")
	session.call("advance", 5.5)
	session.call("lift_fryer")
	session.call("advance", 1.0)
	session.call("plate_fryer")
	session.call("season_last", CATALOG.SEASONING_SALT_PEPPER)
	var served := Dictionary(session.call("serve_plate"))
	_check(bool(served.get("success", false)) and int(served.get("payment_coins", 0)) == 18, "tutorial combo creates the fixed eighteen-coin payment")
	var collected := Dictionary(session.call("collect_payment"))
	_check(bool(collected.get("completed_tutorial_now", false)) and int(session.get("coins")) == 18, "collecting tutorial payment starts timed service")
	session.call("set_business_paused", false)
	session.call("advance", 1.0)
	_check(is_equal_approx(float(session.get("remaining_seconds")), 59.0), "first-day timer advances only after tutorial collection")
	session.call("end_day", &"manual")
	session.set("coins", 104)
	for growth_id in CATALOG.GROWTH_DISPLAY_ORDER:
		var purchase := Dictionary(session.call("purchase_growth", growth_id))
		_check(bool(purchase.get("success", false)), "growth %s queues for next day" % growth_id)
	_check(not bool(Dictionary(session.call("milestone_progress")).get("complete", true)), "pending growth does not complete the chapter milestone")
	session.call("begin_next_day")
	_check(bool(Dictionary(session.call("milestone_progress")).get("complete", false)), "all four active growth items complete the night-market milestone")
	_check(bool(Dictionary(session.get("unlocked_recipe_ids")).get(CATALOG.RECIPE_PREMIUM_COMBO, false)), "both expansion recipes unlock the premium combo")
	var restored: RefCounted = SESSION.new(session.call("snapshot"))
	_check(Dictionary(restored.call("snapshot")) == Dictionary(session.call("snapshot")), "night-market session restores independent state")
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("NIGHT_MARKET_SESSION_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("NIGHT_MARKET_SESSION_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
