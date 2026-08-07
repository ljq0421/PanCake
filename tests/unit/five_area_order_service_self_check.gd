extends SceneTree
const ORDERS = preload("res://scripts/services/five_area_order_service.gd")
var _failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var service: RefCounted = ORDERS.new()
	var template := {"id": &"order.pancake.classic", "heat_preference": &"golden", "ingredient_ids": [&"stock.pancake.egg"], "sauce_ids": [&"stock.pancake.sauce.sweet_flour"]}
	var opened: Dictionary = service.call("open_pancake_order", template)
	var order_id: StringName = Dictionary(opened.get("order", {})).get("order_id", &"")
	var product := {"product_instance_id": &"product.1", "product_id": &"product.pancake.custom", "heat_preference": &"golden", "ingredient_ids": [&"stock.pancake.egg"], "sauce_ids": [&"stock.pancake.sauce.sweet_flour"]}
	_check(bool(service.call("preview_attach_product", order_id, 0, product).get("will_match", false)), "formal order previews matching tray product")
	_check(bool(service.call("attach_product", order_id, 0, product).get("success", false)), "formal order reserves matched product")
	var settled: Dictionary = service.call("settle_order", order_id)
	var repeated_settlement: Dictionary = service.call("settle_order", order_id)
	_check(bool(settled.get("order_success", false)) and bool(repeated_settlement.get("success", false)) and bool(repeated_settlement.get("already_settled", false)), "formal order settles once and safely accepts a retry")
	var multi: Dictionary = service.call("open_order", [
		{"area_id": &"area.pancake", "product_id": &"product.pancake.custom", "quantity": 1, "ingredient_ids": [&"stock.pancake.egg"], "sauce_ids": [], "heat_preference": &"golden"},
		{"area_id": &"area.packaged_drink", "product_id": &"product.packaged_drink.milk", "quantity": 1},
	])
	var multi_id: StringName = Dictionary(multi.get("order", {})).get("order_id", &"")
	var pancake_product := {"product_instance_id": &"product.2", "product_id": &"product.pancake.custom", "heat_preference": &"golden", "ingredient_ids": [&"stock.pancake.egg"], "sauce_ids": []}
	var drink_product := {"product_instance_id": &"product.3", "product_id": &"product.packaged_drink.milk"}
	_check(bool(service.call("attach_product", multi_id, 0, pancake_product).get("success", false)) and bool(service.call("attach_product", multi_id, 1, drink_product).get("success", false)), "formal order routes products to distinct multi-item entries")
	var sauce_contract: RefCounted = ORDERS.new()
	var double_sauce: Dictionary = sauce_contract.call("open_pancake_order", {"id": &"order.pancake.double_sauce", "heat_preference": &"golden", "ingredient_ids": [&"stock.pancake.egg"], "sauce_ids": [&"stock.pancake.sauce.sweet_flour", &"stock.pancake.sauce.red_chili"]})
	_check(bool(double_sauce.get("success", false)), "formal pancake order accepts the confirmed two-sauce maximum")
	var over_sauce_contract: RefCounted = ORDERS.new()
	var over_sauced: Dictionary = over_sauce_contract.call("open_order", [{"area_id": &"area.pancake", "product_id": &"product.pancake.custom", "sauce_ids": [&"sauce.one", &"sauce.two", &"sauce.three"]}])
	_check(not bool(over_sauced.get("success", true)) and over_sauced.get("reason", &"") == &"too_many_sauce_requirements", "formal order rejects a third sauce requirement")
	var restored: RefCounted = ORDERS.new(service.call("snapshot"))
	_check(Dictionary(restored.call("active_order")).get("order_id", &"") == multi_id and bool(restored.call("settle_order", multi_id).get("order_success", false)), "active multi-item formal order survives snapshot restore")
	var wrong: RefCounted = ORDERS.new()
	var wrong_open: Dictionary = wrong.call("open_pancake_order", template)
	var wrong_id: StringName = Dictionary(wrong_open.get("order", {})).get("order_id", &"")
	var wrong_product := product.duplicate(true)
	wrong_product["ingredient_ids"] = []
	_check(bool(wrong.call("attach_product", wrong_id, 0, wrong_product).get("success", false)) and not bool(wrong.call("settle_order", wrong_id).get("order_success", true)), "wrong manually produced product settles as an order mismatch instead of blocking the day")
	_finish()
func _check(condition: bool, message: String) -> void:
	if condition: print("PASS: %s" % message)
	else: _failures.append(message)
func _finish() -> void:
	if _failures.is_empty(): print("FIVE_AREA_ORDER_SERVICE_SELF_CHECK_PASS"); quit(0); return
	printerr("FIVE_AREA_ORDER_SERVICE_SELF_CHECK_FAIL\n" + "\n".join(_failures)); quit(1)
