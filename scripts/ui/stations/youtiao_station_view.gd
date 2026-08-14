class_name YoutiaoStationView
extends PanelContainer

signal intent_requested(intent: Dictionary)

const RECIPE_IDS: Array[StringName] = [
	&"recipe.youtiao.plain",
]
const RECIPE_STOCK_IDS := {
	&"recipe.youtiao.plain": &"stock.youtiao.plain_dough",
}

@onready var tier_label: Label = %TierLabel
@onready var order_label: Label = %OrderLabel
@onready var state_label: Label = %StateLabel
@onready var quality_label: Label = %QualityLabel
@onready var quantity_label: Label = %QuantityLabel
@onready var feedback_label: Label = %FeedbackLabel
@onready var lock_overlay: PanelContainer = %LockOverlay
@onready var lock_label: Label = %LockLabel
@onready var load_button: Button = %LoadButton
@onready var start_button: Button = %StartButton
@onready var lift_button: Button = %LiftButton
@onready var auto_lift_toggle: CheckButton = %AutoLiftToggle
@onready var collect_button: Button = %CollectButton
@onready var discard_button: Button = %DiscardButton
@onready var restock_button: Button = %RestockButton

var _recipe_buttons: Array[Button] = []
var _snapshot: Dictionary = {}
var _selected_recipe_id: StringName = &""
var _quantity := 1
var _order_id: StringName = &""
var _item_index := -1
var _locked := true
var _interaction_enabled := true
var _restock_held := false


func _ready() -> void:
	_recipe_buttons = [%PlainButton]
	for index in range(_recipe_buttons.size()):
		_recipe_buttons[index].pressed.connect(_select_recipe.bind(RECIPE_IDS[index]))
	%QuantityMinusButton.pressed.connect(_change_quantity.bind(-1))
	%QuantityPlusButton.pressed.connect(_change_quantity.bind(1))
	load_button.pressed.connect(_emit_load)
	start_button.pressed.connect(_emit_action.bind(&"start"))
	lift_button.pressed.connect(_emit_action.bind(&"lift"))
	auto_lift_toggle.toggled.connect(func(enabled: bool): intent_requested.emit({"type": &"set_youtiao_auto_lift", "enabled": enabled}))
	collect_button.pressed.connect(_emit_collect)
	discard_button.pressed.connect(func(): intent_requested.emit({"type": &"discard_youtiao"}))
	restock_button.button_down.connect(_set_restock_held.bind(true))
	restock_button.button_up.connect(_set_restock_held.bind(false))
	restock_button.mouse_exited.connect(_set_restock_held.bind(false))
	set_process(true)
	_refresh()


func _process(delta: float) -> void:
	if _restock_held and not _locked and _interaction_enabled and not _selected_recipe_id.is_empty():
		intent_requested.emit({"type": &"restock_hold", "stock_id": RECIPE_STOCK_IDS.get(_selected_recipe_id, &""), "delta": maxf(delta, 0.0)})


func apply_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	_order_id = StringName(snapshot.get("order_id", &""))
	_item_index = int(snapshot.get("item_index", -1))
	_refresh()


func set_locked(locked: bool, reason_text: String) -> void:
	_locked = locked
	lock_overlay.visible = locked
	lock_label.text = reason_text if not reason_text.is_empty() else "油条炸锅尚未解锁"
	_refresh()


func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	if not enabled:
		_restock_held = false
	_refresh()


func show_feedback(message: String) -> void:
	feedback_label.text = message


func _select_recipe(recipe_id: StringName) -> void:
	_selected_recipe_id = recipe_id
	feedback_label.text = "已选 %s；设定数量后装入炸锅。" % _recipe_label(recipe_id)
	_refresh()


func _change_quantity(delta: int) -> void:
	var capacity := maxi(int(Dictionary(_snapshot.get("machine", {})).get("capacity", 1)), 1)
	_quantity = clampi(_quantity + delta, 1, capacity)
	_refresh()


func _emit_load() -> void:
	if _selected_recipe_id.is_empty():
		feedback_label.text = "先选择一种面胚。"
		return
	intent_requested.emit({"type": &"load_youtiao", "recipe_id": _selected_recipe_id, "quantity": _quantity, "order_id": _order_id})


func _emit_action(action_id: StringName) -> void:
	intent_requested.emit({"type": &"youtiao_action", "action_id": action_id})


func _emit_collect() -> void:
	if StringName(Dictionary(_snapshot.get("machine", {})).get("state", &"")) == &"ready_to_collect":
		intent_requested.emit({"type": &"store_youtiao_batch", "slot_id": &"slot.04"})
		return
	if _order_id.is_empty() or _item_index < 0:
		feedback_label.text = "选择当前订单中的油条项后再逐根装配。"
		return
	intent_requested.emit({"type": &"deliver_youtiao", "order_id": _order_id, "item_index": _item_index})


func _refresh() -> void:
	if not is_node_ready():
		return
	var machine := Dictionary(_snapshot.get("machine", {}))
	var inventory := Dictionary(_snapshot.get("inventory", {}))
	var unlocked_recipes := PackedStringArray(Array(_snapshot.get("unlocked_recipe_ids", [])))
	var tier := clampi(int(machine.get("tier", 0)), 0, 2)
	tier_label.text = ["基础 · 4份 / 10秒", "中级 · 6份 / 8秒", "高级 · 8份 / 6秒"][tier]
	var item := Dictionary(_snapshot.get("order_item", {}))
	order_label.text = "当前订单项：未选择" if item.is_empty() else "当前订单项：%s" % _product_label(StringName(item.get("product_id", &"")))
	var state := StringName(machine.get("state", &"unowned"))
	var prepared_count := int(Dictionary(_snapshot.get("prepared_slot", {})).get("count", 0))
	state_label.text = "炸锅状态：%s" % _state_text(state)
	quality_label.text = "当前品质：%d · 成品区 %d/%d · %s" % [roundi(float(machine.get("quality", 100.0))), prepared_count, int(Dictionary(_snapshot.get("prepared_slot", {})).get("capacity", 4)), _warning_text(machine)]
	var automation_ids := Array(_snapshot.get("unlocked_automation_ids", []))
	var owns_auto_lift := automation_ids.has("automation.youtiao.auto_lift") or automation_ids.has(&"automation.youtiao.auto_lift")
	auto_lift_toggle.visible = owns_auto_lift
	auto_lift_toggle.set_pressed_no_signal(owns_auto_lift and bool(machine.get("auto_lift_enabled", false)))
	auto_lift_toggle.text = "自动升篮：开" if auto_lift_toggle.button_pressed else "自动升篮：关"
	quantity_label.text = "装入数量：%d" % _quantity
	for index in range(_recipe_buttons.size()):
		var recipe_id := RECIPE_IDS[index]
		var stock_id: StringName = RECIPE_STOCK_IDS[recipe_id]
		var unlocked := unlocked_recipes.has(str(recipe_id))
		_recipe_buttons[index].text = "%s\n面胚 %d%s" % [_recipe_label(recipe_id), int(inventory.get(str(stock_id), 0)), "" if unlocked else " · 未解锁"]
		_recipe_buttons[index].disabled = _locked or not _interaction_enabled or not unlocked
	_refresh_interaction()


func _refresh_interaction() -> void:
	if not is_node_ready():
		return
	var disabled := _locked or not _interaction_enabled
	var state := StringName(Dictionary(_snapshot.get("machine", {})).get("state", &"unowned"))
	var prepared_count := int(Dictionary(_snapshot.get("prepared_slot", {})).get("count", 0))
	load_button.disabled = disabled or _selected_recipe_id.is_empty() or state not in [&"idle", &"loaded"]
	start_button.disabled = disabled or state != &"loaded"
	lift_button.disabled = disabled or state not in [&"ready_safe", &"overcooking"]
	collect_button.text = "整锅收纳" if state == &"ready_to_collect" else "逐根装配订单"
	collect_button.disabled = disabled or (state != &"ready_to_collect" and (prepared_count <= 0 or _order_id.is_empty() or _item_index < 0))
	discard_button.disabled = disabled or state != &"burnt"
	restock_button.disabled = disabled or _selected_recipe_id.is_empty()
	%QuantityMinusButton.disabled = disabled or _quantity <= 1
	%QuantityPlusButton.disabled = disabled or _quantity >= maxi(int(Dictionary(_snapshot.get("machine", {})).get("capacity", 1)), 1)


func _set_restock_held(value: bool) -> void:
	_restock_held = value


static func _recipe_label(recipe_id: StringName) -> String:
	match recipe_id:
		&"recipe.youtiao.plain": return "油条"
	return "未知面胚"


static func _product_label(product_id: StringName) -> String:
	return _recipe_label(StringName(str(product_id).replace("product.", "recipe.")))


static func _state_text(state: StringName) -> String:
	match state:
		&"idle": return "空闲"
		&"loaded": return "已装料 · 等待启动"
		&"frying": return "炸制中"
		&"ready_safe": return "熟成安全期 · 可升篮"
		&"overcooking": return "正在过火 · 立即升篮"
		&"draining": return "离油中"
		&"ready_to_collect": return "可取出"
		&"burnt": return "整批焦糊 · 只能报废"
	return "未开放"


static func _warning_text(machine: Dictionary) -> String:
	match StringName(machine.get("state", &"")):
		&"ready_safe": return "红色预警：安全期倒计时"
		&"overcooking": return "红色预警：品质正在下降"
		&"burnt": return "不可交付"
		&"frying":
			var tier := int(machine.get("tier", 0))
			var duration: float = float([10.0, 8.0, 6.0][clampi(tier, 0, 2)])
			if duration - float(machine.get("cooking_elapsed_seconds", 0.0)) <= 3.0:
				return "黄色预警：即将熟成"
	return "状态正常"
