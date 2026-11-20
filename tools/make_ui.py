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


def streaks(w, h, rows, blur_x, blur_y):
    # noise stretched along x: long horizontal grain streaks
    n = Image.fromarray((rng.random((rows, max(2, w // 40))) * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    return np.asarray(n.filter(ImageFilter.BoxBlur(1)), np.float32) / 255


def wood(w, h):
    """Weathered honey-tan board: fine wavy grain lines, long sun-bleached streaks, faint grime."""
    blot = np.asarray(Image.fromarray((rng.random((4, 8)) * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC), np.float32) / 255
    base = np.array([0.76, 0.55, 0.30])
    rgb = base * (0.9 + 0.2 * blot[..., None])
    # grain: many thin, slightly wavy lines running the length of the board
    gl = Image.new("L", (w, h), 0)
    gd = ImageDraw.Draw(gl)
    y = -2.0 * SS
    while y < h + 2 * SS:
        y += rng.uniform(0.8, 2.6) * SS
        ph, amp = rng.uniform(0, 6), rng.uniform(0.3, 2.0) * SS
        pts = [(x, y + math.sin(x / w * rng.uniform(2, 5) + ph) * amp) for x in np.linspace(-10, w + 10, 24)]
        gd.line(pts, fill=int(rng.uniform(25, 140)), width=max(1, int(rng.uniform(0.4, 1.1) * SS)))
    grain = np.asarray(gl.filter(ImageFilter.GaussianBlur(0.35 * SS)), np.float32)[..., None] / 255
    rgb = rgb * (1 - grain * 0.55) + np.array([0.42, 0.25, 0.1]) * grain * 0.55
    # pale bleached streaks along the grain
    sc = Image.new("L", (w, h), 0)
    sd = ImageDraw.Draw(sc)
    for _ in range(int(w * h / (500 * SS * SS))):
        x0, y0 = rng.uniform(-40, w), rng.uniform(0, h)
        ln = rng.uniform(25, 150) * SS
        pts = [(x0 + ln * k / 8, y0 + math.sin(k * 0.8 + rng.random()) * SS * 0.8) for k in range(9)]
        sd.line(pts, fill=int(rng.uniform(60, 210)), width=max(1, int(rng.uniform(0.4, 1.6) * SS)))
    pale = np.asarray(sc.filter(ImageFilter.GaussianBlur(0.5 * SS)), np.float32)[..., None] / 255
    rgb = rgb * (1 - pale * 0.75) + np.array([0.95, 0.86, 0.7]) * pale * 0.75
    # faint dark grime patches
    gr = np.asarray(Image.fromarray((rng.random((18, 5)) * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC), np.float32) / 255
    rgb *= (1 - np.clip(gr - 0.6, 0, 1) * 0.55)[..., None]  # stretched along x so grime follows the grain
    return np.clip(rgb, 0, 1)


def chipped_mask(w, h, radius):
    """Rounded board outline with a few splintered notches on the edges, like old boards."""
    m = Image.new("L", (w, h), 0)
    md = ImageDraw.Draw(m)
    md.rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, fill=255)
    for _ in range(7):
        side = rng.integers(4)
        d = rng.uniform(2, 5) * SS
        if side < 2:  # left/right ends get V-shaped splinters
            x = 0 if side == 0 else w - 1
            y = rng.uniform(0.15, 0.85) * h
            s = 1 if side == 0 else -1
            md.polygon([(x, y - d * 1.6), (x + s * d, y), (x, y + d * 0.8)], fill=0)
        else:
            y = 0 if side == 2 else h - 1
            x = rng.uniform(0.1, 0.9) * w
            s = 1 if side == 2 else -1
            md.polygon([(x - d * 2.2, y), (x, y + s * d * 0.7), (x + d * 1.4, y)], fill=0)
    return m


def straw(d, cx, cy, ang, spread, n, length, front=False):
    for _ in range(n):
        # walk the stalk in small steps, turning more toward the tip so it curls instead of poking straight out
        heading = ang + rng.uniform(-spread, spread)
        ln = length * rng.uniform(0.55, 1.0) * SS
        curl = rng.uniform(0.3, 1.0) * rng.choice([-1, 1])
        kink = rng.random() < 0.3
        steps = 16
        x, y = cx, cy
        pts = [(x, y)]
        for k in range(steps):
            t = k / steps
            heading += curl / steps * (0.5 + 1.5 * t)
            if kink and k == steps // 2:
                heading += rng.uniform(-0.8, 0.8)  # a bent, broken-looking stalk
            x += math.cos(heading) * ln / steps
            y += math.sin(heading) * ln / steps
            pts.append((x, y))
        c = [(232, 200, 120), (214, 176, 92), (196, 156, 74), (240, 214, 140), (176, 138, 62)][rng.integers(5)]
        hi = tuple(min(255, v + 35) for v in c)
        w0 = rng.uniform(2.2, 3.4) * SS
        for layer, (off, col, scale) in enumerate([(SS, (45, 28, 10, 110), 1.25), (0, c + (255,), 1.0), (-0.5 * SS, hi + (200,), 0.35)]):
            for k in range(steps):
                wd = max(1, int(w0 * scale * (1.0 - 0.8 * k / steps)))  # taper toward the tip
                a, b = pts[k], pts[k + 1]
                d.line([(a[0] + off, a[1] + off), (b[0] + off, b[1] + off)], fill=col, width=wd)
                r = wd / 2  # round joints so the curve stays smooth
                d.ellipse([b[0] + off - r, b[1] + off - r, b[0] + off + r, b[1] + off + r], fill=col)


def draw_board(img, i, pw, ph, all_corners=False, frame=9):
    """Weathered honey board pasted at (i, i): shadow, thickness, chipped face, inner frame, screws."""
    # weathered board: drop shadow, darker side for thickness, chipped face, raised inner frame, screws
    thick = 4 * SS
    fh = ph - thick
    mask = chipped_mask(pw, fh, 7 * SS)
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    shadow.paste((25, 15, 5, 120), (i, i + thick + 2 * SS), mask)
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(3 * SS)))
    side = Image.fromarray((wood(pw, fh) * 0.45 * 255).astype(np.uint8)).convert("RGBA")
    img.paste(side, (i, i + thick), mask)

    face = wood(pw, fh)
    m = np.asarray(mask, np.float32) / 255
    soft = np.asarray(mask.filter(ImageFilter.GaussianBlur(2.5 * SS)), np.float32) / 255
    face *= (0.72 + 0.28 * soft)[..., None]  # edges a touch darker, worn
    yy = np.arange(fh)[:, None] / fh
    face *= (1.06 - 0.12 * yy)[..., None]  # light from above
    plank = Image.fromarray((np.clip(face, 0, 1) * 255).astype(np.uint8)).convert("RGBA")
    pd = ImageDraw.Draw(plank, "RGBA")
    fi = frame * SS  # inner frame inset
    box = [fi, fi * 0.85, pw - fi, fh - fi * 0.85]
    pd.rounded_rectangle([box[0] + SS, box[1] + SS, box[2] + SS, box[3] + SS], radius=4 * SS, outline=(255, 235, 200, 45), width=int(1.6 * SS))
    pd.rounded_rectangle(box, radius=4 * SS, outline=(70, 40, 15, 170), width=int(1.6 * SS))
    rows = (box[1] + 7 * SS, box[3] - 7 * SS) if all_corners else (box[1] + 7 * SS,)
    for sx, sy in [(x, y) for x in (box[0] + 7 * SS, box[2] - 7 * SS) for y in rows]:  # screws, like the reference board
        r = 3.4 * SS
        pd.ellipse([sx - r + SS, sy - r + SS, sx + r + SS, sy + r + SS], fill=(30, 18, 8, 110))
        for k in range(8):  # radial gradient: brushed steel head lit from the top-left
            f = 1 - k / 8
            c = int(120 + 120 * (1 - f))
            pd.ellipse([sx - r * f - (1 - f) * SS, sy - r * f - (1 - f) * SS, sx + r * f - (1 - f) * SS, sy + r * f - (1 - f) * SS], fill=(c, c, c + 4, 255))
        pd.ellipse([sx - r, sy - r, sx + r, sy + r], outline=(70, 70, 72, 255), width=int(0.6 * SS))
        a = rng.uniform(0, math.pi)
        dx, dy = math.cos(a) * r * 0.7, math.sin(a) * r * 0.7
        pd.line([sx - dx, sy - dy, sx + dx, sy + dy], fill=(60, 60, 64, 255), width=int(0.9 * SS))
    img.paste(plank, (i, i), mask)


def button():
    w, h = W * SS, H * SS
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")  # blend mode, so the soft stalk shadows stay translucent
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
    draw_board(img, i, w - 2 * i, h - 2 * i)
    # a few stalks in front so the straw wraps around the board
    for (cx, cy, ang) in [(i + 4 * SS, i + 18 * SS, -2.9), (w - i - 4 * SS, h - i - 16 * SS, 0.3)]:
        straw(ImageDraw.Draw(img, "RGBA"), cx, cy, ang, 0.4, 5, 24)
    img = img.resize((W, H), Image.LANCZOS)
    img.save(OUT / "wood_button.png")


PW, PH = 360, 280
PIN = 26


def panel():
    """Big board for the build menu (9-slice): straw tufts at the corners, four screws."""
    w, h = PW * SS, PH * SS
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    i = PIN * SS
    for (cx, cy, ang) in [(i + 14 * SS, i + 10 * SS, -2.4), (w - i - 14 * SS, i + 10 * SS, -0.75),
                          (i + 14 * SS, h - i - 10 * SS, 2.4), (w - i - 14 * SS, h - i - 10 * SS, 0.75)]:
        straw(d, cx, cy, ang, 0.85, 34, 44)
    draw_board(img, i, w - 2 * i, h - 2 * i, all_corners=True, frame=14)
    for (cx, cy, ang) in [(i + 4 * SS, i + 26 * SS, -2.9), (w - i - 4 * SS, h - i - 24 * SS, 0.3)]:
        straw(ImageDraw.Draw(img, "RGBA"), cx, cy, ang, 0.4, 6, 30)
    img.resize((PW, PH), Image.LANCZOS).save(OUT / "wood_panel.png")


# ---------- icons: cream fill, dark brown outline, drawn at 4x ----------
S = 64 * SS
CREAM = (250, 236, 200, 255)
INK = (55, 30, 12, 255)


BRASS = np.array([0.80, 0.62, 0.32])
IRON = np.array([0.20, 0.15, 0.10])
PAD = 16 * SS  # room for the drop shadow


def blur(a, r):
    return np.asarray(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r)), np.float32) / 255


def icon(name, draw_fn):
    # 1. flat drawing: cream = raised plate, dark ink = engraved grooves, colored = painted parts
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(img), lambda v: v * SS)
    a = np.pad(np.asarray(img, np.float32) / 255, ((PAD, PAD), (PAD, PAD), (0, 0)))
    rgb, alpha = a[..., :3], a[..., 3]
    sat = rgb.max(-1) - rgb.min(-1)
    ink = (rgb.mean(-1) < 0.35) & (sat < 0.25) & (alpha > 0)
    painted = (sat > 0.25) & ~ink
    # 2. height map -> normals -> light from the top-left: gives the stamped-metal relief
    height = blur(alpha * np.where(ink, 0.35, 1.0), 2.2 * SS)
    gy, gx = np.gradient(height * 90)
    n = np.dstack([-gx, -gy, np.ones_like(gx)])
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    light = np.array([-0.55, -0.6, 0.58])
    shade = np.clip(n @ (light / np.linalg.norm(light)), 0, 1)
    # 3. worn brass: blotchy patina, fine grain and scratches; painted parts keep their color, chipped
    h, w = alpha.shape
    blotch = blur(rng.random((h, w)), 9 * SS)
    blotch = (blotch - blotch.min()) / (np.ptp(blotch) + 1e-6)
    grain = blur(rng.random((h, w)), 0.8 * SS)
    col = np.where(painted[..., None], rgb * 0.85, BRASS * (0.6 + 0.65 * blotch[..., None]))
    col = np.where(ink[..., None], IRON, col)
    col *= (0.72 + 0.5 * grain[..., None])
    col *= (0.55 + 0.45 * blur(alpha, 2.5 * SS))[..., None]  # grime collects toward the edges
    scratches = Image.new("L", (w, h), 0)
    sd = ImageDraw.Draw(scratches)
    for _ in range(26):
        x0, y0 = rng.uniform(0, w), rng.uniform(0, h)
        r, t = rng.uniform(6, 22) * SS, rng.uniform(0, math.pi)
        sd.line([x0, y0, x0 + math.cos(t) * r, y0 + math.sin(t) * r], fill=255, width=max(1, SS // 2))
    col = col * (1 - 0.45 * (np.asarray(scratches, np.float32) / 255)[..., None])
    col = col * (0.45 + 0.85 * shade[..., None]) + (shade ** 14)[..., None] * 0.35  # diffuse + glint
    # 4. soft drop shadow under the plate
    sh = np.roll(np.roll(blur(alpha, 3 * SS), 3 * SS, 0), 2 * SS, 1) * 0.6
    out_a = alpha + sh * (1 - alpha)
    out_rgb = np.where(alpha[..., None] > 0, col, 0.05) * (alpha / np.maximum(out_a, 1e-4))[..., None]
    out = np.dstack([np.clip(out_rgb, 0, 1), np.clip(out_a, 0, 1)])
    Image.fromarray((out * 255).astype(np.uint8)).resize((96, 96), Image.LANCZOS).save(OUT / "icons" / f"{name}.png")


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


def cow(d, k):
    for x in (14, 21, 37, 44):  # legs behind the body
        d.rectangle([k(x), k(38), k(x + 5), k(58)], fill=CREAM, outline=INK, width=k(3))
    d.line([k(9), k(28), k(5), k(46)], fill=INK, width=k(3))  # tail
    d.rounded_rectangle([k(8), k(22), k(48), k(44)], radius=k(9), fill=CREAM, outline=INK, width=k(3))
    d.line([k(48), k(24), k(46), k(14)], fill=INK, width=k(3))  # horns
    d.line([k(55), k(25), k(60), k(16)], fill=INK, width=k(3))
    shape(d, [(44, 22), (58, 24), (61, 38), (53, 44), (45, 34)], k)


def hay(d, k):  # square bale with twine and straw ends
    d.rounded_rectangle([k(6), k(18), k(58), k(50)], radius=k(4), fill=CREAM, outline=INK, width=k(3))
    for y in (24, 31, 38, 45):
        d.line([k(9), k(y), k(55), k(y)], fill=INK, width=k(1))
    for x in (22, 42):
        d.line([k(x), k(18), k(x), k(50)], fill=(150, 50, 35, 255), width=k(3))
    for x in (8, 14, 50, 56):
        d.line([k(x), k(18), k(x - 2), k(11)], fill=INK, width=k(2))


def market(d, k):  # money bag tied at the neck, with a coin
    d.ellipse([k(10), k(22), k(50), k(60)], fill=CREAM, outline=INK, width=k(3))
    shape(d, [(22, 24), (18, 10), (30, 14), (42, 10), (38, 24)], k)
    d.line([k(20), k(24), k(40), k(24)], fill=(150, 50, 35, 255), width=k(4))
    d.line([k(30), k(32), k(30), k(52)], fill=INK, width=k(3))  # $ stroke
    d.arc([k(23), k(33), k(37), k(43)], 90, 300, fill=INK, width=k(3))
    d.arc([k(23), k(41), k(37), k(51)], 270, 120, fill=INK, width=k(3))
    d.ellipse([k(44), k(44), k(60), k(60)], fill=(225, 180, 80, 255), outline=INK, width=k(3))


def land(d, k):  # fenced plot with a flag on a stake
    d.rectangle([k(6), k(26), k(58), k(58)], fill=(150, 175, 90, 255), outline=INK, width=k(3))
    for x in (6, 19, 32, 45, 58):
        d.line([k(x), k(22), k(x), k(30)], fill=INK, width=k(3))
    d.line([k(6), k(26), k(58), k(26)], fill=INK, width=k(2))
    d.line([k(32), k(46), k(32), k(6)], fill=INK, width=k(3))
    shape(d, [(32, 6), (52, 12), (32, 18)], k)


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


def vet(d, k):  # doctor's bag with a red cross
    d.arc([k(22), k(6), k(42), k(26)], 180, 360, fill=INK, width=k(4))
    d.rounded_rectangle([k(6), k(16), k(58), k(56)], radius=k(6), fill=CREAM, outline=INK, width=k(3))
    d.line([k(6), k(26), k(58), k(26)], fill=INK, width=k(2))
    d.rectangle([k(28), k(30), k(36), k(52)], fill=(190, 45, 35, 255))
    d.rectangle([k(21), k(37), k(43), k(45)], fill=(190, 45, 35, 255))


def vaccine(d, k):  # syringe, needle to the lower left
    shape(d, [(22, 34), (44, 12), (52, 20), (30, 42)], k)
    d.line([k(26), k(38), k(10), k(54)], fill=INK, width=k(3))  # needle
    for t in (0.3, 0.5, 0.7):  # dose marks
        x, y = 22 + 22 * t, 34 - 22 * t
        d.line([k(x), k(y), k(x + 4), k(y + 4)], fill=INK, width=k(2))
    d.line([k(48), k(16), k(56), k(8)], fill=INK, width=k(4))  # plunger
    d.line([k(52), k(4), k(60), k(12)], fill=INK, width=k(4))
    d.line([k(40), k(10), k(54), k(24)], fill=INK, width=k(3))  # finger grip
    shape(d, [(25, 33), (36, 22), (40, 26), (29, 37)], k)
    d.polygon([(k(26), k(34)), (k(36), k(24)), (k(39), k(27)), (k(29), k(37))], fill=(120, 170, 200, 255))


def worker(d, k):  # cowboy hat
    d.ellipse([k(4), k(36), k(60), k(52)], fill=CREAM, outline=INK, width=k(3))  # brim
    shape(d, [(18, 42), (20, 18), (27, 14), (32, 19), (37, 14), (44, 18), (46, 42)], k)  # pinched crown
    d.line([k(19), k(36), k(45), k(36)], fill=(150, 50, 35, 255), width=k(5))  # hat band


def star(d, k):  # lawman's star with balls on its points
    pts = []
    for i in range(10):
        r = 28 if i % 2 == 0 else 12
        a = math.radians(-90 + i * 36)
        pts.append((32 + math.cos(a) * r, 33 + math.sin(a) * r))
    shape(d, pts, k)
    for i in range(5):
        a = math.radians(-90 + i * 72)
        x, y = 32 + math.cos(a) * 28, 33 + math.sin(a) * 28
        d.ellipse([k(x - 4), k(y - 4), k(x + 4), k(y + 4)], fill=CREAM, outline=INK, width=k(2))
    d.ellipse([k(26), k(27), k(38), k(39)], fill=(150, 50, 35, 255), outline=INK, width=k(2))


def stable(d, k):  # horseshoe, open end up
    d.arc([k(10), k(12), k(54), k(60)], 330, 210, fill=INK, width=k(16))
    d.arc([k(10), k(12), k(54), k(60)], 330, 210, fill=CREAM, width=k(10))
    for a in (0, 40, 90, 140, 180):
        r = math.radians(a)
        x, y = 32 + math.cos(r) * 19, 36 + math.sin(r) * 21
        d.ellipse([k(x - 1.5), k(y - 1.5), k(x + 1.5), k(y + 1.5)], fill=INK)


def smithy(d, k):  # anvil on a block
    shape(d, [(6, 18), (44, 18), (58, 22), (46, 30), (40, 30), (36, 40), (44, 46), (20, 46), (26, 40), (22, 30), (6, 26)], k)
    d.rectangle([k(18), k(46), k(46), k(58)], fill=(150, 50, 35, 255), outline=INK, width=k(3))


def rodeo(d, k):  # lasso: a loop of rope with a trailing end
    d.ellipse([k(8), k(10), k(56), k(44)], outline=INK, width=k(9))
    d.ellipse([k(8), k(10), k(56), k(44)], outline=CREAM, width=k(4))
    d.line([k(14), k(36), k(8), k(58)], fill=INK, width=k(9))
    d.line([k(14), k(36), k(8), k(58)], fill=CREAM, width=k(4))
    d.ellipse([k(10), k(30), k(20), k(40)], fill=(150, 50, 35, 255), outline=INK, width=k(2))


def pond(d, k):  # water drop over ripples
    d.ellipse([k(6), k(42), k(58), k(60)], fill=CREAM, outline=INK, width=k(3))
    d.ellipse([k(18), k(47), k(46), k(55)], outline=INK, width=k(2))
    shape(d, [(32, 4), (44, 24), (46, 32), (40, 40), (32, 42), (24, 40), (18, 32), (20, 24)], k)
    d.polygon([(k(32), k(10)), (k(40), k(25)), (k(41), k(32)), (k(36), k(37)), (k(32), k(38)), (k(26), k(35)), (k(23), k(30)), (k(25), k(24))], fill=(90, 150, 190, 255))


def kennel(d, k):  # doghouse with a round door
    shape(d, [(12, 58), (12, 30), (52, 30), (52, 58)], k)
    shape(d, [(4, 32), (32, 8), (60, 32), (54, 36), (32, 16), (10, 36)], k)
    d.polygon([(k(12), k(30)), (k(32), k(14)), (k(52), k(30))], fill=(150, 50, 35, 255), outline=INK)
    d.pieslice([k(22), k(36), k(42), k(60)], 180, 360, fill=INK)
    d.rectangle([k(22), k(48), k(42), k(58)], fill=INK)


def tower(d, k):  # lookout tower with a pointed roof
    d.line([k(18), k(60), k(25), k(28)], fill=INK, width=k(4))
    d.line([k(46), k(60), k(39), k(28)], fill=INK, width=k(4))
    for y in (38, 50):
        d.line([k(22), k(y + 5), k(42), k(y - 5)], fill=INK, width=k(2))
        d.line([k(42), k(y + 5), k(22), k(y - 5)], fill=INK, width=k(2))
    shape(d, [(18, 22), (46, 22), (46, 30), (18, 30)], k)
    d.line([k(21), k(22), k(21), k(13)], fill=INK, width=k(3))
    d.line([k(43), k(22), k(43), k(13)], fill=INK, width=k(3))
    shape(d, [(12, 15), (32, 3), (52, 15)], k)
    d.rectangle([k(29), k(16), k(35), k(21)], fill=(230, 170, 60, 255))


def feedlot(d, k):  # feed trough heaped with hay, on legs
    for x in (12, 48):
        d.line([k(x), k(44), k(x - 2), k(60)], fill=INK, width=k(4))
        d.line([k(x + 4), k(44), k(x + 6), k(60)], fill=INK, width=k(4))
    d.pieslice([k(12), k(8), k(52), k(48)], 180, 360, fill=(220, 180, 80, 255), outline=INK, width=k(2))
    for x in (20, 28, 36, 44):
        d.line([k(x), k(28), k(x - 3), k(18)], fill=INK, width=k(1))
    shape(d, [(4, 28), (60, 28), (54, 46), (10, 46)], k)
    d.line([k(8), k(37), k(56), k(37)], fill=INK, width=k(2))


def saloon(d, k):  # coffee pot
    shape(d, [(18, 58), (14, 28), (20, 18), (44, 18), (50, 28), (46, 58)], k)
    shape(d, [(26, 18), (24, 10), (40, 10), (38, 18)], k)
    d.ellipse([k(29), k(3), k(35), k(9)], fill=CREAM, outline=INK, width=k(2))
    d.arc([k(42), k(24), k(62), k(48)], 280, 80, fill=INK, width=k(4))  # handle
    shape(d, [(16, 30), (4, 22), (4, 27), (14, 36)], k)  # spout
    d.rectangle([k(16), k(36), k(48), k(42)], fill=(150, 50, 35, 255))


def train(d, k):  # steam engine
    shape(d, [(30, 20), (56, 20), (56, 48), (30, 48)], k)  # cab
    d.rectangle([k(36), k(25), k(50), k(34)], fill=INK)
    shape(d, [(6, 30), (32, 30), (32, 48), (6, 48)], k)  # boiler
    shape(d, [(10, 30), (10, 14), (18, 14), (18, 30)], k)  # stack
    shape(d, [(7, 14), (21, 14), (19, 9), (9, 9)], k)
    shape(d, [(2, 48), (8, 40), (8, 48)], k)  # cowcatcher
    for x, r in ((14, 6), (28, 6), (46, 8)):
        d.ellipse([k(x - r), k(54 - r), k(x + r), k(54 + r)], fill=(150, 50, 35, 255), outline=INK, width=k(3))


def corral(d, k):  # rail fence with the gate swung open
    for y in (24, 37, 50):
        shape(d, [(4, y - 3), (24, y - 3), (24, y + 3), (4, y + 3)], k)
        shape(d, [(40, y - 3), (60, y - 3), (60, y + 3), (40, y + 3)], k)
    for x in (6, 22, 42, 58):
        shape(d, [(x - 3.5, 14), (x + 3.5, 14), (x + 3.5, 60), (x - 3.5, 60)], k)
    shape(d, [(26, 20), (38, 28), (38, 54), (26, 46)], k)


def horse(d, k):  # a horse's head in profile, mane flying
    d.polygon([(k(38), k(6)), (k(52), k(12)), (k(60), k(30)), (k(61), k(52)), (k(56), k(60)), (k(50), k(40)), (k(44), k(16))], fill=(150, 50, 35, 255), outline=INK, width=k(3))
    shape(d, [(38, 6), (46, 14), (52, 30), (56, 60), (30, 60), (28, 46), (18, 40), (8, 38), (4, 32), (8, 24), (22, 14), (32, 10)], k)
    shape(d, [(34, 12), (37, 1), (42, 11)], k)
    d.ellipse([k(27), k(18), k(32), k(23)], fill=INK)
    d.ellipse([k(7), k(30), k(11), k(34)], fill=INK)


def gear(d, k):  # settings: a cog with eight teeth and a hole in the middle
    pts = []
    for i in range(8):
        a = math.radians(i * 45)
        for da, r in ((-13, 20), (-8, 28), (8, 28), (13, 20)):
            b = a + math.radians(da)
            pts.append((32 + math.cos(b) * r, 32 + math.sin(b) * r))
    shape(d, pts, k)
    d.ellipse([k(22), k(22), k(42), k(42)], fill=(150, 50, 35, 255), outline=INK, width=k(3))
    d.ellipse([k(28), k(28), k(36), k(36)], fill=INK)



def arrow(d, k):  # the tutorial's pointer: a fat arrow pointing down
    pts = [(22, 4), (42, 4), (42, 30), (56, 30), (32, 60), (8, 30), (22, 30)]
    d.polygon([(k(x), k(y)) for x, y in pts], fill=(225, 90, 50, 255), outline=INK, width=k(3))



def gift(d, k):  # the daily prize: a box tied with ribbon and a bow
    d.rectangle([k(8), k(26), k(56), k(60)], fill=(150, 50, 35, 255), outline=INK, width=k(3))
    d.rectangle([k(4), k(18), k(60), k(28)], fill=(150, 50, 35, 255), outline=INK, width=k(3))
    shape(d, [(28, 18), (36, 18), (36, 60), (28, 60)], k)
    shape(d, [(32, 18), (18, 6), (12, 12), (20, 18)], k)
    shape(d, [(32, 18), (46, 6), (52, 12), (44, 18)], k)


def trophy(d, k):  # the fair's cup: a bowl with two handles on a stem and a stepped base
    d.arc([k(4), k(12), k(22), k(32)], 90, 270, fill=INK, width=k(4))
    d.arc([k(42), k(12), k(60), k(32)], 270, 90, fill=INK, width=k(4))
    shape(d, [(14, 8), (50, 8), (48, 22), (42, 32), (36, 36), (28, 36), (22, 32), (16, 22)], k)
    shape(d, [(28, 36), (36, 36), (36, 46), (28, 46)], k)
    shape(d, [(20, 46), (44, 46), (44, 52), (20, 52)], k)
    shape(d, [(14, 52), (50, 52), (50, 60), (14, 60)], k)
    d.ellipse([k(27), k(14), k(37), k(24)], fill=(150, 50, 35, 255), outline=INK, width=k(2))


def book(d, k):  # the collection book: a thick book with a red spine, a bookmark and a star on the cover
    shape(d, [(12, 6), (52, 6), (52, 58), (12, 58)], k)
    d.rectangle([k(12), k(6), k(20), k(58)], fill=(150, 50, 35, 255), outline=INK, width=k(3))
    d.polygon([(k(40), k(58)), (k(46), k(58)), (k(46), k(64)), (k(43), k(61)), (k(40), k(64))], fill=(150, 50, 35, 255), outline=INK)
    pts = []
    for i in range(10):
        r = 12 if i % 2 == 0 else 5
        a = math.radians(-90 + i * 36)
        pts.append((k(36 + math.cos(a) * r), k(30 + math.sin(a) * r)))
    d.polygon(pts, fill=INK)


def party(d, k):  # a festival: a string of little flags
    def y(x):
        return 10 + 12 * math.sin(math.pi * (x - 2) / 60)
    d.line([(k(x), k(y(x))) for x in range(2, 63, 3)], fill=INK, width=k(3))
    for i, c in enumerate([(150, 50, 35, 255), None, (60, 120, 50, 255), (150, 50, 35, 255)]):
        x0, x1 = 4 + i * 14.5, 16 + i * 14.5
        pts = [(x0, y(x0)), (x1, y(x1)), ((x0 + x1) / 2, (y(x0) + y(x1)) / 2 + 30)]
        if c is None:
            shape(d, pts, k)
        else:
            d.polygon([(k(px), k(py)) for px, py in pts], fill=c, outline=INK, width=k(2))


button()
panel()
for n, f in dict(land=land, market=market, hay=hay, cow=cow, barn=barn, house=house, silo=silo, windmill=windmill, build=build, rotate=rotate, cancel=cancel, place=place, vet=vet, vaccine=vaccine, worker=worker, star=star, stable=stable, smithy=smithy, rodeo=rodeo, pond=pond, kennel=kennel, tower=tower, feedlot=feedlot, saloon=saloon, train=train, corral=corral, horse=horse, gear=gear, arrow=arrow, gift=gift, trophy=trophy, book=book, party=party).items():
    icon(n, f)
print("ok")
