@tool
extends Node

# Preview nodes are internal, ownerless editor objects. They can display the
# lazy-loaded runtime artwork without being serialized into the scene.
const MACHINE_PREVIEW_NAME := &"EditorPreviewMachine"
const CUP_STACK_PREVIEW_NAME := &"EditorPreviewCupStack"
const SUGAR_JAR_PREVIEW_NAME := &"EditorPreviewSugarJar"
const LEFT_CUP_PREVIEW_NAME := &"EditorPreviewLeftCup"
const RIGHT_CUP_PREVIEW_NAME := &"EditorPreviewRightCup"
const LEFT_NOZZLE_GUIDE_NAME := &"EditorPreviewLeftNozzleGuide"
const RIGHT_NOZZLE_GUIDE_NAME := &"EditorPreviewRightNozzleGuide"

var _applied_tier := -1


func _ready() -> void:
	var editor_preview_enabled := Engine.is_editor_hint()
	set_process(editor_preview_enabled)
	if not editor_preview_enabled:
		return
	call_deferred("_apply_editor_preview")


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if _preview_tier() != _applied_tier:
		_apply_editor_preview()
	_sync_editor_preview_geometry()


func _apply_editor_preview() -> void:
	if not Engine.is_editor_hint():
		return
	var station := get_parent() as Control
	if station == null:
		return
	var constants := _station_constants(station)
	var machine_layouts := Array(constants.get("MACHINE_TIER_LAYOUTS", []))
	var cup_stack_paths := Array(constants.get("CUP_STACK_TEXTURE_PATHS", []))
	if machine_layouts.is_empty() or cup_stack_paths.is_empty():
		return
	var tier := _preview_tier()
	var machine_layout := Dictionary(machine_layouts[clampi(tier, 0, machine_layouts.size() - 1)])
	var dispenser := station.get_node_or_null("MachineAssembly/SoyMilkDispenser") as TextureRect
	var cup_stack := station.get_node_or_null("CupStack") as TextureButton
	var sugar_jar := station.get_node_or_null("SugarJar") as TextureButton
	_create_preview_texture_from_path(dispenser, MACHINE_PREVIEW_NAME, str(machine_layout.get("texture_path", "")), TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	_create_preview_texture_from_path(cup_stack, CUP_STACK_PREVIEW_NAME, str(cup_stack_paths.back()), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	_create_preview_texture_from_path(sugar_jar, SUGAR_JAR_PREVIEW_NAME, str(constants.get("SUGAR_JAR_TEXTURE_PATH", "")), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	var cup_source_texture := load(str(cup_stack_paths.front())) as Texture2D
	var outlet_region: Rect2 = constants.get("OUTLET_CUP_REGION", Rect2())
	if cup_source_texture != null and outlet_region.has_area():
		var outlet_texture := AtlasTexture.new()
		outlet_texture.atlas = cup_source_texture
		outlet_texture.region = outlet_region
		var machine_assembly := station.get_node_or_null("MachineAssembly") as Control
		_create_preview_texture(machine_assembly, LEFT_CUP_PREVIEW_NAME, outlet_texture, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
		_create_preview_texture(machine_assembly, RIGHT_CUP_PREVIEW_NAME, outlet_texture, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
		_create_nozzle_guide(machine_assembly, LEFT_NOZZLE_GUIDE_NAME, "左出浆口")
		_create_nozzle_guide(machine_assembly, RIGHT_NOZZLE_GUIDE_NAME, "右出浆口")
	_applied_tier = tier
	_sync_editor_preview_geometry()


func _create_preview_texture_from_path(target: Control, preview_name: StringName, texture_path: String, stretch_mode: int) -> void:
	if target == null or texture_path.is_empty():
		return
	_create_preview_texture(target.get_parent() as Control, preview_name, load(texture_path) as Texture2D, stretch_mode)


func _create_preview_texture(parent: Control, preview_name: StringName, texture: Texture2D, stretch_mode: int) -> void:
	if parent == null or texture == null:
		return
	var preview := parent.get_node_or_null(NodePath(str(preview_name))) as TextureRect
	if preview == null:
		preview = TextureRect.new()
		preview.name = preview_name
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		parent.add_child(preview, false, Node.INTERNAL_MODE_BACK)
	preview.texture = texture
	preview.stretch_mode = stretch_mode


func _create_nozzle_guide(parent: Control, guide_name: StringName, text: String) -> void:
	if parent == null:
		return
	var guide := parent.get_node_or_null(NodePath(str(guide_name))) as Label
	if guide == null:
		guide = Label.new()
		guide.name = guide_name
		guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
		guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		guide.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		guide.add_theme_color_override("font_color", Color(1.0, 0.86, 0.34, 0.96))
		guide.add_theme_color_override("font_outline_color", Color(0.18, 0.08, 0.01, 0.95))
		guide.add_theme_constant_override("outline_size", 4)
		guide.add_theme_font_size_override("font_size", 13)
		parent.add_child(guide, false, Node.INTERNAL_MODE_FRONT)
	guide.text = text


func _sync_editor_preview_geometry() -> void:
	if not Engine.is_editor_hint():
		return
	var station := get_parent() as Control
	if station == null:
		return
	_sync_preview_node(station.get_node_or_null("MachineAssembly/SoyMilkDispenser") as Control, MACHINE_PREVIEW_NAME)
	_sync_preview_node(station.get_node_or_null("CupStack") as Control, CUP_STACK_PREVIEW_NAME)
	_sync_preview_node(station.get_node_or_null("SugarJar") as Control, SUGAR_JAR_PREVIEW_NAME)
	var machine_assembly := station.get_node_or_null("MachineAssembly") as Control
	var machine_preview := machine_assembly.get_node_or_null(NodePath(str(MACHINE_PREVIEW_NAME))) as TextureRect if machine_assembly != null else null
	var cup_stack_target := station.get_node_or_null("CupStack") as Control
	var left_cup_preview := machine_assembly.get_node_or_null(NodePath(str(LEFT_CUP_PREVIEW_NAME))) as TextureRect if machine_assembly != null else null
	var right_cup_preview := machine_assembly.get_node_or_null(NodePath(str(RIGHT_CUP_PREVIEW_NAME))) as TextureRect if machine_assembly != null else null
	if machine_preview == null or machine_preview.texture == null or cup_stack_target == null or left_cup_preview == null or left_cup_preview.texture == null or right_cup_preview == null:
		return
	var machine_rect := _preview_machine_rect(station)
	machine_preview.position = machine_rect.position
	machine_preview.size = machine_rect.size
	var layout := _preview_tier_layout(station)
	var left_outlet := _texture_position_to_machine(machine_preview, Vector2(layout.get("left_nozzle_texture_position", Vector2.ZERO)))
	var right_outlet := _texture_position_to_machine(machine_preview, Vector2(layout.get("right_nozzle_texture_position", Vector2.ZERO)))
	var outlet_atlas := left_cup_preview.texture as AtlasTexture
	if outlet_atlas == null or outlet_atlas.atlas == null:
		return
	var cup_source_size := outlet_atlas.atlas.get_size()
	var outlet_texture_size := left_cup_preview.texture.get_size()
	var stack_scale := minf(cup_stack_target.size.x / cup_source_size.x, cup_stack_target.size.y / cup_source_size.y)
	var cup_size := outlet_texture_size * stack_scale
	left_cup_preview.position = Vector2(left_outlet.x - cup_size.x * 0.5, left_outlet.y) + _preview_left_cup_offset(station)
	left_cup_preview.size = cup_size
	left_cup_preview.z_index = 1
	left_cup_preview.self_modulate = Color(1.0, 1.0, 1.0, 0.78)
	left_cup_preview.visible = true
	var advanced := _preview_tier() >= 2
	right_cup_preview.position = Vector2(right_outlet.x - cup_size.x * 0.5, right_outlet.y) + _preview_right_cup_offset(station)
	right_cup_preview.size = cup_size
	right_cup_preview.z_index = 1
	right_cup_preview.self_modulate = Color(1.0, 1.0, 1.0, 0.78)
	right_cup_preview.visible = advanced
	var nozzle_size := Vector2(88.0, 92.0) if advanced else Vector2(112.0, 100.0)
	_sync_nozzle_guide(machine_assembly, LEFT_NOZZLE_GUIDE_NAME, left_outlet, nozzle_size, true)
	_sync_nozzle_guide(machine_assembly, RIGHT_NOZZLE_GUIDE_NAME, right_outlet, nozzle_size, advanced)


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


func _sync_nozzle_guide(parent: Control, guide_name: StringName, outlet: Vector2, guide_size: Vector2, visible: bool) -> void:
	if parent == null:
		return
	var guide := parent.get_node_or_null(NodePath(str(guide_name))) as Label
	if guide == null:
		return
	guide.size = guide_size
	guide.position = Vector2(
		clampf(outlet.x - guide_size.x * 0.5, 0.0, parent.size.x - guide_size.x),
		clampf(outlet.y - guide_size.y, 0.0, parent.size.y - guide_size.y)
	)
	guide.z_index = 20
	guide.visible = visible


func _preview_tier() -> int:
	var station := get_parent()
	return clampi(int(station.get("editor_preview_tier")) if station != null else 0, 0, 2)


func _preview_tier_layout(station: Control) -> Dictionary:
	var constants := _station_constants(station)
	var machine_layouts := Array(constants.get("MACHINE_TIER_LAYOUTS", []))
	if machine_layouts.is_empty():
		return {}
	var tier := clampi(_preview_tier(), 0, machine_layouts.size() - 1)
	var layout := Dictionary(machine_layouts[tier]).duplicate()
	match tier:
		0:
			layout["left_nozzle_texture_position"] = Vector2(station.get("basic_left_nozzle_texture_position"))
			layout["right_nozzle_texture_position"] = Vector2.ZERO
		1:
			layout["left_nozzle_texture_position"] = Vector2(station.get("intermediate_left_nozzle_texture_position"))
			layout["right_nozzle_texture_position"] = Vector2.ZERO
		2:
			layout["left_nozzle_texture_position"] = Vector2(station.get("advanced_left_nozzle_texture_position"))
			layout["right_nozzle_texture_position"] = Vector2(station.get("advanced_right_nozzle_texture_position"))
	return layout


func _preview_machine_rect(station: Control) -> Rect2:
	match _preview_tier():
		0: return Rect2(station.get("basic_machine_rect"))
		1: return Rect2(station.get("intermediate_machine_rect"))
		2: return Rect2(station.get("advanced_machine_rect"))
	return Rect2(station.get("basic_machine_rect"))


func _preview_left_cup_offset(station: Control) -> Vector2:
	match _preview_tier():
		0: return Vector2(station.get("basic_left_cup_offset"))
		1: return Vector2(station.get("intermediate_left_cup_offset"))
		2: return Vector2(station.get("advanced_left_cup_offset"))
	return Vector2(station.get("basic_left_cup_offset"))


func _preview_right_cup_offset(station: Control) -> Vector2:
	return Vector2(station.get("advanced_right_cup_offset")) if _preview_tier() >= 2 else _preview_left_cup_offset(station)


func _texture_position_to_machine(machine_preview: TextureRect, texture_position: Vector2) -> Vector2:
	var texture_size := machine_preview.texture.get_size()
	var scale := maxf(machine_preview.size.x / texture_size.x, machine_preview.size.y / texture_size.y)
	var drawn_size := texture_size * scale
	var crop_offset := (machine_preview.size - drawn_size) * 0.5
	return machine_preview.position + crop_offset + texture_position * scale


static func _station_constants(station: Control) -> Dictionary:
	var station_script := station.get_script() as Script
	return station_script.get_script_constant_map() if station_script != null else {}
