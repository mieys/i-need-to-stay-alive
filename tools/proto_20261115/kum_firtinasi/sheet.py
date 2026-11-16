# KUM FIRTINASI prototipi: out/<varyant>_NN.png karelerinden 2x2 karşılaştırma GIF'i + durağan sayfa.
#   python -I tools/proto_20261115/kum_firtinasi/sheet.py
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
FONT = os.path.join(HERE, "..", "..", "..", "assets", "fonts", "m5x7.ttf")
import sys
SETS = {
    "1": ([("simdi", "Şimdi: çölde açık hava"), ("A", "A  Hafif toz"), ("B", "B  Yoğun fırtına"), ("C", "C  Sadece savrulan kum")], ""),
    "2": ([("B", "Önceki B (bulut gibi)"), ("B1", "Yeni 1  Lifli toz akıntısı"), ("B2", "Yeni 2  Kum yılanları"), ("A1", "Yeni 1, hafif (A seviyesi)")], "_tur2"),
}
CELLS, SUFFIX = SETS[sys.argv[1] if len(sys.argv) > 1 else "1"]
FRAMES = 20
FRAME_MS = 67
BAR = 34


def cell(name, i, crop_w, crop_h, scale):
    im = Image.open(os.path.join(OUT, "%s_%02d.png" % (name, i))).convert("RGB")
    w, h = im.size
    x0, y0 = (w - crop_w) // 2, (h - crop_h) // 2
    im = im.crop((x0, y0, x0 + crop_w, y0 + crop_h))
    return im.resize((int(crop_w * scale), int(crop_h * scale)), Image.BOX)


def grid(i, crop_w, crop_h, scale, font):
    cw, ch = int(crop_w * scale), int(crop_h * scale)
    sheet = Image.new("RGB", (cw * 2, (ch + BAR) * 2), (24, 20, 16))
    d = ImageDraw.Draw(sheet)
    for k, (name, label) in enumerate(CELLS):
        cx, cy = (k % 2) * cw, (k // 2) * (ch + BAR)
        sheet.paste(cell(name, i, crop_w, crop_h, scale), (cx, cy + BAR))
        d.text((cx + 12, cy + 2), label, font=font, fill=(240, 220, 180))
    return sheet


def main():
    font = ImageFont.truetype(FONT, 32)
    frames = [grid(i, 1600, 900, 0.5, font) for i in range(FRAMES)]
    pal = frames[len(frames) // 2].quantize(colors=255, method=Image.Quantize.MEDIANCUT)
    q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
    gif = os.path.join(HERE, "kum_firtinasi_karsilastirma%s.gif" % SUFFIX)
    q[0].save(gif, save_all=True, append_images=q[1:], duration=FRAME_MS, loop=0, optimize=False)
    still = os.path.join(HERE, "kum_firtinasi_durgun%s.png" % SUFFIX)
    grid(8, 1920, 1080, 0.5, font).save(still)
    print(gif, os.path.getsize(gif) // 1024, "KB")
    print(still, os.path.getsize(still) // 1024, "KB")


main()
