class_name F3StationController
extends Control

@onready var drink_station = %PackagedDrinkStation
@onready var youtiao_station = %YoutiaoStation
@onready var order_summary_label: Label = %OrderSummaryLabel
@onready var feedback_label: Label = %GlobalFeedbackLabel
@onready var settle_button: Button = %SettleOrderButton

var _session: Node
var _item_buttons: Array[Button] = []
var _selected_item_index := 0
var _interaction_enabled := true


func _ready() -> void:
	_session = get_node_or_null("/root/GameSession")
	_item_buttons = [%OrderItem1, %OrderItem2, %OrderItem3]
	for index in range(_item_buttons.size()):
		_item_buttons[index].pressed.connect(_select_order_item.bind(index))
	drink_station.intent_requested.connect(_on_station_intent.bind(&"drink"))
	youtiao_station.intent_requested.connect(_on_station_intent.bind(&"youtiao"))
	settle_button.pressed.connect(_settle_order)
	if _session != null:
		if _session.has_signal("production_changed"):
			_session.production_changed.connect(_on_session_changed)
		if _session.has_signal("inventory_changed"):
			_session.inventory_changed.connect(_on_session_changed)
		if _session.has_signal("progression_changed"):
			_session.progression_changed.connect(_on_session_changed)
	set_process(true)
	_refresh()


func _process(delta: float) -> void:
	if _session != null and _interaction_enabled and _session.has_method("advance_f3_production"):
		_session.call("advance_f3_production", delta)


func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	drink_station.set_interaction_enabled(enabled)
	youtiao_station.set_interaction_enabled(enabled)
	settle_button.disabled = not enabled


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
	var items: Array = Array(order.get("items", []))
	if _selected_item_index >= items.size():
		_selected_item_index = 0
	var selected_item := Dictionary(items[_selected_item_index]) if _selected_item_index >= 0 and _selected_item_index < items.size() else {}
	order_summary_label.text = "当前订单：无" if order_id.is_empty() else "当前订单：%s · 选择要交付的商品项" % order_id
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
	var common := {
		"inventory": inventory,
		"order_id": order_id,
		"item_index": _selected_item_index if not selected_item.is_empty() else -1,
		"order_item": selected_item,
	}
	var drink_snapshot := common.duplicate(true)
	drink_snapshot["machine"] = _session.call("f3_machine_snapshot", &"device.packaged_drink_heater")
	drink_snapshot["unlocked_product_ids"] = progression.get("unlocked_product_ids", [])
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
	var message := "操作成功" if bool(result.get("success", false)) else _reason_text(StringName(result.get("reason", &"operation_failed")))
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
	return "操作未完成：%s" % reason
