# Draws the wooden UI: a plank button with straw poking out around it, and burned-in style icons.
# Output: ../ui/wood_button.png (9-slice, see ui_theme.gd for margins) and ../ui/icons/*.png
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "ui"
(OUT / "icons").mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(4)
SS = 4  # supersampling for clean edges

W, H = 240, 120
INSET = 20  # straw sticks out this far past the plank


def wood(w, h):
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    warp = np.sin(x / w * 7 + rng.random() * 6) * 6 + np.sin(x / w * 23) * 2
    grain = np.sin((y + warp) * 0.32) * 0.5 + 0.5
    grain = grain ** 3
    fine = rng.random((h, w)).astype(np.float32)
    fine = np.asarray(Image.fromarray((fine * 255).astype(np.uint8)).resize((w, h)).filter(ImageFilter.GaussianBlur(1)), np.float32) / 255
    streak = np.asarray(Image.fromarray((rng.random((h // 6 + 1, 4)) * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC), np.float32) / 255
    base = np.array([0.56, 0.36, 0.2])
    dark = np.array([0.36, 0.21, 0.1])
    t = (grain * 0.55 + fine * 0.2 + streak * 0.35)[..., None]
    rgb = base * (1 - t * 0.6) + dark * t * 0.6
    # two boards: seam across the middle
    seam = np.abs(y - h * 0.5) < 1.2 * SS
    rgb[seam] *= 0.45
    rgb[(y > h * 0.5 + 1.2 * SS) & (y < h * 0.5 + 3 * SS)] *= 1.15
    return np.clip(rgb, 0, 1)


def straw(d, cx, cy, ang, spread, n, length, front=False):
    for _ in range(n):
        a = ang + rng.uniform(-spread, spread)
        ln = length * rng.uniform(0.55, 1.0) * SS
        bend = rng.uniform(-0.25, 0.25)
        pts = []
        for k in range(6):
            t = k / 5
            aa = a + bend * t
            pts.append((cx + math.cos(aa) * ln * t, cy + math.sin(aa) * ln * t))
        c = [(242, 212, 120), (222, 182, 88), (190, 148, 66), (250, 228, 150)][rng.integers(4)]
        wdt = int(rng.uniform(1.6, 3.0) * SS)
        d.line(pts, fill=(60, 40, 15, 255), width=wdt + SS)  # dark outline reads on any background
        d.line(pts, fill=c + (255,), width=wdt)


def button():
    w, h = W * SS, H * SS
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    i = INSET * SS
    # straw behind the plank: tufts at the corners, a few along the long edges
    for (cx, cy, ang) in [(i + 10 * SS, i + 8 * SS, -2.4), (w - i - 10 * SS, i + 8 * SS, -0.75),
                          (i + 10 * SS, h - i - 8 * SS, 2.4), (w - i - 10 * SS, h - i - 8 * SS, 0.75)]:
        straw(d, cx, cy, ang, 0.8, 26, 34)
    for x in (w * 0.24, w * 0.42, w * 0.6, w * 0.78):
        straw(d, x, h - i - 4 * SS, 1.57, 0.75, 9, 21)
        straw(d, x + 14 * SS, i + 4 * SS, -1.57, 0.7, 6, 17)
    for y in (h * 0.4, h * 0.6):
        straw(d, i + 4 * SS, y, 3.14, 0.6, 6, 18)
        straw(d, w - i - 4 * SS, y, 0.0, 0.6, 6, 18)
    # plank with rounded corners, dark rim and a lit top edge
    pw, ph = w - 2 * i, h - 2 * i
    tex = (wood(pw, ph) * 255).astype(np.uint8)
    plank = Image.fromarray(tex).convert("RGBA")
    mask = Image.new("L", (pw, ph), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, pw - 1, ph - 1], radius=9 * SS, fill=255)
    rim = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rim)
    rd.rounded_rectangle([0, 0, pw - 1, ph - 1], radius=9 * SS, outline=(45, 25, 10, 255), width=3 * SS)
    rd.rounded_rectangle([3 * SS, 3 * SS, pw - 3 * SS, ph * 0.5], radius=7 * SS, outline=(255, 220, 160, 70), width=SS * 2)
    plank = Image.alpha_composite(plank, rim)
    pd = ImageDraw.Draw(plank)
    for nx, ny in [(12, 12), (pw / SS - 12, 12), (12, ph / SS - 12), (pw / SS - 12, ph / SS - 12)]:  # nails
        r = 3.2 * SS
        pd.ellipse([nx * SS - r, ny * SS - r, nx * SS + r, ny * SS + r], fill=(70, 62, 55, 255), outline=(30, 25, 20, 255), width=SS)
        pd.ellipse([nx * SS - r * 0.4, ny * SS - r * 0.6, nx * SS, ny * SS - r * 0.1], fill=(170, 160, 150, 255))
    img.paste(plank, (i, i), mask)
    # a few stalks in front so the straw wraps around the board
    for (cx, cy, ang) in [(i + 4 * SS, i + 18 * SS, -2.9), (w - i - 4 * SS, h - i - 16 * SS, 0.3)]:
        straw(d := ImageDraw.Draw(img), cx, cy, ang, 0.4, 5, 24)
    img = img.resize((W, H), Image.LANCZOS)
    img.save(OUT / "wood_button.png")


# ---------- icons: cream fill, dark brown outline, drawn at 4x ----------
S = 64 * SS
CREAM = (250, 236, 200, 255)
INK = (55, 30, 12, 255)


def icon(name, draw_fn):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    draw_fn(d, lambda v: v * SS)
    img.resize((64, 64), Image.LANCZOS).save(OUT / "icons" / f"{name}.png")


def shape(d, pts, k):
    p = [(k(x), k(y)) for x, y in pts]
    d.polygon(p, fill=CREAM, outline=INK, width=k(3))


def barn(d, k):
    shape(d, [(8, 58), (8, 28), (17, 15), (32, 8), (47, 15), (56, 28), (56, 58)], k)
    d.rectangle([k(22), k(36), k(42), k(58)], fill=(150, 50, 35, 255), outline=INK, width=k(3))
    d.line([k(22), k(36), k(42), k(58)], fill=CREAM, width=k(3))
    d.line([k(42), k(36), k(22), k(58)], fill=CREAM, width=k(3))


def house(d, k):
    shape(d, [(12, 58), (12, 32), (52, 32), (52, 58)], k)
    shape(d, [(5, 34), (32, 10), (59, 34)], k)
    d.rectangle([k(27), k(42), k(37), k(58)], fill=INK)
    d.rectangle([k(42), k(12), k(48), k(24)], fill=CREAM, outline=INK, width=k(3))


def silo(d, k):
    d.rounded_rectangle([k(18), k(22), k(46), k(60)], radius=k(3), fill=CREAM, outline=INK, width=k(3))
    d.pieslice([k(18), k(6), k(46), k(38)], 180, 360, fill=(150, 150, 145, 255), outline=INK, width=k(3))
    for y in (32, 42, 52):
        d.line([k(18), k(y), k(46), k(y)], fill=INK, width=k(2))


def windmill(d, k):
    d.line([k(22), k(60), k(30), k(24)], fill=INK, width=k(4))
    d.line([k(42), k(60), k(34), k(24)], fill=INK, width=k(4))
    for y in (36, 48):
        d.line([k(24), k(y + 4), k(40), k(y - 4)], fill=INK, width=k(2))
        d.line([k(40), k(y + 4), k(24), k(y - 4)], fill=INK, width=k(2))
    d.ellipse([k(14), k(4), k(50), k(40)], fill=CREAM, outline=INK, width=k(3))
    for a in range(0, 360, 30):
        r = math.radians(a)
        d.line([k(32), k(22), k(32 + math.cos(r) * 17), k(22 + math.sin(r) * 17)], fill=INK, width=k(2))
    d.ellipse([k(28), k(18), k(36), k(26)], fill=INK)


def build(d, k):  # hammer
    shape(d, [(28, 24), (36, 24), (36, 60), (28, 60)], k)
    shape(d, [(12, 10), (46, 10), (54, 18), (46, 26), (12, 26)], k)


def rotate(d, k):
    d.arc([k(10), k(10), k(54), k(54)], 40, 330, fill=INK, width=k(10))
    d.arc([k(10), k(10), k(54), k(54)], 40, 330, fill=CREAM, width=k(5))
    shape(d, [(44, 4), (60, 22), (40, 26)], k)


def cancel(d, k):
    for a, b in [((14, 14), (50, 50)), ((50, 14), (14, 50))]:
        d.line([k(a[0]), k(a[1]), k(b[0]), k(b[1])], fill=INK, width=k(14))
        d.line([k(a[0]), k(a[1]), k(b[0]), k(b[1])], fill=(225, 90, 70, 255), width=k(8))


def place(d, k):
    pts = [k(10), k(34), k(26), k(50), k(55), k(16)]
    d.line(pts, fill=INK, width=k(14), joint="curve")
    d.line(pts, fill=(120, 200, 90, 255), width=k(8), joint="curve")


button()
for n, f in dict(barn=barn, house=house, silo=silo, windmill=windmill, build=build, rotate=rotate, cancel=cancel, place=place).items():
    icon(n, f)
print("ok")
