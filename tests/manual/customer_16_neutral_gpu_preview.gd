extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const OUTPUT_PATH := "res://tmp/validation/customer_16_neutral_v2_chinese_gpu_clear_1920x1080.png"
const EXPECTED_REGION := Rect2(508, 18, 520, 1006)

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_failures.append("Customer neutral preview must run without --headless")
		_finish()
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	print("DISPLAY_SERVER=%s" % DisplayServer.get_name())
	print("RENDERING_METHOD=%s" % RenderingServer.get_current_rendering_method())
	print("VIDEO_ADAPTER=%s" % RenderingServer.get_video_adapter_name())
	var session := root.get_node_or_null("GameSession")
	if session == null:
		_failures.append("GameSession is missing")
		_finish()
		return
	session.call("begin_new_game")
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	for _frame in 12:
		await process_frame
	var workstation := game.get_node_or_null("Workstation")
	if workstation == null:
		_failures.append("Workstation is missing")
		_finish()
		return
	workstation.set_process(false)
	workstation._formal_order_id = &""
	workstation.customer_queue.call("restore_active_customer", {}, &"customer_16")
	var portrait := workstation.get_node_or_null("SafeArea/CustomerPortrait") as TextureRect
	if portrait == null:
		_failures.append("CustomerPortrait is missing")
		_finish()
		return
	workstation.call("_set_customer_portrait_state", &"neutral")
	var order_card := workstation.get_node_or_null("SafeArea/OrderCard") as CanvasItem
	if order_card != null:
		order_card.visible = false
	var tutorial_overlay := workstation.get_node_or_null("SafeArea/TutorialGuideOverlay") as CanvasItem
	if tutorial_overlay != null:
		tutorial_overlay.visible = false
	# The formal three-customer cards intentionally cover the legacy portrait area.
	# Hide them only in this art-review capture so the selected runtime Atlas can
	# be inspected at its actual workstation scale without modifying gameplay.
	for service_slot_name in [&"ServiceCustomer1", &"ServiceCustomer2", &"ServiceCustomer3"]:
		var service_slot := workstation.get_node_or_null("SafeArea/%s" % service_slot_name) as CanvasItem
		if service_slot != null:
			service_slot.visible = false
	portrait.visible = true
	portrait.modulate = Color.WHITE
	for _frame in 3:
		await process_frame
	print("CUSTOMER_16_PREVIEW_PORTRAIT visible=%s position=%s texture=%s" % [portrait.visible, portrait.global_position, portrait.texture.resource_path if portrait.texture != null else "<null>"])
	_check(portrait.texture != null and portrait.texture.resource_path.ends_with("customer_16_neutral_cropped.tres"), "customer_16 neutral portrait loads in the real workstation")
	if portrait.texture != null:
		var atlas := portrait.texture.get("atlas") as Texture2D
		_check(atlas != null and atlas.resource_path.ends_with("customer_16_neutral_v2_keyclean.png"), "AtlasTexture resolves the selected customer_16 neutral PNG")
		_check(portrait.texture.get("region") == EXPECTED_REGION, "customer_16 crop contains full hair, hands, and below-waist anchor")
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var image := root.get_texture().get_image()
	_check(image.save_png(path) == OK and image.get_size() == Vector2i(1920, 1080), "captured a real 1920x1080 GPU workstation frame")
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CUSTOMER_16_NEUTRAL_GPU_PREVIEW_PASS")
		quit(0)
		return
	printerr("CUSTOMER_16_NEUTRAL_GPU_PREVIEW_FAIL\n" + "\n".join(_failures))
	quit(1)
