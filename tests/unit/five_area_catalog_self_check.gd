extends SceneTree

const CATALOG = preload("res://scripts/data/five_area_catalog.gd")
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check(CATALOG.validate_catalog().is_empty(), "catalog validation")
	_check(CATALOG.GROWTH_DEFINITIONS.size() == 41, "catalog contains exactly 41 stable growth definitions")
	var expected_primary_gates := {
		&"growth.tool.pancake.wide_spreader": "day:2",
		&"growth.add_on.pancake.red_chili": "reputation:10",
		&"growth.add_on.pancake.ham_sausage": "day:4",
		&"growth.equipment.pancake.intermediate": "mastery:area.pancake:a_grade:2",
		&"growth.add_on.pancake.meat_floss": "reputation:45",
		&"growth.capacity.pancake_holding_tray.two_slots": "day:8",
		&"growth.add_on.pancake.coriander": "day:8",
		&"growth.add_on.pancake.preserved_mustard": "reputation:100",
		&"growth.add_on.pancake.pork_tenderloin": "day:10",
		&"growth.automation.pancake.auto_sauce_brush": "mastery:area.pancake:a_grade:5",
		&"growth.equipment.pancake.advanced": "mastery:area.pancake:a_grade:10",
		&"growth.automation.pancake.press_once": "mastery:area.pancake:a_grade:20",
		&"growth.capacity.stock.intermediate": "reputation:80",
		&"growth.capacity.stock.advanced": "reputation:200",
		&"growth.area.packaged_drink": "mastery:area.pancake:qualified:6",
		&"growth.product.packaged_drink.soy_milk": "reputation:30",
		&"growth.equipment.packaged_drink.intermediate": "mastery:area.packaged_drink:correct_temperature:6",
		&"growth.product.packaged_drink.walnut": "day:11",
		&"growth.product.packaged_drink.black_sesame": "reputation:160",
		&"growth.equipment.packaged_drink.advanced": "mastery:area.packaged_drink:correct_streak_best:8",
		&"growth.area.youtiao": "reputation:60",
		&"growth.assist.youtiao.temperature_indicator": "reputation:70",
		&"growth.recipe.youtiao.oil_cake": "day:7",
		&"growth.equipment.youtiao.intermediate": "mastery:area.youtiao:qualified:6",
		&"growth.recipe.youtiao.sugar_oil_cake": "reputation:140",
		&"growth.automation.youtiao.auto_lift": "mastery:area.youtiao:a_grade:5",
		&"growth.equipment.youtiao.advanced": "mastery:area.youtiao:a_grade:8",
		&"growth.automation.youtiao.auto_load": "mastery:area.youtiao:a_grade:10",
		&"growth.area.fresh_soy_milk": "day:10",
		&"growth.recipe.fresh_soy_milk.black_bean": "day:10",
		&"growth.equipment.fresh_soy_milk.intermediate": "mastery:area.fresh_soy_milk:qualified:6",
		&"growth.recipe.fresh_soy_milk.red_bean": "reputation:150",
		&"growth.recipe.fresh_soy_milk.multigrain": "day:16",
		&"growth.automation.fresh_soy_milk.auto_water_start": "mastery:area.fresh_soy_milk:a_grade:5",
		&"growth.equipment.fresh_soy_milk.advanced": "mastery:area.fresh_soy_milk:a_grade:8",
		&"growth.automation.fresh_soy_milk.auto_cup_rack": "mastery:area.fresh_soy_milk:a_grade:10",
		&"growth.area.steamer": "mastery:area.fresh_soy_milk:qualified:4",
		&"growth.recipe.steamer.vegetable_bun": "day:15",
		&"growth.equipment.steamer.intermediate": "mastery:area.steamer:qualified:9",
		&"growth.recipe.steamer.meat_bun": "reputation:200",
		&"growth.equipment.steamer.advanced": "mastery:area.steamer:a_grade:8",
	}
	_check(expected_primary_gates.size() == 41, "growth gate baseline covers all 41 items")
	for growth_id in expected_primary_gates:
		_check(_primary_gate_signature(CATALOG.growth_definition(growth_id)) == expected_primary_gates[growth_id], "%s keeps its authored primary gate" % growth_id)
	for device_id in CATALOG.DEVICE_DEFINITIONS:
		for tier in range(3):
			_check(not CATALOG.device_tier(StringName(device_id), tier).is_empty(), "%s owns continuous tier %d" % [device_id, tier])
	_check(CATALOG.product_definition(&"product.packaged_drink.soy_milk") != CATALOG.product_definition(&"product.fresh_soy_milk.yellow_bean") and CATALOG.product_definition(&"product.packaged_drink.soy_milk").get("area_id") != CATALOG.product_definition(&"product.fresh_soy_milk.yellow_bean").get("area_id"), "packaged soy drink and fresh soy milk remain isolated products")
	_check(CATALOG.PHYSICAL_AREA_IDS == [&"area.fresh_soy_milk", &"area.youtiao", &"area.pancake", &"area.packaged_drink", &"area.steamer"], "physical area order")
	_check(CATALOG.UNLOCK_AREA_IDS == [&"area.pancake", &"area.packaged_drink", &"area.youtiao", &"area.fresh_soy_milk", &"area.steamer"], "unlock area order")
	var expected_slots := {
		1: &"stock.fresh_soy_milk.yellow_bean", 2: &"stock.fresh_soy_milk.black_bean", 3: &"stock.youtiao.plain_dough",
		7: &"stock.pancake.egg", 8: &"stock.pancake.baocui", 9: &"stock.pancake.scallion",
		16: &"stock.packaged_drink.milk", 17: &"stock.steamer.vegetable_bun", 18: &"stock.steamer.mantou",
	}
	for slot_index in range(1, 19):
		var slot := CATALOG.material_slot_definition(StringName("slot.%02d" % slot_index))
		if expected_slots.has(slot_index):
			_check(slot.get("kind") == &"stock" and slot.get("stock_id") == expected_slots[slot_index], "slot %02d stock ownership" % slot_index)
		elif CATALOG.PANCAKE_ADD_ON_SLOT_PRIORITY.has(StringName("slot.%02d" % slot_index)):
			_check(slot.get("kind") == &"dynamic_add_on", "slot %02d participates in dynamic pancake add-on priority" % slot_index)
		else:
			_check(slot.get("kind") == &"reserved", "slot %02d reserved ownership" % slot_index)
	_check(CATALOG.PANCAKE_ADD_ON_SLOT_PRIORITY == [&"slot.10", &"slot.11", &"slot.12", &"slot.06", &"slot.13", &"slot.05", &"slot.14"], "pancake add-on slot priority")
	_check(CATALOG.PANCAKE_ADD_ON_DISPLAY_ORDER == [&"stock.pancake.ham_sausage", &"stock.pancake.meat_floss", &"stock.pancake.coriander", &"stock.pancake.preserved_mustard", &"stock.pancake.pork_tenderloin"], "only later pancake add-ons use dynamic slot order")
	for stock_id in CATALOG.PANCAKE_ADD_ON_DISPLAY_ORDER:
		_check(CATALOG.stock_definition(stock_id).get("material_slot_id") == &"", "%s has no permanent material slot" % stock_id)
	for sauce_id in CATALOG.SAUCE_DEFINITIONS.keys():
		_check(CATALOG.stock_definition(sauce_id).get("material_slot_id") == &"", "%s does not occupy a material slot" % sauce_id)
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
