class_name CustomerServiceSlot
extends Control

const PATIENCE_BAR_STYLE := preload("res://scripts/ui/patience_bar_style.gd")
const CARD_SCALE := 1.5
const CARD_HEADER_HEIGHT := 42.0
const CARD_FOOTER_HEIGHT := 36.0
const CARD_CONTENT_INSET := 9.0
const CARD_BLOCK_GAP := 6.0
const CARD_BLOCK_HEIGHT := 90.0
const PANCAKE_INGREDIENT_COLUMNS := 4
const NORMAL_PRODUCTS_PER_ROW := 3
const NORMAL_PRODUCT_SIZE := Vector2(81.9, 81.9)
const PANCAKE_PRODUCT_SIZE := Vector2(78.0, 78.0)
const NORMAL_INGREDIENT_SIZE := Vector2(25.2, 25.2)
const PANCAKE_INGREDIENT_SIZE := Vector2(42.0, 42.0)
const NORMAL_REQUIREMENT_LIMIT := 2
const PATIENCE_FILL_POSITION_X := 64.5
const PATIENCE_FILL_BOTTOM_INSET := 25.5
const PATIENCE_FILL_SIZE := Vector2(187.5, 13.5)
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
signal focus_requested(order_id: StringName)
signal delivery_requested(order_id: StringName, item_index: int)
signal product_dropped(order_id: StringName, item_index: int, source_ref: Dictionary)

@onready var portrait: TextureRect = %Portrait
@onready var order_panel: Control = $OrderPanel
@onready var card_background: OrderCardBackground = %CardBackground
@onready var card_focus_button: Button = %CardFocusButton
@onready var header_title: Label = %HeaderTitle
@onready var order_title: Label = %OrderTitle
@onready var special_title: Label = %SpecialTitle
@onready var special_rule: Label = %SpecialRule
@onready var progress_title: Label = %ProgressTitle
@onready var patience_bar: ProgressBar = %PatienceBar

var item_buttons: Array[Button] = []
var item_icons: Array[TextureRect] = []
var quantity_labels: Array[Label] = []

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
	_register_authored_item_controls()
	_ensure_item_control_count(item_buttons.size())
	card_focus_button.pressed.connect(_request_focus)
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
	_ensure_item_control_count(items.size())
	_apply_card_layout(items, requirements_by_item)
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
	# An order card belongs to the customer currently being served.  Hide it as
	# soon as that customer starts leaving so a completed or expired order never
	# appears to remain available at an empty service position.
	order_panel.visible = false
	_cancel_presentation_tween()
	_presentation_tween = create_tween()
	_presentation_tween.set_parallel(true)
	if reduce_motion:
		portrait.position = _portrait_rest_position
		order_panel.position = _order_panel_rest_position
		_presentation_tween.tween_property(portrait, "modulate:a", 0.0, REDUCED_PORTRAIT_SECONDS).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
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


func _register_authored_item_controls() -> void:
	for item_index in 3:
		var button := get_node("OrderPanel/ItemButton%d" % (item_index + 1)) as Button
		var icon := button.get_node("ItemIcon%d" % (item_index + 1)) as TextureRect
		var quantity := button.get_node("Quantity%d" % (item_index + 1)) as Label
		_register_item_control(button, icon, quantity, item_index)
	card_background.visible = true


func _ensure_item_control_count(count: int) -> void:
	while item_buttons.size() < count:
		var item_index := item_buttons.size()
		var button := OrderItemDropButton.new()
		button.name = "ItemButton%d" % (item_index + 1)
		button.item_index = item_index
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.flat = true
		button.z_index = 2
		var icon := TextureRect.new()
		icon.name = "ItemIcon%d" % (item_index + 1)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		button.add_child(icon)
		var quantity := Label.new()
		quantity.name = "Quantity%d" % (item_index + 1)
		quantity.visible = false
		quantity.mouse_filter = Control.MOUSE_FILTER_IGNORE
		quantity.add_theme_color_override("font_color", Color("fff0bd"))
		quantity.add_theme_color_override("font_outline_color", Color("2e1005"))
		quantity.add_theme_constant_override("outline_size", 3)
		quantity.add_theme_font_size_override("font_size", 15)
		quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		button.add_child(quantity)
		order_panel.add_child(button)
		_register_item_control(button, icon, quantity, item_index)


func _register_item_control(button: Button, icon: TextureRect, quantity: Label, item_index: int) -> void:
	if button is OrderItemDropButton:
		(button as OrderItemDropButton).item_index = item_index
	button.z_index = 2
	button.pressed.connect(_request_delivery.bind(item_index))
	if button.has_signal("product_source_dropped"):
		button.connect("product_source_dropped", _on_product_source_dropped)
	item_buttons.append(button)
	item_icons.append(icon)
	quantity_labels.append(quantity)
	_ingredient_icons_by_item.append([])
	_ensure_ingredient_slot_count(item_index, 8)


func _ensure_ingredient_slot_count(item_index: int, count: int) -> void:
	var ingredient_icons: Array = _ingredient_icons_by_item[item_index]
	while ingredient_icons.size() < count:
		var ingredient_index := ingredient_icons.size()
		var ingredient_slot := Control.new()
		ingredient_slot.name = "IngredientSlot%d_%d" % [item_index + 1, ingredient_index + 1]
		ingredient_slot.z_index = 3
		ingredient_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ingredient_icon := TextureRect.new()
		ingredient_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ingredient_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 0)
		ingredient_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ingredient_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ingredient_slot.add_child(ingredient_icon)
		order_panel.add_child(ingredient_slot)
		ingredient_icons.append(ingredient_icon)
	_ingredient_icons_by_item[item_index] = ingredient_icons


func _apply_card_layout(items: Array, requirements_by_item: Array) -> void:
	var normal_indexes: Array[int] = []
	var pancake_indexes: Array[int] = []
	for item_index in items.size():
		var item := Dictionary(items[item_index])
		if _is_pancake_item(item):
			pancake_indexes.append(item_index)
		else:
			normal_indexes.append(item_index)
	var blocks: Array[Dictionary] = []
	var row_top := CARD_HEADER_HEIGHT + CARD_CONTENT_INSET
	for normal_start in range(0, normal_indexes.size(), NORMAL_PRODUCTS_PER_ROW):
		var indexes: Array[int] = normal_indexes.slice(normal_start, normal_start + NORMAL_PRODUCTS_PER_ROW)
		blocks.append({"top": row_top, "height": CARD_BLOCK_HEIGHT})
		for position_in_row in indexes.size():
			_layout_normal_item(indexes[position_in_row], position_in_row, row_top, Array(requirements_by_item[indexes[position_in_row]]) if indexes[position_in_row] < requirements_by_item.size() else [])
		row_top += CARD_BLOCK_HEIGHT + CARD_BLOCK_GAP
	for item_index in pancake_indexes:
		var requirements: Array = Array(requirements_by_item[item_index]) if item_index < requirements_by_item.size() else []
		var pancake_height := maxf(CARD_BLOCK_HEIGHT, 13.0 + 41.0 * ceil(float(requirements.size()) / float(PANCAKE_INGREDIENT_COLUMNS)))
		blocks.append({"top": row_top, "height": pancake_height})
		_layout_pancake_item(item_index, row_top, requirements)
		row_top += pancake_height + CARD_BLOCK_GAP
	if special_rule.visible:
		blocks.append({"top": row_top, "height": 30.0})
		special_rule.position = Vector2(15.0, row_top + 3.0)
		special_rule.size = Vector2(card_width - 30.0, 24.0)
		row_top += 30.0 + CARD_BLOCK_GAP
	var card_height := CARD_HEADER_HEIGHT + CARD_CONTENT_INSET + CARD_FOOTER_HEIGHT if blocks.is_empty() else row_top + CARD_CONTENT_INSET + CARD_FOOTER_HEIGHT - CARD_BLOCK_GAP
	order_panel.size = Vector2(card_width, card_height)
	card_background.set_card_layout(blocks)
	header_title.visible = not special_title.visible
	order_title.position = Vector2(card_width - 72.0, 7.5)
	order_title.size = Vector2(60.0, 27.0)
	special_title.position = Vector2(12.0, 7.5)
	special_title.size = Vector2(card_width - 90.0, 27.0)
	progress_title.position = Vector2(12.0, card_height - 30.0)
	progress_title.size = Vector2(51.0, 21.0)
	patience_bar.position = Vector2(PATIENCE_FILL_POSITION_X, card_height - PATIENCE_FILL_BOTTOM_INSET)
	patience_bar.size = PATIENCE_FILL_SIZE


func _is_pancake_item(item: Dictionary) -> bool:
	return StringName(item.get("area_id", &"")) == &"area.pancake" or StringName(item.get("product_id", &"")) == &"product.pancake.custom"


func _layout_normal_item(item_index: int, position_in_row: int, block_top: float, requirements: Array) -> void:
	var button := item_buttons[item_index]
	button.position = Vector2(17.1 + position_in_row * 82.5, block_top + 4.05)
	button.size = NORMAL_PRODUCT_SIZE
	quantity_labels[item_index].position = Vector2(27.3, 50.4)
	quantity_labels[item_index].size = Vector2(54.6, 27.3)
	var badge_origin := button.position + Vector2(56.7, 36.0) if requirements.size() <= 1 else button.position + Vector2(42.0, 36.0)
	_layout_ingredient_slots(item_index, requirements, NORMAL_REQUIREMENT_LIMIT, badge_origin, NORMAL_INGREDIENT_SIZE, Vector2(14.7, 8.0), false)


func _layout_pancake_item(item_index: int, block_top: float, requirements: Array) -> void:
	var button := item_buttons[item_index]
	button.position = Vector2(9.0, block_top + 6.0)
	button.size = PANCAKE_PRODUCT_SIZE
	quantity_labels[item_index].position = Vector2(24.0, 48.75)
	quantity_labels[item_index].size = Vector2(54.6, 27.3)
	_layout_ingredient_slots(item_index, requirements, requirements.size(), Vector2(88.0, block_top + 12.0), PANCAKE_INGREDIENT_SIZE, Vector2(41.0, 41.0), true)


func _layout_ingredient_slots(item_index: int, requirements: Array, visible_count: int, origin: Vector2, icon_size: Vector2, spacing: Vector2, grid: bool) -> void:
	_ensure_ingredient_slot_count(item_index, requirements.size())
	var ingredient_icons: Array = _ingredient_icons_by_item[item_index]
	for ingredient_index in ingredient_icons.size():
		var ingredient_icon := ingredient_icons[ingredient_index] as TextureRect
		var ingredient_slot := ingredient_icon.get_parent() as Control
		var is_visible := ingredient_index < visible_count and ingredient_index < requirements.size()
		ingredient_slot.visible = is_visible
		if not is_visible:
			continue
		var column := ingredient_index % PANCAKE_INGREDIENT_COLUMNS if grid else ingredient_index
		var row := ingredient_index / PANCAKE_INGREDIENT_COLUMNS if grid else ingredient_index
		ingredient_slot.position = origin + Vector2(column * spacing.x, row * spacing.y)
		ingredient_slot.size = icon_size


func _bind_requirements_by_item(requirements_by_item: Array) -> void:
	for item_index in range(_ingredient_icons_by_item.size()):
		var item_requirements: Array = Array(requirements_by_item[item_index]) if item_index < requirements_by_item.size() else []
		_ensure_ingredient_slot_count(item_index, item_requirements.size())
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
