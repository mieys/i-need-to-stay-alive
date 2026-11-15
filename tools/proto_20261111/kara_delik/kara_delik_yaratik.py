"""Yaratikli cekim (kara_delik_run.ps1 -Sub yaratik -Env "KD_CODES=D,D2;KD_MOBS=14;KD_WALK=0") -> GIF + duragan kareler.

  python -I tools/proto_20261111/kara_delik/kara_delik_yaratik.py [ham_klasor] [kodlar, ornek D,D2]
Cikti out/yaratikli_<kodlar>.gif (kodlar yan yana; giris + dongu 0-1,95 sn, bitis 5,75-6,75 sn; zaman = deligin saati)
+ out/yaratikli_<kodlar>.png (satir = kod).
"""

import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "kara_delik_cap", "yaratik")
CODES = (sys.argv[2] if len(sys.argv) > 2 else "D").split(",")
LABEL = {"D": "D - merkez zeminde (yaratiklar ustunde)", "D2": "D2 - merkez yaratiklarin ustunde (yutar)",
         "D1": "D eski merkez", "now": "SU AN", "A": "A Coken Zemin", "B": "B Yutan Kure", "C": "C Hiclik Girdabi"}
FONT = os.path.join(HERE, "..", "..", "..", "assets", "fonts", "m5x7.ttf")
BG = (24, 20, 28)
INK = (236, 214, 170)
DIM = (150, 136, 112)


def font(sz):
    try:
        return ImageFont.truetype(FONT, sz)
    except OSError:
        return ImageFont.load_default()


def eff_times(z, c):
    cast = z["marks"][c][1]
    real = [(t - cast) / 1000.0 for t in z["times"][c]]
    eff, off = list(real), 0.0
    for i, ht in enumerate(z["hts"][c]):
        if 0.0 <= ht < 90.0:
            eff[i], off = ht, ht - real[i]
        elif ht >= 90.0:
            eff[i] = real[i] + off
    return eff


def main():
    z = json.load(open(os.path.join(SRC, "zamanlar.json"), encoding="utf-8"))
    eff = {c: eff_times(z, c) for c in CODES}

    def frame(c, t):
        lst = eff[c]
        i = min(range(len(lst)), key=lambda q: abs(lst[q] - t))
        return Image.open(os.path.join(SRC, "%s_%03d.png" % (c, i))).convert("RGB")

    w, h = frame(CODES[0], 0.0).size
    head = 34
    f32 = font(32)
    tag = "_".join(CODES)
    frames = []
    seq = [x * 0.05 for x in range(-2, 40)] + [None] * 6 + [5.75 + x * 0.05 for x in range(21)]
    for t in seq:
        cv = Image.new("RGB", (w * len(CODES), h + head), BG)
        d = ImageDraw.Draw(cv)
        if t is None:
            d.text((20, h // 2), "... 4 sn sonra: bitis", fill=INK, font=font(48))
        else:
            for k, c in enumerate(CODES):
                cv.paste(frame(c, t), (k * w, head))
                d.text((k * w + 8, 0), LABEL.get(c, c), fill=INK, font=f32)
            d.text((w * len(CODES) - 150, 0), "%.2f sn" % max(0.0, t), fill=DIM, font=f32)
        frames.append(cv.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE))
    frames[0].save(os.path.join(OUT, "yaratikli_%s.gif" % tag), save_all=True, append_images=frames[1:], duration=50, loop=0)
    times = [0.5, 1.0, 1.9, 6.1, 6.3]
    s2 = 0.75
    cw, ch = int(w * s2), int(h * s2)
    sheet = Image.new("RGB", (cw * len(times), (ch + head) * len(CODES)), BG)
    d = ImageDraw.Draw(sheet)
    for r, c in enumerate(CODES):
        y = r * (ch + head)
        for n, t in enumerate(times):
            sheet.paste(frame(c, t).resize((cw, ch), Image.NEAREST), (n * cw, y + head))
            d.text((n * cw + 8, y), ("%s   " % LABEL.get(c, c) if n == 0 else "") + "%.2f sn" % t, fill=INK if n == 0 else DIM,
                   font=f32)
    sheet.save(os.path.join(OUT, "yaratikli_%s.png" % tag))
    print("tamam", len(frames), "kare", "%.1f MB" % (os.path.getsize(os.path.join(OUT, "yaratikli_%s.gif" % tag)) / 1e6))


if __name__ == "__main__":
    main()
