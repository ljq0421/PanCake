extends SceneTree

const AUTO_LIFT := &"automation.youtiao.auto_lift"
const AUTO_LOAD := &"automation.youtiao.auto_load"
const RECIPE := &"recipe.youtiao.plain"
const STOCK := "stock.youtiao.plain_dough"

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession is available")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	var progression: RefCounted = session.call("progression_service")
	_configure_youtiao(progression, [])
	_set_stock(session, 4)
	var before := int(Dictionary(session.call("inventory_snapshot")).get(STOCK, 0))
	var unowned: Dictionary = session.call("confirm_and_run_youtiao_auto_load", RECIPE, 1)
	_check(not bool(unowned.get("success", false)) and StringName(unowned.get("reason", &"")) == &"automation_not_owned", "auto load is rejected while the feeder is unowned")
	_check(int(Dictionary(session.call("inventory_snapshot")).get(STOCK, 0)) == before, "unowned automation does not deduct stock")

	_configure_youtiao(progression, [AUTO_LOAD])
	var invalid: Dictionary = session.call("confirm_and_run_youtiao_auto_load", RECIPE, 0)
	_check(StringName(invalid.get("reason", &"")) == &"invalid_job_profile", "the facade rejects a zero-quantity profile")
	var over_capacity: Dictionary = session.call("confirm_and_run_youtiao_auto_load", RECIPE, 3)
	_check(StringName(over_capacity.get("reason", &"")) == &"capacity_exceeded", "the confirmed batch still respects the tier-one two-serving capacity")
	_check(int(Dictionary(session.call("inventory_snapshot")).get(STOCK, 0)) == 4, "capacity failure leaves all dough in inventory")
	var production_after_failure := Dictionary(session.call("five_area_production_snapshot"))
	_check(int(Dictionary(production_after_failure.get("youtiao_job_profile", {})).get("quantity", 0)) == 3, "a confirmed profile is durable even when its execution cannot fit")

	var loaded: Dictionary = session.call("confirm_and_run_youtiao_auto_load", RECIPE, 2)
	var loaded_machine := Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer"))
	_check(bool(loaded.get("success", false)) and StringName(loaded_machine.get("state", &"")) == &"loaded" and int(loaded_machine.get("quantity", 0)) == 2, "one confirmation performs exactly one two-serving automatic load")
	_check(int(Dictionary(session.call("inventory_snapshot")).get(STOCK, 0)) == 2, "successful automatic loading deducts its exact batch once")
	var full_retry: Dictionary = session.call("confirm_and_run_youtiao_auto_load", RECIPE, 1)
	_check(StringName(full_retry.get("reason", &"")) == &"capacity_exceeded" and int(Dictionary(session.call("inventory_snapshot")).get(STOCK, 0)) == 2, "retrying a full basket fails without a second deduction")

	_configure_youtiao(progression, [AUTO_LOAD, AUTO_LIFT])
	_check(bool(Dictionary(session.call("perform_f3_youtiao_action", &"start")).get("success", false)), "the automatically loaded batch enters the unchanged frying model")
	session.call("advance_f3_production", 12.0)
	var lifted := Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer"))
	_check(StringName(lifted.get("state", &"")) == &"draining", "owned auto-lift reuses the normal draining state at maturity")
	session.call("advance_f3_production", 2.0)
	_check(StringName(Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer")).get("state", &"")) == &"ready_to_collect", "auto-lift still honors the existing two-second drain time")

	session.call("begin_new_game")
	progression = session.call("progression_service")
	_configure_youtiao(progression, [AUTO_LOAD])
	_set_stock(session, 1)
	var insufficient: Dictionary = session.call("confirm_and_run_youtiao_auto_load", RECIPE, 2)
	_check(StringName(insufficient.get("reason", &"")) == &"insufficient_stock", "inventory shortage is reported by the existing atomic load service")
	_check(int(Dictionary(session.call("inventory_snapshot")).get(STOCK, 0)) == 1 and StringName(Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer")).get("state", &"")) == &"idle", "insufficient stock rolls both inventory and fryer state back")
	_finish()


func _configure_youtiao(progression: RefCounted, automations: Array) -> void:
	progression.set("unlocked_area_ids", {&"area.pancake": true, &"area.packaged_drink": true, &"area.youtiao": true})
	progression.set("device_tiers", {&"device.pancake_griddle": 0, &"device.packaged_drink_heater": 0, &"device.youtiao_fryer": 0})
	progression.set("unlocked_recipe_ids", {RECIPE: true})
	progression.set("unlocked_product_ids", {&"product.youtiao.plain": true})
	progression.set("unlocked_stock_ids", {StringName(STOCK): true})
	var automation_set := {}
	for automation_id in automations:
		automation_set[StringName(automation_id)] = true
	progression.set("unlocked_automation_ids", automation_set)


func _set_stock(session: Node, quantity: int) -> void:
	var inventory := Dictionary(session.call("inventory_snapshot"))
	inventory[STOCK] = quantity
	session.call("save_inventory", inventory)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("YOUTIAO_AUTO_LOAD_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("YOUTIAO_AUTO_LOAD_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
