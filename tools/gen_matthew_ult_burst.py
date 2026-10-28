#!/usr/bin/env python3
"""Matthew R "Yıldırım Kalkanı" PATLAMASI - yeni sayfa (madde 356, 2026-10-21).

Kullanıcı: "matthewin ultisi patlamıyor gibi görünüyor ... efekti hiç görünmüyor gibi, iyi bir patlama efekti ve sarsıntı olmalı
patladığında pikachunun çıldırışı gibi". Eski sayfa (gen_matthew_simsek.py shield_explosion) 1-2 px ince yaylardan ibaretti, 220
birimlik alanın çoğu boş kalıyordu. Yeni sayfa: dolu merkez parlaması + her karede YENİDEN çakan kalın ışınsal şimşekler (çıldırış
titremesi) + dolu şok dalgası bandı + yarı saydam düz bantlı aydınlık + sonda kenardan fırlayan kıvılcım çizgileri / 4 uçlu
parıltılar (dither / tek piksel serpinti YOK - bkz. hafıza feedback-minimal-visuals-and-prototypes, sandık v3 dersi).

Çizim yardımcıları + palet (G) onaylı Matthew şimşek prototipinden (tools/proto_20261012/gen_matthew_simsek.py) gelir - aynı el.
Oyunda TEXEL (1.212) ile gösterilir: R = 182 sanat pikseli = 220 dünya birimi = hasar yarıçapı (matthew_lightning.gd BURST_RADIUS).
Kare boyu / sayısı / hızı scripts/matthew_lightning.gd SHEETS["nova"] ile AYNI olmalı.

Kullanım (repo kökünden):  python -I tools/gen_matthew_ult_burst.py [--gif ÇIKTI.gif]
(gen_matthew_lightning_fx.py de 'nova' sayfasını buradan yazar.) Sonra Godot --headless --import ya da editöre dön.
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools', 'proto_20261012'))
import gen_matthew_simsek as g  # noqa: E402
from gen_matthew_simsek import G, WHITE, TAU, Layer, bolt, zig, dilate, dash  # noqa: E402

SIZE = 440
R = 182.0  ## 220 dünya birimi / 1.212
N = 14
FPS = 18
COLS = 5


def _disc(ly, d, r):
    """Merkez parlaması: koyu kontur + altın + krem + beyaz çekirdek (düz bantlar)."""
    if r < 2.0:
        return
    m = d <= r
    ly.put(dilate(m) & ~m & ~ly.filled(), G[0])
    ly.put(m, G[3])
    ly.put(d <= r * 0.78, G[4])
    ly.put(d <= r * 0.5, WHITE)


def _shock(ly, d, th, r, thick, k, seed=1.3):
    """Şok dalgası: dolu bant (dış kenar krem, iç altın, dışta koyu kontur) + içte iki basamak yarı saydam iz.
    k > 0 ilerledikçe hilallere ayrılır (parçalar incelerek biter)."""
    if k > 0.0:
        pat = np.sin(th * 7 + seed) * 0.6 + np.sin(th * 3 + seed * 2.3) * 0.4
        mult = np.clip(((1.0 - 1.9 * k) - pat) / 0.5, 0.0, 1.0)
    else:
        mult = np.ones_like(d)
    live = mult > 0.05
    t = thick * mult
    band = (d <= r) & (d >= r - t) & live
    ly.put(dilate(band) & ~band & (d > r - 0.5) & ~ly.filled(), G[0])
    ly.put(band, G[2])
    ly.put(band & (d >= r - np.maximum(1.5, t * 0.45)), G[4])
    trail = (d < r - t) & live & ~ly.filled()
    ly.put(trail & (d >= r - t - 7.0 * mult), G[3], alpha=120)
    ly.put(trail & (d < r - t - 7.0 * mult) & (d >= r - t - 16.0 * mult), G[3], alpha=60)


def _branches(ly, rng, pts, count, lmin, lmax, w):
    """Ana şimşekten ayrılan çatallar (ana şimşekten ÖNCE çizilir). Uca yakın noktadan çıkmaz - tuval kenarına taşmasın."""
    ax = math.atan2(pts[-1][1] - pts[0][1], pts[-1][0] - pts[0][0])
    for _ in range(count):
        k = rng.randrange(1, max(2, len(pts) - 2))
        x, y = pts[k]
        a = ax + rng.choice((-1, 1)) * rng.uniform(0.5, 1.0)
        ln = rng.uniform(lmin, lmax)
        bolt(ly, zig(rng, (x, y), (x + math.cos(a) * ln, y + math.sin(a) * ln), 5, 2.5), w=w, taper=2)


def _rays(ly, c, seed, n, r0, r1, w, nbr, keep_thr=None):
    """Merkezden dışa çakan n şimşek. Her kare farklı tohum = her kare yeniden çakar (çıldırış titremesi)."""
    rot = random.Random(seed * 7919).uniform(0, TAU)
    for b in range(n):
        rb = random.Random(seed * 1000 + b)
        a = rot + TAU * b / n + rb.uniform(-0.2, 0.2)
        rr0 = r0 * rb.uniform(0.9, 1.25)
        rr1 = r1 * rb.uniform(0.84, 1.0)
        if rr1 - rr0 < 8:
            continue
        pts = zig(rb, (c + math.cos(a) * rr0, c + math.sin(a) * rr0), (c + math.cos(a) * rr1, c + math.sin(a) * rr1), 13, 7.0)
        if nbr:
            _branches(ly, rb, pts, nbr, 12, 30 if w >= 5 else 20, 3 if w >= 5 else 1)
        bolt(ly, pts, w=w, taper=4 if w >= 5 else 3, keep=dash(keep_thr, b + seed) if keep_thr else None)


def _glow(ly, d, r, a):
    """Alanın aydınlanması: boş piksellere iki basamak yarı saydam krem (dither yok)."""
    if r <= 0 or a <= 0:
        return
    free = ~ly.filled()
    ly.put(free & (d <= r * 0.55), G[4], alpha=min(255, a + 35))
    ly.put(free & (d > r * 0.55) & (d <= r), G[4], alpha=a)


def _streaks(ly, c, seed, n, r_in, ln, bright):
    """Kenardan dışa fırlayan kısa kıvılcım çizgileri (hız yönünde, uçları incelir)."""
    for q in range(n):
        rq = random.Random(seed * 31 + q)
        a = TAU * q / n + rq.uniform(-0.25, 0.25)
        r0 = r_in * rq.uniform(0.88, 1.0)
        pts = [(c + math.cos(a) * r0, c + math.sin(a) * r0), (c + math.cos(a) * (r0 + ln), c + math.sin(a) * (r0 + ln))]
        bolt(ly, pts, w=3 if bright else 1, taper=2, core=G[4] if bright else G[3])


def _sparkle(ly, x, y, arm):
    """4 uçlu parıltı: beyaz merkez, krem/altın kollar (büyüyüp küçülür)."""
    x, y = int(round(x)), int(round(y))
    for s in range(1, arm + 1):
        col = G[4] if s <= max(1, arm // 2) else G[3]
        for dx, dy in ((s, 0), (-s, 0), (0, s), (0, -s)):
            ly.px(x + dx, y + dy, col)
    if arm >= 2:
        for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
            ly.px(x + dx, y + dy, G[3])
    ly.px(x, y, WHITE)


## kare -> (disk r, şok r, şok kalınlık, şok k, ışın tohumu, ışın r0, ışın r1 (R oranı), ışın w, çatal, kopma eşiği, aydınlık r, aydınlık alfa)
## Aydınlık şok dalgası varken onun İÇİNDE kalır (dışında soluk bir daire "ikinci halka" gibi okunuyordu).
PLAN = [
    (30, 0, 0, 0.0, 1, 24, 0.40, 5, 0, None, 95, 80),
    (42, 78, 10, 0.0, 2, 30, 0.66, 5, 2, None, 140, 70),
    (36, 124, 10, 0.0, 3, 26, 1.00, 5, 3, None, 165, 55),
    (30, 156, 9, 0.0, 4, 22, 1.00, 5, 3, None, 175, 42),
    (25, 176, 8, 0.0, 5, 22, 1.00, 5, 2, None, 178, 30),
    (21, 186, 7, 0.15, 6, 20, 0.96, 3, 2, None, 0, 0),
    (19, 190, 6, 0.35, 7, 20, 1.00, 5, 2, None, 0, 0),  ## yeniden çakış (çıldırışın ikinci nefesi)
    (14, 193, 5, 0.55, 8, 22, 0.94, 3, 1, None, 0, 0),
    (9, 195, 4, 0.75, 9, 26, 0.90, 3, 0, 0.30, 0, 0),
    (0, 0, 0, 0.0, 10, 40, 0.86, 3, 0, 0.50, 0, 0),
    (0, 0, 0, 0.0, 0, 0, 0, 0, 0, None, 0, 0),
    (0, 0, 0, 0.0, 0, 0, 0, 0, 0, None, 0, 0),
    (0, 0, 0, 0.0, 0, 0, 0, 0, 0, None, 0, 0),
    (0, 0, 0, 0.0, 0, 0, 0, 0, 0, None, 0, 0),
]
## Son karelerde dışa fırlayan kıvılcımlar / parıltılar: kare -> (çizgi r, çizgi boyu, parlak mı, parıltı kol boyu)
## (1 px kesik ışınlar "nokta nokta parazit" gibi duruyordu -> kuyrukta sadece kısa çizgiler + az sayıda biçimli parıltı.)
TAIL = {8: (150, 12, True, 0), 9: (172, 14, True, 3), 10: (188, 9, False, 3), 11: (0, 0, False, 2), 12: (0, 0, False, 2), 13: (0, 0, False, 1)}


def frame(f):
    ly = Layer(SIZE, SIZE)
    c = SIZE / 2.0
    X, Y = ly.grid()
    d = np.hypot(X - c, Y - c)
    th = np.arctan2(Y - c, X - c)
    dr, sr, st, sk, seed, r0, r1, w, nbr, keep, gr, ga = PLAN[f]
    if sr > 0:
        _shock(ly, d, th, sr, st, sk)
    if seed:
        if f == 0:  ## ilk kare: kısa kalın dikenler (patlamanın çekirdeği)
            _rays(ly, c, seed, 12, r0, R * r1, w, 0)
        else:
            _rays(ly, c, seed, 11, r0, R * r1, w, nbr, keep)
    _disc(ly, d, dr)
    if f in TAIL:
        sr_, sl, bright, arm = TAIL[f]
        if sr_ > 0:
            _streaks(ly, c, 40 + f, 14, sr_, sl, bright)
        if arm > 0:
            for q in range(7):
                rq = random.Random(700 + q)  ## parıltılar kareler boyunca yerinde kalır, sadece küçülür
                a = TAU * q / 7 + rq.uniform(-0.3, 0.3)
                rr = R * rq.uniform(0.45, 0.95)
                _sparkle(ly, c + math.cos(a) * rr, c + math.sin(a) * rr, arm if (q + f) % 3 else max(1, arm - 1))
    _glow(ly, d, min(gr, sr - st) if sr > 0 else gr, ga)
    return ly.img()


def frames():
    return [frame(f) for f in range(N)]


def preview_gif(path, frs, scale=2):
    """Oyun ölçeği önizlemesi: çimen üstünde, 1 sanat pikseli = TEXEL x zoom 2 ~ 2,4 ekran px (burada tam sayı: 2)."""
    w = SIZE * scale
    out = []
    bg = Image.new('RGBA', (SIZE, SIZE), (*g.GRASS, 255))
    for fr in frs:
        im = bg.copy()
        im.alpha_composite(fr)
        out.append(im.resize((w, w), Image.NEAREST).convert('P', palette=Image.ADAPTIVE))
    hold = [bg.resize((w, w), Image.NEAREST).convert('P', palette=Image.ADAPTIVE)] * 6
    seq = hold + out + hold
    seq[0].save(path, save_all=True, append_images=seq[1:], duration=int(1000 / FPS), loop=0, disposal=2)


def main():
    sys.path.insert(0, os.path.join(ROOT, 'tools'))
    import gen_matthew_lightning_fx as lf
    frs = frames()
    lf.save_sheet('nova', frs, cols=COLS)
    if '--gif' in sys.argv:
        preview_gif(sys.argv[sys.argv.index('--gif') + 1], frs)


if __name__ == '__main__':
    main()
