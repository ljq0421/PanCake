class_name FiveAreaWorkstation
extends "res://scripts/gameplay/workstation.gd"

const PRODUCT_VISUALS := preload("res://scripts/ui/five_area_product_visuals.gd")
const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const PAYMENT_COIN_MODEL_SCRIPT := preload("res://scripts/gameplay/payment_coin_model.gd")
const UI_SCALE_APPLIER := preload("res://scripts/ui/ui_scale_applier.gd")
const PANCAKE_RECIPE_MARKER_TEXTURES := {
	&"stock.pancake.egg": preload("res://resources/art/ingredients/egg/egg_intact_raw_v1_five_area_v2.png"),
	&"stock.pancake.baocui": preload("res://resources/art/ingredients/baocui/baocui_intact_v1.png"),
	&"stock.pancake.scallion": preload("res://resources/art/ingredients/scallion/scallion_scattered_v1_five_area_v2.png"),
	&"stock.pancake.ham_sausage": preload("res://resources/art/ingredients/ham_sausage/ham_sausage_slices_v1.png"),
	&"stock.pancake.meat_floss": preload("res://resources/art/ingredients/meat_floss/meat_floss_pile_v1.png"),
	&"stock.pancake.coriander": preload("res://resources/art/ingredients/coriander/coriander_scattered_five_area_v2.png"),
	&"stock.pancake.youtiao": preload("res://resources/art/products/youtiao/plain_youtiao_v1_five_area_v3.png"),
	&"stock.pancake.sauce.sweet_flour": preload("res://resources/art/ingredients/condiments/sweet-bean-sauce-jar-no-brush.png"),
}
const PANCAKE_RECIPE_MARKER_LABELS := {
	&"stock.pancake.egg": "鸡蛋",
	&"stock.pancake.baocui": "薄脆",
	&"stock.pancake.scallion": "葱花",
	&"stock.pancake.ham_sausage": "火腿",
	&"stock.pancake.meat_floss": "肉松",
	&"stock.pancake.coriander": "香菜",
	&"stock.pancake.youtiao": "油条",
	&"stock.pancake.preserved_mustard": "榨菜",
	&"stock.pancake.pork_tenderloin": "里脊",
	&"stock.pancake.sauce.sweet_flour": "甜面酱",
}
const PANCAKE_RECIPE_MARKER_VISIBLE_LIMIT := 3
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
const PANCAKE_EGG_STOCK_ID := &"stock.pancake.egg"
const QUALITY_COMPLAINT_THRESHOLD := 80.0
const FEEDBACK_METRIC_ORDER := {
	&"thickness": 0,
	&"heat": 1,
	&"egg": 2,
	&"sauce": 3,
	&"ingredients": 4,
	&"order": 5,
	&"time": 6,
}
const PAYMENT_COIN_TEXTURES := {
	1: preload("res://resources/art/payments/coin_1_v2_chinese_ui.png"),
	2: preload("res://resources/art/payments/coin_2_v2_chinese_ui.png"),
	5: preload("res://resources/art/payments/coin_5_v2_chinese_ui.png"),
	10: preload("res://resources/art/payments/coin_10_v2_chinese_ui.png"),
	20: preload("res://resources/art/payments/coin_20_v2_chinese_ui.png"),
}
const FORMAL_PAYMENT_COIN_SIZE := Vector2(44.0, 44.0)
const FORMAL_PAYMENT_COIN_ORIGIN := Vector2(770.0, 558.0)
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
@onready var packaged_drink_station: Control = $FiveAreaInfrastructure/Stations/PackagedDrinkStation
@onready var cartoon_youtiao_fryer: CartoonYoutiaoFryerToggle = $FiveAreaInfrastructure/Stations/CartoonYoutiaoFryer
@onready var pancake_station_view: Control = $SafeArea/JianbingStallArtwork
@onready var multi_griddle_station: Control = $SafeArea/JianbingStallArtwork/MultiGriddleStation
@onready var pancake_holding_tray_button: TextureButton = %PancakeHoldingTray
@onready var pancake_holding_sources: Array[ProductDragSource] = [%PancakeHoldingSource01, %PancakeHoldingSource02]
@onready var waste_area: StagedProductDropTarget = %WasteBasket
@onready var result_review_scroll: ScrollContainer = %ResultReviewScroll
@onready var result_review_cards: VBoxContainer = %ResultReviewCards
@onready var result_dimension_grid: GridContainer = %DimensionGrid
@onready var result_tags_panel: PanelContainer = get_node_or_null("SafeArea/ResultPanel/Margin/VBox/ResultTagsPanel") as PanelContainer
@onready var youtiao_dough_slots: Array[Node] = [%YoutiaoDoughPlain]
@onready var tutorial_guide_overlay: Control = %TutorialGuideOverlay
@onready var top_warning_label: Label = %TopWarningLabel
@onready var pancake_worktop_hotspots: Control = get_node_or_null("SafeArea/JianbingStallArtwork/PancakeWorktopHotspots") as Control
@onready var fixed_material_lock_buttons: Array[BaseButton] = [
	$SafeArea/LockedIngredientInteractions/Slot01LockedButton,
	$SafeArea/LockedIngredientInteractions/Slot02LockedButton,
	$SafeArea/LockedIngredientInteractions/Slot03LockedButton,
	$SafeArea/LockedIngredientInteractions/Slot04LockedButton,
]

var _pending_tray_settlement: Dictionary = {}
var _refresh_elapsed := 0.0
var _delivery_click_in_progress := false
var _pending_youtiao_ingredient_source_ref: Dictionary = {}
var _five_area_mouse_behavior_before_daily_bill := Control.MOUSE_BEHAVIOR_INHERITED
var _pancake_station_mouse_behavior_before_modal := Control.MOUSE_BEHAVIOR_INHERITED
var _multi_griddle_mode_active := false
var _formal_payment_coin_sprites: Array[TextureRect] = []
var _formal_payment_total_pulse_tween: Tween
var _formal_payment_collection_active := false
var _day_end_payment_collection_pending := false
var _deferred_day_end_cutoff: Dictionary = {}
var _result_quality_icons_loaded := false
var _formal_payment_total_rest_modulate := Color.WHITE
var _top_warning_tween: Tween


func _ready() -> void:
	_five_area_mouse_behavior_before_daily_bill = five_area_infrastructure.mouse_behavior_recursive
	_pancake_station_mouse_behavior_before_modal = pancake_station_view.mouse_behavior_recursive
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
	# Keep the opening restock interaction focused on the physical stock sources.
	# The old upper-left checklist competed with the workbench and could surface
	# instructional copy during restocking, so it is intentionally not displayed.
	for station in [fresh_soy_station, cartoon_youtiao_fryer]:
		station.status_message.connect(_show_station_status)
		# The formal shell already owns tightly scoped locked-station click layers.
		# Full-station covers would otherwise steal pointer input from the pancake
		# sauce rack and discard control where their authored rectangles overlap.
		station.mouse_filter = Control.MOUSE_FILTER_STOP
		if station.lock_cover != null:
			station.lock_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not cartoon_youtiao_fryer.youtiao_add_to_pancake_requested.is_connected(_on_youtiao_add_to_pancake_requested):
		cartoon_youtiao_fryer.youtiao_add_to_pancake_requested.connect(_on_youtiao_add_to_pancake_requested)
	packaged_drink_station.connect("status_message", _show_station_status)
	multi_griddle_station.status_message.connect(_show_station_status)
	multi_griddle_station.transient_warning_requested.connect(_show_top_warning)
	multi_griddle_station.fold_feedback_requested.connect(_on_pancake_fold_feedback)
	multi_griddle_station.ingredient_feedback_requested.connect(_on_ingredient_feedback)
	if not cartoon_youtiao_fryer.raw_input_feedback_requested.is_connected(_on_ingredient_feedback):
		cartoon_youtiao_fryer.raw_input_feedback_requested.connect(_on_ingredient_feedback)
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
	if pancake_holding_tray_button != null and not pancake_holding_tray_button.pressed.is_connected(_on_pancake_holding_tray_pressed):
		pancake_holding_tray_button.pressed.connect(_on_pancake_holding_tray_pressed)
	for material_slot in _all_material_slots():
		material_slot.hold_requested.connect(_on_material_hold_requested.bind(material_slot))
		material_slot.hold_advanced.connect(_on_material_hold_advanced.bind(material_slot))
		material_slot.hold_released.connect(_on_material_hold_released.bind(material_slot))
		material_slot.short_clicked.connect(_on_material_short_clicked)
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
		var settings_signal := Signal(session, &"settings_changed")
		if not settings_signal.is_connected(_apply_gameplay_ui_settings):
			settings_signal.connect(_apply_gameplay_ui_settings)
		_apply_gameplay_ui_settings(Dictionary(session.call("get_settings")))
	_restore_pending_payment()
	_refresh_formal_shell()
	_refresh_formal_area_visibility()
	_refresh_material_slots()
	_refresh_multi_griddle_mode()
	_refresh_pancake_holding_tray()
	_refresh_pancake_drag_sources()
	_apply_pointer_cursors(self)
	var active_order := Dictionary(session.call("active_formal_order")) if session != null else {}


func _refresh_result_presentation() -> void:
	super._refresh_result_presentation()
	if result_panel != null and result_panel.visible:
		_load_result_quality_icons()


func _on_pancake_fold_feedback(_unit_index: int, feedback_kind: StringName) -> void:
	kitchen_audio.call("play_cue", &"fold")
	if DisplayServer.get_name() == "headless":
		return
	var weak_strength := 0.12 if feedback_kind == &"snap_threshold" else 0.08
	var strong_strength := 0.28 if feedback_kind == &"snap_threshold" else 0.18
	var duration := 0.08 if feedback_kind == &"snap_threshold" else 0.06
	for device_id in Input.get_connected_joypads():
		Input.start_joy_vibration(device_id, weak_strength, strong_strength, duration)


func _on_ingredient_feedback(success: bool) -> void:
	if success:
		kitchen_audio.call("play_cue", &"pour")


func _apply_pointer_cursors(root_node: Node) -> void:
	if root_node is BaseButton and not root_node is ProductDragSource:
		(root_node as BaseButton).mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for child in root_node.get_children():
		_apply_pointer_cursors(child)


func _populate_result(score_result: Dictionary) -> void:
	var review_items := Array(score_result.get("review_items", []))
	if review_items.size() > 1:
		_populate_multi_product_result(review_items)
		return
	_clear_multi_product_result()
	var product_id := StringName(score_result.get("product_id", &"product.pancake.custom"))
	if product_id == &"product.pancake.custom":
		_set_pancake_result_metric_visibility(score_result)
		super._populate_result(score_result)
		order_score_label.text = "符合度  %d" % roundi(float(Dictionary(score_result.get("dimensions", {})).get("order", 0.0)))
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
	_apply_result_score_tones(float(score_result.get("score", 0.0)))


func _populate_multi_product_result(review_items: Array) -> void:
	result_review_scroll.visible = true
	result_dimension_grid.visible = false
	if result_tags_panel != null:
		result_tags_panel.visible = false
	for child in result_review_cards.get_children():
		child.queue_free()
	for review_item_value in review_items:
		var review_item := Dictionary(review_item_value)
		result_review_cards.add_child(_make_review_card(review_item))
	result_title_label.text = "顾客评价 · %d项" % review_items.size()
	result_detail_label.text = "每件商品独立评价；达到60分的商品才会计入付款。"
	result_title_label.add_theme_color_override("font_color", FORMAL_PAYMENT_GOLD)


func _clear_multi_product_result() -> void:
	result_review_scroll.visible = false
	result_dimension_grid.visible = true
	if result_tags_panel != null:
		result_tags_panel.visible = true
	for child in result_review_cards.get_children():
		child.queue_free()


func _make_review_card(review_item: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 0)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.075, 0.16, 0.15, 0.96)
	card_style.corner_radius_top_left = 12
	card_style.corner_radius_top_right = 12
	card_style.corner_radius_bottom_left = 12
	card_style.corner_radius_bottom_right = 12
	card_style.shadow_color = Color(0.015, 0.01, 0.005, 0.34)
	card_style.shadow_size = 5
	card_style.shadow_offset = Vector2(0, 3)
	card_style.content_margin_left = 20.0
	card_style.content_margin_top = 14.0
	card_style.content_margin_right = 20.0
	card_style.content_margin_bottom = 14.0
	card.add_theme_stylebox_override("panel", card_style)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	card.add_child(content)
	var heading := HBoxContainer.new()
	content.add_child(heading)
	var product_label := Label.new()
	product_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	product_label.add_theme_font_size_override("font_size", 24)
	product_label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.79, 1.0))
	product_label.text = _review_item_title(review_item)
	heading.add_child(product_label)
	var score := float(review_item.get("score", 0.0))
	var score_label := Label.new()
	score_label.add_theme_font_size_override("font_size", 23)
	score_label.add_theme_color_override("font_color", _result_score_color(score))
	score_label.text = "%d分 · %s" % [roundi(score), "已计价" if bool(review_item.get("qualified", false)) else "未计价"]
	heading.add_child(score_label)
	var feedback_label := Label.new()
	feedback_label.add_theme_font_size_override("font_size", 18)
	feedback_label.add_theme_color_override("font_color", Color(0.84, 0.8, 0.68, 1.0))
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.text = str(review_item.get("feedback", "本份已完成"))
	content.add_child(feedback_label)
	var metrics := GridContainer.new()
	metrics.columns = 3
	metrics.add_theme_constant_override("h_separation", 18)
	metrics.add_theme_constant_override("v_separation", 5)
	content.add_child(metrics)
	for metric_value in _review_metric_profile(review_item):
		var metric := Dictionary(metric_value)
		var metric_label := Label.new()
		metric_label.add_theme_font_size_override("font_size", 17)
		metric_label.add_theme_color_override("font_color", _result_score_color(float(metric.get("score", 0.0))))
		metric_label.text = "%s %d" % [str(metric.get("label", "评分")), roundi(float(metric.get("score", 0.0)))]
		metrics.add_child(metric_label)
	return card


func _review_item_title(review_item: Dictionary) -> String:
	var expected_product_id := StringName(review_item.get("expected_product_id", &""))
	var actual_product_id := StringName(review_item.get("actual_product_id", expected_product_id))
	var expected_label := _product_label(expected_product_id)
	if actual_product_id.is_empty() or actual_product_id == expected_product_id:
		return expected_label
	return "%s（实送%s）" % [expected_label, _product_label(actual_product_id)]


func _review_metric_profile(review_item: Dictionary) -> Array[Dictionary]:
	var product := Dictionary(review_item.get("product", {}))
	var product_id := StringName(review_item.get("actual_product_id", product.get("product_id", &"")))
	var displayed_item := Dictionary(review_item.get("order_item", {}))
	if product_id == &"product.pancake.custom":
		var dimensions := Dictionary(product.get("dimension_scores", {}))
		var labels := {
			&"thickness": "厚薄", &"heat": "火候", &"egg": "摊蛋", &"sauce": "酱料",
			&"ingredients": "配料", &"order": "订单", &"time": "时间",
		}
		var profile: Array[Dictionary] = []
		for metric_value in [&"thickness", &"heat", &"egg", &"sauce", &"ingredients", &"order", &"time"]:
			var metric := StringName(metric_value)
			if dimensions.has(metric):
				profile.append({"label": labels[metric], "score": float(dimensions.get(metric, 0.0))})
		return profile
	return _non_pancake_result_metric_profile({"display_product": product, "display_item": displayed_item}, product_id)


func _set_pancake_result_metric_visibility(score_result: Dictionary) -> void:
	_set_result_metric_visibility(RESULT_METRIC_LABEL_NAMES.keys(), true, true)
	_set_result_metric_visibility([&"IntegrityMetric", &"FoldMetric"], false, false)
	# Compatibility callers and older result snapshots do not include the order
	# item. Keep the established complete metric list when requirements are unknown.
	if not score_result.has("display_item"):
		return
	var displayed_item := Dictionary(score_result.get("display_item", {}))
	if not displayed_item.has("ingredient_ids"):
		return
	var requests_egg := false
	var requests_other_ingredients := false
	for stock_id_value in Array(displayed_item.get("ingredient_ids", [])):
		var stock_id := StringName(stock_id_value)
		if stock_id == PANCAKE_EGG_STOCK_ID:
			requests_egg = true
		elif not stock_id.is_empty():
			requests_other_ingredients = true
	_set_result_metric_visibility([&"EggMetric"], requests_egg, requests_egg)
	_set_result_metric_visibility([&"IngredientMetric"], requests_other_ingredients, requests_other_ingredients)


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
		&"product.youtiao.plain":
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
	if event is InputEventKey and event.pressed and not event.echo and not get_tree().paused and not is_blocking_modal_open():
		for action_id in [&"tool_ladle", &"tool_spreader", &"tool_sauce_brush", &"tool_fold_package"]:
			if event.is_action(action_id):
				_activate_tool_shortcut(action_id)
				get_viewport().set_input_as_handled()
				return
	super._input(event)


func _activate_tool_shortcut(action_id: StringName) -> Dictionary:
	var result: Dictionary
	match action_id:
		&"tool_ladle":
			result = Dictionary(multi_griddle_station.call("select_worktop_tool", &"tool.pancake.ladle"))
		&"tool_spreader":
			var session := get_node_or_null("/root/GameSession")
			var progression: RefCounted = session.call("progression_service") if session != null and session.has_method("progression_service") else null
			var tool_id := &"tool.pancake.press_once" if progression != null and bool(progression.call("owns_growth", &"growth.automation.pancake.press_once")) else &"tool.pancake.spreader"
			result = Dictionary(multi_griddle_station.call("select_worktop_tool", tool_id))
		&"tool_sauce_brush":
			result = Dictionary(multi_griddle_station.call("select_worktop_tool", &"stock.pancake.sauce.sweet_flour"))
		&"tool_fold_package":
			result = Dictionary(multi_griddle_station.call("trigger_fold_package"))
		_:
			return {"success": false, "reason": &"unknown_shortcut", "target": action_id}
	if bool(result.get("success", false)):
		var session := get_node_or_null("/root/GameSession")
		if session != null and session.has_method("record_active_tutorial_action"):
			session.call("record_active_tutorial_action", action_id)
		return result
	var message := str(result.get("message", _tool_shortcut_failure_message(StringName(result.get("reason", &"unknown")))))
	tool_status_label.text = message
	return result


static func _tool_shortcut_failure_message(reason: StringName) -> String:
	return {
		&"griddle_busy": "当前鏊面制作中，不能使用面糊勺",
		&"griddle_locked": "当前没有可用的煎饼鏊子",
		&"tool_locked": "该工具尚未解锁",
		&"stock_locked": "秘制酱料尚未解锁",
		&"insufficient_stock": "秘制酱料库存不足",
		&"wrong_stage": "当前制作阶段不能使用该工具",
	}.get(reason, "当前无法使用该工具")


func _apply_gameplay_ui_settings(settings: Dictionary) -> void:
	var ui_scale := float(settings.get("ui_scale", 100.0))
	# Gameplay controls use authored absolute hit rectangles. Scale text only so
	# accessibility settings never move the griddle, ingredients, or drop zones.
	UI_SCALE_APPLIER.apply_to($SafeArea, ui_scale, 24, false)
	UI_SCALE_APPLIER.apply_to(five_area_infrastructure, ui_scale, 24, false)
	UI_SCALE_APPLIER.apply_to(tutorial_guide_overlay, ui_scale, 24, false)


func reset_pancake() -> void:
	if _multi_griddle_mode_active and is_instance_valid(multi_griddle_station):
		multi_griddle_station.reset_active()
		return
	super.reset_pancake()


func end_business_day(cutoff: Dictionary = {}) -> void:
	if daily_bill_panel.visible or _day_end_payment_collection_pending:
		return
	if _start_day_end_payment_collection(cutoff):
		return
	_complete_business_day_end(cutoff)


func _complete_business_day_end(cutoff: Dictionary) -> void:
	super.end_business_day(cutoff)
	# GameSession has already attributed the unfinished pancake's consumed
	# materials to today's waste. Clear the live griddle too: otherwise its
	# periodic snapshot sync can overwrite that cleared save while the daily
	# bill or upgrade workshop is still open.
	if daily_bill_panel.visible and is_instance_valid(multi_griddle_station):
		multi_griddle_station.reset_all()
	if daily_bill_panel.visible:
		_set_daily_bill_modal_input(true)


func _start_day_end_payment_collection(cutoff: Dictionary) -> bool:
	if _formal_payment_collection_active:
		_day_end_payment_collection_pending = true
		_deferred_day_end_cutoff = cutoff.duplicate(true)
		return true
	var session := get_node_or_null("/root/GameSession")
	if session == null or not session.has_method("pending_order_payments"):
		return false
	if Array(session.call("pending_order_payments")).is_empty():
		return false
	var collected := Dictionary(session.call("collect_all_pending_order_payments"))
	if not bool(collected.get("success", false)):
		return false
	var collected_coins: Array[TextureRect] = []
	for coin in _formal_payment_coin_sprites:
		if is_instance_valid(coin):
			collected_coins.append(coin)
	_formal_payment_coin_sprites.clear()
	_day_end_payment_collection_pending = true
	_deferred_day_end_cutoff = cutoff.duplicate(true)
	_play_formal_payment_collection_feedback(
		int(collected.get("amount", 0)),
		collected_coins,
		_formal_payment_should_reduce_motion(),
	)
	return true


func _close_daily_bill() -> void:
	super._close_daily_bill()
	_refresh_five_area_modal_input()


func _set_daily_bill_modal_input(_active: bool) -> void:
	_refresh_five_area_modal_input()


func is_blocking_modal_open() -> bool:
	return (
		(daily_bill_panel != null and daily_bill_panel.visible)
		or (unlock_progress_panel != null and unlock_progress_panel.visible)
		or (result_panel != null and result_panel.visible)
		or (_upgrade_workshop != null and _upgrade_workshop.visible)
	)


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
	pancake_station_view.mouse_behavior_recursive = (
		Control.MOUSE_BEHAVIOR_DISABLED
		if modal_is_open
		else _pancake_station_mouse_behavior_before_modal
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
	_refresh_pancake_holding_tray()
	_refresh_pancake_drag_sources()


func _on_production_shell_changed(_snapshot: Dictionary = {}) -> void:
	# Production ticks can arrive every frame. They must not rebuild the order
	# card/portrait tree; only the production-dependent shell is refreshed.
	_refresh_pending_payment_display()
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
		# The original oil-dough image is painted into the countertop artwork.
		# Its visible restock control is the fryer itself, so this source remains
		# painted artwork rather than a second interactive restock region.
		var show_slot := false
		slot.visible = show_slot
		slot.mouse_filter = Control.MOUSE_FILTER_STOP if show_slot else Control.MOUSE_FILTER_IGNORE
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
		# The workshop owns its own filled-juice-tray preview.  Do not leave the
		# live, interactive drink tray underneath it as a duplicate.
		_set_formal_area_visible(packaged_drink_station, false)
		return
	var progression := Dictionary(session.call("five_area_progression_snapshot"))
	var unlocked_areas := Array(progression.get("unlocked_area_ids", []))
	_set_formal_area_visible(cartoon_youtiao_fryer, _id_in(unlocked_areas, &"area.youtiao"))
	_set_formal_area_visible(fresh_soy_station, _id_in(unlocked_areas, &"area.fresh_soy_milk"))
	var packaged_drinks_unlocked := _id_in(unlocked_areas, &"area.packaged_drink")
	_set_formal_area_visible(packaged_drink_station, packaged_drinks_unlocked)
	packaged_drink_station.call("refresh_from_session")


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
		slot.set_hold_progress(float(status.get("container_fill_ratio", 0.0)))
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
	slot.set_hold_progress(float(result.get("container_fill_ratio", 0.0)))
	if int(result.get("completed_units", 0)) > 0:
		tool_status_label.text = "%s补货 +%d" % [slot.material_label, int(result.get("completed_units", 0))]
	if bool(result.get("auto_stopped", false)) or not bool(result.get("success", false)):
		slot.reject_hold()
		tool_status_label.text = _restock_failure_text(StringName(result.get("reason", &"")), result)
	_refresh_material_slots()


func _on_material_hold_released(source_ref: Dictionary, slot: Node) -> void:
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("cancel_five_area_restock_hold"):
		session.call("cancel_five_area_restock_hold", StringName(source_ref.get("stock_id", &"")))
	if slot != null and slot.has_method("set_hold_progress"):
		slot.call("set_hold_progress", 0.0)


func _on_material_short_clicked(source_ref: Dictionary) -> void:
	if StringName(source_ref.get("source_kind", &"")) == &"youtiao_dough":
		cartoon_youtiao_fryer.select_recipe(StringName(source_ref.get("recipe_id", &"")))


func _on_youtiao_add_to_pancake_requested(source_ref: Dictionary) -> void:
	var result := Dictionary(multi_griddle_station.apply_clicked_youtiao(source_ref))
	if not bool(result.get("success", false)):
		tool_status_label.text = str(result.get("message", "当前不能把油条加到煎饼上"))
	cartoon_youtiao_fryer.refresh_from_session()


func place_youtiao_source_on_pancake(source_ref: Dictionary, viewport_position: Vector2) -> void:
	var source_kind := StringName(source_ref.get("source_kind", &""))
	if StringName(source_ref.get("product_id", &"")) != &"product.youtiao.plain" or source_kind not in [&"prepared_product_slot", &"youtiao_fryer_slot"]:
		tool_status_label.text = "请将炸好的油条拖到煎饼上"
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
		var source_kind := StringName(_pending_youtiao_ingredient_source_ref.get("source_kind", &""))
		if source_kind == &"prepared_product_slot":
			return bool(Dictionary(session.call("preview_take_prepared_product", StringName(_pending_youtiao_ingredient_source_ref.get("source_slot_id", &"")), int(_pending_youtiao_ingredient_source_ref.get("source_index", 0)))).get("success", false))
		if source_kind == &"youtiao_fryer_slot" and session.has_method("preview_take_youtiao_fryer_slot"):
			return bool(Dictionary(session.call("preview_take_youtiao_fryer_slot", int(_pending_youtiao_ingredient_source_ref.get("source_index", -1)))).get("success", false))
		return false
	return super._ingredient_available_for_drag(ingredient_type)


func _consume_dragged_ingredient(ingredient_type: StringName) -> bool:
	if ingredient_type == IngredientModel.YOUTIAO:
		var session := get_node_or_null("/root/GameSession")
		if session == null:
			return false
		var source_kind := StringName(_pending_youtiao_ingredient_source_ref.get("source_kind", &""))
		if source_kind == &"prepared_product_slot":
			return bool(Dictionary(session.call("take_prepared_product", StringName(_pending_youtiao_ingredient_source_ref.get("source_slot_id", &"")), int(_pending_youtiao_ingredient_source_ref.get("source_index", 0)))).get("success", false))
		if source_kind == &"youtiao_fryer_slot" and session.has_method("take_youtiao_fryer_slot"):
			return bool(Dictionary(session.call("take_youtiao_fryer_slot", int(_pending_youtiao_ingredient_source_ref.get("source_index", -1)))).get("success", false))
		return false
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
				&"burnt": return {"target": cartoon_youtiao_fryer.waste_source, "message": "把整锅焦糊油条拖到废弃区"}
				&"draining": return {"target": cartoon_youtiao_fryer.state_label, "message": "等待沥油完成"}
				&"ready_to_collect":
					return {"target": cartoon_youtiao_fryer.output_sources[0], "message": "点击任意油条将整篮放入成品盘，或拖到煎饼与顾客订单"}
		&"area.fresh_soy_milk":
			var machine := Dictionary(session.call("f3_machine_snapshot", &"device.fresh_soy_milk_machine"))
			match StringName(machine.get("state", &"idle")):
				&"ready": return {"target": fresh_soy_station.cup_stack, "message": "点击杯堆，拿一个空杯放到出浆口"}
				&"held_empty": return {"target": fresh_soy_station.nozzle_button, "message": "按住出浆口 0.8 秒接满豆浆"}
				&"filled": return {"target": fresh_soy_station.sugar_jar, "message": "按订单选择无糖、正常糖或多糖，再拖杯交付"}
		&"area.packaged_drink":
			return {"target": packaged_drink_station, "message": "长按果汁货位补货，再把果汁拖到订单商品上交付"}
		&"area.pancake":
			if _multi_griddle_mode_active:
				return _tutorial_pancake_griddle_guide(session, area_id)
			match p1_session.phase:
				P1Session.Phase.SPREAD: return {"target": ladle_button, "message": "舀取面糊，在鏊面摊成完整饼皮"}
				P1Session.Phase.FIRST_SIDE, P1Session.Phase.SECOND_SIDE: return {"target": step_action_button, "message": "观察火候并在合适时机翻面或确认"}
				P1Session.Phase.SAUCE_AND_FILLINGS: return {"target": sauce_brush_button, "message": "刷酱并按订单加入配料"}
				P1Session.Phase.FOLD: return {"target": fold_button, "message": "选择折叠工具并完成折叠"}
				P1Session.Phase.PACKAGE: return {"target": fold_button, "message": "折叠完成后会自动装入纸袋"}
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
				"target": _pancake_worktop_target("BatterLadleSource/HitButton", griddle),
				"message": "第1步：单击拿起面糊勺，再在空鏊面按住倒入面糊",
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
					"message": "第3步：单击鸡蛋直接打到当前饼面，再用摊饼器摊开蛋液",
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
				return {"target": griddle.main_action, "message": "第二面已焦糊：完成加料后请尽快点击“打包”"}
			return _tutorial_pancake_garnish_or_pack(griddle)
		CompactGriddleUnit.State.GARNISH:
			return _tutorial_pancake_garnish_or_pack(griddle)
		CompactGriddleUnit.State.FOLDING:
			return {"target": griddle.pancake_surface, "message": "第6步：正在自动折叠并装入纸袋"}
		CompactGriddleUnit.State.READY:
			return {"target": _tutorial_delivery_target(session, area_id), "message": "第6步：点击订单商品，交付完成的煎饼"}
	return {}


func _tutorial_pancake_garnish_or_pack(griddle: CompactGriddleUnit) -> Dictionary:
	var sauce_id := griddle.next_sauce_id()
	if not sauce_id.is_empty():
		return {
			"target": _pancake_worktop_target("SecretSauceSource/Hotspot", griddle.pancake_surface),
			"message": "第5步：点击秘制酱料，自动均匀刷到翻面后的饼面",
		}
	var ingredient_id := griddle.next_ingredient_id()
	if not ingredient_id.is_empty():
		var hotspot_paths := {
			&"stock.pancake.baocui": "BaocuiBasket/Hotspot",
			&"stock.pancake.scallion": "ScallionTray/Hotspot",
			&"stock.pancake.ham_sausage": "HamSource/Hotspot",
			&"stock.pancake.coriander": "CorianderTray/Hotspot",
			&"stock.pancake.meat_floss": "PorkFlossSource/Hotspot",
		}
		return {
			"target": _pancake_worktop_target(str(hotspot_paths.get(ingredient_id, "")), griddle.pancake_surface),
			"message": "第5步：按订单加入%s" % str(multi_griddle_station.call("_stock_label", ingredient_id)),
		}
	return {"target": griddle.main_action, "message": "第6步：配料完成，点击“打包”自动折叠并装袋"}


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
	_refresh_pending_payment_display()
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
	_apply_attention_entries(entries)


func _apply_attention_entries(entries: Array) -> void:
	var rail := $FiveAreaInfrastructure/AttentionRail
	var all_parts := PackedStringArray()
	var has_red_entry := false
	for entry_value in entries:
		var entry := Dictionary(entry_value)
		has_red_entry = has_red_entry or StringName(entry.get("severity", &"yellow")) == &"red"
		all_parts.append("%s %d秒" % [
			_attention_label(StringName(entry.get("status_key", &"attention"))),
			maxi(ceili(float(entry.get("seconds_to_irreversible_loss", 0.0))), 0),
		])
	var visible_parts := PackedStringArray()
	for part_index in mini(all_parts.size(), 2):
		visible_parts.append(all_parts[part_index])
	if all_parts.size() > visible_parts.size():
		visible_parts.append("另有%d项" % (all_parts.size() - visible_parts.size()))
	for index in range(rail.get_child_count()):
		var label := rail.get_child(index) as Label
		if label == null:
			continue
		label.visible = index == 0 and not all_parts.is_empty()
		if index != 0:
			continue
		label.text = "%s  ·  %s" % ["紧急" if has_red_entry else "注意", "  ·  ".join(visible_parts)]
		label.tooltip_text = "待处理事项\n%s" % "\n".join(all_parts)
		label.add_theme_color_override("font_color", Color("ff8f78") if has_red_entry else Color("ffd06a"))


func _refresh_pancake_drag_sources() -> void:
	var session := get_node_or_null("/root/GameSession")
	var holding_slots: Array = []
	if session != null and session.has_method("pancake_holding_tray_snapshot"):
		holding_slots = Array(Dictionary(session.call("pancake_holding_tray_snapshot")).get("slots", []))
	for slot_index in range(pancake_holding_sources.size()):
		var product := Dictionary(holding_slots[slot_index]) if slot_index < holding_slots.size() else {}
		var source := pancake_holding_sources[slot_index]
		source.configure({"source_kind": &"pancake_holding", "source_index": slot_index, "product_id": StringName(product.get("product_id", &"")), "discardable": true}, PRODUCT_VISUALS.texture_for(&"product.pancake.custom"), not product.is_empty(), _pancake_holding_tooltip(product))
		source.visible = not product.is_empty()
		_refresh_pancake_recipe_markers(source, product)


func _refresh_pancake_holding_tray() -> void:
	if pancake_holding_tray_button == null:
		return
	var session := get_node_or_null("/root/GameSession")
	var unlocked := false
	if session != null and session.has_method("progression_service"):
		unlocked = bool(session.call("progression_service").call("owns_growth", &"growth.capacity.pancake_holding_tray.two_slots"))
	pancake_holding_tray_button.visible = unlocked
	pancake_holding_tray_button.disabled = not unlocked
	if unlocked:
		_refresh_pancake_drag_sources()


func _on_pancake_holding_tray_pressed() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null or multi_griddle_station == null:
		return
	var ready_sources: Array = multi_griddle_station.ready_source_refs()
	if ready_sources.is_empty():
		tool_status_label.text = "暂存盘内没有待存煎饼；请先完成纸袋包装。"
		return
	if ready_sources.size() != 1:
		tool_status_label.text = "暂存盘暂不能自动选择多张已打包煎饼；请先处理鏊子上的成品。"
		return
	var source_ref := Dictionary(ready_sources[0])
	var source_index := int(source_ref.get("source_index", -1))
	var stored := Dictionary(session.call("store_pancake_griddle_ready_in_holding_tray", source_index))
	if not bool(stored.get("success", false)):
		tool_status_label.text = _pancake_holding_store_failure_text(StringName(stored.get("reason", &"unknown")))
		_refresh_pancake_holding_tray()
		return
	# The session has already atomically cleared the authoritative griddle
	# snapshot. Reset only the matching visual unit afterwards.
	multi_griddle_station.consume_ready(source_index)
	_refresh_pancake_holding_tray()
	tool_status_label.text = "已放入煎饼暂存盘；可从盘中拖到顾客订单。"


static func _pancake_holding_store_failure_text(reason: StringName) -> String:
	match reason:
		&"tray_locked": return "煎饼暂存盘尚未升级。"
		&"capacity_full": return "煎饼暂存盘已满；请先交付或废弃盘内成品。"
		&"pancake_not_ready": return "这张煎饼尚未完成纸袋包装。"
		&"duplicate_product_instance": return "该煎饼已在暂存盘中。"
		_: return "暂存失败：%s" % str(reason)


func _refresh_pancake_recipe_markers(source: Control, product: Dictionary) -> void:
	for child in source.get_children():
		if child.has_meta("pancake_recipe_marker"):
			child.queue_free()
	if product.is_empty():
		return
	var marker_entries := _pancake_recipe_marker_entries(product)
	var visible_count := mini(marker_entries.size(), PANCAKE_RECIPE_MARKER_VISIBLE_LIMIT)
	for marker_index in visible_count:
		var entry := Dictionary(marker_entries[marker_index])
		var marker := TextureRect.new()
		marker.set_meta("pancake_recipe_marker", true)
		marker.z_index = 10
		marker.position = Vector2(2.0 + float(marker_index) * 18.0, 34.0)
		marker.size = Vector2(16.0, 16.0)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.texture = PANCAKE_RECIPE_MARKER_TEXTURES.get(StringName(entry.get("stock_id", &""))) as Texture2D
		marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		source.add_child(marker)
		var portions := int(entry.get("count", 1))
		if portions > 1:
			var count_label := Label.new()
			count_label.set_meta("pancake_recipe_marker", true)
			count_label.z_index = 11
			count_label.position = marker.position + Vector2(10.0, 7.0)
			count_label.size = Vector2(10.0, 10.0)
			count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			count_label.text = str(portions)
			count_label.add_theme_font_size_override("font_size", 10)
			count_label.add_theme_color_override("font_color", Color.WHITE)
			count_label.add_theme_color_override("font_outline_color", Color(0.16, 0.06, 0.02, 1.0))
			count_label.add_theme_constant_override("outline_size", 2)
			source.add_child(count_label)
	if marker_entries.size() > visible_count:
		var extra_label := Label.new()
		extra_label.set_meta("pancake_recipe_marker", true)
		extra_label.z_index = 11
		extra_label.position = Vector2(2.0 + float(visible_count) * 18.0, 34.0)
		extra_label.size = Vector2(22.0, 16.0)
		extra_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		extra_label.text = "+%d" % (marker_entries.size() - visible_count)
		extra_label.add_theme_font_size_override("font_size", 11)
		extra_label.add_theme_color_override("font_color", Color.WHITE)
		extra_label.add_theme_color_override("font_outline_color", Color(0.16, 0.06, 0.02, 1.0))
		extra_label.add_theme_constant_override("outline_size", 2)
		source.add_child(extra_label)


static func _pancake_recipe_marker_entries(product: Dictionary) -> Array[Dictionary]:
	var counts := {}
	var order: Array[StringName] = []
	for stock_group in [Array(product.get("ingredient_ids", [])), Array(product.get("sauce_ids", []))]:
		for stock_value in stock_group:
			var stock_id := StringName(stock_value)
			if not PANCAKE_RECIPE_MARKER_TEXTURES.has(stock_id):
				continue
			if not counts.has(stock_id):
				order.append(stock_id)
				counts[stock_id] = 0
			counts[stock_id] = int(counts[stock_id]) + 1
	var entries: Array[Dictionary] = []
	for stock_id in order:
		entries.append({"stock_id": stock_id, "count": int(counts[stock_id])})
	return entries


static func _pancake_holding_tooltip(product: Dictionary) -> String:
	if product.is_empty():
		return "空格：点击暂存盘将唯一已打包煎饼放入这里。"
	var names := PackedStringArray()
	for entry in _pancake_recipe_label_entries(product):
		var value := Dictionary(entry)
		var name := str(PANCAKE_RECIPE_MARKER_LABELS.get(StringName(value.get("stock_id", &"")), "配料"))
		var portions := int(value.get("count", 1))
		names.append("%s×%d" % [name, portions] if portions > 1 else name)
	var state := StringName(product.get("state", &"fresh"))
	var freshness: String = str({&"fresh": "新鲜", &"aging": "正在变凉", &"stale": "已冷掉"}.get(state, "新鲜度未知"))
	return "配方：%s\n新鲜度：%s\n可拖到顾客订单，或拖入废弃篓。" % ["、".join(names) if not names.is_empty() else "原味", freshness]


static func _pancake_recipe_label_entries(product: Dictionary) -> Array[Dictionary]:
	var counts := {}
	var order: Array[StringName] = []
	for stock_group in [Array(product.get("ingredient_ids", [])), Array(product.get("sauce_ids", []))]:
		for stock_value in stock_group:
			var stock_id := StringName(stock_value)
			if stock_id.is_empty():
				continue
			if not counts.has(stock_id):
				order.append(stock_id)
				counts[stock_id] = 0
			counts[stock_id] = int(counts[stock_id]) + 1
	var entries: Array[Dictionary] = []
	for stock_id in order:
		entries.append({"stock_id": stock_id, "count": int(counts[stock_id])})
	return entries


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
		icon.visible = product_texture != null
		_set_order_product_text_fallback(button, str(CATALOG.product_definition(product_id).get("label", "成品")), product_texture == null)
		var completed := Array(item.get("prepared_product_instance_ids", [])).size() >= maxi(int(item.get("quantity", 1)), 1)
		var should_disable := completed or not order_active or _delivery_click_in_progress
		if button.disabled != should_disable:
			button.disabled = should_disable
		var target_mouse_filter := Control.MOUSE_FILTER_IGNORE if should_disable else Control.MOUSE_FILTER_STOP
		if button.mouse_filter != target_mouse_filter:
			button.mouse_filter = target_mouse_filter
		button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if should_disable else Control.CURSOR_POINTING_HAND
		button.tooltip_text = "该订单商品已交付" if completed else "点击交付对应成品"


func _set_order_product_text_fallback(button: Button, product_label: String, show_fallback: bool) -> void:
	var fallback := button.get_node_or_null("ProductTextFallback") as Panel
	if fallback == null:
		fallback = Panel.new()
		fallback.name = "ProductTextFallback"
		fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#e86b28")
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color("#fff0b6")
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		fallback.add_theme_stylebox_override("panel", style)
		var label := Label.new()
		label.name = "Label"
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color("#fff7ce"))
		label.add_theme_color_override("font_outline_color", Color("#722506"))
		label.add_theme_constant_override("outline_size", 3)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fallback.add_child(label)
		button.add_child(fallback)
	var fallback_label := fallback.get_node("Label") as Label
	fallback_label.text = product_label
	fallback.visible = show_fallback


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
	var tutorial_order := bool(order.get("tutorial_no_countdown", false))
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
		var failure_message := str(staged.get("message", "交付失败，成品未被消耗：%s" % str(staged.get("reason", &"unknown"))))
		tool_status_label.text = failure_message
		_refresh_formal_shell()
		return
	_on_clicked_product_consumed(source_ref)
	if not tutorial_order and not bool(staged.get("will_match", false)):
		_show_top_warning("订单内容不匹配；本单仍会结算并按现有规则扣分")
	var refreshed := Dictionary(session.call("formal_order", order_id))
	if not _formal_order_items_complete(refreshed):
		var suffix := "（餐品与要求不符，结算时会扣分）" if not tutorial_order and not bool(staged.get("will_match", false)) else ""
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
	for source_ref in _available_delivery_source_refs():
		var preview := Dictionary(session.call("preview_stage_product_to_order", source_ref, order_id, item_index))
		if not bool(preview.get("success", false)):
			continue
		var candidate := {"source_ref": Dictionary(source_ref).duplicate(true), "preview": preview}
		if bool(preview.get("will_match", false)):
			return candidate
	# An order-card click means “deliver this exact item”.  Do not silently use
	# another product from the same area as a fallback: chicken cutlets and
	# youtiao share the fryer area, but they are never interchangeable.
	return {}


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
	sources.append_array(fresh_soy_station.product_sources())
	sources.append_array(packaged_drink_station.call("product_sources"))
	for source in sources:
		if source == null or source.disabled or not source.visible:
			continue
		var source_ref := Dictionary(source.call("source_ref"))
		if not source_ref.is_empty():
			result.append(source_ref)
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("prepared_product_slot_status"):
		for slot_id in [&"slot.04", &"slot.chicken"]:
			var status := Dictionary(session.call("prepared_product_slot_status", slot_id))
			if bool(status.get("success", false)) and int(status.get("count", 0)) > 0:
				# Each stored product needs its own source index; using the legacy -1
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
	packaged_drink_station.call("refresh_from_session")


func _on_customer_service_product_dropped(order_id: StringName, item_index: int, source_ref: Dictionary) -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return
	_on_customer_service_focus_requested(order_id)
	var staged := Dictionary(session.call("stage_product_to_order", source_ref, order_id, item_index))
	if not bool(staged.get("success", false)):
		var failure_message := str(staged.get("message", "拖放交付失败，原成品保留：%s" % str(staged.get("reason", &"unknown"))))
		tool_status_label.text = failure_message
		_refresh_formal_shell()
		return
	_on_clicked_product_consumed(source_ref)
	var refreshed := Dictionary(session.call("formal_order", order_id))
	if not bool(refreshed.get("tutorial_no_countdown", false)) and not bool(staged.get("will_match", false)):
		_show_top_warning("订单内容不匹配；本单仍会结算并按现有规则扣分")
	if not _formal_order_items_complete(refreshed):
		tool_status_label.text = "已拖放交付第 %d 项；继续完成其余餐品" % (item_index + 1)
		_refresh_formal_shell()
		return
	var completed := Dictionary(session.call("complete_order_delivery", order_id))
	if bool(completed.get("success", false)):
		_finish_clicked_order(completed)
	else:
		tool_status_label.text = str(completed.get("message", "订单完成失败：%s" % str(completed.get("reason", &"unknown"))))


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
	var review_count := int(finished.get("review_count", 1))
	summary_score_label.text = "本单 %d项 · +%d金币" % [review_count, earned]
	summary_feedback_label.text = str(finished.get("feedback", "本单已完成"))
	summary_feedback_label.visible = not summary_feedback_label.text.strip_edges().is_empty()
	_result_detail_open = false
	_order_summary_visible = true
	_refresh_pending_payment_display()
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
	_refresh_pending_payment_display()
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
	return total / float(visible_coin_count) if visible_coin_count > 0 else FORMAL_PAYMENT_COIN_ORIGIN + FORMAL_PAYMENT_COIN_SIZE * 0.5


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
	_refresh_pending_payment_display()
	if _day_end_payment_collection_pending:
		tool_status_label.text = "营业结束，已统一收取 %d 金币" % amount
		var cutoff := _deferred_day_end_cutoff.duplicate(true)
		_day_end_payment_collection_pending = false
		_deferred_day_end_cutoff.clear()
		call_deferred("_complete_business_day_end", cutoff)
		return
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
	_refresh_pending_payment_display()


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
		coin.mouse_filter = Control.MOUSE_FILTER_STOP
		coin.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		coin.tooltip_text = "点击收取 %d 金币" % denomination
		coin.gui_input.connect(_on_formal_payment_coin_gui_input)
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


func _on_formal_payment_coin_gui_input(event: InputEvent) -> void:
	if _formal_payment_collection_active:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			get_viewport().set_input_as_handled()
			_collect_pending_payments()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			get_viewport().set_input_as_handled()
			_collect_pending_payments()


func _refresh_pending_payment_display() -> void:
	# Coins are the sole visible payment interaction. This method remains as the
	# refresh seam for settlement and workshop state changes.
	pass


func _set_upgrade_workshop_preview(enabled: bool) -> void:
	super._set_upgrade_workshop_preview(enabled)
	if enabled:
		# The workshop overlay supplies a non-interactive filled juice tray, so
		# never expose the live station UI while the overlay is open.
		_set_formal_area_visible(packaged_drink_station, false)
	else:
		_refresh_formal_area_visibility()
	_refresh_pending_payment_display()


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
		# The shared waste basket bypasses DirectSoyStation's local handlers.
		# Refresh it explicitly so a discarded filled cup cannot remain visible.
		fresh_soy_station.refresh_from_session()
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
	var review_items := Array(settlement.get("review_items", []))
	var has_explicit_review_items := not review_items.is_empty()
	if review_items.is_empty():
		review_items = _legacy_review_items(item_results)
	var primary_review := Dictionary(review_items[0]) if not review_items.is_empty() else {}
	var primary_result := Dictionary(item_results[0]) if not item_results.is_empty() else {}
	var product := Dictionary(primary_review.get("product", primary_result.get("product", {})))
	var feedback_items := _review_feedback_items(review_items) if has_explicit_review_items else _delivery_feedback_items(item_results)
	summary["review_items"] = review_items
	summary["review_count"] = review_items.size()
	summary["score"] = float(primary_review.get("score", product.get("score", 100.0 if bool(settlement.get("order_success", false)) else 0.0)))
	summary["dimensions"] = Dictionary(product.get("dimension_scores", {})).duplicate(true)
	summary["product_id"] = StringName(primary_review.get("actual_product_id", product.get("product_id", &"product.pancake.custom")))
	summary["display_product"] = product.duplicate(true)
	summary["display_item"] = Dictionary(primary_review.get("order_item", primary_result)).duplicate(true)
	summary["tags"] = feedback_items
	if feedback_items.is_empty():
		summary["feedback"] = "顾客已收到完整订单"
	else:
		summary["feedback"] = "顾客指出：%s" % str(feedback_items[0])
	return summary


static func _legacy_review_items(item_results: Array) -> Array[Dictionary]:
	var review_items: Array[Dictionary] = []
	for item_result_value in item_results:
		var item_result := Dictionary(item_result_value)
		for product_value in Array(item_result.get("products", [])):
			var product := Dictionary(product_value)
			var mismatch_reasons := PackedStringArray(item_result.get("mismatch_reasons", PackedStringArray()))
			var score := 0.0 if not mismatch_reasons.is_empty() else float(product.get("score", product.get("quality", 100.0)))
			review_items.append({
				"expected_product_id": item_result.get("product_id", &""),
				"actual_product_id": product.get("product_id", item_result.get("product_id", &"")),
				"product": product.duplicate(true),
				"order_item": item_result.duplicate(true),
				"mismatch_reasons": mismatch_reasons,
				"score": score,
				"qualified": mismatch_reasons.is_empty() and score >= 60.0,
			})
	return review_items


static func _review_feedback_items(review_items: Array) -> PackedStringArray:
	var feedback_items := PackedStringArray()
	for review_item_value in review_items:
		var review_item := Dictionary(review_item_value)
		if bool(review_item.get("qualified", false)):
			continue
		var feedback := str(review_item.get("feedback", ""))
		if feedback.is_empty() and not bool(review_item.get("qualified", true)):
			feedback = "%s未达到付款标准" % _product_label(StringName(review_item.get("expected_product_id", &"")))
		if not feedback.is_empty() and not feedback_items.has(feedback):
			feedback_items.append(feedback)
	return feedback_items


static func _delivery_feedback_items(item_results: Array) -> PackedStringArray:
	var candidates := _delivery_feedback_candidates(item_results)
	var feedback_items := PackedStringArray()
	for candidate_value in candidates:
		feedback_items.append(str(Dictionary(candidate_value).get("text", "")))
	return feedback_items


static func _delivery_feedback_candidates(item_results: Array) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for item_result_value in item_results:
		var item_result := Dictionary(item_result_value)
		var expected_product := _product_label(StringName(item_result.get("product_id", &"")))
		var product := Dictionary(item_result.get("product", {}))
		var actual_product := _product_label(StringName(product.get("product_id", &"")))
		for reason_value in Array(item_result.get("mismatch_reasons", [])):
			var reason := StringName(reason_value)
			var feedback := _delivery_feedback_text(reason, expected_product, actual_product, product)
			_add_delivery_feedback_candidate(candidates, feedback, _delivery_mismatch_score(reason, product), _delivery_mismatch_metric(reason))
		for quality_candidate in _pancake_quality_feedback_candidates(item_result, product):
			_add_delivery_feedback_candidate(
				candidates,
				str(quality_candidate.get("text", "")),
				float(quality_candidate.get("score", 100.0)),
				StringName(quality_candidate.get("metric", &"")),
			)
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_score := float(left.get("score", 100.0))
		var right_score := float(right.get("score", 100.0))
		if not is_equal_approx(left_score, right_score):
			return left_score < right_score
		return int(left.get("metric_order", 999)) < int(right.get("metric_order", 999))
	)
	return candidates


static func _add_delivery_feedback_candidate(candidates: Array[Dictionary], text: String, score: float, metric: StringName) -> void:
	if text.is_empty():
		return
	for existing in candidates:
		if str(existing.get("text", "")) == text:
			return
	candidates.append({
		"text": text,
		"score": clampf(score, 0.0, 100.0),
		"metric_order": int(FEEDBACK_METRIC_ORDER.get(metric, -1)),
	})


static func _delivery_mismatch_metric(reason: StringName) -> StringName:
	match reason:
		&"heat_preference": return &"heat"
		&"ingredient_ids": return &"ingredients"
		&"sauce_ids": return &"sauce"
		&"missing_order_item", &"incomplete_quantity", &"product_id": return &"order"
		_: return &"order"


static func _delivery_mismatch_score(reason: StringName, product: Dictionary) -> float:
	var dimensions := Dictionary(product.get("dimension_scores", {}))
	match reason:
		&"missing_order_item", &"incomplete_quantity", &"product_id": return 0.0
		&"ingredient_ids": return minf(float(dimensions.get("ingredients", 100.0)), float(dimensions.get("order", 100.0)))
		&"sauce_ids": return minf(float(dimensions.get("sauce", 100.0)), float(dimensions.get("order", 100.0)))
		&"heat_preference": return float(dimensions.get("heat", 100.0))
		_: return float(dimensions.get("order", 0.0))


static func _pancake_quality_feedback_candidates(item_result: Dictionary, product: Dictionary) -> Array[Dictionary]:
	if StringName(product.get("product_id", &"")) != &"product.pancake.custom":
		return []
	var dimensions := Dictionary(product.get("dimension_scores", {}))
	var candidates: Array[Dictionary] = []
	for metric_value in FEEDBACK_METRIC_ORDER:
		var metric := StringName(metric_value)
		if metric == &"order" or not _pancake_feedback_metric_visible(item_result, metric):
			continue
		var score := float(dimensions.get(metric, 100.0))
		if score >= QUALITY_COMPLAINT_THRESHOLD:
			continue
		candidates.append({"metric": metric, "score": score, "text": _pancake_quality_feedback_text(metric, product)})
	return candidates


static func _pancake_feedback_metric_visible(item_result: Dictionary, metric: StringName) -> bool:
	if metric not in [&"egg", &"ingredients"] or not item_result.has("ingredient_ids"):
		return true
	var requests_egg := false
	var requests_other_ingredients := false
	for stock_id_value in Array(item_result.get("ingredient_ids", [])):
		var stock_id := StringName(stock_id_value)
		if stock_id == PANCAKE_EGG_STOCK_ID:
			requests_egg = true
		elif not stock_id.is_empty():
			requests_other_ingredients = true
	return requests_egg if metric == &"egg" else requests_other_ingredients


static func _pancake_quality_feedback_text(metric: StringName, product: Dictionary) -> String:
	var tags := PackedStringArray(Array(product.get("tags", [])).map(func(tag): return str(tag)))
	match metric:
		&"thickness": return "煎饼厚薄不均"
		&"heat":
			var heat_feedback := str(product.get("heat_feedback", ""))
			return "煎饼%s" % heat_feedback if not heat_feedback.is_empty() else "煎饼火候不够理想"
		&"egg":
			return _first_matching_tag(tags, ["蛋黄没有摊开", "鸡蛋覆盖不足", "鸡蛋厚薄不均", "鸡蛋局部堆积"], "煎饼鸡蛋没有摊匀")
		&"sauce":
			return _first_matching_tag(tags, ["局部缺酱", "酱料过量", "刷痕断续"], "煎饼酱料涂抹不均")
		&"ingredients":
			return _first_matching_tag(tags, ["配料靠边易漏"], "煎饼配料摆放不理想")
		&"time": return "顾客等待时间过长"
		_: return "煎饼制作质量不够理想"


static func _first_matching_tag(tags: PackedStringArray, preferred_tags: Array, fallback: String) -> String:
	for preferred_tag_value in preferred_tags:
		var preferred_tag := str(preferred_tag_value)
		if tags.has(preferred_tag):
			return "煎饼%s" % preferred_tag
	return fallback


static func _delivery_feedback_text(reason: StringName, expected_product: String, actual_product: String, product: Dictionary = {}) -> String:
	match reason:
		&"missing_order_item", &"incomplete_quantity": return "%s未按订单交齐" % expected_product
		&"product_id": return "交付的%s与订单要求的%s不符" % [actual_product, expected_product]
		&"heat_preference":
			var heat_feedback := str(product.get("heat_feedback", ""))
			return "%s%s" % [expected_product, heat_feedback] if not heat_feedback.is_empty() else "%s火候不符合订单要求" % expected_product
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
		&"area.packaged_drink": "请先长按果汁货位补货，再拖动果汁交付",
	}.get(area_id, "该区域没有可交付的成品")


static func _area_label(area_id: StringName) -> String:
	return {
		&"area.pancake": "煎饼鏊台",
		&"area.youtiao": "油条炸锅",
		&"area.fresh_soy_milk": "现磨豆浆机",
		&"area.packaged_drink": "成品饮品区",
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
