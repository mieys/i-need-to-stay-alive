"""Vampir Q "Kan Emme" prototip cekimlerini birlestirir (kan_emme_capture.gd ciktisi out/oyun/).

  python -I tools/proto_20261116/kan_emme/kan_emme_gif.py [--src oyun]
Cikti out/:
  karsilastirma.gif  - SU AN | A | B | C ust ust 3+2 izgara, Q basildigi ana hizali, gercek zaman (oyun ms), x0,5 yumusak kucultme
  <kod>.gif          - tek tek, oyun olceginde (1 dunya = 3 px)
  ozet.png           - her satir bir kod: Q'dan sonra secili anlar (oyun olcegi x0,5)
"""

import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
SRCNAME = sys.argv[sys.argv.index("--src") + 1] if "--src" in sys.argv else "oyun"
SRC = os.path.join(OUT, SRCNAME)
CODES = ["now", "A", "B", "C", "D"]
LABEL = {"now": "SU AN", "A": "A Kan Akintisi", "B": "B Kuyruklu Damla", "C": "C Kan Kalbi", "D": "D Kizil Buhar"}
FONT = os.path.join(HERE, "..", "..", "..", "assets", "fonts", "m5x7.ttf")
SUFFIX = "" if SRCNAME == "oyun" else "_" + SRCNAME.replace("oyun_", "")


def font(sz):
    try:
        return ImageFont.truetype(FONT, sz)
    except OSError:
        return ImageFont.load_default()


def load(code, idx):
    return Image.open(os.path.join(SRC, "%s_%03d.png" % (code, idx))).convert("RGB")


def nearest_idx(tl, target):
    return min(range(len(tl)), key=lambda q: abs(tl[q] - target))


def main():
    z = json.load(open(os.path.join(SRC, "zamanlar.json"), encoding="utf-8"))
    times, marks = z["times"], z["marks"]
    codes = [c for c in CODES if c in times]
    w, h = load(codes[0], 0).size
    step = 1000 // 30
    span_pre, span_post = 200, 1250
    # ---- tek tek GIF (oyun olcegi)
    for code in codes:
        tl = times[code]
        t0 = tl[marks[code]]
        frames = []
        for ms in range(-span_pre, span_post, step):
            im = load(code, nearest_idx(tl, t0 + ms))
            d = ImageDraw.Draw(im)
            d.text((8, 2), LABEL[code], fill=(236, 214, 170), font=font(32))
            frames.append(im)
        frames[0].save(os.path.join(OUT, "%s%s.gif" % (code, SUFFIX)), save_all=True, append_images=frames[1:], duration=step, loop=0)
    # ---- karsilastirma: 3 + 2 izgara, x0,5
    s = 0.5
    tw, th = int(w * s), int(h * s)
    head = 22
    cols = 3
    rows = (len(codes) + cols - 1) // cols
    frames = []
    for ms in range(-span_pre, span_post, step):
        canvas = Image.new("RGB", (tw * cols, (th + head) * rows), (24, 20, 28))
        d = ImageDraw.Draw(canvas)
        for k, code in enumerate(codes):
            tl = times[code]
            t0 = tl[marks[code]]
            im = load(code, nearest_idx(tl, t0 + ms)).resize((tw, th), Image.LANCZOS)
            x, y = (k % cols) * tw, (k // cols) * (th + head)
            canvas.paste(im, (x, y + head))
            d.text((x + 6, y + 1), LABEL[code], fill=(236, 214, 170), font=font(32))
        frames.append(canvas)
    frames[0].save(os.path.join(OUT, "karsilastirma%s.gif" % SUFFIX), save_all=True, append_images=frames[1:], duration=step, loop=0)
    # ---- ozet: Q'dan sonra secili anlar
    sel = [60, 150, 250, 350, 470, 620, 800]
    s2 = 0.5
    cw2, ch2 = int(w * s2), int(h * s2)
    sheet = Image.new("RGB", (190 + cw2 * len(sel), 24 + (ch2 + 4) * len(codes)), (24, 20, 28))
    d = ImageDraw.Draw(sheet)
    for n, ms in enumerate(sel):
        d.text((190 + n * cw2 + 6, 0), "+%d ms" % ms, fill=(200, 190, 170), font=font(32))
    for r, code in enumerate(codes):
        tl = times[code]
        t0 = tl[marks[code]]
        y = 24 + r * (ch2 + 4)
        d.text((8, y + ch2 // 2 - 12), LABEL[code], fill=(236, 214, 170), font=font(32))
        for n, ms in enumerate(sel):
            sheet.paste(load(code, nearest_idx(tl, t0 + ms)).resize((cw2, ch2), Image.LANCZOS), (190 + n * cw2, y))
    sheet.save(os.path.join(OUT, "ozet%s.png" % SUFFIX))
    print("tamam", len(frames), "kare", w, "x", h)


if __name__ == "__main__":
    main()
