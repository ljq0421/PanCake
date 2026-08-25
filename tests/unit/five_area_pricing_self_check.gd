extends SceneTree

const CATALOG = preload("res://scripts/data/five_area_catalog.gd")
const ORDER_GENERATOR = preload("res://scripts/services/five_area_playable_order_generator.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	_check(CATALOG.PANCAKE_BASE_SELL_PRICE == 2, "plain pancake costs 2", failures)
	_check(CATALOG.PANCAKE_ADD_ON_SELL_PRICES == {
		&"stock.pancake.egg": 2,
		&"stock.pancake.baocui": 1,
		&"stock.pancake.scallion": 1,
		&"stock.pancake.coriander": 1,
		&"stock.pancake.ham_sausage": 4,
		&"stock.pancake.meat_floss": 4,
		&"stock.pancake.youtiao": 3,
	}, "pancake add-on prices match the approved list", failures)
	_check(_payment(&"order.pancake.no_egg_secret") == 2, "secret sauce is free", failures)
	_check(_payment(&"order.pancake.classic") == 6, "egg, baocui, and scallion pancake costs 6", failures)
	_check(_payment(&"order.pancake.chili_ham") == 9, "egg, baocui, and ham pancake costs 9", failures)
	_check(_payment(&"order.pancake.meat_floss_sweet") == 10, "meat floss pancake costs 10", failures)
	_check(_payment(&"order.pancake.youtiao_scallion") == 8, "youtiao pancake costs 8", failures)
	_check(int(CATALOG.product_definition(&"product.youtiao.plain").get("base_sell_price", 0)) == 3, "plain youtiao costs 3", failures)
	_check(int(CATALOG.product_definition(&"product.youtiao.sesame").get("base_sell_price", 0)) == 4, "sesame youtiao costs 4", failures)
	_check(int(CATALOG.product_definition(&"product.fresh_soy_milk.yellow_bean").get("base_sell_price", 0)) == 3, "soy milk costs 3", failures)
	_check(CATALOG.soy_milk_sell_price(0, &"room_temperature") == 3, "plain soy milk costs 3", failures)
	_check(CATALOG.soy_milk_sell_price(1, &"room_temperature") == 4, "sugared soy milk costs 4", failures)
	_check(CATALOG.soy_milk_sell_price(2, &"room_temperature") == 4, "two-sugar soy milk still costs 4", failures)
	_check(CATALOG.soy_milk_sell_price(0, &"iced") == 4, "iced soy milk costs 4", failures)
	_check(CATALOG.soy_milk_sell_price(1, &"iced") == 5, "sugared iced soy milk costs 5", failures)
	_check(_soy_order_price(1, &"room_temperature") == 4, "generator prices sugared soy milk at 4", failures)
	_check(_soy_order_price(2, &"room_temperature") == 4, "generator prices two-sugar soy milk at 4", failures)
	_check(_soy_order_price(0, &"iced") == 4, "generator prices iced soy milk at 4", failures)
	_check(_soy_order_price(1, &"iced") == 5, "generator prices sugared iced soy milk at 5", failures)
	_check(CATALOG.validate_catalog().is_empty(), "catalog price rules validate", failures)
	if failures.is_empty():
		print("FIVE_AREA_PRICING_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("FIVE_AREA_PRICING_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)


func _payment(template_id: StringName) -> int:
	return int(CATALOG.pancake_order_template(template_id).get("payment_coins", 0))


func _soy_order_price(sugar_servings: int, temperature_mode: StringName) -> int:
	return int(ORDER_GENERATOR._product_item_unit_price({
		"product_id": &"product.fresh_soy_milk.yellow_bean",
		"sugar_servings": sugar_servings,
		"temperature_mode": temperature_mode,
	}))


func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
