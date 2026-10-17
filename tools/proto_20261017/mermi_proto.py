# -*- coding: utf-8 -*-
"""MERMİ prototipleri (2026-10-17, oyuna bağlı DEĞİL). Kullanıcı: "mermi atışları için (asalar, menzilli silahlar vb) yeni prototip
üretir misin pixel art".

Bugünkü mermiler karışık: ok/mermi/dart 200-250 px'lik yumuşak resimlerin 0,2-0,5 ölçekli hâli (piksel değil, 135-1900 renk), Arcane
32 px kareler x1,8 (karakterden iri piksel), Buz 48x32 x1,1; Fişek zaten Zanaatkâr roketi (madde 198). DİKKAT: weapon.gd _fire_at mermiyi
sahibinin ölçeğiyle (0,5) çarpar -> sahne ölçekleri dünyada yarıya iner. Yeni set TEK yoğunlukta: 1 sanat pikseli = 0,575 dünya px
(weapon_tier_art.gd WORLD_PX, Zanaatkâr silahlarıyla aynı; zoom 2'de 1,15 ekran px - hafif karışık piksel, silahlarda kabul edildi).

Üç yön x 8 mermi (Tabanca, Tüfek, Tüftüf, Yay, Arbalet, Arcane, Buz, Fişek). Ateş Asası (alev püskürtme), Yıldırım (ışın) ve Bumerang
(mermisi silahın kendisi) mermi değil:
  A Zanaatkâr - seçilen silah setinin malzemeleri: kurşun bilye, bakır sivri mermi, bambu dart + pamuk, tahta ok + demir uç, kalın
                arbalet cıvatası (ok ile AYNI değil), ametist kıymığı, buz sarkıtı, kâğıt roket; kısa açık iz
  B Masal     - tombul, yumuşak canlı renk: hardal bilye, kapsül, çiçekli diken, yuvarlak tüylü ok, yıldız uçlu cıvata, dönen yıldız,
                dönen kar tanesi, şeker çubuğu roket; puf / kesik çizgi izleri
  C Işık İzi  - küçük parlak çekirdek ya da koyu silüet + uzun sivrilen ışık izi (hız hissi); büyülerde kuyruklu yıldız
Gövdeler silah motoruyla (asa_proto48 Canvas + silah_proto48 Cv; ışık/dış çizgi/temizlik silahlarla aynı), izler + parçacıklar burada
(Bayer dither, uçlar sivrilir, yarı saydam çok halkalı hale yok).

Çıktılar (out/mermi/): mermi_<A|B|C>_detay.png (kareler x3 + 0/30/60/90 derece dönüş x2), mermi_<A|B|C>_oyun.gif (1080p oyun ölçeği,
50 fps, 2,8 sn döngü; silahlar Zanaatkâr L3), mermi_karsilastirma.png (ŞU AN / A / B / C, uçuşun ortası, 1080p ölçeği).
Çalıştırma: python tools/proto_20261017/mermi_proto.py [A|B|C|kars]   (argümansız: hepsi)
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
P16 = os.path.normpath(os.path.join(HERE, "..", "proto_20261016"))
sys.path.insert(0, P16)
import silah_zanaat_proto as Z  # noqa: E402  (A_* paletleri, line_px, A_fisek)
import silah_stil_proto as ST  # noqa: E402
import silah_proto48 as S  # noqa: E402
from silah_proto48 import Cv, P, hx, E  # noqa: E402

GAME = E.GAME
OUT = os.path.join(HERE, "out", "mermi")
WPP = 0.575  # dünya px / mermi pikseli = weapon_tier_art.gd WORLD_PX (silahlarla aynı); mermi sahnesinde ölçek WPP / 0,5 (sahip ölçeği)
OWNER = 0.5  # weapon.gd _fire_at: proj.scale *= sahip ölçeği
ZOOM = 2.0  # oyun kamerası: 1080p'de 1 dünya px = 2 ekran px
FPS = 50
LOOP = 2.8  # GIF döngüsü (sn)

for _k, _v in {
    "A_lead": "#18181c #303036 #45454c #5c5c64 #76757c #96949a #cac6c0",
    "A_fluff": "#2e2a22 #6e6656 #9a907c #bcb29c #d8d0bc #ece6d6 #fffcf4",
    "A_poison": "#0e200c #1e4a16 #2e6e20 #44922c #64b23c #94d462 #d4f4a8",
    "B_leaf": "#0c2412 #1a4a22 #2a6e30 #3e9040 #5cb050 #8cd070 #d4f4b0",
    "B_ice": "#0e2436 #1e4a6a #3478a0 #5aa6cc #8ccdea #c4ecfa #ffffff",
    "B_lilac": "#2a1636 #5a3a78 #8a5cae #b07cc0 #cc9ed8 #e6c6ee #fff0ff",
    "C_dark": "#120e0c #241c18 #342a24 #463a32 #5a4c42 #706054 #9a8878",
}.items():
    P[_k] = [hx(c) for c in _v.split()]


def cl(s):
    return [hx(c) for c in s.split()]


BAY = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def on(x, y, a):
    return a * 16.0 > BAY[y & 3][x & 3] + 0.5


# ------------------------------------------------------------------ çizim katmanları
LW = 160
H2 = LW // 2


class Lay:
    """Merminin yerel tuvali: pivot (0, 0) = piksel (80, 80); +x uçuş yönü, y aşağı."""

    def __init__(self):
        self.im = Image.new("RGBA", (LW, LW), (0, 0, 0, 0))
        self.p = self.im.load()

    def put(self, x, y, c, a=255):
        X, Y = H2 + x, H2 + y
        if 0 <= X < LW and 0 <= Y < LW:
            self.p[X, Y] = (c[0], c[1], c[2], a)

    def get(self, x, y):
        X, Y = H2 + x, H2 + y
        return self.p[X, Y] if 0 <= X < LW and 0 <= Y < LW else (0, 0, 0, 0)


def streak(L, x0, n, w0, w1, cols, a0=1.0, a1=0.15, ph=0, yc=0.0, wave=None, clip=None, core=None, solid=0.4):
    """x0'dan geriye (sola) n piksellik DOLU, sivrilen iz (ilk turdaki Bayer kenarlı iz noktalı çizgi gibi okunuyordu - madde 1 px
    noktalı = yabancı kuralı). hw = yarı kalınlık: |dy| < hw + 0,5 olan satırlar (0,5 -> 1 px, 1,0 -> 3 px, 2,0 -> 5 px); dış satırlar
    bir ton koyu. İlk 'solid' oranı tam opak, sonrası a0 -> a1 Bayer ile kırıntılanarak söner. cols yakından uzağa.
    core=(renk, uzunluk): ilk 'uzunluk' pikselde orta satır bu renk (sıcak çekirdek). clip = namludan uzaklık (iz namlunun gerisine
    taşmaz - oyundaki "launch" uzaması)."""
    nc = len(cols)
    for i in range(n):
        x = x0 - i
        if clip is not None and -x > clip:
            break
        t = i / max(1, n - 1)
        hw = w0 + (w1 - w0) * t
        yy = yc + (wave(t, i) if wave else 0.0)
        if hw < 1.0:
            yy = float(round(yy))
        a = 1.0 if t < solid else a0 + (a1 - a0) * (t - solid) / (1.0 - solid)
        ci = min(nc - 1, int(t * nc))
        for y in range(math.floor(yy - hw - 1), math.ceil(yy + hw + 1) + 1):
            dy = abs(y - yy)
            if dy >= hw + 0.5:
                continue
            edge = hw >= 1.0 and dy >= hw - 0.5
            aa = a * (0.7 if edge else 1.0)
            if aa >= 1.0 or on(x + ph, y, aa):
                c = core[0] if core and i < core[1] and dy < 0.5 else cols[min(nc - 1, ci + (1 if edge else 0))]
                L.put(x, y, c)


def dashes(L, x0, n, y, dash, gap, ph, cols, a0=0.9, a1=0.2, clip=None):
    """Kesik hız çizgisi (B): yakından uzağa solar."""
    for i in range(n):
        x = x0 - i
        if clip is not None and -x > clip:
            break
        if (i + ph) % (dash + gap) < dash:
            t = i / max(1, n - 1)
            if on(x, y, a0 + (a1 - a0) * t):
                L.put(x, y, cols[min(len(cols) - 1, int(t * len(cols)))])


def puff(L, cx, cy, r, fill, ol, hi=None):
    """Dış çizgili tombul puf (B). Uzaktan yakına çiz -> yakındaki dolgu uzağın çizgisini örter, tek dış çizgi kalır."""
    R = int(math.ceil(r)) + 1
    for dy in range(-R, R + 1):
        for dx in range(-R, R + 1):
            d = math.hypot(dx, dy)
            if d <= r:
                L.put(cx + dx, cy + dy, hi if hi and dx + dy <= -r * 0.6 and d > r * 0.35 else fill)
            elif d <= r + 1.0 and L.get(cx + dx, cy + dy)[3] == 0:
                L.put(cx + dx, cy + dy, ol)


def ring(L, cx, cy, r, col):
    R = int(math.ceil(r)) + 1
    for dy in range(-R, R + 1):
        for dx in range(-R, R + 1):
            if abs(math.hypot(dx, dy) - r) < 0.5:
                L.put(cx + dx, cy + dy, col)


def core(L, rx, ry, cols, x0=0, y0=0, soft=0.45):
    """Dış çizgisiz parlak çekirdek (C): elips, merkez en açık (cols koyudan açığa), 1 px yumuşak kenar."""
    R = int(math.ceil(max(rx, ry))) + 2
    for dy in range(-R, R + 1):
        for dx in range(-R, R + 1):
            d = math.hypot(dx / rx, dy / ry)
            if d <= 1.0:
                L.put(x0 + dx, y0 + dy, cols[len(cols) - 1 - min(len(cols) - 1, int(d * len(cols)))])
            elif d <= 1.0 + 1.1 / max(rx, ry) and on(x0 + dx, y0 + dy, soft):
                L.put(x0 + dx, y0 + dy, cols[0])


def frame_c():
    """Piksel merkezli yatay çerçeve: (a, b) = (0, 0) piksel (24, 24)'ün ORTASI; a = uçuş yönü (sağ), b aşağı."""
    def xy(a, b):
        return (24.5 + a, 24.5 + b)

    def ab(qx, qy):
        return (qx - 24.5, qy - 24.5)

    E.xy, E.ab = xy, ab


def body(fn, f):
    frame_c()
    c = Cv(3)
    fn(c, f)
    return c.render()


# ================================================================== A - ZANAATKÂR
SMOKE = cl("#efe4c8 #ddd0b0 #c4b896 #a89e84")
IVORY = cl("#fbf3e2 #ece0c6 #d4c8ae")
SPARK = cl("#fff6c8 #fdd85a #f9ab2c #d24618")
GREY = cl("#e8e2d6 #c8c2b6 #a8a296 #8a857c")
VIO = cl("#f2e6fc #d8b8f4 #b48ee0 #8a64bc")
FROST = cl("#ffffff #e0f4fc #b4dcec #88bcd4")
POIS = cl("#d8f4b0 #a8dc84 #7cb860 #5a9a44")


def bA_tabanca(c, f):
    c.sphere((0, 0), 3.4, "A_lead", shine=0.5)


def bA_tufek(c, f):
    def cannel(idx, a, b, x, y, s, v):
        return max(1, idx - 1) if -4.6 <= a <= -3.4 else idx

    c.tube([(-7.0, 0), (2.0, 0)], 2.2, "A_copper", shine=0.4, tex=cannel)
    c.tube([(2.0, 0), (8.0, 0)], (2.2, 0.7), "A_copper", shine=0.45, sep=False)


def bA_tuftuf(c, f):
    def fluff(idx, a, b, x, y, d):  # pamuk lifleri: seyrek açık/koyu benek
        h = S.hsh(x, y, 7)
        return idx + 1 if h > 0.78 else (idx - 1 if h < 0.12 else idx)

    c.plate([(-5.0, -0.6), (-9.0, -2.0), (-12.6, -2.6), (-13.2, 0.0), (-12.6, 2.6), (-9.0, 2.0), (-5.0, 0.6)], "A_fluff", bevel=1.3, shine=0.1,
            tex=fluff)
    c.tube([(-6.0, 0), (3.0, 0)], 0.6, "A_bamboo", shine=0.3)
    Z.line_px(c, [(3.0, 0), (7.0, 0)], "A_steel", 5)
    Z.line_px(c, [(8.0, 0), (11.0, 0)], "A_poison", 5)
    c.dot(9.0, 1.0, "A_poison", 4, emis=False)


def bA_yay(c, f):
    Z.line_px(c, [(-9.0, 0), (7.0, 0)], "A_wood", 4)
    c.gem(S.spike((6.5, 0), (12.0, 0), 1.8, shoulder=0.35, wb=0.6), "A_iron", emis=False)

    def band(idx, a, b, x, y, d):
        return P["A_cloth"][max(1, min(6, idx))] if -7.6 <= a <= -6.6 else idx

    for sg in (-1, 1):
        c.plate([(-4.5, sg * 0.5), (-6.5, sg * 2.4), (-10.0, sg * 2.6), (-10.5, sg * 0.5)], "A_fluff", bevel=0.9, shine=0.1, tex=band, sep=False)
    c.tube([(-11.5, 0), (-10.5, 0)], 0.8, "A_wood", shine=0.3)


def bA_arbalet(c, f):
    c.tube([(-8.0, 0), (5.0, 0)], 1.25, "A_wood", shine=0.3, tex=E.grain)
    for sg in (-1, 1):
        c.plate([(-4.0, sg * 1.5), (-5.8, sg * 3.4), (-8.6, sg * 3.4), (-8.6, sg * 1.5)], "A_leather", bevel=0.8, shine=0.15)
    c.tube([(4.0, 0), (5.0, 0)], 1.7, "A_brass", shine=0.45)
    c.gem(S.spike((5.2, 0), (10.5, 0), 2.6, shoulder=0.25, wb=1.6), "A_iron", emis=False)


def bA_arcane(c, f):
    cb = (-2.0, -0.7, 0.7, 2.0)[f % 4]
    poly = [(13.8, 0), (4.4, -5.2), (-5.8, -4.4), (-12.3, 0), (-5.8, 4.4), (4.4, 5.2)]
    c.gem(poly, "A_amethyst", center=(1.4, cb), steep=0.9, shine=0.4, emis=True)
    c.halo("A_amethyst")


def bA_buz(c, f):
    c.gem(S.spike((-7.0, -1.6), (-15.0, -4.9), 1.6, shoulder=0.4), "A_ice", emis=False)
    c.gem(S.spike((-7.0, 1.6), (-13.5, 4.6), 1.5, shoulder=0.4), "A_ice", emis=False)
    c.gem(S.spike((-9.5, 0), (15.0, 0), 3.6, shoulder=0.28, wb=2.7), "A_ice", emis=False, shine=0.4)
    c.glint((-4.0, 1.0, 6.0, 11.0)[f % 4], -1.0, "A_ice", 6)


def bA_fisek(c, f):
    ln = (5.0, 6.6, 5.6)[f % 3]
    base = -7.8
    fo = [(base - u * ln, v * 2.5) for u, v in S.F1]
    c.layers([fo, S.scale_poly(fo, base - ln * 0.15, 0, 0.66), S.scale_poly(fo, base, 0, 0.3)], "A_fire", (3, 4, 5))
    Z.A_fisek(c, 3)


def tA_tabanca(L, f, clip):
    streak(L, -4, 22, 2.0, 0.5, SMOKE, a0=0.9, a1=0.1, ph=2 * f, clip=clip)


def tA_tufek(L, f, clip):
    streak(L, -9, 40, 2.0, 0.5, cl("#fff4c4 #f4dc8c #e0c070 #c0a060"), a0=0.9, a1=0.1, ph=2 * f, clip=clip, core=(hx("#ffffff"), 8))


def tA_tuftuf(L, f, clip):
    streak(L, -14, 14, 1.0, 0.5, POIS, a0=0.8, a1=0.1, ph=2 * f, clip=clip)


def tA_yay(L, f, clip):
    streak(L, -12, 20, 1.0, 0.5, IVORY, a0=0.85, a1=0.1, ph=2 * f, clip=clip)


def tA_arbalet(L, f, clip):
    streak(L, -10, 18, 1.5, 0.5, IVORY, a0=0.85, a1=0.1, ph=2 * f, clip=clip)


def tA_arcane(L, f, clip):
    streak(L, -12, 20, 2.0, 0.5, VIO, a0=0.8, a1=0.1, ph=2 * f, clip=clip)


def tA_buz(L, f, clip):
    streak(L, -14, 22, 2.0, 0.5, FROST, a0=0.8, a1=0.1, ph=2 * f, clip=clip)


def tA_fisek(L, f, clip):
    streak(L, -22, 12, 1.0, 2.0, GREY, a0=0.6, a1=0.05, ph=2 * f, clip=clip, solid=0.2)


# ================================================================== B - MASAL
CREAM = cl("#fffaf0 #ece0c4 #d4c6a6")
B_OL = hx("#94846a")


def bB_tabanca(c, f):
    c.sphere((0, 0), 4.2, "B_mustard", shine=0.55)


def bB_tufek(c, f):
    c.tube([(-7.0, 0), (3.0, 0)], 2.8, "B_teal", shine=0.5)
    c.tube([(3.0, 0), (7.5, 0)], (2.8, 1.2), "B_coral", shine=0.5)


def bB_tuftuf(c, f):
    c.gem(S.spike((-3.0, 0), (12.0, 0), 2.0, shoulder=0.12, wb=1.5), "B_leaf", emis=False)
    th0 = f * math.pi / 5
    for i in range(5):
        th = th0 + i * 2 * math.pi / 5
        c.sphere((-6.0 + 2.6 * math.cos(th), 2.6 * math.sin(th)), 1.8, "B_coral", shine=0.3, sep=False)
    c.sphere((-6.0, 0), 1.5, "B_mustard", shine=0.5)


def bB_yay(c, f):
    Z.line_px(c, [(-9.0, 0), (7.0, 0)], "B_wood", 4)
    c.gem(S.spike((6.5, 0), (12.0, 0), 2.1, shoulder=0.45, wb=0.8), "B_iron", emis=False)
    for sg, mat in ((-1, "B_coral"), (1, "B_teal")):
        poly = [(-4.5, sg * 0.5)] + [(-8.0 + 3.4 * math.cos(t), sg * (0.5 + 2.7 * math.sin(t)))
                                     for t in [math.pi * i / 10.0 for i in range(11)]] + [(-11.4, sg * 0.5)]
        c.plate(poly, mat, bevel=1.0, shine=0.3)


def bB_arbalet(c, f):
    c.tube([(-7.0, 0), (4.0, 0)], 1.3, "B_plum", shine=0.4)
    for sg in (-1, 1):
        c.plate([(-3.5, sg * 1.5), (-6.0, sg * 3.7), (-8.2, sg * 3.5), (-7.6, sg * 1.5)], "B_mustard", bevel=0.9, shine=0.3)
    c.plate(ST.star_poly(7.0, 0.0, 4.4, 1.9, n=5, rot=f * math.pi / 5), "B_star", bevel=1.1, shine=0.4)


def bB_arcane(c, f):
    rot = f * math.pi / 8
    c.plate(ST.star_poly(0.0, 0.0, 11.0, 3.8, n=4, rot=rot), "B_lilac", bevel=1.8, shine=0.3, flat_bias=1)
    c.halo("B_lilac")
    c.plate(ST.star_poly(0.0, 0.0, 6.4, 2.4, n=4, rot=rot), "B_cream", bevel=1.1, shine=0.4, flat_bias=1)


def bB_buz(c, f):
    rot = f * math.pi / 12
    for k in range(6):
        th = rot + k * math.pi / 3
        ca, sa = math.cos(th), math.sin(th)
        Z.line_px(c, [(ca * 2.0, sa * 2.0), (ca * 9.5, sa * 9.5)], "B_ice", 5)
        for s in (-1, 1):
            t2 = th + s * math.pi / 4
            for r0, ln in ((5.6, 2.9), (3.6, 1.8)):
                Z.line_px(c, [(ca * r0, sa * r0), (ca * r0 + math.cos(t2) * ln, sa * r0 + math.sin(t2) * ln)], "B_ice", 6)
    c.sphere((0, 0), 2.4, "B_ice", shine=0.5)


def bB_fisek(c, f):
    fl = (4.5, 6.0, 5.2)[f % 3]
    base = -7.5
    fo = [(base - u * fl, v * 2.6) for u, v in S.F1]
    c.layers([fo, S.scale_poly(fo, base - fl * 0.15, 0, 0.66), S.scale_poly(fo, base, 0, 0.3)], "B_fire", (3, 4, 5))
    for sg in (-1, 1):
        c.plate([(-2.5, sg * 2.0), (-6.0, sg * 5.0), (-8.0, sg * 5.0), (-7.0, sg * 2.0)], "B_teal", bevel=1.0, shine=0.35)

    def candy(idx, a, b, x, y, s, v):
        return P["B_cream"][max(1, min(6, idx))] if ((a - b * 0.7) % 4.0) < 2.0 else idx

    c.tube([(-6.5, 0), (6.0, 0)], 2.6, "B_coral", shine=0.45, tex=candy)
    c.tube([(6.0, 0), (10.5, 0)], (2.6, 0.7), "B_mustard", shine=0.5)


def tB_tabanca(L, f, clip):
    for x, r in ((-19, 1.4), (-13, 2.2), (-8, 3.0)):
        if -(x - r) <= (clip if clip is not None else 999):
            puff(L, x - f, 0, r + (0.3 if f else 0.0) * (r > 1.5), CREAM[1], B_OL, CREAM[0])


def tB_tufek(L, f, clip):
    streak(L, -9, 36, 1.0, 0.5, cl("#fffaf0 #c4f0e4 #70c8bc #44aaa4"), a0=0.9, a1=0.15, clip=clip,
           wave=lambda t, i: 1.6 * t * math.sin(i * 0.42 + f * math.pi))


def tB_tuftuf(L, f, clip):
    for x, y, r in ((-12, -1, 1.5), (-17, 1, 2.0), (-22, -1, 1.5)):
        if -(x - r) <= (clip if clip is not None else 999):
            ring(L, x - f, y, r, hx("#d4f4b0"))


def tB_yay(L, f, clip):
    for y in (-2, 2):
        dashes(L, -12, 20, y, 4, 2, f * 2, CREAM, clip=clip)


def tB_arbalet(L, f, clip):
    for y in (-2, 0, 2):
        dashes(L, -9, 14 if y else 18, y * 2, 4, 2, f * 2 + (1 if y else 0), CREAM, clip=clip)


def tB_fisek(L, f, clip):
    pass


# ================================================================== C - IŞIK İZİ
AMB = cl("#fff8e0 #ffe08a #f8b840 #e88a1c #b8600c")  # açıktan koyuya (iz)
GOLD = cl("#ffffff #fff4b0 #f8e070 #e8c03a #b8901c")
GRN = cl("#f0fff0 #b8f8a8 #74e070 #3cbc48 #208c30")
WIND = cl("#fffaf0 #f0e2c4 #dccaa8 #b8a888")
VIOC = cl("#fff0ff #dab0ff #b278f4 #8c46d8 #6428a8")
CYAN = cl("#ffffff #b4f0ff #6cd2f0 #34acd4 #1a80a8")


def rev(cols):
    return list(reversed(cols))


def lC_tabanca(L, f, clip):
    streak(L, -3, 28, 1.5, 0.5, AMB, a0=1.0, a1=0.15, ph=2 * f, clip=clip, core=(hx("#ffffff"), 6))
    core(L, 3.2, 2.2, rev(AMB))


def lC_tufek(L, f, clip):
    streak(L, -5, 52, 1.5, 0.5, GOLD, a0=1.0, a1=0.1, ph=2 * f, clip=clip, core=(hx("#ffffff"), 14))
    core(L, 5.0, 1.6, rev(GOLD))


def lC_tuftuf(L, f, clip):
    streak(L, -7, 22, 1.0, 0.5, GRN, a0=0.9, a1=0.1, ph=2 * f, clip=clip)
    for x in range(-6, 9):
        L.put(x, 0, GRN[0] if x >= 5 else GRN[2])
    for x, y in ((-7, -1), (-7, 1), (-8, 0), (-8, -2), (-8, 2), (-9, -1), (-9, 1)):
        L.put(x, y, hx("#fffaf0"))


def bC_yay(c, f):
    Z.line_px(c, [(-9.0, 0), (7.0, 0)], "C_dark", 4)
    c.gem(S.spike((6.5, 0), (11.5, 0), 1.5, shoulder=0.35, wb=0.6), "C_dark", emis=False)
    for sg in (-1, 1):
        c.plate([(-5.5, sg * 0.5), (-7.0, sg * 2.1), (-9.8, sg * 2.1), (-9.8, sg * 0.5)], "C_dark", bevel=0.6, shine=0.1)
    c.glint(9.5, -1.0, "A_steel", 6)


def bC_arbalet(c, f):
    c.tube([(-7.0, 0), (4.0, 0)], 1.25, "C_dark", shine=0.3)
    for sg in (-1, 1):
        c.plate([(-4.0, sg * 1.5), (-5.4, sg * 3.0), (-7.6, sg * 3.0), (-7.6, sg * 1.5)], "C_dark", bevel=0.6)
    c.gem(S.spike((4.0, 0), (9.0, 0), 2.2, shoulder=0.25, wb=1.3), "C_dark", emis=False)
    c.glint(7.0, -1.0, "A_fire", 5)


def lC_yay(L, f, clip):
    streak(L, -10, 32, 1.5, 0.5, WIND, a0=0.85, a1=0.1, ph=2 * f, clip=clip)


def lC_arbalet(L, f, clip):
    streak(L, -8, 30, 2.0, 0.5, cl("#fffaf0 #f8dcb0 #e8b880 #c89060"), a0=0.9, a1=0.1, ph=2 * f, clip=clip)


def lC_arcane(L, f, clip):
    for s in (1, -1):
        streak(L, -5, 38, 0.5, 0.5, VIOC[1:], a0=0.95, a1=0.15, clip=clip,
               wave=lambda t, i, s=s: s * 4.4 * math.sin(i * 0.34 - f * math.pi / 2) * min(1.0, i / 6.0))
    streak(L, -5, 18, 2.0, 0.5, VIOC, a0=0.6, a1=0.1, ph=f, clip=clip)
    core(L, 5.8, 5.8, rev(VIOC))
    th = f * math.pi / 2
    for k in (0, 1):
        x, y = round(9.0 * math.cos(th + k * math.pi)), round(5.6 * math.sin(th + k * math.pi))
        L.put(x, y, VIOC[0])


def lC_buz(L, f, clip):
    streak(L, -7, 34, 3.0, 0.5, CYAN[1:], a0=0.8, a1=0.05, ph=2 * f, clip=clip)
    for y in range(-5, 6):
        for x in range(-8, 13):
            d = abs(y) / 5.0 + (x / 12.5 if x > 0 else -x / 8.5)
            if d <= 1.0:
                L.put(x, y, CYAN[min(4, int(d * 4.6))] if d > 0.25 else CYAN[0])
    L.put(13, 0, CYAN[0])
    L.put((-3, 1, 5, 9)[f % 4], -2, hx("#ffffff"))


def lC_fisek(L, f, clip):
    streak(L, -3, 36, 2.0, 0.5, cl("#fff6c8 #fdd85a #f9ab2c #e06a16 #a8340e"), a0=0.9, a1=0.05, ph=2 * f, clip=clip,
           wave=lambda t, i: 0.8 * t * math.sin(i * 0.9 + f * 2.1))
    core(L, 3.8, 2.9, cl("#e06a16 #f9ab2c #fdd85a #fff6c8 #ffffff"))


# ------------------------------------------------------------------ parçacıklar (dünyada kalan, ekran px)
class Pt:
    __slots__ = ("x", "y", "vx", "vy", "g", "age", "life", "kind", "cols", "r0", "r1", "ol")

    def __init__(self, x, y, vx, vy, life, kind, cols, g=0.0, r0=1.0, r1=1.0, ol=None):
        self.x, self.y, self.vx, self.vy, self.g = x, y, vx, vy, g
        self.age, self.life, self.kind, self.cols, self.r0, self.r1, self.ol = 0.0, life, kind, cols, r0, r1, ol


def PS(kind, cols, n=1, every=0.0, life=(0.3, 0.5), v=(0.0, 0.0), aim="iso", spread=math.pi, drift=(0.0, 0.0), g=0.0, r=(1.0, 1.0),
       jit=0.0, back=0.0, ol=None):
    return dict(kind=kind, cols=cols, n=n, every=every, life=life, v=v, aim=aim, spread=spread, drift=drift, g=g, r=r, jit=jit, back=back, ol=ol)


def spawn(ps, x, y, dx, dy, rng, out, n=None):
    for _ in range(ps["n"] if n is None else n):
        if ps["aim"] == "iso":
            th = rng.uniform(0.0, 2.0 * math.pi)
        else:
            base = math.atan2(dy, dx) + (math.pi if ps["aim"] == "back" else 0.0)
            th = base + rng.uniform(-ps["spread"] / 2.0, ps["spread"] / 2.0)
        sp = rng.uniform(*ps["v"])
        j = rng.uniform(-ps["jit"], ps["jit"])
        px = x - dx * ps["back"] - dy * j
        py = y - dy * ps["back"] + dx * j
        out.append(Pt(px, py, math.cos(th) * sp + ps["drift"][0], math.sin(th) * sp + ps["drift"][1], rng.uniform(*ps["life"]),
                      ps["kind"], ps["cols"], ps["g"], ps["r"][0], ps["r"][1], ps["ol"]))


def draw_pts(img, pts):
    px = img.load()
    W, H = img.size

    def put(x, y, c, a=1.0):
        if 0 <= x < W and 0 <= y < H and on(x, y, a):
            px[x, y] = c

    for p in pts:  # dış çizgiler önce (B pufları birleşik bulut olsun)
        if p.kind == "opuff" and p.ol:
            k = min(1.0, p.age / p.life)
            r = p.r0 + (p.r1 - p.r0) * k
            x0, y0 = int(math.floor(p.x)), int(math.floor(p.y))
            R = int(math.ceil(r)) + 1
            for dy in range(-R, R + 1):
                for dx in range(-R, R + 1):
                    if r < math.hypot(dx, dy) <= r + 1.0:
                        put(x0 + dx, y0 + dy, p.ol)
    for p in pts:
        k = min(1.0, p.age / p.life)
        n = len(p.cols)
        ci = min(n - 1, int(k * n))
        col = p.cols[ci]
        a = 1.0 - k * k
        x0, y0 = int(math.floor(p.x)), int(math.floor(p.y))
        kind = p.kind
        if kind == "dot":
            put(x0, y0, col, a)
        elif kind == "plus":
            put(x0, y0, col)
            if k < 0.55:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    put(x0 + dx, y0 + dy, p.cols[min(n - 1, ci + 1)], a)
        elif kind == "star":
            arm = 2 if k < 0.35 else (1 if k < 0.7 else 0)
            put(x0, y0, col)
            for s in range(1, arm + 1):
                cc = p.cols[min(n - 1, ci + s)]
                for dx, dy in ((s, 0), (-s, 0), (0, s), (0, -s)):
                    put(x0 + dx, y0 + dy, cc)
        elif kind in ("puff", "opuff"):
            r = p.r0 + (p.r1 - p.r0) * k
            R = int(math.ceil(r)) + 1
            for dy in range(-R, R + 1):
                for dx in range(-R, R + 1):
                    if math.hypot(dx, dy) <= r:
                        put(x0 + dx, y0 + dy, col, a * 0.85 if kind == "puff" else 1.0)
        elif kind == "drop":
            put(x0, y0, col)
            put(x0, y0 - 1, p.cols[0], a)


def step_pts(pts, dt):
    keep = []
    for p in pts:
        p.age += dt
        if p.age < p.life:
            p.vy += p.g * dt
            p.x += p.vx * dt
            p.y += p.vy * dt
            keep.append(p)
    return keep


# ------------------------------------------------------------------ yön tabloları
KEYS = [("tabanca", "Tabanca", "horiz"), ("tufek", "Tüfek", "horiz"), ("tuftuf", "Tüftüf", "diag"), ("yay", "Yay", "vert"),
        ("crossbow", "Arbalet", "diag"), ("arcane", "Arcane Asası", "diag"), ("buz_asasi", "Buz Asası", "diag"), ("fisek", "Fişek", "diag")]
SPEED = {"tabanca": 400, "tufek": 650, "tuftuf": 460, "yay": 620, "crossbow": 620, "arcane": 400, "buz_asasi": 400, "fisek": 0}
RATE = {"tabanca": 0.9, "tufek": 1.3, "tuftuf": 1.4, "yay": 0.77, "crossbow": 0.8, "arcane": 1.4, "buz_asasi": 1.1, "fisek": 3.2}
FISEK_T = 1.15


def M(fn=None, nf=1, afps=12.0, trail=None, pivot=(24, 24), emit=(), muzzle=(), hit=(), local=None):
    return dict(fn=fn, nf=nf, afps=afps, trail=trail, pivot=pivot, emit=list(emit), muzzle=list(muzzle), hit=list(hit), local=local)


SM_PUFF = PS("puff", GREY, n=3, life=(0.35, 0.55), v=(8, 26), aim="fwd", spread=1.6, drift=(0, -14), r=(1.2, 3.2))
SM_SPARK = PS("plus", SPARK, n=2, life=(0.06, 0.12), v=(60, 110), aim="fwd", spread=0.9)
DIRS = {
    "A": dict(title="A - Zanaatkâr", sub="silah setinin malzemeleri, kısa açık iz", m={
        "tabanca": M(bA_tabanca, 2, 25, tA_tabanca, muzzle=[SM_PUFF, SM_SPARK], hit=[PS("dot", GREY, n=4, life=(0.15, 0.3), v=(20, 50))]),
        "tufek": M(bA_tufek, 2, 25, tA_tufek, muzzle=[dict(SM_PUFF, n=4, r=(1.5, 3.8)), dict(SM_SPARK, n=3)],
                   hit=[PS("plus", SPARK, n=3, life=(0.08, 0.16), v=(40, 90))]),
        "tuftuf": M(bA_tuftuf, 2, 25, tA_tuftuf, muzzle=[PS("puff", cl("#f4f0e4 #dcd6c6"), n=2, life=(0.2, 0.3), v=(10, 20), r=(1.0, 2.0))],
                    emit=[PS("drop", POIS, every=20, life=(0.25, 0.4), v=(0, 10), g=160, back=2)],
                    hit=[PS("dot", POIS, n=5, life=(0.2, 0.35), v=(20, 50))]),
        "yay": M(bA_yay, 2, 25, tA_yay, hit=[PS("dot", IVORY, n=3, life=(0.1, 0.2), v=(20, 50))]),
        "crossbow": M(bA_arbalet, 2, 25, tA_arbalet, muzzle=[PS("dot", IVORY, n=3, life=(0.1, 0.2), v=(30, 60), aim="fwd", spread=1.2)],
                      hit=[PS("dot", IVORY, n=4, life=(0.1, 0.2), v=(20, 60))]),
        "arcane": M(bA_arcane, 4, 12, tA_arcane, muzzle=[PS("plus", VIO, n=5, life=(0.15, 0.3), v=(30, 70))],
                    emit=[PS("plus", VIO, every=10, life=(0.12, 0.25), v=(10, 30), jit=4.0, back=8)],
                    hit=[PS("plus", VIO, n=6, life=(0.15, 0.3), v=(30, 80))]),
        "buz_asasi": M(bA_buz, 4, 12, tA_buz, muzzle=[PS("dot", FROST, n=5, life=(0.2, 0.35), v=(20, 50))],
                       emit=[PS("dot", FROST, every=7, life=(0.15, 0.3), v=(6, 20), g=40, jit=4.5, back=10)],
                       hit=[PS("plus", FROST, n=6, life=(0.15, 0.3), v=(30, 70))]),
        "fisek": M(bA_fisek, 3, 15, tA_fisek, pivot=(30, 24), muzzle=[SM_PUFF],
                   emit=[PS("plus", SPARK, every=4, life=(0.18, 0.32), v=(15, 45), g=60, jit=1.5, back=16),
                         PS("puff", GREY, every=7, life=(0.4, 0.6), v=(0, 6), drift=(0, -10), r=(1.4, 3.0), jit=1.0, back=18)],
                   hit=[PS("plus", SPARK, n=14, life=(0.2, 0.45), v=(40, 120), g=40),
                        PS("puff", GREY, n=5, life=(0.4, 0.7), v=(10, 30), drift=(0, -10), r=(2.0, 5.0))]),
    }),
    "B": dict(title="B - Masal", sub="tombul, yumuşak canlı renk, puf ve kesik çizgi izleri", m={
        "tabanca": M(bB_tabanca, 2, 12, tB_tabanca, muzzle=[PS("opuff", CREAM, n=3, life=(0.25, 0.4), v=(15, 35), aim="fwd", spread=1.6,
                                                                  r=(2.6, 0.4), ol=B_OL)],
                     hit=[PS("star", cl("#ffffff #fff09a #fcdc5a #ecc232"), n=3, life=(0.15, 0.25), v=(20, 50))]),
        "tufek": M(bB_tufek, 2, 12, tB_tufek, muzzle=[PS("opuff", CREAM, n=4, life=(0.25, 0.4), v=(15, 40), aim="fwd", spread=1.6,
                                                         r=(3.0, 0.4), ol=B_OL)],
                   hit=[PS("star", cl("#ffffff #c4f0e4 #70c8bc"), n=4, life=(0.15, 0.25), v=(20, 50))]),
        "tuftuf": M(bB_tuftuf, 2, 10, tB_tuftuf, emit=[PS("opuff", cl("#eaffdc #d4f4b0"), every=16, life=(0.25, 0.4), v=(2, 8), drift=(0, -18),
                                                            r=(1.6, 0.3), jit=2.0, back=8, ol=hx("#5cb050"))],
                    hit=[PS("star", cl("#ffffff #d4f4b0 #8cd070"), n=4, life=(0.15, 0.25), v=(20, 50))]),
        "yay": M(bB_yay, 2, 25, tB_yay, hit=[PS("star", cl("#ffffff #fff09a #fcdc5a"), n=3, life=(0.12, 0.22), v=(20, 50))]),
        "crossbow": M(bB_arbalet, 2, 10, tB_arbalet, hit=[PS("star", cl("#ffffff #fff09a #fcdc5a"), n=4, life=(0.12, 0.22), v=(20, 50))]),
        "arcane": M(bB_arcane, 4, 12, None, muzzle=[PS("star", cl("#ffffff #fff09a #e0c0ec #b07cc0"), n=4, life=(0.2, 0.35), v=(30, 60))],
                    emit=[PS("star", cl("#ffffff #fff09a #e0c0ec #b07cc0"), every=12, life=(0.2, 0.35), v=(6, 18), jit=4.0, back=9)],
                    hit=[PS("star", cl("#ffffff #fff09a #e0c0ec #b07cc0"), n=6, life=(0.2, 0.35), v=(30, 70))]),
        "buz_asasi": M(bB_buz, 4, 12, None, muzzle=[PS("opuff", cl("#ffffff #e4f6fc"), n=3, life=(0.25, 0.4), v=(15, 35), r=(2.4, 0.4),
                                                       ol=hx("#8ccdea"))],
                       emit=[PS("opuff", cl("#ffffff #e4f6fc"), every=10, life=(0.2, 0.35), v=(4, 12), g=20, r=(2.4, 0.3), jit=3.0, back=8,
                                ol=hx("#8ccdea")),
                             PS("dot", cl("#ffffff #c4ecfa"), every=13, life=(0.2, 0.35), v=(6, 16), g=30, jit=5.0, back=6)],
                       hit=[PS("star", cl("#ffffff #c4ecfa #8ccdea"), n=5, life=(0.15, 0.3), v=(30, 70))]),
        "fisek": M(bB_fisek, 3, 15, None, pivot=(26, 24), muzzle=[PS("opuff", CREAM, n=3, life=(0.3, 0.45), v=(10, 30), r=(3.0, 0.5), ol=B_OL)],
                   emit=[PS("star", cl("#ffffff #fff09a #fcdc5a #ecc232"), every=6, life=(0.2, 0.4), v=(15, 40), g=50, jit=1.5, back=16),
                         PS("opuff", CREAM, every=8, life=(0.35, 0.55), v=(0, 6), drift=(0, -8), r=(2.6, 0.4), jit=1.0, back=17, ol=B_OL)],
                   hit=[PS("star", cl("#ffffff #fff09a #fcdc5a #ecc232 #ee8a6a"), n=12, life=(0.25, 0.5), v=(40, 110), g=40),
                        PS("opuff", CREAM, n=5, life=(0.35, 0.6), v=(10, 30), r=(4.0, 0.5), ol=B_OL)]),
    }),
    "C": dict(title="C - Işık İzi", sub="parlak çekirdek / koyu silüet + uzun sivrilen ışık izi", m={
        "tabanca": M(None, 2, 25, None, local=lC_tabanca, muzzle=[PS("plus", rev(AMB), n=3, life=(0.05, 0.1), v=(60, 120), aim="fwd", spread=1.0)],
                     hit=[PS("plus", rev(AMB), n=4, life=(0.08, 0.16), v=(40, 90))]),
        "tufek": M(None, 2, 25, None, local=lC_tufek, muzzle=[PS("plus", GOLD, n=4, life=(0.05, 0.1), v=(80, 140), aim="fwd", spread=0.8)],
                   hit=[PS("plus", GOLD, n=5, life=(0.08, 0.16), v=(40, 100))]),
        "tuftuf": M(None, 2, 25, None, local=lC_tuftuf, emit=[PS("drop", GRN[1:], every=12, life=(0.3, 0.45), v=(0, 10), g=160, back=2)],
                    hit=[PS("dot", GRN, n=5, life=(0.2, 0.35), v=(20, 50))]),
        "yay": M(bC_yay, 2, 25, lC_yay, hit=[PS("dot", WIND, n=4, life=(0.1, 0.2), v=(20, 60))]),
        "crossbow": M(bC_arbalet, 2, 25, lC_arbalet, hit=[PS("plus", cl("#fff6c8 #fdd85a #f9ab2c"), n=4, life=(0.08, 0.16), v=(30, 80))]),
        "arcane": M(None, 4, 14, None, local=lC_arcane, muzzle=[PS("plus", VIOC, n=5, life=(0.15, 0.3), v=(30, 70))],
                    emit=[PS("dot", VIOC, every=8, life=(0.12, 0.25), v=(8, 24), jit=4.5, back=12)],
                    hit=[PS("plus", VIOC, n=7, life=(0.15, 0.3), v=(30, 90))]),
        "buz_asasi": M(None, 4, 12, None, local=lC_buz, muzzle=[PS("dot", CYAN, n=5, life=(0.2, 0.35), v=(20, 50))],
                       emit=[PS("plus", CYAN, every=11, life=(0.15, 0.3), v=(6, 18), g=30, jit=4.5, back=14)],
                       hit=[PS("plus", CYAN, n=7, life=(0.15, 0.3), v=(30, 80))]),
        "fisek": M(None, 3, 15, None, local=lC_fisek, muzzle=[SM_PUFF],
                   emit=[PS("plus", SPARK, every=3, life=(0.25, 0.45), v=(10, 35), g=70, jit=2.0, back=8),
                         PS("dot", SPARK, every=2, life=(0.3, 0.6), v=(5, 20), g=50, jit=2.5, back=14)],
                   hit=[PS("plus", SPARK, n=16, life=(0.25, 0.5), v=(40, 130), g=40),
                        PS("puff", GREY, n=4, life=(0.4, 0.7), v=(10, 30), drift=(0, -10), r=(2.0, 5.0))]),
    }),
}

_BODY = {}


def local_sprite(m, f, clip, did, key):
    """Yerel tuval: iz (arkada) + gövde. clip = namludan uzaklık (ekran px = mermi pikseli)."""
    L = Lay()
    if m["trail"]:
        m["trail"](L, f, clip)
    if m["local"]:
        m["local"](L, f, clip)
    if m["fn"]:
        k = (did, key, f)
        if k not in _BODY:
            _BODY[k] = body(m["fn"], f)
        px, py = m["pivot"]
        L.im.alpha_composite(_BODY[k], (H2 - px, H2 - py))
    return L.im


def crop_sym(im):
    """Pivotu (80, 80) merkezde tutarak saydam kenarları kırp (blit_world kaynağın ortasını pivot alır)."""
    bb = im.getchannel("A").getbbox()
    if bb is None:
        return Image.new("RGBA", (2, 2), (0, 0, 0, 0))
    h = max(H2 - bb[0], bb[2] - H2, H2 - bb[1], bb[3] - H2) + 1
    return im.crop((H2 - h, H2 - h, H2 + h, H2 + h))


def paste_local(dst, im, x, y, rot=0.0):
    """Yerel sprite'ı dünyaya koy: (x, y) pivotun ekran konumu, 1 mermi pikseli = WPP x ZOOM ekran px (NEAREST, oyundaki gibi
    hafif karışık piksel). rot != 0 -> Godot NEAREST döndürme taklidi (blit_world)."""
    sq = crop_sym(im)
    if abs(rot) < 1e-4:
        n = max(1, int(round(sq.width * WPP * ZOOM)))
        r = sq.resize((n, n), Image.NEAREST)
        dst.paste(r, (int(round(x - n / 2.0)), int(round(y - n / 2.0))), r)
    else:
        E.blit_world(dst, sq, int(round(x)) + 0.5, int(round(y)) + 0.5, WPP, ZOOM, rot)


# ------------------------------------------------------------------ sahne
CHAR_K = 2.2368375 * 0.8075 * 0.5  # Elara dünya px / karakter pikseli
SLIME_K = 0.94905
LANE_W, LANE_H, ARC_H, HEAD_H = 470, 72, 112, 34
G0, G1, G2 = (108, 152, 88), (118, 160, 94), (98, 141, 82)
D0, D1 = (146, 131, 98), (128, 114, 86)


def grass(w, h, seed):
    """Çimen (dünya çözünürlüğünde lekeli, x2 = 2 ekran px'lik doku) + ortadan geçen toprak yol."""
    rng = random.Random(seed)
    W, Hh = w // 2 + 1, h // 2 + 1
    im = Image.new("RGB", (W, Hh), G0)
    d = ImageDraw.Draw(im)
    for _ in range(W * Hh // 160):
        x, y, r = rng.randrange(W), rng.randrange(Hh), rng.randint(3, 8)
        d.ellipse((x - r, y - r * 0.6, x + r, y + r * 0.6), fill=rng.choice([G1, G2]))
    px = im.load()
    for y in range(Hh):
        e0 = 112 + int(3 * math.sin(y * 0.31 + seed)) + rng.randint(0, 1)
        e1 = 136 + int(3 * math.sin(y * 0.27 + seed * 2)) + rng.randint(0, 1)
        for x in range(e0, min(W, e1)):
            px[x, y] = D1 if rng.random() < 0.12 else D0
    for _ in range(W * Hh // 60):
        x, y = rng.randrange(W), rng.randrange(Hh)
        if px[x, y] in (G0, G1, G2):
            px[x, y] = (88, 128, 74)
    return im.resize((W * 2, Hh * 2), Image.NEAREST).crop((0, 0, w, h))


_ASSET = {}


def asset(path, box=None):
    k = (path, box)
    if k not in _ASSET:
        im = Image.open(os.path.join(GAME, path)).convert("RGBA")
        _ASSET[k] = im.crop(box) if box else im
    return _ASSET[k]


def weapon_icon(key):
    return asset("assets/weapons/zanaat/%s_L3.png" % key)


def lane_static(key, kind, idx):
    """Bir şerit: çimen + Elara + silah (Zanaatkâr L3, sağa nişan) + slime. Dönüş: (resim, namlu, hedef)."""
    h = ARC_H if key == "fisek" else LANE_H
    im = grass(LANE_W, h, 11 + idx)
    cy = h - LANE_H // 2 if key == "fisek" else h // 2
    E.blit_world(im, asset("assets/characters/elara/sheets/idle.png", (0, 0, 48, 48)), 40, cy - 1, CHAR_K, ZOOM)
    wi = weapon_icon(key)
    rot = math.pi / 4 if kind == "diag" else 0.0
    wx, wy = 88, cy + 4
    E.blit_world(im, wi, wx, wy, WPP, ZOOM, rot)  # silah da WORLD_PX 0,575
    # namlu: döndürülmüş ikonun en sağdaki opak pikseli
    best = None
    pa = wi.load()
    cs, sn = math.cos(rot), math.sin(rot)
    for y in range(48):
        for x in range(48):
            if pa[x, y][3] > 0:
                sx, sy = (x + 0.5 - 24) * WPP * ZOOM, (y + 0.5 - 24) * WPP * ZOOM
                dx, dy = cs * sx - sn * sy, sn * sx + cs * sy
                if best is None or dx > best[0]:
                    best = (dx, dy)
    mx, my = (wx + 4, wy) if key == "yay" else (wx + best[0] + 2, wy + best[1])
    tx = mx + 300
    E.blit_world(im, asset("visuals/Yaratıklar/Tüm Yaratıklar/Slime 1/PNG/Slime1/With_shadow/Slime1_Walk_with_shadow.png", (0, 0, 64, 64)),
                 tx + 10, my - 6, SLIME_K, ZOOM)
    return im, (mx, my), (tx, my)


def label(d, x, y, s, size=11, col=(240, 234, 218)):
    f = E.font(size, True)
    d.text((x + 1, y + 1), s, fill=(24, 28, 22), font=f)
    d.text((x, y), s, fill=col, font=f)


def bez(p0, p1, p2, t):
    u = 1.0 - t
    return (u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0], u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1])


def bez_d(p0, p1, p2, t):
    return (2 * (1 - t) * (p1[0] - p0[0]) + 2 * t * (p2[0] - p1[0]), 2 * (1 - t) * (p1[1] - p0[1]) + 2 * t * (p2[1] - p1[1]))


class LaneSim:
    """Tek şeridin zamanı: atış takvimi, uçan mermiler, dünyada kalan parçacıklar."""

    def __init__(self, did, key, kind, idx, interval, offset):
        self.did, self.key, self.m = did, key, DIRS[did]["m"][key]
        self.bg, self.mz, self.tg = lane_static(key, kind, idx)
        self.interval, self.next = interval, offset
        self.rng = random.Random(idx * 97 + ord(did))
        self.shots, self.pts = [], []
        if key == "fisek":
            self.arc = (self.mz, ((self.mz[0] + self.tg[0]) / 2.0, 6.0), (self.tg[0] + 4, self.tg[1] - 2))

    def pos(self, s):
        """s = atıştan beri geçen süre -> (x, y, dx, dy, yol, bitti)."""
        if self.key == "fisek":
            t = min(1.0, s / FISEK_T)
            x, y = bez(*self.arc, t)
            dx, dy = bez_d(*self.arc, t)
            l = math.hypot(dx, dy) or 1.0
            return x, y, dx / l, dy / l, t * 400.0, t >= 1.0
        d = SPEED[self.key] * ZOOM * s
        D = self.tg[0] - self.mz[0]
        return self.mz[0] + min(d, D), self.mz[1], 1.0, 0.0, d, d >= D

    def fire(self, t):
        self.shots.append(dict(t0=t, acc=[0.0] * len(self.m["emit"]), last=0.0))
        x, y, dx, dy, _, _ = self.pos(0.0)
        for ps in self.m["muzzle"]:
            spawn(ps, x, y, dx, dy, self.rng, self.pts)

    def step(self, t, dt):
        while t >= self.next:
            self.fire(self.next)
            self.next += self.interval
        keep = []
        for sh in self.shots:
            x, y, dx, dy, trav, done = self.pos(t - sh["t0"])
            dd = trav - sh["last"]
            sh["last"] = trav
            for i, ps in enumerate(self.m["emit"]):
                sh["acc"][i] += dd
                while sh["acc"][i] >= ps["every"]:
                    sh["acc"][i] -= ps["every"] * self.rng.uniform(0.6, 1.4)
                    spawn(ps, x, y, dx, dy, self.rng, self.pts)
            if done:
                for ps in self.m["hit"]:
                    spawn(ps, x, y, dx, dy, self.rng, self.pts)
            else:
                keep.append(sh)
        self.shots = keep
        self.pts = step_pts(self.pts, dt)

    def render(self, t):
        im = self.bg.copy()
        draw_pts(im, self.pts)
        for sh in self.shots:
            s = t - sh["t0"]
            x, y, dx, dy, trav, _ = self.pos(s)
            f = int(s * self.m["afps"]) % self.m["nf"]
            clip = trav if self.key != "fisek" else 999
            sp = local_sprite(self.m, f, clip, self.did, self.key)
            paste_local(im, sp, x, y, math.atan2(dy, dx) if self.key == "fisek" else 0.0)
        return im


def interval_for(key):
    return LOOP / max(1, round(LOOP / RATE[key]))


def header(w, title, sub):
    im = Image.new("RGB", (w, HEAD_H), (30, 34, 32))
    d = ImageDraw.Draw(im)
    label(d, 8, 3, title, 14)
    label(d, 8, 19, sub, 10, (200, 196, 182))
    return im


def stack(parts):
    W = max(p.width for p in parts)
    H = sum(p.height for p in parts)
    im = Image.new("RGB", (W, H), (30, 34, 32))
    y = 0
    for p in parts:
        im.paste(p, (0, y))
        y += p.height
    return im


def build_gif(did):
    sims = [LaneSim(did, k, kind, i, interval_for(k), 0.05 + 0.13 * i) for i, (k, _, kind) in enumerate(KEYS)]
    n = int(LOOP * FPS)
    dt = 1.0 / FPS
    hd = header(LANE_W, DIRS[did]["title"] + "  ·  oyun ölçeği (1080p, zoom 2)", DIRS[did]["sub"] + "  ·  silahlar: Zanaatkâr L3")
    frames = []
    for st in range(2 * n):
        t = st * dt
        for s in sims:
            s.step(t, dt)
        if st >= n:
            parts = [hd]
            for s, (k, name, _) in zip(sims, KEYS):
                li = s.render(t)
                label(ImageDraw.Draw(li), 4, 2, name)
                parts.append(li)
            frames.append(stack(parts))
    sample = stack([frames[i] for i in (0, n // 3, 2 * n // 3)])
    pal = sample.quantize(255, method=Image.Quantize.MEDIANCUT)
    q = [fr.quantize(palette=pal, dither=Image.Dither.NONE) for fr in frames]
    path = os.path.join(OUT, "mermi_%s_oyun.gif" % did)
    q[0].save(path, save_all=True, append_images=q[1:], duration=int(1000 / FPS), loop=0, disposal=1)
    frames[n // 2].save(os.path.join(OUT, "mermi_%s_oyun_kare.png" % did))
    print("gif", path, len(q))


# ------------------------------------------------------------------ detay sayfası
RT = 84  # dönüş örneği karosu (1:1), pivot uçuş yönünde 16 px önde -> uzun iz sığar


def detail(did):
    z, zr = 3, 2
    rows = []
    for key, name, _ in KEYS:
        m = DIRS[did]["m"][key]
        sps = [local_sprite(m, f, None, did, key) for f in range(m["nf"])]
        bb = None
        for sp in sps:
            b = sp.getchannel("A").getbbox()
            bb = b if bb is None else (min(bb[0], b[0]), min(bb[1], b[1]), max(bb[2], b[2]), max(bb[3], b[3]))
        bb = (bb[0] - 2, bb[1] - 2, bb[2] + 2, bb[3] + 2)
        tiles = []
        for sp in sps:
            t = Image.new("RGBA", (bb[2] - bb[0], bb[3] - bb[1]), G0 + (255,))
            t.alpha_composite(sp.crop(bb))
            tiles.append(t.convert("RGB").resize((t.width * z, t.height * z), Image.NEAREST))
        rots = []
        for deg in (0, 30, 60, 90):
            t = grass(RT, RT, 5)
            th = math.radians(-deg)
            paste_local(t, sps[0], RT // 2 + 16 * math.cos(th), RT // 2 + 16 * math.sin(th), th)
            rots.append(t.resize((RT * zr, RT * zr), Image.NEAREST))
        rows.append((name, tiles, rots, bb))
    fw = max(sum(t.width + 6 for t in tiles) for _, tiles, _, _ in rows)
    W = 130 + fw + 4 * (RT * zr + 6) + 10
    H = HEAD_H + 22 + sum(max(max(t.height for t in tiles), RT * zr) + 10 for _, tiles, _, _ in rows)
    im = Image.new("RGB", (W, H), (30, 34, 32))
    im.paste(header(W, DIRS[did]["title"] + "  ·  kareler x3 (sanat pikseli), sağda 0/30/60/90 derece oyun ölçeği x2 (uçuş yönüne döner)",
                    DIRS[did]["sub"] + "  ·  1 mermi pikseli = 0,575 dünya px (silahlarla aynı)"), (0, 0))
    d = ImageDraw.Draw(im)
    label(d, 130, HEAD_H + 4, "uçuş kareleri (iz dahil)", 10, (200, 196, 182))
    for i, deg in enumerate((0, 30, 60, 90)):
        label(d, 130 + fw + i * (RT * zr + 6), HEAD_H + 4, "%d°" % deg, 10, (200, 196, 182))
    y = HEAD_H + 22
    for name, tiles, rots, bb in rows:
        rh = max(max(t.height for t in tiles), RT * zr)
        label(d, 8, y + rh // 2 - 14, name, 13)
        label(d, 8, y + rh // 2 + 4, "%d x %d px" % (bb[2] - bb[0] - 4, bb[3] - bb[1] - 4), 10, (200, 196, 182))
        x = 130
        for t in tiles:
            im.paste(t, (x, y + (rh - t.height) // 2))
            x += t.width + 6
        x = 130 + fw
        for t in rots:
            im.paste(t, (x, y + (rh - t.height) // 2))
            x += t.width + 6
        y += rh + 10
    path = os.path.join(OUT, "mermi_%s_detay.png" % did)
    im.save(path)
    print("detay", path, im.size)


# ------------------------------------------------------------------ karşılaştırma (ŞU AN / A / B / C)
TRAIL_TINT = {"tabanca": (1.0, 0.85, 0.55), "tufek": (1.0, 0.93, 0.6), "tuftuf": (0.74, 1.0, 0.66), "yay": (1.0, 0.95, 0.84),
              "crossbow": (1.0, 0.95, 0.84)}
CUR = {"tabanca": ("assets/weapons/tufek/bullet.png", 0.4), "tufek": ("assets/weapons/tufek/bullet.png", 0.4),
       "tuftuf": ("assets/weapons/tuftuf/dart_v2.png", 0.207), "yay": ("assets/weapons/yay/arrow.png", 0.49368),
       "crossbow": ("assets/weapons/yay/arrow.png", 0.49368), "arcane": ("assets/weapons/arcane/spin_frame1.png", 1.8),
       "buz_asasi": ("assets/weapons/buz_asasi/bolt/fly1.png", 1.1), "fisek": ("assets/weapons/zanaat/fisek_L3.png", WPP / OWNER)}


CUR_ROT = {"tuftuf": -2.351331587385021, "arcane": -2.303834613}  # weapon_*.tscn ranged_projectile_rotation_offset


def current_lane(key, kind, idx, frac):
    """Bugünkü oyun: sprite + (varsa) beyaz iz sayfasının 'fly' karesi, mermi rengine boyanmış (projectile.gd TRAIL_COLORS); hepsi
    sahip ölçeğiyle (0,5) çarpılı. Fişek = Zanaatkâr roketi (burun -45 derece -> teğet + 45, firework_projectile.gd _rot_correction)."""
    sim = LaneSim("A", key, kind, idx, 99.0, 99.0)
    im = sim.bg.copy()
    if key == "fisek":
        tt = frac
        x, y = bez(*sim.arc, tt)
        dx, dy = bez_d(*sim.arc, tt)
        E.blit_world(im, asset(CUR[key][0]), x, y, CUR[key][1] * OWNER, ZOOM, math.atan2(dy, dx) + math.pi / 4)
        return im
    x = sim.mz[0] + (sim.tg[0] - sim.mz[0]) * frac
    y = sim.mz[1]
    if key in TRAIL_TINT:
        tr = asset("assets/fx/trails/trail_sheet.png", (128, 0, 160, 7)).copy()
        r, g, b = TRAIL_TINT[key]
        px = tr.load()
        for yy in range(tr.height):
            for xx in range(tr.width):
                c = px[xx, yy]
                px[xx, yy] = (int(c[0] * r), int(c[1] * g), int(c[2] * b), int(c[3] * 0.9))
        E.blit_world(im, tr, x - 16 * 1.212 * OWNER * ZOOM, y, 1.212 * OWNER, ZOOM)
    E.blit_world(im, asset(CUR[key][0]), x, y, CUR[key][1] * OWNER, ZOOM, CUR_ROT.get(key, 0.0))
    return im


def compare():
    cols = []
    hd = header(LANE_W, "ŞU AN (oyundaki)", "yumuşak resimler küçültülmüş / iri piksel; Buz/Fişek parçacıkları çizilmedi")
    parts = [hd]
    for i, (k, name, kind) in enumerate(KEYS):
        li = current_lane(k, kind, i, 0.5 if k == "fisek" else 0.55)
        label(ImageDraw.Draw(li), 4, 2, name)
        parts.append(li)
    cols.append(stack(parts))
    for did in "ABC":
        parts = [header(LANE_W, DIRS[did]["title"], DIRS[did]["sub"])]
        for i, (k, name, kind) in enumerate(KEYS):
            sim = LaneSim(did, k, kind, i, 99.0, 0.0)
            ft = FISEK_T if k == "fisek" else (sim.tg[0] - sim.mz[0]) / (SPEED[k] * ZOOM)
            snap = ft * (0.5 if k == "fisek" else 0.55)
            dt = 1.0 / FPS
            t = 0.0
            while t < snap:
                sim.step(t, dt)
                t += dt
            li = sim.render(t - dt)
            label(ImageDraw.Draw(li), 4, 2, name)
            parts.append(li)
        cols.append(stack(parts))
    W = sum(c.width for c in cols) + 6 * (len(cols) - 1)
    im = Image.new("RGB", (W, cols[0].height), (18, 20, 20))
    x = 0
    for c in cols:
        im.paste(c, (x, 0))
        x += c.width + 6
    path = os.path.join(OUT, "mermi_karsilastirma.png")
    im.save(path)
    print("kars", path, im.size)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    gi = os.path.join(HERE, "out", ".gdignore")
    if not os.path.exists(gi):
        open(gi, "w").close()
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    gif = "--gif" in sys.argv or not args
    for w in args or ["A", "B", "C", "kars"]:
        if w == "kars":
            compare()
        else:
            detail(w)
            if gif:
                build_gif(w)
