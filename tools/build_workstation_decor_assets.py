#!/usr/bin/env python3
"""Build, preview, and audit ProjectCake workstation decor layers.

The raw alpha images are produced from ImageGen chroma-key sources with the
installed imagegen skill helper.  This script performs only deterministic
placement/normalization, then writes native-size overlays and validation art.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageChops, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
CANVAS = (1671, 941)
RAW_DIR = ROOT / "tmp/imagegen/workstation_decor_v1/alpha_raw"
OUT_DIR = ROOT / "resources/art/workstation/decor"
VALIDATION_DIR = ROOT / "tmp/validation/workstation_decor_v1"
BASE = ROOT / "resources/art/workstation/background/workstation_backplate_v1.png"

ASSETS = [
    {
        "id": "ingredient_rack_support_v1",
        "raw": RAW_DIR / "ingredient_rack_support_v1_raw.png",
        "out": OUT_DIR / "tier_01_ingredient_rack/ingredient_rack_support_v1.png",
        "label": "01 Rack supports",
        "allowed": [(110, 480, 500, 820), (1160, 480, 1550, 820)],
        "transform": "split_racks",
    },
    {
        "id": "storage_label_rail_v1",
        "raw": RAW_DIR / "storage_label_rail_v1_raw.png",
        "out": OUT_DIR / "tier_02_storage/storage_label_rail_v1.png",
        "label": "02 Storage label rail",
        "allowed": [(110, 130, 550, 330)],
        "transform": "move_storage_rail",
    },
    {
        "id": "blank_order_clipboard_v1",
        "raw": RAW_DIR / "blank_order_clipboard_v1_raw.png",
        "out": OUT_DIR / "tier_03_order/blank_order_clipboard_v1.png",
        "label": "03 Blank order board",
        "allowed": [(1410, 120, 1570, 370)],
        "transform": "move_order_board",
    },
    {
        "id": "awning_side_lamps_v1",
        "raw": RAW_DIR / "awning_side_lamps_v1_raw.png",
        "out": OUT_DIR / "tier_04_shelter/awning_side_lamps_v1.png",
        "label": "04 Awning and side lamps",
        "allowed": [(50, 0, 1620, 95), (10, 90, 110, 250), (1565, 90, 1665, 250)],
        "transform": "split_shelter",
        "allow_top_edge": True,
    },
    {
        "id": "tray_trim_customer_clips_v1",
        "raw": RAW_DIR / "tray_trim_customer_clips_v1_raw.png",
        "out": OUT_DIR / "tier_05_finish/tray_trim_customer_clips_v1.png",
        "label": "05 Tray trim and blank clips",
        "allowed": [(550, 130, 715, 290), (280, 370, 1400, 500)],
        "transform": "split_finish",
    },
]

FORBIDDEN = {
    "customer_portrait": (720, 110, 950, 390),
    "order_card": (1080, 110, 1410, 370),
    "central_operation": (515, 475, 1155, 941),
    "bottom_controls": (80, 820, 1590, 941),
}


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("layer has no visible pixels")
    return bbox


def paste_scaled(source: Image.Image, target: Image.Image, box: tuple[int, int, int, int]) -> None:
    bbox = alpha_bbox(source)
    crop = source.crop(bbox)
    width = box[2] - box[0]
    height = box[3] - box[1]
    crop = crop.resize((width, height), Image.Resampling.LANCZOS)
    target.alpha_composite(crop, (box[0], box[1]))


def build_layer(spec: dict) -> Image.Image:
    source = Image.open(spec["raw"]).convert("RGBA")
    if source.size != CANVAS:
        raise ValueError(f"{spec['raw']} has size {source.size}, expected {CANVAS}")
    transform = spec["transform"]
    if transform == "identity":
        return source.copy()

    result = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    if transform == "split_racks":
        midpoint = CANVAS[0] // 2
        left = source.crop((0, 0, midpoint, CANVAS[1]))
        right = source.crop((midpoint, 0, CANVAS[0], CANVAS[1]))
        paste_scaled(left, result, spec["allowed"][0])
        paste_scaled(right, result, spec["allowed"][1])
    elif transform == "move_storage_rail":
        paste_scaled(source, result, (120, 150, 540, 305))
    elif transform == "move_order_board":
        paste_scaled(source, result, (1415, 140, 1565, 352))
    elif transform == "split_shelter":
        awning = source.crop((0, 0, CANVAS[0], 90))
        left_lamp = source.crop((0, 90, 220, 300))
        right_lamp = source.crop((1450, 90, CANVAS[0], 300))
        result.alpha_composite(awning, (0, 0))
        paste_scaled(left_lamp, result, (20, 105, 100, 225))
        paste_scaled(right_lamp, result, (1575, 105, 1655, 225))
    elif transform == "split_finish":
        cards = source.crop((0, 0, CANVAS[0], 330))
        tray = source.crop((0, 330, CANVAS[0], CANVAS[1]))
        paste_scaled(cards, result, (560, 150, 710, 255))
        result.alpha_composite(tray, (0, 330))
    else:
        raise ValueError(f"unknown transform: {transform}")
    return result


def inside_any(x: int, y: int, rectangles: Iterable[tuple[int, int, int, int]]) -> bool:
    return any(left <= x < right and top <= y < bottom for left, top, right, bottom in rectangles)


def pixel_values(image: Image.Image):
    getter = getattr(image, "get_flattened_data", None)
    return getter() if getter is not None else image.getdata()


def count_overlap(alpha: Image.Image, rect: tuple[int, int, int, int], threshold: int = 8) -> int:
    left, top, right, bottom = rect
    return sum(value > threshold for value in pixel_values(alpha.crop((left, top, right, bottom))))


def audit_layer(spec: dict) -> dict:
    path = spec["out"]
    image = Image.open(path).convert("RGBA")
    if image.size != CANVAS:
        raise AssertionError(f"{path}: expected {CANVAS}, got {image.size}")
    alpha = image.getchannel("A")
    alpha_data = list(pixel_values(alpha))
    visible = sum(value > 8 for value in alpha_data)
    partial = sum(0 < value < 255 for value in alpha_data)
    if visible == 0:
        raise AssertionError(f"{path}: no visible pixels")

    bbox = alpha_bbox(image)
    pixels = image.load()
    residue = 0
    outside_allowed = 0
    for y in range(CANVAS[1]):
        for x in range(CANVAS[0]):
            r, g, b, a = pixels[x, y]
            if a <= 8:
                continue
            if not inside_any(x, y, spec["allowed"]):
                outside_allowed += 1
            magenta_key = r >= 180 and b >= 160 and g <= 110
            green_key = g >= 180 and r <= 110 and b <= 110
            if a >= 32 and (magenta_key or green_key):
                residue += 1

    edge_counts = {
        "top": sum(alpha.getpixel((x, 0)) > 8 for x in range(CANVAS[0])),
        "bottom": sum(alpha.getpixel((x, CANVAS[1] - 1)) > 8 for x in range(CANVAS[0])),
        "left": sum(alpha.getpixel((0, y)) > 8 for y in range(CANVAS[1])),
        "right": sum(alpha.getpixel((CANVAS[0] - 1, y)) > 8 for y in range(CANVAS[1])),
    }
    corners = [
        alpha.getpixel((0, 0)),
        alpha.getpixel((CANVAS[0] - 1, 0)),
        alpha.getpixel((0, CANVAS[1] - 1)),
        alpha.getpixel((CANVAS[0] - 1, CANVAS[1] - 1)),
    ]
    forbidden_overlap = {name: count_overlap(alpha, rect) for name, rect in FORBIDDEN.items()}

    if any(corners):
        raise AssertionError(f"{path}: nontransparent corner alpha {corners}")
    if edge_counts["bottom"] or edge_counts["left"] or edge_counts["right"]:
        raise AssertionError(f"{path}: unexpected canvas-edge pixels {edge_counts}")
    if edge_counts["top"] and not spec.get("allow_top_edge", False):
        raise AssertionError(f"{path}: unexpected top-edge pixels {edge_counts['top']}")
    if outside_allowed:
        raise AssertionError(f"{path}: {outside_allowed} pixels outside allowed placement zones")
    if residue:
        raise AssertionError(f"{path}: {residue} opaque chroma-key residue pixels")
    if any(forbidden_overlap.values()):
        raise AssertionError(f"{path}: forbidden-zone overlap {forbidden_overlap}")

    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    return {
        "id": spec["id"],
        "file": path.relative_to(ROOT).as_posix(),
        "size": list(image.size),
        "mode": image.mode,
        "alpha_bbox": list(bbox),
        "visible_pixels": visible,
        "transparent_ratio": round(sum(value == 0 for value in alpha_data) / len(alpha_data), 6),
        "partial_alpha_pixels": partial,
        "corners_alpha": corners,
        "edge_nontransparent": edge_counts,
        "opaque_key_residue": residue,
        "outside_allowed_pixels": outside_allowed,
        "forbidden_overlap": forbidden_overlap,
        "sha256": digest,
    }


def audit_inter_layer_overlap() -> dict[str, int]:
    masks: dict[str, Image.Image] = {}
    for spec in ASSETS:
        alpha = Image.open(spec["out"]).convert("RGBA").getchannel("A")
        masks[spec["id"]] = alpha.point(lambda value: 255 if value > 8 else 0)
    overlaps: dict[str, int] = {}
    ids = list(masks)
    for index, left_id in enumerate(ids):
        for right_id in ids[index + 1 :]:
            product = ImageChops.multiply(masks[left_id], masks[right_id])
            count = sum(value > 0 for value in pixel_values(product))
            overlaps[f"{left_id}__{right_id}"] = count
    collisions = {pair: count for pair, count in overlaps.items() if count}
    if collisions:
        raise AssertionError(f"decor layers overlap each other: {collisions}")
    return overlaps


def checkerboard(size: tuple[int, int], cell: int = 24) -> Image.Image:
    result = Image.new("RGB", size, (238, 231, 214))
    draw = ImageDraw.Draw(result)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if (x // cell + y // cell) % 2:
                draw.rectangle((x, y, x + cell - 1, y + cell - 1), fill=(208, 219, 212))
    return result.convert("RGBA")


def font(size: int) -> ImageFont.ImageFont:
    for candidate in (Path("C:/Windows/Fonts/arial.ttf"), Path("C:/Windows/Fonts/segoeui.ttf")):
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size=size)
    return ImageFont.load_default()


def make_previews() -> list[Path]:
    VALIDATION_DIR.mkdir(parents=True, exist_ok=True)
    base = Image.open(BASE).convert("RGBA")
    stages: list[tuple[str, Image.Image]] = [("Stage 00 - base", base.copy())]
    composite = base.copy()
    for spec in ASSETS:
        composite.alpha_composite(Image.open(spec["out"]).convert("RGBA"))
        stages.append((f"Stage {len(stages):02d} - {spec['label'][3:]}", composite.copy()))

    written: list[Path] = []
    for index, (_, image) in enumerate(stages):
        path = VALIDATION_DIR / f"workstation_decor_stage_{index:02d}_v1.png"
        image.save(path, optimize=True)
        written.append(path)

    full_hd = stages[-1][1].resize((1920, 1080), Image.Resampling.LANCZOS)
    full_hd_path = VALIDATION_DIR / "workstation_decor_stage_05_full_1920x1080_v1.png"
    full_hd.save(full_hd_path, optimize=True)
    written.append(full_hd_path)

    panels: list[tuple[str, Image.Image]] = []
    check = checkerboard(CANVAS)
    for spec in ASSETS:
        panel = check.copy()
        panel.alpha_composite(Image.open(spec["out"]).convert("RGBA"))
        panels.append((spec["label"], panel))
    panels.extend(stages)

    panel_size = (540, 304)
    label_height = 42
    columns = 3
    rows = (len(panels) + columns - 1) // columns
    sheet = Image.new("RGB", (columns * 580 + 40, rows * (panel_size[1] + label_height + 24) + 40), (45, 39, 34))
    draw = ImageDraw.Draw(sheet)
    title_font = font(24)
    for i, (label, panel) in enumerate(panels):
        col = i % columns
        row = i // columns
        x = 20 + col * 580
        y = 20 + row * (panel_size[1] + label_height + 24)
        thumb = panel.convert("RGB").resize(panel_size, Image.Resampling.LANCZOS)
        sheet.paste(thumb, (x, y + label_height))
        draw.text((x, y + 6), label, font=title_font, fill=(246, 224, 180))
        draw.rectangle((x - 1, y + label_height - 1, x + panel_size[0], y + label_height + panel_size[1]), outline=(181, 132, 62), width=2)

    contact = VALIDATION_DIR / "workstation_decor_contact_sheet_v1.png"
    sheet.save(contact, optimize=True)
    written.append(contact)
    return written


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="audit existing finals without rebuilding")
    args = parser.parse_args()

    if not args.check:
        for spec in ASSETS:
            spec["out"].parent.mkdir(parents=True, exist_ok=True)
            build_layer(spec).save(spec["out"], optimize=True)

    audit = [audit_layer(spec) for spec in ASSETS]
    layer_overlap = audit_inter_layer_overlap()
    previews = make_previews()
    report = {
        "status": "WORKSTATION_DECOR_ASSET_VALIDATION_PASS",
        "canvas": list(CANVAS),
        "anchor": "top-left (0,0)",
        "forbidden_zones": {name: list(rect) for name, rect in FORBIDDEN.items()},
        "assets": audit,
        "inter_layer_overlap": layer_overlap,
        "previews": [path.relative_to(ROOT).as_posix() for path in previews],
        "runtime_integration": "not performed; art-only scope",
        "human_review": "pending",
    }
    VALIDATION_DIR.mkdir(parents=True, exist_ok=True)
    report_path = VALIDATION_DIR / "workstation_decor_audit_v1.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(report["status"])
    for item in audit:
        print(
            f"{item['id']}: bbox={tuple(item['alpha_bbox'])} "
            f"transparent={item['transparent_ratio']:.6f} sha256={item['sha256']}"
        )
    print(f"report={report_path.relative_to(ROOT).as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
