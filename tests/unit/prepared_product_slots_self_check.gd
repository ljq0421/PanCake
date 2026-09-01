extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession exists")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	var progression: RefCounted = session.call("progression_service")
	progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.youtiao": true})
	progression.set("device_tiers", {&"device.pancake_griddle": 0, &"device.youtiao_fryer": 2})
	progression.set("unlocked_recipe_ids", {&"recipe.pancake.base": true, &"recipe.youtiao.plain": true, &"recipe.chicken.cutlet": true})
	progression.set("unlocked_product_ids", {&"product.pancake.custom": true, &"product.youtiao.plain": true, &"product.chicken.cutlet": true})

	_check(StringName(Dictionary(session.call("prepared_product_slot_status", &"slot.fryer_finished")).get("reason", &"")) == &"finished_tray_locked", "shared prepared slot stays locked until the single finished-tray purchase")
	progression.set("owned_growth_ids", {&"growth.capacity.youtiao_finished_tray": true})
	var status := Dictionary(session.call("prepared_product_slot_status", &"slot.fryer_finished"))
	_check(bool(status.get("success", false)) and int(status.get("capacity", 0)) == 16 and int(status.get("columns", 0)) == 8 and int(status.get("rows", 0)) == 2, "one shared prepared slot exposes the 2x8 finished tray")
	_check(StringName(Dictionary(session.call("prepared_product_slot_status", &"slot.04")).get("reason", &"")) == &"unknown_prepared_product_slot" and StringName(Dictionary(session.call("prepared_product_slot_status", &"slot.chicken")).get("reason", &"")) == &"unknown_prepared_product_slot", "retired per-product prepared slots are unavailable")

	for index in range(8):
		_check(bool(Dictionary(session.call("_append_prepared_product", &"slot.fryer_finished", _product(StringName("oil.%d" % index), &"product.youtiao.plain"))).get("success", false)), "shared tray accepts oil strip %d" % (index + 1))
	_check(StringName(Dictionary(session.call("_append_prepared_product", &"slot.fryer_finished", _product(&"oil.overflow", &"product.youtiao.plain"))).get("reason", &"")) == &"prepared_product_slot_full", "shared tray limits oil strips to eight whole columns")

	session.call("clear_prepared_product_slots")
	for index in range(16):
		_check(bool(Dictionary(session.call("_append_prepared_product", &"slot.fryer_finished", _product(StringName("chicken.%d" % index), &"product.chicken.cutlet"))).get("success", false)), "shared tray accepts chicken %d" % (index + 1))
	_check(StringName(Dictionary(session.call("_append_prepared_product", &"slot.fryer_finished", _product(&"chicken.overflow", &"product.chicken.cutlet"))).get("reason", &"")) == &"prepared_product_slot_full", "shared tray limits chicken to sixteen cells")

	session.call("clear_prepared_product_slots")
	session.call("_append_prepared_product", &"slot.fryer_finished", _product(&"chicken.a", &"product.chicken.cutlet"))
	session.call("_append_prepared_product", &"slot.fryer_finished", _product(&"oil.a", &"product.youtiao.plain"))
	session.call("_append_prepared_product", &"slot.fryer_finished", _product(&"chicken.b", &"product.chicken.cutlet"))
	var entries := Array(Dictionary(session.call("prepared_product_slot_status", &"slot.fryer_finished")).get("entries", []))
	_check(entries.size() == 3 and Array(Dictionary(entries[0]).get("cell_indices", [])).hash() == [0].hash() and Array(Dictionary(entries[1]).get("cell_indices", [])).hash() == [2, 3].hash() and Array(Dictionary(entries[2]).get("cell_indices", [])).hash() == [1].hash(), "mixed products pack in insertion order while preserving whole oil-strip columns")
	_finish()


func _product(instance_id: StringName, product_id: StringName) -> Dictionary:
	return {"product_instance_id": instance_id, "product_id": product_id, "quality_grade": &"A"}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PREPARED_PRODUCT_SLOTS_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		printerr("PREPARED_PRODUCT_SLOTS_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
