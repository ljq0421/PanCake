extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")
const PROGRESSION_SERVICE := preload("res://scripts/services/five_area_progression_service.gd")

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
		_check(hotspots.egg_content_textures.size() == 7 and hotspots.egg_content_textures[0] == null, "egg inventory maps empty stock plus all six filled states")
		for count in range(1, 7):
			hotspots._update_egg_inventory_visual(count, 6)
			var texture_path := contents.texture.resource_path if contents != null and contents.texture != null else ""
			_check(texture_path.ends_with("egg-carton-overlay-%d-egg-512.png" % count), "%d-egg stock state uses its matching overlay" % count)
	_check(source != null and source is EggCartonDragSource and source.hold_enabled and is_equal_approx(source.hold_threshold_seconds, 0.20) and source.native_drag_enabled, "egg carton supports both drag-to-griddle and a 0.2-second hold-to-restock")
	if source is EggCartonDragSource:
		_check(not source._has_point(Vector2.ZERO), "transparent margin outside the egg-carton artwork is not clickable")
		source.set_filled_slot_count(3)
		var first_egg := Vector2(source.size.x * 0.25, source.size.y * 0.348)
		var empty_lower_right := Vector2(source.size.x * 0.75, source.size.y * 0.504)
		_check(source._has_point(first_egg), "a filled egg slot is a valid pointer target")
		_check(source._slot_index_at(empty_lower_right) == -1, "an empty egg slot cannot start a drag")
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = first_egg
		press.global_position = source.global_position + first_egg
		source._gui_input(press)
		_check(int(source.source_ref().get("carton_slot_index", -1)) == 0, "drag data identifies the exact clicked egg slot")
		source.end_gesture()
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
