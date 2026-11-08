# -*- coding: utf-8 -*-
"""DIŞ ÇERÇEVE ORMANINI SIKLAŞTIRMA (madde 481, 2026-11-08; kullanıcı: "haritanın geçilemeyecek dış sınırlarının geçilemeyecekmiş gibi ağaçlarla
dolu olmasını sağlar mısın, üst üste bindirmeden; bazı yerlerden sanki geçilebilirmiş gibi duruyor").

Neden boştu: madde 119'un üreticisi (ring_trees.place_forest) ormanı BİLEREK seyrek kurmuştu (o günkü istek "daha seyrek"): yerel kapsama hedefi
en çok %66, gürültüyle açıklıklar, oyun alanına yaklaştıkça seyrelme ve sınırın 2 hücresine hiç ağaç yok; madde 477 (örtüşme temizliği) de 187
ağaç sildi. Ölçüm (opak ağaç pikseli, kara hücre): sınıra 1-3 hücre %29 örtü / hücrelerin %50'si boş, 4-8 hücre %41 / %33, iç %43 / %30.

Yöntem: çerçevedeki ŞABLON nesneleri (STAMP_SOURCES) atılır, orman baştan sıkı dizilir; şablon dışı (elle konmuş) nesneler ve oyun alanı ağaçları
yerinde kalır (sabit engel). Halkanın kara hücreleri geçiş geçiş taranır: önce büyük, sonra orta ağaçlar SATIR SATIR (rastgele kaymalı -> taçlar
birbirine değer), sonra küçük ağaç ve çalılar rastgele sırayla boşluklara; cins o yörenin (madde 119'un tema gürültüsü, çıplak toprakta ölü ağaç).
Opak pikseli (alfa >= 40) daha önce konan HİÇBİR şeyle örtüşmeyen ilk aday konur. Kurallar madde 477 ile aynı: halkada, oyun alanına girmez, suya
girmez, kök satırı suya/kıyıya bitişik değil; halkaya taşan platonun tepesine ağaç dikilir ama kökü kaya/uçurum yüzüne basamaz. Sonra bütün çerçeve
nesneleri cakisma_temizle.katmanla ile katmanlara dağıtılır; 4 katman yetmezse "Dış orman 5.." eklenir (map_color_grade.gd ön ekle bulur).
Görünmez duvar ("Orman parçaları") DEĞİŞMEZ. --koru: eski şablon ağaçları da yerinde kalır, yalnız aralar dolar (denendi: benek benek, kullanılmadı).

Kullanım: python -I tools/dis_cerceve/doldur.py                 -> kuru çalışma (sayılar)
          python -I tools/dis_cerceve/doldur.py --out <tmx>     -> sonucu başka dosyaya yazar (karşılaştırma)
          python -I tools/dis_cerceve/doldur.py --apply <md5>   -> Harita.tmx'e yazar (md5 kapısı + yedek)
"""
import os
import random
import re
import shutil
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import cakisma_temizle as C  # noqa: E402
from cakisma_temizle import K, X0, Y0, X1, Y1, PLAY  # noqa: E402
from ring_stamps import build as build_stamps  # noqa: E402  (madde 119 şablonları: haritanın kendi tileset'lerinden ağaç/çalı)
from ring_trees import Noise  # noqa: E402
from stamplib import Lib, load  # noqa: E402

YEDEK = os.path.join(C.PROJECT, 'harita', 'yedek', 'Harita_2026-11-08_oncesi_cerceve-doldurma.tmx.bak')
OBSTACLE_LAYERS = ['Animasyonsuz çalılar']  # halkada piksel engeli (ağaç değil, üstüne çizilmesin)
## Oyun alanındaki platonun halkaya taşan kısmı (madde 119 kenar tamamlama): üstü ÇİMEN (zemin gibi, ağaç dikilebilir), yüzü kaya/uçurum.
## Engel sayılınca sınırın dibinde 3-5 hücre ağaçsız çimen şeridi kalıyordu (batı kenarı). Kural: kökü kayalı karoya basamaz.
PLATEAU_LAYER = 'Orman parçaları 2'
COAST_LAYERS = ['Su ayrıntılar 2']                                 # kıyı karoları: kök satırı buraya basmaz
GRASS_LAYER = 'Zemin Çimen'
SEED = 20261108
## Var olan çerçeve ağaçları ARASINA doldurmak yetmiyor (yalnız küçük ağaç/çalı sığıyor -> benek benek): orman baştan sıkı dizilir.
## --koru: eski ağaçlar yerinde kalır, yalnız aralar doldurulur (karşılaştırma için).
YENIDEN = '--koru' not in sys.argv
## Baştan dizerken YALNIZ bu tileset'lerden gelen nesneler (madde 119 şablonları) atılır. Diğerleri kullanıcının Tiled'da elle koydukları
## (kuzeydoğu sınırındaki 7 "exterior" ağacı, x 250-256 y -3..39, yarısı oyun alanında) -> yerinde kalır, yeni ağaçlar onlarla da örtüşmez.
## Kanıt: madde 119 üreticisi Harita_oncesi_dis-cerceve.tmx.bak üzerinde yeniden koşturulup git'teki ilk sürümle (6a15d1b9) karşılaştırıldı;
## şablon tileset'li farklar su uzatılırken kesilen ağaçlar + 1 hücrelik kesik kalıntılardı.
STAMP_SOURCES = {'Objects.tsx', 'sade ağaç ve taş.tsx', 'sadece_agac.tsx'}
## Tiled'da çerçeve katmanına kazara boyanmış düz çimen karoları: map_color_grade.gd zeminin altına alır (görünmez) -> korunur, engel değil.
HIDDEN_SOURCES = {'Ground_grass.tsx'}
JITTER_X = float(os.environ.get('DOLDUR_JX', '6'))    # satır içi kayma (hücre); 3'te sıralar ızgara gibi okunuyordu
JITTER_Y = float(os.environ.get('DOLDUR_JY', '1.5'))  # satırlar arası kayma (hücre)
## Hücrenin bu oranından fazlası zaten örtülüyse oraya kök denenmez (hız; örtülü hücreye kök koymak zaten örtüşür).
SKIP_COVERED = 0.55
## Geçişler: (sınıf, tarama sayısı). Önce büyük ağaçlar yer kapar, küçükler ve çalılar aradaki boşlukları doldurur.
PASSES = [('buyuk', 2), ('orta', 2), ('kucuk', 2), ('cali', 3)]


def to_obj(st):
    mask = st['alpha'] >= 40
    rows = np.nonzero(mask.any(axis=1))[0]
    return {'cells': {(i, j): gid for (i, j, gid) in st['tiles']}, 'mask': mask, 'npx': int(mask.sum()),
            'base_rel': int(rows[-1]), 'name': st['name']}


def main():
    raw = open(C.TMX, encoding='utf-8', newline='').read()
    nl = '\r\n' if '\r\n' in raw else '\n'
    T = C.Tiles(raw)
    W, H = (X1 - X0) * 16, (Y1 - Y0) * 16
    rng = random.Random(SEED)
    taken = np.zeros((H, W), bool)

    def cells_of(name):
        return K.read_cells(K.layer_span(raw, name).group(2))
    water = set()
    for n in C.WATER_LAYERS:
        water |= set(cells_of(n))
    coast = set()
    for n in COAST_LAYERS:
        coast |= set(cells_of(n))
    wet = water | coast
    near_wet = {(x + dx, y + dy) for (x, y) in wet for dx in (-1, 0, 1) for dy in (-1, 0, 1)}
    grass = set(cells_of(GRASS_LAYER))

    def window(o, x, y):
        py, px = (y - Y0) * 16, (x - X0) * 16
        hh, ww = o['mask'].shape
        if py < 0 or px < 0 or py + hh > H or px + ww > W:
            return None
        return (slice(py, py + hh), slice(px, px + ww))

    def stamp(o, x, y):
        w = window(o, x, y)
        if w is not None:
            taken[w] |= o['mask']

    def fits(o, x, y):
        base_row = o['base_rel'] // 16
        for (dx, dy) in o['cells']:
            cx, cy = x + dx, y + dy
            if not (X0 <= cx < X1 and Y0 <= cy < Y1) or (0 <= cx < PLAY and 0 <= cy < PLAY) or (cx, cy) in water:
                return False
            if dy == base_row and ((cx, cy) in near_wet or (cx, cy) in rocky):
                return False
        return True

    # sabit engeller: oyun alanı ağaçları + halkadaki plato/uçurum parçaları + var olan çerçeve ağaçları (yerinde kalır)
    for n in C.FIXED_LAYERS:
        for o in C.objects(cells_of(n), T):
            stamp(o, o['x'], o['y'])
    for n in OBSTACLE_LAYERS:  # yalnız halkadaki hücreleri (oyun alanının bu katmanlarında başka tileset'ler de var)
        ring = {c: g for c, g in cells_of(n).items() if not (0 <= c[0] < PLAY and 0 <= c[1] < PLAY)}
        for o in C.objects(ring, T):
            stamp(o, o['x'], o['y'])
    _root, ts = load(C.TMX)
    rocky = set()   # platonun kaya/uçurum yüzü karoları (opak piksellerin %25'inden fazlası kahverengi/gri: r >= g)
    for c, g in cells_of(PLATEAU_LAYER).items():
        if 0 <= c[0] < PLAY and 0 <= c[1] < PLAY:
            continue
        im = ts.tile(g)
        if im is None:
            continue
        a = np.asarray(im).astype(np.int32)
        op = a[:, :, 3] >= 40
        if op.any() and float(((a[:, :, 0] >= a[:, :, 1]) & op).sum()) / float(op.sum()) > 0.25:
            rocky.add(c)
    frame = []
    kept_hand = 0
    for n in C.FRAME_LAYERS:
        for o in C.objects(cells_of(n), T):
            src = T.decode(next(iter(o['cells'].values())))[0]
            if YENIDEN and src in STAMP_SOURCES:
                continue
            if src not in STAMP_SOURCES:
                kept_hand += 1
            if src not in HIDDEN_SOURCES:
                stamp(o, o['x'], o['y'])
            frame.append((o, o['x'], o['y']))
    before = len(frame)
    print('elle konmuş (şablon dışı) çerçeve nesnesi korunuyor:', kept_hand)

    # şablonlar (Lib haritanın kendi tileset'lerini çözümler; gid'ler bu TMX'in firstgid'leriyle)
    TREES, SHRUBS, SHRUBS_DARK, _MUSH, _STUMPS, _ROCKS = build_stamps(Lib(ts))
    TR = {k: [to_obj(s) for s in v] for k, v in TREES.items()}
    SH = [to_obj(s) for s in SHRUBS]
    SHD = [to_obj(s) for s in SHRUBS_DARK]

    # yöre cinsi: madde 119'un tema gürültüsü (koyu koru / açık koru) + çıplak toprak payı (ölü ağaç)
    n_theme = Noise(23)
    land = [(x, y) for y in range(Y0, Y1) for x in range(X0, X1)
            if not (0 <= x < PLAY and 0 <= y < PLAY) and (x, y) not in water]
    dirt = np.zeros((Y1 - Y0, X1 - X0), np.float32)
    for (x, y) in land:
        if (x, y) not in grass:
            dirt[y - Y0, x - X0] = 1.0
    R = 6
    cs = np.pad(dirt, ((R + 1, R), (R + 1, R))).cumsum(0).cumsum(1)
    dirt_frac = (cs[2 * R + 1:, 2 * R + 1:] - cs[:-2 * R - 1, 2 * R + 1:] - cs[2 * R + 1:, :-2 * R - 1] + cs[:-2 * R - 1, :-2 * R - 1]) / float((2 * R + 1) ** 2)

    def rows_of(o):
        return max(dy for _, dy in o['cells']) + 1

    ALL_TREES = {id(o): o for v in TR.values() for o in v}.values()
    SIZE = {'buyuk': [o for o in ALL_TREES if rows_of(o) >= 5], 'orta': [o for o in ALL_TREES if rows_of(o) == 4],
            'kucuk': [o for o in ALL_TREES if rows_of(o) <= 3]}
    # yöre ağırlıkları (madde 119 tree_stamp oranları): koyu koru çam %60 / yosunlu %25 / yapraklı %15; açık koru yapraklı + biraz çam;
    # çıplak toprak yöresi ölü + yosunlu
    WEIGHTS = {
        'koyu': [('dark_pine', 6), ('mossy', 2.5), ('lush_mid', 1.5)],
        'acik': [('lush_mid', 4), ('lush_big', 3), ('dark_pine', 1.5), ('lush_small', 1)],
        'olu': [('dead', 5), ('mossy', 2)],
    }

    def pool(x, y, cls):
        if cls == 'cali':
            lst = (SH if (x, y) in grass else SHD)[:]
            rng.shuffle(lst)
            return lst
        df = float(dirt_frac[y - Y0, x - X0])
        yore = 'olu' if rng.random() < df ** 0.8 else ('koyu' if n_theme(x, y) > 0.55 else 'acik')
        ids = {id(o) for o in SIZE[cls]}
        keyed = []
        for sp, w in WEIGHTS[yore]:
            for o in TR[sp]:
                if id(o) in ids:
                    keyed.append((rng.random() ** (1.0 / w), id(o), o))   # ağırlıklı karışık sıra
        keyed.sort(key=lambda k: -k[0])
        seen, out = set(), []
        for _k, i, o in keyed:
            if i not in seen:
                seen.add(i)
                out.append(o)
        return out

    added = {}
    for cls, sweeps in PASSES:
        for _s in range(sweeps):
            order = land[:]
            rng.shuffle(order)
            if cls in ('buyuk', 'orta'):
                # SIKI DİZİLİŞ: satır satır (yukarıdan aşağı) + rastgele kayma -> taçlar birbirine değer, düz ızgara olmaz
                order.sort(key=lambda c: (c[1] + rng.random() * JITTER_Y, c[0] + rng.random() * JITTER_X))
            for (bx, by) in order:
                py, px = (by - Y0) * 16, (bx - X0) * 16
                if taken[py:py + 16, px:px + 16].mean() > SKIP_COVERED:
                    continue
                for o in pool(bx, by, cls):
                    x = bx - (max(dx for dx, _ in o['cells']) + 1) // 2
                    y = by - o['base_rel'] // 16
                    w = window(o, x, y)
                    if w is None or (taken[w] & o['mask']).any() or not fits(o, x, y):
                        continue
                    taken[w] |= o['mask']
                    frame.append((o, x, y))
                    added[cls] = added.get(cls, 0) + 1
                    break
    grids = C.katmanla(frame, W, H)
    print('çerçeve nesnesi %d -> %d | eklenen %s | gereken katman %d' % (before, len(frame), added, len(grids)))

    # örtü ölçümü (yalnız ağaç/çalı pikseli; doluluk.py ile aynı bantlar)
    cell_cov = taken.reshape(H // 16, 16, W // 16, 16).mean(axis=(1, 3))
    bands = {'1-3': [], '4-8': [], '9+': []}
    for (x, y) in land:
        d = max(max(0 - x, 0, x - 255), max(0 - y, 0, y - 255))
        bands['1-3' if d <= 3 else ('4-8' if d <= 8 else '9+')].append(cell_cov[y - Y0, x - X0])
    for k, v in bands.items():
        print('  bant %s: ortalama örtü %%%.0f, boş (<%%10) hücre %%%.0f' % (k, 100 * np.mean(v), 100 * np.mean(np.array(v) < 0.1)))

    # katman adları: var olanlar + gerekirse yenileri ("Dış orman 4"ün ardına)
    names = list(C.FRAME_LAYERS)
    text = raw
    if len(grids) > len(names):
        nxt = int(re.search(r'nextlayerid="(\d+)"', text).group(1))
        last = K.layer_span(text, names[-1])
        ins = ''
        for i in range(len(names), len(grids)):
            nm = 'Dış orman %d' % (i + 1)
            ins += nl + '  <layer id="%d" name="%s" width="320" height="296">%s   <data encoding="csv">%s   </data>%s  </layer>' % (
                nxt, nm, nl, nl, nl, nl)
            names.append(nm)
            nxt += 1
        text = text[:last.end(3)] + ins + text[last.end(3):]
        text = re.sub(r'nextlayerid="\d+"', 'nextlayerid="%d"' % nxt, text, count=1)
    while len(grids) < len(names):
        grids.append({})
    text = C.yaz_katmanlar(text, names, grids, nl)
    argv = [a for a in sys.argv if a != '--koru']
    if len(argv) >= 3 and argv[1] == '--out':
        open(argv[2], 'w', encoding='utf-8', newline='').write(text)
        print('yazıldı (karşılaştırma):', argv[2])
    elif len(argv) >= 3 and argv[1] == '--apply':
        if C.md5(C.TMX) != argv[2]:
            raise SystemExit('DURDU: Harita.tmx md5 değişmiş (%s) - Tiled\'dan kaydedilmiş olabilir' % C.md5(C.TMX))
        if not os.path.exists(YEDEK):
            shutil.copy2(C.TMX, YEDEK)
        tmp = C.TMX + '.tmp'
        open(tmp, 'w', encoding='utf-8', newline='').write(text)
        os.replace(tmp, C.TMX)
        print('YAZILDI | yeni md5', C.md5(C.TMX))
    else:
        print('kuru çalışma | şu anki md5', C.md5(C.TMX))


if __name__ == '__main__':
    main()
