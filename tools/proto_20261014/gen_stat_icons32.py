"""Mini stat paneli için 32x32 piksel simgeler (PROTOTİP, 2026-10-14).

Kullanıcı: "16x16 değil 32x32 istiyorum, bunlar çok ruhsuz" + "LoL'den çalmayalım, eskileri referans almayalım".
Sıfırdan tasarım. Her parça bir MASKE (çokgen/daire/kalın çizgi) + 5 tonlu malzeme rampası; ton, kenar normaline
(ışık sol üstte) ve şeklin hacmine göre seçilir. Kontur her parçanın kendi koyu tonundan (seçici kontur), sonraki parça
öncekinin üstüne konturunu çizer (parçalar birbirinden ayrılır). 1 sanat pikseli = 1 ekran pikseli.

Çıktı: out/stat_ikon32/<id>.png + out/stat_ikon32_onizleme.png (x5, adlı) + out/stat_ikon32_1x.png (koyu levhada 1:1, x3).
Kullanım: python tools/proto_20261014/gen_stat_icons32.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(HERE, "out", "stat_ikon32")
N = 32
LIGHT = (-0.6, -0.8)  # ışık sol üstten


def hx(c):
    c = c.lstrip("#")
    return (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), 255)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (255,)


def ramp(*cs):
    return [hx(c) for c in cs]


STEEL = ramp("#363e52", "#5d6880", "#8e9bb2", "#c3cedd", "#f4f8ff")
WOOD = ramp("#3d220f", "#64391a", "#8e5a2b", "#b9814a", "#e3b47c")
LEATHER = ramp("#3b1d10", "#5e3019", "#86472a", "#b0663e", "#d8925f")
GOLD = ramp("#6b3f0a", "#a8650f", "#df9a1f", "#ffd04a", "#fff6c0")
RED = ramp("#4a0a18", "#86132a", "#c4283a", "#ef5a5f", "#ffc0b8")
DRED = ramp("#2a0610", "#4e0b1c", "#7a1426", "#a8213a", "#d84a5a")
GREEN = ramp("#123d1e", "#22692e", "#3a9a3e", "#79d257", "#d8f9a8")
BLUE = ramp("#0f2350", "#1d4596", "#2f6fd0", "#62a8f0", "#d2ecff")
CYAN = ramp("#0f4250", "#1f7d90", "#3fb5c8", "#8fe3ee", "#effeff")
ORANGE = ramp("#5a1e08", "#9a3a10", "#e2651c", "#ffa040", "#ffe6a8")
WHITE = ramp("#58627a", "#9aa6ba", "#d3dbe8", "#f2f6fb", "#ffffff")
GLASS = ramp("#1e2840", "#2c3a58", "#3f5274", "#a9c4e0", "#f0f8ff")
INK = hx("#0d0710")
NIGHT = ramp("#0d0710", "#1e0d18", "#33121f", "#4f1a2c", "#8a2d40")
BAT = ramp("#1a0a14", "#2e1224", "#4a1d36", "#6e2e4e", "#a04a6e")


# ------------------------------------------------------------------------------------------- maskeler

def m_poly(pts):
    im = Image.new("1", (N, N), 0)
    ImageDraw.Draw(im).polygon([(float(x), float(y)) for x, y in pts], fill=1)
    return {(x, y) for y in range(N) for x in range(N) if im.getpixel((x, y))}


def m_line(pts, w):
    im = Image.new("1", (N, N), 0)
    ImageDraw.Draw(im).line([(float(x), float(y)) for x, y in pts], fill=1, width=w, joint="curve")
    return {(x, y) for y in range(N) for x in range(N) if im.getpixel((x, y))}


def m_fn(f):
    return {(x, y) for y in range(N) for x in range(N) if f(x + 0.5, y + 0.5)}


def m_circle(cx, cy, r):
    return m_fn(lambda x, y: (x - cx) ** 2 + (y - cy) ** 2 <= r * r)


def m_ring(cx, cy, r0, r1, a0=None, a1=None):
    def f(x, y):
        d = math.hypot(x - cx, y - cy)
        if not (r0 <= d <= r1):
            return False
        if a0 is None:
            return True
        a = math.degrees(math.atan2(y - cy, x - cx)) % 360
        return (a0 <= a <= a1) if a0 <= a1 else (a >= a0 or a <= a1)
    return m_fn(f)


def heater(cx, top, w, h, straight=0.45):
    """Isıtıcı kalkan biçimi: üst düz, alt sivri."""
    def f(x, y):
        t = (y - top) / h
        if t < 0 or t > 1:
            return False
        if t <= straight:
            half = w / 2
        else:
            u = (t - straight) / (1 - straight)
            half = w / 2 * math.sqrt(max(0.0, 1 - u ** 1.6))
        return abs(x - cx) <= half
    return m_fn(f)


def heart(cx, cy, s):
    def f(x, y):
        px = (x - cx) / s
        py = -(y - cy) / s
        return (px * px + py * py - 1) ** 3 - px * px * py ** 3 <= 0
    return m_fn(f)


# ------------------------------------------------------------------------------------------- gölgeleme

def shade(mask, volume=0.9, bevel=1.5):
    """Her piksel için 0..4 ton numarası (0 koyu, 4 parlak)."""
    if not mask:
        return {}
    cx = sum(p[0] for p in mask) / len(mask)
    cy = sum(p[1] for p in mask) / len(mask)
    ext = max(math.hypot(p[0] - cx, p[1] - cy) for p in mask) + 0.5
    lx, ly = LIGHT
    out = {}
    for (x, y) in mask:
        nx = ny = 0.0
        mind = 9.0
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                if (dx or dy) and (x + dx, y + dy) not in mask:
                    d = math.hypot(dx, dy)
                    if d <= 2.3:
                        nx += dx / (d * d)
                        ny += dy / (d * d)
                        mind = min(mind, d)
        v = ((x - cx) * lx + (y - cy) * ly) / ext * volume
        base = 2 + (1 if v > 0.4 else (-1 if v < -0.4 else 0))
        if mind <= bevel and (nx or ny):
            nd = (nx * lx + ny * ly) / math.hypot(nx, ny)
            if mind <= 1.0:
                if nd > 0.55:
                    idx = 4
                elif nd > 0.15:
                    idx = 3
                elif nd < -0.55:
                    idx = 0
                elif nd < -0.15:
                    idx = 1
                else:
                    idx = base
            else:
                idx = 3 if nd > 0.35 else (1 if nd < -0.35 else base)
        else:
            idx = base
        out[(x, y)] = idx
    return out


class Icon:
    def __init__(self):
        self.px = {}

    def outline_of(self, mask, col):
        for (x, y) in mask:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (x + dx, y + dy)
                if q not in mask and 0 <= q[0] < N and 0 <= q[1] < N:
                    self.px[q] = col

    def layer(self, mask, rmp, outline=True, volume=0.9, bevel=1.5, idx_fn=None, oc=None):
        """Maskeyi rampayla boyar; outline=True ise önce kendi koyu tonundan kontur."""
        if outline:
            self.outline_of(mask, oc or mix(rmp[0], INK, 0.55))
        sh = shade(mask, volume, bevel)
        for p, i in sh.items():
            if idx_fn:
                i = idx_fn(p, i)
            self.px[p] = rmp[max(0, min(4, i))]
        return self

    def put(self, pts, col):
        for p in pts:
            if 0 <= p[0] < N and 0 <= p[1] < N:
                self.px[p] = col if len(col) == 4 else col + (255,)

    def glow(self, pts, col, a):
        for p in pts:
            if 0 <= p[0] < N and 0 <= p[1] < N and p not in self.px:
                self.px[p] = col[:3] + (a,)

    def sparkle(self, x, y, col, big=False):
        self.put([(x, y)], WHITE[4])
        arm = [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
        self.put(arm, col)
        if big:
            self.put([(x + 2, y), (x - 2, y), (x, y + 2), (x, y - 2)], col[:3] + (150,))

    def image(self):
        im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        for p, c in self.px.items():
            im.putpixel(p, c)
        return im


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


# ------------------------------------------------------------------------------------------- simgeler

def ic_damage():
    """Savaş baltası: deri sargılı sap, hilal ağız, keskin kenar parıltısı."""
    ic = Icon()
    a, b = (6, 27), (23, 6)
    ic.layer(m_line([a, b], 3), WOOD, volume=0.3)
    ic.layer(m_line([(7.5, 25.5), (12, 20)], 4), LEATHER, volume=0.2,
             idx_fn=lambda p, i: i - 1 if (p[0] + p[1]) % 3 == 0 else i)
    ic.layer(m_circle(5.5, 27.5, 2.3), GOLD)
    d = (b[0] - a[0], b[1] - a[1])
    L = math.hypot(*d)
    al = (d[0] / L, d[1] / L)
    pp = (-al[1], -al[0])  # sapa dik, sol üst tarafa
    pp = (al[1] * -1, al[0]) if False else (-al[1], al[0])
    pp = (pp[0] * -1, pp[1] * -1)
    c = lerp(a, b, 0.82)
    pts = [(c[0] + al[0] * 3.5 + pp[0] * 1, c[1] + al[1] * 3.5 + pp[1] * 1)]
    for k in range(13):
        t = -1.15 + 2.3 * k / 12
        r = 12.0
        pts.append((c[0] + pp[0] * r * math.cos(t) + al[0] * 9.5 * math.sin(t),
                    c[1] + pp[1] * r * math.cos(t) + al[1] * 9.5 * math.sin(t)))
    pts.append((c[0] - al[0] * 3.5 + pp[0] * 1, c[1] - al[1] * 3.5 + pp[1] * 1))
    pts = pts[:1] + list(reversed(pts[1:-1])) + pts[-1:] if False else pts
    head = m_poly(pts)
    ic.layer(head, STEEL, volume=1.0)
    # keskin kenar: ağzın dış 1 px'i parlak
    edge = {p for p in head if any((p[0] + dx, p[1] + dy) not in head for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            and ((p[0] - c[0]) * pp[0] + (p[1] - c[1]) * pp[1]) > 6.5}
    ic.put(edge, STEEL[4])
    # arka diken
    back = m_poly([(c[0] - pp[0] * 1 + al[0] * 2, c[1] - pp[1] * 1 + al[1] * 2), (c[0] - pp[0] * 7, c[1] - pp[1] * 7),
                   (c[0] - pp[0] * 1 - al[0] * 2, c[1] - pp[1] * 1 - al[1] * 2)])
    ic.layer(back, STEEL, volume=0.4)
    # sap başlığı + perçinler
    ic.put([(int(c[0] + al[0] * 4), int(c[1] + al[1] * 4))], GOLD[3])
    ic.put([(int(round(c[0] + pp[0] * 2)), int(round(c[1] + pp[1] * 2)))], GOLD[3])
    ic.put([(int(round(c[0] + pp[0] * 2 + 1)), int(round(c[1] + pp[1] * 2 + 1)))], GOLD[1])
    return ic


def ic_fire_rate():
    """İki hızlı hançer: arkada soluk iz kopyası, sarı hız çizgileri."""
    ic = Icon()
    for (x0, y0, x1, y1, al) in [(1, 15, 9, 7, 110), (4, 22, 8, 18, 160), (10, 30, 18, 22, 110)]:
        ic.glow(m_line([(x0, y0), (x1, y1)], 1), GOLD[3], al)

    def dagger(ox, oy, ghost=False):
        blade = m_poly([(12 + ox, 18 + oy), (16 + ox, 22 + oy), (29 + ox, 3 + oy)])
        guard = m_line([(10 + ox, 18 + oy), (16 + ox, 24 + oy)], 2)
        grip = m_line([(7 + ox, 25 + oy), (12 + ox, 20 + oy)], 3)
        pom = m_circle(6 + ox, 26.5 + oy, 1.8)
        if ghost:
            for m in (blade, guard, grip, pom):
                ic.glow(m, CYAN[3], 70)
            return
        ic.layer(grip, LEATHER, volume=0.2, idx_fn=lambda p, i: i - 1 if (p[0] + p[1]) % 3 == 0 else i)
        ic.layer(pom, GOLD)
        ic.layer(blade, STEEL, volume=1.0)
        # oluk: bıçak ortasında koyu çizgi
        ic.put(m_line([(16 + ox, 18 + oy), (24 + ox, 9 + oy)], 1) & blade, STEEL[1])
        ic.layer(guard, GOLD, volume=0.4)
    dagger(-4, 3, ghost=True)
    dagger(0, 0)
    ic.sparkle(28, 4, GOLD[3])
    return ic


def ic_crit_chance():
    """Hedef tahtası + tam ortaya saplanmış ok (gölgesiyle)."""
    ic = Icon()
    cx, cy, R = 13.5, 17.5, 12.0
    disc = m_circle(cx, cy, R)
    rings = [(2.6, RED), (5.4, WHITE), (8.3, RED), (12.5, WHITE)]

    def ring_of(p):
        d = math.hypot(p[0] + 0.5 - cx, p[1] + 0.5 - cy)
        for r, rm in rings:
            if d <= r:
                return rm
        return WHITE
    ic.outline_of(disc, mix(RED[0], INK, 0.55))
    sh = shade(disc, 1.0)
    for p, i in sh.items():
        rm = ring_of(p)
        ic.px[p] = rm[max(0, min(4, i if rm is RED else i))]
    # halka ayrımı: kırmızı halkanın iç kenarı koyu
    # ok gölgesi
    ic.put({(x + 1, y + 2) for (x, y) in m_line([(14, 17), (24, 7)], 1)} & disc, mix(RED[1], INK, 0.5))
    shaft = m_line([(14, 17), (27, 4)], 2)
    ic.layer(shaft, WOOD, volume=0.2)
    fl = m_poly([(24, 3), (29, 0), (31, 1), (30, 4), (28, 8), (25, 6)])
    ic.layer(fl, RED, volume=0.8)
    ic.put(m_line([(25, 6), (29, 2)], 1) & fl, RED[1])
    ic.put([(13, 17), (14, 18), (13, 18)], STEEL[1])
    ic.sparkle(4, 6, GOLD[3])
    return ic


def ic_crit_damage():
    """Akkor çekirdekli patlama yıldızı + ortada ünlem."""
    ic = Icon()
    cx, cy = 16.0, 16.0
    pts = []
    for k in range(20):
        a = math.pi * 2 * k / 20 - math.pi / 2 + math.pi / 20
        r = 15.0 if k % 2 == 0 else 7.2
        if k % 4 == 2:
            r = 11.5
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    star = m_poly(pts)
    ic.outline_of(star, mix(ORANGE[0], INK, 0.5))
    for p in star:
        d = math.hypot(p[0] + 0.5 - cx, p[1] + 0.5 - cy)
        if d < 4.5:
            c = ORANGE[4]
        elif d < 7.0:
            c = GOLD[3]
        elif d < 9.5:
            c = ORANGE[3]
        elif d < 12.0:
            c = ORANGE[2]
        else:
            c = RED[2]
        ic.px[p] = c
    ex = m_poly([(13, 6), (19, 6), (18, 19), (14, 19)])
    dot = m_circle(16, 23.2, 2.1)
    for m in (ex, dot):
        ic.layer(m, NIGHT, volume=0.6, oc=INK)
    ic.put([(14, 7), (14, 8), (14, 9)], NIGHT[4])
    for (x, y) in [(4, 5), (27, 26), (28, 7)]:
        ic.sparkle(x, y, GOLD[3])
    return ic


def ic_cooldown():
    """Kum saati: ahşap başlıklar + altın perçin, cam, akan camgöbeği büyülü kum."""
    ic = Icon()
    glass = m_poly([(8, 5), (24, 5), (24, 7), (17.5, 15), (17.5, 17), (24, 25), (24, 27), (8, 27), (8, 25),
                    (14.5, 17), (14.5, 15), (8, 7)])
    ic.layer(glass, GLASS, volume=0.4)
    sand_top = m_poly([(10, 9), (22, 9), (17, 14.5), (15, 14.5)]) & glass
    ic.layer(sand_top, CYAN, outline=False, volume=0.8)
    pile = m_poly([(9, 27), (23, 27), (19, 21), (16, 19.5), (13, 21)]) & glass
    ic.layer(pile, CYAN, outline=False, volume=0.8)
    ic.put([(16, 16), (16, 17), (16, 18), (15, 19), (16, 20)], CYAN[4])
    # cam parıltısı
    ic.put([(10, 6), (11, 6), (9, 7), (10, 26), (9, 25)], GLASS[4])
    ic.put([(22, 23), (22, 24), (21, 22)], GLASS[3])
    for (x0, x1, y0, y1) in [(4, 28, 1, 4), (4, 28, 28, 31)]:
        cap = m_poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)])
        ic.layer(cap, WOOD, volume=0.6)
    for x in (6, 26):
        post = m_poly([(x - 1, 5), (x + 1, 5), (x + 1, 28), (x - 1, 28)])
        ic.layer(post, WOOD, volume=0.2)
    ic.put([(5, 2), (27, 2), (5, 29), (27, 29)], GOLD[3])
    ic.put([(6, 3), (26, 3), (6, 30), (26, 30)], GOLD[1])
    ic.sparkle(29, 14, CYAN[3])
    return ic


def ic_lifesteal():
    """Kan yarasası: tırtıklı kanatlar, kırmızı gözler, pençesinde kan damlası."""
    ic = Icon()
    def wing(sgn):
        cx = 16
        pts = [(cx + sgn * 3, 9), (cx + sgn * 8, 5), (cx + sgn * 13, 6), (cx + sgn * 15.5, 10), (cx + sgn * 15, 15),
               (cx + sgn * 12.5, 13.5), (cx + sgn * 11, 17), (cx + sgn * 8.5, 14.5), (cx + sgn * 6.5, 18), (cx + sgn * 3, 15)]
        return m_poly(pts)
    for sg in (-1, 1):
        w = wing(sg)
        ic.layer(w, BAT, volume=0.8)
        # kanat kemikleri
        ic.put(m_line([(16 + sg * 3, 10), (16 + sg * 8, 6), (16 + sg * 13, 7)], 1) & w, BAT[4])
        ic.put(m_line([(16 + sg * 8, 6), (16 + sg * 8.5, 13)], 1) & w, BAT[3])
        ic.put(m_line([(16 + sg * 13, 7), (16 + sg * 12.5, 12)], 1) & w, BAT[3])
    body = m_fn(lambda x, y: ((x - 16) / 3.6) ** 2 + ((y - 13) / 6.0) ** 2 <= 1)
    ears = m_poly([(12.5, 9), (13, 4), (15.5, 8)]) | m_poly([(19.5, 9), (19, 4), (16.5, 8)])
    ic.layer(body | ears, BAT, volume=1.0)
    ic.put([(14, 11), (18, 11)], hx("#ff3a3a"))
    ic.put([(14, 10), (18, 10)], hx("#ffb0a0"))
    ic.put([(15, 15), (17, 15)], WHITE[4])
    drop = m_fn(lambda x, y: ((x - 16) ** 2 + (y - 26.5) ** 2 <= 3.4 ** 2) or (20.5 < y < 26.5 and abs(x - 16) <= (y - 20.5) * 0.6))
    ic.layer(drop, RED, volume=1.0)
    ic.put([(14, 25), (14, 26)], RED[4])
    ic.put([(15, 18), (17, 18)], BAT[1])
    ic.glow(m_ring(16, 26, 4.5, 6.0), RED[3], 60)
    return ic


def ic_dodge():
    """Rüzgârda süzülen tüy + kıvrılan esinti çizgileri."""
    ic = Icon()
    for pts, al in [([(1, 11), (10, 11), (13, 9), (13, 6), (10, 5), (8, 7)], 200),
                    ([(3, 25), (14, 25), (18, 27), (18, 30), (15, 31)], 200),
                    ([(20, 19), (30, 19)], 150)]:
        ic.glow(m_line(pts, 1), CYAN[3], al)
    quill = [(7, 29), (12, 22), (18, 13), (24, 6), (28, 2)]
    vane = m_fn(lambda x, y: _feather(x, y))
    ic.layer(vane, WHITE, volume=1.0, oc=mix(CYAN[0], INK, 0.5))
    # tüy çentikleri
    for (x, y) in [(15, 21), (16, 22), (21, 15), (22, 16), (12, 14), (11, 13)]:
        if (x, y) in vane:
            ic.px[(x, y)] = WHITE[1]
    ic.put(m_line(quill, 1), CYAN[1])
    ic.put(m_line([(7, 29), (10, 25)], 1), WOOD[2])
    ic.put([(17, 9), (16, 10), (18, 8)], WHITE[4])
    ic.sparkle(27, 12, CYAN[3])
    return ic


def _feather(x, y):
    # quill boyunca (7,29)->(28,2) eğik elips
    ax, ay = 7.0, 29.0
    dx, dy = 21.0, -27.0
    L = math.hypot(dx, dy)
    ux, uy = dx / L, dy / L
    t = ((x - ax) * ux + (y - ay) * uy) / L
    s = (x - ax) * -uy + (y - ay) * ux
    if t < 0.18 or t > 1.0:
        return False
    w = 6.2 * math.sin(math.pi * min(1.0, (t - 0.18) / 0.82) ** 0.8)
    return abs(s + 0.6) <= w


def ic_speed():
    """Kanatlı çizme: deri, kıvrık konç, altın bağcık, beyaz kanat, toz/hız çizgileri."""
    ic = Icon()
    for (x0, y, x1, al) in [(0, 9, 5, 170), (1, 15, 6, 210), (0, 21, 5, 170)]:
        ic.glow(m_line([(x0, y), (x1, y)], 1), WHITE[3], al)
    wing = m_poly([(11, 8), (3, 3), (5, 6), (2, 7), (5, 10), (3, 12), (8, 14), (11, 14)])
    ic.layer(wing, WHITE, volume=0.9, oc=mix(STEEL[0], INK, 0.4))
    ic.put([(6, 8), (7, 10), (6, 11)], WHITE[1])
    boot = m_poly([(10, 6), (20, 6), (20, 18), (27, 20), (29, 23), (29, 26), (9, 26), (10, 18)])
    ic.layer(boot, LEATHER, volume=1.0)
    cuff = m_poly([(9, 4), (21, 4), (21, 8), (9, 8)])
    ic.layer(cuff, LEATHER, volume=0.6, idx_fn=lambda p, i: i + 1)
    sole = m_poly([(8, 26), (30, 26), (30, 29), (8, 29)])
    ic.layer(sole, WOOD, volume=0.3, idx_fn=lambda p, i: i - 1)
    ic.put([(17, 11), (18, 13), (17, 15), (18, 17), (20, 19), (22, 20)], GOLD[3])
    ic.put([(12, 10), (12, 11), (12, 12), (13, 20)], LEATHER[4])
    ic.put([(2, 27), (4, 28), (1, 29), (5, 30)], WOOD[3][:3] + (160,))
    return ic


def ic_shield_pen():
    """Çelik çerçeveli ahşap kalkan; çatlattan geçen mızrak, kıymıklar."""
    ic = Icon()
    sh = heater(13.5, 6, 21, 25)
    ic.layer(sh, STEEL, volume=0.6)
    face = heater(13.5, 8, 17, 21)
    ic.layer(face, WOOD, volume=0.9, idx_fn=lambda p, i: i - 1 if p[0] in (9, 13, 17) else i, oc=STEEL[1])
    ic.put([(13, 18), (13, 19), (14, 19)], GOLD[3])
    cracks = [[(17, 13), (14, 15), (13, 18)], [(17, 13), (21, 16), (21, 19)], [(17, 13), (12, 10), (10, 11)],
              [(17, 13), (18, 18), (16, 22), (17, 25)]]
    for c in cracks:
        ic.put(m_line(c, 1) & face, mix(WOOD[0], INK, 0.5))
    shaft = m_line([(17, 13), (31, 0)], 3)
    ic.layer(shaft, WOOD, volume=0.3)
    # içeri girmiş ucun etrafı: kıymıklar
    ic.put([(15, 11), (19, 15), (20, 12)], WOOD[4])
    ic.put([(18, 11), (16, 14)], INK)
    # sağ üstte mızrak bağı
    ic.layer(m_line([(26, 4), (28, 2)], 3), GOLD, volume=0.4)
    for (x, y) in [(23, 19), (25, 21), (5, 4)]:
        ic.put([(x, y)], WOOD[3])
    return ic


def ic_range():
    """Gerili yay, nişanlanmış ok ve uzakta küçük hedef ışıltısı."""
    ic = Icon()
    pts = []
    for k in range(17):
        t = k / 16
        pts.append((9 + 9 * math.sin(math.pi * t), 2 + 27 * t))
    limb = m_line(pts, 3)
    ic.layer(limb, WOOD, volume=0.5)
    grip = m_line([(17.5, 13), (17.5, 18)], 4)
    ic.layer(grip, LEATHER, volume=0.3, idx_fn=lambda p, i: i - 1 if p[1] % 2 == 0 else i)
    ic.put([(9, 2), (9, 29)], GOLD[3])
    string = m_line([(9, 2), (4, 15.5), (9, 29)], 1)
    ic.glow(string, WHITE[3], 230)
    shaft = m_line([(4, 15.5), (25, 15.5)], 1)
    ic.layer(shaft, WOOD, volume=0.1)
    head = m_poly([(24, 13), (30, 15.5), (24, 18)])
    ic.layer(head, STEEL, volume=0.8)
    fl = m_poly([(2, 12), (7, 14.5), (7, 16.5), (2, 19), (4, 15.5)])
    ic.layer(fl, RED, volume=0.6)
    for x in (27, 29, 31):
        pass
    ic.put([(29, 7), (31, 7)], GOLD[3][:3] + (150,))
    ic.sparkle(29, 4, GOLD[3])
    return ic


def _mana_shield(ic):
    outer = heater(16, 2, 25, 29)
    ic.layer(outer, BLUE, volume=0.5, idx_fn=lambda p, i: max(1, i))
    inner = heater(16, 5, 19, 23)
    ic.layer(inner, BLUE, volume=1.0, oc=BLUE[1], idx_fn=lambda p, i: i - 1 if i < 4 else i)
    ic.put([(6, 3), (7, 3), (5, 4), (5, 5)], BLUE[4])
    return inner


def ic_shield_prot():
    """Mana kalkanı: ortada içe dönen girdap (soğurma)."""
    ic = Icon()
    inner = _mana_shield(ic)
    cx, cy = 16.0, 14.5
    pts = set()
    for k in range(260):
        t = k / 260 * math.pi * 3.2
        r = 0.6 + t * 0.62
        pts.add((int(math.floor(cx + math.cos(t) * r)), int(math.floor(cy + math.sin(t) * r))))
    for p in pts:
        if p in inner:
            ic.px[p] = CYAN[4] if math.hypot(p[0] - cx, p[1] - cy) < 4 else CYAN[3]
    ic.glow({(x + dx, y + dy) for (x, y) in pts for dx, dy in ((1, 0), (0, 1))}, CYAN[3], 90)
    ic.put([(16, 14), (15, 14)], WHITE[4])
    ic.sparkle(27, 26, CYAN[3])
    return ic


def ic_shield_amount():
    """Mana kalkanı + kalın beyaz artı (parlamalı)."""
    ic = Icon()
    _mana_shield(ic)
    plus = m_poly([(14, 7), (18, 7), (18, 12), (23, 12), (23, 16), (18, 16), (18, 21), (14, 21), (14, 16), (9, 16), (9, 12), (14, 12)])
    ic.layer(plus, WHITE, volume=0.5, oc=BLUE[0])
    ic.put([(15, 8), (15, 9), (10, 13)], WHITE[4])
    ic.sparkle(26, 24, CYAN[3])
    return ic


def ic_shield_regen():
    """Mana kalkanı + dönen yenilenme oku."""
    ic = Icon()
    _mana_shield(ic)
    cx, cy = 16.0, 14.5
    arc = m_ring(cx, cy, 4.2, 6.6, 300, 230)
    ic.layer(arc, CYAN, volume=0.6, oc=BLUE[0], idx_fn=lambda p, i: i + 1)
    head = m_poly([(19.5, 4.5), (25.5, 9.5), (18.5, 12)])
    ic.layer(head, CYAN, volume=0.6, oc=BLUE[0], idx_fn=lambda p, i: i + 1)
    ic.put([(16, 14), (16, 15)], CYAN[4])
    ic.sparkle(26, 24, CYAN[3])
    return ic


def ic_health_regen():
    """Hacimli kalp + yükselen yeşil ok + yeşil ışıltılar."""
    ic = Icon()
    h = heart(14.5, 15.0, 11.5)
    ic.layer(h, RED, volume=1.2)
    ic.put([(7, 8), (8, 7), (9, 7), (7, 9)], RED[4])
    arrow = m_poly([(24, 13), (31, 20), (27, 20), (27, 29), (21, 29), (21, 20), (17, 20)])
    ic.layer(arrow, GREEN, volume=0.8)
    ic.put([(23, 16), (22, 18), (22, 21), (22, 24)], GREEN[4])
    ic.sparkle(4, 25, GREEN[3])
    ic.sparkle(28, 6, GREEN[3])
    return ic


def ic_heal_power():
    """Şifa iksiri: yuvarlak cam şişe, ışıyan yeşil sıvı, kabarcıklar, mantar tıpa."""
    ic = Icon()
    bulb = m_circle(16, 20, 10.2)
    neck = m_poly([(13, 4), (19, 4), (19, 12), (13, 12)])
    glass = bulb | neck
    ic.layer(glass, GLASS, volume=0.5)
    liquid = {p for p in bulb if p[1] >= 16 and math.hypot(p[0] + 0.5 - 16, p[1] + 0.5 - 20) <= 8.6}
    ic.layer(liquid, GREEN, outline=False, volume=1.0, idx_fn=lambda p, i: i + 1 if p[1] == 16 else i)
    ic.put([(x, 16) for x in range(9, 24) if (x, 16) in liquid], GREEN[4])
    for (x, y, r) in [(13, 22, 1), (18, 25, 1), (16, 19, 0), (20, 21, 0)]:
        ic.put([(x, y)] if r == 0 else [(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)], GREEN[4])
    ic.put([(10, 14), (9, 15), (9, 16), (10, 13), (11, 12)], GLASS[4])
    ic.put([(14, 6), (14, 7), (14, 8)], GLASS[3])
    lip = m_poly([(11, 3), (21, 3), (21, 5), (11, 5)])
    ic.layer(lip, GLASS, volume=0.3, idx_fn=lambda p, i: i + 1)
    cork = m_poly([(13, 0), (19, 0), (19, 3), (13, 3)])
    ic.layer(cork, WOOD, volume=0.6)
    ic.glow(m_ring(16, 20, 10.3, 12.0), GREEN[3], 55)
    ic.sparkle(26, 7, GREEN[3])
    return ic


def ic_luck():
    """Uğurlu altın nal (ağzı yukarı), çivi delikleri, çıkıntılı uçlar, parıltılar."""
    ic = Icon()
    cx, cy, R, r = 16.0, 15.0, 12.0, 6.0
    low = m_fn(lambda x, y: y >= cy and r <= math.hypot(x - cx, y - cy) <= R)
    arms = m_fn(lambda x, y: 4.0 <= y < cy and (cx - R <= x <= cx - r or cx + r <= x <= cx + R))
    calks = m_poly([(3, 2), (11, 2), (11, 5), (3, 5)]) | m_poly([(21, 2), (29, 2), (29, 5), (21, 5)])
    ic.layer(low | arms, GOLD, volume=1.0)
    ic.layer(calks, GOLD, volume=0.5, idx_fn=lambda p, i: i + 1 if i < 3 else i)
    # iç oluk (nal izi)
    groove = m_fn(lambda x, y: (y >= cy and abs(math.hypot(x - cx, y - cy) - 9.0) <= 0.5) or
                  (6.5 <= y < cy and (abs(x - (cx - 9.0)) <= 0.5 or abs(x - (cx + 9.0)) <= 0.5)))
    for q in groove:
        if q in low or q in arms:
            ic.px[q] = GOLD[1]
    holes = [(7, 9), (7, 15), (9, 21), (22, 21), (24, 15), (24, 9)]
    ic.put([(x + dx, y + dy) for (x, y) in holes for dx in (0, 1) for dy in (0, 1)], NIGHT[1])
    ic.put([(x + 1, y + 1) for (x, y) in holes], GOLD[0])
    ic.put([(5, 7), (5, 8), (5, 9), (5, 10)], GOLD[4])
    ic.sparkle(16, 6, GOLD[3], True)
    ic.sparkle(29, 28, GOLD[3])
    ic.sparkle(2, 28, GOLD[3])
    return ic


ICONS = [
    ("damage", "Saldırı Gücü", ic_damage),
    ("fire_rate", "Saldırı Hızı", ic_fire_rate),
    ("crit_chance", "Kritik Şansı", ic_crit_chance),
    ("crit_damage", "Kritik Hasarı", ic_crit_damage),
    ("cooldown_reduction", "Bekleme Azaltma", ic_cooldown),
    ("lifesteal", "Can Çalma", ic_lifesteal),
    ("dodge", "Sıvışma", ic_dodge),
    ("speed", "Hareket Hızı", ic_speed),
    ("shield_pen_percent", "Kalkan Delme", ic_shield_pen),
    ("range", "Menzil", ic_range),
    ("shield_protection", "MK Soğurma", ic_shield_prot),
    ("shield_amount", "MK Miktarı", ic_shield_amount),
    ("shield_regen", "MK Yenilenmesi", ic_shield_regen),
    ("health_regen", "Can Yenilenmesi", ic_health_regen),
    ("heal_power", "İyileştirme Gücü", ic_heal_power),
    ("luck", "Şans", ic_luck),
]


def main():
    os.makedirs(OUT, exist_ok=True)
    font = ImageFont.truetype(os.path.join(ROOT, "assets", "fonts", "PixeloidSans.ttf"), 9)
    imgs = []
    for key, name, fn in ICONS:
        im = fn().image()
        im.save(os.path.join(OUT, key + ".png"))
        imgs.append((name, im))
    z, cols = 5, 8
    cw, chh = N * z + 24, N * z + 30
    sheet = Image.new("RGBA", (cols * cw + 16, 2 * chh + 16), "#2a1a10")
    d = ImageDraw.Draw(sheet)
    for i, (name, im) in enumerate(imgs):
        x = 16 + (i % cols) * cw
        y = 12 + (i // cols) * chh
        d.rectangle([x - 3, y - 3, x + N * z + 2, y + N * z + 2], fill="#1c1009")
        sheet.alpha_composite(im.resize((N * z, N * z), Image.NEAREST), (x, y))
        d.text((x, y + N * z + 7), name, fill="#f7eed6", font=font)
    sheet.save(os.path.join(HERE, "out", "stat_ikon32_onizleme.png"))
    strip = Image.new("RGBA", (8 * 38 + 6, 2 * 38 + 6), "#211409")
    for i, (_, im) in enumerate(imgs):
        strip.alpha_composite(im, (6 + (i % 8) * 38, 6 + (i // 8) * 38))
    strip.resize((strip.width * 2, strip.height * 2), Image.NEAREST).save(os.path.join(HERE, "out", "stat_ikon32_1x.png"))


if __name__ == "__main__":
    main()
