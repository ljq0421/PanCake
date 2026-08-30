extends SceneTree


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2:
		printerr("Usage: godot -s res://tools/chroma_key_green.gd -- <source.png> <target.png>")
		quit(2)
		return
	var source_path := str(arguments[0])
	var target_path := str(arguments[1])
	var image := Image.load_from_file(source_path)
	if image.is_empty():
		printerr("Could not load green-screen source: %s" % source_path)
		quit(3)
		return
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			var competing_channel := maxf(color.r, color.b)
			var green_dominance := color.g - competing_channel
			# Generated green-screen sources are not numerically flat: shadows and
			# antialiasing darken the matte. Combining dominance with luminance keys
			# the backdrop while retaining dark green ingredients such as peppers.
			var dominance_weight := clampf((green_dominance - 0.12) / 0.38, 0.0, 1.0)
			var luminance_weight := clampf((color.g - 0.45) / 0.35, 0.0, 1.0)
			var key_weight := dominance_weight * luminance_weight
			if key_weight <= 0.0:
				continue
			color.g = lerpf(color.g, competing_channel, key_weight)
			color.a *= 1.0 - key_weight
			if color.a <= 0.02:
				color = Color(0.0, 0.0, 0.0, 0.0)
			image.set_pixel(x, y, color)
	var absolute_target := ProjectSettings.globalize_path(target_path)
	DirAccess.make_dir_recursive_absolute(absolute_target.get_base_dir())
	var save_error := image.save_png(absolute_target)
	if save_error != OK:
		printerr("Could not save keyed PNG: %s" % error_string(save_error))
		quit(4)
		return
	print("CHROMA_KEY_GREEN_PASS: %s" % absolute_target)
	quit(0)
