extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/five_area_workstation.tscn")

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	await process_frame
	var hotspots := workstation.get_node_or_null("FiveAreaInfrastructure/PancakeWorktopHotspots") as PancakeWorktopHotspots
	var carton := hotspots.get_node_or_null("EggBasketVisual") as TextureRect if hotspots != null else null
	var contents := hotspots.get_node_or_null("EggContentVisual") as TextureRect if hotspots != null else null
	var source := hotspots.get_node_or_null("EggHotspot") as ProductDragSource if hotspots != null else null
	_check(hotspots != null, "the physical egg carton owns a worktop-hotspot controller")
	_check(carton != null and contents != null, "the egg carton has fixed base and changing contents layers")
	if carton != null and contents != null:
		_check(Rect2(carton.position, carton.size) == Rect2(contents.position, contents.size), "egg overlays share the carton base coordinates")
	if hotspots != null:
		_check(hotspots.egg_content_textures.size() == 7 and hotspots.egg_content_textures[0] == null, "egg inventory maps empty stock plus all six filled states")
		for count in range(1, 7):
			hotspots._update_egg_inventory_visual(count, 6)
			var texture_path := contents.texture.resource_path if contents != null and contents.texture != null else ""
			_check(texture_path.ends_with("egg-carton-overlay-%d-egg-512.png" % count), "%d-egg stock state uses its matching overlay" % count)
	_check(source != null and source is EggCartonDragSource and source.hold_enabled and is_equal_approx(source.hold_threshold_seconds, 0.20) and source.native_drag_enabled, "egg carton supports both drag-to-griddle and a 0.2-second hold-to-restock")
	if source is EggCartonDragSource:
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
