# ZİNDANLAR (madde 373) ortak çekirdek: yerleşim (oda grafiği + döngüler), kalınlık düzeltmeleri, KAÇIŞ doğrulaması,
# tileset kaydı (paket sayfaları harita/zindan/<paket>/ altına kopyalanır, .tsx yazılır), TMX yazıcı ve önizleme çizicisi.
#
# Hücre türleri (t ızgarası): S duvar/kaya (geçilmez + görüşü keser), F zemin, W su (geçilmez, görüşü kesmez), L lav/uçurum (aynı).
# Oyun tarafı (scripts/dungeon/*) TMX'in "Engel" katmanını okur: 1 = duvar (hareket + görüş + mermi), 2 = engel (yalnız hareket).
import math
import os
import random
import shutil
from collections import deque

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..', '..'))
ART = os.path.normpath(os.path.join(PROJECT, '..', 'Harita içerikleri'))
HARITA = os.path.join(PROJECT, 'harita')
ZROOT = os.path.join(HARITA, 'zindan')
OUT = os.path.join(HERE, 'out')

S, F, W, L = 0, 1, 2, 3
CORRIDOR_W = 5  # koridor genişliği (hücre): 3'te kovalamada "çok dar" geliyordu (madde 376); kapı yerlerinde payandayla daralır
FH, FV, FD = 0x80000000, 0x40000000, 0x20000000
CELL = 16


# ------------------------------------------------------------------------------------------------ yerleşim
class Room:
    def __init__(self, rid, x, y, w, h, kind='oda'):
        self.id, self.x, self.y, self.w, self.h, self.kind = rid, x, y, w, h, kind
        self.tags = set()
        self.cells = None  # organik odalarda carve sonrası hücre listesi

    def center(self):
        return (self.x + self.w // 2, self.y + self.h // 2)

    def rect(self):
        return (self.x, self.y, self.w, self.h)

    def inside(self, x, y, pad=0):
        return self.x - pad <= x < self.x + self.w + pad and self.y - pad <= y < self.y + self.h + pad


class Layout:
    def __init__(self, w, h, seed):
        self.W, self.H = w, h
        self.rng = random.Random(seed)
        self.t = np.zeros((h, w), np.uint8)
        self.room_id = np.full((h, w), -1, np.int16)
        self.corr_id = np.full((h, w), -1, np.int16)
        self.rooms = []
        self.edges = []  # (a, b, eid)
        self.reserve = np.zeros((h, w), bool)  # yol payı: engelli süs konmaz
        self.solid_obj = np.zeros((h, w), np.uint8)  # 2 = nesne engeli (yalnız hareket)
        self.notes = []

    # ---- odalar
    def fits(self, x, y, w, h, mx, my, border=3):
        if x < border or y < border + 3 or x + w > self.W - border or y + h > self.H - border:
            return False
        for r in self.rooms:
            if x < r.x + r.w + mx and r.x < x + w + mx and y < r.y + r.h + my and r.y < y + h + my:
                return False
        return True

    def add_room(self, x, y, w, h, kind='oda'):
        r = Room(len(self.rooms), x, y, w, h, kind)
        self.rooms.append(r)
        return r

    def scatter_rooms(self, specs, mx=4, my=6, tries=4000, region=None):
        """specs: [(adet, (wmin, wmax), (hmin, hmax), tür)] - rastgele yerleştirir (çakışma + kenar payı)."""
        rng = self.rng
        x0, y0, x1, y1 = region or (0, 0, self.W, self.H)
        for count, (wa, wb), (ha, hb), kind in specs:
            placed = 0
            for _ in range(tries):
                if placed >= count:
                    break
                w, h = rng.randint(wa, wb), rng.randint(ha, hb)
                x, y = rng.randint(x0, max(x0, x1 - w)), rng.randint(y0, max(y0, y1 - h))
                if self.fits(x, y, w, h, mx, my):
                    self.add_room(x, y, w, h, kind)
                    placed += 1
            if placed < count:
                self.notes.append('uyarı: %s için %d/%d oda' % (kind, placed, count))

    # ---- grafik
    def build_graph(self, k=3, loop_ratio=0.45, max_len=60):
        n = len(self.rooms)
        cs = [r.center() for r in self.rooms]
        cand = set()
        for i in range(n):
            d = sorted(((math.dist(cs[i], cs[j]), j) for j in range(n) if j != i))
            for dist, j in d[:k]:
                if dist <= max_len or len(cand) == 0:
                    cand.add((min(i, j), max(i, j)))
        cand = sorted(cand, key=lambda e: math.dist(cs[e[0]], cs[e[1]]))
        parent = list(range(n))

        def find(a):
            while parent[a] != a:
                parent[a] = parent[parent[a]]
                a = parent[a]
            return a
        mst, extra = [], []
        for a, b in cand:
            ra, rb = find(a), find(b)
            if ra != rb:
                parent[ra] = rb
                mst.append((a, b))
            else:
                extra.append((a, b))
        # bağlı değilse en yakın çiftleri ekle
        for i in range(n):
            for j in range(n):
                if find(i) != find(j):
                    parent[find(i)] = find(j)
                    mst.append((min(i, j), max(i, j)))
        want = int(round(len(mst) * loop_ratio))
        chosen = list(mst) + extra[:want]
        self.edges = [(a, b, i) for i, (a, b) in enumerate(chosen)]
        self.ensure_bridgeless()

    def _bridges(self):
        n = len(self.rooms)
        adj = [[] for _ in range(n)]
        for a, b, e in self.edges:
            adj[a].append((b, e))
            adj[b].append((a, e))
        tin, low, seen = [0] * n, [0] * n, [False] * n
        out, timer = [], [0]

        def dfs(v, pe):
            seen[v] = True
            timer[0] += 1
            tin[v] = low[v] = timer[0]
            for to, e in adj[v]:
                if e == pe:
                    continue
                if seen[to]:
                    low[v] = min(low[v], tin[to])
                else:
                    dfs(to, e)
                    low[v] = min(low[v], low[to])
                    if low[to] > tin[v]:
                        out.append(e)
        import sys
        sys.setrecursionlimit(10000)
        for v in range(n):
            if not seen[v]:
                dfs(v, -1)
        return out

    def ensure_bridgeless(self):
        """Her köprü kenarı için (koparsa grafiği bölen koridor) küçük taraftaki bir odadan karşı tarafa ek koridor: tek bir koridoru
        tutan kovalayıcı hiçbir odayı çıkışlardan ayıramaz (KAÇIŞ kuralı, kullanıcı: "her zaman bir yol olmalı kurtuluş için")."""
        cs = [r.center() for r in self.rooms]
        for _ in range(60):
            br = self._bridges()
            if not br:
                return
            e = br[0]
            a, b = [(x, y) for x, y, i in self.edges if i == e][0]
            # a tarafı: e olmadan a'dan ulaşılanlar
            side = self._reach(a, skip=e)
            other = [i for i in range(len(self.rooms)) if i not in side]
            best = None
            for i in side:
                for j in other:
                    if (i, j) in ((a, b), (b, a)):
                        continue
                    d = math.dist(cs[i], cs[j])
                    if best is None or d < best[0]:
                        best = (d, i, j)
            if best is None:
                return
            nid = max(i for _, _, i in self.edges) + 1
            self.edges.append((min(best[1], best[2]), max(best[1], best[2]), nid))

    def _reach(self, s, skip=-1):
        adj = {}
        for a, b, e in self.edges:
            if e == skip:
                continue
            adj.setdefault(a, []).append(b)
            adj.setdefault(b, []).append(a)
        seen, q = {s}, [s]
        while q:
            v = q.pop()
            for to in adj.get(v, []):
                if to not in seen:
                    seen.add(to)
                    q.append(to)
        return seen

    # ---- oyma
    def carve_rect(self, x, y, w, h, val=F, rid=None):
        x0, y0 = max(1, x), max(1, y)
        x1, y1 = min(self.W - 1, x + w), min(self.H - 1, y + h)
        self.t[y0:y1, x0:x1] = val
        if rid is not None:
            self.room_id[y0:y1, x0:x1] = rid

    def carve_rooms(self):
        for r in self.rooms:
            if r.cells is None:
                self.carve_rect(r.x, r.y, r.w, r.h, F, r.id)

    def carve_corridor(self, a, b, eid, width=3, horiz_first=None):
        ra, rb = self.rooms[a], self.rooms[b]
        (ax, ay), (bx, by) = ra.center(), rb.center()
        if horiz_first is None:
            horiz_first = self._prefer_horizontal(ax, ay, bx, by, width)
        half = width // 2
        cells = []
        if horiz_first:
            cells += self._seg(ax, ay, bx, ay, width)
            cells += self._seg(bx, ay, bx, by, width)
        else:
            cells += self._seg(ax, ay, ax, by, width)
            cells += self._seg(ax, by, bx, by, width)
        for (x, y) in cells:
            if 1 <= x < self.W - 1 and 3 <= y < self.H - 1:
                if self.t[y, x] == S:
                    self.t[y, x] = F
                if self.room_id[y, x] < 0:
                    self.corr_id[y, x] = eid
        del half

    def _seg(self, x0, y0, x1, y1, width):
        out = []
        lo = -(width // 2)
        hi = lo + width
        if y0 == y1:
            for x in range(min(x0, x1) + lo, max(x0, x1) + hi):
                for dy in range(lo, hi):
                    out.append((x, y0 + dy))
        else:
            for y in range(min(y0, y1) + lo, max(y0, y1) + hi):
                for dx in range(lo, hi):
                    out.append((x0 + dx, y))
        return out

    def _prefer_horizontal(self, ax, ay, bx, by, width):
        # İki L yolundan, başka zeminlere 4 satırdan yakın geçen (ince duvar üretecek) hücresi az olanı seç.
        def cost(cells):
            c = 0
            for (x, y) in cells:
                if not (0 <= x < self.W and 0 <= y < self.H):
                    c += 5
                    continue
                if self.t[y, x] == S:
                    for dy in (-5, -4, 4, 5):
                        yy = y + dy
                        if 0 <= yy < self.H and self.t[yy, x] != S:
                            c += 1
            return c
        h = self._seg(ax, ay, bx, ay, width) + self._seg(bx, ay, bx, by, width)
        v = self._seg(ax, ay, ax, by, width) + self._seg(ax, by, bx, by, width)
        ch, cv = cost(h), cost(v)
        if ch == cv:
            return self.rng.random() < 0.5
        return ch < cv

    def carve_all_corridors(self, width=3, widths=None, astar=True):
        for a, b, e in self.edges:
            w = widths(e) if widths else width
            if not astar or not self.carve_corridor_astar(a, b, e, w):
                self.carve_corridor(a, b, e, w)

    def _near_mask(self, skip_rooms, width, gap_v=4, gap_h=2):
        """Mevcut zeminin (skip_rooms dışındaki) koridor ekseni için 'çok yakın' bölgesi: buradan geçen koridor ince duvar bırakır."""
        fl = (self.t != S) & ~np.isin(self.room_id, list(skip_rooms))
        rv, rh = width // 2 + gap_v, width // 2 + gap_h
        m = np.zeros_like(fl)
        ys, xs = np.nonzero(fl)
        H, W = self.H, self.W
        # ayrık genişletme: dikdörtgen çekirdek (rv dikey, rh yatay)
        acc = np.zeros((H + 2 * rv + 1, W + 2 * rh + 1), np.int32)
        for y, x in zip(ys, xs):
            acc[y, x] += 1
            acc[y, x + 2 * rh + 1] -= 1
            acc[y + 2 * rv + 1, x] -= 1
            acc[y + 2 * rv + 1, x + 2 * rh + 1] += 1
        acc = acc.cumsum(0).cumsum(1)
        m = acc[rv:rv + H, rh:rh + W] > 0
        return m

    def carve_corridor_astar(self, a, b, eid, width=3, turn_cost=4, near_cost=14, room_cost=60):
        """Koridor eksenini A* ile bulur: başka odaların içi pahalı, diğer zeminlere yakın (ince duvar) pahalı, dönüş cezalı ->
        okunaklı, birbirine kaynamayan dolambaçlı koridorlar. Bulamazsa False (çağıran L koridora düşer)."""
        import heapq
        ra, rb = self.rooms[a], self.rooms[b]
        sx, sy = ra.center()
        gx, gy = rb.center()
        near = self._near_mask({a, b}, width)
        other_room = (self.room_id >= 0) & (self.room_id != a) & (self.room_id != b)
        half = width // 2
        H, W = self.H, self.W
        cost = np.ones((H, W), np.float32)
        cost[near] += near_cost
        # eksen hücresinin çevresinde (koridor bandı) başka oda varsa pahalı
        band = np.zeros_like(other_room)
        for dy in range(-half - 1, half + 2):
            for dx in range(-half - 1, half + 2):
                band |= np.roll(np.roll(other_room, dy, 0), dx, 1)
        cost[band] += room_cost
        inside_ab = (self.room_id == a) | (self.room_id == b)
        cost[inside_ab] = 1.0
        lo, hi = half + 2, 4 + half
        dirs = ((1, 0), (-1, 0), (0, 1), (0, -1))
        start = (sx, sy, -1)
        g = {start: 0.0}
        prev = {}
        pq = [(abs(gx - sx) + abs(gy - sy), 0.0, start)]
        found = None
        it = 0
        while pq:
            f, gc, st = heapq.heappop(pq)
            if gc > g.get(st, 1e18):
                continue
            x, y, d = st
            if (x, y) == (gx, gy):
                found = st
                break
            it += 1
            if it > 120000:
                break
            for di, (dx, dy) in enumerate(dirs):
                nx, ny = x + dx, y + dy
                if not (lo <= nx < W - lo and hi <= ny < H - lo):
                    continue
                nc = gc + float(cost[ny, nx]) + (turn_cost if d >= 0 and di != d else 0.0)
                ns = (nx, ny, di)
                if nc < g.get(ns, 1e18):
                    g[ns] = nc
                    prev[ns] = st
                    heapq.heappush(pq, (nc + abs(gx - nx) + abs(gy - ny), nc, ns))
        if found is None:
            return False
        path = []
        st = found
        while st in prev:
            path.append((st[0], st[1]))
            st = prev[st]
        lo_o = -(width // 2)
        for (x, y) in path:
            for dy in range(lo_o, lo_o + width):
                for dx in range(lo_o, lo_o + width):
                    xx, yy = x + dx, y + dy
                    if 1 <= xx < W - 1 and 3 <= yy < H - 1:
                        if self.t[yy, xx] == S:
                            self.t[yy, xx] = F
                        if self.room_id[yy, xx] < 0:
                            self.corr_id[yy, xx] = eid
        return True

    # ---- organik (mağara)
    def carve_blob(self, r, rough=0.35, val=F):
        """Odayı gürültülü elips olarak oyar (mağara)."""
        rng = self.rng
        cx, cy = r.x + r.w / 2.0, r.y + r.h / 2.0
        rx, ry = r.w / 2.0, r.h / 2.0
        k = [rng.uniform(0, math.tau) for _ in range(4)]
        amp = [rng.uniform(0.05, rough) for _ in range(4)]
        cells = []
        for y in range(r.y - 2, r.y + r.h + 2):
            for x in range(r.x - 2, r.x + r.w + 2):
                if not (2 <= x < self.W - 2 and 4 <= y < self.H - 2):
                    continue
                dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                ang = math.atan2(dy, dx)
                rad = 1.0 + sum(a * math.sin((i + 2) * ang + k[i]) for i, a in enumerate(amp)) * 0.5
                if dx * dx + dy * dy <= rad * rad:
                    self.t[y, x] = val
                    self.room_id[y, x] = r.id
                    cells.append((x, y))
        r.cells = cells

    def carve_tunnel(self, a, b, eid, width=3, wiggle=0.35):
        ra, rb = self.rooms[a], self.rooms[b]
        (ax, ay), (bx, by) = ra.center(), rb.center()
        rng = self.rng
        n = max(2, int(math.dist((ax, ay), (bx, by)) / 2))
        nx, ny = -(by - ay), (bx - ax)
        ln = math.hypot(nx, ny) or 1.0
        nx, ny = nx / ln, ny / ln
        ph, fr = rng.uniform(0, math.tau), rng.uniform(1.0, 2.5)
        amp = math.dist((ax, ay), (bx, by)) * wiggle * 0.25
        for i in range(n + 1):
            u = i / n
            off = math.sin(u * math.pi * fr + ph) * math.sin(u * math.pi) * amp
            px, py = ax + (bx - ax) * u + nx * off, ay + (by - ay) * u + ny * off
            rr = width / 2.0 + rng.uniform(-0.2, 0.5)
            for y in range(int(py - rr - 1), int(py + rr + 2)):
                for x in range(int(px - rr - 1), int(px + rr + 2)):
                    if (x + 0.5 - px) ** 2 + (y + 0.5 - py) ** 2 <= rr * rr and 2 <= x < self.W - 2 and 4 <= y < self.H - 2:
                        if self.t[y, x] == S:
                            self.t[y, x] = F
                        if self.room_id[y, x] < 0:
                            self.corr_id[y, x] = eid

    def smooth_cave(self, passes=2):
        for _ in range(passes):
            t = self.t
            fl = (t == F).astype(np.int8)
            pad = np.pad(fl, 1)
            cnt = sum(pad[1 + dy:1 + dy + self.H, 1 + dx:1 + dx + self.W] for dy in (-1, 0, 1) for dx in (-1, 0, 1)) - fl
            new = t.copy()
            new[(t == S) & (cnt >= 6)] = F
            new[(t == F) & (cnt <= 2) & (self.room_id < 0) & (self.corr_id < 0)] = S
            self.t = new

    # ---- kalınlık düzeltmeleri (3/4 bakış: kuzey duvar yüzü için zeminin üstünde en az min_v satır duvar; yanlarda en az min_h)
    def fix_thickness(self, min_v=4, min_h=2, rounds=8, keep=None):
        for _ in range(rounds):
            changed = 0
            t = self.t
            for x in range(self.W):
                y = 0
                while y < self.H:
                    if t[y, x] == S and y > 0 and t[y - 1, x] != S:
                        y2 = y
                        while y2 < self.H and t[y2, x] == S:
                            y2 += 1
                        if y2 < self.H and (y2 - y) < min_v and not self._kept(keep, x, y, y2, True):
                            t[y:y2, x] = F
                            changed += y2 - y
                        y = y2
                    else:
                        y += 1
            for y in range(self.H):
                x = 0
                while x < self.W:
                    if t[y, x] == S and x > 0 and t[y, x - 1] != S:
                        x2 = x
                        while x2 < self.W and t[y, x2] == S:
                            x2 += 1
                        if x2 < self.W and (x2 - x) < min_h and not self._kept(keep, y, x, x2, False):
                            t[y, x:x2] = F
                            changed += x2 - x
                        x = x2
                    else:
                        x += 1
            # çapraz değme: [[F,S],[S,F]] -> birini zemin yap
            for y in range(1, self.H - 1):
                for x in range(1, self.W - 1):
                    a, b, c, d = t[y, x], t[y, x + 1], t[y + 1, x], t[y + 1, x + 1]
                    if a != S and d != S and b == S and c == S:
                        t[y, x + 1] = F
                        changed += 1
                    elif b != S and c != S and a == S and d == S:
                        t[y, x] = F
                        changed += 1
            # küçük duvar adacıkları -> zemin
            changed += self._fill_small_islands(10)
            if not changed:
                return

    def _kept(self, keep, a, b0, b1, vertical):
        return False if keep is None else keep(a, b0, b1, vertical)

    def _fill_small_islands(self, max_size):
        t = self.t
        seen = np.zeros(t.shape, bool)
        changed = 0
        for y in range(self.H):
            for x in range(self.W):
                if t[y, x] != S or seen[y, x]:
                    continue
                comp, q, edge = [], deque([(x, y)]), False
                seen[y, x] = True
                while q:
                    cx, cy = q.popleft()
                    comp.append((cx, cy))
                    if cx in (0, self.W - 1) or cy in (0, self.H - 1):
                        edge = True
                    for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                        if 0 <= nx < self.W and 0 <= ny < self.H and not seen[ny, nx] and t[ny, nx] == S:
                            seen[ny, nx] = True
                            q.append((nx, ny))
                if not edge and len(comp) <= max_size:
                    for cx, cy in comp:
                        t[cy, cx] = F
                    changed += len(comp)
        return changed

    # ---- sorgular
    def passable(self):
        return (self.t == F) & (self.solid_obj == 0)

    def bfs(self, sources, passable=None):
        if passable is None:
            passable = self.passable()
        dist = np.full(self.t.shape, -1, np.int32)
        q = deque()
        for (x, y) in sources:
            if passable[y, x]:
                dist[y, x] = 0
                q.append((x, y))
        while q:
            x, y = q.popleft()
            d = dist[y, x] + 1
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < self.W and 0 <= ny < self.H and dist[ny, nx] < 0 and passable[ny, nx]:
                    dist[ny, nx] = d
                    q.append((nx, ny))
        return dist

    def floor_components(self):
        p = self.passable()
        lab = np.full(self.t.shape, -1, np.int32)
        n = 0
        sizes = []
        for y in range(self.H):
            for x in range(self.W):
                if p[y, x] and lab[y, x] < 0:
                    q = deque([(x, y)])
                    lab[y, x] = n
                    c = 0
                    while q:
                        cx, cy = q.popleft()
                        c += 1
                        for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                            if 0 <= nx < self.W and 0 <= ny < self.H and lab[ny, nx] < 0 and p[ny, nx]:
                                lab[ny, nx] = n
                                q.append((nx, ny))
                    sizes.append(c)
                    n += 1
        return lab, sizes

    def keep_main_component(self, seed_cell):
        lab, sizes = self.floor_components()
        keep = lab[seed_cell[1], seed_cell[0]]
        drop = (self.t == F) & (lab != keep) & (self.solid_obj == 0)
        self.t[drop] = S
        return int(drop.sum())


# ------------------------------------------------------------------------------------------------ KAÇIŞ doğrulaması
def escape_report(lay, exits, gates=()):
    """exits: çıkış hücreleri. gates: (kapı hücreleri listesi) - kapalı kapılar.
    1) Tüm zemin çıkışlara bağlı mı. 2) TEK bir koridor (grafik kenarı) ya da TEK bir kapı kapatılınca her oda hâlâ bir çıkışa ulaşıyor mu.
    3) Her zemin hücresinin en yakın çıkışa yürüme mesafesi (hücre)."""
    p = lay.passable()
    base = lay.bfs(exits, p)
    unreach = int(((p) & (base < 0)).sum())
    fails = []
    room_cells = {r.id: (r.center() if r.cells is None else r.cells[len(r.cells) // 2]) for r in lay.rooms}

    def check(block_mask, label):
        pp = p & ~block_mask
        d = lay.bfs(exits, pp)
        for rid, (cx, cy) in room_cells.items():
            if block_mask[cy, cx]:
                continue
            if pp[cy, cx] and d[cy, cx] < 0:
                fails.append((label, rid))
    for i, cells in enumerate(gates):
        m = np.zeros(p.shape, bool)
        for (x, y) in cells:
            m[y, x] = True
        check(m, 'kapı %d' % i)
    vals = base[p & (base >= 0)]
    return {
        'zemin': int(p.sum()),
        'ulasilmaz': unreach,
        'kapi_hatasi': fails,
        'tikanma_hatasi': blockage_failures(lay, exits),
        'cikis_mesafe_ort': float(vals.mean()) if vals.size else 0.0,
        'cikis_mesafe_max': int(vals.max()) if vals.size else 0,
    }


def _room_cells(lay, r):
    if r.cells is not None:
        return r.cells
    return [(x, y) for y in range(r.y, r.y + r.h) for x in range(r.x, r.x + r.w)]


def blockage_failures(lay, exits, radius=2, step=3, extra_block=None, points=None):
    """TIKANMA testi: koridorlardaki her `step`. hücreye (yalnız koridor, oda değil) yarıçapı `radius` bir kare "kovalayan grup"
    konur; o kapalıyken çıkışlardan hiç ulaşılamayan oda varsa [(tıkanan hücre, oda id)] döner. Odanın tıkanan hücreleri sayılmaz.
    points: yalnız bu (x, y) noktalarını dene (onarım turlarında hızlı yeniden deneme)."""
    p = lay.passable()
    if extra_block is not None:
        p = p & ~extra_block
    rooms = [(r.id, [c for c in _room_cells(lay, r) if p[c[1], c[0]]]) for r in lay.rooms]
    if points is None:
        corr = [(int(y), int(x)) for i, (y, x) in enumerate(np.argwhere((lay.corr_id >= 0) & (lay.room_id < 0) & p)) if i % step == 0]
    else:
        corr = [(y, x) for (x, y) in points]
    out = []
    for (y, x) in corr:
        if not p[y, x]:
            continue
        m = p.copy()
        m[max(0, y - radius):y + radius + 1, max(0, x - radius):x + radius + 1] = False
        d = lay.bfs(exits, m)
        for rid, cells in rooms:
            ok = [c for c in cells if m[c[1], c[0]]]
            if ok and all(d[c[1], c[0]] < 0 for c in ok[::max(1, len(ok) // 6)]):
                out.append(((int(x), int(y)), rid))
    return out


def repair_escape(lay, exits, width=3, max_rounds=16, organic=False):
    """Tıkanma testi hatası kalmayana kadar: o tıkanmada kopan oda kümesinden, tıkanan noktadan UZAK geçen bir koridorla kümenin
    dışındaki (çıkışa ulaşan) en yakın odaya bağlantı. Önce tam test, sonra yalnız hatalı noktalar yeniden denenir, en sonda tam test."""
    fails = blockage_failures(lay, exits)
    for _ in range(max_rounds):
        if not fails:
            break
        (bx, by), _rid = fails[0]
        cut = sorted({rid for (pt, rid) in fails if pt == (bx, by)})
        p = lay.passable()
        p[max(0, by - 2):by + 3, max(0, bx - 2):bx + 3] = False
        d = lay.bfs(exits, p)
        best = None
        for a in cut:
            ca = lay.rooms[a].center()
            for r in lay.rooms:
                if r.id in cut:
                    continue
                c = r.center()
                if d[c[1], c[0]] < 0:
                    continue
                for hf in (True, False):
                    if organic:
                        path = None
                        far = _dist_point_seg((bx, by), ca, c) > 6
                    else:
                        if hf:
                            path = lay._seg(ca[0], ca[1], c[0], ca[1], width) + lay._seg(c[0], ca[1], c[0], c[1], width)
                        else:
                            path = lay._seg(ca[0], ca[1], ca[0], c[1], width) + lay._seg(ca[0], c[1], c[0], c[1], width)
                        far = all(abs(x - bx) > 5 or abs(y - by) > 5 for (x, y) in path)
                    if not far:
                        continue
                    dist = math.dist(ca, c)
                    if best is None or dist < best[0]:
                        best = (dist, a, r.id, hf)
        if best is None:
            lay.notes.append('kaçış onarımı BAŞARISIZ: tıkanma %s, kopan %s' % ((bx, by), cut))
            fails = [f for f in fails if f[0] != (bx, by)]
            continue
        _, a, b, hf = best
        eid = max(e for _, _, e in lay.edges) + 1
        lay.edges.append((min(a, b), max(a, b), eid))
        if organic:
            lay.carve_tunnel(a, b, eid, width)
        else:
            lay.carve_corridor(a, b, eid, width, horiz_first=hf)
        lay.notes.append('kaçış onarımı: oda %d -> %d (tıkanma %s, kopan %s)' % (a, b, (bx, by), cut))
        fails = blockage_failures(lay, exits, points=sorted({pt for pt, _ in fails}))
    return not blockage_failures(lay, exits)


def _dist_point_seg(p, a, b):
    ax, ay = a
    bx, by = b
    px, py = p
    dx, dy = bx - ax, by - ay
    ll = dx * dx + dy * dy
    u = 0.0 if ll == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / ll))
    return math.hypot(px - (ax + u * dx), py - (ay + u * dy))


# ------------------------------------------------------------------------------------------------ tileset kaydı + TMX
def open_sheet(spec):
    if spec.startswith('zip:'):
        import io
        import zipfile
        archive, inner = spec[4:].split('|', 1)
        with zipfile.ZipFile(os.path.join(ART, archive)) as zf:
            return Image.open(io.BytesIO(zf.read(inner))).convert('RGBA')
    return Image.open(spec).convert('RGBA')


class Tileset:
    def __init__(self, key, src, dest_rel, img=None, anims=None):
        self.key, self.src, self.dest_rel = key, src, dest_rel  # dest_rel: harita/zindan altına göre
        self.img = img if img is not None else open_sheet(src)
        self.cols = self.img.width // CELL
        self.rows = self.img.height // CELL
        self.count = self.cols * self.rows
        self.anims = anims or {}  # yerel id -> [(kare yerel id, ms)]
        self.first = 0
        self._cache = {}
        self.used = set()

    def lid(self, col, row):
        return row * self.cols + col

    def tile(self, lid):
        if lid not in self._cache:
            c, r = lid % self.cols, lid // self.cols
            self._cache[lid] = self.img.crop((c * CELL, r * CELL, c * CELL + CELL, r * CELL + CELL))
        return self._cache[lid]

    def opaque(self, col, row):
        t = self.tile(self.lid(col, row))
        return t.getextrema()[3][1] > 0


class TilesetBank:
    def __init__(self, pack_dir):
        self.pack_dir = pack_dir  # harita/zindan/<pack_dir>
        self.sets = {}
        self.order = []

    def add(self, key, src, name=None, img=None, anims=None):
        name = name or os.path.basename(src.split('|')[-1])
        ts = Tileset(key, src, os.path.join(self.pack_dir, name).replace('\\', '/'), img, anims)
        self.sets[key] = ts
        self.order.append(key)
        for k in self.order:
            self.sets[k].first = 0  # yeni sayfa: gid'ler yeniden atanır (ilk gid() çağrısında)
        return ts

    def assign_gids(self):
        g = 1
        for k in self.order:
            self.sets[k].first = g
            g += self.sets[k].count

    def gid(self, key, col, row, flags=0):
        ts = self.sets[key]
        if ts.first == 0:
            self.assign_gids()
        lid = ts.lid(col, row)
        ts.used.add(lid)
        return (ts.first + lid) | flags

    def decode(self, gid):
        g = gid & ~(FH | FV | FD)
        for k in reversed(self.order):
            ts = self.sets[k]
            if ts.first <= g < ts.first + ts.count:
                return ts, g - ts.first
        return None, 0

    def write_files(self):
        """PNG'leri harita/zindan/<paket>/ altına yazar + her biri için .tsx (animasyonlar dahil)."""
        for k in self.order:
            ts = self.sets[k]
            png = os.path.join(ZROOT, ts.dest_rel)
            os.makedirs(os.path.dirname(png), exist_ok=True)
            ts.img.save(png)
            tsx = os.path.splitext(png)[0] + '.tsx'
            lines = ['<?xml version="1.0" encoding="UTF-8"?>',
                     '<tileset version="1.10" tiledversion="1.12.2" name="%s" tilewidth="16" tileheight="16" tilecount="%d" columns="%d">'
                     % (os.path.splitext(os.path.basename(png))[0], ts.count, ts.cols),
                     ' <image source="%s" width="%d" height="%d"/>' % (os.path.basename(png), ts.img.width, ts.img.height)]
            for lid in sorted(ts.anims):
                lines.append(' <tile id="%d">' % lid)
                lines.append('  <animation>')
                for fl, ms in ts.anims[lid]:
                    lines.append('   <frame tileid="%d" duration="%d"/>' % (fl, ms))
                lines.append('  </animation>')
                lines.append(' </tile>')
            lines.append('</tileset>')
            with open(tsx, 'w', encoding='utf-8', newline='\n') as f:
                f.write('\n'.join(lines) + '\n')


class TileLayers:
    def __init__(self, w, h, order):
        self.W, self.H = w, h
        self.order = list(order)
        self.L = {n: np.zeros((h, w), np.int64) for n in self.order}

    def put(self, name, x, y, gid):
        if 0 <= x < self.W and 0 <= y < self.H:
            self.L[name][y, x] = gid

    def get(self, name, x, y):
        return int(self.L[name][y, x]) if 0 <= x < self.W and 0 <= y < self.H else 0


def write_tmx(path, bank, layers, objects, w, h, props=None, hidden=()):
    bank.assign_gids()
    rel = os.path.relpath(ZROOT, os.path.dirname(path)).replace('\\', '/')
    lines = ['<?xml version="1.0" encoding="UTF-8"?>',
             '<map version="1.10" tiledversion="1.12.2" orientation="orthogonal" renderorder="right-down" width="%d" height="%d" '
             'tilewidth="16" tileheight="16" infinite="0" nextlayerid="%d" nextobjectid="%d">' % (w, h, len(layers.order) + 3, len(objects) + 1)]
    if props:
        lines.append(' <properties>')
        for k, v in props.items():
            lines.append('  <property name="%s" value="%s"/>' % (k, v))
        lines.append(' </properties>')
    for k in bank.order:
        ts = bank.sets[k]
        src = os.path.splitext(ts.dest_rel)[0] + '.tsx'
        src = (rel + '/' + src) if rel != '.' else src
        lines.append(' <tileset firstgid="%d" source="%s"/>' % (ts.first, src))
    lid = 1
    for name in layers.order:
        arr = layers.L[name]
        vis = ' visible="0"' if name in hidden else ''
        op = ' opacity="0.45"' if name in hidden else ''
        lines.append(' <layer id="%d" name="%s" width="%d" height="%d"%s%s>' % (lid, name, w, h, vis, op))
        lines.append('  <data encoding="csv">')
        lines.append(',\n'.join(','.join(str(int(v)) for v in row) for row in arr))
        lines.append('</data>')
        lines.append(' </layer>')
        lid += 1
    lines.append(' <objectgroup id="%d" name="Etkileşimler">' % lid)
    for i, o in enumerate(objects):
        lines.append('  <object id="%d" name="%s" type="%s" x="%d" y="%d" width="%d" height="%d">'
                     % (i + 1, o['name'], o['type'], o['x'], o['y'], o.get('w', 16), o.get('h', 16)))
        pr = o.get('props', {})
        if pr:
            lines.append('   <properties>')
            for k, v in pr.items():
                lines.append('    <property name="%s" value="%s"/>' % (k, v))
            lines.append('   </properties>')
        lines.append('  </object>')
    lines.append(' </objectgroup>')
    lines.append('</map>')
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')


# ------------------------------------------------------------------------------------------------ önizleme
def render(bank, layers, w, h, x0=0, y0=0, x1=None, y1=None, skip=(), bg=(10, 9, 12, 255), t_ms=0):
    bank.assign_gids()
    x1 = w if x1 is None else x1
    y1 = h if y1 is None else y1
    img = Image.new('RGBA', ((x1 - x0) * CELL, (y1 - y0) * CELL), bg)
    cache = {}
    for name in layers.order:
        if name in skip:
            continue
        arr = layers.L[name]
        for y in range(y0, y1):
            row = arr[y]
            for x in range(x0, x1):
                g = int(row[x])
                if not g:
                    continue
                key = (g, t_ms)
                if key not in cache:
                    ts, lid = bank.decode(g)
                    if ts is None:
                        cache[key] = None
                    else:
                        if lid in ts.anims and t_ms:
                            fr = ts.anims[lid]
                            tot = sum(ms for _, ms in fr)
                            tt = t_ms % tot
                            for fl, ms in fr:
                                if tt < ms:
                                    lid = fl
                                    break
                                tt -= ms
                        t = ts.tile(lid)
                        if g & FD:
                            t = t.transpose(Image.TRANSPOSE)
                        if g & FH:
                            t = t.transpose(Image.FLIP_LEFT_RIGHT)
                        if g & FV:
                            t = t.transpose(Image.FLIP_TOP_BOTTOM)
                        cache[key] = t
                t = cache[key]
                if t is not None:
                    img.alpha_composite(t, ((x - x0) * CELL, (y - y0) * CELL))
    return img


def semantic_png(lay, objects, path, scale=4):
    cols = {S: (24, 22, 28), F: (150, 140, 120), W: (60, 120, 170), L: (200, 90, 40)}
    img = Image.new('RGB', (lay.W, lay.H))
    px = img.load()
    for y in range(lay.H):
        for x in range(lay.W):
            c = cols[int(lay.t[y, x])]
            if lay.solid_obj[y, x]:
                c = (110, 80, 60)
            px[x, y] = c
    img = img.resize((lay.W * scale, lay.H * scale), Image.NEAREST)
    from PIL import ImageDraw
    d = ImageDraw.Draw(img)
    tc = {'cikis': (60, 255, 90), 'kaynak': (255, 220, 60), 'kapi': (255, 80, 80), 'saklanma': (160, 120, 255), 'tuzak': (255, 140, 0),
          'sunak': (255, 255, 255), 'sandik': (255, 200, 120), 'kol': (255, 120, 200), 'sakin': (200, 40, 40), 'avci': (255, 0, 0),
          'kisayol': (0, 200, 255), 'isik': (255, 250, 200)}
    for o in objects:
        c = tc.get(o['type'], (255, 0, 255))
        x, y = o['x'] / CELL * scale, o['y'] / CELL * scale
        ww, hh = max(scale, o.get('w', 16) / CELL * scale), max(scale, o.get('h', 16) / CELL * scale)
        d.rectangle([x, y, x + ww - 1, y + hh - 1], outline=c)
    for r in lay.rooms:
        cx, cy = r.center()
        d.text((cx * scale - 4, cy * scale - 4), str(r.id), fill=(255, 255, 255))
    img.save(path)


def sample_anims(tmx_path, tileset_name, src_override=None):
    """Paketin örnek TMX'indeki gömülü tileset animasyonları: {yerel id: [(kare yerel id, ms)]} (aynı adlı ilk tileset)."""
    import xml.etree.ElementTree as ET
    root = ET.parse(tmx_path).getroot()
    out = {}
    for ts in root.findall('tileset'):
        if ts.get('name') != tileset_name:
            continue
        img = ts.find('image')
        if src_override and img is not None and os.path.basename(img.get('source')) != src_override:
            continue
        for t in ts.findall('tile'):
            an = t.find('animation')
            if an is None:
                continue
            out[int(t.get('id'))] = [(int(f.get('tileid')), int(f.get('duration'))) for f in an.findall('frame')]
        if out:
            break
    return out


def make_marker_sheet():
    """Engel katmanı işaret sayfası: 0 duvar (kırmızı), 1 engel (turuncu), 2 saklanma (mor), 3 kapı (camgöbeği), 4 su (mavi)."""
    img = Image.new('RGBA', (80, 16), (0, 0, 0, 0))
    cols = [(220, 40, 40, 150), (240, 150, 30, 150), (150, 80, 230, 150), (40, 220, 230, 150), (40, 90, 230, 150)]
    for i, c in enumerate(cols):
        for y in range(16):
            for x in range(16):
                edge = x in (0, 15) or y in (0, 15)
                img.putpixel((i * 16 + x, y), (c[0], c[1], c[2], 230 if edge else c[3]))
    return img


ENGEL_DUVAR, ENGEL_NESNE, ENGEL_SAKLANMA, ENGEL_KAPI, ENGEL_SU = 0, 1, 2, 3, 4


def stamp(bank, tl, layer, key, rect, x, y, flip_h=False, skip_empty=True):
    """Sayfadaki (sx, sy, w, h) karo dikdörtgenini (x, y) sol üst hücresine koyar; boş karolar atlanır. Koyulan hücreleri döner."""
    sx, sy, w, h = rect
    ts = bank.sets[key]
    put = []
    for j in range(h):
        for i in range(w):
            si = (w - 1 - i) if flip_h else i
            if skip_empty and not ts.opaque(sx + si, sy + j):
                continue
            tl.put(layer, x + i, y + j, bank.gid(key, sx + si, sy + j, FH if flip_h else 0))
            put.append((x + i, y + j))
    return put


def copy_tree_file(src, dst):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copyfile(src, dst)
