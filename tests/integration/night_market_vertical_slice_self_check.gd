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
	var night_audio := workstation.get_node("NightAudio") as NightMarketAudioPlayer
	_check(night_audio != null and night_audio.has_all_cues(), "night market binds dedicated cooking, ready-window, warning and service audio")
	if night_audio != null:
		for cue in [&"grill_place", &"grill_sizzle", &"grill_flip", &"grill_lift", &"fryer_lower", &"fryer_bubbles", &"fryer_lift", &"season", &"ready_cue", &"overcook_warning"]:
			var stream := night_audio.get_cue_stream(cue)
			_check(stream != null and stream.resource_path == "res://resources/audio/sfx/night_%s.wav" % cue, "%s uses its dedicated deterministic source asset" % cue)
		_check((night_audio.get_node("GrillSizzle") as AudioStreamPlayer).bus == &"SFX", "grill loop follows the settings-controlled SFX bus")
		_check((night_audio.get_node("FryerBubbles") as AudioStreamPlayer).bus == &"SFX", "fryer loop follows the settings-controlled SFX bus")
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
	var detail_button := workstation.get_node("StatsPanel/Layout/DetailReadoutButton") as Button
	var fryer_status := workstation.get_node("FryerPanel/Layout/FryerStatusLabel") as Label
	var fryer_hint := workstation.get_node("FryerPanel/Layout/Hint") as Label
	var seasoning_title := workstation.get_node("PlatePanel/Layout/SeasoningTitle") as Label
	_check(detail_button.text == "显示详细数值" and not fryer_status.text.contains("℃") and not fryer_hint.text.contains("秒") and is_zero_approx(fryer_hint.modulate.a) and is_zero_approx(seasoning_title.modulate.a), "night market defaults to qualitative states and hides secondary fryer and seasoning instructions")
	(workstation.get_node("FryerPanel/Layout/PowerRow/PowerStandardButton") as Button).grab_focus()
	workstation.call("_refresh", false)
	_check(is_equal_approx(fryer_hint.modulate.a, 1.0), "focusing a fryer control progressively reveals its cooking target")
	(workstation.get_node("FryerPanel/Layout/PowerRow/PowerStandardButton") as Button).release_focus()
	workstation.call("_add_grill", NIGHT_CATALOG.ITEM_LAMB)
	var grill_slot := workstation.get_node("GrillPanel/Layout/Slots/Medium/GrillSlot2") as Button
	_check(grill_slot.text.contains("正面") and grill_slot.text.contains("反面") and grill_slot.text.count("\n") == 1 and grill_slot.tooltip_text.contains("翻面"), "grill keeps two-sided doneness visible while moving repeated operation copy into focus help")
	workstation.call("_toggle_precision_details")
	_check(
		detail_button.text == "隐藏详细数值"
		and fryer_status.text.contains("℃")
		and (workstation.get_node("FryerPanel/Layout/PowerRow/PowerStandardButton") as Button).text.contains("℃")
		and grill_slot.text.contains("正 "),
		"one explicit control restores exact heat, temperature and timing readouts",
	)
	workstation.call("_toggle_precision_details")
	var audio_diagnostics := night_audio.get_diagnostics()
	_check(bool(audio_diagnostics.get("grill_sizzle_playing", false)), "placing a skewer starts the charcoal cooking loop")
	_session.call("night_market_advance", 7.0)
	workstation.call("_refresh", false)
	var ready_counts := Dictionary(night_audio.get_diagnostics().get("cue_counts", {}))
	_check(grill_slot.text.contains("★翻面") and grill_slot.modulate != Color.WHITE and "现在翻面" in (workstation.get_node("StatusPanel/StatusLabel") as Label).text, "one golden grill side highlights the slot and asks for a flip")
	_check(int(ready_counts.get(&"ready_cue", 0)) == 1, "entering the grill flip window plays one ready cue")
	workstation.call("_refresh", false)
	ready_counts = Dictionary(night_audio.get_diagnostics().get("cue_counts", {}))
	_check(int(ready_counts.get(&"ready_cue", 0)) == 1, "staying in the grill flip window does not repeat the cue")
	workstation.call("_flip_grill_slot", 2)
	_session.call("night_market_advance", 7.0)
	workstation.call("_refresh", false)
	ready_counts = Dictionary(night_audio.get_diagnostics().get("cue_counts", {}))
	_check(grill_slot.text.contains("★起串") and (workstation.get_node("GrillPanel/Layout/PlateGrillButton") as Button).text.contains("立即起串") and int(ready_counts.get(&"ready_cue", 0)) == 2, "two golden grill sides highlight the lift action with one new cue")
	workstation.call("_plate_selected_grill")
	workstation.call("_season", NIGHT_CATALOG.SEASONING_CUMIN)
	workstation.call("_add_fryer", NIGHT_CATALOG.ITEM_LOTUS)
	workstation.call("_lower_fryer")
	audio_diagnostics = night_audio.get_diagnostics()
	_check(bool(audio_diagnostics.get("fryer_bubbles_playing", false)), "lowering the basket starts the active-oil loop")
	_session.call("night_market_advance", 5.5)
	workstation.call("_refresh", false)
	ready_counts = Dictionary(night_audio.get_diagnostics().get("cue_counts", {}))
	_check(fryer_status.text.contains("★可提篮") and (workstation.get_node("FryerPanel/Layout/ActionRow/LiftFryerButton") as Button).text.contains("★") and int(ready_counts.get(&"ready_cue", 0)) == 3, "golden fryer food highlights the basket-lift action with one new cue")
	workstation.call("_lift_fryer")
	_session.call("night_market_advance", 1.2)
	workstation.call("_refresh", false)
	ready_counts = Dictionary(night_audio.get_diagnostics().get("cue_counts", {}))
	_check(fryer_status.text.contains("★可装盘") and (workstation.get_node("FryerPanel/Layout/ActionRow/PlateFryerButton") as Button).text.contains("★") and int(ready_counts.get(&"ready_cue", 0)) == 4, "slower oil drips highlight the plating action with one new cue")
	workstation.call("_plate_fryer")
	workstation.call("_season", NIGHT_CATALOG.SEASONING_SALT_PEPPER)
	workstation.call("_serve_plate")
	_check(
		(workstation.get_node("ResultPanel") as Control).visible
		and (workstation.get_node("ResultDim") as Control).visible,
		"serving the shared plate opens a focused score-and-payment result",
	)
	var result_details := (workstation.get_node("ResultPanel/Layout/ResultDetails") as Label).text
	_check(
		result_details.contains("羊肉串")
		and result_details.contains("炸藕片")
		and result_details.count("•") == 2,
		"result feedback gives one item-specific action line for each cooking station",
	)
	workstation.call("_collect_payment")
	snapshot = Dictionary(_session.call("night_market_shop_snapshot"))
	_check(int(snapshot.get("coins", -1)) == 18 and bool(snapshot.get("tutorial_completed", false)), "tutorial payment grants exactly eighteen late-night coins")
	var first_timed_order := Dictionary(snapshot.get("active_order", {}))
	_check(
		StringName(first_timed_order.get("recipe_id", &"")) == NIGHT_CATALOG.RECIPE_LAMB
		and Array(first_timed_order.get("item_ids", [])).size() == 1
		and not bool(first_timed_order.get("tutorial_no_countdown", true)),
		"tutorial collection transitions into a timed single-line grill order before returning to combos",
	)
	_check(int(_session.call("global_reputation")) >= 1, "night-market settlement updates the shared campaign reputation")
	_check(is_equal_approx(float(snapshot.get("remaining_seconds", 0.0)), 60.0), "tutorial collection starts the first sixty-second service window")
	var cue_counts := Dictionary(night_audio.get_diagnostics().get("cue_counts", {}))
	for expected in [
		{&"cue": &"grill_place", &"count": 1},
		{&"cue": &"grill_flip", &"count": 1},
		{&"cue": &"grill_lift", &"count": 1},
		{&"cue": &"fryer_lower", &"count": 1},
		{&"cue": &"fryer_lift", &"count": 1},
		{&"cue": &"season", &"count": 2},
		{&"cue": &"ready_cue", &"count": 4},
		{&"cue": &"serve", &"count": 1},
		{&"cue": &"payment", &"count": 1},
	]:
		_check(int(cue_counts.get(expected[&"cue"], 0)) == int(expected[&"count"]), "%s plays exactly on successful semantic actions" % expected[&"cue"])
	night_audio.set_cooking_activity(false, false, true)
	night_audio.set_cooking_activity(false, false, true)
	cue_counts = Dictionary(night_audio.get_diagnostics().get("cue_counts", {}))
	_check(int(cue_counts.get(&"overcook_warning", 0)) == 1, "continuous overcooking raises one warning instead of repeating every refresh")
	night_audio.set_cooking_activity(false, false, false)
	workstation.call("end_business_day_early")
	_check(
		(workstation.get_node("DayPanel") as Control).visible
		and (workstation.get_node("DayDim") as Control).visible
		and (workstation.get_node("DayPanel/Layout/GrowthChicken") as Button).text.contains("鸡肉串"),
		"day end opens the bill and all four next-day growth choices",
	)
	_check("早餐特殊顾客" in (workstation.get_node("DayPanel/Layout/DaySummary") as Label).text and "20" in (workstation.get_node("DayPanel/Layout/DaySummary") as Label).text, "night-market day end explains how shared reputation advances breakfast special customers")
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
