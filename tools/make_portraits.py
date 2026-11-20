# Paints the townspeople's portraits (people.gd) as old hand-tinted studio photographs in an oval
# worn-brass frame, to sit with the leather boards and brass icons.
# Output: ../ui/people/<id>.png, 320x400 with a transparent outside.
# Each face is built as a relief (height map) of soft shapes, lit from the top left, then toned
# like an old photo: warm sepia, film grain, a dark vignette and a few scratches.
import math
import numpy as np
from PIL import Image, ImageFilter
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "ui" / "people"
OUT.mkdir(parents=True, exist_ok=True)
FW, FH = 320, 400
SS = 2
W, H = FW * SS, FH * SS
ys, xs = np.mgrid[0:H, 0:W].astype(np.float32) / SS   # design-space coordinates (0..320, 0..400)


def blur(a, r):
    """Gaussian blur of a float image (radius in design units), done in the frequency domain."""
    if r <= 0:
        return a
    sig = r * SS
    p = int(sig * 3) + 1
    b = np.pad(a.astype(np.float32), p, mode="reflect")
    fy = np.fft.fftfreq(b.shape[0])[:, None]
    fx = np.fft.rfftfreq(b.shape[1])[None, :]
    g = np.exp(-2 * (math.pi * sig) ** 2 * (fx ** 2 + fy ** 2))
    out = np.fft.irfft2(np.fft.rfft2(b) * g, s=b.shape)
    return out[p:-p, p:-p].astype(np.float32)


def noise(rng, cells_x, cells_y, smooth=Image.BICUBIC):
    n = Image.fromarray((rng.random((cells_y, cells_x)) * 255).astype(np.uint8)).resize((W, H), smooth)
    return np.asarray(n, np.float32) / 255


def fbm(rng, base=4, octaves=5):
    out = np.zeros((H, W), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        c = base * 2 ** o
        out += noise(rng, c, int(c * H / W) + 1) * amp
        tot += amp
        amp *= 0.5
    return out / tot


def strands(rng, along_x, density=60, length=6):
    """Hair-like streaks: noise stretched along one axis."""
    if along_x:
        n = noise(rng, max(2, W // (length * 8)), H // 2)
    else:
        n = noise(rng, W // 2, max(2, H // (length * 8)))
    return n


def radial(rng, px, py, k=260, clump=24):
    """Combed hair: fine streaks fanning out from (px, py), with a few thicker locks."""
    a = np.arctan2(ys - py, xs - px)
    def wave(n):
        v = rng.random(n + 1)
        t = (a + math.pi) / (2 * math.pi) * n
        i = np.floor(t).astype(int)
        f = t - i
        f = f * f * (3 - 2 * f)
        return v[i % n] * (1 - f) + v[(i + 1) % n] * f
    r = np.sqrt((xs - px) ** 2 + (ys - py) ** 2)
    fine = wave(k)
    locks = wave(clump)
    breaks = noise(rng, 40, 50) * 0.3
    return np.clip(0.55 * fine + 0.45 * locks + breaks - 0.15 + 0.0 * r, 0, 1)


def ell(cx, cy, rx, ry, rot=0.0):
    """Normalised squared distance inside an ellipse (<1 inside)."""
    dx, dy = xs - cx, ys - cy
    if rot:
        c, s = math.cos(rot), math.sin(rot)
        dx, dy = dx * c + dy * s, -dx * s + dy * c
    return (dx / rx) ** 2 + (dy / ry) ** 2


def dome(cx, cy, rx, ry, h, rot=0.0):
    d = ell(cx, cy, rx, ry, rot)
    return np.sqrt(np.clip(1 - d, 0, 1)) * h, np.clip((1 - d) * max(rx, ry) / 1.5, 0, 1)


def gauss(cx, cy, sx, sy, rot=0.0):
    return np.exp(-ell(cx, cy, sx, sy, rot))


def poly_mask(pts, soft=0.8):
    from PIL import ImageDraw
    im = Image.new("L", (W, H), 0)
    ImageDraw.Draw(im).polygon([(x * SS, y * SS) for x, y in pts], fill=255)
    return blur(np.asarray(im, np.float32) / 255, soft)


class Canvas:
    def __init__(self):
        self.rgb = np.zeros((H, W, 3), np.float32)
        self.h = np.zeros((H, W), np.float32)
        self.spec = np.zeros((H, W), np.float32)
        self.cover = np.zeros((H, W), np.float32)

    def lay(self, mask, rgb, height, spec=0.0):
        m = np.clip(mask, 0, 1)
        rgb = np.broadcast_to(np.asarray(rgb, np.float32), (H, W, 3)) if np.ndim(rgb) == 1 else rgb
        self.rgb = self.rgb * (1 - m[..., None]) + rgb * m[..., None]
        self.h = self.h * (1 - m) + height * m
        self.spec = self.spec * (1 - m) + spec * m
        self.cover = np.maximum(self.cover, m)

    def paint(self, mask, rgb, amount=1.0):
        """Colour only, the relief stays (freckles, blush, lips, shadows)."""
        m = np.clip(mask * amount, 0, 1)[..., None]
        self.rgb = self.rgb * (1 - m) + np.asarray(rgb, np.float32) * m

    def bump(self, add, mask=None):
        self.h = self.h + (add if mask is None else add * mask)

    def shade(self, ao=0.6):
        gy, gx = np.gradient(blur(self.h, 1.6), 1.0 / SS)
        n = np.dstack([-gx, -gy, np.full_like(gx, 1.0)])
        n /= np.linalg.norm(n, axis=-1, keepdims=True)
        L = np.array([-0.68, -0.5, 0.55])
        L /= np.linalg.norm(L)
        diff = np.clip(n @ L, 0, 1)
        # cavities: where the relief is lower than its surroundings
        occl = np.clip((blur(self.h, 10) - self.h) / 18, 0, 1)
        half = np.array([-0.25, -0.3, 1.0])
        half /= np.linalg.norm(half)
        sp = np.clip(n @ half, 0, 1) ** 40 * self.spec
        light = 0.22 + 1.0 * diff
        out = self.rgb * light[..., None] * (1 - ao * occl[..., None]) + sp[..., None] * 0.8
        # a soft fill from the right so the shadow side isn't black
        fill = np.clip(n @ np.array([0.7, -0.1, 0.7]), 0, 1)
        return out + self.rgb * fill[..., None] * 0.12


# ---------------------------------------------------------------- the parts

CX, CY = 160, 196   # middle of the face


def backdrop(c, rng, tone):
    """A painted studio backdrop: lighter behind the head, mottled, darker to the corners."""
    g = fbm(rng, 3, 4)
    glow = np.exp(-(((xs - 140) / 150) ** 2 + ((ys - 150) / 170) ** 2))
    base = np.asarray(tone) * (0.45 + 0.5 * glow)[..., None] * (0.85 + 0.3 * g)[..., None]
    c.lay(np.ones((H, W)), base, np.zeros((H, W)))


def torso(c, rng, shirt, wide=1.0, collar=None):
    pts = [(CX - 150 * wide, 420), (CX - 140 * wide, 352), (CX - 108 * wide, 310), (CX - 46, 286), (CX + 46, 286),
           (CX + 108 * wide, 310), (CX + 140 * wide, 352), (CX + 150 * wide, 420)]
    m = poly_mask(pts, 1.2)
    h = dome(CX, 420, 190 * wide, 150, 60)[0]
    folds = fbm(rng, 6, 3)
    rgb = np.asarray(shirt) * (0.85 + 0.3 * folds)[..., None]
    c.lay(m, rgb, h + folds * 6)


def neck(c, skin, thick=1.0):
    pts = [(CX - 46 * thick, 302), (CX - 38 * thick, 236), (CX + 38 * thick, 236), (CX + 46 * thick, 302)]
    m = poly_mask(pts, 1.5)
    h = np.sqrt(np.clip(1 - ((xs - CX) / (48 * thick)) ** 2, 0, 1)) * 70
    c.lay(m, skin, h)
    # shadow under the jaw
    c.paint(gauss(CX, 252, 40 * thick, 14), np.asarray(skin) * 0.55, 0.8)


def head(c, rng, skin, fem=False, age=0.0, jaw=1.0):
    rx, ry = (52, 70) if fem else (56, 74)
    # an egg: the half-width narrows smoothly from the cheekbones down to the chin
    v = (ys - CY) / ry
    taper = 1 - 0.42 * np.clip(v - 0.05, 0, 1) ** 1.4 / jaw
    hw = rx * np.sqrt(np.clip(1 - v ** 2, 0, 1)) * taper + 0.01
    u = (xs - CX) / hw
    hh = 100 * np.sqrt(np.clip(1 - u ** 2, 0, 1)) * np.sqrt(np.clip(1 - v ** 2, 0, 1)) ** 0.5
    m = blur(((u ** 2 < 1) & (np.abs(v) < 1)).astype(np.float32), 1.2)
    # features in the relief
    feat = (gauss(CX - 2, CY + 8, 5.5, 16) * 12      # nose bridge
            + gauss(CX - 3, CY + 27, 8, 6.5) * 15    # nose tip
            + gauss(CX - 11, CY + 30, 4.5, 3.5) * 6 + gauss(CX + 6, CY + 30, 4.5, 3.5) * 6   # nostril wings
            - gauss(CX - 24, CY - 4, 15, 9) * 16     # eye sockets
            - gauss(CX + 22, CY - 4, 15, 9) * 16
            + gauss(CX - 23, CY - 18, 17, 5) * 8     # brows
            + gauss(CX + 21, CY - 18, 17, 5) * 8
            + gauss(CX - 30, CY + 18, 16, 14) * 5    # cheeks
            + gauss(CX + 28, CY + 18, 16, 14) * 5
            + gauss(CX - 2, CY + 46, 14, 6) * 6      # lips
            + gauss(CX - 2, CY + 64, 16, 10) * 8     # chin
            - gauss(CX - 2, CY + 39, 10, 2.2) * 6)   # mouth line
    skin_n = fbm(rng, 10, 4)
    rgb = np.asarray(skin) * (0.92 + 0.14 * skin_n)[..., None]
    c.lay(m, rgb, hh + feat + skin_n * 2, spec=0.25)
    # ears
    for sx in (-1, 1):
        eh, em = dome(CX + sx * (rx - 1), CY + 6, 8, 16, 66)
        em = np.clip(em * 3, 0, 1) * (1 - np.clip(m * 1.3, 0, 1) * (ell(CX, CY, rx - 4, ry) < 1))
        c.lay(em, np.asarray(skin) * 0.9, eh)
    # colour: warmer cheeks, nose and lips; age lines
    c.paint(gauss(CX - 32, CY + 22, 15, 11) + gauss(CX + 30, CY + 22, 15, 11), np.asarray(skin) * np.array([1.05, 0.82, 0.78]), 0.35)
    c.paint(gauss(CX - 3, CY + 28, 8, 6), np.asarray(skin) * np.array([1.02, 0.84, 0.8]), 0.3)
    lips = np.clip(gauss(CX - 2, CY + 44, 15, 5.5) * 1.4 - 0.2, 0, 1)
    c.paint(lips, np.asarray(skin) * np.array([0.88, 0.6, 0.56]), 0.85 if fem else 0.55)
    c.paint(np.clip(gauss(CX - 2, CY + 40, 13, 1.4) * 1.5 - 0.3, 0, 1), np.asarray(skin) * 0.35, 0.9)  # the line between the lips
    if age > 0:
        lines = np.zeros((H, W), np.float32)
        for sx in (-1, 1):  # crow's feet and smile folds
            lines += np.clip(gauss(CX + sx * 44, CY - 2, 6, 1.2, sx * 0.4) + gauss(CX + sx * 44, CY + 4, 6, 1.2, -sx * 0.3), 0, 1)
            lines += np.clip(gauss(CX + sx * 20, CY + 34, 2, 12, -sx * 0.45), 0, 1)
        lines += np.clip(gauss(CX - 2, CY - 38, 26, 1.3) + gauss(CX - 2, CY - 31, 22, 1.2), 0, 1)  # forehead
        c.bump(-lines * 6 * age)
        c.paint(lines, np.asarray(skin) * 0.6, 0.45 * age)
    # nostrils
    for sx in (-1, 1):
        c.paint(gauss(CX - 3 + sx * 7, CY + 33, 3, 1.8), np.asarray(skin) * 0.3, 0.8)
    return m


def eyes(c, skin, iris=(0.28, 0.2, 0.14), brow=(0.25, 0.18, 0.12), fem=False, squint=0.0):
    for sx, ex in ((-1, CX - 24), (1, CX + 22)):
        ey = CY - 3
        rx, ry = 10.5, 4.6 * (1 - 0.35 * squint)
        eye = np.clip((1 - ell(ex, ey, rx, ry)) * 6, 0, 1)
        c.paint(eye, np.asarray(skin) * 0.3 + np.array([0.62, 0.58, 0.52]) * 0.55, 1.0)   # the white, toned down
        ir = np.clip((1 - ell(ex + 1, ey + 0.4, 4.6, 4.6)) * 5, 0, 1) * eye
        c.paint(ir, iris, 1.0)
        c.paint(np.clip((1 - ell(ex + 1, ey + 0.4, 2.0, 2.0)) * 5, 0, 1) * eye, (0.05, 0.04, 0.03), 1.0)
        c.paint(np.clip((1 - ell(ex - 0.8, ey - 1.2, 1.1, 1.1)) * 4, 0, 1) * eye, (0.85, 0.82, 0.78), 0.9)   # glint
        # upper lid: a dark line and a soft shadow on the eye
        lid = np.clip(1 - np.abs(ell(ex, ey + 1.2, rx + 1.2, ry + 1.8) - 1) * 4, 0, 1) * (ys < ey + 0.5)
        c.paint(lid, (0.12, 0.08, 0.06), 0.85 if fem else 0.65)
        c.paint(np.clip(gauss(ex, ey - 4, 11, 3), 0, 1) * eye, np.asarray(skin) * 0.45, 0.5)
        # lower lid and the crease above
        c.paint(np.clip(1 - np.abs(ell(ex, ey - 0.5, rx, ry + 1.5) - 1) * 5, 0, 1) * (ys > ey + 1), np.asarray(skin) * 0.6, 0.35)
        c.paint(np.clip(gauss(ex, ey - 8, 11, 1.4), 0, 1), np.asarray(skin) * 0.55, 0.45)
        # brow
        t = 2.2 if fem else 3.6
        bm = np.clip(gauss(ex - sx * 1, ey - 15 - (xs - ex) * sx * 0.06, 13, t, -sx * 0.12) * 1.6 - 0.3, 0, 1)
        c.paint(bm, brow, 0.9)
        c.bump(bm * 3)


def hair_cap(c, rng, col, fem=False, bun=False, bald=0.0):
    """Hair on top of the head: a cap over the skull, combed from a parting (or back to the bun)."""
    st = radial(rng, CX + 6, CY - 76, 300) if fem and bun else radial(rng, CX + 22, CY - 150, 420, 30)
    if fem:
        top = np.clip((1 - ell(CX, CY - 22, 64, 62)) * 6, 0, 1) * (ys < CY - 44 + ((xs - CX) / 50) ** 2 * 34)
        side = np.clip((1 - ell(CX, CY - 6, 64, 66)) * 6, 0, 1) * (np.abs(xs - CX) > 46) * (ys < CY + 30)
        m = np.clip(top + side, 0, 1)
        h = dome(CX, CY - 18, 66, 70, 112)[0]
        if bun:
            bh, bm = dome(CX + 6, CY - 76, 30, 20, 120)
            m = np.maximum(m, np.clip(bm * 3, 0, 1))
            h = np.maximum(h, bh)
    else:
        m = np.clip((1 - ell(CX, CY - 20, 62, 64)) * 6, 0, 1) * (ys < CY - 48 + ((xs - CX) / 52) ** 2 * 44)
        m = blur(m, 1.0)
        m *= np.clip((ys - (CY - 92 + bald * 30)) / 4, 0, 1)
        h = dome(CX, CY - 18, 66, 70, 110)[0]
    rgb = np.asarray(col) * (0.55 + 0.75 * st)[..., None]
    c.lay(m, rgb, h + st * 1.5, spec=0.35)


def beard(c, rng, col, full=True, stache=True, long=0.0):
    st = radial(rng, CX - 2, CY - 60, 520, 40)
    if full:
        pts = [(CX - 60, CY + 4), (CX - 56, CY + 40), (CX - 34, CY + 78 + long * 30), (CX - 2, CY + 92 + long * 50), (CX + 32, CY + 78 + long * 30),
               (CX + 56, CY + 40), (CX + 60, CY + 4), (CX + 42, CY + 26), (CX + 20, CY + 48), (CX - 2, CY + 52), (CX - 22, CY + 48), (CX - 42, CY + 26)]
        m = poly_mask(pts, 2.5)
        h = dome(CX, CY + 20, 66, 80, 112)[0] + st * 2.5
        c.lay(m, np.asarray(col) * (0.55 + 0.8 * st)[..., None], h, spec=0.2)
    if stache:
        pts = [(CX - 30, CY + 44), (CX - 22, CY + 34), (CX - 8, CY + 31), (CX - 2, CY + 34), (CX + 4, CY + 31), (CX + 18, CY + 34), (CX + 26, CY + 44),
               (CX + 14, CY + 41), (CX - 2, CY + 40), (CX - 18, CY + 41)]
        m = poly_mask(pts, 1.6)
        st2 = radial(rng, CX - 2, CY + 20, 200, 12)
        c.lay(m, np.asarray(col) * (0.55 + 0.8 * st2)[..., None], dome(CX, CY + 20, 66, 80, 112)[0] + 8 + st2 * 1.5, spec=0.2)


def hat_cowboy(c, rng, col):
    g = fbm(rng, 8, 4)
    rgb = np.asarray(col) * (0.8 + 0.4 * g)[..., None]
    # brim: a wide flat ellipse, curled up at the sides
    bm = np.clip((1 - ell(CX, CY - 52, 118, 26)) * 8, 0, 1)
    curl = ((xs - CX) / 118) ** 4 * 30
    c.lay(bm, rgb * 0.9, 120 + curl + (ys - (CY - 52)) * 0.6)
    # shadow of the brim over the face
    c.cast(bm, 0, 26, 8, 0.6)
    crown = poly_mask([(CX - 54, CY - 54), (CX - 48, CY - 118), (CX - 20, CY - 132), (CX, CY - 122), (CX + 20, CY - 132), (CX + 48, CY - 118), (CX + 54, CY - 54)], 2)
    ch = dome(CX, CY - 80, 60, 70, 150)[0] - gauss(CX, CY - 126, 10, 26) * 14
    c.lay(crown, rgb, ch)
    band = crown * np.clip(1 - np.abs(ys - (CY - 64)) / 7, 0, 1)
    c.lay(band, np.asarray(col) * 0.4, ch + 3)


def hat_bowler(c, rng, col):
    g = fbm(rng, 8, 4)
    rgb = np.asarray(col) * (0.85 + 0.3 * g)[..., None]
    bm = np.clip((1 - ell(CX, CY - 50, 84, 14)) * 8, 0, 1)
    c.lay(bm, rgb, 120 + (ys - (CY - 50)) * 0.8, spec=0.5)
    c.cast(bm, 0, 20, 7, 0.45)
    cm = np.clip((1 - ell(CX, CY - 76, 62, 44)) * 8, 0, 1) * (ys < CY - 50)
    c.lay(cm, rgb, dome(CX, CY - 70, 64, 56, 150)[0], spec=0.6)
    c.lay(cm * np.clip(1 - np.abs(ys - (CY - 56)) / 5, 0, 1), np.asarray(col) * 0.6 + 0.02, dome(CX, CY - 70, 64, 56, 150)[0] + 2)


def hat_bonnet(c, rng, col):
    g = fbm(rng, 10, 4)
    rgb = np.asarray(col) * (0.8 + 0.35 * g)[..., None]
    # a deep brim framing the face, open at the front
    outer = np.clip((1 - ell(CX, CY - 4, 86, 98)) * 8, 0, 1)
    inner = np.clip((1 - ell(CX, CY + 10, 62, 82)) * 8, 0, 1)
    m = np.clip(outer - inner, 0, 1) * (ys < CY + 46)
    pleats = 0.5 + 0.5 * np.sin(np.arctan2(ys - CY, xs - CX) * 26)
    c.lay(m, rgb * (0.85 + 0.25 * pleats)[..., None], 120 + pleats * 6 - ell(CX, CY - 4, 86, 98) * 20)
    c.cast(m * (ys < CY - 30), 4, 12, 7, 0.45)
    # ribbon under the chin
    rib = poly_mask([(CX - 70, CY + 40), (CX - 46, CY + 82), (CX - 14, CY + 98), (CX - 10, CY + 92), (CX - 40, CY + 72), (CX - 60, CY + 36)], 1.2)
    c.lay(rib, np.asarray(col) * 0.75, 110 + 0 * xs)
    bow = np.clip((1 - ell(CX - 20, CY + 98, 14, 8, 0.3)) * 6, 0, 1) + np.clip((1 - ell(CX + 2, CY + 100, 12, 7, -0.3)) * 6, 0, 1)
    c.lay(np.clip(bow, 0, 1), np.asarray(col) * 0.85, 112 + 0 * xs)


def hat_fur(c, rng, col):
    fur = noise(rng, W // 3, H // 3, Image.NEAREST)
    fur = blur(fur, 0.5)
    m = np.clip((1 - ell(CX, CY - 64, 72, 44)) * 8, 0, 1) * (ys < CY - 36)
    m *= np.clip(1 - (fur - 0.5) * 0.3 * (ell(CX, CY - 64, 72, 44) > 0.8), 0, 1)
    c.lay(m, np.asarray(col) * (0.5 + 0.9 * fur)[..., None], dome(CX, CY - 60, 74, 56, 150)[0] + fur * 10)
    c.cast(m, 2, 12, 6, 0.4)
    # a tail hanging at the side
    tail = np.clip((1 - ell(CX + 66, CY - 6, 14, 52, -0.15)) * 6, 0, 1)
    rings = 0.5 + 0.5 * np.sin((ys - CY) / 7.0)
    tc = np.asarray(col) * (0.45 + 0.6 * fur * (0.6 + 0.6 * rings))[..., None]
    c.lay(tail, tc, 130 + fur * 8)


def cast(self, mask, dx, dy, r, k):
    sh = blur(np.roll(np.roll(mask, int(dy * SS), 0), int(dx * SS), 1), r) * k
    self.rgb = self.rgb * (1 - sh[..., None])


Canvas.cast = cast


def star(c, x, y, r=15):
    pts = []
    for i in range(10):
        rr = r if i % 2 == 0 else r * 0.45
        a = -math.pi / 2 + i * math.pi / 5
        pts.append((x + math.cos(a) * rr, y + math.sin(a) * rr))
    m = poly_mask(pts, 0.8)
    for i in range(0, 10, 2):
        c.lay(np.clip((1 - ell(pts[i][0], pts[i][1], 2.6, 2.6)) * 5, 0, 1), (0.8, 0.62, 0.28), 150 + 0 * xs, spec=1.0)
    c.lay(m, (0.82, 0.64, 0.3), 140 + dome(x, y, r, r, 8)[0], spec=1.0)
    c.lay(np.clip((1 - ell(x, y, r * 0.42, r * 0.42)) * 4, 0, 1) * m, (0.7, 0.52, 0.24), 140 + 0 * xs, spec=1.0)


# ---------------------------------------------------------------- photo, frame

def photo_tone(rgb, rng, tint=0.5):
    tint = min(1.0, tint + 0.2)
    rgb = np.dstack([blur(rgb[..., i], 0.45) for i in range(3)])
    glow = np.dstack([blur(rgb[..., i], 6) for i in range(3)])
    rgb = rgb * 0.88 + np.maximum(rgb, glow) * 0.12   # a little halation, like an old lens
    lum = rgb @ np.array([0.3, 0.55, 0.15])
    sepia = lum[..., None] * np.array([1.14, 0.95, 0.7])
    out = rgb * (1 - tint) + sepia * tint
    out = (out - 0.5) * 1.06 + 0.5 + 0.02
    grain = noise(rng, W // 2, H // 2, Image.NEAREST) - 0.5
    out = out + grain[..., None] * 0.07
    vig = np.clip(ell(FW / 2, FH / 2 - 6, 168, 214), 0, 2)
    out = out * (1 - 0.7 * np.clip(vig - 0.3, 0, 1) ** 1.3)[..., None]
    # a few fine scratches and dust specks
    from PIL import ImageDraw
    sc = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(sc)
    for _ in range(9):
        x0, y0 = rng.uniform(0, W), rng.uniform(0, H)
        r, t = rng.uniform(20, 90) * SS, rng.uniform(0, math.pi)
        d.line([x0, y0, x0 + math.cos(t) * r, y0 + math.sin(t) * r], fill=int(rng.uniform(60, 140)), width=1)
    for _ in range(30):
        x0, y0 = rng.uniform(0, W), rng.uniform(0, H)
        d.ellipse([x0, y0, x0 + SS, y0 + SS], fill=int(rng.uniform(60, 160)))
    s = np.asarray(sc, np.float32) / 255
    out = out + s[..., None] * 0.18
    return np.clip(out, 0, 1)


def frame(rgb, rng):
    """Oval worn-brass frame with a rounded profile; outside it the image is transparent."""
    d = np.sqrt(ell(FW / 2, FH / 2, FW / 2 - 6, FH / 2 - 6))
    ring_in = 0.895
    t = np.clip((d - ring_in) / (1 - ring_in), 0, 1)
    prof = np.sin(t * math.pi) * 18 + np.sin(t * math.pi * 3) * 2
    beads = (np.sin(np.arctan2((ys - FH / 2) / FH, (xs - FW / 2) / FW) * 110) > 0.3) * (np.abs(t - 0.5) < 0.1) * 1.5
    hgt = prof + beads
    gy, gx = np.gradient(blur(hgt, 0.6), 1.0 / SS)
    n = np.dstack([-gx * 0.5, -gy * 0.5, np.ones_like(gx)])
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    L = np.array([-0.55, -0.6, 0.58])
    L /= np.linalg.norm(L)
    sh = np.clip(n @ L, 0, 1)
    blot = fbm(rng, 6, 4)
    brass = np.array([0.6, 0.45, 0.22]) * (0.55 + 0.6 * blot)[..., None]
    patina = np.clip((blot - 0.58) * 4, 0, 1)[..., None] * np.array([-0.16, -0.06, -0.02])
    grime = blur((rng.random((H, W)) > 0.5).astype(np.float32), 0.4)
    col = (brass + patina) * (0.4 + 0.85 * sh)[..., None] * (0.85 + 0.25 * grime)[..., None] + (sh ** 16)[..., None] * 0.22
    on_ring = (d >= ring_in)[..., None]
    # the photo sits a little under the ring: a soft shadow along its inner edge
    inner_sh = np.clip(1 - (ring_in - d) / 0.05, 0, 1) * (d < ring_in)
    rgb = rgb * (1 - 0.6 * inner_sh)[..., None]
    out = np.where(on_ring, col, rgb)
    alpha = np.clip((1 - d) * 120, 0, 1)
    return np.dstack([np.clip(out, 0, 1), alpha])


def save(name, c, rng, tint):
    rgb = photo_tone(c.shade(), rng, tint)
    img = frame(rgb, rng)
    Image.fromarray((img * 255).astype(np.uint8), "RGBA").resize((FW, FH), Image.LANCZOS).save(OUT / f"{name}.png")
    print("ok", name)


# ---------------------------------------------------------------- the six

def bill(rng):  # the sheriff: weathered, moustache, dark hat, tan shirt, leather vest, star
    c = Canvas()
    skin = (0.78, 0.56, 0.42)
    backdrop(c, rng, (0.55, 0.5, 0.44))
    torso(c, rng, (0.62, 0.5, 0.34), 1.05)
    vest = poly_mask([(CX - 160, 420), (CX - 150, 340), (CX - 106, 306), (CX - 44, 290), (CX - 14, 420)], 1.2) + \
        poly_mask([(CX + 160, 420), (CX + 150, 340), (CX + 106, 306), (CX + 44, 290), (CX + 14, 420)], 1.2)
    c.lay(np.clip(vest, 0, 1), np.asarray((0.36, 0.24, 0.15)) * (0.8 + 0.4 * fbm(rng, 10, 3))[..., None], dome(CX, 420, 200, 150, 64)[0] + 4)
    neck(c, skin, 1.08)
    c.lay(poly_mask([(CX - 40, 296), (CX - 26, 270), (CX, 300), (CX + 26, 270), (CX + 40, 296), (CX, 316)], 1), (0.62, 0.5, 0.34), 80 + 0 * xs)
    star(c, CX - 78, 352, 17)
    head(c, rng, skin, age=0.6, jaw=1.08)
    eyes(c, skin, iris=(0.3, 0.32, 0.3), brow=(0.3, 0.2, 0.12), squint=0.35)
    hair_cap(c, rng, (0.32, 0.22, 0.14))
    beard(c, rng, (0.36, 0.25, 0.16), full=False)
    c.paint(np.clip(fbm(rng, 30, 2) - 0.45, 0, 1) * (ell(CX, CY + 50, 50, 30) < 1), (0.3, 0.22, 0.17), 0.5)  # stubble
    hat_cowboy(c, rng, (0.36, 0.26, 0.17))
    save("bill", c, rng, 0.5)


def henry(rng):  # the shopkeeper: older, grey, spectacles, bowler, dark coat, white collar, red tie
    c = Canvas()
    skin = (0.84, 0.66, 0.54)
    backdrop(c, rng, (0.5, 0.5, 0.48))
    torso(c, rng, (0.2, 0.21, 0.24), 1.0)
    c.lay(poly_mask([(CX - 40, 290), (CX - 30, 276), (CX, 330), (CX + 30, 276), (CX + 40, 290), (CX + 6, 420), (CX - 6, 420)], 1.2), (0.82, 0.8, 0.74), 76 + 0 * xs)
    c.lay(poly_mask([(CX - 9, 304), (CX + 9, 304), (CX + 13, 360), (CX, 372), (CX - 13, 360)], 1), (0.55, 0.14, 0.1), 84 + 0 * xs, spec=0.4)
    neck(c, skin, 0.95)
    c.lay(poly_mask([(CX - 34, 286), (CX - 30, 266), (CX + 30, 266), (CX + 34, 286), (CX, 298)], 1.2), (0.85, 0.83, 0.78), 80 + 0 * xs)
    head(c, rng, skin, age=1.0, jaw=0.96)
    eyes(c, skin, iris=(0.25, 0.3, 0.34), brow=(0.62, 0.6, 0.57))
    hair_cap(c, rng, (0.68, 0.66, 0.63), bald=0.6)
    for sx in (-1, 1):  # grey sideburns
        sb = np.clip((1 - ell(CX + sx * 52, CY - 6, 5, 16)) * 4, 0, 1) * 0.85
        c.lay(sb, np.asarray((0.66, 0.64, 0.6)) * (0.7 + 0.5 * strands(rng, False))[..., None], dome(CX, CY, 66, 80, 104)[0])
    beard(c, rng, (0.7, 0.68, 0.64), full=False)
    for ex in (CX - 24, CX + 22):  # round wire spectacles
        ring = np.clip(1 - np.abs(np.sqrt(ell(ex, CY - 2, 15, 13)) - 1) * 12, 0, 1)
        c.lay(ring, (0.6, 0.5, 0.3), 128 + 0 * xs, spec=1.0)
        c.paint(np.clip((1 - ell(ex - 5, CY - 7, 5, 3)) * 3, 0, 1), (0.9, 0.9, 0.88), 0.25)
    br = np.clip(1 - np.abs(ys - (CY - 6)) / 1.3, 0, 1) * (np.abs(xs - (CX - 1)) < 8)
    c.lay(br, (0.6, 0.5, 0.3), 128 + 0 * xs, spec=1.0)
    hat_bowler(c, rng, (0.13, 0.12, 0.11))
    save("henry", c, rng, 0.5)


def rose(rng):  # the vet: auburn hair up in a bun, white high-collared blouse, a stethoscope
    c = Canvas()
    skin = (0.84, 0.64, 0.52)
    backdrop(c, rng, (0.52, 0.5, 0.46))
    torso(c, rng, (0.86, 0.84, 0.8), 0.92)
    neck(c, skin, 0.82)
    c.lay(poly_mask([(CX - 32, 300), (CX - 30, 262), (CX + 30, 262), (CX + 32, 300), (CX, 308)], 1.2), np.asarray((0.88, 0.86, 0.82)) * (0.85 + 0.25 * strands(rng, False))[..., None], 82 + 0 * xs)
    c.lay(np.clip((1 - ell(CX, 300, 6, 6)) * 4, 0, 1), (0.75, 0.62, 0.3), 92 + 0 * xs, spec=1.0)  # collar button
    tube = np.clip(1 - np.abs(np.sqrt(ell(CX, 290, 62, 58)) - 1) * 30, 0, 1) * (ys > 300)
    c.lay(tube, (0.16, 0.15, 0.15), 96 + 0 * xs, spec=0.6)
    c.lay(np.clip((1 - ell(CX + 46, 352, 9, 9)) * 4, 0, 1), (0.66, 0.66, 0.66), 104 + dome(CX + 46, 352, 9, 9, 6)[0], spec=1.0)
    hair_back = np.clip((1 - ell(CX, CY - 8, 70, 82)) * 6, 0, 1) * (ys < CY + 40)
    c.lay(hair_back, np.asarray((0.4, 0.18, 0.09)) * (0.6 + 0.7 * strands(rng, False))[..., None], 40 + 0 * xs)
    head(c, rng, skin, fem=True, age=0.15)
    eyes(c, skin, iris=(0.24, 0.3, 0.2), brow=(0.36, 0.17, 0.09), fem=True)
    hair_cap(c, rng, (0.45, 0.2, 0.1), fem=True, bun=True)
    save("rose", c, rng, 0.45)


def elsie(rng):  # the schoolteacher: light brown hair under a bonnet, blue dress, a brooch
    c = Canvas()
    skin = (0.88, 0.7, 0.6)
    backdrop(c, rng, (0.54, 0.52, 0.48))
    torso(c, rng, (0.38, 0.45, 0.58), 0.9)
    neck(c, skin, 0.8)
    lace = np.clip(1 - np.abs(ys - (288 - np.abs(xs - CX) * 0.4)) / 6, 0, 1) * (np.abs(xs - CX) < 70)
    c.lay(lace, np.asarray((0.85, 0.83, 0.78)) * (0.75 + 0.4 * noise(rng, W // 6, H // 6, Image.NEAREST))[..., None], 84 + 0 * xs)
    c.lay(np.clip((1 - ell(CX, 310, 9, 11)) * 4, 0, 1), (0.78, 0.6, 0.3), 100 + dome(CX, 310, 9, 11, 8)[0], spec=1.0)
    c.lay(np.clip((1 - ell(CX, 310, 5, 6)) * 4, 0, 1), (0.5, 0.18, 0.2), 108 + 0 * xs, spec=0.8)
    hair_back = np.clip((1 - ell(CX, CY + 4, 68, 84)) * 6, 0, 1) * (ys < CY + 58)
    c.lay(hair_back, np.asarray((0.58, 0.4, 0.2)) * (0.6 + 0.7 * strands(rng, False))[..., None], 40 + 0 * xs)
    head(c, rng, skin, fem=True, age=0.0)
    eyes(c, skin, iris=(0.26, 0.34, 0.42), brow=(0.46, 0.32, 0.17), fem=True)
    hair_cap(c, rng, (0.6, 0.42, 0.2), fem=True)
    hat_bonnet(c, rng, (0.56, 0.4, 0.42))
    save("elsie", c, rng, 0.45)


def sam(rng):  # the old trapper: deep-lined, sun-dark, a long white beard and a fur cap
    c = Canvas()
    skin = (0.68, 0.48, 0.35)
    backdrop(c, rng, (0.5, 0.47, 0.42))
    torso(c, rng, (0.42, 0.32, 0.22), 1.05)
    fringe = (np.sin(xs * 1.4) > 0) * np.clip(1 - np.abs(ys - 330) / 10, 0, 1) * (np.abs(xs - CX) > 50)
    c.paint(fringe, (0.3, 0.22, 0.14), 0.6)
    neck(c, skin, 1.0)
    head(c, rng, skin, age=1.4, jaw=1.02)
    eyes(c, skin, iris=(0.3, 0.3, 0.28), brow=(0.82, 0.8, 0.76), squint=0.6)
    hair_cap(c, rng, (0.82, 0.8, 0.76))
    for sx in (-1, 1):
        hh = np.clip((1 - ell(CX + sx * 58, CY + 6, 12, 40)) * 5, 0, 1)
        c.lay(hh, np.asarray((0.8, 0.78, 0.74)) * (0.6 + 0.6 * strands(rng, False))[..., None], dome(CX, CY, 70, 84, 104)[0])
    beard(c, rng, (0.84, 0.82, 0.78), full=True, long=0.8)
    hat_fur(c, rng, (0.48, 0.34, 0.2))
    save("sam", c, rng, 0.5)


def tom(rng):  # the blacksmith: broad, black hair and beard, rolled grey shirt, leather apron
    c = Canvas()
    skin = (0.76, 0.54, 0.4)
    backdrop(c, rng, (0.48, 0.45, 0.4))
    torso(c, rng, (0.55, 0.52, 0.47), 1.15)
    apron = poly_mask([(CX - 70, 420), (CX - 62, 316), (CX - 40, 300), (CX + 40, 300), (CX + 62, 316), (CX + 70, 420)], 1.2)
    c.lay(apron, np.asarray((0.32, 0.21, 0.13)) * (0.75 + 0.45 * fbm(rng, 12, 4))[..., None], dome(CX, 420, 210, 150, 66)[0] + 5, spec=0.3)
    neck(c, skin, 1.2)
    head(c, rng, skin, age=0.35, jaw=1.12)
    eyes(c, skin, iris=(0.2, 0.15, 0.1), brow=(0.1, 0.08, 0.07), squint=0.15)
    hair_cap(c, rng, (0.12, 0.1, 0.09))
    beard(c, rng, (0.13, 0.11, 0.1), full=True)
    c.paint(np.clip(fbm(rng, 40, 2) - 0.55, 0, 1) * 2 * (ell(CX, CY + 6, 60, 80) < 1), (0.15, 0.12, 0.1), 0.25)  # soot
    save("tom", c, rng, 0.5)


import sys
only = sys.argv[1:] or ["bill", "henry", "rose", "elsie", "sam", "tom"]
for name in only:
    globals()[name](np.random.default_rng(sum(map(ord, name)) + 7))
