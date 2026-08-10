extends SceneTree

const PATHS := [
	"res://resources/art/products/packaged_drink/milk_package_five_area_v2.png",
	"res://resources/art/products/packaged_drink/milk_heated_five_area_v2.png",
	"res://resources/art/products/packaged_drink/soy_milk_package_five_area_v2.png",
	"res://resources/art/products/packaged_drink/soy_milk_heated_five_area_v2.png",
	"res://resources/art/products/packaged_drink/walnut_package_five_area_v2.png",
	"res://resources/art/products/packaged_drink/walnut_heated_five_area_v2.png",
	"res://resources/art/products/packaged_drink/black_sesame_package_five_area_v2.png",
	"res://resources/art/products/packaged_drink/black_sesame_heated_five_area_v2.png",
]
const DISPLAY_RACK_PATH := "res://resources/art/workstation/expansion/machines/packaged_drink_display_rack_tier_1_five_area_v4.png"


func _initialize() -> void:
	for path in PATHS:
		var texture := ResourceLoader.load(path, "Texture2D") as Texture2D
		assert(texture != null, "Expected Texture2D: %s" % path)
		assert(texture.get_size() == Vector2(256, 256), "Unexpected dimensions: %s" % path)
	var display_rack := ResourceLoader.load(DISPLAY_RACK_PATH, "Texture2D") as Texture2D
	assert(display_rack != null, "Expected display-rack Texture2D: %s" % DISPLAY_RACK_PATH)
	assert(display_rack.get_size() == Vector2(1024, 656), "Unexpected display-rack dimensions: %s" % DISPLAY_RACK_PATH)
	print("PACKAGED_DRINK_ART_LOAD_CHECK_PASS")
	quit()
