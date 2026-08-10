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
	_check(_growth_ids(day_one_items) == [&"growth.tool.pancake.wide_spreader", &"growth.add_on.pancake.red_chili", &"growth.area.packaged_drink"], "day-one settlement follows the first three fixed-route goals")
	var fixed_route := Array(CATALOG.FIXED_GROWTH_ROUTE)
	var unique_route := {}
	for growth_id_variant in fixed_route:
		unique_route[StringName(growth_id_variant)] = true
	_check(fixed_route.size() == CATALOG.GROWTH_DEFINITIONS.size() and unique_route.size() == fixed_route.size(), "fixed growth route covers every growth definition exactly once")
	_check(fixed_route.slice(0, 3) == Array(_growth_ids(day_one_items)), "the first recommendation window follows the catalog route")
	_check(day_one_items.size() == 3 and Array(day_one_recommendations.get("install", [])).size() == 2 and Array(day_one_recommendations.get("content", [])).size() == 1, "recommendation limit applies to the total across both purchase slots")
	_check(not bool(Dictionary(day_one_items[0]).get("can_purchase", true)) and StringName(Dictionary(day_one_items[0]).get("reason", &"")) == &"day_requirement", "wide spreader keeps its D2 gate")
	_check(bool(Dictionary(day_one_items[1]).get("can_purchase", false)), "reputation 20 satisfies the chili reputation gate on day one")
	_check(bool(Dictionary(day_one_items[2]).get("can_purchase", false)), "six qualified pancakes and tutorial completion satisfy the drink-area gate on day one")
	_check(not Array(Dictionary(day_one_items[0]).get("missing_requirements", [])).is_empty(), "locked recommendation retains its complete requirement list")
	day_one.set_day_open(false)
	var ready_day_end_items: Array = Array(day_one.growth_recommendations(3).get("recommended", []))
	_check(not bool(Dictionary(ready_day_end_items[0]).get("coin_guarantee", false)) and StringName(Dictionary(ready_day_end_items[0]).get("reason", &"")) == &"day_requirement", "an existing purchasable card prevents the day-end coin guarantee from replacing the frontier gate")

	var locked_day_end = SERVICE.new({
		"coins": 5,
		"reputation": 0,
		"current_day": 1,
		"day_open": false,
		"unlocked_area_ids": [&"area.pancake"],
		"area_mastery_details": {&"area.pancake": {"qualified": 0, "a_grade": 0}},
	})
	var locked_day_end_items: Array = Array(locked_day_end.growth_recommendations(3).get("recommended", []))
	var guaranteed_frontier := Dictionary(locked_day_end_items[0])
	_check(_growth_ids(locked_day_end_items) == _growth_ids(day_one_items), "coin guarantee keeps the fixed three-card IDs and route order")
	_check(bool(guaranteed_frontier.get("coin_guarantee", false)) and not bool(guaranteed_frontier.get("can_purchase", true)) and StringName(guaranteed_frontier.get("reason", &"")) == &"insufficient_coins", "all-locked day end marks only the route frontier as the coin guarantee")
	var guaranteed_requirements: Array = Array(guaranteed_frontier.get("missing_requirements", []))
	_check(guaranteed_requirements.size() == 1 and StringName(Dictionary(guaranteed_requirements[0]).get("reason", &"")) == &"insufficient_coins" and int(Dictionary(guaranteed_requirements[0]).get("price", 0)) == 12, "coin guarantee removes non-coin gates and retains the catalog price")
	_check(not bool(Dictionary(locked_day_end_items[1]).get("coin_guarantee", false)) and not bool(Dictionary(locked_day_end_items[2]).get("coin_guarantee", false)), "coin guarantee applies to exactly one card")
	locked_day_end.set_day_open(true)
	var open_day_status: Dictionary = locked_day_end.purchase_status(&"growth.tool.pancake.wide_spreader")
	_check(not bool(open_day_status.get("coin_guarantee", false)) and StringName(open_day_status.get("reason", &"")) == &"day_requirement", "coin guarantee never changes purchase status during an open business day")
	locked_day_end.set_day_open(false)
	locked_day_end.coins = 20
	var guarantee_purchase: Dictionary = locked_day_end.purchase(&"growth.tool.pancake.wide_spreader")
	_check(bool(guarantee_purchase.get("success", false)) and int(guarantee_purchase.get("charged_coins", 0)) == 12 and locked_day_end.coins == 8 and locked_day_end.pending_install_purchase == &"growth.tool.pancake.wide_spreader", "guaranteed frontier purchase uses the same effective status, price, and install slot")
	var pending_guarantee_status: Dictionary = locked_day_end.purchase_status(&"growth.tool.pancake.wide_spreader")
	_check(bool(pending_guarantee_status.get("pending_activation", false)) and not bool(pending_guarantee_status.get("coin_guarantee", false)), "purchased guarantee becomes a normal pending card instead of generating another guarantee")
	var guarantee_activation: Dictionary = locked_day_end.begin_next_business_day()
	_check(bool(guarantee_activation.get("success", false)) and locked_day_end.owns_growth(&"growth.tool.pancake.wide_spreader"), "guaranteed purchase still activates on the next business day")

	var occupied_frontier = SERVICE.new({
		"coins": 100,
		"reputation": 0,
		"current_day": 1,
		"day_open": false,
		"pending_install_purchase": "growth.area.packaged_drink",
	})
	var occupied_frontier_status := Dictionary(Array(occupied_frontier.growth_recommendations(3).get("recommended", []))[0])
	_check(not bool(occupied_frontier_status.get("coin_guarantee", false)) and StringName(occupied_frontier_status.get("reason", &"")) == &"purchase_slot_occupied", "occupied frontier purchase slot suppresses the guarantee without reordering cards")
	var completed_route = SERVICE.new({
		"coins": 9999,
		"current_day": 99,
		"day_open": false,
		"owned_growth_ids": Array(CATALOG.FIXED_GROWTH_ROUTE),
	})
	_check(Array(completed_route.growth_recommendations(3).get("recommended", [])).is_empty(), "completed route does not invent a repeatable coin guarantee")

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
	_check(bool(Dictionary(day_two_items[2]).get("can_purchase", false)), "the drink area uses qualified pancakes instead of a day gate")
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
	_check(bool(day_three.purchase_status(&"growth.area.packaged_drink").get("can_purchase", false)), "drink area opens when tutorial and qualified-pancake progress are ready")

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
	var press_ready = SERVICE.new({"coins": 100, "current_day": 20, "owned_growth_ids": [&"growth.tool.pancake.wide_spreader", &"growth.equipment.pancake.intermediate", &"growth.automation.pancake.auto_sauce_brush"], "unlocked_area_ids": [&"area.pancake", &"area.packaged_drink", &"area.youtiao", &"area.fresh_soy_milk", &"area.steamer"], "area_mastery_details": {&"area.pancake": {"qualified": 99, "a_grade": 20}}})
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
