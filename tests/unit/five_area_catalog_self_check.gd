extends SceneTree

const CATALOG = preload("res://scripts/data/five_area_catalog.gd")
const CORE_PANCAKE_GROWTH_IDS: Array[StringName] = [
	&"growth.add_on.pancake.egg",
	&"growth.add_on.pancake.baocui",
	&"growth.add_on.pancake.scallion",
	&"growth.add_on.pancake.ham_sausage",
	&"growth.add_on.pancake.coriander",
	&"growth.add_on.pancake.meat_floss",
]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(CATALOG.validate_catalog().is_empty(), "catalog validation succeeds")
	_check(CATALOG.AREA_IDS == [&"area.pancake", &"area.youtiao", &"area.fresh_soy_milk", &"area.packaged_drink"], "four active areas are retained")
	_check(_growth_price(&"growth.add_on.pancake.egg") == 10, "egg costs 10 coins")
	_check(_growth_price(&"growth.add_on.pancake.baocui") == 30, "baocui costs 30 coins")
	_check(_growth_price(&"growth.add_on.pancake.scallion") == 50, "scallion costs 50 coins")
	_check(_growth_price(&"growth.add_on.pancake.meat_floss") == 80 and _requires(&"growth.add_on.pancake.meat_floss", &"growth.add_on.pancake.baocui"), "meat floss follows baocui")
	_check(_growth_price(&"growth.add_on.pancake.ham_sausage") == 80 and _requires(&"growth.add_on.pancake.ham_sausage", &"growth.add_on.pancake.meat_floss"), "ham follows meat floss")
	_check(_growth_price(&"growth.add_on.pancake.coriander") == 50 and _requires(&"growth.add_on.pancake.coriander", &"growth.add_on.pancake.scallion"), "coriander follows scallion")
	_check(_growth_price(&"growth.automation.pancake.one_click_egg") == 60 and _requires(&"growth.automation.pancake.one_click_egg", &"growth.add_on.pancake.egg"), "one-click egg follows egg")
	_check(_growth_price(&"growth.automation.pancake.auto_batter_ladle") == 120 and _growth_price(&"growth.automation.pancake.press_once") == 120, "remaining pancake automation uses the approved prices")
	_check(_growth_price(&"growth.automation.pancake.non_burning_griddle") == 180 and _requires(&"growth.automation.pancake.non_burning_griddle", &"growth.automation.pancake.auto_batter_ladle") and _requires(&"growth.automation.pancake.non_burning_griddle", &"growth.automation.pancake.press_once"), "non-burning griddle costs 180 and follows both pancake tools")
	_check(_growth_price(&"growth.automation.pancake.fast_cook_griddle") == 240 and _requires(&"growth.automation.pancake.fast_cook_griddle", &"growth.automation.pancake.non_burning_griddle"), "fast-cook griddle costs 240 and follows the non-burning griddle")
	_check(CATALOG.GROWTH_DISPLAY_ORDER.find(&"growth.automation.pancake.fast_cook_griddle") == CATALOG.GROWTH_DISPLAY_ORDER.find(&"growth.automation.pancake.non_burning_griddle") + 1, "fast-cook griddle directly follows the non-burning griddle")
	var first_pancake_holding_tray := CATALOG.growth_definition(&"growth.capacity.pancake_holding_tray.first_slot")
	_check(_growth_price(&"growth.capacity.pancake_holding_tray.first_slot") == 40 and str(first_pancake_holding_tray.get("label", "")) == "煎饼暂存盘" and StringName(first_pancake_holding_tray.get("requires_area_id", &"")) == &"area.pancake" and StringName(first_pancake_holding_tray.get("kind", &"")) == &"storage", "the single three-serving pancake holding tray is one 40-coin storage upgrade")
	_check(CATALOG.growth_definition(&"growth.capacity.pancake_holding_tray.second_slot").is_empty() and not CATALOG.GROWTH_DISPLAY_ORDER.has(&"growth.capacity.pancake_holding_tray.second_slot"), "the retired second holding-tray upgrade is absent from the active catalog")
	_check(CATALOG.growth_definition(&"growth.automation.pancake.auto_sauce_brush").is_empty(), "automatic sauce is baseline behavior instead of a purchasable growth")
	_check(_matches_area_unlock(&"growth.area.youtiao"), "youtiao unlock requires all six pancake ingredients")
	_check(_matches_area_unlock(&"growth.area.fresh_soy_milk"), "soy unlock requires all six pancake ingredients without requiring youtiao")
	_check(_growth_price(&"growth.area.youtiao") == 200 and _growth_price(&"growth.area.fresh_soy_milk") == 200, "parallel area unlocks cost 200 coins")
	_check(_growth_price(&"growth.equipment.youtiao.advanced") == 250 and _growth_price(&"growth.equipment.youtiao.dual_basket") == 350, "youtiao equipment uses the approved prices")
	_check(_growth_price(&"growth.automation.fresh_soy_milk.auto_fill") == 250 and _growth_price(&"growth.automation.fresh_soy_milk.advanced") == 350, "soy equipment uses the approved prices")
	var drink_rack := CATALOG.growth_definition(&"growth.area.packaged_drink")
	_check(_growth_price(&"growth.area.packaged_drink") == 200 and StringName(drink_rack.get("requires_area_id", &"")) == &"area.fresh_soy_milk", "drink rack follows soy and costs 200 coins")
	_check(CATALOG.pancake_order_price(CATALOG.pancake_order_template(&"order.pancake.no_egg_plain")) == 6, "plain pancake sale is 6 coins")
	_check(CATALOG.pancake_order_price(CATALOG.pancake_order_template(&"order.pancake.double_meat_floss")) == 42, "double meat-floss pancake sale is 42 coins")
	_check(int(CATALOG.product_definition(&"product.youtiao.plain").get("base_sell_price", 0)) == 9, "youtiao sale is tripled")
	_check(int(CATALOG.product_definition(&"product.chicken.cutlet").get("base_sell_price", 0)) == 24, "chicken sale is tripled")
	_check(CATALOG.soy_milk_sell_price(0) == 9 and CATALOG.soy_milk_sell_price(1) == 12, "soy milk sale is tripled")
	_check(int(CATALOG.product_definition(&"product.packaged_drink.juice").get("base_sell_price", 0)) == 9, "juice sale is tripled")
	_finish()


func _matches_area_unlock(growth_id: StringName) -> bool:
	var definition := CATALOG.growth_definition(growth_id)
	return StringName(definition.get("requires_area_id", &"")) == &"area.pancake" \
		and Array(definition.get("requires_growth_ids", [])) == CORE_PANCAKE_GROWTH_IDS


func _growth_price(growth_id: StringName) -> int:
	return int(CATALOG.growth_definition(growth_id).get("price", 0))


func _requires(growth_id: StringName, prerequisite_id: StringName) -> bool:
	return Array(CATALOG.growth_definition(growth_id).get("requires_growth_ids", [])).has(prerequisite_id)


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
