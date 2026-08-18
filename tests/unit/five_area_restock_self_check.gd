extends SceneTree

const SERVICE := preload("res://scripts/services/five_area_restock_service.gd")
const EGG_STOCK := &"stock.pancake.egg"
const YOUTIAO_STOCK := &"stock.youtiao.plain_dough"

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession autoload is available")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	var service: RefCounted = SERVICE.new(session)
	var inventory: Dictionary = session.call("inventory_snapshot")
	inventory[str(EGG_STOCK)] = 0
	session.call("save_inventory", inventory)
	var empty_status: Dictionary = service.call("status", EGG_STOCK)
	_check(bool(empty_status.get("success", false)) and int(empty_status.get("current_stock", -1)) == 0, "formal service reads stable pancake stock IDs")
	var no_money: Dictionary = service.call("advance_hold", EGG_STOCK, 1.0)
	_check(no_money.get("reason", &"") == &"insufficient_coins" and int(session.call("inventory_snapshot").get(str(EGG_STOCK), -1)) == 0, "insufficient formal coins stop before inventory mutation")
	session.call("credit_coins", 3)
	var unit_seconds := float(service.call("status", EGG_STOCK).get("unit_seconds", 0.0))
	service.call("advance_hold", EGG_STOCK, unit_seconds * 0.40)
	var partial := float(service.call("status", EGG_STOCK).get("progress_seconds", 0.0))
	_check(partial > 0.0 and partial < unit_seconds, "formal service stores partial hold progress")
	service.call("release", EGG_STOCK)
	var completed: Dictionary = service.call("advance_hold", EGG_STOCK, unit_seconds * 0.60)
	_check(int(completed.get("completed_units", 0)) == 1 and int(session.call("inventory_snapshot").get(str(EGG_STOCK), 0)) == 1, "segmented hold completes exactly one formal stock unit")
	_check(int(session.call("five_area_progression_snapshot").get("coins", 0)) == 2, "a completed formal restock deducts one formal coin")
	var progression: RefCounted = session.call("progression_service")
	var unlocked_stock_ids := Dictionary(progression.get("unlocked_stock_ids")).duplicate(true)
	unlocked_stock_ids[YOUTIAO_STOCK] = true
	progression.set("unlocked_stock_ids", unlocked_stock_ids)
	session.call("_sync_progression_to_save")
	inventory = session.call("inventory_snapshot")
	inventory[str(YOUTIAO_STOCK)] = 0
	session.call("save_inventory", inventory)
	var youtiao_status := Dictionary(service.call("status", YOUTIAO_STOCK))
	_check(is_equal_approx(float(youtiao_status.get("unit_seconds", 0.0)), 0.25), "plain youtiao dough uses the confirmed 0.25-second unit duration")
	_check(int(youtiao_status.get("capacity", 0)) == 4, "plain youtiao dough is limited to the four physical board slots")
	service.call("advance_hold", YOUTIAO_STOCK, 0.10)
	service.call("release", YOUTIAO_STOCK)
	var youtiao_completed := Dictionary(service.call("advance_hold", YOUTIAO_STOCK, 0.15))
	_check(int(youtiao_completed.get("completed_units", 0)) == 1 and int(session.call("inventory_snapshot").get(str(YOUTIAO_STOCK), 0)) == 1, "segmented youtiao hold completes one unit at the faster rate")
	_check(int(session.call("five_area_progression_snapshot").get("coins", -1)) == 0, "faster youtiao restock keeps its two-coin unit cost")
	session.call("continue_game")
	_check(int(session.call("inventory_snapshot").get(str(EGG_STOCK), 0)) == 1 and int(session.call("inventory_snapshot").get(str(YOUTIAO_STOCK), 0)) == 1, "formal restock inventory persists through save reload")
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("FIVE_AREA_RESTOCK_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
