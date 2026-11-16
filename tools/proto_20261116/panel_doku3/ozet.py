# Özet: her varyantın oda listesi + karakter seçimi kırpıntısı 1:1, yan yana -> out/ozet.png (+ etiket). python ozet.py
import os
from PIL import Image, ImageDraw, ImageFont
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
V = [("simdi", "ŞİMDİ (E Akan Damar)"), ("r1", "R1 Sade Damar"), ("r2", "R2 Kabartma Damar (önerim)"), ("r3", "R3 Ton Akışı"), ("r4", "R4 Kesik Lif")]
RB = (640, 330, 1240, 630)   # oda listesi paneli (doku geniş alanda)
CS = (500, 440, 1240, 700)   # karakter seçimi yetenek listesi (yazı üstünde doku)
try:
    font = ImageFont.truetype("arial.ttf", 22)
except OSError:
    font = ImageFont.load_default()
rw, rh = RB[2] - RB[0], RB[3] - RB[1]
cw, ch = CS[2] - CS[0], CS[3] - CS[1]
lab = 34
rowh = max(rh, ch) + lab + 10
sheet = Image.new("RGB", (rw + cw + 10, rowh * len(V)), (12, 9, 6))
d = ImageDraw.Draw(sheet)
for i, (k, title) in enumerate(V):
    y0 = i * rowh
    d.text((6, y0 + 6), title, fill=(240, 192, 112), font=font)
    rb = Image.open(os.path.join(OUT, k + "_room_browser.png")).convert("RGB").crop(RB)
    cs = Image.open(os.path.join(OUT, k + "_character_select.png")).convert("RGB").crop(CS)
    sheet.paste(rb, (0, y0 + lab))
    sheet.paste(cs, (rw + 10, y0 + lab))
sheet.save(os.path.join(OUT, "ozet.png"))
print("ozet", sheet.size)
