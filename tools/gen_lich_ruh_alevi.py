# -*- coding: utf-8 -*-
"""Lich büyülü atışı "A - Ruh Alevi" sprite sayfaları (madde 280). Çizim prototipten: tools/proto_20261019/lich_mermi_proto.py (A_shot / A_impact).

1 sanat pikseli = PixelDraw.TEXEL dünya px (sahnede Sprite2D ölçeği TEXEL). Mermi döndürülmez: her yön sanat çözünürlüğünde ayrı çizilir
(döndürülen piksel sprite'ı tırtıklı oluyordu) -> satır = yön (32 yön, 0 = +x, açı saat yönünde artar = Vector2.angle()), sütun = kare.
Çıktılar (assets/fx/lich/):
  ruh_alevi.png         büyü   : 6 kare x 32 yön, hücre 40x40, pivot hücre merkezi (baş)
  ruh_alevi_kucuk.png   normal : 6 kare x 32 yön, hücre 24x24
  ruh_alevi_isabet.png  büyü isabeti : 9 kare (25 fps), hücre 32x32
  ruh_alevi_isabet_kucuk.png normal isabeti : 7 kare, hücre 24x24
Çalıştırma: python tools/gen_lich_ruh_alevi.py  (sonra yeni PNG için: Godot --headless --path . --import)
"""
import math
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "proto_20261019"))
import lich_mermi_proto as P  # noqa: E402

OUT = os.path.normpath(os.path.join(HERE, "..", "assets", "fx", "lich"))
NDIR = 32
NF = P.A_NF  # 6
FPS_IMPACT = 25


def shot_cell(ang, f, normal, cell):
    cv = P.Cv(cell, cell)
    pal = P.TIERS[1]
    if normal:
        fn = P.flame_fn(f, NF, 2.3, [(6.5, 0.0, 0.9, 0.0, 1.9)], pal, 0.9)
    else:
        fn = P.flame_fn(f, NF, 3.5, [(15.0, 0.0, 1.5, 0.0, 2.6), (10.0, -3.2, 1.6, 1.9, 1.5), (11.0, 3.0, 1.6, 3.6, 1.5)], pal, 1.4)
    cv.field(fn, ang)
    return cv.im


def check_edges(im, name):
    """Hücre kenarına değen piksel = kırpılmış çizim."""
    w, h = im.size
    p = im.load()
    for x in range(w):
        if p[x, 0][3] or p[x, h - 1][3]:
            raise SystemExit("%s: hücre kenarına taşıyor (x=%d)" % (name, x))
    for y in range(h):
        if p[0, y][3] or p[w - 1, y][3]:
            raise SystemExit("%s: hücre kenarına taşıyor (y=%d)" % (name, y))


def shot_sheet(normal, cell, path):
    sheet = Image.new("RGBA", (cell * NF, cell * NDIR), (0, 0, 0, 0))
    for d in range(NDIR):
        ang = d * 2.0 * math.pi / NDIR
        for f in range(NF):
            im = shot_cell(ang, f, normal, cell)
            check_edges(im, "%s d%d f%d" % (os.path.basename(path), d, f))
            sheet.paste(im, (f * cell, d * cell))
    sheet.save(path)
    print(path, sheet.size)


def impact_sheet(normal, cell, path):
    frames = []
    fi = 0
    while True:
        im = P.A_impact(fi / float(FPS_IMPACT), normal, 1)
        if im is None:
            break
        # prototip tuvali 64x48, pivot (32, 24) -> hücre merkezine kırp
        c = im.crop((32 - cell // 2, 24 - cell // 2, 32 + cell // 2, 24 + cell // 2))
        check_edges(c, "%s f%d" % (os.path.basename(path), fi))
        frames.append(c)
        fi += 1
    sheet = Image.new("RGBA", (cell * len(frames), cell), (0, 0, 0, 0))
    for i, c in enumerate(frames):
        sheet.paste(c, (i * cell, 0))
    sheet.save(path)
    print(path, sheet.size, len(frames), "kare")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    shot_sheet(False, 40, os.path.join(OUT, "ruh_alevi.png"))
    shot_sheet(True, 24, os.path.join(OUT, "ruh_alevi_kucuk.png"))
    impact_sheet(False, 32, os.path.join(OUT, "ruh_alevi_isabet.png"))
    impact_sheet(True, 24, os.path.join(OUT, "ruh_alevi_isabet_kucuk.png"))
