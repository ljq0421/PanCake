from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "tmp" / "validation" / "fixed_store_growth_visual_latest.png"
OUTPUT = ROOT / "docs" / "workstation_expansion_layout_concept_v2.png"
FONT_REGULAR = Path(r"C:\Windows\Fonts\Deng.ttf")
FONT_BOLD = Path(r"C:\Windows\Fonts\Dengb.ttf")

COLORS = {
    "ink": (42, 31, 24, 255),
    "cream": (246, 232, 201, 245),
    "metal": (207, 202, 185, 242),
    "teal": (39, 117, 111, 255),
    "teal_dark": (19, 76, 73, 255),
    "amber": (225, 163, 61, 255),
    "coral": (178, 89, 65, 255),
    "sage": (101, 133, 79, 255),
    "white": (255, 250, 237, 255),
    "shadow": (20, 16, 12, 105),
}


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT_BOLD if bold else FONT_REGULAR), size)


def rounded_panel(
    draw: ImageDraw.ImageDraw,
    box: tuple[int, int, int, int],
    fill: tuple[int, int, int, int],
    outline: tuple[int, int, int, int],
    width: int = 3,
    radius: int = 14,
) -> None:
    x1, y1, x2, y2 = box
    draw.rounded_rectangle((x1 + 5, y1 + 7, x2 + 5, y2 + 7), radius, fill=COLORS["shadow"])
    draw.rounded_rectangle(box, radius, fill=fill, outline=outline, width=width)


def crop_alpha(path: Path) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    bbox = image.getbbox()
    return image.crop(bbox) if bbox else image


def contain(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    result = image.copy()
    result.thumbnail(size, Image.Resampling.LANCZOS)
    return result


def paste_center(canvas: Image.Image, image: Image.Image, box: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    x1, y1, x2, y2 = box
    x = x1 + ((x2 - x1) - image.width) // 2
    y = y1 + ((y2 - y1) - image.height) // 2
    canvas.alpha_composite(image, (x, y))
    return (x, y, x + image.width, y + image.height)


def mute_existing_content(
    canvas: Image.Image,
    box: tuple[int, int, int, int],
    radius: int = 22,
) -> None:
    x1, y1, x2, y2 = box
    patch = canvas.crop(box).filter(ImageFilter.GaussianBlur(18))
    tint = Image.new("RGBA", patch.size, (239, 229, 204, 178))
    patch = Image.alpha_composite(patch, tint)
    mask = Image.new("L", patch.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, patch.width - 1, patch.height - 1), radius, fill=255)
    canvas.paste(patch, (x1, y1), mask)


def label_chip(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int],
    text: str,
    color: tuple[int, int, int, int],
    size: int = 22,
) -> tuple[int, int, int, int]:
    typeface = font(size, True)
    bbox = draw.textbbox((0, 0), text, font=typeface)
    width = bbox[2] - bbox[0] + 30
    height = bbox[3] - bbox[1] + 18
    x, y = xy
    draw.rounded_rectangle((x, y, x + width, y + height), 13, fill=color)
    draw.text((x + 15, y + 6), text, font=typeface, fill=COLORS["white"])
    return (x, y, x + width, y + height)


def material_caddy(
    canvas: Image.Image,
    draw: ImageDraw.ImageDraw,
    box: tuple[int, int, int, int],
    title: str,
    accent: tuple[int, int, int, int],
    items: list[tuple[str, Path]],
) -> None:
    x1, y1, x2, y2 = box
    rounded_panel(draw, box, COLORS["metal"], COLORS["teal_dark"], width=3, radius=12)
    draw.rounded_rectangle((x1 + 8, y1 + 8, x2 - 8, y1 + 32), 7, fill=accent)
    draw.text((x1 + 15, y1 + 8), title, font=font(17, True), fill=COLORS["white"])
    gap = 7
    slot_y1 = y1 + 39
    slot_y2 = y2 - 8
    slot_width = ((x2 - x1 - 24) - gap * (len(items) - 1)) // len(items)
    for index, (name, path) in enumerate(items):
        sx1 = x1 + 12 + index * (slot_width + gap)
        sx2 = sx1 + slot_width
        draw.rounded_rectangle(
            (sx1, slot_y1, sx2, slot_y2),
            8,
            fill=(244, 238, 217, 250),
            outline=(115, 99, 76, 255),
            width=2,
        )
        ingredient = contain(crop_alpha(path), (slot_width - 16, 38))
        paste_center(canvas, ingredient, (sx1 + 5, slot_y1 + 3, sx2 - 5, slot_y1 + 43))
        name_font = font(14, True)
        text_box = draw.textbbox((0, 0), name, font=name_font)
        draw.text(
            ((sx1 + sx2 - (text_box[2] - text_box[0])) // 2, slot_y2 - 24),
            name,
            font=name_font,
            fill=COLORS["ink"],
        )


def station_outline(
    draw: ImageDraw.ImageDraw,
    box: tuple[int, int, int, int],
    accent: tuple[int, int, int, int],
    label: str,
    footprint: str,
) -> None:
    x1, y1, x2, y2 = box
    draw.rounded_rectangle(box, 22, outline=accent, width=5)
    label_chip(draw, (x1 + 12, y2 - 49), label, accent, 19)
    text_font = font(16, True)
    text_box = draw.textbbox((0, 0), footprint, font=text_font)
    draw.rounded_rectangle(
        (x2 - (text_box[2] - text_box[0]) - 24, y1 + 10, x2 - 10, y1 + 38),
        8,
        fill=(42, 31, 24, 208),
    )
    draw.text((x2 - (text_box[2] - text_box[0]) - 17, y1 + 12), footprint, font=text_font, fill=COLORS["white"])


def render() -> None:
    canvas = Image.open(BASE).convert("RGBA")
    if canvas.size == (1920, 1200):
        canvas = canvas.crop((0, 60, 1920, 1140))
    if canvas.size != (1920, 1080):
        raise ValueError(f"Expected 1920x1080 base image, got {canvas.size}")
    draw = ImageDraw.Draw(canvas, "RGBA")

    soy_box = (82, 670, 356, 1016)
    waffle_box = (370, 670, 706, 1016)
    fryer_box = (1305, 824, 1845, 1019)
    mute_existing_content(canvas, soy_box)
    mute_existing_content(canvas, waffle_box)
    mute_existing_content(canvas, fryer_box)
    draw = ImageDraw.Draw(canvas, "RGBA")

    # Header: exact implementation-facing summary, separate from the playable surface.
    draw.rounded_rectangle((34, 24, 1886, 116), 22, fill=(38, 28, 22, 232), outline=COLORS["amber"], width=3)
    draw.text((66, 42), "固定摊位扩展工作台 · 布局概念 V2", font=font(34, True), fill=COLORS["white"])
    draw.text(
        (66, 84),
        "基准画布 1920×1080  |  工具筒 3  |  设备原料位 9：豆类 3 / 鸡蛋仔 3 / 油条面 3",
        font=font(20),
        fill=(231, 198, 127, 255),
    )

    # Hide the old loose upgrade hooks and create one continuous mise-en-place rail.
    draw.rounded_rectangle((370, 535, 1264, 667), 18, fill=(225, 216, 194, 238), outline=COLORS["teal_dark"], width=4)
    draw.text((392, 543), "后沿备料轨道：原料紧邻对应设备，长按原料盒补货", font=font(18, True), fill=COLORS["ink"])

    resources = ROOT / "resources" / "art" / "ingredients"
    material_caddy(
        canvas,
        draw,
        (382, 573, 657, 660),
        "豆浆机 · 3 格",
        COLORS["amber"],
        [
            ("黄豆", resources / "soybean" / "yellow_soybean_portion_v1.png"),
            ("红豆", resources / "beans" / "red_bean_portion_v1.png"),
            ("黑豆", resources / "beans" / "black_bean_portion_v1.png"),
        ],
    )
    material_caddy(
        canvas,
        draw,
        (670, 573, 945, 660),
        "鸡蛋仔 · 3 格",
        COLORS["coral"],
        [
            ("鸡蛋糊", resources / "egg_waffle" / "plain_egg_waffle_batter_v1.png"),
            ("草莓酱", resources / "sauces" / "strawberry_sauce_bottle_v1.png"),
            ("巧克力", resources / "sauces" / "chocolate_sauce_bottle_v1.png"),
        ],
    )
    material_caddy(
        canvas,
        draw,
        (958, 573, 1252, 660),
        "油条机 · 3 格",
        COLORS["sage"],
        [
            ("原味面", resources / "youtiao" / "plain_youtiao_dough_v1.png"),
            ("芝麻面", resources / "youtiao" / "sesame_youtiao_dough_v1.png"),
            ("葱香面", resources / "youtiao" / "scallion_youtiao_dough_v1.png"),
        ],
    )

    # Tool cups remain the single home for base and upgraded hand tools.
    draw.rounded_rectangle((24, 432, 360, 626), 20, outline=COLORS["teal"], width=5)
    label_chip(draw, (42, 585), "工具筒 ×3 · 升级替换原位", COLORS["teal"], 18)

    # Device placements: alpha-cropped source art is rendered at the target visual scale.
    machine_root = ROOT / "resources" / "art" / "workstation" / "expansion" / "machines"
    station_outline(draw, soy_box, COLORS["amber"], "豆浆机", "占地 274×346")
    station_outline(draw, waffle_box, COLORS["coral"], "鸡蛋仔机", "占地 336×346")
    station_outline(draw, fryer_box, COLORS["sage"], "油条机", "占地 540×195")

    soy = contain(crop_alpha(machine_root / "soy_milk_machine_tier_2_v1.png"), (252, 286))
    waffle = contain(crop_alpha(machine_root / "egg_waffle_machine_tier_2_v1.png"), (300, 292))
    fryer = contain(crop_alpha(machine_root / "youtiao_fryer_tier_2_v1.png"), (510, 162))
    paste_center(canvas, soy, (92, 700, 346, 985))
    paste_center(canvas, waffle, (384, 700, 692, 985))
    paste_center(canvas, fryer, (1320, 850, 1830, 1006))

    # Relation lines make the source-to-machine grouping measurable without UI arrows in the final game.
    draw.line((520, 660, 220, 682), fill=COLORS["amber"], width=4)
    draw.ellipse((213, 675, 227, 689), fill=COLORS["amber"])
    draw.line((808, 660, 536, 682), fill=COLORS["coral"], width=4)
    draw.ellipse((529, 675, 543, 689), fill=COLORS["coral"])
    draw.line((1105, 660, 1575, 834), fill=COLORS["sage"], width=4)
    draw.ellipse((1568, 827, 1582, 841), fill=COLORS["sage"])

    # Fixed areas are explicitly called out so implementation does not steal their interaction space.
    draw.rounded_rectangle((730, 625, 1270, 1018), 28, outline=(255, 244, 214, 220), width=3)
    label_chip(draw, (890, 976), "中央鏊子 · 保持不动", COLORS["ink"], 18)
    draw.rounded_rectangle((1268, 622, 1842, 825), 22, outline=(255, 244, 214, 220), width=3)
    label_chip(draw, (1450, 780), "小料盘 · 保持不动", COLORS["ink"], 18)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(OUTPUT, quality=96)
    print(OUTPUT)


if __name__ == "__main__":
    render()
