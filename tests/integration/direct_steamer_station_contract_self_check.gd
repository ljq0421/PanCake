extends SceneTree

const SCENE := preload("res://scenes/gameplay/direct_steamer_station.tscn")
const CAPACITIES := [1, 2, 4]
const ASSET_PATHS := [
	"res://resources/art/workstation/expansion/machines/steamer_tier_1_closed_five_area_v6_chinese.png",
	"res://resources/art/workstation/expansion/machines/steamer_tier_1_open_five_area_v6_chinese.png",
	"res://resources/art/workstation/expansion/machines/steamer_tier_2_closed_five_area_v6_chinese.png",
	"res://resources/art/workstation/expansion/machines/steamer_tier_2_open_five_area_v6_chinese.png",
	"res://resources/art/workstation/expansion/machines/steamer_tier_3_closed_five_area_v6_chinese.png",
	"res://resources/art/workstation/expansion/machines/steamer_tier_3_open_five_area_v6_chinese.png",
]

var failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_assets()
	var station := SCENE.instantiate()
	root.add_child(station)
	await process_frame
	# This is a visual-contract fixture, so keep the project's GameSession autoload
	# from replacing the injected snapshots on the station's 0.1 second poll.
	station.set_process(false)
	_check(is_equal_approx(station.closed_machine_visual.size.x, 300.0), "whole-machine art uses the enlarged 300px workbench width")
	_check(station.closed_machine_visual.position == station.open_machine_visual.position and station.closed_machine_visual.size == station.open_machine_visual.size, "open and closed art keep identical enlarged registration")

	for tier in range(3):
		var capacity: int = CAPACITIES[tier]
		station.apply_visual_snapshot(_snapshot(tier, capacity), true)
		_check(station.closed_machine_visual.texture is AtlasTexture, "tier %d closed machine uses one cropped whole-machine sprite" % [tier + 1])
		_check(station.open_machine_visual.texture is AtlasTexture, "tier %d open machine uses one cropped whole-machine sprite" % [tier + 1])
		_check(station.closed_machine_visual.visible and is_equal_approx(station.closed_machine_visual.modulate.a, 1.0), "tier %d defaults to closed" % [tier + 1])
		_check(not station.open_machine_visual.visible and not station.is_lid_open(), "tier %d does not persist an open lid" % [tier + 1])
		_check(is_equal_approx(station.closed_machine_visual.size.x, 300.0), "tier %d keeps the same physical machine width" % [tier + 1])

	station.apply_visual_snapshot(_snapshot(1, 2), true)
	station.call("_on_steamer_drag_started", {"source_kind": &"steamer_input"})
	station.apply_visual_snapshot(_snapshot(1, 2), true)
	_check(station.is_lid_open(), "ordinary session polling does not cancel an active lid presentation")
	await create_timer(0.30).timeout
	_check(station.open_machine_visual.visible and station.open_machine_visual.modulate.a > 0.99, "input drag opens the lid")
	station.call("_on_steamer_drag_ended", {"source_kind": &"steamer_input"}, false)
	await create_timer(0.30).timeout
	_check(not station.is_lid_open() and not station.open_machine_visual.visible, "cancelled drag returns to closed")

	station.call("_on_steamer_drag_started", {"source_kind": &"steamer_layer"})
	station.call("_on_steamer_drag_started", {"source_kind": &"steamer_layer"})
	station.call("_on_steamer_drag_ended", {"source_kind": &"steamer_layer"}, true)
	_check(station.is_lid_open(), "overlapping drag lifecycle cannot close the remaining active presentation")
	station.call("_on_steamer_drag_ended", {"source_kind": &"steamer_layer"}, true)
	await create_timer(0.30).timeout
	_check(not station.is_lid_open(), "successful output drag returns to closed")

	station.call("_on_steamer_drag_started", {"source_kind": &"steamer_input"})
	station.apply_visual_snapshot(_snapshot(2, 4), true)
	_check(not station.is_lid_open() and station.closed_machine_visual.modulate.a > 0.99, "tier changes cancel stale lid animation")
	station.call("_on_steamer_drag_started", {"source_kind": &"steamer_input"})
	station.apply_visual_snapshot(_snapshot(2, 4), false)
	_check(not station.is_lid_open() and not station.closed_machine_visual.visible and not station.open_machine_visual.visible, "locking the area hides both states and closes the lid")

	var layers := [
		_layer(&"steaming", 6.2, 0.0),
		_layer(&"ready_safe", 0.0, 12.0),
		_layer(&"overcooking", 0.0, 4.0),
		_layer(&"spoiled", 0.0, 0.0),
	]
	station.apply_visual_snapshot({"owned": true, "tier": 2, "layer_capacity": 4, "layers": layers}, true, PackedStringArray(["recipe.steamer.mantou"]), {"stock.steamer.mantou": 2})
	_check(station.layer_labels[0].text.contains("7秒") and station.layer_labels[1].text.contains("12秒") and station.layer_labels[2].text.contains("4秒"), "phase countdowns remain intact")
	_check(station.layer_labels[3].text.contains("已蒸坏"), "spoiled food still has its terminal state copy")
	_check(station.layer_outputs[3].visible and not station.layer_outputs[3].disabled and bool(station.layer_outputs[3].source_ref().get("discardable", false)), "spoiled food remains a waste-only drag source")
	station.apply_visual_snapshot({"owned": true, "tier": 2, "layer_capacity": 4, "layers": [_held_layer(), _empty_layer(), _empty_layer(), _empty_layer()]})
	_check(station.layer_labels[0].text == "保温中" and not station.layer_labels[0].text.contains("999999"), "infinite hold remains readable")

	station.queue_free()
	await process_frame
	_finish()


func _check_assets() -> void:
	for path in ASSET_PATHS:
		_check(ResourceLoader.exists(path), "%s imports as a Godot resource" % path)
		var texture := load(path) as Texture2D
		_check(texture != null and Vector2i(texture.get_width(), texture.get_height()) == Vector2i(1024, 1536), "%s keeps the 1024x1536 v6 contract" % path)
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		_check(not image.is_empty(), "%s decodes" % path)
		if image.is_empty():
			continue
		for corner in [Vector2i.ZERO, Vector2i(1023, 0), Vector2i(0, 1535), Vector2i(1023, 1535)]:
			_check(image.get_pixelv(corner).a <= 0.02, "%s keeps transparent corners" % path)


static func _snapshot(tier: int, capacity: int) -> Dictionary:
	var layers: Array[Dictionary] = []
	for index in range(4):
		layers.append(_empty_layer() if index < capacity else {"state": &"locked", "recipe_id": &"", "quantity": 0})
	return {"owned": true, "tier": tier, "layer_capacity": capacity, "layers": layers}


static func _layer(state: StringName, seconds_to_ready: float, seconds_to_loss: float) -> Dictionary:
	return {
		"state": state,
		"recipe_id": &"recipe.steamer.mantou",
		"quantity": 1,
		"seconds_to_ready": seconds_to_ready,
		"seconds_to_loss": seconds_to_loss,
		"infinite_hold": false,
	}


static func _held_layer() -> Dictionary:
	var layer := _layer(&"ready_safe", 0.0, 0.0)
	layer["infinite_hold"] = true
	return layer


static func _empty_layer() -> Dictionary:
	return {"state": &"empty", "recipe_id": &"", "quantity": 0}


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("DIRECT_STEAMER_STATION_CONTRACT_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("DIRECT_STEAMER_STATION_CONTRACT_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
