# KARA BATAKLIK haritası üreteci (yeni açık hava haritası, 2026-11-09; kullanıcı: "ana haritanın %70 büyüklüğünde ... bataklık biyomu
# assetlerini kullan ve güzel hoş bir bataklık ormanı tasarla"). Oyun alanı 214x214 hücre (= ana haritanın 256x256 alanının %70'i) + ana
# haritanınki gibi 32/20 hücrelik geçilmez dış çerçeve (kamera kenarı boş göstermesin). Sonlu TMX: oyun alanı hücre (32,20)'den başlar.
#
# KATMANLAR Harita.tmx ile AYNI adlarda (oyunun ana harita sistemleri değişmeden çalışsın): collision (terrain_collision.gd: "Su/Su" +
# "Su/Su ayrıntılar 2" görünür su pikseli, "Shader Eklenecek/Ağaç N" gövde bandı, "Animasyonsuz çalılar" / "Orman parçaları 3" katı nesne),
# orman duvarı (= "Orman parçaları/Orman parçaları" hücreleri: geçilmez + görüşü keser), derinlik ön kopyaları (depth_occluders.gd), ağaç / ot
# sallanması (tree_sway / grass_sway), saklanma çalılığı ("Orman parçaları/Saklanma Çalılığı", eğrelti yatağı satırları 4-7).
#
# ARAZİ = köşe ızgarası (dual grid): su / kara, kara üstünde çamur / çimen, çimen üstünde uzun çimen. Bataklık setinin kenar karoları köşe
# temellidir: karo, 4 köşesinin hangisi o arazide olduğuna göre seçilir (3x3 ada bloğu + 2x2 iç köşe bloğu); yalnız çapraz iki köşe
# (KD+GB ya da KB+GD) çiziminde yoktur -> temizlikte ızgaradan atılır. Su katmanı ana haritadaki gibi DÜZ MAVİ karo (collision mavi pikseli
# su sayar) - bataklık suyu scenes/bataklik_su.gdshader ile çizilir.
#
# ÇİZİM SIRASI kuralları (Godot): "Shader Eklenecek" y-sıralı; Ağaç / Animasyonsuz çalılar / Çalılar / Çiçekler katmanları y=0'da TEK parça
# sıralanır (sahne sırasıyla), "Çalılar1" karoları tek tek y'ye göre hepsinden SONRA. Bu yüzden:
#  - üst üste binen ağaçlarda güneydeki (kökü aşağıda olan) daha üst Ağaç katmanına konur (kuzeyden güneye atama);
#  - nesne ağaçla bindiğinde nesne ağacın KUZEYİNDE olmalı (ağaç üstte çizilir);
#  - ot/çiçek bir nesneyle bindiğinde: ot nesnenin kuzeyindeyse "Çalılar" (altta), güneyindeyse "Çalılar1" (üstte).
#
# Kullanım (proje kökünden):
#   python -I tools/bataklik/gen_bataklik.py            -> önizleme + rapor (tools/bataklik/out/), TMX'e yazmaz
#   python -I tools/bataklik/gen_bataklik.py --write    -> harita/bataklik.tmx + assets/ui/minimap_bataklik.png + scripts/bataklik_meta.gd
#     (md5 kapısı: TMX son yazımdan sonra Tiled'da değiştiyse durur; --force ezer). Sonra: Godot --headless --import, bake_bataklik.gd.
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
ATLAS = json.load(open(os.path.join(HERE, 'atlas.json'), encoding='utf-8'))
HDIR = os.path.join(ROOT, 'harita')
BDIR = os.path.join(HDIR, 'bataklik')
OUT_DIR = os.path.join(HERE, 'out')
TMX_PATH = os.path.join(HDIR, 'bataklik.tmx')
MINIMAP_PATH = os.path.join(ROOT, 'assets', 'ui', 'minimap_bataklik.png')
META_PATH = os.path.join(ROOT, 'scripts', 'bataklik_meta.gd')
MD5_PATH = os.path.join(HERE, 'son_yazim.md5')  ## son --write'ın TMX md5'i (Tiled düzenlemesi kapısı)
SEED = 20261109
## Madde 525: bataklık suyu YÜRÜNÜR (map_profiles "su_yurunur", terrain_collision suyu saymaz) - ulaşılabilirlik taklidi de suyu engel saymaz.
WATER_BLOCKS = False
WATER_MASK_PATH = os.path.join(ROOT, 'assets', 'map', 'bataklik_su_derinlik.png')
MASK_TEXEL = 2  ## dünya px / teksel (scripts/wade_fx.gd ile aynı)
MASK_DEPTH_PX = 40.0  ## kıyıdan bu kadar px içeride derinlik tam
## SÜS YOĞUNLUĞU (madde 527, kullanıcı: "ağaçları bitkileri süsleri vs azaltmanı istiyorum haritada genel olarak çok göz yoruyor herşey").
## Tek yer: yorum içindeki sayı = madde 524/525'teki ilk değer. Yer işaretleri (cadı kulübesi, iskelet, mantar evi...) ve saklanma çalılıkları
## (oyun mekaniği) değişmedi.
YOGUNLUK = {
    'orman_aralik': 3,       ## 2: sık koru / kenar bandında gövdeler arası (Chebyshev) - büyük = seyrek
    'kume_aralik': 13,       ## 8: geçiş bölgesinde ağaç kümesi merkezleri arası
    'kume_agac': (2, 3),     ## (2, 5): kümedeki ağaç sayısı
    'tek_aralik': 13,        ## 9: çayırda tek ağaçlar arası
    'tek_sayi': 50,          ## 150
    'nesne_sayi': 70,        ## 170: küçük nesne (taş, kütük, mantar...)
    'kiyi_saz': (0.10, 0.10),  ## (0.30, 0.25): suya bitişik karada saz olasılığı (taban, gürültü payı)
    'patika_ot': 0.005,      ## 0.015
    'orman_ortu': 0.08,      ## 0.30: koru tabanında ot/eğrelti
    'cayir_ot': (0.010, 0.035, 0.03),  ## (0.03, 0.10, 0.10): çayır / geçiş taban olasılığı + gürültü payı
    'cicek': 0.003,          ## 0.012
    'su_dalga': 0.020,       ## 0.045
    'su_nilufer': 0.04,      ## 0.10
    'su_mercimek': 0.025,    ## 0.07
    'leke_deneme': 1300,     ## 4200: çimen lekesi
}

T = 16
PLAY = 214
RX, RY = 32, 20
W, H = PLAY + 2 * RX, PLAY + 2 * RY  ## 278 x 254 hücre
PX0, PY0 = RX, RY  ## oyun alanının sol üst hücresi

## ---------------------------------------------------------------- karo setleri (TMX sırası = firstgid sırası)
TILESETS = [
    ('taban', 'bataklik/Bataklık taban.tsx', 2, 2),
    ('zemin', 'bataklik/Bataklık zemin.tsx', 21, 21 * 26),
    ('leke', 'bataklik/Bataklık leke.tsx', 21, 21 * 16),
    ('su', 'bataklik/Bataklık su.tsx', 37, 37 * 78),
    ('nilufer', 'bataklik/Bataklık nilüfer.tsx', 7, 7 * 43),
    ('mercimek', 'bataklik/Bataklık mercimek.tsx', 11, 11 * 48),
    ('kiyi', 'bataklik/Bataklık kıyı.tsx', 39, 39 * 48),
    ('nesne', 'bataklik/Bataklık nesne.tsx', 64, 64 * 88),
    ('calilik', 'bataklik/Bataklık çalılık.tsx', 16, 128),
]
TS_FILES = {'taban': 'b_taban.png', 'zemin': 'b_zemin.png', 'leke': 'b_leke.png', 'su': 'b_su.png', 'nilufer': 'b_nilufer.png',
            'mercimek': 'b_mercimek.png', 'kiyi': 'b_kiyi.png', 'nesne': 'b_nesne.png', 'calilik': 'b_calilik.png'}
## Arazi blokları: (karo seti, 3x3 ada sol üst, 2x2 iç köşe sol üst)
BLOCK_COAST = ('kiyi', (2, 1), (5, 1))       ## çimen kıyısı (kara = çimen, dışı su)
BLOCK_GRASS = ('zemin', (1, 22), (4, 22))    ## çamur üstüne çimen
BLOCK_TALL = ('zemin', (1, 8), (4, 8))       ## çimen üstüne uzun çimen
MUD_FILL = ('zemin', (2, 2))
WATER_TILE = ('taban', (0, 0))
BLOCKER_TILE = ('taban', (1, 0))

## Katmanlar: (grup, ad) çizim sırasıyla. Harita.tmx adları; "Su süsleri", "Leke" bu haritaya özgü (collision onları saymaz).
LAYERS = [
    ('Yer', 'Zemin Toprak'), ('Yer', 'Zemin Çimen'), ('Yer', 'Leke'),
    ('Su', 'Su'), ('Su', 'Su süsleri'), ('Su', 'Su ayrıntılar 2'),
    ('Orman parçaları', 'Saklanma Çalılığı'), ('Orman parçaları', 'Orman parçaları'), ('Orman parçaları', 'Orman parçaları 3'),
    ('Shader Eklenecek', 'Çiçekler 1'), ('Shader Eklenecek', 'Çalılar'), ('Shader Eklenecek', 'Çalılar1'),
    ('Shader Eklenecek', 'Animasyonsuz çalılar'),
] + [('Shader Eklenecek', 'Ağaç %d' % i) for i in range(8)]
TREE_LAYERS = 8

## terrain_collision.gd sabitleri (ayak izi taklidi - oyundaki hesapla aynı)
FEET_SHIFT = 15.0
MIN_PIXELS = 20
TREE_BAND = 9.0
WATER_MIN_PIXELS = 100
PROP_MIN_W, PROP_MIN_H, PROP_MIN_PIXELS, PROP_MIN_DENSITY, PROP_MAX_GREEN = 18, 14, 220, 0.35, 0.4
PROP_SMALL_AREA, PROP_SMALL_MAX_SOFT = 700.0, 0.15

rng = random.Random(SEED)
nprng = np.random.default_rng(SEED)


def P(x, y):
    """oyun alanı yerel hücresi -> harita hücresi"""
    return x + PX0, y + PY0


## ---------------------------------------------------------------- görüntüler
def load_sheets():
    imgs = {}
    for key, _, cols, _ in TILESETS:
        path = os.path.join(BDIR, TS_FILES[key])
        imgs[key] = np.array(Image.open(path).convert('RGBA'))
    return imgs


def ensure_base_tiles():
    """b_taban.png: 0 = düz mavi su (collision su sayar; görünüşü bataklik_su.gdshader), 1 = tamamen saydam (görünmez engel)."""
    img = Image.new('RGBA', (32, 16), (0, 0, 0, 0))
    for y in range(16):
        for x in range(16):
            img.putpixel((x, y), (40, 96, 200, 255))
    img.save(os.path.join(BDIR, 'b_taban.png'))
    tsx = ('<?xml version="1.0" encoding="UTF-8"?>\n'
           '<tileset version="1.10" tiledversion="1.12.2" name="Bataklık taban" tilewidth="16" tileheight="16" tilecount="2" columns="2">\n'
           ' <image source="b_taban.png" width="32" height="16"/>\n</tileset>\n')
    with open(os.path.join(BDIR, 'Bataklık taban.tsx'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(tsx)


def tile_px(imgs, ts, c, r):
    return imgs[ts][r * T:(r + 1) * T, c * T:(c + 1) * T]


def nonempty_tiles(img):
    h, w = img.shape[0] // T, img.shape[1] // T
    a = img[:, :, 3].reshape(h, T, w, T).max(axis=(1, 3))
    return a > 0


def components(mask, r0, r1):
    """mask satır r0..r1 arası 8-komşu bağlı karo kümeleri -> [[(c, r), ...]] (damga)"""
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


## ---------------------------------------------------------------- gürültü
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


## ---------------------------------------------------------------- tasarım (oyun alanı yerel hücre koordinatı, 0..213)
SPAWN = (107, 178)
REGIONS = {
    'kamp': (107, 178),        ## doğuş: açık çayır + yeşil alevli meşaleler
    'cadi': (40, 38),          ## KB: cadı oyuğu (cadı kulübesi, kazan, totemler)
    'sazlik': (110, 26),       ## K: sazlık gölcükler
    'kemik': (174, 40),        ## KD: kemik tarlası (dev iskelet, kafa ağaçları)
    'mantar': (34, 106),       ## B: mantar korusu
    'tapinak': (180, 108),     ## D: yıkık tapınak (harabeler, heykeller)
    'egrelti': (40, 172),      ## GB: eğrelti vadisi (çadır, yırtıcı bitkiler)
    'olu_orman': (172, 174),   ## GD: ölü orman (yüzlü ağaç, kafa ağacı)
}
LAKE = (106, 100, 31, 20)      ## Kara Göl: merkez + yarıçaplar (hücre)
## Patikalar: kamptan göle iner, göl çevresinde batı ve doğu kolları (kıyıdan uzak), kuzeyde sazlık yayı; dış kenarı dolanan halka YOK.
TRAILS = [
    ['kamp', (104, 162), (97, 146), (100, 133)],
    [(100, 133), (82, 130), (64, 120), (50, 112), 'mantar'],
    [(100, 133), (122, 136), (142, 128), (160, 118), 'tapinak'],
    ['mantar', (42, 88), (50, 66), (44, 50), 'cadi'],
    ['cadi', (60, 28), (82, 20), 'sazlik'],
    ['sazlik', (134, 22), (152, 30), 'kemik'],
    ['kemik', (186, 60), (190, 84), 'tapinak'],
    ['kamp', (86, 190), (64, 186), 'egrelti'],
    ['kamp', (126, 192), (150, 188), 'olu_orman'],
]
CLEARINGS = {'kamp': 14, 'cadi': 9, 'sazlik': 5, 'kemik': 9, 'mantar': 8, 'tapinak': 9, 'egrelti': 8, 'olu_orman': 9}
MUD_FLATS = {'kamp': 7, 'cadi': 6, 'kemik': 5, 'tapinak': 4}


def catmull(points, steps=10):
    pts = [points[0]] + points + [points[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = [np.array(p, float) for p in pts[i - 1:i + 3]]
        for s in range(steps):
            t = s / steps
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(np.array(points[-1], float))
    return out


def trail_points():
    out = []
    for tr in TRAILS:
        pts = [REGIONS[p] if isinstance(p, str) else p for p in tr]
        ## kıvrım: ara noktalara gürültü + her aralığa bir yan sapma noktası (patika düz çizgi gibi durmasın)
        jit = [pts[0]]
        for a, b in zip(pts[:-1], pts[1:]):
            dx, dy = b[0] - a[0], b[1] - a[1]
            L = math.hypot(dx, dy) + 1e-6
            off = rng.uniform(-0.16, 0.16) * L
            jit.append(((a[0] + b[0]) / 2 - dy / L * off, (a[1] + b[1]) / 2 + dx / L * off))
            jit.append(b if b is pts[-1] else (b[0] + rng.uniform(-2.5, 2.5), b[1] + rng.uniform(-2.5, 2.5)))
        out.append(catmull(jit, 10))
    return out


def dist_field(shape, pts_list, widths=None):
    """vertex ızgarasında her noktanın polyline'lara en yakın uzaklığı (hücre)"""
    vh, vw = shape
    yy, xx = np.mgrid[0:vh, 0:vw]
    d = np.full(shape, 1e9)
    for pts in pts_list:
        for a, b in zip(pts[:-1], pts[1:]):
            ax, ay = a
            bx, by = b
            dx, dy = bx - ax, by - ay
            L2 = dx * dx + dy * dy + 1e-9
            x0, x1 = int(min(ax, bx)) - 14, int(max(ax, bx)) + 15
            y0, y1 = int(min(ay, by)) - 14, int(max(ay, by)) + 15
            x0, y0 = max(0, x0), max(0, y0)
            x1, y1 = min(vw, x1), min(vh, y1)
            if x1 <= x0 or y1 <= y0:
                continue
            sx = xx[y0:y1, x0:x1]
            sy = yy[y0:y1, x0:x1]
            t = np.clip(((sx - ax) * dx + (sy - ay) * dy) / L2, 0, 1)
            px = ax + t * dx
            py = ay + t * dy
            dd = np.hypot(sx - px, sy - py)
            d[y0:y1, x0:x1] = np.minimum(d[y0:y1, x0:x1], dd)
    return d


## ---------------------------------------------------------------- köşe ızgarası temizliği
def fix_diagonals(v, prefer=None):
    """çapraz (yalnız iki karşı köşe) 2x2 pencereleri doldurur: çizimi olmayan karo kalmasın. prefer: True -> 1'e doldur, False -> 0'a."""
    for _ in range(40):
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
    """value değerli 4-komşu küçük bileşenleri tersine çevirir"""
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


## ---------------------------------------------------------------- harita durumu
class Map:
    def __init__(self, imgs):
        self.imgs = imgs
        self.layers = {name: {} for _, name in LAYERS}
        self.nesne_ne = nonempty_tiles(imgs['nesne'])
        self.objects = []  ## yerleştirilen nesneler: dict(key, layer, cells, root, x, y, kind)
        self.cover = {}  ## hücre -> [nesne indeksleri] (bitki/çizim sırası denetimi)
        self.base_cells = set()  ## nesnelerin alt iki satırı + altındaki satır (çalılık / küçük süs buraya girmez)
        self.meta_lights = []
        self.fireflies = []

    def put(self, layer, cell, ts, coord):
        x, y = cell
        if 0 <= x < W and 0 <= y < H:
            self.layers[layer][(x, y)] = (ts, coord)

    ## Nesnenin yazılacak karoları (blok içi): dolu karolar + onları 4-komşu BAĞLAYAN saydam karolar. Oyun nesneyi "atlasta sağ/alt komşu
    ## karo" zinciriyle tanır (depth_occluders.object_bases): arada boş karo kalırsa nesne parçalanır, kopan parça (ör. tacın bir ucu) kendi
    ## kökünü alır -> havada gövde bandı (hayalet engel) ve yanlış derinlik. Bağlayıcı saydam karo çizim yapmaz, yalnız zinciri tamamlar.
    def stamp(self, key):
        if not hasattr(self, '_stamps'):
            self._stamps = {}
        if key in self._stamps:
            return self._stamps[key]
        o = ATLAS['objects'][key]
        full = {(tx, ty) for ty in range(o['ht']) for tx in range(o['wt']) if self.nesne_ne[o['ay'] + ty, o['ax'] + tx]}
        tiles = set(full)
        while True:
            ## bileşenler (4-komşu)
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
            ## en büyük bileşene en kısa yol (blok içinde, BFS) - yol üstündeki boş karolar eklenir
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

    ## nesne damgası: kök (en alt satır) hücresi (cx, by); yatayda blok ortalı
    def obj_cells(self, key, cx, by):
        o = ATLAS['objects'][key]
        x0 = cx - o['wt'] // 2
        y0 = by - o['ht'] + 1
        return [((x0 + tx, y0 + ty), (o['ax'] + tx, o['ay'] + ty)) for (tx, ty) in self.stamp(key)]

    def can_place(self, key, cx, by, layer):
        for (c, _) in self.obj_cells(key, cx, by):
            if not (0 <= c[0] < W and 0 <= c[1] < H):
                return False
            if c in self.layers[layer]:
                return False
        return True

    def place(self, key, cx, by, layer, kind):
        cells = [(c, a) for (c, a) in self.obj_cells(key, cx, by) if 0 <= c[0] < W and 0 <= c[1] < H]
        idx = len(self.objects)
        for (c, a) in cells:
            self.layers[layer][c] = ('nesne', a)
            self.cover.setdefault(c, []).append(idx)
            if c[1] >= by - 1 and kind != 'bitki':
                self.base_cells.add(c)
                self.base_cells.add((c[0], by + 1))
        self.objects.append({'key': key, 'layer': layer, 'cells': [c for c, _ in cells], 'root': by, 'cx': cx, 'kind': kind})
        return idx


## ---------------------------------------------------------------- ARAZİ
def build_terrain(m):
    VH, VW = H + 1, W + 1
    yy, xx = np.mgrid[0:VH, 0:VW]
    lx = xx - PX0  ## oyun alanı yerel (köşe) koordinatı
    ly = yy - PY0
    n1 = fbm((VH, VW), 22, SEED + 1)
    n2 = fbm((VH, VW), 9, SEED + 2)
    n3 = fbm((VH, VW), 40, SEED + 3)

    ## 1) SU alanı (> 0 su)
    wet = np.full((VH, VW), -1.0)
    cx, cy, rx, ry = LAKE
    d = np.hypot((lx - cx) / rx, (ly - cy) / ry)
    wet = np.maximum(wet, 1.0 - d + (n1 - 0.5) * 0.55 + (n2 - 0.5) * 0.18)
    ## göl kolları
    for (ax, ay, arx, ary) in [(80, 86, 12, 8), (134, 112, 13, 7), (96, 120, 10, 5), (124, 82, 9, 7)]:
        dd = np.hypot((lx - ax) / arx, (ly - ay) / ary)
        wet = np.maximum(wet, 1.0 - dd + (n2 - 0.5) * 0.4)
    ## gölcükler: bölgeye göre yoğunluk (K sazlık bol)
    ## Gölcükler: her biri 2-4 üst üste binen eğik elips (yuvarlak leke gibi durmasın) + kenarı gürültülü. Bataklık kümeleri: bir merkez
    ## çevresinde 3-6 küçük gölcük (sazlıklı çamurluk hissi).
    pools = []
    tries = 0

    def pool_ok(px, py, r, gap):
        if math.hypot(px - SPAWN[0], py - SPAWN[1]) < 24:
            return False
        if math.hypot((px - cx) / (rx + 6), (py - cy) / (ry + 6)) < 1.0:
            return False
        if any(math.hypot(px - REGIONS[k][0], py - REGIONS[k][1]) < CLEARINGS[k] + r + 1 for k in REGIONS):
            return False
        if any(math.hypot(px - q[0], py - q[1]) < q[2] + r + gap for q in pools):
            return False
        return 8 < px < PLAY - 8 and 8 < py < PLAY - 8

    while len(pools) < 40 and tries < 5000:
        tries += 1
        px, py = rng.uniform(8, PLAY - 8), rng.uniform(8, PLAY - 8)
        r = rng.uniform(2.6, 7.0)
        if pool_ok(px, py, r, 6):
            pools.append((px, py, r))
    ## bataklık kümeleri (sazlık kuzey, göl kıyıları, ölü orman güneyi)
    for (mx, my, n) in [(96, 40, 6), (130, 42, 5), (70, 104, 4), (146, 96, 4), (150, 160, 4), (62, 158, 4), (186, 132, 3), (24, 128, 3)]:
        for _ in range(n * 8):
            px, py = mx + rng.uniform(-11, 11), my + rng.uniform(-8, 8)
            r = rng.uniform(1.6, 3.4)
            if pool_ok(px, py, r, 2.5):
                pools.append((px, py, r))
                n -= 1
                if n <= 0:
                    break
    for (px, py, r) in pools:
        for k in range(rng.randint(2, 4)):
            ox, oy = (0.0, 0.0) if k == 0 else (rng.uniform(-0.8, 0.8) * r, rng.uniform(-0.6, 0.6) * r)
            e = rng.uniform(0.55, 1.6)
            ang = rng.uniform(0, math.pi)
            ca, sa = math.cos(ang), math.sin(ang)
            rr = r * (1.0 if k == 0 else rng.uniform(0.45, 0.8))
            ux = (lx - px - ox) * ca + (ly - py - oy) * sa
            uy = -(lx - px - ox) * sa + (ly - py - oy) * ca
            dd = np.hypot(ux / (rr * e), uy / (rr / e))
            wet = np.maximum(wet, 1.0 - dd + (n2 - 0.5) * 0.55)
    ## sazlık: kuzeyde birbirine yakın küçük gölcük kümesi + kıvrımlı dere (göl -> kuzey)
    stream = catmull([(106, 82), (104, 66), (112, 52), (108, 36), (118, 24), (128, 16)], 14)
    sd = dist_field((VH, VW), [[(p[0] + PX0, p[1] + PY0) for p in stream]])
    wet = np.maximum(wet, 1.0 - sd / (1.6 + 1.2 * n2))
    stream2 = catmull([(132, 116), (146, 126), (152, 142), (162, 150)], 14)
    sd2 = dist_field((VH, VW), [[(p[0] + PX0, p[1] + PY0) for p in stream2]])
    wet = np.maximum(wet, 1.0 - sd2 / (1.4 + 1.0 * n2))
    ## dış çerçeve + kenar bandı: seyrek su
    edge = np.minimum.reduce([lx, ly, PLAY - lx, PLAY - ly])
    wet = np.where(edge < -3, np.maximum(wet, (n3 - 0.74) * 3.0), wet)

    ## 2) KURU tutulacak yerler: doğuş + bölge açıklıkları + patikalar (genişlik + 3 hücre pay)
    dry = np.zeros((VH, VW), bool)
    for k, (rxk, ryk) in REGIONS.items():
        dry |= np.hypot(lx - rxk, ly - ryk) < CLEARINGS[k] + n2 * 2
    trails = trail_points()
    tpts = [[(p[0] + PX0, p[1] + PY0) for p in tr] for tr in trails]
    td = dist_field((VH, VW), tpts)
    tw = 1.3 + 1.2 * n2  ## patika yarı genişliği (köşe)
    dry |= td < tw + 3.2
    water = (wet > 0) & ~dry
    ## göl adaları (ulaşılamaz süs: kafa ağacı, heykel)
    islands = [(98, 94, 3.2, 2.4), (118, 104, 2.6, 2.0)]
    for (ix_, iy_, irx, iry) in islands:
        water &= ~(np.hypot((lx - ix_) / irx, (ly - iy_) / iry) < 1.0)
    water = remove_small(water, 3, True)
    water = remove_small(water, 4, False)  ## 1-3 köşelik kara kırıntısı (su içinde) -> su
    for (ix_, iy_, irx, iry) in islands:  ## adalar kalsın
        water &= ~(np.hypot((lx - ix_) / irx, (ly - iy_) / iry) < 1.0)
    water = fix_diagonals(water, prefer=True)
    land = ~water

    ## 3) ÇAMUR: patikalar + açıklık çamurları, suya en az 2 köşe uzak (kıyı karoları hep çimen kıyısı)
    mud = (td < tw)
    for k, r in MUD_FLATS.items():
        rxk, ryk = REGIONS[k]
        mud |= np.hypot(lx - rxk, ly - ryk) < r + (n2 - 0.5) * 3
    ## suya uzaklık (Chebyshev, köşe)
    wd = cheb_dist(water, 4)
    mud &= land & (wd > 2)
    mud = remove_small(mud, 5, True)
    mud = remove_small(mud, 3, False)
    mud = fix_diagonals(mud, prefer=False)
    mud &= land & (wd > 2)
    mud = fix_diagonals(mud, prefer=False)
    grass = land & ~mud

    ## 4) UZUN ÇİMEN lekeleri: çimen üstünde, çamur ve sudan en az 2 köşe
    tn = fbm((VH, VW), 7, SEED + 9)
    tall = (tn > 9.0) & grass  ## KAPALI: lekenin içi çimenle aynı renk, yalnız saçak kontur çizgisi gibi görünüyordu
    tall = remove_small(tall, 6, True)
    tall = remove_small(tall, 3, False)
    tall = fix_diagonals(tall, prefer=False)
    tall &= grass & (cheb_dist(~grass, 3) > 1)
    tall = fix_diagonals(tall, prefer=False)

    m.v_water, m.v_land, m.v_mud, m.v_grass, m.v_tall = water, land, mud, grass, tall
    m.trail_dist = td
    m.edge = edge
    m.pools = pools
    m.islands = islands



def drain_forest_water(m):
    """Madde 525: su yürünür -> orman duvarı (görünmez engel) suyun içinden geçmesin (gölcüğün ortasında görünmez duvar). Bir köşeye değen 4
    hücreden biri orman ise o köşe kuru: orman hücresinin hiçbir köşesi su değil, gölcük kıyısı orman kenarından önce biter (kıyı karosuyla)."""
    f = m.forest
    near = np.zeros((H + 1, W + 1), bool)
    near[:-1, :-1] |= f
    near[:-1, 1:] |= f
    near[1:, :-1] |= f
    near[1:, 1:] |= f
    water = m.v_water & ~near
    water = remove_small(water, 3, True)
    water = remove_small(water, 4, False)
    water = fix_diagonals(water, prefer=False)
    water &= ~near
    water = fix_diagonals(water, prefer=False)
    m.v_water = water
    m.v_land = ~water
    m.v_mud &= m.v_land
    m.v_grass = m.v_land & ~m.v_mud
    m.v_tall &= m.v_grass


def forest_floor(m):
    """Sık koru + kenar bandı zemini KOYU ÇAMUR (yaprak çürüğü): koru kütlesi uzaktan da okunsun, kenarında çimen saçağı. Köşe, çevresindeki 4
    hücre de orman ise çamur (koru kenarından yarım hücre içeride biter); suya 2 köşe kuralı ve çapraz temizliği yine geçerli."""
    f = m.forest
    v = np.zeros((H + 1, W + 1), bool)
    v[1:-1, 1:-1] = f[:-1, :-1] & f[:-1, 1:] & f[1:, :-1] & f[1:, 1:]
    wd = cheb_dist(m.v_water, 4)
    mud = m.v_mud | (v & m.v_land & (wd > 2))
    mud = remove_small(mud, 5, True)
    mud = remove_small(mud, 3, False)
    mud = fix_diagonals(mud, prefer=False)
    mud &= m.v_land & (wd > 2)
    mud = fix_diagonals(mud, prefer=False)
    m.v_mud = mud
    m.v_grass = m.v_land & ~mud
    tall = m.v_tall & m.v_grass & (cheb_dist(~m.v_grass, 3) > 1)
    tall = remove_small(tall, 6, True)
    m.v_tall = fix_diagonals(tall, prefer=False)
    m.c_mud = mud[:-1, :-1] | mud[:-1, 1:] | mud[1:, :-1] | mud[1:, 1:]


def paint_terrain(m):
    land, grass, tall = m.v_land, m.v_grass, m.v_tall
    for y in range(H):
        for x in range(W):
            wc = corner_code(land, x, y)  ## kara köşeleri
            if wc != 15:
                m.put('Su', (x, y), *WATER_TILE)
                if wc != 0:
                    m.put('Su ayrıntılar 2', (x, y), *block_tile(BLOCK_COAST, wc))
                continue
            m.put('Zemin Toprak', (x, y), *MUD_FILL)
            gc = corner_code(grass, x, y)
            if gc != 0:
                m.put('Zemin Çimen', (x, y), *block_tile(BLOCK_GRASS, gc))
            ## uzun çimen (BLOCK_TALL) kapalı: lekenin içi çimenle aynı renk, yalnız saçağı kontur çizgisi gibi görünüyordu


def cheb_dist(mask, maxd):
    """her köşenin mask'e Chebyshev uzaklığı (maxd'ye kadar, ötesi maxd+1)"""
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


## ---------------------------------------------------------------- hücre sınıfları (yerleşim kuralları)
def cell_masks(m):
    land = m.v_land
    full_land = land[:-1, :-1] & land[:-1, 1:] & land[1:, :-1] & land[1:, 1:]  ## (H, W) hücre: 4 köşe kara
    full_water = m.v_water[:-1, :-1] & m.v_water[:-1, 1:] & m.v_water[1:, :-1] & m.v_water[1:, 1:]
    mud_any = m.v_mud[:-1, :-1] | m.v_mud[:-1, 1:] | m.v_mud[1:, :-1] | m.v_mud[1:, 1:]
    m.c_land = full_land
    m.c_water = full_water
    m.c_mud = mud_any
    td = m.trail_dist
    m.c_trail = np.minimum.reduce([td[:-1, :-1], td[:-1, 1:], td[1:, :-1], td[1:, 1:]])
    m.c_edge = np.minimum.reduce([m.edge[:-1, :-1], m.edge[1:, 1:]])
    ## suya uzaklık (hücre)
    m.c_wd = cheb_dist(~full_land, 8)


## ---------------------------------------------------------------- orman duvarı (geçilmez bant + korular)
def build_forest(m):
    cn = fbm((H, W), 11, SEED + 21)
    yy, xx = np.mgrid[0:H, 0:W]
    lx, ly = xx - PX0, yy - PY0
    edge = np.minimum.reduce([lx, ly, PLAY - 1 - lx, PLAY - 1 - ly])
    cn2 = fbm((H, W), 30, SEED + 23, 2)
    depth = 2.5 + cn * 5.0 + np.clip(cn2 - 0.35, 0, 1) * 18.0  ## kenar ormanı derinliği: kısa dalgalı + yer yer derin girintiler
    band = edge < depth
    ## YOĞUNLUK alanı: düşük frekanslı gürültü + kenara yaklaştıkça artar; bölge açıklıkları, patikalar ve göl kıyısı açar.
    ## > T_KORU: sık koru (geçilmez + görüşü keser), T_GECIS..T_KORU: ağaç kümeleri, altı: açık çayır (tek tük ağaç).
    d = 0.7 * fbm((H, W), 24, SEED + 71, 4) + 0.3 * fbm((H, W), 9, SEED + 72, 3)
    d = (d - d.min()) / (d.max() - d.min())
    open_ = np.zeros((H, W))
    for k, (rxk, ryk) in REGIONS.items():
        r = (CLEARINGS[k] + 5) * 1.7
        open_ = np.maximum(open_, np.clip(1.0 - np.hypot(lx - rxk, ly - ryk) / r, 0, 1))
    trail = np.clip(1.0 - (m.c_trail - 2.0) / 8.0, 0, 1)
    cx, cy, rx, ry = LAKE
    lake_d = np.hypot((lx - cx) / (rx + 12), (ly - cy) / (ry + 12))
    lake_open = np.clip(1.4 - lake_d, 0, 1)
    edge_up = np.clip(1.0 - edge / 26.0, 0, 1) * 0.35
    D = d + edge_up - 0.75 * open_ - 0.55 * trail - 0.5 * lake_open
    play = (lx >= 0) & (ly >= 0) & (lx < PLAY) & (ly < PLAY)
    vals = D[play & m.c_land & ~band]
    m.T_KORU = float(np.percentile(vals, 87))
    m.T_GECIS = float(np.percentile(vals, 60))
    m.D = D
    ## patika ve açıklıkları kesmesin
    keep_open = m.c_trail < 4.5
    for k, (rxk, ryk) in REGIONS.items():
        keep_open |= np.hypot(lx - rxk, ly - ryk) < CLEARINGS[k] + 2
    gmask = (D > m.T_KORU) & m.c_land & ~keep_open & play
    gmask = remove_small(gmask, 16, True)
    gmask = remove_small(gmask, 6, False)
    gmask &= ~keep_open & m.c_land
    band &= ~(keep_open & (edge >= 2))
    m.forest = band | gmask
    m.forest_band = band
    m.zone = np.where(m.forest, 2, np.where(D > m.T_GECIS, 1, 0))  ## 2 koru, 1 geçiş, 0 çayır
    for y in range(H):
        for x in range(W):
            if m.forest[y, x]:
                m.put('Orman parçaları', (x, y), *BLOCKER_TILE)


## ---------------------------------------------------------------- nesneler
TREE_SETS = {
    'yesil': ['yesil_agac_1', 'yesil_agac_2', 'yesil_agac_3', 'yesil_agac_4', 'cali_agac_1', 'cali_agac_2', 'cali_agac_3'],
    'olu': ['olu_agac_1', 'olu_agac_2', 'olu_agac_3', 'olu_agac_4', 'kavisli_agac_1', 'kavisli_agac_2', 'kavisli_agac_3', 'kavisli_agac_4'],
    'egrelti': ['egrelti_agac_1', 'egrelti_agac_2', 'egrelti_agac_3', 'egrelti_agac_4', 'egrelti_fidan_1', 'egrelti_fidan_2'],
    'kafa': ['kafa_agaci_2', 'kafa_agaci_3', 'kafa_agaci_4'],
}
## bölge -> ağaç karışımı (ağırlık)
REGION_TREES = {
    'kamp': {'yesil': 6, 'olu': 1, 'egrelti': 2},
    'cadi': {'olu': 5, 'kafa': 2, 'yesil': 2},
    'sazlik': {'yesil': 4, 'egrelti': 3, 'olu': 1},
    'kemik': {'olu': 5, 'kafa': 3, 'yesil': 1},
    'mantar': {'yesil': 4, 'egrelti': 2, 'olu': 1},
    'tapinak': {'yesil': 5, 'olu': 2},
    'egrelti': {'egrelti': 6, 'yesil': 3},
    'olu_orman': {'olu': 6, 'kafa': 2, 'yesil': 1},
}


def nearest_region(x, y):
    lx, ly = x - PX0, y - PY0
    return min(REGIONS, key=lambda k: math.hypot(lx - REGIONS[k][0], ly - REGIONS[k][1]))


def pick_tree(region, big=True):
    mix = REGION_TREES[region]
    tot = sum(mix.values())
    r = rng.uniform(0, tot)
    for s, w in mix.items():
        r -= w
        if r <= 0:
            break
    keys = TREE_SETS[s]
    if not big:
        keys = [k for k in keys if ATLAS['objects'][k]['ht'] <= 4] or keys
    return rng.choice(keys)


def obj_rect_ok(m, key, cx, by, need_land=True, avoid_forest=False):
    o = ATLAS['objects'][key]
    x0 = cx - o['wt'] // 2
    ## kök satırı ve bir üstü kara olmalı (gövde suya basmasın)
    for tx in range(o['wt']):
        for yy in (by, by - 1):
            x = x0 + tx
            if not (0 <= x < W and 0 <= yy < H):
                return False
            if need_land and not m.c_land[yy, x]:
                return False
    if avoid_forest:
        for tx in range(o['wt']):
            if m.forest[by, x0 + tx]:
                return False
    return True


def place_landmarks(m):
    """bölge başına elle tasarlanmış nesneler (y-sıralı nesne katmanı)"""
    L = 'Animasyonsuz çalılar'
    plan = {
        'cadi': [('cadi_kulubesi', 0, -2), ('kazan_2', -6, 3), ('cadi_totem_1', 7, 1), ('cadi_totem_2', -9, -2), ('cadi_totem_3', 5, 6),
                 ('kafa_kazik_1', -3, 6), ('kafa_kazik_2', 2, 7), ('kazan_3', -8, 6), ('ibrik_bitki_1', 9, -4), ('kucuk_mesale', -3, 1),
                 ('kucuk_mesale', 3, 1)],
        'kemik': [('dev_iskelet', 0, 0), ('kemik_1', -8, 5), ('kemik_2', 8, 4), ('kemik_3', 6, -6), ('kafa_kazik_1', -6, -4),
                  ('heykel_el', 9, 9), ('kafatasi_totem_2', -10, 1)],
        'mantar': [('mantar_evi', 0, -3), ('dev_mantar_1', -7, 2), ('dev_mantar_2', 7, 3), ('ak_mantar_1', -4, 7), ('ak_mantar_2', 5, -7),
                   ('kara_mantar_1', 8, 8), ('kizil_mantar_1', -9, -5), ('dev_mantar_3', 10, -2), ('yosun_mercan_1', -2, 8),
                   ('ak_mantar_3', 2, 5)],
        'tapinak': [('harabe_1', 0, -3), ('heykel_mizrak', -8, 2), ('heykel_bilge', 8, 2), ('harabe_2', -9, -6), ('harabe_3', 9, -6),
                    ('harabe_4', 4, 7), ('harabe_5', -5, 7), ('kaya_1', 11, 6)],
        'egrelti': [('cadir', 0, -3), ('yirtici_bitki_1', -7, 3), ('kazan_1', 4, 2), ('yirtici_bitki_1', 8, -3), ('kucuk_mesale', -2, 1),
                    ('kafatasi_totem_1', 7, 5)],
        'olu_orman': [('yuzlu_agac', 0, -2), ('kafa_agaci_1', 9, 5), ('kafatasi_totem_1', -8, 3), ('kutuk_1', -6, -6), ('kemik_3', 5, 7),
                      ('kafa_kazik_2', -3, 6)],
        'kamp': [('mesale', -5, -3), ('mesale', 5, -3), ('mesale', -6, 3), ('mesale', 6, 3), ('kutuk_6', -9, -7)],
        'sazlik': [('agac_ev', 6, -2), ('kucuk_mesale', 3, 2)],
    }
    for reg, items in plan.items():
        rx_, ry_ = REGIONS[reg]
        for key, dx, dy in items:
            cx, by = P(rx_ + dx, ry_ + dy)
            ok = False
            for attempt in range(30):
                jx = 0 if attempt == 0 else rng.randint(-2, 2)
                jy = 0 if attempt == 0 else rng.randint(-2, 2)
                if obj_rect_ok(m, key, cx + jx, by + jy, avoid_forest=True) and m.can_place(key, cx + jx, by + jy, L) \
                        and not near_spawn(cx + jx, by + jy, 4):
                    m.place(key, cx + jx, by + jy, L, 'nesne')
                    if key in ('mesale', 'kucuk_mesale', 'cadi_kulubesi', 'kazan_2', 'kazan_1'):
                        o = ATLAS['objects'][key]
                        m.meta_lights.append((key, cx + jx, by + jy, o['ht']))
                    ok = True
                    break
            if not ok:
                print('  yer işareti sığmadı:', reg, key)
    ## göl adaları: süs
    for (ix_, iy_, _, _), key in zip(m.islands, ['kafa_agaci_3', 'heykel_el']):
        cx, by = P(int(round(ix_)), int(round(iy_)) + 1)
        if m.can_place(key, cx, by, L):
            m.place(key, cx, by, L, 'nesne')


def near_spawn(x, y, r):
    sx, sy = P(*SPAWN)
    return math.hypot(x - sx, y - sy) < r


def collect_trees(m):
    """ağaç adayları: (anahtar, cx, kök). Katman ataması sonra (kuzeyden güneye)."""
    trees = []
    trunk = {}  ## gövde hücresi -> ağaç (aralık denetimi)

    def free(cx, by, r):
        for dx in range(-r, r + 1):
            for dy in range(-r, r + 1):
                if (cx + dx, by + dy) in trunk:
                    return False
        return True

    def add(key, cx, by):
        trees.append((key, cx, by))
        trunk[(cx, by)] = True

    ## 1) orman bandı + korular: sık (geçilmez alan zaten engel)
    fy, fx = np.nonzero(m.forest)
    order = list(zip(fx.tolist(), fy.tolist()))
    rng.shuffle(order)
    for (x, y) in order:
        if not m.c_land[y, x]:
            continue
        if not free(x, y, YOGUNLUK['orman_aralik']):
            continue
        reg = nearest_region(x, y)
        key = pick_tree(reg) if rng.random() < 0.6 else rng.choice(['cali_agac_1', 'cali_agac_1', 'yesil_agac_1', 'yesil_agac_2', 'cali_agac_3'])
        if not obj_rect_ok(m, key, x, y) or not south_of_objects(m, key, x, y):
            continue
        add(key, x, y)
    ## 2) yürünebilir alan: geçiş bölgesinde ağaç KÜMELERİ (2-5 ağaç, gövdeler arası 2-3 hücre), çayırda tek tük ağaç
    def open_ok(x, y):
        if m.forest[y, x] or not m.c_land[y, x] or m.c_trail[y, x] < 4.0 or m.c_wd[y, x] < 2:
            return False
        lx, ly = x - PX0, y - PY0
        if not (2 <= lx < PLAY - 2 and 2 <= ly < PLAY - 2):
            return False
        return not any(math.hypot(lx - REGIONS[k][0], ly - REGIONS[k][1]) < CLEARINGS[k] for k in REGIONS)

    clump_centers = []
    cand = [(float(m.D[y, x]) + rng.random() * 0.15, x, y) for y in range(H) for x in range(W) if m.zone[y, x] == 1 and open_ok(x, y)]
    cand.sort(reverse=True)
    for _, x, y in cand:
        if any(max(abs(x - a), abs(y - b)) < YOGUNLUK['kume_aralik'] for a, b in clump_centers):
            continue
        clump_centers.append((x, y))
        reg = nearest_region(x, y)
        n = rng.randint(*YOGUNLUK['kume_agac'])
        for _ in range(n * 6):
            tx, ty = x + rng.randint(-3, 3), y + rng.randint(-2, 2)
            if not (0 <= tx < W and 0 <= ty < H) or not open_ok(tx, ty) or not free(tx, ty, 1):
                continue
            key = pick_tree(reg, big=rng.random() < 0.6)
            if not obj_rect_ok(m, key, tx, ty) or not south_of_objects(m, key, tx, ty):
                continue
            add(key, tx, ty)
            n -= 1
            if n <= 0:
                break
    singles = 0
    cand = [(rng.random(), x, y) for y in range(H) for x in range(W) if m.zone[y, x] == 0 and open_ok(x, y)]
    cand.sort()
    for _, x, y in cand:
        if not free(x, y, YOGUNLUK['tek_aralik']):
            continue
        reg = nearest_region(x, y)
        key = pick_tree(reg)
        if not obj_rect_ok(m, key, x, y) or not south_of_objects(m, key, x, y):
            continue
        add(key, x, y)
        singles += 1
        if singles >= YOGUNLUK['tek_sayi']:
            break
    m.clumps = clump_centers
    return trees


def south_of_objects(m, key, x, y):
    """ağaç bir nesneyle (yer işareti) binerse ağaç nesnenin GÜNEYİNDE olmalı (Ağaç katmanları nesne katmanının üstünde çizilir), ayrıca
    ağacın kök satırı nesnenin karolarına girmesin"""
    for (c, _) in m.obj_cells(key, x, y):
        for oi in m.cover.get(c, []):
            if m.objects[oi]['root'] >= y - 1:
                return False
    return True


def assign_tree_layers(m, trees):
    """kuzeyden güneye: bindiği önceki ağaçlardan bir üst katman"""
    trees = sorted(trees, key=lambda t: (t[2], t[1]))
    cell_layer = {}  ## hücre -> en üst ağaç katmanı
    placed = 0
    skipped = 0
    for key, cx, by in trees:
        cells = m.obj_cells(key, cx, by)
        L = 0
        for (c, _) in cells:
            if c in cell_layer:
                L = max(L, cell_layer[c] + 1)
        if L >= TREE_LAYERS:
            skipped += 1
            continue
        lname = 'Ağaç %d' % L
        idx = m.place(key, cx, by, lname, 'agac')
        for (c, _) in cells:
            cell_layer[c] = L
        placed += 1
    return placed, skipped


## ---------------------------------------------------------------- küçük nesneler + bitkiler
def place_props(m):
    L = 'Animasyonsuz çalılar'
    keys_by_region = {
        'kamp': ['tas_5', 'tas_6', 'kaya_5', 'tas_7', 'tas_4'],
        'cadi': ['tas_6', 'kutuk_7', 'ibrik_bitki_2', 'kara_mantar_2', 'tas_5', 'kutuk_1'],
        'sazlik': ['tas_4', 'tas_6', 'kutuk_1', 'kaya_4', 'ibrik_bitki_2'],
        'kemik': ['kemik_2', 'kemik_3', 'tas_3', 'kutuk_7', 'tas_6'],
        'mantar': ['ak_mantar_2', 'ak_mantar_3', 'dev_mantar_4', 'kara_mantar_2', 'kizil_mantar_1', 'dev_mantar_3', 'ak_mantar_4'],
        'tapinak': ['kaya_2', 'kaya_3', 'tas_1', 'tas_2', 'harabe_5', 'kaya_4'],
        'egrelti': ['ibrik_bitki_2', 'ibrik_bitki_3', 'yirtici_bitki_1', 'tas_6', 'kutuk_1'],
        'olu_orman': ['kutuk_1', 'tas_3', 'kemik_2', 'kemik_3', 'tas_6', 'kirik_agac_3'],
    }
    flat_keys = ['kirik_agac_4', 'kirik_agac_3', 'kirik_agac_5', 'kutuk_2']
    count = 0
    pn = fbm((H, W), 10, SEED + 41)
    for _ in range(6000):
        x = rng.randint(PX0, PX0 + PLAY - 1)
        y = rng.randint(PY0, PY0 + PLAY - 1)
        if m.forest[y, x] or not m.c_land[y, x] or m.c_trail[y, x] < 3.5 or m.c_wd[y, x] < 2:
            continue
        if pn[y, x] < 0.45:
            continue
        if near_spawn(x, y, 10):
            continue
        reg = nearest_region(x, y)
        flat = rng.random() < 0.18
        key = rng.choice(flat_keys if flat else keys_by_region[reg])
        layer = 'Orman parçaları 3' if flat else L
        if not obj_rect_ok(m, key, x, y, avoid_forest=True) or not m.can_place(key, x, y, layer):
            continue
        ## başka nesnelere / ağaçlara binme: hiç binmesin (küçük nesne) ve çevresinde 2 hücre boşluk
        cells = m.obj_cells(key, x, y)
        bad = False
        for (c, _) in cells:
            for dx in (-2, -1, 0, 1, 2):
                for dy in (-1, 0, 1):
                    if (c[0] + dx, c[1] + dy) in m.cover:
                        bad = True
        if bad:
            continue
        m.place(key, x, y, layer, 'yassi' if flat else 'nesne')
        count += 1
        if count >= YOGUNLUK['nesne_sayi']:
            break
    return count


def plant_layer_for(m, cells, root):
    """bitki hücreleri nesnelerle binerse: nesnenin kuzeyindeyse Çalılar (altta), güneyindeyse Çalılar1 (üstte); ikisi birden -> None"""
    north = south = False
    for c in cells:
        for oi in m.cover.get(c, []):
            r = m.objects[oi]['root']
            if root < r:
                north = True
            elif root > r:
                south = True
            else:
                return None
    if north and south:
        return None
    return 'Çalılar1' if south else 'Çalılar'


def place_plants(m):
    plant_sets = {
        'kiyi': ['sazlik_1', 'sazlik_2', 'sazlik_3', 'sazlik_4', 'sazlik_5', 'sazlik_6', 'sazlik_7', 'sazlik_8', 'ot_2', 'ot_6'],
        'cayir': ['ot_1', 'ot_2', 'ot_3', 'ot_5', 'ot_7', 'parlak_ot_1', 'parlak_ot_2', 'parlak_ot_3', 'falez_3', 'falez_6', 'ot_4', 'ot_6'],
        'egrelti': ['falez_1', 'falez_2', 'falez_4', 'falez_5', 'cicekli_egrelti_1', 'cicekli_egrelti_2', 'egrelti_1', 'egrelti_2'],
        'mantar': ['gri_mantar_1', 'gri_mantar_2', 'kizil_mantar_2', 'kizil_mantar_3', 'kara_mantar_3', 'yosun_mercan_2', 'ibrik_bitki_4'],
        'cicek': ['pembe_cicek_1', 'pembe_cicek_2', 'ak_cicek_1', 'ak_cicek_2', 'ak_cicek_3', 'ak_cicek_4', 'cicekli_egrelti_3'],
        'kazik': ['kazik_2', 'kazik_3', 'kazik_4', 'kazik_5', 'yirtici_bitki_2', 'yirtici_bitki_3'],
    }
    used = set()

    def try_plant(key, x, y, flower=False):
        cells = [c for c, _ in m.obj_cells(key, x, y)]
        for c in cells:
            if not (0 <= c[0] < W and 0 <= c[1] < H) or c in used:
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

    pn = fbm((H, W), 6, SEED + 51)
    n = 0
    for y in range(H):
        for x in range(W):
            if not m.c_land[y, x] or m.layers['Saklanma Çalılığı'].get((x, y)):
                continue
            onpath = m.c_mud[y, x] or m.c_trail[y, x] < 2.5
            lx, ly = x - PX0, y - PY0
            inplay = 0 <= lx < PLAY and 0 <= ly < PLAY
            r = rng.random()
            wd = m.c_wd[y, x]
            reg = nearest_region(x, y)
            if wd <= 1 and not onpath:
                ## kıyı sazlığı: suya bitişik karada sık
                if r < YOGUNLUK['kiyi_saz'][0] + YOGUNLUK['kiyi_saz'][1] * pn[y, x]:
                    n += try_plant(rng.choice(plant_sets['kiyi']), x, y)
                continue
            if onpath:
                if r < YOGUNLUK['patika_ot']:
                    n += try_plant(rng.choice(plant_sets['cayir'][:5]), x, y)
                continue
            if m.forest[y, x]:
                ## orman bandında yer örtüsü (ağaç gövdeleri arası)
                if r < YOGUNLUK['orman_ortu']:
                    n += try_plant(rng.choice(plant_sets['egrelti'] * 2 + plant_sets['mantar'] + plant_sets['cayir'][:6]), x, y)
                continue
            if not inplay:
                continue
            co, cg, cn = YOGUNLUK['cayir_ot']
            dens = (co if m.zone[y, x] == 0 else cg) + cn * max(0.0, pn[y, x] - 0.45)
            if r < dens:
                if reg == 'mantar' and rng.random() < 0.55:
                    s = 'mantar'
                elif reg in ('egrelti', 'sazlik') and rng.random() < 0.5:
                    s = 'egrelti'
                elif reg in ('olu_orman', 'kemik', 'cadi') and rng.random() < 0.06:
                    s = 'kazik'
                else:
                    s = 'cayir'
                n += try_plant(rng.choice(plant_sets[s]), x, y)
            elif r < dens + YOGUNLUK['cicek'] and not near_spawn(x, y, 6):
                n += try_plant(rng.choice(plant_sets['cicek']), x, y, flower=True)
    return n


def place_water_decor(m, imgs):
    """dalga izleri + nilüfer + su mercimeği: yalnız tam su hücrelerinde, kıyıdan en az 1 hücre (Su süsleri katmanı collision'a girmez)"""
    su_ne = nonempty_tiles(imgs['su'])
    ripples = [c for c in components(su_ne, 1, 13) if len(c) >= 2]
    lilies = pixel_blob_stamps(imgs['nilufer'], 0, 7)
    ducks = pixel_blob_stamps(imgs['mercimek'], 0, 8)
    deep = m.c_water
    L = 'Su süsleri'
    used = set()
    dn = fbm((H, W), 9, SEED + 61)

    def stamp(ts, comp, x, y):
        c0 = min(c for c, r in comp)
        r0 = min(r for c, r in comp)
        cells = [((x + c - c0), (y + r - r0)) for c, r in comp]
        for (cx, cy) in cells:
            if not (0 <= cx < W and 0 <= cy < H) or not deep[cy, cx] or (cx, cy) in used:
                return False
        for (c, r), (cx, cy) in zip(comp, cells):
            m.put(L, (cx, cy), ts, (c, r))
            used.add((cx, cy))
        return True

    ys, xs = np.nonzero(deep)
    idx = list(range(len(xs)))
    rng.shuffle(idx)
    cnt = {'dalga': 0, 'nilufer': 0, 'mercimek': 0}
    for i in idx:
        x, y = int(xs[i]), int(ys[i])
        r = rng.random()
        pd, pl, pm = YOGUNLUK['su_dalga'], YOGUNLUK['su_nilufer'], YOGUNLUK['su_mercimek']
        if r < pd:
            cnt['dalga'] += stamp('su', rng.choice(ripples), x, y)
        elif r < pd + pl * dn[y, x]:
            cnt['nilufer'] += stamp('nilufer', rng.choice(lilies), x, y)
        elif r < pd + pl * dn[y, x] + pm * (1 - dn[y, x]):
            cnt['mercimek'] += stamp('mercimek', rng.choice(ducks), x, y)
    return cnt


def pixel_blob_stamps(img, r0, r1):
    """satır r0..r1 bandındaki piksel lekeleri (8-komşu opak piksel kümesi) -> leke başına karo damgası; damganın karolarına başka bir
    lekenin pikseli giriyorsa atlanır (su mercimeği sayfasında kümeler bitişik: karo bileşeni tüm satırı tek blok yapıp ızgara gibi tekrar ediyordu)"""
    a = img[r0 * T:r1 * T, :, 3] > 0
    hh, ww = a.shape
    lab = np.zeros(a.shape, np.int32)
    n = 0
    for y in range(hh):
        for x in range(ww):
            if a[y, x] and lab[y, x] == 0:
                n += 1
                st = [(y, x)]
                lab[y, x] = n
                while st:
                    cy, cx = st.pop()
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            ny, nx = cy + dy, cx + dx
                            if 0 <= ny < hh and 0 <= nx < ww and a[ny, nx] and lab[ny, nx] == 0:
                                lab[ny, nx] = n
                                st.append((ny, nx))
    out = []
    for i in range(1, n + 1):
        ys, xs = np.nonzero(lab == i)
        if len(ys) < 6:
            continue
        c0, c1 = xs.min() // T, xs.max() // T
        t0, t1 = ys.min() // T, ys.max() // T
        sub = lab[t0 * T:(t1 + 1) * T, c0 * T:(c1 + 1) * T]
        if np.any((sub != 0) & (sub != i)):
            continue
        out.append([(c, r0 + r) for r in range(t0, t1 + 1) for c in range(c0, c1 + 1)
                    if (lab[r * T:(r + 1) * T, c * T:(c + 1) * T] == i).any()])
    return out


def place_spots(m, imgs):
    """çimen üstü lekeler (açık/koyu yosun lekeleri): yalnız tam çimen hücrelerine"""
    ## tek karoluk, kenara değmeyen (kendi içinde kapalı) lekeler: komşu karoyla birleşen lekeler yarım kalmasın
    img = imgs['leke']
    comps = []
    for r in range(img.shape[0] // T):
        for c in range(img.shape[1] // T):
            a = img[r * T:(r + 1) * T, c * T:(c + 1) * T, 3] > 0
            if a.sum() >= 6 and not (a[0].any() or a[-1].any() or a[:, 0].any() or a[:, -1].any()):
                comps.append([(c, r)])
    grass_full = m.v_grass[:-1, :-1] & m.v_grass[:-1, 1:] & m.v_grass[1:, :-1] & m.v_grass[1:, 1:]
    n = 0
    for _ in range(YOGUNLUK['leke_deneme']):
        x, y = rng.randint(0, W - 1), rng.randint(0, H - 1)
        if not grass_full[y, x]:
            continue
        comp = rng.choice(comps)
        c0 = min(c for c, r in comp)
        r0 = min(r for c, r in comp)
        cells = [((x + c - c0), (y + r - r0)) for c, r in comp]
        if any(not (0 <= cx < W and 0 <= cy < H) or not grass_full[cy, cx] or (cx, cy) in m.layers['Leke'] for cx, cy in cells):
            continue
        for (c, r), (cx, cy) in zip(comp, cells):
            m.put('Leke', (cx, cy), 'leke', (c, r))
        n += 1
    return n


## ---------------------------------------------------------------- saklanma çalılığı (eğrelti yatağı)
def place_brush(m):
    L = 'Saklanma Çalılığı'
    patches = 0
    centers = []
    for _ in range(900):
        x = rng.randint(PX0 + 12, PX0 + PLAY - 13)
        y = rng.randint(PY0 + 12, PY0 + PLAY - 13)
        if near_spawn(x, y, 22):
            continue
        if any(math.hypot(x - a, y - b) < 22 for a, b in centers):
            continue
        if any(math.hypot(x - PX0 - REGIONS[k][0], y - PY0 - REGIONS[k][1]) < CLEARINGS[k] + 9 for k in REGIONS):
            continue
        blobs = [(0.0, 0.0, rng.uniform(3.0, 4.2), rng.uniform(2.2, 3.0))]
        for _ in range(rng.randint(1, 2)):
            blobs.append((rng.uniform(-3.0, 3.0), rng.uniform(-1.6, 1.6), rng.uniform(1.8, 3.0), rng.uniform(1.5, 2.4)))
        cells = []
        for dy in range(-6, 7):
            for dx in range(-8, 9):
                if any(((dx - bx) / brx) ** 2 + ((dy - by_) / bry) ** 2 < 1.0 for bx, by_, brx, bry in blobs):
                    cells.append((x + dx, y + dy))
        ## çalılık hücresi: kara, orman/patika/kıyı değil, bir nesnenin gövde/kök satırına (alt 2 satır) değmiyor - ağaç tacının altında
        ## kalabilir (çalılık zemin katmanında, tac üstte çizilir)
        ok = True
        for (cx, cy) in cells:
            if not m.c_land[cy, cx] or m.forest[cy, cx] or m.c_trail[cy, cx] < 3 or m.c_wd[cy, cx] < 2 or (cx, cy) in m.base_cells:
                ok = False
                break
        if not ok:
            continue
        cs = set(cells)
        ## tek hücrelik çıkıntıları temizle
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
            v = rng.choice([k for k in (4, 5, 6, 7) if k not in banned])
            var_of[c] = v
            m.put(L, c, 'calilik', (mask, v))
        centers.append((x, y))
        patches += 1
        if patches >= 11:
            break
    return patches


## ---------------------------------------------------------------- collision taklidi + ulaşılabilirlik
def tile_rgba(imgs, ts, coord):
    c, r = coord
    return imgs[ts][r * T:(r + 1) * T, c * T:(c + 1) * T]


def is_blue(px):
    r, g, b = px[..., 0] / 255.0, px[..., 1] / 255.0, px[..., 2] / 255.0
    return (b > g + 0.03) & (b > r + 0.1)


def compute_blocked(m, imgs):
    """oyundaki engel hücreleri (KÖK uzayı: oyuncunun gövde ortası). terrain_collision.gd + orman katmanı ile aynı kurallar."""
    blocked = np.zeros((H, W), bool)
    blocked |= m.forest
    cat = {'water': 0, 'trees': 0, 'props': 0}
    ## su: Su hücresi görünür mavi piksel >= 100 -> bir hücre yukarı (madde 525'ten beri bataklıkta su yürünür: WATER_BLOCKS False)
    for (x, y), (ts, co) in (m.layers['Su'].items() if WATER_BLOCKS else []):
        base = tile_rgba(imgs, ts, co)
        vis = (base[..., 3] > 127) & is_blue(base)
        ov = m.layers['Su ayrıntılar 2'].get((x, y))
        if ov:
            t2 = tile_rgba(imgs, *ov)
            cls2 = (t2[..., 3] > 127) & ~is_blue(t2)
            vis &= ~cls2
        if vis.sum() >= WATER_MIN_PIXELS and 0 <= y - 1:
            if not blocked[y - 1, x]:
                cat['water'] += 1
            blocked[y - 1, x] = True
    ## ağaçlar + katı nesneler (bant)
    nes = imgs['nesne']
    counts = {}
    for ob in m.objects:
        o = ATLAS['objects'][ob['key']]
        layer = ob['layer']
        if layer.startswith('Ağaç'):
            band = TREE_BAND
            k = 'trees'
        elif layer in ('Animasyonsuz çalılar', 'Orman parçaları 3'):
            if not solid_prop(nes, o):
                continue
            hh = float(o['h'])
            band = min(max(hh * 0.5, 8.0), 24.0) if layer == 'Animasyonsuz çalılar' else min(max(hh, 8.0), 48.0)
            k = 'props'
        else:
            continue
        x0 = ob['cx'] - o['wt'] // 2
        y0 = ob['root'] - o['ht'] + 1
        blk = nes[o['ay'] * T:(o['ay'] + o['ht']) * T, o['ax'] * T:(o['ax'] + o['wt']) * T]
        alpha = blk[..., 3] > 127
        rows = np.nonzero(alpha.any(axis=1))[0]
        if len(rows) == 0:
            continue
        base_y = (y0 * T) + rows[-1] + 1  ## kök: en alt opak satırın altı (dünya px)
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


_solid_cache = {}


def solid_prop(nes, o):
    key = (o['ax'], o['ay'])
    if key in _solid_cache:
        return _solid_cache[key]
    blk = nes[o['ay'] * T:(o['ay'] + o['ht']) * T, o['ax'] * T:(o['ax'] + o['wt']) * T].astype(float) / 255.0
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
    """doğuştan yürüyerek ulaşılamayan engelsiz hücreler (ağaç/su arası cepler) orman katmanına (görünmez engel): orada yaratık doğmasın,
    görev noktası seçilmesin. Ayrıca oyun alanında kaç yürünebilir hücre olduğunu döner."""
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
                    ts, (c, r) = t
                    g0, cols = first[ts]
                    row.append(str(g0 + r * cols + c))
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


def render(m, imgs, path, scale_div=1, layers=None):
    canvas = np.zeros((H * T, W * T, 4), np.uint8)
    canvas[..., 3] = 255
    canvas[..., :3] = (30, 30, 30)
    WATER_COLOR = np.array([36, 103, 75], np.uint8)
    for grp, name in LAYERS:
        if layers is not None and name not in layers:
            continue
        if name == 'Orman parçaları':
            continue
        for (x, y), (ts, co) in m.layers[name].items():
            t = tile_rgba(imgs, ts, co)
            if name == 'Su':
                t = t.copy()
                t[..., :3] = WATER_COLOR
            a = t[..., 3:4].astype(np.float32) / 255.0
            dst = canvas[y * T:(y + 1) * T, x * T:(x + 1) * T]
            dst[..., :3] = (t[..., :3] * a + dst[..., :3] * (1 - a)).astype(np.uint8)
    img = Image.fromarray(canvas, 'RGBA')
    if scale_div > 1:
        img = img.resize((img.width // scale_div, img.height // scale_div), Image.BOX)
    img.save(path)
    return img


def write_meta(m, path):
    sx, sy = P(*SPAWN)
    lines = ['extends RefCounted', '',
             '## KARA BATAKLIK haritasının çalışma anı verisi - tools/bataklik/gen_bataklik.py --write ÜRETİR (elle düzenleme; üreteç ezer).',
             '## Koordinatlar dünya pikseli (Harita (0,0)\'da). Oyun alanı hücre Rect2i(%d, %d, %d, %d).' % (PX0, PY0, PLAY, PLAY), '',
             'const PLAY_CELLS := Rect2i(%d, %d, %d, %d)' % (PX0, PY0, PLAY, PLAY),
             'const SPAWN := Vector2(%d, %d)' % (sx * T + 8, sy * T + 8),
             '## Işıklar: [tür, dünya konumu] (meşale alevi, cadı kulübesi feneri, kazan)']
    lights = []
    for key, cx, by, ht in m.meta_lights:
        o = ATLAS['objects'][key]
        ## ışık noktası: nesnenin üst kısmı (meşale alevi) / gövde ortası
        x0 = (cx - o['wt'] // 2) * T + o['ox'] + o['w'] / 2.0
        top = (by + 1) * T - o['h']
        if key in ('mesale', 'kucuk_mesale'):
            wy = top + 6
        elif key == 'cadi_kulubesi':
            wy = top + o['h'] * 0.62
        else:
            wy = top + o['h'] * 0.45
        lights.append('\t["%s", Vector2(%.1f, %.1f)],' % (key, x0, wy))
    lines.append('const LIGHTS := [')
    lines += lights
    lines.append(']')
    lines.append('## Ateş böceği alanları (gece): [merkez, yarıçap] - göl kıyıları, gölcükler, sazlık')
    lines.append('const FIREFLY_ZONES := [')
    for (cx, cy, r) in m.fireflies:
        lines.append('\t[Vector2(%.1f, %.1f), %.1f],' % (cx, cy, r))
    lines.append(']')
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')


def water_mask(m, imgs):
    """SU DERİNLİK MASKESİ (madde 525, scripts/wade_fx.gd + scenes/bataklik_su_ayak.gdshader): harita tamamı, MASK_TEXEL dünya px / teksel,
    L8: 0 = kara, 1..255 = görünür su (Su karosu - kıyı karosunun opak, mavi olmayan pikselleri; terrain_collision'ın su sınıflamasıyla aynı)
    + kıyıya uzaklık (MASK_DEPTH_PX'te 255). Teksel, 2x2 pikselinin en az 3'ü su ise su (kıyı çizgisinde çimene taşmasın)."""
    water = np.zeros((H * T, W * T), bool)
    for (x, y), (ts, co) in m.layers['Su'].items():
        base = tile_rgba(imgs, ts, co)
        vis = (base[..., 3] > 127) & is_blue(base)
        ov = m.layers['Su ayrıntılar 2'].get((x, y))
        if ov:
            t2 = tile_rgba(imgs, *ov)
            vis &= ~((t2[..., 3] > 127) & ~is_blue(t2))
        water[y * T:(y + 1) * T, x * T:(x + 1) * T] = vis
    k = MASK_TEXEL
    w2 = water.reshape(H * T // k, k, W * T // k, k).sum(axis=(1, 3)) >= 3
    ## kıyıya uzaklık (teksel, 4-komşu aşındırma adımları)
    steps = int(MASK_DEPTH_PX / k)
    dist = np.zeros(w2.shape, np.int32)
    cur = w2.copy()
    for i in range(steps):
        er = cur.copy()
        er[1:, :] &= cur[:-1, :]
        er[:-1, :] &= cur[1:, :]
        er[:, 1:] &= cur[:, :-1]
        er[:, :-1] &= cur[:, 1:]
        dist += er
        cur = er
    val = np.where(w2, 1 + np.round(dist / max(1, steps) * 254.0), 0).astype(np.uint8)
    return Image.fromarray(val, 'L')


def firefly_zones(m):
    zones = []
    cx, cy, rx, ry = LAKE
    for a in range(0, 360, 30):
        t = math.radians(a)
        px = cx + math.cos(t) * (rx + 2)
        py = cy + math.sin(t) * (ry + 2)
        zones.append(((px + PX0) * T, (py + PY0) * T, 70.0))
    for (px, py, r) in m.pools:
        if rng.random() < 0.55:
            zones.append(((px + PX0) * T, (py + PY0) * T, max(40.0, r * T * 1.3)))
    m.fireflies = zones


def minimap(m, img_full):
    """1 doku pikseli = 1 hücre (harita tamamı, köken 0,0): tam çizimin hücre ortalaması, su biraz koyu, orman duvarı koyulaştırılmış"""
    small = img_full.resize((W, H), Image.BOX).convert('RGB')
    a = np.array(small).astype(np.float32)
    f = m.forest[..., None]
    a = np.where(f, a * 0.55, a)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), 'RGB')


def main():
    write = '--write' in sys.argv
    os.makedirs(OUT_DIR, exist_ok=True)
    ensure_base_tiles()
    imgs = load_sheets()
    m = Map(imgs)
    build_terrain(m)
    cell_masks(m)
    build_forest(m)
    drain_forest_water(m)
    cell_masks(m)
    forest_floor(m)
    paint_terrain(m)
    place_landmarks(m)
    trees = collect_trees(m)
    placed, skipped = assign_tree_layers(m, trees)
    nprops = place_props(m)
    nbrush = place_brush(m)
    nplants = place_plants(m)
    wdec = place_water_decor(m, imgs)
    nspots = place_spots(m, imgs)
    firefly_zones(m)
    blocked, reach, npocket, cat = seal_pockets(m, imgs)
    play = blocked[PY0:PY0 + PLAY, PX0:PX0 + PLAY]
    rplay = reach[PY0:PY0 + PLAY, PX0:PX0 + PLAY]
    print('ağaç: %d (sığmayan %d)  nesne: %d  bitki: %d  çalılık: %d  su süsü: %s  leke: %d' % (placed, skipped, nprops, nplants, nbrush, wdec, nspots))
    print('engel hücre (oyun alanı): %d / %d  ulaşılabilir: %d (%%%.1f)  kapatılan cep: %d  kategori: %s' % (
        int(play.sum()), PLAY * PLAY, int(rplay.sum()), 100.0 * rplay.sum() / (PLAY * PLAY), npocket, cat))
    full = render(m, imgs, os.path.join(OUT_DIR, 'onizleme_tam.png'))
    full.resize((full.width // 4, full.height // 4), Image.BOX).save(os.path.join(OUT_DIR, 'onizleme_4.png'))
    ## engel görselleştirmesi (kök uzayı)
    ov = np.array(full.resize((W * 4, H * 4), Image.BOX).convert('RGBA'))
    bm = np.kron(blocked, np.ones((4, 4), bool))
    rm = np.kron(reach, np.ones((4, 4), bool))
    ov[bm] = (ov[bm] * 0.45 + np.array([200, 30, 30, 255]) * 0.55).astype(np.uint8)
    ov[~bm & ~rm] = (ov[~bm & ~rm] * 0.5 + np.array([30, 30, 220, 255]) * 0.5).astype(np.uint8)
    Image.fromarray(ov, 'RGBA').save(os.path.join(OUT_DIR, 'engel_4.png'))
    mm = minimap(m, full)
    mm.save(os.path.join(OUT_DIR, 'minimap.png'))
    with open(os.path.join(OUT_DIR, 'nesneler.json'), 'w', encoding='utf-8') as f:
        json.dump([{'key': o['key'], 'layer': o['layer'], 'cx': o['cx'], 'root': o['root']} for o in m.objects if o['kind'] != 'bitki'],
                  f, ensure_ascii=False)
    np.save(os.path.join(OUT_DIR, 'engel.npy'), blocked)
    np.save(os.path.join(OUT_DIR, 'ulasilir.npy'), reach)
    if write:
        ## md5 kapısı (CLAUDE.md harita kuralı): TMX son yazımdan sonra Tiled'da değiştiyse üzerine yazma (--force ile ezilir)
        if os.path.exists(TMX_PATH) and os.path.exists(MD5_PATH) and '--force' not in sys.argv:
            with open(TMX_PATH, 'rb') as f:
                now = hashlib.md5(f.read()).hexdigest()
            if now != open(MD5_PATH).read().strip():
                print('DURDU: harita/bataklik.tmx son yazımdan sonra değişmiş (Tiled?) - elle düzenlemeleri korumak için yazılmadı. '
                      'Bilerek ezmek için --write --force.')
                sys.exit(2)
        write_tmx(m, TMX_PATH)
        mm.save(MINIMAP_PATH)
        write_meta(m, META_PATH)
        water_mask(m, imgs).save(WATER_MASK_PATH)
        with open(TMX_PATH, 'rb') as f:
            md5 = hashlib.md5(f.read()).hexdigest()
        with open(MD5_PATH, 'w') as f:
            f.write(md5)
        print('yazıldı:', TMX_PATH, md5)


if __name__ == '__main__':
    main()
