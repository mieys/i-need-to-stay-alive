import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
"""DIS CERCEVE adim 2: halkaya yogun orman (agac + calilik + kaya/mantar). Statik katmanlar: 'Orman parcalari/Dis orman N'. CLAUDE.md madde 119.
Neden statik (Agac 0/1/2 DEGIL): Agac katmanlarindaki her hucre acilista terrain_collision/derinlik/sallanma taramasindan gecer (~60 bin hucre = saniyeler
yukleme); halka zaten gorunmez orman-duvari hucreleriyle engelli ve oyuncu hep halkanin onunde (kenardan 16 px iceride, halka hucreleri oyun alani disinda),
yani derinlik/sallanma gerekmez. Ressam algoritmasi: govde y'si kuculen -> buyuyen sirayla, her agac onceki agaclarla ortak hucre varsa bir ust katmana."""
import math, random
import numpy as np
from ring_core import *
from ring_stamps import build


class Noise:
    """gen_forest.py Noise ile ayni fikir: basit sin toplami (0..1)."""
    def __init__(self, seed, n=4, scale=0.8):
        r = random.Random(seed)
        self.w = []
        for i in range(n):
            ang = r.uniform(0, math.tau); f = r.uniform(0.035, 0.11) * scale * (1 + i * 0.35)
            self.w.append((math.cos(ang) * f, math.sin(ang) * f, r.uniform(0, math.tau), 1.0 / (1 + i * 0.4)))
        self.norm = sum(w[3] for w in self.w)

    def __call__(self, x, y):
        s = sum(a * math.sin(x * fx + y * fy + p) for fx, fy, p, a in self.w)
        return 0.5 + 0.5 * s / self.norm


def dil(m, r):
    out = m.copy()
    H, W = m.shape
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= r * r + r:
                sh = np.zeros_like(m)
                ys0, ys1 = max(0, dy), min(H, H + dy)
                xs0, xs1 = max(0, dx), min(W, W + dx)
                sh[ys0:ys1, xs0:xs1] = m[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx]
                out |= sh
    return out


def dist_to_play(x, y):
    """Halka hucresinin oyun alani dikdortgenine Chebyshev uzakligi (1 = hemen bitisik)."""
    dx = max(0 - x, 0, x - (PLAY - 1))
    dy = max(0 - y, 0, y - (PLAY - 1))
    return max(dx, dy)


def prep(st):
    a = st['alpha']
    st['opq'] = a >= 40
    st['npx'] = int(st['opq'].sum())
    st['base_row'] = (st['basepx'] - 1) // T
    st['cells'] = [(i, j, gid) for (i, j, gid) in st['tiles']]
    return st


def smoothstep(e0, e1, x):
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3.0 - 2.0 * t)


def place_forest(B, lib, seed=20261013, K=4, log=print):
    """SEYREK orman (2026-10-13 ikinci tur; kullanici: 'agaclar ust uste binmis, asiri detay, daha seyrek olmaliydi, koselerde cok keskin bitisler'):
    yerel kapsama hedefi (gürültüyle degisen: aciklik/öbek), agaclar neredeyse hic ust uste binmez (yeni piksel orani >= %78), az cins, serpistirme YOK,
    calilik sadece oyun alanina bitisik seritte seyrek. Orman kitlesinin kenari duz cizgi degil: yogunluk gürültü + mesafeyle yumusakca artar."""
    rng = random.Random(seed)
    TREES, SHRUBS, SHRUBS_DARK, MUSH, STUMPS, ROCKS = build(lib)
    for grp in list(TREES.values()) + [SHRUBS, SHRUBS_DARK]:
        for st in grp:
            prep(st)
    ring = B['ring']; water = B['water_ring']; grass = B['grass_ring']
    land = ring & ~water
    comp = B.get('completed', np.zeros((H2, W2), bool))
    forb = dil(water, 1) | ~ring | comp
    landpx = np.kron(land, np.ones((T, T), bool))
    covered = np.kron(comp, np.ones((T, T), bool))
    n_theme = Noise(23)
    n_dens = Noise(71, 5, 0.9)
    n_edge = Noise(97, 4, 1.4)
    # cıplak toprak payı (yumuşak): cins sınırı zemin sınırında duvar gibi kesilmesin (yarıçap 6 kutu bulanıklığı)
    dirt = (land & ~grass).astype(np.float32)
    R = 6
    cs = np.pad(dirt, ((R + 1, R), (R + 1, R))).cumsum(0).cumsum(1)
    dirt_frac = (cs[2 * R + 1:, 2 * R + 1:] - cs[:-2 * R - 1, 2 * R + 1:] - cs[2 * R + 1:, :-2 * R - 1] + cs[:-2 * R - 1, :-2 * R - 1]) / float((2 * R + 1) ** 2)
    accepted = []
    placed = {'tree': 0, 'shrub': 0, 'dropped': 0}
    land_cells = [(x, y) for y in range(Y0, Y0 + H2) for x in range(X0, X0 + W2) if land[y - Y0, x - X0]]

    def pick(lst):
        return rng.choice(lst)

    def tree_stamp(x, y):
        r = rng.random()
        if rng.random() < float(dirt_frac[y - Y0, x - X0]) ** 0.8:     # çıplak toprak yöresi: ölü ağaç
            return pick(TREES['dead'][:2])
        if n_theme(x, y) > 0.55:                            # koyu koru
            if r < 0.60: return pick(TREES['dark_pine'])
            if r < 0.85: return pick(TREES['mossy'][:2])
            return pick(TREES['lush_mid'])
        if r < 0.50: return pick(TREES['lush_mid'])         # açık koru
        if r < 0.82: return pick(TREES['lush_big'])
        if r < 0.92: return pick(TREES['dark_pine'])
        return pick(TREES['lush_small'])

    def local_cov(bx, by, rad=4):
        py0, px0 = max(0, (by - Y0 - rad) * T), max(0, (bx - X0 - rad) * T)
        py1, px1 = (by - Y0 + rad + 1) * T, (bx - X0 + rad + 1) * T
        return float(covered[py0:py1, px0:px1].mean())

    def propose(st, bx, by, thr):
        tx = bx - st['w'] // 2
        ty = by - st['base_row']
        for (i, j, gid) in st['cells']:
            x, y = tx + i, ty + j
            if not (X0 <= x < X0 + W2 and Y0 <= y < Y0 + H2) or forb[y - Y0, x - X0]:
                return False
        py, px = (ty - Y0) * T, (tx - X0) * T
        hh, ww = st['opq'].shape
        if py < 0 or px < 0 or py + hh > covered.shape[0] or px + ww > covered.shape[1]:
            return False
        cov = covered[py:py + hh, px:px + ww]
        newpx = int((st['opq'] & ~cov).sum())
        if newpx < thr * st['npx']:
            return False
        covered[py:py + hh, px:px + ww] |= st['opq']
        accepted.append((st, tx, ty))
        return True

    BASE = 0.50
    for sweep in range(2):
        order = land_cells[:]
        rng.shuffle(order)
        for (bx, by) in order:
            d = dist_to_play(bx, by)
            # yerel hedef kapsama: gürültüyle açıklık/öbek; oyun alanına yaklaştıkça YUMUŞAK seyrelme (düz bir orman duvarı çizgisi yok)
            ef = 0.20 + 0.80 * smoothstep(0.0, 12.0, d + 8.0 * (n_edge(bx, by) - 0.5))
            dirty = float(dirt_frac[by - Y0, bx - X0])
            target = BASE * (0.45 + 1.10 * n_dens(bx, by)) * ef * (1.0 - 0.5 * dirty)
            target = min(target, 0.66)
            if local_cov(bx, by) >= target:
                continue
            if d <= 2:
                continue                                    # ağaç sığmaz; çalı aşağıda
            if rng.random() < 0.55:
                continue
            if propose(tree_stamp(bx, by), bx, by, 0.80 + 0.14 * dirty):
                placed['tree'] += 1
    # nehir ağızları: su halkada devam etmiyor; kesik ucu yoğun çalılıkla örtülür (düz kesik görünmesin)
    mouth = B.get('mouth', np.zeros((H2, W2), bool))
    for rep in range(3):
        for (bx, by) in land_cells:
            if not mouth[by - Y0, bx - X0] or rng.random() > 0.55:
                continue
            if local_cov(bx, by, 1) > 0.70:
                continue
            st = pick(SHRUBS if grass[by - Y0, bx - X0] else SHRUBS_DARK)
            if propose(st, bx, by, 0.35):
                placed['shrub'] += 1
    # deniz kıyısı: düz uzayan kıyıyı yumuşatan seyrek kıyı bitkisi (suya bitişik 1-3 hücre)
    near_water = dil(water, 3) & ~dil(water, 1)
    for (bx, by) in land_cells:
        if not near_water[by - Y0, bx - X0] or rng.random() > 0.13:
            continue
        if local_cov(bx, by, 2) > 0.40:
            continue
        st = pick(SHRUBS if grass[by - Y0, bx - X0] else SHRUBS_DARK)
        if propose(st, bx, by, 0.7):
            placed['shrub'] += 1
    # oyun alanına yakın (<= 4 hücre) SEYREK çalı: görünmez duvarın önünde çıplak çimen kalmasın ama düz bir çalı hattı da olmasın
    for (bx, by) in land_cells:
        d = dist_to_play(bx, by)
        if d > 4:
            continue
        if n_edge(bx * 1.7, by * 1.7) < 0.40 or rng.random() > 0.10:
            continue
        if local_cov(bx, by, 2) > 0.45:
            continue
        st = pick(SHRUBS if grass[by - Y0, bx - X0] else SHRUBS_DARK)
        if propose(st, bx, by, 0.7):
            placed['shrub'] += 1

    # ---- katman atamasi (ressam): taban y'si kucukten buyuge; piksel ortusmesi olan onceki nesnenin ustune, ortak hucre bos olan en dusuk katman
    accepted.sort(key=lambda a: (a[2] * T + a[0]['basepx'], a[1]))
    occ = [np.zeros((H2, W2), bool) for _ in range(K)]
    ptop = np.full((H2 * T, W2 * T), -1, np.int8)
    layers_ = [np.zeros((H2, W2), np.int64) for _ in range(K)]
    for (st, tx, ty) in accepted:
        cells = [(tx + i, ty + j, gid) for (i, j, gid) in st['cells']]
        py, px = (ty - Y0) * T, (tx - X0) * T
        hh, ww = st['opq'].shape
        sub = ptop[py:py + hh, px:px + ww]
        under = sub[st['opq']]
        kmin = (int(under.max()) + 1) if under.size else 0
        kk = -1
        for k in list(range(kmin, K)) + list(range(min(kmin, K) - 1, -1, -1)):
            if all(not occ[k][y - Y0, x - X0] for (x, y, _) in cells):
                kk = k
                if k < kmin:
                    placed['order_relaxed'] = placed.get('order_relaxed', 0) + 1
                break
        if kk < 0:
            placed['dropped'] += 1
            continue
        for (x, y, gid) in cells:
            layers_[kk][y - Y0, x - X0] = gid
            occ[kk][y - Y0, x - X0] = True
        sub[st['opq']] = kk
    top = np.full((H2, W2), -1, np.int8)
    for k in range(K):
        top[occ[k]] = k
    kused = int(max(1, int(top.max()) + 1))
    cov_ratio = float((covered & landpx).sum()) / max(1, int(landpx.sum()))
    log(f'  orman: agac {placed["tree"]}, calilik {placed["shrub"]}, atilan {placed["dropped"]}, sirasi gevsetilen {placed.get("order_relaxed", 0)}, '
        f'katman {kused}/{K}, kara halka ortuleme %{cov_ratio * 100:.1f}, dolu hucre {int((top >= 0).sum())}')
    return layers_[:kused], covered, placed
