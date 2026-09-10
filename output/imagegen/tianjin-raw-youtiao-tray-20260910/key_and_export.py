from pathlib import Path
import json
import shutil
import numpy as np
from PIL import Image

project = Path(r"D:\Project\ProjectCake\project-cake")
source = Path(r"D:\CodexHome-Clean-Test-20260814\generated_images\01a08948-b992-7f60-9d49-e09520a46bee\exec-32745e56-2091-49f0-8433-9b18f49288ff.png")
work = project / "output/imagegen/tianjin-raw-youtiao-tray-20260910"
final = project / "resource/art/TianJin/生油条盘-左侧-v1.png"
if final.exists():
    raise FileExistsError(f"Refusing to overwrite {final}")
work.mkdir(parents=True, exist_ok=True)
shutil.copy2(source, work / "raw-youtiao-tray-green.png")
original = Image.open(source).convert("RGBA")
pixels = np.asarray(original, dtype=np.float32)
rgb = pixels[..., :3].copy()
red, green, blue = rgb[..., 0], rgb[..., 1], rgb[..., 2]
excess = green - np.maximum(red, blue)
alpha = (1 - np.clip((excess - 8) / 70, 0, 1)) * (pixels[..., 3] / 255)
edge = (alpha > 0) & (alpha < 1)
rgb[..., 1][edge] = np.minimum(green[edge], np.maximum(red, blue)[edge])
rgba = np.dstack((rgb, alpha * 255)).astype(np.uint8)
rgba[rgba[..., 3] == 0, :3] = 0
cutout = Image.fromarray(rgba)
cutout.save(work / "raw-youtiao-tray-cutout.png")
result = cutout.resize((512, 512), Image.Resampling.LANCZOS)
arr = np.array(result)
# Resampling can produce small color overshoots in nearly transparent pixels.
# This warm tray has no green surfaces; remove only excess green at its edges.
resampled_edge = (arr[..., 3] > 0) & (arr[..., 3] < 255)
arr[..., 1][resampled_edge] = np.minimum(arr[..., 1][resampled_edge], np.maximum(arr[..., 0], arr[..., 2])[resampled_edge])
arr[arr[..., 3] == 0, :3] = 0
result = Image.fromarray(arr)
result.save(final)
assert result.size == (512, 512)
assert result.mode == "RGBA"
assert result.getextrema()[3] == (0, 255)
assert all(result.getpixel(p)[3] == 0 for p in [(0,0),(511,0),(0,511),(511,511)])
fg = arr[..., 3] > 0
spill = (arr[..., 1].astype(int) > np.maximum(arr[..., 0], arr[..., 2]).astype(int) + 8) & fg
assert not spill.any(), "Visible green spill remains"
# Measure the straight outer depth edges, excluding their rounded corners.
m = alpha > 0.9
ys = np.arange(480, 685)
xs_left = np.array([np.flatnonzero(m[y])[0] for y in ys])
xs_right = np.array([np.flatnonzero(m[y])[-1] for y in ys])
angles = [-float(np.degrees(np.arctan(np.polyfit(ys, xs, 1)[0]))) for xs in (xs_left, xs_right)]
metrics = {
    "source_size": list(original.size),
    "final_size": list(result.size),
    "mode": result.mode,
    "alpha_range": result.getextrema()[3],
    "alpha_bounds": result.getbbox(),
    "transparent_pixels": int((arr[..., 3] == 0).sum()),
    "partial_alpha_pixels": int(((arr[..., 3] > 0) & (arr[..., 3] < 255)).sum()),
    "visible_green_spill_pixels": int(spill.sum()),
    "measured_outer_side_receding_right_degrees": angles,
    "average_outer_side_receding_right_degrees": sum(angles)/2,
    "final": str(final)
}
(work / "qa.json").write_text(json.dumps(metrics, ensure_ascii=False, indent=2), encoding="utf-8")
preview = Image.new("RGB", (1024, 512))
for i, color in enumerate(("#F4EADC", "#302723")):
    bg = Image.new("RGBA", (512,512), color)
    bg.alpha_composite(result)
    preview.paste(bg.convert("RGB"), (i*512,0))
preview.save(work / "qa-light-dark.png")
print(json.dumps(metrics, ensure_ascii=False, indent=2))
