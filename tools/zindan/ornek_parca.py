# ÖRNEK PARÇALARI (madde 447): setlerin KENDİ örnek haritalarından (Dungeon3 / Inside / Outside / Hapishane Interior / Dungeon1 / Cave /
# Glowing_cave) kırpılan oda parçaları. Ressamın dizdiği katmanlar hücre hücre AYNEN kalır; tema haritası bu parçaları dizer, aralarına koridor
# boyar. Bir parça:
#   - katman ROLÜ (ada göre): 'base' (karakterin altında: su, zemin, ayrıntı, duvar, duvar altı eşya), 'depth' (derinlikli eşya: ayak sırasıyla
#     karakteri örter), 'skip' (örnekteki karakter / NPC animasyonları);
#   - hücre SINIFI: S duvar/boşluk (hareket + görüş), F zemin, W su/lav (yalnız hareket), O eşya engeli (eşyanın taban satırı);
#   - MÜHÜR: kırpma kenarı odanın ortasından geçebilir; kenar şeridi (üst 3 satır = yüz payı, alt / yanlar 1) kapı ağızları dışında duvara
#     çevrilir ve harita ressamı (paint_walls_34) yeniden boyar; şeride değen eşyalar düşer (yarım eşya kalmaz);
#   - KAPI AĞIZLARI: kenarı geçen 3-6 hücrelik zemin koşuları (daha genişse ortasında 4 hücrelik ağız açılır); koridor buradan bağlanır.
# Kullanım (sınıflandırma bindirmesi): python tools/zindan/ornek_parca.py <tmx> <bindirme.png>
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ornek_tmx as OT  # noqa: E402

S, F, W, O = 0, 1, 2, 3
SEAL_TOP, SEAL_SIDE, SEAL_BOTTOM = 3, 1, 1
PORT_MIN, PORT_MAX, PORT_OPEN = 3, 6, 4
CARVE_MAX = 8  ## oyulmuş kapı ağzı en çok bu kadar hücre deler (duvar / eşya / ayrı bölme; su değil)

SKIP_KEYS = ('guard', 'prisoner', 'chief', 'thief', 'undead', 'poor_man', 'character')
DEPTH_KEYS = ('object', 'torch', 'light', 'web', 'lever', 'column', 'rock', 'front', 'statue', 'coffin', 'candle')
FLOOR_KEYS = ('floor', 'ground', 'surface')
WATER_LAYER_KEYS = ('water', 'lava', 'bottom')
WALL_DECOR = ('mushroom', 'shinies', 'window')
PASS_SHEETS = ('door',)  ## kapı karoları geçilebilir (açık kapı / kemer ağzı)
SOLID_MIN_CELLS = 2      ## tek hücrelik süsler (mum, kafatası) yürünür
## duvara asılı / yerde yassı / ışık eşyaları engel sayılmaz (meşale, mum, kabartma, tuzak, ağ, ateş, ışıltı, kol)
NONSOLID_SHEETS = ('torch', 'candle', 'relief', 'trap', 'spike', 'web', 'fire', 'wisp', 'shinies', 'lever', 'light', 'window')


def label4(mask):
    """4 komşulu bileşen etiketleri (0 = dışarıda)."""
    h, w = mask.shape
    lab = np.zeros((h, w), np.int32)
    n = 0
    for y in range(h):
        for x in range(w):
            if mask[y, x] and lab[y, x] == 0:
                n += 1
                st = [(x, y)]
                lab[y, x] = n
                while st:
                    cx, cy = st.pop()
                    for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                        if 0 <= nx < w and 0 <= ny < h and mask[ny, nx] and lab[ny, nx] == 0:
                            lab[ny, nx] = n
                            st.append((nx, ny))
    return lab


def layer_role(name):
    low = name.lower()
    if any(k in low for k in SKIP_KEYS):
        return 'skip'
    if 'under' in low:
        return 'base'
    if any(k in low for k in DEPTH_KEYS):
        return 'depth'
    return 'base'


def _is_wall_layer(low):
    return 'wall' in low and 'under' not in low and not any(k in low for k in WALL_DECOR) and 'front' not in low


def objects_of(smp, cells):
    """Katmandaki eşyalar = atlasta komşu karolar (aynı sayfa + aynı çevirme), depth_occluders.object_bases ile AYNI kural. [[(x, y)]]."""
    info = {}
    for (x, y), g in cells.items():
        sh, lid = smp.sheet_of(g)
        if sh is None:
            continue
        info[(x, y)] = (sh.firstgid, lid % sh.cols, lid // sh.cols, bool(g & OT.FH))
    parent = {c: c for c in info}

    def find(c):
        while parent[c] != c:
            parent[c] = parent[parent[c]]
            c = parent[c]
        return c

    for (x, y), (sid, col, row, fh) in info.items():
        r = info.get((x + 1, y))
        if r and r[0] == sid and r[3] == fh and r[2] == row and r[1] == col + (-1 if fh else 1):
            parent[find((x + 1, y))] = find((x, y))
        d = info.get((x, y + 1))
        if d and d[0] == sid and d[3] == fh and d[1] == col and d[2] == row + 1:
            parent[find((x, y + 1))] = find((x, y))
    groups = {}
    for c in info:
        groups.setdefault(find(c), []).append(c)
    return list(groups.values())


class SampleInfo:
    """Örneğin tamamı: hücre sınıfı + katmanlar (rol, ad, {(x, y): gid}) + eşya grupları; koordinatlar örneğin sol üstüne göre (0..w, 0..h)."""

    def __init__(self, key, path, bridges=False):
        self.key, self.path = key, path
        smp = OT.Sample(path)
        self.smp = smp
        self.w, self.h = smp.x1 - smp.x0, smp.y1 - smp.y0
        self.layers = []
        for name, cells in smp.layers:
            rel = {(x - smp.x0, y - smp.y0): g for (x, y), g in cells.items()}
            self.layers.append((layer_role(name), name, rel))
        self.cls, self.solid = self._classify()
        if bridges:
            self._bridges()
            self.cls, self.solid = self._open_passages(self.cls)
        self.void = np.ones((self.h, self.w), bool)
        for role, _, cells in self.layers:
            if role == 'skip':
                continue
            for (x, y) in cells:
                self.void[y, x] = False

    def _open_passages(self, grid):
        """Geçit açma: iki ayrı zemin bölgesine değen eşya tabanı yürünür olur (örnekte o geçit yürünüyordu; engel kuralımız kaba)."""
        h, w = grid.shape
        bases = self._bases
        while True:
            lab = label4(grid == F)
            hit = None
            for b in bases:
                if not any(grid[y, x] == O for (x, y) in b):
                    continue
                nb = set()
                for (x, y) in b:
                    for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                        if 0 <= nx < w and 0 <= ny < h and lab[ny, nx] > 0:
                            nb.add(int(lab[ny, nx]))
                if len(nb) >= 2:
                    hit = b
                    break
            if hit is None:
                break
            for (x, y) in hit:
                if grid[y, x] == O:
                    grid[y, x] = F
        solid = grid == O
        return grid, solid

    def _bridges(self):
        """Suyun üstüne yatan eşya = KÖPRÜ (lağım tahtaları; yalnız köprülü örneklerde): hücreleri yürünür zemin olur ve karakterin ALTINDA çizilir
        (derinlikli katmandan aynı sıradaki bir taban katmanına taşınır; üstünde yürüyeni örtmesin)."""
        smp = self.smp
        g = self.cls
        h, w = g.shape
        out = []
        for role, name, cells in self.layers:
            out.append((role, name, cells))
            if role != 'depth':
                continue
            flat = {}
            for grp in objects_of(smp, {(x + smp.x0, y + smp.y0): v for (x, y), v in cells.items()}):
                pts = [(x - smp.x0, y - smp.y0) for (x, y) in grp]
                wet = [p for p in pts if g[p[1], p[0]] == W]
                if len(pts) < 2 or len(wet) * 2 < len(pts):
                    continue
                for p in pts:
                    flat[p] = cells.pop(p)
                    if g[p[1], p[0]] in (W, O):
                        g[p[1], p[0]] = F
            if flat:
                out.append(('base', name + ' köprü', flat))
        self.layers = out
        self.solid = g == O

    def _classify(self):
        smp = self.smp
        w, h = self.w, self.h
        floor = np.zeros((h, w), bool)
        wall = np.zeros((h, w), bool)
        water = np.zeros((h, w), bool)
        bases = []
        for role, name, cells in self.layers:
            low = name.lower()
            if role == 'skip':
                continue
            for (x, y), g in cells.items():
                sh, _ = smp.sheet_of(g)
                shn = (sh.name if sh else '').lower()
                if role == 'base' and _is_wall_layer(low):
                    if any(k in shn for k in PASS_SHEETS):
                        floor[y, x] = True
                    else:
                        wall[y, x] = True
                elif role == 'base' and any(k in low for k in FLOOR_KEYS) and 'water_floor' not in low:
                    floor[y, x] = True
                elif role == 'base' and (any(k in low for k in WATER_LAYER_KEYS) or 'under_water' in low):
                    water[y, x] = True
            if role == 'depth':
                # eşyanın taban satırı engel (3/4 bakış: gövde üstte çizilir); tek hücrelik / tek satırlık / asılı süsler yürünür
                for grp in objects_of(smp, {(x + smp.x0, y + smp.y0): g for (x, y), g in cells.items()}):
                    ys = [c[1] for c in grp]
                    if len(grp) < SOLID_MIN_CELLS or max(ys) == min(ys):
                        continue
                    sh, _ = smp.sheet_of(cells[(grp[0][0] - smp.x0, grp[0][1] - smp.y0)])
                    if sh is not None and any(k in sh.name.lower() for k in NONSOLID_SHEETS):
                        continue
                    by = max(ys)
                    bases.append([(x - smp.x0, y - smp.y0) for (x, y) in grp if y == by])
        grid = np.full((h, w), S, np.uint8)
        grid[water & ~floor] = W
        grid[floor] = F
        grid[wall] = S
        for b in bases:
            for (x, y) in b:
                if grid[y, x] == F:
                    grid[y, x] = O
        self._bases = bases
        return self._open_passages(grid)


class Piece:
    """Örneğin (x0, y0, x1, y1) kırpması, isteğe göre yatay aynalı. cls / band / ports parça koordinatında."""

    def __init__(self, info, rect, name, kind='oda', flip=False, ports=None):
        self.info, self.name, self.kind, self.flip = info, name, kind, flip
        x0, y0, x1, y1 = rect
        self.rect = rect
        self.w, self.h = x1 - x0, y1 - y0
        cls = info.cls[y0:y1, x0:x1].copy()
        void = info.void[y0:y1, x0:x1].copy()
        if flip:
            cls, void = cls[:, ::-1].copy(), void[:, ::-1].copy()
        self.cls, self.void = cls, void
        self.want_ports = ports  # None: otomatik; yoksa [('n'|'s'|'w'|'e', başlangıç, genişlik)]
        self._seal_and_ports()
        self._cut_layers()

    def _sx(self, x):
        """Parça x -> örnek x."""
        return self.rect[0] + ((self.w - 1 - x) if self.flip else x)

    def _seal_and_ports(self):
        w, h = self.w, self.h
        band = np.zeros((h, w), bool)
        band[:SEAL_TOP, :] = True
        band[h - SEAL_BOTTOM:, :] = True
        band[:, :SEAL_SIDE] = True
        band[:, w - SEAL_SIDE:] = True
        open_ = self.cls != S
        ports = []
        for side in 'nswe':
            line = {'n': open_[0, :], 's': open_[h - 1, :], 'w': open_[:, 0], 'e': open_[:, w - 1]}[side]
            deep = {'n': open_[:SEAL_TOP + 1, :].all(axis=0), 's': open_[h - 2:, :].all(axis=0),
                    'w': open_[:, :2].all(axis=1), 'e': open_[:, w - 2:].all(axis=1)}[side]
            ok = line & deep & (self._row_or_col_cls(side) == F)
            i, n = 0, len(ok)
            while i < n:
                if not ok[i]:
                    i += 1
                    continue
                j = i
                while j < n and ok[j]:
                    j += 1
                run = j - i
                lo = 3 if side in 'we' else 2  # yan kapı ağzında yüz payı: koşunun üstünde 3 satır duvar kalmalı
                if run >= PORT_MIN:
                    a, b = i, j
                    if run > PORT_MAX:
                        a = i + (run - PORT_OPEN) // 2
                        b = a + PORT_OPEN
                    if side in 'we' and a < lo:
                        a = lo
                    if b - a >= PORT_MIN:
                        ports.append((side, a, b - a))
                i = j
        if self.want_ports is not None:
            ports = [p for p in ports if any(p[0] == q[0] and abs(p[1] - q[1]) <= 2 for q in self.want_ports)]
        ports = [(s, a, n, []) for (s, a, n) in ports]

        def unseal(bd, side, a, n):
            if side == 'n':
                bd[:SEAL_TOP, a:a + n] = False
            elif side == 's':
                bd[h - SEAL_BOTTOM:, a:a + n] = False
            elif side == 'w':
                bd[a:a + n, :SEAL_SIDE] = False
            else:
                bd[a:a + n, w - SEAL_SIDE:] = False

        for (side, a, n, _) in ports:
            unseal(band, side, a, n)
        # mühürden SONRA ana zemin bölgesi (mühür odayı bölebilir: kenar şeridinden dolaşan yol kapanır)
        self.cls[band] = S
        lab = label4(self.cls == F)
        main = int(np.bincount(lab[lab > 0]).argmax()) if lab.max() > 0 else -1
        self._lab, self._main = lab, main
        keep = []
        for (side, a, n, cells) in ports:
            d = SEAL_TOP if side == 'n' else 1
            inner = [self._side_cell(side, a + i, d) for i in range(n)]
            if any(0 <= x < w and 0 <= y < h and lab[y, x] == main for (x, y) in inner):
                keep.append((side, a, n, cells))
            else:
                # ana bölgeye açılmayan doğal ağız mühürlenir
                if side == 'n':
                    band[:SEAL_TOP, a:a + n] = True
                elif side == 's':
                    band[h - SEAL_BOTTOM:, a:a + n] = True
                elif side == 'w':
                    band[a:a + n, :SEAL_SIDE] = True
                else:
                    band[a:a + n, w - SEAL_SIDE:] = True
                self.cls[band] = S
        ports = keep
        # ana bölgeye ağzı olmayan kenara OYULMUŞ ağız: kenardan içeri en çok CARVE_MAX hücre delinip ana zemine varılır; kanal + iki yanı
        # (yan kapıda üstte yüz payı) ressama bırakılır (duvar köşeleri / yüzler kanala göre yeniden boyanır)
        have = {p[0] for p in ports}
        repaint = np.zeros((h, w), bool)
        for side in 'nswe':
            if side in have:
                continue
            c = self._carve_port(side)
            if c is None:
                continue
            a, n, d = c
            cells = []
            for k in range(d):
                for i in range(n):
                    cells.append(self._side_cell(side, a + i, k))
            for (x, y) in cells:
                self.cls[y, x] = F
                repaint[y, x] = True
                band[y, x] = False
            for k in range(d + 1):
                for i in ([-1, n] if side in 'ns' else [-3, -2, -1, n]):
                    x, y = self._side_cell(side, a + i, k)
                    if 0 <= x < w and 0 <= y < h and self.cls[y, x] == S:
                        repaint[y, x] = True
            ports.append((side, a, n, cells))
        self.ports = ports
        # mühür: şerit duvar olur + karoları ressama bırakılır (yalnız zaten tamamen boş olan hücreler değil: onlar boşluk kalır)
        # (boş hücreler de: ressamın yüzü / tepesi parça içinde kalsın; yoksa dışarıda yüzsüz tepe çizgisi havada kalıyordu)
        self.band = band | repaint

    def _side_cell(self, side, along, depth):
        """Kenar boyunca `along`, içeri `depth` -> parça (x, y)."""
        if side == 'n':
            return along, depth
        if side == 's':
            return along, self.h - 1 - depth
        if side == 'w':
            return depth, along
        return self.w - 1 - depth, along

    def _carve_port(self, side):
        """(başlangıç, genişlik, derinlik): kenardan içeri yalnız duvar (S) delinerek PORT_OPEN genişliğinde zemine varılan en sığ yer."""
        n = PORT_OPEN
        length = self.w if side in 'ns' else self.h
        lo, hi = (2, length - n - 2) if side in 'ns' else (4, length - n - 2)
        mid = (lo + hi) / 2.0
        best = None
        for a in range(lo, hi + 1):
            for d in range(1, CARVE_MAX + 1):
                row = [self._side_cell(side, a + i, d) for i in range(n)]
                if not all(0 <= x < self.w and 0 <= y < self.h for (x, y) in row):
                    break
                if all(self.cls[y, x] == F and self._lab[y, x] == self._main for (x, y) in row):
                    # içerideki zemin en az 2 sıra derin olmalı (köşeye değil odaya açılsın)
                    row2 = [self._side_cell(side, a + i, d + 1) for i in range(n)]
                    if all(0 <= x < self.w and 0 <= y < self.h and self.cls[y, x] != S for (x, y) in row2):
                        sc = (d, abs(a + n / 2.0 - mid))
                        if best is None or sc < best[0]:
                            best = (sc, a, d)
                    break
                if any(self.cls[y, x] == W for (x, y) in row):
                    break
        if best is None:
            return None
        return best[1], n, best[2]

    def _row_or_col_cls(self, side):
        c = self.cls
        return {'n': c[0, :], 's': c[-1, :], 'w': c[:, 0], 'e': c[:, -1]}[side]

    def _cut_layers(self):
        """Parça koordinatında katmanlar [(rol, ad, {(x, y): gid})]: mühür şeridine değen eşya grupları atılır, şerit hücreleri boşaltılır."""
        info = self.info
        smp = info.smp
        x0, y0, x1, y1 = self.rect
        out = []
        for role, name, cells in info.layers:
            if role == 'skip':
                continue
            sub = {(x, y): g for (x, y), g in cells.items() if x0 <= x < x1 and y0 <= y < y1}
            drop = set()
            if role == 'depth':
                for grp in objects_of(smp, {(x + smp.x0, y + smp.y0): g for (x, y), g in cells.items()}):
                    pts = [(x - smp.x0, y - smp.y0) for (x, y) in grp]
                    inside = [p for p in pts if x0 <= p[0] < x1 and y0 <= p[1] < y1]
                    if len(inside) < len(pts) or any(self.band[p[1] - y0, self._px(p[0])] for p in inside):
                        drop.update(inside)
            rel = {}
            for (x, y), g in sub.items():
                if (x, y) in drop:
                    continue
                px, py = self._px(x), y - y0
                if self.band[py, px]:
                    continue
                rel[(px, py)] = (g ^ OT.FH) if self.flip else g
            out.append((role, name, rel))
        self.layers = out
        # düşen eşyaların engeli de kalkar
        solid_left = np.zeros((self.h, self.w), bool)
        for role, name, rel in out:
            if role != 'depth':
                continue
            for grp in objects_of(_FlipSample(smp, self), {(x, y): g for (x, y), g in rel.items()}):
                ys = [c[1] for c in grp]
                if len(grp) < SOLID_MIN_CELLS or max(ys) == min(ys):
                    continue
                for (x, y) in grp:
                    if y == max(ys):
                        solid_left[y, x] = True
        o = self.cls == O
        self.cls[o & ~solid_left] = F

    def _px(self, sx):
        """Örnek x -> parça x."""
        x = sx - self.rect[0]
        return (self.w - 1 - x) if self.flip else x


class _FlipSample:
    """objects_of için sayfa çözücü (parça koordinatında çevirme bayrağı zaten gid'de)."""

    def __init__(self, smp, piece):
        self.smp = smp

    def sheet_of(self, g):
        return self.smp.sheet_of(g)


def overlay_grid(img, grid, cell=16):
    col = {S: (220, 40, 40, 90), W: (40, 120, 255, 120), O: (255, 170, 30, 160)}
    ov = Image.new('RGBA', img.size, (0, 0, 0, 0))
    px = ov.load()
    h, w = grid.shape
    for y in range(h):
        for x in range(w):
            c = col.get(int(grid[y, x]))
            if c is None:
                continue
            for j in range(cell):
                for i in range(cell):
                    if i in (0, cell - 1) or j in (0, cell - 1) or (i + j) % 4 == 0:
                        px[x * cell + i, y * cell + j] = c
    out = img.convert('RGBA')
    out.alpha_composite(ov)
    return out


if __name__ == '__main__':
    inf = SampleInfo('ornek', sys.argv[1])
    vals, cnt = np.unique(inf.cls, return_counts=True)
    print({k: int(c) for k, c in zip(vals, cnt)})
    overlay_grid(inf.smp.render(), inf.cls).save(sys.argv[2])
