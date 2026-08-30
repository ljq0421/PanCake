extends SceneTree

const STORE := preload("res://scripts/services/game_session_store.gd")
const CATALOG := preload("res://scripts/data/five_area_catalog.gd")

var _failures: Array[String] = []
var _session: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_session = STORE.new()
	root.add_child(_session)
	_session.set("_active_save_path", "user://campaign_chapter_self_check.json")
	var started := Dictionary(_session.call("begin_new_game"))
	_check(bool(started.get("success", false)) and _session.SAVE_VERSION == 11, "new game creates campaign version eleven")
	_check(StringName(_session.call("active_chapter_id")) == _session.BREAKFAST_CHAPTER_ID, "new campaign starts in breakfast chapter")
	_check(not bool(Dictionary(_session.call("chapter_status", _session.NOODLE_CHAPTER_ID)).get("unlocked", true)), "noodle chapter starts locked")
	var progression: RefCounted = _session.call("progression_service")
	progression.set("coins", 88)
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
	progression.set("day_open", false)
	_session.set("_save_data", Dictionary(_session.get("_save_data")).merged({"day_open": false}, true))
	_session.call("_sync_progression_to_save")
	_check(bool(Dictionary(_session.call("chapter_status", _session.NOODLE_CHAPTER_ID)).get("unlocked", false)), "all four bronze areas permanently unlock noodle chapter")
	progression.set("area_mastery", {})
	progression.set("area_mastery_details", {})
	_session.call("_sync_progression_to_save")
	_check(bool(Dictionary(_session.call("chapter_status", _session.NOODLE_CHAPTER_ID)).get("unlocked", false)), "chapter-two unlock remains permanent if later snapshots no longer meet the milestone")
	var selected := Dictionary(_session.call("select_chapter", _session.NOODLE_CHAPTER_ID))
	_check(bool(selected.get("success", false)) and StringName(_session.call("active_chapter_id")) == _session.NOODLE_CHAPTER_ID, "closed breakfast day can switch to noodle chapter")
	_check(int(Dictionary(_session.call("chapter_status", _session.NOODLE_CHAPTER_ID)).get("coins", -1)) == 0, "new noodle chapter starts with independent zero coins")
	_check(str(selected.get("scene_path", "")).ends_with("noodle_shop_main.tscn"), "chapter selection returns independent noodle scene")
	_session.call("noodle_ensure_active_order")
	_session.call("noodle_begin_active_recipe")
	_session.call("noodle_record_stroke", 140.0, 0.2)
	var before_resume := Dictionary(_session.call("noodle_shop_snapshot"))
	_session.call("mark_session_left")
	_session.call("_load_save")
	var after_resume := Dictionary(_session.call("noodle_shop_snapshot"))
	_check(
		StringName(Dictionary(after_resume.get("active_order", {})).get("order_id", &"")) == StringName(Dictionary(before_resume.get("active_order", {})).get("order_id", &""))
		and Array(Dictionary(after_resume.get("production", {})).get("batches", [])).size() == 1
		and Dictionary(after_resume.get("active_order", {})).get("drain_target") is Vector2,
		"mid-order exit restores the noodle order, batch and typed order contract",
	)
	var blocked := Dictionary(_session.call("select_chapter", _session.BREAKFAST_CHAPTER_ID))
	_check(StringName(blocked.get("reason", &"")) == &"business_day_open", "open noodle day prevents switching shops")
	_session.call("noodle_end_day", &"manual")
	_check(bool(Dictionary(_session.call("select_chapter", _session.BREAKFAST_CHAPTER_ID)).get("success", false)), "day end permits returning to breakfast shop")
	_check(int(Dictionary(_session.call("chapter_status", _session.BREAKFAST_CHAPTER_ID)).get("coins", -1)) == 88, "switching shops preserves breakfast-shop coins independently")
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
		print("CAMPAIGN_CHAPTER_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("CAMPAIGN_CHAPTER_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
