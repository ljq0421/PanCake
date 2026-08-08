"""Build a heated drink sprite without changing its room-temperature artwork.

The generated reference supplies only the steam; the package pixels are copied
from the room-temperature source unchanged.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--package", required=True)
    parser.add_argument("--steam-source", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--crop", nargs=4, type=int, required=True, metavar=("L", "T", "R", "B"))
    parser.add_argument("--steam-size", nargs=2, type=int, required=True, metavar=("W", "H"))
    parser.add_argument("--position", nargs=2, type=int, required=True, metavar=("X", "Y"))
    args = parser.parse_args()

    package = Image.open(args.package).convert("RGBA")
    generated = np.asarray(Image.open(args.steam_source).convert("RGB"))
    left, top, right, bottom = args.crop
    steam_rgb = generated[top:bottom, left:right]

    # ImageGen's requested magenta background varies slightly after encoding.
    # Retain every non-magenta steam pixel, including antialiased gold edges.
    red, green, blue = steam_rgb[:, :, 0], steam_rgb[:, :, 1], steam_rgb[:, :, 2]
    # The flat key can become pale pink at the generated edge.  It remains
    # strongly red/blue-dominant, unlike the cream/yellow steam.
    key = (red > 180) & (blue > 160) & (green.astype(np.int16) + 80 < np.minimum(red, blue))
    steam_alpha = np.where(key, 0, 255).astype(np.uint8)
    steam = Image.fromarray(np.dstack((steam_rgb, steam_alpha)), "RGBA")
    steam = steam.resize(tuple(args.steam_size), Image.Resampling.LANCZOS)
    package.alpha_composite(steam, tuple(args.position))

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    package.save(out)


if __name__ == "__main__":
    main()
