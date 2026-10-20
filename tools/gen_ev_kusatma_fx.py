#!/usr/bin/env python3
"""EV KUSATMASI + ACILIS piksel sanati (2026-10-19, madde 313). Kullanim (repo kokunden): python tools/gen_ev_kusatma_fx.py

Yazar: assets/fx/ev_kusatma/
  catlak.png  : kutuk duvar CATLAKLARI, 6 sekil x 3 asama (satir = sekil, sutun = asama; hucre 32x32, 1 piksel = 1 dunya px,
                ic mekan karolariyla ayni yogunluk). Ana yarik kutuklari capraz keser, lif boyunca yatay kiymiklar dallanir;
                asama 0 kisa, 2 tam + dallar. Renkler duvarin kendi paleti (koyu ek yeri 48,17,13 / golge 76,44,38 / acik kenar).
  dokuntu.png : tavandan dokulen parcalar: 8 parca (tahta kiymigi / siva / tas, koyu konturlu), hucre 8x8.
  toz.png     : yere dusen parcanin toz bulutu, 5 kare, hucre 14x10.
  toz_akisi.png: tavandan suzulen ince toz/kum akisi, 6 kare, hucre 6x40 (dongu).
  korku.png   : karakterlerin ustunde KORKU balonu (karakter piksel yogunlugunda), 3 tur x hucre 16x16:
                0 = korkmus yuz (golge cizgileri, iri gozler, titrek agiz), 1 = unlem, 2 = ter damlalari.
Hepsi duz renk + sert kenar (dither/yumusak isik yok - kullanici kurali).
"""
import os
import random

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx", "ev_kusatma")

DEEP = (48, 17, 13, 255)
DARK = (76, 44, 38, 255)
SHADE = (106, 65, 54, 235)
LITE = (188, 136, 92, 230)
WOOD_L = (178, 121, 74, 255)
WOOD_M = (140, 90, 68, 255)
WOOD_D = (98, 60, 46, 255)
PLASTER = (196, 178, 150, 255)
PLASTER_D = (150, 132, 110, 255)
STONE = (128, 122, 116, 255)
STONE_D = (88, 82, 78, 255)
DUST = (206, 184, 150)


def put(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


def crack_path(rng, cell):
    """Ana yarik: ust ortadan asagi capraz, her adim 1 piksel; yatay kiymik dallari ayri listede (lif boyunca)."""
    x = cell // 2 + rng.randint(-5, 5)
    y = 3
    pts = [(x, y)]
    drift = rng.choice([-1, 1])
    while y < cell - 4:
        r = rng.random()
        if r < 0.55:
            y += 1
        elif r < 0.85:
            x += drift
            y += 1
        else:
            x += drift
        if rng.random() < 0.18:
            drift = -drift
        x = max(3, min(cell - 4, x))
        pts.append((x, y))
    branches = []
    for _ in range(rng.randint(3, 5)):
        i = rng.randint(len(pts) // 5, len(pts) - 2)
        bx, by = pts[i]
        d = rng.choice([-1, 1])
        n = rng.randint(3, 7)
        br = []
        for k in range(1, n + 1):
            yy = by + (1 if rng.random() < 0.2 and k > 1 else 0)
            br.append((bx + d * k, yy))
            by = yy
        branches.append((i / len(pts), br))
    return pts, branches


def draw_crack(img, ox, oy, pts, branches, frac):
    n = max(2, int(len(pts) * frac))
    main = pts[:n]
    for (x, y) in main:
        put(img, ox + x + 1, oy + y, LITE) ## alt-sag acik kenar (kirik tahtanin isik alan agzi)
    for (x, y) in main:
        put(img, ox + x - 1, oy + y, SHADE)
    for i, (x, y) in enumerate(main):
        put(img, ox + x, oy + y, DEEP)
        if 0.3 < i / n < 0.75 and frac > 0.6: ## ortasi daha genis acilir
            put(img, ox + x - 1, oy + y, DARK)
    for start, br in branches:
        if start > frac - 0.05 or frac < 0.5:
            continue
        keep = br if frac >= 1.0 else br[:max(2, len(br) // 2)]
        for (x, y) in keep:
            put(img, ox + x, oy + y + 1, LITE)
            put(img, ox + x, oy + y, DARK if (x + y) % 3 else DEEP)


def gen_cracks():
    cell = 32
    img = Image.new("RGBA", (cell * 3, cell * 6))
    for s in range(6):
        rng = random.Random(4100 + s * 17)
        pts, branches = crack_path(rng, cell)
        for stage, frac in enumerate((0.45, 0.75, 1.0)):
            draw_crack(img, stage * cell, s * cell, pts, branches, frac)
    img.save(os.path.join(OUT, "catlak.png"))


# Parcalar (8x8 hucre): "o" = koyu kontur (ahsap zeminde secilsin diye), L/M/D tahta, P/p siva, S/s tas.
CHUNKS = [
    [" ooo ", "oLLMo", "oMMDo", " ooo "],
    ["oo   ", "oLMo ", " oMDo", "  oo "],
    [" oo  ", "oPPpo", "oPppo", " ooo "],
    ["oooo", "oPpo", "oooo"],
    [" ooo ", "oSSso", "oSsso", " ooo "],
    ["ooo", "oSo", "ooo"],
    ["oooooo", "oLMMDo", "oooooo"],
    [" oo ", "oPPo", "oPpo", " oo "],
]
CHUNK_COL = {"L": WOOD_L, "M": WOOD_M, "D": WOOD_D, "P": PLASTER, "p": PLASTER_D, "S": STONE, "s": STONE_D,
             "o": (52, 30, 24, 255)}


def gen_debris():
    cell = 8
    img = Image.new("RGBA", (cell * len(CHUNKS), cell))
    for i, rows in enumerate(CHUNKS):
        oy = (cell - len(rows)) // 2
        ox = (cell - max(len(r) for r in rows)) // 2
        for y, r in enumerate(rows):
            for x, ch in enumerate(r):
                if ch != " ":
                    put(img, i * cell + ox + x, oy + y, CHUNK_COL[ch])
    img.save(os.path.join(OUT, "dokuntu.png"))


def gen_dust():
    w, h, frames = 14, 10, 5
    img = Image.new("RGBA", (w * frames, h))
    rng = random.Random(77)
    puffs = [(rng.uniform(-1, 1), rng.uniform(-0.2, 0.15)) for _ in range(9)]
    for f in range(frames):
        t = (f + 1) / frames
        alpha = int(210 * (1.0 - t) ** 0.8)
        for (dx, dy) in puffs:
            cx = w / 2 + dx * (2 + 5 * t)
            cy = h - 3 + dy * 6 * t - 2.5 * t
            r = 1 if t < 0.5 else 2
            for yy in range(-r, r + 1):
                for xx in range(-r, r + 1):
                    if xx * xx + yy * yy <= r * r:
                        put(img, f * w + int(round(cx + xx)), int(round(cy + yy)), DUST + (alpha,))
    img.save(os.path.join(OUT, "toz.png"))


def gen_dust_stream():
    w, h, frames = 6, 40, 6
    img = Image.new("RGBA", (w * frames, h))
    rng = random.Random(9)
    grains = [(rng.randint(1, w - 2), rng.uniform(0, h), rng.random() < 0.35) for _ in range(22)]
    for f in range(frames):
        for (x, y0, big) in grains:
            y = (y0 + f * h / frames) % h
            a = int(235 * (1.0 - y / h * 0.5))
            put(img, f * w + x, int(y), DUST + (a,))
            if big:
                put(img, f * w + x, int(y) + 1, DUST + (a,))
    img.save(os.path.join(OUT, "toz_akisi.png"))


OUTL = (40, 28, 30, 255)
FILL = (246, 240, 228, 255)
FILL_S = (214, 204, 190, 255)
BLUE = (70, 118, 206, 255)
DROP = (126, 186, 240, 255)
DROP_H = (220, 240, 255, 255)
RED = (214, 58, 48, 255)
BLACK = (24, 18, 20, 255)


def bubble(img, ox):
    """15x12 yuvarlatilmis balon + alt ortada 3 piksel kuyruk (16x16 hucre)."""
    for y in range(12):
        for x in range(15):
            corner = (x in (0, 14) and y in (0, 11)) or (x in (0, 14) and y in (1, 10)) and False
            if (x in (0, 14) and y in (0, 1, 10, 11)) or (x in (1, 13) and y in (0, 11)):
                continue
            edge = x == 0 or x == 14 or y == 0 or y == 11 or (x in (1, 13) and y in (1, 10))
            put(img, ox + x, y, OUTL if edge else (FILL_S if y >= 9 else FILL))
    for i, (x, y) in enumerate([(6, 11), (7, 11), (8, 11), (6, 12), (7, 12), (7, 13)]):
        put(img, ox + x, y, OUTL)
    put(img, ox + 7, 11, FILL_S)
    put(img, ox + 7, 12, FILL_S if False else OUTL)


def gen_emotes():
    img = Image.new("RGBA", (16 * 3, 16))
    for i in range(3):
        bubble(img, i * 16)
    o = 0 ## korkmus yuz: alin golge cizgileri + halka gozler + acik "O" agiz
    for x in (3, 5, 7, 9, 11):
        put(img, o + x, 1, BLUE)
        put(img, o + x, 2, BLUE)
    ring = ((0, 0), (1, 0), (2, 0), (0, 1), (2, 1), (0, 2), (1, 2), (2, 2))
    for ex in (3, 9):
        for (dx, dy) in ring:
            put(img, o + ex + dx, 4 + dy, BLACK)
    for (dx, dy) in ring:
        put(img, o + 6 + dx, 7 + dy, BLACK)
    put(img, o + 7, 8, RED)
    o = 16 ## unlem
    for y in range(2, 7):
        put(img, o + 7, y, RED)
        put(img, o + 8, y, RED)
    put(img, o + 7, 8, RED)
    put(img, o + 8, 8, RED)
    o = 32 ## ter damlalari
    for (bx, by) in ((4, 3), (9, 5)):
        put(img, o + bx + 1, by, DROP)
        put(img, o + bx, by + 1, DROP)
        put(img, o + bx + 1, by + 1, DROP)
        put(img, o + bx + 2, by + 1, DROP)
        for dx in range(4):
            put(img, o + bx - 1 + dx, by + 2, DROP)
        put(img, o + bx, by + 3, DROP)
        put(img, o + bx + 1, by + 3, DROP)
        put(img, o + bx + 2, by + 3, DROP)
        put(img, o + bx, by + 2, DROP_H)
    img.save(os.path.join(OUT, "korku.png"))


def main():
    os.makedirs(OUT, exist_ok=True)
    gen_cracks()
    gen_debris()
    gen_dust()
    gen_dust_stream()
    gen_emotes()
    print("yazildi:", ", ".join(sorted(os.listdir(OUT))))


if __name__ == "__main__":
    main()
