extends SceneTree

const GENERATOR := preload("res://scripts/services/five_area_playable_order_generator.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var progression := _fully_playable_progression()
	var inventory := {}
	var first := Dictionary(GENERATOR.generate(progression, inventory, 24680, 7, 8, 0))
	var repeated := Dictionary(GENERATOR.generate(progression, inventory, 24680, 7, 8, 0))
	_check(first == repeated, "fixed seed and sequence generate an identical order")
	_check(bool(first.get("success", false)) and Array(first.get("items", [])).size() in [1, 2, 3], "three-area generator returns one to three products")
	var seen := {}
	var supported_only := true
	var combo_seen := false
	for sequence in range(1, 501):
		var generated := Dictionary(GENERATOR.generate(progression, inventory, 24680, sequence, 8, 0))
		var items := Array(generated.get("items", []))
		combo_seen = combo_seen or items.size() > 1
		for item_value in items:
			var area_id := StringName(Dictionary(item_value).get("area_id", &""))
			seen[area_id] = true
			supported_only = supported_only and area_id in GENERATOR.PLAYABLE_AREA_IDS
	_check(seen.has(&"area.pancake") and seen.has(&"area.youtiao") and seen.has(&"area.fresh_soy_milk"), "deterministic sampling reaches all three active areas")
	_check(not seen.has(&"area.packaged_drink") and not seen.has(&"area.steamer") and supported_only, "sampling never emits retired areas")
	_check(combo_seen, "full three-area shop can generate combo orders")
	_check_basic_soy_flavour_orders(inventory)
	_check_youtiao_quantities(inventory)
	_check_youtiao_stage_ratios(inventory)
	_check_three_area_ratios(inventory)
	var pancake_only := _fully_playable_progression()
	pancake_only["unlocked_area_ids"] = [&"area.pancake"]
	pancake_only["tutorial"]["completed_area_ids"] = [&"area.pancake"]
	for sequence in range(1, 30):
		var generated := Dictionary(GENERATOR.generate(pancake_only, inventory, 100, sequence, 2, 0))
		for item_value in Array(generated.get("items", [])):
			_check(StringName(Dictionary(item_value).get("area_id", &"")) == &"area.pancake", "starter shop generates pancake-only customers")
	var youtiao_tutorial := _fully_playable_progression()
	youtiao_tutorial["tutorial"] = {"completed_area_ids": [&"area.pancake"], "active_kind": &"area", "active_id": &"area.youtiao"}
	var youtiao_teaching := Dictionary(GENERATOR.generate(youtiao_tutorial, {}, 3, 1, 5, 0))
	_check(_single_area(youtiao_teaching) == &"area.youtiao" and int(Dictionary(Array(youtiao_teaching.get("items", []))[0]).get("quantity", 0)) == 1 and bool(Dictionary(youtiao_teaching.get("metadata", {})).get("tutorial_no_countdown", false)), "youtiao unlock creates one single-item unlimited teaching order even at zero stock")
	var soy_tutorial := _fully_playable_progression()
	soy_tutorial["tutorial"] = {"completed_area_ids": [&"area.pancake", &"area.youtiao"], "active_kind": &"area", "active_id": &"area.fresh_soy_milk"}
	var soy_teaching := Dictionary(GENERATOR.generate(soy_tutorial, {}, 3, 1, 8, 0))
	_check(_single_area(soy_teaching) == &"area.fresh_soy_milk" and bool(Dictionary(soy_teaching.get("metadata", {})).get("tutorial_no_countdown", false)), "soy unlock creates one unlimited teaching order even at zero stock")
	var wide_spreader_growth := _fully_playable_progression()
	wide_spreader_growth["owned_growth_ids"] = PackedStringArray(["growth.tool.pancake.wide_spreader"])
	wide_spreader_growth["tutorial"] = {"completed_area_ids": [&"area.pancake", &"area.youtiao", &"area.fresh_soy_milk"], "completed_device_ids": [], "queue_area_ids": [], "queue_device_ids": [], "active_kind": &"", "active_id": &""}
	var promoted_wide_spreader_order := Dictionary(GENERATOR.generate(wide_spreader_growth, inventory, 3, 1, 9, 0))
	_check(bool(promoted_wide_spreader_order.get("success", false)) and not bool(Dictionary(promoted_wide_spreader_order.get("metadata", {})).get("tutorial_no_countdown", false)), "wide spreader ownership produces only an ordinary timed content order, never a teaching order")
	var retired_tutorial := _fully_playable_progression()
	retired_tutorial["tutorial"] = {"completed_area_ids": [&"area.pancake", &"area.youtiao", &"area.fresh_soy_milk"], "active_kind": &"area", "active_id": &"area.steamer"}
	var fallback := Dictionary(GENERATOR.generate(retired_tutorial, {}, 9, 2, 9, 0))
	_check(bool(fallback.get("success", false)) and _all_supported(fallback), "retired tutorial state cannot revive a retired product")
	_finish()


func _check_youtiao_stage_ratios(inventory: Dictionary) -> void:
	var progression := _fully_playable_progression()
	progression["unlocked_area_ids"] = [&"area.pancake", &"area.youtiao"]
	progression["tutorial"]["completed_area_ids"] = [&"area.pancake", &"area.youtiao"]
	var sample_count := 4000
	var pancake_main := 0
	var pancake_with_youtiao := 0
	var youtiao_single := 0
	for sequence in range(1, sample_count + 1):
		var areas := _candidate_areas(Dictionary(GENERATOR.generate(progression, inventory, 89123, sequence, 8, 0)))
		if areas.has(&"area.pancake"):
			pancake_main += 1
			pancake_with_youtiao += int(areas.has(&"area.youtiao"))
		elif areas == [&"area.youtiao"]:
			youtiao_single += 1
	_check(absf(float(pancake_main) / sample_count - 0.75) <= 0.03, "youtiao stage keeps 75% pancake-main orders")
	_check(absf(float(youtiao_single) / sample_count - 0.25) <= 0.03, "youtiao stage keeps 25% youtiao single orders")
	_check(absf(float(pancake_with_youtiao) / maxf(float(pancake_main), 1.0) - 0.30) <= 0.04, "30% of pancake-main orders add youtiao")


func _check_youtiao_quantities(inventory: Dictionary) -> void:
	var progression := _fully_playable_progression()
	progression["unlocked_area_ids"] = [&"area.youtiao"]
	var tutorial := Dictionary(progression.get("tutorial", {})).duplicate(true)
	tutorial["completed_area_ids"] = [&"area.youtiao"]
	progression["tutorial"] = tutorial
	var counts := {1: 0, 2: 0, 3: 0}
	var sample_count := 5000
	for sequence in range(1, sample_count + 1):
		var generated := Dictionary(GENERATOR.generate(progression, inventory, 41773, sequence, 8, 0))
		var item := Dictionary(Array(generated.get("items", []))[0])
		var quantity := int(item.get("quantity", 0))
		counts[quantity] = int(counts.get(quantity, 0)) + 1
		_check(StringName(item.get("product_id", &"")) == &"product.youtiao.plain" and quantity in [1, 2, 3], "ordinary fryer orders contain only one to three oil strips")
	_check(absf(float(counts[1]) / sample_count - 0.50) <= 0.03, "one-strip orders use the authored 50% weight")
	_check(absf(float(counts[2]) / sample_count - 0.35) <= 0.03, "two-strip orders use the authored 35% weight")
	_check(absf(float(counts[3]) / sample_count - 0.15) <= 0.03, "three-strip orders use the authored 15% weight")


func _check_three_area_ratios(inventory: Dictionary) -> void:
	var progression := _fully_playable_progression()
	var sample_count := 5000
	var pancake_main := 0
	var youtiao_single := 0
	var soy_single := 0
	var pancake_plain := 0
	var pancake_one_side := 0
	var pancake_two_sides := 0
	for sequence in range(1, sample_count + 1):
		var areas := _candidate_areas(Dictionary(GENERATOR.generate(progression, inventory, 73199, sequence, 12, 0)))
		if areas.has(&"area.pancake"):
			pancake_main += 1
			match areas.size():
				1: pancake_plain += 1
				2: pancake_one_side += 1
				3: pancake_two_sides += 1
		elif areas == [&"area.youtiao"]:
			youtiao_single += 1
		elif areas == [&"area.fresh_soy_milk"]:
			soy_single += 1
	_check(absf(float(pancake_main) / sample_count - 0.70) <= 0.03, "full shop keeps 70% pancake-main orders")
	_check(absf(float(youtiao_single) / sample_count - 0.15) <= 0.03, "full shop keeps 15% youtiao single orders")
	_check(absf(float(soy_single) / sample_count - 0.15) <= 0.03, "full shop keeps 15% soy single orders")
	_check(absf(float(pancake_plain) / maxf(float(pancake_main), 1.0) - 0.55) <= 0.04, "pancake-main mix keeps 55% plain")
	_check(absf(float(pancake_one_side) / maxf(float(pancake_main), 1.0) - 0.35) <= 0.04, "pancake-main mix keeps 35% one-side combos")
	_check(absf(float(pancake_two_sides) / maxf(float(pancake_main), 1.0) - 0.10) <= 0.03, "pancake-main mix keeps 10% two-side combos")


func _check_basic_soy_flavour_orders(inventory: Dictionary) -> void:
	var progression := _fully_playable_progression()
	progression["unlocked_recipe_ids"] = [&"recipe.pancake.base", &"recipe.youtiao.plain", &"recipe.fresh_soy_milk.yellow_bean"]
	progression["unlocked_product_ids"] = [&"product.pancake.custom", &"product.youtiao.plain", &"product.fresh_soy_milk.yellow_bean"]
	var soy_orders := 0
	for sequence in range(1, 200):
		var candidate := Dictionary(GENERATOR.generate(progression, inventory, 24680, sequence, 8, 0))
		for item_value in Array(candidate.get("items", [])):
			var item := Dictionary(item_value)
			if StringName(item.get("area_id", &"")) == &"area.fresh_soy_milk":
				soy_orders += 1
				_check(StringName(item.get("product_id", &"")) == &"product.fresh_soy_milk.yellow_bean", "basic soy machine never generates locked flavour requirements")
	_check(soy_orders > 0, "basic soy order sampling includes yellow-soy requests")


func _fully_playable_progression() -> Dictionary:
	return {
		"unlocked_area_ids": [&"area.pancake", &"area.youtiao", &"area.fresh_soy_milk"],
		"device_tiers": {&"device.pancake_griddle": 2, &"device.youtiao_fryer": 2, &"device.fresh_soy_milk_machine": 2},
		"unlocked_recipe_ids": [&"recipe.pancake.base", &"recipe.youtiao.plain", &"recipe.fresh_soy_milk.yellow_bean", &"recipe.fresh_soy_milk.black_bean", &"recipe.fresh_soy_milk.red_bean", &"recipe.fresh_soy_milk.multigrain"],
		"unlocked_product_ids": [&"product.pancake.custom", &"product.youtiao.plain", &"product.fresh_soy_milk.yellow_bean", &"product.fresh_soy_milk.black_bean", &"product.fresh_soy_milk.red_bean", &"product.fresh_soy_milk.multigrain"],
		"unlocked_stock_ids": [&"stock.pancake.batter", &"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.scallion", &"stock.pancake.sauce.sweet_flour", &"stock.youtiao.plain_dough", &"stock.fresh_soy_milk.yellow_bean", &"stock.fresh_soy_milk.black_bean", &"stock.fresh_soy_milk.red_bean"],
		"tutorial": {"completed_area_ids": [&"area.pancake", &"area.youtiao", &"area.fresh_soy_milk"], "active_kind": &"", "active_id": &""},
	}


func _single_area(candidate: Dictionary) -> StringName:
	var items := Array(candidate.get("items", []))
	return StringName(Dictionary(items[0]).get("area_id", &"")) if items.size() == 1 else &""


func _all_supported(candidate: Dictionary) -> bool:
	for item_value in Array(candidate.get("items", [])):
		if StringName(Dictionary(item_value).get("area_id", &"")) not in GENERATOR.PLAYABLE_AREA_IDS:
			return false
	return true


func _candidate_areas(candidate: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	for item_value in Array(candidate.get("items", [])):
		result.append(StringName(Dictionary(item_value).get("area_id", &"")))
	return result


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("THREE_AREA_PLAYABLE_ORDER_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("THREE_AREA_PLAYABLE_ORDER_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
