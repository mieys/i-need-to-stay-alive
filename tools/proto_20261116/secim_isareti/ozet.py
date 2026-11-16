# Secim isareti prototipleri: out/<harf>_kar.png + <harf>_karo.png -> out/ozet.png (2x2, basliklar).
#   python tools/proto_20261116/secim_isareti/ozet.py
import os
from PIL import Image, ImageDraw, ImageFont

D = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
V = [("A", "A  Spot Işığı - diğerleri kararır"), ("B", "B  İşaretçi Ok - üstte zıplayan ok"),
     ("C", "C  Altın Hale - kademeli parıltı"), ("D", "D  Altın Çerçeve - çerçeve altına döner")]
font = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 30)
panels = []
for key, title in V:
    a = Image.open(os.path.join(D, key + "_kar.png")).convert("RGB")
    b = Image.open(os.path.join(D, key + "_karo.png")).convert("RGB")
    w = max(a.width, b.width)
    p = Image.new("RGB", (w, 50 + a.height + 10 + b.height), (24, 17, 11))
    ImageDraw.Draw(p).text((10, 8), title, font=font, fill=(240, 192, 112))
    p.paste(a, (0, 50))
    p.paste(b, (0, 50 + a.height + 10))
    panels.append(p)
pw = max(p.width for p in panels)
ph = max(p.height for p in panels)
sheet = Image.new("RGB", (pw * 2 + 16, ph * 2 + 16), (12, 8, 5))
for i, p in enumerate(panels):
    sheet.paste(p, ((i % 2) * (pw + 16), (i // 2) * (ph + 16)))
sheet = sheet.resize((sheet.width * 3 // 4, sheet.height * 3 // 4), Image.LANCZOS)
sheet.save(os.path.join(D, "ozet.png"))
print(sheet.size)
