#!/usr/bin/env python3
"""Mermi arkasi PARCACIK izleri - pixel-art spritesheet'ler (scripts/fx_particle_trail.gd bunlari cizer).

Kullanici istekleri (2026-09-24):
  - "fuze atesnlendiginde arkasinda partikuller biraksin fuze oldugu hissedilsin ... pixel efekt hazirla fakat sonrasinda
    spritesheete donustur yoksa performans kaybi yasariz"  -> "missile" (Fisek)
  - "ates asasi, buz asasi atesnlendiginde attigi atisin arkasinda kendine uygun partikuller olsun atis hissiyati
    hissedilebilsin diye ... pixel tarzda yapip spritesheete donustur"  -> "fire", "ice"

Her stil: bir parcacigin omru boyunca 8 kare (sutunlar) x 2 varyant (satirlar), kare 12x12 sanat pikseli
(1 sanat pikseli = PixelDraw.TEXEL dunya birimi, 48x48 karakter yogunlugu - bkz. hafiza "Pixel density 48x48").
  missile: beyaz-sicak kivilcim -> sari/turuncu alev -> kirmizi -> koyu duman -> acik gri duman -> seyrek dagilan duman
  fire:    sari-beyaz kor -> turuncu alev dili -> kirmizi kor -> kararan kul zerresi (dumansiz, ates asasinin toplariyla
           ayni sicak paleti, kucuk ve hizli sonen)
  ice:     beyaz parlak buz kristali (+ bicimli yildiz) -> buz mavisi elmas -> kucuk kar tanesi kirintilari -> soluk sis
Oyun ici tek bir Node tum parcaciklari bu sayfalardan cizer (parcacik basina node yok).

Kullanim (repo kokunden):  python tools/gen_projectile_trail_fx.py
Cikti: assets/fx/projectile_trails/{missile,fire,ice}_sheet.png  (96x24)
Yeni PNG'ler icin Godot'ta bir kez `--headless --import` gerekir.
"""
import math
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "fx", "projectile_trails")

CELL = 12
FRAMES = 8
VARIANTS = 2


def hash01(a, b, c):
    x = (a * 73856093) ^ (b * 19349663) ^ (c * 83492791)
    x = (x ^ (x >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((x ^ (x >> 16)) & 0xFFFF) / 65535.0


def blob(im, cx, cy, r, fill, rim=None, core=None, core_r=0.0, dither=0.0, variant=0, frame=0, wobble=0.35):
    """Pikselli yuvarlak leke; rim = 1 px koyu kenar, core = sicak cekirdek, dither = deterministik bosaltma orani."""
    px = im.load()
    for y in range(CELL):
        for x in range(CELL):
            dx = x + 0.5 - cx
            dy = y + 0.5 - cy
            wob = wobble * math.sin(math.atan2(dy, dx) * 3.0 + variant * 2.1)
            d = math.hypot(dx, dy)
            if d > r + wob:
                continue
            if dither > 0.0 and hash01(x, y, variant * 31 + frame) < dither:
                continue
            c = fill
            if rim is not None and d > r + wob - 1.0:
                c = rim
            if core is not None and d <= core_r:
                c = core
            px[x, y] = c


def put(im, x, y, c):
    if 0 <= x < CELL and 0 <= y < CELL:
        im.putpixel((x, y), c)


# ------------------------------------------------------------------------------------------------ missile (Fisek)
M_HOT = (255, 250, 222, 255)
M_YELLOW = (255, 214, 90, 255)
M_ORANGE = (255, 138, 38, 255)
M_RED = (196, 58, 30, 255)
M_SMOKE_D = (84, 78, 80, 255)
M_SMOKE_M = (132, 126, 126, 255)
M_SMOKE_L = (184, 180, 176, 255)


def missile_frame(f, v):
    im = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    c = CELL / 2.0
    ox = 0.4 if v == 1 else 0.0
    if f == 0:
        blob(im, c + ox, c, 1.6, M_YELLOW, core=M_HOT, core_r=1.0, variant=v, frame=f)
    elif f == 1:
        blob(im, c + ox, c, 2.4, M_ORANGE, core=M_YELLOW, core_r=1.4, variant=v, frame=f)
    elif f == 2:
        blob(im, c + ox, c, 3.0, M_ORANGE, rim=M_RED, core=M_YELLOW, core_r=1.0, variant=v, frame=f)
    elif f == 3:
        blob(im, c + ox, c, 3.4, M_SMOKE_D, core=M_RED, core_r=1.6, variant=v, frame=f)
    elif f == 4:
        blob(im, c + ox, c - 0.3, 3.8, M_SMOKE_M, rim=M_SMOKE_D, variant=v, frame=f)
    elif f == 5:
        blob(im, c + ox, c - 0.6, 4.2, M_SMOKE_L, rim=M_SMOKE_M, dither=0.18, variant=v, frame=f)
    elif f == 6:
        blob(im, c + ox, c - 0.9, 4.6, M_SMOKE_L, dither=0.45, variant=v, frame=f)
    else:
        blob(im, c + ox, c - 1.2, 4.8, M_SMOKE_L, dither=0.75, variant=v, frame=f)
    return im


# ------------------------------------------------------------------------------------------------ fire (Ates Asasi)
F_WHITE = (255, 247, 205, 255)
F_YELLOW = (255, 206, 70, 255)
F_ORANGE = (255, 128, 30, 255)
F_RED = (214, 52, 24, 255)
F_DARK = (122, 30, 18, 255)
F_ASH = (70, 44, 38, 255)


FIRE_ART = [
    ["", "", "", "", "", ".....y", "....ywy", ".....y"],
    ["", "", "", ".....y", "....yy", "....ywy", "...oyyyo", "...oyyyo", "....ooo"],
    ["", "......o", ".....oo", ".....oy", "....oyyo", "...oyywyo", "...oyyyyo", "...royyor", "....roor", ".....rr"],
    ["", ".......r", "......ro", ".....roo", "....rooyr", "....royyr", "....rooor", ".....rrr"],
    ["", "", "", ".....r", "....ror", ".....r"],
    ["", "", ".....d", "....drd", ".....d"],
    ["", "......d", ".....a"],
    [".....a"],
]
FIRE_PAL = {"w": F_WHITE, "y": F_YELLOW, "o": F_ORANGE, "r": F_RED, "d": F_DARK, "a": F_ASH}


def fire_frame(f, v):
    """Kucuk alev dili (elle cizilmis): kivilcim -> buyuyen, ucu kivrilan alev -> kizaran, kopan alev -> kor -> kul.
    Varyant 1 yatay aynali."""
    im = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    for y, row in enumerate(FIRE_ART[f]):
        for x, ch in enumerate(row):
            if ch in FIRE_PAL:
                put(im, (CELL - 1 - x) if v == 1 else x, y + 1, FIRE_PAL[ch])
    return im


# ------------------------------------------------------------------------------------------------ ice (Buz Asasi)
I_WHITE = (250, 255, 255, 255)
I_PALE = (196, 240, 255, 255)
I_CYAN = (112, 206, 250, 255)
I_BLUE = (62, 138, 214, 255)
I_MIST = (205, 232, 246, 150)


def ice_frame(f, v):
    """Buz kristali: parlak + yildiz -> elmas -> kucuk kar kirintilari -> soluk sis."""
    im = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    c = 6
    if f == 0:
        for d in range(-2, 3):
            put(im, c + d, c, I_PALE)
            put(im, c, c + d, I_PALE)
        put(im, c, c, I_WHITE)
    elif f == 1:
        ## 4 kollu parlak yildiz + capraz kucuk isinlar
        for d in range(-3, 4):
            put(im, c + d, c, I_CYAN if abs(d) == 3 else I_PALE)
            put(im, c, c + d, I_CYAN if abs(d) == 3 else I_PALE)
        for d in (-1, 1):
            put(im, c + d, c + d, I_PALE)
            put(im, c + d, c - d, I_PALE)
        put(im, c, c, I_WHITE)
    elif f in (2, 3):
        ## elmas kristal (konturlu), ikinci karede biraz kuculur
        r = 3 if f == 2 else 2
        for y in range(-r, r + 1):
            w = r - abs(y)
            for x in range(-w, w + 1):
                edge = abs(x) == w
                put(im, c + x, c + y, I_BLUE if edge else (I_WHITE if (x == -1 and y == -1) else I_CYAN))
    elif f == 4:
        ## kristal kar tanelerine ayrilir
        pts = [(-2, -1), (2, 1), (0, 2)] if v == 0 else [(-1, 2), (2, -1), (-2, -2)]
        for (x, y) in pts:
            put(im, c + x, c + y, I_PALE)
        put(im, c, c, I_CYAN)
    elif f == 5:
        pts = [(-3, 0), (3, 2), (1, -3), (-1, 3)] if v == 0 else [(-3, -2), (2, 3), (3, -1), (0, -3)]
        for (x, y) in pts:
            put(im, c + x, c + y, I_PALE if (x + y) % 2 else I_CYAN)
        blob(im, c + 0.5, c + 0.5, 2.0, I_MIST, dither=0.5, variant=v, frame=f)
    elif f == 6:
        blob(im, c + 0.5, c + 0.5, 3.0, I_MIST, dither=0.65, variant=v, frame=f)
        put(im, c + (3 if v else -3), c + 3, I_PALE)
    else:
        blob(im, c + 0.5, c + 0.5, 3.6, I_MIST, dither=0.85, variant=v, frame=f)
    return im


STYLES = {"missile": missile_frame, "fire": fire_frame, "ice": ice_frame}


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    previews = []
    for name, fn in STYLES.items():
        sheet = Image.new("RGBA", (CELL * FRAMES, CELL * VARIANTS), (0, 0, 0, 0))
        for v in range(VARIANTS):
            for f in range(FRAMES):
                sheet.paste(fn(f, v), (f * CELL, v * CELL))
        path = os.path.join(OUT_DIR, name + "_sheet.png")
        sheet.save(path)
        print("wrote", path, sheet.size)
        previews.append(sheet)
    preview = os.environ.get("TRAIL_PREVIEW_DIR")
    if preview:
        h = sum(p.height for p in previews) + 4 * len(previews)
        out = Image.new("RGBA", (CELL * FRAMES, h), (70, 110, 60, 255))
        y = 0
        for p in previews:
            out.alpha_composite(p, (0, y))
            y += p.height + 4
        out.resize((out.width * 10, out.height * 10), Image.NEAREST).save(os.path.join(preview, "trail_preview.png"))


if __name__ == "__main__":
    main()
