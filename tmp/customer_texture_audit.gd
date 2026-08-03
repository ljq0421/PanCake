extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var loaded_count := 0
	for index in range(1, 11):
		var customer_id := "customer_%02d" % index
		for state in ["neutral", "impatient", "satisfied"]:
			var path := "res://resources/art/customers/%s/%s_%s_v1.png" % [customer_id, customer_id, state]
			var texture := load(path) as Texture2D
			if texture == null:
				failures.append("load failed: %s" % path)
				continue
			var image := texture.get_image()
			if image == null or image.is_empty():
				failures.append("image data missing: %s" % path)
				continue
			if image.get_width() != texture.get_width() or image.get_height() != texture.get_height():
				failures.append("texture/image size mismatch: %s" % path)
				continue
			if image.detect_alpha() == Image.ALPHA_NONE:
				failures.append("alpha missing: %s" % path)
				continue
			loaded_count += 1
			print("CUSTOMER_TEXTURE_OK %s %dx%d format=%s alpha=%s" % [path, texture.get_width(), texture.get_height(), image.get_format(), image.detect_alpha()])
	print("CUSTOMER_TEXTURE_AUDIT loaded=%d failures=%d" % [loaded_count, failures.size()])
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)
