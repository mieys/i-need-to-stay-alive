# -*- coding: utf-8 -*-
"""ZANAATKÂR silah seti: 15 silah x 5 seviye, 48x48 (2026-10-16, oyuna bağlı DEĞİL). Kullanıcı madde 175'teki yönlerden A'yı seçti:
"zanaatkar prototiplerini tüm silahlar için yapıp gösterir misin".

Seviye = işçilik (tablo TA tek yer):
  1 Paslı      paslı demir, ip sargı, kaba ahşap, taş yok
  2 Demir      temiz demir, deri sap
  3 Çelik      çelik + pirinç süs
  4 Kara Çelik karartılmış çelik + gümüş + kırmızı kumaş (püskül/sargı)
  5 Yadigâr    çelik + altın + lal taşı, tek ışıltı
Işıma yalnız gerçekten ışıyan yerde (alev, kıvılcım, büyü kristali); silüetler silah başına ayrı (asalar: fener / paratoner + cam
yalıtkan / gök küresi halkaları / kristal mızrak). Uzunkılıç, Ateş Asası, Tabanca silah_stil_proto.py'deki A_* çizimleri.

Çıktılar: silah48_zanaat/<anahtar>_L<n>.png, silah48_zanaat_sayfa_<1..3>.png (x4), silah48_zanaat_ozet.png (x2),
silah48_zanaat_oyun.png (oyun ölçeği: 0,5 dünya px/piksel, zoom 2 -> 1:1, resim x2). Tek silah: python silah_zanaat_proto.py yay
"""
import math
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import silah_stil_proto as A  # noqa: E402
import silah_proto48 as S  # noqa: E402
from silah_proto48 import Cv, frame, LV, F1, F3, F5, flame, ring, pgrain, facet, E, P, hx, spike, ribbon, circle_pts, font, N  # noqa: E402

OUT = os.path.join(HERE, "silah48_zanaat")
bar, shiny, blade_tex2, tassel = A.bar, A.shiny, A.blade_tex2, A.tassel

for _k, _v in {
    "A_amethyst": "#1a0e22 #34204a #4c2e6a #66408a #8058a6 #a07cc4 #dcc8f0",
    "A_ice": "#1a2a36 #2e4a5e #44687e #5e8aa0 #80aec0 #a8d0dc #e8f8fc",
    "A_reed": "#2a2414 #50482a #6e643c #8a8050 #a49a66 #bcb27e #d8d0a4",
    "A_paper": "#2a2218 #54483a #7a6c58 #9c8e78 #b8ab94 #d0c6b0 #ece6d6",
    "A_copper": "#2a140c #50281a #6e3a24 #8a4e30 #a6643e #be7c52 #dca282",
    "A_bolt": "#3a2e08 #7a640e #b49a1c #dcc23a #f2dc6a #fcf0a8 #ffffff",
    "A_string": "#2a2620 #5a554c #827c70 #a49e92 #c0bab0 #d8d2c8 #f0ece4",
}.items():
    P[_k] = [hx(c) for c in _v.split()]

TA = {
    1: dict(name="Paslı", m="A_iron", tr="A_iron", wd="A_wood", gr="A_rope"),
    2: dict(name="Demir", m="A_iron", tr="A_iron", wd="A_wood", gr="A_leather"),
    3: dict(name="Çelik", m="A_steel", tr="A_brass", wd="A_wood", gr="A_leather"),
    4: dict(name="Kara Çelik", m="A_black", tr="A_silver", wd="A_dwood", gr="A_cloth"),
    5: dict(name="Yadigâr", m="A_steel", tr="A_gold", wd="A_dwood", gr="A_leather"),
}


def rust_tex(lv, base=None):
    """Tüp dokusu: L1'de pas lekeleri (base verilirse önce o doku)."""
    def f(idx, a, b, x, y, s, v):
        if base is not None:
            idx = base(idx, a, b, x, y, s, v)
        if lv == 1 and S.hsh(x // 2, y // 2, 13) < 0.3:
            return P["A_rust"][max(2, min(5, idx))]
        return idx
    return f


def glint5(c, lv, a, b, mat="A_steel"):
    if lv == 5:
        c.glint(a, b, mat, 6)


# ---------------------------------------------------------------- BIÇAK (çapraz)
def A_dagger(c, lv):
    t = TA[lv]
    g, tip, w, pe = -7.0, LV(lv, 14, 25), LV(lv, 2.3, 3.3), LV(lv, -15, -20)
    if lv == 1:
        bar(c, pe + 0.6, g - 0.6, 1.4, "A_wood", tex=E.grain, shine=0.2)
        bar(c, g - 1.6, g - 0.4, 1.6, "A_iron", shine=0.35)
    else:
        c.tube([(pe + 1.6, 0), (g - 0.8, 0)], 1.25, t["gr"], tex=E.wrap, shine=0.1)
        if lv == 4:
            c.tube(circle_pts(pe + 0.2, 0, 1.7, n=16), 0.55, t["tr"], shine=0.45)
        else:
            c.sphere((pe + 1.2, 0), LV(lv, 1.5, 2.0), t["tr"], shine=0.45)
        if lv == 5:
            shiny(c, pe + 1.2, 0, 0.8, "A_garnet")
    b0 = g + 0.4
    L = tip - b0
    if lv == 1:
        poly = [(b0, -w * 0.9), (b0 + L * 0.55, -w), (tip, w * 0.35), (b0 + L * 0.7, w * 0.75), (b0, w * 0.75)]
    elif lv == 2:
        poly = [(b0, -w), (b0 + L * 0.3, -w * 0.95), (tip, 0), (b0 + L * 0.3, w * 0.95), (b0, w)]
    elif lv == 3:
        poly = [(b0, -w * 0.85), (b0 + L * 0.2, -w), (tip, 0), (b0 + L * 0.2, w), (b0, w * 0.85)]
    else:
        poly = [(b0, -w * 0.8), (b0 + L * 0.4, -w * 1.05), (tip, 0), (b0 + L * 0.4, w * 1.05), (b0, w * 0.8)]
    c.plate(poly, t["m"], bevel=1.2, shine=0.25, tex=blade_tex2(edge="A_silver" if lv == 4 else None, fuller=lv in (3, 5), rust=lv == 1))
    if lv == 5:
        c.tube([(b0 + 1.6, 0), (b0 + L * 0.5, 0)], 0.42, "A_gold", shine=0.5, sep=False, outline=False)
    half = LV(lv, 2.6, 5.2)
    if lv == 2:
        c.tube([(g, -half), (g, half)], 0.9, "A_iron", shine=0.35)
    elif lv == 3:
        c.tube([(g, -half), (g, half)], 0.95, t["tr"], shine=0.45)
        for sg in (-1, 1):
            c.sphere((g, sg * half), 1.1, t["tr"], shine=0.5)
    elif lv >= 4:
        c.tube([(g, 0), (g + 0.6, -half * 0.8), (g + 2.6, -half)], (1.15, 0.55), t["tr"], shine=0.45)
        c.tube([(g, 0), (g - 0.6, half * 0.8), (g - 2.6, half)], (1.15, 0.55), t["tr"], shine=0.45)
        c.sphere((g, 0), 1.5, t["tr"], shine=0.5)
        if lv == 5:
            shiny(c, g, 0, 0.9, "A_garnet")
    glint5(c, lv, b0 + L * 0.6, -w * 0.4)


# ---------------------------------------------------------------- TOPUZ (çapraz)
def A_topuz(c, lv):
    t = TA[lv]
    hc, R = LV(lv, 15.5, 16.5), LV(lv, 4.6, 5.8)
    pe = LV(lv, -25, -28)
    if lv == 1:
        end = hc + R * 0.7
        c.tube([(pe + 1.0, 0), (end, 0)], (1.2, 3.0), "A_wood", tex=E.grain, shine=0.25)
        c.tube([(pe + 1.5, 0), (pe + 8, 0)], 1.55, "A_rope", tex=E.wrap, shine=0.1)
        for k, (a, sg) in enumerate(((hc - 3.0, -1), (hc, 1), (hc + 1.6, -1), (hc - 1.4, 1), (hc + 3.2, 1))):
            rr = 1.2 + 1.8 * (a - pe - 1.0) / (end - pe - 1.0)
            facet(c, spike((a, sg * (rr - 0.6)), (a + 0.6, sg * (rr + 1.6)), 0.6, shoulder=0.2), "A_iron")
        return
    c.tube([(pe + 1.5, 0), (hc - R * 0.6, 0)], 1.2, t["wd"] if lv < 4 else t["m"], tex=E.grain if lv < 4 else None, shine=0.3)
    c.tube([(pe + 2.0, 0), (pe + 10.0, 0)], 1.5, t["gr"], tex=E.wrap, shine=0.1)
    c.sphere((pe + 1.2, 0), LV(lv, 1.5, 2.0), t["tr"], shine=0.45)
    c.tube([(hc - R - 1.8, 0), (hc - R + 0.4, 0)], (1.5, 1.9), t["tr"], shine=0.45)
    if lv == 4:
        for k in range(6):
            th = 2 * math.pi * k / 6 + 0.3
            ca, sa = math.cos(th), math.sin(th)
            facet(c, spike((hc + ca * R * 0.8, sa * R * 0.8), (hc + ca * (R + 3.8), sa * (R + 3.8)), 1.7, shoulder=0.15), t["tr"])
        c.sphere((hc, 0), R * 0.95, t["m"], shine=0.35)
        return
    fin = "A_gold" if lv == 5 else t["m"]
    c.tube([(hc - R, 0), (hc + R * 0.85, 0)], 1.7, t["m"], shine=0.4)
    for sg in (-1, 1):
        c.plate([(hc - R * 0.95, sg * 1.3), (hc - R * 0.55, sg * R * 0.95), (hc + R * 0.45, sg * R * 1.05), (hc + R * 0.85, sg * 1.3)], fin, bevel=1.2, shine=0.35)
    c.tube([(hc - R * 0.8, 0), (hc + R * 0.7, 0)], 0.6, fin, shine=0.6)
    facet(c, spike((hc + R * 0.8, 0), (hc + R + 1.8, 0), 1.2), t["tr"])
    if lv == 5:
        shiny(c, hc + R * 0.95, 0, 0.8, "A_garnet")
    glint5(c, lv, hc - R * 0.2, -R * 0.7, "A_gold")


# ---------------------------------------------------------------- PENÇE (çapraz)
def A_pence(c, lv):
    t = TA[lv]
    n = 3 if lv <= 3 else 4
    bs = [-2.6, 0.0, 2.6] if n == 3 else [-3.9, -1.3, 1.3, 3.9]
    fan = [-10.0, 0.0, 10.0] if n == 3 else [-15.0, -5.0, 5.0, 15.0]
    cl = LV(lv, 10.0, 18.0)
    cm = ["", "A_iron", "A_iron", "A_steel", "A_silver", "A_steel"][lv]
    for b0, ph in zip(bs, fan):
        pts, pa, pb = [], -3.5, b0
        for k in range(6):
            ang = math.radians(ph + 14.0 * (k / 5.0) ** 1.6)
            pts.append((pa, pb))
            pa += cl / 5.0 * math.cos(ang)
            pb += cl / 5.0 * math.sin(ang)
        c.tube(pts, (LV(lv, 1.0, 1.3), 0.35), cm, shine=0.45, tex=rust_tex(lv))
    cuff = ["", "A_leather", "A_leather", "A_leather", "A_black", "A_steel"][lv]
    cw0, cw1 = LV(lv, 3.0, 3.5), LV(lv, 3.5, 4.1)
    c.plate([(-26, -cw0), (-16.5, -cw1), (-16.5, cw1), (-26, cw0)], cuff, bevel=2.2, shine=0.25)
    c.tube([(-25.6, -cw0 - 0.2), (-25.6, cw0 + 0.2)], 0.75, "A_rope" if lv == 1 else t["tr"], shine=0.35)
    c.tube([(-21.5, -cw0 - 0.3), (-21.5, cw0 + 0.3)], 0.6, "A_cloth" if lv == 4 else ("A_rope" if lv == 1 else "A_leather"), shine=0.3)
    c.tube([(-17.2, 0), (-15.6, 0)], LV(lv, 3.9, 4.6), "A_rope" if lv == 1 else t["tr"], shine=0.4)
    hp = [(-16.0, -4.2), (-10, -5.0), (-5.5, -4.8), (-3.0, -3.4), (-2.6, 0), (-3.0, 3.4), (-5.5, 4.8), (-10, 5.0), (-16.0, 4.2)]
    c.plate(hp, "A_leather" if lv < 4 else cuff, bevel=1.8, shine=0.2)
    if lv >= 2:
        c.plate([(-13, -3.4), (-8, -3.9), (-6, -2.6), (-6, 2.6), (-8, 3.9), (-13, 3.4)], "A_gold" if lv == 5 else t["m"], bevel=1.4, shine=0.3)
    for b0 in bs:
        c.sphere((-4.0, b0), LV(lv, 0.95, 1.2), "A_iron" if lv == 1 else t["tr"], shine=0.45)
    if lv == 5:
        shiny(c, -9.6, 0, 1.4, "A_garnet")
    glint5(c, lv, cl * 0.5, -3.0)


# ---------------------------------------------------------------- YILDIRIM ASASI (çapraz) - paratoner + cam yalıtkanlar
def A_light(c, lv):
    t = TA[lv]
    rod = ["", "A_wood", "A_iron", "A_steel", "A_black", "A_dwood"][lv]
    pe, fa = LV(lv, -27, -29), LV(lv, 9.0, 10.0)
    tl, sp = LV(lv, 23.0, 27.5), LV(lv, 2.4, 3.6)
    facet(c, spike((pe + 2.2, 0), (pe - 1.2, 0), 1.0, shoulder=0.3), "A_copper")
    bar(c, pe + 1.5, fa, 1.05 if lv < 5 else 1.15, rod, tex=rust_tex(lv, E.grain if rod.endswith("wood") else None), shine=0.4)
    if lv >= 2:
        c.tube([(-14, 0), (-8, 0)], 1.7, t["gr"], tex=E.wrap, shine=0.1)
    E.coil(c, -3.5, 4, "A_copper", step=1.4, r=0.5)
    if lv >= 3:
        for a in [fa - 6.2, fa - 4.4] + ([fa - 8.0] if lv == 5 else []):
            c.tube([(a, -2.6), (a, 2.6)], 0.75, "A_glass", shine=0.5)
    pm = ["", "A_iron", "A_iron", "A_steel", "A_silver", "A_gold"][lv]
    if lv == 1:
        facet(c, spike((fa - 0.5, 0), (tl, 0), 0.9, shoulder=0.1), "A_iron")
        bar(c, fa - 2.2, fa + 0.2, 1.5, "A_copper", shine=0.4)
        c.star(tl + 0.6, -1.6, "A_bolt", 1)
        return
    zz = [(tl - 6.0, -sp + 0.8), (tl - 4.6, -sp * 0.35), (tl - 6.4, sp * 0.1), (tl - 4.8, sp - 0.8)]
    c.tube(zz, 0.42, "A_bolt", glow=(6, 6, 5), sep=False, outline=False)
    c.parts[-1]["emis"] = False
    for sg in (-1, 1):
        c.tube([(fa, 0), (fa + 2.0, sg * sp * 0.9), (fa + 4.5, sg * sp), (tl - 3.0, sg * sp)], (0.9, 0.6), pm, shine=0.45)
        facet(c, spike((tl - 3.4, sg * sp), (tl - 0.8, sg * sp * 0.85), 0.75, shoulder=0.2), pm)
    if lv >= 4:
        bar(c, fa, tl - 0.8, (0.85, 0.55), pm, shine=0.45)
        facet(c, spike((tl - 1.2, 0), (tl + 1.4, 0), 0.75), pm)
    bar(c, fa - 2.2, fa + 0.4, (1.4, 1.8), "A_copper" if lv == 2 else t["tr"], shine=0.45)
    if lv == 5:
        c.sphere((fa + 2.8, 0), 2.3, "A_glass", shine=0.5)
        c.tube([(fa + 1.6, -0.8), (fa + 2.6, 0.4), (fa + 3.2, -0.6), (fa + 4.0, 0.6)], 0.42, "A_bolt", glow=(6, 6, 5), sep=False, outline=False)
        shiny(c, fa - 0.9, -1.75, 0.8, "A_garnet")
        c.glint(tl - 1.0, -sp - 1.4, "A_bolt", 6)


# ---------------------------------------------------------------- ARCANE ASASI (çapraz) - gök küresi halkaları
def A_arcane(c, lv):
    t = TA[lv]
    sm = ["", "A_wood", "A_wood", "A_wood", "A_black", "A_dwood"][lv]
    pe, hc, R = LV(lv, -27, -29), LV(lv, 16.5, 17.0), LV(lv, 2.6, 4.0)
    tr = "A_rope" if lv == 1 else t["tr"]
    if lv >= 2:
        bar(c, pe + 0.4, pe + 2.4, (1.1, 1.5), t["tr"], shine=0.4)
    bar(c, pe + 1.5, hc - R - 1.0, 1.25, sm, tex=E.grain if sm.endswith("wood") else None, shine=0.3)
    if lv >= 2:
        c.tube([(-14, 0), (-8, 0)], 1.7, t["gr"], tex=E.wrap, shine=0.1)
    if lv >= 3:
        for a in (-15.0, -7.0):
            bar(c, a - 0.7, a + 0.3, 1.85, t["tr"], shine=0.45)
    rr = R + 1.6
    if lv >= 2:
        c.tube(circle_pts(hc, 0.0, rr, n=36), 0.55, t["tr"], shine=0.45)
    cry = [(hc - R * 1.25, 0), (hc - R * 0.1, -R * 0.75), (hc + R * 1.55, 0), (hc - R * 0.1, R * 0.75)]
    c.gem(cry, "A_amethyst", table=0.35, emis=lv >= 4)
    if lv == 1:
        for k in range(3):
            c.tube([(hc - R - 1.2 + k * 1.0, -1.8), (hc - R - 0.8 + k * 1.0, 1.8)], 0.42, "A_rope", shine=0.2)
        return
    bar(c, hc - R - 2.6, hc - R - 0.8, (1.4, 1.8), t["tr"], shine=0.45)
    if lv >= 3:
        c.tube(circle_pts(hc, 0.0, rr, n=36, ra=rr * 0.42), 0.5, t["tr"], shine=0.45)
    if lv >= 4:
        c.tube(circle_pts(hc, 0.0, rr * 0.42, n=36, ra=rr), 0.5, t["tr"], shine=0.45)
    if lv == 5:
        facet(c, spike((hc + rr - 0.4, 0), (hc + rr + 3.0, 0), 0.9), "A_gold")
        shiny(c, hc - R - 1.7, -1.75, 0.8, "A_garnet")
        c.glint(hc + R * 0.3, -R * 0.3, "A_amethyst", 6)


# ---------------------------------------------------------------- BUZ ASASI (çapraz) - kristal mızrak
def A_ice(c, lv):
    t = TA[lv]
    sm = ["", "birch", "A_iron", "A_steel", "A_black", "A_dwood"][lv]
    pe, ca = LV(lv, -27, -29), LV(lv, 8.0, 7.0)
    tip, w = LV(lv, 24.0, 30.0), LV(lv, 1.9, 3.0)
    if lv >= 2:
        bar(c, pe + 0.4, pe + 2.4, (1.1, 1.5), t["tr"], shine=0.4)
    bar(c, pe + 1.5, ca + 1.0, 1.2, sm, tex=rust_tex(lv), shine=0.4 if lv > 1 else 0.1)
    if lv >= 2:
        c.tube([(-14.5, 0), (-8.5, 0)], 1.75, t["gr"], tex=E.wrap, shine=0.1)
    if lv >= 3:
        for a in (-15.5, -7.5):
            bar(c, a - 0.7, a + 0.3, 1.85, t["tr"], shine=0.45)
    fan = [[], [], [(55, 5.0)], [(50, 6.0)], [(45, 6.8)], [(42, 7.6), (95, 5.6)]][lv]
    cx = ca + 3.5
    for ang, ln in fan:
        for sg in (-1, 1):
            th = math.radians(ang)
            d = (math.cos(th), sg * math.sin(th))
            c.gem(spike((cx + d[0] * 1.2, d[1] * 1.2), (cx + d[0] * ln, d[1] * ln), LV(lv, 1.1, 1.4)), "A_ice", emis=lv >= 4)
    c.gem(spike((ca, 0), (tip, 0), w, shoulder=0.25, wb=w * 0.55), "A_ice", emis=lv >= 4)
    if lv == 1:
        c.tube([(ca - 1.2, 0), (ca + 2.4, 0)], 1.75, "A_rope", tex=E.wrap, shine=0.2)
    else:
        bar(c, ca - 2.6, ca - 0.4, (1.6, 2.1), t["tr"], shine=0.45)
        for sg in (-1, 1):
            c.tube([(ca - 0.8, sg * 1.3), (ca + 1.6, sg * (w + 0.4)), (ca + 4.0, sg * w * 0.75)], (0.8, 0.45), t["tr"], shine=0.45)
        if lv == 5:
            shiny(c, ca - 1.5, 0, 1.0, "A_garnet")
    glint5(c, lv, tip - 6.0, -w * 0.5, "A_ice")


# ---------------------------------------------------------------- TÜFEK (yatay)
def A_rifle(c, lv):
    t = TA[lv]
    by, mz = -1.5, LV(lv, 20.5, 21.5)
    wd = t["wd"]
    bm = ["", "A_iron", "A_iron", "A_steel", "A_black", "A_steel"][lv]
    tr = "A_iron" if lv == 1 else t["tr"]
    c.plate([(-8.5, -3.5), (-16.0, -2.5), (-21.6, -3.0), (-21.6, 4.5), (-18.2, 4.5), (-13.0, 1.0), (-7.0, 0.8)], wd, bevel=1.4, shine=0.15, tex=pgrain)
    if lv >= 2:
        c.tube([(-21.4, -2.6), (-21.4, 4.2)], 0.7, tr, shine=0.4)
    fe = LV(lv, 14.0, 16.0)
    c.plate([(0.5, -0.6), (fe, -0.6), (fe + 1.4, 0.4), (fe, 1.4), (0.5, 1.4)], wd, bevel=1.2, shine=0.15, tex=pgrain)
    c.plate([(-10.0, -4.0), (0.5, -4.0), (0.5, 0.6), (-10.0, 1.0)], bm, bevel=1.3, shine=0.3)
    c.plate([(-8.6, -3.4), (-3.4, -3.4), (-3.4, -1.0), (-8.6, -1.0)], tr, bevel=0.9, shine=0.35)
    c.tube([(0.0, by), (mz, by)], 1.0, bm, shine=0.45, tex=rust_tex(lv))
    if lv >= 2:
        c.tube([(1.0, 1.6), (mz - 2.0, 1.6)], 0.4, "A_wood" if lv < 4 else tr, shine=0.3, sep=False)
    for a in [[], [6.0, 12.0], [6.0, 12.0], [4.0, 9.0, 14.0], [6.0, 13.0], [4.0, 9.0, 14.0]][lv]:
        ring(c, a, by + 0.5, 2.0, tr, 1.0)
    c.tube([(-7.0, 0.8), (-7.2, 3.4), (-4.6, 3.8), (-3.8, 0.8)], 0.5, tr, shine=0.3)
    c.tube([(-5.6, 0.6), (-6.0, 2.6)], 0.45, "A_iron")
    if lv == 1:
        c.tube([(-6.0, -3.6), (-7.6, -5.6), (-6.2, -7.0), (-4.6, -6.6)], 0.5, "A_iron", shine=0.3)
        c.sphere((-4.4, -6.8), 0.8, "A_fire", glow=True)
    else:
        c.tube([(-7.4, -3.8), (-8.6, -6.0), (-7.2, -7.0)], (0.8, 0.5), "A_iron", shine=0.35)
    if lv >= 4:
        for a in (-5.0, 0.0):
            c.tube([(a, -4.2), (a, -5.4)], 0.6, tr)
        c.tube([(-7.0, -6.4), (3.0, -6.4)], 1.1, tr, shine=0.45)
        ring(c, 2.4, -6.4, 1.6, tr, 1.4)
        ring(c, -7.6, -6.4, 1.5, tr, 1.2)
    if lv == 5:
        shiny(c, -16.5, 0.8, 1.1, "A_garnet")
        c.glint(mz - 6.0, by - 0.6, "A_steel", 6)


# ---------------------------------------------------------------- TÜFTÜF (çapraz üfleme borusu)
def A_tuftuf(c, lv):
    t = TA[lv]
    a0, a1, r = LV(lv, -25, -29), LV(lv, 21, 27), LV(lv, 1.3, 1.7)
    mat = ["", "A_reed", "A_wood", "A_wood", "A_dwood", "A_dwood"][lv]

    def tex(idx, a, b, x, y, s, v):
        if lv == 1:
            ph = (a + 40) % 7.0
            if ph < 0.75:
                return idx - 2
            if ph < 1.5:
                return idx + 1
            return idx
        return E.grain(idx, a, b, x, y, s, v)

    c.tube([(a0 + 2, 0), (a1 - 2, 0)], r, mat, tex=tex, shine=0.3)
    mp = ["", "A_reed", "A_leather", "A_brass", "A_silver", "A_gold"][lv]
    c.tube([(a0, 0), (a0 + 2.6, 0)], (r * 0.8, r * 1.1), mp, shine=0.4)
    if lv >= 2:
        c.tube([(a1 - 2.6, 0), (a1, 0)], (r * 1.15, r * (1.5 if lv == 5 else 1.3)), "A_iron" if lv == 2 else t["tr"], shine=0.4)
    bands = [[], [-6.0, 8.0], [-8.0, 8.0], [-14.0, -2.0, 10.0], [-8.0, 6.0], [-14.0, -2.0, 10.0]][lv]
    for a in bands:
        bar(c, a, a + 1.2, r + 0.35, "A_rope" if lv == 1 else ("A_iron" if lv == 2 else t["tr"]), shine=0.45, tex=E.wrap if lv == 1 else None)
    if lv == 4:
        tassel(c, -7.4, r + 0.2, "A_cloth", cord="A_silver", ln=3.4)
    if lv == 5:
        shiny(c, 4.0, 0, 1.0, "A_garnet")
        c.glint(a1 - 6.0, -r * 0.6, "A_gold", 6)


# ---------------------------------------------------------------- YAY (dikey, kiriş solda)
def A_yay(c, lv):
    t = TA[lv]
    H, bg, bt = LV(lv, 18.0, 20.3), LV(lv, 4.5, 6.0), -LV(lv, 4.5, 6.0)
    mat = ["", "A_wood", "A_wood", "A_wood", "A_dwood", "A_dwood"][lv]

    def limb(sg):
        pts = []
        for i in range(9):
            s = i / 8.0
            pts.append((sg * s * H, bt + (bg - bt) * math.cos(s * math.pi / 2) ** 0.85))
        if lv >= 3:
            pts[-1] = (sg * H * 0.97, bt + 0.3)
            pts.append((sg * min(H + 0.8, 21.0), bt + LV(lv, 1.3, 2.2)))
        return pts

    up, dn = limb(1), limb(-1)
    sa = up[-2][0] if lv >= 3 else up[-1][0]
    c.tube([(sa - 0.4, bt + 0.6), (-sa + 0.4, bt + 0.6)], 0.45 if lv == 1 else 0.4, "A_rope" if lv == 1 else "A_string", shine=0.2, sep=False)
    rr = (LV(lv, 1.4, 1.8), LV(lv, 0.65, 0.8))
    for pts in (up, dn):
        c.tube(pts, rr, mat, tex=rust_tex(lv, E.grain) if lv == 1 else E.grain, shine=0.3)
    if lv >= 3:
        for pts in (up, dn):
            c.sphere(pts[-1], LV(lv, 0.9, 1.2), t["tr"], shine=0.5)
        for sg in (-1, 1):
            c.tube([(sg * 3.6 - 0.5, bg - 0.2), (sg * 3.6 + 0.5, bg - 0.2)], 2.0, t["tr"], shine=0.45)
    c.tube([(-3.0, bg - 0.2), (3.0, bg - 0.2)], LV(lv, 1.9, 2.2), t["gr"], tex=E.wrap, shine=0.1)
    if lv == 5:
        shiny(c, 0.0, bg + 0.9, 1.1, "A_garnet")
        c.glint(H * 0.55, bg - 1.6, "A_gold", 6)


# ---------------------------------------------------------------- ARBALET (çapraz)
def A_crossbow(c, lv):
    t = TA[lv]
    wd, tr = t["wd"], ("A_iron" if lv == 1 else t["tr"])
    pe, pa, H, nut = LV(lv, -25.5, -28.0), LV(lv, 11.0, 12.5), LV(lv, 9.0, 12.0), LV(lv, -2.0, -4.0)
    pm = ["", "A_wood", "A_iron", "A_steel", "A_black", "A_steel"][lv]
    c.plate([(pe, -2.2), (pe + 8.0, -1.6), (pe + 8.0, 2.0), (pe, 2.9)], wd, bevel=1.4, shine=0.15, tex=pgrain)
    if lv >= 2:
        c.tube([(pe + 0.2, -2.0), (pe + 0.2, 2.7)], 0.75, tr, shine=0.4)
    bar(c, pe + 7.0, pa + 2.5, LV(lv, 1.55, 1.8), wd, tex=E.grain, shine=0.25)
    c.tube([(-10.0, 1.6), (-13.0 if lv > 2 else -16.0, 3.6 if lv > 2 else 3.2)], 0.5, "A_iron", shine=0.3)
    if lv >= 3:
        bar(c, 3.0, 4.2, 1.95, tr, shine=0.45)
    if lv == 4:
        c.tube([(pe + 5.0, 2.4), (pe + 5.0, 5.4), (pe + 3.2, 5.8)], 0.5, tr, shine=0.45)
        c.sphere((pe + 3.0, 5.8), 0.8, "A_cloth", shine=0.3)

    def prod():
        side = [(pa - (b / H) ** 2 * LV(lv, 3.6, 4.6), b) for b in [H * i / 6.0 for i in range(7)]]
        if lv >= 3:
            side.append((side[-1][0] - 1.2, H + 0.9))
        return side

    side = prod()
    ta, tb = side[-1] if lv < 3 else side[-2]
    line_px(c, [(ta - 0.3, -tb + 0.3), (nut, 0), (ta - 0.3, tb - 0.3)], "A_rope" if lv == 1 else "A_string", 4)
    c.tube([(nut + 0.5, 0), (pa + 4.0, 0)], 0.55, "A_wood", shine=0.35)
    for sg in (-1, 1):
        c.plate([(nut + 0.6, sg * 0.4), (nut + 3.6, sg * 0.5), (nut + 1.8, sg * 2.0), (nut - 0.2, sg * 2.0)], "A_cloth" if lv >= 4 else "A_paper", bevel=0.8)
    c.gem(spike((pa + 3.2, 0), (pa + LV(lv, 6.4, 8.0), 0), LV(lv, 1.0, 1.3)), t["m"], emis=False)
    for sg in (-1, 1):
        c.tube([(a, sg * b) for a, b in side], (LV(lv, 1.35, 1.6), 0.6), pm, tex=E.grain if lv == 1 else rust_tex(lv), shine=0.4)
        if lv >= 3:
            c.sphere((side[-1][0], sg * side[-1][1]), 0.85, tr, shine=0.5)
    c.sphere((pa + 0.2, 0), LV(lv, 1.6, 2.1), tr, shine=0.45)
    if lv >= 2:
        c.tube([(pa + 1.2, -1.9), (pa + 3.6, -1.9), (pa + 3.6, 1.9), (pa + 1.2, 1.9)], 0.45, tr, shine=0.4)
    if lv == 5:
        shiny(c, pe + 4.0, 0.3, 1.1, "A_garnet")
        c.glint(pa - 2.0, -H * 0.7, "A_steel", 6)


# ---------------------------------------------------------------- BUMERANG (yatay V)
def A_boomerang(c, lv):
    t = TA[lv]
    S_ = LV(lv, 0.82, 1.0)
    w = LV(lv, 2.4, 3.0)
    mat = ["", "A_wood", "A_wood", "A_wood", "A_dwood", "A_dwood"][lv]
    pts = [(-19 * S_, 6.5 * S_), (-9 * S_, -2.0 * S_), (0, -8.5 * S_), (9 * S_, -2.0 * S_), (19 * S_, 6.5 * S_)]

    def btex(idx, a, b, x, y, d):
        if lv >= 3 and d < 0.9 and b < -8.0 * S_ + abs(a) * 0.78 - 0.5:
            return P[t["tr"]][5]
        if lv == 1 and S.hsh(x, y, 9) < 0.18:
            return max(1, idx - 1)
        return pgrain(idx, a, b, x, y, d)

    c.plate(ribbon(pts, w * 0.82, w * 0.82, miter=2.2), mat, bevel=1.6, shine=0.3, tex=btex)
    if lv >= 2:
        for sg in (-1, 1):
            a, b = pts[0] if sg < 0 else pts[-1]
            c.sphere((a - sg * 0.6, b - 0.4), w * 0.72, "A_iron" if lv == 2 else t["tr"], shine=0.45)
    if lv == 4:
        c.plate([(-1.8, -8.5 * S_ - 0.6), (1.8, -8.5 * S_ - 0.6), (2.6, -8.5 * S_ + 3.4), (-2.6, -8.5 * S_ + 3.4)], "A_cloth", bevel=1.0, shine=0.3)
    if lv in (3, 5):
        c.sphere((0, -8.5 * S_ + 1.4), LV(lv, 1.6, 2.2), t["tr"], shine=0.5)
    if lv == 5:
        shiny(c, 0, -8.5 * S_ + 1.4, 1.0, "A_garnet")
        c.glint(-9 * S_, -2.6 * S_, "A_gold", 6)


# ---------------------------------------------------------------- FİŞEK (çapraz roket)
def A_fisek(c, lv):
    t = TA[lv]
    r = LV(lv, 2.4, 3.2)
    b0, b1, nose = LV(lv, -4.0, -8.0), LV(lv, 10.0, 13.5), LV(lv, 17.5, 23.5)
    body = ["", "A_paper", "A_paper", "A_paper", "A_black", "A_steel"][lv]
    if lv >= 4:
        ln, base = LV(lv, 5.0, 7.0), b0 - 1.8
        fo = [(base - u * ln, v * r * 0.9) for u, v in F1]
        c.layers([fo, S.scale_poly(fo, base - ln * 0.15, 0, 0.66), S.scale_poly(fo, base, 0, 0.3)], "A_fire", (3, 4, 5))
    if lv <= 2:
        c.tube([(b0 + 3.0, r + 0.9), (-26.5, r + 0.9)], 0.6, "A_wood", shine=0.3)
        c.tube([(b0 - 0.2, 0), (b0 - 1.6, 0.8), (b0 - 2.4, -0.2), (b0 - 3.4, 0.4)], 0.42, "A_rope", sep=False)
        c.star(b0 - 3.8, 0.4, "A_fire", 1)
    else:
        fl = LV(lv, 3.2, 4.6)
        for sg in (-1, 1):
            c.plate([(b0 + 4.5, sg * r * 0.6), (b0 + 0.2, sg * (r + fl)), (b0 - 2.6, sg * (r + fl + 0.6)), (b0 - 0.6, sg * r * 0.4)], t["tr"], bevel=1.2, shine=0.35)
        bar(c, b0 - 2.0, b0 + 0.2, (r * 0.65, r * 0.85), "A_iron", shine=0.4)

    def stex(idx, a, b, x, y, s, v):
        ph = (a - b0) / max(1.0, b1 - b0)
        if lv <= 3 and (0.15 < ph < 0.27 or 0.55 < ph < 0.67):
            return P["A_cloth"][max(1, min(6, idx))]
        return idx

    bar(c, b0, b1, r, body, tex=stex, shine=0.3)
    if lv >= 4:
        for a in (b0 + 1.2, b1 - 1.6):
            bar(c, a, a + 0.9, r + 0.35, t["tr"], shine=0.45)
    nm = ["", "A_cloth", "A_iron", "A_brass", "A_silver", "A_gold"][lv]
    c.gem(spike((b1 - 0.4, 0), (nose, 0), r * 1.02, shoulder=0.04, wb=r * 1.02), nm, emis=False)
    if lv == 5:
        shiny(c, (b0 + b1) / 2 + 1.0, -0.4, 1.2, "A_garnet")
        c.glint(nose - 3.0, -r * 0.4, "A_gold", 6)



# ================================================================ ASALAR v2 (kullanıcı: "asalar çok birbirine benziyor daha karakteristik")
# İlk sürümde dördü de aynı kahverengi çubuk + küçük baştı; oyun ölçeğinde hepsi "uzun çubuk" okunuyordu. Şimdi BÜTÜN silüet farklı:
# Ateş = kalın koyu gövde, tepesi kıvrık kanca + ASILI FENER; Yıldırım = ince bakır çubuk + geniş U çatal + dişler arası kıvılcım;
# Arcane = mor ahşap + büyük HALKA içinde asılı kristal; Buz = soluk kırağılı gövde + kristal DEMETİ + gövdeden sarkan buz sarkıtları.
P["A_plumwood"] = [hx(c) for c in "#1a0e16 #2e1a28 #42263a #56344c #6c4460 #845878 #a87c9c".split()]


def scr(cx, cy, pts):
    """Ekran ofsetleri -> (a, b): çapraz çerçevede dik duran şekiller (kanca, fener, sarkıt)."""
    return [E.ab(cx + dx, cy + dy) for dx, dy in pts]


def line_px(c, pts, mat, idx=4, outline=True, glow=False):
    """Kesintisiz 1 piksellik çoklu çizgi (Bresenham). İnce tüp (r<0,5) 45 derece dışı açıda piksel atlayıp KOPUK görünüyordu
    (arbalet kirişi L4)."""
    pid = c._part(mat, False, glow, outline)
    sp = [E.xy(*p) for p in pts]
    for (fx0, fy0), (fx1, fy1) in zip(sp[:-1], sp[1:]):
        x0, y0, x1, y1 = int(math.floor(fx0)), int(math.floor(fy0)), int(math.floor(fx1)), int(math.floor(fy1))
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            if 0 <= x0 < N and 0 <= y0 < N:
                c.pix[(x0, y0)] = [P[mat][idx], pid]
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy


def flame_up(c, cx, cy, h, w, tmpl, mat="A_fire"):
    """Ekranda yukarı yanan alev (fener içi); (cx, cy) alev tabanı."""
    fo = [(v * w, -u * h) for u, v in tmpl]
    polys = [fo] + [[(x * k, y * k) for x, y in fo] for k in (0.72, 0.46, 0.22)]
    c.layers([scr(cx, cy, q) for q in polys], mat, (3, 4, 5, 6))


def staff_base(c, lv, pe, top, sm, r, tex=None):
    t = TA[lv]
    if lv >= 2:
        bar(c, pe + 0.4, pe + 2.4, (1.1, 1.5), t["tr"], shine=0.4)
    bar(c, pe + 1.5, top, r, sm, tex=tex, shine=0.35)
    if lv >= 2:
        c.tube([(-14, 0), (-8, 0)], r + 0.5, t["gr"], tex=E.wrap, shine=0.1)
    if lv >= 3:
        for a in (-15.0, -7.0):
            bar(c, a - 0.7, a + 0.3, r + 0.6, t["tr"], shine=0.45)


P["A_clay"] = [hx(c) for c in "#2a120a #52241a #723426 #8e4632 #a85c40 #c07856 #dca07e".split()]


# Püskürtme jeti: ağızda dar, ileri açılan, önü ve yanları DİLLİ, DIŞ ÇİZGİSİZ (dış çizgili düzgün şekil turuncu "balon/kaşık" okutuyordu;
# mum alevi şablonları F1/F3/F5 uca doğru daralıp "meşale" okutuyordu)
JET = [(0, -0.28), (0.2, -0.5), (0.3, -0.42), (0.42, -0.75), (0.52, -0.62), (0.62, -0.95), (0.7, -0.7), (0.78, -0.88), (0.86, -0.5),
       (1.0, -0.35), (0.9, -0.12), (0.98, 0.12), (0.88, 0.3), (1.0, 0.55), (0.84, 0.62), (0.76, 0.9), (0.66, 0.7), (0.56, 0.92),
       (0.46, 0.66), (0.34, 0.72), (0.24, 0.46), (0, 0.28)]


def jet(c, base, length, width):
    length = min(length, 30.6 - base)
    fo = [(base + u * length, v * width) for u, v in JET]
    c.layers([fo, S.scale_poly(fo, base, 0, 0.74), S.scale_poly(fo, base, 0, 0.5), S.scale_poly(fo, base, 0, 0.27)], "A_fire", (3, 4, 5, 6),
             sep=False, outline=False)


def Z_fire(c, lv):
    """ALEV AĞZI (kullanıcı: "ateş asası çok kötü, ateş püskürten bir asaya uygun değil, yeniden tasarla"; asılı fener alevi yana
    sarkıtıyordu). Oyunda alev asanın baktığı yöne püskürür (madde 37) -> uçta İLERİ bakan ağız, alev ağızdan ileri açılan dilli JET
    (seviyeyle uzar/genişler). Merdiven: L1 kil köz çömleği (ip gövdede), L2 perçinli demir huni, L3 pirinç yakıt haznesi + çan nozul,
    L4 karartılmış çelik OCAK KÜRESİ (içten sızan ateş yarıkları) + gümüş nozul, L5 altın ocak küresi + lal + büyük çan nozul + kanatçık.
    (Ejder başı denendi: 48 pikselde hurda yığını gibi okundu.)"""
    t = TA[lv]
    sm = ["", "A_wood", "A_wood", "A_dwood", "A_black", "A_dwood"][lv]
    pe = LV(lv, -27, -29)
    if lv == 1:
        hp = 9.0
        staff_base(c, lv, pe, hp - 2.6, sm, 1.35, tex=E.grain)
        for k in range(3):
            c.tube([(hp - 7.0 + k * 1.2, -1.9), (hp - 6.6 + k * 1.2, 1.9)], 0.45, "A_rope", shine=0.2)
        jet(c, hp + 2.4, 9.5, 2.8)
        c.sphere((hp, 0), 3.4, "A_clay", shine=0.3)
        c.tube([(hp + 3.0, -2.4), (hp + 3.0, 2.4)], 0.95, "A_clay", shine=0.35)
        c.sphere((hp + 2.6, 0), 1.3, "A_fire", glow=True)
        return
    if lv == 2:
        hp = 8.0
        staff_base(c, lv, pe, hp - 2.0, sm, 1.4, tex=E.grain)
        jet(c, hp + 4.4, 12.0, 3.6)
        c.plate([(hp - 2.0, -1.5), (hp + 3.6, -3.9), (hp + 5.0, -4.4), (hp + 5.0, 4.4), (hp + 3.6, 3.9), (hp - 2.0, 1.5)], "A_iron", bevel=1.6, shine=0.35)
        c.tube([(hp + 5.0, -4.8), (hp + 5.0, 4.8)], 0.9, "A_iron", shine=0.45)
        for sg in (-1, 1):
            c.sphere((hp + 1.4, sg * 2.0), 0.7, "A_steel", shine=0.6)
        bar(c, hp - 3.8, hp - 1.6, (1.6, 1.9), "A_iron", shine=0.4)
        return
    if lv == 3:
        hp = 7.0
        staff_base(c, lv, pe, hp - 5.0, sm, 1.45, tex=E.grain)
        jet(c, hp + 6.6, 13.5, 4.3)
        c.sphere((hp - 2.4, 0), 3.4, "A_brass", shine=0.5)
        c.sphere((hp - 3.0, -1.7), 0.9, "A_fire", glow=True)
        bar(c, hp + 0.6, hp + 3.4, 1.3, "A_steel", shine=0.5)
        c.plate([(hp + 3.0, -1.4), (hp + 5.4, -3.0), (hp + 7.6, -5.0), (hp + 7.6, 5.0), (hp + 5.4, 3.0), (hp + 3.0, 1.4)], "A_brass", bevel=1.6, shine=0.4)
        c.tube([(hp + 7.6, -5.3), (hp + 7.6, 5.3)], 0.8, "A_brass", shine=0.5)
        return
    # L4-5: ocak küresi + çan nozul
    gold = lv == 5
    hp = 6.0 if not gold else 5.5
    R = 3.6 if not gold else 4.0
    om, nm = ("A_black", "A_silver") if not gold else ("A_gold", "A_gold")
    staff_base(c, lv, pe, hp - R, sm, 1.5, tex=E.grain if sm.endswith("wood") else None)
    nl, nw = (6.0, 3.6) if not gold else (7.0, 4.4)
    jet(c, hp + R + nl - 1.0, 16.5 if not gold else 18.5, 4.8 if not gold else 5.2)
    if gold:
        for sg in (-1, 1):
            c.plate([(hp - 0.6, sg * (R - 0.6)), (hp - 2.6, sg * (R + 2.6)), (hp - 4.6, sg * (R + 2.2)), (hp - 3.2, sg * (R - 0.8))], "A_gold", bevel=1.0, shine=0.4)
    c.sphere((hp, 0), R, om, shine=0.45)
    c.tube([(hp, -R + 0.2), (hp, R - 0.2)], 0.7, nm, shine=0.5)
    for db in (-1.8, 1.4):
        c.tube([(hp - 1.8, db), (hp - 0.8, db + 0.3)], 0.42, "A_fire", glow=(6, 5, 4), sep=False, outline=False)
        c.tube([(hp + 0.8, db), (hp + 1.8, db + 0.3)], 0.42, "A_fire", glow=(6, 5, 4), sep=False, outline=False)
    c.plate([(hp + R - 0.6, -1.4), (hp + R + nl * 0.5, -nw * 0.55), (hp + R + nl, -nw), (hp + R + nl, nw), (hp + R + nl * 0.5, nw * 0.55),
             (hp + R - 0.6, 1.4)], nm, bevel=1.5, shine=0.4)
    c.tube([(hp + R + nl, -nw - 0.3), (hp + R + nl, nw + 0.3)], 0.8, nm, shine=0.5)
    bar(c, hp - R - 1.8, hp - R + 0.2, (1.6, 2.0), "A_cloth" if not gold else "A_gold", shine=0.4)
    if gold:
        shiny(c, hp - 0.6, -2.0, 1.0, "A_garnet")
        c.glint(hp - 1.6, -R * 0.6, "A_gold", 6)


def Z_light(c, lv):
    """PARATONER ÇATALI: ince metal çubuk + bakır bobin + cam yalıtkan diskler, tepede GENİŞ U çatal, dişler arası kıvılcım."""
    t = TA[lv]
    rod = ["", "A_wood", "A_copper", "A_steel", "A_black", "A_copper"][lv]
    pm = ["", "A_copper", "A_iron", "A_steel", "A_silver", "A_gold"][lv]
    pe, fa = LV(lv, -27, -29), 6.0
    tl, sp = LV(lv, 24.0, 26.5), LV(lv, 3.4, 4.6)
    facet(c, spike((pe + 2.2, 0), (pe - 1.2, 0), 1.0, shoulder=0.3), "A_copper")
    staff_base(c, lv, pe, fa - 1.0, rod, 1.15 if lv == 1 else 0.95, tex=E.grain if lv == 1 else None)
    for a0 in ([-20.0, -4.0] if lv == 1 else [-3.0]):
        E.coil(c, a0, 5, "A_copper", step=1.3, r=0.5)
    if lv >= 3:
        for a in [fa - 5.6, fa - 3.8] + ([fa - 7.4] if lv == 5 else []):
            c.tube([(a, -2.6), (a, 2.6)], 0.75, "A_glass", shine=0.5)
    arcs = [[], [], [tl - 6.0], [tl - 6.0], [tl - 5.0, tl - 10.0], [tl - 5.0, tl - 10.0]][lv]
    for a0 in arcs:
        # hale dişler arasını yeşilimsi kutuya çeviriyordu -> ışımaz, sadece parlak renk
        line_px(c, [(a0, -sp + 0.8), (a0 + 1.6, -sp * 0.3), (a0 - 0.4, sp * 0.2), (a0 + 1.2, sp - 0.8)], "A_bolt", 6, outline=False)
    u = [(tl - 2.6, -sp), (fa + 3.2, -sp), (fa + 0.8, -sp * 0.6), (fa + 0.2, 0), (fa + 0.8, sp * 0.6), (fa + 3.2, sp), (tl - 2.6, sp)]
    c.tube(u, 0.85, pm, shine=0.45)
    for sg in (-1, 1):
        facet(c, spike((tl - 3.0, sg * sp), (tl, sg * sp * 0.92), 0.75, shoulder=0.2), pm)
    if lv >= 4:
        bar(c, fa, tl - 0.6, (0.85, 0.55), pm, shine=0.45)
        facet(c, spike((tl - 1.0, 0), (tl + 1.4, 0), 0.75), pm)
    bar(c, fa - 2.2, fa + 0.4, (1.3, 1.7), "A_copper" if lv <= 2 else t["tr"], shine=0.45)
    if lv == 1:
        c.star(tl + 0.4, -sp - 1.0, "A_bolt", 1)
    if lv == 5:
        c.sphere((fa + 3.4, 0), 2.0, "A_glass", shine=0.5)
        line_px(c, [(fa + 2.2, -0.6), (fa + 3.0, 0.5), (fa + 3.8, -0.5), (fa + 4.6, 0.4)], "A_bolt", 6, outline=False)
        shiny(c, fa - 0.9, -1.6, 0.8, "A_garnet")


P["A_violetwood"] = [hx(c) for c in "#180a1e #2c1438 #3e1e50 #522a68 #683a80 #80509a #a87cc0".split()]
P["A_violet"] = [hx(c) for c in "#140a22 #2a1648 #3e2268 #543288 #6c46a6 #8a62c4 #c4a8ec".split()]
P["A_violetcloth"] = [hx(c) for c in "#1a0a24 #34164a #4a2066 #622c84 #7c3ca0 #9858ba #c894e0".split()]
P["A_amethyst"] = [hx(c) for c in "#1e0a30 #3a1660 #56248c #7436b4 #9450d6 #b880f0 #ecdcff".split()]


def Z_arcane(c, lv):
    """GÖK HALKASI, MOR TEMA, BÜYÜYEN SİLÜET (kullanıcı: "birbirinin aynısı gibi oldu fazla gelişmiş gibi görünmüyor"):
    L1 küçük eğri dal halka + sönük küçük kristal (iple bağlı), L2 düz gövde + demir telli halka, L3 büyük halka + pirinç kenar + IŞIYAN kristal,
    L4 halkadan 4 ametist sivri + gümüş kanatlı bilezik, L5 6 ışıyan ametist ışını + altın hilal + büyük kristal. Renk hep mor; işçilik
    merdiveni yalnız küçük süslerde (bilezik, tel, kenar, hilal)."""
    t = TA[lv]
    pe = LV(lv, -26, -29)
    hc = [0, 18.0, 17.5, 17.0, 16.8, 16.5][lv]
    rr = [0, 4.2, 5.0, 5.8, 6.2, 6.4][lv]
    k = [0, 0.9, 1.1, 1.35, 1.5, 1.7][lv]
    tr = "A_iron" if lv <= 2 else t["tr"]
    # gövde
    if lv == 1:
        c.tube([(pe + 1.0, 0.4), (-15, -0.5), (-3, 0.5), (hc - rr, 0)], 1.1, "A_violetwood", tex=E.grain, shine=0.3)
    else:
        bar(c, pe + 0.4, pe + 2.4, (1.1, 1.5), tr, shine=0.4)
        bar(c, pe + 1.5, hc - rr, 1.25, "A_violetwood", tex=E.grain, shine=0.35)
        c.tube([(-14, 0), (-8, 0)], 1.75, "A_violetcloth", tex=E.wrap, shine=0.15)
        if lv >= 3:
            for a0 in (-15.0, -7.0):
                bar(c, a0 - 0.7, a0 + 0.3, 1.85, tr, shine=0.45)
    # halka mor kalır ve seviyeyle kalınlaşır (tam metal kenar halkası + kanatlar başı yine altın/gümüş okutuyordu)
    c.tube(circle_pts(hc, 0.0, rr, n=44), [0, 0.7, 0.85, 1.0, 1.1, 1.2][lv], "A_violetwood" if lv == 1 else "A_violet", shine=0.5,
           tex=E.grain if lv == 1 else None)
    # ışınlar (L4 dört, L5 altı) halkanın ÖNÜNDE, açık ametist
    rays = {4: [(45, 3.2), (135, 3.2), (225, 3.2), (315, 3.2)],
            5: [(45, 2.8), (90, 3.8), (135, 2.8), (225, 2.8), (270, 3.8), (315, 2.8)]}.get(lv, [])
    for ang, ln in rays:
        th = math.radians(ang)
        d = (math.cos(th), math.sin(th))
        c.gem(spike((hc + d[0] * (rr - 0.6), d[1] * (rr - 0.6)), (hc + d[0] * (rr + ln), d[1] * (rr + ln)), 1.15, shoulder=0.2),
              "A_amethyst", table=0.45, steep=0.6, shine=0.5, emis=lv == 5)
    # küçük metal kelepçeler: işçilik merdiveni
    for ang in {2: [90, 270], 3: [90, 270], 4: [0, 90, 180, 270], 5: [180, 90, 270]}.get(lv, []):
        th = math.radians(ang)
        c.sphere((hc + rr * math.cos(th), rr * math.sin(th)), 1.0, tr, shine=0.5)
    if lv >= 2:
        bar(c, hc - rr - 2.2, hc - rr - 0.2, (1.3, 1.7), tr, shine=0.45)
    # askı
    if lv == 1:
        line_px(c, [(hc, -rr + 0.6), (hc - 0.2, -1.2)], "A_rope", 3)
        line_px(c, [(hc, rr - 0.6), (hc - 0.2, 1.2)], "A_rope", 3)
    else:
        for sg in (-1, 1):
            c.tube([(hc - 0.2, sg * 1.3 * k), (hc, sg * (rr - 0.5))], 0.42, tr, shine=0.45)
    if lv >= 4:
        c.tube(circle_pts(hc, 0.0, rr - 0.2, n=44, ra=(rr - 0.2) * 0.38), 0.42, tr, shine=0.45)
    if lv == 5:
        moon = [(hc + rr + 0.6 + 2.6 * math.cos(th), 2.6 * math.sin(th)) for th in [math.radians(-80 + 160 * i / 10) for i in range(11)]]
        inner = [(hc + rr + 1.7 + 1.9 * math.cos(th), 1.9 * math.sin(th)) for th in [math.radians(70 - 140 * i / 10) for i in range(11)]]
        c.plate(moon + inner, "A_gold", bevel=0.9, shine=0.45)
    # kristal en önde
    cry = [(hc - 2.3 * k, 0), (hc - 0.2 * k, -1.5 * k), (hc + 2.7 * k, 0), (hc - 0.2 * k, 1.5 * k)]
    c.gem(cry, "A_amethyst" if lv > 1 else "A_violet", table=0.35, emis=lv >= 3)
    if lv == 5:
        shiny(c, hc - rr - 1.2, -1.6, 0.8, "A_amethyst")
        c.glint(hc - 0.6 * k, -0.6 * k, "A_amethyst", 6)


def Z_ice(c, lv):
    """KRİSTAL DEMETİ: soluk kırağılı gövde, gövdeden (ekranda aşağı) sarkan buz sarkıtları, tepede yelpaze gibi açılan kristaller."""
    t = TA[lv]
    sm = ["", "birch", "birch", "A_silver", "A_black", "A_silver"][lv]
    pe, ca = LV(lv, -27, -29), LV(lv, 9.0, 8.0)

    def frost(idx, a, b, x, y, s, v):
        if lv <= 2:
            for k0, sd in ((-22, 1), (-17.5, -1), (-12, 1), (-6.5, -1), (-1.5, 1)):
                if k0 <= a <= k0 + 1.0 and b * sd > -0.3:
                    return P["birch"][0] if abs(b) < 0.4 else P["birch"][1]
        if S.hsh(x, y, 7) < 0.04 + (a - pe) / 40.0 * 0.1:
            return P["A_ice"][5]
        return idx

    staff_base(c, lv, pe, ca + 1.0, sm, 1.2, tex=frost)
    for a in [-4.0, -17.0, 3.0][:max(0, lv - 1) if lv < 5 else 3]:
        bx, by = E.xy(a, 1.0)
        c.gem(spike(E.ab(bx, by), E.ab(bx, by + LV(lv, 3.0, 4.6)), 0.75, shoulder=0.2), "A_ice", emis=False)
    crs = {1: [(24, 6.0, 1.2), (0, 13.0, 2.0)],
           2: [(28, 8.0, 1.5), (-24, 7.0, 1.4), (0, 15.0, 2.3)],
           3: [(30, 10.0, 1.8), (-28, 9.0, 1.7), (0, 17.0, 2.6)],
           4: [(60, 6.0, 1.3), (30, 12.0, 2.0), (-30, 11.0, 2.0), (0, 19.0, 2.8)],
           5: [(58, 8.0, 1.6), (-58, 8.0, 1.6), (28, 13.0, 2.2), (-28, 13.0, 2.2), (0, 21.0, 3.0)]}[lv]
    for ang, ln, w in crs:
        th = math.radians(ang)
        d = (math.cos(th), math.sin(th))
        base = (ca + d[0] * 0.8, d[1] * 0.8)
        c.gem(spike(base, (ca + d[0] * ln, d[1] * ln), w, shoulder=0.28, wb=w * 0.6), "A_ice", emis=lv >= 4)
    if lv == 1:
        c.tube([(ca - 1.6, 0), (ca + 1.6, 0)], 1.8, "A_rope", tex=E.wrap, shine=0.2)
    else:
        bar(c, ca - 2.4, ca + 0.4, (1.6, 2.0), t["tr"], shine=0.45)
        if lv == 5:
            shiny(c, ca - 1.0, 0, 0.9, "A_garnet")
            c.glint(ca + 12.0, -1.2, "A_ice", 6)


WEAPONS = [
    ("dagger", "Bıçak", "diag", A_dagger),
    ("uzunkilic", "Uzunkılıç", "diag", A.A_sword),
    ("topuz", "Topuz", "diag", A_topuz),
    ("pence", "Pençe", "diag", A_pence),
    ("fire_staff", "Ateş Asası", "diag", Z_fire),
    ("lightning_staff", "Yıldırım Asası", "diag", Z_light),
    ("arcane", "Arcane Asası", "diag", Z_arcane),
    ("buz_asasi", "Buz Asası", "diag", Z_ice),
    ("tabanca", "Tabanca", "horiz", A.A_gun),
    ("tufek", "Tüfek", "horiz", A_rifle),
    ("tuftuf", "Tüftüf", "diag", A_tuftuf),
    ("yay", "Yay", "vert", A_yay),
    ("crossbow", "Arbalet", "diag", A_crossbow),
    ("boomerang", "Bumerang", "horiz", A_boomerang),
    ("fisek", "Fişek", "diag", A_fisek),
]


def build(keys=None):
    os.makedirs(OUT, exist_ok=True)
    gd = os.path.join(OUT, ".gdignore")
    if not os.path.exists(gd):
        open(gd, "w").close()
    imgs = {}
    for key, _, fr, fn in WEAPONS:
        if keys and key not in keys:
            continue
        frame(fr)
        for lv in range(1, 6):
            cv = Cv(lv)
            fn(cv, lv)
            img = cv.render()
            img.save(os.path.join(OUT, "%s_L%d.png" % (key, lv)))
            a = img.getchannel("A").point(lambda v: 255 if v == 255 else 0).getbbox()
            if a and (a[0] == 0 or a[1] == 0 or a[2] == N or a[3] == N):
                print("KENAR!", key, lv, a)
            imgs[(key, lv)] = img
    return imgs


def sheet(imgs, rows, path, z=4):
    cell = N * z
    lw, gap, top = 150, 14, 40
    W = lw + 5 * (cell + gap) + gap + (60 if z < 4 else 0)
    H = top + len(rows) * (cell + gap) + gap
    im = Image.new("RGBA", (W, H), (34, 38, 40, 255))
    d = ImageDraw.Draw(im)
    for lv in range(1, 6):
        x0 = lw + gap + (lv - 1) * (cell + gap)
        d.text((x0, 10), "%d - %s" % (lv, TA[lv]["name"]), fill=(235, 230, 215), font=font(20 if z >= 4 else 15, True))
    for ri, (key, label) in enumerate(rows):
        y0 = top + ri * (cell + gap)
        d.text((12, y0 + cell // 2 - 10), label, fill=(235, 230, 215), font=font(18, True))
        for lv in range(1, 6):
            x0 = lw + gap + (lv - 1) * (cell + gap)
            d.rectangle([x0, y0, x0 + cell - 1, y0 + cell - 1], fill=S.BG)
            im.alpha_composite(imgs[(key, lv)].resize((cell, cell), Image.NEAREST), (x0, y0))
    im.convert("RGB").save(path)


def context(imgs):
    """Oyun ölçeği: 0,5 dünya px/piksel x zoom 2 = 1:1, büyücü boy kıyası, resim x2."""
    zoom, wpp = 2.0, 0.5
    cwp = 2.2368375 * 0.8075 * 0.5
    wiz = Image.open(os.path.join(E.GAME, "assets/characters/buyucu/sheets/idle.png")).convert("RGBA").crop((0, 0, 48, 48))
    cw, ch, lw, top = 54, 64, 110, 26
    W = lw + 80 + len(WEAPONS) * cw + 10
    H = top + 5 * (ch + 6)
    im = Image.new("RGB", (W, H), (34, 38, 40))
    d = ImageDraw.Draw(im)
    d.text((8, 4), "Zanaatkâr - oyun ölçeği (1 piksel = 1 ekran pikseli, zoom 2)", fill=(235, 230, 215), font=font(13, True))
    for lv in range(1, 6):
        y0 = top + (lv - 1) * (ch + 6)
        d.text((8, y0 + ch // 2 - 8), "%d - %s" % (lv, TA[lv]["name"]), fill=(235, 230, 215), font=font(13, True))
        pc = Image.new("RGB", (80 + len(WEAPONS) * cw, ch), S.BG)
        E.blit_world(pc, wiz, 40, ch // 2, cwp, zoom)
        for i, (key, _, _, _) in enumerate(WEAPONS):
            E.blit_world(pc, imgs[(key, lv)], 80 + i * cw + cw // 2, ch // 2, wpp, zoom)
        im.paste(pc, (lw, y0))
    im.resize((W * 2, H * 2), Image.NEAREST).save(os.path.join(HERE, "silah48_zanaat_oyun.png"))


if __name__ == "__main__":
    only = sys.argv[1:] or None
    imgs = build(only)
    rows = [(k, n) for k, n, _, _ in WEAPONS if (k, 1) in imgs]
    if only:
        sheet(imgs, rows, os.path.join(HERE, "silah48_zanaat_deneme.png"))
    else:
        for i in range(3):
            sheet(imgs, rows[i * 5:(i + 1) * 5], os.path.join(HERE, "silah48_zanaat_sayfa_%d.png" % (i + 1)))
        sheet(imgs, rows, os.path.join(HERE, "silah48_zanaat_ozet.png"), z=2)
        context(imgs)
    print("ok", len(imgs))
