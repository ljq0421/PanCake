class_name CartoonYoutiaoFryerToggle
extends Control

## The cartoon fryer is the production UI for device.youtiao_fryer. GameSession
## remains the authority for stock, production time, quality, waste and storage.
signal status_message(message: String)

const DEVICE_ID := &"device.youtiao_fryer"
const RECIPE_ID := &"recipe.youtiao.plain"
const PRODUCT_ID := &"product.youtiao.plain"

@export var lowered_machine_texture: Texture2D
@export var raised_machine_texture: Texture2D
@export var raw_youtiao_texture: Texture2D
@export var golden_youtiao_texture: Texture2D
@export var burnt_youtiao_texture: Texture2D
@export var reduce_motion := false

@onready var fryer_visual: TextureRect = %FryerVisual
@onready var dough_visuals: Array[TextureRect] = [%DoughVisual1, %DoughVisual2]
@onready var product_visuals: Array[TextureRect] = [%ProductVisual1, %ProductVisual2]
@onready var plate_product_visuals: Array[TextureRect] = [%PlateProductVisual1, %PlateProductVisual2]
@onready var drag_visual: TextureRect = %DragVisual
@onready var status_label: Label = %StatusLabel

# Compatibility surface consumed by FiveAreaWorkstation and tutorial routing.
var output_sources: Array[ProductDragSource] = []
var prepared_slot: PreparedProductSlot
var waste_target: StagedProductDropTarget
var start_button: Control
var lift_button: Control
var state_label: Label
var lock_cover: Button

var _machine: Dictionary = {}
var _refresh_elapsed := 0.0
var _drag_kind := &""
var _drag_item_index := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	start_button = fryer_visual
	lift_button = fryer_visual
	state_label = status_label
	_expand_visual_capacity()
	_create_runtime_controls()
	refresh_from_session()


func _process(delta: float) -> void:
	_refresh_elapsed += maxf(delta, 0.0)
	if _refresh_elapsed >= 0.10:
		_refresh_elapsed = 0.0
		refresh_from_session()
	if not _drag_kind.is_empty():
		drag_visual.position = get_local_mouse_position() - drag_visual.size * 0.5


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag_or_click(event.position)
		else:
			_finish_drag_or_click(event.position)
		accept_event()
	elif event is InputEventMouseMotion and not _drag_kind.is_empty():
		accept_event()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and StringName(Dictionary(data).get("kind", &"")) == &"product_source" and StringName(Dictionary(Dictionary(data).get("source_ref", {})).get("source_kind", &"")) == &"youtiao_dough"


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var source_ref := Dictionary(Dictionary(data).get("source_ref", {}))
	_load_dough(StringName(source_ref.get("recipe_id", RECIPE_ID)))


func select_recipe(_recipe_id: StringName) -> void:
	pass


func refresh_from_session() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null or not session.has_method("f3_machine_snapshot"):
		return
	_machine = Dictionary(session.call("f3_machine_snapshot", DEVICE_ID))
	_apply_snapshot()
	_refresh_prepared_slot(session)


func _begin_drag_or_click(point: Vector2) -> void:
	if _is_board_point(point):
		var dough_index := _visible_item_at(dough_visuals, point)
		if dough_index >= 0:
			_begin_drag(&"dough", dough_index, raw_youtiao_texture, point)
			return
	if fryer_visual.get_rect().has_point(point):
		_perform_machine_click()


func _finish_drag_or_click(point: Vector2) -> void:
	if _drag_kind == &"dough":
		drag_visual.visible = false
		if fryer_visual.get_rect().has_point(point):
			_load_dough(RECIPE_ID)
		else:
			dough_visuals[_drag_item_index].visible = true
	_drag_kind = &""
	_drag_item_index = -1


func _begin_drag(kind: StringName, item_index: int, texture: Texture2D, point: Vector2) -> void:
	_drag_kind = kind
	_drag_item_index = item_index
	drag_visual.texture = texture
	drag_visual.position = point - drag_visual.size * 0.5
	drag_visual.visible = true
	dough_visuals[item_index].visible = false


func _load_dough(recipe_id: StringName = RECIPE_ID) -> void:
	var session := get_node_or_null("/root/GameSession")
	var result := Dictionary(session.call("load_f3_youtiao", recipe_id, 1)) if session != null else {"success": false, "reason": &"no_game_session"}
	if bool(result.get("success", false)):
		status_message.emit("面胚已放入卡通油条机")
	else:
		status_message.emit(_failure_text(StringName(result.get("reason", &""))))
	refresh_from_session()


func _perform_machine_click() -> void:
	var state := StringName(_machine.get("state", &"idle"))
	var action := &"start" if state == &"loaded" else &"lift" if state in [&"ready_safe", &"overcooking"] else &""
	if action.is_empty():
		status_message.emit("先将面胚拖入炸篮" if state == &"idle" else _state_text(state))
		return
	var session := get_node_or_null("/root/GameSession")
	var result := Dictionary(session.call("perform_f3_youtiao_action", action)) if session != null else {"success": false, "reason": &"no_game_session"}
	status_message.emit("油条开始炸制" if action == &"start" and bool(result.get("success", false)) else "炸篮已抬起，正在沥油" if bool(result.get("success", false)) else _failure_text(StringName(result.get("reason", &""))))
	refresh_from_session()


func _apply_snapshot() -> void:
	var state := StringName(_machine.get("state", &"unowned"))
	var capacity := clampi(int(_machine.get("capacity", 0)), 0, product_visuals.size())
	var occupied := _occupied_slots()
	var cooking := state in [&"loaded", &"frying"]
	var finished_texture := burnt_youtiao_texture if state == &"burnt" else golden_youtiao_texture
	fryer_visual.texture = lowered_machine_texture if state == &"frying" else raised_machine_texture
	for index in range(product_visuals.size()):
		var visible := index < capacity and occupied.has(index)
		var visual := product_visuals[index]
		visual.visible = visible
		visual.texture = raw_youtiao_texture if cooking else finished_texture
		visual.position = _basket_position(index, state == &"frying")
		visual.modulate = Color.WHITE
	for index in range(dough_visuals.size()):
		dough_visuals[index].visible = state in [&"idle", &"loaded"] and int(_machine.get("quantity", 0)) < int(_machine.get("capacity", 0))
	for index in range(plate_product_visuals.size()):
		plate_product_visuals[index].visible = index < occupied.size() and state == &"ready_to_collect"
		plate_product_visuals[index].texture = finished_texture
		plate_product_visuals[index].position = _plate_position(index)
	status_label.text = "%s · %d/%d" % [_state_text(state), int(_machine.get("quantity", 0)), int(_machine.get("capacity", 0))]
	_refresh_output_source(state, occupied)


func _refresh_output_source(state: StringName, occupied: Array[int]) -> void:
	if output_sources.is_empty():
		return
	var available := not occupied.is_empty() and state in [&"ready_to_collect", &"burnt"]
	var hint := "拖到成品暂存区收纳整锅油条" if state == &"ready_to_collect" else "拖到废弃区报废整锅油条"
	output_sources[0].configure({"source_kind": &"youtiao_batch", "source_index": -1, "product_id": PRODUCT_ID, "quantity": occupied.size(), "discardable": true}, burnt_youtiao_texture if state == &"burnt" else golden_youtiao_texture, available, hint)
	output_sources[0].visible = available


func _refresh_prepared_slot(session: Node) -> void:
	if prepared_slot == null:
		return
	var status := Dictionary(session.call("prepared_product_slot_status", &"slot.04"))
	prepared_slot.configure_count(int(status.get("count", 0)), StringName(status.get("reason", &"")) != &"recipe_locked", int(status.get("capacity", 4)))


func _create_runtime_controls() -> void:
	var output := ProductDragSource.new()
	output.name = "BatchOutputSource"
	output.position = Vector2(340.0, 440.0)
	output.size = Vector2(260.0, 210.0)
	output.ignore_texture_size = true
	output.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	output.native_drag_enabled = true
	output.visible = false
	add_child(output)
	output_sources.append(output)

	prepared_slot = PreparedProductSlot.new()
	prepared_slot.name = "PreparedPlain"
	prepared_slot.position = Vector2(340.0, 655.0)
	prepared_slot.size = Vector2(260.0, 48.0)
	prepared_slot.slot_id = &"slot.04"
	prepared_slot.product_id = PRODUCT_ID
	prepared_slot.ingredient_type = &"youtiao"
	prepared_slot.product_texture = golden_youtiao_texture
	prepared_slot.allow_pancake_drag = true
	_add_prepared_slot_children(prepared_slot)
	add_child(prepared_slot)
	prepared_slot.store_completed.connect(_on_prepared_store_completed)

	waste_target = StagedProductDropTarget.new()
	waste_target.name = "WasteTarget"
	waste_target.position = Vector2(340.0, 710.0)
	waste_target.size = Vector2(260.0, 44.0)
	waste_target.disposition = "waste"
	var waste_label := Label.new()
	waste_label.text = "拖到这里废弃"
	waste_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	waste_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	waste_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	waste_target.add_child(waste_label)
	add_child(waste_target)


func _add_prepared_slot_children(slot: PreparedProductSlot) -> void:
	var artwork := TextureRect.new()
	artwork.name = "Artwork"
	artwork.position = Vector2(8.0, 4.0)
	artwork.size = Vector2(54.0, 38.0)
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.add_child(artwork)
	var label := Label.new()
	label.name = "CountLabel"
	label.position = Vector2(68.0, 0.0)
	label.size = Vector2(184.0, 48.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot.add_child(label)


func _expand_visual_capacity() -> void:
	for index in range(2, 8):
		var basket_visual := product_visuals[0].duplicate() as TextureRect
		basket_visual.name = "ProductVisual%d" % (index + 1)
		add_child(basket_visual)
		product_visuals.append(basket_visual)
		var plate_visual := plate_product_visuals[0].duplicate() as TextureRect
		plate_visual.name = "PlateProductVisual%d" % (index + 1)
		add_child(plate_visual)
		plate_product_visuals.append(plate_visual)


func _on_prepared_store_completed(result: Dictionary) -> void:
	status_message.emit("炸好的油条已收纳" if bool(result.get("success", false)) else _failure_text(StringName(result.get("reason", &""))))
	refresh_from_session()


func _occupied_slots() -> Array[int]:
	var result: Array[int] = []
	for value in Array(_machine.get("occupied_slot_indices", [])):
		result.append(int(value))
	return result


func _is_board_point(point: Vector2) -> bool:
	return Rect2(Vector2(0.0, 429.0), Vector2(338.0, 221.0)).has_point(point)


func _visible_item_at(items: Array[TextureRect], point: Vector2) -> int:
	for index in range(items.size() - 1, -1, -1):
		if items[index].visible and items[index].get_rect().has_point(point):
			return index
	return -1


static func _basket_position(index: int, lowered: bool) -> Vector2:
	var column := index % 4
	var row := index / 4
	return Vector2(202.0 + column * 47.0, (132.0 if lowered else 68.0) + row * 34.0)


static func _plate_position(index: int) -> Vector2:
	var column := index % 2
	var row := index / 2
	return Vector2(358.0 + column * 105.0, 458.0 + row * 45.0)


static func _state_text(state: StringName) -> String:
	return {
		&"unowned": "油条机未解锁", &"idle": "拖面胚到炸篮", &"loaded": "点击油条机开始炸制",
		&"frying": "炸制中", &"ready_safe": "点击油条机抬起沥网", &"overcooking": "油条即将炸糊",
		&"draining": "正在沥油", &"ready_to_collect": "拖盘中油条收纳", &"burnt": "油条已炸糊，拖去废弃",
	}.get(state, "油条机")


static func _failure_text(reason: StringName) -> String:
	return {
		&"capacity_exceeded": "炸篮已满", &"insufficient_stock": "油条面胚不足", &"recipe_locked": "油条配方尚未解锁",
		&"equipment_not_owned": "油条机尚未解锁", &"invalid_equipment_state": "当前不能放入面胚",
	}.get(reason, "操作未完成：%s" % str(reason))
