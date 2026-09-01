extends SceneTree

const WORKSTATION := preload("res://scripts/gameplay/five_area_workstation.gd")
const WORKSTATION_SCENE := preload("res://scenes/gameplay/four_area_workstation.tscn")
const WORKSHOP_SCENE := preload("res://scenes/ui/upgrade_workshop_overlay.tscn")
const COMPACT_GRIDDLE_SCENE := preload("res://scenes/gameplay/compact_griddle_unit.tscn")
const PACKAGE_GRID := preload("res://scripts/ui/pancake_package_ingredient_grid.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var tray := WORKSTATION_SCENE.instantiate()
	var tray_button := tray.get_node_or_null("FiveAreaInfrastructure/Stations/PancakeHoldingTray") as TextureButton
	_check(tray_button != null and tray_button.texture_normal != null and tray_button.texture_normal.resource_path.ends_with("container-l-empty-p1-v2-transparent.png"), "formal workstation authors one clickable P1 L holding tray")
	var formal_tray_position := tray_button.position if tray_button != null else Vector2.ZERO
	var formal_tray_size := tray_button.size if tray_button != null else Vector2.ZERO
	_check(tray.get_node_or_null("FiveAreaInfrastructure/Stations/PancakeHoldingTray/SlotFrame01") == null and tray.get_node_or_null("FiveAreaInfrastructure/Stations/PancakeHoldingTray/SlotFrame02") == null, "retired duplicate tray frames are removed")
	var sources: Array[ProductDragSource] = []
	for source_index in range(1, 4):
		sources.append(tray.get_node_or_null("FiveAreaInfrastructure/Stations/PancakeHoldingTray/PancakeHoldingSource%02d" % source_index) as ProductDragSource)
	var first_source := sources[0]
	_check(sources.size() == 3 and sources.all(func(source): return source != null and source.size == Vector2(164.0, 164.0) and source.scale.is_equal_approx(Vector2(1.066666, 1.066666))) and sources[0].position.x < sources[1].position.x and sources[1].position.x < sources[2].position.x and sources[0].position.y > sources[1].position.y and sources[1].position.y > sources[2].position.y and sources[0].z_index < sources[1].z_index and sources[1].z_index < sources[2].z_index, "three same-size packaged pancakes are deliberately offset into a readable stack")
	_check(WORKSTATION.PANCAKE_HOLDING_PACKAGE_TEXTURE.resource_path.ends_with("paper_bag_package_v1.png"), "finished-tray slots keep the packaged pancake artwork separate from order cards")
	var egg_baocui := {
		"ingredient_ids": [&"stock.pancake.egg", &"stock.pancake.baocui"],
		"sauce_ids": [&"stock.pancake.sauce.sweet_flour"],
	}
	var herb_pancake := {
		"ingredient_ids": [&"stock.pancake.scallion", &"stock.pancake.coriander"],
		"sauce_ids": [&"stock.pancake.sauce.sweet_flour"],
	}
	tray.call("_refresh_pancake_recipe_markers", first_source, egg_baocui)
	var tray_grid := first_source.get_node_or_null("PancakePackageIngredientGrid") as PancakePackageIngredientGrid
	var expected_selected := PACKAGE_GRID.selected_item_ids(egg_baocui)
	_check(tray_grid != null and tray_grid.ITEM_IDS.size() == 8 and tray_grid.selected_item_ids_snapshot() == expected_selected and not tray_grid.selected_item_ids_snapshot().has(&"stock.pancake.ham_sausage"), "tray paper bag renders the fixed eight-item three-by-three grid and checks only selected ingredients")
	root.add_child(tray)
	var griddle := COMPACT_GRIDDLE_SCENE.instantiate()
	root.add_child(griddle)
	griddle.mark_ready(egg_baocui)
	await process_frame
	var griddle_grid := griddle.package_visual.get_node_or_null("PancakePackageIngredientGrid") as PancakePackageIngredientGrid
	var reveal_grid := griddle.fold_overlay.get_node_or_null("PancakePackageIngredientGrid") as PancakePackageIngredientGrid
	var reveal_top_left: Vector2 = griddle.fold_overlay.get_global_transform_with_canvas() * griddle.fold_overlay.package_display_rect.position
	var reveal_bottom_right: Vector2 = griddle.fold_overlay.get_global_transform_with_canvas() * griddle.fold_overlay.package_display_rect.end
	var ready_top_left: Vector2 = griddle.package_visual.get_global_transform_with_canvas() * Vector2.ZERO
	var ready_bottom_right: Vector2 = griddle.package_visual.get_global_transform_with_canvas() * griddle.package_visual.size
	_check(griddle.package_visual.size.is_equal_approx(first_source.size) and griddle.package_visual.scale.is_equal_approx(first_source.scale) and griddle_grid != null and reveal_grid != null and griddle_grid.selected_item_ids_snapshot() == expected_selected and reveal_grid.selected_item_ids_snapshot() == expected_selected and reveal_top_left.is_equal_approx(ready_top_left) and reveal_bottom_right.is_equal_approx(ready_bottom_right), "griddle reveal and ready bag share the tray-sized geometry and identical checked ingredient grid")
	griddle.queue_free()
	await process_frame
	_check(WORKSTATION._pancake_holding_tooltip(egg_baocui).contains("鸡蛋") and WORKSTATION._pancake_holding_tooltip(herb_pancake).contains("香菜"), "holding-tray tooltip names the complete stored recipe")
	tray.queue_free()
	await process_frame
	var session := root.get_node_or_null("GameSession")
	if session != null:
		session.call("begin_new_game")
		var progression: RefCounted = session.call("progression_service")
		progression.set("owned_growth_ids", {&"growth.capacity.pancake_holding_tray.first_slot": true})
		var formal_workstation := WORKSTATION_SCENE.instantiate()
		root.add_child(formal_workstation)
		await process_frame
		var formal_tray := formal_workstation.get_node_or_null("FiveAreaInfrastructure/Stations/PancakeHoldingTray") as TextureButton
		_check(formal_tray != null and formal_tray.visible and int(session.call("pancake_holding_tray_slot_count")) == 3, "one purchase exposes the tray and its three storage positions")
		formal_workstation.queue_free()
		await process_frame
	var workshop := WORKSHOP_SCENE.instantiate()
	root.add_child(workshop)
	await process_frame
	_check(workshop.get_node_or_null("UpgradeProps/WorkshopProp_growth_capacity_pancake_holding_tray_first_slot") is Button and workshop.get_node_or_null("UpgradeProps/WorkshopProp_growth_capacity_pancake_holding_tray_second_slot") == null, "workshop exposes one holding-tray purchase and removes the second upgrade")
	var preview := workshop.get_node_or_null("UpgradeProps/PancakeHoldingTrayPreview") as TextureRect
	_check(preview != null and preview.texture != null and preview.texture.resource_path.ends_with("container-l-empty-p1-v2-transparent.png"), "workshop preview uses the requested P1 L tray artwork")
	_check(preview != null and preview.position.is_equal_approx(formal_tray_position) and preview.size.is_equal_approx(formal_tray_size), "workshop preview aligns with the finished tray on the formal workstation")
	_check(preview != null and not preview.visible, "workshop hides the ghosted tray preview once the live tray is owned")
	if session != null:
		var progression: RefCounted = session.call("progression_service")
		progression.set("owned_growth_ids", {})
		workshop.refresh()
		_check(preview != null and preview.visible and is_equal_approx(preview.self_modulate.a, 0.42), "workshop keeps one ghosted tray preview before the tray is owned")
	workshop.free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PANCAKE_HOLDING_TRAY_DISPLAY_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("PANCAKE_HOLDING_TRAY_DISPLAY_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
