extends SceneTree

const ARTWORK_SCENE := preload("res://scenes/gameplay/jianbing_stall_artwork.tscn")
const SOY_SCENE := preload("res://scenes/gameplay/direct_soy_station.tscn")
const SCALE_FACTOR := 1.4
const SAUCE_VISUAL_SCALE_FACTOR := 1.5

const ORIGINAL_SIZES := {
	&"SecretSauceSource": Vector2(137.0, 148.4),
	&"ScallionTray": Vector2(146.0, 147.0),
	&"CorianderTray": Vector2(149.0, 149.0),
}

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var artwork := ARTWORK_SCENE.instantiate()
	root.add_child(artwork)
	var worktop := artwork.get_node("PancakeWorktopHotspots") as Control
	for source_name in ORIGINAL_SIZES:
		var source := worktop.get_node(str(source_name)) as Control
		var visual := source.get_node("Visual") as TextureRect
		var hotspot := source.get_node("Hotspot") as ProductDragSource
		var source_scale := SAUCE_VISUAL_SCALE_FACTOR if source_name == &"SecretSauceSource" else SCALE_FACTOR
		var expected_size: Vector2 = ORIGINAL_SIZES[source_name] * source_scale
		_check(source.size.is_equal_approx(expected_size), "%s uses its visual-normalized scale" % source_name)
		_check(visual.get_global_rect().is_equal_approx(source.get_global_rect()), "%s artwork follows the resized source rectangle" % source_name)
		_check(hotspot.get_global_rect().is_equal_approx(source.get_global_rect()), "%s hotspot follows the resized source rectangle" % source_name)

	var soy_station := SOY_SCENE.instantiate()
	root.add_child(soy_station)
	await process_frame
	soy_station.set_workshop_preview(true)
	var sugar_jar := soy_station.get_node("SugarJar") as TextureButton
	_check(sugar_jar.size.is_equal_approx(Vector2(157.0, 125.0) * SCALE_FACTOR), "sugar tray is exactly 1.4x its previous size")
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
