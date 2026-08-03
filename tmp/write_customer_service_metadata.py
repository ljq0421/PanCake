from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(r"D:\Project\ProjectCake\project-cake")
AUDIT = ROOT / "tmp" / "imagegen" / "customer_service_v1" / "customer_service_pixel_audit_v1.json"
IDENTITIES = {
    2: "adult woman, warm skin, shoulder-length deep chestnut wavy hair, brick-red short-sleeve top with cream rounded collar, mustard-yellow lower garment",
    3: "older woman, warm skin, silver-gray hair swept into a side/back bun, faded teal short-sleeve outer layer, warm cream inner blouse, terracotta lower garment",
    4: "middle-aged man, warm brown skin, close dark curly hair, navy polo with ochre collar and sleeve trim, brick-brown lower garment",
    5: "young adult woman, warm skin, narrow oval face, blunt bangs and chin-length dark bob, mauve square-neck short-sleeve top, warm cream lower garment",
    6: "slim elderly man, long rectangular face, swept-back silver hair, light-blue shirt, mustard V-neck vest, brick-red lower garment",
    7: "full-figured middle-aged woman, warm fair skin with freckles, copper-red short layered hair, warm gold boat-neck top, deep teal lower garment",
    8: "slim young adult man, narrow face, honey-blond shoulder-length straight hair, charcoal two-button Henley, warm rust-brown trousers",
    9: "adult woman, deep warm-brown skin, heart-shaped face, blue-black long side braid, coral-orange wrap/collar top, deep indigo lower garment",
    10: "sturdy broad middle-aged man, warm olive skin, bald head with dark side stubble, dark mustache and short goatee, dark burgundy open-collar shirt over cream undershirt, warm khaki trousers",
}


def full_prompt(customer: int, state: str) -> str:
    identity = IDENTITIES[customer]
    if state == "accepting_bag":
        action = "Change only expression and arms: pleased receiving expression; both forearms extend forward and down, with two complete hands firmly gripping the left and right sides of exactly one upright filled paper bag centered against the torso. Exactly one person, two arms, two hands and one bag; no coins."
    else:
        action = "Change only expression and arms: pleased polite payment; tuck exactly one upright filled paper bag under the subject's LEFT arm (viewer-right side), while the RIGHT forearm reaches toward the player (viewer-left) with one complete open palm holding exactly THREE clearly separated round gold coins. Exactly one person, two arms, two hands, one bag and three coins."
    correction = ""
    if customer == 8 and state == "accepting_bag":
        correction = " This is the accepted targeted composition correction: scale the complete customer-and-bag figure to about 82% canvas height and leave at least 70 pixels of clean key color below the complete lower waist/trouser edge."
    if customer == 10:
        correction = " This is the accepted targeted composition correction: scale the complete figure/action to about 82% canvas height and leave at least 70 pixels of clean key color below the complete lower trouser/waist edge."
    refs = "Image 1 is the exact neutral identity/outfit authority; the customer_01 action sprite is pose/action reference only; paper-bag, coin when applicable, and visual_style_anchor_v8 images are motif/style references."
    return (
        f"Use case: identity-preserve. Asset type: ProjectCake customer action Sprite2D, customer_{customer:02d}_{state}_v1. {refs} "
        f"Preserve customer_{customer:02d} exactly: {identity}; keep the same face, age, body proportions, palette and bold deep-brown outline. {action}{correction} "
        "Centered waist-up half-body; preserve all hair tips, both ears, both shoulders, both forearms, both complete hands, the bag, coins when applicable, and the complete lower waist edge fully inside the canvas with generous margin. "
        "Match ProjectCake warm flat 2D cartoon style, chunky readable shapes, thick deep-brown outer lines, simple color blocks and no more than about three shade levels. "
        "Background must be one perfectly uniform flat chroma color #ff00ff reaching every edge and corner, with no gradient, texture, floor, halo, glow, cast shadow, reflection or vignette. "
        "Do not add text, numbers, logo, watermark, UI, order card, patience bar, cash note, extra props, extra limbs, extra fingers, floating symbols or background."
    )


records = {record["file"]: record for record in json.loads(AUDIT.read_text(encoding="utf-8"))}
prompt_dir = ROOT / "resources" / "art" / "prompts"
for customer in range(2, 11):
    for state in ("accepting_bag", "paying_coins"):
        stem = f"customer_{customer:02d}_{state}_v1"
        rel = f"resources/art/customers/customer_{customer:02d}/{stem}.png"
        record = records[rel]
        rejected = []
        if customer == 2 and state == "accepting_bag":
            rejected.append("customer_02_accepting_bag_v1_rejected_softmatte_alpha.png (warm skin was incorrectly removed by the dominance-based soft matte)")
        if customer == 8 and state == "accepting_bag":
            rejected.append("customer_08_accepting_bag_v1_rejected_bottom_crop.png (lower trouser edge touched the canvas)")
        if customer == 10:
            rejected.append(f"customer_10_{state}_v1_rejected_bottom_crop.png (lower trouser edge touched the canvas)")
        prompt = full_prompt(customer, state)
        prompt_text = f"""# {stem}

- Generator: Codex built-in `image_gen`
- Generated: 2026-08-02 (Asia/Shanghai)
- Use case: `identity-preserve`
- References: `customer_{customer:02d}_neutral_v1.png`, customer 01 action pose reference, `paper_bag_package_v1.png`, {"`currency_coin_v1.png`, " if state == "paying_coins" else ""}`visual_style_anchor_v8.png`
- Source: `tmp/imagegen/customer_service_v1/{stem}_chromakey.png`
- Final: `res://{rel}`
- Rejected/processing record: {"; ".join(rejected) if rejected else "none; accepted first visual candidate after hard chroma extraction"}
- Chroma removal: skill `remove_chroma_key.py`, border auto-key, hard alpha, tolerance 60{" (75 for customer_05 magenta-edge cleanup)" if customer == 5 else ""}
- SHA-256: `{record['sha256']}`

## Complete accepted prompt

```text
{prompt}
```
"""
        (prompt_dir / f"{stem}.md").write_text(prompt_text, encoding="utf-8")

        x0, y0, x1, y1 = record["bbox"]
        width, height = x1 - x0, y1 - y0
        tres = f'''[gd_resource type="AtlasTexture" load_steps=2 format=3]

[ext_resource type="Texture2D" path="res://{rel}" id="1_customer"]

[resource]
atlas = ExtResource("1_customer")
region = Rect2({x0}, {y0}, {width}, {height})
filter_clip = true
'''
        out = ROOT / "resources" / "art" / "customers" / f"customer_{customer:02d}" / f"customer_{customer:02d}_{state}_cropped.tres"
        out.write_text(tres, encoding="utf-8")

print("Wrote 18 complete prompt records and 18 cropped AtlasTexture resources.")
