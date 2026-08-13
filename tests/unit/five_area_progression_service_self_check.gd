extends SceneTree

const SERVICE := preload("res://scripts/services/five_area_progression_service.gd")
const CATALOG := preload("res://scripts/data/five_area_catalog.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var starter := SERVICE.new()
	_check(starter.owns_area(&"area.pancake") and not starter.owns_area(&"area.youtiao") and not starter.owns_area(&"area.fresh_soy_milk"), "new game starts with only pancake area")
	_check(starter.device_tier(&"device.pancake_griddle") == 0, "new game starts with one griddle")
	var starter_tutorial := starter.tutorial_snapshot()
	_check(StringName(starter_tutorial.get("active_id", &"")) == &"area.pancake", "pancake is the first tutorial")
	var route_ids := PackedStringArray(CATALOG.growth_ids())
	_check(route_ids.size() == 26, "growth route exposes only twenty-six three-area upgrades")
	for retired_growth in [&"growth.area.packaged_drink", &"growth.area.steamer", &"growth.equipment.packaged_drink.advanced"]:
		_check(not route_ids.has(str(retired_growth)), "%s is absent from active growth" % retired_growth)
	var early := SERVICE.new({
		"coins": 200,
		"reputation": 30,
		"current_day": 4,
		"unlocked_area_ids": [&"area.pancake"],
		"area_mastery_details": {&"area.pancake": {"qualified": 6, "a_grade": 4}},
		"tutorial": {"completed_area_ids": [&"area.pancake"], "queue_area_ids": [], "active_kind": &"", "active_id": &""},
	})
	var early_cards: Array = Array(early.growth_recommendations(4).get("recommended", []))
	_check(_growth_ids(early_cards) == [&"growth.tool.pancake.wide_spreader", &"growth.add_on.pancake.red_chili", &"growth.add_on.pancake.ham_sausage", &"growth.area.youtiao"], "early route leads from pancake improvements into youtiao")
	var youtiao_purchase := Dictionary(early.purchase(&"growth.area.youtiao"))
	_check(bool(youtiao_purchase.get("success", false)) and early.pending_install_purchase == &"growth.area.youtiao", "qualified pancake play can reserve youtiao unlock")
	early.set_day_open(false)
	var youtiao_activation := Dictionary(early.begin_next_business_day())
	_check(bool(youtiao_activation.get("success", false)) and early.owns_area(&"area.youtiao"), "youtiao unlock activates next business day")
	early.advance_tutorial_for_new_business_day()
	_check(StringName(early.tutorial_snapshot().get("active_id", &"")) == &"area.youtiao", "youtiao tutorial follows pancake")
	var dual := SERVICE.new({
		"coins": 100,
		"current_day": 5,
		"unlocked_area_ids": [&"area.pancake"],
		"area_mastery_details": {&"area.pancake": {"qualified": 8, "a_grade": 4}},
		"tutorial": {"completed_area_ids": [&"area.pancake"], "queue_area_ids": [], "active_kind": &"", "active_id": &""},
	})
	_check(bool(dual.purchase(&"growth.equipment.pancake.intermediate").get("success", false)), "four A-grade pancakes can reserve the second griddle")
	dual.set_day_open(false)
	dual.begin_next_business_day()
	_check(dual.device_tier(&"device.pancake_griddle") == 1, "intermediate upgrade activates two-griddle tier")
	var triple := SERVICE.new({
		"coins": 200,
		"current_day": 20,
		"reputation": 300,
		"unlocked_area_ids": [&"area.pancake", &"area.youtiao", &"area.fresh_soy_milk"],
		"device_tiers": {&"device.pancake_griddle": 1, &"device.youtiao_fryer": 0, &"device.fresh_soy_milk_machine": 0},
		"area_mastery_details": {&"area.pancake": {"qualified": 20, "a_grade": 12}},
		"tutorial": {"completed_area_ids": [&"area.pancake", &"area.youtiao", &"area.fresh_soy_milk"], "queue_area_ids": [], "active_kind": &"", "active_id": &""},
	})
	_check(bool(triple.purchase(&"growth.equipment.pancake.advanced").get("success", false)), "all three areas and twelve A grades can reserve third griddle")
	triple.set_day_open(false)
	triple.begin_next_business_day()
	_check(triple.device_tier(&"device.pancake_griddle") == 2, "advanced upgrade activates three-griddle tier")
	var soy_gate := SERVICE.new({
		"coins": 100,
		"current_day": 7,
		"reputation": 60,
		"unlocked_area_ids": [&"area.pancake", &"area.youtiao"],
		"device_tiers": {&"device.pancake_griddle": 0, &"device.youtiao_fryer": 0},
		"area_mastery_details": {&"area.youtiao": {"qualified": 4, "a_grade": 0}},
		"tutorial": {"completed_area_ids": [&"area.pancake", &"area.youtiao"], "queue_area_ids": [], "active_kind": &"", "active_id": &""},
	})
	_check(bool(soy_gate.purchase(&"growth.area.fresh_soy_milk").get("success", false)), "soy unlock follows four qualified youtiao orders")
	soy_gate.set_day_open(false)
	soy_gate.begin_next_business_day()
	soy_gate.advance_tutorial_for_new_business_day()
	_check(soy_gate.owns_area(&"area.fresh_soy_milk") and StringName(soy_gate.tutorial_snapshot().get("active_id", &"")) == &"area.fresh_soy_milk", "soy is the third and final area tutorial")
	var legacy := SERVICE.new({
		"coins": 77,
		"unlocked_area_ids": [&"area.pancake", &"area.packaged_drink", &"area.youtiao", &"area.fresh_soy_milk", &"area.steamer"],
		"device_tiers": {&"device.pancake_griddle": 9, &"device.packaged_drink_heater": 2, &"device.youtiao_fryer": 1, &"device.fresh_soy_milk_machine": 1, &"device.steamer": 2},
		"unlocked_stock_ids": [&"stock.pancake.batter", &"stock.packaged_drink.milk", &"stock.steamer.mantou", &"stock.youtiao.plain_dough"],
		"owned_growth_ids": [&"growth.area.packaged_drink", &"growth.area.youtiao", &"growth.area.steamer"],
		"tutorial": {"completed_area_ids": [&"area.pancake", &"area.packaged_drink"], "queue_area_ids": [&"area.steamer"], "active_kind": &"area", "active_id": &"area.steamer"},
	})
	var legacy_snapshot := legacy.snapshot()
	_check(PackedStringArray(legacy_snapshot.get("unlocked_area_ids", [])) == PackedStringArray(["area.pancake", "area.youtiao", "area.fresh_soy_milk"]), "legacy save strips retired areas while preserving active ones")
	_check(not legacy.owns_device(&"device.packaged_drink_heater") and not legacy.owns_device(&"device.steamer"), "legacy save strips retired devices")
	_check(not legacy.owns_stock(&"stock.packaged_drink.milk") and not legacy.owns_stock(&"stock.steamer.mantou"), "legacy save strips retired stock")
	_check(legacy.device_tier(&"device.pancake_griddle") == 2, "legacy griddle tier clamps to the three-griddle maximum")
	_check(StringName(legacy.tutorial_snapshot().get("active_id", &"")) == &"", "retired active tutorial is cleared")
	_check(legacy.coins == 77, "legacy normalization preserves economy")
	_finish()


func _growth_ids(entries: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in entries:
		result.append(StringName(Dictionary(value).get("growth_id", &"")))
	return result


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("THREE_AREA_PROGRESSION_SERVICE_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("THREE_AREA_PROGRESSION_SERVICE_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
