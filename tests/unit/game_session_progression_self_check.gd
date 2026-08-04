extends SceneTree

const CATALOG := preload("res://scripts/data/workstation_expansion_catalog.gd")

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
	var progression: RefCounted = session.call("progression_service")
	progression.set("coins", 200)
	progression.set("reputation", 80)
	progression.set("current_day", 6)
	progression.call("set_metric", &"lifetime_orders", 18)
	progression.call("set_metric", &"average_score", 76)
	var purchase: Dictionary = progression.call("purchase", CATALOG.TOOL_SPREADER_WIDE)
	_check(bool(purchase.get("success", false)), "fixture can create a pending growth purchase")
	progression.call("set_refill_progress", CATALOG.STOCK_EGG, 0.12)
	progression.get("inventory").call("set_current", CATALOG.STOCK_EGG, 2)
	progression.set("stall_tier", 1)
	progression.get("equipment_batches")[CATALOG.DEVICE_SOY_MILK] = {"state": &"processing", "loaded_quantity": 1, "recipe_id": CATALOG.RECIPE_SOY_YELLOW}
	session.call("save_workstation_progression", progression.call("snapshot"))
	var restored: Dictionary = session.call("workstation_progression_snapshot")
	_check(int(restored.get("coins", 0)) == 188, "full progression save keeps charged coin balance")
	_check(int(restored.get("reputation", 0)) == 80, "full progression save keeps reputation")
	_check(int(Dictionary(restored.get("metrics", {})).get("lifetime_orders", 0)) == 18, "full progression save keeps metrics")
	_check(str(restored.get("pending_purchase", "")) == str(CATALOG.TOOL_SPREADER_WIDE), "full progression save keeps pending purchase")
	_check(int(Dictionary(restored.get("ingredient_stock", {})).get("egg", 0)) == 2, "full progression save keeps inventory")
	_check(is_equal_approx(float(Dictionary(restored.get("refill_progress", {})).get("egg", 0.0)), 0.12), "full progression save keeps refill progress")
	_check(int(restored.get("stall_tier", 0)) == 1, "full progression save keeps the store level")
	_check(Dictionary(restored.get("equipment_batches", {})).has("soy_milk_machine"), "full progression save keeps in-progress equipment batches")
	var next_day: Dictionary = session.call("begin_next_business_day")
	var activated: Dictionary = session.call("workstation_progression_snapshot")
	_check(bool(next_day.get("success", false)) and int(activated.get("current_day", 0)) == 7, "next-day transition advances the persisted day")
	_check(Array(activated.get("owned_items", [])).has(str(CATALOG.TOOL_SPREADER_WIDE)), "next-day transition persists the activated purchase")
	_check(str(activated.get("pending_purchase", "")).is_empty(), "next-day transition clears pending purchase")
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("GAME_SESSION_PROGRESSION_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
