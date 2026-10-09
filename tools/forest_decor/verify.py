import sys; sys.path.insert(0, sys.argv[1]); sys.path.insert(0, __import__('os').path.dirname(__import__('os').path.abspath(__file__)))
from stamplib import *
import json
new_path = sys.argv[2]
rootA, tsA = load()                 # orijinal (harita/Harita.tmx)
rootB, tsB = load(new_path)         # yeni
LA = {'/'.join(p): grid(l) for p, l in layers(rootA)}
LB = {'/'.join(p): grid(l) for p, l in layers(rootB)}
TARGET = ['Shader Eklenecek/Ağaç 0', 'Shader Eklenecek/Ağaç 1', 'Shader Eklenecek/Ağaç 2', 'Shader Eklenecek/Çalılar1',
          'Shader Eklenecek/Çalılar', 'Shader Eklenecek/Animasyonsuz çalılar', 'Shader Eklenecek/Çiçekler 1']
# 1) hedef disi katman degismedi, hedeflerde sadece ekleme
ok = True
for k in LA:
    if k in TARGET:
        a, b = LA[k], LB[k]
        if not ((a == 0) | (a == b)).all(): print('HATA: mevcut hucre degisti', k); ok = False
        print(f'{k:45s} +{int(((b != 0) & (a == 0)).sum())} hucre')
    else:
        if not (LA[k] == LB[k]).all(): print('HATA: hedef disi katman degisti', k); ok = False
print('katman butunlugu', 'TAMAM' if ok else 'BOZUK')

# 2) agac gruplama (tree_sway kurali) + ayak izi
def decode(ts, gid):
    g = gid & 0x0FFFFFFF; t = ts.find(g)
    return (t[1], g - t[0], gid & 0xE0000000, t[3]) if t else None
def tree_groups(ts, g):
    cells = {(y, x): decode(ts, int(g[y, x])) for y, x in zip(*np.nonzero(g))}
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
    return list(groups.values())
def footprint_cells(ts, groups, g):
    fp = np.zeros((H, W), bool); n = 0; tall = []
    for ks in groups:
        ys = [k[0] for k in ks]; xs = [k[1] for k in ks]; y0, x0 = min(ys), min(xs)
        w = max(xs) - x0 + 1; h = max(ys) - y0 + 1
        al = np.zeros((h * T, w * T), np.uint8)
        for k in ks:
            im = ts.tile(int(g[k]))
            if im: al[(k[0] - y0) * T:(k[0] - y0 + 1) * T, (k[1] - x0) * T:(k[1] - x0 + 1) * T] = np.array(im.getchannel('A'))
        f, b = footprint({'alpha': al})
        for dx, dy in f:
            c = (x0 + dx, y0 + dy)
            if 0 <= c[0] < W and 0 <= c[1] < H: fp[c[1], c[0]] = True
        n += 1
        if h > 7: tall.append((x0, y0, w, h))
    return fp, n, tall
fpA = np.zeros((H, W), bool); fpB = np.zeros((H, W), bool); nA = nB = 0
for k in TARGET[:3]:
    gA = tree_groups(tsA, LA[k]); gB = tree_groups(tsB, LB[k])
    a, na, _ = footprint_cells(tsA, gA, LA[k]); b, nb, tall = footprint_cells(tsB, gB, LB[k])
    fpA |= a; fpB |= b; nA += na; nB += nb
    print(f'{k}: agac {na} -> {nb}  (yuksek grup: {tall[:5]})')
print('agac govde hucresi', int(fpA.sum()), '->', int(fpB.sum()))

M = np.load(sys.argv[1] + '/masks.npz')
wall, water_core, house, mine, base, bridge, dirt, grass = (M[k] for k in ('wall', 'water_core', 'house', 'mine', 'base', 'bridge', 'dirt', 'grass'))
# yeni govdeler yasak yerde mi
newfp = fpB & ~fpA
def dil(m, r):
    pad = np.pad(m, r, constant_values=False); o = np.zeros_like(m)
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            o |= pad[r + dy:r + dy + m.shape[0], r + dx:r + dx + m.shape[1]]
    return o
checks = {
    'duvar': wall, 'su': water_core, 'ev': house, 'maden': mine, 'dusman_ussu': base, 'kopru': bridge,
    'ev_yakini(3)': dil(house, 3), 'yol/toprak(1) barren disinda': dil(dirt, 1) & ~((np.arange(H)[:, None] >= 184) & (np.arange(W)[None, :] < 48)) & ~((np.arange(H)[:, None] >= 178) & (np.arange(W)[None, :] >= 186)),
}
for name, m in checks.items():
    print(f'  yeni govde {name}: {int((newfp & m).sum())}')

# 3) gecis: carpisma = duvar + su(1 yukari kaymis) + ev + maden + us + agac govdeleri
water_blk = np.roll(water_core, -1, 0); water_blk[-1, :] = False
bridge_open = np.roll(bridge, -1, 0)
water_blk &= ~bridge_open
def reach(block, start, agent=1):
    # agent=1: 3x3 komsulugu tamamen bos hucreler (oyuncu ~1.4 hucre)
    free = ~block
    if agent >= 1:
        pad = np.pad(block, 1, constant_values=True); er = np.zeros_like(block)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                er |= pad[1 + dy:1 + dy + H, 1 + dx:1 + dx + W]
        free = ~er
    seen = np.zeros((H, W), bool)
    if not free[start[1], start[0]]:
        # en yakin serbest hucre
        best = None
        for r in range(1, 12):
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    x, y = start[0] + dx, start[1] + dy
                    if 0 <= x < W and 0 <= y < H and free[y, x]: best = (x, y); break
                if best: break
            if best: break
        start = best
    st = [(start[1], start[0])]; seen[start[1], start[0]] = True
    while st:
        y, x = st.pop()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            yy, xx = y + dy, x + dx
            if 0 <= yy < H and 0 <= xx < W and free[yy, xx] and not seen[yy, xx]:
                seen[yy, xx] = True; st.append((yy, xx))
    return seen, free
base_block = wall | water_blk | house | mine | base
for agent in (0, 1):
    sA, fA = reach(base_block | fpA, (120, 86), agent)
    sB, fB = reach(base_block | fpB, (120, 86), agent)
    lost = sA & ~sB
    # kaybedilen hucrelerden 'baglanti kopan' olanlar: sB'de ulasilamayip fB'de serbest olanlar
    lost_free = lost & fB
    print(f'ajan={agent}: ulasilabilir {int(sA.sum())} -> {int(sB.sum())}; kopan(serbest) {int(lost_free.sum())}; fB serbest {int(fB.sum())}')
    # kopan alanlari kume kume yazdir
    if lost_free.any():
        ys, xs = np.nonzero(lost_free)
        print('   kopan hucre ornek:', list(zip(xs[:12].tolist(), ys[:12].tolist())))
# hedef noktalar: kapilar, maden, dusman ussu cevresi ulasilabilir mi
for nm, (x, y) in {'ev kapisi': (120, 84), 'demirci kapisi': (81, 149), 'maden(2,200)': (6, 200), 'dusman ussu': (232, 218)}.items():
    print(f'  {nm} ({x},{y}) ulasim A/B:', bool(reach(base_block | fpA, (120, 86), 1)[0][y, x]), bool(reach(base_block | fpB, (120, 86), 1)[0][y, x]))

# ------------------------------------------------------------------ 4) ust uste binme / kumsal / dar vadi (2026-10-09 geri bildirimi)
def cheb(m, maxd=9):
    d = np.full(m.shape, maxd + 1, np.int32); d[m] = 0; cur = m.copy()
    for k in range(1, maxd + 1):
        nxt = cur.copy()
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                s_ = np.roll(np.roll(cur, dy, 0), dx, 1)
                if dy == 1: s_[0, :] = False
                if dy == -1: s_[-1, :] = False
                if dx == 1: s_[:, 0] = False
                if dx == -1: s_[:, -1] = False
                nxt |= s_
        d[nxt & ~cur] = k; cur = nxt
    return d
blk = wall | water_blk | house | mine | base
R_ = 9; pad_ = np.pad(blk, R_, constant_values=True); D_ = np.full((H, W), 99.0)
for dy in range(-R_, R_ + 1):
    for dx in range(-R_, R_ + 1):
        d_ = (dx * dx + dy * dy) ** 0.5
        if d_ > R_: continue
        D_ = np.where(pad_[R_ + dy:R_ + dy + H, R_ + dx:R_ + dx + W] & (D_ > d_), d_, D_)
D_[blk] = 0
r_ = 5; padD = np.pad(D_, r_, constant_values=0); MXv = np.zeros((H, W))
for dy in range(-r_, r_ + 1):
    for dx in range(-r_, r_ + 1):
        if dx * dx + dy * dy <= r_ * r_: MXv = np.maximum(MXv, padD[r_ + dy:r_ + dy + H, r_ + dx:r_ + dx + W])
OBJL = {'T0': TARGET[0], 'T1': TARGET[1], 'T2': TARGET[2], 'BUSH': TARGET[3], 'REED': TARGET[4], 'OBJ': TARGET[5], 'FLOW': TARGET[6]}
newm = {k: (LB[v] != 0) & (LA[v] == 0) for k, v in OBJL.items()}
anyb = {k: LB[v] != 0 for k, v in OBJL.items()}
over = 0
for k in newm:
    for k2 in anyb:
        if k2 == k: continue
        if k == 'REED' or k2 == 'REED':
            # kamis (yeni) baska nesneyle ayni hucreyi paylasmasin; mevcut cim tutamlari (REED katmani) sayilmaz
            if k == 'REED': over += int((newm['REED'] & anyb[k2]).sum())
        else:
            over += int((newm[k] & anyb[k2]).sum())
print('ust uste binen hucre (yeni karo + baska nesne karosu, katmanlar arasi):', over)
dirt_ = M['dirt']; wcore = M['water_core']
beach_chk = (dirt_ & (cheb(wcore, 9) <= 8))
for k in newm: print(f'  kumsal (toprak, sudan <=8) uzerindeki yeni {k} karosu:', int((newm[k] & beach_chk).sum()))
newtree = newm['T0'] | newm['T1'] | newm['T2']
print('  yeni agac govdesi dar vadide (MX<5.2):', int((newfp & (MXv < 5.2)).sum()))
print('  yeni agac tacı dar vadide (MX<4.2, engel olmayan hucre):', int((newtree & ~blk & (MXv < 4.2)).sum()))
print('  yeni cali/nesne dar vadide (MX<4.6):', int(((newm['BUSH'] | newm['OBJ'] | newm['REED']) & ~blk & (MXv < 4.6)).sum()))
print('  yeni cicek dar vadide (MX<3.0):', int((newm['FLOW'] & ~blk & (MXv < 3.0)).sum()))
