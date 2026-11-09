"""Vampir yarasa donusumu prototip cekimlerini birlestirir (vampir_donusum_capture.gd ciktisi out/vampir_donusum/oyun/).

  python -I tools/proto_20261109/vampir_donusum_gif.py [--kare]
Cikti out/vampir_donusum/:
  karsilastirma.gif  - SU AN | A | B | C | D yan yana, gercek zaman (giris -> yarasa -> donus), x2 piksel
  ozet.png           - her satir bir kod: girisin ve donusun ilk kareleri (oyun olcegi, x1,5)
"""

import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out", "vampir_donusum")
SRC = os.path.join(OUT, "oyun")
CODES = ["now", "A", "B", "C", "D"]
LABEL = {"now": "SU AN", "A": "A Yarasa Surusu", "B": "B Pelerin", "C": "C Kizil Girdap", "D": "D Golge Sutunu"}
FONT = os.path.join(HERE, "..", "..", "assets", "fonts", "m5x7.ttf")


def font(sz):
    try:
        return ImageFont.truetype(FONT, sz)
    except OSError:
        return ImageFont.load_default()


def load(code, idx):
    return Image.open(os.path.join(SRC, "%s_%03d.png" % (code, idx))).convert("RGB")


def main():
    z = json.load(open(os.path.join(SRC, "zamanlar.json"), encoding="utf-8"))
    times, marks = z["times"], z["marks"]
    codes = [c for c in CODES if c in times]
    w, h = load(codes[0], 0).size
    # kirpma: oyuncu cevresi (cekim 300x250 @1920 -> pencere pikseli), ust/alt HUD bos
    crop = (int(w * 0.12), int(h * 0.12), int(w * 0.88), int(h * 0.98))
    cw, ch = crop[2] - crop[0], crop[3] - crop[1]
    S = 1.0 if cw > 260 else 2.0
    tw, th = int(cw * S), int(ch * S)
    head = 26
    # ---- GIF: her kodun zaman cizgisini giris anina hizala, 30 kare/sn yeniden ornekle
    span_pre, span_post = 250, 2350
    step = 1000 // 30
    frames = []
    for ms in range(-span_pre, span_post, step):
        canvas = Image.new("RGB", (tw * len(codes), th + head), (24, 20, 28))
        d = ImageDraw.Draw(canvas)
        for k, code in enumerate(codes):
            tl = times[code]
            t0 = tl[marks[code][0]]
            target = t0 + ms
            idx = min(range(len(tl)), key=lambda q: abs(tl[q] - target))
            im = load(code, idx).crop(crop).resize((tw, th), Image.NEAREST)
            canvas.paste(im, (k * tw, head))
            d.text((k * tw + 8, 2), LABEL[code], fill=(236, 214, 170), font=font(32))
        frames.append(canvas)
    frames[0].save(os.path.join(OUT, "karsilastirma.gif"), save_all=True, append_images=frames[1:], duration=step, loop=0,
                   optimize=False)
    # ---- ozet: giris 9 kare + donus 7 kare
    sel_in, sel_out = 9, 7
    s2 = 0.75
    cw2, ch2 = int(cw * s2), int(ch * s2)
    sheet = Image.new("RGB", (160 + cw2 * (sel_in + sel_out) + 12, (ch2 + 4) * len(codes)), (24, 20, 28))
    d = ImageDraw.Draw(sheet)
    for r, code in enumerate(codes):
        mi, mo = marks[code]
        y = r * (ch2 + 4)
        d.text((8, y + ch2 // 2 - 12), LABEL[code], fill=(236, 214, 170), font=font(32))
        idxs = [mi - 1] + list(range(mi, mi + 2 * (sel_in - 1), 2))[:sel_in - 1] + [mo - 1] + list(range(mo, mo + 2 * (sel_out - 1), 2))[:sel_out - 1]
        x = 160
        for n, idx in enumerate(idxs):
            if n == sel_in:
                x += 12
            idx = min(idx, len(times[code]) - 1)
            sheet.paste(load(code, idx).crop(crop).resize((cw2, ch2), Image.NEAREST), (x, y))
            x += cw2
    sheet.save(os.path.join(OUT, "ozet.png"))
    print("tamam", len(frames), "kare", tw * len(codes), "x", th + head)


if __name__ == "__main__":
    main()
