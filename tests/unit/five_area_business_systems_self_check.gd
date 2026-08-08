extends SceneTree

const REPORT := preload("res://scripts/services/business_report_service.gd")
const ATTENTION := preload("res://scripts/services/attention_service.gd")
const GOALS := preload("res://scripts/services/daily_goal_service.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	var report: RefCounted = REPORT.new()
	report.call("begin_day", 6)
	var sale := {"event_id": &"sale.1", "kind": &"sale", "area_id": &"area.pancake", "coins_delta": 20, "reputation_delta": 4, "details": {"terminal_state": &"completed"}}
	_check(bool(report.call("record_event", sale).get("changed", false)), "business report accepts a standard sale event")
	_check(not bool(report.call("record_event", sale).get("changed", true)), "business report deduplicates repeated event IDs")
	report.call("record_event", {"event_id": &"cost.1", "kind": &"stock_cost", "area_id": &"area.pancake", "coins_delta": -6})
	report.call("record_event", {"event_id": &"waste.1", "kind": &"waste", "area_id": &"area.steamer", "details": {"attributed_cost": 3}})
	var bill: Dictionary = report.call("build_bill")
	_check(int(bill.get("revenue", 0)) == 20 and int(bill.get("cash_cost", 0)) == 6 and int(bill.get("net_profit", 0)) == 14, "business report conserves revenue, cash cost, and profit")
	_check(int(bill.get("waste_cost", 0)) == 3 and int(Dictionary(bill.get("waste_by_area", {})).get("area.steamer", 0)) == 3, "business report attributes waste by area")
	var restored: RefCounted = REPORT.new(report.call("snapshot"))
	_check(not bool(restored.call("record_event", sale).get("changed", true)), "ledger deduplication survives snapshot restore")

	var attention: Array = ATTENTION.build_attention({
		&"device.youtiao_fryer": {"state": &"overcooking", "seconds_to_loss": 4.0},
		&"device.fresh_soy_milk_machine": {"state": &"ready_safe", "seconds_to_loss": 8.0},
		&"device.steamer": {"layers": [{"layer_index": 0, "state": &"ready_safe", "seconds_to_loss": 1.0}]},
	}, [{"state": &"ready_safe", "seconds_to_loss": 2.0}], {"slots": [{"slot_index": 0, "age_seconds": 30.0, "product": {"product_id": &"product.pancake.custom"}}]})
	_check(attention.size() == 3, "attention rail is capped at three entries")
	_check(StringName(Dictionary(attention[0]).get("severity", &"")) == &"red" and float(Dictionary(attention[0]).get("seconds_to_irreversible_loss", 99.0)) <= float(Dictionary(attention[1]).get("seconds_to_irreversible_loss", 99.0)), "attention rail sorts red irreversible loss first")

	var goals: RefCounted = GOALS.new()
	var areas := [&"area.pancake", &"area.packaged_drink", &"area.youtiao", &"area.fresh_soy_milk", &"area.steamer"]
	var created: Dictionary = goals.call("begin_day", {"current_day": 9, "unlocked_area_ids": areas, "tutorial_completed_area_ids": areas, "specialization": {}, "order_rng_seed": 123})
	_check(bool(created.get("created", false)) and StringName(Dictionary(created.get("goal", {})).get("goal_id", &"")) == &"goal.signature.combo_two_no_failure", "daily goal starts deterministically only after all five tutorials")
	goals.call("record_business_event", {"kind": &"sale", "quantity": 1, "details": {"complexity": &"double"}})
	var completed: Dictionary = goals.call("record_business_event", {"kind": &"sale", "quantity": 1, "details": {"complexity": &"double"}})
	_check(bool(completed.get("completed", false)) and not StringName(completed.get("reward_event_id", &"")).is_empty(), "daily goal emits one stable reward request on completion")
	var same_day: Dictionary = goals.call("begin_day", {"current_day": 9, "unlocked_area_ids": areas, "tutorial_completed_area_ids": areas, "specialization": {}, "order_rng_seed": 999})
	_check(not bool(same_day.get("created", true)) and bool(Dictionary(same_day.get("goal", {})).get("completed", false)), "save restore and same-day entry do not reroll a daily goal")

	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("FIVE_AREA_BUSINESS_SYSTEMS_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("FIVE_AREA_BUSINESS_SYSTEMS_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
