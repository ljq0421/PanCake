extends SceneTree

const CATALOG := preload("res://scripts/data/workstation_expansion_catalog.gd")
const EQUIPMENT_BATCH_MODEL := preload("res://scripts/gameplay/equipment_batch_model.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	_check_catalog_specs()
	_check_soy_batch_rules()
	_check_quality_holds()
	_finish()


func _check_catalog_specs() -> void:
	_check(CATALOG.device_tier(CATALOG.DEVICE_SOY_MILK, CATALOG.TIER_BASIC).capacity == 2, "basic soy capacity is two")
	_check(CATALOG.device_tier(CATALOG.DEVICE_SOY_MILK, CATALOG.TIER_BASIC).duration_seconds == 16.0, "basic soy duration is sixteen seconds")
	_check(CATALOG.device_tier(CATALOG.DEVICE_SOY_MILK, CATALOG.TIER_INTERMEDIATE).duration_seconds == 12.0, "intermediate soy duration is twenty-five percent shorter")
	_check(CATALOG.device_tier(CATALOG.DEVICE_SOY_MILK, CATALOG.TIER_ADVANCED).capacity == 4, "advanced soy capacity is four")
	_check(CATALOG.device_tier(CATALOG.DEVICE_YOUTIAO, CATALOG.TIER_BASIC).duration_seconds == 12.0, "basic youtiao duration is twelve seconds")
	_check(CATALOG.device_tier(CATALOG.DEVICE_YOUTIAO, CATALOG.TIER_INTERMEDIATE).duration_seconds == 9.0, "intermediate youtiao duration is nine seconds")
	_check(CATALOG.device_tier(CATALOG.DEVICE_YOUTIAO, CATALOG.TIER_ADVANCED).capacity == 4, "advanced youtiao capacity is four")
	_check(CATALOG.main_recipe_ids(CATALOG.DEVICE_SOY_MILK).size() >= 3, "soy recipes are appendable and include the first three beans")
	_check(CATALOG.main_recipe_ids(CATALOG.DEVICE_YOUTIAO).size() >= 3, "youtiao recipes are appendable and include three doughs")


func _check_soy_batch_rules() -> void:
	var machine: RefCounted = EQUIPMENT_BATCH_MODEL.new(CATALOG.DEVICE_SOY_MILK)
	_check(_reason(machine.call("load_input", CATALOG.RECIPE_SOY_YELLOW, 1)) == &"equipment_not_owned", "unowned equipment rejects loading")
	machine.call("configure_owned", CATALOG.TIER_BASIC)
	_check(bool(machine.call("load_input", CATALOG.RECIPE_SOY_YELLOW, 1).success), "a partial soy batch can be loaded")
	_check(_reason(machine.call("load_input", CATALOG.RECIPE_SOY_RED, 1)) == &"mixed_main_recipe", "one batch cannot mix main recipes")
	_check(bool(machine.call("load_input", CATALOG.RECIPE_SOY_YELLOW, 1).success), "matching recipe can fill remaining capacity")
	_check(_reason(machine.call("load_input", CATALOG.RECIPE_SOY_YELLOW, 1)) == &"capacity_exceeded", "maximum capacity is enforced")
	_check(_reason(machine.call("start")) == &"missing_required_action", "soy cannot start before water is added")
	_check(bool(machine.call("perform_action", CATALOG.ACTION_ADD_WATER).success), "soy accepts the water action")
	_check(bool(machine.call("start").success), "soy starts without requiring a full-only special case")
	_check(_reason(machine.call("load_input", CATALOG.RECIPE_SOY_YELLOW, 1)) == &"processing_in_progress", "processing equipment rejects more input")
	machine.call("advance_time", 15.999)
	_check(machine.get("state") == EQUIPMENT_BATCH_MODEL.STATE_PROCESSING, "soy is not complete before sixteen seconds")
	machine.call("advance_time", 0.001)
	_check(machine.get("state") == EQUIPMENT_BATCH_MODEL.STATE_HOLDING, "completed soy enters non-decaying hold")
	_check(is_equal_approx(float(machine.get("quality")), 100.0), "soy quality does not decay")
	_check(_reason(machine.call("start")) == &"finished_output_occupies_capacity", "finished output blocks another start")
	var first: Dictionary = machine.call("collect", 1)
	_check(bool(first.success) and int(first.remaining_quantity) == 1 and int(first.released_quantity) == 1, "partial collection reports released and remaining capacity")
	_check(machine.get("state") == EQUIPMENT_BATCH_MODEL.STATE_HOLDING, "remaining finished soy still occupies the machine")
	var second: Dictionary = machine.call("collect", 1)
	_check(bool(second.success) and machine.get("state") == EQUIPMENT_BATCH_MODEL.STATE_IDLE, "collecting the full batch releases the machine")


func _check_quality_holds() -> void:
	var fryer: RefCounted = EQUIPMENT_BATCH_MODEL.new(CATALOG.DEVICE_YOUTIAO, CATALOG.TIER_BASIC, true)
	_check(bool(fryer.call("load_input", CATALOG.RECIPE_YOUTIAO_PLAIN, 1).success), "one youtiao may start below maximum capacity")
	_check(bool(fryer.call("start").success), "loaded fryer starts")
	fryer.call("advance_time", 12.0)
	_check(fryer.get("state") == EQUIPMENT_BATCH_MODEL.STATE_SAFE_HOLD, "basic fryer enters safety hold at completion")
	fryer.call("advance_time", 5.0)
	_check(fryer.get("state") == EQUIPMENT_BATCH_MODEL.STATE_SAFE_HOLD, "the complete five-second safety period does not decay")
	_check(is_equal_approx(float(fryer.get("quality")), 100.0), "quality is unchanged at the safety threshold")
	fryer.call("advance_time", 0.001)
	_check(fryer.get("state") == EQUIPMENT_BATCH_MODEL.STATE_DECAYING, "quality decay starts only after the threshold")
	_check(float(fryer.get("quality")) < 100.0, "quality uses the data-driven decay rate after safety")
	_check(_reason(fryer.call("collect", 1)) == &"missing_required_action", "youtiao must be drained before collection")
	_check(bool(fryer.call("perform_action", CATALOG.ACTION_DRAIN_OIL).success), "completed youtiao accepts drain action")
	_check(bool(fryer.call("collect", 1).success), "drained youtiao can be collected")

	var advanced: RefCounted = EQUIPMENT_BATCH_MODEL.new(CATALOG.DEVICE_YOUTIAO, CATALOG.TIER_ADVANCED, true)
	_check(bool(advanced.call("load_input", CATALOG.RECIPE_YOUTIAO_SESAME, 4).success), "advanced fryer accepts four matching items")
	advanced.call("start")
	advanced.call("advance_time", 1009.0)
	_check(advanced.get("state") == EQUIPMENT_BATCH_MODEL.STATE_HOLDING, "advanced fryer holds indefinitely")
	_check(is_equal_approx(float(advanced.get("quality")), 100.0) and int(advanced.get("loaded_quantity")) == 4, "advanced held output keeps quality and occupies all capacity")


func _reason(result: Dictionary) -> StringName:
	return result.get("reason", &"") as StringName


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("EQUIPMENT_BATCH_SELF_CHECK_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
