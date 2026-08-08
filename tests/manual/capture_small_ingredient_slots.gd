extends SceneTree

const WORKSTATION_SCENE := preload("res://scenes/gameplay/initial_unlock_workstation.tscn")
const OUTPUT_PATH := "res://tmp/validation/small_ingredient_slots_1920x1080.png"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var workstation := WORKSTATION_SCENE.instantiate()
	root.add_child(workstation)
	await process_frame
	await process_frame
	workstation.call("apply_progression_effects", {
		"owned_growth_ids": [
			&"growth.add_on.pancake.coriander",
			&"growth.add_on.pancake.preserved_mustard",
		],
		"device_tiers": {},
	})
	for slot_path in ["SafeArea/IngredientRack/CorianderButton", "SafeArea/IngredientRack/PreservedMustardButton"]:
		var slot := workstation.get_node(slot_path) as Button
		slot.visible = true
		slot.disabled = false
		slot.call("set_stock_quantity", 6)
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if error != OK:
		push_error("Failed to capture small ingredient slots: %s" % error)
		quit(1)
	print("SMALL_INGREDIENT_SLOTS_CAPTURED %s" % OUTPUT_PATH)
	quit()
