extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession autoload exists")
	if session == null:
		_finish()
		return
	session.call("reset_incompatible_development_save")
	var old_file := FileAccess.open(session.SAVE_PATH, FileAccess.WRITE)
	var storage_available := old_file != null
	if storage_available:
		old_file.store_string(JSON.stringify({"version": 2, "progression": {"pending_purchase": "old"}}))
		old_file.close()
		session.call("_load_save")
		_check(not FileAccess.file_exists(session.SAVE_PATH), "old development save is deleted rather than migrated")
	else:
		print("INFO: user:// is unavailable in this sandbox; disk deletion assertions skipped.")
	var new_game: Dictionary = session.call("begin_new_game")
	_check(bool(new_game.get("success", false)) and session.call("has_save"), "new five-area save is created")
	_check(session.SAVE_VERSION == 3 and session.SAVE_KIND == "five_area_v1", "save has the formal five-area identity")
	var progression: RefCounted = session.call("progression_service")
	_check(progression.call("owns_area", &"area.pancake") and not progression.call("owns_area", &"area.packaged_drink"), "new game opens only pancake area")
	var inventory: Dictionary = session.call("inventory_snapshot")
	_check(inventory.has("stock.pancake.sauce.sweet_flour") and int(inventory.get("stock.pancake.sauce.sweet_flour", 0)) == 6, "sweet flour sauce is normal inventory")
	_check(inventory.has("stock.packaged_drink.milk") and int(inventory.get("stock.packaged_drink.milk", 1)) == 0, "locked stock is persisted independently from unlock ownership")
	var bill_entry: Dictionary = session.call("record_order_completed", {"id": "bill-cost", "title": "成本账单"}, {"score": 80.0, "material_cost": 3}, 9)
	var bill_with_cost: Dictionary = session.call("today_bill")
	_check(bool(bill_entry.get("success", false)) and int(bill_with_cost.get("total_cost", 0)) == 3 and int(bill_with_cost.get("total_profit", 0)) == 6, "daily bill preserves material cost and gross profit alongside income")
	var queue_first: Dictionary = session.call("next_filtered_pancake_order")
	var queue_second: Dictionary = session.call("next_filtered_pancake_order")
	var queue_third: Dictionary = session.call("next_filtered_pancake_order")
	_check(bool(queue_first.get("tutorial_no_countdown", false)) and not bool(queue_second.get("tutorial_no_countdown", false)) and not bool(queue_third.get("tutorial_no_countdown", false)), "formal pancake queue filters to unlocked stock and reserves the single tutorial for the first customer")
	var tutorial_result: Dictionary = session.call("record_order_completed", queue_first, {"score": 25.0}, 0)
	var tutorial_snapshot: Dictionary = progression.call("tutorial_snapshot")
	_check(bool(tutorial_result.get("success", false)) and str(tutorial_snapshot.get("active_id", "")).is_empty(), "a completed no-countdown tutorial clears its persisted state without a 70-point gate")
	var formal_open: Dictionary = session.call("open_formal_order", [
		{"area_id": &"area.pancake", "product_id": &"product.pancake.custom", "quantity": 1, "ingredient_ids": [&"stock.pancake.egg"], "sauce_ids": [], "heat_preference": &"golden"},
		{"area_id": &"area.packaged_drink", "product_id": &"product.packaged_drink.milk", "quantity": 1},
	], {"source": &"session_self_check"})
	_check(bool(formal_open.get("success", false)) and Array(Dictionary(formal_open.get("order", {})).get("items", [])).size() == 2, "session opens a persisted formal multi-product order")
	var formal_order_id: StringName = Dictionary(formal_open.get("order", {})).get("order_id", &"")
	_check(bool(session.call("attach_formal_order_product", formal_order_id, 0, {"product_instance_id": &"test.pancake", "product_id": &"product.pancake.custom", "ingredient_ids": [&"stock.pancake.egg"], "sauce_ids": [], "heat_preference": &"golden"}).get("success", false)) and bool(session.call("attach_formal_order_product", formal_order_id, 1, {"product_instance_id": &"test.drink", "product_id": &"product.packaged_drink.milk"}).get("success", false)), "session routes products into their formal order entries")
	_check(bool(session.call("settle_formal_order", formal_order_id).get("order_success", false)), "session settles the formal multi-product order once")
	var legacy_pancake_order: Dictionary = session.call("open_pancake_order", {"id": &"legacy.pancake", "ingredients": [&"egg", &"baocui"], "sauces": [&"sweet_flour"], "heat_preference": &"golden"})
	var stable_item: Dictionary = Dictionary(Array(Dictionary(legacy_pancake_order.get("order", {})).get("items", []))[0])
	_check(Array(stable_item.get("ingredient_ids", [])).has("stock.pancake.egg") and Array(stable_item.get("sauce_ids", [])).has("stock.pancake.sauce.sweet_flour"), "legacy pancake order maps to stable formal product requirements")
	progression.set("coins", 100)
	progression.set("reputation", 20)
	progression.set("current_day", 3)
	progression.set("area_mastery", {&"area.pancake": 6})
	progression.set("area_mastery_details", {&"area.pancake": {"qualified": 6, "a_grade": 0}})
	progression.set("tutorial_completed_area_ids", {&"area.pancake": true})
	_check(bool(session.call("purchase_growth", &"growth.area.packaged_drink").get("success", false)), "installation pending purchase saves immediately")
	_check(bool(session.call("purchase_growth", &"growth.add_on.pancake.red_chili").get("success", false)), "content pending purchase saves immediately")
	session.call("abandon_active_formal_order", &"business_day_expired")
	session.call("end_business_day")
	var next_day: Dictionary = session.call("begin_next_business_day")
	_check(bool(next_day.get("success", false)), "next business day activates persisted pending purchases")
	var drink_tutorial_opened: Dictionary = session.call("ensure_active_playable_order")
	var drink_tutorial := Dictionary(drink_tutorial_opened.get("order", {}))
	var drink_tutorial_items := Array(drink_tutorial.get("items", []))
	var drink_tutorial_item := Dictionary(drink_tutorial_items[0]) if not drink_tutorial_items.is_empty() else {}
	_check(bool(drink_tutorial_opened.get("success", false)) and StringName(drink_tutorial.get("teaching_area_id", &"")) == &"area.packaged_drink" and drink_tutorial_items.size() == 1 and StringName(drink_tutorial_item.get("product_id", &"")) == &"product.packaged_drink.milk", "activated cabinet immediately creates its single packaged-drink teaching customer")
	_check(int(Dictionary(session.call("inventory_snapshot")).get("stock.packaged_drink.milk", -1)) == 0 and Array(session.call("active_formal_orders")).size() == 1, "drink teaching appears without granting free stock and exclusively occupies the store")
	if storage_available:
		session.call("_load_save")
		session.call("_restore_progression")
		var restored: RefCounted = session.call("progression_service")
		_check(restored.call("owns_area", &"area.packaged_drink") and restored.call("owns_stock", &"stock.pancake.sauce.red_chili"), "save reload restores both activated purchase channels")
	else:
		_check(progression.call("owns_area", &"area.packaged_drink") and progression.call("owns_stock", &"stock.pancake.sauce.red_chili"), "in-memory activated state remains coherent without sandbox storage")
	session.call("begin_new_game")
	progression = session.call("progression_service")
	progression.set("coins", 40)
	progression.set("current_day", 8)
	progression.set("area_mastery_details", {&"area.pancake": {"qualified": 16, "a_grade": 0}})
	_check(bool(session.call("purchase_growth", &"growth.add_on.pancake.coriander").get("success", false)), "coriander content unlock can be purchased")
	session.call("end_business_day")
	_check(bool(session.call("begin_next_business_day").get("success", false)), "coriander unlock activates on the next business day")
	var coriander_stock: Dictionary = session.call("five_area_restock_status", &"stock.pancake.coriander")
	_check(bool(coriander_stock.get("success", false)) and int(coriander_stock.get("current_stock", -1)) == 0 and int(coriander_stock.get("capacity", 0)) > 0, "newly activated coriander is refillable but does not receive free stock")
	_finish()

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("FIVE_AREA_GAME_SESSION_STORE_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("FIVE_AREA_GAME_SESSION_STORE_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
