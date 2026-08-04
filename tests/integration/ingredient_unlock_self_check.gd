extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/initial_unlock_workstation.tscn")
const CATALOG := preload("res://scripts/data/workstation_expansion_catalog.gd")
const ORDER_SERVICE := preload("res://scripts/services/order_service.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession autoload is available")
	if session == null:
		_finish()
		return
	session.begin_new_game()
	var progression: RefCounted = session.progression_service()
	_check(progression.call("unlocked_ingredient_ids") == CATALOG.starter_ingredient_ids(), "new game unlocks only egg, baocui, and scallion")
	_check(int(progression.get("inventory").call("current", CATALOG.STOCK_HAM_SAUSAGE)) == 0, "new game keeps ham sausage stock at zero")

	progression.set("coins", 18)
	progression.set("reputation", 20)
	progression.set("current_day", 3)
	progression.call("set_metric", &"average_score", 65)
	var purchase: Dictionary = progression.call("purchase", CATALOG.UNLOCK_INGREDIENT_HAM)
	_check(bool(purchase.get("success", false)), "ham sausage permanent unlock can be purchased at its exact gate")
	_check(not Array(progression.call("unlocked_ingredient_ids")).has(CATALOG.STOCK_HAM_SAUSAGE), "pending purchase does not expose ham during the current day")
	_check(int(progression.get("inventory").call("current", CATALOG.STOCK_HAM_SAUSAGE)) == 0, "buying the unlock does not grant free ham inventory")
	progression.call("begin_next_business_day")
	session.save_workstation_progression(progression.call("snapshot"))
	_check(Array(session.unlocked_ingredient_ids()).has(CATALOG.STOCK_HAM_SAUSAGE), "ham unlock becomes permanent on the next business day")
	_check(int(session.ingredient_stock_snapshot().get("ham_sausage", -1)) == 0, "activated ham tray still starts empty and requires refill")

	var starter_orders := ORDER_SERVICE.new(CATALOG.starter_ingredient_ids())
	var starter_titles := PackedStringArray()
	for index in 4:
		starter_titles.append(str(starter_orders.call("next_order").get("title", "")))
	_check(not "香辣火腿煎饼" in starter_titles and not "双酱全料煎饼" in starter_titles, "locked ham orders never enter the starter queue")
	var unlocked_orders := ORDER_SERVICE.new(session.unlocked_ingredient_ids())
	var unlocked_titles := PackedStringArray()
	for index in 4:
		unlocked_titles.append(str(unlocked_orders.call("next_order").get("title", "")))
	_check("香辣火腿煎饼" in unlocked_titles, "ham orders enter the queue after permanent unlock")

	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	await process_frame
	await process_frame
	var ham_button := workstation.get_node("SafeArea/IngredientRack/HamButton") as Button
	var meat_floss_button := workstation.get_node("SafeArea/IngredientRack/MeatFlossButton") as Button
	_check(ham_button.visible and not ham_button.disabled, "activated ham unlock exposes the scene-backed refill and drag tray")
	_check(not meat_floss_button.visible and meat_floss_button.disabled, "later permanent ingredients remain physically hidden while locked")
	_check((workstation.get("order_service") as RefCounted).call("order_at", 1).get("id", &"") == &"chili_ham", "real workstation builds its order pool from persisted unlocks")
	workstation.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	_failures.append(description)
	push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("INGREDIENT_UNLOCK_SELF_CHECK_PASS")
		quit(0)
		return
	print("INGREDIENT_UNLOCK_SELF_CHECK_FAIL: %s" % ", ".join(_failures))
	quit(1)
