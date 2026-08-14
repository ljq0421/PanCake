extends SceneTree

const MODEL := preload("res://scripts/gameplay/fresh_soy_milk_machine_model.gd")

const YELLOW := &"stock.fresh_soy_milk.yellow_bean"
const BLACK := &"stock.fresh_soy_milk.black_bean"
const RED := &"stock.fresh_soy_milk.red_bean"

var failures := PackedStringArray()


func _initialize() -> void:
	var one: RefCounted = MODEL.new(0, true)
	_check(bool(one.call("add_ingredient", YELLOW).get("success", false)) and int(one.call("snapshot").get("quantity", 0)) == 1, "one scoop forms a one-cup simple batch")
	_check(bool(one.call("add_ingredient", YELLOW).get("success", false)) and int(one.call("snapshot").get("quantity", 0)) == 2, "two repeated scoops form a two-cup batch")
	_check(StringName(one.call("add_ingredient", YELLOW).get("reason", &"")) == &"batch_capacity_reached", "tier-zero machine rejects a third cup")

	var four: RefCounted = MODEL.new(2, true)
	for _index in range(4):
		four.call("add_ingredient", YELLOW)
	_check(int(four.call("snapshot").get("quantity", 0)) == 4, "advanced machine forms a four-cup batch")

	var two_bean: RefCounted = MODEL.new(0, true)
	two_bean.call("add_ingredient", YELLOW)
	two_bean.call("add_ingredient", BLACK)
	var two_bean_snapshot := Dictionary(two_bean.call("snapshot"))
	_check(StringName(two_bean_snapshot.get("recipe_id", &"")) == &"recipe.fresh_soy_milk.multigrain" and PackedStringArray(two_bean_snapshot.get("ingredient_ids", [])).size() == 2, "equal two-bean composition resolves to multigrain")

	var three_bean: RefCounted = MODEL.new(2, true)
	for _cup in range(2):
		for stock_id in [YELLOW, BLACK, RED]:
			three_bean.call("add_ingredient", stock_id)
	var three_bean_snapshot := Dictionary(three_bean.call("snapshot"))
	_check(int(three_bean_snapshot.get("quantity", 0)) == 2 and PackedStringArray(three_bean_snapshot.get("ingredient_ids", [])).size() == 3, "equal three-bean counts form a two-cup multigrain batch")

	var incomplete: RefCounted = MODEL.new(0, true)
	incomplete.call("add_ingredient", YELLOW)
	incomplete.call("add_ingredient", YELLOW)
	incomplete.call("add_ingredient", BLACK)
	_check(StringName(incomplete.call("snapshot").get("recipe_id", &"")) == &"" and StringName(incomplete.call("start_water").get("reason", &"")) == &"water_not_available", "unequal bean counts cannot create a mixed-product batch")
	var cleared := Dictionary(incomplete.call("clear_hopper"))
	_check(bool(cleared.get("success", false)) and int(cleared.get("quantity", 0)) == 3 and StringName(incomplete.call("snapshot").get("state", &"")) == &"idle", "clear hopper reports every discarded scoop before water")

	_check(_water_grade_at(0.48) == &"C", "water below 25 is C")
	_check(_water_grade_at(0.50) == &"B", "water boundary 25 is B")
	_check(_water_grade_at(0.90) == &"A", "water boundary 45 is A")
	_check(_water_grade_at(1.20) == &"A", "water boundary 60 is A")
	_check(_water_grade_at(1.22) == &"B", "water 61 is B")
	_check(_water_grade_at(1.60) == &"B", "water boundary 80 is B")
	_check(_water_grade_at(1.62) == &"C", "water above 80 is C")

	for tier in range(3):
		_check(is_equal_approx(_duration_for(tier, [YELLOW]), 5.0 - tier), "yellow duration follows tier %d" % tier)
		_check(is_equal_approx(_duration_for(tier, [BLACK]), 6.0 - tier), "black duration follows tier %d" % tier)
		_check(is_equal_approx(_duration_for(tier, [YELLOW, BLACK]), 7.0 - tier), "multigrain duration follows tier %d" % tier)

	var c_grade: RefCounted = MODEL.new(0, true)
	c_grade.call("add_ingredient", YELLOW)
	c_grade.call("start_water")
	c_grade.call("advance_time", 0.2, false)
	c_grade.call("stop_water")
	c_grade.call("start")
	c_grade.call("advance_time", 5.0, false)
	var c_product := Dictionary(c_grade.call("preview_collect", 1))
	_check(StringName(c_product.get("grade", &"")) == &"C" and is_equal_approx(float(c_product.get("quality_multiplier", 0.0)), 0.5), "red-zone water creates a C cup at half payout")

	var protected_rack: RefCounted = MODEL.new(2, true)
	protected_rack.call("load_recipe", &"recipe.fresh_soy_milk.yellow_bean", 4)
	protected_rack.call("add_water")
	protected_rack.call("start")
	protected_rack.call("advance_time", 3.0, true)
	protected_rack.call("advance_time", 120.0, true)
	var rack := Array(protected_rack.call("snapshot").get("output_rack", []))
	var held := 0
	for cup_value in rack:
		var cup := Dictionary(cup_value)
		if not cup.is_empty() and bool(cup.get("infinite_hold", false)) and StringName(cup.get("state", &"")) == &"ready_safe":
			held += 1
	_check(held == 4 and StringName(protected_rack.call("snapshot").get("state", &"")) == &"idle", "advanced auto rack accepts the whole batch and preserves infinite hold")

	var quality_max: RefCounted = MODEL.new(0, true)
	quality_max.call("configure_upgrades", true, true)
	quality_max.call("add_ingredient", YELLOW)
	_check(bool(quality_max.call("start").get("success", false)) and StringName(quality_max.call("snapshot").get("water_grade", &"")) == &"A", "quality MAX skips manual water and starts at A grade")
	_finish()


func _water_grade_at(seconds: float) -> StringName:
	var machine: RefCounted = MODEL.new(0, true)
	machine.call("add_ingredient", YELLOW)
	machine.call("start_water")
	machine.call("advance_time", seconds, false)
	machine.call("stop_water")
	return StringName(machine.call("snapshot").get("water_grade", &""))


func _duration_for(tier: int, ingredients: Array) -> float:
	var machine: RefCounted = MODEL.new(tier, true)
	for stock_id in ingredients:
		machine.call("add_ingredient", StringName(stock_id))
	return float(machine.call("production_duration_seconds"))


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("FRESH_SOY_MILK_V5_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("FRESH_SOY_MILK_V5_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
