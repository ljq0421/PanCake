extends SceneTree

const TRAY = preload("res://scripts/gameplay/pancake_holding_tray_model.gd")
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var tray: RefCounted = TRAY.new()
	var order := {"product_id": &"product.pancake.custom", "heat_preference": &"golden", "ingredient_ids": [&"stock.pancake.egg", &"stock.pancake.baocui"], "sauce_ids": [&"stock.pancake.sauce.sweet_flour"]}
	var product := {"product_instance_id": &"product_instance.pancake.1", "product_id": &"product.pancake.custom", "heat_preference": &"golden", "ingredient_ids": [&"stock.pancake.baocui", &"stock.pancake.egg"], "sauce_ids": [&"stock.pancake.sauce.sweet_flour"], "score": 90.0}
	_check(bool(tray.call("store", product).get("success", false)) and tray.call("store", product.duplicate(true)).get("reason") == &"duplicate_product_instance", "tray rejects duplicate product instances")
	var product_two: Dictionary = product.duplicate(true)
	product_two["product_instance_id"] = &"product_instance.pancake.2"
	_check(bool(tray.call("store", product_two).get("success", false)) and not bool(tray.call("store", product_two).get("success", false)), "tray has exactly two slots")
	tray.call("advance_time", 40.0)
	var aging: Dictionary = tray.call("preview_serve_matching", 0, order)
	_check(bool(aging.get("success", false)) and is_equal_approx(float(aging.get("freshness_penalty", 0.0)), 10.0) and aging.get("grade") == &"B", "aging tray product applies linear freshness penalty and recomputes grade")
	var mismatch: Dictionary = order.duplicate(true)
	mismatch["sauce_ids"] = [&"stock.pancake.sauce.red_chili"]
	var mismatch_preview: Dictionary = tray.call("preview_serve", 0, mismatch)
	_check(bool(mismatch_preview.get("success", false)) and Array(mismatch_preview.get("mismatch_reasons", [])).has("sauce_ids"), "tray allows a mismatched pancake and reports the score reason")
	_check(is_equal_approx(float(mismatch_preview.get("legacy_order_penalty", 0.0)), 13.0) and mismatch_preview.get("grade") == &"C", "legacy tray snapshots receive the documented sauce-category penalty")
	tray.call("advance_time", 20.0)
	var stale: Dictionary = tray.call("preview_serve", 0, order)
	_check(bool(stale.get("success", false)) and is_equal_approx(float(stale.get("freshness_penalty", 0.0)), 20.0) and Dictionary(stale.get("product", {})).get("state") == &"stale", "60-second product remains sellable with the capped freshness penalty")
	tray.call("advance_time", 300.0)
	_check(is_equal_approx(float(tray.call("preview_serve", 0, order).get("freshness_penalty", 0.0)), 20.0), "freshness penalty stays capped after 60 seconds")
	var served: Dictionary = tray.call("serve", 0, mismatch)
	_check(bool(served.get("success", false)) and Dictionary(tray.call("slot_snapshot", 0)).get("state") == &"empty", "serving a mismatched stale pancake consumes exactly one stored instance")
	_check(tray.call("clear_for_day_end").size() == 1 and tray.call("snapshot").get("slots", []).all(func(slot: Dictionary): return slot.is_empty()), "day end clears the remaining tray slot")
	_finish()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("PANCAKE_HOLDING_TRAY_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("PANCAKE_HOLDING_TRAY_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
