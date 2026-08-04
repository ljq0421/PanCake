class_name InitialUnlockWorkstationAdapter
extends Node

const CATALOG := preload("res://scripts/data/workstation_expansion_catalog.gd")
const PROGRESSION_SERVICE := preload("res://scripts/services/workstation_progression_service.gd")
const PRODUCTION_SERVICE := preload("res://scripts/services/expansion_production_service.gd")
const HOLD_REFILL_SERVICE := preload("res://scripts/services/hold_refill_service.gd")

@export var initial_progression_snapshot: Dictionary = {}

var progression: RefCounted
var production: RefCounted
var hold_refill: RefCounted


func _ready() -> void:
	call_deferred("apply_progression_snapshot", initial_progression_snapshot)


func _process(delta: float) -> void:
	if production != null:
		production.call("advance_time", delta)


func apply_progression_snapshot(snapshot: Dictionary) -> void:
	progression = PROGRESSION_SERVICE.new(snapshot)
	production = PRODUCTION_SERVICE.new(progression)
	hold_refill = HOLD_REFILL_SERVICE.new(progression)
	_refresh_owned_tools()
	_refresh_device_slots()
	_refresh_ingredient_trays()
	_bind_workstation_state()
	_hide_direct_ingredient_labels()


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
		button.disabled = not owned
		button.mouse_filter = Control.MOUSE_FILTER_STOP if owned else Control.MOUSE_FILTER_IGNORE
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
		var hit_area := child.get_node_or_null("InteractionArea") as BaseButton
		if hit_area != null:
			hit_area.disabled = not owned
			hit_area.mouse_filter = Control.MOUSE_FILTER_STOP if owned else Control.MOUSE_FILTER_IGNORE
		var cover := child.get_node_or_null("LockedCover") as CanvasItem
		if cover != null:
			cover.visible = not owned and bool(child.get_meta(&"show_locked_cover", true))
		child.set_meta(&"machine_state", snapshot.get("state", &"unowned"))


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


func _bind_workstation_state() -> void:
	var workstation := get_parent().get_parent()
	var stock_model: Variant = workstation.get("ingredient_stock_model")
	if stock_model is RefCounted and stock_model.has_signal("changed"):
		var changed := Signal(stock_model, &"changed")
		if not changed.is_connected(_hide_direct_ingredient_labels):
			changed.connect(_hide_direct_ingredient_labels)


func _hide_direct_ingredient_labels(_ingredient_type: StringName = &"", _current_stock: int = 0) -> void:
	for slot_name in [&"EggButton", &"BaocuiButton", &"ScallionButton"]:
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
