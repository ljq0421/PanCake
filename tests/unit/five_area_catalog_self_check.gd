extends SceneTree

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(CATALOG.validate_catalog().is_empty(), "catalog validation succeeds")
	_check(CATALOG.CARTOON_BREAKFAST_V1 and CATALOG.BALANCE_VERSION == 11, "cartoon breakfast rules have a distinct balance version")
	_check(CATALOG.GROWTH_DISPLAY_ORDER == [&"growth.area.youtiao", &"growth.area.fresh_soy_milk"], "growth workshop exposes only the two counter expansions")
	var youtiao := CATALOG.growth_definition(&"growth.area.youtiao")
	var drinks := CATALOG.growth_definition(&"growth.area.fresh_soy_milk")
	_check(int(youtiao.get("price", 0)) == 200 and Array(youtiao.get("requires_growth_ids", [])).is_empty(), "youtiao area costs 200 without topping prerequisites")
	_check(int(drinks.get("price", 0)) == 200 and Array(drinks.get("requires_growth_ids", [])).is_empty(), "drink area costs 200 without topping prerequisites")
	_check(Array(drinks.get("unlock_area_ids", [])).has(&"area.packaged_drink") and Array(drinks.get("unlock_product_ids", [])).has(&"product.packaged_drink.juice"), "drink purchase bundles soy and boxed juice")
	_check(CATALOG.growth_definition(&"growth.area.packaged_drink").is_empty(), "boxed juice is not a separate purchase")
	_check(CATALOG.growth_definition(&"growth.equipment.youtiao.advanced").is_empty() and CATALOG.growth_definition(&"growth.automation.fresh_soy_milk.auto_fill").is_empty(), "equipment upgrades and automation are absent from the active catalog")
	for stock_id in [
		&"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.scallion",
		&"stock.pancake.ham_sausage", &"stock.pancake.meat_floss", &"stock.pancake.sauce.sweet_flour",
		&"stock.youtiao.plain_dough", &"stock.packaged_drink.juice",
	]:
		_check(bool(CATALOG.stock_definition(stock_id).get("unlimited", false)), "%s is unlimited in v1" % stock_id)
	var fryer_tiers := Array(CATALOG.device_definition(&"device.youtiao_fryer").get("tiers", []))
	_check(not fryer_tiers.is_empty() and int(Dictionary(fryer_tiers[0]).get("capacity", 0)) == 4, "base fryer capacity is four")
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("FIVE_AREA_CATALOG_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("FIVE_AREA_CATALOG_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
