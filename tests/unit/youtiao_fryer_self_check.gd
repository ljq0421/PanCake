extends SceneTree

const MODEL := preload("res://scripts/gameplay/youtiao_fryer_model.gd")
var _failures: Array[String] = []


func _initialize() -> void:
	var fryer: RefCounted = MODEL.new()
	_check(fryer.call("load_recipe", &"recipe.youtiao.plain", 1).get("reason") == &"equipment_not_owned", "locked fryer rejects loading")
	fryer.call("configure_owned", 0)
	_check(int(fryer.call("capacity")) == 4, "basic fryer capacity is four")
	_check(bool(fryer.call("load_recipe", &"recipe.youtiao.plain", 1).get("success", false)), "partial batch is allowed")
	_check(fryer.call("load_recipe", &"recipe.youtiao.oil_cake", 1).get("reason") == &"invalid_recipe", "removed recipes are rejected")
	_check(bool(fryer.call("load_recipe", &"recipe.youtiao.plain", 3).get("success", false)), "matching recipe fills remaining capacity")
	_check(fryer.call("load_recipe", &"recipe.youtiao.plain", 1).get("reason") == &"capacity_exceeded", "capacity is enforced")
	_check(bool(fryer.call("start").get("success", false)), "loaded fryer starts")
	fryer.call("advance_time", 10.0)
	_check(fryer.get("state") == &"ready_safe", "batch enters safe window at completion")
	fryer.call("advance_time", 5.0)
	_check(fryer.get("state") == &"ready_safe" and is_equal_approx(float(fryer.get("quality")), 100.0), "full five second safe window does not decay")
	fryer.call("advance_time", 0.001)
	_check(fryer.get("state") == &"overcooking" and float(fryer.get("quality")) < 100.0, "quality begins decaying after the safe window")
	_check(bool(fryer.call("lift").get("success", false)), "overcooking batch can be lifted at current quality")
	fryer.call("advance_time", 2.0)
	_check(fryer.get("state") == &"ready_to_collect", "two second draining makes products collectible")
	var first: Dictionary = fryer.call("collect", 1)
	_check(bool(first.get("success", false)) and int(first.get("remaining_quantity", 0)) == 3 and fryer.get("state") == &"ready_to_collect", "partial collection leaves extra product in fryer")
	_check(bool(fryer.call("collect", 3).get("success", false)) and fryer.get("state") == &"idle", "last collection releases fryer")

	var stable_slots: RefCounted = MODEL.new(0, true)
	stable_slots.call("load_recipe", &"recipe.youtiao.plain", 2)
	stable_slots.call("start")
	stable_slots.call("advance_time", 10.0)
	stable_slots.call("lift")
	stable_slots.call("advance_time", 2.0)
	var left_result := Dictionary(stable_slots.call("collect_slot", 0))
	_check(bool(left_result.get("success", false)) and Array(stable_slots.call("snapshot").get("occupied_slot_indices", [])).hash() == [1].hash(), "collecting the left fryer slot keeps the right product in slot one")
	var hole_restored: RefCounted = MODEL.new()
	hole_restored.call("load_snapshot", stable_slots.call("snapshot"))
	_check(Array(hole_restored.call("snapshot").get("occupied_slot_indices", [])).hash() == [1].hash(), "fryer snapshot preserves an empty left slot")
	_check(bool(hole_restored.call("collect_slot", 1).get("success", false)) and hole_restored.get("state") == &"idle", "the product remaining in the right slot can be collected independently")
	var legacy_slots: RefCounted = MODEL.new()
	legacy_slots.call("load_snapshot", {"owned": true, "tier": 0, "state": &"loaded", "recipe_id": &"recipe.youtiao.plain", "quantity": 2})
	_check(Array(legacy_slots.call("snapshot").get("occupied_slot_indices", [])).hash() == [0, 1].hash(), "legacy quantity-only snapshots rebuild slots from left to right")

	var burnt: RefCounted = MODEL.new(0, true)
	burnt.call("load_recipe", &"recipe.youtiao.plain", 4)
	burnt.call("start")
	burnt.call("advance_time", 25.001)
	_check(burnt.get("state") == &"burnt", "four-slot fryer still burns without auto lift")
	_check(bool(burnt.call("discard").get("success", false)) and burnt.get("state") == &"idle", "burnt batch discards as one batch")

	for discard_state in [&"loaded", &"frying", &"ready_safe", &"overcooking", &"draining", &"ready_to_collect", &"burnt"]:
		var discardable: RefCounted = MODEL.new()
		discardable.call("load_snapshot", {
			"owned": true,
			"tier": 0,
			"state": discard_state,
			"recipe_id": &"recipe.youtiao.plain",
			"quantity": 2,
			"quality": 0.0 if discard_state == &"burnt" else 85.0,
		})
		var discarded := Dictionary(discardable.call("discard_slot", 0))
		_check(bool(discarded.get("success", false)) and int(discarded.get("quantity", 0)) == 1 and StringName(discarded.get("discarded_state", &"")) == discard_state and Array(discardable.call("snapshot").get("occupied_slot_indices", [])).hash() == [1].hash(), "%s fryer supports one-slot waste without reflowing the other slot" % discard_state)
		_check(bool(discardable.call("discard_slot", 1).get("success", false)) and discardable.get("state") == &"idle", "%s fryer returns idle after its final slot is discarded" % discard_state)

	var automated: RefCounted = MODEL.new(0, true)
	automated.call("load_recipe", &"recipe.youtiao.plain", 1)
	automated.call("start")
	automated.call("advance_time", 10.0, true)
	_check(automated.get("state") == &"draining", "auto lift replaces only the lift action")
	automated.call("advance_time", 2.0, true)
	_check(automated.get("state") == &"ready_to_collect", "auto lifted product still requires normal draining")
	var restored: RefCounted = MODEL.new()
	restored.call("load_snapshot", automated.call("snapshot"))
	_check(restored.get("state") == &"ready_to_collect", "fryer snapshot restores without offline time progression")

	var advanced: RefCounted = MODEL.new(1, true)
	_check(int(advanced.call("capacity")) == 4, "advanced fryer keeps the four-slot basket")
	advanced.call("load_recipe", &"recipe.youtiao.plain", 1)
	advanced.call("start")
	advanced.call("advance_time", 10.0, true)
	_check(advanced.get("state") == &"draining", "advanced fryer supports automatic basket lifting")
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
