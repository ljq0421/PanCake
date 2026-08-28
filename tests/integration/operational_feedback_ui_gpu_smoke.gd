extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")
const CAPTURES := [
	{"size": Vector2i(1920, 1080), "path": "res://tmp/validation/operational_feedback_ui_gpu_1920x1080.png"},
	{"size": Vector2i(1366, 768), "path": "res://tmp/validation/operational_feedback_ui_gpu_1366x768.png"},
	{"size": Vector2i(1280, 720), "path": "res://tmp/validation/operational_feedback_ui_gpu_1280x720.png"},
]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Operational feedback UI smoke must run without --headless")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	var session := root.get_node_or_null("GameSession")
	_check(session != null, "GameSession exists for the operational feedback preview")
	if session == null:
		_finish()
		return
	session.set("_active_save_path", "res://tmp/validation/operational_feedback_save.json")
	session.call("begin_new_game")
	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	for _frame in 8:
		await process_frame
	workstation.set_process(false)
	workstation.set("_restore_customer_layout_without_entrance", true)
	workstation.set("_customer_service_slot_signatures", {})
	workstation.call("_refresh_customer_service_slots", [_center_customer_order()])
	workstation.call("_show_formal_payment_coins", 28)
	workstation.call("_apply_attention_entries", [
		{"status_key": &"youtiao_overcooking", "severity": &"red", "seconds_to_irreversible_loss": 5.2},
		{"status_key": &"fresh_soy_milk_ready", "severity": &"yellow", "seconds_to_irreversible_loss": 12.1},
		{"status_key": &"tray_stale", "severity": &"yellow", "seconds_to_irreversible_loss": 19.8},
	])
	await process_frame

	var attention := workstation.get_node("FiveAreaInfrastructure/AttentionRail/Attention01") as Label
	var coins: Array[TextureRect] = []
	for coin_value in Array(workstation.get("_formal_payment_coin_sprites")):
		var coin := coin_value as TextureRect
		if is_instance_valid(coin):
			coins.append(coin)
	_check(workstation.get_node_or_null("FiveAreaInfrastructure/PendingPaymentButton") == null, "payment collection uses no separate CTA button")
	_check(attention.visible and attention.text.begins_with("紧急") and "另有1项" in attention.text, "attention chip prioritizes urgency and caps the inline summary")
	_check("煎饼暂存即将陈旧" in attention.tooltip_text, "attention tooltip preserves overflow details")
	_check(coins.size() == 4, "payment preview renders the expected denomination cluster")
	for capture_variant in CAPTURES:
		var capture: Dictionary = capture_variant
		await _capture(workstation, coins, Vector2i(capture["size"]), str(capture["path"]))
	workstation.queue_free()
	await process_frame
	_finish()


func _center_customer_order() -> Dictionary:
	return {
		"order_id": &"preview.operational.feedback",
		"service_slot": 2,
		"customer_id": &"customer_05",
		"patience_seconds": 90.0,
		"remaining_patience_seconds": 47.0,
		"perfect_quote_coins": 28,
		"items": [{
			"area_id": &"area.youtiao",
			"product_id": &"product.youtiao.plain",
			"quantity": 1,
			"temperature_mode": &"hot",
			"prepared_product_instance_ids": [],
		}],
	}


func _capture(workstation: Control, coins: Array[TextureRect], window_size: Vector2i, path: String) -> void:
	DisplayServer.window_set_size(window_size)
	for _frame in 8:
		await process_frame
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(window_size))
	var screen_transform: Transform2D = root.get_screen_transform()
	var attention := workstation.get_node("FiveAreaInfrastructure/AttentionRail/Attention01") as Label
	var attention_rect: Rect2 = screen_transform * attention.get_global_rect()
	_check(viewport_rect.encloses(attention_rect), "attention chip stays on-screen at %s" % window_size)
	for coin in coins:
		var coin_rect: Rect2 = screen_transform * coin.get_global_rect()
		_check(viewport_rect.encloses(coin_rect), "clickable payment coin stays on-screen at %s" % window_size)
		_check(coin.mouse_filter == Control.MOUSE_FILTER_STOP and coin.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "payment coin exposes a direct click target")
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var absolute_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	_check(image.save_png(absolute_path) == OK and image.get_size() == window_size, "captured operational feedback UI at %s" % window_size)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("OPERATIONAL_FEEDBACK_UI_GPU_SMOKE_PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
