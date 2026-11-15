# Derives painted/rusty variants from the Poly Haven (CC0) source textures in ../textures.
import numpy as np
from PIL import Image, ImageFilter
from pathlib import Path

T = Path(__file__).resolve().parent.parent / "textures"
rng = np.random.default_rng(7)


def load(name):
    return np.asarray(Image.open(T / name).convert("RGB"), dtype=np.float32) / 255.0


def save(arr, name):
    Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8)).save(T / name, quality=92)


def noise(size, cells, blur):
    # tileable: wrap-pad before blur, then crop
    n = rng.random((cells, cells)).astype(np.float32)
    im = Image.fromarray((n * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC)
    a = np.asarray(im, dtype=np.float32) / 255.0
    a = np.tile(a, (3, 3))
    a = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(blur)), dtype=np.float32) / 255.0
    return a[size:2 * size, size:2 * size]


# --- painted planks: keep the wood detail, repaint it ---
src = load("distressed_painted_planks_diff.jpg")
lum = src.mean(axis=2, keepdims=True)
detail = lum / lum.mean()
sat = src.max(axis=2) - src.min(axis=2)
chipped = np.clip((sat - 0.08) * 8, 0, 1)[..., None]  # the orange flecks become bare wood
bare_wood = np.array([0.42, 0.33, 0.24]) * detail
fade = noise(1024, 6, 30)[..., None]

red = np.array([0.40, 0.085, 0.065]) * detail * (0.85 + 0.3 * fade)
red = red * (1 - chipped) + bare_wood * chipped
save(red, "barn_red_diff.jpg")

white = np.array([0.86, 0.83, 0.76]) * detail * (0.9 + 0.15 * fade)
white = white * (1 - chipped) + bare_wood * chipped
save(white, "trim_white_diff.jpg")

# --- corrugated roof: galvanized with rust that streaks down the slope (texture v) ---
iron = load("corrugated_iron_diff.jpg")
ilum = iron.mean(axis=2, keepdims=True) / iron.mean()
patches = noise(1024, 8, 25)
streak = np.asarray(Image.fromarray((rng.random((8, 1024)) * 255).astype(np.uint8)).resize((1024, 1024), Image.BICUBIC), dtype=np.float32) / 255.0
rust_mask = np.clip((patches * 0.6 + streak * 0.5 - 0.45) * 3, 0, 1)[..., None]
rust = np.array([0.45, 0.22, 0.10]) * ilum * (0.7 + 0.5 * noise(1024, 40, 3)[..., None])
galv = np.array([0.55, 0.56, 0.54]) * ilum
save(galv * (1 - rust_mask) + rust * rust_mask, "roof_rusty_diff.jpg")

print("ok")
