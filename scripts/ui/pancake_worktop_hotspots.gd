class_name PancakeWorktopHotspots
extends Control

signal status_message(message: String)

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const SPREADER_HOLDER_EMPTY := preload("res://resources/art/workstation/tools/batter_ladle_holder_empty_v1.png")
const SPREADER_HOLDER_FILLED := preload("res://resources/art/workstation/tools/batter_spreader_holder_wide_filled_v2.png")
const PRESS_SPREADER := preload("res://resources/art/workstation/tools/pancake-press-wide-upgrade-v2-base.png")
const BATTER_LADLE_HOLDER_EMPTY := preload("res://resources/art/workstation/tools/batter_ladle_holder_empty_v1.png")
const BATTER_LADLE_HOLDER_FILLED := preload("res://resources/art/workstation/tools/batter_ladle_holder_occupied_v1.png")
const BAOCUI_EMPTY_TRAY := preload("res://resources/art/workstation/material_slots/legacy_trays/empty-square-ingredient-tray-v1.png")
const EGG_DRAG_PREVIEW := preload("res://resources/art/ingredients/egg/egg_whole_v1_five_area_v2.png")
const AUTO_BATTER_LADLE_GROWTH_ID := &"growth.automation.pancake.auto_batter_ladle"
const PRESS_SPREADER_GROWTH_ID := &"growth.automation.pancake.press_once"

const INGREDIENT_HOTSPOT_IDS: Dictionary = {
	&"HamSource/Hotspot": &"stock.pancake.ham_sausage",
	&"PorkFlossSource/Hotspot": &"stock.pancake.meat_floss",
	&"ScallionTray/Hotspot": &"stock.pancake.scallion",
	&"CorianderTray/Hotspot": &"stock.pancake.coriander",
	&"BaocuiBasket/Hotspot": &"stock.pancake.baocui",
	&"EggCarton/Hotspot": &"stock.pancake.egg",
}
const SAUCE_HOTSPOT_IDS: Dictionary = {
	&"SecretSauceSource/Hotspot": &"stock.pancake.sauce.sweet_flour",
}
## Some optional ingredients are rendered by the stall artwork rather than by
## their drag source. Keep those visuals in the same unlock state as the source
## so locked items do not leave an empty tray or sauce jar on the workbench.
const STOCK_VISUAL_PATHS: Dictionary = {
	&"stock.pancake.egg": [NodePath("EggCarton")],
	&"stock.pancake.baocui": [NodePath("BaocuiBasket")],
	&"stock.pancake.scallion": [NodePath("ScallionTray")],
	&"stock.pancake.sauce.sweet_flour": [NodePath("SecretSauceSource")],
	&"stock.pancake.ham_sausage": [NodePath("HamSource")],
	&"stock.pancake.meat_floss": [NodePath("PorkFlossSource")],
	&"stock.pancake.coriander": [NodePath("CorianderTray")],
}
## Container artwork stays in the scene while its drag source lives under the
## worktop hotspots. These paths let the workshop present a stocked catalogue
## without changing the service-day inventory.
const CONTAINER_VISUAL_PATHS := [
	NodePath("PorkFlossSource/Visual"),
	NodePath("HamSource/Visual"),
	NodePath("ScallionTray/Visual"),
	NodePath("CorianderTray/Visual"),
]
## Every source owns one layout rectangle. Its painted layers and input surface
## are children of that rectangle, so moving or resizing the source cannot leave
## a sibling hotspot behind.
const ALPHA_HIT_VISUAL_PATHS: Dictionary = {
	&"PorkFlossSource/Hotspot": [NodePath("PorkFlossSource/Visual")],
	&"HamSource/Hotspot": [NodePath("HamSource/Visual")],
	&"EggCarton/Hotspot": [NodePath("EggCarton/Visual"), NodePath("EggCarton/Visual/Contents")],
	&"ScallionTray/Hotspot": [NodePath("ScallionTray/Visual")],
	&"CorianderTray/Hotspot": [NodePath("CorianderTray/Visual")],
	&"BaocuiBasket/Hotspot": [NodePath("BaocuiBasket/Visual")],
	&"SecretSauceSource/Hotspot": [NodePath("SecretSauceSource/Visual")],
}
const EGG_STOCK_ID := &"stock.pancake.egg"
const BAOCUI_STOCK_ID := &"stock.pancake.baocui"

@export var griddle_station_path: NodePath
## Indexes map directly to egg counts. Index zero is the empty tray; all other
## entries are complete tray images rather than overlays.
@export var egg_content_textures: Array[Texture2D] = []
## Ordered from one to the maximum visible crisp count. Each texture is a
## complete ingredient tray, so inventory changes replace the tray artwork.
@export var baocui_tray_textures: Array[Texture2D] = []

var _session: Node
var _refresh_elapsed := 0.0
var _workshop_preview := false


func _ready() -> void:
	_update_egg_inventory_visual(0, int(CATALOG.stock_definition(EGG_STOCK_ID).get("restock_capacity", 10)))
	_update_baocui_inventory_visual(0)
	_update_spreader_holder_visual()
	for hotspot_name in INGREDIENT_HOTSPOT_IDS:
		_configure_material_hotspot(_material_hotspot(hotspot_name), INGREDIENT_HOTSPOT_IDS[hotspot_name], &"pancake_shared_ingredient")
	for hotspot_name in SAUCE_HOTSPOT_IDS:
		var hotspot := _material_hotspot(hotspot_name)
		_configure_material_hotspot(hotspot, SAUCE_HOTSPOT_IDS[hotspot_name], &"pancake_shared_sauce")
	var spreader_hit_button := get_node_or_null("SpreaderSource/HitButton") as BaseButton
	if spreader_hit_button != null and not spreader_hit_button.pressed.is_connected(_on_spreader_pressed):
		spreader_hit_button.pressed.connect(_on_spreader_pressed)
	var batter_ladle_hit_button := get_node_or_null("BatterLadleSource/HitButton") as BaseButton
	if batter_ladle_hit_button != null and not batter_ladle_hit_button.button_down.is_connected(_on_batter_ladle_button_down):
		batter_ladle_hit_button.button_down.connect(_on_batter_ladle_button_down)
	if batter_ladle_hit_button != null and not batter_ladle_hit_button.pressed.is_connected(_on_batter_ladle_pressed):
		batter_ladle_hit_button.pressed.connect(_on_batter_ladle_pressed)
	var station := _griddle_station()
	if station != null and station.has_signal("held_tool_changed") and not station.is_connected("held_tool_changed", _on_station_held_tool_changed):
		station.connect("held_tool_changed", _on_station_held_tool_changed)
	_update_batter_ladle_holder_visual()
	call_deferred("_sync_material_alpha_hit_regions")


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
	_set_container_preview(enabled)
	refresh_from_session()


func _process(delta: float) -> void:
	_refresh_elapsed += maxf(delta, 0.0)
	if _refresh_elapsed >= 0.20:
		var viewport := get_viewport()
		if viewport != null and viewport.gui_is_dragging():
			return
		_refresh_elapsed = 0.0
		refresh_from_session()


func _on_station_held_tool_changed(_tool_id: StringName) -> void:
	_update_spreader_holder_visual()
	_update_batter_ladle_holder_visual()
	_sync_material_alpha_hit_regions()


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
	var egg_capacity := int(CATALOG.stock_definition(EGG_STOCK_ID).get("restock_capacity", 10))
	if _session.has_method("five_area_restock_status"):
		var egg_status := Dictionary(_session.call("five_area_restock_status", EGG_STOCK_ID))
		egg_capacity = int(egg_status.get("capacity", egg_capacity))
	_update_egg_inventory_visual(int(inventory.get(str(EGG_STOCK_ID), 0)), egg_capacity)
	_update_baocui_inventory_visual(int(inventory.get(str(BAOCUI_STOCK_ID), 0)))
	_update_spreader_holder_visual()
	_update_batter_ladle_holder_visual()
	_refresh_material_hover_visuals()


func _configure_material_hotspot(hotspot: ProductDragSource, stock_id: StringName, source_kind: StringName) -> void:
	if hotspot == null:
		return
	var unlimited := bool(CATALOG.stock_definition(stock_id).get("unlimited", false))
	# A TextureButton without a texture can be returned as the hovered Control,
	# but Godot does not reliably route button presses to it. Give every authored
	# transparent hotspot a real (still invisible) texture-backed hit surface.
	var hit_texture := hotspot.texture_normal
	if hit_texture == null:
		var hit_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		hit_image.fill(Color.TRANSPARENT)
		hit_texture = ImageTexture.create_from_image(hit_image)
	hotspot.ignore_texture_size = true
	hotspot.hold_enabled = not unlimited
	# Sauce selection must win for a normal click; use a deliberate hold for
	# restocking so a slightly slow click cannot be mistaken for replenishment.
	hotspot.hold_threshold_seconds = 0.50 if source_kind == &"pancake_shared_sauce" else 0.20
	hotspot.cancel_pending_on_mouse_exit = true
	# All raw pancake ingredients share one responsive click grammar. Finished
	# products keep their existing native drag behaviour elsewhere.
	hotspot.native_drag_enabled = false
	hotspot.set_drag_preview_texture(null)
	var drag_preview_size := Vector2(72.0, 72.0)
	hotspot.set_drag_preview_size(drag_preview_size)
	# Keep the whole egg above the pointer while dragging. The visual offset does
	# not affect the release coordinate used to crack it onto the pancake.
	hotspot.set_drag_preview_offset(
		Vector2(0.0, -60.0)
		if stock_id == EGG_STOCK_ID
		else -drag_preview_size * 0.5
	)
	hotspot.mouse_filter = Control.MOUSE_FILTER_STOP
	# The authored ingredient art is a sibling of the transparent drag target.
	# Let the source restore that prop's hover after periodic inventory refreshes.
	hotspot.set_hover_visual_target(hotspot.get_parent() as CanvasItem)
	if not hotspot.short_clicked.is_connected(_on_material_short_clicked):
		hotspot.short_clicked.connect(_on_material_short_clicked.bind(hotspot))
	if not hotspot.hold_requested.is_connected(_on_material_hold_requested):
		hotspot.hold_requested.connect(_on_material_hold_requested.bind(hotspot))
	if not hotspot.hold_advanced.is_connected(_on_material_hold_advanced):
		hotspot.hold_advanced.connect(_on_material_hold_advanced.bind(hotspot))
	if not hotspot.hold_released.is_connected(_on_material_hold_released):
		hotspot.hold_released.connect(_on_material_hold_released.bind(hotspot))
	if source_kind == &"pancake_shared_ingredient":
		if not hotspot.hover_changed.is_connected(_on_material_hover_changed):
			hotspot.hover_changed.connect(_on_material_hover_changed.bind(hotspot))
	hotspot.configure({"source_kind": source_kind, "source_index": -1, "stock_id": stock_id}, hit_texture, false)


func _sync_material_alpha_hit_regions() -> void:
	for hotspot_path_variant in ALPHA_HIT_VISUAL_PATHS:
		var hotspot_path := NodePath(str(hotspot_path_variant))
		var hotspot := get_node_or_null(hotspot_path) as ProductDragSource
		if hotspot == null:
			continue
		var regions: Array[Dictionary] = []
		for layer_path_variant in Array(ALPHA_HIT_VISUAL_PATHS[hotspot_path_variant]):
			var layer := get_node_or_null(NodePath(str(layer_path_variant))) as TextureRect
			if layer == null or not layer.visible or layer.texture == null:
				continue
			regions.append({"texture": layer.texture, "rect": _painted_rect_in_hotspot(layer, hotspot)})
		hotspot.set_alpha_hit_regions(regions)


func _painted_rect_in_hotspot(layer: TextureRect, hotspot: ProductDragSource) -> Rect2:
	var hotspot_global_rect := hotspot.get_global_rect()
	var layer_global_rect := layer.get_global_rect()
	if hotspot_global_rect.size.x <= 0.0 or hotspot_global_rect.size.y <= 0.0:
		return Rect2()
	var rect := Rect2(
		(layer_global_rect.position - hotspot_global_rect.position) * hotspot.size / hotspot_global_rect.size,
		layer_global_rect.size * hotspot.size / hotspot_global_rect.size
	)
	if layer.stretch_mode not in [TextureRect.STRETCH_KEEP_ASPECT, TextureRect.STRETCH_KEEP_ASPECT_CENTERED]:
		return rect
	var texture_size := layer.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return rect
	var scale := minf(rect.size.x / texture_size.x, rect.size.y / texture_size.y)
	var painted_size := texture_size * scale
	return Rect2(rect.position + (rect.size - painted_size) * 0.5, painted_size)


func _refresh_material_hotspot(hotspot: ProductDragSource, stock_id: StringName, source_kind: StringName, inventory: Dictionary, progression: RefCounted) -> void:
	if hotspot == null:
		return
	var unlocked := progression != null and bool(progression.call("owns_stock", stock_id))
	var interactive := unlocked and not _workshop_preview
	var unlimited := bool(CATALOG.stock_definition(stock_id).get("unlimited", false))
	var count := maxi(int(inventory.get(str(stock_id), 0)), 0)
	if hotspot.has_method("set_filled_slot_count"):
		hotspot.call("set_filled_slot_count", count)
	var label := _stock_label(stock_id)
	var click_action := "点击打蛋" if stock_id == EGG_STOCK_ID else "点击加入煎饼"
	var hint := (
		"%s：%s；供应充足，无需补货" % [label, click_action]
		if unlimited
		else "%s：%s；原地长按补货" % [label, click_action]
	) if source_kind == &"pancake_shared_ingredient" else (
		"%s：点击后在鏊面拖刷" % label
		if unlimited
		else "%s：点击后在鏊面拖刷；原地长按补货" % label
	)
	if not unlocked:
		hint = "%s尚未解锁" % label
	elif count <= 0 and not unlimited:
		hint = "%s库存不足；原地长按补货" % label
	# Always reconfigure after the session state is available. The sources start
	# disabled in _ready(), so only refreshing the empty/locked branches leaves
	# an owned, stocked material unable to receive either drag or hold input.
	# Empty but unlocked materials remain clickable for the hold-to-restock
	# gesture, while dragging is available only when stock exists.
	hotspot.configure({"source_kind": source_kind, "source_index": -1, "stock_id": stock_id}, hotspot.texture_normal, interactive, hint)
	hotspot.native_drag_enabled = false
	hotspot.set_drag_available(false)
	hotspot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if interactive else Control.CURSOR_FORBIDDEN


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


func _refresh_material_hover_visuals() -> void:
	for hotspot_name in INGREDIENT_HOTSPOT_IDS:
		var hotspot := _material_hotspot(hotspot_name)
		if hotspot != null:
			hotspot.refresh_hover_visual()
	for hotspot_name in SAUCE_HOTSPOT_IDS:
		var hotspot := _material_hotspot(hotspot_name)
		if hotspot != null:
			hotspot.refresh_hover_visual()


func _set_container_preview(enabled: bool) -> void:
	for visual_path in CONTAINER_VISUAL_PATHS:
		var visual := get_node_or_null(visual_path)
		if visual != null and visual.has_method("set_workshop_preview"):
			visual.call("set_workshop_preview", enabled)


func _on_spreader_pressed() -> void:
	var station := _griddle_station()
	if station == null or not station.has_method("select_worktop_tool"):
		return
	var progression: RefCounted = _session.call("progression_service") if _session != null and _session.has_method("progression_service") else null
	var tool_id := &"tool.pancake.press_once" if progression != null and bool(progression.call("owns_growth", PRESS_SPREADER_GROWTH_ID)) else &"tool.pancake.spreader"
	var result := Dictionary(station.call("select_worktop_tool", tool_id))
	if not bool(result.get("success", false)):
		status_message.emit("当前无法使用压饼器" if tool_id == &"tool.pancake.press_once" else "当前无法使用摊饼器")
	else:
		_record_tutorial_action(&"tool_spreader")


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
	else:
		_record_tutorial_action(&"tool_ladle")
	_update_batter_ladle_holder_visual()


func _on_batter_ladle_pressed() -> void:
	if _auto_batter_ladle_owned():
		_pour_batter(CompactGriddleUnit.STANDARD_BATTER_AMOUNT, true)


func _pour_batter(batter_amount: float, used_automatic_batter_ladle: bool = false) -> void:
	var station := _griddle_station()
	if station == null or not station.has_method("take_batter_from_ladle"):
		return
	var result := Dictionary(station.call("take_batter_from_ladle", batter_amount, used_automatic_batter_ladle))
	if not bool(result.get("success", false)):
		status_message.emit("当前鏊面无法添加面糊")
	else:
		_record_tutorial_action(&"batter_added")
	_update_batter_ladle_holder_visual()


func _on_material_short_clicked(source_ref: Dictionary, hotspot: ProductDragSource) -> void:
	var stock_id := StringName(source_ref.get("stock_id", &""))
	var source_kind := StringName(source_ref.get("source_kind", &""))
	if stock_id.is_empty():
		return
	if source_kind == &"pancake_shared_ingredient":
		var station := _griddle_station()
		if station != null and station.has_method("apply_one_click_ingredient"):
			var result := Dictionary(station.call("apply_one_click_ingredient", stock_id))
			hotspot.play_result_feedback(bool(result.get("success", false)))
			if station.has_method("play_ingredient_feedback"):
				station.call("play_ingredient_feedback", bool(result.get("success", false)))
			if bool(result.get("success", false)):
				_record_tutorial_action(&"ingredient_%s" % stock_id)
			if not bool(result.get("success", false)):
				hotspot.release_focus()
			call_deferred("refresh_from_session")
			return
	var station := _griddle_station()
	if station == null or not station.has_method("select_worktop_tool"):
		return
	var result := Dictionary(station.call("select_worktop_tool", stock_id))
	if not bool(result.get("success", false)):
		hotspot.release_focus()
	else:
		_record_tutorial_action(&"tool_sauce_brush")


func _record_tutorial_action(action_id: StringName) -> void:
	if _session != null and _session.has_method("record_active_tutorial_action"):
		_session.call("record_active_tutorial_action", action_id)


func _on_material_drag_started(source_ref: Dictionary, hotspot: ProductDragSource) -> void:
	var station := _griddle_station()
	if station == null or not station.has_method("reserve_ingredient_drag"):
		hotspot.set_drag_available(false)
		return
	var result := Dictionary(station.call("reserve_ingredient_drag", source_ref))
	if not bool(result.get("success", false)):
		hotspot.set_drag_available(false)
		status_message.emit("%s库存不足，请原地长按补货" % _stock_label(StringName(source_ref.get("stock_id", &""))))
	# Reconfigure on the next idle step, after ProductDragSource has created the
	# native drag. This makes the physical tray lose a portion immediately while
	# still allowing the last reserved portion to remain under the pointer.
	call_deferred("refresh_from_session")


func _on_material_drag_ended(source_ref: Dictionary, successful: bool, _hotspot: ProductDragSource) -> void:
	var station := _griddle_station()
	if station != null and station.has_method("finish_ingredient_drag"):
		station.call("finish_ingredient_drag", source_ref, successful)
	call_deferred("refresh_from_session")


func _one_click_ingredient_enabled(stock_id: StringName) -> bool:
	var station := _griddle_station()
	return station != null and station.has_method("one_click_ingredient_enabled") and bool(station.call("one_click_ingredient_enabled", stock_id))


func _ingredient_drag_enabled(stock_id: StringName) -> bool:
	var station := _griddle_station()
	return station != null and station.has_method("ingredient_drag_enabled") and bool(station.call("ingredient_drag_enabled", stock_id))


func _on_material_hold_requested(source_ref: Dictionary, hotspot: ProductDragSource) -> void:
	if _session == null or not _session.has_method("five_area_restock_status"):
		hotspot.reject_hold()
		return
	var stock_id := StringName(source_ref.get("stock_id", &""))
	var status := Dictionary(_session.call("five_area_restock_status", stock_id))
	if bool(status.get("success", false)) and int(status.get("current_stock", 0)) < int(status.get("capacity", 0)):
		hotspot.accept_hold()
		hotspot.set_hold_progress(float(status.get("container_fill_ratio", 0.0)))
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
	hotspot.set_hold_progress(float(result.get("container_fill_ratio", 0.0)))
	if int(result.get("completed_units", 0)) > 0:
		status_message.emit("%s补货 +%d" % [_stock_label(stock_id), int(result.get("completed_units", 0))])
	if bool(result.get("auto_stopped", false)) or not bool(result.get("success", false)):
		hotspot.reject_hold()
		status_message.emit(_restock_failure_text(StringName(result.get("reason", &"")), result))
	refresh_from_session()


func _on_material_hold_released(source_ref: Dictionary, hotspot: ProductDragSource) -> void:
	if _session != null and _session.has_method("cancel_five_area_restock_hold"):
		_session.call("cancel_five_area_restock_hold", StringName(source_ref.get("stock_id", &"")))
	hotspot.set_hold_progress(0.0)
	refresh_from_session()


func _on_material_hover_changed(source_ref: Dictionary, hovering: bool, _hotspot: ProductDragSource) -> void:
	var station := _griddle_station()
	if station == null or not station.has_method("set_ingredient_target_preview"):
		return
	if not hovering:
		station.call("set_ingredient_target_preview", {}, false)
		return
	var preview := Dictionary(station.call("preview_one_click_ingredient", StringName(source_ref.get("stock_id", &""))))
	station.call("set_ingredient_target_preview", preview, true)
	if not bool(preview.get("success", false)):
		status_message.emit(str(preview.get("message", "当前不能投放该原料")))


func _material_hotspot(hotspot_name: StringName) -> ProductDragSource:
	return get_node_or_null(NodePath(str(hotspot_name))) as ProductDragSource


func _update_egg_inventory_visual(stock: int, capacity: int) -> void:
	var carton := get_node_or_null("EggCarton") as Control
	if carton == null:
		return
	var carton_base := carton.get_node_or_null("Visual") as TextureRect
	if carton_base == null:
		return
	# The v1 egg assets already include their metal tray, so replace the complete
	# visual instead of layering them over the legacy carton artwork.
	var content_visual := carton_base.get_node_or_null("Contents") as TextureRect
	var display_stock := capacity if _workshop_preview else stock
	var capped_stock := clampi(display_stock, 0, maxi(capacity, 0))
	carton_base.texture = egg_content_textures[capped_stock] if capped_stock < egg_content_textures.size() else null
	if content_visual != null:
		content_visual.texture = null
		content_visual.visible = false


func _update_baocui_inventory_visual(stock: int) -> void:
	var basket := get_node_or_null("BaocuiBasket") as Control
	if basket == null:
		return
	var visual := basket.get_node_or_null("Visual") as TextureRect
	if visual == null:
		return
	var display_stock := baocui_tray_textures.size() if _workshop_preview else stock
	var texture_index := clampi(display_stock, 0, baocui_tray_textures.size()) - 1
	visual.texture = baocui_tray_textures[texture_index] if texture_index >= 0 else BAOCUI_EMPTY_TRAY


func _update_spreader_holder_visual() -> void:
	var holder_visual := get_node_or_null("SpreaderSource/Visual") as TextureRect
	var press_visual := get_node_or_null("SpreaderSource/PressVisual") as TextureRect
	var hit_button := get_node_or_null("SpreaderSource/HitButton") as AlphaTextureHitButton
	if holder_visual == null or press_visual == null or hit_button == null:
		return
	var station := _griddle_station()
	var spreader_selected := station != null and station.has_method("is_spreader_selected") and bool(station.call("is_spreader_selected"))
	var progression: RefCounted = _session.call("progression_service") if _session != null and _session.has_method("progression_service") else null
	var press_spreader_owned := progression != null and bool(progression.call("owns_growth", PRESS_SPREADER_GROWTH_ID))
	# The workshop overlays the sole upgrade target at the press node's position.
	# Runtime play switches between the base-holder and the scene-authored press.
	var replace_with_press_preview := _workshop_preview
	var display_texture := SPREADER_HOLDER_EMPTY if spreader_selected and not _workshop_preview else SPREADER_HOLDER_FILLED
	holder_visual.texture = display_texture
	hit_button.hit_texture = PRESS_SPREADER if press_spreader_owned else display_texture
	holder_visual.modulate = Color.WHITE
	holder_visual.visible = not replace_with_press_preview and not press_spreader_owned
	press_visual.visible = not replace_with_press_preview and press_spreader_owned
	hit_button.disabled = _workshop_preview


func _update_batter_ladle_holder_visual() -> void:
	var holder_visual := get_node_or_null("BatterLadleSource/Visual") as TextureRect
	var hit_button := get_node_or_null("BatterLadleSource/HitButton") as AlphaTextureHitButton
	if holder_visual == null or hit_button == null:
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
	# Availability only controls whether the holder can be pressed. Once pouring
	# ends, the ladle is physically back in the cylinder even though the active
	# griddle remains busy with that pancake.
	var display_texture := BATTER_LADLE_HOLDER_EMPTY if ladle_selected else BATTER_LADLE_HOLDER_FILLED
	holder_visual.texture = display_texture
	hit_button.hit_texture = display_texture
	hit_button.disabled = not batter_available or _workshop_preview
	# Disabled BaseButtons still participate in GUI picking. The authored ladle
	# overlaps the sauce tray, so once batter is no longer available its inactive
	# silhouette must let pointer events reach the usable sauce beneath it.
	hit_button.mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if not hit_button.disabled
		else Control.MOUSE_FILTER_IGNORE
	)
	if not batter_available:
		hit_button.tooltip_text = "鏊面制作中"
	elif _auto_batter_ladle_owned():
		hit_button.tooltip_text = "点击加标准分量面糊"
	elif ladle_selected:
		hit_button.tooltip_text = "面糊勺已拿起；在空鏊子上按住并拖动调整落点"
	else:
		hit_button.tooltip_text = "点击拿起面糊勺，在空鏊子上按住并拖动调整落点"


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
