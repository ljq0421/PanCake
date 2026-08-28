class_name UiScaleApplier
extends RefCounted

const BASE_FONT_METADATA := &"p1_base_font_size"
const BASE_MINIMUM_METADATA := &"p1_base_minimum_size"


static func apply_to(root: Node, scale_percent: float, minimum_font_size: int = 24, scale_button_minimum: bool = true) -> void:
	if root == null:
		return
	var factor := clampf(scale_percent, 100.0, 150.0) / 100.0
	_apply_node(root, factor, minimum_font_size, scale_button_minimum)
	for child in root.get_children():
		apply_to(child, scale_percent, minimum_font_size, scale_button_minimum)


static func _apply_node(node: Node, factor: float, minimum_font_size: int, scale_button_minimum: bool) -> void:
	if node is Label or node is BaseButton or node is LineEdit or node is OptionButton:
		var control := node as Control
		if control is TextureButton:
			return
		if not control.has_meta(BASE_FONT_METADATA):
			control.set_meta(BASE_FONT_METADATA, maxi(control.get_theme_font_size(&"font_size"), minimum_font_size))
		var base_size := maxi(int(control.get_meta(BASE_FONT_METADATA)), minimum_font_size)
		control.add_theme_font_size_override(&"font_size", roundi(float(base_size) * factor))
		if control is BaseButton and scale_button_minimum:
			if not control.has_meta(BASE_MINIMUM_METADATA):
				control.set_meta(BASE_MINIMUM_METADATA, control.custom_minimum_size)
			var base_minimum := Vector2(control.get_meta(BASE_MINIMUM_METADATA))
			control.custom_minimum_size.y = maxf(base_minimum.y, 48.0 * factor)
	if node is RichTextLabel:
		var rich := node as RichTextLabel
		if not rich.has_meta(BASE_FONT_METADATA):
			rich.set_meta(BASE_FONT_METADATA, maxi(rich.get_theme_font_size(&"normal_font_size"), minimum_font_size))
		rich.add_theme_font_size_override(&"normal_font_size", roundi(float(rich.get_meta(BASE_FONT_METADATA)) * factor))
