"""Shaman totemleri v4 PROTOTIPLERI - 2. tur: GOSTERISLI SIHIRLI totemler (kucuk). OYUNA BAGLI DEGIL.

1. tur (shaman_totem_proto.py) icin kullanici: "bunlar cok sade ve gosterissiz. tasarim olarak illa shamana benzemelerine gerek
yok sihirli totemler gibi olmalilar." -> boy yine kucuk (Shaman'dan biraz uzun, eski v3'un ~yarisi) ama:
parlayan run/goz/catlaklar, suzulen element cekirdekleri, sarmal enerji kuyruklari, kivilcim/yildiz pariltilari, altin suslemeler.
Kacinilanlar (v2 "teknolojik" dersi): faset kristal, yorungede donen parcalar, zemin run halkasi, dama halo.

Q = Saldiri Totemi (ATES), E = Kalkan Totemi (mavi RUH/kalkan). Kare 40x56, 1 sanat px = Shaman pikseli (0.903 dunya birimi),
ayak satiri y=52, 8 kare dongu (10 fps). Yonler:
  A Element Catali  - obsidyen sutun + altin bilezik, iki boynuz-catal arasinda suzulen element cekirdegi, yukari akan run sutunu
  B Ruh Maskesi     - iri oyma maske, parlayan gozler; Q alev tacli + disli agiz, E isik tuyu tacli + isik gozyasi
  C Suzulen Runlar  - kaya kaide + ust uste suzulen 3 runlu obsidyen parca, aralarindan yukari akan enerji sutunu
  D Gok Kusu        - kisa direk + oyma kus, KALKIK kanatlari element isigindan yelpaze tuyler (Q anka), gogsunde tas
Ciktilar: tools/proto_20261016/totem2/ (.gdignore). Calistir: python tools/proto_20261016/shaman_totem_proto2.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont

W, H = 40, 56
CX = 19  # simetri ekseni (tek genislikler x .. 38-x)
GY = 52  # ayak satiri
FRAMES = 8
FPS = 10
OUTLINE = (18, 12, 16, 255)

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(HERE, "totem2")
TAU = 2 * math.pi


def rgba(r, g, b, a=255):
    return (int(r), int(g), int(b), int(a))


def mix(c1, c2, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(round(c1[i] + (c2[i] - c1[i]) * t)) for i in range(4))


def M(x):
    """x'in eksene gore aynasi."""
    return 2 * CX - x


# ------------------------------------------------------------------ paletler
OBS = (rgba(22, 18, 30), rgba(40, 34, 54), rgba(62, 54, 80), rgba(92, 82, 112), rgba(128, 118, 150))
GOLD = (rgba(84, 52, 16), rgba(146, 100, 34), rgba(204, 158, 62), rgba(244, 212, 122), rgba(255, 244, 196))
WOOD = (rgba(46, 24, 16), rgba(90, 50, 30), rgba(134, 82, 46), rgba(176, 122, 70), rgba(212, 166, 108))
RWOOD = (rgba(46, 16, 14), rgba(88, 32, 26), rgba(130, 52, 36), rgba(170, 82, 52), rgba(204, 120, 80))
PALE = (rgba(64, 66, 86), rgba(116, 120, 140), rgba(170, 174, 188), rgba(212, 214, 222), rgba(240, 242, 246))
STONE = (rgba(34, 32, 42), rgba(60, 58, 72), rgba(92, 90, 104), rgba(128, 126, 136), rgba(166, 164, 170))
BONE = (rgba(120, 104, 84), rgba(178, 162, 132), rgba(224, 212, 182), rgba(248, 242, 224))
EARTH = (rgba(48, 34, 24), rgba(78, 56, 36), rgba(108, 80, 52))
MOSS_D, MOSS, MOSS_L = rgba(40, 80, 40), rgba(72, 120, 54), rgba(118, 162, 72)
LEATHER_D, LEATHER = rgba(62, 34, 20), rgba(112, 68, 40)

FIRE = (rgba(96, 18, 10), rgba(190, 50, 20), rgba(240, 118, 34), rgba(252, 188, 68), rgba(255, 236, 160), rgba(255, 252, 228))
SPIRIT = (rgba(16, 40, 96), rgba(36, 96, 196), rgba(70, 164, 244), rgba(140, 220, 255), rgba(214, 246, 255), rgba(250, 255, 255))
ELEM = {"q": FIRE, "e": SPIRIT}


# ------------------------------------------------------------------ tuval: arka efekt / govde (kontur alir) / govde ustu isik / on efekt
class Cv:
    LAYERS = ("back", "body", "emis", "front")

    def __init__(self):
        self.L = {k: Image.new("RGBA", (W, H), (0, 0, 0, 0)) for k in self.LAYERS}
        self.halo = []

    @staticmethod
    def _xy(x, y):
        return int(math.floor(x + 0.5)), int(math.floor(y + 0.5))

    def px(self, x, y, c, layer="body"):
        x, y = self._xy(x, y)
        if 0 <= x < W and 0 <= y < H:
            self.L[layer].putpixel((x, y), c)

    def hl(self, x0, x1, y, c, layer="body"):
        for x in range(int(x0), int(x1) + 1):
            self.px(x, y, c, layer)

    def blend(self, x, y, c, a, layer="front"):
        x, y = self._xy(x, y)
        if not (0 <= x < W and 0 <= y < H) or a <= 0:
            return
        im = self.L[layer]
        cur = im.getpixel((x, y))
        a = min(255, int(a))
        if cur[3] == 0:
            im.putpixel((x, y), (c[0], c[1], c[2], a))
        else:
            k = a / 255.0
            im.putpixel((x, y), tuple(int(cur[i] * (1 - k) + c[i] * k) for i in range(3)) + (max(cur[3], a),))

    def glow(self, x, y, c, halo=1.0, layer="front"):
        self.px(x, y, c, layer)
        if halo > 0:
            xi, yi = self._xy(x, y)
            self.halo.append((xi, yi, c, halo))

    def render(self):
        out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        hm = {}
        for (x, y, c, k) in self.halo:
            for dy in range(-3, 4):
                for dx in range(-3, 4):
                    d = math.hypot(dx, dy)
                    if d == 0 or d > 3.2:
                        continue
                    a = (110 if d < 1.5 else (52 if d < 2.5 else 20)) * k
                    key = (x + dx, y + dy)
                    if key not in hm or hm[key][3] < a:
                        hm[key] = (c[0], c[1], c[2], int(min(200, a)))
        for (x, y), c in hm.items():
            if 0 <= x < W and 0 <= y < H:
                out.putpixel((x, y), c)
        out.alpha_composite(self.L["back"])
        out.alpha_composite(_outline(self.L["body"]))
        out.alpha_composite(self.L["emis"])
        out.alpha_composite(self.L["front"])
        return out


def _outline(layer):
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
                    op[x, y] = OUTLINE
                    break
    return out


def shade(pal, u):
    if u < 0.14:
        return pal[3]
    if u < 0.48:
        return pal[2]
    if u < 0.8:
        return pal[1]
    return pal[0]


def fill_rows(cv, rows, pal, layer="body", top_light=1):
    """rows: {y: (xl, xr)} - satir basina silindir golgesi; ust top_light satir bir ton acik."""
    ys = sorted(rows)
    for i, y in enumerate(ys):
        xl, xr = rows[y]
        for x in range(xl, xr + 1):
            u = (x - xl) / max(1, xr - xl)
            c = shade(pal, u)
            if i < top_light and u < 0.8:
                c = pal[min(4, pal.index(c) + 1)] if c in pal else c
            cv.px(x, y, c, layer)


def mound(cv, x0, x1):
    cx = (x0 + x1) / 2
    hw = (x1 - x0) / 2
    for y, k, c in ((GY, 1.0, EARTH[1]), (GY + 1, 0.86, EARTH[0])):
        cv.hl(int(round(cx - hw * k)), int(round(cx + hw * k)), y, c)


# ------------------------------------------------------------------ efekt parcalari
def wave(t, ph=0.0):
    return math.sin(TAU * (t + ph))


def flame(cv, cx, base_y, h, w, t, pal, halo=1.0, layer="front", ph=0.0):
    tt = t + ph
    hh = h + (1 if math.sin(TAU * tt * 2) > 0.45 else 0) - (1 if math.sin(TAU * tt * 2) < -0.65 else 0)
    for r in range(hh):
        v = r / max(1, hh - 1)
        prof = math.sin(math.pi * min(1.0, 0.16 + v * 0.95)) ** 0.7
        half = max(0.0, (w / 2) * prof * (1.0 - v * 0.5))
        sway = math.sin(TAU * tt + v * 2.6) * v * 1.4
        y = base_y - r
        for x in range(int(math.floor(cx - half + sway + 0.5)), int(math.floor(cx + half + sway - 0.5)) + 1):
            d = abs(x - (cx + sway)) / max(0.6, half)
            if v < 0.3 and d < 0.4:
                c = pal[5]
            elif v < 0.5 and d < 0.6:
                c = pal[4]
            elif v < 0.75 and d < 0.8:
                c = pal[3]
            elif v < 0.9:
                c = pal[2]
            else:
                c = pal[1]
            cv.glow(x, y, c, halo if v < 0.7 else halo * 0.5, layer)
    k = int((tt % 1.0) * FRAMES) % 4
    if k == 0:
        cv.glow(cx + 1, base_y - hh - 1, pal[3], 0.4, layer)
    elif k == 2:
        cv.glow(cx - 1, base_y - hh - 2, pal[2], 0.3, layer)


def orb(cv, cx, cy, r, t, pal, layer="front"):
    """Element cekirdegi: beyaz merkez -> kenar; kenari hafif dalgali; icinde donen iki parlak nokta."""
    R = int(math.ceil(r)) + 1
    for dy in range(-R, R + 1):
        for dx in range(-R, R + 1):
            a = math.atan2(dy, dx)
            rr = r * (1.0 + 0.07 * math.sin(3 * a + TAU * t))
            d = math.hypot(dx, dy) / rr
            if d > 1.0:
                continue
            c = pal[5] if d < 0.3 else (pal[4] if d < 0.55 else (pal[3] if d < 0.8 else pal[2]))
            if d > 0.8 and dy > 0:
                c = pal[1] if d > 0.9 else pal[2]
            cv.glow(cx + dx, cy + dy, c, 1.0 if d > 0.6 else 0.0, layer)
    for k in range(2):
        a = TAU * (t + k / 2)
        cv.px(cx + math.cos(a) * r * 0.55, cy + math.sin(a) * r * 0.55, pal[5], layer)


def sparkle(cv, x, y, s, pal, layer="front"):
    """4 kollu yildiz pariltisi; s = kol boyu (0 = yok)."""
    if s <= 0:
        return
    cv.glow(x, y, pal[5], 0.6, layer)
    for k in range(1, s + 1):
        c = pal[4] if k == 1 else pal[2]
        for dx, dy in ((k, 0), (-k, 0), (0, k), (0, -k)):
            cv.px(x + dx, y + dy, c, layer)


TWINKLE = (0, 1, 2, 1, 0, 0, 0, 0)


def twinkles(cv, f, pal, spots):
    for (x, y, ph) in spots:
        sparkle(cv, x, y, TWINKLE[(f + ph) % FRAMES], pal)


def particles(cv, t, pal, spots, rise, layer="front"):
    """Yukselen isik taneleri: spots = (x, y_alt, faz, savrulma)."""
    for (x, y, ph, drift) in spots:
        u = (t + ph) % 1.0
        yy = y - u * rise
        xx = x + math.sin(TAU * u + ph * 6) * drift
        a = 255 * (1.0 - u) ** 0.8
        cv.blend(xx, yy, pal[4] if u < 0.35 else pal[3], a, layer)


def wisps(cv, t, cx, yb, yt, R, pal, n=2, turns=1.0, tail=8, squash=0.32):
    """Govdenin cevresinde sarmal yukselen isik kuyruklari; arkadaki kisim govdenin arkasina cizilir."""
    for i in range(n):
        u0 = (t + i / n) % 1.0
        for k in range(tail, -1, -1):
            u = u0 - k * 0.018
            if u < 0:
                continue
            th = TAU * turns * u + i * math.pi
            x = cx + R * math.sin(th)
            y = yb - u * (yb - yt) + R * squash * math.cos(th)
            front = math.cos(th) > 0
            edge = min(1.0, u / 0.12, (1.0 - u) / 0.12)
            a = 255 * (1.0 - k / (tail + 1)) * max(0.0, edge)
            if k == 0:
                if edge > 0.5:
                    cv.glow(x, y, pal[5], 0.7, "front" if front else "back")
            else:
                cv.blend(x, y, pal[3] if k < 3 else pal[2], a, "front" if front else "back")


def glyph(cv, ox, oy, rows, col, layer="emis", halo=0.5):
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch == "X":
                cv.glow(ox + i, oy + j, col, halo, layer)


def feather(cv, x0, y0, ang, length, wmax, pal, layer="front", halo=0.6):
    """Isiktan tuy: ang derece (0 = sag, 90 = yukari); tabanda ve ucta ince, ortada genis; ucu beyaza yakin."""
    a = math.radians(ang)
    dx, dy = math.cos(a), -math.sin(a)
    nx, ny = -dy, dx
    steps = int(length * 2) + 1
    for i in range(steps + 1):
        s = i / steps
        q = (s - 0.55) / 0.55
        half = (wmax / 2) * math.sqrt(max(0.0, 1.0 - q * q)) * (0.55 + 0.45 * min(1.0, s * 3))
        px_, py_ = x0 + dx * s * length, y0 + dy * s * length
        hk = int(math.ceil(half))
        for k in range(-hk, hk + 1):
            if abs(k) > half + 0.25:
                continue
            if s > 0.86 and abs(k) < half * 0.7:
                c = pal[4]
            elif k == 0:
                c = pal[3] if s > 0.3 else pal[2]
            elif abs(k) < half * 0.6:
                c = pal[3]
            else:
                c = pal[2]
            cv.glow(px_ + nx * k, py_ + ny * k, c, halo if abs(k) >= half - 0.6 else 0.0, layer)


R3 = (["X.X", ".X.", "X.X"], ["XXX", ".X.", ".X."], [".X.", "XXX", ".X."], ["X..", "XXX", "..X"], [".X.", "X.X", ".X."])
RUNE5_FIRE = ["..X..", ".XX..", ".X.X.", "X...X", ".XXX."]
RUNE5_WARD = ["X.X.X", "X.X.X", ".XXX.", "..X..", "..X.."]


# ------------------------------------------------------------------ A) ELEMENT CATALI
def totem_a(kind, f):
    if kind == "e":
        return totem_a_e(f)  # kullanici secimi: E ayri, koruma temali tasarim
    t = f / FRAMES
    cv = Cv()
    ep = ELEM[kind]
    mound(cv, 9, 29)
    # basamakli kaide + altin kenar
    fill_rows(cv, {50: (10, 28), 51: (10, 28), 52: (10, 28)}, OBS)
    fill_rows(cv, {47: (12, 26), 48: (12, 26), 49: (12, 26)}, OBS)
    cv.hl(12, 26, 47, GOLD[2])
    cv.hl(12, 15, 47, GOLD[3])
    cv.hl(10, 28, 50, OBS[3])
    cv.px(26, 47, GOLD[1])
    # sutun + oyma oluklar
    fill_rows(cv, {y: (14, 24) for y in range(30, 47)}, OBS, top_light=0)
    for y in range(31, 46):
        cv.px(16, y, OBS[0])
        cv.px(22, y, OBS[0])
    # altin bilezik + tas
    fill_rows(cv, {27: (13, 25), 28: (13, 25), 29: (13, 25)}, GOLD)
    cv.hl(13, 25, 29, GOLD[1])
    # boynuz-catal (2 px kalin, ucta altin)
    path = [(14, 26), (13, 25), (12, 24), (11, 23), (11, 22), (10, 21), (10, 20), (10, 19), (11, 18), (11, 17), (12, 16), (13, 15)]
    for (x, y) in path:
        cv.px(x, y, OBS[3])
        cv.px(x + 1, y, OBS[2])
        cv.px(M(x), y, OBS[1])
        cv.px(M(x + 1), y, OBS[2])
    for (x, y) in ((13, 15), (14, 15), (13, 14), (14, 16)):
        cv.px(x, y, GOLD[3])
        cv.px(M(x), y, GOLD[2])
    # catalin ic kenarinda nabizli element isigi
    hi = ep[4] if wave(t) > 0.2 else ep[3]
    for (x, y) in path[2:10]:
        cv.blend(x + 2, y, hi, 170, "emis")
        cv.blend(M(x + 2), y, hi, 170, "emis")
    # bilezik tasi
    cv.glow(18, 28, ep[3], 0.6, "emis")
    cv.glow(19, 28, ep[5], 0.8, "emis")
    cv.glow(20, 28, ep[3], 0.6, "emis")
    # yukari akan run sutunu (asagidan yukari sirayla parlar)
    for k, (y0, rn) in enumerate(((42, R3[0]), (37, R3[2]), (32, R3[1]))):
        lit = (f - k * 2) % FRAMES < 3
        glyph(cv, 18, y0, rn, ep[4] if lit else ep[2], "emis", 0.7 if lit else 0.25)
    if kind == "q":
        # lav catlaklari
        for (x, y) in ((15, 35), (15, 36), (14, 37), (23, 40), (24, 41), (23, 42)):
            cv.glow(x, y, FIRE[2] if wave(t, 0.3) > 0 else FIRE[3], 0.3, "emis")
    # suzulen cekirdek
    cy = 20 + (1 if wave(t) > 0.5 else (-1 if wave(t) < -0.5 else 0))
    if kind == "q":
        orb(cv, 19, cy, 3.6, t, ep)
        flame(cv, 19, cy - 2, 9, 6, t, ep)
        particles(cv, t, ep, [(16, cy, 0.0, 1.0), (22, cy, 0.5, 1.0), (19, cy - 6, 0.25, 1.5)], 10)
    else:
        orb(cv, 19, cy, 4.2, t, ep)
        # catal uclarindan cekirdege kivilcim yayi (bazi karelerde)
        if f % 4 == 1:
            for (x, y) in ((15, 16), (16, 17), (15, 18), (16, 19)):
                cv.glow(x, y, ep[4], 0.4)
        if f % 4 == 3:
            for (x, y) in ((23, 16), (22, 17), (23, 18), (22, 19)):
                cv.glow(x, y, ep[4], 0.4)
        twinkles(cv, f, ep, [(19, 12, 0), (12, 11, 3), (27, 13, 5)])
    wisps(cv, t, 19, 46, 29, 8, ep)
    return cv.render()


# ------------------------------------------------------------------ A-E) KORUYUCU KANAT (Kalkan Totemi; kullanici 2026-10-16: "A olsun ama mavi
# olanin yuvarlak kuresi kalkan seklinde olsun, totem biraz daha farkli gorunsun diger(Q)in kopyasi gibi duruyor, koruma temali birsey olsun")
# Q'dan ayrisma: koyu obsidyen yerine ACIK MERMER + altin, dar sutun yerine mazgalli KALE kaidesi + genis kule govde, boynuz halkasi yerine
# kalkani saran iki TAS KANAT, kure yerine suzulen mavi ISIK KALKANI (Algiz runu + kalkanin ustunden gecen parilti).
MARBLE_BRIGHT = (rgba(70, 76, 102), rgba(124, 132, 156), rgba(178, 186, 204), rgba(218, 224, 234), rgba(244, 247, 252))  # ilk hal: "cok parlak ve beyaz"
E_TONES = {  # kullanici: "E cok parlak ve beyaz olmus ama kalkan parlitisi v.b harika" -> govde koyulasti, kalkan ayni
    "arduvaz": (rgba(36, 40, 58), rgba(62, 70, 92), rgba(92, 102, 126), rgba(124, 134, 158), rgba(156, 166, 188)),
    "eski_tas": (rgba(44, 40, 42), rgba(74, 70, 70), rgba(106, 100, 96), rgba(138, 130, 122), rgba(168, 160, 148)),
}
MARBLE = E_TONES["arduvaz"]
WING_AE = {16: (10, 11), 17: (9, 11), 18: (8, 11), 19: (7, 11), 20: (6, 10), 21: (5, 10), 22: (4, 10), 23: (4, 10), 24: (3, 10),
           25: (3, 11), 26: (4, 12), 27: (5, 13), 28: (7, 13), 29: (9, 13), 30: (11, 13)}
WING_AE_FEATHERS = (((9, 20), (5, 23)), ((10, 23), (4, 26)), ((11, 26), (6, 28)))  # tuy kademe cizgileri (ic -> dis)
SHIELD_AE = (5, 5, 5, 5, 5, 5, 4, 4, 4, 3, 3, 2, 1, 0)  # satir basina yari genislik (orta sutun 19)


def light_shield(cv, top, f, pal):
    """Suzulen isik kalkani (heater): parlak kenar, iki tonlu ic, Algiz, capraz gecen parilti bandi."""
    n = len(SHIELD_AE)
    sweep = (f * 4) % 40 - 8  # x + y sabiti; 8 karede bir kez kalkanin ustunden gecer
    for j, hw in enumerate(SHIELD_AE):
        y = top + j
        for x in range(CX - hw, CX + hw + 1):
            rim = j == 0 or x in (CX - hw, CX + hw) or j == n - 1 or (j > 0 and abs(x - CX) > SHIELD_AE[min(n - 1, j + 1)])
            if rim:
                c = pal[4] if (x <= CX and j < 9) else pal[3]
                cv.glow(x, y, c, 0.8)
            else:
                c = pal[2] if x < CX else pal[1]
                if 0 <= (x - CX) + j - sweep <= 1:
                    c = pal[4]
                cv.glow(x, y, c, 0.0)
    # sol ust kose parlamasi
    cv.px(CX - 4, top + 1, pal[5], "front")
    glyph(cv, CX - 2, top + 3, RUNE5_WARD, pal[5], "front", 0.0)


def totem_a_e(f, tone=None):
    global MARBLE
    if tone:
        MARBLE = E_TONES[tone]
    t = f / FRAMES
    cv = Cv()
    ep = SPIRIT
    mound(cv, 8, 30)
    # kale kaidesi: genis basamak + iki mazgal + altin kenar
    fill_rows(cv, {49: (9, 29), 50: (9, 29), 51: (9, 29), 52: (9, 29)}, MARBLE)
    for (xl, xr) in ((9, 12), (26, 29)):
        fill_rows(cv, {46: (xl, xr), 47: (xl, xr), 48: (xl, xr)}, MARBLE)
    cv.hl(9, 29, 50, GOLD[2])
    cv.hl(9, 13, 50, GOLD[3])
    cv.px(29, 50, GOLD[1])
    # kule govde (asagi dogru genisler) + oyma pano
    fill_rows(cv, {y: (14 - (1 if y > 41 else 0), 24 + (1 if y > 41 else 0)) for y in range(33, 49)}, MARBLE, top_light=0)
    for y in range(35, 47):
        cv.px(16, y, MARBLE[1])
        cv.px(22, y, MARBLE[1])
    cv.hl(16, 22, 34, MARBLE[1])
    cv.hl(16, 22, 47, MARBLE[3])
    # panoda asagidan yukari sirayla parlayan Algiz runlari
    for k, y0 in enumerate((42, 36)):
        lit = (f - k * 3) % FRAMES < 4
        glyph(cv, 17, y0, ["X.X.X", ".XXX.", "..X..", "..X.."], ep[4] if lit else ep[2], "emis", 0.7 if lit else 0.25)
    # altin bilezik + mavi tas
    fill_rows(cv, {31: (13, 25), 32: (13, 25)}, GOLD)
    cv.hl(13, 25, 32, GOLD[1])
    cv.glow(18, 31, ep[3], 0.6, "emis")
    cv.glow(19, 31, ep[5], 0.8, "emis")
    cv.glow(20, 31, ep[3], 0.6, "emis")
    # kalkani saran tas kanatlar: tuy kademeleri, ic kenar altin, uc altin
    for y, (xl, xr) in WING_AE.items():
        for x in range(xl, xr + 1):
            u = (x - xl) / max(1, xr - xl)
            cv.px(x, y, MARBLE[3] if u < 0.5 else MARBLE[2])
            cv.px(M(x), y, MARBLE[1] if u < 0.5 else MARBLE[2])
        cv.px(xr, y, GOLD[3] if y < 24 else MARBLE[4])
        cv.px(M(xr), y, GOLD[2] if y < 24 else MARBLE[2])
    for (p0, p1) in WING_AE_FEATHERS:
        n = max(abs(p1[0] - p0[0]), abs(p1[1] - p0[1]))
        for i in range(n + 1):
            x = round(p0[0] + (p1[0] - p0[0]) * i / n)
            y = round(p0[1] + (p1[1] - p0[1]) * i / n)
            cv.px(x, y, MARBLE[1])
            cv.px(M(x), y, MARBLE[0])
        cv.px(p1[0] - 1, p1[1] + 1, MARBLE[2])  # tuy ucu disari tasar
        cv.px(M(p1[0] - 1), p1[1] + 1, MARBLE[1])
    for (x, y) in ((10, 16), (11, 16), (9, 17)):
        cv.px(x, y, GOLD[3])
        cv.px(M(x), y, GOLD[2])
    # kanatlarin ic kenarinda nabizli koruma isigi
    hi = ep[4] if wave(t) > 0.2 else ep[3]
    for y, (xl, xr) in WING_AE.items():
        if 18 <= y <= 28:
            cv.blend(xr + 1, y, hi, 150, "emis")
            cv.blend(M(xr + 1), y, hi, 150, "emis")
    # suzulen isik kalkani
    bob = 1 if wave(t) > 0.5 else (-1 if wave(t) < -0.5 else 0)
    light_shield(cv, 14 + bob, f, ep)
    particles(cv, t, ep, [(15, 28, 0.0, 1.0), (23, 28, 0.5, 1.0), (19, 13, 0.25, 1.5)], 9)
    twinkles(cv, f, ep, [(19, 9, 0), (5, 15, 3), (33, 14, 5)])
    wisps(cv, t, 19, 47, 33, 8, ep)
    return cv.render()


# ------------------------------------------------------------------ B) RUH MASKESI
MASK = {20: (13, 25), 21: (11, 27), 22: (10, 28), 23: (10, 28), 24: (10, 28), 25: (10, 28), 26: (10, 28), 27: (10, 28),
        28: (9, 29), 29: (9, 29), 30: (9, 29), 31: (10, 28), 32: (10, 28), 33: (11, 27), 34: (12, 26), 35: (13, 25),
        36: (14, 24), 37: (15, 23)}
WING_L = {21: (6, 9), 22: (4, 9), 23: (3, 9), 24: (4, 9), 25: (5, 9), 26: (6, 9), 27: (7, 9)}


def totem_b(kind, f):
    t = f / FRAMES
    cv = Cv()
    ep = ELEM[kind]
    pal = RWOOD if kind == "q" else PALE
    mound(cv, 11, 27)
    # direk + kokler + deri sargi
    fill_rows(cv, {y: (15, 23) for y in range(38, 51)}, WOOD, top_light=0)
    fill_rows(cv, {50: (13, 25), 51: (12, 26), 52: (12, 26)}, WOOD, top_light=0)
    cv.hl(15, 23, 44, LEATHER)
    cv.hl(15, 23, 45, LEATHER_D)
    # kanat-kulaklar
    for y, (xl, xr) in WING_L.items():
        for x in range(xl, xr + 1):
            cv.px(x, y, pal[3] if y < 24 else pal[2])
            cv.px(M(x), y, pal[1] if y < 24 else pal[0])
    # maske
    fill_rows(cv, MASK, pal)
    # kanat uclarinda element isigi
    for (x, y) in ((3, 23), (4, 22), (4, 24), (5, 25)):
        cv.glow(x, y, ep[3], 0.5, "emis")
        cv.glow(M(x), y, ep[3], 0.5, "emis")
    # kanattan sarkan boncuk
    sw = 1 if wave(t) > 0.4 else 0
    for xs in (7, M(7)):
        cv.px(xs, 28, LEATHER_D)
        cv.px(xs, 29, LEATHER_D)
        cv.px(xs + sw, 30, GOLD[3])
        cv.glow(xs + sw, 31, ep[3], 0.4, "front")
    # kas, goz cukurlari, parlayan gozler
    if kind == "q":
        brow = [(11, 23), (12, 23), (13, 24), (14, 24), (15, 25), (16, 25), (17, 26)]
    else:
        brow = [(11, 25), (12, 24), (13, 23), (14, 23), (15, 23), (16, 24), (17, 25)]
    for (x, y) in brow:
        cv.px(x, y, pal[0])
        cv.px(M(x), y, pal[0])
    for (y, xl, xr) in ((26, 13, 16), (27, 12, 16), (28, 13, 15)):
        cv.hl(xl, xr, y, OBS[0])
        cv.hl(M(xr), M(xl), y, OBS[0])
    eye = ep[5] if wave(t) > -0.3 else ep[4]
    for (x, y, c) in ((14, 27, eye), (15, 27, eye), (13, 27, ep[3]), (14, 26, ep[3])):
        cv.glow(x, y, c, 0.9, "emis")
        cv.glow(M(x), y, c, 0.9, "emis")
    # burun
    for y in range(28, 31):
        cv.px(18, y, pal[4] if y < 30 else pal[3])
        cv.px(19, y, pal[3])
        cv.px(20, y, pal[1])
    cv.px(18, 31, pal[0])
    cv.px(20, 31, pal[0])
    # alin runu
    if kind == "q":
        glyph(cv, 18, 21, [".X.", "XX.", "X.X"], ep[3] if wave(t, 0.2) > 0 else ep[2], "emis", 0.5)
    else:
        glyph(cv, 18, 21, ["X.X", ".X.", ".X."], ep[4] if wave(t, 0.2) > 0 else ep[3], "emis", 0.5)
    # yanak boyasi
    for (x, y) in ((11, 30), (12, 30), (11, 31), (12, 32)):
        cv.px(x, y, ep[1] if kind == "q" else ep[1])
        cv.px(M(x), y, ep[1])
    if kind == "q":
        # acik agiz: icinde ates, ust dislar
        for y, (xl, xr) in ((32, (15, 23)), (33, (15, 23)), (34, (16, 22))):
            for x in range(xl, xr + 1):
                cv.px(x, y, OBS[0])
        for x in range(16, 23):
            cv.glow(x, 33, FIRE[3] if (x + f) % 3 else FIRE[4], 0.6, "emis")
        for x in range(17, 22):
            cv.glow(x, 34, FIRE[2], 0.3, "emis")
        for (x, y) in ((16, 32), (16, 33), (22, 32), (22, 33), (18, 32), (20, 32)):
            cv.px(x, y, BONE[3], "emis")
        # alev taci: altin bant + 5 alev dili
        cv.hl(13, 25, 19, GOLD[3])
        cv.hl(13, 25, 20, GOLD[2])
        for x in (15, 19, 23):
            cv.glow(x, 20, FIRE[4], 0.4, "emis")
        for (x, h, w, ph) in ((13, 5, 3, 0.0), (16, 8, 4, 0.3), (19, 11, 5, 0.6), (22, 8, 4, 0.15), (25, 5, 3, 0.45)):
            flame(cv, x, 18, h, w, t, ep, 0.8, "front", ph)
        particles(cv, t, ep, [(14, 12, 0.0, 1.0), (24, 11, 0.4, 1.0), (19, 7, 0.7, 1.5)], 7)
    else:
        # sakin agiz + isik gozyaslari
        cv.hl(16, 22, 33, pal[0])
        cv.hl(17, 21, 34, pal[3])
        for k in range(3):
            y = 29 + ((f // 2 + k) % 4)
            a = 230 - 60 * ((f // 2 + k) % 4)
            cv.blend(14, y, ep[4], a, "emis")
            cv.blend(M(14), y, ep[4], a, "emis")
        # isik tuyu taci
        cv.hl(13, 25, 19, GOLD[3])
        cv.hl(13, 25, 20, GOLD[2])
        for x in (15, 19, 23):
            cv.glow(x, 20, ep[4], 0.4, "emis")
        sway = wave(t) * 4
        for (x, ang, ln) in ((14, 140, 8), (16, 115, 10), (19, 90, 12), (22, 65, 10), (24, 40, 8)):
            feather(cv, x, 19, ang + sway * (1 if ang != 90 else 0.5), ln, 4.2, ep, "back", 0.6)
        twinkles(cv, f, ep, [(8, 15, 1), (30, 14, 4), (19, 4, 6)])
    return cv.render()


# ------------------------------------------------------------------ C) SUZULEN RUNLAR
BASE_C = {46: (12, 26), 47: (11, 27), 48: (10, 27), 49: (10, 28), 50: (10, 28), 51: (10, 28), 52: (11, 27)}
BASE_C_ROCKS = ({44: (12, 14), 45: (11, 15)}, {43: (24, 25), 44: (23, 26), 45: (22, 27)})
SHARD1 = [(19, 20), (17, 21), (15, 23), (14, 24), (13, 25), (14, 25), (15, 24), (16, 23), (17, 21), (19, 20)]
SHARD2 = [(18, 20), (16, 22), (15, 23), (15, 23), (16, 23), (17, 22), (18, 20)]
SHARD3 = [(19, 19), (19, 20), (18, 20), (18, 21), (17, 21), (17, 21), (18, 21), (18, 20), (19, 20)]


def _shard(cv, y0, rows):
    fill_rows(cv, {y0 + j: r for j, r in enumerate(rows)}, OBS, top_light=2)
    # alt kenar koyu
    xl, xr = rows[-1]
    cv.hl(xl, xr, y0 + len(rows) - 1, OBS[0])


def totem_c(kind, f):
    t = f / FRAMES
    cv = Cv()
    ep = ELEM[kind]
    mound(cv, 9, 29)
    # kaya kaide + yosun
    fill_rows(cv, BASE_C, STONE, top_light=2)
    for rk in BASE_C_ROCKS:
        fill_rows(cv, rk, STONE, top_light=1)
    for (x, y) in ((12, 46), (13, 46), (11, 47), (24, 46), (25, 47), (16, 46), (21, 46), (11, 45)):
        cv.px(x, y, MOSS)
    cv.px(13, 45, MOSS_L)
    cv.px(24, 45, MOSS_L)
    glyph(cv, 18, 48, R3[4], ep[3], "emis", 0.6)
    b1, b2, b3 = (round(wave(t, ph) * 1.0) for ph in (0.0, 0.33, 0.66))
    y1, y2, y3 = 33 + b1, 23 + b2, 11 + b3
    # enerji sutunu (arkada, parca aralarinda gorunur): yukari akan parlak bantlar
    for y in range(y3 + 2, 47):
        band = 0.5 + 0.5 * math.sin((y * 0.8) + TAU * t * 2)
        cv.glow(19, y, ep[5] if band > 0.55 else ep[4], 0.9, "back")
        cv.blend(18, y, ep[3], 150 + 90 * band, "back")
        cv.blend(20, y, ep[3], 150 + 90 * band, "back")
        cv.blend(17, y, ep[2], 60 + 80 * band, "back")
        cv.blend(21, y, ep[2], 60 + 80 * band, "back")
    # kaide tepesinde isik havuzu
    for x in range(15, 24):
        cv.glow(x, 46, ep[4] if abs(x - 19) < 2 else ep[3], 0.5, "emis")
    _shard(cv, y1, SHARD1)
    _shard(cv, y2, SHARD2)
    _shard(cv, y3, SHARD3)
    # runlar (asagidan yukari sirayla parlar)
    seq = [(17, y1 + 3, RUNE5_FIRE if kind == "q" else RUNE5_WARD), (18, y2 + 2, R3[2]), (19, y3 + 3, ["X", "X", "X"])]
    for k, (gx, gy, rn) in enumerate(seq):
        lit = (f - k * 2) % FRAMES < 4
        glyph(cv, gx, gy, rn, ep[4] if lit else ep[2], "emis", 0.8 if lit else 0.3)
    if kind == "q":
        flame(cv, 19, y3 - 1, 8, 5, t, ep)
    else:
        orb(cv, 19, y3 - 3, 2.2, t, ep)
        sparkle(cv, 19, y3 - 3, TWINKLE[f % FRAMES] + 1, ep)
    particles(cv, t, ep, [(16, 44, 0.0, 1.0), (22, 43, 0.35, 1.0), (13, 32, 0.6, 1.2), (25, 30, 0.8, 1.2)], 14)
    twinkles(cv, f, ep, [(10, 28, 2), (28, 20, 5), (27, 38, 0)])
    return cv.render()


# ------------------------------------------------------------------ D) GOK KUSU
BIRD_HEAD = {17: (17, 21), 18: (16, 22), 19: (15, 23), 20: (15, 23), 21: (15, 23), 22: (15, 23), 23: (15, 23), 24: (16, 22),
             25: (16, 22), 26: (17, 21)}
BIRD_BODY = {27: (14, 24), 28: (13, 25), 29: (13, 25), 30: (13, 25), 31: (13, 25), 32: (13, 25), 33: (13, 25), 34: (14, 24),
             35: (15, 23)}
# kalkik "acik kanat" (sol): omuzdan (14, 30) yukari-disari, dis kenari tuy taragi; ic dolgu element isigi
WING_POLY = [(14, 27), (11, 23), (8, 18), (6, 13), (4, 15), (5, 17), (2, 18), (3, 21), (1, 23), (3, 25), (2, 27), (5, 28),
             (6, 30), (9, 30), (11, 31), (14, 31)]
WING_ARM = [(14, 28), (13, 27), (12, 26), (11, 25), (11, 24), (10, 23), (9, 22), (9, 21), (8, 20), (8, 19), (7, 18), (7, 17),
            (6, 16), (6, 15)]


def energy_wing(cv, side, pal, flap, f, fire):
    sx, sy = 14, 30
    pts = []
    for (x, y) in WING_POLY:
        d = math.hypot(x - sx, y - sy)
        pts.append((x if side < 0 else M(x), y - flap * d / 12.0))
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    mp = mask.load()
    ox = sx if side < 0 else M(sx)
    for y in range(H):
        for x in range(W):
            if not mp[x, y]:
                continue
            edge = any(not (0 <= x + dx < W and 0 <= y + dy < H and mp[x + dx, y + dy])
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            d = math.hypot(x - ox, y - sy)
            ang = math.atan2(sy - y, (ox - x) if side < 0 else (x - ox))  # 0 = disari yatay, pi/2 = yukari
            sector = (ang / 0.30) % 1.0
            if edge:
                c = pal[4] if (y < sy - 6 or d > 9) else pal[3]
                halo = 0.8
            elif d > 4 and sector < 0.2:
                c = pal[1]
                halo = 0.0
            elif d < 6:
                c = pal[3]
                halo = 0.0
            else:
                c = pal[2]
                halo = 0.0
            cv.glow(x, y, c, halo, "back")
            # ates kanadi: dis kenardan yukari kopan alev dilleri
            if fire and edge and d > 8 and (x * 3 + y + f) % 4 == 0:
                cv.glow(x + (-1 if side < 0 else 1) * (1 if y > 22 else 0), y - 1, pal[3], 0.5, "back")
                if (x + f) % 2 == 0:
                    cv.glow(x + (-1 if side < 0 else 1) * (1 if y > 22 else 0), y - 2, pal[2], 0.3, "back")


def totem_d(kind, f):
    t = f / FRAMES
    cv = Cv()
    ep = ELEM[kind]
    mound(cv, 11, 27)
    # direk + alt yuz
    fill_rows(cv, {y: (15, 23) for y in range(36, 51)}, WOOD, top_light=0)
    fill_rows(cv, {50: (13, 25), 51: (12, 26), 52: (12, 26)}, WOOD, top_light=0)
    cv.hl(15, 23, 39, WOOD[0])
    cv.hl(17, 21, 43, WOOD[0])
    cv.hl(18, 20, 44, WOOD[3])
    eh = ep[4] if wave(t, 0.5) > 0 else ep[3]
    cv.glow(16, 40, eh, 0.5, "emis")
    cv.glow(17, 40, ep[2], 0.3, "emis")
    cv.glow(22, 40, eh, 0.5, "emis")
    cv.glow(21, 40, ep[2], 0.3, "emis")
    for y in (46, 48):
        cv.hl(16, 22, y, ep[1])
    # kalkik enerji kanatlari + on kenarda oyma kanat kemigi; cirpma = dis uc 1 px
    flap = 1 if wave(t) > 0.3 else (0 if wave(t) > -0.3 else -1)
    for side in (-1, 1):
        energy_wing(cv, side, ep, flap, f, kind == "q")
    for (x, y) in WING_ARM:
        yy = y - flap * math.hypot(x - 14, y - 30) / 12.0
        cv.px(x, yy, WOOD[3])
        cv.px(M(x), yy, WOOD[1])
    # govde + bas
    fill_rows(cv, BIRD_BODY, WOOD, top_light=0)
    for y in (29, 31, 33):
        for x in range(14 + (y // 2) % 2, 25, 2):
            cv.px(x, y, WOOD[1])
    fill_rows(cv, BIRD_HEAD, WOOD, top_light=1)
    cv.hl(15, 23, 20, WOOD[0])
    for (x, y) in ((16, 21), (17, 21)):
        cv.glow(x, y, ep[5] if x == 17 else ep[3], 0.7, "emis")
        cv.glow(M(x), y, ep[5] if x == 17 else ep[3], 0.7, "emis")
    # altin gaga
    for (x, y, c) in ((18, 23, GOLD[3]), (19, 23, GOLD[2]), (20, 23, GOLD[1]), (18, 24, GOLD[2]), (19, 24, GOLD[2]),
                      (20, 24, GOLD[1]), (19, 25, GOLD[2]), (19, 26, GOLD[1])):
        cv.px(x, y, c, "emis")
    # gogus tasi
    cv.glow(18, 30, ep[3], 0.7, "emis")
    cv.glow(19, 30, ep[5], 0.9, "emis")
    cv.glow(20, 30, ep[3], 0.7, "emis")
    cv.glow(19, 31, ep[3], 0.7, "emis")
    cv.glow(19, 29, ep[4], 0.7, "emis")
    # tepe tuyleri
    for (x, ang, ln) in ((17, 110, 4), (19, 90, 5), (21, 70, 4)):
        feather(cv, x, 16, ang, ln, 2.2, ep, "front", 0.5)
    if kind == "q":
        particles(cv, t, ep, [(4, 16, 0.0, 1.0), (34, 16, 0.5, 1.0), (19, 14, 0.25, 1.0)], 8)
    else:
        twinkles(cv, f, ep, [(3, 12, 0), (35, 12, 4), (19, 9, 2)])
    return cv.render()


DIRECTIONS = [
    ("A", "Element Catali", totem_a),
    ("B", "Ruh Maskesi", totem_b),
    ("C", "Suzulen Runlar", totem_c),
    ("D", "Gok Kusu", totem_d),
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
            if r < 6:
                px[x, y] = rgba(91, 146, 82)
            elif r < 8:
                px[x, y] = rgba(150, 197, 95)
    return im


def font(sz):
    try:
        return ImageFont.truetype("arial.ttf", sz)
    except Exception:
        return ImageFont.load_default()


def old_frames():
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
    open(os.path.join(OUT, ".gdignore"), "w").close()
    sheets = {}
    for (key, name, fn) in DIRECTIONS:
        for kind in ("q", "e"):
            frames = [fn(kind, f) for f in range(FRAMES)]
            sheet = Image.new("RGBA", (W * FRAMES, H), (0, 0, 0, 0))
            for i, fr in enumerate(frames):
                sheet.paste(fr, (i * W, 0), fr)
            sheet.save(os.path.join(OUT, "totem_%s_%s.png" % (key, kind)))
            sheets[(key, kind)] = frames

    # 1) yakin sayfa x4
    Z = 4
    cw, ch = W * Z, H * Z
    pad, lab = 16, 38
    page = Image.new("RGBA", (pad + 4 * (cw + pad), lab + len(DIRECTIONS) * (ch + lab) + pad), rgba(34, 40, 30))
    d = ImageDraw.Draw(page)
    fnt = font(21)
    for r, (key, name, fn) in enumerate(DIRECTIONS):
        y = lab + r * (ch + lab)
        d.text((pad, y - 29), "%s - %s   (Q Saldiri | E Kalkan)" % (key, name), fill=(236, 226, 200), font=fnt)
        for c, (kind, fi) in enumerate((("q", 0), ("q", 4), ("e", 0), ("e", 4))):
            x = pad + c * (cw + pad)
            page.paste(grass_bg(W, H, seed=r * 7 + c).resize((cw, ch), Image.NEAREST), (x, y))
            page.alpha_composite(sheets[(key, kind)][fi].resize((cw, ch), Image.NEAREST), (x, y))
    page.save(os.path.join(OUT, "totem_sayfa.png"))

    # 2) oyun olcegi x2 (kamera zoom 2), Shaman + eski v3 ayni piksel yogunlugunda
    S = 2
    old = old_frames()
    items = [("Shaman", shaman_frame()), ("eski Q", old["q"]), ("eski E", old["e"])]
    for (key, name, fn) in DIRECTIONS:
        items.append((key + " Q", sheets[(key, "q")][0]))
        items.append((key + " E", sheets[(key, "e")][0]))
    gap = 4
    base = 96
    tot_w = sum(im.width for _, im in items) + gap * (len(items) + 1)
    scene = grass_bg(tot_w, base + 10, seed=3)
    x = gap
    labels = []
    for (nm, im) in items:
        if nm == "Shaman":
            fy = base - 41
        elif nm.startswith("eski"):
            fy = base - im.height + 3
        else:
            fy = base - GY
        scene.alpha_composite(im, (x, fy))
        labels.append((nm, x + im.width // 2))
        x += im.width + gap
    big = scene.resize((scene.width * S, scene.height * S), Image.NEAREST)
    canvas = Image.new("RGBA", (big.width, big.height + 32), rgba(34, 40, 30))
    canvas.paste(big, (0, 0))
    d = ImageDraw.Draw(canvas)
    f2 = font(15)
    for (nm, cx) in labels:
        d.text((cx * S - d.textlength(nm, font=f2) / 2, big.height + 7), nm, fill=(236, 226, 200), font=f2)
    canvas.save(os.path.join(OUT, "totem_oyun.png"))

    # 3) GIF x3, 10 fps
    Z = 3
    n = len(DIRECTIONS) * 2
    gw, gh = n * (W * Z + 6) + 6, H * Z + 12
    bgs = grass_bg(gw // Z + 1, gh // Z + 1, seed=11).resize(((gw // Z + 1) * Z, (gh // Z + 1) * Z), Image.NEAREST).crop((0, 0, gw, gh))
    gif = []
    for f in range(FRAMES):
        fr = bgs.copy()
        x = 6
        for (key, name, fn) in DIRECTIONS:
            for kind in ("q", "e"):
                fr.alpha_composite(sheets[(key, kind)][f].resize((W * Z, H * Z), Image.NEAREST), (x, 6))
                x += W * Z + 6
        gif.append(fr.convert("RGB"))
    gif[0].save(os.path.join(OUT, "totem_anim.gif"), save_all=True, append_images=gif[1:], duration=int(1000 / FPS), loop=0)
    print("ok ->", OUT)


if __name__ == "__main__":
    main()
