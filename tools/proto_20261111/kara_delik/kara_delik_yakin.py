"""D merkezinin yakin cekimi: eski (D1) / yeni (D) yan yana, x3 (kara_delik_capture.gd ham kareleri).

  python -I tools/proto_20261111/kara_delik/kara_delik_yakin.py [ham_klasor]
Cikti out/merkez_yakin.png (satir = surum, sutun = an) + out/merkez_yakin.gif (iki surum yan yana, giris+dongu ve bitis).
Ham kare = dunya CROP (-140,-92) 280x160; piksel/dunya kare genisliginden (cekim penceresi ekranin cozunurlugunde olabilir).
"""

import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "kara_delik_cap", "oyun")
FONT = os.path.join(HERE, "..", "..", "..", "assets", "fonts", "m5x7.ttf")
CODES = [("D1", "D eski merkez"), ("D", "D yeni merkez")]
WBOX = (-50.0, -40.0, 50.0, 25.0)   # dunya, delik merkezine gore
S = 2
BG = (24, 20, 28)
INK = (236, 214, 170)
DIM = (150, 136, 112)


def font(sz):
    try:
        return ImageFont.truetype(FONT, sz)
    except OSError:
        return ImageFont.load_default()


def box(k):
    return (int(round((140 + WBOX[0]) * k)), int(round((92 + WBOX[1]) * k)),
            int(round((140 + WBOX[2]) * k)), int(round((92 + WBOX[3]) * k)))


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
    eff = {c: eff_times(z, c) for c, _ in CODES}

    def frame(c, t):
        lst = eff[c]
        i = min(range(len(lst)), key=lambda q: abs(lst[q] - t))
        im = Image.open(os.path.join(SRC, "%s_%03d.png" % (c, i))).convert("RGB")
        k = im.width / 280.0
        im = im.crop(box(k))
        return im.resize((im.width * S, im.height * S), Image.NEAREST)

    k0 = Image.open(os.path.join(SRC, "D_000.png")).width / 280.0
    b0 = box(k0)
    cw, ch = (b0[2] - b0[0]) * S, (b0[3] - b0[1]) * S
    f32 = font(32)
    times = [0.2, 0.8, 1.5, 6.1, 6.27]
    lab = 0
    head = 36
    sheet = Image.new("RGB", (cw * len(times), (ch + head) * len(CODES)), BG)
    d = ImageDraw.Draw(sheet)
    for r, (c, name) in enumerate(CODES):
        y = r * (ch + head)
        for n, t in enumerate(times):
            sheet.paste(frame(c, t), (lab + n * cw, y + head))
            d.text((lab + n * cw + 8, y), "%s   %.2f sn" % (name, t), fill=INK if n == 0 else DIM, font=f32)
    sheet.save(os.path.join(OUT, "merkez_yakin.png"))
    frames = []
    seq = [x * 0.05 for x in range(-2, 39)] + [5.75 + x * 0.05 for x in range(21)]
    for t in seq:
        cv = Image.new("RGB", (cw * 2, ch + head), BG)
        dd = ImageDraw.Draw(cv)
        for k, (c, name) in enumerate(CODES):
            cv.paste(frame(c, t), (k * cw, head))
            dd.text((k * cw + 8, 0), name, fill=INK, font=f32)
        dd.text((cw * 2 - 170, 0), "%.2f sn" % max(0.0, t), fill=DIM, font=f32)
        frames.append(cv.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE))
    frames[0].save(os.path.join(OUT, "merkez_yakin.gif"), save_all=True, append_images=frames[1:], duration=50, loop=0)
    print("tamam", sheet.size, len(frames), "kare gif")


if __name__ == "__main__":
    main()
