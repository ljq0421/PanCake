extends SceneTree

const SERVICE := preload("res://scripts/services/five_area_progression_service.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var starter := SERVICE.new()
	_check(starter.owns_area(&"area.pancake") and not starter.owns_area(&"area.youtiao") and not starter.owns_area(&"area.fresh_soy_milk"), "day one opens only the pancake counter")
	for stock_id in [
		&"stock.pancake.batter", &"stock.pancake.egg", &"stock.pancake.baocui",
		&"stock.pancake.scallion", &"stock.pancake.ham_sausage", &"stock.pancake.meat_floss",
		&"stock.pancake.sauce.sweet_flour",
	]:
		_check(starter.owns_stock(stock_id), "%s is available from day one" % stock_id)
	_check(not starter.owns_stock(&"stock.pancake.coriander"), "coriander is excluded")

	var growth := SERVICE.new({"coins": 400})
	_check(bool(growth.purchase_status(&"growth.area.youtiao").get("can_purchase", false)), "youtiao can be purchased without topping or mastery gates")
	_check(bool(growth.purchase_status(&"growth.area.fresh_soy_milk").get("can_purchase", false)), "drinks can be purchased independently")
	_check(bool(growth.purchase(&"growth.area.fresh_soy_milk").get("success", false)), "drink expansion can be reserved")
	_check(StringName(growth.purchase_status(&"growth.area.youtiao").get("reason", &"")) == &"daily_purchase_limit", "only one expansion can be pending per day")
	_check(not growth.owns_area(&"area.fresh_soy_milk") and not growth.owns_area(&"area.packaged_drink"), "purchase remains pending during the current day")
	growth.set_day_open(false)
	_check(bool(growth.begin_next_business_day().get("success", false)), "next day activates the pending expansion")
	_check(growth.owns_area(&"area.fresh_soy_milk") and growth.owns_area(&"area.packaged_drink"), "drink activation opens soy and boxed juice together")
	_check(growth.owns_product(&"product.fresh_soy_milk.yellow_bean") and growth.owns_product(&"product.packaged_drink.juice"), "drink activation unlocks both products")
	_check(growth.device_tier(&"device.fresh_soy_milk_machine") == 0 and growth.device_tier(&"device.packaged_drink_rack") == 0, "drink equipment stays at base tier")
	_check(bool(growth.purchase(&"growth.area.youtiao").get("success", false)), "the other expansion can be reserved on the next day")
	growth.set_day_open(false)
	growth.begin_next_business_day()
	_check(growth.owns_area(&"area.youtiao") and growth.device_tier(&"device.youtiao_fryer") == 0, "youtiao activates at base tier")
	_check(StringName(growth.purchase_status(&"growth.equipment.youtiao.advanced").get("reason", &"")) == &"unknown_growth", "retired upgrades cannot be purchased")
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("FIVE_AREA_PROGRESSION_SERVICE_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("FIVE_AREA_PROGRESSION_SERVICE_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
