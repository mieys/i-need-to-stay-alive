"""Kullanici istegi (2026-09-25): "kalkan baginin ozel efektini yeniden tasarlamani istiyorum, pixel tarzda spritesheet
olacak sekilde, fazla goz yormayan minimalist bir kalkan bagi efekti olmali".

Eski efekt (fx_kalkan_bagi_link.gd) her karede prosedurel ciziliyordu: saniyede 46 piksel HIZLA akan kesikli bir hat +
iki ucta surekli yanip sonen parlak kareler - surekli goz alan bir hareket. Yeni tasarim uc kucuk sprite sayfasi:

  - link_line.png  (8x3, doseme): 1 piksellik yumusak mavi hat, ustunde/altinda cok soluk hale; her 8 pikselde bir hafif
                    parlak "boncuk". Kod bu dosemeyi hat boyunca tekrarlayip COK yavas kaydirir (sakin bir akis).
  - link_glint.png (6 kare x 7x7): kucuk kalkan rozeti - ara sira bir uctan digerine suzulur (belirir, parlar, soner).
  - link_end.png   (8 kare x 7x7): iki uctaki minik elmas - yavasca nefes alir (buyuyup kuculmez, sadece parlakligi
                    ve cevresindeki soluk hale degisir).

Renkler kalkan mavisi (hud.gd kalkan cubugu / eski bag rengi 0.45, 0.8, 1.0 ailesi). 1 sanat pikseli = PixelDraw.TEXEL.
Calistir: python tools/gen_kalkan_bagi_fx.py  (sonra Godot editoru import eder)
"""

import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "fx", "kalkan_bagi")

DEEP = (52, 112, 214)
MID = (115, 199, 255)
LIGHT = (209, 242, 255)
WHITE = (255, 255, 255)


def rgba(c, a):
    return (c[0], c[1], c[2], int(round(255 * a)))


def line_tile():
    img = Image.new("RGBA", (8, 3), (0, 0, 0, 0))
    for x in range(8):
        img.putpixel((x, 0), rgba(DEEP, 0.16))
        img.putpixel((x, 2), rgba(DEEP, 0.16))
        img.putpixel((x, 1), rgba(MID, 0.55))
    img.putpixel((0, 1), rgba(LIGHT, 0.8))  # boncuk
    return img


SHIELD = [
    "ooooo",
    "owllo",
    "ollmo",
    "olmmo",
    ".omo.",
    "..o..",
]


def glint_sheet():
    frames = 6
    alphas = [0.35, 0.7, 1.0, 1.0, 0.7, 0.35]
    img = Image.new("RGBA", (7 * frames, 7), (0, 0, 0, 0))
    for f in range(frames):
        a = alphas[f]
        for y, row in enumerate(SHIELD):
            for x, ch in enumerate(row):
                col = {"o": DEEP, "l": LIGHT, "m": MID, "w": WHITE}.get(ch)
                if col is None:
                    continue
                img.putpixel((f * 7 + 1 + x, y), rgba(col, a))
        # parlak an: sol ustte tek piksellik isilti
        if f in (2, 3):
            img.putpixel((f * 7 + 1 + (1 if f == 2 else 2), 1), rgba(WHITE, 1.0))
    return img


def end_sheet():
    frames = 8
    img = Image.new("RGBA", (7 * frames, 7), (0, 0, 0, 0))
    for f in range(frames):
        # 0..1..0 nefes
        k = 1.0 - abs((f / (frames / 2.0)) - 1.0)
        core_a = 0.55 + 0.35 * k
        halo_a = 0.08 + 0.22 * k
        cx = cy = 3
        for y in range(7):
            for x in range(7):
                d = abs(x - cx) + abs(y - cy)  # elmas (manhattan) mesafe
                if d == 0:
                    img.putpixel((f * 7 + x, y), rgba(WHITE, core_a))
                elif d == 1:
                    img.putpixel((f * 7 + x, y), rgba(LIGHT, core_a))
                elif d == 2:
                    img.putpixel((f * 7 + x, y), rgba(MID, core_a * 0.8))
                elif d == 3:
                    img.putpixel((f * 7 + x, y), rgba(DEEP, halo_a))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, img in (("link_line.png", line_tile()), ("link_glint.png", glint_sheet()), ("link_end.png", end_sheet())):
        path = os.path.join(OUT, name)
        img.save(path)
        print("yazildi:", os.path.normpath(path), img.size)


if __name__ == "__main__":
    main()
