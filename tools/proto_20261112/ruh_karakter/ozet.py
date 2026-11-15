# Ruh Magazasi karakter ayrintisi prototipleri - ozet sayfasi (out/ozet.png). Yakalamalar 2560x1440 (kullanicinin ekran olcegi), kirpma 1:1.
#   python -I tools/proto_20261112/ruh_karakter/ozet.py
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
FONT = os.path.join(HERE, "..", "..", "..", "assets", "fonts", "m5x7.ttf")
X0, Y0, Y1 = 1640, 60, 1440  # sag ayrinti paneli (2560x1440 yakalamada)
PANELS = [
    ("now_vampir", "ŞU AN (bugünkü)", X0),
    ("a_vampir", "A - Yetenek Sekmeleri (ikona gel / tıkla)", X0),
    ("b_vampir", "B - Açılır Liste (satıra tıkla)", X0),
    ("c_vampir_genel", "C - Defter Sayfaları: GENEL", X0),
    ("c_vampir_yetenek", "C - Defter Sayfaları: YETENEKLER", X0),
    ("d_vampir", "D - Oyun İçi İpucu (yeteneğin üstüne gel)", 900),
]
GAP, HEAD = 24, 70
font = ImageFont.truetype(FONT, 48)
crops = [(Image.open(os.path.join(OUT, n + ".png")).convert("RGB").crop((x, Y0, 2560, Y1)), t) for n, t, x in PANELS]
rows = [crops[:3], crops[3:]]
W = max(sum(c.width for c, _ in r) + GAP * (len(r) - 1) for r in rows)
H = sum(HEAD + max(c.height for c, _ in r) for r in rows) + GAP
sheet = Image.new("RGB", (W, H), (24, 18, 14))
d = ImageDraw.Draw(sheet)
y = 0
for r in rows:
    x = 0
    for c, t in r:
        d.text((x + 8, y + 10), t, font=font, fill=(242, 196, 110))
        sheet.paste(c, (x, y + HEAD))
        x += c.width + GAP
    y += HEAD + max(c.height for c, _ in r) + GAP
sheet.save(os.path.join(OUT, "ozet.png"))
print("ozet", sheet.size)
