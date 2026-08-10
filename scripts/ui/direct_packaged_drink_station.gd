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

@onready var lanes: Array[ProductDragSource] = [%Lane01, %Lane02, %Lane03, %Lane04]
@onready var lane_depth_a: Array[TextureRect] = [%Depth01A, %Depth02A, %Depth03A, %Depth04A]
@onready var lane_depth_b: Array[TextureRect] = [%Depth01B, %Depth02B, %Depth03B, %Depth04B]
@onready var lane_counts: Array[Label] = [%Count01, %Count02, %Count03, %Count04]
@onready var restock_buttons: Array[RestockHoldButton] = [%Restock01, %Restock02, %Restock03, %Restock04]
@onready var heater_sources: Array[ProductDragSource] = [%HeaterSource01, %HeaterSource02, %HeaterSource03, %HeaterSource04]
@onready var heater_targets: Array[HeaterSlotDropTarget] = [%HeaterSlot01, %HeaterSlot02, %HeaterSlot03, %HeaterSlot04]
@onready var heater_states: Array[Label] = [%HeaterState01, %HeaterState02, %HeaterState03, %HeaterState04]
@onready var state_label: Label = %StateLabel
@onready var lock_cover: Button = %LockCover

var _refresh_elapsed := 0.0


func _ready() -> void:
	for index in range(restock_buttons.size()):
		restock_buttons[index].restock_feedback.connect(_on_restock_feedback)
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
		lanes[index].configure({"source_kind": &"inventory", "source_index": index, "product_id": product_id}, texture, unlocked and count > 0, "%s · 拖到托盘；需加热时先拖到加热位" % str(definition.get("label", product_id)))
		lanes[index].visible = unlocked and count > 0
		lane_depth_a[index].texture = texture
		lane_depth_b[index].texture = texture
		lane_depth_a[index].visible = unlocked and count >= 2
		lane_depth_b[index].visible = unlocked and count >= 3
		lane_counts[index].text = str(count) if unlocked else "锁"
		restock_buttons[index].configure(stock_id, unlocked, "按住补货；每完成 0.5 秒增加一份，松开保留进度")
	var machine := Dictionary(Dictionary(session.call("five_area_production_snapshot")).get("packaged_drink_heater", {}))
	var slots := Array(machine.get("slots", []))
	for slot_index in range(heater_sources.size()):
		var slot := Dictionary(slots[slot_index]) if slot_index < slots.size() else {"state": &"locked"}
		var state := StringName(slot.get("state", &"locked"))
		var product_id := StringName(slot.get("product_id", &""))
		var ready := state in [&"ready_hot", &"cooled"]
		heater_targets[slot_index].visible = state != &"locked"
		heater_sources[slot_index].configure({"source_kind": &"heater_slot", "source_index": slot_index, "product_id": product_id}, PRODUCT_VISUALS.texture_for(product_id, &"heated"), ready, "热饮完成后拖到顾客托盘")
		heater_sources[slot_index].visible = state != &"empty" and state != &"locked"
		heater_states[slot_index].text = _heater_state_text(slot)
	state_label.text = "四条货道独立计数 · 拖拽取物"


func _on_restock_feedback(result: Dictionary) -> void:
	if int(result.get("completed_units", 0)) > 0:
		status_message.emit("饮品已上架 +%d" % int(result.get("completed_units", 0)))
	elif not bool(result.get("success", false)):
		status_message.emit("补货停止：%s" % str(result.get("reason", &"unknown")))


func _on_heater_load_completed(result: Dictionary) -> void:
	status_message.emit("饮品已放入加热位" if bool(result.get("success", false)) else "饮品回到货道：%s" % str(result.get("reason", &"unknown")))
	refresh_from_session()


func _on_lock_cover_pressed() -> void:
	var session := get_node_or_null("/root/GameSession")
	var text := "成品饮品区域尚未解锁"
	if session != null and session.has_method("growth_missing_requirements"):
		text = str(session.call("growth_missing_requirements", &"growth.area.packaged_drink"))
	status_message.emit(text)


static func _heater_state_text(slot: Dictionary) -> String:
	match StringName(slot.get("state", &"locked")):
		&"empty": return "空"
		&"heating": return "%.1fs" % float(slot.get("elapsed_seconds", 0.0))
		&"ready_hot": return "热"
		&"cooled": return "冷"
	return "锁"

