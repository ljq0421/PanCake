extends SceneTree

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
	_check(preview_script_source.begins_with("@tool"), "soy preview helper runs in the editor")
	_check(preview_script_source.contains("if not Engine.is_editor_hint():"), "soy preview helper exits outside the editor")
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
