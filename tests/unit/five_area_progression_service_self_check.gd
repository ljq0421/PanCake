extends SceneTree

const SERVICE = preload("res://scripts/services/five_area_progression_service.gd")
const CATALOG = preload("res://scripts/data/five_area_catalog.gd")
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var day_one = SERVICE.new({
		"coins": 100,
		"reputation": 20,
		"current_day": 1,
		"unlocked_area_ids": [&"area.pancake"],
		"area_mastery_details": {&"area.pancake": {"qualified": 6, "a_grade": 1}},
		"tutorial": {"completed_area_ids": [&"area.pancake"], "queue_area_ids": [], "active_kind": &"", "active_id": &""},
	})
	var day_one_recommendations: Dictionary = day_one.growth_recommendations(3)
	var day_one_items: Array = Array(day_one_recommendations.get("recommended", []))
	_check(Array(day_one.growth_recommendations(0).get("recommended", [])).is_empty(), "zero recommendation limit returns an empty compatible result")
	_check(_growth_ids(day_one_items) == [&"growth.tool.pancake.wide_spreader", &"growth.add_on.pancake.red_chili", &"growth.area.packaged_drink"], "day-one settlement recommends the two D2 pancake goals and the D3 next-area goal")
	var fixed_route := Array(CATALOG.FIXED_GROWTH_ROUTE)
	var unique_route := {}
	for growth_id_variant in fixed_route:
		unique_route[StringName(growth_id_variant)] = true
	_check(fixed_route.size() == CATALOG.GROWTH_DEFINITIONS.size() and unique_route.size() == fixed_route.size(), "fixed growth route covers every growth definition exactly once")
	_check(fixed_route.slice(0, 3) == Array(_growth_ids(day_one_items)), "the first recommendation window follows the catalog route")
	_check(day_one_items.size() == 3 and Array(day_one_recommendations.get("install", [])).size() == 2 and Array(day_one_recommendations.get("content", [])).size() == 1, "recommendation limit applies to the total across both purchase slots")
	for item_variant in day_one_items:
		var item := Dictionary(item_variant)
		_check(not bool(item.get("can_purchase", true)) and StringName(item.get("reason", &"")) == &"day_requirement", "day-one recommendation remains locked by its D2 or D3 purchase day")
		_check(not Array(item.get("missing_requirements", [])).is_empty(), "locked recommendation retains its complete requirement list")

	var day_two = SERVICE.new({
		"coins": 100,
		"reputation": 20,
		"current_day": 2,
		"unlocked_area_ids": [&"area.pancake"],
		"area_mastery_details": {&"area.pancake": {"qualified": 6, "a_grade": 1}},
		"tutorial": {"completed_area_ids": [&"area.pancake"], "queue_area_ids": [], "active_kind": &"", "active_id": &""},
	})
	var day_two_items: Array = Array(day_two.growth_recommendations(3).get("recommended", []))
	_check(_growth_ids(day_two_items) == _growth_ids(day_one_items), "changing day, coins, reputation, and mastery does not reorder the fixed route")
	_check(bool(Dictionary(day_two_items[0]).get("can_purchase", false)) and bool(Dictionary(day_two_items[1]).get("can_purchase", false)), "D2 permits the qualified spreader and chili purchases")
	_check(StringName(Dictionary(day_two_items[2]).get("reason", &"")) == &"day_requirement", "the drink area remains locked until its D3 purchase day")
	_check(bool(day_two.purchase(&"growth.tool.pancake.wide_spreader").get("success", false)) and bool(day_two.purchase(&"growth.add_on.pancake.red_chili").get("success", false)), "D2 accepts one installation and one content purchase")
	var pending_items: Array = Array(day_two.growth_recommendations(3).get("recommended", []))
	_check(_growth_ids(pending_items) == _growth_ids(day_two_items), "pending purchases remain in their route positions until next-day activation")
	_check(bool(Dictionary(pending_items[0]).get("pending_activation", false)) and bool(Dictionary(pending_items[1]).get("pending_activation", false)), "pending route cards expose explicit activation state")
	day_two.set_day_open(false)
	var day_three_activation: Dictionary = day_two.begin_next_business_day()
	_check(bool(day_three_activation.get("success", false)) and int(day_three_activation.get("current_day", 0)) == 3, "D2 purchases activate on D3")
	_check(_growth_ids(Array(day_two.growth_recommendations(3).get("recommended", []))) == [&"growth.area.packaged_drink", &"growth.equipment.pancake.intermediate", &"growth.add_on.pancake.ham_sausage"], "activated growth leaves the queue and advances the fixed three-card window")

	var day_three = SERVICE.new({
		"coins": 100,
		"reputation": 20,
		"current_day": 3,
		"unlocked_area_ids": [&"area.pancake"],
		"area_mastery_details": {&"area.pancake": {"qualified": 6, "a_grade": 1}},
		"tutorial": {"completed_area_ids": [&"area.pancake"], "queue_area_ids": [], "active_kind": &"", "active_id": &""},
	})
	_check(bool(day_three.purchase_status(&"growth.area.packaged_drink").get("can_purchase", false)), "drink area opens for purchase on D3 when reputation, tutorial, and mastery are ready")

	var rich_late_state = SERVICE.new({
		"coins": 9999,
		"reputation": 999,
		"current_day": 30,
		"unlocked_area_ids": [&"area.pancake", &"area.packaged_drink", &"area.youtiao", &"area.fresh_soy_milk", &"area.steamer"],
		"area_mastery_details": {&"area.pancake": {"qualified": 99, "a_grade": 99}},
		"tutorial": {"completed_area_ids": [&"area.pancake", &"area.packaged_drink", &"area.youtiao", &"area.fresh_soy_milk", &"area.steamer"], "queue_area_ids": [], "active_kind": &"", "active_id": &""},
	})
	_check(_growth_ids(Array(rich_late_state.growth_recommendations(3).get("recommended", []))) == _growth_ids(day_one_items), "purchase eligibility never substitutes or reprioritizes fixed-route cards")

	var progression = SERVICE.new()
	var tutorial: Dictionary = progression.tutorial_snapshot()
	_check(tutorial.get("active_kind", &"") == &"area" and tutorial.get("active_id", &"") == &"area.pancake", "new progression begins with the pancake-area tutorial")
	_check(bool(progression.complete_tutorial(&"area", &"area.pancake").get("success", false)), "area tutorial completion is persisted by stable area ID")
	progression.coins = 100
	progression.reputation = 20
	progression.current_day = 3
	progression.area_mastery = {&"area.pancake": 6}
	progression.area_mastery_details = {&"area.pancake": {"qualified": 6, "a_grade": 0}}
	var install = progression.purchase(&"growth.area.packaged_drink")
	_check(install.get("success") and progression.coins == 70, "installation purchase charges immediately")
	var content = progression.purchase(&"growth.add_on.pancake.red_chili")
	_check(content.get("success") and progression.coins == 62, "content purchase may coexist with installation pending")
	_check(progression.purchase(&"growth.tool.pancake.wide_spreader").get("reason") == &"purchase_slot_occupied", "second installation pending is rejected")
	_check(not progression.begin_next_business_day().get("success"), "activation requires business day to be closed")
	progression.set_day_open(false)
	var activation = progression.begin_next_business_day()
	_check(activation.get("success") and progression.owns_area(&"area.packaged_drink"), "installation activates the following day")
	_check(progression.owns_stock(&"stock.pancake.sauce.red_chili"), "content activates the following day")
	_check(progression.pending_install_purchase.is_empty() and progression.pending_content_purchase.is_empty(), "activation clears both pending slots")
	var restored = SERVICE.new(progression.snapshot())
	_check(restored.owns_area(&"area.packaged_drink") and restored.owns_stock(&"stock.pancake.sauce.red_chili"), "snapshot restores activation state")
	var rollback = SERVICE.new({"coins": 50, "current_day": 4, "day_open": false, "pending_install_purchase": "growth.missing", "pending_content_purchase": ""})
	var rollback_before := rollback.snapshot()
	_check(not rollback.begin_next_business_day().get("success") and rollback.snapshot() == rollback_before, "invalid pending activation rolls back atomically")
	var press_locked = SERVICE.new({"coins": 100, "current_day": 20, "owned_growth_ids": [], "unlocked_area_ids": [&"area.pancake"]})
	_check(press_locked.purchase_status(&"growth.automation.pancake.press_once").get("reason") == &"growth_requirement", "press automation requires every confirmed pancake tool/device/automation prerequisite")
	var press_ready = SERVICE.new({"coins": 100, "current_day": 20, "owned_growth_ids": [&"growth.tool.pancake.wide_spreader", &"growth.equipment.pancake.intermediate", &"growth.automation.pancake.auto_sauce_brush"], "unlocked_area_ids": [&"area.pancake"]})
	var press_purchase: Dictionary = press_ready.purchase(&"growth.automation.pancake.press_once")
	_check(bool(press_purchase.get("success", false)) and int(press_purchase.get("charged_coins", 0)) == 60, "press automation costs the confirmed 60 coins after all prerequisites")
	if _failures.is_empty():
		print("FIVE_AREA_PROGRESSION_SERVICE_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("FIVE_AREA_PROGRESSION_SERVICE_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _growth_ids(items: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for item_variant in items:
		result.append(StringName(Dictionary(item_variant).get("growth_id", &"")))
	return result
