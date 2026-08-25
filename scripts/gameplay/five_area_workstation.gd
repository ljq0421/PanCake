class_name FiveAreaWorkstation
extends "res://scripts/gameplay/workstation.gd"

const PRODUCT_VISUALS := preload("res://scripts/ui/five_area_product_visuals.gd")
const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const PAYMENT_COIN_MODEL_SCRIPT := preload("res://scripts/gameplay/payment_coin_model.gd")
const RESULT_QUALITY_ICON_PATHS := {
	&"IntegrityMetric": "res://resources/art/ui/quality/quality_integrity_v2_chinese_ui.png",
	&"ThicknessMetric": "res://resources/art/ui/quality/quality_thickness_uniformity_v2_chinese_ui.png",
	&"HeatMetric": "res://resources/art/ui/quality/quality_heat_uniformity_v2_chinese_ui.png",
	&"EggMetric": "res://resources/art/ui/quality/quality_egg_spread_v2_chinese_ui.png",
	&"SauceMetric": "res://resources/art/ui/quality/quality_sauce_coverage_v2_chinese_ui.png",
	&"IngredientMetric": "res://resources/art/ui/quality/quality_ingredient_distribution_v2_chinese_ui.png",
	&"FoldMetric": "res://resources/art/ui/quality/quality_fold_stability_v2_chinese_ui.png",
	&"OrderMetric": "res://resources/art/ui/quality/quality_order_correctness_v2_chinese_ui.png",
	&"TimeMetric": "res://resources/art/ui/quality/quality_preparation_time_v2_chinese_ui.png",
}
const RESULT_METRIC_LABEL_NAMES := {
	&"IntegrityMetric": &"IntegrityScoreLabel",
	&"ThicknessMetric": &"ThicknessScoreLabel",
	&"HeatMetric": &"HeatScoreLabel",
	&"EggMetric": &"EggScoreLabel",
	&"SauceMetric": &"SauceScoreLabel",
	&"IngredientMetric": &"IngredientScoreLabel",
	&"FoldMetric": &"FoldScoreLabel",
	&"OrderMetric": &"OrderScoreLabel",
	&"TimeMetric": &"TimeScoreLabel",
}
const PAYMENT_COIN_TEXTURES := {
	1: preload("res://resources/art/payments/coin_1_v2_chinese_ui.png"),
	2: preload("res://resources/art/payments/coin_2_v2_chinese_ui.png"),
	5: preload("res://resources/art/payments/coin_5_v2_chinese_ui.png"),
	10: preload("res://resources/art/payments/coin_10_v2_chinese_ui.png"),
	20: preload("res://resources/art/payments/coin_20_v2_chinese_ui.png"),
}
const RIGHT_SOY_STATION_POSITION := Vector2(1500.0, 480.0)
const RIGHT_SOY_STATION_SIZE := Vector2(410.0, 496.0)
const FORMAL_PAYMENT_COIN_SIZE := Vector2(44.0, 44.0)
const FORMAL_PAYMENT_COIN_ORIGIN := Vector2(842.0, 526.0)
const FORMAL_PAYMENT_COIN_COLUMN_SPACING := 38.0
const FORMAL_PAYMENT_COIN_ROW_SPACING := 24.0
const FORMAL_PAYMENT_COIN_MAX_COLUMNS := 6
const FORMAL_PAYMENT_COIN_STAGGER_SECONDS := 0.05
const FORMAL_PAYMENT_COIN_LAUNCH_SECONDS := 0.12
const FORMAL_PAYMENT_COIN_FLIGHT_SECONDS := 0.24
const FORMAL_PAYMENT_REDUCED_FADE_SECONDS := 0.20
const FORMAL_PAYMENT_REWARD_POP_SECONDS := 0.16
const FORMAL_PAYMENT_REWARD_EXIT_SECONDS := 0.20
const FORMAL_PAYMENT_BURST_SPARK_COUNT := 10
const FORMAL_PAYMENT_GOLD := Color(1.0, 0.72, 0.12, 1.0)
const FORMAL_PAYMENT_GOLD_BRIGHT := Color(1.0, 0.94, 0.54, 1.0)
const RESULT_OVERLAY_Z_INDEX := 300
const TOP_WARNING_DURATION_SECONDS := 2.0
const TOP_WARNING_FADE_SECONDS := 0.20

@onready var five_area_infrastructure: Control = $FiveAreaInfrastructure
@onready var fresh_soy_station: DirectSoyStation = $FiveAreaInfrastructure/Stations/FreshSoyMilkStation
@onready var cartoon_youtiao_fryer: CartoonYoutiaoFryerToggle = $FiveAreaInfrastructure/Stations/CartoonYoutiaoFryer
@onready var multi_griddle_station: Control = %MultiGriddleStation
@onready var pancake_ready_source: ProductDragSource = get_node_or_null("FiveAreaInfrastructure/PancakeReadySource") as ProductDragSource
@onready var pancake_holding_sources: Array[ProductDragSource] = [%PancakeHoldingSource01, %PancakeHoldingSource02]
@onready var waste_area: StagedProductDropTarget = %WasteBasket
@onready var pending_payment_button: Button = %PendingPaymentButton
@onready var youtiao_dough_slots: Array[Node] = [%YoutiaoDoughPlain]
@onready var tutorial_guide_overlay: Control = %TutorialGuideOverlay
@onready var top_warning_label: Label = %TopWarningLabel
@onready var pancake_worktop_hotspots: Control = get_node_or_null("SafeArea/JianbingStallArtwork/PancakeWorktopHotspots") as Control
@onready var fixed_material_lock_artworks: Array[Control] = [
	$SafeArea/LockedIngredientArtwork/Slot01,
	$SafeArea/LockedIngredientArtwork/Slot02,
	$SafeArea/LockedIngredientArtwork/Slot03,
	$SafeArea/LockedIngredientArtwork/Slot04,
]
@onready var fixed_material_lock_buttons: Array[BaseButton] = [
	$SafeArea/LockedIngredientInteractions/Slot01LockedButton,
	$SafeArea/LockedIngredientInteractions/Slot02LockedButton,
	$SafeArea/LockedIngredientInteractions/Slot03LockedButton,
	$SafeArea/LockedIngredientInteractions/Slot04LockedButton,
]

var _ready_pancake_source_ref: Dictionary = {}
var _pending_tray_settlement: Dictionary = {}
var _refresh_elapsed := 0.0
var _delivery_click_in_progress := false
var _pending_youtiao_ingredient_source_ref: Dictionary = {}
var _five_area_mouse_behavior_before_daily_bill := Control.MOUSE_BEHAVIOR_INHERITED
var _multi_griddle_mode_active := false
var _formal_payment_coin_sprites: Array[TextureRect] = []
var _formal_payment_total_pulse_tween: Tween
var _formal_payment_collection_active := false
var _workshop_payment_display_hidden := false
var _result_quality_icons_loaded := false
var _formal_payment_total_rest_modulate := Color.WHITE
var _top_warning_tween: Tween


func _ready() -> void:
	_five_area_mouse_behavior_before_daily_bill = five_area_infrastructure.mouse_behavior_recursive
	super._ready()
	# The base shop setup initializes legacy foreground layers after the scene
	# has been instantiated. Set these application-layer values after that setup
	# so the result UI always remains above all direct-manipulation hotspots.
	result_panel.z_index = RESULT_OVERLAY_Z_INDEX
	order_summary_card.z_index = RESULT_OVERLAY_Z_INDEX
	if result_detail_input_shield != null:
		result_detail_input_shield.z_index = RESULT_OVERLAY_Z_INDEX - 1
	# The formal-order shell returns from the parent setup before its legacy
	# payment animation setup. Keep the real coin sprites above the counter,
	# but below modal result panels.
	payment_coin_layer.z_index = 30
	_formal_payment_total_rest_modulate = global_status_label.modulate
	# DirectSoyStation owns both the right-side dispenser artwork and its serving
	# interactions. Normalize its instance offsets so the retired left-side
	# placement cannot resurface.
	fresh_soy_station.set_anchors_preset(Control.PRESET_TOP_LEFT)
	fresh_soy_station.position = RIGHT_SOY_STATION_POSITION
	fresh_soy_station.size = RIGHT_SOY_STATION_SIZE
	for station in [fresh_soy_station, cartoon_youtiao_fryer]:
		station.status_message.connect(_show_station_status)
		# The formal shell already owns tightly scoped locked-station click layers.
		# Full-station covers would otherwise steal pointer input from the pancake
		# sauce rack and discard control where their authored rectangles overlap.
		station.mouse_filter = Control.MOUSE_FILTER_STOP
		if station.lock_cover != null:
			station.lock_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	multi_griddle_station.status_message.connect(_show_station_status)
	multi_griddle_station.transient_warning_requested.connect(_show_top_warning)
	if pancake_worktop_hotspots != null:
		pancake_worktop_hotspots.status_message.connect(_show_station_status)
	for service_slot in customer_service_slots:
		var drop_callback := Callable(self, "_on_customer_service_product_dropped")
		if service_slot.has_signal("product_dropped") and not service_slot.is_connected("product_dropped", drop_callback):
			service_slot.connect("product_dropped", drop_callback)
	if waste_area != null:
		waste_area.disposition_completed.connect(_on_disposition_completed)
		waste_area.product_source_discarded.connect(_on_waste_product_source_discarded)
		waste_area.active_griddle_clear_requested.connect(_on_waste_active_griddle_clear_requested)
	pending_payment_button.pressed.connect(_collect_pending_payments)
	for material_slot in _all_material_slots():
		material_slot.hold_requested.connect(_on_material_hold_requested.bind(material_slot))
		material_slot.hold_advanced.connect(_on_material_hold_advanced.bind(material_slot))
		material_slot.short_clicked.connect(_on_material_short_clicked)
	for source in cartoon_youtiao_fryer.output_sources:
		source.native_drag_enabled = true
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		multi_griddle_station.bind_session(session)
		if pancake_worktop_hotspots != null:
			pancake_worktop_hotspots.bind_session(session)
		var order_signal := Signal(session, &"order_changed")
		if not order_signal.is_connected(_on_formal_shell_changed):
			order_signal.connect(_on_formal_shell_changed)
		var production_signal := Signal(session, &"production_changed")
		if not production_signal.is_connected(_on_production_shell_changed):
			production_signal.connect(_on_production_shell_changed)
	_restore_pending_payment()
	_refresh_formal_shell()
	_refresh_formal_area_visibility()
	_refresh_material_slots()
	_refresh_multi_griddle_mode()
	_refresh_pancake_drag_sources()
	var active_order := Dictionary(session.call("active_formal_order")) if session != null else {}


func _refresh_result_presentation() -> void:
	super._refresh_result_presentation()
	if result_panel != null and result_panel.visible:
		_load_result_quality_icons()


func _populate_result(score_result: Dictionary) -> void:
	var product_id := StringName(score_result.get("product_id", &"product.pancake.custom"))
	if product_id == &"product.pancake.custom":
		_set_result_metric_visibility(RESULT_METRIC_LABEL_NAMES.keys(), true, true)
		super._populate_result(score_result)
		return
	var metric_profile := _non_pancake_result_metric_profile(score_result, product_id)
	_set_result_metric_visibility(RESULT_METRIC_LABEL_NAMES.keys(), false, false)
	for metric_value in metric_profile:
		var metric := Dictionary(metric_value)
		var metric_name := StringName(metric.get("metric", &""))
		var metric_control := get_node_or_null("SafeArea/ResultPanel/Margin/VBox/DimensionGrid/%s" % metric_name) as Control
		var score_label_name := StringName(RESULT_METRIC_LABEL_NAMES.get(metric_name, &""))
		var score_label := get_node_or_null("%%%s" % score_label_name) as Label
		if metric_control != null:
			metric_control.visible = true
		if score_label != null:
			score_label.text = "%s  %d" % [str(metric.get("label", "评分")), roundi(float(metric.get("score", 0.0)))]
	result_title_label.text = "顾客评价 · %d分" % roundi(float(score_result.get("score", 0.0)))
	result_detail_label.text = str(score_result.get("feedback", "本单已完成"))
	var result_tags: String = " · ".join(PackedStringArray(Array(score_result.get("tags", [])).map(func(tag): return str(tag))))
	result_tags_label.text = "亮点与问题：%s" % (result_tags if not result_tags.is_empty() else "暂无")


func _set_result_metric_visibility(metric_names: Array, visible: bool, show_icons: bool) -> void:
	for metric_value in metric_names:
		var metric_name := StringName(metric_value)
		var metric_control := get_node_or_null("SafeArea/ResultPanel/Margin/VBox/DimensionGrid/%s" % metric_name) as Control
		if metric_control != null:
			metric_control.visible = visible
			var icon := metric_control.get_node_or_null("Icon") as TextureRect
			if icon != null:
				icon.visible = visible and show_icons


static func _non_pancake_result_metric_profile(score_result: Dictionary, product_id: StringName) -> Array[Dictionary]:
	var displayed_item := Dictionary(score_result.get("display_item", {}))
	var product := Dictionary(score_result.get("display_product", {}))
	if product.is_empty():
		product = {"product_id": product_id}
	var mismatch_reasons := PackedStringArray(displayed_item.get("mismatch_reasons", PackedStringArray()))
	var order_score := 100.0 if mismatch_reasons.is_empty() else 0.0
	match product_id:
		&"product.youtiao.plain", &"product.youtiao.sesame":
			return [
				{"metric": &"IntegrityMetric", "label": "火候", "score": float(product.get("quality", 0.0))},
				# A youtiao can only become a deliverable product after its draining
				# phase has completed, so the delivered state represents full draining.
				{"metric": &"ThicknessMetric", "label": "沥油", "score": 100.0},
				{"metric": &"OrderMetric", "label": "订单", "score": order_score},
			]
		&"product.fresh_soy_milk.yellow_bean":
			var requested_sugar := int(displayed_item.get("requested_sugar_servings", 0))
			var requested_temperature := StringName(displayed_item.get("requested_temperature_mode", &"room_temperature"))
			return [
				{"metric": &"IntegrityMetric", "label": "满杯度", "score": float(product.get("fill_ratio", 0.0)) * 100.0},
				{"metric": &"ThicknessMetric", "label": "糖度", "score": 100.0 if int(product.get("sugar_servings", 0)) == requested_sugar else 0.0},
				{"metric": &"HeatMetric", "label": "温度", "score": 100.0 if StringName(product.get("temperature_mode", &"room_temperature")) == requested_temperature else 0.0},
				{"metric": &"OrderMetric", "label": "订单", "score": order_score},
			]
	return [{"metric": &"OrderMetric", "label": "订单", "score": order_score}]


func _load_result_quality_icons() -> void:
	if _result_quality_icons_loaded:
		return
	for metric_name in RESULT_QUALITY_ICON_PATHS:
		var icon := get_node_or_null("SafeArea/ResultPanel/Margin/VBox/DimensionGrid/%s/Icon" % metric_name) as TextureRect
		if icon != null:
			icon.texture = load(str(RESULT_QUALITY_ICON_PATHS[metric_name])) as Texture2D
	_result_quality_icons_loaded = true


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"reset_pancake") and not (event is InputEventKey and event.echo):
		reset_pancake()
		get_viewport().set_input_as_handled()
		return
	super._input(event)


func reset_pancake() -> void:
	if _multi_griddle_mode_active and is_instance_valid(multi_griddle_station):
		multi_griddle_station.reset_active()
		return
	super.reset_pancake()


func end_business_day(cutoff: Dictionary = {}) -> void:
	super.end_business_day(cutoff)
	# GameSession has already attributed the unfinished pancake's consumed
	# materials to today's waste. Clear the live griddle too: otherwise its
	# periodic snapshot sync can overwrite that cleared save while the daily
	# bill or upgrade workshop is still open.
	if daily_bill_panel.visible and is_instance_valid(multi_griddle_station):
		multi_griddle_station.reset_all()
	if daily_bill_panel.visible:
		_set_daily_bill_modal_input(true)


func _close_daily_bill() -> void:
	super._close_daily_bill()
	_refresh_five_area_modal_input()


func _set_daily_bill_modal_input(_active: bool) -> void:
	_refresh_five_area_modal_input()


func _refresh_five_area_modal_input() -> void:
	# Only full-screen/modal presentations block the workbench. The compact order
	# summary intentionally stays visible while the next customer is being served,
	# so it must not freeze the production hotspots.
	var result_modal_visible := result_panel != null and result_panel.visible
	var modal_is_open := result_modal_visible or (daily_bill_panel != null and daily_bill_panel.visible)
	five_area_infrastructure.mouse_behavior_recursive = (
		Control.MOUSE_BEHAVIOR_DISABLED
		if modal_is_open
		else _five_area_mouse_behavior_before_daily_bill
	)


func _raise_result_presentation_input() -> void:
	# CanvasItem z-order controls drawing, but Control hit testing follows sibling
	# order. Put the active result UI at the end of SafeArea too, otherwise an
	# order card created later in the scene can receive the click beneath it.
	if _result_detail_open and result_panel.visible:
		if result_detail_input_shield != null:
			result_detail_input_shield.move_to_front()
		result_panel.move_to_front()
	elif _order_summary_visible and order_summary_card.visible:
		order_summary_card.move_to_front()


func _process(delta: float) -> void:
	super._process(delta)
	_refresh_elapsed += delta
	if _refresh_elapsed >= 0.10:
		# Native dragging already performs synchronous Control hit testing for each
		# pointer sample. Periodic source reconfiguration invalidates that tree and
		# makes unrelated drags visibly hitch. These views are presentation-only and
		# catch up on the first frame after release.
		var viewport := get_viewport()
		if viewport == null or not viewport.gui_is_dragging():
			_refresh_elapsed = 0.0
			_refresh_pancake_drag_sources()
			_refresh_material_slots()
			_refresh_tutorial_guide()
			_refresh_multi_griddle_mode()
	if serve_product_button != null:
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
		tool_status_label.text = "“%s”" % customer_line if not customer_line.is_empty() else "已查看当前顾客点单；点击订单商品图标即可交付"


func _on_customer_service_delivery_requested(order_id: StringName, item_index: int) -> void:
	_on_customer_service_focus_requested(order_id)
	if _delivery_click_in_progress:
		tool_status_label.text = "正在交付上一件商品，请勿重复点击"
		return
	_delivery_click_in_progress = true
	_try_deliver_order_item(order_id, item_index)
	_delivery_click_in_progress = false
	_refresh_formal_shell()


func _on_formal_shell_changed(_snapshot: Dictionary = {}) -> void:
	_refresh_formal_shell()
	# The service owns refill/promotion, so every durable order change must also
	# rebuild the service slots instead of waiting for a legacy UI callback.
	_refresh_customer_queue()
	_refresh_pancake_drag_sources()


func _on_production_shell_changed(_snapshot: Dictionary = {}) -> void:
	# Production ticks can arrive every frame. They must not rebuild the order
	# card/portrait tree; only the production-dependent shell is refreshed.
	_refresh_pending_payment_button()
	_refresh_attention_rail()
	_refresh_pancake_drag_sources()


func _all_material_slots() -> Array[Node]:
	var result: Array[Node] = []
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
	for slot in _all_material_slots():
		var area_id := &"area.youtiao" if slot.source_kind == &"youtiao_dough" else &"area.fresh_soy_milk"
		var unlocked: bool = _id_in(unlocked_areas, area_id) and (slot.recipe_id.is_empty() or _id_in(unlocked_recipes, slot.recipe_id))
		var status := Dictionary(session.call("five_area_restock_status", slot.stock_id)) if not slot.stock_id.is_empty() else {}
		slot.apply_state(int(inventory.get(str(slot.stock_id), 0)), unlocked, int(status.get("capacity", 6)))
	var fixed_slots: Array[Node] = youtiao_dough_slots
	for index in fixed_slots.size():
		var slot := fixed_slots[index]
		var area_id := &"area.youtiao" if slot.source_kind == &"youtiao_dough" else &"area.fresh_soy_milk"
		var unlocked: bool = _id_in(unlocked_areas, area_id) and _id_in(unlocked_recipes, slot.recipe_id)
		# The countertop art contains the physical ingredients.  These former
		# bottom-dock controls are intentionally removed from the workbench view.
		slot.visible = false
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if index < fixed_material_lock_artworks.size():
			fixed_material_lock_artworks[index].visible = false
		if index < fixed_material_lock_buttons.size():
			fixed_material_lock_buttons[index].visible = false
			fixed_material_lock_buttons[index].mouse_filter = Control.MOUSE_FILTER_IGNORE


func _refresh_formal_area_visibility() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null or not session.has_method("five_area_progression_snapshot"):
		return
	# Purchasing an area broadcasts a progression update immediately, while the
	# purchase itself remains pending until the next business day.  Keep both
	# station previews visible during the workshop so that update cannot remove
	# the just-reserved soy machine from under its purchase status.
	if _upgrade_workshop != null and _upgrade_workshop.visible:
		fresh_soy_station.set_workshop_preview(true)
		cartoon_youtiao_fryer.set_workshop_preview(true)
		return
	var progression := Dictionary(session.call("five_area_progression_snapshot"))
	var unlocked_areas := Array(progression.get("unlocked_area_ids", []))
	_set_formal_area_visible(cartoon_youtiao_fryer, _id_in(unlocked_areas, &"area.youtiao"))
	_set_formal_area_visible(fresh_soy_station, _id_in(unlocked_areas, &"area.fresh_soy_milk"))


static func _set_formal_area_visible(area_node: Control, unlocked: bool) -> void:
	area_node.visible = unlocked
	area_node.mouse_behavior_recursive = (
		Control.MOUSE_BEHAVIOR_INHERITED
		if unlocked
		else Control.MOUSE_BEHAVIOR_DISABLED
	)


func _on_global_status_changed(value: Variant = null) -> void:
	super._on_global_status_changed(value)
	_refresh_formal_area_visibility()


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
		cartoon_youtiao_fryer.select_recipe(StringName(source_ref.get("recipe_id", &"")))


func place_youtiao_source_on_pancake(source_ref: Dictionary, viewport_position: Vector2) -> void:
	if StringName(source_ref.get("product_id", &"")) != &"product.youtiao.plain" or StringName(source_ref.get("source_kind", &"")) != &"prepared_product_slot":
		tool_status_label.text = "油条需先整锅收纳，再从成品区逐根加入煎饼"
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
		return StringName(_pending_youtiao_ingredient_source_ref.get("source_kind", &"")) == &"prepared_product_slot" and bool(Dictionary(session.call("preview_take_prepared_product", StringName(_pending_youtiao_ingredient_source_ref.get("source_slot_id", &"")), int(_pending_youtiao_ingredient_source_ref.get("source_index", 0)))).get("success", false))
	return super._ingredient_available_for_drag(ingredient_type)


func _consume_dragged_ingredient(ingredient_type: StringName) -> bool:
	if ingredient_type == IngredientModel.YOUTIAO:
		var session := get_node_or_null("/root/GameSession")
		if session == null:
			return false
		return StringName(_pending_youtiao_ingredient_source_ref.get("source_kind", &"")) == &"prepared_product_slot" and bool(Dictionary(session.call("take_prepared_product", StringName(_pending_youtiao_ingredient_source_ref.get("source_slot_id", &"")), int(_pending_youtiao_ingredient_source_ref.get("source_index", 0)))).get("success", false))
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
				return {"target": _tutorial_delivery_target(session, area_id), "message": "点击订单中的油条，从成品区逐根交付"}
			var machine := Dictionary(session.call("f3_machine_snapshot", &"device.youtiao_fryer"))
			match StringName(machine.get("state", &"idle")):
				&"idle":
					return {"target": cartoon_youtiao_fryer.start_button, "message": "长按油条机添加面胚；基础炸篮共4格"}
				&"loaded":
					var quantity := int(machine.get("quantity", 0))
					var capacity := int(machine.get("capacity", 2))
					var message := "已装%d/%d，点击启动" % [quantity, capacity] if quantity >= capacity else "已装%d/%d，可再放一份或直接启动" % [quantity, capacity]
					return {"target": cartoon_youtiao_fryer.start_button, "message": message}
				&"frying": return {"target": cartoon_youtiao_fryer.state_label, "message": "等待炸制完成，留意设备状态"}
				&"ready_safe", &"overcooking": return {"target": cartoon_youtiao_fryer.lift_button, "message": "及时升篮"}
				&"burnt": return {"target": cartoon_youtiao_fryer.output_sources[0], "message": "把整锅焦糊油条拖到废弃区"}
				&"draining": return {"target": cartoon_youtiao_fryer.state_label, "message": "等待沥油完成"}
				&"ready_to_collect":
					return {"target": cartoon_youtiao_fryer.output_sources[0], "message": "把炸篮中的油条逐根拖到顾客订单或成品盘"}
		&"area.fresh_soy_milk":
			var machine := Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine"))
			match StringName(machine.get("state", &"idle")):
				&"ready": return {"target": fresh_soy_station.machine_output, "message": "点击空杯，拿到出浆口"}
				&"held_empty": return {"target": fresh_soy_station.nozzle_button, "message": "按住出浆口 0.8 秒接满豆浆"}
				&"filled": return {"target": fresh_soy_station.sugar_jar, "message": "按订单选择无糖、正常糖或多糖，再拖杯交付"}
		&"area.pancake":
			if _multi_griddle_mode_active:
				return _tutorial_pancake_griddle_guide(session, area_id)
			match p1_session.phase:
				P1Session.Phase.SPREAD: return {"target": ladle_button, "message": "舀取面糊，在鏊面摊成完整饼皮"}
				P1Session.Phase.FIRST_SIDE, P1Session.Phase.SECOND_SIDE: return {"target": step_action_button, "message": "观察火候并在合适时机翻面或确认"}
				P1Session.Phase.SAUCE_AND_FILLINGS: return {"target": sauce_brush_button, "message": "刷酱并按订单加入配料"}
				P1Session.Phase.FOLD: return {"target": fold_button, "message": "选择折叠工具并完成折叠"}
				P1Session.Phase.PACKAGE: return {"target": paper_sleeve_button, "message": "选择可用包装完成打包"}
				P1Session.Phase.READY_TO_SERVE: return {"target": _tutorial_delivery_target(session, area_id), "message": "点击订单商品交付经典煎饼"}
	return {}


func _tutorial_pancake_griddle_guide(session: Node, area_id: StringName) -> Dictionary:
	if multi_griddle_station.units.is_empty():
		return {}
	var griddle := multi_griddle_station.units[0] as CompactGriddleUnit
	if griddle == null:
		return {}
	match griddle.state:
		CompactGriddleUnit.State.IDLE:
			return {
				"target": _pancake_worktop_target("BatterLadleHolderHotspot", griddle),
				"message": "第1步：按住面糊勺，拖到空鏊子倒入面糊",
			}
		CompactGriddleUnit.State.BATTER:
			return {
				"target": griddle.pancake_surface,
				"message": "第2步：用摊饼器在鏊面画圈，把面糊摊成完整饼皮",
			}
		CompactGriddleUnit.State.FIRST_SIDE:
			if not griddle.pancake_model.has_egg():
				return {
					"target": _pancake_worktop_target("EggCarton/Hotspot", griddle.pancake_surface),
					"message": "第3步：把鸡蛋拖到饼面，再用摊饼器把蛋液摊开",
				}
			var first_side_heat := Dictionary(griddle.cooking_heat_status())
			if bool(first_side_heat.get("charred", false)):
				return {"target": griddle.main_action, "message": "第一面已焦糊：请立刻点击“翻面”，火候分已下降"}
			if bool(first_side_heat.get("flip_ready", false)):
				return {"target": griddle.main_action, "message": "第4步：现在可翻面，点击“翻面”"}
			return {"target": griddle.heat_status_label, "message": "第4步：观察火候计时，出现“现在可翻面”后再点击翻面"}
		CompactGriddleUnit.State.SECOND_SIDE:
			var second_side_heat := Dictionary(griddle.cooking_heat_status())
			if bool(second_side_heat.get("charred", false)):
				return {"target": griddle.heat_status_label, "message": "第二面已焦糊：立即从饼边开始折叠，火候分已下降"}
			return {"target": griddle.pancake_surface, "message": "第5步：第二面继续受热；从饼边向内拖动，完成两次折叠"}
		CompactGriddleUnit.State.GARNISH, CompactGriddleUnit.State.FOLDING:
			return {"target": griddle.pancake_surface, "message": "第5步：从饼边向内拖动，完成两次折叠并装袋"}
		CompactGriddleUnit.State.READY:
			return {"target": _tutorial_delivery_target(session, area_id), "message": "第6步：把完成的煎饼拖到订单商品上交付"}
	return {}


func _pancake_worktop_target(path: String, fallback: Control) -> Control:
	if pancake_worktop_hotspots == null:
		return fallback
	var target := pancake_worktop_hotspots.get_node_or_null(NodePath(path)) as Control
	return target if target != null else fallback


func _tutorial_delivery_target(session: Node, area_id: StringName) -> Control:
	if session == null or not session.has_method("active_formal_order"):
		return null
	var order := Dictionary(session.call("active_formal_order"))
	var order_id := StringName(order.get("order_id", &""))
	if order_id.is_empty():
		return null
	var items := Array(order.get("items", []))
	for item_index in range(items.size()):
		var item := Dictionary(items[item_index])
		if StringName(item.get("area_id", &"")) != area_id:
			continue
		var attached_count := Array(item.get("prepared_product_instance_ids", [])).size()
		if attached_count >= maxi(int(item.get("quantity", 1)), 1):
			continue
		for service_slot in customer_service_slots:
			if not service_slot.has_method("delivery_target"):
				continue
			var target := service_slot.call("delivery_target", order_id, item_index) as Control
			if target != null:
				return target
	return null


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


func _refresh_multi_griddle_mode() -> void:
	if not is_node_ready():
		return
	_multi_griddle_mode_active = true
	multi_griddle_station.visible = true
	multi_griddle_station.process_mode = Node.PROCESS_MODE_INHERIT
	multi_griddle_station.set_griddle_count(1)
	_apply_multi_griddle_legacy_visibility()
	# Every compact griddle owns a dedicated discard action. The compact target
	# inside the youtiao station remains available for fryer and soy waste.
	if waste_area != null:
		waste_area.visible = true
	if pancake_ready_source != null:
		pancake_ready_source.visible = false
	var legacy_discard := get_node_or_null("SafeArea/DiscardCurrentPancakeButton") as CanvasItem
	if legacy_discard != null:
		legacy_discard.visible = false


func _apply_multi_griddle_legacy_visibility() -> void:
	if not _multi_griddle_mode_active:
		return
	for legacy_path in ["SafeArea/PanBase", "SafeArea/LeftRack", "SafeArea/RightRack", "SafeArea/IngredientRack", "SafeArea/MaterialDock", "SafeArea/P1ControlBar", "SafeArea/PhaseLabel"]:
		var legacy_control := get_node_or_null(legacy_path) as Control
		if legacy_control != null:
			legacy_control.visible = false
			legacy_control.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	_hide_unused_worktop_locks()


func _hide_unused_worktop_locks() -> void:
	var retained_lock_names := {
		&"Slot01": true, &"Slot02": true, &"Slot03": true,
		&"Slot04": true, &"Slot05": true, &"Slot06": true,
	}
	var old_artwork := get_node_or_null("SafeArea/LockedIngredientArtwork")
	if old_artwork != null:
		for child in old_artwork.get_children():
			if child is CanvasItem and not retained_lock_names.has(StringName(child.name)):
				child.visible = false
	var old_interactions := get_node_or_null("SafeArea/LockedIngredientInteractions")
	if old_interactions != null:
		for child in old_interactions.get_children():
			var slot_name := str(child.name).trim_suffix("LockedButton")
			if child is Control and not retained_lock_names.has(StringName(slot_name)):
				child.visible = false
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _refresh_p1_ui() -> void:
	super._refresh_p1_ui()
	_raise_result_presentation_input()
	_refresh_five_area_modal_input()
	if not _multi_griddle_mode_active:
		return
	_apply_multi_griddle_legacy_visibility()
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
		if pancake_ready_source != null:
			pancake_ready_source.visible = false
		return
	if pancake_ready_source == null:
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
		pancake_holding_sources[slot_index].configure({"source_kind": &"pancake_holding", "source_index": slot_index, "product_id": StringName(product.get("product_id", &"")), "discardable": true}, PRODUCT_VISUALS.texture_for(&"product.pancake.custom"), not product.is_empty(), "暂存煎饼可交付；点击订单商品图标取用，或拖入废弃篓")
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
	_try_deliver_order_item(_formal_order_id, item_index)
	_delivery_click_in_progress = false
	_refresh_formal_shell()


func _try_deliver_order_item(order_id: StringName, item_index: int) -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null or order_id.is_empty():
		tool_status_label.text = "当前没有可交付的顾客订单"
		return
	var order := Dictionary(session.call("formal_order", order_id))
	var items := Array(order.get("items", []))
	if item_index < 0 or item_index >= items.size():
		tool_status_label.text = "该订单商品格为空"
		return
	var item := Dictionary(items[item_index])
	if Array(item.get("prepared_product_instance_ids", [])).size() >= maxi(int(item.get("quantity", 1)), 1):
		tool_status_label.text = "该订单商品已经交付，不能重复提交"
		_refresh_order_card_ui(order, _formal_order_patience_ratio(order))
		return
	var chosen := _delivery_source_for_item(session, order_id, order, item_index)
	if chosen.is_empty():
		tool_status_label.text = _missing_delivery_source_text(StringName(item.get("area_id", &"")))
		return
	var source_ref := Dictionary(chosen.get("source_ref", {}))
	var staged := Dictionary(session.call("stage_product_to_order", source_ref, order_id, item_index))
	if not bool(staged.get("success", false)):
		tool_status_label.text = "交付失败，成品未被消耗：%s" % str(staged.get("reason", &"unknown"))
		_refresh_formal_shell()
		return
	_on_clicked_product_consumed(source_ref)
	var refreshed := Dictionary(session.call("formal_order", order_id))
	if not _formal_order_items_complete(refreshed):
		var suffix := "（餐品与要求不符，结算时会扣分）" if not bool(staged.get("will_match", false)) else ""
		tool_status_label.text = "已交付第 %d 项%s；请继续点击剩余商品" % [item_index + 1, suffix]
		_refresh_order_card_ui(refreshed, _formal_order_patience_ratio(refreshed))
		return
	var completed := Dictionary(session.call("complete_order_delivery", order_id))
	if not bool(completed.get("success", false)):
		tool_status_label.text = "订单完成失败：%s" % str(completed.get("reason", &"unknown"))
		return
	_finish_clicked_order(completed)


func _delivery_source_for_item(session: Node, order_id: StringName, order: Dictionary, item_index: int) -> Dictionary:
	var items := Array(order.get("items", []))
	if item_index < 0 or item_index >= items.size():
		return {}
	var target_area := StringName(Dictionary(items[item_index]).get("area_id", &""))
	var fallback := {}
	for source_ref in _available_delivery_source_refs():
		var preview := Dictionary(session.call("preview_stage_product_to_order", source_ref, order_id, item_index))
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
	cartoon_youtiao_fryer.refresh_from_session()
	_refresh_pancake_drag_sources()
	var result: Array[Dictionary] = []
	# A completed pancake is business state, not presentation state.  Keep its
	# full product snapshot available to click delivery even if the drag source
	# has not completed a visibility/disabled refresh on this frame.
	result.append_array(multi_griddle_station.ready_source_refs())
	var sources: Array[ProductDragSource] = []
	sources.append_array(pancake_holding_sources)
	sources.append_array(cartoon_youtiao_fryer.output_sources)
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
		for slot_id in [&"slot.04"]:
			var status := Dictionary(session.call("prepared_product_slot_status", slot_id))
			if bool(status.get("success", false)) and int(status.get("count", 0)) > 0:
				# A finished tray can contain both plain and sesame youtiao.  Each
				# stored product needs its own source index; using the legacy -1
				# shortcut always previews index 0 and makes later matching products
				# invisible to click delivery.
				var products := Array(status.get("products", []))
				for source_index in range(products.size()):
					var product := Dictionary(products[source_index])
					result.append({
						"source_kind": &"prepared_product_slot",
						"source_slot_id": slot_id,
						"source_index": source_index,
						"product_id": StringName(product.get("product_id", &"")),
					})
	return result


func _on_clicked_product_consumed(source_ref: Dictionary) -> void:
	if StringName(source_ref.get("source_kind", &"")) == &"pancake_griddle_ready":
		multi_griddle_station.consume_ready(int(source_ref.get("source_index", -1)))
	_refresh_pancake_drag_sources()
	cartoon_youtiao_fryer.refresh_from_session()
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
	if earned > 0:
		_show_formal_payment_coins(earned)
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
	if _formal_payment_collection_active:
		return
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return
	var collected := Dictionary(session.call("collect_all_pending_order_payments"))
	if not bool(collected.get("success", false)):
		tool_status_label.text = "收币失败：%s" % str(collected.get("reason", &"unknown"))
		return
	var amount := int(collected.get("amount", 0))
	var collected_coins: Array[TextureRect] = []
	for coin in _formal_payment_coin_sprites:
		if is_instance_valid(coin):
			collected_coins.append(coin)
	_formal_payment_coin_sprites.clear()
	_play_formal_payment_collection_feedback(amount, collected_coins, _formal_payment_should_reduce_motion())


func _play_formal_payment_collection_feedback(
	amount: int,
	collected_coins: Array[TextureRect],
	reduce_motion: bool
) -> void:
	_formal_payment_collection_active = true
	_refresh_pending_payment_button()
	var origin := _formal_payment_collection_origin(collected_coins)
	var target := _formal_payment_collection_target()
	_show_formal_payment_collection_burst(origin, reduce_motion)
	_show_formal_payment_reward(amount, origin, reduce_motion)
	if collected_coins.is_empty():
		_show_formal_payment_target_impact(target, true, reduce_motion)
		var fallback_tween := create_tween()
		fallback_tween.tween_interval(FORMAL_PAYMENT_COIN_LAUNCH_SECONDS)
		fallback_tween.tween_callback(_complete_formal_payment_collection.bind(amount, collected_coins, reduce_motion))
		tool_status_label.text = "收取中：%d 金币正在入账" % amount
		return
	for index in range(collected_coins.size()):
		var coin := collected_coins[index]
		_play_formal_payment_collection_flight(
			coin,
			target,
			index,
			index == collected_coins.size() - 1,
			amount,
			collected_coins,
			reduce_motion
		)
	tool_status_label.text = "收取中：%d 金币正在入账" % amount


func _formal_payment_collection_origin(coins: Array[TextureRect]) -> Vector2:
	var total := Vector2.ZERO
	var visible_coin_count := 0
	for coin in coins:
		if is_instance_valid(coin):
			total += coin.get_global_rect().get_center()
			visible_coin_count += 1
	return total / float(visible_coin_count) if visible_coin_count > 0 else pending_payment_button.get_global_rect().get_center()


func _formal_payment_collection_target() -> Vector2:
	var status_rect := global_status_label.get_global_rect()
	return status_rect.position + Vector2(78.0, status_rect.size.y * 0.5)


func _play_formal_payment_collection_flight(
	coin: TextureRect,
	target: Vector2,
	index: int,
	is_last: bool,
	amount: int,
	coins: Array[TextureRect],
	reduce_motion: bool
) -> void:
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.z_index = 125
	coin.pivot_offset = coin.size * 0.5
	var stagger_delay := float(index) * FORMAL_PAYMENT_COIN_STAGGER_SECONDS
	coin.set_meta(&"formal_payment_stagger_delay", stagger_delay)
	if reduce_motion:
		var reduced_tween := create_tween()
		if stagger_delay > 0.0:
			reduced_tween.tween_interval(stagger_delay)
		reduced_tween.tween_property(coin, "modulate:a", 0.0, FORMAL_PAYMENT_REDUCED_FADE_SECONDS).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		reduced_tween.tween_callback(_on_formal_payment_coin_arrived.bind(coin, target, index, is_last, amount, coins, reduce_motion))
		return
	var start_position := coin.global_position
	var spread := _formal_payment_launch_spread(index, coins.size())
	var launch_position := start_position + Vector2(spread * (38.0 + float(index % 3) * 6.0), -48.0 - float(index % 2) * 10.0)
	var destination := target - coin.size * 0.5 + Vector2(float(index % 3 - 1) * 10.0, float(index % 2) * 4.0)
	var arc_control := launch_position.lerp(destination, 0.46) + Vector2(float(index % 3 - 1) * 34.0, -92.0 - float(index % 2) * 18.0)
	var spin_direction := -1.0 if index % 2 == 0 else 1.0
	var launch_rotation := spin_direction * 0.24
	var coin_tween := create_tween()
	if stagger_delay > 0.0:
		coin_tween.tween_interval(stagger_delay)
	coin_tween.tween_property(coin, "global_position", launch_position, FORMAL_PAYMENT_COIN_LAUNCH_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	coin_tween.parallel().tween_property(coin, "scale", Vector2(1.46, 1.46), FORMAL_PAYMENT_COIN_LAUNCH_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	coin_tween.parallel().tween_property(coin, "rotation", launch_rotation, FORMAL_PAYMENT_COIN_LAUNCH_SECONDS).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	coin_tween.chain().tween_method(
		_set_formal_payment_coin_flight_position.bind(coin, launch_position, arc_control, destination),
		0.0,
		1.0,
		FORMAL_PAYMENT_COIN_FLIGHT_SECONDS
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	coin_tween.parallel().tween_property(coin, "scale", Vector2(0.62, 0.62), FORMAL_PAYMENT_COIN_FLIGHT_SECONDS).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	coin_tween.parallel().tween_property(coin, "rotation", launch_rotation + spin_direction * TAU * 0.85, FORMAL_PAYMENT_COIN_FLIGHT_SECONDS).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	coin_tween.parallel().tween_property(coin, "modulate:a", 0.0, 0.08).set_delay(FORMAL_PAYMENT_COIN_FLIGHT_SECONDS - 0.08).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	coin_tween.chain().tween_callback(_on_formal_payment_coin_arrived.bind(coin, target, index, is_last, amount, coins, reduce_motion))


func _formal_payment_launch_spread(index: int, coin_count: int) -> float:
	if coin_count <= 1:
		return 0.0
	match index % 5:
		0:
			return -0.70
		1:
			return 0.70
		2:
			return 0.0
		3:
			return -1.0
		4:
			return 1.0
	return 0.0


func _set_formal_payment_coin_flight_position(
	progress: float,
	coin: TextureRect,
	start_position: Vector2,
	control_position: Vector2,
	end_position: Vector2
) -> void:
	if not is_instance_valid(coin):
		return
	var inverse := 1.0 - progress
	coin.global_position = inverse * inverse * start_position \
		+ 2.0 * inverse * progress * control_position \
		+ progress * progress * end_position


func _on_formal_payment_coin_arrived(
	coin: TextureRect,
	target: Vector2,
	index: int,
	is_last: bool,
	amount: int,
	coins: Array[TextureRect],
	reduce_motion: bool
) -> void:
	if is_instance_valid(coin):
		coin.visible = false
	_show_formal_payment_target_impact(target, is_last, reduce_motion)
	if is_last:
		_complete_formal_payment_collection(amount, coins, reduce_motion)


func _show_formal_payment_collection_burst(origin: Vector2, reduce_motion: bool) -> void:
	_spawn_formal_payment_ring(
		origin,
		132.0,
		1.62,
		FORMAL_PAYMENT_GOLD,
		&"origin_ring",
		reduce_motion
	)
	if reduce_motion:
		return
	for index in range(FORMAL_PAYMENT_BURST_SPARK_COUNT):
		var angle := -PI * 0.5 + TAU * float(index) / float(FORMAL_PAYMENT_BURST_SPARK_COUNT)
		var distance := 58.0 + float(index % 3) * 13.0
		_spawn_formal_payment_spark(origin, Vector2.RIGHT.rotated(angle), distance, index, &"origin_spark")


func _show_formal_payment_target_impact(target: Vector2, strong: bool, reduce_motion: bool) -> void:
	_spawn_formal_payment_ring(
		target,
		104.0 if strong else 62.0,
		1.70 if strong else 1.45,
		FORMAL_PAYMENT_GOLD_BRIGHT if strong else FORMAL_PAYMENT_GOLD,
		&"target_ring",
		reduce_motion
	)
	if reduce_motion or not strong:
		return
	for index in range(6):
		var angle := TAU * float(index) / 6.0
		_spawn_formal_payment_spark(target, Vector2.RIGHT.rotated(angle), 44.0, index, &"target_spark")


func _spawn_formal_payment_ring(
	center: Vector2,
	diameter: float,
	end_scale: float,
	color: Color,
	kind: StringName,
	reduce_motion: bool
) -> void:
	var ring := Panel.new()
	ring.name = "FormalCoinCollectionRing"
	ring.size = Vector2(diameter, diameter)
	ring.pivot_offset = ring.size * 0.5
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.z_index = 127
	ring.set_meta(&"formal_payment_fx_kind", kind)
	var ring_style := StyleBoxFlat.new()
	ring_style.bg_color = Color(color.r, color.g, color.b, 0.14)
	ring_style.border_color = color
	ring_style.set_border_width_all(5)
	ring_style.set_corner_radius_all(roundi(diameter * 0.5))
	ring.add_theme_stylebox_override(&"panel", ring_style)
	payment_coin_layer.add_child(ring)
	ring.global_position = center - ring.size * 0.5
	ring.scale = Vector2.ONE if reduce_motion else Vector2(0.90, 0.90)
	var ring_tween := create_tween()
	if reduce_motion:
		ring_tween.tween_property(ring, "modulate:a", 0.0, FORMAL_PAYMENT_REDUCED_FADE_SECONDS).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	else:
		ring_tween.tween_property(ring, "scale", Vector2(end_scale, end_scale), 0.24).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		ring_tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.14).set_delay(0.10).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	ring_tween.tween_callback(ring.queue_free)


func _spawn_formal_payment_spark(
	center: Vector2,
	direction: Vector2,
	distance: float,
	index: int,
	kind: StringName
) -> void:
	var spark := ColorRect.new()
	spark.name = "FormalCoinCollectionSpark"
	spark.size = Vector2(7.0 if index % 2 == 0 else 5.0, 18.0 if index % 2 == 0 else 13.0)
	spark.pivot_offset = spark.size * 0.5
	spark.color = FORMAL_PAYMENT_GOLD_BRIGHT if index % 2 == 0 else FORMAL_PAYMENT_GOLD
	spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spark.z_index = 128
	spark.rotation = direction.angle() + PI * 0.5
	spark.scale = Vector2(0.90, 0.90)
	spark.set_meta(&"formal_payment_fx_kind", kind)
	payment_coin_layer.add_child(spark)
	spark.global_position = center - spark.size * 0.5
	var spark_destination := center + direction * distance - spark.size * 0.5
	var spark_tween := create_tween()
	spark_tween.tween_property(spark, "global_position", spark_destination, 0.24).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	spark_tween.parallel().tween_property(spark, "scale", Vector2(0.72, 1.20), 0.24).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	spark_tween.parallel().tween_property(spark, "modulate:a", 0.0, 0.14).set_delay(0.10).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	spark_tween.tween_callback(spark.queue_free)


func _show_formal_payment_reward(amount: int, origin: Vector2, reduce_motion: bool) -> void:
	var reward_badge := PanelContainer.new()
	reward_badge.name = "FormalCoinCollectionReward"
	reward_badge.size = Vector2(320.0, 84.0)
	reward_badge.custom_minimum_size = reward_badge.size
	reward_badge.z_index = 124
	reward_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_badge.set_meta(&"formal_payment_fx_kind", &"reward_badge")
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.20, 0.08, 0.01, 0.92)
	badge_style.border_color = FORMAL_PAYMENT_GOLD
	badge_style.set_border_width_all(3)
	badge_style.set_corner_radius_all(24)
	badge_style.shadow_color = Color(0.08, 0.02, 0.0, 0.50)
	badge_style.shadow_size = 10
	badge_style.shadow_offset = Vector2(0.0, 5.0)
	reward_badge.add_theme_stylebox_override(&"panel", badge_style)
	var reward_label := Label.new()
	reward_label.name = "Amount"
	reward_label.text = "+%d 金币" % amount
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reward_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_label.add_theme_color_override(&"font_color", FORMAL_PAYMENT_GOLD_BRIGHT)
	reward_label.add_theme_color_override(&"font_outline_color", Color(0.18, 0.06, 0.0, 0.98))
	reward_label.add_theme_constant_override(&"outline_size", 8)
	reward_label.add_theme_font_size_override(&"font_size", 50)
	reward_badge.add_child(reward_label)
	payment_coin_layer.add_child(reward_badge)
	var shown_position := origin - Vector2(reward_badge.size.x * 0.5, 124.0)
	var start_position := shown_position + Vector2(0.0, 16.0)
	reward_badge.pivot_offset = reward_badge.size * 0.5
	reward_badge.global_position = shown_position if reduce_motion else start_position
	reward_badge.scale = Vector2.ONE if reduce_motion else Vector2(0.94, 0.94)
	reward_badge.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var reward_tween := create_tween()
	if reduce_motion:
		reward_tween.tween_property(reward_badge, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		reward_tween.tween_interval(0.12)
		reward_tween.tween_property(reward_badge, "modulate:a", 0.0, FORMAL_PAYMENT_REWARD_EXIT_SECONDS).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	else:
		reward_tween.tween_property(reward_badge, "global_position", shown_position, FORMAL_PAYMENT_REWARD_POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		reward_tween.parallel().tween_property(reward_badge, "scale", Vector2(1.16, 1.16), FORMAL_PAYMENT_REWARD_POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		reward_tween.parallel().tween_property(reward_badge, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		reward_tween.chain().tween_interval(0.12)
		reward_tween.tween_property(reward_badge, "global_position", shown_position - Vector2(0.0, 42.0), FORMAL_PAYMENT_REWARD_EXIT_SECONDS).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		reward_tween.parallel().tween_property(reward_badge, "scale", Vector2.ONE, FORMAL_PAYMENT_REWARD_EXIT_SECONDS).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		reward_tween.parallel().tween_property(reward_badge, "modulate:a", 0.0, FORMAL_PAYMENT_REWARD_EXIT_SECONDS).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	reward_tween.tween_callback(reward_badge.queue_free)


func _complete_formal_payment_collection(amount: int, coins: Array[TextureRect], reduce_motion: bool) -> void:
	for coin in coins:
		if is_instance_valid(coin):
			coin.queue_free()
	_pulse_formal_coin_total(reduce_motion, _finish_formal_payment_collection.bind(amount))


func _finish_formal_payment_collection(amount: int) -> void:
	_formal_payment_collection_active = false
	_refresh_pending_payment_button()
	tool_status_label.text = "已收取 %d 金币；当前顾客订单继续" % amount


func _pulse_formal_coin_total(reduce_motion: bool = false, finished_callback: Callable = Callable()) -> void:
	if _formal_payment_total_pulse_tween != null and _formal_payment_total_pulse_tween.is_valid():
		_formal_payment_total_pulse_tween.kill()
	global_status_label.modulate = _formal_payment_total_rest_modulate
	_formal_payment_total_pulse_tween = create_tween()
	if reduce_motion:
		global_status_label.modulate = FORMAL_PAYMENT_GOLD_BRIGHT
		_formal_payment_total_pulse_tween.tween_property(global_status_label, "modulate", _formal_payment_total_rest_modulate, 0.20).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		if finished_callback.is_valid():
			_formal_payment_total_pulse_tween.tween_callback(finished_callback)
		return
	_formal_payment_total_pulse_tween.tween_property(global_status_label, "modulate", FORMAL_PAYMENT_GOLD_BRIGHT, 0.12).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_formal_payment_total_pulse_tween.tween_property(global_status_label, "modulate", _formal_payment_total_rest_modulate, 0.20).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	if finished_callback.is_valid():
		_formal_payment_total_pulse_tween.tween_callback(finished_callback)


func _formal_payment_should_reduce_motion() -> bool:
	return DisplayServer.has_method(&"accessibility_should_reduce_motion") \
		and bool(DisplayServer.call(&"accessibility_should_reduce_motion"))


func _collect_tray_payment() -> void:
	_collect_pending_payments()


func _restore_pending_payment() -> void:
	_clear_formal_payment_coins()
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("pending_order_payments"):
		for payment_value in Array(session.call("pending_order_payments")):
			_show_formal_payment_coins(maxi(int(Dictionary(payment_value).get("amount", 0)), 0))
	_refresh_pending_payment_button()


func _show_formal_payment_coins(amount: int) -> void:
	for denomination in PAYMENT_COIN_MODEL_SCRIPT.decompose(amount):
		var coin := payment_sprite.duplicate() as TextureRect
		if coin == null:
			continue
		var texture := PAYMENT_COIN_TEXTURES.get(denomination, payment_sprite.texture) as Texture2D
		coin.name = "FormalPaymentCoin%d_%d" % [denomination, _formal_payment_coin_sprites.size()]
		coin.unique_name_in_owner = false
		coin.texture = texture
		coin.position = _formal_payment_coin_target(_formal_payment_coin_sprites.size())
		coin.size = FORMAL_PAYMENT_COIN_SIZE
		coin.visible = true
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin.tooltip_text = "%d 金币待收取" % denomination
		payment_coin_layer.add_child(coin)
		_formal_payment_coin_sprites.append(coin)


func _clear_formal_payment_coins() -> void:
	for coin in _formal_payment_coin_sprites:
		if is_instance_valid(coin):
			coin.queue_free()
	_formal_payment_coin_sprites.clear()


func _formal_payment_coin_target(index: int) -> Vector2:
	var column := index % FORMAL_PAYMENT_COIN_MAX_COLUMNS
	var row := floori(float(index) / float(FORMAL_PAYMENT_COIN_MAX_COLUMNS))
	return FORMAL_PAYMENT_COIN_ORIGIN + Vector2(
		float(column) * FORMAL_PAYMENT_COIN_COLUMN_SPACING,
		float(row) * FORMAL_PAYMENT_COIN_ROW_SPACING,
	)


func _refresh_pending_payment_button() -> void:
	var pending_total := _pending_payment_total()
	var has_pending_payment := pending_total > 0 and not _workshop_payment_display_hidden
	var can_collect := has_pending_payment and not _formal_payment_collection_active
	pending_payment_button.visible = has_pending_payment
	pending_payment_button.disabled = not can_collect
	pending_payment_button.mouse_filter = Control.MOUSE_FILTER_STOP if can_collect else Control.MOUSE_FILTER_IGNORE
	pending_payment_button.text = "金币 ×%d\n点击全部收取" % pending_total
	pending_payment_button.tooltip_text = "收取所有尚未领取的顾客付款" if pending_total > 0 else "当前没有待收金币"


func _set_upgrade_workshop_preview(enabled: bool) -> void:
	_workshop_payment_display_hidden = enabled
	super._set_upgrade_workshop_preview(enabled)
	_refresh_pending_payment_button()


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
		cartoon_youtiao_fryer.refresh_from_session()
	else:
		tool_status_label.text = "餐品回到原处：%s" % str(result.get("reason", &"unknown"))


func _on_waste_product_source_discarded(source_ref: Dictionary) -> void:
	if StringName(source_ref.get("source_kind", &"")) != &"pancake_griddle_ready":
		return
	var source_index := int(source_ref.get("source_index", -1))
	if source_index >= 0 and multi_griddle_station != null:
		multi_griddle_station.consume_ready(source_index)


func _on_waste_active_griddle_clear_requested() -> void:
	if multi_griddle_station == null:
		return
	var result := Dictionary(multi_griddle_station.reset_active())
	if bool(result.get("success", false)):
		tool_status_label.text = "已废弃当前煎饼；原料不返还，请重新添面糊"


func _show_station_status(message: String) -> void:
	tool_status_label.text = message


func _show_top_warning(message: String) -> void:
	if top_warning_label == null:
		return
	if _top_warning_tween != null and _top_warning_tween.is_valid():
		_top_warning_tween.kill()
	top_warning_label.text = message
	top_warning_label.modulate = Color.WHITE
	top_warning_label.visible = true
	_top_warning_tween = create_tween()
	_top_warning_tween.tween_interval(TOP_WARNING_DURATION_SECONDS)
	if _formal_payment_should_reduce_motion():
		_top_warning_tween.tween_callback(func() -> void: top_warning_label.visible = false)
		return
	_top_warning_tween.tween_property(top_warning_label, "modulate:a", 0.0, TOP_WARNING_FADE_SECONDS).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_top_warning_tween.tween_callback(func() -> void: top_warning_label.visible = false)


static func _tray_result_summary(settlement: Dictionary) -> Dictionary:
	var summary := settlement.duplicate(true)
	var item_results := Array(settlement.get("item_results", []))
	var primary_result := Dictionary(item_results[0]) if not item_results.is_empty() else {}
	var product := Dictionary(primary_result.get("product", {}))
	var feedback_items := _delivery_feedback_items(item_results)
	summary["score"] = float(product.get("score", 100.0 if bool(settlement.get("order_success", false)) else 0.0))
	summary["dimensions"] = Dictionary(product.get("dimension_scores", {})).duplicate(true)
	summary["product_id"] = StringName(product.get("product_id", &"product.pancake.custom"))
	summary["display_product"] = product.duplicate(true)
	summary["display_item"] = primary_result.duplicate(true)
	summary["tags"] = feedback_items
	if feedback_items.is_empty():
		summary["feedback"] = "顾客已收到完整订单"
	else:
		summary["feedback"] = "顾客指出：%s" % "、".join(feedback_items)
	return summary


static func _delivery_feedback_items(item_results: Array) -> PackedStringArray:
	var feedback_items := PackedStringArray()
	for item_result_value in item_results:
		var item_result := Dictionary(item_result_value)
		var expected_product := _product_label(StringName(item_result.get("product_id", &"")))
		var actual_product := _product_label(StringName(Dictionary(item_result.get("product", {})).get("product_id", &"")))
		for reason_value in Array(item_result.get("mismatch_reasons", [])):
			var feedback := _delivery_feedback_text(StringName(reason_value), expected_product, actual_product)
			if not feedback.is_empty() and not feedback_items.has(feedback):
				feedback_items.append(feedback)
	return feedback_items


static func _delivery_feedback_text(reason: StringName, expected_product: String, actual_product: String) -> String:
	match reason:
		&"missing_order_item", &"incomplete_quantity": return "%s未按订单交齐" % expected_product
		&"product_id": return "交付的%s与订单要求的%s不符" % [actual_product, expected_product]
		&"heat_preference": return "%s火候不符合订单要求" % expected_product
		&"temperature_mode": return "%s温度不符合订单要求" % expected_product
		&"ingredient_ids": return "%s配料与订单要求不符" % expected_product
		&"sauce_ids": return "%s酱料与订单要求不符" % expected_product
		&"sugar_servings": return "%s糖量不符合订单要求" % expected_product
		_: return "交付的%s不符合订单要求" % expected_product


static func _product_label(product_id: StringName) -> String:
	if product_id == &"product.pancake.custom":
		return "煎饼"
	var definition := CATALOG.product_definition(product_id)
	return str(definition.get("label", "餐品"))


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
