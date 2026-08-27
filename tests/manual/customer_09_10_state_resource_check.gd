extends SceneTree

const CASES := [
	["customer_09", "neutral", Rect2(287, 108, 548, 1222), Vector2(1122, 1402)],
	["customer_09", "impatient", Rect2(287, 110, 547, 1221), Vector2(1121, 1403)],
	["customer_09", "satisfied", Rect2(286, 99, 549, 1232), Vector2(1122, 1402)],
	["customer_09", "accepting_bag", Rect2(296, 99, 531, 1245), Vector2(1122, 1402)],
	["customer_09", "paying_coins", Rect2(208, 107, 712, 1226), Vector2(1122, 1402)],
	["customer_10", "neutral", Rect2(399, 40, 612, 1074), Vector2(1412, 1114)],
	["customer_10", "impatient", Rect2(402, 41, 613, 1075), Vector2(1409, 1116)],
	["customer_10", "satisfied", Rect2(399, 35, 611, 1079), Vector2(1411, 1114)],
	["customer_10", "accepting_bag", Rect2(381, 38, 651, 1076), Vector2(1412, 1114)],
	["customer_10", "paying_coins", Rect2(324, 38, 743, 1076), Vector2(1412, 1114)],
]

var _failures: Array[String] = []


func _initialize() -> void:
	for case: Array in CASES:
		var customer_id: String = case[0]
		var state: String = case[1]
		var expected_region: Rect2 = case[2]
		var expected_canvas: Vector2 = case[3]
		var texture_path := "res://resources/art/customers/%s/%s_%s_cropped.tres" % [customer_id, customer_id, state]
		var expected_png := "%s_%s_v2_qstyle.png" % [customer_id, state]
		var texture := load(texture_path) as AtlasTexture
		_check(texture != null, "%s %s AtlasTexture loads" % [customer_id, state])
		if texture == null:
			continue
		_check(texture.region == expected_region, "%s %s uses the approved qstyle Atlas region" % [customer_id, state])
		var atlas := texture.atlas as Texture2D
		_check(atlas != null and atlas.resource_path.ends_with(expected_png), "%s %s resolves expected qstyle PNG" % [customer_id, state])
		if atlas != null:
			_check(atlas.get_size() == expected_canvas, "%s %s preserves its approved canvas" % [customer_id, state])
	if _failures.is_empty():
		print("CUSTOMER_09_10_STATE_RESOURCE_CHECK_PASS")
		quit(0)
		return
	printerr("CUSTOMER_09_10_STATE_RESOURCE_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
