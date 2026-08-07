extends SceneTree

const MODEL := preload("res://scripts/gameplay/youtiao_fryer_model.gd")
var _failures: Array[String] = []


func _initialize() -> void:
	var fryer: RefCounted = MODEL.new()
	_check(fryer.call("load_recipe", &"recipe.youtiao.plain", 1).get("reason") == &"equipment_not_owned", "locked fryer rejects loading")
	fryer.call("configure_owned", 0)
	_check(int(fryer.call("capacity")) == 2, "basic fryer capacity is two")
	_check(bool(fryer.call("load_recipe", &"recipe.youtiao.plain", 1).get("success", false)), "partial batch is allowed")
	_check(fryer.call("load_recipe", &"recipe.youtiao.oil_cake", 1).get("reason") == &"mixed_recipe", "one batch cannot mix recipes")
	_check(bool(fryer.call("load_recipe", &"recipe.youtiao.plain", 1).get("success", false)), "matching recipe fills remaining capacity")
	_check(fryer.call("load_recipe", &"recipe.youtiao.plain", 1).get("reason") == &"capacity_exceeded", "capacity is enforced")
	_check(bool(fryer.call("start").get("success", false)), "loaded fryer starts")
	fryer.call("advance_time", 12.0)
	_check(fryer.get("state") == &"ready_safe", "batch enters safe window at completion")
	fryer.call("advance_time", 5.0)
	_check(fryer.get("state") == &"ready_safe" and is_equal_approx(float(fryer.get("quality")), 100.0), "full five second safe window does not decay")
	fryer.call("advance_time", 0.001)
	_check(fryer.get("state") == &"overcooking" and float(fryer.get("quality")) < 100.0, "quality begins decaying after the safe window")
	_check(bool(fryer.call("lift").get("success", false)), "overcooking batch can be lifted at current quality")
	fryer.call("advance_time", 2.0)
	_check(fryer.get("state") == &"ready_to_collect", "two second draining makes products collectible")
	var first: Dictionary = fryer.call("collect", 1)
	_check(bool(first.get("success", false)) and int(first.get("remaining_quantity", 0)) == 1 and fryer.get("state") == &"ready_to_collect", "partial collection leaves extra product in fryer")
	_check(bool(fryer.call("collect", 1).get("success", false)) and fryer.get("state") == &"idle", "last collection releases fryer")

	var burnt: RefCounted = MODEL.new(2, true)
	burnt.call("load_recipe", &"recipe.youtiao.sugar_oil_cake", 4)
	burnt.call("start")
	burnt.call("advance_time", 24.001)
	_check(burnt.get("state") == &"burnt", "advanced fryer still burns without auto lift")
	_check(bool(burnt.call("discard").get("success", false)) and burnt.get("state") == &"idle", "burnt batch discards as one batch")

	var automated: RefCounted = MODEL.new(0, true)
	automated.call("load_recipe", &"recipe.youtiao.plain", 1)
	automated.call("start")
	automated.call("advance_time", 12.0, true)
	_check(automated.get("state") == &"draining", "auto lift replaces only the lift action")
	automated.call("advance_time", 2.0, true)
	_check(automated.get("state") == &"ready_to_collect", "auto lifted product still requires normal draining")
	var restored: RefCounted = MODEL.new()
	restored.call("load_snapshot", automated.call("snapshot"))
	_check(restored.get("state") == &"ready_to_collect", "fryer snapshot restores without offline time progression")
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("YOUTIAO_FRYER_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("YOUTIAO_FRYER_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)

