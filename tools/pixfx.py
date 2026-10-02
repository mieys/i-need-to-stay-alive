"""pixfx - efsun efektleri icin piksel sanat ilkelleri (2026-09-30, ikinci tasarim).

Kullanici ilk sete "hepsi cok kotu ... oyunun 48x48 pixel sanatiyla uyusmali" dedi. Ilk set 1 px noktali halkalar ve
dagink zerrelerdi. Oyundaki iyi efektlerin dili (hit_effects/big_burst, burn/fire_min, poison_hit, korsan patlamasi,
assasin shadow_hit) - buradaki ilkeller onu uretir:
  * IC DOLU kutleler, 5 tonlu rampa [kontur, koyu, orta, acik, parlak] - isik sol ustten (cel shading)
  * 1 px KOYU KONTUR
  * ilk karelerde krem/beyaz parlama
  * sonme: seffaflasma yerine kutleler hilale asinir, parcalanir, kuculur (alfa neredeyse hic yok)
Tum cizim tam piksel izgarasinda, maske (numpy bool) -> renk. Tuval 1 piksel = oyunda 1.212 dunya birimi (TEXEL).
"""

import math

import numpy as np
from PIL import Image, ImageDraw

TAU = 2 * math.pi
LIGHT = (-0.55, -0.83)  # isik yonu (sol ust)

# ---- paletler: [kontur, koyu, orta, acik, parlak]
FIRE = [(86, 18, 20), (182, 44, 28), (236, 112, 36), (255, 186, 64), (255, 242, 178)]
EMBER = [(64, 16, 16), (140, 34, 24), (206, 76, 30), (246, 146, 48), (255, 214, 120)]
SMOKE = [(38, 32, 42), (66, 60, 74), (104, 98, 112), (146, 142, 152), (186, 182, 190)]
SMOKE_LIGHT = [(58, 52, 62), (112, 106, 118), (152, 148, 158), (192, 188, 196), (226, 222, 228)]
ICE = [(18, 38, 88), (46, 96, 186), (96, 164, 238), (168, 222, 255), (238, 250, 255)]
BOLT = [(84, 64, 10), (196, 146, 20), (250, 212, 56), (255, 244, 150), (255, 255, 236)]
VOID = [(26, 8, 44), (66, 26, 116), (124, 64, 204), (184, 136, 255), (238, 218, 255)]
TOXIC = [(18, 46, 14), (54, 124, 28), (112, 194, 46), (184, 242, 104), (238, 255, 206)]
BLOOD = [(56, 8, 14), (124, 18, 28), (194, 38, 48), (238, 98, 96), (255, 198, 196)]
STEEL = [(28, 30, 42), (78, 84, 102), (138, 146, 166), (198, 206, 220), (250, 252, 255)]
EARTH = [(38, 26, 18), (86, 60, 40), (134, 98, 66), (182, 146, 104), (220, 194, 156)]
DUST = [(70, 58, 46), (122, 106, 86), (164, 148, 124), (200, 188, 164), (232, 224, 204)]
WIND = [(66, 88, 110), (146, 172, 194), (196, 218, 234), (234, 244, 252), (255, 255, 255)]
SHADOW = [(10, 4, 18), (34, 14, 56), (68, 32, 108), (118, 68, 178), (188, 150, 240)]
HEAL = [(20, 60, 24), (48, 140, 56), (96, 206, 96), (176, 248, 160), (240, 255, 230)]
STONE = [(34, 28, 30), (78, 68, 66), (122, 110, 102), (168, 156, 142), (212, 202, 186)]
CHARGE = [(72, 44, 22), (170, 112, 44), (236, 198, 124), (255, 240, 204), (255, 255, 255)]
WOOD = [(40, 22, 14), (96, 58, 32), (146, 96, 54), (192, 140, 84), (226, 184, 120)]
FW_COLS = [[(120, 70, 10), (255, 214, 72), (255, 250, 200)], [(120, 20, 40), (255, 96, 110), (255, 214, 214)],
           [(20, 70, 120), (96, 206, 255), (224, 250, 255)], [(80, 24, 120), (206, 120, 255), (246, 224, 255)]]
CREAM = (255, 250, 228)
WHITE = (255, 255, 255)


# ====================================================================== tuval
## Kenar payi (x, y): cizim tasarim tuvalinden bu kadar genis bir dizide yapilir, koordinatlar tasarim tuvaline gore kalir
## (grid/px/poly/chunk kaydirir). Boylece tasma (firlayan tas, toz, kesik ucu) tuval kenarinda DUZ KESILMEZ; kaydet
## (generator save) sonra merkezi koruyarak simetrik kirpar -> oyun kodundaki merkez tabanli ofsetler degismez.
## Kullanici bildirimi 2026-09-30: "koseleri keskin bitisli, baslangiclari keskin - hic dogal durmuyor".
PAD = [0, 0]


class Canvas:
    def __init__(self, w, h):
        self.ox, self.oy = PAD
        self.bw, self.bh = w, h
        self.w, self.h = w + 2 * self.ox, h + 2 * self.oy
        self.rgba = np.zeros((self.h, self.w, 4), dtype=np.uint8)

    def put(self, mask, col, alpha=255):
        self.rgba[mask, 0] = col[0]
        self.rgba[mask, 1] = col[1]
        self.rgba[mask, 2] = col[2]
        self.rgba[mask, 3] = alpha

    def idx(self, x, y):
        """Tasarim koordinati -> dizi indeksi (satir, sutun)."""
        return int(math.floor(y + 0.5)) + self.oy, int(math.floor(x + 0.5)) + self.ox

    def px(self, x, y, col, alpha=255):
        y, x = self.idx(x, y)
        if 0 <= x < self.w and 0 <= y < self.h:
            self.rgba[y, x] = (col[0], col[1], col[2], alpha)

    def filled(self):
        return self.rgba[:, :, 3] > 0

    def image(self):
        return Image.fromarray(self.rgba, "RGBA")

    def grid(self):
        yy, xx = np.mgrid[0:self.h, 0:self.w]
        return xx + 0.5 - self.ox, yy + 0.5 - self.oy


def dilate(mask):
    m = mask.copy()
    m[1:, :] |= mask[:-1, :]
    m[:-1, :] |= mask[1:, :]
    m[:, 1:] |= mask[:, :-1]
    m[:, :-1] |= mask[:, 1:]
    return m


def erode(mask):
    m = mask.copy()
    m[1:, :] &= mask[:-1, :]
    m[:-1, :] &= mask[1:, :]
    m[:, 1:] &= mask[:, :-1]
    m[:, :-1] &= mask[:, 1:]
    return m


def outline_of(mask):
    return dilate(mask) & ~mask


def fill_holes(mask):
    """Kutlenin icindeki kapali bosluklari doldurur (heat_fill icinde kontur halkasi olusmasin)."""
    out = np.zeros_like(mask)
    out[0, :] = ~mask[0, :]
    out[-1, :] = ~mask[-1, :]
    out[:, 0] |= ~mask[:, 0]
    out[:, -1] |= ~mask[:, -1]
    while True:
        nxt = dilate(out) & ~mask
        if (nxt == out).all():
            break
        out = nxt
    return ~out


def poly_mask(cv, pts):
    im = Image.new("L", (cv.w, cv.h), 0)
    ImageDraw.Draw(im).polygon([(float(x) - 0.5 + cv.ox, float(y) - 0.5 + cv.oy) for (x, y) in pts], fill=255)
    return np.array(im) > 0


def noise_xy(X, Y, scale, seed, period_x=None):
    """Yumusak gurultu (0..1) verilen koordinat dizilerinde - akis (X kaydirma) icin. period_x: x'te tam periyodik
    (dosenebilir karolar)."""
    rng = np.random.default_rng(seed)
    acc = np.zeros_like(X, dtype=float)
    amp_sum = 0.0
    for o in range(4):
        a = 0.55 ** o
        ph = rng.uniform(0, TAU, 4)
        if period_x:
            kx = max(1, int(round(period_x * (2 ** o) / scale)))
            fx = kx / period_x
        else:
            fx = (2 ** o) / scale * rng.uniform(0.8, 1.2)
        fy = (2 ** o) / scale * rng.uniform(0.8, 1.2)
        acc += a * np.sin(X * fx * TAU + ph[0]) * np.sin(Y * fy * TAU + ph[1] + 0.7 * np.sin(X * fx * TAU + ph[2]))
        amp_sum += a
    return 0.5 + 0.5 * acc / amp_sum


# ====================================================================== golgeli kutleler
def puffs(cv, circles, pal, cut=None, outline=True, hi=True, squash=1.0):
    """Cember birlesimi (duman / alev / kaya kutlesi). circles: [(cx, cy, r)], squash: y basikligi.
    Her piksel icine dustugu en derin cemberin kuresine gore golgelenir (sol ust isik). cut: [(cx, cy, r)] cikarilan
    cemberler (hilale asinma). Doner: kutle maskesi."""
    X, Y = cv.grid()
    depth = np.full((cv.h, cv.w), -1.0)
    nx = np.zeros((cv.h, cv.w))
    ny = np.zeros((cv.h, cv.w))
    for (cx, cy, r) in circles:
        if r <= 0.4:
            continue
        dx = (X - cx) / r
        dy = (Y - cy) / (r * squash)
        d2 = dx * dx + dy * dy
        inside = d2 <= 1.0
        dep = 1.0 - np.sqrt(np.minimum(d2, 1.0))
        better = inside & (dep > depth)
        depth[better] = dep[better]
        nx[better] = dx[better]
        ny[better] = dy[better]
    mask = depth >= 0.0
    if cut:
        for (cx, cy, r) in cut:
            mask &= ((X - cx) ** 2 + ((Y - cy) / squash) ** 2) > r * r
    if not mask.any():
        return mask
    s = nx * LIGHT[0] + ny * LIGHT[1]
    tone = np.where(s > 0.42, 3, np.where(s > -0.12, 2, 1))
    if hi:
        tone = np.where((s > 0.62) & (depth > 0.25), 4, tone)
    # alt kenar (golge tarafi) bir ton koyu
    edge = mask & ~erode(mask)
    tone = np.where(edge & (s < -0.2), 0, tone)
    for t in range(5):
        cv.put(mask & (tone == t), pal[t])
    if outline:
        cv.put(outline_of(mask) & ~cv.filled(), pal[0])
    return mask


def ellipses_mask(cv, items):
    """Yonlu elips birlesimi: items [(cx, cy, rx, ry, aci)] - aci boyunca rx uzar (alev dili, sis kutlesi)."""
    X, Y = cv.grid()
    m = np.zeros((cv.h, cv.w), dtype=bool)
    for (cx, cy, rx, ry, a) in items:
        if rx <= 0.4 or ry <= 0.4:
            continue
        ca, sa = math.cos(a), math.sin(a)
        dx, dy = X - cx, Y - cy
        u = (dx * ca + dy * sa) / rx
        v = (-dx * sa + dy * ca) / ry
        m |= (u * u + v * v) <= 1.0
    return m


def heat_fill(cv, mask, pal, levels=(1, 2, 4, 7), outline=True):
    """ISI golgelendirmesi (alev / enerji / sis): kenardan iceri derinlige gore ton - dis katman koyu, cekirdek parlak
    (burn/fire_min gibi). levels: koyu->orta->acik->parlak gecisinin erozyon adimlari. Doner: maske."""
    if not mask.any():
        return mask
    cv.put(mask, pal[1])
    cur = mask
    tone = 1
    step = 0
    for lv, t in zip(levels, (2, 3, 4, 4)):
        while step < lv:
            cur = erode(cur)
            step += 1
        if not cur.any():
            break
        cv.put(cur, pal[t])
    if outline:
        cv.put(outline_of(mask) & ~cv.filled(), pal[0])
    return mask


def value_noise(cv, scale, seed, t=0.0):
    """Yumusak deger gurultusu (0..1) - zemin dokulari / lav damarlari icin. t kaydirma (dongu)."""
    rng = np.random.default_rng(seed)
    X, Y = cv.grid()
    acc = np.zeros((cv.h, cv.w))
    amp_sum = 0.0
    for o in range(4):
        f = (2 ** o) / scale
        a = 0.55 ** o
        th = rng.uniform(0, TAU)
        ph = rng.uniform(0, TAU, 2)
        u = X * math.cos(th) + Y * math.sin(th)
        v = -X * math.sin(th) + Y * math.cos(th)
        acc += a * (np.sin(u * f * TAU + ph[0] + t * TAU) * np.sin(v * f * TAU * 0.83 + ph[1] - t * TAU * 0.6))
        amp_sum += a
    return 0.5 + 0.5 * acc / amp_sum


def disc_flash(cv, cx, cy, r, core=CREAM, rim=None, squash=1.0):
    """Parlama diski: ic krem, 1 px acik renk kenar (kontursuz - isik)."""
    X, Y = cv.grid()
    d = np.sqrt((X - cx) ** 2 + ((Y - cy) / squash) ** 2)
    m = d <= r
    cv.put(m, core)
    if rim is not None:
        cv.put(m & (d > r - 1.2), rim)
    return m


def star(cv, x, y, size, core=WHITE, arm=None, diag=False):
    """Arti bicimli parilti: 1 px merkez + size uzunlugunda kollar (uclar incelir)."""
    arm = arm or core
    cv.px(x, y, core)
    for i in range(1, size + 1):
        c = core if i == 1 and size > 2 else arm
        for dx, dy in ((i, 0), (-i, 0), (0, i), (0, -i)):
            cv.px(x + dx, y + dy, c)
    if diag and size >= 2:
        for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
            cv.px(x + dx, y + dy, arm)


def chunk(cv, x, y, size, pal):
    """Kucuk kaya/kivilcim parcasi (2-3 px, isikli ust, kontur)."""
    m = np.zeros((cv.h, cv.w), dtype=bool)
    y0, x0 = cv.idx(x, y)
    for dy in range(size):
        for dx in range(size):
            xx, yy = x0 + dx, y0 + dy
            if 0 <= xx < cv.w and 0 <= yy < cv.h:
                m[yy, xx] = True
    if not m.any():
        return
    cv.put(m, pal[2])
    if 0 <= x0 < cv.w and 0 <= y0 < cv.h:
        cv.rgba[y0, x0] = (pal[3][0], pal[3][1], pal[3][2], 255)
    cv.put(outline_of(m) & ~cv.filled(), pal[0])


# ====================================================================== kalin yaylar / halkalar
def _polar(cv, cx, cy, squash):
    X, Y = cv.grid()
    dx = X - cx
    dy = (Y - cy) / squash
    return np.sqrt(dx * dx + dy * dy), np.arctan2(dy, dx)


def _ang_in(theta, a0, a1):
    """theta [a0, a1] (a0 < a1, radyan, sarmali) araliginda mi; doner: 0..1 konum (a0=0, a1=1) ya da -1."""
    span = a1 - a0
    rel = np.mod(theta - a0, TAU)
    return np.where(rel <= span, rel / max(span, 1e-6), -1.0)


def arc_band(cv, cx, cy, radius, a0, a1, thick_head, thick_tail, pal, squash=1.0, outline=True, inner_hi=False, mult=None,
             round_head=True):
    """Kalin hilal / kesik: a0 (kuyruk) -> a1 (bas) arasinda, kalinlik bastan kuyruga incelir. Dis kenar parlak (kesik
    agzi), ic taraf koyu; kontur. round_head: bas ucu radyal DUZ kesilmez, dis kenar boyunca yuvarlanip sivrilir
    (kullanici: "baslangiclari keskin, dogal durmuyor"). mult: aciya bagli kalinlik carpani (parcalanma - uclar incelir).
    Doner: maske."""
    r, th = _polar(cv, cx, cy, squash)
    u = _ang_in(th, a0, a1)
    on = u >= 0.0
    uc = np.clip(u, 0, 1)
    thick = thick_tail + (thick_head - thick_tail) * uc ** 0.8
    if round_head:
        span = (a1 - a0) % TAU or TAU
        hr = max(0.55, 1.0 - min(0.3, (thick_head * 1.6 / max(radius, 1.0)) / span))
        k = np.clip((uc - hr) / (1.0 - hr), 0, 1)
        thick = thick * np.sqrt(np.clip(1.0 - k * k, 0, 1))
    if mult is not None:
        thick = thick * mult
    rin = radius - thick
    m = on & (r <= radius) & (r >= rin) & (thick > 0.4)
    if not m.any():
        return m
    k = (r - rin) / np.maximum(thick, 0.5)  # 0 ic, 1 dis
    if inner_hi:
        k = 1.0 - k
    tone = np.where(k > 0.78, 4, np.where(k > 0.5, 3, np.where(k > 0.22, 2, 1)))
    for t in range(1, 5):
        cv.put(m & (tone == t), pal[t])
    if outline:
        cv.put(outline_of(m) & ~cv.filled(), pal[0])
    return m


def ring_band(cv, cx, cy, radius, thick, pal, squash=1.0, gaps=None, outline=True, lit_outer=True, mult=None):
    """Dolu halka bandi (sok dalgasi). Dis kenar parlak, ic koyu; gaps: [(a0, a1)] kesilen acilar; mult: aciya bagli
    kalinlik carpani (0 -> bosluk; parcalar hilal gibi incelerek biter, duz kesilmez)."""
    r, th = _polar(cv, cx, cy, squash)
    thick_a = thick * mult if mult is not None else thick
    rin = radius - thick_a
    m = (r <= radius) & (r >= rin) & (np.asarray(thick_a) > 0.4)
    if gaps:
        for (a0, a1) in gaps:
            m &= _ang_in(th, a0, a1) < 0.0
    if not m.any():
        return m
    k = (r - (radius - thick)) / max(thick, 0.5)
    if not lit_outer:
        k = 1.0 - k
    # ust yarida (isik) bir ton acik
    top = np.sin(th) < -0.2
    tone = np.where(k > 0.7, 4, np.where(k > 0.4, 3, np.where(k > 0.15, 2, 1)))
    tone = np.where(top & (tone < 4), tone + 1, tone)
    tone = np.minimum(tone, 4)
    for t in range(1, 5):
        cv.put(m & (tone == t), pal[t])
    if outline:
        cv.put(outline_of(m) & ~cv.filled(), pal[0])
    return m


def ellipse_mask(cv, cx, cy, rx, ry):
    X, Y = cv.grid()
    return ((X - cx) / rx) ** 2 + ((Y - cy) / ry) ** 2 <= 1.0


def blob_mask(cv, cx, cy, rx, ry, seed, wobble=0.18, lobes=7):
    """Duzensiz kenarli elips (zemin birikintisi). Kenar yaricapi aciyla sinuzoidal oynar - tohumla sabit."""
    rng = np.random.default_rng(seed)
    ph = rng.uniform(0, TAU, 3)
    X, Y = cv.grid()
    th = np.arctan2((Y - cy) / ry, (X - cx) / rx)
    k = 1.0 + wobble * (0.55 * np.sin(lobes * th + ph[0]) + 0.3 * np.sin((lobes + 3) * th + ph[1]) + 0.15 * np.sin(2 * th + ph[2]))
    return ((X - cx) / (rx * k)) ** 2 + ((Y - cy) / (ry * k)) ** 2 <= 1.0


# ====================================================================== cizgi / isik yolu
def thick_line(cv, x0, y0, x1, y1, w, col):
    X, Y = cv.grid()
    ax, ay = x1 - x0, y1 - y0
    L2 = max(ax * ax + ay * ay, 1e-6)
    t = np.clip(((X - x0) * ax + (Y - y0) * ay) / L2, 0, 1)
    d = np.hypot(X - (x0 + t * ax), Y - (y0 + t * ay))
    m = d <= w * 0.5
    cv.put(m, col)
    return m


def bolt_path(rng, x0, y0, x1, y1, segs, jag):
    pts = [(x0, y0)]
    for i in range(1, segs):
        t = i / segs
        nx, ny = -(y1 - y0), (x1 - x0)
        L = math.hypot(nx, ny) or 1.0
        o = rng.uniform(-jag, jag)
        pts.append((x0 + (x1 - x0) * t + nx / L * o, y0 + (y1 - y0) * t + ny / L * o))
    pts.append((x1, y1))
    return pts


def draw_bolt(cv, pts, pal, core_w=1.0, glow_w=3.0):
    """Simsek: dis parlama (acik) + cekirdek (parlak) + kontur."""
    m_glow = np.zeros((cv.h, cv.w), dtype=bool)
    for (a, b) in zip(pts[:-1], pts[1:]):
        m_glow |= thick_line(cv, a[0], a[1], b[0], b[1], glow_w, pal[3])
    for (a, b) in zip(pts[:-1], pts[1:]):
        thick_line(cv, a[0], a[1], b[0], b[1], core_w, pal[4])
    cv.put(outline_of(m_glow) & ~cv.filled(), pal[1])
    return m_glow


# ====================================================================== patlama (hit_effects/big_burst dili)
def burst(cv, cx, cy, R, t, pal, smoke, seed, n_puffs=7, squash=1.0, shards=True, shard_col=None):
    """Tek karede patlama evresi (t 0..1): 0-0,12 krem parlama + isinlar, sonra dolu golgeli alev kumeleri disari acilir,
    ortada krem cekirdek; 0,45'ten sonra kumeler duman paletine gecer ve hilale asinarak kuculur; ince krem parcalar ve
    kivilcimlar disari ucar. pal: sicak palet, smoke: sogumus palet."""
    import random as _r
    rng = _r.Random(seed)
    base = [(TAU * k / n_puffs + rng.uniform(-0.25, 0.25), rng.uniform(0.75, 1.1), rng.uniform(0.8, 1.15)) for k in range(n_puffs)]
    if t < 0.12:
        k = t / 0.12
        rr = R * (0.28 + 0.14 * k)
        disc_flash(cv, cx, cy, rr, core=CREAM, rim=pal[4], squash=squash)
        for q in range(4):
            a = q * TAU / 4 + math.pi / 4 * (1 if k > 0.5 else 0)
            for d in range(int(rr) + 1, int(rr + R * 0.35) + 1):
                cv.px(cx + math.cos(a) * d, cy + math.sin(a) * d * squash, pal[4] if d < rr + R * 0.2 else pal[3])
        return
    u = (t - 0.12) / 0.88
    spread = ease_out(min(1.0, u * 1.6))
    cool = max(0.0, (u - 0.3) / 0.7)
    use = pal if cool < 0.25 else (smoke if cool > 0.55 else [pal[0], pal[1], smoke[2], pal[2], pal[3]])
    circles = []
    cuts = []
    for (a, dk, rk) in base:
        d = R * (0.12 + 0.5 * spread) * dk
        x = cx + math.cos(a) * d
        y = cy + math.sin(a) * d * squash - R * 0.12 * cool
        r = R * (0.24 + 0.1 * spread) * rk * (1.0 - 0.55 * cool)
        circles.append((x, y, r))
        if cool > 0.0:
            ca = a + math.pi
            cuts.append((x + math.cos(ca) * r * 0.35 + r * 0.2, y + math.sin(ca) * r * 0.35 * squash - r * 0.2, r * (0.35 + 0.75 * cool)))
    if u < 0.3:
        circles.append((cx, cy, R * (0.3 - 0.25 * u)))
    m = puffs(cv, circles, use, cut=cuts or None, squash=squash)
    if u < 0.3:
        X, Y = cv.grid()
        core = m & erode(erode(erode(erode(m)))) & (np.hypot(X - cx, (Y - cy) / squash) < R * (0.22 - 0.3 * u))
        cv.put(core, CREAM)
    if shards and u < 0.75:
        sc = shard_col or CREAM
        for q in range(9):
            a = TAU * q / 9 + 0.35
            d0 = R * (0.35 + 0.65 * spread)
            L = max(1, int(R * 0.18 * (1.0 - u)))
            for s_ in range(L):
                cv.px(cx + math.cos(a) * (d0 + s_), cy + math.sin(a) * (d0 + s_) * squash, sc)
    if u > 0.2:
        for q in range(6):
            a = rng.uniform(0, TAU)
            d = R * (0.6 + 0.5 * spread) * rng.uniform(0.8, 1.15)
            if rng.random() < 1.0 - cool * 0.6:
                cv.px(cx + math.cos(a) * d, cy + math.sin(a) * d * squash + cool * 3, pal[3] if q % 2 else pal[4])
    return m


def facets(cv, faces, pal, outline=True):
    """Kristal / kaya yuzeyleri: faces [(noktalar, ton)] - her yuz tek ton; birlesimin konturu pal[0]."""
    allm = np.zeros((cv.h, cv.w), dtype=bool)
    for (pts, tone) in faces:
        m = poly_mask(cv, pts)
        cv.put(m, pal[tone])
        allm |= m
    if outline:
        cv.put(outline_of(allm) & ~cv.filled(), pal[0])
    return allm


def break_mult(cv, cx, cy, squash, k, seed, lobes=9):
    """Parcalanma carpani (k 0..1 ilerledikce bosluklar buyur): aciya bagli 0..1 - bosluk kenarina dogru YUMUSAK iner,
    boylece parcalar hilal gibi sivrilerek biter (eskiden radyal duz kesiliyordu)."""
    X, Y = cv.grid()
    th = np.arctan2((Y - cy) / squash, X - cx)
    pat = np.sin(th * lobes + seed) * 0.6 + np.sin(th * max(2, lobes // 2) + seed * 2) * 0.4
    thr = 1.0 - 1.7 * k
    return np.clip((thr - pat) / 0.45, 0.0, 1.0) ** 0.7


def shock_ring(cv, cx, cy, R, thick, t, pal, squash, seed, break_from=0.55):
    """Genisleyen dolu sok halkasi; break_from'dan sonra parcalanir (parcalar incelerek biter), dis kenar parlak."""
    mult = None
    if t > break_from:
        mult = break_mult(cv, cx, cy, squash, (t - break_from) / (1.0 - break_from), seed)
    return ring_band(cv, cx, cy, R, thick, pal, squash=squash, mult=mult)


# ====================================================================== kaydet
def ease_out(t):
    return 1.0 - (1.0 - t) ** 2


def lerp(a, b, t):
    return a + (b - a) * t
