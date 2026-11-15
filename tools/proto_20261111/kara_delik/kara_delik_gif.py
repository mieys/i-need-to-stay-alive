"""Hadime kara delik prototip cekimlerini birlestirir (kara_delik_capture.gd ciktisi, varsayilan %TEMP%/kara_delik_cap/oyun).

  python -I tools/proto_20261111/kara_delik/kara_delik_gif.py [ham_klasor]
Cikti tools/proto_20261111/kara_delik/out/:
  karsilastirma.gif - SU AN | A | B / C | D | zaman, gercek oyun olcegi (1 dunya = 2 ekran px), giris + dongu (0-1,9 sn) ve
                      bitis (5,75-6,75 sn; carpma 6,25 sn = sesin cokus vurusu)
  dongu_buyuk.png   - dongu ortasi (1,5 sn) tam olcek, 3x2
  ozet.png          - her satir bir kod: giris / dongu / bitis kareleri (x0,5)
"""

import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "kara_delik_cap", "oyun")
CODES = ["now", "A", "B", "C", "D"]
LABEL = {"now": "SU AN", "A": "A  Coken Zemin", "B": "B  Yutan Kure", "C": "C  Hiclik Girdabi", "D": "D  Bukulen Uzay"}
FONT = os.path.join(HERE, "..", "..", "..", "assets", "fonts", "m5x7.ttf")
BG = (24, 20, 28)
INK = (236, 214, 170)
DIM = (150, 136, 112)


def font(sz):
    try:
        return ImageFont.truetype(FONT, sz)
    except OSError:
        return ImageFont.load_default()


def main():
    z = json.load(open(os.path.join(SRC, "zamanlar.json"), encoding="utf-8"))
    codes = [c for c in CODES if c in z["times"]]
    # zaman = deligin KENDI saati (_t; ses ve kare secimi buna oturur). Cekim sirasinda ekran okuma fizik saatini gercek
    # saatten biraz geride birakir -> delik yokken (on kayit / silindikten sonra) gercek saat + en yakin farkla devam.
    rel = {}
    for c in codes:
        cast = z["marks"][c][1]
        real = [(t - cast) / 1000.0 for t in z["times"][c]]
        hts = z.get("hts", {}).get(c, [])
        eff = list(real)
        off = 0.0
        for i, ht in enumerate(hts):
            if 0.0 <= ht < 90.0:
                eff[i] = ht
                off = ht - real[i]
            elif ht >= 90.0:
                eff[i] = real[i] + off
        rel[c] = eff
    cache = {}

    def frame(c, t):
        lst = rel[c]
        i = min(range(len(lst)), key=lambda q: abs(lst[q] - t))
        key = (c, i)
        if key not in cache:
            cache[key] = Image.open(os.path.join(SRC, "%s_%03d.png" % (c, i))).convert("RGB")
        return cache[key]

    w, h = frame(codes[0], 0.0).size
    head = 30
    cols = 3
    rows = 2
    f32 = font(32)

    def grid(t, phase_txt):
        cv = Image.new("RGB", (w * cols, (h + head) * rows), BG)
        d = ImageDraw.Draw(cv)
        for n, c in enumerate(codes):
            x, y = (n % cols) * w, (n // cols) * (h + head)
            cv.paste(frame(c, t), (x, y + head))
            d.text((x + 8, y - 2), LABEL[c], fill=INK, font=f32)
        # bos hucre: zaman
        x, y = 2 * w, (h + head)
        d.text((x + 24, y + head + 40), "t = %.2f sn" % max(0.0, t), fill=INK, font=f32)
        d.text((x + 24, y + head + 80), phase_txt, fill=DIM, font=f32)
        d.text((x + 24, y + head + 200), "gercek oyun olcegi", fill=DIM, font=f32)
        d.text((x + 24, y + head + 232), "cekim alani 110 dunya px", fill=DIM, font=f32)
        return cv

    def phase_of(t):
        if t < 0:
            return "E basiliyor"
        if t < 0.4:
            return "giris (0,4 sn)"
        if t < 6.0:
            return "dongu"
        if t < 6.25:
            return "bitis basladi"
        if t < 6.32:
            return "CARPMA (ses vurusu)"
        return "bitis"

    frames = []
    step = 0.05
    t = -0.1
    while t < 1.95:
        frames.append(grid(t, phase_of(t)))
        t += step
    sep = Image.new("RGB", frames[0].size, BG)
    ImageDraw.Draw(sep).text((40, frames[0].height // 2 - 20), "... 4 sn sonra: bitis", fill=INK, font=font(48))
    frames += [sep] * 8
    t = 5.75
    while t < 6.75:
        frames.append(grid(t, phase_of(t)))
        t += step
    durs = [int(step * 1000)] * len(frames)
    pal_frames = [f.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE) for f in frames]
    pal_frames[0].save(os.path.join(OUT, "karsilastirma.gif"), save_all=True, append_images=pal_frames[1:], duration=durs,
                       loop=0, optimize=False)
    grid(1.5, "dongu").save(os.path.join(OUT, "dongu_buyuk.png"))
    # ozet: satir basina kod
    times = [0.1, 0.3, 1.0, 1.6, 6.05, 6.2, 6.27, 6.35, 6.45]
    s2 = 0.5
    cw, ch = int(w * s2), int(h * s2)
    lab = 230
    sheet = Image.new("RGB", (lab + cw * len(times), 40 + (ch + 4) * len(codes)), BG)
    d = ImageDraw.Draw(sheet)
    for n, tt in enumerate(times):
        d.text((lab + n * cw + 6, 2), "%.2f sn" % tt, fill=DIM, font=f32)
    for r, c in enumerate(codes):
        y = 40 + r * (ch + 4)
        d.text((8, y + ch // 2 - 16), LABEL[c], fill=INK, font=f32)
        for n, tt in enumerate(times):
            sheet.paste(frame(c, tt).resize((cw, ch), Image.NEAREST), (lab + n * cw, y))
    sheet.save(os.path.join(OUT, "ozet.png"))
    sz = os.path.getsize(os.path.join(OUT, "karsilastirma.gif")) / 1e6
    print("tamam", len(frames), "kare", frames[0].size, "gif %.1f MB" % sz)


if __name__ == "__main__":
    main()
