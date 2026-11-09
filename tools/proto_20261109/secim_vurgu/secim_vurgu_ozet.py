# SECIM VURGUSU ozeti (madde 538): out/<ad>.png -> out/ozet.png (etiketli, alt alta). python -I secim_vurgu_ozet.py
import os, sys
from PIL import Image, ImageDraw, ImageFont
here = os.path.dirname(os.path.abspath(sys.argv[0]))
out = os.path.join(here, "out")
font = ImageFont.truetype(os.path.join(here, "..", "..", "..", "assets", "fonts", "m5x7.ttf"), 32)
rows = [("SU_AN", "ŞU AN - altın kart kenarı (seçili) + altın odak halkası (üstünde)"),
        ("A", "A - Büyüme: üstündeki / seçili kart %5 büyür (evrim kartı gibi)"),
        ("B", "B - Halka Yanar: kart aynı, portre halkası altın (seçili) / soluk altın (üstünde)"),
        ("C", "C - Köşebentler: kart köşelerinde piksel köşebent"),
        ("D", "D - Ad Levhası: seçili adı altın levhada, üstündeki açık ahşap levhada")]
ims = [(Image.open(os.path.join(out, k + ".png")).convert("RGB"), t) for k, t in rows]
w = max(i.width for i, _ in ims)
h = sum(i.height + 40 for i, _ in ims)
sheet = Image.new("RGB", (w, h), (24, 16, 10))
d = ImageDraw.Draw(sheet)
y = 0
for im, t in ims:
    d.text((10, y + 2), t, font=font, fill=(240, 210, 140))
    sheet.paste(im, (0, y + 40))
    y += im.height + 40
sheet.save(os.path.join(out, "ozet.png"))
print(sheet.size)
