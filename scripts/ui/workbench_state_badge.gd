class_name WorkbenchStateBadge
extends PanelContainer

## Shared, device-attached P2 state treatment.  Every state combines a shape,
## text and colour so the workstation remains fully readable with SFX muted or
## for players who cannot distinguish red, yellow and green alone.

const STATE_DEFAULT := &"default"
const STATE_HOVER := &"hover"
const STATE_SELECTED := &"selected"
const STATE_ACTIVE := &"active"
const STATE_COMPLETE := &"complete"
const STATE_RISK := &"risk"
const STATE_SHORTAGE := &"shortage"
const STATE_UNAVAILABLE := &"unavailable"

const STATE_PRESENTATION := {
	STATE_DEFAULT: {"icon": "○", "color": Color("d9d3c4"), "border": Color("8b8173")},
	STATE_HOVER: {"icon": "◇", "color": Color("fff1b8"), "border": Color("edc66a")},
	STATE_SELECTED: {"icon": "◆", "color": Color("ffe17a"), "border": Color("f1b63c")},
	STATE_ACTIVE: {"icon": "▶", "color": Color("fff0ad"), "border": Color("f1b63c")},
	STATE_COMPLETE: {"icon": "✓", "color": Color("d6f4df"), "border": Color("4d9875")},
	STATE_RISK: {"icon": "!", "color": Color("ffd6ce"), "border": Color("d75b49")},
	STATE_SHORTAGE: {"icon": "↓", "color": Color("ffe0a0"), "border": Color("c8872e")},
	STATE_UNAVAILABLE: {"icon": "×", "color": Color("c8c3bb"), "border": Color("77716a")},
}

var _state: StringName = STATE_DEFAULT
var _detail := "待命"
var _progress := -1.0
var _icon_label: Label
var _text_label: Label
var _progress_bar: ProgressBar


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(188.0, 38.0)
	_build_content()
	_apply_presentation()


func set_state(next_state: StringName, detail: String, progress: float = -1.0) -> void:
	_state = next_state if STATE_PRESENTATION.has(next_state) else STATE_DEFAULT
	_detail = detail
	_progress = progress
	set_meta(&"workbench_state_key", _state)
	set_meta(&"workbench_state_detail", _detail)
	set_meta(&"workbench_state_progress", _progress)
	if is_node_ready():
		_apply_presentation()


func state_key() -> StringName:
	return _state


func detail_text() -> String:
	return _detail


func progress_ratio() -> float:
	return _progress


func _build_content() -> void:
	if _text_label != null:
		return
	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 10)
	margin.add_theme_constant_override(&"margin_top", 5)
	margin.add_theme_constant_override(&"margin_right", 10)
	margin.add_theme_constant_override(&"margin_bottom", 5)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 7)
	margin.add_child(row)
	_icon_label = Label.new()
	_icon_label.custom_minimum_size = Vector2(22.0, 0.0)
	_icon_label.add_theme_font_size_override(&"font_size", 18)
	_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_icon_label)
	_text_label = Label.new()
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.add_theme_font_size_override(&"font_size", 16)
	_text_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_text_label)
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(52.0, 10.0)
	_progress_bar.show_percentage = false
	_progress_bar.max_value = 1.0
	row.add_child(_progress_bar)


func _apply_presentation() -> void:
	var presentation := Dictionary(STATE_PRESENTATION[_state])
	var foreground := Color(presentation["color"])
	var border := Color(presentation["border"])
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.10, 0.095, 0.90 if _state != STATE_DEFAULT else 0.72)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	add_theme_stylebox_override(&"panel", style)
	_icon_label.text = str(presentation["icon"])
	_icon_label.add_theme_color_override(&"font_color", foreground)
	_text_label.text = _detail
	_text_label.add_theme_color_override(&"font_color", foreground)
	_progress_bar.visible = _progress >= 0.0 and _state == STATE_ACTIVE
	_progress_bar.value = clampf(_progress, 0.0, 1.0)
	modulate.a = 0.76 if _state == STATE_DEFAULT else 1.0


static func griddle_state(snapshot: Dictionary, heat_status: Dictionary = {}) -> Dictionary:
	var state := int(snapshot.get("state", 0))
	if bool(heat_status.get("charred", false)):
		return {"state": STATE_RISK, "detail": "鏊台 · 已焦糊", "progress": -1.0}
	if state == 6:
		return {"state": STATE_COMPLETE, "detail": "鏊台 · 可交付", "progress": -1.0}
	if state in [1, 2, 3, 4, 5]:
		var progress := float(heat_status.get("doneness", -1.0)) if bool(heat_status.get("cooking", false)) else -1.0
		return {"state": STATE_ACTIVE, "detail": "鏊台 · 制作", "progress": progress}
	return {"state": STATE_DEFAULT, "detail": "鏊台 · 待命", "progress": -1.0}


static func fryer_state(snapshot: Dictionary, shortage: bool = false) -> Dictionary:
	if not bool(snapshot.get("owned", false)):
		return {"state": STATE_UNAVAILABLE, "detail": "炸锅 · 未解锁", "progress": -1.0}
	var lanes := Dictionary(snapshot.get("lanes", {}))
	var lane_values: Array = lanes.values() if not lanes.is_empty() else [snapshot]
	var states: Array[StringName] = []
	var progress := -1.0
	for lane_value in lane_values:
		var lane := Dictionary(lane_value)
		if not bool(lane.get("owned", true)):
			continue
		var lane_state := StringName(lane.get("state", &"idle"))
		states.append(lane_state)
		if lane_state == &"frying":
			var duration := maxf(float(lane.get("duration_seconds", 0.0)), 0.001)
			progress = maxf(progress, clampf(float(lane.get("cooking_elapsed_seconds", 0.0)) / duration, 0.0, 1.0))
	if states.any(func(value: StringName) -> bool: return value in [&"overcooking", &"burnt"]):
		return {"state": STATE_RISK, "detail": "炸锅 · 过火风险", "progress": -1.0}
	if states.any(func(value: StringName) -> bool: return value in [&"ready_safe", &"ready_to_collect"]):
		return {"state": STATE_COMPLETE, "detail": "炸锅 · 可收取", "progress": -1.0}
	if states.any(func(value: StringName) -> bool: return value in [&"loaded", &"frying", &"draining"]):
		return {"state": STATE_ACTIVE, "detail": "炸锅 · 进行中", "progress": progress}
	if shortage:
		return {"state": STATE_SHORTAGE, "detail": "炸锅 · 原料缺货", "progress": -1.0}
	return {"state": STATE_DEFAULT, "detail": "炸锅 · 待命", "progress": -1.0}


static func soy_state(snapshot: Dictionary, cup_shortage: bool = false) -> Dictionary:
	if not bool(snapshot.get("owned", false)):
		return {"state": STATE_UNAVAILABLE, "detail": "豆浆机 · 未解锁", "progress": -1.0}
	var cup_state := StringName(snapshot.get("cup_state", snapshot.get("state", &"ready")))
	if cup_state == &"filled" or int(snapshot.get("ready_cup_count", 0)) > 0:
		return {"state": STATE_COMPLETE, "detail": "豆浆机 · 可交付", "progress": -1.0}
	if cup_state == &"held_empty":
		return {"state": STATE_ACTIVE, "detail": "豆浆机 · 接浆中", "progress": -1.0}
	if cup_shortage:
		return {"state": STATE_SHORTAGE, "detail": "豆浆机 · 空杯缺货", "progress": -1.0}
	return {"state": STATE_DEFAULT, "detail": "豆浆机 · 待命", "progress": -1.0}


static func packaged_drink_state(unlocked: bool, count: int, capacity: int) -> Dictionary:
	if not unlocked:
		return {"state": STATE_UNAVAILABLE, "detail": "饮品架 · 未解锁", "progress": -1.0}
	if count <= 0:
		return {"state": STATE_SHORTAGE, "detail": "饮品架 · 缺货 0/%d" % capacity, "progress": -1.0}
	return {"state": STATE_COMPLETE, "detail": "饮品架 · 充足 ×%d" % count, "progress": -1.0}
