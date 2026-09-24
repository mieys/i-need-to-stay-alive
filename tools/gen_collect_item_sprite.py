#!/usr/bin/env python3
""""Topla" gorevi objesi (mission_collect_item.gd) icin pixel-art spritesheet.

Kullanici bildirimi (2026-09-24): "Toplama gorevinde toplamamiz gereken seyler haritada gorunmuyor, toplanmasi icin
temsili birseyler uretilip haritada rasgele yerlerde olmasi gerekiyor" + genel kural "efektler pixel sanati olacak ve
spritesheete donusturulecek" (bkz. hafiza: 48x48 yogunluk, 1 texel detay, 1 px kontur). Eskiden obje her karede
draw_colored_polygon ile YUMUSAK kenarli bir elmas olarak ciziliyordu.

Tasarim: yerde duran turkuaz bir ruh kristali (13x19 sanat pikseli), 1 px koyu kontur, uc ton govde, dikey parlama
seridi kristal boyunca yukaridan asagi kayar + tepede bir kare yildizcik yanip soner (6 kare, dongu). Altta sabit
mini golge. Tek kare 24x32 sanat pikseli; oyun ici Sprite olcegi PixelDraw.TEXEL (1.212) - karakterlerle ayni yogunluk.

Cikti:
  assets/fx/mission_collect/crystal_sheet.png  (6 kare x 24x32)
  assets/fx/mission_collect/crystal_frames.tres (SpriteFrames, "idle" dongu)
Yeni PNG icin Godot'ta bir kez `--headless --import` gerekir.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_perf_sprite_fx_tres import write_sprite_frames  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "fx", "mission_collect")

W, H = 24, 32
FRAMES = 6

# o: kontur, d: koyu, m: orta, l: acik, h: parlama (seride gore degisir)
CRYSTAL = [
    "......o......",
    ".....olo.....",
    "....olmdo....",
    "....olmdo....",
    "...olmmddo...",
    "...olmmddo...",
    "..olmmmmddo..",
    "..olmmmmddo..",
    ".olmmmmmdddo.",
    ".olmmmmmdddo.",
    ".olmmmmmdddo.",
    ".olmmmmmdddo.",
    "..olmmmmddo..",
    "..olmmmmddo..",
    "...olmmddo...",
    "...olmmddo...",
    "....olmdo....",
    ".....odo.....",
    "......o......",
]
PAL = {
    "o": (12, 58, 62, 255),
    "d": (22, 128, 128, 255),
    "m": (58, 214, 196, 255),
    "l": (170, 255, 236, 255),
}
SHINE = (236, 255, 250, 255)
SPARK = (255, 255, 255, 255)
SHADOW_EDGE = (0, 0, 0, 70)
SHADOW_CORE = (0, 0, 0, 51)


def frame(i):
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = im.load()
    # mini zemin golgesi (PixelDraw.ground_shadow ile ayni dil: sert kenarli elips, ortasi koyu)
    cx, gy = W // 2, H - 3
    for dx in range(-6, 7):
        for dy in range(-1, 2):
            if (dx / 6.5) ** 2 + (dy / 1.6) ** 2 <= 1.0:
                px[cx + dx, gy + dy] = SHADOW_CORE if abs(dx) <= 3 and dy == 0 else SHADOW_EDGE
    ox = (W - len(CRYSTAL[0])) // 2
    oy = 5
    shine_row = int(round(-2 + (len(CRYSTAL) + 4) * i / FRAMES))  # parlama seridi yukaridan asagi kayar
    for y, row in enumerate(CRYSTAL):
        for x, ch in enumerate(row):
            if ch not in PAL:
                continue
            c = PAL[ch]
            if ch in "ml" and (y == shine_row or y == shine_row + 1) and x <= len(row) // 2 + 1:
                c = SHINE
            px[ox + x, oy + y] = c
    # tepe yildizcigi: 6 karenin 2'sinde arti, 1'inde nokta
    sx, sy = cx, oy - 3
    if i in (1, 2):
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            px[sx + dx, sy + dy] = SPARK if (dx, dy) == (0, 0) else PAL["l"]
    elif i == 3:
        px[sx, sy] = PAL["l"]
    # yan pariltilar (dongunun baska evresinde) - 1 texel
    if i == 4:
        px[ox - 1, oy + 7] = PAL["l"]
    if i == 5:
        px[ox + len(CRYSTAL[0]), oy + 11] = PAL["l"]
    return im


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    sheet = Image.new("RGBA", (W * FRAMES, H), (0, 0, 0, 0))
    for i in range(FRAMES):
        sheet.paste(frame(i), (i * W, 0))
    path = os.path.join(OUT_DIR, "crystal_sheet.png")
    sheet.save(path)
    print("wrote", path, sheet.size)
    write_sprite_frames(
        os.path.join(OUT_DIR, "crystal_frames.tres"),
        "res://assets/fx/mission_collect/crystal_sheet.png",
        W, H,
        [("idle", (0, 0), FRAMES, True, 8.0)],
    )


if __name__ == "__main__":
    main()
