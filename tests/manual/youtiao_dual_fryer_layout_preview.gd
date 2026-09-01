extends SceneTree

const FRYER_SCENE := preload("res://scenes/gameplay/cartoon_youtiao_fryer_toggle.tscn")
const OUTPUT_DIR := "res://tmp/validation/youtiao_dual_fryer_layout"
const STATES: Array[Dictionary] = [
	{"name": "both_raised", "left_lowered": false, "right_lowered": false},
	{"name": "left_lowered", "left_lowered": true, "right_lowered": false},
	{"name": "right_lowered", "left_lowered": false, "right_lowered": true},
	{"name": "both_lowered", "left_lowered": true, "right_lowered": true},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("YOUTIAO_DUAL_FRYER_LAYOUT_PREVIEW_FAIL\nGPU preview must run without --headless")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(900, 700))
	var background := ColorRect.new()
	background.color = Color("f5ead7")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var fryer := FRYER_SCENE.instantiate() as CartoonYoutiaoFryerToggle
	fryer.position = Vector2(40.0, 15.0)
	fryer.scale = Vector2(2.0, 2.0)
	root.add_child(fryer)
	await process_frame
	fryer.call("_ensure_visual_resources")
	fryer.shared_tray.visible = true
	fryer.shared_tray.preview_shared_products(fryer.call("_editor_preview_tray_entries", true), fryer.call("_shared_tray_textures"))
	fryer.status_label.visible = false
	if fryer.youtiao_progress_bar != null:
		fryer.youtiao_progress_bar.visible = false
	if fryer.chicken_progress_bar != null:
		fryer.chicken_progress_bar.visible = false
	if fryer.youtiao_progress_label != null:
		fryer.youtiao_progress_label.visible = false
	if fryer.chicken_progress_label != null:
		fryer.chicken_progress_label.visible = false
	for source in fryer.fryer_slot_sources:
		source.texture_normal = fryer.raw_youtiao_texture
		source.texture_disabled = fryer.raw_youtiao_texture
		source.visible = true
	for source in fryer.chicken_slot_sources:
		source.texture_normal = fryer.chicken_raw_texture
		source.texture_disabled = fryer.chicken_raw_texture
		source.visible = true

	for state in STATES:
		var left_lowered := bool(state["left_lowered"])
		var right_lowered := bool(state["right_lowered"])
		fryer.call("_apply_fryer_layout", true, left_lowered, true, right_lowered)
		if not left_lowered and not right_lowered:
			fryer.fryer_visual.texture = fryer.dual_raised_machine_texture
		elif not left_lowered:
			fryer.fryer_visual.texture = fryer.dual_left_raised_machine_texture
		elif not right_lowered:
			fryer.fryer_visual.texture = fryer.dual_right_raised_machine_texture
		else:
			fryer.fryer_visual.texture = fryer.dual_lowered_machine_texture
		for _frame in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var output_path := ProjectSettings.globalize_path("%s/%s.png" % [OUTPUT_DIR, state["name"]])
		DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
		var image := root.get_texture().get_image()
		if image.save_png(output_path) != OK:
			printerr("YOUTIAO_DUAL_FRYER_LAYOUT_PREVIEW_FAIL\nCould not save %s" % output_path)
			quit(1)
			return
	fryer.queue_free()
	print("YOUTIAO_DUAL_FRYER_LAYOUT_PREVIEW_PASS")
	quit(0)
