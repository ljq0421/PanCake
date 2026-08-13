"""Normalize customer_04 action states to the approved neutral palette/Atlas contract."""

from __future__ import annotations

import argparse
import colorsys
import statistics
from pathlib import Path

from PIL import Image


NAVY_RANGE = ((0.52, 0.68), (0.25, 0.90), (0.18, 0.72))
BRICK_RANGE = ((0.02, 0.11), (0.50, 1.00), (0.35, 0.82))
CANVAS_SIZE = (1535, 1024)
PANTS_Y_MIN = 880
PANTS_X_RANGE = (540, 1000)


def _matches(hsv: tuple[float, float, float], ranges: tuple[tuple[float, float], ...]) -> bool:
	return all(low <= value <= high for value, (low, high) in zip(hsv, ranges))


def _palette(image: Image.Image, ranges: tuple[tuple[float, float], ...], pants_only: bool) -> tuple[float, float, float]:
	values: list[tuple[float, float, float]] = []
	for y in range(image.height):
		if pants_only and y < PANTS_Y_MIN:
			continue
		for x in range(image.width):
			if pants_only and not (PANTS_X_RANGE[0] <= x < PANTS_X_RANGE[1]):
				continue
			red, green, blue, alpha = image.getpixel((x, y))
			if alpha < 220:
				continue
			hsv = colorsys.rgb_to_hsv(red / 255.0, green / 255.0, blue / 255.0)
			if _matches(hsv, ranges):
				values.append(hsv)
	if not values:
		raise ValueError("No matching garment pixels found")
	return tuple(statistics.median(value[index] for value in values) for index in range(3))


def _clamp(value: float) -> float:
	return max(0.0, min(1.0, value))


def _adjust(hsv: tuple[float, float, float], source: tuple[float, float, float], target: tuple[float, float, float]) -> tuple[int, int, int]:
	hue, saturation, value = hsv
	hue = (hue + target[0] - source[0]) % 1.0
	saturation = _clamp(saturation * target[1] / max(source[1], 0.001))
	value = _clamp(value * target[2] / max(source[2], 0.001))
	red, green, blue = colorsys.hsv_to_rgb(hue, saturation, value)
	return round(red * 255), round(green * 255), round(blue * 255)


def normalize(reference_path: Path, source_path: Path, output_path: Path, box: tuple[int, int, int, int]) -> None:
	reference = Image.open(reference_path).convert("RGBA")
	source = Image.open(source_path).convert("RGBA")
	alpha_box = source.getchannel("A").getbbox()
	if alpha_box is None:
		raise ValueError("Source has empty alpha")
	x, y, width, height = box
	subject = source.crop(alpha_box).resize((width, height), Image.Resampling.LANCZOS)
	image = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
	image.alpha_composite(subject, (x, y))

	palettes = {
		"navy": (_palette(image, NAVY_RANGE, False), _palette(reference, NAVY_RANGE, False)),
		"brick": (_palette(image, BRICK_RANGE, True), _palette(reference, BRICK_RANGE, True)),
	}
	pixels: list[tuple[int, int, int, int]] = []
	for py in range(image.height):
		for px in range(image.width):
			red, green, blue, alpha = image.getpixel((px, py))
			if alpha <= 1 and red > 200 and blue > 180 and green < 90:
				pixels.append((0, 0, 0, 0))
				continue
			if alpha < 220:
				pixels.append((red, green, blue, alpha))
				continue
			hsv = colorsys.rgb_to_hsv(red / 255.0, green / 255.0, blue / 255.0)
			if _matches(hsv, NAVY_RANGE):
				red, green, blue = _adjust(hsv, *palettes["navy"])
			elif py >= PANTS_Y_MIN and PANTS_X_RANGE[0] <= px < PANTS_X_RANGE[1] and _matches(hsv, BRICK_RANGE):
				red, green, blue = _adjust(hsv, *palettes["brick"])
			pixels.append((red, green, blue, alpha))
	image.putdata(pixels)
	output_path.parent.mkdir(parents=True, exist_ok=True)
	image.save(output_path)
	print(f"source_alpha_box={alpha_box} target_box={(x, y, width, height)} final_alpha_box={image.getchannel('A').getbbox()}")
	print(f"palettes={palettes}")


def main() -> None:
	parser = argparse.ArgumentParser()
	parser.add_argument("--reference", type=Path, required=True)
	parser.add_argument("--source", type=Path, required=True)
	parser.add_argument("--out", type=Path, required=True)
	parser.add_argument("--box", required=True, help="x,y,width,height")
	args = parser.parse_args()
	box = tuple(int(value) for value in args.box.split(","))
	if len(box) != 4:
		raise ValueError("--box must contain x,y,width,height")
	normalize(args.reference, args.source, args.out, box)


if __name__ == "__main__":
	main()
