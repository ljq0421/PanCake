extends SceneTree

## Historical test path retained for the test runner.  Its assertions now cover
## the formal five-area session contract rather than the retired v2 snapshot.
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession autoload is available")
	if session == null:
		_finish()
		return
	var new_game: Dictionary = session.call("begin_new_game")
	_check(bool(new_game.get("success", false)) and session.call("has_save"), "new game creates a formal save")
	var progression: RefCounted = session.call("progression_service")
	_check(progression.call("owns_area", &"area.pancake") and not progression.call("owns_area", &"area.packaged_drink"), "new game only unlocks pancake")
	progression.set("coins", 100)
	progression.set("current_day", 3)
	progression.set("reputation", 20)
	progression.set("area_mastery", {&"area.pancake": 6})
	progression.set("area_mastery_details", {
		&"area.pancake": {"qualified": 6, "a_grade": 1},
	})
	progression.set("tutorial_completed_area_ids", {&"area.pancake": true})
	var install: Dictionary = session.call("purchase_growth", &"growth.area.packaged_drink")
	var content: Dictionary = session.call("purchase_growth", &"growth.add_on.pancake.red_chili")
	_check(bool(install.get("success", false)) and bool(content.get("success", false)), "session persists independent install and content pending purchases")
	_check(session.call("end_business_day").get("success", false), "session closes the business day before activation")
	var next_day: Dictionary = session.call("begin_next_business_day")
	_check(bool(next_day.get("success", false)) and progression.call("owns_area", &"area.packaged_drink"), "session activates install purchase next day")
	_check(progression.call("owns_stock", &"stock.pancake.sauce.red_chili"), "session activates content purchase next day")
	_finish()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("GAME_SESSION_PROGRESSION_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("GAME_SESSION_PROGRESSION_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
