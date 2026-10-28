# ZİNDANLAR (madde 373): ortak boyama + süsleme + etkileşim yerleşimi.
# 3/4 bakış duvarı: bir duvar hücresinin altında 1/2/3 hücre sonra zemin varsa sırasıyla alt yüz / üst yüz / dudak; yoksa üst (kenarlı).
# Engel katmanı (oyun okur): 0 duvar (hareket + görüş), 1 nesne (yalnız hareket), 2 saklanma (yürünür, saklar), 3 kapı (çalışma anında aç/kapa).
import math
import os
import random
import shutil
from collections import deque

import numpy as np

import zindan_core as Z

CYAN = (0.45, 1.0, 0.95)
RED = (1.0, 0.42, 0.32)
AMBER = (1.0, 0.7, 0.35)
VIOLET = (0.7, 0.55, 1.0)


def k_below(t, x, y, n=3):
    H = t.shape[0]
    for k in range(1, n + 1):
        yy = y + k
        if yy >= H:
            return 0
        if t[yy, x] != Z.S:
            return k
    return 0


def paint_walls_34(lay, bank, tl, key, floor=(2, 8), top=((1, 1), (2, 1), (3, 1), (1, 2), (2, 2), (3, 2)),
                   face_rows=None, face_cols=(1, 2, 3), region=None, floor_variants=None, rng=None, floor_key=None, floor_pool=None,
                   floor_fn=None, face_key=None, water_face=None, face_caps=None):
    """top: (TL, T, TR, L, C, R). face_rows: {k: satır} (k=1 alt yüz, 2 üst yüz, 3 dudak); bir k yoksa o hücre üst (boşluk) olur
    (2 satırlık yüz paketleri). floor_key/floor_pool: zemin başka sayfadan, hücre konumuna göre (kararlı) havuzdan seçilir.
    floor_fn(x, y) -> (sayfa, (sütun, satır)): hücre başına zemin (oda/koridor/desen; havuzu ezer). face_key: yüz başka sayfadan.
    water_face = (sayfa, face_rows, face_cols): yüzün altındaki ilk hücre kanal (Z.W) ise bu yüz (su çizgili) kullanılır.
    face_caps = (sol sütun, sağ sütun): yüzün yuvarlak ucu komşu hücreye taşan paketlerde (kanalizasyon) uç, yüzün yanındaki ZEMİN
    hücresine ikinci geçişte konur (aynı satır)."""
    face_rows = face_rows or {1: 5, 2: 4, 3: 3}
    fkey = floor_key or key
    fckey = face_key or key
    t = lay.t
    Hh, Ww = t.shape
    S = Z.S
    x0, y0, x1, y1 = region or (0, 0, Ww, Hh)

    def isS(x, y):
        return not (0 <= x < Ww and 0 <= y < Hh) or t[y, x] == S

    caps = []
    for y in range(max(0, y0), min(Hh, y1)):
        for x in range(max(0, x0), min(Ww, x1)):
            tl.put('Duvar', x, y, 0)
            fl = floor
            fk = fkey
            if floor_fn is not None:
                fk, fl = floor_fn(x, y)
            elif floor_pool:
                hsh = (x * 73856093) ^ (y * 19349663)
                fl = floor_pool[hsh % len(floor_pool)]
            elif floor_variants and rng is not None and rng.random() < floor_variants[1]:
                fl = floor_variants[0][rng.randrange(len(floor_variants[0]))]
            if t[y, x] != S:
                tl.put('Zemin', x, y, bank.gid(fk, fl[0], fl[1]))
                continue
            near = any(0 <= x + dx < Ww and 0 <= y + dy < Hh and t[y + dy, x + dx] != S for dy in (-1, 0, 1) for dx in (-1, 0, 1))
            tl.put('Zemin', x, y, bank.gid(fk, fl[0], fl[1]) if near else 0)
            k = k_below(t, x, y)
            lf, rt, up = isS(x - 1, y), isS(x + 1, y), isS(x, y - 1)
            fr, fcols, fkk = face_rows, face_cols, fckey
            if k and water_face is not None and t[y + k, x] == Z.W:
                fkk, fr, fcols = water_face
            if k and k not in fr:
                k = 0
            if k and isinstance(fr[k], tuple):  # satır başına ayrı sayfa: (sayfa, satır, (sol, orta, sağ))
                fkk, row_k, fcols = fr[k]
                fr = dict(fr)
                fr[k] = row_k
            if k:
                lk = lf and k_below(t, x - 1, y) == k
                rk = rt and k_below(t, x + 1, y) == k
                mid = fcols[1]
                if lk and rk:
                    col = mid if not isinstance(mid, (list, tuple)) else mid[(x * 7 + (y + k) * 3) % len(mid)]
                elif not lk and rk:
                    col = fcols[0]
                elif lk and not rk:
                    col = fcols[2]
                else:
                    col = mid if not isinstance(mid, (list, tuple)) else mid[0]
                tl.put('Duvar', x, y, bank.gid(fkk, col, fr[k]))
                if face_caps is not None and fkk == fckey:
                    if not lk and x > 0 and t[y, x - 1] != S:
                        caps.append((x - 1, y, face_caps[0], fr[k]))
                    if not rk and x + 1 < Ww and t[y, x + 1] != S:
                        caps.append((x + 1, y, face_caps[1], fr[k]))
                continue
            if not up:
                c = top[0] if not lf else (top[2] if not rt else top[1])
            else:
                c = top[3] if not lf else (top[5] if not rt else top[4])
            tl.put('Duvar', x, y, bank.gid(key, c[0], c[1]))
    for (x, y, col, row) in caps:
        tl.put('Duvar', x, y, bank.gid(fckey, col, row))


# ------------------------------------------------------------------------------------------------ zemin çeşitliliği
def value_noise(w, h, seed, cell=7.0):
    """[0, 1] yumuşak değer gürültüsü (smoothstep'li çift doğrusal), (h, w) dizi."""
    rng = random.Random(seed)
    gw, gh = int(w / cell) + 3, int(h / cell) + 3
    g = np.array([[rng.random() for _ in range(gw)] for _ in range(gh)])
    ys, xs = np.mgrid[0:h, 0:w]
    fx, fy = xs / cell, ys / cell
    ix, iy = fx.astype(int), fy.astype(int)
    u, v = fx - ix, fy - iy
    u, v = u * u * (3 - 2 * u), v * v * (3 - 2 * v)
    return g[iy, ix] * (1 - u) * (1 - v) + g[iy, ix + 1] * u * (1 - v) + g[iy + 1, ix] * (1 - u) * v + g[iy + 1, ix + 1] * u * v


def hpick(pool, x, y, salt=0):
    """Hücreye göre kararlı seçim (aynı tohumda her koşuda aynı)."""
    return pool[((x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)) % len(pool)]


def wall_distance(lay, cap=8):
    """Her hücrenin en yakın duvar (Z.S) hücresine Chebyshev uzaklığı (duvar 0, tavan cap)."""
    t = lay.t
    Hh, Ww = t.shape
    d = np.full((Hh, Ww), cap, np.int16)
    q = deque()
    for y in range(Hh):
        for x in range(Ww):
            if t[y, x] == Z.S:
                d[y, x] = 0
                q.append((x, y))
    while q:
        x, y = q.popleft()
        nd = d[y, x] + 1
        if nd >= cap:
            continue
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                xx, yy = x + dx, y + dy
                if 0 <= xx < Ww and 0 <= yy < Hh and d[yy, xx] > nd:
                    d[yy, xx] = nd
                    q.append((xx, yy))
    return d


def room_mask(lay):
    """Oda zemini (room_id >= 0) True; koridorlar False."""
    return (lay.room_id >= 0) & (lay.t != Z.S)


def nine_slice(tl, bank, layer, key, s9, x, y, w, h):
    """s9 = (TL, T, TR, L, C, R, BL, B, BR) karoları; (x, y, w, h) dikdörtgenine döşer (w, h >= 2). C liste olabilir (kararlı seçim)."""
    for j in range(h):
        for i in range(w):
            r = 0 if j == 0 else (2 if j == h - 1 else 1)
            c = 0 if i == 0 else (2 if i == w - 1 else 1)
            cc = s9[r * 3 + c]
            if isinstance(cc, list):
                cc = hpick(cc, x + i, y + j, 5)
            tl.put(layer, x + i, y + j, bank.gid(key, cc[0], cc[1]))


def place_rugs(mask, noise, thr, rng, sizes=((3, 3), (4, 3), (5, 3), (4, 4), (6, 4), (3, 2)), max_n=999, gap=1):
    """Gürültünün thr üstündeki yerlerine, mask içinde kalan, birbirine değmeyen dikdörtgen yamalar (halı/levha) seçer.
    Dönüş: [(x, y, w, h)]."""
    Hh, Ww = mask.shape
    used = np.zeros(mask.shape, bool)
    cands = [(float(noise[y, x]), x, y) for y in range(Hh) for x in range(Ww) if mask[y, x] and noise[y, x] > thr]
    cands.sort(reverse=True)
    out = []
    for _, x, y in cands:
        if len(out) >= max_n:
            break
        if used[y, x]:
            continue
        for (w, h) in sorted(sizes, key=lambda s: -s[0] * s[1] + rng.random() * 6):
            x0, y0 = x - w // 2, y - h // 2
            if x0 < 0 or y0 < 0 or x0 + w > Ww or y0 + h > Hh:
                continue
            if not mask[y0:y0 + h, x0:x0 + w].all():
                continue
            if used[max(0, y0 - gap):y0 + h + gap, max(0, x0 - gap):x0 + w + gap].any():
                continue
            used[y0:y0 + h, x0:x0 + w] = True
            out.append((x0, y0, w, h))
            break
    return out


def floor_frame(lay, bank, tl, key, frame, region=None, against_up=(Z.W,), against_side=(Z.S, Z.W), skip=None):
    """Zemin kenar çerçevesi: boşluğa / kanala bakan zemin hücresine çerçeve karosu ('Zemin' katmanını ezer).
    frame = {'T','B','L','R','TL','TR','BL','BR'}: karo (ya da (x, y) -> karo). Üst kenar yalnız against_up'a bakınca (üstte çoğunlukla
    duvar yüzü vardır, yüzün tabanı zaten çizgili)."""
    t = lay.t
    Hh, Ww = t.shape
    x0, y0, x1, y1 = region or (0, 0, Ww, Hh)

    def v(x, y):
        return t[y, x] if 0 <= x < Ww and 0 <= y < Hh else Z.S

    for y in range(max(0, y0), min(Hh, y1)):
        for x in range(max(0, x0), min(Ww, x1)):
            if t[y, x] != Z.F or (skip is not None and skip(x, y)):
                continue
            up = v(x, y - 1) in against_up
            dn = v(x, y + 1) in against_side
            lf = v(x - 1, y) in against_side
            rt = v(x + 1, y) in against_side
            if not (up or dn or lf or rt):
                continue
            k = ('T' if up else ('B' if dn else '')) + ('L' if lf else ('R' if rt else ''))
            c = frame.get(k) or frame.get(k[0]) or frame.get(k[-1])
            if c is None:
                continue
            if callable(c):
                c = c(x, y)
            tl.put('Zemin', x, y, bank.gid(key, c[0], c[1]))


def floor_details(lay, bank, tl, key, tiles, density=0.2, seed=1, layer='Zemin süsü', mask=None):
    """Zemine değer gürültüsüyle öbeklenen ayrıntı karoları (tuğla çizgileri, çatlak). mask: yalnız True hücrelere."""
    rng = random.Random(seed)
    Hh, Ww = lay.t.shape
    gw, gh = Ww // 6 + 2, Hh // 6 + 2
    g = np.array([[rng.random() for _ in range(gw)] for _ in range(gh)])
    for y in range(Hh):
        for x in range(Ww):
            if lay.t[y, x] != Z.F or (mask is not None and not mask[y, x]):
                continue
            fx, fy = x / 6.0, y / 6.0
            ix, iy = int(fx), int(fy)
            u, v = fx - ix, fy - iy
            n = (g[iy, ix] * (1 - u) * (1 - v) + g[iy, ix + 1] * u * (1 - v) + g[iy + 1, ix] * (1 - u) * v + g[iy + 1, ix + 1] * u * v)
            if n > 1.0 - density * 2.2 and rng.random() < 0.55:
                c = tiles[rng.randrange(len(tiles))]
                tl.put(layer, x, y, bank.gid(key, c[0], c[1]))


def obj_cells(o):
    x0, y0 = o['x'] // 16, o['y'] // 16
    return [(x0 + i, y0 + j) for j in range(max(1, o.get('h', 16) // 16)) for i in range(max(1, o.get('w', 16) // 16))]


def obj_center_cell(o):
    return (o['x'] // 16 + max(1, o.get('w', 16) // 16) // 2, o['y'] // 16 + max(1, o.get('h', 16) // 16) // 2)


def copy_runtime_sheets(src_dir, pack, names):
    for n in names:
        dst = os.path.join(Z.ZROOT, pack, 'runtime', n)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copyfile(os.path.join(src_dir, n), dst)


def write_engel(lay, bank, tl, dz):
    t = lay.t
    Hh, Ww = t.shape
    for y in range(Hh):
        for x in range(Ww):
            v = -1
            if t[y, x] == Z.S:
                v = Z.ENGEL_DUVAR
            elif t[y, x] == Z.W:
                v = Z.ENGEL_SU
            elif t[y, x] == Z.L or lay.solid_obj[y, x] == 2:
                v = Z.ENGEL_NESNE
            elif lay.solid_obj[y, x] == 1:
                v = Z.ENGEL_DUVAR  # sütun gibi görüşü kesen nesne
            elif dz.hide[y, x]:
                v = Z.ENGEL_SAKLANMA
            elif dz.gate[y, x]:
                v = Z.ENGEL_KAPI
            tl.put('Engel', x, y, bank.gid('eng', v, 0) if v >= 0 else 0)


class Decorator:
    def __init__(self, lay, bank, tl, seed=1, paint=None):
        self.lay, self.bank, self.tl = lay, bank, tl
        self.rng = random.Random(seed * 7 + 3)
        Hh, Ww = lay.t.shape
        self.occ = np.zeros((Hh, Ww), bool)
        self.hide = np.zeros((Hh, Ww), bool)
        self.gate = np.zeros((Hh, Ww), bool)
        self.objects = []
        self.notes = []
        self.paint = paint  # (x0, y0, x1, y1) bölgesini yeniden boyayan işlev (geometri değişince)
        self._build_reserve()
        self.spawn = None

    # ---------------------------------------------------------------- yardımcılar
    def _build_reserve(self):
        lay = self.lay
        r = (lay.corr_id >= 0) & (lay.room_id < 0)
        res = r.copy()
        Hh, Ww = lay.t.shape
        # koridorun odaya girdiği yerin 2 hücre içi + oda merkezinden geçen 3 hücrelik artı
        door = np.zeros((Hh, Ww), bool)
        ys, xs = np.nonzero(r)
        for y, x in zip(ys, xs):
            for dy in (-2, -1, 0, 1, 2):
                for dx in (-2, -1, 0, 1, 2):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < Hh and 0 <= xx < Ww and lay.room_id[yy, xx] >= 0:
                        res[yy, xx] = True
                        door[yy, xx] = True
        self.doorway = door | r
        for rm in lay.rooms:
            cx, cy = rm.center()
            if rm.cells is None and rm.w >= 6 and rm.h >= 6:
                # iç halka (kenardan 1 içeride): odadaki tüm kapı ağızları birbirine engelsiz bağlı kalsın (kaçış)
                for x in range(rm.x + 1, rm.x + rm.w - 1):
                    res[rm.y + 1, x] = True
                    res[rm.y + rm.h - 2, x] = True
                for y in range(rm.y + 1, rm.y + rm.h - 1):
                    res[y, rm.x + 1] = True
                    res[y, rm.x + rm.w - 2] = True
            for x in range(rm.x, rm.x + rm.w):
                for dy in (-1, 0, 1):
                    if 0 <= cy + dy < Hh:
                        res[cy + dy, x] = True
            for y in range(rm.y, rm.y + rm.h):
                for dx in (-1, 0, 1):
                    if 0 <= cx + dx < Ww:
                        res[y, cx + dx] = True
        self.reserve = res

    def is_free(self, x, y, w, h, allow_reserve=False, allow_door=False):
        """allow_reserve: oda artısı/iç halka/koridor hücrelerine izin (yürünür süs için). Kapı ağzı (koridorun odaya girdiği 2 hücre) yalnız
        allow_door ile - engelli nesne hiçbir zaman kapı ağzına konmaz."""
        lay = self.lay
        Hh, Ww = lay.t.shape
        if x < 0 or y < 0 or x + w > Ww or y + h > Hh:
            return False
        sub = (slice(y, y + h), slice(x, x + w))
        if not allow_door and self.doorway[sub].any():
            return False
        if (lay.t[sub] != Z.F).any() or self.occ[sub].any() or lay.solid_obj[sub].any() or self.hide[sub].any() or self.gate[sub].any():
            return False
        if not allow_reserve and self.reserve[sub].any():
            return False
        return True

    def is_face(self, x, y, k=None):
        t = self.lay.t
        if not (0 <= y < t.shape[0] and 0 <= x < t.shape[1]) or t[y, x] != Z.S:
            return False
        kk = k_below(t, x, y)
        return kk > 0 if k is None else kk == k

    def face_free(self, x, y, w, h):
        for j in range(h):
            for i in range(w):
                if not self.is_face(x + i, y + j) or self.occ[y + j, x + i]:
                    return False
        return True

    def put(self, layer, spec, x, y, flip=False, occupy=True):
        key, rect = spec
        cells = Z.stamp(self.bank, self.tl, layer, key, rect, x, y, flip_h=flip)
        if occupy:
            for (cx, cy) in cells:
                if 0 <= cy < self.occ.shape[0] and 0 <= cx < self.occ.shape[1]:
                    self.occ[cy, cx] = True
        return cells

    def add_obj(self, typ, name, x, y, w=1, h=1, **props):
        o = {'type': typ, 'name': name, 'x': int(x * 16), 'y': int(y * 16), 'w': int(w * 16), 'h': int(h * 16),
             'props': {k: v for k, v in props.items()}}
        self.objects.append(o)
        return o

    def light(self, px, py, color, r=96, energy=1.0, flicker=1):
        o = {'type': 'isik', 'name': 'ışık', 'x': int(px), 'y': int(py), 'w': 0, 'h': 0,
             'props': {'r': int(r), 'renk': '%.2f,%.2f,%.2f' % color, 'g': '%.2f' % energy, 'titre': int(flicker)}}
        self.objects.append(o)

    def _connected_ok(self, cells):
        """cells nesne engeli olsa harita bölünüyor mu? (doğuş/giriş noktasından ulaşılan zemin sayısı yalnız hücre kadar azalmalı)"""
        lay = self.lay
        p = lay.passable() & ~self.gate
        start = self.spawn or lay.rooms[0].center()
        before = int((lay.bfs([start], p) >= 0).sum())
        for (x, y) in cells:
            p[y, x] = False
        after = int((lay.bfs([start], p) >= 0).sum())
        lost = sum(1 for (x, y) in cells if lay.passable()[y, x])
        return after >= before - lost

    def solidify(self, cells, val=2, check=True):
        cells = [(x, y) for (x, y) in cells if 0 <= y < self.lay.t.shape[0] and 0 <= x < self.lay.t.shape[1] and self.lay.t[y, x] == Z.F]
        if check and not self._connected_ok(cells):
            return False
        for (x, y) in cells:
            self.lay.solid_obj[y, x] = val
        return True

    def repaint(self, x0, y0, x1, y1):
        if self.paint:
            self.paint((x0 - 2, y0 - 4, x1 + 2, y1 + 4))

    # ---------------------------------------------------------------- oda içerikleri
    def spawn_point(self, r):
        cx, cy = r.center()
        y = min(r.y + r.h - 2, r.y + 4)
        self.spawn = (cx, y)
        self.add_obj('dogus', 'Doğuş', cx - 1, y - 1, 3, 2)

    def exit_stairs(self, r, spec, name, main=False):
        """Kuzey duvarına 3 hücrelik oyuk açar, merdiveni çizer; oyuk = çıkış tetikleyici."""
        key, rect = spec
        w = rect[2]
        cands = list(range(r.x + 1, r.x + r.w - w - 1))
        cands.sort(key=lambda x: abs(x + w // 2 - (r.x + r.w // 2)))
        for x in cands:
            ok = all(self.is_face(x + i, r.y - 3 + j) for i in range(w) for j in range(3)) and \
                all(self.is_face(x - 1, r.y - 3 + j) and self.is_face(x + w, r.y - 3 + j) for j in range(3))
            if not ok:
                continue
            # duvarın arkası en az 1 satır daha duvar (merdiven başı üstte çizilir)
            if any(self.lay.t[r.y - 4, x + i] != Z.S for i in range(w)):
                continue
            for j in range(3):
                for i in range(w):
                    self.lay.t[r.y - 3 + j, x + i] = Z.F
            self.repaint(x - 1, r.y - 5, x + w + 1, r.y + 1)
            cells = self.put('Duvar süsü', spec, x, r.y - 4)
            for (cx, cy) in cells:
                self.occ[cy, cx] = True
            for i in range(w):
                for j in range(2):
                    self.reserve[r.y + j, x + i] = True
            self.add_obj('cikis', name, x, r.y - 3, w, 3, ana=1 if main else 0)
            return True
        # yedek: odanın zeminine kapak merdiven (dar geçit)
        hatch = getattr(self, 'hatch_spec', None)
        if hatch:
            hw, hh = hatch[1][2], hatch[1][3]
            spots = [(x, y) for y in range(r.y + 1, r.y + r.h - hh) for x in range(r.x + 1, r.x + r.w - hw)]
            spots.sort(key=lambda c: math.dist(c, r.center()))
            for (x, y) in spots:
                if self.is_free(x, y, hw, hh, allow_reserve=True):
                    self.put('Eşya alt', hatch, x, y)
                    self.add_obj('cikis', name, x, y, hw, hh, ana=1 if main else 0)
                    self.notes.append('%s: duvar merdiveni yerine kapak (oda %d)' % (name, r.id))
                    return True
        self.notes.append('UYARI: %s için merdiven yeri bulunamadı (oda %d)' % (name, r.id))
        return False

    def statue_pair(self, r, spec):
        key, (sx, sy, w, h) = spec
        for x, flip in ((r.x + 1, False), (r.x + r.w - 1 - w, True)):
            if self.is_free(x, r.y, w, 1) and all(self.is_face(x + i, r.y - 1) for i in range(w)):
                if self.solidify([(x + i, r.y) for i in range(w)]):
                    self.put('Eşya', spec, x, r.y - h + 1, flip)

    def wall_torches(self, r, choices, step=6, light=CYAN, start=None):
        y = r.y - 3
        x = r.x + (start if start is not None else 2)
        n = 0
        while x + 2 <= r.x + r.w - 1:
            spec = choices[n % len(choices)]
            w = spec[1][2]
            if self.face_free(x, y, w, 3) and all(self.is_face(x + i, y, 3) for i in range(w)):
                self.put('Duvar süsü', spec, x, y)
                self.light((x + w / 2.0) * 16, (y + 1.2) * 16, light, r=110, energy=0.9)
                n += 1
                x += step
            else:
                x += 1

    def wall_reliefs(self, r, spec, step=9):
        y = r.y - 2
        x = r.x + 4
        while x + 2 <= r.x + r.w - 1:
            if self.face_free(x, y, 2, 2):
                self.put('Duvar süsü', spec, x, y)
                x += step
            else:
                x += 1

    def wall_hangings(self, r, choices, step=4):
        x = r.x + 1
        while x + 2 <= r.x + r.w - 1:
            spec = choices[self.rng.randrange(len(choices))]
            w, h = spec[1][2], spec[1][3]
            y = r.y - h if h <= 3 else r.y - 3
            if h == 3:
                y = r.y - 3
            elif h == 2:
                y = r.y - 2
            if self.face_free(x, y, w, h):
                self.put('Duvar süsü', spec, x, y)
                x += step + self.rng.randrange(3)
            else:
                x += 1

    def corner_candles(self, r, choices, light=CYAN, count=2):
        spots = [(r.x, r.y), (r.x + r.w - 2, r.y), (r.x, r.y + r.h - 2), (r.x + r.w - 2, r.y + r.h - 2)]
        self.rng.shuffle(spots)
        n = 0
        for (x, y) in spots:
            if n >= count:
                break
            if self.is_free(x, y, 2, 2) and self.solidify([(x, y + 1), (x + 1, y + 1)]):
                spec = choices[self.rng.randrange(len(choices))]
                self.put('Eşya', spec, x, y)
                self.light((x + 1) * 16, (y + 1) * 16, light, r=80, energy=0.75)
                n += 1

    def altar(self, r, spec, name, light=CYAN, light_r=140):
        key, (sx, sy, w, h) = spec
        base_y = r.y + 1  # heykelin alt 2 satırı zeminde
        top = base_y + 1 - (h - 1)
        xs = sorted(range(r.x + 2, r.x + r.w - w - 1), key=lambda xx: abs(xx + w // 2 - (r.x + r.w // 2)))
        x = next((xx for xx in xs if self.is_free(xx, r.y, w, 2, allow_reserve=True)
                  and all(self.is_face(xx + i, r.y - 1) for i in range(w))), None)
        by = r.y
        if x is None:
            # geniş koridorlar kuzey duvarını kapı ağzına çevirdiyse: oda içinde SERBEST duran sunak (üstü zemin, önünde etkileşim alanı)
            t = self.lay.t
            for yb in range(r.y + h - 2, r.y + r.h - 4):
                for xx in xs:
                    if self.is_free(xx, yb, w, 4, allow_reserve=True) and \
                            all(t[yy, xx + i] == Z.F and not self.occ[yy, xx + i] for yy in range(yb - h + 2, yb) for i in range(w)):
                        x, by = xx, yb
                        break
                if x is not None:
                    break
            top = by + 1 - (h - 1)
        if x is None:
            self.notes.append('UYARI: sunak yeri dolu (oda %d)' % r.id)
            return
        foot = [(x + i, by + j) for i in range(1, w - 1) for j in range(2)]
        if not self.solidify(foot):
            return
        self.put('Eşya', spec, x, top)
        for i in range(w):
            for j in range(4):
                if 0 <= by + 2 + j < self.reserve.shape[0]:
                    self.reserve[by + 2 + j, x + i] = True
        self.add_obj('sunak', name, x, by + 2, w, 2)
        self.light((x + w / 2.0) * 16, (by - 0.5) * 16, light, r=light_r, energy=1.2)

    def tomb_rows(self, r, tombs, open_list, margin_top=2, hide_every=3):
        cx = r.x + r.w // 2
        n = 0
        y = r.y + max(2, margin_top)
        while y < r.y + r.h - 2:
            row_h = 0
            x = r.x + 2
            while x + 2 <= r.x + r.w - 2:
                if cx - 2 <= x <= cx + 1:
                    x = cx + 2
                    continue
                use_open = hide_every and n % hide_every == hide_every - 1
                spec = open_list[self.rng.randrange(len(open_list))] if use_open else tombs[self.rng.randrange(len(tombs))]
                w, h = spec[1][2], spec[1][3]
                if y + h > r.y + r.h or not self.is_free(x, y, w, h):
                    x += 1
                    continue
                if use_open:
                    self.put('Eşya alt', spec, x, y)
                    for j in range(1, h):
                        for i in range(w):
                            self.hide[y + j, x + i] = True
                    self.add_obj('saklanma', 'Açık Lahit', x, y + 1, w, h - 1)
                else:
                    foot = [(x + i, y + j) for i in range(w) for j in range(1, h)]
                    if not self.solidify(foot):
                        x += 1
                        continue
                    self.put('Eşya', spec, x, y)
                n += 1
                row_h = max(row_h, h)
                x += w + 2
            y += (row_h or 1) + 2

    def resource_nodes(self, r, kind, n):
        """Kaynak düğümü (çalışma anında çizilir, 2x3 görsel): tabanı odanın üst ya da alt kenar satırında 2x1 engel."""
        placed = 0
        spots = [(x, r.y) for x in range(r.x + 1, r.x + r.w - 2)] + [(x, r.y + r.h - 1) for x in range(r.x + 1, r.x + r.w - 2)]
        self.rng.shuffle(spots)
        for (x, y) in spots:
            if placed >= n:
                break
            if not self.is_free(x - 1, y, 4, 1):
                continue
            if any(math.dist((x, y), (o['x'] // 16, o['y'] // 16)) < 6 for o in self.objects if o['type'] == 'kaynak'):
                continue
            if self.solidify([(x, y), (x + 1, y)]):
                for i in range(2):
                    self.occ[y, x + i] = True
                    if y - 1 >= 0:
                        self.occ[y - 1, x + i] = True
                self.add_obj('kaynak', kind, x, y - 2, 2, 3, tur=kind)
                placed += 1
        if placed < n:
            self.notes.append('UYARI: oda %d kaynak %d/%d' % (r.id, placed, n))

    def dwellers(self, r, profile):
        cx, cy = r.center()
        area = r.w * r.h
        count = max(2, min(9, area // 30))
        self.add_obj('sakin', profile, r.x + 1, r.y + 1, r.w - 2, r.h - 2, profil=profile, adet=count)

    def wall_fires(self, r, choices, step=6, light=AMBER):
        """Odanın üst zemin satırına ayaklı ateş kazanları (tabanı engel, üstü kuzey yüzünün önünde)."""
        x = r.x + 2
        n = 0
        while x + 3 <= r.x + r.w - 1:
            spec = choices[n % len(choices)]
            w, h = spec[1][2], spec[1][3]
            if self.is_free(x, r.y, w, 1) and all(self.is_face(x + i, r.y - 1) for i in range(w)) and self.solidify([(x + i, r.y) for i in range(w)]):
                self.put('Eşya', spec, x, r.y - h + 1)
                self.light((x + w / 2.0) * 16, (r.y + 0.2) * 16, light, r=118, energy=1.0)
                n += 1
                x += step
            else:
                x += 1

    def wall_row(self, r, choices, step=3, layer='Eşya', solid=False, face=False):
        """Kuzey duvarı boyunca sıra: face=True ise yüzün üstünde (hücre kapısı, pencere), değilse zemin satırında, üstü yüzün önünde (raf)."""
        x = r.x + 1
        n = 0
        while x + 2 <= r.x + r.w - 1:
            spec = choices[n % len(choices)]
            w, h = spec[1][2], spec[1][3]
            if face:
                y = r.y - min(h, 3)
                if self.face_free(x, y, w, min(h, 3)):
                    self.put(layer, spec, x, y)
                    n += 1
                    x += w + step - 2
                    continue
            else:
                if self.is_free(x, r.y, w, 1) and all(self.is_face(x + i, r.y - 1) for i in range(w)) and \
                        (not solid or self.solidify([(x + i, r.y) for i in range(w)])):
                    self.put(layer, spec, x, r.y - h + 1)
                    n += 1
                    x += w + step - 2
                    continue
            x += 1

    def edge_props(self, r, choices, side='s', step=3, solid=True, layer='Eşya', n_max=99, light=None):
        """Odanın DIŞ halkasına (duvar dibi; iç halka kaçış yolu olarak ayrılı kalır) sıra eşya. Yalnız TABAN satırı engel/serbest
        denetlenir, üst kısım yalnız görsel (kuzeyde duvar yüzünün önüne, güneyde iç halkanın üstüne taşar). side: n/s/w/e;
        w/e yalnız 1 hücre genişlikli seçimler. Dönüş: konan sayı."""
        t = self.lay.t
        n = 0
        cand = [c for c in choices if side in 'ns' or c[1][2] == 1]
        if not cand or r.w < 6 or r.h < 6:
            return 0
        if side in 'ns':
            yb = r.y if side == 'n' else r.y + r.h - 1
            pos = r.x
            while pos < r.x + r.w and n < n_max:
                spec = cand[(n + self.rng.randrange(len(cand))) % len(cand)]
                w, h = spec[1][2], spec[1][3]
                ok = pos + w <= r.x + r.w and self.is_free(pos, yb, w, 1)
                if ok and side == 'n':  # üstü duvar yüzünün önüne: yüzdeki meşale/kabartma/kemerle çakışmasın
                    ok = all(self.is_face(pos + i, yb - 1) for i in range(w)) and \
                        not any(self.occ[yy, pos + i] for yy in range(max(0, yb - h + 1), yb) for i in range(w))
                if ok and side == 's' and h > 1:
                    ok = all(t[yy, pos + i] == Z.F and not self.occ[yy, pos + i] for yy in range(yb - h + 1, yb) for i in range(w))
                if ok and (not solid or self.solidify([(pos + i, yb) for i in range(w)])):
                    self.put(layer, spec, pos, yb - h + 1)
                    if light is not None:
                        self.light((pos + w / 2.0) * 16, (yb - h / 2.0) * 16, light, r=70, energy=0.7)
                    n += 1
                    pos += w + step
                    continue
                pos += 1
        else:
            xb = r.x if side == 'w' else r.x + r.w - 1
            pos = r.y + 1
            while pos < r.y + r.h and n < n_max:
                spec = cand[(n + self.rng.randrange(len(cand))) % len(cand)]
                h = spec[1][3]
                yb = pos + h - 1
                ok = yb < r.y + r.h and self.is_free(xb, yb, 1, 1) and \
                    all(t[yy, xb] == Z.F and not self.occ[yy, xb] for yy in range(pos, yb))
                if ok and (not solid or self.solidify([(xb, yb)])):
                    self.put(layer, spec, xb, pos)
                    if light is not None:
                        self.light((xb + 0.5) * 16, (pos + h / 2.0) * 16, light, r=70, energy=0.7)
                    n += 1
                    pos += h + step
                    continue
                pos += 1
        return n

    def npc_spot(self, r, kind):
        """Sunağın soluna NPC (çalışma anında çizilir)."""
        alt = [o for o in self.objects if o['type'] == 'sunak' and r.x * 16 <= o['x'] < (r.x + r.w) * 16]
        if alt:
            o = alt[-1]
            x, y = o['x'] // 16 - 2, o['y'] // 16 - 1
        else:
            x, y = r.center()
        self.add_obj('npc', kind, x, y, 1, 1, tur=kind)
        self.solidify([(x, y)])

    def hide_spot_object(self, r, spec, name, layer='Eşya üst', rows=2, inset=1):
        """Büyük yumuşak nesne (et kökü vb.): alt `rows` satırı yürünür SAKLANMA hücresi (yanlardan `inset` hücre içeride).
        Açık lahit için layer='Eşya alt', rows=h-1, inset=0 (içine yatılır). Dönüş: konduysa True."""
        key, (sx, sy, w, h) = spec
        spots = [(x, y) for y in range(r.y, r.y + r.h - h + 1) for x in range(r.x, r.x + r.w - w + 1)]
        self.rng.shuffle(spots)
        for (x, y) in spots:
            if not self.is_free(x, y, w, h, allow_reserve=True):
                continue
            self.put(layer, spec, x, y)
            for j in range(h - rows, h):
                for i in range(inset, w - inset):
                    self.hide[y + j, x + i] = True
            self.add_obj('saklanma', name, x + inset, y + h - rows, w - 2 * inset, rows)
            return True
        return False

    def corridor_glow(self, choices, every=16, light=AMBER):
        """Koridor kenarına yürünür ışıyan süs (mantar) + zayıf ışık, en az `every` hücre arayla."""
        placed = []
        for (y, x) in self.corridor_cells():
            if any(abs(px - x) + abs(py - y) < every for (px, py) in placed):
                continue
            if not (self.lay.t[y - 1, x] == Z.S or self.lay.t[y, x - 1] == Z.S):
                continue
            spec = choices[len(placed) % len(choices)]
            w, h = spec[1][2], spec[1][3]
            if self.is_free(x, y, w, h, allow_reserve=True, allow_door=True):
                self.put('Zemin süsü', spec, x, y)
                self.light((x + w / 2.0) * 16, (y + h / 2.0) * 16, light, r=72, energy=0.55)
                placed.append((x, y))

    def corner_webs(self, r, key='web'):
        self._web_key = key
        segs = self._web_segments()
        if not segs:
            return
        big = [s for s in segs if s[3] >= 2 and s[2] >= 2]
        if not big:
            return
        spec = (self._web_key, big[self.rng.randrange(len(big))])
        w, h = spec[1][2], spec[1][3]
        for (x, flip) in ((r.x, False), (r.x + r.w - w, True)):
            if self.rng.random() < 0.65:
                self.put('Eşya üst', spec, x, r.y - 3, flip, occupy=False)

    def _web_segments(self):
        key = getattr(self, '_web_key', 'web')
        if getattr(self, '_webs_key', None) == key:
            return self._webs
        self._webs_key = key
        self._webs = []
        if key not in self.bank.sets:
            return self._webs
        img = self.bank.sets[key].img
        a = np.array(img.getchannel('A')) > 20
        seen = np.zeros(a.shape, bool)
        Hh, Ww = a.shape
        for y in range(Hh):
            for x in range(Ww):
                if a[y, x] and not seen[y, x]:
                    q = deque([(x, y)])
                    seen[y, x] = True
                    x0 = x1 = x
                    y0 = y1 = y
                    while q:
                        cx, cy = q.popleft()
                        x0, x1, y0, y1 = min(x0, cx), max(x1, cx), min(y0, cy), max(y1, cy)
                        for dy in (-1, 0, 1):
                            for dx in (-1, 0, 1):
                                nx, ny = cx + dx, cy + dy
                                if 0 <= nx < Ww and 0 <= ny < Hh and a[ny, nx] and not seen[ny, nx]:
                                    seen[ny, nx] = True
                                    q.append((nx, ny))
                    tx0, ty0 = x0 // 16, y0 // 16
                    self._webs.append((tx0, ty0, x1 // 16 - tx0 + 1, y1 // 16 - ty0 + 1))
        return self._webs

    def blob_scatter(self, r, choices, n, solid=False, light=None, vision=False, layer=None):
        """Organik (mağara) odalarda da aynı: sınır kutusu içinde rastgele, yalnız zemin hücrelerine."""
        self.scatter(r, choices, n, solid=solid, light=light, vision=vision, layer=layer)

    def blob_hide(self, r, spec, name):
        self.hide_spot_object(r, spec, name)

    def scatter(self, r, choices, n, solid=False, light=None, vision=False, layer=None):
        """vision: tabanı görüşü de keser (sarkıt, kristal sütunu - kovalamada göz teması koparır)."""
        placed = 0
        for _ in range(n * 30):
            if placed >= n:
                break
            spec = choices[self.rng.randrange(len(choices))]
            w, h = spec[1][2], spec[1][3]
            x = self.rng.randint(r.x, max(r.x, r.x + r.w - w))
            y = self.rng.randint(r.y, max(r.y, r.y + r.h - h))
            if not self.is_free(x, y, w, h, allow_reserve=not solid, allow_door=not solid):
                continue
            if solid:
                foot = [(x + i, y + h - 1) for i in range(w)] if h >= 2 else [(x + i, y) for i in range(w)]
                if vision and w >= 3:
                    foot = [(x + i, y + h - 1) for i in range(1, w - 1)] + ([(x + i, y + h - 2) for i in range(1, w - 1)] if h >= 3 else [])
                if not self.solidify(foot, val=1 if vision else 2):
                    continue
                self.put(layer or 'Eşya', spec, x, y)
            else:
                self.put(layer or 'Zemin süsü', spec, x, y)
            if light is not None:
                self.light((x + w / 2.0) * 16, (y + h * 0.4) * 16, light, r=70, energy=0.6, flicker=0)
            placed += 1

    def pillars(self, r, spec, spacing=4):
        key, (sx, sy, w, h) = spec
        for y in range(r.y + 3, r.y + r.h - 1, spacing):
            for x in range(r.x + 2, r.x + r.w - 2, spacing):
                if self.is_free(x, y - h + 2, w, h - 1) and self.solidify([(x, y), (x, y - 1)][:2], val=1):
                    self.put('Eşya', spec, x, y - h + 1)

    def hide_alcove(self, r, spec=None):
        """Kuzey yüzünde karanlık niş (kemer) + önündeki 2x2 zemin = saklanma."""
        spec = spec or ('arc', (14, 3, 2, 3))
        if spec[0] not in self.bank.sets:
            return
        w = spec[1][2]
        for x in range(r.x + 2, r.x + r.w - w - 1):
            if self.face_free(x, r.y - 3, w, 3) and self.is_free(x, r.y, w, 2, allow_reserve=True):
                self.put('Duvar süsü', spec, x, r.y - 3)
                for j in range(2):
                    for i in range(w):
                        self.hide[r.y + j, x + i] = True
                self.add_obj('saklanma', 'Gölge Nişi', x, r.y, w, 2)
                return

    def chest(self, r, elite=False):
        """Sandık (çalışma anında çizilir; açılınca oyunun normal / elit sandık düşüşü). Kuzey duvar dibi, yoksa oda içi."""
        spots = [(x, r.y) for x in range(r.x + 1, r.x + r.w - 2)]
        self.rng.shuffle(spots)
        rest = [(x, y) for y in range(r.y + 1, r.y + r.h - 2) for x in range(r.x + 1, r.x + r.w - 2)]
        self.rng.shuffle(rest)
        t = self.lay.t
        for (x, y) in spots + rest:
            # yalnız üst (engelli) satır serbest/ayrılmamış olmalı; alt yarı görsel, iç halkanın üstüne taşabilir (yürünür kalır)
            if y + 1 >= t.shape[0] or not all(t[y + 1, x + i] == Z.F and not self.occ[y + 1, x + i] for i in range(2)):
                continue
            if self.is_free(x, y, 2, 1) and self.solidify([(x, y), (x + 1, y)]):
                self.occ[y:y + 2, x:x + 2] = True
                self.add_obj('sandik', 'Elit Sandık' if elite else 'Sandık', x, y, 2, 2, elit=1 if elite else 0)
                return True
        self.notes.append('UYARI: oda %d sandık yeri yok' % r.id)
        return False

    # ---------------------------------------------------------------- koridorlar
    def corridor_cells(self):
        lay = self.lay
        return np.argwhere((lay.corr_id >= 0) & (lay.room_id < 0) & (lay.t == Z.F))

    def corridor_dressing(self, choices, density=0.01):
        for (y, x) in self.corridor_cells():
            if self.rng.random() < density:
                spec = choices[self.rng.randrange(len(choices))]
                w, h = spec[1][2], spec[1][3]
                if self.is_free(x, y, w, h, allow_reserve=True, allow_door=True):
                    self.put('Zemin süsü', spec, x, y)

    def corridor_torches(self, choices, every=14, light=CYAN):
        """Yatay koridorların kuzey yüzüne meşale: aynı satırda en az `every` hücre arayla (başka meşaleye 6 hücreden yakın değil)."""
        count = 0
        last = {}
        placed = []
        for (y, x) in sorted(self.corridor_cells().tolist(), key=lambda c: (c[0], c[1])):
            if y < 4 or not all(self.is_face(x + i, y - 3, 3) and self.is_face(x + i, y - 1, 1) for i in range(2)):
                continue
            if x - last.get(y, -999) < every:
                continue
            if any(abs(px - x) < 6 and abs(py - y) < 4 for (px, py) in placed):
                continue
            if not self.face_free(x, y - 3, 2, 3):
                continue
            spec = choices[count % len(choices)]
            self.put('Duvar süsü', spec, x, y - 3)
            self.light((x + 1) * 16, (y - 1.8) * 16, light, r=100, energy=0.8)
            last[y] = x
            placed.append((x, y))
            count += 1

    def corridor_face_decor(self, choices, every=11, layer='Duvar süsü', rows=3):
        """Koridorların kuzey duvar yüzüne aralıklı yüz süsü (kemer, pencere, kabartma, boru...): yüzün alt satırı koridor zemininin
        hemen üstünde; süs alttan hizalı (h satır). rows: yüz yüksekliği (2 ya da 3). Koridora engel konmaz (kaçış yolu)."""
        placed = []
        n = 0
        cells = sorted(self.corridor_cells().tolist(), key=lambda c: (c[0], c[1]))
        for (y, x) in cells:
            spec = choices[n % len(choices)]
            w, h = spec[1][2], spec[1][3]
            if y < rows + 1 or not all(self.is_face(x + i, y - 1, 1) and self.is_face(x + i, y - rows, rows) for i in range(w)):
                continue
            if any(abs(px - x) < every and abs(py - y) < 4 for (px, py) in placed):
                continue
            top = y - h
            if not self.face_free(x, top, w, h):
                continue
            self.put(layer, spec, x, top)
            placed.append((x, y))
            n += 1

    GATE_NAMES = {'parmaklik': 'Parmaklık', 'diken': 'Diken Bariyeri', 'kafes': 'Kafes Kapı', 'et': 'Et Duvarı',
                  'kristal': 'Kristal Duvar', 'demir': 'Demir Kapı', 'barikat': 'Tahta Barikat'}

    def _to_wall(self, cells):
        """Zemin hücrelerini duvara çevirir; üstlerine önceden konmuş zemin süsü / eşya karoları silinir."""
        for (x, y) in cells:
            self.lay.t[y, x] = Z.S
            self.occ[y, x] = True
            for name in ('Zemin süsü', 'Zemin ayrıntı', 'Eşya alt', 'Eşya'):
                if name in self.tl.L:
                    self.tl.put(name, x, y, 0)

    def gates(self, max_count=6, styles=('parmaklik', 'diken'), min_dist=22, ns_narrow=True):
        """Kapanan kapılar: (a) odaya KUZEYDEN giren dikey koridorun ağzı (styles[0]; ns_narrow: 2 geniş kapı, koridor 3. sütunda
        daraltılır - değilse 3 geniş), (b) düz yatay koridor kesiti (styles[1], 1x3). Kaçış: kapılar koridorda; grafik köprüsüz olduğundan tek
        kapı kimseyi hapsetmez (escape_report kapı başına denetler)."""
        ns_style, ew_style = styles[0], styles[1]
        lay = self.lay
        t = lay.t
        cands = []
        for r in lay.rooms:
            y = r.y - 1
            x = r.x
            while x < r.x + r.w:
                if t[y, x] == Z.F and lay.room_id[y, x] < 0:
                    x2 = x
                    while x2 < r.x + r.w and t[y, x2] == Z.F and lay.room_id[y, x2] < 0:
                        x2 += 1
                    wdt = x2 - x
                    if 3 <= wdt <= 6 and all(t[r.y - 1 - j, x + i] == Z.F for i in range(wdt) for j in range(4)) and \
                            all(t[r.y - 1 - j, x - 1] == Z.S and t[r.y - 1 - j, x + wdt] == Z.S for j in range(4)):
                        cands.append(('ns', x, r.y - 3, (r, wdt)))
                    x = x2
                else:
                    x += 1
        for (y, x) in self.corridor_cells():
            if x < 3 or x > t.shape[1] - 4 or t[y - 1, x] != Z.S:
                continue
            h = 0
            while y + h < t.shape[0] and t[y + h, x] == Z.F:
                h += 1
            if not (3 <= h <= 6) or y + h >= t.shape[0] or t[y + h, x] != Z.S:
                continue
            pat = [Z.S] + [Z.F] * h + [Z.S]
            if all([t[y + j, x + d] for j in range(-1, h + 1)] == pat for d in (-2, -1, 1, 2)):
                cands.append(('ew', x, y, h))
        self.rng.shuffle(cands)
        chosen = []
        # önce kuzey ağızları (en çok max_count - 2), sonra yatay kesitler: iki tarz da bulunsun
        for want, limit in (('ns', max_count - 2), ('ew', max_count), ('ns', max_count)):
            for c in cands:
                if len(chosen) >= limit or c[0] != want or c in chosen:
                    continue
                if any(math.dist((c[1], c[2]), (o[1], o[2])) < min_dist for o in chosen):
                    continue
                chosen.append(c)
        for (kind, x, y, extra) in chosen:
            if kind == 'ns':
                gw = 2 if ns_narrow else 3
                wdt = extra[1]
                if wdt > gw:
                    # kapı yerinde koridor iki yandan DUVAR PAYANDASIYLA kapı genişliğine daralır (geniş koridor, madde 376), geri boya
                    left = (wdt - gw) // 2
                    self._to_wall([(x + i, y + j) for j in range(3) for i in range(wdt) if not (left <= i < left + gw)])
                    self.repaint(x - 1, y - 2, x + wdt + 1, y + 4)
                    x += left
                cells = [(x + i, y + j) for i in range(gw) for j in range(3)]
                for (cx, cy) in cells:
                    self.gate[cy, cx] = True
                    self.occ[cy, cx] = True
                if not ns_narrow:
                    for j in range(-1, 3):
                        for i in (-1, gw):
                            if 0 <= y + j < t.shape[0]:
                                self.occ[y + j, x + i] = True
                self.add_obj('kapi', self.GATE_NAMES.get(ns_style, ns_style), x, y, gw, 3, stil=ns_style)
            else:
                h = extra
                if h > 3:
                    # yatay koridor 3 satıra daralır: alt satırlar (x-1..x+1) aşağıdaki duvara katılır (yüz oluşmaz), geri boya
                    self._to_wall([(x + i, y + j) for j in range(3, h) for i in (-1, 0, 1)])
                    self.repaint(x - 3, y - 2, x + 4, y + h + 2)
                cells = [(x, y + j) for j in range(3)]
                for (cx, cy) in cells:
                    self.gate[cy, cx] = True
                    self.occ[cy, cx] = True
                self.add_obj('kapi', self.GATE_NAMES.get(ew_style, ew_style), x, y, 1, 3, stil=ew_style)
        if len(chosen) < max_count:
            self.notes.append('kapı %d/%d' % (len(chosen), max_count))

    def traps(self, kind, count=5, min_dist=18):
        lay = self.lay
        t = lay.t
        cands = []
        for (y, x) in self.corridor_cells():
            if x < 3 or x > t.shape[1] - 5 or t[y - 1, x] != Z.S:
                continue
            h = 0
            while y + h < t.shape[0] and t[y + h, x] == Z.F:
                h += 1
            if not (3 <= h <= 6):
                continue
            pat = [Z.S] + [Z.F] * h + [Z.S]
            ok = all([t[y + j, x + d] if y + j < t.shape[0] else Z.S for j in range(-1, h + 1)] == pat for d in range(-1, 4))
            yy = y + (h - 3) // 2  # geniş koridorda ortada: kenarından dolaşılabilir
            if ok and not self.gate[y:y + h, x - 3:x + 6].any() and not self.occ[yy:yy + 3, x:x + 3].any():
                cands.append((x, yy))
        self.rng.shuffle(cands)
        chosen = []
        for c in cands:
            if len(chosen) >= count:
                break
            if any(math.dist(c, o) < min_dist for o in chosen):
                continue
            if any(o['type'] in ('kapi',) and math.dist(c, obj_center_cell(o)) < 10 for o in self.objects):
                continue
            chosen.append(c)
        for (x, y) in chosen:
            for j in range(3):
                for i in range(3):
                    self.occ[y + j, x + i] = True
            self.add_obj('tuzak', kind, x, y, 3, 3, tur=kind)

    def hunter_route(self, name):
        big = [r for r in self.lay.rooms if r.kind not in ('oda',)]
        if not big:
            return
        start = min(big, key=lambda r: r.center()[1])
        route = [start]
        rest = [r for r in big if r is not start]
        while rest:
            last = route[-1].center()
            nxt = min(rest, key=lambda r: math.dist(r.center(), last))
            route.append(nxt)
            rest.remove(nxt)
        pts = ';'.join('%d,%d' % (r.center()[0] * 16 + 8, r.center()[1] * 16 + 8) for r in route if r.kind != 'giris')
        far = max(big, key=lambda r: r.center()[1])
        self.add_obj('avci', name, far.center()[0], far.center()[1], 1, 1, rota=pts, tur=name)
