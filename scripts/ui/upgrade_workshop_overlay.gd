@tool
class_name UpgradeWorkshopOverlay
extends Control

signal begin_next_day_requested
signal closed
const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const PRESS_SPREADER_PROP_PATH := NodePath("UpgradeProps/WorkshopProp_growth_automation_pancake_press_once")
const RUNTIME_PRESS_VISUAL_PATH := NodePath("JianbingStallArtwork/PancakeWorktopHotspots/SpreaderSource/PressVisual")
const EDITOR_PRESS_VISUAL_PATH := NodePath("SyncedWorkstationPreview/SafeArea/JianbingStallArtwork/PancakeWorktopHotspots/SpreaderSource/PressVisual")
const EDITOR_PANCAKE_WORKTOP_PATH := NodePath("SafeArea/JianbingStallArtwork/PancakeWorktopHotspots")
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
	NodePath("FiveAreaInfrastructure/PendingPaymentButton"),
]
@onready var _detail := %DetailText as RichTextLabel
@onready var _queue := %QueueLabel as Label
@onready var _buy := %BuyButton as Button
@onready var _hint := %HoverHint as PanelContainer
@onready var _hint_label := %HintLabel as Label
@onready var _detail_panel := %DetailPanel as Panel
@onready var _press_preview := %PressSpreaderPreview as TextureRect
@onready var _juice_tray_preview := %FilledOrangeJuiceTrayPreview as TextureRect
@onready var _editor_preview := %EditorPreview as Control
var _selected_id: StringName = &""
var _anchors: Dictionary = {}
var _tag_layouts: Dictionary = {}


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
			material_previews.visible = true
		_configure_editor_workstation_preview()
		call_deferred("_sync_press_spreader_layout")
		return
	_editor_preview.visible = false
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
		prop.mouse_entered.connect(_show_hint.bind(growth_id, prop))
		prop.mouse_exited.connect(func() -> void: _hint.visible = false)
		_anchors[growth_id] = prop
		_tag_layouts[growth_id] = {"position": prop.position, "size": prop.size}
	refresh()


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
	_configure_editor_pancake_preview(synced_preview)


func _configure_editor_pancake_preview(synced_preview: Control) -> void:
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
			container.modulate = Color.WHITE
	_set_editor_preview_texture_from_last_export(
		worktop,
		NodePath("EggCarton/Visual/Contents"),
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
	_press_preview.visible = true
	_press_preview.self_modulate = Color(1.0, 1.0, 1.0, 1.0 if press_spreader_owned else 0.42)
	# A future drink rack is still readable in the workshop, but remains clearly
	# a preview until the area is active on the next business day.
	_juice_tray_preview.self_modulate = Color(1.0, 1.0, 1.0, 1.0 if packaged_drinks_unlocked else 0.42)
	var queued_labels := PackedStringArray()
	for raw_id in Array(Dictionary(session.call("five_area_progression_snapshot")).get("pending_growth_ids", [])):
		queued_labels.append(str(CATALOG.growth_definition(StringName(raw_id)).get("label", raw_id)))
	_queue.text = "升级工作台总览 · 预订清单：%s" % ("、".join(queued_labels) if not queued_labels.is_empty() else "空")
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
			&"growth.capacity.chicken_finished_tray",
			&"growth.add_on.pancake.egg",
			&"growth.add_on.pancake.baocui",
			&"growth.add_on.pancake.scallion",
			&"growth.automation.pancake.one_click_egg",
		]
		var is_youtiao_machine_upgrade := growth_id in [&"growth.area.youtiao", &"growth.equipment.youtiao.advanced", &"growth.equipment.youtiao.dual_basket"]
		var is_soy_milk_machine_upgrade := growth_id in [&"growth.area.fresh_soy_milk", &"growth.automation.fresh_soy_milk.auto_fill", &"growth.automation.fresh_soy_milk.advanced"]
		prop.visible = not bool(status.get("already_owned", false)) \
			and (_has_owned_growth_prerequisites(growth_id, owned_growth_ids) or show_prerequisite_locked_visual) \
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
		prop.modulate = Color.WHITE if _state_text(status) != "条件不足" and _state_text(status) != "金币不足" else Color(0.62, 0.62, 0.62, 1.0)
	if not _selected_id.is_empty() and selected_prop_is_visible:
		_show_detail(_selected_id)
	elif not _selected_id.is_empty():
		_selected_id = &""
		_detail_panel.visible = false
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
	var normal_background := Color(0.15, 0.17, 0.20, 0.94)
	var normal_border := Color(0.54, 0.58, 0.63, 0.94)
	var hover_background := Color(0.20, 0.23, 0.27, 0.98)
	var hover_border := Color(0.72, 0.76, 0.81, 1.0)
	if bool(status.get("already_owned", false)):
		normal_background = Color(0.08, 0.20, 0.30, 0.96)
		normal_border = Color(0.42, 0.75, 0.94, 1.0)
		hover_background = Color(0.11, 0.28, 0.40, 0.98)
		hover_border = Color(0.67, 0.88, 1.0, 1.0)
	elif bool(status.get("pending_activation", false)):
		normal_background = Color(0.31, 0.20, 0.06, 0.96)
		normal_border = Color(1.0, 0.75, 0.32, 1.0)
		hover_background = Color(0.40, 0.27, 0.08, 0.98)
		hover_border = Color(1.0, 0.89, 0.56, 1.0)
	elif bool(status.get("can_purchase", false)):
		normal_background = Color(0.07, 0.27, 0.16, 0.96)
		normal_border = Color(0.47, 0.91, 0.60, 1.0)
		hover_background = Color(0.10, 0.36, 0.21, 0.98)
		hover_border = Color(0.78, 1.0, 0.72, 1.0)
	var normal := _upgrade_tag_box(normal_background, normal_border)
	var hover := _upgrade_tag_box(hover_background, hover_border)
	prop.add_theme_stylebox_override("normal", normal)
	prop.add_theme_stylebox_override("hover", hover)
	prop.add_theme_stylebox_override("pressed", hover)
	prop.add_theme_color_override("font_color", Color(1.0, 0.98, 0.84, 1.0))
	prop.add_theme_color_override("font_hover_color", Color.WHITE)


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
	_show_detail(growth_id)


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
	_detail.text = "[b]%s[/b]\n价格：%d 金币\n状态：%s\n%s" % [definition.get("label", "升级"), int(status.get("price", 0)), _state_text(status), _requirements_text(status)]
	_buy.disabled = not bool(status.get("can_purchase", false))
	_buy.text = "预订（次日生效）" if not _buy.disabled else "当前不可预订"
	_detail_panel.visible = true

func _show_hint(growth_id: StringName, prop: Control) -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null: return
	var status := Dictionary(session.call("growth_purchase_status", growth_id))
	_hint_label.text = _tag_tooltip_text(growth_id, status)
	_hint.position = prop.position + Vector2(0, 42)
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


func _tag_text(growth_id: StringName, status: Dictionary) -> String:
	var definition := CATALOG.growth_definition(growth_id)
	var growth_name := str(definition.get("label", "升级"))
	if bool(status.get("can_purchase", false)):
		return "名称：%s，价格：%d金币" % [growth_name, int(status.get("price", 0))]
	return "名称：%s，不可预订" % growth_name


func _tag_tooltip_text(growth_id: StringName, status: Dictionary) -> String:
	if bool(status.get("can_purchase", false)):
		return _tag_text(growth_id, status)
	return _requirements_text(status)


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
	var characters_per_line := 15
	var line_count := 0
	for line in tag.text.split("\n"):
		line_count += maxi(1, ceili(float(line.length()) / characters_per_line))
	var target_height := maxf(authored_size.y, 10.0 + float(line_count) * 15.0)
	prop.size = Vector2(authored_size.x, target_height)
	prop.position = authored_position + Vector2(0.0, authored_size.y - target_height)


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
