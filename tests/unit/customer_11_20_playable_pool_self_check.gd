extends SceneTree

const PORTRAITS := preload("res://scripts/ui/customer_portrait_catalog.gd")
const LEGACY_QUEUE := preload("res://scripts/services/customer_queue_service.gd")
const FORMAL_ORDERS := preload("res://scripts/services/five_area_order_service.gd")
const PORTRAIT_FRAME_SIZE := Vector2(228.0, 372.4)
const MIN_RENDERED_CHARACTER_HEIGHT := 310.0
const MAX_RENDERED_BOTTOM_GAP := 30.0

const EXPECTED_CUSTOMER_IDS: Array[StringName] = [
	&"customer_01", &"customer_02", &"customer_03", &"customer_04", &"customer_05",
	&"customer_06", &"customer_07", &"customer_08", &"customer_09", &"customer_10",
	&"customer_11", &"customer_12", &"customer_13", &"customer_14", &"customer_15",
	&"customer_16", &"customer_17", &"customer_18", &"customer_19", &"customer_20",
]

var _failures: Array[String] = []


func _initialize() -> void:
	var catalog: RefCounted = PORTRAITS.new()
	_check(PORTRAITS.CUSTOMER_IDS == EXPECTED_CUSTOMER_IDS, "portrait catalog exposes the complete 01-20 pool")
	_check(LEGACY_QUEUE.CUSTOMER_IDS == EXPECTED_CUSTOMER_IDS, "legacy customer queue exposes the complete 01-20 pool")
	_check(FORMAL_ORDERS.CUSTOMER_IDS == EXPECTED_CUSTOMER_IDS, "formal order service exposes the complete 01-20 pool")

	for number in range(11, 21):
		var customer_id := StringName("customer_%02d" % number)
		for state in PORTRAITS.STATES:
			var path := str(catalog.call("resource_path_for", customer_id, state))
			_check(ResourceLoader.exists(path, "Texture2D"), "%s %s runtime portrait exists" % [customer_id, state])
			var texture := load(path) as AtlasTexture
			_check(texture != null and texture.atlas != null, "%s %s runtime portrait loads" % [customer_id, state])
			if texture != null and texture.atlas != null:
				var cropped_image := texture.get_image()
				_check(_has_two_pixel_alpha_padding(cropped_image), "%s %s keeps a two-pixel transparent safety margin without clipping" % [customer_id, state])
				var rendered_height := _rendered_character_height(texture.region.size)
				var bottom_gap := _rendered_bottom_gap(texture.region.size)
				_check(rendered_height >= MIN_RENDERED_CHARACTER_HEIGHT, "%s %s fills the shared portrait frame" % [customer_id, state])
				_check(bottom_gap <= MAX_RENDERED_BOTTOM_GAP, "%s %s stays anchored near the portrait baseline" % [customer_id, state])
		_check(FORMAL_ORDERS.customer_id_for_sequence(number) == customer_id, "%s participates in deterministic formal-order rotation" % customer_id)
		var queue: RefCounted = LEGACY_QUEUE.new(null, 1)
		queue.call("restore_active_customer", {}, customer_id)
		_check(StringName(Dictionary(queue.call("current_customer")).get("id", &"")) == customer_id, "%s restores through the legacy queue" % customer_id)

	_check(FORMAL_ORDERS.customer_id_for_sequence(21) == &"customer_01", "expanded formal-order rotation wraps after customer_20")
	_check(FORMAL_ORDERS.legacy_customer_id_for_sequence(11) == &"customer_01", "pre-expansion save migration retains the original ten-customer modulo")
	_finish()


func _has_two_pixel_alpha_padding(image: Image) -> bool:
	if image == null or image.is_empty() or image.get_width() < 5 or image.get_height() < 5:
		return false
	var last_x := image.get_width() - 1
	var last_y := image.get_height() - 1
	return (
		not _row_has_alpha(image, 0)
		and not _row_has_alpha(image, 1)
		and _row_has_alpha(image, 2)
		and _row_has_alpha(image, last_y - 2)
		and not _row_has_alpha(image, last_y - 1)
		and not _row_has_alpha(image, last_y)
		and not _column_has_alpha(image, 0)
		and not _column_has_alpha(image, 1)
		and _column_has_alpha(image, 2)
		and _column_has_alpha(image, last_x - 2)
		and not _column_has_alpha(image, last_x - 1)
		and not _column_has_alpha(image, last_x)
	)


func _row_has_alpha(image: Image, y: int) -> bool:
	for x in image.get_width():
		if image.get_pixel(x, y).a > 0.0:
			return true
	return false


func _column_has_alpha(image: Image, x: int) -> bool:
	for y in image.get_height():
		if image.get_pixel(x, y).a > 0.0:
			return true
	return false


func _rendered_character_height(region_size: Vector2) -> float:
	var scale_factor := minf(PORTRAIT_FRAME_SIZE.x / region_size.x, PORTRAIT_FRAME_SIZE.y / region_size.y)
	return (region_size.y - 4.0) * scale_factor


func _rendered_bottom_gap(region_size: Vector2) -> float:
	var scale_factor := minf(PORTRAIT_FRAME_SIZE.x / region_size.x, PORTRAIT_FRAME_SIZE.y / region_size.y)
	return (PORTRAIT_FRAME_SIZE.y - region_size.y * scale_factor) * 0.5 + 2.0 * scale_factor


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CUSTOMER_11_20_PLAYABLE_POOL_SELF_CHECK_PASS")
		quit(0)
		return
	printerr("CUSTOMER_11_20_PLAYABLE_POOL_SELF_CHECK_FAIL\n" + "\n".join(_failures))
	quit(1)
