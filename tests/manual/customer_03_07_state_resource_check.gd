extends SceneTree

const CANVAS_HEIGHTS := {
	"customer_03": 1280,
	"customer_04": 1300,
	"customer_05": 1250,
	"customer_06": 1250,
	"customer_07": 1230,
}
const STATES := ["neutral", "impatient", "satisfied", "accepting_bag", "paying_coins"]
const EXPECTED_REGIONS := {
	"customer_03": {
		"neutral": Rect2(296, 194, 432, 938),
		"impatient": Rect2(298, 194, 428, 938),
		"satisfied": Rect2(296, 195, 432, 937),
		"accepting_bag": Rect2(294, 167, 428, 971),
		"paying_coins": Rect2(218, 195, 574, 937),
	},
	"customer_04": {
		"neutral": Rect2(230, 139, 564, 1161),
		"impatient": Rect2(231, 140, 563, 1160),
		"satisfied": Rect2(232, 140, 560, 1160),
		"accepting_bag": Rect2(208, 141, 599, 1159),
		"paying_coins": Rect2(131, 140, 741, 1160),
	},
	"customer_05": {
		"neutral": Rect2(281, 173, 461, 1011),
		"impatient": Rect2(280, 170, 462, 1013),
		"satisfied": Rect2(281, 173, 461, 1012),
		"accepting_bag": Rect2(295, 173, 432, 1011),
		"paying_coins": Rect2(220, 174, 574, 1010),
	},
	"customer_06": {
		"neutral": Rect2(273, 163, 472, 968),
		"impatient": Rect2(271, 136, 478, 984),
		"satisfied": Rect2(273, 163, 472, 961),
		"accepting_bag": Rect2(265, 163, 488, 977),
		"paying_coins": Rect2(178, 153, 640, 990),
	},
	"customer_07": {
		"neutral": Rect2(176, 165, 656, 1065),
		"impatient": Rect2(177, 167, 654, 1063),
		"satisfied": Rect2(177, 166, 654, 1064),
		"accepting_bag": Rect2(170, 162, 670, 1068),
		"paying_coins": Rect2(128, 132, 778, 1098),
	},
}

var _failures: Array[String] = []


func _initialize() -> void:
	for customer_id: String in CANVAS_HEIGHTS:
		var expected_canvas := Vector2i(1024, CANVAS_HEIGHTS[customer_id])
		for state: String in STATES:
			var expected_region: Rect2 = EXPECTED_REGIONS[customer_id][state]
			var stem := "%s_%s_v2_qstyle" % [customer_id, state]
			var texture_path := "res://resources/art/customers/%s/%s_%s_cropped.tres" % [customer_id, customer_id, state]
			var png_path := "res://resources/art/customers/%s/%s.png" % [customer_id, stem]
			var green_path := "res://resources/art/customers/%s/%s_green.png" % [customer_id, stem]
			var texture := load(texture_path) as AtlasTexture
			_check(texture != null, "%s %s AtlasTexture loads" % [customer_id, state])
			if texture == null:
				continue
			_check(texture.region == expected_region, "%s %s uses the approved half-body crop" % [customer_id, state])
			_check(texture.region != Rect2(Vector2.ZERO, expected_canvas), "%s %s does not expose the full source canvas" % [customer_id, state])
			var atlas := texture.atlas as Texture2D
			_check(atlas != null and atlas.resource_path == png_path, "%s %s resolves expected qstyle PNG" % [customer_id, state])
			if atlas != null:
				_check(atlas.get_size() == Vector2(expected_canvas), "%s %s preserves the approved canvas" % [customer_id, state])
			var image := Image.load_from_file(png_path)
			_check(image != null and not image.is_empty(), "%s %s transparent PNG loads" % [customer_id, state])
			if image != null and not image.is_empty():
				_check(image.get_size() == expected_canvas, "%s %s transparent PNG has approved dimensions" % [customer_id, state])
				_check(image.get_format() in [Image.FORMAT_RGBA8, Image.FORMAT_RGBAF, Image.FORMAT_RGBAH], "%s %s retains an alpha channel" % [customer_id, state])
				_check(_corners_are_transparent(image), "%s %s has transparent canvas corners" % [customer_id, state])
			var green_image := Image.load_from_file(green_path)
			_check(green_image != null and not green_image.is_empty(), "%s %s green intermediate loads" % [customer_id, state])
			if green_image != null and not green_image.is_empty():
				_check(green_image.get_size() == expected_canvas, "%s %s green intermediate has approved dimensions" % [customer_id, state])
				_check(_corners_are_green(green_image), "%s %s preserves the green-screen source" % [customer_id, state])
	if _failures.is_empty():
		print("CUSTOMER_03_07_STATE_RESOURCE_CHECK_PASS")
		quit(0)
		return
	printerr("CUSTOMER_03_07_STATE_RESOURCE_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)


func _corners_are_transparent(image: Image) -> bool:
	var maximum := image.get_size() - Vector2i.ONE
	return (
		image.get_pixel(0, 0).a <= 0.01
		and image.get_pixel(maximum.x, 0).a <= 0.01
		and image.get_pixel(0, maximum.y).a <= 0.01
		and image.get_pixel(maximum.x, maximum.y).a <= 0.01
	)


func _corners_are_green(image: Image) -> bool:
	var maximum := image.get_size() - Vector2i.ONE
	for point: Vector2i in [Vector2i.ZERO, Vector2i(maximum.x, 0), Vector2i(0, maximum.y), maximum]:
		var pixel := image.get_pixelv(point)
		if pixel.g < 0.75 or pixel.g <= pixel.r + 0.35 or pixel.g <= pixel.b + 0.35:
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
