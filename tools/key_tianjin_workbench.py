"""Extract the approved green-screen tray. Never changes source artwork."""
import argparse
from pathlib import Path
import numpy as np
from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument("source", type=Path)
parser.add_argument("output", type=Path)
args = parser.parse_args()
pixels = np.array(Image.open(args.source).convert("RGB"), dtype=np.float32)
red, green, blue = pixels[..., 0], pixels[..., 1], pixels[..., 2]
excess = green - np.maximum(red, blue)
alpha = 1 - np.clip((excess - 8) / 70, 0, 1)
# Remove the green contribution on partially covered edge pixels.
edge = (alpha > 0) & (alpha < 1)
pixels[..., 1][edge] = np.minimum(green[edge], np.maximum(red, blue)[edge])
result = Image.fromarray(np.dstack((pixels.astype(np.uint8), (alpha * 255).astype(np.uint8))))
box = result.getbbox()
if box is None:
    raise ValueError("No foreground survived the green key")
result = result.crop((max(0, box[0]-4), max(0, box[1]-4), min(result.width, box[2]+4), min(result.height, box[3]+4)))
args.output.parent.mkdir(parents=True, exist_ok=True)
result.save(args.output)
print(f"Saved {args.output}: {result.size}, alpha={result.getextrema()[3]}")
