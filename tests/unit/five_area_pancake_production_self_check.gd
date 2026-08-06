extends SceneTree

const SERVICE = preload("res://scripts/services/five_area_pancake_production_service.gd")
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession available")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	var service: RefCounted = SERVICE.new(session)
	var before: Dictionary = session.call("inventory_snapshot")
	var result: Dictionary = service.call("settle_completed_pancake", {"applied_sauce_ids": [&"sweet_flour"], "applied_ingredient_ids": [&"egg", &"baocui"]}, {"id": &"order.pancake.classic", "heat_preference": &"golden"})
	_check(bool(result.get("success", false)) and result.get("product_id") == &"product.pancake.custom", "pancake completion creates the stable pancake product")
	var after: Dictionary = session.call("inventory_snapshot")
	_check(int(after.get("stock.pancake.batter", 0)) == int(before.get("stock.pancake.batter", 0)) - 1, "pancake completion consumes batter inventory")
	_check(int(after.get("stock.pancake.sauce.sweet_flour", 0)) == int(before.get("stock.pancake.sauce.sweet_flour", 0)) - 1, "pancake completion consumes sweet flour sauce inventory without a material slot")
	var legacy: Dictionary = session.call("pancake_legacy_inventory_snapshot")
	_check(int(legacy.get("egg", 0)) == int(after.get("stock.pancake.egg", 0)), "legacy pancake interaction inventory maps to stable stock IDs")
	var product: Dictionary = result.get("product", {})
	_check(session.call("store_pancake_product", product).get("reason") == &"tray_locked", "holding tray is not available before its content unlock")
	var progression: RefCounted = session.call("progression_service")
	progression.set("coins", 40)
	progression.set("current_day", 8)
	_check(bool(session.call("purchase_growth", &"growth.capacity.pancake_holding_tray.two_slots").get("success", false)), "tray capacity can be purchased through the content slot")
	session.call("end_business_day")
	_check(bool(session.call("begin_next_business_day").get("success", false)), "tray capacity activates on the following day")
	_check(bool(session.call("store_pancake_product", product).get("success", false)), "structured pancake product enters the formal holding tray")
	_check(not bool(session.call("store_pancake_product", product).get("success", false)), "holding tray rejects a duplicate structured product")
	var tray: Dictionary = session.call("pancake_holding_tray_snapshot")
	_check(Array(tray.get("slots", [])).size() == 2 and not Dictionary(Array(tray.get("slots", []))[0]).is_empty(), "formal save snapshot keeps the fixed two-slot tray")
	_finish()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("FIVE_AREA_PANCAKE_PRODUCTION_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("FIVE_AREA_PANCAKE_PRODUCTION_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
