"""YERALTI CANAVARI ZEMİN ÇATLAKLARI - sprite sayfası (2026-10-10, kullanıcı: "çatlaklar zeminle uyumsuz, yeniden tasarla; çatlaklar olduğunda fps inanılmaz düştü,
sanırım spritesheet yapman gerekiyor"). Eskiden scripts/underground_cracks.gd her karede yüzlerce çokgen/çizgi çiziyordu; artık çatlaklar hazır piksel sanatı karelerdir.
Çizim dili (haritanın zemininden ölçülen tonlar): ince (1-2 px) koyu toprak yarığı, güney duvarında koyu gölge, kuzey dudağında yırtılmış çimin koyu yeşil hattı,
yanında 1-2 px toprak kırıntıları - kalın siyah çizgi yok, zeminle aynı aileden renkler.
Çıktı: assets/fx/underground_cracks/cracks.png (64x64 kare, 4 büyüme karesi x 8 çeşit: sütun = kare, satır = çeşit)
       assets/fx/underground_cracks/bursts.png (48x48 kare, 4 karede açılan ışınsal çatlak x 4 çeşit).
Kullanım (proje kökünden): python -I tools/gen_underground_cracks.py
"""
import math
import os
import random

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..'))
OUT = os.path.join(PROJECT, 'assets', 'fx', 'underground_cracks')
os.makedirs(OUT, exist_ok=True)

CORE = (54, 40, 30)          # yarığın dibi (koyu toprak)
WALL = (82, 60, 42)          # güney duvarı
LIP = (74, 112, 48)          # yırtılmış çimin koyu kenarı (zemin çimi ~126,176,84)
LIP_DIRT = (128, 100, 70)    # toprak zeminde dudak
CHIP = (112, 86, 60)         # kırıntı
CHIP_HI = (150, 122, 92)     # kırıntının açık yüzü (zemin toprağı)
FRAMES = 4
GROW = [0.3, 0.55, 0.8, 1.0]


def walk(rng, start, angle, steps, step_len, jitter):
    pts = [start]
    for _ in range(steps):
        angle += rng.uniform(-jitter, jitter)
        x, y = pts[-1]
        pts.append((x + math.cos(angle) * step_len, y + math.sin(angle) * step_len))
    return pts


def raster(pts):
    """noktalar arasını tek piksellik adımlarla doldur -> sıralı piksel yolu"""
    out = []
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        n = max(1, int(max(abs(x1 - x0), abs(y1 - y0))))
        for i in range(n):
            t = i / n
            p = (int(round(x0 + (x1 - x0) * t)), int(round(y0 + (y1 - y0) * t)))
            if not out or out[-1] != p:
                out.append(p)
    p = (int(round(pts[-1][0])), int(round(pts[-1][1])))
    if not out or out[-1] != p:
        out.append(p)
    return out


def put(a, x, y, c, alpha=255):
    h, w = a.shape[:2]
    if 0 <= x < w and 0 <= y < h:
        if alpha >= 255 or a[y, x, 3] == 0:
            a[y, x] = (c[0], c[1], c[2], alpha)
        else:
            sa = alpha / 255.0
            a[y, x, :3] = (np.array(c) * sa + a[y, x, :3] * (1 - sa)).astype(np.uint8)
            a[y, x, 3] = max(a[y, x, 3], alpha)


def draw_fissure(a, path, frac, width0, lip_col, rng_chips):
    """path: sıralı piksel yolu; frac: çizilen oran; width0: başta 2 (kalın), uca doğru 1"""
    n = max(2, int(len(path) * frac))
    seg = path[:n]
    total = len(path)
    # 1) dudak (kuzey/üst taraf) + gölge halesi - önce, çekirdek üstüne biner
    for i, (x, y) in enumerate(seg):
        put(a, x, y - 1, lip_col, 200)
        if i % 3 == 0:
            put(a, x + 1, y - 1, lip_col, 120)
    # 2) çekirdek + güney duvarı
    for i, (x, y) in enumerate(seg):
        thick = width0 if i < total * 0.55 else 1
        put(a, x, y, CORE)
        if thick >= 2:
            put(a, x, y + 1, WALL)
        else:
            put(a, x, y + 1, WALL, 150)
    # 3) kırıntılar (sadece tam boyda)
    if frac >= 0.99:
        for (x, y, up) in rng_chips:
            put(a, x, y, CHIP)
            put(a, x, y - 1 if up else y + 1, CHIP_HI, 220)


def crack_variant(seed, size=64):
    rng = random.Random(seed)
    c = size / 2
    ang = rng.uniform(0, math.pi)
    main = walk(rng, (c - math.cos(ang) * 22 + rng.uniform(-3, 3), c - math.sin(ang) * 22 + rng.uniform(-3, 3)), ang, rng.randint(7, 9), rng.uniform(5.0, 6.5), 0.55)
    paths = [(raster(main), 2)]
    mp = paths[0][0]
    for _ in range(rng.randint(1, 2)):
        k = rng.randint(len(main) // 3, len(main) - 3)
        bang = ang + rng.choice([-1, 1]) * rng.uniform(0.6, 1.1)
        b = walk(rng, main[k], bang, rng.randint(2, 4), rng.uniform(4.0, 5.5), 0.5)
        paths.append((raster(b), 1))
    chips = []
    for _ in range(rng.randint(3, 5)):
        x, y = mp[rng.randrange(len(mp))]
        chips.append((x + rng.choice([-3, -2, 2, 3]), y + rng.choice([-3, -2, 2, 3]), rng.random() < 0.5))
    return paths, chips


def burst_variant(seed, size=48):
    rng = random.Random(seed)
    c = size / 2
    count = rng.randint(5, 7)
    base = rng.uniform(0, math.tau)
    paths = []
    for i in range(count):
        a0 = base + i / count * math.tau + rng.uniform(-0.25, 0.25)
        pts = walk(rng, (c, c), a0, rng.randint(3, 4), rng.uniform(4.0, 6.0), 0.4)
        paths.append((raster(pts), 2 if i % 2 == 0 else 1))
    chips = [(int(c + math.cos(t) * r), int(c + math.sin(t) * r), rng.random() < 0.5)
             for t, r in ((rng.uniform(0, math.tau), rng.uniform(6, 16)) for _ in range(6))]
    return paths, chips


def sheet(variants, size):
    img = np.zeros((size * len(variants), size * FRAMES, 4), np.uint8)
    for row, (paths, chips) in enumerate(variants):
        for col, frac in enumerate(GROW):
            cell = np.zeros((size, size, 4), np.uint8)
            # merkezde küçük çökme (koyu toprak lekesi) - yalnız ışınsal çatlakta görünür, burada yok
            for path, w in paths:
                draw_fissure(cell, path, frac, w, LIP, chips)
            img[row * size:(row + 1) * size, col * size:(col + 1) * size] = cell
    return Image.fromarray(img, 'RGBA')


if __name__ == '__main__':
    cracks = [crack_variant(1000 + i) for i in range(8)]
    sheet(cracks, 64).save(os.path.join(OUT, 'cracks.png'))
    bursts = [burst_variant(2000 + i) for i in range(4)]
    b = sheet(bursts, 48)
    # ışınsal çatlağın merkezinde uzvun çıktığı küçük çukur (koyu toprak, 3x3 + kenar)
    arr = np.array(b)
    for row in range(4):
        for col in range(FRAMES):
            cx, cy = col * 48 + 24, row * 48 + 24
            for dx in range(-2, 3):
                for dy in range(-2, 3):
                    if abs(dx) + abs(dy) <= 3:
                        arr[cy + dy, cx + dx] = (*(CORE if abs(dx) + abs(dy) <= 1 else WALL), 255)
    Image.fromarray(arr, 'RGBA').save(os.path.join(OUT, 'bursts.png'))
    # önizleme: gerçek zemin tonları üstünde
    prev = Image.new('RGBA', (256 + 192 + 30, 512), (126, 176, 84, 255))
    prev.alpha_composite(Image.open(os.path.join(OUT, 'cracks.png')), (0, 0))
    half = Image.new('RGBA', (192, 192), (150, 122, 92, 255))
    half.alpha_composite(b)
    prev.alpha_composite(half, (286, 0))
    prev.resize((prev.width * 2, prev.height * 2), Image.NEAREST).convert('RGB').save(os.path.join(HERE, 'hide_bush_proto', 'out', 'cracks_preview.png'))
    print('tamam')
