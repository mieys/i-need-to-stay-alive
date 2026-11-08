# ÖRNEKTEN TEMA HARİTALARI (madde 447; madde 445'in yerine - kullanıcı: "çok sıkıcı, özen gösterilmemiş, bazı şeyler ters konmuş, örneklerden
# ilham aldığına emin misin?"): Kemik Katakombu / Kızıl Lağım / Boynuz Mağaraları artık setlerin KENDİ örnek haritalarından kırpılan odalardan
# (ornek_parca.Piece: ressamın katmanları aynen, kenar mühürlü, kapı ağızlı) kurulur. Akış:
#   1) yerleşim: doğuş parçası ortada, kalanlar kümelenerek (aralarında koridor payı), aynı oda en çok `adet` kez (yarısı ayna);
#   2) bağlantı: parça çiftleri arasında kapı ağzı -> kapı ağzı koridorları (Kruskal + döngü), A* (dönüş cezası, parça payı yasak);
#      kullanılmayan ağız mühürlenir (ressam duvar boyar);
#   3) boyama: temanın ressamı (paint_walls_34 tuck / Et paint_walls) koridorları + mühür şeritlerini boyar; parça içi örneğin karoları;
#   4) katmanlar: örnek katmanları çakışma zinciriyle paketlenir ('Taban n' karakter altı, 'Eşya*' derinlikli; Et'te su karoları 'Kan*');
#   5) etkileşimler: doğuş, sakinler (parça başına), sandık, kaynak, sunak (örnekteki heykel/totemin önü), saklanma, kapı, tuzak, avcı,
#      ışıklar (örnekteki meşale/mum/ateş/lav karolarından).
# Çalıştır: python tools/zindan/gen_ornek_haritalar.py <kemik|et|boynuz|hepsi> [--write]  (önizleme tools/zindan/out/<id>_*.png)
# --write sonrası: Godot --headless --path . --import ; Godot --headless --path . -s res://tools/zindan/bake_zindan.gd -- <id>
import heapq
import math
import os
import random
import sys
import time

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import zindan_core as Z  # noqa: E402
import zindan_paint as P  # noqa: E402
import gen_kadim_derinlikler as G  # noqa: E402
import gen_tema_haritalari as T  # noqa: E402
import gen_kemik_mahzeni as KM  # noqa: E402
import gen_et_kuyusu as EK  # noqa: E402
import gen_boynuzlu_kapi as BK  # noqa: E402
import ornek_parca as OP  # noqa: E402
import ornek_tmx as OT  # noqa: E402

RL = os.path.join(Z.ART, 'Zindan Tileseti (Roguelike)', 'Tiled_files')
KZ = os.path.join(Z.ART, 'Kanalizasyon Tileseti', 'Tiled_files')
HP = os.path.join(Z.ART, 'Hapishane Assetleri', 'Tiled_files')
D1 = os.path.join(Z.ART, 'Piksel Zindan Assetleri', 'Tiled_files')
MG = os.path.join(Z.ART, 'Magara Tileseti', 'Tiled_files')
PM = os.path.join(Z.ART, 'Parlayan Magara Tileseti', 'Tiled_files')

CANVAS = 214            # en büyük harita (madde 445: Kadim'in %70'i); parçalar bitince kullanılan alana kırpılır
GAP = (12, 17)           # komşu parçalar arası boşluk (iki parça payı + koridor + duvarları)
MARGIN = 3              # koridor parçaya bu kadar yaklaşamaz (kapı ağzı saplaması hariç)
STUB = MARGIN + 1
CW_MAX = 5
PAINT_LAYERS = ('Kan', 'Zemin', 'Zemin ayrıntı', 'Zemin desen', 'Zemin süsü', 'Duvar')

# ışık veren örnek sayfaları (ad parçası -> (renk, yarıçap)); renk None = temanın rengi
LIGHT_SHEETS = (('statue_fire', (None, 150)), ('torch', (None, 96)), ('candle', (None, 64)), ('fire_anim', (P.AMBER, 104)),
                ('lava', ((1.0, 0.45, 0.15), 120)), ('bubbles', ((1.0, 0.45, 0.15), 90)), ('totem', (P.CYAN, 150)),
                ('shinies', ((0.55, 0.9, 1.0), 64)), ('wisps', ((0.6, 1.0, 0.85), 72)), ('flasks', ((0.5, 1.0, 0.6), 70)))

TEMALAR = {
    'kemik': {
        'id': 'kemik_katakombu', 'ad': 'Kemik Katakombu', 'seed': 5101, 'renk': P.CYAN,
        'ornek': {'d3': os.path.join(RL, 'Dungeon3.tmx')},
        # (anahtar, örnek, kırpma (x0, y0, x1, y1), ad, sakin profili, adet)
        'parca': [
            ('tabut', 'd3', (10, 12, 31, 26), 'Tabut Salonu', 'oda', 2),
            ('kripta', 'd3', (0, 0, 40, 31), 'Ana Kripta', 'kalp', 1),
            ('sunak', 'd3', (11, 0, 38, 16), 'Sunak Salonu', 'kalp', 2),
            ('lahit', 'd3', (0, 3, 13, 21), 'Lahit Odası', 'lahit', 3),
            ('heykel', 'd3', (27, 13, 40, 26), 'Heykel Odası', 'sutun', 3),
            ('batihavuz', 'd3', (0, 16, 17, 31), 'Batı Havuzu', 'kemik', 3),
            ('havuz', 'd3', (11, 19, 31, 31), 'Havuz Odası', 'kemik', 3),
            ('sarnic', 'd3', (23, 19, 40, 31), 'Doğu Sarnıcı', 'lahit', 3),
            ('revak', 'd3', (11, 6, 38, 21), 'Revak', 'sutun', 2),
        ],
        'dogus': 'tabut', 'kapi': (('parmaklik', 'diken'), True), 'tuzak': 'diken', 'avci': 'kemik_bekcisi', 'kaynak': 'ruh_kandili',
        'sunak': ('statue_fire', 'Kemik Sunağı'), 'sakla': [(KM.OPEN_EMPTY_V[0], 'Açık Lahit', 'Eşya alt', KM.OPEN_EMPTY_V[0][1][3] - 1, 0)],
    },
    'et': {
        'id': 'kizil_lagim', 'ad': 'Kızıl Lağım', 'seed': 5203, 'renk': P.AMBER,
        'ornek': {'in': os.path.join(KZ, 'Inside.tmx'), 'out': os.path.join(KZ, 'Outside.tmx'), 'hp': os.path.join(HP, 'Interior.tmx')},
        'parca': [
            ('kanal', 'in', (3, 3, 26, 18), 'Lağım Kemeri', 'kanal', 4),
            ('sol', 'in', (3, 6, 14, 18), 'Batı Rıhtımı', 'oda', 4),
            ('sag', 'in', (15, 6, 26, 18), 'Doğu Rıhtımı', 'oda', 4),
            ('cikis', 'out', (0, 4, 17, 16), 'Lağım Ağzı', 'kanal', 4),
            ('hapis', 'hp', (2, 2, 22, 14), 'Hücre Koğuşu', 'hucre', 3),
        ],
        'dogus': 'kanal', 'kapi': (('kafes', 'barikat'), False), 'tuzak': 'giyotin', 'avci': 'kuyu_kasabi', 'kaynak': 'et_kesesi',
        'sunak': (None, 'Simyacı'), 'sakla': [(EK.ROOT_PODS[1], 'Et Kökü', 'Eşya üst', 2, 0), (EK.ROOT_PODS[3], 'Et Kökü', 'Eşya üst', 2, 0)], 'kan': True, 'kopru': ('in', 'out'),
    },
    'boynuz': {
        'id': 'boynuz_magaralari', 'ad': 'Boynuz Mağaraları', 'seed': 5307, 'renk': P.CYAN,
        'ornek': {'d1': os.path.join(D1, 'Dungeon1.tmx'), 'cv': os.path.join(MG, 'Cave.tmx'), 'gc': os.path.join(PM, 'Glowing_cave.tmx')},
        'parca': [
            ('tapinak', 'd1', (0, 0, 38, 28), 'Boynuz Tapınağı', 'salon', 1),
            ('magara', 'cv', (0, 0, 39, 26), 'Lav Mağarası', 'lav', 1),
            ('isik', 'gc', (0, 0, 38, 25), 'Işıyan Koru', 'magara', 1),
            ('d1kuzey', 'd1', (0, 0, 20, 14), 'Kuzey Odaları', 'oda', 2),
            ('d1dogu', 'd1', (18, 0, 38, 14), 'Ateş Odası', 'salon', 2),
            ('d1guney', 'd1', (0, 13, 20, 28), 'Sarnıç Odaları', 'oda', 2),
            ('d1havuz', 'd1', (18, 9, 38, 28), 'Havuz Salonu', 'salon', 2),
            ('lavbati', 'cv', (0, 0, 20, 26), 'Kristal Yarık', 'kristal', 2),
            ('lavdogu', 'cv', (19, 0, 39, 26), 'Kafatası Mağarası', 'lav', 2),
            ('mantar', 'gc', (0, 0, 20, 25), 'Mantar Kovuğu', 'magara', 2),
            ('totem', 'gc', (18, 0, 38, 25), 'Totem Mağarası', 'kalp', 2),
        ],
        'dogus': 'tapinak', 'kapi': (('demir', 'kristal'), True), 'tuzak': 'diken', 'avci': 'boynuzlu_bekci', 'kaynak': 'isik_kristali',
        'sunak': ('totem', 'Boynuz Totemi'), 'sakla': [(BK.MUSH_HOUSE[1], 'Mantar Kovuğu', 'Eşya', 2, 1)],
    },
}


# ================================================================================================ yerleşim
class Placed:
    def __init__(self, idx, piece, x, y, key, prof):
        self.idx, self.piece, self.x, self.y, self.key, self.prof = idx, piece, x, y, key, prof
        self.used = set()  # bağlanan kapı ağzı indeksleri

    @property
    def rect(self):
        return (self.x, self.y, self.x + self.piece.w, self.y + self.piece.h)

    def stub(self, pi):
        """Kapı ağzının dışarıdaki saplaması: (hücreler, uç hücre, yön)."""
        side, a, n = self.piece.ports[pi][:3]
        x0, y0, x1, y1 = self.rect
        cells = []
        if side == 'n':
            for d in range(1, STUB + 1):
                cells += [(x0 + a + i, y0 - d) for i in range(n)]
            end, dv = (x0 + a + n // 2, y0 - STUB), (0, -1)
        elif side == 's':
            for d in range(STUB):
                cells += [(x0 + a + i, y1 + d) for i in range(n)]
            end, dv = (x0 + a + n // 2, y1 + STUB - 1), (0, 1)
        elif side == 'w':
            for d in range(1, STUB + 1):
                cells += [(x0 - d, y0 + a + i) for i in range(n)]
            end, dv = (x0 - STUB, y0 + a + n // 2), (-1, 0)
        else:
            for d in range(STUB):
                cells += [(x1 + d, y0 + a + i) for i in range(n)]
            end, dv = (x1 + STUB - 1, y0 + a + n // 2), (1, 0)
        return cells, end, dv


def expand_instances(cfg):
    out = []
    for (key, smp, rect, name, prof, count) in cfg['parca']:
        for k in range(count):
            out.append((key, smp, rect, name, prof, k % 2 == 1))
    return out


OPP = {'n': 's', 's': 'n', 'w': 'e', 'e': 'w'}


def port_span(p, i):
    """Kapı ağzının harita koordinatında kenar boyunca aralığı [a, b) ve kenar çizgisi."""
    side, a, n = p.piece.ports[i][:3]
    x0, y0, x1, y1 = p.rect
    if side in 'ns':
        return x0 + a, x0 + a + n, (y0 if side == 'n' else y1)
    return y0 + a, y0 + a + n, (x0 if side == 'w' else x1)


def rect_hit(r, rects, pad):
    x0, y0, x1, y1 = r
    return any(x0 < q[2] + pad and q[0] < x1 + pad and y0 < q[3] + pad and q[1] < y1 + pad for q in rects)


def grow(cfg, infos, rng, log):
    """Kapıdan kapıya büyüme: açık bir kapı ağzının karşısına (zıt kenar ağzı hizalı) yeni parça, arada kısa DÜZ koridor.
    Dönüş: (parçalar, koridorlar [(a, i, b, j, dikdörtgen)])."""
    pool = expand_instances(cfg)
    spawn_i = next(i for i, it in enumerate(pool) if it[0] == cfg['dogus'] and not it[5])
    first = pool.pop(spawn_i)
    rng.shuffle(pool)
    cache = {}

    def piece_of(it):
        k = (it[0], it[5])
        if k not in cache:
            cache[k] = it
        return OP.Piece(infos[it[1]], it[2], it[3], it[4], it[5])

    p0 = Placed(0, piece_of(first), 0, 0, first[0], first[4])
    p0.x, p0.y = (CANVAS - p0.piece.w) // 2, (CANVAS - p0.piece.h) // 2
    placed = [p0]
    links = []
    open_ports = [(0, i) for i in range(len(p0.piece.ports))]
    dead = []
    cx = cy = CANVAS / 2.0
    while open_ports and pool:
        # merkeze yakın açık ağız önce (derli toplu harita)
        open_ports.sort(key=lambda pi: _port_dist(placed[pi[0]], pi[1], cx, cy) + rng.random() * 25)
        pidx, i = open_ports.pop(0)
        p = placed[pidx]
        side = p.piece.ports[i][0]
        a0, a1, edge = port_span(p, i)
        done = False
        tries = list(range(len(pool)))
        rng.shuffle(tries)
        for ti in tries[:14]:
            it = pool[ti]
            pc = piece_of(it)
            cands = [j for j, pt in enumerate(pc.ports) if pt[0] == OPP[side]]
            rng.shuffle(cands)
            for j in cands:
                _, b, m = pc.ports[j][:3]
                g = rng.randint(3, 7)
                # ağız merkezleri hizalı
                shift = (a0 + a1) // 2 - (b + m // 2)
                if side == 'n':
                    x, y = shift, edge - g - pc.h
                elif side == 's':
                    x, y = shift, edge + g
                elif side == 'w':
                    x, y = edge - g - pc.w, shift
                else:
                    x, y = edge + g, shift
                r = (x, y, x + pc.w, y + pc.h)
                if x < 4 or y < 7 or r[2] > CANVAS - 4 or r[3] > CANVAS - 4:
                    continue
                if rect_hit(r, [q.rect for q in placed if q is not p], 5) or rect_hit(r, [p.rect], 1):
                    continue
                q = Placed(len(placed), pc, x, y, it[0], it[4])
                c0, c1, _ = port_span(q, j)
                lo, hi = max(a0, c0), min(a1, c1)
                if hi - lo < 3:
                    continue
                if hi - lo > CW_MAX:
                    lo += (hi - lo - CW_MAX) // 2
                    hi = lo + CW_MAX
                if side == 'n':
                    cr = (lo, y + pc.h, hi, edge)
                elif side == 's':
                    cr = (lo, edge, hi, y)
                elif side == 'w':
                    cr = (x + pc.w, lo, edge, hi)
                else:
                    cr = (edge, lo, x, hi)
                if rect_hit(cr, [o.rect for o in placed if o is not p], 2):
                    continue
                placed.append(q)
                p.used.add(i)
                q.used.add(j)
                links.append((p.idx, i, q.idx, j, cr))
                open_ports += [(q.idx, k) for k in range(len(pc.ports)) if k != j]
                pool.pop(ti)
                done = True
                break
            if done:
                break
        if not done:
            dead.append((pidx, i))
    log.append('büyüme: %d parça, %d düz koridor, kalan havuz %d' % (len(placed), len(links), len(pool)))
    return placed, links


def _port_dist(p, i, cx, cy):
    a0, a1, edge = port_span(p, i)
    side = p.piece.ports[i][0]
    px, py = ((a0 + a1) / 2.0, edge) if side in 'ns' else (edge, (a0 + a1) / 2.0)
    return math.hypot(px - cx, py - cy)


# ================================================================================================ döngü koridorları (A*)
class Router:
    def __init__(self, lay, placed):
        self.lay = lay
        self.H, self.W = lay.t.shape
        blk = np.zeros((self.H, self.W), bool)
        for p in placed:
            x0, y0, x1, y1 = p.rect
            blk[max(0, y0 - MARGIN):y1 + MARGIN, max(0, x0 - MARGIN):x1 + MARGIN] = True
        blk[:3, :] = blk[-3:, :] = True
        blk[:, :3] = blk[:, -3:] = True
        blk[:6, :] = True  # üst kenarda yüz payı
        # var olan düz koridorların çevresi (paralel geçip ince duvar bırakmasın; kesişme serbest değil - döngü kendi yolunu bulur)
        c = lay.corr_id >= 0
        near = c.copy()
        for d in range(1, 4):
            near[d:, :] |= c[:-d, :]
            near[:-d, :] |= c[d:, :]
            near[:, d:] |= c[:, :-d]
            near[:, :-d] |= c[:, d:]
        blk |= near
        self.blk = blk
        self.corr = np.zeros((self.H, self.W), bool)
        self._free = {}

    def free(self, w):
        if w not in self._free:
            b = self.blk.astype(np.int32)
            c = np.zeros((self.H + 1, self.W + 1), np.int32)
            c[1:, 1:] = b.cumsum(0).cumsum(1)
            f = np.zeros((self.H, self.W), bool)
            hh, ww = self.H - w + 1, self.W - w + 1
            s = c[w:w + hh, w:w + ww] - c[:hh, w:w + ww] - c[w:w + hh, :ww] + c[:hh, :ww]
            f[:hh, :ww] = s == 0
            self._free[w] = f
        return self._free[w]

    def block(self, cells, pad=3):
        for (x, y) in cells:
            self.blk[max(0, y - pad):y + pad + 1, max(0, x - pad):x + pad + 1] = True
        self._free = {}

    def route(self, a, b, w):
        free = self.free(w)
        if not all(0 <= c[1] < self.H and 0 <= c[0] < self.W and free[c[1], c[0]] for c in (a, b)):
            return None
        dirs = ((1, 0), (-1, 0), (0, 1), (0, -1))
        start = (a[0], a[1], -1)
        dist = {start: 0}
        prev = {}
        pq = [(abs(a[0] - b[0]) + abs(a[1] - b[1]), 0, start)]
        goal = None
        n = 0
        while pq:
            f, g, s = heapq.heappop(pq)
            if dist.get(s, 1e18) < g:
                continue
            x, y, d = s
            if (x, y) == b:
                goal = s
                break
            n += 1
            if n > 300000:
                break
            for k, (dx, dy) in enumerate(dirs):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < self.W and 0 <= ny < self.H) or not free[ny, nx]:
                    continue
                c = g + 1 + (8 if d not in (-1, k) else 0)
                ns = (nx, ny, k)
                if c < dist.get(ns, 1e18):
                    dist[ns] = c
                    prev[ns] = s
                    heapq.heappush(pq, (c + abs(nx - b[0]) + abs(ny - b[1]), c, ns))
        if goal is None:
            return None
        path = []
        s = goal
        while s in prev:
            path.append((s[0], s[1]))
            s = prev[s]
        path.append((a[0], a[1]))
        return path[::-1]


def brush_at(end, dv, w):
    """Saplama ucundan dışarı doğru fırça sol üstü (fırça uç hücreyi kapsar)."""
    ex, ey = end
    if dv[1] != 0:
        return (ex - w // 2, ey - (w - 1) if dv[1] < 0 else ey)
    return (ex - (w - 1) if dv[0] < 0 else ex, ey - w // 2)


def carve_links(lay, placed, links):
    for e, (a, i, b, j, (x0, y0, x1, y1)) in enumerate(links):
        lay.t[y0:y1, x0:x1] = Z.F
        lay.corr_id[y0:y1, x0:x1] = e
        lay.edges.append((a, b, e))
    return len(links)


def add_loops(lay, placed, rng, log, e0):
    """Kullanılmayan ağızlar arasında A* döngü koridorları: önce yalnız TEK bağı olan (yaprak) parçalar (köprüsüz grafik: tek kapı ya da
    tıkanma kimseyi hapsetmez), sonra kısa ek döngüler."""
    rt = Router(lay, placed)
    e = e0
    made = 0
    free_ports = [(p, i) for p in placed for i in range(len(p.piece.ports)) if i not in p.used]

    def cand_pairs(only_leaf):
        out = []
        for ai in range(len(free_ports)):
            p, i = free_ports[ai]
            for bi in range(ai + 1, len(free_ports)):
                q, j = free_ports[bi]
                if p is q or i in p.used or j in q.used:
                    continue
                if only_leaf and len(p.used) > 1 and len(q.used) > 1:
                    continue
                _, ea, da = p.stub(i)
                _, eb, db = q.stub(j)
                d = abs(ea[0] - eb[0]) + abs(ea[1] - eb[1])
                vx, vy = eb[0] - ea[0], eb[1] - ea[1]
                if da[0] * vx + da[1] * vy < 0 or db[0] * -vx + db[1] * -vy < 0:
                    d += 40
                if d <= (90 if only_leaf else 40):
                    out.append((d, p, i, q, j))
        out.sort(key=lambda v: v[0])
        return out

    for only_leaf, limit in ((True, 99), (False, 6)):
        n_here = 0
        for (d, p, i, q, j) in cand_pairs(only_leaf):
            if n_here >= limit:
                break
            if i in p.used or j in q.used:
                continue
            if only_leaf and len(p.used) > 1 and len(q.used) > 1:
                continue
            ca, ea, da = p.stub(i)
            cb, eb, db = q.stub(j)
            w = min(p.piece.ports[i][2], q.piece.ports[j][2], CW_MAX)
            path = rt.route(brush_at(ea, da, w), brush_at(eb, db, w), w)
            if path is None:
                continue
            cells = set(ca) | set(cb)
            for (x, y) in path:
                cells.update((x + i2, y + j2) for j2 in range(w) for i2 in range(w))
            for (x, y) in cells:
                lay.t[y, x] = Z.F
                if lay.room_id[y, x] < 0:
                    lay.corr_id[y, x] = e
            rt.block(cells)
            p.used.add(i)
            q.used.add(j)
            lay.edges.append((p.idx, q.idx, e))
            e += 1
            made += 1
            n_here += 1
    # köprü kapatma: tek koridorla asılı parça zincirleri (kapı kapanınca / tıkanınca kopar) uzak taraftan yakın tarafa ikinci yol
    for _ in range(12):
        far_sets = piece_bridges(len(placed), lay.edges)
        if not far_sets:
            break
        fixed = False
        for far in far_sets:
            cands = []
            for p in placed:
                if p.idx not in far:
                    continue
                for i in range(len(p.piece.ports)):
                    if i in p.used:
                        continue
                    for q in placed:
                        if q.idx in far:
                            continue
                        for j in range(len(q.piece.ports)):
                            if j in q.used:
                                continue
                            _, ea, _ = p.stub(i)
                            _, eb, _ = q.stub(j)
                            d = abs(ea[0] - eb[0]) + abs(ea[1] - eb[1])
                            if d <= 110:
                                cands.append((d, p, i, q, j))
            cands.sort(key=lambda v: v[0])
            for (d, p, i, q, j) in cands[:8]:
                ca, ea, da = p.stub(i)
                cb, eb, db = q.stub(j)
                w = min(p.piece.ports[i][2], q.piece.ports[j][2], CW_MAX)
                path = rt.route(brush_at(ea, da, w), brush_at(eb, db, w), w)
                if path is None:
                    continue
                cells = set(ca) | set(cb)
                for (x, y) in path:
                    cells.update((x + i2, y + j2) for j2 in range(w) for i2 in range(w))
                for (x, y) in cells:
                    lay.t[y, x] = Z.F
                    if lay.room_id[y, x] < 0:
                        lay.corr_id[y, x] = e
                rt.block(cells)
                p.used.add(i)
                q.used.add(j)
                lay.edges.append((p.idx, q.idx, e))
                e += 1
                made += 1
                fixed = True
                break
            if fixed:
                break
        if not fixed:
            break
    log.append('döngü koridoru: %d, kalan köprü kümesi %d' % (made, len(piece_bridges(len(placed), lay.edges))))
    return e


def piece_bridges_one(n, edges, e0):
    """e0 koridoru kapanınca doğuştan (parça 0) kopan parça var mı."""
    adj = {}
    for (a, b, e) in edges:
        if e == e0:
            continue
        adj.setdefault(a, []).append(b)
        adj.setdefault(b, []).append(a)
    st, vis = [0], {0}
    while st:
        u = st.pop()
        for v in adj.get(u, ()):
            if v not in vis:
                vis.add(v)
                st.append(v)
    return len(vis) < n


def piece_bridges(n, edges):
    """Parça grafiğinde köprü kenarlar: her biri için doğuştan (parça 0) kopan parça kümesi (küçükten büyüğe, tekrarsız)."""
    out = []
    seen = set()
    for (a0, b0, e0) in edges:
        adj = {}
        for (a, b, e) in edges:
            if e == e0:
                continue
            adj.setdefault(a, []).append(b)
            adj.setdefault(b, []).append(a)
        st, vis = [0], {0}
        while st:
            u = st.pop()
            for v in adj.get(u, ()):
                if v not in vis:
                    vis.add(v)
                    st.append(v)
        far = frozenset(i for i in range(n) if i not in vis)
        if far and far not in seen:
            seen.add(far)
            out.append(far)
    out.sort(key=len)
    return out


# ================================================================================================ katmanlar
def pack_slots(layers):
    """[(ad, {hücre: gid})] çizim sırası -> her katmanın yuva indeksi (çakışan önceki katmanın bir üstü)."""
    slots, keys = [], []
    for i, (_, rel) in enumerate(layers):
        ks = set(rel)
        s = 0
        for k in range(i):
            if keys[k] & ks:
                s = max(s, slots[k] + 1)
        slots.append(s)
        keys.append(ks)
    return slots


def split_piece_layers(piece, kan):
    """Parçanın katmanları -> (kan, taban, derinlik) grupları [(ad, {hücre: gid})]; Et'te su karoları kan grubuna ayrılır."""
    smp = piece.info.smp
    g_kan, g_base, g_depth = [], [], []
    for role, name, rel in piece.layers:
        if role == 'depth':
            g_depth.append((name, rel))
            continue
        if kan and any(k in name.lower() for k in ('bottom', 'water')) and 'door' not in name.lower():
            # su gövdesi + su altı duvarı + su ayrıntısı katmanları kana boyanır; zemin katmanındaki kıyı karoları (platform zemini) DEĞİL
            g_kan.append((name, rel))
        else:
            g_base.append((name, rel))
    return g_kan, g_base, g_depth


class SheetMap:
    """Örnek sayfası -> birleşik banka anahtarı (aynı kaynak dosya = aynı anahtar; ressamın sayfası yeniden kullanılır)."""

    def __init__(self, mb, tema):
        self.mb, self.tema = mb, tema
        self.by_src = {}
        for k in mb.order:
            ts = mb.sets[k]
            if isinstance(ts.src, str) and not ts.src.startswith('zip:') and os.path.exists(ts.src):
                self.by_src[os.path.normcase(os.path.abspath(ts.src))] = k
        self.names = {os.path.basename(mb.sets[k].dest_rel).lower() for k in mb.order}
        self.light = {}  # banka anahtarı -> (renk, yarıçap)
        self.frames = {}  # sayfa -> {ara kare: animasyonlu karo}

    def key(self, sample_key, sh):
        src = os.path.normcase(os.path.abspath(sh.path))
        k = self.by_src.get(src)
        if k is None:
            base = os.path.basename(sh.path)
            name = '%s_%s' % (self.tema, base)
            if name.lower() in self.names:
                name = '%s_%s_%s' % (self.tema, sample_key, base)
            k = 'smp_%s_%s' % (sample_key, os.path.splitext(base)[0])
            self.mb.add(k, sh.path, name=name, img=sh.img, anims=sh.anims)
            self.names.add(name.lower())
            self.by_src[src] = k
        low = os.path.basename(sh.path).lower()
        for frag, val in LIGHT_SHEETS:
            if frag in low:
                self.light[k] = val
                break
        return k

    def gid(self, sample_key, smp, g):
        sh, lid = smp.sheet_of(g)
        if sh is None:
            return 0, None
        # animasyonun ara karesi tek başına kullanılmışsa animasyonlu karoya çevrilir (Godot'ta kare, animasyonlu karonun atlas alanını
        # kaplar; aynı yere ikinci karo kurulamıyor: "Cannot create tile ... already present", YATI'de flip_h null hatası)
        fm = self.frames.get(id(sh))
        if fm is None:
            fm = {}
            for base, frames in sh.anims.items():
                for (f, _ms) in frames:
                    if f != base:
                        fm.setdefault(f, base)
            self.frames[id(sh)] = fm
        lid = fm.get(lid, lid)
        k = self.key(sample_key, sh)
        ts = self.mb.sets[k]
        return self.mb.gid(k, lid % ts.cols, lid // ts.cols, g & (Z.FH | Z.FV | Z.FD)), k


# ================================================================================================ ana akış
def build(tema, write=False):
    cfg = TEMALAR[tema]
    t0 = time.time()
    rng = random.Random(cfg['seed'])
    T.configure(tema)  # G.* (THEMES / ID / bankalar) bu temaya
    infos = {k: OP.SampleInfo(k, p, bridges=k in cfg.get('kopru', ())) for k, p in cfg['ornek'].items()}
    log = []
    placed, links = grow(cfg, infos, rng, log)
    print('yerleşim: %d parça, %.1f sn' % (len(placed), time.time() - t0))

    lay = Z.Layout(CANVAS, CANVAS, cfg['seed'])
    lay.t[:] = Z.S
    for p in placed:
        x0, y0, x1, y1 = p.rect
        r = lay.add_room(x0, y0, p.piece.w, p.piece.h, p.prof)
        r.hall = p.piece.name
        r.theme = tema
        cls = p.piece.cls
        sub = lay.t[y0:y1, x0:x1]
        sub[cls == OP.F] = Z.F
        sub[cls == OP.O] = Z.F
        sub[cls == OP.W] = Z.W
        lay.room_id[y0:y1, x0:x1] = r.id
        lay.solid_obj[y0:y1, x0:x1][cls == OP.O] = 2
    n_edges = carve_links(lay, placed, links)
    n_edges = add_loops(lay, placed, rng, log, n_edges)
    print('bağlantı: %d koridor, %.1f sn' % (n_edges, time.time() - t0))
    # bağlanmayan kapı ağızları mühürlenir (oyulmuş ağız geri duvar olur, ressam boyar)
    keep_ids = {p.idx for p in placed}
    for p in placed:
        x0, y0, x1, y1 = p.rect
        if p.idx not in keep_ids:
            lay.t[y0:y1, x0:x1] = Z.S
            lay.room_id[y0:y1, x0:x1] = -1
            lay.solid_obj[y0:y1, x0:x1] = 0
            continue
        for i, (side, a, n, carved) in enumerate(p.piece.ports):
            if i in p.used:
                continue
            pc = p.piece
            for (cx, cy) in carved:
                pc.cls[cy, cx] = OP.S
                lay.t[y0 + cy, x0 + cx] = Z.S
            if side == 'n':
                cells = [(a + k, j) for k in range(n) for j in range(OP.SEAL_TOP)]
            elif side == 's':
                cells = [(a + k, pc.h - 1) for k in range(n)]
            elif side == 'w':
                cells = [(0, a + k) for k in range(n)]
            else:
                cells = [(pc.w - 1, a + k) for k in range(n)]
            for (cx, cy) in cells:
                pc.band[cy, cx] = True
                pc.cls[cy, cx] = OP.S
                lay.t[y0 + cy, x0 + cx] = Z.S
                for (_, _, rel) in pc.layers:
                    rel.pop((cx, cy), None)
    placed = [p for p in placed if p.idx in keep_ids]
    lay.rooms = [r for r in lay.rooms if (lay.room_id == r.id).any()]
    # koridor kalınlık düzeltmeleri yalnız parça dışında
    piece_mask = np.zeros((CANVAS, CANVAS), bool)
    for p in placed:
        x0, y0, x1, y1 = p.rect
        piece_mask[y0:y1, x0:x1] = True
    saved = lay.t[piece_mask].copy()
    lay.fix_thickness(min_v=4, min_h=2)
    G.normalize_steps(lay)
    lay.t[piece_mask] = saved
    lay.corr_id[(lay.t != Z.F) & (lay.corr_id >= 0)] = -1

    # kırpma: kullanılan alan + kenar payı
    ys, xs = np.nonzero(lay.t != Z.S)
    bx0, by0 = max(0, int(xs.min()) - 6), max(0, int(ys.min()) - 8)
    bx1, by1 = min(CANVAS, int(xs.max()) + 7), min(CANVAS, int(ys.max()) + 7)
    lay = crop_layout(lay, bx0, by0, bx1, by1)
    for p in placed:
        p.x -= bx0
        p.y -= by0
    piece_mask = piece_mask[by0:by1, bx0:bx1]
    W, H = lay.W, lay.H
    G.W, G.H = W, H
    print('harita %dx%d' % (W, H))

    # boyama: ressam her yeri boyar, parça içi (mühür şeridi hariç) örneğin karolarıyla değişir
    mb = G.make_bank()
    tb = G.ThemeBank(mb, tema)
    smap = SheetMap(mb, tema)
    view = G.View(lay, [], (lay.corr_id >= 0))
    pt = Z.TileLayers(W, H, G.ORDER)
    if tema == 'kemik':
        KM.paint_base(view, tb, pt)
    elif tema == 'boynuz':
        BK.paint_base(view, tb, pt)
    else:
        EK.paint_base(view, tb, pt, random.Random(cfg['seed'] + 5), [])
    own = np.zeros((H, W), bool)
    for p in placed:
        x0, y0, x1, y1 = p.rect
        own[y0:y1, x0:x1] |= ~p.piece.band
    for name in PAINT_LAYERS:
        pt.L[name][own] = 0

    # örnek katmanları: parça başına paketlenir, sonra birleşik yuvalar
    per = []
    n_kan = n_base = n_depth = 0
    for p in placed:
        gk, gb, gd = split_piece_layers(p.piece, cfg.get('kan', False))
        sk, sb, sd = pack_slots(gk), pack_slots(gb), pack_slots(gd)
        per.append((p, gk, sk, gb, sb, gd, sd))
        n_kan = max(n_kan, (max(sk) + 1) if sk else 0)
        n_base = max(n_base, (max(sb) + 1) if sb else 0)
        n_depth = max(n_depth, (max(sd) + 1) if sd else 0)
    kan_names = ['Kan'] + ['Kan %d' % (i + 1) for i in range(1, n_kan)]
    base_names = ['Taban %d' % (i + 1) for i in range(n_base)]
    depth_names = ['Eşya alt', 'Eşya'] + ['Eşya %d' % i for i in range(2, n_depth)]
    order = kan_names + ['Zemin', 'Zemin ayrıntı', 'Zemin desen', 'Zemin süsü', 'Duvar'] + base_names + ['Duvar süsü'] + depth_names + \
        ['Eşya üst', 'Engel']
    tl = Z.TileLayers(W, H, order)
    for name in G.ORDER:
        if name in tl.L:
            tl.L[name][:] = pt.L[name]
    lights = []
    occ_obj = np.zeros((H, W), bool)
    for (p, gk, sk, gb, sb, gd, sd) in per:
        smp = p.piece.info.smp
        skey = p.piece.info.key
        for grp, slots, names in ((gk, sk, kan_names), (gb, sb, base_names), (gd, sd, depth_names)):
            for (name, rel), s in zip(grp, slots):
                L = tl.L[names[s]]
                for (cx, cy), g in rel.items():
                    gg, k = smap.gid(skey, smp, g)
                    if gg:
                        L[p.y + cy, p.x + cx] = gg
                        if names is depth_names:
                            occ_obj[p.y + cy, p.x + cx] = True
                        if k in smap.light:
                            lights.append((p.x + cx, p.y + cy, smap.light[k]))
    print('katmanlar: kan %d, taban %d, eşya %d; %.1f sn' % (n_kan, n_base, n_depth, time.time() - t0))

    # süsleme / etkileşimler
    dz = P.Decorator(lay, tb, tl, seed=cfg['seed'], paint=None)
    dz.occ |= occ_obj
    dz.occ |= lay.solid_obj > 0
    place_lights(dz, lights, cfg['renk'])
    spawn_p = placed[0]
    sx, sy = spawn_spot(lay, dz, spawn_p)
    dz.spawn = (sx, sy)
    dz.add_obj('dogus', 'Doğuş', sx - 1, sy - 1, 3, 2)
    dz.reserve[sy - 3:sy + 3, sx - 3:sx + 4] = True
    regions = piece_regions(lay, placed)
    for (p, r) in regions:
        if p is not spawn_p:  # doğuş odasında sakin yok (oyuncu yaratığın yanında doğuyordu)
            dz.dwellers(r, p.prof)
    place_altar(dz, lay, placed, regions, cfg, tema)
    if tema == 'et':
        for (p, r) in regions:
            if p.prof == 'hucre':
                dz.npc_spot(r, 'simyaci')
                break
    rs = [r for (_, r) in regions]
    rng.shuffle(rs)
    n_res = max(10, len(rs) // 2 + 6)
    for r in rs:
        if sum(1 for o in dz.objects if o['type'] == 'kaynak') >= n_res:
            break
        resource_in(dz, r, cfg['kaynak'])
    n_chest = 0
    for i, r in enumerate(rs):
        if n_chest >= max(10, len(rs) // 2):
            break
        if dz.chest(r, elite=(i % 7 == 3)):
            n_chest += 1
    n_hide = 0
    for r in rs:
        for (spec, name, layer, rows, inset) in cfg['sakla']:
            if n_hide < max(8, len(rs) // 2) and dz.hide_spot_object(r, spec, name, layer=layer, rows=rows, inset=inset):
                n_hide += 1
    styles, narrow = cfg['kapi']
    paint_fn = make_painter(tema, lay, tb, tl, own)
    dz.paint = paint_fn
    dz.gates(max_count=12, styles=styles, ns_narrow=narrow)
    # köprü koridordaki kapı kaldırılır (kapanınca arkadaki odalar kopuyordu), en çok 7 kapı kalır
    bridge_e = set()
    for (a0, b0, e0) in lay.edges:
        if piece_bridges_one(len(placed), lay.edges, e0):
            bridge_e.add(e0)
    kept = 0
    for o in list(dz.objects):
        if o['type'] != 'kapi':
            continue
        cells = P.obj_cells(o)
        bad = any(0 <= y < lay.H and 0 <= x < lay.W and int(lay.corr_id[y, x]) in bridge_e for (x, y) in cells)
        if bad or kept >= 7:
            dz.objects.remove(o)
            for (x, y) in cells:
                if 0 <= y < lay.H and 0 <= x < lay.W:
                    dz.gate[y, x] = False
        else:
            kept += 1
    dz.traps(cfg['tuzak'], count=5)
    dz.hunter_route(cfg['avci'])
    corridor_dress(dz, tema)
    objs = dz.objects
    for o in objs:
        o.setdefault('props', {})['tema'] = tema
    P.write_engel(lay, mb, tl, dz)

    # rapor
    rep = escape(lay, dz, placed)
    counts = {}
    for o in objs:
        counts[o['type']] = counts.get(o['type'], 0) + 1
    print('parça %d, zemin %d hücre (%%%.1f), nesneler %s' % (len(placed), rep['zemin'], 100.0 * rep['zemin'] / (W * H), counts))
    print('kaçış:', rep)
    for s in log + lay.notes + dz.notes:
        print(' ', s)
    pre = cfg['id']
    os.makedirs(Z.OUT, exist_ok=True)
    Z.semantic_png(lay, objs, os.path.join(Z.OUT, pre + '_sema.png'), scale=3)
    img = Z.render(mb, tl, W, H, skip=('Engel',))
    img.resize((W * 4, H * 4), Z.Image.BOX).save(os.path.join(Z.OUT, pre + '_tam.png'))
    cx, cy = spawn_p.x + spawn_p.piece.w // 2, spawn_p.y + spawn_p.piece.h // 2
    img.crop(((cx - 45) * 16, (cy - 30) * 16, (cx + 45) * 16, (cy + 30) * 16)).save(os.path.join(Z.OUT, pre + '_merkez.png'))
    print('önizleme: %.1f sn' % (time.time() - t0))
    if write:
        mb.write_files()
        if tema == 'kemik':
            P.copy_runtime_sheets(KM.RL, cfg['id'], KM.RUNTIME_SHEETS)
        for name, src in (EK.RUNTIME_SHEETS if tema == 'et' else []) + (BK.RUNTIME_SHEETS if tema == 'boynuz' else []):
            P.copy_runtime_sheets(src, cfg['id'], [name])
        tmx = os.path.join(Z.ZROOT, cfg['id'] + '.tmx')
        Z.write_tmx(tmx, mb, tl, objs, W, H, props={'zindan': cfg['id'], 'ad': cfg['ad'], 'harita': 'alternatif'}, hidden=('Engel',))
        print('yazıldı', tmx)
    return lay, placed


def crop_layout(lay, x0, y0, x1, y1):
    nl = Z.Layout(x1 - x0, y1 - y0, 1)
    nl.rng = lay.rng
    nl.t = lay.t[y0:y1, x0:x1].copy()
    nl.room_id = lay.room_id[y0:y1, x0:x1].copy()
    nl.corr_id = lay.corr_id[y0:y1, x0:x1].copy()
    nl.solid_obj = lay.solid_obj[y0:y1, x0:x1].copy()
    nl.reserve = lay.reserve[y0:y1, x0:x1].copy()
    nl.edges = lay.edges
    nl.notes = lay.notes
    for r in lay.rooms:
        r.x -= x0
        r.y -= y0
        nl.rooms.append(r)
    return nl


def make_painter(tema, lay, tb, tl, own):
    """Kapı daraltması gibi geometri değişikliklerinde bölgeyi yeniden boyar (parça içi korunur)."""
    def paint(reg):
        x0, y0, x1, y1 = max(0, reg[0]), max(0, reg[1]), min(lay.W, reg[2]), min(lay.H, reg[3])
        tmp = Z.TileLayers(lay.W, lay.H, G.ORDER)
        view = G.View(lay, [], (lay.corr_id >= 0))
        if tema == 'et':
            EK.paint_walls(view, tb, tmp, region=(x0, y0, x1, y1))
        else:
            P.paint_walls_34(view, tb, tmp, 'wf', floor=(2, 8), region=(x0, y0, x1, y1))
        m = ~own[y0:y1, x0:x1]
        for name in ('Zemin', 'Duvar'):
            g = tl.L[name][y0:y1, x0:x1]
            g[m] = tmp.L[name][y0:y1, x0:x1][m]
    return paint


def piece_regions(lay, placed):
    """Her parçanın büyük zemin bileşenleri -> Room (sınır kutusu, kind = profil)."""
    out = []
    for p in placed:
        x0, y0, x1, y1 = p.rect
        f = (lay.t[y0:y1, x0:x1] == Z.F)
        lab = G.label(f)
        for v in np.unique(lab):
            if v <= 0:
                continue
            ys, xs = np.nonzero(lab == v)
            if len(xs) < 30:
                continue
            r = Z.Room(1000 + len(out), x0 + int(xs.min()), y0 + int(ys.min()), int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1),
                       p.prof)
            out.append((p, r))
    return out


def spawn_spot(lay, dz, p):
    x0, y0, x1, y1 = p.rect
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    best = None
    for y in range(y0 + 3, y1 - 3):
        for x in range(x0 + 3, x1 - 3):
            if (lay.t[y - 2:y + 2, x - 2:x + 3] == Z.F).all() and not lay.solid_obj[y - 2:y + 2, x - 2:x + 3].any() and \
                    not dz.occ[y - 2:y + 2, x - 2:x + 3].any():
                d = (x - cx) ** 2 + (y - cy) ** 2
                if best is None or d < best[0]:
                    best = (d, x, y)
    return (best[1], best[2]) if best else (cx, cy)


def place_lights(dz, lights, color):
    """Örnekteki ışıklı karolar: 3 hücrelik kümelere toplanır, küme başına bir ışık."""
    done = set()
    for (x, y, (col, r)) in sorted(lights, key=lambda v: (v[2][1] * -1, v[1], v[0])):
        k = (x // 3, y // 3)
        if k in done:
            continue
        done.add(k)
        dz.light((x + 0.5) * 16, (y + 0.5) * 16, col or color, r=r, energy=1.0)


def place_altar(dz, lay, placed, regions, cfg, tema):
    frag, name = cfg['sunak']
    if frag:
        # örnekteki heykel/totem: alt satırının iki altı sunak etkileşim alanı
        for p in placed:
            smp = p.piece.info.smp
            for role, lname, rel in p.piece.layers:
                cells = [(c, g) for c, g in rel.items() if frag in ((smp.sheet_of(g)[0].name if smp.sheet_of(g)[0] else '').lower())]
                if not cells:
                    continue
                xs = [c[0] for c, _ in cells]
                ys = [c[1] for c, _ in cells]
                bx, by = p.x + min(xs), p.y + max(ys) + 1
                w = max(xs) - min(xs) + 1
                if all(lay.t[by + j, bx + i] == Z.F for i in range(w) for j in range(2) if 0 <= by + j < lay.H):
                    dz.add_obj('sunak', name, bx, by, w, 2)
                    for j in range(2, 5):
                        for i in range(w):
                            if 0 <= by + j < lay.H:
                                dz.reserve[by + j, bx + i] = True
                    return
    spec = {'et': EK.ALCH_TABLES[0], 'kemik': KM.STATUE_FIRE, 'boynuz': BK.TOTEM}[tema]
    for (p, r) in sorted(regions, key=lambda pr: -pr[1].w * pr[1].h):
        n0 = len(dz.objects)
        dz.altar(r, spec, name, light=P.AMBER if tema == 'et' else P.CYAN, light_r=140)
        if any(o['type'] == 'sunak' for o in dz.objects[n0:]):
            return


def resource_in(dz, r, kind):
    spots = [(x, y) for y in range(r.y, r.y + r.h) for x in range(r.x, r.x + r.w - 1)]
    dz.rng.shuffle(spots)
    t = dz.lay.t
    for (x, y) in spots:
        if not dz.is_free(x - 1, y, 4, 1):
            continue
        if y < 2 or any(dz.occ[y - j, x + i] for i in range(2) for j in (1, 2)):
            continue
        if any(math.dist((x, y), (o['x'] // 16, o['y'] // 16)) < 8 for o in dz.objects if o['type'] == 'kaynak'):
            continue
        if not all(t[y - 1, x + i] in (Z.F, Z.S) for i in range(2)):
            continue
        if dz.solidify([(x, y), (x + 1, y)]):
            for i in range(2):
                dz.occ[y, x + i] = True
                dz.occ[y - 1, x + i] = True
            dz.add_obj('kaynak', kind, x, y - 2, 2, 3, tur=kind)
            return True
    return False


def corridor_dress(dz, tema):
    if tema == 'kemik':
        dz.corridor_dressing(KM.BONES + KM.SKULLS, density=0.010)
        dz.corridor_torches(KM.TORCH_WALL, every=14, light=P.CYAN)
    elif tema == 'et':
        dz.corridor_dressing(EK.MUSHROOMS[:6], density=0.008)
        dz.corridor_glow(EK.MUSHROOMS[:5], every=16, light=P.AMBER)
    else:
        dz.corridor_glow(BK.BLUE_SHARDS, every=14, light=P.CYAN)


def escape(lay, dz, placed):
    p = lay.passable()
    lab = G.label(p)
    sx, sy = dz.spawn

    def at_spawn(lb):
        sub = lb[sy - 2:sy + 3, sx - 2:sx + 3]
        return np.bincount(sub[sub > 0]).argmax() if (sub > 0).any() else 0

    good = at_spawn(lab)
    unreach = int((p & (lab != good)).sum())
    # tek koridor kapanınca kopan parça (köprü)
    bridges = []
    eids = sorted({e for (_, _, e) in lay.edges})
    for e in eids:
        m = p & ~(lay.corr_id == e)
        lab2 = G.label(m)
        g2 = at_spawn(lab2)
        for q in placed:
            x0, y0, x1, y1 = q.rect
            sub = m[y0:y1, x0:x1]
            if sub.any() and not (lab2[y0:y1, x0:x1][sub] == g2).any():
                bridges.append((e, q.piece.name))
                break
    return {'zemin': int(p.sum()), 'ulasilmaz': unreach, 'kopru_koridor': len(bridges), 'kopru_ornek': bridges[:4]}


def main():
    write = '--write' in sys.argv
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    temalar = list(TEMALAR) if (not args or args[0] == 'hepsi') else args
    for tema in temalar:
        print('=====', tema, TEMALAR[tema]['ad'])
        build(tema, write)


if __name__ == '__main__':
    main()
