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
	var inventory: Dictionary = session.call("inventory_snapshot")
	inventory["stock.pancake.batter"] = 0
	inventory["stock.pancake.sauce.sweet_flour"] = 0
	inventory["stock.pancake.egg"] = 2
	_check(bool(session.call("save_inventory", inventory).get("success", false)), "test can prepare depleted daily consumables")
	session.call("end_business_day")
	_check(bool(session.call("begin_next_business_day").get("success", false)), "next business day opens")
	var next_inventory: Dictionary = session.call("inventory_snapshot")
	_check(int(next_inventory.get("stock.pancake.batter", 0)) == 6, "new business day replenishes non-restockable batter")
	_check(int(next_inventory.get("stock.pancake.sauce.sweet_flour", 0)) == 6, "new business day replenishes non-restockable base sauce")
	_check(int(next_inventory.get("stock.pancake.egg", 0)) == 2, "daily replenishment does not overwrite player-restocked ingredient trays")
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
