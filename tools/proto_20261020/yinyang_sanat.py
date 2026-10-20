# -*- coding: utf-8 -*-
"""YİN YANG KİTABI (silah) sanatı PROTOTİPLERİ (2026-10-20, oyuna bağlı DEĞİL). Kullanıcı: "4 tane yin ve yang kitabı için 4 prototip
hazırla" (yeni silah: tek hedef %100 saldırı gücü + isabet başına %10 saldırı gücü kalkan, kalkan menzilsiz; özellik "Denge").

Zanaatkâr seti (madde 196) altyapısıyla (silah_zanaat_proto.py: TA seviye merdiveni, Cv tuvali), 48x48, ÖNDEN bakış (frame "horiz":
a = sağa, b = aşağı, ışık sol-üst). Kitap kalınlığı sağ-alta düşer (sayfa kenarı çizgileri görünür). 4 silüet:
  A Mühürlü Cilt  - kalın kapalı cilt, kapakta kubbeli yin-yang mührü (çerçeveli), köşe demirleri, kopça
  B Açık Sayfalar - açık kitap: sol sayfa mürekkep (yin), sağ sayfa fildişi (yang), S kıvrımı cilt yerinden geçer
  C Doğu Risalesi - ince iple dikili cilt, sol kenarda dikiş, etiket şeridi, boyalı yin-yang, aşağı sarkan püskül
  D Yuvarlak Cilt - daire biçimli kitap: kapağın kendisi yin-yang, kenarda sayfa yayı, solda menteşe, sağda kopça
Seviye merdiveni (TA): 1 Paslı / 2 Demir / 3 Çelik + pirinç / 4 Kara Çelik + gümüş + kırmızı / 5 Yadigâr çelik + altın + lal.

Çıktılar (out/yinyang/): sanat/yinyang_<A..D>_L<n>.png (48x48), yinyang_sanat_sayfa.png (x4), yinyang_sanat_oyun.png (oyun ölçeği:
1 sanat px = 0,575 dünya px, zoom 2, Talon + Uzunkılıç L3 + Mızrak L3 boy kıyası, resim x2).
Çalıştırma: python tools/proto_20261020/yinyang_sanat.py
"""
import math
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
P16 = os.path.normpath(os.path.join(HERE, "..", "proto_20261016"))
sys.path.insert(0, P16)
import silah_zanaat_proto as Z  # noqa: E402
import silah_proto48 as S  # noqa: E402
from silah_proto48 import Cv, frame, LV, E, P, hx, circle_pts, font, N  # noqa: E402

TA = Z.TA
hsh = S.hsh
OUT = os.path.join(HERE, "out", "yinyang")
ART = os.path.join(OUT, "sanat")

for _k, _v in {
    "Y_yin": "#08070c #14121a #1e1b26 #292533 #353040 #443e52 #6a6280",    # mürekkep (yin)
    "Y_yang": "#2a261e #5e5646 #8e846e #b8ad94 #d6ccb4 #ebe3cf #fffaee",   # fildişi (yang)
    "Y_wine": "#16070a #300f16 #451620 #5a1e2a #702836 #873646 #a85a68",   # Yadigâr deri
}.items():
    P[_k] = [hx(c) for c in _v.split()]


# ---------------------------------------------------------------- ortak parçalar
def rect(a0, b0, a1, b1):
    return [(a0, b0), (a1, b0), (a1, b1), (a0, b1)]


def rrect(a0, b0, a1, b1, r, n=3):
    pts = []
    for ca, cb, t0 in ((a1 - r, b0 + r, -90), (a1 - r, b1 - r, 0), (a0 + r, b1 - r, 90), (a0 + r, b0 + r, 180)):
        for i in range(n + 1):
            t = math.radians(t0 + 90 * i / n)
            pts.append((ca + r * math.cos(t), cb + r * math.sin(t)))
    return pts


def snap_pt(p):
    """Piksel köşesine oturt (frame horiz: x = 24 + a, y = 24.5 + b) -> noktalar 2x2 / 4x4 temiz kare çıkar, "+" olmaz."""
    return (float(round(p[0])), round(p[1] - 0.5) + 0.5)


class YY:
    """Yin-yang geometrisi: sağ yarı + üst baş = yang (fildişi), sol yarı + alt baş = yin; yang başında yin noktası, yin başında yang
    noktası. rot = saat yönünde dönüş (radyan). rot 0'da merkez ve R tamsayıya oturtulur: iki nokta da piksel köşesine düşer."""

    def __init__(self, ca, cb, R, rot=0.0):
        if rot == 0.0:
            R = float(int(R + 0.5))
            ca = float(round(ca))
            cb = round(cb - 0.5 - R / 2.0) + 0.5 + R / 2.0
        self.ca, self.cb, self.R, self.rot = ca, cb, R, rot
        h = R / 2.0
        s, c = math.sin(rot), math.cos(rot)
        self.top = (ca + h * s, cb - h * c)
        self.bot = (ca - h * s, cb + h * c)
        self.dtop, self.dbot = snap_pt(self.top), snap_pt(self.bot)
        self.dr = 1.2 if R <= 8.5 else 1.75

    def side(self, a, b):
        if math.hypot(a - self.dtop[0], b - self.dtop[1]) < self.dr:
            return "yin"
        if math.hypot(a - self.dbot[0], b - self.dbot[1]) < self.dr:
            return "yang"
        h = self.R / 2.0
        if math.hypot(a - self.top[0], b - self.top[1]) < h:
            return "yang"
        if math.hypot(a - self.bot[0], b - self.bot[1]) < h:
            return "yin"
        xr = (a - self.ca) * math.cos(self.rot) + (b - self.cb) * math.sin(self.rot)
        return "yang" if xr > 0 else "yin"

    def inside(self, a, b):
        return math.hypot(a - self.ca, b - self.cb) <= self.R


def yy_tex(g, dark="Y_yin", light="Y_yang"):
    """Düz levha üstünde yin-yang: kenar bevel'i + hafif 3 tonlu dışbükeylik, yang tarafı bir ton açık."""
    def f(idx, a, b, x, y, d, *rest):
        side = g.side(a, b)
        if d < 1.0:
            i = idx
        else:
            k = ((a - g.ca) + (b - g.cb)) / max(g.R, 1.0)
            i = 4 if k < -0.7 else (3 if k < 0.6 else 2)
        if side == "yang":
            i += 1
        return P[light if side == "yang" else dark][max(1, min(6, i))]
    return f


def yy_disc(c, ca, cb, R, dark="Y_yin", light="Y_yang", rot=0.0, bevel=1.1):
    g = YY(ca, cb, R, rot)
    c.plate(circle_pts(g.ca, g.cb, g.R, n=40)[:-1], dark, bevel=bevel, shine=0.2, tex=yy_tex(g, dark, light))
    c.parts[-1]["keep"] = True  # noktalar (2x2 px) temizlikte silinmesin
    return g


def leather_tex(R, ca=0.0, cb=0.0, worn=False):
    def f(idx, a, b, x, y, d, *rest):
        if d < 1.0:
            return idx
        k = ((a - ca) + (b - cb)) / max(R, 1.0)
        base = 4 if k < -0.75 else (3 if k < 0.55 else 2)
        if worn and hsh(x // 2, y // 2, 13) < 0.22:
            base += 1
        return base
    return f


def pages_tex(a_edge=None, b_edge=None):
    """Sayfa kenarı: sağ kenarda dikey, alt kenarda yatay ince çizgiler."""
    def f(idx, a, b, x, y, d, *rest):
        if a_edge is not None and a > a_edge:
            return 5 if x % 2 == 0 else 3
        if b_edge is not None and b > b_edge:
            return 5 if y % 2 == 0 else 3
        return 4
    return f


def corner(c, a, b, sa, sb, k, mat):
    """Köşe demiri: (a, b) köşesinde, kapağın içine doğru (sa, sb) yönlü üçgen."""
    c.plate([(a + sa * 0.3, b + sb * 0.3), (a - sa * k, b + sb * 0.3), (a + sa * 0.3, b - sb * k)], mat, bevel=0.9, shine=0.45)


def ribbon_mark(c, a, b0, b1, mat="A_cloth", w=1.0):
    """Kırmızı ayraç şeridi, ucu çatallı."""
    c.plate([(a - w, b0), (a + w, b0), (a + w, b1), (a, b1 - 1.0), (a - w, b1)], mat, bevel=0.6, shine=0.25)


def glint5(c, lv, a, b, mat="A_gold"):
    if lv == 5:
        c.glint(a, b, mat, 6)


COVER = {1: "A_leather", 2: "A_leather", 3: "A_leather", 4: "A_black", 5: "Y_wine"}


# ---------------------------------------------------------------- A Mühürlü Cilt
def A_book(c, lv):
    t = TA[lv]
    W, H = LV(lv, 9.5, 12.0), LV(lv, 12.0, 15.0)
    th = LV(lv, 2.0, 2.8)
    a0, a1, b0, b1 = -W - 1.0, W - 1.0, -H - 1.0, H - 1.0
    cov = COVER[lv]
    c.plate(rrect(a0 + th, b0 + th, a1 + th, b1 + th, 1.2), cov, bevel=0.8, shine=0.1, tex=lambda i, *r: 1 if i < 3 else 2)
    c.plate(rect(a0 + 1.4, b0 + 1.4, a1 + th - 0.7, b1 + th - 0.7), "paper", bevel=0.5, shine=0.1, tex=pages_tex(a1 - 0.2, b1 - 0.2))
    c.plate(rrect(a0, b0, a1, b1, 1.4), cov, bevel=1.3, shine=0.2, tex=leather_tex(H, worn=lv == 1))
    ## sırt oluğu
    c.tube([(a0 + 2.6, b0 + 1.2), (a0 + 2.6, b1 - 1.2)], 0.5, cov, shine=0.0, tex=lambda i, *r: 1, sep=False, outline=False)
    ma, mb = (a0 + 2.6 + a1) * 0.5 + 0.4, (b0 + b1) * 0.5 - 0.5
    R = LV(lv, 5.5, 7.5)
    g = yy_disc(c, ma, mb, R)
    ring = {1: "A_iron", 2: "A_iron", 3: t["tr"], 4: "A_silver", 5: "A_gold"}[lv]
    c.tube(circle_pts(g.ca, g.cb, g.R + 0.8, n=32), LV(lv, 0.7, 1.0), ring, shine=0.5, tex=Z.rust_tex(lv))
    ma, mb = g.ca, g.cb
    if lv == 1:
        ## paslı halka, tek iple bağlı
        c.tube([(a0 - 0.4, b1 - 2.6), (a1 + 0.4, b1 - 2.6)], 0.6, "A_rope", tex=E.wrap, shine=0.1, sep=True)
        return
    cm = {2: "A_iron", 3: t["tr"], 4: "A_silver", 5: "A_gold"}[lv]
    k = LV(lv, 3.0, 4.0)
    corner(c, a1, b0, -1, 1, k, cm)
    corner(c, a1, b1, -1, -1, k, cm)
    if lv >= 3:
        corner(c, a0, b0, 1, 1, k, cm)
        corner(c, a0, b1, 1, -1, k, cm)
        ## kopça: kapağın sağ kenarından sayfaların üstüne
        cb_ = mb
        c.plate(rect(a1 - 2.2, cb_ - 1.6, a1 + th + 0.6, cb_ + 1.6), "A_leather" if lv != 4 else "A_cloth", bevel=0.7, shine=0.2)
        c.plate(rect(a1 - 1.6, cb_ - 1.0, a1 + 0.4, cb_ + 1.0), cm, bevel=0.6, shine=0.5)
    if lv == 4:
        ribbon_mark(c, a0 + 5.0, b1 + th - 1.0, b1 + th + 4.5)
    if lv == 5:
        c.sphere((ma, mb - g.R - 1.6), 1.0, "A_garnet", shine=0.7)
        glint5(c, lv, a0 + 2.2, b0 + 2.0)


# ---------------------------------------------------------------- B Açık Sayfalar
def spread_pts(W, top, bot, dip, sag, side, n=8):
    """Açık kitabın bir yaprağı (side -1 sol, +1 sağ): cilt üstü -> dış üst -> dış alt -> cilt altı."""
    pts = []
    for i in range(n + 1):
        u = i / float(n)
        a = 2 * (1 - u) * u * (side * W * 0.45) + u * u * (side * W)
        b = (1 - u) ** 2 * (top + dip) + 2 * (1 - u) * u * (top - 0.8) + u * u * top
        pts.append((a, b))
    for i in range(n + 1):
        u = i / float(n)
        a = (1 - u) ** 2 * (side * W) + 2 * (1 - u) * u * (side * W * 0.45)
        b = (1 - u) ** 2 * bot + 2 * (1 - u) * u * (bot - 0.5) + u * u * (bot + sag)
        pts.append((a, b))
    return pts


def B_page_tex(g, side, dark="Y_yin", light="Y_yang"):
    """Sol yaprak mürekkep, sağ yaprak fildişi; dairenin içinde DÖNDÜRÜLMÜŞ yin-yang (noktalar cilt çizgisine düşmesin) + ince halka."""
    def f(idx, a, b, x, y, d, *rest):
        r = math.hypot(a - g.ca, b - g.cb)
        out = "yin" if side < 0 else "yang"
        if r <= g.R:
            s = g.side(a, b)
        else:
            s = out
        if abs(r - g.R - 0.2) < 0.55:  # halka: dışarının tersi renk
            s = "yang" if out == "yin" else "yin"
        aa = abs(a - g.ca)
        i = 2 if aa < 1.6 else (3 if aa < 3.4 else 4)
        if d < 0.9 and aa >= 1.6:
            i = max(i, min(5, idx))
        if s == "yang":
            i += 1
        return P[light if s == "yang" else dark][max(1, min(6, i))]
    return f


def B_book(c, lv):
    t = TA[lv]
    W, H = LV(lv, 11.0, 14.0), LV(lv, 9.5, 12.0)
    dip, sag = 1.6, 1.4
    top, bot = -H - 2.0, H - 2.0
    cov = COVER[lv]
    cp = rrect(-W - 1.4, top + 2.2, W + 1.4, bot + sag + 3.6, 1.2, n=2)
    c.plate(cp, cov, bevel=0.9, shine=0.15, tex=leather_tex(W, worn=lv == 1))
    for sd in (-1, 1):
        c.plate(spread_pts(W - 0.2, top + 2.0, bot + 2.0, dip, sag, sd), "paper", bevel=0.4, shine=0.1, tex=pages_tex(None, -99))
    g = YY(0.0, (top + bot) * 0.5 + 0.8, min(W, H) * 0.86, rot=-0.62)
    for sd in (-1, 1):
        c.plate(spread_pts(W, top, bot, dip, sag, sd), "Y_yin", bevel=1.0, shine=0.15, tex=B_page_tex(g, sd))
        c.parts[-1]["keep"] = True
    if lv == 1:
        ## eski deri cilt, sırtı alttan iple bağlı
        c.tube([(-2.2, bot + sag + 1.4), (2.2, bot + sag + 1.4)], 0.65, "A_rope", tex=E.wrap, shine=0.1)
        return
    cm = {2: "A_iron", 3: t["tr"], 4: "A_silver", 5: "A_gold"}[lv]
    k = LV(lv, 2.8, 3.8)
    yb = bot + sag + 3.6
    corner(c, -W - 1.4, yb, 1, -1, k, cm)
    corner(c, W + 1.4, yb, -1, -1, k, cm)
    if lv == 4:
        c.tube([(0.6, top + dip + 0.6), (0.9, bot + sag + 1.0)], 0.75, "A_cloth", shine=0.25, sep=True)
        ribbon_mark(c, 0.9, bot + sag + 1.0, bot + sag + 7.0, w=0.9)
    if lv in (3, 5):
        c.sphere((0.0, bot + sag + 2.4), LV(lv, 1.3, 1.7), cm, shine=0.5)
    if lv == 5:
        c.sphere((-0.15, bot + sag + 2.25), 0.8, "A_garnet", shine=0.7, sep=False)
        glint5(c, lv, -W + 2.0, top + 1.2)


# ---------------------------------------------------------------- C Doğu Risalesi
C_COVER = {1: "A_paper", 2: "navy", 3: "navy", 4: "A_black", 5: "navy"}
C_THREAD = {1: "A_rope", 2: "A_string", 3: "A_string", 4: "A_cloth", 5: "A_gold"}


def trigram(c, a, b, lines, mat, w=3.0, vertical=False):
    """Sekiz köşe (bagua) işareti: 3 çizgi, kırık çizgi (yin) = 0, düz (yang) = 1."""
    for i, full in enumerate(lines):
        o = (i - 1) * 1.7
        if vertical:
            segs = [(o, -w / 2, o, w / 2)] if full else [(o, -w / 2, o, -0.55), (o, 0.55, o, w / 2)]
        else:
            segs = [(-w / 2, o, w / 2, o)] if full else [(-w / 2, o, -0.55, o), (0.55, o, w / 2, o)]
        for x0, y0, x1, y1 in segs:
            c.tube([(a + x0, b + y0), (a + x1, b + y1)], 0.42, mat, shine=0.4, sep=False, outline=False)


def C_book(c, lv):
    t = TA[lv]
    W, H = LV(lv, 9.0, 11.5), LV(lv, 11.5, 14.0)
    th = 1.3
    oy = -2.5  # püskül için yukarı
    a0, a1, b0, b1 = -W - 0.4, W - 0.4, -H + oy, H + oy
    cov = C_COVER[lv]
    c.plate(rect(a0 + th, b0 + th, a1 + th, b1 + th), "paper", bevel=0.4, shine=0.1, tex=pages_tex(a1 - 0.2, b1 - 0.2))
    c.plate(rect(a0, b0, a1, b1), cov, bevel=1.1, shine=0.15, tex=leather_tex(H, worn=lv == 1))
    thr = C_THREAD[lv]
    sa = a0 + 2.0
    ## dikiş: dikey iplik + kenarı saran kısa sargılar
    c.tube([(sa, b0 + 1.6), (sa, b1 - 1.6)], 0.4, thr, shine=0.3, sep=False, outline=False)
    stitches = [b0 + 1.8 + (b1 - b0 - 3.6) * i / 3.0 for i in range(4)]
    for sb in stitches:
        c.tube([(a0 - 0.6, sb), (sa, sb)], 0.45, thr, shine=0.3, sep=False)
    if lv >= 3:
        cm = {3: t["tr"], 4: "A_silver", 5: "A_gold"}[lv]
        corner(c, a0, b0, 1, 1, 2.6, cm)
        corner(c, a0, b1, 1, -1, 2.6, cm)
    ## etiket şeridi (sol üst): üstünde mürekkep işaretleri
    la0, la1 = a0 + 3.8, a0 + 6.6
    lb0, lb1 = b0 + 1.8, b0 + LV(lv, 9.0, 10.5)
    c.plate(rect(la0, lb0, la1, lb1), "A_paper" if lv != 1 else "Y_yang", bevel=0.5, shine=0.1)
    for i in range(3):
        bb = lb0 + 1.6 + i * 2.2
        if bb < lb1 - 1.0:
            c.dot((la0 + la1) * 0.5, bb, "Y_yin", 2, emis=False)
    ## boyalı yin-yang
    R = LV(lv, 5.6, 7.0)
    ma, mb = (la1 + a1) * 0.5 + 0.6, (b0 + b1) * 0.5 + 1.0
    g = yy_disc(c, ma, mb, R, bevel=0.8)
    ma, mb, R = g.ca, g.cb, g.R
    if lv >= 3:
        c.tube(circle_pts(ma, mb, R + 0.7, n=32), 0.5, {3: t["tr"], 4: "A_silver", 5: "A_gold"}[lv], shine=0.5)
    if lv >= 4:
        tm = "A_silver" if lv == 4 else "A_gold"
        rr = R + 3.0
        trigram(c, ma, mb - rr, (1, 1, 1), tm)
        trigram(c, ma, mb + rr, (0, 0, 0), tm)
    ## püskül: alttaki dikişten sarkar
    if lv >= 2:
        pa = sa
        tm = {2: "A_rope", 3: "A_rope", 4: "A_cloth", 5: "A_cloth"}[lv]
        c.tube([(pa, b1 + 0.2), (pa, b1 + 2.6)], 0.4, thr if lv != 4 else "A_cloth", shine=0.2, sep=False)
        bead = {2: None, 3: t["tr"], 4: "A_silver", 5: "A_gold"}[lv]
        y = b1 + 2.6
        if bead:
            c.sphere((pa, y + 0.9), 1.1, bead, shine=0.55)
            y += 1.8
        L = LV(lv, 4.0, 5.5)

        def strands(idx, a, b, x, y_, d, *rest):
            return 2 if (x % 2 == 0 and d > 0.6) else max(3, min(5, idx))
        c.plate([(pa - 0.9, y), (pa + 0.9, y), (pa + 1.7, y + L), (pa - 1.7, y + L)], tm, bevel=0.6, shine=0.2, tex=strands)
        if lv == 5:
            c.sphere((pa - 0.1, y - 1.0), 0.6, "A_garnet", shine=0.7, sep=False)
    glint5(c, lv, a1 - 2.0, b0 + 1.8)


# ---------------------------------------------------------------- D Yuvarlak Cilt
def rim_tex(ca, cb):
    def f(idx, a, b, x, y, d, *rest):
        r = math.hypot(a - ca, b - cb)
        return 5 if int(r * 1.25) % 2 == 0 else 3
    return f


def D_book(c, lv):
    t = TA[lv]
    R = LV(lv, 10.5, 13.5)
    th = LV(lv, 2.0, 2.8)
    ca, cb = -1.0, -1.2
    dark, light = ("A_dwood", "Y_yang") if lv == 1 else (("Y_yin", "Y_yang") if lv != 4 else ("A_black", "Y_yang"))
    back = {1: "A_dwood", 2: "A_leather", 3: "A_leather", 4: "A_black", 5: "Y_wine"}[lv]
    g = YY(ca, cb, R)
    ca, cb, R = g.ca, g.cb, g.R
    c.plate(circle_pts(ca + th * 0.55, cb + th, R, n=40)[:-1], back, bevel=0.8, shine=0.1, tex=lambda i, *r: 1 if i < 3 else 2)
    c.plate(circle_pts(ca + th * 0.3, cb + th * 0.55, R - 0.3, n=40)[:-1], "paper", bevel=0.4, shine=0.1,
            tex=rim_tex(ca + th * 0.3, cb + th * 0.55))
    yy_disc(c, ca, cb, R, dark, light, rot=0.0, bevel=1.3)
    if lv == 1:
        ## tahta kapak (yarısı fildişi boyalı): solda iki demir çivi menteşe, sağda tahta kama kopça
        for ang in (160, 200):
            r_ = math.radians(ang)
            c.sphere((ca + (R - 1.3) * math.cos(r_), cb + (R - 1.3) * math.sin(r_)), 0.9, "A_iron", shine=0.4)
        c.plate(rect(ca + R - 1.4, cb - 1.2, ca + R + th + 0.4, cb + 1.2), "A_wood", bevel=0.6, shine=0.2)
        return
    rm = {2: "A_iron", 3: "A_steel", 4: "A_silver", 5: "A_gold"}[lv]
    c.tube(circle_pts(ca, cb, R, n=40), LV(lv, 0.75, 1.05), rm, shine=0.5)
    hm = {2: "A_iron", 3: t["tr"], 4: "A_silver", 5: "A_gold"}[lv]
    ## menteşe: solda iki dikey makara
    for ang in (160, 200):
        r_ = math.radians(ang)
        ha, hb = ca + (R + 0.4) * math.cos(r_), cb + (R + 0.4) * math.sin(r_)
        c.plate(rect(ha - 1.1, hb - 1.6, ha + 1.1, hb + 1.6), hm, bevel=0.7, shine=0.5)
    if lv >= 3:
        ## kopça sağda
        c.plate(rect(ca + R - 1.6, cb - 1.5, ca + R + th + 0.8, cb + 1.5), hm, bevel=0.7, shine=0.5)
    if lv == 4:
        ribbon_mark(c, ca - 3.0, cb + R + th - 1.2, cb + R + th + 4.2)
    if lv == 5:
        ## yin noktası lal taşı (yang noktası boyalı kalır)
        c.sphere(g.dtop, 1.7, "A_garnet", shine=0.7)
        glint5(c, lv, ca - R * 0.6, cb - R * 0.6)


DIRS = [("A", "A - Mühürlü Cilt", A_book), ("B", "B - Açık Sayfalar", B_book), ("C", "C - Doğu Risalesi", C_book),
        ("D", "D - Yuvarlak Cilt", D_book)]


def build():
    os.makedirs(ART, exist_ok=True)
    gi = os.path.join(HERE, "out", ".gdignore")
    if not os.path.exists(gi):
        open(gi, "w").close()
    imgs = {}
    frame("horiz")
    for did, _, fn in DIRS:
        for lv in range(1, 6):
            cv = Cv(lv)
            fn(cv, lv)
            img = cv.render()
            img.save(os.path.join(ART, "yinyang_%s_L%d.png" % (did, lv)))
            bb = img.getchannel("A").point(lambda v: 255 if v == 255 else 0).getbbox()
            if bb and (bb[0] == 0 or bb[1] == 0 or bb[2] == N or bb[3] == N):
                print("KENAR!", did, lv, bb)
            imgs[(did, lv)] = img
    return imgs


def sheet(imgs, path, z=4):
    cell = N * z
    lw, gap, top = 190, 14, 40
    W = lw + 5 * (cell + gap) + gap
    H = top + len(DIRS) * (cell + gap) + gap
    im = Image.new("RGBA", (W, H), (34, 38, 40, 255))
    d = ImageDraw.Draw(im)
    for lv in range(1, 6):
        x0 = lw + gap + (lv - 1) * (cell + gap)
        d.text((x0, 10), "%d - %s" % (lv, TA[lv]["name"]), fill=(235, 230, 215), font=font(20, True))
    for ri, (did, label, _) in enumerate(DIRS):
        y0 = top + ri * (cell + gap)
        d.text((12, y0 + cell // 2 - 10), label, fill=(235, 230, 215), font=font(18, True))
        for lv in range(1, 6):
            x0 = lw + gap + (lv - 1) * (cell + gap)
            d.rectangle([x0, y0, x0 + cell - 1, y0 + cell - 1], fill=S.BG)
            im.alpha_composite(imgs[(did, lv)].resize((cell, cell), Image.NEAREST), (x0, y0))
    im.convert("RGB").save(path)
    print("sayfa", path, im.size)


def context(imgs):
    """Oyun ölçeği: 1 sanat px = 0,575 dünya px x zoom 2, Talon + Uzunkılıç L3 + Mızrak L3 boy kıyası, resim x2."""
    zoom, wpp = 2.0, 0.575
    cwp = 2.2368375 * 0.8075 * 0.5
    ch_img = Image.open(os.path.join(E.GAME, "assets/characters/talon/sheets/idle.png")).convert("RGBA").crop((0, 96, 48, 144))
    sword = Image.open(os.path.join(E.GAME, "assets/weapons/zanaat/uzunkilic_L3.png")).convert("RGBA")
    spear = Image.open(os.path.join(E.GAME, "assets/weapons/zanaat/mizrak_L3.png")).convert("RGBA")
    cw, chh, lw, top = 50, 70, 130, 24
    lead = 160
    W = lw + lead + 5 * cw + 10
    H = top + len(DIRS) * (chh + 6)
    im = Image.new("RGB", (W, H), (34, 38, 40))
    d = ImageDraw.Draw(im)
    d.text((8, 4), "Yin Yang Kitabı - oyun ölçeği (zoom 2)  ·  solda Talon + Uzunkılıç L3 + Mızrak L3", fill=(235, 230, 215), font=font(12, True))
    for ri, (did, label, _) in enumerate(DIRS):
        y0 = top + ri * (chh + 6)
        d.text((8, y0 + chh // 2 - 8), label, fill=(235, 230, 215), font=font(12, True))
        pc = Image.new("RGB", (lead + 5 * cw, chh), S.BG)
        E.blit_world(pc, ch_img, 34, chh // 2 + 4, cwp, zoom)
        E.blit_world(pc, sword, 82, chh // 2, wpp, zoom)
        E.blit_world(pc, spear, 128, chh // 2, wpp, zoom)
        for lv in range(1, 6):
            E.blit_world(pc, imgs[(did, lv)], lead + (lv - 1) * cw + cw // 2, chh // 2, wpp, zoom)
        im.paste(pc, (lw, y0))
    path = os.path.join(OUT, "yinyang_sanat_oyun.png")
    im.resize((W * 2, H * 2), Image.NEAREST).save(path)
    print("oyun", path)


if __name__ == "__main__":
    imgs = build()
    sheet(imgs, os.path.join(OUT, "yinyang_sanat_sayfa.png"))
    context(imgs)
