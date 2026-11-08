"""Ruh hâli prototip karelerini birleştirir (oyuna bağlı DEĞİL).
Satır = karakter, sütun = NORMAL / ŞU AN / A / B / C / D; 3x en yakın komşu büyütme.
Çıktı: out/proto/ozet.gif (animasyonlu) + out/proto/ozet.png (tek kare) + out/proto/gercek_olcek.png (1x, oyundaki boy).
Kullanım: python -I tools/proto_20261107/ruh_hali/ruh_proto_gif.py
"""
import os
import glob
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "out", "proto")
FONT = os.path.join(HERE, "..", "..", "..", "assets", "fonts", "m5x7.ttf")
COLS = [("0normal", "NORMAL"), ("1suan", "ŞU AN"), ("2A", "A  Hayalet"), ("3B", "B  Işık Ruhu"),
        ("4C", "C  Bedenden Çıkış"), ("5D", "D  Mavi Alev")]
K = 3
LABEL_H = 40
BG = (24, 18, 14)
INK = (238, 224, 196)


def main():
    chars = sorted({os.path.basename(p).split("_")[0] for p in glob.glob(os.path.join(SRC, "c*_0normal_00.png"))},
                   key=lambda s: int(s[1:]))
    n = len(glob.glob(os.path.join(SRC, f"{chars[0]}_0normal_*.png")))
    cell = Image.open(os.path.join(SRC, f"{chars[0]}_0normal_00.png")).size
    cw, ch = cell[0] * K, cell[1] * K
    font = ImageFont.truetype(FONT, 32)
    W, H = cw * len(COLS), LABEL_H + ch * len(chars)
    frames = []
    for i in range(n):
        im = Image.new("RGB", (W, H), BG)
        d = ImageDraw.Draw(im)
        for ci, (tag, label) in enumerate(COLS):
            d.text((ci * cw + 10, 4), label, font=font, fill=INK)
            for ri, c in enumerate(chars):
                p = os.path.join(SRC, f"{c}_{tag}_{i:02d}.png")
                if os.path.exists(p):
                    t = Image.open(p).convert("RGB").resize((cw, ch), Image.NEAREST)
                    im.paste(t, (ci * cw, LABEL_H + ri * ch))
        for ci in range(1, len(COLS)):
            d.line([(ci * cw, 0), (ci * cw, H)], fill=BG, width=3)
        frames.append(im)
    frames[0].save(os.path.join(SRC, "ozet.gif"), save_all=True, append_images=frames[1:], duration=83, loop=0)
    frames[n // 2].save(os.path.join(SRC, "ozet.png"))
    # gerçek ölçek (1x): oyunda başka oyuncunun gördüğü boy
    real = Image.new("RGB", (cell[0] * len(COLS), cell[1] * len(chars)), BG)
    for ci, (tag, _) in enumerate(COLS):
        for ri, c in enumerate(chars):
            p = os.path.join(SRC, f"{c}_{tag}_{n // 2:02d}.png")
            if os.path.exists(p):
                real.paste(Image.open(p).convert("RGB"), (ci * cell[0], ri * cell[1]))
    real.save(os.path.join(SRC, "gercek_olcek.png"))
    print("ok", W, H, n)


if __name__ == "__main__":
    main()
