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
import math
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


# ------------------------------------------------------------------------------------------------ toplama parıltısı
## Kullanici istegi (2026-09-24): "toplama gorevinde birsey toplarken topladigimiz sey saydamlasarak yok olmak yerine
## toplama efektine benzer bir parilti falan olsun" - kristal beyaz parlar, buyuk turkuaz 4 kollu yildiza donusur,
## cevresine 6 kucuk parilti sacilip yukari suzulerek soner. 40x40 sanat pikseli, 10 kare (tek seferlik, 20 fps).
PW = PH = 40
P_FRAMES = 10
P_CX, P_CY = 20, 20  ## kristal govdesinin merkezi (mission_collect_item.gd offset'i buna gore)


def _star(px, cx, cy, arm, core, edge):
    for d in range(-arm, arm + 1):
        c = core if abs(d) <= max(1, arm // 3) else (PAL["l"] if abs(d) < arm else edge)
        for (x, y) in ((cx + d, cy), (cx, cy + d)):
            if 0 <= x < PW and 0 <= y < PH:
                px[x, y] = c
    for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
        x, y = cx + dx, cy + dy
        if arm >= 4 and 0 <= x < PW and 0 <= y < PH:
            px[x, y] = PAL["l"]


def pickup_frame(i):
    im = Image.new("RGBA", (PW, PH), (0, 0, 0, 0))
    px = im.load()
    ox = P_CX - len(CRYSTAL[0]) // 2
    oy = P_CY - len(CRYSTAL) // 2
    if i <= 1:
        ## kristal silueti beyaza/acik turkuaza parlar (i=1'de 1 px sisip dagilmaya baslar)
        for y, row in enumerate(CRYSTAL):
            for x, ch in enumerate(row):
                if ch not in PAL:
                    continue
                c = SPARK if i == 0 and ch != "o" else (SHINE if ch in "ml" else PAL["l"])
                if i == 1 and ch == "o":
                    c = PAL["m"]
                px[ox + x, oy + y] = c
        if i == 1:
            _star(px, P_CX, P_CY, 5, SPARK, PAL["m"])
        return im
    k = i - 2  ## 0..7
    ## merkez yildiz: buyuk basla, kucul
    arm = [9, 7, 5, 3, 2, 1, 0, 0][k]
    if arm > 0:
        _star(px, P_CX, P_CY - k, arm, SPARK, PAL["m"])
    ## 6 parilti: disa acilip yukari suzulur, "+" -> nokta -> sonar
    for s in range(6):
        a = s * math.pi / 3.0 + 0.3
        r = 5 + k * 2.2
        x = int(round(P_CX + math.cos(a) * r))
        y = int(round(P_CY + math.sin(a) * r * 0.8 - k * 1.6))
        if k >= 6 and s % 2 == 1:
            continue
        if k <= 3:
            for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
                if 0 <= x + dx < PW and 0 <= y + dy < PH:
                    px[x + dx, y + dy] = SPARK if (dx, dy) == (0, 0) else PAL["l"]
        elif 0 <= x < PW and 0 <= y < PH:
            px[x, y] = PAL["l"] if k <= 5 else PAL["m"]
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
    psheet = Image.new("RGBA", (PW * P_FRAMES, PH), (0, 0, 0, 0))
    for i in range(P_FRAMES):
        psheet.paste(pickup_frame(i), (i * PW, 0))
    ppath = os.path.join(OUT_DIR, "pickup_sheet.png")
    psheet.save(ppath)
    print("wrote", ppath, psheet.size)
    write_sprite_frames(
        os.path.join(OUT_DIR, "pickup_frames.tres"),
        "res://assets/fx/mission_collect/pickup_sheet.png",
        PW, PH,
        [("pickup", (0, 0), P_FRAMES, False, 20.0)],
    )
    preview = os.environ.get("COLLECT_PREVIEW_DIR")
    if preview:
        bg = Image.new("RGBA", psheet.size, (70, 110, 60, 255))
        bg.alpha_composite(psheet)
        bg.resize((psheet.width * 4, psheet.height * 4), Image.NEAREST).save(os.path.join(preview, "pickup_preview.png"))


if __name__ == "__main__":
    main()
