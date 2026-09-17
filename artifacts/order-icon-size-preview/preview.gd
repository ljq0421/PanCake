extends Control

const FONT = preload("res://resource/fonts/KNMaiyuan/KNMaiyuan-Regular.ttf")
const FRAME = preload("res://resource/art/OrderBubbleUI/frame-tianjin.tres")
const ROOT = "res://resource/art/TianJin/"
const PAPER = Color("faf2df")
const INK = Color("4a291c")
const BLUE = Color("368eb2")
const ORANGE = Color("ce792e")
var geometry: Array[Dictionary] = []
var prepared: Dictionary = {}

func label_at(text: String, pos: Vector2, font_size: int, color: Color = INK) -> void:
	var label = Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)

func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i(-10000, -10000)
	label_at("订单卡图标放大 · 修改前示意", Vector2(100, 42), 46)
	label_at("使用现有游戏素材与边框；卡片统一宽度保持 184，以下按 2 倍展示便于比较。", Vector2(103, 108), 25)
	label_at("当前尺寸", Vector2(186, 175), 31)
	label_at("建议放大", Vector2(774, 175), 31)
	make_card(Vector2(155, 276), false)
	make_card(Vector2(745, 276), true)
	label_at("成品槽位 62 × 46\n配料槽位 28 × 22", Vector2(178, 735), 26)
	label_at("成品槽位 74 × 54\n配料槽位 36 × 26", Vector2(768, 735), 26)
	label_at("可视成品约放大 20%\n可视配料约放大 20%—30%", Vector2(1250, 260), 34)
	label_at("放大的依据", Vector2(1250, 385), 29)
	label_at("先识别非透明的食物轮廓，\n再等比放入更大的图标区域。\n不按原图整张画布直接撑满。", Vector2(1250, 437), 27)
	label_at("边缘保护", Vector2(1250, 570), 29)
	label_at("保留半透明边缘与描边余量。\n数量文字仍在右侧，\n无配料成品保持居中。", Vector2(1250, 622), 27)
	label_at("蓝框：图标区域", Vector2(1250, 786), 25, BLUE)
	label_at("橙框：素材可视轮廓的外接矩形", Vector2(1250, 828), 25, ORANGE)
	label_at("框线只用于这张示意，正式订单卡不会显示。", Vector2(100, 946), 25)
	label_at("此图仅供确认放大幅度，尚未修改正式订单卡代码。", Vector2(100, 989), 25, Color("816c59"))
	queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var shot = get_viewport().get_texture().get_image()
	var err = shot.save_png("res://artifacts/order-icon-size-preview/proposal.png")
	print("ORDER_ICON_SIZE_PREVIEW saved=", err)
	get_tree().quit(0 if err == OK else 1)

func make_card(origin: Vector2, larger: bool) -> void:
	geometry.append({"origin": origin, "frame": true})
	var product_size = Vector2(74, 54) if larger else Vector2(62, 46)
	var topping_size = Vector2(36, 26) if larger else Vector2(28, 22)
	var row_height: float = 58 if larger else 54
	var top: float = 6 if larger else 18
	var inset: float = 2 if larger else 4
	var gap: float = 6 if larger else 8
	var group_width = product_size.x + gap + topping_size.x * 2 + 4
	var start_x = (184 - group_width) / 2
	icon_at(ROOT + "装袋后的通用煎饼果子.png", origin, Vector2(start_x, top + inset), product_size, larger)
	var toppings = ["OrderUI/sauce_light.png", "香葱碎.png", "薄脆.png"]
	for i in range(3):
		var pos = Vector2(start_x + product_size.x + gap + (i % 2) * (topping_size.x + 4), top + inset + floori(i / 2.0) * (topping_size.y + 2))
		icon_at(ROOT + toppings[i], origin, pos, topping_size, larger)
	for row in range(1, 3):
		var y = top + row * (row_height + 1)
		geometry.append({"origin": origin, "rule": Rect2(12 if larger else 18, y - 1, 160 if larger else 148, 1)})
		icon_at(ROOT + ("成品豆浆杯.png" if row == 1 else "熟油条.png"), origin,
			Vector2((184 - product_size.x) / 2, y + inset), product_size, larger)
		if row == 2:
			label_at("0/2", origin + Vector2((184 + product_size.x) / 2 + (2 if larger else 4), y + inset + (product_size.y - 26) / 2) * 2, 36)

func icon_at(path: String, origin: Vector2, pos: Vector2, size: Vector2, show_bounds: bool) -> void:
	var key = path + str(size)
	if not prepared.has(key):
		var source = load(path).get_image()
		source.convert(Image.FORMAT_RGBA8)
		var pixels = source.get_data()
		var width = source.get_width()
		var height = source.get_height()
		var left = width
		var top = height
		var right = -1
		var bottom = -1
		for y in range(height):
			for x in range(width):
				if pixels[(y * width + x) * 4 + 3] >= 8:
					left = mini(left, x)
					right = maxi(right, x)
					top = mini(top, y)
					bottom = maxi(bottom, y)
		var bounds = Rect2i(left, top, right - left + 1, bottom - top + 1)
		var fit = minf((size.x - 4) / bounds.size.x, (size.y - 4) / bounds.size.y)
		var padding = ceili(2 / fit)
		var image = Image.create_empty(bounds.size.x + padding * 2, bounds.size.y + padding * 2, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		image.blit_rect(source, bounds, Vector2i(padding, padding))
		image.fix_alpha_edges()
		image.generate_mipmaps()
		prepared[key] = {"texture": ImageTexture.create_from_image(image), "used": Rect2(Vector2(padding, padding), bounds.size)}
	var texture: Texture2D = prepared[key].texture
	var icon = TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = texture
	icon.position = origin + pos * 2
	icon.size = size * 2
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var ink = ShaderMaterial.new()
	ink.shader = load("res://resource/shaders/food_ink.gdshader")
	ink.set_shader_parameter("outline_pixels", 1.7)
	ink.set_shader_parameter("detail_pixels", .7)
	icon.material = ink
	add_child(icon)
	if show_bounds:
		var scale = minf(size.x / texture.get_width(), size.y / texture.get_height())
		var fitted = (size - texture.get_size() * scale) / 2
		var used: Rect2 = prepared[key].used
		geometry.append({"origin": origin, "slot": Rect2(pos, size),
			"visible": Rect2(pos + fitted + used.position * scale, used.size * scale)})

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color("f1e9dc"))
	for item in geometry:
		draw_set_transform(item.origin, 0, Vector2.ONE * 2)
		if item.has("frame"):
			draw_set_transform(item.origin + Vector2(0, -48), 0, Vector2.ONE * .8)
			var frame_size = Vector2(184 / .4, (203 + 24) / .4)
			draw_style_box(FRAME, Rect2(Vector2.ZERO, frame_size))
			draw_texture_rect_region(FRAME.texture, Rect2(110, frame_size.y - 80, frame_size.x - 220, 80),
				Rect2(110, FRAME.texture.get_height() - 80, 64, 80))
			draw_set_transform(item.origin, 0, Vector2.ONE * 2)
			var tail = PackedVector2Array([Vector2(77, 194), Vector2(92, 215), Vector2(107, 194)])
			draw_colored_polygon(tail, PAPER)
			draw_polyline(tail, INK, 3, true)
			draw_line(Vector2(18, 188), Vector2(166, 188), Color("76a951"), 6, true)
		elif item.has("rule"):
			draw_rect(item.rule, Color("cdb38e"))
		elif item.has("slot"):
			draw_rect(item.slot, Color(BLUE, .6), false, .6)
			draw_rect(item.visible, Color(ORANGE, .7), false, .6)
	draw_set_transform(Vector2.ZERO)
