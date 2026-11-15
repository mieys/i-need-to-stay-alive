# AYAZ DAĞI haritası üreteci (kış / dağ, 2026-11-12; kullanıcı: "bu assetleri kullanarak ana haritanın büyüklüğünde yeni bir harita ... belli
# yerlerde meşale ve ateşli ilgi alanları olmalı çünkü bu haritadan sonra üşüme ve ısınma mekaniği ekleyeceğim ... güzel kış-dağ temalı cozy").
# Oyun alanı 256x256 hücre (= ana haritanın alanı) + ana harita gibi 32/20 hücrelik geçilmez dış çerçeve. Sonlu TMX: oyun alanı hücre (32,20)'den.
# Altın Kumlar üretecinin (tools/col/gen_col.py) kış karşılığı: aynı katman adları (Harita.tmx), aynı köşe ızgarası arazisi, aynı collision
# taklidi + cep mühürleme, aynı md5 kapısı.
#
# ARAZİ = köşe ızgarası (dual grid): kar (taban) / donmuş göl (BUZ, yürünür) / sıcak kaynak (SU, yürünmez) / toprak patika. Kar her yerde dolgu
# (12,30); toprak = setin toprak adası bloğu (1,29)+(4,29) karın üstünde (kenarı kar topakları); göl / kaynak kıyısı = setin kar adası bloğu
# (11,29)+(14,29) buzun / suyun üstünde. Toprak buza / suya 2 köşeden yaklaşmaz (bir hücrede iki kenar türü olmasın). Çapraz köşe (6/9) yok.
#
# ISINMA NOKTALARI (ileride üşüme / ısınma mekaniği için; kis_meta.gd HEAT_SOURCES = [tür, dünya konumu, yarıçap px]): doğuş kampı, avcı kampı,
# totem tapınağının mangalları, yılbaşı meydanı, sıcak kaynak, eski harabenin şenlik mangalı + bütün yol meşaleleri. Kuzey (Kadim Buz Ağacı,
# Kristal Vadisi) bilerek ateşsiz: haritanın soğuk yarısı. Ateşlerin çevresinde kar erimiş (toprak halka).
#
# ÇİZİM SIRASI: Altın Kumlar ile aynı kurallar (y-sıralı nesneler 4 katman, ağaçlar 8 katman, ot/çiçek Çalılar / Çalılar1).
#
# Kullanım (proje kökünden):
#   python -I tools/kis/gen_kis.py            -> önizleme + rapor (tools/kis/out/), TMX'e yazmaz
#   python -I tools/kis/gen_kis.py --write    -> harita/kis.tmx + assets/ui/minimap_kis.png + scripts/kis_meta.gd (md5 kapısı; --force ezer)
#   Sonra: Godot --headless --path . --import, Godot --headless --path . -s tools/kis/bake_kis.gd
import hashlib
import json
import math
import os
import random
import sys
from collections import deque

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.dirname(HERE))
import harita_duvar  ## noqa: E402 (tools/harita_duvar.py, madde 676)
ATLAS = json.load(open(os.path.join(HERE, 'atlas.json'), encoding='utf-8'))
HDIR = os.path.join(ROOT, 'harita')
KDIR = os.path.join(HDIR, 'kis')
OUT_DIR = os.path.join(HERE, 'out')
TMX_PATH = os.path.join(HDIR, 'kis.tmx')
MINIMAP_PATH = os.path.join(ROOT, 'assets', 'ui', 'minimap_kis.png')
META_PATH = os.path.join(ROOT, 'scripts', 'kis_meta.gd')
MD5_PATH = os.path.join(HERE, 'son_yazim.md5')
SEED = 20261112
FH = 0x80000000  ## Tiled yatay çevirme bayrağı

## SÜS YOĞUNLUĞU (madde 527 / 529 dersi: göz yormasın) - tek yer.
YOGUNLUK = {
    'serit_deneme': 30000,     ## dağ şeridi yerleştirme denemesi
    'serit_aralik': 2,         ## şeritte kök hücreleri arası (Chebyshev) en az
    'koru_aralik': 3,          ## iç çam korularında gövde aralığı
    'tek_agac': 70,            ## karda tek tük ağaç
    'kaya': 70,                ## dağınık kaya / taş
    'kardan_adam': 9,          ## haritaya serpiştirilmiş kardan adam
    'bitki': 0.006,            ## kar hücresi başına küçük bitki (buz çiçeği, diken çiçeği, kristal filiz)
    'kar_obek': 700,           ## kar öbeği denemesi
    'leke': 700,               ## kar / toprak lekesi denemesi
    'iz': 26,                  ## ayak izi grubu
    'meşale_aralik': 15,       ## yol boyunca meşaleler arası (hücre, yay uzunluğu)
    'su_dalga': 0.05,          ## sıcak kaynakta tam su hücresi başına dalga izi
    'catlak': 0.012,           ## tam buz hücresi başına çatlak denemesi (sık olunca göl benekli duruyordu)
}

T = 16
PLAY = 256
RX, RY = 32, 20
W, H = PLAY + 2 * RX, PLAY + 2 * RY  ## 320 x 296 hücre
PX0, PY0 = RX, RY

TS_ORDER = [('taban', 'kis/Kış taban.tsx', 'Kış taban'), ('zemin', 'kis/Kış zemin.tsx', 'Kış zemin'), ('catlak', 'kis/Kış çatlak.tsx', 'Kış çatlak'),
            ('leke', 'kis/Kış leke.tsx', 'Kış leke'), ('su', 'kis/Kış su.tsx', 'Kış su'), ('nesne', 'kis/Kış nesne.tsx', 'Kış nesne'),
            ('calilik', 'kis/Kış çalılık.tsx', 'Kış çalılık')]
TILESETS = []
TS_FILES = {}
for _k, _p, _n in TS_ORDER:
    _s = ATLAS['sheets'][_n]
    TILESETS.append((_k, _p, _s['cols'], _s['cols'] * (_s['h'] // T)))
    TS_FILES[_k] = _s['file']

BLOCK_DIRT = ('zemin', (1, 29), (4, 29))    ## toprak adası (kenarı kar topakları) - karın üstünde
BLOCK_SNOW = ('zemin', (11, 29), (14, 29))  ## kar adası - buzun / suyun üstünde (göl / kaynak kıyısı)
SNOW_FILL = ('zemin', (12, 30))
ICE_FILLS = [(1, 45), (4, 45), (7, 45), (10, 45), (13, 45)]  ## 2x2 dikişsiz buz dokuları (sol üst karo)
WATER_TILE = ('taban', (0, 0))
BLOCKER_TILE = ('taban', (1, 0))

OBJ_LAYERS = ['Animasyonsuz çalılar', 'Kayalar 1', 'Kayalar 2', 'Kayalar 3']
LAYERS = [
    ('Yer', 'Zemin Toprak'), ('Yer', 'Buz'), ('Yer', 'Zemin Çimen'), ('Yer', 'Patika'), ('Yer', 'Leke'), ('Yer', 'Kar süsleri'),
    ('Su', 'Su'), ('Su', 'Su süsleri'), ('Su', 'Su ayrıntılar 2'),
    ('Orman parçaları', 'Saklanma Çalılığı'), ('Orman parçaları', 'Orman parçaları'),
    ('Shader Eklenecek', 'Çiçekler 1'), ('Shader Eklenecek', 'Çalılar'), ('Shader Eklenecek', 'Çalılar1'),
] + [('Shader Eklenecek', n) for n in OBJ_LAYERS] + [('Shader Eklenecek', 'Ağaç %d' % i) for i in range(8)]
TREE_LAYERS = 8

## terrain_collision.gd sabitleri (ayak izi taklidi)
FEET_SHIFT = 15.0
MIN_PIXELS = 20
TREE_BAND = 9.0
WATER_MIN_PIXELS = 100
PROP_MIN_W, PROP_MIN_H, PROP_MIN_PIXELS, PROP_MIN_DENSITY, PROP_MAX_GREEN = 18, 14, 220, 0.35, 0.4
PROP_SMALL_AREA, PROP_SMALL_MAX_SOFT = 700.0, 0.15

rng = random.Random(SEED)


def P(x, y):
    return x + PX0, y + PY0


## ---------------------------------------------------------------- tasarım (oyun alanı yerel hücre, 0..255)
## YERLEŞİM (madde 658, 2026-11-13, kullanıcı: "yaptığın haritalar hep birbirine benziyor hepsinin ortasında göl var"): ortadaki Ayna Göl ve
## çevresindeki halka yol KALDIRILDI. Harita artık DAĞ haritası: AYAZ DAĞI kuzey kenarından haritanın ortasına inen geçilmez bir sırt (kuzeyi iki
## vadiye böler), Kadim Buz Ağacı sırtın ucunda; büyük donmuş göl güneydoğu köşesine kaydı; kuzeybatı vadisinde donmuş dereyle bağlı dört
## küçük buz gölü (tespih göller). Doğuş güneybatıda, yollar halka değil kıvrımlı bir döngü. Kara Bataklık = nehir, Altın Kumlar = kaya platoları.
SPAWN = (52, 216)
REGIONS = {
    'kamp': (52, 214),        ## doğuş (GB): Ocak Başı Kampı (büyük mangal + kazanlı kamp ateşi, çadırlar, kütükler)
    'gol': (194, 172),        ## GD: Ayna Göl - büyük donmuş göl (yürünür), kıyısında olta delikleri
    'buz_agaci': (140, 120),  ## orta: dağ sırtının ucunda Kadim Buz Ağacı (dev buz ağacı, buz kristalleri) - soğuk, ateşsiz
    'totem': (40, 40),        ## KB vadisi: Ayı Totemi Tapınağı (totemler + mangallar + harabe)
    'kristal': (210, 44),     ## KD vadisi: Kristal Vadisi (dev kristaller, buz ağaçları) - soğuk, ateşsiz
    'yilbasi': (44, 146),     ## B: Yılbaşı Meydanı (süslü çam, kardan adamlar, meşale halkası, kamp ateşi)
    'kaplica': (226, 108),    ## D: Sıcak Kaynak (buharı tüten su, meşaleler)
    'mantar': (130, 224),     ## G: Karlı Mantar Korusu
    'harabe': (226, 228),     ## GD köşe: Eski Harabe (yıkık taş ev / kule / kemer, şenlik mangalı)
    'avci': (72, 100),        ## KB vadisinin ağzı: Avcı Kampı (çadır + kamp ateşi), tespih göllerin yanında
}
CLEARINGS = {'kamp': 14, 'gol': 0, 'buz_agaci': 11, 'totem': 10, 'kristal': 9, 'yilbasi': 11, 'kaplica': 10, 'mantar': 7, 'harabe': 10,
             'avci': 7}
## AYAZ DAĞI sırtı (geçilmez; dış şerit gibi iç kenarında kaya tepeleri, içi sık karlı çam): üst üste binen elipsler (x, y, rx, ry, açı)
RIDGE = [(128, -8, 46, 30, 0.0), (124, 28, 30, 22, 0.1), (130, 60, 20, 18, -0.15), (136, 86, 13, 12, 0.2), (112, 18, 12, 10, 0.4),
         (150, 40, 12, 10, -0.3)]
## Donmuş göller: (merkez x, y, yarıçap x, y, ek loblar [(x, y, rx, ry)]); ilk = Ayna Göl (olta delikleri onun kıyısında)
LAKES = [
    (194, 172, 25, 14, [(171, 167, 9, 6), (215, 179, 10, 6), (200, 159, 8, 5), (186, 186, 9, 4), (208, 166, 7, 5)]),
    (74, 30, 5.5, 3.6, []),                   ## tespih göller (KB vadisi, kuzeyden güneye)
    (84, 54, 6.5, 4.2, [(89, 57, 3, 2)]),
    (92, 78, 5.5, 3.8, []),
    (100, 100, 6.0, 4.0, [(95, 103, 3, 2)]),
    (30, 96, 5, 3.4, []),
    (230, 68, 4.6, 3.2, []),
    (158, 208, 4.5, 3.0, []),
    (20, 182, 4.2, 3.0, []),
    (178, 92, 4.2, 3.0, []),
    (98, 160, 5.0, 3.2, [(102, 163, 2.5, 2)]),
]
## Donmuş dereler (yürünür buz şeridi): tespih gölleri birbirine bağlar - (orta çizgi noktaları, yarı genişlik köşe)
ICE_STREAMS = [([(74, 30), (80, 42), (84, 54), (88, 66), (92, 78), (96, 90), (100, 100)], 1.3)]
## Sıcak kaynak (açık su, yürünmez): (merkez x, y, rx, ry, loblar)
SPRINGS = [(226, 105, 5.0, 3.4, [(231, 108, 2.6, 2.0)])]
## Patikalar (toprak yol): yerel hücre noktaları. Döngü: kamp -> Yılbaşı -> Buz Ağacı -> Mantar -> kamp; kollar vadilere ve göl kıyısına.
PATHS = [
    [(52, 210), (48, 192), (42, 172), (44, 154)],                                          ## kamp -> yılbaşı
    [(44, 140), (56, 124), (64, 110), (68, 100), (62, 82), (54, 64), (46, 50), (40, 46)],  ## yılbaşı -> avcı -> KB vadisi -> totem
    [(52, 146), (72, 138), (96, 132), (116, 126), (130, 122)],                             ## yılbaşı -> buz ağacı
    [(56, 220), (76, 226), (98, 228), (118, 226), (128, 224)],                             ## kamp -> mantar
    [(130, 220), (128, 200), (134, 178), (138, 154), (140, 134)],                          ## mantar -> buz ağacı
    [(134, 228), (156, 226), (178, 220), (200, 216), (220, 226)],                          ## mantar -> göl güney kıyısı -> harabe
    [(152, 122), (172, 118), (194, 116), (214, 110), (222, 108)],                          ## buz ağacı -> sıcak kaynak (gölün kuzeyi)
    [(226, 100), (224, 84), (218, 66), (212, 50)],                                         ## kaynak -> KD vadisi -> kristal
]
PATH_R = 1.7      ## yol yarı genişliği (köşe)
## Ateşin çevresinde eriyen kar (toprak halka): (merkez x, y, yarıçap) köşe - bölgenin ateşlerini kapsar
MELT = [(52, 214, 7.0), (72, 100, 4.5), (40, 40, 5.5), (44, 149, 5.5), (226, 229, 6.0)]
BRUSH_COUNT = 10
## İç çam koruları (sık ağaç kümeleri; aralarından geçilir): (x, y, yarıçap)
GROVES = [(24, 118, 6), (64, 164, 7), (92, 198, 6), (96, 148, 6), (166, 142, 6), (150, 194, 6), (110, 112, 5), (236, 142, 6),
          (244, 200, 5), (196, 240, 6), (160, 240, 5), (22, 214, 5), (74, 238, 5), (186, 64, 6), (238, 36, 6), (176, 30, 5), (20, 68, 6),
          (54, 84, 5), (162, 102, 5), (206, 136, 5), (118, 178, 6), (80, 182, 5)]
## Dağ kayası kümeleri (dağ sırtının eteği + kuzey köşeler): (x, y, yarıçap)
ROCK_CLUSTERS = [(104, 64, 5), (158, 60, 5), (116, 96, 4), (158, 90, 4), (58, 18, 4), (198, 20, 4), (24, 160, 4), (244, 236, 4)]

## Nesne grupları
PINES = ['cam_1', 'cam_2', 'cam_3']
ROUND_PINES = ['cam_yuvarlak_1', 'cam_yuvarlak_2', 'cam_yuvarlak_3']
ROUND = ['yuvarlak_agac_1', 'yuvarlak_agac_2', 'yuvarlak_agac_3']
RED = ['kizil_agac_1', 'kizil_agac_2', 'kizil_agac_3']
ICE_TREES = ['buz_agaci_1', 'buz_agaci_2', 'buz_agaci_3']
MUSH_TREES = ['mantar_agac_1', 'mantar_agac_2', 'mantar_agac_3']
ROCKS = ['kaya_buyuk', 'kaya_orta', 'kaya_kucuk', 'kaya_yigin', 'kaya_yay']
RUINS = ['harabe_ev', 'harabe_kule', 'harabe_kemer', 'harabe_duvar', 'harabe_kucuk']
SNOWMEN = ['kardan_adam_1', 'kardan_adam_2', 'kardan_adam_3', 'kardan_adam_4']
SNOWMEN_SMALL = ['kardan_adam_5', 'kardan_adam_6']
CRYSTALS = ['kristal_dev', 'kristal_2', 'kristal_3', 'buz_kristal_1', 'buz_kristal_2', 'kizil_kristal_1', 'kizil_kristal_2']
MESAS = ['tepe_s', 'tepe_krater_s']
MESAS_G = ['tepe_g', 'tepe_krater_g', 'tepe_yuksek_g', 'tepe_krater_yuksek_g']
NO_FLIP = {'dev_buz_agaci', 'yilbasi_agaci', 'totem_1', 'totem_2', 'kamp_atesi', 'mesale', 'mangal', 'buyuk_mangal', 'cadir_1', 'cadir_2',
           'harabe_ev', 'harabe_kule', 'harabe_kemer', 'kardan_adam_1', 'kardan_adam_2', 'kardan_adam_3', 'kardan_adam_4'}
FIRE_KEYS = {'kamp_atesi', 'mesale', 'mangal', 'buyuk_mangal'}
## Isınma noktası yarıçapı (dünya px; ileride üşüme / ısınma mekaniği okur) + gece ışığı türü
HEAT_RADIUS = {'kamp_atesi': 120.0, 'buyuk_mangal': 150.0, 'mangal': 90.0, 'mesale': 64.0, 'kaplica': 170.0}


## ---------------------------------------------------------------- gürültü + yardımcılar (Altın Kumlar üretecinden)
def value_noise(shape, scale, seed):
    r = np.random.default_rng(seed)
    gh, gw = int(shape[0] / scale) + 3, int(shape[1] / scale) + 3
    g = r.random((gh, gw))
    ys = np.arange(shape[0]) / scale
    xs = np.arange(shape[1]) / scale
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    fy = ys - y0
    fx = xs - x0
    fy = fy * fy * (3 - 2 * fy)
    fx = fx * fx * (3 - 2 * fx)
    a = g[y0][:, x0]
    b = g[y0][:, x0 + 1]
    c = g[y0 + 1][:, x0]
    d = g[y0 + 1][:, x0 + 1]
    top = a + (b - a) * fx[None, :]
    bot = c + (d - c) * fx[None, :]
    return top + (bot - top) * fy[:, None]


def fbm(shape, scale, seed, octaves=3):
    tot = np.zeros(shape)
    amp = 1.0
    norm = 0.0
    for o in range(octaves):
        tot += value_noise(shape, scale / (2 ** o), seed + o * 101) * amp
        norm += amp
        amp *= 0.5
    return tot / norm


def fix_diagonals(v, prefer=None):
    for _ in range(60):
        a = v[:-1, :-1]
        b = v[:-1, 1:]
        c = v[1:, :-1]
        d = v[1:, 1:]
        diag1 = a & d & ~b & ~c
        diag2 = b & c & ~a & ~d
        bad = diag1 | diag2
        if not bad.any():
            return v
        ys, xs = np.nonzero(bad)
        for y, x in zip(ys, xs):
            if prefer is None:
                win = v[max(0, y - 1):y + 3, max(0, x - 1):x + 3]
                fill = win.mean() >= 0.5
            else:
                fill = prefer
            if diag1[y, x]:
                if fill:
                    v[y, x + 1] = True
                    v[y + 1, x] = True
                else:
                    v[y, x] = False
                    v[y + 1, x + 1] = False
            else:
                if fill:
                    v[y, x] = True
                    v[y + 1, x + 1] = True
                else:
                    v[y, x + 1] = False
                    v[y + 1, x] = False
    raise RuntimeError('çapraz temizliği bitmedi')


def remove_small(v, min_size, value=True):
    vh, vw = v.shape
    seen = np.zeros_like(v, bool)
    for y in range(vh):
        for x in range(vw):
            if v[y, x] != value or seen[y, x]:
                continue
            comp = []
            q = deque([(y, x)])
            seen[y, x] = True
            while q:
                cy, cx = q.popleft()
                comp.append((cy, cx))
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = cy + dy, cx + dx
                    if 0 <= ny < vh and 0 <= nx < vw and not seen[ny, nx] and v[ny, nx] == value:
                        seen[ny, nx] = True
                        q.append((ny, nx))
            if len(comp) < min_size:
                for cy, cx in comp:
                    v[cy, cx] = not value
    return v


def corner_code(v, x, y):
    """hücre (x, y) köşeleri: KB=1, KD=2, GB=4, GD=8"""
    return int(v[y, x]) | (int(v[y, x + 1]) << 1) | (int(v[y + 1, x]) << 2) | (int(v[y + 1, x + 1]) << 3)


def block_tile(block, code):
    ts, (bx, by), (ix, iy) = block
    m = {8: (bx, by), 12: (bx + 1, by), 4: (bx + 2, by), 10: (bx, by + 1), 15: (bx + 1, by + 1), 5: (bx + 2, by + 1),
         2: (bx, by + 2), 3: (bx + 1, by + 2), 1: (bx + 2, by + 2), 7: (ix, iy), 11: (ix + 1, iy), 13: (ix, iy + 1), 14: (ix + 1, iy + 1)}
    return ts, m[code]


def cheb_dist(mask, maxd):
    d = np.where(mask, 0, maxd + 1)
    cur = mask.copy()
    for i in range(1, maxd + 1):
        grown = cur.copy()
        grown[1:, :] |= cur[:-1, :]
        grown[:-1, :] |= cur[1:, :]
        grown[:, 1:] |= cur[:, :-1]
        grown[:, :-1] |= cur[:, 1:]
        grown[1:, 1:] |= cur[:-1, :-1]
        grown[:-1, :-1] |= cur[1:, 1:]
        grown[1:, :-1] |= cur[:-1, 1:]
        grown[:-1, 1:] |= cur[1:, :-1]
        d = np.where(grown & ~cur & (d > i), i, d)
        cur = grown
    return d


def smooth_mask(v, iters):
    v = v.copy()
    for _ in range(iters):
        p = np.pad(v.astype(np.int32), 1, mode='edge')
        s = sum(p[1 + dy:p.shape[0] - 1 + dy, 1 + dx:p.shape[1] - 1 + dx] for dy in (-1, 0, 1) for dx in (-1, 0, 1))
        v = s >= 5
    return v


def nonempty_tiles(img):
    h, w = img.shape[0] // T, img.shape[1] // T
    return img[:h * T, :w * T, 3].reshape(h, T, w, T).max(axis=(1, 3)) > 0


def components(mask, r0, r1):
    seen = set()
    out = []
    h, w = mask.shape
    for r in range(r0, r1):
        for c in range(w):
            if not mask[r, c] or (c, r) in seen:
                continue
            comp = []
            st = [(c, r)]
            seen.add((c, r))
            while st:
                cc, rr = st.pop()
                comp.append((cc, rr))
                for dc in (-1, 0, 1):
                    for dr in (-1, 0, 1):
                        nc, nr = cc + dc, rr + dr
                        if r0 <= nr < r1 and 0 <= nc < w and mask[nr, nc] and (nc, nr) not in seen:
                            seen.add((nc, nr))
                            st.append((nc, nr))
            out.append(comp)
    return out


def load_sheets():
    imgs = {}
    for key, _, _, _ in TILESETS:
        imgs[key] = np.array(Image.open(os.path.join(KDIR, TS_FILES[key])).convert('RGBA'))
    return imgs


def obj(key):
    return ATLAS['objects'][key]


def variant(key, ground):
    """kar / toprak çeşidi: anahtar_s / anahtar_g (yoksa çeşitsiz anahtar)"""
    want = key + ('_g' if ground == 'dirt' else '_s')
    if want in ATLAS['objects']:
        return want
    if key + '_s' in ATLAS['objects']:
        return key + '_s'
    return key


## ---------------------------------------------------------------- harita durumu
class Map:
    def __init__(self, imgs):
        self.imgs = imgs
        self.layers = {name: {} for _, name in LAYERS}
        self.ne = {'nesne': nonempty_tiles(imgs['nesne'])}
        self.objects = []
        self.cover = {}
        self.base_cells = set()
        self.meta_lights = []
        self.heat = []
        self.smoke = []
        self._stamps = {}

    def put(self, layer, cell, ts, coord, flip=False):
        x, y = cell
        if 0 <= x < W and 0 <= y < H:
            self.layers[layer][(x, y)] = (ts, coord, flip)

    ## Nesnenin karoları: dolu karolar + onları 4-komşu BAĞLAYAN saydam karolar (madde 524 tuzağı).
    def stamp(self, key):
        if key in self._stamps:
            return self._stamps[key]
        o = obj(key)
        ne = self.ne[o['ts']]
        full = {(tx, ty) for ty in range(o['ht']) for tx in range(o['wt']) if ne[o['ay'] + ty, o['ax'] + tx]}
        tiles = set(full)
        while True:
            comps = []
            seen = set()
            for t in sorted(tiles):
                if t in seen:
                    continue
                comp = {t}
                st = [t]
                seen.add(t)
                while st:
                    a = st.pop()
                    for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        b = (a[0] + d[0], a[1] + d[1])
                        if b in tiles and b not in seen:
                            seen.add(b)
                            comp.add(b)
                            st.append(b)
                comps.append(comp)
            if len(comps) <= 1:
                break
            comps.sort(key=len, reverse=True)
            main_c, other = comps[0], comps[1]
            prev = {t: None for t in other}
            q = deque(other)
            hit = None
            while q:
                a = q.popleft()
                if a in main_c:
                    hit = a
                    break
                for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    b = (a[0] + d[0], a[1] + d[1])
                    if 0 <= b[0] < o['wt'] and 0 <= b[1] < o['ht'] and b not in prev:
                        prev[b] = a
                        q.append(b)
            while hit is not None:
                tiles.add(hit)
                hit = prev[hit]
        self._stamps[key] = sorted(tiles, key=lambda t: (t[1], t[0]))
        return self._stamps[key]

    def obj_cells(self, key, cx, by, flip=False):
        o = obj(key)
        x0 = cx - o['wt'] // 2
        y0 = by - o['ht'] + 1
        out = []
        for (tx, ty) in self.stamp(key):
            mx = (o['wt'] - 1 - tx) if flip else tx
            out.append(((x0 + mx, y0 + ty), (o['ax'] + tx, o['ay'] + ty)))
        return out

    def can_place(self, key, cx, by, layer, flip=False):
        for (c, _) in self.obj_cells(key, cx, by, flip):
            if not (0 <= c[0] < W and 0 <= c[1] < H) or c in self.layers[layer]:
                return False
        return True

    def place(self, key, cx, by, layer, kind, flip=False):
        o = obj(key)
        cells = [(c, a) for (c, a) in self.obj_cells(key, cx, by, flip) if 0 <= c[0] < W and 0 <= c[1] < H]
        idx = len(self.objects)
        for (c, a) in cells:
            self.layers[layer][c] = (o['ts'], a, flip)
            self.cover.setdefault(c, []).append(idx)
            if c[1] >= by - 1 and kind not in ('bitki', 'yassi', 'cicek'):
                self.base_cells.add(c)
                self.base_cells.add((c[0], by + 1))
        self.objects.append({'key': key, 'layer': layer, 'cells': [c for c, _ in cells], 'root': by, 'cx': cx, 'kind': kind,
                             'flip': flip})
        return idx


## ---------------------------------------------------------------- ARAZİ
def ellipse_field(lx, ly, cx, cy, rx, ry, ang=0.0):
    ca, sa = math.cos(ang), math.sin(ang)
    ux = (lx - cx) * ca + (ly - cy) * sa
    uy = -(lx - cx) * sa + (ly - cy) * ca
    return np.hypot(ux / rx, uy / ry)


def blob_mask(lx, ly, spec, n1, n2, ang_j=0.25):
    cx, cy, rx, ry, lobes = spec
    wet = 1.0 - ellipse_field(lx, ly, cx, cy, rx, ry, rng.uniform(-ang_j, ang_j)) + (n1 - 0.5) * 0.40 + (n2 - 0.5) * 0.08
    for (ax, ay, arx, ary) in lobes:
        wet = np.maximum(wet, 1.0 - ellipse_field(lx, ly, ax, ay, arx, ary, rng.uniform(-0.6, 0.6)) + (n1 - 0.5) * 0.3 + (n2 - 0.5) * 0.08)
    return wet > 0


def path_samples(pts, step=0.5):
    out = []
    for (a, b) in zip(pts[:-1], pts[1:]):
        n = max(1, int(math.hypot(b[0] - a[0], b[1] - a[1]) / step))
        for i in range(n):
            t = i / n
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    out.append(pts[-1])
    return out


def ridge_field(lx, ly, n=None, n2=None):
    """AYAZ DAĞI sırtı maskesi (True = dağ, geçilmez). lx/ly yerel hücre dizileri; n / n2 = 0..1 kenar gürültüsü ya da None"""
    j = 0.0 if n is None else (n - 0.5) * 0.45
    if n2 is not None:
        j = j + (n2 - 0.5) * 0.40
    mask = np.zeros(np.shape(lx), bool)
    for (cx, cy, rx, ry, a) in RIDGE:
        mask |= ellipse_field(lx, ly, cx, cy, rx, ry, a) + j < 1.0
    return mask


def wobble(samples, seed, amp=2.2):
    """yolu dik yönde yumuşak gürültüyle büker (cetvelle çizilmiş gibi durmasın)"""
    out = []
    r = random.Random(seed)
    ph1, ph2 = r.uniform(0, 6.28), r.uniform(0, 6.28)
    acc = 0.0
    for i, (x, y) in enumerate(samples):
        if i > 0:
            acc += math.hypot(x - samples[i - 1][0], y - samples[i - 1][1])
        j = min(i + 1, len(samples) - 1)
        k = max(i - 1, 0)
        dx, dy = samples[j][0] - samples[k][0], samples[j][1] - samples[k][1]
        ln = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / ln, dx / ln
        fade = min(1.0, i / 6.0, (len(samples) - 1 - i) / 6.0)
        off = (math.sin(acc * 0.07 + ph1) * 0.7 + math.sin(acc * 0.19 + ph2) * 0.3) * amp * fade
        out.append((x + nx * off, y + ny * off))
    return out


def build_terrain(m):
    VH, VW = H + 1, W + 1
    yy, xx = np.mgrid[0:VH, 0:VW]
    lx = xx - PX0
    ly = yy - PY0
    n1 = fbm((VH, VW), 18, SEED + 1)
    n2 = fbm((VH, VW), 8, SEED + 2)
    ## 1) BUZ (donmuş göller)
    ice = np.zeros((VH, VW), bool)
    for spec in LAKES:
        ice |= blob_mask(lx, ly, spec, n1, n2)
    ## donmuş dereler (tespih gölleri bağlar): gürültülü genişlikte buz şeridi
    for si, (pts, hw) in enumerate(ICE_STREAMS):
        for (px_, py_) in wobble(path_samples(pts), SEED + 90 + si, 2.4):
            r = hw + (n1[int(min(VH - 1, max(0, py_ + PY0))), int(min(VW - 1, max(0, px_ + PX0)))] - 0.5) * 1.0
            x0, x1 = int(px_ + PX0 - r - 1), int(px_ + PX0 + r + 2)
            y0, y1 = int(py_ + PY0 - r - 1), int(py_ + PY0 + r + 2)
            ice[y0:y1, x0:x1] |= np.hypot(xx[y0:y1, x0:x1] - PX0 - px_, yy[y0:y1, x0:x1] - PY0 - py_) <= r
    ice = remove_small(ice, 6, True)
    ice = remove_small(ice, 8, False)
    ice = smooth_mask(ice, 2)
    ice = fix_diagonals(ice, prefer=True)
    ## 2) SU (sıcak kaynak)
    water = np.zeros((VH, VW), bool)
    for spec in SPRINGS:
        water |= blob_mask(lx, ly, spec, n1, n2, 0.1)
    water = smooth_mask(water, 1)
    water &= ~(cheb_dist(ice, 4) <= 3)
    water = fix_diagonals(water, prefer=True)
    ## 3) TOPRAK: patikalar (gürültülü genişlik) + ateşlerin çevresinde eriyen kar
    dirt = np.zeros((VH, VW), bool)
    paths = [wobble(path_samples(p), SEED + 70 + i, 3.6) for i, p in enumerate(PATHS)]
    m.path_lines = paths
    for line in paths:
        for (px_, py_) in line:
            r = PATH_R + (n2[int(min(VH - 1, max(0, py_ + PY0))), int(min(VW - 1, max(0, px_ + PX0)))] - 0.5) * 1.2
            x0, x1 = int(px_ + PX0 - r - 1), int(px_ + PX0 + r + 2)
            y0, y1 = int(py_ + PY0 - r - 1), int(py_ + PY0 + r + 2)
            sub_x = xx[y0:y1, x0:x1] - PX0
            sub_y = yy[y0:y1, x0:x1] - PY0
            dirt[y0:y1, x0:x1] |= np.hypot(sub_x - px_, sub_y - py_) <= r
    for (cx, cy, rad) in MELT:
        dirt |= ellipse_field(lx, ly, cx, cy, rad, rad * 0.78, rng.uniform(-0.3, 0.3)) + (n2 - 0.5) * 0.35 < 1.0
    dirt = smooth_mask(dirt, 1)
    near_wet = cheb_dist(ice | water, 3) <= 2
    dirt &= ~near_wet
    dirt = remove_small(dirt, 10, True)
    dirt = remove_small(dirt, 6, False)
    dirt = fix_diagonals(dirt, prefer=False)
    dirt &= ~near_wet
    m.v_ice, m.v_water, m.v_dirt = ice, water, dirt
    m.v_land = ~ice & ~water


def paint_terrain(m):
    land, ice, water, dirt = m.v_land, m.v_ice, m.v_water, m.v_dirt
    nowater = ~water
    noice = ~ice
    ice_var = {}
    for y in range(H):
        for x in range(W):
            wc = corner_code(nowater, x, y)
            if wc != 15:
                m.put('Su', (x, y), *WATER_TILE)
                if wc != 0:
                    m.put('Su ayrıntılar 2', (x, y), *block_tile(BLOCK_SNOW, wc))
                continue
            ic = corner_code(noice, x, y)
            if ic != 15:
                bk = (x // 2, y // 2)
                if bk not in ice_var:
                    ice_var[bk] = rng.choice(ICE_FILLS)
                bx, by = ice_var[bk]
                m.put('Buz', (x, y), 'zemin', (bx + x % 2, by + y % 2))
                if ic != 0:
                    m.put('Zemin Çimen', (x, y), *block_tile(BLOCK_SNOW, ic))
                continue
            m.put('Zemin Toprak', (x, y), *SNOW_FILL)
            dc = corner_code(dirt, x, y)
            if dc != 0:
                m.put('Patika', (x, y), *block_tile(BLOCK_DIRT, dc))


## ---------------------------------------------------------------- hücre sınıfları
def cell_masks(m):
    def full(v):
        return v[:-1, :-1] & v[:-1, 1:] & v[1:, :-1] & v[1:, 1:]

    def any_(v):
        return v[:-1, :-1] | v[:-1, 1:] | v[1:, :-1] | v[1:, 1:]
    m.c_land = full(m.v_land)
    m.c_ice = full(m.v_ice)
    m.c_water = full(m.v_water)
    m.c_dirt = full(m.v_dirt)
    m.c_dirt_any = any_(m.v_dirt)
    m.c_snow = m.c_land & ~m.c_dirt_any
    m.c_wd = cheb_dist(~m.c_land, 10)          ## buza / suya uzaklık (hücre)
    m.c_pd = cheb_dist(m.c_dirt_any, 12)       ## patikaya uzaklık
    yy, xx = np.mgrid[0:H, 0:W]
    lx, ly = xx - PX0, yy - PY0
    m.c_edge = np.minimum.reduce([lx, ly, PLAY - 1 - lx, PLAY - 1 - ly])


def in_play(x, y, margin=0):
    lx, ly = x - PX0, y - PY0
    return margin <= lx < PLAY - margin and margin <= ly < PLAY - margin


def near_spawn(x, y, r):
    sx, sy = P(*SPAWN)
    return math.hypot(x - sx, y - sy) < r


def in_clearing(x, y, extra=0.0):
    lx, ly = x - PX0, y - PY0
    return any(math.hypot(lx - REGIONS[k][0], ly - REGIONS[k][1]) < CLEARINGS[k] + extra for k in REGIONS if CLEARINGS[k] > 0)


def nearest_region(x, y):
    lx, ly = x - PX0, y - PY0
    return min(REGIONS, key=lambda k: math.hypot(lx - REGIONS[k][0], ly - REGIONS[k][1]))


def in_meadow(m, x, y, pad=0.0):
    lx, ly = x - PX0 + 0.5, y - PY0 + 0.5
    for (bx, by_, rx_, ry_, ang) in getattr(m, 'brush_sites', []):
        ca, sa = math.cos(ang), math.sin(ang)
        ux = (lx - bx) * ca + (ly - by_) * sa
        uy = -(lx - bx) * sa + (ly - by_) * ca
        if (ux / (rx_ + pad)) ** 2 + (uy / (ry_ + pad)) ** 2 < 1.0:
            return True
    return False


## ---------------------------------------------------------------- dış sınır (geçilmez dağ şeridi)
def build_band(m):
    cn = fbm((H, W), 10, SEED + 21)
    cn2 = fbm((H, W), 28, SEED + 23, 2)
    depth = 3.0 + cn * 5.0 + np.clip(cn2 - 0.40, 0, 1) * 18.0
    yy, xx = np.mgrid[0:H, 0:W]
    lx, ly = xx - PX0, yy - PY0
    ## kuzey kenar daha derin (dağ yamacı)
    depth += np.clip((40 - ly) / 40.0, 0, 1) * 4.0
    band = m.c_edge < depth
    ## AYAZ DAĞI sırtı (madde 658): kuzey kenarından ortaya inen geçilmez dağ - şeridin parçası (kaya tepeleri + sık karlı çam)
    band |= ridge_field(lx + 0.5, ly + 0.5, cn, cn2)
    keep = np.zeros((H, W), bool)
    for k, (rxk, ryk) in REGIONS.items():
        if CLEARINGS[k] > 0:
            keep |= np.hypot(lx - rxk, ly - ryk) < CLEARINGS[k] + 3
    keep |= m.c_dirt_any | (m.c_pd <= 1)
    keep &= m.c_edge >= 2
    band &= ~keep
    band &= m.c_land | (m.c_edge < 0)
    m.forest = band
    for y in range(H):
        for x in range(W):
            if band[y, x]:
                m.put('Orman parçaları', (x, y), *BLOCKER_TILE)


## ---------------------------------------------------------------- nesne yerleşimi
def root_ok(m, key, cx, by, ground='land', avoid_forest=True, rows=2):
    """kök satırı (+ bir üstü) uygun zeminde: 'land' kar ya da toprak, 'snow' tam kar, 'dirt' tam toprak, 'ice' tam buz"""
    o = obj(key)
    x0 = cx - o['wt'] // 2
    for tx in range(o['wt']):
        for yy in range(by - rows + 1, by + 1):
            x = x0 + tx
            if not (0 <= x < W and 0 <= yy < H):
                return False
            if ground == 'ice':
                if not m.c_ice[yy, x]:
                    return False
            elif not m.c_land[yy, x]:
                return False
            elif ground == 'snow' and m.c_dirt_any[yy, x]:
                return False
            elif ground == 'dirt' and not m.c_dirt[yy, x]:
                return False
    if avoid_forest:
        for tx in range(o['wt']):
            if m.forest[by, x0 + tx] or m.forest[by - 1, x0 + tx]:
                return False
    if in_meadow(m, cx, by, 1.0):
        return False
    for (c, _) in m.obj_cells(key, cx, by):
        if not (0 <= c[0] < W and 0 <= c[1] < H):
            return False
    return True


def overlaps(m, key, cx, by, flip=False):
    s = set()
    for (c, _) in m.obj_cells(key, cx, by, flip):
        for oi in m.cover.get(c, []):
            s.add(oi)
    return s


def obj_layer_for(m, key, cx, by, flip=False, cover_bases=False):
    L = 0
    for oi in overlaps(m, key, cx, by, flip):
        ob = m.objects[oi]
        if ob['layer'] not in OBJ_LAYERS:
            return None
        if ob['root'] >= by - 1:
            return None
        L = max(L, OBJ_LAYERS.index(ob['layer']) + 1)
    if L >= len(OBJ_LAYERS):
        return None
    if not cover_bases:
        for (c, _) in m.obj_cells(key, cx, by, flip):
            if c in m.base_cells:
                return None
    return OBJ_LAYERS[L]


def place_obj(m, key, cx, by, kind='nesne', flip=None, cover_bases=False):
    if flip is None:
        flip = key.rsplit('_', 1)[0] not in NO_FLIP and key not in NO_FLIP and rng.random() < 0.5
    L = obj_layer_for(m, key, cx, by, flip, cover_bases)
    if L is None:
        return None
    cells = [c for c, _ in m.obj_cells(key, cx, by, flip)]
    for li in range(OBJ_LAYERS.index(L), len(OBJ_LAYERS)):
        lname = OBJ_LAYERS[li]
        if not m.can_place(key, cx, by, lname, flip):
            continue
        clash = False
        for c in cells:
            for dx in (-1, 1):
                n = (c[0] + dx, c[1])
                if n in m.layers[lname] and n not in cells:
                    for oi in m.cover.get(n, []):
                        ob = m.objects[oi]
                        if ob['layer'] == lname and ob['root'] == by:
                            clash = True
        if not clash:
            idx = m.place(key, cx, by, lname, kind, flip)
            if key in FIRE_KEYS:
                note_fire(m, key, cx, by)
            return idx
    return None


def obj_px(key, cx, by):
    """nesnenin dünya pikselinde yatay ortası ve tepesi"""
    o = obj(key)
    x = (cx - o['wt'] // 2) * T + o['ox'] + o['w'] / 2.0
    top = (by + 1) * T - o['h']
    return x, top


def note_fire(m, key, cx, by):
    x, top = obj_px(key, cx, by)
    o = obj(key)
    if key == 'mesale':
        flame = (x, top + 7.0)
    elif key == 'kamp_atesi':
        flame = (x, top + o['h'] * 0.62)
    else:
        flame = (x, top + o['h'] * 0.45)
    m.meta_lights.append((key, flame))
    m.heat.append((key, ((cx + 0.5) * T if key != 'mesale' else x, (by + 0.6) * T), HEAT_RADIUS[key]))
    if key in ('kamp_atesi', 'buyuk_mangal'):
        m.smoke.append((x, top + 2.0))


def try_place(m, key, cx, by, ground='land', kind='nesne', jitter=2, tries=40, flip=None, avoid_forest=True):
    for attempt in range(tries):
        jx = 0 if attempt == 0 else rng.randint(-jitter, jitter)
        jy = 0 if attempt == 0 else rng.randint(-jitter, jitter)
        if not root_ok(m, key, cx + jx, by + jy, ground, avoid_forest):
            continue
        if place_obj(m, key, cx + jx, by + jy, kind, flip=flip) is not None:
            return (cx + jx, by + jy)
    return None


def ground_at(m, x, y):
    return 'dirt' if m.c_dirt[y, x] else 'snow'


def place_landmarks(m):
    """bölgelerin yer işaretleri + ateşleri. Ofsetler bölge merkezine göre hücre (kök satırı)."""
    plan = {
        'kamp': [('buyuk_mangal', 0, -1), ('kamp_atesi', 5, 2), ('cadir_1', -7, -4), ('cadir_2', 7, -5), ('kutuk_yatay', 0, 2),
                 ('kutuk_dik', -3, 0), ('kutuk_yatay_2', -4, 3), ('mesale', -10, 3), ('mesale', 10, 3), ('mesale', -9, -8),
                 ('mesale', 9, -9)],
        'avci': [('kamp_atesi', 0, 0), ('cadir_1', -5, -3), ('kutuk_yatay', 1, 2), ('mesale', 4, -3)],
        'totem': [('buyuk_mangal', 0, 0), ('totem_1', -5, -2), ('totem_1', 5, -2), ('totem_2', -4, 4), ('totem_2', 4, 4), ('mangal', -8, 1),
                  ('mangal', 8, 1), ('harabe_kule', -10, -6), ('harabe_duvar', 10, -6), ('mesale', -3, 8), ('mesale', 3, 8)],
        'buz_agaci': [('dev_buz_agaci', 0, 2), ('buz_kristal_2', -12, 4), ('buz_kristal_1', 12, 3), ('kristal_2', -9, 7), ('kristal_3', 10, 8)],
        'kristal': [('kristal_dev', 0, 0), ('kristal_2', -6, 4), ('kristal_2', 7, -4), ('kizil_kristal_1', -7, -4), ('kizil_kristal_2', 6, 5),
                    ('buz_kristal_2', 2, 7), ('buz_kristal_1', -3, -7), ('kristal_3', 9, 1)],
        'yilbasi': [('yilbasi_agaci', 0, 0), ('kardan_adam_1', -5, 3), ('kardan_adam_3', 5, 3), ('kardan_adam_2', -7, -3),
                    ('kardan_adam_4', 7, -2), ('kamp_atesi', 0, 6), ('mesale', -9, 6), ('mesale', 9, 6), ('mesale', -9, -6),
                    ('mesale', 9, -6), ('kutuk_yatay', -3, 8), ('kutuk_yatay_2', 3, 8)],
        'kaplica': [('mesale', -8, 5), ('mesale', 8, 5), ('mesale', 0, -6), ('kaya_orta', -9, -3), ('kaya_buyuk', 10, -3), ('kaya_kucuk', 5, 7)],
        'mantar': [('mantar_1', 0, 0), ('mantar_2', -5, 3), ('mantar_1', 5, 4), ('mesale', 0, 6)],
        'harabe': [('buyuk_mangal', 0, 1), ('harabe_ev', -8, -4), ('harabe_kule', 8, -5), ('harabe_kemer', 0, -7), ('harabe_duvar', -9, 5),
                   ('harabe_kucuk', 9, 5), ('mangal', -5, 4), ('mangal', 5, 4), ('mesale', 0, 8)],
    }
    for reg, items in plan.items():
        rx_, ry_ = REGIONS[reg]
        for key, dx, dy in items:
            cx, by = P(rx_ + dx, ry_ + dy)
            g = 'dirt' if (0 <= by < H and 0 <= cx < W and m.c_dirt[by, cx]) else 'land'
            k2 = variant(key, 'dirt' if g == 'dirt' else 'snow')
            kind = 'nesne'
            if key in ('dev_buz_agaci', 'yilbasi_agaci'):
                if try_tree(m, k2, cx, by, 'land', 0, force=True):
                    continue
                print('  yer işareti sığmadı:', reg, key)
                continue
            if try_place(m, k2, cx, by, 'land', kind, flip=(dx > 0) if key not in NO_FLIP else False) is None:
                print('  yer işareti sığmadı:', reg, key)


## ---------------------------------------------------------------- yol meşaleleri
def place_path_torches(m):
    n = 0
    for li, line in enumerate(m.path_lines):
        acc = 0.0
        side = 1 if li % 2 == 0 else -1
        nxt = YOGUNLUK['meşale_aralik'] * 0.6
        for i in range(1, len(line)):
            x0, y0 = line[i - 1]
            x1, y1 = line[i]
            acc += math.hypot(x1 - x0, y1 - y0)
            if acc < nxt:
                continue
            dx, dy = x1 - x0, y1 - y0
            ln = math.hypot(dx, dy) or 1.0
            ox, oy = -dy / ln * side, dx / ln * side
            done = False
            for off in (3.2, 3.8, 4.4):
                cx, by = P(int(round(x1 + ox * off)), int(round(y1 + oy * off)))
                if not (0 <= cx < W and 0 <= by < H) or in_clearing(cx, by, 2) or m.forest[by, cx]:
                    continue
                if any(math.hypot(cx - (h[1][0] / T), by - (h[1][1] / T)) < 8 for h in m.heat):
                    continue
                if root_ok(m, 'mesale', cx, by, 'land') and place_obj(m, 'mesale', cx, by) is not None:
                    n += 1
                    done = True
                    break
            nxt = acc + (YOGUNLUK['meşale_aralik'] if done else 3.0)
            if done:
                side = -side
    return n


## ---------------------------------------------------------------- dağ şeridi
def place_band(m):
    """geçilmez şerit + dış çerçeve: iç kenar boyunca kaya tepeleri + büyük kayalar (dağ eteği), şeridin geri kalanı sık karlı çam
    ormanı (ağaçlar collect_trees'te) + seyrek kaya. Y-sıralı, üst üste binebilir."""
    n = 0
    roots = set()

    def free(x, y, sp):
        return not any((x + dx, y + dy) in roots for dx in range(-sp, sp + 1) for dy in range(-1, 2))
    f = m.forest
    inner = f & ~np.roll(f, 1, 0) | f & ~np.roll(f, -1, 0) | f & ~np.roll(f, 1, 1) | f & ~np.roll(f, -1, 1)
    ys, xs = np.nonzero(inner)
    order = [(x, y) for x, y in zip(xs.tolist(), ys.tolist()) if in_play(x, y, -2)]
    rng.shuffle(order)
    for (x, y) in order:
        if not free(x, y, 3) or rng.random() < 0.45:
            continue
        r = rng.random()
        key = rng.choice(MESAS) if r < 0.45 else (variant(rng.choice(['kaya_buyuk', 'kaya_yigin', 'kaya_orta']), 'snow'))
        for dy in (0, -1, 1):
            yy = y + dy
            if 0 <= yy < H and m.forest[yy, x] and root_ok(m, key, x, yy, 'land', avoid_forest=False, rows=1) and \
                    place_obj(m, key, x, yy, 'nesne', cover_bases=True) is not None:
                roots.add((x, yy))
                n += 1
                break
    ## Not (madde 658): AYAZ DAĞI sırtı da bu dille çizilir (iç kenarında kaya tepeleri, içi sık karlı çam). Sırta özel sık kaya tepesi
    ## denendi: çamların yerini kapıp "taş tarlası" gibi duruyordu ve karlı tepeler kartta karla aynı tonda kayboluyordu.
    ys, xs = np.nonzero(m.forest)
    order = list(zip(xs.tolist(), ys.tolist()))
    rng.shuffle(order)
    for (x, y) in order[:6000]:
        if not free(x, y, 6) or rng.random() < 0.7:
            continue
        key = rng.choice(MESAS + MESAS_G[:2]) if rng.random() < 0.5 else variant(rng.choice(ROCKS), 'snow')
        if root_ok(m, key, x, y, 'land', avoid_forest=False, rows=1) and place_obj(m, key, x, y, 'nesne', cover_bases=True) is not None:
            roots.add((x, y))
            n += 1
    return n


def rim_rock(m, x, y, rnd):
    """madde 676 kenar dolgusu: görünmez engelin açık görünen kenar hücresine (x, y) karlı kaya; kök kenarda ya da 1 hücre içeride.
    Ağaçlardan sonra çağrılır: obj_layer_for ağaç tacına binen kayayı reddeder (kaya tacın altında çizilirdi)."""
    for key in (variant(rnd.choice(['kaya_buyuk', 'kaya_yigin', 'kaya_orta']), 'snow'), variant('kaya_kucuk', 'snow')):
        flip = key.rsplit('_', 1)[0] not in NO_FLIP and key not in NO_FLIP and rnd.random() < 0.5
        for dy in (0, -1):
            yy = y + dy
            if 0 <= yy < H and m.forest[yy, x] and root_ok(m, key, x, yy, 'land', avoid_forest=False, rows=1) and                     place_obj(m, key, x, yy, 'nesne', flip=flip, cover_bases=True) is not None:
                return True
    return False


def place_rock_clusters(m):
    n = 0
    for (cx_, cy_, r) in ROCK_CLUSTERS:
        for _ in range(int(r * r * 1.8)):
            a = rng.uniform(0, math.tau)
            d = math.sqrt(rng.random()) * r
            x, y = P(int(round(cx_ + math.cos(a) * d)), int(round(cy_ + math.sin(a) * d * 0.8)))
            if not (0 <= x < W and 0 <= y < H) or near_spawn(x, y, 14) or in_clearing(x, y, 1) or m.c_pd[y, x] < 2:
                continue
            rr = rng.random()
            key = rng.choice(MESAS) if rr < 0.3 else variant(rng.choice(ROCKS), 'snow')
            if root_ok(m, key, x, y, 'snow') and place_obj(m, key, x, y) is not None:
                n += 1
    return n


def scatter(m, count, keys_fn, cond, kind='nesne', tries=20000, spacing=3, ground='snow'):
    n = 0
    for _ in range(tries):
        if n >= count:
            break
        x = rng.randint(PX0, PX0 + PLAY - 1)
        y = rng.randint(PY0, PY0 + PLAY - 1)
        if not cond(x, y):
            continue
        key = keys_fn(x, y)
        if key is None:
            continue
        if not root_ok(m, key, x, y, ground):
            continue
        bad = False
        for (c, _) in m.obj_cells(key, x, y):
            for dx in range(-spacing, spacing + 1):
                if (c[0] + dx, c[1]) in m.cover or (c[0] + dx, c[1] + 1) in m.cover:
                    bad = True
                    break
            if bad:
                break
        if bad:
            continue
        if place_obj(m, key, x, y, kind) is not None:
            n += 1
    return n


def place_scatter(m):
    out = {}

    def open_snow(x, y):
        return m.c_snow[y, x] and not m.forest[y, x] and m.c_wd[y, x] >= 3 and m.c_pd[y, x] >= 2 and not near_spawn(x, y, 12) and \
            not in_clearing(x, y)

    def rock_key(x, y):
        north = (y - PY0) < 90
        if not north and rng.random() < 0.4:
            return None
        r = rng.random()
        if r < 0.25:
            return rng.choice(MESAS)
        return variant(rng.choice(ROCKS + ['harabe_kucuk']), 'snow')
    out['kaya'] = scatter(m, YOGUNLUK['kaya'], rock_key, open_snow, spacing=4)
    out['kardan'] = scatter(m, YOGUNLUK['kardan_adam'], lambda x, y: variant(rng.choice(SNOWMEN + SNOWMEN_SMALL), 'snow'),
                            lambda x, y: open_snow(x, y) and m.c_pd[y, x] <= 6, spacing=5)
    ## kristal filizleri kuzeyde (soğuk yarı)
    out['kristal'] = scatter(m, 26, lambda x, y: variant(rng.choice(['kristal_2', 'kristal_3', 'buz_kristal_1', 'buz_kristal_2']), 'snow'),
                             lambda x, y: open_snow(x, y) and (y - PY0) < 100, spacing=4)
    return out


## ---------------------------------------------------------------- ağaçlar
def south_of_objects(m, key, x, y, flip=False):
    for (c, _) in m.obj_cells(key, x, y, flip):
        for oi in m.cover.get(c, []):
            ob = m.objects[oi]
            if ob['layer'] in OBJ_LAYERS and ob['root'] >= y - 1:
                return False
            if c in m.base_cells and ob['layer'] in OBJ_LAYERS:
                return False
    return True


TREES = []
TRUNK = {}


def try_tree(m, key, x, y, ground, r, force=False, avoid_forest=True):
    flip = key.rsplit('_', 1)[0] not in NO_FLIP and rng.random() < 0.5
    if not force and any((x + dx, y + dy) in TRUNK for dx in range(-r, r + 1) for dy in range(-r, r + 1)):
        return False
    if not root_ok(m, key, x, y, ground, avoid_forest) or not south_of_objects(m, key, x, y, flip):
        return False
    TREES.append((key, x, y, flip))
    TRUNK[(x, y)] = True
    return True


def collect_trees(m):
    ## 1) bölgeye özgü ağaçlar
    def region_ring(reg, keys, count, r0, r1, sp):
        rx0, ry0 = REGIONS[reg]
        k = 0
        for _ in range(count * 40):
            if k >= count:
                break
            a = rng.uniform(0, math.tau)
            d = r0 + math.sqrt(rng.random()) * (r1 - r0)
            x, y = P(int(round(rx0 + math.cos(a) * d)), int(round(ry0 + math.sin(a) * d * 0.8)))
            if not (0 <= x < W and 0 <= y < H) or m.forest[y, x] or m.c_pd[y, x] < 2:
                continue
            g = ground_at(m, x, y)
            if try_tree(m, variant(rng.choice(keys), g), x, y, 'land', sp):
                k += 1
        return k
    region_ring('buz_agaci', ICE_TREES, 14, CLEARINGS['buz_agaci'] + 1, 24, 5)
    region_ring('kristal', ICE_TREES, 10, CLEARINGS['kristal'] + 1, 20, 5)
    region_ring('mantar', MUSH_TREES, 22, CLEARINGS['mantar'] + 1, 20, 4)
    region_ring('yilbasi', PINES + ROUND_PINES, 12, CLEARINGS['yilbasi'] + 1, 20, 5)
    region_ring('totem', PINES + RED, 10, CLEARINGS['totem'] + 1, 20, 5)
    region_ring('harabe', RED + ROUND, 10, CLEARINGS['harabe'] + 1, 20, 5)
    region_ring('kaplica', ROUND_PINES + ROUND, 8, CLEARINGS['kaplica'] + 1, 18, 5)
    region_ring('kamp', PINES + ROUND_PINES, 10, CLEARINGS['kamp'] + 2, 22, 5)
    region_ring('avci', PINES, 6, CLEARINGS['avci'] + 1, 14, 4)
    ## 2) çam koruları (sık)
    for (gx, gy, r) in GROVES:
        for _ in range(int(r * r * 2.4)):
            a = rng.uniform(0, math.tau)
            d = math.sqrt(rng.random()) * r
            x, y = P(int(round(gx + math.cos(a) * d)), int(round(gy + math.sin(a) * d * 0.85)))
            if not (0 <= x < W and 0 <= y < H) or in_clearing(x, y, 2) or m.forest[y, x] or m.c_pd[y, x] < 2 or m.c_wd[y, x] < 2:
                continue
            r2 = rng.random()
            keys = PINES if r2 < 0.55 else (ROUND_PINES if r2 < 0.85 else RED)
            try_tree(m, variant(rng.choice(keys), 'snow'), x, y, 'snow', YOGUNLUK['koru_aralik'])
    ## 3) göl kıyısı: seyrek yuvarlak ağaç / kızıl ağaç
    cand = [(rng.random(), x, y) for y in range(PY0, PY0 + PLAY) for x in range(PX0, PX0 + PLAY)
            if m.c_snow[y, x] and 2 <= m.c_wd[y, x] <= 4 and not m.forest[y, x] and m.c_pd[y, x] >= 2]
    cand.sort()
    k = 0
    for _, x, y in cand:
        if k >= 40 or near_spawn(x, y, 12) or in_clearing(x, y, 1):
            continue
        if try_tree(m, variant(rng.choice(ROUND + RED + ROUND_PINES), 'snow'), x, y, 'snow', 7):
            k += 1
    ## 4) karda tek tük
    singles = 0
    cand = [(rng.random(), x, y) for y in range(PY0, PY0 + PLAY) for x in range(PX0, PX0 + PLAY)
            if m.c_snow[y, x] and not m.forest[y, x] and m.c_wd[y, x] >= 4 and m.c_pd[y, x] >= 3]
    cand.sort()
    for _, x, y in cand:
        if singles >= YOGUNLUK['tek_agac']:
            break
        if near_spawn(x, y, 12) or in_clearing(x, y, 1):
            continue
        north = (y - PY0) < 90
        keys = (ICE_TREES + RED + PINES) if north else (PINES + ROUND_PINES + ROUND + RED)
        if try_tree(m, variant(rng.choice(keys), 'snow'), x, y, 'snow', 10):
            singles += 1
    ## 5) dağ şeridi: sık karlı çam ormanı (gövde kaya tabanına girmez)
    ys, xs = np.nonzero(m.forest)
    order = list(zip(xs.tolist(), ys.tolist()))
    rng.shuffle(order)
    for (x, y) in order:
        if rng.random() < 0.2:
            continue
        r2 = rng.random()
        keys = PINES if r2 < 0.6 else (ROUND_PINES if r2 < 0.88 else RED)
        key = variant(rng.choice(keys), 'snow')
        flip = rng.random() < 0.5
        if any((x + dx, y + dy) in TRUNK for dx in range(-2, 3) for dy in range(-2, 3)):
            continue
        if not root_ok(m, key, x, y, 'land', avoid_forest=False, rows=1) or not south_of_objects(m, key, x, y, flip):
            continue
        TREES.append((key, x, y, flip))
        TRUNK[(x, y)] = True
    return TREES


def assign_tree_layers(m, trees):
    trees = sorted(trees, key=lambda t: (t[2], t[1]))
    cell_layer = {}
    placed = skipped = 0
    for key, cx, by, flip in trees:
        cells = m.obj_cells(key, cx, by, flip)
        L = 0
        for (c, _) in cells:
            if c in cell_layer:
                L = max(L, cell_layer[c] + 1)
        if L >= TREE_LAYERS:
            skipped += 1
            continue
        m.place(key, cx, by, 'Ağaç %d' % L, 'agac', flip)
        if key.startswith('dev_buz_agaci'):
            x, top = obj_px(key, cx, by)
            m.meta_lights.append(('buz_agaci', (x, top + obj(key)['h'] * 0.4)))
        for (c, _) in cells:
            cell_layer[c] = L
        placed += 1
    return placed, skipped


## ---------------------------------------------------------------- yer süsleri + bitkiler
def plant_layer_for(m, cells, root):
    north = south = False
    for c in cells:
        for oi in m.cover.get(c, []):
            r = m.objects[oi]['root']
            if m.objects[oi]['kind'] in ('yassi',):
                continue
            if root < r:
                north = True
            elif root > r:
                south = True
            else:
                return None
    if north and south:
        return None
    return 'Çalılar1' if south else 'Çalılar'


DETAIL_SNOW = sorted(k for k in ATLAS['objects'] if k.startswith('kar_obek'))
DETAIL_DIRT = sorted(k for k in ATLAS['objects'] if k.startswith('toprak_obek'))
FOOTPRINTS = sorted(k for k in ATLAS['objects'] if k.startswith('iz_'))
SMALL_PLANTS = ['buz_cicek_1', 'buz_cicek_2', 'buz_cicek_3', 'diken_cicek_1', 'diken_cicek_2', 'diken_cicek_3']
SMALL_PROPS = ['mantar_3', 'kizil_kristal_3', 'buz_kristal_3', 'buz_kristal_4']  ## sallanmayan küçük nesneler (y-sıralı)


def place_flat(m, key, x, y, need, flip=None):
    if flip is None:
        flip = rng.random() < 0.5
    cells = m.obj_cells(key, x, y, flip)
    for (c, _) in cells:
        if not (0 <= c[0] < W and 0 <= c[1] < H) or c in m.layers['Kar süsleri'] or c in m.layers['Saklanma Çalılığı']:
            return False
        if need == 'snow' and not m.c_snow[c[1], c[0]]:
            return False
        if need == 'dirt' and not m.c_dirt[c[1], c[0]]:
            return False
        if need == 'land' and not m.c_land[c[1], c[0]]:
            return False
        if c in m.base_cells:
            return False
    m.place(key, x, y, 'Kar süsleri', 'yassi', flip)
    return True


def place_ground_decor(m):
    n = {'kar_obek': 0, 'toprak_obek': 0, 'iz': 0, 'buz_deligi': 0, 'tas': 0}
    ## kar öbekleri: ağaç / kaya diplerinde sıklaşır
    for _ in range(YOGUNLUK['kar_obek']):
        x, y = rng.randint(PX0, PX0 + PLAY - 1), rng.randint(PY0, PY0 + PLAY - 1)
        near = any((x + dx, y + dy) in m.cover for dx in (-2, 0, 2) for dy in (-1, 1))
        if not near and rng.random() < 0.7:
            continue
        n['kar_obek'] += place_flat(m, rng.choice(DETAIL_SNOW), x, y, 'snow')
    for _ in range(400):
        x, y = rng.randint(PX0, PX0 + PLAY - 1), rng.randint(PY0, PY0 + PLAY - 1)
        if m.c_dirt[y, x] and rng.random() < 0.35:
            n['toprak_obek'] += place_flat(m, rng.choice(DETAIL_DIRT), x, y, 'dirt')
    ## ayak izleri: yolun yanında karda
    for _ in range(4000):
        if n['iz'] >= YOGUNLUK['iz']:
            break
        x, y = rng.randint(PX0, PX0 + PLAY - 1), rng.randint(PY0, PY0 + PLAY - 1)
        if not (2 <= m.c_pd[y, x] <= 5) or in_clearing(x, y):
            continue
        n['iz'] += place_flat(m, rng.choice(FOOTPRINTS), x, y, 'snow', flip=False)
    ## göl kıyısında olta delikleri (Ayna Göl kıyısı)
    gcx, gcy, grx, gry = LAKES[0][:4]
    for _ in range(3000):
        if n['buz_deligi'] >= 7:
            break
        x = rng.randint(PX0 + int(gcx - grx - 12), PX0 + int(gcx + grx + 12))
        y = rng.randint(PY0 + int(gcy - gry - 12), PY0 + int(gcy + gry + 12))
        if not (0 <= x < W and 0 <= y < H):
            continue
        if m.c_wd[y, x] != 2 or not m.c_snow[y, x]:
            continue
        if any(ob['key'] == 'buz_deligi' and math.hypot(ob['cx'] - x, ob['root'] - y) < 7 for ob in m.objects):
            continue
        n['buz_deligi'] += place_flat(m, 'buz_deligi', x, y, 'snow', flip=False)
    for _ in range(300):
        x, y = rng.randint(PX0, PX0 + PLAY - 1), rng.randint(PY0, PY0 + PLAY - 1)
        if rng.random() < 0.5 and not in_clearing(x, y):
            n['tas'] += place_flat(m, variant(rng.choice(['tas_1', 'tas_2', 'tas_3']), ground_at(m, x, y)), x, y, 'land')
    return n


def place_spots(m, imgs):
    img = imgs['leke']
    dirt_spots, snow_spots = [], []
    for r in range(img.shape[0] // T):
        for c in range(img.shape[1] // T):
            t = img[r * T:(r + 1) * T, c * T:(c + 1) * T]
            a = t[..., 3] > 0
            if a.sum() < 6 or a[0].any() or a[-1].any() or a[:, 0].any() or a[:, -1].any():
                continue
            mean = t[a][:, :3].mean(axis=0)
            (snow_spots if mean[2] > mean[0] else dirt_spots).append((c, r))
    n = 0
    for _ in range(YOGUNLUK['leke'] * 4):
        x, y = rng.randint(PX0, PX0 + PLAY - 1), rng.randint(PY0, PY0 + PLAY - 1)
        if (x, y) in m.layers['Leke']:
            continue
        if m.c_dirt[y, x] and dirt_spots and rng.random() < 0.5:
            m.put('Leke', (x, y), 'leke', rng.choice(dirt_spots))
            n += 1
        elif m.c_snow[y, x] and snow_spots and rng.random() < 0.12:
            m.put('Leke', (x, y), 'leke', rng.choice(snow_spots))
            n += 1
        if n >= YOGUNLUK['leke']:
            break
    return n


def place_plants(m):
    used = set()

    def try_plant(key, x, y, flower=False):
        cells = [c for c, _ in m.obj_cells(key, x, y)]
        for c in cells:
            if not (0 <= c[0] < W and 0 <= c[1] < H) or c in used or not m.c_snow[c[1], c[0]]:
                return False
        layer = 'Çiçekler 1' if flower else plant_layer_for(m, cells, y)
        if layer is None:
            return False
        if flower and plant_layer_for(m, cells, y) != 'Çalılar':
            return False
        if not m.can_place(key, x, y, layer):
            return False
        m.place(key, x, y, layer, 'bitki')
        for c in cells:
            used.add(c)
        return True

    n = 0
    pn = fbm((H, W), 7, SEED + 51)
    for y in range(PY0, PY0 + PLAY):
        for x in range(PX0, PX0 + PLAY):
            if not m.c_snow[y, x] or m.forest[y, x] or m.layers['Saklanma Çalılığı'].get((x, y)) or in_clearing(x, y):
                continue
            r = rng.random()
            p = YOGUNLUK['bitki'] * (0.3 + pn[y, x] * 1.6)
            if r < p:
                k2 = variant(rng.choice(SMALL_PLANTS), 'snow')
                n += try_plant(k2, x, y, flower=obj(k2)['kind'] == 'cicek')
            elif r < p * 1.35 and (x, y) not in m.cover and root_ok(m, variant(rng.choice(SMALL_PROPS), 'snow'), x, y, 'snow'):
                n += place_obj(m, variant(rng.choice(SMALL_PROPS), 'snow'), x, y) is not None
    return n


def place_water_decor(m, imgs):
    su_ne = nonempty_tiles(imgs['su'])
    ripples = [c for c in components(su_ne, 1, 13) if len(c) >= 2]
    deep = m.c_water
    used = set()
    n = 0
    ys, xs = np.nonzero(deep)
    idx = list(range(len(xs)))
    rng.shuffle(idx)
    for i in idx:
        x, y = int(xs[i]), int(ys[i])
        if rng.random() >= YOGUNLUK['su_dalga']:
            continue
        comp = rng.choice(ripples)
        c0 = min(c for c, r in comp)
        r0 = min(r for c, r in comp)
        cells = [((x + c - c0), (y + r - r0)) for c, r in comp]
        if not all(0 <= cx < W and 0 <= cy < H and deep[cy, cx] and (cx, cy) not in used for cx, cy in cells):
            continue
        for (c, r), (cx, cy) in zip(comp, cells):
            m.put('Su süsleri', (cx, cy), 'su', (c, r))
            used.add((cx, cy))
        n += 1
    return n


def place_cracks(m, imgs):
    """çatlaklı tam buz karoları (k_catlak bileşenleri: 2x2 ve 4x4) buz dolgusunun YERİNE, tam buz hücrelerinde"""
    ne = nonempty_tiles(imgs['catlak'])
    blocks = []
    for comp in components(ne, 0, ne.shape[0]):
        cs = [c for c, _ in comp]
        rs = [r for _, r in comp]
        c0, r0, c1, r1 = min(cs), min(rs), max(cs), max(rs)
        if len(comp) == (c1 - c0 + 1) * (r1 - r0 + 1):
            blocks.append((c0, r0, c1 - c0 + 1, r1 - r0 + 1))
    used = set()
    n = 0
    ys, xs = np.nonzero(m.c_ice)
    idx = list(range(len(xs)))
    rng.shuffle(idx)
    for i in idx:
        if rng.random() >= YOGUNLUK['catlak']:
            continue
        x, y = int(xs[i]), int(ys[i])
        c0, r0, bw, bh = rng.choice(blocks)
        cells = [(x + dx, y + dy) for dy in range(bh) for dx in range(bw)]
        if not all(0 <= cx < W and 0 <= cy < H and m.c_ice[cy, cx] and (cx, cy) not in used and
                   all((cx + a, cy + b) not in used for a in (-1, 0, 1) for b in (-1, 0, 1)) for cx, cy in cells):
            continue
        for dy in range(bh):
            for dx in range(bw):
                m.put('Buz', (x + dx, y + dy), 'catlak', (c0 + dx, r0 + dy))
                used.add((x + dx, y + dy))
        n += 1
    return n


def place_brush(m):
    """saklanma çalılığı (kırağılı çam çalısı, atlas satır 0-3): karda, yollardan / göllerden / bölgelerden uzak elips yamalar"""
    L = 'Saklanma Çalılığı'
    m.brush_sites = []
    sx_, sy_ = SPAWN
    for _ in range(6000):
        if len(m.brush_sites) >= BRUSH_COUNT:
            break
        bx, by_ = rng.uniform(16, PLAY - 16), rng.uniform(16, PLAY - 16)
        ix, iy = int(round(bx)) + PX0, int(round(by_)) + PY0
        if math.hypot(bx - sx_, by_ - sy_) < 24 or m.forest[iy, ix] or m.c_pd[iy, ix] < 6 or m.c_wd[iy, ix] < 6:
            continue
        if any(math.hypot(bx - REGIONS[k][0], by_ - REGIONS[k][1]) < CLEARINGS[k] + 10 for k in REGIONS):
            continue
        if any(math.hypot(bx - a, by_ - b) < 30 for a, b, _, _, _ in m.brush_sites):
            continue
        if any(math.hypot(bx - g[0], by_ - g[1]) < g[2] + 5 for g in GROVES):
            continue
        m.brush_sites.append((bx, by_, rng.uniform(5.5, 7.0), rng.uniform(3.8, 4.8), rng.uniform(-0.5, 0.5)))
    patches = 0
    m.brush_cells = set()
    for (bx, by_, rx_, ry_, ang) in m.brush_sites:
        ca, sa = math.cos(ang), math.sin(ang)
        cs = set()
        for dy in range(-int(ry_) - 2, int(ry_) + 3):
            for dx in range(-int(rx_) - 2, int(rx_) + 3):
                x, y = P(int(round(bx)) + dx, int(round(by_)) + dy)
                lx, ly = x - PX0 + 0.5, y - PY0 + 0.5
                ux = (lx - bx) * ca + (ly - by_) * sa
                uy = -(lx - bx) * sa + (ly - by_) * ca
                if (ux / (rx_ - 0.8)) ** 2 + (uy / (ry_ - 0.6)) ** 2 >= 1.0:
                    continue
                if not (0 <= x < W and 0 <= y < H) or not m.c_snow[y, x] or m.forest[y, x] or (x, y) in m.base_cells:
                    continue
                cs.add((x, y))
        for _ in range(2):
            for c in list(cs):
                nb = sum((c[0] + d[0], c[1] + d[1]) in cs for d in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if nb <= 1:
                    cs.discard(c)
        deep = [c for c in cs if all((c[0] + dx, c[1] + dy) in cs for dx in (-1, 0, 1) for dy in (-1, 0, 1))]
        if len(cs) < 12 or len(deep) < 2:
            continue
        var_of = {}
        for c in sorted(cs, key=lambda c: (c[1], c[0])):
            mask = (0 if (c[0], c[1] - 1) in cs else 1) | (0 if (c[0], c[1] + 1) in cs else 2) | \
                   (0 if (c[0] - 1, c[1]) in cs else 4) | (0 if (c[0] + 1, c[1]) in cs else 8)
            banned = {var_of.get((c[0] - 1, c[1])), var_of.get((c[0], c[1] - 1))}
            v = rng.choice([k for k in (0, 1, 2, 3) if k not in banned])
            var_of[c] = v
            m.put(L, c, 'calilik', (mask, v))
        m.brush_cells |= cs
        patches += 1
    return patches


## ---------------------------------------------------------------- collision taklidi + ulaşılabilirlik
def tile_rgba(imgs, ts, coord, flip=False):
    c, r = coord
    t = imgs[ts][r * T:(r + 1) * T, c * T:(c + 1) * T]
    return t[:, ::-1] if flip else t


def is_blue(px):
    r, g, b = px[..., 0] / 255.0, px[..., 1] / 255.0, px[..., 2] / 255.0
    return (b > g + 0.03) & (b > r + 0.1)


_solid_cache = {}


def solid_prop(key):
    """terrain_collision.gd is_solid_prop taklidi"""
    if key in _solid_cache:
        return _solid_cache[key]
    o = obj(key)
    img = IMGS[o['ts']]
    blk = img[o['ay'] * T:(o['ay'] + o['ht']) * T, o['ax'] * T:(o['ax'] + o['wt']) * T].astype(float) / 255.0
    a = blk[..., 3] > 0.5
    px = int(a.sum())
    ys, xs = np.nonzero(a)
    if px == 0:
        _solid_cache[key] = False
        return False
    w = xs.max() - xs.min() + 1
    h = ys.max() - ys.min() + 1
    ok = w >= PROP_MIN_W and h >= PROP_MIN_H and px >= PROP_MIN_PIXELS and px / (w * h) >= PROP_MIN_DENSITY
    if ok:
        r, g, b = blk[..., 0], blk[..., 1], blk[..., 2]
        green = ((g > r + 0.05) & (g > b + 0.05) & a).sum() / px
        red = ((r > 0.55) & (r > g + 0.3) & (r > b + 0.3) & a).sum() / px
        if w * h <= PROP_SMALL_AREA and green + red >= PROP_SMALL_MAX_SOFT:
            ok = False
        else:
            ok = green < PROP_MAX_GREEN
    _solid_cache[key] = ok
    return ok


def compute_blocked(m, imgs):
    blocked = np.zeros((H, W), bool)
    blocked |= m.forest
    cat = {'water': 0, 'trees': 0, 'props': 0}
    for (x, y), (ts, co, fl) in m.layers['Su'].items():
        base = tile_rgba(imgs, ts, co)
        vis = (base[..., 3] > 127) & is_blue(base)
        ov = m.layers['Su ayrıntılar 2'].get((x, y))
        if ov:
            t2 = tile_rgba(imgs, ov[0], ov[1], ov[2])
            vis &= ~((t2[..., 3] > 127) & ~is_blue(t2))
        if vis.sum() >= WATER_MIN_PIXELS and y - 1 >= 0:
            if not blocked[y - 1, x]:
                cat['water'] += 1
            blocked[y - 1, x] = True
    counts = {}
    for ob in m.objects:
        o = obj(ob['key'])
        layer = ob['layer']
        if layer.startswith('Ağaç'):
            band = TREE_BAND
            k = 'trees'
        elif layer in OBJ_LAYERS:
            if not solid_prop(ob['key']):
                continue
            band = min(max(float(o['h']) * 0.5, 8.0), 24.0)
            k = 'props'
        else:
            continue
        img = imgs[o['ts']]
        x0 = ob['cx'] - o['wt'] // 2
        y0 = ob['root'] - o['ht'] + 1
        blk = img[o['ay'] * T:(o['ay'] + o['ht']) * T, o['ax'] * T:(o['ax'] + o['wt']) * T]
        alpha = blk[..., 3] > 127
        if ob['flip']:
            alpha = alpha[:, ::-1]
        rows = np.nonzero(alpha.any(axis=1))[0]
        if len(rows) == 0:
            continue
        base_y = (y0 * T) + rows[-1] + 1
        for py in range(blk.shape[0]):
            wy = y0 * T + py
            if wy < base_y - band or wy >= base_y:
                continue
            xs = np.nonzero(alpha[py])[0]
            if len(xs) == 0:
                continue
            gy = int(math.floor((wy + 0.5 - FEET_SHIFT) / T))
            for px_ in xs:
                gx = int(math.floor((x0 * T + px_ + 0.5) / T))
                counts[(gx, gy, k)] = counts.get((gx, gy, k), 0) + 1
    for (gx, gy, k), n in counts.items():
        if n >= MIN_PIXELS and 0 <= gx < W and 0 <= gy < H:
            if not blocked[gy, gx]:
                cat[k] += 1
            blocked[gy, gx] = True
    return blocked, cat


def flood(blocked, start):
    seen = np.zeros_like(blocked)
    sx, sy = start
    if blocked[sy, sx]:
        raise RuntimeError('doğuş engelli')
    q = deque([(sx, sy)])
    seen[sy, sx] = True
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < W and 0 <= ny < H and not seen[ny, nx] and not blocked[ny, nx]:
                seen[ny, nx] = True
                q.append((nx, ny))
    return seen


def seal_pockets(m, imgs):
    blocked, cat = compute_blocked(m, imgs)
    reach = flood(blocked, P(*SPAWN))
    play = np.zeros((H, W), bool)
    play[PY0:PY0 + PLAY, PX0:PX0 + PLAY] = True
    pocket = ~blocked & ~reach & play
    for y, x in zip(*np.nonzero(pocket)):
        m.put('Orman parçaları', (int(x), int(y)), *BLOCKER_TILE)
        m.forest[y, x] = True
    return blocked, reach, int(pocket.sum()), cat


## ---------------------------------------------------------------- yazım
def gid_tables():
    first = {}
    g = 1
    for key, _, cols, count in TILESETS:
        first[key] = (g, cols)
        g += count
    return first


def write_tmx(m, path):
    first = gid_tables()
    lines = ['<?xml version="1.0" encoding="UTF-8"?>',
             '<map version="1.10" tiledversion="1.12.2" orientation="orthogonal" renderorder="right-down" width="%d" height="%d" '
             'tilewidth="16" tileheight="16" infinite="0" nextlayerid="%d" nextobjectid="1">' % (W, H, len(LAYERS) + 20)]
    for key, src, cols, count in TILESETS:
        lines.append(' <tileset firstgid="%d" source="%s"/>' % (first[key][0], src))
    lid = 1
    cur_group = None
    for grp, name in LAYERS:
        if grp != cur_group:
            if cur_group is not None:
                lines.append(' </group>')
            lines.append(' <group id="%d" name="%s">' % (lid, grp))
            lid += 1
            cur_group = grp
        data = m.layers[name]
        rows = []
        for y in range(H):
            row = []
            for x in range(W):
                t = data.get((x, y))
                if t is None:
                    row.append('0')
                else:
                    ts, (c, r), fl = t
                    g0, cols = first[ts]
                    g = g0 + r * cols + c
                    row.append(str(g | FH if fl else g))
            rows.append(','.join(row))
        lines.append('  <layer id="%d" name="%s" width="%d" height="%d">' % (lid, name, W, H))
        lid += 1
        lines.append('   <data encoding="csv">')
        lines.append(',\n'.join(rows))
        lines.append('</data>')
        lines.append('  </layer>')
    lines.append(' </group>')
    lines.append('</map>')
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')


WATER_COLOR = np.array([62, 152, 160], np.uint8)  ## kis_su.gdshader su_rengi
ICE_UNDER = np.array([67, 109, 174], np.uint8)


def render(m, imgs, path=None, layers=None, rect=None):
    x0, y0, x1, y1 = rect if rect else (0, 0, W, H)
    canvas = np.zeros(((y1 - y0) * T, (x1 - x0) * T, 4), np.uint8)
    canvas[..., 3] = 255
    canvas[..., :3] = (30, 30, 30)
    for grp, name in LAYERS:
        if layers is not None and name not in layers:
            continue
        if name == 'Orman parçaları':
            continue
        for (x, y), (ts, co, fl) in m.layers[name].items():
            if not (x0 <= x < x1 and y0 <= y < y1):
                continue
            t = tile_rgba(imgs, ts, co, fl)
            if name == 'Su':
                t = t.copy()
                t[..., :3] = WATER_COLOR
            a = t[..., 3:4].astype(np.float32) / 255.0
            dst = canvas[(y - y0) * T:(y - y0 + 1) * T, (x - x0) * T:(x - x0 + 1) * T]
            if name == 'Buz':
                dst[..., :3] = ICE_UNDER  ## buz yarı saydam: altındaki su (kis_buz.gdshader su_rengi)
            dst[..., :3] = (t[..., :3] * a + dst[..., :3] * (1 - a)).astype(np.uint8)
    img = Image.fromarray(canvas, 'RGBA')
    if path:
        img.save(path)
    return img


def write_meta(m, path):
    sx, sy = P(*SPAWN)
    lines = ['extends RefCounted', '',
             '## AYAZ DAĞI (kış) haritasının çalışma anı verisi - tools/kis/gen_kis.py --write ÜRETİR (elle düzenleme; üreteç ezer).',
             '## Koordinatlar dünya pikseli (Harita (0,0)\'da). Oyun alanı hücre Rect2i(%d, %d, %d, %d).' % (PX0, PY0, PLAY, PLAY), '',
             'const PLAY_CELLS := Rect2i(%d, %d, %d, %d)' % (PX0, PY0, PLAY, PLAY),
             'const SPAWN := Vector2(%d, %d)' % (sx * T + 8, sy * T + 8),
             '## Gece ışıkları: [tür, dünya konumu] (alevler, kristal, dev buz ağacı, sıcak kaynak) - kis_fx.gd kurar']
    lines.append('const LIGHTS := [')
    for kind, (x, y) in m.meta_lights:
        lines.append('\t["%s", Vector2(%.1f, %.1f)],' % (kind, x, y))
    lines.append(']')
    lines.append('## ISINMA NOKTALARI (ileride üşüme / ısınma mekaniği okur): [tür, dünya konumu (ateşin dibi), yarıçap px]. Türler: kamp_atesi,')
    lines.append('## buyuk_mangal, mangal, mesale, kaplica. kis_fx.gd her birine "isi_kaynagi" grubunda bir düğüm koyar (meta: tur, yaricap).')
    lines.append('const HEAT_SOURCES := [')
    for kind, (x, y), r in m.heat:
        lines.append('\t["%s", Vector2(%.1f, %.1f), %.1f],' % (kind, x, y, r))
    lines.append(']')
    lines.append('## Duman tüten ateşler (kamp ateşi + büyük mangal): alevin tepesi (dünya px)')
    lines.append('const SMOKE := [')
    for (x, y) in m.smoke:
        lines.append('\tVector2(%.1f, %.1f),' % (x, y))
    lines.append(']')
    lines.append('## Sıcak kaynak buharı: [merkez dünya px, yarıçap x, yarıçap y] (hücre ortası)')
    lines.append('const STEAM := [')
    for (cx, cy, rx, ry, _) in SPRINGS:
        x, y = P(cx, cy)
        lines.append('\t[Vector2(%.1f, %.1f), %.1f, %.1f],' % (x * T, y * T, rx * T, ry * T))
    lines.append(']')
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')


def minimap(m, img_full):
    small = img_full.resize((W, H), Image.BOX).convert('RGB')
    a = np.array(small).astype(np.float32)
    a = np.where(m.forest[..., None], a * 0.62, a)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), 'RGB')


IMGS = None


def main():
    global IMGS
    write = '--write' in sys.argv
    os.makedirs(OUT_DIR, exist_ok=True)
    imgs = load_sheets()
    IMGS = imgs
    m = Map(imgs)
    build_terrain(m)
    cell_masks(m)
    build_band(m)
    paint_terrain(m)
    place_brush(m)
    place_landmarks(m)
    for (cx, cy, rx, ry, _) in SPRINGS:
        x, y = P(cx, cy)
        m.heat.append(('kaplica', (x * T, y * T), HEAT_RADIUS['kaplica']))
        m.meta_lights.append(('kaplica', (x * T, y * T)))
    ntorch = place_path_torches(m)
    nband = place_band(m)
    nclus = place_rock_clusters(m)
    nscat = place_scatter(m)
    trees = collect_trees(m)
    placed, skipped = assign_tree_layers(m, trees)
    for ob in m.objects:
        if ob['key'].startswith('kristal_dev'):
            x, top = obj_px(ob['key'], ob['cx'], ob['root'])
            m.meta_lights.append(('kristal', (x, top + obj(ob['key'])['h'] * 0.5)))
    ndec = place_ground_decor(m)
    nspots = place_spots(m, imgs)
    nplants = place_plants(m)
    nwater = place_water_decor(m, imgs)
    ncrack = place_cracks(m, imgs)
    ## madde 676: görünmez engelin (şerit / plato / sırt) kenarı görünen kaya / ağaca hizalanır (tools/harita_duvar.py)
    cov_layers = OBJ_LAYERS + ['Ağaç %d' % i for i in range(TREE_LAYERS)]
    cov = harita_duvar.nesne_ortusu(m, imgs, tile_rgba, cov_layers, H, W, T, FEET_SHIFT)
    nfill = harita_duvar.kenar_doldur(m, imgs, cov, compute_blocked, flood, P(*SPAWN), lambda x, y, rnd: rim_rock(m, x, y, rnd))
    cov = harita_duvar.nesne_ortusu(m, imgs, tile_rgba, cov_layers, H, W, T, FEET_SHIFT)
    ncut = harita_duvar.duvari_hizala(m, imgs, cov, compute_blocked, flood, P(*SPAWN), (PX0, PY0, PLAY, PLAY))
    blocked, reach, npocket, cat = seal_pockets(m, imgs)
    rim_all, rim_open = harita_duvar.acik_kenar(m, imgs, cov, compute_blocked, flood, P(*SPAWN))
    print('duvar hizalama: kenar dolgusu %d, kırpılan %d hücre, kenar %d (açık görünen %d)' % (nfill, ncut, rim_all, rim_open))
    play = blocked[PY0:PY0 + PLAY, PX0:PX0 + PLAY]
    rplay = reach[PY0:PY0 + PLAY, PX0:PX0 + PLAY]
    nobj = sum(1 for o in m.objects if o['layer'] in OBJ_LAYERS)
    print('meşale (yol): %d  şerit kaya: %d  küme kaya: %d  serpiştirme: %s  y-sıralı nesne toplam: %d' % (ntorch, nband, nclus, nscat, nobj))
    print('ağaç: %d (sığmayan %d)  yer süsü: %s  leke: %d  bitki: %d  su süsü: %d  çatlak: %d  çalılık: %d' % (
        placed, skipped, ndec, nspots, nplants, nwater, ncrack, len(m.brush_sites)))
    print('ateş: %d  ışınma noktası: %d  gece ışığı: %d' % (sum(1 for o in m.objects if o['key'] in FIRE_KEYS), len(m.heat), len(m.meta_lights)))
    print('engel hücre (oyun alanı): %d / %d  ulaşılabilir: %d (%%%.1f)  kapatılan cep: %d  kategori: %s' % (
        int(play.sum()), PLAY * PLAY, int(rplay.sum()), 100.0 * rplay.sum() / (PLAY * PLAY), npocket, cat))
    full = render(m, imgs, os.path.join(OUT_DIR, 'onizleme_tam.png'))
    full.resize((full.width // 4, full.height // 4), Image.BOX).save(os.path.join(OUT_DIR, 'onizleme_4.png'))
    ov = np.array(full.resize((W * 4, H * 4), Image.BOX).convert('RGBA'))
    bm = np.kron(blocked, np.ones((4, 4), bool))
    rm = np.kron(reach, np.ones((4, 4), bool))
    ov[bm] = (ov[bm] * 0.45 + np.array([200, 30, 30, 255]) * 0.55).astype(np.uint8)
    ov[~bm & ~rm] = (ov[~bm & ~rm] * 0.5 + np.array([30, 30, 220, 255]) * 0.5).astype(np.uint8)
    Image.fromarray(ov, 'RGBA').save(os.path.join(OUT_DIR, 'engel_4.png'))
    mm = minimap(m, full)
    mm.save(os.path.join(OUT_DIR, 'minimap.png'))
    with open(os.path.join(OUT_DIR, 'nesneler.json'), 'w', encoding='utf-8') as f:
        json.dump([{'key': o['key'], 'layer': o['layer'], 'cx': o['cx'], 'root': o['root'], 'flip': o['flip']} for o in m.objects
                   if o['kind'] not in ('bitki', 'cicek')], f, ensure_ascii=False)
    np.save(os.path.join(OUT_DIR, 'engel.npy'), blocked)
    np.save(os.path.join(OUT_DIR, 'ulasilir.npy'), reach)
    if write:
        if os.path.exists(TMX_PATH) and os.path.exists(MD5_PATH) and '--force' not in sys.argv:
            with open(TMX_PATH, 'rb') as f:
                now = hashlib.md5(f.read()).hexdigest()
            if now != open(MD5_PATH).read().strip():
                print('DURDU: harita/kis.tmx son yazımdan sonra değişmiş (Tiled?) - elle düzenlemeleri korumak için yazılmadı. '
                      'Bilerek ezmek için --write --force.')
                sys.exit(2)
        write_tmx(m, TMX_PATH)
        mm.save(MINIMAP_PATH)
        write_meta(m, META_PATH)
        with open(TMX_PATH, 'rb') as f:
            md5 = hashlib.md5(f.read()).hexdigest()
        with open(MD5_PATH, 'w') as f:
            f.write(md5)
        print('yazıldı:', TMX_PATH, md5)


if __name__ == '__main__':
    main()
