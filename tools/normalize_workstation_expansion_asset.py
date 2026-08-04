#!/usr/bin/env python3
"""Normalize a keyed ImageGen cutout onto a stable transparent game-sprite canvas."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--width", required=True, type=int)
    parser.add_argument("--height", required=True, type=int)
    parser.add_argument("--margin", type=float, default=0.06)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    image = Image.open(args.input).convert("RGBA")
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise SystemExit("input has no visible pixels")

    cropped = image.crop(bbox)
    usable_w = max(1, round(args.width * (1.0 - args.margin * 2.0)))
    usable_h = max(1, round(args.height * (1.0 - args.margin * 2.0)))
    scale = min(usable_w / cropped.width, usable_h / cropped.height)
    scaled_size = (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale)))
    resized = cropped.resize(scaled_size, Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (args.width, args.height), (0, 0, 0, 0))
    offset = ((args.width - resized.width) // 2, (args.height - resized.height) // 2)
    canvas.alpha_composite(resized, offset)
    pixels = list(canvas.get_flattened_data())
    canvas.putdata([
        (r, g, b, 0) if a > 0 and r > 210 and b > 210 and g < 80 else (r, g, b, a)
        for r, g, b, a in pixels
    ])
    args.output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(args.output, optimize=True)

    final_alpha = canvas.getchannel("A")
    final_bbox = final_alpha.getbbox()
    corners = [canvas.getpixel((0, 0))[3], canvas.getpixel((args.width - 1, 0))[3], canvas.getpixel((0, args.height - 1))[3], canvas.getpixel((args.width - 1, args.height - 1))[3]]
    magenta_fringe = sum(1 for r, g, b, a in canvas.get_flattened_data() if a > 0 and r > 210 and b > 210 and g < 80)
    digest = hashlib.sha256(args.output.read_bytes()).hexdigest()
    print(json.dumps({
        "file": args.output.as_posix(),
        "size": [args.width, args.height],
        "source_bbox": list(bbox),
        "final_bbox": list(final_bbox) if final_bbox else None,
        "transparent_corners": corners,
        "magenta_fringe_pixels": magenta_fringe,
        "sha256": digest,
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
