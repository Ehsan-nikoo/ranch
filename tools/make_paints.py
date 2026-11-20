# The other paint colours a player can pick for the ranch's buildings (Building.PAINTS), made the same way
# as barn_red_diff.jpg in make_textures.py: the Poly Haven (CC0) planks, repainted, the chips bare wood.
import numpy as np
from PIL import Image, ImageFilter
from pathlib import Path

T = Path(__file__).resolve().parent.parent / "textures"
rng = np.random.default_rng(11)


def load(name):
    return np.asarray(Image.open(T / name).convert("RGB"), dtype=np.float32) / 255.0


def noise(size, cells, blur):
    n = rng.random((cells, cells)).astype(np.float32)
    im = Image.fromarray((n * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC)
    a = np.tile(np.asarray(im, dtype=np.float32) / 255.0, (3, 3))
    a = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(blur)), dtype=np.float32) / 255.0
    return a[size:2 * size, size:2 * size]


src = load("distressed_painted_planks_diff.jpg")
lum = src.mean(axis=2, keepdims=True)
detail = lum / lum.mean()
sat = src.max(axis=2) - src.min(axis=2)
chipped = np.clip((sat - 0.08) * 8, 0, 1)[..., None]
bare_wood = np.array([0.42, 0.33, 0.24]) * detail
fade = noise(1024, 6, 30)[..., None]

for name, c in dict(green=[0.11, 0.25, 0.13], blue=[0.11, 0.2, 0.34], yellow=[0.62, 0.44, 0.11],
                    brown=[0.31, 0.17, 0.08], gray=[0.4, 0.4, 0.38]).items():
    p = np.array(c) * detail * (0.85 + 0.3 * fade)
    p = p * (1 - chipped) + bare_wood * chipped
    Image.fromarray((np.clip(p, 0, 1) * 255).astype(np.uint8)).save(T / f"paint_{name}.jpg", quality=90)
print("ok")
