"""2026-10-12 prototipleri: MATTHEW REWORK - köpek gitti, şimşek geldi (kullanıcı: "birçok yeni pixel art efekt üretimi gerekiyor,
bunları yüklemeden önce bana gösterir misin"). Renk kararı: SARI-ALTIN (krem-beyaz çekirdek). OYUNA HENÜZ BAĞLI DEĞİL.
  Q  Şimşek Hücumu   - Matthew'dan hedefe çakan şimşek (6 evre) + isabet patlaması
  P  Yıldırım Hızı   - arkasında 1 sn'de incelip sönen yıldırım izi; maksimum hızda GÜÇLENMİŞ iz (kalın, çatallı)
  E  Elektrik Topu   - top formu döngüsü (normal + final evrimi %50 büyük), dönüşme/çıkma, çarpma patlaması (bilardo)
  R  Yıldırım Kalkanı - tilki kulaklı kubbenin yerine yıldırımlı halka: döngü + kırılma + patlama (yarıçap 220)
  4 yetenek ikonu (48x48, mevcut karo diliyle)
Dil (tools/pixfx.py ile aynı): içi dolu kütleler, 5 ton [kontur, koyu, orta, açık, parlak], 1 px koyu kontur, uçlar incelerek biter;
1 sanat pikseli = 1 texel (karakterin 48x48 karesiyle aynı doku yoğunluğu). Şimşekler Bresenham çizgisi + 4-komşu genişletme
(1/3/5 px) ile tam piksel ızgarasında.
Çıktı: out/matthew_{q,pasif,e,e_boyut,r,r_patlama}.gif + out/matthew_ikonlar.png + out/matthew_simsek_sheet.png
Kullanım (proje kökünden): python -I tools/proto_20261012/gen_matthew_simsek.py
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(HERE, 'out')
os.makedirs(OUT, exist_ok=True)
sys.path.insert(0, os.path.join(PROJECT, 'tools'))
from gen_elara_korsan_icons import C, canvas as icanvas, outline as ioutline, put as iput, sparkle as isparkle, tile as itile  # noqa: E402

TAU = math.tau
## Sarı-altın şimşek paleti: [kontur, koyu, orta, açık, parlak]
G = [(92, 54, 8), (204, 136, 20), (250, 208, 52), (255, 240, 140), (255, 255, 232)]
WHITE = (255, 255, 255)
GRASS = (126, 176, 84)


def font(sz):
    for c in (r'C:\Windows\Fonts\segoeui.ttf', r'C:\Windows\Fonts\arial.ttf'):
        if os.path.exists(c):
            return ImageFont.truetype(c, sz)
    return ImageFont.load_default()


# ====================================================================== ilkel katman
class Layer:
    def __init__(self, w, h):
        self.w, self.h = int(w), int(h)
        self.a = np.zeros((self.h, self.w, 4), dtype=np.uint8)

    def put(self, m, c, alpha=255):
        self.a[m] = (c[0], c[1], c[2], alpha)

    def px(self, x, y, c, alpha=255):
        x, y = int(math.floor(x)), int(math.floor(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            self.a[y, x] = (c[0], c[1], c[2], alpha)

    def filled(self):
        return self.a[:, :, 3] > 0

    def grid(self):
        yy, xx = np.mgrid[0:self.h, 0:self.w]
        return xx + 0.5, yy + 0.5

    def img(self):
        return Image.fromarray(self.a, 'RGBA')


def dilate(m):
    o = m.copy()
    o[1:, :] |= m[:-1, :]
    o[:-1, :] |= m[1:, :]
    o[:, 1:] |= m[:, :-1]
    o[:, :-1] |= m[:, 1:]
    return o


def outline(ly, m, col=None):
    ly.put(dilate(m) & ~m & ~ly.filled(), col or G[0])


def poly_mask(ly, pts):
    im = Image.new('L', (ly.w, ly.h), 0)
    ImageDraw.Draw(im).polygon([(x - 0.5, y - 0.5) for (x, y) in pts], fill=255)
    return np.array(im) > 0


def bres(pts):
    """Kırık çizginin sıralı piksel listesi (8-bağlı, tekrar yok)."""
    out = []
    for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
        x0, y0, x1, y1 = int(math.floor(ax)), int(math.floor(ay)), int(math.floor(bx)), int(math.floor(by))
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        while True:
            if not out or out[-1] != (x0, y0):
                out.append((x0, y0))
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy
    return out


def pmask(shape, pix):
    m = np.zeros(shape, dtype=bool)
    for (x, y) in pix:
        if 0 <= x < shape[1] and 0 <= y < shape[0]:
            m[y, x] = True
    return m


def zig(rng, p0, p1, step, jag):
    """p0 -> p1 arası sivri zikzak: ara noktalar sırayla sağa/sola savrulur."""
    x0, y0 = p0
    x1, y1 = p1
    ln = math.hypot(x1 - x0, y1 - y0)
    if ln < 1.0:
        return [p0, p1]
    ux, uy = (x1 - x0) / ln, (y1 - y0) / ln
    nx, ny = -uy, ux
    pts = [p0]
    d = 0.0
    sign = rng.choice((-1, 1))
    while True:
        d += step * rng.uniform(0.6, 1.4)
        if d >= ln - step * 0.5:
            break
        o = sign * jag * rng.uniform(0.45, 1.0)
        sign = -sign
        pts.append((x0 + ux * d + nx * o, y0 + uy * d + ny * o))
    pts.append(p1)
    return pts


def dash(thr, seed):
    """Parçalanma: çizgi boyunca bitişik boşluklar (thr büyüdükçe daha çok piksel düşer)."""
    def keep(i, _n):
        return 0.5 + 0.25 * math.sin(i * 0.61 + seed * 1.7) + 0.25 * math.sin(i * 0.23 + seed * 2.7 + 1.0) >= thr
    return keep


def bolt(ly, pts, w=3, taper=3, outl=True, core=None, body=None, keep=None):
    """Şimşek: w = 1/3/5 px. Uçlarda taper piksel boyunca incelir (5 -> 3 -> 1). keep(i, n): parçalanma süzgeci."""
    pix = bres(pts)
    n = len(pix)
    idx = [i for i in range(n) if keep is None or keep(i, n)]
    shape = (ly.h, ly.w)
    m1 = pmask(shape, [pix[i] for i in idx])
    m3 = np.zeros(shape, dtype=bool)
    m5 = np.zeros(shape, dtype=bool)
    if w >= 3:
        m3 = dilate(pmask(shape, [pix[i] for i in idx if taper <= i < n - taper]))
    if w >= 5:
        m5 = dilate(dilate(pmask(shape, [pix[i] for i in idx if 2 * taper <= i < n - 2 * taper])))
    allm = m1 | m3 | m5
    if outl:  ## ince (1 px) kollar koyu konturla "beyaz solucan" gibi duruyordu -> altın kenar (ana şimşeğin minyatürü)
        ly.put(dilate(allm) & ~allm & ~ly.filled(), G[0] if w >= 3 else G[1])
    if w >= 5:
        ly.put(m5, body or G[2])
        ly.put(m3, G[3])
        ly.put(m1, core or G[4])
    elif w >= 3:
        ly.put(m3, body or G[2])
        ly.put(m1, core or G[4])
    else:
        ly.put(m1, core or G[4])
    return allm


def branches(ly, rng, pts, count, lmin, lmax):
    """Ana yoldan ayrılan kısa çatallar (ana şimşekten ÖNCE çizilir, kökü altında kalır)."""
    ax = math.atan2(pts[-1][1] - pts[0][1], pts[-1][0] - pts[0][0])
    for _ in range(count):
        k = rng.randrange(1, max(2, len(pts) - 1))
        x, y = pts[k]
        a = ax + rng.choice((-1, 1)) * rng.uniform(0.45, 0.95)
        ln = rng.uniform(lmin, lmax)
        bolt(ly, zig(rng, (x, y), (x + math.cos(a) * ln, y + math.sin(a) * ln), 4, 2.0), w=1, taper=2)


def plus(ly, x, y, core=WHITE, arm=None):
    arm = arm or G[4]
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        ly.px(x + dx, y + dy, arm)
    ly.px(x, y, core)


def ring(ly, cx, cy, r, thick, k=0.0, seed=0.0, lobes=7):
    """Şok halkası; k 0..1 ilerledikçe hilallere ayrılır (parçalar incelerek biter)."""
    X, Y = ly.grid()
    d = np.hypot(X - cx, Y - cy)
    th = np.arctan2(Y - cy, X - cx)
    if k > 0.0:
        pat = np.sin(th * lobes + seed) * 0.6 + np.sin(th * 3 + seed * 2.3) * 0.4
        mult = np.clip(((1.0 - 1.9 * k) - pat) / 0.5, 0.0, 1.0)
        m = (np.abs(d - r) <= thick * mult * 0.5) & (mult > 0.05)
    else:
        m = np.abs(d - r) <= thick * 0.5
    outline(ly, m)
    ly.put(m, G[2])
    if thick >= 2.5:
        ly.put(m & (d >= r), G[3])
    return m


def star_pts(rng, cx, cy, r_out, r_in, n, rot):
    pts = []
    for k in range(n * 2):
        a = rot + TAU * k / (n * 2)
        r = r_out * rng.uniform(0.72, 1.0) if k % 2 == 0 else r_in * rng.uniform(0.85, 1.1)
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


def impact(ly, cx, cy, R, f, seed=0, with_ring=False):
    """Elektrik isabeti, 5 kare: krem disk -> sivri yıldız -> içi boşalan dikenler -> kıvılcımlar -> son pikseller."""
    rot = random.Random(seed).uniform(0, TAU)
    rs = random.Random(seed * 131 + 7)  ## yıldız biçimi karelere göre sabit
    rf = random.Random(seed * 131 + 7 + f * 17)
    X, Y = ly.grid()
    d = np.hypot(X - cx, Y - cy)
    if f == 0:
        r = R * 0.42
        m = d <= r
        outline(ly, m)
        ly.put(m, G[3])
        ly.put(d <= r - 1.2, G[4])
        for q in range(4):
            a = TAU / 8 + q * TAU / 4
            for s in range(int(r) + 1, int(r + R * 0.5) + 1):
                ly.px(cx + math.cos(a) * s, cy + math.sin(a) * s, G[4])
    elif f == 1:
        pts = star_pts(rs, cx, cy, R, R * 0.42, 7, rot)
        outer = poly_mask(ly, pts)
        inner = poly_mask(ly, [(cx + (x - cx) * 0.62, cy + (y - cy) * 0.62) for (x, y) in pts])
        outline(ly, outer)
        ly.put(outer, G[2])
        ly.put(inner, G[3])
        ly.put(d <= R * 0.26, G[4])
    elif f == 2:
        pts = star_pts(rs, cx, cy, R * 1.22, R * 0.6, 7, rot)
        m = poly_mask(ly, pts) & (d > R * 0.55)
        outline(ly, m)
        ly.put(m, G[2])
        ly.put(m & (d > R * 0.9), G[3])
        for q in range(3):
            a = rot + 0.5 + q * TAU / 3
            p0 = (cx + math.cos(a) * R * 0.5, cy + math.sin(a) * R * 0.5)
            p1 = (cx + math.cos(a) * R * 1.45, cy + math.sin(a) * R * 1.45)
            bolt(ly, zig(rf, p0, p1, 4, 2.0), w=1, taper=2)
        if with_ring:
            ring(ly, cx, cy, R * 1.5, 2.6, k=0.25, seed=seed)
    elif f == 3:
        for q in range(7):
            a = rot + q * TAU / 7 + rf.uniform(-0.2, 0.2)
            r = R * rf.uniform(1.05, 1.5)
            x, y = cx + math.cos(a) * r, cy + math.sin(a) * r
            if q % 2 == 0:
                plus(ly, x, y, G[4], G[2])
            else:
                ly.px(x, y, G[3])
                ly.px(x + 1, y, G[2])
        if with_ring:
            ring(ly, cx, cy, R * 1.8, 2.0, k=0.6, seed=seed)
    else:
        for q in range(4):
            a = rot + q * TAU / 4 + rf.uniform(-0.3, 0.3)
            r = R * rf.uniform(1.3, 1.7)
            ly.px(cx + math.cos(a) * r, cy + math.sin(a) * r, G[2] if q % 2 else G[1])


# ====================================================================== sahne yardımcıları
_BG = None
BGW = 480


def grass(w, h, off=0):
    global _BG
    if _BG is None:
        img = Image.new('RGBA', (BGW, 400), GRASS + (255,))
        rng = random.Random(4)
        px = img.load()
        for _ in range(BGW * 400 // 14):
            px[rng.randrange(BGW), rng.randrange(400)] = rng.choice([(116, 166, 76), (134, 184, 92), (110, 158, 72)]) + (255,)
        _BG = img
    off %= BGW
    out = Image.new('RGBA', (w, h))
    out.paste(_BG.crop((off, 0, min(BGW, off + w), h)), (0, 0))
    if off + w > BGW:
        out.paste(_BG.crop((0, 0, off + w - BGW, h)), (BGW - off, 0))
    return out


def comp(dst, src, x=0, y=0):
    if isinstance(src, Layer):
        src = src.img()
    x, y = int(round(x)), int(round(y))
    sx0, sy0 = max(0, -x), max(0, -y)
    sx1, sy1 = min(src.width, dst.width - x), min(src.height, dst.height - y)
    if sx1 <= sx0 or sy1 <= sy0:
        return
    dst.alpha_composite(src.crop((sx0, sy0, sx1, sy1)), (x + sx0, y + sy0))


def _sheet(name):
    return Image.open(os.path.join(PROJECT, 'assets', 'characters', 'matthew', 'sheets', name + '.png')).convert('RGBA')


IDLE = _sheet('idle')  ## 4 sütun; satırlar: aşağı, sol, sağ, yukarı
RUN = _sheet('run')  ## 6 sütun


def char(sh, col, row=2):
    return sh.crop((col * 48, row * 48, col * 48 + 48, row * 48 + 48))


def ground_shadow(dst, cx, feet, rx=9, ry=3):
    sh = Layer(dst.width, dst.height)
    X, Y = sh.grid()
    sh.put(((X - cx) / rx) ** 2 + ((Y - feet + 1) / ry) ** 2 <= 1.0, (40, 60, 30), 90)
    comp(dst, sh)


def put_char(dst, fr, cx, feet):
    ground_shadow(dst, cx, feet)
    comp(dst, fr, cx - 24, feet - 40)


def silhouette(fr):
    """Dönüşüm parlaması: karakterin krem silueti + sarı kontur."""
    ly = Layer(48, 48)
    m = np.array(fr)[:, :, 3] > 0
    ly.put(dilate(m) & ~m, G[2])
    ly.put(m, G[4])
    return ly


def slime(flash=False, squash=0.0):
    """Temsili yaratık (oyundaki sprite DEĞİL - sadece ölçek ve isabet için)."""
    ly = Layer(28, 24)
    cx, base = 14.0, 20.0
    X, Y = ly.grid()
    rx, ry = 9.0 + 2.0 * squash, 7.5 - 2.0 * squash
    m = (((X - cx) / rx) ** 2 + ((Y - (base - ry * 0.8)) / ry) ** 2 <= 1.0) & (Y <= base)
    ly.put(dilate(m) & ~m, (30, 20, 54))
    ly.put(m, (60, 44, 104))
    ly.put(m & (((X - cx + 1) / (rx - 1.5)) ** 2 + ((Y - (base - ry * 0.95)) / (ry - 1.5)) ** 2 <= 1.0), (96, 72, 150))
    ly.put(m & (((X - cx + 3) / (rx * 0.4)) ** 2 + ((Y - (base - ry * 1.25)) / (ry * 0.3)) ** 2 <= 1.0), (140, 112, 196))
    for ex in (-3, 3):
        ly.px(cx + ex, base - ry * 0.75, (20, 12, 36))
        ly.px(cx + ex, base - ry * 0.75 + 1, (20, 12, 36))
    if flash:
        ly.put(m, G[4])
    return ly


def put_slime(dst, x, feet, flash=False, squash=0.0):
    ground_shadow(dst, x, feet, 8, 2.5)
    comp(dst, slime(flash, squash), x - 14, feet - 20)


def save_gif(name, frames, scale, ms, labels=None):
    f = font(15)
    big = []
    for fr in frames:
        im = fr.convert('RGB').resize((fr.width * scale, fr.height * scale), Image.NEAREST)
        if labels:
            d = ImageDraw.Draw(im)
            for (x, y, text) in labels:
                d.text((x + 1, y + 1), text, fill=(20, 30, 14), font=f)
                d.text((x, y), text, fill=(250, 246, 226), font=f)
        big.append(im.quantize(colors=200, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE))
    big[0].save(os.path.join(OUT, name), save_all=True, append_images=big[1:], duration=ms, loop=0, disposal=1)


# ====================================================================== Q - Şimşek Hücumu
def q_strike(w, h, p0, p1, s, seed):
    """Tek çakış, 6 evre: öncü çizgi -> kalın+çatallı -> titrek -> kopuk -> kesik çizgiler -> kıvılcım."""
    ly = Layer(w, h)
    rng = random.Random(seed * 97 + s * 13)
    pts = zig(random.Random(seed * 97 + min(s, 2) * 13), p0, p1, 11, 6.5)  ## evre 2'den sonra biçim sabit, sadece söner
    if s == 0:
        bolt(ly, pts, w=1, outl=False, core=G[3])
    elif s == 1:
        branches(ly, rng, pts, 2, 10, 20)
        bolt(ly, pts, w=5, taper=3)
    elif s == 2:
        branches(ly, rng, pts, 1, 8, 14)
        bolt(ly, pts, w=3, taper=4)
    elif s == 3:
        bolt(ly, pts, w=3, taper=5, core=G[3], keep=dash(0.2, seed))
    elif s == 4:
        bolt(ly, pts, w=1, outl=False, core=G[3], keep=dash(0.52, seed))
    else:
        bolt(ly, pts, w=1, outl=False, core=G[2], keep=dash(0.8, seed))
    if s <= 1:  ## elde atış parlaması
        plus(ly, p0[0], p0[1], WHITE, G[4])
        if s == 1:
            for dx, dy in ((2, 0), (-2, 0), (0, 2), (0, -2), (1, 1), (-1, 1), (1, -1), (-1, -1)):
                ly.px(p0[0] + dx, p0[1] + dy, G[3])
    return ly


def scene_q():
    W, H = 250, 132
    mx, mfeet = 44, 84
    src = (mx + 6, mfeet - 19)
    targets = [(150, 40), (214, 78), (160, 120)]
    starts = [5, 9, 13]
    frames = []
    for f in range(30):
        img = grass(W, H)
        for k, (tx, ty) in enumerate(targets):
            s = f - starts[k]
            put_slime(img, tx, ty, flash=s in (1, 2), squash=0.6 if s in (1, 2, 3) else 0.0)
        put_char(img, char(IDLE, (f // 4) % 4), mx, mfeet)
        for k, (tx, ty) in enumerate(targets):
            s = f - starts[k]
            if 0 <= s <= 5:
                comp(img, q_strike(W, H, src, (tx, ty - 8), s, k + 1))
            if 1 <= s <= 5:
                ly = Layer(W, H)
                impact(ly, tx, ty - 8, 13, s - 1, seed=k + 1)
                comp(img, ly)
        frames.append(img)
    return frames


# ====================================================================== Pasif - Yıldırım Hızı izi
TW, TH = 16, 32  ## iz karosu: 16 px ilerleme başına bir damga; çizgi karonun orta satırından girer/çıkar (dikişsiz)
TRAIL_STAGES = 8  ## 1 sn = 8 evre


def trail_tile(j, stage, strong):
    ly = Layer(TW, TH)
    cy = TH // 2
    v = j % 3
    rs = random.Random(300 + v * 19)
    jag = 3.6 if strong else 2.7
    pts = [(0, cy)]
    sign = 1 if v % 2 == 0 else -1
    for x in (5, 11):
        pts.append((x + rs.uniform(-1, 1), cy + sign * jag * rs.uniform(0.6, 1.0)))
        sign = -sign
    pts.append((TW, cy))
    fr = random.Random(7000 + j * 53 + stage * 11)  ## çatal/kıvılcım titremesi

    def sparks(n, dy, col):
        for _ in range(n):
            ly.px(fr.randrange(1, TW - 1), cy + dy + fr.randrange(-3, 3), col)

    def forks(n, lmin, lmax):
        for _ in range(n):
            x, y = pts[fr.choice((1, 2))]
            up = -1 if y < cy else 1
            a = up * (math.pi / 2) + fr.uniform(-0.5, 0.5)
            ln = fr.uniform(lmin, lmax)
            bolt(ly, zig(fr, (x, y), (x + math.cos(a) * ln, y + math.sin(a) * ln), 3, 1.6), w=1, taper=2)

    if not strong:
        if stage <= 1:
            bolt(ly, pts, w=3, taper=0)
        elif stage == 2:
            bolt(ly, pts, w=3, taper=0, core=G[3])
        elif stage == 3:
            bolt(ly, pts, w=1, core=G[3], keep=dash(0.22, j))
        elif stage == 4:
            bolt(ly, pts, w=1, core=G[3], keep=dash(0.45, j))
        elif stage == 5:
            bolt(ly, pts, w=1, outl=False, core=G[2], keep=dash(0.62, j))
        elif stage == 6:
            sparks(3, -1, G[2])
        else:
            sparks(1, -2, G[1])
    else:
        if stage <= 1:
            forks(2, 7, 11)
            bolt(ly, pts, w=5, taper=0)
            for (x, y) in pts[1:3]:
                plus(ly, x, y)
        elif stage == 2:
            forks(1, 6, 10)
            bolt(ly, pts, w=5, taper=0)
        elif stage == 3:
            forks(1, 4, 7)
            bolt(ly, pts, w=3, taper=0)
        elif stage == 4:
            bolt(ly, pts, w=3, taper=0, core=G[3])
        elif stage == 5:
            bolt(ly, pts, w=1, core=G[3], keep=dash(0.25, j))
        elif stage == 6:
            bolt(ly, pts, w=1, outl=False, core=G[2], keep=dash(0.55, j))
            sparks(2, -2, G[3])
        else:
            sparks(2, -3, G[2])
    return ly


def scene_pasif():
    W, RH = 300, 84
    V = 10  ## px/kare, 20 fps -> 200 texel/sn (taban hız 252 dünya birimi = 208 texel)
    cxs, feet = 236, 60
    line_y = feet - 9
    frames = []
    for f in range(48):
        cam = f * V
        img = Image.new('RGBA', (W, RH * 2))
        for row, strong in enumerate((False, True)):
            sub = grass(W, RH, cam)
            head = cam + cxs - 5  ## izin taze ucu (gövdenin hemen arkası)
            j = head // TW
            while True:
                age = (head - j * TW) / (V * 20.0)
                if age >= 1.0:
                    break
                comp(sub, trail_tile(j, int(age * TRAIL_STAGES), strong), j * TW - TW - cam, line_y - TH // 2)
                j -= 1
            put_char(sub, char(RUN, (f * 6 // 8) % 6), cxs, feet)
            img.paste(sub, (0, row * RH))
        frames.append(img)
    return frames


# ====================================================================== E - Elektrik Topu
BALL_R = 13.0
BALL_R_BIG = 19.5  ## final evrimi: %50 büyük (ayrı sayfa - germe yok)


def ball(i, R, n=8, pad=12):
    size = int(2 * R + 2 * pad)
    ly = Layer(size, size)
    c = size / 2.0
    X, Y = ly.grid()
    dx, dy = X - c, Y - c
    d = np.hypot(dx, dy)
    th = np.arctan2(dy, dx)
    ph = TAU * i / n
    rr = R * (1.0 + 0.018 * np.sin(3 * th + ph) + 0.012 * np.sin(5 * th - 2 * ph))
    m = d <= rr
    q = d / rr
    chk = ((np.floor(X) + np.floor(Y)) % 2) == 0
    ly.put(m, G[1])
    ly.put(m & (q < 0.9), G[2])
    ly.put(m & (q >= 0.68) & (q < 0.76) & chk, G[3])
    ly.put(m & (q < 0.68), G[3])
    ly.put(m & (q >= 0.42) & (q < 0.5) & chk, G[4])
    ly.put(m & (q < 0.42), G[4])
    ly.put(m & (q < 0.2), WHITE)
    rng = random.Random(77 + i * 13)
    ## çekirdekten kabuğa uzanan beyaz damarlar (döngü boyunca 120 derece döner -> dikişsiz)
    for k in range(3):
        a = k * TAU / 3 + ph / 3 + rng.uniform(-0.2, 0.2)
        p0 = (c + math.cos(a) * R * 0.34, c + math.sin(a) * R * 0.34)
        p1 = (c + math.cos(a + rng.uniform(-0.3, 0.3)) * R * 0.97, c + math.sin(a + rng.uniform(-0.3, 0.3)) * R * 0.97)
        vm = pmask((ly.h, ly.w), bres(zig(rng, p0, p1, 3.5, 1.7))) & m
        ly.put(vm, WHITE)
    ly.put(dilate(m) & ~m, G[0])
    ## topun çevresinde dönen iki zikzak ark (döngüde yarım tur -> dikişsiz)
    for k in range(2):
        a0 = k * math.pi + ph / 2
        span = 1.25
        m_ = 6
        sign = rng.choice((-1, 1))
        opts = []
        for q_ in range(m_ + 1):
            aa = a0 + span * (q_ / m_ - 0.5)
            off = 0.0 if q_ in (0, m_) else sign * rng.uniform(0.6, 1.8)
            sign = -sign
            opts.append((c + math.cos(aa) * (R + 4.0 + off), c + math.sin(aa) * (R + 4.0 + off)))
        bolt(ly, opts, w=1, taper=2)
    ## kabuktan dışarı sıçrayan kısa ark + kıvılcımlar
    for _ in range(1):
        a = rng.uniform(0, TAU)
        ln = rng.uniform(5, 9) * (R / BALL_R) ** 0.5
        p0 = (c + math.cos(a) * (R + 0.5), c + math.sin(a) * (R + 0.5))
        p1 = (c + math.cos(a + rng.uniform(-0.4, 0.4)) * (R + ln), c + math.sin(a + rng.uniform(-0.4, 0.4)) * (R + ln))
        bolt(ly, zig(rng, p0, p1, 3, 1.6), w=1, taper=2)
    for _ in range(3):
        a = rng.uniform(0, TAU)
        r = R + rng.uniform(3, pad - 2)
        ly.px(c + math.cos(a) * r, c + math.sin(a) * r, G[3] if rng.random() < 0.5 else G[4])
    return ly


def burst_form(R, seed):
    """Dönüşme/çıkma ara karesi: krem disk + dışa çakan 6 kısa şimşek."""
    size = int(2 * R + 40)
    ly = Layer(size, size)
    c = size / 2.0
    rng = random.Random(seed)
    X, Y = ly.grid()
    d = np.hypot(X - c, Y - c)
    for q in range(6):
        a = q * TAU / 6 + rng.uniform(-0.25, 0.25)
        p0 = (c + math.cos(a) * R * 0.5, c + math.sin(a) * R * 0.5)
        p1 = (c + math.cos(a) * (R + 14), c + math.sin(a) * (R + 14))
        bolt(ly, zig(rng, p0, p1, 4, 2.2), w=3 if q % 2 == 0 else 1, taper=3)
    m = d <= R * 0.8
    ly.put(dilate(m) & ~m, G[0])
    ly.put(m, G[3])
    ly.put(d <= R * 0.8 - 1.5, G[4])
    return ly


def put_ball(dst, i, x, cy, R):
    ly = ball(i, R)
    comp(dst, ly, x - ly.w / 2, cy - ly.h / 2)


def scene_e():
    W, H = 290, 112
    feet = 80
    mx0 = 40
    A0, B0 = 152, 214  ## yaratıkların başlangıç x'i
    a_path = [0, 14, 26, 36, 44]  ## A'nın fırlama ötelemeleri (son adımda B'ye çarpar)
    T_FLASH, T_BURST, T_BALL = 5, 6, 7
    T_HIT1 = 25
    T_HIT2 = T_HIT1 + len(a_path) - 1
    T_OUT = 34
    frames = []
    bx_end = mx0
    for f in range(46):
        img = grass(W, H)
        ## yaratıklar
        sa = f - T_HIT1
        ax = A0 + (a_path[min(sa, len(a_path) - 1)] if sa >= 0 else 0)
        sb = f - T_HIT2
        bx_ = B0 + (min(sb, 3) * 4 if sb >= 0 else 0)
        put_slime(img, ax, feet, flash=sa in (0, 1) or sb in (0, 1), squash=0.7 if sa in (0, 1, 2) else 0.0)
        put_slime(img, bx_, feet + 2, flash=sb in (0, 1), squash=0.7 if sb in (0, 1, 2) else 0.0)
        ## Matthew / top
        if f < T_FLASH:
            put_char(img, char(IDLE, (f // 4) % 4), mx0, feet)
        elif f == T_FLASH:
            ground_shadow(img, mx0, feet)
            comp(img, silhouette(char(IDLE, 1)), mx0 - 24, feet - 40)
        elif f == T_BURST:
            ground_shadow(img, mx0, feet)
            ly = burst_form(BALL_R, 5)
            comp(img, ly, mx0 - ly.w / 2, feet - 17 - ly.h / 2)
        elif f < T_OUT:
            bx = mx0 + (f - T_BALL) * 5 if f < T_HIT1 else mx0 + (T_HIT1 - T_BALL) * 5 + (f - T_HIT1) * 3
            bx_end = bx
            ground_shadow(img, bx, feet, 10, 3)
            put_ball(img, f % 8, bx, feet - 17 + (1 if f % 8 in (2, 3, 4) else 0), BALL_R)
        elif f == T_OUT:
            ground_shadow(img, bx_end, feet)
            ly = burst_form(BALL_R, 9)
            comp(img, ly, bx_end - ly.w / 2, feet - 17 - ly.h / 2)
        elif f == T_OUT + 1:
            ground_shadow(img, bx_end, feet)
            comp(img, silhouette(char(IDLE, 0)), bx_end - 24, feet - 40)
        else:
            put_char(img, char(IDLE, (f // 4) % 4), bx_end, feet)
        ## çarpma patlamaları
        if 0 <= sa <= 4:
            ly = Layer(W, H)
            impact(ly, A0 - 7, feet - 12, 13, sa, seed=11, with_ring=True)
            comp(img, ly)
        if 0 <= sb <= 4:
            ly = Layer(W, H)
            impact(ly, B0 - 9, feet - 9, 13, sb, seed=12, with_ring=True)
            comp(img, ly)
        frames.append(img)
    return frames


def scene_e_size():
    W, H = 210, 96
    feet = 70
    frames = []
    for f in range(16):
        img = grass(W, H)
        put_char(img, char(IDLE, (f // 4) % 4, 0), 34, feet)
        ground_shadow(img, 98, feet, 10, 3)
        put_ball(img, f % 8, 98, feet - 17, BALL_R)
        ground_shadow(img, 164, feet + 2, 14, 4)
        put_ball(img, f % 8, 164, feet - 22, BALL_R_BIG)
        frames.append(img)
    return frames


# ====================================================================== R - Yıldırım Kalkanı
## Kullanıcı (2026-10-12, ilk prototip yarıçap 50 = eski Feda Kalkanı ölçüsü): "kalkan efekti çok büyük, Matthew ufacık kalıyor"
## -> gövdeyi saran dar halka. Karakter gövdesi ~14 x 32 px; 26 px yarıçap üstte/altta ~8 px pay bırakır.
DOME_R = 26.0  ## kullanıcı seçimi (26 / 30 / 36 karşılaştırmasından)


def shield_loop(i, n=24, size=128):
    ly = Layer(size, size)
    c = size / 2.0
    R = DOME_R
    X, Y = ly.grid()
    dx, dy = X - c, Y - c
    d = np.hypot(dx, dy)
    ## 3 px halka: içten dışa açık / orta / koyu + dış kontur; ışık sol üstten (iç kenar sağ altta koyu, sol üstte krem)
    ly.put((d >= R + 1.5) & (d < R + 2.5), G[0])
    ly.put((d >= R + 0.5) & (d < R + 1.5), G[1])
    ly.put((d >= R - 0.5) & (d < R + 0.5), G[2])
    inner = (d >= R - 1.5) & (d < R - 0.5)
    ly.put(inner, G[3])
    ly.put(inner & (dx + dy < -0.55 * R), G[4])
    ly.put((d >= R - 2.5) & (d < R - 1.5) & (dx + dy > 0.35 * R), G[0])
    ## sol üstte noktalı parıltı yayı (mevcut kubbenin dili)
    for q in range(10):
        a = math.radians(196 + q * 5.5)
        if q % 2 == 0:
            ly.px(c + math.cos(a) * (R - (5 if R < 40 else 8)), c + math.sin(a) * (R - (5 if R < 40 else 8)), G[4], 200)
    nodes = 3 if R < 40 else 4  ## küçük halkada 4 düğüm bütün çemberi zikzağa boğuyordu
    small = R < 40
    rot = (TAU / nodes) * i / n
    for k in range(nodes):
        a = rot + k * TAU / nodes
        rng = random.Random(1000 + k * 37 + (i // 2) * 101)  ## 2 karede bir titrer
        ## halka boyunca sürünen ark: düğümde kalın, iki uca doğru incelir (yay UZUNLUĞU sabit ~13-20 px, açı yarıçapa göre)
        span = rng.uniform(13.0, 20.0) / R
        m = 5
        pts = []
        sign = rng.choice((-1, 1))
        for q in range(-m, m + 1):
            aa = a + span * q / m
            off = 0.0 if q == 0 else sign * rng.uniform(1.2, 3.4) * (1.0 - 0.35 * abs(q) / m)
            sign = -sign
            pts.append((c + math.cos(aa) * (R + off), c + math.sin(aa) * (R + off)))
        ## içe ve dışa çatal
        fa = a + rng.uniform(-0.18, 0.18)
        fl = rng.uniform(5, 9) if small else rng.uniform(8, 14)  ## küçük halkada içe çatal şapkaya değmesin
        bolt(ly, zig(rng, (c + math.cos(a) * (R - 2), c + math.sin(a) * (R - 2)), (c + math.cos(fa) * (R - fl), c + math.sin(fa) * (R - fl)), 4, 2.2), w=1, taper=2)
        fa = a + rng.uniform(-0.25, 0.25)
        fl = rng.uniform(4, 7) if small else rng.uniform(5, 9)
        bolt(ly, zig(rng, (c + math.cos(a) * (R + 2), c + math.sin(a) * (R + 2)), (c + math.cos(fa) * (R + fl), c + math.sin(fa) * (R + fl)), 3, 1.6), w=1, taper=2)
        bolt(ly, pts, w=3, taper=5)
        nx, ny = c + math.cos(a) * R, c + math.sin(a) * R
        plus(ly, nx, ny)
        for ddx, ddy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
            ly.px(nx + ddx, ny + ddy, G[3])
    return ly


def shield_pop(f, n=8, size=190):
    ly = Layer(size, size)
    c = size / 2.0
    R = DOME_R
    X, Y = ly.grid()
    d = np.hypot(X - c, Y - c)
    th = np.arctan2(Y - c, X - c)
    if f == 0:
        m = np.abs(d - R) <= 2.5
        outline(ly, m)
        ly.put(m, G[3])
        ly.put(np.abs(d - R) <= 1.5, G[4])
        return ly
    k = (f - 1) / (n - 2)
    rr = R + 4 + 20 * (1.0 - (1.0 - k) ** 2)
    thick = 5.0 * (1.0 - k) + 1.2
    pat = np.sin(th * 8 + 1.3) * 0.6 + np.sin(th * 3 + 0.4) * 0.4
    mult = np.clip(((0.95 - 1.75 * k) - pat) / 0.5, 0.0, 1.0)
    m = (np.abs(d - rr) <= thick * mult * 0.5) & (mult > 0.05)
    outline(ly, m)
    ly.put(m, G[2])
    ly.put(m & (d >= rr), G[3])
    if k < 0.3:
        ly.put(m & (np.abs(d - rr) <= 0.8), G[4])
    rng = random.Random(40 + f * 7)
    if k < 0.75:
        for q in range(8):
            a = q * TAU / 8 + 0.2 + rng.uniform(-0.12, 0.12)
            ln = 10 + 16 * k + rng.uniform(0, 6)
            p0 = (c + math.cos(a) * (rr + 2), c + math.sin(a) * (rr + 2))
            p1 = (c + math.cos(a) * (rr + ln), c + math.sin(a) * (rr + ln))
            if k < 0.35:
                bolt(ly, zig(rng, p0, p1, 4, 2.4), w=3, taper=3)
            else:
                bolt(ly, zig(rng, p0, p1, 4, 2.4), w=1, taper=2, keep=dash(0.3, q))
    if k > 0.4:
        for q in range(10):
            a = rng.uniform(0, TAU)
            r = rr + rng.uniform(-6, 12)
            ly.px(c + math.cos(a) * r, c + math.sin(a) * r, G[3] if q % 2 else G[2])
    return ly


EXP_SIZE = 380
EXP_R = 178.0  ## 220 dünya birimi / 1.212


def shield_explosion(f, n=10):
    ly = Layer(EXP_SIZE, EXP_SIZE)
    c = EXP_SIZE / 2.0
    X, Y = ly.grid()
    d = np.hypot(X - c, Y - c)
    if f == 0:
        m = d <= 24
        outline(ly, m)
        ly.put(m, G[3])
        ly.put(d <= 21, G[4])
        ly.put(d <= 12, WHITE)
        for q in range(8):
            a = q * TAU / 8 + 0.2
            for s in range(25, 46):
                ly.px(c + math.cos(a) * s, c + math.sin(a) * s, G[4] if s < 38 else G[3])
        return ly
    k = (f - 1) / (n - 2)
    front = EXP_R * (1.0 - (1.0 - min(1.0, k * 1.35)) ** 2)
    inner = front * max(0.0, min(0.92, (k - 0.2) / 0.6))
    ## şok dalgası: düz çember + ışınlar "araba tekerleği" gibi duruyordu -> çember boyunca zikzak ARK PARÇALARI (uçları incelir,
    ## ilerledikçe kısalıp kopar); ışınların boyu ve başlangıcı düzensiz, dalgaya değmeden biter.
    NA = 7
    for q in range(NA):
        rng = random.Random(500 + q * 17 + f * 5)
        a0 = TAU * q / NA + 0.12 * math.sin(q * 2.1)
        span = (TAU / NA) * (0.84 - 0.5 * k)
        steps = max(4, int(front * span / 9))
        sign = rng.choice((-1, 1))
        apts = []
        for s_ in range(steps + 1):
            aa = a0 + span * (s_ / steps - 0.5)
            off = 0.0 if s_ in (0, steps) else sign * rng.uniform(1.5, 4.5)
            sign = -sign
            apts.append((c + math.cos(aa) * (front + off), c + math.sin(aa) * (front + off)))
        if k < 0.35:
            bolt(ly, apts, w=5, taper=4)
        elif k < 0.7:
            bolt(ly, apts, w=3, taper=5)
        else:
            bolt(ly, apts, w=1, taper=2, keep=dash(0.3 + (k - 0.7), q))
    for b in range(8):
        rng = random.Random(900 + b * 31 + f * 7)
        rb = random.Random(900 + b)
        a = TAU * b / 8 + 0.2 + rb.uniform(-0.22, 0.22)
        r0 = max(inner, 9.0) * rb.uniform(1.0, 1.5)
        r1 = front * rb.uniform(0.66, 0.92)
        if r1 - r0 < 10:
            continue
        pts = zig(rng, (c + math.cos(a) * r0, c + math.sin(a) * r0), (c + math.cos(a) * r1, c + math.sin(a) * r1), 14, 8.0)
        if k < 0.3:
            branches(ly, rng, pts, 2, 12, 24)
            bolt(ly, pts, w=5, taper=4)
        elif k < 0.6:
            branches(ly, rng, pts, 1, 10, 18)
            bolt(ly, pts, w=3, taper=5)
        elif k < 0.85:
            bolt(ly, pts, w=3, taper=5, core=G[3], keep=dash(0.3, b))
        else:
            bolt(ly, pts, w=1, outl=False, core=G[3], keep=dash(0.6, b))
    if k < 0.35:
        r = 20.0 * (1.0 - k * 2.2)
        m = d <= r
        ly.put(dilate(m) & ~m, G[0])
        ly.put(m, G[3])
        ly.put(d <= r - 1.5, G[4])
    return ly


GLOW_RGB = (255, 222, 80)


def glow_char(fr, level, pulse):
    """Kullanıcı isteği: kalkan aktifken Matthew SARI parıldasın, parıltı KALKAN KIRILMAYA YAKLAŞTIKÇA artsın.
    level 0..1 = 1 - kalan kapasite / toplam kapasite. Gövde sarıyla AYDINLANIR (screen karışımı - boyama gövdeyi çamur
    kahvesine çeviriyordu; koyu çizgiler biraz daha az aydınlanır ki yüz kaybolmasın) + dış kontur koyu altından kreme açılır;
    %70'ten sonra ikinci, yanıp sönen dış halka. Oyunda sprite shader'ında aynı formül (tek uniform: level)."""
    if level <= 0.02:
        return fr
    a = np.array(fr).copy()
    m = a[:, :, 3] > 0
    rgb = a[:, :, :3].astype(np.float32) / 255.0
    luma = rgb[:, :, 0] * 0.3 + rgb[:, :, 1] * 0.59 + rgb[:, :, 2] * 0.11
    t = level * (0.5 + 0.28 * pulse) * (0.55 + 0.45 * luma)
    for q in range(3):
        g = GLOW_RGB[q] / 255.0
        ch = 1.0 - (1.0 - rgb[:, :, q]) * (1.0 - g * t)
        a[:, :, q] = np.where(m, ch * 255.0, a[:, :, q]).astype(np.uint8)
    d1 = dilate(m)
    if level > 0.12:
        col = G[1 + min(3, int(level * 3.2 + 0.5 * pulse))]
        a[d1 & ~m] = (col[0], col[1], col[2], 255)
    if level > 0.7 and pulse > 0.45:
        col = G[2] if level < 0.9 else G[3]
        a[dilate(d1) & ~d1] = (col[0], col[1], col[2], 255)
    return Image.fromarray(a, 'RGBA')


def _pulse(frames_elapsed, level):
    """Nabız kırılmaya yaklaştıkça hızlanır (12 fps'te periyot 12 -> 3 kare)."""
    return 0.5 + 0.5 * math.sin(frames_elapsed * TAU / (12.0 - 9.0 * level))


def scene_r_glow():
    """Parıltı kademeleri yan yana: kalkan dolu -> kırılmak üzere."""
    PW, H = 84, 96
    levels = (0.0, 0.35, 0.7, 0.97)
    frames = []
    for f in range(24):
        img = Image.new('RGBA', (PW * 4, H))
        for k, lv in enumerate(levels):
            sub = grass(PW, H, k * 90)
            put_char(sub, glow_char(char(IDLE, (f // 3) % 4, 0), lv, _pulse(f, lv)), PW // 2, H // 2 + 18)
            ly = shield_loop(f)
            comp(sub, ly, PW // 2 - ly.w / 2, H // 2 - ly.h / 2)
            img.paste(sub, (k * PW, 0))
        frames.append(img)
    return frames


def scene_r():
    W, H = 130, 150
    mx, feet = 65, 96
    cy = feet - 18
    T_CAST, T_LOOP, LOOPS = 3, 6, 2
    T_POP = T_LOOP + 24 * LOOPS
    frames = []
    for f in range(T_POP + 8 + 8):
        img = grass(W, H)
        fr = char(IDLE, (f // 3) % 4, 0)
        if T_LOOP <= f < T_POP:  ## kalkan hasar aldıkça (burada: zamanla) parıltı artar, kırılınca söner
            lv = (f - T_LOOP) / float(T_POP - T_LOOP - 1)
            fr = glow_char(fr, lv, _pulse(f - T_LOOP, lv))
        put_char(img, fr, mx, feet)
        if T_CAST <= f < T_CAST + 4:  ## gökten inen çağırma şimşeği
            s = f - T_CAST
            ly = Layer(W, H)
            rng = random.Random(60 + min(s, 2))
            pts = zig(rng, (mx + 22, -4), (mx, feet - 36), 11, 6.0)
            if s == 0:
                bolt(ly, pts, w=1, outl=False, core=G[3])
            elif s == 1:
                branches(ly, rng, pts, 2, 8, 16)
                bolt(ly, pts, w=5, taper=2)
            elif s == 2:
                bolt(ly, pts, w=3, taper=3)
            else:
                bolt(ly, pts, w=1, outl=False, core=G[3], keep=dash(0.5, 3))
            comp(img, ly)
            if s >= 1:
                li = Layer(W, H)
                impact(li, mx, feet - 34, 11, s - 1, seed=21)
                comp(img, li)
        if f == T_LOOP - 1:
            ly = shield_pop(0)
            comp(img, ly, mx - ly.w / 2, cy - ly.h / 2)
        elif T_LOOP <= f < T_POP:
            ly = shield_loop((f - T_LOOP) % 24)
            comp(img, ly, mx - ly.w / 2, cy - ly.h / 2)
        elif T_POP <= f < T_POP + 8:
            ly = shield_pop(f - T_POP)
            comp(img, ly, mx - ly.w / 2, cy - ly.h / 2)
        frames.append(img)
    return frames


def r_sizes_image():
    """Kalkan boyutu karşılaştırması (durağan): 26 / 30 / 36 ve ilk prototipin 50'si."""
    global DOME_R
    keep = DOME_R
    sizes = [(26.0, 'yarıçap 26 (dar)'), (30.0, 'yarıçap 30 (GIF)'), (36.0, 'yarıçap 36 (geniş)'), (50.0, 'yarıçap 50 (ilk prototip)')]
    k = 4
    W, H = 128, 132
    out = Image.new('RGB', (len(sizes) * (W * k + 8) + 8, H * k + 44), (24, 24, 28))
    d = ImageDraw.Draw(out)
    f = font(18)
    for i, (r, title) in enumerate(sizes):
        DOME_R = r
        img = grass(W, H)
        put_char(img, char(IDLE, 0, 0), W // 2, H // 2 + 18)
        ly = shield_loop(2)
        comp(img, ly, W // 2 - ly.w / 2, H // 2 - ly.h / 2)
        x = 8 + i * (W * k + 8)
        out.paste(img.convert('RGB').resize((W * k, H * k), Image.NEAREST), (x, 36))
        d.text((x + 4, 8), title, fill=(240, 236, 220), font=f)
    DOME_R = keep
    out.save(os.path.join(OUT, 'matthew_r_boyut.png'))
    return out


def scene_r_explosion():
    W = H = EXP_SIZE
    mx, feet = W // 2, H // 2 + 18
    frames = []
    for f in range(20):
        img = grass(W, H)
        for (sx, sy) in ((70, 120), (300, 90), (250, 300), (110, 290), (330, 220)):
            s = f - 4
            put_slime(img, sx, sy, flash=s in (3, 4, 5))
        put_char(img, char(IDLE, (f // 3) % 4, 0), mx, feet)
        if f < 3:
            ly = shield_loop(f)
            comp(img, ly, mx - ly.w / 2, feet - 18 - ly.h / 2)
        elif f == 3:
            ly = shield_pop(0)
            comp(img, ly, mx - ly.w / 2, feet - 18 - ly.h / 2)
        elif f < 14:
            comp(img, shield_explosion(f - 4), 0, 18 - 18)
        frames.append(img)
    return frames


# ====================================================================== ikonlar (48x48, mevcut karo dili)
GOLD = (C('#fff1a8'), C('#f2c440'), C('#c88a1c'), C('#7e4c0c'))
ICREAM = C('#fffbe0')


def _finish(base, emblem, fxl):
    base.alpha_composite(ioutline(emblem))
    if fxl is not None:
        base.alpha_composite(fxl)
    return base


def _glyph(d, pts, hi_edges, lo_edges):
    L_, A, M, _D = GOLD
    d.polygon(pts, fill=A)
    for (a, b) in lo_edges:
        d.line((pts[a], pts[b]), fill=M)
    for (a, b) in hi_edges:
        d.line((pts[a], pts[b]), fill=L_)


def _zigline(layer, pts, col):
    for (x, y) in bres(pts):
        iput(layer, [(x, y)], col)


def _streak(layer, x0, x1, y, hi, lo):
    n = max(1, x1 - x0)
    for i in range(n + 1):
        t = i / n
        c = tuple(int(round(lo[q] + (hi[q] - lo[q]) * t)) for q in range(3)) + (int(90 + 165 * t),)
        iput(layer, [(x0 + i, y)], c)


def icon_q():
    im = itile(C('#b8463a'), C('#3a1218'), C('#e2704a'), C('#f7a07a'), C('#4a1418'), glow_center=(23, 23), glow_r=(15, 14))
    e, fxl = icanvas(), icanvas()
    d = ImageDraw.Draw(e)
    pts = [(21, 4), (32, 4), (26, 18), (35, 18), (15, 42), (20, 26), (11, 26)]
    _glyph(d, pts, hi_edges=((6, 0), (0, 1), (5, 6)), lo_edges=((1, 2), (3, 4), (2, 3)))
    d.line(((22, 7), (16, 22)), fill=ICREAM)
    ## zincir: ikinci hedefe sıçrayan ince kol
    _zigline(e, [(30, 24), (35, 28), (33, 32), (40, 36)], GOLD[0])
    ## isabet parlaması (uçta) + kıvılcımlar
    isparkle(fxl, 14, 42, C('#ffffff'), C('#fff1a8'), 3)
    iput(fxl, [(11, 39), (17, 45), (11, 45), (18, 39)], C('#ffe38a'))
    isparkle(fxl, 41, 37, C('#ffffff'), C('#fff1a8'), 1)
    isparkle(fxl, 39, 10, C('#ffffff'), C('#ffd9a0'), 1)
    return _finish(im, e, fxl)


def icon_e():
    im = itile(C('#4f9a44'), C('#163319'), C('#7fcf5a'), C('#b6ef8e'), C('#123014'), glow_center=(27, 25), glow_r=(15, 14))
    e, fxl = icanvas(), icanvas()
    cx, cy, R = 27.5, 25.5, 11.0
    for y in range(48):
        for x in range(48):
            dd = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if dd > R:
                continue
            if dd <= 3.2:
                c = C('#ffffff')
            elif dd <= 5.6 or (dd <= 6.4 and (x + y) % 2 == 0):
                c = ICREAM
            elif dd <= 8.0 or (dd <= 8.8 and (x + y) % 2 == 0):
                c = GOLD[0]
            elif dd <= 10.0:
                c = GOLD[1]
            else:
                c = GOLD[2]
            iput(e, [(x, y)], c)
    ## damarlar
    for zz in ([(27, 25), (30, 21), (32, 22), (35, 18)], [(27, 26), (23, 29), (24, 32), (20, 34)], [(28, 26), (32, 29), (31, 32), (35, 33)], [(26, 24), (22, 22), (21, 19)]):
        _zigline(e, zz, C('#ffffff'))
    ## dışa sıçrayan arklar
    _zigline(e, [(36, 15), (39, 12), (38, 10), (42, 7)], GOLD[0])
    _zigline(e, [(37, 33), (40, 35), (39, 38), (43, 40)], GOLD[0])
    _zigline(e, [(20, 16), (18, 13), (20, 11)], GOLD[0])
    ## hız çizgileri
    for (x0, x1, y) in ((4, 13, 19), (3, 12, 26), (5, 14, 33)):
        _streak(fxl, x0, x1, y, (255, 251, 224), (120, 190, 90))
    isparkle(fxl, 10, 40, C('#ffffff'), C('#d8ff9a'), 1)
    isparkle(fxl, 42, 22, C('#ffffff'), C('#fff1a8'), 1)
    return _finish(im, e, fxl)


def icon_r():
    im = itile(C('#3d4f9a'), C('#141a3c'), C('#6b86d8'), C('#a8bcf5'), C('#141a3c'), glow_center=(24, 26), glow_r=(15, 15))
    e, fxl = icanvas(), icanvas()
    d = ImageDraw.Draw(e)
    L_, A, M, _D = GOLD
    outer = [(12, 10), (36, 10), (36, 25), (33, 33), (24, 42), (15, 33), (12, 25)]
    inner = [(14, 12), (34, 12), (34, 25), (31, 32), (24, 40), (17, 32), (14, 25)]
    d.polygon(outer, fill=A)
    d.line((12, 10, 36, 10), fill=L_)
    d.line((12, 10, 12, 25), fill=L_)
    d.line((36, 11, 36, 25, 33, 33, 24, 42), fill=M)
    d.polygon(inner, fill=C('#2a3a86'))
    d.line((14, 12, 34, 12), fill=C('#4a62c4'))
    d.line((14, 12, 14, 25), fill=C('#4a62c4'))
    d.line((34, 13, 34, 25, 31, 32, 24, 40), fill=C('#1a2356'))
    pts = [(24, 15), (30, 15), (26, 23), (31, 23), (20, 37), (23, 27), (18, 27)]
    d.polygon(pts, fill=A)
    d.line((pts[6], pts[0]), fill=ICREAM)
    d.line((pts[0], pts[1]), fill=ICREAM)
    d.line((pts[5], pts[6]), fill=L_)
    d.line(((25, 17), (21, 25)), fill=ICREAM)
    d.line((pts[3], pts[4]), fill=M)
    ## kalkanın çevresinde yıldırım kıvılcımları
    _zigline(fxl, [(7, 14), (9, 17), (7, 20), (9, 23)], C('#fff1a8'))
    _zigline(fxl, [(41, 17), (39, 20), (41, 23), (39, 26)], C('#fff1a8'))
    _zigline(fxl, [(20, 5), (23, 7), (25, 4), (28, 6)], C('#fff1a8'))
    isparkle(fxl, 8, 37, C('#ffffff'), C('#ffe38a'), 1)
    isparkle(fxl, 41, 34, C('#ffffff'), C('#ffe38a'), 1)
    return _finish(im, e, fxl)


BOOT = [
    ".....LLLLL.......",
    ".....LMMMD.......",
    ".....LMMMD.......",
    ".....LMMMD.......",
    ".....LMMMDD......",
    ".....LMMMMMDD....",
    "....LLMMMMMMMDD..",
    "....LMMMMMMMMMMD.",
    "....LMMMMMMMMMMMD",
    "....DDDDDDDDDDDDD",
    "....SSSSSSSSSSSSS",
]


def icon_pasif():
    im = itile(C('#2f7a6a'), C('#10302c'), C('#58b89a'), C('#9ae6cc'), C('#0e2a26'), glow_center=(28, 24), glow_r=(15, 14))
    e, fxl = icanvas(), icanvas()
    cols = {'L': C('#c98a52'), 'M': C('#a0643a'), 'D': C('#6e3f22'), 'S': C('#fbeede')}
    x0, y0 = 22, 16
    for yy, row in enumerate(BOOT):
        for xx, ch in enumerate(row):
            if ch != '.':
                iput(e, [(x0 + xx, y0 + yy)], cols[ch])
    ## ayakkabının arkasından çıkan yıldırım izi (kalın zikzak, sola doğru incelir)
    zz = [(25, 30), (20, 27), (17, 32), (12, 28), (9, 32), (5, 30)]
    pix = bres(zz)
    for i, (x, y) in enumerate(pix):
        iput(e, [(x, y)], GOLD[0] if i < len(pix) * 0.6 else GOLD[1])
        if i < len(pix) * 0.55:
            iput(e, [(x, y + 1)], GOLD[1])
    ## üstte hız çizgileri + yukarı ok (hız birikir)
    for (xa, xb, y) in ((6, 16, 18), (9, 19, 22), (5, 13, 38)):
        _streak(fxl, xa, xb, y, (255, 251, 224), (90, 170, 150))
    for i in range(4):
        iput(fxl, [(40 - i, 9 + i), (40 + i, 9 + i)], C('#fff1a8'))
        iput(fxl, [(40 - i, 13 + i), (40 + i, 13 + i)], C('#f2c440'))
    isparkle(fxl, 9, 42, C('#ffffff'), C('#fff1a8'), 1)
    return _finish(im, e, fxl)


def icons_image():
    names = [('Q  Şimşek Hücumu', icon_q()), ('E  Elektrik Topu', icon_e()), ('R  Yıldırım Kalkanı', icon_r()), ('Pasif  Yıldırım Hızı', icon_pasif())]
    k = 4
    gap = 26
    cell = 48 * k + gap
    out = Image.new('RGB', (len(names) * cell + gap, 48 * k + 64), (30, 30, 36))
    d = ImageDraw.Draw(out)
    f = font(17)
    for i, (title, ic) in enumerate(names):
        x = gap + i * cell
        out.paste(ic.resize((48 * k, 48 * k), Image.NEAREST).convert('RGB'), (x, 14))
        out.paste(ic.convert('RGB'), (x, 48 * k + 14 - 48))  ## gerçek 48 px boyutu (sol alt köşe)
        d.text((x + 56, 48 * k + 22), title, fill=(240, 236, 220), font=f)
    out.save(os.path.join(OUT, 'matthew_ikonlar.png'))
    return out


# ====================================================================== ana
def main():
    q = scene_q()
    save_gif('matthew_q.gif', q, 3, 70)
    p = scene_pasif()
    save_gif('matthew_pasif.gif', p, 3, 50, labels=[(8, 6, 'Pasif - normal iz (1 sn\'de incelip söner)'), (8, 84 * 3 + 6, 'Pasif - GÜÇLENMİŞ iz (maks. hız: 1 sn sersemletme + %80 AP)')])
    e = scene_e()
    save_gif('matthew_e.gif', e, 3, 70)
    es = scene_e_size()
    save_gif('matthew_e_boyut.gif', es, 4, 90, labels=[(96, 8, 'Matthew'), (350, 8, 'normal'), (590, 8, 'final (+%50)')])
    r = scene_r()
    save_gif('matthew_r.gif', r, 3, 83)
    rx = scene_r_explosion()
    save_gif('matthew_r_patlama.gif', rx, 2, 83)
    r_sizes_image()
    save_gif('matthew_r_parilti.gif', scene_r_glow(), 5, 83, labels=[(8, 6, 'kalkan %100'), (84 * 5 + 8, 6, 'kalkan %65'), (84 * 10 + 8, 6, 'kalkan %30'), (84 * 15 + 8, 6, 'kalkan %3 - kırılmak üzere')])
    ic = icons_image()

    ## toplu sayfa: her efektten seçilmiş kareler
    rows = [
        ('Q - Şimşek Hücumu: Matthew\'dan hedeflere sırayla çakar (köpek yerine)', [q[i] for i in (6, 10, 14, 16)], 2),
        ('Pasif - Yıldırım Hızı izi: üstte normal, altta GÜÇLENMİŞ (maks. hız)', [p[i] for i in (0, 20)], 2),
        ('E - Elektrik Topu: dönüşme, top, çarpma, fırlayan yaratık ötekine çarpar', [e[i] for i in (5, 6, 14, 25, 27, 29)], 1),
        ('E - boyut: normal ve final evrimi (+%50)', [es[i] for i in (0, 3, 6)], 2),
        ('R - Yıldırım Kalkanı: çağırma şimşeği, döngü, kırılma', [r[i] for i in (4, 10, 22, 55, 57, 59)], 2),
        ('R - kalkan kırılınca patlama (yarıçap 220)', [rx[i] for i in (4, 6, 8, 10, 12)], 1),
    ]
    f = font(18)
    th = 30
    width = max(sum(fr.width * sc + 8 for fr in frs) + 8 for (_t, frs, sc) in rows)
    width = max(width, ic.width + 16)
    height = sum(th + max(fr.height for fr in frs) * sc + 10 for (_t, frs, sc) in rows) + ic.height + 20
    sheet = Image.new('RGB', (width, height), (24, 24, 28))
    d = ImageDraw.Draw(sheet)
    y = 6
    for (title, frs, sc) in rows:
        d.text((10, y + 3), title, fill=(240, 236, 220), font=f)
        x = 8
        for fr in frs:
            sheet.paste(fr.convert('RGB').resize((fr.width * sc, fr.height * sc), Image.NEAREST), (x, y + th))
            x += fr.width * sc + 8
        y += th + max(fr.height for fr in frs) * sc + 10
    sheet.paste(ic, (8, y))
    sheet.save(os.path.join(OUT, 'matthew_simsek_sheet.png'))
    print('tamam:', sorted(n for n in os.listdir(OUT) if n.startswith('matthew')), sheet.size)


if __name__ == '__main__':
    main()
