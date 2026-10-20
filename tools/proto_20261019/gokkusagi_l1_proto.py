# -*- coding: utf-8 -*-
"""GÖKKUŞAĞI ASASI 1. seviye (Paslı) yeniden çizim prototipleri (2026-10-19, madde 320).

Kullanıcı: "gökkuşağı asasının ilk seviyesi mızrağa benziyor asadan ziyade". Teşhis: L1 prizması renksiz gri kuvars (SPECTRUM n=0)
+ ileri bakan sivri üçgen + altında ip sargısı + düz sap = mızrak ucu. L2-L5 renkli prizma + metal pençe ile okunuyor.
  ŞU AN  : oyundaki L1
  A Çatallı Dal (SEÇİLDİ, oyunda) : sap tepede ikiye ayrılır, iki ahşap kol prizmayı yanlardan kavrar (lir/sapan), prizma 3 renk, kısa (mızrak ucu değil)
  B Kök Yuvası  : sap ucunda boğumlu ahşap topuz, kök pençeler prizmanın tabanını sarar, topuzdan küçük yaprak çıkar
  C Ahşap Pençe : bugünkü düzen + 3 renkli prizma + L2'nin pençesi ahşaptan (merdiven en tutarlı, değişiklik en az)
Çıktı out/gokkusagi/l1_secenek.png (x5 + oyun ölçeği x1 + L2 yanında). Çalıştırma: python tools/proto_20261019/gokkusagi_l1_proto.py
"""
import math
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gokkusagi_proto as G  # noqa: E402
from gokkusagi_proto import Cv, frame, P, SPECTRUM, E, bar, staff_base, label, N  # noqa: E402

OUT = os.path.join(HERE, "out", "gokkusagi")
PE = -27.0


def prism(c, base_a, s, h, n=3, mat="R_prism"):
    """İleri bakan üçgen prizma, taban base_a, yarı genişlik s, boy h; n renk bandı (madde 298 ptex ile aynı kural)."""
    apex_a = base_a + h
    mats = SPECTRUM.get(n, [])

    def ptex(idx, a, b, x, y, d):
        fa = (a - base_a) / (apex_a - base_a)
        if n == 0 or fa < 0.22 or d < 0.7:
            return idx
        half = s * (1.0 - fa) + 0.35
        u = (b / half + 1.0) * 0.5
        k = int(max(0, min(n - 1, math.floor(u * n))))
        return P[mats[k]][max(3, min(6, idx + 1))]
    c.plate([(apex_a, 0.0), (base_a, -s), (base_a, s)], mat, bevel=1.1, shine=0.45, tex=ptex)
    return apex_a


def v_now(c, lv=1):
    """Eski L1 (madde 306'daki A_prism lv 1 dalı, donduruldu)."""
    s, hc = 4.6, 15.0
    base_a = hc - s * 0.7
    staff_base(c, 1, PE, base_a - 1.0, "A_wood", 1.3, tex=E.grain)
    c.plate([(hc + s * 1.25, 0.0), (base_a, -s * 1.02), (base_a, s * 1.02)], "R_quartz", bevel=1.1, shine=0.45)
    c.tube([(base_a - 2.2, 0), (base_a + 0.4, 0)], 1.45, "A_rope", tex=E.wrap, shine=0.15)


def v_fork(c, lv=1):
    """A Çatallı Dal - SEÇİLDİ, oyunda: tek kaynak gokkusagi_proto.A_prism_fork."""
    G.A_prism_fork(c)


def v_root(c, lv=1):
    """B Kök Yuvası: boğumlu ahşap topuz, kökler prizmayı yarıya kadar sarar, küçük yaprak."""
    ka = 6.0
    staff_base(c, 1, PE, ka - 1.0, "A_wood", 1.3, tex=E.grain)
    ap = prism(c, ka + 1.8, 4.6, 9.6)
    c.sphere((ka, 0.0), 2.9, "A_wood", shine=0.35)
    for sg in (-1, 1):
        c.tube([(ka + 1.0, sg * 2.0), (ka + 3.2, sg * 5.0), (ka + 6.0, sg * 4.4), (ka + 7.4, sg * 2.8)], (1.0, 0.5), "A_wood",
               tex=E.grain, shine=0.35)
    c.plate([(ka - 2.0, -2.2), (ka - 1.2, -4.4), (ka - 3.2, -5.0), (ka - 3.8, -3.2)], "R_green", bevel=0.9, shine=0.3)
    c.glint(ap - 1.4, -0.6, "R_prism", 6)


def v_claw(c, lv=1):
    """C Ahşap Pençe: madde 298 A_prism düzeni (L2 boyu) + renkli prizma + L2 pençesi ahşaptan."""
    s, hc = 5.4, 15.5
    base_a = hc - s * 0.7
    staff_base(c, 1, PE, base_a - 1.0, "A_wood", 1.3, tex=E.grain)
    ap = prism(c, base_a, s * 1.02, s * 1.95)
    for sg in (-1, 1):
        c.tube([(base_a - 2.0, sg * 0.5), (base_a - 0.5, sg * (s * 1.02 + 0.3)), (base_a + s * 0.75, sg * (s * 0.62 + 0.25))],
               0.8, "A_wood", tex=E.grain, shine=0.35)
    c.tube([(base_a - 3.6, 0), (base_a - 1.2, 0)], 1.6, "A_rope", tex=E.wrap, shine=0.15)
    c.glint(ap - 1.6, -0.6, "R_prism", 6)


VARIANTS = [("ŞU AN", v_now), ("A Çatallı Dal", v_fork), ("B Kök Yuvası", v_root), ("C Ahşap Pençe", v_claw)]


def render(fn, lv=1):
    cv = Cv(lv)
    fn(cv, lv)
    img = cv.render()
    a = img.getchannel("A").point(lambda v: 255 if v == 255 else 0).getbbox()
    if a and (a[0] == 0 or a[1] == 0 or a[2] == N or a[3] == N):
        print("KENAR!", fn.__name__, a)
    return img


def main():
    frame("diag")
    os.makedirs(OUT, exist_ok=True)
    icons = [(name, render(fn)) for name, fn in VARIANTS]
    l2 = render(G.A_prism, 2)
    z, gap, top = 7, 16, 30
    cell = N * z
    W = gap + len(icons) * (cell + gap)
    H = top + cell + gap + 60 + gap
    im = Image.new("RGBA", (W, H), (58, 68, 58, 255))
    d = ImageDraw.Draw(im)
    for i, (name, ic) in enumerate(icons):
        x = gap + i * (cell + gap)
        label(d, x + 4, 8, name, 14)
        im.alpha_composite(ic.resize((cell, cell), Image.NEAREST), (x, top))
        # oyun ölçeği (1 sanat px ~ 1,15 ekran px @1080p) + yanında L2
        y = top + cell + gap
        im.alpha_composite(ic.resize((55, 55), Image.NEAREST), (x + 20, y))
        im.alpha_composite(l2.resize((55, 55), Image.NEAREST), (x + 90, y))
        label(d, x + 150, y + 20, "<- oyun ölçeği, sağda L2", 11)
    p = os.path.join(OUT, "l1_secenek.png")
    im.convert("RGB").save(p)
    for name, ic in icons:
        G_ICON = os.path.join(OUT, "l1_%s.png" % name.split()[0].lower().replace("ş", "s"))
        ic.save(G_ICON)
    print(p)


if __name__ == "__main__":
    main()
