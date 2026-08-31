extends SceneTree

const STORE := preload("res://scripts/services/game_session_store.gd")

var _failures: Array[String] = []
var _session: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_session = STORE.new()
	root.add_child(_session)
	_session.set("_active_save_path", "user://debug_chapter_access_self_check.json")
	_session.call("begin_new_game")

	var normal_locked := Dictionary(_session.call("select_chapter", _session.NOODLE_CHAPTER_ID))
	_check(StringName(normal_locked.get("reason", &"")) == &"chapter_locked", "normal chapter selection still rejects a locked shop")

	var breakfast_save := Dictionary(_session.get("_save_data")).duplicate(true)
	breakfast_save["day_open"] = false
	_session.set("_save_data", breakfast_save)
	var debug_noodle := Dictionary(_session.call("select_chapter", _session.NOODLE_CHAPTER_ID, true))
	_check(
		bool(debug_noodle.get("success", false))
		and bool(debug_noodle.get("debug_bypass", false))
		and StringName(_session.call("active_chapter_id")) == _session.NOODLE_CHAPTER_ID,
		"debug selection enters the locked noodle shop",
	)
	_check(not bool(Dictionary(_session.call("chapter_status", _session.NOODLE_CHAPTER_ID)).get("unlocked", true)), "debug entry does not permanently unlock the noodle shop")

	var open_day_block := Dictionary(_session.call("select_chapter", _session.NIGHT_MARKET_CHAPTER_ID, true))
	_check(StringName(open_day_block.get("reason", &"")) == &"business_day_open", "debug entry still respects the open-business-day switch lock")
	_session.call("noodle_end_day", &"manual")
	var debug_night := Dictionary(_session.call("select_chapter", _session.NIGHT_MARKET_CHAPTER_ID, true))
	_check(
		bool(debug_night.get("success", false))
		and bool(debug_night.get("debug_bypass", false))
		and str(debug_night.get("scene_path", "")).ends_with("night_market_main.tscn"),
		"debug selection enters the locked late-night shop after day end",
	)
	_check(not bool(Dictionary(_session.call("chapter_status", _session.NIGHT_MARKET_CHAPTER_ID)).get("unlocked", true)), "debug entry does not permanently unlock the late-night shop")
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if is_instance_valid(_session):
		_session.queue_free()
	if _failures.is_empty():
		print("DEBUG_CHAPTER_ACCESS_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("DEBUG_CHAPTER_ACCESS_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
