"""LoL TARZI SAKLANMA ÇALILIĞI PROTOTİPLERİ (2026-10-09, 2. tur) - kullanıcı: "çalılar hoş fakat ben league of legends tarzı çalıları kastetmiştim,
aralarında hafif boşluklar olan türden. buna göre yeniden 4 tane prototip hazırlar mısın".

Tek büyük çalı DEĞİL: bir ALANA yayılmış, tek tek ot/yaprak öbeklerinden (tutam) oluşan çalılık. Tutamlar arasında hafif boşluklar var (gölgeli
zemin görünür), arka sıralar koyu / ön sıralar açık (derinlik), ön sıradaki tutamlar içerideki oyuncunun ÖNÜNE çizilir. Haritanın filiz/ot dili:
konturSUZ 1-2 px eğri yaprak vuruşları, gövde koyu -> uç açık (Çalılar katmanındaki exterior filizleri), renkler haritanın kendi sprite'larından.
  A  Uzun Ot          - sarı-yeşil uzun ot yaprakları (haritadaki filizlerin uzun/sık hâli), en "LoL" olan
  B  Eğrelti          - koyu deniz-yeşili, kemerli eğrelti yaprakları (yan yaprakçıklı)
  C  Gizemli Ot       - koyu ot, uçlarında mor/mavi (haritanın çiçek renkleri) - gizemli orman temasıyla
  D  Geniş Yapraklı   - zeytin yeşili geniş yapraklı öbekler (1 px koyu kenar + orta damar)
Çalılık Tiled'da istenen şekilde BOYANABİLİR olacak şekilde düşünüldü (tutam = küçük parça); burada iki örnek şekil var.
Çıktı (tools/hide_bush_proto/out/): brush_karsilastirma.png (boş / yanında oyuncu / içinde saklanmış oyuncu), brush_sekiller.png (aynı stilde uzun şerit +
L şekli), brush_yakin.png (8x), brush_{a,b,c,d}.png (şeffaf örnek çalılık).
Kullanım (proje kökünden): python -I tools/hide_bush_proto/gen_brush_proto.py
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'out')
os.makedirs(OUT, exist_ok=True)
PROJECT = os.path.normpath(os.path.join(HERE, '..', '..'))

# ---------------------------------------------------------------- paletler (koyu -> açık), haritadan ölçüldü
GRASS = [(40, 78, 24), (58, 100, 26), (78, 122, 26), (127, 165, 57), (177, 207, 82), (218, 235, 95)]   # Çalılar filizleri + koyu uzatma
FERN = [(20, 60, 54), (24, 78, 70), (39, 115, 69), (54, 140, 71), (64, 162, 61), (120, 196, 96)]
MYSTIC = [(18, 48, 46), (24, 78, 70), (36, 101, 68), (54, 140, 71), (86, 150, 96)]
MYSTIC_TIPS = [[(140, 70, 200), (190, 110, 235), (230, 190, 255)], [(75, 108, 196), (73, 138, 205), (185, 219, 255)]]
LEAF = [(25, 57, 38), (45, 96, 57), (53, 113, 55), (77, 132, 59), (104, 150, 61), (135, 171, 62), (151, 186, 58)]
GROUND_SHADE = (30, 62, 34)


# ---------------------------------------------------------------- piksel yardımcıları
class Img:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.a = np.zeros((h, w, 4), np.uint8)

    def put(self, x, y, c, alpha=255):
        x, y = int(round(x)), int(round(y))
        if not (0 <= x < self.w and 0 <= y < self.h):
            return
        if alpha >= 255:
            self.a[y, x] = (c[0], c[1], c[2], 255)
            return
        dst = self.a[y, x].astype(float)
        sa = alpha / 255.0
        da = dst[3] / 255.0
        oa = sa + da * (1 - sa)
        if oa <= 0:
            return
        rgb = (np.array(c, float) * sa + dst[:3] * da * (1 - sa)) / oa
        self.a[y, x] = (int(rgb[0]), int(rgb[1]), int(rgb[2]), int(oa * 255))

    def image(self):
        return Image.fromarray(self.a, 'RGBA')


def shift(ramp, k):
    """ramp'ı k kadar koyulaştır (arka sıralar)"""
    return [ramp[max(0, min(len(ramp) - 1, i - k))] for i in range(len(ramp))]


# ---------------------------------------------------------------- tutam çizicileri
def blade(img, x0, y0, h, lean, ramp, rng, tip=None, wide=True):
    """ot yaprağı: altta 2 px (sol açık / sağ koyu), üst %40'ta 1 px; taban koyu -> uç açık"""
    n = len(ramp)
    for i in range(h):
        t = i / max(1, h - 1)
        x = x0 + lean * (t ** 1.6) * h
        y = y0 - i
        idx = min(n - 1, int(1 + t * (n - 1.01)))
        if t < 0.9:
            idx = min(idx, n - 2)          # en parlak ton sadece en uçta (buğday tarlası gibi parlamasın)
        c = ramp[idx]
        if tip is not None and t > 0.72:
            c = tip[min(len(tip) - 1, int((t - 0.72) / 0.28 * len(tip)))]
        if wide and t < 0.75:
            img.put(x, y, c)
            img.put(x + 1, y, ramp[max(0, idx - 2)])
        else:
            img.put(x, y, c)


def tuft_grass(img, bx, by, ramp, rng, scale=1.0, tips=None, tip_p=0.0):
    """yelpaze öbek: 3-5 yaprak, ortadakiler uzun, yandakiler dışa eğik; tabanda koyu çekirdek (öbekler birbirinden ayrılsın)"""
    k = rng.randint(4, 6)
    hs = []
    for j in range(k):
        side = (j - (k - 1) / 2) / max(1, (k - 1) / 2)
        h = int(rng.uniform(12, 17) * scale * (1.0 - 0.30 * abs(side)))
        lean = side * rng.uniform(0.38, 0.68) + rng.uniform(-0.05, 0.05)
        hs.append((abs(side), side, h, lean))
    for _, side, h, lean in sorted(hs, key=lambda q: -q[0]):    # yandakiler önce, ortadakiler üstte
        tip = rng.choice(tips) if tips and rng.random() < tip_p else None
        blade(img, bx + side * 2.2, by, max(6, h), lean, ramp, rng, tip=tip, wide=True)
    for dx in (-2, -1, 0, 1, 2, 3):
        img.put(bx + dx, by + 1, ramp[0], 120 if abs(dx) < 2 else 70)


def frond(img, x0, y0, L, ang0, curl, ramp, rng):
    """kemerli eğrelti yaprağı: koyu gövde, iki yanda uca doğru kısalan, uca doğru yatık yaprakçıklar (düzenli desen)"""
    x, y, a = float(x0), float(y0), ang0
    n = len(ramp)
    sgn = 1 if ang0 >= 0 else -1
    pts = []
    for i in range(L):
        x += math.sin(a)
        y -= math.cos(a)
        a += curl * sgn
        pts.append((x, y, a, i / L))
    # önce yaprakçıklar, sonra gövde (gövde üstte okunur)
    for i, (x, y, a, t) in enumerate(pts):
        if i < 1 or i % 2:
            continue
        ll = max(1, int(round((1 - t) * 4.0)))
        dx, dy = math.sin(a), -math.cos(a)
        px, py = math.cos(a), math.sin(a)
        for side in (-1, 1):
            upper = (side * sgn) < 0
            for kk in range(1, ll + 1):
                fx = x + side * px * kk + dx * kk * 0.55
                fy = y + side * py * kk + dy * kk * 0.55
                tone = ramp[min(n - 1, 3 + (1 if upper else 0) + (1 if kk == 1 and upper else 0))] if kk < ll else ramp[min(n - 1, 4 if upper else 3)]
                img.put(fx, fy, tone)
    for (x, y, a, t) in pts:
        img.put(x, y, ramp[min(n - 1, 1 + int(t * 2))])


def tuft_fern(img, bx, by, ramp, rng, scale=1.0):
    k = rng.randint(3, 4)
    for j in range(k):
        side = (j - (k - 1) / 2) / max(1, (k - 1) / 2)
        L = int(rng.uniform(12, 17) * scale * (1.0 - 0.2 * abs(side)))
        ang = side * rng.uniform(0.5, 0.85) + rng.uniform(-0.08, 0.08)
        frond(img, bx + side * 1.5, by, L, ang, rng.uniform(0.045, 0.075), ramp, rng)
    for dx in (-2, -1, 0, 1, 2):
        img.put(bx + dx, by + 1, ramp[0], 120 if abs(dx) < 2 else 70)


def leaf(img, x0, y0, L, wd, ang, ramp, rng):
    """geniş yaprak: dolu, kontur SADECE gölge yanında (alt/sağ), açık orta damar, sol-üst kenar açık"""
    dx, dy = math.sin(ang), -math.cos(ang)
    px_, py_ = math.cos(ang), math.sin(ang)
    cells = {}
    s = 0.0
    while s <= L:
        w = wd * (math.sin(math.pi * min(1.0, s / L * 0.94 + 0.03)) ** 0.7)
        u = -w
        while u <= w + 1e-6:
            X = int(round(x0 + dx * s + px_ * u))
            Y = int(round(y0 + dy * s + py_ * u))
            cells[(X, Y)] = (s / L, u / max(w, 0.01))
            u += 0.5
        s += 0.5
    n = len(ramp)
    for (X, Y), (t, uu) in cells.items():
        out_r = (X + 1, Y) not in cells
        out_b = (X, Y + 1) not in cells
        out_l = (X - 1, Y) not in cells
        out_t = (X, Y - 1) not in cells
        if out_r or out_b:
            c = ramp[0] if (out_r and out_b) or t < 0.5 else ramp[1]
        elif out_l or out_t:
            c = ramp[n - 1]
        elif abs(uu) < 0.25 and 0.15 < t < 0.85:
            c = ramp[n - 2]
        else:
            c = ramp[4 if uu < 0 else 3]
        img.put(X, Y, c)


def tuft_leaves(img, bx, by, ramp, rng, scale=1.0):
    k = rng.randint(2, 4)
    angs = [rng.uniform(-1.15, 1.15) for _ in range(k)]
    for ang in sorted(angs, key=lambda a: -abs(a)):
        L = rng.uniform(9.0, 13.0) * scale * (1.0 - 0.15 * abs(ang))
        leaf(img, bx + math.sin(ang) * 1.5, by, L, rng.uniform(2.6, 3.6) * scale, ang, ramp, rng)
    for dx in (-2, -1, 0, 1, 2):
        img.put(bx + dx, by + 1, ramp[0], 130 if abs(dx) < 2 else 80)


STYLES = {
    'a': dict(name='A  Uzun Ot', draw=lambda im, x, y, ramp, rng: tuft_grass(im, x, y, ramp, rng), ramp=GRASS, sx=7.6, sy=5.0, skip=0.10),
    'b': dict(name='B  Eğrelti', draw=lambda im, x, y, ramp, rng: tuft_fern(im, x, y, ramp, rng), ramp=FERN, sx=9.2, sy=5.6, skip=0.10),
    'c': dict(name='C  Gizemli Ot', draw=lambda im, x, y, ramp, rng: tuft_grass(im, x, y, ramp, rng, tips=MYSTIC_TIPS, tip_p=0.45), ramp=MYSTIC, sx=7.6, sy=5.0, skip=0.10),
    'd': dict(name='D  Geniş Yapraklı', draw=lambda im, x, y, ramp, rng: tuft_leaves(im, x, y, ramp, rng), ramp=LEAF, sx=9.0, sy=5.6, skip=0.10),
}


# ---------------------------------------------------------------- 3. TUR: A + C KARIŞIMI (kullanıcı: "3 ve 1'i karıştırır mısın fakat 3 çok koyu renkli,
# zeminle uyumsuz oluyor biraz"). C'nin koyu deniz-yeşili yerine çime (126,176,84) yakın, daha açık ve daha az mavi bir yeşil; uçlar aynı mor/mavi.
MYSTIC_LIGHT = [(42, 88, 50), (56, 114, 60), (74, 140, 70), (98, 162, 82), (130, 184, 96), (166, 206, 118)]


def _shift_of(ramp, base):
    """Brush.render'ın verdiği (arka sıra için koyulaştırılmış) ramp'tan koyulaştırma miktarını bul"""
    for k in range(4):
        if ramp == shift(base, k):
            return k
    return 0


def tuft_mix(img, bx, by, ramp, rng, p_c, per_blade, tip_c, tip_a):
    """p_c: gizemli (açık) ot oranı; per_blade=False -> öbek öbek, True -> her öbekte iki tür yaprak birlikte"""
    k = _shift_of(ramp, GRASS)
    ra, rc = shift(GRASS, k), shift(MYSTIC_LIGHT, k)
    if not per_blade:
        if rng.random() < p_c:
            tuft_grass(img, bx, by, rc, rng, tips=MYSTIC_TIPS, tip_p=tip_c)
        else:
            tuft_grass(img, bx, by, ra, rng, tips=MYSTIC_TIPS, tip_p=tip_a)
        return
    n = rng.randint(4, 6)
    hs = []
    for j in range(n):
        side = (j - (n - 1) / 2) / max(1, (n - 1) / 2)
        h = int(rng.uniform(12, 17) * (1.0 - 0.30 * abs(side)))
        lean = side * rng.uniform(0.38, 0.68) + rng.uniform(-0.05, 0.05)
        hs.append((abs(side), side, h, lean))
    for _, side, h, lean in sorted(hs, key=lambda q: -q[0]):
        is_c = rng.random() < p_c
        tip = rng.choice(MYSTIC_TIPS) if rng.random() < (tip_c if is_c else tip_a) else None
        blade(img, bx + side * 2.2, by, max(6, h), lean, rc if is_c else ra, rng, tip=tip, wide=True)
    for dx in (-2, -1, 0, 1, 2, 3):
        img.put(bx + dx, by + 1, ra[0], 120 if abs(dx) < 2 else 70)


STYLES.update({
    'k1': dict(name='K1  Dengeli', note='yarı uzun ot, yarı\naçık gizemli ot',
               draw=lambda im, x, y, ramp, rng: tuft_mix(im, x, y, ramp, rng, p_c=0.5, per_blade=False, tip_c=0.5, tip_a=0.0),
               ramp=GRASS, sx=7.6, sy=5.0, skip=0.10),
    'k2': dict(name='K2  Çoğunlukla Ot', note='ot ağırlıklı, mor-mavi\nseyrek vurgu',
               draw=lambda im, x, y, ramp, rng: tuft_mix(im, x, y, ramp, rng, p_c=0.28, per_blade=False, tip_c=0.42, tip_a=0.0),
               ramp=GRASS, sx=7.6, sy=5.0, skip=0.10),
    'k3': dict(name='K3  İç İçe', note='her öbekte iki tür\nyaprak birlikte',
               draw=lambda im, x, y, ramp, rng: tuft_mix(im, x, y, ramp, rng, p_c=0.45, per_blade=True, tip_c=0.38, tip_a=0.0),
               ramp=GRASS, sx=7.6, sy=5.0, skip=0.10),
})


# ---------------------------------------------------------------- çalılık alanı
def blob_mask(w, h, blobs):
    yy, xx = np.mgrid[0:h, 0:w]
    f = np.full((h, w), -1.0)
    for (cx, cy, rx, ry, wob) in blobs:
        dx = (xx - cx) / rx
        dy = (yy - cy) / ry
        r = np.sqrt(dx * dx + dy * dy)
        th = np.arctan2(dy, dx)
        ww = np.ones_like(r)
        for (k, amp, ph) in wob:
            ww += amp * np.sin(k * th + ph)
        f = np.maximum(f, 1.0 - r / ww)
    return f > 0


def tuft_sites(mask, sx, sy, skip, rng, holes=2):
    """jitter'lı ızgara + rastgele atlama + birkaç küçük boşluk ("aralarında hafif boşluklar")"""
    h, w = mask.shape
    sites = []
    ys = np.arange(2, h, sy)
    hole_pts = []
    pts_in = list(zip(*np.nonzero(mask)))
    for _ in range(holes):
        y, x = pts_in[rng.randrange(len(pts_in))]
        hole_pts.append((x, y))
    for ri, y in enumerate(ys):
        off = (sx / 2) if ri % 2 else 0.0
        for x in np.arange(2 + off, w, sx):
            jx, jy = x + rng.uniform(-1.6, 1.6), y + rng.uniform(-1.2, 1.2)
            ix, iy = int(round(jx)), int(round(jy))
            if not (0 <= ix < w and 0 <= iy < h) or not mask[iy, ix]:
                continue
            if rng.random() < skip:
                continue
            if any((ix - hx) ** 2 + (iy - hy) ** 2 < 22 for hx, hy in hole_pts):
                continue
            sites.append((jx, jy))
    return sites


class Brush:
    """bir çalılık: zemin gölgesi + tutam listesi (taban y'ye göre sıralı; içerideki oyuncunun önü/arkası için)"""

    def __init__(self, key, mask, seed, pad_top=20, pad_x=12):
        self.key = key
        st = STYLES[key]
        self.rng = random.Random(seed)
        self.mask = mask
        self.pad_top = pad_top
        self.pad_x = pad_x                         # yana eğilen yapraklar tuval kenarında kesilmesin
        mh, mw = mask.shape
        self.w, self.h = mw + 2 * pad_x, mh + pad_top
        self.sites = sorted(tuft_sites(mask, st['sx'], st['sy'], st['skip'], self.rng), key=lambda p: p[1])
        self.seeds = [self.rng.randrange(1 << 30) for _ in self.sites]

    def _ground(self, img):
        m = self.mask
        p = np.pad(m, 1, constant_values=False)
        er = m & p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:]
        for y, x in zip(*np.nonzero(m)):
            edge = not er[y, x]
            if edge and (x + y) % 2:
                continue
            img.put(x + self.pad_x, y + self.pad_top, GROUND_SHADE, 58 if edge else 92)

    def render(self, back_of=None, front_of=None, ground=True):
        """back_of=y: sadece tabanı y'den yukarıdaki tutamlar (oyuncunun arkası); front_of=y: sadece aşağıdakiler (önü)"""
        st = STYLES[self.key]
        img = Img(self.w, self.h)
        if ground and front_of is None:
            self._ground(img)
        n = len(self.sites)
        ys = [p[1] for p in self.sites]
        y0, y1 = (min(ys), max(ys)) if ys else (0, 1)
        for (x, y), sd in zip(self.sites, self.seeds):
            by = y + self.pad_top
            if back_of is not None and by > back_of:
                continue
            if front_of is not None and by <= front_of:
                continue
            depth = (y - y0) / max(1.0, y1 - y0)       # 0 arka, 1 ön
            k = 1 if depth < 0.45 else 0
            st['draw'](img, x + self.pad_x, by, shift(st['ramp'], k), random.Random(sd))
        return img.image()


def shape_main(key):
    return blob_mask(92, 40, [(46, 20, 44, 17, [(3, 0.08, 0.5), (5, 0.06, 1.9)]), (24, 22, 18, 15, [(4, 0.07, 2.2)]),
                               (70, 19, 20, 15, [(5, 0.07, 0.8)])])


def shape_strip(key):
    return blob_mask(140, 24, [(70, 12, 68, 10, [(4, 0.07, 1.2), (9, 0.05, 0.3)])])


def shape_l(key):
    return blob_mask(84, 68, [(26, 34, 20, 32, [(4, 0.07, 0.4)]), (52, 54, 32, 12, [(5, 0.07, 2.0)])])


# ---------------------------------------------------------------- önizleme
def _font(size):
    for cand in (r'C:\Windows\Fonts\segoeui.ttf', r'C:\Windows\Fonts\arial.ttf'):
        if os.path.exists(cand):
            return ImageFont.truetype(cand, size)
    return ImageFont.load_default()


def grass_patch(w_cells, h_cells):
    import sys
    try:
        sys.path.insert(0, os.path.join(PROJECT, 'tools', 'forest_decor'))
        os.environ.setdefault('HARITA_TMX', os.path.join(PROJECT, 'harita', 'yedek', 'Harita_YEDEK_2026-10-09_agac-oncesi.tmx.bak'))
        from tmxlib import load, render, layers, grid  # noqa
        root, ts = load()
        L = {'/'.join(p): grid(l) for p, l in layers(root)}
        busy = np.zeros(L['Yer/Zemin Çimen'].shape, bool)
        for k in L:
            if k.startswith('Shader Eklenecek/') and 'Çalılar' not in k and 'Çiçek' not in k:
                busy |= L[k] != 0
        for k in ('Orman parçaları/Orman parçaları', 'Orman parçaları/Orman parçaları 2', 'Su/Su', 'Köprü/Köprü alt'):
            busy |= L[k] != 0
        grass = L['Yer/Zemin Çimen'] != 0
        for y in range(20, 230 - h_cells):
            for x in range(20, 230 - w_cells, 3):
                if grass[y:y + h_cells, x:x + w_cells].all() and not busy[y - 2:y + h_cells + 2, x - 2:x + w_cells + 2].any():
                    return render(root, ts, region=(x, y, x + w_cells, y + h_cells)).convert('RGBA')
    except Exception as ex:  # noqa
        print('harita parcasi yok:', ex)
    return Image.new('RGBA', (w_cells * 16, h_cells * 16), (126, 176, 84, 255))


def player_frame(alpha=1.0):
    sheet = Image.open(os.path.join(PROJECT, 'assets', 'characters', 'assasin', 'sheets', 'idle.png')).convert('RGBA')
    fr = sheet.crop((0, 0, 48, 48))
    s = 1.0845                                       # oyunda: 1,0845 ekran pikseli / sanat pikseli (dünya x2 ekranda)
    fr = fr.resize((int(round(48 * s)), int(round(48 * s))), Image.NEAREST)
    if alpha < 1.0:
        a = np.array(fr)
        a[..., 3] = (a[..., 3] * alpha).astype(np.uint8)
        fr = Image.fromarray(a, 'RGBA')
    return fr


PLAYER_FOOT = 43          # ölçeklenmiş karede ayak satırı (ekran px; kare 52 px, sanat ayağı 40/48)


def compose_main(brushes):
    cols = ['boş', 'yanında oyuncu (gerçek ölçek)', 'içinde saklanmış oyuncu']
    pw, ph = 262, 150                                 # ekran px (dünya x2)
    gx, gy = 4, 4
    left, top = 190, 34
    W = left + 3 * (pw * 2 + gx)
    H = top + len(brushes) * (ph * 2 + gy)
    sheet = Image.new('RGB', (W, H), (24, 28, 24))
    d = ImageDraw.Draw(sheet)
    f1, f2 = _font(22), _font(15)
    notes = {'a': 'haritadaki filizlerin\nuzun / sık hâli', 'b': 'koyu, yan yaprakçıklı\neğrelti', 'c': 'koyu ot, uçlarda\nmor-mavi', 'd': 'kenarlı geniş\nyapraklar'}
    bg0 = grass_patch(16, 11)
    bg0 = bg0.resize((bg0.width * 2, bg0.height * 2), Image.NEAREST)
    pf = player_frame()
    pf_hidden = player_frame(0.62)
    for ri, br in enumerate(brushes):
        full = br.render()
        sp2 = full.resize((full.width * 2, full.height * 2), Image.NEAREST)
        for ci in range(3):
            ox, oy = (ci * 41 + ri * 13) % (bg0.width - pw), (ri * 31) % (bg0.height - ph)
            panel = bg0.crop((ox, oy, ox + pw, oy + ph)).copy()
            bx = (pw - sp2.width) // 2 if ci != 1 else (pw - sp2.width - pf.width - 4) // 2   # yanında: çalılık + oyuncu birlikte ortalı
            by = ph - sp2.height - 4
            if ci == 0:
                panel.alpha_composite(sp2, (bx, by))
            elif ci == 1:
                panel.alpha_composite(sp2, (bx, by))
                foot = by + int(sp2.height * 0.72)
                panel.alpha_composite(pf, (bx + sp2.width + 2, foot - PLAYER_FOOT))
            else:
                # oyuncunun ayağı çalılığın ortasında: arkadaki tutamlar -> oyuncu (yarı saydam) -> öndeki tutamlar
                foot_world = br.pad_top + int(br.mask.shape[0] * 0.55)
                back = br.render(back_of=foot_world).resize((full.width * 2, full.height * 2), Image.NEAREST)
                front = br.render(front_of=foot_world).resize((full.width * 2, full.height * 2), Image.NEAREST)
                panel.alpha_composite(back, (bx, by))
                panel.alpha_composite(pf_hidden, (bx + sp2.width // 2 - pf.width // 2, by + foot_world * 2 - PLAYER_FOOT))
                panel.alpha_composite(front, (bx, by))
            panel = panel.resize((pw * 2, ph * 2), Image.NEAREST)
            sheet.paste(panel.convert('RGB'), (left + ci * (pw * 2 + gx), top + ri * (ph * 2 + gy)))
        d.text((12, top + ri * (ph * 2 + gy) + 100), STYLES[br.key]['name'], fill=(255, 255, 255), font=f1)
        d.multiline_text((12, top + ri * (ph * 2 + gy) + 134), STYLES[br.key].get('note') or notes.get(br.key, ''), fill=(190, 210, 190), font=f2, spacing=3)
    for ci, t in enumerate(cols):
        d.text((left + ci * (pw * 2 + gx) + 6, 8), t, fill=(210, 230, 210), font=f2)
    return sheet


def compose_shapes(keys):
    """aynı stilde farklı şekiller: Tiled'da boyanabilir olduğunu göstermek için uzun şerit + L"""
    pw, ph = 330, 190
    left, top = 190, 34
    sheet = Image.new('RGB', (left + 2 * (pw * 2 + 4), top + len(keys) * (ph * 2 + 4)), (24, 28, 24))
    d = ImageDraw.Draw(sheet)
    f1, f2 = _font(22), _font(15)
    bg0 = grass_patch(22, 13)
    bg0 = bg0.resize((bg0.width * 2, bg0.height * 2), Image.NEAREST)
    for ri, k in enumerate(keys):
        for ci, (shape, seed) in enumerate(((shape_strip(k), 900 + ri), (shape_l(k), 950 + ri))):
            br = Brush(k, shape, seed)
            im = br.render()
            sp2 = im.resize((im.width * 2, im.height * 2), Image.NEAREST)
            ox, oy = (ci * 53 + ri * 17) % max(1, bg0.width - pw), (ri * 23) % max(1, bg0.height - ph)
            panel = bg0.crop((ox, oy, ox + pw, oy + ph)).copy()
            panel.alpha_composite(sp2, ((pw - sp2.width) // 2, (ph - sp2.height) // 2 + 6))
            sheet.paste(panel.resize((pw * 2, ph * 2), Image.NEAREST).convert('RGB'), (left + ci * (pw * 2 + 4), top + ri * (ph * 2 + 4)))
        d.text((12, top + ri * (ph * 2 + 4) + 150), STYLES[k]['name'], fill=(255, 255, 255), font=f1)
    d.text((left + 6, 8), 'uzun şerit (yol kenarı)', fill=(210, 230, 210), font=f2)
    d.text((left + pw * 2 + 10, 8), 'L şekli (duvar köşesi)', fill=(210, 230, 210), font=f2)
    return sheet


def main():
    keys = ['a', 'b', 'c', 'd']
    brushes = [Brush(k, shape_main(k), 100 + i) for i, k in enumerate(keys)]
    for br in brushes:
        br.render().save(os.path.join(OUT, f'brush_{br.key}.png'))
    compose_main(brushes).save(os.path.join(OUT, 'brush_karsilastirma.png'))
    compose_shapes(keys).save(os.path.join(OUT, 'brush_sekiller.png'))
    # yakın plan 6x (yalın çim rengi üstünde)
    ims = [b.render() for b in brushes]
    sc, pad = 6, 8
    W = sum(i.width for i in ims) * sc + pad * sc * (len(ims) + 1)
    Hh = max(i.height for i in ims) * sc + 2 * pad * sc
    big = Image.new('RGBA', (W, Hh), (126, 176, 84, 255))
    x = pad * sc
    for i in ims:
        big.alpha_composite(i.resize((i.width * sc, i.height * sc), Image.NEAREST), (x, pad * sc))
        x += i.width * sc + pad * sc
    big.convert('RGB').save(os.path.join(OUT, 'brush_yakin.png'))
    # 3. tur: A + C karışımları (K1-K3), gerçek çim üstünde karşılaştırma + şekiller + yakın plan (referans A ve C ile)
    mkeys = ['k1', 'k2', 'k3']
    mixes = [Brush(k, shape_main(k), 300 + i) for i, k in enumerate(mkeys)]
    for br in mixes:
        br.render().save(os.path.join(OUT, f'brush_{br.key}.png'))
    compose_main(mixes).save(os.path.join(OUT, 'brush_karisik_karsilastirma.png'))
    compose_shapes(mkeys).save(os.path.join(OUT, 'brush_karisik_sekiller.png'))
    ims = [b.render() for b in [brushes[0]] + mixes + [brushes[2]]]
    labels = ['A (önce)', 'K1', 'K2', 'K3', 'C (önce)']
    W = sum(i.width for i in ims) * sc + pad * sc * (len(ims) + 1)
    big = Image.new('RGBA', (W, Hh + 30), (126, 176, 84, 255))
    dd = ImageDraw.Draw(big)
    x = pad * sc
    for i, lab in zip(ims, labels):
        big.alpha_composite(i.resize((i.width * sc, i.height * sc), Image.NEAREST), (x, pad * sc))
        dd.text((x + 4, 6), lab, fill=(20, 40, 20), font=_font(28))
        x += i.width * sc + pad * sc
    big.convert('RGB').save(os.path.join(OUT, 'brush_karisik_yakin.png'))
    print('tamam')


if __name__ == '__main__':
    main()
