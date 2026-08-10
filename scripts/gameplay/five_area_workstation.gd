class_name FiveAreaWorkstation
extends "res://scripts/gameplay/workstation.gd"

const PRODUCT_VISUALS := preload("res://scripts/ui/five_area_product_visuals.gd")

@onready var five_area_infrastructure: Control = $FiveAreaInfrastructure
@onready var fresh_soy_station: DirectSoyStation = $FiveAreaInfrastructure/Stations/FreshSoyMilkStation
@onready var youtiao_station: DirectYoutiaoStation = $FiveAreaInfrastructure/Stations/YoutiaoStation
@onready var packaged_drink_station: DirectPackagedDrinkStation = $FiveAreaInfrastructure/Stations/PackagedDrinkStation
@onready var steamer_station: DirectSteamerStation = $FiveAreaInfrastructure/Stations/SteamerStation
@onready var pancake_ready_source: ProductDragSource = %PancakeReadySource
@onready var pancake_holding_sources: Array[ProductDragSource] = [%PancakeHoldingSource01, %PancakeHoldingSource02]
@onready var waste_area: StagedProductDropTarget = %WasteArea
@onready var pending_payment_button: Button = %PendingPaymentButton
@onready var prepared_product_slots: Array[Node] = [%PreparedProductSlot04, %PreparedProductSlot05, %PreparedProductSlot06]

var _ready_pancake_source_ref: Dictionary = {}
var _pending_tray_settlement: Dictionary = {}
var _refresh_elapsed := 0.0
var _delivery_click_in_progress := false


func _ready() -> void:
	super._ready()
	for station in [fresh_soy_station, youtiao_station, packaged_drink_station, steamer_station]:
		station.status_message.connect(_show_station_status)
		# The formal shell already owns tightly scoped locked-station click layers.
		# Full-station covers would otherwise steal pointer input from the pancake
		# sauce rack and discard control where their authored rectangles overlap.
		station.mouse_filter = Control.MOUSE_FILTER_STOP if station in [fresh_soy_station, youtiao_station] else Control.MOUSE_FILTER_IGNORE
		station.lock_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	waste_area.disposition_completed.connect(_on_disposition_completed)
	pending_payment_button.pressed.connect(_collect_pending_payments)
	for prepared_slot in prepared_product_slots:
		Signal(prepared_slot, &"store_completed").connect(_on_prepared_product_store_completed)
	Signal(prepared_product_slots[0], &"drag_requested").connect(_begin_ingredient_drag)
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		var order_signal := Signal(session, &"order_changed")
		if not order_signal.is_connected(_on_formal_shell_changed):
			order_signal.connect(_on_formal_shell_changed)
		var production_signal := Signal(session, &"production_changed")
		if not production_signal.is_connected(_on_production_shell_changed):
			production_signal.connect(_on_production_shell_changed)
		var prepared_signal := Signal(session, &"prepared_product_slots_changed")
		if not prepared_signal.is_connected(_on_prepared_product_slots_changed):
			prepared_signal.connect(_on_prepared_product_slots_changed)
	_restore_pending_payment()
	_refresh_formal_shell()
	_refresh_pancake_drag_sources()
	_refresh_prepared_product_slots()
	var active_order := Dictionary(session.call("active_formal_order")) if session != null else {}
	_set_packaged_drink_tutorial_status(active_order)


func _process(delta: float) -> void:
	super._process(delta)
	_refresh_elapsed += delta
	if _refresh_elapsed >= 0.10:
		_refresh_elapsed = 0.0
		_refresh_pancake_drag_sources()
	serve_product_button.visible = false


func _should_defer_business_day_expiration() -> bool:
	var session := get_node_or_null("/root/GameSession")
	if session == null or _formal_order_id.is_empty():
		return false
	var order := Dictionary(session.call("formal_order", _formal_order_id))
	return StringName(order.get("state", &"")) in [&"active", &"serving"]


func _open_f3_station(area_id: StringName) -> void:
	# All production equipment is already present in the shop. Clicking an old
	# route target only explains the direct interaction and never changes focus.
	tool_status_label.text = "%s已在店面中：直接操作设备和实体物料" % _area_label(area_id)


func _close_f3_station() -> void:
	pass


func _focus_formal_order(order: Dictionary, restart_pancake: bool = false) -> void:
	super._focus_formal_order(order, restart_pancake)
	if not order.is_empty():
		_refresh_order_card_ui(order, _formal_order_patience_ratio(order))
		if not _set_packaged_drink_tutorial_status(order):
			tool_status_label.text = "已查看当前顾客点单；点击订单商品图标交付对应成品"


func _set_packaged_drink_tutorial_status(order: Dictionary) -> bool:
	if StringName(order.get("teaching_area_id", &"")) != &"area.packaged_drink":
		return false
	var session := get_node_or_null("/root/GameSession")
	var milk_count := 0
	if session != null and session.has_method("inventory_snapshot"):
		milk_count = int(Dictionary(session.call("inventory_snapshot")).get("stock.packaged_drink.milk", 0))
	tool_status_label.text = (
		"饮品教学：先长按纯牛奶补货，再点击订单商品交付"
		if milk_count <= 0
		else "饮品教学：点击订单商品交付一份常温纯牛奶"
	)
	return true


func _on_formal_shell_changed(_snapshot: Dictionary = {}) -> void:
	_refresh_formal_shell()
	_refresh_pancake_drag_sources()


func _on_production_shell_changed(_snapshot: Dictionary = {}) -> void:
	# Production ticks can arrive every frame. They must not rebuild the order
	# card/portrait tree; only the production-dependent shell is refreshed.
	_refresh_pending_payment_button()
	_refresh_attention_rail()
	_refresh_pancake_drag_sources()


func _on_prepared_product_slots_changed(_snapshot: Dictionary = {}) -> void:
	_refresh_prepared_product_slots()


func _refresh_prepared_product_slots() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null or not session.has_method("prepared_product_slot_status"):
		return
	for prepared_slot in prepared_product_slots:
		var status := Dictionary(session.call("prepared_product_slot_status", StringName(prepared_slot.get("slot_id"))))
		prepared_slot.call("configure_count", int(status.get("count", 0)), bool(status.get("success", false)))


func _on_prepared_product_store_completed(result: Dictionary) -> void:
	_refresh_prepared_product_slots()
	youtiao_station.refresh_from_session()
	if bool(result.get("success", false)):
		tool_status_label.text = "炸物已放入 %s（%d/6）" % [str(result.get("slot_id", &"")), int(result.get("count", 0))]
		return
	var reason := StringName(result.get("reason", &"unknown"))
	var messages := {
		&"prepared_product_slot_full": "该炸物成品槽已满，成品仍留在炸篮",
		&"prepared_product_slot_mismatch": "炸物与成品槽不匹配，成品仍留在炸篮",
		&"recipe_locked": "对应炸物配方尚未解锁，成品仍留在炸篮",
	}
	tool_status_label.text = str(messages.get(reason, "入槽失败，成品仍留在炸篮：%s" % str(reason)))


func _refresh_formal_shell() -> void:
	if not is_node_ready():
		return
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return
	if not _formal_order_id.is_empty():
		var focused := Dictionary(session.call("formal_order", _formal_order_id))
		if StringName(focused.get("state", &"")) in [&"active", &"serving"]:
			_refresh_order_card_ui(focused, _formal_order_patience_ratio(focused))
	_refresh_pending_payment_button()
	_refresh_attention_rail()


func _refresh_attention_rail() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null or not session.has_method("five_area_attention"):
		return
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
	pancake_ready_source.configure(_ready_pancake_source_ref, PRODUCT_VISUALS.texture_for(&"product.pancake.custom"), ready, "现做煎饼已完成；点击订单商品图标交付，或拖到废弃区")
	pancake_ready_source.visible = ready
	var session := get_node_or_null("/root/GameSession")
	var holding_slots: Array = []
	if session != null and session.has_method("pancake_holding_tray_snapshot"):
		holding_slots = Array(Dictionary(session.call("pancake_holding_tray_snapshot")).get("slots", []))
	for slot_index in range(pancake_holding_sources.size()):
		var product := Dictionary(holding_slots[slot_index]) if slot_index < holding_slots.size() else {}
		pancake_holding_sources[slot_index].configure({"source_kind": &"pancake_holding", "source_index": slot_index, "product_id": StringName(product.get("product_id", &""))}, PRODUCT_VISUALS.texture_for(&"product.pancake.custom"), not product.is_empty(), "暂存煎饼可交付；点击订单商品图标取用")
		pancake_holding_sources[slot_index].visible = not product.is_empty()


func _refresh_order_card_ui(order: Dictionary, patience_ratio: float) -> void:
	super._refresh_order_card_ui(order, patience_ratio)
	var items := _order_items_for_card(order)
	var order_id := StringName(order.get("order_id", _formal_order_id))
	var order_active := not order_id.is_empty() and StringName(order.get("state", &"active")) in [&"active", &"serving"]
	for item_index in range(order_dish_buttons.size()):
		var button := order_dish_buttons[item_index]
		var icon := order_dish_icons[item_index]
		var has_item := item_index < items.size()
		button.visible = has_item
		if not has_item:
			button.disabled = true
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE
			continue
		var item := Dictionary(items[item_index])
		var product_id := StringName(item.get("product_id", &"product.pancake.custom"))
		var temperature_mode := StringName(item.get("temperature_mode", &"room_temperature"))
		var product_texture := PRODUCT_VISUALS.texture_for(product_id, temperature_mode)
		if product_texture != null:
			icon.texture = product_texture
		var completed := Array(item.get("prepared_product_instance_ids", [])).size() >= maxi(int(item.get("quantity", 1)), 1)
		var should_disable := completed or not order_active or _delivery_click_in_progress
		if button.disabled != should_disable:
			button.disabled = should_disable
		var target_mouse_filter := Control.MOUSE_FILTER_IGNORE if should_disable else Control.MOUSE_FILTER_STOP
		if button.mouse_filter != target_mouse_filter:
			button.mouse_filter = target_mouse_filter
		button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if should_disable else Control.CURSOR_POINTING_HAND
		button.tooltip_text = "该订单商品已交付" if completed else "点击交付对应成品"


func _order_card_uses_click_delivery() -> bool:
	return true


func _on_order_dish_pressed(item_index: int) -> void:
	if _delivery_click_in_progress:
		tool_status_label.text = "正在交付上一件商品，请勿重复点击"
		return
	_delivery_click_in_progress = true
	_try_deliver_order_item(item_index)
	_delivery_click_in_progress = false
	_refresh_formal_shell()


func _try_deliver_order_item(item_index: int) -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null or _formal_order_id.is_empty():
		tool_status_label.text = "当前没有可交付的顾客订单"
		return
	var order := Dictionary(session.call("formal_order", _formal_order_id))
	var items := Array(order.get("items", []))
	if item_index < 0 or item_index >= items.size():
		tool_status_label.text = "该订单商品格为空"
		return
	var item := Dictionary(items[item_index])
	if Array(item.get("prepared_product_instance_ids", [])).size() >= maxi(int(item.get("quantity", 1)), 1):
		tool_status_label.text = "该订单商品已经交付，不能重复提交"
		_refresh_order_card_ui(order, _formal_order_patience_ratio(order))
		return
	var chosen := _delivery_source_for_item(session, order, item_index)
	if chosen.is_empty():
		tool_status_label.text = _missing_delivery_source_text(StringName(item.get("area_id", &"")))
		return
	var source_ref := Dictionary(chosen.get("source_ref", {}))
	var staged := Dictionary(session.call("stage_product_to_order", source_ref, _formal_order_id, item_index))
	if not bool(staged.get("success", false)):
		tool_status_label.text = "交付失败，成品未被消耗：%s" % str(staged.get("reason", &"unknown"))
		_refresh_formal_shell()
		return
	_on_clicked_product_consumed(source_ref)
	var refreshed := Dictionary(session.call("formal_order", _formal_order_id))
	if not _formal_order_items_complete(refreshed):
		var suffix := "（餐品与要求不符，结算时会扣分）" if not bool(staged.get("will_match", false)) else ""
		tool_status_label.text = "已交付第 %d 项%s；请继续点击剩余商品" % [item_index + 1, suffix]
		_refresh_order_card_ui(refreshed, _formal_order_patience_ratio(refreshed))
		return
	var completed := Dictionary(session.call("complete_order_delivery", _formal_order_id))
	if not bool(completed.get("success", false)):
		tool_status_label.text = "订单完成失败：%s" % str(completed.get("reason", &"unknown"))
		return
	_finish_clicked_order(completed)


func _delivery_source_for_item(session: Node, order: Dictionary, item_index: int) -> Dictionary:
	var items := Array(order.get("items", []))
	if item_index < 0 or item_index >= items.size():
		return {}
	var target_area := StringName(Dictionary(items[item_index]).get("area_id", &""))
	var fallback := {}
	for source_ref in _available_delivery_source_refs():
		var preview := Dictionary(session.call("preview_stage_product_to_order", source_ref, _formal_order_id, item_index))
		if not bool(preview.get("success", false)):
			continue
		var product := Dictionary(preview.get("product", {}))
		var product_id := StringName(product.get("product_id", &""))
		var product_area := StringName(product.get("area_id", FIVE_AREA_CATALOG.product_definition(product_id).get("area_id", &"")))
		if product_area != target_area:
			continue
		var candidate := {"source_ref": Dictionary(source_ref).duplicate(true), "preview": preview}
		if bool(preview.get("will_match", false)):
			return candidate
		if fallback.is_empty():
			fallback = candidate
	return fallback


func _available_delivery_source_refs() -> Array[Dictionary]:
	packaged_drink_station.refresh_from_session()
	youtiao_station.refresh_from_session()
	_refresh_pancake_drag_sources()
	var sources: Array[ProductDragSource] = [pancake_ready_source]
	sources.append_array(pancake_holding_sources)
	sources.append_array(packaged_drink_station.heater_sources)
	sources.append_array(packaged_drink_station.lanes)
	var result: Array[Dictionary] = []
	for source in sources:
		if source == null or source.disabled or not source.visible:
			continue
		var source_ref := Dictionary(source.call("source_ref"))
		if not source_ref.is_empty():
			result.append(source_ref)
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("prepared_product_slot_status"):
		for slot_id in [&"slot.04", &"slot.05", &"slot.06"]:
			var status := Dictionary(session.call("prepared_product_slot_status", slot_id))
			if bool(status.get("success", false)) and int(status.get("count", 0)) > 0:
				result.append({
					"source_kind": &"prepared_product_slot",
					"source_slot_id": slot_id,
					"source_index": -1,
					"product_id": StringName(status.get("product_id", &"")),
				})
	return result


func _on_clicked_product_consumed(source_ref: Dictionary) -> void:
	if StringName(source_ref.get("source_kind", &"")) == &"pancake_ready":
		_ready_pancake_source_ref.clear()
		reset_pancake()
	_refresh_pancake_drag_sources()
	packaged_drink_station.refresh_from_session()
	youtiao_station.refresh_from_session()
	_refresh_prepared_product_slots()


func _finish_clicked_order(result: Dictionary) -> void:
	var finished := _tray_result_summary(result)
	_pending_tray_settlement = finished.duplicate(true)
	kitchen_audio.call("set_sizzle", false, 0.0)
	kitchen_audio.call("play_cue", &"serve")
	var earned := int(finished.get("earned_coins", 0))
	if _business_day_expiration_pending:
		_business_day_expiration_pending = false
		_end_business_day_for_timer()
	else:
		_on_playable_order_finished(finished)
	_populate_result(finished)
	summary_score_label.text = "本单 %d分 · +%d金币" % [roundi(float(finished.get("score", 0.0))), earned]
	summary_feedback_label.text = str(finished.get("feedback", "本单已完成"))
	_result_detail_open = false
	_order_summary_visible = true
	_refresh_pending_payment_button()
	if not _business_day_closed:
		_refresh_p1_ui()
		var pending_total := _pending_payment_total()
		tool_status_label.text = "顾客已付款 %d 金币；下一位顾客已到，收款位累计待收 %d 金币" % [earned, pending_total] if earned > 0 else "错单已结束且本单未付款；下一位顾客已到"


func _collect_pending_payments() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return
	var collected := Dictionary(session.call("collect_all_pending_order_payments"))
	if not bool(collected.get("success", false)):
		tool_status_label.text = "收币失败：%s" % str(collected.get("reason", &"unknown"))
		return
	_refresh_pending_payment_button()
	tool_status_label.text = "已一次收取 %d 金币；当前顾客订单继续" % int(collected.get("amount", 0))


func _collect_tray_payment() -> void:
	_collect_pending_payments()


func _restore_pending_payment() -> void:
	_refresh_pending_payment_button()


func _refresh_pending_payment_button() -> void:
	var pending_total := _pending_payment_total()
	pending_payment_button.visible = pending_total > 0
	pending_payment_button.disabled = pending_total <= 0
	pending_payment_button.mouse_filter = Control.MOUSE_FILTER_STOP if pending_total > 0 else Control.MOUSE_FILTER_IGNORE
	pending_payment_button.text = "金币 ×%d\n点击全部收取" % pending_total
	pending_payment_button.tooltip_text = "收取所有尚未领取的顾客付款" if pending_total > 0 else "当前没有待收金币"


func _pending_payment_total() -> int:
	var session := get_node_or_null("/root/GameSession")
	if session == null or not session.has_method("pending_order_payments"):
		return 0
	var total := 0
	for payment_value in Array(session.call("pending_order_payments")):
		total += maxi(int(Dictionary(payment_value).get("amount", 0)), 0)
	return total


func _on_disposition_completed(result: Dictionary) -> void:
	if bool(result.get("success", false)):
		tool_status_label.text = "餐品已计入浪费"
		_refresh_pancake_drag_sources()
		packaged_drink_station.refresh_from_session()
		youtiao_station.refresh_from_session()
	else:
		tool_status_label.text = "餐品回到原处：%s" % str(result.get("reason", &"unknown"))


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
		summary["feedback"] = "顾客已收到完整订单"
	else:
		summary["feedback"] = "顾客指出：%s" % "、".join(mismatch_reasons)
	return summary


static func _missing_delivery_source_text(area_id: StringName) -> String:
	return {
		&"area.pancake": "没有可交付的煎饼；请先完成包装或从成品暂存托盘取用",
		&"area.packaged_drink": "没有可交付的成品饮品；热饮需要等待加热完成",
		&"area.youtiao": "没有可交付的油条；请先完成炸制并升篮沥油",
	}.get(area_id, "该区域没有可交付的成品")


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
