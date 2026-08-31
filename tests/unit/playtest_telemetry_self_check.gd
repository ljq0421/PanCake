extends SceneTree

const TELEMETRY := preload("res://scripts/services/playtest_telemetry.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var output := "user://playtest-telemetry-self-check/%d" % Time.get_ticks_usec()
	var telemetry: RefCounted = TELEMETRY.new()
	var started := Dictionary(telemetry.call("start_session", output, "self-check", {"fixture": true}))
	_check(bool(started.get("enabled", false)), "explicit start enables local playtest telemetry")
	telemetry.call("record", &"order_settled", {
		"chapter_id": &"chapter.noodle_shop",
		"day": 2,
		"coins": 10,
		"owned_growth_count": 1,
		"global_reputation": 4,
		"success": true,
		"overall_score": 88.0,
		"payment_coins": 10,
		"reputation_delta": 1,
	})
	telemetry.call("record", &"growth_purchased", {
		"chapter_id": &"chapter.noodle_shop",
		"day": 2,
		"coins": 0,
		"owned_growth_count": 1,
		"global_reputation": 4,
		"growth_id": &"growth.noodle.recipe.tomato_egg",
		"success": true,
	})
	telemetry.call("record", &"day_ended", {
		"chapter_id": &"chapter.noodle_shop",
		"day": 2,
		"coins": 0,
		"owned_growth_count": 1,
		"global_reputation": 4,
		"orders_completed": 1,
		"revenue": 10,
	})
	var finished := Dictionary(telemetry.call("finish", {"fixture_complete": true}))
	_check(not bool(finished.get("enabled", true)), "finishing closes the opt-in telemetry session")
	var events_path := str(finished.get("events_path", ""))
	var summary_path := str(finished.get("summary_path", ""))
	_check(FileAccess.file_exists(events_path) and FileAccess.file_exists(summary_path), "telemetry exports crash-resilient JSONL and a cumulative JSON summary")
	var lines: PackedStringArray = FileAccess.get_file_as_string(events_path).strip_edges().split("\n")
	_check(lines.size() == 5, "session start, three gameplay events and session finish are recorded exactly once")
	var summary_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(summary_path))
	_check(summary_value is Dictionary, "summary export remains machine-readable JSON")
	if summary_value is Dictionary:
		var summary := Dictionary(summary_value)
		var chapter := Dictionary(Dictionary(summary.get("chapters", {})).get("chapter.noodle_shop", {}))
		_check(int(summary.get("event_count", 0)) == 5, "summary event count matches the append-only log")
		_check(
			int(chapter.get("orders_settled", 0)) == 1
			and is_equal_approx(float(chapter.get("average_score", 0.0)), 88.0)
			and int(chapter.get("growth_purchases", 0)) == 1
			and int(chapter.get("days_ended", 0)) == 1,
			"chapter summary aggregates order quality, growth pace and completed days",
		)
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PLAYTEST_TELEMETRY_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("PLAYTEST_TELEMETRY_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
