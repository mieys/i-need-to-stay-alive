"""Saganak havasinin yildirim efektleri (pixel sprite sayfalari) -> assets/fx/storm/

Kullanici istegi (2026-09-25): "yeni hava durumu: saganak yagis ... rasgele aralıklarla rasgele konumlara yildirim
dusmeli, yildirim dustugu yerdeki yaratiklara ciddi hasar vermeli ve dusmeden once dusecegi yerde hafif elektriklenme
olmali ki dikkatli olalim ... herseyin optimize olmasi gerekiyor". Her parca TEK AnimatedSprite2D (bkz. fx_storm_*.gd).

Olcek: 1 sanat pikseli = 1 dunya birimi (dunyada duran efektler, harita karolariyla ayni piksel; karakterin sanat
pikseli ~1.12 dunya birimi). Yildirimin etki alani weather_storm.gd STRIKE_RADIUS x STRIKE_RADIUS*STRIKE_Y_RATIO elipsi
(56 x 34) - uyari halkasi BIREBIR bu elipsi cizer ki oyuncu gordugu alandan kacabilsin.

  warning (128x80, 12 kare, 16 fps, dongu): yerde titreyen kesik elips (etki alani) + icinde ziplayan minik elektrik
           kivilcimlari + hafif dither'li dolgu. Script dusus yaklastikca parlakligi/titremeyi artirir.
  bolt    (72x230, 9 kare, 24 fps, tek sefer): gokten zemine zikzak yildirim - beyaz cekirdek, mavi hale, 2 dal;
           ikinci bir parlama (yeniden vurus titremesi) ile soner.
  impact  (150x90, 10 kare, 20 fps, tek sefer): zeminde beyaz-sari patlama + disa yayilan elips dalga + savrulan kivilcim.
  scorch  (56x34, tek kare): yanik izi - script birkac saniyede soldurur.

Calistir: python tools/gen_storm_fx.py
"""

import math
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx", "storm")
RES = "res://assets/fx/storm/"

WHITE = (255, 255, 255)
PALE_Y = (255, 248, 196)
PALE_B = (206, 228, 255)
BLUE = (140, 190, 255)
DEEP = (70, 110, 230)
VIOLET = (170, 140, 255)
SCORCH = (34, 26, 30)
EMBER = (255, 160, 70)

STRIKE_RX = 56
STRIKE_RY = 34


def qa(a):
    for lv in (1.0, 0.8, 0.55, 0.3):
        if a >= lv - 0.12:
            return lv
    return 0.0


def put(img, x, y, col, a=1.0, over=False):
    x, y = int(round(x)), int(round(y))
    if not (0 <= x < img.width and 0 <= y < img.height):
        return
    a = qa(a)
    if a <= 0:
        return
    if not over and img.getpixel((x, y))[3] >= int(255 * a):
        return
    img.putpixel((x, y), col + (int(255 * a),))


def line(img, x0, y0, x1, y1, col, a=1.0, over=False):
    n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for i in range(n + 1):
        t = i / max(1, n)
        put(img, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, col, a, over)


def ellipse(img, cx, cy, rx, ry, col, a, dash=None, phase=0.0):
    n = int(2 * math.pi * max(rx, ry) * 1.5)
    for i in range(n):
        ang = 2 * math.pi * i / n
        if dash is not None and ((ang + phase) % dash) > dash * 0.6:
            continue
        put(img, cx + rx * math.cos(ang), cy + ry * math.sin(ang), col, a)


def zigzag(rng, x0, y0, x1, y1, segs, jitter):
    pts = [(x0, y0)]
    for i in range(1, segs):
        t = i / segs
        pts.append((x0 + (x1 - x0) * t + rng.uniform(-jitter, jitter), y0 + (y1 - y0) * t + rng.uniform(-2, 2)))
    pts.append((x1, y1))
    return pts


def sheet_save(name, frames, anim, loop, fps):
    os.makedirs(OUT, exist_ok=True)
    w, h = frames[0].size
    s = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        s.paste(f, (i * w, 0))
    s.save(os.path.join(OUT, name + "_sheet.png"), optimize=True)
    write_sprite_frames(os.path.join(OUT, name + "_frames.tres"), RES + name + "_sheet.png", w, h,
                        [(anim, (0, 0), len(frames), loop, fps)])


# ---------------------------------------------------------------- warning
def warning():
    W, H = 128, 80
    cx, cy = 64, 40
    frames = []
    for f in range(12):
        rng = random.Random(100 + f)
        img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        # hafif dither'li dolgu (satirlar her karede kayar - titresim)
        for y in range(H):
            for x in range(W):
                if ((x - cx) / STRIKE_RX) ** 2 + ((y - cy) / STRIKE_RY) ** 2 <= 1.0 and (x + y + f) % 4 == 0:
                    put(img, x, y, BLUE, 0.3)
        # etki alani siniri: kesik, donen elips + ic halka
        ellipse(img, cx, cy, STRIKE_RX, STRIKE_RY, PALE_B, 0.8, dash=0.26, phase=f * 0.05)
        ellipse(img, cx, cy, STRIKE_RX - 1, STRIKE_RY - 1, BLUE, 0.55, dash=0.26, phase=f * 0.05)
        ellipse(img, cx, cy, STRIKE_RX * 0.35, STRIKE_RY * 0.35, PALE_Y, 0.55 if f % 2 == 0 else 0.3)
        # ziplayan minik kivilcimlar (3-5 piksellik zikzak)
        for _ in range(5):
            a = rng.uniform(0, 2 * math.pi)
            r = math.sqrt(rng.uniform(0.05, 0.9))
            x = cx + STRIKE_RX * r * math.cos(a)
            y = cy + STRIKE_RY * r * math.sin(a)
            pts = zigzag(rng, x, y, x + rng.uniform(-6, 6), y - rng.uniform(3, 8), 3, 2.0)
            for (xa, ya), (xb, yb) in zip(pts, pts[1:]):
                line(img, xa, ya, xb, yb, WHITE if rng.random() < 0.5 else PALE_Y, 1.0, over=True)
        frames.append(img)
    sheet_save("warning", frames, "loop", True, 16)


# ---------------------------------------------------------------- bolt
def bolt():
    W, H = 72, 230
    gx, gy = 36, 222
    rng = random.Random(7)
    main = zigzag(rng, gx + rng.uniform(-12, 12), 0, gx, gy, 16, 9.0)
    br1_i, br2_i = 5, 10
    br1 = zigzag(rng, main[br1_i][0], main[br1_i][1], main[br1_i][0] + 22, main[br1_i][1] + 44, 5, 4.0)
    br2 = zigzag(rng, main[br2_i][0], main[br2_i][1], main[br2_i][0] - 20, main[br2_i][1] + 36, 4, 4.0)
    # kare: (ne kadari cizili 0..1, parlaklik, dallar, titreme tohumu)
    plan = [(0.45, 0.8, False), (1.0, 1.0, True), (1.0, 1.0, True), (1.0, 0.55, False), (1.0, 1.0, True),
            (1.0, 0.55, True), (1.0, 0.3, False), (1.0, 0.3, False), (0.0, 0.0, False)]
    frames = []
    for f, (reach, bright, branches) in enumerate(plan):
        img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        if reach > 0:
            jr = random.Random(50 + f)
            pts = [(x + (jr.uniform(-1.2, 1.2) if 0 < i < len(main) - 1 else 0), y) for i, (x, y) in enumerate(main)]
            n_draw = max(2, int(len(pts) * reach))
            segs = list(zip(pts[:n_draw], pts[1:n_draw]))
            paths = [segs]
            if branches:
                paths.append(list(zip(br1, br1[1:])))
                paths.append(list(zip(br2, br2[1:])))
            for k, path in enumerate(paths):
                core = WHITE if bright >= 0.8 else PALE_B
                halo_a = bright * (0.8 if k == 0 else 0.55)
                thick = (k == 0)  # ana govde 2 piksel beyaz cekirdek, dallar 1 piksel
                for (xa, ya), (xb, yb) in path:
                    for ox in ((-3, 4) if thick else (-2, 2)):
                        line(img, xa + ox, ya, xb + ox, yb, DEEP, halo_a * 0.55)
                    for ox in ((-2, -1, 2, 3) if thick else (-1, 1)):
                        line(img, xa + ox, ya, xb + ox, yb, BLUE, halo_a)
                for (xa, ya), (xb, yb) in path:
                    line(img, xa, ya, xb, yb, core, bright, over=True)
                    if thick:
                        line(img, xa + 1, ya, xb + 1, yb, PALE_Y if bright >= 0.8 else PALE_B, bright, over=True)
        frames.append(img)
    sheet_save("bolt", frames, "strike", False, 24)


# ---------------------------------------------------------------- impact
def impact():
    W, H = 150, 90
    cx, cy = 75, 50
    frames = []
    rng = random.Random(3)
    sparks = [(rng.uniform(0, 2 * math.pi), rng.uniform(40, 80)) for _ in range(16)]
    for f in range(10):
        t = f / 9
        img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        # disa yayilan dalga (etki alanindan biraz buyuk)
        r = 10 + 56 * (1 - (1 - t) ** 2)
        ellipse(img, cx, cy, r, r * STRIKE_RY / STRIKE_RX, PALE_B if t < 0.5 else BLUE, 1.0 - t)
        ellipse(img, cx, cy + 1, r, r * STRIKE_RY / STRIKE_RX, BLUE, (1.0 - t) * 0.55)
        # cekirdek patlama + isinlar (ilk kareler)
        if t < 0.5:
            core = 12 * (1 - t * 1.6)
            for y in range(H):
                for x in range(W):
                    d = math.hypot((x - cx), (y - cy) * 1.4)
                    if d <= core:
                        put(img, x, y, WHITE if d < core * 0.55 else PALE_Y, 1.0 if d < core * 0.55 else 0.8)
            for k in range(8):
                a = k * math.pi / 4 + 0.2
                l = 18 * (1 - t * 1.5)
                line(img, cx, cy, cx + l * math.cos(a), cy + l * 0.6 * math.sin(a), PALE_Y, 0.8 * (1 - t * 1.6))
        # savrulan kivilcimlar
        for a, spd in sparks:
            d = spd * t * 0.6 + 6
            x = cx + d * math.cos(a)
            y = cy + d * 0.6 * math.sin(a) - 14 * math.sin(math.pi * min(1.0, t * 1.2))
            put(img, x, y, WHITE if t < 0.4 else PALE_Y, 1.0 - t)
            put(img, x - math.cos(a), y - 0.6 * math.sin(a), BLUE, (1.0 - t) * 0.55)
        frames.append(img)
    sheet_save("impact", frames, "burst", False, 20)


def scorch():
    W, H = 56, 34
    cx, cy = 28, 17
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    rng = random.Random(11)
    for y in range(H):
        for x in range(W):
            d = ((x + 0.5 - cx) / 24.0) ** 2 + ((y + 0.5 - cy) / 14.0) ** 2
            if d <= 1.0:
                a = 0.8 if d < 0.35 else (0.55 if d < 0.7 else (0.3 if (x + y) % 2 == 0 else 0.0))
                put(img, x, y, SCORCH, a)
    # catlak cizgileri + kor
    for k in range(6):
        a = k * math.pi / 3 + rng.uniform(-0.3, 0.3)
        pts = zigzag(rng, cx, cy, cx + 20 * math.cos(a), cy + 12 * math.sin(a), 4, 2.0)
        for (xa, ya), (xb, yb) in zip(pts, pts[1:]):
            line(img, xa, ya, xb, yb, (18, 12, 16), 1.0, over=True)
    for _ in range(7):
        put(img, cx + rng.uniform(-14, 14), cy + rng.uniform(-8, 8), EMBER, 1.0, over=True)
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, "scorch.png"))
    print("wrote", os.path.join(OUT, "scorch.png"))


if __name__ == "__main__":
    warning()
    bolt()
    impact()
    scorch()
