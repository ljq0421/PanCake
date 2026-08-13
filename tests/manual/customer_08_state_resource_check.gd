extends SceneTree

const STATES := {
	&"neutral": [
		"res://resources/art/customers/customer_08/customer_08_neutral_cropped.tres",
		"customer_08_neutral_v4_chinese.png",
		Rect2(556, 84, 403, 884),
	],
	&"impatient": [
		"res://resources/art/customers/customer_08/customer_08_impatient_cropped.tres",
		"customer_08_impatient_v4_colorlocked.png",
		Rect2(556, 85, 402, 883),
	],
	&"satisfied": [
		"res://resources/art/customers/customer_08/customer_08_satisfied_cropped.tres",
		"customer_08_satisfied_v4_colorlocked.png",
		Rect2(556, 86, 402, 884),
	],
	&"accepting_bag": [
		"res://resources/art/customers/customer_08/customer_08_accepting_bag_cropped.tres",
		"customer_08_accepting_bag_v4_colorlocked.png",
		Rect2(578, 89, 375, 774),
	],
	&"paying_coins": [
		"res://resources/art/customers/customer_08/customer_08_paying_coins_cropped.tres",
		"customer_08_paying_coins_v4_colorlocked.png",
		Rect2(423, 59, 657, 928),
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
		_check(texture.region == expected[2], "%s preserves legacy Atlas region" % state)
		var atlas := texture.atlas as Texture2D
		_check(atlas != null and atlas.resource_path.ends_with(expected[1]), "%s resolves expected v4 PNG" % state)
		if atlas != null:
			_check(atlas.get_size() == Vector2(1536, 1024), "%s PNG preserves the 1536x1024 canvas" % state)
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
