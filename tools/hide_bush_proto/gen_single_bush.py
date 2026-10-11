"""TEK KARELİK SAKLANMA ÇALILARI (2026-10-10, kullanıcı: "saklanma çalıları toplu yerleştirilmiş, animasyonları doğal durmuyor; tek tek kare kare yerleştirilip
oyuncu içine girince o karedeki çalıların saklanmasını istiyorum"). Her karo = BİR çalı (16x16): 3-5 yapraklı küçük öbek, kenarlarda sallanma payı, tabanda hafif gölge.
K1 dili (gen_brush_proto.py): çimen tonlarında ot + açık gizemli ot (uçları mor/mavi). Çıktı: harita/saklanma_calilik.png (256x16 = 16 çeşit) + önizleme out/tek_*.png.
Kullanım (proje kökünden): python -I tools/hide_bush_proto/gen_single_bush.py
"""
import os
import random
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_brush_proto as G  # noqa: E402

PROJECT = os.path.normpath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(HERE, 'out')
os.makedirs(OUT, exist_ok=True)
TILE = 16
VARIANTS = 16
MARGIN_X = 3          # sallanma payı: yaprak en çok bu kadar kenara yaklaşır (sol 3..sağ 12)


def one(seed, mystic):
    rng = random.Random(seed)
    for attempt in range(40):
        img = G.Img(TILE, TILE)
        # zemin gölgesi (tabanda küçük koyu elips)
        for dx in range(-4, 5):
            a = 70 if abs(dx) < 3 else 40
            img.put(8 + dx, 15, G.GROUND_SHADE, a)
        k = rng.randint(6, 8)
        ramp = G.MYSTIC_LIGHT if mystic and rng.random() < 0.6 else G.GRASS
        hs = []
        for j in range(k):
            side = (j - (k - 1) / 2) / max(1, (k - 1) / 2)
            h = int(rng.uniform(9, 14) * (1.0 - 0.28 * abs(side)))
            lean = side * rng.uniform(0.14, 0.26) + rng.uniform(-0.04, 0.04)
            hs.append((abs(side), side, h, lean))
        for _, side, h, lean in sorted(hs, key=lambda q: -q[0]):
            tip = rng.choice(G.MYSTIC_TIPS) if mystic and rng.random() < 0.5 else None
            G.blade(img, 8 + side * 2.0 + rng.uniform(-0.4, 0.4), 14, max(6, h), lean, ramp, rng, tip=tip, wide=True)
        for dx in (-3, -2, -1, 0, 1, 2, 3):
            img.put(8 + dx, 15, ramp[0], 140 if abs(dx) < 3 else 90)
        a = img.a[:, :, 3]
        cols = np.nonzero(a.max(axis=0) > 0)[0]
        if cols.size and cols.min() >= MARGIN_X and cols.max() <= TILE - 1 - MARGIN_X and np.nonzero(a.max(axis=1) > 0)[0].min() >= 1:
            return img.image()
    return img.image()


def build():
    atlas = Image.new('RGBA', (TILE * 16, TILE * ((VARIANTS + 15) // 16)), (0, 0, 0, 0))
    tiles = []
    for i in range(VARIANTS):
        t = one(5000 + i * 17, mystic=(i % 2 == 1) or i >= 12)
        tiles.append(t)
        atlas.alpha_composite(t, ((i % 16) * TILE, (i // 16) * TILE))
    return atlas, tiles


def preview(tiles):
    """gerçek çimen rengi üstünde: rastgele tek tek yerleştirilmiş çalılar + oyuncu boyutu (9x21) boş / çalıda"""
    sc = 6
    W, H = 18, 8
    base = Image.new('RGBA', (W * TILE, H * TILE), (126, 176, 84, 255))
    rng = random.Random(7)
    for y in range(H):
        for x in range(W):
            if rng.random() < 0.45:
                base.alpha_composite(rng.choice(tiles), (x * TILE, y * TILE))
    big = base.resize((base.width * sc, base.height * sc), Image.NEAREST)
    big.convert('RGB').save(os.path.join(OUT, 'tek_alan.png'))
    row = Image.new('RGBA', (VARIANTS * TILE, TILE), (126, 176, 84, 255))
    for i, t in enumerate(tiles):
        row.alpha_composite(t, (i * TILE, 0))
    row.resize((row.width * 8, row.height * 8), Image.NEAREST).convert('RGB').save(os.path.join(OUT, 'tek_cesitler.png'))


if __name__ == '__main__':
    atlas, tiles = build()
    atlas.save(os.path.join(OUT, 'saklanma_calilik_tek.png'))
    preview(tiles)
    print('tamam', atlas.size)
