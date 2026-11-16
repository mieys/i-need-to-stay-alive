"""HARİTA CİLA DENETİMİ - analiz (2026-11-15). tools/harita_cila/denetim.gd'nin dökümünü okur, kusur adaylarını yazar.
Kullanım: python -I tools/harita_cila/analiz.py [id ...]   (varsayılan: out/ içindeki her döküm)
Bölümler: ulaşılabilirlik (doğuştan 4-komşu taşma), kapalı açık cepler, ulaşılamayan etkileşim düğümleri, açık arazide tek başına görünmez engel
(orman/duvar katmanı, nesne kategorisi yok), katı görünen ama çarpışmasız nesneler (oyuncunun basabildiği yerde), katman tablosu.
"""
import json
import os
import sys
from collections import deque

import numpy as np

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'out')
B_WALL, B_FOREST, B_ICE = 1, 2, 4
CAT = {'water': 8, 'trees': 16, 'props': 32, 'houses': 64, 'mines': 128, 'enemy_base': 256}
NODE_SKIP = {'light'}


def load(mid):
    meta = json.load(open(os.path.join(OUT, 'meta_%s.json' % mid), encoding='utf-8'))
    x0, y0, w, h = meta['rect']
    g = np.fromfile(os.path.join(OUT, 'grid_%s.bin' % mid), dtype='<u2').reshape(h, w)
    return meta, g


def flood(free, start):
    h, w = free.shape
    seen = np.zeros_like(free, bool)
    sy, sx = start
    if not (0 <= sy < h and 0 <= sx < w) or not free[sy, sx]:
        ## doğuş engelde: en yakın açık hücre
        ys, xs = np.nonzero(free)
        k = int(np.argmin((ys - sy) ** 2 + (xs - sx) ** 2))
        sy, sx = int(ys[k]), int(xs[k])
    q = deque([(sy, sx)])
    seen[sy, sx] = True
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and free[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                q.append((ny, nx))
    return seen


def components(mask):
    h, w = mask.shape
    lab = np.zeros((h, w), np.int32)
    out = []
    for y, x in zip(*np.nonzero(mask)):
        if lab[y, x]:
            continue
        n = len(out) + 1
        lab[y, x] = n
        q = deque([(y, x)])
        cells = []
        while q:
            cy, cx = q.popleft()
            cells.append((cy, cx))
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = cy + dy, cx + dx
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not lab[ny, nx]:
                    lab[ny, nx] = n
                    q.append((ny, nx))
        out.append(cells)
    return lab, out


def dilate(m, r=1):
    o = m.copy()
    for _ in range(r):
        n = o.copy()
        n[1:, :] |= o[:-1, :]
        n[:-1, :] |= o[1:, :]
        n[:, 1:] |= o[:, :-1]
        n[:, :-1] |= o[:, 1:]
        o = n
    return o


def analyse(mid):
    meta, g = load(mid)
    x0, y0, w, h = meta['rect']
    ox, oy, sc = meta['forest_xform']

    def cell_of(px, py):
        return int((py - oy) // (16 * sc)) - y0, int((px - ox) // (16 * sc)) - x0

    blocked = (g & B_WALL) > 0
    free = ~blocked
    sp = meta['spawn'] or meta['player']
    reach = flood(free, cell_of(*sp))
    if reach.sum() < 0.3 * free.sum():
        ## doğuş bir iç mekânda / kapalı yerde (ana harita: açılış evi) -> en büyük açık bileşen
        _, cc = components(free)
        reach = np.zeros_like(free)
        for p in max(cc, key=len):
            reach[p] = True
    px0, py0, pw, ph = meta['play']
    play = np.zeros_like(blocked)
    play[max(0, py0 - y0):py0 - y0 + ph, max(0, px0 - x0):px0 - x0 + pw] = True
    print('=' * 100)
    print('%s  ızgara %dx%d  oyun alanı %s  engel %d  ulaşılabilir %d (oyun alanının %%%.1f)' % (
        mid, w, h, meta['play'], int(blocked.sum()), int(reach.sum()), 100.0 * (reach & play).sum() / max(1, play.sum())))
    ## kapalı açık cepler (oyun alanında, engel değil, ulaşılamıyor)
    _, comps = components(free & ~reach & play)
    comps.sort(key=len, reverse=True)
    big = [c for c in comps if len(c) >= 3]
    print('kapalı açık cep: %d (>=3 hücre: %d) en büyükler: %s' % (len(comps), len(big), [
        (len(c), min(p[1] for p in c) + x0, min(p[0] for p in c) + y0) for c in big[:8]]))
    ## görünmez engel kırıntısı: kategori bitsiz engel, küçük bileşen, çevresi ulaşılabilir
    inv = blocked & ((g & sum(CAT.values())) == 0)
    _, icomps = components(inv)
    specks = []
    for c in icomps:
        if len(c) > 6:
            continue
        m = np.zeros_like(inv)
        for p in c:
            m[p] = True
        ring = dilate(m) & ~m
        if ring.sum() and (reach[ring].mean() >= 0.75):
            specks.append((len(c), c[0][1] + x0, c[0][0] + y0))
    print('açık arazide görünmez engel kırıntısı (<=6 hücre, çevresi %%75+ ulaşılabilir): %d %s' % (len(specks), specks[:20]))
    ## düğümler: ulaşılabilir hücreye uzaklık
    rd = reach
    bad = {}
    for n in meta['nodes']:
        gs = [x for x in n['g'] if x not in NODE_SKIP]
        if not gs:
            continue
        cy, cx = cell_of(*n['p'])
        if not (0 <= cy < h and 0 <= cx < w):
            bad.setdefault('harita dışı', []).append((n['n'], gs[0], n['p']))
            continue
        y1, y2, x1, x2 = max(0, cy - 2), min(h, cy + 3), max(0, cx - 2), min(w, cx + 3)
        if not rd[y1:y2, x1:x2].any():
            bad.setdefault(gs[0], []).append((n['n'], n['s'], [round(v) for v in n['p']], cx + x0, cy + y0))
    print('ulaşılamayan düğüm (2 hücre içinde ulaşılabilir hücre yok): %s' % (
        {k: (len(v), v[:4]) for k, v in bad.items()} if bad else 'yok'))
    groups = {}
    for n in meta['nodes']:
        for x in n['g']:
            groups[x] = groups.get(x, 0) + 1
    print('gruplar:', dict(sorted(groups.items(), key=lambda kv: -kv[1])[:40]))
    ## katmanlar
    print('katmanlar (yol | hücre | z | ysort | çarpışma | katı nesne):')
    for L in meta['layers']:
        walk = 0
        for (sx, sy, sw, sh) in L['samples']:
            cy, cx = cell_of(sx, sy - 15)
            if 0 <= cy < h and 0 <= cx < w and reach[cy, cx] and not blocked[cy, cx]:
                walk += 1
        print('  %-48s %6d z%-2d %s %s katı=%-4d %s' % (L['path'][:48], L['cells'], L['z'], 'Y' if L['ysort'] else '-',
                                                     'Ç' if L['covered'] else '-', L['solid'],
                                                     ('ÜSTÜNE BASILIR: %d' % walk) if (walk and not L['covered']) else ''))
    return meta, g, reach


if __name__ == '__main__':
    ids = sys.argv[1:] or sorted(f[5:-5] for f in os.listdir(OUT) if f.startswith('meta_') and f.endswith('.json'))
    for i in ids:
        analyse(i)
