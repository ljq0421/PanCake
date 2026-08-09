extends SceneTree


const MANIFEST_PATH := "res://docs/five_area_art_v2_manifest.json"


func _init() -> void:
	var manifest_file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	assert(manifest_file != null, "Expected five-area v2 art manifest")
	var manifest_value: Variant = JSON.parse_string(manifest_file.get_as_text())
	assert(manifest_value is Dictionary, "Expected manifest JSON object")
	var manifest := manifest_value as Dictionary
	var entries_value: Variant = manifest.get("entries", [])
	assert(entries_value is Array, "Expected manifest entries array")

	var loaded_count := 0
	for entry_value in entries_value as Array:
		assert(entry_value is Dictionary, "Expected manifest entry object")
		var entry := entry_value as Dictionary
		var path := String(entry.get("target_path", ""))
		assert(not path.is_empty(), "Expected target_path")
		if not FileAccess.file_exists(path):
			continue
		var texture := ResourceLoader.load(path, "Texture2D") as Texture2D
		assert(texture != null, "Expected Texture2D: %s" % path)
		loaded_count += 1

	assert(loaded_count > 0, "Expected at least one present five-area v2 texture")
	print("FIVE_AREA_ART_V2_PRESENT_LOAD_CHECK_PASS loaded=%d" % loaded_count)
	quit()
