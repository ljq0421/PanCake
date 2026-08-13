extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession exists for packaged-drink split migration")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	var legacy := Dictionary(session.get("_save_data")).duplicate(true)
	legacy.erase("packaged_drink_split_migration_version")
	legacy.erase("packaged_drink_split_migration_pending")
	legacy.erase("packaged_drink_suspended_heater_tier")
	legacy["day_open"] = true
	var progression := Dictionary(legacy.get("progression", {})).duplicate(true)
	progression["day_open"] = true
	progression["coins"] = 100
	progression["unlocked_area_ids"] = [&"area.pancake", &"area.packaged_drink"]
	progression["unlocked_recipe_ids"] = [&"recipe.pancake.base", &"recipe.packaged_drink.milk"]
	progression["unlocked_product_ids"] = [&"product.pancake.custom", &"product.packaged_drink.milk"]
	progression["unlocked_stock_ids"] = [&"stock.pancake.batter", &"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.scallion", &"stock.pancake.sauce.sweet_flour", &"stock.packaged_drink.milk"]
	progression["device_tiers"] = {&"device.pancake_griddle": 0, &"device.packaged_drink_heater": 2}
	progression["owned_growth_ids"] = [&"growth.area.packaged_drink", &"growth.equipment.packaged_drink.intermediate", &"growth.equipment.packaged_drink.advanced"]
	progression["tutorial"] = {
		"completed_area_ids": [&"area.pancake", &"area.packaged_drink"],
		"completed_device_ids": [&"device.packaged_drink_heater"],
		"queue_area_ids": [],
		"queue_device_ids": [],
		"active_kind": &"",
		"active_id": &"",
	}
	legacy["progression"] = progression
	var inventory := Dictionary(legacy.get("inventory", {})).duplicate(true)
	inventory["stock.packaged_drink.milk"] = 6
	legacy["inventory"] = inventory
	var production := Dictionary(legacy.get("production", {})).duplicate(true)
	production["packaged_drink_heater"] = {
		"device_id": &"device.packaged_drink_heater",
		"owned": true,
		"tier": 2,
		"capacity": 4,
		"slots": [
			{"state": &"heating", "product_id": &"product.packaged_drink.milk", "elapsed_seconds": 0.5, "hot_elapsed_seconds": 0.0},
			{"state": &"empty", "product_id": &"", "elapsed_seconds": 0.0, "hot_elapsed_seconds": 0.0},
			{"state": &"empty", "product_id": &"", "elapsed_seconds": 0.0, "hot_elapsed_seconds": 0.0},
			{"state": &"empty", "product_id": &"", "elapsed_seconds": 0.0, "hot_elapsed_seconds": 0.0},
		],
	}
	legacy["production"] = production
	session.set("_save_data", legacy)
	session.call("_ensure_save_shape")
	var deferred := Dictionary(session.get("_save_data"))
	var deferred_progression := Dictionary(deferred.get("progression", {}))
	_check(
		bool(deferred.get("packaged_drink_split_migration_pending", false))
		and Dictionary(deferred_progression.get("device_tiers", {})).has(&"device.packaged_drink_heater"),
		"an open legacy business day defers migration and keeps its current heater usable"
	)

	deferred["day_open"] = false
	deferred_progression["day_open"] = false
	deferred["progression"] = deferred_progression
	session.set("_save_data", deferred)
	session.call("_prepare_packaged_drink_split_migration")
	var migrated := Dictionary(session.get("_save_data"))
	var migrated_progression := Dictionary(migrated.get("progression", {}))
	var migrated_tiers := Dictionary(migrated_progression.get("device_tiers", {}))
	var migrated_growth := PackedStringArray(Array(migrated_progression.get("owned_growth_ids", [])))
	var migrated_heater := Dictionary(Dictionary(migrated.get("production", {})).get("packaged_drink_heater", {}))
	_check(
		int(migrated.get("packaged_drink_split_migration_version", 0)) == 1
		and not bool(migrated.get("packaged_drink_split_migration_pending", true))
		and int(migrated.get("packaged_drink_suspended_heater_tier", -1)) == 2
		and not (migrated_tiers.has(&"device.packaged_drink_heater") or migrated_tiers.has("device.packaged_drink_heater")),
		"safe-boundary migration re-locks the heater and suspends its paid tier"
	)
	_check(
		int(Dictionary(migrated.get("inventory", {})).get("stock.packaged_drink.milk", 0)) == 7
		and not bool(migrated_heater.get("owned", true)),
		"drink in the heater returns to inventory without loss even above normal capacity"
	)
	_check(
		migrated_growth.has("growth.equipment.packaged_drink.intermediate")
		and migrated_growth.has("growth.equipment.packaged_drink.advanced")
		and not migrated_growth.has("growth.equipment.packaged_drink.basic"),
		"legacy paid upgrade records remain owned while the new base heater must be purchased"
	)

	session.call("_restore_progression")
	var restored_progression: RefCounted = session.call("progression_service")
	var basic_purchase := Dictionary(session.call("purchase_growth", &"growth.equipment.packaged_drink.basic"))
	var next_day := Dictionary(session.call("begin_next_business_day"))
	var tutorial := Dictionary(restored_progression.call("tutorial_snapshot"))
	_check(
		bool(basic_purchase.get("success", false))
		and int(basic_purchase.get("charged_coins", 0)) == 12
		and int(next_day.get("restored_packaged_drink_heater_tier", -1)) == 2
		and restored_progression.call("owns_device", &"device.packaged_drink_heater")
		and int(restored_progression.call("device_tier", &"device.packaged_drink_heater")) == 2,
		"buying the base heater once restores the previously paid tier without charging upgrade prices again"
	)
	_check(
		StringName(tutorial.get("active_kind", &"")) == &"device"
		and StringName(tutorial.get("active_id", &"")) == &"device.packaged_drink_heater"
		and not Array(tutorial.get("completed_device_ids", [])).has("device.packaged_drink_heater"),
		"restored heater tier still triggers the new one-time hot-drink tutorial"
	)
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PACKAGED_DRINK_SPLIT_MIGRATION_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("PACKAGED_DRINK_SPLIT_MIGRATION_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
