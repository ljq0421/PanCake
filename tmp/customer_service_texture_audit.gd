extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var loaded_png := 0
	var loaded_cropped := 0
	for index in range(1, 11):
		var customer_id := "customer_%02d" % index
		for state in ["accepting_bag", "paying_coins"]:
			var png_path := "res://resources/art/customers/%s/%s_%s_v1.png" % [customer_id, customer_id, state]
			var texture := load(png_path) as Texture2D
			if texture == null:
				failures.append("PNG load failed: %s" % png_path)
				continue
			var image := texture.get_image()
			if image == null or image.is_empty():
				failures.append("PNG image data missing: %s" % png_path)
				continue
			if image.detect_alpha() == Image.ALPHA_NONE:
				failures.append("PNG alpha missing: %s" % png_path)
				continue
			loaded_png += 1
			var cropped_path := "res://resources/art/customers/%s/%s_%s_cropped.tres" % [customer_id, customer_id, state]
			var cropped := load(cropped_path) as AtlasTexture
			if cropped == null:
				failures.append("AtlasTexture load failed: %s" % cropped_path)
				continue
			if cropped.atlas == null or cropped.region.size.x <= 0.0 or cropped.region.size.y <= 0.0:
				failures.append("AtlasTexture invalid: %s" % cropped_path)
				continue
			loaded_cropped += 1
			print("CUSTOMER_SERVICE_TEXTURE_OK %s %dx%d crop=%s alpha=%s" % [png_path, texture.get_width(), texture.get_height(), cropped.region, image.detect_alpha()])
	print("CUSTOMER_SERVICE_TEXTURE_AUDIT png=%d cropped=%d failures=%d" % [loaded_png, loaded_cropped, failures.size()])
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)
