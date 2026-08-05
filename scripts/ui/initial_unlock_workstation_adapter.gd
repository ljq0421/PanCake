class_name InitialUnlockWorkstationAdapter
extends Node

const CATALOG := preload("res://scripts/data/workstation_expansion_catalog.gd")
const PROGRESSION_SERVICE := preload("res://scripts/services/workstation_progression_service.gd")
const PRODUCTION_SERVICE := preload("res://scripts/services/expansion_production_service.gd")
const HOLD_REFILL_SERVICE := preload("res://scripts/services/hold_refill_service.gd")
const DEVICE_TIER_TEXTURES := {
	CATALOG.DEVICE_SOY_MILK: [
		preload("res://resources/art/workstation/expansion/machines/soy_milk_machine_tier_1_v1.png"),
		preload("res://resources/art/workstation/expansion/machines/soy_milk_machine_tier_2_v1.png"),
		preload("res://resources/art/workstation/expansion/machines/soy_milk_machine_tier_3_v1.png"),
	],
	CATALOG.DEVICE_YOUTIAO: [
		preload("res://resources/art/workstation/expansion/machines/youtiao_fryer_tier_1_v1.png"),
		preload("res://resources/art/workstation/expansion/machines/youtiao_fryer_tier_2_v1.png"),
		preload("res://resources/art/workstation/expansion/machines/youtiao_fryer_tier_3_v1.png"),
	],
	CATALOG.DEVICE_EGG_WAFFLE: [
		preload("res://resources/art/workstation/expansion/machines/egg_waffle_machine_tier_1_v1.png"),
		preload("res://resources/art/workstation/expansion/machines/egg_waffle_machine_tier_2_v1.png"),
		preload("res://resources/art/workstation/expansion/machines/egg_waffle_machine_tier_3_v1.png"),
	],
}
@export var initial_progression_snapshot: Dictionary = {}

var progression: RefCounted
var production: RefCounted
var hold_refill: RefCounted
var _hovered_source: Button
var _hover_previous_instructions := ""
var _active_refill_source: Button
var _active_refill_stock_id: StringName = &""
var _held_device_id: StringName = &""
var _device_hold_elapsed := 0.0
var _device_refill_active := false
var _production_save_elapsed := 0.0

const DEVICE_REFILL_HOLD_THRESHOLD := 0.35


func _ready() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_signal("coins_changed"):
		var changed := Signal(session, &"coins_changed")
		if not changed.is_connected(_on_session_coins_changed):
			changed.connect(_on_session_coins_changed)
	call_deferred("apply_progression_snapshot", initial_progression_snapshot)


func _process(delta: float) -> void:
	if production != null:
		production.call("advance_time", delta)
		_persist_active_production(delta)
	_advance_device_refill_hold(delta)


func _input(event: InputEvent) -> void:
	if _active_refill_stock_id.is_empty() or not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
		_release_active_refill()


func apply_progression_snapshot(snapshot: Dictionary) -> void:
	var effective_snapshot := snapshot.duplicate(true)
	var session := get_node_or_null("/root/GameSession")
	if effective_snapshot.is_empty():
		if session != null and session.has_method("workstation_progression_snapshot"):
			effective_snapshot = Dictionary(session.call("workstation_progression_snapshot"))
	if snapshot.is_empty() and session != null and session.has_method("progression_service"):
		progression = session.call("progression_service")
	else:
		progression = PROGRESSION_SERVICE.new(effective_snapshot)
	var workstation := get_parent().get_parent()
	var live_inventory: Variant = workstation.get("ingredient_stock_model")
	if live_inventory is RefCounted:
		var target_capacity := int(progression.call("ingredient_box_capacity"))
		var first_stock_id: StringName = CATALOG.stock_ids()[0]
		if int(live_inventory.call("capacity", first_stock_id)) != target_capacity:
			live_inventory.call("set_capacity_for_all", target_capacity)
		live_inventory.call("load_snapshot", Dictionary(effective_snapshot.get("ingredient_stock", {})))
		progression.set("inventory", live_inventory)
	production = PRODUCTION_SERVICE.new(progression)
	hold_refill = HOLD_REFILL_SERVICE.new(progression)
	if workstation.has_method("apply_progression_effects"):
		workstation.call("apply_progression_effects", progression.call("snapshot"))
	_refresh_owned_tools()
	_refresh_device_slots()
	_refresh_ingredient_trays()
	_bind_workstation_state()
	_bind_direct_refill_slots()
	_hide_direct_ingredient_labels()
	_refresh_refill_source_tooltips()


func progression_snapshot() -> Dictionary:
	return {} if progression == null else progression.call("snapshot")


func machine_snapshot(device_id: StringName) -> Dictionary:
	if production == null:
		return {"owned": false, "has_output": false, "state": &"unowned"}
	return production.call("machine_snapshot", device_id)


func production_service() -> RefCounted:
	return production


func refill_service() -> RefCounted:
	return hold_refill


func _refresh_owned_tools() -> void:
	if progression == null:
		return
	_set_button_owned("../LeftRack/ScraperButton", progression.call("owns", CATALOG.TOOL_SPREADER_BASIC))
	_set_button_owned("../LeftRack/SauceBrushButton", progression.call("owns", CATALOG.TOOL_SAUCE_BRUSH_MANUAL))
	# Folding is part of the established pancake flow and has no purchase entry.
	_set_button_owned("../LeftRack/FoldButton", true)
	var fold_button := get_node_or_null("../LeftRack/FoldButton") as BaseButton
	if fold_button != null:
		fold_button.visible = false
		fold_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_button_owned("../LeftRack/LadleButton", true)
	var upgrade_hooks := get_node_or_null("../ExpansionLayout/LeftZone/UpgradeToolHooks")
	if upgrade_hooks == null:
		return
	for child in upgrade_hooks.get_children():
		var button := child as BaseButton
		if button == null:
			continue
		var item_id := StringName(str(button.get_meta(&"item_id", "")))
		var owned := not item_id.is_empty() and bool(progression.call("owns", item_id))
		button.visible = owned
		button.disabled = not owned
		button.mouse_filter = Control.MOUSE_FILTER_STOP if owned else Control.MOUSE_FILTER_IGNORE
		if owned:
			button.tooltip_text = str(CATALOG.purchase_presentation(item_id).get("description", "已解锁"))
			var handler := _on_upgrade_tool_pressed.bind(item_id)
			if not button.pressed.is_connected(handler):
				button.pressed.connect(handler)
		var cover := button.get_node_or_null("LockedCover") as CanvasItem
		if cover != null:
			cover.visible = not owned and bool(button.get_meta(&"show_locked_cover", true))


func _refresh_device_slots() -> void:
	var device_slots := get_node_or_null("../ExpansionLayout/DeviceSlots")
	if progression == null or production == null or device_slots == null:
		return
	for child in device_slots.get_children():
		var device_id := StringName(str(child.get_meta(&"device_id", "")))
		var snapshot: Dictionary = production.call("machine_snapshot", device_id)
		var owned := bool(snapshot.get("owned", false))
		var tier := int(snapshot.get("tier", -1))
		var equipment_art := child.get_node_or_null("EquipmentArt") as TextureRect
		if equipment_art != null:
			equipment_art.visible = owned
			if owned and DEVICE_TIER_TEXTURES.has(device_id):
				equipment_art.texture = DEVICE_TIER_TEXTURES[device_id][clampi(tier, CATALOG.TIER_BASIC, CATALOG.TIER_ADVANCED)]
		var hit_area := child.get_node_or_null("InteractionArea") as BaseButton
		if hit_area != null:
			hit_area.disabled = not owned
			hit_area.mouse_filter = Control.MOUSE_FILTER_STOP if owned else Control.MOUSE_FILTER_IGNORE
			if owned:
				var tier_data := CATALOG.device_tier(device_id, tier)
				hit_area.tooltip_text = "%s · %d档 · 单批%d份 · %.0f秒\n点击操作 · 按住补默认原料" % [
					_device_label(device_id), tier + 1, int(tier_data.get("capacity", 0)), float(tier_data.get("duration_seconds", 0.0))
				]
				var down_handler := _on_device_button_down.bind(device_id)
				if not hit_area.button_down.is_connected(down_handler):
					hit_area.button_down.connect(down_handler)
				var up_handler := _on_device_button_up.bind(device_id)
				if not hit_area.button_up.is_connected(up_handler):
					hit_area.button_up.connect(up_handler)
		var cover := child.get_node_or_null("LockedCover") as CanvasItem
		if cover != null:
			cover.visible = not owned and bool(child.get_meta(&"show_locked_cover", true))
		child.set_meta(&"machine_state", snapshot.get("state", &"unowned"))


func _on_upgrade_tool_pressed(item_id: StringName) -> void:
	var workstation := get_parent().get_parent()
	match item_id:
		CATALOG.TOOL_SPREADER_WIDE:
			var scraper := get_node_or_null("../LeftRack/ScraperButton") as Button
			if scraper != null:
				scraper.emit_signal("pressed")
		CATALOG.TOOL_PRESS:
			workstation.call("use_press_spreader")
		CATALOG.TOOL_SAUCE_BRUSH_AUTO:
			workstation.call("use_automatic_sauce_brush")


func _device_label(device_id: StringName) -> String:
	return str({
		CATALOG.DEVICE_SOY_MILK: "豆浆机",
		CATALOG.DEVICE_YOUTIAO: "炸油条机",
		CATALOG.DEVICE_EGG_WAFFLE: "鸡蛋仔机",
	}.get(device_id, str(device_id)))


func _on_device_button_down(device_id: StringName) -> void:
	_held_device_id = device_id
	_device_hold_elapsed = 0.0
	_device_refill_active = false


func _on_device_button_up(device_id: StringName) -> void:
	if device_id != _held_device_id:
		return
	if _device_refill_active:
		var stock_id := _default_device_stock_id(device_id)
		hold_refill.call("release", stock_id)
		_persist_progression()
	else:
		_advance_device_operation(device_id)
	_held_device_id = &""
	_device_hold_elapsed = 0.0
	_device_refill_active = false


func _advance_device_refill_hold(delta: float) -> void:
	if _held_device_id.is_empty() or hold_refill == null:
		return
	_device_hold_elapsed += maxf(delta, 0.0)
	if _device_hold_elapsed < DEVICE_REFILL_HOLD_THRESHOLD:
		return
	_device_refill_active = true
	var stock_id := _default_device_stock_id(_held_device_id)
	var result: Dictionary = hold_refill.call("advance_hold", stock_id, delta)
	if int(result.get("completed_units", 0)) > 0:
		_persist_progression()
		_show_device_message("%s原料 +%d · 当前%d/%d" % [
			_device_label(_held_device_id), int(result.get("completed_units", 0)), int(result.get("current_stock", 0)), int(result.get("capacity", 0))
		])
	if bool(result.get("auto_stopped", false)):
		hold_refill.call("release", stock_id)
		_held_device_id = &""
		_device_refill_active = false


func _advance_device_operation(device_id: StringName) -> void:
	if production == null:
		return
	var snapshot: Dictionary = production.call("machine_snapshot", device_id)
	var state := StringName(snapshot.get("state", &"unowned"))
	var result := {}
	if state == &"idle":
		var recipe_id := _default_device_recipe_id(device_id)
		result = production.call("load_input", device_id, recipe_id, 1)
		if bool(result.get("success", false)):
			_show_device_message("%s已装入1份%s；再次点击执行必要动作并启动" % [_device_label(device_id), str(CATALOG.recipe_definition(recipe_id).get("label", "原料"))])
		else:
			_show_device_message("%s原料不足：请按住设备补原料" % _device_label(device_id))
	elif state == &"loading":
		for action in Array(CATALOG.device_definition(device_id).get("required_before_start", [])):
			production.call("perform_action", device_id, StringName(action))
		result = production.call("start", device_id)
		_show_device_message("%s已启动 · 约%.0f秒完成" % [_device_label(device_id), float(result.get("duration_seconds", 0.0))])
	elif state == &"processing":
		_show_device_message("%s加工中 · %.0f/%.0f秒" % [_device_label(device_id), float(snapshot.get("processing_elapsed", 0.0)), float(snapshot.get("duration_seconds", 0.0))])
	elif bool(snapshot.get("has_output", false)):
		for action in Array(CATALOG.device_definition(device_id).get("required_before_collect", [])):
			production.call("perform_action", device_id, StringName(action))
		result = production.call("collect", device_id, int(snapshot.get("loaded_quantity", 1)))
		if bool(result.get("success", false)):
			_record_device_quality(device_id, float(result.get("product", {}).get("quality", 0.0)))
			_show_device_message("已收取%s · 品质%d" % [_device_label(device_id), roundi(float(result.get("product", {}).get("quality", 0.0)))])
	_persist_progression()
	_refresh_device_slots()


func _default_device_recipe_id(device_id: StringName) -> StringName:
	var recipe_ids := CATALOG.main_recipe_ids(device_id)
	return recipe_ids[0] if not recipe_ids.is_empty() else &""


func _default_device_stock_id(device_id: StringName) -> StringName:
	return StringName(CATALOG.recipe_definition(_default_device_recipe_id(device_id)).get("stock_id", ""))


func _record_device_quality(device_id: StringName, quality: float) -> void:
	if quality < 65.0 or progression == null:
		return
	var metric_id := {
		CATALOG.DEVICE_SOY_MILK: &"soy_good",
		CATALOG.DEVICE_YOUTIAO: &"youtiao_good",
		CATALOG.DEVICE_EGG_WAFFLE: &"egg_waffle_good",
	}.get(device_id, &"") as StringName
	if metric_id.is_empty():
		return
	progression.call("set_metric", metric_id, int(progression.call("metric", metric_id)) + 1)
	var soy_good := int(progression.call("metric", &"soy_good"))
	var youtiao_good := int(progression.call("metric", &"youtiao_good"))
	var waffle_good := int(progression.call("metric", &"egg_waffle_good"))
	progression.call("set_metric", &"soy_youtiao_good", mini(soy_good, youtiao_good))
	progression.call("set_metric", &"all_equipment_good", mini(soy_good, mini(youtiao_good, waffle_good)))


func _persist_active_production(delta: float) -> void:
	var has_active_state := false
	for device_id in CATALOG.DEVICE_DEFINITIONS:
		var snapshot: Dictionary = production.call("machine_snapshot", device_id)
		if snapshot.get("state", &"unowned") in [&"processing", &"completed_safe_period", &"quality_decaying", &"infinite_hold"]:
			has_active_state = true
			break
	if not has_active_state:
		_production_save_elapsed = 0.0
		return
	_production_save_elapsed += maxf(delta, 0.0)
	if _production_save_elapsed >= 1.0:
		_production_save_elapsed = 0.0
		_persist_progression()


func _show_device_message(message: String) -> void:
	var status_label := get_node_or_null("../BottomStrip/ToolStatusLabel") as Label
	if status_label != null:
		status_label.text = message


func _refresh_ingredient_trays() -> void:
	var tray_grid := get_node_or_null("../ExpansionLayout/RightZone/IngredientTrayGrid")
	if tray_grid == null:
		return
	# The first three physical trays are occupied by scene-backed direct ingredient buttons.
	# Tray buttons remain transparent underlays; the remaining nine positions stay locked.
	for child in tray_grid.get_children():
		var button := child as BaseButton
		if button == null:
			continue
		button.disabled = true
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var unlocked: Array = progression.call("unlocked_ingredient_ids") if progression != null else []
	for slot in _all_direct_ingredient_slots():
		var stock_id := StringName(str(slot.get("ingredient_type")))
		var is_unlocked := unlocked.has(stock_id)
		slot.visible = is_unlocked
		slot.disabled = not is_unlocked
		slot.mouse_filter = Control.MOUSE_FILTER_STOP if is_unlocked else Control.MOUSE_FILTER_IGNORE


func _bind_direct_refill_slots() -> void:
	for slot in _direct_ingredient_slots():
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


func _bind_workstation_state() -> void:
	var workstation := get_parent().get_parent()
	var stock_model: Variant = workstation.get("ingredient_stock_model")
	if stock_model is RefCounted and stock_model.has_signal("changed"):
		var changed := Signal(stock_model, &"changed")
		if not changed.is_connected(_hide_direct_ingredient_labels):
			changed.connect(_hide_direct_ingredient_labels)
		if not changed.is_connected(_on_live_stock_changed):
			changed.connect(_on_live_stock_changed)


func _on_refill_hold_requested(stock_id: StringName) -> void:
	var source := _slot_for_stock(stock_id)
	if progression == null or hold_refill == null or source == null or source.disabled:
		if source != null:
			source.call("reject_hold")
		return
	var refill_status: Dictionary = hold_refill.call("status", stock_id)
	if not bool(refill_status.get("success", false)):
		source.call("reject_hold")
		_refresh_source_tooltip(source, stock_id, &"unknown_refill_entry")
		_show_refill_message(stock_id, &"unknown_refill_entry")
		return
	if int(refill_status.get("current_stock", 0)) >= int(refill_status.get("capacity", 0)):
		source.call("reject_hold")
		_refresh_source_tooltip(source, stock_id, &"capacity_reached")
		_show_refill_message(stock_id, &"capacity_reached")
		return
	if int(progression.get("coins")) < int(refill_status.get("unit_cost", 0)):
		source.call("reject_hold")
		_refresh_source_tooltip(source, stock_id, &"insufficient_coins")
		_show_refill_message(stock_id, &"insufficient_coins")
		return
	_release_active_refill()
	_active_refill_source = source
	_active_refill_stock_id = stock_id
	source.call("accept_hold")
	_refresh_source_tooltip(source, stock_id)


func _on_refill_hold_advanced(stock_id: StringName, delta: float) -> void:
	if stock_id != _active_refill_stock_id:
		return
	_advance_active_refill(delta)


func _on_refill_hold_released(stock_id: StringName) -> void:
	if stock_id != _active_refill_stock_id:
		return
	_release_active_refill()


func _advance_active_refill(delta: float) -> void:
	if hold_refill == null or _active_refill_stock_id.is_empty():
		return
	var stock_id := _active_refill_stock_id
	var source := _active_refill_source
	var result: Dictionary = hold_refill.call("advance_hold", stock_id, maxf(delta, 0.0))
	if int(result.get("completed_units", 0)) > 0 or bool(result.get("auto_stopped", false)):
		_persist_progression()
	if source != null:
		_refresh_source_tooltip(source, stock_id, StringName(result.get("reason", &"")))
	if bool(result.get("auto_stopped", false)):
		hold_refill.call("release", stock_id)
		_clear_active_refill()
		_show_refill_message(stock_id, StringName(result.get("reason", &"")))


func _release_active_refill() -> void:
	var had_active_refill := not _active_refill_stock_id.is_empty()
	if had_active_refill and hold_refill != null:
		hold_refill.call("release", _active_refill_stock_id)
	if had_active_refill:
		_persist_progression()
	_clear_active_refill()
	_refresh_refill_source_tooltips()


func _clear_active_refill() -> void:
	if _active_refill_source != null:
		_active_refill_source.call("stop_hold")
	_active_refill_source = null
	_active_refill_stock_id = &""


func _on_live_stock_changed(_ingredient_type: StringName, _current_stock: int) -> void:
	_hide_direct_ingredient_labels()
	_refresh_refill_source_tooltips()


func _on_session_coins_changed(current_coins: int) -> void:
	if progression == null:
		return
	progression.set("coins", maxi(current_coins, 0))
	_refresh_refill_source_tooltips()


func _persist_progression() -> void:
	if progression == null:
		return
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("save_workstation_progression"):
		session.call("save_workstation_progression", progression.call("snapshot"))


func _refresh_refill_source_tooltips() -> void:
	for source in _direct_ingredient_slots():
		var stock_id := StringName(str(source.get("ingredient_type")))
		_refresh_source_tooltip(source, stock_id)


func _refresh_source_tooltip(source: Button, stock_id: StringName, reason: StringName = &"") -> void:
	if hold_refill == null or progression == null:
		return
	var refill_status: Dictionary = hold_refill.call("status", stock_id)
	if not bool(refill_status.get("success", false)):
		return
	var current := int(refill_status.get("current_stock", 0))
	var capacity := int(refill_status.get("capacity", 0))
	var unit_cost := int(refill_status.get("unit_cost", 0))
	var unit_seconds := float(refill_status.get("unit_seconds", 0.0))
	var state_hint := "按住持续补货"
	if reason == &"capacity_reached" or current >= capacity:
		state_hint = "已满"
	elif reason == &"insufficient_coins" or int(progression.get("coins")) < unit_cost:
		state_hint = "金币不足"
	var help_text := "%s · 每份 %d 金币 · %.2f 秒\n当前 %d/%d · 余额 %d · %s" % [
		IngredientModel.display_name(stock_id),
		unit_cost,
		unit_seconds,
		current,
		capacity,
		int(progression.get("coins")),
		state_hint,
	]
	source.tooltip_text = ""
	source.set_meta(&"refill_help_text", help_text)
	if _hovered_source == source:
		_set_hover_instructions(help_text)


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


func _show_refill_message(ingredient_type: StringName, reason: StringName) -> void:
	var status_label := get_node_or_null("../BottomStrip/ToolStatusLabel") as Label
	if status_label == null:
		return
	match reason:
		&"capacity_reached":
			status_label.text = "%s盘已经满了" % IngredientModel.display_name(ingredient_type)
		&"insufficient_coins":
			status_label.text = "金币不足，无法继续补%s" % IngredientModel.display_name(ingredient_type)
		_:
			status_label.text = "当前无法补充%s" % IngredientModel.display_name(ingredient_type)


func _direct_ingredient_slots() -> Array[Button]:
	var result: Array[Button] = []
	for slot in _all_direct_ingredient_slots():
		if slot.visible and not slot.disabled:
			result.append(slot)
	return result


func _all_direct_ingredient_slots() -> Array[Button]:
	var result: Array[Button] = []
	for slot_name in [&"EggButton", &"BaocuiButton", &"ScallionButton", &"HamButton", &"MeatFlossButton", &"PorkTenderloinButton"]:
		var slot := get_node_or_null("../IngredientRack/%s" % slot_name) as Button
		if slot != null:
			result.append(slot)
	return result


func _slot_for_stock(stock_id: StringName) -> Button:
	for slot in _direct_ingredient_slots():
		if StringName(str(slot.get("ingredient_type"))) == stock_id:
			return slot
	return null


func _hide_direct_ingredient_labels(_ingredient_type: StringName = &"", _current_stock: int = 0) -> void:
	for slot_name in [&"EggButton", &"BaocuiButton", &"ScallionButton", &"HamButton", &"MeatFlossButton", &"PorkTenderloinButton"]:
		var slot := get_node_or_null("../IngredientRack/%s" % slot_name)
		if slot == null:
			continue
		for label_name in [&"Label", &"EmptyLabel"]:
			var label := slot.get_node_or_null(String(label_name)) as CanvasItem
			if label != null:
				label.visible = false


func _set_button_owned(path: NodePath, owned: bool) -> void:
	var button := get_node_or_null(path) as BaseButton
	if button == null:
		return
	button.set_meta(&"progression_owned", owned)
	button.disabled = not owned
	button.mouse_filter = Control.MOUSE_FILTER_STOP if owned else Control.MOUSE_FILTER_IGNORE
