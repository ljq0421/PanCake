class_name CartoonYoutiaoFryerToggle
extends TextureButton

@export var lowered_texture: Texture2D
@export var raised_texture: Texture2D

var _is_raised := true


func _ready() -> void:
	_is_raised = true
	texture_normal = raised_texture
	tooltip_text = "点击油条机，放下沥网"
	pressed.connect(_toggle_drain)


func _toggle_drain() -> void:
	_is_raised = not _is_raised
	texture_normal = raised_texture if _is_raised else lowered_texture
	tooltip_text = "点击油条机，放下沥网" if _is_raised else "点击油条机，抬起沥网"
