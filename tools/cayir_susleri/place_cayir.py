# -*- coding: utf-8 -*-
"""BAŞLANGIÇ ÇAYIRI SÜSLERİ (madde 383). Kullanıcı: "başlangıç çayırı çok boş duruyor, iyi bir atmosfer katacak ayrıntılar ekler misin (evden
çıkınca büyük açık alan, haritanın orta kısımları); çok yol kapatmasın, sadece boş gözüksün istemiyorum; aynı değişiklikleri Harita.tmx'e de uygula".

Ne yapar: canlı harita/Harita.tmx'in orta bölgesine (REGION) haritanın KENDİ tileset'lerinden küçük sahneler (babaannenin bostanı + korkuluk,
odun kesme kütüğü, kuyu, terk edilmiş avcı kampı, devrik ağaç köşesi, taş öbekleri, peri halkası, birkaç yalnız ağaç), renk temalı kır çiçeği
öbekleri ve yol kenarı / nesne dibi sallanan ot öbekleri ekler. Yalnız EKLEME (tek istisna: tarla toprağının altındaki "Çimler" mini otu silinir).

Kurallar (madde 47 v2 ile aynı ruh): yeni karo hiçbir süs katmanında dolu bir hücreyi paylaşmaz; yol (çimen olmayan) + duvar/su/köprü/ev/
saklanma çalılığı üstüne konmaz; KATI nesneler (kaya, kütük, kuyu, ağaç...) yoldan ve duvardan en az SOLID_PATH_GAP / SOLID_WALL_GAP hücre uzakta,
çevrelerinde SOLID_RING hücre başka katı engel yok (geçit daralmaz); sallanan katmanda yeni nesneler arasında 1 hücre boşluk (grup birleşmesin).

Kullanım (proje kökünden):
  python -I tools/cayir_susleri/place_cayir.py                 -> kuru çalışma: rapor + out/once.png, out/sonra.png, out/yakin_*.png + şu anki md5
  python -I tools/cayir_susleri/place_cayir.py --apply <md5>   -> Harita.tmx'e yazar (md5 kapısı: Tiled'dan kaydedilmişse DURUR), ilk yazımda yedek
Tekrar koşma ÜSTÜNE YIĞAR (yeni süsler tekrar eklenir): geri almak için yedeği (YEDEK) Harita.tmx üzerine kopyala.
"""
import hashlib
import math
import os
import random
import shutil
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cayir_core as K  # noqa: E402

OUT = os.path.join(K.HERE, 'out')
YEDEK = os.path.join(K.HARITA, 'yedek', 'Harita_2026-10-24_oncesi_cayir-susleri.tmx.bak')
SEED = 381
REGION = (86, 62, 197, 177)          ## x0, y0, x1, y1 (hücre, x1/y1 hariç) - evin çevresi + nehrin iki yakası + güneydoğu büyük çayır
FULL_GRASS = 135                     ## Zemin Çimen tam çimen karosu (gid)
SOLID_PATH_GAP = 3
SOLID_WALL_GAP = 3
SOLID_RING = 2
SOFT_PATH_GAP = 1                    ## çiçek/ot: yolun kendisine değil, kenarına kadar

L_FLOWER = 'Çiçekler 1'              ## sallanır, y-sıralı, dokununca eğilir
L_TUFT = 'Çalılar'                   ## sallanan ot öbekleri (exterior.tsx filizleri)
L_BUSH = 'Çalılar1'
L_PROP = 'Animasyonsuz çalılar'      ## y-sıralı nesne, büyük + dolu + yeşil olmayan nesne terrain_collision "props" kuralıyla ENGEL
L_TREE = 'Ağaç 0'                    ## sallanır + gövde engeli + derinlik + gölge
L_GROUND = 'Çimler'                  ## zemin ayrıntısı (tarla toprağı)
SWAY_LAYERS = (L_FLOWER, L_TUFT, L_BUSH)

DECOR_LAYERS = ['Çiçekler 1', 'Çalılar', 'Çalılar1', 'Animasyonsuz çalılar', 'Derin orman süsleri', 'Derin orman çukurları', 'Ağaç 0', 'Ağaç 1',
                'Ağaç 2', 'Ağaç ölü', 'Derin orman nesneleri', 'Saklanma Çalılığı', 'orman parçaları -1', 'Orman parçaları 3', 'Orman parçaları 4']
WALL_LAYERS = ['Orman parçaları', 'Orman parçaları 2', 'Su', 'Su collisionsuz', 'Su altı', 'Su ayrıntılar 2', 'Su ayrıntılar 3', 'Köprü alt',
               'Köprü üst', 'Blacksmith', 'blacksmith kapı', 'Ev ayrıntı', 'Ev', 'ev kapı', 'Ev Çatı 1', 'Maden', 'Maden 1', 'Düşman üssü']

EXT = 'exterior.tsx'
OBJ = 'Objects.tsx'
EXO = 'Exterior_objects.tsx'
FLW = 'Flowers.tsx'
SADE = 'sade ağaç ve taş.tsx'
PLANT = 'meyve sebze.tsx'
FARM = 'çiftlik parçaları.tsx'

## ---------------- sanat: (tileset, x, y, w, h) karo dikdörtgenleri (tools/cayir_susleri/README yerine burada) ----------------
ART = {
    ## ev / bostan
    'korkuluk': (EXT, 1, 37, 4, 4),          ## balkabağı kafalı korkuluk
    'kuyu': (EXT, 1, 34, 3, 3),              ## taş kuyu (çimen halkalı 4,34 sürümü oyunda ENGEL olmuyor: yaprak payı %52)
    'balta_kutuk': (EXO, 14, 27, 2, 2),      ## baltası saplı kesme kütüğü
    'odun_1': (EXO, 8, 29, 1, 2),
    'odun_2': (EXO, 10, 29, 1, 2),
    'odun_3': (EXO, 11, 29, 1, 2),
    'cuval': (EXO, 0, 29, 2, 2),
    'kurutma': (EXO, 0, 23, 4, 4),           ## deri kurutma çerçevesi + tabure (taburesiz 4,23 sürümünün ortası boş: test_deep_forest kuralını bozar)
    'kazik': (EXO, 6, 27, 2, 2),             ## yontulmuş kazıklar
    'lahana_1': (PLANT, 4, 3, 2, 2),
    'lahana_2': (PLANT, 6, 3, 2, 2),
    'balkabagi': (PLANT, 12, 3, 2, 2),
    'havuc': (PLANT, 2, 5, 1, 2),
    'pancar': (PLANT, 6, 5, 1, 2),
    'pirasa': (PLANT, 10, 5, 1, 2),
    'turp': (PLANT, 18, 5, 1, 2),
    'domates': (PLANT, 22, 0, 2, 3),
    'misir': (PLANT, 30, 0, 2, 3),
    'misir2': (PLANT, 28, 0, 2, 3),
    ## orman zemini
    'devrik_agac': (OBJ, 1, 9, 6, 3),
    'kutuk_buyuk': (OBJ, 7, 9, 3, 3),
    'kutuk_kok': (EXT, 11, 50, 2, 2),
    'kirik_dal': (EXT, 6, 42, 3, 2),
    'kutuk_kesik': (EXT, 12, 47, 2, 2),
    'mantar_k1': (OBJ, 23, 23, 2, 2),
    'mantar_k2': (OBJ, 25, 23, 2, 2),
    'mantar_k3': (OBJ, 27, 23, 2, 2),
    'mantar_b1': (OBJ, 23, 25, 2, 2),
    'mantar_b2': (OBJ, 25, 25, 2, 2),
    'mantar_b3': (OBJ, 27, 25, 2, 2),
    'kaya_koyu_b': (OBJ, 1, 26, 3, 3),
    'kaya_koyu_b2': (OBJ, 11, 26, 3, 3),
    'kaya_koyu_k1': (OBJ, 4, 26, 2, 2),
    'kaya_koyu_k2': (OBJ, 14, 26, 2, 2),
    'kaya_koyu_k3': (OBJ, 16, 26, 2, 2),
    'cakil_1': (OBJ, 13, 21, 2, 2),
    'cakil_2': (OBJ, 15, 21, 2, 2),
    'cakil_3': (OBJ, 21, 19, 2, 2),
    'mavi_tas_1': (EXT, 1, 52, 2, 2),
    'mavi_tas_2': (EXT, 3, 52, 2, 2),
    ## ağaçlar (haritanın orta bölgesindeki türler)
    'agac_yuvarlak': (SADE, 5, 0, 4, 5),
    'agac_govdeli': (SADE, 13, 0, 4, 5),
    'agac_kucuk': (SADE, 4, 5, 4, 4),
    'agac_yasli': (OBJ, 17, 0, 6, 5),
    ## çalı (Çalılar1'deki mevcut türler)
    'cali_yuvarlak': (SADE, 8, 9, 2, 2),
    'cali_kume': (OBJ, 25, 9, 2, 2),
    'cali_buyuk': (SADE, 5, 9, 3, 3),
    'cali_uzun': (SADE, 3, 9, 2, 3),
    'cali_koyu': (OBJ, 12, 6, 3, 3),
}
## sallanan ot filizleri (Çalılar katmanının kendi karoları) 1x2
TUFTS = [(EXT, 1, 54, 1, 2), (EXT, 2, 54, 1, 2)]   ## (0,54) resimde BOŞ karo (katmanda 21 kez var ama hiçbir şey çizmiyor)
## çiçek temaları: (ad, büyükler 2x2, tekler 1x1/1x2)
THEMES = {
    'mavi': ([(FLW, 0, 0, 2, 2), (FLW, 2, 0, 2, 2), (FLW, 10, 4, 2, 2)],
             [(FLW, 9, 6, 1, 1), (FLW, 10, 6, 1, 1), (FLW, 11, 6, 1, 1), (FLW, 12, 5, 1, 1), (FLW, 13, 5, 1, 1), (FLW, 12, 4, 1, 1),
              (FLW, 13, 4, 1, 1), (FLW, 5, 6, 1, 2)]),
    'sari': ([(FLW, 6, 2, 2, 2), (FLW, 8, 2, 2, 2), (FLW, 8, 4, 2, 2)],
             [(FLW, 0, 6, 1, 2), (FLW, 1, 6, 1, 2), (FLW, 2, 6, 1, 1), (EXT, 6, 54, 1, 1), (EXT, 7, 54, 1, 1), (EXT, 8, 54, 1, 1),
              (EXT, 9, 54, 1, 1), (FLW, 8, 6, 1, 1)]),
    'mor': ([(FLW, 0, 4, 2, 2), (FLW, 2, 4, 2, 2), (FLW, 4, 4, 2, 2)],
            [(FLW, 12, 6, 1, 1), (FLW, 13, 6, 1, 1), (FLW, 14, 6, 1, 1), (FLW, 16, 2, 1, 1), (FLW, 17, 2, 1, 1), (FLW, 3, 6, 1, 2),
             (FLW, 4, 6, 1, 2), (FLW, 2, 7, 1, 1)]),
    'pembe': ([(FLW, 6, 0, 2, 2), (FLW, 8, 0, 2, 2), (FLW, 14, 0, 2, 2), (FLW, 2, 2, 2, 2)],
              [(FLW, 10, 0, 2, 2), (FLW, 16, 0, 2, 2), (FLW, 4, 2, 2, 2), (EXT, 4, 54, 1, 1), (EXT, 10, 54, 1, 1), (FLW, 2, 7, 1, 1),
               (FLW, 12, 6, 1, 1)]),
}


def md5(p):
    return hashlib.md5(open(p, 'rb').read()).hexdigest()


class World:
    def __init__(self, text):
        self.text = text
        self.layers = K.layer_list(text)
        self.L = {n: c for n, o, v, c in self.layers}
        self.ts = K.Tilesets(text)
        self.sprites = {}
        x0, y0, x1, y1 = REGION
        self.x0, self.y0, self.W, self.H = x0, y0, x1 - x0, y1 - y0
        self.add = {}                          ## katman -> {hücre: gid}
        self.erase = {}                        ## katman -> {hücre}
        self.new_any = set()                   ## yeni süs hücreleri (zemin hariç)
        self.new_ground = set()
        self.new_solid = set()                 ## yeni katı nesnelerin ayak izi
        self.n_solid = 0
        self.log = []
        g = self.L['Zemin Çimen']
        self.dirt = self.mask(lambda c: g.get(c) != FULL_GRASS)
        ## Çimler'deki kahverengi (toprak lekesi) karolar da yol sayılır; yeşil filizler sayılmaz
        brown = {}
        for c, gid in self.L['Çimler'].items():
            if gid not in brown:
                t = self.ts.tile(gid)
                a = np.asarray(t, np.float32) if t is not None else None
                if a is None or a[..., 3].max() == 0:
                    brown[gid] = False
                else:
                    m = a[..., 3] > 100
                    r, gg = a[..., 0][m].mean(), a[..., 1][m].mean()
                    brown[gid] = r > gg
        self.dirt |= self.mask(lambda c: c in self.L['Çimler'] and brown[self.L['Çimler'][c]])
        walls = set()
        for n in WALL_LAYERS:
            walls |= set(self.L[n])
        self.wall = self.mask(lambda c: c in walls)
        occ = set()
        for n in DECOR_LAYERS:
            occ |= set(self.L[n])
        self.occ = self.mask(lambda c: c in occ)
        ## mevcut engeller (katı halka için): duvar + ağaç/nesne katmanları
        solid_layers = ['Ağaç 0', 'Ağaç 1', 'Ağaç 2', 'Ağaç ölü', 'Animasyonsuz çalılar', 'Derin orman nesneleri', 'Orman parçaları 3',
                        'Orman parçaları 4', 'orman parçaları -1']
        so = set()
        for n in solid_layers:
            so |= set(self.L[n])
        self.solid_old = self.mask(lambda c: c in so) | self.wall
        self.d_dirt = self.dist(self.dirt)
        self.d_wall = self.dist(self.wall)

    ## ---- ızgara yardımcıları (bölge yerel dizileri) ----
    def mask(self, f):
        m = np.zeros((self.H, self.W), bool)
        for j in range(self.H):
            for i in range(self.W):
                m[j, i] = f((self.x0 + i, self.y0 + j))
        return m

    def dist(self, m):
        """Chebyshev uzaklığı (hücre) en yakın True'ya; bölge dışı uzak sayılır."""
        d = np.full(m.shape, 999, np.int32)
        q = deque()
        for j, i in zip(*np.nonzero(m)):
            d[j, i] = 0
            q.append((j, i))
        while q:
            j, i = q.popleft()
            for dj in (-1, 0, 1):
                for di in (-1, 0, 1):
                    nj, ni = j + dj, i + di
                    if 0 <= nj < self.H and 0 <= ni < self.W and d[nj, ni] > d[j, i] + 1:
                        d[nj, ni] = d[j, i] + 1
                        q.append((nj, ni))
        return d

    def inside(self, c):
        return 0 <= c[0] - self.x0 < self.W and 0 <= c[1] - self.y0 < self.H

    def at(self, arr, c):
        return arr[c[1] - self.y0, c[0] - self.x0]

    def sp(self, key):
        spec = ART[key] if isinstance(key, str) else key
        if spec not in self.sprites:
            src, x, y, w, h = spec
            self.sprites[spec] = K.sprite(self.ts, str(key), src, x, y, w, h)
        return self.sprites[spec]

    ## ---- yerleştirme denetimi ----
    def footprint(self, s, ax, ay):
        """Katı nesnenin ayak izi: opak karoların en alt satırı (+ 3+ satırlık nesnede bir üstü)."""
        rows = {}
        for i, j, g in s.tiles:
            rows.setdefault(j, []).append(i)
        bot = max(rows)
        fp = {(ax + i, ay + bot) for i in rows[bot]}
        if s.h >= 3 and bot - 1 in rows:
            fp |= {(ax + i, ay + bot - 1) for i in rows[bot - 1]}
        return fp

    def solid_of(self, layer, s):
        """Oyunda engel mi: ağaç = gövde engeli; Animasyonsuz çalılar = terrain_collision props kuralı (cayir_core.is_solid_prop)."""
        if layer == L_TREE:
            return True
        if layer == L_PROP:
            return K.is_solid_prop(s)
        return False

    def can(self, layer, s, ax, ay, soft_gap=SOFT_PATH_GAP, ground_ok=False, ring_layer_gap=True, own_list=()):
        """own_list: aynı sahnenin önceki katı nesnelerinin ayak izleri (sahne içi nesneler birbirine yaslanabilir)."""
        own = set().union(*own_list) if own_list else set()
        solid = self.solid_of(layer, s)
        cells = s.cells(ax, ay)
        for c in cells:
            if not self.inside(c) or self.at(self.wall, c) or self.at(self.occ, c) or c in self.new_any:
                return False
            if c in self.new_ground and not ground_ok:
                return False
            if c in self.add.get(layer, {}):
                return False
        if layer == L_TREE:
            ## ağaç tacı yolun / duvarın üstüne taşmaz (madde 47 v2)
            for c in cells:
                if self.at(self.d_dirt, c) < 1 or self.at(self.d_wall, c) < 2:
                    return False
        if solid and not K.center_blocked(s):
            return False          ## katı ama ortası yürünebilir nesne konmaz (test_deep_forest: katı nesnenin ortası engel olmalı)
        if solid:
            fp = self.footprint(s, ax, ay)
            for c in fp:
                if self.at(self.d_dirt, c) < SOLID_PATH_GAP or self.at(self.d_wall, c) < SOLID_WALL_GAP:
                    return False
            ## sahne içi: ya bitişik (tek engel) ya en az 2 hücre aralık - 1 hücrelik aralık geçilecek gibi görünür ama oyuncu sığmaz (çap 22 px)
            for other in own_list:
                if min(max(abs(fx - ox), abs(fy - oy)) for (fx, fy) in fp for (ox, oy) in other) == 2:
                    return False
            for (fx, fy) in fp:
                for dx in range(-SOLID_RING, SOLID_RING + 1):
                    for dy in range(-SOLID_RING, SOLID_RING + 1):
                        n = (fx + dx, fy + dy)
                        if n in fp or n in own:
                            continue
                        if n in self.new_solid or (self.inside(n) and self.at(self.solid_old, n) and n not in cells):
                            return False
        else:
            for c in cells:
                if self.at(self.d_dirt, c) < soft_gap or self.at(self.d_wall, c) < 1:
                    return False
        if layer in SWAY_LAYERS and ring_layer_gap:
            lay = self.add.get(layer, {})
            for (cx, cy) in cells:
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        n = (cx + dx, cy + dy)
                        if n not in cells and n in lay:
                            return False
        return True

    def put(self, layer, s, ax, ay):
        cells = s.cells(ax, ay)
        self.add.setdefault(layer, {}).update(cells)
        if layer == L_GROUND:
            self.new_ground |= set(cells)
        else:
            self.new_any |= set(cells)
        fp = set()
        if self.solid_of(layer, s):
            fp = self.footprint(s, ax, ay)
            self.new_solid |= fp
            self.n_solid += 1
        return fp

    def snapshot(self):
        return (dict((k, dict(v)) for k, v in self.add.items()), set(self.new_any), set(self.new_ground), set(self.new_solid), self.n_solid)

    def restore(self, snap):
        self.add, self.new_any, self.new_ground, self.new_solid, self.n_solid = snap

    ## ---- sahneler ----
    def place_group(self, name, center, radius, parts):
        """parts: [(katman, sprite anahtarı, dx, dy)] - (dx, dy) grubun çapasına göre. En yakın geçerli çapa aranır."""
        cx, cy = center
        cands = sorted(((dx, dy) for dx in range(-radius, radius + 1) for dy in range(-radius, radius + 1)),
                       key=lambda d: (d[0] * d[0] + d[1] * d[1], d))
        for dx, dy in cands:
            ax, ay = cx + dx, cy + dy
            ok = True
            snap = self.snapshot()
            own = []
            for layer, key, ox, oy in parts:
                s = self.sp(key)
                if not self.can(layer, s, ax + ox, ay + oy, ground_ok=layer != L_GROUND, ring_layer_gap=False, own_list=own):
                    ok = False
                    break
                fp = self.put(layer, s, ax + ox, ay + oy)
                if fp:
                    own.append(fp)
            if ok:
                self.log.append('%-22s çapa (%d, %d)  [istenen (%d, %d)]' % (name, ax, ay, cx, cy))
                return (ax, ay)
            self.restore(snap)
        self.log.append('%-22s YER BULUNAMADI (istenen (%d, %d) r%d)' % (name, cx, cy, radius))
        return None

    def scatter(self, rng, layer, keys, center, rx, ry, count, flip=False, soft_gap=SOFT_PATH_GAP, tries=400):
        """Elips içinde (merkeze yoğun) count adet; keys sırayla/rastgele."""
        placed = 0
        for _ in range(tries):
            if placed >= count:
                break
            a = rng.random() * math.tau
            r = math.sqrt(rng.random()) ** 1.3
            x = int(round(center[0] + math.cos(a) * rx * r))
            y = int(round(center[1] + math.sin(a) * ry * r))
            key = rng.choice(keys)
            s = self.sp(key)
            if flip and rng.random() < 0.5:
                s = flipped(s)
            if self.can(layer, s, x, y, soft_gap=soft_gap):
                self.put(layer, s, x, y)
                placed += 1
        return placed


def flipped(s):
    """Yatay çevrilmiş kopya (Tiled çevirme biti); 1 karo genişliğinde ofset aynı."""
    tiles = [(s.w - 1 - i, j, g | 0x80000000) for i, j, g in s.tiles]
    return K.Sprite(s.name + '_f', s.src, tiles, s.w, s.h, s.rgba.transpose(Image.FLIP_LEFT_RIGHT))


def soil_bed(W, ax, ay, w, h):
    """Çiftlik toprağı (çiftlik parçaları 8..11 x 13..16 dolu yama): kenar/köşe karoları + iç."""
    fg, _s, _img, cols, _c = W.ts.by_src[FARM]
    cells = {}
    for j in range(h):
        for i in range(w):
            tx = 8 if i == 0 else 11 if i == w - 1 else 9 + (i % 2)
            ty = 13 if j == 0 else 16 if j == h - 1 else 14 + (j % 2)
            cells[(ax + i, ay + j)] = fg + ty * cols + tx
    return cells


def build(W):
    """SADE sürüm (2026-10-24, kullanıcı ilk sürüm için: "çok abartmışsın doğal durmuyor, gerçek çayırda bu kadar çok şey olmaz"): ilk sürümün
    15 çiçek öbeği, yol kenarı otları, seyrek tek çiçekler, avcı kampı, kuyu, peri halkası, 6 taş öbeği, 4 ağaç, 14 çalısı ÇIKARILDI. Kalan: evin
    kendi bostanı + korkuluğu + odun kütüğü, çayırda tek yaşlı ağaç + bir ağaç, bir devrik ağaç, iki yalın taş, birkaç çalı ve tek türden küçük çiçek
    kümeleri (gerçek kır çiçekleri öbek öbek ve tek tür olur, her yere serpilmez)."""
    rng = random.Random(SEED)
    ## 1) EVİN KENDİSİ: bostan + korkuluk, duvar dibinde odun kesme kütüğü
    garden = None
    for (cx, cy) in [(130, 82), (133, 79), (136, 81), (131, 76)]:
        garden = try_garden(W, cx, cy)
        if garden:
            break
    if not garden:
        W.log.append('bostan                 YER BULUNAMADI')
    W.place_group('odun kesme', (127, 79), 6, [
        (L_PROP, 'balta_kutuk', 0, 0),
        (L_PROP, 'odun_1', 2, 0),
    ])
    ## 2) ÇAYIR: tek yaşlı ağaç (güneydoğu çayırının ortası) + güneybatıda bir ağaç
    W.place_group('yaşlı ağaç (çayır)', (162, 146), 6, [(L_TREE, 'agac_yasli', 0, 0)])
    W.place_group('ağaç (güneybatı)', (113, 163), 6, [(L_TREE, 'agac_govdeli', 0, 0)])
    ## 3) devrik ağaç + kendi kütüğü, iki yalın taş
    log = W.place_group('devrik ağaç', (137, 140), 10, [
        (L_PROP, 'devrik_agac', 0, 0),
        (L_PROP, 'kutuk_buyuk', 6, 0),       ## devrilen ağacın kendi kütüğü (bitişik = tek engel)
    ])
    if log:
        W.scatter(rng, L_PROP, ['mantar_k3'], (log[0] + 3, log[1] + 3), 2.0, 1.0, 1)
    W.place_group('taş (batı)', (107, 102), 6, [
        (L_PROP, 'kaya_koyu_b', 0, 0),
        (L_PROP, 'kaya_koyu_k1', 3, 1),
    ])
    W.place_group('taş (doğu)', (172, 139), 8, [(L_PROP, 'kaya_koyu_k2', 0, 0)])
    ## 4) ÇALILAR: duvar/nehir kıyısına yakın, yoldan uzak, birbirinden en az 20 hücre aralıklı (sallanır, engel değil)
    bush_keys = ['cali_yuvarlak', 'cali_buyuk', 'cali_kume', 'cali_uzun']
    spots = [(W.x0 + i, W.y0 + j) for j in range(W.H) for i in range(W.W) if 2 <= W.d_wall[j, i] <= 4 and W.d_dirt[j, i] >= 3]
    rng.shuffle(spots)
    bushes = []
    for (x, y) in spots:
        if len(bushes) >= 5:
            break
        if any(abs(x - bx) + abs(y - by) < 20 for bx, by in bushes) or any(abs(x - a) + abs(y - b) < 4 for a, b in W.new_solid):
            continue
        key = bush_keys[len(bushes) % len(bush_keys)]
        s = W.sp(key)
        if W.can(L_BUSH, s, x, y):
            W.put(L_BUSH, s, x, y)
            bushes.append((x, y))
    W.log.append('%-22s %d adet' % ('kıyı/duvar dibi çalı', len(bushes)))
    ## 5) ÇİÇEK KÜMELERİ: 5 küme, her biri TEK tür (+ en çok bir iri aynı renkte), sık ve küçük
    patches = [
        ('mavi', (152, 141), [(FLW, 10, 6, 1, 1)], (FLW, 2, 0, 2, 2)),
        ('sarı', (112, 108), [(FLW, 0, 6, 1, 2), (FLW, 1, 6, 1, 2)], None),
        ('mor', (127, 163), [(FLW, 12, 6, 1, 1)], (FLW, 2, 4, 2, 2)),
        ('turuncu', (168, 129), [(EXT, 7, 54, 1, 1), (EXT, 8, 54, 1, 1)], None),
        ('beyaz', (100, 72), [(FLW, 12, 4, 1, 1), (FLW, 13, 4, 1, 1)], None),
    ]
    for name, c, small, big in patches:
        nb = W.scatter(rng, L_FLOWER, [big], c, 1.0, 0.8, 1) if big else 0
        ns = W.scatter(rng, L_FLOWER, small, c, 3.0, 2.0, 7)
        W.log.append('%-22s %s %s: %d iri + %d küçük' % ('çiçek kümesi', name, c, nb, ns))
    ## 6) kalan nesnelerin dibinde birkaç sallanan ot filizi (yol kenarlarına ve çayırın geneline YOK)
    n_base = 0
    for layer in (L_PROP, L_TREE):
        for (x, y) in sorted(W.add.get(layer, {})):
            if rng.random() < 0.15:
                n_base += W.scatter(rng, L_TUFT, TUFTS, (x, y + 1), 1.6, 1.0, 1, flip=True, tries=12)
    W.log.append('ot filizi (nesne dibi): %d' % n_base)


def try_garden(W, cx, cy):
    """Babaannenin bostanı: 7x4 toprak; arka sıra (tabanı 2. satırda) mısır/domates/mısır + pırasa, ön sıra (tabanı son satırda) havuç/pancar/
    turp + lahana; doğusunda korkuluk. Toprak 'Çimler'de (zemin ayrıntısı): altındaki mini ot silinir."""
    crops = [('misir', 0, -1), ('domates', 2, -1), ('misir2', 4, -1), ('pirasa', 6, 0),
             ('havuc', 0, 2), ('pancar', 1, 2), ('havuc', 2, 2), ('turp', 3, 2), ('lahana_1', 4, 2), ('pancar', 6, 2)]
    for dx, dy in sorted(((a, b) for a in range(-3, 4) for b in range(-3, 4)), key=lambda d: (d[0] * d[0] + d[1] * d[1], d)):
        ax, ay = cx + dx, cy + dy
        bed = soil_bed(W, ax, ay, 7, 4)
        if any(not W.inside(c) or W.at(W.wall, c) or W.at(W.occ, c) or c in W.new_any or c in W.new_ground or W.at(W.d_dirt, c) < 2
               for c in bed):
            continue
        snap = W.snapshot()
        W.add.setdefault(L_GROUND, {}).update(bed)
        W.new_ground |= set(bed)
        ok = True
        for key, ox, oy in crops:
            s = W.sp(key)
            if any((not W.inside(c)) or W.at(W.wall, c) or W.at(W.occ, c) or c in W.new_any for c in s.cells(ax + ox, ay + oy)):
                ok = False
                break
            W.put(L_FLOWER, s, ax + ox, ay + oy)
        n_log = len(W.log)
        if ok:
            ok = bool(W.place_group('korkuluk', (ax + 8, ay - 2), 2, [(L_PROP, 'korkuluk', 0, 0)]))
        if ok:
            W.erase.setdefault(L_GROUND, set()).update(c for c in bed if c in W.L[L_GROUND])
            W.log.append('%-22s çapa (%d, %d) 7x4 toprak + %d sebze' % ('bostan', ax, ay, len(crops)))
            return (ax, ay)
        del W.log[n_log:]
        W.restore(snap)
    return None


def fairy_ring(W, center):
    """Peri halkası: 8 küçük mantar elips üstünde (hiçbiri engel değil), ortada üç küçük çiçek."""
    keys = ['mantar_k1', 'mantar_k2', 'mantar_k3', 'mantar_b2', 'mantar_b3']
    cx, cy = center
    for dx, dy in sorted(((a, b) for a in range(-4, 5) for b in range(-4, 5)), key=lambda d: (d[0] * d[0] + d[1] * d[1], d)):
        ox, oy = cx + dx, cy + dy
        snap = W.snapshot()
        placed = 0
        bad = False
        for k in range(8):
            ang = k / 8 * math.tau
            x = int(round(ox + math.cos(ang) * 4.0)) - 1
            y = int(round(oy + math.sin(ang) * 3.0)) - 1
            s = W.sp(keys[(k * 3) % len(keys)])
            if any(c in W.new_any for c in s.cells(x, y)):
                continue          ## halkanın kendi komşusuyla çakışıyorsa o mantar atlanır
            if not W.can(L_PROP, s, x, y, ring_layer_gap=False):
                bad = True
                break
            W.put(L_PROP, s, x, y)
            placed += 1
        if not bad and placed >= 7:
            for k, key in enumerate([(FLW, 12, 4, 1, 1), (FLW, 13, 4, 1, 1), (FLW, 2, 7, 1, 1)]):
                s = W.sp(key)
                if W.can(L_FLOWER, s, ox - 1 + k, oy - (k % 2), ring_layer_gap=False):
                    W.put(L_FLOWER, s, ox - 1 + k, oy - (k % 2))
            W.log.append('%-22s merkez (%d, %d)  [istenen (%d, %d)] %d mantar' % ('peri halkası', ox, oy, cx, cy, placed))
            return (ox, oy)
        W.restore(snap)
    W.log.append('peri halkası           YER BULUNAMADI %s' % (center,))
    return None


def preview(W, path, layers, extra, region=None, scale=0.5, grid=True):
    reg = region or REGION
    im = K.render(layers, W.ts, reg, extra=extra).convert('RGB')
    im = im.resize((int(im.size[0] * scale), int(im.size[1] * scale)), Image.LANCZOS if scale < 1 else Image.NEAREST)
    if grid:
        d = ImageDraw.Draw(im)
        c = 16 * scale
        for x in range(reg[0], reg[2] + 1):
            if x % 10 == 0:
                d.line([((x - reg[0]) * c, 0), ((x - reg[0]) * c, im.size[1])], fill=(255, 80, 80))
                d.text(((x - reg[0]) * c + 2, 2), str(x), fill=(255, 255, 0))
        for y in range(reg[1], reg[3] + 1):
            if y % 10 == 0:
                d.line([(0, (y - reg[1]) * c), (im.size[0], (y - reg[1]) * c)], fill=(255, 80, 80))
                d.text((2, (y - reg[1]) * c + 2), str(y), fill=(255, 255, 0))
    im.save(path)


def main():
    os.makedirs(OUT, exist_ok=True)
    text = K.read_tmx()
    assert '\r' not in text
    W = World(text)
    build(W)
    for line in W.log:
        print(line)
    tot = {k: len(v) for k, v in W.add.items()}
    print('eklenen hücre:', tot, '| silinen Çimler:', len(W.erase.get(L_GROUND, ())), '| yeni ENGEL nesne:', W.n_solid,
          '(ayak izi %d hücre)' % len(W.new_solid))
    after = [(n, o, v, {k: g for k, g in c.items() if k not in W.erase.get(n, ())}) for n, o, v, c in W.layers]
    preview(W, os.path.join(OUT, 'once.png'), W.layers, None)
    preview(W, os.path.join(OUT, 'sonra.png'), after, W.add)
    for name, reg in [('ev', (110, 68, 150, 100)), ('guneydogu', (140, 124, 182, 170)), ('guneybati', (96, 96, 140, 172))]:
        preview(W, os.path.join(OUT, 'yakin_%s_once.png' % name), W.layers, None, reg, 1.0, False)
        preview(W, os.path.join(OUT, 'yakin_%s.png' % name), after, W.add, reg, 1.0, False)
    if '--apply' in sys.argv:
        want = sys.argv[sys.argv.index('--apply') + 1]
        have = md5(K.TMX)
        if have != want:
            print('DURDU: Harita.tmx md5 değişmiş (%s), Tiled\'dan kaydedilmiş olabilir' % have)
            return 1
        if not os.path.exists(YEDEK):
            shutil.copyfile(K.TMX, YEDEK)
            print('yedek:', YEDEK)
        out = text
        for layer, cells in W.erase.items():
            if cells:
                m = K.layer_span(out, layer)
                ch = K.parse_chunks(m.group(1))
                for (x, y) in cells:
                    ch[((x // 16) * 16, (y // 16) * 16)][y - (y // 16) * 16, x - (x // 16) * 16] = 0
                out = out[:m.start(1)] + K.write_chunks(ch) + out[m.end(1):]
        for layer, cells in W.add.items():
            out = K.add_cells(out, layer, cells)
        with open(K.TMX, 'w', encoding='utf-8', newline='\n') as f:
            f.write(out)
        open(os.path.join(OUT, 'son_yazim.md5'), 'w').write(md5(K.TMX))
        print('YAZILDI | yeni md5', md5(K.TMX))
    else:
        print('kuru çalışma | şu anki md5', md5(K.TMX))
    return 0


if __name__ == '__main__':
    sys.exit(main())
