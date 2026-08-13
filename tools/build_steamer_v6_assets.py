#!/usr/bin/env python3
"""Build same-width ProjectCake steamer v6 assets and visual audit artifacts."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


CANVAS_SIZE = (1024, 1536)
SUBJECT_WIDTH = 690
SUBJECT_MAX_HEIGHT = 1504
SUBJECT_BOTTOM = 1520
TIERS = (1, 2, 3)
STATES = ("closed", "open")


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
	bbox = image.getchannel("A").getbbox()
	if bbox is None:
		raise ValueError("image has no visible subject")
	return bbox


def load_subject(path: Path) -> tuple[Image.Image, tuple[int, int, int, int]]:
	image = Image.open(path).convert("RGBA")
	bbox = alpha_bbox(image)
	return image.crop(bbox), bbox


def union_bbox(boxes: list[tuple[int, int, int, int]], padding: int = 8) -> tuple[int, int, int, int]:
	left = max(min(box[0] for box in boxes) - padding, 0)
	top = max(min(box[1] for box in boxes) - padding, 0)
	right = min(max(box[2] for box in boxes) + padding, CANVAS_SIZE[0])
	bottom = min(max(box[3] for box in boxes) + padding, CANVAS_SIZE[1])
	return left, top, right, bottom


def magenta_residual(image: Image.Image) -> int:
	return sum(
		1
		for red, green, blue, alpha in image.getdata()
		if alpha > 0 and red > 180 and blue > 130 and min(red, blue) - green > 60
	)


def clear_magenta_residue(image: Image.Image) -> None:
	pixels = image.load()
	for y in range(image.height):
		for x in range(image.width):
			red, green, blue, alpha = pixels[x, y]
			if alpha > 0 and red > 180 and blue > 130 and min(red, blue) - green > 60:
				pixels[x, y] = (0, 0, 0, 0)


def normalize_pair(source_dir: Path, output_dir: Path, tier: int) -> dict[str, object]:
	subjects: dict[str, Image.Image] = {}
	source_bounds: dict[str, tuple[int, int, int, int]] = {}
	for state in STATES:
		subjects[state], source_bounds[state] = load_subject(source_dir / f"tier_{tier}_{state}.png")

	normalized: dict[str, Image.Image] = {}
	state_scales: dict[str, float] = {}
	for state, subject in subjects.items():
		# Normalize every state to the same authored width. This is intentional:
		# higher tiers are allowed to grow upward instead of shrinking to fit a
		# fixed-height icon box, and generated open-state padding cannot narrow it.
		scale = min(SUBJECT_WIDTH / subject.width, SUBJECT_MAX_HEIGHT / subject.height)
		state_scales[state] = scale
		resized = subject.resize(
			(max(1, round(subject.width * scale)), max(1, round(subject.height * scale))),
			Image.Resampling.LANCZOS,
		)
		clear_magenta_residue(resized)
		canvas = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
		position = ((CANVAS_SIZE[0] - resized.width) // 2, SUBJECT_BOTTOM - resized.height)
		canvas.alpha_composite(resized, position)
		normalized[state] = canvas

	pair_bounds = union_bbox([alpha_bbox(image) for image in normalized.values()])
	entry: dict[str, object] = {"tier": tier, "pair_bounds": list(pair_bounds), "state_scales": state_scales, "states": {}}
	output_dir.mkdir(parents=True, exist_ok=True)
	for state, image in normalized.items():
		output_path = output_dir / f"steamer_tier_{tier}_{state}_five_area_v6_chinese.png"
		image.save(output_path, optimize=True)
		alpha = image.getchannel("A")
		entry["states"][state] = {
			"path": output_path.as_posix(),
			"canvas_size": list(image.size),
			"source_bounds": list(source_bounds[state]),
			"normalized_bounds": list(alpha_bbox(image)),
			"corner_alpha": [alpha.getpixel((0, 0)), alpha.getpixel((1023, 0)), alpha.getpixel((0, 1535)), alpha.getpixel((1023, 1535))],
			"magenta_residual_pixels": magenta_residual(image),
			"sha256": hashlib.sha256(image.tobytes()).hexdigest(),
		}
	return entry


def font(size: int) -> ImageFont.ImageFont:
	for candidate in (Path("C:/Windows/Fonts/msyh.ttc"), Path("C:/Windows/Fonts/simhei.ttf")):
		if candidate.exists():
			return ImageFont.truetype(str(candidate), size=size)
	return ImageFont.load_default()


def render_contact_sheet(output_dir: Path, audit: dict[str, object], path: Path) -> None:
	sheet = Image.new("RGB", (1200, 860), "#203238")
	draw = ImageDraw.Draw(sheet)
	draw.text((36, 22), "ProjectCake 蒸笼 v6 · 同宽升级预览", fill="#fff3d0", font=font(30))
	draw.text((36, 62), "每列：1层 / 2层 / 4层；上排闭盖，下排开盖", fill="#b9d9d5", font=font(16))
	entries = {int(entry["tier"]): entry for entry in audit["tiers"]}
	for column, tier in enumerate(TIERS):
		entry = entries[tier]
		left, top, right, bottom = entry["pair_bounds"]
		for row, state in enumerate(STATES):
			panel_x, panel_y = 36 + column * 386, 104 + row * 356
			draw.rounded_rectangle((panel_x, panel_y, panel_x + 356, panel_y + 316), radius=18, fill="#f7eac4", outline="#9b7041", width=4)
			draw.text((panel_x + 18, panel_y + 14), f"T{tier} · {'闭盖' if state == 'closed' else '开盖'}", fill="#55351f", font=font(22))
			source = Image.open(output_dir / f"steamer_tier_{tier}_{state}_five_area_v6_chinese.png").convert("RGBA").crop((left, top, right, bottom))
			source.thumbnail((318, 244), Image.Resampling.LANCZOS)
			sheet.paste(source, (panel_x + (356 - source.width) // 2, panel_y + 68 + (238 - source.height)), source)
	path.parent.mkdir(parents=True, exist_ok=True)
	sheet.save(path, optimize=True)


def main() -> int:
	parser = argparse.ArgumentParser()
	parser.add_argument("--source-dir", type=Path, required=True)
	parser.add_argument("--output-dir", type=Path, required=True)
	parser.add_argument("--audit", type=Path, required=True)
	parser.add_argument("--contact-sheet", type=Path, required=True)
	args = parser.parse_args()
	audit: dict[str, object] = {"asset_family": "steamer_v6_chinese", "canvas_size": list(CANVAS_SIZE), "tier_capacities": {"1": 1, "2": 2, "3": 4}, "tiers": []}
	for tier in TIERS:
		audit["tiers"].append(normalize_pair(args.source_dir, args.output_dir, tier))
	args.audit.parent.mkdir(parents=True, exist_ok=True)
	args.audit.write_text(json.dumps(audit, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
	render_contact_sheet(args.output_dir, audit, args.contact_sheet)
	print(json.dumps(audit, ensure_ascii=False, indent=2))
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
