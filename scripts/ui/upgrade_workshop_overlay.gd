class_name UpgradeWorkshopOverlay
extends Control

signal begin_next_day_requested
signal closed
const CATALOG := preload("res://scripts/data/five_area_catalog.gd")

## Positions correspond to actual counter objects; labels are temporary props
## for artwork that has not yet been produced.
const PROP_LAYOUT := {
	&"growth.tool.pancake.wide_spreader": [Vector2(760, 645), "宽幅摊饼器"], &"growth.add_on.pancake.red_chili": [Vector2(1335, 690), "辣椒酱瓶"], &"growth.add_on.pancake.ham_sausage": [Vector2(1110, 840), "火腿槽"], &"growth.add_on.pancake.coriander": [Vector2(1215, 840), "香菜槽"], &"growth.add_on.pancake.meat_floss": [Vector2(1320, 840), "肉松槽"], &"growth.add_on.pancake.tomato": [Vector2(1435, 690), "番茄酱瓶"], &"growth.automation.pancake.press_once": [Vector2(900, 620), "压饼器"], &"growth.automation.pancake.auto_sauce_brush": [Vector2(1010, 620), "自动酱刷"],
	&"growth.area.youtiao": [Vector2(230, 610), "油条炸锅"], &"growth.flavor.youtiao.sesame": [Vector2(95, 875), "芝麻盒"], &"growth.flavor.youtiao.sugar": [Vector2(220, 875), "白糖盒"], &"growth.assist.youtiao.temperature_indicator": [Vector2(350, 610), "控温器"], &"growth.equipment.youtiao.fast_fryer": [Vector2(335, 700), "快速炸锅"], &"growth.equipment.youtiao.eight_slot": [Vector2(335, 780), "八格炸篮"],
	&"growth.area.fresh_soy_milk": [Vector2(510, 635), "豆浆机"], &"growth.assist.fresh_soy_milk.sugar": [Vector2(565, 845), "加糖罐"], &"growth.flavor.fresh_soy_milk.black_bean": [Vector2(455, 555), "黑豆菜单"], &"growth.assist.fresh_soy_milk.ice": [Vector2(680, 845), "加冰盒"], &"growth.flavor.fresh_soy_milk.red_bean": [Vector2(570, 555), "红豆菜单"], &"growth.automation.fresh_soy_milk.auto_fill": [Vector2(660, 635), "自动满杯"],
}

var _detail: RichTextLabel
var _queue: Label
var _buy: Button
var _hint: PanelContainer
var _hint_label: Label
var _selected_id: StringName = &""
var _anchors: Dictionary = {}

func _ready() -> void:
	z_index = 1100
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.05, 0.08, 0.42)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_queue = Label.new()
	_queue.position = Vector2(28, 24)
	_queue.add_theme_font_size_override("font_size", 18)
	_queue.add_theme_color_override("font_color", Color("fff3c7"))
	add_child(_queue)
	_build_detail_panel()
	_build_hover_hint()
	for growth_id in CATALOG.GROWTH_DISPLAY_ORDER:
		var layout: Array = PROP_LAYOUT[growth_id]
		var prop_position: Vector2 = layout[0]
		var prop := Button.new()
		prop.name = "WorkshopProp_" + str(growth_id).replace(".", "_")
		prop.position = prop_position
		prop.size = Vector2(104, 44)
		prop.pressed.connect(_select.bind(growth_id))
		prop.mouse_entered.connect(_show_hint.bind(growth_id, prop))
		prop.mouse_exited.connect(func() -> void: _hint.visible = false)
		add_child(prop)
		_anchors[growth_id] = prop
	refresh()

func _build_detail_panel() -> void:
	var panel := Panel.new()
	panel.position = Vector2(28, 64)
	panel.size = Vector2(360, 365)
	add_child(panel)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.position = Vector2(14, 12)
	_detail.size = Vector2(332, 242)
	panel.add_child(_detail)
	_buy = Button.new()
	_buy.position = Vector2(14, 270)
	_buy.size = Vector2(332, 38)
	_buy.pressed.connect(_on_buy)
	panel.add_child(_buy)
	var next := Button.new()
	next.text = "确认预订，开始下一天"
	next.position = Vector2(14, 314)
	next.size = Vector2(210, 36)
	next.pressed.connect(func() -> void: begin_next_day_requested.emit())
	panel.add_child(next)
	var back := Button.new()
	back.text = "返回账单"
	back.position = Vector2(230, 314)
	back.size = Vector2(116, 36)
	back.pressed.connect(func() -> void: closed.emit())
	panel.add_child(back)

func _build_hover_hint() -> void:
	_hint = PanelContainer.new()
	_hint.visible = false
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.size = Vector2(310, 128)
	_hint.z_index = 2
	_hint_label = Label.new()
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_font_size_override("font_size", 16)
	_hint.add_child(_hint_label)
	add_child(_hint)

func refresh() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null: return
	var overview: Array = session.call("growth_overview")
	var queued_labels := PackedStringArray()
	for raw_id in Array(Dictionary(session.call("five_area_progression_snapshot")).get("pending_growth_ids", [])):
		queued_labels.append(str(CATALOG.growth_definition(StringName(raw_id)).get("label", raw_id)))
	_queue.text = "升级工作台总览 · 预订清单：%s" % ("、".join(queued_labels) if not queued_labels.is_empty() else "空")
	for raw_status in overview:
		var status := Dictionary(raw_status)
		var growth_id := StringName(status.get("growth_id", &""))
		var prop := _anchors.get(growth_id) as Button
		if prop == null: continue
		prop.text = "%s\n￥%d · %s" % [str(PROP_LAYOUT[growth_id][1]), int(status.get("price", 0)), _state_text(status)]
		prop.tooltip_text = _requirements_text(status)
		prop.modulate = Color.WHITE if _state_text(status) != "条件不足" and _state_text(status) != "金币不足" else Color(0.46, 0.46, 0.46, 1.0)
	if not _selected_id.is_empty(): _show_detail(_selected_id)

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

func _show_hint(growth_id: StringName, prop: Control) -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null: return
	var status := Dictionary(session.call("growth_purchase_status", growth_id))
	_hint_label.text = "%s\n%s" % [CATALOG.growth_definition(growth_id).get("label", "升级"), _requirements_text(status)]
	_hint.position = prop.position + Vector2(0, 48)
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
