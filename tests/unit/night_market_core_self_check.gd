extends SceneTree

const CATALOG := preload("res://scripts/data/night_market_catalog.gd")
const MODEL := preload("res://scripts/gameplay/night_market_production_model.gd")
const SCORER := preload("res://scripts/gameplay/night_market_scorer.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var model: RefCounted = MODEL.new()
	_check(bool(Dictionary(model.call("add_grill_skewer", CATALOG.ITEM_LAMB, CATALOG.ZONE_MEDIUM)).get("success", false)), "lamb enters a free medium-heat slot")
	model.call("advance", 7.0)
	var half := Dictionary(Dictionary(model.call("snapshot")).get("grill_slots", [])[2])
	_check(is_equal_approx(float(half.get("front_heat", 0.0)), 49.0) and is_zero_approx(float(half.get("back_heat", 0.0))), "only the face toward the charcoal accumulates heat")
	model.call("flip_grill_slot", 2)
	model.call("advance", 7.0)
	model.call("plate_grill_slot", 2)
	model.call("season_last_unseasoned", CATALOG.SEASONING_CUMIN)
	model.call("add_fryer_item", CATALOG.ITEM_LOTUS)
	model.call("lower_fryer")
	model.call("advance", 5.5)
	model.call("lift_fryer")
	model.call("advance", 1.2)
	model.call("plate_fryer")
	model.call("season_last_unseasoned", CATALOG.SEASONING_SALT_PEPPER)
	var order := {
		"item_ids": [CATALOG.ITEM_LAMB, CATALOG.ITEM_LOTUS],
		"time_limit": 60.0,
	}
	var score := Dictionary(SCORER.evaluate(model.call("snapshot"), order))
	_check(float(score.get("overall_score", 0.0)) >= 90.0 and str(score.get("grade", "")) == "A", "balanced grill and well-drained fryer produce an A-grade combo")
	var restored: RefCounted = MODEL.new(model.call("snapshot"))
	_check(Dictionary(restored.call("snapshot")) == Dictionary(model.call("snapshot")), "production snapshot round-trips with both lines and the shared plate")

	var neglected: RefCounted = MODEL.new()
	neglected.call("add_grill_skewer", CATALOG.ITEM_LAMB, CATALOG.ZONE_MEDIUM)
	neglected.call("advance", 14.0)
	neglected.call("plate_grill_slot", 2)
	neglected.call("season_last_unseasoned", CATALOG.SEASONING_CUMIN)
	var neglected_score := Dictionary(SCORER.evaluate(neglected.call("snapshot"), {"item_ids": [CATALOG.ITEM_LAMB], "time_limit": 40.0}))
	_check(float(Dictionary(Array(neglected_score.get("item_results", []))[0]).get("balance_score", 100.0)) < 30.0, "never flipping a skewer fails the two-sided balance score")
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("NIGHT_MARKET_CORE_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("NIGHT_MARKET_CORE_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
