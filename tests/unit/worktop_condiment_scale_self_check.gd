extends SceneTree

const ARTWORK_SCENE := preload("res://scenes/gameplay/jianbing_stall_artwork.tscn")
const SOY_SCENE := preload("res://scenes/gameplay/direct_soy_station.tscn")
const CONDIMENT_SOURCES := [&"SecretSauceSource", &"ScallionTray", &"CorianderTray"]

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var artwork := ARTWORK_SCENE.instantiate()
	root.add_child(artwork)
	var worktop := artwork.get_node("PancakeWorktopHotspots") as Control
	for source_name in CONDIMENT_SOURCES:
		var source := worktop.get_node(str(source_name)) as Control
		var visual := source.get_node("Visual") as TextureRect
		var hotspot := source.get_node("Hotspot") as ProductDragSource
		_check(visual.size.is_equal_approx(WorkbenchArtSpec.CONTAINER_S), "%s artwork uses the P1 S component size" % source_name)
		_check(str(visual.get_meta(&"workbench_container_size_class", "")) == "S", "%s records the reusable S component class" % source_name)
		_check(source.get_global_rect().encloses(visual.get_global_rect()), "%s keeps its S artwork inside the established hit target" % source_name)
		_check(hotspot.get_global_rect().is_equal_approx(source.get_global_rect()), "%s hotspot follows the resized source rectangle" % source_name)

	var soy_station := SOY_SCENE.instantiate()
	root.add_child(soy_station)
	await process_frame
	soy_station.set_workshop_preview(true)
	var sugar_jar := soy_station.get_node("SugarJar") as TextureButton
	_check(sugar_jar.size.is_equal_approx(WorkbenchArtSpec.CONTAINER_S), "sugar tray uses the P1 S component size")
	_check(str(sugar_jar.get_meta(&"workbench_container_size_class", "")) == "S", "sugar tray records the reusable S component class")
	_check(sugar_jar.has_method("_has_point") and sugar_jar.call("_has_point", sugar_jar.size * 0.5), "sugar tray keeps its texture-shaped click hotspot")

	artwork.queue_free()
	soy_station.queue_free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("WORKTOP_CONDIMENT_SCALE_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("WORKTOP_CONDIMENT_SCALE_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
