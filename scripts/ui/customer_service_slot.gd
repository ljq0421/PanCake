class_name CustomerServiceSlot
extends Control

const PATIENCE_BAR_STYLE := preload("res://scripts/ui/patience_bar_style.gd")
const CARD_BACKGROUND_BY_ITEM_COUNT := {
	1: preload("res://resources/art/ui/order/order_card_background_rows_1_v1.png"),
	2: preload("res://resources/art/ui/order/order_card_background_rows_2_v1.png"),
	3: preload("res://resources/art/ui/order/order_card_background_rows_3_v1.png"),
}
const INGREDIENT_COLUMNS := 4
const INGREDIENTS_PER_ITEM := 8
const PATIENCE_FILL_POSITION_X := 52.0
const PATIENCE_FILL_BOTTOM_INSET := 26.0
const PATIENCE_FILL_SIZE := Vector2(168.0, 10.0)
const PORTRAIT_OFFSCREEN_LEFT_MARGIN := 16.0
const PORTRAIT_ENTER_SECONDS := 1.10
const PORTRAIT_EXIT_SECONDS := 0.80
const REDUCED_PORTRAIT_SECONDS := 0.60
const REDUCED_ORDER_PANEL_DELAY_SECONDS := 0.20
const REDUCED_ORDER_PANEL_SECONDS := 0.50
const PORTRAIT_WALK_PIXELS_PER_SECOND := 250.0
const WALK_STEP_COUNT := 3.0
const WALK_BOB_PIXELS := 8.0
const WALK_SWAY_RADIANS := 0.025

@export_category("Order Card Layout")
@export_range(1.0, 1000.0, 1.0, "suffix:px") var card_width := 0.0
@export_range(1.0, 1000.0, 1.0, "suffix:px") var card_height_one_item := 0.0
@export_range(1.0, 1000.0, 1.0, "suffix:px") var card_height_two_items := 0.0
@export_range(1.0, 1000.0, 1.0, "suffix:px") var card_height_three_items := 0.0
@export_range(0.0, 500.0, 1.0, "suffix:px") var row_top := 0.0
@export_range(1.0, 500.0, 1.0, "suffix:px") var row_height := 0.0
@export_range(0.0, 500.0, 1.0, "suffix:px") var row_gap := 0.0
@export var product_icon_offset := Vector2.ZERO
@export var product_icon_size := Vector2.ZERO
@export var ingredient_grid_offset := Vector2.ZERO
@export var ingredient_grid_spacing := Vector2.ZERO
@export var ingredient_icon_size := Vector2.ZERO

signal focus_requested(order_id: StringName)
signal delivery_requested(order_id: StringName, item_index: int)
signal product_dropped(order_id: StringName, item_index: int, source_ref: Dictionary)

@onready var portrait: TextureRect = %Portrait
@onready var order_panel: Control = $OrderPanel
@onready var card_background: TextureRect = %CardBackground
@onready var card_focus_button: Button = %CardFocusButton
@onready var order_title: Label = %OrderTitle
@onready var special_title: Label = %SpecialTitle
@onready var special_rule: Label = %SpecialRule
@onready var item_buttons: Array[Button] = [%ItemButton1, %ItemButton2, %ItemButton3]
@onready var item_icons: Array[TextureRect] = [%ItemIcon1, %ItemIcon2, %ItemIcon3]
@onready var quantity_labels: Array[Label] = [%Quantity1, %Quantity2, %Quantity3]
@onready var patience_bar: ProgressBar = %PatienceBar

var _order_id: StringName = &""
var _patience_bar_tier := -1
var _ingredient_icons_by_item: Array = []
var _presentation_tween: Tween
var _pending_presentation: Dictionary = {}
var _portrait_rest_position := Vector2.ZERO
var _portrait_rest_global_position := Vector2.ZERO
var _order_panel_rest_position := Vector2.ZERO
var _transition_phase: StringName = &"idle"


func _ready() -> void:
	_create_simple_card_controls()
	card_focus_button.pressed.connect(_request_focus)
	for item_index in range(item_buttons.size()):
		item_buttons[item_index].pressed.connect(_request_delivery.bind(item_index))
		if item_buttons[item_index].has_signal("product_source_dropped"):
			item_buttons[item_index].connect("product_source_dropped", _on_product_source_dropped)
	_portrait_rest_position = portrait.position
	_portrait_rest_global_position = portrait.global_position
	_order_panel_rest_position = order_panel.position
	portrait.pivot_offset = Vector2(portrait.size.x * 0.5, portrait.size.y)
	_reset_presentation_transforms()
	visible = false


## Queues a customer presentation without changing the synchronous bind_order()
## contract used by card rendering and tests. Repeated refreshes always retain
## only the latest requested customer while an outgoing customer is leaving.
func present_order(
	order: Dictionary,
	customer_texture: Texture2D,
	item_textures: Array,
	requirements_by_item: Array,
	perfect_quote: int,
	reduce_motion: bool = false,
	entrance_delay_seconds: float = 0.0,
	entrance_delay_reserver: Callable = Callable(),
) -> void:
	var requested_order_id := StringName(order.get("order_id", &""))
	_pending_presentation = {
		"order": order.duplicate(true),
		"customer_texture": customer_texture,
		"item_textures": item_textures.duplicate(true),
		"requirements_by_item": requirements_by_item.duplicate(true),
		"perfect_quote": perfect_quote,
		"reduce_motion": reduce_motion,
		"entrance_delay_seconds": maxf(entrance_delay_seconds, 0.0),
		"entrance_delay_reserver": entrance_delay_reserver,
	}
	if requested_order_id == _order_id and _transition_phase != &"exiting":
		bind_order(order, customer_texture, item_textures, requirements_by_item, perfect_quote)
		return
	if _transition_phase == &"exiting":
		return
	if _transition_phase == &"entering":
		_cancel_presentation_tween()
		_reset_presentation_transforms()
		_transition_phase = &"idle"
	if _order_id.is_empty() or not visible:
		_present_pending_customer()
		return
	_play_customer_exit(reduce_motion)


func is_presentation_transitioning() -> bool:
	return _transition_phase != &"idle"


## Restores a persisted customer exactly at the authored service position.
## Continue-game scene binding uses this path so saved customers do not replay
## an arrival that already happened before the player left.
func restore_order(
	order: Dictionary,
	customer_texture: Texture2D,
	item_textures: Array,
	requirements_by_item: Array,
	perfect_quote: int,
) -> void:
	_pending_presentation.clear()
	_cancel_presentation_tween()
	_transition_phase = &"idle"
	_reset_presentation_transforms()
	bind_order(order, customer_texture, item_textures, requirements_by_item, perfect_quote)
	order_panel.visible = visible
	_set_order_interaction_enabled(visible)


func bind_order(order: Dictionary, customer_texture: Texture2D, item_textures: Array, requirements_by_item: Array, perfect_quote: int) -> void:
	_order_id = StringName(order.get("order_id", &""))
	visible = not _order_id.is_empty()
	if not visible:
		return
	portrait.texture = customer_texture
	var special_customer_id := StringName(order.get("special_customer_id", Dictionary(order.get("metadata", {})).get("special_customer_id", &"")))
	var title_text := str(order.get("special_title", Dictionary(order.get("metadata", {})).get("special_title", "")))
	var rule_text := str(order.get("special_rule_text", Dictionary(order.get("metadata", {})).get("special_rule_text", "")))
	special_title.visible = not special_customer_id.is_empty()
	special_title.text = title_text
	special_rule.visible = not special_customer_id.is_empty()
	special_rule.text = rule_text
	# The coin is baked into the card background; leave only the dynamic reward amount.
	# Tutorial orders use this same compact header for their no-countdown status.
	order_title.text = "教学单 · 不限时" if bool(order.get("tutorial_no_countdown", false)) else str(maxi(perfect_quote, 0))
	var items := Array(order.get("items", []))
	if items.size() > item_buttons.size():
		items.resize(item_buttons.size())
	_apply_simple_card_layout(items.size())
	for item_index in range(item_buttons.size()):
		var has_item := item_index < items.size() and item_index < item_textures.size()
		item_buttons[item_index].visible = has_item
		quantity_labels[item_index].visible = false
		if not has_item:
			continue
		var item := Dictionary(items[item_index])
		var attached_count := Array(item.get("prepared_product_instance_ids", [])).size()
		var required_count := maxi(int(item.get("quantity", 1)), 1)
		var completed := attached_count >= required_count
		item_buttons[item_index].disabled = completed
		item_buttons[item_index].tooltip_text = "该商品已交付" if completed else "把匹配成品拖到这里交付"
		item_icons[item_index].texture = item_textures[item_index] as Texture2D
		item_icons[item_index].modulate = Color(0.55, 0.55, 0.55, 0.72) if completed else Color.WHITE
		quantity_labels[item_index].visible = required_count > 1
		quantity_labels[item_index].text = "✓" if completed else "%d/%d" % [mini(attached_count, required_count), required_count]
	_bind_requirements_by_item(requirements_by_item)
	update_patience(order)


func update_patience(order: Dictionary) -> void:
	if _order_id.is_empty() or StringName(order.get("order_id", &"")) != _order_id:
		return
	var unlimited := bool(order.get("tutorial_no_countdown", false))
	var total := maxf(float(order.get("patience_seconds", 0.0)), 0.001)
	var remaining := maxf(float(order.get("remaining_patience_seconds", total)), 0.0)
	var ratio := 1.0 if unlimited else clampf(remaining / total, 0.0, 1.0)
	patience_bar.visible = not unlimited
	patience_bar.value = ratio * 100.0
	_patience_bar_tier = PATIENCE_BAR_STYLE.apply(patience_bar, ratio, _patience_bar_tier)


func _play_customer_exit(reduce_motion: bool) -> void:
	_transition_phase = &"exiting"
	_set_order_interaction_enabled(false)
	_cancel_presentation_tween()
	_presentation_tween = create_tween()
	_presentation_tween.set_parallel(true)
	if reduce_motion:
		portrait.position = _portrait_rest_position
		order_panel.position = _order_panel_rest_position
		_presentation_tween.tween_property(portrait, "modulate:a", 0.0, REDUCED_PORTRAIT_SECONDS).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		_presentation_tween.tween_property(order_panel, "modulate:a", 0.0, REDUCED_ORDER_PANEL_SECONDS).set_delay(REDUCED_ORDER_PANEL_DELAY_SECONDS).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	else:
		# Normal motion is deliberately walk-only; fades and card translation read as drifting.
		portrait.modulate.a = 1.0
		order_panel.position = _order_panel_rest_position
		order_panel.modulate.a = 1.0
		var exit_start := _portrait_rest_global_position
		var exit_end := _portrait_offscreen_left_global_position()
		var portrait_exit_seconds := _walk_duration_seconds(exit_start, exit_end, PORTRAIT_EXIT_SECONDS)
		_presentation_tween.tween_method(_apply_portrait_walk_progress.bind(exit_start, exit_end), 0.0, 1.0, portrait_exit_seconds).set_trans(Tween.TRANS_LINEAR)
	_presentation_tween.chain().tween_callback(_on_customer_exit_finished)


func _on_customer_exit_finished() -> void:
	_presentation_tween = null
	_transition_phase = &"idle"
	_present_pending_customer()


func _present_pending_customer() -> void:
	var presentation := _pending_presentation.duplicate(true)
	_pending_presentation.clear()
	var next_order := Dictionary(presentation.get("order", {}))
	bind_order(
		next_order,
		presentation.get("customer_texture") as Texture2D,
		Array(presentation.get("item_textures", [])),
		Array(presentation.get("requirements_by_item", [])),
		int(presentation.get("perfect_quote", 0)),
	)
	if _order_id.is_empty():
		_reset_presentation_transforms()
		_transition_phase = &"idle"
		return
	var reduce_motion := bool(presentation.get("reduce_motion", false))
	var entrance_delay_seconds := float(presentation.get("entrance_delay_seconds", 0.0))
	var entrance_delay_reserver: Callable = presentation.get("entrance_delay_reserver", Callable())
	if entrance_delay_reserver.is_valid():
		entrance_delay_seconds = maxf(float(entrance_delay_reserver.call(entrance_delay_seconds)), 0.0)
	_transition_phase = &"entering"
	_set_order_interaction_enabled(false)
	order_panel.visible = false
	_cancel_presentation_tween()
	if reduce_motion:
		portrait.position = _portrait_rest_position
		order_panel.position = _order_panel_rest_position
		portrait.modulate.a = 0.0
		order_panel.modulate.a = 1.0
	else:
		portrait.global_position = _portrait_offscreen_left_global_position()
		portrait.modulate.a = 1.0
		order_panel.position = _order_panel_rest_position
		order_panel.modulate.a = 1.0
	_presentation_tween = create_tween()
	_presentation_tween.set_parallel(true)
	if reduce_motion:
		_presentation_tween.tween_property(portrait, "modulate:a", 1.0, REDUCED_PORTRAIT_SECONDS).set_delay(entrance_delay_seconds).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	else:
		# Linear progress keeps the configured pixels-per-second speed perceptually constant.
		var entry_start := _portrait_offscreen_left_global_position()
		var portrait_enter_seconds := _walk_duration_seconds(entry_start, _portrait_rest_global_position, PORTRAIT_ENTER_SECONDS)
		_presentation_tween.tween_method(_apply_portrait_walk_progress.bind(entry_start, _portrait_rest_global_position), 0.0, 1.0, portrait_enter_seconds).set_delay(entrance_delay_seconds).set_trans(Tween.TRANS_LINEAR)
	_presentation_tween.chain().tween_callback(_on_customer_enter_finished)


func _on_customer_enter_finished() -> void:
	_presentation_tween = null
	_transition_phase = &"idle"
	_reset_presentation_transforms()
	order_panel.visible = true
	_set_order_interaction_enabled(true)


func _cancel_presentation_tween() -> void:
	if _presentation_tween != null and _presentation_tween.is_valid():
		_presentation_tween.kill()
	_presentation_tween = null


func _reset_presentation_transforms() -> void:
	portrait.position = _portrait_rest_position
	order_panel.position = _order_panel_rest_position
	portrait.rotation = 0.0
	portrait.modulate.a = 1.0
	order_panel.modulate.a = 1.0


func _set_order_interaction_enabled(enabled: bool) -> void:
	card_focus_button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	for item_button in item_buttons:
		item_button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func _portrait_offscreen_left_global_position() -> Vector2:
	var viewport := get_viewport()
	var viewport_left := viewport.get_visible_rect().position.x if viewport != null else 0.0
	return Vector2(viewport_left - portrait.size.x - PORTRAIT_OFFSCREEN_LEFT_MARGIN, _portrait_rest_global_position.y)


func _walk_duration_seconds(start_position: Vector2, end_position: Vector2, minimum_seconds: float) -> float:
	return maxf(minimum_seconds, start_position.distance_to(end_position) / PORTRAIT_WALK_PIXELS_PER_SECOND)


func _apply_portrait_walk_progress(progress: float, start_position: Vector2, end_position: Vector2) -> void:
	var step_wave := sin(progress * PI * WALK_STEP_COUNT)
	portrait.global_position = start_position.lerp(end_position, progress) + Vector2(0.0, -absf(step_wave) * WALK_BOB_PIXELS)
	portrait.rotation = step_wave * WALK_SWAY_RADIANS


func _create_simple_card_controls() -> void:
	# The painted card contains only the background; dish and ingredient icons remain dynamic.
	card_background.visible = true
	for item_index in range(item_buttons.size()):
		var ingredient_icons: Array[TextureRect] = []
		for ingredient_index in range(INGREDIENTS_PER_ITEM):
			var ingredient_slot := Control.new()
			ingredient_slot.name = "IngredientSlot%d_%d" % [item_index + 1, ingredient_index + 1]
			# The painted order-card background is now visible, so requirements must render above it.
			ingredient_slot.z_index = 1
			ingredient_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var ingredient_icon := TextureRect.new()
			ingredient_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ingredient_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 3)
			ingredient_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ingredient_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ingredient_slot.add_child(ingredient_icon)
			order_panel.add_child(ingredient_slot)
			ingredient_icons.append(ingredient_icon)
		_ingredient_icons_by_item.append(ingredient_icons)


func _apply_simple_card_layout(item_count: int) -> void:
	var visible_item_count := clampi(item_count, 1, item_buttons.size())
	var card_height := _card_height_for_item_count(visible_item_count)
	order_panel.size = Vector2(card_width, card_height)
	card_background.texture = CARD_BACKGROUND_BY_ITEM_COUNT[visible_item_count]
	order_title.position = Vector2(52.0, 7.0)
	order_title.size = Vector2(144.0, 20.0)
	special_title.position = Vector2(52.0, 28.0)
	special_title.size = Vector2(182.0, 16.0)
	special_rule.position = Vector2(18.0, card_height - 47.0)
	special_rule.size = Vector2(214.0, 17.0)
	# Only the fill is drawn here. The heart, track and border stay in the card bitmap.
	patience_bar.position = Vector2(PATIENCE_FILL_POSITION_X, card_height - PATIENCE_FILL_BOTTOM_INSET)
	patience_bar.size = PATIENCE_FILL_SIZE
	for item_index in range(item_buttons.size()):
		var item_row_top := row_top + item_index * (row_height + row_gap)
		var is_visible := item_index < visible_item_count
		# Center every dish target within its visual order row; icons inherit the target's full rect.
		item_buttons[item_index].position = Vector2(
			product_icon_offset.x,
			item_row_top + (row_height - product_icon_size.y) * 0.5,
		)
		item_buttons[item_index].size = product_icon_size
		quantity_labels[item_index].position = Vector2(5.0, 42.0)
		quantity_labels[item_index].size = Vector2(45.0, 20.0)
		var ingredient_icons: Array = _ingredient_icons_by_item[item_index]
		for ingredient_index in range(ingredient_icons.size()):
			var ingredient_icon := ingredient_icons[ingredient_index] as TextureRect
			var ingredient_slot := ingredient_icon.get_parent() as Control
			var column := ingredient_index % INGREDIENT_COLUMNS
			var ingredient_row := ingredient_index / INGREDIENT_COLUMNS
			ingredient_slot.position = Vector2(
				ingredient_grid_offset.x + column * ingredient_grid_spacing.x,
				item_row_top + ingredient_grid_offset.y + ingredient_row * ingredient_grid_spacing.y,
			)
			ingredient_slot.size = ingredient_icon_size
			ingredient_slot.visible = false


func _card_height_for_item_count(item_count: int) -> float:
	match item_count:
		1:
			return card_height_one_item
		2:
			return card_height_two_items
		_:
			return card_height_three_items


func _bind_requirements_by_item(requirements_by_item: Array) -> void:
	for item_index in range(_ingredient_icons_by_item.size()):
		var item_requirements: Array = Array(requirements_by_item[item_index]) if item_index < requirements_by_item.size() else []
		if item_requirements.size() > INGREDIENTS_PER_ITEM:
			item_requirements.resize(INGREDIENTS_PER_ITEM)
		var ingredient_icons: Array = _ingredient_icons_by_item[item_index]
		for ingredient_index in range(ingredient_icons.size()):
			var ingredient_icon := ingredient_icons[ingredient_index] as TextureRect
			var ingredient_slot := ingredient_icon.get_parent() as Control
			var has_requirement := item_buttons[item_index].visible and ingredient_index < item_requirements.size()
			ingredient_slot.visible = has_requirement
			if not has_requirement:
				ingredient_icon.texture = null
				ingredient_slot.tooltip_text = ""
				continue
			var requirement := Dictionary(item_requirements[ingredient_index])
			var kind := StringName(requirement.get("kind", &""))
			ingredient_icon.texture = requirement.get("texture") as Texture2D
			ingredient_slot.tooltip_text = "需要加热" if kind == &"heated" else str(requirement.get("display_name", "配料要求"))

func delivery_target(order_id: StringName, item_index: int) -> Control:
	if _order_id != order_id or item_index < 0 or item_index >= item_buttons.size():
		return null
	var target := item_buttons[item_index]
	return target if target.visible and not target.disabled else null


func _request_focus() -> void:
	if not _order_id.is_empty():
		focus_requested.emit(_order_id)


func _request_delivery(item_index: int) -> void:
	if not _order_id.is_empty():
		delivery_requested.emit(_order_id, item_index)


func _on_product_source_dropped(item_index: int, source_ref: Dictionary) -> void:
	if not _order_id.is_empty():
		product_dropped.emit(_order_id, item_index, source_ref.duplicate(true))
