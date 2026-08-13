#!/usr/bin/env python3
"""Normalize the approved steamer v5 sprites and build visual audit artifacts."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


CANVAS_SIZE = (1024, 512)
SUBJECT_MAX_SIZE = (920, 484)
SUBJECT_BOTTOM = 504
TIERS = (1, 2, 3)
STATES = ("closed", "open")


def _alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("image has no visible subject")
    return bbox


def _load_subject(path: Path) -> tuple[Image.Image, tuple[int, int, int, int]]:
    image = Image.open(path).convert("RGBA")
    bbox = _alpha_bbox(image)
    return image.crop(bbox), bbox


def _remove_magenta_residue(image: Image.Image) -> None:
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = pixels[x, y]
            if (
                alpha > 0
                and red > 180
                and blue > 130
                and min(red, blue) - green > 60
            ):
                pixels[x, y] = (0, 0, 0, 0)


def _pad_bbox(
    bbox: tuple[int, int, int, int],
    padding: int = 8,
) -> tuple[int, int, int, int]:
    left, top, right, bottom = bbox
    return (
        max(left - padding, 0),
        max(top - padding, 0),
        min(right + padding, CANVAS_SIZE[0]),
        min(bottom + padding, CANVAS_SIZE[1]),
    )


def _normalize_pair(
    source_dir: Path,
    output_dir: Path,
    tier: int,
) -> dict[str, object]:
    subjects: dict[str, Image.Image] = {}
    source_bounds: dict[str, tuple[int, int, int, int]] = {}
    for state in STATES:
        subject, bbox = _load_subject(source_dir / f"tier_{tier}_{state}.png")
        subjects[state] = subject
        source_bounds[state] = bbox

    max_width = max(subject.width for subject in subjects.values())
    max_height = max(subject.height for subject in subjects.values())
    scale = min(
        SUBJECT_MAX_SIZE[0] / max_width,
        SUBJECT_MAX_SIZE[1] / max_height,
    )

    normalized: dict[str, Image.Image] = {}
    for state, subject in subjects.items():
        resized = subject.resize(
            (
                max(1, round(subject.width * scale)),
                max(1, round(subject.height * scale)),
            ),
            Image.Resampling.LANCZOS,
        )
        _remove_magenta_residue(resized)
        canvas = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
        position = (
            (CANVAS_SIZE[0] - resized.width) // 2,
            SUBJECT_BOTTOM - resized.height,
        )
        canvas.alpha_composite(resized, position)
        normalized[state] = canvas

    pair_bbox: tuple[int, int, int, int] | None = None
    for image in normalized.values():
        bbox = _alpha_bbox(image)
        if pair_bbox is None:
            pair_bbox = bbox
        else:
            pair_bbox = (
                min(pair_bbox[0], bbox[0]),
                min(pair_bbox[1], bbox[1]),
                max(pair_bbox[2], bbox[2]),
                max(pair_bbox[3], bbox[3]),
            )
    assert pair_bbox is not None
    pair_bbox = _pad_bbox(pair_bbox)

    output_dir.mkdir(parents=True, exist_ok=True)
    entries: dict[str, object] = {
        "tier": tier,
        "pair_bounds": list(pair_bbox),
        "scale": scale,
        "states": {},
    }
    for state, image in normalized.items():
        output_path = output_dir / (
            f"steamer_tier_{tier}_{state}_five_area_v5_chinese.png"
        )
        image.save(output_path, optimize=True)
        alpha = image.getchannel("A")
        rgba_bytes = image.tobytes()
        pixels = image.load()
        magenta_residual = sum(
            1
            for y in range(image.height)
            for x in range(image.width)
            if (
                pixels[x, y][3] > 0
                and pixels[x, y][0] > 180
                and pixels[x, y][2] > 130
                and min(pixels[x, y][0], pixels[x, y][2]) - pixels[x, y][1] > 60
            )
        )
        entries["states"][state] = {
            "path": output_path.as_posix(),
            "canvas_size": list(image.size),
            "source_bounds": list(source_bounds[state]),
            "normalized_bounds": list(_alpha_bbox(image)),
            "alpha_extrema": list(alpha.getextrema()),
            "corner_alpha": [
                alpha.getpixel((0, 0)),
                alpha.getpixel((image.width - 1, 0)),
                alpha.getpixel((0, image.height - 1)),
                alpha.getpixel((image.width - 1, image.height - 1)),
            ],
            "magenta_residual_pixels": magenta_residual,
            "sha256": hashlib.sha256(rgba_bytes).hexdigest(),
        }
    return entries


def _font(size: int) -> ImageFont.ImageFont:
    candidates = (
        Path("C:/Windows/Fonts/msyh.ttc"),
        Path("C:/Windows/Fonts/simhei.ttf"),
    )
    for candidate in candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size=size)
    return ImageFont.load_default()


def _render_contact_sheet(output_dir: Path, audit: dict[str, object], path: Path) -> None:
    sheet = Image.new("RGB", (1200, 860), "#203238")
    draw = ImageDraw.Draw(sheet)
    title_font = _font(30)
    label_font = _font(22)
    note_font = _font(16)
    draw.text((36, 22), "ProjectCake 蒸笼 v5 · 正式工作台预览", fill="#fff3d0", font=title_font)
    draw.text((36, 62), "每列：1层 / 2层 / 4层；上排闭盖，下排开盖", fill="#b9d9d5", font=note_font)

    tier_entries = {int(entry["tier"]): entry for entry in audit["tiers"]}
    for column, tier in enumerate(TIERS):
        entry = tier_entries[tier]
        left, top, right, bottom = entry["pair_bounds"]
        for row, state in enumerate(STATES):
            panel_x = 36 + column * 386
            panel_y = 104 + row * 356
            draw.rounded_rectangle(
                (panel_x, panel_y, panel_x + 356, panel_y + 316),
                radius=18,
                fill="#f7eac4",
                outline="#b27331",
                width=4,
            )
            label = f"T{tier} · {'闭盖' if state == 'closed' else '开盖'}"
            draw.text((panel_x + 18, panel_y + 14), label, fill="#55351f", font=label_font)
            source_path = output_dir / f"steamer_tier_{tier}_{state}_five_area_v5_chinese.png"
            source = Image.open(source_path).convert("RGBA").crop((left, top, right, bottom))
            preview = Image.new("RGBA", (306, 216), (0, 0, 0, 0))
            source.thumbnail((286, 196), Image.Resampling.LANCZOS)
            preview.alpha_composite(
                source,
                ((preview.width - source.width) // 2, preview.height - source.height - 4),
            )
            sheet.paste(preview, (panel_x + 25, panel_y + 82), preview)

    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path, optimize=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--audit", type=Path, required=True)
    parser.add_argument("--contact-sheet", type=Path, required=True)
    args = parser.parse_args()

    audit: dict[str, object] = {
        "asset_family": "steamer_v5_chinese",
        "canvas_size": list(CANVAS_SIZE),
        "tier_capacities": {"1": 1, "2": 2, "3": 4},
        "tiers": [],
    }
    for tier in TIERS:
        audit["tiers"].append(
            _normalize_pair(args.source_dir, args.output_dir, tier)
        )

    args.audit.parent.mkdir(parents=True, exist_ok=True)
    args.audit.write_text(json.dumps(audit, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    _render_contact_sheet(args.output_dir, audit, args.contact_sheet)
    print(json.dumps(audit, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
