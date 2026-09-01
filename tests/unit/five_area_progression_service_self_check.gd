extends SceneTree

const SERVICE = preload("res://scripts/services/five_area_progression_service.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var starter := SERVICE.new()
	_check(
		starter.owns_area(&"area.pancake")
		and starter.owns_stock(&"stock.pancake.batter")
		and starter.owns_stock(&"stock.pancake.egg")
		and starter.owns_stock(&"stock.pancake.baocui")
		and starter.owns_stock(&"stock.pancake.sauce.sweet_flour"),
		"new game starts with the full basic pancake recipe stock set"
	)
	_check(
		starter.owns_growth(&"growth.add_on.pancake.egg")
		and starter.owns_growth(&"growth.add_on.pancake.baocui")
		and StringName(starter.purchase_status(&"growth.add_on.pancake.egg").get("reason", &"")) == &"already_owned"
		and StringName(starter.purchase_status(&"growth.add_on.pancake.baocui").get("reason", &"")) == &"already_owned",
		"starter egg and baocui growth are installed for free and cannot be repurchased"
	)
	var existing_save := SERVICE.new({
		"unlocked_stock_ids": [&"stock.pancake.batter", &"stock.pancake.sauce.sweet_flour"],
		"owned_growth_ids": [],
	})
	_check(
		not existing_save.owns_stock(&"stock.pancake.egg")
		and not existing_save.owns_stock(&"stock.pancake.baocui")
		and not existing_save.owns_growth(&"growth.add_on.pancake.egg")
		and not existing_save.owns_growth(&"growth.add_on.pancake.baocui"),
		"loading an existing save does not grant the new starter unlocks"
	)
	var retired_tray_owner := SERVICE.new({"owned_growth_ids": [&"growth.capacity.pancake_holding_tray.second_slot"]})
	_check(retired_tray_owner.owns_growth(&"growth.capacity.pancake_holding_tray.first_slot") and not retired_tray_owner.owns_growth(&"growth.capacity.pancake_holding_tray.second_slot"), "retired second-tray ownership migrates to the single tray")
	var retired_tray_pending := SERVICE.new({"pending_growth_ids": [&"growth.capacity.pancake_holding_tray.second_slot"]})
	_check(Array(retired_tray_pending.snapshot().get("pending_growth_ids", [])).has(&"growth.capacity.pancake_holding_tray.first_slot") and not Array(retired_tray_pending.snapshot().get("pending_growth_ids", [])).has(&"growth.capacity.pancake_holding_tray.second_slot"), "retired pending second-tray purchases migrate to the single tray")
	var topping_chain := SERVICE.new({
		"coins": 160,
		"unlocked_area_ids": [&"area.pancake"],
		"owned_growth_ids": ["growth.add_on.pancake.baocui"],
	})
	_check(bool(topping_chain.purchase(&"growth.add_on.pancake.meat_floss").get("success", false)), "meat floss can be reserved after baocui")
	_check(not bool(topping_chain.purchase_status(&"growth.add_on.pancake.ham_sausage").get("can_purchase", false)), "ham cannot be reserved while its meat-floss prerequisite is only pending")
	topping_chain.set_day_open(false)
	topping_chain.begin_next_business_day()
	_check(bool(topping_chain.purchase(&"growth.add_on.pancake.ham_sausage").get("success", false)), "ham becomes reservable after meat floss activates")

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
	_check(not bool(all_toppings.purchase_status(&"growth.area.packaged_drink").get("can_purchase", false)), "drink rack cannot be reserved while soy is only pending")
	all_toppings.set_day_open(false)
	_check(bool(all_toppings.begin_next_business_day().get("success", false)) and all_toppings.owns_area(&"area.fresh_soy_milk") and not all_toppings.owns_area(&"area.youtiao"), "soy activation does not unlock youtiao")
	_check(bool(all_toppings.purchase(&"growth.area.packaged_drink").get("success", false)), "drink rack becomes reservable after soy activates")

	var youtiao_route := SERVICE.new({
		"coins": 660,
		"unlocked_area_ids": [&"area.pancake", &"area.youtiao"],
		"owned_growth_ids": ["growth.area.youtiao", "growth.equipment.youtiao.advanced"],
	})
	_check(bool(youtiao_route.purchase(&"growth.capacity.youtiao_finished_tray").get("success", false)), "one 50-coin shared finished tray can be reserved after the youtiao area")
	_check(bool(youtiao_route.purchase(&"growth.equipment.youtiao.dual_basket").get("success", false)), "dual basket needs only advanced fryer and 350 coins")
	youtiao_route.set_day_open(false)
	youtiao_route.begin_next_business_day()
	_check(youtiao_route.owns_growth(&"growth.equipment.youtiao.dual_basket") and youtiao_route.owns_recipe(&"recipe.chicken.cutlet"), "dual basket unlocks chicken on the next business day")
	_check(youtiao_route.owns_growth(&"growth.capacity.youtiao_finished_tray"), "the purchased shared tray remains available after the dual basket unlock")

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
