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
    parser.add_argument("--key-color", choices=("magenta", "green"), default="magenta")
    parser.add_argument(
        "--preserve-canvas",
        action="store_true",
        help="Remove the key while retaining the generated canvas composition.",
    )
    args = parser.parse_args()

    rgb = np.asarray(Image.open(args.input).convert("RGB")).copy()
    red, green, blue = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    if args.key_color == "green":
        # A saturated green screen is not present in the warm-toned food art.
        green_i = green.astype(np.int16)
        key = (green_i > 60) & (green_i > red.astype(np.int16) + 15) & (green_i > blue.astype(np.int16) + 15)
    else:
        # The generated key can range from hot pink to pale pink. It is always
        # red/blue-dominant; cream, gold, and white game artwork is not.
        key = (red > 180) & (blue > 160) & (green.astype(np.int16) + 80 < np.minimum(red, blue))
    # Clear keyed RGB as well as alpha before resampling, so the resize cannot
    # bleed green into the anti-aliased outline.
    rgb[key] = (0, 0, 0)
    rgba = Image.fromarray(np.dstack((rgb, np.where(key, 0, 255).astype(np.uint8))), "RGBA")
    if args.preserve_canvas:
        rgba = rgba.resize((args.width, args.height), Image.Resampling.LANCZOS)
        resized = np.asarray(rgba).copy()
        # A few partially transparent pixels can retain green after resize.
        # They are outside the warm orange/brown palette, so remove them too.
        if args.key_color == "green":
            rr, gg, bb, aa = (resized[:, :, i].astype(np.int16) for i in range(4))
            fringe = (aa > 0) & (gg > 60) & (gg > rr + 10) & (gg > bb + 10)
            resized[fringe] = (0, 0, 0, 0)
        rgba = Image.fromarray(resized, "RGBA")
        out = Path(args.out)
        out.parent.mkdir(parents=True, exist_ok=True)
        rgba.save(out)
        print({"output_size": rgba.size, "output_bbox": rgba.getchannel("A").getbbox()})
        return
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
