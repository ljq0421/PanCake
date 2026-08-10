class_name DirectPackagedDrinkStation
extends Control

signal status_message(message: String)

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const PRODUCT_VISUALS := preload("res://scripts/ui/five_area_product_visuals.gd")
const PRODUCT_IDS: Array[StringName] = [
	&"product.packaged_drink.milk",
	&"product.packaged_drink.soy_milk",
	&"product.packaged_drink.walnut",
	&"product.packaged_drink.black_sesame",
]

@export var heater_empty_style: StyleBox
@export var heater_heating_style: StyleBox
@export var heater_ready_style: StyleBox
@export var heater_cooled_style: StyleBox

@onready var lanes: Array[ProductDragSource] = [%Lane01, %Lane02, %Lane03, %Lane04]
@onready var lane_depth_a: Array[TextureRect] = [%Depth01A, %Depth02A, %Depth03A, %Depth04A]
@onready var lane_depth_b: Array[TextureRect] = [%Depth01B, %Depth02B, %Depth03B, %Depth04B]
@onready var lane_counts: Array[Label] = [%Count01, %Count02, %Count03, %Count04]
@onready var heater_sources: Array[ProductDragSource] = [%HeaterSource01, %HeaterSource02, %HeaterSource03, %HeaterSource04]
@onready var heater_targets: Array[HeaterSlotDropTarget] = [%HeaterSlot01, %HeaterSlot02, %HeaterSlot03, %HeaterSlot04]
@onready var heater_states: Array[Label] = [%HeaterState01, %HeaterState02, %HeaterState03, %HeaterState04]
@onready var state_label: Label = %StateLabel
@onready var lock_cover: Button = %LockCover

var _refresh_elapsed := 0.0


func _ready() -> void:
	for index in range(lanes.size()):
		lanes[index].hold_enabled = true
		lanes[index].hold_threshold_seconds = 0.1
		lanes[index].hold_requested.connect(_on_lane_hold_requested)
		lanes[index].hold_advanced.connect(_on_lane_hold_advanced)
		heater_targets[index].load_completed.connect(_on_heater_load_completed)
	lock_cover.pressed.connect(_on_lock_cover_pressed)
	refresh_from_session()


func _process(delta: float) -> void:
	_refresh_elapsed += delta
	if _refresh_elapsed >= 0.10:
		_refresh_elapsed = 0.0
		refresh_from_session()


func refresh_from_session() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null or not session.has_method("five_area_production_snapshot"):
		return
	var progression := Dictionary(session.call("five_area_progression_snapshot"))
	var unlocked_areas := Array(progression.get("unlocked_area_ids", []))
	var area_unlocked := unlocked_areas.has("area.packaged_drink")
	lock_cover.visible = not area_unlocked
	var unlocked_products := PackedStringArray(Array(progression.get("unlocked_product_ids", [])))
	var inventory := Dictionary(session.call("inventory_snapshot"))
	for index in range(PRODUCT_IDS.size()):
		var product_id := PRODUCT_IDS[index]
		var definition := CATALOG.product_definition(product_id)
		var stock_id := StringName(definition.get("stock_id", &""))
		var count := maxi(int(inventory.get(str(stock_id), 0)), 0)
		var unlocked := area_unlocked and unlocked_products.has(str(product_id))
		var texture := PRODUCT_VISUALS.texture_for(product_id)
		lanes[index].configure({"source_kind": &"inventory", "source_index": index, "product_id": product_id}, texture, area_unlocked, "%s · 长按补货；有库存时移动超过 10px 可拖到加热位" % str(definition.get("label", product_id)))
		lanes[index].set_drag_available(unlocked and count > 0)
		lanes[index].visible = area_unlocked
		lanes[index].self_modulate = Color.WHITE if unlocked and count > 0 else Color(1.0, 1.0, 1.0, 0.36)
		lane_depth_a[index].texture = texture
		lane_depth_b[index].texture = texture
		lane_depth_a[index].visible = unlocked and count >= 2
		lane_depth_b[index].visible = unlocked and count >= 3
		lane_counts[index].text = str(count) if unlocked else "锁"
	var machine := Dictionary(Dictionary(session.call("five_area_production_snapshot")).get("packaged_drink_heater", {}))
	var slots := Array(machine.get("slots", []))
	var tier_definition := CATALOG.device_tier(&"device.packaged_drink_heater", int(machine.get("tier", 0)))
	var duration_seconds := float(tier_definition.get("duration_seconds", 0.0))
	for slot_index in range(heater_sources.size()):
		var slot := Dictionary(slots[slot_index]) if slot_index < slots.size() else {"state": &"locked"}
		var state := StringName(slot.get("state", &"locked"))
		var product_id := StringName(slot.get("product_id", &""))
		var ready := state in [&"ready_hot", &"cooled"]
		heater_targets[slot_index].visible = state != &"locked"
		var state_text := _heater_state_text(slot, duration_seconds)
		var state_tooltip := _heater_state_tooltip(slot, duration_seconds)
		heater_sources[slot_index].configure({"source_kind": &"heater_slot", "source_index": slot_index, "product_id": product_id}, PRODUCT_VISUALS.texture_for(product_id, &"heated"), ready, state_tooltip)
		heater_sources[slot_index].visible = state != &"empty" and state != &"locked"
		heater_states[slot_index].text = state_text
		heater_states[slot_index].tooltip_text = state_tooltip
		heater_states[slot_index].add_theme_color_override("font_color", _heater_state_color(state))
		heater_targets[slot_index].tooltip_text = state_tooltip
		var slot_style := _heater_style_for_state(state)
		if slot_style != null:
			heater_targets[slot_index].add_theme_stylebox_override("panel", slot_style)
	state_label.text = "长按货道补货 · 移动超过 10px 拖拽"


func _on_lane_hold_requested(source_ref: Dictionary) -> void:
	var lane := _lane_for_source(source_ref)
	var session := get_node_or_null("/root/GameSession")
	if lane == null or session == null:
		return
	var definition := CATALOG.product_definition(StringName(source_ref.get("product_id", &"")))
	var stock_id := StringName(definition.get("stock_id", &""))
	var status := Dictionary(session.call("five_area_restock_status", stock_id))
	if not bool(status.get("success", false)):
		lane.reject_hold()
		status_message.emit(_restock_reason_text(StringName(status.get("reason", &"unknown"))))
		return
	if int(status.get("current_stock", 0)) >= int(status.get("capacity", 0)):
		lane.reject_hold()
		status_message.emit("该饮品货道已满")
		return
	if int(status.get("coins", 0)) < int(status.get("unit_cost", 0)):
		lane.reject_hold()
		status_message.emit("金币不足，补货未扣费")
		return
	lane.accept_hold()
	status_message.emit("正在补货；每 0.5 秒完成一瓶")


func _on_lane_hold_advanced(source_ref: Dictionary, delta: float) -> void:
	var lane := _lane_for_source(source_ref)
	var session := get_node_or_null("/root/GameSession")
	if lane == null or session == null:
		return
	var definition := CATALOG.product_definition(StringName(source_ref.get("product_id", &"")))
	var stock_id := StringName(definition.get("stock_id", &""))
	var result := Dictionary(session.call("advance_five_area_restock_hold", stock_id, delta))
	if int(result.get("completed_units", 0)) > 0:
		status_message.emit("饮品已上架 +%d" % int(result.get("completed_units", 0)))
		refresh_from_session()
	if bool(result.get("auto_stopped", false)):
		lane.reject_hold()
		status_message.emit(_restock_reason_text(StringName(result.get("reason", &"unknown"))))
	elif not bool(result.get("success", false)):
		lane.reject_hold()
		status_message.emit(_restock_reason_text(StringName(result.get("reason", &"unknown"))))


func _lane_for_source(source_ref: Dictionary) -> ProductDragSource:
	var index := int(source_ref.get("source_index", -1))
	return lanes[index] if index >= 0 and index < lanes.size() else null


static func _restock_reason_text(reason: StringName) -> String:
	match reason:
		&"capacity_reached": return "该饮品货道已满"
		&"insufficient_coins": return "金币不足，补货已停止"
		&"stock_locked": return "该饮品尚未解锁"
		&"restock_unavailable": return "该商品不能直接补货"
	return "补货停止：%s" % str(reason)


func _on_heater_load_completed(result: Dictionary) -> void:
	status_message.emit("饮品已放入加热位" if bool(result.get("success", false)) else "饮品回到货道：%s" % str(result.get("reason", &"unknown")))
	refresh_from_session()


func _on_lock_cover_pressed() -> void:
	var session := get_node_or_null("/root/GameSession")
	var text := "成品饮品区域尚未解锁"
	if session != null and session.has_method("growth_missing_requirements"):
		text = str(session.call("growth_missing_requirements", &"growth.area.packaged_drink"))
	status_message.emit(text)


static func _heater_state_text(slot: Dictionary, duration_seconds: float) -> String:
	match StringName(slot.get("state", &"locked")):
		&"empty": return "空"
		&"heating": return "%.1f秒" % maxf(duration_seconds - float(slot.get("elapsed_seconds", 0.0)), 0.0)
		&"ready_hot": return "已加热"
		&"cooled": return "已冷却"
	return "锁"


static func _heater_state_tooltip(slot: Dictionary, duration_seconds: float) -> String:
	match StringName(slot.get("state", &"locked")):
		&"empty": return "空加热位：把需要加热的饮品拖到这里"
		&"heating": return "正在加热，剩余 %.1f 秒" % maxf(duration_seconds - float(slot.get("elapsed_seconds", 0.0)), 0.0)
		&"ready_hot": return "已加热：点击订单商品交付"
		&"cooled": return "已冷却：拖到废弃区处理"
	return "该加热位尚未开放"


func _heater_style_for_state(state: StringName) -> StyleBox:
	match state:
		&"heating": return heater_heating_style
		&"ready_hot": return heater_ready_style
		&"cooled": return heater_cooled_style
	return heater_empty_style


static func _heater_state_color(state: StringName) -> Color:
	match state:
		&"heating": return Color(0.34, 0.18, 0.05)
		&"ready_hot": return Color(0.38, 0.08, 0.02)
		&"cooled": return Color(0.12, 0.22, 0.3)
	return Color(0.2, 0.12, 0.06)
