extends SceneTree

const SPECIAL_SETTLEMENT := preload("res://scripts/services/special_customer_settlement.gd")
const SPECIALS := preload("res://scripts/data/special_customer_catalog.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession autoload exists")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	var mixed := _open_order(session, [
		{"area_id": &"area.pancake", "product_id": &"product.pancake.custom", "quantity": 1, "base_price_coins": 12},
		{"area_id": &"area.youtiao", "product_id": &"product.youtiao.plain", "quantity": 1, "base_price_coins": 9},
		{"area_id": &"area.fresh_soy_milk", "product_id": &"product.fresh_soy_milk.yellow_bean", "quantity": 1, "base_price_coins": 9},
	])
	_attach(session, mixed, 0, {"product_instance_id": &"review.pancake.low", "product_id": &"product.pancake.custom", "area_id": &"area.pancake", "heat_matches_requested_preference": true, "ingredient_ids": [], "sauce_ids": [], "score": 59.0, "grade": &"C"})
	_attach(session, mixed, 1, {"product_instance_id": &"review.youtiao.good", "product_id": &"product.youtiao.plain", "area_id": &"area.youtiao", "temperature_mode": &"room_temperature", "ingredient_ids": [], "sauce_ids": [], "quality": 92.0, "grade": &"A"})
	_attach(session, mixed, 2, {"product_instance_id": &"review.soy.good", "product_id": &"product.fresh_soy_milk.yellow_bean", "area_id": &"area.fresh_soy_milk", "temperature_mode": &"room_temperature", "ingredient_ids": [], "sauce_ids": [], "sugar_servings": 0, "quality": 96.0, "grade": &"A", "fill_ratio": 0.96})
	var mixed_settlement := Dictionary(session.call("settle_f3_order", mixed))
	var mixed_reviews := Array(mixed_settlement.get("review_items", []))
	_check(mixed_reviews.size() == 3, "multi-item settlement creates one review record per delivered product")
	_check(int(mixed_settlement.get("qualified_item_count", 0)) == 2 and int(mixed_settlement.get("earned_coins", -1)) == 16, "qualified products contribute their floor-rounded score-proportional payments")
	_check(not bool(mixed_settlement.get("payment_pending", true)) or int(mixed_settlement.get("earned_coins", 0)) == 16, "a partial order creates its score-proportional pending payment")
	_check(int(mixed_settlement.get("consolation_coins", -1)) == 0, "a sub-60 product never creates the retired consolation coin")
	var mixed_payment := Dictionary(session.call("collect_tray_payment", mixed_settlement.get("settlement_id", &"")))
	var repeated_mixed_payment := Dictionary(session.call("collect_tray_payment", mixed_settlement.get("settlement_id", &"")))
	_check(int(mixed_payment.get("amount", 0)) == 16 and bool(repeated_mixed_payment.get("already_collected", false)), "score-proportional payment is collected exactly once")

	var soft_mismatch_order := _open_order(session, [{"area_id": &"area.pancake", "product_id": &"product.pancake.custom", "quantity": 1, "base_price_coins": 12, "heat_preference": &"golden", "ingredient_ids": [], "sauce_ids": []}])
	_attach(session, soft_mismatch_order, 0, {"product_instance_id": &"review.pancake.heat_soft", "product_id": &"product.pancake.custom", "area_id": &"area.pancake", "heat_matches_requested_preference": false, "ingredient_ids": [], "sauce_ids": [], "score": 72.0, "grade": &"B"})
	var soft_mismatch_settlement := Dictionary(session.call("settle_f3_order", soft_mismatch_order))
	var soft_mismatch_review := Dictionary(Array(soft_mismatch_settlement.get("review_items", []))[0])
	_check(
		is_equal_approx(float(soft_mismatch_review.get("score", 0.0)), 72.0)
		and bool(soft_mismatch_review.get("qualified", false))
		and int(soft_mismatch_review.get("payment_coins", -1)) == 8
		and int(soft_mismatch_settlement.get("earned_coins", -1)) == 8,
		"a 72-point heat mismatch receives floor(12 × 72%) = 8 coins"
	)
	var quantity_order := _open_order(session, [{"area_id": &"area.youtiao", "product_id": &"product.youtiao.plain", "quantity": 2, "base_price_coins": 9}])
	_attach(session, quantity_order, 0, {"product_instance_id": &"review.youtiao.first", "product_id": &"product.youtiao.plain", "area_id": &"area.youtiao", "temperature_mode": &"room_temperature", "ingredient_ids": [], "sauce_ids": [], "quality": 80.0, "grade": &"B"})
	_attach(session, quantity_order, 0, {"product_instance_id": &"review.youtiao.second", "product_id": &"product.youtiao.plain", "area_id": &"area.youtiao", "temperature_mode": &"room_temperature", "ingredient_ids": [], "sauce_ids": [], "quality": 40.0, "grade": &"C"})
	var quantity_settlement := Dictionary(session.call("settle_f3_order", quantity_order))
	_check(Array(quantity_settlement.get("review_items", [])).size() == 2 and int(quantity_settlement.get("earned_coins", -1)) == 7, "two units in one order item retain independent score-proportional payments")

	var wrong_order := _open_order(session, [{"area_id": &"area.youtiao", "product_id": &"product.youtiao.plain", "quantity": 1, "base_price_coins": 9}])
	_attach(session, wrong_order, 0, {"product_instance_id": &"review.youtiao.wrong", "product_id": &"product.fresh_soy_milk.yellow_bean", "area_id": &"area.fresh_soy_milk", "temperature_mode": &"room_temperature", "ingredient_ids": [], "sauce_ids": [], "quality": 100.0, "grade": &"A"})
	var wrong_settlement := Dictionary(session.call("settle_f3_order", wrong_order))
	_check(int(wrong_settlement.get("earned_coins", -1)) == 0 and not bool(wrong_settlement.get("payment_pending", true)), "a wrong product scores zero and receives no payment")
	_check(Array(wrong_settlement.get("review_items", [])).size() == 1 and not bool(Dictionary(Array(wrong_settlement.get("review_items", []))[0]).get("qualified", true)), "wrong-product review remains visible as an unqualified individual result")
	var special_partial := SPECIAL_SETTLEMENT.calculate({"special_customer_id": SPECIALS.GLUTTON, "perfect_quote_coins": 24}, false, PackedStringArray(["A", "C"]), 18, 3)
	var special_complete := SPECIAL_SETTLEMENT.calculate({"special_customer_id": SPECIALS.GLUTTON, "perfect_quote_coins": 24}, true, PackedStringArray(["A", "A"]), 18, 3)
	_check(int(special_partial.get("earned_coins", -1)) == 18 and int(special_partial.get("perfect_bonus_coins", -1)) == 0, "a partially qualified special order keeps only its individual-item payment")
	_check(int(special_complete.get("earned_coins", -1)) == 24 and int(special_complete.get("perfect_bonus_coins", -1)) == 6, "a fully qualified special order retains its existing perfect-order reward")
	_finish()


func _open_order(session: Node, items: Array) -> StringName:
	var opened := Dictionary(session.call("open_formal_order", items, {"base_coins": 999, "source": &"multi_item_review_payment_test"}))
	_check(bool(opened.get("success", false)), "test order opens")
	return StringName(Dictionary(opened.get("order", {})).get("order_id", &""))


func _attach(session: Node, order_id: StringName, item_index: int, product: Dictionary) -> void:
	_check(bool(Dictionary(session.call("attach_formal_order_product", order_id, item_index, product)).get("success", false)), "test product attaches to its intended order item")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("MULTI_ITEM_REVIEW_PAYMENT_SELF_CHECK PASS")
		quit()
		return
	printerr("MULTI_ITEM_REVIEW_PAYMENT_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
