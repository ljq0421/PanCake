class_name NoodleShopWorkstation
extends Control

signal daily_bill_closed

const CATALOG := preload("res://scripts/data/noodle_shop_catalog.gd")
const PORTRAIT_CATALOG := preload("res://scripts/ui/customer_portrait_catalog.gd")

@onready var gesture_surface: NoodleGestureSurface = %GestureSurface
@onready var portrait: TextureRect = %CustomerPortrait
@onready var order_title: Label = %OrderTitle
@onready var order_details: Label = %OrderDetails
@onready var timer_label: Label = %TimerLabel
@onready var economy_label: Label = %EconomyLabel
@onready var status_label: Label = %StatusLabel
@onready var batch_label: Label = %BatchLabel
@onready var refuse_button: Button = %RefuseButton
@onready var begin_button: Button = %BeginButton
@onready var lift_button: Button = %LiftButton
@onready var return_button: Button = %ReturnButton
@onready var bowl_button: Button = %BowlButton
@onready var serve_button: Button = %ServeButton
@onready var discard_button: Button = %DiscardButton
@onready var collect_button: Button = %CollectButton
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_title: Label = %ResultTitle
@onready var result_details: Label = %ResultDetails
@onready var result_close_button: Button = %ResultCloseButton
@onready var end_day_button: Button = %EndDayButton
@onready var day_panel: PanelContainer = %DayPanel
@onready var day_summary: Label = %DaySummary
@onready var next_day_button: Button = %NextDayButton
@onready var day_menu_button: Button = %DayMenuButton
@onready var tomato_restock_button: Button = %TomatoRestockButton
@onready var zhajiang_restock_button: Button = %ZhajiangRestockButton
@onready var growth_buttons: Array[Button] = [%GrowthTomato, %GrowthKnife, %GrowthZhajiang, %GrowthBasket]
@onready var knife_audio: AudioStreamPlayer = %KnifeAudio
@onready var basket_audio: AudioStreamPlayer = %BasketAudio
@onready var serve_audio: AudioStreamPlayer = %ServeAudio
@onready var payment_audio: AudioStreamPlayer = %PaymentAudio
@onready var patience_audio: AudioStreamPlayer = %PatienceAudio

var _session: Node
var _portraits: RefCounted = PORTRAIT_CATALOG.new()
var _refresh_elapsed := 0.0


func _ready() -> void:
	_session = get_node_or_null("/root/GameSession")
	if _session == null:
		push_error("GameSession autoload is required by the noodle shop")
		return
	gesture_surface.stroke_completed.connect(_on_stroke_completed)
	begin_button.pressed.connect(_begin_recipe)
	lift_button.pressed.connect(_lift_basket)
	return_button.pressed.connect(_return_to_pot)
	bowl_button.pressed.connect(_transfer_to_bowl)
	serve_button.pressed.connect(_serve_bowl)
	discard_button.pressed.connect(_discard_bowl)
	refuse_button.pressed.connect(_refuse_order)
	collect_button.pressed.connect(_collect_payment)
	result_close_button.pressed.connect(func(): result_panel.visible = false)
	end_day_button.pressed.connect(end_business_day_early)
	next_day_button.pressed.connect(_begin_next_day)
	day_menu_button.pressed.connect(func(): daily_bill_closed.emit())
	tomato_restock_button.pressed.connect(func(): _restock(CATALOG.STOCK_TOMATO))
	zhajiang_restock_button.pressed.connect(func(): _restock(CATALOG.STOCK_ZHAJIANG))
	for index in range(growth_buttons.size()):
		var growth_id := CATALOG.GROWTH_DISPLAY_ORDER[index]
		growth_buttons[index].pressed.connect(func(): _purchase_growth(growth_id))
	%ClearBrothButton.pressed.connect(func(): _set_broth(&"broth.clear"))
	%TomatoBrothButton.pressed.connect(func(): _set_broth(&"broth.tomato"))
	%NoBrothButton.pressed.connect(func(): _set_broth(&"broth.none"))
	%ScallionButton.pressed.connect(func(): _add_topping(&"topping.scallion"))
	%TomatoToppingButton.pressed.connect(func(): _add_topping(&"topping.tomato_egg"))
	%ZhajiangButton.pressed.connect(func(): _add_topping(&"topping.zhajiang"))
	%CucumberButton.pressed.connect(func(): _add_topping(&"topping.cucumber"))
	result_panel.visible = false
	day_panel.visible = false
	_session.call("set_business_paused", false)
	_session.call("noodle_ensure_active_order")
	_refresh(true)


func _process(delta: float) -> void:
	if _session == null or get_tree().paused:
		return
	var advanced := Dictionary(_session.call("noodle_advance", delta))
	if bool(advanced.get("customer_left_now", false)):
		status_label.text = "顾客等不及离开了，口碑 -2。"
		patience_audio.play()
		if not bool(advanced.get("expired_now", false)):
			_session.call("noodle_ensure_active_order")
	if bool(advanced.get("expired_now", false)):
		_show_day_bill(Dictionary(advanced.get("bill", {})))
	_refresh_elapsed += delta
	if _refresh_elapsed >= 0.08:
		_refresh_elapsed = 0.0
		_refresh(false)


func end_business_day_early() -> void:
	if _session == null:
		return
	_show_day_bill(Dictionary(_session.call("noodle_end_day", &"manual")))


func is_blocking_modal_open() -> bool:
	return day_panel.visible or result_panel.visible


func _on_stroke_completed(distance: float, duration: float) -> void:
	var result := Dictionary(_session.call("noodle_record_stroke", distance, duration))
	if bool(result.get("success", false)):
		var batch := Dictionary(result.get("batch", {}))
		status_label.text = "第 %d 刀 · %s · %.0f px/s" % [int(result.get("batch_count", 0)), _profile_label(StringName(batch.get("thickness_id", &"standard"))), float(batch.get("speed", 0.0))]
		knife_audio.play()
	else:
		status_label.text = _reason_text(StringName(result.get("reason", &"")))
	_refresh(true)


func _begin_recipe() -> void:
	var result := Dictionary(_session.call("noodle_begin_active_recipe"))
	status_label.text = "开始削面，保持每刀节奏稳定。" if bool(result.get("success", false)) else _reason_text(StringName(result.get("reason", &"")))
	_refresh(true)


func _lift_basket() -> void:
	var result := Dictionary(_session.call("noodle_lift_basket"))
	status_label.text = "面篮已提起，观察沥水时间。" if bool(result.get("success", false)) else _reason_text(StringName(result.get("reason", &"")))
	if bool(result.get("success", false)):
		basket_audio.play()
	_refresh(true)


func _return_to_pot() -> void:
	var result := Dictionary(_session.call("noodle_return_basket_to_pot"))
	status_label.text = "回锅补煮会限制熟度最高分。" if bool(result.get("success", false)) else _reason_text(StringName(result.get("reason", &"")))
	_refresh(true)


func _transfer_to_bowl() -> void:
	var result := Dictionary(_session.call("noodle_transfer_to_bowl"))
	status_label.text = "已入碗，请选择汤底和浇头。" if bool(result.get("success", false)) else _reason_text(StringName(result.get("reason", &"")))
	_refresh(true)


func _set_broth(broth_id: StringName) -> void:
	var result := Dictionary(_session.call("noodle_set_broth", broth_id))
	status_label.text = "汤底已加入。" if bool(result.get("success", false)) else _reason_text(StringName(result.get("reason", &"")))
	_refresh(true)


func _add_topping(topping_id: StringName) -> void:
	var result := Dictionary(_session.call("noodle_add_topping", topping_id))
	status_label.text = "浇头已加入。" if bool(result.get("success", false)) else _reason_text(StringName(result.get("reason", &"")))
	_refresh(true)


func _serve_bowl() -> void:
	var result := Dictionary(_session.call("noodle_serve_bowl"))
	if not bool(result.get("success", false)):
		status_label.text = _reason_text(StringName(result.get("reason", &"")))
		return
	var score := Dictionary(result.get("score", {}))
	result_title.text = "%s · %.0f 分" % [str(result.get("grade", "D")), float(score.get("overall_score", 0.0))]
	result_details.text = "%s\n刀工 %.0f  ·  熟度 %.0f  ·  粗细 %.0f  ·  配方 %.0f\n待收款：%d 金币" % [
		str(score.get("feedback", "")),
		float(score.get("blade_score", 0.0)),
		float(score.get("doneness_score", 0.0)),
		float(score.get("profile_score", 0.0)),
		float(score.get("recipe_score", 0.0)),
		int(result.get("payment_coins", 0)),
	]
	result_panel.visible = true
	serve_audio.play()
	_refresh(true)


func _collect_payment() -> void:
	var result := Dictionary(_session.call("noodle_collect_payment"))
	if bool(result.get("success", false)):
		status_label.text = "收下 %d 金币。" % int(result.get("collected_coins", 0))
		payment_audio.play()
		result_panel.visible = false
		_session.call("noodle_ensure_active_order")
	else:
		status_label.text = _reason_text(StringName(result.get("reason", &"")))
	_refresh(true)


func _refuse_order() -> void:
	var result := Dictionary(_session.call("noodle_refuse_order"))
	if bool(result.get("success", false)):
		status_label.text = "已谢绝订单，口碑 %+d。" % int(result.get("reputation_delta", 0))
		_session.call("noodle_ensure_active_order")
	else:
		status_label.text = _reason_text(StringName(result.get("reason", &"")))
	_refresh(true)


func _discard_bowl() -> void:
	var result := Dictionary(_session.call("noodle_discard_bowl"))
	status_label.text = "这碗面已废弃，请重新制作。" if bool(result.get("success", false)) else _reason_text(StringName(result.get("reason", &"")))
	_refresh(true)


func _restock(stock_id: StringName) -> void:
	var result := Dictionary(_session.call("noodle_restock", stock_id))
	status_label.text = "补货完成。" if bool(result.get("success", false)) else _reason_text(StringName(result.get("reason", &"")))
	_refresh(true)


func _purchase_growth(growth_id: StringName) -> void:
	var result := Dictionary(_session.call("noodle_purchase_growth", growth_id))
	status_label.text = "已购买，下一营业日生效。" if bool(result.get("success", false)) else _reason_text(StringName(result.get("reason", &"")))
	_refresh(true)


func _begin_next_day() -> void:
	var result := Dictionary(_session.call("noodle_begin_next_day"))
	if bool(result.get("success", false)):
		day_panel.visible = false
		_session.call("set_business_paused", false)
		_session.call("noodle_ensure_active_order")
		status_label.text = "新一天开门，先检查浇头库存。"
	_refresh(true)


func _show_day_bill(bill: Dictionary) -> void:
	day_summary.text = "第 %d 日结束\n完成 %d 单 · 营收 %d 金币 · 口碑 %+d\n购买成长后，下一营业日生效。" % [
		int(bill.get("day", 1)),
		int(bill.get("orders_completed", 0)),
		int(bill.get("revenue", 0)),
		int(bill.get("reputation_delta", 0)),
	]
	day_panel.visible = true
	result_panel.visible = false
	_refresh(true)


func _refresh(force_portrait: bool) -> void:
	if _session == null:
		return
	var shop := Dictionary(_session.call("noodle_shop_snapshot"))
	var order := Dictionary(shop.get("active_order", {}))
	var production := Dictionary(shop.get("production", {}))
	gesture_surface.set_production_snapshot(production)
	var recipe := CATALOG.recipe(StringName(order.get("recipe_id", production.get("recipe_id", CATALOG.RECIPE_CLEAR))))
	order_title.text = "等待下一位顾客" if order.is_empty() else str(order.get("title", "刀削面"))
	order_details.text = "收款后迎接下一位顾客" if order.is_empty() else "%s · 目标6刀\n汤底：%s · 浇头：%s%s" % [
		_profile_label(StringName(order.get("noodle_profile_id", &"standard"))),
		_broth_label(StringName(order.get("broth_id", &""))),
		"、".join(Array(order.get("topping_ids", [])).map(func(value): return _topping_label(StringName(value)))),
		"\n教学单不限时" if bool(order.get("tutorial_no_countdown", false)) else "\n耐心：%.0f 秒" % float(order.get("remaining_patience_seconds", 0.0)),
	]
	timer_label.text = "教学不限时" if not bool(shop.get("tutorial_completed", false)) else "%02d:%02d" % [floori(float(shop.get("remaining_seconds", 0.0)) / 60.0), int(shop.get("remaining_seconds", 0.0)) % 60]
	economy_label.text = "面馆金币 %d  ·  全局口碑 %d  ·  第 %d 日" % [int(shop.get("coins", 0)), int(_session.call("global_reputation")), int(shop.get("current_day", 1))]
	batch_label.text = "已削 %d/6 刀 · 沥水 %.1f 秒" % [Array(production.get("batches", [])).size(), float(production.get("drain_seconds", 0.0))]
	var state := StringName(production.get("state", &"idle"))
	begin_button.disabled = order.is_empty() or state != &"idle"
	lift_button.disabled = state not in [&"shaving", &"cooking"] or Array(production.get("batches", [])).size() < CATALOG.MIN_LIFT_BATCH_COUNT
	return_button.disabled = state != &"lifted"
	bowl_button.disabled = state != &"lifted"
	serve_button.disabled = state != &"bowled"
	discard_button.disabled = state == &"idle"
	refuse_button.disabled = order.is_empty() or bool(order.get("tutorial_no_countdown", false))
	collect_button.visible = not Dictionary(shop.get("pending_payment", {})).is_empty()
	collect_button.text = "点击收款  +%d" % int(Dictionary(shop.get("pending_payment", {})).get("coins", 0))
	var unlocked := Array(shop.get("unlocked_recipe_ids", []))
	var inv := Dictionary(shop.get("inventory", {}))
	tomato_restock_button.visible = unlocked.has(CATALOG.RECIPE_TOMATO) or unlocked.has(str(CATALOG.RECIPE_TOMATO))
	zhajiang_restock_button.visible = unlocked.has(CATALOG.RECIPE_ZHAJIANG) or unlocked.has(str(CATALOG.RECIPE_ZHAJIANG))
	tomato_restock_button.text = "补番茄鸡蛋 %d/6（2币）" % int(inv.get(str(CATALOG.STOCK_TOMATO), 0))
	zhajiang_restock_button.text = "补炸酱 %d/6（3币）" % int(inv.get(str(CATALOG.STOCK_ZHAJIANG), 0))
	var overview := Array(_session.call("noodle_growth_overview"))
	for index in range(growth_buttons.size()):
		if index >= overview.size():
			continue
		var growth := Dictionary(overview[index])
		growth_buttons[index].text = "%s · %d币%s" % [str(growth.get("label", "成长")), int(growth.get("price", 0)), "（已拥有）" if bool(growth.get("owned", false)) else "（待生效）" if bool(growth.get("pending", false)) else ""]
		growth_buttons[index].disabled = bool(growth.get("owned", false)) or bool(growth.get("pending", false))
	day_panel.visible = day_panel.visible or not bool(shop.get("day_open", true))
	end_day_button.disabled = not bool(shop.get("day_open", true))
	if force_portrait and not order.is_empty():
		portrait.texture = _portraits.call("texture_for", StringName(order.get("customer_id", &"customer_01")), &"neutral")


static func _profile_label(profile: StringName) -> String:
	return {&"thin": "薄面 · 快刀", &"standard": "标准面 · 稳刀", &"thick": "厚面 · 慢刀"}.get(profile, "标准面")


static func _broth_label(id: StringName) -> String:
	return {&"broth.clear": "清汤", &"broth.tomato": "番茄汤", &"broth.none": "无汤"}.get(id, "未选择")


static func _topping_label(id: StringName) -> String:
	return {&"topping.scallion": "葱花", &"topping.tomato_egg": "番茄鸡蛋", &"topping.zhajiang": "炸酱", &"topping.cucumber": "黄瓜丝"}.get(id, str(id))


static func _reason_text(reason: StringName) -> String:
	return {
		&"stroke_too_short": "这一刀太短，请从面团完整划向锅口。",
		&"basket_not_in_pot": "请先开始制作或把面篮放回锅里。",
		&"too_few_batches": "至少削4刀才能提篮。",
		&"insufficient_stock": "浇头缺货，请先补货。",
		&"stock_full": "库存已经装满。",
		&"insufficient_coins": "金币不足。",
		&"bowl_already_mixed": "浇头已经混合，不能再换汤底。",
		&"no_pending_payment": "当前没有待收款。",
		&"tutorial_order_cannot_be_refused": "教学单不能谢绝，请先完成这一碗。",
		&"no_production": "当前没有可废弃的面。",
		&"business_day_open": "请先结束营业日。",
		&"missing_prerequisite": "前置配方尚未购买。",
	}.get(reason, "当前操作还不能进行。")
