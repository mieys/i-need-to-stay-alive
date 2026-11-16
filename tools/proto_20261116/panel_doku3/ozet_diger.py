# Diğer menüler özeti: her ekran için 5 varyantın 1:1 kırpıntısı (3 sütun) -> out/ozet_<ekran>.png. python ozet_diger.py
import os
from PIL import Image, ImageDraw, ImageFont
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "out", "diger")
OUT = os.path.join(HERE, "out")
V = [("simdi", "ŞİMDİ (E Akan Damar)"), ("r1", "R1 Sade Damar"), ("r2", "R2 Kabartma Damar (önerim)"), ("r3", "R3 Ton Akışı"), ("r4", "R4 Kesik Lif")]
CROP = {  # ekran -> (x0, y0, x1, y1) 1920x1080 çekimde, dokulu pencerenin yazılı bölgesi
    "dunya_haritasi": (170, 400, 930, 880),
    "level_pazari": (330, 150, 1090, 630),
    "oyun_sonu": (372, 84, 1132, 564),
}
try:
    font = ImageFont.truetype("arial.ttf", 22)
except OSError:
    font = ImageFont.load_default()
for screen, box in CROP.items():
    w, h = box[2] - box[0], box[3] - box[1]
    lab, gap, cols = 34, 10, 3
    rows = (len(V) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * w + (cols - 1) * gap, rows * (h + lab + gap)), (12, 9, 6))
    d = ImageDraw.Draw(sheet)
    for i, (k, title) in enumerate(V):
        x0 = (i % cols) * (w + gap)
        y0 = (i // cols) * (h + lab + gap)
        d.text((x0 + 6, y0 + 6), title, fill=(240, 192, 112), font=font)
        sheet.paste(Image.open(os.path.join(SRC, "%s_%s.png" % (k, screen))).convert("RGB").crop(box), (x0, y0 + lab))
    if len(V) < rows * cols:  # boş son hücre: önerilen varyantın tam ekranı (küçültülmüş, bağlam için)
        x0 = (cols - 1) * (w + gap)
        y0 = (rows - 1) * (h + lab + gap)
        d.text((x0 + 6, y0 + 6), "R2 tam ekran (küçültülmüş)", fill=(196, 176, 144), font=font)
        full = Image.open(os.path.join(SRC, "r2_%s.png" % screen)).convert("RGB")
        full = full.resize((w, int(w * 1080 / 1920)), Image.LANCZOS)
        sheet.paste(full, (x0, y0 + lab + (h - full.height) // 2))
    path = os.path.join(OUT, "ozet_%s.png" % screen)
    sheet.save(path)
    print(path, sheet.size)
