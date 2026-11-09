# PAZAR DÜĞMELERİ prototipleri özeti (2026-11-09): ŞU AN + A-D.
#   out/ozet.png      - her varyantın SATIN AL + DEVAM ET bölgesi 1:1 (oyunun gerçek pikseli), alt alta
#   out/ozet_tam.png  - tam ekranlar %45, 2 sütun
# Kullanım: python -I ozet.py   (dugme_run.ps1 sonrası)
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
FONT = os.path.normpath(os.path.join(HERE, "..", "..", "..", "assets", "fonts", "m5x7.ttf"))
CELLS = [("SU_AN", "ŞU AN - ikisi de aynı altın düğme"),
         ("A", "A - Altın Kese + Ahşap Tahta"),
         ("B", "B - Altın + Ok Tabela"),
         ("C", "C - Fiyat Etiketi + Altın Çerçeve"),
         ("D", "D - Kalın Altın + Koyu Tuş (ENTER)")]
CROP = (930, 690, 1700, 940)  # SATIN AL (önizlemenin altı) + DEVAM ET (pencerenin sağ altı)
GAP = 16
LABEL_H = 40
font = ImageFont.truetype(FONT, 32)

cw, ch = CROP[2] - CROP[0], CROP[3] - CROP[1]
cols = 2
rows = (len(CELLS) + cols - 1) // cols
img = Image.new("RGB", (GAP + cols * (cw + GAP), GAP + rows * (LABEL_H + ch + GAP)), (20, 14, 9))
draw = ImageDraw.Draw(img)
for n, (key, label) in enumerate(CELLS):
    p = os.path.join(OUT, key + ".png")
    if not os.path.exists(p):
        continue
    x = GAP + (n % cols) * (cw + GAP)
    y = GAP + (n // cols) * (LABEL_H + ch + GAP)
    draw.text((x, y - 4), label, font=font, fill=(243, 230, 204))
    img.paste(Image.open(p).convert("RGB").crop(CROP), (x, y + LABEL_H))
img.save(os.path.join(OUT, "ozet.png"))
print("ozet", img.size)

S = 0.45
w, h = int(1920 * S), int(1080 * S)
full = Image.new("RGB", (GAP + 2 * (w + GAP), GAP + 3 * (LABEL_H + h + GAP)), (20, 14, 9))
draw = ImageDraw.Draw(full)
for n, (key, label) in enumerate(CELLS):
    p = os.path.join(OUT, key + ".png")
    if not os.path.exists(p):
        continue
    x = GAP + (n % 2) * (w + GAP)
    y = GAP + (n // 2) * (LABEL_H + h + GAP)
    draw.text((x, y - 4), label, font=font, fill=(243, 230, 204))
    full.paste(Image.open(p).convert("RGB").resize((w, h), Image.LANCZOS), (x, y + LABEL_H))
full.save(os.path.join(OUT, "ozet_tam.png"))
print("ozet_tam", full.size)
