# PAZAR YENİ TASARIM prototipleri özeti (2026-11-08): ŞU AN + A-D, 2 sütun x 3 satır, %45.
# Kullanım: python -I ozet.py   (pazar_yeni_run.ps1 sonrası) ; C ailesi: python -I ozet.py C   -> out/ozet_c.png
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
FONT = os.path.normpath(os.path.join(HERE, "..", "..", "..", "assets", "fonts", "m5x7.ttf"))
CELLS = [("SU_AN", "ŞU AN"), ("A", "A - Tezgâh Rafları"), ("B", "B - Dükkân Listesi"),
         ("C", "C - Kart Vitrini"), ("D", "D - Vitrin Sahnesi")]
NAME = "ozet.png"
if len(sys.argv) > 1 and sys.argv[1] == "C":
    CELLS = [("C", "C - Kart Vitrini (önceki)"), ("C1", "C1 - Sakin Izgara"), ("C2", "C2 - Dikey Kartlar"),
             ("C3", "C3 - Tarifli Kartlar"), ("C4", "C4 - Fiyat Etiketli")]
    NAME = "ozet_c.png"
if len(sys.argv) > 1 and sys.argv[1] == "B":
    CELLS = [("B", "B - Dükkân Listesi (önceki)"), ("B1", "B1 - Sade Liste"), ("B2", "B2 - Kutulu Bölmeler"),
             ("B3", "B3 - Geniş Önizleme"), ("B4", "B4 - Defter")]
    NAME = "ozet_b.png"
S = 0.45
GAP = 14
LABEL_H = 36
w, h = int(1920 * S), int(1080 * S)
img = Image.new("RGB", (GAP + 2 * (w + GAP), GAP + 3 * (LABEL_H + h + GAP)), (20, 14, 9))
draw = ImageDraw.Draw(img)
font = ImageFont.truetype(FONT, 32)
for n, (key, label) in enumerate(CELLS):
    p = os.path.join(OUT, key + ".png")
    if not os.path.exists(p):
        continue
    x = GAP + (n % 2) * (w + GAP)
    y = GAP + (n // 2) * (LABEL_H + h + GAP)
    draw.text((x, y - 4), label, font=font, fill=(243, 230, 204))
    img.paste(Image.open(p).convert("RGB").resize((w, h), Image.LANCZOS), (x, y + LABEL_H))
img.save(os.path.join(OUT, NAME))
print("ozet", img.size)
