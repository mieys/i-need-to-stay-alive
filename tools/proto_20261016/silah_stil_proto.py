# -*- coding: utf-8 -*-
"""Silah STİL prototipleri (2026-10-16, oyuna bağlı DEĞİL). Kullanıcı: "sıfırdan yeni prototipler üretir misin bunlara ısınamadım,
terraria teması uymadı oyunuma" (madde 174'teki Terraria tadındaki set reddedildi).

Oyunun dili: sıcak tonlu, koyu konturlu, yumuşak "cozy RPG" karakterleri; eski silah ikonları rustik ve mat. Üç yön, her biri 3 temsilci
silah (Uzunkılıç, Ateş Asası, Tabanca) x 5 seviye; seçilen yön sonra 15 silaha yayılır:
  A Zanaatkâr - mat, gerçekçi; seviye = işçilik (paslı demir -> demir -> çelik + pirinç -> karartılmış çelik + gümüş -> yaldızlı yadigâr)
  B Masal     - yuvarlak, tombul, yumuşak canlı renkler; motif = mum, yıldız, ay, güneş, kurdele
  C Orman     - hayatta kalma/doğa; çakmaktaşı + kemik -> boynuz, yosun -> kehribar -> antik ruh ağacı (turkuaz ışık, yaprak, ateş böceği)
Az ton (düz gölge), parıltı en fazla L5'te bir tane, hale yalnızca gerçekten ışıyan parçada.

Motor: silah_proto48.py (Cv temizliği + çerçeve) -> asa_proto48.py. Çıktılar: silah48_stil/<A|B|C>_<anahtar>_L<n>.png,
silah48_stil_<A|B|C>.png (x4), silah48_stil_oyun.png (oyun ölçeği: 0,5 dünya px/piksel, zoom 2 -> 1:1, resim x2).
Çalıştırma: python tools/proto_20261016/silah_stil_proto.py
"""
import math
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import silah_proto48 as S  # noqa: E402
from silah_proto48 import Cv, frame, LV, F1, F3, F5, flame, ring, pgrain, facet, E, P, hx, spike, ribbon, circle_pts, scale_poly, font, N  # noqa: E402

OUT = os.path.join(HERE, "silah48_stil")

for _k, _v in {
    # A - mat, sıcak
    "A_wood": "#2a1a12 #4a2e1e #61402a #7a5236 #93673f #a87b4c #c9a074",
    "A_dwood": "#160d08 #2a1a10 #3a2416 #4c301e #5e3c26 #724a30 #946a4c",
    "A_rust": "#2a1810 #4e2c1c #6e3e26 #8a5432 #a0683e #b07c52 #c89a72",
    "A_iron": "#1c1c20 #36363c #4c4b50 #626066 #7a777a #918d8c #b8b2aa",
    "A_steel": "#1a1d24 #383d46 #555b64 #727882 #8f949c #aeb2b8 #dfe0e0",
    "A_black": "#0e0e12 #1e1e24 #2a2a32 #383842 #484852 #5c5c66 #8a8a94",
    "A_brass": "#2a1e0c #574018 #7a5a24 #9a7432 #b48c42 #c9a45a #e6cc8c",
    "A_silver": "#20242a #4a5058 #6c727a #8e949a #adb2b6 #c8ccce #eeeeea",
    "A_gold": "#2c1c08 #5c3e12 #85601e #a8802c #c49a3c #d8b45a #f2dc96",
    "A_leather": "#1e120c #3a2418 #4e3020 #623e2a #744c34 #865c40 #a07656",
    "A_rope": "#2a2216 #5a4a30 #75613f #8c7650 #a08a62 #b49e76 #cdbb96",
    "A_cloth": "#2a0c0c #521818 #6e2020 #8a2c28 #a23c32 #b85040 #d4705a",
    "A_garnet": "#22060a #4a0c16 #6e1420 #8e1c2a #b02c36 #cc4a4a #f0a0a0",
    "A_fire": "#3a1006 #6e1e0a #a8340e #d45a14 #ee8a24 #f8b844 #fde8a0",
    "A_glass": "#1e2a2a #3a4c4a #56706a #74908a #94b0a8 #b8d0c8 #e8f4ee",
    # B - masal
    "B_wood": "#2e1a12 #5a3420 #7a4a2c #9a643a #b88050 #d0a06c #ecc898",
    "B_iron": "#1e2230 #3c4258 #56607a #74809a #94a0b8 #b4c0d4 #e4ecf6",
    "B_teal": "#0c2428 #145056 #1e6e72 #2a8c8c #44aaa4 #70c8bc #c4f0e4",
    "B_plum": "#1e0e26 #3e1c4a #5a2c68 #764088 #9256a4 #b07cc0 #e0c0ec",
    "B_mustard": "#2c1e06 #6a4a0e #946c18 #b88c26 #d4aa3a #e8c85c #fff0b4",
    "B_coral": "#2e0e0e #6a2020 #923028 #b84636 #d6624a #ee8a6a #ffd0bc",
    "B_cream": "#2e2618 #6a5c44 #94846a #b8a888 #d4c6a6 #ece0c4 #fffaf0",
    "B_star": "#3a2a06 #8a6a10 #c49a1c #ecc232 #fcdc5a #fff09a #ffffff",
    "B_fire": "#3e0e08 #861e10 #c43c18 #ec6a24 #fc9a36 #ffc85a #fff2c0",
    # C - orman
    "C_bark": "#1a120c #34241a #4a3424 #5e4430 #74563c #8a6a4a #a8886a",
    "C_flint": "#16161a #2c2c34 #40404a #56565e #6c6c74 #868690 #b0b0b8",
    "C_obs": "#0a0a0e #16161e #22222c #30303a #40404c #56566a #8c8ca8",
    "C_bone": "#26201a #54483a #786a56 #9a8c74 #b8ac92 #d2c8b0 #f0eadc",
    "C_sinew": "#2a1e14 #523c26 #6c5034 #846440 #9a7a52 #ae8e66 #c8ac88",
    "C_moss": "#0e1a0e #1e3418 #2c4a22 #3c602c #4e7838 #66904a #94b874",
    "C_iron": "#18191c #32343a #474a52 #5e626a #777b82 #92969a #bcc0c2",
    "C_bronze": "#24160a #4c3016 #6c4620 #8c5e2c #a8773a #c0904e #e0b880",
    "C_amber": "#2e1604 #6a3406 #9a520c #c47216 #e0942a #f2b84e #ffe4a0",
    "C_spirit": "#06261e #0c4a3c #127060 #1e9884 #38bca4 #74dcc4 #d8fff4",
    "C_leaf": "#0c200c #183e18 #245a20 #32762a #44923a #62ac52 #a4d890",
    "C_antler": "#2a2016 #5a4630 #7c6446 #9c8460 #b8a07c #cebc9a #ece0c8",
    "C_fire": "#3a1004 #7a2008 #b4400c #e06a16 #f4962a #fcc456 #fff0b8",
}.items():
    P[_k] = [hx(c) for c in _v.split()]


def bar(c, a0, a1, r, m, **kw):
    c.tube([(a0, 0), (a1, 0)], r, m, **kw)


def shiny(c, a, b, r, m):
    c.sphere((a, b), r, m, shine=0.6)


def star_poly(ca, cb, ro, ri, n=5, rot=0.0):
    pts = []
    for i in range(2 * n):
        r = ro if i % 2 == 0 else ri
        th = rot + math.pi * i / n
        pts.append((ca + r * math.cos(th), cb + r * math.sin(th)))
    return pts


def wavy(a0, a1, amp, per, n=24, ph=0.0):
    return [(a0 + (a1 - a0) * i / n, amp * math.sin(ph + 2 * math.pi * (a0 + (a1 - a0) * i / n) / per)) for i in range(n + 1)]


def tassel(c, a, b, m, cord="A_rope", ln=5.0):
    """Topuzdan aşağı (ekranda aşağı = -a,+b) sarkan püskül."""
    c.tube([(a, b), (a - 1.6, b + 1.8), (a - 2.6, b + 3.0)], 0.4, cord, shine=0.2, sep=False)
    c.plate([(a - 2.2, b + 2.4), (a - 2.4 - ln * 0.5, b + 2.6 + ln * 0.6), (a - 3.6 - ln * 0.4, b + 2.0 + ln * 0.7),
             (a - 3.6, b + 2.4)], m, bevel=0.9, shine=0.2)


def blade_tex2(edge=None, fuller=False, rust=False):
    """Düz, az tonlu bıçak: ışıklı yarı 4, gölge yarı 3, kenar bevel 5/2; edge=malzeme -> kenar başka metal (iki tonlu)."""
    def f(idx, a, b, x, y, d):
        if d < 1.0:
            if edge:
                return P[edge][5 if b < 0 else 3]
            return 5 if b < 0 else 2
        if fuller and abs(b) < 0.36:
            return 2
        if rust and S.hsh(x // 2, y // 2, 13) < 0.3:
            return P["A_rust"][3 if b < 0 else 2]
        return 4 if b < -0.2 else 3
    return f


# ================================================================ A - ZANAATKÂR
def A_sword(c, lv):
    g = -11.0
    tip = LV(lv, 21, 30.5)
    w = [0, 1.9, 2.0, 2.2, 2.4, 2.75][lv]
    pe = LV(lv, -21, -27)
    bm = ["", "A_iron", "A_iron", "A_steel", "A_black", "A_steel"][lv]
    tr = ["", "A_iron", "A_iron", "A_brass", "A_silver", "A_gold"][lv]
    c.tube([(pe + 1.6, 0), (g - 0.8, 0)], 1.2 if lv < 3 else 1.3, "A_rope" if lv == 1 else "A_leather", tex=E.wrap, shine=0.1)
    if lv >= 3:
        bar(c, g - 2.4, g - 1.4, 1.55, tr, shine=0.4)
        bar(c, pe + 1.8, pe + 2.8, 1.5, tr, shine=0.4)
    if lv >= 4:
        tassel(c, pe + 5.6, 1.2, "A_cloth", cord=tr, ln=3.0)
    if lv == 1:
        c.sphere((pe + 1.2, 0), 1.35, "A_wood", shine=0.2)
    elif lv == 4:
        c.tube([(pe + 0.6, -2.0), (pe + 0.6, 2.0)], 1.1, tr, shine=0.45)
    else:
        c.sphere((pe + 1.2, 0), LV(lv, 1.6, 2.2), tr, shine=0.45)
    if lv == 5:
        shiny(c, pe + 1.2, 0, 0.9, "A_garnet")
    b0 = g + 0.4
    L = tip - b0
    tl = w * 2.1
    if lv == 1:
        poly = [(b0, -w), (b0 + L * 0.34, -w), (b0 + L * 0.37, -w * 0.55), (b0 + L * 0.41, -w), (tip - tl, -w * 0.95), (tip, 0),
                (tip - tl, w), (b0 + L * 0.62, w), (b0 + L * 0.65, w * 0.5), (b0 + L * 0.69, w), (b0, w)]
    elif lv == 5:
        poly = [(b0, -w * 0.9), (b0 + 2.4, -w), (tip - tl * 1.5, -w * 1.08), (tip, 0), (tip - tl * 1.5, w * 1.08), (b0 + 2.4, w), (b0, w * 0.9)]
    else:
        poly = [(b0, -w), (tip - tl, -w), (tip, 0), (tip - tl, w), (b0, w)]
    c.plate(poly, bm, bevel=1.2, shine=0.25, tex=blade_tex2(edge="A_silver" if lv == 4 else None, fuller=lv in (3, 5), rust=lv == 1))
    if lv == 5:
        c.tube([(b0 + 2.0, 0), (b0 + L * 0.5, 0)], 0.42, "A_gold", shine=0.5, sep=False, outline=False)
    half = LV(lv, 3.4, 7.2)
    if lv == 1:
        c.tube([(g, -half), (g, half)], 0.85, tr, shine=0.3)
    elif lv == 2:
        for sg in (-1, 1):
            c.tube([(g, 0), (g + 0.2, sg * half * 0.7), (g + 1.4, sg * half)], (1.2, 0.7), tr, shine=0.35)
    elif lv == 3:
        c.tube([(g, -half), (g, half)], 1.0, tr, shine=0.45)
        for sg in (-1, 1):
            c.sphere((g, sg * half), 1.25, tr, shine=0.5)
    else:
        for sg in (-1, 1):
            c.tube([(g, 0), (g, sg * half * 0.55), (g + 1.6, sg * half), (g + 3.0, sg * half * 0.82)], (1.25, 0.6), tr, shine=0.45)
            if lv == 5:
                c.sphere((g + 3.0, sg * half * 0.82), 0.9, tr, shine=0.5)
        c.plate([(g - 1.3, -1.8), (g + 1.6, -1.6), (g + 2.2, 0), (g + 1.6, 1.6), (g - 1.3, 1.8)], tr, bevel=1.0, shine=0.4)
        if lv == 5:
            shiny(c, g + 0.4, 0, 1.05, "A_garnet")
    if lv == 5:
        c.glint(b0 + L * 0.7, -w * 0.5, "A_steel", 6)


def A_fire(c, lv):
    pe = LV(lv, -27, -29)
    hc = LV(lv, 15.0, 16.0)
    sm = ["", "A_wood", "A_wood", "A_wood", "A_black", "A_dwood"][lv]
    tr = ["", "A_rope", "A_iron", "A_brass", "A_silver", "A_gold"][lv]
    if lv == 1:
        c.tube([(pe + 1, 0.3), (-16, -0.5), (-4, 0.5), (6, -0.3), (hc - 2, 0)], 1.2, sm, tex=E.grain, shine=0.2)
    else:
        bar(c, pe + 0.4, pe + 2.4, (1.1, 1.5), tr if lv >= 2 else "A_iron", shine=0.4)
        bar(c, pe + 1.5, hc - 3.0, 1.25, sm, tex=E.grain if sm.endswith("wood") else None, shine=0.3)
        c.tube([(-14, 0), (-8, 0)], 1.7, "A_leather", tex=E.wrap, shine=0.1)
    if lv >= 3:
        for a in (-15.0, -7.0):
            bar(c, a - 0.7, a + 0.3, 1.85, tr, shine=0.45)
    if lv == 1:
        c.sphere((hc, 0), 2.3, "A_fire", glow=True)
        flame(c, hc + 0.5, 6.0, 2.0, F1, mat="A_fire")
        for k in range(3):
            c.tube([(hc - 1.6 + k * 1.2, -2.4), (hc - 1.2 + k * 1.2, 2.4)], 0.42, "A_rope", shine=0.2)
        return
    if lv == 2:
        flame(c, hc + 0.6, 8.0, 2.6, F1, mat="A_fire")
        c.sphere((hc, 0), 2.4, "A_fire", glow=True)
        bar(c, hc - 4.2, hc - 2.4, (1.4, 1.8), tr, shine=0.4)
        for sg in (-1, 1):
            c.tube([(hc - 2.6, sg * 1.0), (hc - 1.0, sg * 3.0), (hc + 1.8, sg * 3.0), (hc + 3.0, sg * 1.2)], 0.45, "A_steel", shine=0.5)
        return
    if lv == 3:
        flame(c, hc + 1.0, 11.0, 3.6, F3, mat="A_fire")
        bar(c, hc - 4.4, hc - 2.6, (1.4, 1.9), tr, shine=0.4)
        c.plate([(hc - 2.8, -1.6), (hc + 0.5, -3.6), (hc + 2.6, -4.2), (hc + 2.6, 4.2), (hc + 0.5, 3.6), (hc - 2.8, 1.6)], tr, bevel=1.6, shine=0.35)
        c.tube([(hc + 2.6, -4.6), (hc + 2.6, 4.6)], 0.7, tr, shine=0.5)
        return
    # L4-5: fener
    lw, lh = (3.0, 4.6) if lv == 4 else (3.6, 5.6)
    lc = hc + 0.5
    bar(c, lc - lh - 2.6, lc - lh - 0.4, (1.4, 2.0), tr, shine=0.45)
    c.plate([(lc - lh, -lw), (lc + lh, -lw), (lc + lh, lw), (lc - lh, lw)], "A_glass", bevel=0.8, shine=0.2)
    flame(c, lc - lh * 0.55, lh * 1.45, lw * 0.75, F1 if lv == 4 else F3, mat="A_fire", cap=lc + lh - 0.6)
    c.sphere((lc - lh * 0.35, 0), lw * 0.45, "A_fire", glow=True)
    for sg in (-1, 1):
        c.tube([(lc - lh, sg * lw), (lc + lh, sg * lw)], 0.7, tr, shine=0.45)
    c.tube([(lc - lh, -lw - 0.4), (lc - lh, lw + 0.4)], 0.8, tr, shine=0.45)
    c.plate([(lc + lh - 0.4, -lw - 1.0), (lc + lh + 2.6, -lw * 0.4), (lc + lh + 2.6, lw * 0.4), (lc + lh - 0.4, lw + 1.0)], tr, bevel=1.2, shine=0.4)
    facet(c, spike((lc + lh + 2.2, 0), (lc + lh + 5.0, 0), 0.9), tr)
    c.tube([(lc + lh + 2.4, -1.6), (lc + lh + 4.0, -2.6), (lc + lh + 4.6, -1.0)], 0.45, tr, shine=0.4)
    if lv == 5:
        for sg in (-1, 1):
            c.tube([(lc - lh, sg * (lw + 0.6)), (lc - lh - 1.6, sg * (lw + 2.0)), (lc - lh - 0.6, sg * (lw + 3.2))], (0.6, 0.4), tr, shine=0.45)
        shiny(c, lc + lh + 1.0, 0, 0.95, "A_garnet")


def A_gun(c, lv):
    by = -3.5
    tr = ["", "A_rope", "A_iron", "A_brass", "A_silver", "A_gold"][lv]
    if lv == 1:
        bar(c, -19.0, -2.0, 1.25, "A_wood", tex=E.grain, shine=0.2)
        c.sphere((-19.0, 0), 1.4, "A_wood", shine=0.2)
        c.tube([(-6.0, -2.6), (9.0, -2.6)], 2.0, "A_iron", shine=0.35)
        ring(c, 7.6, -2.6, 2.5, "A_iron", 1.4)
        for a in (-4.5, 1.0):
            ring(c, a, -1.4, 2.4, "A_rope", 1.2)
        c.tube([(-6.6, -3.0), (-8.0, -5.6), (-6.6, -7.0)], 0.42, "A_rope", sep=False)
        c.star(-6.4, -7.6, "A_fire", 1)
        return
    mz = [0, 0, 9.5, 13.5, 14.5, 15.5][lv]
    br = [0, 0, 1.3, 1.4, 1.2, 1.5][lv]
    wd = ["", "", "A_wood", "A_wood", "A_dwood", "A_dwood"][lv]
    bm = ["", "", "A_iron", "A_steel", "A_black", "A_steel"][lv]
    grip = [(-5.0, -1.5), (-6.8, 4.0), (-8.6, 9.0), (-13.8, 10.2), (-15.2, 7.8), (-13.0, 2.0), (-12.5, -1.5)]
    c.plate(grip, wd, bevel=1.5, shine=0.15, tex=pgrain)
    if lv >= 3:
        c.tube([(-15.0, 8.4), (-13.6, 10.6), (-9.0, 10.0)], 0.9, tr, shine=0.4)
    if lv == 5:
        shiny(c, -10.4, 4.0, 1.2, "A_garnet")
        c.tube([(-7.0, 1.0), (-9.4, 6.4)], 0.42, "A_gold", sep=False, outline=False)
    c.tube([(-4.6, -0.5), (-4.8, 2.4), (-2.6, 3.6), (-0.2, 2.6), (0.0, -0.5)], 0.5, tr, shine=0.3)
    c.tube([(-2.4, -0.5), (-2.9, 2.0)], 0.5, "A_iron", shine=0.3)
    c.plate([(-12.5, -6.4), (-2.0, -6.4), (mz - 3.0, -2.2), (mz - 3.0, -1.2), (-11.5, -0.8)], wd, bevel=1.4, shine=0.15, tex=pgrain)
    c.plate([(-9.0, -7.2), (-4.0, -7.2), (-4.0, -4.6), (-9.0, -4.6)], tr if lv >= 3 else "A_iron", bevel=1.0, shine=0.35)
    c.tube([(-8.4, -7.0), (-9.8, -9.2), (-8.4, -10.2)], (0.85, 0.55), "A_iron", shine=0.35)
    if lv == 4:
        for dy in (-1.3, 1.3):
            c.tube([(-3.0, by + dy), (mz, by + dy)], br, bm, shine=0.4)
        for a in (0.0, mz - 1.4):
            ring(c, a, by, 2.9, tr, 1.4)
    elif lv == 5:
        c.tube([(-3.0, by), (mz - 3.0, by)], br, bm, shine=0.45)
        c.plate([(mz - 3.6, by - br - 0.2), (mz + 0.6, by - 3.6), (mz + 0.6, by + 3.6), (mz - 3.6, by + br + 0.2)], bm, bevel=1.2, shine=0.35)
        ring(c, mz - 0.4, by, 3.8, tr, 1.4)
        for a in (0.5, 5.0):
            ring(c, a, by, br + 0.5, tr, 1.1)
        c.glint(mz - 6.0, by - 0.8, "A_steel", 6)
    else:
        c.tube([(-3.0, by), (mz, by)], br, bm, shine=0.45)
        ring(c, mz - 1.4, by, br + 0.6, tr, 1.4)
        if lv == 3:
            ring(c, 3.0, by, br + 0.5, tr, 1.0)
    c.tube([(mz - 2.6, by - 2.4), (mz - 2.2, by - 3.4)], 0.5, tr, shine=0.4)


# ================================================================ B - MASAL
def B_sword(c, lv):
    g = -10.0
    tip = LV(lv, 20, 29)
    w = LV(lv, 2.7, 3.4)
    pe = LV(lv, -19, -24)
    bm = ["", "B_wood", "B_iron", "B_iron", "B_iron", "B_iron"][lv]
    gm = ["", "B_wood", "B_iron", "B_teal", "B_plum", "B_mustard"][lv]
    c.tube([(pe + 1.8, 0), (g - 0.8, 0)], 1.45, "B_coral" if lv != 4 else "B_teal", tex=E.wrap, shine=0.15)
    c.sphere((pe + 1.4, 0), LV(lv, 1.8, 2.5), gm if lv > 1 else "B_wood", shine=0.45)
    b0 = g + 0.4
    L = tip - b0
    rt = [(tip - w + w * math.cos(th), w * math.sin(th)) for th in [-math.pi / 2 + math.pi * i / 8 for i in range(9)]]
    if lv == 1:
        poly = [(b0, -w)] + rt + [(b0, w)]
    elif lv <= 3:
        poly = [(b0, -w), (tip - w * 1.6, -w), (tip, 0), (tip - w * 1.6, w), (b0, w)]
    else:
        poly = [(b0, -w * 0.85), (b0 + L * 0.55, -w * 1.15), (tip, 0), (b0 + L * 0.55, w * 1.15), (b0, w * 0.85)]
    c.plate(poly, bm, bevel=1.4, shine=0.3, tex=blade_tex2(edge="B_mustard" if lv == 5 else None))
    if lv >= 4:
        c.plate([(g - 0.6, 1.4), (g - 3.6, 4.0), (g - 7.8, 3.6), (g - 6.4, 5.4), (g - 9.6, 6.4), (g - 4.0, 6.6), (g - 1.2, 3.6)], "B_coral", bevel=1.0, shine=0.3)
        c.plate([(g - 0.6, 1.4), (g - 1.6, 4.6), (g - 1.0, 8.4), (g + 0.4, 7.0), (g + 1.8, 8.6), (g + 1.0, 4.2)], "B_coral", bevel=1.0, shine=0.3)
    if lv == 1:
        c.tube([(g, -3.4), (g, 3.4)], 1.3, "B_wood", shine=0.3)
    elif lv == 2:
        c.sphere((g, 0), 3.0, gm, shine=0.4)
        c.sphere((g, 0), 1.2, "B_iron", shine=0.5)
    elif lv == 3:
        for sg in (-1, 1):
            c.plate([(g - 1.0, sg * 1.0), (g + 1.6, sg * 2.6), (g + 1.2, sg * 5.0), (g - 0.6, sg * 5.6), (g - 1.6, sg * 3.4)], gm, bevel=1.2, shine=0.35)
        c.sphere((g, 0), 1.7, "B_mustard", shine=0.5)
    elif lv == 4:
        moon = [(g + 1.0 + 6.0 * math.cos(th), 6.0 * math.sin(th)) for th in [math.radians(95 + 170 * i / 14) for i in range(15)]]
        inner = [(g + 3.4 + 4.6 * math.cos(th), 4.6 * math.sin(th)) for th in [math.radians(255 - 150 * i / 14) for i in range(15)]]
        c.plate(moon + inner, gm, bevel=1.2, shine=0.35)
        c.sphere((g, 0), 1.4, "B_mustard", shine=0.5)
    else:
        c.plate(star_poly(g, 0.0, 6.0, 2.6, rot=math.pi), gm, bevel=1.4, shine=0.4)
        c.halo("B_star")
        shiny(c, g, 0, 1.4, "B_coral")
    if lv == 5:
        c.star(tip - 5.0, -w - 2.4, "B_star", 1)


def B_fire(c, lv):
    pe = LV(lv, -26, -28.5)
    hc = LV(lv, 16.0, 16.5)
    sm = ["", "B_wood", "B_wood", "B_teal", "B_plum", "B_plum"][lv]
    if lv >= 2:
        c.sphere((pe + 1.2, 0), 1.5, "B_mustard", shine=0.45)
    bar(c, pe + 1.6, hc - (3.0 if lv > 1 else 4.0), 1.3, sm, tex=E.grain if sm == "B_wood" else None, shine=0.35)
    if lv >= 2:
        c.tube([(-13, 0), (-7.5, 0)], 1.75, "B_coral", tex=E.wrap, shine=0.15)
    if lv == 1:
        c.plate([(hc - 4.6, -2.6), (hc - 3.2, -2.6), (hc - 3.2, 2.6), (hc - 4.6, 2.6)], "B_mustard", bevel=0.9, shine=0.4)
        bar(c, hc - 3.4, hc + 2.4, 1.5, "B_cream", shine=0.3)
        c.tube([(hc + 2.4, 0), (hc + 3.0, 0)], 0.35, "B_wood", sep=False)
        flame(c, hc + 2.6, 6.0, 1.8, F1, mat="B_fire")
        return
    if lv == 2:
        c.tube(circle_pts(hc, 0.0, 3.6, n=28), 0.9, "B_wood", shine=0.35)
        c.sphere((hc, 0), 2.5, "B_fire", glow=True)
        return
    if lv == 3:
        sp = [(hc - 3.0, 0.0)]
        for i in range(1, 22):
            th = math.radians(-90 + 300 * i / 21)
            r = 4.2 * (1.0 - 0.5 * i / 21)
            sp.append((hc + 1.0 + r * math.sin(th + math.pi / 2), -r * math.cos(th + math.pi / 2) - 1.0))
        flame(c, hc + 2.4, 9.0, 2.8, F3, mat="B_fire")
        c.tube(sp, (1.1, 0.5), sm, shine=0.45)
        c.sphere((hc + 1.4, -1.0), 2.0, "B_fire", glow=True)
        return
    R = 3.0 if lv == 4 else 3.6
    rays = 8 if lv == 4 else 10
    ro = R + (3.2 if lv == 4 else 4.4)
    for k in range(rays):
        th = 2 * math.pi * k / rays
        ca, sa = math.cos(th), math.sin(th)
        L = ro if k % 2 == 0 else ro - 1.4
        c.plate([(hc + ca * (R + 0.4) - sa * 1.2, sa * (R + 0.4) + ca * 1.2), (hc + ca * L, sa * L),
                 (hc + ca * (R + 0.4) + sa * 1.2, sa * (R + 0.4) - ca * 1.2)], "B_mustard", bevel=0.9, shine=0.35)
    c.tube(circle_pts(hc, 0.0, R + 0.6, n=28), 0.8, "B_mustard", shine=0.45)
    c.sphere((hc, 0), R, "B_fire", glow=True)
    bar(c, hc - R - 2.6, hc - R - 0.6, (1.5, 1.9), "B_mustard", shine=0.45)
    if lv == 5:
        c.halo("B_star")
        shiny(c, hc - R - 1.6, 0, 0.9, "B_coral")
        c.star(hc + ro + 1.0, -ro * 0.6, "B_star", 1)


def B_gun(c, lv):
    by = -3.0
    if lv == 1:
        c.tube([(-14.0, by), (6.0, by)], 2.6, "B_wood", tex=E.grain, shine=0.3)
        c.plate([(-12.0, by + 1.5), (-8.0, by + 1.5), (-10.0, by + 9.0), (-14.5, by + 9.0)], "B_wood", bevel=1.6, shine=0.2)
        bar(c, 6.0, 9.0, 1.9, "B_cream", shine=0.25) if False else c.tube([(6.0, by), (9.4, by)], (1.9, 1.6), "B_cream", shine=0.25)
        c.tube([(-2.0, by + 2.4), (3.0, by + 4.6), (8.0, by + 1.6)], 0.35, "B_cream", sep=False)
        ring(c, -6.0, by, 3.0, "B_coral", 1.6)
        return
    body = ["", "", "B_iron", "B_teal", "B_plum", "B_mustard"][lv]
    tr = ["", "", "B_iron", "B_mustard", "B_mustard", "B_coral"][lv]
    mz = LV(lv, 7.0, 12.5)
    c.plate([(-5.0, by + 1.0), (-1.6, by + 1.0), (-5.4, by + 9.6), (-9.4, by + 11.0), (-11.6, by + 9.6), (-8.4, by + 1.0)], "B_wood", bevel=1.6, shine=0.2)
    c.sphere((-10.4, by + 10.0), 1.5, tr, shine=0.45)
    c.tube([(-3.4, by + 2.0), (-3.0, by + 4.6), (-0.6, by + 5.2), (0.6, by + 3.6), (0.4, by + 2.0)], 0.55, tr, shine=0.35)
    c.tube([(-10.0, by), (mz, by)], 2.4, body, shine=0.4)
    c.sphere((-10.0, by), 2.4, body, shine=0.4)
    if lv == 3:
        c.plate([(mz - 1.0, by - 2.0), (mz + 3.0, by - 4.6), (mz + 3.0, by + 4.6), (mz - 1.0, by + 2.0)], body, bevel=1.4, shine=0.35)
        ring(c, mz + 2.4, by, 4.8, tr, 1.2)
    elif lv >= 4:
        c.plate(star_poly(mz + 1.6, by, 4.6 if lv == 4 else 5.6, 2.2 if lv == 4 else 2.6, rot=0.0), tr if lv == 4 else "B_star", bevel=1.2, shine=0.4)
        if lv == 5:
            c.halo("B_star")
    else:
        ring(c, mz - 1.4, by, 3.0, tr, 1.6)
    ring(c, -4.0, by, 2.9, tr, 1.4)
    c.sphere((-11.0, by - 2.6), 1.1, tr, shine=0.45)
    if lv == 5:
        shiny(c, -8.0, by + 5.0, 1.3, "B_coral")
        c.star(mz - 4.0, by - 5.0, "B_star", 1)


# ================================================================ C - ORMAN
def knapped(a0, a1, w, n, seed, tipw=0.0):
    """Yontulmuş taş bıçak: iki kenarda düzensiz küçük çentikler."""
    up, dn = [], []
    for i in range(n + 1):
        t = i / n
        a = a0 + (a1 - a0) * t
        ww = w * (1.0 - t ** 2.2) + tipw
        j1 = (S.hsh(i, seed, 1) - 0.5) * 0.9
        j2 = (S.hsh(i, seed, 2) - 0.5) * 0.9
        up.append((a, -max(0.2, ww + j1)))
        dn.append((a, max(0.2, ww + j2)))
    return up + [(a1 + 0.8, 0)] + dn[::-1]


def C_sword(c, lv):
    g = -10.0
    tip = LV(lv, 19, 29.5)
    pe = LV(lv, -20, -26)
    hm = ["", "C_bark", "C_bark", "C_bark", "C_bark", "C_bark"][lv]
    bar(c, pe + 1.0, g - 0.6, 1.25, hm, tex=E.grain, shine=0.2)
    c.tube([(g - 7.0, 0), (g - 1.0, 0)], 1.55, "C_sinew" if lv < 3 else ("C_moss" if lv == 3 else "C_leaf"), tex=E.wrap, shine=0.1)
    b0 = g + 0.4
    L = tip - b0
    if lv == 1:
        c.plate(knapped(b0 - 1.0, tip - 0.8, 2.6, 9, 3), "C_flint", bevel=1.0, shine=0.25, tex=blade_tex2())
        for k in range(3):
            c.tube([(g - 1.6 + k * 1.1, -2.2), (g - 1.2 + k * 1.1, 2.2)], 0.42, "C_sinew", shine=0.2)
        return
    if lv == 2:
        poly = [(b0, -1.8), (b0 + L * 0.35, -2.6), (tip, -0.4), (tip - 1.2, 0.6)] + [
            (b0 + L * (0.85 - 0.12 * i), 1.6 + (0.7 if i % 2 == 0 else 0.0)) for i in range(6)] + [(b0, 1.8)]
        c.plate(poly, "C_bone", bevel=1.2, shine=0.2, tex=blade_tex2())
        c.sphere((g, 0), 2.1, "C_bone", shine=0.3)
        return
    if lv == 3:
        w = 2.1
        c.plate([(b0, -w), (tip - w * 2, -w), (tip, 0), (tip - w * 2, w), (b0, w)], "C_iron", bevel=1.2, shine=0.25, tex=blade_tex2())
        for sg in (-1, 1):
            c.tube([(g, 0), (g + 0.4, sg * 2.4), (g - 0.4, sg * 4.6), (g + 1.6, sg * 6.0)], (1.1, 0.5), "C_antler", shine=0.35)
            c.tube([(g + 0.2, sg * 3.6), (g + 2.2, sg * 3.8)], (0.6, 0.35), "C_antler", shine=0.35)
        return
    if lv == 4:
        c.plate(knapped(b0, tip - 0.8, 2.9, 11, 7, tipw=0.4), "C_obs", bevel=1.2, shine=0.35, tex=blade_tex2())
        for sg in (-1, 1):
            c.plate([(g + 0.6, sg * 1.0), (g + 1.4, sg * 3.4), (g - 0.6, sg * 6.4), (g - 1.8, sg * 3.8), (g - 1.0, sg * 1.2)], "C_leaf", bevel=1.0, shine=0.3)
        c.gem([(g - 1.4, 0), (g, -1.6), (g + 1.6, 0), (g, 1.6)], "C_amber", table=0.35, emis=False)
        return
    # L5 ruh ağacı
    w = 2.8
    c.plate([(b0, -w * 0.9), (b0 + L * 0.5, -w * 1.1), (tip, 0), (b0 + L * 0.5, w * 1.1), (b0, w * 0.9)], "C_bark", bevel=1.4, shine=0.25, tex=blade_tex2())
    c.tube([(b0 + 1.0, 0), (b0 + L * 0.35, -0.6), (b0 + L * 0.6, 0.5), (tip - 3.0, 0)], 0.45, "C_spirit", glow=(6, 5, 4), sep=False, outline=False)
    c.tube([(b0 + L * 0.35, -0.6), (b0 + L * 0.45, -1.8)], 0.42, "C_spirit", glow=(5, 5, 4), sep=False, outline=False)
    c.tube([(b0 + L * 0.6, 0.5), (b0 + L * 0.7, 1.7)], 0.42, "C_spirit", glow=(5, 5, 4), sep=False, outline=False)
    for sg, (la, lb) in ((-1, (g + 1.0, 5.6)), (1, (g + 2.4, 6.0)), (1, (g - 1.6, 4.4))):
        c.plate([(g, sg * 1.0), (la, sg * lb * 0.6), (la + 0.6, sg * lb), (la - 1.2, sg * lb * 0.8)], "C_leaf", bevel=1.0, shine=0.3)
    c.sphere((g - 0.2, 0), 1.6, "C_spirit", glow=True)
    c.glint(tip - 6.0, -w - 3.2, "C_spirit", 6)
    c.glint(b0 + 4.0, w + 4.0, "C_spirit", 6)


def C_fire(c, lv):
    pe = LV(lv, -26.5, -29)
    hc = LV(lv, 15.0, 16.0)
    if lv <= 2:
        bar(c, pe + 1.0, hc - 2.0, 1.25, "C_bark", tex=E.grain, shine=0.2)
    elif lv == 3:
        c.tube(wavy(pe + 1.0, hc - 2.0, 0.6, 9.0), 1.3, "C_bark", tex=E.grain, shine=0.25)
    else:
        for sg in (1, -1):
            c.tube(wavy(pe + 1.0, hc - 1.0, 0.8 * sg, 7.0), 0.85, "C_bark" if lv == 4 else "C_moss", tex=E.grain, shine=0.3)
    if lv >= 2:
        c.tube([(-14, 0), (-8.5, 0)], 1.7, "C_sinew" if lv < 4 else "C_moss", tex=E.wrap, shine=0.1)
    if lv == 1:
        flame(c, hc + 0.5, 8.0, 2.6, F1, mat="C_fire")
        c.tube([(hc - 3.0, 0), (hc + 1.4, 0)], 2.0, "C_sinew", tex=E.wrap, shine=0.15)
        return
    if lv == 2:
        flame(c, hc + 0.6, 7.0, 2.2, F1, mat="C_fire")
        c.sphere((hc, 0), 2.2, "C_fire", glow=True)
        for sg in (-1, 1):
            c.tube([(hc - 3.0, 0), (hc - 1.6, sg * 2.4), (hc + 1.0, sg * 3.4), (hc + 3.4, sg * 2.6)], (1.0, 0.5), "C_antler", shine=0.35)
            c.tube([(hc - 0.6, sg * 3.1), (hc + 0.4, sg * 4.8)], (0.55, 0.35), "C_antler", shine=0.35)
        return
    if lv == 3:
        flame(c, hc + 1.4, 10.0, 3.0, F3, mat="C_fire")
        c.gem([(hc - 2.6, 0), (hc - 0.6, -2.2), (hc + 1.8, -1.8), (hc + 2.6, 0), (hc + 1.6, 2.0), (hc - 0.6, 2.2)], "C_amber", table=0.4, emis=False)
        for sg in (-1, 1):
            c.tube([(hc - 3.4, sg * 0.6), (hc - 1.4, sg * 2.8), (hc + 1.4, sg * 2.8)], (0.8, 0.45), "C_bark", shine=0.3)
        return
    fm = "C_fire"
    flame(c, hc + 1.0, LV(lv, 11.0, 13.5), LV(lv, 3.4, 4.2), F3 if lv == 4 else F5, mat=fm)
    if lv == 5:
        fo_r = LV(lv, 3.4, 4.2)
        c.sphere((hc + 0.6, 0), 2.2, "C_spirit", glow=True)
    else:
        c.sphere((hc + 0.6, 0), 2.2, fm, glow=True)
    for sg in (-1, 1):
        c.tube([(hc - 3.0, sg * 0.6), (hc - 1.4, sg * 3.4), (hc + 1.6, sg * 4.2), (hc + 3.6, sg * 3.0)], (1.0, 0.45), "C_bark", shine=0.3)
        c.plate([(hc - 1.4, sg * 3.4), (hc - 3.6, sg * 6.2), (hc - 1.0, sg * 7.0), (hc + 0.2, sg * 4.6)], "C_leaf", bevel=0.9, shine=0.3)
    if lv == 5:
        c.plate([(hc + 1.6, -4.2), (hc + 4.4, -7.0), (hc + 5.6, -5.6), (hc + 3.2, -4.0)], "C_leaf", bevel=0.9, shine=0.3)
        c.glint(hc + 8.0, 6.0, "C_spirit", 6)
        c.glint(hc - 6.0, -7.0, "C_spirit", 6)
        c.glint(hc + 12.0, -4.0, "C_spirit", 6)


def C_gun(c, lv):
    by = -3.5
    if lv == 1:
        c.tube([(-18.0, 0.5), (-4.0, -1.5)], 1.3, "C_bark", tex=E.grain, shine=0.2)
        c.tube([(-6.0, by), (8.0, by)], 2.2, "C_bark", tex=E.grain, shine=0.3)
        for a in (-4.0, 1.0, 6.0):
            ring(c, a, by, 2.7, "C_sinew", 1.2)
        c.tube([(-6.6, by - 0.4), (-8.0, by - 3.0), (-6.8, by - 4.6)], 0.42, "C_sinew", sep=False)
        c.star(-6.6, by - 5.2, "C_fire", 1)
        return
    mz = LV(lv, 10.0, 15.5)
    gm = ["", "", "C_antler", "C_bark", "C_bark", "C_bark"][lv]
    bm = ["", "", "C_iron", "C_iron", "C_bronze", "C_bark"][lv]
    grip = [(-5.0, -1.5), (-6.8, 4.0), (-8.6, 9.0), (-13.8, 10.2), (-15.2, 7.8), (-13.0, 2.0), (-12.5, -1.5)]
    c.plate(grip, gm, bevel=1.5, shine=0.2, tex=pgrain if gm == "C_bark" else None)
    if lv >= 3:
        c.plate([(-8.0, 1.6), (-10.0, 5.6), (-11.6, 5.0), (-10.0, 2.0)], "C_moss" if lv == 3 else "C_leaf", bevel=0.9, shine=0.3)
    c.tube([(-4.6, -0.5), (-4.8, 2.4), (-2.6, 3.6), (-0.2, 2.6), (0.0, -0.5)], 0.5, "C_bronze" if lv >= 4 else "C_iron", shine=0.3)
    c.plate([(-12.5, -6.4), (-2.0, -6.4), (mz - 3.0, -2.2), (mz - 3.0, -1.2), (-11.5, -0.8)], "C_bark", bevel=1.4, shine=0.15, tex=pgrain)
    c.tube([(-8.4, -7.0), (-9.8, -9.2), (-8.4, -10.2)], (0.85, 0.55), "C_iron", shine=0.35)
    c.tube([(-3.0, by), (mz, by)], 1.4 if lv < 5 else 1.7, bm, shine=0.4, tex=E.grain if bm == "C_bark" else None)
    ring(c, mz - 1.4, by, 2.1 if lv < 5 else 2.4, "C_bronze" if lv >= 4 else "C_iron", 1.4)
    if lv == 4:
        c.gem([(-1.0, by - 2.2), (3.0, by - 2.2), (3.0, by + 2.2), (-1.0, by + 2.2)], "C_amber", table=0.5, emis=True)
    if lv == 5:
        c.tube([(-1.0, by), (mz - 2.0, by)], 0.45, "C_spirit", glow=(6, 5, 4), sep=False, outline=False)
        c.plate([(mz - 4.0, by - 1.6), (mz - 1.0, by - 4.4), (mz + 0.6, by - 3.6), (mz - 2.0, by - 1.4)], "C_leaf", bevel=0.9, shine=0.3)
        c.sphere((mz + 0.6, by), 1.2, "C_spirit", glow=True)
        c.glint(mz - 6.0, by - 5.6, "C_spirit", 6)


STYLES = [
    ("A", "Zanaatkâr (mat, gerçekçi, işçilik)", [A_sword, A_fire, A_gun]),
    ("B", "Masal (yuvarlak, sevimli, motifli)", [B_sword, B_fire, B_gun]),
    ("C", "Orman (ilkel -> antik ruh ağacı)", [C_sword, C_fire, C_gun]),
]
ROWS = [("uzunkilic", "Uzunkılıç", "diag"), ("fire_staff", "Ateş Asası", "diag"), ("tabanca", "Tabanca", "horiz")]


def build():
    os.makedirs(OUT, exist_ok=True)
    gd = os.path.join(OUT, ".gdignore")
    if not os.path.exists(gd):
        open(gd, "w").close()
    imgs = {}
    for sid, _, fns in STYLES:
        for (key, _, fr), fn in zip(ROWS, fns):
            frame(fr)
            for lv in range(1, 6):
                cv = Cv(lv)
                fn(cv, lv)
                img = cv.render()
                img.save(os.path.join(OUT, "%s_%s_L%d.png" % (sid, key, lv)))
                a = img.getchannel("A").point(lambda v: 255 if v == 255 else 0).getbbox()
                if a and (a[0] == 0 or a[1] == 0 or a[2] == N or a[3] == N):
                    print("KENAR!", sid, key, lv, a)
                imgs[(sid, key, lv)] = img
    return imgs


def sheet(imgs, sid, title, z=4):
    cell = N * z
    lw, gap, top = 150, 14, 44
    W = lw + 5 * (cell + gap) + gap
    H = top + len(ROWS) * (cell + gap) + gap
    im = Image.new("RGBA", (W, H), (34, 38, 40, 255))
    d = ImageDraw.Draw(im)
    d.text((12, 10), "%s - %s" % (sid, title), fill=(235, 230, 215), font=font(20, True))
    for lv in range(1, 6):
        d.text((lw + gap + (lv - 1) * (cell + gap) + cell - 40, 14), "L%d" % lv, fill=(200, 196, 182), font=font(18, True))
    for ri, (key, label, _) in enumerate(ROWS):
        y0 = top + ri * (cell + gap)
        d.text((12, y0 + cell // 2 - 10), label, fill=(235, 230, 215), font=font(18, True))
        for lv in range(1, 6):
            x0 = lw + gap + (lv - 1) * (cell + gap)
            d.rectangle([x0, y0, x0 + cell - 1, y0 + cell - 1], fill=S.BG)
            im.alpha_composite(imgs[(sid, key, lv)].resize((cell, cell), Image.NEAREST), (x0, y0))
    im.convert("RGB").save(os.path.join(HERE, "silah48_stil_%s.png" % sid))


def context(imgs, styles=None, out=None):
    """Oyun ölçeği: 0,5 dünya px/piksel x zoom 2 = 1:1 (keskin), karakter gerçek ölçeğinde (0,903 dünya px), sonra x2."""
    styles = styles or STYLES
    zoom, wpp = 2.0, 0.5
    cwp = 2.2368375 * 0.8075 * 0.5
    chars = [Image.open(os.path.join(S.E.GAME, "assets/characters/%s/sheets/idle.png" % n)).convert("RGBA").crop((0, 0, 48, 48))
             for n in ("sovalye", "buyucu", "korsan")]
    cw, ch, lw, top = 56, 70, 150, 26
    cols = [(k, lv) for k, _, _ in ROWS for lv in (1, 3, 5)]
    W = lw + 3 * 80 + len(cols) * cw + 10
    H = top + len(styles) * (ch + 8)
    im = Image.new("RGB", (W, H), (34, 38, 40))
    d = ImageDraw.Draw(im)
    d.text((8, 4), "Oyun ölçeği (1 piksel = 1 ekran pikseli, zoom 2) - L1 / L3 / L5", fill=(235, 230, 215), font=font(13, True))
    for si, (sid, title, _) in enumerate(styles):
        y0 = top + si * (ch + 8)
        d.text((8, y0 + ch // 2 - 8), "%s - %s" % (sid, title.split(" (")[0]), fill=(235, 230, 215), font=font(13, True))
        pc = Image.new("RGB", (3 * 80 + len(cols) * cw, ch), S.BG)
        for i, chi in enumerate(chars):
            E.blit_world(pc, chi, 40 + i * 80, ch // 2, cwp, zoom)
        for i, (key, lv) in enumerate(cols):
            E.blit_world(pc, imgs[(sid, key, lv)], 240 + i * cw + cw // 2, ch // 2, wpp, zoom)
        im.paste(pc, (lw, y0))
    im.resize((W * 2, H * 2), Image.NEAREST).save(out or os.path.join(HERE, "silah48_stil_oyun.png"))


if __name__ == "__main__":
    imgs = build()
    for sid, title, _ in STYLES:
        sheet(imgs, sid, title)
    context(imgs)
    print("ok", len(imgs))
