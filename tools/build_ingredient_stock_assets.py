from __future__ import annotations

import argparse
import hashlib
import math
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
INGREDIENT_ROOT = ROOT / "resources" / "art" / "ingredients"
RESTOCK_ROOT = ROOT / "resources" / "art" / "workstation" / "restock"
CANVAS_SIZE = 512
MAX_QUANTITY = 14
OUTPUT_VERSION = "v2"

UNIT_SOURCES = {
    "egg": {
        "path": INGREDIENT_ROOT / "egg" / "stock" / "egg_stock_1_v1.png",
        "maximum_size": (126, 178),
    },
    "baocui": {
        "path": INGREDIENT_ROOT / "baocui" / "stock" / "baocui_stock_1_v1.png",
        "maximum_size": (238, 190),
    },
    "ham_sausage": {
        "path": INGREDIENT_ROOT / "ham_sausage" / "stock" / "ham_sausage_stock_1_v1.png",
        "maximum_size": (180, 190),
    },
    "scallion": {
        "path": INGREDIENT_ROOT / "scallion" / "stock" / "scallion_stock_1_v1.png",
        "maximum_size": (140, 110),
    },
    "meat_floss": {
        "path": INGREDIENT_ROOT / "meat_floss" / "meat_floss_pile_v1_five_area_v2.png",
        "maximum_size": (180, 110),
    },
    "pork_tenderloin": {
        "path": INGREDIENT_ROOT / "pork_tenderloin" / "pork_tenderloin_portion_v1_five_area_v2.png",
        "maximum_size": (190, 120),
    },
    "coriander": {
        "path": INGREDIENT_ROOT / "coriander" / "coriander_pile_five_area_v2.png",
        "maximum_size": (180, 120),
    },
    "preserved_mustard": {
        "path": INGREDIENT_ROOT / "preserved_mustard" / "preserved_mustard_pile_five_area_v2.png",
        "maximum_size": (180, 135),
    },
}

CONTAINERS = {
    "egg_carton_v1.png": ROOT / "tmp" / "imagegen" / "ingredient_stock" / "alpha" / "egg_carton_alpha.png",
    "baocui_tin_v1.png": ROOT / "tmp" / "imagegen" / "ingredient_stock" / "alpha" / "baocui_tin_alpha.png",
    "ham_fresh_box_v1.png": ROOT / "tmp" / "imagegen" / "ingredient_stock" / "alpha" / "ham_fresh_box_alpha.png",
    "scallion_enamel_jar_v1.png": ROOT / "tmp" / "imagegen" / "ingredient_stock" / "alpha" / "scallion_enamel_jar_alpha.png",
}


def _visible_subject(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    bounds = rgba.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError("stock unit source contains no visible subject")
    return rgba.crop(bounds)


def _row_counts(quantity: int) -> list[int]:
    row_count = math.ceil(quantity / 4)
    base = quantity // row_count
    larger_rows = quantity % row_count
    return [base] * (row_count - larger_rows) + [base + 1] * larger_rows


def _state_layout(quantity: int) -> tuple[list[tuple[int, int]], int, int]:
    row_counts = _row_counts(quantity)
    rows = len(row_counts)
    max_columns = max(row_counts)
    if rows == 1:
        y_positions = [CANVAS_SIZE // 2]
    else:
        top = 70
        bottom = CANVAS_SIZE - 70
        y_positions = [round(top + index * (bottom - top) / (rows - 1)) for index in range(rows)]
    positions: list[tuple[int, int]] = []
    for row_index, columns in enumerate(row_counts):
        cell_width = 400 / columns
        start_x = CANVAS_SIZE / 2 - cell_width * (columns - 1) / 2
        positions.extend((round(start_x + index * cell_width), y_positions[row_index]) for index in range(columns))
    cell_width = round(400 / max_columns)
    cell_height = 360 if rows == 1 else round(360 / rows)
    return positions, cell_width, cell_height


def _compose_state(source: Image.Image, quantity: int, maximum_size: tuple[int, int]) -> Image.Image:
    positions, cell_width, cell_height = _state_layout(quantity)
    subject = _visible_subject(source)
    target_width = min(maximum_size[0], round(cell_width * 0.78))
    target_height = min(maximum_size[1], round(cell_height * 0.78))
    scale = min(target_width / subject.width, target_height / subject.height)
    unit = subject.resize(
        (max(1, round(subject.width * scale)), max(1, round(subject.height * scale))),
        Image.Resampling.LANCZOS,
    )
    canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    for center_x, center_y in positions:
        canvas.alpha_composite(unit, (center_x - unit.width // 2, center_y - unit.height // 2))
    return canvas


def _fit_canvas(image: Image.Image, maximum_subject_size: int = 448) -> Image.Image:
    subject = _visible_subject(image)
    scale = min(maximum_subject_size / subject.width, maximum_subject_size / subject.height)
    size = (max(1, round(subject.width * scale)), max(1, round(subject.height * scale)))
    subject = subject.resize(size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(subject, ((CANVAS_SIZE - size[0]) // 2, (CANVAS_SIZE - size[1]) // 2))
    return canvas


def _count_large_alpha_components(image: Image.Image, minimum_pixels: int = 80) -> int:
    alpha = image.convert("RGBA").getchannel("A")
    width, height = alpha.size
    active = bytearray(1 if value > 32 else 0 for value in alpha.tobytes())
    visited = bytearray(width * height)
    large_components = 0
    for start, is_active in enumerate(active):
        if not is_active or visited[start]:
            continue
        stack = [start]
        visited[start] = 1
        size = 0
        while stack:
            index = stack.pop()
            size += 1
            x = index % width
            y = index // width
            neighbors = []
            if x > 0:
                neighbors.append(index - 1)
            if x + 1 < width:
                neighbors.append(index + 1)
            if y > 0:
                neighbors.append(index - width)
            if y + 1 < height:
                neighbors.append(index + width)
            for neighbor in neighbors:
                if active[neighbor] and not visited[neighbor]:
                    visited[neighbor] = 1
                    stack.append(neighbor)
        if size >= minimum_pixels:
            large_components += 1
    return large_components


def _stock_path(ingredient_id: str, quantity: int) -> Path:
    return INGREDIENT_ROOT / ingredient_id / "stock" / f"{ingredient_id}_stock_{quantity}_{OUTPUT_VERSION}.png"


def build() -> None:
    for ingredient_id, configuration in UNIT_SOURCES.items():
        source_path = Path(configuration["path"])
        if not source_path.is_file():
            raise FileNotFoundError(source_path)
        source = Image.open(source_path).convert("RGBA")
        output_dir = INGREDIENT_ROOT / ingredient_id / "stock"
        output_dir.mkdir(parents=True, exist_ok=True)
        for quantity in range(1, MAX_QUANTITY + 1):
            _compose_state(source, quantity, configuration["maximum_size"]).save(
                _stock_path(ingredient_id, quantity)
            )

    RESTOCK_ROOT.mkdir(parents=True, exist_ok=True)
    for filename, source_path in CONTAINERS.items():
        if source_path.is_file():
            _fit_canvas(Image.open(source_path)).save(RESTOCK_ROOT / filename)


def check() -> None:
    errors: list[str] = []
    for ingredient_id in UNIT_SOURCES:
        hashes: set[str] = set()
        for quantity in range(1, MAX_QUANTITY + 1):
            path = _stock_path(ingredient_id, quantity)
            if not path.is_file():
                errors.append(f"missing: {path.relative_to(ROOT)}")
                continue
            image = Image.open(path).convert("RGBA")
            if image.size != (CANVAS_SIZE, CANVAS_SIZE):
                errors.append(f"wrong size: {path.relative_to(ROOT)} -> {image.size}")
            if image.getchannel("A").getbbox() is None:
                errors.append(f"empty alpha: {path.relative_to(ROOT)}")
            corners = [(0, 0), (511, 0), (0, 511), (511, 511)]
            if any(image.getpixel(point)[3] > 8 for point in corners):
                errors.append(f"opaque corner: {path.relative_to(ROOT)}")
            digest = hashlib.sha256(image.tobytes()).hexdigest()
            if digest in hashes:
                errors.append(f"duplicate quantity state: {path.relative_to(ROOT)}")
            hashes.add(digest)
            if ingredient_id in {"ham_sausage", "meat_floss"}:
                component_count = _count_large_alpha_components(image)
                if component_count != quantity:
                    errors.append(
                        f"wrong visible portion count: {path.relative_to(ROOT)} -> "
                        f"{component_count}, expected {quantity}"
                    )

    if errors:
        raise SystemExit("\n".join(errors))
    print("INGREDIENT_STOCK_ASSET_CHECK_PASS")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if not args.check:
        build()
    check()


if __name__ == "__main__":
    main()
