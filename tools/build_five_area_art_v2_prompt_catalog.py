#!/usr/bin/env python3
"""Write deterministic per-asset ImageGen prompts for the v2 art manifest."""

from __future__ import annotations

import json
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
REFERENCE = "res://resources/art/customers/customer_01/customer_01_neutral_v1.png"


def subject_for(asset_id: str, family: str) -> str:
    words = asset_id.removesuffix("_five_area_v2").replace("_", " ")
    if family == "machine":
        return f"a non-human Chinese breakfast-stall machine representing {words}"
    if family == "shader_texture":
        return f"a seamless, opaque material texture representing {words}"
    if family in {"ui_icon", "ui_panel", "order_card"}:
        return f"a text-free game UI visual representing {words}"
    if family == "supplier_portrait":
        return f"a friendly supplier character portrait representing {words}"
    return f"a non-human cooking-game sprite representing {words}"


def prompt_for(entry: dict[str, object]) -> str:
    subject = subject_for(str(entry["asset_id"]), str(entry["family"]))
    width, height = entry["canvas"]
    if entry["alpha_mode"] == "opaque_tile":
        background = "The whole canvas must be opaque, edge-to-edge and seamlessly tileable; no chroma key or transparency."
    else:
        background = "Center it on a perfectly flat pure #ff00ff chroma-key background with generous margins; alpha will be extracted after generation."
    return (
        f"Use the attached ProjectCake customer portrait only as a style reference. Create {subject}. "
        "Match rounded chibi cartoon proportions, thick deep-brown outline, warm cel-shaded highlights, "
        "and polished cozy Chinese breakfast-stall game art. Do not make equipment or ingredients into people. "
        f"{background} No text, numbers, labels, logos, watermark, cast shadow, floor, or reflection. "
        f"Output composition: {width}x{height}."
    )


def main() -> None:
    manifest_path = PROJECT_ROOT / "docs" / "five_area_art_v2_manifest.json"
    out_dir = PROJECT_ROOT / "resources" / "art" / "prompts" / "five_area_v2"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    out_dir.mkdir(parents=True, exist_ok=True)
    for entry in manifest["entries"]:
        record = {
            "asset_id": entry["asset_id"],
            "target_path": entry["target_path"],
            "reference": REFERENCE,
            "prompt": prompt_for(entry),
            "canvas": entry["canvas"],
            "alpha_mode": entry["alpha_mode"],
        }
        (out_dir / f"{entry['asset_id']}.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"count": len(manifest["entries"]), "directory": str(out_dir)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
