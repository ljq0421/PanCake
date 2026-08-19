class_name CartoonYoutiaoFryerToggle
extends Control

## The cartoon fryer is the production UI for device.youtiao_fryer. GameSession
## remains the authority for stock, production time, quality, waste and storage.
signal status_message(message: String)

const DEVICE_ID := &"device.youtiao_fryer"
const RECIPE_ID := &"recipe.youtiao.plain"
const PRODUCT_ID := &"product.youtiao.plain"
const DOUGH_STOCK_ID := &"stock.youtiao.plain_dough"
const BOARD_HOLD_THRESHOLD_SECONDS := 0.20
const BOARD_DRAG_THRESHOLD_PIXELS := 10.0
const BOARD_VISUAL_CAPACITY := 4
const PLATE_VISUAL_CAPACITY := 4

@export var lowered_machine_texture: Texture2D
@export var raised_machine_texture: Texture2D
@export var raw_youtiao_texture: Texture2D
@export var golden_youtiao_texture: Texture2D
@export var plate_youtiao_texture: Texture2D
@export var burnt_youtiao_texture: Texture2D
@export var reduce_motion := false

@onready var fryer_visual: TextureRect = %FryerVisual
@onready var dough_visuals: Array[TextureRect] = [%DoughVisual1]
@onready var product_visuals: Array[TextureRect] = [%ProductVisual1, %ProductVisual2]
@onready var plate_product_visuals: Array[TextureRect] = [%PlateProductVisual1, %PlateProductVisual2]
@onready var board_dough_slots: Array[Control] = [%BoardDoughSlot1, %BoardDoughSlot2, %BoardDoughSlot3, %BoardDoughSlot4]
@onready var raised_basket_slots: Array[Control] = [%RaisedBasketSlot1, %RaisedBasketSlot2, %RaisedBasketSlot3, %RaisedBasketSlot4]
@onready var lowered_basket_slots: Array[Control] = [%LoweredBasketSlot1, %LoweredBasketSlot2, %LoweredBasketSlot3, %LoweredBasketSlot4]
@onready var plate_product_slots: Array[Control] = [%PlateProductSlot1, %PlateProductSlot2, %PlateProductSlot3, %PlateProductSlot4]
@onready var drag_visual: TextureRect = %DragVisual
@onready var status_label: Label = %StatusLabel

# Compatibility surface consumed by FiveAreaWorkstation and tutorial routing.
var output_sources: Array[ProductDragSource] = []
var plate_sources: Array[ProductDragSource] = []
var prepared_slot: PreparedProductSlot
var waste_target: StagedProductDropTarget
var start_button: Control
var lift_button: Control
var state_label: Label
var lock_cover: Button

var _machine: Dictionary = {}
var _dough_stock := 0
var _plate_count := 0
var _refresh_elapsed := 0.0
var _drag_kind := &""
var _drag_item_index := -1
var _board_press_active := false
var _board_hold_active := false
var _board_hold_elapsed := 0.0
var _board_press_position := Vector2.ZERO
var _board_dough_index := -1
var _seasoned_product_id: StringName = &""
var _sesame_button: Button
var _sugar_button: Button
var _workshop_preview := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	start_button = fryer_visual
	lift_button = fryer_visual
	state_label = status_label
	_expand_visual_capacity()
	_create_runtime_controls()
	refresh_from_session()


func _process(delta: float) -> void:
	_advance_board_hold(delta)
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
	elif event is InputEventMouseMotion and (_board_press_active or not _drag_kind.is_empty()):
		if _board_press_active:
			_update_board_gesture(event.position)
		accept_event()


func _input(event: InputEvent) -> void:
	# Once a press begins on the board, keep tracking it even when a player
	# drags or releases outside this Control's bounds.
	if not _board_press_active and _drag_kind.is_empty():
		return
	if event is InputEventMouseMotion:
		if _board_press_active:
			_update_board_gesture(get_local_mouse_position())
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drag_or_click(get_local_mouse_position())
		get_viewport().set_input_as_handled()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or StringName(Dictionary(data).get("kind", &"")) != &"product_source":
		return false
	var source_ref := Dictionary(Dictionary(data).get("source_ref", {}))
	if StringName(source_ref.get("source_kind", &"")) == &"youtiao_dough":
		return true
	return (
		StringName(source_ref.get("source_kind", &"")) == &"youtiao_fryer_slot"
		and StringName(_machine.get("state", &"")) == &"ready_to_collect"
		and _plate_count < PLATE_VISUAL_CAPACITY
		and _is_plate_point(_at_position)
	)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var source_ref := Dictionary(Dictionary(data).get("source_ref", {}))
	if StringName(source_ref.get("source_kind", &"")) == &"youtiao_dough":
		_load_dough(StringName(source_ref.get("recipe_id", RECIPE_ID)))
		return
	if StringName(source_ref.get("source_kind", &"")) == &"youtiao_fryer_slot" and _is_plate_point(_at_position):
		_store_fryer_slot_on_plate(int(source_ref.get("source_index", -1)))


func select_recipe(_recipe_id: StringName) -> void:
	pass


func refresh_from_session() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null or not session.has_method("f3_machine_snapshot"):
		return
	_machine = Dictionary(session.call("f3_machine_snapshot", DEVICE_ID))
	if _workshop_preview:
		visible = true
		_machine["state"] = &"idle"
		_machine["capacity"] = 8
		_machine["quantity"] = 0
	var progression := Dictionary(session.call("five_area_progression_snapshot")) if session.has_method("five_area_progression_snapshot") else {}
	var unlocked_products := Array(progression.get("unlocked_product_ids", []))
	_sesame_button.visible = unlocked_products.has("product.youtiao.sesame")
	_sugar_button.visible = unlocked_products.has("product.youtiao.sugar")
	if _workshop_preview:
		_sesame_button.visible = true
		_sugar_button.visible = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		mouse_filter = Control.MOUSE_FILTER_STOP
	if not _sesame_button.visible and _seasoned_product_id == &"product.youtiao.sesame": _seasoned_product_id = &""
	if not _sugar_button.visible and _seasoned_product_id == &"product.youtiao.sugar": _seasoned_product_id = &""
	var inventory := Dictionary(session.call("inventory_snapshot")) if session.has_method("inventory_snapshot") else {}
	_dough_stock = maxi(int(inventory.get(str(DOUGH_STOCK_ID), 0)), 0)
	_refresh_prepared_slot(session)
	_apply_snapshot()


func _begin_drag_or_click(point: Vector2) -> void:
	if _is_board_point(point):
		_begin_board_gesture(point)
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
	_end_board_gesture()


func _begin_board_gesture(point: Vector2) -> void:
	_board_press_active = true
	_board_hold_active = false
	_board_hold_elapsed = 0.0
	_board_press_position = point
	_board_dough_index = _visible_item_at(dough_visuals, point)


func _update_board_gesture(point: Vector2) -> void:
	if not _board_press_active or point.distance_to(_board_press_position) <= BOARD_DRAG_THRESHOLD_PIXELS:
		return
	if _board_hold_active:
		# Movement after a hold keeps the familiar dough-drag interaction when a
		# physical piece is available, while ending replenishment immediately.
		_board_hold_active = false
	if _board_dough_index >= 0 and _can_load_dough() and dough_visuals[_board_dough_index].visible:
		_begin_drag(&"dough", _board_dough_index, raw_youtiao_texture, _board_press_position)
		if _drag_kind == &"dough":
			drag_visual.position = point - drag_visual.size * 0.5
	_end_board_gesture()


func _advance_board_hold(delta: float) -> void:
	if not _board_press_active or not _drag_kind.is_empty():
		return
	if not _board_hold_active:
		_board_hold_elapsed += maxf(delta, 0.0)
		if _board_hold_elapsed + 0.000001 < BOARD_HOLD_THRESHOLD_SECONDS:
			return
		_start_board_restock_hold()
		return
	var session := get_node_or_null("/root/GameSession")
	var result := Dictionary(session.call("advance_five_area_restock_hold", DOUGH_STOCK_ID, delta)) if session != null else {"success": false, "reason": &"no_game_session"}
	if int(result.get("completed_units", 0)) > 0:
		status_message.emit("油条面胚补货 +%d" % int(result.get("completed_units", 0)))
	if bool(result.get("auto_stopped", false)) or not bool(result.get("success", false)):
		_board_hold_active = false
		_board_press_active = false
		status_message.emit(_restock_failure_text(StringName(result.get("reason", &"")), result))
	refresh_from_session()


func _start_board_restock_hold() -> void:
	var session := get_node_or_null("/root/GameSession")
	var status := Dictionary(session.call("five_area_restock_status", DOUGH_STOCK_ID)) if session != null else {"success": false, "reason": &"no_game_session"}
	var can_restock := bool(status.get("success", false)) and int(status.get("current_stock", 0)) < int(status.get("capacity", 0)) and int(status.get("coins", 0)) >= int(status.get("unit_cost", 0))
	if can_restock:
		_board_hold_active = true
		status_message.emit("持续长按案板补充油条面胚；每完成一份才扣金币")
		return
	_board_press_active = false
	if not bool(status.get("success", false)):
		status_message.emit(_restock_failure_text(StringName(status.get("reason", &"")), status))
	elif int(status.get("current_stock", 0)) >= int(status.get("capacity", 0)):
		status_message.emit("油条面胚已补满")
	else:
		status_message.emit("余额不足：每份需要 %d 金币" % int(status.get("unit_cost", 0)))


func _end_board_gesture() -> void:
	_board_press_active = false
	_board_hold_active = false
	_board_hold_elapsed = 0.0
	_board_dough_index = -1


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


func _store_fryer_slot_on_plate(source_index: int) -> void:
	var session := get_node_or_null("/root/GameSession")
	var result := Dictionary(session.call("store_ready_youtiao_slot", &"slot.04", source_index, _seasoned_product_id)) if session != null else {"success": false, "reason": &"no_game_session"}
	if bool(result.get("success", false)):
		status_message.emit("油条已放入成品盘" if _seasoned_product_id.is_empty() else "油条已完成调味并放入成品盘")
		_seasoned_product_id = &""
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
	var basket_slots := lowered_basket_slots if state == &"frying" else raised_basket_slots
	fryer_visual.texture = lowered_machine_texture if state == &"frying" else raised_machine_texture
	for index in range(product_visuals.size()):
		var visible := index < capacity and occupied.has(index)
		var visual := product_visuals[index]
		var slot := basket_slots[index]
		visual.visible = visible
		visual.texture = raw_youtiao_texture if cooking else finished_texture
		visual.position = slot.position
		visual.size = slot.size
		visual.modulate = Color.WHITE
	for index in range(dough_visuals.size()):
		var visual := dough_visuals[index]
		var slot := board_dough_slots[index]
		visual.position = slot.position
		visual.size = slot.size
		visual.visible = state != &"unowned" and index < _dough_stock
	for index in range(plate_product_visuals.size()):
		var visual := plate_product_visuals[index]
		var slot := plate_product_slots[index]
		visual.visible = index < _plate_count
		visual.texture = _plate_youtiao_texture()
		visual.position = slot.position
		visual.size = slot.size
	status_label.text = "%s · %d/%d" % [_state_text(state), int(_machine.get("quantity", 0)), int(_machine.get("capacity", 0))]
	_refresh_output_source(state, occupied)
	_refresh_plate_sources()


func _refresh_output_source(state: StringName, occupied: Array[int]) -> void:
	if output_sources.is_empty():
		return
	for source_index in range(output_sources.size()):
		var output := output_sources[source_index]
		var ready_slot := state == &"ready_to_collect" and occupied.has(source_index)
		var burnt_batch_source := state == &"burnt" and source_index == 0 and not occupied.is_empty()
		output.position = product_visuals[source_index].position if ready_slot else Vector2(140.0, 0.0)
		output.size = product_visuals[source_index].size if ready_slot else Vector2(320.0, 426.0)
		output.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
		var source_ref := {"source_kind": &"youtiao_fryer_slot", "source_index": source_index, "product_id": PRODUCT_ID, "discardable": false}
		var hint := "拖这一根油条到成品盘"
		if burnt_batch_source:
			source_ref = {"source_kind": &"youtiao_batch", "source_index": -1, "product_id": PRODUCT_ID, "quantity": occupied.size(), "discardable": true}
			hint = "拖到废弃区报废整锅油条"
		output.configure(source_ref, burnt_youtiao_texture if state == &"burnt" else golden_youtiao_texture, ready_slot or burnt_batch_source, hint)
		output.visible = ready_slot or burnt_batch_source


func _refresh_prepared_slot(session: Node) -> void:
	if prepared_slot == null:
		return
	var status := Dictionary(session.call("prepared_product_slot_status", &"slot.04"))
	_plate_count = clampi(int(status.get("count", 0)), 0, PLATE_VISUAL_CAPACITY)
	prepared_slot.configure_count(int(status.get("count", 0)), StringName(status.get("reason", &"")) != &"recipe_locked", int(status.get("capacity", 4)))


func _refresh_plate_sources() -> void:
	for source_index in range(plate_sources.size()):
		var source := plate_sources[source_index]
		var visible := source_index < _plate_count
		source.position = plate_product_visuals[source_index].position
		source.size = plate_product_visuals[source_index].size
		source.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
		source.configure({
			"source_kind": &"prepared_product_slot",
			"source_slot_id": &"slot.04",
			"source_index": source_index,
			"product_id": PRODUCT_ID,
			"discardable": true,
		}, _plate_youtiao_texture(), visible, "拖这一根油条到煎饼或出餐位")
		source.visible = visible


func _select_sesame_seasoning() -> void:
	_seasoned_product_id = &"product.youtiao.sesame"
	status_message.emit("下一根出锅油条将裹芝麻")


func _select_sugar_seasoning() -> void:
	_seasoned_product_id = &"product.youtiao.sugar"
	status_message.emit("下一根出锅油条将裹白糖")


func set_workshop_preview(enabled: bool) -> void:
	_workshop_preview = enabled
	refresh_from_session()


func _create_runtime_controls() -> void:
	_sesame_button = Button.new()
	_sesame_button.text = "芝麻调味"
	_sesame_button.position = Vector2(10.0, 650.0)
	_sesame_button.size = Vector2(112.0, 38.0)
	_sesame_button.pressed.connect(_select_sesame_seasoning)
	add_child(_sesame_button)
	_sugar_button = Button.new()
	_sugar_button.text = "白糖调味"
	_sugar_button.position = Vector2(130.0, 650.0)
	_sugar_button.size = Vector2(112.0, 38.0)
	_sugar_button.pressed.connect(_select_sugar_seasoning)
	add_child(_sugar_button)
	for source_index in range(product_visuals.size()):
		var output := ProductDragSource.new()
		output.name = "FryerSlotSource%d" % (source_index + 1)
		output.ignore_texture_size = true
		output.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		output.native_drag_enabled = true
		output.visible = false
		add_child(output)
		output_sources.append(output)
	for source_index in range(plate_product_visuals.size()):
		var plate_source := ProductDragSource.new()
		plate_source.name = "PlateYoutiaoSource%d" % (source_index + 1)
		plate_source.ignore_texture_size = true
		plate_source.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		plate_source.native_drag_enabled = true
		plate_source.visible = false
		add_child(plate_source)
		plate_sources.append(plate_source)

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
	prepared_slot.visible = false
	prepared_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

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


func _plate_youtiao_texture() -> Texture2D:
	return plate_youtiao_texture if plate_youtiao_texture != null else golden_youtiao_texture


func _expand_visual_capacity() -> void:
	for index in range(1, BOARD_VISUAL_CAPACITY):
		var dough_visual := dough_visuals[0].duplicate() as TextureRect
		dough_visual.name = "DoughVisual%d" % (index + 1)
		add_child(dough_visual)
		dough_visuals.append(dough_visual)
	for index in range(2, 4):
		var basket_visual := product_visuals[0].duplicate() as TextureRect
		basket_visual.name = "ProductVisual%d" % (index + 1)
		add_child(basket_visual)
		product_visuals.append(basket_visual)
	for index in range(2, PLATE_VISUAL_CAPACITY):
		var plate_visual := plate_product_visuals[0].duplicate() as TextureRect
		plate_visual.name = "PlateProductVisual%d" % (index + 1)
		add_child(plate_visual)
		plate_product_visuals.append(plate_visual)


func _can_load_dough() -> bool:
	var state := StringName(_machine.get("state", &"unowned"))
	return state in [&"idle", &"loaded"] and int(_machine.get("quantity", 0)) < int(_machine.get("capacity", 0))


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


func _is_plate_point(point: Vector2) -> bool:
	return Rect2(Vector2(340.0, 440.0), Vector2(260.0, 210.0)).has_point(point)


func _visible_item_at(items: Array[TextureRect], point: Vector2) -> int:
	for index in range(items.size() - 1, -1, -1):
		if items[index].visible and items[index].get_rect().has_point(point):
			return index
	return -1


static func _state_text(state: StringName) -> String:
	return {
		&"unowned": "油条机未解锁", &"idle": "拖面胚到炸篮；长按案板补货", &"loaded": "点击油条机开始炸制",
		&"frying": "炸制中", &"ready_safe": "点击油条机抬起沥网", &"overcooking": "油条即将炸糊",
		&"draining": "正在沥油", &"ready_to_collect": "逐根拖油条到成品盘", &"burnt": "油条已炸糊，拖去废弃",
	}.get(state, "油条机")


static func _failure_text(reason: StringName) -> String:
	return {
		&"capacity_exceeded": "炸篮已满", &"insufficient_stock": "油条面胚不足", &"recipe_locked": "油条配方尚未解锁",
		&"equipment_not_owned": "油条机尚未解锁", &"invalid_equipment_state": "当前不能放入面胚",
	}.get(reason, "操作未完成：%s" % str(reason))


static func _restock_failure_text(reason: StringName, status: Dictionary) -> String:
	match reason:
		&"stock_locked": return "油条面胚尚未解锁"
		&"capacity_reached": return "油条面胚已补满"
		&"insufficient_coins": return "余额不足：每份需要 %d 金币" % int(status.get("unit_cost", 0))
		_: return "暂时无法补货：%s" % str(reason)
