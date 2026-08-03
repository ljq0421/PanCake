from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(r"D:\Project\ProjectCake\project-cake")
MANIFEST = ROOT / "resources" / "art" / "ASSET_MANIFEST.md"
AUDIT = ROOT / "tmp" / "imagegen" / "customer_service_v1" / "customer_service_pixel_audit_v1.json"
MARKER = "<!-- customer-service-all-customers-v1 -->"

records = {record["file"]: record for record in json.loads(AUDIT.read_text(encoding="utf-8"))}
manifest = MANIFEST.read_text(encoding="utf-8")
if MARKER in manifest:
    manifest = manifest[: manifest.index(MARKER)].rstrip() + "\n"

lines = [
    "",
    MARKER,
    "# Customer service action portraits — all customers v1",
    "",
    "- Scope: customer_01 through customer_10, each with `accepting_bag` and `paying_coins`.",
    "- Batch status: 20/20 final PNGs and 20/20 cropped AtlasTextures pass pixel and Godot 4.7.1 loading checks.",
    "- Runtime note: customer_01 is already wired into the handoff/payment flow; customer_02—10 are art-complete but runtime mapping remains pending because this art-only task does not modify business scripts or scene logic.",
    "- Human review: pending for the full 20-image contact sheet.",
    "- Contact sheet: `tmp/imagegen/customer_service_v1/customer_service_contact_sheet_v1.png`.",
    "- Pixel audit: `tmp/imagegen/customer_service_v1/customer_service_pixel_audit_v1.json` (`all_pass: true`).",
    "- Godot audit: `tmp/customer_service_texture_audit.gd`; result `png=20 cropped=20 failures=0`.",
    "",
    "| Customer | Accepting bag | Paying coins | Pixel | Godot | Runtime | Human |",
    "|---|---|---|---|---|---|---|",
]
for customer in range(1, 11):
    runtime = "integrated" if customer == 1 else "pending"
    lines.append(f"| customer_{customer:02d} | complete | complete | pass | pass | {runtime} | pending |")

for customer in range(2, 11):
    for state in ("accepting_bag", "paying_coins"):
        stem = f"customer_{customer:02d}_{state}_v1"
        rel = f"resources/art/customers/customer_{customer:02d}/{stem}.png"
        record = records[rel]
        x0, y0, x1, y1 = record["bbox"]
        width, height = x1 - x0, y1 - y0
        prompt_path = ROOT / "resources" / "art" / "prompts" / f"{stem}.md"
        prompt_doc = prompt_path.read_text(encoding="utf-8")
        prompt = prompt_doc.split("```text\n", 1)[1].split("\n```", 1)[0]
        rejected = "none; first visual candidate accepted"
        if customer == 2 and state == "accepting_bag":
            rejected = "`tmp/imagegen/customer_service_v1/customer_02_accepting_bag_v1_rejected_softmatte_alpha.png`; rejected because dominance-based soft matte removed warm skin; accepted source reprocessed with hard border key"
        if customer == 8 and state == "accepting_bag":
            rejected = "`tmp/imagegen/customer_service_v1/customer_08_accepting_bag_v1_rejected_bottom_crop.png`; rejected because lower trouser edge touched the canvas; regenerated with explicit bottom margin"
        if customer == 10:
            rejected = f"`tmp/imagegen/customer_service_v1/customer_10_{state}_v1_rejected_bottom_crop.png`; rejected because lower trouser edge touched the canvas; regenerated with explicit bottom margin"
        purpose = "Customer receives the completed filled paper bag with both hands." if state == "accepting_bag" else "Customer holds the received bag under the left arm and offers exactly three coins with the right hand."
        lines.extend([
            "",
            f"## {stem}",
            "",
            "- `status`: art-complete-godot-import-passed-runtime-integration-pending-human-review-pending",
            f"- `purpose`: {purpose}",
            f"- `final_file`: `res://{rel}`",
            f"- `cropped_resource`: `res://resources/art/customers/customer_{customer:02d}/customer_{customer:02d}_{state}_cropped.tres`",
            f"- `source_file`: `tmp/imagegen/customer_service_v1/{stem}_chromakey.png`",
            f"- `prompt_file`: `res://resources/art/prompts/{stem}.md`",
            f"- `rejected_processing_record`: {rejected}",
            "- `generator`: Codex built-in `image_gen`; chroma removal with the imagegen skill `remove_chroma_key.py` using border auto-key and hard alpha",
            "- `generated_on`: 2026-08-02 (Asia/Shanghai)",
            f"- `size`: {record['size'][0]} x {record['size'][1]} px RGBA",
            f"- `alpha_bbox`: ({x0}, {y0}) - ({x1}, {y1}); cropped size {width} x {height}",
            f"- `transparent_ratio`: {record['transparent_ratio']:.6f}",
            f"- `alpha_check`: passed; corners `[0,0,0,0]`, canvas-edge nontransparent pixels 0, key-color residue 0, partial alpha {record['partial_alpha']}",
            f"- `sha256`: `{record['sha256']}`",
            f"- `suggested_anchor`: cropped bottom-center `(x={width / 2:.1f}, y={height})`; align to the existing customer waist baseline in the workstation",
            "- `godot_import`: passed with Godot 4.7.1; PNG `Texture2D` and cropped `AtlasTexture` loaded with alpha",
            "- `runtime_integration`: pending (art-only scope)",
            "- `human_review`: pending",
            "- `complete_prompt`:",
            "",
            "```text",
            prompt,
            "```",
        ])

MANIFEST.write_text(manifest.rstrip() + "\n" + "\n".join(lines) + "\n", encoding="utf-8")
print("Appended customer service batch manifest for 18 new assets.")
