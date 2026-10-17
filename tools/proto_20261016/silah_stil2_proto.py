# -*- coding: utf-8 -*-
"""Silah STİL prototipleri 2. tur (2026-10-16, oyuna bağlı DEĞİL). Kullanıcı (madde 175'teki A/B/C'den sonra): "daha fazla prototip
önerir misin biraz daha gösterişli olsun". Gösteriş = güçlü siluet + seviye başına TEK odak (yanan rün, taç, parlayan göz, oyma yüz);
süs yağmuru / çok halkalı hale YOK (madde 174 dersleri). Aynı 3 temsilci silah x 5 seviye:
  D Rün Ateşi        karartılmış demir + tunç, kazınmış rünler seviyeyle yanar (amber), L5 yanan kanal + monolit
  E Kraliyet         altın + kraliyet mavisi mine + kırmızı kurdele + inci; L4-5 kanat siper, zambak, TAÇ
  F Canavar Ganimeti boss avından parçalar: diş, boynuz, kürk, pul, kafatası; L5 ejderha (parlayan göz, ateş nefesi)
  G Balkabağı Gecesi ürpertici masal: kara demir, mor, kemik, hayalet yeşili; asa = oyma balkabağı (L5 taçlı)
Çıktılar: silah48_stil/<D|E|F|G>_<anahtar>_L<n>.png, silah48_stil_<D|E|F|G>.png (x4), silah48_stil2_oyun.png (oyun ölçeği 1:1 x2).
Çalıştırma: python tools/proto_20261016/silah_stil2_proto.py
"""
import math
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import silah_stil_proto as A  # noqa: E402  (A/B/C paletleri + yardımcılar)
from silah_proto48 import Cv, frame, LV, F1, F3, F5, flame, ring, pgrain, facet, E, P, hx, spike, ribbon, circle_pts, font, N  # noqa: E402
import silah_proto48 as S  # noqa: E402

OUT = A.OUT
bar, shiny, star_poly, blade_tex2 = A.bar, A.shiny, A.star_poly, A.blade_tex2

for _k, _v in {
    "D_iron": "#101216 #1e2228 #2c3038 #3c414a #50565f #686e78 #9aa0a8",
    "D_stone": "#121214 #222226 #323236 #44444a #58585e #6e6e74 #9a9aa0",
    "D_bronze": "#22140a #4a2c12 #6a421a #8a5a24 #a87430 #c69048 #e8c080",
    "D_rune": "#3a1604 #7a3406 #b85a0c #e8861a #fcb03c #ffd47e #fff4d4",
    "E_gold": "#2e1c04 #6a440a #9c6c14 #c8961e #e6b832 #f6d860 #fff6c0",
    "E_ivory": "#2c2620 #6a6052 #9a8e7c #c0b4a0 #ddd2bc #f0e8d6 #ffffff",
    "E_blue": "#060c2a #0e1c5c #182e8a #2444b4 #3a62d6 #6a90ee #c8daff",
    "E_red": "#200408 #4a0a14 #761220 #9c1c2c #c02c3a #de5258 #ffb0b0",
    "E_steel": "#1a1e28 #3a4252 #5a6476 #7c879a #a0aabc #c4ccda #f4f6fa",
    "E_pearl": "#2a2830 #6a6676 #9a96a8 #c2bed0 #e0dcec #f2f0f8 #ffffff",
    "F_horn": "#120c08 #261a12 #3a281c #503828 #6a4c36 #866448 #b08c6c",
    "F_fur": "#1e140c #3e2a18 #5a3e24 #765232 #926842 #ac8256 #cca47c",
    "F_tooth": "#2a261e #6a6252 #9c927c #c4baa2 #e2dac4 #f4eedc #ffffff",
    "F_eye": "#3a2a02 #7a5a06 #b88a0c #e8b81a #fcd844 #fff08a #ffffff",
    "F_scale": "#08161a #10282e #183c42 #225258 #2e6a6e #448886 #78b0a8",
    "G_wood": "#120c0a #22161a #322024 #442a2e #583838 #6e4846 #8e6660",
    "G_ghost": "#06221a #0c4434 #14684e #24906a #4cb88c #8ae0b4 #e0fff0",
    "G_purple": "#14081e #2a1240 #401c5e #582880 #72389e #9058be #c8a0e8",
    "G_pumpkin": "#2a0e02 #5e2206 #8e3a0a #c25a12 #e8801e #f8a43a #ffd690",
    "G_vine": "#0a160a #16301a #22441e #2e5a26 #3e7230 #548c40 #86b870",
}.items():
    P[_k] = [hx(c) for c in _v.split()]

GLY = [[(0, -1), (0, 0), (0, 1), (1, -1)], [(-1, -1), (0, 0), (1, -1), (0, 1)], [(0, -1), (0, 0), (0, 1), (-1, 0), (1, 1)],
       [(-1, 0), (0, -1), (1, 0), (0, 1)]]


def glyph(c, a, b, k, mat, glow=True):
    """Ekranda dik duran küçük rün damgası (ışıyorsa amber, değilse kazıma koyusu)."""
    x0, y0 = E.xy(a, b)
    pid = c._part(mat, False, glow, False)
    for dx, dy in GLY[k % len(GLY)]:
        c.pix[(int(x0) + dx, int(y0) + dy)] = [P[mat][5 if glow else 1], pid]


def scr(cx, cy, pts):
    """Ekran ofsetleri -> (a, b): çapraz çerçevede dik duran şekiller (taç, yüz) için."""
    return [E.ab(cx + dx, cy + dy) for dx, dy in pts]


def scr_pix(c, cx, cy, pts, mat, idx, glow=True):
    pid = c._part(mat, False, glow, False)
    for dx, dy in pts:
        c.pix[(int(cx) + dx, int(cy) + dy)] = [P[mat][idx], pid]


def pistol_base(c, wood, lockm, trim, mz, grain=True):
    grip = [(-5.0, -1.5), (-6.8, 4.0), (-8.6, 9.0), (-13.8, 10.2), (-15.2, 7.8), (-13.0, 2.0), (-12.5, -1.5)]
    c.plate(grip, wood, bevel=1.5, shine=0.15, tex=pgrain if grain else None)
    c.tube([(-4.6, -0.5), (-4.8, 2.4), (-2.6, 3.6), (-0.2, 2.6), (0.0, -0.5)], 0.5, trim, shine=0.3)
    c.tube([(-2.4, -0.5), (-2.9, 2.0)], 0.5, "A_iron", shine=0.3)
    c.plate([(-12.5, -6.4), (-2.0, -6.4), (mz - 3.0, -2.2), (mz - 3.0, -1.2), (-11.5, -0.8)], wood, bevel=1.4, shine=0.15,
            tex=pgrain if grain else None)
    c.plate([(-9.0, -7.2), (-4.0, -7.2), (-4.0, -4.6), (-9.0, -4.6)], lockm, bevel=1.0, shine=0.35)
    c.tube([(-8.4, -7.0), (-9.8, -9.2), (-8.4, -10.2)], (0.85, 0.55), "A_iron", shine=0.35)


def grip_and_pommel_line(c, pe, g, m, r=1.3):
    c.tube([(pe + 1.8, 0), (g - 0.8, 0)], r, m, tex=E.wrap, shine=0.12)


# ================================================================ D - RÜN ATEŞİ
def D_sword(c, lv):
    g, tip, w, pe = -11.0, LV(lv, 22, 30.5), LV(lv, 2.0, 3.0), LV(lv, -21, -27)
    tr = "A_iron" if lv == 1 else "D_bronze"
    grip_and_pommel_line(c, pe, g, "A_leather")
    c.gem([(pe - 1.2, 0), (pe + 1.0, -1.9), (pe + 3.0, 0), (pe + 1.0, 1.9)], tr, table=0.4, emis=False)
    if lv == 5:
        c.sphere((pe + 1.0, 0), 0.8, "D_rune", glow=True)
    b0 = g + 0.4
    L, tl = tip - b0, w * 2.0
    if lv <= 3:
        poly = [(b0, -w), (tip - tl, -w), (tip, 0), (tip - tl, w), (b0, w)]
    elif lv == 4:
        poly = [(b0, -w), (tip - tl * 1.6, -w), (tip, -w * 0.3), (tip - tl * 0.5, w), (b0, w)]
    else:
        poly = [(b0, -w * 0.9), (b0 + L * 0.7, -w * 1.15), (tip, 0), (b0 + L * 0.7, w * 1.15), (b0, w * 0.9)]
    c.plate(poly, "D_iron", bevel=1.2, shine=0.3, tex=blade_tex2())
    if lv == 5:
        c.tube([(b0 + 1.5, 0), (b0 + L * 0.8, 0)], 0.45, "D_rune", glow=(6, 5, 4), sep=False, outline=False)
    else:
        n = [0, 1, 2, 3, 3][lv]
        for i in range(n):
            glyph(c, b0 + 3.2 + i * (L * 0.62 / n), 0, i, "D_rune" if lv >= 3 else "D_iron", glow=lv >= 3)
    half = LV(lv, 3.4, 7.0)
    if lv <= 2:
        c.tube([(g, -half), (g, half)], 0.85 if lv == 1 else 1.0, tr, shine=0.4)
    else:
        for sg in (-1, 1):
            c.plate([(g - 1.2, sg * 1.0), (g + 1.4, sg * 1.6), (g + 1.0 + (1.8 if lv == 5 else 0.0), sg * half), (g - 0.8, sg * half * 0.92),
                     (g - 1.6, sg * half * 0.4)], tr, bevel=1.0, shine=0.35)
        c.gem([(g - 1.6, 0), (g, -1.6), (g + 1.6, 0), (g, 1.6)], "D_rune" if lv >= 4 else "D_stone", table=0.4, emis=lv >= 4)
    if lv == 5:
        c.star(tip - 4.0, -w - 2.6, "D_rune", 1)


def D_stone_poly(ca, cb, s, ln=1.0):
    return [(ca - 2.6 * s * ln, cb), (ca - 1.4 * s, cb - 2.0 * s), (ca + 1.6 * s, cb - 2.2 * s), (ca + 2.8 * s * ln, cb), (ca + 1.4 * s, cb + 2.2 * s),
            (ca - 1.6 * s, cb + 2.0 * s)]


def D_fire(c, lv):
    pe, hc = LV(lv, -27, -29), LV(lv, 14.5, 14.0)
    sm = ["", "A_wood", "A_wood", "D_iron", "D_iron", "D_iron"][lv]
    if lv >= 2:
        bar(c, pe + 0.4, pe + 2.4, (1.1, 1.5), "D_bronze", shine=0.4)
    bar(c, pe + 1.5, hc - 3.0, 1.25, sm, tex=E.grain if sm == "A_wood" else None, shine=0.3)
    if lv >= 2:
        c.tube([(-14, 0), (-8, 0)], 1.7, "A_leather", tex=E.wrap, shine=0.1)
    if lv >= 3:
        for a in (-15.0, -7.0):
            bar(c, a - 0.7, a + 0.3, 1.85, "D_bronze", shine=0.45)
    if lv == 1:
        c.gem(D_stone_poly(hc, 0, 1.1), "D_stone", table=0.45, emis=False)
        glyph(c, hc, 0, 0, "D_iron", glow=False)
        for k in range(3):
            c.tube([(hc - 3.2 + k * 1.1, -2.2), (hc - 2.8 + k * 1.1, 2.2)], 0.42, "A_rope", shine=0.2)
        return
    if lv == 2:
        flame(c, hc + 2.6, 6.0, 1.8, F1, mat="A_fire")
        bar(c, hc - 4.2, hc - 2.4, (1.4, 1.8), "D_bronze", shine=0.4)
        c.gem(D_stone_poly(hc, 0, 1.25), "D_stone", table=0.45, emis=False)
        glyph(c, hc, 0, 1, "D_rune")
        return
    if lv == 3:
        flame(c, hc + 2.4, 10.0, 2.8, F3, mat="A_fire")
        bar(c, hc - 4.6, hc - 2.6, (1.5, 1.9), "D_bronze", shine=0.4)
        c.gem(D_stone_poly(hc, 0, 1.4), "D_stone", table=0.45, emis=False)
        glyph(c, hc, 0, 2, "D_rune")
        for sg in (-1, 1):
            c.tube([(hc - 3.6, sg * 1.0), (hc - 2.0, sg * 3.4), (hc + 1.6, sg * 3.6), (hc + 3.2, sg * 2.2)], (0.9, 0.5), "D_bronze", shine=0.45)
        return
    if lv == 4:
        flame(c, hc - 0.5, 15.0, 3.6, F3, mat="A_fire")
        c.sphere((hc + 1.0, 0), 2.2, "A_fire", glow=True)
        c.tube(circle_pts(hc - 1.0, 0.0, 4.2, n=24)[6:19], 0.8, "D_bronze", shine=0.45)
        bar(c, hc - 6.0, hc - 4.0, (1.5, 1.9), "D_bronze", shine=0.4)
        for sg in (-1, 1):
            c.gem(D_stone_poly(hc + 1.0, sg * 6.8, 0.75), "D_stone", table=0.45, emis=False)
            glyph(c, hc + 1.0, sg * 6.8, 3 if sg < 0 else 1, "D_rune")
        return
    # L5 monolit + alev tacı
    flame(c, hc + 5.0, 12.0, 3.8, F5, mat="A_fire")
    bar(c, hc - 6.4, hc - 4.2, (1.6, 2.1), "D_bronze", shine=0.45)
    c.gem([(hc - 4.4, 0), (hc - 2.6, -2.8), (hc + 4.2, -3.0), (hc + 6.0, 0), (hc + 4.2, 3.0), (hc - 2.6, 2.8)], "D_stone", table=0.5, emis=False)
    glyph(c, hc - 1.2, 0, 0, "D_rune")
    glyph(c, hc + 2.6, 0, 2, "D_rune")
    for sg in (-1, 1):
        c.gem(D_stone_poly(hc + 2.0, sg * 7.4, 0.62), "D_stone", table=0.45, emis=False)
        glyph(c, hc + 2.0, sg * 7.4, 3, "D_rune")


def D_gun(c, lv):
    by = -3.5
    if lv == 1:
        bar(c, -19.0, -2.0, 1.25, "A_wood", tex=E.grain, shine=0.2)
        c.tube([(-6.0, -2.6), (9.0, -2.6)], 2.0, "D_iron", shine=0.35)
        ring(c, 7.6, -2.6, 2.5, "D_iron", 1.4)
        glyph(c, 1.5, -2.6, 0, "D_iron", glow=False)
        for a in (-4.5,):
            ring(c, a, -1.4, 2.4, "A_rope", 1.2)
        return
    mz, br = [0, 0, 10.0, 13.0, 14.5, 15.5][lv], [0, 0, 1.3, 1.4, 1.8, 2.0][lv]
    pistol_base(c, "A_dwood", "D_bronze" if lv >= 3 else "D_iron", "D_bronze", mz)
    glyph(c, -6.5, -5.9, 1, "D_rune" if lv >= 2 else "D_iron", glow=lv >= 2)
    c.tube([(-3.0, by), (mz, by)], br, "D_iron", shine=0.4)
    if lv >= 3:
        c.tube([(-1.0, by), (mz - 2.4, by)], 0.45, "D_rune", glow=(6, 5, 4), sep=False, outline=False)
    if lv == 4:
        for a in (2.0, 8.0):
            ring(c, a, by, br + 0.6, "D_rune", 1.2)
            c.halo("D_rune")
    if lv == 5:
        c.plate([(mz - 4.0, by - 3.2), (mz + 1.0, by - 3.2), (mz + 1.0, by + 3.2), (mz - 4.0, by + 3.2)], "D_iron", bevel=1.2, shine=0.35)
        c.sphere((mz + 0.4, by), 1.5, "D_rune", glow=True)
        for sg in (-1, 1):
            c.plate([(-1.0, by + sg * br), (3.0, by + sg * (br + 2.4)), (7.0, by + sg * br)], "D_bronze", bevel=1.0, shine=0.35)
    ring(c, mz - 1.4, by, br + 0.5, "D_bronze" if lv >= 2 else "D_iron", 1.4)


# ================================================================ E - KRALİYET
def E_sword(c, lv):
    g, tip, w, pe = -11.0, LV(lv, 22, 30.5), LV(lv, 2.0, 2.8), LV(lv, -21, -26.5)
    grip_and_pommel_line(c, pe, g, "E_blue")
    if lv >= 2:
        bar(c, g - 2.2, g - 1.2, 1.5, "E_gold", shine=0.45)
    if lv == 5:
        crown = [(pe + 2.6, -2.4), (pe + 0.4, -2.6), (pe - 2.0, -2.9), (pe - 0.6, -1.2), (pe - 2.6, 0), (pe - 0.6, 1.2), (pe - 2.0, 2.9), (pe + 0.4, 2.6),
                 (pe + 2.6, 2.4)]
        c.plate(crown, "E_gold", bevel=1.0, shine=0.4)
        shiny(c, pe + 1.0, 0, 0.9, "E_red")
    else:
        pm = ["", "A_iron", "E_gold", "E_pearl", "E_gold"][lv]
        c.sphere((pe + 1.2, 0), LV(lv, 1.5, 2.1), pm, shine=0.5)
        if lv == 4:
            shiny(c, pe + 1.2, 0, 0.9, "E_blue")
    b0 = g + 0.4
    L, tl = tip - b0, w * 2.0
    bm = "E_ivory" if lv == 5 else "E_steel"
    poly = [(b0, -w), (tip - tl, -w), (tip, 0), (tip - tl, w), (b0, w)] if lv < 5 else \
        [(b0, -w * 0.9), (b0 + L * 0.6, -w * 1.1), (tip, 0), (b0 + L * 0.6, w * 1.1), (b0, w * 0.9)]
    c.plate(poly, bm, bevel=1.2, shine=0.3, tex=blade_tex2(edge="E_gold" if lv >= 4 else None, fuller=lv == 3))
    if lv >= 4:
        c.plate([(g - 0.6, 1.4), (g - 3.6, 4.0), (g - 7.6, 3.6), (g - 6.2, 5.4), (g - 9.4, 6.4), (g - 4.0, 6.6), (g - 1.2, 3.6)], "E_red", bevel=1.0, shine=0.3)
    half = LV(lv, 3.4, 6.8)
    if lv == 1:
        c.tube([(g, -half), (g, half)], 0.85, "A_iron", shine=0.35)
    elif lv == 2:
        c.tube([(g, -half), (g, half)], 0.95, "E_gold", shine=0.45)
        for sg in (-1, 1):
            c.sphere((g, sg * half), 1.2, "E_gold", shine=0.5)
    elif lv == 3:
        c.plate([(g - 1.4, -half), (g + 1.4, -half), (g + 1.4, half), (g - 1.4, half)], "E_gold", bevel=1.0, shine=0.4)
        c.plate([(g - 0.7, -half + 0.8), (g + 0.7, -half + 0.8), (g + 0.7, half - 0.8), (g - 0.7, half - 0.8)], "E_blue", bevel=0.8, shine=0.4)
    elif lv == 4:
        for sg in (-1, 1):
            c.plate([(g - 1.0, sg * 1.2), (g + 1.2, sg * 2.4), (g + 3.6, sg * half), (g + 1.4, sg * half * 0.9), (g - 1.2, sg * half * 0.6)], "E_gold", bevel=1.1, shine=0.4)
        shiny(c, g, 0, 1.3, "E_blue")
    else:
        bar(c, g - 1.2, g + 0.2, 2.4, "E_gold", shine=0.45)
        for sg in (-1, 1):
            c.tube([(g, sg * 1.2), (g + 0.5, sg * 3.6), (g + 2.5, sg * 5.8), (g + 4.6, sg * 5.2), (g + 4.0, sg * 3.6)], (1.35, 0.6), "E_gold", shine=0.45)
        c.plate([(g - 0.6, -1.3), (g + 2.6, -1.7), (g + 5.4, 0), (g + 2.6, 1.7), (g - 0.6, 1.3)], "E_gold", bevel=1.0, shine=0.45)
        shiny(c, g + 1.2, 0, 1.1, "E_blue")
        c.star(tip - 4.0, -w - 2.6, "E_gold", 1)


def E_fire(c, lv):
    pe, hc = LV(lv, -26.5, -28.5), LV(lv, 15.0, 15.5)
    rod = "A_wood" if lv == 1 else "E_ivory"
    if lv >= 2:
        c.sphere((pe + 1.2, 0), 1.6, "E_gold", shine=0.5)
    bar(c, pe + 1.6, hc - 3.0, 1.2, rod, tex=E.grain if lv == 1 else None, shine=0.35)
    for a in [[], [-6.0], [-16.0, -6.0], [-16.0, -6.0, 4.0], [-16.0, -6.0, 4.0]][lv - 1]:
        bar(c, a - 0.7, a + 0.5, 1.75, "E_gold", shine=0.5)
    if lv >= 4:
        shiny(c, -6.0, -1.8, 0.8, "E_blue")
    if lv == 1:
        c.plate([(hc - 3.0, -1.4), (hc + 0.6, -2.8), (hc + 1.4, -2.8), (hc + 1.4, 2.8), (hc + 0.6, 2.8), (hc - 3.0, 1.4)], "E_gold", bevel=1.2, shine=0.4)
        flame(c, hc + 1.0, 7.0, 2.4, F1, mat="A_fire")
        return
    if lv == 2:
        flame(c, hc + 2.2, 7.0, 2.0, F1, mat="A_fire")
        c.sphere((hc, 0), 2.6, "E_gold", shine=0.5)
        bar(c, hc + 2.0, hc + 3.0, 0.9, "E_gold", shine=0.5)
        return
    if lv == 3:
        flame(c, hc + 4.0, 8.0, 2.2, F1, mat="A_fire")
        c.sphere((hc, 0), 3.4, "E_blue", shine=0.5)
        c.tube([(hc - 3.4, 0), (hc + 3.4, 0)], 0.6, "E_gold", shine=0.5)
        c.tube(circle_pts(hc, 0.0, 3.4, n=24, ra=1.4), 0.55, "E_gold", shine=0.5)
        facet(c, spike((hc + 3.0, 0), (hc + 5.2, 0), 0.9), "E_gold")
        return
    R = 4.0 if lv == 4 else 5.0
    flame(c, hc - 0.5, R + (9.0 if lv == 4 else 12.0), R * 0.85, F3 if lv == 4 else F5, mat="A_fire")
    bar(c, hc - 4.4, hc - 2.4, (1.6, 2.0), "E_gold", shine=0.45)
    crown = [(hc - 2.6, -R), (hc + 2.8, -R - 0.8), (hc + 1.0, -R * 0.45), (hc + 3.4, 0), (hc + 1.0, R * 0.45), (hc + 2.8, R + 0.8), (hc - 2.6, R)]
    c.plate(crown, "E_gold", bevel=1.2, shine=0.45)
    shiny(c, hc - 1.0, 0, 1.2, "E_blue")
    if lv == 5:
        for sg in (-1, 1):
            shiny(c, hc - 1.0, sg * R * 0.62, 0.8, "E_red")
            c.glint(hc + 2.8, sg * (R + 0.8), "E_pearl", 6)
        c.plate([(hc - 3.4, 1.6), (hc - 6.4, 4.2), (hc - 10.4, 3.8), (hc - 9.0, 5.6), (hc - 12.2, 6.6), (hc - 6.8, 6.8), (hc - 3.8, 3.8)], "E_red", bevel=1.0, shine=0.3)
        c.star(hc + R + 6.0, -R - 2.0, "E_gold", 1)


def E_gun(c, lv):
    by = -3.5
    mz = LV(lv, 10.0, 15.5)
    wood = ["", "A_wood", "A_dwood", "E_blue", "E_ivory", "E_ivory"][lv]
    trim = "A_iron" if lv == 1 else "E_gold"
    pistol_base(c, wood, trim, trim, mz, grain=lv <= 2)
    if lv >= 3:
        c.sphere((-10.4, 4.0), 1.6, "E_gold", shine=0.5)
        shiny(c, -10.4, 4.0, 0.8, "E_blue" if lv < 5 else "E_red")
    bm = "E_gold" if lv >= 4 else "E_steel"
    c.tube([(-3.0, by), (mz - 1.0, by)], 1.4, bm, shine=0.45)
    if lv >= 4:
        c.plate([(mz - 2.0, by - 1.4), (mz + 1.2, by - 3.0), (mz + 1.2, by + 3.0), (mz - 2.0, by + 1.4)], "E_gold", bevel=1.1, shine=0.45)
    else:
        ring(c, mz - 1.4, by, 2.0, trim, 1.4)
    if lv >= 2:
        ring(c, 2.0, by, 2.0, "E_gold", 1.0)
    if lv == 5:
        crown = [(-12.0, 10.0), (-15.0, 10.6), (-16.4, 13.4), (-14.6, 12.4), (-14.0, 14.4), (-12.6, 12.2), (-11.0, 13.6), (-11.4, 10.6)]
        c.plate(crown, "E_gold", bevel=0.9, shine=0.45)
        A.tassel(c, -9.2, 9.6, "E_red", cord="E_gold", ln=2.6)
        c.star(mz - 5.0, by - 4.4, "E_gold", 1)


# ================================================================ F - CANAVAR GANİMETİ
def teeth(c, a0, a1, n, side_b, out, mat="F_tooth", w=0.7):
    for i in range(n):
        a = a0 + (a1 - a0) * (i + 0.5) / n
        facet(c, spike((a - 0.4, side_b), (a + 0.9, side_b + out), w, shoulder=0.2), mat)


def F_sword(c, lv):
    g, tip, w, pe = -11.0, LV(lv, 22, 30), LV(lv, 2.0, 2.7), LV(lv, -21, -26)
    grip_and_pommel_line(c, pe, g, "F_fur" if lv < 4 else "F_scale")
    if lv <= 2:
        c.sphere((pe + 1.2, 0), 1.6, "C_bone", shine=0.3)
    else:
        for sg in (-1, 0, 1):
            facet(c, spike((pe + 1.6, sg * 0.9), (pe - LV(lv, 1.8, 3.0), sg * 2.4), 0.7), "F_tooth" if lv < 4 else "F_horn")
        c.sphere((pe + 1.4, 0), 1.5, "F_horn", shine=0.4)
    b0 = g + 0.4
    L, tl = tip - b0, w * 2.0
    bm = ["", "A_iron", "A_iron", "C_bone", "A_iron", "D_iron"][lv]
    if lv == 3:
        poly = [(b0, -w), (b0 + L * 0.6, -w * 1.1), (tip, -w * 0.2), (tip - 2.0, w * 0.6), (b0 + L * 0.5, w * 0.9), (b0, w)]
    elif lv == 5:
        poly = [(b0, -w), (b0 + L * 0.55, -w * 1.15), (tip, -w * 0.3), (tip - 1.2, w * 0.5), (b0 + L * 0.55, w * 1.15), (b0, w)]
    else:
        poly = [(b0, -w), (tip - tl, -w), (tip, 0), (tip - tl, w), (b0, w)]
    c.plate(poly, bm, bevel=1.2, shine=0.3, tex=blade_tex2())
    if lv == 2:
        teeth(c, b0 + 4.0, b0 + L * 0.75, 3, w - 0.2, 2.2, w=0.85)
    elif lv == 3:
        teeth(c, b0 + 2.0, b0 + L * 0.8, 5, -w + 0.2, -2.1, w=0.85)
    elif lv >= 4:
        n = 3 if lv == 4 else 4
        teeth(c, b0 + 2.5, b0 + L * 0.78, n, -w + 0.2, -2.2, w=0.85)
        teeth(c, b0 + 3.5, b0 + L * 0.78, n, w - 0.2, 2.2, w=0.85)
    if lv <= 2:
        c.tube([(g, -LV(lv, 3.4, 4.0)), (g, LV(lv, 3.4, 4.0))], 0.95, "A_iron" if lv == 1 else "C_bone", shine=0.35)
    elif lv == 3:
        for sg in (-1, 1):
            c.tube([(g, sg * 1.0), (g - 0.6, sg * 3.0), (g + 1.0, sg * 4.6), (g + 2.6, sg * 4.0)], (1.2, 0.45), "F_horn", shine=0.4)
    elif lv == 4:
        for sg in (-1, 1):
            c.tube([(g, sg * 1.2), (g - 1.2, sg * 4.0), (g + 1.4, sg * 7.0), (g + 4.6, sg * 7.4)], (1.6, 0.35), "F_horn", shine=0.4)
    else:
        skull(c, g - 1.0, 1.05, eyes="F_eye", dragon=True)


def skull(c, ca, s, eyes=None, horns=False, dragon=False):
    """Yukarıdan kafatası, burun +a yönünde."""
    if horns and not dragon:
        for sg in (-1, 1):
            c.tube([(ca - 0.6 * s, sg * 2.0 * s), (ca - 2.8 * s, sg * 3.6 * s), (ca - 4.6 * s, sg * 2.4 * s), (ca - 3.8 * s, sg * 0.9 * s),
                    (ca - 2.4 * s, sg * 1.5 * s)], (1.3 * s, 0.5), "F_horn", shine=0.4)
    if dragon:
        for sg in (-1, 1):
            facet(c, spike((ca - 0.6 * s, sg * 1.6 * s), (ca - 6.0 * s, sg * 4.4 * s), 1.0 * s), "F_horn")
            facet(c, spike((ca + 0.4 * s, sg * 2.0 * s), (ca - 3.0 * s, sg * 4.8 * s), 0.7 * s), "F_horn")
    snout = 4.2 if dragon else 3.2
    c.plate([(ca, -1.9 * s), (ca + snout * s, -1.1 * s), (ca + (snout + 0.8) * s, 0), (ca + snout * s, 1.1 * s), (ca, 1.9 * s)], "C_bone", bevel=1.2, shine=0.3)
    c.sphere((ca - 0.4 * s, 0), 2.5 * s, "C_bone", shine=0.3)
    for sg in (-1, 1):
        if eyes:
            c.sphere((ca + 0.6 * s, sg * 1.25 * s), 0.75 * s, eyes, glow=True)
        else:
            c.sphere((ca + 0.6 * s, sg * 1.25 * s), 0.6 * s, "F_horn", shine=0.0)


def F_fire(c, lv):
    pe, hc = LV(lv, -27, -29), LV(lv, 12.0, 10.0)
    bar(c, pe + 1.5, hc - 2.4, 1.25, "A_wood" if lv < 4 else "F_horn", tex=E.grain if lv < 4 else None, shine=0.3)
    if lv >= 2:
        c.tube([(-14, 0), (-8, 0)], 1.8, "F_fur", tex=E.wrap, shine=0.1)
    if lv == 1:
        c.sphere((hc + 1.0, 0), 2.0, "A_fire", glow=True)
        flame(c, hc + 1.4, 6.0, 1.8, F1, mat="A_fire")
        for sg in (-1, 1):
            c.tube([(hc - 2.4, sg * 0.6), (hc - 0.4, sg * 2.6), (hc + 2.6, sg * 2.2), (hc + 3.4, sg * 1.0)], (0.9, 0.3), "F_tooth", shine=0.4)
        return
    s = [0, 0, 1.0, 1.2, 1.35, 1.5][lv]
    if lv >= 3:
        flame(c, hc + (3.6 if lv < 5 else 4.6) * s, LV(lv, 9.0, 14.0), LV(lv, 2.4, 3.6), F3 if lv < 5 else F5, mat="A_fire")
    if lv >= 4:
        fur = [(hc - 2.6 * s, -3.0 * s), (hc - 5.6 * s, -3.8 * s), (hc - 4.2 * s, -2.0 * s), (hc - 6.4 * s, -1.0 * s), (hc - 4.6 * s, 0),
               (hc - 6.4 * s, 1.0 * s), (hc - 4.2 * s, 2.0 * s), (hc - 5.6 * s, 3.8 * s), (hc - 2.6 * s, 3.0 * s)]
        c.plate(fur, "F_fur", bevel=1.0, shine=0.25)
    skull(c, hc, s, eyes="A_fire" if lv >= 2 else None, horns=lv in (3, 4), dragon=lv == 5)


def F_gun(c, lv):
    by = -3.5
    mz = LV(lv, 10.0, 13.5)
    wood = ["", "C_bone", "C_bone", "F_horn", "F_horn", "F_scale"][lv]
    pistol_base(c, wood, "A_iron", "A_iron" if lv < 3 else "C_bone", mz, grain=False)
    if lv >= 3:
        c.tube([(-8.0, 1.8), (-12.0, 4.6)], 1.6, "F_fur", tex=E.wrap, shine=0.1)
    c.tube([(-3.0, by), (mz, by)], 1.4, "A_iron" if lv < 5 else "F_scale", shine=0.4)
    if lv == 2:
        for sg in (-1, 1):
            facet(c, spike((mz - 1.4, by + sg * 1.2), (mz + 1.0, by + sg * 3.2), 0.7), "F_tooth")
    if lv == 3:
        teeth(c, 0.0, mz - 2.0, 3, by - 1.2, -1.8)
    if lv == 4:
        for sg in (-1, 1):
            c.plate([(mz - 6.0, by + sg * 1.0), (mz - 1.0, by + sg * 3.4), (mz + 2.4, by + sg * 2.4), (mz + 2.0, by + sg * 1.4), (mz - 5.0, by + sg * 0.6)], "F_horn", bevel=1.0, shine=0.35)
            teeth(c, mz - 3.6, mz + 1.4, 2, by + sg * 1.6, -sg * 1.4)
    if lv == 5:
        head = [(mz - 7.0, by - 3.8), (mz - 1.0, by - 4.4), (mz + 4.4, by - 2.0), (mz + 4.8, by + 0.6), (mz + 2.0, by + 3.2), (mz - 5.0, by + 3.6)]
        for sg in (-1, 1):
            facet(c, spike((mz - 4.4, by - 2.4), (mz - 10.0, by - 6.8 + (0 if sg < 0 else 2.2)), 0.8), "F_horn")
        c.plate(head, "F_scale", bevel=1.4, shine=0.35)
        teeth(c, mz - 1.0, mz + 2.6, 2, by + 0.8, 1.4)
        c.sphere((mz - 2.4, by - 1.8), 1.1, "F_eye", glow=True)
        c.sphere((mz + 5.0, by + 0.4), 1.2, "A_fire", glow=True)


# ================================================================ G - BALKABAĞI GECESİ
def G_sword(c, lv):
    g, tip, w, pe = -11.0, LV(lv, 21, 29.5), LV(lv, 2.0, 2.6), LV(lv, -21, -26)
    grip_and_pommel_line(c, pe, g, "A_rope" if lv == 1 else "G_purple")
    if lv >= 4:
        cx, cy = E.xy(pe + 1.2, 0)
        c.sphere((pe + 1.2, 0), 2.1, "C_bone", shine=0.3)
        scr_pix(c, cx, cy, [(-1, 0), (1, 0)], "G_ghost" if lv == 5 else "F_horn", 5 if lv == 5 else 1, glow=lv == 5)
    else:
        c.sphere((pe + 1.2, 0), 1.6, "D_iron" if lv > 1 else "A_iron", shine=0.4)
    b0 = g + 0.4
    L = tip - b0
    poly = [(b0, -w), (b0 + L * 0.5, -w * 1.35), (b0 + L * 0.85, -w * 1.3), (tip, w * 0.2), (b0 + L * 0.8, w * 0.9), (b0, w * 0.9)]
    if lv == 5:
        c.plate(poly, "G_ghost", bevel=1.4, shine=0.3, tex=blade_tex2(), emis=True)
        c.tube([(b0, w * 0.75), (b0 + L * 0.8, w * 0.75), (tip - 0.4, w * 0.15)], 0.7, "D_iron", shine=0.4)
    else:
        bm = ["", "A_iron", "D_iron", "D_iron", "D_iron"][lv]
        c.plate(poly, bm, bevel=1.2, shine=0.3, tex=blade_tex2(edge="G_ghost" if lv >= 3 else None, rust=lv == 1))
        if lv >= 3:
            c.halo("G_ghost")
    half = LV(lv, 3.2, 5.6)
    if lv <= 2:
        c.tube([(g, -half), (g, half)], 0.9, "D_iron" if lv == 2 else "A_iron", shine=0.35)
    else:
        for sg in (-1, 1):
            c.tube([(g, sg * 1.0), (g + 0.6, sg * half * 0.6), (g - 0.6, sg * half), (g - 2.0, sg * half * 0.8)], (1.1, 0.5), "C_bone", shine=0.35)
        c.sphere((g, 0), 1.5, "G_purple", shine=0.5)
    if lv >= 4:
        c.tube([(g + 1.0, -half - 0.6), (g - 1.4, -half - 2.4), (g - 4.0, -half - 2.0), (g - 5.6, -half - 3.4)], (0.8, 0.3), "G_ghost", glow=(6, 5, 4), sep=False, outline=False)


def pumpkin(c, hc, r, face=True, ghost=False):
    cx, cy = E.xy(hc, 0)

    def rib(idx, a, b, x, y, vl):
        if int(round(x - cx)) % 3 == 0 and vl < 0.9:
            return max(1, idx - 1)
        return idx

    c.sphere((hc, 0), r, "G_pumpkin", shine=0.35, tex=rib)
    (a0, b0), (a1, b1) = E.ab(cx, cy - r + 0.4), E.ab(cx + 1.4, cy - r - 2.2)
    c.tube([(a0, b0), (a1, b1)], 0.75, "G_vine", shine=0.3)
    if face:
        if r < 4.0:
            pts = [(-2, -1), (1, -1), (-2, 1), (-1, 1), (0, 2), (1, 1)]
        else:
            pts = [(-2, -2), (-3, -1), (-2, -1), (-1, -1), (2, -2), (1, -1), (2, -1), (3, -1), (0, 0),
                   (-3, 2), (-2, 2), (0, 2), (2, 2), (3, 2), (-2, 3), (-1, 3), (1, 3), (2, 3)]
        scr_pix(c, cx, cy, pts, "G_ghost" if ghost else "G_pumpkin", 6)


def G_fire(c, lv):
    pe, hc = LV(lv, -27, -29), LV(lv, 15.0, 14.5)
    R = [0, 2.6, 3.6, 4.2, 4.6, 5.0][lv]
    bar(c, pe + 1.5, hc - R, 1.25, "A_wood" if lv == 1 else "G_wood", tex=E.grain, shine=0.3)
    if lv >= 2:
        c.tube([(-14, 0), (-8, 0)], 1.75, "G_purple", tex=E.wrap, shine=0.1)
    if lv >= 3:
        c.tube(A.wavy(hc - R - 9.0, hc - R + 0.5, 1.4, 4.5), 0.55, "G_vine", shine=0.3)
        c.plate([(hc - R - 4.0, 1.4), (hc - R - 6.4, 4.0), (hc - R - 3.6, 4.8), (hc - R - 2.6, 2.4)], "G_vine", bevel=0.9, shine=0.3)
    if lv == 1:
        pumpkin(c, hc, R, face=False)
        flame(c, hc + R - 0.6, 5.0, 1.6, F1, mat="A_fire")
        return
    if lv >= 4:
        flame(c, hc + R - 1.0, LV(lv, 8.0, 9.0), R * 0.7, F3, mat="G_ghost" if lv == 4 else "A_fire")
    pumpkin(c, hc, R, face=True, ghost=lv == 4)
    if lv == 5:
        cx, cy = E.xy(hc, 0)
        crown = [(-4.4, 0.6), (-5.0, -4.0), (-2.4, -2.0), (0, -5.4), (2.4, -2.0), (5.0, -4.0), (4.4, 0.6)]
        c.plate(scr(cx, cy - R + 0.4, crown), "E_gold", bevel=1.0, shine=0.45)
        (ga, gb) = E.ab(cx, cy - R - 1.4)
        shiny(c, ga, gb, 0.9, "G_purple")
        c.halo("G_pumpkin")


def G_gun(c, lv):
    by = -3.5
    mz = LV(lv, 10.0, 14.5)
    wood = ["", "A_wood", "G_wood", "C_bone", "G_wood", "G_wood"][lv]
    pistol_base(c, wood, "D_iron" if lv > 1 else "A_iron", "D_iron" if lv > 1 else "A_iron", mz, grain=lv != 3)
    if lv >= 2:
        c.tube([(-8.4, 2.2), (-11.6, 6.4)], 1.5, "G_purple", tex=E.wrap, shine=0.1)
    c.tube([(-3.0, by), (mz - 2.0, by)], 1.4, "D_iron" if lv > 1 else "A_iron", shine=0.4)
    c.plate([(mz - 2.6, by - 1.4), (mz + 0.8, by - 3.2), (mz + 0.8, by + 3.2), (mz - 2.6, by + 1.4)], "D_iron" if lv > 1 else "A_iron", bevel=1.1, shine=0.35)
    if lv == 3:
        ring(c, mz - 0.6, by, 3.3, "G_ghost", 1.0)
        c.halo("G_ghost")
    if lv >= 4:
        c.sphere((-14.6, 9.6), 2.0, "C_bone", shine=0.3)
        cx, cy = E.xy(-14.6, 9.6)
        scr_pix(c, cx, cy, [(-1, 0), (1, 0)], "G_ghost" if lv == 5 else "F_horn", 5 if lv == 5 else 1, glow=lv == 5)
        flame(c, mz + 0.6, LV(lv, 4.0, 6.5), 2.2, F1, mat="G_ghost", cap=22.5)
    if lv == 5:
        c.tube([(-1.0, by), (mz - 3.0, by)], 0.45, "G_ghost", glow=(6, 5, 4), sep=False, outline=False)


STYLES = [
    ("D", "Rün Ateşi (yanan rünler)", [D_sword, D_fire, D_gun]),
    ("E", "Kraliyet (altın, mine, taç)", [E_sword, E_fire, E_gun]),
    ("F", "Canavar Ganimeti (diş, boynuz, kafatası)", [F_sword, F_fire, F_gun]),
    ("G", "Balkabağı Gecesi (ürpertici masal)", [G_sword, G_fire, G_gun]),
]


def build():
    os.makedirs(OUT, exist_ok=True)
    imgs = {}
    for sid, _, fns in STYLES:
        for (key, _, fr), fn in zip(A.ROWS, fns):
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


if __name__ == "__main__":
    imgs = build()
    for sid, title, _ in STYLES:
        A.sheet(imgs, sid, title)
    A.context(imgs, STYLES, os.path.join(HERE, "silah48_stil2_oyun.png"))
    print("ok", len(imgs))
