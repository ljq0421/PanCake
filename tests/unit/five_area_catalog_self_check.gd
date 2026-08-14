extends SceneTree

const CATALOG = preload("res://scripts/data/five_area_catalog.gd")
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog_errors := CATALOG.validate_catalog()
	_check(catalog_errors.is_empty(), "catalog validation: %s" % ", ".join(catalog_errors))
	_check(CATALOG.AREA_IDS == [&"area.pancake", &"area.youtiao", &"area.fresh_soy_milk"], "only pancake, youtiao and fresh soy remain active")
	_check(CATALOG.growth_ids().size() == 29, "three-area growth route contains 29 active upgrades after retiring two fryer recipes")
	for growth_id in CATALOG.growth_ids():
		var definition := CATALOG.growth_definition(growth_id)
		_check(CATALOG.AREA_IDS.has(StringName(definition.get("requires_area_id", &""))), "%s belongs to an active area" % growth_id)
	_check(_primary_gate_signature(CATALOG.growth_definition(&"growth.equipment.pancake.intermediate")) == "mastery:area.pancake:a_grade:4", "second griddle requires four A-grade pancakes")
	_check(_primary_gate_signature(CATALOG.growth_definition(&"growth.equipment.pancake.advanced")) == "mastery:area.pancake:a_grade:12", "third griddle requires twelve A-grade pancakes")
	_check(_primary_gate_signature(CATALOG.growth_definition(&"growth.area.youtiao")) == "reputation:20,mastery:area.pancake:qualified:6", "youtiao unlock follows pancake mastery")
	_check(_primary_gate_signature(CATALOG.growth_definition(&"growth.area.fresh_soy_milk")) == "day:7,reputation:60,mastery:area.youtiao:qualified:4", "soy unlock follows youtiao mastery")
	for area_id in CATALOG.AREA_IDS:
		var device_id := StringName(CATALOG.area_definition(area_id).get("device_id", &""))
		for tier in range(3):
			_check(not CATALOG.device_tier(StringName(device_id), tier).is_empty(), "%s owns continuous tier %d" % [device_id, tier])
	_check(int(CATALOG.device_tier(&"device.pancake_griddle", 0).get("griddle_count", 0)) == 1, "basic pancake station has one griddle")
	_check(int(CATALOG.device_tier(&"device.pancake_griddle", 1).get("griddle_count", 0)) == 2, "intermediate pancake station has two griddles")
	_check(int(CATALOG.device_tier(&"device.pancake_griddle", 2).get("griddle_count", 0)) == 3, "advanced pancake station has three griddles")
	for youtiao_tier in [{"tier": 0, "capacity": 4, "duration": 10.0}, {"tier": 1, "capacity": 6, "duration": 8.0}, {"tier": 2, "capacity": 8, "duration": 6.0}]:
		var definition := CATALOG.device_tier(&"device.youtiao_fryer", int(youtiao_tier["tier"]))
		_check(int(definition.get("capacity", 0)) == int(youtiao_tier["capacity"]) and is_equal_approx(float(definition.get("duration_seconds", 0.0)), float(youtiao_tier["duration"])), "youtiao tier %d uses its 4/6/8 and 10/8/6 contract" % int(youtiao_tier["tier"]))
	_check(CATALOG.PHYSICAL_AREA_IDS == [&"area.fresh_soy_milk", &"area.pancake", &"area.youtiao"], "physical area order")
	_check(CATALOG.UNLOCK_AREA_IDS == [&"area.pancake", &"area.youtiao", &"area.fresh_soy_milk"], "unlock area order")
	for stock_id in CATALOG.stock_ids():
		_check(CATALOG.AREA_IDS.has(StringName(CATALOG.stock_definition(stock_id).get("area_id", &""))), "%s belongs to an active area" % stock_id)
	var expected_slots := {
		1: &"stock.fresh_soy_milk.yellow_bean", 2: &"stock.fresh_soy_milk.black_bean", 3: &"stock.fresh_soy_milk.red_bean",
		4: &"stock.youtiao.plain_dough",
		7: &"stock.pancake.egg", 8: &"stock.pancake.baocui", 9: &"stock.pancake.scallion",
	}
	for slot_index in range(1, 16):
		var slot := CATALOG.material_slot_definition(StringName("slot.%02d" % slot_index))
		if expected_slots.has(slot_index):
			_check(slot.get("kind") == &"stock" and slot.get("stock_id") == expected_slots[slot_index], "slot %02d stock ownership" % slot_index)
		elif slot_index in [5, 6]:
			_check(slot.is_empty(), "retired youtiao slot %02d has no active definition" % slot_index)
		elif CATALOG.PANCAKE_ADD_ON_SLOT_PRIORITY.has(StringName("slot.%02d" % slot_index)):
			_check(slot.get("kind") == &"dynamic_add_on", "slot %02d participates in dynamic pancake add-on priority" % slot_index)
		else:
			_check(slot.get("kind") == &"reserved", "slot %02d reserved ownership" % slot_index)
	_check(CATALOG.PANCAKE_ADD_ON_SLOT_PRIORITY == [&"slot.10", &"slot.11", &"slot.12", &"slot.13", &"slot.14"], "pancake add-on slot priority")
	_check(CATALOG.stock_definition(&"stock.pancake.youtiao").get("category") == &"prepared_add_on" and int(CATALOG.stock_definition(&"stock.pancake.youtiao").get("restock_capacity", -1)) == 0, "pancake youtiao remains a non-restockable processed ingredient")
	_check(CATALOG.PANCAKE_ADD_ON_DISPLAY_ORDER == [&"stock.pancake.ham_sausage", &"stock.pancake.meat_floss", &"stock.pancake.coriander", &"stock.pancake.preserved_mustard", &"stock.pancake.pork_tenderloin"], "only later pancake add-ons use dynamic slot order")
	for stock_id in CATALOG.PANCAKE_ADD_ON_DISPLAY_ORDER:
		_check(CATALOG.stock_definition(stock_id).get("material_slot_id") == &"", "%s has no permanent material slot" % stock_id)
	for sauce_id in CATALOG.SAUCE_DEFINITIONS.keys():
		_check(CATALOG.stock_definition(sauce_id).get("material_slot_id") == &"", "%s does not occupy a material slot" % sauce_id)
	for stock_id in [&"stock.youtiao.plain_dough"]:
		_check(is_equal_approx(float(CATALOG.stock_definition(stock_id).get("refill_seconds", 0.0)), 0.25), "%s restocks at the confirmed pancake-ingredient speed" % stock_id)
	_check(CATALOG.recipe_definition(&"recipe.youtiao.oil_cake").is_empty() and CATALOG.recipe_definition(&"recipe.youtiao.sugar_oil_cake").is_empty(), "retired fryer recipes are absent")
	_check(CATALOG.product_definition(&"product.youtiao.oil_cake").is_empty() and CATALOG.product_definition(&"product.youtiao.sugar_oil_cake").is_empty(), "retired fryer products are absent")
	for stock_id in [&"stock.fresh_soy_milk.yellow_bean", &"stock.fresh_soy_milk.black_bean", &"stock.fresh_soy_milk.red_bean"]:
		_check(is_equal_approx(float(CATALOG.stock_definition(stock_id).get("refill_seconds", 0.0)), 0.25), "%s restocks at the pancake-ingredient speed" % stock_id)
	_check(CATALOG.stock_definition(&"stock.fresh_soy_milk.multigrain").is_empty() and Array(CATALOG.recipe_definition(&"recipe.fresh_soy_milk.multigrain").get("stock_ids", [])).is_empty(), "multigrain remains a product recipe without an independent stock")
	var copy := CATALOG.stock_definition(&"stock.pancake.egg")
	copy["material_slot_id"] = &"slot.invalid"
	_check(CATALOG.stock_definition(&"stock.pancake.egg").get("material_slot_id") == &"slot.07", "catalog queries return deep copies")
	if _failures.is_empty():
		print("FIVE_AREA_CATALOG_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("FIVE_AREA_CATALOG_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _primary_gate_signature(definition: Dictionary) -> String:
	var gates: Array[String] = []
	if definition.has("min_day"):
		gates.append("day:%d" % int(definition.get("min_day", 0)))
	if definition.has("min_reputation"):
		gates.append("reputation:%d" % int(definition.get("min_reputation", 0)))
	for area_id_variant in Dictionary(definition.get("requires_mastery", {})):
		var area_id := StringName(area_id_variant)
		for metric_variant in Dictionary(definition.get("requires_mastery", {})).get(area_id, {}):
			var metric := StringName(metric_variant)
			gates.append("mastery:%s:%s:%d" % [area_id, metric, int(Dictionary(definition.get("requires_mastery", {})).get(area_id, {}).get(metric, 0))])
	return ",".join(gates)
