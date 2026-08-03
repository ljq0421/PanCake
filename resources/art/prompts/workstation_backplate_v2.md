# Workstation backplate v2

- Generated on: 2026-08-02 (Asia/Shanghai)
- Generator: Codex built-in `image_gen`, precise-object-edit mode
- Edit target: `res://resources/art/workstation/background/workstation_backplate_v1.png`
- Runtime purpose: clear the upper-left shelf so the four scene-backed refill containers replace the baked-in napkin box and chopstick holder.

## Final prompt

Use case: precise-object-edit. Asset type: ProjectCake fixed workstation backplate replacement. Image 1 is the exact edit target and composition authority. Remove only the tissue/napkin box and the tall chopstick cylinder from the upper-left shelf. Reconstruct the exposed dark-brown shelf surface, rear shelf edge, wall boundary, and nearby shadows so that the upper-left shelf becomes clean and empty for four separate runtime refill-container sprites. Preserve absolutely everything else pixel-compositionally: exact canvas and crop, camera, wall tiles, all counters and shelf geometry, central long inset tray, both six-cell metal racks, bottom teal and dark slots, right sauce bottles, right plant, colors, lighting, line weight, texture, perspective, and empty spaces. Do not add replacement objects, containers, food, text, labels, numbers, logos, watermark, people, hands, tools, new shadows, or decorations. Do not move, resize, redraw, recolor, zoom, crop, or reframe any preserved element. The only visible change must be that the tissue box and chopstick holder are gone and their former area is clean matching shelf surface.

## Processing

- Built-in source: `C:/Users/Administrator/.codex/generated_images/019fc0eb-edfa-73c3-b5be-3be8133fbaf0/exec-133a2e28-b0bd-4022-8bf5-8b6c7d59cfe9.png`
- Project-bound source: `tmp/imagegen/ingredient_stock/backplate/workstation_backplate_v2_imagegen_source.png`
- Build script: `tools/build_workstation_backplate_v2.py`
- Final file: `res://resources/art/workstation/background/workstation_backplate_v2.png`

The model output drifted by one horizontal pixel. The build script normalizes only this bounded drift, then composites only the former napkin/chopstick area through a feathered mask onto the original v1 backplate. Pixels outside the edit mask are validated as unchanged.

Human art-direction approval remains separate from automated and local visual checks.
