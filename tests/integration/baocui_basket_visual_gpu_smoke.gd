extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/four_area_workstation.tscn")
const STOCK_ID := &"stock.pancake.baocui"
const OUTPUT_DIR := "res://tmp/validation/baocui_basket_states"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("BAOCUI_BASKET_VISUAL_GPU_SMOKE_FAIL\nRequires a GPU-backed Godot window")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var session := root.get_node_or_null("GameSession")
	if session == null:
		printerr("BAOCUI_BASKET_VISUAL_GPU_SMOKE_FAIL\nGameSession is unavailable")
		quit(1)
		return
	session.call("begin_new_game")
	var progression: RefCounted = session.call("progression_service")
	progression.set("unlocked_stock_ids", {STOCK_ID: true})
	progression.set("coins", 99)
	session.call("_sync_progression_to_save")
	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	for _frame in range(8):
		await process_frame
	for stock_count in range(7):
		var inventory := Dictionary(session.call("inventory_snapshot"))
		inventory[str(STOCK_ID)] = stock_count
		session.call("save_inventory", inventory)
		for _frame in range(3):
			await process_frame
		await RenderingServer.frame_post_draw
		var output_path := "%s/baocui_%d.png" % [OUTPUT_DIR, stock_count]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path).get_base_dir())
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output_path))
	workstation.queue_free()
	await process_frame
	print("BAOCUI_BASKET_VISUAL_GPU_SMOKE_PASS\nBAOCUI_BASKET_SCREENSHOTS=%s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)
