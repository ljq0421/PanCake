#!/usr/bin/env python3
"""Remove nearly-invisible chroma-key fringe left after alpha extraction."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def is_chroma_key(red: int, green: int, blue: int) -> bool:
    green_key = red < 40 and green > 230 and blue < 40
    # Compressed ImageGen magenta keys can fade to muted purple at the edge.
    magenta_key = red > 80 and blue > 40 and green + 30 < min(red, blue)
    return green_key or magenta_key


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="+", type=Path)
    parser.add_argument("--max-alpha", type=int, default=8)
    args = parser.parse_args()
    for path in args.paths:
        image = Image.open(path).convert("RGBA")
        pixels = image.load()
        changed = 0
        for y in range(image.height):
            for x in range(image.width):
                red, green, blue, alpha = pixels[x, y]
                if alpha <= args.max_alpha and is_chroma_key(red, green, blue):
                    pixels[x, y] = (0, 0, 0, 0)
                    changed += 1
        image.save(path)
        print(f"{path}: removed {changed} low-alpha key pixels")


if __name__ == "__main__":
    main()
