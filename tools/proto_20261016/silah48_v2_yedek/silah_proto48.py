# -*- coding: utf-8 -*-
"""Silah prototipleri: 15 silah x 5 seviye, 48x48 (2026-10-16, oyuna bağlı DEĞİL).
Kullanıcı: "oyunumdaki tüm silahlar için 1 levelden 5 levele doğru gittikçe güçlenecek şekilde görünen pixel art 48x48, terrariadaki
silahlara benzeyen (ama kopyası gibi olmasın sadece sanat olarak benzeyen) yeni silahlar".

Seviye merdiveni = oyundaki efsun kademe kontür renkleriyle aynı sıra (enchant_weapon_glow.gd TIER_COLORS: 2 yeşil, 3 mavi, 4 mor, 5 kırmızı):
  1 Bakır      bakır + açık ahşap, sade, en küçük siluet, taş yok
  2 Çelik      çelik + deri, zümrüt taş
  3 Kobalt     kobalt mavisi metal + altın süs + safir, ilk parıltı
  4 Gece       gece demiri (koyu mor) + gümüş + ışıyan ametist damarlar, dikenler, mor hale
  5 Kızıl Kor  kızıl cehennem demiri + altın + ışıyan kor/yakut, kanat/alev süsleri, kırmızı hale, kıvılcımlar, en büyük siluet
Silahın oyundaki duruşu korunur: asa/bıçak/kılıç/topuz/pençe/tüftüf/arbalet/fişek çapraz (sol-alt -> sağ-üst), tabanca/tüfek/bumerang
yatay (namlu sağda), yay dikey (kiriş solda).

Motor: asa_proto48.py (ışıklı tüp / küre / eğimli levha / kesme taş, ışık sol-üst); burada çizim çerçevesi değiştirilebilir (frame),
hale rengi parça başına (Cv.halo) ve 5. seviyede 3 kademeli geniş hale.
Çıktılar: silah48/<anahtar>_L<n>.png (ham 48x48), silah48_sayfa_<1..3>.png (x4), silah48_ozet.png (x2, hepsi).
Çalıştırma: python tools/proto_20261016/silah_proto48.py
"""
import math
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import asa_proto48 as E  # noqa: E402
from asa_proto48 import Canvas, P, N, R2, hx, hsh, spike, ribbon, seg_quads, circle_pts, scale_poly, font  # noqa: E402

OUT = os.path.join(HERE, "silah48")

for _k, _v in {
    "cobalt": "#0a1230 #172a5e #213f8c #2d58b8 #4479d8 #6ea2f0 #d0e6ff",
    "emerald": "#04200f #0b3d1f #125c30 #1a8044 #2aa85c #5cd68a #d2ffe2",
    "sapphire": "#060e38 #0e1f6c #18359c #2650c8 #3f78ea #82b2ff #e6f0ff",
    "demon": "#0b0512 #1b0d28 #2a163e #3c2156 #532f70 #6e4690 #a684c8",
    "hell": "#100304 #26080c #3e0e14 #5a161c #7a2428 #a03a38 #e88a78",
    "redglow": "#3e0404 #7a0c0c #b81a14 #e8321e #ff6038 #ff9e6c #fff0dc",
    "ebony": "#0e0907 #21150f #322017 #452d20 #5a3d2c #75523c #a07c62",
    "bamboo": "#1e1a08 #4a4214 #6e6422 #948a34 #b8ae4c #d8d070 #f6f2bc",
    "paper": "#2a1e14 #5a4430 #8a6e50 #b09676 #cdb898 #e6d6b8 #fff8e8",
    "bone": "#1e1a16 #4a4238 #706658 #968a78 #b8ad98 #d8cfba #f8f2e2",
    "navy": "#070b1c #121a3a #1c2752 #28366c #364888 #4a5ea6 #8a9cd6",
}.items():
    P[_k] = [hx(c) for c in _v.split()]

T = {
    1: dict(name="Bakır", metal="copper", trim="copper", dark="iron", wood="wood", grip="leather", gem=None, glow=None, spark=None),
    2: dict(name="Çelik", metal="steel", trim="iron", dark="iron", wood="wood", grip="leather", gem="emerald", glow=None, spark=None),
    3: dict(name="Kobalt", metal="cobalt", trim="gold", dark="iron", wood="ebony", grip="navy", gem="sapphire", glow=None, spark="silver"),
    4: dict(name="Gece", metal="demon", trim="silver", dark="obsid", wood="demon", grip="plum", gem="arc", glow="arc", spark="arc"),
    5: dict(name="Kızıl Kor", metal="hell", trim="gold", dark="obsid", wood="hell", grip="obsid", gem="ruby", glow="redglow", spark="fire"),
}


def LV(lv, v1, v5):
    return v1 + (v5 - v1) * (lv - 1) / 4.0


def frame(kind):
    """Çizim çerçevesi: a = silah ekseni (uca doğru +), b = eksene dik (b<0 ışıklı sol-üst taraf)."""
    if kind == "diag":
        O, u, v, AS = (24.5, 24.5), (1 / R2, -1 / R2), (1 / R2, 1 / R2), 0.955
    elif kind == "horiz":
        O, u, v, AS = (24.0, 24.5), (1.0, 0.0), (0.0, 1.0), 1.0
    else:  # vert: a yukarı, b sağa
        O, u, v, AS = (24.5, 24.0), (0.0, -1.0), (1.0, 0.0), 1.0

    def xy(a, b):
        a *= AS
        return (O[0] + a * u[0] + b * v[0], O[1] + a * u[1] + b * v[1])

    def ab(qx, qy):
        px, py = qx - O[0], qy - O[1]
        return (px * u[0] + py * u[1]) / AS, px * v[0] + py * v[1]

    E.xy, E.ab = xy, ab


class Cv(Canvas):
    def __init__(self, lv):
        super().__init__()
        self.lv = lv

    def halo(self, mat):
        """Son çizilen parçayı ışıyan yap, halesi verilen malzemenin renginde."""
        self.parts[-1]["halo"] = mat
        self.parts[-1]["emis"] = True

    def render(self):
        pix = {k: list(v) for k, v in self.pix.items()}
        for (x, y), (c, pid) in self.pix.items():
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                o = self.pix.get((x + dx, y + dy))
                if o is not None and o[1] > pid and self.parts[o[1]]["sep"]:
                    pix[(x, y)][0] = P[self.parts[o[1]]["mat"]][0]
                    break
        img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        for (x, y), (c, pid) in pix.items():
            img.putpixel((x, y), c + (255,))
        outl = {}
        for (x, y), (c, pid) in self.pix.items():
            part = self.parts[pid]
            if not part["outline"]:
                continue
            ol = P[part["mat"]][0]
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                k = (x + dx, y + dy)
                if k in self.pix or not (0 <= k[0] < N and 0 <= k[1] < N):
                    continue
                if k not in outl or sum(ol) < sum(outl[k]):
                    outl[k] = ol
        for k, c in outl.items():
            img.putpixel(k, c + (255,))
        steps = [(1.5, 110), (2.3, 48)] if self.lv < 5 else [(1.5, 125), (2.3, 64), (3.2, 26)]
        rad = steps[-1][0]
        best = {}
        for (ex, ey), (c, pid) in self.pix.items():
            part = self.parts[pid]
            if not part["emis"]:
                continue
            m = part.get("halo", part["mat"])
            for dy in range(-4, 5):
                for dx in range(-4, 5):
                    k = (ex + dx, ey + dy)
                    if not (0 <= k[0] < N and 0 <= k[1] < N) or k in self.pix or k in outl:
                        continue
                    d = math.hypot(dx, dy)
                    if d <= rad and (k not in best or d < best[k][0]):
                        best[k] = (d, m)
        for k, (d, m) in best.items():
            al = next(a for r, a in steps if d <= r)
            img.putpixel(k, P[m][4] + (al,))
        for (x, y), c in self.post.items():
            under = img.getpixel((x, y))
            if c[3] < 255 and under[3] == 255:
                continue
            img.putpixel((x, y), c)
        return img


# ---------------------------------------------------------------- ortak parçalar
def facet(c, poly, mat, **kw):
    kw.setdefault("emis", False)
    c.gem(poly, mat, **kw)


def gem_at(c, a, b, r, lv):
    g = T[lv]["gem"]
    if not g:
        return
    if lv >= 4:
        c.sphere((a, b), r, g, glow=True)
    else:
        c.sphere((a, b), r, g, shine=0.55)


def vein(c, pts, lv, r=0.45):
    g = T[lv]["glow"]
    if g:
        c.tube(pts, r, g, glow=(6, 5, 4), sep=False, outline=False)


def fx(c, lv, spots):
    """Seviyeye göre parıltı: 3 tek ışıltı, 4 + yıldız, 5 + büyük yıldız + kor kıvılcımları."""
    m = T[lv]["spark"]
    if m is None:
        return
    if len(spots) > 0:
        c.glint(*spots[0], m if lv > 3 else "silver", 6)
    if lv >= 4 and len(spots) > 1:
        c.star(*spots[1], m, 1)
    if lv >= 5:
        if len(spots) > 2:
            c.star(*spots[2], m, 2)
        for s in spots[3:]:
            c.dot(*s, m, 5)


def ring(c, a, by, rr, mat, wa=1.2):
    """Yatay çerçevede namlu bileziği: dar dikdörtgen levha (kısa tüp kapsül olur, top gibi görünür)."""
    c.plate([(a, by - rr), (a + wa, by - rr), (a + wa, by + rr), (a, by + rr)], mat, bevel=0.9, shine=0.4)


def pgrain(idx, a, b, x, y, d):
    if d > 1.0 and idx > 1 and hsh(int(round(b * 1.4)), int(math.floor(a / 2.6)), 5) < 0.22:
        return idx - 1
    return idx


def teeth_edge(a_from, a_to, w_from, w_to, n, depth, side, lean=0.25):
    """a_from -> a_to boyunca side*w kenarında n diş; diş tepesi a_from tarafına yakın (uç tarafa eğik)."""
    pts = []
    for i in range(n):
        s0 = a_from + (a_to - a_from) * i / n
        s1 = a_from + (a_to - a_from) * (i + 1) / n
        w0 = w_from + (w_to - w_from) * i / n
        w1 = w_from + (w_to - w_from) * (i + 1) / n
        pts.append((s0, side * w0))
        pts.append((s0 + (s1 - s0) * lean, side * (w0 + (w1 - w0) * lean + depth)))
    pts.append((a_to, side * w_to))
    return pts


def pommel(c, lv, pe, scale=1.0):
    tr = T[lv]["trim"]
    if lv >= 4:
        facet(c, spike((pe + 1.4, 0), (pe - 2.6 * scale, 0), 1.25 * scale, shoulder=0.25), tr)
    r = LV(lv, 1.5, 2.3) * scale
    c.sphere((pe + 1.2, 0), r, tr, shine=0.4)
    if lv >= 2:
        gem_at(c, pe + 1.2, 0, r * 0.5, lv)


def guard(c, lv, g, half, k=1.0):
    t = T[lv]
    tr = t["trim"]
    if lv == 1:
        c.tube([(g, -half), (g, half)], 0.85 * k, tr, shine=0.35)
    elif lv == 2:
        for s in (-1, 1):
            c.tube([(g, 0), (g + 0.2, s * half * 0.72), (g + 1.6 * k, s * half)], (1.35 * k, 0.75), tr, shine=0.4)
    elif lv == 3:
        for s in (-1, 1):
            c.tube([(g, 0), (g, s * half * 0.7), (g + 1.2 * k, s * half), (g + 2.5 * k, s * half * 0.84), (g + 1.9 * k, s * half * 0.66)],
                   (1.35 * k, 0.6), tr, shine=0.45)
        c.sphere((g, 0), 1.9 * k, tr, shine=0.45)
        gem_at(c, g, 0, 1.0 * k, lv)
    elif lv == 4:
        for s in (-1, 1):
            facet(c, spike((g - 0.4, s * 1.4), (g + 4.0 * k, s * half), 1.15 * k), tr)
            facet(c, spike((g - 0.6, s * 1.2), (g - 3.0 * k, s * half * 0.7), 0.9 * k), tr)
        c.tube([(g, -2.7 * k), (g, 2.7 * k)], 1.45 * k, t["metal"], shine=0.4)
        gem_at(c, g, 0, 1.15 * k, lv)
    else:
        for s in (-1, 1):
            wing = [(g + 0.9, s * 1.2), (g + 1.4, s * half * 0.55), (g - 0.2, s * half), (g - 3.6 * k, s * half * 1.02),
                    (g - 2.3 * k, s * half * 0.74), (g - 3.8 * k, s * half * 0.6), (g - 1.9 * k, s * half * 0.38), (g - 1.2, s * 1.2)]
            c.plate(wing, tr, bevel=1.3, shine=0.35)
        c.sphere((g, 0), 2.2 * k, tr, shine=0.45)
        gem_at(c, g, 0, 1.3 * k, lv)


# ---------------------------------------------------------------- BIÇAK + UZUNKILIÇ (çapraz)
def blade_tex(lv, fuller=False):
    glow = T[lv]["glow"] if lv == 5 else None

    def f(idx, a, b, x, y, d):
        if glow and d < 0.8:
            return P[glow][5] if b < 0 else P[glow][4]
        if d < 1.0:
            return 5 if b < 0 else 2
        if abs(b) < 0.36:
            return 2 if fuller else 5
        return 4 if b < 0 else 3
    return f


def blade_poly(kind, lv, b0, tip, w):
    L = tip - b0
    if kind == "dagger":
        if lv == 1:  # yaprak
            return [(b0, -w * 0.6), (b0 + L * 0.4, -w), (tip, 0), (b0 + L * 0.4, w), (b0, w * 0.6)]
        if lv == 2:  # geniş üçgen
            return [(b0, -w), (b0 + L * 0.3, -w * 0.95), (tip, 0), (b0 + L * 0.3, w * 0.95), (b0, w)]
        if lv == 3:  # sırtta kılıç kıran çentiği
            return [(b0, -w), (b0 + L * 0.35, -w * 0.9), (tip, 0), (b0 + L * 0.5, w * 0.75), (b0 + L * 0.36, w * 0.75),
                    (b0 + L * 0.3, w * 1.25), (b0 + L * 0.18, w * 0.8), (b0 + L * 0.1, w * 1.15), (b0, w)]
        if lv == 4:  # sırtta iki büyük kanca
            return ([(b0, -w), (b0 + L * 0.35, -w * 0.92), (tip, 0), (b0 + L * 0.62, w * 0.72)]
                    + teeth_edge(b0 + L * 0.6, b0 + L * 0.12, w * 0.72, w * 1.0, 2, 2.0, 1, lean=0.2) + [(b0, w)])
        left = teeth_edge(b0 + L * 0.66, b0 + L * 0.08, w * 0.72, w * 1.0, 2, 1.6, -1)
        right = teeth_edge(b0 + L * 0.66, b0 + L * 0.08, w * 0.72, w * 1.0, 3, 1.8, 1)
        return [(b0, -w)] + left[::-1] + [(tip, 0)] + right + [(b0, w)]
    tl = w * 2.0
    if lv == 1:
        return [(b0, -w), (tip - tl, -w), (tip, 0), (tip - tl, w), (b0, w)]
    if lv == 2:
        return [(b0, -w * 1.05), (tip - tl, -w * 0.92), (tip, 0), (tip - tl, w * 0.92), (b0, w * 1.05)]
    if lv == 3:  # uca doğru genişleyen
        return [(b0, -w * 0.85), (b0 + 2.5, -w * 1.0), (tip - tl * 1.6, -w * 1.18), (tip, 0), (tip - tl * 1.6, w * 1.18), (b0 + 2.5, w * 1.0), (b0, w * 0.85)]
    if lv == 4:
        return ([(b0, -w), (b0 + 2.5, -w * 1.1), (tip - tl * 1.3, -w * 0.95), (tip, 0), (tip - tl * 1.3, w * 0.95)]
                + teeth_edge(tip - tl * 1.3, b0 + 3, w * 0.95, w * 1.05, 3, 1.9, 1, lean=0.2) + [(b0, w)])
    left = teeth_edge(tip - tl * 1.2, b0 + 2, w * 0.9, w * 1.05, 5, 1.2, -1)
    right = teeth_edge(tip - tl * 1.2, b0 + 2, w * 0.9, w * 1.05, 5, 1.2, 1)
    return [(b0, -w * 1.05)] + left[::-1] + [(tip, 0)] + right + [(b0, w * 1.05)]


def bladed(c, lv, kind):
    t = T[lv]
    if kind == "dagger":
        g, tip, w, pe, half = -8.0, LV(lv, 15, 27), LV(lv, 3.0, 4.3), LV(lv, -17, -23), LV(lv, 3.2, 6.6)
    else:
        g, tip, w, pe, half = -12.0, LV(lv, 25, 31.2), LV(lv, 2.0, 2.8), LV(lv, -25, -28.5), LV(lv, 4.0, 8.6)
    c.tube([(pe + 1.8, 0), (g - 0.8, 0)], 1.2 if lv < 3 else 1.38, t["grip"], tex=E.wrap, shine=0.1)
    pommel(c, lv, pe, 0.85 if lv == 1 else 1.0)
    b0 = g + 0.4
    c.plate(blade_poly(kind, lv, b0, tip, w), t["metal"], bevel=1.3, shine=0.3, tex=blade_tex(lv, fuller=(kind == "sword" and lv >= 2)))
    if lv == 5:
        c.halo(t["glow"])
    if lv >= 4:
        vein(c, [(b0 + 2.0, 0), (b0 + (tip - b0) * (0.6 if kind == "dagger" else 0.78), 0)], lv, r=0.5)
    elif kind == "sword" and lv == 3:
        c.tube([(b0 + 1.5, 0), (b0 + 6.5, 0)], 0.5, "gold", shine=0.5, sep=False, outline=False)
    guard(c, lv, g, half)
    L = tip - b0
    fx(c, lv, [(b0 + L * 0.72, -w * 0.4), (tip - 4.5, -w - 2.2), (b0 + L * 0.45, w + 4.5), (b0 + L * 0.85, w + 2.2), (b0 + L * 0.3, -w - 3.4)])


def w_dagger(c, lv):
    bladed(c, lv, "dagger")


def w_uzunkilic(c, lv):
    bladed(c, lv, "sword")


# ---------------------------------------------------------------- TOPUZ (çapraz)
def w_topuz(c, lv):
    t = T[lv]
    m, tr = t["metal"], t["trim"]
    hc, R = LV(lv, 15.5, 15.5), LV(lv, 5.0, 6.8)
    pe = LV(lv, -26, -29)
    sm = t["wood"] if lv <= 3 else m
    c.tube([(pe + 1.5, 0), (hc - R * 0.5, 0)], LV(lv, 1.15, 1.35), sm, tex=E.grain if lv <= 3 else None, shine=0.3)
    c.tube([(pe + 2.2, 0), (pe + LV(lv, 10, 12), 0)], LV(lv, 1.4, 1.6), t["grip"], tex=E.wrap, shine=0.1)
    pommel(c, lv, pe)
    if lv >= 3:
        c.tube([(pe + 12.5, 0), (pe + 13.9, 0)], 1.8, tr, shine=0.4)
    if lv >= 4:
        vein(c, [(pe + 16, 0), (pe + 18, -0.4), (pe + 20, 0.4), (pe + 22, 0)], lv, r=0.42)
    c.tube([(hc - R - 2.2, 0), (hc - R + 0.6, 0)], (LV(lv, 1.6, 2.0), LV(lv, 2.0, 2.8)), tr if lv >= 2 else m, shine=0.4)
    if lv in (1, 3):
        n = 4 if lv == 1 else 6
        fl = LV(lv, 2.4, 3.0)
        for k in range(n):
            th = 2 * math.pi * k / n + math.pi / n
            ca, sa = math.cos(th), math.sin(th)
            pa, pb = -sa, ca
            inner, outer, wd = R * 0.4, R + fl, 1.5 if lv == 1 else 1.25
            poly = [(hc + ca * inner + pa * wd, sa * inner + pb * wd), (hc + ca * outer + pa * wd * 0.7, sa * outer + pb * wd * 0.7),
                    (hc + ca * outer - pa * wd * 0.7, sa * outer - pb * wd * 0.7), (hc + ca * inner - pa * wd, sa * inner - pb * wd)]
            c.plate(poly, m if lv == 1 else tr, bevel=1.0, shine=0.35)
    else:
        n = {2: 6, 4: 8, 5: 8}[lv]
        sl = LV(lv, 3.2, 4.0)
        for k in range(n):
            th = 2 * math.pi * k / n + 0.3
            ca, sa = math.cos(th), math.sin(th)
            facet(c, spike((hc + ca * R * 0.85, sa * R * 0.85), (hc + ca * (R + sl), sa * (R + sl)), LV(lv, 1.5, 2.0), shoulder=0.15), m if lv == 2 else tr)
    c.sphere((hc, 0), R, m, shine=0.35)
    if lv >= 2:
        k = R / 5.0
        for da, db in ((-1.8, -1.6), (1.9, -0.6), (-0.4, 2.1)):
            c.sphere((hc + da * k, db * k), 0.8, tr, shine=0.6)
    if lv >= 3:
        c.gem(spike((hc + R * 0.5, 0), (hc + R + LV(lv, 2.5, 4.0), 0), LV(lv, 1.3, 1.8)), t["gem"], emis=lv >= 4)
    if lv >= 4:
        vein(c, [(hc - R * 0.6, -R * 0.2), (hc - R * 0.1, R * 0.25), (hc + R * 0.3, -R * 0.15), (hc + R * 0.55, R * 0.35)], lv, r=0.4)
        vein(c, [(hc - R * 0.1, R * 0.25), (hc - R * 0.2, R * 0.65)], lv, r=0.4)
    fx(c, lv, [(hc - R * 0.3, -R * 0.5), (hc + R + 1.5, -R - 1.2), (hc - R - 1.5, R + 2.5), (hc + 1.5, R + 3.2), (hc - 3.0, -R - 3.5)])


# ---------------------------------------------------------------- PENÇE (çapraz, eldiven + pençeler sağ-üste)
def w_pence(c, lv):
    t = T[lv]
    tr = t["trim"]
    cuff = ["", "leather", "steel", "cobalt", "demon", "hell"][lv]
    hand = ["", "leather", "leather", "navy", "demon", "hell"][lv]
    claw = ["", "copper", "steel", "silver", "demon", "hell"][lv]
    n = 3 if lv <= 2 else 4
    bs = [-2.6, 0.0, 2.6] if n == 3 else [-3.9, -1.3, 1.3, 3.9]
    fan = [-12.0, 0.0, 12.0] if n == 3 else [-18.0, -6.0, 6.0, 18.0]
    cl = LV(lv, 13.0, 19.0)
    glow = t["glow"]

    def ctex(idx, a, b, x, y, d):
        if lv == 5 and d < 0.8:
            return P["redglow"][5]
        if d < 0.8:
            return 6 if idx >= 4 else idx
        return idx

    # pençeler (eldivenin arkasında başlar): her biri yelpaze açısında, uca doğru aynı yöne kıvrılır
    for b0, ph in zip(bs, fan):
        pts = []
        pa, pb = -3.5, b0
        for k in range(6):
            ang = math.radians(ph + 16.0 * (k / 5.0) ** 1.6)
            pts.append((pa, pb))
            pa += cl / 5.0 * math.cos(ang)
            pb += cl / 5.0 * math.sin(ang)
        c.plate(ribbon(pts, LV(lv, 1.1, 1.35), 0.12), claw, bevel=1.0, shine=0.45, tex=ctex)
        if glow:
            c.halo(glow)
    # manşet
    cw0, cw1 = LV(lv, 3.0, 3.5), LV(lv, 3.5, 4.1)
    c.plate([(-26, -cw0), (-16.5, -cw1), (-16.5, cw1), (-26, cw0)], cuff, bevel=2.2, shine=0.25)
    c.tube([(-25.6, -cw0 - 0.2), (-25.6, cw0 + 0.2)], 0.75, tr if lv >= 2 else "leather", shine=0.35)
    if lv <= 3:
        c.tube([(-21.5, -cw0 - 0.3), (-21.5, cw0 + 0.3)], 0.6, "leather" if lv == 1 else tr, shine=0.3)
    if lv >= 4:
        for sg in (-1, 1):
            facet(c, spike((-21, sg * 3.0), (-25.5, sg * LV(lv, 6.8, 8.0)), 1.0), tr)
    c.tube([(-17.2, 0), (-15.6, 0)], LV(lv, 3.9, 4.8), tr if lv >= 2 else "wood", shine=0.4)
    if lv >= 4:
        vein(c, [(-25, -1.2), (-22.5, 0.6), (-20, -0.6), (-18, 0.6)], lv, r=0.42)
    if lv == 5:
        for sg in (-1, 1):
            c.plate([(-23, sg * 3.6), (-19.5, sg * 4.2), (-21, sg * 7.0), (-24.0, sg * 7.8), (-23.4, sg * 6.0), (-25.4, sg * 5.4)],
                    tr, bevel=1.2, shine=0.35)
    # el sırtı + boğum plakası + boğumlar
    hp = [(-16.0, -4.2), (-10, -5.0), (-5.5, -4.8), (-3.0, -3.4), (-2.6, 0), (-3.0, 3.4), (-5.5, 4.8), (-10, 5.0), (-16.0, 4.2)]
    c.plate(hp, hand, bevel=1.8, shine=0.2)
    if lv >= 2:
        c.plate([(-13, -3.4), (-8, -3.9), (-6, -2.6), (-6, 2.6), (-8, 3.9), (-13, 3.4)], t["metal"] if lv >= 3 else "steel", bevel=1.4, shine=0.3)
    for b0 in bs:
        c.sphere((-4.0, b0), LV(lv, 0.95, 1.25), tr if lv >= 2 else "copper", shine=0.45)
    if lv >= 2:
        gem_at(c, -9.6, 0, LV(lv, 1.1, 1.9), lv)
    fx(c, lv, [(cl * 0.45, -3.6), (cl * 0.9, -6.5), (cl * 0.35, 9.0), (cl * 0.85, 6.0), (cl * 0.2, -8.0)])


# ---------------------------------------------------------------- ASALAR (çapraz) - her asanın KENDİ silueti (kullanıcı: "asalar
# birbirine çok benziyor"): Ateş mangal kâsesi, Yıldırım paratoner çatalı, Arcane çoban kancası, Buz kristal mızrak.
F1 = [(0, -0.8), (0.35, -1.0), (0.7, -0.6), (1.0, 0.05), (0.65, 0.55), (0.35, 1.0), (0, 0.8)]
F3 = [(0, -0.68), (0.22, -0.82), (0.33, -0.58), (0.53, -1.0), (0.56, -0.45), (0.74, -0.36), (1.0, 0.03), (0.74, 0.27), (0.64, 0.67),
      (0.51, 0.39), (0.36, 0.82), (0.19, 0.73), (0, 0.67)]
F5 = [(0, -0.7), (0.15, -0.9), (0.25, -0.7), (0.38, -1.05), (0.45, -0.6), (0.62, -0.85), (0.66, -0.35), (0.82, -0.32), (1.0, 0.0),
      (0.8, 0.3), (0.7, 0.62), (0.6, 0.4), (0.46, 0.95), (0.38, 0.55), (0.24, 0.78), (0.14, 0.6), (0, 0.7)]


def flame(c, base, length, width, tmpl, mat="fire", cap=30.6):
    length = min(length, cap - base)
    fo = [(base + u * length, v * width) for u, v in tmpl]
    c.layers([fo, scale_poly(fo, base + length * 0.15, 0, 0.72), scale_poly(fo, base + length * 0.1, 0, 0.46),
              scale_poly(fo, base, 0, 0.22)], mat, (3, 4, 5, 6))


def char_tex(idx, a, b, x, y, s, v):
    """Yanık ahşap: damar + kömürleşmiş lekeler."""
    idx = E.grain(idx, a, b, x, y, s, v)
    if idx > 1 and hsh(x, y, 11) < 0.13:
        return max(1, idx - 2)
    return idx


def w_fire_staff(c, lv):
    """Ateş = MANGAL: kalın yanık gövde + kor çatlakları, tepede ağzı ileri açılan kâse ve içinden yükselen alev (L1 bez sargılı meşale).
    L4 öne kıvrık boynuzlar, L5 geriye açılan anka kanatları."""
    t = T[lv]
    tr = t["trim"]
    sm = ["", "wood", "wood", "ebony", "demon", "hell"][lv]
    pe = LV(lv, -26.5, -29.0)
    ca = LV(lv, 10.5, 11.5)
    R = LV(lv, 3.4, 5.2)
    if lv >= 2:
        c.tube([(pe + 0.4, 0), (pe + 2.6, 0)], (1.2, 1.75), tr, shine=0.4)
    c.tube([(pe + 1.5, 0), (ca, 0)], LV(lv, 1.35, 1.5), sm, tex=char_tex if lv <= 3 else None, shine=0.25)
    for pts in [[(-20, 0.3), (-18.5, -0.4), (-17, 0.3)], [(-4.5, -0.3), (-3.0, 0.4), (-1.5, -0.3)], [(-24, -0.3), (-22.6, 0.4)],
                [(3.0, 0.3), (4.5, -0.4), (6.0, 0.3)]][:lv - 1]:
        c.tube(pts, 0.42, "fire", glow=(5, 5, 4), sep=False, outline=False)
    if lv >= 2:
        c.tube([(-14, 0), (-8, 0)], 1.8, t["grip"], tex=E.wrap, shine=0.1)
    if lv >= 3:
        c.tube([(-7.6, 0), (-6.2, 0)], 1.95, tr, shine=0.45)
        gem_at(c, -6.9, -1.8, 0.8, lv)
    flame(c, ca + (2.0 if lv >= 2 else 0.6), R + LV(lv, 6.0, 13.0), R * LV(lv, 0.95, 1.15), [F1, F3, F3, F5, F5][lv - 1])
    if lv == 1:
        c.tube([(ca - 3.2, 0), (ca + 1.4, 0)], 2.0, "paper", tex=E.wrap, shine=0.15)
        c.tube([(ca - 3.6, 0), (ca - 2.6, 0)], 2.15, "leather", shine=0.3)
    else:
        if lv == 5:
            for sg in (-1, 1):
                c.plate([(ca + 1.5, sg * R * 0.7), (ca + 0.5, sg * (R + 2.5)), (ca - 2.5, sg * (R + 5.5)), (ca - 2.2, sg * (R + 3.0)),
                         (ca - 5.0, sg * (R + 4.0)), (ca - 3.4, sg * (R + 1.2)), (ca - 1.0, sg * 1.6)], tr, bevel=1.2, shine=0.35)
        c.tube([(ca - 3.0, 0), (ca - 1.2, 0)], (1.6, 2.0), tr, shine=0.4)
        bowl = [(ca - 1.6, -1.7), (ca + 1.2, -R * 0.8), (ca + 3.6, -R), (ca + 4.4, -R - 0.4), (ca + 4.4, R + 0.4), (ca + 3.6, R),
                (ca + 1.2, R * 0.8), (ca - 1.6, 1.7)]
        c.plate(bowl, t["metal"] if lv >= 3 else "iron", bevel=1.8, shine=0.3)
        if lv >= 3:
            for b1 in (-R * 0.62, R * 0.62):
                c.tube([(ca - 0.6, b1 * 0.3), (ca + 4.0, b1)], 0.5, tr, shine=0.45)
        c.tube([(ca + 4.3, -R - 0.7), (ca + 4.3, R + 0.7)], 0.8, tr, shine=0.45)
        gem_at(c, ca + 1.6, 0, LV(lv, 0.9, 1.3), lv)
        if lv >= 4:
            for sg in (-1, 1):
                hp = [(ca + 3.0, sg * (R - 0.2)), (ca + 5.0, sg * (R + 2.4)), (ca + 8.0, sg * (R + 3.6)), (ca + 10.5, sg * (R + 3.0))]
                c.plate(ribbon(hp, 1.3, 0.2), tr, bevel=1.0, shine=0.45)
    for a, b in [(ca + R + 9.0, -R - 1.0), (ca + 6.0, R + 2.6), (ca + R + 4.0, -R - 2.6), (ca + 11.0, R + 1.0)][:lv - 1]:
        c.dot(a, b, "fire", 5)
    if lv >= 4:
        c.star(ca + 6.0, -R - 3.6, "fire", 1)
    if lv == 5:
        c.star(ca - 4.0, R + 6.4, "fire", 2)


def w_lightning_staff(c, lv):
    """Yıldırım = PARATONER ÇATALI: ince düz metal çubuk + bakır bobin grupları + toprak sivrisi, tepede çatal (L3'ten üç dişli),
    dişler arasında şimşek arkları. L4 dikenli dişler, L5 orta diş şimşeğin kendisi."""
    t = T[lv]
    tr = t["trim"]
    rod = ["", "wood", "steel", "cobalt", "demon", "hell"][lv]
    cm = ["", "copper", "copper", "gold", "silver", "gold"][lv]
    tm = t["metal"]
    pe = LV(lv, -27.0, -29.0)
    fa = LV(lv, 8.0, 9.0)
    tl = LV(lv, 26.0, 28.5)
    sp = LV(lv, 3.2, 4.6)
    facet(c, spike((pe + 2.2, 0), (pe - 1.2, 0), 1.0, shoulder=0.3), "copper" if lv == 1 else t["metal"])
    c.tube([(pe + 1.5, 0), (fa, 0)], 1.05, rod, tex=E.grain if lv == 1 else None, shine=0.45)
    for a0 in [[-4.0], [-20.0, -4.0], [-20.0, -11.0, -2.0], [-20.0, -11.0, -2.0], [-21.0, -12.0, -3.0]][lv - 1]:
        E.coil(c, a0, 4, cm, step=1.4, r=0.5)
    arcs = [[], [fa + 10.0], [fa + 7.0, fa + 13.0], [fa + 6.0, fa + 11.0, fa + 15.5], [fa + 7.0, fa + 14.0]][lv - 1]
    for a0 in arcs:
        c.tube([(a0, -sp + 0.8), (a0 + 1.4, -sp * 0.4), (a0 - 0.6, -sp * 0.05), (a0 + 1.0, sp * 0.35), (a0 - 0.2, sp - 0.8)], 0.5, "bolt",
               glow=(6, 6, 5), sep=False, outline=False)
        c.parts[-1]["emis"] = False  # hale dişler arasını doldurup başı tek lekeye çeviriyordu
    for sg in (-1, 1):
        c.tube([(fa, 0), (fa + 2.0, sg * sp * 0.9), (fa + 5.0, sg * sp * 1.1), (tl - 4.0, sg * sp)], (0.95, 0.6), tm, shine=0.45)
        facet(c, spike((tl - 4.4, sg * sp), (tl - 1.4, sg * sp * 0.72), 0.85, shoulder=0.2), tr if lv >= 2 else "copper")
        if lv >= 4:
            facet(c, spike((tl - 7.5, sg * sp * 1.05), (tl - 10.0, sg * (sp + 2.0)), 0.65), tr)
    if lv >= 3:
        if lv < 5:
            c.tube([(fa, 0), (tl - 1.0, 0)], (0.8, 0.5), tm, shine=0.45)
            facet(c, spike((tl - 1.4, 0), (tl + 0.8, 0), 0.8), tr)
        else:
            zz = [(fa + 1.0, 0), (fa + 7.0, -1.6), (fa + 6.2, 0.8), (fa + 13.0, -1.0), (fa + 12.4, 0.9), (tl + 0.8, 0)]
            c.layers_union([seg_quads(zz, 1.35, 0.35), seg_quads(zz, 0.8, 0.2), seg_quads(zz, 0.4, 0.1)], "bolt", (4, 5, 6))
        if lv < 5:
            c.gem([(fa + 2.0, 0), (fa + 3.8, -1.4), (fa + 6.2, 0), (fa + 3.8, 1.4)], "bolt", table=0.4)
    c.tube([(fa - 2.2, 0), (fa + 0.4, 0)], (1.5, 1.9), tr if lv >= 2 else "copper", shine=0.45)
    if lv >= 2:
        gem_at(c, fa - 0.9, -1.75, 0.8, lv)
    c.star(tl - 1.6, -sp - 1.6, "bolt", 1)
    if lv >= 3:
        c.glint(tl - 6.0, sp + 1.6, "bolt", 6)
    if lv >= 4:
        c.tube([(fa + 9.0, sp + 2.0), (fa + 10.0, sp + 3.2), (fa + 9.2, sp + 4.2)], 0.42, "bolt", glow=(6, 6, 5), outline=False, sep=False)
    if lv == 5:
        c.star(fa - 4.0, -sp - 3.0, "bolt", 2)
        c.tube([(fa + 14.0, -sp - 2.0), (fa + 15.2, -sp - 3.0), (fa + 14.4, -sp - 4.2)], 0.42, "bolt", glow=(6, 6, 5), outline=False, sep=False)


def w_arcane(c, lv):
    """Arcane = ÇOBAN KANCASI: burgulu gövde (L1 eğri dal, L2 iki dal sarmal, L3+ koyu dal + metal tel sarmal), tepe sol-üste kıvrılan kanca,
    kancanın içinde asılı (L1-2 iple) / süzülen (L3+) mor küre. L4 karşı yanda süzülen kıymıklar + rünler, L5 ikinci küre."""
    t = T[lv]
    tr = t["trim"]
    sm = ["", "wood", "wood", "ebony", "demon", "hell"][lv]
    pe = LV(lv, -26.5, -29.0)
    hc = LV(lv, 15.5, 16.0)
    Rr = LV(lv, 4.0, 5.0)
    sweep = math.radians(LV(lv, 235, 290))
    Ro = LV(lv, 1.9, 3.0)
    if lv >= 2:
        c.tube([(pe + 0.4, 0), (pe + 2.6, 0)], (1.6, 1.2), tr, shine=0.4)
        c.sphere((pe + 0.9, 0), 0.9, "arc", glow=True)
    if lv == 1:
        c.tube([(pe + 1.0, 0.3), (-18, -0.5), (-9, 0.6), (0, -0.5), (8, 0.4), (hc, 0)], 1.2, sm, tex=E.grain, shine=0.25)
    else:
        n = 36
        A = [pe + 1.5 + i * (hc - pe - 1.5) / n for i in range(n + 1)]
        sa = [(a, -0.8 * math.sin(2 * math.pi * a / 6.5)) for a in A]
        sb = [(a, 0.8 * math.sin(2 * math.pi * a / 6.5)) for a in A]
        c.tube(sb, 0.8 if lv == 2 else 0.6, sm if lv == 2 else tr, shine=0.45, tex=E.grain if lv == 2 else None)
        c.tube(sa, 0.85, sm, shine=0.3, tex=E.grain if lv <= 3 else None)
        c.tube([(-14.5, 0), (-8.5, 0)], 1.75, t["grip"], tex=E.wrap, shine=0.1)
    if lv >= 4:
        for a in (-20.0, -4.0, 6.0):
            x0, y0 = E.xy(a, 0.0)
            pid = c._part(t["glow"], False, True, True)
            for dx, dy in ((0, 0), (1, -1), (-1, 1)):
                c.pix[(int(x0) + dx, int(y0) + dy)] = [P[t["glow"]][5 if (dx, dy) == (0, 0) else 4], pid]
    hk = []
    for i in range(15):
        th = sweep * i / 14
        hk.append((hc + Rr * math.sin(th), -Rr + Rr * math.cos(th)))
    hm = sm if lv <= 2 else tr
    c.tube(hk, (1.25, 0.7), hm, tex=E.grain if lv <= 2 else None, shine=0.4)
    ea, eb = hk[-1]
    if lv == 2:
        c.sphere((ea, eb), 1.0, "iron", shine=0.45)
    elif lv == 3:
        c.sphere((ea, eb), 1.0, t["gem"], shine=0.55)
    elif lv == 4:
        facet(c, spike((ea, eb), (ea - 2.6 * math.cos(sweep), eb + 2.6 * math.sin(sweep)), 0.75), tr)
    elif lv == 5:
        c.sphere((ea, eb), 1.15, "ruby", glow=True)
    c.tube([(hc - 2.2, 0), (hc - 0.4, 0)], (1.5, 1.8), tr if lv >= 2 else "wood", shine=0.4)
    if lv >= 3:
        gem_at(c, hc - 1.3, 1.7, 0.8, lv)
    oc = (hc + 0.3, -Rr)
    if lv <= 2:
        c.tube([(hc + Rr, -Rr), (oc[0] + Ro, -Rr)], 0.35, "ash", shine=0.2, sep=False)
    c.sphere(oc, Ro, "arc", shine=0.4, emis=True)
    for da, db, k in [(-0.35, 0.25, 5), (0.15, 0.5, 4), (0.45, 0.1, 4), (-0.1, -0.15, 6), (0.3, -0.45, 4)][:lv]:
        c.dot(oc[0] + Ro * da, oc[1] + Ro * db, "arc", k)
    if lv >= 3:
        seen = set()
        for k, (a, b) in enumerate(circle_pts(oc[0], oc[1], Ro + 1.6, n=34, ra=Ro * 0.6)):
            x, y = E.xy(a, b)
            if k % 2 == 0:
                seen.add((int(x), int(y)))
        for (x, y) in seen:
            if (x, y) not in c.pix:
                c._post(x, y, P["arc"][5] + (170,))
    if lv >= 4:
        for (ba, bb), (ta, tb) in [((hc + 3.0, 3.0), (hc + 6.5, 5.6)), ((hc - 1.0, 4.0), (hc + 0.6, 8.0)),
                                   ((hc + 6.5, 1.6), (hc + 10.5, 2.4))][:2 if lv == 4 else 3]:
            c.gem(spike((ba, bb), (ta, tb), 1.0 if lv == 4 else 1.2), "arc")
    if lv == 5:
        c.sphere((hc + 8.5, 6.2), 1.4, "arc", glow=True)
    c.star(hc + Rr + 2.4, -Rr - 2.0, "arc", 1)
    if lv >= 3:
        c.glint(oc[0] - Ro * 0.4, oc[1] - Ro * 0.4, "arc", 6)
    if lv == 5:
        c.star(hc - 6.0, -Rr - 3.0, "arc", 2)


def w_buz_asasi(c, lv):
    """Buz = KRİSTAL MIZRAK: soluk kırağılı gövde, altından sarkan buz sarkıtları, dipte buz sivrisi, tepede uzun kesme kristal mızrak;
    arkasında geriye açılan kristal yelpazesi (L5 kar tanesi tacı). L1 iple bağlanmış tek buz parçası."""
    t = T[lv]
    tr = t["trim"]
    sm = ["", "birch", "steel", "cobalt", "demon", "hell"][lv]
    pe = LV(lv, -26.5, -29.0)
    ca = LV(lv, 8.0, 7.0)
    tip = LV(lv, 25.5, 30.5)
    w = LV(lv, 2.0, 3.1)

    def frost(idx, a, b, x, y, s, v):
        if lv == 1:
            for k, sd in ((-22, 1), (-17.5, -1), (-12, 1), (-6.5, -1), (-1.5, 1)):
                if k <= a <= k + 1.0 and b * sd > -0.3:
                    return P["birch"][0] if abs(b) < 0.4 else P["birch"][1]
        if hsh(x, y, 7) < 0.06 + (a - pe) / 40.0 * 0.22:
            return P["ice"][5]
        return idx

    c.gem(spike((pe + 2.2, 0), (pe - 1.4, 0), 1.1, shoulder=0.3), "ice")
    c.tube([(pe + 1.5, 0), (ca + 1.0, 0)], 1.2, sm, tex=frost, shine=0.4 if lv >= 2 else 0.1)
    if lv >= 2:
        c.tube([(-14.5, 0), (-8.5, 0)], 1.75, t["grip"], tex=E.wrap, shine=0.1)
    for a in [-19.0, -5.0, -12.0, 1.0][:lv - 1]:
        c.gem(spike((a, 0.9), (a - 1.8, LV(lv, 3.6, 4.6)), 0.75, shoulder=0.2), "ice")
    fan = [[], [(55, 5.0)], [(55, 6.5)], [(45, 7.5), (95, 6.0)], [(38, 8.5), (88, 8.0), (138, 6.5)]][lv - 1]
    cx = ca + 3.5
    for ang, ln in fan:
        for sg in (-1, 1):
            th = math.radians(ang)
            d = (math.cos(th), sg * math.sin(th))
            c.gem(spike((cx + d[0] * 1.2, d[1] * 1.2), (cx + d[0] * ln, d[1] * ln), LV(lv, 1.2, 1.5)), "ice")
    c.gem(spike((ca, 0), (tip, 0), w, shoulder=0.25, wb=w * 0.55), "ice")
    if lv == 1:
        c.tube([(ca - 1.2, 0), (ca + 2.4, 0)], 1.75, "leather", tex=E.wrap, shine=0.2)
    else:
        c.tube([(ca - 2.6, 0), (ca - 0.4, 0)], (1.6, 2.1), tr, shine=0.45)
        for sg in (-1, 1):
            c.tube([(ca - 0.8, sg * 1.3), (ca + 1.6, sg * (w + 0.4)), (ca + 4.0, sg * w * 0.75)], (0.8, 0.45), tr, shine=0.45)
        gem_at(c, ca - 1.5, 0, LV(lv, 0.9, 1.2), lv)
    if lv >= 3:
        c.star(tip - 5.0, -w - 2.2, "ice", 1)
    if lv >= 4:
        c.star(cx - 3.5, 7.0, "ice", 1)
    if lv == 5:
        c.star(tip - 10.0, -w - 6.5, "ice", 2)
        c.dot(tip - 6.0, w + 2.0, "ice", 5)


# ---------------------------------------------------------------- TABANCA (yatay, namlu sağda)
def w_tabanca(c, lv):
    t = T[lv]
    m, tr, wd = t["metal"], t["trim"], t["wood"]
    by = -4.0
    br = LV(lv, 1.1, 2.2)
    mz = LV(lv, 9.5, 19.5)
    rear = -12.5
    grip = [(-5.0, -1.5), (-6.8, 4.0), (-8.6, 9.0), (-13.8, 10.2), (-15.2, 7.8), (-13.0, 2.0), (-12.5, -1.5)]
    c.plate(grip, wd, bevel=1.5, shine=0.15, tex=pgrain)
    if lv >= 2:
        c.tube([(-15.0, 8.4), (-13.6, 10.6), (-9.0, 10.0)], 0.9, tr, shine=0.4)
        gem_at(c, -10.4, 4.0, LV(lv, 0.9, 1.4), lv)
    c.tube([(-4.6, -0.5), (-4.8, 2.4), (-2.6, 3.6), (-0.2, 2.6), (0.0, -0.5)], 0.5, tr if lv >= 2 else "iron", shine=0.3)
    c.tube([(-2.4, -0.5), (-2.9, 2.0)], 0.5, "iron", shine=0.3)
    if lv == 1:
        c.plate([(rear, -6.4), (-2.0, -6.4), (mz - 2.5, -3.4), (mz - 2.5, -1.6), (rear + 1.0, -0.8)], wd, bevel=1.4, shine=0.15, tex=pgrain)
        c.tube([(rear + 2.0, by), (mz, by)], br, m, shine=0.45)
        c.tube([(-9.0, -6.4), (-10.6, -8.6), (-9.2, -9.8)], (0.85, 0.55), "iron", shine=0.35)
        c.plate([(-7.6, -7.4), (-5.0, -7.4), (-5.0, -6.2), (-7.6, -6.2)], "iron", bevel=1.0)
    else:
        c.plate([(rear, -7.0), (0.5, -7.0), (2.0, -5.8), (2.0, -1.0), (rear + 0.5, -1.0)], m, bevel=1.4, shine=0.3)
        c.tube([(rear + 1.0, -6.4), (rear - 0.2, -8.6), (rear + 1.4, -9.4)], (0.9, 0.55), t["dark"], shine=0.35)
        if lv == 2:
            def cyl(idx, a, b, x, y, d):
                return idx - 1 if d > 1.0 and int(round(b)) in (-5, -3) else idx
            c.plate([(-4.5, -7.4), (1.0, -7.4), (1.0, -0.6), (-4.5, -0.6)], m, bevel=1.6, shine=0.3, tex=cyl)
        c.tube([(-1.0, by), (mz, by)], br, m, shine=0.45)
    ring(c, mz - 1.6, by, br + 0.6, tr, 1.6)
    c.tube([(mz - 2.6, by - br - 0.6), (mz - 2.2, by - br - 1.4)], 0.5, tr, shine=0.4)
    if lv >= 3:
        for a in (3.0, 9.0) if lv == 3 else (2.0,):
            ring(c, a, by, br + 0.5, tr)
    if lv >= 4:
        for a in (5.0, 8.0, 11.0, 14.0)[:lv - 2]:
            vein(c, [(a, by - br + 0.6), (a + 0.6, by + br - 0.6)], lv, r=0.45)
        facet(c, spike((mz - 7.0, by + br - 0.2), (mz - 1.0, by + br + 2.8), 0.9), tr)
    if lv == 5:
        for sg in (-1, 1):
            yb = by + sg * (br + 0.2)
            c.plate([(2.0, yb), (5.0, yb + sg * 3.0), (9.0, yb + sg * 3.6), (7.5, yb + sg * 1.6), (12.0, yb + sg * 1.2), (10.0, yb)], tr, bevel=1.2, shine=0.35)
        c.tube([(mz - 0.5, by), (mz + 0.8, by)], br * 0.7, "redglow", glow=(6, 5, 4), sep=False)
        c.halo("redglow")
    fx(c, lv, [(mz - 5.0, by - 0.8), (mz + 1.0, by - br - 3.0), (-9.5, -11.0), (mz + 1.2, by + 3.2), (mz - 2.0, by - br - 5.0)])


# ---------------------------------------------------------------- TÜFEK (yatay, uzun)
def w_tufek(c, lv):
    t = T[lv]
    m, tr, wd = t["metal"], t["trim"], t["wood"]
    by = -1.5
    br = [0, 1.0, 1.0, 1.2, 1.6, 1.0][lv]
    mz = LV(lv, 20.5, 21.0)
    fe = LV(lv, 12.0, 9.0)
    stock = [(-8.5, -3.5), (-16.0, -2.5), (-21.6, -3.0), (-21.6, 4.5), (-18.2, 4.5), (-13.0, 1.0), (-7.0, 0.8)]
    c.plate(stock, wd, bevel=1.4, shine=0.15, tex=pgrain)
    if lv >= 2:
        c.tube([(-21.4, -2.6), (-21.4, 4.2)], 0.7, tr, shine=0.4)
    if lv >= 3:
        gem_at(c, -16.5, 0.8, LV(lv, 0.9, 1.3), lv)
    c.tube([(-7.0, 0.8), (-7.2, 3.4), (-4.6, 3.8), (-3.8, 0.8)], 0.5, tr if lv >= 2 else "iron", shine=0.3)
    c.tube([(-5.6, 0.6), (-6.0, 2.6)], 0.45, "iron")
    if lv == 5:
        for sg in (-1, 1):
            c.tube([(0.0, by + sg * 1.6), (mz, by + sg * 1.6)], 0.95, m, shine=0.45)
        for a in (4.0, 8.0, 12.0, 16.0):
            vein(c, [(a, by - 0.8), (a + 1.2, by + 0.8)], lv, r=0.5)
        c.tube([(1.0, by), (mz - 1.0, by)], 0.5, "redglow", glow=(6, 5, 5), sep=False, outline=False)
        c.halo("redglow")
    else:
        if lv <= 3:
            c.plate([(0.5, -0.6), (fe, -0.6), (fe + 1.4, 0.6), (fe, 1.4), (0.5, 1.4)], wd, bevel=1.2, shine=0.15, tex=pgrain)
        c.tube([(0.0, by), (mz, by)], br, m, shine=0.45)
    rc = [(-10.0, -4.5), (1.5, -4.5), (1.5, 0.6), (-10.0, 1.0)] if lv < 4 else [(-11.0, -5.0), (2.5, -5.0), (3.5, -3.0), (2.5, 1.0), (-11.0, 1.4)]
    c.plate(rc, m, bevel=1.3, shine=0.3)
    if lv == 1:
        for a in (4.0, 9.5):
            ring(c, a, by + 0.5, 1.9, "copper", 1.0)
        c.tube([(-7.5, -4.6), (-8.6, -6.6), (-7.2, -7.4)], (0.8, 0.5), "iron")
    if lv >= 2:
        c.tube([(-2.6, -2.4), (-1.6, 1.8)], 0.5, t["dark"], shine=0.4)
        c.sphere((-1.4, 2.2), 0.9, t["dark"], shine=0.5)
        sr = LV(lv, 1.0, 1.4)
        for a in (-5.5, -0.5):
            c.tube([(a, -5.0), (a, -6.0)], 0.6, t["dark"])
        c.tube([(-8.0, -7.0), (3.0, -7.0)], sr, t["dark"], shine=0.45)
        ring(c, 1.6, -7.0, sr + 0.5, tr, 1.8)
        ring(c, -8.6, -7.0, sr + 0.4, tr, 1.6)
        gem_at(c, 3.8, -7.0, sr * 0.75, lv)
    if lv == 3:
        for a in (5.0, 11.0, 17.0):
            ring(c, a, by, br + 0.6, tr, 1.0)
    if lv == 4:
        c.plate([(mz - 3.5, by - 2.4), (mz, by - 2.4), (mz, by + 2.4), (mz - 3.5, by + 2.4)], tr, bevel=1.0, shine=0.3)
        for a in (-8.0, -5.0, -2.0):
            vein(c, [(a, -3.6), (a + 1.0, -0.4)], lv, r=0.45)
    if lv >= 4:
        facet(c, spike((-1.0, 1.0), (5.0, 4.0), 0.9), tr)
    if lv == 5:
        for sg in (-1, 1):
            yb = by + sg * 2.6
            c.plate([(4.0, yb), (7.0, yb + sg * 2.4), (12.0, yb + sg * 2.8), (10.0, yb + sg * 1.0), (15.0, yb + sg * 0.4), (13.0, yb)], tr, bevel=1.1, shine=0.35)
        gem_at(c, -4.5, -1.8, 1.4, lv)
    fx(c, lv, [(mz - 6.0, by - 0.6), (mz - 1.0, by - 4.5), (-14.0, -8.0), (mz - 0.5, by + 4.0), (mz - 9.0, by - 5.5)])


# ---------------------------------------------------------------- TÜFTÜF (çapraz üfleme borusu)
def w_tuftuf(c, lv):
    t = T[lv]
    tr = t["trim"]
    a0, a1 = LV(lv, -25, -29), LV(lv, 21, 26.0)
    r = LV(lv, 1.3, 1.75)
    mat = ["", "bamboo", "wood", "ebony", "bone", "hell"][lv]

    def tex(idx, a, b, x, y, s, v):
        if lv == 1:
            ph = (a + 40) % 7.0
            if ph < 0.75:
                return idx - 2
            if ph < 1.5:
                return idx + 1
        elif lv == 4 and (a + 40) % 4.0 < 0.8:
            return idx - 2
        elif lv in (2, 3):
            return E.grain(idx, a, b, x, y, s, v)
        return idx

    c.tube([(a0 + 2, 0), (a1 - 2, 0)], r, mat, tex=tex, shine=0.3)
    c.tube([(a0, 0), (a0 + 2.6, 0)], (r * 0.8, r * 1.1), tr if lv >= 2 else "copper", shine=0.4)
    if lv < 5:
        c.tube([(a1 - 2.6, 0), (a1, 0)], (r * 1.15, r * 1.3), tr if lv >= 2 else "copper", shine=0.4)
    thr = {1: ["ruby", "emerald", "sapphire"], 2: ["emerald"], 3: ["sapphire", "gold"], 4: [], 5: []}[lv]
    for i, tm in enumerate(thr):
        a = a0 + 6.0 + i * 1.6
        c.tube([(a, 0), (a + 1.1, 0)], r + 0.3, tm, shine=0.4)
    if lv >= 2:
        for a in ([-6.0] if lv == 2 else [-8.0, 6.0]):
            c.tube([(a, 0), (a + 1.3, 0)], r + 0.4, tr, shine=0.45)
    if lv >= 3:
        hb = -8.0 + 0.6
        cord = [(hb, r + 0.3), (hb - 1.0, r + 2.6), (hb - 2.0, r + 4.6)]
        c.tube(cord, 0.45, "leather", shine=0.2, sep=False)
        fm = {3: "sapphire", 4: "arc", 5: "fire"}[lv]
        fpoly = [(hb - 1.8, r + 4.0), (hb - 5.0, r + 6.6), (hb - 8.4, r + 7.8), (hb - 5.6, r + 5.4), (hb - 2.6, r + 4.2)]
        c.plate(fpoly, fm, bevel=1.0, shine=0.3, emis=lv >= 4)
    if lv >= 4:
        for a in (-18.0, -2.0, 12.0):
            vein(c, [(a, -r + 0.3), (a + 0.4, r - 0.3)], lv, r=0.45)
    if lv == 4:
        for a in (-12.0, 0.0):
            facet(c, spike((a, -r + 0.2), (a - 2.6, -r - 2.6), 0.85), "bone")
    if lv == 5:
        jaw_u = [(a1 - 6.5, -r - 0.2), (a1 - 3.0, -r - 1.8), (a1 + 0.8, -r - 1.0), (a1 + 1.5, -0.5), (a1 - 1.0, -0.3), (a1 - 6.5, -0.2)]
        jaw_l = [(a1 - 6.5, r + 0.2), (a1 - 3.0, r + 1.5), (a1 + 0.3, r + 0.8), (a1 + 0.8, 0.6), (a1 - 1.0, 0.4), (a1 - 6.5, 0.2)]
        c.sphere((a1 + 0.2, 0), 1.0, "fire", glow=True)
        c.plate(jaw_l, tr, bevel=1.2, shine=0.35)
        c.plate(jaw_u, tr, bevel=1.2, shine=0.35)
        facet(c, spike((a1 - 5.0, -r - 1.0), (a1 - 9.5, -r - 4.2), 0.9), tr)
        gem_at(c, a1 - 3.2, -r - 0.4, 0.75, lv)
        for a, b in ((a1 + 2.6, -1.4), (a1 + 3.4, 0.8)):
            c.dot(a, b, "fire", 5)
    fx(c, lv, [(a1 - 5.0, -r - 0.2), (a1 - 4.0, -r - 4.5), (a0 + 7.0, r + 4.0), (a1 - 1.0, r + 3.0)])


# ---------------------------------------------------------------- YAY (dikey, kiriş solda, ok sağa)
def w_yay(c, lv):
    t = T[lv]
    tr = t["trim"]
    H = LV(lv, 18.0, 20.3)
    bg = LV(lv, 4.5, 6.0)
    bt = -LV(lv, 4.5, 6.0)
    mat = ["", "wood", "wood", "ebony", "demon", "hell"][lv]

    def limb(sg):
        pts = []
        for i in range(9):
            s = i / 8.0
            pts.append((sg * s * H, bt + (bg - bt) * math.cos(s * math.pi / 2) ** 0.85))
        if lv >= 2:
            pts[-1] = (sg * H * 0.97, bt + 0.3)
            pts.append((sg * min(H + 0.8, 21.0), bt + LV(lv, 1.3, 2.4)))
        return pts

    up, dn = limb(1), limb(-1)
    sa = up[-2][0] if lv >= 2 else up[-1][0]
    if lv >= 4:
        c.tube([(sa - 0.4, bt + 0.6), (-sa + 0.4, bt + 0.6)], 0.42, t["glow"], glow=(6, 5, 4), sep=False, outline=False)
    else:
        c.tube([(sa - 0.4, bt + 0.6), (-sa + 0.4, bt + 0.6)], 0.42, "ash" if lv < 3 else "silver", shine=0.2, sep=False)
    if lv >= 4:
        for sg in (-1, 1):
            for s, ln in ((0.38, 3.2), (0.68, 2.6)):
                a = sg * s * H
                b = bt + (bg - bt) * math.cos(s * math.pi / 2) ** 0.85
                facet(c, spike((a, b + 0.6), (a + sg * 1.6, b + ln * LV(lv, 1.0, 1.25)), 0.85), tr if lv == 5 else "bone")
    if lv == 5:
        for sg in (-1, 1):
            c.plate([(sg * 3.5, bg + 0.6), (sg * 7.5, bg + 3.0), (sg * 12.0, bg + 2.6), (sg * 9.5, bg + 1.2), (sg * 14.0, bg - 0.4),
                     (sg * 9.0, bg - 0.6)], tr, bevel=1.1, shine=0.35)
    rr = (LV(lv, 1.5, 1.9), LV(lv, 0.65, 0.8))
    for pts in (up, dn):
        c.tube(pts, rr, mat, tex=E.grain if lv <= 3 else None, shine=0.3)
    if lv >= 4:
        for sg in (-1, 1):
            vein(c, [(sg * 4.0, bg - 0.4), (sg * 8.0, bg - 1.6), (sg * 12.0, bg - 3.8)], lv, r=0.42)
    if lv >= 2:
        for pts in (up, dn):
            c.sphere(pts[-1], LV(lv, 0.9, 1.3), tr, shine=0.5)
    if lv >= 3:
        for sg in (-1, 1):
            c.tube([(sg * 3.2, bg - 0.2), (sg * 4.4, bg - 0.3)], 2.0, tr, shine=0.45)
    c.tube([(-3.0, bg - 0.2), (3.0, bg - 0.2)], LV(lv, 1.9, 2.25), t["grip"], tex=E.wrap, shine=0.1)
    if lv >= 2:
        gem_at(c, 0.0, bg + 0.9, LV(lv, 0.9, 1.4), lv)
    fx(c, lv, [(H * 0.55, bg - 1.8), (H * 0.8, bg + 3.0), (-H * 0.55, bg + 4.0), (-H * 0.85, bt - 1.6), (H * 0.2, bt - 2.0)])


# ---------------------------------------------------------------- ARBALET (çapraz, uç sağ-üstte)
def w_crossbow(c, lv):
    t = T[lv]
    tr, wd = t["trim"], t["wood"]
    pe = LV(lv, -25.5, -28.0)
    pa = LV(lv, 11.0, 12.5)
    H = LV(lv, 9.0, 12.5)
    nut = LV(lv, -2.0, -4.0)
    pm = ["", "wood", "steel", "cobalt", "demon", "hell"][lv]
    c.plate([(pe, -2.2), (pe + 8.0, -1.6), (pe + 8.0, 2.0), (pe, 2.9)], wd, bevel=1.4, shine=0.15, tex=pgrain)
    if lv >= 2:
        c.tube([(pe + 0.2, -2.2), (pe + 0.2, 3.2)], 0.75, tr, shine=0.4)
    c.tube([(pe + 7.0, 0), (pa + 2.5, 0)], LV(lv, 1.55, 1.8), wd, tex=E.grain if lv <= 3 else None, shine=0.25)
    c.tube([(-11.0, 1.6), (-12.6, 4.4)], 0.5, t["dark"], shine=0.3)
    if lv >= 3:
        gem_at(c, pe + 4.0, 0.3, LV(lv, 1.0, 1.4), lv)
        for a in (-8.0, 3.0):
            c.tube([(a, 0), (a + 1.2, 0)], 1.95, tr, shine=0.45)
    if lv >= 4:
        vein(c, [(-20.0, 0.0), (-17.0, 0.0)], lv, r=0.45)

    def prod(off, hh, rr):
        side = []
        for i in range(7):
            b = hh * i / 6.0
            side.append((pa + off - (b / hh) ** 2 * LV(lv, 3.6, 5.0), b))
        if lv >= 2:
            side.append((side[-1][0] - 1.2, hh + 0.9))
        return side

    tips = []
    prods = [(0.0, H)] if lv < 5 else [(-2.6, H * 0.82), (0.0, H)]
    for off, hh in prods:
        side = prod(off, hh, None)
        tips.append(side[-1] if lv < 2 else side[-2])
    st = t["glow"] if lv >= 4 else ("ash" if lv < 3 else "silver")
    for (ta, tb) in tips[-1:]:
        pts = [(ta - 0.4, -tb + 0.4), (nut, 0), (ta - 0.4, tb - 0.4)]
        if lv >= 4:
            c.tube(pts, 0.42, st, glow=(6, 5, 4), sep=False, outline=False)
        else:
            c.tube(pts, 0.42, st, shine=0.2, sep=False)
    bm = "wood" if lv <= 2 else t["metal"]
    c.tube([(nut + 0.5, 0), (pa + 4.0, 0)], 0.55, bm, shine=0.35)
    for sg in (-1, 1):
        c.plate([(nut + 0.6, sg * 0.4), (nut + 3.6, sg * 0.5), (nut + 1.8, sg * 2.0), (nut - 0.2, sg * 2.0)],
                {1: "paper", 2: "ruby", 3: "sapphire", 4: "arc", 5: "fire"}[lv], bevel=0.8)
    c.gem(spike((pa + 3.2, 0), (pa + LV(lv, 6.6, 8.6), 0), LV(lv, 1.0, 1.35)), t["metal"] if lv >= 2 else "iron", emis=lv >= 4)
    for off, hh in prods:
        up = prod(off, hh, None)
        for sg in (-1, 1):
            c.tube([(a, sg * b) for a, b in up], (LV(lv, 1.35, 1.6), 0.6), pm, tex=E.grain if lv == 1 else None, shine=0.4)
    if lv >= 4:
        for sg in (-1, 1):
            a, b = prod(0.0, H, None)[4]
            facet(c, spike((a, sg * b), (a + 3.4, sg * (b + 1.6)), 0.85), tr)
    c.sphere((pa + 0.2, 0), LV(lv, 1.6, 2.2), tr, shine=0.45)
    if lv >= 2:
        gem_at(c, pa + 0.2, 0, LV(lv, 0.7, 1.1), lv)
        c.tube([(pa + 1.2, -1.9), (pa + 3.6, -1.9), (pa + 3.6, 1.9), (pa + 1.2, 1.9)], 0.45, tr, shine=0.4)
    fx(c, lv, [(pa - 6.0, -H * 0.75), (pa + 6.0, -4.0), (pa - 3.0, H + 2.5), (pa + 7.5, 3.2), (-6.0, -4.5)])


# ---------------------------------------------------------------- BUMERANG (yatay V, tepe yukarıda)
def w_boomerang(c, lv):
    t = T[lv]
    tr = t["trim"]
    S = LV(lv, 0.82, 1.0)
    mat = ["", "wood", "wood", "cobalt", "demon", "hell"][lv]
    w = LV(lv, 2.4, 3.1)
    pts = [(-19 * S, 6.5 * S), (-9 * S, -2.0 * S), (0, -8.5 * S), (9 * S, -2.0 * S), (19 * S, 6.5 * S)]
    if lv >= 4:
        for sg in (-1, 1):
            for s in (0.3, 0.62):
                a = sg * 19 * S * s
                b = -8.5 * S + (6.5 + 8.5) * S * s
                nrm = (-0.62 * sg, -0.78)
                facet(c, spike((a + nrm[0] * (w - 0.6), b + nrm[1] * (w - 0.6)), (a + nrm[0] * (w + 2.6) + sg * 1.4, b + nrm[1] * (w + 2.6)), 0.9), tr)

    def btex(idx, a, b, x, y, d):
        if lv == 1 and d > 0.9 and (13.0 * S < abs(a) < 14.4 * S or 10.4 * S < abs(a) < 11.4 * S):
            return P["ruby"][max(1, min(6, idx))]
        if lv >= 4 and d < 0.8 and b > -8.0 * S + abs(a) * 0.78 + 0.3:
            return P[t["glow"]][5]
        return idx

    c.plate(ribbon(pts, w * 0.82, w * 0.82, miter=2.2), mat, bevel=1.6, shine=0.3, tex=btex)
    if lv == 5:
        c.halo("redglow")
    if lv >= 2:
        for sg in (-1, 1):
            a, b = pts[0] if sg < 0 else pts[-1]
            c.sphere((a - sg * 0.6, b - 0.4), w * 0.75, t["metal"] if lv == 2 else tr, shine=0.45)
    if lv >= 3:
        c.sphere((0, -8.5 * S + 1.4), LV(lv, 2.1, 2.8), tr, shine=0.45)
        gem_at(c, 0, -8.5 * S + 1.4, LV(lv, 1.1, 1.5), lv)
    elif lv == 2:
        gem_at(c, 0, -8.5 * S + 1.4, 1.0, lv)
    if lv >= 4:
        for sg in (-1, 1):
            vein(c, [(sg * 4.0, -5.0 * S), (sg * 8.0, -2.0 * S), (sg * 12.0, 1.2 * S)], lv, r=0.42)
    fx(c, lv, [(-9 * S, -2.6 * S), (12.0, -9.0), (-4.0, 9.0), (6.0, 6.0), (-15.0, -4.0)])


# ---------------------------------------------------------------- FİŞEK (çapraz roket, burun sağ-üstte)
def w_fisek(c, lv):
    t = T[lv]
    tr = t["trim"]
    r = LV(lv, 2.4, 3.3)
    b0, b1 = LV(lv, -4.0, -9.0), LV(lv, 10.0, 14.0)
    nose = LV(lv, 17.5, 24.0)
    body = ["", "paper", "paper", "cobalt", "demon", "hell"][lv]
    stripe = {1: "ruby", 2: "emerald", 3: "gold", 4: "silver", 5: "gold"}[lv]
    if lv >= 4:
        ln, base = LV(lv, 7.0, 10.0), b0 - 1.8
        fo = [(base - u * ln, v * r * 1.05) for u, v in (F3 if lv == 4 else F5)]
        c.layers([fo, scale_poly(fo, base - ln * 0.15, 0, 0.72), scale_poly(fo, base - ln * 0.1, 0, 0.46), scale_poly(fo, base, 0, 0.22)],
                 "arc" if lv == 4 else "fire", (3, 4, 5, 6))
    if lv <= 2:
        c.tube([(b0 + 3.0, r + 0.9), (-26.5, r + 0.9)], 0.6, "wood", shine=0.3)
        c.tube([(b0 - 0.2, 0), (b0 - 1.6, 0.8), (b0 - 2.4, -0.2), (b0 - 3.4, 0.4)], 0.42, "paper", sep=False)
        c.star(b0 - 3.8, 0.4, "fire", 1)
    if lv >= 3:
        fl = LV(lv, 3.2, 5.0)
        for sg in (-1, 1):
            c.plate([(b0 + 4.5, sg * r * 0.6), (b0 + 0.2, sg * (r + fl)), (b0 - 2.6, sg * (r + fl + 0.6)), (b0 - 0.6, sg * r * 0.4)],
                    tr, bevel=1.2, shine=0.35)
        c.tube([(b0 - 2.0, 0), (b0 + 0.2, 0)], (r * 0.65, r * 0.85), t["dark"], shine=0.4)

    def stex(idx, a, b, x, y, s, v):
        ph = (a - b0) / max(1.0, b1 - b0)
        if lv == 1 and (0.15 < ph < 0.27 or 0.55 < ph < 0.67):
            return P["ruby"][max(1, min(6, idx))]
        if lv == 2 and 0.62 < ph < 0.76:
            return P["emerald"][max(1, min(6, idx))]
        return idx

    c.tube([(b0, 0), (b1, 0)], r, body, tex=stex, shine=0.3)
    if lv >= 3:
        for a in (b0 + 1.2, b1 - 1.6):
            c.tube([(a, 0), (a + 0.9, 0)], r + 0.35, stripe, shine=0.45)
    if lv >= 4:
        for a in (b0 + 4.0, b0 + 7.5, b0 + 11.0):
            vein(c, [(a, -r + 0.6), (a + 0.8, 0), (a, r - 0.6)], lv, r=0.42)
    nm = {1: "ruby", 2: "steel", 3: "gold", 4: "silver", 5: "gold"}[lv]
    c.gem(spike((b1 - 0.4, 0), (nose, 0), r * 1.02, shoulder=0.04, wb=r * 1.02), nm, emis=False)
    if lv >= 2:
        gem_at(c, (b0 + b1) / 2 + 1.0, -0.4, LV(lv, 1.1, 1.6), lv)
    fx(c, lv, [(nose - 3.0, -r * 0.4), (nose + 0.5, -r - 3.0), (b0 - 6.0, -r - 4.0), (b0 - 10.0, r + 1.0), (b0 - 4.0, r + 4.5)])


# ---------------------------------------------------------------- liste + çıktı
WEAPONS = [
    ("dagger", "Bıçak", "diag", w_dagger),
    ("uzunkilic", "Uzunkılıç", "diag", w_uzunkilic),
    ("topuz", "Topuz", "diag", w_topuz),
    ("pence", "Pençe", "diag", w_pence),
    ("fire_staff", "Ateş Asası", "diag", w_fire_staff),
    ("lightning_staff", "Yıldırım Asası", "diag", w_lightning_staff),
    ("arcane", "Arcane Asası", "diag", w_arcane),
    ("buz_asasi", "Buz Asası", "diag", w_buz_asasi),
    ("tabanca", "Tabanca", "horiz", w_tabanca),
    ("tufek", "Tüfek", "horiz", w_tufek),
    ("tuftuf", "Tüftüf", "diag", w_tuftuf),
    ("yay", "Yay", "vert", w_yay),
    ("crossbow", "Arbalet", "diag", w_crossbow),
    ("boomerang", "Bumerang", "horiz", w_boomerang),
    ("fisek", "Fişek", "diag", w_fisek),
]


def build(keys=None):
    os.makedirs(OUT, exist_ok=True)
    gd = os.path.join(OUT, ".gdignore")
    if not os.path.exists(gd):
        open(gd, "w").close()
    out = {}
    for key, _, fr, fn in WEAPONS:
        if keys and key not in keys:
            continue
        frame(fr)
        for lv in range(1, 6):
            cv = Cv(lv)
            fn(cv, lv)
            img = cv.render()
            img.save(os.path.join(OUT, "%s_L%d.png" % (key, lv)))
            bb = img.getbbox()
            edge = bb[0] == 0 or bb[1] == 0 or bb[2] == N or bb[3] == N
            if edge:
                print("KENAR!", key, lv, bb)
            out[(key, lv)] = img
    return out


BG = (62, 82, 56)


def sheet(imgs, rows, path, z=4):
    cell = N * z
    lw, gap, top = 150, 14, 40
    W = lw + 5 * (cell + gap) + gap + (50 if z < 4 else 0)
    H = top + len(rows) * (cell + gap) + gap
    im = Image.new("RGBA", (W, H), (34, 38, 40, 255))
    d = ImageDraw.Draw(im)
    for lv in range(1, 6):
        x0 = lw + gap + (lv - 1) * (cell + gap)
        d.text((x0, 10), "%d - %s" % (lv, T[lv]["name"]), fill=(235, 230, 215), font=font(20, True))
    for ri, (key, label) in enumerate(rows):
        y0 = top + ri * (cell + gap)
        d.text((12, y0 + cell // 2 - 10), label, fill=(235, 230, 215), font=font(18, True))
        for lv in range(1, 6):
            x0 = lw + gap + (lv - 1) * (cell + gap)
            d.rectangle([x0, y0, x0 + cell - 1, y0 + cell - 1], fill=BG)
            im.alpha_composite(imgs[(key, lv)].resize((cell, cell), Image.NEAREST), (x0, y0))
    im.convert("RGB").save(path)


def context(imgs):
    """Oyun ölçeği (kamera zoom 2): asa notundaki ölçek, 48 tuval = 28/46 dünya px/piksel; tuvale göre ölçeklenir, böylece
    düşük seviye silah oyunda da küçük görünür. Solda büyücü (karakter pikseli 0,903 dünya px) boy kıyası için."""
    zoom, wpp = 2.0, 28.0 / 46.0
    char_world_px = 2.2368375 * 0.8075 * 0.5
    wiz = Image.open(os.path.join(E.GAME, "assets/characters/buyucu/sheets/idle.png")).convert("RGBA").crop((0, 0, 48, 48))
    cw, ch, lw, top = 64, 74, 120, 30
    W = lw + 90 + len(WEAPONS) * cw + 10
    H = top + 5 * (ch + 8)
    im = Image.new("RGB", (W, H), (34, 38, 40))
    d = ImageDraw.Draw(im)
    d.text((10, 6), "Oyun ölçeği (zoom 2, NEAREST) - her satır bir seviye", fill=(235, 230, 215), font=font(15, True))
    for lv in range(1, 6):
        y0 = top + (lv - 1) * (ch + 8)
        d.text((10, y0 + ch // 2 - 9), "%d - %s" % (lv, T[lv]["name"]), fill=(235, 230, 215), font=font(15, True))
        pc = Image.new("RGB", (90 + len(WEAPONS) * cw, ch), BG)
        E.blit_world(pc, wiz, 45, ch / 2, char_world_px, zoom)
        for i, (key, _, _, _) in enumerate(WEAPONS):
            E.blit_world(pc, imgs[(key, lv)], 90 + i * cw + cw / 2, ch / 2, wpp, zoom)
        im.paste(pc, (lw, y0))
    im.save(os.path.join(HERE, "silah48_oyun_olcegi.png"))


if __name__ == "__main__":
    only = sys.argv[1:] or None
    imgs = build(only)
    rows = [(k, n) for k, n, _, _ in WEAPONS if (k, 1) in imgs]
    if only:
        sheet(imgs, rows, os.path.join(HERE, "silah48_deneme.png"))
    else:
        for i in range(3):
            sheet(imgs, rows[i * 5:(i + 1) * 5], os.path.join(HERE, "silah48_sayfa_%d.png" % (i + 1)))
        sheet(imgs, rows, os.path.join(HERE, "silah48_ozet.png"), z=2)
        context(imgs)
    print("ok", len(imgs))
