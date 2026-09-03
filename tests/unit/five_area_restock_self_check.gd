extends SceneTree

const SERVICE := preload("res://scripts/services/five_area_restock_service.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession autoload is available")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	var service := SERVICE.new(session)
	var before := Dictionary(session.call("inventory_snapshot"))
	for stock_id in [
		&"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.scallion",
		&"stock.pancake.ham_sausage", &"stock.pancake.meat_floss", &"stock.pancake.sauce.sweet_flour",
		&"stock.youtiao.plain_dough", &"stock.packaged_drink.juice",
	]:
		var status := Dictionary(service.status(stock_id))
		var advanced := Dictionary(service.advance_hold(stock_id, 1.0))
		_check(not bool(status.get("success", true)) and StringName(status.get("reason", &"")) == &"restock_unnecessary", "%s exposes no refill operation" % stock_id)
		_check(not bool(advanced.get("success", true)) and StringName(advanced.get("reason", &"")) == &"restock_unnecessary", "%s ignores long-hold refill" % stock_id)
	_check(Dictionary(session.call("inventory_snapshot")) == before and int(Dictionary(session.call("today_bill")).get("cash_cost", 0)) == 0, "blocked refill gestures change neither inventory nor costs")
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("FIVE_AREA_RESTOCK_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("FIVE_AREA_RESTOCK_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
