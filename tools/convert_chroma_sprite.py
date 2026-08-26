"""Convert an ImageGen magenta-key sprite into a centered transparent PNG."""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image


def _border_connected(mask: np.ndarray) -> np.ndarray:
    """Keep only key-colored pixels connected to the canvas edge.

    A green-screen asset can legitimately contain mint-green equipment panels
    and indicator lights.  Restricting the key to the outer connected region
    prevents those details from being punched out.
    """
    height, width = mask.shape
    connected = np.zeros_like(mask, dtype=bool)
    queue: deque[tuple[int, int]] = deque()

    for x in range(width):
        if mask[0, x]:
            connected[0, x] = True
            queue.append((0, x))
        if mask[height - 1, x] and not connected[height - 1, x]:
            connected[height - 1, x] = True
            queue.append((height - 1, x))
    for y in range(1, height - 1):
        if mask[y, 0] and not connected[y, 0]:
            connected[y, 0] = True
            queue.append((y, 0))
        if mask[y, width - 1] and not connected[y, width - 1]:
            connected[y, width - 1] = True
            queue.append((y, width - 1))

    while queue:
        y, x = queue.popleft()
        for next_y, next_x in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if (
                0 <= next_y < height
                and 0 <= next_x < width
                and mask[next_y, next_x]
                and not connected[next_y, next_x]
            ):
                connected[next_y, next_x] = True
                queue.append((next_y, next_x))
    return connected


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
        # Key only the highly saturated screen green.  ProjectCake equipment
        # itself uses mint and ink-green panels, so a merely green-dominant
        # pixel must remain visible.
        green_i = green.astype(np.int16)
        key = (
            (green_i > 200)
            & (green_i > red.astype(np.int16) + 150)
            & (green_i > blue.astype(np.int16) + 150)
        )
    else:
        # The generated key can range from hot pink to pale pink. It is always
        # red/blue-dominant; cream, gold, and white game artwork is not.
        key = (red > 180) & (blue > 160) & (green.astype(np.int16) + 80 < np.minimum(red, blue))
    if args.key_color == "green":
        key = _border_connected(key)
        # Pull in the narrow, green-contaminated antialiasing fringe that can
        # surround a generated silhouette, without touching isolated green
        # controls or body panels.
        fringe_candidate = (
            (green_i > 180)
            & (red.astype(np.int16) < 110)
            & (blue.astype(np.int16) < 110)
        )
        near_key = key.copy()
        for _ in range(4):
            padded = np.pad(near_key, 1)
            near_key = (
                padded[:-2, :-2]
                | padded[:-2, 1:-1]
                | padded[:-2, 2:]
                | padded[1:-1, :-2]
                | padded[1:-1, 2:]
                | padded[2:, :-2]
                | padded[2:, 1:-1]
                | padded[2:, 2:]
            )
        key |= fringe_candidate & near_key
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
            fringe = (
                (aa > 0)
                & (gg > 200)
                & (gg > rr + 150)
                & (gg > bb + 150)
            )
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
