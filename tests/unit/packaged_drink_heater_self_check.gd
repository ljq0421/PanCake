extends SceneTree

const MODEL := preload("res://scripts/gameplay/packaged_drink_heater_model.gd")
var _failures: Array[String] = []


func _initialize() -> void:
	var heater: RefCounted = MODEL.new()
	_check(heater.call("load_product", 0, &"product.packaged_drink.milk").get("reason") == &"equipment_not_owned", "locked heater rejects loading")
	_check(bool(heater.call("configure_owned", 0).get("success", false)) and int(heater.call("capacity")) == 1, "basic heater opens one slot")
	_check(bool(heater.call("load_product", 0, &"product.packaged_drink.milk").get("success", false)), "unlocked slot accepts a drink")
	_check(heater.call("load_product", 0, &"product.packaged_drink.milk").get("reason") == &"slot_occupied", "occupied slot rejects a second drink")
	heater.call("advance_time", 1.999)
	_check(Dictionary(heater.call("slot_snapshot", 0)).get("state") == &"heating", "drink remains heating before two seconds")
	heater.call("advance_time", 0.001)
	_check(Dictionary(heater.call("slot_snapshot", 0)).get("state") == &"ready_hot", "drink becomes hot at two seconds")
	heater.call("advance_time", 8.2)
	_check(Dictionary(heater.call("slot_snapshot", 0)).get("state") == &"cooled", "basic hot drink enters cooled state after the eight second window")
	_check(bool(heater.call("collect", 0).get("success", false)), "boundary collection accepts the confirmed 0.3 second grace")
	_check(bool(heater.call("load_product", 0, &"product.packaged_drink.milk").get("success", false)), "slot is reusable after collection")
	heater.call("advance_time", 10.31)
	_check(heater.call("collect", 0).get("reason") == &"drink_cooled", "collection is rejected outside input grace")
	_check(bool(heater.call("discard", 0).get("success", false)), "cooled drink can be discarded")
	_check(bool(heater.call("configure_owned", 1).get("success", false)) and int(heater.call("capacity")) == 2, "intermediate heater opens two slots")
	_check(bool(heater.call("configure_owned", 2).get("success", false)) and int(heater.call("capacity")) == 4, "advanced heater opens four slots")
	heater.call("load_product", 3, &"product.packaged_drink.black_sesame")
	heater.call("advance_time", 1000.0)
	_check(Dictionary(heater.call("slot_snapshot", 3)).get("state") == &"ready_hot", "advanced heater holds completed drinks indefinitely while occupying the slot")
	var restored: RefCounted = MODEL.new()
	restored.call("load_snapshot", heater.call("snapshot"))
	_check(Dictionary(restored.call("slot_snapshot", 3)).get("state") == &"ready_hot", "heater snapshot restores without offline time progression")
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PACKAGED_DRINK_HEATER_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("PACKAGED_DRINK_HEATER_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)

