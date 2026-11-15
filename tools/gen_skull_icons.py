"""Kafatasi ikonlari (kullanici cizimi, 2026-11-11): tools/skull_ikon/skull_kaynak.png (32x32) -> assets/ui/skull/.
  skull.png        kaynagin opak alani kirpilmis hali (22x30, piksel piksel ayni)
  skull_red.png    ayni ikon kan kirmizisi (Final kademe)
  skull_s.png      2x2 kutu ortalamasiyla 11x15 kucuk hali (18-27 px'lik yerler, nearest ile keskin)
  skull_s_red.png  kucugun kirmizisi
Calistir: python -I tools/gen_skull_icons.py   (sonra Godot'ta import: assets/ui/skull/*.png)
"""
import colorsys
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "skull_ikon", "skull_kaynak.png")
OUT = os.path.join(ROOT, "assets", "ui", "skull")
CROP = (5, 1, 27, 31)  # kaynaktaki opak alan, 22x30 (cift boyutlu ve cift hizali: 2x2 kutular tam oturur)


def red_of(im: Image.Image) -> Image.Image:
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            if v > 0.12:  # siyah dis hatta dokunma
                h = 0.0 + (h - 0.14) * 0.25  # altin tonu (0,14) -> kirmizi (0), kucuk sapma korunur
                s = min(1.0, s * 1.55 + 0.12)
                v = v * 0.97
            r2, g2, b2 = colorsys.hsv_to_rgb(h % 1.0, s, v)
            px[x, y] = (round(r2 * 255), round(g2 * 255), round(b2 * 255), a)
    return out


def small_of(im: Image.Image) -> Image.Image:
    sm = im.resize((im.width // 2, im.height // 2), Image.BOX)  # Pillow RGBA'da on-carpimli ortalar
    px = sm.load()
    for y in range(sm.height):
        for x in range(sm.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255 if a >= 128 else 0)
    return sm


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    src = Image.open(SRC).convert("RGBA")
    big = src.crop(CROP)
    big_red = red_of(big)
    for name, im in (("skull", big), ("skull_red", big_red), ("skull_s", small_of(big)), ("skull_s_red", small_of(big_red))):
        im.save(os.path.join(OUT, name + ".png"))
        print(name, im.size)


if __name__ == "__main__":
    main()
