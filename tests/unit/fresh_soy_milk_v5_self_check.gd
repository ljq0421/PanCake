extends SceneTree

const MODEL := preload("res://scripts/gameplay/fresh_soy_milk_machine_model.gd")

const YELLOW := &"stock.fresh_soy_milk.yellow_bean"

var failures := PackedStringArray()


func _initialize() -> void:
	var retired_contract: RefCounted = MODEL.new(0, true)
	_check(_reason(retired_contract.call("add_ingredient", YELLOW)) == &"soy_bean_loading_retired", "bean loading remains explicitly retired")
	_check(_reason(retired_contract.call("start_water")) == &"soy_water_timing_retired", "manual water timing remains explicitly retired")
	_check(_reason(retired_contract.call("add_water")) == &"soy_water_timing_retired", "batch water loading remains explicitly retired")
	_check(_reason(retired_contract.call("start")) == &"soy_batch_production_retired", "batch production remains explicitly retired")
	_check(_reason(retired_contract.call("load_recipe", &"recipe.fresh_soy_milk.yellow_bean", 2)) == &"soy_batch_production_retired", "batch recipe loading remains explicitly retired")
	_check(_reason(retired_contract.call("collect_output", 0)) == &"soy_cup_rack_retired", "the former output rack remains explicitly retired")

	var manual: RefCounted = MODEL.new(0, true)
	_check(bool(manual.call("take_empty_cup").get("success", false)), "the current station takes one empty cup")
	var half_fill := Dictionary(manual.call("fill_held_cup", 0.4))
	var half_cup := Dictionary(half_fill.get("cup", {}))
	_check(bool(half_fill.get("success", false)) and is_equal_approx(float(half_cup.get("fill_ratio", 0.0)), 0.5) and StringName(half_cup.get("grade", &"")) == &"C", "manual serving grades a half-filled cup without the retired production loop")

	var automatic: RefCounted = MODEL.new(0, true)
	automatic.call("configure_upgrades", true, true)
	automatic.call("take_empty_cup")
	var auto_fill := Dictionary(automatic.call("fill_held_cup", 0.01))
	_check(bool(auto_fill.get("success", false)) and is_equal_approx(float(auto_fill.get("fill_ratio", 0.0)), 1.0), "the current auto-fill upgrade fills one foreground cup")

	var advanced: RefCounted = MODEL.new(0, true)
	advanced.call("configure_upgrades", true, true, true, true, true)
	advanced.call("take_empty_cup")
	advanced.call("take_empty_cup")
	var double_fill := Dictionary(advanced.call("fill_held_cup", 0.01, 2))
	var advanced_snapshot := Dictionary(advanced.call("snapshot"))
	_check(bool(double_fill.get("success", false)) and int(double_fill.get("quantity", 0)) == 2 and int(advanced_snapshot.get("ready_cup_count", 0)) == 2, "the advanced machine fills two physical cup outlets")
	_check(Array(advanced_snapshot.get("output_rack", [])).is_empty(), "the current station does not recreate the retired output rack")

	advanced.call("configure_available_recipes", [
		&"recipe.fresh_soy_milk.yellow_bean",
		&"recipe.fresh_soy_milk.black_bean",
		&"recipe.fresh_soy_milk.red_bean",
		&"recipe.fresh_soy_milk.multigrain",
	])
	_check(Array(advanced.call("snapshot").get("available_recipe_ids", [])) == [&"recipe.fresh_soy_milk.yellow_bean"], "only the currently supported yellow-soy recipe is available")
	_finish()


func _reason(result: Dictionary) -> StringName:
	return StringName(result.get("reason", &""))


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("FRESH_SOY_MILK_SERVING_MODEL_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("FRESH_SOY_MILK_SERVING_MODEL_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
