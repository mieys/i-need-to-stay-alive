#!/usr/bin/env python3
"""Yaratiklarin YANMA efektinin ATES katmani - minimal 48x48 pixel-art spritesheet.

Kullanici istegi (2026-09-24): "oyundaki yakma efektini daha minimal pixel tarzda 48x48 ve goz yormayacak sekilde
degistirmeni istiyorum ancak dumana dokunma" + "bu efekt icin de spritesheete donustur".
Eski ates (assets/generated/fx_burn_fire_v2.png, 119x124 kareler) disaridan gelmis yumusak kenarli, cok parlak ve hizli
titreyen bir alevdi. Yeni alev (fx_burn_status.gd FIRE katmani; DUMAN katmani ve ayarlari HIC degismedi):
  * 48x48 kare, 1 sanat pikseli = TEXEL (karakterlerle ayni piksel yogunlugu), 8 kare / 8 fps sakin dongu.
  * Goz yormayan: sadece 4 yumusak ton (soluk sari ic, turuncu, koyu turuncu-kirmizi, koyu kontur), beyaz-sicak
    parlama YOK, kareler arasinda toplam parlaklik sabit (yanip sonme yok) - sadece alev dilleri hafifce sallanir.
  * Uc alev dili (ortada uzun, yanlarda kisa, farkli fazda) + nadiren yukselen tek bir kor.
Cikti: assets/fx/burn/fire_min_sheet.png + fire_min_frames.tres ("burn" - fx_burn_status.gd'nin oynattigi ad).
Kullanim: python tools/gen_burn_fire_fx.py [onizleme.png]
"""
import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_enemy_ability_fx import put, rgba, outline_pass  # noqa: E402
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx", "burn")
RES = "res://assets/fx/burn/"
N = 48
FRAMES = 8
FPS = 8.0

INNER = rgba(1.0, 0.86, 0.46)   # soluk sari (beyaz degil)
MID = rgba(0.98, 0.58, 0.2)     # yumusak turuncu
OUTER = rgba(0.84, 0.3, 0.12)   # koyu turuncu-kirmizi
EDGE = rgba(0.4, 0.1, 0.06)     # kontur

BASE_Y = 42
# (x ofseti, boy, genislik, faz)
TONGUES = [(0, 26, 7.0, 0.0), (-8, 15, 5.0, 2.1), (8, 17, 5.2, 4.0)]


def frame(fi):
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ph = fi / FRAMES * math.tau
    for ox, h0, w0, p0 in TONGUES:
        h = h0 * (0.9 + 0.1 * math.sin(ph + p0))
        sway = math.sin(ph + p0) * 1.4
        top = int(h)
        for yy in range(top + 1):
            u = yy / max(h, 1.0)  # 0 taban .. 1 uc
            half = w0 * (1.0 - u) ** 0.75 * (0.6 + 0.4 * (1.0 - u))
            cx = N / 2 + ox + sway * u * u
            for xx in range(int(cx - half - 1), int(cx + half + 2)):
                d = abs(xx + 0.5 - cx) / max(half, 0.5)
                if d > 1.0:
                    continue
                heat = (1.0 - d) * 0.55 + (1.0 - u) * 0.45
                col = INNER if heat > 0.76 else (MID if heat > 0.44 else OUTER)
                put(im, xx, BASE_Y - yy, col)
    # taban: alevlerin oturdugu kisa koz cizgisi
    for x in range(N // 2 - 10, N // 2 + 11):
        put(im, x, BASE_Y + 1, OUTER)
    outline_pass(im, EDGE)
    # nadir kor: 8 karelik dongude tek bir kivilcim yukselir (konturlanmaz)
    k = fi / FRAMES
    put(im, N // 2 + 5 + math.sin(k * math.tau) * 2, BASE_Y - 22 - k * 14, MID if k < 0.6 else OUTER)
    return im


def main():
    frames = [frame(i) for i in range(FRAMES)]
    sheet = Image.new("RGBA", (N * FRAMES, N), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * N, 0), f)
    os.makedirs(OUT, exist_ok=True)
    sheet.save(os.path.join(OUT, "fire_min_sheet.png"))
    write_sprite_frames(os.path.join(OUT, "fire_min_frames.tres"), RES + "fire_min_sheet.png", N, N,
                        [("burn", (0, 0), FRAMES, True, FPS)])
    print("wrote fire_min", sheet.size)
    if len(sys.argv) > 1:
        S = 6
        prev = Image.new("RGBA", (N * S * FRAMES + 20, N * S + 20), (58, 72, 52, 255))
        prev.alpha_composite(sheet.resize((N * FRAMES * S, N * S), Image.NEAREST), (10, 10))
        prev.save(sys.argv[1])


if __name__ == "__main__":
    main()
