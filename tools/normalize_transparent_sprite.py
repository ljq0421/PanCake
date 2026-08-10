"""Place a transparent sprite on an exact registered game-art canvas."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--canvas-width", required=True, type=int)
    parser.add_argument("--canvas-height", required=True, type=int)
    parser.add_argument("--box-width", required=True, type=int)
    parser.add_argument("--box-height", required=True, type=int)
    parser.add_argument("--center-x", required=True, type=float)
    parser.add_argument("--center-y", required=True, type=float)
    args = parser.parse_args()

    image = Image.open(args.input).convert("RGBA")
    alpha_bbox = image.getchannel("A").getbbox()
    if alpha_bbox is None:
        raise ValueError(f"No visible pixels in {args.input}")
    sprite = image.crop(alpha_bbox)
    scale = min(args.box_width / sprite.width, args.box_height / sprite.height)
    target_size = (
        max(1, round(sprite.width * scale)),
        max(1, round(sprite.height * scale)),
    )
    sprite = sprite.resize(target_size, Image.Resampling.LANCZOS)

    canvas = Image.new(
        "RGBA", (args.canvas_width, args.canvas_height), (0, 0, 0, 0)
    )
    left = round(args.center_x - sprite.width / 2)
    top = round(args.center_y - sprite.height / 2)
    if left < 0 or top < 0 or left + sprite.width > canvas.width or top + sprite.height > canvas.height:
        raise ValueError(
            f"Registered sprite exceeds canvas: position={(left, top)}, size={sprite.size}, canvas={canvas.size}"
        )
    canvas.alpha_composite(sprite, (left, top))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(args.out)
    print(
        {
            "input_bbox": alpha_bbox,
            "canvas": canvas.size,
            "output_bbox": canvas.getchannel("A").getbbox(),
        }
    )


if __name__ == "__main__":
    main()
