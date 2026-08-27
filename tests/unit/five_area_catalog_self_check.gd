extends SceneTree

const CATALOG = preload("res://scripts/data/five_area_catalog.gd")
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog_errors := CATALOG.validate_catalog()
	_check(catalog_errors.is_empty(), "catalog validation: %s" % ", ".join(catalog_errors))
	_check(CATALOG.AREA_IDS == [&"area.pancake", &"area.youtiao", &"area.fresh_soy_milk"], "only pancake, youtiao and fresh soy remain active")
	_check(CATALOG.growth_ids().size() == 25, "growth route includes the six independent one-click pancake ingredient upgrades")
	var sweet_flour_unlock := CATALOG.growth_definition(&"growth.add_on.pancake.sweet_flour")
	var baocui_unlock := CATALOG.growth_definition(&"growth.add_on.pancake.baocui")
	var scallion_unlock := CATALOG.growth_definition(&"growth.add_on.pancake.scallion")
	_check(int(sweet_flour_unlock.get("price", 0)) == 6 and int(Dictionary(sweet_flour_unlock.get("requires_mastery", {})).get(&"area.pancake", {}).get("qualified", 0)) == 2, "sweet-flour sauce unlock follows two qualified pancakes")
	_check(int(baocui_unlock.get("price", 0)) == 8 and int(Dictionary(baocui_unlock.get("requires_mastery", {})).get(&"area.pancake", {}).get("qualified", 0)) == 4 and Array(baocui_unlock.get("requires_growth_ids", [])).is_empty(), "baocui unlock requires four qualified pancakes with no ingredient prerequisite")
	_check(int(scallion_unlock.get("price", 0)) == 8 and int(Dictionary(scallion_unlock.get("requires_mastery", {})).get(&"area.pancake", {}).get("qualified", 0)) == 6 and Array(scallion_unlock.get("requires_growth_ids", [])).is_empty(), "scallion unlock requires six qualified pancakes with no ingredient prerequisite")
	for growth_id in CATALOG.growth_ids():
		var definition := CATALOG.growth_definition(growth_id)
		_check(CATALOG.AREA_IDS.has(StringName(definition.get("requires_area_id", &""))), "%s belongs to an active area" % growth_id)
	_check(_primary_gate_signature(CATALOG.growth_definition(&"growth.area.youtiao")) == "reputation:20,mastery:area.pancake:qualified:6", "youtiao unlock follows pancake mastery")
	var youtiao_tray := CATALOG.growth_definition(&"growth.capacity.youtiao_finished_tray")
	_check(youtiao_tray.get("label") == "油条成品盘" and int(youtiao_tray.get("price", 0)) == 12 and Array(youtiao_tray.get("requires_growth_ids", [])).has(&"growth.area.youtiao"), "finished youtiao tray is a 12-coin purchase after the fryer")
	_check(_primary_gate_signature(CATALOG.growth_definition(&"growth.area.fresh_soy_milk")) == "day:7,reputation:60,mastery:area.youtiao:qualified:4", "soy unlock follows youtiao mastery")
	for area_id in CATALOG.AREA_IDS:
		var device_id := StringName(CATALOG.area_definition(area_id).get("device_id", &""))
		var tier_count := 3 if device_id == &"device.fresh_soy_milk_machine" else 1
		for tier in range(tier_count):
			_check(not CATALOG.device_tier(StringName(device_id), tier).is_empty(), "%s owns continuous tier %d" % [device_id, tier])
	_check(int(CATALOG.device_tier(&"device.pancake_griddle", 0).get("griddle_count", 0)) == 1, "basic pancake station has one griddle")
	_check(CATALOG.device_tier(&"device.pancake_griddle", 1).is_empty() and CATALOG.growth_definition(&"growth.equipment.pancake.intermediate").is_empty(), "pancake capacity expansion is absent from catalog")
	var youtiao_definition := CATALOG.device_tier(&"device.youtiao_fryer", 0)
	_check(int(youtiao_definition.get("capacity", 0)) == 4 and is_equal_approx(float(youtiao_definition.get("duration_seconds", 0.0)), 10.0), "youtiao fryer remains fixed at four slots and ten seconds")
	_check(CATALOG.device_tier(&"device.youtiao_fryer", 1).is_empty() and CATALOG.growth_definition(&"growth.equipment.youtiao.intermediate").is_empty() and CATALOG.growth_definition(&"growth.equipment.youtiao.advanced").is_empty(), "youtiao capacity upgrades are absent from catalog")
	_check(CATALOG.PHYSICAL_AREA_IDS == [&"area.fresh_soy_milk", &"area.pancake", &"area.youtiao"], "physical area order")
	_check(CATALOG.UNLOCK_AREA_IDS == [&"area.pancake", &"area.youtiao", &"area.fresh_soy_milk"], "unlock area order")
	for stock_id in CATALOG.stock_ids():
		_check(CATALOG.AREA_IDS.has(StringName(CATALOG.stock_definition(stock_id).get("area_id", &""))), "%s belongs to an active area" % stock_id)
	var expected_slots := {
		4: &"stock.youtiao.plain_dough",
		7: &"stock.pancake.egg", 8: &"stock.pancake.baocui", 9: &"stock.pancake.scallion",
	}
	for slot_index in range(1, 16):
		var slot := CATALOG.material_slot_definition(StringName("slot.%02d" % slot_index))
		if expected_slots.has(slot_index):
			_check(slot.get("kind") == &"stock" and slot.get("stock_id") == expected_slots[slot_index], "slot %02d stock ownership" % slot_index)
		elif slot_index in [1, 2, 3]:
			_check(slot.get("kind") == &"reserved", "retired soy slot %02d remains reserved" % slot_index)
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
	_check(Array(CATALOG.recipe_definition(&"recipe.fresh_soy_milk.yellow_bean").get("stock_ids", [])).is_empty(), "yellow soy is ready-made and never creates bean inventory")
	for retired_id in [
		&"recipe.youtiao.sesame", &"product.youtiao.sesame", &"growth.flavor.youtiao.sesame",
		&"recipe.youtiao.sugar", &"product.youtiao.sugar", &"growth.flavor.youtiao.sugar", &"growth.assist.youtiao.temperature_indicator",
		&"recipe.fresh_soy_milk.black_bean", &"product.fresh_soy_milk.black_bean", &"growth.flavor.fresh_soy_milk.black_bean",
		&"recipe.fresh_soy_milk.red_bean", &"product.fresh_soy_milk.red_bean", &"growth.flavor.fresh_soy_milk.red_bean",
	]:
		_check(CATALOG.recipe_definition(retired_id).is_empty() and CATALOG.product_definition(retired_id).is_empty() and CATALOG.growth_definition(retired_id).is_empty(), "%s is absent from the active catalog" % retired_id)
	_check(CATALOG.growth_definition(&"growth.area.fresh_soy_milk").get("label") == "初级豆浆机", "the first soy unlock is named the basic soy machine")
	_check(CATALOG.growth_definition(&"growth.automation.fresh_soy_milk.auto_fill").get("label") == "中级豆浆机", "the second soy unlock is named the intermediate soy machine")
	_check(CATALOG.growth_definition(&"growth.automation.fresh_soy_milk.advanced").get("label") == "高级豆浆机", "the final soy unlock is named the advanced soy machine")
	var batter_ladle := CATALOG.growth_definition(&"growth.automation.pancake.auto_batter_ladle")
	_check(batter_ladle.get("label") == "定量面糊勺" and int(batter_ladle.get("price", 0)) == 20, "batter-ladle upgrade uses the approved name and price")
	_check(int(Dictionary(batter_ladle.get("requires_mastery", {})).get(&"area.pancake", {}).get("a_grade", 0)) == 3, "batter-ladle upgrade unlocks after three A-grade pancakes")
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
