extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/main.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_session := root.get_node_or_null("GameSession")
	if game_session != null:
		game_session.call("begin_new_game")
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var workstation := main.get_node("Workstation") as Workstation
	workstation.set_process(false)

	_fill_product_base(workstation.pancake_model)
	workstation.ingredient_model.place(
		IngredientModel.BAOCUI,
		Vector2(workstation.pancake_model.grid_size - 1, workstation.pancake_model.grid_size - 1) * 0.5,
		0.0,
		workstation.pancake_model
	)
	workstation.ingredient_stock_model.consume(IngredientModel.BAOCUI)
	await process_frame
	await process_frame

	var capture_directory := ProjectSettings.globalize_path("res://tmp/validation")
	DirAccess.make_dir_recursive_absolute(capture_directory)
	var capture_path := capture_directory.path_join("ingredient_stock_visual_latest.png")
	if root.get_texture().get_image().save_png(capture_path) != OK:
		push_error("Failed to save ingredient stock visual capture")
		quit(1)
		return
	print("INGREDIENT_STOCK_VISUAL_SMOKE_PASS: %s" % capture_path)
	quit(0)


func _fill_product_base(model: PancakeModel) -> void:
	var center := Vector2(model.grid_size - 1, model.grid_size - 1) * 0.5
	var radius := float(model.grid_size) * 0.42
	for y in model.grid_size:
		for x in model.grid_size:
			var index := model.index_of(Vector2i(x, y))
			if Vector2(x, y).distance_to(center) <= radius:
				model.coverage[index] = 1.0
				model.thickness[index] = 1.0
				model.wetness[index] = 0.25
				model.doneness[index] = 0.45
	model.revision += 1
