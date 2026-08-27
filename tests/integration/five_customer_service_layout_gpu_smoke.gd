extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")
const CAPTURES := [
	{"size": Vector2i(1920, 1080), "path": "res://tmp/validation/five_customer_service_layout_gpu_1920x1080.png"},
	{"size": Vector2i(1366, 768), "path": "res://tmp/validation/five_customer_service_layout_gpu_1366x768.png"},
	{"size": Vector2i(1280, 720), "path": "res://tmp/validation/five_customer_service_layout_gpu_1280x720.png"},
]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Five-customer service layout smoke must run without --headless")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession exists for the five-customer layout")
	if session == null:
		_finish()
		return
	session.call("begin_new_game")
	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	for _frame in 3:
		await process_frame
	workstation.set_process(false)
	workstation.set("_restore_customer_layout_without_entrance", true)
	workstation.set("_customer_service_slot_signatures", {})
	workstation.call("_refresh_customer_service_slots", _preview_orders())
	await process_frame
	var card_rects: Array[Rect2] = []
	for slot_index in 5:
		var slot := workstation.get_node("SafeArea/ServiceCustomer%d" % (slot_index + 1)) as CustomerServiceSlot
		var order_panel := slot.get_node("OrderPanel") as Control
		_check(slot.visible and not slot.is_presentation_transitioning(), "service slot %d is visibly settled" % (slot_index + 1))
		_check(order_panel.size.x == 264.0 and order_panel.size.y <= 282.0, "service slot %d keeps the bounded variable-height card" % (slot_index + 1))
		card_rects.append(order_panel.get_global_rect())
	for left_index in 4:
		_check(not card_rects[left_index].intersects(card_rects[left_index + 1]), "adjacent order cards %d and %d do not overlap" % [left_index + 1, left_index + 2])
	for capture in CAPTURES:
		await _capture(workstation, Vector2i(capture["size"]), str(capture["path"]))
	workstation.queue_free()
	await process_frame
	_finish()


func _preview_orders() -> Array:
	var juice := {"area_id": &"area.packaged_drink", "product_id": &"product.packaged_drink.juice", "quantity": 1, "temperature_mode": &"room_temperature", "prepared_product_instance_ids": []}
	var youtiao := {"area_id": &"area.youtiao", "product_id": &"product.youtiao.plain", "quantity": 1, "temperature_mode": &"hot", "prepared_product_instance_ids": []}
	var soy := {"area_id": &"area.fresh_soy_milk", "product_id": &"product.fresh_soy_milk.yellow_bean", "quantity": 2, "temperature_mode": &"hot", "prepared_product_instance_ids": []}
	var pancake := {
		"area_id": &"area.pancake",
		"product_id": &"product.pancake.custom",
		"quantity": 1,
		"temperature_mode": &"hot",
		"ingredient_ids": [&"stock.pancake.egg", &"stock.pancake.baocui", &"stock.pancake.scallion"],
		"sauce_ids": [&"stock.pancake.sauce.sweet_flour"],
		"prepared_product_instance_ids": [],
	}
	var item_sets := [
		[juice.duplicate(true)],
		[youtiao.duplicate(true), soy.duplicate(true)],
		[juice.duplicate(true), youtiao.duplicate(true), soy.duplicate(true), pancake.duplicate(true)],
		[pancake.duplicate(true)],
		[soy.duplicate(true)],
	]
	var orders: Array = []
	for slot_index in 5:
		orders.append({
			"order_id": StringName("preview.five.%d" % slot_index),
			"service_slot": slot_index,
			"customer_id": StringName("customer_%02d" % (slot_index * 2 + 1)),
			"patience_seconds": 90.0,
			"remaining_patience_seconds": 90.0 - slot_index * 12.0,
			"perfect_quote_coins": 8 + slot_index * 3,
			"items": item_sets[slot_index],
		})
	return orders


func _capture(workstation: Control, window_size: Vector2i, path: String) -> void:
	DisplayServer.window_set_size(window_size)
	for _frame in 8:
		await process_frame
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(window_size))
	for slot_index in 5:
		var panel := workstation.get_node("SafeArea/ServiceCustomer%d/OrderPanel" % (slot_index + 1)) as Control
		var screen_rect := root.get_screen_transform() * panel.get_global_rect()
		_check(viewport_rect.encloses(screen_rect), "service slot %d card stays on-screen at %s" % [slot_index + 1, window_size])
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var absolute_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	_check(image.save_png(absolute_path) == OK and image.get_size() == window_size, "captured five-customer layout at %s" % window_size)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("FIVE_CUSTOMER_SERVICE_LAYOUT_GPU_SMOKE_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
