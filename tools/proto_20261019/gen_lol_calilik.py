"""SAKLANMA ÇALILIĞI - LoL TARZI, OYUNLA UYUMLU (madde 276, 2026-10-19; kullanıcı: "çalıları biraz league of legends tarzı yapar mısın fakat oyunla uyumlu
duracak biçimde. sallanmaya ve saklanmaya uyumlu olması gerekiyor unutma").
LoL'ün uzun, geniş, sivri yapraklı çalılığı (tepede dışarı taşan yaprak uçları, kenarda dışa yatan yapraklar, açık sarımsı uçlar) + haritanın çalı dili (madde 274:
Objects.png paletleri, 1 px koyu kontür, sol üstten ışık, koyu taban/ön yüz, altta yarı saydam gölge, yuvarlak köşe). Eski ince ot halısından (madde 63/67) farkı:
yapraklar 2,5-4,5 px GENİŞ ve öbek (tutam) hâlinde, uçlar sivri ve açık, her yaprağın sağ kenarı koyu (öbekler birbirinden ayrılır) -> gürültü değil, okunur şekil.
4 çeşit: L1 Uzun Yaprak (orta yeşil), L2 Mavi Yeşil (LoL'e en yakın renk), L3 Geniş Yaprak (iri, az, parlak), L4 Çalı + Yaprak (yuvarlak çalı pulları arasından yapraklar).
KARO DÜZENİ AYNI (256x64; sütun = kenar maskesi 1 üst/2 alt/4 sol/8 sağ açık, satır = 4 çeşit) -> seçilen atlas harita/saklanma_calilik.png yerine konur; hışırtı
(hide_brush_visual.gd) ve içerideki karakter örtüsü (saklanma_calilik.gdshader) atlası okuduğu için aynen çalışır.
DİKİŞSİZLİK: karo sınırına oturan tutamlar ("sınır tutamları") her karoda/çeşitte AYNI ve İLK çizilir; çeşide özel tutamlar sınır satır/sütunlarına hiç değmez
(yapraklar karo içinde 1 px pay bırakır) -> sınır pikselleri sadece ortak tutamlardan oluşur, hangi çeşit yan yana gelirse gelsin kesik yok. Sınır tutamları önce
çizildiği için iç tutamlar onları örter (her karonun altında aynı tutamın üstte durması = 16 px'lik tekrar olurdu). Kontür 1 px taşkın tuvalde hesaplanır
(taşkın = komşunun sınır sütunu = sadece ortak tutamlar -> komşuyla aynı karar).
Çıktı: out/calilik/atlas_l{1..4}.png + out/calilik/onizleme_lol.png. Oyunda: calilik_run.ps1 -Tags simdi,l1,l2,l3,l4 ; sayfa: calilik_sheet.py --tags simdi,l1,l2,l3,l4 --ad lol
Kullanım: python -I tools/proto_20261019/gen_lol_calilik.py
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_calilik_proto as P  # noqa: E402

OUT = P.OUT
TILE, SEEDS = 16, 4
TOP, BOTTOM, LEFT, RIGHT = 1, 2, 4, 8
E = 1                      ## taşkın (komşu karonun sınır pikseli)
N = TILE + 2 * E
## dolgu (koyu taban) sınırları - açık kenarda: üst 8,5 (yaprak uçları ~1'e kadar çıkar), alt 11,5 (+ kavis, altında gölge), sol 4 / sağ 12
T_FILL, B_FILL, L_FILL, R_FILL = 9.5, 11.2, 4.0, 12.0
CORNER_R = 10.0
ENV_R = 11.0          ## iki yanı açık üst köşede yaprak bölgesinin yayı
SHADOW = (25, 57, 38)
LIGHT = np.array([-0.5, -0.8, 0.9]) / np.linalg.norm([-0.5, -0.8, 0.9])

## palet 0 kontür, 1 derin, 2..5 gövde koyudan açığa, 6 uç, 7 uç parıltısı (Objects.png çalılarından; uçlar zeytin çalının açık tonları)
STYLES = {
    'l1': dict(name='L1 · Uzun Yaprak', desc='LoL çalılığı + haritanın orta yeşili, açık sarımsı uçlar',
               pal=[(25, 57, 38), (37, 89, 58), (46, 106, 63), (58, 123, 64), (79, 145, 66), (99, 166, 61), (136, 186, 62), (178, 206, 86)],
               w=(3, 3, 2), ln=(8.0, 11.5), tufts=5, leaves=(2, 3), spread=0.22, lobes=0),
    'l2': dict(name='L2 · Mavi Yeşil', desc='LoL çalılığının mavi-yeşil tonu (haritanın sivri çalısından), açık uçlar',
               pal=[(19, 54, 47), (36, 96, 70), (46, 118, 76), (56, 138, 78), (72, 158, 76), (92, 176, 70), (146, 202, 78), (190, 220, 104)],
               w=(3, 3, 2), ln=(8.0, 11.5), tufts=5, leaves=(2, 3), spread=0.22, lobes=0),
    'l3': dict(name='L3 · Geniş Yaprak', desc='iri, az ve parlak yapraklar (ağaç taçlarının yeşili)',
               pal=[(25, 57, 38), (39, 95, 62), (58, 123, 64), (79, 145, 66), (99, 166, 61), (112, 184, 55), (150, 204, 72), (194, 226, 104)],
               w=(4, 4, 3), ln=(7.0, 10.0), tufts=4, leaves=(2, 2), spread=0.28, lobes=0),
    'l4': dict(name='L4 · Çalı + Yaprak', desc='yuvarlak çalı pulları arasından yükselen LoL yaprakları',
               pal=[(25, 57, 38), (45, 96, 57), (53, 113, 55), (77, 132, 59), (104, 150, 61), (135, 171, 62), (160, 192, 66), (196, 214, 96)],
               w=(3, 2), ln=(7.0, 10.5), tufts=4, leaves=(2, 3), spread=0.22, lobes=2),
}


def _gkey(*vals):
    h = 1469598103934665603
    for v in vals:
        h = ((h ^ int(round(v * 100))) * 1099511628211) & 0xFFFFFFFFFFFF
    return h


class Item:
    """tutam (yapraklar) ya da L4'te yuvarlak pul; x,y = kök (karo koordinatı). Yaprak: H satır, kökte W px genişlik, lean = satır başına yatay kayma
    (uçta curve ile artar -> uç dışa kıvrılır)."""

    def __init__(self, kind, x, y, key, st, n_leaves=None, ln=None, fan=None, lean=0.0, r=0.0):
        self.kind, self.x, self.y, self.key, self.r = kind, x, y, key, r
        rng = random.Random(key)
        self.leaves = []
        if kind == 'tuft':
            lo, hi = st['leaves'] if n_leaves is None else n_leaves
            n = rng.randint(lo, hi)
            fan = st['spread'] if fan is None else fan
            lmin, lmax = st['ln'] if ln is None else ln
            for i in range(n):
                u = (i + 0.5) / n - 0.5 if n > 1 else 0.0
                ld = lean + u * 2 * fan + rng.uniform(-0.06, 0.06)
                H = int(round(rng.uniform(lmin, lmax) * (1.0 - 0.3 * abs(u) * 2)))
                self.leaves.append(dict(dx=(rng.uniform(-0.6, 0.6) + u * 1.5) * (0.6 if fan < 0.2 else 1.0), lean=ld, curve=rng.uniform(0.008, 0.03) * (1 if ld >= 0 else -1),
                                        H=max(3, H), W=rng.choice(st['w']), tone=rng.choice([0, 0, 0, -1])))
            ## ortadaki (uzun) yaprak en son: öne gelsin
            self.leaves.sort(key=lambda lf: -abs(lf['lean'] - lean))


def leaf_rows(it, lf):
    """yaprağın satırları: [(satır y (tam sayı, karo koord.), x0, x1, t)] kökten uca; genişlik kökte W, uca doğru 1'e iner"""
    rows = []
    by = int(math.floor(it.y))
    H, W = lf['H'], lf['W']
    for r in range(H):
        t = r / max(1, H - 1)
        cx = it.x + lf['dx'] + lf['lean'] * r + lf['curve'] * r * r
        w = max(1, int(round(W - (W - 1) * max(0.0, (t - 0.45) / 0.55) ** 0.9)))
        x0 = int(math.floor(cx - w / 2.0 + 0.5))
        rows.append((by - r, x0, x0 + w - 1, t))
    return rows


def fit_leaves(item, mask=0):
    """çeşide özel tutam: yaprak KAPALI yanda sınır satır/sütununa ve komşusuna değmesin (dış kontür sınır pikseline düşmesin); AÇIK yanda karo kenarına
    1 px kalana kadar serbest (sabit 2 px sınırı tepede/yanlarda dümdüz çizgi çiziyordu) - kısalt, olmazsa at"""
    lx = 1 if mask & LEFT else 2
    hx = TILE - 2 if mask & RIGHT else TILE - 3
    ly = 1 if mask & TOP else 2
    hy = TILE - 2 if mask & BOTTOM else TILE - 3
    keep = []
    for lf in item.leaves:
        while lf['H'] >= 3:
            rr = leaf_rows(item, lf)
            if all(ly <= y <= hy and lx <= x0 and x1 <= hx for (y, x0, x1, _) in rr):
                keep.append(lf)
                break
            lf['H'] -= 1
    item.leaves = keep
    return item


def _shared_items(mask, st):
    """karo sınırındaki ortak tutamlar (her karo/çeşitte aynı): kapalı yanlarda sınır tutamları, köşede küçük tutam; açık yanlarda uçtaki kenar tutamları"""
    out = []
    ## YATAY SINIR: kök sınırın ~3 px ALTINDA, yapraklar sınırı geçip üst karoya 4-5 satır girer -> sınır şeridinden yaprakların açık orta/uç kısımları geçer
    ## (kök sınırdayken her karo sırasında 4 satırlık koyu yatay bant oluşuyordu - madde 67'deki şikâyet)
    for (bx, jy, h) in ((3.0, 3.0, 7.5), (8.0, 2.4, 6.5), (12.6, 3.4, 8.0)):
        for (oy, need) in ((0.0, TOP), (16.0, BOTTOM)):
            if not mask & need:
                out.append(Item('tuft', bx, oy + jy, _gkey(1, bx, jy), st, n_leaves=(2, 2), ln=(h - 1.0, h), fan=0.18))
    ## DİKEY SINIR: üç dik tutam (yapraklar yatay sınırı geçmez)
    for (jx, by, h) in ((0.3, 4.6, 5.0), (-0.4, 9.6, 5.5), (0.2, 14.6, 5.5)):
        for (ox, need) in ((0.0, LEFT), (16.0, RIGHT)):
            if not mask & need:
                out.append(Item('tuft', ox + jx, by, _gkey(2, jx, by), st, n_leaves=(2, 2), ln=(h - 1.0, min(h, math.floor(by) + 1.0)), fan=0.12))
    for (ox, oy, need) in ((0, 0, TOP | LEFT), (16, 0, TOP | RIGHT), (0, 16, BOTTOM | LEFT), (16, 16, BOTTOM | RIGHT)):
        if not mask & need:
            out.append(Item('tuft', ox, oy, _gkey(3), st, n_leaves=(1, 1), ln=(3.0, 3.0), fan=0.0))
    ## açık kenar uç tutamları (komşu açık kenar karosuyla ortak)
    ## uç tutamı sadece KAPALI yana bitişik uçta (açık köşede komşu yok: yaprakları karo kenarında kesilip '▼' izi bırakıyordu)
    ends_x = [ox for ox, sd in ((0.0, LEFT), (16.0, RIGHT)) if not mask & sd]
    ends_y = [oy for oy, sd in ((0.0, TOP), (16.0, BOTTOM)) if not mask & sd]
    if mask & TOP:
        for ox in ends_x:
            out.append(Item('tuft', ox, T_FILL + 2.5, _gkey(4), st, n_leaves=(2, 2), ln=(7.0, 8.0), fan=0.3))
    if mask & BOTTOM:
        for ox in ends_x:
            out.append(Item('tuft', ox, B_FILL + 2.5, _gkey(5), st, n_leaves=(2, 2), ln=(4.0, 5.0), fan=0.3))
    for side, base, sign in ((LEFT, L_FILL + 1.5, -1), (RIGHT, R_FILL - 1.5, 1)):
        if mask & side:
            for oy in ends_y:
                out.append(Item('tuft', base, oy, _gkey(6, sign), st, n_leaves=(2, 2), ln=(4.0, 5.0), fan=0.2, lean=0.45 * sign))
    out.sort(key=lambda o: (o.y, o.x, o.key))
    return out


def _variant_items(mask, seed, st, fill_ok):
    rng = random.Random(seed * 7919 + mask * 131 + 29)
    items = []
    ## açık kenar tutamları: üstte uzun, dışa yatan yapraklar (LoL'ün sivri tepesi); yanlarda dışa yatık; altta kısa ön tutamlar
    if mask & TOP:
        for x0 in (4.5, 8.0, 11.5):
            x = x0 + rng.uniform(-1.0, 1.0)
            lean = (x - 8.0) / 8.0 * 0.25
            hmax = st['ln'][1] + rng.choice([-3.0, -1.5, 0.0, 1.0])
            items.append(Item('tuft', x, T_FILL + rng.uniform(2.0, 3.6), rng.getrandbits(40), st, n_leaves=(2, 3),
                              ln=(hmax - 2.5, hmax), fan=0.22, lean=lean))
    for side, base, sign in ((LEFT, L_FILL + 1.5, -1), (RIGHT, R_FILL - 1.5, 1)):
        if mask & side:
            for y0 in (5.5, 11.0):
                items.append(Item('tuft', base + rng.uniform(-0.6, 0.6), y0 + rng.uniform(-1.0, 1.0), rng.getrandbits(40), st,
                                  n_leaves=(2, 3), ln=(st['ln'][0] * 0.7, st['ln'][1] * 0.75), fan=0.15, lean=0.5 * sign))
    if mask & BOTTOM:
        for x0 in (4.5, 11.0):
            items.append(Item('tuft', x0 + rng.uniform(-1.0, 1.0), B_FILL + rng.uniform(1.6, 2.6), rng.getrandbits(40), st,
                              n_leaves=(2, 4), ln=(st['ln'][0] * 0.6, st['ln'][0] * 0.95)))
    ## iç: L4'te yuvarlak pullar + tutamlar; kök noktası en iyi aday örneklemesiyle (en az örtülen yer)
    taken = [(o.x, o.y) for o in items]
    for k in range(st['lobes']):
        r = rng.uniform(2.4, 3.2)
        best, bs = None, -1e9
        for _ in range(20):
            x, y = rng.uniform(r + 1.2, TILE - r - 1.2), rng.uniform(r + 1.2, TILE - r - 1.2)
            if not fill_ok(x, y):
                continue
            sc = min([math.hypot(x - a, y - b) for a, b in taken] + [9.0]) + rng.random() * 0.5
            if sc > bs:
                best, bs = (x, y), sc
        if best:
            taken.append(best)
            items.append(Item('lobe', best[0], best[1], rng.getrandbits(40), st, r=r))
    for k in range(st['tufts']):
        tall = k < (st['tufts'] * 2 + 2) // 3
        best, bs = None, -1e9
        for _ in range(24):
            x = rng.uniform(3.0, 13.0)
            y = rng.uniform(10.0, 13.8) if tall else rng.uniform(6.5, 10.0)
            if not fill_ok(x, y):
                continue
            sc = min([math.hypot(x - a, (y - b) * 1.6) for a, b in taken] + [9.0]) + rng.random() * 0.5
            if sc > bs:
                best, bs = (x, y), sc
        if best is None:
            continue
        taken.append(best)
        ln = st['ln'] if tall else (st['ln'][0] * 0.55, st['ln'][0] * 0.8)
        it = Item('tuft', best[0], best[1], rng.getrandbits(40), st, ln=ln, lean=rng.uniform(-0.12, 0.12))
        fit_leaves(it, mask)
        if it.leaves:
            items.append(it)
    for it in items:
        if it.kind == 'tuft':
            fit_leaves(it, mask)
    items = [it for it in items if it.kind == 'lobe' or it.leaves]
    items.sort(key=lambda o: (o.y, o.x))
    return items


def _fill_fn(mask, seed):
    rng = random.Random(seed * 31 + mask * 7 + 3)

    def scal(base_pts):
        return base_pts

    circ = {}
    if mask & BOTTOM:
        pts = [(0.0, B_FILL, 2.3), (16.0, B_FILL, 2.3)]
        for x0 in (4.5, 11.0):
            pts.append((x0 + rng.uniform(-1.0, 1.0), B_FILL + rng.uniform(-0.3, 0.4), rng.uniform(2.6, 3.4)))
        circ[BOTTOM] = pts
    for side, base in ((LEFT, L_FILL), (RIGHT, R_FILL)):
        if mask & side:
            pts = [(base, 0.0, 2.2), (base, 16.0, 2.2)]
            for y0 in (5.0, 11.0):
                pts.append((base + rng.uniform(-0.5, 0.5), y0 + rng.uniform(-1.0, 1.0), rng.uniform(2.4, 3.2)))
            circ[side] = pts

    def in_c(side, x, y):
        return any((x - cx) ** 2 + (y - cy) ** 2 <= r * r for (cx, cy, r) in circ.get(side, []))

    def ok(x, y):
        if mask & TOP and y < T_FILL:
            return False
        if mask & BOTTOM and y > B_FILL and not in_c(BOTTOM, x, y):
            return False
        if mask & LEFT and x < L_FILL and not in_c(LEFT, x, y):
            return False
        if mask & RIGHT and x > R_FILL and not in_c(RIGHT, x, y):
            return False
        for (a, b, ccx, ccy) in ((TOP, LEFT, CORNER_R, CORNER_R), (TOP, RIGHT, TILE - CORNER_R, CORNER_R),
                                 (BOTTOM, LEFT, CORNER_R, TILE - CORNER_R), (BOTTOM, RIGHT, TILE - CORNER_R, TILE - CORNER_R)):
            if mask & a and mask & b:
                qx = x < ccx if ccx < TILE / 2 else x > ccx
                qy = y < ccy if ccy < TILE / 2 else y > ccy
                if qx and qy and (x - ccx) ** 2 + (y - ccy) ** 2 > CORNER_R ** 2:
                    return False
        return True
    return ok


YY, XX = np.mgrid[0:N, 0:N].astype(float) - E + 0.5   ## taşkın tuvalin piksel merkezleri (karo koordinatı)


def draw_leaf(idx, it, lf, fill_mask):
    """SATIR SATIR (elle çizilmiş piksel yaprak): sol kenar açık, orta ton, sağ kenar koyu; sağındaki 1 px derin ton (yaprakları ayıran çizgi, sadece dolu
    zeminde); kök koyu, uca doğru açılır; uç pikseli açık sarımsı."""
    tone_off = lf['tone']
    for (y, x0, x1, t) in leaf_rows(it, lf):
        cy = y + E
        if cy < 0 or cy >= N:
            continue
        w = x1 - x0 + 1
        base = 3 if t < 0.25 else (4 if t < 0.6 else 5)
        for x in range(x0, x1 + 1):
            cx = x + E
            if cx < 0 or cx >= N:
                continue
            if t >= 0.86 and lf['H'] >= 6:
                v = 7 if (x == x0 and t >= 0.95) else 6   ## açık uç sadece uzun yapraklarda (kısa/arkadaki yaprakların ucu benek gibi duruyordu)
            elif t >= 0.86:
                v = 5
            elif w == 1:
                v = base + 1
            elif x == x0:
                v = min(5, base + 1) if t < 0.6 else 6   ## ışık alan sol kenar
            elif x == x1:
                v = base - 1          ## gölgede sağ kenar
            else:
                v = base
            idx[cy, cx] = int(min(7, max(1, v + (tone_off if t < 0.86 else 0))))
        sx = x1 + 1 + E
        if 0 <= sx < N and t < 0.86 and (idx[cy, sx] >= 0 or fill_mask[cy, sx]):
            idx[cy, sx] = 1


def draw_lobe(idx, it):
    r = it.r
    dx, dy = (XX - it.x) / r, (YY - it.y) / r
    d2 = dx * dx + dy * dy
    m = d2 <= 1.0
    nz = np.sqrt(np.clip(1 - d2, 0, 1))
    s = (dx * LIGHT[0] + dy * LIGHT[1] + nz * LIGHT[2]) / np.sqrt(dx * dx + dy * dy + nz * nz + 1e-9)
    tone = np.where(s < -0.05, 2, np.where(s < 0.3, 3, np.where(s < 0.6, 4, np.where(s < 0.84, 5, 6))))
    tone = np.where((d2 > 0.6) & (dy > -0.1), 1, tone)
    idx[m] = tone[m]


def tile(mask, seed, st):
    fill_ok = _fill_fn(mask, seed)
    idx = np.full((N, N), -1, np.int16)
    for yy in range(N):
        for xx in range(N):
            if fill_ok(xx - E + 0.5, yy - E + 0.5):
                idx[yy, xx] = 2
    fill_mask = idx >= 0
    for it in _shared_items(mask, st):
        for lf in it.leaves:
            draw_leaf(idx, it, lf, fill_mask)
    for it in _variant_items(mask, seed, st, fill_ok):
        if it.kind == 'lobe':
            draw_lobe(idx, it)
        else:
            for lf in it.leaves:
                draw_leaf(idx, it, lf, fill_mask)
    ## iki yanı açık üst köşe: yaprak bölgesi yarıçapı ENV_R yayla kırpılır (üst köşe kare kalıyordu); alt köşeyi dolgunun kendi yayı yuvarlar
    for (a, b2, ccx) in ((TOP, LEFT, ENV_R), (TOP, RIGHT, TILE - ENV_R)):
        if mask & a and mask & b2:
            ccy = 1.0 + ENV_R
            qx = (XX < ccx) if ccx < TILE / 2 else (XX > ccx)
            out_c = qx & (YY < ccy) & ((XX - ccx) ** 2 + (YY - ccy) ** 2 > ENV_R ** 2)
            idx[out_c] = -1
    ## açık yanda tuval dışı boş, kapalı yanda dolu sayılır (taşkın zaten komşunun sınır sütunu)
    op = idx >= 0
    pad = np.zeros((N + 2, N + 2), bool)
    pad[1:-1, 1:-1] = op
    if not mask & TOP:
        pad[0, :] = True
    if not mask & BOTTOM:
        pad[-1, :] = True
    if not mask & LEFT:
        pad[:, 0] = True
    if not mask & RIGHT:
        pad[:, -1] = True
    ## KONTÜR SİLÜETİN DIŞINDA (1 px, 4 komşu): ince yaprak uçları koyu çizgiyle ÇEVRELENİR (içe çizilince ucu yiyip tepede '^' izi bırakıyordu)
    near = pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:]
    inner = np.zeros((N + 2, N + 2), bool)
    inner[1:-1, 1:-1] = op
    near = inner[:-2, 1:-1] | inner[2:, 1:-1] | inner[1:-1, :-2] | inner[1:-1, 2:]
    edge = ~op & near
    idx = np.where(edge, 0, idx)
    ## alt açık: ön yüz (alt hattın 2 px yukarısı) bir ton koyu
    core = idx[E:E + TILE, E:E + TILE].copy()
    opc = core >= 0
    if mask & BOTTOM:
        for x in range(TILE):
            col = np.where(opc[:, x])[0]
            if len(col):
                yb = col[-1]
                for y in range(max(0, yb - 2), yb + 1):
                    if 2 < core[y, x] < 6:
                        core[y, x] -= 1
    pal = st['pal']
    img = np.zeros((TILE, TILE, 4), np.uint8)
    for y in range(TILE):
        for x in range(TILE):
            if core[y, x] >= 0:
                img[y, x] = (*pal[int(core[y, x])], 255)
    if mask & BOTTOM:
        for x in range(TILE):
            col = np.where(opc[:, x])[0]
            if len(col):
                yb = col[-1]
                for k, a in enumerate((120, 70)):
                    yy = yb + 1 + k
                    if yy < TILE and img[yy, x, 3] == 0:
                        img[yy, x] = (*SHADOW, a)
    return Image.fromarray(img, 'RGBA')


def build(st):
    atlas = Image.new('RGBA', (TILE * 16, TILE * SEEDS), (0, 0, 0, 0))
    for s in range(SEEDS):
        for m in range(16):
            atlas.alpha_composite(tile(m, s, st), (m * TILE, s * TILE))
    return atlas


if __name__ == '__main__':
    proj = os.path.dirname(os.path.dirname(HERE))
    built = [('simdi', Image.open(os.path.join(proj, 'harita', 'saklanma_calilik.png')).convert('RGBA'))]
    for key, st in STYLES.items():
        a = build(st)
        a.save(os.path.join(OUT, 'atlas_%s.png' % key))
        built.append((key, a))
        P.STYLES[key] = st   ## önizleme başlıkları
    P.preview(built).save(os.path.join(OUT, 'onizleme_lol.png'))
    print('tamam')
