extends SceneTree

const PANCAKE_PRODUCTION := preload("res://scripts/services/five_area_pancake_production_service.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var model := _uniform_pancake(64)
	var ingredients := IngredientModel.new()
	var youtiao_result := ingredients.place(IngredientModel.YOUTIAO, Vector2(32.0, 32.0), 0.0, model)
	var placement := Dictionary(youtiao_result.get("placement", {}))
	_check(
		bool(youtiao_result.get("success", false))
		and is_equal_approx(float(placement.get("structural_load", 0.0)), 0.55)
		and is_equal_approx(float(placement.get("wetness", 0.0)), 0.02),
		"plain youtiao enters the pancake model with the authored structure and moisture load"
	)
	ingredients.place(IngredientModel.EGG, Vector2(29.0, 31.0), 0.0, model)
	ingredients.place(IngredientModel.SCALLION, Vector2(35.0, 33.0), 0.0, model)
	var fold := PancakeFoldModel.new(model, ingredients)
	var order := {
		"ingredients": [&"egg", &"youtiao", &"scallion"],
		"sauces": [],
		"heat_preference": &"golden",
		"time_limit": 72.0,
	}
	var scored := PancakeScorer.evaluate_order(model, ingredients, fold, order, 20.0, 1.0)
	_check(
		Array(scored.get("missing_ingredients", [])).is_empty()
		and Array(scored.get("unexpected_ingredients", [])).is_empty()
		and Array(scored.get("applied_ingredient_ids", [])).has(IngredientModel.YOUTIAO),
		"plain youtiao participates in formal ingredient matching"
	)
	var service: RefCounted = PANCAKE_PRODUCTION.new(null)
	var score_payload := scored.duplicate(true)
	score_payload["fried_grade"] = &"S"
	score_payload["fried_quality_score"] = 999.0
	var product := Dictionary(service.call("create_product_snapshot", score_payload, {"id": &"order.pancake.youtiao_scallion"}))
	_check(
		Array(product.get("ingredient_ids", [])).has("stock.pancake.youtiao")
		and Array(product.get("cost_stock_ids", [])).has("stock.pancake.youtiao")
		and int(product.get("material_cost", 0)) >= 2,
		"processed youtiao is retained in the pancake ingredient and material-cost contract"
	)
	_check(
		not product.has("fried_grade") and not product.has("fried_quality_score"),
		"fryer grade is not copied into pancake quality for a second bonus or penalty"
	)
	var layer := IngredientLayer.new()
	layer.size = Vector2(640.0, 400.0)
	root.add_child(layer)
	layer.set_model(ingredients)
	await process_frame
	var youtiao_sprite: Sprite2D = null
	for child in layer.get_children():
		var sprite := child as Sprite2D
		if sprite != null and StringName(sprite.get_meta(&"ingredient_type", &"")) == IngredientModel.YOUTIAO:
			youtiao_sprite = sprite
			break
	var youtiao_image := Image.load_from_file(ProjectSettings.globalize_path("res://resources/art/products/youtiao/plain_youtiao_v1_five_area_v3.png"))
	var baocui_image := Image.load_from_file(ProjectSettings.globalize_path("res://resources/art/ingredients/baocui/baocui_broken_v1.png"))
	var youtiao_visible_width := float(youtiao_image.get_used_rect().size.x) * youtiao_sprite.scale.x if youtiao_sprite != null else 0.0
	var baocui_visible_width := float(baocui_image.get_used_rect().size.x) * 0.16
	_check(
		youtiao_sprite != null
		and youtiao_sprite.texture != null
		and youtiao_sprite.scale.is_equal_approx(Vector2(0.78, 0.78))
		and baocui_visible_width > 0.0
		and absf(youtiao_visible_width / baocui_visible_width - 1.0) <= 0.10,
		"pancake rendering enlarges plain youtiao to within ten percent of baocui's visible width"
	)
	layer.queue_free()
	_finish()


func _uniform_pancake(size: int) -> PancakeModel:
	var model := PancakeModel.new(size)
	for y in size:
		for x in size:
			if not model.is_inside_pan(Vector2(x, y), 0.84):
				continue
			var index := y * size + x
			model.coverage[index] = 1.0
			model.thickness[index] = 0.42
			model.wetness[index] = 0.25
			model.doneness[index] = 0.64
			model.back_doneness[index] = 0.64
	return model


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("YOUTIAO_PANCAKE_ADD_ON_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("YOUTIAO_PANCAKE_ADD_ON_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
