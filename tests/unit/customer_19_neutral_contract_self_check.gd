extends SceneTree

const PORTRAIT_CATALOG_SCRIPT := preload("res://scripts/ui/customer_portrait_catalog.gd")
const CUSTOMER_QUEUE_SCRIPT := preload("res://scripts/services/customer_queue_service.gd")
const FORMAL_ORDER_SCRIPT := preload("res://scripts/services/five_area_order_service.gd")
const CUSTOMER_ID := &"customer_19"
const EXPECTED_REGION := Rect2(533, 89, 459, 851)
const EXPECTED_PNG_PATH := "res://resources/art/customers/customer_19/customer_19_neutral_v1_keyclean.png"
const EXPECTED_STATE_PNGS := {
	&"neutral": "customer_19_neutral_v1_keyclean.png",
	&"impatient": "customer_19_impatient_v1.png",
	&"satisfied": "customer_19_satisfied_v1.png",
	&"accepting_bag": "customer_19_accepting_bag_v1.png",
	&"paying_coins": "customer_19_paying_coins_v1.png",
}

var _failures: Array[String] = []


func _initialize() -> void:
	var catalog: RefCounted = PORTRAIT_CATALOG_SCRIPT.new()
	_check(PORTRAIT_CATALOG_SCRIPT.CUSTOMER_IDS.has(CUSTOMER_ID), "portrait catalog exposes customer_19")
	var texture := load(str(catalog.call("resource_path_for", CUSTOMER_ID, &"neutral"))) as AtlasTexture
	_check(texture != null and texture.region == EXPECTED_REGION, "neutral AtlasTexture preserves complete hair, hands, and bottom anchor")
	_check(texture != null and texture.atlas != null and texture.atlas.resource_path == EXPECTED_PNG_PATH, "neutral AtlasTexture resolves the selected PNG")
	var image := Image.load_from_file(EXPECTED_PNG_PATH)
	_check(not image.is_empty() and image.get_size() == Vector2i(1536, 1024), "neutral PNG has the expected canvas")
	_check(image.get_format() in [Image.FORMAT_RGBA8, Image.FORMAT_RGBAF, Image.FORMAT_RGBAH], "neutral PNG retains an alpha channel")
	if not image.is_empty():
		var transparent_corners := true
		for corner in [Vector2i(0, 0), Vector2i(image.get_width() - 1, 0), Vector2i(0, image.get_height() - 1), Vector2i(image.get_width() - 1, image.get_height() - 1)]:
			transparent_corners = transparent_corners and image.get_pixelv(corner).a == 0.0
		_check(transparent_corners, "neutral PNG keeps all four corners transparent")
	for state in EXPECTED_STATE_PNGS:
		var state_texture := load(str(catalog.call("resource_path_for", CUSTOMER_ID, state))) as AtlasTexture
		_check(state_texture != null and state_texture.atlas != null and state_texture.atlas.resource_path.ends_with(String(EXPECTED_STATE_PNGS[state])), "%s AtlasTexture resolves its selected PNG" % state)
	_check(CUSTOMER_QUEUE_SCRIPT.CUSTOMER_IDS.has(CUSTOMER_ID), "customer queue includes customer_19")
	_check(FORMAL_ORDER_SCRIPT.CUSTOMER_IDS.has(CUSTOMER_ID), "formal order pool includes customer_19")
	_check(FORMAL_ORDER_SCRIPT.customer_id_for_sequence(11) == &"customer_11" and FORMAL_ORDER_SCRIPT.customer_id_for_sequence(21) == &"customer_01", "current rotation includes twenty customers before wrapping")
	_check(FORMAL_ORDER_SCRIPT.legacy_customer_id_for_sequence(11) == &"customer_01", "pre-expansion snapshots keep the original ten-customer modulo")
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CUSTOMER_19_NEUTRAL_CONTRACT_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("CUSTOMER_19_NEUTRAL_CONTRACT_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
