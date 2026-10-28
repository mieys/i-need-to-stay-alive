# 4 prototipi (A/B/C/D) + bugunku ana ekrani tek ozet goruntude birlestirir (out/ruh_ana_ozet.png, out/ruh_ana_ozet_simdi.png).
import sys, os
from PIL import Image, ImageDraw
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
def sheet(names, labels, path, cols=2, w=1280):
    ims = [Image.open(os.path.join(OUT, "ruh_ana_%s.png" % n)).convert("RGB") for n in names]
    h = int(w * ims[0].height / ims[0].width)
    rows = (len(ims) + cols - 1) // cols
    pad, lab = 16, 40
    S = Image.new("RGB", (cols * w + (cols + 1) * pad, rows * (h + lab) + (rows + 1) * pad), (20, 15, 11))
    d = ImageDraw.Draw(S)
    for i, (im, t) in enumerate(zip(ims, labels)):
        x = pad + (i % cols) * (w + pad)
        y = pad + (i // cols) * (h + lab + pad)
        d.text((x + 4, y + 8), t, fill=(242, 198, 116))
        S.paste(im.resize((w, h), Image.LANCZOS), (x, y + lab))
    S.save(path)
    print(path)
sheet(["a", "b", "c_kar", "d"], ["A - Buyuk Vitrin", "B - Bes Kapi", "C - Menu + Onizleme", "D - Koleksiyon Raflari"], os.path.join(OUT, "ruh_ana_ozet.png"))
