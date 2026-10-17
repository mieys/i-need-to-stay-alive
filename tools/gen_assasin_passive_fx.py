#!/usr/bin/env python3
"""Assasin Cocuk PASIFI "Bicak Uzmanligi" (yetenek sonrasi 3 sn garantili kritik) efekt sayfalari -> assets/fx/assasin/passive_*.

Kullanici istegi (2026-10-16): "pasifi icin de ozel efekt hazirlayalim, varligi hic belli olmuyor". Pasifin hic gorseli yoktu
(player.gd _assasin_crit_timer tamamen yerel sayac). Renk KRITIK kirmizisi (oyundaki kritik hasar sayilari kirmizi; ultinin
morundan ayrissin). Iki sayfa, ikisi de karakterin PIKSEL yogunlugunda cizilir (oyunda olcek = karakter sprite'inin olcegi):
  * passive_proc   tetiklenince govde merkezinde: gogus parlamasi + disa acilan ince kirmizi halka + yukari suzulen bicak
                   kiymiklari. 8 kare, 24 fps.
  * passive_glint  pasif surerken govdenin cevresinde ara ara beliren kucuk yildiz parlamasi. 5 kare, 20 fps.
Kiyidaki dis hat + parilti bandi sayfa degil, shader: shaders/assasin_passive_outline.gdshader.

Calistir: python tools/gen_assasin_passive_fx.py [onizleme.png]
"""

import math
import os
import random
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402
import pixfx as P  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx", "assasin")
RES = "res://assets/fx/assasin/"

## Kritik kirmizisi rampasi [kontur, koyu, orta, acik, parlak] - orta ton enemy.gd CRIT_COLOR (1, 0.25, 0.2) civari.
CRIT = [(46, 8, 12), (128, 20, 26), (222, 58, 46), (255, 118, 86), (255, 214, 180)]
STEEL = P.STEEL
WHITE = P.WHITE
CREAM = P.CREAM


def sheet(imgs):
    w, h = imgs[0].size
    out = Image.new("RGBA", (w * len(imgs), h), (0, 0, 0, 0))
    for i, im in enumerate(imgs):
        out.paste(im, (i * w, 0))
    return out


def save(name, frames, anim, loop, fps):
    os.makedirs(OUT, exist_ok=True)
    imgs = [f.image() for f in frames]
    W, H = imgs[0].size
    used = np.zeros((H, W), dtype=bool)
    for f in frames:
        used |= f.rgba[:, :, 3] > 0
    ys, xs = np.nonzero(used)
    if len(xs):
        cx_ = max(0, min(int(xs.min()), W - 1 - int(xs.max())) - 1)
        cy_ = max(0, min(int(ys.min()), H - 1 - int(ys.max())) - 1)
        imgs = [im.crop((cx_, cy_, W - cx_, H - cy_)) for im in imgs]
    sheet(imgs).save(os.path.join(OUT, name + "_sheet.png"))
    w, h = imgs[0].size
    write_sprite_frames(os.path.join(OUT, name + "_frames.tres"), RES + name + "_sheet.png", w, h,
                        [(anim, (0, 0), len(imgs), loop, fps)])
    print("   %-16s %dx%d x %d kare" % (name, w, h, len(imgs)))
    return imgs


def make_proc():
    """Govde merkezli: gogus parlamasi + disa acilan ince kirmizi halka (kopararak soner) + govdenin iki yanindan yukari suzulen
    bicak kiymiklari (ince, ucu sivri, beyaz uclu). Ilk deneme (capraz iki kisa bicak, kabzali) onizlemede "V / kus" gibi okundu."""
    P.PAD[:] = [8, 8]
    W, H, CX, CY = 52, 60, 26, 30
    N = 8
    rng = random.Random(9)
    # bicak kiymiklari: (x ofseti, baslangic y ofseti, hiz px/kare, boy, baslangic karesi)
    slivers = [(-11, 9, 3.2, 5, 0), (11, 7, 3.6, 5, 0), (-6, 13, 2.8, 4, 1), (7, 12, 3.0, 4, 1), (-15, 2, 2.4, 3, 2), (15, 4, 2.6, 3, 2)]
    frames = []
    for f in range(N):
        cv = P.Canvas(W, H)
        u = f / (N - 1)
        # halka: 7 -> 23 px, 0,8 basik; ikinci yarida kopar
        R = 7 + 16 * P.ease_out(min(1.0, u * 1.3))
        if f <= 5:
            mult = P.break_mult(cv, CX, CY, 0.8, max(0.0, (u - 0.35) / 0.65), seed=2.0) if u > 0.35 else None
            P.ring_band(cv, CX, CY, R, 1.6 if f < 3 else 1.1, [CRIT[0], CRIT[1], CRIT[2], CRIT[3], CRIT[4]], squash=0.8,
                        outline=f < 4, mult=mult)
        # gogus parlamasi
        if f == 0:
            P.disc_flash(cv, CX, CY - 4, 2.4, core=WHITE, rim=CRIT[4])
            P.star(cv, CX, CY - 4, 6, core=WHITE, arm=CRIT[4])
        elif f == 1:
            P.star(cv, CX, CY - 4, 4, core=WHITE, arm=CRIT[3], diag=True)
        elif f == 2:
            P.star(cv, CX, CY - 4, 2, core=CRIT[4], arm=CRIT[3])
        # yukari suzulen bicak kiymiklari
        for (ox, oy, sp, ln, f0) in slivers:
            k = f - f0
            if k < 0 or k > 5:
                continue
            L = max(1, ln - max(0, k - 2))
            y0 = CY + oy - sp * k
            x = CX + ox
            for i in range(L):
                col = WHITE if (i == 0 and k < 3) else (CRIT[4] if i < 2 else CRIT[3])
                cv.px(x, y0 + i, col)
            if k < 3:
                cv.px(x - 1, y0 + L, CRIT[1])
                cv.px(x + 1, y0 + L, CRIT[1])
        frames.append(cv)
    return save("passive_proc", frames, "play", False, 24.0)


def make_glint():
    P.PAD[:] = [2, 2]
    W, H, C = 9, 9, 4
    frames = []
    for f in range(5):
        cv = P.Canvas(W, H)
        if f == 0:
            cv.px(C, C, WHITE)
        elif f == 1:
            P.star(cv, C, C, 2, core=WHITE, arm=CRIT[4])
        elif f == 2:
            P.star(cv, C, C, 3, core=WHITE, arm=CRIT[3], diag=True)
        elif f == 3:
            P.star(cv, C, C, 2, core=CRIT[4], arm=CRIT[2])
        else:
            cv.px(C, C, CRIT[3])
        frames.append(cv)
    return save("passive_glint", frames, "play", False, 20.0)


def preview(path, proc, glint):
    rows = [sheet(proc), sheet(glint)]
    Wd = max(r.size[0] for r in rows)
    Hd = sum(r.size[1] + 4 for r in rows)
    out = Image.new("RGBA", (Wd, Hd), (58, 86, 52, 255))
    y = 0
    for r in rows:
        out.alpha_composite(r, (0, y))
        y += r.size[1] + 4
    out.resize((Wd * 6, Hd * 6), Image.NEAREST).save(path)
    print("onizleme:", path)


def main():
    print("Assasin pasif efektleri ->", OUT)
    proc = make_proc()
    glint = make_glint()
    if len(sys.argv) > 1:
        preview(sys.argv[1], proc, glint)


if __name__ == "__main__":
    main()
