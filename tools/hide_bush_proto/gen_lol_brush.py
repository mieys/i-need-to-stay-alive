"""LoL TARZI SAKLANMA ÇALILIĞI - KARE KARE (2026-10-10, kullanıcı: "league of legends tarzı olmalı" + "içine girip saklanabilmemiz ve vücudumuzun içine uyum sağlayabilmesi
için kare kare eklenmiş çalılar olması gerek" + "ayrık ayrık oldu, saklanmaya uygun bir çalı bütünlüğü yok").
Her 16x16 karo = sıkı uzun ot öbeği (K1 dili: haritanın ot tonları + açık gizemli ot, uçları mor/mavi). Karolar yan yana DİKİŞSİZ birleşir (yapraklar karo içinde kalır,
tabanlar karo boyunca yayılır) -> boyanan her alan bütün bir çalılık olur; her karo yine ayrı parça (kendi hışırtısı, kendi derinliği: içindeki karakterin bacakları
altındaki sıraların otlarının arkasında kalır).
KENAR KAROLARI: karonun hangi yanında çalılık YOKSA (üst/alt/sol/sağ açık) o yana göre seyrelen/kısalan sürüm -> çalılığın dış hattı düz kare değil, doğal.
Atlas: 16 sütun x SEEDS satır; sütun = kenar maskesi (1 üst açık, 2 alt açık, 4 sol açık, 8 sağ açık), satır = çeşit. Tiled'da elle boyamak için: iç karolar = sütun 0.
Çıktı: out/saklanma_lol.png + önizleme out/lol_onizleme.png. Kullanım (proje kökünden): python -I tools/hide_bush_proto/gen_lol_brush.py
"""
import os
import random
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_brush_proto as G  # noqa: E402

OUT = os.path.join(HERE, 'out')
os.makedirs(OUT, exist_ok=True)
TILE = 16
SEEDS = 4
TOP, BOTTOM, LEFT, RIGHT = 1, 2, 4, 8
GROUND = (36, 70, 30)


class WrapImg(G.Img):
    """Yatayda sarmal tuval: soldan taşan yaprak sağdan girer -> karolar yan yana dikişsiz (aynı sıradaki iç karolar)."""

    def __init__(self, w, h, wrap, wrap_y=False):
        super().__init__(w, h)
        self.wrap = wrap
        self.wrap_y = wrap_y

    def put(self, x, y, c, alpha=255):
        if self.wrap:
            x = round(x) % self.w
        if self.wrap_y:
            y = round(y) % self.h   ## üstten taşan uç alttan girer: karo sıraları arasında "uçsuz" şerit kalmasın
        super().put(x, y, c, alpha)


FILL = [(31, 62, 30), (38, 72, 32), (44, 82, 34)]


def tile(mask, seed):
    rng = random.Random(seed * 7919 + mask * 131)
    side_open = bool(mask & (LEFT | RIGHT))
    img = WrapImg(TILE, TILE, wrap=not side_open, wrap_y=not (mask & (TOP | BOTTOM)))
    # açık kenarlar için girintili sınır (her sütun/satır için rastgele 2-5 px)
    top_edge = [rng.randint(4, 8) for _ in range(TILE)] if mask & TOP else [0] * TILE
    bot_edge = [TILE - rng.randint(2, 4) for _ in range(TILE)] if mask & BOTTOM else [TILE] * TILE
    lft_edge = [rng.randint(1, 4) for _ in range(TILE)] if mask & LEFT else [0] * TILE
    rgt_edge = [TILE - rng.randint(1, 4) for _ in range(TILE)] if mask & RIGHT else [TILE] * TILE

    def inside(x, y):
        return top_edge[x] <= y < bot_edge[x] and lft_edge[y] <= x < rgt_edge[y]

    # koyu dolgu (çalılığın içi): opak, hafif desenli -> içerideki karakter yaprak karanlığına gömülür
    for y in range(TILE):
        for x in range(TILE):
            if inside(x, y):
                img.a[y, x] = (*FILL[rng.randrange(3) if rng.random() < 0.35 else 1], 255)
    # yapraklar: tabanlar karonun HER yüksekliğine dağılır (bant/şerit görünmesin), arkadan öne
    blades = []
    for i in range(30):
        x = rng.uniform(0.0, 16.0)
        base = rng.uniform(2.0, 16.0)
        xi, bi = int(x) % TILE, min(TILE - 1, int(base))
        if not inside(xi, bi):
            continue
        h = rng.uniform(5.0, 11.0)
        if mask & TOP:
            h = min(h, base - top_edge[xi] + rng.uniform(1.0, 4.0))
        lean = rng.uniform(-0.32, 0.32)
        if side_open:
            tip = x + lean * h
            if tip < lft_edge[bi] or tip > rgt_edge[bi] - 1:
                lean = -lean
        blades.append((base, x, max(4.0, h), lean))
    blades.sort(key=lambda q: q[0])
    for base, x, h, lean in blades:
        depth = (base - 2.0) / 14.0
        k = 2 if depth < 0.3 else (1 if depth < 0.65 else 0)
        mystic = rng.random() < 0.5
        ramp = G.shift(G.MYSTIC_LIGHT if mystic else G.GRASS, k)
        tip = rng.choice(G.MYSTIC_TIPS) if mystic and rng.random() < 0.35 else None
        G.blade(img, x, base, int(h), lean, ramp, rng, tip=tip, wide=True)
    return img.image()


def build():
    atlas = Image.new('RGBA', (TILE * 16, TILE * SEEDS), (0, 0, 0, 0))
    for s in range(SEEDS):
        for m in range(16):
            atlas.alpha_composite(tile(m, s), (m * TILE, s * TILE))
    return atlas


def mask_of(cells, x, y):
    m = 0
    if (x, y - 1) not in cells:
        m |= TOP
    if (x, y + 1) not in cells:
        m |= BOTTOM
    if (x - 1, y) not in cells:
        m |= LEFT
    if (x + 1, y) not in cells:
        m |= RIGHT
    return m


def preview(atlas):
    rng = random.Random(3)
    W, H = 22, 12
    m = G.blob_mask(W, H, [(7, 6, 6, 4.5, [(3, 0.12, 0.4)]), (15, 5, 5, 4, [(4, 0.1, 1.0)])])
    cells = {(x, y) for y in range(H) for x in range(W) if m[y, x]}
    bg = Image.new('RGBA', (W * TILE, H * TILE), (126, 176, 84, 255))
    for (x, y) in sorted(cells, key=lambda c: c[1]):
        mk = mask_of(cells, x, y)
        s = rng.randrange(SEEDS)
        bg.alpha_composite(atlas.crop((mk * TILE, s * TILE, mk * TILE + TILE, s * TILE + TILE)), (x * TILE, y * TILE))
    bg.resize((bg.width * 4, bg.height * 4), Image.NEAREST).convert('RGB').save(os.path.join(OUT, 'lol_onizleme.png'))


if __name__ == '__main__':
    a = build()
    a.save(os.path.join(OUT, 'saklanma_lol.png'))
    preview(a)
    print('tamam', a.size)
