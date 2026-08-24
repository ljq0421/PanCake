extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")
const LAUNCH_SCREENSHOT := "res://tmp/validation/formal_payment_collection_fx_launch_1920x1080.png"
const IMPACT_SCREENSHOT := "res://tmp/validation/formal_payment_collection_fx_impact_1920x1080.png"

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("FORMAL_PAYMENT_COLLECTION_FX_GPU_PREVIEW_FAIL\nGPU preview must run without --headless")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await process_frame
	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	for _frame in range(8):
		await process_frame

	workstation.call("_show_formal_payment_coins", 22)
	var coins: Array[TextureRect] = []
	for value in Array(workstation.get("_formal_payment_coin_sprites")):
		var coin := value as TextureRect
		if is_instance_valid(coin):
			coins.append(coin)
	var live_coins: Array = workstation.get("_formal_payment_coin_sprites")
	live_coins.clear()
	_check(coins.size() == 2, "preview has two denomination coins")
	workstation.global_status_label.text = "金币 22  ·  营业日 1  ·  口碑 0  ·  熟练度（煎饼）0"
	workstation.call("_play_formal_payment_collection_feedback", 22, coins, false)
	await create_timer(0.11).timeout
	await process_frame
	var launch_path := await _capture(LAUNCH_SCREENSHOT)
	await create_timer(0.31).timeout
	await process_frame
	var impact_path := await _capture(IMPACT_SCREENSHOT)

	workstation.queue_free()
	await process_frame
	if failures.is_empty():
		print("FORMAL_PAYMENT_COLLECTION_FX_GPU_PREVIEW_PASS")
		print("FORMAL_PAYMENT_COLLECTION_FX_LAUNCH_SCREENSHOT=%s" % launch_path)
		print("FORMAL_PAYMENT_COLLECTION_FX_IMPACT_SCREENSHOT=%s" % impact_path)
		quit(0)
		return
	printerr("FORMAL_PAYMENT_COLLECTION_FX_GPU_PREVIEW_FAIL\n" + "\n".join(failures))
	quit(1)


func _capture(resource_path: String) -> String:
	await RenderingServer.frame_post_draw
	var absolute_path := ProjectSettings.globalize_path(resource_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var image := root.get_texture().get_image()
	var save_error := image.save_png(absolute_path)
	_check(save_error == OK and image.get_size() == Vector2i(1920, 1080), "GPU frame saves at 1920×1080")
	return absolute_path


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
