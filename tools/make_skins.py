# Draws the four ranch looks for boards and buttons, lit like real materials (height map + light
# from the top left) instead of flat cartoon fills:
#   barn    weathered barn planks in a board frame, rusty iron corner brackets
#   saddle  saddle leather: basketweave-stamped border, stitching, brass conchos
#   poster  an old paper notice nailed on dark planks
#   rope    oak planks with a twisted rope around the edge
# Output: ../ui/skins/<name>/button.png and panel.png (9-slice; margins in ui_theme.gd SKINS).
import math
import sys
import numpy as np
from PIL import Image, ImageDraw
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "ui" / "skins"
SS = 2  # drawn at 2x, then scaled down for clean edges
rng = np.random.default_rng(11)

LIGHT = np.array([-0.42, -0.62, 0.66], np.float32)
LIGHT /= np.linalg.norm(LIGHT)
HALF = LIGHT + np.array([0, 0, 1], np.float32)
HALF /= np.linalg.norm(HALF)


# ---------------------------------------------------------------- basics

def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def box1(a, r, axis):
    if r < 1:
        return a
    pad = [(0, 0)] * a.ndim
    pad[axis] = (r + 1, r)
    c = np.cumsum(np.pad(a, pad, mode="edge"), axis=axis, dtype=np.float64)
    n = a.shape[axis]
    hi = np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=axis)
    lo = np.take(c, np.arange(0, n), axis=axis)
    return ((hi - lo) / (2 * r + 1)).astype(np.float32)


def blur(a, sigma):
    """Gaussian-ish blur: three box passes."""
    r = int(round((math.sqrt(4 * sigma * sigma + 1) - 1) / 2))
    for _ in range(3):
        a = box1(box1(a, r, 0), r, 1)
    return a


def noise(w, h, cx, cy):
    """Smooth value noise with cells cx by cy pixels."""
    cx, cy = max(cx, 1.0), max(cy, 1.0)
    gw, gh = int(w / cx) + 4, int(h / cy) + 4
    g = rng.random((gh, gw)).astype(np.float32)
    big = Image.fromarray(g, "F").resize((int(math.ceil(gw * cx)), int(math.ceil(gh * cy))), Image.BICUBIC)
    a = np.asarray(big)
    ox, oy = int(cx), int(cy)
    return a[oy:oy + h, ox:ox + w]


def fbm(w, h, cx, cy, octaves=4, gain=0.5):
    s, amp, tot = 0.0, 1.0, 0.0
    for _ in range(octaves):
        s = s + amp * noise(w, h, cx, cy)
        tot += amp
        amp *= gain
        cx /= 2.0
        cy /= 2.0
    return s / tot


def shade(alb, H, bump=1.0, spec=None, shin=24.0, amb=0.42, ao=0.0):
    """Lights an albedo with a height map: diffuse from the top left, optional specular, cavity darkening."""
    gy, gx = np.gradient(H * bump)
    n = np.stack([-gx, -gy, np.ones_like(H)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    ndl = np.clip(n @ LIGHT, 0, 1)
    lum = (amb + (1 - amb) * ndl) / (amb + (1 - amb) * LIGHT[2])
    rgb = alb * lum[..., None]
    if ao:
        cav = np.clip((blur(H, 6 * SS) - H) * ao, 0, 0.6)
        rgb *= (1 - cav)[..., None]
    if spec is not None:
        ndh = np.clip(n @ HALF, 0, 1)
        rgb += (spec * ndh ** shin)[..., None]
    return rgb


def mix(a, b, t):
    t = np.asarray(t, np.float32)
    if t.ndim == 2:
        t = t[..., None]
    return a * (1 - t) + b * t


def grid(w, h):
    Y, X = np.mgrid[0:h, 0:w].astype(np.float32)
    return X, Y


def mask_draw(w, h, fn):
    m = Image.new("L", (w, h), 0)
    fn(ImageDraw.Draw(m))
    return np.asarray(m, np.float32) / 255


def over(rgb, a, top_rgb, top_a, shadow=0.55, off=(3, 4), soft=4.0):
    """Lays a part over the picture with a soft shadow to the bottom right."""
    sh = np.roll(np.roll(top_a, int(off[1] * SS), 0), int(off[0] * SS), 1)
    sh = blur(sh, soft * SS) * shadow
    rgb = rgb * (1 - sh)[..., None]
    a2 = np.maximum(a, np.clip(sh * 1.2, 0, 1) * (a > 0))
    t = top_a[..., None]
    return rgb * (1 - t) + top_rgb * t, np.maximum(a2, top_a)


def save(rgb, a, w, h, path):
    img = np.dstack([np.clip(rgb, 0, 1), np.clip(a, 0, 1)])
    im = Image.fromarray((img * 255 + 0.5).astype(np.uint8), "RGBA").resize((w, h), Image.LANCZOS)
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)
    print("wrote", path, im.size)


# ---------------------------------------------------------------- wood

def wood(w, h, light, dark, ring=11.0, knots=0, weather=0.5, gray=0.0, cracks=0, contrast=1.0):
    """One board, grain along x. Returns albedo, height."""
    X, Y = grid(w, h)
    ring *= SS
    warp = (fbm(w, h, 520 * SS, 70 * SS, 3) - 0.5) * ring * 6 + (fbm(w, h, 220 * SS, 22 * SS, 2) - 0.5) * ring * 0.5
    v = Y + warp
    knot_core = np.zeros((h, w), np.float32)
    for _ in range(knots):
        kx, ky = rng.uniform(0.1, 0.9) * w, rng.uniform(0.25, 0.75) * h
        s = rng.uniform(5, 9) * SS
        dx, dy = (X - kx) / (s * 3.2), (Y - ky) / (s * 1.6)
        r2 = dx * dx + dy * dy
        v += np.sign(Y - ky) * s * 1.9 * np.exp(-r2 * 0.9)  # grain bends around the knot
        rc = np.sqrt(((X - kx) / (s * 1.3)) ** 2 + ((Y - ky) / (s * 0.75)) ** 2)
        knot_core = np.maximum(knot_core, smooth(1.4, 0.35, rc) * 0.85 + smooth(1.0, 0.0, rc) * 0.15)
    phase = v / ring + (fbm(w, h, 300 * SS, 30 * SS, 2) - 0.5) * 1.5
    f = phase - np.floor(phase)
    late = np.exp(-((f - 0.82) / 0.09) ** 2) * (0.45 + 0.9 * fbm(w, h, 600 * SS, ring * 1.3, 2))
    fibers = fbm(w, h, 70 * SS, 0.9 * SS, 3)
    pores = smooth(0.72, 0.9, noise(w, h, 9 * SS, 0.8 * SS))
    blot = fbm(w, h, 240 * SS, 70 * SS, 3)
    t = np.clip(0.18 + (0.55 * late + 0.35 * (fibers - 0.5) + 0.25 * pores) * contrast + 0.35 * (blot - 0.5), 0, 1)
    alb = mix(light, dark, t)
    if gray:
        g = alb.mean(-1, keepdims=True) * np.array([1.0, 0.98, 0.95])
        gm = np.clip(gray * (0.6 + 0.8 * (fbm(w, h, 300 * SS, 90 * SS, 3) - 0.3)), 0, 1)
        alb = mix(alb, g * 1.05, gm)
    alb = mix(alb, dark * 0.6, knot_core * 0.8)
    H = late * 1.2 * weather + fibers * 0.9 - knot_core * 0.8 + pores * -0.4
    if cracks:
        cm = Image.new("L", (w, h), 0)
        cd = ImageDraw.Draw(cm)
        for _ in range(cracks):
            x0 = rng.uniform(-0.1, 0.8) * w
            ln = rng.uniform(0.1, 0.35) * w
            y0 = rng.uniform(0.2, 0.8) * h
            pts = []
            for k in range(30):
                x = x0 + ln * k / 29
                xi = int(np.clip(x, 0, w - 1))
                yi = int(np.clip(y0, 0, h - 1))
                pts.append((x, y0 + (warp[yi, xi] if 0 <= x < w else 0) * 0.15 + rng.uniform(-0.3, 0.3) * SS))
            for k in range(29):
                wd = max(1, int(SS * 1.6 * math.sin(math.pi * (k + 0.5) / 29)))
                cd.line([pts[k], pts[k + 1]], fill=255, width=wd)
        c = np.asarray(cm, np.float32) / 255
        alb = mix(alb, dark * 0.3, c * 0.9)
        H -= c * 2.5
    return alb, H


def planks(w, h, sizes, light, dark, vertical=False, gap=2.5, bevel=4.0, seam=0.75, **kw):
    """Boards side by side: along y (horizontal boards) or along x (vertical)."""
    L = w if vertical else h
    edges = [0.0]
    while edges[-1] < L:
        edges.append(edges[-1] + rng.uniform(*sizes) * SS)
    edges[-1] = max(edges[-1], L)
    alb = np.zeros((h, w, 3), np.float32)
    H = np.zeros((h, w), np.float32)
    for a, b in zip(edges, edges[1:]):
        a0, b0 = int(a), int(min(b, L))
        n = b0 - a0
        if n <= 0:
            continue
        tone = rng.uniform(0.86, 1.1)
        if vertical:
            al, hh = wood(h, n, light * tone, dark * tone, **kw)
            al, hh = al.transpose(1, 0, 2), hh.T
            alb[:, a0:b0], H[:, a0:b0] = al, hh
        else:
            al, hh = wood(w, n, light * tone, dark * tone, **kw)
            alb[a0:b0], H[a0:b0] = al, hh
        # rounded board edges and a dark gap between boards
        d = np.minimum(np.arange(n) - 0.0, (n - 1) - np.arange(n)).astype(np.float32)
        prof = np.sqrt(np.clip(d / (bevel * SS), 0, 1)) * 2.5
        gapm = smooth(gap * SS * 0.5, 0, d)
        if vertical:
            H[:, a0:b0] += prof[None, :]
            alb[:, a0:b0] *= (1 - seam * gapm)[None, :, None]
        else:
            H[a0:b0] += prof[:, None]
            alb[a0:b0] *= (1 - seam * gapm)[:, None, None]
    return alb, H


def nail(rgb, a, H_unused, x, y, r, rusty=True):
    """A forged nail head: dome with a light top and rust."""
    hh, ww = a.shape
    s = int(r * 3)
    x0, y0 = int(x - s), int(y - s)
    X, Y = grid(2 * s, 2 * s)
    dx, dy = X - s, Y - s
    rr = np.sqrt(dx * dx + dy * dy) / r
    m = smooth(1.0, 0.9, rr)
    Hn = np.sqrt(np.clip(1 - rr ** 2, 0, 1)) * r * 0.5 + (noise(2 * s, 2 * s, 1.2 * SS, 1.2 * SS) - 0.5) * 0.6 * SS
    rust = smooth(0.4, 0.75, fbm(2 * s, 2 * s, 5 * SS, 5 * SS, 3)) if rusty else np.zeros_like(rr)
    alb = mix(np.array([0.22, 0.21, 0.2]), np.array([0.42, 0.21, 0.09]), rust * 0.85)
    col = shade(alb, Hn, 1.0, spec=(1 - rust) * 0.35, shin=30)
    sl = (slice(max(0, y0), min(hh, y0 + 2 * s)), slice(max(0, x0), min(ww, x0 + 2 * s)))
    cs = (slice(sl[0].start - y0, sl[0].stop - y0), slice(sl[1].start - x0, sl[1].stop - x0))
    top_a = np.zeros_like(a)
    top_rgb = np.zeros_like(rgb)
    top_a[sl] = m[cs]
    top_rgb[sl] = col[cs]
    return over(rgb, a, top_rgb, top_a, shadow=0.6, off=(1.2, 1.6), soft=1.4)


# ---------------------------------------------------------------- metal

def iron(w, h, mask, rust_amt=0.55):
    """Hand-forged iron: hammered dimples, rounded edges, rust. Returns rgb lit."""
    edge = blur(mask, 2.5 * SS)
    dots = (rng.random((h, w)) > 0.9975).astype(np.float32)
    dimples = blur(dots, 3.0 * SS) * 40
    H = edge * 6 - dimples + (fbm(w, h, 3 * SS, 3 * SS, 2) - 0.5) * 0.8
    rust = smooth(0.42, 0.7, fbm(w, h, 40 * SS, 40 * SS, 5) * rust_amt + (1 - edge) * 0.35 + 0.18)
    flake = smooth(0.6, 0.8, noise(w, h, 2 * SS, 2 * SS)) * rust
    alb = mix(np.array([0.17, 0.165, 0.16]), np.array([0.38, 0.19, 0.08]), rust)
    alb = mix(alb, np.array([0.55, 0.29, 0.12]), flake * 0.6)
    H += flake * 0.8
    return shade(alb, H, 1.0, spec=(1 - rust) * 0.45, shin=28, ao=0.08)


def rivets(rgb, a, pts, r):
    for x, y in pts:
        rgb, a = nail(rgb, a, None, x, y, r)
    return rgb, a


def brass(w, h, cx, cy, R, lobes=12):
    """A saddle concho: scalloped brass dome with an engraved ring and a screw in the middle."""
    X, Y = grid(w, h)
    dx, dy = X - cx, Y - cy
    th = np.arctan2(dy, dx)
    rr = np.sqrt(dx * dx + dy * dy) / (R * (1 + 0.07 * np.cos(lobes * th)))
    m = smooth(1.0, 0.94, rr)
    H = np.sqrt(np.clip(1 - rr ** 2, 0, 1)) * R * 0.35
    H -= np.exp(-((rr - 0.68) / 0.035) ** 2) * 2.0 * SS  # engraved ring
    for k in range(lobes):  # engraved rays between ring and rim
        a = 2 * math.pi * (k + 0.5) / lobes
        ray = np.abs(np.sin(th - a)) * rr * R
        H -= (np.cos(th - a) > 0) * smooth(1.2 * SS, 0, ray) * smooth(0.7, 0.75, rr) * smooth(0.93, 0.86, rr) * 1.4 * SS
    sr = np.sqrt(dx * dx + dy * dy) / (R * 0.22)
    H += np.sqrt(np.clip(1 - sr ** 2, 0, 1)) * R * 0.12
    slot = (np.abs(dy - dx * 0.4) < 0.9 * SS) & (sr < 0.85)
    H -= slot * 1.5 * SS
    tarn = smooth(0.5, 0.8, fbm(w, h, 8 * SS, 8 * SS, 3))
    alb = mix(np.array([0.66, 0.52, 0.3]), np.array([0.3, 0.24, 0.14]), tarn * 0.7)
    col = shade(alb, H, 1.0, spec=np.full((h, w), 0.9, np.float32), shin=18, amb=0.35, ao=0.15)
    return col, m


# ---------------------------------------------------------------- leather

def leather(w, h, col, var=0.18):
    peb = blur(noise(w, h, 2.0 * SS, 2.0 * SS), 0.5 * SS)
    ridge = 1 - np.abs(fbm(w, h, 26 * SS, 26 * SS, 3) * 2 - 1)
    crease = ridge ** 14  # fine wrinkles, felt more than seen
    H = peb * 1.3 + fbm(w, h, 160 * SS, 50 * SS, 3) * 4 - crease * 0.45
    tone = 1 - var + 2 * var * fbm(w, h, 260 * SS, 180 * SS, 4)
    mottle = fbm(w, h, 18 * SS, 18 * SS, 3)
    alb = col * tone[..., None] * (0.94 + 0.12 * mottle)[..., None] * (1 - 0.06 * crease)[..., None]
    return alb, H


def rr_path(x0, y0, x1, y1, r, step):
    """Points along a rounded rectangle, clockwise from the top left, with their direction."""
    segs = []
    ax0, ax1, ay0, ay1 = x0 + r, x1 - r, y0 + r, y1 - r
    segs.append(("l", (ax0, y0), (ax1, y0)))
    segs.append(("a", (ax1, ay0), -math.pi / 2, 0))
    segs.append(("l", (x1, ay0), (x1, ay1)))
    segs.append(("a", (ax1, ay1), 0, math.pi / 2))
    segs.append(("l", (ax1, y1), (ax0, y1)))
    segs.append(("a", (ax0, ay1), math.pi / 2, math.pi))
    segs.append(("l", (x0, ay1), (x0, ay0)))
    segs.append(("a", (ax0, ay0), math.pi, 1.5 * math.pi))
    pts = []
    for s in segs:
        if s[0] == "l":
            (xa, ya), (xb, yb) = s[1], s[2]
            n = max(1, int(math.hypot(xb - xa, yb - ya) / step))
            ang = math.atan2(yb - ya, xb - xa)
            pts += [(xa + (xb - xa) * k / n, ya + (yb - ya) * k / n, ang) for k in range(n)]
        else:
            (cx, cy), a0, a1 = s[1], s[2], s[3]
            n = max(1, int(r * (a1 - a0) / step))
            pts += [(cx + r * math.cos(a0 + (a1 - a0) * k / n), cy + r * math.sin(a0 + (a1 - a0) * k / n), a0 + (a1 - a0) * k / n + math.pi / 2) for k in range(n)]
    return pts


def stitches(w, h, path, length, slant, width, thread):
    """Saddle stitching along a path: slanted thread with dark holes, sitting in a pressed groove."""
    th = Image.new("L", (w, h), 0)
    gr = Image.new("L", (w, h), 0)
    ho = Image.new("L", (w, h), 0)
    td, gd, hd = ImageDraw.Draw(th), ImageDraw.Draw(gr), ImageDraw.Draw(ho)
    for i, (x, y, ang) in enumerate(path):
        a = ang + slant
        dx, dy = math.cos(a) * length / 2, math.sin(a) * length / 2
        td.line([(x - dx, y - dy), (x + dx, y + dy)], fill=255, width=int(width))
        for sx, sy in ((x - dx * 1.15, y - dy * 1.15), (x + dx * 1.15, y + dy * 1.15)):
            r = width * 0.55
            hd.ellipse([sx - r, sy - r, sx + r, sy + r], fill=255)
        if i:
            px, py, _ = path[i - 1]
            gd.line([(px, py), (x, y)], fill=255, width=int(width * 2.2))
    t = blur(np.asarray(th, np.float32) / 255, 0.5 * SS)
    g = blur(np.asarray(gr, np.float32) / 255, 1.0 * SS)
    o = blur(np.asarray(ho, np.float32) / 255, 0.6 * SS)
    tw = fbm(w, h, 1.5 * SS, 1.5 * SS, 2)
    H = t * (2.2 + tw) - g * 1.6 - o * 1.2
    return t, H, o, np.array(thread, np.float32)


def basketweave(w, h, T):
    """Basketweave stamping: blocks of three bars, turned every other block."""
    X, Y = grid(w, h)
    i, j = np.floor(X / T), np.floor(Y / T)
    lx, ly = X - i * T, Y - j * T
    flip = ((i + j) % 2) == 1
    a = np.where(flip, lx, ly)  # across the bars
    b = np.where(flip, ly, lx)  # along the bars
    bar = T / 3
    c = a - (np.floor(a / bar) + 0.5) * bar
    across = smooth(bar * 0.42, bar * 0.18, np.abs(c))
    along = smooth(0.0, T * 0.12, b) * smooth(T, T * 0.88, b)
    stamp = across * along
    lines = smooth(0.6 * SS, 0, np.abs(c)) * along  # the stamp's fine lines
    return stamp, lines


# ---------------------------------------------------------------- rope

def rope(w, h, x0, y0, x1, y1, r, R, pitch, col):
    """A twisted three-strand rope following a rounded rectangle. Returns rgb, alpha."""
    X, Y = grid(w, h)
    ax0, ax1, ay0, ay1 = x0 + r, x1 - r, y0 + r, y1 - r
    qx, qy = np.clip(X, ax0, ax1), np.clip(Y, ay0, ay1)
    vx, vy = X - qx, Y - qy
    dist = np.sqrt(vx * vx + vy * vy)
    d = dist - r
    th = np.arctan2(vy, vx)
    Lt, Lr = ax1 - ax0, ay1 - ay0
    q = math.pi / 2 * r
    s = np.zeros_like(X)
    top = (vy < 0) & (vx == 0)
    right = (vx > 0) & (vy == 0)
    bot = (vy > 0) & (vx == 0)
    left = (vx < 0) & (vy == 0)
    s = np.where(top, X - ax0, s)
    s = np.where((vx > 0) & (vy < 0), Lt + r * (th + math.pi / 2), s)
    s = np.where(right, Lt + q + (Y - ay0), s)
    s = np.where((vx > 0) & (vy > 0), Lt + q + Lr + r * th, s)
    s = np.where(bot, Lt + 2 * q + Lr + (ax1 - X), s)
    s = np.where((vx < 0) & (vy > 0), 2 * Lt + 2 * q + Lr + r * (th - math.pi / 2), s)
    s = np.where(left, 2 * Lt + 3 * q + Lr + (ay1 - Y), s)
    s = np.where((vx < 0) & (vy < 0), 2 * Lt + 3 * q + 2 * Lr + r * (th + math.pi), s)
    t = d / R
    inside = smooth(1.0, 0.92, np.abs(t))
    prof = np.sqrt(np.clip(1 - t * t, 0, 1))
    u = (s + t * R * 1.0) / (pitch / 3)  # three strands laid at a slant
    f = u - np.floor(u)
    strand = np.sin(np.pi * f) ** 0.7
    # fibres run along each strand: sample noise along the strand's own direction
    fib_src = noise(1024, 64, 14 * SS, 0.6 * SS)
    fu = ((s * 0.8 - t * R * 0.9) % 1024).astype(np.int32)
    fv = ((f * 63)).astype(np.int32)
    fib = fib_src[fv, fu]
    H = prof * R * 0.8 + strand * R * 0.28 * prof + (fib - 0.5) * 1.2 * SS
    alb = col * (0.78 + 0.3 * fib)[..., None] * (0.55 + 0.45 * strand)[..., None]
    hair = smooth(0.82, 0.95, noise(w, h, 1.0 * SS, 1.0 * SS)) * inside
    alb = mix(alb, col * 1.15, hair * 0.4)
    rgb = shade(alb, H, 1.0, spec=np.full((h, w), 0.06, np.float32), shin=10, ao=0.06)
    return rgb, inside


# ---------------------------------------------------------------- paper

def paper(w, h, x0, y0, x1, y1):
    """An old printed notice with torn, browned edges. Returns rgb, alpha."""
    X, Y = grid(w, h)

    def jag(n, amp):
        return (fbm(n, 1, 30 * SS, 1, 4)[0] - 0.5) * amp + (noise(n, 1, 2 * SS, 1)[0] - 0.5) * amp * 0.5

    jt, jb = jag(w, 7 * SS), jag(w, 7 * SS)
    jl, jr = jag(h, 7 * SS), jag(h, 7 * SS)
    m = (Y > y0 + jt[None, :]) & (Y < y1 + jb[None, :]) & (X > x0 + jl[:, None]) & (X < x1 + jr[:, None])
    m = m.astype(np.float32)
    m = blur(m, 0.5 * SS)
    near = 1 - blur(m, 18 * SS)
    alb = np.array([0.85, 0.79, 0.65]) * (0.92 + 0.12 * fbm(w, h, 260 * SS, 200 * SS, 4))[..., None]
    stain = smooth(0.6, 0.85, fbm(w, h, 160 * SS, 140 * SS, 5))
    alb = mix(alb, alb * np.array([0.82, 0.68, 0.48]), stain * 0.55)
    fox = blur(smooth(0.975, 0.998, noise(w, h, 4 * SS, 4 * SS)), 1.5 * SS)
    alb = mix(alb, np.array([0.6, 0.45, 0.28]), np.clip(fox * 1.4, 0, 0.35))
    alb = mix(alb, np.array([0.42, 0.28, 0.13]), np.clip(near * 1.9, 0, 1) ** 1.4)
    rim = smooth(0.2, 0.0, blur(m, 1.5 * SS) - 0.5)
    alb = mix(alb, np.array([0.22, 0.13, 0.06]), rim * 0.8)
    fib = fbm(w, h, 3 * SS, 3 * SS, 2)
    H = fib * 0.8 + fbm(w, h, 200 * SS, 120 * SS, 3) * 10
    for fy in (0.5,):  # one fold across the middle
        yy = y0 + (y1 - y0) * fy
        H += np.exp(-((Y - yy) / (5 * SS)) ** 2) * 2.5
    rgb = shade(alb, H, 1.0, amb=0.55)
    return rgb, m


# ---------------------------------------------------------------- skins

def frame_planks(w, h, fw, light, dark, **kw):
    """A frame of four boards around the edge, grain running along each side, with mitred corners."""
    top_a, top_h = wood(w, fw, light, dark, **kw)
    bot_a, bot_h = wood(w, fw, light, dark, **kw)
    lef_a, lef_h = wood(h, fw, light, dark, **kw)
    rig_a, rig_h = wood(h, fw, light, dark, **kw)
    alb = np.zeros((h, w, 3), np.float32)
    H = np.zeros((h, w), np.float32)
    X, Y = grid(w, h)
    m = np.zeros((h, w), np.float32)
    dt, db, dl, dr = Y, h - 1 - Y, X, w - 1 - X
    near = np.minimum(np.minimum(dt, db), np.minimum(dl, dr))
    m = (near < fw).astype(np.float32)
    which = np.argmin(np.stack([dt, db, dl, dr]), 0)
    for k, (al, hh) in enumerate([(top_a, top_h), (bot_a, bot_h), (lef_a, lef_h), (rig_a, rig_h)]):
        sel = (which == k) & (m > 0)
        if k == 0:
            A, HH = al, hh
            src_a = np.zeros((h, w, 3), np.float32); src_h = np.zeros((h, w), np.float32)
            src_a[:fw], src_h[:fw] = A, HH
        elif k == 1:
            src_a = np.zeros((h, w, 3), np.float32); src_h = np.zeros((h, w), np.float32)
            src_a[h - fw:], src_h[h - fw:] = al[::-1], hh[::-1]
        elif k == 2:
            src_a = np.zeros((h, w, 3), np.float32); src_h = np.zeros((h, w), np.float32)
            src_a[:, :fw], src_h[:, :fw] = al.transpose(1, 0, 2), hh.T
        else:
            src_a = np.zeros((h, w, 3), np.float32); src_h = np.zeros((h, w), np.float32)
            src_a[:, w - fw:], src_h[:, w - fw:] = al.transpose(1, 0, 2)[:, ::-1], hh.T[:, ::-1]
        alb[sel], H[sel] = src_a[sel], src_h[sel]
    # bevel each frame board: higher in its middle, a dark seam at the mitres and the inner edge
    prof = np.sqrt(np.clip(near / (5 * SS), 0, 1)) * np.sqrt(np.clip((fw - near) / (5 * SS), 0, 1))
    srt = np.sort(np.stack([dt, db, dl, dr]), 0)
    mitre = smooth(1.5 * SS, 0, srt[1] - srt[0]) * m
    H += prof * 4 - mitre * 3
    alb *= (1 - 0.6 * mitre)[..., None]
    return alb, H, m


def skin_barn():
    light, dark = np.array([0.68, 0.6, 0.5]), np.array([0.31, 0.25, 0.19])
    # button: one weathered board with iron caps on both ends, browner and darker than the board
    # behind it so it stands out
    BW, BH, P = 300, 112, 5
    w, h = BW * SS, BH * SS
    alb, H = wood(w - 2 * P * SS, h - 2 * P * SS, np.array([0.6, 0.48, 0.35]), np.array([0.29, 0.21, 0.14]), ring=9, weather=0.9, gray=0.2, contrast=0.8)
    bw, bh = alb.shape[1], alb.shape[0]
    bm = mask_draw(bw, bh, lambda d: d.rounded_rectangle([0, 0, bw - 1, bh - 1], radius=4 * SS, fill=255))
    H += np.sqrt(np.clip(blur(bm, 3 * SS), 0, 1)) * 5
    face = shade(alb, H, 1.0, ao=0.12)
    rgb = np.zeros((h, w, 3), np.float32)
    a = np.zeros((h, w), np.float32)
    top = np.zeros((h, w, 3), np.float32)
    ta = np.zeros((h, w), np.float32)
    top[P * SS:P * SS + bh, P * SS:P * SS + bw] = face
    ta[P * SS:P * SS + bh, P * SS:P * SS + bw] = bm
    rgb, a = over(rgb, a, top, ta, shadow=0.7, off=(1.5, 2.5), soft=2.5)
    cw = 22 * SS
    for side in (0, 1):
        x0 = P * SS - 2 * SS if side == 0 else w - P * SS - cw + 2 * SS
        cm = mask_draw(w, h, lambda d: d.rounded_rectangle([x0, P * SS - 2 * SS, x0 + cw, h - P * SS + 2 * SS], radius=3 * SS, fill=255))
        rgb, a = over(rgb, a, iron(w, h, cm), cm, shadow=0.6, off=(1.5, 2), soft=2)
        cx = x0 + cw / 2
        rgb, a = rivets(rgb, a, [(cx, h * 0.3), (cx, h * 0.7)], 3.6 * SS)
    save(rgb, a, BW, BH, OUT / "barn" / "button.png")

    # board: weathered planks inside a frame of boards, iron brackets on the corners
    PW, PH, P = 1000, 680, 8
    w, h = PW * SS, PH * SS
    iw, ih = w - 2 * P * SS, h - 2 * P * SS
    alb, H = planks(iw, ih, (82, 100), light * 1.06, dark * 1.1, seam=0.55, ring=12, weather=0.8, gray=0.45, contrast=0.6)
    alb *= (0.9 + 0.1 * smooth(0, 0.35, 1 - np.abs(np.linspace(-1, 1, ih)))[:, None, None])
    fa, fh, fm = frame_planks(iw, ih, 46 * SS, light * 0.95, dark * 0.95, ring=10, weather=0.9, gray=0.55)
    H = np.where(fm > 0, fh + 4, H)
    alb = np.where(fm[..., None] > 0, fa, alb)
    inner = blur(fm, 3 * SS)
    H += inner * 2
    face = shade(alb, H, 1.0, ao=0.14)
    face *= (1 - 0.35 * smooth(0.5, 0.0, fm) * smooth(0.05, 0.5, blur(fm, 7 * SS)))[..., None]  # frame shadow
    bm = mask_draw(iw, ih, lambda d: d.rounded_rectangle([0, 0, iw - 1, ih - 1], radius=6 * SS, fill=255))
    rgb = np.zeros((h, w, 3), np.float32)
    a = np.zeros((h, w), np.float32)
    top = np.zeros((h, w, 3), np.float32)
    ta = np.zeros((h, w), np.float32)
    top[P * SS:P * SS + ih, P * SS:P * SS + iw] = face
    ta[P * SS:P * SS + ih, P * SS:P * SS + iw] = bm
    rgb, a = over(rgb, a, top, ta, shadow=0.75, off=(2, 3), soft=4)
    arm, wd = 96 * SS, 26 * SS
    for sx, sy in ((0, 0), (1, 0), (0, 1), (1, 1)):
        ox = P * SS + 6 * SS if sx == 0 else w - P * SS - 6 * SS
        oy = P * SS + 6 * SS if sy == 0 else h - P * SS - 6 * SS
        dx, dy = (1 if sx == 0 else -1), (1 if sy == 0 else -1)

        def draw(d, ox=ox, oy=oy, dx=dx, dy=dy):
            xs = sorted([ox, ox + dx * arm]); ys = sorted([oy, oy + dy * wd])
            d.rounded_rectangle([xs[0], ys[0], xs[1], ys[1]], radius=4 * SS, fill=255)
            xs = sorted([ox, ox + dx * wd]); ys = sorted([oy, oy + dy * arm * 0.85])
            d.rounded_rectangle([xs[0], ys[0], xs[1], ys[1]], radius=4 * SS, fill=255)
            for (ex, ey) in ((ox + dx * arm, oy + dy * wd / 2), (ox + dx * wd / 2, oy + dy * arm * 0.85)):
                r = wd * 0.62
                d.ellipse([ex - r, ey - r, ex + r, ey + r], fill=255)

        cm = mask_draw(w, h, draw)
        rgb, a = over(rgb, a, iron(w, h, cm), cm, shadow=0.7, off=(2, 3), soft=3)
        rv = [(ox + dx * wd / 2, oy + dy * wd / 2), (ox + dx * arm * 0.55, oy + dy * wd / 2), (ox + dx * arm, oy + dy * wd / 2),
              (ox + dx * wd / 2, oy + dy * arm * 0.85)]
        rgb, a = rivets(rgb, a, rv, 4.6 * SS)
    save(rgb, a, PW, PH, OUT / "barn" / "panel.png")


def skin_saddle():
    dark_l = np.array([0.30, 0.17, 0.08])
    tan = np.array([0.67, 0.49, 0.31])
    thread = (0.86, 0.78, 0.6)
    # button: dark leather pad, stitched round, small brass rivet at each end
    BW, BH, P = 300, 112, 5
    w, h = BW * SS, BH * SS
    bw, bh = w - 2 * P * SS, h - 2 * P * SS
    alb, H = leather(bw, bh, dark_l * 1.25)
    bm = mask_draw(bw, bh, lambda d: d.rounded_rectangle([0, 0, bw - 1, bh - 1], radius=14 * SS, fill=255))
    edge = blur(bm, 5 * SS)
    H += np.sqrt(np.clip(edge, 0, 1)) * 5
    alb *= (0.55 + 0.45 * smooth(0.2, 0.9, edge))[..., None]  # dyed, burnished edges
    t, sh, holes, tc = stitches(bw, bh, rr_path(10 * SS, 10 * SS, bw - 10 * SS, bh - 10 * SS, 9 * SS, 8 * SS), 6.0 * SS, 0.5, 2.0 * SS, thread)
    H += sh
    alb = mix(alb, tc, t)
    alb *= (1 - 0.5 * holes)[..., None]
    face = shade(alb, H, 1.0, spec=np.full((bh, bw), 0.06, np.float32), shin=12, ao=0.1)
    rgb = np.zeros((h, w, 3), np.float32)
    a = np.zeros((h, w), np.float32)
    top = np.zeros((h, w, 3), np.float32)
    ta = np.zeros((h, w), np.float32)
    top[P * SS:P * SS + bh, P * SS:P * SS + bw] = face
    ta[P * SS:P * SS + bh, P * SS:P * SS + bw] = bm
    rgb, a = over(rgb, a, top, ta, shadow=0.7, off=(1.5, 2.5), soft=2.5)
    for cx in (P * SS + 18 * SS, w - P * SS - 18 * SS):
        col, m = brass(w, h, cx, h / 2, 8 * SS, lobes=10)
        rgb, a = over(rgb, a, col, m, shadow=0.6, off=(1, 1.5), soft=1.5)
    save(rgb, a, BW, BH, OUT / "saddle" / "button.png")

    # board: stamped dark border, smooth tan middle, stitching, brass conchos in the corners
    PW, PH, P = 1000, 680, 8
    w, h = PW * SS, PH * SS
    bw, bh = w - 2 * P * SS, h - 2 * P * SS
    band = 50 * SS
    alb, H = leather(bw, bh, tan, var=0.14)
    dalb, dH = leather(bw, bh, dark_l * 1.35, var=0.12)
    X, Y = grid(bw, bh)
    near = np.minimum(np.minimum(X, bw - 1 - X), np.minimum(Y, bh - 1 - Y))
    bandm = smooth(band + 1.0 * SS, band - 1.0 * SS, near)
    stamp, lines = basketweave(bw, bh, 22 * SS)
    stamp *= smooth(band - 9 * SS, band - 12 * SS, near) * smooth(15 * SS, 18 * SS, near)
    lines *= stamp > 0.01
    dH = dH - stamp * 4.0 + lines * 0.8
    dalb = dalb * (1 - 0.45 * stamp)[..., None]
    alb = mix(alb, dalb, bandm)
    H = np.where(bandm > 0.5, dH, H)
    cut = np.exp(-((near - band) / (1.2 * SS)) ** 2)  # swivel-knife cut where the border meets the middle
    H -= cut * 3
    alb *= (1 - 0.5 * cut)[..., None]
    bm = mask_draw(bw, bh, lambda d: d.rounded_rectangle([0, 0, bw - 1, bh - 1], radius=20 * SS, fill=255))
    edge = blur(bm, 6 * SS)
    H += np.sqrt(np.clip(edge, 0, 1)) * 6
    alb *= (0.5 + 0.5 * smooth(0.2, 0.9, edge))[..., None]
    for ins, ln in ((8 * SS, 7.0 * SS), (band + 9 * SS, 7.0 * SS)):
        t, sh, holes, tc = stitches(bw, bh, rr_path(ins, ins, bw - ins, bh - ins, 12 * SS if ins < band else 6 * SS, 10 * SS), ln, 0.5, 2.4 * SS, thread)
        H += sh
        alb = mix(alb, tc, t)
        alb *= (1 - 0.5 * holes)[..., None]
    face = shade(alb, H, 1.0, spec=np.full((bh, bw), 0.05, np.float32), shin=10, ao=0.12)
    rgb = np.zeros((h, w, 3), np.float32)
    a = np.zeros((h, w), np.float32)
    top = np.zeros((h, w, 3), np.float32)
    ta = np.zeros((h, w), np.float32)
    top[P * SS:P * SS + bh, P * SS:P * SS + bw] = face
    ta[P * SS:P * SS + bh, P * SS:P * SS + bw] = bm
    rgb, a = over(rgb, a, top, ta, shadow=0.75, off=(2, 3), soft=4)
    c = P * SS + band / 2 + 2 * SS
    for cx, cy in ((c, c), (w - c, c), (c, h - c), (w - c, h - c)):
        col, m = brass(w, h, cx, cy, 19 * SS)
        rgb, a = over(rgb, a, col, m, shadow=0.65, off=(2, 3), soft=2.5)
    save(rgb, a, PW, PH, OUT / "saddle" / "panel.png")


def skin_poster():
    dl, dd = np.array([0.36, 0.23, 0.13]), np.array([0.13, 0.08, 0.05])
    # button: a dark stained board with a nail at each end
    BW, BH, P = 300, 112, 5
    w, h = BW * SS, BH * SS
    bw, bh = w - 2 * P * SS, h - 2 * P * SS
    alb, H = wood(bw, bh, dl * 1.1, dd, ring=8, weather=0.5, contrast=0.9)
    bm = mask_draw(bw, bh, lambda d: d.rounded_rectangle([0, 0, bw - 1, bh - 1], radius=4 * SS, fill=255))
    H += np.sqrt(np.clip(blur(bm, 3 * SS), 0, 1)) * 5
    alb *= (0.7 + 0.3 * smooth(0.1, 0.8, blur(bm, 6 * SS)))[..., None]
    face = shade(alb, H, 1.0, spec=np.full((bh, bw), 0.08, np.float32), shin=14, ao=0.1)
    rgb = np.zeros((h, w, 3), np.float32)
    a = np.zeros((h, w), np.float32)
    top = np.zeros((h, w, 3), np.float32)
    ta = np.zeros((h, w), np.float32)
    top[P * SS:P * SS + bh, P * SS:P * SS + bw] = face
    ta[P * SS:P * SS + bh, P * SS:P * SS + bw] = bm
    rgb, a = over(rgb, a, top, ta, shadow=0.7, off=(1.5, 2.5), soft=2.5)
    rgb, a = rivets(rgb, a, [(P * SS + 17 * SS, h / 2), (w - P * SS - 17 * SS, h / 2)], 6.5 * SS)
    save(rgb, a, BW, BH, OUT / "poster" / "button.png")

    # board: old paper nailed onto dark vertical planks
    PW, PH, P = 1000, 680, 8
    w, h = PW * SS, PH * SS
    bw, bh = w - 2 * P * SS, h - 2 * P * SS
    alb, H = planks(bw, bh, (95, 125), dl, dd, vertical=True, ring=9, weather=0.6, cracks=1)
    bm = mask_draw(bw, bh, lambda d: d.rounded_rectangle([0, 0, bw - 1, bh - 1], radius=6 * SS, fill=255))
    alb *= (0.7 + 0.3 * smooth(0.1, 0.8, blur(bm, 10 * SS)))[..., None]
    face = shade(alb, H, 1.0, spec=np.full((bh, bw), 0.05, np.float32), shin=12, ao=0.12)
    rgb = np.zeros((h, w, 3), np.float32)
    a = np.zeros((h, w), np.float32)
    top = np.zeros((h, w, 3), np.float32)
    ta = np.zeros((h, w), np.float32)
    top[P * SS:P * SS + bh, P * SS:P * SS + bw] = face
    ta[P * SS:P * SS + bh, P * SS:P * SS + bw] = bm
    rgb, a = over(rgb, a, top, ta, shadow=0.75, off=(2, 3), soft=4)
    m0 = 30 * SS
    prgb, pm = paper(w, h, P * SS + m0, P * SS + m0, w - P * SS - m0, h - P * SS - m0)
    rgb, a = over(rgb, a, prgb, pm, shadow=0.55, off=(3, 4), soft=5)
    n = P * SS + m0 + 18 * SS
    rgb, a = rivets(rgb, a, [(n, n), (w - n, n), (n, h - n), (w - n, h - n)], 8.5 * SS)
    save(rgb, a, PW, PH, OUT / "poster" / "panel.png")


def skin_rope():
    ol, od = np.array([0.76, 0.58, 0.37]), np.array([0.45, 0.29, 0.15])
    hemp = np.array([0.74, 0.62, 0.42])
    # button: an oak board with a thin rope round its edge
    BW, BH, P = 300, 112, 5
    w, h = BW * SS, BH * SS
    bw, bh = w - 2 * P * SS, h - 2 * P * SS
    alb, H = wood(bw, bh, ol, od, ring=9, weather=0.35, contrast=0.75)
    bm = mask_draw(bw, bh, lambda d: d.rounded_rectangle([0, 0, bw - 1, bh - 1], radius=12 * SS, fill=255))
    H += np.sqrt(np.clip(blur(bm, 3 * SS), 0, 1)) * 5
    face = shade(alb, H, 1.0, spec=np.full((bh, bw), 0.05, np.float32), shin=12, ao=0.1)
    rgb = np.zeros((h, w, 3), np.float32)
    a = np.zeros((h, w), np.float32)
    top = np.zeros((h, w, 3), np.float32)
    ta = np.zeros((h, w), np.float32)
    top[P * SS:P * SS + bh, P * SS:P * SS + bw] = face
    ta[P * SS:P * SS + bh, P * SS:P * SS + bw] = bm
    rgb, a = over(rgb, a, top, ta, shadow=0.7, off=(1.5, 2.5), soft=2.5)
    R = 7 * SS
    e = P * SS + R + 1 * SS
    rr, ra = rope(w, h, e, e, w - e, h - e, 13 * SS, R, 6.5 * R, hemp)
    rgb, a = over(rgb, a, rr, ra, shadow=0.6, off=(1.2, 1.8), soft=1.5)
    save(rgb, a, BW, BH, OUT / "rope" / "button.png")

    # board: oak planks with a thick rope around, inside the edge
    PW, PH, P = 1000, 680, 8
    w, h = PW * SS, PH * SS
    bw, bh = w - 2 * P * SS, h - 2 * P * SS
    alb, H = planks(bw, bh, (85, 105), ol * 1.03, od, seam=0.5, ring=11, weather=0.4, contrast=0.75)
    bm = mask_draw(bw, bh, lambda d: d.rounded_rectangle([0, 0, bw - 1, bh - 1], radius=14 * SS, fill=255))
    alb *= (0.75 + 0.25 * smooth(0.1, 0.8, blur(bm, 10 * SS)))[..., None]
    face = shade(alb, H, 1.0, spec=np.full((bh, bw), 0.05, np.float32), shin=12, ao=0.12)
    rgb = np.zeros((h, w, 3), np.float32)
    a = np.zeros((h, w), np.float32)
    top = np.zeros((h, w, 3), np.float32)
    ta = np.zeros((h, w), np.float32)
    top[P * SS:P * SS + bh, P * SS:P * SS + bw] = face
    ta[P * SS:P * SS + bh, P * SS:P * SS + bw] = bm
    rgb, a = over(rgb, a, top, ta, shadow=0.75, off=(2, 3), soft=4)
    R = 15 * SS
    e = P * SS + 8 * SS + R
    rr, ra = rope(w, h, e, e, w - e, h - e, 34 * SS, R, 6.5 * R, hemp)
    rgb, a = over(rgb, a, rr, ra, shadow=0.65, off=(2.5, 3.5), soft=3)
    save(rgb, a, PW, PH, OUT / "rope" / "panel.png")


if __name__ == "__main__":
    todo = sys.argv[1:] or ["barn", "saddle", "poster", "rope"]
    for name in todo:
        rng = np.random.default_rng(sum(map(ord, name)))  # each look comes out the same on its own
        globals()["skin_" + name]()
