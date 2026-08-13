extends SceneTree

const WORKSTATION_SCRIPT := preload("res://scripts/gameplay/workstation.gd")
const CUSTOMER_ID := &"customer_15"
const STATES := [&"neutral", &"impatient", &"satisfied", &"accepting_bag", &"paying_coins"]
const EXPECTED_STATES := {
	&"neutral": {
		"png": "res://resources/art/customers/customer_15/customer_15_neutral_v1.png",
		"region": Rect2(498, 35, 531, 989),
	},
	&"impatient": {
		"png": "res://resources/art/customers/customer_15/customer_15_impatient_v6.png",
		"region": Rect2(443, 38, 586, 986),
	},
	&"satisfied": {
		"png": "res://resources/art/customers/customer_15/customer_15_satisfied_v7.png",
		"region": Rect2(516, 37, 492, 987),
	},
	&"accepting_bag": {
		"png": "res://resources/art/customers/customer_15/customer_15_accepting_bag_v6.png",
		"region": Rect2(513, 38, 495, 986),
	},
	&"paying_coins": {
		"png": "res://resources/art/customers/customer_15/customer_15_paying_coins_v6.png",
		"region": Rect2(518, 29, 506, 995),
	},
}

var _failures: Array[String] = []


func _initialize() -> void:
	var customer_textures: Dictionary = WORKSTATION_SCRIPT.CUSTOMER_TEXTURES
	_check(customer_textures.has(CUSTOMER_ID), "workstation exposes customer_15")
	var state_textures := Dictionary(customer_textures.get(CUSTOMER_ID, {}))
	_check(state_textures.keys().size() == STATES.size(), "customer_15 exposes exactly five portrait state keys")
	for state in STATES:
		_check(state_textures.has(state), "customer_15 exposes %s" % state)
		var texture := state_textures.get(state) as AtlasTexture
		if texture == null:
			continue
		var expected: Dictionary = EXPECTED_STATES[state]
		_check(texture.region == expected["region"], "%s preserves its verified crop" % state)
		_check(texture.atlas != null and texture.atlas.resource_path == expected["png"], "%s resolves its final RGBA PNG" % state)
		var image := Image.load_from_file(expected["png"])
		_check(not image.is_empty() and image.get_size() == Vector2i(1536, 1024), "%s PNG imports at the expected canvas size" % state)
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
		print("CUSTOMER_15_PORTRAIT_CONTRACT_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("CUSTOMER_15_PORTRAIT_CONTRACT_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
