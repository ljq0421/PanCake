extends SceneTree

const GENERATOR := preload("res://scripts/services/five_area_playable_order_generator.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var progression := _fully_unlocked_progression()
	var first := Dictionary(GENERATOR.generate(progression, {}, 24680, 7, 8, 0))
	var repeated := Dictionary(GENERATOR.generate(progression, {}, 24680, 7, 8, 0))
	_check(first == repeated, "fixed seed and sequence remain deterministic")
	var seen := {}
	for sequence in range(1, 801):
		var generated := Dictionary(GENERATOR.generate(progression, {}, 24680, sequence, 8, 0, {
			"special_state": {"generated_today": 0, "last_generated_sequence": -100},
		}))
		var items := Array(generated.get("items", []))
		_check(bool(generated.get("success", false)) and items.size() == 1, "every ordinary order contains exactly one item")
		if items.size() != 1:
			continue
		var item := Dictionary(items[0])
		var area_id := StringName(item.get("area_id", &""))
		seen[area_id] = true
		_check(area_id in GENERATOR.PLAYABLE_AREA_IDS, "orders use only supported areas")
		_check(int(item.get("quantity", 1)) == 1, "all v1 products request one serving")
		if area_id == &"area.pancake":
			var stocks := Array(item.get("ingredient_ids", [])) + Array(item.get("sauce_ids", []))
			_check(not stocks.has(&"stock.pancake.coriander") and not stocks.has("stock.pancake.coriander"), "pancake orders never request coriander")
		if area_id == &"area.fresh_soy_milk":
			_check(StringName(item.get("product_id", &"")) == &"product.fresh_soy_milk.yellow_bean" and int(item.get("sugar_servings", 0)) == 0, "soy orders are plain yellow soy without sugar")
		_check(StringName(Dictionary(generated.get("metadata", {})).get("special_customer_id", &"")).is_empty(), "special orders are disabled")
	_check(seen.has(&"area.pancake") and seen.has(&"area.youtiao") and seen.has(&"area.fresh_soy_milk") and seen.has(&"area.packaged_drink"), "sampling reaches all four unlocked single products")

	var pancake_only := _fully_unlocked_progression()
	pancake_only["unlocked_area_ids"] = [&"area.pancake"]
	pancake_only["tutorial"] = {"completed_area_ids": [&"area.pancake"], "active_kind": &"", "active_id": &""}
	for sequence in range(1, 40):
		var generated := Dictionary(GENERATOR.generate(pancake_only, {}, 100, sequence, 1, 0))
		var items := Array(generated.get("items", []))
		_check(items.size() == 1 and StringName(Dictionary(items[0]).get("area_id", &"")) == &"area.pancake", "day-one shop generates pancake-only orders")
	_finish()


func _fully_unlocked_progression() -> Dictionary:
	return {
		"unlocked_area_ids": [&"area.pancake", &"area.youtiao", &"area.fresh_soy_milk", &"area.packaged_drink"],
		"device_tiers": {&"device.pancake_griddle": 0, &"device.youtiao_fryer": 0, &"device.fresh_soy_milk_machine": 0, &"device.packaged_drink_rack": 0},
		"unlocked_recipe_ids": [&"recipe.pancake.base", &"recipe.youtiao.plain", &"recipe.fresh_soy_milk.yellow_bean", &"recipe.packaged_drink.juice"],
		"unlocked_product_ids": [&"product.pancake.custom", &"product.youtiao.plain", &"product.fresh_soy_milk.yellow_bean", &"product.packaged_drink.juice"],
		"unlocked_stock_ids": [&"stock.pancake.batter", &"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.scallion", &"stock.pancake.ham_sausage", &"stock.pancake.meat_floss", &"stock.pancake.sauce.sweet_flour", &"stock.youtiao.plain_dough", &"stock.packaged_drink.juice"],
		"tutorial": {"completed_area_ids": [&"area.pancake", &"area.youtiao", &"area.fresh_soy_milk", &"area.packaged_drink"], "active_kind": &"", "active_id": &""},
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("THREE_AREA_PLAYABLE_ORDER_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("THREE_AREA_PLAYABLE_ORDER_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
