# ALTIN KUMLAR haritası üreteci (çöl, 2026-11-09; kullanıcı: "ana haritanın %90 büyüklüğünde yeni bir harita ... çöl assetlerini kullanarak
# çöl tasarla ... su ilgi alanları da olsun, su kenarlarını çöle ait animasyonlu su kenarlarıyla ... Y ekseni ve collision sınırları iyi olsun").
# Oyun alanı 243x243 hücre (= ana haritanın 256x256 alanının %90'ı) + ana harita gibi 32/20 hücrelik geçilmez dış çerçeve. Sonlu TMX: oyun
# alanı hücre (32,20)'den başlar. Kara Bataklık üretecinin (tools/bataklik/gen_bataklik.py) çöl karşılığı: aynı katman adları (Harita.tmx),
# aynı köşe ızgarası arazisi, aynı collision taklidi + cep mühürleme, aynı md5 kapısı.
#
# ARAZİ = köşe ızgarası (dual grid): su / kara, kara üstünde kum / çimen. Kıyılar çöl setinin ANİMASYONLU kıyı karoları (Water_coasts): kum
# kıyısı (0,1)+(3,1) ya da çimen kıyısı (0,5)+(3,5) - zemin parçalarıyla kıyı YAPILMAZ. Bir kıyı hücresinin kara köşeleri hep aynı türde
# (yeşil vaha: suya 1 köşe yakın kara hep çimen; kum havuzu: suya 2 köşe yakın kara hep kum). Çimen kenarı setin saçaklı çimen bloğu
# (8,30)+(11,30). Çapraz iki köşe (6/9) çizimi YOK -> fix_diagonals.
#
# ÇİZİM SIRASI (Godot, "Shader Eklenecek" y-sıralı; Ağaç / Animasyonsuz çalılar / Kayalar / Çalılar katmanları y=0'da TEK parça, "Çalılar1"
# karoları tek tek y'ye göre hepsinden SONRA; derinlik ön kopyaları depth_occluders.gd):
#  - y-sıralı nesneler (kaya, kaya sütunu, kaktüs, kafatası, harabe, yer işareti) 4 katmana dağılır ("Animasyonsuz çalılar", "Kayalar 1..3"):
#    üst üste binenlerde güneydeki (kökü aşağıda) daha üst katmanda (kuzeyden güneye atama) - kaya şeridi sık ve doğal dursun;
#  - üst üste binen ağaçlarda güneydeki üst Ağaç katmanında; ağaç bir nesneyle binerse ağaç nesnenin GÜNEYİNDE (Ağaç katmanları üstte);
#  - ot/çiçek nesneyle binerse: nesnenin kuzeyindeyse "Çalılar" (altta), güneyindeyse "Çalılar1" (üstte).
#
# Kullanım (proje kökünden):
#   python -I tools/col/gen_col.py            -> önizleme + rapor (tools/col/out/), TMX'e yazmaz
#   python -I tools/col/gen_col.py --write    -> harita/col.tmx + assets/ui/minimap_col.png + scripts/col_meta.gd (md5 kapısı; --force ezer)
#   Sonra: Godot --headless --path . --import, Godot --headless --path . -s tools/col/bake_col.gd
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
CDIR = os.path.join(HDIR, 'col')
OUT_DIR = os.path.join(HERE, 'out')
TMX_PATH = os.path.join(HDIR, 'col.tmx')
MINIMAP_PATH = os.path.join(ROOT, 'assets', 'ui', 'minimap_col.png')
META_PATH = os.path.join(ROOT, 'scripts', 'col_meta.gd')
MD5_PATH = os.path.join(HERE, 'son_yazim.md5')
SEED = 20261110
FH = 0x80000000  ## Tiled yatay çevirme bayrağı

## SÜS YOĞUNLUĞU (Kara Bataklık madde 527 dersi: göz yormasın) - tek yer.
YOGUNLUK = {
    'serit_deneme': 26000,     ## kaya şeridi yerleştirme denemesi
    'serit_aralik': 3,         ## şeritte kök hücreleri arası (Chebyshev) en az
    'palmiye_aralik': 3,       ## vaha halkasında gövdeler arası
    'olu_agac_aralik': 7,      ## ölü ağaç ovasında
    'tek_agac': 34,            ## kumda tek tük ölü ağaç / palmiye
    'kaktus': 150,             ## dağınık kaktüs (kaktüs bahçesi ayrıca)
    'kaya': 95,                ## dağınık kaya / kaya sütunu
    'kuru_ot': 0.010,          ## kum hücresi başına kuru ot olasılığı (bozkır payı ayrıca)
    'bozkir_ot': 0.05,         ## vaha çevresi bozkırda
    'cimen_ot': 0.06,          ## çimen hücresinde yeşil ot
    'cicek': 0.025,            ## çimende çiçek (suya yakın)
    'filiz': 0.03,             ## bozkırda animasyonlu minik filiz
    'tumsek': 900,             ## kum tümseği denemesi
    'leke': 900,               ## bozkır çimen lekesi denemesi
    'su_dalga': 0.03,          ## tam su hücresi başına dalga izi
}

T = 16
PLAY = 243
RX, RY = 32, 20
W, H = PLAY + 2 * RX, PLAY + 2 * RY  ## 307 x 283 hücre
PX0, PY0 = RX, RY

## Karo setleri (TMX sırası = firstgid sırası): (anahtar, tsx yolu, atlas.json sayfa adı)
TS_ORDER = [('taban', 'col/Çöl taban.tsx', 'Çöl taban'), ('zemin', 'col/Çöl zemin.tsx', 'Çöl zemin'), ('leke', 'col/Çöl leke.tsx', 'Çöl leke'),
            ('su', 'col/Çöl su.tsx', 'Çöl su'), ('kiyi', 'col/Çöl kıyı.tsx', 'Çöl kıyı'), ('filiz', 'col/Çöl filiz.tsx', 'Çöl filiz'),
            ('nesne', 'col/Çöl nesne.tsx', 'Çöl nesne'), ('kaktus', 'col/Çöl kaktüs.tsx', 'Çöl kaktüs'),
            ('calilik', 'col/Çöl çalılık.tsx', 'Çöl çalılık')]
TILESETS = []
TS_FILES = {}
for _k, _p, _n in TS_ORDER:
    _s = ATLAS['sheets'][_n]
    TILESETS.append((_k, _p, _s['cols'], _s['cols'] * (_s['h'] // T)))
    TS_FILES[_k] = _s['file']

BLOCK_COAST_SAND = ('kiyi', (0, 1), (3, 1))
BLOCK_COAST_GRASS = ('kiyi', (0, 5), (3, 5))
BLOCK_GRASS = ('zemin', (8, 30), (11, 30))
SAND_FILL = ('zemin', (2, 25))
WATER_TILE = ('taban', (0, 0))
BLOCKER_TILE = ('taban', (1, 0))

OBJ_LAYERS = ['Animasyonsuz çalılar', 'Kayalar 1', 'Kayalar 2', 'Kayalar 3']
LAYERS = [
    ('Yer', 'Zemin Toprak'), ('Yer', 'Zemin Çimen'), ('Yer', 'Leke'), ('Yer', 'Kum süsleri'), ('Yer', 'Filiz'),
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


## ---------------------------------------------------------------- tasarım (oyun alanı yerel hücre, 0..242)
SPAWN = (121, 214)
REGIONS = {
    'kervan': (121, 214),     ## doğuş: açık kum düzlüğü, kırık sütunlar
    'vaha': (121, 110),       ## Büyük Vaha: ortada göl, şelaleli ağaç, palmiye halkası
    'firavun': (196, 44),     ## KD: Firavun Vadisi (firavun kapısı, yüzlü sütunlar, kaya)
    'kure': (46, 46),         ## KB: Küre Tapınağı (mavi küre, kemer harabesi)
    'sutunlar': (122, 32),    ## K: rüzgârın oyduğu kaya sütunları
    'yilan': (204, 128),      ## D: Yılan Mezarlığı (dev kafatası, yılan iskeletleri)
    'olu_ova': (38, 136),     ## B: Ölü Ağaçlar Ovası
    'kaktus': (56, 204),      ## GB: Kaktüs Bahçesi (agav, fıçı kaktüs)
    'kayalik': (196, 202),    ## GD: Kayalık (mağaralı kaya, yeşil vaha)
}
CLEARINGS = {'kervan': 13, 'vaha': 0, 'firavun': 8, 'kure': 7, 'sutunlar': 4, 'yilan': 6, 'olu_ova': 4, 'kaktus': 4, 'kayalik': 5}
## Vahalar: (merkez x, y, yarıçap x, y, yeşil mi, ek loblar [(x, y, rx, ry)]). Yeşil = çimen kıyısı + çimen halkası + palmiye; değil = kum kıyılı
## su birikintisi (kuyu).
OASES = [
    (121, 108, 19, 11, True, [(103, 103, 8, 6), (139, 114, 9, 6), (128, 97, 7, 4), (111, 119, 7, 4), (136, 102, 6, 4)]),
    (150, 200, 5.5, 3.6, True, [(146, 203, 3, 2)]),
    (186, 182, 6.5, 4.2, True, [(192, 186, 4, 3)]),
    (28, 100, 6.0, 4.0, True, [(33, 97, 3, 2.5)]),
    (222, 74, 5.0, 3.6, True, []),
    (66, 70, 3.8, 2.6, False, []),
    (80, 210, 3.2, 2.3, False, []),
    (152, 52, 3.8, 2.7, False, []),
    (212, 146, 3.4, 2.4, False, []),
    (92, 162, 3.0, 2.2, False, []),
    (58, 154, 2.6, 2.0, False, []),
]
GRASS_RING = {0: 7.0}  ## vaha indeksi -> çimen halkası genişliği (köşe); varsayılan 3.5
BRUSH_COUNT = 10       ## saklanma çalılığı (kuru çayır yaması içinde)
## Kum tepeleri (tümsek kümeleri): (x, y, yarıçap)
DUNES = [(88, 186, 16), (172, 150, 14), (82, 62, 12), (160, 72, 12), (30, 186, 12), (214, 98, 10), (100, 232, 12), (236, 214, 8)]
## İç kaya kümeleri (yoğun kaya + sütun; aralarından geçilir): (x, y, yarıçap)
ROCK_CLUSTERS = [(180, 30, 6), (212, 36, 5), (106, 22, 5), (140, 26, 5), (34, 30, 5), (206, 208, 7), (178, 216, 5), (16, 164, 5),
                 (228, 168, 5), (64, 112, 4), (172, 120, 4), (84, 138, 3)]


## ---------------------------------------------------------------- gürültü + yardımcılar (Kara Bataklık üretecinden)
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
    """çoğunluk süzgeci (3x3): tek köşelik çentik / çıkıntılar gider, kıyı ve çimen kenarı yumuşar"""
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
        imgs[key] = np.array(Image.open(os.path.join(CDIR, TS_FILES[key])).convert('RGBA'))
    return imgs


def obj(key):
    return ATLAS['objects'][key]


## ---------------------------------------------------------------- harita durumu
class Map:
    def __init__(self, imgs):
        self.imgs = imgs
        self.layers = {name: {} for _, name in LAYERS}
        self.ne = {'nesne': nonempty_tiles(imgs['nesne']), 'kaktus': nonempty_tiles(imgs['kaktus'])}
        self.objects = []
        self.cover = {}       ## hücre -> [nesne indeksleri]
        self.base_cells = set()
        self.meta_lights = []
        self._stamps = {}

    def put(self, layer, cell, ts, coord, flip=False):
        x, y = cell
        if 0 <= x < W and 0 <= y < H:
            self.layers[layer][(x, y)] = (ts, coord, flip)

    ## Nesnenin karoları: dolu karolar + onları 4-komşu BAĞLAYAN saydam karolar (oyun nesneyi "atlasta komşu karo" zinciriyle tanır;
    ## arada boş karo kalırsa nesne parçalanır -> hayalet engel / yanlış derinlik). Kara Bataklık madde 524.
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

    ## kök (en alt satır) hücresi (cx, by); yatayda blok ortalı. Çevrilmişte hücre x'i aynalanır (atlas karosu aynı, Tiled bayrağı FH).
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


def build_terrain(m):
    VH, VW = H + 1, W + 1
    yy, xx = np.mgrid[0:VH, 0:VW]
    lx = xx - PX0
    ly = yy - PY0
    n1 = fbm((VH, VW), 18, SEED + 1)
    n2 = fbm((VH, VW), 8, SEED + 2)
    n3 = fbm((VH, VW), 30, SEED + 3)
    ## 1) SU: vaha başına (yeşil / kum) ayrı maske - kıyı türü buna göre
    oasis_id = np.full((VH, VW), -1, np.int32)
    wet_best = np.full((VH, VW), -1.0)
    for i, (cx, cy, rx, ry, lush, lobes) in enumerate(OASES):
        wet = 1.0 - ellipse_field(lx, ly, cx, cy, rx, ry, rng.uniform(-0.25, 0.25)) + (n1 - 0.5) * 0.42 + (n2 - 0.5) * 0.07
        for (ax, ay, arx, ary) in lobes:
            wet = np.maximum(wet, 1.0 - ellipse_field(lx, ly, ax, ay, arx, ary, rng.uniform(-0.6, 0.6)) + (n1 - 0.5) * 0.3 + (n2 - 0.5) * 0.08)
        better = wet > wet_best
        wet_best = np.where(better, wet, wet_best)
        oasis_id = np.where(better, i, oasis_id)
    water = wet_best > 0
    water = remove_small(water, 4, True)
    water = remove_small(water, 6, False)
    water = smooth_mask(water, 2)
    water = fix_diagonals(water, prefer=True)
    land = ~water
    ## vaha kimliği: suyun her köşesi en yakın vahaya (kıyı türü)
    lush_water = np.zeros_like(water)
    sand_water = np.zeros_like(water)
    for i, o in enumerate(OASES):
        msk = water & (oasis_id == i)
        if o[4]:
            lush_water |= msk
        else:
            sand_water |= msk
    ## 2) ÇİMEN: yeşil vahaların çevresinde halka (gürültülü dış kenar) + birkaç küçük bozkır yaması; kum havuzuna 2 köşeden yakın olmaz,
    ## yeşil vahanın suyuna 1 köşe yakın kara HEP çimen (kıyı hücresinin kara köşeleri tek türde).
    grass = np.zeros_like(water)
    m.lush_dist = np.full((VH, VW), 1e9)
    for i, (cx, cy, rx, ry, lush, lobes) in enumerate(OASES):
        if not lush:
            continue
        msk = water & (oasis_id == i)
        d = cheb_dist(msk, 16).astype(float)
        m.lush_dist = np.minimum(m.lush_dist, d)
        ring = GRASS_RING.get(i, 3.5)
        grass |= land & (d <= ring + (n1 - 0.5) * 5.0 + (n2 - 0.5) * 1.5)
    ## bozkır yamaları: yeşil vahaların hemen ötesinde birkaç yuvarlak çimen adacığı (köşeli leke gibi durmasın: elips + yumuşatma)
    for i, (cx, cy, rx, ry, lush, lobes) in enumerate(OASES):
        if not lush:
            continue
        for _ in range(3 if i == 0 else 1):
            a = rng.uniform(0, math.tau)
            dd = max(rx, ry) + GRASS_RING.get(i, 3.5) + rng.uniform(5, 9)
            px_, py_ = cx + math.cos(a) * dd, cy + math.sin(a) * dd * 0.8
            grass |= land & (ellipse_field(lx, ly, px_, py_, rng.uniform(2.2, 3.6), rng.uniform(1.6, 2.6), rng.uniform(0, 3)) +
                             (n2 - 0.5) * 0.5 < 1.0)
    ## KURU ÇAYIR (saklanma çalılığı yeri): yeşil vahaların ötesindeki bozkırda gürültülü elips çimen yamaları; çalılık bu yamanın İÇİNE
    ## konur (place_brush) - kumun ortasında düz kenarlı bir ot öbeği gibi durmasın, kenarını setin saçaklı çimeni sarsın.
    m.brush_sites = []
    sx_, sy_ = SPAWN
    for _ in range(4000):
        if len(m.brush_sites) >= BRUSH_COUNT:
            break
        bx, by_ = rng.uniform(16, PLAY - 16), rng.uniform(16, PLAY - 16)
        iy, ix = int(round(by_)) + PY0, int(round(bx)) + PX0
        if not (10 <= m.lush_dist[iy, ix] <= 26) or math.hypot(bx - sx_, by_ - sy_) < 24:
            continue
        if any(math.hypot(bx - REGIONS[k][0], by_ - REGIONS[k][1]) < CLEARINGS[k] + 9 for k in REGIONS if CLEARINGS[k] > 0):
            continue
        if any(math.hypot(bx - o[0], by_ - o[1]) < max(o[2], o[3]) + 10 for o in OASES if not o[4]):
            continue
        if any(math.hypot(bx - a, by_ - b) < 28 for a, b, _, _, _ in m.brush_sites):
            continue
        if any(math.hypot(bx - c[0], by_ - c[1]) < c[2] + 9 for c in ROCK_CLUSTERS):
            continue
        rx_, ry_, ang = rng.uniform(6.5, 8.0), rng.uniform(4.6, 5.6), rng.uniform(-0.5, 0.5)
        blob = land & (ellipse_field(lx, ly, bx, by_, rx_, ry_, ang) + (n2 - 0.5) * 0.45 + (n1 - 0.5) * 0.25 < 1.0)
        if blob.sum() < 120 or (blob & ~land).any():
            continue
        grass |= blob
        m.brush_sites.append((bx, by_, rx_, ry_, ang))
    grass = smooth_mask(grass, 1)
    near_sand_pool = cheb_dist(sand_water, 3) <= 2
    grass &= land & ~near_sand_pool
    grass = remove_small(grass, 14, True)
    grass = remove_small(grass, 8, False)
    grass = fix_diagonals(grass, prefer=False)
    near_lush = cheb_dist(lush_water, 2) <= 1
    grass |= land & near_lush
    grass = fix_diagonals(grass, prefer=True)
    grass &= land & ~near_sand_pool
    ## çapraz temizliği yeşil kıyıyı bozmasın: kıyıya 1 köşe yakın kara yine çimen
    grass |= land & near_lush
    m.v_water, m.v_land, m.v_grass = water, land, grass
    m.v_lush_water, m.v_sand_water = lush_water, sand_water
    m.n3 = n3


def paint_terrain(m):
    land, grass = m.v_land, m.v_grass
    bad = 0
    for y in range(H):
        for x in range(W):
            wc = corner_code(land, x, y)
            if wc != 15:
                m.put('Su', (x, y), *WATER_TILE)
                if wc != 0:
                    gc = corner_code(grass, x, y) & wc
                    if gc != 0 and gc != wc:
                        bad += 1
                    block = BLOCK_COAST_GRASS if gc == wc else BLOCK_COAST_SAND
                    m.put('Su ayrıntılar 2', (x, y), *block_tile(block, wc))
                continue
            m.put('Zemin Toprak', (x, y), *SAND_FILL)
            gc = corner_code(grass, x, y)
            if gc != 0:
                m.put('Zemin Çimen', (x, y), *block_tile(BLOCK_GRASS, gc))
    if bad:
        print('UYARI: karışık kıyı hücresi (kum + çimen köşesi):', bad)


## ---------------------------------------------------------------- hücre sınıfları
def cell_masks(m):
    land = m.v_land
    m.c_land = land[:-1, :-1] & land[:-1, 1:] & land[1:, :-1] & land[1:, 1:]
    w = m.v_water
    m.c_water = w[:-1, :-1] & w[:-1, 1:] & w[1:, :-1] & w[1:, 1:]
    g = m.v_grass
    m.c_grass = g[:-1, :-1] & g[:-1, 1:] & g[1:, :-1] & g[1:, 1:]       ## tam çimen
    m.c_grass_any = g[:-1, :-1] | g[:-1, 1:] | g[1:, :-1] | g[1:, 1:]
    m.c_sand = m.c_land & ~m.c_grass_any                                   ## tam kum
    m.c_wd = cheb_dist(~m.c_land, 10)                                      ## suya uzaklık (hücre)
    ld = m.lush_dist
    m.c_lush = np.minimum.reduce([ld[:-1, :-1], ld[:-1, 1:], ld[1:, :-1], ld[1:, 1:]])
    yy, xx = np.mgrid[0:H, 0:W]
    lx, ly = xx - PX0, yy - PY0
    m.c_edge = np.minimum.reduce([lx, ly, PLAY - 1 - lx, PLAY - 1 - ly])


def in_meadow(m, x, y, pad=0.0):
    lx, ly = x - PX0 + 0.5, y - PY0 + 0.5
    for (bx, by_, rx_, ry_, ang) in getattr(m, 'brush_sites', []):
        ca, sa = math.cos(ang), math.sin(ang)
        ux = (lx - bx) * ca + (ly - by_) * sa
        uy = -(lx - bx) * sa + (ly - by_) * ca
        if (ux / (rx_ + pad)) ** 2 + (uy / (ry_ + pad)) ** 2 < 1.0:
            return True
    return False


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


## ---------------------------------------------------------------- dış sınır (geçilmez kaya şeridi)
def build_band(m):
    cn = fbm((H, W), 10, SEED + 21)
    cn2 = fbm((H, W), 28, SEED + 23, 2)
    depth = 3.0 + cn * 4.0 + np.clip(cn2 - 0.42, 0, 1) * 16.0
    band = m.c_edge < depth
    ## doğuş ve bölge açıklıkları şeride değmesin (güneyde doğuş kenara yakın)
    yy, xx = np.mgrid[0:H, 0:W]
    lx, ly = xx - PX0, yy - PY0
    keep = np.zeros((H, W), bool)
    for k, (rxk, ryk) in REGIONS.items():
        if CLEARINGS[k] > 0:
            keep |= np.hypot(lx - rxk, ly - ryk) < CLEARINGS[k] + 3
    keep &= m.c_edge >= 2
    band &= ~keep
    band &= m.c_land | (m.c_edge < 0)
    m.forest = band
    for y in range(H):
        for x in range(W):
            if band[y, x]:
                m.put('Orman parçaları', (x, y), *BLOCKER_TILE)


## ---------------------------------------------------------------- nesne yerleşimi
ROCK_BIG = ['kaya_magara', 'kaya_buyuk', 'kaya_orta']
ROCK_SMALL = ['kaya_kucuk', 'kaya_orta']
HOODOO_S = ['sutun_1_s', 'sutun_2_s', 'sutun_3_s', 'mantar_kaya_1_s', 'mantar_kaya_3_s', 'tas_top_1_s']
HOODOO_G = ['sutun_4_g', 'sutun_5_g', 'mantar_kaya_2_g', 'mantar_kaya_4_g', 'tas_top_2_g']
FACE_HOODOO = ['yuz_sutun_1_s', 'yuz_sutun_2_s', 'yuz_sutun_3_s']
CACTI = ['kaktus_1', 'kaktus_2', 'kaktus_3', 'kaktus_4']
BARREL = ['fici_kaktus_1', 'fici_kaktus_2', 'fici_kaktus_3', 'fici_kaktus_4']
FLOWER_CACTI_S = ['cicekli_kaktus_1_s', 'cicekli_kaktus_2_s']
FLOWER_CACTI_G = ['cicekli_kaktus_1_g', 'cicekli_kaktus_2_g']
AGAVE_S = ['agav_1_s', 'agav_2_s', 'agav_3_s']
AGAVE_G = ['agav_1_g', 'agav_2_g', 'agav_3_g']
DEAD_BIG_S = ['olu_dev_%d_s' % i for i in range(1, 7)] + ['olu_kivrik_%d_s' % i for i in range(1, 7)]
DEAD_BIG_G = ['olu_dev_%d_g' % i for i in range(1, 7)] + ['olu_kivrik_%d_g' % i for i in range(1, 7)]
DEAD_SMALL_S = ['olu_agac_1_s', 'olu_agac_2_s', 'olu_agac_3_s', 'olu_dal_1_s', 'olu_dal_2_s', 'olu_fidan_1_s', 'olu_fidan_2_s', 'olu_fidan_3_s']
DEAD_SMALL_G = ['olu_agac_1_g', 'olu_agac_2_g', 'olu_agac_3_g', 'olu_dal_1_g', 'olu_dal_2_g', 'olu_fidan_1_g', 'olu_fidan_2_g', 'olu_fidan_3_g']
PALM_S = ['palmiye_1', 'palmiye_2', 'palmiye_k1', 'yuvarlak_1', 'yuvarlak_2', 'yuvarlak_k1']
PALM_G = ['palmiye_3', 'palmiye_b', 'palmiye_k2', 'yuvarlak_3', 'yuvarlak_b', 'yuvarlak_k2', 'cali_agac_1', 'cali_agac_2']
NO_FLIP = {'firavun_s', 'firavun_g', 'kure_s', 'kure_g', 'kemer', 'selale_agaci', 'yuz_sutun_1_s', 'yuz_sutun_2_s', 'yuz_sutun_3_s'}


def root_ok(m, key, cx, by, ground='land', avoid_forest=True, rows=2):
    """kök satırı (+ bir üstü) uygun zeminde: 'land' tam kara, 'sand' tam kum, 'grass' tam çimen, 'water' tam su"""
    o = obj(key)
    x0 = cx - o['wt'] // 2
    for tx in range(o['wt']):
        for yy in range(by - rows + 1, by + 1):
            x = x0 + tx
            if not (0 <= x < W and 0 <= yy < H):
                return False
            if ground == 'water':
                if not m.c_water[yy, x]:
                    return False
            elif not m.c_land[yy, x]:
                return False
            elif ground == 'sand' and m.c_grass_any[yy, x]:
                return False
            elif ground == 'grass' and not m.c_grass[yy, x]:
                return False
    if avoid_forest:
        for tx in range(o['wt']):
            if m.forest[by, x0 + tx] or m.forest[by - 1, x0 + tx]:
                return False
    ## kuru çayır yamaları saklanma çalılığına ayrılmış: içine nesne / ağaç kökü konmaz
    if in_meadow(m, cx, by, 1.0):
        return False
    ## tüm karolar haritada
    for (c, _) in m.obj_cells(key, cx, by):
        if not (0 <= c[0] < W and 0 <= c[1] < H):
            return False
    return True


def overlaps(m, key, cx, by, flip=False):
    """nesnenin bindiği önceki nesnelerin indeksleri"""
    s = set()
    for (c, _) in m.obj_cells(key, cx, by, flip):
        for oi in m.cover.get(c, []):
            s.add(oi)
    return s


def obj_layer_for(m, key, cx, by, flip=False, cover_bases=False):
    """y-sıralı nesne katmanı: bindiği nesnelerin hepsi kuzeyde (kökü yukarıda) olmalı ve hiçbiri ağaç/bitki olmamalı; katman = en üsttekinin
    bir üstü. Kökü aynı ya da güneyde olan bir nesneyle binerse None (çizim sırası bozulur). Taban (alt 2 satır) başka nesneye girmez."""
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
    """cover_bases: kuzeydeki nesnenin tabanını örtebilir (yalnız geçilmez şeritte: orada kimse durmaz, sık kaya yığını için)"""
    if flip is None:
        flip = key not in NO_FLIP and rng.random() < 0.5
    L = obj_layer_for(m, key, cx, by, flip, cover_bases)
    if L is None:
        return None
    ## Aynı katmanda kökü AYNI satırda olan ve yan yana (yatay komşu hücre) duran iki nesneyi oyun tek nesne sayar (terrain_collision
    ## object_groups: aynı kök + bitişik hücre birleşir) -> küçüğün ayak izi büyüğünün boyuyla uzar. Böyle komşu varsa bir üst katman.
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
            return m.place(key, cx, by, lname, kind, flip)
    return None


def place_landmarks(m):
    plan = {
        'firavun': [('firavun_s', 0, -1), ('yuz_sutun_1_s', -6, 0), ('yuz_sutun_1_s', 6, 0), ('kaya_buyuk', -12, -4), ('kaya_orta', 11, -5),
                    ('yuz_sutun_3_s', -9, 5), ('yuz_sutun_3_s', 9, 5), ('kemer', 13, 4), ('sutun_2_s', -14, 3), ('mantar_kaya_1_s', 15, -1)],
        'kure': [('kure_s', 0, -1), ('kemer', -7, -3), ('kaya_orta', 7, -4), ('yuz_sutun_2_s', -6, 4), ('yuz_sutun_2_s', 6, 4),
                 ('kaktus_3', 9, 2), ('kaktus_4', -10, 1), ('tas_top_1_s', 3, 6)],
        'yilan': [('dev_kafatasi_s', 0, -2), ('kafatasi_o_s', -7, 3), ('kafatasi_k_s', 6, 4), ('kafatasi_k_s', -3, 7)],
        'sutunlar': [('yuz_sutun_1_s', 0, 0), ('sutun_1_s', -5, -2), ('sutun_1_s', 5, -3), ('sutun_2_s', -3, 4), ('sutun_3_s', 4, 4)],
        'kayalik': [('kaya_magara', 0, -2), ('kaya_buyuk', -7, 1), ('sutun_1_s', 6, 1), ('mantar_kaya_1_s', -4, 5)],
        'kervan': [('kaya_kucuk', -9, -6), ('tas_top_1_s', 10, -5)],
        'kaktus': [('kaktus_3', 0, 0), ('kaktus_4', -3, 2), ('kaktus_1', 3, 2), ('agav_1_s', -5, -2), ('agav_2_s', 5, -2), ('fici_kaktus_1', 0, 4),
                   ('fici_kaktus_2', -6, 4), ('fici_kaktus_3', 6, 5)],
        'olu_ova': [],
        'vaha': [],
    }
    for reg, items in plan.items():
        rx_, ry_ = REGIONS[reg]
        for key, dx, dy in items:
            cx, by = P(rx_ + dx, ry_ + dy)
            ok = False
            for attempt in range(40):
                jx = 0 if attempt == 0 else rng.randint(-2, 2)
                jy = 0 if attempt == 0 else rng.randint(-2, 2)
                if not root_ok(m, key, cx + jx, by + jy, 'sand') or near_spawn(cx + jx, by + jy, 5):
                    continue
                if place_obj(m, key, cx + jx, by + jy, 'nesne', flip=(key not in NO_FLIP and dx > 0)) is not None:
                    if key.startswith('kure'):
                        o = obj(key)
                        m.meta_lights.append(('kure', cx + jx, by + jy))
                    ok = True
                    break
            if not ok:
                print('  yer işareti sığmadı:', reg, key)
    ## Büyük Vaha: şelaleli ağaç göl içinde, kuzey kıyıya yakın (gövde suda)
    cx0, cy0 = OASES[0][0], OASES[0][1]
    placed = False
    for dy in range(-12, 4):
        for dx in sorted(range(-10, 11), key=abs):
            cx, by = P(cx0 + dx, cy0 + dy)
            if root_ok(m, 'selale_agaci', cx, by, 'water', avoid_forest=False, rows=2) and m.c_water[by + 1, cx]:
                ## tacı (üst satırlar) kuzey kıyıya taşar - ama kökün güneyi su olmalı (önünde kimse durmasın)
                if place_obj(m, 'selale_agaci', cx, by, 'nesne', flip=False) is not None:
                    placed = True
                    break
        if placed:
            break
    if not placed:
        print('  şelaleli ağaç sığmadı')


def scatter(m, count, keys_fn, cond, kind='nesne', tries=20000, spacing=3, ground='sand'):
    """koşulu sağlayan rastgele hücrelere nesne serpiştir; nesneler arası en az spacing hücre boşluk"""
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
        g = ground(key) if callable(ground) else ground
        if not root_ok(m, key, x, y, g):
            continue
        cells = m.obj_cells(key, x, y)
        bad = False
        for (c, _) in cells:
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


def place_band_rocks(m):
    """geçilmez şerit + dış çerçeve: ÖNCE iç kenara (oyuncunun gördüğü sınır) birbirine binen büyük kayalardan bir duvar, SONRA şeridin geri
    kalanı büyük kaya ağırlıklı sık kaya alanı (kaya sütunu az, küçük taş çok az). Y-sıralı, üst üste binebilir (4 nesne katmanı)."""
    n = 0
    roots = set()

    def free(x, y, sp):
        return not any((x + dx, y + dy) in roots for dx in range(-sp, sp + 1) for dy in range(-1, 2))

    ## 1) iç kenar duvarı: oyun alanına komşu şerit hücreleri (kenar çizgisi boyunca, gürültülü sırayla)
    inner = m.forest & ~np.roll(m.forest, 1, 0) | m.forest & ~np.roll(m.forest, -1, 0) | m.forest & ~np.roll(m.forest, 1, 1) |         m.forest & ~np.roll(m.forest, -1, 1)
    ys, xs = np.nonzero(inner)
    order = [(x, y) for x, y in zip(xs.tolist(), ys.tolist()) if in_play(x, y, -2)]
    rng.shuffle(order)
    for (x, y) in order:
        if not free(x, y, 2):
            continue
        key = rng.choice(['kaya_magara', 'kaya_buyuk', 'kaya_buyuk', 'kaya_orta', 'kaya_orta'])
        ## kök şeridin içinde (oyun alanı tarafına taşmasın): kökü 1-2 hücre içeri al
        for dy in (0, -1, 1):
            yy = y + dy
            if 0 <= yy < H and m.forest[yy, x] and root_ok(m, key, x, yy, 'land', avoid_forest=False, rows=1) and                     place_obj(m, key, x, yy, 'nesne', cover_bases=True) is not None:
                roots.add((x, yy))
                n += 1
                break
    ## 2) şeridin geri kalanı
    ys, xs = np.nonzero(m.forest)
    order = list(zip(xs.tolist(), ys.tolist()))
    rng.shuffle(order)
    for (x, y) in order[:YOGUNLUK['serit_deneme']]:
        if not free(x, y, YOGUNLUK['serit_aralik']):
            continue
        r = rng.random()
        if r < 0.72:
            key = rng.choice(ROCK_BIG)
        elif r < 0.92:
            key = rng.choice(['sutun_1_s', 'sutun_2_s', 'sutun_3_s', 'mantar_kaya_1_s'])
        else:
            key = 'kaya_kucuk'
        if not root_ok(m, key, x, y, 'land', avoid_forest=False, rows=1):
            continue
        if place_obj(m, key, x, y, 'nesne', cover_bases=True) is not None:
            roots.add((x, y))
            n += 1
    return n


def place_rock_clusters(m):
    n = 0
    for (cx_, cy_, r) in ROCK_CLUSTERS:
        for _ in range(int(r * r * 2.2)):
            a = rng.uniform(0, math.tau)
            d = math.sqrt(rng.random()) * r
            x, y = P(int(round(cx_ + math.cos(a) * d)), int(round(cy_ + math.sin(a) * d * 0.8)))
            if near_spawn(x, y, 14) or in_clearing(x, y, 1):
                continue
            rr = rng.random()
            key = rng.choice(ROCK_BIG) if rr < 0.45 else (rng.choice(HOODOO_S) if rr < 0.8 else rng.choice(ROCK_SMALL))
            if root_ok(m, key, x, y, 'sand') and place_obj(m, key, x, y) is not None:
                n += 1
    return n


def place_region_clusters(m):
    """bölgeye özgü yoğun kümeler: kaya sütunu tarlası (K), kaktüs bahçesi (GB), kayalık (GD), firavun vadisi sütunları (KD)"""
    plan = [('sutunlar', 17, 34, lambda: rng.choice(HOODOO_S * 3 + ['mantar_kaya_1_s', 'mantar_kaya_3_s', 'kaya_orta'])),
            ('kaktus', 15, 40, lambda: rng.choice(CACTI * 2 + BARREL * 2 + AGAVE_S + FLOWER_CACTI_S)),
            ('kayalik', 14, 22, lambda: rng.choice(ROCK_BIG + HOODOO_S + ['kaya_kucuk'])),
            ('firavun', 18, 14, lambda: rng.choice(HOODOO_S + ['kaya_orta', 'kaya_kucuk'])),
            ('kure', 15, 10, lambda: rng.choice(CACTI + ['kaya_orta', 'kaya_kucuk', 'sutun_3_s']))]
    out = {}
    for reg, r, count, pick in plan:
        rx0, ry0 = REGIONS[reg]
        n = 0
        for _ in range(count * 30):
            if n >= count:
                break
            a = rng.uniform(0, math.tau)
            d = CLEARINGS[reg] + 1 + math.sqrt(rng.random()) * (r - CLEARINGS[reg])
            x, y = P(int(round(rx0 + math.cos(a) * d)), int(round(ry0 + math.sin(a) * d * 0.8)))
            if not (0 <= x < W and 0 <= y < H) or m.forest[y, x] or near_spawn(x, y, 14):
                continue
            key = pick()
            if not root_ok(m, key, x, y, 'sand'):
                continue
            ## en az 2 hücre boşluk (taban satırları)
            if any((c[0] + dx, c[1] + dy) in m.cover for (c, _) in m.obj_cells(key, x, y) if c[1] >= y - 1
                   for dx in (-2, -1, 0, 1, 2) for dy in (0, 1)):
                continue
            if place_obj(m, key, x, y) is not None:
                n += 1
        out[reg] = n
    return out


def place_scatter(m):
    out = {}

    def sand_far(x, y):
        return m.c_sand[y, x] and not m.forest[y, x] and m.c_wd[y, x] >= 3 and not near_spawn(x, y, 12) and not in_clearing(x, y)

    ## kaya + kaya sütunu (kuzey ve doğu bölgelerinde daha sık)
    def rock_key(x, y):
        reg = nearest_region(x, y)
        boost = reg in ('sutunlar', 'firavun', 'kayalik', 'kure')
        if not boost and rng.random() < 0.45:
            return None
        r = rng.random()
        if r < 0.5:
            return rng.choice(HOODOO_S)
        if r < 0.8:
            return rng.choice(ROCK_SMALL)
        return rng.choice(ROCK_BIG)
    out['kaya'] = scatter(m, YOGUNLUK['kaya'], rock_key, sand_far, spacing=4)

    ## kaktüs: kaktüs bahçesinde sık, başka yerde seyrek; vahaya yakın çiçekli
    def cactus_key(x, y):
        reg = nearest_region(x, y)
        lx, ly = x - PX0, y - PY0
        kx, ky = REGIONS['kaktus']
        if math.hypot(lx - kx, ly - ky) > 26 and rng.random() < 0.55:
            return None
        if m.c_lush[y, x] < 16 and rng.random() < 0.5:
            return rng.choice(FLOWER_CACTI_S)
        r = rng.random()
        if r < 0.45:
            return rng.choice(CACTI)
        if r < 0.75:
            return rng.choice(BARREL)
        return rng.choice(AGAVE_S)
    out['kaktus'] = scatter(m, YOGUNLUK['kaktus'], cactus_key, sand_far, spacing=3)
    ## çimende: çalı + çimen çeşidi agav / çiçekli kaktüs / kısa sütun
    out['cimen'] = scatter(m, 40, lambda x, y: rng.choice(['cali_1', 'cali_1'] + AGAVE_G + FLOWER_CACTI_G + HOODOO_G[:2]),
                           lambda x, y: m.c_grass[y, x] and m.c_wd[y, x] >= 2 and not m.forest[y, x], spacing=3, ground='grass')
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


def collect_trees(m):
    trees = []
    trunk = {}

    def free(cx, by, r):
        return not any((cx + dx, by + dy) in trunk for dx in range(-r, r + 1) for dy in range(-r, r + 1))

    def add(key, cx, by, flip):
        trees.append((key, cx, by, flip))
        trunk[(cx, by)] = True

    def try_add(key, x, y, ground, r):
        flip = key not in NO_FLIP and rng.random() < 0.5
        if not free(x, y, r) or not root_ok(m, key, x, y, ground) or not south_of_objects(m, key, x, y, flip):
            return False
        add(key, x, y, flip)
        return True

    ## 1) yeşil vaha halkası: kıyıya yakın palmiyeler / yuvarlak ağaçlar (çimen çeşidi), halkanın dışında kum çeşidi
    cand = [(rng.random(), x, y) for y in range(PY0, PY0 + PLAY) for x in range(PX0, PX0 + PLAY)
            if m.c_land[y, x] and 1 <= m.c_wd[y, x] <= 5 and m.c_lush[y, x] <= 9 and not m.forest[y, x]]
    cand.sort()
    for _, x, y in cand:
        if near_spawn(x, y, 10):
            continue
        if m.c_grass[y, x]:
            key = rng.choice(PALM_G)
            try_add(key, x, y, 'grass', YOGUNLUK['palmiye_aralik'])
        elif m.c_sand[y, x] and rng.random() < 0.5:
            try_add(rng.choice(PALM_S), x, y, 'sand', YOGUNLUK['palmiye_aralik'] + 1)
    ## kum havuzlarının yanında 1-2 kum palmiyesi
    for (cx_, cy_, rx_, ry_, lush, _) in OASES:
        if lush:
            continue
        k = 0
        for _ in range(60):
            a = rng.uniform(0, math.tau)
            x, y = P(int(round(cx_ + math.cos(a) * (rx_ + 2.5))), int(round(cy_ + math.sin(a) * (ry_ + 2.0))))
            if try_add(rng.choice(PALM_S), x, y, 'sand', 3):
                k += 1
                if k >= 2:
                    break
    ## 2) Ölü Ağaçlar Ovası: kümeler
    ox, oy = REGIONS['olu_ova']
    for _ in range(500):
        a = rng.uniform(0, math.tau)
        d = math.sqrt(rng.random()) * 24
        x, y = P(int(round(ox + math.cos(a) * d)), int(round(oy + math.sin(a) * d * 0.9)))
        if in_clearing(x, y) or m.forest[y, x]:
            continue
        g = 'grass' if m.c_grass[y, x] else 'sand'
        key = rng.choice((DEAD_BIG_G + DEAD_SMALL_G) if g == 'grass' else (DEAD_BIG_S * 2 + DEAD_SMALL_S))
        try_add(key, x, y, g, YOGUNLUK['olu_agac_aralik'] if key in DEAD_BIG_S + DEAD_BIG_G else 4)
    ## 3) yılan mezarlığı + kayalık çevresi: seyrek ölü ağaç
    for reg in ('yilan', 'kayalik', 'firavun'):
        rx0, ry0 = REGIONS[reg]
        for _ in range(60):
            x, y = P(rx0 + rng.randint(-16, 16), ry0 + rng.randint(-12, 12))
            if in_clearing(x, y) or not (0 <= x < W and 0 <= y < H) or m.forest[y, x]:
                continue
            try_add(rng.choice(DEAD_SMALL_S + DEAD_BIG_S[:3]), x, y, 'sand', 6)
    ## 4) kumda tek tük
    singles = 0
    cand = [(rng.random(), x, y) for y in range(PY0, PY0 + PLAY) for x in range(PX0, PX0 + PLAY)
            if m.c_sand[y, x] and not m.forest[y, x] and m.c_wd[y, x] >= 4]
    cand.sort()
    for _, x, y in cand:
        if singles >= YOGUNLUK['tek_agac']:
            break
        if near_spawn(x, y, 12) or in_clearing(x, y):
            continue
        key = rng.choice(DEAD_SMALL_S) if rng.random() < 0.75 else rng.choice(DEAD_BIG_S)
        if try_add(key, x, y, 'sand', 12):
            singles += 1
    ## 5) şerit + dış çerçeve: kayaların arasına ölü ağaç (gövde kaya tabanına girmez)
    ys, xs = np.nonzero(m.forest)
    order = list(zip(xs.tolist(), ys.tolist()))
    rng.shuffle(order)
    band_n = 0
    for (x, y) in order[:9000]:
        if rng.random() < 0.85:
            continue
        key = rng.choice(DEAD_BIG_S + DEAD_SMALL_S)
        flip = rng.random() < 0.5
        if not free(x, y, 5) or not root_ok(m, key, x, y, 'land', avoid_forest=False, rows=1) or not south_of_objects(m, key, x, y, flip):
            continue
        add(key, x, y, flip)
        band_n += 1
    return trees


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


DETAIL = {k for k in ATLAS['objects'] if k.startswith('d_')}
DRY_GRASS = sorted(k for k in DETAIL if k.startswith('d_kuru_ot'))
GREEN_S = sorted(k for k in DETAIL if k.startswith('d_ot_s'))
GREEN_G = sorted(k for k in DETAIL if k.startswith('d_ot_g'))
FLOWERS = sorted(k for k in DETAIL if k.startswith('d_cicek'))
MOUNDS = sorted(k for k in DETAIL if k.startswith('d_tumsek'))
BONES_S = sorted(k for k in DETAIL if k.startswith('d_kemik_') and not k.startswith('d_kemik_g')) + \
    sorted(k for k in ATLAS['objects'] if k.startswith('kemik_parca') and k.endswith('_s'))
BONES_G = sorted(k for k in DETAIL if k.startswith('d_kemik_g')) + sorted(k for k in ATLAS['objects'] if k.startswith('kemik_parca') and k.endswith('_g'))
MINI_CACTI = ['mini_kaktus_1', 'mini_kaktus_2', 'mini_kaktus_3', 'mini_kaktus_4', 'cicekli_kaktus_3_s']
SPROUTS = ['filiz_1', 'filiz_2', 'filiz_3']


def place_flat(m, key, x, y, need):
    """yere serili süs ('Kum süsleri'): tüm karoları istenen zeminde, katmanda boş, nesne tabanına değmiyor"""
    flip = rng.random() < 0.5
    cells = m.obj_cells(key, x, y, flip)
    for (c, _) in cells:
        if not (0 <= c[0] < W and 0 <= c[1] < H) or c in m.layers['Kum süsleri'] or c in m.layers['Saklanma Çalılığı']:
            return False
        if need == 'sand' and not m.c_sand[c[1], c[0]]:
            return False
        if need == 'grass' and not m.c_grass[c[1], c[0]]:
            return False
        if need == 'land' and not m.c_land[c[1], c[0]]:
            return False
        if c in m.base_cells:
            return False
    m.place(key, x, y, 'Kum süsleri', 'yassi', flip)
    return True


def place_ground_decor(m):
    n = {'tumsek': 0, 'kemik': 0, 'iskelet': 0, 'sutun_dibi': 0}
    ## kum tepeleri: tümsek kümeleri
    for _ in range(YOGUNLUK['tumsek']):
        if rng.random() < 0.7:
            dx_, dy_, r = rng.choice(DUNES)
            a = rng.uniform(0, math.tau)
            d = math.sqrt(rng.random()) * r
            x, y = P(int(round(dx_ + math.cos(a) * d)), int(round(dy_ + math.sin(a) * d * 0.7)))
        else:
            x, y = rng.randint(0, W - 1), rng.randint(0, H - 1)
        if not (0 <= x < W and 0 <= y < H) or near_spawn(x, y, 6):
            continue
        n['tumsek'] += place_flat(m, rng.choice(MOUNDS), x, y, 'sand')
    ## yılan mezarlığı: iskeletler + kemikler
    yx, yy_ = REGIONS['yilan']
    for key in ['yilan_1_s', 'yilan_2_s', 'yilan_2_s', 'yilan_1_s']:
        for _ in range(80):
            x, y = P(yx + rng.randint(-15, 15), yy_ + rng.randint(-11, 11))
            if place_flat(m, key, x, y, 'sand'):
                n['iskelet'] += 1
                break
    for _ in range(120):
        x, y = P(yx + rng.randint(-20, 20), yy_ + rng.randint(-15, 15))
        n['kemik'] += place_flat(m, rng.choice(BONES_S), x, y, 'sand')
    ## başka yerlerde seyrek kemik + bir iki iskelet, doğuşta kırık sütun dipleri
    for _ in range(260):
        x, y = rng.randint(PX0, PX0 + PLAY - 1), rng.randint(PY0, PY0 + PLAY - 1)
        if m.c_grass[y, x]:
            if rng.random() < 0.3:
                n['kemik'] += place_flat(m, rng.choice(BONES_G), x, y, 'grass')
        elif rng.random() < 0.25:
            n['kemik'] += place_flat(m, rng.choice(BONES_S), x, y, 'sand')
    for key in ['yilan_1_s', 'yilan_2_s']:
        for _ in range(200):
            x, y = rng.randint(PX0 + 10, PX0 + PLAY - 10), rng.randint(PY0 + 10, PY0 + PLAY - 10)
            if not in_clearing(x, y, 4) and place_flat(m, key, x, y, 'sand'):
                n['iskelet'] += 1
                break
    sx, sy = REGIONS['kervan']
    for key in ['kirik_sutun_3', 'kirik_sutun_3']:
        for _ in range(60):
            x, y = P(sx + rng.randint(-12, 12), sy + rng.randint(-9, 9))
            if not near_spawn(x, y, 4) and place_flat(m, key, x, y, 'sand'):
                n['sutun_dibi'] += 1
                break
    for key in ['kirik_sutun_1', 'kirik_sutun_2', 'kirik_sutun_4']:
        for _ in range(200):
            x, y = rng.randint(PX0, PX0 + PLAY - 1), rng.randint(PY0, PY0 + PLAY - 1)
            if place_flat(m, key, x, y, 'grass'):
                n['sutun_dibi'] += 1
                break
    return n


def place_spots(m, imgs):
    """bozkır lekeleri (setin çimen lekeleri, c_leke): vaha çevresinin kum hücrelerinde, çimen halkasına doğru sıklaşır; tek karoluk kapalı lekeler"""
    img = imgs['leke']
    comps = []
    for r in range(img.shape[0] // T):
        for c in range(img.shape[1] // T):
            a = img[r * T:(r + 1) * T, c * T:(c + 1) * T, 3] > 0
            if a.sum() >= 6 and not (a[0].any() or a[-1].any() or a[:, 0].any() or a[:, -1].any()):
                comps.append((c, r))
    n = 0
    for _ in range(YOGUNLUK['leke'] * 4):
        x, y = rng.randint(0, W - 1), rng.randint(0, H - 1)
        if not m.c_sand[y, x] or (x, y) in m.layers['Leke']:
            continue
        ld = m.c_lush[y, x]
        p = 0.9 if ld < 10 else (0.35 if ld < 18 else 0.03)
        if rng.random() > p:
            continue
        m.put('Leke', (x, y), 'leke', rng.choice(comps))
        n += 1
        if n >= YOGUNLUK['leke']:
            break
    return n


def place_plants(m):
    used = set()

    def try_plant(key, x, y, flower=False):
        cells = [c for c, _ in m.obj_cells(key, x, y)]
        for c in cells:
            if not (0 <= c[0] < W and 0 <= c[1] < H) or c in used or not m.c_land[c[1], c[0]]:
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

    fil = imgs_filiz_tiles(m)
    n = {'ot': 0, 'cicek': 0, 'filiz': 0}
    pn = fbm((H, W), 7, SEED + 51)
    for y in range(H):
        for x in range(W):
            if not m.c_land[y, x] or m.layers['Saklanma Çalılığı'].get((x, y)):
                continue
            r = rng.random()
            ld = m.c_lush[y, x]
            if m.c_grass[y, x]:
                if r < YOGUNLUK['cimen_ot'] * (0.5 + pn[y, x]):
                    n['ot'] += try_plant(rng.choice(GREEN_G), x, y)
                elif r < YOGUNLUK['cimen_ot'] + YOGUNLUK['cicek'] and m.c_wd[y, x] <= 6:
                    n['cicek'] += try_plant(rng.choice(FLOWERS), x, y, flower=True)
                continue
            if not m.c_sand[y, x]:
                continue
            if m.forest[y, x]:
                if r < 0.02:
                    n['ot'] += try_plant(rng.choice(DRY_GRASS), x, y)
                continue
            bozkir = ld < 18
            p = YOGUNLUK['bozkir_ot'] if bozkir else YOGUNLUK['kuru_ot'] * (0.4 + pn[y, x] * 1.2)
            if r < p:
                key = rng.choice(GREEN_S) if (bozkir and rng.random() < 0.45) else rng.choice(DRY_GRASS)
                if rng.random() < 0.06:
                    key = rng.choice(MINI_CACTI)
                if bozkir and rng.random() < 0.08:
                    key = rng.choice(SPROUTS)
                n['ot'] += try_plant(key, x, y)
            elif bozkir and r < p + YOGUNLUK['filiz'] and (x, y) not in m.layers['Filiz'] and (x, y) not in m.cover:
                m.put('Filiz', (x, y), 'filiz', rng.choice(fil))
                n['filiz'] += 1
    return n


def imgs_filiz_tiles(m):
    a = m.imgs['filiz']
    out = []
    for r in range(2):
        for c in range(a.shape[1] // T):
            if a[r * T:(r + 1) * T, c * T:(c + 1) * T, 3].any():
                out.append((c, r))
    return out


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
        ok = all(0 <= cx < W and 0 <= cy < H and deep[cy, cx] and (cx, cy) not in used and (cx, cy) not in m.cover for cx, cy in cells)
        if not ok:
            continue
        for (c, r), (cx, cy) in zip(comp, cells):
            m.put('Su süsleri', (cx, cy), 'su', (c, r))
            used.add((cx, cy))
        n += 1
    return n


def place_brush(m):
    """saklanma çalılığı (KURU UZUN OT, atlas satır 0-3): her kuru çayır yamasının (build_terrain m.brush_sites) içinde, yamanın çimeninden
    1,5-2 hücre içeride - kenarını saçaklı çimen sarar. Nesne tabanına / suya / şeride değmez."""
    L = 'Saklanma Çalılığı'
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
                if (ux / (rx_ - 1.8)) ** 2 + (uy / (ry_ - 1.4)) ** 2 >= 1.0:
                    continue
                if not (0 <= x < W and 0 <= y < H) or not m.c_grass[y, x] or m.forest[y, x] or m.c_wd[y, x] < 2:
                    continue
                if (x, y) in m.base_cells:
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
            mask = (0 if (c[0], c[1] - 1) in cs else 1) | (0 if (c[0], c[1] + 1) in cs else 2) |                    (0 if (c[0] - 1, c[1]) in cs else 4) | (0 if (c[0] + 1, c[1]) in cs else 8)
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
    """terrain_collision.gd is_solid_prop taklidi; c_kaktus.png yeşil olsa da katı (SOLID_EVEN_IF_GREEN_TEXTURES)"""
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
    if ok and o['ts'] != 'kaktus':
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


WATER_COLOR = np.array([62, 142, 150], np.uint8)


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
            dst[..., :3] = (t[..., :3] * a + dst[..., :3] * (1 - a)).astype(np.uint8)
    img = Image.fromarray(canvas, 'RGBA')
    if path:
        img.save(path)
    return img


def write_meta(m, path):
    sx, sy = P(*SPAWN)
    lines = ['extends RefCounted', '',
             '## ALTIN KUMLAR (çöl) haritasının çalışma anı verisi - tools/col/gen_col.py --write ÜRETİR (elle düzenleme; üreteç ezer).',
             '## Koordinatlar dünya pikseli (Harita (0,0)\'da). Oyun alanı hücre Rect2i(%d, %d, %d, %d).' % (PX0, PY0, PLAY, PLAY), '',
             'const PLAY_CELLS := Rect2i(%d, %d, %d, %d)' % (PX0, PY0, PLAY, PLAY),
             'const SPAWN := Vector2(%d, %d)' % (sx * T + 8, sy * T + 8),
             '## Gece ışıkları: [tür, dünya konumu] (küre tapınağının mavi küresi)']
    lines.append('const LIGHTS := [')
    for kind, cx, by in m.meta_lights:
        o = obj('kure_s')
        x = (cx - o['wt'] // 2) * T + o['ox'] + o['w'] / 2.0
        top = (by + 1) * T - o['h']
        lines.append('\t["%s", Vector2(%.1f, %.1f)],' % (kind, x, top + 12.0))
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
    place_landmarks(m)
    nband = place_band_rocks(m)
    nclus = place_rock_clusters(m)
    nreg = place_region_clusters(m)
    nscat = place_scatter(m)
    trees = collect_trees(m)
    placed, skipped = assign_tree_layers(m, trees)
    nbrush = place_brush(m)
    ndec = place_ground_decor(m)
    nspots = place_spots(m, imgs)
    nplants = place_plants(m)
    nwater = place_water_decor(m, imgs)
    blocked, reach, npocket, cat = seal_pockets(m, imgs)
    play = blocked[PY0:PY0 + PLAY, PX0:PX0 + PLAY]
    rplay = reach[PY0:PY0 + PLAY, PX0:PX0 + PLAY]
    nobj = sum(1 for o in m.objects if o['layer'] in OBJ_LAYERS)
    print('şerit kaya: %d  küme kaya: %d  bölge kümeleri: %s  serpiştirme: %s  y-sıralı nesne toplam: %d' % (nband, nclus, nreg, nscat, nobj))
    print('ağaç: %d (sığmayan %d)  yer süsü: %s  çalılık: %d  leke: %d  bitki: %s  su süsü: %d' % (
        placed, skipped, ndec, nbrush, nspots, nplants, nwater))
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
                print('DURDU: harita/col.tmx son yazımdan sonra değişmiş (Tiled?) - elle düzenlemeleri korumak için yazılmadı. '
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
