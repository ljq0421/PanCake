from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


ROOT = Path(r"D:\Project\ProjectCake\project-cake")
OUT_DIR = ROOT / "tmp" / "imagegen" / "customer_service_v1"
STATES = ("accepting_bag", "paying_coins")


def audit(path: Path) -> dict:
    image = Image.open(path).convert("RGBA")
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    width, height = image.size
    pixels = list(image.getdata())
    transparent = sum(a == 0 for _, _, _, a in pixels)
    partial = sum(0 < a < 255 for _, _, _, a in pixels)
    magenta_opaque = sum(a > 0 and r > 220 and b > 200 and g < 70 for r, g, b, a in pixels)
    corners = [image.getpixel((0, 0))[3], image.getpixel((width - 1, 0))[3], image.getpixel((0, height - 1))[3], image.getpixel((width - 1, height - 1))[3]]
    edge_nonzero = 0
    for x in range(width):
        edge_nonzero += image.getpixel((x, 0))[3] > 0
        edge_nonzero += image.getpixel((x, height - 1))[3] > 0
    for y in range(1, height - 1):
        edge_nonzero += image.getpixel((0, y))[3] > 0
        edge_nonzero += image.getpixel((width - 1, y))[3] > 0
    sha = hashlib.sha256(path.read_bytes()).hexdigest()
    return {
        "file": path.relative_to(ROOT).as_posix(),
        "size": [width, height],
        "bbox": list(bbox) if bbox else None,
        "transparent_ratio": round(transparent / (width * height), 6),
        "partial_alpha": partial,
        "corner_alpha": corners,
        "edge_nonzero": edge_nonzero,
        "opaque_magenta_like": magenta_opaque,
        "sha256": sha,
        "pass": bool(bbox) and corners == [0, 0, 0, 0] and edge_nonzero == 0 and magenta_opaque == 0,
    }


def checker(size: tuple[int, int], cell: int = 24) -> Image.Image:
    canvas = Image.new("RGB", size, "#efe7da")
    draw = ImageDraw.Draw(canvas)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if (x // cell + y // cell) % 2:
                draw.rectangle((x, y, x + cell - 1, y + cell - 1), fill="#ddd2c3")
    return canvas


def make_contact_sheet(records: list[dict]) -> Path:
    tile_w, tile_h = 410, 470
    sheet = Image.new("RGB", (tile_w * 4, tile_h * 5), "#2f251f")
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default(size=22)
    for index, record in enumerate(records):
        customer = index // 2 + 1
        state = STATES[index % 2]
        col = (index % 4)
        row = index // 4
        x0, y0 = col * tile_w, row * tile_h
        tile = checker((tile_w - 16, tile_h - 50))
        source = Image.open(ROOT / record["file"]).convert("RGBA")
        contained = ImageOps.contain(source, (tile.width - 20, tile.height - 20), Image.Resampling.LANCZOS)
        tile.paste(contained, ((tile.width - contained.width) // 2, (tile.height - contained.height) // 2), contained)
        sheet.paste(tile, (x0 + 8, y0 + 38))
        label = f"customer_{customer:02d}  {state}"
        draw.text((x0 + 12, y0 + 8), label, fill="#fff4dc", font=font)
    path = OUT_DIR / "customer_service_contact_sheet_v1.png"
    sheet.save(path)
    return path


records = []
for customer in range(1, 11):
    for state in STATES:
        path = ROOT / "resources" / "art" / "customers" / f"customer_{customer:02d}" / f"customer_{customer:02d}_{state}_v1.png"
        records.append(audit(path))

OUT_DIR.mkdir(parents=True, exist_ok=True)
audit_path = OUT_DIR / "customer_service_pixel_audit_v1.json"
audit_path.write_text(json.dumps(records, indent=2), encoding="utf-8")
contact_path = make_contact_sheet(records)
print(json.dumps({"all_pass": all(record["pass"] for record in records), "records": records, "audit": str(audit_path), "contact_sheet": str(contact_path)}, indent=2))
