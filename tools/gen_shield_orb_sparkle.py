#!/usr/bin/env python3
"""Kalkan orbu parıltısını (scripts/shield_orb_drop.gd, eskiden orb başına 12 Hz'de ~70 draw_rect + 480 hücre taraması)
sprite sheet'e çevirir. Katkı (ADD) karışımı için kareler önceden toplanmıştır: piksel rengi = sum(rgb * alfa), alfa 1 (toplam > 0 ise).
Döngü 48 adım (12 FPS = 4 sn): yıldız dönemi 16, cam parlaması dönemi 24, halenin nabzı 24 (eskiden ~25,1 - dikişsiz döngü için).
Kullanım: python tools/gen_shield_orb_sparkle.py  -> assets/pickups/shield_orb/sparkle_t1.png, sparkle_t2.png (48 kare, 26x26, yatay şerit)
"""
import math
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "pickups", "shield_orb")

FRAMES = 48
CELL = 26
CENTER = CELL // 2
GLINT_PERIOD = 24
SPARKLE_PERIOD = 16
PULSE_PERIOD = 24
STAGES = [1, 2, 3, 3, 2, 1]
WHITE = (1.0, 1.0, 1.0, 1.0)
BLUE = (0.45, 0.75, 1.0, 0.9)
GOLD = (1.0, 0.85, 0.4, 0.9)
HALO = (0.35, 0.65, 1.0)


def render(tier, step):
    r = 10.0 if tier >= 2 else 8.0
    acc = [[[0.0, 0.0, 0.0] for _ in range(CELL)] for _ in range(CELL)]

    def add(x, y, rgb, a):
        ix, iy = int(x) + CENTER, int(y) + CENTER
        if 0 <= ix < CELL and 0 <= iy < CELL:
            for i in range(3):
                acc[iy][ix][i] += rgb[i] * a

    pulse = 0.5 + 0.5 * math.sin(2.0 * math.pi * step / PULSE_PERIOD)
    reach = int(r) + 3
    for y in range(-reach, reach):
        for x in range(-reach, reach):
            d = math.hypot(x + 0.5, y + 0.5)
            if r - 0.2 < d <= r + 2.2:
                inner = d <= r + 1.0
                add(x, y, HALO, (0.30 if inner else 0.13) * (0.45 + 0.55 * pulse))
    g = step % GLINT_PERIOD
    if g < 7:
        k = int(-r + (2 * r) * g / 6.0)  # lerpf + int() ayni (Godot int() sifira dogru keser)
        for y in range(-int(r), int(r)):
            for x in range(-int(r), int(r)):
                if (x + y == k or x + y == k + 1) and math.hypot(x + 0.5, y + 0.5) < r - 1.6:
                    add(x, y, (1.0, 1.0, 1.0), 0.55)
    spots = [(-0.72, -0.78), (0.95, -0.25), (0.35, 0.92)]
    if tier >= 2:
        spots.append((-1.0, 0.4))
    for i, s in enumerate(spots):
        local = (step + i * (SPARKLE_PERIOD // len(spots)) + i * 3) % SPARKLE_PERIOD
        if local >= len(STAGES):
            continue
        stage = STAGES[local]
        cx, cy = math.floor(s[0] * r), math.floor(s[1] * r)
        tint = GOLD if (tier >= 2 and i % 2 == 1) else BLUE
        if stage >= 2:
            col = WHITE if stage >= 3 else tint
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                add(cx + dx, cy + dy, col[:3], col[3])
        if stage >= 3:
            for dx, dy in ((-2, 0), (2, 0), (0, -2), (0, 2)):
                add(cx + dx, cy + dy, tint[:3], tint[3])
        add(cx, cy, WHITE[:3], 1.0)
    img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    for y in range(CELL):
        for x in range(CELL):
            c = acc[y][x]
            if c[0] + c[1] + c[2] > 0.004:
                img.putpixel((x, y), tuple(min(255, int(round(v * 255))) for v in c) + (255,))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    for tier in (1, 2):
        sheet = Image.new("RGBA", (CELL * FRAMES, CELL), (0, 0, 0, 0))
        for step in range(FRAMES):
            sheet.paste(render(tier, step), (step * CELL, 0))
        path = os.path.join(OUT, "sparkle_t%d.png" % tier)
        sheet.save(path)
        print("wrote", path)


if __name__ == "__main__":
    main()
