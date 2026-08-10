class_name FiveAreaWorkstation
extends "res://scripts/gameplay/workstation.gd"

const PRODUCT_VISUALS := preload("res://scripts/ui/five_area_product_visuals.gd")

@onready var five_area_infrastructure: Control = $FiveAreaInfrastructure
@onready var fresh_soy_station: DirectSoyStation = $FiveAreaInfrastructure/Stations/FreshSoyMilkStation
@onready var youtiao_station: DirectYoutiaoStation = $FiveAreaInfrastructure/Stations/YoutiaoStation
@onready var packaged_drink_station: DirectPackagedDrinkStation = $FiveAreaInfrastructure/Stations/PackagedDrinkStation
@onready var steamer_station: DirectSteamerStation = $FiveAreaInfrastructure/Stations/SteamerStation
@onready var customer_handoff_tray: CustomerHandoffTray = $FiveAreaInfrastructure/CustomerHandoffTray
@onready var pancake_ready_source: ProductDragSource = %PancakeReadySource
@onready var pancake_holding_sources: Array[ProductDragSource] = [%PancakeHoldingSource01, %PancakeHoldingSource02]
@onready var waste_area: StagedProductDropTarget = %WasteArea
@onready var tray_payment_button: Button = %TrayPaymentButton

var _ready_pancake_source_ref: Dictionary = {}
var _pending_tray_settlement: Dictionary = {}
var _refresh_elapsed := 0.0


func _ready() -> void:
	super._ready()
	for station in [fresh_soy_station, youtiao_station, packaged_drink_station, steamer_station]:
		station.status_message.connect(_show_station_status)
	customer_handoff_tray.status_message.connect(_show_station_status)
	customer_handoff_tray.product_staged.connect(_on_tray_product_staged)
	customer_handoff_tray.order_handed_off.connect(_on_tray_order_handed_off)
	waste_area.disposition_completed.connect(_on_disposition_completed)
	tray_payment_button.pressed.connect(_collect_tray_payment)
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		var order_signal := Signal(session, &"order_changed")
		if not order_signal.is_connected(_on_formal_shell_changed):
			order_signal.connect(_on_formal_shell_changed)
		var production_signal := Signal(session, &"production_changed")
		if not production_signal.is_connected(_on_formal_shell_changed):
			production_signal.connect(_on_formal_shell_changed)
	_restore_pending_payment()
	_refresh_formal_shell()
	_refresh_pancake_drag_sources()


func _process(delta: float) -> void:
	super._process(delta)
	_refresh_elapsed += delta
	if _refresh_elapsed >= 0.10:
		_refresh_elapsed = 0.0
		_refresh_formal_shell()
		_refresh_pancake_drag_sources()
	# Delivery is physical: the old click-to-serve affordance cannot reappear
	# when the inherited pancake state refreshes.
	serve_product_button.visible = false
	for dish_button in order_dish_buttons:
		dish_button.disabled = true
		dish_button.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _open_f3_station(area_id: StringName) -> void:
	# All production equipment is already present in the shop. Clicking an old
	# route target only explains the direct interaction and never changes focus.
	tool_status_label.text = "%s已在店面中：直接操作设备和实体物料" % _area_label(area_id)


func _close_f3_station() -> void:
	pass


func _focus_formal_order(order: Dictionary, restart_pancake: bool = false) -> void:
	super._focus_formal_order(order, restart_pancake)
	if order.is_empty():
		customer_handoff_tray.clear_order()
		return
	customer_handoff_tray.focus_order(order)
	tool_status_label.text = "已查看当前顾客点单；五个区域保持原位并继续计时"


func _on_formal_shell_changed(_snapshot: Dictionary = {}) -> void:
	_refresh_formal_shell()
	_refresh_pancake_drag_sources()


func _refresh_formal_shell() -> void:
	if not is_node_ready():
		return
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return
	if not _formal_order_id.is_empty() and not tray_payment_button.visible:
		var focused := Dictionary(session.call("formal_order", _formal_order_id))
		if StringName(focused.get("state", &"")) in [&"active", &"serving"]:
			customer_handoff_tray.focus_order(focused)
		else:
			customer_handoff_tray.clear_order()
	var entries: Array = Array(session.call("five_area_attention"))
	var rail := $FiveAreaInfrastructure/AttentionRail
	for index in range(rail.get_child_count()):
		var label := rail.get_child(index) as Label
		if index < entries.size():
			var entry := Dictionary(entries[index])
			var severity := StringName(entry.get("severity", &"yellow"))
			label.text = "%s · %.1f秒" % [_attention_label(StringName(entry.get("status_key", &"attention"))), float(entry.get("seconds_to_irreversible_loss", 0.0))]
			label.add_theme_color_override("font_color", Color("d94732") if severity == &"red" else Color("b97813"))
			label.visible = true
		else:
			label.visible = false


func _refresh_pancake_drag_sources() -> void:
	if p1_session == null or five_area_pancake_production == null:
		return
	var ready := p1_session.phase == P1Session.Phase.READY_TO_SERVE
	if ready and _ready_pancake_source_ref.is_empty():
		var score_result := PANCAKE_SCORER_SCRIPT.evaluate_order(
			pancake_model,
			ingredient_model,
			fold_model,
			p1_session.order,
			p1_session.elapsed_seconds,
			p1_session.patience_ratio(),
		)
		var product := Dictionary(five_area_pancake_production.call("create_product_snapshot", score_result, p1_session.order, {"package_result": fold_model.package_result})).duplicate(true)
		_ready_pancake_source_ref = {"source_kind": &"pancake_ready", "source_index": -1, "product_id": &"product.pancake.custom", "product": product}
	elif not ready:
		_ready_pancake_source_ref.clear()
	pancake_ready_source.configure(_ready_pancake_source_ref, PRODUCT_VISUALS.texture_for(&"product.pancake.custom"), ready, "把现做煎饼拖入顾客托盘")
	pancake_ready_source.visible = ready
	var session := get_node_or_null("/root/GameSession")
	var holding_slots: Array = []
	if session != null and session.has_method("pancake_holding_tray_snapshot"):
		holding_slots = Array(Dictionary(session.call("pancake_holding_tray_snapshot")).get("slots", []))
	for slot_index in range(pancake_holding_sources.size()):
		var product := Dictionary(holding_slots[slot_index]) if slot_index < holding_slots.size() else {}
		pancake_holding_sources[slot_index].configure({"source_kind": &"pancake_holding", "source_index": slot_index, "product_id": StringName(product.get("product_id", &""))}, PRODUCT_VISUALS.texture_for(&"product.pancake.custom"), not product.is_empty(), "把暂存煎饼拖入顾客托盘")
		pancake_holding_sources[slot_index].visible = not product.is_empty()


func _on_tray_product_staged(_result: Dictionary, source_ref: Dictionary, _item_index: int) -> void:
	if StringName(source_ref.get("source_kind", &"")) == &"pancake_ready":
		_ready_pancake_source_ref.clear()
		reset_pancake()
		tool_status_label.text = "现做煎饼已装盘；继续制作其他餐品或递出整盘"
	_refresh_pancake_drag_sources()


func _on_tray_order_handed_off(result: Dictionary) -> void:
	_pending_tray_settlement = _tray_result_summary(result)
	kitchen_audio.call("set_sizzle", false, 0.0)
	kitchen_audio.call("play_cue", &"serve")
	var settlement_id := StringName(result.get("settlement_id", &""))
	var amount := int(result.get("earned_coins", 0))
	tray_payment_button.text = "金币 ×%d\n点击收币" % amount
	tray_payment_button.set_meta("settlement_id", settlement_id)
	tray_payment_button.visible = true
	customer_handoff_tray.visible = false
	_set_customer_portrait_state(&"paying_coins")
	tool_status_label.text = "顾客已接到托盘并付款；点击金币收入钱箱"


func _collect_tray_payment() -> void:
	var settlement_id := StringName(tray_payment_button.get_meta("settlement_id", &""))
	var session := get_node_or_null("/root/GameSession")
	if session == null or settlement_id.is_empty():
		return
	var collected: Dictionary = session.call("collect_tray_payment", settlement_id)
	if not bool(collected.get("success", false)):
		tool_status_label.text = "收币失败：%s" % str(collected.get("reason", &"unknown"))
		return
	tray_payment_button.visible = false
	customer_handoff_tray.visible = true
	tool_status_label.text = "已收取 %d 金币" % int(collected.get("amount", 0))
	var finished := _pending_tray_settlement.duplicate(true)
	_pending_tray_settlement.clear()
	_on_playable_order_finished(finished)
	_populate_result(finished)
	summary_score_label.text = "本单 %d分 · +%d金币" % [roundi(float(finished.get("score", 0.0))), int(finished.get("earned_coins", 0))]
	summary_feedback_label.text = str(finished.get("feedback", "本单已完成"))
	_result_detail_open = false
	_order_summary_visible = true
	_refresh_p1_ui()


func _restore_pending_payment() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null or not session.has_method("pending_tray_payments"):
		return
	var pending: Array = Array(session.call("pending_tray_payments"))
	if pending.is_empty():
		return
	var payment := Dictionary(pending.back())
	_pending_tray_settlement = {
		"success": true,
		"settlement_id": StringName(payment.get("settlement_id", &"")),
		"order_id": StringName(payment.get("order_id", &"")),
		"earned_coins": int(payment.get("amount", 0)),
		"reputation_delta": 0,
	}
	tray_payment_button.set_meta("settlement_id", _pending_tray_settlement.get("settlement_id", &""))
	tray_payment_button.text = "金币 ×%d\n点击收币" % int(payment.get("amount", 0))
	tray_payment_button.visible = true
	customer_handoff_tray.visible = false


func _on_disposition_completed(result: Dictionary) -> void:
	if bool(result.get("success", false)):
		tool_status_label.text = "餐品已计入浪费"
		customer_handoff_tray.refresh_from_session()
	else:
		tool_status_label.text = "餐品回到托盘：%s" % str(result.get("reason", &"unknown"))


func _show_station_status(message: String) -> void:
	tool_status_label.text = message


static func _tray_result_summary(settlement: Dictionary) -> Dictionary:
	var summary := settlement.duplicate(true)
	var item_results := Array(settlement.get("item_results", []))
	var primary_result := Dictionary(item_results[0]) if not item_results.is_empty() else {}
	var product := Dictionary(primary_result.get("product", {}))
	var mismatch_reasons := PackedStringArray(Array(settlement.get("mismatch_reasons", [])))
	summary["score"] = float(product.get("score", 100.0 if bool(settlement.get("order_success", false)) else 0.0))
	summary["dimensions"] = Dictionary(product.get("dimension_scores", {})).duplicate(true)
	summary["tags"] = mismatch_reasons
	if mismatch_reasons.is_empty():
		summary["feedback"] = "顾客已收到完整托盘"
	else:
		summary["feedback"] = "顾客指出：%s" % "、".join(mismatch_reasons)
	return summary


static func _area_label(area_id: StringName) -> String:
	return {
		&"area.pancake": "煎饼鏊台",
		&"area.packaged_drink": "成品饮品柜",
		&"area.youtiao": "油条炸锅",
		&"area.fresh_soy_milk": "现磨豆浆机",
		&"area.steamer": "蒸笼",
	}.get(area_id, "该设备")


static func _attention_label(status_key: StringName) -> String:
	return {
		&"packaged_drink_ready": "热饮可取",
		&"packaged_drink_overcooking": "热饮即将过热",
		&"youtiao_ready": "油条可升篮",
		&"youtiao_overcooking": "油条即将过火",
		&"fresh_soy_milk_ready": "豆浆可接杯",
		&"fresh_soy_milk_overcooking": "豆浆即将变质",
		&"fresh_soy_milk_blocked": "豆浆接杯架已满",
		&"steamer_ready": "蒸品已熟",
		&"steamer_overcooking": "蒸品即将过熟",
		&"soy_output_spoil": "豆浆杯即将变质",
		&"tray_stale": "煎饼暂存即将陈旧",
	}.get(status_key, str(status_key))
