class_name UpgradeWorkshopOverlay
extends Control

signal begin_next_day_requested
signal closed
const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const WIDE_SPREADER_VISUAL_PATH := "SafeArea/JianbingStallArtwork/PancakeWorktopHotspots/SpreaderHolderFilledVisual"

# Each upgrade is anchored to the actual artwork node in the workstation scene.
# This deliberately avoids a second set of hand-maintained workshop coordinates.
const SOURCE_PATHS := {
	&"growth.area.youtiao": "FiveAreaInfrastructure/Stations/CartoonYoutiaoFryer/FryerVisual",
	&"growth.equipment.youtiao.advanced": "FiveAreaInfrastructure/Stations/CartoonYoutiaoFryer/FryerVisual",
	&"growth.area.fresh_soy_milk": "FiveAreaInfrastructure/Stations/FreshSoyMilkStation/SoyMilkDispenser",
	&"growth.flavor.fresh_soy_milk.black_bean": "FiveAreaInfrastructure/Stations/FreshSoyMilkStation/SoyMilkDispenser",
	&"growth.flavor.fresh_soy_milk.red_bean": "FiveAreaInfrastructure/Stations/FreshSoyMilkStation/SoyMilkDispenser",
	&"growth.assist.fresh_soy_milk.sugar": "FiveAreaInfrastructure/Stations/FreshSoyMilkStation/SoyMilkSugarJar",
	&"growth.assist.fresh_soy_milk.ice": "FiveAreaInfrastructure/Stations/FreshSoyMilkStation/IceButton",
	&"growth.automation.fresh_soy_milk.auto_fill": "FiveAreaInfrastructure/Stations/FreshSoyMilkStation/SoyMilkDispenser",
	&"growth.tool.pancake.wide_spreader": "SafeArea/JianbingStallArtwork/PancakeWorktopHotspots/SpreaderHolderFilledVisual",
	&"growth.automation.pancake.press_once": "SafeArea/JianbingStallArtwork/PancakeWorktopHotspots/SpreaderHolderFilledVisual",
	&"growth.automation.pancake.auto_sauce_brush": "SafeArea/JianbingStallArtwork/SweetBeanSauceJar",
	&"growth.add_on.pancake.chili_sauce": "SafeArea/JianbingStallArtwork/ChiliSauceJar",
	&"growth.add_on.pancake.tomato": "SafeArea/JianbingStallArtwork/TomatoSauceJar",
	&"growth.add_on.pancake.ham_sausage": "SafeArea/JianbingStallArtwork/ToppingIngredientTray2",
	&"growth.add_on.pancake.meat_floss": "SafeArea/JianbingStallArtwork/ToppingIngredientTray",
	&"growth.add_on.pancake.coriander": "SafeArea/JianbingStallArtwork/PancakeWorktopHotspots/CorianderTray/Visual",
	&"growth.add_on.pancake.red_chili": "SafeArea/JianbingStallArtwork/ChiliSauceJar",
	&"growth.flavor.youtiao.sesame": "FiveAreaInfrastructure/Stations/CartoonYoutiaoFryer",
	&"growth.flavor.youtiao.sugar": "FiveAreaInfrastructure/Stations/CartoonYoutiaoFryer",
	&"growth.assist.youtiao.temperature_indicator": "FiveAreaInfrastructure/Stations/CartoonYoutiaoFryer/FryerVisual",
}
const TAG_OFFSETS := {
	&"growth.flavor.youtiao.sesame": Vector2(0.0, -84.0),
	&"growth.flavor.youtiao.sugar": Vector2(0.0, -42.0),
	&"growth.assist.youtiao.temperature_indicator": Vector2(0.0, 42.0),
	# The area unlock shares the dispenser artwork with three follow-up upgrades.
	# Give it its own row so the essential "豆浆机" purchase target cannot be
	# covered by the red-bean flavour target.
	&"growth.area.fresh_soy_milk": Vector2(0.0, -84.0),
	&"growth.flavor.fresh_soy_milk.black_bean": Vector2(0.0, -42.0),
	&"growth.flavor.fresh_soy_milk.red_bean": Vector2(0.0, 0.0),
	&"growth.automation.fresh_soy_milk.auto_fill": Vector2(0.0, 42.0),
	&"growth.tool.pancake.wide_spreader": Vector2(0.0, -42.0),
	&"growth.automation.pancake.press_once": Vector2(0.0, 0.0),
	&"growth.automation.pancake.auto_sauce_brush": Vector2(0.0, 42.0),
	&"growth.add_on.pancake.red_chili": Vector2(0.0, -42.0),
}

@onready var _detail := %DetailText as RichTextLabel
@onready var _queue := %QueueLabel as Label
@onready var _buy := %BuyButton as Button
@onready var _hint := %HoverHint as PanelContainer
@onready var _hint_label := %HintLabel as Label
@onready var _detail_panel := %DetailPanel as Panel
@onready var _press_preview := %PressSpreaderPreview as TextureRect
var _selected_id: StringName = &""
var _anchors: Dictionary = {}

func _ready() -> void:
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
	if wide_spreader_owned:
		_align_press_preview_to_wide_spreader()
	var queued_labels := PackedStringArray()
	for raw_id in Array(Dictionary(session.call("five_area_progression_snapshot")).get("pending_growth_ids", [])):
		queued_labels.append(str(CATALOG.growth_definition(StringName(raw_id)).get("label", raw_id)))
	_queue.text = "升级工作台总览 · 预订清单：%s" % ("、".join(queued_labels) if not queued_labels.is_empty() else "空")
	for raw_status in overview:
		var status := Dictionary(raw_status)
		var growth_id := StringName(status.get("growth_id", &""))
		var prop := _anchors.get(growth_id) as Button
		if prop == null: continue
		prop.visible = not growth_id in [&"growth.area.youtiao", &"growth.equipment.youtiao.advanced"] or growth_id == youtiao_upgrade_id
		_anchor_to_source(prop, growth_id)
		prop.tooltip_text = _requirements_text(status)
		var condition_tag := prop.get_node_or_null("ConditionTag") as Label
		if condition_tag != null:
			condition_tag.text = "%s\n%s" % [CATALOG.growth_definition(growth_id).get("label", "升级"), _inline_requirement(status)]
		prop.modulate = Color.WHITE if _state_text(status) != "条件不足" and _state_text(status) != "金币不足" else Color(0.62, 0.62, 0.62, 1.0)
	if not _selected_id.is_empty(): _show_detail(_selected_id)


func _anchor_to_source(prop: Control, growth_id: StringName) -> void:
	if growth_id == &"growth.automation.pancake.press_once":
		_anchor_to_control(prop, _press_preview, growth_id)
		return
	var source_path := String(SOURCE_PATHS.get(growth_id, ""))
	if source_path.is_empty():
		return
	var safe_area := get_parent()
	var workstation := safe_area.get_parent() if safe_area != null else null
	if workstation == null:
		return
	var source := workstation.get_node_or_null(NodePath(source_path)) as Control
	if source == null:
		return
	_anchor_to_control(prop, source, growth_id)


func _anchor_to_control(prop: Control, source: Control, growth_id: StringName) -> void:
	if source == null:
		return
	var global_rect := source.get_global_rect()
	var local_origin := get_global_transform_with_canvas().affine_inverse() * global_rect.position
	# Keep the tag next to (not on top of) the artwork so the authored image is
	# still visible and remains the visual source of truth.
	var offset := Vector2(TAG_OFFSETS.get(growth_id, Vector2.ZERO))
	prop.position = local_origin + Vector2(global_rect.size.x + 8.0, 2.0) + offset
	if prop.position.x + prop.size.x > size.x - 12.0:
		prop.position = local_origin + Vector2(-prop.size.x - 8.0, 2.0) + offset


func _wide_spreader_visual() -> Control:
	var safe_area := get_parent()
	var workstation := safe_area.get_parent() if safe_area != null else null
	return workstation.get_node_or_null(NodePath(WIDE_SPREADER_VISUAL_PATH)) as Control if workstation != null else null


func _align_press_preview_to_wide_spreader() -> void:
	var visual := _wide_spreader_visual()
	if visual == null:
		return
	var visual_rect := visual.get_global_rect()
	var preview_parent := _press_preview.get_parent() as Control
	if preview_parent == null:
		return
	_press_preview.position = preview_parent.get_global_transform_with_canvas().affine_inverse() * visual_rect.position
	_press_preview.size = visual_rect.size


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
	if bool(status.get("already_owned", false)): return "已拥有"
	if bool(status.get("pending_activation", false)): return "已预订"
	if bool(status.get("can_purchase", false)): return "可预订"
	var gaps: Array = Array(status.get("missing_requirements", []))
	return "金币不足" if gaps.size() == 1 and StringName(Dictionary(gaps[0]).get("reason", &"")) == &"insufficient_coins" else "条件不足"

func _requirements_text(status: Dictionary) -> String:
	if bool(status.get("already_owned", false)): return "已安装在工作台上。"
	if bool(status.get("pending_activation", false)): return "已预订，下一营业日统一生效。"
	var lines := PackedStringArray()
	for raw_requirement in Array(status.get("missing_requirements", [])):
		lines.append(_requirement_text(Dictionary(raw_requirement)))
	return "可立即预订，下一营业日生效。" if lines.is_empty() else "需要：\n" + "\n".join(lines)


func _inline_requirement(status: Dictionary) -> String:
	if bool(status.get("already_owned", false)):
		return "已安装"
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
		&"reputation_requirement": return "声望 %d（当前 %d）" % [int(requirement.get("min_reputation", 0)), int(requirement.get("current_reputation", 0))]
		&"tutorial_requirement": return "完成%s教学" % _area_label(StringName(requirement.get("required_tutorial_area_id", &"")))
		&"mastery_requirement": return "%s%s %d 次（当前 %d 次）" % [_area_label(StringName(requirement.get("mastery_area_id", &""))), " A级" if StringName(requirement.get("mastery_metric", &"")) == &"a_grade" else "合格", int(requirement.get("required_mastery", 0)), int(requirement.get("current_mastery", 0))]
		&"insufficient_coins": return "金币 %d/%d" % [int(requirement.get("current_coins", 0)), int(requirement.get("price", 0))]
	return "条件不足"

func _area_label(area_id: StringName) -> String:
	return {&"area.pancake":"煎饼", &"area.youtiao":"油条", &"area.fresh_soy_milk":"豆浆"}.get(area_id, "前置")
