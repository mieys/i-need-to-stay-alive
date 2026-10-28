# DERİN ORMAN bölge ZEMİNİ (madde 361/363): kullanıcının yüklediği arşivlerin zemin karolarından tek kaynak doku -> tools/derin_orman/out/zemin_kaynak.png.
# zemin_karolari.py bölge maskesinin içinde çimen/toprak karosunun rengini bu dokuyla değiştirip GERÇEK KAROLARA pişirir (eskiden shader yapıyordu):
# her 16x16 dünya hücresi bir satırdan rastgele (konum hash'i) bir karo seçer -> tekrar yok, karolar arası dikişsiz.
# Düzen: 256 x 384, bölge başına 6 satır x 16 yuva (16 px):
#   0 zemin A (çimenin yerine)   1 zemin B (gürültü yamaları / Batı'da gölcük suyu)   2 yol (toprağın yerine)
#   3 zemin süsleri (saydam)     4 yol süsleri (saydam)                             5 gölcük süsleri (saydam, Batı dalgacıkları; diğerleri boş)
# Yuvalar ağırlık için tekrar eder (en düz karo çoğunlukta). Bölge sırası maske kanalıyla aynı: kuzey, batı, doğu, güney.
#   Kuzey "Kadim Kara Orman"  : ölü diyar gri kül zemini + koyu kül yamaları, yollar eski arnavut kaldırımı; çatlak/diken/çakıl
#   Batı "Kızıl Bataklık"     : lanetli toprağın şeftali zemini + küçük bataklık gölcükleri (paketin lacivert suyu + dalgacıkları, kenarı
#                               kızıl çamur çizgisi; 2. tur - kök halısı yamaları "gelişigüzel leke" gibiydi), yollar mor toprak; kök/ot/leke
#   Doğu "Işıyan Kayalıklar"  : kayalığın bej taşı, yollar arnavut kaldırımı; beyaz-mavi çiçek, yonca, çakıl
#   Güney "Sisli Sazlık"      : bataklığın yosunlu zeytin çimeni + koyu yosun yamaları, yollar çamur; yosun lekeleri
# Kullanım: python -I tools/derin_orman/gen_zemin_dokusu.py   (sonra Godot --headless --import)
import os
import random
import sys
from collections import deque

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import derin_orman_core as C  # noqa: E402

## madde 363: artık oyunun dokusu DEĞİL, karo pişiricisinin kaynağı (zemin_karolari.py) -> Godot'un içe aktarmadığı out/ klasöründe
OUT = os.path.join(C.HERE, 'out', 'zemin_kaynak.png')
SLOTS = 16
ROWS = 6
UD_G = C.zsheet(C.ZIP_UNDEAD, 'Tiled_files/Ground_rocks.png')
UD_D = C.zsheet(C.ZIP_UNDEAD, 'Tiled_files/details.png')
CU_G = C.zsheet(C.ZIP_CURSED, 'Tiled_files/Ground.png')
CU_D = C.zsheet(C.ZIP_CURSED, 'Tiled_files/details.png')
CU_S = C.zsheet(C.ZIP_CURSED, 'Tiled_files/spots.png')
RK_G = C.zsheet(C.ZIP_ROCKY, 'Tiled_files/Ground_moss.png')
RK_D = C.zsheet(C.ZIP_ROCKY, 'Tiled_files/details.png')
SW_G = C.zsheet(C.ZIP_SWAMP, 'Tiled_files/Ground_grass_swamp.png')
SW_S = C.zsheet(C.ZIP_SWAMP, 'Tiled_files/spots.png')
CU_W = C.zsheet(C.ZIP_CURSED, 'Tiled_files/water_detilazation.png')
## su ayrıntı sayfasının İLK animasyon karesi (Tiled'da kare aralığı 13 satır = 208 px): dalgacık parçaları buradan
CU_W_KARE0 = (0, 0, 592, 208)

## dolgu: (sayfa, hedef renk, renk toleransı, en çok std, en düz karonun yuva sayısı[, yasak renk])
##   yasak renk: bu renge yakın (toplam fark < 40) pikseli %3'ten fazla olan karo alınmaz (kenar karosu: kök halısının içinde şeftali delik)
## süs: [(sayfa, en çok boy)] -> sayfadaki <= boy x boy saydam parçalar
ZEMIN = {
    'kuzey': {
        'a': (UD_G, (108, 112, 103), 10, 1.0, 16), 'b': (UD_G, (81, 90, 86), 6, 2.0, 16), 'yol': (UD_G, (154, 148, 126), 16, 21.2, 3),
        'sus': [(UD_D, 15)], 'yol_sus': [(UD_D, 9)],
    },
    'bati': {
        'a': (CU_G, (205, 150, 115), 10, 3.0, 12), 'b': (CU_W, (52, 54, 74), 6, 1.0, 16), 'yol': (CU_G, (157, 98, 89), 8, 3.0, 16),
        'sus': [(CU_D, 15), (CU_S, 13)], 'yol_sus': [(CU_D, 10)], 'su': True, 'golcuk_sus': [(CU_W, 15, CU_W_KARE0)],
    },
    'dogu': {
        'a': (RK_G, (196, 184, 150), 10, 6.0, 10), 'b': (RK_G, (196, 184, 150), 10, 6.0, 10), 'yol': (UD_G, (154, 148, 126), 16, 21.2, 3),
        'sus': [(RK_D, 15)], 'yol_sus': [(RK_D, 9)],
    },
    'guney': {
        'a': (SW_G, (144, 163, 71), 14, 14.0, 7), 'b': (SW_G, (120, 142, 69), 8, 1.0, 16), 'yol': (SW_G, (124, 117, 56), 6, 1.0, 16),
        'sus': [(SW_S, 14)], 'yol_sus': [(SW_S, 9)],
    },
}
_sheets = {}


def sheet(spec):
    if spec not in _sheets:
        _sheets[spec] = np.asarray(C.open_sheet(spec)).copy()
    return _sheets[spec]


def fill_tiles(spec, target, tol, max_std, lead, yasak=None):
    im = sheet(spec).astype(np.float32)
    h, w = im.shape[:2]
    found = []
    for ty in range(h // 16):
        for tx in range(w // 16):
            t = im[ty * 16:(ty + 1) * 16, tx * 16:(tx + 1) * 16]
            if t[..., 3].min() < 255:
                continue
            rgb = t[..., :3].reshape(-1, 3)
            if np.abs(rgb.mean(0) - np.array(target)).max() > tol:
                continue
            sd = float(rgb.std(0).mean())
            if yasak is not None and (np.abs(rgb - np.array(yasak)).sum(1) < 40).mean() > 0.03:
                continue
            if sd <= max_std:
                found.append((sd, (tx, ty), t.astype(np.uint8)))
    assert found, ('dolgu karosu bulunamadı', spec, target)
    found.sort(key=lambda f: (f[0], f[1]))
    ## aynı karoları ayıkla
    uniq = []
    for f in found:
        if not any(np.array_equal(f[2], u[2]) for u in uniq):
            uniq.append(f)
    slots = [uniq[0][2]] * lead
    rest = uniq[1:] or uniq
    i = 0
    while len(slots) < SLOTS:
        slots.append(rest[i % len(rest)][2])
        i += 1
    return slots[:SLOTS], len(uniq)


def sarap(t, k=1.0):
    """Paketin lacivert suyu -> Kızıl Bataklık'ın koyu şarap rengi (parlaklık mavi kanaldan; k: dalgacık süsleri suyun üstünde görünsün diye açılır)."""
    out = t.copy()
    b = t[..., 2].astype(np.float32)
    out[..., 0] = np.clip(b * 0.82 * k, 0, 255)
    out[..., 1] = np.clip(b * 0.33 * k, 0, 255)
    out[..., 2] = np.clip(b * 0.45 * k, 0, 255)
    return out


def pieces(spec, size, box=None):
    a = sheet(spec)
    if box is not None:
        a = a[box[1]:box[3], box[0]:box[2]]
    al = a[..., 3] > 0
    h, w = al.shape
    seen = np.zeros_like(al)
    out = []
    for y in range(h):
        for x in range(w):
            if not al[y, x] or seen[y, x]:
                continue
            q = deque([(y, x)])
            seen[y, x] = True
            pts = []
            while q:
                u, v = q.popleft()
                pts.append((u, v))
                for du in (-1, 0, 1):
                    for dv in (-1, 0, 1):
                        uu, vv = u + du, v + dv
                        if 0 <= uu < h and 0 <= vv < w and al[uu, vv] and not seen[uu, vv]:
                            seen[uu, vv] = True
                            q.append((uu, vv))
            ys = [p[0] for p in pts]
            xs = [p[1] for p in pts]
            bw, bh = max(xs) - min(xs) + 1, max(ys) - min(ys) + 1
            if len(pts) >= 5 and bw <= size and bh <= size:
                m = np.zeros((bh, bw, 4), np.uint8)
                for (u, v) in pts:
                    m[u - min(ys), v - min(xs)] = a[u, v]
                out.append(m)
    return out


def decal_slots(specs, rng):
    allp = []
    for sp in specs:
        allp += pieces(sp[0], sp[1], sp[2] if len(sp) > 2 else None)
    assert allp, ('süs parçası yok', specs)
    ## benzer parçaları seyrelt (çok tekrar eden aynı boy), sonra 16 yuva
    rng.shuffle(allp)
    pick = []
    for p in allp:
        if len(pick) >= SLOTS:
            break
        if not any(q.shape == p.shape and np.array_equal(q, p) for q in pick):
            pick.append(p)
    while len(pick) < SLOTS:
        pick.append(pick[len(pick) % max(1, len(pick))])
    slots = []
    for p in pick:
        t = np.zeros((16, 16, 4), np.uint8)
        ph, pw = p.shape[:2]
        ox, oy = rng.randint(0, 16 - pw), rng.randint(0, 16 - ph)
        t[oy:oy + ph, ox:ox + pw] = p
        slots.append(t)
    return slots


def main():
    rng = random.Random(20261022)
    atlas = np.zeros((len(C.ZONE_ORDER) * ROWS * 16, SLOTS * 16, 4), np.uint8)
    for zi, z in enumerate(C.ZONE_ORDER):
        cfg = ZEMIN[z]
        rows = []
        info = []
        for key in ('a', 'b', 'yol'):
            slots, n = fill_tiles(*cfg[key])
            if key == 'b' and cfg.get('su'):
                pass  ## paketin kendi lacivert suyu (kızıla boyanınca su değil leke gibi okunuyordu)
            rows.append(slots)
            info.append('%s %d karo' % (key, n))
        rows.append(decal_slots(cfg['sus'], rng))
        rows.append(decal_slots(cfg['yol_sus'], rng))
        if cfg.get('golcuk_sus'):
            rows.append([sarap(t, 1.9) if cfg.get('su') == 'sarap' else t for t in decal_slots(cfg['golcuk_sus'], rng)])
        for r, slots in enumerate(rows):
            for i, t in enumerate(slots):
                y = (zi * ROWS + r) * 16
                atlas[y:y + 16, i * 16:(i + 1) * 16] = t
        print(z, ', '.join(info))
    Image.fromarray(atlas).save(OUT)
    print('yazıldı', OUT, atlas.shape[1], 'x', atlas.shape[0])


if __name__ == '__main__':
    main()
