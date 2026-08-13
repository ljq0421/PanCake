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
	var promotion_state_before := Array(Dictionary(session.get("_save_data")).get("pending_order_promotions", [])).duplicate(true)
	session.call("_enqueue_growth_order_promotions", [&"growth.tool.pancake.wide_spreader"])
	_check(Array(Dictionary(session.get("_save_data")).get("pending_order_promotions", [])) == promotion_state_before, "wide spreader activation creates no tutorial order or promotion order")
	var progression: RefCounted = session.call("progression_service")
	_check(progression.call("owns_area", &"area.pancake") and not progression.call("owns_area", &"area.packaged_drink"), "new game only unlocks pancake")
	progression.set("coins", 100)
	progression.set("current_day", 3)
	progression.set("reputation", 20)
	progression.set("area_mastery", {&"area.pancake": 6})
	progression.set("area_mastery_details", {
		&"area.pancake": {"qualified": 6, "a_grade": 1},
	})
	_check(bool(Dictionary(progression.call("complete_tutorial", &"area", &"area.pancake")).get("success", false)), "fixture completes the opening pancake tutorial through the progression API")
	var install: Dictionary = session.call("purchase_growth", &"growth.area.packaged_drink")
	var content: Dictionary = session.call("purchase_growth", &"growth.add_on.pancake.red_chili")
	_check(bool(install.get("success", false)) and bool(content.get("success", false)), "session persists independent install and content pending purchases")
	_check(session.call("end_business_day").get("success", false), "session closes the business day before activation")
	var next_day: Dictionary = session.call("begin_next_business_day")
	_check(bool(next_day.get("success", false)) and progression.call("owns_area", &"area.packaged_drink"), "session activates install purchase next day")
	_check(progression.call("owns_stock", &"stock.pancake.sauce.red_chili"), "session activates content purchase next day")
	var tutorial: Dictionary = Dictionary(session.call("five_area_progression_snapshot")).get("tutorial", {})
	_check(StringName(tutorial.get("active_kind", &"")) == &"area" and StringName(tutorial.get("active_id", &"")) == &"area.packaged_drink", "packaged-drink activation schedules its area tutorial for the new day")
	_check(Array(session.call("active_formal_orders")).is_empty() and Array(session.call("waiting_formal_orders")).is_empty(), "business-day transition persists an empty order queue before the tutorial refresh")
	var generated := Dictionary(session.call("ensure_active_playable_order"))
	var generated_queue := Array(generated.get("queue", []))
	var tutorial_then_chili := generated_queue.size() == 4
	if generated_queue.size() == 4:
		tutorial_then_chili = StringName(Dictionary(Dictionary(generated_queue[0]).get("metadata", {})).get("tutorial_id", &"")) == &"area.packaged_drink"
		for queue_index in range(1, 4):
			var queue_items := Array(Dictionary(generated_queue[queue_index]).get("items", []))
			var promoted_stock_found := false
			for queue_item_value in queue_items:
				var queue_item := Dictionary(queue_item_value)
				promoted_stock_found = promoted_stock_found or Array(queue_item.get("sauce_ids", [])).has(&"stock.pancake.sauce.red_chili")
			tutorial_then_chili = tutorial_then_chili and promoted_stock_found
	var saved_promotions := Array(Dictionary(session.get("_save_data")).get("pending_order_promotions", []))
	_check(tutorial_then_chili and saved_promotions.size() == 1 and StringName(Dictionary(saved_promotions[0]).get("source_growth_id", &"")) == &"tutorial:area.packaged_drink" and int(Dictionary(saved_promotions[0]).get("remaining_orders", 0)) == 3, "tutorial stays exclusive first, consumes the three persisted chili exposures at generation, then leaves area follow-up promotion persisted")
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
