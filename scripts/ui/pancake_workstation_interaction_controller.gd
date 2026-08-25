class_name PancakeWorkstationInteractionController
extends Node

signal station_requested(area_id: StringName)

const RESTOCK_SERVICE := preload("res://scripts/services/five_area_restock_service.gd")
const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const INTERACTIVE_STATION_AREAS: Array[StringName] = [
	&"area.youtiao",
	&"area.fresh_soy_milk",
]

const INGREDIENT_STOCK_IDS := {
	&"egg": &"stock.pancake.egg",
	&"baocui": &"stock.pancake.baocui",
	&"ham_sausage": &"stock.pancake.ham_sausage",
	&"scallion": &"stock.pancake.scallion",
	&"meat_floss": &"stock.pancake.meat_floss",
	&"pork_tenderloin": &"stock.pancake.pork_tenderloin",
	&"coriander": &"stock.pancake.coriander",
	&"preserved_mustard": &"stock.pancake.preserved_mustard",
}

const STOCK_INGREDIENT_IDS := {
	&"stock.pancake.baocui": &"baocui",
	&"stock.pancake.scallion": &"scallion",
	&"stock.pancake.ham_sausage": &"ham_sausage",
	&"stock.pancake.meat_floss": &"meat_floss",
	&"stock.pancake.coriander": &"coriander",
	&"stock.pancake.preserved_mustard": &"preserved_mustard",
	&"stock.pancake.pork_tenderloin": &"pork_tenderloin",
}

var _restock: RefCounted
var _hovered_source: Button
var _hover_previous_instructions := ""
var _active_refill_source: Button
var _active_refill_stock_id: StringName = &""
var _unlocked_station_areas: Dictionary = {}


func _ready() -> void:
	var session := _session()
	if session == null:
		return
	_restock = RESTOCK_SERVICE.new(session)
	for binding in [
		[&"inventory_changed", _on_inventory_changed],
		[&"progression_changed", _on_progression_changed],
	]:
		var signal_ref := Signal(session, binding[0])
		if not signal_ref.is_connected(binding[1]):
			signal_ref.connect(binding[1])
	_bind_direct_refill_slots()
	_bind_locked_art_interactions()
	_refresh_formal_state()


func _input(event: InputEvent) -> void:
	if _active_refill_stock_id.is_empty() or not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
		_release_active_refill()


func _on_inventory_changed(_snapshot: Dictionary) -> void:
	_sync_live_ingredient_stock()
	_refresh_refill_source_tooltips()


func _on_progression_changed(_snapshot: Dictionary) -> void:
	_refresh_formal_state()


func _refresh_formal_state() -> void:
	var session := _session()
	if session == null:
		return
	var workstation := _workstation()
	if workstation != null and workstation.has_method("apply_progression_effects"):
		workstation.call("apply_progression_effects", Dictionary(session.call("five_area_progression_snapshot")))
	_refresh_ingredient_trays()
	_refresh_material_slot_locks()
	_sync_live_ingredient_stock()
	_refresh_formal_five_area_state()
	_refresh_refill_source_tooltips()


func _refresh_ingredient_trays() -> void:
	var session := _session()
	if session == null:
		return
	var unlocked: Array[StringName] = []
	if session.has_method("unlocked_ingredient_ids"):
		unlocked.assign(session.call("unlocked_ingredient_ids"))
	for slot in _all_direct_ingredient_slots():
		slot.visible = false
		slot.disabled = true
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.remove_meta(&"material_slot_id")
	var fixed_slots := {
		&"egg": &"slot.07",
		&"baocui": &"slot.08",
		&"scallion": &"slot.09",
	}
	for ingredient_id in fixed_slots:
		var fixed_slot := _slot_for_any_ingredient(ingredient_id)
		if fixed_slot != null and unlocked.has(ingredient_id):
			_place_ingredient_in_material_slot(fixed_slot, fixed_slots[ingredient_id])
	var occupied_index := 0
	for stock_id in CATALOG.PANCAKE_ADD_ON_DISPLAY_ORDER:
		var ingredient_id: StringName = STOCK_INGREDIENT_IDS.get(stock_id, &"")
		if ingredient_id.is_empty() or not unlocked.has(ingredient_id):
			continue
		var slot := _slot_for_any_ingredient(ingredient_id)
		if slot == null or occupied_index >= CATALOG.PANCAKE_ADD_ON_SLOT_PRIORITY.size():
			continue
		_place_ingredient_in_material_slot(slot, CATALOG.PANCAKE_ADD_ON_SLOT_PRIORITY[occupied_index])
		occupied_index += 1


func _refresh_material_slot_locks() -> void:
	var occupied_slot_names: Dictionary = {}
	for ingredient_slot in _all_direct_ingredient_slots():
		if ingredient_slot.visible and ingredient_slot.has_meta(&"material_slot_id"):
			occupied_slot_names[_scene_slot_name(StringName(ingredient_slot.get_meta(&"material_slot_id")))] = true
	for slot_id in CATALOG.PANCAKE_ADD_ON_SLOT_PRIORITY:
		var slot_name := _scene_slot_name(slot_id)
		var occupied := bool(occupied_slot_names.get(slot_name, false))
		var locked_art := get_node_or_null("../LockedIngredientArtwork/%s" % slot_name) as CanvasItem
		if locked_art != null:
			locked_art.visible = not occupied
		var locked_button := get_node_or_null("../LockedIngredientInteractions/%sLockedButton" % slot_name) as Button
		if locked_button != null:
			locked_button.visible = not occupied
			locked_button.disabled = occupied
			locked_button.mouse_filter = Control.MOUSE_FILTER_IGNORE if occupied else Control.MOUSE_FILTER_STOP
			locked_button.tooltip_text = "新小料解锁后会按 Slot10 → Slot11 → Slot12 → Slot13 → Slot14 的顺序放入。"


func _sync_live_ingredient_stock() -> void:
	var session := _session()
	var workstation := _workstation()
	if session == null or workstation == null or not session.has_method("inventory_snapshot"):
		return
	var stock_model: Variant = workstation.get("ingredient_stock_model")
	if not stock_model is RefCounted:
		return
	var inventory: Dictionary = session.call("inventory_snapshot")
	for ingredient_id in INGREDIENT_STOCK_IDS:
		var stable_stock_id: StringName = INGREDIENT_STOCK_IDS[ingredient_id]
		stock_model.call("set_current", ingredient_id, maxi(int(inventory.get(str(stable_stock_id), 0)), 0))


func _bind_direct_refill_slots() -> void:
	for slot in _all_direct_ingredient_slots():
		var requested := Signal(slot, &"hold_requested")
		if not requested.is_connected(_on_refill_hold_requested):
			requested.connect(_on_refill_hold_requested)
		var advanced := Signal(slot, &"hold_advanced")
		if not advanced.is_connected(_on_refill_hold_advanced):
			advanced.connect(_on_refill_hold_advanced)
		var released := Signal(slot, &"hold_released")
		if not released.is_connected(_on_refill_hold_released):
			released.connect(_on_refill_hold_released)
		var entered_handler := _on_source_hovered.bind(slot)
		if not slot.mouse_entered.is_connected(entered_handler):
			slot.mouse_entered.connect(entered_handler)
		var exited_handler := _on_source_unhovered.bind(slot)
		if not slot.mouse_exited.is_connected(exited_handler):
			slot.mouse_exited.connect(exited_handler)


func _on_refill_hold_requested(ingredient_id: StringName) -> void:
	var source := _slot_for_ingredient(ingredient_id)
	var stock_id := _stable_stock_id(ingredient_id)
	if _restock == null or source == null or source.disabled or stock_id.is_empty():
		if source != null:
			source.call("reject_hold")
		return
	var status: Dictionary = _restock.call("status", stock_id)
	if not bool(status.get("success", false)):
		source.call("reject_hold")
		_show_refill_message(ingredient_id, StringName(status.get("reason", &"")))
		return
	if int(status.get("current_stock", 0)) >= int(status.get("capacity", 0)):
		source.call("reject_hold")
		_show_refill_message(ingredient_id, &"capacity_reached")
		return
	if int(status.get("coins", 0)) < int(status.get("unit_cost", 0)):
		source.call("reject_hold")
		_show_refill_message(ingredient_id, &"insufficient_coins")
		return
	_release_active_refill()
	_active_refill_source = source
	_active_refill_stock_id = stock_id
	source.call("accept_hold")
	_refresh_source_tooltip(source, ingredient_id)


func _on_refill_hold_advanced(ingredient_id: StringName, delta: float) -> void:
	if _stable_stock_id(ingredient_id) != _active_refill_stock_id or _restock == null:
		return
	var result: Dictionary = _restock.call("advance_hold", _active_refill_stock_id, delta)
	if bool(result.get("auto_stopped", false)):
		_show_refill_message(ingredient_id, StringName(result.get("reason", &"")))
		_clear_active_refill()


func _on_refill_hold_released(ingredient_id: StringName) -> void:
	if _stable_stock_id(ingredient_id) == _active_refill_stock_id:
		_release_active_refill()


func _release_active_refill() -> void:
	if _active_refill_stock_id.is_empty():
		return
	if _restock != null:
		_restock.call("release", _active_refill_stock_id)
	_clear_active_refill()
	_refresh_refill_source_tooltips()


func _clear_active_refill() -> void:
	if _active_refill_source != null:
		_active_refill_source.call("stop_hold")
	_active_refill_source = null
	_active_refill_stock_id = &""


func _refresh_refill_source_tooltips() -> void:
	for source in _direct_ingredient_slots():
		_refresh_source_tooltip(source, StringName(str(source.get("ingredient_type"))))


func _refresh_source_tooltip(source: Button, ingredient_id: StringName) -> void:
	if _restock == null:
		return
	var stock_id := _stable_stock_id(ingredient_id)
	var status: Dictionary = _restock.call("status", stock_id)
	if not bool(status.get("success", false)):
		return
	var current := int(status.get("current_stock", 0))
	var capacity := int(status.get("capacity", 0))
	var state_hint := "按住持续补货"
	if current >= capacity:
		state_hint = "已满"
	elif int(status.get("coins", 0)) < int(status.get("unit_cost", 0)):
		state_hint = "金币不足"
	var help_text := "%s · 每份 %d 金币 · %.2f 秒\n当前 %d/%d · 余额 %d · %s" % [
		_ingredient_label(ingredient_id), int(status.get("unit_cost", 0)), float(status.get("unit_seconds", 0.0)), current, capacity, int(status.get("coins", 0)), state_hint,
	]
	source.tooltip_text = ""
	source.set_meta(&"refill_help_text", help_text)
	if _hovered_source == source:
		_set_hover_instructions(help_text)


func _show_refill_message(ingredient_id: StringName, reason: StringName) -> void:
	var status_label := get_node_or_null("../BottomStrip/ToolStatusLabel") as Label
	if status_label == null:
		return
	match reason:
		&"capacity_reached": status_label.text = "%s盘已经满了" % _ingredient_label(ingredient_id)
		&"insufficient_coins": status_label.text = "金币不足，无法继续补%s" % _ingredient_label(ingredient_id)
		&"stock_locked": status_label.text = "%s尚未解锁" % _ingredient_label(ingredient_id)
		_: status_label.text = "当前无法补充%s" % _ingredient_label(ingredient_id)


func _on_source_hovered(source: Button) -> void:
	var instructions := get_node_or_null("../BottomStrip/Instructions") as Label
	if instructions == null:
		return
	_hovered_source = source
	_hover_previous_instructions = instructions.text
	_set_hover_instructions(str(source.get_meta(&"refill_help_text", "")))


func _on_source_unhovered(source: Button) -> void:
	if _hovered_source != source:
		return
	var instructions := get_node_or_null("../BottomStrip/Instructions") as Label
	if instructions != null:
		instructions.text = _hover_previous_instructions
	_hovered_source = null
	_hover_previous_instructions = ""


func _set_hover_instructions(help_text: String) -> void:
	var instructions := get_node_or_null("../BottomStrip/Instructions") as Label
	if instructions != null:
		instructions.text = help_text


func _refresh_formal_five_area_state() -> void:
	var session := _session()
	if session == null:
		return
	var formal_snapshot: Dictionary = session.call("five_area_progression_snapshot")
	var unlocked: Dictionary = {}
	for area_id in Array(formal_snapshot.get("unlocked_area_ids", [])):
		unlocked[StringName(area_id)] = true
	_unlocked_station_areas = unlocked
	for button_path in ["../FiveAreaStationClickLayers/FreshSoyMilkLockedClickLayer", "../FiveAreaStationClickLayers/YoutiaoLockedClickLayer", "../FiveAreaStationClickLayers/PackagedDrinkLockedClickLayer", "../FiveAreaStationClickLayers/SteamerLockedClickLayer"]:
		var station_button := get_node_or_null(button_path) as Button
		if station_button == null:
			continue
		var area_is_unlocked := bool(unlocked.get(StringName(station_button.get_meta(&"area_id", &"")), false))
		var area_id := StringName(station_button.get_meta(&"area_id", &""))
		var can_open_station := area_is_unlocked and INTERACTIVE_STATION_AREAS.has(area_id)
		station_button.disabled = area_is_unlocked and not can_open_station
		station_button.mouse_filter = Control.MOUSE_FILTER_STOP if not area_is_unlocked or can_open_station else Control.MOUSE_FILTER_IGNORE
		station_button.tooltip_text = "点击打开%s操作台" % _station_label(area_id) if can_open_station else station_button.tooltip_text
		var locked_art := get_node_or_null(station_button.get_meta(&"locked_art_path", NodePath())) as CanvasItem
		if locked_art != null:
			locked_art.visible = not area_is_unlocked
		var active_art := get_node_or_null(station_button.get_meta(&"active_art_path", NodePath())) as CanvasItem
		if active_art != null:
			active_art.visible = area_is_unlocked


func _bind_locked_art_interactions() -> void:
	for parent_path in [&"../FiveAreaStationClickLayers", &"../LockedIngredientInteractions"]:
		var interaction_parent := get_node_or_null(NodePath(parent_path))
		if interaction_parent == null:
			continue
		for child in interaction_parent.get_children():
			var button := child as Button
			if button == null:
				continue
			var handler := _on_locked_art_pressed.bind(button)
			if not button.pressed.is_connected(handler):
				button.pressed.connect(handler)


func _on_locked_art_pressed(button: Button) -> void:
	var area_id := StringName(button.get_meta(&"area_id", &""))
	if bool(_unlocked_station_areas.get(area_id, false)) and INTERACTIVE_STATION_AREAS.has(area_id):
		station_requested.emit(area_id)
		button.release_focus()
		return
	var artwork := get_node_or_null(button.get_meta(&"locked_art_path", NodePath())) as Control
	if artwork != null:
		artwork.pivot_offset = artwork.size * 0.5
		artwork.scale = Vector2(0.9, 0.9)
		var pulse := create_tween()
		pulse.tween_property(artwork, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var condition := str(button.get_meta(&"unlock_condition", ""))
	if condition.is_empty():
		condition = "此槽当前没有已解锁小料；新小料会按既定槽位优先序自动放入。"
	var status_label := get_node_or_null("../BottomStrip/ToolStatusLabel") as Label
	if status_label != null:
		status_label.text = condition
	button.release_focus()


static func _station_label(area_id: StringName) -> String:
	match area_id:
		&"area.youtiao": return "油条"
		&"area.fresh_soy_milk": return "现磨豆浆"
	return "分区"


func _direct_ingredient_slots() -> Array[Button]:
	var result: Array[Button] = []
	for slot in _all_direct_ingredient_slots():
		if slot.visible and not slot.disabled:
			result.append(slot)
	return result


func _all_direct_ingredient_slots() -> Array[Button]:
	var result: Array[Button] = []
	for slot_name in [&"EggButton", &"BaocuiButton", &"ScallionButton", &"HamButton", &"MeatFlossButton", &"PorkTenderloinButton", &"CorianderButton", &"PreservedMustardButton"]:
		var slot := get_node_or_null("../IngredientRack/%s" % slot_name) as Button
		if slot != null:
			result.append(slot)
	return result


func _slot_for_ingredient(ingredient_id: StringName) -> Button:
	for slot in _direct_ingredient_slots():
		if StringName(str(slot.get("ingredient_type"))) == ingredient_id:
			return slot
	return null


func _slot_for_any_ingredient(ingredient_id: StringName) -> Button:
	for slot in _all_direct_ingredient_slots():
		if StringName(str(slot.get("ingredient_type"))) == ingredient_id:
			return slot
	return null


func _place_ingredient_in_material_slot(slot: Button, material_slot_id: StringName) -> void:
	var target := get_node_or_null("../MaterialDock/%s" % _scene_slot_name(material_slot_id)) as Control
	var rack := slot.get_parent() as Control
	if target == null or rack == null:
		return
	# MaterialDock and IngredientRack are sibling scene layers. Use the authored
	# offsets because MaterialDock's full-rect metadata layer acquires a runtime
	# minimum-size translation from its off-screen children.
	var target_rect: Rect2 = target.get_meta(&"worktop_rect", Rect2(
		Vector2(target.offset_left, target.offset_top),
		Vector2(target.offset_right - target.offset_left, target.offset_bottom - target.offset_top)
	))
	slot.position = target_rect.position - rack.position
	slot.size = target_rect.size
	slot.visible = true
	slot.disabled = false
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.set_meta(&"material_slot_id", material_slot_id)


func _scene_slot_name(material_slot_id: StringName) -> StringName:
	return StringName("Slot%02d" % int(str(material_slot_id).get_slice(".", 1)))


func _stable_stock_id(ingredient_id: StringName) -> StringName:
	return INGREDIENT_STOCK_IDS.get(ingredient_id, &"") as StringName


func _ingredient_label(ingredient_id: StringName) -> String:
	var workstation := _workstation()
	if workstation != null and workstation.get("ingredient_model") != null:
		return str(workstation.get("ingredient_model").display_name(ingredient_id))
	return str(ingredient_id)


func _session() -> Node:
	return get_node_or_null("/root/GameSession")


func _workstation() -> Node:
	return get_parent().get_parent()
