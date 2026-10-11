"""2026-10-12 prototipleri: Şovalye Adam pasif rework - "canı %40'un altına düşünce aldığı hasar %20 azalır" aktifken görünecek LOOPLU efekt.
4 prototip (kullanıcı seçecek; seçilen sonra spritesheet/FX sahnesine çevrilir):
  A) Demir Kabuk     - gövdeyi saran 1 px çelik kontur + üstünden yukarı süpüren metalik parıltı
  B) Kızıl Yemin     - ayak altında kor kırmızısı nabız halkası, üstünde dönen altın rün çizgileri + yükselen 3 kıvılcım
  C) Yörünge Plakaları - gövdenin çevresinde dönen 4 küçük çelik plaka (arkadakiler karakterin ARKASINDA, öndekiler önünde)
  D) Altın Mühür     - başın üstünde hafifçe sallanan küçük altın kalkan simgesi + ara sıra parıltı, ayak altında soluk altın halka
Hepsi gerçek çimen üstünde, karakter 48x48 karesiyle AYNI doku yoğunluğunda (1 sanat px = 1 texel), 16 karelik döngü.
Çıktı: out/sovalye_low_hp_{A..D}.gif (x4 büyük, döngü) + out/sovalye_low_hp_sheet.png (her prototipten 4 kare).
Kullanım (proje kökünden): python -I tools/proto_20261012/gen_sovalye_low_hp.py
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(HERE, 'out')
os.makedirs(OUT, exist_ok=True)

N = 16  ## döngü kare sayısı
W = H = 96  ## tuval (karakter karesi 48x48, ortada)
OX = OY = 24  ## karakter karesinin tuvaldeki sol-üst köşesi
FEET_Y = OY + 40  ## karakterin ayak çizgisi (gövde y 8..40)
HEAD_Y = OY + 8
CX = OX + 24  ## gövde ekseni
BODY_Y = (HEAD_Y + FEET_Y) // 2

GRASS = (126, 176, 84)
STEEL = [(28, 30, 42), (78, 84, 102), (138, 146, 166), (198, 206, 220), (250, 252, 255)]
BLOOD = [(56, 8, 14), (124, 18, 28), (194, 38, 48), (238, 98, 96), (255, 198, 196)]
EMBER = [(64, 16, 16), (140, 34, 24), (206, 76, 30), (246, 146, 48), (255, 214, 120)]
GOLD = [(84, 56, 8), (178, 120, 22), (236, 184, 52), (255, 226, 120), (255, 249, 214)]


def font(sz):
    for c in (r'C:\Windows\Fonts\segoeui.ttf', r'C:\Windows\Fonts\arial.ttf'):
        if os.path.exists(c):
            return ImageFont.truetype(c, sz)
    return ImageFont.load_default()


def grass_bg():
    img = Image.new('RGBA', (W, H), GRASS + (255,))
    rng = random.Random(4)
    px = img.load()
    for _ in range(W * H // 14):
        x, y = rng.randrange(W), rng.randrange(H)
        px[x, y] = rng.choice([(116, 166, 76), (134, 184, 92), (110, 158, 72)]) + (255,)
    return img


BG = grass_bg()
SHEET = Image.open(os.path.join(PROJECT, 'assets', 'characters', 'sovalye', 'sheets', 'idle.png')).convert('RGBA')


def char_frame(i):
    col = (i * 4 // N) % 4  ## idle döngüsü (4 kare) 16 kareye yayılır
    return SHEET.crop((col * 48, 0, col * 48 + 48, 48))


def body_mask(fr):
    m = np.zeros((H, W), dtype=bool)
    a = np.array(fr)[:, :, 3] > 0
    m[OY:OY + 48, OX:OX + 48] = a
    return m


class Layer:
    """tuval boyunda RGBA piksel katmanı; px() tam piksel koyar."""

    def __init__(self):
        self.a = np.zeros((H, W, 4), dtype=np.uint8)

    def px(self, x, y, c, alpha=255):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < W and 0 <= y < H:
            self.a[y, x] = (c[0], c[1], c[2], alpha)

    def img(self):
        return Image.fromarray(self.a, 'RGBA')


def ellipse_pts(cx, cy, rx, ry, steps=240):
    for i in range(steps):
        t = i / steps * math.tau
        yield t, cx + math.cos(t) * rx, cy + math.sin(t) * ry


def compose(back, fr, front):
    img = BG.copy()
    # gölge (karakter altı, koyu elips) - oyundaki piksel ayak gölgesi
    sh = Layer()
    for _, x, y in ellipse_pts(CX, FEET_Y - 1, 9, 3, 200):
        for dx in (-2, -1, 0, 1, 2):
            sh.px(x + dx * 0.5, y, (40, 60, 30), 90)
    img.alpha_composite(sh.img())
    if back is not None:
        img.alpha_composite(back.img() if isinstance(back, Layer) else back)
    canvas = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    canvas.paste(fr, (OX, OY))
    img.alpha_composite(canvas)
    if front is not None:
        img.alpha_composite(front.img() if isinstance(front, Layer) else front)
    return img


def ramp(p, k):
    return p[max(0, min(4, int(k)))]


# ------------------------------------------------------------------ A) Demir Kabuk
def proto_a(i):
    fr = char_frame(i)
    m = body_mask(fr)
    t = i / N
    # 1 px dış kontur + parıltı bandı: bant gövde boyunca aşağıdan yukarı süpürür (ilk yarı), ikinci yarıda kontur nabzı
    ring = Layer()
    ys, xs = np.where(m)
    mset = set(zip(xs.tolist(), ys.tolist()))
    pulse = 0.5 + 0.5 * math.sin(t * math.tau)
    band_y = FEET_Y - (FEET_Y - HEAD_Y + 6) * (t * 2 % 1.0) if t < 0.5 else None
    for (x, y) in mset:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if (nx, ny) not in mset:
                near_band = band_y is not None and abs(ny - band_y) <= 2
                k = 2.7 + pulse * 1.0 + (1.6 if near_band else 0.0)
                ring.px(nx, ny, ramp(STEEL, k), 255)
    out = np.array(fr).copy()
    if band_y is not None:  ## gövde pikselleri bandın içinde açılır (metal parlaması)
        for y in range(OY, OY + 48):
            d = abs(y - band_y)
            if d <= 2:
                for x in range(OX, OX + 48):
                    if m[y, x]:
                        r, g, b, a = (int(v) for v in out[y - OY, x - OX])
                        mix = 0.45 if d < 1 else 0.28
                        out[y - OY, x - OX] = (int(r + (235 - r) * mix), int(g + (240 - g) * mix), int(b + (255 - b) * mix), a)
    return compose(None, Image.fromarray(out, 'RGBA'), ring)


# ------------------------------------------------------------------ B) Kızıl Yemin
def proto_b(i):
    fr = char_frame(i)
    t = i / N
    back = Layer()
    cy = FEET_Y + 1
    pulse = 0.5 + 0.5 * math.sin(t * math.tau)
    rx, ry = 19 + pulse * 2, 7 + pulse * 0.8
    for ang, x, y in ellipse_pts(CX, cy, rx, ry, 360):
        back.px(x, y, ramp(BLOOD, 1.6 + pulse * 1.2), 255)
    # iç ince halka
    for ang, x, y in ellipse_pts(CX, cy, rx - 4, ry - 1.6, 260):
        back.px(x, y, ramp(BLOOD, 1.0 + pulse), 150)
    # dönen altın rün çizgileri (8 kısa çizgi)
    for k in range(8):
        a0 = t * math.tau + k * math.tau / 8
        for s in (-0.07, 0.0, 0.07):
            x = CX + math.cos(a0 + s) * (rx - 2)
            y = cy + math.sin(a0 + s) * (ry - 0.8)
            back.px(x, y, ramp(GOLD, 2.4 + (1 if k % 2 == 0 else 0)), 255)
    front = Layer()
    # yükselen 3 kıvılcım (2x2 çekirdek, kor tonları, yükselirken küçülüp söner)
    for k in range(3):
        u = (t + k / 3.0) % 1.0
        sx = CX - 10 + k * 10 + math.sin((u + k) * math.tau) * 2
        sy = FEET_Y - 2 - u * 30
        size = 2 if u < 0.55 else 1
        col = ramp(EMBER, 3.6 - u * 2.4)
        for dx in range(size):
            for dy in range(size):
                front.px(sx + dx, sy + dy, col, 255)
    return compose(back, fr, front)


# ------------------------------------------------------------------ C) Yörünge Plakaları
def plate(layer, x, y, depth_front, tilt):
    """7x9 küçük çelik plaka (kalkan biçimli), altın 1 px kontur; tilt 0..1 dönerken daralır."""
    w = max(3, int(round(7 * (0.45 + 0.55 * abs(math.cos(tilt))))))
    pts = []
    for yy in range(9):
        ww = w if yy < 6 else max(1, w - (yy - 5) * 2)
        for xx in range(-(ww // 2), ww // 2 + 1):
            pts.append((xx, yy - 4, ww))
    for (xx, yy, ww) in pts:
        edge = abs(xx) == ww // 2 or yy == -4 or yy == 4 or (yy >= 2 and abs(xx) >= ww // 2 - 0)
        inner_k = 2.3 if depth_front else 1.4
        col = ramp(GOLD, 1.8 if depth_front else 1.0) if edge else ramp(STEEL, inner_k + (0.9 if xx < 0 else 0.0))
        layer.px(x + xx, y + yy, col, 255)


def proto_c(i):
    fr = char_frame(i)
    t = i / N
    back, front = Layer(), Layer()
    for k in range(4):
        a = t * math.tau + k * math.tau / 4
        x = CX + math.cos(a) * 21
        y = BODY_Y + 2 + math.sin(a) * 7
        if math.sin(a) < 0:  ## karakterin arkasında
            plate(back, x, y, False, a)
        else:
            plate(front, x, y, True, a)
    return compose(back, fr, front)


# ------------------------------------------------------------------ D) Altın Mühür
SHIELD = [  ## 9x11 mini kalkan: 0 boş, 1 kontur, 2 koyu, 3 orta, 4 açık, 5 parlak
    "011111110",
    "123333321",
    "134444431",
    "134555431",
    "134555431",
    "134444431",
    "123444321",
    ".1233321.",
    "..12321..",
    "...121...",
    "....1....",
]


def proto_d(i):
    fr = char_frame(i)
    t = i / N
    back, front = Layer(), Layer()
    # ayak altında soluk altın halka (nabız)
    pulse = 0.5 + 0.5 * math.sin(t * math.tau)
    for ang, x, y in ellipse_pts(CX, FEET_Y + 1, 16 + pulse * 1.5, 6, 300):
        back.px(x, y, ramp(GOLD, 1.0 + pulse * 0.9), 170)
    # başın üstünde sallanan kalkan simgesi
    bob = math.sin(t * math.tau) * 1.6
    sx0 = CX - 4
    sy0 = HEAD_Y - 17 + bob
    for yy, row in enumerate(SHIELD):
        for xx, ch in enumerate(row):
            if ch == '.' or ch == '0':
                continue
            k = int(ch)
            col = (20, 14, 6) if k == 1 else ramp(GOLD, k - 1 + (0.6 if (pulse > 0.8 and k >= 3) else 0.0))
            front.px(sx0 + xx, sy0 + yy, col, 255)
    # ara sıra parıltı (artı biçimli, iki kare)
    if i in (5, 6, 11):
        px0, py0 = (sx0 + 2, sy0 + 2) if i != 11 else (sx0 + 7, sy0 + 6)
        r = 2 if i == 6 else 1
        for d in range(-r, r + 1):
            front.px(px0 + d, py0, ramp(GOLD, 4), 255)
            front.px(px0, py0 + d, ramp(GOLD, 4), 255)
    return compose(back, fr, front)


PROTOS = [
    ('A', 'Demir Kabuk', proto_a),
    ('B', 'Kızıl Yemin', proto_b),
    ('C', 'Yörünge Plakaları', proto_c),
    ('D', 'Altın Mühür', proto_d),
]


def main():
    panels = []
    for key, name, fn in PROTOS:
        frames = [fn(i) for i in range(N)]
        big = [f.resize((W * 4, H * 4), Image.NEAREST).convert('P', palette=Image.ADAPTIVE, colors=128) for f in frames]
        big[0].save(os.path.join(OUT, 'sovalye_low_hp_%s.gif' % key), save_all=True, append_images=big[1:], duration=83, loop=0, disposal=1)
        panels.append((key + ') ' + name, [frames[j] for j in (0, 4, 8, 12)]))
    pw, ph = W * 2, H * 2
    title_h = 30
    sheet = Image.new('RGB', (4 * (pw + 8) + 8, 4 * (ph + title_h + 8) + 8), (24, 24, 28))
    d = ImageDraw.Draw(sheet)
    f = font(20)
    for r, (title, frs) in enumerate(panels):
        y = 8 + r * (ph + title_h + 8)
        d.text((10, y + 3), title, fill=(240, 236, 220), font=f)
        for c, fr in enumerate(frs):
            sheet.paste(fr.resize((pw, ph), Image.NEAREST).convert('RGB'), (8 + c * (pw + 8), y + title_h))
    sheet.save(os.path.join(OUT, 'sovalye_low_hp_sheet.png'))
    print('tamam:', os.listdir(OUT))


if __name__ == '__main__':
    main()
