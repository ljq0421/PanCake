class_name F3StationController
extends Control

signal order_finished(result: Dictionary)

@onready var drink_station = %PackagedDrinkStation
@onready var youtiao_station = %YoutiaoStation
@onready var order_summary_label: Label = %OrderSummaryLabel
@onready var feedback_label: Label = %GlobalFeedbackLabel
@onready var settle_button: Button = %SettleOrderButton
@onready var refuse_button: Button = %RefuseOrderButton
@onready var skip_tutorial_button: Button = %SkipTutorialButton

var _session: Node
var _item_buttons: Array[Button] = []
var _selected_item_index := 0
var _interaction_enabled := true
var _displayed_order_id: StringName = &""
var _refusal_confirmation_order_id: StringName = &""
var _skip_confirmation_tutorial_id: StringName = &""


func _ready() -> void:
	_session = get_node_or_null("/root/GameSession")
	_item_buttons = [%OrderItem1, %OrderItem2, %OrderItem3]
	for index in range(_item_buttons.size()):
		_item_buttons[index].pressed.connect(_select_order_item.bind(index))
	drink_station.intent_requested.connect(_on_station_intent.bind(&"drink"))
	youtiao_station.intent_requested.connect(_on_station_intent.bind(&"youtiao"))
	settle_button.pressed.connect(_settle_order)
	refuse_button.pressed.connect(_refuse_order)
	skip_tutorial_button.pressed.connect(_skip_tutorial)
	if _session != null:
		if _session.has_signal("production_changed"):
			_session.production_changed.connect(_on_session_changed)
		if _session.has_signal("inventory_changed"):
			_session.inventory_changed.connect(_on_session_changed)
		if _session.has_signal("progression_changed"):
			_session.progression_changed.connect(_on_session_changed)
		if _session.has_signal("order_changed"):
			_session.order_changed.connect(_on_session_changed)
	set_process(true)
	_refresh()


func _process(_delta: float) -> void:
	# Production time is advanced by the formal workstation so all regions keep
	# running concurrently even when this overlay is closed.
	pass


func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	drink_station.set_interaction_enabled(enabled)
	youtiao_station.set_interaction_enabled(enabled)
	settle_button.disabled = not enabled
	refuse_button.disabled = not enabled
	skip_tutorial_button.disabled = not enabled


func refresh_from_session() -> void:
	_refresh()


func _select_order_item(item_index: int) -> void:
	_selected_item_index = item_index
	_refresh()


func _on_station_intent(intent: Dictionary, source: StringName) -> void:
	if _session == null:
		_show_result(source, {"success": false, "reason": &"session_unavailable"})
		return
	var result: Dictionary
	match StringName(intent.get("type", &"")):
		&"restock_hold":
			result = _session.call("advance_five_area_restock_hold", StringName(intent.get("stock_id", &"")), float(intent.get("delta", 0.0)))
		&"deliver_room_temperature_drink":
			result = _session.call("deliver_room_temperature_drink", StringName(intent.get("order_id", &"")), int(intent.get("item_index", -1)), StringName(intent.get("product_id", &"")))
		&"load_drink":
			result = _session.call("load_f3_drink", int(intent.get("slot_index", -1)), StringName(intent.get("product_id", &"")), StringName(intent.get("order_id", &"")))
		&"deliver_heated_drink":
			result = _session.call("deliver_heated_drink", int(intent.get("slot_index", -1)), StringName(intent.get("order_id", &"")), int(intent.get("item_index", -1)))
		&"discard_drink":
			result = _session.call("discard_f3_drink", int(intent.get("slot_index", -1)))
		&"load_youtiao":
			result = _session.call("load_f3_youtiao", StringName(intent.get("recipe_id", &"")), int(intent.get("quantity", 1)), StringName(intent.get("order_id", &"")))
		&"youtiao_action":
			result = _session.call("perform_f3_youtiao_action", StringName(intent.get("action_id", &"")))
		&"deliver_youtiao":
			result = _session.call("deliver_f3_youtiao", StringName(intent.get("order_id", &"")), int(intent.get("item_index", -1)))
		&"discard_youtiao":
			result = _session.call("discard_f3_youtiao")
		_:
			result = {"success": false, "reason": &"unknown_intent"}
	_show_result(source, result)
	_refresh()


func _settle_order() -> void:
	if _session == null:
		return
	var order: Dictionary = _session.call("active_formal_order")
	var order_id := StringName(order.get("order_id", &""))
	if order_id.is_empty():
		_show_result(&"global", {"success": false, "reason": &"order_not_active"})
		return
	var result: Dictionary = _session.call("settle_f3_order", order_id, false)
	_show_result(&"global", result)
	if bool(result.get("success", false)):
		order_finished.emit(result.duplicate(true))
	_refresh()


func _refuse_order() -> void:
	if _session == null:
		return
	var order: Dictionary = _session.call("active_formal_order")
	var order_id := StringName(order.get("order_id", &""))
	if order_id.is_empty():
		_show_result(&"global", {"success": false, "reason": &"order_not_active"})
		return
	if _refusal_confirmation_order_id != order_id:
		var preview: Dictionary = _session.call("preview_formal_order_refusal", order_id)
		if not bool(preview.get("success", false)):
			_show_result(&"global", preview)
			return
		_refusal_confirmation_order_id = order_id
		refuse_button.text = "确认婉拒（口碑 %d）" % int(preview.get("reputation_delta", -1))
		feedback_label.text = "再次点击确认；本单预计口碑 %d。" % int(preview.get("reputation_delta", -1))
		return
	var result: Dictionary = _session.call("refuse_formal_order", order_id)
	_show_result(&"global", result)
	if bool(result.get("success", false)):
		order_finished.emit(result.duplicate(true))
	_refresh()


func _skip_tutorial() -> void:
	if _session == null:
		return
	var progression: Dictionary = _session.call("five_area_progression_snapshot")
	var tutorial := Dictionary(progression.get("tutorial", {}))
	var tutorial_id := StringName(tutorial.get("active_id", &""))
	if tutorial_id.is_empty():
		_show_result(&"global", {"success": false, "reason": &"tutorial_not_active"})
		return
	if _skip_confirmation_tutorial_id != tutorial_id:
		_skip_confirmation_tutorial_id = tutorial_id
		skip_tutorial_button.text = "确认跳过教学"
		feedback_label.text = "再次点击确认；跳过后不增加熟练度。"
		return
	var result: Dictionary = _session.call("skip_active_area_tutorial")
	_show_result(&"global", result)
	if bool(result.get("success", false)):
		order_finished.emit(result.duplicate(true))
	_refresh()


func _on_session_changed(_value: Variant = null) -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	if _session == null or not _session.has_method("active_formal_order"):
		order_summary_label.text = "当前没有可用的游戏会话。"
		return
	var progression: Dictionary = _session.call("five_area_progression_snapshot")
	var inventory: Dictionary = _session.call("inventory_snapshot")
	var order: Dictionary = _session.call("active_formal_order")
	var order_id := StringName(order.get("order_id", &""))
	if order_id != _displayed_order_id:
		_displayed_order_id = order_id
		_refusal_confirmation_order_id = &""
		_skip_confirmation_tutorial_id = &""
		refuse_button.text = "婉拒订单"
		skip_tutorial_button.text = "跳过教学"
	var items: Array = Array(order.get("items", []))
	if _selected_item_index >= items.size():
		_selected_item_index = 0
	var selected_item := Dictionary(items[_selected_item_index]) if _selected_item_index >= 0 and _selected_item_index < items.size() else {}
	if order_id.is_empty():
		order_summary_label.text = "当前订单：无"
	elif bool(order.get("tutorial_no_countdown", false)) or not StringName(order.get("teaching_area_id", &"")).is_empty():
		order_summary_label.text = "当前订单：%s · 教学单·不限时" % order_id
	else:
		var remaining := float(order.get("remaining_patience_seconds", 0.0))
		var total := maxf(float(order.get("patience_seconds", 0.0)), 0.1)
		order_summary_label.text = "当前订单：%s · 耐心 %.1f/%.1f 秒" % [order_id, remaining, total]
	for index in range(_item_buttons.size()):
		var button := _item_buttons[index]
		if index >= items.size():
			button.visible = false
			continue
		button.visible = true
		var item := Dictionary(items[index])
		button.text = "%s%s" % [_item_label(item), "  ✓" if Array(item.get("prepared_product_instance_ids", [])).size() >= int(item.get("quantity", 1)) else ""]
		button.button_pressed = index == _selected_item_index
		button.disabled = not _interaction_enabled
	settle_button.disabled = not _interaction_enabled or order_id.is_empty()
	refuse_button.disabled = not _interaction_enabled or order_id.is_empty()
	var teaching_area_id := StringName(order.get("teaching_area_id", &""))
	skip_tutorial_button.visible = not teaching_area_id.is_empty()
	skip_tutorial_button.disabled = not _interaction_enabled or teaching_area_id.is_empty()
	var common := {
		"inventory": inventory,
		"order_id": order_id,
		"item_index": _selected_item_index if not selected_item.is_empty() else -1,
		"order_item": selected_item,
	}
	var drink_snapshot := common.duplicate(true)
	drink_snapshot["machine"] = _session.call("f3_machine_snapshot", &"device.packaged_drink_heater")
	drink_snapshot["unlocked_product_ids"] = progression.get("unlocked_product_ids", [])
	var mastery_by_area: Dictionary = Dictionary(progression.get("area_mastery_details", {}))
	drink_snapshot["mastery"] = Dictionary(mastery_by_area.get(
		&"area.packaged_drink",
		mastery_by_area.get("area.packaged_drink", {}),
	)).duplicate(true)
	drink_station.apply_snapshot(drink_snapshot)
	var drink_owned := Array(progression.get("unlocked_area_ids", [])).has("area.packaged_drink")
	drink_station.set_locked(not drink_owned, "成品饮品柜尚未解锁；按成长路径购买后次日生效。")
	var youtiao_snapshot := common.duplicate(true)
	youtiao_snapshot["machine"] = _session.call("f3_machine_snapshot", &"device.youtiao_fryer")
	youtiao_snapshot["unlocked_recipe_ids"] = progression.get("unlocked_recipe_ids", [])
	youtiao_snapshot["owned_assist_ids"] = progression.get("owned_assist_ids", [])
	youtiao_station.apply_snapshot(youtiao_snapshot)
	var youtiao_owned := Array(progression.get("unlocked_area_ids", [])).has("area.youtiao")
	youtiao_station.set_locked(not youtiao_owned, "油条炸锅尚未解锁；先完成饮品教学与正确温度订单。")


func _show_result(source: StringName, result: Dictionary) -> void:
	var message := _reason_text(StringName(result.get("reason", &"operation_failed")))
	if bool(result.get("success", false)):
		match StringName(result.get("terminal_state", &"")):
			&"refused": message = "订单已婉拒 · 口碑 %d" % int(result.get("reputation_delta", -1))
			&"expired": message = "顾客耐心耗尽 · 口碑 -2"
			_:
				message = "订单完成 · 金币 +%d · 口碑 %+d" % [int(result.get("earned_coins", 0)), int(result.get("reputation_delta", 0))] if result.has("earned_coins") else "操作成功"
	feedback_label.text = message
	if source == &"drink":
		drink_station.show_feedback(message)
	elif source == &"youtiao":
		youtiao_station.show_feedback(message)


static func _item_label(item: Dictionary) -> String:
	var product_id := StringName(item.get("product_id", &""))
	var label := str(product_id)
	match product_id:
		&"product.packaged_drink.milk": label = "纯牛奶"
		&"product.packaged_drink.soy_milk": label = "成品豆奶"
		&"product.packaged_drink.walnut": label = "核桃乳"
		&"product.packaged_drink.black_sesame": label = "黑芝麻乳"
		&"product.youtiao.plain": label = "原味油条"
		&"product.youtiao.oil_cake": label = "油饼"
		&"product.youtiao.sugar_oil_cake": label = "糖油饼"
	var temperature := StringName(item.get("temperature_mode", &"room_temperature"))
	return "%s · %s" % [label, "加热" if temperature == &"heated" else "常温"]


static func _reason_text(reason: StringName) -> String:
	match reason:
		&"order_item_mismatch": return "与当前订单项不匹配，商品仍保留在原处。"
		&"insufficient_stock": return "库存不足，请先按住补货。"
		&"product_locked", &"recipe_locked": return "该商品尚未解锁。"
		&"slot_occupied": return "该加热位仍被占用。"
		&"drink_still_heating": return "饮品仍在加热。"
		&"drink_cooled": return "饮品已经冷却，只能报废。"
		&"missing_order_item": return "订单内容尚未全部交付。"
		&"order_not_active": return "当前没有可接收商品的活动订单。"
		&"batch_not_loaded": return "先装入面胚再启动。"
		&"lift_not_available": return "尚未熟成，当前不能升篮。"
		&"product_not_ready": return "油条尚未完成离油。"
		&"discard_not_available": return "当前状态不能报废。"
		&"insufficient_coins": return "金币不足，补货未完成。"
		&"tutorial_not_active": return "当前没有可跳过的区域教学。"
		&"stock_refusal": return "订单已婉拒。"
		&"patience_expired": return "顾客耐心耗尽，订单失败。"
	return "操作未完成：%s" % reason
