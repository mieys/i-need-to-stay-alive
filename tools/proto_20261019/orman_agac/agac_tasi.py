"""ORMAN KATMANLARINDAKİ TEK BAŞINA AĞAÇLAR -> "Shader Eklenecek/Ağaç 0/1/2" (2026-10-19, madde 284 (c) devamı).
Sorun: orman grubu katmanları ("Orman parçaları/..." + dış çerçeve "Dış orman 1-4") derinliğe (depth_occluders.gd ön kopyaları) ve sallanmaya
(tree_sway.gd) girmiyor - arkalarından geçen karakter hep üstte çizilir. Ağaç katmanına taşınan ağaç ikisini de kendiliğinden alır.

Nesne = atlas komşuluğu (depth_occluders.gd object_bases / tree_sway.gd ile AYNI kural: sağdaki hücre atlasta sağdaki karo (yatay çevrikte soldaki),
alttaki hücre atlasta alttaki karo; aynı karo seti + aynı çevirme). Kök = nesnenin en alt opak satırı (alfa > 0,4).
ADAY: ağaç karo setinden (AGAC_TS), en az 2 satır + 24 px boy, ve ARKASINA GEÇİLEBİLEN: ayak noktası kökün üstünde, yürünebilir bir hücrede
(orman duvarı hücresi değil, Su/Su değil, bina duvarı değil, oyun alanında 16 px içeride) duran karakterin gövde dikdörtgeni (grass_sway/depth ile aynı:
yarım genişlik 9,35, boy 28,9) ağacın opak piksellerinden en az MIN_OVERLAP kadarını örtüyor. Arkasına geçilemeyen ağacı taşımak görünüşte hiçbir şey
değiştirmez (yalnız sallanır), o yüzden onlar listeye girmez.
Hedef katman: Ağaç 0 -> 1 -> 2, hedef hücreler boş olan ilk katman; aynı kaynakta üst üste binen iki aday çizim sırasını korur (sonraki kaynak katmandaki
daha yüksek Ağaç katmanına), mevcut bir Ağaç ağacıyla piksel örtüşmesi varsa taşınan onun ALTINDA kalır (bugün de altında).

Kullanım (proje kökünden):
  python -I tools/proto_20261019/orman_agac/agac_tasi.py              -> out/orman_agac/: adaylar.json, genel.png (harita), yakin_*.png (yakın çekim)
  python -I tools/proto_20261019/orman_agac/agac_tasi.py --apply <md5> -> Harita.tmx (md5 kapısı; yedek harita/yedek/Harita_2026-10-19_oncesi_agac-tasima.tmx.bak)
Okuma: tools/dis_cerceve/ring_write.read_back (sonsuz TMX); yazma: yalnız değişen katmanların <data> bloğu, Tiled biçimi (place_lol_ek.py ile aynı).
"""
import hashlib
import json
import os
import re
import shutil
import sys
import xml.etree.ElementTree as ET

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
sys.path.insert(0, os.path.join(PROJECT, 'tools', 'dis_cerceve'))
sys.path.insert(0, os.path.join(PROJECT, 'tools', 'forest_decor'))
from ring_core import X0, Y0, W2, H2, PLAY, render_region  # noqa: E402
from ring_write import read_back  # noqa: E402
import tmxlib  # noqa: E402

TMX = os.path.join(PROJECT, 'harita', 'Harita.tmx')
YEDEK = os.path.join(PROJECT, 'harita', 'yedek')
OUT = os.path.join(HERE, '..', 'out', 'orman_agac')
T = 16
MAP_OFS = (-2, 21)              ## main.tscn Harita konumu (dünya = yerel + ofset)
FEET = 15.0 * 0.85              ## depth_occluders FEET_OFFSET (oyuncu konumu -> ayak)
HALF_W = 11.0 * 0.85
BODY_H = 34.0 * 0.85
EDGE_INSET = 16.0               ## player.gd MAP_EDGE_INSET
ALPHA = int(0.4 * 255)
MIN_OVERLAP = 12                ## gövde dikdörtgeninde örtülmesi gereken en az opak piksel (görünür bir "üstte çizilme")
MIN_ROWS, MIN_H = 2, 24
STEP = 3                        ## ayak noktası örnekleme adımı (px)
SOURCES = [
    'Orman parçaları/orman parçaları -1', 'Orman parçaları/Orman parçaları', 'Orman parçaları/Orman parçaları 2',
    'Orman parçaları/Orman parçaları 3', 'Orman parçaları/Orman parçaları 4',
    'Orman parçaları/Dış orman 1', 'Orman parçaları/Dış orman 2', 'Orman parçaları/Dış orman 3', 'Orman parçaları/Dış orman 4',
]
TARGETS = ['Shader Eklenecek/Ağaç 0', 'Shader Eklenecek/Ağaç 1', 'Shader Eklenecek/Ağaç 2']
AGAC_TS = {'sade ağaç ve taş.tsx', 'Objects.tsx', 'sadece_agac.tsx', 'sadece agac golgeli.tsx', 'bataklık spritesheet.tsx'}
FOREST = 'Orman parçaları/Orman parçaları'
BLOCK_LAYERS = ['Su/Su', 'ev/Blacksmith', 'ev/blacksmith kapı', 'ev/Ev', 'ev/ev kapı']
FLIP = 0xE0000000


def md5(p):
    return hashlib.md5(open(p, 'rb').read()).hexdigest()


class Atlas:
    """gid -> (karo seti adı, atlas x, atlas y, yatay çevrik) + karo görüntüsü (tmxlib, çevirmeli)."""

    def __init__(self, root, ts):
        self.ts = ts
        self.sets = []
        for e in root.findall('tileset'):
            p = os.path.join(PROJECT, 'harita', e.get('source'))
            if not os.path.exists(p):
                continue
            try:
                cols = int(ET.parse(p).getroot().get('columns'))
            except Exception:
                continue
            self.sets.append((int(e.get('firstgid')), e.get('source'), cols))
        self.sets.sort()

    def info(self, gid):
        g = gid & ~FLIP & 0xFFFFFFFF
        best = None
        for s in self.sets:
            if s[0] <= g:
                best = s
        if best is None:
            return None
        i = g - best[0]
        return best[1], i % best[2], i // best[2], bool(gid & 0x80000000), bool(gid & 0x40000000)

    def alpha(self, gid):
        t = self.ts.tile(int(gid))
        if t is None:
            return np.zeros((T, T), bool)
        return np.array(t)[:, :, 3] > ALPHA


def find_objects(grid, atlas):
    """grid: (H2,W2) gid ızgarası -> [ {cells:[(x,y) mutlak], ...} ] atlas komşuluğuyla."""
    ys, xs = np.nonzero(grid)
    cells = {(int(x) + X0, int(y) + Y0): int(grid[y, x]) for y, x in zip(ys, xs)}
    inf = {c: atlas.info(g) for c, g in cells.items()}
    parent = {c: c for c in cells}

    def find(c):
        while parent[c] != c:
            parent[c] = parent[parent[c]]
            c = parent[c]
        return c

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra
    for (x, y), a in inf.items():
        if a is None:
            continue
        r = inf.get((x + 1, y))
        if r and r[0] == a[0] and r[3] == a[3] and r[4] == a[4] and r[2] == a[2] and r[1] == a[1] + (-1 if a[3] else 1):
            union((x, y), (x + 1, y))
        d = inf.get((x, y + 1))
        if d and d[0] == a[0] and d[3] == a[3] and d[4] == a[4] and d[1] == a[1] and d[2] == a[2] + 1:
            union((x, y), (x, y + 1))
    groups = {}
    for c in cells:
        groups.setdefault(find(c), []).append(c)
    out = []
    for cs in groups.values():
        out.append({'cells': sorted(cs), 'gids': {c: cells[c] for c in cs}, 'ts': inf[cs[0]][0] if inf[cs[0]] else None})
    return out


def object_mask(obj, atlas):
    xs = [c[0] for c in obj['cells']]
    ys = [c[1] for c in obj['cells']]
    cx0, cy0, cx1, cy1 = min(xs), min(ys), max(xs) + 1, max(ys) + 1
    m = np.zeros(((cy1 - cy0) * T, (cx1 - cx0) * T), bool)
    for (x, y), g in obj['gids'].items():
        m[(y - cy0) * T:(y - cy0 + 1) * T, (x - cx0) * T:(x - cx0 + 1) * T] = atlas.alpha(g)
    return m, cx0, cy0


def main():
    os.makedirs(OUT, exist_ok=True)
    g = read_back(TMX)
    root, ts = tmxlib.load(TMX)
    atlas = Atlas(root, ts)
    forest = g[FOREST] != 0
    block = forest.copy()
    for k in BLOCK_LAYERS:
        block |= g[k] != 0

    def walkable(lx, ly):
        """lx, ly = harita-yerel ayak noktası (px)."""
        px, py = lx, ly - FEET                                ## oyuncu konumu, harita-yerel (oyun dikdörtgeni de Harita ofsetiyle kaymış: yerel 0..4096)
        if not (EDGE_INSET <= px <= PLAY * T - EDGE_INSET and EDGE_INSET <= py <= PLAY * T - EDGE_INSET):
            return False
        cx, cy = int(lx // T), int(ly // T)
        if not (X0 <= cx < X0 + W2 and Y0 <= cy < Y0 + H2):
            return False
        return not block[cy - Y0, cx - X0]

    cands = []
    stats = {}
    for li, src in enumerate(SOURCES):
        objs = find_objects(g[src], atlas)
        n_tree = 0
        for o in objs:
            if o['ts'] not in AGAC_TS:
                continue
            m, cx0, cy0 = object_mask(o, atlas)
            rows = np.nonzero(m.any(axis=1))[0]
            cols = np.nonzero(m.any(axis=0))[0]
            if len(rows) == 0:
                continue
            nrows = len(set(c[1] for c in o['cells']))
            top, bot = int(rows[0]), int(rows[-1])
            if nrows < MIN_ROWS or bot - top + 1 < MIN_H:
                continue
            n_tree += 1
            root_y = cy0 * T + bot + 1                         ## harita-yerel kök y
            ox0, ox1 = cx0 * T + int(cols[0]), cx0 * T + int(cols[-1]) + 1
            oy0 = cy0 * T + top
            ## arkasına geçilebilir mi: ayak kökün üstünde, gövde opak pikselleri örtüyor
            integ = np.pad(m.astype(np.int32).cumsum(0).cumsum(1), ((1, 0), (1, 0)))
            H, W = m.shape
            reach = 0
            best = 0
            for fy in range(oy0 + 4, root_y, STEP):
                for fx in range(ox0 - int(HALF_W), ox1 + int(HALF_W) + 1, STEP):
                    x0 = int(max(0, fx - HALF_W - cx0 * T)); x1 = int(min(W, fx + HALF_W - cx0 * T))
                    y0 = int(max(0, fy - BODY_H - cy0 * T)); y1 = int(min(H, fy - cy0 * T))
                    if x1 <= x0 or y1 <= y0:
                        continue
                    ov = integ[y1, x1] - integ[y0, x1] - integ[y1, x0] + integ[y0, x0]
                    if ov >= MIN_OVERLAP and walkable(fx, fy):
                        reach += 1
                        best = max(best, int(ov))
            in_play = 0 <= (ox0 + ox1) // 2 // T < PLAY and 0 <= root_y // T < PLAY
            ## orman duvarına bağlı mı (ayak izinin 1 hücre çevresinde duvar hücresi)
            near_wall = 0
            for (x, y) in o['cells']:
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        xx, yy = x + dx, y + dy
                        if X0 <= xx < X0 + W2 and Y0 <= yy < Y0 + H2 and forest[yy - Y0, xx - X0]:
                            near_wall += 1
            if reach == 0:
                continue
            cands.append({
                'src': src, 'src_i': li, 'ts': o['ts'], 'cells': [list(c) for c in o['cells']],
                'gids': {'%d,%d' % c: v for c, v in o['gids'].items()},
                'bbox_px': [ox0, oy0, ox1, root_y], 'root_y': root_y, 'reach': reach, 'max_overlap': best,
                'in_play': bool(in_play), 'wall_touch': near_wall,
                'world': [(ox0 + ox1) // 2 + MAP_OFS[0], root_y + MAP_OFS[1]],
            })
        stats[src] = {'nesne': len(objs), 'agac': n_tree}
    ## hedef katman seçimi
    occ = {t: (g[t] != 0).copy() for t in TARGETS}
    placed = []                                               ## (aday, hedef indeks)
    cands.sort(key=lambda c: (c['src_i'], c['root_y'], c['bbox_px'][0]))
    for c in cands:
        cs = [tuple(v) for v in c['cells']]
        lo = 0
        for p, ti in placed:                                   ## önceki kaynak katmandaki örtüşen aday -> üstte kalmalı
            if p['src_i'] < c['src_i'] and boxes_overlap(p['bbox_px'], c['bbox_px']):
                lo = max(lo, ti + 1)
        hi = len(TARGETS) - 1
        for ti, t in enumerate(TARGETS):                       ## mevcut Ağaç ağacıyla örtüşme -> taşınan onun altında kalsın
            if overlap_cells(g[t], c['bbox_px']):
                hi = min(hi, ti - 1) if ti > 0 else hi
        chosen = None
        for ti in range(lo, len(TARGETS)):
            t = TARGETS[ti]
            if all(not occ[t][y - Y0, x - X0] for x, y in cs):
                chosen = ti
                break
        c['target'] = TARGETS[chosen] if chosen is not None else None
        c['order_warn'] = chosen is not None and chosen > hi
        if chosen is not None:
            for x, y in cs:
                occ[TARGETS[chosen]][y - Y0, x - X0] = True
            placed.append((c, chosen))
    for i, c in enumerate(cands):
        c['id'] = i + 1
    json.dump({'stats': stats, 'adaylar': cands}, open(os.path.join(OUT, 'adaylar.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print('katman istatistik (atlas nesnesi / ağaç boyunda):')
    for k, v in stats.items():
        print('  %-40s %6d %5d' % (k, v['nesne'], v['agac']))
    print('ADAY (arkasına geçilebilen) %d:' % len(cands))
    by = {}
    for c in cands:
        by.setdefault(c['src'], []).append(c)
    for k, v in by.items():
        print('  %-40s %3d  oyun alanı %d / halka %d' % (k, len(v), sum(c['in_play'] for c in v), sum(not c['in_play'] for c in v)))
    for c in cands:
        print('  #%-3d %-28s %-24s dünya(%5d,%5d) hücre %3d erişim %4d örtü %4d duvar %2d -> %s%s' % (
            c['id'], c['src'].split('/')[-1], c['ts'], c['world'][0], c['world'][1], len(c['cells']), c['reach'], c['max_overlap'], c['wall_touch'],
            c['target'], ' SIRA!' if c['order_warn'] else ''))
    preview(g, root, ts, cands)
    if '--apply' in sys.argv:
        apply(cands, sys.argv[sys.argv.index('--apply') + 1])


def boxes_overlap(a, b):
    return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]


def overlap_cells(grid, box):
    x0, y0, x1, y1 = box[0] // T, box[1] // T, (box[2] - 1) // T + 1, (box[3] - 1) // T + 1
    sub = grid[max(0, y0 - Y0):max(0, y1 - Y0), max(0, x0 - X0):max(0, x1 - X0)]
    return bool(np.count_nonzero(sub))


def preview(g, root, ts, cands):
    order = list(g.keys())
    vis, opac = {}, {}
    for p, el in tmxlib.layers(root):
        k = '/'.join(p)
        vis[k] = el.get('visible', '1') != '0'
        opac[k] = float(el.get('opacity', '1'))
    ## genel harita: oyun alanı + 6 hücre halka, 1 hücre = 3 px, adaylar renkli kutu
    S = 3
    E = 6
    reg = (-E, -E, PLAY + E, PLAY + E)
    big = render_region(ts, g, order, vis, opac, reg)
    small = big.resize(((reg[2] - reg[0]) * S, (reg[3] - reg[1]) * S), Image.BOX).convert('RGB')
    d = ImageDraw.Draw(small)
    for c in cands:
        x0, y0, x1, y1 = c['bbox_px']
        col = (255, 60, 40) if c['in_play'] else (255, 220, 40)
        d.rectangle([(x0 / T - reg[0]) * S, (y0 / T - reg[1]) * S, (x1 / T - reg[0]) * S, (y1 / T - reg[1]) * S], outline=col, width=2)
    d.rectangle([(0 - reg[0]) * S, (0 - reg[1]) * S, (PLAY - reg[0]) * S, (PLAY - reg[1]) * S], outline=(255, 255, 255), width=1)
    small.save(os.path.join(OUT, 'genel.png'))
    big.close()
    ## tüm adaylar tek sayfada: kutu + 1 hücre pay, 2 px/px, numara üstte (çevre karartılmış -> nesne seçilsin)
    tiles = []
    for c in cands:
        x0, y0, x1, y1 = c['bbox_px']
        rx0, ry0, rx1, ry1 = x0 // T - 1, y0 // T - 1, (x1 - 1) // T + 2, (y1 - 1) // T + 2
        im = render_region(ts, g, order, vis, opac, (rx0, ry0, rx1, ry1)).convert('RGB')
        im = im.resize((im.width * 2, im.height * 2), Image.NEAREST)
        d = ImageDraw.Draw(im)
        d.rectangle([(x0 - rx0 * T) * 2 - 1, (y0 - ry0 * T) * 2 - 1, (x1 - rx0 * T) * 2, (y1 - ry0 * T) * 2], outline=(255, 60, 40), width=1)
        tiles.append((c['id'], im))
    if tiles:
        cw = max(t[1].width for t in tiles) + 6
        ch = max(t[1].height for t in tiles) + 20
        ncol = 9
        sheet = Image.new('RGB', (cw * ncol, ch * ((len(tiles) + ncol - 1) // ncol)), (24, 22, 28))
        d = ImageDraw.Draw(sheet)
        for i, (cid, im) in enumerate(tiles):
            ox, oy = (i % ncol) * cw + 3, (i // ncol) * ch + 16
            sheet.paste(im, (ox, oy))
            d.text((ox, oy - 14), '#%d' % cid, fill=(255, 236, 160))
        sheet.save(os.path.join(OUT, 'adaylar_sayfa.png'))
    ## yakın çekimler: en çok erişilen 8 aday (2 px/px), kutu + numara
    top = sorted(cands, key=lambda c: -c['reach'])[:8]
    for c in top:
        x0, y0, x1, y1 = c['bbox_px']
        rx0, ry0, rx1, ry1 = x0 // T - 6, y0 // T - 4, (x1 - 1) // T + 7, (y1 - 1) // T + 5
        im = render_region(ts, g, order, vis, opac, (rx0, ry0, rx1, ry1)).convert('RGB')
        im = im.resize((im.width * 2, im.height * 2), Image.NEAREST)
        d = ImageDraw.Draw(im)
        d.rectangle([(x0 - rx0 * T) * 2, (y0 - ry0 * T) * 2, (x1 - rx0 * T) * 2, (y1 - ry0 * T) * 2], outline=(255, 60, 40), width=2)
        d.text((4, 4), '#%d %s' % (c['id'], c['src'].split('/')[-1]), fill=(255, 255, 255))
        im.save(os.path.join(OUT, 'yakin_%02d.png' % c['id']))


def layer_block(text, name):
    m = re.search(r'(<layer id="\d+" name="%s"[^>]*>\r?\n   <data encoding="csv">\r?\n)(.*?)(\r?\n   </data>)' % re.escape(name), text, re.S)
    assert m, ('katman yok', name)
    return m


def write_chunks(grid, nl):
    parts = []
    for cy in range(Y0, Y0 + H2, 16):
        for cx in range(X0, X0 + W2, 16):
            sub = grid[cy - Y0:cy - Y0 + 16, cx - X0:cx - X0 + 16]
            if not sub.any():
                continue
            rows = [','.join(str(int(v)) for v in r) for r in sub]
            parts.append('    <chunk x="%d" y="%d" width="16" height="16">%s%s%s</chunk>' % (cx, cy, nl, (',' + nl).join(rows), nl))
    return nl.join(parts)


def apply(cands, want):
    have = md5(TMX)
    if have != want:
        print('DURDU: Harita.tmx md5 değişmiş (%s), Tiled\'dan kaydedilmiş olabilir' % have)
        sys.exit(2)
    sel = os.environ.get('AGAC_SEC')                          ## isteğe bağlı: "1,2,5" -> sadece bu adaylar
    if sel:
        ids = {int(v) for v in sel.split(',') if v.strip()}
        cands = [c for c in cands if c['id'] in ids]
    g = read_back(TMX)
    changed = set()
    for c in cands:
        if not c['target']:
            print('ATLANDI #%d (hedef katman dolu)' % c['id'])
            continue
        for key, gid in c['gids'].items():
            x, y = map(int, key.split(','))
            assert g[c['src']][y - Y0, x - X0] == gid, ('kaynak hücre değişmiş', c['id'], key)
            assert g[c['target']][y - Y0, x - X0] == 0, ('hedef hücre dolu', c['id'], key)
            g[c['src']][y - Y0, x - X0] = 0
            g[c['target']][y - Y0, x - X0] = gid
        changed.add(c['src'])
        changed.add(c['target'])
    text = open(TMX, encoding='utf-8', newline='').read()
    nl = '\r\n' if '\r\n' in text else '\n'
    for path in sorted(changed, key=lambda p: -layer_block(text, p.split('/')[-1]).start()):   ## sondan başa: konumlar kaymasın
        m = layer_block(text, path.split('/')[-1])
        text = text[:m.start(2)] + write_chunks(g[path], nl) + text[m.end(2):]
    stamp = os.path.join(YEDEK, 'Harita_2026-10-19_oncesi_agac-tasima.tmx.bak')
    if not os.path.exists(stamp):
        shutil.copy2(TMX, stamp)
    tmp = TMX + '.tmp'
    open(tmp, 'w', encoding='utf-8', newline='').write(text)
    os.replace(tmp, TMX)
    ## geri okuma doğrulaması: taşınan hücreler hedefte, diğer tüm katmanlar aynı
    g2 = read_back(TMX)
    for k in g:
        assert np.array_equal(g[k], g2[k]), ('geri okuma farkı', k)
    print('YAZILDI. katmanlar:', sorted(changed), '| taşınan aday', sum(1 for c in cands if c['target']), '| yeni md5', md5(TMX))


if __name__ == '__main__':
    main()
