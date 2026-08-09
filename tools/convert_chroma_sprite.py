"""Convert an ImageGen magenta-key sprite into a centered transparent PNG."""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--width", type=int, required=True)
    parser.add_argument("--height", type=int, required=True)
    parser.add_argument("--margin", type=int, default=15)
    args = parser.parse_args()

    rgb = np.asarray(Image.open(args.input).convert("RGB"))
    red, green, blue = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    # The generated key can range from hot pink to pale pink. It is always
    # red/blue-dominant; cream, gold, and white game artwork is not.
    key = (red > 180) & (blue > 160) & (green.astype(np.int16) + 80 < np.minimum(red, blue))
    rgba = Image.fromarray(np.dstack((rgb, np.where(key, 0, 255).astype(np.uint8))), "RGBA")
    bbox = rgba.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("No non-key pixels were found")
    sprite = rgba.crop(bbox)
    max_width = args.width - args.margin * 2
    max_height = args.height - args.margin * 2
    scale = min(max_width / sprite.width, max_height / sprite.height)
    size = (max(1, round(sprite.width * scale)), max(1, round(sprite.height * scale)))
    sprite = sprite.resize(size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (args.width, args.height), (0, 0, 0, 0))
    canvas.alpha_composite(sprite, ((args.width - sprite.width) // 2, (args.height - sprite.height) // 2))
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out)
    print({"source_bbox": bbox, "output_size": canvas.size, "output_bbox": canvas.getchannel("A").getbbox()})


if __name__ == "__main__":
    main()
