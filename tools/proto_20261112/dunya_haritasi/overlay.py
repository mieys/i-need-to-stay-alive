"""DÜNYA HARİTASI prototipi (2026-11-12, oyuna bağlı DEĞİL) - 3. adım: compose.py çıktısından vurgu katmanları.

  cerceve_<id>.png : bölge oyun alanının 1 piksellik altın kenarı + dışında 1 piksel koyu kontur (dünya pikseli = 1 hücre)
  karart_<id>.png  : seçili bölge dışını karartan katman (DEEP, %45)
  dunya_yol.png    : D için bölgeleri bağlayan toprak yol (renk ana haritanın yol pikselleri), yalnız bölgelerin dışında
  python -I tools/proto_20261112/dunya_haritasi/overlay.py
"""
import json
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'out')
GOLD = (240, 192, 112, 255)   ## HudTheme.ACCENT
DARK = (32, 21, 13, 255)      ## HudTheme.OUTLINE
DEEP = (20, 14, 9)            ## HudTheme.DEEP
ROAD = (184, 150, 102)
ROAD_EDGE = (92, 70, 44)
ORDER = ['ana', 'bataklik', 'batik_nekropol', 'lagim_agi', 'col']


def shift_or(m):
    return np.roll(m, 1, 0) | np.roll(m, -1, 0) | np.roll(m, 1, 1) | np.roll(m, -1, 1)


def fill_blob(m, r=7):
    """Zindan planı: koridorlar arası boşlukları kapat (kapanış) + delikleri doldur -> tek organik leke."""
    d = m.copy()
    for _ in range(r):
        d = d | shift_or(d)
    outside = np.zeros_like(d)
    outside[0, :] = ~d[0, :]
    outside[-1, :] = ~d[-1, :]
    outside[:, 0] |= ~d[:, 0]
    outside[:, -1] |= ~d[:, -1]
    while True:
        nxt = (outside | shift_or(outside)) & ~d
        if (nxt == outside).all():
            break
        outside = nxt
    d = ~outside
    for _ in range(r):
        d = d & ~shift_or(~d)
    return d


def main():
    meta = json.load(open(os.path.join(OUT, 'bolgeler.json'), encoding='utf-8'))
    W, H = meta['size']
    masks = {}
    for r in meta['regions']:
        rid = r['id']
        m = np.asarray(Image.open(os.path.join(OUT, 'bolge_%s.png' % rid))) > 127
        if rid in ('batik_nekropol', 'lagim_agi'):
            m = fill_blob(m)
        masks[rid] = m
        edge = m & shift_or(~m)
        ring = ~m & shift_or(m)
        o = np.zeros((H, W, 4), np.uint8)
        o[edge] = GOLD
        o[ring] = DARK
        Image.fromarray(o, 'RGBA').save(os.path.join(OUT, 'cerceve_%s.png' % rid))
        k = np.zeros((H, W, 4), np.uint8)
        k[..., :3] = DEEP
        k[..., 3] = np.where(m, 0, 115)
        Image.fromarray(k, 'RGBA').save(os.path.join(OUT, 'karart_%s.png' % rid))

    ## Yol: merkezler arası yumuşak eğri (ikinci derece Bezier), bölgelerin içinde çizilmez
    world = np.asarray(Image.open(os.path.join(OUT, 'dunya.png')).convert('RGBA')).copy()
    inside = np.zeros((H, W), bool)
    for m in masks.values():
        inside |= m
    road = np.zeros((H, W), bool)
    cen = {r['id']: np.array(r['center']) for r in meta['regions']}
    for a, b in zip(ORDER, ORDER[1:]):
        p0, p2 = cen[a], cen[b]
        mid = (p0 + p2) / 2
        n = np.array([-(p2 - p0)[1], (p2 - p0)[0]])
        n = n / (np.linalg.norm(n) + 1e-6)
        p1 = mid + n * 26
        for t in np.linspace(0, 1, 900):
            p = (1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t * t * p2
            x, y = int(round(p[0])), int(round(p[1]))
            road[y - 1:y + 2, x - 1:x + 2] = True
    road &= ~inside
    edge = ~road & shift_or(road) & ~inside
    world[edge, :3] = ROAD_EDGE
    world[road, :3] = ROAD
    Image.fromarray(world, 'RGBA').save(os.path.join(OUT, 'dunya_yol.png'))
    print('vurgu + yol hazır')


if __name__ == '__main__':
    main()
