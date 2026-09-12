"""Key the imagegen green backgrounds without tinting the Wuhan teal border.

Usage: python tools/prepare_book_borders.py input.png output.png
The source is retained. Original dimensions and antialiased contour are preserved.
"""
import sys
from pathlib import Path
import numpy as np
from PIL import Image

source, destination = map(Path, sys.argv[1:3])
pixels = np.asarray(Image.open(source).convert("RGBA"), dtype=np.float32)
rgb = pixels[:, :, :3]
excess = rgb[:, :, 1] - np.maximum(rgb[:, :, 0], rgb[:, :, 2])
# Teal has balanced channels; chroma green has a large green-only excess.
alpha = np.clip(1.0 - np.maximum(excess - 45.0, 0.0) / 195.0, 0.0, 1.0)
alpha[excess > 180] = 0
edge = (alpha > 0) & (alpha < 1)
rgb[edge, 1] -= (1.0 - alpha[edge]) * 255
rgb[edge] /= alpha[edge, None]
pixels[:, :, 3] *= alpha
pixels[alpha == 0] = 0
destination.parent.mkdir(parents=True, exist_ok=True)
Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8)).save(destination)
print(f"{destination}: {pixels.shape[1]}x{pixels.shape[0]}")
