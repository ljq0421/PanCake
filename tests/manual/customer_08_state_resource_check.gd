extends SceneTree

const STATES := {
	&"neutral": [
		"res://resources/art/customers/customer_08/customer_08_neutral_cropped.tres",
		"customer_08_neutral_v2_qstyle.png",
		Rect2(465, 77, 466, 966),
		Vector2(1413, 1113),
	],
	&"impatient": [
		"res://resources/art/customers/customer_08/customer_08_impatient_cropped.tres",
		"customer_08_impatient_v2_qstyle.png",
		Rect2(470, 74, 475, 983),
		Vector2(1411, 1114),
	],
	&"satisfied": [
		"res://resources/art/customers/customer_08/customer_08_satisfied_cropped.tres",
		"customer_08_satisfied_v2_qstyle.png",
		Rect2(460, 73, 466, 975),
		Vector2(1411, 1114),
	],
	&"accepting_bag": [
		"res://resources/art/customers/customer_08/customer_08_accepting_bag_cropped.tres",
		"customer_08_accepting_bag_v2_qstyle.png",
		Rect2(457, 70, 490, 992),
		Vector2(1411, 1114),
	],
	&"paying_coins": [
		"res://resources/art/customers/customer_08/customer_08_paying_coins_cropped.tres",
		"customer_08_paying_coins_v2_qstyle.png",
		Rect2(351, 78, 656, 999),
		Vector2(1412, 1114),
	],
}

var _failures: Array[String] = []


func _initialize() -> void:
	for state in STATES:
		var expected: Array = STATES[state]
		var texture := load(expected[0]) as AtlasTexture
		_check(texture != null, "%s AtlasTexture loads" % state)
		if texture == null:
			continue
		_check(texture.region == expected[2], "%s uses the approved qstyle Atlas region" % state)
		var atlas := texture.atlas as Texture2D
		_check(atlas != null and atlas.resource_path.ends_with(expected[1]), "%s resolves expected qstyle PNG" % state)
		if atlas != null:
			_check(atlas.get_size() == expected[3], "%s PNG preserves its approved canvas" % state)
	if _failures.is_empty():
		print("CUSTOMER_08_STATE_RESOURCE_CHECK_PASS")
		quit(0)
		return
	printerr("CUSTOMER_08_STATE_RESOURCE_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
