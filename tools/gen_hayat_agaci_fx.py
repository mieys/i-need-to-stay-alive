"""Oakley R "Hayat Ağacı" (madde 266) sanatı -> assets/fx/oakley/hayat_agaci/. Kullanıcı seçimi (madde 265 prototipleri): ağaç C
(Bereket Ağacı = haritanın meyve ağacı), kök efekti C (toprak altında tümsek + dipten fışkıran kalın kökler), ağaç ve aurası %30 büyük.
  * agac_{kucuk,orta,buyuk}.png  = ../Harita içerikleri/sadece ağaç/Assets_separately/Trees_texture_shadow/Fruit_tree{3,2,1}.png
    (haritadaki "sadece agac golgeli" ile aynı sanat, bbox'a kırpılır; ölçek 1,3 oyunda Sprite2D.scale ile) + agac_kucuk_golgesiz.png
    (topraktan çıkış/çekilme anında gölge zemin çizgisinin altında kalsın diye gölgesiz sürüm). Gövde dibi noktaları aşağıda yazdırılır
    -> scripts/oakley_tree.gd TREE_BASE.
  * alan.png      2:1 elips (169 x 84,5 = madde 265'in 130 x 65'i x1,3) soluk altın dolgu + kenar bandı, 1 dünya px.
  * isik_arka.png / isik_on.png  kenarda yükselen altın ışık çizgileri (C dili), 14 kare döngü (12 fps); arka yarı (kuzey) / ön yarı.
  * halka.png     açılış darbesi halkası, 6 kare (14 fps).
  * tumsek.png    toprak altında giden kökün tümseği, 2 kare.
  * kok_{s,m,l}_{arka,on}.png  yaratığın dibinden fışkıran kökler + sarılma halkası (6 kare: 0-3 büyüme, 4-5 döngü; bırakma = büyümenin
    tersi). Boylar fx_oakley_entangle.gd ile aynı eşik (gövde yarıçapı 16 / 30). Ölçek 1 (1 piksel = 1 dünya birimi, haritanın pikseli).
  * meyve.png, arti.png, parilti_{1,2,3}.png, tohum.png  can tiki (ağaçtan dosta uçan elma -> altın artı) ve büyüme pırıltıları.
Çizim dili madde 265 prototipiyle (tools/proto_20261018/hayat_agaci_proto.py) aynı: dolu kütleler, 1 px koyu kontur, alfa bantlı.
Kullanım (proje kökünden): python -I tools/gen_hayat_agaci_fx.py
"""
import math
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..'))
TREE_DIR = os.path.join(os.path.dirname(PROJECT), 'Harita içerikleri', 'sadece ağaç', 'Assets_separately')
OUT = os.path.join(PROJECT, 'assets', 'fx', 'oakley', 'hayat_agaci')
TAU = math.tau
S = 1.3
RX, RY = 130.0 * S, 65.0 * S
RAY_N, RAY_FRAMES = 26, 14
RING_FRAMES, RING_FPS = 6, 14.0

GOLD = [(96, 52, 14), (170, 104, 24), (232, 170, 52), (252, 222, 120), (255, 248, 214)]
ROOT = [(38, 22, 14), (82, 50, 28), (124, 80, 44), (166, 118, 68), (204, 160, 104)]
DIRT = [(70, 48, 30), (104, 74, 46), (140, 104, 66)]
APPLE = [(70, 14, 20), (170, 32, 36), (226, 70, 60), (255, 200, 180)]
LEAF = (84, 148, 58)


def band(a, n=5):
    return max(0.0, min(1.0, round(a * n) / n))


def ease_out(t):
    t = max(0.0, min(1.0, t))
    return 1 - (1 - t) ** 3


class Cv:
    """Kayan nokta RGBA tuval; 'üstüne' karıştırma (prototipteki Ov)."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.c = np.zeros((h, w, 4), np.float32)

    def put(self, m, rgb, a, x0=0, y0=0):
        if a <= 0.001:
            return
        h, w = m.shape
        X0, Y0, X1, Y1 = max(0, x0), max(0, y0), min(self.w, x0 + w), min(self.h, y0 + h)
        if X1 <= X0 or Y1 <= Y0:
            return
        mm = m[Y0 - y0:Y1 - y0, X0 - x0:X1 - x0]
        if not mm.any():
            return
        reg = self.c[Y0:Y1, X0:X1]
        d = reg[mm]
        oa = a + d[:, 3] * (1 - a)
        col = (np.array(rgb, np.float32) / 255.0 * a + d[:, :3] * d[:, 3:4] * (1 - a)) / np.maximum(oa[:, None], 1e-6)
        reg[mm] = np.concatenate([col, oa[:, None]], 1)

    def px(self, x, y, rgb, a):
        self.put(np.ones((1, 1), bool), rgb, a, int(math.floor(x)), int(math.floor(y)))

    def img(self):
        return Image.fromarray(np.clip(self.c * 255.0, 0, 255).astype(np.uint8), 'RGBA')


def ell_d(w, h, cx, cy, rx, ry):
    Y, X = np.mgrid[0:h, 0:w]
    return ((X + 0.5 - cx) / rx) ** 2 + ((Y + 0.5 - cy) / ry) ** 2


def dilate(m):
    o = m.copy()
    o[1:] |= m[:-1]
    o[:-1] |= m[1:]
    o[:, 1:] |= m[:, :-1]
    o[:, :-1] |= m[:, 1:]
    return o


def tube(cv, pts, r0, r1, pal):
    """Kalınlığı r0 -> r1 incelen dolu kök: koyu kontur, gövde, üst ışık, alt gölge."""
    P = np.array(pts, np.float32)
    Y, X = np.mgrid[0:cv.h, 0:cv.w]
    body = np.zeros((cv.h, cv.w), bool)
    seg = np.hypot(np.diff(P[:, 0]), np.diff(P[:, 1]))
    total = max(1e-3, float(seg.sum()))
    s = 0.0
    for i in range(len(P) - 1):
        n = max(1, int(seg[i] * 2))
        for j in range(n):
            q = j / n
            px, py = P[i] + (P[i + 1] - P[i]) * q
            r = r0 + (r1 - r0) * ((s + seg[i] * q) / total)
            body |= (X + 0.5 - px) ** 2 + (Y + 0.5 - py) ** 2 <= r * r
        s += seg[i]
    cv.put(dilate(body) & ~body, pal[0], 1.0)
    cv.put(body, pal[2], 1.0)
    top = body & ~np.roll(body, 1, axis=0)
    bot = body & ~np.roll(body, -1, axis=0)
    cv.put(bot & ~top, pal[1], 1.0)
    cv.put(top, pal[3], 1.0)


def strip(frames):
    w, h = frames[0].size
    out = Image.new('RGBA', (w * len(frames), h))
    for i, f in enumerate(frames):
        out.alpha_composite(f, (i * w, 0))
    return out


def save(im, name):
    im.save(os.path.join(OUT, name))
    return im


# ====================================================================== ağaçlar
def trees():
    info = {}
    for i, key in ((3, 'kucuk'), (2, 'orta'), (1, 'buyuk')):
        plain = Image.open(os.path.join(TREE_DIR, 'Trees', f'Fruit_tree{i}.png')).convert('RGBA')
        shad = Image.open(os.path.join(TREE_DIR, 'Trees_texture_shadow', f'Fruit_tree{i}.png')).convert('RGBA')
        a = np.array(plain)[:, :, 3] > 0
        ys = np.where(a.any(axis=1))[0]
        by = int(ys.max())
        xs = np.where(a[by - 3:by + 1].any(axis=0))[0]
        bx = (xs.min() + xs.max() + 1) / 2.0
        pb, sb = plain.getbbox(), shad.getbbox()
        ox, oy = sb[2] - pb[2], sb[1] - pb[1]  ## gölgeli sürüm başka tuvalde olabilir (madde 265 tuzağı)
        crop = shad.crop(sb)
        save(crop, f'agac_{key}.png')
        base = (bx + ox - sb[0], by + oy - sb[1])
        info[key] = (base, by - int(ys.min()) + 1, crop.size)
        if key == 'kucuk':
            pc = plain.crop((sb[0] - ox, sb[1] - oy, sb[2] - ox, sb[3] - oy))
            save(pc, 'agac_kucuk_golgesiz.png')
    return info


# ====================================================================== alan + ışık + halka
def zone():
    w, h = int(2 * math.ceil(RX)) + 4, int(2 * math.ceil(RY)) + 4
    cv = Cv(w, h)
    d = ell_d(w, h, w / 2, h / 2, RX, RY)
    cv.put(d <= 1.0, GOLD[3], 0.07)
    cv.put((d <= 1.0) & (d > 0.9), GOLD[3], 0.14)
    return save(cv.img(), 'alan.png')


def rays():
    """Kenarda yükselen ışık çizgileri - arka yarı (sin < 0) ve ön yarı ayrı sayfa; düğüm konumu = tuvalin (0,0) noktası:
    arka için alanın kuzey ucu (merkez - RY), ön için güney ucu (merkez + RY)."""
    w = int(2 * math.ceil(RX)) + 6
    top_pad = 46
    hb = int(math.ceil(RY)) + top_pad + 3
    out = {}
    for back in (True, False):
        frames = []
        for f in range(RAY_FRAMES):
            t = f / RAY_FRAMES
            cv = Cv(w, hb)
            ## tuvalde merkez: arka -> alanın merkezi (w/2, top_pad + RY) ; ön -> (w/2, top_pad)
            cx, cy = w / 2, (top_pad + RY) if back else top_pad
            for i in range(RAY_N):
                a = TAU * i / RAY_N + 0.15
                if (math.sin(a) < 0) != back:
                    continue
                x = cx + RX * 0.97 * math.cos(a)
                y = cy + RY * 0.97 * math.sin(a)
                ph = (t + i * 0.37) % 1.0
                L = 10 + 5 * ((i * 7) % 3)
                lift = ph * 18
                for j in range(L):
                    al = band((1 - j / L) * (1 - ph) * 0.8, 4)
                    cv.px(x, y - lift - j, GOLD[4] if j < 2 else GOLD[3], al)
            frames.append(cv.img())
        out[back] = save(strip(frames), 'isik_arka.png' if back else 'isik_on.png')
    return w, hb, top_pad


def ring_sheet():
    rmax = 18 + (RX * 1.3 - 18)
    w, h = int(2 * rmax) + 8, int(rmax) + 8
    frames = []
    for f in range(RING_FRAMES):
        kt = f / RING_FPS
        q = ease_out(kt / 0.42)
        rx = 18 + (RX * 1.3 - 18) * q
        cv = Cv(w, h)
        for (r, th, al) in ((rx, 3.0 - 1.5 * q, 0.9 * (1 - q)), (rx * 0.82, 1.5, 0.4 * (1 - q))):
            d = ell_d(w, h, w / 2, h / 2, r, r * 0.5)
            cv.put((d <= 1.0) & (d >= ((r - th) / r) ** 2), GOLD[4], band(al, 5))
        frames.append(cv.img())
    save(strip(frames), 'halka.png')
    return w, h


# ====================================================================== kök
def mound():
    frames = []
    for (rx, ry) in ((4.5, 2.6), (5.0, 2.3)):
        cv = Cv(12, 8)
        d = ell_d(12, 8, 6, 5, rx, ry)
        cv.put(d <= 1.0, DIRT[1], 1.0)
        cv.put((d <= 1.0) & (d > 0.55), DIRT[0], 1.0)
        d2 = ell_d(12, 8, 6, 4, rx * 0.6, ry * 0.6)
        cv.put(d2 <= 0.5, DIRT[2], 1.0)
        frames.append(cv.img())
    save(strip(frames), 'tumsek.png')


WRAP_K = {'s': 1.0, 'm': 1.6, 'l': 2.6}
WRAP_SPIKES = [(-10, 9, False), (10, 8, False), (-4, 11, True), (5, 10, True)]  ## (dx, boy, arkada mı) - prototip C


def wrap_sheets():
    info = {}
    for key, k in WRAP_K.items():
        rx, ry, th = 10.0 * k, 3.6 * k, 3.0 * (k ** 0.6)
        w = int(2 * (rx + 7)) + 2
        h = int(math.ceil(12 * k)) + 12
        gy = h - 4  ## zemin satırı (yaratığın ayak hizası)
        cx = w / 2
        r0, r1 = 2.1 * (k ** 0.6), 0.8 * (k ** 0.5)
        for layer_back in (True, False):
            frames = []
            for f in range(6):
                grow = [0.25, 0.5, 0.75, 1.0, 1.0, 1.0][f]
                breathe = 1 if f == 5 else 0
                cv = Cv(w, h)
                for (dx, h0, back) in WRAP_SPIKES:
                    if back != layer_back:
                        continue
                    hgt = h0 * k * grow
                    if hgt < 1:
                        continue
                    bx = cx + dx * k
                    tipx = bx - math.copysign(4 * k, dx) * grow - math.copysign(breathe, dx)
                    tube(cv, [(bx, gy + 1), (bx + (tipx - bx) * 0.3, gy - hgt * 0.55), (tipx, gy - hgt)], r0, r1, ROOT)
                if f >= 2:  ## sarılma halkası: arka katman üst yarı, ön katman alt yarı
                    cy = gy - 5 * k
                    d = ell_d(w, h, cx, cy, rx, ry)
                    Y = np.mgrid[0:h, 0:w][0]
                    half = (Y + 0.5 - cy) >= 0
                    sel = ~half if layer_back else half
                    m = (d <= 1.0) & (d >= ((rx - th) / rx) ** 2) & sel
                    cv.put(dilate(m) & ~m & sel, ROOT[0], 1.0)
                    cv.put(m, ROOT[2], 1.0)
                    cv.put(m & ~np.roll(m, 1, axis=0), ROOT[3], 1.0)
                frames.append(cv.img())
            save(strip(frames), f'kok_{key}_{"arka" if layer_back else "on"}.png')
        info[key] = (w, h, gy)
    return info


# ====================================================================== küçük şekiller
def glyph(rows, pal):
    h, w = len(rows), max(len(r) for r in rows)
    im = Image.new('RGBA', (w, h))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in pal:
                im.putpixel((x, y), tuple(pal[ch]) + (255,))
    return im


def sparkle(k):
    n = 2 * k + 1
    im = Image.new('RGBA', (n, n))
    for i in range(1, k + 1):
        for (dx, dy) in ((i, 0), (-i, 0), (0, i), (0, -i)):
            im.putpixel((k + dx, k + dy), (GOLD[3] if i > 1 or k == 1 else GOLD[4]) + (255,))
    im.putpixel((k, k), GOLD[4] + (255,))
    return im


def glyphs():
    save(glyph(["...s...", "..oslo.", ".orrRo.", "orrrRwo", "orrrrRo", ".orrro.", "..ooo.."],
               {'o': APPLE[0], 'r': APPLE[1], 'R': APPLE[2], 'w': APPLE[3], 's': ROOT[1], 'l': LEAF}), 'meyve.png')
    save(glyph(["..ooo..", "..oho..", "ooohooo", "ohhwhho", "ooohooo", "..oho..", "..ooo.."],
               {'o': GOLD[0], 'h': GOLD[3], 'w': GOLD[4]}), 'arti.png')
    for k in (1, 2, 3):
        save(sparkle(k), f'parilti_{k}.png')
    save(glyph([".o.", "oho", ".o."], {'o': GOLD[1], 'h': GOLD[4]}), 'tohum.png')


def main():
    os.makedirs(OUT, exist_ok=True)
    info = trees()
    zw = zone()
    rw, rh, top_pad = rays()
    hw, hh = ring_sheet()
    mound()
    wr = wrap_sheets()
    glyphs()
    print('TREE_BASE (kırpılmış dokuda gövde dibi), boy, doku:')
    for k, (b, hgt, size) in info.items():
        print(f'  "{k}": Vector2({b[0]:.1f}, {b[1]:.1f}), boy {hgt}, doku {size}')
    print('alan', zw.size, '| ışık kare', (rw, rh), 'üst pay', top_pad, '| halka kare', (hw, hh))
    for k, v in wr.items():
        print(f'  kök {k}: kare {v[0]}x{v[1]}, zemin satırı {v[2]}')


if __name__ == '__main__':
    main()
