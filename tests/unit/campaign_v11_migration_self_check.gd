extends SceneTree

const STORE := preload("res://scripts/services/game_session_store.gd")
const SAVE_PATH := "user://campaign_v11_migration_self_check.json"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_test_files()
	var source := STORE.new()
	source.set("_active_save_path", SAVE_PATH)
	root.add_child(source)
	source.call("begin_new_game")
	var progression: RefCounted = source.call("progression_service")
	progression.set("coins", 63)
	progression.set("reputation", 17)
	source.call("_sync_progression_to_save")
	source.call("_touch_and_write", true)
	var fixture_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	_check(fixture_value is Dictionary, "version-eleven fixture can be read")
	if fixture_value is Dictionary:
		var fixture := Dictionary(fixture_value)
		fixture["version"] = source.PREVIOUS_SAVE_VERSION
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(fixture))
			file.close()
	source.queue_free()
	await process_frame
	var migrated := STORE.new()
	migrated.set("_active_save_path", SAVE_PATH)
	root.add_child(migrated)
	await process_frame
	var campaign := Dictionary(migrated.call("campaign_snapshot"))
	var breakfast: Dictionary = Dictionary(Dictionary(migrated.get("_campaign_data")).get("chapters", {})).get(str(migrated.BREAKFAST_CHAPTER_ID), {})
	_check(migrated.has_save() and migrated.SAVE_VERSION == 12, "version-eleven campaign migrates in place to version twelve")
	_check(int(campaign.get("global_reputation", -1)) == 17, "version-eleven migration preserves shared reputation")
	_check(int(Dictionary(breakfast.get("progression", {})).get("coins", -1)) == 63, "version-eleven migration preserves breakfast coins")
	_check(Array(migrated.call("chapter_statuses")).size() == 3, "migrated campaign exposes the third chapter without unlocking it early")
	_check(not bool(Dictionary(migrated.call("chapter_status", migrated.NIGHT_MARKET_CHAPTER_ID)).get("unlocked", true)), "migrated campaign keeps the night-market milestone locked")
	migrated.queue_free()
	await process_frame
	_remove_test_files()
	_finish()


func _remove_test_files() -> void:
	var absolute := ProjectSettings.globalize_path(SAVE_PATH)
	for suffix_value in ["", STORE.SAVE_TEMP_SUFFIX, STORE.SAVE_BACKUP_SUFFIX]:
		var path := absolute + str(suffix_value)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CAMPAIGN_V11_MIGRATION_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("CAMPAIGN_V11_MIGRATION_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
