extends SceneTree

const MODEL := preload("res://scripts/gameplay/fresh_soy_milk_machine_model.gd")
const CATALOG := preload("res://scripts/data/five_area_catalog.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	for stock_id in [
		&"stock.fresh_soy_milk.yellow_bean",
		&"stock.fresh_soy_milk.black_bean",
		&"stock.fresh_soy_milk.red_bean",
		&"stock.fresh_soy_milk.multigrain",
	]:
		_check(is_equal_approx(float(CATALOG.stock_definition(stock_id).get("refill_seconds", 0.0)), 0.25), "%s refills in 0.25 seconds" % stock_id)

	var manual: RefCounted = MODEL.new(0, true)
	_make_batch(manual, 2)
	manual.call("advance_time", 5.0, false)
	_check(manual.call("preview_collect", 1).get("reason") == &"cup_required" and not bool(Dictionary(manual.call("snapshot")).get("manual_cup_ready", true)), "completed soy cannot be delivered before the player fills a cup")
	_check(bool(manual.call("fill_manual_cup").get("success", false)) and bool(Dictionary(manual.call("snapshot")).get("manual_cup_ready", false)), "manual cup action prepares exactly one cup")
	var first_manual := Dictionary(manual.call("collect", 1))
	_check(bool(first_manual.get("success", false)) and int(first_manual.get("remaining_quantity", 0)) == 1 and manual.call("preview_collect", 1).get("reason") == &"cup_required", "a multi-cup batch requires another cup after each collected serving")
	manual.call("fill_manual_cup")
	_check(bool(manual.call("collect", 1).get("success", false)) and StringName(Dictionary(manual.call("snapshot")).get("state", &"")) == &"idle", "the final manually filled cup releases the machine")

	var migrated: RefCounted = MODEL.new()
	migrated.call("load_snapshot", {
		"owned": true, "tier": 0, "state": &"ready_safe",
		"recipe_id": &"recipe.fresh_soy_milk.yellow_bean", "quantity": 1,
	})
	_check(bool(Dictionary(migrated.call("snapshot")).get("manual_cup_ready", false)) and bool(migrated.call("collect", 1).get("success", false)), "old completed-soy snapshot migrates as an already prepared product cup")

	var machine: RefCounted = MODEL.new(0, true)
	_make_batch(machine, 2)
	machine.call("advance_time", 5.0, false)
	machine.call("advance_time", 16.0, false)
	var spoiled := Dictionary(machine.call("snapshot"))
	_check(StringName(spoiled.get("state", &"")) == &"spoiled" and int(spoiled.get("quantity", 0)) == 2, "machine outlet represents the whole spoiled batch")
	var discarded_batch := Dictionary(machine.call("discard"))
	_check(bool(discarded_batch.get("success", false)) and int(discarded_batch.get("quantity", 0)) == 2 and StringName(Dictionary(machine.call("snapshot")).get("state", &"")) == &"idle", "discarding the machine outlet clears the whole batch")

	machine = MODEL.new(0, true)
	_make_batch(machine, 2)
	machine.call("advance_time", 5.0, true)
	machine.call("advance_time", 16.0, true)
	var rack := Array(Dictionary(machine.call("snapshot")).get("output_rack", []))
	var spoiled_count := 0
	for cup_variant in rack:
		if StringName(Dictionary(cup_variant).get("state", &"")) == &"spoiled":
			spoiled_count += 1
	var discarded_cup := Dictionary(machine.call("discard_output", 0))
	var rack_after := Array(Dictionary(machine.call("snapshot")).get("output_rack", []))
	var remaining_count := 0
	for cup_variant in rack_after:
		if not Dictionary(cup_variant).is_empty():
			remaining_count += 1
	_check(spoiled_count == 2 and bool(discarded_cup.get("success", false)) and remaining_count == 1, "rack disposal removes only the selected spoiled cup")
	_finish()


func _make_batch(machine: RefCounted, quantity: int) -> void:
	machine.call("load_recipe", &"recipe.fresh_soy_milk.yellow_bean", quantity)
	machine.call("add_water")
	machine.call("start")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("FRESH_SOY_MILK_SPOIL_DISCARD_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("FRESH_SOY_MILK_SPOIL_DISCARD_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
