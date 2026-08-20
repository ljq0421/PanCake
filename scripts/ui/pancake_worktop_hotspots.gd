class_name PancakeWorktopHotspots
extends Control

signal status_message(message: String)

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const SPREADER_HOLDER_FILLED := preload("res://resources/art/workstation/tools/batter_spreader_holder_filled_v1.png")
const WIDE_SPREADER_HOLDER_FILLED := preload("res://resources/art/workstation/tools/batter_spreader_holder_wide_filled_v1.png")
const PRESS_SPREADER := preload("res://resources/art/workstation/tools/pancake-press-wide-upgrade-v1.png")
const BATTER_LADLE_HOLDER_EMPTY := preload("res://resources/art/workstation/tools/batter_ladle_holder_empty_v1.png")
const BATTER_LADLE_HOLDER_FILLED := preload("res://resources/art/workstation/tools/batter_ladle_holder_occupied_v1.png")
const WIDE_SPREADER_GROWTH_ID := &"growth.tool.pancake.wide_spreader"
const AUTO_BATTER_LADLE_GROWTH_ID := &"growth.automation.pancake.auto_batter_ladle"
const PRESS_SPREADER_GROWTH_ID := &"growth.automation.pancake.press_once"

const INGREDIENT_HOTSPOT_IDS: Dictionary = {
	&"HamTrayHotspot": &"stock.pancake.ham_sausage",
	&"PorkFlossHotspot": &"stock.pancake.meat_floss",
	&"ScallionTray/Hotspot": &"stock.pancake.scallion",
	&"CorianderTray/Hotspot": &"stock.pancake.coriander",
	&"BaocuiBasket/Hotspot": &"stock.pancake.baocui",
	&"EggCarton/Hotspot": &"stock.pancake.egg",
}
const SAUCE_HOTSPOT_IDS: Dictionary = {
	&"SweetSauceHotspot": &"stock.pancake.sauce.sweet_flour",
	&"ChiliSauceHotspot": &"stock.pancake.sauce.red_chili",
	&"TomatoSauceHotspot": &"stock.pancake.sauce.tomato",
}
## Some optional ingredients are rendered by the stall artwork rather than by
## their drag source. Keep those visuals in the same unlock state as the source
## so locked items do not leave an empty tray or sauce jar on the workbench.
const STOCK_VISUAL_PATHS: Dictionary = {
	&"stock.pancake.ham_sausage": [NodePath("../ToppingIngredientTray2")],
	&"stock.pancake.meat_floss": [NodePath("../ToppingIngredientTray"), NodePath("PorkFlossHotspot")],
	&"stock.pancake.coriander": [NodePath("CorianderTray")],
	&"stock.pancake.sauce.red_chili": [NodePath("../ChiliSauceJar"), NodePath("ChiliSauceHotspot"), NodePath("ChiliSauceHotspotHitButton")],
	&"stock.pancake.sauce.tomato": [NodePath("../TomatoSauceJar"), NodePath("TomatoSauceHotspot"), NodePath("TomatoSauceHotspotHitButton")],
}
const EGG_STOCK_ID := &"stock.pancake.egg"
const BAOCUI_STOCK_ID := &"stock.pancake.baocui"

@export var griddle_station_path: NodePath
## Indexes map directly to egg counts.  The scene starts with no content
## textures, so the new carton stays visible while the matching egg layers
## are authored.
@export var egg_content_textures: Array[Texture2D] = []
## Ordered from one to the maximum visible crisp count. The basket itself is
## the shared drag source; this array updates its separate contents layer.
@export var baocui_content_textures: Array[Texture2D] = []

var _session: Node
var _refresh_elapsed := 0.0
var _workshop_preview := false
var _spreader_hit_button: Button
var _sauce_hit_buttons := {}


func _ready() -> void:
	_update_egg_inventory_visual(0, int(CATALOG.stock_definition(EGG_STOCK_ID).get("restock_capacity", 6)))
	_update_baocui_inventory_visual(0)
	_update_spreader_holder_visual()
	for hotspot_name in INGREDIENT_HOTSPOT_IDS:
		_configure_material_hotspot(_material_hotspot(hotspot_name), INGREDIENT_HOTSPOT_IDS[hotspot_name], &"pancake_shared_ingredient")
	for hotspot_name in SAUCE_HOTSPOT_IDS:
		var hotspot := _material_hotspot(hotspot_name)
		_configure_material_hotspot(hotspot, SAUCE_HOTSPOT_IDS[hotspot_name], &"pancake_shared_sauce")
		var authored_hit_button := get_node_or_null(NodePath("%sHitButton" % str(hotspot_name))) as BaseButton
		_connect_sauce_hit_button(authored_hit_button, hotspot)
		if authored_hit_button != null:
			# The griddle is authored after this worktop and captures clicks over
			# the jar body. Its static hit target is retained for the scene, while
			# the overlay below receives the actual pointer input above the griddle.
			authored_hit_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hit_button := _ensure_sauce_hit_button(hotspot)
		_connect_sauce_hit_button(hit_button, hotspot)
	var spreader := get_node_or_null("SpreaderHotspot") as TextureButton
	_ensure_texture_button_hit_surface(spreader)
	var spreader_hit_button := _ensure_spreader_hit_button(spreader)
	if spreader_hit_button != null and not spreader_hit_button.pressed.is_connected(_on_spreader_pressed):
		spreader_hit_button.pressed.connect(_on_spreader_pressed)
	var batter_ladle := get_node_or_null("BatterLadleHolderHotspot") as TextureButton
	_ensure_texture_button_hit_surface(batter_ladle)
	if batter_ladle != null and not batter_ladle.button_down.is_connected(_on_batter_ladle_button_down):
		batter_ladle.button_down.connect(_on_batter_ladle_button_down)
	if batter_ladle != null and not batter_ladle.pressed.is_connected(_on_batter_ladle_pressed):
		batter_ladle.pressed.connect(_on_batter_ladle_pressed)
	var station := _griddle_station()
	if station != null and station.has_signal("held_tool_changed") and not station.is_connected("held_tool_changed", _on_station_held_tool_changed):
		station.connect("held_tool_changed", _on_station_held_tool_changed)
	_update_batter_ladle_holder_visual()


func bind_session(session: Node) -> void:
	_session = session
	refresh_from_session()


func set_workshop_preview(enabled: bool) -> void:
	_workshop_preview = enabled
	mouse_behavior_recursive = (
		Control.MOUSE_BEHAVIOR_DISABLED
		if enabled
		else Control.MOUSE_BEHAVIOR_INHERITED
	)
	refresh_from_session()


func _process(delta: float) -> void:
	_refresh_elapsed += maxf(delta, 0.0)
	if _refresh_elapsed >= 0.20:
		_refresh_elapsed = 0.0
		refresh_from_session()


func _on_station_held_tool_changed(_tool_id: StringName) -> void:
	_update_spreader_holder_visual()
	_update_batter_ladle_holder_visual()


func refresh_from_session() -> void:
	if _session == null or not _session.has_method("inventory_snapshot"):
		return
	var inventory := Dictionary(_session.call("inventory_snapshot"))
	var progression: RefCounted = _session.call("progression_service") if _session.has_method("progression_service") else null
	for hotspot_name in INGREDIENT_HOTSPOT_IDS:
		_refresh_material_hotspot(_material_hotspot(hotspot_name), INGREDIENT_HOTSPOT_IDS[hotspot_name], &"pancake_shared_ingredient", inventory, progression)
	for hotspot_name in SAUCE_HOTSPOT_IDS:
		_refresh_material_hotspot(_material_hotspot(hotspot_name), SAUCE_HOTSPOT_IDS[hotspot_name], &"pancake_shared_sauce", inventory, progression)
	_refresh_optional_stock_visuals(progression)
	var egg_capacity := int(CATALOG.stock_definition(EGG_STOCK_ID).get("restock_capacity", 6))
	if _session.has_method("five_area_restock_status"):
		var egg_status := Dictionary(_session.call("five_area_restock_status", EGG_STOCK_ID))
		egg_capacity = int(egg_status.get("capacity", egg_capacity))
	_update_egg_inventory_visual(int(inventory.get(str(EGG_STOCK_ID), 0)), egg_capacity)
	_update_baocui_inventory_visual(int(inventory.get(str(BAOCUI_STOCK_ID), 0)))
	_update_spreader_holder_visual()
	_update_batter_ladle_holder_visual()


func _configure_material_hotspot(hotspot: ProductDragSource, stock_id: StringName, source_kind: StringName) -> void:
	if hotspot == null:
		return
	# A TextureButton without a texture can be returned as the hovered Control,
	# but Godot does not reliably route button presses to it. Give every authored
	# transparent hotspot a real (still invisible) texture-backed hit surface.
	var hit_texture := hotspot.texture_normal
	if hit_texture == null:
		var hit_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		hit_image.fill(Color.TRANSPARENT)
		hit_texture = ImageTexture.create_from_image(hit_image)
	hotspot.ignore_texture_size = true
	hotspot.hold_enabled = true
	# Sauce selection must win for a normal click; use a deliberate hold for
	# restocking so a slightly slow click cannot be mistaken for replenishment.
	hotspot.hold_threshold_seconds = 0.50 if source_kind == &"pancake_shared_sauce" else 0.20
	hotspot.cancel_pending_on_mouse_exit = false
	hotspot.native_drag_enabled = source_kind == &"pancake_shared_ingredient"
	# Sauce jars use a sibling AlphaTextureHitButton so their transparent image
	# margins never select a sauce. The backing source only owns the gesture
	# state machine and must not receive pointer events through those margins.
	hotspot.mouse_filter = Control.MOUSE_FILTER_IGNORE if source_kind == &"pancake_shared_sauce" else Control.MOUSE_FILTER_STOP
	if not hotspot.short_clicked.is_connected(_on_material_short_clicked):
		hotspot.short_clicked.connect(_on_material_short_clicked.bind(hotspot))
	if not hotspot.hold_requested.is_connected(_on_material_hold_requested):
		hotspot.hold_requested.connect(_on_material_hold_requested.bind(hotspot))
	if not hotspot.hold_advanced.is_connected(_on_material_hold_advanced):
		hotspot.hold_advanced.connect(_on_material_hold_advanced.bind(hotspot))
	if not hotspot.hold_released.is_connected(_on_material_hold_released):
		hotspot.hold_released.connect(_on_material_hold_released.bind(hotspot))
	hotspot.configure({"source_kind": source_kind, "source_index": -1, "stock_id": stock_id}, hit_texture, false)


func _ensure_texture_button_hit_surface(button: TextureButton) -> void:
	if button == null or button.texture_normal != null:
		return
	# TextureButtons without a texture can display the art below them, but may
	# not receive pointer events. Keep the button visually transparent while
	# giving the press its own reliable hit surface.
	var hit_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	hit_image.fill(Color.TRANSPARENT)
	var hit_texture := ImageTexture.create_from_image(hit_image)
	button.ignore_texture_size = true
	button.texture_normal = hit_texture
	button.texture_hover = hit_texture
	button.texture_pressed = hit_texture


func _ensure_spreader_hit_button(spreader: TextureButton) -> Button:
	if spreader == null:
		return null
	var hit_button := _spreader_hit_button
	if hit_button == null:
		var host := _spreader_hit_host()
		hit_button = host.get_node_or_null("SpreaderHotspotHitButton") as Button
	if hit_button == null:
		hit_button = Button.new()
		hit_button.name = &"SpreaderHotspotHitButton"
		hit_button.focus_mode = Control.FOCUS_NONE
		hit_button.flat = true
		hit_button.tooltip_text = "压饼器：倒入面糊后点击一次，形成标准饼皮"
		_spreader_hit_host().add_child(hit_button)
	_spreader_hit_button = hit_button
	var spreader_rect := spreader.get_global_rect()
	var hit_host := hit_button.get_parent() as Control
	if hit_host != null:
		hit_button.position = hit_host.get_global_transform_with_canvas().affine_inverse() * spreader_rect.position
		hit_button.size = spreader_rect.size
	hit_button.z_index = 200
	hit_button.mouse_filter = Control.MOUSE_FILTER_STOP
	return hit_button


func _spreader_hit_host() -> Control:
	# FiveAreaInfrastructure is authored after SafeArea, so this overlay lives
	# above the griddle control that otherwise captures clicks in the tool slot.
	var infrastructure := get_node_or_null("../../../FiveAreaInfrastructure") as Control
	return infrastructure if infrastructure != null else self


func _ensure_sauce_hit_button(hotspot: ProductDragSource) -> Button:
	if hotspot == null:
		return null
	var hotspot_key := StringName(hotspot.name)
	var hit_button := _sauce_hit_buttons.get(hotspot_key) as Button
	var hit_host := _spreader_hit_host()
	if hit_button == null:
		hit_button = hit_host.get_node_or_null(NodePath("%sOverlayHitButton" % hotspot.name)) as Button
	if hit_button == null:
		hit_button = Button.new()
		hit_button.name = "%sOverlayHitButton" % hotspot.name
		hit_button.focus_mode = Control.FOCUS_NONE
		hit_button.flat = true
		hit_host.add_child(hit_button)
	_sauce_hit_buttons[hotspot_key] = hit_button
	var hotspot_rect := hotspot.get_global_rect()
	hit_button.position = hit_host.get_global_transform_with_canvas().affine_inverse() * hotspot_rect.position
	hit_button.size = hotspot_rect.size
	hit_button.z_index = 201
	hit_button.mouse_filter = Control.MOUSE_FILTER_STOP
	return hit_button


func _connect_sauce_hit_button(hit_button: BaseButton, hotspot: ProductDragSource) -> void:
	if hit_button == null or hotspot == null:
		return
	if not hit_button.button_down.is_connected(_on_sauce_hit_button_down):
		hit_button.button_down.connect(_on_sauce_hit_button_down.bind(hotspot))
	if not hit_button.button_up.is_connected(_on_sauce_hit_button_up):
		hit_button.button_up.connect(_on_sauce_hit_button_up.bind(hotspot))


func _refresh_material_hotspot(hotspot: ProductDragSource, stock_id: StringName, source_kind: StringName, inventory: Dictionary, progression: RefCounted) -> void:
	if hotspot == null:
		return
	var unlocked := progression != null and bool(progression.call("owns_stock", stock_id))
	var interactive := unlocked and not _workshop_preview
	var count := maxi(int(inventory.get(str(stock_id), 0)), 0)
	if hotspot.has_method("set_filled_slot_count"):
		hotspot.call("set_filled_slot_count", count)
	var label := _stock_label(stock_id)
	var hint := "%s：拖到鏊面；原地长按补货" % label if source_kind == &"pancake_shared_ingredient" else "%s：点击后在鏊面拖刷；原地长按补货" % label
	if not unlocked:
		hint = "%s尚未解锁" % label
	elif count <= 0:
		hint = "%s库存不足；原地长按补货" % label
	# Always reconfigure after the session state is available. The sources start
	# disabled in _ready(), so only refreshing the empty/locked branches leaves
	# an owned, stocked material unable to receive either drag or hold input.
	# Empty but unlocked materials remain clickable for the hold-to-restock
	# gesture, while dragging is available only when stock exists.
	hotspot.configure({"source_kind": source_kind, "source_index": -1, "stock_id": stock_id}, hotspot.texture_normal, interactive, hint)
	hotspot.set_drag_available(interactive and count > 0 and source_kind == &"pancake_shared_ingredient")
	hotspot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if interactive else Control.CURSOR_FORBIDDEN
	if source_kind == &"pancake_shared_sauce":
		# Keep the authored and foreground overlay buttons in sync. The overlay
		# sits above the griddle input surface so the complete jar remains usable.
		var authored_hit_button := get_node_or_null(NodePath("%sHitButton" % hotspot.name)) as BaseButton
		var overlay_hit_button := _ensure_sauce_hit_button(hotspot)
		for hit_button in [authored_hit_button, overlay_hit_button]:
			if hit_button == null:
				continue
			hit_button.disabled = not interactive
			hit_button.tooltip_text = hint
			hit_button.mouse_default_cursor_shape = hotspot.mouse_default_cursor_shape


func _refresh_optional_stock_visuals(progression: RefCounted) -> void:
	for stock_id_variant in STOCK_VISUAL_PATHS:
		var stock_id := StringName(stock_id_variant)
		var unlocked := progression != null and bool(progression.call("owns_stock", stock_id))
		var visible_in_preview := unlocked or _workshop_preview
		for visual_path_variant in Array(STOCK_VISUAL_PATHS[stock_id_variant]):
			var visual := get_node_or_null(visual_path_variant) as Control
			if visual == null:
				continue
			visual.visible = visible_in_preview
			visual.modulate = Color(1.0, 1.0, 1.0, 0.42) if _workshop_preview and not unlocked else Color.WHITE
			visual.mouse_behavior_recursive = (
				Control.MOUSE_BEHAVIOR_INHERITED
				if unlocked and not _workshop_preview
				else Control.MOUSE_BEHAVIOR_DISABLED
			)


func _on_spreader_pressed() -> void:
	var station := _griddle_station()
	if station == null or not station.has_method("select_worktop_tool"):
		return
	var progression: RefCounted = _session.call("progression_service") if _session != null and _session.has_method("progression_service") else null
	var tool_id := &"tool.pancake.press_once" if progression != null and bool(progression.call("owns_growth", PRESS_SPREADER_GROWTH_ID)) else &"tool.pancake.spreader"
	var result := Dictionary(station.call("select_worktop_tool", tool_id))
	if not bool(result.get("success", false)):
		status_message.emit("当前无法使用压饼器" if tool_id == &"tool.pancake.press_once" else "当前无法使用摊饼器")


func _on_batter_ladle_button_down() -> void:
	var station := _griddle_station()
	if station == null:
		return
	if _auto_batter_ladle_owned():
		return
	if not station.has_method("select_worktop_tool"):
		return
	var result := Dictionary(station.call("select_worktop_tool", &"tool.pancake.ladle"))
	if not bool(result.get("success", false)):
		status_message.emit("当前鏊面无法添加面糊")
	_update_batter_ladle_holder_visual()


func _on_batter_ladle_pressed() -> void:
	if _auto_batter_ladle_owned():
		_pour_batter(CompactGriddleUnit.STANDARD_BATTER_AMOUNT)


func _pour_batter(batter_amount: float) -> void:
	var station := _griddle_station()
	if station == null or not station.has_method("take_batter_from_ladle"):
		return
	var result := Dictionary(station.call("take_batter_from_ladle", batter_amount))
	if not bool(result.get("success", false)):
		status_message.emit("当前鏊面无法添加面糊")
	_update_batter_ladle_holder_visual()


func _on_sauce_hit_button_down(hotspot: ProductDragSource) -> void:
	# A plain transparent Button provides a stable native pointer target while
	# ProductDragSource retains the existing click/hold/restock state machine.
	hotspot.begin_gesture(hotspot.get_global_rect().get_center())


func _on_sauce_hit_button_up(hotspot: ProductDragSource) -> void:
	hotspot.end_gesture()


func _on_material_short_clicked(source_ref: Dictionary, hotspot: ProductDragSource) -> void:
	var stock_id := StringName(source_ref.get("stock_id", &""))
	var source_kind := StringName(source_ref.get("source_kind", &""))
	if stock_id.is_empty():
		return
	if source_kind == &"pancake_shared_ingredient":
		status_message.emit("拖动%s到鏊面；原地长按可补货" % _stock_label(stock_id))
		return
	var station := _griddle_station()
	if station == null or not station.has_method("select_worktop_tool"):
		return
	var result := Dictionary(station.call("select_worktop_tool", stock_id))
	if not bool(result.get("success", false)):
		hotspot.release_focus()


func _on_material_hold_requested(source_ref: Dictionary, hotspot: ProductDragSource) -> void:
	if _session == null or not _session.has_method("five_area_restock_status"):
		hotspot.reject_hold()
		return
	var stock_id := StringName(source_ref.get("stock_id", &""))
	var status := Dictionary(_session.call("five_area_restock_status", stock_id))
	if bool(status.get("success", false)) and int(status.get("current_stock", 0)) < int(status.get("capacity", 0)):
		hotspot.accept_hold()
		status_message.emit("持续按住补%s；每完成一份才扣金币" % _stock_label(stock_id))
		return
	hotspot.reject_hold()
	status_message.emit(_restock_failure_text(StringName(status.get("reason", &"")), status))


func _on_material_hold_advanced(source_ref: Dictionary, delta: float, hotspot: ProductDragSource) -> void:
	if _session == null or not _session.has_method("advance_five_area_restock_hold"):
		hotspot.reject_hold()
		return
	var stock_id := StringName(source_ref.get("stock_id", &""))
	var result := Dictionary(_session.call("advance_five_area_restock_hold", stock_id, delta))
	if int(result.get("completed_units", 0)) > 0:
		status_message.emit("%s补货 +%d" % [_stock_label(stock_id), int(result.get("completed_units", 0))])
	if bool(result.get("auto_stopped", false)) or not bool(result.get("success", false)):
		hotspot.reject_hold()
		status_message.emit(_restock_failure_text(StringName(result.get("reason", &"")), result))
	refresh_from_session()


func _on_material_hold_released(_source_ref: Dictionary, _hotspot: ProductDragSource) -> void:
	refresh_from_session()


func _material_hotspot(hotspot_name: StringName) -> ProductDragSource:
	return get_node_or_null(NodePath(str(hotspot_name))) as ProductDragSource


func _update_egg_inventory_visual(stock: int, capacity: int) -> void:
	var carton := get_node_or_null("EggCarton") as Control
	if carton == null:
		return
	var carton_base := carton.get_node_or_null("Visual") as TextureRect
	if carton_base == null:
		return
	# The carton owns its optional content layer. Only that child changes with
	# stock, so the old woven-basket states can never reappear.
	var content_visual := carton_base.get_node_or_null("Contents") as TextureRect
	if content_visual == null:
		return
	var capped_stock := clampi(stock, 0, maxi(capacity, 0))
	content_visual.texture = egg_content_textures[capped_stock] if capped_stock < egg_content_textures.size() else null


func _update_baocui_inventory_visual(stock: int) -> void:
	var basket := get_node_or_null("BaocuiBasket") as Control
	if basket == null:
		return
	var contents := basket.get_node_or_null("Contents") as TextureRect
	if contents == null:
		return
	var texture_index := clampi(stock, 0, baocui_content_textures.size()) - 1
	contents.texture = baocui_content_textures[texture_index] if texture_index >= 0 else null
	contents.visible = texture_index >= 0


func _update_spreader_holder_visual() -> void:
	var holder_empty := get_node_or_null("SpreaderHolderEmptyVisual") as CanvasItem
	var holder_filled := get_node_or_null("SpreaderHolderFilledVisual") as TextureRect
	if holder_empty == null or holder_filled == null:
		return
	var station := _griddle_station()
	var spreader_selected := station != null and station.has_method("is_spreader_selected") and bool(station.call("is_spreader_selected"))
	var progression: RefCounted = _session.call("progression_service") if _session != null and _session.has_method("progression_service") else null
	var wide_spreader_owned := progression != null and bool(progression.call("owns_growth", WIDE_SPREADER_GROWTH_ID))
	var press_spreader_owned := progression != null and bool(progression.call("owns_growth", PRESS_SPREADER_GROWTH_ID))
	var show_wide_preview := _workshop_preview and not wide_spreader_owned
	# Once the wide spreader is owned, the workshop uses the same artwork slot
	# for the press-spreader preview. Keep the runtime holder out of that slot;
	# the overlay supplies the translucent (locked) or opaque (owned) press.
	var replace_with_press_preview := _workshop_preview and wide_spreader_owned
	holder_filled.texture = (
		PRESS_SPREADER
		if press_spreader_owned and not _workshop_preview
		else WIDE_SPREADER_HOLDER_FILLED
		if wide_spreader_owned or _workshop_preview
		else SPREADER_HOLDER_FILLED
	)
	holder_filled.modulate = Color(1.0, 1.0, 1.0, 0.42) if show_wide_preview else Color.WHITE
	# The workshop must consistently show the upgrade target instead of the
	# runtime's temporarily selected/empty holder state.
	holder_empty.visible = spreader_selected and not _workshop_preview and not press_spreader_owned
	holder_filled.visible = (not spreader_selected or _workshop_preview or press_spreader_owned) and not replace_with_press_preview


func _update_batter_ladle_holder_visual() -> void:
	var holder := get_node_or_null("BatterLadleHolderHotspot") as TextureButton
	if holder == null:
		return
	var station := _griddle_station()
	# Keep the authored filled sprite through scene construction. The griddle's
	# @onready unit list is populated a little later than this worktop artwork.
	if station == null or not station.is_node_ready():
		return
	var batter_available := (
		station.has_method("can_take_batter_from_ladle")
		and bool(station.call("can_take_batter_from_ladle"))
	)
	var ladle_selected := station.has_method("is_batter_ladle_selected") and bool(station.call("is_batter_ladle_selected"))
	holder.texture_normal = BATTER_LADLE_HOLDER_EMPTY if ladle_selected or not batter_available else BATTER_LADLE_HOLDER_FILLED
	holder.texture_hover = holder.texture_normal
	holder.texture_pressed = holder.texture_normal
	holder.disabled = not batter_available or _workshop_preview
	if not batter_available:
		holder.tooltip_text = "鏊面制作中"
	elif _auto_batter_ladle_owned():
		holder.tooltip_text = "点击加标准分量面糊"
	elif ladle_selected:
		holder.tooltip_text = "按住面糊勺拖到空鏊子；松开即停止"
	else:
		holder.tooltip_text = "按住面糊勺拖到空鏊子倒入"


func _auto_batter_ladle_owned() -> bool:
	var progression: RefCounted = _session.call("progression_service") if _session != null and _session.has_method("progression_service") else null
	return progression != null and bool(progression.call("owns_growth", AUTO_BATTER_LADLE_GROWTH_ID))


func _griddle_station() -> Node:
	return get_node_or_null(griddle_station_path)


static func _stock_label(stock_id: StringName) -> String:
	var label := str(CATALOG.stock_definition(stock_id).get("label", ""))
	return label if not label.is_empty() else str(stock_id)


static func _restock_failure_text(reason: StringName, status: Dictionary) -> String:
	match reason:
		&"stock_locked": return "该材料尚未解锁"
		&"capacity_reached": return "材料库存已满"
		&"insufficient_coins": return "余额不足：每份需要%d金币" % int(status.get("unit_cost", 0))
	return "当前无法补货"
