extends SceneTree

const SCENE := preload("res://scenes/main/night_market_main.tscn")
const BREAKFAST_CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const NOODLE_CATALOG := preload("res://scripts/data/noodle_shop_catalog.gd")
const NIGHT_CATALOG := preload("res://scripts/data/night_market_catalog.gd")

var _failures: Array[String] = []
var _session: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_session = root.get_node_or_null("GameSession")
	_check(_session != null, "campaign session autoload exists")
	if _session == null:
		_finish()
		return
	_session.set("_active_save_path", "user://night_market_vertical_slice_self_check.json")
	_session.call("begin_new_game")
	_unlock_noodle_chapter()
	_session.call("select_chapter", _session.NOODLE_CHAPTER_ID)
	_session.call("noodle_end_day", &"manual")
	var noodle_session: RefCounted = _session.get("_noodle_session")
	var owned_growth_ids := {}
	for growth_id in NOODLE_CATALOG.GROWTH_DISPLAY_ORDER:
		owned_growth_ids[growth_id] = true
	noodle_session.set("owned_growth_ids", owned_growth_ids)
	_session.call("_sync_noodle_session_to_save")
	_session.call("_refresh_campaign_unlocks")
	var selected := Dictionary(_session.call("select_chapter", _session.NIGHT_MARKET_CHAPTER_ID))
	_check(bool(selected.get("success", false)), "completed lunch-shop growth opens the late-night chapter")
	var scene := SCENE.instantiate()
	root.add_child(scene)
	for _frame in 5:
		await process_frame
	var workstation := scene.get_node_or_null("Workstation") as NightMarketWorkstation
	_check(workstation != null, "independent night-market main scene instantiates its workstation")
	if workstation == null:
		scene.queue_free()
		_finish()
		return
	_check(
		workstation.get_node_or_null("GrillPanel") != null
		and workstation.get_node_or_null("FryerPanel") != null
		and workstation.get_node_or_null("PlatePanel") != null,
		"first viewport exposes equal grill and fryer wings joined by one shared plate",
	)
	var snapshot := Dictionary(_session.call("night_market_shop_snapshot"))
	var order := Dictionary(snapshot.get("active_order", {}))
	_check(
		bool(order.get("tutorial_no_countdown", false))
		and Array(order.get("item_ids", [])) == [NIGHT_CATALOG.ITEM_LAMB, NIGHT_CATALOG.ITEM_LOTUS],
		"first order is the unlimited lamb-and-lotus twin-fire tutorial",
	)
	_check((workstation.get_node("StatsPanel/Layout/TimerLabel") as Label).text == "教学不限时", "top bar clearly presents the unlimited tutorial")
	workstation.call("_add_grill", NIGHT_CATALOG.ITEM_LAMB)
	_session.call("night_market_advance", 7.0)
	workstation.call("_flip_grill_slot", 2)
	_session.call("night_market_advance", 7.0)
	workstation.call("_plate_selected_grill")
	workstation.call("_season", NIGHT_CATALOG.SEASONING_CUMIN)
	workstation.call("_add_fryer", NIGHT_CATALOG.ITEM_LOTUS)
	workstation.call("_lower_fryer")
	_session.call("night_market_advance", 5.5)
	workstation.call("_lift_fryer")
	_session.call("night_market_advance", 1.2)
	workstation.call("_plate_fryer")
	workstation.call("_season", NIGHT_CATALOG.SEASONING_SALT_PEPPER)
	workstation.call("_serve_plate")
	_check(
		(workstation.get_node("ResultPanel") as Control).visible
		and (workstation.get_node("ResultDim") as Control).visible,
		"serving the shared plate opens a focused score-and-payment result",
	)
	workstation.call("_collect_payment")
	snapshot = Dictionary(_session.call("night_market_shop_snapshot"))
	_check(int(snapshot.get("coins", -1)) == 18 and bool(snapshot.get("tutorial_completed", false)), "tutorial payment grants exactly eighteen late-night coins")
	_check(int(_session.call("global_reputation")) >= 1, "night-market settlement updates the shared campaign reputation")
	_check(is_equal_approx(float(snapshot.get("remaining_seconds", 0.0)), 60.0), "tutorial collection starts the first sixty-second service window")
	workstation.call("end_business_day_early")
	_check(
		(workstation.get_node("DayPanel") as Control).visible
		and (workstation.get_node("DayDim") as Control).visible
		and (workstation.get_node("DayPanel/Layout/GrowthChicken") as Button).text.contains("鸡肉串"),
		"day end opens the bill and all four next-day growth choices",
	)
	var purchase := Dictionary(_session.call("night_market_purchase_growth", NIGHT_CATALOG.GROWTH_CHICKEN))
	_check(bool(purchase.get("success", false)), "first recipe growth can be purchased from tutorial earnings")
	_session.call("night_market_begin_next_day")
	snapshot = Dictionary(_session.call("night_market_shop_snapshot"))
	_check(Array(snapshot.get("unlocked_recipe_ids", [])).has(NIGHT_CATALOG.RECIPE_CHICKEN), "purchased chicken recipe activates only on the next business day")
	scene.queue_free()
	await process_frame
	_finish()


func _unlock_noodle_chapter() -> void:
	var progression: RefCounted = _session.call("progression_service")
	var unlocked_areas := {}
	var mastery := {}
	var mastery_details := {}
	var tutorials := {}
	for area_id in BREAKFAST_CATALOG.AREA_IDS:
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


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("NIGHT_MARKET_VERTICAL_SLICE_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("NIGHT_MARKET_VERTICAL_SLICE_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
