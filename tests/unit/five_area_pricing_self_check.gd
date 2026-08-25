extends SceneTree

const CATALOG = preload("res://scripts/data/five_area_catalog.gd")


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
	_check(CATALOG.validate_catalog().is_empty(), "catalog price rules validate", failures)
	if failures.is_empty():
		print("FIVE_AREA_PRICING_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("FIVE_AREA_PRICING_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)


func _payment(template_id: StringName) -> int:
	return int(CATALOG.pancake_order_template(template_id).get("payment_coins", 0))


func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
