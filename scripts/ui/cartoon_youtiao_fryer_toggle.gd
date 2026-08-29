@tool
class_name CartoonYoutiaoFryerToggle
extends Control

## The cartoon fryer is the production UI for device.youtiao_fryer. GameSession
## remains the authority for stock, production time, quality, waste and storage.
signal status_message(message: String)
signal youtiao_add_to_pancake_requested(source_ref: Dictionary)
signal raw_input_feedback_requested(success: bool)
signal audio_cue_requested(cue: StringName)

const DEVICE_ID := &"device.youtiao_fryer"
const RECIPE_ID := &"recipe.youtiao.plain"
const PRODUCT_ID := &"product.youtiao.plain"
const CHICKEN_RECIPE_ID := &"recipe.chicken.cutlet"
const CHICKEN_PRODUCT_ID := &"product.chicken.cutlet"
const DOUGH_STOCK_ID := &"stock.youtiao.plain_dough"
const CHICKEN_STOCK_ID := &"stock.chicken.cutlet_raw"
const FINISHED_TRAY_GROWTH_ID := &"growth.capacity.youtiao_finished_tray"
const CHICKEN_FINISHED_TRAY_GROWTH_ID := &"growth.capacity.chicken_finished_tray"
const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const COOKING_STAGE_BAR_SCRIPT := preload("res://scripts/ui/cooking_stage_bar.gd")
const MACHINE_HOLD_THRESHOLD_SECONDS := 0.20
const MACHINE_ADD_INTERVAL_SECONDS := 0.25
const TRAY_VISUAL_CAPACITY := 4
const PLATE_VISUAL_CAPACITY := TRAY_VISUAL_CAPACITY * 2
const WORKSHOP_LOCKED_AREA_MODULATE := Color(1.0, 1.0, 1.0, 0.42)
const PLATE_YOUTIAO_REGION := Rect2(174.0, 8.0, 677.0, 1500.0)
const RAW_YOUTIAO_REGION := Rect2(97.0, 53.0, 321.0, 403.0)
# These regions are authored in the 320 x 270 FryerVisual coordinate space.
# They cover the visible wire baskets (including their handles), rather than
# the much smaller product-source rects laid over the food sprites.
const SINGLE_BASKET_INPUT_REGION := Rect2(55.0, 70.0, 210.0, 145.0)
const LEFT_BASKET_INPUT_REGION := Rect2(18.0, 72.0, 142.0, 150.0)
const RIGHT_BASKET_INPUT_REGION := Rect2(160.0, 72.0, 142.0, 150.0)
const MACHINE_HOLD_CANCEL_TOLERANCE_MIN_PIXELS := 18.0
const MACHINE_HOLD_CANCEL_TOLERANCE_MAX_PIXELS := 32.0
const BASIC_EXTRA_DOWN_OFFSET := Vector2(0.0, 10.0)
const BASIC_FINISHED_OFFSET := Vector2(-9.0, 10.0)
const BASIC_FINISHED_SCALE := Vector2(0.75, 0.75)
const ADVANCED_PRODUCT_SCALE := Vector2(0.65, 0.65)
const ADVANCED_FINISHED_PRODUCT_SCALE := Vector2(0.82, 0.82)
const ADVANCED_RAISED_PRODUCT_OFFSET := Vector2(-32.0, 10.0)
const ADVANCED_LOWERED_PRODUCT_OFFSET := Vector2(-32.0, 12.0)
const ADVANCED_FINISHED_UP_OFFSET := Vector2(0.0, -6.0)
const YOUTIAO_SLOT_X_POSITIONS := [0.0, 39.0, 78.0, 117.0]
const ADVANCED_FINISHED_SLOT_X_POSITIONS := [0.0, 27.0, 54.0, 81.0]
@export var reduce_motion := false

@export_group("Editor preview")
@export_enum("Basic", "Advanced", "Dual basket") var editor_preview_tier := 0
@export_enum("Raised empty", "Raised dough", "Lowered dough", "Lowered finished", "Raised finished", "Raised burnt") var editor_preview_state := 1
@export var editor_preview_trays := true

# Strings, not Texture2D references: the Inspector exposes the exact source
# artwork without making any of these PNGs a dependency of the loaded scene.
@export_group("Artwork (lazy-loaded)")
@export_file("*.png") var lowered_machine_texture_path := "res://resources/art/workstation/machines/youtiao_fryer/youtiao-fryer-cartoon-empty-drain-lowered.png"
@export_file("*.png") var raised_machine_texture_path := "res://resources/art/workstation/machines/youtiao_fryer/youtiao-fryer-cartoon-empty-drain-raised-coherent.png"
@export_file("*.png") var advanced_lowered_machine_texture_path := "res://resources/art/workstation/machines/youtiao_fryer/advanced/youtiao-fryer-cartoon-advanced-empty-drain-lowered.png"
@export_file("*.png") var advanced_raised_machine_texture_path := "res://resources/art/workstation/machines/youtiao_fryer/advanced/youtiao-fryer-cartoon-advanced-empty-drain-raised.png"
@export_file("*.png") var dual_lowered_machine_texture_path := "res://resources/art/workstation/machines/youtiao_fryer/youtiao_chicken_dual_fryer_v2.png"
@export_file("*.png") var dual_raised_machine_texture_path := "res://resources/art/workstation/machines/youtiao_fryer/youtiao_chicken_dual_fryer_v2_drain_raised.png"
@export_file("*.png") var dual_left_raised_machine_texture_path := "res://resources/art/workstation/machines/youtiao_fryer/youtiao_chicken_dual_fryer_v2_left_raised.png"
@export_file("*.png") var dual_right_raised_machine_texture_path := "res://resources/art/workstation/machines/youtiao_fryer/youtiao_chicken_dual_fryer_v2_right_raised.png"
@export_file("*.png") var raw_youtiao_texture_path := "res://resources/art/workstation/machines/youtiao_fryer/youtiao-raw-dough-v4.png"
@export_file("*.png") var golden_youtiao_texture_path := "res://resources/art/workstation/machines/youtiao_fryer/youtiao-golden-v5-transparent.png"
@export_file("*.png") var burnt_youtiao_texture_path := "res://resources/art/workstation/machines/youtiao_fryer/youtiao-burnt-v4.png"
# @export_file("*.png") var plate_texture_path := "res://resources/art/workstation/machines/youtiao_fryer/youtiao-empty-serving-plate-oblique-v2.png"
@export_file("*.png") var plate_texture_path := "res://resources/art/workstation/material_slots/legacy_trays/empty-square-ingredient-tray.png"
@export_file("*.png") var chicken_raw_texture_path := "res://resources/art/products/chicken/chicken_cutlet_raw_breaded_v1.png"
@export_file("*.png") var chicken_golden_texture_path := "res://resources/art/products/chicken/chicken_cutlet_golden_v1.png"
@export_file("*.png") var chicken_burnt_texture_path := "res://resources/art/products/chicken/chicken_cutlet_burnt_v1.png"

@onready var fryer_assembly: Control = %FryerAssembly
@onready var fryer_visual: TextureRect = %FryerVisual
@onready var fryer_layout_player: AnimationPlayer = %FryerLayoutPlayer
@onready var basket_products: Control = %LeftBasket
@onready var chicken_basket_products: Control = %RightBasket
@onready var fryer_slot_sources: Array[ProductDragSource] = [%ProductSource1, %ProductSource2, %ProductSource3, %ProductSource4]
@onready var burnt_batch_source: ProductDragSource = %BurntBatchSource
@onready var chicken_slot_sources: Array[ProductDragSource] = [%ChickenProductSource1, %ChickenProductSource2, %ChickenProductSource3, %ChickenProductSource4]
@onready var plain_tray: YoutiaoTrayView = %PlainTray
@onready var chicken_tray: YoutiaoTrayView = %ChickenTray
@onready var status_label: Label = %StatusLabel
@onready var youtiao_progress_label: Label = %YoutiaoProgressLabel
@onready var youtiao_progress_bar = %YoutiaoProgressBar
@onready var chicken_progress_label: Label = %ChickenProgressLabel
@onready var chicken_progress_bar = %ChickenProgressBar

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
var _chicken_stock := 0
var _chicken_unlocked := false
var _finished_tray_unlocked := false
var _chicken_finished_tray_unlocked := false
var _plate_count := 0
var _plate_products: Array[Dictionary] = []
var _chicken_plate_products: Array[Dictionary] = []
var _refresh_elapsed := 0.0
var _machine_press_active := false
var _machine_hold_active := false
var _machine_hold_elapsed := 0.0
var _machine_add_elapsed := 0.0
var _machine_lane: StringName = &"left"
var _workshop_preview := false
var _workshop_advanced_preview := false
var _session_refresh_pending := false
var _editor_preview_signature := 0
var _texture_cache: Dictionary = {}
var lowered_machine_texture: Texture2D
var raised_machine_texture: Texture2D
var advanced_lowered_machine_texture: Texture2D
var advanced_raised_machine_texture: Texture2D
var dual_lowered_machine_texture: Texture2D
var dual_raised_machine_texture: Texture2D
var dual_left_raised_machine_texture: Texture2D
var dual_right_raised_machine_texture: Texture2D
var raw_youtiao_texture: Texture2D
var golden_youtiao_texture: Texture2D
var plate_youtiao_texture: Texture2D
var burnt_youtiao_texture: Texture2D
var chicken_raw_texture: Texture2D
var chicken_golden_texture: Texture2D
var chicken_burnt_texture: Texture2D
var _machine_cancel_tolerance_pixels := 25.0
var _machine_feedback_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	start_button = fryer_visual
	lift_button = fryer_visual
	state_label = youtiao_progress_label
	if Engine.is_editor_hint():
		_ensure_visual_resources()
		_apply_editor_preview()
		return
	_configure_component_controls()
	mouse_exited.connect(_clear_machine_hover_preview)
	_connect_session_signals()
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("get_settings"):
		_apply_interaction_settings(Dictionary(session.call("get_settings")))
		var settings_signal := Signal(session, &"settings_changed")
		if not settings_signal.is_connected(_apply_interaction_settings):
			settings_signal.connect(_apply_interaction_settings)
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
		if _machine_press_active:
			return
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
	elif event is InputEventMouseMotion and not _machine_press_active:
		_update_machine_hover_preview(event.position)


func _has_point(point: Vector2) -> bool:
	# This root also spans the adjacent pancake toppings. Restrict its input
	# bounds to the fryer and its own finished-product trays so the invisible
	# portion of the Control cannot swallow their hover, drag, or hold gestures.
	# A sibling hotspot can cause Godot to recalculate the hovered Control while
	# this preview node is still entering the scene tree. @onready references are
	# not assigned until this node's _ready(), so it cannot claim input yet.
	if _machine_lane_at_local_point(point) != &"":
		return true
	if plain_tray != null and plain_tray.visible and _control_contains_local_point(plain_tray, point):
		return true
	if chicken_tray != null and chicken_tray.visible and _control_contains_local_point(chicken_tray, point):
		return true
	return false


func _input(event: InputEvent) -> void:
	# Continue tracking a press that began on the fryer, even if it is released
	# outside this Control's bounds.
	if not _machine_press_active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drag_or_click(get_local_mouse_position())
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		# `_input` receives viewport coordinates, whereas the hotspot helper takes
		# coordinates local to this fryer.  Converting the viewport point prevents
		# the fryer transform from being applied twice and falsely cancelling a
		# held restock as soon as the pointer moves.
		var local_pointer: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if _machine_lane_at_local_point(local_pointer, _machine_cancel_tolerance_pixels) != _machine_lane:
			_cancel_machine_gesture()
			status_message.emit("已取消长按，未完成的补货不会扣费")
			get_viewport().set_input_as_handled()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or StringName(Dictionary(data).get("kind", &"")) != &"product_source":
		return false
	var source_ref := Dictionary(Dictionary(data).get("source_ref", {}))
	if StringName(source_ref.get("source_kind", &"")) == &"youtiao_dough":
		return true
	return false


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var source_ref := Dictionary(Dictionary(data).get("source_ref", {}))
	if StringName(source_ref.get("source_kind", &"")) == &"youtiao_dough":
		_load_dough(StringName(source_ref.get("recipe_id", RECIPE_ID)))


func select_recipe(next_recipe_id: StringName) -> void:
	if next_recipe_id == CHICKEN_RECIPE_ID:
		_load_chicken()
	else:
		_load_dough(next_recipe_id)


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
	_chicken_finished_tray_unlocked = Array(progression.get("owned_growth_ids", [])).has(CHICKEN_FINISHED_TRAY_GROWTH_ID)
	_workshop_advanced_preview = _workshop_preview and area_unlocked
	if area_unlocked or _workshop_preview:
		_ensure_visual_resources()
	modulate = WORKSHOP_LOCKED_AREA_MODULATE if _workshop_preview and not area_unlocked else Color.WHITE
	var unlocked_products := Array(progression.get("unlocked_product_ids", []))
	_chicken_unlocked = unlocked_products.has(CHICKEN_PRODUCT_ID) and int(_machine.get("tier", 0)) >= 2
	plain_tray.visible = _finished_tray_unlocked or _workshop_preview
	plain_tray.self_modulate = WORKSHOP_LOCKED_AREA_MODULATE if _workshop_preview and not _finished_tray_unlocked else Color.WHITE
	plain_tray.set_drop_enabled(_finished_tray_unlocked and not _workshop_preview)
	# Chicken belongs exclusively to the third-tier dual-basket fryer.  Unlike
	# the legacy trays, do not reveal it just because the workshop is previewing
	# an earlier youtiao upgrade.
	chicken_tray.visible = _chicken_unlocked and (_chicken_finished_tray_unlocked or _workshop_preview)
	chicken_tray.self_modulate = WORKSHOP_LOCKED_AREA_MODULATE if _workshop_preview and not _chicken_finished_tray_unlocked else Color.WHITE
	chicken_tray.set_drop_enabled(_chicken_finished_tray_unlocked and not _workshop_preview)
	if _workshop_preview:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		mouse_filter = Control.MOUSE_FILTER_STOP
	var inventory := Dictionary(session.call("inventory_snapshot")) if session.has_method("inventory_snapshot") else {}
	_dough_stock = maxi(int(inventory.get(str(DOUGH_STOCK_ID), 0)), 0)
	_chicken_stock = maxi(int(inventory.get(str(CHICKEN_STOCK_ID), 0)), 0)
	_refresh_prepared_slot(session)
	_apply_snapshot()
	_session_refresh_pending = false


func _begin_drag_or_click(point: Vector2) -> void:
	var lane_id := _machine_lane_at_local_point(point)
	if lane_id != &"":
		_machine_lane = lane_id
		_begin_machine_gesture()


func _update_machine_hover_preview(point: Vector2) -> void:
	var lane_id := _machine_lane_at_local_point(point)
	if lane_id == &"":
		_clear_machine_hover_preview()
		return
	var lane := Dictionary(Dictionary(_machine.get("lanes", {})).get(lane_id, _machine))
	var state := StringName(lane.get("state", &"idle"))
	var stock := _chicken_stock if lane_id == &"right" else _dough_stock
	var valid := false
	var message := ""
	match state:
		&"idle":
			valid = stock > 0
			message = ("点击加入鸡排生料" if lane_id == &"right" else "点击加入油条面胚") if valid else "原料库存不足；长按当前炸篮补货"
		&"loaded":
			valid = true
			message = "点击开始炸制"
		&"ready_safe", &"overcooking":
			valid = true
			message = "点击抬起炸篮并沥油"
		&"frying":
			message = "炸制中"
		&"burnt":
			message = "本批已焦糊，请先处理成品"
		_:
			message = "当前设备不可用"
	fryer_visual.self_modulate = Color(0.82, 1.0, 0.82, 1.0) if valid else Color(1.0, 0.72, 0.68, 1.0)
	tooltip_text = message
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if valid else Control.CURSOR_FORBIDDEN


func _clear_machine_hover_preview() -> void:
	if fryer_visual != null:
		fryer_visual.self_modulate = Color.WHITE
	tooltip_text = ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _finish_drag_or_click(point: Vector2) -> void:
	if not _machine_press_active:
		return
	var was_hold := _machine_hold_active
	if was_hold:
		_cancel_machine_restock_progress()
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
		_start_machine_input_hold()
		return
	if not _can_load_selected_lane():
		_end_machine_gesture()
		status_message.emit("右侧鸡排滤网已满，点击右篮开始炸制" if _machine_lane == &"right" else "炸篮已满，点击油条机开始炸制")
		return
	if _selected_input_stock() > 0:
		_machine_add_elapsed += maxf(delta, 0.0)
		if _machine_add_elapsed + 0.000001 >= MACHINE_ADD_INTERVAL_SECONDS:
			_machine_add_elapsed = 0.0
			_load_selected_input()
		return
	var session := get_node_or_null("/root/GameSession")
	var stock_id := _selected_stock_id()
	var result := Dictionary(session.call("advance_five_area_restock_hold", stock_id, delta)) if session != null else {"success": false, "reason": &"no_game_session"}
	if int(result.get("completed_units", 0)) > 0:
		for _unit in int(result.get("completed_units", 0)):
			_load_selected_input()
	if bool(result.get("auto_stopped", false)) or not bool(result.get("success", false)):
		_end_machine_gesture()
		status_message.emit(_restock_failure_text(StringName(result.get("reason", &"")), result))
	refresh_from_session()


func _start_machine_input_hold() -> void:
	var session := get_node_or_null("/root/GameSession")
	var status := Dictionary(session.call("five_area_restock_status", _selected_stock_id())) if session != null else {"success": false, "reason": &"no_game_session"}
	var can_restock := bool(status.get("success", false)) and int(status.get("current_stock", 0)) < int(status.get("capacity", 0)) and int(status.get("coins", 0)) >= int(status.get("unit_cost", 0))
	if _can_load_selected_lane() and (_selected_input_stock() > 0 or can_restock):
		_machine_hold_active = true
		status_message.emit("持续长按右侧滤网补货并加入鸡排；每完成一份才扣金币" if _machine_lane == &"right" else "持续长按油条机添加油条面胚；每完成一份才扣金币")
		return
	_end_machine_gesture()
	if not _can_load_selected_lane():
		status_message.emit("右侧鸡排滤网已满，点击右篮开始炸制" if _machine_lane == &"right" else "炸篮已满，点击油条机开始炸制")
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
		audio_cue_requested.emit(&"youtiao_load")
	else:
		status_message.emit(_failure_text(StringName(result.get("reason", &""))))
	refresh_from_session()
	_play_machine_input_feedback(bool(result.get("success", false)))


func _load_chicken() -> void:
	var session := get_node_or_null("/root/GameSession")
	var result := Dictionary(session.call("load_f3_chicken", 1)) if session != null else {"success": false, "reason": &"no_game_session"}
	if bool(result.get("success", false)):
		status_message.emit("鸡排已加入右侧炸篮")
	else:
		status_message.emit(_failure_text(StringName(result.get("reason", &""))))
	refresh_from_session()
	_play_machine_input_feedback(bool(result.get("success", false)))


func _selected_stock_id() -> StringName:
	return CHICKEN_STOCK_ID if _machine_lane == &"right" else DOUGH_STOCK_ID


func _selected_input_stock() -> int:
	return _chicken_stock if _machine_lane == &"right" else _dough_stock


func _load_selected_input() -> void:
	if _machine_lane == &"right":
		_load_chicken()
	else:
		_load_dough(RECIPE_ID)


func _store_ready_fryer_batch_on_plate(product_id: StringName) -> void:
	var session := get_node_or_null("/root/GameSession")
	var is_chicken := product_id == CHICKEN_PRODUCT_ID
	var result := {"success": false, "reason": &"no_game_session"}
	if session != null and session.has_method("store_ready_fryer_batch_to_available_capacity"):
		result = Dictionary(session.call("store_ready_fryer_batch_to_available_capacity", &"slot.chicken" if is_chicken else &"slot.04", &"right" if is_chicken else &"left"))
	elif session != null and session.has_method("store_ready_fryer_batch"):
		result = Dictionary(session.call("store_ready_fryer_batch", &"slot.chicken" if is_chicken else &"slot.04", &"right" if is_chicken else &"left"))
	elif session != null and not is_chicken and session.has_method("store_ready_youtiao_batch"):
		result = Dictionary(session.call("store_ready_youtiao_batch", &"slot.04"))
	if bool(result.get("success", false)):
		var quantity := int(result.get("stored_quantity", 0))
		var remaining := int(result.get("remaining_quantity", 0))
		var message := "%d份鸡排已放入鸡排盘" % quantity if is_chicken else "%d根油条已放入成品盘" % quantity
		if remaining > 0:
			message += "；成品盘已满，剩余%d份保留在滤网中" % remaining
		status_message.emit(message)
	else:
		status_message.emit(_failure_text(StringName(result.get("reason", &""))))
	_request_session_refresh()


func _perform_machine_click() -> void:
	var lane := Dictionary(Dictionary(_machine.get("lanes", {})).get(_machine_lane, _machine))
	var state := StringName(lane.get("state", &"idle"))
	if state == &"idle":
		if _selected_input_stock() > 0:
			_load_selected_input()
		else:
			status_message.emit("原料库存不足；长按当前炸篮补货")
		return
	var action := &"start" if state == &"loaded" else &"lift" if state in [&"ready_safe", &"overcooking"] else &""
	if action.is_empty():
		status_message.emit("长按右侧滤网补货并加入鸡排" if _machine_lane == &"right" and state == &"idle" else "长按油条机添加面胚" if state == &"idle" else _state_text(state))
		return
	var session := get_node_or_null("/root/GameSession")
	var result := Dictionary(session.call("perform_f3_chicken_action", action)) if session != null and _machine_lane == &"right" else Dictionary(session.call("perform_f3_youtiao_action", action)) if session != null else {"success": false, "reason": &"no_game_session"}
	status_message.emit("鸡排开始炸制" if _machine_lane == &"right" and action == &"start" and bool(result.get("success", false)) else "油条开始炸制" if action == &"start" and bool(result.get("success", false)) else "炸篮已抬起，正在沥油" if bool(result.get("success", false)) else _failure_text(StringName(result.get("reason", &""))))
	if bool(result.get("success", false)):
		audio_cue_requested.emit(&"fryer_start" if action == &"start" else &"fryer_ready")
	refresh_from_session()


func _play_machine_input_feedback(success: bool) -> void:
	raw_input_feedback_requested.emit(success)
	if _machine_feedback_tween != null and _machine_feedback_tween.is_valid():
		_machine_feedback_tween.kill()
	fryer_visual.pivot_offset = fryer_visual.size * 0.5
	fryer_visual.scale = Vector2.ONE
	var reduce_motion := DisplayServer.has_method(&"accessibility_should_reduce_motion") and bool(DisplayServer.call(&"accessibility_should_reduce_motion"))
	var feedback_color := Color(0.72, 1.0, 0.72, 1.0) if success else Color(1.0, 0.52, 0.48, 1.0)
	_machine_feedback_tween = create_tween()
	_machine_feedback_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_machine_feedback_tween.tween_property(fryer_visual, "self_modulate", feedback_color, 0.06)
	if not reduce_motion:
		_machine_feedback_tween.parallel().tween_property(fryer_visual, "scale", Vector2.ONE * (1.015 if success else 0.985), 0.06)
	_machine_feedback_tween.tween_property(fryer_visual, "self_modulate", Color.WHITE, 0.08)
	if not reduce_motion:
		_machine_feedback_tween.parallel().tween_property(fryer_visual, "scale", Vector2.ONE, 0.08)


func _cancel_machine_gesture() -> void:
	if not _machine_press_active:
		return
	if _machine_hold_active:
		_cancel_machine_restock_progress()
	_end_machine_gesture()
	refresh_from_session()


func _cancel_machine_restock_progress() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("cancel_five_area_restock_hold"):
		session.call("cancel_five_area_restock_hold", _selected_stock_id())


func _apply_interaction_settings(settings: Dictionary) -> void:
	var sensitivity := clampf(float(settings.get("drag_sensitivity", 100.0)), 50.0, 150.0)
	_machine_cancel_tolerance_pixels = lerpf(MACHINE_HOLD_CANCEL_TOLERANCE_MIN_PIXELS, MACHINE_HOLD_CANCEL_TOLERANCE_MAX_PIXELS, (sensitivity - 50.0) / 100.0)


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
	var use_dual_art := int(_machine.get("tier", 0)) >= 2
	var right_lane := Dictionary(Dictionary(_machine.get("lanes", {})).get(&"right", {}))
	var right_state := StringName(right_lane.get("state", &"idle"))
	var right_lowered := right_state in [&"frying", &"ready_safe", &"overcooking"]
	_apply_fryer_layout(use_advanced_art, basket_lowered, use_dual_art, right_lowered, state)
	if use_dual_art and dual_lowered_machine_texture != null and dual_raised_machine_texture != null:
		if not basket_lowered and not right_lowered:
			fryer_visual.texture = dual_raised_machine_texture
		elif not basket_lowered and dual_left_raised_machine_texture != null:
			fryer_visual.texture = dual_left_raised_machine_texture
		elif not right_lowered and dual_right_raised_machine_texture != null:
			fryer_visual.texture = dual_right_raised_machine_texture
		else:
			fryer_visual.texture = dual_lowered_machine_texture
	elif use_advanced_art and advanced_lowered_machine_texture != null and advanced_raised_machine_texture != null:
		fryer_visual.texture = advanced_lowered_machine_texture if basket_lowered else advanced_raised_machine_texture
	else:
		fryer_visual.texture = lowered_machine_texture if basket_lowered else raised_machine_texture
	_refresh_output_sources(state, occupied, capacity, raw_youtiao_texture if cooking else finished_texture)
	_refresh_chicken_output_sources(right_lane)
	_refresh_plate_sources()
	# The compact per-lane rows replace this legacy multi-line readout at runtime.
	# Keep the node for editor previews and scene compatibility only.
	status_label.visible = false
	status_label.text = "%s · %d/%d" % [_state_text(state), int(_machine.get("quantity", 0)), int(_machine.get("capacity", 0))]
	if _chicken_unlocked:
		status_label.text += "\n鸡排：%s · %d/%d" % [_state_text(StringName(right_lane.get("state", &"idle"))), int(right_lane.get("quantity", 0)), int(right_lane.get("capacity", 4))]
	var youtiao_progress_visible := state not in [&"unowned", &"unsupported"] and (not _workshop_preview or _workshop_advanced_preview)
	_apply_lane_progress(&"left", _machine, youtiao_progress_bar, youtiao_progress_label, youtiao_progress_visible)
	_apply_lane_progress(&"right", right_lane, chicken_progress_bar, chicken_progress_label, _chicken_unlocked)


func _apply_lane_progress(
	lane_id: StringName,
	lane: Dictionary,
	bar,
	label: Label,
	show_progress: bool
) -> void:
	bar.visible = show_progress
	label.visible = show_progress
	if not show_progress:
		return
	var timing := _lane_timing(lane_id, lane)
	var duration := float(timing.get("duration", 10.0))
	var safe_seconds := float(timing.get("safe", 5.0))
	var decay_seconds := float(timing.get("decay", 10.0))
	var total_seconds := maxf(duration + safe_seconds + decay_seconds, 0.001)
	var state := StringName(lane.get("state", &"idle"))
	var cooking_elapsed := clampf(float(lane.get("cooking_elapsed_seconds", 0.0)), 0.0, duration)
	var completed_elapsed := clampf(float(lane.get("completed_elapsed_seconds", 0.0)), 0.0, safe_seconds + decay_seconds)
	var progress_seconds := 0.0
	match state:
		&"frying":
			progress_seconds = cooking_elapsed
		&"ready_safe", &"overcooking", &"draining", &"ready_to_collect":
			progress_seconds = duration + completed_elapsed
		&"burnt":
			progress_seconds = total_seconds
	var active := state in [&"frying", &"ready_safe", &"overcooking", &"draining", &"ready_to_collect", &"burnt"]
	var prefix := "鸡排" if lane_id == &"right" else "油条"
	var lane_text := _lane_progress_text(prefix, state)
	var detail_text := _lane_progress_detail(prefix, state, cooking_elapsed, duration, completed_elapsed, safe_seconds, float(lane.get("quality", 100.0)))
	label.text = lane_text
	bar.configure(
		progress_seconds / total_seconds,
		duration / total_seconds,
		(duration + safe_seconds) / total_seconds,
		active,
		COOKING_STAGE_BAR_SCRIPT.STAGE_RED if state == &"burnt" else &"",
		detail_text,
	)


func _lane_timing(lane_id: StringName, lane: Dictionary) -> Dictionary:
	var definition := CATALOG.device_tier(DEVICE_ID, int(_machine.get("tier", 0)))
	var fallback_recipe_id := CHICKEN_RECIPE_ID if lane_id == &"right" else RECIPE_ID
	var recipe_id := StringName(lane.get("recipe_id", fallback_recipe_id))
	if recipe_id.is_empty():
		recipe_id = fallback_recipe_id
	var recipe := CATALOG.recipe_definition(recipe_id)
	return {
		"duration": float(recipe.get("duration_seconds", definition.get("duration_seconds", 10.0))),
		"safe": float(definition.get("safe_seconds", 5.0)),
		"decay": float(definition.get("decay_seconds", 10.0)),
	}


static func _lane_progress_text(prefix: String, state: StringName) -> String:
	match state:
		&"loaded":
			return "%s · 待启动" % prefix
		&"frying":
			return "%s · 炸制中" % prefix
		&"ready_safe":
			return "%s · 最佳起锅" % prefix
		&"overcooking":
			return "%s · 过火风险" % prefix
		&"draining":
			return "%s · 沥油中" % prefix
		&"ready_to_collect":
			return "%s · 可取餐" % prefix
		&"burnt":
			return "%s · 已焦糊" % prefix
	return "%s · 未开始" % prefix


static func _lane_progress_detail(
	prefix: String,
	state: StringName,
	cooking_elapsed: float,
	duration: float,
	completed_elapsed: float,
	safe_seconds: float,
	quality: float
) -> String:
	match state:
		&"frying":
			return "%s炸制 %.1f/%.1f秒" % [prefix, cooking_elapsed, duration]
		&"ready_safe":
			return "%s处于最佳起锅区间，剩余%.1f秒" % [prefix, maxf(safe_seconds - completed_elapsed, 0.0)]
		&"overcooking":
			return "%s已进入过火风险区间，当前品质%d" % [prefix, roundi(quality)]
	return _lane_progress_text(prefix, state)


func _apply_editor_preview() -> void:
	if not is_node_ready():
		return
	_editor_preview_signature = _preview_signature()
	_ensure_visual_resources()
	var use_advanced_art := editor_preview_tier >= 1
	var use_dual_art := editor_preview_tier >= 2
	var basket_lowered := editor_preview_state in [2, 3]
	var product_preview_state := {
		1: &"loaded",
		2: &"frying",
		3: &"ready_safe",
		4: &"draining",
		5: &"burnt",
	}.get(editor_preview_state, &"") as StringName
	_apply_fryer_layout(use_advanced_art, basket_lowered, use_dual_art, basket_lowered, product_preview_state)
	if use_dual_art:
		fryer_visual.texture = dual_lowered_machine_texture if basket_lowered else dual_raised_machine_texture
	elif use_advanced_art:
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
	chicken_tray.visible = use_dual_art and editor_preview_trays
	plain_tray.self_modulate = Color.WHITE
	plain_tray.preview_products(_plate_youtiao_texture(), 4 if editor_preview_trays else 0)
	status_label.visible = true
	var tier_label := "双篮" if use_dual_art else "高级" if use_advanced_art else "初级"
	status_label.text = "布局预览 · %s · %s" % [tier_label, ["抬起空篮", "抬起面坯", "落下面坯", "落下成品", "抬起成品", "抬起焦糊"][editor_preview_state]]
	youtiao_progress_label.visible = true
	youtiao_progress_bar.visible = true
	youtiao_progress_label.text = "油条 · 布局预览"
	if _editor_control_has_tool_script(youtiao_progress_bar):
		youtiao_progress_bar.configure(0.0, 0.40, 0.60, false, &"", youtiao_progress_label.text)
	chicken_progress_label.visible = use_dual_art
	chicken_progress_bar.visible = use_dual_art
	if use_dual_art:
		chicken_progress_label.text = "鸡排 · 布局预览"
		if _editor_control_has_tool_script(chicken_progress_bar):
			chicken_progress_bar.configure(0.0, 12.0 / 27.0, 17.0 / 27.0, false, &"", chicken_progress_label.text)


func _editor_control_has_tool_script(control: Control) -> bool:
	var control_script := control.get_script() as Script if control != null else null
	return control_script != null and control_script.is_tool()


func _preview_signature() -> int:
	return [
		editor_preview_tier,
		editor_preview_state,
		editor_preview_trays,
	].hash()


func _apply_fryer_layout(
	use_advanced_art: bool,
	basket_lowered: bool,
	use_dual_art: bool = false,
	right_basket_lowered: bool = false,
	product_state: StringName = &""
) -> void:
	var layout_name := _fryer_layout_animation(use_advanced_art, basket_lowered, use_dual_art, right_basket_lowered)
	if not fryer_layout_player.has_animation(layout_name):
		push_error("Missing authored fryer layout animation: %s" % layout_name)
		return
	# Position, size, per-slot spacing and lane scale are authored in the scene.
	# The script only selects the layout state required by the machine model.
	fryer_layout_player.play(layout_name)
	fryer_layout_player.seek(0.0, true)
	_apply_youtiao_slot_x_positions(YOUTIAO_SLOT_X_POSITIONS)
	if use_advanced_art and not use_dual_art:
		_apply_advanced_product_state_adjustment(product_state)
	elif not use_dual_art:
		_apply_basic_product_state_adjustment(product_state)


func _apply_advanced_product_state_adjustment(state: StringName) -> void:
	# Advanced-only offsets keep the four product presentations independent of
	# the scene-authored basic and dual-basket layouts.
	match state:
		&"loaded":
			basket_products.position += ADVANCED_RAISED_PRODUCT_OFFSET
			basket_products.scale = ADVANCED_PRODUCT_SCALE
		&"frying":
			basket_products.position += ADVANCED_LOWERED_PRODUCT_OFFSET
			basket_products.scale = ADVANCED_PRODUCT_SCALE
		&"ready_safe", &"overcooking":
			basket_products.position += ADVANCED_LOWERED_PRODUCT_OFFSET + ADVANCED_FINISHED_UP_OFFSET
			basket_products.scale = ADVANCED_FINISHED_PRODUCT_SCALE
			_apply_youtiao_slot_x_positions(ADVANCED_FINISHED_SLOT_X_POSITIONS)
		&"draining", &"ready_to_collect":
			basket_products.position += ADVANCED_RAISED_PRODUCT_OFFSET + ADVANCED_FINISHED_UP_OFFSET
			basket_products.scale = ADVANCED_FINISHED_PRODUCT_SCALE
			_apply_youtiao_slot_x_positions(ADVANCED_FINISHED_SLOT_X_POSITIONS)


func _apply_youtiao_slot_x_positions(x_positions: Array) -> void:
	for source_index in range(mini(fryer_slot_sources.size(), x_positions.size())):
		var source := fryer_slot_sources[source_index]
		source.position.x = float(x_positions[source_index])


func _apply_basic_product_state_adjustment(state: StringName) -> void:
	match state:
		&"frying":
			basket_products.position += BASIC_EXTRA_DOWN_OFFSET
		&"ready_safe", &"overcooking":
			basket_products.position += BASIC_FINISHED_OFFSET
			basket_products.scale = BASIC_FINISHED_SCALE
		&"draining", &"ready_to_collect":
			basket_products.position += BASIC_FINISHED_OFFSET
			basket_products.scale = BASIC_FINISHED_SCALE


func _fryer_layout_animation(use_advanced_art: bool, basket_lowered: bool, use_dual_art: bool, right_basket_lowered: bool) -> StringName:
	if use_dual_art:
		if basket_lowered and right_basket_lowered:
			return &"dual_both_lowered"
		if basket_lowered:
			return &"dual_left_lowered"
		if right_basket_lowered:
			return &"dual_right_lowered"
		return &"dual_both_raised"
	if use_advanced_art:
		return &"advanced_lowered" if basket_lowered else &"advanced_raised"
	return &"basic_lowered" if basket_lowered else &"basic_raised"


func _refresh_output_sources(state: StringName, occupied: Array[int], capacity: int, product_texture: Texture2D) -> void:
	if fryer_slot_sources.is_empty():
		return
	for source_index in range(fryer_slot_sources.size()):
		var output := fryer_slot_sources[source_index]
		var occupied_slot := source_index < capacity and occupied.has(source_index)
		var ready_slot := state == &"ready_to_collect" and occupied.has(source_index)
		output.self_modulate = Color.WHITE
		output.configure({
			"source_kind": &"youtiao_fryer_slot",
			"source_index": source_index,
			"product_id": PRODUCT_ID,
			"discardable": ready_slot,
		}, product_texture, ready_slot, "点击油条成品盘收取滤网中的油条；也可拖到煎饼或顾客")
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


func _refresh_chicken_output_sources(lane: Dictionary) -> void:
	var state := StringName(lane.get("state", &"unowned"))
	var occupied: Array = Array(lane.get("occupied_slot_indices", []))
	var capacity := clampi(int(lane.get("capacity", 0)), 0, chicken_slot_sources.size())
	var cooking := state in [&"loaded", &"frying"]
	var texture := chicken_raw_texture if cooking else chicken_burnt_texture if state == &"burnt" else chicken_golden_texture
	chicken_basket_products.visible = _chicken_unlocked
	for source_index in range(chicken_slot_sources.size()):
		var source := chicken_slot_sources[source_index]
		var occupied_slot := source_index < capacity and occupied.has(source_index)
		var ready_slot := state == &"ready_to_collect" and occupied.has(source_index)
		var burnt_slot := state == &"burnt" and occupied.has(source_index)
		var source_available := ready_slot or burnt_slot
		source.configure(
			{"source_kind": &"fryer_slot", "lane_id": &"right", "source_index": source_index, "product_id": CHICKEN_PRODUCT_ID, "discardable": source_available},
			texture,
			source_available,
			"拖到废弃区报废整篮%s" % ("焦糊鸡排" if burnt_slot else "鸡排") if source_available else "点击鸡排成品盘收取滤网中的鸡排",
		)
		var regions: Array[Dictionary] = []
		if source_available:
			regions.append({"texture": texture, "rect": Rect2(Vector2.ZERO, source.size)})
		source.set_alpha_hit_regions(regions)
		# Clicking a ready chicken still collects the full basket. Dragging either
		# a ready or burnt visible cutlet to the shared waste basket discards that
		# entire right-filter batch.
		source.native_drag_enabled = source_available
		source.mouse_filter = Control.MOUSE_FILTER_STOP if source_available else Control.MOUSE_FILTER_IGNORE
		source.visible = _chicken_unlocked and occupied_slot and not _workshop_preview


func _refresh_prepared_slot(session: Node) -> void:
	var status := Dictionary(session.call("prepared_product_slot_status", &"slot.04"))
	_plate_products.clear()
	for product_value in Array(status.get("products", [])):
		_plate_products.append(Dictionary(product_value).duplicate(true))
	_plate_count = clampi(_plate_products.size(), 0, PLATE_VISUAL_CAPACITY)
	_chicken_plate_products.clear()
	var chicken_status := Dictionary(session.call("prepared_product_slot_status", &"slot.chicken"))
	for product_value in Array(chicken_status.get("products", [])):
		_chicken_plate_products.append(Dictionary(product_value).duplicate(true))


func _refresh_plate_sources() -> void:
	var plain_entries: Array[Dictionary] = []
	for source_index in range(mini(_plate_count, _plate_products.size())):
		var product_id := StringName(_plate_products[source_index].get("product_id", PRODUCT_ID))
		var entry := {"source_index": source_index, "product_id": product_id}
		plain_entries.append(entry)
	plain_tray.configure_products(plain_entries, _plate_youtiao_texture(), _finished_tray_unlocked and not _workshop_preview)
	var chicken_entries: Array[Dictionary] = []
	for source_index in range(mini(_chicken_plate_products.size(), 4)):
		chicken_entries.append({"source_index": source_index, "product_id": CHICKEN_PRODUCT_ID})
	chicken_tray.configure_products(chicken_entries, chicken_golden_texture, _chicken_finished_tray_unlocked and not _workshop_preview)


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
	output_sources.append_array(chicken_slot_sources)
	plate_sources.append_array(plain_tray.product_sources)
	plate_sources.append_array(chicken_tray.product_sources)
	waste_source = burnt_batch_source
	for source in output_sources:
		# Plain youtiao supports click-to-collect plus precise dragging to a
		# pancake, tray or customer. Chicken can be dragged to waste only after
		# its batch has finished cooking; its refresh state enables that gesture.
		source.native_drag_enabled = source in fryer_slot_sources
		source.drag_threshold_pixels = 4.0
		source.drag_ended.connect(_on_product_drag_ended)
	burnt_batch_source.native_drag_enabled = true
	burnt_batch_source.drag_threshold_pixels = 4.0
	burnt_batch_source.drag_ended.connect(_on_product_drag_ended)
	plain_tray.tray_clicked.connect(_on_plain_tray_clicked)
	chicken_tray.tray_clicked.connect(_on_chicken_tray_clicked)
	plain_tray.product_drag_ended.connect(_on_product_drag_ended)
	chicken_tray.product_drag_ended.connect(_on_product_drag_ended)
	for source in plain_tray.product_sources:
		source.short_clicked.connect(_on_plain_tray_product_short_clicked)


func _on_plain_tray_clicked() -> void:
	_store_ready_fryer_batch_on_plate(PRODUCT_ID)


func _on_chicken_tray_clicked() -> void:
	_store_ready_fryer_batch_on_plate(CHICKEN_PRODUCT_ID)


func _on_plain_tray_product_short_clicked(source_ref: Dictionary) -> void:
	if (
		StringName(source_ref.get("source_kind", &"")) == &"prepared_product_slot"
		and StringName(source_ref.get("product_id", &"")) == PRODUCT_ID
	):
		youtiao_add_to_pancake_requested.emit(source_ref.duplicate(true))


func _plate_youtiao_texture() -> Texture2D:
	return plate_youtiao_texture if plate_youtiao_texture != null else golden_youtiao_texture


func _ensure_visual_resources() -> void:
	if raised_machine_texture != null:
		return
	lowered_machine_texture = _load_texture(lowered_machine_texture_path)
	raised_machine_texture = _load_texture(raised_machine_texture_path)
	advanced_lowered_machine_texture = _load_texture(advanced_lowered_machine_texture_path)
	advanced_raised_machine_texture = _load_texture(advanced_raised_machine_texture_path)
	dual_lowered_machine_texture = _load_texture(dual_lowered_machine_texture_path)
	dual_raised_machine_texture = _load_texture(dual_raised_machine_texture_path)
	dual_left_raised_machine_texture = _load_texture(dual_left_raised_machine_texture_path)
	dual_right_raised_machine_texture = _load_texture(dual_right_raised_machine_texture_path)
	var raw_texture := _load_texture(raw_youtiao_texture_path)
	if raw_texture != null:
		raw_youtiao_texture = AtlasTexture.new()
		raw_youtiao_texture.atlas = raw_texture
		raw_youtiao_texture.region = RAW_YOUTIAO_REGION
	golden_youtiao_texture = _load_texture(golden_youtiao_texture_path)
	burnt_youtiao_texture = _load_texture(burnt_youtiao_texture_path)
	var plate_texture := _load_texture(plate_texture_path)
	plain_tray.set_artwork_texture(plate_texture)
	chicken_tray.set_artwork_texture(plate_texture)
	if golden_youtiao_texture != null:
		plate_youtiao_texture = AtlasTexture.new()
		plate_youtiao_texture.atlas = golden_youtiao_texture
		plate_youtiao_texture.region = PLATE_YOUTIAO_REGION
	chicken_raw_texture = _load_texture(chicken_raw_texture_path)
	chicken_golden_texture = _load_texture(chicken_golden_texture_path)
	chicken_burnt_texture = _load_texture(chicken_burnt_texture_path)


func _load_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path] as Texture2D
	var texture := load(path) as Texture2D
	_texture_cache[path] = texture
	return texture


func _can_load_dough() -> bool:
	return _can_load_lane(&"left")


func _can_load_selected_lane() -> bool:
	return _can_load_lane(_machine_lane)


func _can_load_lane(lane_id: StringName) -> bool:
	var lanes := Dictionary(_machine.get("lanes", {}))
	var lane := Dictionary(lanes.get(lane_id, _machine if lane_id == &"left" else {}))
	var state := StringName(lane.get("state", &"unowned"))
	return state in [&"idle", &"loaded"] and int(lane.get("quantity", 0)) < int(lane.get("capacity", 0))


func _on_prepared_store_completed(result: Dictionary) -> void:
	status_message.emit("炸好的油条已收纳" if bool(result.get("success", false)) else _failure_text(StringName(result.get("reason", &""))))
	refresh_from_session()


func _occupied_slots() -> Array[int]:
	var result: Array[int] = []
	for value in Array(_machine.get("occupied_slot_indices", [])):
		result.append(int(value))
	return result


func _machine_lane_at_local_point(point: Vector2, margin: float = 0.0) -> StringName:
	if fryer_visual == null or not fryer_visual.visible:
		return &""
	var canvas_point := get_global_transform_with_canvas() * point
	var visual_point := fryer_visual.get_global_transform_with_canvas().affine_inverse() * canvas_point
	return _machine_lane_from_visual_point(visual_point, margin)


func _machine_lane_from_visual_point(visual_point: Vector2, margin: float = 0.0) -> StringName:
	var expanded_margin := maxf(margin, 0.0)
	if not _chicken_unlocked:
		return &"left" if SINGLE_BASKET_INPUT_REGION.grow(expanded_margin).has_point(visual_point) else &""
	if LEFT_BASKET_INPUT_REGION.grow(expanded_margin).has_point(visual_point):
		return &"left"
	if RIGHT_BASKET_INPUT_REGION.grow(expanded_margin).has_point(visual_point):
		return &"right"
	return &""


func _control_contains_local_point(control: Control, point: Vector2, margin: float = 0.0) -> bool:
	if control == null or not control.visible:
		return false
	var canvas_point := get_global_transform_with_canvas() * point
	var control_point := control.get_global_transform_with_canvas().affine_inverse() * canvas_point
	return Rect2(Vector2.ZERO, control.size).grow(maxf(margin, 0.0)).has_point(control_point)


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
	var lanes := Dictionary(_machine.get("lanes", {}))
	for lane_id in [&"left", &"right"]:
		var fallback := _machine if lane_id == &"left" else {}
		var lane := Dictionary(lanes.get(lane_id, fallback))
		if StringName(lane.get("state", &"")) in [
			&"frying",
			&"ready_safe",
			&"overcooking",
			&"draining",
		]:
			return true
	return false


func _state_text(state: StringName) -> String:
	return {
		&"unowned": "油条机未解锁", &"idle": "长按油条机添加面胚", &"loaded": "点击油条机开始炸制",
		&"frying": "炸制中", &"ready_safe": "点击油条机抬起沥网", &"overcooking": "油条即将炸糊",
		&"draining": "正在沥油", &"ready_to_collect": "点击任意油条，整篮放入成品盘" if _finished_tray_unlocked else "成品盘尚未解锁，炸好的油条请暂存在滤网中", &"burnt": "油条已炸糊，拖去废弃",
	}.get(state, "油条机")


static func _failure_text(reason: StringName) -> String:
	return {
		&"capacity_exceeded": "炸篮已满", &"insufficient_stock": "油条面胚不足", &"recipe_locked": "油条配方尚未解锁",
		&"equipment_not_owned": "油条机尚未解锁", &"invalid_equipment_state": "当前不能放入面胚",
		&"finished_tray_locked": "对应成品盘尚未解锁，炸好的成品请暂存在炸篮中",
		&"prepared_product_slot_full": "成品盘已满，请先出餐或废弃盘内油条",
	}.get(reason, "操作未完成：%s" % str(reason))


static func _restock_failure_text(reason: StringName, status: Dictionary) -> String:
	match reason:
		&"stock_locked": return "油条面胚尚未解锁"
		&"capacity_reached": return "油条面胚已补满"
		&"insufficient_coins": return "余额不足：每份需要 %d 金币" % int(status.get("unit_cost", 0))
		_: return "暂时无法补货：%s" % str(reason)
