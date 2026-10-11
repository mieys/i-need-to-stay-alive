"""AĞAÇ SEYRELTME (2026-10-09, kullanıcı: "harita çok boğuk, haritanın orta kısımlarında gereksiz boğucu ağaçlar var (dış köşeler ve dağların arkası hariç); biraz azalt, Harita.tmx'e de yap").

SADECE benim orman dokusu eklediğim ağaçlar (özgün yedekte olmayan damgalar; kullanıcının kendi koyduğu ağaçlara DOKUNULMAZ) ve sadece "orta bölgede" (harita kenarından en az EDGE_MARGIN hücre içeride; dış halka korunur):
  - duvardan uzaktaki (açık alan) ağaçlar KEEP_OPEN oranında kalır,
  - dağ/uçurum kenarındaki (WALL_NEAR hücre içinde) ağaçlar KEEP_NEAR_WALL oranında kalır (daha az seyreltilir).
Kalanlar arası en az MIN_KEEP_GAP hücre. Aynı girdi = aynı çıktı (sabit tohum).

Kullanım (proje kökünden):
  python -I tools/forest_decor/thin_trees.py             -> tools/hide_bush_proto/out/Harita_seyrek.tmx + rapor
  python -I tools/forest_decor/thin_trees.py --apply <canlı md5>   -> canlı harita/Harita.tmx'i (md5 kapısı) değiştirir
"""
import hashlib
import os
import random
import re
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(PROJECT, 'tools', 'hide_bush_proto'))
sys.path.insert(0, HERE)
os.environ.setdefault('HARITA_TMX', os.path.join(PROJECT, 'harita', 'Harita.tmx'))
import place_brush as PB                                   # noqa: E402
from tmxlib import load, layers, grid                      # noqa: E402

LIVE = os.path.join(PROJECT, 'harita', 'Harita.tmx')
ORIG = os.path.join(PROJECT, 'harita', 'yedek', 'Harita_YEDEK_2026-10-09_agac-oncesi.tmx.bak')
OUT_TMX = os.path.join(PROJECT, 'tools', 'hide_bush_proto', 'out', 'Harita_seyrek.tmx')
TREE_LAYERS = ['Shader Eklenecek/Ağaç 0', 'Shader Eklenecek/Ağaç 1', 'Shader Eklenecek/Ağaç 2']
W = H = 256
EDGE_MARGIN = 28       # harita kenarından bu kadar içeride = "orta bölge" (dış halka korunur)
WALL_NEAR = 4          # duvara (dağ) bu kadar yakın = "dağ kenarı" (daha az seyreltilir)
KEEP_OPEN = 0.35       # orta bölgede, duvardan uzak ağaçların kalan oranı
KEEP_NEAR_WALL = 0.65  # orta bölgede, dağ kenarındaki ağaçların kalan oranı
MIN_KEEP_GAP = 4
SEED = 20261010


def md5(p):
    return hashlib.md5(open(p, 'rb').read()).hexdigest()


def main():
    root, ts = load(LIVE)
    L = {'/'.join(p): grid(l) for p, l in layers(root)}
    root_o, ts_o = load(ORIG)
    LO = {'/'.join(p): grid(l) for p, l in layers(root_o)}
    wall = L['Orman parçaları/Orman parçaları'] != 0
    dist = PB.cheb(wall, WALL_NEAR + 1)
    rng = random.Random(SEED)
    stamps = []                                       # (katman, hücreler, kök x, kök y, grup)
    for k in TREE_LAYERS:
        for grp in PB.groups_new(ts, L[k], LO[k]):
            by = max(c[0] for c in grp)
            bx = sum(x for (y, x) in grp if y == by) / sum(1 for (y, x) in grp if y == by)   # gövde (en alt satır) merkezi
            if not (EDGE_MARGIN <= bx < W - EDGE_MARGIN and EDGE_MARGIN <= by < H - EDGE_MARGIN):
                continue                                  # dış halka: dokunulmaz
            near = dist[int(by), int(bx)] <= WALL_NEAR
            stamps.append((k, grp, bx, by, 'dag' if near else 'acik'))
    print('benim ağaçlarım (orta bölge):', len(stamps), {g: sum(1 for s in stamps if s[4] == g) for g in ('acik', 'dag')})
    new = {k: L[k].copy() for k in TREE_LAYERS}
    kept = []
    removed = 0
    for group, keep_ratio in (('acik', KEEP_OPEN), ('dag', KEEP_NEAR_WALL)):
        pool = [s for s in stamps if s[4] == group]
        rng.shuffle(pool)
        quota = int(round(len(pool) * keep_ratio))
        n_kept = 0
        for k, grp, bx, by, _ in pool:
            if n_kept < quota and all(max(abs(bx - ox), abs(by - oy)) >= MIN_KEEP_GAP for ox, oy in kept):
                kept.append((bx, by))
                n_kept += 1
            else:
                for (y, x) in grp:
                    new[k][y, x] = 0
                removed += 1
    print('kalan:', len(stamps) - removed, '| kaldırılan:', removed)
    txt = open(LIVE, encoding='utf-8', newline='').read()

    def fmt(g):
        return '\r\n' + ',\r\n'.join(','.join(str(int(v)) for v in g[y]) for y in range(H)) + '\r\n'

    def span(t, name):
        mm = re.search(r'<layer id="\d+" name="' + re.escape(name) + r'"[^>]*>\s*<data encoding="csv">', t)
        assert mm, name
        s = mm.end()
        return s, t.index('</data>', s)
    for k in TREE_LAYERS:
        s, e = span(txt, k.split('/')[1])
        assert txt[s:e] == fmt(L[k]), 'CSV biçimi tutmuyor: ' + k
        txt = txt[:s] + fmt(new[k]) + txt[e:]
    open(OUT_TMX, 'w', encoding='utf-8', newline='').write(txt)
    print('yazıldı:', OUT_TMX, '| kaynak md5', md5(LIVE))


if __name__ == '__main__':
    if len(sys.argv) >= 3 and sys.argv[1] == '--apply':
        if md5(LIVE) != sys.argv[2]:
            print('DURDUM: canlı Harita.tmx beklenen sürüm değil', md5(LIVE)); sys.exit(3)
        data = open(OUT_TMX, 'rb').read()
        tmp = LIVE + '.tmp_seyrek'
        open(tmp, 'wb').write(data)
        if md5(LIVE) != sys.argv[2]:
            os.remove(tmp); print('DURDUM: yazma anında değişti'); sys.exit(3)
        os.replace(tmp, LIVE)
        print('uygulandı', md5(LIVE))
    else:
        main()
