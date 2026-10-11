"""LoL TARZI ÇALILIĞI Harita.tmx'e yazar (2026-10-10; çizim gen_lol_brush.py). Alan = saklanma çalılığının ESKİ (tek karelik denemeden önceki) dolu hücreleri
(harita/yedek/Harita_2026-10-10_oncesi_tek-hucre-calilik.tmx.bak; yol/duvar/su/ağaç testlerinden geçmiş 29 çalılık). HER alan hücresi dolar (bütün çalılık); her hücrenin
karosu komşulara göre kenar maskesi (1 üst, 2 alt, 4 sol, 8 sağ açık) + rastgele çeşit (soldaki/üstteki komşuyla aynı değil).
Kullanım: python -I tools/hide_bush_proto/place_lol.py [--apply <Harita.tmx md5>]  -> out/lol_hucreler.json ({x,y,ax,ay}); --apply TMX + png + tsx yazar (yedekli)."""
import json
import os
import random
import re
import shutil
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import place_single as P  # noqa: E402  (TMX okuma/md5 yardımcıları)

SRC = os.path.join(P.YEDEK, 'Harita_2026-10-10_oncesi_tek-hucre-calilik.tmx.bak')
SEEDS = 4
COLS = 16
SEED = 20261011


def main():
    src = open(SRC, encoding='utf-8', newline='').read().replace('\r\n', '\n')
    _, old = P.read_layer(src)
    foot = (old & P.GID_MASK) != 0
    cells = {(int(x), int(y)) for y, x in zip(*np.nonzero(foot))}
    rng = random.Random(SEED)
    seed_of = {}
    out = []
    for (x, y) in sorted(cells, key=lambda c: (c[1], c[0])):
        m = 0
        if (x, y - 1) not in cells:
            m |= 1
        if (x, y + 1) not in cells:
            m |= 2
        if (x - 1, y) not in cells:
            m |= 4
        if (x + 1, y) not in cells:
            m |= 8
        avoid = {seed_of.get((x - 1, y)), seed_of.get((x, y - 1))}
        opts = [s for s in range(SEEDS) if s not in avoid] or list(range(SEEDS))
        s = rng.choice(opts)
        seed_of[(x, y)] = s
        out.append({'x': x, 'y': y, 'ax': m, 'ay': s})
    print('hücre', len(out))
    json.dump(out, open(os.path.join(P.OUT, 'lol_hucreler.json'), 'w'))
    if '--apply' not in sys.argv:
        return
    want = sys.argv[sys.argv.index('--apply') + 1]
    if P.md5(P.TMX) != want:
        print('DURDU: Harita.tmx md5 değişmiş (%s), Tiled\'dan kaydedilmiş olabilir' % P.md5(P.TMX))
        sys.exit(2)
    stamp = '2026-10-10_oncesi_lol-calilik'
    shutil.copy2(P.TMX, os.path.join(P.YEDEK, 'Harita_%s.tmx.bak' % stamp))
    shutil.copy2(P.TSX, os.path.join(P.YEDEK, 'saklanma_calilik_%s.tsx.bak' % stamp))
    shutil.copy2(P.PNG, os.path.join(P.YEDEK, 'saklanma_calilik_%s.png.bak' % stamp))
    shutil.copy2(os.path.join(P.OUT, 'saklanma_lol.png'), P.PNG)
    tsx = open(P.TSX, encoding='utf-8', newline='').read()
    tsx = re.sub(r'tilecount="\d+"', 'tilecount="%d"' % (COLS * SEEDS), tsx)
    tsx = re.sub(r'<image source="saklanma_calilik.png" width="\d+" height="\d+"/>', '<image source="saklanma_calilik.png" width="256" height="%d"/>' % (16 * SEEDS), tsx)
    open(P.TSX, 'w', encoding='utf-8', newline='').write(tsx)
    text = open(P.TMX, encoding='utf-8', newline='').read()
    nl = '\r\n' if '\r\n' in text else '\n'
    text = text.replace('\r\n', '\n')
    m, grid = P.read_layer(text)
    new = np.zeros_like(grid)
    for c in out:
        new[c['y'], c['x']] = P.FIRSTGID + c['ay'] * COLS + c['ax']
    rows = [','.join(str(int(v)) for v in new[y]) + (',' if y < new.shape[0] - 1 else '') for y in range(new.shape[0])]
    res = text[:m.start(2)] + '\n'.join(rows) + text[m.end(2):]
    tmp = P.TMX + '.tmp'
    open(tmp, 'w', encoding='utf-8', newline='').write(res.replace('\n', nl))
    os.replace(tmp, P.TMX)
    print('YAZILDI. yeni md5', P.md5(P.TMX))


if __name__ == '__main__':
    main()
