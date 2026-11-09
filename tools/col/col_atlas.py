# ALTIN KUMLAR (çöl haritası, 2026-11-09) atlasları: çöl setinin karo sayfaları + tek tek kesilmiş nesneleri proje içine (harita/col/).
# Kaynak (proje DIŞI, salt okunur): ../Harita içerikleri/Col Tileseti/Tiled_files (craftpix çöl seti; örnek harita Desert.tmx).
# Kara Bataklık atlasının (tools/bataklik/bataklik_atlas.py) çöl karşılığı - aynı paket ailesi, aynı karo düzeni.
#
# Zemin sayfaları kaynağın düzeniyle AYNI (üreteç kaynak koordinatlarıyla yazılmış):
#   c_zemin.png = Ground_grass (statik: kum dolgu (2,25), saçaklı çimen bloğu (8,30)+(11,30))
#   c_kiyi.png  = Water_coasts (kum kıyısı (0,1)+(3,1), çimen kıyısı (0,5)+(3,5)); 8 satırlık bantlar animasyon kareleri. Örnekte (Desert.tmx)
#                 yalnız KULLANILAN karoların animasyonu tanımlı (5 kare) -> burada bant 0'daki her dolu karoya kare = taban + 8k satır
#                 (k = 0..5; 6. bant da ayrı, ölçüldü).
#   c_su.png    = water_detilazation_v2 (dalga izleri; Water_detilazation2.tsx animasyonları, kayık kare düzeltmesi)
#   c_leke.png  = spots (çimen lekeleri)       c_filiz.png = sand (rüzgârda sallanan minik filizler, 6 kare, 2 satır aralık)
# Nesne atlasları (kaynak sayfadan opak sınıra kırpılır, karo bloğuna ALTTAN oturur, yatayda ortalı, aralarında 1 boş karo - "atlasta komşu karo =
# aynı nesne" kuralı, depth_occluders / tree_sway / terrain_collision):
#   c_nesne.png  = Objects.png (kaya, harabe, palmiye, ağaç, ölü ağaç, kafatası, firavun kapısı, küre tapınağı, agav...), Details.png (kum tümsekleri,
#                  kemikler, kuru ot, çiçek, yeşil ot) ve Animated_objects.png (şelaleli vaha ağacı + kaya sütunları; kareler bloğun altında alt alta).
#   c_kaktus.png = kaktüsler AYRI doku: terrain_collision.gd SOLID_EVEN_IF_GREEN_TEXTURES - yeşil oldukları hâlde katı (çalı sayılıp içinden geçilmesin).
#   c_calilik.png= saklanma çalılığı atlası (harita/saklanma_calilik.png, 16 maske x 8 çeşit) çölün kuru ot rampasına boyanmış hâli.
# Tablo: tools/col/atlas.json. Kullanım (proje kökünden): python -I tools/col/col_atlas.py
import json
import os
import sys
import xml.etree.ElementTree as ET
from collections import Counter, deque

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.normpath(os.path.join(ROOT, '..', 'Harita içerikleri', 'Col Tileseti', 'Tiled_files'))
OUT = os.path.join(ROOT, 'harita', 'col')
JSON_OUT = os.path.join(ROOT, 'tools', 'col', 'atlas.json')
T = 16
FRAME_MS = 150

KIYI_BAND = 8      ## Water_coasts: animasyon karesi aralığı (satır)
KIYI_FRAMES = 6    ## 6 bant da ayrı kare (örnek Desert.tmx 5'ini kullanıyordu; 6. bant 1.'den farklı, tam döngü)
FILIZ_BAND = 2     ## sand.png: kare aralığı (satır)
FILIZ_FRAMES = 6
GRASS_SHIFT_Y = 736  ## Objects.png: çimen zeminli çeşitler kum çeşitlerinin 46 karo altında (satır 67-112)

## Statik nesneler (Objects.png piksel dikdörtgeni x0, y0, x1, y1 - sınır, kırpma içeride opak sınıra yapılır).
## tür: agac (Ağaç katmanı, sallanır) / nesne (y-sıralı "Animasyonsuz çalılar") / kaya (y-sıralı kaya katmanları, üst üste binebilir) /
##      bitki (sallanan ot) / cicek / yassi (yere serili, karakterin altında: "Yer/Leke") / kaktus (c_kaktus.png, y-sıralı, katı)
## 'g' = çimen zeminli çeşidi de var (dikdörtgen + GRASS_SHIFT_Y): anahtar_s (kum) / anahtar_g (çimen).
STATIC = {
    'kaya_magara': ((8, 7, 93, 88), 'kaya', ''), 'kaya_buyuk': ((115, 16, 186, 80), 'kaya', ''),
    'kemer': ((196, 19, 251, 77), 'nesne', ''), 'kaya_orta': ((257, 33, 304, 78), 'kaya', ''), 'kaya_kucuk': ((321, 50, 352, 79), 'kaya', ''),
    'kaktus_1': ((371, 19, 397, 46), 'kaktus', ''), 'kaktus_2': ((371, 51, 397, 78), 'kaktus', ''),
    'kaktus_3': ((312, 90, 344, 124), 'kaktus', ''), 'kaktus_4': ((360, 90, 392, 124), 'kaktus', ''),
    'yuvarlak_1': ((17, 100, 79, 174), 'agac', ''), 'palmiye_1': ((81, 101, 144, 173), 'agac', ''),
    'yuvarlak_2': ((150, 114, 200, 175), 'agac', ''), 'palmiye_2': ((212, 116, 265, 174), 'agac', ''),
    'palmiye_k1': ((280, 134, 313, 169), 'agac', ''), 'yuvarlak_k1': ((321, 134, 352, 171), 'agac', ''),
    'yuvarlak_3': ((22, 178, 72, 239), 'agac', ''), 'palmiye_3': ((84, 180, 137, 238), 'agac', ''),
    'yuvarlak_b': ((273, 180, 335, 255), 'agac', ''), 'palmiye_b': ((337, 181, 400, 254), 'agac', ''),
    'palmiye_k2': ((152, 198, 185, 233), 'agac', ''), 'yuvarlak_k2': ((193, 198, 224, 235), 'agac', ''),
    'cali_agac_1': ((129, 243, 206, 327), 'agac', ''), 'cali_agac_2': ((215, 259, 280, 327), 'agac', ''),
    'filiz_1': ((23, 250, 42, 264), 'bitki', ''), 'filiz_2': ((19, 277, 47, 298), 'bitki', ''), 'filiz_3': ((20, 305, 59, 335), 'bitki', ''),
    'fici_kaktus_1': ((354, 257, 383, 287), 'kaktus', ''), 'fici_kaktus_2': ((354, 305, 383, 336), 'kaktus', ''),
    'fici_kaktus_3': ((373, 356, 395, 380), 'kaktus', ''), 'fici_kaktus_4': ((373, 388, 395, 412), 'kaktus', ''),
    'mini_kaktus_1': ((385, 257, 399, 272), 'bitki', ''), 'mini_kaktus_2': ((385, 289, 399, 304), 'bitki', ''),
    'mini_kaktus_3': ((385, 417, 399, 430), 'bitki', ''), 'mini_kaktus_4': ((385, 433, 399, 448), 'bitki', ''),
    'cali_1': ((294, 281, 333, 320), 'nesne', ''),
    ## kum + çimen çeşitli (satır 20,8-66)
    'yilan_1': ((14, 333, 95, 419), 'yassi', 'g'), 'yilan_2': ((109, 341, 217, 431), 'yassi', 'g'),
    'kafatasi_k': ((320, 341, 351, 365), 'nesne', 'g'), 'dev_kafatasi': ((243, 343, 308, 393), 'nesne', 'g'),
    'kafatasi_o': ((251, 407, 300, 444), 'nesne', 'g'), 'olu_fidan_1': ((326, 416, 365, 462), 'agac', 'g'),
    'firavun': ((17, 438, 111, 542), 'nesne', 'g'), 'kure': ((112, 453, 187, 527), 'nesne', 'g'),
    'olu_agac_1': ((193, 448, 256, 540), 'agac', 'g'), 'olu_agac_2': ((259, 465, 324, 540), 'agac', 'g'),
    'olu_agac_3': ((338, 466, 398, 530), 'agac', 'g'),
    'olu_dev_1': ((13, 545, 106, 683), 'agac', 'g'), 'olu_dev_2': ((206, 546, 300, 700), 'agac', 'g'),
    'olu_dev_3': ((118, 548, 197, 672), 'agac', 'g'), 'olu_dev_4': ((315, 548, 394, 672), 'agac', 'g'),
    'olu_dev_5': ((14, 690, 108, 844), 'agac', 'g'), 'olu_dev_6': ((118, 690, 211, 828), 'agac', 'g'),
    'olu_kivrik_1': ((236, 708, 310, 816), 'agac', 'g'), 'olu_kivrik_2': ((318, 708, 383, 816), 'agac', 'g'),
    'olu_fidan_2': ((334, 816, 373, 878), 'agac', 'g'), 'olu_kivrik_3': ((183, 837, 247, 950), 'agac', 'g'),
    'olu_kivrik_4': ((256, 837, 321, 950), 'agac', 'g'), 'olu_kivrik_5': ((13, 853, 87, 956), 'agac', 'g'),
    'olu_kivrik_6': ((104, 853, 166, 956), 'agac', 'g'), 'olu_fidan_3': ((336, 881, 375, 943), 'agac', 'g'),
    'cicekli_kaktus_1': ((310, 951, 342, 991), 'kaktus', 'g'), 'cicekli_kaktus_2': ((356, 957, 378, 989), 'kaktus', 'g'),
    'cicekli_kaktus_3': ((385, 967, 399, 988), 'bitki', 'g'),
    'olu_dal_1': ((24, 973, 84, 1060), 'agac', 'g'), 'olu_dal_2': ((99, 973, 159, 1060), 'agac', 'g'),
    'agav_1': ((177, 977, 241, 1047), 'nesne', 'g'), 'agav_2': ((257, 992, 306, 1051), 'nesne', 'g'),
    'agav_3': ((321, 1010, 352, 1049), 'nesne', 'g'),
}
## Animasyonlu nesneler (Animated_objects.png): kare 0 dikdörtgeni, kareler arası yatay adım (px), kare sayısı, tür. Kum / çimen ayrımı
## (dipteki ot tutamı) otomatik: anahtarın sonuna _s / _g.
ANIM = {
    'selale_agaci': ((16, 16, 128, 152), 112, 6, 'nesne'),   ## şelaleli vaha ağacı (gövdesi suda)
    'sutun_1': ((21, 163, 60, 224), 48, 6, 'kaya'), 'sutun_2': ((321, 162, 352, 211), 48, 6, 'kaya'),
    'tas_top_1': ((70, 248, 88, 267), 32, 6, 'kaya'), 'tas_top_2': ((278, 248, 297, 269), 32, 6, 'kaya'),
    'yuz_sutun_1': ((21, 277, 73, 368), 64, 6, 'kaya'), 'sutun_3': ((405, 296, 429, 332), 32, 6, 'kaya'),
    'yuz_sutun_2': ((17, 372, 62, 444), 64, 6, 'kaya'), 'yuz_sutun_3': ((406, 391, 442, 445), 48, 6, 'kaya'),
    'mantar_kaya_1': ((23, 472, 57, 506), 48, 6, 'kaya'), 'mantar_kaya_2': ((343, 472, 377, 507), 48, 6, 'kaya'),
    'mantar_kaya_3': ((19, 516, 44, 541), 32, 6, 'kaya'), 'mantar_kaya_4': ((259, 516, 285, 543), 32, 6, 'kaya'),
    'sutun_4': ((21, 568, 45, 605), 32, 6, 'kaya'), 'sutun_5': ((321, 562, 352, 611), 48, 6, 'kaya'),
}
## Animasyonsuz kırık sütun dipleri (Animated_objects.png, tek kare): yere serili
STUMPS = {'kirik_sutun_1': (25, 240, 57, 258), 'kirik_sutun_2': (411, 352, 448, 369), 'kirik_sutun_3': (474, 352, 502, 364),
          'kirik_sutun_4': (477, 528, 501, 540)}
## Details.png satır bantları (karo satırı) -> tür / takı (bileşenler otomatik bulunur)
DETAIL_BANDS = [(0.0, 6.0, 'tumsek', 'yassi'), (6.0, 8.0, 'kemik', 'yassi'), (8.0, 12.5, 'kuru_ot', 'bitki'),
                (12.5, 15.0, 'cicek', 'cicek'), (15.0, 21.0, 'ot_s', 'bitki'), (21.0, 27.0, 'ot_g', 'bitki'), (27.0, 30.0, 'kemik_g', 'yassi')]
## Objects.png en alt bant (satır 113-121): kemik parçaları (yere serili)
BONE_BAND = (113 * T, 121 * T)


def connected(alpha, gap=0, minpx=12):
    """opak piksel kümeleri (8-komşu + gap) -> [(x0, y0, x1, y1, n)]"""
    h, w = alpha.shape
    lab = np.zeros((h, w), np.int32)
    out = []
    n = 0
    ys, xs = np.nonzero(alpha)
    for y0, x0 in zip(ys, xs):
        if lab[y0, x0]:
            continue
        n += 1
        q = deque([(y0, x0)])
        lab[y0, x0] = n
        py, px = [], []
        while q:
            y, x = q.popleft()
            py.append(y)
            px.append(x)
            for dy in range(-gap - 1, gap + 2):
                for dx in range(-gap - 1, gap + 2):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < h and 0 <= nx < w and alpha[ny, nx] and not lab[ny, nx]:
                        lab[ny, nx] = n
                        q.append((ny, nx))
        if len(py) >= minpx:
            out.append((min(px), min(py), max(px) + 1, max(py) + 1, len(py)))
    return out


def crop_opaque(img, rect):
    x0, y0, x1, y1 = rect
    sub = img.crop((x0, y0, x1, y1))
    bb = sub.getbbox()
    if bb is None:
        return None
    return sub.crop(bb)


def green_ratio(im):
    a = np.array(im).astype(float) / 255.0
    op = a[..., 3] > 0.5
    if op.sum() == 0:
        return 0.0
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    return float(((g > r + 0.05) & (g > b + 0.05) & op).sum()) / float(op.sum())


def base_green(im):
    """alt 6 satırdaki çimen (zeytin ot tutamı) payı: çimen zeminli çeşit mi. Setin çimeni zeytin sarısı (#afa046: kırmızı > yeşil) - "yeşil"
    denetimi değil TON: çimen ~50-75 derece, kum ~40 derece."""
    a = np.array(im.convert('RGB')).astype(float) / 255.0
    al = np.array(im)[..., 3] > 127
    rows = np.nonzero(al.any(axis=1))[0]
    if len(rows) == 0:
        return 0.0
    y0 = max(0, rows[-1] - 5)
    sub, op = a[y0:rows[-1] + 1], al[y0:rows[-1] + 1]
    mx, mn = sub.max(axis=2), sub.min(axis=2)
    d = mx - mn + 1e-6
    r, g, b = sub[..., 0], sub[..., 1], sub[..., 2]
    hue = np.where(mx == r, ((g - b) / d) % 6.0, np.where(mx == g, (b - r) / d + 2.0, (r - g) / d + 4.0)) / 6.0
    sat = d / (mx + 1e-6)
    grass = op & (hue > 0.135) & (hue < 0.30) & (sat > 0.35)
    return float(grass.sum()) / max(1.0, float(op.sum()))


def write_tsx(path, name, img_file, w, h, anims):
    cols = w // T
    lines = ['<?xml version="1.0" encoding="UTF-8"?>',
             '<tileset version="1.10" tiledversion="1.12.2" name="%s" tilewidth="16" tileheight="16" tilecount="%d" columns="%d">' % (name, cols * (h // T), cols),
             ' <image source="%s" width="%d" height="%d"/>' % (img_file, w, h)]
    for tid in sorted(anims):
        lines.append(' <tile id="%d">' % tid)
        lines.append('  <animation>')
        for f in anims[tid]:
            lines.append('   <frame tileid="%d" duration="%d"/>' % (f, FRAME_MS))
        lines.append('  </animation>')
        lines.append(' </tile>')
    lines.append('</tileset>')
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')


def tile_ne(img_np, c, r):
    return img_np[r * T:(r + 1) * T, c * T:(c + 1) * T, 3].any()


def band_anims(img, band, frames, rows):
    """bant 0'daki (satır 0..rows-1) dolu her karo: kare k = taban + band*k satır (kareler dolu olmalı)"""
    a = np.array(img)
    cols = img.width // T
    out = {}
    for r in range(rows):
        for c in range(cols):
            if not tile_ne(a, c, r):
                continue
            fr = []
            for k in range(frames):
                rr = r + band * k
                if (rr + 1) * T > img.height or not tile_ne(a, c, rr):
                    break
                fr.append(rr * cols + c)
            if len(fr) == frames:
                out[r * cols + c] = fr
    return out


def canonical_anims(name, anims):
    offs = Counter(tuple(f - tid for f in fr) for tid, fr in anims.items())
    canon = list(offs.most_common(1)[0][0])
    fixed = 0
    out = {}
    for tid, fr in anims.items():
        want = [tid + o for o in canon]
        if fr != want and len(fr) == len(want):
            fixed += 1
            fr = want
        out[tid] = fr
    if fixed:
        print('  %s: %d animasyonun kayık karesi düzeltildi' % (name, fixed))
    return out


def tsx_anims(path):
    node = ET.parse(path).getroot()
    out = {}
    for t in node.findall('tile'):
        a = t.find('animation')
        if a is not None:
            out[int(t.get('id'))] = [int(f.get('tileid')) for f in a.findall('frame')]
    return out


def build_sheets():
    info = {}
    ## zemin + leke: aynen
    for name, fname, src in [('Çöl zemin', 'c_zemin.png', 'Ground_grass.png'), ('Çöl leke', 'c_leke.png', 'spots.png')]:
        img = Image.open(os.path.join(SRC, src)).convert('RGBA')
        img.save(os.path.join(OUT, fname))
        write_tsx(os.path.join(OUT, name + '.tsx'), name, fname, img.width, img.height, {})
        info[name] = {'file': fname, 'cols': img.width // T, 'w': img.width, 'h': img.height, 'anims': 0}
    ## kıyı
    kimg = Image.open(os.path.join(SRC, 'Water_coasts.png')).convert('RGBA')
    ka = np.array(kimg)
    kimg.save(os.path.join(OUT, 'c_kiyi.png'))
    kan = band_anims(kimg, KIYI_BAND, KIYI_FRAMES, KIYI_BAND)
    kan.pop(0, None)  ## (0,0) düz su karosu (animasyonsuz; bizim su shader'ımız çizer)
    write_tsx(os.path.join(OUT, 'Çöl kıyı.tsx'), 'Çöl kıyı', 'c_kiyi.png', kimg.width, kimg.height, kan)
    info['Çöl kıyı'] = {'file': 'c_kiyi.png', 'cols': kimg.width // T, 'w': kimg.width, 'h': kimg.height, 'anims': len(kan)}
    ## su dalga izleri
    simg = Image.open(os.path.join(SRC, 'water_detilazation_v2.png')).convert('RGBA')
    simg.save(os.path.join(OUT, 'c_su.png'))
    san = canonical_anims('Çöl su', tsx_anims(os.path.join(SRC, 'Water_detilazation2.tsx')))
    for tid, fr in san.items():
        d = [fr[i + 1] - fr[i] for i in range(len(fr) - 1)]
        assert len(set(d)) == 1, (tid, fr)
    write_tsx(os.path.join(OUT, 'Çöl su.tsx'), 'Çöl su', 'c_su.png', simg.width, simg.height, san)
    info['Çöl su'] = {'file': 'c_su.png', 'cols': simg.width // T, 'w': simg.width, 'h': simg.height, 'anims': len(san)}
    ## filizler
    fimg = Image.open(os.path.join(SRC, 'sand.png')).convert('RGBA')
    fimg.save(os.path.join(OUT, 'c_filiz.png'))
    fan = band_anims(fimg, FILIZ_BAND, FILIZ_FRAMES, FILIZ_BAND)
    write_tsx(os.path.join(OUT, 'Çöl filiz.tsx'), 'Çöl filiz', 'c_filiz.png', fimg.width, fimg.height, fan)
    info['Çöl filiz'] = {'file': 'c_filiz.png', 'cols': fimg.width // T, 'w': fimg.width, 'h': fimg.height, 'anims': len(fan)}
    return info


def collect_items():
    """-> [{key, kind, atlas, frames: [Image]}]"""
    obj = Image.open(os.path.join(SRC, 'Objects.png')).convert('RGBA')
    det = Image.open(os.path.join(SRC, 'Details.png')).convert('RGBA')
    ani = Image.open(os.path.join(SRC, 'Animated_objects.png')).convert('RGBA')
    items = []

    def add(key, kind, frames):
        items.append({'key': key, 'kind': kind, 'atlas': 'kaktus' if kind == 'kaktus' else 'nesne', 'frames': frames})

    for key, (rect, kind, var) in STATIC.items():
        if var == 'g':
            im = crop_opaque(obj, rect)
            add(key + '_s', kind, [im])
            x0, y0, x1, y1 = rect
            img = crop_opaque(obj, (x0 - 2, y0 + GRASS_SHIFT_Y - 2, x1 + 2, y1 + GRASS_SHIFT_Y + 2))
            add(key + '_g', kind, [img])
        else:
            add(key, kind, [crop_opaque(obj, rect)])
    ## animasyonlu: kareler ortak sınıra kırpılır
    for key, (rect, step, n, kind) in ANIM.items():
        x0, y0, x1, y1 = rect
        raw = [ani.crop((x0 + k * step, y0, x1 + k * step, y1)) for k in range(n)]
        bb = None
        for f in raw:
            b = f.getbbox()
            if b:
                bb = b if bb is None else (min(bb[0], b[0]), min(bb[1], b[1]), max(bb[2], b[2]), max(bb[3], b[3]))
        frames = [f.crop(bb) for f in raw]
        suffix = '_g' if base_green(frames[0]) > 0.12 else '_s'
        add(key + ('' if key == 'selale_agaci' else suffix), kind, frames)
    for key, rect in STUMPS.items():
        im = crop_opaque(ani, rect)
        add(key, 'yassi', [im])
    ## Details.png: bileşenler, bantlara göre
    da = np.array(det)[..., 3] > 0
    counters = Counter()
    for (x0, y0, x1, y1, n) in sorted(connected(da, 0, 18), key=lambda t: (t[1] // 8, t[0])):
        ty = (y0 + y1) / 2.0 / T
        for (b0, b1, tag, kind) in DETAIL_BANDS:
            if b0 <= ty < b1:
                counters[tag] += 1
                add('d_%s_%d' % (tag, counters[tag]), kind, [det.crop((x0, y0, x1, y1))])
                break
    ## kemik parçaları (Objects.png satır 113-121)
    oa = np.array(obj)[..., 3] > 0
    sub = np.zeros_like(oa)
    sub[BONE_BAND[0]:BONE_BAND[1]] = oa[BONE_BAND[0]:BONE_BAND[1]]
    k = 0
    for (x0, y0, x1, y1, n) in sorted(connected(sub, 1, 40), key=lambda t: (t[1] // 16, t[0])):
        k += 1
        im = obj.crop((x0, y0, x1, y1))
        add('kemik_parca_%d%s' % (k, '_g' if base_green(im) > 0.12 else '_s'), 'yassi', [im])
    return items


def pack(items, atlas_name, file_name, cols=64):
    items = [it for it in items if it['atlas'] == atlas_name]
    for it in items:
        w, h = it['frames'][0].size
        it['w'], it['h'] = w, h
        it['wt'], it['ht'] = (w + T - 1) // T, (h + T - 1) // T
    items.sort(key=lambda it: (-(it['ht'] * len(it['frames']) + len(it['frames']) - 1), -it['wt'], it['key']))
    x = y = 0
    shelf_h = 0
    for it in items:
        nf = len(it['frames'])
        bh = it['ht'] * nf + (nf - 1)
        if x + it['wt'] > cols:
            x = 0
            y += shelf_h + 1
            shelf_h = 0
        it['ax'], it['ay'] = x, y
        x += it['wt'] + 1
        shelf_h = max(shelf_h, bh)
    rows = y + shelf_h
    atlas = Image.new('RGBA', (cols * T, rows * T), (0, 0, 0, 0))
    anims = {}
    catalog = {}
    for it in items:
        wt, ht = it['wt'], it['ht']
        ox = (wt * T - it['w']) // 2
        oy = ht * T - it['h']
        for k, f in enumerate(it['frames']):
            atlas.alpha_composite(f, (it['ax'] * T + ox, (it['ay'] + k * (ht + 1)) * T + oy))
        if len(it['frames']) > 1:
            for ty in range(ht):
                for tx in range(wt):
                    base = (it['ay'] + ty) * cols + it['ax'] + tx
                    anims[base] = [(it['ay'] + ty + k * (ht + 1)) * cols + it['ax'] + tx for k in range(len(it['frames']))]
        catalog[it['key']] = {'kind': it['kind'], 'ts': atlas_name, 'ax': it['ax'], 'ay': it['ay'], 'wt': wt, 'ht': ht,
                              'frames': len(it['frames']), 'ox': ox, 'oy': oy, 'w': it['w'], 'h': it['h'],
                              'green': round(green_ratio(it['frames'][0]), 3),
                              'cimen': base_green(it['frames'][0]) > 0.12}  ## dibinde çimen tutamı: çimen zeminde kullanılır
    atlas.save(os.path.join(OUT, file_name))
    tname = 'Çöl nesne' if atlas_name == 'nesne' else 'Çöl kaktüs'
    write_tsx(os.path.join(OUT, tname + '.tsx'), tname, file_name, atlas.width, atlas.height, anims)
    return catalog, {'file': file_name, 'cols': cols, 'w': atlas.width, 'h': atlas.height, 'anims': len(anims)}


## Saklanma çalılığı: KURU UZUN OT (atlasın uzun yaprak satırları 0-3 kullanılır, üreteç place_brush). Rampa saman sarısı: koyu dip
## (zeytin-kahve gölge) -> parlak saman ucu; çölde koyu bir halı gibi durmasın, vaha çimeninin üstünde uzun kuru ot gibi okunsun.
DESERT_RAMP = [(58, 52, 24), (82, 76, 31), (104, 95, 39), (126, 113, 46), (146, 129, 52), (164, 145, 58), (181, 159, 64), (196, 172, 71),
               (209, 184, 79), (221, 197, 92), (232, 210, 108)]


def build_brush():
    src = Image.open(os.path.join(ROOT, 'harita', 'saklanma_calilik.png')).convert('RGBA')
    px = src.load()
    cols = sorted({px[x, y][:3] for y in range(src.height) for x in range(src.width) if px[x, y][3] > 0},
                  key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2])
    lum = [0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2] for c in cols]
    lo, hi = lum[0], lum[-1]
    m = {}
    for c, l in zip(cols, lum):
        t = (l - lo) / max(1e-6, hi - lo)
        i = min(len(DESERT_RAMP) - 1, int(round(t * (len(DESERT_RAMP) - 1))))
        m[c] = DESERT_RAMP[i]
    out = Image.new('RGBA', src.size)
    op = out.load()
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = px[x, y]
            op[x, y] = m[(r, g, b)] + (a,) if a > 0 else (0, 0, 0, 0)
    out.save(os.path.join(OUT, 'c_calilik.png'))
    write_tsx(os.path.join(OUT, 'Çöl çalılık.tsx'), 'Çöl çalılık', 'c_calilik.png', out.width, out.height, {})
    return {'file': 'c_calilik.png', 'cols': out.width // T, 'w': out.width, 'h': out.height, 'anims': 0}


def ensure_base_tiles():
    """c_taban.png: 0 = düz mavi su (collision su sayar; görünüşü col_su.gdshader), 1 = tamamen saydam (görünmez engel)."""
    img = Image.new('RGBA', (32, 16), (0, 0, 0, 0))
    for y in range(16):
        for x in range(16):
            img.putpixel((x, y), (40, 96, 200, 255))
    img.save(os.path.join(OUT, 'c_taban.png'))
    write_tsx(os.path.join(OUT, 'Çöl taban.tsx'), 'Çöl taban', 'c_taban.png', 32, 16, {})
    return {'file': 'c_taban.png', 'cols': 2, 'w': 32, 'h': 16, 'anims': 0}


def main():
    if not os.path.isdir(SRC):
        print('Kaynak klasör yok:', SRC)
        sys.exit(1)
    os.makedirs(OUT, exist_ok=True)
    sheets = build_sheets()
    sheets['Çöl taban'] = ensure_base_tiles()
    items = collect_items()
    cat_n, inf_n = pack(items, 'nesne', 'c_nesne.png')
    cat_k, inf_k = pack(items, 'kaktus', 'c_kaktus.png', cols=24)
    sheets['Çöl nesne'] = inf_n
    sheets['Çöl kaktüs'] = inf_k
    sheets['Çöl çalılık'] = build_brush()
    catalog = dict(cat_n)
    catalog.update(cat_k)
    with open(JSON_OUT, 'w', encoding='utf-8') as f:
        json.dump({'sheets': sheets, 'objects': catalog}, f, ensure_ascii=False, indent=1, sort_keys=True)
    for k, v in sheets.items():
        print('%-14s %s %dx%d anim=%d' % (k, v['file'], v['w'], v['h'], v['anims']))
    kinds = Counter(v['kind'] for v in catalog.values())
    print('nesne: %d  %s' % (len(catalog), dict(kinds)))


if __name__ == '__main__':
    main()
