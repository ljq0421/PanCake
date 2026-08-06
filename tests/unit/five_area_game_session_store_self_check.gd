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
	progression.set("current_day", 3)
	_check(bool(session.call("purchase_growth", &"growth.area.packaged_drink").get("success", false)), "installation pending purchase saves immediately")
	_check(bool(session.call("purchase_growth", &"growth.add_on.pancake.red_chili").get("success", false)), "content pending purchase saves immediately")
	session.call("end_business_day")
	var next_day: Dictionary = session.call("begin_next_business_day")
	_check(bool(next_day.get("success", false)), "next business day activates persisted pending purchases")
	if storage_available:
		session.call("_load_save")
		session.call("_restore_progression")
		var restored: RefCounted = session.call("progression_service")
		_check(restored.call("owns_area", &"area.packaged_drink") and restored.call("owns_stock", &"stock.pancake.sauce.red_chili"), "save reload restores both activated purchase channels")
	else:
		_check(progression.call("owns_area", &"area.packaged_drink") and progression.call("owns_stock", &"stock.pancake.sauce.red_chili"), "in-memory activated state remains coherent without sandbox storage")
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
