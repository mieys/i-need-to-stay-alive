import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
"""DIS CERCEVE adim 1: zemin / su / gorunmez engel halkasi (agaclar ring_trees.py'de). CLAUDE.md madde 119."""
import os, sys
import numpy as np
from ring_core import *

SU = 'Su/Su'
WATER_LAYERS = ['Su/Su altı', 'Su/Su collisionsuz', 'Su/Su', 'Su/Su ayrıntılar 2', 'Su/Su ayrıntılar 3', 'Su/Su ayrıntıları 4']
GROUND_DIRT, GROUND_GRASS = 'Yer/Zemin Toprak', 'Yer/Zemin Çimen'
WALL = 'Orman parçaları/Orman parçaları'
DIRT_GID = 78          # Ground_grass #77 (duz toprak)
GRASS_GID = 135        # Ground_grass #134 (cimen ic)
WALL_GID = 341         # Ground_grass #340 = TAMAMEN SAYDAM karo -> orman katmaninda "dolu" hucre = engel + gorus engeli, gorunmez (CLAUDE.md madde 119)
# duz cimen kenar parcalari (Ground_grass kimligi+1): cimenin SAGI/SOLU/ALTI/USTU boslukla bitiyorsa
INNER = {'TR': 156, 'TL': 157, 'BR': 137, 'BL': 138}   # ic kose parcalari (Ground_grass #155/#156/#136/#137, +1)
EDGE = {'L': 134, 'R': 136, 'T': 116, 'B': 154, 'TL': 115, 'TR': 117, 'BL': 153, 'BR': 155}


def is_blue(ts, gid):
    t = ts.tile(gid)
    if t is None:
        return False
    a = np.array(t)
    m = a[..., 3] > 128
    if not m.any():
        return False
    r, g, b = [a[..., i][m].astype(float).mean() for i in range(3)]
    return b > g + 8 and b > r + 25


_seam_cache = {}
def seamless(ts, gid, axis):
    """Karo bu eksende kendi kendine dikissiz tekrarlanir mi? axis 'v': ust satir ~ alt satir (dikey tekrar), 'h': sol sutun ~ sag sutun."""
    key = (gid, axis)
    if key in _seam_cache:
        return _seam_cache[key]
    t = ts.tile(gid)
    if t is None:
        r = True
    else:
        a = np.array(t).astype(int)
        e0, e1 = (a[0], a[15]) if axis == 'v' else (a[:, 0], a[:, 15])
        diff = (np.abs(e0 - e1).max(axis=1) > 24)
        r = int(diff.sum()) <= 1
    _seam_cache[key] = r
    return r


def runs_filter(arr, min_run):
    """1B bool dizide min_run'dan kisa kosulari komsu degere cevir."""
    a = arr.copy()
    n = len(a)
    changed = True
    while changed:
        changed = False
        i = 0
        while i < n:
            j = i
            while j + 1 < n and a[j + 1] == a[i]:
                j += 1
            if j - i + 1 < min_run and not (i == 0 and j == n - 1):
                if i > 0:
                    a[i:j + 1] = a[i - 1]
                else:
                    a[i:j + 1] = a[j + 1]
                changed = True
                break
            i = j + 1
    return a


def edge_grass_profiles(ts, g_grass):
    """4 kenar icin 1B 'cimen mi' profilleri (kenara yakin 3 hucrenin cogunlugu, kisa kosular silinir)."""
    ok = np.zeros((PLAY, PLAY), bool)
    ys, xs = np.nonzero(g_grass)
    for y, x in zip(ys, xs):
        t = ts.find(int(g_grass[y, x]) & 0x0FFFFFFF)
        ok[y, x] = bool(t) and t[1] != 'Water_coasts.tsx'
    prof = {}
    prof['N'] = runs_filter(ok[0:3, :].sum(axis=0) >= 2, 6)
    prof['S'] = runs_filter(ok[PLAY - 3:PLAY, :].sum(axis=0) >= 2, 6)
    prof['W'] = runs_filter(ok[:, 0:3].sum(axis=1) >= 2, 6)
    prof['E'] = runs_filter(ok[:, PLAY - 3:PLAY].sum(axis=1) >= 2, 6)
    return prof


def ring_grass_mask(prof):
    """(H2,W2) bool: halka hucresi cimen mi (oyun alani False)."""
    m = np.zeros((H2, W2), bool)
    for y in range(Y0, Y0 + H2):
        for x in range(X0, X0 + W2):
            if 0 <= x < PLAY and 0 <= y < PLAY:
                continue
            if y < 0 and 0 <= x < PLAY:
                v = prof['N'][x]
            elif y >= PLAY and 0 <= x < PLAY:
                v = prof['S'][x]
            elif x < 0 and 0 <= y < PLAY:
                v = prof['W'][y]
            elif x >= PLAY and 0 <= y < PLAY:
                v = prof['E'][y]
            elif x < 0 and y < 0:
                v = prof['W'][0]
            elif x < 0:
                v = prof['W'][PLAY - 1]
            elif y < 0:
                v = prof['E'][0]
            else:
                v = prof['E'][PLAY - 1]
            m[y - Y0, x - X0] = v
    return m


FLAG_H, FLAG_V = 0x80000000, 0x40000000


def mirror_src(x, y):
    """Halka hucresi (mutlak x,y) -> oyun alanindaki ayna hucre + hangi eksenlerde yansidigi."""
    mx = my = False
    sx, sy = x, y
    if x < 0:
        sx, mx = -x - 1, True
    elif x >= PLAY:
        sx, mx = 2 * PLAY - 1 - x, True
    if y < 0:
        sy, my = -y - 1, True
    elif y >= PLAY:
        sy, my = 2 * PLAY - 1 - y, True
    return sx, sy, mx, my


def mirrored_gid(v, mx, my):
    """Karonun dunyada yansimis hali: H/V bayragi cevrilir (bayraklar komuttur, D bayragi olsa da dogru)."""
    if v == 0:
        return 0
    if mx:
        v ^= FLAG_H
    if my:
        v ^= FLAG_V
    return v


def visible_class_map(root, ts):
    """Oyun alaninin GORUNEN zemin sinifi (256,256): 0 cimen, 1 toprak/kaya, 2 su - zemin + su + orman/plato katmanlarinin birlesik cizimi."""
    import tmxlib as _t
    keep = ('Yer/', 'Su/', 'Orman parçaları/')
    im = _t.render(root, ts, skip=lambda p: not '/'.join(p).startswith(keep) or '/'.join(p) == 'Orman parçaları/Saklanma Çalılığı')
    a = np.array(im.convert('RGB')).astype(np.float32).reshape(PLAY, T, PLAY, T, 3).mean(axis=(1, 3))
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    cls = np.ones((PLAY, PLAY), np.int8)
    cls[(g > r + 14) & (g > b + 20)] = 0
    cls[(b > g + 6) & (b > r + 20)] = 2
    return cls


def smooth_mask(m, ring, iters=2):
    """Cimen maskesini temizle: 1-2 hucrelik cikinti/delik kalmasin (3x3 cogunluk filtresi). Oyun alani hucreleri degismez."""
    out = m.copy()
    H_, W_ = m.shape
    for _ in range(iters):
        pad = np.pad(out, 1, constant_values=False)
        cnt = sum(pad[1 + dy:1 + dy + H_, 1 + dx:1 + dx + W_].astype(np.int8) for dy in (-1, 0, 1) for dx in (-1, 0, 1))
        new = cnt >= 5
        out = np.where(ring, new, out)
    return out


def sea_edges(su_old, blue):
    """Kenar hucre -> 'deniz mi' (True) / 'nehir mi' (False) / kuru. Kenar boyunca ardisik GORUNEN su kosusu >= 30 hucre = deniz; kosede kendisine bitisik
    deniz kosusuyla birlesen kisa kosu da denizdir (kuzeybati koyu hem ust hem sol kenara degiyor). Nehir agizlari dis halkada DEVAM ETMEZ (duz seritlere bol)."""
    def run_flags(vals):
        n = len(vals)
        flags = [False] * n
        i = 0
        runs = []
        while i < n:
            if vals[i]:
                j = i
                while j + 1 < n and vals[j + 1]:
                    j += 1
                runs.append((i, j))
                i = j + 1
            else:
                i += 1
        return runs
    def water_line(cells):
        out = []
        for (x, y) in cells:
            v = int(su_old[y, x])
            out.append(bool(v) and blue(v))
        return out
    edges = {
        'N': [(x, 0) for x in range(PLAY)],
        'S': [(x, PLAY - 1) for x in range(PLAY)],
        'W': [(0, y) for y in range(PLAY)],
        'E': [(PLAY - 1, y) for y in range(PLAY)],
    }
    wl = {k: water_line(v) for k, v in edges.items()}
    runs = {k: run_flags(v) for k, v in wl.items()}
    sea = {k: np.zeros(PLAY, bool) for k in edges}        # uzun kosu: deniz disari DUZ devam
    sea_m = {k: np.zeros(PLAY, bool) for k in edges}      # kosede denize bitisik KISA kosu (+8 hucre pay): kiyi AYNALANIR (duz kiyi seridi olmasin)
    for k in edges:
        for (a, b) in runs[k]:
            if b - a + 1 >= 30:
                sea[k][a:b + 1] = True
    pairs = [('N', 0, 'W', 0), ('N', PLAY - 1, 'E', 0), ('S', 0, 'W', PLAY - 1), ('S', PLAY - 1, 'E', PLAY - 1)]
    for (k1, i1, k2, i2) in pairs:
        for (ka, ia, kb, ib) in ((k1, i1, k2, i2), (k2, i2, k1, i1)):
            if sea[ka][ia] and wl[kb][ib] and not sea[kb][ib]:
                for (a, b) in runs[kb]:
                    if a <= ib <= b:
                        sea_m[kb][max(0, a - 8):min(PLAY, b + 9)] = True
    return sea, sea_m, wl


def build_base(root, ts):
    """-> dict(grids, order, attrs, masks...)
    DIS CERCEVE ZEMIN/SU = oyun alaninin AYNA GORUNTUSU (2026-10-13 ikinci tur): ilk surumde kenar satiri/sutunu tekrarlaniyordu (duz seritler, ayni
    kiyi cizgisi 32 hucre duz uzuyordu, kullanici: 'cok keskin bitisler var koselerde'). Ayna: kiyi/nehir/toprak-cimen sinirlari dogal egriligiyle
    kenardan dogru surer, kenarda kesintisiz birlesir (ayna simetrisi), karolar H/V cevrilmis halleriyle yazilir."""
    entries = list(layers(root))   # (yol listesi, element)
    order = ['/'.join(p) for p, _ in entries]
    attrs = {'/'.join(p): dict(l.attrib) for p, l in entries}
    old = {'/'.join(p): grid(l) for p, l in entries}
    grids = {k: pad(v) for k, v in old.items()}
    ring = ring_mask()

    water_mask = np.zeros((H2, W2), bool)       # halkada GORUNEN su (mavi) hucreleri
    grass_mask = np.zeros((H2, W2), bool)       # halkada cimen (agac cinsi icin)
    blue_cache = {}

    def blue(v):
        if v not in blue_cache:
            blue_cache[v] = is_blue(ts, v)
        return blue_cache[v]

    su_old = old[SU]
    sea, sea_m, wl = sea_edges(su_old, blue)
    print('  deniz kenarlari: ' + ', '.join(f'{k}={int(v.sum())}' for k, v in sea.items()) + ' | nehir/kapali agizlar: ' + ', '.join(f'{k}={int(sum(wl[k])) - int((np.array(wl[k]) & sea[k]).sum())}' for k in sea))

    mouth = np.zeros((H2, W2), bool)    # nehir agzi bolgeleri (halkada su devam etmez; calilikla ortulur)
    for k in wl:
        for i in range(PLAY):
            if wl[k][i] and not sea[k][i] and not sea_m[k][i]:
                for t in range(-3, 4):
                    j = i + t
                    if not (0 <= j < PLAY):
                        continue
                    for dd in range(1, 4):
                        cx_, cy_ = {'N': (j, -dd), 'S': (j, PLAY - 1 + dd), 'W': (-dd, j), 'E': (PLAY - 1 + dd, j)}[k]
                        mouth[cy_ - Y0, cx_ - X0] = True

    def edge_in_mirror_zone(x, y):
        if y < 0 and 0 <= x < PLAY:
            return bool(sea_m['N'][x])
        if y >= PLAY and 0 <= x < PLAY:
            return bool(sea_m['S'][x])
        if x < 0 and 0 <= y < PLAY:
            return bool(sea_m['W'][y])
        if x >= PLAY and 0 <= y < PLAY:
            return bool(sea_m['E'][y])
        return False

    def edge_is_water(x, y):
        """Band hucresinin kenar kaynagi DENIZ ise True: deniz disari devam eder. Nehirler / kapali sular devam ETMEZ (halkada kara)."""
        if y < 0 and 0 <= x < PLAY:
            return bool(sea['N'][x])
        if y >= PLAY and 0 <= x < PLAY:
            return bool(sea['S'][x])
        if x < 0 and 0 <= y < PLAY:
            return bool(sea['W'][y])
        if x >= PLAY and 0 <= y < PLAY:
            return bool(sea['E'][y])
        return False

    skipped = 0

    def put_water_cell(x, y, src_vals, mx, my):
        """src_vals: katman adi -> kaynak gid. Su maskesini gunceller."""
        for name in WATER_LAYERS:
            v = src_vals.get(name, 0)
            if not v:
                continue
            v = mirrored_gid(v, mx, my)
            grids[name][y - Y0, x - X0] = v
            if name == SU and blue(v):
                water_mask[y - Y0, x - X0] = True

    def cells_in(order):
        for y in range(Y0, Y0 + H2):
            for x in range(X0, X0 + W2):
                if 0 <= x < PLAY and 0 <= y < PLAY:
                    continue
                out_x = x < 0 or x >= PLAY
                out_y = y < 0 or y >= PLAY
                if (out_x and out_y) == order:
                    yield x, y, out_x, out_y

    # ZEMIN: toprak her halka hucresinde; CIMEN = oyun alaninin GORUNEN cimen/toprak/su sinifinin aynasi (alttaki "plato dolgusu" gibi gizli geometri yansimasin),
    # temizlenmis (tek hucrelik cikinti yok) ve duz kenar/ic kose parcalariyla cizilir.
    cls_play = visible_class_map(root, ts)             # (256,256): 0 cimen, 1 toprak/kaya, 2 su
    cls = np.zeros((H2, W2), np.int8)
    for x, y, out_x, out_y in list(cells_in(False)) + list(cells_in(True)):
        sx, sy, mx, my = mirror_src(x, y)
        cls[y - Y0, x - X0] = 0 if cls_play[sy, sx] == 2 else cls_play[sy, sx]   # aynalanan su = halkada kara (zemin cimeni)
        grids[GROUND_DIRT][y - Y0, x - X0] = DIRT_GID
    cls[play_slice()] = cls_play
    grass_cls = smooth_mask(cls == 0, ring)
    ring_grass = grass_cls & ring
    gg = grids[GROUND_GRASS]
    def g_at(x, y):
        if x < X0 or x >= X0 + W2 or y < Y0 or y >= Y0 + H2:
            return True
        return bool(grass_cls[y - Y0, x - X0])
    for y in range(Y0, Y0 + H2):
        for x in range(X0, X0 + W2):
            if not ring_grass[y - Y0, x - X0]:
                continue
            n_, s_, w_, e_ = g_at(x, y - 1), g_at(x, y + 1), g_at(x - 1, y), g_at(x + 1, y)
            ne_, nw_, se_, sw_ = g_at(x + 1, y - 1), g_at(x - 1, y - 1), g_at(x + 1, y + 1), g_at(x - 1, y + 1)
            gid = GRASS_GID
            miss = ('T' if not n_ else '') + ('B' if not s_ else '') + ('L' if not w_ else '') + ('R' if not e_ else '')
            if miss in EDGE:
                gid = EDGE[miss]
            elif miss == '':
                diag = [k for k, v in (('TR', ne_), ('TL', nw_), ('BR', se_), ('BL', sw_)) if not v]
                if len(diag) == 1:
                    gid = INNER[diag[0]]
            gg[y - Y0, x - X0] = gid
    # SU, 1. asama (kenar bantlari): kenar hucresi suysa deniz/nehir DISARI DUZ devam eder (dikissiz karolar), degilse kiyi/goller AYNA (organik kiyi)
    for x, y, out_x, out_y in cells_in(False):
        sx, sy, mx, my = mirror_src(x, y)
        if edge_is_water(x, y):
            cx, cy = clamp_src(x, y)
            vals = {}
            for name in WATER_LAYERS:
                v = int(old[name][cy, cx])
                if v and ((out_y and not seamless(ts, v, 'v')) or (out_x and not seamless(ts, v, 'h'))):
                    skipped += 1
                    v = 0
                vals[name] = v
            put_water_cell(x, y, vals, False, False)
        elif edge_in_mirror_zone(x, y):
            put_water_cell(x, y, {n: int(old[n][sy, sx]) for n in WATER_LAYERS}, mx, my)
        # deniz degilse (nehir agzi / kara): halkada su YOK
    # SU, 2. asama (kose bloklari): komsu bant suya degiyorsa o bant hucresi kose boyunca da uzar (deniz kosede KESILMESIN), yoksa ayna
    for x, y, out_x, out_y in cells_in(True):
        ex = 0 if x < 0 else PLAY - 1
        ey = 0 if y < 0 else PLAY - 1
        hs = (ex, y)       # yatay bant (kuzey/guney) hucresi
        vs = (x, ey)       # dikey bant (bati/dogu) hucresi
        src = None
        if water_mask[hs[1] - Y0, hs[0] - X0]:
            src, need = hs, 'h'
        elif water_mask[vs[1] - Y0, vs[0] - X0]:
            src, need = vs, 'v'
        if src is not None:
            vals = {}
            for name in WATER_LAYERS:
                v = int(grids[name][src[1] - Y0, src[0] - X0])
                if v and not seamless(ts, v, need):
                    skipped += 1
                    v = 0
                vals[name] = v
            for name in WATER_LAYERS:
                v = vals[name]
                if v:
                    grids[name][y - Y0, x - X0] = v
                    if name == SU and blue(v):
                        water_mask[y - Y0, x - X0] = True
    print('  su: dikissiz olmadigi icin atlanan hucre', skipped)
    # su altinda cimen olmasin (Su katmani yari saydam: alttaki cimen yesil sizar)
    gg[water_mask] = 0
    grass_mask = ring_grass & ~water_mask

    # --- gorunmez engel: halkanin HER hucresi (kara + su); orman katmaninda dolu hucre = engel + gorus engeli
    grids[WALL][ring] = WALL_GID

    return dict(grids=grids, order=order, attrs=attrs, ring=ring, grass_ring=grass_mask, water_ring=water_mask, mouth=mouth, entries=entries)
