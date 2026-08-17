class_name PancakeWorktopHotspots
extends Control

signal status_message(message: String)

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")

const INGREDIENT_HOTSPOT_IDS: Dictionary = {
	&"ScallionHotspot": &"stock.pancake.scallion",
	&"CorianderHotspot": &"stock.pancake.coriander",
	&"BaocuiHotspot": &"stock.pancake.baocui",
	&"EggHotspot": &"stock.pancake.egg",
}
const SAUCE_HOTSPOT_IDS: Dictionary = {
	&"SweetSauceHotspot": &"stock.pancake.sauce.sweet_flour",
	&"ChiliSauceHotspot": &"stock.pancake.sauce.red_chili",
}
const EGG_STOCK_ID := &"stock.pancake.egg"

@export var griddle_station_path: NodePath
## Indexes map directly to egg counts.  The scene starts with no content
## textures, so the new carton stays visible while the matching egg layers
## are authored.
@export var egg_content_textures: Array[Texture2D] = []

var _session: Node
var _refresh_elapsed := 0.0


func _ready() -> void:
	_update_egg_inventory_visual(0, int(CATALOG.stock_definition(EGG_STOCK_ID).get("restock_capacity", 6)))
	_update_spreader_holder_visual()
	for hotspot_name in INGREDIENT_HOTSPOT_IDS:
		_configure_material_hotspot(_material_hotspot(hotspot_name), INGREDIENT_HOTSPOT_IDS[hotspot_name], &"pancake_shared_ingredient")
	for hotspot_name in SAUCE_HOTSPOT_IDS:
		var hotspot := _material_hotspot(hotspot_name)
		_configure_material_hotspot(hotspot, SAUCE_HOTSPOT_IDS[hotspot_name], &"pancake_shared_sauce")
		var hit_button := get_node_or_null(NodePath("%sHitButton" % str(hotspot_name))) as BaseButton
		if hit_button != null:
			if not hit_button.button_down.is_connected(_on_sauce_hit_button_down):
				hit_button.button_down.connect(_on_sauce_hit_button_down.bind(hotspot))
			if not hit_button.button_up.is_connected(_on_sauce_hit_button_up):
				hit_button.button_up.connect(_on_sauce_hit_button_up.bind(hotspot))
	var spreader := get_node_or_null("SpreaderHotspot") as BaseButton
	if spreader != null and not spreader.pressed.is_connected(_on_spreader_pressed):
		spreader.pressed.connect(_on_spreader_pressed)


func bind_session(session: Node) -> void:
	_session = session
	refresh_from_session()


func _process(delta: float) -> void:
	_refresh_elapsed += maxf(delta, 0.0)
	if _refresh_elapsed >= 0.20:
		_refresh_elapsed = 0.0
		refresh_from_session()


func refresh_from_session() -> void:
	if _session == null or not _session.has_method("inventory_snapshot"):
		return
	var inventory := Dictionary(_session.call("inventory_snapshot"))
	var progression: RefCounted = _session.call("progression_service") if _session.has_method("progression_service") else null
	for hotspot_name in INGREDIENT_HOTSPOT_IDS:
		_refresh_material_hotspot(_material_hotspot(hotspot_name), INGREDIENT_HOTSPOT_IDS[hotspot_name], &"pancake_shared_ingredient", inventory, progression)
	for hotspot_name in SAUCE_HOTSPOT_IDS:
		_refresh_material_hotspot(_material_hotspot(hotspot_name), SAUCE_HOTSPOT_IDS[hotspot_name], &"pancake_shared_sauce", inventory, progression)
	var egg_capacity := int(CATALOG.stock_definition(EGG_STOCK_ID).get("restock_capacity", 6))
	if _session.has_method("five_area_restock_status"):
		var egg_status := Dictionary(_session.call("five_area_restock_status", EGG_STOCK_ID))
		egg_capacity = int(egg_status.get("capacity", egg_capacity))
	_update_egg_inventory_visual(int(inventory.get(str(EGG_STOCK_ID), 0)), egg_capacity)
	_update_spreader_holder_visual()


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
	if not hotspot.short_clicked.is_connected(_on_material_short_clicked):
		hotspot.short_clicked.connect(_on_material_short_clicked.bind(hotspot))
	if not hotspot.hold_requested.is_connected(_on_material_hold_requested):
		hotspot.hold_requested.connect(_on_material_hold_requested.bind(hotspot))
	if not hotspot.hold_advanced.is_connected(_on_material_hold_advanced):
		hotspot.hold_advanced.connect(_on_material_hold_advanced.bind(hotspot))
	if not hotspot.hold_released.is_connected(_on_material_hold_released):
		hotspot.hold_released.connect(_on_material_hold_released.bind(hotspot))
	hotspot.configure({"source_kind": source_kind, "source_index": -1, "stock_id": stock_id}, hit_texture, false)


func _refresh_material_hotspot(hotspot: ProductDragSource, stock_id: StringName, source_kind: StringName, inventory: Dictionary, progression: RefCounted) -> void:
	if hotspot == null:
		return
	var unlocked := progression != null and bool(progression.call("owns_stock", stock_id))
	var count := maxi(int(inventory.get(str(stock_id), 0)), 0)
	if hotspot.has_method("set_filled_slot_count"):
		hotspot.call("set_filled_slot_count", count)
	var label := _stock_label(stock_id)
	var hint := "%s：拖到鏊面；原地长按补货" % label if source_kind == &"pancake_shared_ingredient" else "%s：点击后在鏊面拖刷；原地长按补货" % label
	if not unlocked:
		hint = "%s尚未解锁" % label
	elif count <= 0:
		hint = "%s库存不足；原地长按补货" % label
	# Keep an empty but unlocked material clickable so a player can still begin
	# the shared hold-to-restock gesture from its physical worktop location.
	hotspot.configure({"source_kind": source_kind, "source_index": -1, "stock_id": stock_id}, hotspot.texture_normal, unlocked, hint)
	hotspot.set_drag_available(unlocked and count > 0 and source_kind == &"pancake_shared_ingredient")
	hotspot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if unlocked else Control.CURSOR_FORBIDDEN


func _on_spreader_pressed() -> void:
	var station := _griddle_station()
	if station == null or not station.has_method("select_worktop_tool"):
		return
	var result := Dictionary(station.call("select_worktop_tool", &"tool.pancake.spreader"))
	if not bool(result.get("success", false)):
		status_message.emit("当前无法使用摊饼器")


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
	var carton_base := get_node_or_null("EggBasketVisual") as TextureRect
	if carton_base == null:
		return
	# The carton is a fixed base layer.  Only the optional egg-content layer
	# changes with stock, so the old woven-basket states can never reappear.
	var content_visual := get_node_or_null("EggContentVisual") as TextureRect
	if content_visual == null:
		return
	var capped_stock := clampi(stock, 0, maxi(capacity, 0))
	content_visual.texture = egg_content_textures[capped_stock] if capped_stock < egg_content_textures.size() else null


func _update_spreader_holder_visual() -> void:
	var holder_empty := get_node_or_null("SpreaderHolderEmptyVisual") as CanvasItem
	var holder_filled := get_node_or_null("SpreaderHolderFilledVisual") as CanvasItem
	if holder_empty == null or holder_filled == null:
		return
	var station := _griddle_station()
	var spreader_selected := station != null and station.has_method("is_spreader_selected") and bool(station.call("is_spreader_selected"))
	holder_empty.visible = spreader_selected
	holder_filled.visible = not spreader_selected


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
