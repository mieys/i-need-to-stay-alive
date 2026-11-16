# Kart dokusu seçenekleri özeti (madde 753): silah ızgarası + dünya haritası kartları, 1:1 -> out/ozet_kart.png. python ozet_kart.py
import os
from PIL import Image, ImageDraw, ImageFont
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "out", "kart")
O = [("simdi", "ŞİMDİ: kartlar da dokulu"), ("duz", "A: kartlar düz, pencere dokulu (önerim)"), ("zayif", "B: kartlarda %35 doku")]
CROPS = [("karakter", (1262, 282, 1900, 662)), ("harita", (170, 120, 650, 500))]
try:
    font = ImageFont.truetype("arial.ttf", 22)
except OSError:
    font = ImageFont.load_default()
lab, gap = 34, 10
cw = sum(b[2] - b[0] for _, b in CROPS) + gap * (len(CROPS) - 1)
rh = max(b[3] - b[1] for _, b in CROPS)
sheet = Image.new("RGB", (cw, len(O) * (rh + lab + gap)), (12, 9, 6))
d = ImageDraw.Draw(sheet)
for i, (k, title) in enumerate(O):
    y0 = i * (rh + lab + gap)
    d.text((6, y0 + 6), title, fill=(240, 192, 112), font=font)
    x = 0
    for scr, b in CROPS:
        sheet.paste(Image.open(os.path.join(SRC, "%s_%s.png" % (k, scr))).convert("RGB").crop(b), (x, y0 + lab))
        x += b[2] - b[0] + gap
path = os.path.join(HERE, "out", "ozet_kart.png")
sheet.save(path)
print(path, sheet.size)
