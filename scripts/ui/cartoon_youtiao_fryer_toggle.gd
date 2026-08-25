@tool
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
const WORKSHOP_LOCKED_AREA_MODULATE := Color(1.0, 1.0, 1.0, 0.42)
const PLATE_YOUTIAO_REGION := Rect2(174.0, 8.0, 677.0, 1500.0)
const BLACK_SESAME_YOUTIAO_REGION := Rect2(147.0, 13.0, 218.0, 484.0)
const RAW_YOUTIAO_REGION := Rect2(97.0, 53.0, 321.0, 403.0)
@export var reduce_motion := false

@export_group("Editor preview")
@export_enum("Basic", "Advanced") var editor_preview_tier := 0
@export_enum("Raised empty", "Raised dough", "Lowered dough", "Lowered finished", "Raised finished", "Raised burnt") var editor_preview_state := 1
@export var editor_preview_trays := true

@export_group("Fryer layout")
@export var basket_slot_size := Vector2(75.0, 77.0)
@export var basket_slot_step := Vector2(39.0, 0.0)

@export_subgroup("Basic raised")
@export var basic_raised_machine_rect := Rect2(0.0, 80.0, 256.0, 341.0)
@export var basic_raised_basket_position := Vector2(62.0, 66.0)

@export_subgroup("Basic lowered")
@export var basic_lowered_machine_rect := Rect2(0.0, 80.0, 256.0, 341.0)
@export var basic_lowered_basket_position := Vector2(62.0, 132.0)

@export_subgroup("Advanced raised")
@export var advanced_raised_machine_rect := Rect2(0.0, 80.0, 256.0, 341.0)
@export var advanced_raised_basket_position := Vector2(62.0, 90.0)

@export_subgroup("Advanced lowered")
@export var advanced_lowered_machine_rect := Rect2(0.0, 80.0, 256.0, 341.0)
@export var advanced_lowered_basket_position := Vector2(62.0, 132.0)

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

@onready var fryer_assembly: Control = %FryerAssembly
@onready var fryer_visual: TextureRect = %FryerVisual
@onready var basket_products: Control = %BasketProducts
@onready var fryer_slot_sources: Array[ProductDragSource] = [%ProductSource1, %ProductSource2, %ProductSource3, %ProductSource4]
@onready var burnt_batch_source: ProductDragSource = %BurntBatchSource
@onready var plain_tray: YoutiaoTrayView = %PlainTray
@onready var sesame_tray: YoutiaoTrayView = %SesameTray
@onready var status_label: Label = %StatusLabel

# Compatibility surface consumed by FiveAreaWorkstation and tutorial routing.
var output_sources: Array[ProductDragSource] = []
var plate_sources: Array[ProductDragSource] = []
var waste_source: ProductDragSource
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
var _editor_preview_signature := 0
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
	if Engine.is_editor_hint():
		_ensure_visual_resources()
		_apply_editor_preview()
		return
	_configure_component_controls()
	_connect_session_signals()
	refresh_from_session()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		var signature := _preview_signature()
		if signature != _editor_preview_signature:
			_apply_editor_preview()
		return
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
	if _control_contains_local_point(fryer_visual, point):
		return true
	if plain_tray != null and plain_tray.visible and _control_contains_local_point(plain_tray, point):
		return true
	return sesame_tray != null and sesame_tray.visible and _control_contains_local_point(sesame_tray, point)


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
	plain_tray.visible = _finished_tray_unlocked or _workshop_preview
	plain_tray.self_modulate = WORKSHOP_LOCKED_AREA_MODULATE if _workshop_preview and not _finished_tray_unlocked else Color.WHITE
	plain_tray.set_drop_enabled(_finished_tray_unlocked and not _workshop_preview)
	# The sesame tray needs both the general finished-product tray and the
	# sesame recipe.  Before the general tray is unlocked, all fried sticks stay
	# in the raised filter basket.
	sesame_tray.visible = (_finished_tray_unlocked and sesame_unlocked) or _workshop_preview
	# The whole fryer is already translucent while its area is locked. Avoid
	# multiplying that alpha; once the fryer is unlocked, only the still-locked
	# sesame tray receives the same workshop-preview treatment.
	sesame_tray.self_modulate = WORKSHOP_LOCKED_AREA_MODULATE if _workshop_preview and area_unlocked and (not _finished_tray_unlocked or not sesame_unlocked) else Color.WHITE
	sesame_tray.set_drop_enabled(_finished_tray_unlocked and sesame_unlocked and not _workshop_preview)
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
	if _control_contains_local_point(fryer_visual, point):
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
	var capacity := clampi(int(_machine.get("capacity", 0)), 0, output_sources.size())
	var occupied := _occupied_slots()
	var cooking := state in [&"loaded", &"frying"]
	# Reaching the target fry time does not itself lift the basic basket. Keep
	# both its artwork and the single basket-products group lowered until clicked.
	var basket_lowered := state in [&"frying", &"ready_safe", &"overcooking"]
	var finished_texture := burnt_youtiao_texture if state == &"burnt" else golden_youtiao_texture
	var use_advanced_art := int(_machine.get("tier", 0)) >= 1 or _workshop_advanced_preview
	_apply_fryer_layout(use_advanced_art, basket_lowered)
	if use_advanced_art and advanced_lowered_machine_texture != null and advanced_raised_machine_texture != null:
		fryer_visual.texture = advanced_lowered_machine_texture if basket_lowered else advanced_raised_machine_texture
	else:
		fryer_visual.texture = lowered_machine_texture if basket_lowered else raised_machine_texture
	_refresh_output_sources(state, occupied, capacity, raw_youtiao_texture if cooking else finished_texture)
	_refresh_plate_sources()
	status_label.visible = not _workshop_preview
	status_label.text = "%s · %d/%d" % [_state_text(state), int(_machine.get("quantity", 0)), int(_machine.get("capacity", 0))]


func _apply_editor_preview() -> void:
	if not is_node_ready():
		return
	_editor_preview_signature = _preview_signature()
	_ensure_visual_resources()
	var use_advanced_art := editor_preview_tier >= 1
	var basket_lowered := editor_preview_state in [2, 3]
	_apply_fryer_layout(use_advanced_art, basket_lowered)
	if use_advanced_art:
		fryer_visual.texture = advanced_lowered_machine_texture if basket_lowered else advanced_raised_machine_texture
	else:
		fryer_visual.texture = lowered_machine_texture if basket_lowered else raised_machine_texture
	var product_texture: Texture2D = null
	match editor_preview_state:
		1, 2: product_texture = raw_youtiao_texture
		3, 4: product_texture = golden_youtiao_texture
		5: product_texture = burnt_youtiao_texture
	for source in fryer_slot_sources:
		source.texture_normal = product_texture
		source.texture_disabled = product_texture
		source.disabled = true
		source.mouse_filter = Control.MOUSE_FILTER_IGNORE
		source.self_modulate = Color.WHITE
		source.visible = product_texture != null
	burnt_batch_source.visible = false
	burnt_batch_source.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plain_tray.visible = editor_preview_trays
	sesame_tray.visible = editor_preview_trays
	plain_tray.self_modulate = Color.WHITE
	sesame_tray.self_modulate = Color.WHITE
	plain_tray.preview_products(_plate_youtiao_texture(), 4 if editor_preview_trays else 0)
	sesame_tray.preview_products(black_sesame_youtiao_texture, 4 if editor_preview_trays else 0)
	status_label.visible = true
	status_label.text = "布局预览 · %s · %s" % ["高级" if use_advanced_art else "初级", ["抬起空篮", "抬起面坯", "落下面坯", "落下成品", "抬起成品", "抬起焦糊"][editor_preview_state]]


func _preview_signature() -> int:
	return [
		editor_preview_tier,
		editor_preview_state,
		editor_preview_trays,
		basket_slot_size,
		basket_slot_step,
		basic_raised_machine_rect,
		basic_raised_basket_position,
		basic_lowered_machine_rect,
		basic_lowered_basket_position,
		advanced_raised_machine_rect,
		advanced_raised_basket_position,
		advanced_lowered_machine_rect,
		advanced_lowered_basket_position,
	].hash()


func _apply_fryer_layout(use_advanced_art: bool, basket_lowered: bool) -> void:
	var machine_rect := basic_lowered_machine_rect if basket_lowered else basic_raised_machine_rect
	var basket_position := basic_lowered_basket_position if basket_lowered else basic_raised_basket_position
	if use_advanced_art:
		machine_rect = advanced_lowered_machine_rect if basket_lowered else advanced_raised_machine_rect
		basket_position = advanced_lowered_basket_position if basket_lowered else advanced_raised_basket_position
	fryer_visual.position = machine_rect.position
	fryer_visual.size = machine_rect.size
	basket_products.position = basket_position
	basket_products.size = Vector2(
		basket_slot_size.x + basket_slot_step.x * float(maxi(fryer_slot_sources.size() - 1, 0)),
		basket_slot_size.y + basket_slot_step.y * float(maxi(fryer_slot_sources.size() - 1, 0)),
	)
	for source_index in range(fryer_slot_sources.size()):
		var source := fryer_slot_sources[source_index]
		source.position = basket_slot_step * float(source_index)
		source.size = basket_slot_size
	burnt_batch_source.position = machine_rect.position
	burnt_batch_source.size = machine_rect.size


func _refresh_output_sources(state: StringName, occupied: Array[int], capacity: int, product_texture: Texture2D) -> void:
	if output_sources.is_empty():
		return
	for source_index in range(output_sources.size()):
		var output := output_sources[source_index]
		var occupied_slot := source_index < capacity and occupied.has(source_index)
		var ready_slot := state == &"ready_to_collect" and occupied.has(source_index)
		output.self_modulate = Color.WHITE
		output.configure({
			"source_kind": &"youtiao_fryer_slot",
			"source_index": source_index,
			"product_id": PRODUCT_ID,
			"discardable": ready_slot,
		}, product_texture, ready_slot, "拖这一根油条到顾客订单或成品盘")
		# The four visual sticks overlap for depth, but their transparent padding
		# must not overlap as hit areas.  Alpha hit testing keeps each visible stick
		# independently draggable while the same node remains the visible artwork.
		_set_youtiao_alpha_hit_region(output, product_texture, ready_slot)
		output.mouse_filter = Control.MOUSE_FILTER_STOP if ready_slot else Control.MOUSE_FILTER_IGNORE
		output.visible = occupied_slot and not _workshop_preview
	var burnt_available := state == &"burnt" and not occupied.is_empty() and not _workshop_preview
	burnt_batch_source.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	burnt_batch_source.configure({
		"source_kind": &"youtiao_batch",
		"source_index": -1,
		"product_id": PRODUCT_ID,
		"quantity": occupied.size(),
		"discardable": true,
	}, burnt_youtiao_texture, burnt_available, "拖到废弃区报废整锅油条")
	burnt_batch_source.set_alpha_hit_regions([])
	burnt_batch_source.mouse_filter = Control.MOUSE_FILTER_STOP if burnt_available else Control.MOUSE_FILTER_IGNORE
	burnt_batch_source.visible = burnt_available


func _is_black_sesame_tray_point(point: Vector2) -> bool:
	return sesame_tray.visible and _control_contains_local_point(sesame_tray, point)


func _refresh_prepared_slot(session: Node) -> void:
	var status := Dictionary(session.call("prepared_product_slot_status", &"slot.04"))
	_plate_products.clear()
	for product_value in Array(status.get("products", [])):
		_plate_products.append(Dictionary(product_value).duplicate(true))
	_plate_count = clampi(_plate_products.size(), 0, PLATE_VISUAL_CAPACITY)


func _refresh_plate_sources() -> void:
	var plain_entries: Array[Dictionary] = []
	var sesame_entries: Array[Dictionary] = []
	for source_index in range(mini(_plate_count, _plate_products.size())):
		var product_id := StringName(_plate_products[source_index].get("product_id", PRODUCT_ID))
		var entry := {"source_index": source_index, "product_id": product_id}
		if product_id == SESAME_PRODUCT_ID:
			sesame_entries.append(entry)
		else:
			plain_entries.append(entry)
	plain_tray.configure_products(plain_entries, _plate_youtiao_texture(), _finished_tray_unlocked and not _workshop_preview)
	sesame_tray.configure_products(sesame_entries, black_sesame_youtiao_texture, _finished_tray_unlocked and sesame_tray.visible and not _workshop_preview)


func _set_youtiao_alpha_hit_region(source: ProductDragSource, product_texture: Texture2D, enabled: bool) -> void:
	var regions: Array[Dictionary] = []
	if enabled:
		regions.append({"texture": product_texture, "rect": Rect2(Vector2.ZERO, source.size)})
	source.set_alpha_hit_regions(regions)


func set_workshop_preview(enabled: bool) -> void:
	_workshop_preview = enabled
	refresh_from_session()


func _configure_component_controls() -> void:
	output_sources.append_array(fryer_slot_sources)
	plate_sources.append_array(plain_tray.product_sources)
	plate_sources.append_array(sesame_tray.product_sources)
	waste_source = burnt_batch_source
	for source in output_sources:
		source.native_drag_enabled = true
		source.drag_threshold_pixels = 4.0
		source.drag_ended.connect(_on_product_drag_ended)
	burnt_batch_source.native_drag_enabled = true
	burnt_batch_source.drag_threshold_pixels = 4.0
	burnt_batch_source.drag_ended.connect(_on_product_drag_ended)
	plain_tray.fryer_slot_drop_requested.connect(_on_tray_fryer_slot_drop_requested)
	sesame_tray.fryer_slot_drop_requested.connect(_on_tray_fryer_slot_drop_requested)
	plain_tray.product_drag_ended.connect(_on_product_drag_ended)
	sesame_tray.product_drag_ended.connect(_on_product_drag_ended)


func _on_tray_fryer_slot_drop_requested(source_index: int, destination_product_id: StringName) -> void:
	_store_fryer_slot_on_plate(source_index, destination_product_id)


func _plate_youtiao_texture() -> Texture2D:
	return plate_youtiao_texture if plate_youtiao_texture != null else golden_youtiao_texture


func _ensure_visual_resources() -> void:
	if raised_machine_texture != null:
		return
	lowered_machine_texture = _load_texture(lowered_machine_texture_path)
	raised_machine_texture = _load_texture(raised_machine_texture_path)
	advanced_lowered_machine_texture = _load_texture(advanced_lowered_machine_texture_path)
	advanced_raised_machine_texture = _load_texture(advanced_raised_machine_texture_path)
	var raw_texture := _load_texture(raw_youtiao_texture_path)
	if raw_texture != null:
		raw_youtiao_texture = AtlasTexture.new()
		raw_youtiao_texture.atlas = raw_texture
		raw_youtiao_texture.region = RAW_YOUTIAO_REGION
	golden_youtiao_texture = _load_texture(golden_youtiao_texture_path)
	burnt_youtiao_texture = _load_texture(burnt_youtiao_texture_path)
	var plate_texture := _load_texture(plate_texture_path)
	plain_tray.set_artwork_texture(plate_texture)
	sesame_tray.set_artwork_texture(_load_texture(black_sesame_tray_texture_path))
	var black_sesame_texture := _load_texture(black_sesame_youtiao_texture_path)
	if golden_youtiao_texture != null:
		plate_youtiao_texture = AtlasTexture.new()
		plate_youtiao_texture.atlas = golden_youtiao_texture
		plate_youtiao_texture.region = PLATE_YOUTIAO_REGION
	if black_sesame_texture != null:
		black_sesame_youtiao_texture = AtlasTexture.new()
		black_sesame_youtiao_texture.atlas = black_sesame_texture
		black_sesame_youtiao_texture.region = BLACK_SESAME_YOUTIAO_REGION


func _load_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path] as Texture2D
	var texture := load(path) as Texture2D
	_texture_cache[path] = texture
	return texture


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
	return _finished_tray_unlocked and plain_tray != null and plain_tray.visible and _control_contains_local_point(plain_tray, point)


func _control_contains_local_point(control: Control, point: Vector2) -> bool:
	if control == null or not control.visible:
		return false
	var canvas_point := get_global_transform_with_canvas() * point
	var control_point := control.get_global_transform_with_canvas().affine_inverse() * canvas_point
	return Rect2(Vector2.ZERO, control.size).has_point(control_point)


func _has_active_product_drag() -> bool:
	var sources := output_sources + plate_sources
	if waste_source != null:
		sources.append(waste_source)
	for source in sources:
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
