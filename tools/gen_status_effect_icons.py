"""Skill barının üstündeki buff/debuff durum rozetleri (hud.gd StatusBar) için GERÇEK ikonlar - kullanıcı
isteği (2026-09-22): "bunun gibi yap [kılıç/kalkan/iksir referans görseli] gelen stat neyle ilgiliyse o tarz
görünsün" - eski tek harfli (G/H/İ/Y/K) kısaltmalar kaldırıldı, her efekt neyle ilgiliyse o SİLUETLE gösterilir:
  talon_stack (Güç)          -> KILIÇ (saldırı gücü)
  speed (Hız)                -> ŞİMŞEK (hız/haste)
  invuln (Yenilmezlik)       -> ALTIN KALKAN (hasar almama)
  bat (Yarasa Formu)         -> YARASA KANADI (mor)
  shield_slow (Kalkan Yavaş) -> ÇATLAK KALKAN + aşağı ok (kırmızı, debuff)
  burn (Yanma)               -> ALEV (İblis ateş topu, debuff)
48x48 sanat ızgarası (bkz. hafıza "Pixel density 48x48"), gen_shield_icons.py'daki AYNI küçük
yardımcı (Icon/poly/circle/rect/outline/dilate) deseni - o dosyaya bağımlı değil, kendi küçük kopyası.

Kullanım: python tools/gen_status_effect_icons.py
"""
import math
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from ui_kit_lib import hexc, mix, lighten, darken

OUTDIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'ui', 'status')
N = 48
OUTLINE = hexc('#1a1016')


def poly(points):
    im = Image.new('L', (N, N), 0)
    ImageDraw.Draw(im).polygon(points, fill=255)
    px = im.load()
    return {(x, y) for y in range(N) for x in range(N) if px[x, y] > 127}


def circle(cx, cy, r):
    return {(x, y) for y in range(N) for x in range(N) if math.hypot(x + 0.5 - cx, y + 0.5 - cy) <= r}


def rect(x0, y0, x1, y1):
    return {(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)}


def dilate(m, n=1):
    for _ in range(n):
        m = m | {(x + dx, y + dy) for (x, y) in m for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))}
    return m


class Icon:
    def __init__(self):
        self.p = {}

    def fill(self, cells, color):
        for c in cells:
            self.p[c] = color

    def fill_fn(self, cells, fn):
        for (x, y) in cells:
            self.p[(x, y)] = fn(x, y)

    def outline(self, cells, color=OUTLINE):
        for c in dilate(cells, 1) - cells:
            if c not in self.p:
                self.p[c] = color

    def image(self):
        im = Image.new('RGBA', (N, N), (0, 0, 0, 0))
        px = im.load()
        for (x, y), c in self.p.items():
            if 0 <= x < N and 0 <= y < N:
                px[x, y] = c
        return im


def sword():
    """Saldırı gücü (Talon "Güç" pasifi) - gümüş kılıç, altın kabza."""
    ic = Icon()
    blade = poly([(24, 4), (27, 8), (27, 30), (24, 34), (21, 30), (21, 8)])
    ic.outline(blade)
    ic.fill_fn(blade, lambda x, y: hexc('#f0f2f6') if x < 24 else hexc('#aab2c0'))
    ic.p[(23, 8)] = hexc('#ffffff')
    guard = rect(15, 30, 32, 33)
    ic.outline(guard)
    ic.fill_fn(guard, lambda x, y: hexc('#ffd867') if y < 32 else hexc('#a86a1a'))
    grip = rect(21, 34, 26, 41)
    ic.outline(grip)
    ic.fill_fn(grip, lambda x, y: hexc('#6b4424') if (x + y) % 2 == 0 else hexc('#523018'))
    pommel = circle(24, 44, 3.4)
    ic.outline(pommel)
    ic.fill_fn(pommel, lambda x, y: hexc('#ffe58a') if (x - 24) + (y - 44) < 0 else hexc('#b5811c'))
    return ic


def lightning():
    """Hız artışı - şimşek."""
    ic = Icon()
    bolt = poly([(28, 4), (16, 26), (23, 26), (18, 44), (34, 20), (25, 20)])
    ic.outline(bolt)
    ic.fill_fn(bolt, lambda x, y: hexc('#fff7b8') if (x + y) < 46 else hexc('#7fd8ff'))
    halo = dilate(bolt, 2) - bolt
    for (x, y) in halo:
        if (x + y) % 2 == 0:
            ic.p.setdefault((x, y), hexc('#bdeeff'))
    return ic


def gold_shield():
    """Yenilmezlik (Ruhani Yetenek Kalkan) - parlak altın-beyaz kalkan."""
    ic = Icon()
    M = poly([(24, 5), (39, 10), (40, 24), (35, 36), (24, 44), (13, 36), (8, 24), (9, 10)])
    ic.outline(M)

    def body(x, y):
        c = hexc('#fff3c2') if (x - 24) + (y - 22) < -4 else (hexc('#ffd867') if (x - 24) + (y - 22) < 10 else hexc('#c98f1f'))
        return c

    ic.fill_fn(M, body)
    boss = circle(24, 21, 5.5)
    ic.outline(boss, hexc('#8a5a10'))
    ic.fill_fn(boss, lambda x, y: hexc('#fffbe6') if (x - 24) + (y - 21) < -1 else hexc('#ffd867'))
    for i in range(8):
        a = i * math.pi / 4
        px_, py_ = 24 + math.cos(a) * 15, 22 + math.sin(a) * 15
        p = (int(px_), int(py_))
        if p in M:
            ic.p[p] = hexc('#ffffff')
    return ic


def bat_wing():
    """Yarasa Formu (Vampir Çocuk R) - mor yarasa."""
    ic = Icon()
    body = poly([(24, 16), (28, 20), (28, 30), (24, 34), (20, 30), (20, 20)])
    l_wing = poly([(20, 20), (4, 10), (8, 22), (2, 26), (12, 28), (20, 30)])
    r_wing = poly([(28, 20), (44, 10), (40, 22), (46, 26), (36, 28), (28, 30)])
    ears = poly([(21, 16), (19, 8), (23, 15)]) | poly([(27, 16), (29, 8), (25, 15)])
    whole = body | l_wing | r_wing | ears
    ic.outline(whole)
    ic.fill_fn(l_wing, lambda x, y: hexc('#8a4fd1') if (x + y) % 3 else hexc('#6a35ab'))
    ic.fill_fn(r_wing, lambda x, y: hexc('#8a4fd1') if (x + y) % 3 else hexc('#6a35ab'))
    ic.fill(ears, hexc('#5a2d8f'))
    ic.fill_fn(body, lambda x, y: hexc('#3d1a63') if (x - 24) + (y - 24) < 0 else hexc('#2a1046'))
    for (x, y) in ((22, 24), (26, 24)):
        ic.p[(x, y)] = hexc('#ff5a5a')
    return ic


def cracked_shield():
    """Kalkan yenilemesi yavaş (debuff) - donuk/çatlak kalkan + aşağı ok."""
    ic = Icon()
    M = poly([(24, 6), (37, 11), (38, 23), (34, 34), (24, 41), (14, 34), (10, 23), (11, 11)])
    ic.outline(M)
    ic.fill_fn(M, lambda x, y: hexc('#7c8290') if (x - 24) + (y - 20) < -2 else hexc('#4a4e5a'))
    crack = [(24, 8), (22, 14), (25, 19), (21, 25), (26, 31), (22, 37)]
    for i in range(len(crack) - 1):
        x0, y0 = crack[i]
        x1, y1 = crack[i + 1]
        steps = max(abs(x1 - x0), abs(y1 - y0), 1)
        for s in range(steps + 1):
            f = s / steps
            p = (int(round(x0 + (x1 - x0) * f)), int(round(y0 + (y1 - y0) * f)))
            ic.p[p] = hexc('#14151a')
            if (p[0] + 1, p[1]) in M:
                ic.p[(p[0] + 1, p[1])] = hexc('#1c1e24')
    arrow = poly([(24, 30), (31, 37), (27, 37), (27, 45), (21, 45), (21, 37), (17, 37)])
    ic.outline(arrow, hexc('#5a0e0e'))
    ic.fill_fn(arrow, lambda x, y: hexc('#ff8f80') if x < 24 else hexc('#d9463a'))
    return ic


def flame():
    """Yanma (debuff - Iblis ates topu, 2026-09-24): turuncu-sari alev, icte beyaz cekirdek."""
    ic = Icon()
    outer = poly([(24, 3), (31, 13), (36, 22), (37, 32), (33, 40), (24, 45), (15, 40), (11, 32), (12, 22), (17, 14), (20, 20)])
    ic.outline(outer)
    ic.fill_fn(outer, lambda x, y: hexc('#e04a12') if y > 38 or x < 15 or x > 34 else hexc('#ff7a1c'))
    mid = poly([(24, 14), (30, 25), (31, 34), (24, 41), (17, 34), (18, 26)])
    ic.fill(mid, hexc('#ffb83a'))
    core = poly([(24, 24), (28, 32), (24, 38), (20, 32)])
    ic.fill(core, hexc('#fff3c2'))
    return ic


def build():
    os.makedirs(OUTDIR, exist_ok=True)
    icons = {
        'talon_stack': sword(),
        'speed': lightning(),
        'invuln': gold_shield(),
        'bat': bat_wing(),
        'shield_slow': cracked_shield(),
        'burn': flame(),
    }
    for k, ic in icons.items():
        ic.image().save(os.path.join(OUTDIR, '%s.png' % k))
    sheet = Image.new('RGBA', (N * 4 * len(icons) + 10 * (len(icons) + 1), N * 4 + 20), (40, 30, 22, 255))
    for i, k in enumerate(icons):
        big = icons[k].image().resize((N * 4, N * 4), Image.NEAREST)
        sheet.alpha_composite(big, (10 + i * (N * 4 + 10), 10))
    return sheet


if __name__ == '__main__':
    sh = build()
    if len(sys.argv) > 1:
        sh.save(sys.argv[1])
    print('status effect icons ->', os.path.abspath(OUTDIR))
