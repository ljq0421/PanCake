@tool
extends Node

# Keep these as paths rather than preloaded resources. The helper executes in
# the editor only, so exported builds retain DirectSoyStation's lazy-loading
# behavior and do not pull locked-area artwork into the initial workstation load.
const BASIC_MACHINE_TEXTURE_PATH := "res://resources/art/workstation/machines/soy_milk/soy-milk-dispenser.png"
const FULL_CUP_STACK_TEXTURE_PATH := "res://resources/art/products/soy_milk/soy_milk_plastic_cup_stack_8_v3_bold_cartoon_transparent.png"
const SUGAR_JAR_TEXTURE_PATH := "res://resources/art/workstation/machines/soy_milk/sugar-jar-for-soy-milk.png"
const ICE_TRAY_TEXTURE_PATH := "res://resources/art/workstation/machines/soy_milk/ice-tray-with-scoop.png"
const BASIC_MACHINE_PREVIEW_NAME := &"EditorPreviewBasicMachine"
const CUP_STACK_PREVIEW_NAME := &"EditorPreviewCupStack"
const SUGAR_JAR_PREVIEW_NAME := &"EditorPreviewSugarJar"
const ICE_TRAY_PREVIEW_NAME := &"EditorPreviewIceTray"


func _ready() -> void:
	var editor_preview_enabled := Engine.is_editor_hint()
	set_process(editor_preview_enabled)
	if not editor_preview_enabled:
		return
	call_deferred("_apply_editor_preview")


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_sync_editor_preview_geometry()


func _apply_editor_preview() -> void:
	if not Engine.is_editor_hint():
		return
	var station := get_parent() as Control
	if station == null:
		return
	var dispenser := station.get_node_or_null("MachineAssembly/SoyMilkDispenser") as TextureRect
	var cup_stack := station.get_node_or_null("CupStack") as TextureButton
	var sugar_jar := station.get_node_or_null("SugarJar") as TextureButton
	var ice_button := station.get_node_or_null("IceButton") as TextureButton
	_create_preview_texture(dispenser, BASIC_MACHINE_PREVIEW_NAME, BASIC_MACHINE_TEXTURE_PATH, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	_create_preview_texture(cup_stack, CUP_STACK_PREVIEW_NAME, FULL_CUP_STACK_TEXTURE_PATH, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	_create_preview_texture(sugar_jar, SUGAR_JAR_PREVIEW_NAME, SUGAR_JAR_TEXTURE_PATH, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	_create_preview_texture(ice_button, ICE_TRAY_PREVIEW_NAME, ICE_TRAY_TEXTURE_PATH, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	_sync_editor_preview_geometry()


func _create_preview_texture(target: Control, preview_name: StringName, texture_path: String, stretch_mode: int) -> void:
	if target == null or target.get_parent() == null:
		return
	var preview := target.get_parent().get_node_or_null(NodePath(str(preview_name))) as TextureRect
	if preview == null:
		preview = TextureRect.new()
		preview.name = preview_name
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		target.get_parent().add_child(preview, false, Node.INTERNAL_MODE_BACK)
	preview.texture = load(texture_path) as Texture2D
	preview.stretch_mode = stretch_mode


func _sync_editor_preview_geometry() -> void:
	if not Engine.is_editor_hint():
		return
	var station := get_parent() as Control
	if station == null:
		return
	_sync_preview_node(station.get_node_or_null("MachineAssembly/SoyMilkDispenser") as Control, BASIC_MACHINE_PREVIEW_NAME)
	_sync_preview_node(station.get_node_or_null("CupStack") as Control, CUP_STACK_PREVIEW_NAME)
	_sync_preview_node(station.get_node_or_null("SugarJar") as Control, SUGAR_JAR_PREVIEW_NAME)
	_sync_preview_node(station.get_node_or_null("IceButton") as Control, ICE_TRAY_PREVIEW_NAME)


func _sync_preview_node(target: Control, preview_name: StringName) -> void:
	if target == null or target.get_parent() == null:
		return
	var preview := target.get_parent().get_node_or_null(NodePath(str(preview_name))) as TextureRect
	if preview == null:
		return
	preview.position = target.position
	preview.size = target.size
	preview.z_index = target.z_index
	preview.visible = target.visible
	preview.self_modulate = target.self_modulate
