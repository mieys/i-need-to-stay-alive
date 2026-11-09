"""Karsilastirma sayfasi: her harita icin 2 nokta (dunya) + 'ayrinti haritasi' (1 teksel komsu farki, parlak = bekeli)."""
import sys, os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

D, OUT = sys.argv[1], sys.argv[2]
SEL = [("ana", ["p1", "p4"]), ("bataklik", ["p1", "p4"]), ("col", ["p1", "p4"]),
       ("batik_nekropol", ["p0", "p4"]), ("taskin_hisar", ["p1", "p3"]), ("lagim_agi", ["p0", "p2"])]
AD = {"ana": "ANA HARITA", "bataklik": "KARA BATAKLIK", "col": "ALTIN KUMLAR",
      "batik_nekropol": "BATIK NEKROPOL", "taskin_hisar": "TASKIN HISAR", "lagim_agi": "LAGIM AGI"}
W, H = 480, 270


def detail(img):
    a = np.asarray(img.convert("RGB"), dtype=np.float32) / 255.0
    L = 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
    g = np.zeros_like(L)
    g[:, :-1] += np.abs(np.diff(L, axis=1))
    g[:-1, :] += np.abs(np.diff(L, axis=0))
    v = np.clip(g / 0.25, 0, 1) ** 0.7
    return Image.fromarray((v * 255).astype(np.uint8)).convert("RGB")


rows = []
for mp, pts in SEL:
    tiles = []
    for p in pts:
        f = os.path.join(D, f"{mp}_{p}_dunya.png")
        if not os.path.exists(f):
            continue
        im = Image.open(f).convert("RGB")
        tiles.append(im.resize((W, H), Image.NEAREST))
    if not tiles:
        continue
    tiles.append(detail(Image.open(os.path.join(D, f"{mp}_{pts[0]}_dunya.png"))).resize((W, H), Image.NEAREST))
    rows.append((mp, tiles))

lab = 22
sheet = Image.new("RGB", (W * 3 + 8, len(rows) * (H + lab) + 4), (24, 20, 16))
dr = ImageDraw.Draw(sheet)
try:
    font = ImageFont.truetype("arial.ttf", 16)
except OSError:
    font = ImageFont.load_default()
for i, (mp, tiles) in enumerate(rows):
    y = i * (H + lab) + 2
    dr.text((6, y + 2), AD[mp] + "   (sag: 1 piksellik ayrinti/benek haritasi - parlak = gozu yoran ince desen)", fill=(240, 220, 180), font=font)
    for j, t in enumerate(tiles):
        sheet.paste(t, (2 + j * (W + 2), y + lab))
sheet.save(OUT)
print(OUT, sheet.size)
