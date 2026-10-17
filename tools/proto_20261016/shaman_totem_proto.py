"""Shaman totemleri v4 PROTOTIPLERI - kucuk, kisa, sade ama mistik (MMORPG totemi tadinda). OYUNA BAGLI DEGIL.

Kullanici (2026-10-16): "Shamanin totemleri icin yeni totemler uretmeni istiyorum daha kucuk daha kisa ve daha sade ancak mistik
gorunumlu ilgi cekici mmorpg oyunlarinin tasarimlarina benzeyen turden totemler olacak yetenekleriyle uyumlu."

Bugunku kit: Q = Saldiri Totemi (en yakin dusmana ATES oku + mor alan hasari), E = Kalkan Totemi (cevredekilere MANA KALKANI +
alan hasari). Eski v3 (tools/shaman_totem_art.py) 48x64 kare x 1.212 dunya px = ~70 dunya birimi boy (Shaman ~33): 2 kat uzun.

v4 olcegi: 32x48 kare, 1 sanat pikseli = Shaman'in pikseli (0.903 dunya birimi; DEFS[12] scale 2.2368 x 0.8075 x 0.5). Totem
toplam boyu ~30-36 px = Shaman boyu civari. 4 yon (her biri Q ates + E kalkan cifti):
  A Oyma Kutuk   - WoW klasigi: kisa oyma direk, tek yuz, yanlarda kanat oymasi; Q tepede tas kasede alev, E ustte suzulen kalkan arması
  B Run Tasi     - yosunlu kucuk dikili tas, onunde parlayan TEK run; Q tasin oyugunda yanan alev, E ustunde suzulen ruh isigi
  C Boynuzlu     - Shaman'in geyik boynuzu motifi: kisa direk + boynuzlar, aralarinda suzulen Q ates ruhu / E mavi ruh kuresi, muskalar
  D Suzulen Taslar - uc yassi tas ust uste (cairn), aralarindan element isigi sizar, ust tas suzulur; Q turuncu / E mavi ruh alevi
Ciktilar: tools/proto_20261016/totem/ (.gdignore - Godot ice aktarmaz).
Calistir: python tools/proto_20261016/shaman_totem_proto.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont

W, H = 32, 48
FRAMES = 6
GROUND_Y = 45  # ayak zemini (dunya konumu = totemin koku)
OUTLINE = (20, 12, 12, 255)

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(HERE, "totem")


def rgba(r, g, b, a=255):
    return (int(r), int(g), int(b), int(a))


def mix(c1, c2, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(round(c1[i] + (c2[i] - c1[i]) * t)) for i in range(4))


# ------------------------------------------------------------------ paletler (v3 ile ayni aile + Shaman'in kendi renkleri)
WOOD = (rgba(44, 26, 20), rgba(84, 52, 32), rgba(124, 82, 48), rgba(164, 116, 68), rgba(196, 150, 96))
RWOOD = (rgba(48, 20, 16), rgba(92, 40, 28), rgba(134, 64, 40), rgba(172, 98, 60), rgba(204, 134, 86))
GWOOD = (rgba(38, 34, 40), rgba(70, 64, 70), rgba(104, 96, 98), rgba(140, 132, 128), rgba(176, 168, 158))
STONE = (rgba(40, 40, 50), rgba(70, 72, 84), rgba(104, 106, 116), rgba(140, 142, 148), rgba(176, 176, 178))
ANTLER = (rgba(52, 30, 14), rgba(96, 60, 30), rgba(140, 96, 56), rgba(186, 146, 96), rgba(222, 196, 150))
EARTH = (rgba(52, 36, 26), rgba(82, 58, 38), rgba(112, 82, 54))
MOSS_D, MOSS, MOSS_L = rgba(46, 84, 42), rgba(78, 124, 56), rgba(122, 164, 76)
LEATHER_D, LEATHER, LEATHER_L = rgba(62, 34, 20), rgba(110, 66, 38), rgba(150, 98, 60)
FEATHER, FEATHER_D = rgba(236, 228, 208), rgba(176, 164, 146)
CLAY = (rgba(60, 30, 22), rgba(110, 56, 36), rgba(156, 86, 54), rgba(196, 124, 80))
BEAD_R, BEAD_T = rgba(196, 64, 44), rgba(64, 168, 156)

F0, F1, F2, F3, F4 = rgba(92, 20, 12), rgba(184, 52, 22), rgba(238, 118, 36), rgba(252, 186, 70), rgba(255, 238, 176)
B0, B1, B2, B3, B4 = rgba(20, 44, 96), rgba(44, 98, 184), rgba(86, 156, 236), rgba(164, 214, 255), rgba(236, 248, 255)
ELEM = {"q": (F0, F1, F2, F3, F4), "e": (B0, B1, B2, B3, B4)}


# ------------------------------------------------------------------ cizim tuvali
class Cv:
    """Uc katman: halo (govdenin arkasinda yari saydam isik), govde (sonradan koyu kontur alir), isik (konturusuz, ustte)."""

    def __init__(self):
        self.body = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        self.lit = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        self.halo_pts = []  # (x, y, renk, guc)

    # -- govde
    def px(self, x, y, c, layer=None):
        im = layer or self.body
        x, y = int(math.floor(x + 0.5)), int(math.floor(y + 0.5))  # round() bankaci yuvarlamasi .5'lerde bosluk birakir
        if 0 <= x < W and 0 <= y < H:
            im.putpixel((x, y), c)

    def hl(self, x0, x1, y, c, layer=None):
        for x in range(int(x0), int(x1) + 1):
            self.px(x, y, c, layer)

    def vl(self, x, y0, y1, c, layer=None):
        for y in range(int(y0), int(y1) + 1):
            self.px(x, y, c, layer)

    def get(self, x, y):
        if 0 <= x < W and 0 <= y < H:
            return self.body.getpixel((x, y))
        return (0, 0, 0, 0)

    def line(self, x0, y0, x1, y1, c, layer=None, thick=1):
        n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
        for i in range(n + 1):
            t = i / n
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            for k in range(thick):
                self.px(x + k, y, c, layer)

    # -- isik
    def glow(self, x, y, c, halo=1.0):
        """Kendinden isikli piksel (konturusuz) + cevresine halo."""
        self.px(x, y, c, self.lit)
        if halo > 0:
            self.halo_pts.append((int(math.floor(x + 0.5)), int(math.floor(y + 0.5)), c, halo))

    def glint(self, x, y, c, a=255):
        self.px(x, y, (c[0], c[1], c[2], a), self.lit)

    def render(self, outline_col=OUTLINE):
        out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        # halo: isikli piksellerin 1-2 px cevresi, govdenin ARKASINDA
        halo = {}
        for (x, y, c, k) in self.halo_pts:
            for dy in range(-2, 3):
                for dx in range(-2, 3):
                    d = abs(dx) + abs(dy)
                    if d == 0 or d > 2:
                        continue
                    a = (90 if d == 1 else 38) * k
                    key = (x + dx, y + dy)
                    if key not in halo or halo[key][3] < a:
                        halo[key] = (c[0], c[1], c[2], int(min(255, a)))
        for (x, y), c in halo.items():
            if 0 <= x < W and 0 <= y < H:
                out.putpixel((x, y), c)
        body = _outline(self.body, outline_col)
        out.alpha_composite(body)
        out.alpha_composite(self.lit)
        return out


def _outline(layer, col):
    px = layer.load()
    out = layer.copy()
    op = out.load()
    for y in range(H):
        for x in range(W):
            if px[x, y][3] > 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < H and px[nx, ny][3] > 0:
                    op[x, y] = col
                    break
    return out


def shade(pal, u):
    """Silindir golgesi, isik sol ustten: u=0 sol kenar .. 1 sag kenar."""
    if u < 0.15:
        return pal[3]
    if u < 0.5:
        return pal[2]
    if u < 0.82:
        return pal[1]
    return pal[0]


def post(cv, x0, x1, y0, y1, pal, grain=True):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            cv.px(x, y, shade(pal, (x - x0) / max(1, x1 - x0)))
    if grain:
        for (gx, gy, ln) in ((x0 + 2, y0 + 2, 3), (x1 - 2, y0 + 6, 3), (x0 + 3, y1 - 4, 2)):
            if x0 < gx < x1 and gy + ln <= y1:
                cv.vl(gx, gy, gy + ln - 1, pal[1] if gx < (x0 + x1) / 2 else pal[0])


def mound(cv, t, kind="moss", x0=8, x1=23):
    """Kucuk toprak tumsegi (oyuncu golgesi oyunda ayrica cizilir) + tutam/cakil."""
    cx = (x0 + x1) / 2
    hw = (x1 - x0) / 2
    for y in range(GROUND_Y - 1, GROUND_Y + 2):
        k = {GROUND_Y - 1: 0.72, GROUND_Y: 1.0, GROUND_Y + 1: 0.86}[y]
        a, b = cx - hw * k, cx + hw * k
        for x in range(int(round(a)), int(round(b)) + 1):
            cv.px(x, y, EARTH[1] if y < GROUND_Y + 1 else EARTH[0])
    cv.hl(int(cx - hw * 0.5), int(cx + hw * 0.2), GROUND_Y - 1, EARTH[2])
    if kind == "moss":
        sway = 1 if math.sin(2 * math.pi * t) > 0.3 else 0
        for gx in (x0 + 1, x1 - 2):
            cv.px(gx, GROUND_Y - 1, MOSS)
            cv.px(gx + sway, GROUND_Y - 2, MOSS_L)
            cv.px(gx + 1, GROUND_Y - 1, MOSS_D)
    elif kind == "ash":
        cv.hl(int(cx - 3), int(cx + 2), GROUND_Y, rgba(70, 62, 60))
        cv.px(int(cx - 1), GROUND_Y, rgba(110, 100, 94))


# ------------------------------------------------------------------ ortak element parcalari
def flame(cv, cx, base_y, h, w, t, pal=ELEM["q"], halo=1.0):
    """Damla alev: tabanda genis sicak cekirdek, tepeye dogru incelir, kare kare titrer (6 karede dongu)."""
    ph = 2 * math.pi * t
    hh = h + (1 if math.sin(ph * 2) > 0.5 else 0) - (1 if math.sin(ph * 2) < -0.6 else 0)
    for r in range(hh):
        v = r / max(1, hh - 1)  # 0 taban .. 1 uc
        prof = math.sin(math.pi * min(1.0, 0.18 + v * 0.95)) ** 0.75
        half = max(0.0, (w / 2) * prof * (1.0 - v * 0.55))
        sway = math.sin(ph + v * 2.4) * v * 1.3
        y = base_y - r
        xl, xr = cx - half + sway, cx + half + sway
        for x in range(int(math.floor(xl + 0.5)), int(math.floor(xr - 0.5)) + 1):
            d = abs(x + 0.5 - (cx + sway)) / max(0.6, half)
            if v < 0.35 and d < 0.45:
                c = pal[4]
            elif v < 0.6 and d < 0.6:
                c = pal[3]
            elif d < 0.85 and v < 0.85:
                c = pal[2]
            else:
                c = pal[1]
            cv.glow(x, y, c, halo if (v < 0.7) else halo * 0.6)
    # kopup ucan kivilcim
    k = int(t * FRAMES) % 3
    if k == 0:
        cv.glow(cx + 1, base_y - hh - 1, pal[3], 0.4)
    elif k == 1:
        cv.glow(cx - 1, base_y - hh - 2, pal[2], 0.3)


def motes(cv, t, pal, spots, rise=6):
    """Yukselen tek piksel isiklar (kor / ruh tanesi); spots = (x, y_alt, faz)."""
    for (x, y, ph) in spots:
        u = (t + ph) % 1.0
        yy = y - u * rise
        a = int(255 * (1.0 - u) ** 0.7)
        if a > 40:
            cv.glint(x + (1 if (u > 0.5 and ph > 0.3) else 0), yy, pal[3] if u < 0.5 else pal[2], a)


def glyph(cv, ox, oy, rows, col, col_hi=None, halo=0.7):
    """Run deseni: rows = 'X' / '.' satirlari; col_hi verilirse ust satirlar daha parlak."""
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch == "X":
                c = col_hi if (col_hi and j < len(rows) // 2) else col
                cv.glow(ox + i, oy + j, c, halo)


RUNE_FIRE = [  # alev damlasi
    "..X..",
    ".XX..",
    ".X.X.",
    "X..X.",
    "X.X.X",
    "X...X",
    ".XXX.",
]
RUNE_WARD = [  # Algiz (koruma runu)
    "X.X.X",
    "X.X.X",
    ".XXX.",
    "..X..",
    "..X..",
    "..X..",
]


def spirit_orb(cv, cx, cy, pal):
    """Yildizli ruh kuresi (r 3.2): beyaz cekirdek, kenarda halo."""
    for dy in range(-3, 4):
        for dx in range(-3, 4):
            d = math.hypot(dx, dy)
            if d <= 3.2:
                c = pal[4] if d < 1.2 else (pal[3] if d < 2.2 else pal[2])
                cv.glow(cx + dx, cy + dy, c, 0.9 if d > 2.2 else 0.0)


def pulse(t, lo=0.0, hi=1.0):
    return lo + (hi - lo) * (0.5 + 0.5 * math.sin(2 * math.pi * t))


def bright(pal, t):
    """Nabiz: dongunun parlak yarisinda bir kademe acik renk."""
    return (pal[4], pal[3]) if pulse(t) > 0.55 else (pal[3], pal[2])


# ------------------------------------------------------------------ A) OYMA KUTUK (WoW klasigi)
def totem_a(kind, f):
    t = f / FRAMES
    cv = Cv()
    pal = RWOOD if kind == "q" else GWOOD
    ep = ELEM[kind]
    mound(cv, t, "ash" if kind == "q" else "moss", 9, 22)
    # direk + kok
    post(cv, 12, 19, 32, GROUND_Y - 1, pal)
    cv.hl(11, 20, GROUND_Y - 1, pal[1])
    cv.px(11, GROUND_Y - 2, pal[2])
    cv.px(20, GROUND_Y - 2, pal[0])
    # bas blogu (yuvarlak koseli)
    for y in range(21, 32):
        x0, x1 = (11, 20) if y in (21, 31) else (10, 21)
        for x in range(x0, x1 + 1):
            cv.px(x, y, shade(pal, (x - 10) / 11))
    # kanat oymalari (yukari-disari kalkik)
    for (y, xa, xb) in ((22, 6, 9), (23, 5, 9), (24, 6, 9), (25, 7, 9), (26, 8, 9)):
        cv.hl(xa, xb, y, pal[3] if y < 24 else pal[2])
        cv.hl(31 - xb, 31 - xa, y, pal[1] if y < 24 else pal[0])
    cv.px(5, 23, ep[2])
    cv.px(6, 22, ep[2])
    cv.px(26, 23, ep[1])
    cv.px(25, 22, ep[1])
    # yuz: kas cizgisi, oyma goz yuvalari (icinde element isigi), burun, agiz
    cv.hl(11, 20, 23, pal[0])
    cv.hl(12, 14, 24, pal[0])
    cv.hl(17, 19, 24, pal[0])
    cv.vl(15, 25, 27, pal[3])
    cv.vl(16, 25, 27, pal[1])
    cv.hl(13, 18, 29, pal[0])
    cv.px(12, 28, pal[0])
    cv.px(19, 28, pal[0])
    cv.hl(14, 17, 30, pal[3])
    eh, el = bright(ep, t)
    cv.glow(13, 24, eh, 0.6)
    cv.glow(18, 24, eh, 0.6)
    # deri kayis + sarkan tuy
    cv.hl(12, 19, 34, LEATHER)
    cv.hl(12, 19, 35, LEATHER_D)
    cv.px(13, 34, LEATHER_L)
    sw = 1 if math.sin(2 * math.pi * t) > 0.4 else 0
    cv.vl(19, 36, 37, LEATHER_D)
    cv.px(20, 38, BEAD_R if kind == "q" else BEAD_T)
    cv.vl(20 + sw, 39, 42, FEATHER)
    cv.vl(21 + sw, 40, 41, FEATHER_D)
    cv.px(20 + sw, 42, ep[2])
    # boya: element rengi cift cizgi
    for y in (38, 40):
        cv.hl(13, 17, y, ep[1] if kind == "e" else ep[1])
        cv.px(14, y, ep[2])
    if kind == "q":
        # tas kase + alev (ates oku alevin merkezinden cikar)
        cv.hl(10, 21, 20, STONE[2])
        cv.hl(10, 21, 19, STONE[3])
        cv.hl(11, 20, 18, STONE[1])
        cv.px(10, 19, STONE[4])
        cv.hl(12, 19, 18, F1)
        flame(cv, 15.5, 17, 11, 9, t)
        motes(cv, t, ep, [(9, 18, 0.0), (22, 16, 0.5), (12, 12, 0.3)], 7)
    else:
        # suzulen kalkan armasi (heater) + ic run
        bob = round(math.sin(2 * math.pi * t) * 1.2)
        top = 8 + bob
        rows = (3, 5, 5, 5, 5, 5, 4, 4, 3, 2, 1)
        for j, hw in enumerate(rows):
            y = top + j
            for x in range(16 - hw, 16 + hw):
                edge = (x == 16 - hw or x == 15 + hw or j == 0 or j == len(rows) - 1 or (j == 1 and hw > rows[0]
                        and (x < 16 - rows[0] or x >= 16 + rows[0])))
                cv.glow(x, y, (ep[3] if x < 16 else ep[2]) if edge else (ep[1] if x < 16 else ep[0]), 0.5)
        hi, lo = bright(ep, t)
        glyph(cv, 13, top + 2, ["X.XX.X", "X.XX.X", ".XXXX.", "..XX..", "..XX..", "..XX.."], hi, None, 0.0)
        motes(cv, t, ep, [(9, 20, 0.1), (22, 18, 0.6), (11, 14, 0.4)], 6)
        # kasede ruh isigi dusmesi: bas tepesinde mavi aydinlik
        cv.hl(12, 19, 21, mix(pal[3], ep[3], 0.5))
    return cv.render()


# ------------------------------------------------------------------ B) RUN TASI (dikili tas)
def totem_b(kind, f):
    t = f / FRAMES
    cv = Cv()
    ep = ELEM[kind]
    mound(cv, t, "moss", 8, 23)
    # tas: yuvarlak tepe, hafif egik, tabanda genis
    top = 23 if kind == "q" else 22
    for y in range(top, GROUND_Y):
        v = (y - top) / (GROUND_Y - top)
        hw = 5.0 + v * 1.6
        if y - top < 3:
            hw -= (3 - (y - top)) * 1.1
        lean = -0.6 * (1 - v)
        x0, x1 = int(round(15.5 - hw + lean)), int(round(15.5 + hw + lean)) - 1
        for x in range(x0, x1 + 1):
            u = (x - x0) / max(1, x1 - x0)
            c = shade(STONE, u)
            if y - top < 2 and u < 0.6:
                c = STONE[3]
            cv.px(x, y, c)
    # catlak + yosun
    cv.px(19, top + 6, STONE[0])
    cv.px(20, top + 7, STONE[0])
    cv.px(19, top + 8, STONE[1])
    for (x, y) in ((10, 42), (11, 42), (10, 41), (12, 43), (19, 43), (20, 42), (11, top + 3), (12, top + 2)):
        cv.px(x, y, MOSS)
    cv.px(10, 41, MOSS_L)
    cv.px(12, top + 2, MOSS_L)
    # oyma cerceve + parlayan run (nabiz)
    hi, lo = bright(ep, t)
    gy = top + 7
    for y in range(gy - 1, gy + 8):
        cv.px(12, y, STONE[1])
    if kind == "q":
        glyph(cv, 13, gy, RUNE_FIRE, lo, hi, 0.8)
        # tasin tepesindeki oyukta yanan alev
        cv.hl(12, 18, top, STONE[1])
        cv.hl(13, 17, top, F1)
        flame(cv, 15.5, top - 1, 9, 7, t)
        motes(cv, t, ep, [(9, 30, 0.0), (22, 28, 0.45), (21, 38, 0.75)], 7)
    else:
        glyph(cv, 13, gy + 1, RUNE_WARD, lo, hi, 0.8)
        # tasin ustunde suzulen ruh isigi (kalkan oz)
        bob = round(math.sin(2 * math.pi * t) * 1.2)
        cy = top - 7 + bob
        spirit_orb(cv, 15, cy, ep)
        # kucuk ruh halkasi (ince, kirik)
        rr = 5
        for i in range(16):
            a = 2 * math.pi * (i / 16 + t * 0.25)
            if i % 4 == 0:
                continue
            x = 15 + math.cos(a) * rr
            y = cy + math.sin(a) * rr * 0.45
            cv.glint(x, y, ep[3], 150 if math.sin(a) > 0 else 90)
        motes(cv, t, ep, [(9, 30, 0.2), (22, 28, 0.65), (20, 40, 0.9)], 6)
    return cv.render()


# ------------------------------------------------------------------ C) BOYNUZLU RUH DIREGI (Shaman'in geyik boynuzu motifi)
ANTLER_L = [  # sol boynuz maskesi (x 3..13, y 13..26), 1 px dal; kontur sonradan kalinlastirir. 'T' = acik uc
    # 345678901 23
    "T..T.......",  # y13
    "X..X.......",  # y14
    "X..X...T...",  # y15
    ".X.X...X...",  # y16
    ".XX....X...",  # y17
    "..X...X....",  # y18
    "..X..X.....",  # y19
    "...XX......",  # y20
    "....X......",  # y21
    ".....X.....",  # y22
    "......X....",  # y23
    ".......XX..",  # y24
    ".........XX",  # y25
]


def antler(cv, side, oy=13):
    for j, row in enumerate(ANTLER_L):
        for i, ch in enumerate(row):
            if ch == ".":
                continue
            x = 3 + i
            if side > 0:
                x = 31 - x
            c = ANTLER[4] if ch == "T" else (ANTLER[3] if j < 6 else ANTLER[2])
            if side > 0 and ch != "T":
                c = ANTLER[2] if j < 6 else ANTLER[1]
            cv.px(x, oy + j, c)


def totem_c(kind, f):
    t = f / FRAMES
    cv = Cv()
    ep = ELEM[kind]
    mound(cv, t, "moss", 9, 22)
    post(cv, 13, 18, 33, GROUND_Y - 1, WOOD)
    cv.hl(12, 19, GROUND_Y - 1, WOOD[1])
    # bas: kucuk oyma kafa (gozler element isigi)
    for y in range(26, 33):
        x0, x1 = (13, 18) if y in (26, 32) else (12, 19)
        for x in range(x0, x1 + 1):
            cv.px(x, y, shade(WOOD, (x - 12) / 7))
    cv.hl(12, 19, 27, WOOD[0])
    eh, el = bright(ep, t)
    cv.glow(13, 28, eh, 0.5)
    cv.glow(18, 28, eh, 0.5)
    cv.vl(15, 28, 29, WOOD[3])
    cv.hl(14, 17, 31, WOOD[0])
    # boynuzlar (Shaman'in kendi boynuzu gibi)
    antler(cv, -1, 13)
    antler(cv, 1, 13)
    # sarmasik yapraklari
    for (x, y, c) in ((13, 35, MOSS), (14, 36, MOSS_D), (16, 37, MOSS), (17, 38, MOSS_D), (15, 40, MOSS), (14, 41, MOSS_D)):
        cv.px(x, y, c)
    cv.px(12, 35, MOSS_L)
    cv.px(18, 37, MOSS_L)
    cv.px(13, 41, MOSS_L)
    # bastan sarkan tek muska
    sw = 1 if math.sin(2 * math.pi * t) > 0.4 else 0
    cv.vl(20, 29, 30, LEATHER_D)
    cv.px(20, 31, BEAD_R if kind == "q" else BEAD_T)
    cv.vl(20 + sw, 32, 34, FEATHER)
    cv.px(21 + sw, 33, FEATHER_D)
    cv.px(20 + sw, 35, ep[2])
    # boynuzlar arasinda suzulen element
    bob = round(math.sin(2 * math.pi * t) * 1.0)
    cy = 18 + bob
    if kind == "q":
        flame(cv, 15.5, cy + 5, 10, 7, t)
        motes(cv, t, ep, [(11, 22, 0.15), (20, 21, 0.6)], 6)
    else:
        spirit_orb(cv, 15, cy, ep)
        motes(cv, t, ep, [(11, 22, 0.15), (20, 21, 0.6)], 6)
    return cv.render()


# ------------------------------------------------------------------ D) SUZULEN TAS YIGINI (cairn: uc yassi tas, aralarinda isik)
def _flat_stone(cv, cx, y0, rows, moss=()):
    """Yassi dogal tas: rows = (sol_yari, sag_yari, x_kayma) satirlari - asimetrik, hafif egik."""
    n = len(rows)
    for j, (hl, hr, dx) in enumerate(rows):
        y = y0 + j
        x0, x1 = int(math.floor(cx - hl + dx + 0.5)), int(math.floor(cx + hr + dx + 0.5)) - 1
        for x in range(x0, x1 + 1):
            u = (x - x0) / max(1, x1 - x0)
            c = shade(STONE, u)
            if j == 0 or (j == 1 and u < 0.7):
                c = STONE[3] if u < 0.75 else STONE[2]
            if j == n - 1:
                c = STONE[1] if u < 0.6 else STONE[0]
            cv.px(x, y, c)
    for (x, y) in moss:
        cv.px(x, y, MOSS)


def _gap_glow(cv, cx, y, hw, c, halo=0.5):
    for x in range(int(round(cx - hw)), int(round(cx + hw))):
        cv.glow(x, y, c, halo)


def totem_d(kind, f):
    t = f / FRAMES
    cv = Cv()
    ep = ELEM[kind]
    mound(cv, t, "moss", 8, 23)
    hi, lo = bright(ep, t)
    bob = round(math.sin(2 * math.pi * t) * 1.0)
    # taban tasi (yere oturur, genis + yassi)
    _flat_stone(cv, 15.5, 39, ((4.0, 5.0, 0), (6.0, 6.5, 0), (6.5, 7.0, 0), (6.5, 7.0, 0), (6.0, 6.5, 0), (5.5, 6.0, 0)),
                ((10, 43), (11, 44), (9, 43), (21, 42), (22, 43)))
    # orta tas saga kaymis + egik; altindaki 1 px bosluktan isik sizar
    _gap_glow(cv, 16.0, 38, 4.0, lo, 0.6)
    _flat_stone(cv, 16.5, 33, ((2.5, 3.5, 0.5), (4.5, 5.0, 0), (5.0, 5.0, 0), (5.0, 4.5, -0.5), (4.0, 3.5, -0.5)),
                ((12, 35),))
    # ust tas sola kaymis, kucuk, suzulur (2-3 px bosluk, nabizli isik)
    top = 26 + bob
    for y in range(top + 5, 33):
        _gap_glow(cv, 15.0, y, 2.0 if y < 32 else 3.0, lo if y == 32 else hi, 0.35)
    _flat_stone(cv, 15.0, top, ((2.0, 2.5, 0.5), (3.5, 3.5, 0), (4.0, 3.5, 0), (3.5, 3.0, 0), (2.5, 2.0, 0)))
    # orta tasta iki isik noktasi (kucuk run izi)
    cv.glow(14, 35, hi, 0.4)
    cv.glow(19, 35, hi, 0.4)
    # tepe: Q turuncu alev, E mavi ruh alevi
    flame(cv, 15.0, top - 1, 9, 6, t, ep)
    motes(cv, t, ep, [(10, 31, 0.0), (21, 30, 0.5), (19, 39, 0.8)], 7)
    return cv.render()


DIRECTIONS = [
    ("A", "Oyma Kutuk", totem_a),
    ("B", "Run Tasi", totem_b),
    ("C", "Boynuzlu Direk", totem_c),
    ("D", "Suzulen Taslar", totem_d),
]


# ------------------------------------------------------------------ cikti
def grass_bg(w, h, seed=7):
    im = Image.new("RGBA", (w, h), rgba(122, 173, 85))
    px = im.load()
    s = seed
    for y in range(h):
        for x in range(w):
            s = (s * 1103515245 + 12345) & 0x7FFFFFFF
            r = s % 100
            if r < 7:
                px[x, y] = rgba(91, 146, 82)
            elif r < 9:
                px[x, y] = rgba(150, 197, 95)
    return im


def font(sz):
    try:
        return ImageFont.truetype("arial.ttf", sz)
    except Exception:
        return ImageFont.load_default()


def old_frames():
    """Eski v3 totemleri, yeni olcekte (1.212 / 0.903 = x1.342 NEAREST) - boy kiyasi."""
    res = {}
    for k, name in (("q", "attack"), ("e", "shield")):
        im = Image.open(os.path.join(ROOT, "assets", "shaman", "totem_%s_idle.png" % name)).convert("RGBA").crop((0, 0, 48, 64))
        s = 1.212 / 0.903
        res[k] = im.resize((round(48 * s), round(64 * s)), Image.NEAREST)
    return res


def shaman_frame():
    im = Image.open(os.path.join(ROOT, "assets", "characters", "shaman", "sheets", "idle.png")).convert("RGBA")
    return im.crop((0, 0, 48, 48))


def main():
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, ".gdignore"), "w") as fh:
        fh.write("")
    sheets = {}
    for (key, name, fn) in DIRECTIONS:
        for kind in ("q", "e"):
            frames = [fn(kind, f) for f in range(FRAMES)]
            sheet = Image.new("RGBA", (W * FRAMES, H), (0, 0, 0, 0))
            for i, fr in enumerate(frames):
                sheet.paste(fr, (i * W, 0), fr)
            sheet.save(os.path.join(OUT, "totem_%s_%s.png" % (key, kind)))
            sheets[(key, kind)] = frames

    # 1) sayfa: x5, her yon icin Q ve E, 2 kare + eski kiyas
    Z = 5
    cw, ch = W * Z, H * Z
    pad = 18
    lab = 40
    cols = 4  # Q f0, Q f3, E f0, E f3
    rows = len(DIRECTIONS)
    sw = pad + cols * (cw + pad)
    sh = lab + rows * (ch + lab) + pad
    page = Image.new("RGBA", (sw, sh), rgba(34, 40, 30))
    d = ImageDraw.Draw(page)
    fnt = font(22)
    for r, (key, name, fn) in enumerate(DIRECTIONS):
        y = lab + r * (ch + lab)
        d.text((pad, y - 30), "%s - %s   (Q Saldiri | E Kalkan)" % (key, name), fill=(236, 226, 200), font=fnt)
        for c, (kind, fi) in enumerate((("q", 0), ("q", 3), ("e", 0), ("e", 3))):
            x = pad + c * (cw + pad)
            bg = grass_bg(W, H, seed=r * 7 + c).resize((cw, ch), Image.NEAREST)
            page.paste(bg, (x, y))
            fr = sheets[(key, kind)][fi].resize((cw, ch), Image.NEAREST)
            page.alpha_composite(fr, (x, y))
    page.save(os.path.join(OUT, "totem_sayfa.png"))

    # 2) oyun olcegi: kamera x2, 1 sanat px = Shaman pikseli; eski totemler ayni olcekte
    S = 2
    old = old_frames()
    sham = shaman_frame()
    items = [("Shaman", sham, 0), ("eski Q", old["q"], 0), ("eski E", old["e"], 0)]
    for (key, name, fn) in DIRECTIONS:
        items.append((key + " Q", sheets[(key, "q")][0], 0))
        items.append((key + " E", sheets[(key, "e")][0], 0))
    gap = 6
    tot_w = sum(im.width for _, im, _ in items) + gap * (len(items) + 1)
    base = 92  # ayak cizgisi (sanat px)
    scene = grass_bg(tot_w, base + 12, seed=3)
    x = gap
    labels = []
    for (nm, im, _) in items:
        if nm == "Shaman":
            fy = base - 41  # idle karesinde ayak y~41
        elif nm.startswith("eski"):
            fy = base - im.height + round(2 * 1.342)
        else:
            fy = base - GROUND_Y
        scene.alpha_composite(im, (x, fy))
        labels.append((nm, x + im.width // 2))
        x += im.width + gap
    big = scene.resize((scene.width * S, scene.height * S), Image.NEAREST)
    canvas = Image.new("RGBA", (big.width, big.height + 34), rgba(34, 40, 30))
    canvas.paste(big, (0, 0))
    d = ImageDraw.Draw(canvas)
    f2 = font(15)
    for (nm, cx) in labels:
        tw = d.textlength(nm, font=f2)
        d.text((cx * S - tw / 2, big.height + 8), nm, fill=(236, 226, 200), font=f2)
    canvas.save(os.path.join(OUT, "totem_oyun.png"))

    # 3) animasyon GIF: 8 totem x4, 7 fps (sahnedeki hiz)
    Z = 4
    n = len(DIRECTIONS) * 2
    gw = n * (W * Z + 8) + 8
    gh = H * Z + 16
    gif = []
    for f in range(FRAMES):
        fr = grass_bg(gw // Z + 1, gh // Z + 1, seed=11).resize(((gw // Z + 1) * Z, (gh // Z + 1) * Z), Image.NEAREST).crop((0, 0, gw, gh))
        x = 8
        for (key, name, fn) in DIRECTIONS:
            for kind in ("q", "e"):
                im = sheets[(key, kind)][f].resize((W * Z, H * Z), Image.NEAREST)
                fr.alpha_composite(im, (x, 8))
                x += W * Z + 8
        gif.append(fr.convert("RGB"))
    gif[0].save(os.path.join(OUT, "totem_anim.gif"), save_all=True, append_images=gif[1:], duration=int(1000 / 7), loop=0)
    print("ok ->", OUT)


if __name__ == "__main__":
    main()
