# Can yesili adaylari sayfasi (madde 473): hud_capture.gd HP_CANDS karelerinden (hud_yeni/out/hpsw/<aday>_<oran>.png),
# satir = aday, sutun = can orani, 2x en yakin komsu. Cikti: bar_proto/out/hp_yesil.png
#   python -I tools/proto_20261108/bar_proto/hp_swatch.py
import os, glob
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "hud_yeni", "out", "hpsw")
ROOT = os.path.join(HERE, "..", "..", "..")
NAMES = ["SU AN", "A  Yaprak #3cb043", "B  Zumrut #26a65b", "C  Cayir #72b83a", "D  Orman #3f9a3c"]
PCTS = ["%100", "%70", "%35", "%12"]
K = 2


def main():
    font_p = glob.glob(os.path.join(ROOT, "assets", "fonts", "m5x7*.ttf")) or glob.glob(os.path.join(ROOT, "assets", "**", "m5x7*.ttf"), recursive=True)
    font = ImageFont.truetype(font_p[0], 32) if font_p else ImageFont.load_default()
    rows = len(NAMES)
    cols = len(PCTS)
    cell = Image.open(os.path.join(SRC, "0_0.png"))
    cw, ch = cell.width * K, cell.height * K
    lw, gap, top = 300, 14, 44
    sheet = Image.new("RGB", (lw + cols * (cw + gap), top + rows * (ch + gap)), (23, 17, 12))
    d = ImageDraw.Draw(sheet)
    for j, p in enumerate(PCTS):
        d.text((lw + j * (cw + gap) + cw // 2 - 20, 6), p, fill=(232, 214, 180), font=font)
    for i, n in enumerate(NAMES):
        y = top + i * (ch + gap)
        d.text((10, y + ch // 2 - 16), n, fill=(232, 214, 180), font=font)
        for j in range(cols):
            im = Image.open(os.path.join(SRC, "%d_%d.png" % (i, j))).convert("RGB")
            sheet.paste(im.resize((cw, ch), Image.NEAREST), (lw + j * (cw + gap), y))
    out = os.path.join(HERE, "out", "hp_yesil.png")
    sheet.save(out)
    print("ok", sheet.size, out)


if __name__ == "__main__":
    main()
