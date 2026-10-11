"""SAKLANMA ÇALILIĞI - KÖŞE DIŞI YERLER (2026-10-09, kullanıcı: "saklanma çalıları haritada sadece köşelerde var, köşe olmayan yerlerde de ağaç kenarlarında
v.b. saklanma çalıları olmasını istiyorum. hem bakedde hem tmxde olmalı").

place_brush.py'nin aynı çalılık stili (K1) + aynı kuralları (yol testi `lane_ok`, vadi koruması, özgün nesneler dokunulmaz) kullanır; fark: adaylar köşe/koy değil
  - 'ağaç'  : ağaç öbeklerinin kenarı (ağaç tacına 1-3 hücre, açık yöne bakan; ağaç sayısı çok olan yerler önce),
  - 'duvar' : kaya duvarının DÜZ kenarı (köşe değil; görünür kaya yüzü boyunca uzanan şerit).
KAYNAK CANLI Harita.tmx (mevcut çalılıklar aynen kalır; yenileri eklenir, atlas son katmandan yeniden kurulur). Hiçbir ağaç silinmez (ağaç hücreleri korumalı);
çalılığın altındaki BENİM çalı/çiçek/mantar süslerim kaldırılır (place_brush ile aynı).

Kullanım (proje kökünden):
  python -I tools/hide_bush_proto/add_brush.py [N_AĞAÇ] [N_DUVAR]   -> out/Harita_calilik.tmx + out/yeni_saklanma_calilik.{png,tsx} + out/saklanma_alanlari.json
  python -I tools/hide_bush_proto/place_brush.py --apply <canlı md5> -> canlı Harita.tmx + atlası değiştirir (md5 kapısı)
"""
import json
import math
import os
import random
import re
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import place_brush as PB                       # noqa: E402
from place_brush import (W, H, T, FIRSTGID, LAYER_NAME, STYLE, SEED, SIZES, SIZE_WEIGHTS, OUT, OUT_TMX, LIVE, PNG_NAME, TSX_NAME,   # noqa: E402
                         GB, load, layers, grid, groups_new, patch_general, lane_ok, tree_trunks, clearance, cheb, dil, md5)

GAP = int(os.environ.get('CALILIK_GAP', 11))            # çalılıklar arası en az (hücre)
TREE_LAYERS = ['Shader Eklenecek/Ağaç 0', 'Shader Eklenecek/Ağaç 1', 'Shader Eklenecek/Ağaç 2']


def candidates(B, L, ts_l, cur, rng):
    wall = B['wall']
    tree_any = np.zeros((H, W), bool)
    for k in TREE_LAYERS:
        tree_any |= L[k] != 0
    brush_any = cur != 0
    trunks = tree_trunks(ts_l, L)
    lane_block = B['lane_block'] | trunks
    mx = clearance(wall | lane_block)
    free = B['brush_free'] & ~tree_any & ~dil(brush_any, 1)
    t_dist = cheb(tree_any, 6)
    visible = np.zeros((H, W), bool)
    g21 = L['Orman parçaları/Orman parçaları']
    for yy, xx in zip(*np.nonzero(wall)):
        d = PB.decode(ts_l, int(g21[yy, xx]))
        visible[yy, xx] = bool(d) and not (d[0] == 'Ground_grass.tsx' and d[1] == 212)
    ys_t, xs_t = np.nonzero(tree_any)
    cands = []
    # ---- ağaç kenarı
    for y in range(6, H - 6):
        for x in range(6, W - 6):
            if not free[y, x] or not (1 <= t_dist[y, x] <= 3):
                continue
            near = (np.abs(ys_t - y) <= 5) & (np.abs(xs_t - x) <= 5)
            n = int(near.sum())
            if n < 14:                                   # yalnız ağaç öbekleri (tek ağaç değil)
                continue
            vx = float((x - xs_t[near]).sum()); vy = float((y - ys_t[near]).sum())
            ln = math.hypot(vx, vy)
            if ln < 1e-6:
                continue
            d = (vx / ln, vy / ln)
            cxm, cym = int(round(x + d[0] * 3)), int(round(y + d[1] * 3))
            if not (0 <= cxm < W and 0 <= cym < H) or mx[cym, cxm] < 4.0 or not free[cym, cxm]:
                continue
            area = sum(1 for i in range(-3, 4) for j in range(-3, 4) if free[min(H - 1, max(0, cym + j)), min(W - 1, max(0, cxm + i))])
            if area < 30:
                continue
            cands.append({'x': x, 'y': y, 'px': 1 if d[0] >= 0 else -1, 'py': 1 if d[1] >= 0 else -1, 'run_v': 4, 'run_h': 4, 'free': area,
                          'dir': d, 'kind': 'ağaç', 'score': n * 0.6 + area * 0.4 + rng.random() * 12})
    # ---- düz duvar kenarı (köşe değil)
    for y in range(6, H - 6):
        for x in range(6, W - 6):
            if not free[y, x]:
                continue
            for (ax, ay) in ((1, 0), (-1, 0), (0, 1), (0, -1)):            # duvar yönü
                if not wall[y + ay, x + ax]:
                    continue
                # duvar boyunca (dik eksen) en az 7 hücre görünür kaya yüzü
                px_, py_ = -ay, ax
                run = 0
                for k in range(-6, 7):
                    wx, wy = x + ax + px_ * k, y + ay + py_ * k
                    if 0 <= wx < W and 0 <= wy < H and visible[wy, wx] and not wall[wy - ay, wx - ax]:
                        run += 1
                if run < 9:
                    continue
                # köşe olmasın: şerit boyunca iki uçta da duvar kolu yok
                if any(0 <= x + px_ * k < W and 0 <= y + py_ * k < H and wall[y + py_ * k, x + px_ * k] for k in (-3, -2, 2, 3)):
                    continue
                d = (-float(ax), -float(ay))
                cxm, cym = int(round(x + d[0] * 3)), int(round(y + d[1] * 3))
                if not (0 <= cxm < W and 0 <= cym < H) or mx[cym, cxm] < 4.6 or not free[cym, cxm]:
                    continue
                area = sum(1 for i in range(-3, 4) for j in range(-3, 4) if free[min(H - 1, max(0, cym + j)), min(W - 1, max(0, cxm + i))])
                if area < 30:
                    continue
                cands.append({'x': x, 'y': y, 'px': 1 if d[0] >= 0 else -1, 'py': 1 if d[1] >= 0 else -1, 'run_v': 4, 'run_h': 4, 'free': area,
                              'dir': d, 'kind': 'duvar', 'score': run + area * 0.4 + rng.random() * 12})
                break
    return cands, free, tree_any, lane_block


def main(n_tree, n_wall):
    B = PB.build()
    ts = B['ts']
    LO = B['LO']
    rng = random.Random(SEED + 4242)
    root_l, ts_l = load(LIVE)
    L = {'/'.join(p): grid(l) for p, l in layers(root_l)}
    meta = json.load(open(os.path.join(OUT, 'saklanma_alanlari.json'), encoding='utf-8'))
    old = meta['patches']
    brush_key = next(k for k in L if k.split('/')[-1] == LAYER_NAME)      # kullanıcı katmanı Tiled'da başka gruba taşıyabilir (18:53: 'Orman parçaları' grubu)
    print('çalılık katmanı:', brush_key)
    cur = L[brush_key].copy()
    atlas_old = np.array(Image.open(os.path.join(PB.PROJECT, 'harita', PNG_NAME)).convert('RGBA'))
    cols_old = atlas_old.shape[1] // T

    def old_tile(gid):
        i = int(gid) - FIRSTGID
        r, cc = divmod(i, cols_old)
        return atlas_old[r * T:(r + 1) * T, cc * T:(cc + 1) * T]
    cells_img = {(int(x), int(y)): old_tile(cur[y, x]) for y, x in zip(*np.nonzero(cur))}
    used = cur != 0
    used_ground = np.zeros((H, W), bool)
    for p in old:
        for gx, gy in p['ground_cells']:
            used_ground[gy, gx] = True
    cands, free, tree_any, lane_block = candidates(B, L, ts_l, cur, rng)
    print('aday: ağaç', sum(1 for c in cands if c['kind'] == 'ağaç'), '| duvar', sum(1 for c in cands if c['kind'] == 'duvar'))
    protect = B['protect'] | tree_any
    added = []
    rejects = 0
    want = {'ağaç': n_tree, 'duvar': n_wall}
    for kind in ('ağaç', 'duvar'):
        pool = sorted((c for c in cands if c['kind'] == kind), key=lambda c: -c['score'])
        got = 0
        for c in pool:
            if got >= want[kind]:
                break
            sites = [p['corner'] for p in old] + [p['corner'] for p in added]
            if any(max(abs(c['x'] - sx), abs(c['y'] - sy)) < GAP for sx, sy in sites):
                continue
            r = rng.random(); acc = 0.0; wsize = 'küçük'
            for nm, wgt in SIZE_WEIGHTS:
                acc += wgt
                if r <= acc:
                    wsize = nm
                    break
            order = ['büyük', 'orta', 'küçük']
            p = None
            for size in order[order.index(wsize):]:
                q = patch_general(c, free, B['wall'], random.Random(rng.randrange(1 << 30)), size)
                if q is None or q['mask'].sum() < SIZES[size][2]:
                    continue
                if not lane_ok(lane_block | used_ground, q['ground']):
                    rejects += 1
                    continue
                p = q; p['size'] = size
                break
            if p is None:
                continue
            canvas = [(p['x0'] + i, p['y0'] + j) for j in range(p['h']) for i in range(p['w'])]
            if any(not (0 <= cx < W and 0 <= cy < H) or used[cy, cx] for cx, cy in canvas):
                continue
            img = np.array(GB.Brush(STYLE, p['mask'], SEED + 9000 + len(added) * 17, pad_top=0, pad_x=0).render())
            here = {}
            bad = False
            for j in range(p['h']):
                for i in range(p['w']):
                    t = img[j * T:(j + 1) * T, i * T:(i + 1) * T]
                    if t[..., 3].max() == 0:
                        continue
                    cx, cy = p['x0'] + i, p['y0'] + j
                    if protect[cy, cx]:
                        bad = True
                        break
                    here[(cx, cy)] = t
                if bad:
                    break
            if bad or not here:
                continue
            for (cx, cy), t in here.items():
                cells_img[(cx, cy)] = t
                used[cy, cx] = True
            for gx, gy in p['ground']:
                used_ground[gy, gx] = True
            mk = np.nonzero(p['mask'])
            added.append({'corner': [c['x'], c['y']], 'kind': kind, 'size': p['size'], 'dir': [round(c['dir'][0], 3), round(c['dir'][1], 3)],
                          'canvas': [p['x0'], p['y0'], p['w'], p['h']], 'ground_cells': [list(g) for g in p['ground']],
                          'ground_px_bbox': [int(p['x0'] * T + mk[1].min()), int(p['y0'] * T + mk[0].min()),
                                             int(p['x0'] * T + mk[1].max()), int(p['y0'] * T + mk[0].max())], 'tiles': len(here)})
            got += 1
    print('eklenen:', len(added), [(a['kind'], a['size'], a['corner']) for a in added], '| yol testinden dönen:', rejects)
    # yeni çalılıkların altındaki BENİM süslerim (canlı katmanda olup özgünde olmayan damgalar)
    newly = np.zeros((H, W), bool)
    for a in added:
        x0, y0, w, h = a['canvas']
        for (cx, cy) in cells_img:
            if x0 <= cx < x0 + w and y0 <= cy < y0 + h:
                newly[cy, cx] = True
    targets = ['Shader Eklenecek/Ağaç 0', 'Shader Eklenecek/Ağaç 1', 'Shader Eklenecek/Ağaç 2', 'Shader Eklenecek/Çalılar1', 'Shader Eklenecek/Çalılar',
               'Shader Eklenecek/Animasyonsuz çalılar', 'Shader Eklenecek/Çiçekler 1']
    newL = {k: L[k].copy() for k in targets}
    removed = {}
    for k in targets:
        n = 0
        for grp in groups_new(ts_l, L[k], LO[k]):
            if any(newly[y, x] for (y, x) in grp):
                for (y, x) in grp:
                    newL[k][y, x] = 0
                n += 1
        removed[k.split('/')[1]] = n
    print('kaldırılan kendi süslerim (damga):', removed)
    assert removed['Ağaç 0'] == removed['Ağaç 1'] == removed['Ağaç 2'] == 0, 'ağaç silinmemeli'
    tiles, index, layer_new = [], {}, np.zeros((H, W), np.int64)
    for (cx, cy) in sorted(cells_img, key=lambda q: (q[1], q[0])):
        t = cells_img[(cx, cy)]
        key = t.tobytes()
        if key not in index:
            index[key] = len(tiles)
            tiles.append(t)
        layer_new[cy, cx] = FIRSTGID + index[key]
    cols = 16
    rows = (len(tiles) + cols - 1) // cols
    atlas = np.zeros((rows * T, cols * T, 4), np.uint8)
    for i, t in enumerate(tiles):
        r, cc = divmod(i, cols)
        atlas[r * T:(r + 1) * T, cc * T:(cc + 1) * T] = t
    txt = open(LIVE, encoding='utf-8', newline='').read()

    def fmt(g):
        return '\r\n' + ',\r\n'.join(','.join(str(int(v)) for v in g[y]) for y in range(H)) + '\r\n'

    def span(t, name):
        mm = re.search(r'<layer id="\d+" name="' + re.escape(name) + r'"[^>]*>\s*<data encoding="csv">', t)
        assert mm, name
        s = mm.end()
        return s, t.index('</data>', s)
    for k in targets:
        s, e = span(txt, k.split('/')[1])
        assert txt[s:e] == fmt(L[k]), 'CSV biçimi tutmuyor: ' + k
        txt = txt[:s] + fmt(newL[k]) + txt[e:]
    s, e = span(txt, LAYER_NAME)
    assert txt[s:e] == fmt(L[brush_key])
    txt = txt[:s] + fmt(layer_new) + txt[e:]
    open(OUT_TMX, 'w', encoding='utf-8', newline='').write(txt)
    Image.fromarray(atlas, 'RGBA').save(os.path.join(OUT, 'yeni_' + PNG_NAME))
    tsx = ('<?xml version="1.0" encoding="UTF-8"?>\r\n'
           f'<tileset version="1.10" tiledversion="1.12.2" name="saklanma_calilik" tilewidth="16" tileheight="16" tilecount="{len(tiles)}" columns="{cols}">\r\n'
           f' <image source="{PNG_NAME}" width="{cols * T}" height="{rows * T}"/>\r\n'
           '</tileset>\r\n')
    open(os.path.join(OUT, 'yeni_' + TSX_NAME), 'w', encoding='utf-8', newline='').write(tsx)
    meta['patches'] = old + added
    json.dump(meta, open(os.path.join(OUT, 'saklanma_alanlari.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print('yazıldı:', OUT_TMX, '| atlas', len(tiles), 'karo | canlı md5', md5(LIVE))
    return added


if __name__ == '__main__':
    nt = int(sys.argv[1]) if len(sys.argv) > 1 else 8
    nw = int(sys.argv[2]) if len(sys.argv) > 2 else 4
    main(nt, nw)
