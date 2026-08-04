#!/usr/bin/env python3
"""Audit ProjectCake workstation-expansion art batches and build a contact sheet."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
ASSETS = [
    "resources/art/workstation/expansion/machines/soy_milk_machine_tier_1_v1.png",
    "resources/art/workstation/expansion/machines/soy_milk_machine_tier_2_v1.png",
    "resources/art/workstation/expansion/machines/soy_milk_machine_tier_3_v1.png",
    "resources/art/workstation/expansion/machines/youtiao_fryer_tier_1_v1.png",
    "resources/art/workstation/expansion/machines/youtiao_fryer_tier_2_v1.png",
    "resources/art/workstation/expansion/machines/youtiao_fryer_tier_3_v1.png",
    "resources/art/workstation/expansion/machines/egg_waffle_machine_tier_1_v1.png",
    "resources/art/workstation/expansion/machines/egg_waffle_machine_tier_2_v1.png",
    "resources/art/workstation/expansion/machines/egg_waffle_machine_tier_3_v1.png",
    "resources/art/workstation/expansion/tools/single_press_spreader_v1.png",
    "resources/art/workstation/expansion/tools/automatic_sauce_brush_v1.png",
    "resources/art/workstation/expansion/trays/ingredient_tray_4x3_v1.png",
    "resources/art/workstation/expansion/trays/ingredient_slot_locked_cover_v1.png",
    "resources/art/workstation/expansion/bins/small_ingredient_box_tier_1_v1.png",
    "resources/art/workstation/expansion/bins/small_ingredient_box_tier_2_v1.png",
    "resources/art/workstation/expansion/bins/small_ingredient_box_tier_3_v1.png",
    "resources/art/ingredients/soybean/yellow_soybean_portion_v1.png",
    "resources/art/ingredients/beans/red_bean_portion_v1.png",
    "resources/art/ingredients/beans/black_bean_portion_v1.png",
    "resources/art/products/soy_milk/plain_soy_milk_cup_v1.png",
    "resources/art/products/soy_milk/red_bean_soy_milk_cup_v1.png",
    "resources/art/products/soy_milk/black_bean_soy_milk_cup_v1.png",
    "resources/art/ingredients/youtiao/plain_youtiao_dough_v1.png",
    "resources/art/ingredients/youtiao/sesame_youtiao_dough_v1.png",
    "resources/art/ingredients/youtiao/scallion_youtiao_dough_v1.png",
    "resources/art/products/youtiao/plain_youtiao_v1.png",
    "resources/art/products/youtiao/sesame_youtiao_v1.png",
    "resources/art/products/youtiao/scallion_youtiao_v1.png",
    "resources/art/ingredients/egg_waffle/plain_egg_waffle_batter_v1.png",
    "resources/art/ingredients/sauces/strawberry_sauce_bottle_v1.png",
    "resources/art/ingredients/sauces/chocolate_sauce_bottle_v1.png",
    "resources/art/products/egg_waffle/plain_egg_waffle_v1.png",
    "resources/art/products/egg_waffle/strawberry_egg_waffle_v1.png",
    "resources/art/products/egg_waffle/chocolate_egg_waffle_v1.png",
    "resources/art/ingredients/nuts/peanut_portion_v1.png",
    "resources/art/ingredients/beans/mung_bean_portion_v1.png",
    "resources/art/ingredients/grains/five_grain_mix_portion_v1.png",
    "resources/art/products/soy_milk/peanut_soy_milk_cup_v1.png",
    "resources/art/products/soy_milk/mung_bean_soy_milk_cup_v1.png",
    "resources/art/products/soy_milk/five_grain_soy_milk_cup_v1.png",
    "resources/art/ingredients/youtiao/glutinous_rice_youtiao_dough_v1.png",
    "resources/art/ingredients/youtiao/multigrain_youtiao_dough_v1.png",
    "resources/art/ingredients/youtiao/filled_youtiao_dough_v1.png",
    "resources/art/products/youtiao/glutinous_rice_youtiao_v1.png",
    "resources/art/products/youtiao/multigrain_youtiao_v1.png",
    "resources/art/products/youtiao/filled_youtiao_v1.png",
    "resources/art/ingredients/egg_waffle/matcha_egg_waffle_batter_v1.png",
    "resources/art/ingredients/egg_waffle/sesame_topping_portion_v1.png",
    "resources/art/ingredients/egg_waffle/dried_fruit_topping_portion_v1.png",
    "resources/art/products/egg_waffle/matcha_egg_waffle_v1.png",
    "resources/art/products/egg_waffle/sesame_egg_waffle_v1.png",
    "resources/art/products/egg_waffle/dried_fruit_egg_waffle_v1.png",
]


def checkerboard(size: tuple[int, int], cell: int = 16) -> Image.Image:
    image = Image.new("RGB", size, "#d9d2c5")
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if (x // cell + y // cell) % 2:
                draw.rectangle((x, y, x + cell - 1, y + cell - 1), fill="#f2eee7")
    return image


def main() -> None:
    output_dir = ROOT / "tmp/validation/workstation_expansion_v1"
    output_dir.mkdir(parents=True, exist_ok=True)
    records: list[dict[str, object]] = []
    thumbs: list[tuple[str, Image.Image]] = []
    for relative in ASSETS:
        path = ROOT / relative
        image = Image.open(path).convert("RGBA")
        alpha = image.getchannel("A")
        bbox = alpha.getbbox()
        corners = [
            image.getpixel((0, 0))[3],
            image.getpixel((image.width - 1, 0))[3],
            image.getpixel((0, image.height - 1))[3],
            image.getpixel((image.width - 1, image.height - 1))[3],
        ]
        pixels = list(image.get_flattened_data())
        magenta = sum(1 for r, g, b, a in pixels if a > 0 and r > 210 and b > 210 and g < 80)
        records.append({
            "file": relative,
            "size": [image.width, image.height],
            "mode": image.mode,
            "alpha_bbox": list(bbox) if bbox else None,
            "transparent_corner_alpha": corners,
            "magenta_fringe_pixels": magenta,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "godot_import_sidecar": path.with_suffix(path.suffix + ".import").exists(),
        })
        thumb = image.copy()
        thumb.thumbnail((430, 250), Image.Resampling.LANCZOS)
        thumbs.append((Path(relative).stem, thumb))

    cell_w, cell_h, columns = 480, 320, 2
    rows = (len(thumbs) + columns - 1) // columns
    sheet = Image.new("RGB", (cell_w * columns, cell_h * rows), "#c9c0b1")
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default(size=20)
    for index, (name, thumb) in enumerate(thumbs):
        x = (index % columns) * cell_w
        y = (index // columns) * cell_h
        background = checkerboard((cell_w - 20, cell_h - 54))
        sheet.paste(background, (x + 10, y + 40))
        tx = x + (cell_w - thumb.width) // 2
        ty = y + 46 + (cell_h - 60 - thumb.height) // 2
        sheet.paste(thumb, (tx, ty), thumb)
        draw.text((x + 14, y + 10), name, fill="#2b1d16", font=font)

    contact_path = output_dir / "workstation_expansion_contact_sheet_v1.png"
    sheet.save(contact_path, optimize=True)
    report = {
        "asset_count": len(records),
        "all_rgba": all(record["mode"] == "RGBA" for record in records),
        "all_corners_transparent": all(record["transparent_corner_alpha"] == [0, 0, 0, 0] for record in records),
        "all_key_fringe_zero": all(record["magenta_fringe_pixels"] == 0 for record in records),
        "all_imported": all(record["godot_import_sidecar"] for record in records),
        "records": records,
    }
    report_path = output_dir / "workstation_expansion_asset_audit_v1.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()
