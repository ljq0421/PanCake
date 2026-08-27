extends SceneTree

const PORTRAIT_CATALOG_SCRIPT := preload("res://scripts/ui/customer_portrait_catalog.gd")
const CUSTOMER_ID := &"customer_17"
const STATES := [&"neutral", &"impatient", &"satisfied", &"accepting_bag", &"paying_coins"]
const EXPECTED_FILES := {
	&"neutral": "customer_17_neutral_v1_keyclean.png",
	&"impatient": "customer_17_impatient_v1_keyclean.png",
	&"satisfied": "customer_17_satisfied_v1_keyclean.png",
	&"accepting_bag": "customer_17_accepting_bag_v1_keyclean.png",
	&"paying_coins": "customer_17_paying_coins_v1_keyclean.png",
}
const EXPECTED_REGIONS := {
	&"neutral": Rect2(535, 122, 459, 834),
	&"impatient": Rect2(533, 114, 448, 853),
	&"satisfied": Rect2(544, 113, 446, 814),
	&"accepting_bag": Rect2(529, 111, 463, 847),
	&"paying_coins": Rect2(489, 77, 546, 872),
}

var _failures: Array[String] = []


func _initialize() -> void:
	var catalog: RefCounted = PORTRAIT_CATALOG_SCRIPT.new()
	_check(PORTRAIT_CATALOG_SCRIPT.CUSTOMER_IDS.has(CUSTOMER_ID), "portrait catalog exposes customer_17")
	for state in STATES:
		var path := str(catalog.call("resource_path_for", CUSTOMER_ID, state))
		_check(ResourceLoader.exists(path, "Texture2D"), "customer_17 exposes %s" % state)
		var texture := load(path) as AtlasTexture
		_check(texture != null and texture.region == EXPECTED_REGIONS[state], "%s preserves complete hair, hands, and bottom anchor" % state)
		_check(texture != null and texture.atlas != null and texture.atlas.resource_path.ends_with(String(EXPECTED_FILES[state])), "%s AtlasTexture resolves its selected PNG" % state)
		var png_path := "res://resources/art/customers/customer_17/customer_17_%s_v1_keyclean.png" % state
		var image := Image.load_from_file(png_path)
		_check(not image.is_empty() and image.get_size() == Vector2i(1536, 1024), "%s PNG has the expected canvas" % state)
		_check(image.get_format() in [Image.FORMAT_RGBA8, Image.FORMAT_RGBAF, Image.FORMAT_RGBAH], "%s PNG retains an alpha channel" % state)
		if image.is_empty():
			continue
		var transparent_corners := true
		for corner in [Vector2i(0, 0), Vector2i(image.get_width() - 1, 0), Vector2i(0, image.get_height() - 1), Vector2i(image.get_width() - 1, image.get_height() - 1)]:
			transparent_corners = transparent_corners and image.get_pixelv(corner).a == 0.0
		_check(transparent_corners, "%s PNG keeps all four corners transparent" % state)
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CUSTOMER_17_STATES_CONTRACT_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("CUSTOMER_17_NEUTRAL_CONTRACT_SELF_CHECK_FAIL\\n" + "\\n".join(_failures))
	quit(1)
