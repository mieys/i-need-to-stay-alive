"""TEK KARELİK SAKLANMA ÇALILARINI Harita.tmx'e yerleştirir (2026-10-10, kullanıcı: "tek tek kare kare yerleştirilip oyuncu içine girince o karedeki çalıların
saklanması"; bkz. gen_single_bush.py). Alan = mevcut "Saklanma Çalılığı" katmanının dolu hücreleri (yol/duvar/su/ağaç testlerinden zaten geçmiş yerler); her seçilen hücreye
BAĞIMSIZ bir çalı (16 çeşitten biri) konur: komşu hücrelerin hepsi dolmaz (en çok 1 dolu dik komşu, 2x2 blok yok), böylece her çalı kendi başına okunur.
Kullanım (proje kökünden):
  python -I tools/hide_bush_proto/place_single.py                     -> sadece plan + önizleme + out/tek_hucreler.json
  python -I tools/hide_bush_proto/place_single.py --apply <md5>       -> md5 (Harita.tmx) tutuyorsa yedek alır, katmanı/png/tsx'i yazar
Üretim deterministik (SEED). Yoğunluk: KEEP (kabul olasılığı).
"""
import hashlib
import json
import os
import random
import re
import shutil
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
PROJECT = os.path.normpath(os.path.join(HERE, '..', '..'))
TMX = os.path.join(PROJECT, 'harita', 'Harita.tmx')
TSX = os.path.join(PROJECT, 'harita', 'saklanma_calilik.tsx')
PNG = os.path.join(PROJECT, 'harita', 'saklanma_calilik.png')
YEDEK = os.path.join(PROJECT, 'harita', 'yedek')
OUT = os.path.join(HERE, 'out')
LAYER = 'Saklanma Çalılığı'
FIRSTGID = 34768
VARIANTS = 16
SEED = 20261010
KEEP = 0.72
GID_MASK = 0x1FFFFFFF


def md5(p):
    return hashlib.md5(open(p, 'rb').read()).hexdigest()


def read_layer(text):
    m = re.search(r'(<layer id="\d+" name="%s"[^>]*>\s*<data encoding="csv">\n)(.*?)(\n</data>)' % re.escape(LAYER), text, re.S)
    assert m, 'katman yok'
    rows = [r for r in m.group(2).split('\n')]
    grid = np.array([[int(v) for v in r.rstrip(',').split(',')] for r in rows], dtype=np.int64)
    return m, grid


def select(foot):
    rng = random.Random(SEED)
    h, w = foot.shape
    cells = [(int(y), int(x)) for y, x in zip(*np.nonzero(foot))]
    rng.shuffle(cells)
    chosen = np.zeros_like(foot, dtype=bool)
    variant = {}

    def has(y, x):
        return 0 <= y < h and 0 <= x < w and chosen[y, x]

    for (y, x) in cells:
        if rng.random() > KEEP:
            continue
        n4 = [(y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)]
        if sum(1 for (a, b) in n4 if has(a, b)) > 1:
            continue
        # 2x2 blok oluşmasın
        bad = False
        for dy in (-1, 0):
            for dx in (-1, 0):
                blk = [(y + dy, x + dx), (y + dy + 1, x + dx), (y + dy, x + dx + 1), (y + dy + 1, x + dx + 1)]
                if sum(1 for (a, b) in blk if (a, b) != (y, x) and has(a, b)) >= 3:
                    bad = True
        if bad:
            continue
        chosen[y, x] = True
        used = {variant.get(p) for p in n4 + [(y - 1, x - 1), (y - 1, x + 1)] if p in variant}
        opts = [v for v in range(VARIANTS) if v not in used] or list(range(VARIANTS))
        variant[(y, x)] = rng.choice(opts)
    return chosen, variant


def main():
    apply = '--apply' in sys.argv
    text = open(TMX, encoding='utf-8', newline='').read()
    nl = '\r\n' if '\r\n' in text else '\n'
    text = text.replace('\r\n', '\n')
    m, grid = read_layer(text)
    foot = (grid & GID_MASK) != 0
    chosen, variant = select(foot)
    print('alan hücresi', int(foot.sum()), '-> çalı', int(chosen.sum()), '(%.0f%%)' % (100.0 * chosen.sum() / max(1, foot.sum())))
    new = np.zeros_like(grid)
    for (y, x), v in variant.items():
        new[y, x] = FIRSTGID + v
    cells = [{'x': x, 'y': y, 'v': v} for (y, x), v in sorted(variant.items())]
    os.makedirs(OUT, exist_ok=True)
    json.dump(cells, open(os.path.join(OUT, 'tek_hucreler.json'), 'w'))
    if not apply:
        return
    want = sys.argv[sys.argv.index('--apply') + 1]
    have = md5(TMX)
    if have != want:
        print('DURDU: Harita.tmx md5 %s beklenen %s - kullanıcı Tiled\'dan kaydetmiş olabilir' % (have, want))
        sys.exit(2)
    # yedekler
    stamp = '2026-10-10_oncesi_tek-hucre-calilik'
    shutil.copy2(TMX, os.path.join(YEDEK, 'Harita_%s.tmx.bak' % stamp))
    shutil.copy2(TSX, os.path.join(YEDEK, 'saklanma_calilik_%s.tsx.bak' % stamp))
    shutil.copy2(PNG, os.path.join(YEDEK, 'saklanma_calilik_%s.png.bak' % stamp))
    # png + tsx
    shutil.copy2(os.path.join(OUT, 'saklanma_calilik_tek.png'), PNG)
    tsx = open(TSX, encoding='utf-8', newline='').read()
    tsx = re.sub(r'tilecount="\d+"', 'tilecount="%d"' % VARIANTS, tsx)
    tsx = re.sub(r'<image source="saklanma_calilik.png" width="\d+" height="\d+"/>', '<image source="saklanma_calilik.png" width="256" height="16"/>', tsx)
    open(TSX, 'w', encoding='utf-8', newline='').write(tsx)
    # katman CSV
    rows = []
    for y in range(new.shape[0]):
        rows.append(','.join(str(int(v)) for v in new[y]) + (',' if y < new.shape[0] - 1 else ''))
    out = text[:m.start(2)] + '\n'.join(rows) + text[m.end(2):]
    tmp = TMX + '.tmp'
    open(tmp, 'w', encoding='utf-8', newline='').write(out.replace('\n', nl))
    os.replace(tmp, TMX)
    print('YAZILDI. yeni md5', md5(TMX))


if __name__ == '__main__':
    main()
