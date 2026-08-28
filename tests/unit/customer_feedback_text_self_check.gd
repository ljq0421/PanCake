extends SceneTree

const WORKSTATION := preload("res://scripts/gameplay/five_area_workstation.gd")

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
