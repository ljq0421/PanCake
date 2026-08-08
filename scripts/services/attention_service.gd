class_name AttentionService
extends RefCounted

const CATALOG := preload("res://scripts/data/five_area_catalog.gd")
const MAX_ITEMS := 3


static func build_attention(
	machine_snapshots: Dictionary,
	output_rack: Array[Dictionary],
	tray_snapshot: Dictionary
) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for device_key in machine_snapshots:
		var device_id := StringName(device_key)
		var snapshot := Dictionary(machine_snapshots[device_key])
		if device_id == &"device.steamer":
			for raw_layer in Array(snapshot.get("layers", [])):
				_append_machine_attention(items, Dictionary(raw_layer), device_id, StringName("%s.layer.%d" % [device_id, int(Dictionary(raw_layer).get("layer_index", 0))]))
		else:
			_append_machine_attention(items, snapshot, device_id, device_id)
	for rack_index in range(output_rack.size()):
		var cup := Dictionary(output_rack[rack_index])
		if cup.is_empty():
			continue
		var seconds := maxf(float(cup.get("seconds_to_loss", 0.0)), 0.0)
		items.append(_entry(&"output.fresh_soy_milk", &"area.fresh_soy_milk", &"red" if seconds <= 2.0 else &"yellow", seconds, &"soy_output_spoil"))
	for raw_slot in Array(tray_snapshot.get("slots", [])):
		var slot := Dictionary(raw_slot)
		if slot.is_empty() or Dictionary(slot.get("product", {})).is_empty():
			continue
		var age := maxf(float(slot.get("age_seconds", 0.0)), 0.0)
		var seconds := maxf(60.0 - age, 0.0)
		if age >= 20.0:
			items.append(_entry(StringName("pancake_tray.%d" % int(slot.get("slot_index", 0))), &"area.pancake", &"red" if seconds <= 10.0 else &"yellow", seconds, &"tray_stale"))
	items.sort_custom(_sort_attention)
	return items.slice(0, mini(items.size(), MAX_ITEMS))


static func _append_machine_attention(items: Array[Dictionary], snapshot: Dictionary, device_id: StringName, source_id: StringName) -> void:
	var state := StringName(snapshot.get("state", &""))
	var area_id := StringName(CATALOG.device_definition(device_id).get("area_id", &""))
	var seconds := maxf(float(snapshot.get("seconds_to_loss", 0.0)), 0.0)
	var severity := &""
	var status_key := &""
	if state in [&"overcooking", &"burnt", &"spoiled", &"blocked"]:
		severity = &"red"
		status_key = StringName("%s_%s" % [str(area_id).trim_prefix("area."), str(state)])
	elif state in [&"ready_safe", &"ready_hot", &"ready_to_collect", &"ready"]:
		severity = &"red" if seconds <= 2.0 else &"yellow"
		status_key = StringName("%s_ready" % str(area_id).trim_prefix("area."))
	if not severity.is_empty():
		items.append(_entry(source_id, area_id, severity, seconds, status_key))


static func _entry(source_id: StringName, area_id: StringName, severity: StringName, seconds: float, status_key: StringName) -> Dictionary:
	return {"source_id": source_id, "area_id": area_id, "severity": severity, "seconds_to_irreversible_loss": snappedf(maxf(seconds, 0.0), 0.1), "status_key": status_key}


static func _sort_attention(left: Dictionary, right: Dictionary) -> bool:
	var left_rank := 0 if StringName(left.get("severity", &"")) == &"red" else 1
	var right_rank := 0 if StringName(right.get("severity", &"")) == &"red" else 1
	if left_rank != right_rank:
		return left_rank < right_rank
	var left_seconds := float(left.get("seconds_to_irreversible_loss", 0.0))
	var right_seconds := float(right.get("seconds_to_irreversible_loss", 0.0))
	if not is_equal_approx(left_seconds, right_seconds):
		return left_seconds < right_seconds
	return CATALOG.AREA_IDS.find(StringName(left.get("area_id", &""))) < CATALOG.AREA_IDS.find(StringName(right.get("area_id", &"")))
