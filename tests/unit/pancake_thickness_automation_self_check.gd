extends SceneTree

const PANCAKE_MODEL_SCRIPT := preload("res://scripts/simulation/pancake_model.gd")
const INGREDIENT_MODEL_SCRIPT := preload("res://scripts/gameplay/ingredient_model.gd")
const PANCAKE_FOLD_MODEL_SCRIPT := preload("res://scripts/gameplay/pancake_fold_model.gd")
const PANCAKE_SCORER_SCRIPT := preload("res://scripts/gameplay/pancake_scorer.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var model: PancakeModel = PANCAKE_MODEL_SCRIPT.new(32)
	model.add_batter(Vector2(15.5, 15.5), 4.0, 10.0)
	for index in model.cell_count:
		if model.coverage[index] > 0.0:
			model.thickness[index] = 0.08 if index % 2 == 0 else 1.20
	var ingredients: IngredientModel = INGREDIENT_MODEL_SCRIPT.new()
	var fold_model: PancakeFoldModel = PANCAKE_FOLD_MODEL_SCRIPT.new(model, ingredients)
	var order := {"ingredients": [], "sauces": []}
	var manual_result: Dictionary = PANCAKE_SCORER_SCRIPT.evaluate_order(model, ingredients, fold_model, order, 10.0, 1.0)
	var automated_result: Dictionary = PANCAKE_SCORER_SCRIPT.evaluate_order(model, ingredients, fold_model, order, 10.0, 1.0, false, false, true)
	_check(float(Dictionary(manual_result.get("dimensions", {})).get("thickness", 100.0)) < 100.0, "ordinary uneven batter retains thickness deductions")
	_check(is_equal_approx(float(Dictionary(automated_result.get("dimensions", {})).get("thickness", 0.0)), 100.0), "measured ladle plus press gives a 100 thickness score")
	var stored_result: Dictionary = PANCAKE_SCORER_SCRIPT.evaluate_stored_product({"serving_score_basis": automated_result.get("serving_score_basis", {})}, order, 10.0, 1.0)
	_check(is_equal_approx(float(Dictionary(stored_result.get("dimensions", {})).get("thickness", 0.0)), 100.0), "stored automated pancake retains its 100 thickness score")
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PANCAKE_THICKNESS_AUTOMATION_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("PANCAKE_THICKNESS_AUTOMATION_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
