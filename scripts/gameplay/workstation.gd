class_name Workstation
extends Control

signal daily_bill_closed

const SAUCE_TOOL_STATE_SCRIPT := preload("res://scripts/gameplay/sauce_tool_state.gd")
const PANCAKE_SCORER_SCRIPT := preload("res://scripts/gameplay/pancake_scorer.gd")
const PANCAKE_HOLDING_TRAY_MODEL := preload("res://scripts/gameplay/pancake_holding_tray_model.gd")
const FIVE_AREA_PANCAKE_PRODUCTION_SERVICE := preload("res://scripts/services/five_area_pancake_production_service.gd")
const FOLD_MODEL_SCRIPT := preload("res://scripts/gameplay/pancake_fold_model.gd")
const INGREDIENT_MODEL_SCRIPT := preload("res://scripts/gameplay/ingredient_model.gd")
const INGREDIENT_STOCK_MODEL_SCRIPT := preload("res://scripts/gameplay/ingredient_stock_model.gd")
const ORDER_SERVICE_SCRIPT := preload("res://scripts/services/order_service.gd")
const FIVE_AREA_PANCAKE_ORDER_PROVIDER := preload("res://scripts/services/five_area_pancake_order_provider.gd")
const CUSTOMER_QUEUE_SERVICE_SCRIPT := preload("res://scripts/services/customer_queue_service.gd")
const P1_SESSION_SCRIPT := preload("res://scripts/gameplay/p1_session.gd")
const BUSINESS_DAY_TIMER_SCRIPT := preload("res://scripts/services/business_day_timer.gd")
const FIVE_AREA_CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const UPGRADE_WORKSHOP_SCENE_PATH := "res://scenes/ui/upgrade_workshop_overlay.tscn"
const BASIC_GRIDDLE_TEXTURE := preload("res://resources/art/workstation/griddle/griddle_base_angled_ellipse_v4_chinese.png")
const INTERMEDIATE_GRIDDLE_TEXTURE_PATH := "res://resources/art/workstation/griddle/griddle_base_angled_ellipse_tier_1_v1_chinese.png"
const ADVANCED_GRIDDLE_TEXTURE_PATH := "res://resources/art/workstation/griddle/griddle_base_angled_ellipse_tier_2_v1_chinese.png"
const BASIC_SPREADER_TEXTURE := preload("res://resources/art/workstation/tools/batter_spreader_v1.png")
const CUSTOMER_PORTRAIT_CATALOG_SCRIPT := preload("res://scripts/ui/customer_portrait_catalog.gd")
const PATIENCE_BAR_STYLE := preload("res://scripts/ui/patience_bar_style.gd")
const ORDER_CARD_COIN_TEXTURE_PATH := "res://resources/art/ui/economy/currency_coin_v2_chinese_ui.png"
const ORDER_CARD_DISH_TEXTURE_PATH := "res://resources/art/workstation/textures/pancake_cooked_texture_v1.png"
const ORDER_CARD_INGREDIENT_TEXTURE_PATHS := {
	IngredientModel.EGG: "res://resources/art/ingredients/egg/egg_whole_v1.png",
	&"stock.pancake.egg": "res://resources/art/ingredients/egg/egg_whole_v1.png",
	IngredientModel.BAOCUI: "res://resources/art/ingredients/baocui/baocui_broken_v1.png",
	&"stock.pancake.baocui": "res://resources/art/ingredients/baocui/baocui_broken_v1.png",
	IngredientModel.HAM_SAUSAGE: "res://resources/art/ingredients/ham_sausage/ham_sausage_slices_v1.png",
	&"stock.pancake.ham_sausage": "res://resources/art/ingredients/ham_sausage/ham_sausage_slices_v1.png",
	IngredientModel.SCALLION: "res://resources/art/ingredients/scallion/scallion_scattered_v1.png",
	&"stock.pancake.scallion": "res://resources/art/ingredients/scallion/scallion_scattered_v1.png",
	IngredientModel.MEAT_FLOSS: "res://resources/art/ingredients/meat_floss/meat_floss_pile_v1.png",
	&"stock.pancake.meat_floss": "res://resources/art/ingredients/meat_floss/meat_floss_pile_v1.png",
	IngredientModel.YOUTIAO: "res://resources/art/products/youtiao/plain_youtiao_v1_five_area_v3.png",
	&"stock.pancake.youtiao": "res://resources/art/products/youtiao/plain_youtiao_v1_five_area_v3.png",
	IngredientModel.CORIANDER: "res://resources/art/ingredients/coriander/coriander_scattered_five_area_v2.png",
	&"stock.pancake.coriander": "res://resources/art/ingredients/coriander/coriander_scattered_five_area_v2.png",
}
const ORDER_CARD_INGREDIENT_NAMES := {
	&"stock.pancake.egg": "鸡蛋", &"stock.pancake.baocui": "薄脆", &"stock.pancake.scallion": "香葱",
	&"stock.pancake.ham_sausage": "火腿", &"stock.pancake.meat_floss": "肉松", &"stock.pancake.pork_tenderloin": "里脊肉",
	&"stock.pancake.coriander": "香菜", &"stock.pancake.preserved_mustard": "榨菜", &"stock.pancake.youtiao": "油条",
}
const ORDER_CARD_SAUCE_TEXTURE_PATHS := {
	# Reuse the labeled condiment jars from the material grid: a sauce smear
	# communicates colour, whereas the jar artwork makes the selected sauce
	# immediately identifiable on an order card.
	&"stock.pancake.sauce.sweet_flour": "res://resources/art/ingredients/condiments/sweet-bean-sauce-jar-no-brush.png",
}
const ORDER_CARD_SAUCE_NAMES := {
	&"stock.pancake.sauce.sweet_flour": "秘制酱料",
}
const ORDER_CARD_HEAT_TEXTURE_PATH := "res://resources/art/ui/quality/quality_heat_requirement_v2_chinese_ui.png"
const FIVE_AREA_PRODUCT_VISUALS := preload("res://scripts/ui/five_area_product_visuals.gd")
const ORDER_REQUIREMENT_INGREDIENT := &"ingredient"
const ORDER_REQUIREMENT_SAUCE := &"sauce"
const ORDER_REQUIREMENT_HEATED := &"heated"
const ORDER_REQUIREMENT_SUGAR := &"sugar"
const ORDER_CARD_SUGAR_TEXTURE_PATH := "res://resources/art/workstation/machines/soy_milk/sugar-jar-for-soy-milk.png"
const DAILY_BILL_FIXED_SIZE := Vector2(1260.0, 820.0)
const SPREADER_ART_ROTATION_OFFSET := 1.124
const SPREADER_SPEED_SLOW := -1
const SPREADER_SPEED_MEDIUM := 0
const SPREADER_SPEED_FAST := 1
const EGG_CRACK_EFFECT_BASE_SCALE := Vector2(0.55, 0.55)
const EGG_CRACK_EFFECT_STAGE_Y := 0.0

@export var parameters: PancakeSimulationParameters

@onready var pancake_surface: PancakeHeatmap = get_node_or_null("SafeArea/PanBase/PancakeSurface") as PancakeHeatmap
@onready var pancake_visual: TextureRect = get_node_or_null("SafeArea/PanBase/PancakeSurface/PancakeVisual") as TextureRect
@onready var tool_controller: ToolController = get_node_or_null("ToolController") as ToolController
@onready var ladle_button: Button = get_node_or_null("SafeArea/LeftRack/LadleButton") as Button
@onready var scraper_button: Button = get_node_or_null("SafeArea/LeftRack/ScraperButton") as Button
@onready var sauce_brush_button: Button = get_node_or_null("SafeArea/LeftRack/SauceBrushButton") as Button
@onready var press_spreader_button: Button = get_node_or_null("SafeArea/LeftRack/PressSpreaderButton") as Button
@onready var automatic_sauce_brush_button: Button = get_node_or_null("SafeArea/LeftRack/AutomaticSauceBrushButton") as Button
@onready var sauce_refill_button: Button = get_node_or_null("SafeArea/RightRack/SauceRefillButton") as Button
@onready var sauce_status_label: Label = get_node_or_null("SafeArea/RightRack/SauceStatusLabel") as Label
@onready var fold_button: Button = get_node_or_null("SafeArea/LeftRack/FoldButton") as Button
@onready var fold_status_label: Label = get_node_or_null("SafeArea/RightRack/FoldStatusLabel") as Label
@onready var fold_overlay: Control = get_node_or_null("SafeArea/PanBase/PancakeSurface/PancakeFoldOverlay") as Control
@onready var spreader_artwork: Sprite2D = get_node_or_null("SafeArea/PanBase/PancakeSurface/SpreaderArtwork") as Sprite2D
@onready var tool_status_label: Label = %ToolStatusLabel
@onready var warning_label: Label = %WarningLabel
@onready var business_day_timer_label: Label = _resolve_business_day_timer_label()
@onready var global_status_label: Label = %GlobalStatusLabel
@onready var warning_tone: AudioStreamPlayer = %DamageWarningTone
@onready var surface_readout_label: Label = get_node_or_null("SafeArea/SurfaceReadoutLabel") as Label
@onready var chili_sauce_refill_button: Button = get_node_or_null("SafeArea/RightRack/ChiliSauceRefillButton") as Button
@onready var ingredient_layer: IngredientLayer = get_node_or_null("SafeArea/PanBase/PancakeSurface/IngredientLayer") as IngredientLayer
@onready var sauce_blob_overlay: Control = get_node_or_null("SafeArea/PanBase/PancakeSurface/SauceBlobOverlay") as Control
@onready var egg_crack_artwork: Sprite2D = get_node_or_null("SafeArea/PanBase/PancakeSurface/EggCrackArtwork") as Sprite2D
@onready var egg_crack_effect: AnimatedSprite2D = get_node_or_null("SafeArea/PanBase/PancakeSurface/EggCrackEffect") as AnimatedSprite2D
@onready var ingredient_drag_preview: TextureRect = get_node_or_null("SafeArea/IngredientDragPreview") as TextureRect
@onready var egg_button: Button = get_node_or_null("SafeArea/IngredientRack/EggButton") as Button
@onready var baocui_button: Button = get_node_or_null("SafeArea/IngredientRack/BaocuiButton") as Button
@onready var ham_button: Button = get_node_or_null("SafeArea/IngredientRack/HamButton") as Button
@onready var scallion_button: Button = get_node_or_null("SafeArea/IngredientRack/ScallionButton") as Button
@onready var meat_floss_button: Button = get_node_or_null("SafeArea/IngredientRack/MeatFlossButton") as Button
@onready var pork_tenderloin_button: Button = get_node_or_null("SafeArea/IngredientRack/PorkTenderloinButton") as Button
@onready var coriander_button: Button = get_node_or_null("SafeArea/IngredientRack/CorianderButton") as Button
@onready var preserved_mustard_button: Button = get_node_or_null("SafeArea/IngredientRack/PreservedMustardButton") as Button
@onready var egg_restock_button: Button = get_node_or_null("SafeArea/RestockRack/EggRestockButton") as Button
@onready var baocui_restock_button: Button = get_node_or_null("SafeArea/RestockRack/BaocuiRestockButton") as Button
@onready var ham_restock_button: Button = get_node_or_null("SafeArea/RestockRack/HamRestockButton") as Button
@onready var scallion_restock_button: Button = get_node_or_null("SafeArea/RestockRack/ScallionRestockButton") as Button
@onready var customer_portrait: TextureRect = get_node_or_null("SafeArea/CustomerPortrait") as TextureRect
@onready var waiting_customer_strip: Control = get_node_or_null("SafeArea/CustomerStrip") as Control
@onready var queue_status_label: Label = %QueueStatusLabel
@onready var customer_slot_buttons: Array[Button] = [%CustomerSlot1, %CustomerSlot2, %CustomerSlot3]
@onready var customer_slot_patience_bars: Array[ProgressBar] = [
	%CustomerSlot1.get_node("Patience"),
	%CustomerSlot2.get_node("Patience"),
	%CustomerSlot3.get_node("Patience"),
]
var _customer_slot_patience_tiers := [-1, -1, -1]
## Static customer-card content is cached separately from the continuously
## changing patience value. Rebinding a card relayouts its complete drop-target
## subtree, so doing that every frame makes every native drag compete with GUI
## hit-test invalidation.
var _customer_service_slot_signatures: Dictionary = {}
var _next_customer_entrance_msec := 0
var _restore_customer_layout_without_entrance := false
const CUSTOMER_SERVICE_MIN_ENTRANCE_INTERVAL_SECONDS := 1.0
var _order_patience_tier := -1
@onready var customer_service_slots: Array[Control] = _resolve_customer_service_slots()
@onready var customer_line_label: Label = get_node_or_null("SafeArea/CustomerLineLabel") as Label
@onready var order_coin_icon: TextureRect = get_node_or_null("SafeArea/OrderCard/OrderCoinIcon") as TextureRect
@onready var order_amount_label: Label = get_node_or_null("SafeArea/OrderCard/OrderAmountLabel") as Label
@onready var order_dish_icons: Array[TextureRect] = _optional_texture_rects("SafeArea/OrderCard", "OrderDish", 3)
@onready var order_dish_buttons: Array[Button] = _optional_buttons("SafeArea/OrderCard", "OrderDishTarget", 3)
@onready var order_ingredient_icons: Array[TextureRect] = _optional_texture_rects("SafeArea/OrderCard", "OrderIngredient", 8)
@onready var order_ingredient_backgrounds: Array[Panel] = _optional_panels("SafeArea/OrderCard", "OrderIngredientBackground", 8)
@onready var order_heat_backgrounds: Array[Panel] = _optional_panels("SafeArea/OrderCard", "OrderHeatBackground", 8)
@onready var order_heart_fill: Polygon2D = get_node_or_null("SafeArea/OrderCard/OrderHeartFill") as Polygon2D
@onready var order_patience_bar: ProgressBar = get_node_or_null("SafeArea/OrderCard/OrderPatienceBar") as ProgressBar
@onready var patience_bar: ProgressBar = get_node_or_null("SafeArea/PatienceBar") as ProgressBar
@onready var patience_text_label: Label = get_node_or_null("SafeArea/PatienceTextLabel") as Label
@onready var tutorial_guide_label: Label = get_node("SafeArea/BottomStrip/TutorialGuideLabel") as Label
@onready var phase_label: Label = get_node_or_null("SafeArea/PhaseLabel") as Label
@onready var heat_slider: HSlider = get_node_or_null("SafeArea/P1ControlBar/HeatSlider") as HSlider
@onready var heat_label: Label = get_node_or_null("SafeArea/P1ControlBar/HeatLabel") as Label
@onready var step_action_button: Button = get_node_or_null("SafeArea/P1ControlBar/StepActionButton") as Button
@onready var discard_current_pancake_button: Button = get_node_or_null("SafeArea/DiscardCurrentPancakeButton") as Button
@onready var serve_button: Button = get_node_or_null("SafeArea/P1ControlBar/ServeButton") as Button
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_title_label: Label = %ResultTitleLabel
@onready var result_detail_label: Label = %ResultDetailLabel
@onready var result_tags_label: Label = %ResultTagsLabel
@onready var integrity_score_label: Label = %IntegrityScoreLabel
@onready var thickness_score_label: Label = %ThicknessScoreLabel
@onready var heat_score_label: Label = %HeatScoreLabel
@onready var egg_score_label: Label = %EggScoreLabel
@onready var sauce_score_label: Label = %SauceScoreLabel
@onready var ingredient_score_label: Label = %IngredientScoreLabel
@onready var fold_score_label: Label = %FoldScoreLabel
@onready var order_score_label: Label = %OrderScoreLabel
@onready var time_score_label: Label = %TimeScoreLabel
@onready var next_order_button: Button = %NextOrderButton
@onready var payment_sprite: TextureRect = %PaymentSprite
@onready var payment_coin_layer: Control = %PaymentCoinLayer
@onready var payment_display: TextureRect = %PaymentDisplay
@onready var kitchen_audio: AudioStreamPlayer = %KitchenAudio
@onready var p1_control_bar: Panel = get_node_or_null("SafeArea/P1ControlBar") as Panel
@onready var serve_product_button: Button = get_node_or_null("SafeArea/ServeProductButton") as Button
@onready var store_pancake_button: Button = get_node_or_null("SafeArea/StorePancakeButton") as Button
@onready var pancake_holding_tray: Panel = get_node_or_null("SafeArea/PancakeHoldingTray") as Panel
@onready var pancake_holding_slots: Array[Button] = _optional_buttons("SafeArea/PancakeHoldingTray", "PancakeHoldingSlot", 2)
@onready var handoff_product_sprite: TextureRect = get_node_or_null("SafeArea/HandoffProductSprite") as TextureRect
@onready var order_summary_card: PanelContainer = %OrderSummaryCard
@onready var summary_score_label: Label = %SummaryScoreLabel
@onready var summary_feedback_label: Label = %SummaryFeedbackLabel
@onready var summary_view_button: Button = %SummaryViewButton
@onready var summary_dismiss_button: Button = %SummaryDismissButton
@onready var result_detail_input_shield: Control = get_node_or_null("SafeArea/ResultDetailInputShield") as Control
@onready var daily_bill_panel: PanelContainer = %DailyBillPanel
@onready var business_day_closed_shield: Control = %BusinessDayClosedShield
@onready var daily_bill_title_label: Label = %DailyBillTitleLabel
@onready var daily_bill_stats_label: Label = %DailyBillStatsLabel
@onready var daily_bill_rows: GridContainer = %DailyBillRows
@onready var daily_bill_close_button: Button = %DailyBillCloseButton
@onready var growth_balance_label: Label = %GrowthBalanceLabel
@onready var begin_next_day_button: Button = %BeginNextDayButton
@onready var unlock_progress_button: Button = %UnlockProgressButton
@onready var unlock_progress_panel: PanelContainer = %UnlockProgressPanel
@onready var unlock_progress_label: Label = %UnlockProgressLabel
@onready var unlock_progress_close_button: Button = %UnlockProgressCloseButton
@onready var growth_ticket_buttons: Array[Button] = [%GrowthTicket1, %GrowthTicket2, %GrowthTicket3]
@onready var station_interaction_controller: PancakeWorkstationInteractionController = get_node_or_null("SafeArea/PancakeWorkstationInteractionController") as PancakeWorkstationInteractionController
@onready var refuse_active_order_button: Button = %RefuseActiveOrderButton
@onready var skip_active_tutorial_button: Button = %SkipActiveTutorialButton

var pancake_model: PancakeModel
var _scrape_sampler: StrokeSampler
var _egg_sampler: StrokeSampler
var _sauce_sampler: StrokeSampler
var _previous_scrape_sample := Vector2.ZERO
var _last_process_grid_position := Vector2.ZERO
var _spreader_max_radius := 0.0
var _spreader_direction_grace_remaining := 0
var _spreader_smoothed_angular_speed := 0.0
var _spreader_speed_initialized := false
var _growth_recommendations: Array[Dictionary] = []
var _upgrade_workshop: UpgradeWorkshopOverlay
var _workshop_customer_visibility: Dictionary = {}
var _workshop_runtime_visibility: Dictionary = {}
var _spreader_width_multiplier := 1.0
var _press_spreader_owned := false
var _automatic_brush_owned := false
var _chili_sauce_unlocked := false
var _intermediate_griddle_owned := false
var _advanced_griddle_owned := false
var _press_spreader_used := false
var _spreader_speed_band := SPREADER_SPEED_MEDIUM
var _spreader_smoothed_angle := 0.0
var _spreader_angle_initialized := false
var _spread_shape_locked := false
var _simulation_accumulator := 0.0
var pour_used := false
var sauce_tool_state: RefCounted
var sauce_tool_states: Dictionary = {}
var _last_sauce_evaluation: Dictionary = {}
var _sauce_stroke_id := 0
var _squeezing_sauce := false
var fold_model: RefCounted
var ingredient_model: IngredientModel
var ingredient_stock_model
var order_service: RefCounted
var customer_queue: RefCounted
var p1_session: P1Session
var five_area_pancake_production: RefCounted
var _formal_order_id: StringName = &""
var _pending_delivery_item_index := -1
var _refusal_confirmation_order_id: StringName = &""
var _skip_confirmation_tutorial_id: StringName = &""
var _handoff_product_from_tray: Dictionary = {}
var _resume_production_after_tray_handoff := false
var current_sauce_type: StringName = OrderService.SAUCE_SWEET
var _ingredient_drag_type: StringName = &""
var _ingredient_drag_start := Vector2.ZERO
var _last_sizzle_msec := -10000
var _audio_update_accumulator := 0.0
var _result_detail_open := false
var _order_summary_visible := false
var _handoff_tween: Tween
var _egg_crack_tween: Tween
var _customer_reaction_tween: Tween
var _customer_visual_state: StringName = &""
var _customer_portraits: RefCounted = CUSTOMER_PORTRAIT_CATALOG_SCRIPT.new()
var _customer_reaction_prewarm_started := false
var business_day_timer: RefCounted
var _business_day_closed := false
var _business_day_expiration_pending := false
var _last_persisted_business_second := -1


func _optional_texture_rects(parent_path: String, prefix: String, count: int) -> Array[TextureRect]:
	var result: Array[TextureRect] = []
	for index in count:
		var suffix := "%02d" % (index + 1) if count >= 8 else str(index + 1)
		var node := get_node_or_null("%s/%s%s" % [parent_path, prefix, suffix]) as TextureRect
		if node != null:
			result.append(node)
	return result


func _optional_buttons(parent_path: String, prefix: String, count: int) -> Array[Button]:
	var result: Array[Button] = []
	for index in count:
		var suffix := "%02d" % (index + 1) if count >= 8 else str(index + 1)
		var node := get_node_or_null("%s/%s%s" % [parent_path, prefix, suffix]) as Button
		if node != null:
			result.append(node)
	return result


func _optional_panels(parent_path: String, prefix: String, count: int) -> Array[Panel]:
	var result: Array[Panel] = []
	for index in count:
		var suffix := "%02d" % (index + 1) if count >= 8 else str(index + 1)
		var node := get_node_or_null("%s/%s%s" % [parent_path, prefix, suffix]) as Panel
		if node != null:
			result.append(node)
	return result


func _resolve_business_day_timer_label() -> Label:
	# The initial-unlock gameplay scene intentionally hides the inherited
	# BottomStrip, so its live countdown is a direct SafeArea child instead.
	var entry_scene_label := get_node_or_null("SafeArea/BusinessDayTimerLabel") as Label
	if entry_scene_label != null:
		return entry_scene_label
	return get_node_or_null("SafeArea/BottomStrip/BusinessDayTimerLabel") as Label


func _ready() -> void:
	# Waiting orders continue to be queued and promoted normally, but only
	# customers currently being served are shown on the shop floor.
	if waiting_customer_strip != null:
		waiting_customer_strip.visible = false
	if parameters == null:
		parameters = PancakeSimulationParameters.new()
	pancake_model = PancakeModel.new(parameters.grid_size, parameters)
	ingredient_model = INGREDIENT_MODEL_SCRIPT.new()
	ingredient_stock_model = INGREDIENT_STOCK_MODEL_SCRIPT.new(_saved_ingredient_stock(), IngredientModel.TYPES)
	fold_model = FOLD_MODEL_SCRIPT.new(pancake_model, ingredient_model)
	var unlocked_ingredient_ids: Array[StringName] = IngredientModel.TYPES.duplicate()
	if has_meta(&"unlocked_ingredient_ids"):
		unlocked_ingredient_ids.clear()
		for ingredient_id in Array(get_meta(&"unlocked_ingredient_ids")):
			unlocked_ingredient_ids.append(StringName(ingredient_id))
	var game_session := get_node_or_null("/root/GameSession")
	if game_session != null and game_session.has_method("is_business_paused"):
		# The start menu keeps a continued business paused until Main finishes
		# binding the restored scene. A new game starts unpaused.
		_restore_customer_layout_without_entrance = bool(game_session.call("is_business_paused"))
	if game_session != null and game_session.has_method("uses_five_area_progression") and bool(game_session.call("uses_five_area_progression")):
		five_area_pancake_production = FIVE_AREA_PANCAKE_PRODUCTION_SERVICE.new(game_session)
	if game_session != null and game_session.has_method("unlocked_ingredient_ids"):
		unlocked_ingredient_ids.clear()
		unlocked_ingredient_ids.assign(game_session.call("unlocked_ingredient_ids"))
	var formal_active: Dictionary = {}
	if game_session != null and game_session.has_method("active_formal_order"):
		formal_active = Dictionary(game_session.call("active_formal_order"))
	if game_session != null and game_session.has_method("ensure_active_playable_order") and bool(game_session.call("is_five_area_save_active")):
		# The formal service owns the deterministic stream. The legacy queue is
		# retained only as a one-customer adapter for the pancake simulator.
		order_service = ORDER_SERVICE_SCRIPT.new(unlocked_ingredient_ids)
		customer_queue = CUSTOMER_QUEUE_SERVICE_SCRIPT.new(order_service, 1)
		var ensured: Dictionary = game_session.call("ensure_active_playable_order")
		if bool(ensured.get("success", false)):
			formal_active = Dictionary(ensured.get("order", {}))
		var restored_legacy: Dictionary = Dictionary(Dictionary(formal_active.get("metadata", {})).get("legacy_order", {}))
		if not restored_legacy.is_empty():
			customer_queue.call("restore_active_customer", restored_legacy)
	else:
		order_service = ORDER_SERVICE_SCRIPT.new(unlocked_ingredient_ids)
		customer_queue = CUSTOMER_QUEUE_SERVICE_SCRIPT.new(order_service)
	p1_session = P1_SESSION_SCRIPT.new()
	var business_day_remaining := BUSINESS_DAY_TIMER_SCRIPT.DEFAULT_DURATION_SECONDS
	if game_session != null and game_session.has_method("business_day_remaining_seconds"):
		business_day_remaining = float(game_session.call("business_day_remaining_seconds"))
	business_day_timer = BUSINESS_DAY_TIMER_SCRIPT.new(business_day_remaining)
	_last_persisted_business_second = ceili(business_day_remaining)
	_scrape_sampler = StrokeSampler.new(parameters.scraper_sample_spacing)
	_egg_sampler = StrokeSampler.new(parameters.egg_sample_spacing)
	_sauce_sampler = StrokeSampler.new(parameters.sauce_sample_spacing)
	sauce_tool_states = {
		OrderService.SAUCE_SWEET: SAUCE_TOOL_STATE_SCRIPT.new(parameters.sauce_brush_capacity),
		OrderService.SAUCE_CHILI: SAUCE_TOOL_STATE_SCRIPT.new(parameters.sauce_brush_capacity),
	}
	sauce_tool_state = sauce_tool_states[current_sauce_type]
	if pancake_surface == null:
		_ready_formal_shop_shell(game_session, formal_active)
		return
	pancake_surface.heatmap_update_hz = parameters.heatmap_update_hz
	pancake_surface.render_texture_size = parameters.render_texture_size
	pancake_surface.set_model(pancake_model)
	ingredient_layer.set_model(ingredient_model)
	ingredient_layer.set_fold_model(fold_model)
	fold_overlay.set_fold_model(fold_model)
	fold_overlay.set_fold_sauce_textures(
		pancake_surface.fold_sweet_sauce_texture(),
		pancake_surface.fold_chili_sauce_texture(),
	)
	pancake_surface.pointer_started.connect(_on_pointer_started)
	pancake_surface.pointer_ended.connect(_on_pointer_ended)
	pancake_surface.cancel_requested.connect(_on_cancel_requested)
	ladle_button.pressed.connect(_select_ladle)
	scraper_button.pressed.connect(_on_spreader_tool_pressed)
	press_spreader_button.pressed.connect(use_press_spreader)
	sauce_refill_button.button_down.connect(_on_sauce_squeeze_started)
	sauce_refill_button.button_up.connect(_on_sauce_squeeze_ended)
	chili_sauce_refill_button.button_down.connect(_on_chili_sauce_squeeze_started)
	chili_sauce_refill_button.button_up.connect(_on_sauce_squeeze_ended)
	egg_crack_effect.animation_finished.connect(_on_egg_crack_animation_finished)
	fold_button.pressed.connect(_select_fold)
	store_pancake_button.pressed.connect(_store_current_pancake)
	if customer_service_slots.is_empty():
		for slot_index in customer_slot_buttons.size():
			customer_slot_buttons[slot_index].pressed.connect(_on_customer_slot_pressed.bind(slot_index))
	else:
		for service_slot in customer_service_slots:
			service_slot.connect("focus_requested", Callable(self, "_on_customer_service_focus_requested"))
			service_slot.connect("delivery_requested", Callable(self, "_on_customer_service_delivery_requested"))
	for item_index in order_dish_buttons.size():
		order_dish_buttons[item_index].pressed.connect(_on_order_dish_pressed.bind(item_index))
	next_order_button.pressed.connect(_close_result_detail)
	summary_view_button.pressed.connect(_open_result_detail)
	summary_dismiss_button.pressed.connect(_dismiss_order_summary)
	daily_bill_close_button.pressed.connect(_close_daily_bill)
	begin_next_day_button.pressed.connect(_begin_next_business_day)
	unlock_progress_button.pressed.connect(_open_upgrade_workshop)
	unlock_progress_close_button.pressed.connect(_close_unlock_progress)
	station_interaction_controller.station_requested.connect(_open_f3_station)
	refuse_active_order_button.pressed.connect(_on_refuse_active_order_pressed)
	skip_active_tutorial_button.pressed.connect(_on_skip_active_tutorial_pressed)
	for ticket_index in growth_ticket_buttons.size():
		growth_ticket_buttons[ticket_index].pressed.connect(_on_growth_ticket_pressed.bind(ticket_index))
	step_action_button.pressed.connect(_advance_p1_step)
	discard_current_pancake_button.pressed.connect(_discard_current_pancake)
	# The griddle uses one fixed heat setting. Keeping the node preserves the
	# scene contract for diagnostics, but it is not a player-adjustable control.
	heat_slider.editable = false
	heat_slider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heat_slider.value = 50.0
	p1_session.heat_level = 0.50
	for growth_ticket in growth_ticket_buttons:
		growth_ticket.autowrap_mode = TextServer.AUTOWRAP_OFF
		growth_ticket.clip_text = true
	growth_balance_label.clip_text = true
	_connect_ingredient_slot(egg_button, IngredientModel.EGG)
	_connect_ingredient_slot(baocui_button, IngredientModel.BAOCUI)
	_connect_ingredient_slot(ham_button, IngredientModel.HAM_SAUSAGE)
	_connect_ingredient_slot(scallion_button, IngredientModel.SCALLION)
	_connect_ingredient_slot(meat_floss_button, IngredientModel.MEAT_FLOSS)
	_connect_ingredient_slot(pork_tenderloin_button, IngredientModel.PORK_TENDERLOIN)
	_connect_ingredient_slot(coriander_button, IngredientModel.CORIANDER)
	_connect_ingredient_slot(preserved_mustard_button, IngredientModel.PRESERVED_MUSTARD)
	ingredient_stock_model.changed.connect(_on_ingredient_stock_changed)
	fold_model.changed.connect(_refresh_fold_ui)
	tool_controller.tool_changed.connect(_on_tool_changed)
	p1_session.changed.connect(_refresh_p1_ui)
	_bind_global_status(game_session)
	var first_order: Dictionary = _legacy_order_from_active_formal_order(customer_queue.current_customer().order)
	p1_session.start(first_order)
	if _uses_playable_formal_orders():
		_route_active_playable_order(false)
	else:
		_ensure_formal_pancake_order(first_order)
	_refresh_pancake_holding_tray()
	_on_tool_changed(tool_controller.current_tool)
	_update_sauce_status()
	_refresh_fold_ui()
	_refresh_ingredient_stock_ui()
	_refresh_p1_ui()
	_refresh_global_status()
	_refresh_spreader_upgrade_presentation()
	_refresh_sauce_brush_upgrade_presentation()
	_log_info(&"workstation", "PancakeModel ready: %dx%d" % [parameters.grid_size, parameters.grid_size])


func _ready_formal_shop_shell(game_session: Node, formal_active: Dictionary) -> void:
	for service_slot in customer_service_slots:
		service_slot.connect("focus_requested", Callable(self, "_on_customer_service_focus_requested"))
		service_slot.connect("delivery_requested", Callable(self, "_on_customer_service_delivery_requested"))
	next_order_button.pressed.connect(_close_result_detail)
	summary_view_button.pressed.connect(_open_result_detail)
	summary_dismiss_button.pressed.connect(_dismiss_order_summary)
	daily_bill_close_button.pressed.connect(_close_daily_bill)
	begin_next_day_button.pressed.connect(_begin_next_business_day)
	unlock_progress_button.pressed.connect(_open_upgrade_workshop)
	unlock_progress_close_button.pressed.connect(_close_unlock_progress)
	refuse_active_order_button.pressed.connect(_on_refuse_active_order_pressed)
	skip_active_tutorial_button.pressed.connect(_on_skip_active_tutorial_pressed)
	for ticket_index in growth_ticket_buttons.size():
		growth_ticket_buttons[ticket_index].pressed.connect(_on_growth_ticket_pressed.bind(ticket_index))
	_bind_global_status(game_session)
	var legacy_order := Dictionary(Dictionary(formal_active.get("metadata", {})).get("legacy_order", {}))
	p1_session.start(legacy_order)
	_formal_order_id = StringName(formal_active.get("order_id", &""))
	_refresh_customer_queue()
	_refresh_formal_patience_ui(game_session)
	_refresh_global_status()
	_log_info(&"workstation", "Four-area shop shell ready")


func _open_f3_station(_area_id: StringName) -> void:
	# Production areas are permanent shop-floor entities.  This compatibility
	# route deliberately performs no navigation and opens no production page.
	_refresh_global_status()


func _close_f3_station() -> void:
	_refresh_global_status()


func _uses_playable_formal_orders() -> bool:
	var game_session := get_node_or_null("/root/GameSession")
	return game_session != null and game_session.has_method("ensure_active_playable_order") and bool(game_session.call("is_five_area_save_active"))


func _route_active_playable_order(restart_pancake: bool = true) -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("ensure_active_playable_order"):
		return
	var ensured: Dictionary = game_session.call("ensure_active_playable_order")
	if not bool(ensured.get("success", false)):
		_formal_order_id = &""
		_refresh_main_order_controls({})
		return
	var chosen := {}
	for order_variant in Array(ensured.get("active_orders", [])):
		var candidate := Dictionary(order_variant)
		if StringName(candidate.get("order_id", &"")) == _formal_order_id:
			chosen = candidate
			break
	if chosen.is_empty():
		chosen = Dictionary(ensured.get("order", {}))
	_focus_formal_order(chosen, restart_pancake)


func _focus_formal_order(order: Dictionary, restart_pancake: bool = false) -> void:
	if order.is_empty():
		_formal_order_id = &""
		_refresh_main_order_controls({})
		_refresh_customer_queue()
		return
	_formal_order_id = StringName(order.get("order_id", &""))
	_refresh_main_order_controls(order)
	var items := Array(order.get("items", []))
	if items.is_empty():
		_refresh_customer_queue()
		return
	var area_id := StringName(Dictionary(items[0]).get("area_id", &""))
	if area_id == &"area.pancake":
		_close_f3_station()
		var legacy := Dictionary(Dictionary(order.get("metadata", {})).get("legacy_order", {}))
		if legacy.is_empty():
			tool_status_label.text = "正式煎饼订单缺少制作模板"
			return
		customer_queue.call("restore_active_customer", legacy, StringName(order.get("customer_id", &"customer_01")))
		if restart_pancake:
			reset_pancake()
			p1_session.start(legacy)
		else:
			p1_session.order = legacy.duplicate(true)
			p1_session.mirror_formal_patience(
				float(order.get("remaining_patience_seconds", order.get("patience_seconds", 0.0))),
				bool(order.get("tutorial_no_countdown", false))
			)
		_refresh_p1_ui()
	else:
		_open_f3_station(area_id)
		tool_status_label.text = "已切换查看该顾客订单"
	_refresh_customer_queue()


func _route_active_playable_order_legacy(restart_pancake: bool = true) -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("ensure_active_playable_order"):
		return
	var ensured: Dictionary = game_session.call("ensure_active_playable_order")
	if not bool(ensured.get("success", false)):
		_formal_order_id = &""
		_refresh_main_order_controls({})
		var reason := StringName(ensured.get("reason", &""))
		if reason == &"tutorial_restock_required":
			var area_id := StringName(ensured.get("teaching_area_id", &""))
			var missing := PackedStringArray(ensured.get("missing_stock_ids", PackedStringArray()))
			tool_status_label.text = "教学待补货：%s" % "、".join(missing)
			if area_id == &"area.youtiao":
				_open_f3_station(area_id)
		else:
			tool_status_label.text = "当前没有可生成的正式订单：%s" % str(reason)
		return
	var active := Dictionary(ensured.get("order", {}))
	_formal_order_id = StringName(active.get("order_id", &""))
	_refresh_main_order_controls(active)
	var items: Array = Array(active.get("items", []))
	if items.is_empty():
		return
	var area_id := StringName(Dictionary(items[0]).get("area_id", &""))
	if area_id == &"area.pancake":
		_close_f3_station()
		var legacy := Dictionary(Dictionary(active.get("metadata", {})).get("legacy_order", {}))
		if legacy.is_empty():
			tool_status_label.text = "正式煎饼订单缺少制作模板。"
			return
		customer_queue.call("restore_active_customer", legacy)
		if restart_pancake:
			reset_pancake()
			p1_session.start(legacy)
			_refresh_p1_ui()
	else:
		_open_f3_station(area_id)
		tool_status_label.text = "已切换到油条正式订单。"


func _on_playable_order_finished(result: Dictionary = {}) -> void:
	_refusal_confirmation_order_id = &""
	_skip_confirmation_tutorial_id = &""
	var earned := int(result.get("earned_coins", 0))
	var reputation_delta := int(result.get("reputation_delta", 0))
	tool_status_label.text = "订单已结束 · 金币 +%d · 口碑 %+d" % [earned, reputation_delta]
	_route_active_playable_order(true)


func _on_formal_order_expired(result: Dictionary) -> void:
	var expired_order_id := StringName(result.get("order_id", &""))
	if expired_order_id == _formal_order_id:
		_formal_order_id = &""
	_pending_delivery_item_index = -1
	tool_status_label.text = "顾客耐心耗尽，口碑 -2；店内已补入新顾客"
	_route_active_playable_order(false)


func _on_customer_slot_pressed(slot_index: int) -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("active_formal_orders"):
		return
	var target := {}
	for order_variant in Array(game_session.call("active_formal_orders")):
		var order := Dictionary(order_variant)
		if int(order.get("service_slot", -1)) == slot_index:
			target = order
			break
	if target.is_empty():
		return
	_focus_formal_order(target, false)
	_pending_delivery_item_index = -1


func _on_customer_service_focus_requested(order_id: StringName) -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("formal_order"):
		return
	var order := Dictionary(game_session.call("formal_order", order_id))
	if order.is_empty():
		return
	_focus_formal_order(order, false)
	_pending_delivery_item_index = -1


func _on_customer_service_delivery_requested(order_id: StringName, item_index: int) -> void:
	_on_customer_service_focus_requested(order_id)
	if _formal_order_id == order_id:
		_on_order_dish_pressed(item_index)


func _on_order_dish_pressed(item_index: int) -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or _formal_order_id.is_empty() or not game_session.has_method("formal_order"):
		tool_status_label.text = "当前没有可查看的顾客订单"
		return
	var target_order: Dictionary = game_session.call("formal_order", _formal_order_id)
	var items: Array = Array(target_order.get("items", []))
	if item_index < 0 or item_index >= items.size():
		tool_status_label.text = "该订单商品槽为空"
		return
	tool_status_label.text = "请在五区域正式店面点击订单商品图标交付成品"


func _delivery_source_for_order_item(target_order: Dictionary, item_index: int) -> Dictionary:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null:
		return {}
	var items: Array = Array(target_order.get("items", []))
	if item_index < 0 or item_index >= items.size():
		return {}
	var direct_product := _current_ready_product_preview()
	var tray_slots: Array = []
	if game_session.has_method("pancake_holding_tray_snapshot"):
		tray_slots = Array(Dictionary(game_session.call("pancake_holding_tray_snapshot")).get("slots", []))
	return _select_delivery_source_for_order_item(game_session, target_order, item_index, direct_product, tray_slots)


func _select_delivery_source_for_order_item(game_session: Node, target_order: Dictionary, item_index: int, direct_product: Dictionary, tray_slots: Array) -> Dictionary:
	var direct_available := not direct_product.is_empty()
	var direct_matches := direct_available and _delivery_product_matches_order_item(game_session, target_order, item_index, direct_product)
	if direct_matches:
		return {"kind": &"direct", "will_match": true, "product": direct_product}
	var matching_tray := _oldest_tray_delivery_candidate(game_session, target_order, item_index, tray_slots, true)
	if not matching_tray.is_empty():
		return matching_tray
	if direct_available:
		return {"kind": &"direct", "will_match": false, "product": direct_product}
	return _oldest_tray_delivery_candidate(game_session, target_order, item_index, tray_slots, false)


func _current_ready_product_preview() -> Dictionary:
	if p1_session == null or p1_session.phase != P1Session.Phase.READY_TO_SERVE or five_area_pancake_production == null:
		return {}
	var score_result := PANCAKE_SCORER_SCRIPT.evaluate_order(
		pancake_model,
		ingredient_model,
		fold_model,
		p1_session.order,
		p1_session.elapsed_seconds,
		p1_session.patience_ratio(),
	)
	return Dictionary(five_area_pancake_production.call(
		"create_product_snapshot",
		score_result,
		p1_session.order,
		{"package_result": fold_model.package_result},
	)).duplicate(true)


func _delivery_product_matches_order_item(game_session: Node, target_order: Dictionary, item_index: int, product: Dictionary) -> bool:
	var order_id := StringName(target_order.get("order_id", &""))
	if order_id.is_empty() or not game_session.has_method("preview_attach_formal_order_product"):
		return false
	var preview: Dictionary = game_session.call("preview_attach_formal_order_product", order_id, item_index, product)
	return bool(preview.get("success", false)) and bool(preview.get("will_match", false))


func _oldest_tray_delivery_candidate(game_session: Node, target_order: Dictionary, item_index: int, slots: Array, require_match: bool) -> Dictionary:
	var best := {}
	var best_age := -1.0
	for slot_index in slots.size():
		var product := Dictionary(slots[slot_index])
		if StringName(product.get("product_instance_id", &"")).is_empty():
			continue
		var matches := _delivery_product_matches_order_item(game_session, target_order, item_index, product)
		if matches != require_match:
			continue
		var age := maxf(float(product.get("age_seconds", 0.0)), 0.0)
		if best.is_empty() or age > best_age:
			best = {"kind": &"tray", "slot_index": slot_index, "will_match": matches, "product": product}
			best_age = age
	return best


func _on_refuse_active_order_pressed() -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null:
		return
	var active: Dictionary = game_session.call("formal_order", _formal_order_id) if not _formal_order_id.is_empty() else game_session.call("active_formal_order")
	var order_id := StringName(active.get("order_id", &""))
	if order_id.is_empty():
		return
	if _refusal_confirmation_order_id != order_id:
		var preview: Dictionary = game_session.call("preview_formal_order_refusal", order_id)
		if not bool(preview.get("success", false)):
			tool_status_label.text = "当前不能婉拒订单。"
			return
		_refusal_confirmation_order_id = order_id
		refuse_active_order_button.text = "确认婉拒（口碑 %d）" % int(preview.get("reputation_delta", -1))
		tool_status_label.text = "再次点击确认婉拒。"
		return
	var result: Dictionary = game_session.call("refuse_formal_order", order_id)
	if bool(result.get("success", false)):
		_on_playable_order_finished(result)


func _on_skip_active_tutorial_pressed() -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null:
		return
	var tutorial := Dictionary(Dictionary(game_session.call("five_area_progression_snapshot")).get("tutorial", {}))
	var tutorial_id := StringName(tutorial.get("active_id", &""))
	if tutorial_id.is_empty():
		return
	if _skip_confirmation_tutorial_id != tutorial_id:
		_skip_confirmation_tutorial_id = tutorial_id
		skip_active_tutorial_button.text = "确认跳过教学"
		tool_status_label.text = "再次点击确认；跳过教学不会增加熟练度。"
		return
	var result: Dictionary = game_session.call("skip_active_area_tutorial")
	if bool(result.get("success", false)):
		_on_playable_order_finished(result)


func _refresh_main_order_controls(order: Dictionary) -> void:
	var order_id := StringName(order.get("order_id", &""))
	if order_id != _refusal_confirmation_order_id:
		_refusal_confirmation_order_id = &""
		refuse_active_order_button.text = "婉拒订单"
	var teaching_area_id := StringName(order.get("teaching_area_id", &""))
	refuse_active_order_button.disabled = order_id.is_empty()
	skip_active_tutorial_button.visible = not teaching_area_id.is_empty()
	skip_active_tutorial_button.disabled = teaching_area_id.is_empty()
	if teaching_area_id.is_empty():
		_skip_confirmation_tutorial_id = &""
		skip_active_tutorial_button.text = "跳过教学"


func apply_progression_effects(snapshot: Dictionary) -> void:
	var owned_items := Array(snapshot.get("owned_items", []))
	var owned_growth_ids := Array(snapshot.get("owned_growth_ids", []))
	var unlocked_stock_ids := Array(snapshot.get("unlocked_stock_ids", []))
	_spreader_width_multiplier = 1.0
	_press_spreader_owned = owned_items.has("tool.spreader.press_once") or owned_growth_ids.has("growth.automation.pancake.press_once")
	_automatic_brush_owned = owned_items.has("tool.sauce_brush.automatic") or owned_growth_ids.has("growth.automation.pancake.auto_sauce_brush")
	_chili_sauce_unlocked = false
	var griddle_tier := int(Dictionary(snapshot.get("device_tiers", {})).get("device.pancake_griddle", 0))
	_intermediate_griddle_owned = griddle_tier >= 1
	_advanced_griddle_owned = griddle_tier >= 2
	_refresh_griddle_upgrade_presentation()
	_refresh_spreader_upgrade_presentation()
	_refresh_sauce_brush_upgrade_presentation()
	_refresh_growth_tool_buttons()
	_refresh_sauce_button_states()


func refresh_progression_ui_after_debug(message: String = "") -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session != null and game_session.has_method("five_area_progression_snapshot"):
		apply_progression_effects(Dictionary(game_session.call("five_area_progression_snapshot")))
	_refresh_global_status()
	if daily_bill_panel != null and daily_bill_panel.visible:
		_refresh_growth_section(message)
		if unlock_progress_panel.visible:
			_refresh_unlock_progress()


func set_sauce_unlocked(sauce_type: StringName, unlocked: bool) -> void:
	if sauce_type == OrderService.SAUCE_CHILI:
		_chili_sauce_unlocked = unlocked
	_refresh_sauce_button_states()


func _refresh_griddle_upgrade_presentation() -> void:
	var griddle_artwork := get_node_or_null("SafeArea/PanBase/GriddleArtwork") as Sprite2D
	if griddle_artwork != null:
		var griddle_texture: Texture2D = BASIC_GRIDDLE_TEXTURE
		if _advanced_griddle_owned:
			griddle_texture = load(ADVANCED_GRIDDLE_TEXTURE_PATH) as Texture2D
		elif _intermediate_griddle_owned:
			griddle_texture = load(INTERMEDIATE_GRIDDLE_TEXTURE_PATH) as Texture2D
		griddle_artwork.texture = griddle_texture


func _refresh_spreader_upgrade_presentation() -> void:
	var texture: Texture2D = BASIC_SPREADER_TEXTURE
	if spreader_artwork != null:
		spreader_artwork.texture = texture
	if scraper_button == null:
		return
	var rack_artwork := scraper_button.get_node_or_null("Artwork") as TextureRect
	if rack_artwork != null:
		rack_artwork.texture = texture
	var label := scraper_button.get_node_or_null("Label") as Label
	if label != null:
		label.text = "摊饼器"
	scraper_button.toggle_mode = true
	scraper_button.button_pressed = false
	scraper_button.tooltip_text = "拿起 T 形摊饼器；用于摊面和摊鸡蛋"


func _refresh_sauce_brush_upgrade_presentation() -> void:
	if sauce_brush_button == null:
		return
	sauce_brush_button.visible = false
	sauce_brush_button.disabled = true
	sauce_brush_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_sauce_selection_presentation()


func _on_spreader_tool_pressed() -> void:
	_select_scraper()


func _on_sauce_brush_tool_pressed() -> void:
	if _automatic_brush_owned:
		sauce_brush_button.button_pressed = false
		use_automatic_sauce_brush()
		return
	if tool_controller.current_tool == ToolController.Tool.SAUCE_BRUSH:
		tool_controller.clear_tool()
		tool_status_label.text = "已放下酱刷；可继续加料或抓住饼皮边缘折叠"
		return
	_select_sauce_brush()


func use_press_spreader() -> Dictionary:
	if not _press_spreader_owned:
		tool_status_label.text = "压饼器尚未安装；可在今日账单的安装位购买。"
		return {"success": false, "reason": &"tool_not_owned"}
	if _press_spreader_used:
		tool_status_label.text = "单次压饼器每张饼只能使用一次"
		return {"success": false, "reason": &"already_used"}
	if p1_session == null or p1_session.phase != P1Session.Phase.SPREAD or not pour_used:
		tool_status_label.text = "倒入面糊后、进入煎制前才能使用压饼器"
		return {"success": false, "reason": &"wrong_phase"}
	var result: Dictionary = pancake_model.call("apply_standard_press_spread")
	if not bool(result.get("success", false)):
		tool_status_label.text = "压饼失败：当前没有可整形的面糊"
		return result
	_press_spreader_used = true
	_spread_shape_locked = true
	p1_session.call("advance_time", 1.2)
	var phase_advanced := _confirm_spread_for_next_action()
	result["success"] = phase_advanced
	if not phase_advanced:
		tool_status_label.text = "压饼器已整形，但未能进入下一制作阶段"
		return result
	tool_status_label.text = "压饼器已形成完整饼皮 · 请直接放鸡蛋"
	return result


func use_automatic_sauce_brush(sauce_type: StringName = &"") -> Dictionary:
	if not _automatic_brush_owned:
		tool_status_label.text = "自动酱刷尚未安装；可在今日账单的安装位购买。"
		return {"success": false, "reason": &"tool_not_owned"}
	if sauce_type.is_empty():
		sauce_type = current_sauce_type
	var state: RefCounted = sauce_tool_states.get(sauce_type)
	if state == null or float(state.get("load")) <= 0.0:
		tool_status_label.text = "自动酱刷仍需先挤入%s" % OrderService.sauce_display_name(sauce_type)
		return {"success": false, "reason": &"sauce_not_loaded", "sauce_type": sauce_type}
	var phase_result := _enter_sauce_and_fillings_for_sauce_action()
	if not bool(phase_result.get("success", false)):
		tool_status_label.text = str(phase_result.get("reason", "当前不能使用自动酱刷"))
		return {"success": false, "reason": &"wrong_phase", "sauce_type": sauce_type}
	var total_changed := 0
	var covered_cells := maxi(pancake_model.covered_cell_count(), 1)
	var load_per_cell := parameters.sauce_brush_capacity / float(covered_cells)
	var remaining_cells := floori(float(state.get("load")) / maxf(load_per_cell, 0.000001))
	var stroke_id := pancake_model.begin_sauce_stroke()
	var step := maxi(roundi(parameters.sauce_brush_radius * 1.35), 1)
	for y in range(step / 2, pancake_model.grid_size, step):
		for x in range(step / 2, pancake_model.grid_size, step):
			if remaining_cells <= 0:
				break
			var result := pancake_model.apply_sauce_sample(Vector2(x, y), parameters.sauce_layer_concentration, parameters.sauce_brush_radius, stroke_id, remaining_cells, sauce_type)
			var changed := int(result.get("newly_layered_cells", 0))
			remaining_cells -= changed
			total_changed += changed
		if remaining_cells <= 0:
			break
	state.call("consume", float(total_changed) * load_per_cell)
	p1_session.call("advance_time", 1.5)
	tool_controller.clear_tool()
	_refresh_sauce_load_display()
	tool_status_label.text = "自动酱刷已刷匀%s并回到空手状态" % OrderService.sauce_display_name(sauce_type)
	return {"success": total_changed > 0, "changed_cells": total_changed, "sauce_type": sauce_type}


func _refresh_growth_tool_buttons() -> void:
	if press_spreader_button == null or automatic_sauce_brush_button == null:
		return
	# The press is a separate one-shot batter tool. It must never replace the
	# T-shaped spreader, which remains necessary for spreading egg.
	press_spreader_button.visible = _press_spreader_owned
	press_spreader_button.disabled = not _press_spreader_owned
	press_spreader_button.mouse_filter = Control.MOUSE_FILTER_STOP if _press_spreader_owned else Control.MOUSE_FILTER_IGNORE
	automatic_sauce_brush_button.visible = false
	automatic_sauce_brush_button.disabled = true
	automatic_sauce_brush_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var in_spread := p1_session != null and p1_session.phase == P1Session.Phase.SPREAD and pour_used and not _press_spreader_used
	if _press_spreader_owned:
		press_spreader_button.disabled = false
		press_spreader_button.tooltip_text = "压饼器：点击一次形成标准饼皮；当前可用" if in_spread else "压饼器只用于已倒入面糊、尚未进入煎制的饼皮；点击可查看当前不能使用的原因。"
	sauce_brush_button.visible = false
	sauce_brush_button.disabled = true
	sauce_brush_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_sauce_selection_presentation()


func _process(delta: float) -> void:
	if not _customer_reaction_prewarm_started:
		_customer_reaction_prewarm_started = true
		_customer_portraits.call("enable_reaction_prewarm")
	if bool(_customer_portraits.call("poll")):
		_refresh_customer_queue()
		if not _customer_visual_state.is_empty():
			_set_customer_portrait_state(_customer_visual_state)
	_advance_business_day_timer(delta)
	if _business_day_closed:
		return
	var game_session := get_node_or_null("/root/GameSession")
	var formal_time_paused := _formal_order_time_paused()
	var active_formal_order: Dictionary = {}
	var current_formal_orders: Variant = null
	var mirrors_formal_pancake_patience := false
	if game_session != null and game_session.has_method("advance_formal_order_patience") and not formal_time_paused:
		var patience_result: Dictionary = game_session.call("advance_formal_order_patience", delta)
		current_formal_orders = Array(patience_result.get("active_orders", []))
		for expired_variant in Array(patience_result.get("expired_results", [])):
			var expired: Dictionary = Dictionary(expired_variant)
			if not bool(expired.get("already_settled", false)):
				_on_formal_order_expired(expired)
	_refresh_formal_patience_ui(game_session, current_formal_orders)
	if game_session != null and game_session.has_method("formal_order") and not _formal_order_id.is_empty():
		active_formal_order = game_session.call("formal_order", _formal_order_id)
	elif game_session != null and game_session.has_method("active_formal_order"):
		active_formal_order = game_session.call("active_formal_order")
		var active_items: Array = Array(active_formal_order.get("items", []))
		mirrors_formal_pancake_patience = p1_session != null and not active_items.is_empty() and StringName(Dictionary(active_items[0]).get("area_id", &"")) == &"area.pancake"
		if mirrors_formal_pancake_patience:
			p1_session.mirror_formal_patience(
				float(active_formal_order.get("remaining_patience_seconds", p1_session.patience_seconds)),
				bool(active_formal_order.get("tutorial_no_countdown", false))
			)
	if game_session != null and game_session.has_method("advance_pancake_holding_tray"):
		game_session.call("advance_pancake_holding_tray", delta)
	if game_session != null and game_session.has_method("advance_f3_production") and not formal_time_paused:
		game_session.call("advance_f3_production", delta)
	if pancake_surface == null:
		return
	_update_surface_readout()
	_update_spreader_artwork(delta)
	if p1_session != null and not formal_time_paused:
		if mirrors_formal_pancake_patience:
			p1_session.advance_elapsed_time(delta)
		else:
			p1_session.advance_time(delta)
	if _squeezing_sauce:
		sauce_tool_state.add(parameters.sauce_squeeze_rate * delta)
		_refresh_sauce_load_display()
	_simulation_accumulator += delta
	while _simulation_accumulator + 0.000001 >= parameters.simulation_step_seconds:
		if pour_used and not _folding_locks_preparation() and _is_active_cooking_phase():
			pancake_model.cooking_doneness_cap = PANCAKE_SCORER_SCRIPT.heat_target_for(StringName(p1_session.order.get("heat_preference", &"golden"))) if _intermediate_griddle_owned else 1.0
			pancake_model.advance_cooking(parameters.simulation_step_seconds, p1_session.heat_level)
		else:
			pancake_model.advance_solidification(parameters.simulation_step_seconds)
		_simulation_accumulator -= parameters.simulation_step_seconds
	_update_cooking_audio(delta)
	if not pancake_surface.pointer_pressed:
		return
	if not PancakeSpace.is_inside_pan(pancake_surface.pointer_local_position, pancake_surface.size, parameters.pan_height_ratio):
		return
	var grid_position := PancakeSpace.local_to_grid_position(
		pancake_surface.pointer_local_position, pancake_surface.size, pancake_model.grid_size
	)
	match tool_controller.current_tool:
		ToolController.Tool.SCRAPER:
			_process_scraper(grid_position, delta)
		ToolController.Tool.SAUCE_BRUSH:
			_process_sauce_brush(grid_position)
		ToolController.Tool.FOLD:
			fold_model.update_drag(grid_position)


func _exit_tree() -> void:
	if _customer_portraits != null:
		_customer_portraits.call("finish_pending")


func _formal_order_time_paused() -> bool:
	var game_session := get_node_or_null("/root/GameSession")
	var business_paused := game_session != null and game_session.has_method("is_business_paused") and bool(game_session.call("is_business_paused"))
	return business_paused or get_tree().paused or daily_bill_panel.visible or unlock_progress_panel.visible


func _advance_business_day_timer(delta: float) -> void:
	if business_day_timer == null or _business_day_closed:
		return
	if _active_formal_order_is_tutorial():
		if business_day_timer_label != null:
			business_day_timer_label.text = "教学中"
			business_day_timer_label.add_theme_color_override("font_color", Color(1, 0.82, 0.34, 1))
		return
	var timer_state: Dictionary = business_day_timer.call("advance", delta)
	var remaining := maxi(int(timer_state.get("remaining_whole_seconds", 0)), 0)
	var warning_active := bool(timer_state.get("warning_active", false))
	if business_day_timer_label != null:
		business_day_timer_label.text = "距离打烊 %02d:%02d · 归零即结算" % [remaining / 60, remaining % 60] if warning_active else "营业倒计时 %02d:%02d" % [remaining / 60, remaining % 60]
		business_day_timer_label.add_theme_color_override("font_color", Color(1, 0.36, 0.24, 1) if warning_active else Color(1, 0.82, 0.34, 1))
	if remaining != _last_persisted_business_second:
		_last_persisted_business_second = remaining
		var game_session := get_node_or_null("/root/GameSession")
		if game_session != null and game_session.has_method("set_business_day_remaining_seconds"):
			game_session.call("set_business_day_remaining_seconds", float(timer_state.get("remaining_seconds", 0.0)))
	if bool(timer_state.get("expired_now", false)):
		var legacy_transaction_grace := (
			_allows_transaction_cutoff_grace()
			and p1_session != null
			and p1_session.phase in [P1Session.Phase.HANDOFF, P1Session.Phase.PAYMENT, P1Session.Phase.RESULT]
		)
		if legacy_transaction_grace or _should_defer_business_day_expiration():
			# Let the current customer transaction finish. Legacy scenes defer only
			# during handoff/payment; formal shells may keep the focused order alive.
			_business_day_expiration_pending = true
			return
		_end_business_day_for_timer()


func _active_formal_order_is_tutorial() -> bool:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session != null and game_session.has_method("active_formal_order"):
		var active_order := Dictionary(game_session.call("active_formal_order"))
		return not active_order.is_empty() and bool(active_order.get("tutorial_no_countdown", false))
	return p1_session != null and not p1_session.order.is_empty() and bool(p1_session.order.get("tutorial_no_countdown", false))


func _should_defer_business_day_expiration() -> bool:
	return false


func _allows_transaction_cutoff_grace() -> bool:
	return true


func _end_business_day_for_timer() -> void:
	_end_business_day_at_cutoff(&"timer_expired")


func end_business_day_early_for_testing() -> void:
	_end_business_day_at_cutoff(&"test_early_end")


func end_business_day_early() -> void:
	_end_business_day_at_cutoff(&"manual_early_end")


func can_end_business_day_early_for_testing() -> bool:
	return not _business_day_closed and not daily_bill_panel.visible


func _end_business_day_at_cutoff(cutoff_reason: StringName) -> void:
	if _business_day_closed:
		return
	_business_day_expiration_pending = false
	_business_day_closed = true
	if _handoff_tween != null and _handoff_tween.is_valid():
		_handoff_tween.kill()
	business_day_closed_shield.visible = true
	var queued_customers: int = customer_queue.call("queue_snapshot").size() if customer_queue != null else 0
	var game_session := get_node_or_null("/root/GameSession")
	if game_session != null and game_session.has_method("active_formal_orders"):
		queued_customers = Array(game_session.call("active_formal_orders")).size() + Array(game_session.call("waiting_formal_orders")).size()
	if business_day_timer != null:
		business_day_timer.set("remaining_seconds", 0.0)
	if game_session != null and game_session.has_method("set_business_day_remaining_seconds"):
		game_session.call("set_business_day_remaining_seconds", 0.0)
	end_business_day({
		"reason": cutoff_reason,
		"unserved_customer_count": queued_customers,
	})


func reset_pancake() -> void:
	_pending_delivery_item_index = -1
	# The formal three-area shell has no inherited single-griddle surface. Its
	# compact units own their own reset lifecycle and must not be cleared when a
	# customer order advances or a payment recovery finishes.
	if pancake_surface == null:
		if p1_session != null:
			p1_session.start(p1_session.order)
		return
	pancake_model.reset()
	ingredient_model.reset()
	pancake_visual.visible = true
	ingredient_layer.visible = true
	sauce_blob_overlay.visible = true
	pour_used = false
	_press_spreader_used = false
	_spread_shape_locked = false
	ladle_button.disabled = false
	pancake_surface.clear_trace()
	pancake_surface.pointer_pressed = false
	_scrape_sampler.reset()
	_egg_sampler.reset()
	_sauce_sampler.reset()
	for state in sauce_tool_states.values():
		state.reset()
	current_sauce_type = OrderService.SAUCE_SWEET
	sauce_tool_state = sauce_tool_states[current_sauce_type]
	_squeezing_sauce = false
	_sauce_stroke_id = 0
	fold_model.reset()
	_audio_update_accumulator = 0.0
	kitchen_audio.call("set_sizzle", false, 0.0)
	if p1_session != null:
		p1_session.start(p1_session.order)
	tool_controller.clear_tool()
	warning_label.text = "当前无破洞风险"
	warning_label.modulate = Color(0.76, 0.92, 0.76)
	_update_sauce_status()
	result_panel.visible = false
	order_summary_card.visible = false
	if result_detail_input_shield != null:
		result_detail_input_shield.visible = false
	payment_sprite.visible = false
	handoff_product_sprite.visible = false
	serve_product_button.visible = false
	store_pancake_button.visible = false
	fold_overlay.visible = true
	_result_detail_open = false
	ingredient_drag_preview.visible = false
	_stop_egg_crack_effect()
	_ingredient_drag_type = &""
	_log_info(&"simulation", "Pancake grid reset in %d us" % pancake_model.last_update_usec)


func _discard_current_pancake() -> void:
	if p1_session == null or p1_session.phase in [P1Session.Phase.HANDOFF, P1Session.Phase.PAYMENT, P1Session.Phase.RESULT]:
		return
	var elapsed_seconds := p1_session.elapsed_seconds
	var patience_seconds := p1_session.patience_seconds
	reset_pancake()
	p1_session.elapsed_seconds = elapsed_seconds
	p1_session.patience_seconds = patience_seconds
	p1_session.changed.emit()
	tool_status_label.text = "已丢弃当前煎饼；顾客仍在等待，请重新制作"


func set_heatmap_field(field_name: StringName) -> void:
	pancake_surface.set_heatmap_field(field_name)


func pan_local_to_grid(local_position: Vector2) -> Vector2i:
	return PancakeSpace.local_to_grid(local_position, pancake_surface.size, pancake_model.grid_size)


func _process_scraper(grid_position: Vector2, delta: float) -> void:
	if p1_session.phase == P1Session.Phase.FIRST_SIDE or (
		p1_session.phase == P1Session.Phase.SAUCE_AND_FILLINGS
		and pancake_model.has_egg()
		and pancake_model.egg_is_on_visible_side()
	):
		_process_egg_scraper(grid_position, delta)
		return
	if p1_session.phase != P1Session.Phase.SPREAD:
		pancake_surface.spreader_motion_valid = false
		tool_status_label.text = "当前步骤不需要使用 T 形摊面器"
		return
	var samples := _scrape_sampler.sample_to(grid_position)
	var previous_polar := _pan_polar_offset(_last_process_grid_position)
	var current_polar := _pan_polar_offset(grid_position)
	var angular_delta := absf(wrapf(current_polar.angle() - previous_polar.angle(), -PI, PI))
	var raw_angular_speed := angular_delta / maxf(delta, 0.000001)
	_update_spreader_speed(raw_angular_speed, delta)
	var effect_speed := _spreader_effect_speed()
	var applied_sample := false
	for sample in samples:
		var previous_offset := _pan_polar_offset(_previous_scrape_sample)
		var sample_offset := _pan_polar_offset(sample)
		var motion_distance := previous_offset.distance_to(sample_offset)
		if motion_distance <= 0.0001 or sample_offset.length() <= 1.0:
			_previous_scrape_sample = sample
			continue
		var sample_angle_delta := absf(wrapf(sample_offset.angle() - previous_offset.angle(), -PI, PI))
		var tangential_distance := sample_angle_delta * (previous_offset.length() + sample_offset.length()) * 0.5
		var circularity := tangential_distance / motion_distance
		var moving_too_far_inward := sample_offset.length() + parameters.spreader_inward_tolerance < _spreader_max_radius
		var circular_motion := circularity >= parameters.spreader_min_circularity
		if moving_too_far_inward:
			_spreader_direction_grace_remaining = 0
			_previous_scrape_sample = sample
			continue
		if circular_motion:
			_spreader_direction_grace_remaining = parameters.spreader_direction_grace_samples
		elif _spreader_direction_grace_remaining > 0:
			_spreader_direction_grace_remaining -= 1
		else:
			_previous_scrape_sample = sample
			continue
		var outward_direction := Vector2.from_angle(_spreader_smoothed_angle)
		var result := pancake_model.apply_scraper_sample(sample, outward_direction, effect_speed, _spreader_width_multiplier)
		_previous_scrape_sample = sample
		_spreader_max_radius = maxf(_spreader_max_radius, sample_offset.length())
		applied_sample = true
		_update_damage_warning(float(result.peak_damage), int(result.new_holes))
	_last_process_grid_position = grid_position
	pancake_surface.spreader_motion_valid = applied_sample
	if applied_sample:
		tool_status_label.text = "正在摊饼：速度%s（%s）" % [_spreader_speed_label(), _spreader_thickness_label()]
		var now := Time.get_ticks_msec()
		if now - _last_sizzle_msec > 180:
			_last_sizzle_msec = now
			kitchen_audio.call("play_cue", &"scrape")
	else:
		tool_status_label.text = "T形摊饼器：请绕鏊心画圈并逐步向外"
	pancake_surface.queue_redraw()


func _process_egg_scraper(grid_position: Vector2, delta: float) -> void:
	if not pancake_model.has_egg():
		pancake_surface.spreader_motion_valid = false
		tool_status_label.text = "先把完整鸡蛋拖到饼面，再用 T 形摊面器摊开"
		return
	var raw_samples := _egg_sampler.sample_to(grid_position)
	var samples := _limit_egg_samples(raw_samples)
	var previous_polar := _pan_polar_offset(_last_process_grid_position)
	var current_polar := _pan_polar_offset(grid_position)
	var angular_delta := absf(wrapf(current_polar.angle() - previous_polar.angle(), -PI, PI))
	var raw_angular_speed := angular_delta / maxf(delta, 0.000001)
	_update_spreader_speed(raw_angular_speed, delta)
	var effect_speed := _spreader_effect_speed()
	var result := pancake_model.apply_egg_spreader_path(samples, effect_speed, _spreader_width_multiplier)
	var applied_sample := int(result.changed_cells) > 0
	if not samples.is_empty():
		_previous_scrape_sample = samples[samples.size() - 1]
	_last_process_grid_position = grid_position
	pancake_surface.spreader_motion_valid = applied_sample
	if applied_sample:
		_stop_egg_crack_effect()
		var egg_summary := pancake_model.calculate_egg_spread_summary()
		var set_hint := " · 已凝固，移动很慢" if pancake_model.egg_state == PancakeModel.EggState.SET else ""
		tool_status_label.text = "正在摊蛋：覆盖 %d%% · 均匀 %d%%%s" % [
			roundi(float(egg_summary.coverage_ratio) * 100.0),
			roundi(float(egg_summary.uniformity) * 100.0),
			set_hint,
		]
		var now := Time.get_ticks_msec()
		if now - _last_sizzle_msec > 180:
			_last_sizzle_msec = now
			kitchen_audio.call("play_cue", &"scrape")
	else:
		tool_status_label.text = "让 T 形横杆接触蛋液并连续画圈"
	pancake_surface.queue_redraw()


func _process_sauce_brush(grid_position: Vector2) -> void:
	var samples := _sauce_sampler.sample_to(grid_position)
	for sample in samples:
		_apply_sauce_brush_sample(sample)
	_last_process_grid_position = grid_position


func _apply_sauce_brush_sample(grid_position: Vector2) -> void:
	var covered_cells := pancake_model.covered_cell_count()
	if covered_cells <= 0:
		return
	var load_per_cell := parameters.sauce_brush_capacity / float(covered_cells)
	var maximum_cells := floori(float(sauce_tool_state.load) / maxf(load_per_cell, 0.000001))
	if maximum_cells <= 0:
		tool_status_label.text = "饼面没有待刷的酱料：先点击或按住右侧酱瓶挤酱"
		return
	var result := pancake_model.apply_sauce_sample(
		grid_position,
		parameters.sauce_layer_concentration,
		parameters.sauce_brush_radius,
		_sauce_stroke_id,
		maximum_cells,
		current_sauce_type
	)
	sauce_tool_state.consume(float(result.newly_layered_cells) * load_per_cell)
	if int(result.newly_layered_cells) > 0:
		kitchen_audio.call("play_cue", &"sauce")
	_refresh_sauce_load_display()


func _on_pointer_started(local_position: Vector2) -> void:
	var grid_position := PancakeSpace.local_to_grid_position(local_position, pancake_surface.size, pancake_model.grid_size)
	_last_process_grid_position = grid_position
	# Grabbing an exposed edge is the fold command itself.  It enters the guarded
	# FOLD phase when appropriate, then begins the same drag without requiring a
	# separate FoldButton click.
	if (
		p1_session != null
		and p1_session.phase == P1Session.Phase.SAUCE_AND_FILLINGS
		and tool_controller.current_tool in [ToolController.Tool.NONE, ToolController.Tool.SAUCE_BRUSH, ToolController.Tool.FOLD]
		and _is_fold_grab_edge(grid_position)
	):
		p1_session.begin_folding()
	if p1_session != null and p1_session.phase == P1Session.Phase.FOLD and tool_controller.current_tool != ToolController.Tool.FOLD:
		_select_fold()
	match tool_controller.current_tool:
		ToolController.Tool.LADLE:
			pancake_surface.pointer_pressed = false
			tool_status_label.text = "无需点击鏊面；面糊勺按钮会自动定量倒在正中"
		ToolController.Tool.SCRAPER:
			if p1_session.phase == P1Session.Phase.FIRST_SIDE:
				_egg_sampler.begin(grid_position)
			else:
				_scrape_sampler.begin(grid_position)
			_previous_scrape_sample = grid_position
			_spreader_max_radius = _pan_polar_offset(grid_position).length()
			_spreader_direction_grace_remaining = 0
			_spreader_speed_initialized = false
			_spreader_speed_band = SPREADER_SPEED_MEDIUM
			pancake_surface.spreader_motion_valid = false
		ToolController.Tool.SAUCE_BRUSH:
			_sauce_sampler.begin(grid_position)
			_sauce_stroke_id = pancake_model.begin_sauce_stroke()
			_apply_sauce_brush_sample(grid_position)
		ToolController.Tool.FOLD:
			if not fold_model.begin_drag(grid_position):
				pancake_surface.pointer_pressed = false
				tool_status_label.text = "请抓住尚未折叠的左侧或右侧饼皮边缘"
		_:
			tool_status_label.text = "请先点击左侧工具"


func _is_fold_grab_edge(grid_position: Vector2) -> bool:
	if pancake_model == null:
		return false
	var ratio := grid_position.x / maxf(float(pancake_model.grid_size - 1), 1.0)
	var edge_ratio := pancake_model.parameters.fold_grab_edge_ratio
	return ratio <= edge_ratio or ratio >= 1.0 - edge_ratio


func _on_pointer_ended(local_position: Vector2) -> void:
	var finished_spread_shape := (
		tool_controller.current_tool == ToolController.Tool.SCRAPER
		and p1_session != null
		and p1_session.phase == P1Session.Phase.SPREAD
	)
	if tool_controller.current_tool == ToolController.Tool.FOLD and fold_model.active_region != FOLD_MODEL_SCRIPT.REGION_NONE:
		var grid_position := PancakeSpace.local_to_grid_position(local_position, pancake_surface.size, pancake_model.grid_size)
		var result: Dictionary = fold_model.release_drag(grid_position)
		if bool(result.get("committed", false)):
			tool_status_label.text = fold_model.result_label(result)
			kitchen_audio.call("play_cue", &"fold")
		else:
			tool_status_label.text = str(result.get("reason", "折叠未完成"))
	_scrape_sampler.reset()
	_egg_sampler.reset()
	_sauce_sampler.reset()
	if finished_spread_shape:
		_spread_shape_locked = true
		if _confirm_spread_for_next_action():
			tool_status_label.text = "面饼形状已固定；可直接翻面，鸡蛋按订单需要添加"
		else:
			tool_controller.clear_tool()
			tool_status_label.text = "当前没有可继续制作的面饼"
			_refresh_p1_ui()
	_update_sauce_status()


func _play_egg_crack_effect(local_position: Vector2) -> void:
	_stop_egg_crack_effect(false)
	egg_crack_artwork.position = local_position
	egg_crack_artwork.rotation = 0.0
	egg_crack_artwork.visible = false
	egg_crack_effect.position = Vector2(pancake_surface.size.x * 0.5, EGG_CRACK_EFFECT_STAGE_Y)
	egg_crack_effect.frame = 0
	egg_crack_effect.rotation = -0.10
	egg_crack_effect.scale = EGG_CRACK_EFFECT_BASE_SCALE * 0.82
	egg_crack_effect.visible = true
	egg_crack_effect.play(&"crack")
	_egg_crack_tween = create_tween()
	_egg_crack_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_egg_crack_tween.parallel().tween_property(egg_crack_effect, "scale", EGG_CRACK_EFFECT_BASE_SCALE * 1.10, 0.16)
	_egg_crack_tween.parallel().tween_property(egg_crack_effect, "rotation", 0.055, 0.16)
	_egg_crack_tween.tween_property(egg_crack_effect, "scale", EGG_CRACK_EFFECT_BASE_SCALE, 0.16)
	_egg_crack_tween.parallel().tween_property(egg_crack_effect, "rotation", 0.0, 0.16)


func _on_egg_crack_animation_finished() -> void:
	_stop_egg_crack_effect(false)
	if pancake_model != null and pancake_model.egg_state == PancakeModel.EggState.CRACKED and pancake_model.egg_is_on_visible_side():
		egg_crack_artwork.visible = true


func _stop_egg_crack_effect(hide_landing: bool = true) -> void:
	if _egg_crack_tween != null and _egg_crack_tween.is_valid():
		_egg_crack_tween.kill()
	_egg_crack_tween = null
	if egg_crack_effect != null:
		egg_crack_effect.stop()
		egg_crack_effect.frame = 0
		egg_crack_effect.visible = false
		egg_crack_effect.rotation = 0.0
		egg_crack_effect.scale = EGG_CRACK_EFFECT_BASE_SCALE
	if hide_landing and egg_crack_artwork != null:
		egg_crack_artwork.visible = false


func _on_cancel_requested() -> void:
	_cancel_ingredient_drag()
	tool_controller.clear_tool()
	fold_model.cancel_drag()
	_scrape_sampler.reset()
	_egg_sampler.reset()
	_sauce_sampler.reset()
	_update_sauce_status()


func _select_ladle() -> void:
	if _folding_locks_preparation():
		tool_status_label.text = "折叠已经开始；按 R 重置后才能返回制作步骤"
		return
	if pour_used:
		tool_status_label.text = "面糊已自动倒完；本张饼不能再次加面"
		return
	_auto_pour_center()


func _select_scraper() -> void:
	if _folding_locks_preparation():
		tool_status_label.text = "折叠已经开始；不能再使用刮板"
		return
	if not _scraper_can_act():
		tool_status_label.text = "当前步骤不需要使用 T 形摊面器"
		return
	tool_controller.select_tool(ToolController.Tool.SCRAPER)


func _select_sauce_brush() -> void:
	if _folding_locks_preparation():
		tool_status_label.text = "折叠已经开始；不能再刷酱"
		return
	if not _confirm_spread_for_next_action():
		return
	if float(sauce_tool_state.load) <= 0.0:
		tool_status_label.text = "先点击或按住秘制酱料，把酱挤到饼面"
		return
	var phase_result := _enter_sauce_and_fillings_for_sauce_action()
	if not bool(phase_result.get("success", false)):
		tool_status_label.text = str(phase_result.get("reason", "当前不能刷酱"))
		return
	tool_controller.select_tool(ToolController.Tool.SAUCE_BRUSH)


func _select_fold() -> void:
	if pancake_model.covered_cell_count() <= 0:
		fold_button.button_pressed = false
		tool_status_label.text = "当前没有可折叠的面饼"
		return
	if not _confirm_spread_for_next_action():
		fold_button.button_pressed = false
		return
	if fold_model.package_result != FOLD_MODEL_SCRIPT.PACKAGE_NONE or fold_model.completed_fold_count() >= 2:
		fold_button.button_pressed = false
		tool_status_label.text = "折叠阶段已完成；请选择可用包装或按 R 重置"
		return
	if p1_session != null and p1_session.phase in [P1Session.Phase.FIRST_SIDE, P1Session.Phase.SECOND_SIDE, P1Session.Phase.SAUCE_AND_FILLINGS]:
		var phase_result := p1_session.begin_folding()
		if not bool(phase_result.success):
			tool_status_label.text = str(phase_result.reason)
			return
	_stop_egg_crack_effect()
	tool_controller.select_tool(ToolController.Tool.FOLD)


func _on_sauce_squeeze_started() -> void:
	_start_sauce_squeeze(OrderService.SAUCE_SWEET)


func _on_chili_sauce_squeeze_started() -> void:
	_start_sauce_squeeze(OrderService.SAUCE_CHILI)


func _start_sauce_squeeze(sauce_type: StringName) -> void:
	_select_sauce_type(sauce_type)
	_begin_sauce_squeeze()


func _begin_sauce_squeeze() -> void:
	if _folding_locks_preparation():
		_squeezing_sauce = false
		tool_status_label.text = "折叠已经开始；不能再挤酱"
		return
	if not _confirm_spread_for_next_action():
		_squeezing_sauce = false
		return
	var phase_result := _enter_sauce_and_fillings_for_sauce_action()
	if not bool(phase_result.get("success", false)):
		_squeezing_sauce = false
		tool_status_label.text = str(phase_result.get("reason", "当前不能挤酱"))
		return
	_squeezing_sauce = true
	sauce_tool_state.add(parameters.sauce_squeeze_initial_amount)
	tool_status_label.text = "正在挤%s：按住越久，饼面上的酱越多" % OrderService.sauce_display_name(current_sauce_type)
	_refresh_sauce_load_display()


func _on_sauce_squeeze_ended() -> void:
	if not _squeezing_sauce:
		return
	_squeezing_sauce = false
	_refresh_sauce_load_display()
	if _automatic_brush_owned:
		use_automatic_sauce_brush(current_sauce_type)
		return
	_select_sauce_brush()
	if tool_controller.current_tool == ToolController.Tool.SAUCE_BRUSH:
		tool_status_label.text = "%s刷已拿起：在饼面拖动刷匀；右键可取消" % OrderService.sauce_display_name(current_sauce_type)


func _on_tool_changed(tool: ToolController.Tool) -> void:
	var preparation_locked := _folding_locks_preparation()
	ladle_button.disabled = pour_used or preparation_locked
	ladle_button.button_pressed = false
	scraper_button.disabled = preparation_locked or not _scraper_can_act()
	scraper_button.button_pressed = tool == ToolController.Tool.SCRAPER and not preparation_locked
	sauce_brush_button.visible = false
	sauce_brush_button.disabled = true
	sauce_brush_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_sauce_button_states()
	fold_button.disabled = fold_model.package_result != FOLD_MODEL_SCRIPT.PACKAGE_NONE or fold_model.completed_fold_count() >= 2
	fold_button.button_pressed = tool == ToolController.Tool.FOLD and not fold_button.disabled
	fold_overlay.set_guides_visible(tool == ToolController.Tool.FOLD and not fold_button.disabled)
	tool_status_label.text = "当前工具：%s" % tool_controller.display_name()
	match tool:
		ToolController.Tool.LADLE:
			pancake_surface.cursor_radius_pixels = parameters.pour_radius / float(parameters.grid_size) * pancake_surface.size.x
			pancake_surface.cursor_is_t_spreader = false
		ToolController.Tool.SCRAPER:
			pancake_surface.cursor_radius_pixels = parameters.scraper_width * _spreader_width_multiplier * 0.5 / float(parameters.grid_size) * pancake_surface.size.x
			pancake_surface.cursor_is_t_spreader = true
		ToolController.Tool.SAUCE_BRUSH:
			pancake_surface.cursor_radius_pixels = parameters.sauce_brush_radius / float(parameters.grid_size) * pancake_surface.size.x
			pancake_surface.cursor_is_t_spreader = false
			tool_status_label.text = "当前工具：%s刷 · 饼面拖动刷匀 · 右键取消" % OrderService.sauce_display_name(current_sauce_type)
		ToolController.Tool.FOLD:
			pancake_surface.cursor_radius_pixels = 18.0
			pancake_surface.cursor_is_t_spreader = false
		_:
			pancake_surface.cursor_radius_pixels = 8.0
			pancake_surface.cursor_is_t_spreader = false
	if tool != ToolController.Tool.SCRAPER:
		_spreader_angle_initialized = false
		_spreader_speed_initialized = false
	_update_spreader_artwork(0.0)
	_refresh_sauce_selection_presentation()
	pancake_surface.queue_redraw()
	_refresh_fold_ui()


func _update_spreader_artwork(delta: float) -> void:
	var spreader_selected := tool_controller.current_tool == ToolController.Tool.SCRAPER
	var pointer_inside := PancakeSpace.is_inside_pan(
		pancake_surface.pointer_local_position,
		pancake_surface.size,
		parameters.pan_height_ratio
	)
	spreader_artwork.visible = spreader_selected and pointer_inside
	if not spreader_artwork.visible:
		return
	var contact_position := pancake_surface.pointer_local_position
	var radial := contact_position - pancake_surface.size * 0.5
	if radial.length_squared() > 0.01:
		var target_angle := radial.angle()
		if not _spreader_angle_initialized or delta <= 0.0:
			_spreader_smoothed_angle = target_angle
			_spreader_angle_initialized = true
		else:
			var response_blend := 1.0 - exp(-delta / maxf(parameters.spreader_rotation_response_seconds, 0.001))
			var target_delta := wrapf(target_angle - _spreader_smoothed_angle, -PI, PI)
			if absf(target_delta) > parameters.spreader_rotation_dead_zone:
				var effective_delta := target_delta - signf(target_delta) * parameters.spreader_rotation_dead_zone
				var maximum_step := parameters.spreader_max_turn_rate * delta
				_spreader_smoothed_angle = wrapf(
					_spreader_smoothed_angle + clampf(effective_delta * response_blend, -maximum_step, maximum_step),
					-PI,
					PI
				)
		pancake_surface.spreader_radial_angle = _spreader_smoothed_angle
	spreader_artwork.position = contact_position
	spreader_artwork.rotation = pancake_surface.spreader_radial_angle + SPREADER_ART_ROTATION_OFFSET


func _update_spreader_speed(raw_angular_speed: float, delta: float) -> void:
	if not _spreader_speed_initialized:
		_spreader_smoothed_angular_speed = raw_angular_speed
		_spreader_speed_initialized = true
	else:
		var blend := 1.0 - exp(-delta / maxf(parameters.spreader_speed_smoothing_seconds, 0.001))
		_spreader_smoothed_angular_speed = lerpf(_spreader_smoothed_angular_speed, raw_angular_speed, blend)
	var hysteresis := parameters.spreader_speed_hysteresis
	match _spreader_speed_band:
		SPREADER_SPEED_SLOW:
			if _spreader_smoothed_angular_speed > parameters.spreader_slow_angular_speed + hysteresis:
				_spreader_speed_band = SPREADER_SPEED_MEDIUM
		SPREADER_SPEED_FAST:
			if _spreader_smoothed_angular_speed < parameters.spreader_fast_angular_speed - hysteresis:
				_spreader_speed_band = SPREADER_SPEED_MEDIUM
		_:
			if _spreader_smoothed_angular_speed < parameters.spreader_slow_angular_speed - hysteresis:
				_spreader_speed_band = SPREADER_SPEED_SLOW
			elif _spreader_smoothed_angular_speed > parameters.spreader_fast_angular_speed + hysteresis:
				_spreader_speed_band = SPREADER_SPEED_FAST


func _spreader_effect_speed() -> float:
	match _spreader_speed_band:
		SPREADER_SPEED_SLOW:
			return parameters.spreader_slow_effect_speed
		SPREADER_SPEED_FAST:
			return parameters.spreader_fast_effect_speed
		_:
			return parameters.spreader_medium_effect_speed


func _spreader_speed_label() -> String:
	match _spreader_speed_band:
		SPREADER_SPEED_SLOW:
			return "慢"
		SPREADER_SPEED_FAST:
			return "快"
		_:
			return "适中"


func _spreader_thickness_label() -> String:
	match _spreader_speed_band:
		SPREADER_SPEED_SLOW:
			return "偏薄"
		SPREADER_SPEED_FAST:
			return "偏厚"
		_:
			return "标准厚度"


func _refresh_fold_ui() -> void:
	if not is_instance_valid(fold_status_label):
		return
	var left_visual_progress := 1.0 if fold_model.is_region_folded(FOLD_MODEL_SCRIPT.REGION_LEFT) else 0.0
	var right_visual_progress := 1.0 if fold_model.is_region_folded(FOLD_MODEL_SCRIPT.REGION_RIGHT) else 0.0
	if fold_model.active_region == FOLD_MODEL_SCRIPT.REGION_LEFT:
		left_visual_progress = float(fold_model.drag_progress)
	elif fold_model.active_region == FOLD_MODEL_SCRIPT.REGION_RIGHT:
		right_visual_progress = float(fold_model.drag_progress)
	pancake_surface.set_fold_visual_state(
		left_visual_progress,
		right_visual_progress,
		fold_model.package_result != FOLD_MODEL_SCRIPT.PACKAGE_NONE
	)
	fold_overlay.set_fold_sauce_textures(
		pancake_surface.fold_sweet_sauce_texture(),
		pancake_surface.fold_chili_sauce_texture(),
	)
	sauce_blob_overlay.call("set_fold_progress", left_visual_progress, right_visual_progress)
	var left: Dictionary = fold_model.get_region_result(FOLD_MODEL_SCRIPT.REGION_LEFT)
	var right: Dictionary = fold_model.get_region_result(FOLD_MODEL_SCRIPT.REGION_RIGHT)
	var left_text: String = fold_model.result_label(left) if bool(left.get("folded", false)) else "待折"
	var right_text: String = fold_model.result_label(right) if bool(right.get("folded", false)) else "待折"
	if fold_model.package_result == FOLD_MODEL_SCRIPT.PACKAGE_BAG:
		fold_status_label.text = "折叠完整 · 已装入纸袋"
	else:
		fold_status_label.text = "左：%s · 右：%s" % [left_text, right_text]
	var preparation_locked := _folding_locks_preparation()
	ladle_button.disabled = pour_used or preparation_locked
	scraper_button.disabled = preparation_locked or not _scraper_can_act()
	sauce_brush_button.visible = false
	sauce_brush_button.disabled = true
	sauce_brush_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_sauce_button_states()
	fold_button.disabled = fold_model.package_result != FOLD_MODEL_SCRIPT.PACKAGE_NONE or fold_model.completed_fold_count() >= 2
	if fold_model.completed_fold_count() >= 2 and fold_model.package_result == FOLD_MODEL_SCRIPT.PACKAGE_NONE and p1_session.phase == P1Session.Phase.FOLD:
		p1_session.mark_ready_for_package()
		var package_result := Dictionary(fold_model.package_with(FOLD_MODEL_SCRIPT.PACKAGE_BAG))
		if bool(package_result.get("success", false)):
			tool_controller.clear_tool()
			tool_status_label.text = "折叠完成，已自动装入纸袋"
			p1_session.mark_packaged()
	fold_overlay.queue_redraw()


func _folding_locks_preparation() -> bool:
	return fold_model != null and (fold_model.completed_fold_count() > 0 or fold_model.package_result != FOLD_MODEL_SCRIPT.PACKAGE_NONE)


func _enter_sauce_and_fillings_for_sauce_action() -> Dictionary:
	if p1_session == null:
		return {"success": false, "reason": "煎饼制作状态尚未就绪"}
	if p1_session.phase in [P1Session.Phase.FIRST_SIDE, P1Session.Phase.SECOND_SIDE, P1Session.Phase.SAUCE_AND_FILLINGS]:
		# Sauce is available while either side is cooking; it never confirms or
		# interrupts the current fire-level stage.
		return {"success": true, "without_flip": not pancake_model.is_flipped, "already_active": true}
	return {"success": false, "reason": "摊饼完成后、开始折叠前才能加酱"}


func _scraper_can_act() -> bool:
	if p1_session == null or pancake_model == null:
		return true
	if p1_session.phase == P1Session.Phase.SPREAD:
		return not _spread_shape_locked
	return p1_session.phase in [P1Session.Phase.FIRST_SIDE, P1Session.Phase.SAUCE_AND_FILLINGS] and pancake_model.has_egg() and pancake_model.egg_is_on_visible_side()


func _is_active_cooking_phase() -> bool:
	return p1_session != null and p1_session.phase in [
		P1Session.Phase.SPREAD,
		P1Session.Phase.FIRST_SIDE,
		P1Session.Phase.SECOND_SIDE,
	]


func _confirm_spread_for_next_action() -> bool:
	if p1_session == null or p1_session.phase != P1Session.Phase.SPREAD:
		return true
	var result := p1_session.confirm_spread(pancake_model)
	if not bool(result.get("success", false)):
		tool_status_label.text = str(result.get("reason", "请先倒入面糊"))
		return false
	tool_controller.clear_tool()
	_refresh_p1_ui()
	return true


func _auto_pour_center() -> void:
	if five_area_pancake_production != null:
		var availability: Dictionary = five_area_pancake_production.call("can_produce")
		if not bool(availability.get("success", false)):
			tool_status_label.text = _pancake_availability_failure_text(availability)
			return
	var center := Vector2(pancake_model.grid_size - 1, pancake_model.grid_size - 1) * 0.5
	pancake_model.add_batter(center, parameters.automatic_pour_amount, parameters.automatic_pour_radius)
	pour_used = true
	_spread_shape_locked = false
	ladle_button.disabled = true
	tool_controller.select_tool(ToolController.Tool.SCRAPER)
	tool_status_label.text = "面糊已自动定量倒在鏊心；拿摊饼器绕鏊面转一圈即可"
	kitchen_audio.call("play_cue", &"pour")
	_refresh_p1_ui()


static func _pancake_availability_failure_text(result: Dictionary) -> String:
	match StringName(result.get("reason", &"unknown")):
		&"recipe_locked":
			return "煎饼基础配方未解锁，存档状态异常"
		&"no_game_session":
			return "存档服务尚未就绪，请返回开始页后重试"
		&"insufficient_stock":
			return "制作所需原料不足，请先补货"
		_:
			return "当前无法制作煎饼，请返回开始页后重试"


func _update_cooking_audio(delta: float) -> void:
	_audio_update_accumulator += delta
	if _audio_update_accumulator < 0.12:
		return
	_audio_update_accumulator = fmod(_audio_update_accumulator, 0.12)
	var cooking_phase := p1_session != null and p1_session.phase in [
		P1Session.Phase.SPREAD,
		P1Session.Phase.FIRST_SIDE,
		P1Session.Phase.SECOND_SIDE,
	]
	if not pour_used or not cooking_phase or p1_session.heat_level <= 0.02:
		kitchen_audio.call("set_sizzle", false, 0.0)
		return
	var summary := pancake_model.calculate_summary()
	var moisture := clampf(float(summary.mean_wetness), 0.0, 1.0)
	var heat := clampf(p1_session.heat_level, 0.0, 1.0)
	var intensity := clampf((0.24 + heat * 0.76) * lerpf(0.38, 1.0, moisture), 0.0, 1.0)
	kitchen_audio.call("set_sizzle", true, intensity)


func _update_surface_readout() -> void:
	var local_position := pancake_surface.pointer_local_position
	if not PancakeSpace.is_inside_pan(local_position, pancake_surface.size, parameters.pan_height_ratio):
		surface_readout_label.text = "把鼠标移入鏊面，可直接查看当前位置的面糊状态"
		return
	var cell := pan_local_to_grid(local_position)
	var covered := pancake_model.get_field_value(PancakeModel.FIELD_COVERAGE, cell)
	var cell_thickness := pancake_model.get_field_value(PancakeModel.FIELD_THICKNESS, cell)
	var cell_damage := pancake_model.get_field_value(PancakeModel.FIELD_DAMAGE, cell)
	var sauce := pancake_model.get_field_value(PancakeModel.FIELD_SAUCE_CONCENTRATION, cell)
	var chili_sauce := pancake_model.get_field_value(PancakeModel.FIELD_CHILI_SAUCE_CONCENTRATION, cell)
	var doneness := pancake_model.visible_doneness_at(pancake_model.index_of(cell))
	var description := "无面糊"
	if cell_damage >= parameters.hole_damage_threshold:
		description = "破洞"
	elif covered > 0.0:
		if cell_thickness < 0.12:
			description = "偏薄"
		elif cell_thickness < 0.45:
			description = "适中"
		elif cell_thickness < 0.9:
			description = "偏厚"
		else:
			description = "很厚"
	var pour_state := "面糊已倒完" if pour_used else "尚可倒面"
	surface_readout_label.text = "当前位置：%s（厚 %.2f · 火 %.2f · 秘制酱 %.2f） · %s" % [description, cell_thickness, doneness, sauce, pour_state]


func _refresh_sauce_load_display() -> void:
	var score_text := "--"
	if not _last_sauce_evaluation.is_empty():
		score_text = "%d" % roundi(float(_last_sauce_evaluation.score))
	var sweet_state: RefCounted = sauce_tool_states.get(OrderService.SAUCE_SWEET)
	var chili_state: RefCounted = sauce_tool_states.get(OrderService.SAUCE_CHILI)
	var sweet_ratio: float = sweet_state.load_ratio() if sweet_state != null else 0.0
	var chili_ratio: float = chili_state.load_ratio() if chili_state != null else 0.0
	sauce_blob_overlay.call("set_amounts", sweet_ratio, chili_ratio)
	sauce_status_label.text = "%s · 饼面待刷 %d%% · 酱料评分 %s" % [OrderService.sauce_display_name(current_sauce_type), roundi(sauce_tool_state.load_ratio() * 100.0), score_text]
	_refresh_sauce_selection_presentation()


func _refresh_sauce_button_states() -> void:
	if sauce_refill_button == null or chili_sauce_refill_button == null:
		return
	var preparation_locked := _folding_locks_preparation()
	var sauce_phase_locked := p1_session == null or p1_session.phase not in [
		P1Session.Phase.FIRST_SIDE,
		P1Session.Phase.SAUCE_AND_FILLINGS,
	]
	_set_sauce_button_state(sauce_refill_button, true, preparation_locked or sauce_phase_locked)
	_set_sauce_button_state(chili_sauce_refill_button, _chili_sauce_unlocked, preparation_locked or sauce_phase_locked)


func _set_sauce_button_state(button: Button, unlocked: bool, interaction_locked: bool) -> void:
	button.visible = unlocked
	button.disabled = not unlocked or interaction_locked
	button.mouse_filter = Control.MOUSE_FILTER_STOP if unlocked else Control.MOUSE_FILTER_IGNORE


func _update_sauce_status() -> void:
	_last_sauce_evaluation = PANCAKE_SCORER_SCRIPT.evaluate_sauce_type(pancake_model, current_sauce_type)
	_refresh_sauce_load_display()


func _update_damage_warning(peak_damage: float, new_holes: int) -> void:
	if new_holes > 0:
		warning_label.text = "已刮破：继续刮会扩大破洞"
		warning_label.modulate = Color(1.0, 0.35, 0.28)
		warning_tone.call("trigger", true)
	elif peak_damage >= 0.65:
		warning_label.text = "危险：该区域即将破洞"
		warning_label.modulate = Color(1.0, 0.72, 0.20)
		warning_tone.call("trigger", false)
	elif peak_damage >= 0.25:
		warning_label.text = "提示：薄区正在受损"
		warning_label.modulate = Color(1.0, 0.90, 0.52)
	else:
		warning_label.text = "当前无破洞风险"
		warning_label.modulate = Color(0.76, 0.92, 0.76)


func _select_sauce_type(sauce_type: StringName) -> void:
	if not sauce_tool_states.has(sauce_type):
		return
	current_sauce_type = sauce_type
	sauce_tool_state = sauce_tool_states[sauce_type]
	_sauce_stroke_id = pancake_model.begin_sauce_stroke()
	_update_sauce_status()


func _refresh_sauce_selection_presentation() -> void:
	if sauce_refill_button == null or pancake_surface == null:
		return
	var brushing := tool_controller != null and tool_controller.current_tool == ToolController.Tool.SAUCE_BRUSH
	sauce_refill_button.set_pressed_no_signal(brushing and current_sauce_type == OrderService.SAUCE_SWEET)
	var automatic_suffix := "；松开后自动刷匀并回到空手" if _automatic_brush_owned else "；松开后自动拿起对应酱刷"
	sauce_refill_button.tooltip_text = "按住控制秘制酱料用量%s" % automatic_suffix
	pancake_surface.cursor_is_sauce_brush = brushing
	pancake_surface.cursor_sauce_color = Color(0.34, 0.08, 0.035, 0.98)


func _on_heat_changed(value: float) -> void:
	if p1_session == null:
		return
	# Ignore programmatic or legacy slider changes: the current default is the
	# single supported griddle heat.
	p1_session.heat_level = 0.50
	heat_slider.set_value_no_signal(50.0)
	p1_session.changed.emit()


func _advance_p1_step() -> void:
	var action_result := {"success": false, "reason": "当前步骤尚未完成"}
	match p1_session.phase:
		P1Session.Phase.SPREAD:
			tool_status_label.text = "摊好后直接选择鸡蛋或下一项操作"
			return
		P1Session.Phase.FIRST_SIDE:
			action_result = p1_session.request_flip(pancake_model, ingredient_model)
			if bool(action_result.get("requires_folding", false)):
				tool_controller.clear_tool()
				tool_status_label.text = "小料已在饼面上，不再翻面；可继续刷酱、放料，完成后抓住饼皮边缘折叠"
				_refresh_p1_ui()
				return
			if bool(action_result.success):
				tool_controller.clear_tool()
				_stop_egg_crack_effect()
				tool_status_label.text = (
					"已提前翻面：本单火候分和订单评价会降低；可继续煎第二面或直接进行后续操作"
					if bool(action_result.get("early_flip", false))
					else "翻面完成：可继续煎第二面，火候仅影响最终评分"
				)
				kitchen_audio.call("play_cue", &"flip")
		P1Session.Phase.SECOND_SIDE:
			tool_status_label.text = "火候仅影响评分；可继续加酱、加料或直接折叠"
		P1Session.Phase.SAUCE_AND_FILLINGS:
			action_result = p1_session.begin_folding()
			if bool(action_result.success):
				_select_fold()
		P1Session.Phase.FOLD, P1Session.Phase.PACKAGE:
			tool_status_label.text = "先完成两侧折叠，完成后会自动装入纸袋"
		P1Session.Phase.READY_TO_SERVE:
			tool_status_label.text = "点击鏊子上的包装成品，把餐递给顾客"
			return
		P1Session.Phase.HANDOFF, P1Session.Phase.PAYMENT:
			tool_status_label.text = "顾客正在接餐并付款"
			return
		P1Session.Phase.RESULT:
			tool_status_label.text = "可查看本单小结，或继续接待下一位顾客"
			return
	if not bool(action_result.get("success", false)):
		tool_status_label.text = str(action_result.get("reason", "当前步骤尚未完成"))
	_refresh_p1_ui()


func _on_ingredient_gui_input(event: InputEvent, ingredient_type: StringName) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	_begin_ingredient_drag(ingredient_type, get_viewport().get_mouse_position())


func _connect_ingredient_slot(slot: Button, ingredient_type: StringName) -> void:
	if slot.has_signal("drag_requested"):
		slot.connect("drag_requested", _begin_ingredient_drag)
	else:
		slot.gui_input.connect(_on_ingredient_gui_input.bind(ingredient_type))


func _begin_ingredient_drag(ingredient_type: StringName, press_position: Vector2) -> void:
	if not _confirm_spread_for_next_action():
		return
	if not _ingredient_available_for_drag(ingredient_type):
		tool_status_label.text = "%s托盘已经空了，请原地长按当前小料盘补货" % IngredientModel.display_name(ingredient_type)
		return
	if p1_session.phase not in [P1Session.Phase.FIRST_SIDE, P1Session.Phase.SECOND_SIDE, P1Session.Phase.SAUCE_AND_FILLINGS]:
		tool_status_label.text = "当前步骤不能放配料"
		return
	_ingredient_drag_type = ingredient_type
	_ingredient_drag_start = press_position
	ingredient_drag_preview.texture = _ingredient_texture(ingredient_type)
	ingredient_drag_preview.visible = true
	ingredient_drag_preview.global_position = _ingredient_drag_start - ingredient_drag_preview.size * 0.5
	tool_status_label.text = "拖动%s到饼面后松开" % IngredientModel.display_name(ingredient_type)


func _input(event: InputEvent) -> void:
	if _ingredient_drag_type == &"":
		return
	if event is InputEventMouseMotion:
		ingredient_drag_preview.global_position = event.position - ingredient_drag_preview.size * 0.5
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_ingredient_drag(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_cancel_ingredient_drag()
		get_viewport().set_input_as_handled()


func _cancel_ingredient_drag() -> void:
	if _ingredient_drag_type.is_empty():
		return
	ingredient_drag_preview.visible = false
	ingredient_drag_preview.texture = null
	_ingredient_drag_type = &""
	tool_status_label.text = "已取消放置小料；库存未消耗"


func _finish_ingredient_drag(viewport_position: Vector2) -> void:
	ingredient_drag_preview.visible = false
	var spent_ingredient := _ingredient_drag_type
	if not _consume_dragged_ingredient(spent_ingredient):
		tool_status_label.text = "%s托盘已经空了，无法继续放置" % IngredientModel.display_name(spent_ingredient)
		_ingredient_drag_type = &""
		_refresh_p1_ui()
		return
	var local_position := pancake_surface.get_global_transform_with_canvas().affine_inverse() * viewport_position
	if not PancakeSpace.is_inside_pan(local_position, pancake_surface.size, parameters.pan_height_ratio):
		tool_status_label.text = "配料没有落在鏊面内，本次用料已损耗"
		_ingredient_drag_type = &""
		return
	var grid_position := PancakeSpace.local_to_grid_position(local_position, pancake_surface.size, pancake_model.grid_size)
	var resolved_local_position := local_position
	var resolved_grid_position := grid_position
	if _ingredient_drag_type == IngredientModel.EGG:
		resolved_local_position = pancake_surface.size * 0.5
		resolved_grid_position = Vector2.ONE * float(pancake_model.grid_size - 1) * 0.5
	var rotation := (viewport_position - _ingredient_drag_start).angle()
	var result := {"success": false, "reason": "配料未能放置"}
	if _ingredient_drag_type == IngredientModel.EGG:
		var egg_validation := pancake_model.can_crack_egg(resolved_grid_position)
		if bool(egg_validation.success):
			result = ingredient_model.place(_ingredient_drag_type, resolved_grid_position, rotation, pancake_model)
			if bool(result.success):
				var crack_result := pancake_model.crack_egg(resolved_grid_position)
				if not bool(crack_result.success):
					result = crack_result
		else:
			result = egg_validation
	else:
		result = ingredient_model.place(_ingredient_drag_type, grid_position, rotation, pancake_model)
	if bool(result.success):
		if _ingredient_drag_type == IngredientModel.EGG:
			_play_egg_crack_effect(resolved_local_position)
			tool_controller.select_tool(ToolController.Tool.SCRAPER)
			tool_status_label.text = "鸡蛋已打入；用 T 形摊面器连续画圈摊开蛋黄和蛋白"
		else:
			tool_status_label.text = "%s已放到饼面，可继续调整下一种配料" % IngredientModel.display_name(_ingredient_drag_type)
	else:
		tool_status_label.text = "%s；本次用料已损耗" % str(result.reason)
	_ingredient_drag_type = &""
	_refresh_p1_ui()


func _ingredient_texture(ingredient_type: StringName) -> Texture2D:
	return ingredient_layer.texture_for(ingredient_type)


func _ingredient_available_for_drag(ingredient_type: StringName) -> bool:
	if ingredient_type == IngredientModel.YOUTIAO:
		var session := get_node_or_null("/root/GameSession")
		if session == null or not session.has_method("prepared_product_slot_status"):
			return false
		return int(Dictionary(session.call("prepared_product_slot_status", &"slot.04")).get("count", 0)) > 0
	return ingredient_stock_model.has_stock(ingredient_type)


func _consume_dragged_ingredient(ingredient_type: StringName) -> bool:
	if ingredient_type == IngredientModel.YOUTIAO:
		var session := get_node_or_null("/root/GameSession")
		if session == null or not session.has_method("take_prepared_product"):
			return false
		return bool(Dictionary(session.call("take_prepared_product", &"slot.04")).get("success", false))
	return ingredient_stock_model.consume(ingredient_type)


func _saved_ingredient_stock() -> Dictionary:
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("pancake_legacy_inventory_snapshot"):
		return Dictionary(session.call("pancake_legacy_inventory_snapshot"))
	if session != null and session.has_method("ingredient_stock_snapshot"):
		return Dictionary(session.call("ingredient_stock_snapshot"))
	return {}


func _persist_ingredient_stock() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("save_pancake_legacy_inventory"):
		session.call("save_pancake_legacy_inventory", ingredient_stock_model.snapshot())
		return
	if session != null and session.has_method("save_ingredient_stock"):
		session.call("save_ingredient_stock", ingredient_stock_model.snapshot())


func _on_ingredient_stock_changed(_ingredient_type: StringName, _current_stock: int) -> void:
	_refresh_ingredient_stock_ui()
	_persist_ingredient_stock()
	_refresh_p1_ui()


func _restock_ingredient(ingredient_type: StringName) -> void:
	if not ingredient_stock_model.refill(ingredient_type):
		tool_status_label.text = "%s托盘现在是满的" % IngredientModel.display_name(ingredient_type)
		return
	tool_status_label.text = "%s已从备料容器补满" % IngredientModel.display_name(ingredient_type)


func _refresh_ingredient_stock_ui() -> void:
	var slots := {
		IngredientModel.EGG: egg_button,
		IngredientModel.BAOCUI: baocui_button,
		IngredientModel.HAM_SAUSAGE: ham_button,
		IngredientModel.SCALLION: scallion_button,
		IngredientModel.MEAT_FLOSS: meat_floss_button,
		IngredientModel.PORK_TENDERLOIN: pork_tenderloin_button,
		IngredientModel.CORIANDER: coriander_button,
		IngredientModel.PRESERVED_MUSTARD: preserved_mustard_button,
	}
	var restock_buttons := {
		IngredientModel.EGG: egg_restock_button,
		IngredientModel.BAOCUI: baocui_restock_button,
		IngredientModel.HAM_SAUSAGE: ham_restock_button,
		IngredientModel.SCALLION: scallion_restock_button,
	}
	for ingredient_type in IngredientModel.TYPES:
		if not slots.has(ingredient_type):
			continue
		var current_stock: int = ingredient_stock_model.current(ingredient_type)
		(slots[ingredient_type] as Button).call("set_stock_quantity", current_stock)
		if not restock_buttons.has(ingredient_type):
			continue
		var restock_button := restock_buttons[ingredient_type] as Button
		var legacy_rack_visible := (restock_button.get_parent() as CanvasItem).visible
		restock_button.disabled = not legacy_rack_visible or current_stock >= ingredient_stock_model.capacity(ingredient_type)
		restock_button.mouse_filter = Control.MOUSE_FILTER_STOP if legacy_rack_visible else Control.MOUSE_FILTER_IGNORE
		restock_button.tooltip_text = "托盘已满" if legacy_rack_visible and restock_button.disabled else ""


func _serve_order() -> void:
	if p1_session.phase != P1Session.Phase.READY_TO_SERVE:
		tool_status_label.text = "完成折叠和包装后，再选择订单商品图标交付"
		return
	tool_status_label.text = "成品已准备好；点击订单商品图标交付"


func _deliver_direct_pancake_to_order(target_order: Dictionary, item_index: int) -> void:
	if p1_session.phase != P1Session.Phase.READY_TO_SERVE:
		_pending_delivery_item_index = -1
		return
	var game_session := get_node_or_null("/root/GameSession")
	var order_id := StringName(target_order.get("order_id", &""))
	if game_session == null or order_id.is_empty():
		return
	var items: Array = Array(target_order.get("items", []))
	if item_index < 0 or item_index >= items.size():
		tool_status_label.text = "该订单商品槽为空"
		return
	var serving: Dictionary = game_session.call("begin_formal_order_serving", order_id)
	if not bool(serving.get("success", false)):
		tool_status_label.text = "该顾客当前无法接餐"
		return
	if game_session.has_method("mark_formal_order_production_started"):
		game_session.call("mark_formal_order_production_started", order_id, &"device.pancake_griddle")
	_formal_order_id = order_id
	var legacy := Dictionary(Dictionary(target_order.get("metadata", {})).get("legacy_order", {}))
	if not legacy.is_empty():
		p1_session.order = legacy.duplicate(true)
	p1_session.mirror_formal_patience(
		float(target_order.get("remaining_patience_seconds", target_order.get("patience_seconds", 0.0))),
		bool(target_order.get("tutorial_no_countdown", false))
	)
	var score_result := PANCAKE_SCORER_SCRIPT.evaluate_order(
		pancake_model,
		ingredient_model,
		fold_model,
		p1_session.order,
		p1_session.elapsed_seconds,
		p1_session.patience_ratio()
	)
	var preview_product: Dictionary = five_area_pancake_production.call(
		"create_product_snapshot",
		score_result,
		p1_session.order,
		{"package_result": fold_model.package_result},
	)
	var order_preview: Dictionary = game_session.call("preview_attach_formal_order_product", order_id, item_index, preview_product)
	if not bool(order_preview.get("success", false)):
		game_session.call("cancel_formal_order_serving", order_id)
		tool_status_label.text = "当前订单商品槽不能接收成品：%s" % str(order_preview.get("reason", "unknown"))
		return
	var inventory_rollback: Dictionary = game_session.call("inventory_snapshot")
	var production_result: Dictionary = five_area_pancake_production.call(
		"settle_completed_pancake",
		score_result,
		p1_session.order,
		{"package_result": fold_model.package_result},
	)
	if not bool(production_result.get("success", false)):
		game_session.call("cancel_formal_order_serving", order_id)
		tool_status_label.text = "煎饼库存结算失败：%s" % str(production_result.get("reason", "unknown"))
		return
	var product := Dictionary(production_result.get("product", {})).duplicate(true)
	var attached: Dictionary = game_session.call("attach_formal_order_product", order_id, item_index, product)
	if not bool(attached.get("success", false)):
		game_session.call("save_inventory", inventory_rollback)
		game_session.call("cancel_formal_order_serving", order_id)
		tool_status_label.text = "正式订单接收成品失败：%s" % str(attached.get("reason", "unknown"))
		return
	_pending_delivery_item_index = -1
	var refreshed_order: Dictionary = game_session.call("formal_order", order_id)
	if not _formal_order_items_complete(refreshed_order):
		game_session.call("cancel_formal_order_serving", order_id)
		reset_pancake()
		p1_session.mirror_formal_patience(
			float(refreshed_order.get("remaining_patience_seconds", refreshed_order.get("patience_seconds", 0.0))),
			bool(refreshed_order.get("tutorial_no_countdown", false)),
		)
		tool_status_label.text = "已交付第 %d 项；请继续制作，再点击剩余商品图标。" % (item_index + 1)
		_refresh_customer_queue()
		_refresh_p1_ui()
		return
	var settled_formal: Dictionary = game_session.call("settle_formal_order", order_id)
	if not bool(settled_formal.get("success", false)):
		tool_status_label.text = "正式订单结算失败：%s" % str(settled_formal.get("reason", "unknown"))
		return
	var handoff_result := p1_session.begin_handoff(score_result)
	if not bool(handoff_result.get("success", false)):
		tool_status_label.text = str(handoff_result.get("reason", "当前不能递餐"))
		return
	# The direct product is already consumed, attached, and formally settled.
	# Reuse this marker so the payment callback does not create or attach it twice.
	_handoff_product_from_tray = product
	_begin_pancake_handoff_visual(score_result)


func _serve_order_legacy() -> void:
	if p1_session.phase != P1Session.Phase.READY_TO_SERVE:
		tool_status_label.text = "完成折叠和包装后，点击鏊子上的成品出餐"
		return
	var score_result := PANCAKE_SCORER_SCRIPT.evaluate_order(
		pancake_model,
		ingredient_model,
		fold_model,
		p1_session.order,
		p1_session.elapsed_seconds,
		p1_session.patience_ratio()
	)
	var handoff_result := p1_session.begin_handoff(score_result)
	if not bool(handoff_result.get("success", false)):
		tool_status_label.text = str(handoff_result.get("reason", "当前不能递餐"))
		return
	_begin_pancake_handoff_visual(score_result)


func _begin_pancake_handoff_visual(score_result: Dictionary, package_result: StringName = &"") -> void:
	_populate_result(score_result)
	serve_product_button.visible = false
	store_pancake_button.visible = false
	handoff_product_sprite.texture = fold_overlay.current_package_texture() if package_result.is_empty() else fold_overlay.package_texture_for(package_result)
	handoff_product_sprite.position = Vector2(810.0, 590.0)
	handoff_product_sprite.size = Vector2(300.0, 300.0)
	handoff_product_sprite.modulate = Color.WHITE
	handoff_product_sprite.visible = true
	fold_overlay.visible = false
	pancake_visual.visible = false
	ingredient_layer.visible = false
	sauce_blob_overlay.visible = false
	_stop_egg_crack_effect()
	tool_status_label.text = "正在把餐递给顾客"
	if _handoff_tween != null and _handoff_tween.is_valid():
		_handoff_tween.kill()
	_handoff_tween = create_tween()
	_handoff_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_handoff_tween.parallel().tween_property(handoff_product_sprite, "position", Vector2(885.0, 255.0), 0.48)
	_handoff_tween.parallel().tween_property(handoff_product_sprite, "size", Vector2(150.0, 150.0), 0.48)
	_handoff_tween.parallel().tween_property(handoff_product_sprite, "modulate:a", 0.25, 0.48)
	_handoff_tween.tween_callback(_finish_handoff_visual)
	kitchen_audio.call("set_sizzle", false, 0.0)
	kitchen_audio.call("play_cue", &"serve")
	_refresh_p1_ui()


func _store_current_pancake() -> void:
	if p1_session.phase != P1Session.Phase.READY_TO_SERVE or five_area_pancake_production == null:
		return
	var score_result := PANCAKE_SCORER_SCRIPT.evaluate_order(pancake_model, ingredient_model, fold_model, p1_session.order, p1_session.elapsed_seconds, p1_session.patience_ratio())
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null:
		return
	var product_result: Dictionary = five_area_pancake_production.call("settle_completed_pancake", score_result, p1_session.order, {"package_result": fold_model.package_result})
	if not bool(product_result.get("success", false)):
		tool_status_label.text = "无法存入暂存托盘：%s" % str(product_result.get("reason", "unknown"))
		return
	var stored: Dictionary = game_session.call("store_pancake_product", product_result.get("product", {}))
	if not bool(stored.get("success", false)):
		tool_status_label.text = "无法存入暂存托盘：%s" % str(stored.get("reason", "unknown"))
		return
	tool_status_label.text = "煎饼已存入成品暂存托盘；需要交付时直接点击订单商品图标。"
	p1_session.start(p1_session.order)
	reset_pancake()
	_refresh_pancake_holding_tray()


func _serve_pancake_from_holding_tray(slot_index: int) -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null:
		return
	var tray_slots: Array = Array(Dictionary(game_session.call("pancake_holding_tray_snapshot")).get("slots", []))
	if slot_index < 0 or slot_index >= tray_slots.size() or Dictionary(tray_slots[slot_index]).is_empty():
		tool_status_label.text = "暂存格为空；请先完成并暂存煎饼"
		return
	tool_status_label.text = "暂存格仅用于查看成品与新鲜度；交付请直接点击订单商品图标"


func _deliver_tray_pancake_to_order(slot_index: int, target_order: Dictionary, item_index: int) -> void:
	_formal_order_id = StringName(target_order.get("order_id", &""))
	var legacy := Dictionary(Dictionary(target_order.get("metadata", {})).get("legacy_order", {}))
	if not legacy.is_empty():
		p1_session.order = legacy.duplicate(true)
	p1_session.mirror_formal_patience(
		float(target_order.get("remaining_patience_seconds", target_order.get("patience_seconds", 0.0))),
		bool(target_order.get("tutorial_no_countdown", false))
	)
	_pending_delivery_item_index = item_index
	_serve_pancake_from_holding_tray_legacy(slot_index, item_index)


func _serve_pancake_from_holding_tray_legacy(slot_index: int, selected_item_index: int = -1) -> void:
	if five_area_pancake_production == null or p1_session == null:
		tool_status_label.text = "暂存托盘暂不可用：请先进入一局煎饼制作。"
		return
	if slot_index < 0 or slot_index >= pancake_holding_slots.size():
		tool_status_label.text = "暂存格不存在。"
		return
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null:
		tool_status_label.text = "暂存托盘暂不可用：游戏存档尚未就绪。"
		return
	var tray_slots: Array = Array(Dictionary(game_session.call("pancake_holding_tray_snapshot")).get("slots", []))
	if slot_index >= tray_slots.size() or Dictionary(tray_slots[slot_index]).is_empty():
		tool_status_label.text = "暂存格为空：完成并包装煎饼后，点击“暂存成品”放入这里。"
		return
	if p1_session.phase in [P1Session.Phase.HANDOFF, P1Session.Phase.PAYMENT, P1Session.Phase.RESULT]:
		tool_status_label.text = "当前顾客正在递餐或付款，暂时不能重复交付。"
		return
	var formal_order: Dictionary = game_session.call("formal_order", _formal_order_id) if game_session.has_method("formal_order") else {}
	if formal_order.is_empty() or _formal_order_id.is_empty():
		tool_status_label.text = "当前订单未进入正式订单服务。"
		return
	var items: Array = Array(formal_order.get("items", []))
	if items.is_empty():
		tool_status_label.text = "正式订单没有可交付条目。"
		return
	var tray_product := Dictionary(tray_slots[slot_index]).duplicate(true)
	var item_index := selected_item_index
	if item_index < 0:
		item_index = int(game_session.call("formal_order_delivery_item_index", _formal_order_id, tray_product)) if game_session.has_method("formal_order_delivery_item_index") else 0
	if item_index < 0 or item_index >= items.size():
		tool_status_label.text = "目标顾客没有尚未完成的品项"
		return
	var serving: Dictionary = game_session.call("begin_formal_order_serving", _formal_order_id)
	if not bool(serving.get("success", false)):
		tool_status_label.text = "该顾客当前无法接餐"
		return
	if game_session.has_method("mark_formal_order_production_started"):
		game_session.call("mark_formal_order_production_started", _formal_order_id, &"pancake_holding_tray")
	var formal_item: Dictionary = Dictionary(items[item_index])
	var tray_preview: Dictionary = game_session.call("preview_pancake_tray_delivery", slot_index, formal_item)
	if not bool(tray_preview.get("success", false)):
		game_session.call("cancel_formal_order_serving", _formal_order_id)
		tool_status_label.text = _pancake_tray_failure_text(tray_preview)
		_refresh_pancake_holding_tray()
		return
	var order_service_ref: RefCounted = game_session.call("order_service")
	var order_preview: Dictionary = order_service_ref.call("preview_attach_product", _formal_order_id, item_index, tray_preview.get("product", {}))
	if not bool(order_preview.get("success", false)):
		game_session.call("cancel_formal_order_serving", _formal_order_id)
		tool_status_label.text = "当前订单暂时不能接收成品：%s" % str(order_preview.get("reason", "unknown"))
		return
	var delivered: Dictionary = game_session.call("serve_pancake_tray_delivery", slot_index, formal_item)
	if not bool(delivered.get("success", false)):
		game_session.call("cancel_formal_order_serving", _formal_order_id)
		tool_status_label.text = _pancake_tray_failure_text(delivered)
		_refresh_pancake_holding_tray()
		return
	var attached: Dictionary = game_session.call("attach_formal_order_product", _formal_order_id, item_index, delivered.get("served_product", {}))
	if not bool(attached.get("success", false)):
		game_session.call("cancel_formal_order_serving", _formal_order_id)
		tool_status_label.text = "正式订单接收成品失败：%s" % str(attached.get("reason", "unknown"))
		return
	_pending_delivery_item_index = -1
	var refreshed_order: Dictionary = game_session.call("formal_order", _formal_order_id)
	if not _formal_order_items_complete(refreshed_order):
		game_session.call("cancel_formal_order_serving", _formal_order_id)
		tool_status_label.text = "已交付 1 项，继续制作剩余品项；该顾客耐心已恢复倒计时。"
		_refresh_pancake_holding_tray()
		_refresh_customer_queue()
		return
	var settled_formal: Dictionary = game_session.call("settle_formal_order", _formal_order_id)
	if not bool(settled_formal.get("success", false)):
		tool_status_label.text = "正式订单结算失败：%s" % str(settled_formal.get("reason", "unknown"))
		return
	var served_product: Dictionary = Dictionary(delivered.get("served_product", {})).duplicate(true)
	var result: Dictionary = PANCAKE_SCORER_SCRIPT.evaluate_stored_product(
		served_product,
		p1_session.order,
		p1_session.elapsed_seconds,
		p1_session.patience_ratio(),
	)
	if result.is_empty():
		result = {
			"score": float(delivered.get("final_score", 0.0)),
			"dimensions": Dictionary(served_product.get("dimension_scores", {})).duplicate(true),
			"tags": PackedStringArray(),
			"feedback": "旧版暂存成品按订单差异兼容计分",
		}
	else:
		var freshness_penalty := float(delivered.get("freshness_penalty", 0.0))
		result["score"] = maxf(float(result.get("score", 0.0)) - freshness_penalty, 0.0)
		result["freshness_penalty"] = freshness_penalty
		if freshness_penalty > 0.0:
			var tags := PackedStringArray(result.get("tags", PackedStringArray()))
			tags.append("暂存新鲜度 -%d" % roundi(freshness_penalty))
			result["tags"] = tags
			result["feedback"] = "%s 暂存时间使最终评分降低 %d 分。" % [str(result.get("feedback", "")), roundi(freshness_penalty)]
	result["grade"] = PANCAKE_HOLDING_TRAY_MODEL.grade_for_score(float(result.get("score", 0.0)))
	result["area_id"] = &"area.pancake"
	result["product_id"] = &"product.pancake.custom"
	result["mismatch_reasons"] = Array(delivered.get("mismatch_reasons", [])).duplicate()
	var handoff := p1_session.begin_handoff_from_tray(result)
	if not bool(handoff.get("success", false)):
		tool_status_label.text = str(handoff.get("reason", "无法交付"))
		return
	_handoff_product_from_tray = served_product
	_resume_production_after_tray_handoff = true
	_refresh_pancake_holding_tray()
	var stored_fold: Dictionary = Dictionary(served_product.get("fold_snapshot", {}))
	_begin_pancake_handoff_visual(result, StringName(stored_fold.get("package_result", &"")))


func _formal_order_items_complete(order: Dictionary) -> bool:
	var items: Array = Array(order.get("items", []))
	if items.is_empty():
		return false
	for item_value in items:
		var item := Dictionary(item_value)
		if Array(item.get("prepared_product_instance_ids", [])).size() < int(item.get("quantity", 1)):
			return false
	return true


func _on_pancake_holding_tray_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tool_status_label.text = "成品暂存用法：煎饼完成包装后点“暂存成品”；有顾客订单时可随时交付，配方、火候和存放时间会影响评分。"


func _pancake_tray_failure_text(result: Dictionary) -> String:
	match StringName(result.get("reason", &"")):
		&"empty_slot":
			return "暂存格为空：完成并包装煎饼后，点击“暂存成品”放入这里。"
	return "暂存煎饼不能交付：%s" % str(result.get("reason", "未知原因"))


func _pancake_tray_mismatch_text(reasons: Array) -> String:
	var labels := PackedStringArray()
	for reason_variant in reasons:
		match str(reason_variant):
			"product_id": labels.append("品类不同")
			"heat_preference": labels.append("火候要求不同")
			"ingredient_ids": labels.append("小料不同")
			"sauce_ids": labels.append("酱料不同")
			_: labels.append(str(reason_variant))
	return "、".join(labels) if not labels.is_empty() else "配方不同"


func _refresh_pancake_holding_tray() -> void:
	var session := get_node_or_null("/root/GameSession")
	var unlocked := false
	if session != null and session.has_method("progression_service"):
		unlocked = bool(session.call("progression_service").call("owns_growth", &"growth.capacity.pancake_holding_tray.two_slots"))
	pancake_holding_tray.visible = unlocked
	if not unlocked or session == null or not session.has_method("pancake_holding_tray_snapshot"):
		return
	var slots: Array = Array(Dictionary(session.call("pancake_holding_tray_snapshot")).get("slots", []))
	for index in pancake_holding_slots.size():
		var slot := Dictionary(slots[index]) if index < slots.size() else {}
		var button := pancake_holding_slots[index]
		button.text = "暂存格 %d\n%s" % [index + 1, "空" if slot.is_empty() else "%s · %s" % [str(slot.get("state", "fresh")), str(slot.get("product_id", "煎饼"))]]
		button.disabled = true
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.tooltip_text = "空：完成并包装煎饼后，点击“暂存成品”放入这里。" if slot.is_empty() else "暂存成品与新鲜度展示；交付时点击订单商品图标。"


func _finish_handoff_visual() -> void:
	handoff_product_sprite.visible = false


func _formal_pancake_order_is_settled() -> bool:
	if _formal_order_id.is_empty():
		return false
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("formal_order_snapshot"):
		return false
	var formal_snapshot: Dictionary = game_session.call("formal_order_snapshot")
	var saved_order: Dictionary = Dictionary(Dictionary(formal_snapshot.get("orders", {})).get(str(_formal_order_id), {}))
	return StringName(saved_order.get("state", &"")) == &"settled"


func _populate_result(score_result: Dictionary) -> void:
	result_title_label.text = "顾客评价 · %d分" % roundi(float(score_result.get("score", 0.0)))
	var dimensions: Dictionary = Dictionary(score_result.get("dimensions", {}))
	result_detail_label.text = str(score_result.get("feedback", "本单已完成"))
	integrity_score_label.text = "完整度  %d" % roundi(float(dimensions.get("integrity", 0.0)))
	thickness_score_label.text = "厚薄  %d" % roundi(float(dimensions.get("thickness", 0.0)))
	heat_score_label.text = "火候  %d" % roundi(float(dimensions.get("heat", 0.0)))
	egg_score_label.text = "摊蛋  %d" % roundi(float(dimensions.get("egg", 0.0)))
	sauce_score_label.text = "酱料  %d" % roundi(float(dimensions.get("sauce", 0.0)))
	ingredient_score_label.text = "配料  %d" % roundi(float(dimensions.get("ingredients", 0.0)))
	fold_score_label.text = "折叠  %d" % roundi(float(dimensions.get("fold", 0.0)))
	order_score_label.text = "订单  %d" % roundi(float(dimensions.get("order", 0.0)))
	time_score_label.text = "时间  %d" % roundi(float(dimensions.get("time", 0.0)))
	var result_tags: String = " · ".join(PackedStringArray(Array(score_result.get("tags", [])).map(func(tag): return str(tag))))
	result_tags_label.text = "亮点与问题：%s" % (result_tags if not result_tags.is_empty() else "暂无")


func _start_next_order() -> void:
	if _uses_playable_formal_orders():
		var preserve_formal_production := _resume_production_after_tray_handoff and p1_session.has_suspended_tray_production()
		if preserve_formal_production:
			var game_session := get_node_or_null("/root/GameSession")
			var ensured: Dictionary = game_session.call("ensure_active_playable_order") if game_session != null else {}
			var active := Dictionary(ensured.get("order", {}))
			var items: Array = Array(active.get("items", []))
			var legacy := Dictionary(Dictionary(active.get("metadata", {})).get("legacy_order", {}))
			if not items.is_empty() and StringName(Dictionary(items[0]).get("area_id", &"")) == &"area.pancake" and not legacy.is_empty():
				var resumed: Dictionary = p1_session.resume_production_for_next_order(legacy)
				if bool(resumed.get("success", false)):
					_formal_order_id = StringName(active.get("order_id", &""))
					customer_queue.call("restore_active_customer", legacy)
					_resume_production_after_tray_handoff = false
					_restore_in_progress_after_tray_handoff()
					_refresh_main_order_controls(active)
					_refresh_p1_ui()
					return
		_resume_production_after_tray_handoff = false
		_route_active_playable_order(true)
		return
	var preserve_production := _resume_production_after_tray_handoff and p1_session.has_suspended_tray_production()
	var next_customer: Dictionary = customer_queue.advance_queue()
	if preserve_production:
		var resumed: Dictionary = p1_session.resume_production_for_next_order(next_customer.order)
		if bool(resumed.get("success", false)):
			_restore_in_progress_after_tray_handoff()
		else:
			reset_pancake()
			p1_session.start(next_customer.order)
	else:
		reset_pancake()
		p1_session.start(next_customer.order)
	_resume_production_after_tray_handoff = false
	_ensure_formal_pancake_order(next_customer.order)
	_refresh_p1_ui()


func _restore_in_progress_after_tray_handoff() -> void:
	pancake_visual.visible = true
	ingredient_layer.visible = true
	sauce_blob_overlay.visible = true
	fold_overlay.visible = true
	handoff_product_sprite.visible = false
	result_panel.visible = false
	order_summary_card.visible = false
	if result_detail_input_shield != null:
		result_detail_input_shield.visible = false
	payment_sprite.visible = false
	pancake_surface.pointer_pressed = false
	pancake_surface.spreader_motion_valid = false
	ingredient_drag_preview.visible = false
	_ingredient_drag_type = &""
	_stop_egg_crack_effect(false)
	egg_crack_artwork.visible = pancake_model.egg_state == PancakeModel.EggState.CRACKED and pancake_model.egg_is_on_visible_side()


func _legacy_order_from_active_formal_order(fallback: Dictionary) -> Dictionary:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("active_formal_order"):
		return fallback
	var active: Dictionary = game_session.call("active_formal_order")
	if active.is_empty():
		return fallback
	var legacy: Dictionary = Dictionary(Dictionary(active.get("metadata", {})).get("legacy_order", {}))
	if legacy.is_empty():
		return fallback
	_formal_order_id = StringName(active.get("order_id", &""))
	return legacy


func _ensure_formal_pancake_order(legacy_order: Dictionary) -> void:
	if five_area_pancake_production == null:
		return
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("active_formal_order"):
		return
	var active: Dictionary = game_session.call("active_formal_order")
	if not active.is_empty():
		_formal_order_id = StringName(active.get("order_id", &""))
		return
	var opened: Dictionary = game_session.call("open_pancake_order", legacy_order)
	if bool(opened.get("success", false)):
		_formal_order_id = StringName(Dictionary(opened.get("order", {})).get("order_id", &""))
	else:
		tool_status_label.text = "正式订单创建失败：%s" % str(opened.get("reason", "unknown"))


func _settle_formal_pancake_product(product: Dictionary) -> bool:
	if _formal_order_id.is_empty():
		return true
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null:
		return true
	# A prior completion can have persisted the formal order just before the
	# scene callback is retried.  In that case, do not try to attach the same
	# pancake again; the order is already safely settled and gameplay can move on.
	if _formal_pancake_order_is_settled():
		return true
	var item_index := _pending_delivery_item_index
	if item_index < 0:
		item_index = int(game_session.call("formal_order_delivery_item_index", _formal_order_id, product)) if game_session.has_method("formal_order_delivery_item_index") else 0
	if item_index < 0:
		tool_status_label.text = "目标顾客没有尚未完成的品项"
		return false
	var attached: Dictionary = game_session.call("attach_formal_order_product", _formal_order_id, item_index, product)
	if not bool(attached.get("success", false)):
		# An interrupted callback can leave the product attached while the final
		# settlement has not yet run.  Let the idempotent settlement below finish it.
		if StringName(attached.get("reason", &"")) != &"capacity_full":
			tool_status_label.text = "正式订单接收成品失败：%s" % str(attached.get("reason", "unknown"))
			return false
	var settled: Dictionary = game_session.call("settle_formal_order", _formal_order_id)
	if not bool(settled.get("success", false)):
		tool_status_label.text = "正式订单结算失败：%s" % str(settled.get("reason", "unknown"))
		return false
	_pending_delivery_item_index = -1
	return true


func _open_result_detail() -> void:
	if not _order_summary_visible:
		return
	_result_detail_open = true
	_refresh_p1_ui()


func _close_result_detail() -> void:
	_result_detail_open = false
	_refresh_p1_ui()


func _dismiss_order_summary() -> void:
	_order_summary_visible = false
	_result_detail_open = false
	_refresh_p1_ui()


func end_business_day(cutoff: Dictionary = {}) -> void:
	if daily_bill_panel.visible:
		return
	_business_day_closed = true
	business_day_closed_shield.visible = true
	var game_session := get_node_or_null("/root/GameSession")
	var bill := {"day": 1, "orders": [], "order_count": 0, "total_coins": 0, "average_score": 0.0}
	if game_session != null:
		bill = game_session.call("end_business_day", cutoff)
	_populate_daily_bill(bill)
	result_panel.visible = false
	order_summary_card.visible = false
	if result_detail_input_shield != null:
		result_detail_input_shield.visible = false
	# GUI input follows scene-tree order rather than CanvasItem z_index. Derived
	# workstation controls are appended after this inherited panel, so keep the
	# outside shield and then the modal panel as the final SafeArea siblings.
	business_day_closed_shield.move_to_front()
	daily_bill_panel.move_to_front()
	daily_bill_panel.visible = true


func _populate_daily_bill(bill: Dictionary) -> void:
	daily_bill_title_label.text = "第%d日 · 今日账单" % int(bill.get("day", 1))
	var cutoff: Dictionary = Dictionary(bill.get("cutoff", {}))
	var cutoff_summary := ""
	if StringName(cutoff.get("reason", &"")) == &"timer_expired":
		cutoff_summary = " · 打烊超时 %d 位" % maxi(int(cutoff.get("unserved_customer_count", 0)), 0)
	elif StringName(cutoff.get("reason", &"")) == &"test_early_end":
		cutoff_summary = " · 测试提前结束，未服务 %d 位" % maxi(int(cutoff.get("unserved_customer_count", 0)), 0)
	elif StringName(cutoff.get("reason", &"")) == &"manual_early_end":
		cutoff_summary = " · 提前打烊，未服务 %d 位" % maxi(int(cutoff.get("unserved_customer_count", 0)), 0)
	daily_bill_stats_label.text = "完成 %d 单 · 收入 %d 金币 · 成本 %d 金币（含报废 %d） · 毛利 %d 金币 · 平均 %d分 · 口碑 %+d%s" % [
		int(bill.get("order_count", 0)),
		int(bill.get("total_coins", 0)),
		int(bill.get("total_cost", 0)),
		int(bill.get("waste_cost", 0)),
		int(bill.get("total_profit", 0)),
		roundi(float(bill.get("average_score", 0.0))),
		int(bill.get("reputation_delta", 0)),
		cutoff_summary,
	]
	for child in daily_bill_rows.get_children():
		child.queue_free()
	var entries: Array = bill.get("orders", [])
	if entries.is_empty():
		_add_bill_row("—", "今天还没有完成订单", "—", "0金币")
	else:
		for index in entries.size():
			var entry: Dictionary = entries[index]
			_add_bill_row(
				str(index + 1),
				str(entry.get("title", "未命名订单")),
				"%d分" % int(entry.get("score", 0)),
				"+%d / 成本 %d / 毛利 %d" % [
					int(entry.get("coins", 0)),
					int(entry.get("cost", 0)),
					int(entry.get("profit", int(entry.get("coins", 0)) - int(entry.get("cost", 0)))),
				]
			)
	_refresh_growth_section()


func _add_bill_row(index_text: String, title_text: String, score_text: String, income_text: String) -> void:
	var values := [index_text, title_text, score_text, income_text]
	var widths := [100.0, 480.0, 140.0, 170.0]
	for column in values.size():
		var label := Label.new()
		label.custom_minimum_size = Vector2(widths[column], 46.0)
		label.text = values[column]
		label.add_theme_font_size_override("font_size", 19)
		label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.79))
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if column == 1 else (HORIZONTAL_ALIGNMENT_RIGHT if column == 3 else HORIZONTAL_ALIGNMENT_CENTER)
		daily_bill_rows.add_child(label)


func _close_daily_bill() -> void:
	unlock_progress_panel.visible = false
	daily_bill_panel.visible = false
	daily_bill_closed.emit()


func _refresh_growth_section(message: String = "") -> void:
	var game_session := get_node_or_null("/root/GameSession")
	_growth_recommendations.clear()
	if game_session == null or not game_session.has_method("growth_recommendations"):
		growth_balance_label.text = "成长服务暂不可用，可以返回开始页；今日进度仍会保留。"
		for button in growth_ticket_buttons:
			button.visible = false
		begin_next_day_button.disabled = true
		return
	var snapshot: Dictionary = game_session.call("five_area_progression_snapshot")
	var pending_growth_ids: Array = Array(snapshot.get("pending_growth_ids", []))
	var balance_text := "现有 %d 金币 · 口碑 %d · 全部 21 项升级均可在工坊查看；本夜可预订多个，次日统一生效" % [
		int(snapshot.get("coins", 0)),
		int(snapshot.get("reputation", 0)),
	]
	growth_balance_label.text = balance_text if message.is_empty() else "%s · %s" % [balance_text, message]
	for button in growth_ticket_buttons:
		button.visible = false
	begin_next_day_button.disabled = false
	begin_next_day_button.text = "确认预订并开始下一天" if not pending_growth_ids.is_empty() else "不购买，直接开始下一天"
	if unlock_progress_panel.visible:
		_refresh_unlock_progress()
	daily_bill_panel.size = DAILY_BILL_FIXED_SIZE
	if _upgrade_workshop != null and _upgrade_workshop.visible:
		_upgrade_workshop.refresh()


func _on_growth_ticket_pressed(ticket_index: int) -> void:
	if ticket_index < 0 or ticket_index >= _growth_recommendations.size():
		return
	var item_id := StringName(_growth_recommendations[ticket_index].get("growth_id", ""))
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or item_id.is_empty():
		return
	var result: Dictionary = game_session.call("purchase_growth", item_id)
	if bool(result.get("success", false)):
		_refresh_growth_section("已扣费并预订：对应购买位将在明日激活。")
	else:
		_refresh_growth_section("未能购买：%s" % str(result.get("reason", "条件不足")))


func _begin_next_business_day() -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null:
		return
	var result: Dictionary = game_session.call("begin_next_business_day")
	if not bool(result.get("success", false)):
		growth_balance_label.text = "下一营业日未能开始，请返回开始页后重试。"
		return
	daily_bill_panel.visible = false
	get_tree().reload_current_scene()


func _growth_ticket_status_text(recommendation: Dictionary) -> String:
	return str(_growth_ticket_presentation(recommendation).get("tooltip", ""))


func _growth_ticket_presentation(recommendation: Dictionary) -> Dictionary:
	if bool(recommendation.get("pending_activation", false)) or bool(recommendation.get("purchased", false)):
		return {"compact": "已预订，明日生效", "tooltip": "已预订，将在明日生效", "disabled": true}
	if bool(recommendation.get("can_purchase", false)):
		return {"compact": "可预订，明日生效", "tooltip": "可预订，明日生效", "disabled": false}
	var missing_requirements: Array = Array(recommendation.get("missing_requirements", []))
	var compact_text := ""
	var tooltip_text := ""
	if not missing_requirements.is_empty():
		var explanations := PackedStringArray()
		compact_text = _growth_requirement_text(Dictionary(missing_requirements.front()), true)
		for requirement_variant in missing_requirements:
			var explanation := _growth_requirement_text(Dictionary(requirement_variant), false)
			if not explanation.is_empty() and not explanations.has(explanation):
				explanations.append(explanation)
		if not explanations.is_empty():
			tooltip_text = "；".join(explanations)
	else:
		compact_text = _growth_requirement_text(recommendation, true)
		tooltip_text = _growth_requirement_text(recommendation, false)
	if tooltip_text.is_empty():
		tooltip_text = compact_text
	return {"compact": compact_text, "tooltip": tooltip_text, "disabled": true}


func _growth_requirement_text(requirement: Dictionary, compact: bool = false) -> String:
	match StringName(requirement.get("reason", &"")):
		&"pending_activation":
			return "已预订，明日生效"
		&"purchase_slot_occupied":
			var pending_name := _growth_ticket_display_name(StringName(requirement.get("pending_growth_id", &"")))
			return "该购买位已预订：%s" % pending_name
		&"area_locked":
			return "需先解锁区域：%s" % _tutorial_area_label(StringName(requirement.get("required_area_id", &"")))
		&"growth_requirement":
			return "需先解锁：%s" % _growth_ticket_display_name(StringName(requirement.get("required_growth_id", &"")))
		&"day_requirement":
			var current_day := int(requirement.get("current_day", 1))
			return "营业日 %d/%d" % [current_day, int(requirement.get("min_day", current_day))]
		&"insufficient_coins":
			return "金币 %d/%d" % [int(requirement.get("current_coins", 0)), int(requirement.get("price", 0))]
		&"reputation_requirement":
			return "口碑 %d/%d" % [int(requirement.get("current_reputation", 0)), int(requirement.get("min_reputation", 0))]
		&"tutorial_requirement":
			var required_device_id := StringName(requirement.get("requires_tutorial_device_id", requirement.get("required_tutorial_device_id", &"")))
			if not required_device_id.is_empty():
				return "需完成饮品加热教学" if compact else _tutorial_requirement_text(requirement)
			if compact:
				return "需完成%s教学" % _tutorial_area_label(StringName(requirement.get("requires_tutorial_area_id", requirement.get("required_tutorial_area_id", &""))))
			return _tutorial_requirement_text(requirement)
		&"mastery_requirement":
			return "%s %d/%d" % [
				_growth_mastery_metric_label(StringName(requirement.get("mastery_area_id", &"")), StringName(requirement.get("mastery_metric", &"qualified"))),
				int(requirement.get("current_mastery", 0)),
				int(requirement.get("required_mastery", 0)),
			]
		&"all_areas_requirement":
			return "区域 %d/%d" % [int(requirement.get("current_area_count", 0)), int(requirement.get("required_area_count", 5))]
		&"unknown_growth":
			push_error("Growth UI received an unknown growth configuration: %s" % str(requirement.get("growth_id", "")))
			return "成长配置异常，无法预订"
	push_error("Growth UI received an unsupported requirement reason: %s" % str(requirement.get("reason", "")))
	return "成长配置异常，无法预订"


func _growth_ticket_compact_status_text(recommendation: Dictionary) -> String:
	return str(_growth_ticket_presentation(recommendation).get("compact", ""))


func _growth_mastery_metric_label(area_id: StringName, metric: StringName) -> String:
	var area_label := _tutorial_area_label(area_id)
	match metric:
		&"a_grade":
			return "%s A级数" % area_label
		&"correct_temperature":
			return "%s正确温度单" % area_label
		&"correct_streak_best":
			return "%s最高连对" % area_label
	return "%s合格数" % area_label


func _tutorial_requirement_text(recommendation: Dictionary) -> String:
	var required_device_id := StringName(recommendation.get("requires_tutorial_device_id", recommendation.get("required_tutorial_device_id", &"")))
	var required_area_id := StringName(recommendation.get("requires_tutorial_area_id", recommendation.get("required_tutorial_area_id", &"")))
	var area_label := _tutorial_area_label(required_area_id)
	if required_area_id == &"area.pancake":
		return "先完成煎饼教学：当前营业日第 1 位顾客会出现免倒计时教学单，完成整套制作与交付即可。"
	return "先完成%s教学：解锁该区域后的第 1 位顾客会出现免倒计时教学单，完成整套制作与交付即可。" % area_label


func _tutorial_area_label(area_id: StringName) -> String:
	match area_id:
		&"area.pancake": return "煎饼"
		&"area.youtiao": return "油条"
		&"area.fresh_soy_milk": return "现磨豆浆"
		&"area.packaged_drink": return "成品饮品"
	return "前一区域"


func _growth_ticket_display_name(growth_id: StringName) -> String:
	var catalog_definition: Dictionary = FIVE_AREA_CATALOG.growth_definition(growth_id)
	if not str(catalog_definition.get("label", "")).is_empty():
		return str(catalog_definition.get("label"))
	var names := {
		&"growth.add_on.pancake.ham_sausage": "火腿肠",
		&"growth.add_on.pancake.meat_floss": "肉松",
		&"growth.capacity.pancake_holding_tray.two_slots": "双格暂存托盘",
		&"growth.add_on.pancake.coriander": "香菜",
		&"growth.add_on.pancake.preserved_mustard": "榨菜",
		&"growth.add_on.pancake.pork_tenderloin": "里脊肉",
		&"growth.automation.pancake.auto_sauce_brush": "自动刷酱",
		&"growth.automation.pancake.press_once": "一键压饼",
		&"growth.area.youtiao": "油条档口",
		&"growth.area.fresh_soy_milk": "现磨豆浆档口",
		&"growth.flavor.fresh_soy_milk.multigrain": "五谷口味按钮",
	}
	return str(names.get(growth_id, "未命名成长项目"))


func _open_unlock_progress() -> void:
	_refresh_unlock_progress()
	unlock_progress_panel.move_to_front()
	unlock_progress_panel.visible = true
	unlock_progress_close_button.grab_focus()


func _open_upgrade_workshop() -> void:
	if _upgrade_workshop == null:
		var workshop_scene := load(UPGRADE_WORKSHOP_SCENE_PATH) as PackedScene
		if workshop_scene == null:
			push_error("Could not load upgrade workshop scene")
			return
		_upgrade_workshop = workshop_scene.instantiate() as UpgradeWorkshopOverlay
		_upgrade_workshop.begin_next_day_requested.connect(_begin_next_business_day)
		_upgrade_workshop.closed.connect(_close_upgrade_workshop)
		$SafeArea.add_child(_upgrade_workshop)
	_set_upgrade_workshop_preview(true)
	daily_bill_panel.visible = false
	_upgrade_workshop.move_to_front()
	_upgrade_workshop.visible = true
	_upgrade_workshop.refresh()


func _close_upgrade_workshop() -> void:
	if _upgrade_workshop != null:
		_upgrade_workshop.visible = false
	_set_upgrade_workshop_preview(false)
	daily_bill_panel.visible = true
	daily_bill_panel.move_to_front()


func _set_upgrade_workshop_preview(enabled: bool) -> void:
	for node_name in [&"ServiceCustomer1", &"ServiceCustomer2", &"ServiceCustomer3", &"CustomerStrip", &"CustomerPortrait"]:
		var customer_node := get_node_or_null("SafeArea/%s" % node_name) as CanvasItem
		if customer_node == null:
			continue
		if enabled:
			_workshop_customer_visibility[node_name] = customer_node.visible
			customer_node.visible = false
		elif _workshop_customer_visibility.has(node_name):
			customer_node.visible = bool(_workshop_customer_visibility[node_name])
	if not enabled:
		_workshop_customer_visibility.clear()
	for scene_path in [
		"SafeArea/BottomStrip",
		"SafeArea/BusinessDayTimerLabel",
		"SafeArea/GlobalStatusLabel",
		"SafeArea/PaymentSprite",
		"SafeArea/PaymentCoinLayer",
		"SafeArea/P1ControlBar",
		"SafeArea/IngredientRack",
		"SafeArea/RestockRack",
		"SafeArea/LeftRack",
		"SafeArea/RightRack",
		"SafeArea/SurfaceReadoutLabel",
		"SafeArea/IngredientDragPreview",
		"FiveAreaInfrastructure/PendingPaymentButton",
	]:
		var runtime_node := get_node_or_null(scene_path) as CanvasItem
		if runtime_node == null:
			continue
		if enabled:
			_workshop_runtime_visibility[scene_path] = runtime_node.visible
			runtime_node.visible = false
		elif _workshop_runtime_visibility.has(scene_path):
			runtime_node.visible = bool(_workshop_runtime_visibility[scene_path])
	if not enabled:
		_workshop_runtime_visibility.clear()
	var pancake_worktop_hotspots := get_node_or_null("SafeArea/JianbingStallArtwork/PancakeWorktopHotspots")
	if pancake_worktop_hotspots != null and pancake_worktop_hotspots.has_method("set_workshop_preview"):
		pancake_worktop_hotspots.call("set_workshop_preview", enabled)
	var soy_station := get_node_or_null("FiveAreaInfrastructure/Stations/FreshSoyMilkStation")
	if soy_station != null and soy_station.has_method("set_workshop_preview"):
		soy_station.call("set_workshop_preview", enabled)
	var fryer := get_node_or_null("FiveAreaInfrastructure/Stations/CartoonYoutiaoFryer")
	if fryer != null and fryer.has_method("set_workshop_preview"):
		fryer.call("set_workshop_preview", enabled)
	if not enabled:
		var session := get_node_or_null("/root/GameSession")
		if session != null and session.has_method("five_area_progression_snapshot"):
			apply_progression_effects(Dictionary(session.call("five_area_progression_snapshot")))


func _close_unlock_progress() -> void:
	unlock_progress_panel.visible = false
	unlock_progress_button.grab_focus()


func _refresh_unlock_progress() -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or not game_session.has_method("five_area_progression_snapshot"):
		unlock_progress_label.text = "当前无法读取解锁进度。"
		return
	var snapshot: Dictionary = game_session.call("five_area_progression_snapshot")
	var owned_names := PackedStringArray(["基础煎饼档口与基础鏊子"])
	for growth_id_variant in Array(snapshot.get("owned_growth_ids", [])):
		var growth_id := StringName(growth_id_variant)
		owned_names.append(_growth_ticket_display_name(growth_id))
	owned_names.sort()
	var pending_names := PackedStringArray()
	for growth_id_variant in Array(snapshot.get("pending_growth_ids", [])):
		pending_names.append(_growth_ticket_display_name(StringName(growth_id_variant)))
	unlock_progress_label.text = (
		"已拥有升级（%d）\n• %s\n\n明日统一生效（尚未计入已拥有）\n• %s"
		% [
			owned_names.size(),
			"\n• ".join(owned_names),
			"无" if pending_names.is_empty() else "、".join(pending_names),
		]
	)


func _bind_global_status(game_session: Node) -> void:
	if game_session == null:
		return
	var callback := Callable(self, "_on_global_status_changed")
	for signal_name in [&"coins_changed", &"progression_changed"]:
		if game_session.has_signal(signal_name) and not game_session.is_connected(signal_name, callback):
			game_session.connect(signal_name, callback)


func _on_global_status_changed(_value: Variant = null) -> void:
	_refresh_global_status()


func _refresh_global_status() -> void:
	if global_status_label == null:
		return
	var game_session := get_node_or_null("/root/GameSession")
	var snapshot: Dictionary = {}
	if game_session != null and game_session.has_method("five_area_progression_snapshot"):
		snapshot = Dictionary(game_session.call("five_area_progression_snapshot"))
	var mastery_by_area: Dictionary = Dictionary(snapshot.get("area_mastery", {}))
	var pancake_mastery := int(mastery_by_area.get(&"area.pancake", mastery_by_area.get("area.pancake", 0)))
	global_status_label.text = "金币 %d  ·  营业日 %d  ·  口碑 %d  ·  熟练度（煎饼）%d" % [
		int(snapshot.get("coins", 0)),
		int(snapshot.get("current_day", 1)),
		int(snapshot.get("reputation", 0)),
		pancake_mastery,
	]


func _raw_order_items_for_card(order: Dictionary) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var raw_items: Array = Array(order.get("items", order.get("products", [])))
	for raw_item in raw_items:
		if raw_item is Dictionary:
			items.append((raw_item as Dictionary).duplicate(true))
	if items.is_empty():
		items.append(order.duplicate(true))
	return items


func _order_items_for_card(order: Dictionary) -> Array[Dictionary]:
	var items := _raw_order_items_for_card(order)
	if items.size() > 3:
		items.resize(3)
	return items


func _order_requirements_for_card(order: Dictionary) -> Array[Dictionary]:
	var requirements: Array[Dictionary] = []
	var items := _raw_order_items_for_card(order)
	# Ingredient hints always occupy the first row-major slots, independent of
	# the order in which multi-area items were generated.
	for item in items:
		var area_id := StringName(item.get("area_id", &""))
		if not area_id.is_empty() and area_id != &"area.pancake":
			continue
		var ingredient_ids: Array = Array(item.get("ingredients", item.get("ingredient_ids", [])))
		var ingredient_counts := {}
		for ingredient_id_value in ingredient_ids:
			var ingredient_id := StringName(ingredient_id_value)
			ingredient_counts[ingredient_id] = int(ingredient_counts.get(ingredient_id, 0)) + 1
		for ingredient_id_value in ingredient_ids:
			var ingredient_id := StringName(ingredient_id_value)
			var ingredient_texture_path := str(ORDER_CARD_INGREDIENT_TEXTURE_PATHS.get(ingredient_id, ""))
			var ingredient_texture: Texture2D = load(ingredient_texture_path) as Texture2D if not ingredient_texture_path.is_empty() else null
			if ingredient_texture == null:
				continue
			requirements.append({
				"kind": ORDER_REQUIREMENT_INGREDIENT,
				"texture": ingredient_texture,
				"ingredient_id": ingredient_id,
				"display_name": "%s×%d" % [str(ORDER_CARD_INGREDIENT_NAMES.get(ingredient_id, ingredient_id)), int(ingredient_counts[ingredient_id])] if int(ingredient_counts[ingredient_id]) > 1 else str(ORDER_CARD_INGREDIENT_NAMES.get(ingredient_id, ingredient_id)),
			})
	# Sauce requirements follow pancake toppings. They use the same stable stock
	# IDs as scoring so one- and two-sauce orders remain visually unambiguous.
	for item in items:
		var area_id := StringName(item.get("area_id", &""))
		if not area_id.is_empty() and area_id != &"area.pancake":
			continue
		var sauce_ids: Array = Array(item.get("sauce_ids", []))
		var sauce_counts := {}
		for sauce_id_value in sauce_ids:
			var sauce_id := StringName(sauce_id_value)
			sauce_counts[sauce_id] = int(sauce_counts.get(sauce_id, 0)) + 1
		for sauce_id_value in sauce_ids:
			var sauce_id := StringName(sauce_id_value)
			var sauce_texture_path := str(ORDER_CARD_SAUCE_TEXTURE_PATHS.get(sauce_id, ""))
			var sauce_texture: Texture2D = load(sauce_texture_path) as Texture2D if not sauce_texture_path.is_empty() else null
			if sauce_texture == null:
				continue
			requirements.append({
				"kind": ORDER_REQUIREMENT_SAUCE,
				"texture": sauce_texture,
				"sauce_id": sauce_id,
				"display_name": "%s×%d" % [str(ORDER_CARD_SAUCE_NAMES.get(sauce_id, sauce_id)), int(sauce_counts[sauce_id])] if int(sauce_counts[sauce_id]) > 1 else str(ORDER_CARD_SAUCE_NAMES.get(sauce_id, sauce_id)),
			})
	for item in items:
		if StringName(item.get("area_id", &"")) != &"area.fresh_soy_milk":
			continue
		var sugar_servings := clampi(int(item.get("sugar_servings", 0)), 0, 2)
		var sugar_text: String = ["无糖", "正常糖（1份）", "多糖（2份）"][sugar_servings]
		for _sugar_serving in sugar_servings:
			requirements.append({
				"kind": ORDER_REQUIREMENT_SUGAR,
				"texture": load(ORDER_CARD_SUGAR_TEXTURE_PATH) as Texture2D,
				"display_name": sugar_text,
			})
	var requirement_capacity := order_ingredient_icons.size() if not order_ingredient_icons.is_empty() else 8
	if requirements.size() > requirement_capacity:
		requirements.resize(requirement_capacity)
	return requirements


func _order_requirements_by_item_for_customer_card(order: Dictionary) -> Array:
	var grouped_requirements: Array = []
	for item in _order_items_for_card(order):
		var item_order := order.duplicate(true)
		item_order["items"] = [item]
		var item_requirements: Array = _order_requirements_for_card(item_order)
		if item_requirements.size() > 8:
			item_requirements.resize(8)
		grouped_requirements.append(item_requirements)
	return grouped_requirements


func _refresh_order_card_ui(order: Dictionary, patience_ratio: float) -> void:
	if order_dish_icons.is_empty():
		return
	var tutorial_unlimited := bool(order.get("tutorial_no_countdown", false))
	order_patience_bar.visible = not tutorial_unlimited
	order_heart_fill.visible = not tutorial_unlimited
	var click_delivery := _order_card_uses_click_delivery()
	for dish_index in order_dish_icons.size():
		var dish_icon := order_dish_icons[dish_index]
		dish_icon.texture = null
		dish_icon.visible = false
		dish_icon.modulate = Color.WHITE
		var dish_button := order_dish_buttons[dish_index]
		dish_button.visible = true
		if not click_delivery:
			dish_button.disabled = true
			dish_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dish_button.self_modulate = Color.WHITE
		dish_button.tooltip_text = "只读点单提示"
	for ingredient_index in order_ingredient_icons.size():
		var ingredient_icon := order_ingredient_icons[ingredient_index]
		ingredient_icon.texture = null
		ingredient_icon.visible = false
		ingredient_icon.tooltip_text = ""
		order_ingredient_backgrounds[ingredient_index].visible = false
		order_heat_backgrounds[ingredient_index].visible = false
	var items := _order_items_for_card(order)
	var coin_total := 0
	for dish_index in items.size():
		var item: Dictionary = items[dish_index]
		coin_total += int(item.get("payment_coins", 0))
		var dish_icon := order_dish_icons[dish_index]
		dish_icon.texture = load(ORDER_CARD_DISH_TEXTURE_PATH) as Texture2D
		dish_icon.visible = true
		var attached_count := Array(item.get("prepared_product_instance_ids", [])).size()
		var required_count := int(item.get("quantity", 1))
		var completed := attached_count >= required_count
		dish_icon.modulate = Color(0.58, 0.58, 0.58, 0.72) if completed else Color.WHITE
		var dish_button := order_dish_buttons[dish_index]
		if not click_delivery:
			dish_button.disabled = true
			dish_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dish_button.tooltip_text = "该订单商品已交付" if completed else "点击订单商品图标交付成品"
	var requirements := _order_requirements_for_card(order)
	for requirement_index in requirements.size():
		var requirement: Dictionary = requirements[requirement_index]
		var requirement_kind := StringName(requirement.get("kind", ORDER_REQUIREMENT_INGREDIENT))
		var ingredient_icon := order_ingredient_icons[requirement_index]
		ingredient_icon.texture = requirement.get("texture") as Texture2D
		ingredient_icon.visible = ingredient_icon.texture != null
		if requirement_kind == ORDER_REQUIREMENT_HEATED:
			ingredient_icon.tooltip_text = "需要加热"
		elif requirement_kind == ORDER_REQUIREMENT_SAUCE:
			ingredient_icon.tooltip_text = str(requirement.get("display_name", "酱料"))
		elif requirement_kind == ORDER_REQUIREMENT_SUGAR:
			ingredient_icon.tooltip_text = str(requirement.get("display_name", "甜度"))
		else:
			ingredient_icon.tooltip_text = str(requirement.get("display_name", "配料"))
		# The v3 order-card artwork already owns the eight requirement cells.
		# Ingredient overlays only render the icon; another panel would produce a
		# visibly offset second box. Heating keeps its semantic state highlight.
		order_ingredient_backgrounds[requirement_index].visible = false
		order_heat_backgrounds[requirement_index].visible = requirement_kind == ORDER_REQUIREMENT_HEATED
	if coin_total <= 0:
		var metadata := Dictionary(order.get("metadata", {}))
		var legacy_order := Dictionary(metadata.get("legacy_order", {}))
		coin_total = int(order.get("base_coins", metadata.get("base_coins", legacy_order.get("payment_coins", 0))))
	order_coin_icon.texture = load(ORDER_CARD_COIN_TEXTURE_PATH) as Texture2D
	order_coin_icon.visible = coin_total > 0
	order_amount_label.text = str(coin_total)
	order_patience_bar.value = clampf(patience_ratio, 0.0, 1.0) * 100.0
	_order_patience_tier = PATIENCE_BAR_STYLE.apply(order_patience_bar, patience_ratio, _order_patience_tier)
	order_heart_fill.modulate = Color.WHITE if patience_ratio > P1Session.IMPATIENT_RATIO_THRESHOLD else Color(1.0, 0.58, 0.58, 1.0)


func _refresh_formal_patience_ui(game_session: Node, current_orders: Variant = null) -> void:
	if game_session == null or not game_session.has_method("active_formal_orders"):
		return
	# One snapshot drives both the order card and all three customer slots so a
	# frame can never mix timer values from different service reads.
	# advance_formal_order_patience already returns that snapshot on normal play
	# frames; reusing it avoids another pair of deep copies of every order.
	var orders: Array = Array(current_orders) if current_orders is Array else Array(game_session.call("active_formal_orders"))
	var focused_order: Dictionary = {}
	for slot_index in customer_slot_patience_bars.size():
		var slot_order: Dictionary = {}
		for order_variant in orders:
			var candidate := Dictionary(order_variant)
			if int(candidate.get("service_slot", -1)) == slot_index:
				slot_order = candidate
				break
		if slot_order.is_empty():
			customer_slot_patience_bars[slot_index].visible = false
			continue
		var ratio := _formal_order_patience_ratio(slot_order)
		var bar := customer_slot_patience_bars[slot_index]
		bar.value = ratio * 100.0
		_customer_slot_patience_tiers[slot_index] = PATIENCE_BAR_STYLE.apply(bar, ratio, _customer_slot_patience_tiers[slot_index])
		var unlimited := bool(slot_order.get("tutorial_no_countdown", false))
		bar.visible = not unlimited
		bar.tooltip_text = "教学单·不限时" if unlimited else "耐心 %d 秒" % ceili(float(slot_order.get("remaining_patience_seconds", 0.0)))
		if StringName(slot_order.get("order_id", &"")) == _formal_order_id:
			focused_order = slot_order
	if not focused_order.is_empty() and order_patience_bar != null and order_heart_fill != null:
		var focused_ratio := _formal_order_patience_ratio(focused_order)
		var focused_unlimited := bool(focused_order.get("tutorial_no_countdown", false))
		order_patience_bar.visible = not focused_unlimited
		order_heart_fill.visible = not focused_unlimited
		order_patience_bar.value = focused_ratio * 100.0
		_order_patience_tier = PATIENCE_BAR_STYLE.apply(order_patience_bar, focused_ratio, _order_patience_tier)
		order_heart_fill.modulate = Color.WHITE if focused_ratio > P1Session.IMPATIENT_RATIO_THRESHOLD else Color(1.0, 0.58, 0.58, 1.0)
	_refresh_customer_service_slots(orders)


static func _formal_order_patience_ratio(order: Dictionary) -> float:
	if bool(order.get("tutorial_no_countdown", false)):
		return 1.0
	var total := maxf(float(order.get("patience_seconds", 0.0)), 0.001)
	return clampf(float(order.get("remaining_patience_seconds", total)) / total, 0.0, 1.0)


func _order_card_uses_click_delivery() -> bool:
	return false


func _refresh_result_presentation() -> void:
	result_panel.visible = _result_detail_open
	order_summary_card.visible = _order_summary_visible and not _result_detail_open
	if result_detail_input_shield != null:
		result_detail_input_shield.visible = _result_detail_open


func _refresh_p1_ui() -> void:
	if pancake_surface == null:
		var formal_session := get_node_or_null("/root/GameSession")
		if p1_session != null and not p1_session.order.is_empty():
			_refresh_formal_patience_ui(formal_session)
		_refresh_customer_queue()
		_refresh_result_presentation()
		return
	if p1_session == null or p1_session.order.is_empty():
		return
	customer_line_label.text = "“%s”" % str(p1_session.order.customer_line)
	patience_bar.visible = false
	order_patience_bar.visible = p1_session.has_patience_countdown
	order_heart_fill.visible = p1_session.has_patience_countdown
	patience_text_label.visible = false
	patience_text_label.text = "耐心 %d秒" % ceili(p1_session.patience_seconds) if p1_session.has_patience_countdown else "教学单·不限时"
	tutorial_guide_label.visible = not p1_session.has_patience_countdown
	if tutorial_guide_label.visible:
		get_node("SafeArea/BottomStrip").visible = true
		tutorial_guide_label.text = str(p1_session.order.get("tutorial_guide", "新手指引：本单不计倒计时。"))
	patience_bar.value = p1_session.patience_ratio() * 100.0
	var card_order := p1_session.order
	var game_session := get_node_or_null("/root/GameSession")
	if game_session != null and game_session.has_method("formal_order") and not _formal_order_id.is_empty():
		var formal_order: Dictionary = game_session.call("formal_order", _formal_order_id)
		if not formal_order.is_empty():
			card_order = formal_order
	_refresh_order_card_ui(card_order, p1_session.patience_ratio())
	phase_label.text = "当前步骤：%s · 已用时 %.0f秒" % [p1_session.phase_label(), p1_session.elapsed_seconds]
	p1_session.heat_level = 0.50
	heat_label.text = "火力固定 50%"
	heat_slider.set_value_no_signal(50.0)
	_refresh_growth_tool_buttons()
	match p1_session.phase:
		P1Session.Phase.SPREAD:
			step_action_button.text = ""
		P1Session.Phase.FIRST_SIDE:
			step_action_button.text = "翻面"
		P1Session.Phase.SECOND_SIDE:
			step_action_button.text = ""
		P1Session.Phase.SAUCE_AND_FILLINGS:
			step_action_button.text = "翻面" if not pancake_model.is_flipped else ""
		P1Session.Phase.FOLD, P1Session.Phase.PACKAGE:
			step_action_button.text = ""
		P1Session.Phase.READY_TO_SERVE:
			step_action_button.text = ""
		P1Session.Phase.HANDOFF, P1Session.Phase.PAYMENT:
			step_action_button.text = ""
		P1Session.Phase.RESULT:
			step_action_button.text = ""
	serve_button.visible = false
	var packaging_phase := p1_session.phase == P1Session.Phase.PACKAGE
	heat_label.visible = not packaging_phase
	heat_slider.visible = false
	var blocked_unflipped_topping := (
		p1_session.phase == P1Session.Phase.SAUCE_AND_FILLINGS
		and not pancake_model.is_flipped
		and ingredient_model.has_toppings()
	)
	step_action_button.visible = p1_session.phase == P1Session.Phase.FIRST_SIDE or blocked_unflipped_topping
	step_action_button.disabled = false
	step_action_button.tooltip_text = ""
	if p1_session.phase == P1Session.Phase.FIRST_SIDE:
		var flip_readiness := p1_session.flip_readiness(pancake_model, ingredient_model)
		var can_flip := bool(flip_readiness.get("success", false))
		step_action_button.disabled = not can_flip
		if bool(flip_readiness.get("early_flip", false)):
			step_action_button.text = "翻面（尚未就绪）"
			step_action_button.tooltip_text = str(flip_readiness.get("quality_warning", "提前翻面会降低订单评价"))
		elif not can_flip:
			step_action_button.text = "翻面（尚未就绪）"
			step_action_button.tooltip_text = str(flip_readiness.get("reason", "请先完成翻面准备"))
	elif blocked_unflipped_topping:
		step_action_button.disabled = true
		step_action_button.text = "翻面（已放小料）"
		step_action_button.tooltip_text = "面饼上已有小料，不能翻面；请继续加酱和小料后折叠"
	var ready_to_serve := p1_session.phase == P1Session.Phase.READY_TO_SERVE
	serve_product_button.visible = false
	serve_product_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	discard_current_pancake_button.visible = p1_session.phase not in [P1Session.Phase.HANDOFF, P1Session.Phase.PAYMENT, P1Session.Phase.RESULT]
	store_pancake_button.visible = ready_to_serve and pancake_holding_tray.visible
	var transaction_phase := p1_session.phase in [P1Session.Phase.HANDOFF, P1Session.Phase.PAYMENT, P1Session.Phase.RESULT]
	p1_control_bar.visible = not transaction_phase and not _result_detail_open
	_refresh_result_presentation()
	customer_line_label.visible = not _result_detail_open
	phase_label.visible = not _result_detail_open
	if p1_session.phase == P1Session.Phase.RESULT:
		_set_customer_portrait_state(p1_session.post_handoff_reaction())
	elif p1_session.phase not in [P1Session.Phase.HANDOFF, P1Session.Phase.PAYMENT] and p1_session.is_impatient_now():
		_set_customer_portrait_state(P1Session.REACTION_IMPATIENT)
	elif p1_session.phase not in [P1Session.Phase.HANDOFF, P1Session.Phase.PAYMENT]:
		_set_customer_portrait_state(P1Session.REACTION_NEUTRAL)
	_refresh_customer_queue()
	egg_button.disabled = false
	scraper_button.disabled = _folding_locks_preparation() or not _scraper_can_act()
	baocui_button.disabled = false
	ham_button.disabled = not ham_button.visible
	scallion_button.disabled = false
	sauce_brush_button.visible = false
	sauce_brush_button.disabled = true
	sauce_brush_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_sauce_button_states()


func _current_customer_texture(state: StringName) -> Texture2D:
	var customer_id := StringName(customer_queue.current_customer().get("id", &"customer_01"))
	var game_session := get_node_or_null("/root/GameSession")
	if game_session != null and game_session.has_method("formal_order") and not _formal_order_id.is_empty():
		var formal := Dictionary(game_session.call("formal_order", _formal_order_id))
		customer_id = StringName(formal.get("customer_id", customer_id))
	return _customer_portraits.call("texture_for", customer_id, state) as Texture2D


func _set_customer_portrait_state(state: StringName) -> void:
	var texture_state := P1Session.REACTION_IMPATIENT if state == P1Session.REACTION_VERY_UNHAPPY else state
	var target_texture := _current_customer_texture(texture_state)
	if _customer_visual_state == state and customer_portrait.texture == target_texture:
		return
	_customer_visual_state = state
	if _customer_reaction_tween != null and _customer_reaction_tween.is_valid():
		_customer_reaction_tween.kill()
	customer_portrait.texture = target_texture
	customer_portrait.pivot_offset = customer_portrait.size * 0.5
	customer_portrait.rotation = 0.0
	customer_portrait.modulate = Color.WHITE
	if state != P1Session.REACTION_VERY_UNHAPPY:
		return
	customer_portrait.modulate = Color(1.0, 0.68, 0.68, 1.0)
	_customer_reaction_tween = create_tween()
	_customer_reaction_tween.tween_property(customer_portrait, "rotation", 0.035, 0.06)
	_customer_reaction_tween.tween_property(customer_portrait, "rotation", -0.035, 0.08)
	_customer_reaction_tween.tween_property(customer_portrait, "rotation", 0.025, 0.07)
	_customer_reaction_tween.tween_property(customer_portrait, "rotation", -0.018, 0.07)
	_customer_reaction_tween.tween_property(customer_portrait, "rotation", 0.0, 0.08)


func _refresh_customer_queue() -> void:
	var orders: Array = []
	var waiting: Array = []
	var game_session := get_node_or_null("/root/GameSession")
	if game_session != null and game_session.has_method("active_formal_orders"):
		orders = Array(game_session.call("active_formal_orders"))
	if game_session != null and game_session.has_method("waiting_formal_orders"):
		waiting = Array(game_session.call("waiting_formal_orders"))
	var visible_customer_ids: Array[StringName] = []
	for visible_order_variant in orders + waiting:
		var visible_order := Dictionary(visible_order_variant)
		visible_customer_ids.append(StringName(visible_order.get("customer_id", &"customer_01")))
	_customer_portraits.call("set_visible_customers", visible_customer_ids)
	queue_status_label.text = "排队\n%d/3" % mini(waiting.size(), 3)
	for slot_index in customer_slot_buttons.size():
		var button := customer_slot_buttons[slot_index]
		var bar := customer_slot_patience_bars[slot_index]
		var order := Dictionary(waiting[slot_index]) if slot_index < waiting.size() else {}
		button.visible = not order.is_empty()
		bar.visible = false
		if order.is_empty():
			continue
		var customer_id := StringName(order.get("customer_id", CUSTOMER_QUEUE_SERVICE_SCRIPT.CUSTOMER_IDS[slot_index]))
		button.icon = _customer_portraits.call("texture_for", customer_id, &"neutral") as Texture2D
		var special_title_text := str(order.get("special_title", Dictionary(order.get("metadata", {})).get("special_title", "")))
		button.text = special_title_text if not special_title_text.is_empty() else "等候 %d" % (slot_index + 1)
		var special_rule_text := str(order.get("special_rule_text", Dictionary(order.get("metadata", {})).get("special_rule_text", "")))
		button.tooltip_text = "%s；等候期间不扣耐心" % special_rule_text if not special_rule_text.is_empty() else "等候期间不扣耐心"
		button.toggle_mode = false
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.set_pressed_no_signal(false)
	_refresh_customer_service_slots(orders)


func _resolve_customer_service_slots() -> Array[Control]:
	var result: Array[Control] = []
	for node_name in [&"ServiceCustomer1", &"ServiceCustomer2", &"ServiceCustomer3"]:
		var node := get_node_or_null("SafeArea/%s" % node_name) as Control
		if node != null:
			result.append(node)
	return result


func _refresh_customer_service_slots(orders: Array) -> void:
	if customer_service_slots.is_empty():
		return
	var restore_existing_layout := _restore_customer_layout_without_entrance
	var reduce_motion := _customer_service_slot_should_reduce_motion()
	var centered_tutorial: Dictionary = {}
	if orders.size() == 1:
		var only_order := Dictionary(orders[0])
		if bool(only_order.get("tutorial_no_countdown", false)):
			centered_tutorial = only_order
	for service_slot_index in range(customer_service_slots.size()):
		var order: Dictionary = {}
		if not centered_tutorial.is_empty():
			if service_slot_index == 1:
				order = centered_tutorial
		else:
			for order_variant in orders:
				var candidate := Dictionary(order_variant)
				if int(candidate.get("service_slot", -1)) == service_slot_index:
					order = candidate
					break
		if order.is_empty():
			# Empty slots must be cleared even on the first tutorial refresh, when they
			# have no cached signature yet. Otherwise their scene-default card remains visible.
			if restore_existing_layout:
				customer_service_slots[service_slot_index].call("restore_order", {}, null, [], [], 0)
			else:
				customer_service_slots[service_slot_index].call("present_order", {}, null, [], [], 0, reduce_motion)
			_customer_service_slot_signatures.erase(service_slot_index)
			continue
		var ratio := _formal_order_patience_ratio(order)
		var reaction := &"impatient" if ratio <= P1Session.IMPATIENT_RATIO_THRESHOLD else &"neutral"
		var signature := _customer_service_slot_signature(order, reaction)
		if _customer_service_slot_signatures.get(service_slot_index) == signature:
			customer_service_slots[service_slot_index].call("update_patience", order)
			continue
		var item_textures: Array = []
		var items := Array(order.get("items", []))
		if items.size() > 3:
			items.resize(3)
		for item_variant in items:
			var item := Dictionary(item_variant)
			item_textures.append(FIVE_AREA_PRODUCT_VISUALS.texture_for(StringName(item.get("product_id", &"")), StringName(item.get("temperature_mode", &"room_temperature"))))
		var requirements_by_item := _order_requirements_by_item_for_customer_card(order)
		var metadata := Dictionary(order.get("metadata", {}))
		var coin_total := int(order.get("perfect_quote_coins", metadata.get("perfect_quote_coins", order.get("base_coins", metadata.get("base_coins", 0)))))
		var customer_id := StringName(order.get("customer_id", &"customer_01"))
		var customer_texture := _customer_portraits.call("texture_for", customer_id, reaction) as Texture2D
		if restore_existing_layout:
			customer_service_slots[service_slot_index].call(
				"restore_order",
				order,
				customer_texture,
				item_textures,
				requirements_by_item,
				coin_total,
			)
		else:
			customer_service_slots[service_slot_index].call(
				"present_order",
				order,
				customer_texture,
				item_textures,
				requirements_by_item,
				coin_total,
				reduce_motion,
				0.0,
				Callable(self, "_reserve_customer_entrance_delay_seconds"),
			)
		_customer_service_slot_signatures[service_slot_index] = signature
	if restore_existing_layout:
		_restore_customer_layout_without_entrance = false


func _reserve_customer_entrance_delay_seconds(requested_delay_seconds: float = 0.0) -> float:
	var now_msec := Time.get_ticks_msec()
	var requested_entrance_msec := now_msec + int(ceil(maxf(requested_delay_seconds, 0.0) * 1000.0))
	var reserved_entrance_msec := maxi(requested_entrance_msec, _next_customer_entrance_msec)
	_next_customer_entrance_msec = reserved_entrance_msec + int(CUSTOMER_SERVICE_MIN_ENTRANCE_INTERVAL_SECONDS * 1000.0)
	return float(reserved_entrance_msec - now_msec) / 1000.0


func _customer_service_slot_should_reduce_motion() -> bool:
	return DisplayServer.has_method(&"accessibility_should_reduce_motion") \
		and bool(DisplayServer.call(&"accessibility_should_reduce_motion"))


static func _customer_service_slot_signature(order: Dictionary, reaction: StringName) -> Dictionary:
	var metadata := Dictionary(order.get("metadata", {}))
	return {
		"order_id": StringName(order.get("order_id", &"")),
		"customer_id": StringName(order.get("customer_id", &"customer_01")),
		"reaction": reaction,
		"tutorial_no_countdown": bool(order.get("tutorial_no_countdown", false)),
		"patience_seconds": float(order.get("patience_seconds", 0.0)),
		"perfect_quote_coins": int(order.get("perfect_quote_coins", metadata.get("perfect_quote_coins", order.get("base_coins", metadata.get("base_coins", 0))))),
		"special_customer_id": StringName(order.get("special_customer_id", metadata.get("special_customer_id", &""))),
		"special_title": str(order.get("special_title", metadata.get("special_title", ""))),
		"special_rule_text": str(order.get("special_rule_text", metadata.get("special_rule_text", ""))),
		# Order items contain every field that affects the product icon,
		# requirements, quantity and delivered state. They change only on an
		# actual order action, unlike remaining_patience_seconds.
		"items": Array(order.get("items", [])),
	}


func _refresh_customer_queue_legacy() -> void:
	pass


func _log_info(category: StringName, message: String) -> void:
	var logger := get_node_or_null("/root/AppLog")
	if logger != null and logger.has_method("info"):
		logger.info(category, message)
	else:
		print("[ProjectCake][%s] %s" % [category, message])


func _pan_polar_offset(grid_position: Vector2) -> Vector2:
	var center := Vector2(pancake_model.grid_size - 1, pancake_model.grid_size - 1) * 0.5
	var offset := grid_position - center
	return Vector2(offset.x, offset.y / maxf(parameters.pan_height_ratio, 0.01))


func _limit_egg_samples(raw_samples: PackedVector2Array) -> PackedVector2Array:
	var budget := maxi(parameters.egg_max_samples_per_frame, 1)
	if raw_samples.size() <= budget:
		return raw_samples
	var limited := PackedVector2Array()
	for sample_index in budget:
		var source_index := roundi(float(sample_index) * float(raw_samples.size() - 1) / float(maxi(budget - 1, 1)))
		limited.append(raw_samples[source_index])
	return limited
