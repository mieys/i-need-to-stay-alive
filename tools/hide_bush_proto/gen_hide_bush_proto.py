"""SAKLANMA ÇALISI PROTOTİPLERİ (2026-10-09) - kullanıcı: "haritanın belli bölgelerine içine girip saklanabileceğim çalılar eklemek istiyorum ama
buna uygun bir çalı assetim yok, 4 prototip hazırlar mısın, oyunun haritasıyla uyumlu".

Dört prototip, hepsi KODLA (deterministik, tohumlu) çizilir; renkler haritanın KENDİ tileset'lerinden ölçülen paletlerdir (açık zeytin ve koyu
deniz-yeşili çalı aileleri, çiçek renkleri, kök kahvesi), kontur 1 px koyu, ışık sol-üstten, merkezden dışa "kıl" vuruşlu doku (Objects.png çalılarıyla
aynı dil), 1 sanat pikseli = 1 DÜNYA pikseli (tileset ile aynı; karakterler daha ince: 1 sanat pikseli = ~0,54 dünya pikseli).
  A  Sık Çalı        - büyük, yuvarlak, açık zeytin (haritadaki en çok kullanılan çalı dili)
  B  Dikenli Çalı    - koyu deniz-yeşili, ışınsal sivri uçlar (koyu çamlar/yosunlu ağaçlarla "gizemli" uyum)
  C  Çiçekli Çalı    - orta yeşil, mavi/mor/beyaz çiçek öbekleri (haritanın çiçek paletiyle)
  D  Oyuklu Çalı     - geniş, alt ortasında KARANLIK GİRİŞ OYUĞU (içine girilebildiği açıkça okunur) + küçük kökler
Çıktı (tools/hide_bush_proto/out/): hide_bush_{a,b,c,d}.png (şeffaf, kutucuk hizalı: 48x48 / D 64x48), karsilastirma.png (gerçek harita çimeni üstünde,
oyuncu ölçeğinde: boş / yanında oyuncu / içinde oyuncu), yakin.png (8x büyütülmüş).
Kullanım (proje kökünden): python -I tools/hide_bush_proto/gen_hide_bush_proto.py
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'out')
os.makedirs(OUT, exist_ok=True)
PROJECT = os.path.normpath(os.path.join(HERE, '..', '..'))

# ---------------------------------------------------------------- paletler (haritanın kendi çalı/çiçek sprite'larından ölçüldü)
# index 0 = kontur, 1..n = koyu -> açık tonlar
LIGHT = [(25, 57, 38), (45, 96, 57), (53, 113, 55), (77, 132, 59), (104, 150, 61), (135, 171, 62), (151, 186, 58)]
TEAL = [(13, 35, 38), (24, 78, 70), (27, 98, 73), (39, 115, 69), (54, 140, 71), (64, 162, 61)]
MID = [(22, 63, 54), (36, 101, 68), (53, 113, 55), (77, 132, 59), (86, 140, 77), (104, 150, 61)]
ROOT = [(48, 21, 18), (92, 52, 52), (109, 66, 58), (151, 89, 62)]
FLOWER_BLUE = [(48, 25, 102), (75, 108, 196), (73, 138, 205), (185, 219, 255)]
FLOWER_PURPLE = [(71, 25, 123), (140, 70, 200), (190, 110, 235), (230, 190, 255)]
FLOWER_WARM = [(82, 25, 52), (152, 41, 60), (200, 70, 90), (240, 190, 160)]
SHADOW = (24, 52, 34)


def smooth(a, n=2):
    """kutu bulanıklaştırma (kenar tekrarı)"""
    out = a.astype(float)
    for _ in range(n):
        p = np.pad(out, 1, mode='edge')
        out = (p[:-2, 1:-1] + p[2:, 1:-1] + p[1:-1, :-2] + p[1:-1, 2:] + 4 * p[1:-1, 1:-1]) / 8.0
    return out


def erode(m):
    p = np.pad(m, 1, constant_values=False)
    return m & p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:]


def dilate(m):
    p = np.pad(m, 1, constant_values=False)
    return m | p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:]


class Canvas:
    def __init__(self, w, h, seed):
        self.w, self.h = w, h
        self.rng = random.Random(seed)
        self.yy, self.xx = np.mgrid[0:h, 0:w]
        self.rgba = np.zeros((h, w, 4), np.uint8)

    # ---- silüet
    def blobs_field(self, blobs):
        """blobs: (cx, cy, rx, ry, [(k, amp, phase), ...]) -> içeride pozitif alan; self.lobes = lob başına alan listesi (vadi/oluk çizgisi için)"""
        f = np.full((self.h, self.w), -1.0)
        self.lobes = []
        for (cx, cy, rx, ry, wob) in blobs:
            dx = (self.xx - cx) / rx
            dy = (self.yy - cy) / ry
            r = np.sqrt(dx * dx + dy * dy)
            th = np.arctan2(dy, dx)
            w = np.ones_like(r)
            for (k, amp, ph) in wob:
                w += amp * np.sin(k * th + ph)
            fl = 1.0 - r / w
            self.lobes.append(fl)
            f = np.maximum(f, fl)
        return f

    def creases(self, mask, width=0.075):
        """iki lobun birleştiği vadi: yaprak öbekleri arasındaki koyu oluk (haritadaki çalıların kümeli/lekeli görünümü)"""
        if len(self.lobes) < 2:
            return np.zeros_like(mask)
        stack = np.stack(self.lobes)
        srt = np.sort(stack, axis=0)
        top1, top2 = srt[-1], srt[-2]
        return mask & (top2 > 0.02) & ((top1 - top2) < width) & (top1 > 0.12)

    def polar_field(self, cx, cy, rx, ry, spikes, base_wob=()):
        """ışınsal sivri silüet: spikes = [(açı, genişlik rad, uzunluk oranı)]"""
        dx = (self.xx - cx) / rx
        dy = (self.yy - cy) / ry
        r = np.sqrt(dx * dx + dy * dy)
        th = np.arctan2(dy, dx)
        R = np.ones_like(r)
        for (k, amp, ph) in base_wob:
            R += amp * np.sin(k * th + ph)
        for (a, wd, ln) in spikes:
            d = np.abs((th - a + math.pi) % (2 * math.pi) - math.pi)
            R += ln * np.clip(1.0 - d / wd, 0.0, 1.0) ** 1.3
        return 1.0 - r / R

    # ---- gölgelendirme: derinlik (kubbe) + sol-üst ışık, ton dağılımı SIRALAMAYLA (koyu taban/sağ, açık sol-üst; tüm tonlar kullanılır)
    def shade(self, mask, ntones, lit=0.55, noise=0.10, center=None, dist=None):
        depth = np.zeros(mask.shape)
        cur = mask.copy()
        n = 0
        while cur.any() and n < 40:
            depth += cur
            cur = erode(cur)
            n += 1
        dome = depth / max(1.0, depth.max())
        cx, cy = center if center is not None else (self.cx0, self.cy0)
        R = 0.5 * max(self.w, self.h) * 0.8
        light = np.clip(((cx - self.xx) * 0.55 + (cy - self.yy) * 0.85) / R, -1.0, 1.0)
        base = (1.0 - lit) * smooth(dome, 1) + lit * (0.5 + 0.5 * light)
        nz = np.zeros_like(base)
        for (fx, fy, ph) in [(0.55, 0.31, 1.3), (0.23, 0.61, 4.1), (0.9, 0.7, 2.2)]:
            nz += np.sin(self.xx * fx + self.yy * fy + ph)
        base = base + noise * nz / 3.0
        vals = base[mask]
        # koyu ağırlıklı dağılım: gölge yanı geniş, parlak lekeler az (haritadaki çalılar gibi orta-koyu ağırlıklı)
        wts = np.array([0.14, 0.22, 0.24, 0.20, 0.13, 0.07])[:ntones] if ntones == 6 else np.ones(ntones) / ntones
        wts = wts / wts.sum()
        edges = np.quantile(vals, np.cumsum(wts)[:-1])
        tone = np.digitize(base, edges) + 1
        return np.clip(tone, 1, ntones)

    def strokes(self, tone, mask, cx, cy, count, ntones, length=(3, 6), lit_bias=0.5, jitter=0.35):
        """merkezden dışa kıl vuruşları: aydınlık bölgede daha açık, gölgede daha koyu"""
        rng = self.rng
        ys, xs = np.nonzero(erode(mask))
        if len(ys) == 0:
            return tone
        for _ in range(count):
            i = rng.randrange(len(ys))
            x, y = float(xs[i]), float(ys[i])
            ang = math.atan2(y - cy, x - cx) + rng.uniform(-jitter, jitter)
            L = rng.randint(*length)
            lit = (-(x - cx) - (y - cy)) * 0.04 + rng.uniform(-1, 1)
            delta = 1 if lit > lit_bias - 0.5 and rng.random() < 0.6 else -1
            for t in range(L):
                px = int(round(x + math.cos(ang) * t))
                py = int(round(y + math.sin(ang) * t))
                if 0 <= px < self.w and 0 <= py < self.h and mask[py, px]:
                    tone[py, px] = int(np.clip(tone[py, px] + delta, 1, ntones))
        return tone

    def paint(self, mask, tone, pal, outline=True):
        for y in range(self.h):
            for x in range(self.w):
                if mask[y, x]:
                    c = pal[int(tone[y, x])]
                    self.rgba[y, x] = (c[0], c[1], c[2], 255)
        if outline:
            edge = mask & ~erode(mask)
            rng = self.rng
            for y, x in zip(*np.nonzero(edge)):
                c = pal[0] if rng.random() > 0.12 else pal[1]
                self.rgba[y, x] = (c[0], c[1], c[2], 255)

    def ground_shadow(self, mask, cx, cy, rx, ry, alpha=84):
        """tabanda yarı saydam koyu yeşil yarım ay (haritadaki çalı sprite'larının tabanındaki gölge dili)"""
        rng = self.rng
        dx = (self.xx - cx) / rx
        dy = (self.yy - cy) / ry
        inside = (dx * dx + dy * dy) < 1.0
        for y, x in zip(*np.nonzero(inside & ~mask)):
            if self.rgba[y, x, 3] != 0:
                continue
            edge = (dx[y, x] ** 2 + dy[y, x] ** 2) > 0.72
            if edge and (x + y) % 2 == 0:
                continue
            self.rgba[y, x] = (SHADOW[0], SHADOW[1], SHADOW[2], alpha if not edge else alpha // 2)

    def image(self):
        return Image.fromarray(self.rgba, 'RGBA')


def leaf_tips(cv, mask, pal, count, rng, reach=(1, 2)):
    """kenardan dışa küçük yaprak uçları (haritadaki çalıların tüylü kenarı)"""
    edge = np.nonzero(mask & ~erode(mask))
    pts = list(zip(*edge))
    for _ in range(count):
        y, x = pts[rng.randrange(len(pts))]
        # dışa doğru: kütleden uzak yön
        cy, cx = cv.cy0, cv.cx0
        ang = math.atan2(y - cy, x - cx) + rng.uniform(-0.4, 0.4)
        L = rng.randint(*reach)
        for t in range(1, L + 1):
            px = int(round(x + math.cos(ang) * t)); py = int(round(y + math.sin(ang) * t))
            if 0 <= px < cv.w and 0 <= py < cv.h and not mask[py, px]:
                c = pal[0] if t == L else pal[2]
                cv.rgba[py, px] = (c[0], c[1], c[2], 255)


# ---------------------------------------------------------------- A: SIK ÇALI
def make_a():
    cv = Canvas(48, 48, 101)
    cx, cy = 24.0, 22.0
    cv.cx0, cv.cy0 = cx, cy
    blobs = [
        (cx - 11, cy + 3, 11.5, 11.0, [(3, 0.05, 0.4), (6, 0.03, 1.9)]),
        (cx + 10, cy + 3, 12.0, 11.0, [(4, 0.05, 2.2)]),
        (cx - 6, cy - 5, 11.5, 10.5, [(5, 0.05, 0.9)]),
        (cx + 6, cy - 6, 11.5, 10.0, [(4, 0.05, 3.3)]),
        (cx, cy + 6, 19.0, 9.5, [(6, 0.03, 1.1)]),
        (cx, cy - 1, 14.0, 12.0, [(5, 0.04, 2.0)]),
    ]
    f = cv.blobs_field(blobs)
    f = np.where(cv.yy > cy + 15.5, -1.0, f)
    mask = f > 0
    ntones = len(LIGHT) - 1
    tone = cv.shade(mask, ntones, lit=0.62, noise=0.12)
    tone = np.where(cv.creases(mask), np.maximum(tone - 2, 1), tone)
    tone = np.where(mask & (cv.yy > cy + 9), np.maximum(tone - 1, 1), tone)
    tone = cv.strokes(tone, mask, cx, cy, 300, ntones, length=(3, 6))
    cv.ground_shadow(mask, cx, cy + 15.5, 20.0, 5.2)
    cv.paint(mask, tone, LIGHT)
    leaf_tips(cv, mask, LIGHT, 18, cv.rng)
    return cv.image()


# ---------------------------------------------------------------- B: DİKENLİ (koyu) ÇALI
def make_b():
    cv = Canvas(48, 48, 202)
    cx, cy = 24.0, 22.5
    cv.cx0, cv.cy0 = cx, cy
    rng = cv.rng
    spikes = []
    n = 26
    for i in range(n):
        a = (i + rng.uniform(-0.3, 0.3)) / n * 2 * math.pi
        spikes.append((a, rng.uniform(0.10, 0.17), rng.uniform(0.08, 0.30)))
    f = cv.polar_field(cx, cy, 20.0, 16.5, spikes, base_wob=[(3, 0.04, 0.8), (5, 0.035, 2.6)])
    # alt kenar düz: çalı yere otursun
    f = np.where(cv.yy > cy + 13.5, -1.0, f)
    mask = f > 0
    ntones = len(TEAL) - 1
    tone = cv.shade(mask, ntones, lit=0.6, noise=0.12)
    tone = np.where(mask & (cv.yy > cy + 8), np.maximum(tone - 1, 1), tone)
    tone = cv.strokes(tone, mask, cx, cy, 420, ntones, length=(4, 9), jitter=0.22)
    cv.ground_shadow(mask, cx, cy + 14.2, 19.0, 4.6)
    cv.paint(mask, TEAL, TEAL) if False else cv.paint(mask, tone, TEAL)
    # soluk sivri uç vurguları (sivrilerin ucu daha açık)
    edge = mask & ~erode(mask)
    for y, x in zip(*np.nonzero(edge)):
        if y < cy + 6 and rng.random() < 0.22:
            c = TEAL[4]
            cv.rgba[y, x] = (c[0], c[1], c[2], 255)
    return cv.image()


# ---------------------------------------------------------------- C: ÇİÇEKLİ ÇALI
def flower(cv, x, y, pal, kind):
    """3x3 artı + merkez (haritanın çiçek sprite'ları gibi koyu kontur renginde ince kenar)"""
    out, petal, petal2, center = pal
    pts = {(0, 0): center, (-1, 0): petal, (1, 0): petal, (0, -1): petal2, (0, 1): petal}
    if kind == 1:
        pts = {(0, 0): center, (-1, 0): petal2, (1, 0): petal, (0, -1): petal, (0, 1): petal2, (-1, -1): out, (1, -1): out}
    for (dx, dy), c in pts.items():
        px, py = x + dx, y + dy
        if 0 <= px < cv.w and 0 <= py < cv.h:
            cv.rgba[py, px] = (c[0], c[1], c[2], 255)


def make_c():
    cv = Canvas(48, 48, 303)
    cx, cy = 24.0, 22.0
    cv.cx0, cv.cy0 = cx, cy
    blobs = [
        (cx - 11, cy + 3, 11.0, 10.5, [(4, 0.05, 1.0)]),
        (cx + 11, cy + 3, 11.0, 10.5, [(5, 0.05, 0.3)]),
        (cx - 4, cy - 6, 12.5, 10.5, [(5, 0.05, 3.1)]),
        (cx + 7, cy - 4, 11.0, 10.0, [(4, 0.05, 2.4)]),
        (cx, cy + 6, 19.5, 9.5, [(6, 0.03, 0.7)]),
    ]
    f = cv.blobs_field(blobs)
    f = np.where(cv.yy > cy + 15.5, -1.0, f)
    mask = f > 0
    ntones = len(MID) - 1
    tone = cv.shade(mask, ntones, lit=0.62, noise=0.12)
    tone = np.where(cv.creases(mask), np.maximum(tone - 2, 1), tone)
    tone = np.where(mask & (cv.yy > cy + 9), np.maximum(tone - 1, 1), tone)
    tone = cv.strokes(tone, mask, cx, cy, 260, ntones, length=(3, 5))
    cv.ground_shadow(mask, cx, cy + 15.5, 20.0, 5.0)
    cv.paint(mask, tone, MID)
    leaf_tips(cv, mask, MID, 14, cv.rng)
    rng = cv.rng
    inner = erode(erode(mask))
    pts = list(zip(*np.nonzero(inner)))
    # çiçekler 4 KÜME halinde (üst/dış tepelerde), her kümede 2-4 çiçek + tek tük tomurcuk
    clusters = []
    for (ox, oy) in [(-13, 0), (-6, -9), (3, -9), (11, -4), (14, 4), (-9, 6), (2, 3)]:
        x0, y0 = int(cx + ox + rng.uniform(-1.5, 1.5)), int(cy + oy + rng.uniform(-1.5, 1.5))
        if 0 <= x0 < cv.w and 0 <= y0 < cv.h and inner[y0, x0]:
            clusters.append((x0, y0))
    pals = [FLOWER_BLUE, FLOWER_PURPLE, FLOWER_PURPLE, FLOWER_BLUE, (FLOWER_BLUE[0], FLOWER_BLUE[3], FLOWER_BLUE[3], FLOWER_BLUE[1])]
    occupied = []
    for ci, (x0, y0) in enumerate(clusters):
        pal = pals[ci % len(pals)]
        for _ in range(rng.randint(2, 4)):
            for _t in range(30):
                x = int(x0 + rng.uniform(-5, 5)); y = int(y0 + rng.uniform(-4, 4))
                if 0 <= x < cv.w and 0 <= y < cv.h and mask[y, x] and not any((x - ox) ** 2 + (y - oy) ** 2 < 9 for ox, oy in occupied):
                    occupied.append((x, y))
                    if rng.random() < 0.28:                      # tomurcuk: 2 piksel
                        c = pal[2]
                        cv.rgba[y, x] = (c[0], c[1], c[2], 255)
                        if x + 1 < cv.w and mask[y, x + 1]:
                            cc = pal[3]; cv.rgba[y, x + 1] = (cc[0], cc[1], cc[2], 255)
                    else:
                        flower(cv, x, y, pal, rng.randrange(2))
                    break
    return cv.image()


# ---------------------------------------------------------------- D: OYUKLU ÇALI (girişli)
def make_d():
    cv = Canvas(64, 48, 404)
    cx, cy = 32.0, 21.5
    cv.cx0, cv.cy0 = cx, cy
    blobs = [
        (cx - 18, cy + 3, 12.0, 11.0, [(3, 0.05, 0.2)]),
        (cx + 18, cy + 3, 12.0, 11.0, [(4, 0.05, 1.7)]),
        (cx - 9, cy - 4, 13.0, 11.0, [(5, 0.05, 2.0)]),
        (cx + 8, cy - 5, 13.5, 11.0, [(4, 0.05, 0.8)]),
        (cx, cy - 8, 12.0, 8.5, [(6, 0.04, 3.0)]),
        (cx, cy + 6, 27.0, 10.0, [(6, 0.03, 1.2)]),
    ]
    f = cv.blobs_field(blobs)
    f = np.where(cv.yy > cy + 15.5, -1.0, f)
    mask = f > 0
    ntones = len(LIGHT) - 1
    tone = cv.shade(mask, ntones, lit=0.62, noise=0.12)
    tone = np.where(cv.creases(mask), np.maximum(tone - 2, 1), tone)
    tone = np.where(mask & (cv.yy > cy + 9), np.maximum(tone - 1, 1), tone)
    tone = cv.strokes(tone, mask, cx, cy, 380, ntones, length=(3, 6))
    cv.ground_shadow(mask, cx, cy + 16.0, 27.0, 5.2)
    # GİRİŞ OYUĞU: alt orta (hafif sola), yarım elips
    ex, ey = cx - 2.0, cy + 15.0
    dx = (cv.xx - ex) / 9.0
    dy = (cv.yy - ey) / 11.5
    cave = (dx * dx + dy * dy < 1.0) & mask & (cv.yy <= ey + 1)
    cv.paint(mask, tone, LIGHT)
    # oyuk içi: koyudan açığa dikey geçiş + sağ/sol duvarlarda yaprak gölgesi
    for y, x in zip(*np.nonzero(cave)):
        d = (dx[y, x] ** 2 + dy[y, x] ** 2)
        t = 0 if d > 0.55 else 1
        c = [(13, 35, 38), (8, 22, 26)][t]
        if y >= ey - 1:
            c = (48, 21, 18) if (x + y) % 3 else (31, 14, 12)   # zemin: koyu toprak/kök
        cv.rgba[y, x] = (c[0], c[1], c[2], 255)
    # oyuk kenarına açık yaprak "perde" uçları (içeri sarkan yapraklar)
    rng = cv.rng
    rim = dilate(cave) & ~cave & mask
    for y, x in zip(*np.nonzero(rim)):
        if y < ey - 2 and rng.random() < 0.55:
            c = LIGHT[rng.choice([2, 3, 4])]
            cv.rgba[y, x] = (c[0], c[1], c[2], 255)
            if rng.random() < 0.5 and cave[min(y + 1, cv.h - 1), x]:
                cc = LIGHT[1]
                cv.rgba[y + 1, x] = (cc[0], cc[1], cc[2], 255)
    # oyuk çevresine 1 px koyu kontur
    for y, x in zip(*np.nonzero(dilate(cave) & ~cave & mask)):
        if y >= ey - 6:
            c = LIGHT[0]
            cv.rgba[y, x] = (c[0], c[1], c[2], 255)
    leaf_tips(cv, mask, LIGHT, 22, rng)
    # küçük kökler (haritanın çalı/ağaç diplerindeki kahve kökler)
    for (rx0, side) in ((cx - 14, -1), (cx + 13, 1), (cx + 4, 1)):
        y0 = int(cy + 16)
        for i in range(4):
            x0 = int(rx0 + side * i * 0.8)
            c = ROOT[[0, 2, 1, 2][i]]
            if 0 <= x0 < cv.w and y0 < cv.h:
                cv.rgba[y0, x0] = (c[0], c[1], c[2], 255)
    return cv.image()


# ---------------------------------------------------------------- önizleme (gerçek harita çimeni üstünde, oyuncu ölçeğinde)
def grass_patch(w_cells=16, h_cells=12):
    """haritadan gerçek bir çim parçası (nesnesiz) - harita okunamazsa düz çim rengi"""
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
        best = None
        for y in range(20, 230 - h_cells):
            for x in range(20, 230 - w_cells, 3):
                if grass[y:y + h_cells, x:x + w_cells].all() and not busy[y - 2:y + h_cells + 2, x - 2:x + w_cells + 2].any():
                    best = (x, y); break
            if best: break
        if best:
            x, y = best
            return render(root, ts, region=(x, y, x + w_cells, y + h_cells)).convert('RGBA')
    except Exception as ex:  # noqa
        print('harita parcasi yok:', ex)
    return Image.new('RGBA', (w_cells * 16, h_cells * 16), (126, 176, 84, 255))


def player_frame():
    sheet = Image.open(os.path.join(PROJECT, 'assets', 'characters', 'assasin', 'sheets', 'idle.png')).convert('RGBA')
    fr = sheet.crop((0, 0, 48, 48))                      # aşağı bakan ilk kare
    # oyunda: sprite ölçeği 1.0845 yerel x kök 0.5 x kamera 2 = 1.0845 ekran pikseli / sanat pikseli
    s = 1.0845
    return fr.resize((int(round(48 * s)), int(round(48 * s))), Image.NEAREST)


def _font(size):
    from PIL import ImageFont
    for cand in (r'C:\Windows\Fonts\segoeui.ttf', r'C:\Windows\Fontsrial.ttf'):
        if os.path.exists(cand):
            return ImageFont.truetype(cand, size)
    return ImageFont.load_default()


def compose(sprites):
    """ekran çözünürlüğünde (dünya x2) paneller, sonra x2 büyütülür: 1 dünya pikseli = 4 görüntü pikseli"""
    labels = ['A  Sık Çalı', 'B  Dikenli Çalı', 'C  Çiçekli Çalı', 'D  Oyuklu Çalı']
    notes = ['haritadaki çalı dili,\nen sade', 'koyu / gizemli,\nçam ve yosunla uyumlu', 'mavi-mor çiçekler,\nen belirgin', 'alt ortada karanlık giriş,\nen net "girilir" ipucu']
    cols = ['boş', 'yanında oyuncu (gerçek ölçek)', 'içinde oyuncu (saklanmış)']
    pw, ph = 190, 132
    gx, gy = 4, 4
    left, top = 190, 34
    W = left + 3 * (pw * 2 + gx)
    H = top + 4 * (ph * 2 + gy)
    sheet = Image.new('RGB', (W, H), (24, 28, 24))
    d = ImageDraw.Draw(sheet)
    f1, f2 = _font(22), _font(15)
    bg0 = grass_patch(14, 10)
    bg0 = bg0.resize((bg0.width * 2, bg0.height * 2), Image.NEAREST)
    pf = player_frame()
    for ri, (name, spr) in enumerate(sprites):
        sp2 = spr.resize((spr.width * 2, spr.height * 2), Image.NEAREST)
        for ci in range(3):
            ox, oy = (ci * 37) % (bg0.width - pw), (ri * 29) % (bg0.height - ph)
            panel = bg0.crop((ox, oy, ox + pw, oy + ph)).copy()
            bx = (pw - sp2.width) // 2 + (-26 if ci == 1 else 0)
            by = ph - sp2.height - 6
            foot_y = by + int(sp2.height * 0.80)
            px = bx + (sp2.width - pf.width) // 2
            if ci == 0:
                panel.alpha_composite(sp2, (bx, by))
            elif ci == 1:
                panel.alpha_composite(sp2, (bx, by))
                panel.alpha_composite(pf, (bx + sp2.width + 6, foot_y - 41))
            else:
                panel.alpha_composite(pf, (px, foot_y - 41 - 2))
                a = np.array(sp2)
                a[..., 3] = (a[..., 3] * 0.74).astype(np.uint8)       # içindeyken çalı hafif saydam: oyuncu siluet olarak seçilir
                panel.alpha_composite(Image.fromarray(a, 'RGBA'), (bx, by))
            panel = panel.resize((pw * 2, ph * 2), Image.NEAREST)
            sheet.paste(panel.convert('RGB'), (left + ci * (pw * 2 + gx), top + ri * (ph * 2 + gy)))
        d.text((12, top + ri * (ph * 2 + gy) + 90), labels[ri], fill=(255, 255, 255), font=f1)
        d.multiline_text((12, top + ri * (ph * 2 + gy) + 124), notes[ri], fill=(190, 210, 190), font=f2, spacing=3)
    for ci, t in enumerate(cols):
        d.text((left + ci * (pw * 2 + gx) + 6, 8), t, fill=(210, 230, 210), font=f2)
    return sheet


def main():
    sprites = [('hide_bush_a', make_a()), ('hide_bush_b', make_b()), ('hide_bush_c', make_c()), ('hide_bush_d', make_d())]
    for name, im in sprites:
        im.save(os.path.join(OUT, name + '.png'))
    compose(sprites).save(os.path.join(OUT, 'karsilastirma.png'))
    # yakın plan: 8x, açık/koyu zemin
    pad = 6
    W = sum(im.width for _, im in sprites) + pad * 5
    big = Image.new('RGBA', (W * 6, 48 * 6 + pad * 2 * 6), (126, 176, 84, 255))
    x = pad * 6
    for _, im in sprites:
        big.alpha_composite(im.resize((im.width * 6, im.height * 6), Image.NEAREST), (x, pad * 6))
        x += (im.width + pad) * 6
    big.convert('RGB').save(os.path.join(OUT, 'yakin.png'))
    print('tamam:', os.listdir(OUT))


if __name__ == '__main__':
    main()
