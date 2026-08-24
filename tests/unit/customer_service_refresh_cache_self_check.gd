extends SceneTree

const WORKSTATION_SCRIPT := preload("res://scripts/gameplay/workstation.gd")
const CUSTOMER_SLOT_SCENE := preload("res://scenes/gameplay/customer_service_slot.tscn")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var base_order := {
		"order_id": &"order.cache.01",
		"customer_id": &"customer_01",
		"patience_seconds": 60.0,
		"remaining_patience_seconds": 59.0,
		"items": [{
			"product_id": &"product.youtiao.plain",
			"quantity": 1,
			"prepared_product_instance_ids": PackedStringArray(),
		}],
	}
	var later_order := base_order.duplicate(true)
	later_order["remaining_patience_seconds"] = 21.0
	var base_signature := WORKSTATION_SCRIPT._customer_service_slot_signature(base_order, &"neutral")
	var later_signature := WORKSTATION_SCRIPT._customer_service_slot_signature(later_order, &"neutral")
	_check(base_signature == later_signature, "patience-only changes reuse the existing customer-card layout")
	var delivered_order := later_order.duplicate(true)
	Dictionary(Array(delivered_order["items"])[0])["prepared_product_instance_ids"] = PackedStringArray(["product.instance.01"])
	_check(
		base_signature != WORKSTATION_SCRIPT._customer_service_slot_signature(delivered_order, &"neutral"),
		"delivery changes invalidate the cached customer-card content",
	)
	_check(
		base_signature != WORKSTATION_SCRIPT._customer_service_slot_signature(later_order, &"impatient"),
		"reaction threshold changes invalidate the cached portrait",
	)

	var slot := CUSTOMER_SLOT_SCENE.instantiate() as CustomerServiceSlot
	root.add_child(slot)
	await process_frame
	slot.bind_order(base_order, null, [null], [[]], 3)
	var item_position := slot.item_buttons[0].position
	var item_size := slot.item_buttons[0].size
	slot.update_patience(later_order)
	_check(
		slot.item_buttons[0].position == item_position and slot.item_buttons[0].size == item_size,
		"patience updates do not relayout the draggable delivery target",
	)
	_check(slot.patience_label.text == "耐心 21 秒", "the lightweight path still refreshes visible patience")
	slot.queue_free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CUSTOMER_SERVICE_REFRESH_CACHE_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("CUSTOMER_SERVICE_REFRESH_CACHE_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
