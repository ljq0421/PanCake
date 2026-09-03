@tool
class_name UpgradeWorkshopOverlay
extends Control

signal begin_next_day_requested
signal closed
const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const UNAVAILABLE_TAG_OPACITY := 0.42
const PRESS_SPREADER_PROP_PATH := NodePath("UpgradeProps/WorkshopProp_growth_automation_pancake_press_once")
const RUNTIME_PRESS_VISUAL_PATH := NodePath("JianbingStallArtwork/PancakeWorktopHotspots/SpreaderSource/PressVisual")
const EDITOR_PRESS_VISUAL_PATH := NodePath("SyncedWorkstationPreview/SafeArea/JianbingStallArtwork/PancakeWorktopHotspots/SpreaderSource/PressVisual")
const EDITOR_PANCAKE_WORKTOP_PATH := NodePath("SafeArea/JianbingStallArtwork/PancakeWorktopHotspots")
const EDITOR_YOUTIAO_STATION_PATH := NodePath("SafeArea/FiveAreaInfrastructure/Stations/CartoonYoutiaoFryer")
const EDITOR_YOUTIAO_VISUAL_PATH := NodePath("FryerAssembly/FryerVisual")
const EDITOR_YOUTIAO_TRAY_PATH := NodePath("SharedTray")
const EDITOR_SOY_STATION_PATH := NodePath("SafeArea/FiveAreaInfrastructure/Stations/FreshSoyMilkStation")
const EDITOR_SOY_DISPENSER_PATH := NodePath("MachineAssembly/SoyMilkDispenser")
const EDITOR_SOY_CUP_STACK_PATH := NodePath("CupStack")
const EDITOR_SOY_SUGAR_JAR_PATH := NodePath("SugarJar")
const EDITOR_HOLDING_TRAY_PATH := NodePath("SafeArea/FiveAreaInfrastructure/Stations/PancakeHoldingTray")
const EDITOR_PACKAGED_DRINK_STATION_PATH := NodePath("SafeArea/FiveAreaInfrastructure/Stations/PackagedDrinkStation")
const EDITOR_PREVIEW_LOCKED_MODULATE := Color(1.0, 1.0, 1.0, 0.42)
const EDITOR_YOUTIAO_TEXTURE_PATHS = [
	"res://resources/art/workstation/machines/youtiao_fryer/youtiao-fryer-cartoon-empty-drain-lowered.png",
	"res://resources/art/workstation/machines/youtiao_fryer/advanced/youtiao-fryer-cartoon-advanced-empty-drain-lowered.png",
	"res://resources/art/workstation/machines/youtiao_fryer/youtiao_chicken_dual_fryer_v2.png",
]
const EDITOR_SOY_TEXTURE_PATHS = [
	"res://resources/art/workstation/machines/soy_milk/soy-milk-dispenser.png",
	"res://resources/art/workstation/machines/soy_milk/automatic-soy-milk-dispenser-transparent.png",
	"res://resources/art/workstation/machines/soy_milk/automatic-soy-milk-dispenser-two-outlets-transparent.png",
]
const EDITOR_SOY_CUP_STACK_TEXTURE_PATH := "res://resources/art/products/soy_milk/soy_milk_plastic_cup_stack_8_v3_bold_cartoon_transparent.png"
const EDITOR_SOY_SUGAR_JAR_TEXTURE_PATH := "res://resources/art/workstation/containers/p1/container-s-sugar-p1-v2-transparent.png"

enum EditorPreviewPreset {
	INITIAL_UNLOCKS,
	YOUTIAO_STAGE,
	SOY_STAGE,
	ALL_CONTENT,
}
const EDITOR_PANCAKE_CONTAINER_PATHS: Array[NodePath] = [
	NodePath("EggCarton"),
	NodePath("BaocuiBasket"),
	NodePath("ScallionTray"),
	NodePath("CorianderTray"),
	NodePath("HamSource"),
	NodePath("PorkFlossSource"),
	NodePath("SecretSauceSource"),
	NodePath("BatterLadleSource"),
]
const EDITOR_FULL_CONTAINER_VISUAL_PATHS: Array[NodePath] = [
	NodePath("ScallionTray/Visual"),
	NodePath("CorianderTray/Visual"),
	NodePath("HamSource/Visual"),
	NodePath("PorkFlossSource/Visual"),
]
const EDITOR_PREVIEW_HIDDEN_PATHS: Array[NodePath] = [
	NodePath("SafeArea/ServiceCustomer1"),
	NodePath("SafeArea/ServiceCustomer2"),
	NodePath("SafeArea/ServiceCustomer3"),
	NodePath("SafeArea/CustomerStrip"),
	NodePath("SafeArea/CustomerPortrait"),
	NodePath("SafeArea/BottomStrip"),
	NodePath("SafeArea/BusinessDayTimerLabel"),
	NodePath("SafeArea/GlobalStatusLabel"),
	NodePath("SafeArea/PaymentSprite"),
	NodePath("SafeArea/PaymentCoinLayer"),
	NodePath("SafeArea/P1ControlBar"),
	NodePath("SafeArea/IngredientRack"),
	NodePath("SafeArea/RestockRack"),
	NodePath("SafeArea/LeftRack"),
	NodePath("SafeArea/RightRack"),
	NodePath("SafeArea/SurfaceReadoutLabel"),
	NodePath("SafeArea/IngredientDragPreview"),
]
@onready var _detail := %DetailText as RichTextLabel
@onready var _queue := %QueueLabel as Label
@onready var _buy := %BuyButton as Button
@onready var _hint := %HoverHint as PanelContainer
@onready var _hint_label := %HintLabel as Label
@onready var _detail_panel := %DetailPanel as Panel
@onready var _press_preview := %PressSpreaderPreview as TextureRect
@onready var _juice_tray_preview := %FilledOrangeJuiceTrayPreview as TextureRect
@onready var _pancake_holding_tray_preview := %PancakeHoldingTrayPreview as TextureRect
@onready var _editor_preview := %EditorPreview as Control
@export_group("编辑器工坊预览")
@export_enum("初始：锁定内容", "油条：第一档已解锁", "豆浆：第一档已解锁", "全部内容：布局校准") var editor_preview_preset: int = EditorPreviewPreset.INITIAL_UNLOCKS
var _selected_id: StringName = &""

var _anchors: Dictionary = {}
var _tag_layouts: Dictionary = {}
var _editor_texture_cache: Dictionary = {}


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	var material_previews := get_node_or_null("EditorMaterialPreviews") as CanvasItem
	if material_previews != null:
		material_previews.visible = false
	# The formal workstation is authored as an external scene instance so Godot
	# keeps the editor preview synchronized automatically. Remove it before its
	# runtime callbacks can enter the tree; the real workstation behind this
	# overlay is the only gameplay instance that should run.
	var synced_preview := get_node_or_null("EditorPreview/SyncedWorkstationPreview")
	if synced_preview != null:
		var preview_parent := synced_preview.get_parent()
		if preview_parent != null:
			preview_parent.remove_child(synced_preview)
		synced_preview.free()

func _ready() -> void:
	if Engine.is_editor_hint():
		# The scene editor can restore properties from the nested workstation after
		# this tool script's _ready() has run. Keep editor processing enabled so the
		# catalogue artwork remains synchronized instead of disappearing again.
		set_process(true)
		_editor_preview.visible = true
		var material_previews := get_node_or_null("EditorMaterialPreviews") as CanvasItem
		if material_previews != null:
			# The old, hand-placed guides are retained only as scene-authoring
			# references. The synchronized workstation below is now the visual
			# authority for editor positioning, matching the runtime composition.
			material_previews.visible = false
		_configure_editor_workstation_preview()
		call_deferred("_sync_press_spreader_layout")
		return
	_editor_preview.visible = false
	_hide_inactive_growth_props()
	_buy.pressed.connect(_on_buy)
	%NextDayButton.pressed.connect(func() -> void: begin_next_day_requested.emit())
	%BackButton.pressed.connect(func() -> void: closed.emit())
	for growth_id in CATALOG.GROWTH_DISPLAY_ORDER:
		var prop := get_node_or_null(NodePath("UpgradeProps/WorkshopProp_" + str(growth_id).replace(".", "_"))) as Button
		if prop == null:
			push_error("Upgrade workshop scene is missing its prop node: %s" % growth_id)
			continue
		if growth_id == &"growth.area.packaged_drink":
			prop.pressed.connect(_on_packaged_drink_tag_pressed)
		else:
			prop.pressed.connect(_select.bind(growth_id))
		prop.focus_mode = Control.FOCUS_ALL
		prop.mouse_entered.connect(_show_hint.bind(growth_id, prop))
		prop.mouse_exited.connect(func() -> void: _hint.visible = false)
		prop.focus_entered.connect(_show_hint.bind(growth_id, prop))
		prop.focus_exited.connect(func() -> void: _hint.visible = false)
		var condition_tag := prop.get_node_or_null("ConditionTag") as Label
		if condition_tag != null:
			condition_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			condition_tag.add_theme_font_size_override("font_size", 16)
			condition_tag.add_theme_constant_override("outline_size", 2)
		_anchors[growth_id] = prop
		_tag_layouts[growth_id] = {"position": prop.position, "size": prop.size}
	refresh()
	call_deferred("_focus_first_available_prop")


func _hide_inactive_growth_props() -> void:
	var active_names := {}
	for growth_id in CATALOG.GROWTH_DISPLAY_ORDER:
		active_names["WorkshopProp_" + str(growth_id).replace(".", "_")] = true
	var props := get_node_or_null("UpgradeProps")
	if props == null:
		return
	for child in props.get_children():
		if child is Button and not active_names.has(child.name):
			(child as Button).visible = false
			(child as Button).disabled = true
			(child as Button).mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_configure_editor_workstation_preview()
	_sync_press_spreader_layout()


func _configure_editor_workstation_preview() -> void:
	if not Engine.is_editor_hint() or _editor_preview == null:
		return
	var synced_preview := _editor_preview.get_node_or_null("SyncedWorkstationPreview") as Control
	if synced_preview == null:
		push_error("Workshop editor preview is missing its formal workstation instance")
		return
	for scene_path in EDITOR_PREVIEW_HIDDEN_PATHS:
		var preview_node := synced_preview.get_node_or_null(scene_path) as CanvasItem
		if preview_node != null:
			preview_node.visible = false
	_configure_editor_pancake_preview(synced_preview, _editor_preview_has_pancake_unlocks())
	_configure_editor_equipment_preview(synced_preview)
	_configure_editor_upgrade_tags()


func _configure_editor_pancake_preview(synced_preview: Control, unlocked: bool) -> void:
	# The pancake worktop normally fills and reveals these containers from the
	# live GameSession. That gameplay script is intentionally not a @tool script,
	# so an editor-only workshop instance would otherwise show empty or missing
	# artwork behind its independently authored upgrade tags.
	var worktop := synced_preview.get_node_or_null(EDITOR_PANCAKE_WORKTOP_PATH) as Control
	if worktop == null:
		push_error("Workshop editor preview is missing the pancake worktop")
		return
	worktop.visible = true
	for container_path in EDITOR_PANCAKE_CONTAINER_PATHS:
		var container := worktop.get_node_or_null(container_path) as CanvasItem
		if container != null:
			container.visible = true
			container.modulate = Color.WHITE if unlocked else EDITOR_PREVIEW_LOCKED_MODULATE
	_set_editor_preview_texture_from_last_export(
		worktop,
		NodePath("EggCarton/Visual"),
		worktop,
		&"egg_content_textures"
	)
	_set_editor_preview_texture_from_last_export(
		worktop,
		NodePath("BaocuiBasket/Visual"),
		worktop,
		&"baocui_tray_textures"
	)
	for visual_path in EDITOR_FULL_CONTAINER_VISUAL_PATHS:
		var visual := worktop.get_node_or_null(visual_path) as TextureRect
		_set_editor_preview_texture_from_last_export(worktop, visual_path, visual, &"state_textures")


func _configure_editor_equipment_preview(synced_preview: Control) -> void:
	var youtiao_unlocked := editor_preview_preset >= EditorPreviewPreset.YOUTIAO_STAGE
	var soy_unlocked := editor_preview_preset >= EditorPreviewPreset.SOY_STAGE
	var all_content_unlocked := editor_preview_preset == EditorPreviewPreset.ALL_CONTENT
	var youtiao_tier := 2 if all_content_unlocked else 0
	var soy_tier := 2 if all_content_unlocked else 0
	var youtiao := synced_preview.get_node_or_null(EDITOR_YOUTIAO_STATION_PATH) as Control
	if youtiao != null:
		youtiao.visible = true
		youtiao.modulate = Color.WHITE if youtiao_unlocked else EDITOR_PREVIEW_LOCKED_MODULATE
		youtiao.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fryer_visual := youtiao.get_node_or_null(EDITOR_YOUTIAO_VISUAL_PATH) as TextureRect
		if fryer_visual != null:
			fryer_visual.texture = _editor_texture(EDITOR_YOUTIAO_TEXTURE_PATHS[youtiao_tier])
			fryer_visual.visible = true
		var youtiao_tray := youtiao.get_node_or_null(EDITOR_YOUTIAO_TRAY_PATH) as CanvasItem
		if youtiao_tray != null:
			youtiao_tray.visible = true
			youtiao_tray.modulate = Color.WHITE if youtiao_unlocked else EDITOR_PREVIEW_LOCKED_MODULATE
	var soy := synced_preview.get_node_or_null(EDITOR_SOY_STATION_PATH) as Control
	if soy != null:
		soy.visible = true
		soy.modulate = Color.WHITE if soy_unlocked else EDITOR_PREVIEW_LOCKED_MODULATE
		soy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dispenser := soy.get_node_or_null(EDITOR_SOY_DISPENSER_PATH) as TextureRect
		if dispenser != null:
			dispenser.texture = _editor_texture(EDITOR_SOY_TEXTURE_PATHS[soy_tier])
			dispenser.visible = true
		var cup_stack := soy.get_node_or_null(EDITOR_SOY_CUP_STACK_PATH) as TextureButton
		if cup_stack != null:
			cup_stack.texture_normal = _editor_texture(EDITOR_SOY_CUP_STACK_TEXTURE_PATH)
			cup_stack.visible = true
		var sugar_jar := soy.get_node_or_null(EDITOR_SOY_SUGAR_JAR_PATH) as TextureButton
		if sugar_jar != null:
			sugar_jar.texture_normal = _editor_texture(EDITOR_SOY_SUGAR_JAR_TEXTURE_PATH)
			sugar_jar.visible = soy_unlocked
	var holding_tray := synced_preview.get_node_or_null(EDITOR_HOLDING_TRAY_PATH) as CanvasItem
	if holding_tray != null:
		holding_tray.visible = false
	var packaged_drink_station := synced_preview.get_node_or_null(EDITOR_PACKAGED_DRINK_STATION_PATH) as CanvasItem
	if packaged_drink_station != null:
		packaged_drink_station.visible = false
	_press_preview.visible = true
	_press_preview.self_modulate = Color.WHITE if _editor_preview_has_pancake_unlocks() else EDITOR_PREVIEW_LOCKED_MODULATE
	_pancake_holding_tray_preview.visible = true
	_pancake_holding_tray_preview.self_modulate = Color.WHITE if all_content_unlocked else EDITOR_PREVIEW_LOCKED_MODULATE
	_juice_tray_preview.visible = true
	_juice_tray_preview.self_modulate = Color.WHITE if all_content_unlocked else EDITOR_PREVIEW_LOCKED_MODULATE


func _configure_editor_upgrade_tags() -> void:
	var visible_growth_ids := _editor_preview_visible_growth_ids()
	for raw_growth_id in CATALOG.GROWTH_DISPLAY_ORDER:
		var growth_id := StringName(raw_growth_id)
		var prop := get_node_or_null(NodePath("UpgradeProps/WorkshopProp_" + str(growth_id).replace(".", "_"))) as Button
		if prop == null:
			continue
		prop.visible = visible_growth_ids.has(growth_id)
		prop.modulate = Color.WHITE if editor_preview_preset != EditorPreviewPreset.INITIAL_UNLOCKS else EDITOR_PREVIEW_LOCKED_MODULATE
		var condition_tag := prop.get_node_or_null("ConditionTag") as Label
		if condition_tag != null:
			condition_tag.text = "%d 金币" % int(CATALOG.growth_definition(growth_id).get("price", 0))
	var preset_label: String = ["初始锁定内容", "油条第一档", "豆浆第一档", "全部内容校准"][clampi(editor_preview_preset, 0, 3)]
	_queue.text = "升级工坊 · 编辑器预览：%s" % preset_label


func _editor_preview_has_pancake_unlocks() -> bool:
	return editor_preview_preset >= EditorPreviewPreset.YOUTIAO_STAGE


func _editor_preview_visible_growth_ids() -> Array[StringName]:
	match editor_preview_preset:
		EditorPreviewPreset.INITIAL_UNLOCKS:
			return [
				&"growth.add_on.pancake.egg", &"growth.add_on.pancake.baocui", &"growth.add_on.pancake.scallion",
				&"growth.automation.pancake.auto_batter_ladle", &"growth.add_on.pancake.meat_floss",
				&"growth.add_on.pancake.ham_sausage", &"growth.add_on.pancake.coriander",
				&"growth.automation.pancake.press_once", &"growth.automation.pancake.non_burning_griddle",
				&"growth.capacity.pancake_holding_tray.first_slot", &"growth.area.youtiao",
				&"growth.area.fresh_soy_milk", &"growth.area.packaged_drink",
			]
		EditorPreviewPreset.YOUTIAO_STAGE:
			return [
				&"growth.capacity.youtiao_finished_tray", &"growth.equipment.youtiao.advanced",
				&"growth.capacity.chicken_finished_tray", &"growth.area.fresh_soy_milk",
				&"growth.area.packaged_drink",
			]
		EditorPreviewPreset.SOY_STAGE:
			return [
				&"growth.equipment.youtiao.advanced", &"growth.equipment.youtiao.dual_basket",
				&"growth.capacity.chicken_finished_tray", &"growth.assist.fresh_soy_milk.sugar",
				&"growth.automation.fresh_soy_milk.auto_fill", &"growth.area.packaged_drink",
			]
		_:
			return CATALOG.GROWTH_DISPLAY_ORDER.duplicate()


func _editor_texture(path: String) -> Texture2D:
	if _editor_texture_cache.has(path):
		return _editor_texture_cache[path] as Texture2D
	var texture := load(path) as Texture2D
	_editor_texture_cache[path] = texture
	return texture


func _set_editor_preview_texture_from_last_export(
	root: Node,
	visual_path: NodePath,
	texture_source: Object,
	property_name: StringName
) -> void:
	var visual := root.get_node_or_null(visual_path) as TextureRect
	if visual == null or texture_source == null:
		return
	var exported_textures: Variant = texture_source.get(property_name)
	if not exported_textures is Array or Array(exported_textures).is_empty():
		return
	var preview_texture := Array(exported_textures).back() as Texture2D
	if preview_texture == null:
		return
	visual.texture = preview_texture
	visual.visible = true
	visual.self_modulate = Color.WHITE

func refresh() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null: return
	var overview: Array = session.call("growth_overview")
	var progression := Dictionary(session.call("five_area_progression_snapshot"))
	var owned_growth_ids := Array(progression.get("owned_growth_ids", []))
	var packaged_drinks_unlocked := _contains_id(Array(progression.get("unlocked_area_ids", [])), &"area.packaged_drink")
	var youtiao_upgrade_id := _next_youtiao_fryer_upgrade(owned_growth_ids)
	var soy_milk_machine_upgrade_id := _next_soy_milk_machine_upgrade(owned_growth_ids)
	var press_spreader_owned := owned_growth_ids.has("growth.automation.pancake.press_once")
	var pancake_holding_tray_owned := owned_growth_ids.has("growth.capacity.pancake_holding_tray.first_slot")
	_press_preview.visible = not CATALOG.CARTOON_BREAKFAST_V1
	_press_preview.self_modulate = Color(1.0, 1.0, 1.0, 1.0 if press_spreader_owned else 0.42)
	# The live workstation behind the overlay already shows the installed tray.
	# Keep this ghosted prop only while the tray is still available to purchase,
	# otherwise the two copies appear offset from one another in the workshop.
	_pancake_holding_tray_preview.visible = not CATALOG.CARTOON_BREAKFAST_V1 and not pancake_holding_tray_owned
	_pancake_holding_tray_preview.self_modulate = Color(1.0, 1.0, 1.0, 0.42)
	# A future drink rack is still readable in the workshop, but remains clearly
	# a preview until the area is active on the next business day.
	_juice_tray_preview.self_modulate = Color(1.0, 1.0, 1.0, 1.0 if packaged_drinks_unlocked else 0.42)
	var queued_labels := PackedStringArray()
	for raw_id in Array(Dictionary(session.call("five_area_progression_snapshot")).get("pending_growth_ids", [])):
		queued_labels.append(str(CATALOG.growth_definition(StringName(raw_id)).get("label", raw_id)))
	_queue.text = "升级工坊 · 待生效：%s" % ("、".join(queued_labels) if not queued_labels.is_empty() else "无")
	var selected_prop_is_visible := false
	for raw_status in overview:
		var status := Dictionary(raw_status)
		var growth_id := StringName(status.get("growth_id", &""))
		var prop := _anchors.get(growth_id) as Button
		if prop == null: continue
		# These physical props are visible in the workshop preview before their
		# prerequisites are installed. Keep a concise reservation tag on them, but
		# remove the tag once the upgrade has been installed: the artwork itself is
		# then the completed-state feedback.
		var show_prerequisite_locked_visual := growth_id in [
			&"growth.capacity.youtiao_finished_tray",
			&"growth.add_on.pancake.egg",
			&"growth.add_on.pancake.baocui",
			&"growth.add_on.pancake.scallion",
			&"growth.add_on.pancake.meat_floss",
			&"growth.add_on.pancake.ham_sausage",
			&"growth.add_on.pancake.coriander",
			&"growth.automation.pancake.non_burning_griddle",
		]
		var is_youtiao_machine_upgrade := growth_id in [&"growth.area.youtiao", &"growth.equipment.youtiao.advanced", &"growth.equipment.youtiao.dual_basket"]
		var is_soy_milk_machine_upgrade := growth_id in [&"growth.area.fresh_soy_milk", &"growth.automation.fresh_soy_milk.auto_fill", &"growth.automation.fresh_soy_milk.advanced"]
		# The basic fryer is also a discoverable physical workshop preview before
		# every pancake prerequisite has been installed.
		var show_locked_youtiao_machine_tag := growth_id == &"growth.area.youtiao" and growth_id == youtiao_upgrade_id
		# The basic soy machine is a physical workshop preview even before all of
		# its pancake prerequisites are met.  Keep its unavailable tag visible so
		# players can discover the next area and inspect its requirements.
		var show_locked_soy_machine_tag := growth_id == &"growth.area.fresh_soy_milk" and growth_id == soy_milk_machine_upgrade_id
		prop.visible = not bool(status.get("already_owned", false)) \
			and (_has_owned_growth_prerequisites(growth_id, owned_growth_ids) or show_prerequisite_locked_visual or show_locked_youtiao_machine_tag or show_locked_soy_machine_tag) \
			and (not is_youtiao_machine_upgrade or growth_id == youtiao_upgrade_id) \
			and (not is_soy_milk_machine_upgrade or growth_id == soy_milk_machine_upgrade_id)
		if growth_id == &"growth.area.packaged_drink":
			# This label is both the condition readout and the reservation button.
			# Once the rack is active, neither the locked tag nor its preview action
			# should remain over the completed workstation.
			prop.visible = not packaged_drinks_unlocked
		if growth_id == _selected_id:
			selected_prop_is_visible = prop.visible
		prop.tooltip_text = _tag_tooltip_text(growth_id, status)
		var condition_tag := prop.get_node_or_null("ConditionTag") as Label
		if condition_tag != null:
			condition_tag.text = _tag_text(growth_id, status)
			_fit_tag_to_content(growth_id, prop, condition_tag)
		_apply_upgrade_tag_style(prop, status)
		# Price is always visible on a reservation tag.  A solid tag means the
		# player can reserve it now; every unavailable state is a translucent
		# preview, while its exact missing conditions stay in the hover/detail UI.
		prop.modulate = Color.WHITE if bool(status.get("can_purchase", false)) else Color(1.0, 1.0, 1.0, UNAVAILABLE_TAG_OPACITY)
	if not _selected_id.is_empty() and selected_prop_is_visible:
		_show_detail(_selected_id)
	else:
		if not _selected_id.is_empty():
			_selected_id = &""
		_show_default_detail()
	_sync_press_spreader_layout()


func _sync_press_spreader_layout() -> void:
	var source := _preview_spreader_source()
	if source == null or _press_preview == null:
		return
	var source_rect := _rect_in_overlay_space(source.get_global_rect())
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		return
	_press_preview.position = source_rect.position
	_press_preview.size = source_rect.size
	var press_prop := get_node_or_null(PRESS_SPREADER_PROP_PATH) as Control
	if press_prop != null:
		press_prop.position = Vector2(
			source_rect.get_center().x - press_prop.size.x * 0.5,
			source_rect.end.y - press_prop.size.y
		)


func _preview_spreader_source() -> Control:
	if Engine.is_editor_hint():
		return _editor_preview.get_node_or_null(EDITOR_PRESS_VISUAL_PATH) as Control if _editor_preview != null else null
	var workstation_safe_area := get_parent()
	return workstation_safe_area.get_node_or_null(RUNTIME_PRESS_VISUAL_PATH) as Control if workstation_safe_area != null else null


func _rect_in_overlay_space(global_rect: Rect2) -> Rect2:
	var inverse_transform := get_global_transform_with_canvas().affine_inverse()
	var local_position := inverse_transform * global_rect.position
	var local_end := inverse_transform * global_rect.end
	return Rect2(local_position, local_end - local_position)


func _has_owned_growth_prerequisites(growth_id: StringName, owned_growth_ids: Array) -> bool:
	for raw_required_growth_id in Array(CATALOG.growth_definition(growth_id).get("requires_growth_ids", [])):
		if not owned_growth_ids.has(StringName(raw_required_growth_id)):
			return false
	return true


static func _contains_id(values: Array, expected: StringName) -> bool:
	return values.has(expected) or values.has(str(expected))


func _apply_upgrade_tag_style(prop: Button, status: Dictionary) -> void:
	# Every upgrade state is a labelled UI target rather than unframed text over
	# the workstation artwork. Colour distinguishes the actionable state at a
	# glance without changing the label copy.
	prop.flat = false
	var normal_background := Color(0.035, 0.12, 0.12, 0.97)
	var normal_border := Color(0.31, 0.53, 0.5, 0.98)
	var hover_background := Color(0.055, 0.19, 0.18, 0.99)
	var hover_border := Color(0.48, 0.76, 0.69, 1.0)
	if bool(status.get("already_owned", false)):
		normal_background = Color(0.045, 0.22, 0.2, 0.97)
		normal_border = Color(0.36, 0.78, 0.68, 1.0)
		hover_background = Color(0.065, 0.3, 0.27, 0.99)
		hover_border = Color(0.58, 0.94, 0.82, 1.0)
	elif bool(status.get("pending_activation", false)):
		normal_background = Color(0.31, 0.18, 0.045, 0.97)
		normal_border = Color(1.0, 0.72, 0.25, 1.0)
		hover_background = Color(0.4, 0.25, 0.065, 0.99)
		hover_border = Color(1.0, 0.88, 0.52, 1.0)
	elif bool(status.get("can_purchase", false)):
		normal_background = Color(0.055, 0.31, 0.24, 0.98)
		normal_border = Color(0.35, 0.9, 0.7, 1.0)
		hover_background = Color(0.08, 0.42, 0.32, 0.99)
		hover_border = Color(0.65, 1.0, 0.84, 1.0)
	if StringName(prop.get_meta("growth_id", &"")) == _selected_id:
		normal_border = Color(1.0, 0.79, 0.32, 1.0)
		hover_border = Color(1.0, 0.9, 0.6, 1.0)
	var normal := _upgrade_tag_box(normal_background, normal_border)
	var hover := _upgrade_tag_box(hover_background, hover_border)
	prop.add_theme_stylebox_override("normal", normal)
	prop.add_theme_stylebox_override("hover", hover)
	prop.add_theme_stylebox_override("pressed", hover)
	prop.add_theme_stylebox_override("focus", _upgrade_tag_focus_box())
	prop.add_theme_color_override("font_color", Color(1.0, 0.98, 0.84, 1.0))
	prop.add_theme_color_override("font_hover_color", Color.WHITE)
	prop.add_theme_color_override("font_focus_color", Color.WHITE)


func _upgrade_tag_box(background: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(2)
	box.corner_radius_top_left = 7
	box.corner_radius_top_right = 7
	box.corner_radius_bottom_right = 7
	box.corner_radius_bottom_left = 7
	box.shadow_color = Color(0.02, 0.08, 0.04, 0.55)
	box.shadow_size = 3
	box.shadow_offset = Vector2(0, 2)
	return box


func _upgrade_tag_focus_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	box.border_color = Color(1.0, 0.79, 0.32, 1.0)
	box.set_border_width_all(3)
	box.set_corner_radius_all(9)
	box.expand_margin_left = 3.0
	box.expand_margin_top = 3.0
	box.expand_margin_right = 3.0
	box.expand_margin_bottom = 3.0
	return box


func _next_youtiao_fryer_upgrade(owned_growth_ids: Array) -> StringName:
	if not owned_growth_ids.has("growth.area.youtiao"):
		return &"growth.area.youtiao"
	if not owned_growth_ids.has("growth.equipment.youtiao.advanced"):
		return &"growth.equipment.youtiao.advanced"
	if not owned_growth_ids.has("growth.equipment.youtiao.dual_basket"):
		return &"growth.equipment.youtiao.dual_basket"
	return &""


func _next_soy_milk_machine_upgrade(owned_growth_ids: Array) -> StringName:
	if not owned_growth_ids.has("growth.area.fresh_soy_milk"):
		return &"growth.area.fresh_soy_milk"
	if not owned_growth_ids.has("growth.automation.fresh_soy_milk.auto_fill"):
		return &"growth.automation.fresh_soy_milk.auto_fill"
	if not owned_growth_ids.has("growth.automation.fresh_soy_milk.advanced"):
		return &"growth.automation.fresh_soy_milk.advanced"
	return &""

func _select(growth_id: StringName) -> void:
	_selected_id = growth_id
	refresh()


func _on_packaged_drink_tag_pressed() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return
	var growth_id := &"growth.area.packaged_drink"
	var status := Dictionary(session.call("growth_purchase_status", growth_id))
	if bool(status.get("can_purchase", false)):
		session.call("purchase_growth", growth_id)
		refresh()
		return
	_select(growth_id)

func _show_detail(growth_id: StringName) -> void:
	var session := get_node_or_null("/root/GameSession")
	var status := Dictionary(session.call("growth_purchase_status", growth_id)) if session else {}
	var definition := CATALOG.growth_definition(growth_id)
	_detail.text = "[b]%s[/b]　[color=#72d9c0]%s[/color]　价格：[b]%d 金币[/b]\n%s" % [definition.get("label", "升级"), _state_text(status), int(status.get("price", 0)), _requirements_text(status)]
	_buy.disabled = not bool(status.get("can_purchase", false))
	_buy.text = "预订升级 · 次日生效" if not _buy.disabled else "当前不可预订"
	_detail_panel.visible = true


func _show_default_detail() -> void:
	_detail.text = "[b]选择一个升级[/b]　[color=#72d9c0]查看设备升级条件[/color]\n热点只显示当前状态；悬停可预览，点击后固定显示价格、前置条件和生效时间。"
	_buy.disabled = true
	_buy.text = "选择升级后可预订"
	_detail_panel.visible = true

func _show_hint(growth_id: StringName, prop: Control) -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null: return
	var status := Dictionary(session.call("growth_purchase_status", growth_id))
	_hint_label.text = _tag_tooltip_text(growth_id, status)
	var hint_size := Vector2(
		maxf(_hint.size.x, _hint.custom_minimum_size.x),
		maxf(_hint.size.y, _hint.custom_minimum_size.y)
	)
	var desired := prop.position + Vector2(0.0, prop.size.y + 10.0)
	if desired.y + hint_size.y > size.y - 20.0:
		desired.y = prop.position.y - hint_size.y - 10.0
	desired.x = clampf(desired.x, 20.0, maxf(20.0, size.x - hint_size.x - 20.0))
	desired.y = clampf(desired.y, 20.0, maxf(20.0, size.y - hint_size.y - 20.0))
	_hint.position = desired
	_hint.visible = true

func _on_buy() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session != null and not _selected_id.is_empty(): session.call("purchase_growth", _selected_id)
	refresh()

func _state_text(status: Dictionary) -> String:
	if bool(status.get("already_owned", false)): return "已解锁"
	if bool(status.get("pending_activation", false)): return "已预订"
	if bool(status.get("can_purchase", false)): return "可预订"
	var gaps: Array = Array(status.get("missing_requirements", []))
	return "金币不足" if gaps.size() == 1 and StringName(Dictionary(gaps[0]).get("reason", &"")) == &"insufficient_coins" else "条件不足"

func _requirements_text(status: Dictionary) -> String:
	if bool(status.get("already_owned", false)): return "已解锁，已安装在工作台上。"
	if bool(status.get("pending_activation", false)): return "已预订，下一营业日统一生效。"
	var lines := PackedStringArray()
	for raw_requirement in Array(status.get("missing_requirements", [])):
		lines.append(_requirement_text(Dictionary(raw_requirement)))
	return "可立即预订，下一营业日生效。" if lines.is_empty() else "需要：\n" + "\n".join(lines)


func _tag_text(_growth_id: StringName, status: Dictionary) -> String:
	return "%d 金币" % int(status.get("price", 0))


func _tag_tooltip_text(growth_id: StringName, status: Dictionary) -> String:
	var definition := CATALOG.growth_definition(growth_id)
	return "%s · %s · %d 金币\n%s" % [
		str(definition.get("label", "升级")),
		_state_text(status),
		int(status.get("price", 0)),
		_requirements_text(status),
	]


func _unlock_condition_labels(definition: Dictionary) -> PackedStringArray:
	var conditions := PackedStringArray()
	var required_area_id := StringName(definition.get("requires_area_id", &""))
	if not required_area_id.is_empty():
		conditions.append("解锁%s区" % _area_label(required_area_id))
	for raw_growth_id in Array(definition.get("requires_growth_ids", [])):
		var prerequisite := CATALOG.growth_definition(StringName(raw_growth_id))
		conditions.append("拥有%s" % prerequisite.get("label", "前置升级"))
	var min_day := int(definition.get("min_day", 1))
	if min_day > 1:
		conditions.append("第%d天起" % min_day)
	var min_reputation := int(definition.get("min_reputation", 0))
	if min_reputation > 0:
		conditions.append("口碑%d" % min_reputation)
	var tutorial_area_id := StringName(definition.get("requires_tutorial_area_id", &""))
	if not tutorial_area_id.is_empty():
		conditions.append("完成%s教学" % _area_label(tutorial_area_id))
	if bool(definition.get("requires_all_areas", false)):
		conditions.append("解锁全部区域")
	var mastery_requirements := Dictionary(definition.get("requires_mastery", {}))
	for raw_area_id in mastery_requirements:
		var area_id := StringName(raw_area_id)
		var metrics := Dictionary(mastery_requirements[raw_area_id])
		for raw_metric in metrics:
			var metric := StringName(raw_metric)
			var metric_label := "A级" if metric == &"a_grade" else "合格"
			conditions.append("%s%s%d次" % [_area_label(area_id), metric_label, int(metrics[raw_metric])])
	if conditions.is_empty():
		conditions.append("无额外条件")
	return conditions


func _fit_tag_to_content(growth_id: StringName, prop: Button, tag: Label) -> void:
	var authored_layout := Dictionary(_tag_layouts.get(growth_id, {}))
	if authored_layout.is_empty():
		return
	var authored_position: Vector2 = authored_layout.get("position", prop.position)
	var authored_size: Vector2 = authored_layout.get("size", prop.size)
	var characters_per_line := 10
	var line_count := 0
	for line in tag.text.split("\n"):
		line_count += maxi(1, ceili(float(line.length()) / characters_per_line))
	var target_height := maxf(authored_size.y, 12.0 + float(line_count) * 18.0)
	prop.size = Vector2(authored_size.x, target_height)
	prop.position = authored_position + Vector2(0.0, authored_size.y - target_height)


func _focus_first_available_prop() -> void:
	for raw_growth_id in CATALOG.GROWTH_DISPLAY_ORDER:
		var prop := _anchors.get(StringName(raw_growth_id)) as Button
		if prop != null and prop.visible:
			prop.grab_focus()
			return
	%BackButton.grab_focus()


func _inline_requirement(status: Dictionary) -> String:
	if bool(status.get("already_owned", false)):
		return "已解锁"
	if bool(status.get("pending_activation", false)):
		return "已预订"
	var gaps: Array = Array(status.get("missing_requirements", []))
	if gaps.is_empty():
		return "可预订"
	var requirement := _requirement_text(Dictionary(gaps[0]))
	return requirement + "等" if gaps.size() > 1 else requirement

func _requirement_text(requirement: Dictionary) -> String:
	match StringName(requirement.get("reason", &"")):
		&"area_locked": return "先解锁%s区域" % _area_label(StringName(requirement.get("required_area_id", &"")))
		&"growth_requirement": return "先预订%s" % CATALOG.growth_definition(StringName(requirement.get("required_growth_id", &""))).get("label", "前置升级")
		&"day_requirement": return "第 %d 天（当前第 %d 天）" % [int(requirement.get("min_day", 1)), int(requirement.get("current_day", 1))]
		&"reputation_requirement": return "口碑 %d（当前 %d）" % [int(requirement.get("min_reputation", 0)), int(requirement.get("current_reputation", 0))]
		&"tutorial_requirement": return "完成%s教学" % _area_label(StringName(requirement.get("required_tutorial_area_id", &"")))
		&"mastery_requirement": return "%s%s %d 次（当前 %d 次）" % [_area_label(StringName(requirement.get("mastery_area_id", &""))), " A级" if StringName(requirement.get("mastery_metric", &"")) == &"a_grade" else "合格", int(requirement.get("required_mastery", 0)), int(requirement.get("current_mastery", 0))]
		&"insufficient_coins": return "金币 %d/%d" % [int(requirement.get("current_coins", 0)), int(requirement.get("price", 0))]
	return "条件不足"

func _area_label(area_id: StringName) -> String:
	return {&"area.pancake":"煎饼", &"area.youtiao":"油条", &"area.fresh_soy_milk":"豆浆"}.get(area_id, "前置")
