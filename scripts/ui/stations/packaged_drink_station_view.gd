class_name PackagedDrinkStationView
extends PanelContainer

signal intent_requested(intent: Dictionary)

const PRODUCT_IDS: Array[StringName] = [
	&"product.packaged_drink.milk",
	&"product.packaged_drink.soy_milk",
	&"product.packaged_drink.walnut",
	&"product.packaged_drink.black_sesame",
]
const PRODUCT_STOCK_IDS := {
	&"product.packaged_drink.milk": &"stock.packaged_drink.milk",
	&"product.packaged_drink.soy_milk": &"stock.packaged_drink.soy_milk",
	&"product.packaged_drink.walnut": &"stock.packaged_drink.walnut",
	&"product.packaged_drink.black_sesame": &"stock.packaged_drink.black_sesame",
}

@onready var tier_label: Label = %TierLabel
@onready var mastery_label: Label = %MasteryLabel
@onready var order_label: Label = %OrderLabel
@onready var selection_label: Label = %SelectionLabel
@onready var feedback_label: Label = %FeedbackLabel
@onready var lock_overlay: PanelContainer = %LockOverlay
@onready var lock_label: Label = %LockLabel
@onready var restock_button: Button = %RestockButton

var _product_buttons: Array[Button] = []
var _slot_buttons: Array[Button] = []
var _snapshot: Dictionary = {}
var _selected_product_id: StringName = &""
var _order_id: StringName = &""
var _item_index := -1
var _interaction_enabled := true
var _locked := true
var _restock_held := false


func _ready() -> void:
	_product_buttons = [%MilkButton, %SoyMilkButton, %WalnutButton, %BlackSesameButton]
	_slot_buttons = [%HeaterSlot1, %HeaterSlot2, %HeaterSlot3, %HeaterSlot4]
	for index in range(_product_buttons.size()):
		_product_buttons[index].pressed.connect(_on_product_pressed.bind(PRODUCT_IDS[index]))
	for index in range(_slot_buttons.size()):
		_slot_buttons[index].pressed.connect(_on_slot_pressed.bind(index))
	restock_button.button_down.connect(_set_restock_held.bind(true))
	restock_button.button_up.connect(_set_restock_held.bind(false))
	restock_button.mouse_exited.connect(_set_restock_held.bind(false))
	set_process(true)
	_refresh()


func _process(delta: float) -> void:
	if not _restock_held or _locked or not _interaction_enabled or _selected_product_id.is_empty():
		return
	intent_requested.emit({"type": &"restock_hold", "stock_id": PRODUCT_STOCK_IDS.get(_selected_product_id, &""), "delta": maxf(delta, 0.0)})


func apply_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	_order_id = StringName(snapshot.get("order_id", &""))
	_item_index = int(snapshot.get("item_index", -1))
	_refresh()


func set_locked(locked: bool, reason_text: String) -> void:
	_locked = locked
	lock_overlay.visible = locked
	lock_label.text = reason_text if not reason_text.is_empty() else "成品饮品柜尚未解锁"
	_refresh_interaction()


func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	if not enabled:
		_restock_held = false
	_refresh_interaction()


func _on_product_pressed(product_id: StringName) -> void:
	_selected_product_id = product_id
	var item := Dictionary(_snapshot.get("order_item", {}))
	var temperature_mode := StringName(item.get("temperature_mode", &"room_temperature"))
	selection_label.text = "已选：%s" % _product_label(product_id)
	if _order_id.is_empty() or _item_index < 0:
		feedback_label.text = "请先选择当前订单中的饮品项。"
		return
	if temperature_mode == &"heated":
		feedback_label.text = "订单要求加热：请点击一个空加热位。"
		return
	intent_requested.emit({"type": &"deliver_room_temperature_drink", "order_id": _order_id, "item_index": _item_index, "product_id": product_id})


func _on_slot_pressed(slot_index: int) -> void:
	var machine := Dictionary(_snapshot.get("machine", {}))
	var slots: Array = Array(machine.get("slots", []))
	if slot_index < 0 or slot_index >= slots.size():
		return
	var state := StringName(Dictionary(slots[slot_index]).get("state", &"locked"))
	match state:
		&"empty":
			if _selected_product_id.is_empty():
				feedback_label.text = "先选择一种需要加热的饮品。"
				return
			intent_requested.emit({"type": &"load_drink", "slot_index": slot_index, "product_id": _selected_product_id, "order_id": _order_id})
		&"ready_hot":
			if _order_id.is_empty() or _item_index < 0:
				feedback_label.text = "热饮已完成；选择匹配订单项后再取出。"
				return
			intent_requested.emit({"type": &"deliver_heated_drink", "slot_index": slot_index, "order_id": _order_id, "item_index": _item_index})
		&"cooled":
			intent_requested.emit({"type": &"discard_drink", "slot_index": slot_index})
		&"heating":
			feedback_label.text = "该位置正在加热，完成后再点击交付。"
		_:
			feedback_label.text = "该加热位尚未开放。"


func _refresh() -> void:
	if not is_node_ready():
		return
	var machine := Dictionary(_snapshot.get("machine", {}))
	var inventory := Dictionary(_snapshot.get("inventory", {}))
	var unlocked_products := PackedStringArray(Array(_snapshot.get("unlocked_product_ids", [])))
	var tier := int(machine.get("tier", 0))
	tier_label.text = ["基础 · 1位 / 2秒", "中级 · 2位 / 1秒", "高级 · 4位 / 持续保温"][clampi(tier, 0, 2)]
	var mastery: Dictionary = Dictionary(_snapshot.get("mastery", {}))
	mastery_label.text = "熟练度 · 正确温度 %d · 当前连对 %d · 最高连对 %d" % [
		int(mastery.get("correct_temperature", 0)),
		int(mastery.get("correct_streak_current", 0)),
		int(mastery.get("correct_streak_best", 0)),
	]
	var item := Dictionary(_snapshot.get("order_item", {}))
	if item.is_empty():
		order_label.text = "当前订单项：未选择"
	else:
		order_label.text = "当前订单项：%s · %s" % [_product_label(StringName(item.get("product_id", &""))), "需要加热" if StringName(item.get("temperature_mode", &"room_temperature")) == &"heated" else "常温"]
	for index in range(_product_buttons.size()):
		var product_id := PRODUCT_IDS[index]
		var stock_id: StringName = PRODUCT_STOCK_IDS[product_id]
		var unlocked := unlocked_products.has(str(product_id))
		_product_buttons[index].text = "%s\n库存 %d%s" % [_product_label(product_id), int(inventory.get(str(stock_id), 0)), "" if unlocked else " · 未解锁"]
		_product_buttons[index].disabled = _locked or not _interaction_enabled or not unlocked
	var slots: Array = Array(machine.get("slots", []))
	for slot_index in range(_slot_buttons.size()):
		var slot := Dictionary(slots[slot_index]) if slot_index < slots.size() else {"state": &"locked"}
		_slot_buttons[slot_index].text = "加热位 %d\n%s" % [slot_index + 1, _slot_status_text(slot)]
	_refresh_interaction()


func _refresh_interaction() -> void:
	if not is_node_ready():
		return
	var disabled := _locked or not _interaction_enabled
	var slots: Array = Array(Dictionary(_snapshot.get("machine", {})).get("slots", []))
	for slot_index in range(_slot_buttons.size()):
		var state := StringName(Dictionary(slots[slot_index]).get("state", &"locked")) if slot_index < slots.size() else &"locked"
		_slot_buttons[slot_index].disabled = disabled or state == &"locked"
	restock_button.disabled = disabled or _selected_product_id.is_empty()


func show_feedback(message: String) -> void:
	feedback_label.text = message


func _set_restock_held(value: bool) -> void:
	_restock_held = value


static func _product_label(product_id: StringName) -> String:
	match product_id:
		&"product.packaged_drink.milk": return "纯牛奶"
		&"product.packaged_drink.soy_milk": return "成品豆奶"
		&"product.packaged_drink.walnut": return "核桃乳"
		&"product.packaged_drink.black_sesame": return "黑芝麻乳"
	return "未知饮品"


static func _slot_status_text(slot: Dictionary) -> String:
	var product_name := _product_label(StringName(slot.get("product_id", &"")))
	match StringName(slot.get("state", &"locked")):
		&"empty": return "空位 · 点击装入"
		&"heating": return "%s · 加热 %.1f秒" % [product_name, float(slot.get("elapsed_seconds", 0.0))]
		&"ready_hot": return "%s · 热饮完成 · 点击交付" % product_name
		&"cooled": return "%s · 已冷却 · 点击报废" % product_name
	return "未开放"
