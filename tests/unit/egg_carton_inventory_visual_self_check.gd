extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")
const PROGRESSION_SERVICE := preload("res://scripts/services/five_area_progression_service.gd")
const CATALOG := preload("res://scripts/data/five_area_catalog.gd")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	await process_frame
	var hotspots := workstation.get_node_or_null("SafeArea/JianbingStallArtwork/PancakeWorktopHotspots") as PancakeWorktopHotspots
	var carton := hotspots.get_node_or_null("EggCarton") as Control if hotspots != null else null
	var visual := carton.get_node_or_null("Visual") as TextureRect if carton != null else null
	var contents := visual.get_node_or_null("Contents") as TextureRect if visual != null else null
	var source := carton.get_node_or_null("Hotspot") as ProductDragSource if carton != null else null
	_check(hotspots != null, "the physical egg carton belongs to the worktop controller")
	_check(carton != null and visual != null and contents != null, "the egg-carton component owns visual, contents, and hotspot nodes")
	if hotspots != null and carton != null:
		var starter_progression := PROGRESSION_SERVICE.new()
		hotspots._refresh_optional_stock_visuals(starter_progression)
		_check(not starter_progression.owns_stock(&"stock.pancake.egg") and not carton.visible, "a new game keeps egg locked and removes its carton from the worktop")
		starter_progression.unlocked_stock_ids[&"stock.pancake.egg"] = true
		hotspots._refresh_optional_stock_visuals(starter_progression)
		_check(carton.visible, "unlocking egg restores its carton to the worktop")
	if carton != null and visual != null and contents != null:
		_check(carton.get_global_rect() == visual.get_global_rect() and visual.get_global_rect() == contents.get_global_rect(), "egg contents share the carton component coordinates")
	if hotspots != null:
		_check(int(CATALOG.stock_definition(&"stock.pancake.egg").get("restock_capacity", 0)) == 10, "egg restock capacity is ten")
		_check(hotspots.egg_content_textures.size() == 11, "egg inventory maps the empty tray plus all ten filled states")
		var empty_texture_path := hotspots.egg_content_textures[0].resource_path if hotspots.egg_content_textures[0] != null else ""
		_check(empty_texture_path.ends_with("empty-square-ingredient-tray-v1.png"), "zero egg stock uses the requested empty tray")
		for count in range(0, 11):
			hotspots._update_egg_inventory_visual(count, 10)
			var texture_path := visual.texture.resource_path if visual != null and visual.texture != null else ""
			var expected_filename := "empty-square-ingredient-tray-v1.png" if count == 0 else "egg-v1-%d.png" % count
			_check(texture_path.ends_with(expected_filename), "%d-egg stock state uses its matching complete tray" % count)
			_check(contents == null or (not contents.visible and contents.texture == null), "legacy egg overlay stays disabled")
	_check(source != null and source is EggCartonDragSource and source.hold_enabled and is_equal_approx(source.hold_threshold_seconds, 0.20) and not source.native_drag_enabled, "egg carton uses click-to-place plus a 0.2-second hold-to-restock")
	if source is EggCartonDragSource:
		_check(not source._has_point(Vector2.ZERO), "transparent margin outside the egg-carton artwork is not clickable")
		source.set_filled_slot_count(3)
		var first_egg := Vector2(source.size.x * 0.75, source.size.y * 0.52)
		var empty_upper_left := Vector2(source.size.x * 0.25, source.size.y * 0.36)
		_check(source._has_point(first_egg), "a filled egg slot is a valid pointer target")
		_check(source._slot_index_at(empty_upper_left) == -1, "an empty egg slot cannot start a drag")
		_check(source._slot_index_at(first_egg) == 0, "click hit-testing identifies the exact visible egg slot")
	workstation.queue_free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("EGG_CARTON_INVENTORY_VISUAL_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("EGG_CARTON_INVENTORY_VISUAL_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
