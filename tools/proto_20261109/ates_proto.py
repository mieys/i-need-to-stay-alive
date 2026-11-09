# Ates Asasi alev secenekleri: ates_capture.gd cekimlerinden 2x2 karsilastirma (2026-11-09). Calistir: python -I tools/proto_20261109/ates_proto.py
import os, sys
from PIL import Image, ImageDraw, ImageFont
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "out", "ates_asasi", "oyun")
OUT = os.path.join(HERE, "out", "ates_asasi")
BOX = (840, 380, 1720, 1020)  # oyuncu 2560x1440 pencerede (1280,720)
LABELS = ["ŞU AN", "1  Saydam + turuncu", "1 + 2  Kısa alev (x0,72)", "1 + 2 + 3  Karakterin/yaratığın ALTINDA"]
FONT = None
for p in (r"C:\Windows\Fonts\segoeuib.ttf", r"C:\Windows\Fonts\arialbd.ttf"):
    if os.path.exists(p):
        FONT = ImageFont.truetype(p, 30); break
for sc in ("sag", "asagi"):
    panels = []
    for v in range(4):
        im = Image.open(os.path.join(SRC, "ates_%s_%d.png" % (sc, v))).convert("RGB").crop(BOX)
        d = ImageDraw.Draw(im)
        d.rectangle((0, 0, im.width, 46), fill=(20, 14, 10))
        d.text((14, 6), LABELS[v], fill=(255, 226, 160), font=FONT)
        panels.append(im)
    w, h = panels[0].size
    sheet = Image.new("RGB", (w * 2 + 6, h * 2 + 6), (10, 8, 6))
    for i, im in enumerate(panels):
        sheet.paste(im, ((i % 2) * (w + 6), (i // 2) * (h + 6)))
    sheet.save(os.path.join(OUT, "ates_ozet_%s.png" % sc))
    print("ates_ozet_%s.png" % sc, sheet.size)
