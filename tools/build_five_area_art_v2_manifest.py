#!/usr/bin/env python3
"""Build the non-destructive five-area art-v2 production manifest.

The manifest is the source of truth for the regeneration batch.  It deliberately
does not write PNGs: ImageGen sources and their processed siblings are added by
the production workflow after visual selection.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from dataclasses import asdict, dataclass
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
ART_ROOT = PROJECT_ROOT / "resources" / "art"
VERSION_SUFFIX = "_five_area_v2"
EXCLUDED_TOP_LEVEL = {"customers", "style_guides", "prompts"}


@dataclass(frozen=True)
class AssetEntry:
    asset_id: str
    source_path: str | None
    target_path: str
    family: str
    canvas: list[int]
    alpha_mode: str
    runtime_state: str
    source_sha256: str | None
    runtime_references: list[str]
    status: str


def png_size(path: Path) -> list[int]:
    with path.open("rb") as handle:
        header = handle.read(24)
    if header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        raise ValueError(f"Not a PNG: {path}")
    return [int.from_bytes(header[16:20], "big"), int.from_bytes(header[20:24], "big")]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def profile_for(relative: Path) -> tuple[str, list[int], str]:
    value = relative.as_posix()
    if value.startswith("ingredients/") and "/stock/" in value:
        # Ingredient-rack art is displayed inside roughly 73x83 px slots at
        # 1920x1080.  Four-times source resolution preserves the intentional
        # dark outline after Godot's KEEP_ASPECT_CENTERED downscale.
        return "ingredient_slot_icon", [384, 384], "rgba_cutout"
    if value.startswith("workstation/textures/"):
        return "shader_texture", [1024, 1024], "opaque_tile"
    if value.startswith("workstation/griddle/"):
        return "griddle", [1024, 1024], "rgba_cutout"
    if value.startswith("workstation/expansion/machines/"):
        return "machine", [1024, 512], "rgba_cutout"
    if value.startswith("workstation/decor/") or value.startswith("workstation/overlays/") or value.startswith("workstation/foreground/"):
        return "wide_workstation_decor", [1024, 576], "rgba_cutout"
    if value.startswith("workstation/"):
        return "workstation_sprite", [512, 512], "rgba_cutout"
    if value.startswith("ui/order/"):
        return "order_card", [600, 740], "rgba_cutout"
    if value.startswith("ui/day_summary/") or value.startswith("ui/recipe/") or value.startswith("ui/supplier_event/"):
        return "ui_panel", [1024, 576], "rgba_cutout"
    if value.startswith("ui/") or value.startswith("payments/"):
        return "ui_icon", [256, 256], "rgba_cutout"
    if value.startswith("suppliers/"):
        return "supplier_portrait", [512, 768], "rgba_cutout"
    return "item_icon", [256, 256], "rgba_cutout"


def five_area_target(relative: Path) -> Path:
    # Keep the original version token.  Several source assets intentionally
    # coexist as v1/v2/v3 variants, and stripping it would make two planned
    # art-v2 targets collide.
    return relative.with_name(f"{relative.stem}{VERSION_SUFFIX}.png")


def runtime_references(resource_path: str | None) -> list[str]:
    """Locate static scene/script references without claiming dynamic mappings."""
    if resource_path is None:
        return []
    matches: list[str] = []
    for suffix in ("*.tscn", "*.gd"):
        for candidate in PROJECT_ROOT.rglob(suffix):
            if any(part in {".godot", ".git", "tmp"} for part in candidate.parts):
                continue
            try:
                if resource_path in candidate.read_text(encoding="utf-8"):
                    matches.append(candidate.relative_to(PROJECT_ROOT).as_posix())
            except UnicodeDecodeError:
                continue
    return matches


def existing_entries() -> list[AssetEntry]:
    entries: list[AssetEntry] = []
    for path in sorted(ART_ROOT.rglob("*.png")):
        relative = path.relative_to(ART_ROOT)
        if relative.parts[0] in EXCLUDED_TOP_LEVEL:
            continue
        if "background" in relative.parts or "background" in path.name:
            continue
        if path.stem.endswith(VERSION_SUFFIX):
            continue
        family, canvas, alpha_mode = profile_for(relative)
        target = five_area_target(relative)
        source_path = f"res://resources/art/{relative.as_posix()}"
        entries.append(AssetEntry(
            asset_id=target.stem,
            source_path=source_path,
            target_path=f"res://resources/art/{target.as_posix()}",
            family=family,
            canvas=canvas,
            alpha_mode=alpha_mode,
            runtime_state="existing_reference_to_switch",
            source_sha256=sha256(path),
            runtime_references=runtime_references(source_path),
            status="planned",
        ))
    return entries


def missing_entry(relative: str, family: str, canvas: list[int], alpha_mode: str = "rgba_cutout") -> AssetEntry:
    target = Path(relative)
    return AssetEntry(
        asset_id=target.stem,
        source_path=None,
        target_path=f"res://resources/art/{target.as_posix()}",
        family=family,
        canvas=canvas,
        alpha_mode=alpha_mode,
        runtime_state="new_five_area_binding",
        source_sha256=None,
        runtime_references=[],
        status="planned",
    )


def missing_entries() -> list[AssetEntry]:
    entries: list[AssetEntry] = []
    for station in ("packaged_drink_heater", "steamer"):
        for tier in range(1, 4):
            entries.append(missing_entry(
                f"workstation/expansion/machines/{station}_tier_{tier}{VERSION_SUFFIX}.png",
                "machine", [1024, 512],
            ))
    for ingredient in ("coriander", "preserved_mustard"):
        entries.extend([
            missing_entry(f"ingredients/{ingredient}/{ingredient}_pile{VERSION_SUFFIX}.png", "item_icon", [256, 256]),
            missing_entry(f"ingredients/{ingredient}/{ingredient}_scattered{VERSION_SUFFIX}.png", "item_icon", [256, 256]),
        ])
        for amount in range(1, 7):
            entries.append(missing_entry(
                f"ingredients/{ingredient}/stock/{ingredient}_stock_{amount}{VERSION_SUFFIX}.png",
                "ingredient_slot_icon", [384, 384],
            ))
    for drink in ("milk", "soy_milk", "walnut", "black_sesame"):
        entries.extend([
            missing_entry(f"products/packaged_drink/{drink}_package{VERSION_SUFFIX}.png", "item_icon", [256, 256]),
            missing_entry(f"products/packaged_drink/{drink}_heated{VERSION_SUFFIX}.png", "item_icon", [256, 256]),
        ])
    for product in ("oil_cake", "sugar_oil_cake"):
        entries.extend([
            missing_entry(f"ingredients/youtiao/{product}_dough{VERSION_SUFFIX}.png", "item_icon", [256, 256]),
            missing_entry(f"products/youtiao/{product}{VERSION_SUFFIX}.png", "item_icon", [256, 256]),
        ])
    for product in ("mantou", "vegetable_bun", "meat_bun"):
        entries.extend([
            missing_entry(f"ingredients/steamer/{product}_steaming{VERSION_SUFFIX}.png", "item_icon", [256, 256]),
            missing_entry(f"products/steamer/{product}_cooked{VERSION_SUFFIX}.png", "item_icon", [256, 256]),
        ])
    return entries


def write_outputs(entries: list[AssetEntry], output_json: Path, output_markdown: Path) -> None:
    families: dict[str, int] = {}
    for entry in entries:
        families[entry.family] = families.get(entry.family, 0) + 1
    payload = {
        "schema_version": 1,
        "scope": {
            "included": "all existing formal art PNGs except backgrounds, customers, and style guides; plus 40 explicit five-area gaps",
            "excluded": ["backgrounds", "customers", "style_guides"],
            "naming": "same-directory *_five_area_v2.png siblings",
        },
        "counts": {"total": len(entries), "families": families},
        "entries": [asdict(entry) for entry in entries],
    }
    output_json.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    lines = [
        "# Five-area art v2 production manifest",
        "",
        f"- Total planned assets: `{len(entries)}`",
        "- Excluded: backgrounds, customer portraits, style-guide anchors.",
        "- Naming: same-directory `*_five_area_v2.png` siblings; old assets remain untouched.",
        "",
        "| Family | Count | Canvas | Alpha mode |",
        "| --- | ---: | --- | --- |",
    ]
    for family in sorted(families):
        sample = next(entry for entry in entries if entry.family == family)
        lines.append(f"| {family} | {families[family]} | {sample.canvas[0]}×{sample.canvas[1]} | {sample.alpha_mode} |")
    lines.extend(["", "The JSON companion contains the per-asset old/new mapping, source hash, output specification and integration state.", ""])
    output_markdown.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-json", type=Path, default=PROJECT_ROOT / "docs" / "five_area_art_v2_manifest.json")
    parser.add_argument("--output-markdown", type=Path, default=PROJECT_ROOT / "docs" / "five_area_art_v2_manifest.md")
    args = parser.parse_args()
    entries = existing_entries() + missing_entries()
    if len(entries) != 196:
        raise SystemExit(f"Expected 196 entries, got {len(entries)}. Re-audit scope before generating art.")
    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    write_outputs(entries, args.output_json, args.output_markdown)
    print(json.dumps({"count": len(entries), "json": str(args.output_json), "markdown": str(args.output_markdown)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
