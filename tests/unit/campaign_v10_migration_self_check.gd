extends SceneTree

const STORE := preload("res://scripts/services/game_session_store.gd")
const CATALOG := preload("res://scripts/data/five_area_catalog.gd")

const SAVE_PATH := "user://campaign_v10_migration_self_check.json"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_test_files()
	var source := STORE.new()
	source.set("_active_save_path", SAVE_PATH)
	root.add_child(source)
	source.call("begin_new_game")
	var opened := Dictionary(source.call("open_formal_order", [{
		"area_id": &"area.packaged_drink",
		"product_id": &"product.packaged_drink.juice",
		"quantity": 1,
		"temperature_mode": &"room_temperature",
	}], {"patience_seconds": 31.5, "base_coins": 5}))
	_check(bool(opened.get("success", false)), "migration fixture creates a durable active order")
	var progression: RefCounted = source.call("progression_service")
	progression.set("coins", 37)
	progression.set("reputation", 22)
	progression.set("current_day", 7)
	var unlocked_areas := {}
	var mastery := {}
	var mastery_details := {}
	var tutorials := {}
	for area_id in CATALOG.AREA_IDS:
		unlocked_areas[area_id] = true
		tutorials[area_id] = true
		var qualified := 8 if area_id == &"area.pancake" else 4
		var a_grade := 2 if area_id == &"area.pancake" else 1
		mastery[area_id] = qualified
		mastery_details[area_id] = {"qualified": qualified, "a_grade": a_grade}
	progression.set("unlocked_area_ids", unlocked_areas)
	progression.set("tutorial_completed_area_ids", tutorials)
	progression.set("area_mastery", mastery)
	progression.set("area_mastery_details", mastery_details)
	source.call("_sync_progression_to_save")
	source.call("flush_pending_save")
	var legacy := Dictionary(source.get("_save_data")).duplicate(true)
	legacy["version"] = source.LEGACY_SAVE_VERSION
	legacy["save_kind"] = source.LEGACY_SAVE_KIND
	var legacy_progression := Dictionary(legacy.get("progression", {})).duplicate(true)
	legacy_progression["reputation"] = 22
	legacy["progression"] = legacy_progression
	legacy["business_day_remaining_seconds"] = 47.25
	var legacy_inventory := Dictionary(legacy.get("inventory", {})).duplicate(true)
	legacy_inventory["stock.pancake.egg"] = 3
	legacy["inventory"] = legacy_inventory
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	_check(file != null, "legacy fixture can be written")
	if file != null:
		file.store_string(JSON.stringify(legacy))
		file.close()
	source.queue_free()
	await process_frame
	var migrated := STORE.new()
	migrated.set("_active_save_path", SAVE_PATH)
	root.add_child(migrated)
	await process_frame
	var campaign := Dictionary(migrated.call("campaign_snapshot"))
	var chapters := Dictionary(Dictionary(migrated.get("_campaign_data")).get("chapters", {}))
	var breakfast := Dictionary(chapters.get(str(migrated.BREAKFAST_CHAPTER_ID), {}))
	_check(migrated.has_save() and int(Dictionary(migrated.get("_campaign_data")).get("version", 0)) == 11, "version ten save automatically migrates to campaign version eleven")
	_check(int(campaign.get("global_reputation", -1)) == 22, "legacy shop reputation becomes the authoritative global reputation")
	_check(not Dictionary(breakfast.get("progression", {})).has("reputation"), "migrated chapter state no longer persists a second reputation authority")
	_check(int(Dictionary(breakfast.get("progression", {})).get("coins", -1)) == 37 and int(Dictionary(breakfast.get("progression", {})).get("current_day", -1)) == 7, "migration preserves first-shop coins and business day")
	_check(is_equal_approx(float(breakfast.get("business_day_remaining_seconds", 0.0)), 47.25), "migration preserves the open-day countdown")
	_check(int(Dictionary(breakfast.get("inventory", {})).get("stock.pancake.egg", -1)) == 3, "migration preserves first-shop inventory")
	_check(not Array(Dictionary(breakfast.get("formal_orders", {})).get("active_order_ids", [])).is_empty(), "migration preserves the active order lifecycle")
	_check(Array(campaign.get("unlocked_chapter_ids", [])).has(migrated.NOODLE_CHAPTER_ID), "an already bronze-complete legacy save unlocks chapter two immediately")
	var disk_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	_check(disk_value is Dictionary and str(Dictionary(disk_value).get("save_kind", "")) == migrated.SAVE_KIND, "successful migration atomically persists the campaign identity")
	migrated.queue_free()
	await process_frame
	_remove_test_files()
	_finish()


func _remove_test_files() -> void:
	var absolute := ProjectSettings.globalize_path(SAVE_PATH)
	for suffix_value in ["", STORE.SAVE_TEMP_SUFFIX, STORE.SAVE_BACKUP_SUFFIX]:
		var suffix := str(suffix_value)
		var path: String = absolute + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CAMPAIGN_V10_MIGRATION_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("CAMPAIGN_V10_MIGRATION_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
