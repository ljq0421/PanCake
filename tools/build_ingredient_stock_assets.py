from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ALPHA_ROOT = ROOT / "tmp" / "imagegen" / "ingredient_stock" / "alpha"
INGREDIENT_ROOT = ROOT / "resources" / "art" / "ingredients"
RESTOCK_ROOT = ROOT / "resources" / "art" / "workstation" / "restock"

ATLASES = {
    "egg": ALPHA_ROOT / "egg_stock_atlas_alpha.png",
    "baocui": ALPHA_ROOT / "baocui_stock_atlas_alpha.png",
    "ham_sausage": ALPHA_ROOT / "ham_stock_atlas_alpha.png",
    "scallion": ALPHA_ROOT / "scallion_stock_atlas_alpha.png",
}

CONTAINERS = {
    "egg_carton_v1.png": ALPHA_ROOT / "egg_carton_alpha.png",
    "baocui_tin_v1.png": ALPHA_ROOT / "baocui_tin_alpha.png",
    "ham_fresh_box_v1.png": ALPHA_ROOT / "ham_fresh_box_alpha.png",
    "scallion_enamel_jar_v1.png": ALPHA_ROOT / "scallion_enamel_jar_alpha.png",
}

CANVAS_SIZE = 512


def _cell_edges(length: int, divisions: int) -> list[int]:
    return [round(index * length / divisions) for index in range(divisions + 1)]


def _fit_canvas(image: Image.Image, maximum_subject_size: int = 448) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError("generated asset contains no opaque subject")
    subject = rgba.crop(bounds)
    scale = min(maximum_subject_size / subject.width, maximum_subject_size / subject.height)
    size = (
        max(1, round(subject.width * scale)),
        max(1, round(subject.height * scale)),
    )
    subject = subject.resize(size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    offset = ((CANVAS_SIZE - size[0]) // 2, (CANVAS_SIZE - size[1]) // 2)
    canvas.alpha_composite(subject, offset)
    return canvas


def _remove_small_components(image: Image.Image) -> Image.Image:
    """Remove small cross-cell fragments left by generated atlases."""
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    width, height = rgba.size
    active = bytearray(1 if value > 16 else 0 for value in alpha.tobytes())
    visited = bytearray(width * height)
    components: list[list[int]] = []
    for start, is_active in enumerate(active):
        if not is_active or visited[start]:
            continue
        stack = [start]
        visited[start] = 1
        component: list[int] = []
        while stack:
            index = stack.pop()
            component.append(index)
            x = index % width
            y = index // width
            if x > 0:
                neighbor = index - 1
                if active[neighbor] and not visited[neighbor]:
                    visited[neighbor] = 1
                    stack.append(neighbor)
            if x + 1 < width:
                neighbor = index + 1
                if active[neighbor] and not visited[neighbor]:
                    visited[neighbor] = 1
                    stack.append(neighbor)
            if y > 0:
                neighbor = index - width
                if active[neighbor] and not visited[neighbor]:
                    visited[neighbor] = 1
                    stack.append(neighbor)
            if y + 1 < height:
                neighbor = index + width
                if active[neighbor] and not visited[neighbor]:
                    visited[neighbor] = 1
                    stack.append(neighbor)
        components.append(component)
    if not components:
        return rgba
    largest = max(len(component) for component in components)
    alpha_values = bytearray(alpha.tobytes())
    for component in components:
        if len(component) >= largest * 0.08:
            continue
        for index in component:
            alpha_values[index] = 0
    rgba.putalpha(Image.frombytes("L", rgba.size, bytes(alpha_values)))
    return rgba


def _build_baocui_states(atlas: Image.Image, output_dir: Path) -> None:
    x_edges = _cell_edges(atlas.width, 3)
    y_edges = _cell_edges(atlas.height, 2)
    single = atlas.crop((x_edges[0], y_edges[0], x_edges[1], y_edges[1]))
    single = _remove_small_components(single)
    bounds = single.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError("baocui single-sheet source is empty")
    single = single.crop(bounds)
    scale = min(242 / single.width, 190 / single.height)
    single = single.resize(
        (round(single.width * scale), round(single.height * scale)),
        Image.Resampling.LANCZOS,
    )
    for quantity in range(1, 7):
        canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
        spacing = 42
        total_width = single.width + spacing * (quantity - 1)
        start_x = (CANVAS_SIZE - total_width) // 2
        for index in reversed(range(quantity)):
            angle = (index - (quantity - 1) * 0.5) * 2.4
            sheet = single.rotate(angle, Image.Resampling.BICUBIC, expand=True)
            x = start_x + index * spacing - (sheet.width - single.width) // 2
            y = (CANVAS_SIZE - sheet.height) // 2 + abs(index - (quantity - 1) * 0.5) * 2
            canvas.alpha_composite(sheet, (round(x), round(y)))
        canvas.save(output_dir / f"baocui_stock_{quantity}_v1.png")


def _atlas_cell(atlas: Image.Image, quantity: int) -> Image.Image:
    x_edges = _cell_edges(atlas.width, 3)
    y_edges = _cell_edges(atlas.height, 2)
    column = (quantity - 1) % 3
    row = (quantity - 1) // 3
    return atlas.crop(
        (x_edges[column], y_edges[row], x_edges[column + 1], y_edges[row + 1])
    )


def _scaled_subject(image: Image.Image, maximum_size: tuple[int, int]) -> Image.Image:
    cleaned = _remove_small_components(image)
    bounds = cleaned.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError("quantity source contains no opaque subject")
    subject = cleaned.crop(bounds)
    scale = min(maximum_size[0] / subject.width, maximum_size[1] / subject.height)
    return subject.resize(
        (max(1, round(subject.width * scale)), max(1, round(subject.height * scale))),
        Image.Resampling.LANCZOS,
    )


def _row_centers(count: int, y: int, spacing: int) -> list[tuple[int, int]]:
    start_x = 256 - spacing * (count - 1) // 2
    return [(start_x + index * spacing, y) for index in range(count)]


def _egg_positions(quantity: int) -> list[tuple[int, int]]:
    if quantity == 1:
        return [(256, 256)]
    if quantity == 2:
        return _row_centers(2, 256, 150)
    if quantity == 3:
        return [(256, 150), *_row_centers(2, 350, 150)]
    if quantity == 4:
        return [*_row_centers(2, 150, 140), *_row_centers(2, 350, 140)]
    if quantity == 5:
        return [*_row_centers(2, 150, 142), *_row_centers(3, 350, 132)]
    return [*_row_centers(3, 150, 132), *_row_centers(3, 350, 132)]


def _pile_positions(quantity: int) -> list[tuple[int, int]]:
    if quantity <= 3:
        return _row_centers(quantity, 256, 154)
    top_count = (quantity + 1) // 2
    bottom_count = quantity - top_count
    return [*_row_centers(top_count, 190, 154), *_row_centers(bottom_count, 330, 154)]


def _compose_exact_states(
    source: Image.Image,
    output_dir: Path,
    ingredient_id: str,
    maximum_size: tuple[int, int],
    position_factory,
) -> None:
    subject = _scaled_subject(source, maximum_size)
    for quantity in range(1, 7):
        canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
        for center_x, center_y in position_factory(quantity):
            offset = (center_x - subject.width // 2, center_y - subject.height // 2)
            canvas.alpha_composite(subject, offset)
        canvas.save(output_dir / f"{ingredient_id}_stock_{quantity}_v1.png")


def _count_large_alpha_components(image: Image.Image, minimum_pixels: int = 200) -> int:
    alpha = image.convert("RGBA").getchannel("A")
    width, height = alpha.size
    active = bytearray(1 if value > 16 else 0 for value in alpha.tobytes())
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


def build() -> None:
    for ingredient_id, atlas_path in ATLASES.items():
        if not atlas_path.is_file():
            raise FileNotFoundError(atlas_path)
        atlas = Image.open(atlas_path).convert("RGBA")
        x_edges = _cell_edges(atlas.width, 3)
        y_edges = _cell_edges(atlas.height, 2)
        output_dir = INGREDIENT_ROOT / ingredient_id / "stock"
        output_dir.mkdir(parents=True, exist_ok=True)
        if ingredient_id == "baocui":
            _build_baocui_states(atlas, output_dir)
            continue
        if ingredient_id == "egg":
            # Exact-count composition avoids the generated atlas's seven-egg final cell.
            _compose_exact_states(
                _atlas_cell(atlas, 1), output_dir, ingredient_id, (126, 178), _egg_positions
            )
            continue
        if ingredient_id == "scallion":
            # The generated sixth cell is one usable handful/pile, not six portions.
            _compose_exact_states(
                _atlas_cell(atlas, 6), output_dir, ingredient_id, (142, 108), _pile_positions
            )
            continue
        for quantity in range(1, 7):
            cell = _atlas_cell(atlas, quantity)
            cell = _remove_small_components(cell)
            if cell.size != (CANVAS_SIZE, CANVAS_SIZE):
                cell = cell.resize((CANVAS_SIZE, CANVAS_SIZE), Image.Resampling.LANCZOS)
            cell.save(output_dir / f"{ingredient_id}_stock_{quantity}_v1.png")

    RESTOCK_ROOT.mkdir(parents=True, exist_ok=True)
    for filename, source_path in CONTAINERS.items():
        if not source_path.is_file():
            raise FileNotFoundError(source_path)
        _fit_canvas(Image.open(source_path)).save(RESTOCK_ROOT / filename)


def check() -> None:
    errors: list[str] = []
    for ingredient_id in ATLASES:
        hashes: set[str] = set()
        for quantity in range(1, 7):
            path = INGREDIENT_ROOT / ingredient_id / "stock" / f"{ingredient_id}_stock_{quantity}_v1.png"
            if not path.is_file():
                errors.append(f"missing: {path.relative_to(ROOT)}")
                continue
            image = Image.open(path).convert("RGBA")
            if image.size != (CANVAS_SIZE, CANVAS_SIZE):
                errors.append(f"wrong size: {path.relative_to(ROOT)} -> {image.size}")
            if image.getchannel("A").getbbox() is None:
                errors.append(f"empty alpha: {path.relative_to(ROOT)}")
            corners = [image.getpixel((0, 0))[3], image.getpixel((511, 0))[3], image.getpixel((0, 511))[3], image.getpixel((511, 511))[3]]
            if any(alpha > 8 for alpha in corners):
                errors.append(f"opaque corner: {path.relative_to(ROOT)}")
            digest = hashlib.sha256(image.tobytes()).hexdigest()
            if digest in hashes:
                errors.append(f"duplicate quantity state: {path.relative_to(ROOT)}")
            hashes.add(digest)
            if ingredient_id in {"egg", "scallion"}:
                component_count = _count_large_alpha_components(image)
                if component_count != quantity:
                    errors.append(
                        f"wrong visible portion count: {path.relative_to(ROOT)} -> "
                        f"{component_count}, expected {quantity}"
                    )

    for filename in CONTAINERS:
        path = RESTOCK_ROOT / filename
        if not path.is_file():
            errors.append(f"missing: {path.relative_to(ROOT)}")
            continue
        image = Image.open(path).convert("RGBA")
        if image.size != (CANVAS_SIZE, CANVAS_SIZE):
            errors.append(f"wrong size: {path.relative_to(ROOT)} -> {image.size}")
        if image.getchannel("A").getbbox() is None:
            errors.append(f"empty alpha: {path.relative_to(ROOT)}")
        if any(image.getpixel(point)[3] > 8 for point in [(0, 0), (511, 0), (0, 511), (511, 511)]):
            errors.append(f"opaque corner: {path.relative_to(ROOT)}")

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
