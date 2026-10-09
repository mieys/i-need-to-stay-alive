"""Harita.tmx ORMAN DOKUSU ureticisi (2026-10-09) - CLAUDE.md madde 47.
YENI GORSEL URETMEZ: Harita.tmx'in zaten bagli oldugu tileset'lerden (Objects, sade agac ve tas, sadece_agac, Flowers) agac / cali / mantar /
cicek karolari yerlestirir; sadece 7 hedef katmanin CSV verisini EKLEME olarak degistirir (mevcut hucre silinmez, assert'li).
Kaynak TMX: ortam degiskeni HARITA_TMX (yoksa harita/Harita.tmx). Agac-oncesi hali: harita/yedek/Harita_YEDEK_2026-10-09_agac-oncesi.tmx.bak
Adimlar (proje kokunden, cikti klasoru tools/forest_decor/out):
  $env:HARITA_TMX = "harita/yedek/Harita_YEDEK_2026-10-09_agac-oncesi.tmx.bak"
  python -I tools/forest_decor/masks.py       tools/forest_decor/out
  python -I tools/forest_decor/gen_forest.py  tools/forest_decor/out tools/forest_decor/out/Harita_new.tmx '<ayar json>'
  python -I tools/forest_decor/verify.py      tools/forest_decor/out tools/forest_decor/out/Harita_new.tmx   # butunluk, govde yasak yer, baglanti (cep) denetimi
  python -I tools/forest_decor/preview.py     tools/forest_decor/out tools/forest_decor/out/Harita_new.tmx once   # onizleme png
Kullanilan ayar (2026-10-09, tohum 20261009, ayni girdi -> ayni cikti): {"wall_p":0.55,"zone_lo":0.44,"trunk_gap":1,"border_p":0.30,"groves":11,"meadow_tries":2200,"dead_p":0.010,"water_tree_p":0.02,"wall_under_p":0.34,"reed_p":0.10}
Seyreltmek icin wall_p/border_p/groves dusurun; yogunlastirmak icin arttirin. Sonra cikan TMX'i harita/Harita.tmx uzerine kopyalayip bake edin.
"""
import sys, math, random, re, json
sys.path.insert(0, sys.argv[1]); sys.path.insert(0, __import__('os').path.dirname(__import__('os').path.abspath(__file__)))
from stamplib import *

SEED = 20261009
rng = random.Random(SEED)
OUT = sys.argv[2]
KNOB = json.loads(sys.argv[3]) if len(sys.argv) > 3 else {}
def knob(k, d): return KNOB.get(k, d)

root, ts = load()
lib = Lib(ts)
L = {'/'.join(p): grid(l) for p, l in layers(root)}
M = np.load(sys.argv[1] + '/masks.npz')
wall, water, water_core, bridge = M['wall'], M['water'], M['water_core'], M['bridge']
house, mine, base, grass, dirt = M['house'], M['mine'], M['base'], M['grass'], M['dirt']
forest_other = M['forest_other']

TARGET = {
    'T0': 'Shader Eklenecek/Ağaç 0', 'T1': 'Shader Eklenecek/Ağaç 1', 'T2': 'Shader Eklenecek/Ağaç 2',
    'BUSH': 'Shader Eklenecek/Çalılar1', 'REED': 'Shader Eklenecek/Çalılar',
    'OBJ': 'Shader Eklenecek/Animasyonsuz çalılar', 'FLOW': 'Shader Eklenecek/Çiçekler 1',
}
G = {k: L[v].copy() for k, v in TARGET.items()}
ORIG = {k: L[v].copy() for k, v in TARGET.items()}
TREE_KEYS = ['T0', 'T1', 'T2']

# ---------------------------------------------------------------- yardimcilar
def dil(m, r):
    pad = np.pad(m, r, constant_values=False)
    out = np.zeros_like(m)
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= r * r + r:
                out |= pad[r + dy:r + dy + m.shape[0], r + dx:r + dx + m.shape[1]]
    return out

def cheb_dist(m, maxd=14):
    """m True hucrelere Chebyshev uzakligi (m'in kendisi 0)."""
    d = np.full(m.shape, maxd + 1, np.int32)
    d[m] = 0
    cur = m.copy()
    for k in range(1, maxd + 1):
        nxt = cur.copy()
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                s = np.roll(np.roll(cur, dy, 0), dx, 1)
                # sarma temizligi
                if dy == 1: s[0, :] = False
                if dy == -1: s[-1, :] = False
                if dx == 1: s[:, 0] = False
                if dx == -1: s[:, -1] = False
                nxt |= s
        d[nxt & ~cur] = k
        cur = nxt
    return d

class Noise:
    def __init__(self, seed, n=6, scale=1.0):
        r = random.Random(seed)
        self.w = []
        for i in range(n):
            ang = r.uniform(0, math.tau); f = r.uniform(0.035, 0.11) * scale * (1 + i * 0.35)
            self.w.append((math.cos(ang) * f, math.sin(ang) * f, r.uniform(0, math.tau), 1.0 / (1 + i * 0.4)))
        self.norm = sum(w[3] for w in self.w)
    def __call__(self, x, y):
        s = sum(a * math.sin(x * fx + y * fy + p) for fx, fy, p, a in self.w)
        return 0.5 + 0.5 * s / self.norm

N_CLUMP = Noise(11)
N_THEME = Noise(23, 4, 0.8)
N_FLOWER = Noise(37, 5, 1.3)
N_MIST = Noise(51, 4, 0.9)

# ---------------------------------------------------------------- engel / yasak alanlar
ex_fp = np.zeros((H, W), bool)       # mevcut agac govdesi hucreleri (tahmini)
ex_tiles = {k: {} for k in TREE_KEYS}   # layer -> {(x,y): (gid, entry)}
entries = []                         # yerlestirilmis / mevcut agaclar

def tile_alpha_stamp(tiles):
    """tiles [(dx,dy,gid)] -> stamp dict (alpha) mevcut agaclar icin"""
    w = max(t[0] for t in tiles) + 1; h = max(t[1] for t in tiles) + 1
    al = np.zeros((h * T, w * T), np.uint8)
    for dx, dy, gid in tiles:
        im = ts.tile(gid)
        if im: al[dy * T:(dy + 1) * T, dx * T:(dx + 1) * T] = np.array(im.getchannel('A'))
    return {'alpha': al, 'w': w, 'h': h}

def decode_gid(gid):
    g = gid & 0x0FFFFFFF; t = ts.find(g)
    return (t[1], g - t[0], gid & 0xE0000000, t[3]) if t else None

def register_existing_trees():
    for key in TREE_KEYS:
        g = G[key]
        cells = {(y, x): decode_gid(int(g[y, x])) for y, x in zip(*np.nonzero(g))}
        cells = {k: v for k, v in cells.items() if v}
        parent = {k: k for k in cells}
        def find(a):
            while parent[a] != a:
                parent[a] = parent[parent[a]]; a = parent[a]
            return a
        for (y, x), (src, i, fl, cols) in cells.items():
            for dy, dx, di in ((0, 1, 1), (1, 0, cols)):
                n = (y + dy, x + dx)
                if n in cells and cells[n][0] == src and cells[n][2] == fl and cells[n][1] == i + di:
                    parent[find(n)] = find((y, x))
        groups = {}
        for k in cells: groups.setdefault(find(k), []).append(k)
        for ks in groups.values():
            ys = [k[0] for k in ks]; xs = [k[1] for k in ks]
            y0, x0 = min(ys), min(xs)
            tiles = [(k[1] - x0, k[0] - y0, int(g[k])) for k in ks]
            st = tile_alpha_stamp(tiles)
            fp, bs = footprint(st)
            e = {'layer': key, 'base_y': y0 + bs / T, 'cells': {(k[1], k[0]) for k in ks}, 'fp': set(), 'ex': True}
            for dx, dy in fp:
                c = (x0 + dx, y0 + dy)
                if 0 <= c[0] < W and 0 <= c[1] < H: ex_fp[c[1], c[0]] = True; e['fp'].add(c)
            entries.append(e)
            for k in ks: ex_tiles[key][(k[1], k[0])] = (int(g[k]), e)

register_existing_trees()

# kapi / baslangic noktalari (hucre)
DOORS = [(120, 85), (81, 150)]
door_ban = np.zeros((H, W), bool)
for (dx_, dy_) in DOORS:
    for y in range(max(0, dy_ - 9), min(H, dy_ + 7)):
        for x in range(max(0, dx_ - 10), min(W, dx_ + 11)):
            door_ban[y, x] = True

house_ban = dil(house, 6) | door_ban
mine_ban = dil(mine, 3)
base_ban = dil(base, 5)
bridge_ban = dil(bridge, 3)
water_ban1 = dil(water_core, 1)
water_ban2 = dil(water_core | water, 2)
wall_d = cheb_dist(wall, 14)
water_d = cheb_dist(water_core, 14)
dirt_d = cheb_dist(dirt, 14)          # dirt'e uzaklik
road_ban = dil(dirt, 2)                # yollara 2 hucre yaklasma (barren disinda)

# barren (cıplak toprak) bolgeler: alt-sol ve alt-sag
barren = np.zeros((H, W), bool)
barren[184:256, 0:48] = True
barren[178:256, 186:256] = True

all_blocked = wall | water_core | house | mine | base | ex_fp
# DAR GECIT KORUMASI (kullanici 2026-10-09: "bazi agac/calilar tepe kenarlarindaki vadi gecislerini kapatiyor"):
# MX = her hucrenin cevresindeki (5 hucre) en buyuk "bos disk yaricapi"; kucukse hucre dar bir vadi/gecidin icinde.
_wb = np.roll(water_core, -1, 0); _wb[-1, :] = False; _wb &= ~np.roll(bridge, -1, 0)
blk_static = wall | _wb | house | mine | base
def _clearance():
    R = 9
    pad = np.pad(blk_static, R, constant_values=True)
    D = np.full((H, W), 99.0)
    for dy in range(-R, R + 1):
        for dx in range(-R, R + 1):
            d = (dx * dx + dy * dy) ** 0.5
            if d > R: continue
            sh = pad[R + dy:R + dy + H, R + dx:R + dx + W]
            D = np.where(sh & (D > d), d, D)
    D[blk_static] = 0
    r = 5
    padD = np.pad(D, r, constant_values=0)
    Mx = np.zeros((H, W))
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= r * r:
                Mx = np.maximum(Mx, padD[r + dy:r + dy + H, r + dx:r + dx + W])
    return Mx
MX = _clearance()
# KUMSAL (kullanici: "kumsalda bitki/cali olmamaliydi"): sudan 8 hucre icindeki cıplak toprak + kıyı (Water_coasts) karolari
def _coast_cells():
    out = np.zeros((H, W), bool)
    for nm in ('Yer/Zemin Çimen', 'Yer/Çimler'):
        g = L[nm]
        for y, x in zip(*np.nonzero(g)):
            t = ts.find(int(g[y, x]) & 0x0FFFFFFF)
            if t and t[1] == 'Water_coasts.tsx': out[y, x] = True
    return out
coast_cells = _coast_cells()
beach = (((dirt | coast_cells) & (water_d <= 8)) | dil(coast_cells, 1)) & ~water_core
# SIKI CAKISMA YASAGI: hicbir yeni karo, baska bir agac/cali/nesne/cicek karosuyla ayni hucreyi paylasmaz (katman farki fark etmez)
occ = np.zeros((H, W), bool)
for _k in ('T0', 'T1', 'T2', 'BUSH', 'OBJ', 'FLOW'): occ |= ORIG[_k] != 0
near_other_forest = dil(forest_other & ~wall, 1)
ex_any = np.zeros((H, W), bool)
for k in TARGET: ex_any |= ORIG[k] != 0

# ---------------------------------------------------------------- sprite secimleri
def S(src, i): return lib.stamp(src, i)
O, SA, TR, FL = 'Objects.tsx', 'sade ağaç ve taş.tsx', 'sadece_agac.tsx', 'Flowers.tsx'

def mk(src, ids, kind='tree'):
    out = []
    for i in ids:
        st = S(src, i)
        assert st['contam'] == 0, (src, i, st['contam'])
        st['fp'], st['basepx'] = footprint(st)
        st['name'] = f"{src.split('.')[0][:6]}{i}"
        out.append(st)
    return out

TREES = {
    # buyuk / orta yaprakli ve camlar
    'lush_big':    mk(O, [2, 5, 14, 1, 0]) + mk(SA, [1, 2, 3]),
    'lush_mid':    mk(O, [13, 11, 12]) + mk(SA, [4, 5, 6]),
    'lush_small':  mk(SA, [7, 8]),
    'oak_big':     mk(O, [4]),
    'dark_pine':   mk(O, [0, 11, 12]) + mk(SA, [2, 5]),
    'mossy':       mk(TR, [6, 18, 28]),
    'dead':        mk(TR, [5, 17, 27]),
    'pink':        mk(TR, [8, 19, 32]),
    'clover':      mk(TR, [9, 20, 31]),
    'twisted':     mk(SA, [3, 6, 7]),
}
SHRUBS = mk(O, [15, 20, 22, 25, 26, 31, 32, 19, 3]) + mk(SA, [9, 10, 11, 12, 13, 14, 18])
SHRUBS_DARK = mk(O, [19, 31, 32]) + mk(SA, [9, 10, 11])
MUSH = mk(O, [64, 65, 66, 70, 71, 72])
STUMPS = mk(O, [24, 28, 30, 29])
LOGS = mk(O, [23, 27])
ROCKS = mk(O, [44, 49, 50, 53, 54, 56, 57, 59, 63]) + mk(SA, [20, 21, 22, 23])
REEDS = mk(O, [83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94])
FLOW_BLUE = mk(FL, [0, 1, 2, 15, 17, 18, 16, 23, 24, 25, 26, 27, 35, 36, 38, 39, 40, 41])
FLOW_PURPLE = mk(FL, [19, 20, 32, 33, 31, 16, 40, 41])
FLOW_WARM = mk(FL, [3, 4, 5, 9, 10, 11, 12, 13, 14, 21, 22, 28, 29, 30, 6, 7, 8])
FLOW_ALL = FLOW_BLUE + FLOW_PURPLE + FLOW_WARM

def pick(lst): return rng.choice(lst)

# ---------------------------------------------------------------- yerlestirme cekirdegi
placed_log = []
core_cache = {}

def blocked_now():
    return all_blocked

def _core_map(x0, x1, y0, y1, extra, rad):
    ox, oy = max(0, x0 - rad), max(0, y0 - rad)
    b = all_blocked[oy:min(H, y1 + rad), ox:min(W, x1 + rad)].copy()
    for (x, y) in extra:
        if oy <= y < oy + b.shape[0] and ox <= x < ox + b.shape[1]: b[y - oy, x - ox] = True
    offs = [(dx, dy) for dy in range(-rad, rad + 1) for dx in range(-rad, rad + 1) if dx * dx + dy * dy <= (5 if rad == 2 else 2)]
    core = np.zeros((y1 - y0, x1 - x0), bool)
    for y in range(y0, y1):
        for x in range(x0, x1):
            ok = True
            for dx, dy in offs:
                xx, yy = x + dx, y + dy
                if yy < 0 or xx < 0 or yy >= H or xx >= W or b[yy - oy, xx - ox]: ok = False; break
            core[y - y0, x - x0] = ok
    return core

def _comps(core):
    lab = np.zeros(core.shape, int); n = 0
    for y in range(core.shape[0]):
        for x in range(core.shape[1]):
            if core[y, x] and lab[y, x] == 0:
                n += 1; st = [(y, x)]; lab[y, x] = n
                while st:
                    cy, cx2 = st.pop()
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        yy, xx = cy + dy, cx2 + dx
                        if 0 <= yy < core.shape[0] and 0 <= xx < core.shape[1] and core[yy, xx] and lab[yy, xx] == 0:
                            lab[yy, xx] = n; st.append((yy, xx))
    return lab

def core_ok_window(cx, cy, newfp, R=8):
    """yerel baglanirlik: yeni govde hucreleri eklenince (a) 2 yaricapli genis ajan icin pencere kenarindaki
    baglantilar, (b) 1 yaricapli (oyuncu) ajan icin hem kenar baglantilari hem yeni 'cep' (kopuk kose) olusmamali."""
    x0, x1 = max(0, cx - R), min(W, cx + R + 1)
    y0, y1 = max(0, cy - R), min(H, cy + R + 1)
    for rad, pockets in ((2, False), (1, True)):
        c0 = _core_map(x0, x1, y0, y1, [], rad); c1 = _core_map(x0, x1, y0, y1, newfp, rad)
        l0 = _comps(c0); l1 = _comps(c1)
        hh, ww = c0.shape
        ring = [(y, x) for y in range(hh) for x in range(ww) if (y in (0, hh - 1) or x in (0, ww - 1)) and c0[y, x]]
        for i in range(len(ring)):
            for j in range(i + 1, len(ring)):
                a_, b_ = ring[i], ring[j]
                if l0[a_] == l0[b_] and (not c1[a_] or not c1[b_] or l1[a_] != l1[b_]):
                    return False
        if pockets:
            ring_labels0 = {l0[r_] for r_ in ring}
            ring_labels1 = {l1[r_] for r_ in ring if c1[r_]}
            for y in range(hh):
                for x in range(ww):
                    if c1[y, x] and l1[y, x] not in ring_labels1 and c0[y, x] and l0[y, x] in ring_labels0:
                        return False
    return True

def adjacent_merge(key, tiles_abs):
    """sallanan agac ayirma kurali: ayni katmanda atlas-komsu karolar tek agac sayilir -> yeni agac baska agaca yapismasin"""
    lay = G[key]
    own = {(x, y): gid for (x, y, gid) in tiles_abs}
    for (x, y, gid) in tiles_abs:
        d = decode_gid(gid)
        for dx, dy, di in ((1, 0, 1), (-1, 0, -1), (0, 1, d[3]), (0, -1, -d[3])):
            nx, ny = x + dx, y + dy
            if (nx, ny) in own: continue
            if 0 <= nx < W and 0 <= ny < H and lay[ny, nx]:
                d2 = decode_gid(int(lay[ny, nx]))
                if d2 and d2[0] == d[0] and d2[2] == d[2] and d2[1] == d[1] + di:
                    return True
    return False

def try_place_tree(st, site, theme_dead=False, ignore_core=False, allow_on_dirt=False, min_trunk=2):
    """site = govde merkez hucresi (x,y). Basarili ise yerlestirir, entry dondurur."""
    fp = st['fp']
    if not fp: return None
    fx = int(round(sum(d[0] for d in fp) / len(fp))); fy = max(d[1] for d in fp)
    ox, oy = site[0] - fx, site[1] - fy
    tiles_abs = [(ox + i, oy + j, gid) for (i, j, gid) in st['tiles']]
    for (x, y, gid) in tiles_abs:
        if not (0 <= x < W and 0 <= y < H): return None
    fp_abs = {(ox + dx, oy + dy) for dx, dy in fp}
    for (x, y) in fp_abs:
        if not (1 <= x < W - 1 and 1 <= y < H - 1): return None
        if all_blocked[y, x] or water_ban1[y, x] or house_ban[y, x] or mine_ban[y, x] or base_ban[y, x] or bridge_ban[y, x]: return None
        if near_other_forest[y, x] or ex_any_fp[y, x]: return None
        if not allow_on_dirt and (road_ban[y, x] and not barren[y, x]): return None
        if not allow_on_dirt and dirt[y, x] and not barren[y, x]: return None
        if not dead_ok_grass(st, x, y, theme_dead): return None
        if MX[y, x] < knob('fp_mx', 5.2) or beach[y, x]: return None
    # tac hucreleri: ev/kopru/maden/us icine girmesin; baska nesneyle ayni hucreyi paylasmasin; dar vadiyi/yolu kapatmasin; kumsala girmesin
    for (x, y, gid) in tiles_abs:
        if house[y, x] or bridge[y, x] or mine[y, x] or base[y, x] or door_ban[y, x]: return None
        if occ[y, x] or beach[y, x] or water_core[y, x]: return None
        if not blk_static[y, x] and MX[y, x] < knob('crown_mx', 4.2): return None
        if dirt[y, x] and not barren[y, x]: return None
    # govdeler arasi aralik
    for (x, y) in fp_abs:
        for yy in range(y - min_trunk, y + min_trunk + 1):
            for xx in range(x - min_trunk, x + min_trunk + 1):
                if 0 <= xx < W and 0 <= yy < H and trunk_grid[yy, xx]: return None
    # katman secimi
    my_base = oy + st['basepx'] / T
    cand_layers = []
    for li, key in enumerate(TREE_KEYS):
        ok = True
        for (x, y, gid) in tiles_abs:
            if G[key][y, x]: ok = False; break
        if not ok: continue
        # siralama kurali (ayni hucrede farkli katmanda baska agac karosu)
        for (x, y, gid) in tiles_abs:
            for lj, k2 in enumerate(TREE_KEYS):
                if lj == li: continue
                if G[k2][y, x]:
                    e = tile_owner.get((k2, x, y))
                    by = e['base_y'] if e else 1e9
                    if (my_base > by and not li > lj) or (my_base <= by and not li < lj): ok = False; break
            if not ok: break
        if not ok: continue
        if adjacent_merge(key, tiles_abs): continue
        cand_layers.append(key)
    if not cand_layers: return None
    key = cand_layers[0]
    if not ignore_core and not core_ok_window(site[0], site[1], fp_abs):
        return None
    # yaz
    for (x, y, gid) in tiles_abs: G[key][y, x] = gid; occ[y, x] = True
    e = {'layer': key, 'base_y': my_base, 'cells': {(x, y) for x, y, g in tiles_abs}, 'fp': fp_abs, 'ex': False, 'name': st['name'], 'site': site}
    entries.append(e)
    for (x, y, gid) in tiles_abs: tile_owner[(key, x, y)] = e
    for c in fp_abs:
        all_blocked[c[1], c[0]] = True; trunk_grid[c[1], c[0]] = True
    placed_log.append((st['name'], site, key))
    return e

def dead_ok_grass(st, x, y, dead):
    if dead: return True
    return bool(grass[y, x])

# kutu: mevcut agac tile sahipligi
tile_owner = {}
for key in TREE_KEYS:
    for (x, y), (gid, e) in ex_tiles[key].items(): tile_owner[(key, x, y)] = e
trunk_grid = ex_fp.copy()
ex_any_fp = np.zeros((H, W), bool)   # kucuk dekor icin degil; agac govdesi mevcut dekor ustune binmesin diye ek koruma
for k in ('REED', 'OBJ', 'BUSH', 'FLOW'):
    pass

# ---------------------------------------------------------------- dekor yerlestirme (carpismasiz)
def _atlas_adj(lay, nx, ny, x, y, gid):
    d1 = decode_gid(gid); d2 = decode_gid(int(lay[ny, nx]))
    if not d1 or not d2 or d1[0] != d2[0] or d1[2] != d2[2]: return False
    dx, dy = nx - x, ny - y
    if dy == 0 and dx == 1: return d2[1] == d1[1] + 1
    if dy == 0 and dx == -1: return d2[1] == d1[1] - 1
    if dx == 0 and dy == 1: return d2[1] == d1[1] + d1[3]
    if dx == 0 and dy == -1: return d2[1] == d1[1] - d1[3]
    return False

def place_deco(st, site, layer_key, on_dirt=False, need_grass=True, avoid_trunk=True, tight=True, mx_min=None):
    ox = site[0] - st['w'] // 2
    oy = site[1] - (st['h'] - 1)
    tiles_abs = [(ox + i, oy + j, gid) for (i, j, gid) in st['tiles']]
    lay = G[layer_key]
    own = {(x, y) for x, y, _ in tiles_abs}
    for (x, y, gid) in tiles_abs:
        if not (0 <= x < W and 0 <= y < H): return False
        if lay[y, x]: return False
        if wall[y, x] or water[y, x] or house_ban[y, x] or bridge_ban[y, x] or mine_ban[y, x] or base_ban[y, x]: return False
        if forest_other[y, x]: return False
        if occ[y, x] or beach[y, x]: return False
        if MX[y, x] < (mx_min if mx_min is not None else (3.0 if layer_key == 'FLOW' else knob('deco_mx', 4.6))) and not blk_static[y, x]: return False
        if avoid_trunk and trunk_grid[y, x]: return False
        if need_grass and not on_dirt and not grass[y, x]: return False
        if need_grass and on_dirt and not (grass[y, x] or barren[y, x]): return False
        if not on_dirt and road_ban[y, x] and not barren[y, x] and st['w'] * st['h'] > 1: return False
    for (x, y, gid) in tiles_abs:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n in own or not (0 <= n[0] < W and 0 <= n[1] < H) or not lay[n[1], n[0]]: continue
            if _atlas_adj(lay, n[0], n[1], x, y, gid): return False
    for (x, y, gid) in tiles_abs: lay[y, x] = gid; occ[y, x] = True
    return True

# ---------------------------------------------------------------- tema
def theme_at(x, y):
    """0=bol yesil, 1=karanlik cam/yosun (gizemli)"""
    v = N_THEME(x, y)
    return 1 if v > knob('dark_thresh', 0.5) else 0

def tree_for(x, y, role='belt', dead=False):
    t = theme_at(x, y)
    r = rng.random()
    if dead:
        return pick(TREES['dead'])
    if role == 'border':
        pool = TREES['dark_pine'] + TREES['lush_big'] if t == 1 else TREES['lush_big'] + TREES['lush_mid'] + TREES['dark_pine'][:3]
        return pick(pool)
    if t == 1:
        if r < 0.38: return pick(TREES['dark_pine'])
        if r < 0.55: return pick(TREES['mossy'])
        if r < 0.70: return pick(TREES['twisted'])
        if r < 0.78: return pick(TREES['oak_big'])
        if r < 0.90: return pick(TREES['lush_mid'])
        return pick(TREES['lush_small'])
    else:
        if r < 0.30: return pick(TREES['lush_big'])
        if r < 0.52: return pick(TREES['lush_mid'])
        if r < 0.66: return pick(TREES['dark_pine'])
        if r < 0.76: return pick(TREES['oak_big'])
        if r < 0.84: return pick(TREES['twisted'])
        if r < 0.89: return pick(TREES['mossy'])
        if r < 0.93: return pick(TREES['clover'])
        if r < 0.95: return pick(TREES['pink'])
        return pick(TREES['lush_small'])

# ---------------------------------------------------------------- 1) DUVAR KENARI KUSAGI
def wall_belt():
    n = 0
    sites = [(x, y) for y in range(2, H - 2) for x in range(2, W - 2)
             if 1 <= wall_d[y, x] <= 3 and not wall[y, x] and (grass[y, x] or barren[y, x])]
    rng.shuffle(sites)
    p0 = knob('wall_p', 0.30)
    for (x, y) in sites:
        c = N_CLUMP(x, y)
        zone = min(1.0, max(0.0, (c - knob('zone_lo', 0.40)) / 0.18))
        if rng.random() > p0 * zone: continue
        st = tree_for(x, y, 'belt')
        if place_tree(st, (x, y)): n += 1
    return n

def place_tree(st, site, **kw):
    # min yaricap (kume yogunlugu): buyuk agac daha seyrek
    min_trunk = (knob('trunk_gap', 1) + 1) if st['w'] >= 5 else knob('trunk_gap', 1)
    # kose / dar gecit icin core kontrolu icinde
    return try_place_tree(st, site, min_trunk=min_trunk, **kw)

# ---------------------------------------------------------------- 2) HARITA KENARI ORMANI
def border_belt():
    n = 0
    sites = []
    for y in range(H):
        for x in range(W):
            d = min(x, y, W - 1 - x, H - 1 - y)
            if d <= 7: sites.append((x, y, d))
    rng.shuffle(sites)
    for (x, y, d) in sites:
        depth = 3 + 4 * N_MIST(x, y)           # kenar derinligi 3-7 hucre (duzensiz)
        if d > depth: continue
        if rng.random() > knob('border_p', 0.20): continue
        if not (grass[y, x]): continue
        st = tree_for(x, y, 'border')
        if place_tree(st, (x, y)): n += 1
    return n

# ---------------------------------------------------------------- 3) KOYLER (orman bahceleri) - gizemli acikliklar
def groves():
    cands = []
    far_wall = wall_d
    for y in range(12, H - 12):
        for x in range(12, W - 12):
            if far_wall[y, x] >= 7 and grass[y, x] and not dirt[y, x] and water_d[y, x] >= 6 and not house_ban[y, x] \
               and not road_ban[y, x] and not mine_ban[y, x] and not base_ban[y, x] and not barren[y, x]:
                cands.append((x, y))
    rng.shuffle(cands)
    centers = []
    for (x, y) in cands:
        if any((x - cx) ** 2 + (y - cy) ** 2 < knob('grove_gap', 20) ** 2 for cx, cy in centers): continue
        centers.append((x, y))
        if len(centers) >= knob('groves', 15): break
    n = 0
    info = []
    for (cx, cy) in centers:
        r = rng.uniform(5.5, 8.5)
        count = rng.randint(6, 10)
        theme = rng.choice(['dark', 'dark', 'lush', 'mystic', 'pink' if rng.random() < 0.12 else 'lush'])
        placed = 0
        tries = 0
        while placed < count and tries < 260:
            tries += 1
            a = rng.uniform(0, math.tau); rr = r * math.sqrt(rng.random())
            x = int(round(cx + math.cos(a) * rr)); y = int(round(cy + math.sin(a) * rr * 0.8))
            if not (2 <= x < W - 2 and 2 <= y < H - 2) or not grass[y, x]: continue
            if theme == 'dark': st = pick(TREES['dark_pine'] + TREES['dark_pine'] + TREES['mossy'] + TREES['twisted'])
            elif theme == 'mystic': st = pick(TREES['mossy'] + TREES['mossy'] + TREES['twisted'] + TREES['dark_pine'] + TREES['oak_big'])
            elif theme == 'pink': st = pick(TREES['pink'] + TREES['pink'] + TREES['lush_mid'])
            else: st = pick(TREES['lush_big'] + TREES['lush_mid'] + TREES['oak_big'] + TREES['twisted'])
            if place_tree(st, (x, y)): placed += 1; n += 1
        info.append((cx, cy, theme, placed))
    return n, info, centers

# ---------------------------------------------------------------- 4) BARREN (solgun) AGACLAR
def barren_dead():
    n = 0
    sites = [(x, y) for y in range(3, H - 3) for x in range(3, W - 3) if barren[y, x] and dirt[y, x] and not water[y, x]]
    rng.shuffle(sites)
    for (x, y) in sites:
        if rng.random() > knob('dead_p', 0.012): continue
        if mine_ban[y, x] or base_ban[y, x]: continue
        st = pick(TREES['dead'])
        if try_place_tree(st, (x, y), theme_dead=True, allow_on_dirt=True, min_trunk=3): n += 1
    return n

# ---------------------------------------------------------------- 5) SU KENARI (kamis + yosunlu agaclar)
def waterside():
    n = 0; r = 0
    sites = [(x, y) for y in range(3, H - 3) for x in range(3, W - 3)
             if 2 <= water_d[y, x] <= 3 and grass[y, x] and not wall[y, x]]
    rng.shuffle(sites)
    for (x, y) in sites:
        if rng.random() < knob('water_tree_p', 0.04):
            st = pick(TREES['mossy'] + TREES['lush_mid'] + TREES['twisted'])
            if place_tree(st, (x, y)): n += 1
    # kamislar: kiyiya 1-2 hucre
    sites = [(x, y) for y in range(3, H - 3) for x in range(3, W - 3)
             if 1 <= water_d[y, x] <= 2 and grass[y, x] and not beach[y, x] and not wall[y, x] and not water[y, x]]
    rng.shuffle(sites)
    for (x, y) in sites:
        if rng.random() < knob('reed_p', 0.16) * (0.3 + N_FLOWER(x, y)):
            st = pick(REEDS)
            if place_deco(st, (x, y), 'REED'): r += 1
    return n, r

# ---------------------------------------------------------------- 6) ALT BITKI ORTUSU
def undergrowth():
    cnt = {'bush': 0, 'mush': 0, 'stump': 0, 'log': 0, 'rock': 0, 'flow': 0}
    # a) her yeni agacin cevresine calı / mantar / kutuk
    for e in entries:
        if e['ex']: continue
        sx, sy = e['site']
        t = theme_at(sx, sy)
        for _ in range(rng.choice([0, 1, 1, 2, 2, 3])):
            a = rng.uniform(0, math.tau); rr = rng.uniform(2.3, 4.2)
            x = int(round(sx + math.cos(a) * rr)); y = int(round(sy + math.sin(a) * rr * 0.7))
            if not (2 <= x < W - 2 and 2 <= y < H - 2): continue
            r = rng.random()
            if r < 0.42: ok = place_deco(pick(SHRUBS_DARK if t == 1 else SHRUBS), (x, y), 'BUSH'); k = 'bush'
            elif r < 0.62: ok = place_deco(pick(MUSH), (x, y), 'OBJ'); k = 'mush'
            elif r < 0.72: ok = place_deco(pick(STUMPS), (x, y), 'OBJ'); k = 'stump'
            elif r < 0.80: ok = place_deco(pick(LOGS), (x, y), 'OBJ'); k = 'log'
            elif r < 0.90: ok = place_deco(pick(ROCKS), (x, y), 'OBJ'); k = 'rock'
            else:
                pool = FLOW_BLUE + FLOW_PURPLE if t == 1 else FLOW_ALL
                ok = place_deco(pick(pool), (x, y), 'FLOW'); k = 'flow'
            if ok: cnt[k] += 1
    return cnt

def flower_meadows():
    """acik cayirda dagnik cicek / mantar kumeleri (gurultuyle kumelenir)"""
    cnt = {'flow': 0, 'mush': 0, 'bush': 0}
    for _ in range(knob('meadow_tries', 9000)):
        x = rng.randint(3, W - 4); y = rng.randint(3, H - 4)
        if not grass[y, x] or dirt[y, x]: continue
        v = N_FLOWER(x, y)
        if v < 0.55: continue
        t = theme_at(x, y)
        r = rng.random()
        if r < 0.62:
            pool = (FLOW_BLUE + FLOW_PURPLE + FLOW_BLUE) if t == 1 else FLOW_ALL
            if place_deco(pick(pool), (x, y), 'FLOW'): cnt['flow'] += 1
            # kume: 1-3 komsu cicek
            for _ in range(rng.randint(0, 3)):
                nx, ny = x + rng.randint(-2, 2), y + rng.randint(-1, 1)
                if place_deco(pick(pool), (nx, ny), 'FLOW'): cnt['flow'] += 1
        elif r < 0.80:
            if place_deco(pick(MUSH), (x, y), 'OBJ'):
                cnt['mush'] += 1
                for _ in range(rng.randint(0, 2)):
                    nx, ny = x + rng.randint(-2, 2), y + rng.randint(-1, 1)
                    if place_deco(pick(MUSH), (nx, ny), 'OBJ'): cnt['mush'] += 1
        else:
            if place_deco(pick(SHRUBS_DARK if t == 1 else SHRUBS), (x, y), 'BUSH'): cnt['bush'] += 1
    return cnt

def wall_undergrowth():
    """duvar dibinde calı ve cicek kusagi (agacsiz yerlerde de dolgu)"""
    cnt = {'bush': 0, 'flow': 0, 'mush': 0, 'log': 0}
    sites = [(x, y) for y in range(2, H - 2) for x in range(2, W - 2)
             if 1 <= wall_d[y, x] <= 2 and not wall[y, x] and (grass[y, x] or barren[y, x])]
    rng.shuffle(sites)
    for (x, y) in sites:
        c = N_CLUMP(x, y)
        zone = min(1.0, max(0.15, (c - knob('zone_lo', 0.40) + 0.10) / 0.2))
        if rng.random() > knob('wall_under_p', 0.18) * zone:
            continue
        t = theme_at(x, y); r = rng.random()
        if r < 0.5:
            if place_deco(pick(SHRUBS_DARK if t == 1 else SHRUBS), (x, y), 'BUSH'): cnt['bush'] += 1
        elif r < 0.78:
            pool = (FLOW_BLUE + FLOW_PURPLE) if t == 1 else FLOW_ALL
            if place_deco(pick(pool), (x, y), 'FLOW'): cnt['flow'] += 1
        elif r < 0.93:
            if place_deco(pick(MUSH), (x, y), 'OBJ'): cnt['mush'] += 1
        else:
            if place_deco(pick(LOGS + STUMPS), (x, y), 'OBJ'): cnt['log'] += 1
    return cnt

def barren_props():
    cnt = {'rock': 0, 'stump': 0, 'mush': 0}
    for _ in range(4000):
        x = rng.randint(3, W - 4); y = rng.randint(3, H - 4)
        if not barren[y, x] or water[y, x] or mine_ban[y, x] or base_ban[y, x]: continue
        if rng.random() > 0.10: continue
        r = rng.random()
        if r < 0.5:
            if place_deco(pick(ROCKS), (x, y), 'OBJ', on_dirt=True, need_grass=False): cnt['rock'] += 1
        elif r < 0.8:
            if place_deco(pick(STUMPS + LOGS), (x, y), 'OBJ', on_dirt=True, need_grass=False): cnt['stump'] += 1
        else:
            if place_deco(pick(MUSH), (x, y), 'OBJ', on_dirt=True, need_grass=False): cnt['mush'] += 1
    return cnt


# ---------------------------------------------------------------- yalniz kalan cepleri temizle (global dogrulama)
def heal_pockets(max_iter=60):
    wb = np.roll(water_core, -1, 0); wb[-1, :] = False
    wb &= ~np.roll(bridge, -1, 0)
    static = wall | wb | house | mine | base
    def free1(block):
        pad = np.pad(block, 1, constant_values=True); er = np.zeros_like(block)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                er |= pad[1 + dy:1 + dy + H, 1 + dx:1 + dx + W]
        return ~er
    def label(free):
        lab = np.zeros((H, W), int); n = 0
        for y in range(H):
            for x in range(W):
                if free[y, x] and lab[y, x] == 0:
                    n += 1; st = [(y, x)]; lab[y, x] = n
                    while st:
                        cy, cx = st.pop()
                        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                            yy, xx = cy + dy, cx + dx
                            if 0 <= yy < H and 0 <= xx < W and free[yy, xx] and lab[yy, xx] == 0:
                                lab[yy, xx] = n; st.append((yy, xx))
        return lab, n
    origfp = np.zeros((H, W), bool)
    for e in entries:
        if e['ex']:
            for c in e['fp']: origfp[c[1], c[0]] = True
    labA, nA = label(free1(static | origfp))
    removed = 0
    for it in range(max_iter):
        curfp = np.zeros((H, W), bool)
        for e in entries:
            for c in e['fp']: curfp[c[1], c[0]] = True
        freeB = free1(static | curfp)
        labB, nB = label(freeB)
        # A bilesenindeki hucrelerin B'deki parcalari: en buyuk parca disinda kalanlar kayip
        lost = np.zeros((H, W), bool)
        for ca in range(1, nA + 1):
            m = labA == ca
            ids, cnt = np.unique(labB[m & freeB], return_counts=True)
            ids_cnt = [(i, c) for i, c in zip(ids.tolist(), cnt.tolist()) if i > 0]
            if len(ids_cnt) <= 1: continue
            keep = max(ids_cnt, key=lambda t: t[1])[0]
            lost |= m & freeB & (labB != keep)
        if not lost.any(): break
        ys, xs = np.nonzero(lost)
        # kayip hucrelere en yakin yeni agac
        best = None; bd = 1e9
        for e in entries:
            if e['ex']: continue
            for (fx, fy) in e['fp']:
                d = min((fx - xs) ** 2 + (fy - ys) ** 2)
                if d < bd: bd = d; best = e
        if best is None or bd > 36: break
        for (x, y) in best['cells']:
            if G[best['layer']][y, x] and (best['layer'], x, y) in tile_owner: G[best['layer']][y, x] = 0; tile_owner.pop((best['layer'], x, y), None); occ[y, x] = False
        for c in best['fp']: all_blocked[c[1], c[0]] = False; trunk_grid[c[1], c[0]] = False
        entries.remove(best); removed += 1
    return removed, int(lost.sum()) if 'lost' in dir() else 0


# ---------------------------------------------------------------- KAMIS -> haritanin KENDI animasyonlu cali oumeleri (kullanici 2026-10-09)
# Kullanici: "bu kamis/ot sprite'lari (Objects 83-94) haritamda olmasin; yerine oyunda mevcut animasyonlu calilar (Calilar, Calilar1) yer yer konsun".
# Kamis yerlestirmesi (rastgele akisi v2 ile ayni kalsin diye) aynen calisir, SONRA kamis karolari silinir ve ayri bir rastgele kaynakla
# Calilar/Calilar1 katmanlarinin MEVCUT filiz oumeleri (exterior tileset'i, ayni katmana) konur - baska hicbir katman degismez.
def existing_tufts(key):
    g = ORIG[key]
    cells = {(int(y), int(x)): decode_gid(int(g[y, x])) for y, x in zip(*np.nonzero(g))}
    cells = {k: v for k, v in cells.items() if v and v[0] == 'exterior.tsx'}
    parent = {k: k for k in cells}
    def find(a):
        while parent[a] != a: parent[a] = parent[parent[a]]; a = parent[a]
        return a
    for (y, x), (src, i, fl, cols) in cells.items():
        for dy, dx, di in ((0, 1, 1), (1, 0, cols)):
            n = (y + dy, x + dx)
            if n in cells and cells[n][2] == fl and cells[n][1] == i + di: parent[find(n)] = find((y, x))
    groups = {}
    for k in cells: groups.setdefault(find(k), []).append(k)
    uniq = {}
    for ks in groups.values():
        y0 = min(k[0] for k in ks); x0 = min(k[1] for k in ks)
        tiles = tuple(sorted((k[1] - x0, k[0] - y0, int(g[k])) for k in ks))
        if tiles in uniq: uniq[tiles][0] += 1
        else: uniq[tiles] = [1]
    out = []
    for tiles, (n,) in sorted(uniq.items(), key=lambda kv: -kv[1][0]):
        w = max(t[0] for t in tiles) + 1; h = max(t[1] for t in tiles) + 1
        if len(tiles) < 2 and n < 30: continue          # tek parca seyrek sprite'lar (parca artigi) atla
        out.append({'w': w, 'h': h, 'tiles': list(tiles), 'n': n, 'name': f'{key}:{w}x{h}x{n}'})
    return out

def swap_reeds_for_tufts():
    removed = 0
    lay = G['REED']
    for y, x in zip(*np.nonzero(lay)):
        d = decode_gid(int(lay[y, x]))
        if d and d[0] == 'Objects.tsx' and ORIG['REED'][y, x] == 0:
            lay[y, x] = 0; occ[y, x] = False; removed += 1
    r2 = random.Random(SEED + 7)
    t_reed = existing_tufts('REED'); t_bush = existing_tufts('BUSH')
    def choose(lst):
        wts = [st['n'] ** 0.5 * (1.6 if st['w'] * st['h'] > 1 else 1.0) for st in lst]
        return r2.choices(lst, wts)[0]
    placed = {'REED': 0, 'BUSH': 0}
    caps = {'REED': knob('tuft_reed_max', 45), 'BUSH': knob('tuft_bush_max', 18)}
    def put(st, x, y, key):
        global rng
        if placed[key] >= caps[key]: return False
        keep = rng; rng = r2                      # place_deco rastgele kullanmaz; guvenlik icin
        try: ok = place_deco(st, (x, y), key, mx_min=knob('tuft_mx', 4.6))
        finally: rng = keep
        if ok: placed[key] += 1
        return ok
    # a) kiyi boyunca (kamislarin oldugu yerler: cimde, sudan 1-3 hucre)
    sites = [(x, y) for y in range(3, H - 3) for x in range(3, W - 3)
             if 1 <= water_d[y, x] <= 3 and grass[y, x] and not beach[y, x] and not wall[y, x] and not water[y, x]]
    r2.shuffle(sites)
    for (x, y) in sites:
        if r2.random() < knob('tuft_shore_p', 0.02) * (0.3 + N_FLOWER(x, y)):
            put(choose(t_reed), x, y, 'REED')
    # b) yer yer (gurultuyle kumelenmis) acik cayir + duvar dibi
    for _ in range(knob('tuft_tries', 3500)):
        x = r2.randint(3, W - 4); y = r2.randint(3, H - 4)
        if not grass[y, x] or dirt[y, x]: continue
        v = N_FLOWER(x + 60, y + 25)
        if v < 0.60: continue
        if r2.random() < 0.7: put(choose(t_reed), x, y, 'REED')
        else: put(choose(t_bush), x, y, 'BUSH')
    return removed, placed


# ---------------------------------------------------------------- CICEK SEYRELTME (kullanici 2026-10-09: "ciceklri biraz azaltir misin, cok fazla cicek var")
# Sadece BENIM eklediğim cicekler (ORIG'de olmayan karolar) azaltilir; kumeler daha cok seyrelir (en az `flower_gap` hucre bosluk), kalanlar rastgele
# `flower_keep` olasiligiyla tutulur. Ayri rastgele kaynak (SEED+11): baska hicbir katman degismez.
def thin_flowers():
    g = G['FLOW']; orig = ORIG['FLOW']
    cells = {(int(y), int(x)): decode_gid(int(g[y, x])) for y, x in zip(*np.nonzero((g != 0) & (orig == 0)))}
    cells = {k: v for k, v in cells.items() if v}
    parent = {k: k for k in cells}
    def find(a):
        while parent[a] != a: parent[a] = parent[parent[a]]; a = parent[a]
        return a
    for (y, x), (src, i, fl, cols) in cells.items():
        for dy, dx, di in ((0, 1, 1), (1, 0, cols)):
            n = (y + dy, x + dx)
            if n in cells and cells[n][0] == src and cells[n][2] == fl and cells[n][1] == i + di: parent[find(n)] = find((y, x))
    groups = {}
    for k in cells: groups.setdefault(find(k), []).append(k)
    r3 = random.Random(SEED + 11)
    glist = list(groups.values()); r3.shuffle(glist)
    gap = knob('flower_gap', 2); keep_p = knob('flower_keep', 0.8)
    kept_cells = np.zeros((H, W), bool)
    kept_cells |= (orig != 0)               # ozgun cicekler de aralik hesabina girer
    kept = removed = 0
    for ks in glist:
        ok = r3.random() < keep_p
        if ok:
            for (y, x) in ks:
                y0, y1, x0, x1 = max(0, y - gap), min(H, y + gap + 1), max(0, x - gap), min(W, x + gap + 1)
                if kept_cells[y0:y1, x0:x1].any(): ok = False; break
        if ok:
            kept += 1
            for (y, x) in ks: kept_cells[y, x] = True
        else:
            removed += 1
            for (y, x) in ks: g[y, x] = 0; occ[y, x] = False
    return kept, removed

# ---------------------------------------------------------------- calistir
report = {}
report['wall_belt'] = wall_belt()
report['groves'], ginfo, gcenters = groves()
report['border'] = border_belt()
report['dead'] = barren_dead()
report['water_trees'], report['reeds'] = waterside()
report['under'] = undergrowth()
report['wall_under'] = wall_undergrowth()
report['meadow'] = flower_meadows()
report['barren_props'] = barren_props()
report['healed'] = heal_pockets()
report['reed_swap'] = swap_reeds_for_tufts()
report['flower_thin'] = thin_flowers()
report['trees_new'] = len([e for e in entries if not e['ex']])
report['trees_existing'] = len([e for e in entries if e['ex']])
for k in TARGET:
    report['cells_' + k] = int(((G[k] != 0) & (ORIG[k] == 0)).sum())
    assert ((G[k] != 0) | (ORIG[k] == 0)).all(), 'mevcut hucre silindi: ' + k
    assert (G[k][ORIG[k] != 0] == ORIG[k][ORIG[k] != 0]).all(), 'mevcut hucre degisti: ' + k
print(json.dumps(report, ensure_ascii=False))
print('groves', ginfo)
json.dump({'groves': ginfo}, open(sys.argv[1] + '/gen_info.json', 'w'))

# ---------------------------------------------------------------- TMX'e yaz (sadece 7 katmanin CSV'si)
src_text = open(__import__('os').environ.get('HARITA_TMX') or ROOT + '/Harita.tmx', encoding='utf-8', newline='').read()
def fmt(grid_):
    rows = [','.join(str(int(v)) for v in grid_[y]) for y in range(H)]
    return '\r\n' + ',\r\n'.join(rows) + '\r\n'
def layer_span(text, lname):
    m = re.search(r'<layer id="\d+" name="' + re.escape(lname) + r'"[^>]*>\s*<data encoding="csv">', text)
    assert m, lname
    s = m.end(); e = text.index('</data>', s)
    return s, e
# donusum dogrulamasi: degismemis bir katman ayni metni uretmeli
s, e = layer_span(src_text, 'Ağaç 0')
assert src_text[s:e] == fmt(ORIG['T0']), 'CSV bicimi birebir tutmuyor'
out = src_text
for k, v in TARGET.items():
    lname = v.split('/')[1]
    s, e = layer_span(out, lname)
    out = out[:s] + fmt(G[k]) + out[e:]
open(OUT, 'w', encoding='utf-8', newline='').write(out)
print('yazildi', OUT, len(out))
