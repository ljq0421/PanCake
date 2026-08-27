extends SceneTree

const SERVICE = preload("res://scripts/services/five_area_progression_service.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var starter := SERVICE.new({"coins": 10})
	_check(starter.owns_area(&"area.pancake") and not starter.owns_stock(&"stock.pancake.egg"), "new game starts with pancake only and no egg")
	_check(bool(starter.purchase(&"growth.add_on.pancake.egg").get("success", false)), "egg can be reserved with 10 coins without completing tutorial")
	starter.set_day_open(false)
	_check(bool(starter.begin_next_business_day().get("success", false)) and starter.owns_stock(&"stock.pancake.egg"), "egg activates on the next business day")

	var all_toppings := SERVICE.new({
		"coins": 400,
		"unlocked_area_ids": [&"area.pancake"],
		"owned_growth_ids": [
			"growth.add_on.pancake.egg",
			"growth.add_on.pancake.baocui",
			"growth.add_on.pancake.scallion",
			"growth.add_on.pancake.ham_sausage",
			"growth.add_on.pancake.coriander",
			"growth.add_on.pancake.meat_floss",
		],
	})
	var youtiao_status := all_toppings.purchase_status(&"growth.area.youtiao")
	var soy_status := all_toppings.purchase_status(&"growth.area.fresh_soy_milk")
	_check(bool(youtiao_status.get("can_purchase", false)), "all six toppings and 200 coins unlock youtiao without mastery or reputation")
	_check(bool(soy_status.get("can_purchase", false)), "all six toppings and 200 coins unlock soy without youtiao")
	_check(bool(all_toppings.purchase(&"growth.area.fresh_soy_milk").get("success", false)), "soy can be reserved before youtiao")
	all_toppings.set_day_open(false)
	_check(bool(all_toppings.begin_next_business_day().get("success", false)) and all_toppings.owns_area(&"area.fresh_soy_milk") and not all_toppings.owns_area(&"area.youtiao"), "soy activation does not unlock youtiao")

	var youtiao_route := SERVICE.new({
		"coins": 660,
		"unlocked_area_ids": [&"area.pancake", &"area.youtiao"],
		"owned_growth_ids": ["growth.area.youtiao", "growth.equipment.youtiao.advanced"],
	})
	_check(bool(youtiao_route.purchase(&"growth.equipment.youtiao.dual_basket").get("success", false)), "dual basket needs only advanced fryer and 350 coins")
	youtiao_route.set_day_open(false)
	youtiao_route.begin_next_business_day()
	_check(youtiao_route.owns_growth(&"growth.equipment.youtiao.dual_basket") and youtiao_route.owns_recipe(&"recipe.chicken.cutlet"), "dual basket unlocks chicken on the next business day")
	_check(bool(youtiao_route.purchase(&"growth.capacity.chicken_finished_tray").get("success", false)), "chicken tray is purchasable after dual basket")

	var soy_route := SERVICE.new({
		"coins": 600,
		"unlocked_area_ids": [&"area.pancake", &"area.fresh_soy_milk"],
		"owned_growth_ids": ["growth.area.fresh_soy_milk", "growth.automation.fresh_soy_milk.auto_fill"],
	})
	_check(bool(soy_route.purchase(&"growth.automation.fresh_soy_milk.advanced").get("success", false)), "advanced soy machine needs only intermediate machine and 350 coins")
	_check(bool(soy_route.purchase(&"growth.area.packaged_drink").get("success", false)), "drink rack can be reserved after soy with 200 coins")
	soy_route.set_day_open(false)
	soy_route.begin_next_business_day()
	_check(soy_route.owns_growth(&"growth.automation.fresh_soy_milk.advanced") and soy_route.owns_area(&"area.packaged_drink"), "parallel soy upgrade and drink rack activate together next day")
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
