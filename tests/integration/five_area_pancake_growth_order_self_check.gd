extends SceneTree

const SCENE = preload("res://scenes/gameplay/initial_unlock_workstation.tscn")
const SESSION = preload("res://scripts/gameplay/p1_session.gd")
const CATALOG = preload("res://scripts/data/workstation_expansion_catalog.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var workstation := SCENE.instantiate()
	root.add_child(workstation)
	await process_frame
	var press := workstation.get_node_or_null("SafeArea/LeftRack/PressSpreaderButton") as Button
	var auto_brush := workstation.get_node_or_null("SafeArea/LeftRack/AutomaticSauceBrushButton") as Button
	var coriander := workstation.get_node_or_null("SafeArea/IngredientRack/CorianderButton") as Button
	var mustard := workstation.get_node_or_null("SafeArea/IngredientRack/PreservedMustardButton") as Button
	var tutorial_label := workstation.get_node_or_null("SafeArea/BottomStrip/TutorialGuideLabel") as Label
	_check(press != null and auto_brush != null and coriander != null and mustard != null and tutorial_label != null, "formal workstation owns stable growth controls and tutorial strip nodes")
	workstation.call("apply_progression_effects", {"owned_growth_ids": [&"growth.automation.pancake.press_once", &"growth.automation.pancake.auto_sauce_brush"], "device_tiers": {&"device.pancake_griddle": 2}})
	_check(press.visible and auto_brush.visible and bool(workstation.get("_intermediate_griddle_owned")), "activated pancake growth refreshes press, automatic brush, and intermediate-griddle effects")
	workstation.call("apply_progression_effects", {"owned_items": [&"tool.spreader.wide"]})
	var spreader_artwork := workstation.get_node_or_null("SafeArea/PanBase/PancakeSurface/SpreaderArtwork") as Sprite2D
	var spreader_button_artwork := workstation.get_node_or_null("SafeArea/LeftRack/ScraperButton/Artwork") as TextureRect
	_check(is_equal_approx(float(workstation.get("_spreader_width_multiplier")), CATALOG.WIDE_SPREADER_WIDTH_MULTIPLIER), "wide spreader applies its full gameplay width multiplier")
	_check(spreader_artwork != null and spreader_artwork.texture != null and spreader_artwork.texture.resource_path.ends_with("batter_spreader_upgrade_v1.png"), "wide spreader swaps the held-tool artwork")
	_check(spreader_button_artwork != null and spreader_button_artwork.texture != null and spreader_button_artwork.texture.resource_path.ends_with("batter_spreader_upgrade_v1.png"), "wide spreader swaps the rack artwork")
	workstation.tool_controller.select_tool(ToolController.Tool.SCRAPER)
	var expected_cursor_radius: float = workstation.parameters.scraper_width * CATALOG.WIDE_SPREADER_WIDTH_MULTIPLIER * 0.5 / float(workstation.parameters.grid_size) * workstation.pancake_surface.size.x
	_check(is_equal_approx(workstation.pancake_surface.cursor_radius_pixels, expected_cursor_radius), "wide spreader enlarges the player-visible contact indicator with its real effect")
	var session: RefCounted = SESSION.new()
	session.call("start", {"tutorial_no_countdown": true, "time_limit": 2.0})
	session.call("advance_time", 5.0)
	_check(not bool(session.get("has_patience_countdown")) and is_equal_approx(float(session.call("patience_ratio")), 1.0), "tutorial P1 session has no countdown and cannot become impatient from time")
	workstation.queue_free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("FIVE_AREA_PANCAKE_GROWTH_ORDER_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("FIVE_AREA_PANCAKE_GROWTH_ORDER_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
