# Envanter prototipleri özet sayfası (envanter_proto.gd çıktılarından): ŞU AN + A-D + C ikinci sekme, 2x3, yarı boy.
#   python tools/proto_20261020/envanter_ozet.py
import os
from PIL import Image, ImageDraw, ImageFont
D = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out", "envanter")
CELLS = [("simdi", "ŞU AN"), ("A", "A - Kayrak Çanta (Seyyar Satıcı dili)"), ("B", "B - Kahraman Sandığı (demirci ahşabı)"),
         ("C", "C - Ateş Işığı (ESC / Ayarlar dili)"), ("C2", "C - Ateş Işığı: ÖZELLİKLER sekmesi"), ("D", "D - Gece Sıvası Yan Çanta (telefonla aynı)")]
W, H, CAP = 960, 540, 40
try:
    font = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 24)
except OSError:
    font = ImageFont.load_default()
sheet = Image.new("RGB", (W * 2, (H + CAP) * 3), (18, 16, 22))
dr = ImageDraw.Draw(sheet)
for i, (name, cap) in enumerate(CELLS):
    x, y = (i % 2) * W, (i // 2) * (H + CAP)
    dr.text((x + 14, y + 7), cap, fill=(240, 200, 120), font=font)
    p = os.path.join(D, name + ".png")
    if os.path.exists(p):
        sheet.paste(Image.open(p).convert("RGB").resize((W, H), Image.LANCZOS), (x, y + CAP))
sheet.save(os.path.join(D, "ozet.png"))
print("ozet.png")
