# THESIS: One shared plate joins two equal fire lines; the workstation refuses tabbed or modal station switching.
# OWN-WORLD: Deep teal night, amber lantern light, warm wood, dark iron, cream ceramics, rounded Chinese cartoon forms.
# STORY: Read the order, tend both sides of the grill and one fryer batch, season the shared plate, deliver, and collect.
# FIRST VIEWPORT: Customer and order run across the top; grill owns the left wing, plating the center, fryer the right, with status below.
# FORM: Twin Fire Wings, grounded candidate 3, seed 3e73e27e.
# FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
class_name NightMarketWorkstation
extends Control

signal daily_bill_closed

const CATALOG := preload("res://scripts/data/night_market_catalog.gd")
const PORTRAIT_CATALOG := preload("res://scripts/ui/customer_portrait_catalog.gd")
const FOOD_ATLAS: Texture2D = preload("res://resources/art/night_market/sprites/skewer_doneness_atlas-rgba-v2.png")
const BASKET_ATLAS: Texture2D = preload("res://resources/art/night_market/sprites/fryer_basket_states-rgba-v1.png")
const EFFECT_ATLAS: Texture2D = preload("res://resources/art/night_market/sprites/cooking_effects_atlas-rgba-v1.png")
const READY_NONE := &""
const READY_GRILL_FLIP := &"grill_flip"
const READY_GRILL_LIFT := &"grill_lift"
const READY_FRYER_LIFT := &"fryer_lift"
const READY_FRYER_PLATE := &"fryer_plate"
const READY_TINT := Color(1.0, 0.86, 0.48, 1.0)

@onready var portrait: TextureRect = %Portrait
@onready var order_title: Label = %OrderTitle
@onready var order_details: Label = %OrderDetails
@onready var timer_label: Label = %TimerLabel
@onready var economy_label: Label = %EconomyLabel
@onready var detail_readout_button: Button = %DetailReadoutButton
@onready var tutorial_label: Label = %TutorialLabel
@onready var status_label: Label = %StatusLabel
@onready var grill_food_art: Array[TextureRect] = [%GrillFood0, %GrillFood1, %GrillFood2, %GrillFood3, %GrillFood4, %GrillFood5]
@onready var grill_glow_art: Array[TextureRect] = [%GrillGlowLow, %GrillGlowMedium, %GrillGlowHigh]
@onready var grill_smoke_art: TextureRect = %GrillSmokeArt
@onready var plate_food_art: Array[TextureRect] = [%PlateFood0, %PlateFood1]
@onready var seasoning_effect_art: TextureRect = %SeasoningEffectArt
@onready var fryer_food_art: TextureRect = %FryerFoodArt
@onready var fryer_basket_art: TextureRect = %FryerBasketArt
@onready var fryer_effect_art: TextureRect = %FryerEffectArt
@onready var grill_slot_buttons: Array[Button] = [%GrillSlot0, %GrillSlot1, %GrillSlot2, %GrillSlot3, %GrillSlot4, %GrillSlot5]
@onready var zone_buttons: Array[Button] = [%ZoneLowButton, %ZoneMediumButton, %ZoneHighButton]
@onready var add_lamb_button: Button = %AddLambButton
@onready var add_chicken_button: Button = %AddChickenButton
@onready var plate_grill_button: Button = %PlateGrillButton
@onready var fryer_status_label: Label = %FryerStatusLabel
@onready var fryer_hint_label: Label = %Hint
@onready var add_lotus_button: Button = %AddLotusButton
@onready var add_potato_button: Button = %AddPotatoButton
@onready var power_buttons: Array[Button] = [%PowerLowButton, %PowerStandardButton, %PowerHighButton]
@onready var lower_fryer_button: Button = %LowerFryerButton
@onready var lift_fryer_button: Button = %LiftFryerButton
@onready var plate_fryer_button: Button = %PlateFryerButton
@onready var plate_items_label: Label = %PlateItemsLabel
@onready var seasoning_buttons: Array[Button] = [%CuminButton, %ChiliButton, %SaltPepperButton, %PlumButton]
@onready var serve_button: Button = %ServeButton
@onready var discard_button: Button = %DiscardButton
@onready var refuse_button: Button = %RefuseButton
@onready var collect_button: Button = %CollectButton
@onready var plate_panel: Control = $PlatePanel
@onready var fryer_panel: Control = $FryerPanel
@onready var seasoning_title_label: Label = $PlatePanel/Layout/SeasoningTitle
@onready var chicken_restock_button: Button = %ChickenRestockButton
@onready var potato_restock_button: Button = %PotatoRestockButton
@onready var result_dim: ColorRect = $ResultDim
@onready var result_panel: Control = %ResultPanel
@onready var result_title: Label = %ResultTitle
@onready var result_details: Label = %ResultDetails
@onready var result_close_button: Button = %ResultCloseButton
@onready var day_dim: ColorRect = $DayDim
@onready var day_panel: Control = %DayPanel
@onready var day_summary: Label = %DaySummary
@onready var growth_buttons: Array[Button] = [%GrowthChicken, %GrowthEmberBaffle, %GrowthPotato, %GrowthThermostaticFryer]
@onready var end_day_button: Button = %EndDayButton
@onready var next_day_button: Button = %NextDayButton
@onready var day_menu_button: Button = %DayMenuButton
@onready var night_audio: NightMarketAudioPlayer = %NightAudio

var _session: Node
var _portraits: RefCounted = PORTRAIT_CATALOG.new()
var _refresh_elapsed := 0.0
var _selected_zone := CATALOG.ZONE_MEDIUM
var _selected_grill_slot := 2
var _atlas_cache: Dictionary = {}
var _seasoning_effect_remaining := 0.0
var _show_precision_details := false
var _active_readiness_keys: Dictionary = {}


func _ready() -> void:
	_session = get_node_or_null("/root/GameSession")
	if _session == null:
		push_error("GameSession autoload is required by the night market")
		return
	for index in grill_slot_buttons.size():
		grill_slot_buttons[index].pressed.connect(func(): _flip_grill_slot(index))
	zone_buttons[0].pressed.connect(func(): _select_zone(CATALOG.ZONE_LOW))
	zone_buttons[1].pressed.connect(func(): _select_zone(CATALOG.ZONE_MEDIUM))
	zone_buttons[2].pressed.connect(func(): _select_zone(CATALOG.ZONE_HIGH))
	add_lamb_button.pressed.connect(func(): _add_grill(CATALOG.ITEM_LAMB))
	add_chicken_button.pressed.connect(func(): _add_grill(CATALOG.ITEM_CHICKEN))
	plate_grill_button.pressed.connect(_plate_selected_grill)
	add_lotus_button.pressed.connect(func(): _add_fryer(CATALOG.ITEM_LOTUS))
	add_potato_button.pressed.connect(func(): _add_fryer(CATALOG.ITEM_POTATO))
	power_buttons[0].pressed.connect(func(): _set_fryer_power(&"low"))
	power_buttons[1].pressed.connect(func(): _set_fryer_power(&"standard"))
	power_buttons[2].pressed.connect(func(): _set_fryer_power(&"high"))
	lower_fryer_button.pressed.connect(_lower_fryer)
	lift_fryer_button.pressed.connect(_lift_fryer)
	plate_fryer_button.pressed.connect(_plate_fryer)
	seasoning_buttons[0].pressed.connect(func(): _season(CATALOG.SEASONING_CUMIN))
	seasoning_buttons[1].pressed.connect(func(): _season(CATALOG.SEASONING_CHILI))
	seasoning_buttons[2].pressed.connect(func(): _season(CATALOG.SEASONING_SALT_PEPPER))
	seasoning_buttons[3].pressed.connect(func(): _season(CATALOG.SEASONING_PLUM))
	serve_button.pressed.connect(_serve_plate)
	discard_button.pressed.connect(_discard_production)
	refuse_button.pressed.connect(_refuse_order)
	collect_button.pressed.connect(_collect_payment)
	chicken_restock_button.pressed.connect(func(): _restock(CATALOG.STOCK_CHICKEN))
	potato_restock_button.pressed.connect(func(): _restock(CATALOG.STOCK_POTATO))
	detail_readout_button.pressed.connect(_toggle_precision_details)
	result_close_button.pressed.connect(_close_result)
	end_day_button.pressed.connect(end_business_day_early)
	next_day_button.pressed.connect(_begin_next_day)
	day_menu_button.pressed.connect(func(): daily_bill_closed.emit())
	for index in growth_buttons.size():
		var growth_id := CATALOG.GROWTH_DISPLAY_ORDER[index]
		growth_buttons[index].pressed.connect(func(): _purchase_growth(growth_id))
	result_panel.visible = false
	result_dim.visible = false
	day_panel.visible = false
	day_dim.visible = false
	_initialize_art_layers()
	_session.call("set_business_paused", false)
	_session.call("night_market_ensure_active_order")
	_refresh(true)


func _process(delta: float) -> void:
	if _session == null or get_tree().paused:
		return
	var advanced := Dictionary(_session.call("night_market_advance", delta))
	if bool(advanced.get("customer_left_now", false)):
		status_label.text = "顾客等不及离开了，全局口碑 -2。"
		if not bool(advanced.get("expired_now", false)):
			_session.call("night_market_ensure_active_order")
	if bool(advanced.get("expired_now", false)):
		_show_day_bill(Dictionary(advanced.get("bill", {})))
	if _seasoning_effect_remaining > 0.0:
		_seasoning_effect_remaining = maxf(_seasoning_effect_remaining - delta, 0.0)
		seasoning_effect_art.visible = _seasoning_effect_remaining > 0.0
	_refresh_elapsed += delta
	if _refresh_elapsed >= 0.08:
		_refresh_elapsed = 0.0
		_refresh(false)


func end_business_day_early() -> void:
	if _session == null:
		return
	_show_day_bill(Dictionary(_session.call("night_market_end_day", &"manual")))


func is_blocking_modal_open() -> bool:
	return day_panel.visible or result_panel.visible


func _select_zone(zone_id: StringName) -> void:
	_selected_zone = zone_id
	status_label.text = "已选择%s，下一串会放入这里。" % _zone_label(zone_id)
	_refresh(true)


func _add_grill(item_id: StringName) -> void:
	var result := Dictionary(_session.call("night_market_add_grill_skewer", item_id, _selected_zone))
	if bool(result.get("success", false)):
		_selected_grill_slot = int(result.get("slot_index", _selected_grill_slot))
		status_label.text = "%s已放入%s；点烤位翻面。" % [CATALOG.item_label(item_id), _zone_label(_selected_zone)]
		night_audio.play_cue(&"grill_place")
	else:
		status_label.text = _reason_text(StringName(result.get("reason", &"")))
	_refresh(true)


func _flip_grill_slot(slot_index: int) -> void:
	_selected_grill_slot = slot_index
	var result := Dictionary(_session.call("night_market_flip_grill_slot", slot_index))
	status_label.text = "第 %d 烤位已翻面。" % (slot_index + 1) if bool(result.get("success", false)) else _reason_text(StringName(result.get("reason", &"")))
	if bool(result.get("success", false)):
		night_audio.play_cue(&"grill_flip")
	_refresh(true)


func _plate_selected_grill() -> void:
	var result := Dictionary(_session.call("night_market_plate_grill_slot", _selected_grill_slot))
	status_label.text = "烤串已放到中央托盘，请调味。" if bool(result.get("success", false)) else _reason_text(StringName(result.get("reason", &"")))
	if bool(result.get("success", false)):
		night_audio.play_cue(&"grill_lift")
	_refresh(true)


func _add_fryer(item_id: StringName) -> void:
	var result := Dictionary(_session.call("night_market_add_fryer_item", item_id))
	status_label.text = "%s已放入炸篮。" % CATALOG.item_label(item_id) if bool(result.get("success", false)) else _reason_text(StringName(result.get("reason", &"")))
	_refresh(true)


func _set_fryer_power(power_id: StringName) -> void:
	var result := Dictionary(_session.call("night_market_set_fryer_power", power_id))
	status_label.text = "炸锅火力调到%s。" % _power_label(power_id) if bool(result.get("success", false)) else _reason_text(StringName(result.get("reason", &"")))
	_refresh(true)


func _lower_fryer() -> void:
	var result := Dictionary(_session.call("night_market_lower_fryer"))
	status_label.text = "炸篮已入油，注意油温与上色。" if bool(result.get("success", false)) else _reason_text(StringName(result.get("reason", &"")))
	if bool(result.get("success", false)):
		night_audio.play_cue(&"fryer_lower")
	_refresh(true)


func _lift_fryer() -> void:
	var result := Dictionary(_session.call("night_market_lift_fryer"))
	status_label.text = "炸篮已提起，开始计算沥油时间。" if bool(result.get("success", false)) else _reason_text(StringName(result.get("reason", &"")))
	if bool(result.get("success", false)):
		night_audio.play_cue(&"fryer_lift")
	_refresh(true)


func _plate_fryer() -> void:
	var result := Dictionary(_session.call("night_market_plate_fryer"))
	status_label.text = "炸串已放到中央托盘，请调味。" if bool(result.get("success", false)) else _reason_text(StringName(result.get("reason", &"")))
	_refresh(true)


func _season(seasoning_id: StringName) -> void:
	var result := Dictionary(_session.call("night_market_season_last", seasoning_id))
	status_label.text = "已撒%s。" % CATALOG.seasoning_label(seasoning_id) if bool(result.get("success", false)) else _reason_text(StringName(result.get("reason", &"")))
	if bool(result.get("success", false)):
		_seasoning_effect_remaining = 0.45
		seasoning_effect_art.visible = true
		night_audio.play_cue(&"season")
	_refresh(true)


func _serve_plate() -> void:
	var result := Dictionary(_session.call("night_market_serve_plate"))
	if not bool(result.get("success", false)):
		status_label.text = _reason_text(StringName(result.get("reason", &"")))
		return
	var score := Dictionary(result.get("score", {}))
	result_title.text = "%s · %.0f 分" % [str(result.get("grade", "D")), float(score.get("overall_score", 0.0))]
	var detail_lines := PackedStringArray([str(score.get("feedback", ""))])
	for diagnostic_value in Array(score.get("diagnostics", [])):
		var diagnostic := str(diagnostic_value)
		if not diagnostic.is_empty():
			detail_lines.append("• %s" % diagnostic)
	detail_lines.append("单品 %.0f  ·  配方 %.0f  ·  时间 %.0f" % [
		float(score.get("item_score", 0.0)),
		float(score.get("recipe_score", 0.0)),
		float(score.get("time_score", 0.0)),
	])
	detail_lines.append("待收款：%d 金币" % int(result.get("payment_coins", 0)))
	result_details.text = "\n".join(detail_lines)
	result_panel.visible = true
	result_dim.visible = true
	night_audio.play_cue(&"serve")
	_refresh(true)


func _collect_payment() -> void:
	var result := Dictionary(_session.call("night_market_collect_payment"))
	if bool(result.get("success", false)):
		status_label.text = "收下 %d 金币，迎接下一位顾客。" % int(result.get("collected_coins", 0))
		night_audio.play_cue(&"payment")
		result_panel.visible = false
		result_dim.visible = false
		_session.call("night_market_ensure_active_order")
	else:
		status_label.text = _reason_text(StringName(result.get("reason", &"")))
	_refresh(true)


func _refuse_order() -> void:
	var result := Dictionary(_session.call("night_market_refuse_order"))
	if bool(result.get("success", false)):
		status_label.text = "已谢绝订单，全局口碑 %+d。" % int(result.get("reputation_delta", 0))
		_session.call("night_market_ensure_active_order")
	else:
		status_label.text = _reason_text(StringName(result.get("reason", &"")))
	_refresh(true)


func _discard_production() -> void:
	var result := Dictionary(_session.call("night_market_discard_production"))
	status_label.text = "当前烤串、炸篮与托盘已清空。" if bool(result.get("success", false)) else _reason_text(StringName(result.get("reason", &"")))
	_refresh(true)


func _restock(stock_id: StringName) -> void:
	var result := Dictionary(_session.call("night_market_restock", stock_id))
	status_label.text = "补货完成。" if bool(result.get("success", false)) else _reason_text(StringName(result.get("reason", &"")))
	_refresh(true)


func _purchase_growth(growth_id: StringName) -> void:
	var result := Dictionary(_session.call("night_market_purchase_growth", growth_id))
	status_label.text = "已购买，下一营业日生效。" if bool(result.get("success", false)) else _reason_text(StringName(result.get("reason", &"")))
	_refresh(true)


func _begin_next_day() -> void:
	var result := Dictionary(_session.call("night_market_begin_next_day"))
	if bool(result.get("success", false)):
		day_panel.visible = false
		day_dim.visible = false
		_session.call("set_business_paused", false)
		_session.call("night_market_ensure_active_order")
		status_label.text = "新一天开火，先检查鸡肉与薯片库存。"
	_refresh(true)


func _show_day_bill(bill: Dictionary) -> void:
	day_summary.text = "第 %d 日结束\n完成 %d 单 · 营收 %d 金币 · 口碑 %+d\n%s\n成长购买后将在下一营业日生效。" % [
		int(bill.get("day", 1)), int(bill.get("orders_completed", 0)),
		int(bill.get("revenue", 0)), int(bill.get("reputation_delta", 0)),
		str(_session.call("special_customer_reputation_summary")),
	]
	day_panel.visible = true
	day_dim.visible = true
	result_panel.visible = false
	result_dim.visible = false
	_refresh(true)


func _refresh(force_portrait: bool) -> void:
	if _session == null:
		return
	var shop := Dictionary(_session.call("night_market_shop_snapshot"))
	var order := Dictionary(shop.get("active_order", {}))
	var production := Dictionary(shop.get("production", {}))
	var item_names: Array[String] = []
	for value in Array(order.get("item_ids", [])):
		item_names.append(CATALOG.item_label(StringName(value)))
	order_title.text = "等待下一位顾客" if order.is_empty() else str(order.get("title", "夜宵订单"))
	order_details.text = "收款后迎接下一位顾客" if order.is_empty() else "需要：%s\n%s" % [
		" ＋ ".join(item_names),
		"教学不限时" if bool(order.get("tutorial_no_countdown", false)) else "耐心：%.0f 秒" % float(order.get("remaining_patience_seconds", 0.0)),
	]
	timer_label.text = "教学不限时" if not bool(shop.get("tutorial_completed", false)) else "%02d:%02d" % [floori(float(shop.get("remaining_seconds", 0.0)) / 60.0), int(shop.get("remaining_seconds", 0.0)) % 60]
	economy_label.text = "串铺金币 %d  ·  全局口碑 %d  ·  第 %d 日" % [int(shop.get("coins", 0)), int(_session.call("global_reputation")), int(shop.get("current_day", 1))]
	tutorial_label.text = _tutorial_step(order, production)
	var ember_baffle := _shop_owns_growth(shop, CATALOG.GROWTH_EMBER_BAFFLE)
	_update_grill(production, ember_baffle)
	_update_fryer(production)
	_update_plate(production)
	_update_art_layers(production)
	_update_readiness_feedback(production, ember_baffle)
	var unlocked := Array(shop.get("unlocked_recipe_ids", []))
	var inventory := Dictionary(shop.get("inventory", {}))
	add_chicken_button.visible = unlocked.has(CATALOG.RECIPE_CHICKEN) or unlocked.has(str(CATALOG.RECIPE_CHICKEN))
	add_potato_button.visible = unlocked.has(CATALOG.RECIPE_POTATO) or unlocked.has(str(CATALOG.RECIPE_POTATO))
	chicken_restock_button.visible = add_chicken_button.visible
	potato_restock_button.visible = add_potato_button.visible
	chicken_restock_button.text = "补鸡肉 %d/6（2币）" % int(inventory.get(str(CATALOG.STOCK_CHICKEN), 0))
	potato_restock_button.text = "补薯片 %d/6（2币）" % int(inventory.get(str(CATALOG.STOCK_POTATO), 0))
	var pending := Dictionary(shop.get("pending_payment", {}))
	collect_button.visible = not pending.is_empty()
	collect_button.text = "点击收款  +%d" % int(pending.get("coins", 0))
	serve_button.disabled = Array(production.get("plate_items", [])).is_empty()
	discard_button.disabled = not _has_production(production)
	refuse_button.disabled = order.is_empty() or bool(order.get("tutorial_no_countdown", false))
	var overview := Array(_session.call("night_market_growth_overview"))
	for index in growth_buttons.size():
		if index >= overview.size():
			continue
		var growth := Dictionary(overview[index])
		growth_buttons[index].text = "%s · %d币%s" % [
			str(growth.get("label", "成长")), int(growth.get("price", 0)),
			"（已拥有）" if bool(growth.get("owned", false)) else "（待生效）" if bool(growth.get("pending", false)) else "",
		]
		growth_buttons[index].disabled = bool(growth.get("owned", false)) or bool(growth.get("pending", false))
	day_panel.visible = day_panel.visible or not bool(shop.get("day_open", true))
	day_dim.visible = day_panel.visible
	end_day_button.disabled = not bool(shop.get("day_open", true))
	if force_portrait and not order.is_empty():
		portrait.texture = _portraits.call("texture_for", StringName(order.get("customer_id", &"customer_01")), &"neutral")


func _close_result() -> void:
	result_panel.visible = false
	result_dim.visible = false


func _toggle_precision_details() -> void:
	_show_precision_details = not _show_precision_details
	_refresh(true)


func _update_grill(production: Dictionary, ember_baffle: bool = false) -> void:
	var slots := Array(production.get("grill_slots", []))
	var selected_readiness := READY_NONE
	for index in grill_slot_buttons.size():
		var zone := CATALOG.zone_for_slot(index)
		var skewer := Dictionary(slots[index]) if index < slots.size() else {}
		var prefix := "▶ " if index == _selected_grill_slot else ""
		grill_slot_buttons[index].modulate = Color.WHITE
		if skewer.is_empty():
			grill_slot_buttons[index].text = "%s%s %d · 空位" % [prefix, _zone_label(zone), index % 2 + 1]
			grill_slot_buttons[index].tooltip_text = "选择这个烤位；放串后点按烤位翻面。"
			continue
		var item_id := StringName(skewer.get("item_id", &""))
		var current_side := "正" if StringName(skewer.get("side", &"front")) == &"front" else "反"
		var readiness := _grill_readiness(skewer, ember_baffle)
		if index == _selected_grill_slot:
			selected_readiness = readiness
		if readiness == READY_GRILL_FLIP:
			prefix = "★翻面 "
			grill_slot_buttons[index].modulate = READY_TINT
		elif readiness == READY_GRILL_LIFT:
			prefix = "★起串 "
			grill_slot_buttons[index].modulate = READY_TINT
		if _show_precision_details:
			grill_slot_buttons[index].text = "%s\n正 %.0f / 反 %.0f\n点按翻面 · 当前%s" % [
				prefix + CATALOG.item_label(item_id), float(skewer.get("front_heat", 0.0)),
				float(skewer.get("back_heat", 0.0)), current_side,
			]
		else:
			grill_slot_buttons[index].text = "%s\n正面 %s · 反面 %s" % [
				prefix + CATALOG.item_label(item_id),
				_grill_heat_label(item_id, float(skewer.get("front_heat", 0.0))),
				_grill_heat_label(item_id, float(skewer.get("back_heat", 0.0))),
			]
		if readiness == READY_GRILL_LIFT:
			grill_slot_buttons[index].tooltip_text = "两面已金黄；选中后点击下方按钮起串。点按烤位仍会翻面。"
		elif readiness == READY_GRILL_FLIP:
			grill_slot_buttons[index].tooltip_text = "当前%s面已金黄；现在点按烤位翻面。" % current_side
		else:
			grill_slot_buttons[index].tooltip_text = "点按翻面 · 当前%s面" % current_side
	zone_buttons[0].text = "小火%s" % (" ✓" if _selected_zone == CATALOG.ZONE_LOW else "")
	zone_buttons[1].text = "中火%s" % (" ✓" if _selected_zone == CATALOG.ZONE_MEDIUM else "")
	zone_buttons[2].text = "旺火%s" % (" ✓" if _selected_zone == CATALOG.ZONE_HIGH else "")
	plate_grill_button.text = "★ 两面金黄，立即起串" if selected_readiness == READY_GRILL_LIFT else "取下%s %d并装盘" % [_zone_label(CATALOG.zone_for_slot(_selected_grill_slot)), _selected_grill_slot % 2 + 1]
	plate_grill_button.modulate = READY_TINT if selected_readiness == READY_GRILL_LIFT else Color.WHITE


func _update_fryer(production: Dictionary) -> void:
	var fryer := Dictionary(production.get("fryer", {}))
	var item_id := StringName(fryer.get("item_id", &""))
	var state := StringName(fryer.get("state", &"raised"))
	var readiness := _fryer_readiness(fryer)
	var state_label := "★可提篮" if readiness == READY_FRYER_LIFT else "★可装盘" if readiness == READY_FRYER_PLATE else _fryer_state_label(state)
	if _show_precision_details:
		fryer_status_label.text = "油温 %.0f℃ · %s\n炸篮：%s ×%d · %s\n炸制 %.1f 秒 · 沥油 %.1f 秒" % [
			float(production.get("oil_temperature", 170.0)), _power_label(StringName(production.get("fryer_power", &"standard"))),
			"空" if item_id.is_empty() else CATALOG.item_label(item_id), int(fryer.get("count", 0)), state_label,
			float(fryer.get("cook_seconds", 0.0)), float(fryer.get("drain_seconds", 0.0)),
		]
	else:
		if item_id.is_empty():
			fryer_status_label.text = "油温等待食材 · %s\n炸篮空 · 先放入食材" % _power_label(StringName(production.get("fryer_power", &"standard")))
		else:
			fryer_status_label.text = "油温%s · %s\n%s ×%d · %s · %s · %s" % [
				_fryer_temperature_label(item_id, float(production.get("oil_temperature", 170.0))),
				_power_label(StringName(production.get("fryer_power", &"standard"))),
				CATALOG.item_label(item_id), int(fryer.get("count", 0)), state_label,
				_fryer_cook_label(item_id, float(fryer.get("cook_seconds", 0.0))),
				_fryer_drain_label(item_id, state, float(fryer.get("drain_seconds", 0.0))),
			]
	detail_readout_button.text = "隐藏详细数值" if _show_precision_details else "显示详细数值"
	power_buttons[0].text = "低温 160℃" if _show_precision_details else "低温"
	power_buttons[1].text = "标准 178℃" if _show_precision_details else "标准"
	power_buttons[2].text = "高温 195℃" if _show_precision_details else "高温"
	if item_id.is_empty():
		fryer_hint_label.text = "选择食材后显示其精确目标。" if _show_precision_details else "观察油泡、上色与滴油速度判断火候。"
	else:
		var definition := CATALOG.item(item_id)
		if _show_precision_details:
			fryer_hint_label.text = "%s目标：%.0f–%.0f℃ · 炸 %.1f–%.1f 秒 · 沥油 %.1f–%.1f 秒" % [
				CATALOG.item_label(item_id), float(definition.get("temp_min", 0.0)), float(definition.get("temp_max", 0.0)),
				float(definition.get("cook_min", 0.0)), float(definition.get("cook_max", 0.0)),
				float(definition.get("drain_min", 0.0)), float(definition.get("drain_max", 0.0)),
			]
		else:
			fryer_hint_label.text = "%s目标：油温适宜 · 上色金黄 · 沥油至滴落变缓" % CATALOG.item_label(item_id)
	fryer_hint_label.modulate.a = 1.0 if _show_precision_details or _panel_has_pointer_or_focus(fryer_panel) else 0.0
	lower_fryer_button.disabled = int(fryer.get("count", 0)) <= 0 or state == &"cooking"
	lift_fryer_button.disabled = state != &"cooking"
	plate_fryer_button.disabled = state != &"draining"
	lift_fryer_button.text = "★ 提篮" if readiness == READY_FRYER_LIFT else "提炸篮"
	plate_fryer_button.text = "★ 装盘" if readiness == READY_FRYER_PLATE else "装盘"
	lift_fryer_button.modulate = READY_TINT if readiness == READY_FRYER_LIFT else Color.WHITE
	plate_fryer_button.modulate = READY_TINT if readiness == READY_FRYER_PLATE else Color.WHITE


static func _grill_readiness(skewer: Dictionary, ember_baffle: bool = false) -> StringName:
	var item_id := StringName(skewer.get("item_id", &""))
	var definition := CATALOG.item(item_id)
	if definition.is_empty() or StringName(definition.get("line", &"")) != CATALOG.LINE_GRILL:
		return READY_NONE
	var minimum := float(definition.get("target_min", 45.0))
	var maximum := float(definition.get("target_max", 68.0)) + (8.0 if ember_baffle else 0.0)
	var front := float(skewer.get("front_heat", 0.0))
	var back := float(skewer.get("back_heat", 0.0))
	var front_ready := front >= minimum and front <= maximum
	var back_ready := back >= minimum and back <= maximum
	if front_ready and back_ready:
		return READY_GRILL_LIFT
	var front_active := StringName(skewer.get("side", &"front")) == &"front"
	var current_heat := front if front_active else back
	var opposite_heat := back if front_active else front
	if current_heat >= minimum and current_heat <= maximum and opposite_heat < minimum:
		return READY_GRILL_FLIP
	return READY_NONE


static func _fryer_readiness(fryer: Dictionary) -> StringName:
	var item_id := StringName(fryer.get("item_id", &""))
	var definition := CATALOG.item(item_id)
	if definition.is_empty() or StringName(definition.get("line", &"")) != CATALOG.LINE_FRYER:
		return READY_NONE
	var state := StringName(fryer.get("state", &"raised"))
	if state == &"cooking":
		var cook_seconds := float(fryer.get("cook_seconds", 0.0))
		if cook_seconds >= float(definition.get("cook_min", 4.5)) and cook_seconds <= float(definition.get("cook_max", 7.0)):
			return READY_FRYER_LIFT
	elif state == &"draining":
		var drain_seconds := float(fryer.get("drain_seconds", 0.0))
		if drain_seconds >= float(definition.get("drain_min", 0.8)) and drain_seconds <= float(definition.get("drain_max", 1.8)):
			return READY_FRYER_PLATE
	return READY_NONE


func _update_readiness_feedback(production: Dictionary, ember_baffle: bool) -> void:
	var current_keys: Dictionary = {}
	var new_messages := PackedStringArray()
	var slots := Array(production.get("grill_slots", []))
	for index in slots.size():
		var skewer := Dictionary(slots[index])
		var readiness := _grill_readiness(skewer, ember_baffle)
		if readiness == READY_NONE:
			continue
		var side := StringName(skewer.get("side", &"front"))
		var key := "grill:%d:%s:%s" % [index, readiness, side if readiness == READY_GRILL_FLIP else &"both"]
		current_keys[key] = true
		if _active_readiness_keys.has(key):
			continue
		var label := CATALOG.item_label(StringName(skewer.get("item_id", &"")))
		if readiness == READY_GRILL_FLIP:
			new_messages.append("%s%s%d已金黄，现在翻面" % [label, _zone_label(CATALOG.zone_for_slot(index)), index % 2 + 1])
		else:
			new_messages.append("%s两面已金黄，现在起串" % label)
	var fryer := Dictionary(production.get("fryer", {}))
	var fryer_readiness := _fryer_readiness(fryer)
	if fryer_readiness != READY_NONE:
		var fryer_key := "fryer:%s" % fryer_readiness
		current_keys[fryer_key] = true
		if not _active_readiness_keys.has(fryer_key):
			var fryer_label := CATALOG.item_label(StringName(fryer.get("item_id", &"")))
			new_messages.append("%s已金黄，现在提篮" % fryer_label if fryer_readiness == READY_FRYER_LIFT else "%s滴油变缓，现在装盘" % fryer_label)
	_active_readiness_keys = current_keys
	if new_messages.is_empty():
		return
	status_label.text = "火候提示：%s。" % "；".join(new_messages)
	night_audio.play_cue(&"ready_cue")


static func _shop_owns_growth(shop: Dictionary, growth_id: StringName) -> bool:
	var owned := Array(shop.get("owned_growth_ids", []))
	return owned.has(growth_id) or owned.has(str(growth_id))


func _update_plate(production: Dictionary) -> void:
	var lines: Array[String] = []
	for value in Array(production.get("plate_items", [])):
		var item := Dictionary(value)
		var seasoning := StringName(item.get("seasoning_id", &""))
		lines.append("%s · %s" % [CATALOG.item_label(StringName(item.get("item_id", &""))), "待调味" if seasoning.is_empty() else CATALOG.seasoning_label(seasoning)])
	plate_items_label.text = "托盘为空" if lines.is_empty() else "\n".join(lines)
	seasoning_title_label.modulate.a = 1.0 if _panel_has_pointer_or_focus(plate_panel) else 0.0


func _panel_has_pointer_or_focus(panel: Control) -> bool:
	if panel == null:
		return false
	var viewport := get_viewport()
	if viewport == null:
		return false
	var hovered := viewport.gui_get_hovered_control()
	var focused := viewport.gui_get_focus_owner()
	return _control_belongs_to_panel(hovered, panel) or _control_belongs_to_panel(focused, panel)


static func _control_belongs_to_panel(control: Control, panel: Control) -> bool:
	return control != null and (control == panel or panel.is_ancestor_of(control))


func _initialize_art_layers() -> void:
	grill_glow_art[0].texture = _atlas_frame(EFFECT_ATLAS, 0, 0, 4, 2)
	grill_glow_art[1].texture = _atlas_frame(EFFECT_ATLAS, 1, 0, 4, 2)
	grill_glow_art[2].texture = _atlas_frame(EFFECT_ATLAS, 2, 0, 4, 2)
	grill_glow_art[0].modulate.a = 0.42
	grill_glow_art[1].modulate.a = 0.52
	grill_glow_art[2].modulate.a = 0.62
	grill_smoke_art.texture = _atlas_frame(EFFECT_ATLAS, 3, 0, 4, 2)
	seasoning_effect_art.texture = _atlas_frame(EFFECT_ATLAS, 3, 1, 4, 2)
	fryer_basket_art.texture = _atlas_frame(BASKET_ATLAS, 0, 0, 3, 1)


func _update_art_layers(production: Dictionary) -> void:
	var slots := Array(production.get("grill_slots", []))
	var has_overcooked_grill := false
	for index in grill_food_art.size():
		var visual := grill_food_art[index]
		var skewer := Dictionary(slots[index]) if index < slots.size() else {}
		visual.visible = not skewer.is_empty()
		if skewer.is_empty():
			continue
		var item_id := StringName(skewer.get("item_id", &""))
		var doneness := _doneness_column(item_id, skewer)
		visual.texture = _atlas_frame(FOOD_ATLAS, doneness, _item_row(item_id), 4, 4)
		visual.pivot_offset = visual.size * 0.5
		visual.rotation = deg_to_rad(-2.0 if StringName(skewer.get("side", &"front")) == &"front" else 3.0)
		has_overcooked_grill = has_overcooked_grill or doneness >= 3
	grill_smoke_art.visible = has_overcooked_grill

	var plate := Array(production.get("plate_items", []))
	for index in plate_food_art.size():
		var visual := plate_food_art[index]
		var plated := Dictionary(plate[index]) if index < plate.size() else {}
		visual.visible = not plated.is_empty()
		if plated.is_empty():
			continue
		var item_id := StringName(plated.get("item_id", &""))
		visual.texture = _atlas_frame(FOOD_ATLAS, _doneness_column(item_id, plated), _item_row(item_id), 4, 4)
		visual.modulate = Color(1.0, 0.96, 0.86, 1.0) if not StringName(plated.get("seasoning_id", &"")).is_empty() else Color.WHITE

	var fryer := Dictionary(production.get("fryer", {}))
	var fryer_state := StringName(fryer.get("state", &"raised"))
	var basket_frame := 0 if fryer_state == &"raised" else 1 if fryer_state == &"cooking" else 2
	fryer_basket_art.texture = _atlas_frame(BASKET_ATLAS, basket_frame, 0, 3, 1)
	if fryer_state == &"draining":
		fryer_basket_art.position = Vector2(1430.0, 415.0)
		fryer_food_art.position = Vector2(1510.0, 500.0)
	elif fryer_state == &"cooking":
		fryer_basket_art.position = Vector2(1175.0, 485.0)
		fryer_food_art.position = Vector2(1260.0, 555.0)
	else:
		fryer_basket_art.position = Vector2(1175.0, 440.0)
		fryer_food_art.position = Vector2(1260.0, 520.0)
	var fryer_item_id := StringName(fryer.get("item_id", &""))
	fryer_food_art.visible = not fryer_item_id.is_empty() and int(fryer.get("count", 0)) > 0
	if fryer_food_art.visible:
		fryer_food_art.texture = _atlas_frame(FOOD_ATLAS, _doneness_column(fryer_item_id, fryer), _item_row(fryer_item_id), 4, 4)
	fryer_effect_art.visible = fryer_state == &"cooking"
	if fryer_effect_art.visible:
		var oil_temperature := float(production.get("oil_temperature", 170.0))
		var bubble_frame := 0 if oil_temperature < 160.0 else 1 if oil_temperature <= 190.0 else 2
		fryer_effect_art.texture = _atlas_frame(EFFECT_ATLAS, bubble_frame, 1, 4, 2)
	var fryer_overcooked := fryer_food_art.visible and _doneness_column(fryer_item_id, fryer) >= 3
	night_audio.set_cooking_activity(
		not slots.all(func(value: Variant) -> bool: return Dictionary(value).is_empty()),
		fryer_state == &"cooking",
		has_overcooked_grill or fryer_overcooked
	)


func _atlas_frame(atlas: Texture2D, column: int, row: int, columns: int, rows: int) -> AtlasTexture:
	var cache_key := "%s:%d:%d:%d:%d" % [atlas.resource_path, column, row, columns, rows]
	if _atlas_cache.has(cache_key):
		return _atlas_cache[cache_key]
	var left := floori(float(column * atlas.get_width()) / float(columns))
	var top := floori(float(row * atlas.get_height()) / float(rows))
	var right := floori(float((column + 1) * atlas.get_width()) / float(columns))
	var bottom := floori(float((row + 1) * atlas.get_height()) / float(rows))
	var frame := AtlasTexture.new()
	frame.atlas = atlas
	frame.region = Rect2(left, top, right - left, bottom - top)
	_atlas_cache[cache_key] = frame
	return frame


static func _item_row(item_id: StringName) -> int:
	return {
		CATALOG.ITEM_LAMB: 0,
		CATALOG.ITEM_CHICKEN: 1,
		CATALOG.ITEM_LOTUS: 2,
		CATALOG.ITEM_POTATO: 3,
	}.get(item_id, 0)


static func _doneness_column(item_id: StringName, item_state: Dictionary) -> int:
	var definition := CATALOG.item(item_id)
	if StringName(definition.get("line", &"")) == CATALOG.LINE_GRILL:
		var average_heat := (float(item_state.get("front_heat", 0.0)) + float(item_state.get("back_heat", 0.0))) * 0.5
		if average_heat <= 2.0:
			return 0
		if average_heat < float(definition.get("target_min", 45.0)):
			return 1
		if average_heat <= float(definition.get("target_max", 68.0)):
			return 2
		return 3
	var cook_seconds := float(item_state.get("cook_seconds", 0.0))
	if cook_seconds <= 0.1:
		return 0
	if cook_seconds < float(definition.get("cook_min", 4.5)):
		return 1
	if cook_seconds <= float(definition.get("cook_max", 7.0)):
		return 2
	return 3


static func _grill_heat_label(item_id: StringName, heat: float) -> String:
	var definition := CATALOG.item(item_id)
	if heat <= 2.0:
		return "生"
	if heat < float(definition.get("target_min", 45.0)):
		return "渐熟"
	if heat <= float(definition.get("target_max", 68.0)):
		return "金黄"
	return "焦深"


static func _fryer_temperature_label(item_id: StringName, temperature: float) -> String:
	if item_id.is_empty():
		return "等待食材"
	var definition := CATALOG.item(item_id)
	if temperature < float(definition.get("temp_min", 165.0)):
		return "偏低"
	if temperature <= float(definition.get("temp_max", 185.0)):
		return "适宜"
	return "偏高"


static func _fryer_cook_label(item_id: StringName, cook_seconds: float) -> String:
	if item_id.is_empty() or cook_seconds <= 0.1:
		return "未开始"
	var definition := CATALOG.item(item_id)
	if cook_seconds < float(definition.get("cook_min", 4.5)):
		return "渐熟"
	if cook_seconds <= float(definition.get("cook_max", 7.0)):
		return "金黄"
	return "焦深"


static func _fryer_drain_label(item_id: StringName, state: StringName, drain_seconds: float) -> String:
	if item_id.is_empty() or state != &"draining":
		return "尚未沥油"
	var definition := CATALOG.item(item_id)
	if drain_seconds < float(definition.get("drain_min", 0.8)):
		return "滴油明显"
	if drain_seconds <= float(definition.get("drain_max", 1.8)):
		return "沥油正好"
	return "沥得偏干"


func _tutorial_step(order: Dictionary, production: Dictionary) -> String:
	if order.is_empty() or not bool(order.get("tutorial_no_countdown", false)):
		return "左烤右炸同时推进，中央托盘最多放两串。"
	var plate := Array(production.get("plate_items", []))
	var has_lamb := false
	var has_lotus := false
	for value in plate:
		var item_id := StringName(Dictionary(value).get("item_id", &""))
		has_lamb = has_lamb or item_id == CATALOG.ITEM_LAMB
		has_lotus = has_lotus or item_id == CATALOG.ITEM_LOTUS
	if has_lamb and has_lotus:
		for value in plate:
			if StringName(Dictionary(value).get("seasoning_id", &"")).is_empty():
				return "教学：给托盘上尚未调味的串撒对应调味。"
		return "教学：双拼完成，点击递交。"
	var slots := Array(production.get("grill_slots", []))
	var grill_has_lamb := false
	for value in slots:
		grill_has_lamb = grill_has_lamb or StringName(Dictionary(value).get("item_id", &"")) == CATALOG.ITEM_LAMB
	if not has_lamb and not grill_has_lamb:
		return "教学：选择中火，放入一串羊肉串。"
	var fryer := Dictionary(production.get("fryer", {}))
	if not has_lotus and StringName(fryer.get("item_id", &"")).is_empty():
		return "教学：把一串藕片放入右侧炸篮。"
	return "教学：翻烤羊肉两面；藕片炸好后提篮沥油，再分别装盘。"


static func _has_production(production: Dictionary) -> bool:
	if not Array(production.get("plate_items", [])).is_empty() or int(Dictionary(production.get("fryer", {})).get("count", 0)) > 0:
		return true
	for value in Array(production.get("grill_slots", [])):
		if not Dictionary(value).is_empty():
			return true
	return false


static func _zone_label(zone_id: StringName) -> String:
	return {CATALOG.ZONE_LOW: "小火区", CATALOG.ZONE_MEDIUM: "中火区", CATALOG.ZONE_HIGH: "旺火区"}.get(zone_id, "中火区")


static func _power_label(power_id: StringName) -> String:
	return {&"low": "低温", &"standard": "标准", &"high": "高温"}.get(power_id, "标准")


static func _fryer_state_label(state: StringName) -> String:
	return {&"raised": "提起", &"cooking": "入油", &"draining": "沥油"}.get(state, "提起")


static func _reason_text(reason: StringName) -> String:
	return {
		&"empty_grill_slot": "这个烤位是空的；先放串，或选择有串的烤位。",
		&"grill_zone_full": "这个火区的两个烤位都满了，请选择其他火区。",
		&"plate_full": "中央托盘已经放满两串，请先递交或废弃。",
		&"insufficient_stock": "高级食材缺货，请先补货。",
		&"fryer_basket_not_raised": "炸篮仍在油中或正在沥油，不能继续加料。",
		&"mixed_fryer_batch": "同一炸篮不能混炸两种食材。",
		&"fryer_basket_full": "主炸篮一次最多放两串。",
		&"empty_fryer_basket": "炸篮还是空的。",
		&"fryer_already_lowered": "炸篮已经入油。",
		&"fryer_not_cooking": "炸篮尚未入油。",
		&"fryer_not_draining": "请先提起炸篮开始沥油。",
		&"fryer_reimmersion_used": "这一批已经回锅过一次，不能再次入油。",
		&"no_unseasoned_item": "托盘上没有等待调味的串。",
		&"plate_empty": "中央托盘还是空的。",
		&"no_pending_payment": "当前没有待收款。",
		&"tutorial_order_cannot_be_refused": "教学单不能谢绝，请先完成双拼。",
		&"no_production": "当前没有可废弃的食物。",
		&"business_day_open": "请先结束营业日。",
		&"insufficient_coins": "金币不足。",
		&"stock_full": "库存已经装满。",
		&"missing_prerequisite": "前置成长尚未购买。",
	}.get(reason, "当前操作还不能进行。")
