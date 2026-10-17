"""Shaman totemleri v5 PROTOTIPLERI - DOGA TEMALI (madde 176 devami). OYUNA BAGLI DEGIL.

Kullanici (2026-10-16, efekt A secildikten sonra): "efektler guzel ancak totemlerden emin olamadim. doga temali yeni totemler uretir misin".
Onceki dersler: sade = "gosterissiz" (1. tur), Shaman'a benzemek sart degil, sihirli/gosterisli olsun; E koruma temali, ortada KALKAN
(kure degil), cok parlak/beyaz govde olmasin. Faset kristal / yorunge parcalari = "teknolojik" (v2) -> kacin.
Efekt A ile uyum: Q ates topu totemin tepesindeki ATESTEN cikar, E kalkan aktarimi tepedeki KALKANDAN (yaklasik satir 20, ayak 52).

Kare 40x56, ayak y=52, 8 kare 10 fps, 1 sanat px = Shaman pikseli (0.903 dunya); cizim yardimcilari shaman_totem_proto2.py'den.
  A Kadim Kutuk   - yuzlu, yosunlu yasli kutuk, kokler; iki dal bir besik yapar: Q dallar arasinda kor tohumu + alev, E yaprak damarli isik kalkani
  B Cicek         - orgulu sarmasik sap + iri yapraklar; Q ates zambagi (alev yaprakli, ortasinda kor + alev), E kalkan nilüferi (mavi isik yapraklari + kucuk kalkan)
  C Mantar        - kalin sapli dev mantar + etek + dipte yavru mantarlar; Q kirmizi sapka, kor benekler, tepesinde alev; E biyolüminesan mavi sapka,
                    Algiz runu, sapka altindan damlayan isik, ustunde ince koruma kubbesi
  D Hayvan Ruhlari - Q: ates kuyruklu oyma TILKI (kulaklari arasinda alev), E: runlu kabuklu KAPLUMBAGA (kabuk dikisleri mavi parlar, ustunde isik kalkani)
Ciktilar: tools/proto_20261016/totem3/ (.gdignore). Calistir: python tools/proto_20261016/shaman_totem_proto3.py
"""
import importlib.util
import math
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(HERE, "totem3")
_spec = importlib.util.spec_from_file_location("p2", os.path.join(HERE, "shaman_totem_proto2.py"))
p2 = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(p2)

W, H, CX, GY, FRAMES, FPS = p2.W, p2.H, p2.CX, p2.GY, p2.FRAMES, p2.FPS
Cv, M, rgba, shade, fill_rows, wave = p2.Cv, p2.M, p2.rgba, p2.shade, p2.fill_rows, p2.wave
FIRE, SPIRIT, ELEM, GOLD, OBS = p2.FIRE, p2.SPIRIT, p2.ELEM, p2.GOLD, p2.OBS
MOSS_D, MOSS, MOSS_L, EARTH = p2.MOSS_D, p2.MOSS, p2.MOSS_L, p2.EARTH
TAU = math.tau

BARK = (rgba(30, 22, 20), rgba(58, 42, 34), rgba(88, 64, 48), rgba(120, 92, 66), rgba(152, 122, 88))
LEAF = (rgba(22, 48, 28), rgba(38, 82, 40), rgba(66, 120, 50), rgba(110, 160, 66), rgba(164, 200, 100))
VINE = (rgba(28, 44, 24), rgba(50, 74, 34), rgba(78, 106, 46), rgba(112, 140, 62), rgba(148, 170, 84))
CAP_R = (rgba(64, 18, 16), rgba(120, 34, 26), rgba(172, 58, 38), rgba(212, 98, 60), rgba(238, 150, 104))
CAP_B = (rgba(16, 32, 62), rgba(26, 58, 104), rgba(40, 90, 150), rgba(70, 132, 192), rgba(120, 182, 228))
STEM = (rgba(92, 80, 66), rgba(146, 132, 108), rgba(190, 178, 150), rgba(222, 214, 190), rgba(242, 238, 222))
FOX = (rgba(80, 30, 14), rgba(146, 60, 24), rgba(202, 102, 42), rgba(234, 148, 78), rgba(250, 194, 138))
FUR_W = (rgba(140, 130, 122), rgba(192, 184, 174), rgba(230, 226, 218), rgba(250, 248, 244), rgba(255, 255, 255))
WOOD = p2.WOOD
SHELL = (rgba(28, 40, 30), rgba(48, 66, 42), rgba(76, 94, 56), rgba(108, 122, 74), rgba(140, 150, 94))
SKIN = (rgba(40, 54, 38), rgba(70, 90, 58), rgba(104, 124, 80), rgba(138, 156, 104), rgba(170, 184, 128))


# ------------------------------------------------------------------ yardimcilar
def stroke(cv, pts, widths, pal, layer="body"):
    """Kalinligi degisen dal/kok: noktalar arasi disklerle; isik soldan (silindir golgesi)."""
    for i in range(len(pts) - 1):
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        w0, w1 = widths[i], widths[i + 1]
        n = int(max(abs(x1 - x0), abs(y1 - y0)) * 3) + 1
        for k in range(n + 1):
            s = k / n
            x, y, r = x0 + (x1 - x0) * s, y0 + (y1 - y0) * s, (w0 + (w1 - w0) * s) / 2
            R = int(math.ceil(r))
            for dy in range(-R, R + 1):
                for dx in range(-R, R + 1):
                    if math.hypot(dx, dy) <= max(0.5, r):
                        cv.px(x + dx, y + dy, shade(pal, (dx + r) / (2 * r) if r > 0.6 else 0.5), layer)


def gstroke(cv, pts, widths, pal, layer="back", halo=0.5):
    """Isiktan serit (ates kuyrugu): ortasi parlak, kenari koyu element rengi, ucu beyaza yakin."""
    tot = len(pts) - 1
    for i in range(tot):
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        w0, w1 = widths[i], widths[i + 1]
        n = int(max(abs(x1 - x0), abs(y1 - y0)) * 3) + 1
        for k in range(n + 1):
            s = k / n
            v = (i + s) / tot
            x, y, r = x0 + (x1 - x0) * s, y0 + (y1 - y0) * s, (w0 + (w1 - w0) * s) / 2
            R = int(math.ceil(r))
            for dy in range(-R, R + 1):
                for dx in range(-R, R + 1):
                    d = math.hypot(dx, dy)
                    if d <= max(0.5, r):
                        q = d / max(0.6, r)
                        c = pal[4] if q < 0.4 else (pal[3] if q < 0.75 else pal[2])
                        if v > 0.85 and q < 0.6:
                            c = pal[5]
                        cv.glow(x + dx, y + dy, c, halo if q > 0.7 else 0.0, layer)


def leaf(cv, x0, y0, ang, length, wmax, pal, layer="body"):
    """Sivri uclu yaprak + orta damar; ust yari acik ton."""
    a = math.radians(ang)
    dx, dy = math.cos(a), -math.sin(a)
    nx, ny = -dy, dx
    steps = int(length * 3) + 1
    for i in range(steps + 1):
        s = i / steps
        half = (wmax / 2) * math.sin(math.pi * min(1.0, s)) ** 0.7
        px_, py_ = x0 + dx * s * length, y0 + dy * s * length
        n = max(1, int(half * 4))
        for j in range(-n, n + 1):
            k = half * j / n
            c = pal[1] if (abs(k) < 0.45 and 0.1 < s < 0.85) else (pal[3] if k < 0 else pal[2])
            cv.px(px_ + nx * k, py_ + ny * k, c, layer)


def bob(t):
    return 1 if wave(t) > 0.5 else (-1 if wave(t) < -0.5 else 0)


def fireflies(cv, f, spots, col=(rgba(230, 255, 140), rgba(160, 220, 80))):
    """Ates bocekleri: yavasca yanip sonen sari-yesil tek nokta + yumusak halo."""
    for (x, y, ph) in spots:
        k = (f + ph) % FRAMES
        if k < 5:
            yy = y - (k % 3 == 2)
            cv.glow(x, yy, col[0] if k in (1, 2, 3) else col[1], 0.6 if k in (1, 2, 3) else 0.3)


SHIELD_ROWS = (3, 5, 5, 5, 5, 5, 4, 4, 4, 3, 3, 2, 1, 0)


def leaf_shield(cv, top, f, pal, rows=SHIELD_ROWS, veins=(5, 8, 11)):
    """Yaprak damarli isik kalkani: parlak kenar, iki tonlu ic, orta damar + yukari bakan yan damarlar, uzerinden gecen parilti."""
    n = len(rows)
    sweep = (f * 4) % 40 - 8
    vein = set()
    for j in range(1, n - 2):
        vein.add((CX, j))
    for j0 in veins:
        for d in range(1, 4):
            if j0 - d >= 1:
                vein.add((CX - d, j0 - d))
                vein.add((CX + d, j0 - d))
    for j, hw in enumerate(rows):
        y = top + j
        for x in range(CX - hw, CX + hw + 1):
            rim = j == 0 or x in (CX - hw, CX + hw) or j == n - 1 or (j > 0 and abs(x - CX) > rows[min(n - 1, j + 1)])
            if rim:
                cv.glow(x, y, pal[4] if (x <= CX and j < 9) else pal[3], 0.8)
            else:
                c = pal[2] if x < CX else pal[1]
                if (x, j) in vein:
                    c = pal[5] if x == CX else pal[4]
                elif 0 <= (x - CX) + j - sweep <= 1:
                    c = pal[4]
                cv.glow(x, y, c, 0.0)


# ------------------------------------------------------------------ A) KADIM KUTUK
def totem_a(kind, f):
    t = f / FRAMES
    cv = Cv()
    ep = ELEM[kind]
    p2.mound(cv, 6, 32)
    # kokler
    for pts, ws in (([(14, 47), (11, 50), (7, 52)], [3.2, 2.4, 1.2]), ([(15, 49), (13, 51), (11, 52)], [2.4, 1.8, 1.0])):
        stroke(cv, pts, ws, BARK)
        stroke(cv, [(M(x), y) for x, y in pts], ws, BARK)
    # govde (hafif yamuk, budakli)
    rows = {}
    for y in range(29, 52):
        xl, xr = (11, 27) if y >= 48 else ((12, 26) if y >= 45 else (13, 25))
        if y in (33, 34):
            xl -= 1
        if y in (39, 40, 41):
            xr += 1
        rows[y] = (xl, xr)
    fill_rows(cv, rows, BARK, top_light=0)
    for (x, y0, y1) in ((15, 29, 32), (16, 44, 50), (22, 30, 32), (24, 44, 49), (20, 46, 50), (14, 39, 43)):
        for y in range(y0, y1 + 1):
            cv.px(x, y, BARK[0])
    for (x, y, c) in ((24, 39, BARK[0]), (25, 40, BARK[0]), (24, 41, BARK[3]), (25, 39, BARK[1])):
        cv.px(x, y, c)
    # yuz: catik kas, element gozler, burun, kovuk agiz (icinde loş isik)
    for (x, y) in ((14, 34), (15, 34), (16, 35), (17, 35)):
        cv.px(x, y, BARK[0])
        cv.px(M(x), y, BARK[0])
    eh = ep[5] if wave(t, 0.3) > 0 else ep[4]
    for (x, y, c) in ((15, 36, eh), (16, 36, eh), (14, 36, ep[3])):
        cv.glow(x, y, c, 0.7, "emis")
        cv.glow(M(x), y, c, 0.7, "emis")
    for x in (15, 16):
        cv.px(x, 37, BARK[1])
        cv.px(M(x), 37, BARK[1])
    cv.px(19, 37, BARK[3])
    cv.px(19, 38, BARK[3])
    cv.px(20, 38, BARK[1])
    for (y, xl, xr) in ((41, 17, 21), (42, 17, 21), (43, 18, 20)):
        cv.hl(xl, xr, y, OBS[0])
    for x in (18, 19, 20):
        cv.blend(x, 42, ep[2], 170 if wave(t) > 0 else 110, "emis")
    # omuzlarda yosun
    for (x, y) in ((13, 29), (14, 29), (15, 29), (13, 30), (23, 29), (24, 29), (25, 29), (25, 30), (12, 33), (26, 46), (12, 45)):
        cv.px(x, y, MOSS)
    for (x, y) in ((14, 29), (24, 29), (12, 33)):
        cv.px(x, y, MOSS_L)
    # dallar -> besik
    L = ([(16, 30), (14, 27), (12, 24), (10, 21), (10, 18), (11, 15)], [3.6, 3.0, 2.6, 2.2, 1.8, 1.2])
    L2 = ([(11, 22), (8, 20), (6, 17)], [1.8, 1.4, 1.0])
    R = ([(22, 30), (24, 27), (26, 24), (28, 21), (28, 18), (27, 15)], [3.6, 3.0, 2.6, 2.2, 1.8, 1.2])
    R2 = ([(27, 22), (30, 20), (32, 17)], [1.8, 1.4, 1.0])
    for pts, ws in (L, L2, R, R2):
        stroke(cv, pts, ws, BARK)
    sw = wave(t) * 6
    for (x, y, a0) in ((11, 14, 100), (6, 16, 140), (27, 14, 80), (32, 16, 40)):
        for da in (-35, 0, 35):
            leaf(cv, x, y, a0 + da + sw, 4.5, 2.6, LEAF)
    cy = 21 + bob(t)
    if kind == "q":
        # dal uclarinda kor
        for (x, y) in ((11, 15), (27, 15)):
            cv.glow(x, y + 1, FIRE[3] if wave(t, 0.4) > 0 else FIRE[2], 0.4, "emis")
        p2.orb(cv, CX, cy, 3.4, t, ep)
        p2.flame(cv, CX, cy - 2, 8, 6, t, ep)
        p2.particles(cv, t, ep, [(16, cy, 0.0, 1.0), (22, cy, 0.5, 1.0), (19, cy - 6, 0.25, 1.5)], 10)
    else:
        leaf_shield(cv, cy - 7, f, ep)
        p2.particles(cv, t, ep, [(15, 28, 0.0, 1.0), (23, 28, 0.5, 1.0)], 9)
        p2.twinkles(cv, f, ep, [(19, 9, 0), (6, 11, 3), (32, 11, 5)])
    fireflies(cv, f, [(4, 36, 0), (34, 30, 3), (8, 26, 6)])
    return cv.render()


# ------------------------------------------------------------------ B) CICEK
def totem_b(kind, f):
    t = f / FRAMES
    cv = Cv()
    ep = ELEM[kind]
    p2.mound(cv, 9, 29)
    # kok yumrusu
    fill_rows(cv, {47: (16, 22), 48: (15, 23), 49: (14, 24), 50: (13, 25), 51: (13, 25)}, VINE, top_light=1)
    # orgulu sap: iki iplik, ondeki her satirda degisir
    for y in range(27, 48):
        ph = y * 0.55
        xa, xb = CX + 1.8 * math.sin(ph), CX - 1.8 * math.sin(ph)
        strands = [(xa, (VINE[3], VINE[2])), (xb, (VINE[1], VINE[0]))]
        if math.cos(ph) < 0:
            strands.reverse()
        for (x, (c1, c2)) in strands:
            cv.px(x - 1, y, c1)
            cv.px(x, y, c2)
            cv.px(x + 1, y, c2)
    # iri yapraklar (salinir)
    sw = wave(t) * 4
    leaf(cv, 18, 42, 168 + sw, 12, 6.0, LEAF)
    leaf(cv, 20, 37, 12 - sw, 12, 6.0, LEAF)
    leaf(cv, 18, 32, 140 + sw, 7, 3.6, LEAF)
    leaf(cv, 20, 46, 30 - sw, 6, 3.2, LEAF)
    # canak
    fill_rows(cv, {26: (16, 22), 27: (17, 21), 28: (18, 20)}, VINE, top_light=1)
    cv.px(15, 25, VINE[3])
    cv.px(23, 25, VINE[2])
    cy = 21 + bob(t)
    if kind == "q":
        # ates zambagi: arka yapraklar arkada, on yapraklar onde; ortada kor + alev
        fl = wave(t * 2) * 3
        for (ang, ln) in ((90, 12), (64, 11), (116, 11)):
            p2.feather(cv, CX, 26, ang + fl * (1 if ang != 90 else 0.3), ln, 5.6, FIRE, "back", 0.6)
        p2.orb(cv, CX, cy, 3.0, t, ep)
        p2.flame(cv, CX, cy - 2, 8, 5, t, ep)
        for (ang, ln) in ((36, 9), (144, 9)):
            p2.feather(cv, CX, 27, ang - fl, ln, 5.0, FIRE, "front", 0.5)
        p2.particles(cv, t, ep, [(14, 18, 0.0, 1.0), (24, 18, 0.5, 1.0), (19, 10, 0.25, 1.4)], 9)
    else:
        # kalkan niluferi: yari kapali isik yapraklari + ortada kucuk kalkan
        fl = wave(t) * 2
        lot = (SPIRIT[0], SPIRIT[0], SPIRIT[1], SPIRIT[2], SPIRIT[4], SPIRIT[5])  # doygun mavi, uc acik (beyaz govde istenmedi)
        for (ang, ln) in ((90, 12), (70, 11), (110, 11)):
            p2.feather(cv, CX, 26, ang + fl * (1 if ang != 90 else 0), ln, 5.6, lot, "back", 0.6)
        leaf_shield(cv, cy - 5, f, ep, rows=(2, 3, 3, 3, 3, 3, 2, 2, 1, 0), veins=(4, 7))
        for (ang, ln) in ((42, 9), (138, 9)):
            p2.feather(cv, CX, 27, ang - fl, ln, 5.0, lot, "front", 0.5)
        p2.twinkles(cv, f, ep, [(19, 6, 0), (9, 14, 3), (29, 14, 5)])
    # dipte kucuk cicekler + ates bocekleri
    for (x, c) in ((11, rgba(240, 220, 120)), (27, rgba(230, 160, 200))):
        cv.px(x, 50, MOSS)
        cv.px(x, 49, c)
        cv.px(x - 1, 49, c)
        cv.px(x, 48, c)
    fireflies(cv, f, [(5, 34, 0), (33, 28, 4)])
    return cv.render()


# ------------------------------------------------------------------ C) MANTAR
CAP = {17: 4, 18: 7, 19: 9, 20: 10, 21: 11, 22: 11, 23: 12, 24: 12, 25: 12, 26: 12, 27: 11}
SPOTS = ((14, 21), (18, 19), (23, 20), (26, 24), (11, 25), (21, 23), (16, 25))


def _baby(cv, x, y, hw, pal):
    for yy in range(y + 2, GY + 1):
        cv.px(x, yy, STEM[2])
    fill_rows(cv, {y: (x - hw + 1, x + hw - 1), y + 1: (x - hw, x + hw), y + 2: (x - hw, x + hw)}, pal, top_light=1)


def totem_c(kind, f):
    t = f / FRAMES
    cv = Cv()
    ep = ELEM[kind]
    cap = CAP_R if kind == "q" else CAP_B
    p2.mound(cv, 6, 32)
    _baby(cv, 10, 46, 3, cap)
    _baby(cv, 28, 48, 2, cap)
    # sap + etek
    rows = {y: (CX - (6 if y > 49 else (5 if y > 44 else 4)), CX + (6 if y > 49 else (5 if y > 44 else 4))) for y in range(30, 52)}
    fill_rows(cv, rows, STEM, top_light=0)
    fill_rows(cv, {33: (13, 25), 34: (12, 26)}, STEM, top_light=1)
    cv.hl(13, 25, 35, STEM[0])
    for (x, y) in ((17, 39), (21, 43), (16, 47), (22, 38)):
        cv.px(x, y, STEM[1])
    fill_rows(cv, {41: (24, 27), 42: (24, 28)}, cap, top_light=1)  # yan raf mantari
    # sapka alti (lamel)
    for y in (28, 29):
        for x in range(CX - 11 + (y - 28), CX + 12 - (y - 28)):
            cv.px(x, y, cap[0] if x % 2 else STEM[1])
    # sapka kubbesi (isik sol ust)
    for y, hw in CAP.items():
        for x in range(CX - hw, CX + hw + 1):
            u = (x - (CX - hw)) / max(1, 2 * hw)
            c = shade(cap, u)
            if y < 21 and u < 0.55:
                c = cap[4] if (y < 19 and u < 0.45) else cap[3]
            if y == 27:
                c = cap[1] if u < 0.7 else cap[0]
            cv.px(x, y, c)
    hi = wave(t) > 0
    if kind == "q":
        for i, (x, y) in enumerate(SPOTS):  # kor benekler (nabiz sirayla)
            lit = (f + i) % 4 < 2
            for (dx, dy) in ((0, 0), (1, 0), (0, 1), (1, 1)):
                cv.glow(x + dx, y + dy, (FIRE[4] if lit else FIRE[3]) if (dx + dy) == 0 else FIRE[2], 0.4 if lit else 0.15, "emis")
        p2.orb(cv, CX, 17, 2.4, t, ep)
        p2.flame(cv, CX, 16, 9, 6, t, ep)
        p2.particles(cv, t, ep, [(12, 20, 0.0, 1.2), (26, 21, 0.4, 1.2), (19, 12, 0.7, 1.5), (9, 44, 0.2, 1.0)], 11)
    else:
        for i, (x, y) in enumerate(SPOTS):
            lit = (f + i) % 4 < 2
            for (dx, dy) in ((0, 0), (1, 0), (0, 1), (1, 1)):
                cv.glow(x + dx, y + dy, (SPIRIT[5] if lit else SPIRIT[4]) if (dx + dy) == 0 else SPIRIT[3], 0.4 if lit else 0.15, "emis")
        p2.glyph(cv, 17, 21, p2.RUNE5_WARD, SPIRIT[5] if hi else SPIRIT[4], "emis", 0.6)
        for x in range(CX - 10, CX + 11):  # lamel isigi
            cv.blend(x, 29, SPIRIT[3], 120, "emis")
        for k, x in enumerate((12, 17, 22, 26)):  # damlayan isik
            d = (f + k * 3) % 8
            if d < 6:
                cv.glow(x, 31 + d, SPIRIT[4], 0.4, "front")
        # ince koruma kubbesi (yari saydam kesik yay)
        for i in range(56):
            a = math.pi * i / 55
            x, y = CX + math.cos(a) * 16, 27 - math.sin(a) * 15
            if (i + f) % 3 != 0:
                cv.blend(x, y, SPIRIT[3], 90 + 60 * (1 if hi else 0), "front")
        p2.twinkles(cv, f, ep, [(19, 8, 0), (5, 18, 3), (33, 16, 5)])
    fireflies(cv, f, [(4, 38, 0), (34, 36, 4)])
    return cv.render()


# ------------------------------------------------------------------ D) HAYVAN RUHLARI (Q tilki / E kaplumbaga)
FOX_HEAD = {20: (13, 25), 21: (12, 26), 22: (11, 27), 23: (11, 27), 24: (11, 27), 25: (11, 27), 26: (11, 27), 27: (12, 26),
            28: (13, 25), 29: (14, 24), 30: (15, 23), 31: (16, 22), 32: (17, 21), 33: (18, 20)}
FOX_EAR = {13: (12, 12), 14: (12, 13), 15: (12, 14), 16: (12, 15), 17: (12, 16), 18: (13, 17), 19: (13, 17)}


def _fox(cv, f, t):
    ep = FIRE
    # ates kuyruklari (diregin arkasindan dolanir)
    fl = wave(t * 2)
    tails = (
        ([(17, 49), (12, 47), (8, 43), (6, 38), (8, 33 + fl), (11, 31 + fl)], [2.0, 3.2, 3.8, 3.4, 2.4, 1.0]),
        ([(21, 49), (26, 47), (30, 43), (32, 38), (30, 33 - fl), (27, 31 - fl)], [2.0, 3.2, 3.8, 3.4, 2.4, 1.0]),
        ([(19, 49), (14, 45), (12, 40), (14, 36 + fl)], [1.6, 2.6, 2.4, 1.0]),
    )
    for pts, ws in tails:
        gstroke(cv, pts, ws, ep, "back", 0.6)
    # direk
    fill_rows(cv, {y: (16, 22) for y in range(33, 50)}, WOOD, top_light=0)
    fill_rows(cv, {49: (14, 24), 50: (13, 25), 51: (13, 25), 52: (13, 25)}, WOOD, top_light=1)
    cv.hl(16, 22, 40, WOOD[0])
    cv.hl(16, 22, 41, GOLD[2])
    cv.hl(16, 22, 44, WOOD[0])
    # kulaklar + bas
    for y, (xl, xr) in FOX_EAR.items():
        for x in range(xl, xr + 1):
            inner = x > xl and y > 15 and x < xr
            cv.px(x, y, OBS[1] if y < 15 else (FOX[0] if inner else FOX[2]))
            cv.px(M(x), y, OBS[1] if y < 15 else (FOX[0] if inner else FOX[1]))
    fill_rows(cv, FOX_HEAD, FOX, top_light=1)
    # beyaz yanaklar + burun
    for y in range(27, 34):
        for x in range(FOX_HEAD[y][0], FOX_HEAD[y][1] + 1):
            if y >= 29 or x <= 13 or x >= 25:
                cv.px(x, y, FUR_W[2] if x <= CX else FUR_W[1])
    cv.hl(18, 20, 33, OBS[0])
    cv.px(19, 32, OBS[1])
    # alin alev isareti + egik gozler
    p2.glyph(cv, 18, 21, [".X.", "XX.", "X.X"], FIRE[4] if wave(t) > 0 else FIRE[3], "emis", 0.5)
    for (x, y, c) in ((14, 25, FIRE[3]), (15, 25, FIRE[5]), (16, 24, FIRE[4])):
        cv.glow(x, y, c, 0.7, "emis")
        cv.glow(M(x), y, c, 0.7, "emis")
    for x in (14, 15):
        cv.px(x, 24, FOX[0])
        cv.px(M(x), 24, FOX[0])
    # kulaklar arasinda ates
    cy = 18 + bob(t)
    p2.orb(cv, CX, cy, 2.8, t, ep)
    p2.flame(cv, CX, cy - 2, 8, 5, t, ep)
    p2.particles(cv, t, ep, [(8, 34, 0.0, 1.2), (30, 34, 0.5, 1.2), (19, 10, 0.25, 1.4)], 10)


SHELL_ROWS = {33: (15, 23), 34: (12, 26), 35: (10, 28), 36: (9, 29), 37: (8, 30), 38: (8, 30), 39: (7, 31), 40: (7, 31),
              41: (7, 31), 42: (7, 31), 43: (7, 31), 44: (7, 31), 45: (8, 30), 46: (8, 30)}
# kaplumbaga kabugu: ortada altigen pul + koselerinden kenara uzanan dikisler + alt kenar pullari
_HEX = ([(x, 37) for x in range(17, 22)] + [(16, 38), (22, 38)] + [(15, y) for y in (39, 40, 41)] + [(23, y) for y in (39, 40, 41)]
        + [(16, 42), (22, 42)] + [(x, 43) for x in range(17, 22)])
_RAYS = ([(19, 36), (19, 35), (19, 34)] + [(15, 37), (14, 36), (13, 35), (12, 35)] + [(23, 37), (24, 36), (25, 35), (26, 35)]
         + [(14, 40), (13, 40), (12, 40), (11, 40), (10, 40), (9, 40), (8, 40)] + [(24, 40), (25, 40), (26, 40), (27, 40), (28, 40), (29, 40), (30, 40)]
         + [(15, 43), (14, 44), (13, 45)] + [(23, 43), (24, 44), (25, 45)] + [(19, 44), (19, 45)])
_RIM = [(x, 45) for x in (9, 11, 16, 22, 27, 29)]
SEAMS = _HEX + _RAYS + _RIM


def _turtle(cv, f, t):
    ep = SPIRIT
    # ayaklar + bas (kabugun altinda / onunde)
    for (xl, xr) in ((8, 11), (27, 30)):
        fill_rows(cv, {y: (xl, xr) for y in range(47, 53)}, SKIN, top_light=0)
        for x in (xl, xl + 2):
            cv.px(x, 52, OBS[1])
    fill_rows(cv, {47: (8, 30)}, SHELL, top_light=1)  # karin kenari
    # kubbe kabuk: yuvarlak isik (sol ust acik, alt kenar koyu)
    for y, (xl, xr) in SHELL_ROWS.items():
        for x in range(xl, xr + 1):
            dxn, dyn = (x - CX) / 12.0, (y - 40) / 7.5
            lum = 0.55 - 0.35 * dxn - 0.3 * dyn
            c = SHELL[4] if lum > 0.85 else (SHELL[3] if lum > 0.6 else (SHELL[2] if lum > 0.3 else SHELL[1]))
            if y >= 45:
                c = SHELL[2] if x < CX else SHELL[1]
            cv.px(x, y, c)
    # bas: kabugun altindan onde, yuvarlak; gozler mavi
    fill_rows(cv, {45: (16, 22), 46: (15, 23), 47: (15, 23), 48: (15, 23), 49: (16, 22), 50: (17, 21)}, SKIN, top_light=1)
    cv.glow(17, 47, ep[4], 0.5, "emis")
    cv.glow(21, 47, ep[4], 0.5, "emis")
    cv.px(17, 46, SKIN[0])
    cv.px(21, 46, SKIN[0])
    cv.hl(18, 20, 49, SKIN[1])
    # kabuk dikisleri: koyu oluk + sirayla parlayan mavi isik
    for i, (x, y) in enumerate(SEAMS):
        cv.px(x, y, SHELL[0])
        lit = (i // 6 + f) % 4 < 2
        cv.blend(x, y, ep[4] if lit else ep[2], 230 if lit else 150, "emis")
    p2.glyph(cv, 17, 38, ["X.X.X", ".XXX.", "..X..", "..X.."], ep[5] if wave(t) > 0 else ep[4], "emis", 0.6)
    # yosun + filiz
    for (x, y) in ((16, 33), (17, 33), (13, 34), (14, 34), (15, 34), (27, 36), (28, 37)):
        cv.px(x, y, MOSS)
    cv.px(16, 33, MOSS_L)
    sw = wave(t) * 5
    leaf(cv, 21, 33, 60 + sw, 5, 2.8, LEAF)
    leaf(cv, 21, 33, 125 + sw, 4, 2.4, LEAF)
    # ustunde suzulen isik kalkani
    top = 15 + bob(t)
    leaf_shield(cv, top, f, ep, veins=())
    p2.glyph(cv, CX - 2, top + 3, p2.RUNE5_WARD, ep[5], "front", 0.0)
    p2.particles(cv, t, ep, [(14, 32, 0.0, 1.0), (24, 32, 0.5, 1.0)], 9)
    p2.twinkles(cv, f, ep, [(19, 10, 0), (6, 24, 3), (32, 22, 5)])


def totem_d(kind, f):
    t = f / FRAMES
    cv = Cv()
    p2.mound(cv, 6, 32)
    if kind == "q":
        _fox(cv, f, t)
    else:
        _turtle(cv, f, t)
    fireflies(cv, f, [(3, 40, 1), (35, 44, 5)])
    return cv.render()


DIRECTIONS = [
    ("A", "Kadim Kutuk", totem_a),
    ("B", "Cicek", totem_b),
    ("C", "Mantar", totem_c),
    ("D", "Hayvan Ruhlari (tilki / kaplumbaga)", totem_d),
]


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
    fnt = p2.font(21)
    # 1) yakin sayfa x4 (Q k0, Q k4, E k0, E k4)
    Z = 4
    cw, ch = W * Z, H * Z
    pad, lab = 16, 38
    page = Image.new("RGBA", (pad + 4 * (cw + pad), lab + len(DIRECTIONS) * (ch + lab) + pad), rgba(34, 40, 30))
    d = ImageDraw.Draw(page)
    for r, (key, name, fn) in enumerate(DIRECTIONS):
        y = lab + r * (ch + lab)
        d.text((pad, y - 29), "%s - %s   (Q Saldiri | E Kalkan)" % (key, name), fill=(236, 226, 200), font=fnt)
        for c, (kind, fi) in enumerate((("q", 0), ("q", 4), ("e", 0), ("e", 4))):
            x = pad + c * (cw + pad)
            page.paste(p2.grass_bg(W, H, seed=r * 7 + c).resize((cw, ch), Image.NEAREST), (x, y))
            page.alpha_composite(sheets[(key, kind)][fi].resize((cw, ch), Image.NEAREST), (x, y))
    page.save(os.path.join(OUT, "totem_sayfa.png"))
    # 2) oyun olcegi x2: Shaman + simdiki (oyundaki A) + yeni yonler
    S = 2
    items = [("Shaman", p2.shaman_frame(), 41), ("simdiki Q", p2.totem_a("q", 0), GY), ("simdiki E", p2.totem_a("e", 0), GY)]
    for (key, name, fn) in DIRECTIONS:
        items.append((key + " Q", sheets[(key, "q")][0], GY))
        items.append((key + " E", sheets[(key, "e")][0], GY))
    gap, base = 4, 92
    tot_w = sum(im.width for _, im, _ in items) + gap * (len(items) + 1)
    scene = p2.grass_bg(tot_w, base + 10, seed=3)
    x = gap
    labels = []
    for (nm, im, foot) in items:
        scene.alpha_composite(im, (x, base - foot))
        labels.append((nm, x + im.width // 2))
        x += im.width + gap
    big = scene.resize((scene.width * S, scene.height * S), Image.NEAREST)
    canvas = Image.new("RGBA", (big.width, big.height + 32), rgba(34, 40, 30))
    canvas.paste(big, (0, 0))
    d = ImageDraw.Draw(canvas)
    f2 = p2.font(14)
    for (nm, cx) in labels:
        d.text((cx * S - d.textlength(nm, font=f2) / 2, big.height + 7), nm, fill=(236, 226, 200), font=f2)
    canvas.save(os.path.join(OUT, "totem_oyun.png"))
    # 3) GIF x3
    Z = 3
    n = len(DIRECTIONS) * 2
    gw, gh = n * (W * Z + 6) + 6, H * Z + 12
    bgs = p2.grass_bg(gw // Z + 1, gh // Z + 1, seed=11).resize(((gw // Z + 1) * Z, (gh // Z + 1) * Z), Image.NEAREST).crop((0, 0, gw, gh))
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
