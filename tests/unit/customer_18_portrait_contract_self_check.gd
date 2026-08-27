extends SceneTree

const WORKSTATION_SCRIPT := preload("res://scripts/gameplay/workstation.gd")
const ORDER_SERVICE_SCRIPT := preload("res://scripts/services/five_area_order_service.gd")
const QUEUE_SERVICE_SCRIPT := preload("res://scripts/services/customer_queue_service.gd")
const CUSTOMER_ID := &"customer_18"
const STATES := [&"neutral", &"impatient", &"satisfied", &"accepting_bag", &"paying_coins"]
const EXPECTED_FILES := {
	&"neutral": "customer_18_neutral_v1_keyclean.png",
	&"impatient": "customer_18_impatient_v1.png",
	&"satisfied": "customer_18_satisfied_v1.png",
	&"accepting_bag": "customer_18_accepting_bag_v1.png",
	&"paying_coins": "customer_18_paying_coins_v1.png",
}
const EXPECTED_REGIONS := {
	&"neutral": Rect2(473, 24, 583, 1000),
	&"impatient": Rect2(492, 25, 546, 999),
	&"satisfied": Rect2(493, 25, 542, 999),
	&"accepting_bag": Rect2(487, 28, 563, 996),
	&"paying_coins": Rect2(416, 26, 677, 998),
}
const NEUTRAL_PNG_PATH := "res://resources/art/customers/customer_18/customer_18_neutral_v1_keyclean.png"

var _failures: Array[String] = []


func _initialize() -> void:
	var customer_textures: Dictionary = WORKSTATION_SCRIPT.CUSTOMER_TEXTURES
	_check(customer_textures.has(CUSTOMER_ID), "workstation exposes customer_18")
	var state_textures := Dictionary(customer_textures.get(CUSTOMER_ID, {}))
	_check(state_textures.keys().size() == STATES.size(), "customer_18 exposes exactly five portrait state keys")
	for state in STATES:
		_check(state_textures.has(state), "customer_18 exposes %s" % state)
		var texture := state_textures.get(state) as AtlasTexture
		if texture == null:
			continue
		_check(texture.region == EXPECTED_REGIONS[state], "%s preserves its verified crop" % state)
		_check(texture.atlas != null and texture.atlas.resource_path.ends_with(String(EXPECTED_FILES[state])), "%s resolves its selected action PNG" % state)
	_check(not ORDER_SERVICE_SCRIPT.CUSTOMER_IDS.has(CUSTOMER_ID), "formal order customer pool excludes disabled customer_18")
	_check(not QUEUE_SERVICE_SCRIPT.CUSTOMER_IDS.has(CUSTOMER_ID), "legacy queue customer pool excludes disabled customer_18")
	_check(ORDER_SERVICE_SCRIPT.legacy_customer_id_for_sequence(11) == &"customer_01", "pre-expansion saves retain the original ten-customer modulo")
	var image := Image.load_from_file(NEUTRAL_PNG_PATH)
	_check(not image.is_empty() and image.get_size() == Vector2i(1536, 1024), "neutral PNG imports at the expected canvas size")
	_check(image.get_format() in [Image.FORMAT_RGBA8, Image.FORMAT_RGBAF, Image.FORMAT_RGBAH], "neutral PNG retains an alpha channel")
	if not image.is_empty():
		var transparent_corners := true
		for corner in [Vector2i(0, 0), Vector2i(image.get_width() - 1, 0), Vector2i(0, image.get_height() - 1), Vector2i(image.get_width() - 1, image.get_height() - 1)]:
			transparent_corners = transparent_corners and image.get_pixelv(corner).a == 0.0
		_check(transparent_corners, "neutral PNG keeps all four corners transparent")
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CUSTOMER_18_PORTRAIT_CONTRACT_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("CUSTOMER_18_PORTRAIT_CONTRACT_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
