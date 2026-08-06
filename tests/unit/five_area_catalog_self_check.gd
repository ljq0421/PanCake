extends SceneTree

const CATALOG = preload("res://scripts/data/five_area_catalog.gd")
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check(CATALOG.validate_catalog().is_empty(), "catalog validation")
	_check(CATALOG.PHYSICAL_AREA_IDS == [&"area.fresh_soy_milk", &"area.youtiao", &"area.pancake", &"area.packaged_drink", &"area.steamer"], "physical area order")
	_check(CATALOG.UNLOCK_AREA_IDS == [&"area.pancake", &"area.packaged_drink", &"area.youtiao", &"area.fresh_soy_milk", &"area.steamer"], "unlock area order")
	var expected_slots := {
		1: &"stock.fresh_soy_milk.yellow_bean", 2: &"stock.fresh_soy_milk.black_bean", 3: &"stock.youtiao.plain_dough",
		4: &"stock.pancake.meat_floss", 5: &"stock.pancake.ham_sausage", 6: &"stock.pancake.coriander",
		7: &"stock.pancake.egg", 8: &"stock.pancake.baocui", 9: &"stock.pancake.scallion", 10: &"stock.pancake.pork_tenderloin",
		16: &"stock.packaged_drink.milk", 17: &"stock.steamer.vegetable_bun", 18: &"stock.steamer.mantou",
	}
	for slot_index in range(1, 19):
		var slot := CATALOG.material_slot_definition(StringName("slot.%02d" % slot_index))
		if expected_slots.has(slot_index):
			_check(slot.get("kind") == &"stock" and slot.get("stock_id") == expected_slots[slot_index], "slot %02d stock ownership" % slot_index)
		else:
			_check(slot.get("kind") == &"reserved", "slot %02d reserved ownership" % slot_index)
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
