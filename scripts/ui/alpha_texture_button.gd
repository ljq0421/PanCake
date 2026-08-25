class_name AlphaTextureButton
extends TextureButton

## A TextureButton whose visible texture also defines its clickable silhouette.
## Keeping rendering and hit testing on one node prevents accessory visuals from
## drifting away from sibling transparent buttons when the station is resized.
@export var hit_texture: Texture2D:
	set(value):
		hit_texture = value
		_hit_image = hit_texture.get_image() if hit_texture != null else null

var _hit_image: Image


func _ready() -> void:
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	if _hit_image == null and hit_texture != null:
		_hit_image = hit_texture.get_image()


func configure_texture(texture: Texture2D) -> void:
	hit_texture = texture
	texture_normal = texture
	texture_disabled = texture
	texture_hover = texture
	texture_pressed = texture


func _has_point(point: Vector2) -> bool:
	if not Rect2(Vector2.ZERO, size).has_point(point):
		return false
	if _hit_image == null or size.x <= 0.0 or size.y <= 0.0:
		return false
	var pixel_x := clampi(floori(point.x / size.x * float(_hit_image.get_width())), 0, _hit_image.get_width() - 1)
	var pixel_y := clampi(floori(point.y / size.y * float(_hit_image.get_height())), 0, _hit_image.get_height() - 1)
	return _hit_image.get_pixel(pixel_x, pixel_y).a > 0.0
