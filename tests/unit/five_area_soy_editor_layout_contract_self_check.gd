extends SceneTree

const SOY_SCENE := preload("res://scenes/gameplay/direct_soy_station.tscn")

var failures := PackedStringArray()


func _initialize() -> void:
	var workstation_scene_source := FileAccess.get_file_as_string("res://scenes/gameplay/five_area_workstation.tscn")
	var workstation_script_source := FileAccess.get_file_as_string("res://scripts/gameplay/five_area_workstation.gd")
	var soy_scene_source := FileAccess.get_file_as_string("res://scenes/gameplay/direct_soy_station.tscn")
	var preview_script_source := FileAccess.get_file_as_string("res://scripts/ui/direct_soy_station_editor_preview.gd")
	_check(workstation_scene_source.contains("name=\"FreshSoyMilkStation\""), "formal scene authors the soy station instance")
	_check(not workstation_script_source.contains("RIGHT_SOY_STATION_POSITION"), "runtime code has no duplicate soy position authority")
	_check(not workstation_script_source.contains("fresh_soy_station.position ="), "runtime does not overwrite the authored soy position")
	_check(not workstation_script_source.contains("fresh_soy_station.size ="), "runtime does not overwrite the authored soy size")
	_check(soy_scene_source.contains("direct_soy_station_editor_preview.gd"), "soy scene owns an editor preview helper")
	_check(not soy_scene_source.contains("type=\"Texture2D\""), "soy scene keeps runtime artwork lazy-loaded")
	var soy_runtime_script_source := FileAccess.get_file_as_string("res://scripts/ui/direct_soy_station.gd")
	_check(soy_runtime_script_source.contains("@export_enum(\"Basic\", \"Intermediate\", \"Advanced\") var editor_preview_tier"), "soy root exposes all three editor preview tiers")
	_check(soy_runtime_script_source.contains("@export var advanced_machine_rect"), "advanced machine artwork rectangle is editable")
	_check(soy_runtime_script_source.contains("@export var advanced_right_nozzle_texture_position"), "advanced right outlet geometry is editable")
	_check(soy_runtime_script_source.contains("@export var advanced_right_cup_offset"), "advanced right cup position is editable")
	_check(preview_script_source.begins_with("@tool"), "soy preview helper runs in the editor")
	_check(preview_script_source.contains("if not Engine.is_editor_hint():"), "soy preview helper exits outside the editor")
	var soy_station := SOY_SCENE.instantiate() as DirectSoyStation
	_check(soy_station.basic_left_nozzle_texture_position == Vector2(575.0, 1000.0), "basic cup anchor stays centered under the artwork's dispensing spout")
	_check(soy_station.advanced_left_nozzle_texture_position == Vector2(452.0, 980.0), "advanced left cup anchor stays centered under the artwork's left dispensing spout")
	_check(soy_station.advanced_right_nozzle_texture_position == Vector2(689.0, 980.0), "advanced right cup anchor stays centered under the artwork's right dispensing spout")
	soy_station._displayed_machine_tier = 2
	soy_station.advanced_left_nozzle_texture_position = Vector2(512.0, 990.0)
	soy_station.advanced_right_nozzle_texture_position = Vector2(752.0, 990.0)
	soy_station.advanced_machine_rect = Rect2(12.0, 8.0, 360.0, 370.0)
	soy_station.advanced_left_cup_offset = Vector2(-4.0, 12.0)
	soy_station.advanced_right_cup_offset = Vector2(6.0, 14.0)
	var advanced_layout := soy_station._machine_tier_layout()
	_check(Vector2(advanced_layout.get("left_nozzle_texture_position", Vector2.ZERO)) == Vector2(512.0, 990.0), "advanced left outlet editor value drives runtime geometry")
	_check(Vector2(advanced_layout.get("right_nozzle_texture_position", Vector2.ZERO)) == Vector2(752.0, 990.0), "advanced right outlet editor value drives runtime geometry")
	_check(soy_station._machine_rect_for_tier(2) == Rect2(12.0, 8.0, 360.0, 370.0), "advanced artwork rectangle editor value drives runtime geometry")
	_check(soy_station._left_cup_offset_for_tier(2) == Vector2(-4.0, 12.0), "advanced left cup offset editor value drives runtime geometry")
	_check(soy_station._right_cup_offset_for_tier(2) == Vector2(6.0, 14.0), "advanced right cup offset editor value drives runtime geometry")
	soy_station.free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("FIVE_AREA_SOY_EDITOR_LAYOUT_CONTRACT_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("FIVE_AREA_SOY_EDITOR_LAYOUT_CONTRACT_SELF_CHECK_FAIL\n" + "\n".join(failures))
	quit(1)
