# -*- coding: utf-8 -*-
"""DIŞ ÇERÇEVE ORMANI: ÜST ÜSTE BİNEN AĞAÇLAR (madde 477, 2026-11-08; kullanıcı: "üst üste binen tüm ağaçları düzeltir misin, çok fazla görüyorum, özellikle
sınırlarda"). Madde 119'un üreticisi (ring_trees.place_forest) ağaç başına %20'ye kadar örtüşmeye izin veriyor ve 4 katmana sığmayınca sırayı
gevşetiyordu: 1434 çerçeve ağacında 740 piksel çakışan çift, 126'sında ARKADAKİ ağaç öndekinin üstüne çiziliyordu (oyun alanı ağaçlarında 7 çakışma,
hepsi doğru sırada - elle yerleştirilmiş, dokunulmaz).

Yöntem: "Dış orman 1-4" nesneleri (atlas komşuluğuyla birleşen karolar) BÜYÜKTEN küçüğe yerleştirilir; oyun alanı ağaçları (Ağaç 0/1/2) sabit engel.
Bir ağacın opak pikseli daha önce yerleşenlerle ESIK oranından fazla örtüşüyorsa en yakın boş yere (en çok YARICAP hücre; halkada, suya/su kıyısına
değmeden, oyun alanına girmeden) kaydırılır, yer yoksa silinir. Sonra nesneler katmanlara (ortak hücresi olan iki nesne aynı katmana girmez; kök
y'sine göre arkadan öne) yeniden dağıtılır - örtüşme kalmadığı için çizim sırası görünmez. Görünmez duvar ("Orman parçaları") DEĞİŞMEZ.

Kullanım: python -I tools/dis_cerceve/cakisma_temizle.py                 -> kuru çalışma (sayılar)
          python -I tools/dis_cerceve/cakisma_temizle.py --out <tmx>     -> sonucu başka dosyaya yazar (karşılaştırma)
          python -I tools/dis_cerceve/cakisma_temizle.py --apply <md5>   -> Harita.tmx'e yazar (md5 kapısı + yedek)
"""
import hashlib
import os
import re
import shutil
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(PROJECT, 'tools', 'harita_kenar'))
import kenar_susleri as K  # noqa: E402  (TMX parça okuma/yazma: Tiled biçimi bayt bayt)

TMX = os.path.join(PROJECT, 'harita', 'Harita.tmx')
YEDEK = os.path.join(PROJECT, 'harita', 'yedek', 'Harita_2026-11-08_oncesi_agac-cakisma.tmx.bak')
FRAME_LAYERS = ['Dış orman 1', 'Dış orman 2', 'Dış orman 3', 'Dış orman 4']
FIXED_LAYERS = ['Ağaç 0', 'Ağaç 1', 'Ağaç 2']
WATER_LAYERS = ['Su', 'Su collisionsuz']
PLAY = 256
X0, Y0, X1, Y1 = -32, -20, 288, 276          # halka sınırı (hücre)
## Ölçüm (1434 ağaç): ESIK 0,03 -> 109 küçük temas + ressam kuralıyla 7 katman; 0,01 -> 7 katman; 0 (HİÇ örtüşme) -> 3 katman, sıra sorunu
## kendiliğinden yok. YARICAP 3/4/5/6 -> silinen 224/202/187/161 (5 seçildi: daha uzak kaydırma ormanın yerini fazla değiştirir).
ESIK = 0.0                                     # izin verilen örtüşme: ağacın kendi opak pikselinin oranı
YARICAP = 5
FLAGS = 0xF0000000
FH = 0x80000000


def md5(p):
    return hashlib.md5(open(p, 'rb').read()).hexdigest()


class Tiles:
    def __init__(self, text):
        self.ts = [(int(a), b) for a, b in re.findall(r'<tileset firstgid="(\d+)" source="([^"]+)"', text)]
        self.sheets = {}

    def decode(self, g):
        flip = bool(g & FH)
        gg = g & ~FLAGS
        best = None
        for f, n in self.ts:
            if f <= gg:
                best = (n, gg - f)
        src, lid = best
        if src not in self.sheets:
            t = open(os.path.join(PROJECT, 'harita', src), encoding='utf-8').read()
            cols = int(re.search(r'columns="(\d+)"', t).group(1))
            img = Image.open(os.path.join(PROJECT, 'harita', re.search(r'<image source="([^"]+)"', t).group(1))).convert('RGBA')
            self.sheets[src] = (np.array(img)[:, :, 3] >= 40, cols)
        a, cols = self.sheets[src]
        return src, (lid % cols, lid // cols), flip

    def alpha(self, g):
        src, (c, r), flip = self.decode(g)
        a = self.sheets[src][0][r * 16:(r + 1) * 16, c * 16:(c + 1) * 16]
        return a[:, ::-1] if flip else a


def objects(cells, T):
    """Atlas komşuluğuyla birleşen karolar -> [{'cells': {(dx,dy): gid}, 'x', 'y', 'mask', 'base'}] (depth_occluders kuralı)."""
    info = {c: T.decode(g) for c, g in cells.items()}
    parent = {c: c for c in info}

    def find(c):
        while parent[c] != c:
            parent[c] = parent[parent[c]]
            c = parent[c]
        return c
    for c, (s, at, fl) in info.items():
        r = (c[0] + 1, c[1])
        if r in info and info[r][0] == s and info[r][2] == fl and info[r][1] == (at[0] + (-1 if fl else 1), at[1]):
            parent[find(r)] = find(c)
        d = (c[0], c[1] + 1)
        if d in info and info[d][0] == s and info[d][2] == fl and info[d][1] == (at[0], at[1] + 1):
            parent[find(d)] = find(c)
    groups = {}
    for c in info:
        groups.setdefault(find(c), []).append(c)
    out = []
    for cl in groups.values():
        x0 = min(c[0] for c in cl)
        y0 = min(c[1] for c in cl)
        w = max(c[0] for c in cl) - x0 + 1
        h = max(c[1] for c in cl) - y0 + 1
        m = np.zeros((h * 16, w * 16), bool)
        rel = {}
        for c in cl:
            rel[(c[0] - x0, c[1] - y0)] = cells[c]
            m[(c[1] - y0) * 16:(c[1] - y0 + 1) * 16, (c[0] - x0) * 16:(c[0] - x0 + 1) * 16] |= T.alpha(cells[c])
        if not m.any():
            continue
        rows = np.nonzero(m.any(axis=1))[0]
        out.append({'cells': rel, 'x': x0, 'y': y0, 'mask': m, 'npx': int(m.sum()), 'base_rel': int(rows[-1])})
    return out


def katmanla(kept, W, H):
    """[(nesne, x, y)] -> katman başına {hücre: gid}. Arkadan öne (kök y); RESSAM KURALI: pikseli örtüşen her arka nesneden daha ÜST katman
    (örtüşme yoksa sıra görünmez) + ortak hücresi olmayan ilk katman. doldur.py de kullanır."""
    kept = sorted(kept, key=lambda k: ((k[2] * 16 + k[0]['base_rel']), k[1]))
    occ = []
    grids = []
    ptop = np.full((H, W), -1, np.int8)
    for (o, x, y) in kept:
        cells = [(x + dx, y + dy, g) for (dx, dy), g in o['cells'].items()]
        py, px = (y - Y0) * 16, (x - X0) * 16
        hh, ww = o['mask'].shape
        sub = ptop[py:py + hh, px:px + ww]
        under = sub[o['mask']]
        k = int(under.max()) + 1 if under.size else 0
        while k < len(occ) and any((cx, cy) in occ[k] for (cx, cy, _g) in cells):
            k += 1
        sub[o['mask']] = k
        if k == len(occ):
            occ.append(set())
            grids.append({})
        for (cx, cy, g) in cells:
            occ[k].add((cx, cy))
            grids[k][(cx, cy)] = g
    return grids


def yaz_katmanlar(text, names, grids, nl):
    """Var olan katmanların <data> gövdesini Tiled biçiminde yeniden yazar (katman başlığı/özellikleri aynı kalır)."""
    for name, cells in zip(names, grids):
        m = K.layer_span(text, name)
        body = m.group(2)
        d = re.search(r'([ \t]*)<data encoding="csv">.*?</data>', body, re.S)
        body = body[:d.start()] + K.write_data(cells, nl, d.group(1)) + body[d.end():]
        text = text[:m.start(2)] + body + text[m.end(2):]
    return text


def main():
    raw = open(TMX, encoding='utf-8', newline='').read()
    nl = '\r\n' if '\r\n' in raw else '\n'
    T = Tiles(raw)
    W, H = (X1 - X0) * 16, (Y1 - Y0) * 16
    taken = np.zeros((H, W), bool)
    water = set()
    for n in WATER_LAYERS:
        water |= set(K.read_cells(K.layer_span(raw, n).group(2)))
    near_water = {(x + dx, y + dy) for (x, y) in water for dx in (-1, 0, 1) for dy in (-1, 0, 1)}

    def stamp(o, x, y):
        py, px = (y - Y0) * 16, (x - X0) * 16
        hh, ww = o['mask'].shape
        taken[py:py + hh, px:px + ww] |= o['mask']

    def overlap(o, x, y):
        py, px = (y - Y0) * 16, (x - X0) * 16
        hh, ww = o['mask'].shape
        if py < 0 or px < 0 or py + hh > H or px + ww > W:
            return None
        return int((taken[py:py + hh, px:px + ww] & o['mask']).sum())

    def fits(o, x, y):
        base_row = o['base_rel'] // 16
        for (dx, dy) in o['cells']:
            cx, cy = x + dx, y + dy
            if not (X0 <= cx < X1 and Y0 <= cy < Y1) or (0 <= cx < PLAY and 0 <= cy < PLAY) or (cx, cy) in water:
                return False
            if dy == base_row and (cx, cy) in near_water:
                return False
        return True

    # sabit engel: oyun alanı ağaçları (halkaya taşan kısımları dahil)
    for n in FIXED_LAYERS:
        for o in objects(K.read_cells(K.layer_span(raw, n).group(2)), T):
            if overlap(o, o['x'], o['y']) is not None:
                stamp(o, o['x'], o['y'])
    frame = []
    for n in FRAME_LAYERS:
        frame += objects(K.read_cells(K.layer_span(raw, n).group(2)), T)
    frame.sort(key=lambda o: -o['npx'])
    offs = sorted(((dx, dy) for dy in range(-YARICAP, YARICAP + 1) for dx in range(-YARICAP, YARICAP + 1) if (dx, dy) != (0, 0)),
                  key=lambda d: (d[0] * d[0] + d[1] * d[1], abs(d[1]), d[0]))
    kept, moved, dropped = [], 0, 0
    for o in frame:
        lim = ESIK * o['npx']
        ov = overlap(o, o['x'], o['y'])
        if ov is not None and ov <= lim:
            stamp(o, o['x'], o['y'])
            kept.append((o, o['x'], o['y']))
            continue
        ok = False
        for (dx, dy) in offs:
            x, y = o['x'] + dx, o['y'] + dy
            ov2 = overlap(o, x, y)
            if ov2 is not None and ov2 <= lim and fits(o, x, y):
                stamp(o, x, y)
                kept.append((o, x, y))
                moved += 1
                ok = True
                break
        if not ok:
            dropped += 1
    grids = katmanla(kept, W, H)
    print('çerçeve ağacı %d | yerinde %d | kaydırılan %d | silinen %d | gereken katman %d' % (
        len(frame), len(kept) - moved, moved, dropped, len(grids)))
    if len(grids) > len(FRAME_LAYERS):
        raise SystemExit('DURDU: %d katman gerekiyor (en çok %d) - ESIK/YARICAP ayarla' % (len(grids), len(FRAME_LAYERS)))
    while len(grids) < len(FRAME_LAYERS):
        grids.append({})
    text = yaz_katmanlar(raw, FRAME_LAYERS, grids, nl)
    if len(sys.argv) >= 3 and sys.argv[1] == '--out':
        open(sys.argv[2], 'w', encoding='utf-8', newline='').write(text)
        print('yazıldı (karşılaştırma):', sys.argv[2])
    elif len(sys.argv) >= 3 and sys.argv[1] == '--apply':
        if md5(TMX) != sys.argv[2]:
            raise SystemExit('DURDU: Harita.tmx md5 değişmiş (%s) - Tiled\'dan kaydedilmiş olabilir' % md5(TMX))
        if not os.path.exists(YEDEK):
            shutil.copy2(TMX, YEDEK)
        tmp = TMX + '.tmp'
        open(tmp, 'w', encoding='utf-8', newline='').write(text)
        os.replace(tmp, TMX)
        print('YAZILDI | yeni md5', md5(TMX))
    else:
        print('kuru çalışma | şu anki md5', md5(TMX))


if __name__ == '__main__':
    main()
