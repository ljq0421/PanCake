extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "test has the GameSession autoload")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	var opening_inventory: Dictionary = session.call("inventory_snapshot")
	for stock_id in [&"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.scallion"]:
		_check(int(opening_inventory.get(stock_id, 0)) == 0, "new business starts with %s empty" % stock_id)
	var inventory: Dictionary = session.call("inventory_snapshot")
	inventory["stock.pancake.batter"] = 0
	inventory["stock.pancake.sauce.sweet_flour"] = 0
	inventory["stock.pancake.egg"] = 2
	inventory["stock.pancake.baocui"] = 2
	inventory["stock.pancake.scallion"] = 2
	_check(bool(session.call("save_inventory", inventory).get("success", false)), "test can prepare depleted daily consumables")
	session.call("end_business_day")
	_check(bool(session.call("begin_next_business_day").get("success", false)), "next business day opens")
	var next_inventory: Dictionary = session.call("inventory_snapshot")
	_check(int(next_inventory.get("stock.pancake.batter", 0)) == 0, "unlimited batter remains outside daily inventory replenishment")
	var batter_restock := Dictionary(session.call("five_area_restock_status", &"stock.pancake.batter"))
	_check(not bool(batter_restock.get("success", false)) and StringName(batter_restock.get("reason", &"")) == &"restock_unnecessary", "unlimited batter rejects the paid restock path")
	var sauce_restock := Dictionary(session.call("five_area_restock_status", &"stock.pancake.sauce.sweet_flour"))
	_check(not bool(sauce_restock.get("success", false)) and StringName(sauce_restock.get("reason", &"")) == &"restock_unnecessary", "unlimited sauce rejects the paid restock path")
	_check(int(next_inventory.get("stock.pancake.sauce.sweet_flour", 0)) == 0, "unlimited sauce remains outside daily inventory replenishment")
	for stock_id in [&"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.scallion"]:
		_check(int(next_inventory.get(stock_id, 0)) == 0, "new business day keeps %s empty" % stock_id)
	var progression: RefCounted = session.call("progression_service")
	progression.unlocked_stock_ids[&"stock.pancake.coriander"] = true
	progression.unlocked_stock_ids[&"stock.pancake.meat_floss"] = true
	progression.unlocked_stock_ids[&"stock.pancake.ham_sausage"] = true
	progression.stock_capacity = 8
	session.call("end_business_day")
	_check(bool(session.call("begin_next_business_day").get("success", false)), "business day opens after add-on fixtures unlock")
	var unlocked_inventory: Dictionary = session.call("inventory_snapshot")
	for stock_id in [&"stock.pancake.coriander", &"stock.pancake.scallion", &"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.meat_floss", &"stock.pancake.ham_sausage"]:
		_check(int(unlocked_inventory.get(stock_id, 0)) == 0, "opened business keeps unlocked %s empty" % stock_id)
	session.call("begin_new_game")
	progression = session.call("progression_service")
	progression.set("coins", 10)
	_check(bool(session.call("purchase_growth", &"growth.add_on.pancake.egg").get("success", false)), "egg unlock can be reserved for the next business day")
	session.call("end_business_day")
	var activated_egg_day := Dictionary(session.call("begin_next_business_day"))
	var activated_egg_inventory := Dictionary(session.call("inventory_snapshot"))
	_check(
		int(activated_egg_inventory.get("stock.pancake.egg", -1)) == 0
		and Array(activated_egg_day.get("restock_required_ids", [])).has("stock.pancake.egg"),
		"egg activation opens an empty container that requires manual restocking"
	)
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("DAILY_PANCAKE_CONSUMABLE_RESTOCK_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("DAILY_PANCAKE_CONSUMABLE_RESTOCK_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
