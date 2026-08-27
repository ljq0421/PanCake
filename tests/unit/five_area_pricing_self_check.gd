extends SceneTree

const CATALOG = preload("res://scripts/data/five_area_catalog.gd")
const ORDER_GENERATOR = preload("res://scripts/services/five_area_playable_order_generator.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	_check(CATALOG.PANCAKE_BASE_SELL_PRICE == 6, "plain pancake costs 6", failures)
	_check(CATALOG.PANCAKE_ADD_ON_SELL_PRICES == {
		&"stock.pancake.egg": 6,
		&"stock.pancake.baocui": 3,
		&"stock.pancake.scallion": 3,
		&"stock.pancake.coriander": 3,
		&"stock.pancake.ham_sausage": 12,
		&"stock.pancake.meat_floss": 12,
		&"stock.pancake.youtiao": 9,
	}, "pancake add-on prices match the approved list", failures)
	_check(_payment(&"order.pancake.no_egg_secret") == 6, "secret sauce remains free", failures)
	_check(_payment(&"order.pancake.classic") == 18, "egg, baocui, and scallion pancake costs 18", failures)
	_check(_payment(&"order.pancake.chili_ham") == 27, "egg, baocui, and ham pancake costs 27", failures)
	_check(_payment(&"order.pancake.meat_floss_sweet") == 30, "meat floss pancake costs 30", failures)
	_check(_payment(&"order.pancake.youtiao_scallion") == 24, "youtiao pancake costs 24", failures)
	_check(int(CATALOG.product_definition(&"product.youtiao.plain").get("base_sell_price", 0)) == 9, "plain youtiao costs 9", failures)
	_check(CATALOG.product_definition(&"product.youtiao.sesame").is_empty(), "retired sesame youtiao has no sell price", failures)
	_check(int(CATALOG.product_definition(&"product.fresh_soy_milk.yellow_bean").get("base_sell_price", 0)) == 9, "soy milk costs 9", failures)
	_check(CATALOG.soy_milk_sell_price(0, &"room_temperature") == 9, "plain soy milk costs 9", failures)
	_check(CATALOG.soy_milk_sell_price(1, &"room_temperature") == 12, "sugared soy milk costs 12", failures)
	_check(CATALOG.soy_milk_sell_price(2, &"room_temperature") == 12, "two-sugar soy milk still costs 12", failures)
	_check(_soy_order_price(1, &"room_temperature") == 12, "generator prices sugared soy milk at 12", failures)
	_check(_soy_order_price(2, &"room_temperature") == 12, "generator prices two-sugar soy milk at 12", failures)
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
