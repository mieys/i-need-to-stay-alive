"""SAKLANMA ÇALILIĞI PROTOTİPLERİ v3 (madde 274, 2026-10-19; kullanıcı: "oyundaki saklanma çalıları için oyuncuların içine saklanabilmesine uygun olacak türden ve
oyunun görselliğiyle uyumlu olacak 4 çalı prototipi hazırlar mısın").
Şu anki atlas (madde 63/67, gen_lol_variants.py NATURAL) ince ot yapraklarından gürültülü bir halı: haritanın kendi çalılarındaki (harita/Objects.png) koyu kontür, hacim
ve pul pul yaprak öbeği dili yok. Bu prototipler o dilden türetilir - 4 yön = haritadaki 4 çalı ailesi, paletler Objects.png'den ÖLÇÜLDÜ:
  A Kabarık Çalı   - orta yeşil yuvarlak çalı (yuvarlak yaprak pulları)
  B Sivri Zeytin   - sarımsı zeytin çalı (yıldız biçimli sivri yaprak öbekleri)
  C Yaprak Öbekleri - ağaç taçlarındaki iri öbekler, aralarında koyu boşluk (LoL'deki "aralıklı tutam" hissi)
  D Çiçekli Çalı   - küçük yaprak + haritanın çiçek tonlarında seyrek çiçek
KARO DÜZENİ şu anki harita/saklanma_calilik.png ile AYNI (256x64: 16 sütun = kenar maskesi 1 üst/2 alt/4 sol/8 sağ açık, 4 satır = çeşit) -> seçilen atlas dosyanın
yerine konur, TMX/bake/kod değişmez.
DİKİŞSİZLİK: her karonun öbekleri karo içinde kalır; karo SINIRINA oturan öbekler ("sınır öbekleri") her karoda ve her çeşitte AYNIDIR (sınırın iki yanındaki karo
aynı öbeği aynı gölgeyle çizer) -> hangi çeşit yan yana gelirse gelsin desen sınırda kesilmez. Öbekler y'ye göre sıralı çizilir (alttaki öndedir); sınır öbeği üstteki
karoda en son, alttakinde en önce çizilir = genel y-sıralamasıyla tutarlı. Açık kenarda dış hat: kenara dizili "kenar öbekleri" (karo uçlarındaki ortak) + 1 px koyu
kontür; alt açık kenarda ön yüz bir ton koyu, altında 2 px yarı saydam gölge + taban otları (haritadaki çalıların tabanı gibi); iki yanı açık köşe yuvarlanır.
Çıktı (out/calilik/): atlas_{a,b,c,d}.png + onizleme.png (düz çimde hızlı bakış). Oyunda bakış: calilik_run.ps1 (gerçek çizici).
Kullanım (proje kökünden): python -I tools/proto_20261019/gen_calilik_proto.py
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'out', 'calilik')
os.makedirs(OUT, exist_ok=True)
TILE, SEEDS = 16, 4
TOP, BOTTOM, LEFT, RIGHT = 1, 2, 4, 8

## Kenar ölçüleri (karo içi px): üst açık kenarın taban çizgisi 7 (öbek tepeleri ~3'e çıkar), alt 10 (alt hat ~13,5, altında gölge), sol 4,5 / sağ 11,5.
T_BASE, B_BASE, L_BASE, R_BASE = 7.5, 9.6, 5.0, 11.0
CORNER_R = 11.0
END_RIM = 2.4   ## karo uçlarındaki ortak kenar öbeği küçük: komşu karoyla birleşme noktası hafif bir çukur
LIGHT = np.array([-0.5, -0.8, 0.9]) / np.linalg.norm([-0.5, -0.8, 0.9])
SHADOW = (25, 57, 38)
BASE_GRASS = [(86, 140, 77), (99, 166, 61)]

## palet: 0 kontür, 1 derin, 2..6 koyudan açığa (harita/Objects.png'deki çalılardan ölçüldü)
PAL_A = [(25, 57, 38), (37, 89, 58), (46, 106, 63), (58, 123, 64), (79, 145, 66), (99, 166, 61), (112, 184, 55)]
PAL_B = [(37, 62, 19), (83, 110, 37), (99, 127, 43), (108, 141, 50), (136, 163, 57), (160, 177, 65), (182, 190, 71)]
PAL_C = [(25, 57, 38), (39, 95, 62), (58, 123, 64), (79, 145, 66), (99, 166, 61), (112, 184, 55), (138, 200, 66)]
PAL_D = [(25, 57, 38), (45, 96, 57), (53, 113, 55), (77, 132, 59), (104, 150, 61), (135, 171, 62), (151, 186, 58)]
FLOWERS = [((240, 240, 226), (240, 206, 92)), ((236, 150, 178), (255, 220, 230)), ((246, 214, 98), (255, 244, 180))]

STYLES = {
    'a': dict(name='A · Kabarık Çalı', desc='haritanın orta yeşil yuvarlak çalısı', pal=PAL_A, shape='round', r_int=(2.9, 4.4), n_int=8,
              h_border=[(3.6, -0.4, 2.8), (8.6, 0.7, 3.4), (12.9, -0.2, 2.6)], v_border=[(0.4, 3.4, 2.7), (-0.5, 8.4, 3.3), (0.3, 12.8, 2.6)],
              corner=(0.3, -0.2, 2.6), rim=(3.2, 4.8), flower_p=0.0, fill=1),
    'b': dict(name='B · Sivri Zeytin', desc='haritanın sarımsı zeytin, sivri yapraklı çalısı', pal=PAL_B, shape='star', r_int=(3.8, 5.0), n_int=5,
              h_border=[(4.4, -0.3, 3.4), (11.6, 0.6, 3.7)], v_border=[(0.4, 4.6, 3.5), (-0.3, 11.4, 3.6)], corner=(0.2, -0.2, 3.0),
              rim=(3.4, 4.8), flower_p=0.0, fill=1),
    'c': dict(name='C · Yaprak Öbekleri', desc='ağaç taçlarındaki iri öbekler, aralarında koyu boşluk', pal=PAL_C, shape='cluster', r_int=(3.8, 5.0), n_int=2,
              h_border=[(4.2, 0.4, 3.4), (11.2, -0.5, 4.1)], v_border=[(0.5, 4.0, 3.6), (-0.4, 11.0, 3.9)], corner=(0.0, 0.0, 3.0),
              rim=(3.6, 5.0), flower_p=0.0, fill=1),
    'd': dict(name='D · Çiçekli Çalı', desc='küçük yapraklı çalı + haritanın çiçek tonları', pal=PAL_D, shape='round', r_int=(2.8, 3.9), n_int=9,
              h_border=[(3.6, -0.4, 2.7), (8.4, 0.5, 3.1), (12.7, -0.2, 2.6)], v_border=[(0.3, 3.6, 2.7), (-0.4, 8.2, 3.0), (0.2, 12.7, 2.6)],
              corner=(0.2, -0.2, 2.6), rim=(2.9, 4.0), flower_p=0.07, fill=1),
}


class Lobe:
    def __init__(self, x, y, r, key, style, kind='int'):
        self.x, self.y, self.r, self.key, self.kind = x, y, r, key, kind
        rng = random.Random(key)
        self.tone = rng.choice([0, 0, 0, -1]) if style['shape'] != 'cluster' else 0
        self.phase = rng.uniform(0, math.tau)
        self.points = rng.choice([5, 6, 7])
        self.flower = None   ## D: karo düzeyinde küme hâlinde atanır (lobes_for)
        self.fdx, self.fdy = rng.uniform(-0.35, 0.35), rng.uniform(-0.45, -0.1)
        ## C: iri öbeğin içindeki küçük pullar (öbek merkezine göre, r'nin oranı)
        self.subs = []
        if style['shape'] == 'cluster':
            for i in range(rng.randint(4, 6)):
                a = rng.uniform(0, math.tau)
                d = rng.uniform(0.15, 0.62)
                self.subs.append((math.cos(a) * d, math.sin(a) * d * 0.85, rng.uniform(0.32, 0.44)))
            self.subs.sort(key=lambda s: s[1])


def _gkey(*vals):
    h = 1469598103934665603
    for v in vals:
        h = ((h ^ int(round(v * 100))) * 1099511628211) & 0xFFFFFFFFFFFF
    return h


def lobes_for(mask, seed, st):
    """Karonun öbekleri: kapalı yanlarda ortak sınır öbekleri, açık yanlarda kenar öbekleri (uçtakiler ortak), içte çeşide özel öbekler."""
    L = []
    for (bx, jy, r) in st['h_border']:
        if not mask & TOP:
            L.append(Lobe(bx, jy, r, _gkey(1, bx, jy, r), st, 'border'))
        if not mask & BOTTOM:
            L.append(Lobe(bx, TILE + jy, r, _gkey(1, bx, jy, r), st, 'border'))
    for (jx, by, r) in st['v_border']:
        if not mask & LEFT:
            L.append(Lobe(jx, by, r, _gkey(2, jx, by, r), st, 'border'))
        if not mask & RIGHT:
            L.append(Lobe(TILE + jx, by, r, _gkey(2, jx, by, r), st, 'border'))
    cx, cy, cr = st['corner']
    for (ox, oy, need) in ((0, 0, TOP | LEFT), (TILE, 0, TOP | RIGHT), (0, TILE, BOTTOM | LEFT), (TILE, TILE, BOTTOM | RIGHT)):
        if not mask & need:
            L.append(Lobe(ox + cx, oy + cy, cr, _gkey(3, cx, cy, cr), st, 'border'))
    rng = random.Random(seed * 7919 + mask * 131 + 17)
    rim_lo, rim_hi = st['rim']
    ## kenar öbekleri: karo uçlarındakiler (x=0/16 ya da y=0/16) ortak ve küçük (END_RIM), aradakiler çeşide özel: ya iki öbek ya tek iri öbek
    ## (karodan karoya dalga boyu değişir -> dış hat 16 px'lik düzenli tırtıl gibi durmaz)
    def mids(r_lo, r_hi):
        out = []
        if rng.random() < 0.35:
            r = rng.uniform((r_lo + r_hi) / 2, r_hi + 0.6)
            out.append((8.0 + rng.uniform(-1.2, 1.2), r))
        else:
            for c0 in (5.0, 11.0):
                out.append((c0 + rng.uniform(-1.0, 1.0), rng.uniform(r_lo, r_hi)))
        return [(min(max(c, r), TILE - r), r) for (c, r) in out]

    rims = {}
    if mask & TOP:
        pts = [(0.0, T_BASE, END_RIM, _gkey(4, 0)), (16.0, T_BASE, END_RIM, _gkey(4, 0))]
        for (x, r) in mids(rim_lo, rim_hi):
            pts.append((x, T_BASE + rng.uniform(-1.0, 0.8), r, rng.getrandbits(40)))
        rims[TOP] = pts
    if mask & BOTTOM:
        pts = [(0.0, B_BASE, END_RIM, _gkey(5, 0)), (16.0, B_BASE, END_RIM, _gkey(5, 0))]
        for (x, r) in mids(rim_lo * 0.85, rim_lo + (rim_hi - rim_lo) * 0.45):
            pts.append((x, B_BASE + rng.uniform(-0.6, 0.5), r, rng.getrandbits(40)))
        rims[BOTTOM] = pts
    for side, base in ((LEFT, L_BASE), (RIGHT, R_BASE)):
        if mask & side:
            k = 6 if side == LEFT else 7
            pts = [(base, 0.0, END_RIM, _gkey(k, 0)), (base, 16.0, END_RIM, _gkey(k, 0))]
            for (y, r) in mids(rim_lo, rim_hi * 0.9):
                pts.append((base + rng.uniform(-0.8, 0.8), y, r, rng.getrandbits(40)))
            rims[side] = pts
    for side, pts in rims.items():
        for (x, y, r, k) in pts:
            L.append(Lobe(x, y, r, k, st, 'rim'))
    ## iç öbekler: karonun içinde kalır (sınıra en az 0,5 px). Yer = en iyi aday örneklemesi: 24 adaydan, henüz örtülmemiş en çok pikseli kaplayan
    ## (ızgara yerleşimi her karonun aynı yerinde boşluk bırakıp desen çizgisi oluşturuyordu)
    lo, hi = st['r_int']
    yy, xx = np.mgrid[0:TILE, 0:TILE] + 0.5
    cov = np.zeros((TILE, TILE), bool)
    for o in L:
        cov |= (xx - o.x) ** 2 + (yy - o.y) ** 2 <= (o.r * 0.92) ** 2
    for _ in range(st['n_int']):
        r = rng.uniform(lo, hi)
        best, best_s = None, -1.0
        for _c in range(24):
            x = rng.uniform(r + 0.5, TILE - r - 0.5)
            y = rng.uniform(r + 0.5, TILE - r - 0.5)
            disk = (xx - x) ** 2 + (yy - y) ** 2 <= (r * 0.92) ** 2
            sc = float((disk & ~cov).sum()) + rng.random()
            if sc > best_s:
                best, best_s = (x, y, disk), sc
        x, y, disk = best
        cov |= disk
        L.append(Lobe(x, y, r, rng.getrandbits(40), st, 'int'))
    ## D çiçekleri: çeşide göre 0-3 çiçeklik TEK küme (aynı renk, yan yana öbeklerde); her öbekte ayrı ayrı rastgele çiçek 4 çeşitle kafes gibi tekrar ediyordu
    if st['flower_p'] > 0:
        ints = [o for o in L if o.kind == 'int']
        n_fl = (2, 0, 3, 1)[seed % 4]
        if ints and n_fl:
            frng = random.Random(seed * 101 + mask)
            anchor_l = frng.choice(ints)
            col = frng.choice(FLOWERS)
            for o in sorted(ints, key=lambda o: (o.x - anchor_l.x) ** 2 + (o.y - anchor_l.y) ** 2)[:n_fl]:
                o.flower = col
    L.sort(key=lambda o: (o.y, o.x, o.key))
    return L, rims


def inside_fn(mask, rims):
    def in_rim(side, x, y):
        return any((x - cx) ** 2 + (y - cy) ** 2 <= r * r for (cx, cy, r, _) in rims.get(side, []))

    def inside(x, y):
        if mask & TOP and y < T_BASE and not in_rim(TOP, x, y):
            return False
        if mask & BOTTOM and y > B_BASE and not in_rim(BOTTOM, x, y):
            return False
        if mask & LEFT and x < L_BASE and not in_rim(LEFT, x, y):
            return False
        if mask & RIGHT and x > R_BASE and not in_rim(RIGHT, x, y):
            return False
        for (a, b, ccx, ccy) in ((TOP, LEFT, CORNER_R, CORNER_R), (TOP, RIGHT, TILE - CORNER_R, CORNER_R),
                                 (BOTTOM, LEFT, CORNER_R, TILE - CORNER_R), (BOTTOM, RIGHT, TILE - CORNER_R, TILE - CORNER_R)):
            if mask & a and mask & b:
                qx = x < ccx if ccx < TILE / 2 else x > ccx
                qy = y < ccy if ccy < TILE / 2 else y > ccy
                if qx and qy and (x - ccx) ** 2 + (y - ccy) ** 2 > CORNER_R ** 2:
                    return False
        return True
    return inside


def _tone(s):
    if s < -0.05:
        return 2
    if s < 0.3:
        return 3
    if s < 0.6:
        return 4
    if s < 0.84:
        return 5
    return 6


def _shade(dx, dy, rad):
    d2 = (dx * dx + dy * dy) / (rad * rad)
    nz = math.sqrt(max(0.0, 1.0 - d2))
    n = np.array([dx / rad, dy / rad, nz])
    n /= max(1e-6, np.linalg.norm(n))
    return float(n @ LIGHT), math.sqrt(d2)


def draw_lobe(idx, inmask, lb, st, flowers):
    r = lb.r
    x0, x1 = int(math.floor(lb.x - r - 1)), int(math.ceil(lb.x + r + 1))
    y0, y1 = int(math.floor(lb.y - r - 1)), int(math.ceil(lb.y + r + 1))
    for py in range(max(0, y0), min(TILE, y1 + 1)):
        for px in range(max(0, x0), min(TILE, x1 + 1)):
            if not inmask[py, px]:
                continue
            dx, dy = (px + 0.5 - lb.x) / r, (py + 0.5 - lb.y) / r
            rad = 1.0
            if st['shape'] == 'star':
                a = math.atan2(dy, dx)
                rad = 0.56 + 0.44 * (0.5 + 0.5 * math.cos(lb.points * (a - lb.phase))) ** 1.6
            s, d = _shade(dx, dy, rad)
            if d > 1.0:
                continue
            t = _tone(s) + lb.tone
            if st['shape'] == 'cluster':
                ## iri öbek: kenarda koyu halka, içte küçük pullar (her pul altında bir ton koyu hilal, üstünde bir ton açık)
                if d > 0.86 and dy > -0.35:
                    t = 1
                else:
                    for (sx, sy, sr) in lb.subs:
                        ex, ey = (dx - sx) / sr, (dy - sy) / sr
                        e2 = ex * ex + ey * ey
                        if e2 <= 1.0:
                            if e2 > 0.6 and ey > 0.1:
                                t -= 1
                            elif ey < -0.35 and e2 < 0.5:
                                t += 1
                            break
            else:
                ## yaprak pulu: altında/yanında koyu hilal (oyunun çalılarındaki pul deseni)
                if d > (0.86 if st['shape'] == 'star' else 0.78) and dy > -0.1:
                    t = 1
            idx[py, px] = int(min(6, max(1, t)))
    ## parıltı: sol üstte 1-2 px en açık ton
    hx, hy = int(math.floor(lb.x - 0.38 * r)), int(math.floor(lb.y - 0.45 * r))
    for (qx, qy) in ((hx, hy), (hx + 1, hy)) if r > 3.6 else ((hx, hy),):
        if 0 <= qx < TILE and 0 <= qy < TILE and inmask[qy, qx] and idx[qy, qx] >= 4:
            idx[qy, qx] = 6
    if lb.flower:
        fx, fy = int(math.floor(lb.x + lb.fdx * r)), int(math.floor(lb.y + lb.fdy * r))
        petal, center = lb.flower
        for (qx, qy, c) in ((fx, fy, center), (fx - 1, fy, petal), (fx + 1, fy, petal), (fx, fy - 1, petal), (fx, fy + 1, petal)):
            if 0 <= qx < TILE and 0 <= qy < TILE and inmask[qy, qx]:
                flowers[(qx, qy)] = c
        ## çiçek kaplanırsa sonra çizilen öbek siler (aşağıda)
    return


def tile(mask, seed, st):
    lobes, rims = lobes_for(mask, seed, st)
    inside = inside_fn(mask, rims)
    ext = np.zeros((TILE + 2, TILE + 2), bool)   ## 1 px taşkın alan: kontür için komşu hücrelerin içi/dışı
    for y in range(-1, TILE + 1):
        for x in range(-1, TILE + 1):
            ext[y + 1, x + 1] = inside(x + 0.5, y + 0.5)
    inmask = ext[1:-1, 1:-1]
    idx = np.full((TILE, TILE), -1, np.int8)
    idx[inmask] = st['fill']
    flowers = {}
    for lb in lobes:
        before = idx.copy()
        draw_lobe(idx, inmask, lb, st, flowers)
        ## sonra çizilen öbeğin kapladığı çiçek silinir
        changed = (idx != before)
        for k in [k for k in flowers if changed[k[1], k[0]] and not (lb.flower and k in _flower_px(lb))]:
            del flowers[k]
    ## alt açık kenar: ön yüz (alt hattın 3 px yukarısına kadar) bir ton koyu
    if mask & BOTTOM:
        for x in range(TILE):
            col = [y for y in range(TILE) if inmask[y, x]]
            if not col:
                continue
            yb = col[-1]
            for y in range(max(0, yb - 2), yb + 1):
                if idx[y, x] > 1:
                    idx[y, x] -= 1
    ## kontür: açık yana bakan dış piksel
    outline = np.zeros((TILE, TILE), bool)
    for y in range(TILE):
        for x in range(TILE):
            if inmask[y, x]:
                e = ext[y:y + 3, x:x + 3]
                if not (e[0, 1] and e[2, 1] and e[1, 0] and e[1, 2]):
                    outline[y, x] = True
    ## üst kenar: kontürün altındaki 2 px bir ton açık (ışık alan üst yüzey); sağ açık kenar: kontürün içindeki 1 px bir ton koyu
    if mask & TOP:
        for x in range(TILE):
            col = [y for y in range(TILE) if inmask[y, x]]
            if col:
                y0 = col[0]
                for y in (y0 + 1, y0 + 2):
                    if y < TILE and inmask[y, x] and 1 < idx[y, x] < 6:
                        idx[y, x] += 1
    if mask & RIGHT:
        for y in range(TILE):
            row = [x for x in range(TILE) if inmask[y, x]]
            if row:
                x0 = row[-1] - 1
                if x0 >= 0 and idx[y, x0] > 1:
                    idx[y, x0] -= 1
    img = np.zeros((TILE, TILE, 4), np.uint8)
    pal = st['pal']
    for y in range(TILE):
        for x in range(TILE):
            if idx[y, x] >= 0:
                c = pal[0] if outline[y, x] else pal[int(idx[y, x])]
                if (x, y) in flowers and not outline[y, x]:
                    c = flowers[(x, y)]
                img[y, x] = (*c, 255)
    if mask & BOTTOM:
        rng = random.Random(seed * 31 + mask)
        for x in range(TILE):
            col = [y for y in range(TILE) if inmask[y, x]]
            if not col:
                continue
            yb = col[-1]
            for k, a in enumerate((120, 70)):
                yy = yb + 1 + k
                if yy < TILE and img[yy, x, 3] == 0:
                    img[yy, x] = (*SHADOW, a)
        ## taban otları (haritadaki çalıların dibindeki kısa otlar gibi)
        for _ in range(rng.randint(1, 3)):
            x = rng.randint(2, 13)
            col = [y for y in range(TILE) if inmask[y, x]]
            if not col:
                continue
            yb = col[-1] + 1
            h = rng.randint(2, 3)
            lean = rng.choice([-1, 0, 1])
            for k in range(h):
                yy, xx = yb - k, x + (lean if k == h - 1 else 0)
                if 0 <= yy < TILE and 0 <= xx < TILE:
                    img[yy, xx] = (*BASE_GRASS[1 if k == h - 1 else 0], 255)
    return Image.fromarray(img, 'RGBA')


def _flower_px(lb):
    fx, fy = int(math.floor(lb.x + lb.fdx * lb.r)), int(math.floor(lb.y + lb.fdy * lb.r))
    return {(fx, fy), (fx - 1, fy), (fx + 1, fy), (fx, fy - 1), (fx, fy + 1)}


def build(st):
    atlas = Image.new('RGBA', (TILE * 16, TILE * SEEDS), (0, 0, 0, 0))
    for s in range(SEEDS):
        for m in range(16):
            atlas.alpha_composite(tile(m, s, st), (m * TILE, s * TILE))
    return atlas


## --- hızlı önizleme (düz çim; asıl bakış oyunun çizicisinde: calilik_run.ps1)
def _mask_of(cells, x, y):
    m = 0
    if (x, y - 1) not in cells:
        m |= TOP
    if (x, y + 1) not in cells:
        m |= BOTTOM
    if (x - 1, y) not in cells:
        m |= LEFT
    if (x + 1, y) not in cells:
        m |= RIGHT
    return m


def preview(atlases):
    W, H = 14, 9
    rng = random.Random(3)
    cells = set()
    for y in range(H):
        for x in range(W):
            if ((x - 6.5) / 5.6) ** 2 + ((y - 4.2) / 3.3) ** 2 <= 1.0 + 0.18 * math.sin(x * 1.7 + y):
                cells.add((x, y))
    cells.add((12, 6))
    cells.add((12, 7))
    cells.add((11, 7))
    panels = []
    for key, atlas in atlases:
        bg = Image.new('RGBA', ((W + 2) * TILE, (H + 2) * TILE), (104, 152, 72, 255))
        r2 = random.Random(5)
        for (x, y) in sorted(cells, key=lambda c: c[1]):
            mk = _mask_of(cells, x, y)
            s = r2.randrange(SEEDS)
            bg.alpha_composite(atlas.crop((mk * TILE, s * TILE, mk * TILE + TILE, s * TILE + TILE)), ((x + 1) * TILE, (y + 1) * TILE))
        panels.append((key, bg.resize((bg.width * 3, bg.height * 3), Image.NEAREST)))
    pw, ph = panels[0][1].size
    cols = 3
    rows = (len(panels) + cols - 1) // cols
    sheet = Image.new('RGB', (pw * cols + 10 * (cols + 1), (ph + 44) * rows + 10), (24, 24, 28))
    d = ImageDraw.Draw(sheet)
    try:
        f = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 22)
    except OSError:
        f = ImageFont.load_default()
    for i, (key, img) in enumerate(panels):
        cx, cy = 10 + (i % cols) * (pw + 10), 10 + (i // cols) * (ph + 44)
        sheet.paste(img.convert('RGB'), (cx, cy + 36))
        d.text((cx, cy + 4), 'ŞU AN' if key == 'simdi' else STYLES[key]['name'], fill=(240, 236, 220), font=f)
    return sheet


if __name__ == '__main__':
    proj = os.path.dirname(os.path.dirname(HERE))
    built = [('simdi', Image.open(os.path.join(proj, 'harita', 'saklanma_calilik.png')).convert('RGBA'))]
    for key, st in STYLES.items():
        a = build(st)
        a.save(os.path.join(OUT, 'atlas_%s.png' % key))
        built.append((key, a))
    preview(built).save(os.path.join(OUT, 'onizleme.png'))
    print('tamam')
