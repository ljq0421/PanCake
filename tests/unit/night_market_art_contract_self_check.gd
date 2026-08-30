extends SceneTree

const TRANSPARENT_ASSETS := [
	"res://resources/art/night_market/layers/charcoal_grill-rgba-v1.png",
	"res://resources/art/night_market/layers/plating_station-rgba-v1.png",
	"res://resources/art/night_market/layers/twin_fryer-rgba-v1.png",
	"res://resources/art/night_market/layers/twin_fryer_base-rgba-v1.png",
	"res://resources/art/night_market/sprites/skewer_doneness_atlas-rgba-v2.png",
	"res://resources/art/night_market/sprites/fryer_basket_states-rgba-v1.png",
	"res://resources/art/night_market/sprites/cooking_effects_atlas-rgba-v1.png",
]
const GREEN_SOURCES := [
	"res://resources/art/night_market/source_green/charcoal_grill-green-v1.png",
	"res://resources/art/night_market/source_green/plating_station-green-v1.png",
	"res://resources/art/night_market/source_green/twin_fryer-green-v1.png",
	"res://resources/art/night_market/source_green/skewer_doneness_atlas-green-v1.png",
	"res://resources/art/night_market/source_green/twin_fryer_base-green-v1.png",
	"res://resources/art/night_market/source_green/fryer_basket_states-green-v1.png",
	"res://resources/art/night_market/source_green/cooking_effects_atlas-green-v1.png",
]

var _failures: Array[String] = []


func _initialize() -> void:
	for path in TRANSPARENT_ASSETS:
		_check_transparent_asset(path)
	for path in GREEN_SOURCES:
		_check_green_source(path)
	var background := Image.load_from_file("res://resources/art/night_market/background/night_market_empty_stall-v1.png")
	var background_ratio := float(background.get_width()) / maxf(float(background.get_height()), 1.0)
	_check(not background.is_empty() and absf(background_ratio - 16.0 / 9.0) <= 0.01, "empty stall background preserves the approved 16:9 composition")
	_finish()


func _check_transparent_asset(path: String) -> void:
	var image := Image.load_from_file(path)
	if image.is_empty():
		_failures.append("%s loads as an image" % path)
		return
	var transparent_samples := 0
	var opaque_samples := 0
	var total_samples := 0
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			var alpha := image.get_pixel(x, y).a
			transparent_samples += 1 if alpha <= 0.02 else 0
			opaque_samples += 1 if alpha >= 0.90 else 0
			total_samples += 1
	var transparent_ratio := float(transparent_samples) / maxf(float(total_samples), 1.0)
	var opaque_ratio := float(opaque_samples) / maxf(float(total_samples), 1.0)
	_check(image.get_pixel(0, 0).a <= 0.02, "%s has a genuinely transparent outer corner" % path.get_file())
	_check(transparent_ratio >= 0.20 and opaque_ratio >= 0.08, "%s contains both useful alpha clearance and visible artwork" % path.get_file())


func _check_green_source(path: String) -> void:
	var image := Image.load_from_file(path)
	if image.is_empty():
		_failures.append("%s loads as a green source" % path)
		return
	var corner := image.get_pixel(0, 0)
	_check(corner.a >= 0.99 and corner.g >= 0.85 and corner.g - maxf(corner.r, corner.b) >= 0.70, "%s preserves the required opaque green-screen source" % path.get_file())


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("NIGHT_MARKET_ART_CONTRACT_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("NIGHT_MARKET_ART_CONTRACT_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
