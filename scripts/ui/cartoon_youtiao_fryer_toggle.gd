class_name CartoonYoutiaoFryerToggle
extends Control

## The cartoon fryer is the production UI for device.youtiao_fryer. GameSession
## remains the authority for stock, production time, quality, waste and storage.
signal status_message(message: String)

const DEVICE_ID := &"device.youtiao_fryer"
const RECIPE_ID := &"recipe.youtiao.plain"
const PRODUCT_ID := &"product.youtiao.plain"
const SESAME_PRODUCT_ID := &"product.youtiao.sesame"
const DOUGH_STOCK_ID := &"stock.youtiao.plain_dough"
const FINISHED_TRAY_GROWTH_ID := &"growth.capacity.youtiao_finished_tray"
const MACHINE_HOLD_THRESHOLD_SECONDS := 0.20
const MACHINE_ADD_INTERVAL_SECONDS := 0.25
const TRAY_VISUAL_CAPACITY := 4
const PLATE_VISUAL_CAPACITY := TRAY_VISUAL_CAPACITY * 2
const ADVANCED_RAISED_BASKET_OFFSET := Vector2(0.0, 24.0)
const WORKSHOP_LOCKED_AREA_MODULATE := Color(1.0, 1.0, 1.0, 0.42)
const PLATE_YOUTIAO_REGION := Rect2(174.0, 8.0, 677.0, 1500.0)
const BLACK_SESAME_YOUTIAO_REGION := Rect2(147.0, 13.0, 218.0, 484.0)
@export var reduce_motion := false

# Strings, not Texture2D references: the Inspector exposes the exact source
# artwork without making any of these PNGs a dependency of the loaded scene.
@export_group("Artwork (lazy-loaded)")
@export_file("*.png") var lowered_machine_texture_path := "res://resources/art/workstation/machines/youtiao_fryer/youtiao-fryer-cartoon-empty-drain-lowered.png"
@export_file("*.png") var raised_machine_texture_path := "res://resources/art/workstation/machines/youtiao_fryer/youtiao-fryer-cartoon-empty-drain-raised-coherent.png"
@export_file("*.png") var advanced_lowered_machine_texture_path := "res://resources/art/workstation/machines/youtiao_fryer/advanced/youtiao-fryer-cartoon-advanced-empty-drain-lowered.png"
@export_file("*.png") var advanced_raised_machine_texture_path := "res://resources/art/workstation/machines/youtiao_fryer/advanced/youtiao-fryer-cartoon-advanced-empty-drain-raised.png"
@export_file("*.png") var raw_youtiao_texture_path := "res://resources/art/workstation/machines/youtiao_fryer/youtiao-raw-dough-v4.png"
@export_file("*.png") var golden_youtiao_texture_path := "res://resources/art/workstation/machines/youtiao_fryer/youtiao-golden-v5-transparent.png"
@export_file("*.png") var burnt_youtiao_texture_path := "res://resources/art/workstation/machines/youtiao_fryer/youtiao-burnt-v4.png"
# @export_file("*.png") var plate_texture_path := "res://resources/art/workstation/machines/youtiao_fryer/youtiao-empty-serving-plate-oblique-v2.png"
@export_file("*.png") var plate_texture_path := "res://resources/art/workstation/material_slots/legacy_trays/empty-square-ingredient-tray.png"
@export_file("*.png") var black_sesame_tray_texture_path := "res://resources/art/workstation/material_slots/legacy_trays/black-sesame-square-tray-v2.png"
@export_file("*.png") var black_sesame_youtiao_texture_path := "res://resources/art/workstation/machines/youtiao_fryer/youtiao-black-sesame-v1-transparent.png"

@onready var fryer_visual: TextureRect = %FryerVisual
@onready var black_sesame_tray: TextureRect = %BlackSesameTray
@onready var plate_visual: TextureRect = $PlateVisual
@onready var product_visuals: Array[TextureRect] = [%ProductVisual1, %ProductVisual2]
@onready var plate_product_visuals: Array[TextureRect] = [%PlateProductVisual1, %PlateProductVisual2]
@onready var raised_basket_slots: Array[Control] = [%RaisedBasketSlot1, %RaisedBasketSlot2, %RaisedBasketSlot3, %RaisedBasketSlot4]
@onready var lowered_basket_slots: Array[Control] = [%LoweredBasketSlot1, %LoweredBasketSlot2, %LoweredBasketSlot3, %LoweredBasketSlot4]
@onready var plate_product_slots: Array[Control] = [%PlateProductSlot1, %PlateProductSlot2, %PlateProductSlot3, %PlateProductSlot4]
@onready var sesame_tray_product_slots: Array[Control] = [%SesameTrayProductSlot1, %SesameTrayProductSlot2, %SesameTrayProductSlot3, %SesameTrayProductSlot4]
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
var _finished_tray_unlocked := false
var _plate_count := 0
var _plate_products: Array[Dictionary] = []
var _refresh_elapsed := 0.0
var _machine_press_active := false
var _machine_hold_active := false
var _machine_hold_elapsed := 0.0
var _machine_add_elapsed := 0.0
var _workshop_preview := false
var _workshop_advanced_preview := false
var _session_refresh_pending := false
var _texture_cache: Dictionary = {}
var lowered_machine_texture: Texture2D
var raised_machine_texture: Texture2D
var advanced_lowered_machine_texture: Texture2D
var advanced_raised_machine_texture: Texture2D
var raw_youtiao_texture: Texture2D
var golden_youtiao_texture: Texture2D
var plate_youtiao_texture: Texture2D
var black_sesame_youtiao_texture: Texture2D
var burnt_youtiao_texture: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	start_button = fryer_visual
	lift_button = fryer_visual
	state_label = status_label
	_expand_visual_capacity()
	_create_runtime_controls()
	_connect_session_signals()
	refresh_from_session()


func _process(delta: float) -> void:
	_advance_machine_hold(delta)
	_refresh_elapsed += maxf(delta, 0.0)
	if _refresh_elapsed >= 0.10:
		_refresh_elapsed = 0.0
		# Once a batch is ready to collect, only a player action can change its
		# state. Do not keep rebuilding the draggable sticks and their alpha hit
		# regions every 100 ms while the player moves one to either serving tray.
		# The time-driven fryer states below still refresh at the same cadence.
		if not _requires_timed_session_refresh():
			return
		var viewport := get_viewport()
		if viewport != null and viewport.gui_is_dragging():
			return
		# Do not reconfigure live drag controls in the middle of a native drag.
		# Repeatedly changing their rects and disabled state made the preview feel
		# sticky even though the product was already being dragged.
		if not _has_active_product_drag():
			refresh_from_session()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag_or_click(event.position)
		else:
			_finish_drag_or_click(event.position)
		accept_event()


func _has_point(point: Vector2) -> bool:
	# This root also spans the adjacent pancake toppings. Restrict its input
	# bounds to the fryer and its own finished-product trays so the invisible
	# portion of the Control cannot swallow their hover, drag, or hold gestures.
	# A sibling hotspot can cause Godot to recalculate the hovered Control while
	# this preview node is still entering the scene tree. @onready references are
	# not assigned until this node's _ready(), so it cannot claim input yet.
	if fryer_visual != null and fryer_visual.get_rect().has_point(point):
		return true
	if plate_visual != null and plate_visual.visible and plate_visual.get_rect().has_point(point):
		return true
	return black_sesame_tray != null and black_sesame_tray.visible and black_sesame_tray.get_rect().has_point(point)


func _input(event: InputEvent) -> void:
	# Continue tracking a press that began on the fryer, even if it is released
	# outside this Control's bounds.
	if not _machine_press_active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drag_or_click(get_local_mouse_position())
		get_viewport().set_input_as_handled()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or StringName(Dictionary(data).get("kind", &"")) != &"product_source":
		return false
	var source_ref := Dictionary(Dictionary(data).get("source_ref", {}))
	if StringName(source_ref.get("source_kind", &"")) == &"youtiao_dough":
		return true
	var can_store_finished_youtiao := _finished_tray_unlocked and (
		StringName(source_ref.get("source_kind", &"")) == &"youtiao_fryer_slot"
		and StringName(_machine.get("state", &"")) == &"ready_to_collect"
	)
	return can_store_finished_youtiao and (_is_plate_point(_at_position) or _is_black_sesame_tray_point(_at_position))


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var source_ref := Dictionary(Dictionary(data).get("source_ref", {}))
	if StringName(source_ref.get("source_kind", &"")) == &"youtiao_dough":
		_load_dough(StringName(source_ref.get("recipe_id", RECIPE_ID)))
		return
	if StringName(source_ref.get("source_kind", &"")) != &"youtiao_fryer_slot":
		return
	var source_index := int(source_ref.get("source_index", -1))
	if _is_black_sesame_tray_point(_at_position):
		_store_fryer_slot_on_plate(source_index, SESAME_PRODUCT_ID)
	elif _is_plate_point(_at_position):
		_store_fryer_slot_on_plate(source_index)


func select_recipe(_recipe_id: StringName) -> void:
	pass


func refresh_from_session() -> void:
	# Public refresh requests can arrive from order delivery or another station.
	# Never mutate the live Control that Godot is using as a native drag source;
	# the drag-ended callback below flushes the newest session state instead.
	if is_node_ready() and _has_active_product_drag():
		_session_refresh_pending = true
		return
	var session := get_node_or_null("/root/GameSession")
	if session == null or not session.has_method("f3_machine_snapshot"):
		return
	_machine = Dictionary(session.call("f3_machine_snapshot", DEVICE_ID))
	if _workshop_preview:
		visible = true
		_machine["state"] = &"idle"
		_machine["capacity"] = 4
		_machine["quantity"] = 0
	var progression := Dictionary(session.call("five_area_progression_snapshot")) if session.has_method("five_area_progression_snapshot") else {}
	var area_unlocked := Array(progression.get("unlocked_area_ids", [])).has("area.youtiao")
	_finished_tray_unlocked = Array(progression.get("owned_growth_ids", [])).has(FINISHED_TRAY_GROWTH_ID)
	_workshop_advanced_preview = _workshop_preview and area_unlocked
	if area_unlocked or _workshop_preview:
		_ensure_visual_resources()
	modulate = WORKSHOP_LOCKED_AREA_MODULATE if _workshop_preview and not area_unlocked else Color.WHITE
	var unlocked_products := Array(progression.get("unlocked_product_ids", []))
	var sesame_unlocked := unlocked_products.has(SESAME_PRODUCT_ID)
	plate_visual.visible = _finished_tray_unlocked or _workshop_preview
	plate_visual.self_modulate = WORKSHOP_LOCKED_AREA_MODULATE if _workshop_preview and not _finished_tray_unlocked else Color.WHITE
	# The sesame tray needs both the general finished-product tray and the
	# sesame recipe.  Before the general tray is unlocked, all fried sticks stay
	# in the raised filter basket.
	black_sesame_tray.visible = (_finished_tray_unlocked and sesame_unlocked) or _workshop_preview
	# The whole fryer is already translucent while its area is locked. Avoid
	# multiplying that alpha; once the fryer is unlocked, only the still-locked
	# sesame tray receives the same workshop-preview treatment.
	black_sesame_tray.self_modulate = WORKSHOP_LOCKED_AREA_MODULATE if _workshop_preview and area_unlocked and (not _finished_tray_unlocked or not sesame_unlocked) else Color.WHITE
	if _workshop_preview:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		mouse_filter = Control.MOUSE_FILTER_STOP
	var inventory := Dictionary(session.call("inventory_snapshot")) if session.has_method("inventory_snapshot") else {}
	_dough_stock = maxi(int(inventory.get(str(DOUGH_STOCK_ID), 0)), 0)
	_refresh_prepared_slot(session)
	_apply_snapshot()
	_session_refresh_pending = false


func _begin_drag_or_click(point: Vector2) -> void:
	if fryer_visual.get_rect().has_point(point):
		_begin_machine_gesture()


func _finish_drag_or_click(point: Vector2) -> void:
	if not _machine_press_active:
		return
	var was_hold := _machine_hold_active
	_end_machine_gesture()
	if not was_hold:
		_perform_machine_click()


func _begin_machine_gesture() -> void:
	_machine_press_active = true
	_machine_hold_active = false
	_machine_hold_elapsed = 0.0
	_machine_add_elapsed = 0.0


func _advance_machine_hold(delta: float) -> void:
	if not _machine_press_active:
		return
	if not _machine_hold_active:
		_machine_hold_elapsed += maxf(delta, 0.0)
		if _machine_hold_elapsed + 0.000001 < MACHINE_HOLD_THRESHOLD_SECONDS:
			return
		_start_machine_dough_hold()
		return
	if not _can_load_dough():
		_end_machine_gesture()
		status_message.emit("炸篮已满，点击油条机开始炸制")
		return
	if _dough_stock > 0:
		_machine_add_elapsed += maxf(delta, 0.0)
		if _machine_add_elapsed + 0.000001 >= MACHINE_ADD_INTERVAL_SECONDS:
			_machine_add_elapsed = 0.0
			_load_dough(RECIPE_ID)
		return
	var session := get_node_or_null("/root/GameSession")
	var result := Dictionary(session.call("advance_five_area_restock_hold", DOUGH_STOCK_ID, delta)) if session != null else {"success": false, "reason": &"no_game_session"}
	if int(result.get("completed_units", 0)) > 0:
		for _unit in int(result.get("completed_units", 0)):
			_load_dough(RECIPE_ID)
	if bool(result.get("auto_stopped", false)) or not bool(result.get("success", false)):
		_end_machine_gesture()
		status_message.emit(_restock_failure_text(StringName(result.get("reason", &"")), result))
	refresh_from_session()


func _start_machine_dough_hold() -> void:
	var session := get_node_or_null("/root/GameSession")
	var status := Dictionary(session.call("five_area_restock_status", DOUGH_STOCK_ID)) if session != null else {"success": false, "reason": &"no_game_session"}
	var can_restock := bool(status.get("success", false)) and int(status.get("current_stock", 0)) < int(status.get("capacity", 0)) and int(status.get("coins", 0)) >= int(status.get("unit_cost", 0))
	if _can_load_dough() and (_dough_stock > 0 or can_restock):
		_machine_hold_active = true
		status_message.emit("持续长按油条机添加油条面胚；每完成一份才扣金币")
		return
	_end_machine_gesture()
	if not _can_load_dough():
		status_message.emit("炸篮已满，点击油条机开始炸制")
		return
	if not bool(status.get("success", false)):
		status_message.emit(_restock_failure_text(StringName(status.get("reason", &"")), status))
	else:
		status_message.emit("余额不足：每份需要 %d 金币" % int(status.get("unit_cost", 0)))


func _end_machine_gesture() -> void:
	_machine_press_active = false
	_machine_hold_active = false
	_machine_hold_elapsed = 0.0
	_machine_add_elapsed = 0.0


func _load_dough(recipe_id: StringName = RECIPE_ID) -> void:
	var session := get_node_or_null("/root/GameSession")
	var result := Dictionary(session.call("load_f3_youtiao", recipe_id, 1)) if session != null else {"success": false, "reason": &"no_game_session"}
	if bool(result.get("success", false)):
		status_message.emit("油条面胚已加入炸篮")
	else:
		status_message.emit(_failure_text(StringName(result.get("reason", &""))))
	refresh_from_session()


func _store_fryer_slot_on_plate(source_index: int, product_id: StringName = &"") -> void:
	var session := get_node_or_null("/root/GameSession")
	var final_product_id := product_id
	var result := Dictionary(session.call("store_ready_youtiao_slot", &"slot.04", source_index, final_product_id)) if session != null else {"success": false, "reason": &"no_game_session"}
	if bool(result.get("success", false)):
		status_message.emit("芝麻油条已放入芝麻成品盘" if final_product_id == SESAME_PRODUCT_ID else "油条已放入成品盘")
	else:
		status_message.emit(_failure_text(StringName(result.get("reason", &""))))
	_request_session_refresh()


func _perform_machine_click() -> void:
	var state := StringName(_machine.get("state", &"idle"))
	var action := &"start" if state == &"loaded" else &"lift" if state in [&"ready_safe", &"overcooking"] else &""
	if action.is_empty():
		status_message.emit("长按油条机添加面胚" if state == &"idle" else _state_text(state))
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
	# Reaching the target fry time does not itself lift the basic basket. Keep
	# both its artwork and product anchors lowered until the player clicks it.
	var basket_lowered := state in [&"frying", &"ready_safe", &"overcooking"]
	var finished_texture := burnt_youtiao_texture if state == &"burnt" else golden_youtiao_texture
	var basket_slots := lowered_basket_slots if basket_lowered else raised_basket_slots
	var use_advanced_art := int(_machine.get("tier", 0)) >= 1 or _workshop_advanced_preview
	if use_advanced_art and advanced_lowered_machine_texture != null and advanced_raised_machine_texture != null:
		fryer_visual.texture = advanced_lowered_machine_texture if basket_lowered else advanced_raised_machine_texture
	else:
		fryer_visual.texture = lowered_machine_texture if basket_lowered else raised_machine_texture
	for index in range(product_visuals.size()):
		var visible := index < capacity and occupied.has(index)
		var visual := product_visuals[index]
		var slot := basket_slots[index]
		visual.visible = visible
		visual.texture = raw_youtiao_texture if cooking else finished_texture
		# The advanced raised artwork places the wire-mesh bed lower than the
		# basic fryer. Keep the basic authored slots intact and move only the
		# advanced raised batch onto that mesh plane.
		visual.position = slot.position + ADVANCED_RAISED_BASKET_OFFSET if use_advanced_art and not basket_lowered else slot.position
		visual.size = slot.size
		visual.modulate = Color.WHITE
	for index in range(plate_product_visuals.size()):
		var visual := plate_product_visuals[index]
		var product_id := StringName(_plate_products[index].get("product_id", PRODUCT_ID)) if index < _plate_products.size() else PRODUCT_ID
		var product_rect := _prepared_product_rect(index, product_id)
		visual.visible = _finished_tray_unlocked and index < _plate_count
		visual.texture = _prepared_youtiao_texture(product_id)
		visual.position = product_rect.position
		visual.size = product_rect.size
	status_label.visible = not _workshop_preview
	status_label.text = "%s · %d/%d" % [_state_text(state), int(_machine.get("quantity", 0)), int(_machine.get("capacity", 0))]
	if _workshop_preview:
		# A workshop is a layout preview, not a frozen production snapshot.
		# Never leak current stock, prepared goods, or runtime controls into it.
		for visual in product_visuals + plate_product_visuals:
			visual.visible = false
		for control in output_sources + plate_sources:
			control.visible = false
		if prepared_slot != null: prepared_slot.visible = false
		if waste_target != null: waste_target.visible = false
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
		var source_ref := {"source_kind": &"youtiao_fryer_slot", "source_index": source_index, "product_id": PRODUCT_ID, "discardable": ready_slot}
		var hint := "拖这一根油条到顾客订单或成品盘"
		if burnt_batch_source:
			source_ref = {"source_kind": &"youtiao_batch", "source_index": -1, "product_id": PRODUCT_ID, "quantity": occupied.size(), "discardable": true}
			hint = "拖到废弃区报废整锅油条"
		var product_texture := burnt_youtiao_texture if state == &"burnt" else golden_youtiao_texture
		output.configure(source_ref, product_texture, ready_slot or burnt_batch_source, hint)
		# The four visual sticks overlap for depth, but their transparent padding
		# must not overlap as hit areas.  Alpha hit testing keeps each visible stick
		# independently draggable without changing the authored artwork layout.
		_set_youtiao_alpha_hit_region(output, product_texture, ready_slot)
		output.visible = ready_slot or burnt_batch_source


func _is_black_sesame_tray_point(point: Vector2) -> bool:
	return black_sesame_tray.visible and black_sesame_tray.get_rect().has_point(point)


func _refresh_prepared_slot(session: Node) -> void:
	if prepared_slot == null:
		return
	var status := Dictionary(session.call("prepared_product_slot_status", &"slot.04"))
	_plate_products.clear()
	for product_value in Array(status.get("products", [])):
		_plate_products.append(Dictionary(product_value).duplicate(true))
	_plate_count = clampi(_plate_products.size(), 0, PLATE_VISUAL_CAPACITY)
	prepared_slot.configure_count(int(status.get("count", 0)), StringName(status.get("reason", &"")) != &"recipe_locked", int(status.get("capacity", 4)))


func _refresh_plate_sources() -> void:
	for source_index in range(plate_sources.size()):
		var source := plate_sources[source_index]
		var visible := _finished_tray_unlocked and source_index < _plate_count
		var product_id := StringName(_plate_products[source_index].get("product_id", PRODUCT_ID)) if visible and source_index < _plate_products.size() else PRODUCT_ID
		source.position = plate_product_visuals[source_index].position
		source.size = plate_product_visuals[source_index].size
		source.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
		var product_texture := _prepared_youtiao_texture(product_id)
		source.configure({
			"source_kind": &"prepared_product_slot",
			"source_slot_id": &"slot.04",
			"source_index": source_index,
			"product_id": product_id,
			"discardable": true,
		}, product_texture, visible, "从%s拖这一根%s到出餐位" % ["芝麻成品盘" if product_id == SESAME_PRODUCT_ID else "成品盘", "芝麻油条" if product_id == SESAME_PRODUCT_ID else "油条"])
		_set_youtiao_alpha_hit_region(source, product_texture, visible)
		source.visible = visible


func _prepared_youtiao_texture(product_id: StringName) -> Texture2D:
	return black_sesame_youtiao_texture if product_id == SESAME_PRODUCT_ID else _plate_youtiao_texture()


func _set_youtiao_alpha_hit_region(source: ProductDragSource, product_texture: Texture2D, enabled: bool) -> void:
	var regions: Array[Dictionary] = []
	if enabled:
		regions.append({"texture": product_texture, "rect": Rect2(Vector2.ZERO, source.size)})
	source.set_alpha_hit_regions(regions)


func _prepared_product_rect(product_index: int, product_id: StringName) -> Rect2:
	var sesame_product := product_id == SESAME_PRODUCT_ID
	var display_index := _prepared_product_display_index(product_index, sesame_product)
	if sesame_product:
		var sesame_index := clampi(display_index, 0, sesame_tray_product_slots.size() - 1)
		var sesame_slot := sesame_tray_product_slots[sesame_index]
		return Rect2(sesame_slot.position, sesame_slot.size)
	var plate_index := clampi(display_index, 0, plate_product_slots.size() - 1)
	var plate_slot := plate_product_slots[plate_index]
	return Rect2(plate_slot.position, plate_slot.size)


func _prepared_product_display_index(product_index: int, sesame_product: bool) -> int:
	var result := 0
	for index in range(mini(product_index, _plate_products.size())):
		var prior_product_id := StringName(_plate_products[index].get("product_id", PRODUCT_ID))
		if (prior_product_id == SESAME_PRODUCT_ID) == sesame_product:
			result += 1
	return result


func set_workshop_preview(enabled: bool) -> void:
	_workshop_preview = enabled
	refresh_from_session()


func _create_runtime_controls() -> void:
	for source_index in range(product_visuals.size()):
		var output := ProductDragSource.new()
		output.name = "FryerSlotSource%d" % (source_index + 1)
		# A finished stick can be dragged across the black-sesame tray.  Keep the
		# source above that tray while it is being dragged so the target artwork
		# cannot visually cover the stick.
		output.z_index = black_sesame_tray.z_index + 1
		output.ignore_texture_size = true
		output.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		output.native_drag_enabled = true
		output.drag_threshold_pixels = 4.0
		output.visible = false
		add_child(output)
		output.drag_ended.connect(_on_product_drag_ended)
		output_sources.append(output)
	for source_index in range(plate_product_visuals.size()):
		var plate_source := ProductDragSource.new()
		plate_source.name = "PlateYoutiaoSource%d" % (source_index + 1)
		plate_source.z_index = black_sesame_tray.z_index + 1
		plate_source.ignore_texture_size = true
		plate_source.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		plate_source.native_drag_enabled = true
		plate_source.drag_threshold_pixels = 4.0
		# A stored oil strip stays draggable, while drops over it continue to be
		# evaluated by this fryer as the plate or sesame-tray destination.
		plate_source.set_drop_forward_target(self)
		plate_source.visible = false
		add_child(plate_source)
		plate_source.drag_ended.connect(_on_product_drag_ended)
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


func _ensure_visual_resources() -> void:
	if raised_machine_texture != null:
		return
	lowered_machine_texture = _load_texture(lowered_machine_texture_path)
	raised_machine_texture = _load_texture(raised_machine_texture_path)
	advanced_lowered_machine_texture = _load_texture(advanced_lowered_machine_texture_path)
	advanced_raised_machine_texture = _load_texture(advanced_raised_machine_texture_path)
	raw_youtiao_texture = _load_texture(raw_youtiao_texture_path)
	golden_youtiao_texture = _load_texture(golden_youtiao_texture_path)
	burnt_youtiao_texture = _load_texture(burnt_youtiao_texture_path)
	var plate_texture := _load_texture(plate_texture_path)
	black_sesame_tray.texture = _load_texture(black_sesame_tray_texture_path)
	var black_sesame_texture := _load_texture(black_sesame_youtiao_texture_path)
	if golden_youtiao_texture != null:
		plate_youtiao_texture = AtlasTexture.new()
		plate_youtiao_texture.atlas = golden_youtiao_texture
		plate_youtiao_texture.region = PLATE_YOUTIAO_REGION
	if black_sesame_texture != null:
		black_sesame_youtiao_texture = AtlasTexture.new()
		black_sesame_youtiao_texture.atlas = black_sesame_texture
		black_sesame_youtiao_texture.region = BLACK_SESAME_YOUTIAO_REGION
	plate_visual.texture = plate_texture


func _load_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path] as Texture2D
	var texture := load(path) as Texture2D
	_texture_cache[path] = texture
	return texture


func _expand_visual_capacity() -> void:
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


func _is_plate_point(point: Vector2) -> bool:
	# Treat the entire rendered serving plate as a drop target.  The old
	# hand-authored rectangle began well inside the artwork, so drops on the
	# visible left and upper portions of the plate were silently rejected.
	return _finished_tray_unlocked and plate_visual != null and plate_visual.get_rect().has_point(point)


func _has_active_product_drag() -> bool:
	for source in output_sources + plate_sources:
		if source.is_native_drag_active():
			return true
	return false


func _connect_session_signals() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null or not session.has_signal("prepared_product_slots_changed"):
		return
	var prepared_slots_signal := Signal(session, &"prepared_product_slots_changed")
	if not prepared_slots_signal.is_connected(_on_prepared_product_slots_changed):
		prepared_slots_signal.connect(_on_prepared_product_slots_changed)


func _on_prepared_product_slots_changed(_snapshot: Dictionary = {}) -> void:
	_request_session_refresh()


func _request_session_refresh() -> void:
	if _has_active_product_drag():
		_session_refresh_pending = true
		return
	refresh_from_session()


func _on_product_drag_ended(_source_ref: Dictionary, _successful: bool) -> void:
	# A fryer-slot youtiao can now land directly on a pancake. That consumes the
	# production slot without touching the prepared-product signal this control
	# previously used to trigger a redraw, so always reconcile after any release.
	_session_refresh_pending = true
	_flush_pending_session_refresh.call_deferred()


func _flush_pending_session_refresh() -> void:
	if not _session_refresh_pending or _has_active_product_drag():
		return
	refresh_from_session()


func _requires_timed_session_refresh() -> bool:
	return StringName(_machine.get("state", &"")) in [
		&"frying",
		&"ready_safe",
		&"overcooking",
		&"draining",
	]


func _state_text(state: StringName) -> String:
	return {
		&"unowned": "油条机未解锁", &"idle": "长按油条机添加面胚", &"loaded": "点击油条机开始炸制",
		&"frying": "炸制中", &"ready_safe": "点击油条机抬起沥网", &"overcooking": "油条即将炸糊",
		&"draining": "正在沥油", &"ready_to_collect": "逐根拖油条到顾客订单或成品盘" if _finished_tray_unlocked else "逐根拖油条到顾客订单；成品盘尚未解锁", &"burnt": "油条已炸糊，拖去废弃",
	}.get(state, "油条机")


static func _failure_text(reason: StringName) -> String:
	return {
		&"capacity_exceeded": "炸篮已满", &"insufficient_stock": "油条面胚不足", &"recipe_locked": "油条配方尚未解锁",
		&"equipment_not_owned": "油条机尚未解锁", &"invalid_equipment_state": "当前不能放入面胚",
		&"finished_tray_locked": "成品盘尚未解锁，炸好的油条请暂存在滤网中",
		&"prepared_product_slot_full": "成品盘已满，请先出餐或废弃盘内油条",
	}.get(reason, "操作未完成：%s" % str(reason))


static func _restock_failure_text(reason: StringName, status: Dictionary) -> String:
	match reason:
		&"stock_locked": return "油条面胚尚未解锁"
		&"capacity_reached": return "油条面胚已补满"
		&"insufficient_coins": return "余额不足：每份需要 %d 金币" % int(status.get("unit_cost", 0))
		_: return "暂时无法补货：%s" % str(reason)
