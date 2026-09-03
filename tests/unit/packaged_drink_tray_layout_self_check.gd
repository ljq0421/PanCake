extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/cartoon_breakfast_workstation.tscn")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var workstation := WORKSTATION_SCENE.instantiate() as CartoonBreakfastWorkstation
	root.add_child(workstation)
	await process_frame
	var station := workstation.packaged_drink_station
	var sources: Array[ProductDragSource] = station.product_sources()
	var expected_rect := Rect2(workstation.call("_design_rect", Rect2(1270.0, 680.0, 345.0, 210.0)))
	_check(station.position.is_equal_approx(expected_rect.position) and station.size.is_equal_approx(expected_rect.size), "boxed juice hotspot aligns with the scaled baked drink plate")
	_check(station.baked_into_workbench_artwork and sources.size() == 1, "cartoon station uses one baked tray with one drag source")
	var source := sources[0]
	_check(source.texture_normal == null and not (source.get_node("CountBadge") as Label).visible, "baked tray adds only carton sprites and no inventory badge")
	_check(source.find_children("Representative*", "TextureRect", false, false).all(func(item: Node) -> bool: return source.get_global_rect().encloses((item as TextureRect).get_global_rect())), "cartons stay inside the interactive drink plate")
	root.size = Vector2i(1280, 720)
	await process_frame
	_check(station.size.is_equal_approx(expected_rect.size) and source.size == station.size, "logical tray alignment remains stable at 1280 by 720")
	workstation.queue_free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PACKAGED_DRINK_TRAY_LAYOUT_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("PACKAGED_DRINK_TRAY_LAYOUT_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
