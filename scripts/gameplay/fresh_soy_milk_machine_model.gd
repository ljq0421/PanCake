class_name FreshSoyMilkMachineModel
extends RefCounted

## The soy station is intentionally a serving station now: the machine keeps
## ready-made soy milk, while the player takes a cup, holds it at the spout,
## chooses sweetness, and then delivers it. Bean loading, water timing and
## batch production were retired with the former machine loop.

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const DEVICE_ID := &"device.fresh_soy_milk_machine"
const AREA_ID := &"area.fresh_soy_milk"
const DEFAULT_RECIPE_ID := &"recipe.fresh_soy_milk.yellow_bean"
const FULL_CUP_SECONDS := 0.8
const SOY_RECIPE_IDS: Array[StringName] = [
	&"recipe.fresh_soy_milk.yellow_bean",
	&"recipe.fresh_soy_milk.black_bean",
	&"recipe.fresh_soy_milk.red_bean",
	&"recipe.fresh_soy_milk.multigrain",
]

const CUP_READY := &"ready"
const CUP_HELD_EMPTY := &"held_empty"
const CUP_FILLED := &"filled"

var owned := false
var tier := 0
var recipe_id: StringName = DEFAULT_RECIPE_ID
var cup_state: StringName = CUP_READY
var cup: Dictionary = {}
var available_recipe_ids: Array[StringName] = [DEFAULT_RECIPE_ID]
var fill_guide_enabled := false
var auto_fill_enabled := false
var quality_bonus := 0.0


func _init(next_tier: int = 0, is_owned: bool = false) -> void:
	if is_owned:
		configure_owned(next_tier)


func configure_owned(next_tier: int) -> Dictionary:
	if CATALOG.device_tier(DEVICE_ID, next_tier).is_empty():
		return _failure(&"invalid_device_tier")
	owned = true
	tier = next_tier
	return _success()


func configure_upgrades(has_fill_guide: bool, has_auto_fill: bool, has_quality_upgrade: bool) -> void:
	fill_guide_enabled = has_fill_guide
	auto_fill_enabled = has_auto_fill
	quality_bonus = 10.0 if has_quality_upgrade else 0.0


func configure_available_recipes(next_recipe_ids: Array) -> void:
	available_recipe_ids.clear()
	for candidate in next_recipe_ids:
		if SOY_RECIPE_IDS.has(candidate) and not available_recipe_ids.has(candidate):
			available_recipe_ids.append(candidate)
	if not available_recipe_ids.has(DEFAULT_RECIPE_ID):
		available_recipe_ids.push_front(DEFAULT_RECIPE_ID)
	if not available_recipe_ids.has(recipe_id):
		recipe_id = DEFAULT_RECIPE_ID


func select_recipe(next_recipe_id: StringName) -> Dictionary:
	if not owned:
		return _failure(&"device_unowned")
	if cup_state != CUP_READY:
		return _failure(&"cup_in_progress")
	if not available_recipe_ids.has(next_recipe_id):
		return _failure(&"soy_flavor_locked", {"recipe_id": next_recipe_id})
	recipe_id = next_recipe_id
	return _success({"recipe_id": recipe_id})


func advance_time(_delta: float, _auto_cup_rack: bool = false) -> void:
	# Serving is player-driven; the station has no autonomous timer.
	pass


func take_empty_cup() -> Dictionary:
	if not owned:
		return _failure(&"device_unowned")
	if cup_state != CUP_READY:
		return _failure(&"cup_not_available")
	cup_state = CUP_HELD_EMPTY
	return _success({"cup_state": cup_state})


func return_empty_cup() -> Dictionary:
	if cup_state != CUP_HELD_EMPTY:
		return _failure(&"empty_cup_not_held")
	cup_state = CUP_READY
	return _success({"cup_state": cup_state})


func fill_held_cup(held_seconds: float) -> Dictionary:
	if not owned:
		return _failure(&"device_unowned")
	if cup_state != CUP_HELD_EMPTY:
		return _failure(&"empty_cup_required")
	var fill_ratio := clampf(maxf(held_seconds, 0.0) / FULL_CUP_SECONDS, 0.0, 1.0)
	if auto_fill_enabled:
		fill_ratio = 1.0
	var quality := minf(snappedf(fill_ratio * 100.0 + quality_bonus, 1.0), 100.0)
	cup = _product_payload(fill_ratio, quality)
	cup_state = CUP_FILLED
	return _success({"cup": cup.duplicate(true), "fill_ratio": fill_ratio, "is_full": fill_ratio >= 0.999})


func add_sugar() -> Dictionary:
	if cup_state != CUP_FILLED:
		return _failure(&"filled_cup_required")
	var sugar_servings := int(cup.get("sugar_servings", 0))
	if sugar_servings >= 2:
		return _failure(&"sugar_limit_reached")
	cup["sugar_servings"] = sugar_servings + 1
	return _success({"cup": cup.duplicate(true), "sugar_servings": sugar_servings + 1})


# Retired production-loop entry points are retained as explicit failures so
# legacy callers cannot silently recreate the bean/water workflow.
func add_ingredient(_stock_id: StringName) -> Dictionary:
	return _failure(&"soy_bean_loading_retired")


func load_recipe(_recipe_id: StringName, _quantity: int) -> Dictionary:
	return _failure(&"soy_batch_production_retired")


func clear_hopper() -> Dictionary:
	return _failure(&"soy_bean_loading_retired")


func start_water() -> Dictionary:
	return _failure(&"soy_water_timing_retired")


func stop_water() -> Dictionary:
	return _failure(&"soy_water_timing_retired")


func add_water() -> Dictionary:
	return _failure(&"soy_water_timing_retired")


func start() -> Dictionary:
	return _failure(&"soy_batch_production_retired")


func preview_collect(_quantity: int = 1) -> Dictionary:
	var preview := preview_cup()
	if not bool(preview.get("success", false)):
		return preview
	return _success(Dictionary(preview.get("product", {})))


func collect(_quantity: int = 1) -> Dictionary:
	var taken := take_filled_cup()
	if not bool(taken.get("success", false)):
		return taken
	return _success(Dictionary(taken.get("product", {})))


func collect_output(_slot_index: int) -> Dictionary:
	return _failure(&"soy_cup_rack_retired")


func discard() -> Dictionary:
	return discard_cup()


func discard_output(_slot_index: int) -> Dictionary:
	return _failure(&"soy_cup_rack_retired")


func preview_cup() -> Dictionary:
	if cup_state != CUP_FILLED or cup.is_empty():
		return _failure(&"filled_cup_required")
	return _success({"product": cup.duplicate(true)})


func take_filled_cup() -> Dictionary:
	var preview := preview_cup()
	if not bool(preview.get("success", false)):
		return preview
	var product := cup.duplicate(true)
	cup = {}
	cup_state = CUP_READY
	return _success({"product": product})


func discard_cup() -> Dictionary:
	if cup_state != CUP_FILLED:
		return _failure(&"filled_cup_required")
	var discarded := cup.duplicate(true)
	cup = {}
	cup_state = CUP_READY
	return _success({"product": discarded, "waste_reason": &"soy_cup_discarded"})


func snapshot() -> Dictionary:
	return {
		"device_id": DEVICE_ID,
		"owned": owned,
		"tier": tier,
		"state": cup_state,
		"recipe_id": recipe_id,
		"cup_state": cup_state,
		"cup": cup.duplicate(true),
		"full_cup_seconds": FULL_CUP_SECONDS,
		"soy_reservoir_capacity": int(CATALOG.device_tier(DEVICE_ID, tier).get("soy_reservoir_capacity", 1)),
		"available_recipe_ids": available_recipe_ids.duplicate(),
		"fill_guide_enabled": fill_guide_enabled,
		"auto_fill_enabled": auto_fill_enabled,
		"quality_bonus": quality_bonus,
		"output_rack": [],
	}


func load_snapshot(value: Dictionary) -> Dictionary:
	owned = false
	tier = 0
	recipe_id = DEFAULT_RECIPE_ID
	cup_state = CUP_READY
	cup = {}
	available_recipe_ids = [DEFAULT_RECIPE_ID]
	if value.is_empty() or not bool(value.get("owned", false)):
		return _success()
	var configured := configure_owned(int(value.get("tier", 0)))
	if not bool(configured.get("success", false)):
		return configured
	# Save data from the retired production loop deliberately starts clean.
	# Only snapshots created by this station can restore a player-held cup.
	var restored_state := StringName(value.get("cup_state", CUP_READY))
	var restored_cup := Dictionary(value.get("cup", {})).duplicate(true)
	var restored_recipes: Array[StringName] = []
	for raw_recipe_id in Array(value.get("available_recipe_ids", [])):
		var restored_recipe_id := StringName(raw_recipe_id)
		if SOY_RECIPE_IDS.has(restored_recipe_id):
			restored_recipes.append(restored_recipe_id)
	configure_available_recipes(restored_recipes)
	var restored_recipe_id := StringName(value.get("recipe_id", DEFAULT_RECIPE_ID))
	if available_recipe_ids.has(restored_recipe_id):
		recipe_id = restored_recipe_id
	if restored_state == CUP_FILLED and not restored_cup.is_empty():
		cup_state = CUP_FILLED
		cup = restored_cup
	elif restored_state == CUP_HELD_EMPTY:
		cup_state = CUP_HELD_EMPTY
	return _success()


func _product_payload(fill_ratio: float, quality: float) -> Dictionary:
	var recipe := CATALOG.recipe_definition(recipe_id)
	return {
		"recipe_id": recipe_id,
		"product_id": StringName(recipe.get("product_id", &"")),
		"area_id": AREA_ID,
		"quantity": 1,
		"quality": quality,
		"grade": _grade_for_quality(quality),
		"quality_multiplier": fill_ratio,
		"fill_ratio": fill_ratio,
		"sugar_servings": 0,
		"temperature_mode": &"room_temperature",
		"ingredient_ids": PackedStringArray(),
		"sauce_ids": PackedStringArray(),
	}


static func _grade_for_quality(value: float) -> StringName:
	if value >= 95.0:
		return &"A"
	if value >= 70.0:
		return &"B"
	if value >= 35.0:
		return &"C"
	return &"waste"


static func _success(extra: Dictionary = {}) -> Dictionary:
	var result := {"success": true, "reason": &""}
	result.merge(extra, true)
	return result


static func _failure(reason: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"success": false, "reason": reason}
	result.merge(extra, true)
	return result
