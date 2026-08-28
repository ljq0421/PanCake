extends SceneTree

const WORKSTATION := preload("res://scripts/gameplay/five_area_workstation.gd")
const GAME_SESSION_STORE := preload("res://scripts/services/game_session_store.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var summary := WORKSTATION._tray_result_summary({
		"order_success": false,
		"item_results": [{
			"product_id": &"product.pancake.custom",
			"product": {"product_id": &"product.youtiao.plain"},
			"mismatch_reasons": PackedStringArray(["product_id", "heat_preference", "ingredient_ids", "sauce_ids"]),
		}],
	})
	var feedback := str(summary.get("feedback", ""))
	var tags := PackedStringArray(summary.get("tags", PackedStringArray()))
	_check(
		feedback == "顾客指出：交付的油条与订单要求的煎饼不符"
		and tags.size() == 4,
		"customer feedback promotes the lowest-score problem while retaining every mistake as a result tag"
	)
	_check(not feedback.contains("product_id") and not feedback.contains("sauce_ids") and not " · ".join(tags).contains("_id"), "customer feedback and tags never expose internal identifiers")
	var heat_summary := WORKSTATION._tray_result_summary({
		"order_success": false,
		"item_results": [{
			"product_id": &"product.pancake.custom",
			"product": {"product_id": &"product.pancake.custom", "heat_feedback": "正面偏生、反面偏焦"},
			"mismatch_reasons": PackedStringArray(["heat_preference"]),
		}],
	})
	_check(
		str(heat_summary.get("feedback", "")) == "顾客指出：煎饼正面偏生、反面偏焦",
		"pancake heat mismatch identifies the undercooked and overcooked sides"
	)
	var quality_summary := WORKSTATION._tray_result_summary({
		"order_success": false,
		"item_results": [{
			"product_id": &"product.pancake.custom",
			"ingredient_ids": PackedStringArray(["stock.pancake.baocui"]),
			"product": {
				"product_id": &"product.pancake.custom",
				"heat_feedback": "正面偏焦",
				"dimension_scores": {"heat": 96.0, "ingredients": 79.0, "order": 100.0},
				"tags": PackedStringArray(["配料靠边易漏"]),
			},
			"mismatch_reasons": PackedStringArray(["heat_preference"]),
		}],
	})
	_check(
		str(quality_summary.get("feedback", "")) == "顾客指出：煎饼配料靠边易漏",
		"a sub-80 ingredient quality problem outranks a higher-scoring heat mismatch"
	)
	_check(
		is_zero_approx(float(Dictionary(quality_summary.get("dimensions", {})).get("order", 100.0))),
		"a delivery mismatch changes the displayed pancake compliance score to zero"
	)
	var detailed_feedback := GAME_SESSION_STORE._formal_review_feedback(
		&"product.pancake.custom",
		&"product.pancake.custom",
		{"heat_preference": &"golden", "ingredient_ids": PackedStringArray(["stock.pancake.egg"]), "sauce_ids": PackedStringArray(["stock.pancake.sauce.sweet_flour"])},
		{"heat_feedback": "正面偏生、反面偏焦", "ingredient_ids": PackedStringArray(["stock.pancake.baocui"]), "sauce_ids": PackedStringArray()},
		PackedStringArray(["heat_preference", "ingredient_ids", "sauce_ids"]),
		0.0,
	)
	_check(
		detailed_feedback == "煎饼不符合订单要求：火候订单要金黄，实际正面偏生、反面偏焦；配料订单要鸡蛋，实际薄脆；酱料订单要秘制酱料，实际不加",
		"formal review spells out each pancake requirement and the delivered result"
	)
	if _failures.is_empty():
		print("CUSTOMER_FEEDBACK_TEXT_SELF_CHECK PASS")
		quit()
	else:
		for failure in _failures:
			push_error("FAIL: %s" % failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
