from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def _alpha_bounds(image: Image.Image) -> tuple[int, int, int, int]:
    bounds = image.convert("RGBA").getchannel("A").getbbox()
    if bounds is None:
        raise ValueError("image contains no visible subject")
    return bounds


def normalize(source_path: Path, reference_path: Path, output_path: Path) -> None:
    source = Image.open(source_path).convert("RGBA")
    reference = Image.open(reference_path).convert("RGBA")
    source_bounds = _alpha_bounds(source)
    reference_bounds = _alpha_bounds(reference)
    subject = source.crop(source_bounds)

    target_width = reference_bounds[2] - reference_bounds[0]
    target_height = reference_bounds[3] - reference_bounds[1]
    scale = min(target_width / subject.width, target_height / subject.height)
    resized = subject.resize(
        (max(1, round(subject.width * scale)), max(1, round(subject.height * scale))),
        Image.Resampling.LANCZOS,
    )

    canvas = Image.new("RGBA", reference.size, (0, 0, 0, 0))
    target_center_x = (reference_bounds[0] + reference_bounds[2]) // 2
    target_center_y = (reference_bounds[1] + reference_bounds[3]) // 2
    offset = (
        target_center_x - resized.width // 2,
        target_center_y - resized.height // 2,
    )
    canvas.alpha_composite(resized, offset)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output_path)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    normalize(args.source, args.reference, args.out)


if __name__ == "__main__":
    main()
