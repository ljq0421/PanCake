extends SceneTree

const GAME_SESSION_STORE := preload("res://scripts/services/game_session_store.gd")
const TEST_SAVE_PATH := "res://tmp/validation/project_cake_save_write_self_check.json"

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_test_files()
	var session := GAME_SESSION_STORE.new()
	session.set("_active_save_path", TEST_SAVE_PATH)
	root.add_child(session)
	session.set_process(false)
	await process_frame
	_check(session.process_mode == Node.PROCESS_MODE_ALWAYS, "save merge timer continues while gameplay is paused")

	var begun := Dictionary(session.call("begin_new_game"))
	_check(bool(begun.get("success", false)), "new game creates the test save")
	_check(FileAccess.file_exists(TEST_SAVE_PATH), "initial save is written immediately")
	_check(not _companion_exists(".tmp") and not _companion_exists(".bak"), "successful atomic write leaves no companion files")
	var initial_write_count := int(session.get("_save_write_count"))

	session.call("set_business_day_remaining_seconds", 55.0)
	session.call("set_business_day_remaining_seconds", 54.0)
	_check(int(session.get("_save_write_count")) == initial_write_count, "rapid timer mutations are merged before disk I/O")
	_check(bool(session.get("_save_dirty")), "merged mutations remain marked for persistence")
	session.call("_process", 2.1)
	_check(int(session.get("_save_write_count")) == initial_write_count + 1, "merge window produces one physical save write")
	_check(not bool(session.get("_save_dirty")), "successful merged write clears the dirty state")
	var persisted := _read_test_save()
	_check(is_equal_approx(float(persisted.get("business_day_remaining_seconds", -1.0)), 54.0), "merged write persists the newest state")

	var countdown_write_count := int(session.get("_save_write_count"))
	session.call("set_business_day_remaining_seconds", 53.0)
	session.call("_process", 1.0)
	session.call("set_business_day_remaining_seconds", 52.0)
	session.call("_process", 1.0)
	_check(int(session.get("_save_write_count")) == countdown_write_count + 1, "continuous one-second countdown mutations cannot starve the safety write")
	persisted = _read_test_save()
	_check(is_equal_approx(float(persisted.get("business_day_remaining_seconds", -1.0)), 52.0), "countdown safety write persists the newest timer value")

	session.call("set_business_day_remaining_seconds", 51.0)
	var before_leave_count := int(session.get("_save_write_count"))
	session.call("mark_session_left")
	_check(int(session.get("_save_write_count")) == before_leave_count + 1, "leaving a session flushes pending state immediately")
	persisted = _read_test_save()
	_check(bool(persisted.get("business_paused", false)) and is_equal_approx(float(persisted.get("business_day_remaining_seconds", -1.0)), 51.0), "leave flush is durable and complete")

	session.queue_free()
	await process_frame
	var absolute_path := ProjectSettings.globalize_path(TEST_SAVE_PATH)
	var backup_path := absolute_path + ".bak"
	_check(DirAccess.rename_absolute(absolute_path, backup_path) == OK, "interrupted-write fixture moves the valid save to backup")
	var recovered_session := GAME_SESSION_STORE.new()
	recovered_session.set("_active_save_path", TEST_SAVE_PATH)
	root.add_child(recovered_session)
	recovered_session.set_process(false)
	await process_frame
	_check(recovered_session.call("has_save"), "startup recovers a missing primary save from backup")
	_check(FileAccess.file_exists(TEST_SAVE_PATH) and not FileAccess.file_exists(backup_path), "backup recovery restores the canonical save path")
	recovered_session.queue_free()
	await process_frame

	_cleanup_test_files()
	_finish()


func _read_test_save() -> Dictionary:
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return Dictionary(parsed) if parsed is Dictionary else {}


func _companion_exists(suffix: String) -> bool:
	return FileAccess.file_exists(ProjectSettings.globalize_path(TEST_SAVE_PATH) + suffix)


func _cleanup_test_files() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEST_SAVE_PATH)
	for candidate in [absolute_path, absolute_path + ".tmp", absolute_path + ".bak"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("GAME_SESSION_SAVE_WRITE_SELF_CHECK_OK")
		quit(0)
	else:
		print("GAME_SESSION_SAVE_WRITE_SELF_CHECK_FAIL: %s" % ", ".join(_failures))
		quit(1)
