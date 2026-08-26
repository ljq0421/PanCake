extends SceneTree

const OVERLAY_SCENE := preload("res://scenes/ui/upgrade_workshop_overlay.tscn")
const WORKSTATION_SCENE_PATH := "res://scenes/gameplay/five_area_workstation.tscn"

var failures := PackedStringArray()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(Engine.is_editor_hint(), "self-check runs with editor behavior enabled")
	var overlay := OVERLAY_SCENE.instantiate() as UpgradeWorkshopOverlay
	root.add_child(overlay)
	await process_frame
	await process_frame
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
	var soy_station := (
		synced_preview.get_node_or_null("FiveAreaInfrastructure/Stations/FreshSoyMilkStation") as Control
		if synced_preview != null
		else null
	)
	var soy_dispenser_preview := soy_station.get_node_or_null("MachineAssembly/EditorPreviewBasicMachine") as TextureRect if soy_station != null else null
	var soy_cup_stack_preview := soy_station.get_node_or_null("EditorPreviewCupStack") as TextureRect if soy_station != null else null
	var soy_sugar_jar_preview := soy_station.get_node_or_null("EditorPreviewSugarJar") as TextureRect if soy_station != null else null
	var soy_ice_button_preview := soy_station.get_node_or_null("EditorPreviewIceTray") as TextureRect if soy_station != null else null
	_check(soy_dispenser_preview != null and soy_dispenser_preview.texture != null, "editor preview loads the basic soy dispenser artwork")
	_check(soy_cup_stack_preview != null and soy_cup_stack_preview.texture != null, "editor preview loads a full soy cup stack")
	_check(soy_sugar_jar_preview != null and soy_sugar_jar_preview.texture != null, "editor preview loads the soy sugar jar")
	_check(soy_ice_button_preview != null and soy_ice_button_preview.texture != null, "editor preview loads the soy ice tray")
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
