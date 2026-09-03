extends SceneTree

const ORDERS := preload("res://scripts/services/five_area_order_service.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var service := ORDERS.new()
	var template := {"id": &"order.pancake.classic", "ingredient_ids": [&"stock.pancake.egg"], "sauce_ids": [&"stock.pancake.sauce.sweet_flour"]}
	var opened := Dictionary(service.open_pancake_order(template))
	var order := Dictionary(opened.get("order", {}))
	var order_id := StringName(order.get("order_id", &""))
	_check(bool(opened.get("success", false)) and Array(order.get("items", [])).size() == 1, "formal pancake order opens as one item")
	_check(StringName(order.get("customer_id", &"")) == &"customer_01" and StringName(order.get("special_customer_id", &"x")).is_empty(), "ordinary order uses the cartoon customer pool without special metadata")
	var product := {"product_instance_id": &"product.1", "product_id": &"product.pancake.custom", "heat_is_suitable": true, "ingredient_ids": [&"stock.pancake.egg"], "sauce_ids": [&"stock.pancake.sauce.sweet_flour"]}
	_check(bool(service.preview_attach_product(order_id, 0, product).get("will_match", false)), "matching product previews correctly")
	_check(bool(service.attach_product(order_id, 0, product).get("success", false)), "matching product attaches")
	var settled := Dictionary(service.settle_order(order_id))
	_check(bool(settled.get("order_success", false)), "single-item order settles")

	var multi := ORDERS.new()
	var rejected := Dictionary(multi.open_order([
		{"area_id": &"area.pancake", "product_id": &"product.pancake.custom"},
		{"area_id": &"area.packaged_drink", "product_id": &"product.packaged_drink.juice"},
	]))
	_check(not bool(rejected.get("success", true)), "combo orders are rejected by the service contract")

	var capacity := ORDERS.new()
	for index in range(4):
		var result := Dictionary(capacity.open_order([{"area_id": &"area.pancake", "product_id": &"product.pancake.custom"}], {"patience_seconds": 30.0 + index, "special_customer_id": &"student"}))
		_check(bool(result.get("success", false)), "customer %d occupies a valid service slot" % (index + 1))
	var fifth := Dictionary(capacity.open_order([{"area_id": &"area.pancake", "product_id": &"product.pancake.custom"}]))
	_check(not bool(fifth.get("success", true)) and StringName(fifth.get("reason", &"")) == &"queue_full", "a fifth simultaneous customer is rejected")
	var active := Array(capacity.active_orders())
	_check(active.size() == 4 and active.all(func(value: Variant) -> bool: return int(Dictionary(value).get("service_slot", -1)) in [0, 1, 2, 3]), "four active customers use only service slots zero through three")
	_check(active.all(func(value: Variant) -> bool: return StringName(Dictionary(value).get("special_customer_id", &"x")).is_empty()), "caller-provided special customer metadata is ignored")

	var rotation := PackedStringArray()
	for sequence in range(1, 14):
		rotation.append(str(ORDERS.customer_id_for_sequence(sequence)))
	_check(rotation == PackedStringArray(["customer_01", "customer_02", "customer_03", "customer_04", "customer_05", "customer_06", "customer_01", "customer_02", "customer_03", "customer_04", "customer_05", "customer_06", "customer_01"]), "customer identity rotates deterministically across six portraits")
	_check(ORDERS.legacy_customer_id_for_sequence(7) == &"customer_01", "legacy identities normalize into the same six-customer pool")

	var restored := ORDERS.new(capacity.snapshot())
	_check(restored.active_orders().size() == 4 and restored.waiting_orders().is_empty(), "four-customer state survives snapshot restore")
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("FIVE_AREA_ORDER_SERVICE_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("FIVE_AREA_ORDER_SERVICE_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
