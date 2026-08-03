from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ORIGINAL = ROOT / "resources/art/workstation/background/workstation_backplate_v1.png"
EDITED_SOURCE = ROOT / "tmp/imagegen/ingredient_stock/backplate/workstation_backplate_v2_imagegen_source.png"
OUTPUT = ROOT / "resources/art/workstation/background/workstation_backplate_v2.png"


def main() -> None:
    original = Image.open(ORIGINAL).convert("RGBA")
    edited = Image.open(EDITED_SOURCE).convert("RGBA")
    if edited.size != original.size:
        width_drift = abs(edited.width - original.width)
        height_drift = abs(edited.height - original.height)
        if width_drift > 2 or height_drift > 2:
            raise SystemExit(f"backplate size drift: {edited.size} != {original.size}")
        edited = edited.resize(original.size, Image.Resampling.LANCZOS)

    # Use the generated reconstruction only where the napkin box and chopstick
    # holder existed. Everything outside this feathered area remains byte-for-byte
    # sourced from the approved v1 backplate.
    mask = Image.new("L", original.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((45, 282, 320, 492), radius=20, fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(5.0))
    output = Image.composite(edited, original, mask)
    output.save(OUTPUT)

    unchanged_mask = ImageChops.invert(mask).point(lambda value: 255 if value == 255 else 0)
    outside_diff = ImageChops.difference(output.convert("RGB"), original.convert("RGB"))
    outside_only = Image.composite(
        outside_diff, Image.new("RGB", original.size, (0, 0, 0)), unchanged_mask
    )
    if outside_only.getbbox() is not None:
        raise SystemExit("pixels outside the edit mask changed")
    print("WORKSTATION_BACKPLATE_V2_BUILD_PASS")


if __name__ == "__main__":
    main()
