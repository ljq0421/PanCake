class_name FiveAreaWorkstation
extends "res://scripts/gameplay/workstation.gd"

const PRODUCT_VISUALS := preload("res://scripts/ui/five_area_product_visuals.gd")
const CATALOG := preload("res://scripts/data/five_area_catalog.gd")

@onready var five_area_infrastructure: Control = $FiveAreaInfrastructure
@onready var fresh_soy_station: DirectSoyStation = $FiveAreaInfrastructure/Stations/FreshSoyMilkStation
@onready var youtiao_station: DirectYoutiaoStation = $FiveAreaInfrastructure/Stations/YoutiaoStation
@onready var multi_griddle_station: Control = %MultiGriddleStation
@onready var pancake_ready_source: ProductDragSource = %PancakeReadySource
@onready var pancake_holding_sources: Array[ProductDragSource] = [%PancakeHoldingSource01, %PancakeHoldingSource02]
@onready var waste_area: StagedProductDropTarget = %WasteArea
@onready var pending_payment_button: Button = %PendingPaymentButton
@onready var soy_full_slots: Array[Node] = [%SoyFullYellow, %SoyFullBlack, %SoyFullRed]
@onready var soy_split_slots: Array[Node] = [%SoySplitYellow, %SoySplitBlack, %SoySplitRed, %SoySplitMultigrain, %SoySplitReserved02, %SoySplitReserved03]
@onready var youtiao_dough_slots: Array[Node] = [%YoutiaoDoughPlain, %YoutiaoDoughOilCake, %YoutiaoDoughSugar]
@onready var tutorial_guide_overlay: Control = %TutorialGuideOverlay
@onready var fixed_material_lock_artworks: Array[Control] = [
	$SafeArea/LockedIngredientArtwork/Slot01,
	$SafeArea/LockedIngredientArtwork/Slot02,
	$SafeArea/LockedIngredientArtwork/Slot03,
	$SafeArea/LockedIngredientArtwork/Slot04,
	$SafeArea/LockedIngredientArtwork/Slot05,
	$SafeArea/LockedIngredientArtwork/Slot06,
]
@onready var fixed_material_lock_buttons: Array[BaseButton] = [
	$SafeArea/LockedIngredientInteractions/Slot01LockedButton,
	$SafeArea/LockedIngredientInteractions/Slot02LockedButton,
	$SafeArea/LockedIngredientInteractions/Slot03LockedButton,
	$SafeArea/LockedIngredientInteractions/Slot04LockedButton,
	$SafeArea/LockedIngredientInteractions/Slot05LockedButton,
	$SafeArea/LockedIngredientInteractions/Slot06LockedButton,
]

var _ready_pancake_source_ref: Dictionary = {}
var _pending_tray_settlement: Dictionary = {}
var _refresh_elapsed := 0.0
var _delivery_click_in_progress := false
var _pending_youtiao_ingredient_source_ref: Dictionary = {}
var _five_area_mouse_behavior_before_daily_bill := Control.MOUSE_BEHAVIOR_INHERITED
var _multi_griddle_mode_active := false


func _ready() -> void:
	super._ready()
	_five_area_mouse_behavior_before_daily_bill = five_area_infrastructure.mouse_behavior_recursive
	for station in [fresh_soy_station, youtiao_station]:
		station.status_message.connect(_show_station_status)
		# The formal shell already owns tightly scoped locked-station click layers.
		# Full-station covers would otherwise steal pointer input from the pancake
		# sauce rack and discard control where their authored rectangles overlap.
		station.mouse_filter = Control.MOUSE_FILTER_STOP if station in [fresh_soy_station, youtiao_station] else Control.MOUSE_FILTER_IGNORE
		station.lock_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	multi_griddle_station.status_message.connect(_show_station_status)
	for service_slot in customer_service_slots:
		var drop_callback := Callable(self, "_on_customer_service_product_dropped")
		if service_slot.has_signal("product_dropped") and not service_slot.is_connected("product_dropped", drop_callback):
			service_slot.connect("product_dropped", drop_callback)
	waste_area.disposition_completed.connect(_on_disposition_completed)
	pending_payment_button.pressed.connect(_collect_pending_payments)
	for material_slot in _all_material_slots():
		material_slot.hold_requested.connect(_on_material_hold_requested.bind(material_slot))
		material_slot.hold_advanced.connect(_on_material_hold_advanced.bind(material_slot))
		material_slot.short_clicked.connect(_on_material_short_clicked)
	for source in youtiao_station.output_sources:
		source.native_drag_enabled = true
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		multi_griddle_station.bind_session(session, Callable(self, "_compact_griddle_order"))
		var order_signal := Signal(session, &"order_changed")
		if not order_signal.is_connected(_on_formal_shell_changed):
			order_signal.connect(_on_formal_shell_changed)
		var production_signal := Signal(session, &"production_changed")
		if not production_signal.is_connected(_on_production_shell_changed):
			production_signal.connect(_on_production_shell_changed)
	_restore_pending_payment()
	_refresh_formal_shell()
	_refresh_pancake_drag_sources()
	_refresh_material_slots()
	_refresh_multi_griddle_mode()
	var active_order := Dictionary(session.call("active_formal_order")) if session != null else {}


func end_business_day(cutoff: Dictionary = {}) -> void:
	super.end_business_day(cutoff)
	if daily_bill_panel.visible:
		_set_daily_bill_modal_input(true)


func _close_daily_bill() -> void:
	_set_daily_bill_modal_input(false)
	super._close_daily_bill()


func _set_daily_bill_modal_input(active: bool) -> void:
	five_area_infrastructure.mouse_behavior_recursive = (
		Control.MOUSE_BEHAVIOR_DISABLED
		if active
		else _five_area_mouse_behavior_before_daily_bill
	)


func _process(delta: float) -> void:
	super._process(delta)
	_refresh_elapsed += delta
	if _refresh_elapsed >= 0.10:
		_refresh_elapsed = 0.0
		_refresh_pancake_drag_sources()
		_refresh_material_slots()
		_refresh_tutorial_guide()
		_refresh_multi_griddle_mode()
	serve_product_button.visible = false


func _should_defer_business_day_expiration() -> bool:
	return false


func _allows_transaction_cutoff_grace() -> bool:
	# The five-area shop closes on the exact expiry frame. Any delivery that was
	# synchronously completed before timer processing is already in the ledger;
	# every still-open order is expired below.
	return false


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
		var customer_line := str(order.get("customer_line", Dictionary(order.get("metadata", {})).get("customer_line", "")))
		tool_status_label.text = "“%s”" % customer_line if not customer_line.is_empty() else "已查看当前顾客点单；把匹配成品拖到订单商品图标"


func _on_customer_service_delivery_requested(order_id: StringName, _item_index: int) -> void:
	# Clicking an item only focuses its customer. Delivery is deliberately
	# drag-only so a ready pancake is never silently bound to the focused order.
	_on_customer_service_focus_requested(order_id)
	tool_status_label.text = "请把成品拖到订单商品图标；点击不会自动交付"


func _on_formal_shell_changed(_snapshot: Dictionary = {}) -> void:
	_refresh_formal_shell()
	_refresh_pancake_drag_sources()


func _on_production_shell_changed(_snapshot: Dictionary = {}) -> void:
	# Production ticks can arrive every frame. They must not rebuild the order
	# card/portrait tree; only the production-dependent shell is refreshed.
	_refresh_pending_payment_button()
	_refresh_attention_rail()
	_refresh_pancake_drag_sources()


func _all_material_slots() -> Array[Node]:
	var result: Array[Node] = []
	result.append_array(soy_full_slots)
	result.append_array(soy_split_slots)
	result.append_array(youtiao_dough_slots)
	return result


func _refresh_material_slots() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return
	var inventory := Dictionary(session.call("inventory_snapshot"))
	var progression := Dictionary(session.call("five_area_progression_snapshot"))
	var unlocked_areas := Array(progression.get("unlocked_area_ids", []))
	var unlocked_recipes := Array(progression.get("unlocked_recipe_ids", []))
	var multigrain_split := _id_in(unlocked_recipes, &"recipe.fresh_soy_milk.multigrain")
	for slot in soy_full_slots:
		slot.visible = not multigrain_split
	for slot in soy_split_slots:
		slot.visible = multigrain_split
	for slot in _all_material_slots():
		var area_id := &"area.youtiao" if slot.source_kind == &"youtiao_dough" else &"area.fresh_soy_milk"
		var unlocked: bool = _id_in(unlocked_areas, area_id) and (slot.recipe_id.is_empty() or _id_in(unlocked_recipes, slot.recipe_id))
		var status := Dictionary(session.call("five_area_restock_status", slot.stock_id)) if not slot.stock_id.is_empty() else {}
		slot.apply_state(int(inventory.get(str(slot.stock_id), 0)), unlocked, int(status.get("capacity", 6)))
	var fixed_slots: Array[Node] = [soy_full_slots[0], soy_full_slots[1], soy_full_slots[2], youtiao_dough_slots[0], youtiao_dough_slots[1], youtiao_dough_slots[2]]
	for index in fixed_slots.size():
		var slot := fixed_slots[index]
		var area_id := &"area.youtiao" if slot.source_kind == &"youtiao_dough" else &"area.fresh_soy_milk"
		var unlocked: bool = _id_in(unlocked_areas, area_id) and _id_in(unlocked_recipes, slot.recipe_id)
		fixed_material_lock_artworks[index].visible = not unlocked
		fixed_material_lock_buttons[index].visible = not unlocked
		fixed_material_lock_buttons[index].mouse_filter = Control.MOUSE_FILTER_STOP if not unlocked else Control.MOUSE_FILTER_IGNORE


func _on_material_hold_requested(source_ref: Dictionary, slot: Node) -> void:
	var session := get_node_or_null("/root/GameSession")
	var status := Dictionary(session.call("five_area_restock_status", StringName(source_ref.get("stock_id", &"")))) if session != null else {"success": false, "reason": &"no_game_session"}
	var can_start := bool(status.get("success", false)) and int(status.get("current_stock", 0)) < int(status.get("capacity", 0)) and int(status.get("coins", 0)) >= int(status.get("unit_cost", 0))
	if can_start:
		slot.accept_hold()
		tool_status_label.text = "持续长按补货；拖拽已经取消，不会误扣费用"
		return
	slot.reject_hold()
	tool_status_label.text = _restock_failure_text(StringName(status.get("reason", &"")), status)


func _on_material_hold_advanced(source_ref: Dictionary, delta: float, slot: Node) -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		slot.reject_hold()
		return
	var result := Dictionary(session.call("advance_five_area_restock_hold", StringName(source_ref.get("stock_id", &"")), delta))
	if int(result.get("completed_units", 0)) > 0:
		tool_status_label.text = "%s补货 +%d" % [slot.material_label, int(result.get("completed_units", 0))]
	if bool(result.get("auto_stopped", false)) or not bool(result.get("success", false)):
		slot.reject_hold()
		tool_status_label.text = _restock_failure_text(StringName(result.get("reason", &"")), result)
	_refresh_material_slots()


func _on_material_short_clicked(source_ref: Dictionary) -> void:
	if StringName(source_ref.get("source_kind", &"")) == &"youtiao_dough":
		youtiao_station.select_recipe(StringName(source_ref.get("recipe_id", &"")))


func _on_youtiao_output_drag_started(source_ref: Dictionary) -> void:
	if StringName(source_ref.get("product_id", &"")) != &"product.youtiao.plain":
		tool_status_label.text = "油饼和糖油饼不能作为煎饼配料；请点击订单商品直接交付"
		return
	_begin_ingredient_drag(IngredientModel.YOUTIAO, youtiao_station.output_source.get_global_rect().get_center())


func place_youtiao_source_on_pancake(source_ref: Dictionary, viewport_position: Vector2) -> void:
	if StringName(source_ref.get("product_id", &"")) != &"product.youtiao.plain":
		tool_status_label.text = "只有原味油条可以加入煎饼"
		return
	_pending_youtiao_ingredient_source_ref = source_ref.duplicate(true)
	_begin_ingredient_drag(IngredientModel.YOUTIAO, viewport_position)
	if _ingredient_drag_type == IngredientModel.YOUTIAO:
		_finish_ingredient_drag(viewport_position)
	_pending_youtiao_ingredient_source_ref.clear()


func _ingredient_available_for_drag(ingredient_type: StringName) -> bool:
	if ingredient_type == IngredientModel.YOUTIAO:
		var session := get_node_or_null("/root/GameSession")
		if session == null:
			return false
		if StringName(_pending_youtiao_ingredient_source_ref.get("source_kind", &"")) == &"prepared_product_slot":
			return bool(Dictionary(session.call("preview_take_prepared_product", StringName(_pending_youtiao_ingredient_source_ref.get("source_slot_id", &"")))).get("success", false))
		return session.has_method("preview_take_ready_youtiao_for_pancake") and bool(Dictionary(session.call("preview_take_ready_youtiao_for_pancake")).get("success", false))
	return super._ingredient_available_for_drag(ingredient_type)


func _consume_dragged_ingredient(ingredient_type: StringName) -> bool:
	if ingredient_type == IngredientModel.YOUTIAO:
		var session := get_node_or_null("/root/GameSession")
		if session == null:
			return false
		if StringName(_pending_youtiao_ingredient_source_ref.get("source_kind", &"")) == &"prepared_product_slot":
			return bool(Dictionary(session.call("take_prepared_product", StringName(_pending_youtiao_ingredient_source_ref.get("source_slot_id", &"")))).get("success", false))
		return session.has_method("take_ready_youtiao_for_pancake") and bool(Dictionary(session.call("take_ready_youtiao_for_pancake")).get("success", false))
	return super._consume_dragged_ingredient(ingredient_type)


static func _id_in(values: Array, expected: StringName) -> bool:
	return values.has(expected) or values.has(str(expected))


static func _restock_failure_text(reason: StringName, status: Dictionary) -> String:
	match reason:
		&"stock_locked": return "该材料尚未解锁"
		&"capacity_reached": return "材料槽已满"
		&"insufficient_coins": return "余额不足：每份需要 %d 金币" % int(status.get("unit_cost", 0))
		_: return "暂时无法补货：%s" % str(reason)


func _refresh_tutorial_guide() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		tutorial_guide_overlay.call("hide_guide")
		return
	var order := Dictionary(session.call("active_formal_order"))
	var area_id := StringName(order.get("teaching_area_id", &""))
	var metadata := Dictionary(order.get("metadata", {}))
	var tutorial_kind := StringName(order.get("tutorial_kind", metadata.get("tutorial_kind", &"area" if not area_id.is_empty() else &"")))
	var tutorial_id := StringName(order.get("tutorial_id", metadata.get("tutorial_id", area_id)))
	if tutorial_id.is_empty() or StringName(order.get("state", &"")) not in [&"active", &"serving"]:
		tutorial_guide_overlay.call("hide_guide")
		return
	var guide := _tutorial_guide_for_area(session, area_id) if tutorial_kind == &"area" else {}
	var target := guide.get("target") as Control
	if target == null:
		tutorial_guide_overlay.call("hide_guide")
		return
	tutorial_guide_overlay.call("show_guide", target, str(guide.get("message", "完成下一步")))


func _tutorial_guide_for_area(session: Node, area_id: StringName) -> Dictionary:
	var inventory := Dictionary(session.call("inventory_snapshot"))
	match area_id:
		&"area.youtiao":
			var prepared_plain := Dictionary(session.call("prepared_product_slot_status", &"slot.04")) if session.has_method("prepared_product_slot_status") else {}
			if int(prepared_plain.get("count", 0)) > 0:
				return {"target": order_dish_buttons[0], "message": "点击订单中的原味油条，从暂存盘交付"}
			var machine := Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer"))
			match StringName(machine.get("state", &"idle")):
				&"idle":
					var message := "长按原味面胚补货；基础炸篮共2格" if int(inventory.get("stock.youtiao.plain_dough", 0)) <= 0 else "把原味面胚拖入炸篮；基础炸篮共2格"
					return {"target": youtiao_dough_slots[0], "message": message}
				&"loaded":
					var quantity := int(machine.get("quantity", 0))
					var capacity := int(machine.get("capacity", 2))
					var message := "已装%d/%d，点击启动" % [quantity, capacity] if quantity >= capacity else "已装%d/%d，可再放一份或直接启动" % [quantity, capacity]
					return {"target": youtiao_station.start_button, "message": message}
				&"frying": return {"target": youtiao_station.state_label, "message": "等待炸制完成，留意设备状态"}
				&"ready_safe", &"overcooking": return {"target": youtiao_station.lift_button, "message": "及时升篮"}
				&"burnt": return {"target": youtiao_station.output_sources[0], "message": "把焦糊内容逐份拖到废弃区"}
				&"draining": return {"target": youtiao_station.state_label, "message": "等待沥油完成"}
				&"ready_to_collect": return {"target": youtiao_station.prepared_slots[0], "message": "把炸篮中的原味油条拖入暂存盘"}
		&"area.fresh_soy_milk":
			var machine := Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine"))
			match StringName(machine.get("state", &"idle")):
				&"idle":
					var message := "长按黄豆槽补货" if int(inventory.get("stock.fresh_soy_milk.yellow_bean", 0)) <= 0 else "把黄豆拖入豆浆机料口"
					return {"target": soy_split_slots[0] if soy_split_slots[0].visible else soy_full_slots[0], "message": message}
				&"loaded": return {"target": fresh_soy_station.water_button, "message": "点击加水"}
				&"water_added": return {"target": fresh_soy_station.start_button, "message": "水已加入，点击启动研磨"}
				&"grinding": return {"target": fresh_soy_station.state_label, "message": "等待研磨完成"}
				&"ready_safe", &"overcooking", &"blocked": return {"target": order_dish_buttons[0], "message": "点击订单商品，从出杯口或接杯架交付"}
		&"area.pancake":
			if _multi_griddle_mode_active:
				return {"target": multi_griddle_station, "message": "选择空鏊接单；每张鏊子独立摊、翻、加料和出餐"}
			match p1_session.phase:
				P1Session.Phase.SPREAD: return {"target": ladle_button, "message": "舀取面糊，在鏊面摊成完整饼皮"}
				P1Session.Phase.FIRST_SIDE, P1Session.Phase.SECOND_SIDE: return {"target": step_action_button, "message": "观察火候并在合适时机翻面或确认"}
				P1Session.Phase.SAUCE_AND_FILLINGS: return {"target": sauce_brush_button, "message": "刷酱并按订单加入配料"}
				P1Session.Phase.FOLD: return {"target": fold_button, "message": "选择折叠工具并完成折叠"}
				P1Session.Phase.PACKAGE: return {"target": paper_sleeve_button, "message": "选择可用包装完成打包"}
				P1Session.Phase.READY_TO_SERVE: return {"target": order_dish_buttons[0], "message": "点击订单商品交付经典煎饼"}
	return {}
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


func _compact_griddle_order() -> Dictionary:
	var session := get_node_or_null("/root/GameSession")
	if session == null or _formal_order_id.is_empty() or not session.has_method("formal_order"):
		return {}
	var order := Dictionary(session.call("formal_order", _formal_order_id))
	if StringName(order.get("state", &"")) not in [&"active", &"serving"]:
		return {}
	for item_value in Array(order.get("items", [])):
		var item := Dictionary(item_value)
		if StringName(item.get("area_id", &"")) != &"area.pancake":
			continue
		var attached_count := Array(item.get("attached_products", [])).size()
		if attached_count >= maxi(int(item.get("quantity", 1)), 1):
			continue
		return {
			"product_id": &"product.pancake.custom",
			"heat_preference": StringName(item.get("heat_preference", &"golden")),
			"ingredient_ids": PackedStringArray(Array(item.get("ingredient_ids", []))),
			"sauce_ids": PackedStringArray(Array(item.get("sauce_ids", []))),
		}
	return {}


func _refresh_multi_griddle_mode() -> void:
	if not is_node_ready():
		return
	var session := get_node_or_null("/root/GameSession")
	var griddle_count := 1
	if session != null and session.has_method("progression_service"):
		var progression: RefCounted = session.call("progression_service")
		var tier := int(progression.call("device_tier", &"device.pancake_griddle"))
		griddle_count = int(CATALOG.device_tier(&"device.pancake_griddle", tier).get("griddle_count", tier + 1))
	_multi_griddle_mode_active = true
	multi_griddle_station.visible = true
	multi_griddle_station.process_mode = Node.PROCESS_MODE_INHERIT
	multi_griddle_station.set_griddle_count(griddle_count)
	for legacy_path in ["SafeArea/PanBase", "SafeArea/LeftRack", "SafeArea/RightRack", "SafeArea/P1ControlBar"]:
		var legacy_control := get_node_or_null(legacy_path) as CanvasItem
		if legacy_control != null:
			legacy_control.visible = not _multi_griddle_mode_active
	# Every compact griddle owns a dedicated discard action. The old global
	# discard controls sat above the third griddle and intercepted its input.
	waste_area.visible = false
	pancake_ready_source.visible = false
	var legacy_discard := get_node_or_null("SafeArea/DiscardCurrentPancakeButton") as CanvasItem
	if legacy_discard != null:
		legacy_discard.visible = false


func _refresh_p1_ui() -> void:
	super._refresh_p1_ui()
	if not _multi_griddle_mode_active:
		return
	# The inherited single-griddle refresh normally re-enables its redo button.
	# Compact griddles already expose one discard action per surface.
	if discard_current_pancake_button != null:
		discard_current_pancake_button.visible = false


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
	if _multi_griddle_mode_active:
		_ready_pancake_source_ref.clear()
		pancake_ready_source.visible = false
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
	youtiao_station.refresh_from_session()
	_refresh_pancake_drag_sources()
	var result: Array[Dictionary] = []
	# A completed pancake is business state, not presentation state.  Keep its
	# full product snapshot available to click delivery even if the drag source
	# has not completed a visibility/disabled refresh on this frame.
	result.append_array(multi_griddle_station.ready_source_refs())
	var sources: Array[ProductDragSource] = []
	sources.append_array(pancake_holding_sources)
	sources.append_array(youtiao_station.output_sources)
	sources.append(fresh_soy_station.machine_output)
	sources.append_array(fresh_soy_station.rack_outputs)
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
	if StringName(source_ref.get("source_kind", &"")) == &"pancake_griddle_ready":
		multi_griddle_station.consume_ready(int(source_ref.get("source_index", -1)))
	_refresh_pancake_drag_sources()
	youtiao_station.refresh_from_session()
	fresh_soy_station.refresh_from_session()


func _on_customer_service_product_dropped(order_id: StringName, item_index: int, source_ref: Dictionary) -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return
	_on_customer_service_focus_requested(order_id)
	var staged := Dictionary(session.call("stage_product_to_order", source_ref, order_id, item_index))
	if not bool(staged.get("success", false)):
		tool_status_label.text = "鎷栨斁浜や粯澶辫触锛屽師閺婃垚鍝佷繚鐣欙細%s" % str(staged.get("reason", &"unknown"))
		_refresh_formal_shell()
		return
	_on_clicked_product_consumed(source_ref)
	var refreshed := Dictionary(session.call("formal_order", order_id))
	if not _formal_order_items_complete(refreshed):
		tool_status_label.text = "宸叉嫋鏀句氦浠樼 %d 椤癸紱缁х画瀹屾垚鍏朵綑椁愬搧" % (item_index + 1)
		_refresh_formal_shell()
		return
	var completed := Dictionary(session.call("complete_order_delivery", order_id))
	if bool(completed.get("success", false)):
		_finish_clicked_order(completed)
	else:
		tool_status_label.text = "璁㈠崟瀹屾垚澶辫触锛?s" % str(completed.get("reason", &"unknown"))


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
		&"area.youtiao": "没有可交付的油条；请先完成炸制并升篮沥油",
		&"area.fresh_soy_milk": "请先点击豆浆机的“接杯”，再交付当前这杯豆浆",
	}.get(area_id, "该区域没有可交付的成品")


static func _area_label(area_id: StringName) -> String:
	return {
		&"area.pancake": "煎饼鏊台",
		&"area.youtiao": "油条炸锅",
		&"area.fresh_soy_milk": "现磨豆浆机",
	}.get(area_id, "该设备")


static func _attention_label(status_key: StringName) -> String:
	return {
		&"youtiao_ready": "油条可升篮",
		&"youtiao_overcooking": "油条即将过火",
		&"fresh_soy_milk_ready": "豆浆可接杯",
		&"fresh_soy_milk_overcooking": "豆浆即将变质",
		&"fresh_soy_milk_blocked": "豆浆接杯架已满",
		&"soy_output_spoil": "豆浆杯即将变质",
		&"tray_stale": "煎饼暂存即将陈旧",
	}.get(status_key, str(status_key))
