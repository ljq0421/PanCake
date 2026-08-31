extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")

const GARNISH_CASES := {
	&"stock.pancake.scallion": IngredientModel.SCALLION,
	&"stock.pancake.coriander": IngredientModel.CORIANDER,
}

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession is available")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	var progression: RefCounted = session.call("progression_service")
	progression.set("unlocked_area_ids", {&"area.pancake": true})
	progression.set("unlocked_recipe_ids", {&"recipe.pancake.base": true})
	progression.set("unlocked_product_ids", {&"product.pancake.custom": true})
	progression.set("unlocked_stock_ids", {
		&"stock.pancake.batter": true,
		&"stock.pancake.scallion": true,
		&"stock.pancake.coriander": true,
	})
	session.call("_sync_progression_to_save")
	var inventory := Dictionary(session.call("inventory_snapshot"))
	for stock_id in GARNISH_CASES:
		inventory[str(stock_id)] = 0
	session.call("save_inventory", inventory)

	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	for _frame in 4:
		await process_frame
	var station := workstation.multi_griddle_station as MultiGriddleStation
	var unit := station.units[0] as CompactGriddleUnit
	unit.reset_unit()
	unit.begin_order({})
	_check(bool(Dictionary(unit.use_press_spreader()).get("success", false)), "fixture creates a complete pancake skin")
	_check(bool(Dictionary(unit.advance_main()).get("success", false)), "fixture flips the pancake before garnish placement")

	for stock_id in GARNISH_CASES:
		var ingredient_type: StringName = GARNISH_CASES[stock_id]
		var before := int(Dictionary(session.call("inventory_snapshot")).get(str(stock_id), -1))
		var result := Dictionary(station.apply_one_click_ingredient(stock_id))
		var after := int(Dictionary(session.call("inventory_snapshot")).get(str(stock_id), -1))
		_check(bool(result.get("success", false)), "%s zero-stock unlimited click succeeds" % stock_id)
		_check(unit.ingredient_model.count_type(ingredient_type) == 1, "%s click records one pancake placement" % stock_id)
		_check(unit.applied_ingredient_ids.has(str(stock_id)), "%s click survives into the product ingredient snapshot" % stock_id)
		_check(before == 0 and after == 0, "%s remains unlimited and does not consume inventory" % stock_id)
		var matching_sprites := unit.ingredient_layer.get_children().filter(func(child):
			return child is Sprite2D and StringName(child.get_meta(&"ingredient_type", &"")) == ingredient_type
		)
		_check(matching_sprites.size() == 1, "%s creates one visible ingredient sprite" % stock_id)
		if matching_sprites.size() == 1:
			var sprite := matching_sprites[0] as Sprite2D
			_check(sprite.texture != null and sprite.modulate.a > 0.99 and sprite.scale.x > 0.0, "%s sprite uses an opaque, non-empty authored texture" % stock_id)

	workstation.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("UNLIMITED_PANCAKE_GARNISH_VISUAL_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("UNLIMITED_PANCAKE_GARNISH_VISUAL_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
