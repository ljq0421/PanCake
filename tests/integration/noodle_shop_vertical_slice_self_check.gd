extends SceneTree

const SCENE := preload("res://scenes/main/noodle_shop_main.tscn")
const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const NOODLE_CATALOG := preload("res://scripts/data/noodle_shop_catalog.gd")

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
	_session.set("_active_save_path", "user://noodle_shop_vertical_slice_self_check.json")
	_session.call("begin_new_game")
	_unlock_noodle_chapter()
	var selected := Dictionary(_session.call("select_chapter", _session.NOODLE_CHAPTER_ID))
	_check(bool(selected.get("success", false)), "closed bronze-complete breakfast chapter can enter the noodle shop")
	var scene := SCENE.instantiate()
	root.add_child(scene)
	for _frame in 4:
		await process_frame
	var workstation := scene.get_node_or_null("Workstation") as NoodleShopWorkstation
	_check(workstation != null, "independent noodle main scene instantiates its workstation")
	if workstation == null:
		scene.queue_free()
		_finish()
		return
	var gesture := workstation.get_node_or_null("GestureSurface") as NoodleGestureSurface
	var shop_sign := workstation.get_node_or_null("ShopSign") as Label
	_check(gesture != null and shop_sign != null and "刀削面" in shop_sign.text, "new map exposes the dough-to-pot gesture surface and its own shop identity")
	_check(
		gesture != null
		and gesture.has_formal_art()
		and (workstation.get_node("Backdrop") as TextureRect).texture.resource_path == "res://resources/art/noodle_shop/background/noodle_shop_interior_background-v1.png",
		"noodle shop uses its formal interior, dough, pot, basket, feedback and product art",
	)
	var snapshot := Dictionary(_session.call("noodle_shop_snapshot"))
	var order := Dictionary(snapshot.get("active_order", {}))
	_check(
		bool(order.get("tutorial_no_countdown", false))
		and StringName(order.get("product_id", &"")) == NOODLE_CATALOG.PRODUCT_CLEAR
		and int(order.get("required_batch_count", 0)) == 6
		and order.has("drain_target")
		and order.has("time_limit"),
		"tutorial order uses the stable noodle order contract and has no patience countdown",
	)
	_check((workstation.get_node("StatsPanel/Layout/TimerLabel") as Label).text == "教学不限时", "first-order UI clearly presents the unlimited tutorial")
	_check(bool(Dictionary(_session.call("noodle_begin_active_recipe")).get("success", false)), "tutorial clear-broth production begins")
	for _index in 6:
		_session.call("noodle_advance", 0.5)
		_check(bool(Dictionary(_session.call("noodle_record_stroke", 140.0, 0.2)).get("success", false)), "gesture creates an independently cooking noodle batch")
	_session.call("noodle_advance", 3.0)
	workstation.call("_refresh", false)
	_check(gesture.qualitative_doneness() == "火候正好", "worktop translates per-batch cook windows into a visual-first doneness cue")
	_check(bool(Dictionary(_session.call("noodle_lift_basket")).get("success", false)), "single basket lifts after six batches")
	_session.call("noodle_advance", 0.6)
	_session.call("noodle_transfer_to_bowl")
	_session.call("noodle_set_broth", &"broth.clear")
	_session.call("noodle_add_topping", &"topping.scallion")
	workstation.call("_serve_bowl")
	_check((workstation.get_node("ResultPanel") as Control).visible, "serving opens the noodle-specific score panel")
	workstation.call("_collect_payment")
	snapshot = Dictionary(_session.call("noodle_shop_snapshot"))
	_check(int(snapshot.get("coins", -1)) == 10 and bool(snapshot.get("tutorial_completed", false)), "tutorial payment grants exactly ten noodle-shop coins and starts normal service")
	_check(int(_session.call("global_reputation")) >= 1, "noodle settlement updates the shared campaign reputation authority")
	_check(is_equal_approx(float(snapshot.get("remaining_seconds", 0.0)), 60.0), "the first timed service window starts at sixty seconds")
	workstation.call("end_business_day_early")
	_check((workstation.get_node("DayPanel") as Control).visible, "day end opens the noodle shop bill and growth surface")
	_check("早餐特殊顾客" in (workstation.get_node("DayPanel/Layout/DaySummary") as Label).text and "20" in (workstation.get_node("DayPanel/Layout/DaySummary") as Label).text, "noodle day end explains how shared reputation advances breakfast special customers")
	var purchase := Dictionary(_session.call("noodle_purchase_growth", NOODLE_CATALOG.GROWTH_TOMATO))
	_check(bool(purchase.get("success", false)), "tomato recipe can be purchased for the next business day")
	_session.call("noodle_begin_next_day")
	snapshot = Dictionary(_session.call("noodle_shop_snapshot"))
	_check(Array(snapshot.get("unlocked_recipe_ids", [])).has(NOODLE_CATALOG.RECIPE_TOMATO), "purchased recipe activates only on the next day")
	_check(is_equal_approx(float(snapshot.get("remaining_seconds", 0.0)), 120.0), "later noodle-shop days use the 120-second service window")
	scene.queue_free()
	await process_frame
	_finish()


func _unlock_noodle_chapter() -> void:
	var progression: RefCounted = _session.call("progression_service")
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


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("NOODLE_SHOP_VERTICAL_SLICE_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("NOODLE_SHOP_VERTICAL_SLICE_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
