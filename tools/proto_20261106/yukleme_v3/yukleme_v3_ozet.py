# YÜKLEME EKRANI v3 prototipleri (madde 408) - out/raw karelerinden: tam boy durağan kare + GIF (960x540) + 2x2 özet.
# Kullanım: python tools/proto_20261106/yukleme_v3/yukleme_v3_ozet.py  (önce yukleme_v3_run.ps1)
import glob
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "out", "raw")
OUT = os.path.join(HERE, "out")
FONT = os.path.join(HERE, "..", "..", "..", "assets", "fonts", "m5x7.ttf")
SHOW = 10  # durağan kare (~%60)
NAMES = [("a", "A - Evde"), ("b", "B - Parti Kartları"), ("c", "C - Sade"), ("d", "D - Çayır")]
ONLY = sys.argv[1:]


def frames(p):
    return sorted(glob.glob(os.path.join(RAW, p + "_*.png")))


stills = {}
for key, title in NAMES:
    if ONLY and key not in ONLY:
        continue
    fs = frames(key)
    if not fs:
        print("yok:", key)
        continue
    slug = title.split(" - ")[1].lower().replace(" ", "_").replace("ç", "c").replace("ı", "i")
    still = Image.open(fs[min(SHOW, len(fs) - 1)]).convert("RGB")
    still.save(os.path.join(OUT, f"{key}_{slug}.png"))
    stills[key] = still
    gif = [Image.open(f).convert("RGB").resize((960, 540), Image.Resampling.BOX) for f in fs]
    pal = [g.quantize(colors=128, method=Image.Quantize.MEDIANCUT) for g in gif]
    dur = [120] * (len(pal) - 1) + [900]
    pal[0].save(os.path.join(OUT, f"{key}_{slug}.gif"), save_all=True, append_images=pal[1:], duration=dur, loop=0)
    print("ok", key, len(fs))

if len(stills) == 4:
    font = ImageFont.truetype(FONT, 32)
    sheet = Image.new("RGB", (1920, 1080 + 96), (20, 14, 9))
    d = ImageDraw.Draw(sheet)
    for i, (key, title) in enumerate(NAMES):
        x, y = (i % 2) * 960, (i // 2) * (540 + 48)
        d.text((x + 12, y + 6), title, font=font, fill=(240, 192, 112))
        sheet.paste(stills[key].resize((960, 540), Image.Resampling.BOX), (x, y + 48))
    sheet.save(os.path.join(OUT, "ozet.png"))
    print("ozet")
