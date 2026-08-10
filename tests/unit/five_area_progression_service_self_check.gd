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
	_check(StringName(Dictionary(ready_day_end_items[0]).get("reason", &"")) == &"day_requirement", "closing the day never replaces the frontier's real day gate")

	var locked_day_end = SERVICE.new({
		"coins": 5,
		"reputation": 0,
		"current_day": 1,
		"day_open": false,
		"unlocked_area_ids": [&"area.pancake"],
		"area_mastery_details": {&"area.pancake": {"qualified": 0, "a_grade": 0}},
	})
	var locked_day_end_items: Array = Array(locked_day_end.growth_recommendations(3).get("recommended", []))
	var locked_frontier := Dictionary(locked_day_end_items[0])
	_check(_growth_ids(locked_day_end_items) == _growth_ids(day_one_items), "all-locked day end keeps the fixed three-card IDs and route order")
	_check(not bool(locked_frontier.get("can_purchase", true)) and StringName(locked_frontier.get("reason", &"")) == &"day_requirement", "all-locked day end keeps the frontier's real primary requirement")
	_check(_requirement_reasons(Array(locked_frontier.get("missing_requirements", []))) == [&"day_requirement", &"insufficient_coins"], "all-locked day end retains every real frontier requirement")
	locked_day_end.coins = 20
	var blocked_frontier_purchase: Dictionary = locked_day_end.purchase(&"growth.tool.pancake.wide_spreader")
	_check(not bool(blocked_frontier_purchase.get("success", true)) and StringName(blocked_frontier_purchase.get("reason", &"")) == &"day_requirement" and locked_day_end.coins == 20 and locked_day_end.pending_install_purchase.is_empty(), "direct purchase cannot bypass the frontier's real requirement")

	var occupied_frontier = SERVICE.new({
		"coins": 100,
		"reputation": 0,
		"current_day": 1,
		"day_open": false,
		"pending_install_purchase": "growth.area.packaged_drink",
	})
	var occupied_frontier_status := Dictionary(Array(occupied_frontier.growth_recommendations(3).get("recommended", []))[0])
	_check(StringName(occupied_frontier_status.get("reason", &"")) == &"purchase_slot_occupied", "occupied frontier purchase slot remains the real primary requirement without reordering cards")
	var completed_route = SERVICE.new({
		"coins": 9999,
		"current_day": 99,
		"day_open": false,
		"owned_growth_ids": Array(CATALOG.FIXED_GROWTH_ROUTE),
	})
	_check(Array(completed_route.growth_recommendations(3).get("recommended", [])).is_empty(), "completed route does not invent a repeatable growth item")

	var oil_cake_reservation = SERVICE.new({
		"coins": 844,
		"reputation": 1004,
		"current_day": 12,
		"day_open": false,
		"unlocked_area_ids": [&"area.pancake", &"area.packaged_drink", &"area.youtiao"],
		"owned_growth_ids": [
			&"growth.tool.pancake.wide_spreader",
			&"growth.add_on.pancake.red_chili",
			&"growth.area.packaged_drink",
			&"growth.equipment.pancake.intermediate",
			&"growth.add_on.pancake.ham_sausage",
			&"growth.product.packaged_drink.soy_milk",
			&"growth.equipment.packaged_drink.intermediate",
			&"growth.add_on.pancake.meat_floss",
			&"growth.assist.youtiao.temperature_indicator",
		],
		"tutorial": {"completed_area_ids": [&"area.pancake"], "queue_area_ids": [&"area.packaged_drink"], "active_kind": &"area", "active_id": &"area.packaged_drink"},
	})
	var oil_cake_items_before: Array = Array(oil_cake_reservation.growth_recommendations(3).get("recommended", []))
	_check(_growth_ids(oil_cake_items_before) == [&"growth.area.youtiao", &"growth.recipe.youtiao.oil_cake", &"growth.capacity.stock.intermediate"], "attachment state exposes the same fryer, oil-cake, and stock-capacity window")
	var fryer_before := Dictionary(oil_cake_items_before[0])
	_check(not bool(fryer_before.get("can_purchase", true)) and StringName(fryer_before.get("reason", &"")) == &"tutorial_requirement", "fryer is locked by the unfinished packaged-drink tutorial before reserving oil cake")
	_check(bool(Dictionary(oil_cake_items_before[1]).get("can_purchase", false)) and bool(Dictionary(oil_cake_items_before[2]).get("can_purchase", false)), "oil cake and stock capacity are independently purchasable before reserving content")
	var oil_cake_purchase: Dictionary = oil_cake_reservation.purchase(&"growth.recipe.youtiao.oil_cake")
	_check(bool(oil_cake_purchase.get("success", false)) and oil_cake_reservation.coins == 826 and oil_cake_reservation.pending_content_purchase == &"growth.recipe.youtiao.oil_cake", "oil-cake reservation charges 18 coins and occupies only the content slot")
	var oil_cake_items_after: Array = Array(oil_cake_reservation.growth_recommendations(3).get("recommended", []))
	var fryer_after := Dictionary(oil_cake_items_after[0])
	_check(_growth_ids(oil_cake_items_after) == _growth_ids(oil_cake_items_before), "oil-cake reservation keeps the fixed card IDs and route order")
	_check(not bool(fryer_after.get("can_purchase", true)) and StringName(fryer_after.get("reason", &"")) == &"tutorial_requirement" and Array(fryer_after.get("missing_requirements", [])) == Array(fryer_before.get("missing_requirements", [])), "oil-cake reservation does not change the fryer's tutorial condition")
	_check(bool(Dictionary(oil_cake_items_after[1]).get("pending_activation", false)), "reserved oil cake remains visible as pending activation")
	_check(StringName(Dictionary(oil_cake_items_after[2]).get("reason", &"")) == &"purchase_slot_occupied", "other content growth reflects the occupied content slot")
	var blocked_fryer_purchase: Dictionary = oil_cake_reservation.purchase(&"growth.area.youtiao")
	_check(not bool(blocked_fryer_purchase.get("success", true)) and StringName(blocked_fryer_purchase.get("reason", &"")) == &"tutorial_requirement" and oil_cake_reservation.pending_install_purchase.is_empty(), "direct fryer purchase remains blocked after reserving oil cake")

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

	var damaged_starter_save = SERVICE.new({
		"coins": 37,
		"reputation": 4,
		"current_day": 3,
		"unlocked_area_ids": [&"area.youtiao"],
		"device_tiers": {&"device.youtiao_fryer": 0},
		"unlocked_recipe_ids": [&"recipe.youtiao.plain"],
		"unlocked_product_ids": [&"product.youtiao.plain"],
		"unlocked_stock_ids": [&"stock.youtiao.plain_dough"],
	})
	_check(damaged_starter_save.coins == 37 and damaged_starter_save.reputation == 4 and damaged_starter_save.current_day == 3, "starter repair preserves economy and business-day progress")
	_check(damaged_starter_save.owns_area(&"area.pancake") and damaged_starter_save.device_tier(&"device.pancake_griddle") == 0, "starter repair restores the permanent pancake area and base griddle")
	_check(damaged_starter_save.owns_recipe(&"recipe.pancake.base") and damaged_starter_save.owns_product(&"product.pancake.custom"), "starter repair restores the permanent pancake recipe and product")
	for stock_id in [&"stock.pancake.batter", &"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.scallion", &"stock.pancake.sauce.sweet_flour"]:
		_check(damaged_starter_save.owns_stock(stock_id), "starter repair restores %s ownership" % stock_id)
	_check(damaged_starter_save.owns_area(&"area.youtiao") and damaged_starter_save.owns_recipe(&"recipe.youtiao.plain") and damaged_starter_save.owns_stock(&"stock.youtiao.plain_dough"), "starter repair preserves later area, recipe, and stock unlocks")
	var repaired_once := damaged_starter_save.snapshot()
	_check(SERVICE.new(repaired_once).snapshot() == repaired_once, "starter repair is idempotent across repeated save loads")

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
	var legacy_unfinished_drink = SERVICE.new({
		"unlocked_area_ids": [&"area.pancake", &"area.packaged_drink"],
		"tutorial": {"completed_area_ids": [&"area.pancake"], "queue_area_ids": [], "active_kind": &"", "active_id": &""},
	})
	var reconciled_tutorial: Dictionary = legacy_unfinished_drink.advance_tutorial_for_new_business_day()
	_check(StringName(reconciled_tutorial.get("active_kind", &"")) == &"area" and StringName(reconciled_tutorial.get("active_id", &"")) == &"area.packaged_drink", "old unlocked saves recover the unfinished drink tutorial at the next day boundary")
	var legacy_multi_area = SERVICE.new({
		"unlocked_area_ids": [&"area.pancake", &"area.packaged_drink", &"area.youtiao", &"area.fresh_soy_milk", &"area.steamer"],
		"tutorial": {"completed_area_ids": [&"area.pancake", &"area.packaged_drink"], "queue_area_ids": [], "active_kind": &"", "active_id": &""},
	})
	var recovered_multi := Dictionary(legacy_multi_area.advance_tutorial_for_new_business_day())
	_check(StringName(recovered_multi.get("active_id", &"")) == &"area.youtiao" and Array(legacy_multi_area.tutorial_snapshot().get("queue_area_ids", [])).slice(0, 3) == [&"area.youtiao", &"area.fresh_soy_milk", &"area.steamer"], "old saves recover every unfinished owned area tutorial in unlock order")
	legacy_multi_area.complete_tutorial(&"area", &"area.youtiao")
	var reloaded_multi = SERVICE.new(legacy_multi_area.snapshot())
	reloaded_multi.advance_tutorial_for_new_business_day()
	_check(Array(reloaded_multi.tutorial_snapshot().get("completed_area_ids", [])).has(&"area.youtiao") and StringName(reloaded_multi.tutorial_snapshot().get("active_id", &"")) == &"area.fresh_soy_milk", "completed area tutorial is never regenerated after save reload")
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


func _requirement_reasons(requirements: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for requirement_variant in requirements:
		result.append(StringName(Dictionary(requirement_variant).get("reason", &"")))
	return result
