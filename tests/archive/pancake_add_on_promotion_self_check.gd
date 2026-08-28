extends SceneTree

const PLAYABLE_ORDER_GENERATOR := preload("res://scripts/services/five_area_playable_order_generator.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession autoload is available")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	var save_data: Dictionary = Dictionary(session.get("_save_data"))
	save_data["pending_order_promotions"] = [
		{"kind": &"pancake_stock", "target_id": &"stock.pancake.baocui", "source_growth_id": &"growth.add_on.pancake.baocui", "remaining_orders": 3},
		{"kind": &"pancake_stock", "target_id": &"stock.pancake.coriander", "source_growth_id": &"growth.add_on.pancake.coriander", "remaining_orders": 3},
	]
	session.set("_save_data", save_data)
	var legacy_promotion := Dictionary(session.call("_active_order_promotion_context"))
	_check(
		StringName(legacy_promotion.get("target_id", &"")) == &"stock.pancake.coriander",
		"existing FIFO promotion saves prioritize their newest topping after loading",
	)
	save_data["pending_order_promotions"] = []
	session.set("_save_data", save_data)
	session.call("_enqueue_growth_order_promotions", [
		&"growth.add_on.pancake.sweet_flour",
		&"growth.add_on.pancake.baocui",
		&"growth.add_on.pancake.scallion",
		&"growth.add_on.pancake.coriander",
	])
	var promotion := Dictionary(session.call("_active_order_promotion_context"))
	_check(
		StringName(promotion.get("kind", &"")) == &"pancake_stock"
			and StringName(promotion.get("target_id", &"")) == &"stock.pancake.coriander",
		"the latest unlocked pancake add-on is the first promoted order",
	)
	var progression: RefCounted = session.call("progression_service")
	progression.call("complete_tutorial", &"area", &"area.pancake")
	progression.set("unlocked_stock_ids", _owned_pancake_stock_set())
	var ensured := Dictionary(session.call("ensure_active_playable_order"))
	var queue := Array(ensured.get("queue", []))
	_check(bool(ensured.get("success", false)) and queue.size() == 6, "the live customer queue is filled after add-on activation")
	for order_variant in queue.slice(0, 3):
		var live_items := Array(Dictionary(order_variant).get("items", []))
		var live_item := Dictionary(live_items[0]) if not live_items.is_empty() else {}
		_check(
			Array(live_item.get("ingredient_ids", [])).has(&"stock.pancake.coriander"),
			"the next live customer order contains the newest unlocked topping",
		)
	var generated := PLAYABLE_ORDER_GENERATOR.generate_queue_candidates(
		_fully_unlocked_pancake_progression(),
		{},
		24680,
		1,
		3,
		8,
		8,
		promotion,
	)
	var candidates: Array = Array(generated.get("candidates", []))
	_check(bool(generated.get("success", false)) and candidates.size() == 3, "three topping-promotion candidates are generated")
	for candidate_variant in candidates:
		var items := Array(Dictionary(candidate_variant).get("items", []))
		var item := Dictionary(items[0]) if not items.is_empty() else {}
		var ingredient_ids := Array(item.get("ingredient_ids", []))
		_check(
			ingredient_ids.has(&"stock.pancake.coriander") and ingredient_ids.has(&"stock.pancake.baocui"),
			"the promoted pancake explicitly requests the newly unlocked coriander and crisp",
		)
	session.call("reset_incompatible_development_save")
	_finish()


func _fully_unlocked_pancake_progression() -> Dictionary:
	return {
		"unlocked_area_ids": [&"area.pancake"],
		"unlocked_recipe_ids": [&"recipe.pancake.base"],
		"unlocked_product_ids": [&"product.pancake.custom"],
		"unlocked_stock_ids": _owned_pancake_stock_set().keys(),
		"tutorial": {"completed_area_ids": [&"area.pancake"], "active_kind": &"", "active_id": &""},
	}


func _owned_pancake_stock_set() -> Dictionary:
	return {
		&"stock.pancake.batter": true,
		&"stock.pancake.egg": true,
		&"stock.pancake.sauce.sweet_flour": true,
		&"stock.pancake.baocui": true,
		&"stock.pancake.scallion": true,
		&"stock.pancake.coriander": true,
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PANCAKE_ADD_ON_PROMOTION_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("PANCAKE_ADD_ON_PROMOTION_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
