extends SceneTree

const OVERLAY_SCENE := preload("res://scenes/ui/upgrade_workshop_overlay.tscn")
const WORKSTATION_SCENE_PATH := "res://scenes/gameplay/five_area_workstation.tscn"

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(Engine.is_editor_hint(), "self-check runs with editor behavior enabled")
	var overlay := OVERLAY_SCENE.instantiate() as UpgradeWorkshopOverlay
	var authored_worktop := overlay.get_node_or_null("EditorPreview/SyncedWorkstationPreview/SafeArea/JianbingStallArtwork/PancakeWorktopHotspots") as Control
	var authored_preview_paths := {
		"EggCarton/Visual/Contents": "egg-carton-overlay-6-egg-512.png",
		"BaocuiBasket/Visual": "baocui-6.png",
		"ScallionTray/Visual": "scallion-crock-full.png",
		"CorianderTray/Visual": "cilantro-jar-full.png",
		"HamSource/Visual": "empty-square-ingredient-tray-ham-6.png",
		"PorkFlossSource/Visual": "empty-square-ingredient-tray-6.png",
	}
	for visual_path in authored_preview_paths:
		var authored_visual := authored_worktop.get_node_or_null(visual_path) as TextureRect if authored_worktop != null else null
		_check(
			authored_visual != null
			and authored_visual.texture != null
			and authored_visual.texture.resource_path.ends_with(str(authored_preview_paths[visual_path])),
			"scene-authored editor preview includes %s" % visual_path
		)
	root.add_child(overlay)
	await process_frame
	await process_frame
	var direct_material_previews := overlay.get_node_or_null("EditorMaterialPreviews") as Control
	_check(direct_material_previews != null and direct_material_previews.visible, "editor workshop shows its direct material positioning guides")
	if direct_material_previews != null:
		for preview_path in ["BaocuiBasket", "PorkFlossTray", "HamTray", "SweetSauceJar", "ScallionCrock", "CorianderCrock", "EggCarton", "EggCarton/Contents", "BatterLadle"]:
			var preview := direct_material_previews.get_node_or_null(preview_path) as TextureRect
			_check(preview != null and preview.visible and preview.texture != null, "direct editor guide shows %s" % preview_path)
	var preview_host := overlay.get_node_or_null("EditorPreview") as Control
	var synced_preview := (
		preview_host.get_node_or_null("SyncedWorkstationPreview") as Control
		if preview_host != null
		else null
	)
	_check(synced_preview != null, "editor preview dynamically instantiates the formal workstation")
	_check(
		synced_preview != null and synced_preview.scene_file_path == WORKSTATION_SCENE_PATH,
		"editor preview retains the formal workstation as its scene source"
	)
	_check(
		synced_preview != null
		and synced_preview.get_node_or_null("SafeArea/JianbingStallArtwork") != null
		and synced_preview.get_node_or_null("FiveAreaInfrastructure/Stations/FreshSoyMilkStation") != null
		and synced_preview.get_node_or_null("FiveAreaInfrastructure/Stations/CartoonYoutiaoFryer") != null,
		"editor preview exposes the formal workstation equipment layout"
	)
	var pancake_worktop := (
		synced_preview.get_node_or_null("SafeArea/JianbingStallArtwork/PancakeWorktopHotspots") as Control
		if synced_preview != null
		else null
	)
	var egg_contents := pancake_worktop.get_node_or_null("EggCarton/Visual/Contents") as TextureRect if pancake_worktop != null else null
	var baocui_visual := pancake_worktop.get_node_or_null("BaocuiBasket/Visual") as TextureRect if pancake_worktop != null else null
	_check(egg_contents != null and egg_contents.visible and egg_contents.texture != null, "editor workshop preview shows a full egg carton")
	_check(baocui_visual != null and baocui_visual.visible and baocui_visual.texture != null and baocui_visual.texture.resource_path.ends_with("baocui-6.png"), "editor workshop preview shows the full baocui basket")
	for source_path in ["ScallionTray", "CorianderTray", "HamSource", "PorkFlossSource", "SecretSauceSource", "BatterLadleSource"]:
		var source := pancake_worktop.get_node_or_null(source_path) as Control if pancake_worktop != null else null
		var visual := source.get_node_or_null("Visual") as TextureRect if source != null else null
		_check(source != null and source.visible and visual != null and visual.visible and visual.texture != null, "editor workshop preview shows %s artwork" % source_path)
	# Godot's scene editor can reapply nested-scene defaults after @tool _ready().
	# The overlay must restore its preview on the following editor frame.
	var egg_carton := pancake_worktop.get_node_or_null("EggCarton") as Control if pancake_worktop != null else null
	if egg_carton != null:
		egg_carton.visible = false
	if egg_contents != null:
		egg_contents.texture = null
	await process_frame
	_check(egg_carton != null and egg_carton.visible, "editor preview restores material visibility after nested-scene refresh")
	_check(egg_contents != null and egg_contents.texture != null, "editor preview restores full material artwork after nested-scene refresh")
	var soy_station := (
		synced_preview.get_node_or_null("FiveAreaInfrastructure/Stations/FreshSoyMilkStation") as Control
		if synced_preview != null
		else null
	)
	var soy_dispenser_preview := soy_station.get_node_or_null("MachineAssembly/EditorPreviewMachine") as TextureRect if soy_station != null else null
	var soy_cup_stack_preview := soy_station.get_node_or_null("EditorPreviewCupStack") as TextureRect if soy_station != null else null
	var soy_sugar_jar_preview := soy_station.get_node_or_null("EditorPreviewSugarJar") as TextureRect if soy_station != null else null
	_check(soy_dispenser_preview != null and soy_dispenser_preview.texture != null, "editor preview loads the basic soy dispenser artwork")
	_check(soy_cup_stack_preview != null and soy_cup_stack_preview.texture != null, "editor preview loads a full soy cup stack")
	_check(soy_sugar_jar_preview != null and soy_sugar_jar_preview.texture != null, "editor preview loads the soy sugar jar")
	if soy_station != null and soy_dispenser_preview != null:
		soy_station.set("editor_preview_tier", 1)
		await process_frame
		await process_frame
		_check(soy_dispenser_preview.texture.resource_path.ends_with("automatic-soy-milk-dispenser-transparent.png"), "editor preview switches to the intermediate soy machine")
		soy_station.set("editor_preview_tier", 2)
		await process_frame
		await process_frame
		var right_cup_preview := soy_station.get_node_or_null("MachineAssembly/EditorPreviewRightCup") as TextureRect
		var right_nozzle_guide := soy_station.get_node_or_null("MachineAssembly/EditorPreviewRightNozzleGuide") as Label
		_check(soy_dispenser_preview.texture.resource_path.ends_with("automatic-soy-milk-dispenser-two-outlets-transparent.png"), "editor preview switches to the advanced soy machine")
		_check(right_cup_preview != null and right_cup_preview.visible, "advanced editor preview shows the second cup position")
		_check(right_nozzle_guide != null and right_nozzle_guide.visible, "advanced editor preview shows the second outlet position")
		var advanced_rect_before := Rect2(soy_station.get("advanced_machine_rect"))
		soy_station.set("advanced_machine_rect", Rect2(advanced_rect_before.position + Vector2(6.0, 4.0), advanced_rect_before.size))
		await process_frame
		_check(soy_dispenser_preview.position == advanced_rect_before.position + Vector2(6.0, 4.0), "editing the advanced artwork rectangle updates its editor preview")
		soy_station.set("advanced_machine_rect", advanced_rect_before)
		await process_frame
		var left_cup_preview := soy_station.get_node_or_null("MachineAssembly/EditorPreviewLeftCup") as TextureRect
		var left_cup_position_before := left_cup_preview.position if left_cup_preview != null else Vector2.ZERO
		var left_cup_offset_before := Vector2(soy_station.get("advanced_left_cup_offset"))
		soy_station.set("advanced_left_cup_offset", left_cup_offset_before + Vector2(5.0, 3.0))
		await process_frame
		_check(left_cup_preview != null and left_cup_preview.position == left_cup_position_before + Vector2(5.0, 3.0), "editing the advanced cup offset updates its editor preview")
		soy_station.set("advanced_left_cup_offset", left_cup_offset_before)
		var left_nozzle_guide := soy_station.get_node_or_null("MachineAssembly/EditorPreviewLeftNozzleGuide") as Label
		var guide_position_before := left_nozzle_guide.position if left_nozzle_guide != null else Vector2.ZERO
		var advanced_left_before := Vector2(soy_station.get("advanced_left_nozzle_texture_position"))
		soy_station.set("advanced_left_nozzle_texture_position", advanced_left_before + Vector2(20.0, 0.0))
		await process_frame
		_check(left_nozzle_guide != null and left_nozzle_guide.position.x > guide_position_before.x, "editing the advanced outlet coordinate updates its editor guide")
		soy_station.set("advanced_left_nozzle_texture_position", advanced_left_before)
	overlay.free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("UPGRADE_WORKSHOP_EDITOR_PREVIEW_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("UPGRADE_WORKSHOP_EDITOR_PREVIEW_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
