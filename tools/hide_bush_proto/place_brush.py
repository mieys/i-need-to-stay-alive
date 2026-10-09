"""SAKLANMA ÇALILIĞI -> Harita.tmx (2026-10-09) - kullanıcı: "bu çok güzel. bunun haritada yer yer bazı köşelerde toplu bir biçimde olmasını istiyorum,
köşelere uygun bir şekilde oyuncuların ara sıra saklanabileceği bir yer olsun. bunu harita.tmx'e ekle".

Yapılan: duvarın (Orman parçaları/Orman parçaları = çarpışma katmanı) İÇ KÖŞELERİ bulunur (iki duvar kolu dik buluşur, köşe cebi açık çimen), köşeler haritaya
dağıtılarak seçilir, her köşeye o köşeyi saran çeyrek-elips bir çalılık (gen_brush_proto.py stili K1 "Dengeli": uzun ot + açık gizemli ot) çizilir, çizim
16 px kutucuklara bölünüp YENİ bir tileset (harita/saklanma_calilik.png + .tsx) ve YENİ bir katman ("Shader Eklenecek/Saklanma Çalılığı", Ağaç 0'ın hemen altında)
olarak eklenir. Çalılık çarpışmasız (içine yürünür). Köşe seçimi: su/kumsal/yol/ev+kapı/köprü/maden/düşman üssü/dar vadi (MX) uzak; haritanın ÖZGÜN nesneleriyle
(ağaç, çalı, nesne) üst üste gelen köşe ATLANIR; çalılığın kapladığı yerde BENİM 2026-10-09 orman dokusu eklerim (ağaç/çalı/çiçek/mantar) varsa bütün olarak kaldırılır.
Saklanma alanları (çalılığın zemin maskesi, hücre + dünya px) out/saklanma_alanlari.json'a da yazılır (görünmezlik mekaniği için).

Kullanım (proje kökünden):
  python -I tools/hide_bush_proto/place_brush.py              -> out/Harita_calilik.tmx + harita/saklanma_calilik.{png,tsx} + önizlemeler
  python -I tools/hide_bush_proto/place_brush.py --apply <md5> -> canlı harita/Harita.tmx'i (md5 kapısıyla) out/Harita_calilik.tmx ile değiştirir
"""
import hashlib
import json
import math
import os
import random
import re
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(HERE, 'out')
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(PROJECT, 'tools', 'forest_decor'))
os.environ.setdefault('HARITA_TMX', os.path.join(PROJECT, 'harita', 'Harita.tmx'))
import gen_brush_proto as GB                       # noqa: E402
from tmxlib import load, layers, grid, render     # noqa: E402

LIVE = os.path.join(PROJECT, 'harita', 'Harita.tmx')
ORIG = os.path.join(PROJECT, 'harita', 'yedek', 'Harita_YEDEK_2026-10-09_agac-oncesi.tmx.bak')
OUT_TMX = os.path.join(OUT, 'Harita_calilik.tmx')
TSX_NAME = 'saklanma_calilik.tsx'
PNG_NAME = 'saklanma_calilik.png'
LAYER_NAME = 'Saklanma Çalılığı'
STYLE = 'k1'
SEED = 20261009
N_PATCHES = 22
MIN_GAP = 15                 # köşeler arası en az (hücre)
# 2. TUR (kullanıcı: "çok az koymuşsun, hepsi çok büyük ve geniş, bazılarının küçük olmasını istiyorum; vadi kenarlarındaki yol geçişlerini kapatmasınlar,
# içinden geçebilirler ama tamamen kapatmasınlar"): boyut sınıfları (çoğu küçük) + her çalılık için yerel YOL TESTİ (çalılık engel sayılınca 3 hücrelik
# açık şerit hâlâ var mı; ağaç gövdeleri ve önceki çalılıklar dahil). Kaynak: çalılıklardan ÖNCEKİ Harita.tmx (yedek); uygulama canlı dosyanın md5 kapısıyla.
SRC = os.path.join(PROJECT, 'harita', 'yedek', 'Harita_oncesi_saklanma-calilik.tmx.bak')
SIZES = {   # sınıf: (paralel yarıçap aralığı, açık yöne yarıçap aralığı) hücre cinsinden, en az piksel
    'küçük': ((2.6, 3.4), (2.0, 2.6), 260),
    'orta': ((3.8, 4.8), (2.8, 3.4), 520),
    'büyük': ((5.2, 6.4), (3.4, 4.2), 950),
}
SIZE_WEIGHTS = [('küçük', 0.5), ('orta', 0.35), ('büyük', 0.15)]
FIRSTGID = 34768             # Harita.tmx'teki son tileset (blacksmith kapı 34750 + 18)
W = H = 256
T = 16


def md5(p):
    return hashlib.md5(open(p, 'rb').read()).hexdigest()


def dil(m, r):
    pad = np.pad(m, r, constant_values=False)
    out = np.zeros_like(m)
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= r * r + r:
                out |= pad[r + dy:r + dy + m.shape[0], r + dx:r + dx + m.shape[1]]
    return out


def cheb(m, maxd=12):
    d = np.full(m.shape, maxd + 1, np.int32)
    d[m] = 0
    cur = m.copy()
    for k in range(1, maxd + 1):
        nxt = dil(cur, 1)
        d[nxt & ~cur] = k
        cur = nxt
    return d


def clearance(blk):
    R = 9
    pad = np.pad(blk, R, constant_values=True)
    D = np.full((H, W), 99.0)
    for dy in range(-R, R + 1):
        for dx in range(-R, R + 1):
            d = (dx * dx + dy * dy) ** 0.5
            if d > R:
                continue
            D = np.where(pad[R + dy:R + dy + H, R + dx:R + dx + W] & (D > d), d, D)
    D[blk] = 0
    r = 5
    padD = np.pad(D, r, constant_values=0)
    MX = np.zeros((H, W))
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= r * r:
                MX = np.maximum(MX, padD[r + dy:r + dy + H, r + dx:r + dx + W])
    return MX


def decode(ts, gid):
    g = gid & 0x0FFFFFFF
    t = ts.find(g)
    return (t[1], g - t[0], gid & 0xE0000000, t[3]) if t else None


def groups_new(ts, g_live, g_orig):
    """canlıda olup özgünde olmayan karolardan atlas-komşuluğu grupları (benim eklediğim her damga bir grup)"""
    cells = {}
    for y, x in zip(*np.nonzero((g_live != 0) & (g_orig == 0))):
        d = decode(ts, int(g_live[y, x]))
        if d:
            cells[(int(y), int(x))] = d
    parent = {k: k for k in cells}

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    for (y, x), (src, i, fl, cols) in cells.items():
        for dy, dx, di in ((0, 1, 1), (1, 0, cols)):
            n = (y + dy, x + dx)
            if n in cells and cells[n][0] == src and cells[n][2] == fl and cells[n][1] == i + di:
                parent[find(n)] = find((y, x))
    out = {}
    for k in cells:
        out.setdefault(find(k), []).append(k)
    return list(out.values())


# ---------------------------------------------------------------- analiz
def wide_free(block):
    """3x3'ü tamamen boş hücreler (3 hücrelik şeritte yürünebilir)"""
    pad = np.pad(block, 1, constant_values=True)
    er = block.copy()
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            er |= pad[1 + dy:1 + dy + block.shape[0], 1 + dx:1 + dx + block.shape[1]]
    return ~er


def label4(m):
    lab = np.zeros(m.shape, np.int32)
    n = 0
    for y, x in zip(*np.nonzero(m)):
        if lab[y, x]:
            continue
        n += 1
        st = [(y, x)]
        lab[y, x] = n
        while st:
            cy, cx = st.pop()
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                yy, xx = cy + dy, cx + dx
                if 0 <= yy < m.shape[0] and 0 <= xx < m.shape[1] and m[yy, xx] and not lab[yy, xx]:
                    lab[yy, xx] = n
                    st.append((yy, xx))
    return lab


def lane_ok(block, ground_cells, R=12):
    """çalılığın zemin hücreleri ENGEL sayıldığında pencere kenarları arasındaki 3 hücrelik şerit bağlantısı bozulmuyor mu + büyük kapalı cep oluşmuyor mu"""
    xs = [c[0] for c in ground_cells]; ys = [c[1] for c in ground_cells]
    x0, x1 = max(0, min(xs) - R), min(W, max(xs) + R + 1)
    y0, y1 = max(0, min(ys) - R), min(H, max(ys) + R + 1)
    # 3x3 boşluk 1 hücre GENİŞ pencerede hesaplanıp kırpılır (dışarıyı dolu saymak kenar hücrelerini hep "kapalı" yapıyordu -> test boş kalıyordu)
    X0, X1, Y0, Y1 = max(0, x0 - 1), min(W, x1 + 1), max(0, y0 - 1), min(H, y1 + 1)
    B0 = block[Y0:Y1, X0:X1]
    B1 = B0.copy()
    for (x, y) in ground_cells:
        B1[y - Y0, x - X0] = True
    sl = (slice(y0 - Y0, y0 - Y0 + (y1 - y0)), slice(x0 - X0, x0 - X0 + (x1 - x0)))
    b0 = B0[sl]
    w0, w1 = wide_free(B0)[sl], wide_free(B1)[sl]
    l0, l1 = label4(w0), label4(w1)
    hh, ww = b0.shape
    ring = [(y, x) for y in range(hh) for x in range(ww) if (y in (0, hh - 1) or x in (0, ww - 1)) and w0[y, x]]
    groups = {}
    for (y, x) in ring:
        groups.setdefault(int(l0[y, x]), set()).add(int(l1[y, x]) if w1[y, x] else -1)
    for bs in groups.values():
        if len(bs) > 1 or -1 in bs:
            return False
    ring_l1 = {int(l1[y, x]) for (y, x) in ring if w1[y, x]}
    ring_l0 = {int(l0[y, x]) for (y, x) in ring}
    pocket = w1 & ~np.isin(l1, list(ring_l1)) & np.isin(l0, list(ring_l0))
    if int(pocket.sum()) >= 25:
        return False
    # DOLAMBAÇ: bağlantı kopmasa bile geçidi kapatıp oyuncuyu etrafından dolaştırıyorsa ret (pencerede başka yol olması kapanmayı gizlemesin)
    if not _detour_ok(w0, w1, ring):
        return False
    # DAR GEÇİTLER (3. tur, kullanıcı: "7-6-16 geçiş yollarını kapatıyor"): 3 hücreden dar rampalar/boğazlar 3x3 düzeyinde zaten "kapalı" göründüğü için
    # yukarıdaki test onları görmüyordu. 1 hücrelik yürüme düzeyinde, çalılık + çevresindeki 1 hücre engel sayılınca da bağlantı/dolambaç bozulmamalı.
    g1 = np.zeros_like(b0)
    for (x, y) in ground_cells:
        g1[y - y0, x - x0] = True
    pad = np.pad(g1, 1, constant_values=False)
    gd = g1.copy()
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            gd |= pad[1 + dy:1 + dy + g1.shape[0], 1 + dx:1 + dx + g1.shape[1]]
    f0 = ~b0
    f1 = ~b0 & ~gd
    l0n, l1n = label4(f0), label4(f1)
    ring_n = [(y, x) for y in range(hh) for x in range(ww) if (y in (0, hh - 1) or x in (0, ww - 1)) and f0[y, x]]
    groups = {}
    for (y, x) in ring_n:
        groups.setdefault(int(l0n[y, x]), set()).add(int(l1n[y, x]) if f1[y, x] else -1)
    for bs in groups.values():
        if len(bs) > 1 or -1 in bs:
            return False
    return _detour_ok(f0, f1, ring_n)


def _detour_ok(f0, f1, ring):
    pts = ring[::max(1, len(ring) // 18)]
    for (sy, sx) in pts:
        d0 = bfs_dist(f0, (sy, sx))
        d1 = bfs_dist(f1, (sy, sx))
        for (ty, tx) in pts:
            a, b = d0[ty, tx], d1[ty, tx]
            if a < 0:
                continue
            if b < 0 or (b > a + 6 and b > a * 1.25):
                return False
    return True


def bfs_dist(free, start):
    d = np.full(free.shape, -1, np.int32)
    if not free[start]:
        return d
    d[start] = 0
    q = [start]
    i = 0
    while i < len(q):
        y, x = q[i]; i += 1
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            yy, xx = y + dy, x + dx
            if 0 <= yy < free.shape[0] and 0 <= xx < free.shape[1] and free[yy, xx] and d[yy, xx] < 0:
                d[yy, xx] = d[y, x] + 1
                q.append((yy, xx))
    return d


def tree_trunks(ts, L):
    """ağaç katmanlarındaki gövde (çarpışma) hücreleri - terrain_collision.gd kuralı (stamplib.footprint)"""
    import stamplib
    fp = np.zeros((H, W), bool)
    for k in ('Shader Eklenecek/Ağaç 0', 'Shader Eklenecek/Ağaç 1', 'Shader Eklenecek/Ağaç 2'):
        g = L[k]
        cells = {}
        for y, x in zip(*np.nonzero(g)):
            d = decode(ts, int(g[y, x]))
            if d:
                cells[(int(y), int(x))] = d
        parent = {k2: k2 for k2 in cells}

        def find(a):
            while parent[a] != a:
                parent[a] = parent[parent[a]]
                a = parent[a]
            return a
        for (y, x), (src, i, fl, cols) in cells.items():
            for dy, dx, di in ((0, 1, 1), (1, 0, cols)):
                n = (y + dy, x + dx)
                if n in cells and cells[n][0] == src and cells[n][2] == fl and cells[n][1] == i + di:
                    parent[find(n)] = find((y, x))
        groups = {}
        for a in cells:
            groups.setdefault(find(a), []).append(a)
        for ks in groups.values():
            y0 = min(a[0] for a in ks); x0 = min(a[1] for a in ks)
            w = max(a[1] for a in ks) - x0 + 1; h = max(a[0] for a in ks) - y0 + 1
            al = np.zeros((h * T, w * T), np.uint8)
            for a in ks:
                im = ts.tile(int(g[a]))
                if im:
                    al[(a[0] - y0) * T:(a[0] - y0 + 1) * T, (a[1] - x0) * T:(a[1] - x0 + 1) * T] = np.array(im.getchannel('A'))
            f, _b = stamplib.footprint({'alpha': al})
            for dx, dy in f:
                cx, cy = x0 + dx, y0 + dy
                if 0 <= cx < W and 0 <= cy < H:
                    fp[cy, cx] = True
    return fp


def build():
    rng = random.Random(SEED)
    root, ts = load(SRC)
    L = {'/'.join(p): grid(l) for p, l in layers(root)}
    root_o, ts_o = load(ORIG)
    LO = {'/'.join(p): grid(l) for p, l in layers(root_o)}
    wall = L['Orman parçaları/Orman parçaları'] != 0
    water_core = L['Su/Su'] != 0
    water_any = water_core | (L['Su/Su collisionsuz'] != 0) | (L['Su/Su altı'] != 0)
    grass = L['Yer/Zemin Çimen'] != 0
    dirt = ~grass & ~water_core
    house = np.zeros((H, W), bool)
    for k in ('ev/Blacksmith', 'ev/blacksmith kapı', 'ev/Ev ayrıntı', 'ev/Ev', 'ev/ev kapı', 'ev/Ev Çatı 1', 'ev/baca duman'):
        house |= L[k] != 0
    bridge = (L['Köprü/Köprü alt'] != 0) | (L['Köprü/Köprü üst'] != 0)
    mine = (L['Etkileşimler/Maden'] != 0) | (L['Etkileşimler/Maden 1'] != 0)
    base = (L['Düşman Üssü/Düşman üssü'] != 0) | (L['Düşman Üssü/Özel maden'] != 0)
    # orman katmanlarındaki NESNE karoları (kaya/kalıntı) - kenar saçağı (Ground_grass) serbest
    forest_obj = np.zeros((H, W), bool)
    for k in ('Orman parçaları/Orman parçaları 2', 'Orman parçaları/Orman parçaları 3', 'Orman parçaları/Orman parçaları 4', 'Orman parçaları/orman parçaları -1'):
        g = L[k]
        for y, x in zip(*np.nonzero(g)):
            d = decode(ts, int(g[y, x]))
            if d and d[0] != 'Ground_grass.tsx':
                forest_obj[y, x] = True
    # haritanın ÖZGÜN nesneleri (dokunulmaz)
    protect = np.zeros((H, W), bool)
    for k in ('Shader Eklenecek/Ağaç 0', 'Shader Eklenecek/Ağaç 1', 'Shader Eklenecek/Ağaç 2', 'Shader Eklenecek/Çalılar1', 'Shader Eklenecek/Animasyonsuz çalılar'):
        protect |= LO[k] != 0
    water_d = cheb(water_core, 12)
    beach = ((dirt & (water_d <= 8)) | (water_any & ~water_core)) & ~water_core
    wb = np.roll(water_core, -1, 0); wb[-1, :] = False; wb &= ~np.roll(bridge, -1, 0)
    MX = clearance(wall | wb | house | mine | base)
    # YAMAÇ KENARI ÇİZGİLERİ (Orman parçaları 2/3/4/-1; kaya duvara bitişik olanlar hariç): oyunda çarpışmasız ama vadi geçişlerini görsel olarak bunlar çiziyor
    ledge = np.zeros((H, W), bool)
    for k in ('Orman parçaları/Orman parçaları 2', 'Orman parçaları/Orman parçaları 3', 'Orman parçaları/Orman parçaları 4', 'Orman parçaları/orman parçaları -1'):
        ledge |= L[k] != 0
    ledge_line = ledge & ~dil(wall, 1)
    lane_block = wall | wb | house | mine | base | tree_trunks(ts, L) | ledge_line
    door_ban = np.zeros((H, W), bool)
    for (dx_, dy_) in ((120, 85), (81, 150)):
        door_ban[max(0, dy_ - 10):dy_ + 8, max(0, dx_ - 11):dx_ + 12] = True
    ban = (water_any | dil(water_core, 2) | beach | dil(dirt, 1) | dil(house, 6) | door_ban | dil(bridge, 4) | dil(mine, 4) | dil(base, 6)
           | forest_obj | protect)
    free = ~wall & grass & ~ban

    # ---- iç köşeler: (px, py) cep yönü; duvarlar köşenin -px yanında (dikey kol) ve -py yanında (yatay kol)
    cands = []
    for y in range(4, H - 4):
        for x in range(4, W - 4):
            if not free[y, x]:
                continue
            for (px, py) in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
                # duvar kolları köşeye bitişik ya da 1 hücre uzakta olabilir (aradaki yamaç saçağı serbest)
                gx = 1 if wall[y, x - px] else (2 if wall[y, x - 2 * px] else 0)
                gy = 1 if wall[y - py, x] else (2 if wall[y - 2 * py, x] else 0)
                if not gx or not gy:
                    continue
                run_v = 0
                while run_v < 12 and 0 <= y + py * run_v < H and wall[y + py * run_v, x - gx * px]:
                    run_v += 1
                run_h = 0
                while run_h < 12 and 0 <= x + px * run_h < W and wall[y - gy * py, x + px * run_h]:
                    run_h += 1
                if run_v < 3 or run_h < 3:
                    continue
                # en az bir kol GÖRÜNÜR kaya yüzü olsun (212 = düz çim dolgusu: görünmez çarpışma; ona yaslanan çalılık havada durur)
                arm = [(x - gx * px, y + py * k) for k in range(run_v)] + [(x + px * k, y - gy * py) for k in range(run_h)]
                vis = 0
                for (ax, ay) in arm:
                    d = decode(ts, int(L['Orman parçaları/Orman parçaları'][ay, ax]))
                    if d and not (d[0] == 'Ground_grass.tsx' and d[1] == 212):
                        vis += 1
                if vis < 0.5 * len(arm):
                    continue
                # cep: köşeden cep yönünde 9x7 hücrenin serbest oranı
                cells = [(x + px * i, y + py * j) for i in range(9) for j in range(7)]
                okc = sum(1 for (cx, cy) in cells if 0 <= cx < W and 0 <= cy < H and free[cy, cx])
                cxm, cym = x + px * 3, y + py * 2
                if okc < 34 or MX[cym, cxm] < 4.6:
                    continue
                cands.append({'x': x, 'y': y, 'px': px, 'py': py, 'run_v': run_v, 'run_h': run_h, 'free': okc,
                              'score': okc + min(run_v, 8) + min(run_h, 8) + rng.random() * 6})
    for c in cands:
        n = math.hypot(c['px'], c['py'])
        c['dir'] = (c['px'] / n, c['py'] / n)
        c['kind'] = 'köşe'
        c['score'] += 25                      # dik iç köşeler önce
    # ---- KOYLAR: kayalığın içe kıvrıldığı yerler (görünür kaya duvarı hücreyi >200 derece sarıyor) - dik köşe şartı olmadan
    g21 = L['Orman parçaları/Orman parçaları']
    visible = np.zeros((H, W), bool)
    for yy, xx in zip(*np.nonzero(wall)):
        d = decode(ts, int(g21[yy, xx]))
        visible[yy, xx] = bool(d) and not (d[0] == 'Ground_grass.tsx' and d[1] == 212)
    vis_d = cheb(visible, 4)
    R = 5
    offs = [(dx, dy) for dy in range(-R, R + 1) for dx in range(-R, R + 1) if (dx or dy) and dx * dx + dy * dy <= R * R + 1]
    for y in range(R + 1, H - R - 1, 2):
        for x in range(R + 1, W - R - 1, 2):
            if not free[y, x] or vis_d[y, x] > 2:
                continue
            angs = []
            nf = nw = 0
            for dx, dy in offs:
                if wall[y + dy, x + dx]:
                    angs.append(math.atan2(dy, dx)); nw += 1
                elif free[y + dy, x + dx]:
                    nf += 1
            fw = nw / len(offs)
            if fw < 0.2 or fw > 0.6 or nf < 0.4 * len(offs):
                continue
            angs.sort()
            gaps = [(angs[(i + 1) % len(angs)] - angs[i]) % (2 * math.pi) for i in range(len(angs))]
            gi = max(range(len(gaps)), key=lambda i: gaps[i])
            if 2 * math.pi - gaps[gi] < math.radians(200):
                continue
            # iki (ya da daha çok) ayrı açıklık = GEÇİT/rampa (iki yanı duvar), koy DEĞİL (3. tur: 6/7/16 böyle dar geçitlere oturmuştu)
            if sum(1 for g_ in gaps if g_ >= math.radians(40)) >= 2:
                continue
            mid = angs[gi] + gaps[gi] / 2
            dvec = (math.cos(mid), math.sin(mid))
            cxm, cym = int(round(x + dvec[0] * 3)), int(round(y + dvec[1] * 3))
            if not (0 <= cxm < W and 0 <= cym < H) or MX[cym, cxm] < 4.6:
                continue
            cands.append({'x': x, 'y': y, 'px': 1 if dvec[0] >= 0 else -1, 'py': 1 if dvec[1] >= 0 else -1, 'run_v': 4, 'run_h': 4,
                          'free': nf, 'dir': dvec, 'kind': 'koy', 'score': nf * 0.5 + (2 * math.pi - gaps[gi]) * 4 + rng.random() * 6})
    cands.sort(key=lambda c: -c['score'])
    chosen = []
    for c in cands:
        if any(max(abs(c['x'] - o['x']), abs(c['y'] - o['y'])) < MIN_GAP for o in chosen):
            continue
        chosen.append(c)
        if len(chosen) >= N_PATCHES * 3:
            break
    return dict(root=root, ts=ts, L=L, LO=LO, wall=wall, free=free, protect=protect, cands=cands, chosen=chosen, rng=rng, lane_block=lane_block,
                brush_free=free & ~ledge_line)


def patch_general(c, free, wall, rng, size='orta'):
    """köşe ya da koy: açık yöne (dir) doğru, duvara paralel uzanan elips çalılık; duvara 3 px'ten fazla yaklaşmaz; kenarlar tırtıklı"""
    dx, dy = c['dir']
    tx, ty = -dy, dx                                  # duvara paralel eksen
    (rx0, rx1), (ry0, ry1), _minpx = SIZES[size]
    rx = rng.uniform(rx0, rx1) * T                    # paralel yarıçap
    ry = rng.uniform(ry0, ry1) * T                    # açık yöne yarıçap
    cx0 = (c['x'] + 0.5) * T + dx * ry * 0.55
    cy0 = (c['y'] + 0.5) * T + dy * ry * 0.55
    ph1, ph2 = rng.uniform(0, 6.28), rng.uniform(0, 6.28)
    r_cells = 10
    cells = set()
    for j in range(-r_cells, r_cells + 1):
        for i in range(-r_cells, r_cells + 1):
            qx, qy = c['x'] + i, c['y'] + j
            if 0 <= qx < W and 0 <= qy < H and free[qy, qx]:
                cells.add((qx, qy))
    # yalnız köşe hücresine bağlı serbest hücreler (duvarın / yamaç kenarının öbür yanına taşmasın)
    if (c['x'], c['y']) not in cells:
        return None
    keep, st = {(c['x'], c['y'])}, [(c['x'], c['y'])]
    while st:
        ax, ay = st.pop()
        for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (ax + ox, ay + oy)
            if n in cells and n not in keep and (n[0] - c['x']) ** 2 + (n[1] - c['y']) ** 2 <= 81:
                keep.add(n); st.append(n)
    cells = keep
    xs = [q[0] for q in cells]; ys = [q[1] for q in cells]
    x0, x1 = min(xs) - 1, max(xs) + 1
    y0, y1 = min(ys) - 2, max(ys)
    cw, ch = (x1 - x0 + 1) * T, (y1 - y0 + 1) * T
    mask = np.zeros((ch, cw), bool)
    for yy in range(ch):
        for xx in range(cw):
            wx, wy = x0 * T + xx + 0.5, y0 * T + yy + 0.5
            cell = (int(wx // T), int(wy // T))
            if cell not in cells:
                continue
            u = (wx - cx0) * tx + (wy - cy0) * ty
            v = (wx - cx0) * dx + (wy - cy0) * dy
            ang = math.atan2(v / ry, u / rx)
            wob = 1.0 + 0.07 * math.sin(5 * ang + ph1) + 0.05 * math.sin(9 * ang + ph2)
            if (u / rx) ** 2 + (v / ry) ** 2 > wob * wob:
                continue
            # duvar hücresine 3 px'ten yakın piksel yok
            lx, ly = wx - cell[0] * T, wy - cell[1] * T
            near = ((lx < 3 and wall[cell[1], cell[0] - 1]) or (lx > T - 3 and wall[cell[1], cell[0] + 1])
                    or (ly < 3 and wall[cell[1] - 1, cell[0]]) or (ly > T - 3 and wall[cell[1] + 1, cell[0]]))
            if near:
                continue
            mask[yy, xx] = True
    dist = np.zeros(mask.shape, np.int32)
    cur = mask.copy()
    for k in range(1, 7):
        p_ = np.pad(cur, 1, constant_values=False)
        er = cur & p_[:-2, 1:-1] & p_[2:, 1:-1] & p_[1:-1, :-2] & p_[1:-1, 2:]
        dist[cur & ~er] = k
        cur = er
    dist[cur] = 7
    yy_, xx_ = np.mgrid[0:mask.shape[0], 0:mask.shape[1]]
    nz = (np.sin(xx_ * 0.45 + ph1) + np.sin(yy_ * 0.6 + xx_ * 0.2 + ph2) + np.sin(xx_ * 0.17 - yy_ * 0.31 + ph1 * 2)) / 3.0
    mask &= dist > (2.0 + 2.6 * nz)
    if not mask.any():
        return None
    # tuvali maskeye göre kırp (boş kenar hücreleri at; üstte 2 hücre uç payı kalır)
    rows = np.nonzero(mask.any(axis=1))[0]; colsx = np.nonzero(mask.any(axis=0))[0]
    cy_top = max(0, rows.min() // T - 2); cy_bot = rows.max() // T
    cx_l = max(0, colsx.min() // T - 1); cx_r = min(mask.shape[1] // T - 1, colsx.max() // T + 1)
    mask = mask[cy_top * T:(cy_bot + 1) * T, cx_l * T:(cx_r + 1) * T]
    x0 = int(x0 + cx_l); y0 = int(y0 + cy_top)
    ground_cells = sorted({(int((x0 * T + xx) // T), int((y0 * T + yy) // T)) for yy, xx in zip(*np.nonzero(mask))})
    return dict(x0=x0, y0=y0, w=int(mask.shape[1] // T), h=int(mask.shape[0] // T), mask=mask, ground=ground_cells)


def patch_for(c, free, rng):
    """köşeyi saran çeyrek-elips çalılık: hücre maskesi + tuval (karo hizalı) + px maskesi"""
    px, py = c['px'], c['py']
    long_h = c['run_h'] >= c['run_v']
    rx = rng.uniform(6.2, 8.4) if long_h else rng.uniform(4.2, 5.4)
    ry = rng.uniform(4.0, 5.2) if long_h else rng.uniform(6.0, 7.8)
    ox = c['x'] * T if px > 0 else (c['x'] + 1) * T
    oy = c['y'] * T if py > 0 else (c['y'] + 1) * T
    ph1, ph2 = rng.uniform(0, 6.28), rng.uniform(0, 6.28)
    cells = set()
    for j in range(0, 10):
        for i in range(0, 11):
            cx, cy = c['x'] + px * i, c['y'] + py * j
            if 0 <= cx < W and 0 <= cy < H and free[cy, cx]:
                cells.add((cx, cy))
    # tuval: hücre kutusu + üstte 2 hücre (yaprak uçları), yanlarda 1 hücre
    xs = [cc[0] for cc in cells]; ys = [cc[1] for cc in cells]
    if not xs:
        return None
    x0, x1 = min(xs) - 1, max(xs) + 1
    y0, y1 = min(ys) - 2, max(ys)
    cw, ch = (x1 - x0 + 1) * T, (y1 - y0 + 1) * T
    mask = np.zeros((ch, cw), bool)
    for yy in range(ch):
        for xx in range(cw):
            wx, wy = x0 * T + xx + 0.5, y0 * T + yy + 0.5
            cell = (int(wx // T), int(wy // T))
            if cell not in cells:
                continue
            u = (wx - ox) * px
            v = (wy - oy) * py
            if u < 0 or v < 0:
                continue
            ang = math.atan2(v, u)
            wob = 1.0 + 0.07 * math.sin(5 * ang + ph1) + 0.05 * math.sin(9 * ang + ph2)
            if (u / (rx * T)) ** 2 + (v / (ry * T)) ** 2 <= wob * wob:
                # duvara bitişik ilk 3 px boş (tutam tabanı duvarın içine girmesin)
                if u < 3 or v < 3:
                    continue
                mask[yy, xx] = True
    # TIRTIKLI KENAR: kutucuk sınırındaki düz kesimler doğal görünsün diye kenara yakın pikseller gürültüyle kemirilir
    dist = np.zeros(mask.shape, np.int32)
    cur = mask.copy()
    for k in range(1, 7):
        p_ = np.pad(cur, 1, constant_values=False)
        er = cur & p_[:-2, 1:-1] & p_[2:, 1:-1] & p_[1:-1, :-2] & p_[1:-1, 2:]
        dist[cur & ~er] = k
        cur = er
    dist[cur] = 7
    yy, xx = np.mgrid[0:mask.shape[0], 0:mask.shape[1]]
    nz = (np.sin(xx * 0.45 + ph1) + np.sin(yy * 0.6 + xx * 0.2 + ph2) + np.sin(xx * 0.17 - yy * 0.31 + ph1 * 2)) / 3.0
    mask &= dist > (2.0 + 2.6 * nz)
    ground_cells = sorted({(int((x0 * T + xx) // T), int((y0 * T + yy) // T)) for yy, xx in zip(*np.nonzero(mask))})
    return dict(x0=x0, y0=y0, w=x1 - x0 + 1, h=y1 - y0 + 1, mask=mask, ground=ground_cells)


def main_build():
    B = build()
    root, ts, L, LO, free, protect, rng = B['root'], B['ts'], B['L'], B['LO'], B['free'], B['protect'], B['rng']
    print('köşe adayı:', len(B['cands']), '| aralıklı seçilebilir:', len(B['chosen']))
    layer_new = np.zeros((H, W), np.int64)
    tiles = []                   # benzersiz karo görüntüleri (bytes -> index)
    tile_index = {}
    patches = []
    used = np.zeros((H, W), bool)
    used_ground = np.zeros((H, W), bool)
    lane_rejects = []
    for c in B['chosen']:
        if len(patches) >= N_PATCHES:
            break
        # boyut sınıfı (çoğu küçük); sığmazsa ya da yol testini geçemezse bir küçüğü denenir
        r = rng.random()
        acc = 0.0
        want = 'küçük'
        for nm, wgt in SIZE_WEIGHTS:
            acc += wgt
            if r <= acc:
                want = nm
                break
        order = ['büyük', 'orta', 'küçük']
        p = None
        for size in order[order.index(want):]:
            q = patch_general(c, B['brush_free'], B['wall'], random.Random(rng.randrange(1 << 30)), size)
            if q is None or q['mask'].sum() < SIZES[size][2]:
                continue
            if not lane_ok(B['lane_block'] | used_ground, q['ground']):
                lane_rejects.append((c['x'], c['y'], size))
                continue
            p = q
            p['size'] = size
            break
        if p is None:
            continue
        canvas_cells = [(p['x0'] + i, p['y0'] + j) for j in range(p['h']) for i in range(p['w'])]
        if any(used[cy, cx] for cx, cy in canvas_cells if 0 <= cx < W and 0 <= cy < H):
            continue
        if any(not (0 <= cx < W and 0 <= cy < H) for cx, cy in canvas_cells):
            continue
        br = GB.Brush(STYLE, p['mask'], SEED + len(patches) * 17, pad_top=0, pad_x=0)
        img = np.array(br.render())
        # karolar
        cells_here = {}
        for j in range(p['h']):
            for i in range(p['w']):
                t = img[j * T:(j + 1) * T, i * T:(i + 1) * T]
                if t[..., 3].max() == 0:
                    continue
                cx, cy = p['x0'] + i, p['y0'] + j
                if protect[cy, cx]:
                    cells_here = None
                    break
                cells_here[(cx, cy)] = t
            if cells_here is None:
                break
        if not cells_here:
            continue
        # çalılık KABUL edildikten sonra karolar atlasa yazılır (reddedilen köşelerin karoları atlası şişirmesin)
        for (cx, cy), t in cells_here.items():
            key = t.tobytes()
            if key not in tile_index:
                tile_index[key] = len(tiles)
                tiles.append(t)
            layer_new[cy, cx] = FIRSTGID + tile_index[key]
            used[cy, cx] = True
        for (gx, gy) in p['ground']:
            used_ground[gy, gx] = True
        patches.append({'corner': [c['x'], c['y']], 'kind': c.get('kind', 'köşe'), 'size': p['size'], 'dir': [round(c['dir'][0], 3), round(c['dir'][1], 3)], 'canvas': [p['x0'], p['y0'], p['w'], p['h']],
                        'ground_cells': [list(g) for g in p['ground']],
                        'ground_px_bbox': [int(p['x0'] * T + np.nonzero(p['mask'])[1].min()), int(p['y0'] * T + np.nonzero(p['mask'])[0].min()),
                                           int(p['x0'] * T + np.nonzero(p['mask'])[1].max()), int(p['y0'] * T + np.nonzero(p['mask'])[0].max())],
                        'tiles': len(cells_here)})
    print('yerleşen çalılık:', len(patches), '| benzersiz karo:', len(tiles), '| hücre:', int((layer_new != 0).sum()))
    from collections import Counter
    print('boyutlar:', dict(Counter(p_['size'] for p_ in patches)), '| yol testinden dönen deneme:', len(lane_rejects))
    # ---- kendi süslerimi kaldır (çalılığın kapladığı hücrelere değen bütün damga)
    removed = {}
    targets = ['Shader Eklenecek/Ağaç 0', 'Shader Eklenecek/Ağaç 1', 'Shader Eklenecek/Ağaç 2', 'Shader Eklenecek/Çalılar1', 'Shader Eklenecek/Çalılar',
               'Shader Eklenecek/Animasyonsuz çalılar', 'Shader Eklenecek/Çiçekler 1']
    newL = {k: L[k].copy() for k in targets}
    for k in targets:
        n = 0
        for grp in groups_new(ts, L[k], LO[k]):
            if any(used[y, x] for (y, x) in grp):
                for (y, x) in grp:
                    newL[k][y, x] = 0
                n += 1
        removed[k.split('/')[1]] = n
    print('kaldırılan kendi süslerim (damga):', removed)
    # ---- atlas + tsx
    cols = 16
    rows = (len(tiles) + cols - 1) // cols
    atlas = np.zeros((rows * T, cols * T, 4), np.uint8)
    for i, t in enumerate(tiles):
        r, cc = divmod(i, cols)
        atlas[r * T:(r + 1) * T, cc * T:(cc + 1) * T] = t
    Image.fromarray(atlas, 'RGBA').save(os.path.join(PROJECT, 'harita', PNG_NAME))
    tsx = ('<?xml version="1.0" encoding="UTF-8"?>\r\n'
           f'<tileset version="1.10" tiledversion="1.12.2" name="saklanma_calilik" tilewidth="16" tileheight="16" tilecount="{len(tiles)}" columns="{cols}">\r\n'
           f' <image source="{PNG_NAME}" width="{cols * T}" height="{rows * T}"/>\r\n'
           '</tileset>\r\n')
    open(os.path.join(PROJECT, 'harita', TSX_NAME), 'w', encoding='utf-8', newline='').write(tsx)
    # ---- TMX metni: tileset satırı + yeni katman (Ağaç 0'ın önüne) + nextlayerid + değişen süs katmanları
    txt = open(SRC, encoding='utf-8', newline='').read()
    assert TSX_NAME not in txt, 'tileset zaten ekli'
    last_ts = list(re.finditer(r' <tileset firstgid="\d+" source="[^"]+"/>\r\n', txt))[-1]
    txt = txt[:last_ts.end()] + f' <tileset firstgid="{FIRSTGID}" source="{TSX_NAME}"/>\r\n' + txt[last_ts.end():]
    m = re.search(r'nextlayerid="(\d+)"', txt)
    lid = int(m.group(1))
    txt = txt[:m.start()] + f'nextlayerid="{lid + 1}"' + txt[m.end():]

    def fmt(g):
        return '\r\n' + ',\r\n'.join(','.join(str(int(v)) for v in g[y]) for y in range(H)) + '\r\n'

    def span(t, name):
        mm = re.search(r'<layer id="\d+" name="' + re.escape(name) + r'"[^>]*>\s*<data encoding="csv">', t)
        assert mm, name
        s = mm.end()
        return s, t.index('</data>', s)
    for k in targets:
        name = k.split('/')[1]
        s, e = span(txt, name)
        assert txt[s:e] == fmt(L[k]), 'CSV biçimi tutmuyor: ' + name
        txt = txt[:s] + fmt(newL[k]) + txt[e:]
    anchor = re.search(r'  <layer id="\d+" name="Ağaç 0"', txt)
    block = (f'  <layer id="{lid}" name="{LAYER_NAME}" width="256" height="256">\r\n   <data encoding="csv">' + fmt(layer_new) + '</data>\r\n  </layer>\r\n')
    txt = txt[:anchor.start()] + block + txt[anchor.start():]
    open(OUT_TMX, 'w', encoding='utf-8', newline='').write(txt)
    json.dump({'style': STYLE, 'layer': LAYER_NAME, 'tileset': TSX_NAME, 'firstgid': FIRSTGID, 'patches': patches},
              open(os.path.join(OUT, 'saklanma_alanlari.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print('yazıldı:', OUT_TMX, '| kaynak md5', md5(SRC))
    return patches


def previews(patches):
    """her çalılık için önce/sonra (gerçek harita çizimi, x3)"""
    root_a, ts_a = load(SRC)
    root_b, ts_b = load(OUT_TMX)
    tiles = []
    for p in patches:
        x0, y0, w, h = p['canvas']
        reg = (max(0, x0 - 6), max(0, y0 - 5), min(W, x0 + w + 6), min(H, y0 + h + 5))
        a = render(root_a, ts_a, region=reg).convert('RGB')
        b = render(root_b, ts_b, region=reg).convert('RGB')
        both = Image.new('RGB', (a.width * 2 + 6, a.height), (20, 20, 20))
        both.paste(a, (0, 0)); both.paste(b, (a.width + 6, 0))
        tiles.append(both.resize((both.width * 2, both.height * 2), Image.NEAREST))
    colw = max(t.width for t in tiles)
    sheet = Image.new('RGB', (colw * 2 + 10, sum(t.height + 8 for t in tiles[::2]) + 8), (20, 20, 20))
    y = 0
    for i in range(0, len(tiles), 2):
        sheet.paste(tiles[i], (0, y))
        if i + 1 < len(tiles):
            sheet.paste(tiles[i + 1], (colw + 10, y))
        y += max(tiles[i].height, tiles[i + 1].height if i + 1 < len(tiles) else 0) + 8
    sheet.save(os.path.join(OUT, 'calilik_once_sonra.png'))
    full = render(root_b, ts_b).convert('RGB').resize((1024, 1024), Image.LANCZOS)
    d = ImageDraw.Draw(full)
    for i, p in enumerate(patches):
        x0, y0, w, h = p['canvas']
        d.rectangle((x0 * 4 - 3, y0 * 4 - 3, (x0 + w) * 4 + 3, (y0 + h) * 4 + 3), outline=(255, 60, 200), width=3)
        d.text((x0 * 4, y0 * 4 - 16), str(i + 1), fill=(255, 255, 255))
    full.save(os.path.join(OUT, 'calilik_harita.png'))


def replace_patches(remove_ids):
    """SADECE verilen numaralı çalılıkları (saklanma_alanlari.json sırası, 1'den) kaldırır ve yerlerine aynı kurallarla yenilerini koyar; diğerleri
    karo karo AYNEN kalır. Kaynak: CANLI Harita.tmx (uygulama yine --apply <md5> ile). Atlas son katmandan yeniden kurulur (kullanılmayan karo kalmaz)."""
    B = build()                                   # arazi maskeleri, özgün nesneler, yol engelleri, adaylar (çalılık-öncesi yedekten)
    ts, LO, free, protect, rng = B['ts'], B['LO'], B['free'], B['protect'], random.Random(SEED + 999)
    root_l, ts_l = load(LIVE)
    L = {'/'.join(p): grid(l) for p, l in layers(root_l)}
    meta = json.load(open(os.path.join(OUT, 'saklanma_alanlari.json'), encoding='utf-8'))
    old = meta['patches']
    cur = L['Shader Eklenecek/' + LAYER_NAME].copy()
    atlas_old = np.array(Image.open(os.path.join(PROJECT, 'harita', PNG_NAME)).convert('RGBA'))
    cols_old = atlas_old.shape[1] // T

    def old_tile(gid):
        i = int(gid) - FIRSTGID
        r, cc = divmod(i, cols_old)
        return atlas_old[r * T:(r + 1) * T, cc * T:(cc + 1) * T]
    keep = [p for i, p in enumerate(old, 1) if i not in remove_ids]
    removed_sites = [p['corner'] for i, p in enumerate(old, 1) if i in remove_ids]
    for i, p in enumerate(old, 1):
        if i in remove_ids:
            x0, y0, w, h = p['canvas']
            cur[y0:y0 + h, x0:x0 + w] = 0
    cells_img = {(int(x), int(y)): old_tile(cur[y, x]) for y, x in zip(*np.nonzero(cur))}
    used = cur != 0
    used_ground = np.zeros((H, W), bool)
    for p in keep:
        for gx, gy in p['ground_cells']:
            used_ground[gy, gx] = True
    added = []
    rejects = 0
    gap = int(os.environ.get('CALILIK_GAP', MIN_GAP))
    for c in B['cands']:
        if len(added) >= len(remove_ids):
            break
        sites = [p['corner'] for p in keep] + [p['corner'] for p in added]
        if any(max(abs(c['x'] - sx), abs(c['y'] - sy)) < gap for sx, sy in sites):
            continue
        if any(max(abs(c['x'] - sx), abs(c['y'] - sy)) < 8 for sx, sy in removed_sites):
            continue
        r = rng.random(); acc = 0.0; want = 'küçük'
        for nm, wgt in SIZE_WEIGHTS:
            acc += wgt
            if r <= acc:
                want = nm
                break
        order = ['büyük', 'orta', 'küçük']
        p = None
        for size in order[order.index(want):]:
            q = patch_general(c, B['brush_free'], B['wall'], random.Random(rng.randrange(1 << 30)), size)
            if q is None or q['mask'].sum() < SIZES[size][2]:
                continue
            if not lane_ok(B['lane_block'] | used_ground, q['ground']):
                rejects += 1
                continue
            p = q; p['size'] = size
            break
        if p is None:
            continue
        canvas = [(p['x0'] + i, p['y0'] + j) for j in range(p['h']) for i in range(p['w'])]
        if any(not (0 <= cx < W and 0 <= cy < H) or used[cy, cx] for cx, cy in canvas):
            continue
        img = np.array(GB.Brush(STYLE, p['mask'], SEED + 5000 + len(added) * 17, pad_top=0, pad_x=0).render())
        here = {}
        bad = False
        for j in range(p['h']):
            for i in range(p['w']):
                t = img[j * T:(j + 1) * T, i * T:(i + 1) * T]
                if t[..., 3].max() == 0:
                    continue
                cx, cy = p['x0'] + i, p['y0'] + j
                if protect[cy, cx]:
                    bad = True
                    break
                here[(cx, cy)] = t
            if bad:
                break
        if bad or not here:
            continue
        for (cx, cy), t in here.items():
            cells_img[(cx, cy)] = t
            used[cy, cx] = True
        for gx, gy in p['ground']:
            used_ground[gy, gx] = True
        mk = np.nonzero(p['mask'])
        added.append({'corner': [c['x'], c['y']], 'kind': c.get('kind', 'köşe'), 'size': p['size'],
                      'dir': [round(c['dir'][0], 3), round(c['dir'][1], 3)], 'canvas': [p['x0'], p['y0'], p['w'], p['h']],
                      'ground_cells': [list(g) for g in p['ground']],
                      'ground_px_bbox': [int(p['x0'] * T + mk[1].min()), int(p['y0'] * T + mk[0].min()), int(p['x0'] * T + mk[1].max()), int(p['y0'] * T + mk[0].max())],
                      'tiles': len(here)})
    print('kaldırılan:', sorted(remove_ids), '| eklenen:', len(added), [(a['kind'], a['size'], a['corner']) for a in added], '| yol testinden dönen:', rejects)
    # yeni çalılıkların altındaki BENİM süslerim (canlı katmanda olup özgünde olmayan damgalar)
    newly = np.zeros((H, W), bool)
    for a in added:
        x0, y0, w, h = a['canvas']
        for (cx, cy) in cells_img:
            if x0 <= cx < x0 + w and y0 <= cy < y0 + h:
                newly[cy, cx] = True
    targets = ['Shader Eklenecek/Ağaç 0', 'Shader Eklenecek/Ağaç 1', 'Shader Eklenecek/Ağaç 2', 'Shader Eklenecek/Çalılar1', 'Shader Eklenecek/Çalılar',
               'Shader Eklenecek/Animasyonsuz çalılar', 'Shader Eklenecek/Çiçekler 1']
    newL = {k: L[k].copy() for k in targets}
    removed = {}
    for k in targets:
        n = 0
        for grp in groups_new(ts_l, L[k], LO[k]):
            if any(newly[y, x] for (y, x) in grp):
                for (y, x) in grp:
                    newL[k][y, x] = 0
                n += 1
        removed[k.split('/')[1]] = n
    print('kaldırılan kendi süslerim (damga):', removed)
    # atlası son katmandan yeniden kur
    tiles, index, layer_new = [], {}, np.zeros((H, W), np.int64)
    for (cx, cy) in sorted(cells_img, key=lambda q: (q[1], q[0])):
        t = cells_img[(cx, cy)]
        key = t.tobytes()
        if key not in index:
            index[key] = len(tiles)
            tiles.append(t)
        layer_new[cy, cx] = FIRSTGID + index[key]
    cols = 16
    rows = (len(tiles) + cols - 1) // cols
    atlas = np.zeros((rows * T, cols * T, 4), np.uint8)
    for i, t in enumerate(tiles):
        r, cc = divmod(i, cols)
        atlas[r * T:(r + 1) * T, cc * T:(cc + 1) * T] = t
    txt = open(LIVE, encoding='utf-8', newline='').read()

    def fmt(g):
        return '\r\n' + ',\r\n'.join(','.join(str(int(v)) for v in g[y]) for y in range(H)) + '\r\n'

    def span(t, name):
        mm = re.search(r'<layer id="\d+" name="' + re.escape(name) + r'"[^>]*>\s*<data encoding="csv">', t)
        assert mm, name
        s = mm.end()
        return s, t.index('</data>', s)
    for k in targets:
        s, e = span(txt, k.split('/')[1])
        assert txt[s:e] == fmt(L[k]), 'CSV biçimi tutmuyor: ' + k
        txt = txt[:s] + fmt(newL[k]) + txt[e:]
    s, e = span(txt, LAYER_NAME)
    assert txt[s:e] == fmt(L['Shader Eklenecek/' + LAYER_NAME])
    txt = txt[:s] + fmt(layer_new) + txt[e:]
    open(OUT_TMX, 'w', encoding='utf-8', newline='').write(txt)
    Image.fromarray(atlas, 'RGBA').save(os.path.join(OUT, 'yeni_' + PNG_NAME))   # canlıya --apply ile kopyalanır
    tsx = ('<?xml version="1.0" encoding="UTF-8"?>\r\n'
           f'<tileset version="1.10" tiledversion="1.12.2" name="saklanma_calilik" tilewidth="16" tileheight="16" tilecount="{len(tiles)}" columns="{cols}">\r\n'
           f' <image source="{PNG_NAME}" width="{cols * T}" height="{rows * T}"/>\r\n'
           '</tileset>\r\n')
    open(os.path.join(OUT, 'yeni_' + TSX_NAME), 'w', encoding='utf-8', newline='').write(tsx)
    meta['patches'] = keep + added
    json.dump(meta, open(os.path.join(OUT, 'saklanma_alanlari.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print('yazıldı:', OUT_TMX, '| atlas', len(tiles), 'karo | kaynak md5', md5(LIVE))
    return keep, added


if __name__ == '__main__':
    if len(sys.argv) >= 3 and sys.argv[1] == '--replace':
        ids = {int(v) for v in sys.argv[2].split(',')}
        keep, added = replace_patches(ids)
        sys.exit(0)
    if len(sys.argv) >= 3 and sys.argv[1] == '--apply':
        exp = sys.argv[2]
        if md5(LIVE) != exp:
            print('DURDUM: canlı Harita.tmx beklenen sürüm değil, hiçbir şey yazılmadı', md5(LIVE)); sys.exit(3)
        data = open(OUT_TMX, 'rb').read()
        tmp = LIVE + '.tmp_calilik'
        open(tmp, 'wb').write(data)
        if md5(LIVE) != exp:
            os.remove(tmp); print('DURDUM: yazma anında değişti'); sys.exit(3)
        os.replace(tmp, LIVE)
        # --replace kipi atlası yeniden kurduysa TMX ile birlikte canlıya alınır (karo numaraları ona göre)
        for nm in (PNG_NAME, TSX_NAME):
            src_new = os.path.join(OUT, 'yeni_' + nm)
            if os.path.exists(src_new):
                os.replace(src_new, os.path.join(PROJECT, 'harita', nm))
                print('  güncellendi: harita/' + nm)
        print('uygulandı', md5(LIVE))
    else:
        ps = main_build()
        previews(ps)
