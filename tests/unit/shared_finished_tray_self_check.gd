extends SceneTree

const PROGRESSION = preload("res://scripts/services/five_area_progression_service.gd")

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
	progression.set("unlocked_product_ids", {&"product.pancake.custom": true, &"product.youtiao.plain": true, &"product.chicken.cutlet": true})
	progression.set("owned_growth_ids", {&"growth.capacity.youtiao_finished_tray": true})

	var shared_status := Dictionary(session.call("prepared_product_slot_status", &"slot.fryer_finished"))
	_check(bool(shared_status.get("success", false)) and int(shared_status.get("capacity", 0)) == 16 and int(shared_status.get("columns", 0)) == 8 and int(shared_status.get("rows", 0)) == 2, "shared finished tray exposes one unlocked 2x8 grid")

	session.call("_append_prepared_product", &"slot.fryer_finished", _product(&"chicken.first", &"product.chicken.cutlet"))
	session.call("_append_prepared_product", &"slot.fryer_finished", _product(&"youtiao.first", &"product.youtiao.plain"))
	session.call("_append_prepared_product", &"slot.fryer_finished", _product(&"chicken.second", &"product.chicken.cutlet"))
	var mixed_entries := Array(Dictionary(session.call("prepared_product_slot_status", &"slot.fryer_finished")).get("entries", []))
	_check(
		mixed_entries.size() == 3
		and Array(Dictionary(mixed_entries[0]).get("cell_indices", [])).hash() == [0].hash()
		and Array(Dictionary(mixed_entries[1]).get("cell_indices", [])).hash() == [2, 3].hash()
		and Array(Dictionary(mixed_entries[2]).get("cell_indices", [])).hash() == [1].hash(),
		"chicken-youtiao-chicken keeps insertion order while packing chicken cells and whole youtiao columns",
	)

	session.call("clear_prepared_product_slots")
	for index in range(8):
		_check(bool(Dictionary(session.call("_append_prepared_product", &"slot.fryer_finished", _product(StringName("youtiao.%d" % index), &"product.youtiao.plain"))).get("success", false)), "shared tray accepts oil strip %d" % (index + 1))
	_check(StringName(Dictionary(session.call("_append_prepared_product", &"slot.fryer_finished", _product(&"youtiao.overflow", &"product.youtiao.plain"))).get("reason", &"")) == &"prepared_product_slot_full", "shared tray rejects a ninth oil strip")

	session.call("clear_prepared_product_slots")
	for index in range(16):
		_check(bool(Dictionary(session.call("_append_prepared_product", &"slot.fryer_finished", _product(StringName("chicken.%d" % index), &"product.chicken.cutlet"))).get("success", false)), "shared tray accepts chicken portion %d" % (index + 1))
	_check(StringName(Dictionary(session.call("_append_prepared_product", &"slot.fryer_finished", _product(&"chicken.overflow", &"product.chicken.cutlet"))).get("reason", &"")) == &"prepared_product_slot_full", "shared tray rejects a seventeenth chicken portion")

	var migrated_progression := PROGRESSION.new({"owned_growth_ids": [&"growth.capacity.chicken_finished_tray"]})
	_check(migrated_progression.owns_growth(&"growth.capacity.youtiao_finished_tray") and not migrated_progression.owns_growth(&"growth.capacity.chicken_finished_tray"), "legacy chicken tray purchase migrates to the shared tray")
	var cleared_legacy_slots := Dictionary(session.call("_normalize_prepared_product_slots", {"slot.04": [_product(&"legacy.youtiao", &"product.youtiao.plain")], "slot.chicken": [_product(&"legacy.chicken", &"product.chicken.cutlet")]}))
	_check(Array(cleared_legacy_slots.get("slot.fryer_finished", [])).is_empty(), "legacy stored tray products are cleared during shared-tray migration")
	_finish()


func _product(instance_id: StringName, product_id: StringName) -> Dictionary:
	return {"product_instance_id": instance_id, "product_id": product_id, "quality_grade": &"A"}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("SHARED_FINISHED_TRAY_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		printerr("SHARED_FINISHED_TRAY_SELF_CHECK_FAIL: %s" % failure)
	quit(1)
