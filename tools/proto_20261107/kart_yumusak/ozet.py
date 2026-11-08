# YUMUŞAK KART prototipleri özeti (2026-11-07): her satır bir seçenek (ŞU AN, A-D), solda level ekranı, sağda evrim ekranı (%40).
# Kullanım: python -I ozet.py [out klasörü]   (kart_yumusak_run.ps1 sonunda kendisi çağırır)
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "out")
FONT = os.path.normpath(os.path.join(HERE, "..", "..", "..", "assets", "fonts", "m5x7.ttf"))
NAMES = {"0": "ŞU AN", "A": "A - Sıcak Kapsül", "B": "B - Tek Pencere", "C": "C - Dikişli Kumaş", "D": "D - Ocak Işığı",
         "E": "E - Uzun Kart", "F": "F - Madalyon", "G": "G - HUD Tepsisi", "H": "H - Odak",
         "I": "I - Bantlı Kart", "J": "J - Kemer Kart", "K": "K - Madalyonlu Kart", "L": "L - Resimli Kart"}
# v1 (A-D) out/v1/, v2 (E-H) out/v2/; varsayılan özet v3: ŞU AN + I-L. İkinci argüman "0,A,B" gibi anahtar listesi.
KEYS = (sys.argv[2] if len(sys.argv) > 2 else "0,I,J,K,L").split(",")
ROWS = [(k, NAMES[k]) for k in KEYS]
LV = (270, 0, 1650, 900)  # level: başlık + satırlar + Karıştır
EV = (150, 0, 1770, 900)  # evrim: başlık + kartlar
S = 0.4
GAP = 12
LABEL_H = 34
BG = (20, 14, 9)  # HudTheme.DEEP
TEXT = (243, 230, 204)  # HudTheme.TEXT


def load(name):
    p = os.path.join(OUT, name)
    return Image.open(p).convert("RGB") if os.path.exists(p) else None


cells = []
for key, label in ROWS:
    lv = load(key + "_level.png")
    ev = load(key + "_evrim.png")
    if lv is not None or ev is not None:
        cells.append((label, lv, ev))
lw, lh = int((LV[2] - LV[0]) * S), int((LV[3] - LV[1]) * S)
ew, eh = int((EV[2] - EV[0]) * S), int((EV[3] - EV[1]) * S)
img = Image.new("RGB", (GAP * 3 + lw + ew, GAP + len(cells) * (LABEL_H + max(lh, eh) + GAP)), BG)
draw = ImageDraw.Draw(img)
font = ImageFont.truetype(FONT, 32)
y = GAP
for label, lv, ev in cells:
    draw.text((GAP, y - 4), label, font=font, fill=TEXT)
    y += LABEL_H
    if lv is not None:
        img.paste(lv.crop(LV).resize((lw, lh), Image.LANCZOS), (GAP, y))
    if ev is not None:
        img.paste(ev.crop(EV).resize((ew, eh), Image.LANCZOS), (GAP * 2 + lw, y))
    y += max(lh, eh) + GAP
img.save(os.path.join(OUT, "ozet.png"))
print("ozet", img.size)
