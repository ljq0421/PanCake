extends SceneTree

const MODEL := preload("res://scripts/gameplay/youtiao_fryer_model.gd")
const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
var _failures: Array[String] = []


func _initialize() -> void:
	var chicken_recipe := CATALOG.recipe_definition(&"recipe.chicken.cutlet")
	var chicken_product := CATALOG.product_definition(&"product.chicken.cutlet")
	_check(not chicken_recipe.is_empty() and float(chicken_recipe.get("duration_seconds", 0.0)) == 12.0, "chicken cutlet recipe fries for twelve seconds")
	_check(int(chicken_product.get("base_sell_price", 0)) == 8 and int(chicken_product.get("order_weight", 0)) == 25, "chicken cutlet catalog balance is configured")
	var advanced_growth := CATALOG.growth_definition(&"growth.equipment.youtiao.advanced")
	var dual_growth := CATALOG.growth_definition(&"growth.equipment.youtiao.dual_basket")
	var dual_mastery := Dictionary(dual_growth.get("requires_mastery", {}))
	var dual_youtiao_mastery := Dictionary(dual_mastery.get(&"area.youtiao", {}))
	_check(not Array(advanced_growth.get("unlock_product_ids", [])).has(&"product.chicken.cutlet"), "advanced youtiao fryer does not unlock chicken")
	_check(int(dual_growth.get("price", 0)) == 72 and int(dual_youtiao_mastery.get("qualified", 0)) == 12 and Array(dual_growth.get("requires_growth_ids", [])).has(&"growth.equipment.youtiao.advanced"), "dual fryer costs 72 and follows the advanced fryer after 12 qualified youtiao")

	var basic: RefCounted = MODEL.new(0, true)
	_check(not bool(basic.call("lane_enabled", &"right")), "basic fryer keeps chicken lane locked")
	_check(StringName(Dictionary(basic.call("load_lane_recipe", &"right", &"recipe.chicken.cutlet", 1)).get("reason", &"")) == &"lane_not_unlocked", "basic fryer rejects chicken loading")
	var advanced_only: RefCounted = MODEL.new(1, true)
	_check(not bool(advanced_only.call("lane_enabled", &"right")), "advanced youtiao fryer remains a single left basket")

	var advanced: RefCounted = MODEL.new(2, true)
	_check(bool(advanced.call("lane_enabled", &"left")) and bool(advanced.call("lane_enabled", &"right")), "dual fryer enables both independent lanes")
	_check(bool(Dictionary(advanced.call("load_lane_recipe", &"left", &"recipe.youtiao.plain", 2)).get("success", false)), "left lane loads youtiao")
	_check(bool(Dictionary(advanced.call("load_lane_recipe", &"right", &"recipe.chicken.cutlet", 2)).get("success", false)), "right lane loads chicken")
	_check(StringName(Dictionary(advanced.call("load_lane_recipe", &"left", &"recipe.chicken.cutlet", 1)).get("reason", &"")) == &"invalid_recipe", "left lane rejects chicken")
	_check(StringName(Dictionary(advanced.call("load_lane_recipe", &"right", &"recipe.youtiao.plain", 1)).get("reason", &"")) == &"invalid_recipe", "right lane rejects youtiao")
	advanced.call("start_lane", &"left")
	advanced.call("start_lane", &"right")
	advanced.call("advance_lanes", 10.0, true)
	_check(StringName(Dictionary(advanced.call("lane_snapshot", &"left")).get("state", &"")) == &"draining" and StringName(Dictionary(advanced.call("lane_snapshot", &"right")).get("state", &"")) == &"frying", "left auto-lifts while chicken continues frying")
	advanced.call("advance_lanes", 2.0, true)
	_check(StringName(Dictionary(advanced.call("lane_snapshot", &"left")).get("state", &"")) == &"ready_to_collect" and StringName(Dictionary(advanced.call("lane_snapshot", &"right")).get("state", &"")) == &"draining", "both lanes transition independently")
	advanced.call("advance_lanes", 2.0, true)
	var chicken := Dictionary(advanced.call("collect_lane_slot", &"right", 0))
	_check(bool(chicken.get("success", false)) and StringName(chicken.get("product_id", &"")) == &"product.chicken.cutlet", "right lane collects chicken cutlet products")
	var restored: RefCounted = MODEL.new()
	restored.call("load_snapshot", advanced.call("snapshot"))
	_check(StringName(Dictionary(restored.call("lane_snapshot", &"right")).get("recipe_id", &"")) == &"recipe.chicken.cutlet", "dual-lane snapshot restores chicken progress")

	if _failures.is_empty():
		print("CHICKEN_FRYER_SELF_CHECK_PASS")
		quit(0)
	else:
		print("CHICKEN_FRYER_SELF_CHECK_FAIL\n" + "\n".join(_failures))
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
