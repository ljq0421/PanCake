class_name PackagedDrinkStation
extends Control

signal status_message(message: String)
signal audio_cue_requested(cue: StringName)

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const JUICE_STOCK_TEXTURES := {
	1: preload("res://resources/art/products/orange_juice/yinpin-v1-1.png"),
	2: preload("res://resources/art/products/orange_juice/yinpin-v1-2.png"),
	3: preload("res://resources/art/products/orange_juice/yinpin-v1-3.png"),
	4: preload("res://resources/art/products/orange_juice/yinpin-v1-4.png"),
	5: preload("res://resources/art/products/orange_juice/yinpin-v1-5.png"),
	6: preload("res://resources/art/products/orange_juice/yinpin-v1-6.png"),
	7: preload("res://resources/art/products/orange_juice/yinpin-v1-7.png"),
	8: preload("res://resources/art/products/orange_juice/yinpin-v1-8.png"),
	9: preload("res://resources/art/products/orange_juice/yinpin-v1-9.png"),
	10: preload("res://resources/art/products/orange_juice/yinpin-v1-10.png"),
}
const EMPTY_JUICE_TRAY_TEXTURE := preload("res://resources/art/products/orange_juice/yinpin-v1.png")
const JUICE_DRAG_PREVIEW_TEXTURE := preload("res://resources/art/products/orange_juice/boxed_orange_juice_v1.png")

var _lock_cover: Button
var _sources: Array[ProductDragSource] = []
var _refresh_elapsed := 0.0


func _ready() -> void:
	_build_surface()
	refresh_from_session()


func _process(delta: float) -> void:
	_refresh_elapsed += maxf(delta, 0.0)
	if _refresh_elapsed >= 0.10:
		_refresh_elapsed = 0.0
		refresh_from_session()


func product_sources() -> Array[ProductDragSource]:
	return _sources.duplicate()


func refresh_from_session() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return
	var progression := Dictionary(session.call("five_area_progression_snapshot"))
	var area_unlocked := Array(progression.get("unlocked_area_ids", [])).has("area.packaged_drink")
	var unlocked_products := Array(progression.get("unlocked_product_ids", []))
	var inventory := Dictionary(session.call("inventory_snapshot"))
	_lock_cover.visible = not area_unlocked
	_lock_cover.disabled = area_unlocked
	var product_ids := _area_product_ids()
	for index in range(_sources.size()):
		var source := _sources[index]
		var product_id := product_ids[index] if index < product_ids.size() else &""
		var product := CATALOG.product_definition(product_id)
		var recipe := CATALOG.recipe_definition(StringName(product.get("recipe_id", &"")))
		var stock_ids := Array(recipe.get("stock_ids", []))
		var stock_id := StringName(stock_ids[0]) if not stock_ids.is_empty() else &""
		var count := maxi(int(inventory.get(str(stock_id), 0)), 0)
		var capacity := int(Dictionary(session.call("five_area_restock_status", stock_id)).get("capacity", 6)) if not stock_id.is_empty() else 6
		var product_unlocked := area_unlocked and _id_in(unlocked_products, product_id)
		var stock_visual := _stock_texture_for(product_id, count)
		var tray_texture: Texture2D = stock_visual if stock_visual != null else EMPTY_JUICE_TRAY_TEXTURE
		source.visible = product_unlocked
		source.configure({"source_kind": &"packaged_drink_inventory", "source_index": index, "stock_id": stock_id, "product_id": product_id}, tray_texture, product_unlocked, _lane_hint(product, count, capacity, product_unlocked))
		source.set_drag_preview_texture(JUICE_DRAG_PREVIEW_TEXTURE)
		source.set_drag_preview_text("")
		source.set_drag_preview_size(source.size)
		source.set_drag_available(product_unlocked and count > 0)


func _build_surface() -> void:
	for index in range(_area_product_ids().size()):
		var source := ProductDragSource.new()
		source.name = "DrinkLane%02d" % (index + 1)
		source.position = Vector2.ZERO
		source.size = size
		source.ignore_texture_size = true
		source.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		source.hold_enabled = true
		source.hold_threshold_seconds = 0.20
		source.cancel_pending_on_mouse_exit = false
		source.hold_requested.connect(_on_lane_hold_requested)
		source.hold_advanced.connect(_on_lane_hold_advanced)
		source.drag_started.connect(_on_lane_drag_started)
		add_child(source)
		_sources.append(source)
	_lock_cover = Button.new()
	_lock_cover.position = Vector2(10, 42)
	_lock_cover.size = Vector2(size.x - 20, size.y - 50)
	_lock_cover.text = "成品饮品区尚未解锁"
	_lock_cover.tooltip_text = "完成豆浆教学并获得 4 单合格豆浆后，可在成长工坊购买"
	_lock_cover.add_theme_font_size_override("font_size", 18)
	_lock_cover.pressed.connect(_on_lock_cover_pressed)
	add_child(_lock_cover)


func _area_product_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for raw_product_id in CATALOG.PRODUCT_DEFINITIONS:
		var product_id := StringName(raw_product_id)
		if StringName(CATALOG.product_definition(product_id).get("area_id", &"")) == &"area.packaged_drink":
			ids.append(product_id)
	ids.sort()
	return ids


func _on_lane_hold_requested(source_ref: Dictionary) -> void:
	var source := _source_for_ref(source_ref)
	var session := get_node_or_null("/root/GameSession")
	if source == null or session == null:
		return
	var status := Dictionary(session.call("five_area_restock_status", StringName(source_ref.get("stock_id", &""))))
	if bool(status.get("success", false)) and int(status.get("current_stock", 0)) < int(status.get("capacity", 0)) and int(status.get("coins", 0)) >= int(status.get("unit_cost", 0)):
		source.accept_hold()
		source.set_hold_progress(float(status.get("container_fill_ratio", 0.0)))
		status_message.emit("持续长按补充果汁；每瓶消耗 1 金币")
		return
	source.reject_hold()
	status_message.emit("果汁无法补货：库存已满或金币不足")


func _on_lane_hold_advanced(source_ref: Dictionary, delta: float) -> void:
	var source := _source_for_ref(source_ref)
	var session := get_node_or_null("/root/GameSession")
	if source == null or session == null:
		return
	var result := Dictionary(session.call("advance_five_area_restock_hold", StringName(source_ref.get("stock_id", &"")), delta))
	source.set_hold_progress(float(result.get("container_fill_ratio", 0.0)))
	if int(result.get("completed_units", 0)) > 0:
		audio_cue_requested.emit(&"drink_restock")
		status_message.emit("果汁补货 +%d" % int(result.get("completed_units", 0)))
	if bool(result.get("auto_stopped", false)) or not bool(result.get("success", false)):
		source.reject_hold()
	refresh_from_session()


func _on_lane_drag_started(_source_ref: Dictionary) -> void:
	audio_cue_requested.emit(&"drink_pickup")


func _on_lock_cover_pressed() -> void:
	var session := get_node_or_null("/root/GameSession")
	status_message.emit(str(session.call("growth_missing_requirements", &"growth.area.packaged_drink")) if session != null and session.has_method("growth_missing_requirements") else "成品饮品区尚未解锁")


func _source_for_ref(source_ref: Dictionary) -> ProductDragSource:
	var index := int(source_ref.get("source_index", -1))
	return _sources[index] if index >= 0 and index < _sources.size() else null


static func _id_in(values: Array, expected: StringName) -> bool:
	return values.has(expected) or values.has(str(expected))


static func _stock_texture_for(product_id: StringName, count: int) -> Texture2D:
	if product_id != &"product.packaged_drink.juice" or count <= 0:
		return null
	return JUICE_STOCK_TEXTURES.get(clampi(count, 1, 10)) as Texture2D


static func _lane_hint(product: Dictionary, count: int, capacity: int, unlocked: bool) -> String:
	if not unlocked:
		return "该饮品尚未解锁"
	if count <= 0:
		return "%s已售罄：长按补货" % str(product.get("label", "饮品"))
	if count >= capacity:
		return "%s库存充足：拖到顾客订单交付" % str(product.get("label", "饮品"))
	return "%s：拖动交付；长按补货（%d/%d）" % [str(product.get("label", "饮品")), count, capacity]
