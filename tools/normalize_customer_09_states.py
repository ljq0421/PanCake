"""Restore customer_09 state geometry and lock garment colors to neutral v4.

Only opaque coral-blouse and indigo-lower-garment pixels are adjusted. Skin,
hair, linework, props, facial features, and antialiased transparent edges are
left unchanged.
"""

from __future__ import annotations

import colorsys
import statistics
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
CUSTOMER_DIR = ROOT / "resources" / "art" / "customers" / "customer_09"
NEUTRAL_PATH = CUSTOMER_DIR / "customer_09_neutral_v4_chinese.png"

CONTRACTS = {
    "impatient": ((1536, 1024), (541, 76, 438, 883)),
    "satisfied": ((1536, 1024), (541, 76, 438, 883)),
    "accepting_bag": ((1536, 1024), (528, 60, 457, 947)),
    "paying_coins": ((1530, 1028), (450, 67, 640, 910)),
}


def _geometry_normalize(image: Image.Image, canvas: tuple[int, int], rect: tuple[int, int, int, int]) -> Image.Image:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("Generated state has no visible pixels")
    x, y, width, height = rect
    subject = image.crop(bbox).resize((width, height), Image.Resampling.LANCZOS)
    output = Image.new("RGBA", canvas, (0, 0, 0, 0))
    output.alpha_composite(subject, (x, y))
    return output


def _garment_name(pixel: tuple[int, int, int, int], y: int, rect: tuple[int, int, int, int]) -> str | None:
    red, green, blue, alpha = pixel
    if alpha < 220:
        return None
    _, top, _, height = rect
    hue, saturation, value = colorsys.rgb_to_hsv(red / 255.0, green / 255.0, blue / 255.0)
    relative_y = (y - top) / max(height, 1)
    if 0.25 <= relative_y <= 0.72 and (hue <= 0.065 or hue >= 0.985) and saturation >= 0.45 and red > green * 1.72:
        return "blouse"
    if relative_y >= 0.54 and 0.54 <= hue <= 0.72 and saturation >= 0.34 and 0.12 <= value <= 0.78:
        return "lower_garment"
    return None


def _palettes(image: Image.Image, rect: tuple[int, int, int, int]) -> dict[str, tuple[float, float, float]]:
    values: dict[str, list[tuple[float, float, float]]] = {"blouse": [], "lower_garment": []}
    for y in range(image.height):
        for x in range(image.width):
            pixel = image.getpixel((x, y))
            garment = _garment_name(pixel, y, rect)
            if garment is None:
                continue
            red, green, blue, _ = pixel
            values[garment].append(colorsys.rgb_to_hsv(red / 255.0, green / 255.0, blue / 255.0))
    result = {}
    for garment, samples in values.items():
        if not samples:
            raise ValueError(f"No {garment} pixels found")
        result[garment] = tuple(statistics.median(sample[index] for sample in samples) for index in range(3))
    return result


def _clamp(value: float) -> float:
    return max(0.0, min(1.0, value))


def _palette_normalize(image: Image.Image, rect: tuple[int, int, int, int], target: dict[str, tuple[float, float, float]]) -> tuple[Image.Image, dict[str, tuple[float, float, float]], dict[str, int]]:
    source = _palettes(image, rect)
    counts = {"blouse": 0, "lower_garment": 0}
    output = image.copy()
    for y in range(image.height):
        for x in range(image.width):
            pixel = image.getpixel((x, y))
            garment = _garment_name(pixel, y, rect)
            if garment is None:
                continue
            red, green, blue, alpha = pixel
            hue, saturation, value = colorsys.rgb_to_hsv(red / 255.0, green / 255.0, blue / 255.0)
            source_h, source_s, source_v = source[garment]
            target_h, target_s, target_v = target[garment]
            hue = (hue + target_h - source_h) % 1.0
            saturation = _clamp(saturation * target_s / max(source_s, 0.001))
            value = _clamp(value * target_v / max(source_v, 0.001))
            new_red, new_green, new_blue = colorsys.hsv_to_rgb(hue, saturation, value)
            output.putpixel((x, y), (round(new_red * 255), round(new_green * 255), round(new_blue * 255), alpha))
            counts[garment] += 1
    return output, source, counts


def _clear_residual_key(image: Image.Image) -> int:
    """Clear only near-invisible magenta key pixels introduced by resizing."""
    cleared = 0
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = image.getpixel((x, y))
            if 0 < alpha <= 2 and red > 240 and green < 16 and blue > 240:
                image.putpixel((x, y), (0, 0, 0, 0))
                cleared += 1
    return cleared


def main() -> None:
    neutral = Image.open(NEUTRAL_PATH).convert("RGBA")
    neutral_rect = (540, 75, 439, 884)
    target = _palettes(neutral, neutral_rect)
    print(f"neutral target: {target}")
    for state, (canvas, rect) in CONTRACTS.items():
        path = CUSTOMER_DIR / f"customer_09_{state}_v4_chinese.png"
        image = Image.open(path).convert("RGBA")
        normalized = _geometry_normalize(image, canvas, rect)
        normalized, source, counts = _palette_normalize(normalized, rect, target)
        cleared = _clear_residual_key(normalized)
        normalized.save(path, optimize=True)
        print(f"{state}: {source} -> {target}; pixels={counts}; canvas={canvas}; rect={rect}; key_pixels_cleared={cleared}")


if __name__ == "__main__":
    main()
