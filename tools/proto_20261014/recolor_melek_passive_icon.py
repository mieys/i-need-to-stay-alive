"""Melek pasif ikonu: yesil kalp/artilar -> mavi (kalkan pasifi). Yesil tonlari (hue 0.17-0.45) maviye (0.61) kaydirir;
zemin camgobegi (hue ~0.52) ve beyaz kontur aynen kalir. Calistir: python tools/proto_20261014/recolor_melek_passive_icon.py"""
import colorsys
from PIL import Image

PATH = "assets/skills/melek_passive_icon.png"
im = Image.open(PATH).convert("RGB")
px = im.load()
cache = {}
for y in range(im.height):
    for x in range(im.width):
        c = px[x, y]
        if c in cache:
            px[x, y] = cache[c]
            continue
        h, s, v = colorsys.rgb_to_hsv(c[0] / 255, c[1] / 255, c[2] / 255)
        out = c
        if 0.12 <= h <= 0.45 and s > 0.04 and not (v > 0.97 and s < 0.1):
            r, g, b = colorsys.hsv_to_rgb(0.61, min(1.0, max(s * 0.95, 0.25)), v)
            out = (round(r * 255), round(g * 255), round(b * 255))
        cache[c] = out
        px[x, y] = out
im.save(PATH)
