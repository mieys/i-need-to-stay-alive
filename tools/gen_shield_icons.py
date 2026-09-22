"""Kalkan türü ikonları (48x48 piksel-sanat, x1 kaydedilir; oyunda x2/x3 NEAREST ile gösterilir) -> assets/ui/shields/type_*.png

Kullanıcı isteği (2026-09-21): "kalkanlar için kalkan türleri ve çalışma biçimleriyle uyumlu kalkan ikonları". Tasarım, player.gd SHIELD_TYPES ile eşleşir:
  standart : dengeli/klasik (power 150, emilim %65)          -> mavi çelik kalan, gümüş kenar, orta göbek
  enerji   : düşük güç ama HIZLI yenilenir (delay 4.5, regen 12) -> parlak turkuaz kristal + şimşek, enerji kıvılcımları
  kale     : en yüksek güç/emilim (180, %75), yavaş yenilenir    -> taş kule kalkanı: mazgallı üst, tuğla, kale kapısı, altın kenar
  savas    : savaşta bile durmadan yenilenir (always_regen)    -> kızıl yuvarlak kalkan, çelik kenar dikenleri, çapraz kılıçlar
"""
import math
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from ui_kit_lib import hexc, mix, lighten, darken

OUTDIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'ui', 'shields')
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


def erode(m, n=1):
    for _ in range(n):
        m = {(x, y) for (x, y) in m if all((x + dx, y + dy) in m for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))}
    return m


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


def rim_body(ic, M, rim_light, rim_dark, body_fn, rim=3, cx=24, cy=24):
    """Kenar bandını aydınlık/karanlık (sol-üst ışık), iç gövdeyi body_fn ile boyar."""
    inner = erode(M, rim)
    for (x, y) in M - inner:
        lit = (x - cx) + (y - cy) < 0
        outer = (x, y) not in erode(M, 1)
        c = rim_light if lit else rim_dark
        if outer:
            c = lighten(c, 0.25) if lit else darken(c, 0.22)
        ic.p[(x, y)] = c
    ic.fill_fn(inner, body_fn)
    return inner


def standart():
    ic = Icon()
    M = poly([(8, 6), (24, 3), (40, 6), (41, 24), (36, 35), (24, 45), (12, 35), (7, 24)])
    ic.outline(M)
    blue, blue_l, blue_d = hexc('#3f76d0'), hexc('#5b93ea'), hexc('#2c5399')

    def body(x, y):
        c = blue_l if x < 22 else (blue if x < 27 else blue_d)
        if y > 34 and abs(x - 24) < (46 - y) * 0.9:
            c = darken(c, 0.12)
        return c

    inner = rim_body(ic, M, hexc('#e9edf5'), hexc('#8f99ad'), body)
    # üst kenar perçinleri
    for (x, y) in ((11, 8), (37, 8)):
        ic.p[(x, y)] = hexc('#ffe58a')
        ic.p[(x + 1, y)] = hexc('#c9891c')
    # orta göbek
    boss = circle(24, 21, 6.2)
    ic.outline(boss, hexc('#1e3a70'))
    ic.fill_fn(boss, lambda x, y: hexc('#dfe4ee') if (x - 24) + (y - 21) < -1 else hexc('#8f99ad'))
    ic.fill(circle(24, 21, 2.4), hexc('#ffd55a'))
    ic.p[(23, 20)] = hexc('#fff3b0')
    # ince dikey vurgu çizgisi (kalkanın formu)
    for y in range(29, 40):
        ic.p[(24, y)] = lighten(blue_l, 0.25) if (24, y) in inner else ic.p.get((24, y))
    return ic


def enerji():
    ic = Icon()
    M = poly([(24, 2), (41, 11), (41, 29), (24, 46), (7, 29), (7, 11)])
    ic.outline(M)
    core = hexc('#12305a')
    inner = rim_body(ic, M, hexc('#aef6ff'), hexc('#1f86a3'), lambda x, y: mix(core, hexc('#2b6fb8'), max(0.0, 1.0 - math.hypot(x - 24, y - 24) / 15.0)), rim=3)
    # parıltı: şimşeğin çevresinde dither halo
    bolt = poly([(28, 8), (16, 26), (23, 26), (19, 40), (33, 20), (25, 20)])
    halo = dilate(bolt, 3) - bolt
    for (x, y) in halo:
        if (x + y) % 2 == 0 and (x, y) in inner:
            ic.p[(x, y)] = hexc('#4fd8f0')
    ic.outline(bolt, hexc('#a86a0a'))
    ic.fill_fn(bolt, lambda x, y: hexc('#fff7b8') if (x + y) < 46 else hexc('#ffd94a'))
    # enerji kıvılcımları (artı işaretleri)
    for (sx, sy) in ((12, 17), (36, 31), (13, 33), (35, 15)):
        for (dx, dy) in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            if (sx + dx, sy + dy) in inner:
                ic.p[(sx + dx, sy + dy)] = hexc('#c8fbff') if (dx, dy) == (0, 0) else hexc('#5fdcf0')
    # üst kristal ışıltısı
    ic.p[(24, 4)] = hexc('#ffffff')
    ic.p[(23, 5)] = hexc('#e8ffff')
    return ic


def kale():
    ic = Icon()
    pts = [(8, 4), (15, 4), (15, 9), (21, 9), (21, 4), (27, 4), (27, 9), (33, 9), (33, 4), (40, 4),
           (40, 28), (32, 40), (24, 46), (16, 40), (8, 28)]
    M = poly(pts)
    ic.outline(M)
    stone, stone_l, stone_d = hexc('#8b91a0'), hexc('#a9afbd'), hexc('#666b7a')

    def body(x, y):
        c = stone
        row = (y - 10) // 6
        off = 0 if row % 2 == 0 else 5
        if (y - 10) % 6 == 5:
            c = stone_d  # tuğla derzi (yatay)
        elif (x + off) % 10 == 0:
            c = stone_d  # tuğla derzi (dikey)
        elif (x + off) % 10 == 1 and (y - 10) % 6 == 0:
            c = stone_l
        if x < 18:
            c = mix(c, stone_l, 0.18)
        elif x > 30:
            c = mix(c, stone_d, 0.25)
        return c

    inner = rim_body(ic, M, hexc('#ffd867'), hexc('#a9691a'), body, rim=3, cx=24, cy=24)
    # mazgal (üst) taş rengi: rim altın olduğu için mazgal ağızlarını koyulaştır
    for x in range(16, 21):
        for y in range(4, 9):
            if (x, y) in M and (x, y) not in ic.p:
                pass
    # kale kapısı (kemerli)
    gate = rect(19, 24, 29, 38) | circle(24, 24, 5.4)
    gate = {(x, y) for (x, y) in gate if y >= 19 and 19 <= x <= 29}
    gate &= inner
    ic.outline(gate, hexc('#2a1a12'))
    ic.fill_fn(gate, lambda x, y: hexc('#6b4424') if x % 4 != 0 else hexc('#503219'))
    # kapı demirleri + altın perçinler
    for y in (28, 34):
        for x in range(19, 30):
            if (x, y) in gate:
                ic.p[(x, y)] = hexc('#3a3f4c')
    for (x, y) in ((21, 28), (27, 28), (21, 34), (27, 34)):
        ic.p[(x, y)] = hexc('#ffd867')
    # kemer taşı (üstte)
    ic.p[(24, 19)] = hexc('#cfd3de')
    ic.p[(23, 19)] = hexc('#a9afbd')
    ic.p[(25, 19)] = hexc('#a9afbd')
    return ic


def savas():
    ic = Icon()
    cx, cy = 24, 25
    M = circle(cx, cy, 20.4)
    # kenar dikenleri (çelik)
    spikes = set()
    for ang in (-90, -45, 0, 45, 90, 135, 180, 225):
        a = math.radians(ang)
        tip = (cx + math.cos(a) * 24.5, cy + math.sin(a) * 24.5)
        b1 = (cx + math.cos(a + 0.22) * 19.5, cy + math.sin(a + 0.22) * 19.5)
        b2 = (cx + math.cos(a - 0.22) * 19.5, cy + math.sin(a - 0.22) * 19.5)
        spikes |= poly([tip, b1, b2])
    S = M | spikes
    ic.outline(S)
    ic.fill_fn(spikes - M, lambda x, y: hexc('#dfe4ee') if (x - cx) + (y - cy) < 0 else hexc('#8f99ad'))
    red, red_l, red_d = hexc('#c2352b'), hexc('#e0574a'), hexc('#8c231f')

    def body(x, y):
        d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
        c = red_l if (x - cx) + (y - cy) < -6 else (red if (x - cx) + (y - cy) < 8 else red_d)
        if 13.4 < d < 14.6:
            c = darken(c, 0.25)  # iç halka
        return c

    rim_body(ic, M, hexc('#e9edf5'), hexc('#8f99ad'), body, rim=3, cx=cx, cy=cy)
    # çapraz kılıçlar
    def blade(x0, y0, x1, y1, w=1.6):
        dx, dy = x1 - x0, y1 - y0
        L = math.hypot(dx, dy)
        nx, ny = -dy / L * w, dx / L * w
        return poly([(x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)])

    b1 = blade(14, 14, 34, 34)
    b2 = blade(34, 14, 14, 34)
    for b in (b1, b2):
        ic.outline(b, hexc('#4a1210'))
    for b in (b1, b2):
        ic.fill_fn(b, lambda x, y: hexc('#f4f7fb') if (x + y) % 2 == 0 else hexc('#c5ccd8'))
    # kabzalar (altın çapraz kılıç korumaları)
    for (gx, gy, horiz) in ((17, 17, False), (31, 17, True), (17, 31, True), (31, 31, False)):
        pass
    for (x, y) in ((16, 20), (17, 19), (20, 16), (19, 17), (28, 16), (29, 17), (32, 20), (31, 19), (16, 28), (17, 29), (20, 32), (19, 31), (28, 32), (29, 31), (32, 28), (31, 29)):
        ic.p[(x, y)] = hexc('#ffd867')
    # orta göbek
    boss = circle(cx, cy, 3.6)
    ic.outline(boss, hexc('#5a3a08'))
    ic.fill_fn(boss, lambda x, y: hexc('#fff0a8') if (x - cx) + (y - cy) < 0 else hexc('#e0a628'))
    return ic


def build():
    os.makedirs(OUTDIR, exist_ok=True)
    icons = {'standart': standart(), 'enerji': enerji(), 'kale': kale(), 'savas': savas()}
    for k, ic in icons.items():
        ic.image().save(os.path.join(OUTDIR, 'type_%s.png' % k))
    # önizleme (x4, koyu zemin)
    sheet = Image.new('RGBA', (N * 4 * 4 + 50, N * 4 + 20), (40, 30, 22, 255))
    for i, k in enumerate(icons):
        big = icons[k].image().resize((N * 4, N * 4), Image.NEAREST)
        sheet.alpha_composite(big, (10 + i * (N * 4 + 10), 10))
    return sheet


if __name__ == '__main__':
    sh = build()
    if len(sys.argv) > 1:
        sh.save(sys.argv[1])
    print('shield icons ->', os.path.abspath(OUTDIR))
