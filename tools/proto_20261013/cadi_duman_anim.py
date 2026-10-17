"""Cadı Q dumanı - seçilen dumanın HAREKETLİ önizlemesi (kullanıcı 2026-10-13: "b yi seçiyorum, saydamlık ayarı
olarak da 2" = duman yaratıkların ÜSTÜNDE, her bulut ayrı %50). Sayfa yapısı oyundakiyle aynı: doğuş 5 + döngü 8 +
sönüş 7 kare, 10 kare/sn - onaylanınca aynı kareler tools/gen_cadi_fx.py smoke sayfasına yazılır.
    python -I tools/proto_20261013/cadi_duman_anim.py  -> out/cadi_duman_anim.gif
Duman: 2. turdaki F (kullanıcı önce 1. turdaki B'yi seçti, hareketlisini görünce "vazgeçtim f yi seçiyorum").
Yaratık yerine başka karakterler duruyor.
"""
import math
import os
import random
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import cadi_duman_proto as P  # noqa: E402
from cadi_duman_proto import G, GX, GY, Canvas, TAU  # noqa: E402

N_IN, N_LOOP, N_OUT = 5, 8, 7
FPS = 20
NF = 72  # 3,6 sn: bulut aralığının (8 kare) ve yürüme döngüsünün (12 kare) katı -> dikişsiz
W, H, Z = 328, 92, 3
SPEED = W / NF  # 4,56 px/kare = 91 sanat px/sn (gerçek yürüme hızı)
FEET_Y = 72
LIFE = 3.0  # önizlemede; oyunda 6 sn
ALPHA = 0.5
BOT, LAND = P.BOT, P.LAND
FIGS = [(96, 'korsan'), (214, 'hadime')]


def sheet_frames(fn):
    fr = {'in': [], 'loop': [], 'out': []}
    for i in range(N_IN):
        fr['in'].append(fn(G.lerp(0.25, 1.0, G.ease_out((i + 1) / N_IN)), ((i - N_IN) % N_LOOP) / N_LOOP, 0.0))
    for i in range(N_LOOP):
        fr['loop'].append(fn(1.0, i / N_LOOP, 0.0))
    for i in range(N_OUT):
        fr['out'].append(fn(1.0, (i % N_LOOP) / N_LOOP, (i + 1) / (N_OUT + 0.6)))
    return fr


def pick(fr, age):
    fi = int(age * 10 + 1e-6)
    t_out = LIFE - N_OUT / 10.0
    if fi < N_IN:
        return fr['in'][fi]
    if age >= t_out:
        return fr['out'][min(N_OUT - 1, int((age - t_out) * 10 + 1e-6))]
    return fr['loop'][(fi - N_IN) % N_LOOP]


def pour(pal, t, clean):
    cv = Canvas(40, 40)
    mx, my = BOT[0] - 8.1, BOT[1] + 8.1
    circles = []
    for k in range(5):
        s = (k + t) / 5.0
        circles.append((20 + (LAND[0] - mx) * s + math.sin(TAU * (s + t)) * 0.8, 4 + (LAND[1] - my) * s ** 1.15, (1.5 + 3.6 * s) * min(1.0, (1.0 - s) / 0.2 + 0.3)))
    if clean:
        P.clean_cloud(cv, circles, pal, under=1, shade=2, min_r=1.0)
    else:
        G.soft_cloud(cv, circles, [None] + pal[1:], t, 53, squash=1.0, edge=0.3)
    return cv.rgba.copy(), (mx - 20, my - 4)


def row(f, fr, pal, clean, walk, potion, figs):
    dst = G.grass(W, H)
    for (x, sheet) in figs:
        G.shadow(dst, x, FEET_Y - 4, 8, 2.6)
        G.char_at(dst, sheet[0][(f // 5) % len(sheet[0])], x, FEET_Y - 5)
    wx = (40 + f * SPEED) % W
    st, off = pour(pal, (f % 16) / 16.0, clean)
    bob = round(math.sin(TAU * f / 24.0) * 1.5)
    for o in (-W, 0, W):
        G.shadow(dst, wx + o, FEET_Y + 1, 8, 2.6)
        G.blit(dst, st, wx + o + off[0], FEET_Y + off[1] + bob, alpha=0.9)
        G.blit(dst, potion[(f // 2) % 8], wx + o + BOT[0] - G.POT_CX, FEET_Y + BOT[1] + bob - G.POT_CY)
        G.char_at(dst, walk[2][(f // 2) % 6], wx + o, FEET_Y)
    clouds = []
    for back in range(NF):
        ff = f - back
        if ff % 8 != 0:
            continue
        age = back / FPS
        if age > LIFE:
            break
        clouds.append((age, ((40 + ff * SPEED) % W) + LAND[0], (ff % NF) // 8))
    for (age, cx, ci) in sorted(clouds, reverse=True):
        im = pick(fr, age)
        flip = random.Random(ci * 7 + 3).random() < 0.5  # oyunda: bulut başına rastgele aynalama
        for o in (-W, 0, W):
            G.blit(dst, im, cx + o - GX, FEET_Y + LAND[1] - GY, alpha=ALPHA, flip=flip)
    return dst


def main():
    walk = G.load_game_sheet('cadi', 'walk')
    potion = G.q_potion_frames()
    figs = [(x, G.load_game_sheet(k, 'idle')) for (x, k) in FIGS]
    rows = [('F · Kabaran Duman (mor gölge + hacim yayları) - yaratıkların üstünde, bulut başına %50', sheet_frames(P.frame_f), P.PAL_F, True)]
    ims = []
    for f in range(NF):
        full = np.zeros((H * len(rows), W, 3), np.uint8)
        for i, (_n, fr, pal, clean) in enumerate(rows):
            full[i * H:(i + 1) * H] = row(f, fr, pal, clean, walk, potion, figs)
            full[i * H] = (60, 86, 44)
        im = G.up(full, Z)
        for i, (n, _a, _b, _c) in enumerate(rows):
            G.label(im, 8, i * H * Z + 6, n, 16)
        G.label(im, 8, H * Z - 24, 'gerçek yürüme hızı; bulut burada 3 sn kalıyor, oyunda 6 sn', 13)
        ims.append(im)
    G.save_gif(ims, os.path.join(HERE, 'out', 'cadi_duman_anim.gif'), 1000 // FPS)


if __name__ == '__main__':
    main()
