# Paints the ranch ground mask: R = bare dirt, G = lush green grass. Covers world x,z in [-80, 80].
# main.gd reads the same image to keep grass tufts off the dirt.
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path

N, SPAN = 512, 160.0
rng = np.random.default_rng(5)
out = Path(__file__).resolve().parent.parent / "textures"


def px(x, z):
    return ((x + SPAN / 2) / SPAN * N, (z + SPAN / 2) / SPAN * N)


def noise(cells, blur):
    a = Image.fromarray((rng.random((cells, cells)) * 255).astype(np.uint8)).resize((N, N), Image.BICUBIC)
    return np.asarray(a.filter(ImageFilter.GaussianBlur(blur)), dtype=np.float32) / 255.0


dirt = Image.new("L", (N, N), 0)
d = ImageDraw.Draw(dirt)
# wagon track from the barn doors out to the edge, with a gentle bend
track = [px(0, 8), px(0.5, 18), px(3, 30), px(8, 45), px(10, 60), px(8, 82)]
d.line(track, fill=255, width=int(4.5 / SPAN * N), joint="curve")
# apron in front of the doors, under the lean-to, trampled corral, around the trough
d.ellipse([*px(-6, 6), *px(6, 13)], fill=255)
d.rectangle([*px(5, -6.5), *px(10, 2.5)], fill=200)
d.rectangle([*px(-23.5, -5.5), *px(-9.5, 11.5)], fill=150)
d.ellipse([*px(-14, -1), *px(-9, 5)], fill=255)
# path from corral gate to barn
d.line([px(-9, 8), px(-5, 9.5), px(-2, 9)], fill=230, width=int(2.5 / SPAN * N))

r = np.asarray(dirt.filter(ImageFilter.GaussianBlur(3)), dtype=np.float32) / 255.0
r = np.clip(r * (0.75 + 0.5 * noise(48, 2)) - 0.1 * noise(96, 1), 0, 1)  # ragged edges
g = np.clip((noise(10, 12) - 0.5) * 3.0, 0, 1) * (1 - r)

img = np.zeros((N, N, 3), np.uint8)
img[..., 0] = (r * 255).astype(np.uint8)
img[..., 1] = (g * 255).astype(np.uint8)
Image.fromarray(img).save(out / "ground_mask.png")

# tileable macro-variation noise to break up texture repetition far from the camera
m = rng.random((16, 16))
big = np.tile(m, (3, 3))
im = Image.fromarray((big * 255).astype(np.uint8)).resize((768, 768), Image.BICUBIC).filter(ImageFilter.GaussianBlur(10))
Image.fromarray(np.asarray(im)[256:512, 256:512]).save(out / "macro_noise.png")
print("ok")
