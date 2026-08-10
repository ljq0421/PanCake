class_name CustomerHandoffTray
extends Control

signal status_message(message: String)
signal order_handed_off(result: Dictionary)
signal product_staged(result: Dictionary, source_ref: Dictionary, item_index: int)

@onready var slots: Array[HandoffTraySlot] = [%TraySlot01, %TraySlot02, %TraySlot03]
@onready var tray_handle: TrayHandoffDragHandle = %TrayHandle
@onready var customer_drop_target: TrayCustomerDropTarget = %CustomerDropTarget
@onready var missing_label: Label = %MissingLabel
@onready var customer_hint: Label = %CustomerHint

var _order_id: StringName = &""


func _ready() -> void:
	for slot in slots:
		slot.product_source_dropped.connect(_on_product_source_dropped)
	customer_drop_target.tray_dropped.connect(_on_tray_dropped)
	clear_order()


func focus_order(order: Dictionary) -> void:
	var next_order_id := StringName(order.get("order_id", &""))
	var order_changed := next_order_id != _order_id
	_order_id = next_order_id
	var items := Array(order.get("items", []))
	for index in range(slots.size()):
		if index < items.size():
			slots[index].visible = true
			slots[index].configure(_order_id, Dictionary(items[index]))
		else:
			slots[index].visible = false
			slots[index].clear_slot()
	tray_handle.configure(_order_id)
	if order_changed:
		missing_label.text = ""
	customer_hint.text = "装盘后向顾客拖动整盘"
	visible = not _order_id.is_empty()


func clear_order() -> void:
	_order_id = &""
	for slot in slots:
		slot.clear_slot()
	tray_handle.configure(&"")
	missing_label.text = "等待顾客点单"
	customer_hint.text = "共享递餐托盘"
	visible = true


func refresh_from_session() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null or _order_id.is_empty() or not session.has_method("formal_order"):
		clear_order()
		return
	var order := Dictionary(session.call("formal_order", _order_id))
	if order.is_empty() or StringName(order.get("state", &"")) not in [&"active", &"serving"]:
		clear_order()
		return
	focus_order(order)


func focused_order_id() -> StringName:
	return _order_id


func _on_product_source_dropped(source_ref: Dictionary, item_index: int) -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null or not session.has_method("stage_product_to_order"):
		status_message.emit("装盘失败：营业存档尚未就绪")
		return
	var result: Dictionary = session.call("stage_product_to_order", source_ref, _order_id, item_index)
	if bool(result.get("success", false)):
		missing_label.text = ""
		status_message.emit("已放入第 %d 格%s" % [item_index + 1, "（与点单不符，递出后顾客会反馈）" if not bool(result.get("will_match", false)) else ""])
		product_staged.emit(result.duplicate(true), source_ref.duplicate(true), item_index)
	else:
		status_message.emit("餐品回到原处：%s" % str(result.get("reason", &"unknown")))
	refresh_from_session()


func _on_tray_dropped(order_id: StringName) -> void:
	if order_id != _order_id:
		status_message.emit("托盘已回弹：顾客已切换")
		return
	var session := get_node_or_null("/root/GameSession")
	if session == null or not session.has_method("handoff_order_tray"):
		return
	var result: Dictionary = session.call("handoff_order_tray", order_id)
	if not bool(result.get("success", false)):
		if StringName(result.get("reason", &"")) == &"tray_incomplete":
			missing_label.text = _missing_text(Array(result.get("missing_items", [])))
			status_message.emit("托盘未装齐，已回弹")
		else:
			status_message.emit("暂时不能递餐：%s" % str(result.get("reason", &"unknown")))
		return
	missing_label.text = ""
	order_handed_off.emit(result)


static func _missing_text(missing_items: Array) -> String:
	var parts := PackedStringArray()
	for missing_value in missing_items:
		var missing := Dictionary(missing_value)
		parts.append("第%d格缺%d" % [int(missing.get("item_index", 0)) + 1, int(missing.get("missing_quantity", 1))])
	return "缺少：%s" % "、".join(parts)
