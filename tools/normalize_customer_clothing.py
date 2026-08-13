"""Measure and normalize the shirt/pants palette of customer PNG variants.

This intentionally adjusts only the opaque garment pixels in the specified HSV
ranges. The neutral art is the palette source; pose-specific linework and
shading remain intact.
"""

from __future__ import annotations

import argparse
import colorsys
import statistics
from pathlib import Path

from PIL import Image


GARMENTS = {
    "shirt": ((0.16, 0.34), (0.12, 0.75), (0.18, 0.90)),
    "pants": ((0.48, 0.65), (0.05, 0.65), (0.12, 0.70)),
}


def _matches(hsv: tuple[float, float, float], garment: str) -> bool:
    (min_h, max_h), (min_s, max_s), (min_v, max_v) = GARMENTS[garment]
    h, s, v = hsv
    return min_h <= h <= max_h and min_s <= s <= max_s and min_v <= v <= max_v


def _palette(image: Image.Image, garment: str) -> tuple[float, float, float]:
    pixels = []
    for red, green, blue, alpha in image.convert("RGBA").getdata():
        if alpha < 220:
            continue
        hsv = colorsys.rgb_to_hsv(red / 255, green / 255, blue / 255)
        if _matches(hsv, garment):
            pixels.append(hsv)
    if not pixels:
        raise ValueError(f"No {garment} pixels were found")
    return tuple(statistics.median(value[index] for value in pixels) for index in range(3))


def _clamp(value: float) -> float:
    return max(0.0, min(1.0, value))


def normalize(reference: Path, source: Path, output: Path) -> None:
    reference_image = Image.open(reference).convert("RGBA")
    image = Image.open(source).convert("RGBA")
    source_palettes = {garment: _palette(image, garment) for garment in GARMENTS}
    reference_palettes = {garment: _palette(reference_image, garment) for garment in GARMENTS}
    pixels = []
    for red, green, blue, alpha in image.getdata():
        if alpha < 220:
            pixels.append((red, green, blue, alpha))
            continue
        hsv = colorsys.rgb_to_hsv(red / 255, green / 255, blue / 255)
        garment = next((name for name in GARMENTS if _matches(hsv, name)), None)
        if garment is None:
            pixels.append((red, green, blue, alpha))
            continue
        input_h, input_s, input_v = source_palettes[garment]
        target_h, target_s, target_v = reference_palettes[garment]
        hue, saturation, value = hsv
        hue = _clamp(hue + target_h - input_h)
        saturation = _clamp(saturation * target_s / max(input_s, 0.001))
        value = _clamp(value * target_v / max(input_v, 0.001))
        new_red, new_green, new_blue = colorsys.hsv_to_rgb(hue, saturation, value)
        pixels.append((round(new_red * 255), round(new_green * 255), round(new_blue * 255), alpha))
    image.putdata(pixels)
    output.parent.mkdir(parents=True, exist_ok=True)
    image.save(output)
    print(f"{source.name}: {source_palettes} -> {reference_palettes}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    normalize(args.reference, args.source, args.out)


if __name__ == "__main__":
    main()
