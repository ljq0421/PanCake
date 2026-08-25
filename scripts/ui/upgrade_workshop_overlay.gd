@tool
class_name UpgradeWorkshopOverlay
extends Control

signal begin_next_day_requested
signal closed
const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
@onready var _detail := %DetailText as RichTextLabel
@onready var _queue := %QueueLabel as Label
@onready var _buy := %BuyButton as Button
@onready var _hint := %HoverHint as PanelContainer
@onready var _hint_label := %HintLabel as Label
@onready var _detail_panel := %DetailPanel as Panel
@onready var _press_preview := %PressSpreaderPreview as TextureRect
@onready var _editor_preview := %EditorPreview as Control
var _selected_id: StringName = &""
var _anchors: Dictionary = {}

func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_preview.visible = true
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
		prop.pressed.connect(_select.bind(growth_id))
		prop.mouse_entered.connect(_show_hint.bind(growth_id, prop))
		prop.mouse_exited.connect(func() -> void: _hint.visible = false)
		_anchors[growth_id] = prop
	refresh()

func refresh() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null: return
	var overview: Array = session.call("growth_overview")
	var progression := Dictionary(session.call("five_area_progression_snapshot"))
	var owned_growth_ids := Array(progression.get("owned_growth_ids", []))
	var youtiao_upgrade_id := _next_youtiao_fryer_upgrade(owned_growth_ids)
	var wide_spreader_owned := owned_growth_ids.has("growth.tool.pancake.wide_spreader")
	var press_spreader_owned := owned_growth_ids.has("growth.automation.pancake.press_once")
	_press_preview.visible = wide_spreader_owned
	_press_preview.self_modulate = Color(1.0, 1.0, 1.0, 1.0 if press_spreader_owned else 0.42)
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
		# prerequisites are installed. Keep their tags visible too, so the
		# otherwise unexplained artwork tells the player what can be reserved and
		# which condition is still missing.
		var show_prerequisite_locked_visual := growth_id in [
			&"growth.capacity.youtiao_finished_tray",
			&"growth.flavor.youtiao.sesame",
			&"growth.add_on.pancake.sweet_flour",
			&"growth.add_on.pancake.baocui",
			&"growth.add_on.pancake.scallion",
		]
		prop.visible = (_has_owned_growth_prerequisites(growth_id, owned_growth_ids) or show_prerequisite_locked_visual) and (not growth_id in [&"growth.area.youtiao", &"growth.equipment.youtiao.advanced"] or growth_id == youtiao_upgrade_id)
		if growth_id == _selected_id:
			selected_prop_is_visible = prop.visible
		prop.tooltip_text = _requirements_text(status)
		var condition_tag := prop.get_node_or_null("ConditionTag") as Label
		if condition_tag != null:
			condition_tag.text = "%s\n%s" % [CATALOG.growth_definition(growth_id).get("label", "升级"), _inline_requirement(status)]
		_apply_upgrade_tag_style(prop, status)
		prop.modulate = Color.WHITE if _state_text(status) != "条件不足" and _state_text(status) != "金币不足" else Color(0.62, 0.62, 0.62, 1.0)
	if not _selected_id.is_empty() and selected_prop_is_visible:
		_show_detail(_selected_id)
	elif not _selected_id.is_empty():
		_selected_id = &""
		_detail_panel.visible = false


func _has_owned_growth_prerequisites(growth_id: StringName, owned_growth_ids: Array) -> bool:
	for raw_required_growth_id in Array(CATALOG.growth_definition(growth_id).get("requires_growth_ids", [])):
		if not owned_growth_ids.has(StringName(raw_required_growth_id)):
			return false
	return true


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
	return &""

func _select(growth_id: StringName) -> void:
	_selected_id = growth_id
	_show_detail(growth_id)

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
	_hint_label.text = "%s\n%s" % [CATALOG.growth_definition(growth_id).get("label", "升级"), _requirements_text(status)]
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
