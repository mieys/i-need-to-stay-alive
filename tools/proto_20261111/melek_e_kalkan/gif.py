"""Melek E + dostun kalkan baloncugu prototipi (oyuna bagli DEGIL): yakala.ps1 karelerinden
out/<kalkan>/karsilastirma.gif (2x2, 15 fps) + out/<kalkan>/ozet.png (secenek basina 4 an).
Kullanim: python -I tools/proto_20261111/melek_e_kalkan/gif.py [shield_standart]
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
PROJ = ROOT.parents[2]
SHIELD = sys.argv[1] if len(sys.argv) > 1 else "shield_standart"
SRC = ROOT / "out" / SHIELD
VARIANTS = [
    ("suan", "ŞU AN", "baloncuk yok"),
    ("a", "A - Açık Baloncuk", "bağ değince kalkan yenilenmesi açılır"),
    ("b", "B - Dolan Baloncuk", "A + her dalgada baloncuk parlar"),
    ("c", "C - Baloncuğa Bağ", "B + baloncuk E ile açılır, ip ona değer"),
]
FONT = ImageFont.truetype(str(PROJ / "assets/fonts/m5x7.ttf"), 32)
FONT_S = ImageFont.truetype(str(PROJ / "assets/fonts/m5x7.ttf"), 16)
BG = (30, 22, 16)
INK = (242, 228, 196)
DIM = (176, 156, 124)
CAP_H = 44
PAD = 8


def frames(v):
    return sorted((SRC / v).glob("f_*.png"))


def panel(img, title, sub):
    w, h = img.size
    out = Image.new("RGB", (w, h + CAP_H), BG)
    out.paste(img.convert("RGB"), (0, CAP_H))
    d = ImageDraw.Draw(out)
    d.text((8, 0), title, font=FONT, fill=INK)
    d.text((8, 26), sub, font=FONT_S, fill=DIM)
    return out


def main():
    seqs = [frames(v) for v, _, _ in VARIANTS]
    n = min(len(s) for s in seqs)
    w, h = Image.open(seqs[0][0]).size
    pw, ph = w, h + CAP_H
    gw, gh = pw * 2 + PAD * 3, ph * 2 + PAD * 3
    out_frames = []
    for i in range(n):
        g = Image.new("RGB", (gw, gh), BG)
        for k, (v, title, sub) in enumerate(VARIANTS):
            p = panel(Image.open(seqs[k][i]), title, sub)
            g.paste(p, (PAD + (k % 2) * (pw + PAD), PAD + (k // 2) * (ph + PAD)))
        out_frames.append(g.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE))
    gif = SRC / "karsilastirma.gif"
    out_frames[0].save(gif, save_all=True, append_images=out_frames[1:], duration=67, loop=0, disposal=1)
    print("GIF", gif, n, "kare", gif.stat().st_size // 1024, "KB")

    ## ozet: secenek basina 4 an (bag kuruldu / 1. dalga varisi / 2. varis / bitis)
    picks = [(11, "bağ kuruldu"), (26, "dalga vardı"), (29, "0,2 sn sonra"), (70, "E bitti")]
    crop = (w // 2 - 40, 30, w // 2 + 200, h - 20)  ## dostun cevresi
    cw, ch = crop[2] - crop[0], crop[3] - crop[1]
    sc = 2
    lab_w = 260
    sheet = Image.new("RGB", (lab_w + len(picks) * (cw * sc + PAD) + PAD, 30 + len(VARIANTS) * (ch * sc + PAD) + PAD), BG)
    d = ImageDraw.Draw(sheet)
    for j, (fi, txt) in enumerate(picks):
        d.text((lab_w + PAD + j * (cw * sc + PAD), 4), txt, font=FONT, fill=DIM)
    for k, (v, title, sub) in enumerate(VARIANTS):
        y = 30 + PAD + k * (ch * sc + PAD)
        d.text((8, y + 8), title, font=FONT, fill=INK)
        d.text((8, y + 40), sub, font=FONT_S, fill=DIM)
        for j, (fi, _) in enumerate(picks):
            im = Image.open(seqs[k][min(fi, n - 1)]).convert("RGB").crop(crop).resize((cw * sc, ch * sc), Image.NEAREST)
            sheet.paste(im, (lab_w + PAD + j * (cw * sc + PAD), y))
    ozet = SRC / "ozet.png"
    sheet.save(ozet)
    print("OZET", ozet, sheet.size)


if __name__ == "__main__":
    main()
