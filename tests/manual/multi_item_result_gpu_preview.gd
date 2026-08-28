extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const SCREENSHOT_PATH := "res://tmp/validation/multi_item_result_gpu_preview_1920x1080.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("MULTI_ITEM_RESULT_GPU_PREVIEW_FAIL\nRun without --headless")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	for _frame in 6:
		await process_frame
	var workstation := game.get_node("Workstation")
	workstation._populate_result({
		"review_items": [
			{"expected_product_id": &"product.pancake.custom", "actual_product_id": &"product.pancake.custom", "product": {"product_id": &"product.pancake.custom", "dimension_scores": {"thickness": 58.0, "heat": 72.0, "order": 100.0}}, "order_item": {"ingredient_ids": []}, "score": 58.0, "qualified": false, "feedback": "煎饼评分未达60分，本份不付款"},
			{"expected_product_id": &"product.youtiao.plain", "actual_product_id": &"product.youtiao.plain", "product": {"product_id": &"product.youtiao.plain", "quality": 92.0}, "order_item": {"mismatch_reasons": PackedStringArray()}, "score": 92.0, "qualified": true, "feedback": "油条符合订单要求"},
			{"expected_product_id": &"product.fresh_soy_milk.yellow_bean", "actual_product_id": &"product.fresh_soy_milk.yellow_bean", "product": {"product_id": &"product.fresh_soy_milk.yellow_bean", "fill_ratio": 0.96, "sugar_servings": 0, "temperature_mode": &"room_temperature"}, "order_item": {"requested_sugar_servings": 0, "requested_temperature_mode": &"room_temperature", "mismatch_reasons": PackedStringArray()}, "score": 96.0, "qualified": true, "feedback": "黄豆豆浆符合订单要求"},
		],
	})
	workstation._order_summary_visible = true
	workstation._open_result_detail()
	for _frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var output_absolute := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(output_absolute.get_base_dir())
	var save_error := root.get_texture().get_image().save_png(output_absolute)
	if save_error == OK:
		print("MULTI_ITEM_RESULT_GPU_PREVIEW_PASS")
		quit()
		return
	push_error("MULTI_ITEM_RESULT_GPU_PREVIEW_FAIL\nScreenshot save failed")
	quit(1)
