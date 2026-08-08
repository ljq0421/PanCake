#!/usr/bin/env python3
"""Audit the five-area v2 art manifest without mutating any art assets."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import zlib
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_png_rgba(path: Path) -> tuple[int, int, bytes]:
    """Return an RGBA raster for non-interlaced RGB/RGBA PNGs used by this batch."""
    raw = path.read_bytes()
    if raw[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    pos = 8
    width = height = color_type = bit_depth = None
    chunks: list[bytes] = []
    while pos < len(raw):
        length = struct.unpack(">I", raw[pos:pos + 4])[0]
        kind = raw[pos + 4:pos + 8]
        data = raw[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            width, height, bit_depth, color_type, compression, filtering, interlace = struct.unpack(">IIBBBBB", data)
            if bit_depth != 8 or color_type not in (2, 6) or compression or filtering or interlace:
                raise ValueError("unsupported PNG encoding")
        elif kind == b"IDAT":
            chunks.append(data)
        elif kind == b"IEND":
            break
    assert width is not None and height is not None and color_type is not None
    channels = 4 if color_type == 6 else 3
    decompressed = zlib.decompress(b"".join(chunks))
    stride = width * channels
    rows: list[bytes] = []
    cursor = 0
    previous = bytearray(stride)
    for _ in range(height):
        filter_type = decompressed[cursor]
        cursor += 1
        row = bytearray(decompressed[cursor:cursor + stride])
        cursor += stride
        for index in range(stride):
            left = row[index - channels] if index >= channels else 0
            up = previous[index]
            up_left = previous[index - channels] if index >= channels else 0
            if filter_type == 1:
                row[index] = (row[index] + left) & 255
            elif filter_type == 2:
                row[index] = (row[index] + up) & 255
            elif filter_type == 3:
                row[index] = (row[index] + ((left + up) // 2)) & 255
            elif filter_type == 4:
                p = left + up - up_left
                pa, pb, pc = abs(p - left), abs(p - up), abs(p - up_left)
                row[index] = (row[index] + (left if pa <= pb and pa <= pc else up if pb <= pc else up_left)) & 255
            elif filter_type != 0:
                raise ValueError("unknown PNG filter")
        rows.append(bytes(row))
        previous = row
    if channels == 4:
        return width, height, b"".join(rows)
    rgba = bytearray(width * height * 4)
    for pixel in range(width * height):
        rgba[pixel * 4:pixel * 4 + 3] = b"".join(rows)[pixel * 3:pixel * 3 + 3]
        rgba[pixel * 4 + 3] = 255
    return width, height, bytes(rgba)


def alpha_report(path: Path) -> dict[str, object]:
    width, height, pixels = read_png_rgba(path)
    corners = []
    for x, y in ((0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)):
        offset = (y * width + x) * 4
        corners.append(list(pixels[offset:offset + 4]))
    key_pixels = 0
    opaque_pixels = 0
    for index in range(0, len(pixels), 4):
        red, green, blue, alpha = pixels[index:index + 4]
        if alpha > 0:
            opaque_pixels += 1
            if (red > 230 and green < 40 and blue > 230) or (red < 40 and green > 230 and blue < 40):
                key_pixels += 1
    return {
        "dimensions": [width, height],
        "corner_rgba": corners,
        "opaque_pixels": opaque_pixels,
        "possible_key_pixels": key_pixels,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, default=PROJECT_ROOT / "docs" / "five_area_art_v2_manifest.json")
    parser.add_argument("--output", type=Path, default=PROJECT_ROOT / "docs" / "five_area_art_v2_audit.json")
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    report_entries = []
    totals = {"planned": 0, "present": 0, "valid": 0, "invalid": 0}
    for entry in manifest["entries"]:
        target = PROJECT_ROOT / entry["target_path"].removeprefix("res://")
        source_dir = PROJECT_ROOT / "tmp" / "imagegen" / "five_area_v2" / "sources"
        source = source_dir / f"{entry['asset_id']}_key.png"
        source_name_inferred = False
        if not source.exists():
            legacy_id = re.sub(r"_v[0-9]+(?=_five_area_v2$)", "", entry["asset_id"])
            legacy_source = source_dir / f"{legacy_id}_key.png"
            if legacy_source.exists():
                source = legacy_source
                source_name_inferred = True
        prompt = PROJECT_ROOT / "resources" / "art" / "prompts" / "five_area_v2" / f"{entry['asset_id']}.json"
        row = {
            "asset_id": entry["asset_id"],
            "target_path": entry["target_path"],
            "expected_canvas": entry["canvas"],
            "alpha_mode": entry["alpha_mode"],
            "prompt_record": str(prompt.relative_to(PROJECT_ROOT)).replace("\\", "/") if prompt.exists() else None,
            "imagegen_source": str(source.relative_to(PROJECT_ROOT)).replace("\\", "/") if source.exists() else None,
            "imagegen_source_sha256": sha256(source) if source.exists() else None,
            "imagegen_source_name_inferred": source_name_inferred,
            "dekey_parameters": "auto-key border; soft-matte; transparent-threshold=12; opaque-threshold=220; despill; low-alpha-key-scrub=8",
            "human_visual_review": "pending",
        }
        if not target.exists():
            row["status"] = "planned"
            totals["planned"] += 1
        else:
            totals["present"] += 1
            try:
                visual = alpha_report(target)
                row.update(visual)
                row["sha256"] = sha256(target)
                row["godot_import_present"] = target.with_suffix(target.suffix + ".import").exists()
                expected_dimensions = entry["canvas"]
                dimensions_ok = visual["dimensions"] == expected_dimensions
                corners_transparent = all(corner[3] == 0 for corner in visual["corner_rgba"])
                no_key = visual["possible_key_pixels"] == 0
                if entry["alpha_mode"] == "opaque_tile":
                    alpha_ok = visual["opaque_pixels"] == visual["dimensions"][0] * visual["dimensions"][1]
                else:
                    alpha_ok = corners_transparent and no_key
                row["dimensions_ok"] = dimensions_ok
                row["alpha_ok"] = alpha_ok
                row["status"] = "valid" if dimensions_ok and alpha_ok else "invalid"
            except (OSError, ValueError, zlib.error, AssertionError) as error:
                row["status"] = "invalid"
                row["error"] = str(error)
            totals[row["status"]] += 1
        report_entries.append(row)
    payload = {"manifest": str(args.manifest), "totals": totals, "entries": report_entries}
    args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(totals, ensure_ascii=False))


if __name__ == "__main__":
    main()
