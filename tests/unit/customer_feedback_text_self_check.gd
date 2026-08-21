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
		feedback == "顾客指出：交付的油条与订单要求的煎饼不符、煎饼火候不符合订单要求、煎饼配料与订单要求不符、煎饼酱料与订单要求不符",
		"customer feedback explains the delivered-product mistakes in Chinese"
	)
	_check(not feedback.contains("product_id") and not feedback.contains("sauce_ids") and not " · ".join(tags).contains("_id"), "customer feedback and tags never expose internal identifiers")
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
