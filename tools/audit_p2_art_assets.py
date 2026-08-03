from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
TRANSPARENT_ASSETS = [
    ROOT / "resources/art/ingredients/meat_floss/meat_floss_pile_v1.png",
    ROOT / "resources/art/ingredients/meat_floss/meat_floss_scattered_v1.png",
    ROOT / "resources/art/ingredients/pork_tenderloin/pork_tenderloin_portion_v1.png",
    ROOT / "resources/art/ingredients/pork_tenderloin/pork_tenderloin_slices_v1.png",
    ROOT / "resources/art/ui/economy/currency_coin_v1.png",
    ROOT / "resources/art/ui/economy/reputation_v1.png",
    ROOT / "resources/art/ui/economy/upgrade_v1.png",
    ROOT / "resources/art/ui/day_summary/day_summary_panel_base_v1.png",
    ROOT / "resources/art/workstation/tools/batter_ladle_upgrade_v1.png",
    ROOT / "resources/art/workstation/tools/batter_spreader_upgrade_v1.png",
    ROOT / "resources/art/workstation/tools/folding_spatula_upgrade_v1.png",
    ROOT / "resources/art/workstation/tools/heat_controller_upgrade_v1.png",
    ROOT / "resources/art/workstation/tools/ingredient_tongs_upgrade_v1.png",
    ROOT / "resources/art/workstation/tools/oil_absorbent_paper_upgrade_v1.png",
    ROOT / "resources/art/workstation/tools/reinforced_paper_sleeve_upgrade_v1.png",
    ROOT / "resources/art/workstation/tools/sauce_brush_upgrade_v1.png",
]
OPAQUE_ASSETS = [
    ROOT / "resources/art/workstation/background/workstation_backplate_upgrade_v1.png",
]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def transparent_metrics(path: Path) -> dict[str, object]:
    image = Image.open(path).convert("RGBA")
    alpha = image.getchannel("A")
    histogram = alpha.histogram()
    pixel_count = image.width * image.height
    pixels = list(image.get_flattened_data())
    edge_nontransparent = sum(
        1
        for x in range(image.width)
        if alpha.getpixel((x, 0)) or alpha.getpixel((x, image.height - 1))
    ) + sum(
        1
        for y in range(1, image.height - 1)
        if alpha.getpixel((0, y)) or alpha.getpixel((image.width - 1, y))
    )
    key_residual = sum(
        1
        for red, green, blue, value in pixels
        if value > 0
        and (
            (green > 180 and red < 110 and blue < 110)
            or (red > 180 and blue > 180 and green < 110)
        )
    )
    return {
        "file": path.relative_to(ROOT).as_posix(),
        "size": image.size,
        "mode": "RGBA",
        "bbox": alpha.getbbox(),
        "transparent_ratio": histogram[0] / pixel_count,
        "partial_ratio": sum(histogram[1:255]) / pixel_count,
        "opaque_ratio": histogram[255] / pixel_count,
        "edge_nontransparent": edge_nontransparent,
        "key_residual": key_residual,
        "sha256": sha256(path),
    }


def opaque_metrics(path: Path) -> dict[str, object]:
    image = Image.open(path)
    return {
        "file": path.relative_to(ROOT).as_posix(),
        "size": image.size,
        "mode": image.mode,
        "sha256": sha256(path),
    }


def main() -> None:
    missing = [path for path in TRANSPARENT_ASSETS + OPAQUE_ASSETS if not path.exists()]
    if missing:
        raise SystemExit("Missing P2 assets: " + ", ".join(str(path) for path in missing))

    transparent = [transparent_metrics(path) for path in TRANSPARENT_ASSETS]
    opaque = [opaque_metrics(path) for path in OPAQUE_ASSETS]
    base_size = Image.open(
        ROOT / "resources/art/workstation/background/workstation_backplate_v1.png"
    ).size

    failures: list[str] = []
    for result in transparent:
        if result["edge_nontransparent"] != 0:
            failures.append(f"{result['file']}: non-transparent canvas edge")
        if result["bbox"] is None:
            failures.append(f"{result['file']}: empty alpha subject")
        if result["key_residual"] != 0:
            failures.append(f"{result['file']}: chroma-key residual detected")
    if tuple(opaque[0]["size"]) != tuple(base_size):
        failures.append(
            "workstation_backplate_upgrade_v1.png: size does not match base backplate"
        )

    report = {
        "transparent": transparent,
        "opaque": opaque,
        "base_backplate_size": base_size,
        "failures": failures,
    }
    print(json.dumps(report, indent=2))
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
