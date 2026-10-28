# Komple tasarim prototiplerinin ozetleri (madde 382): her tasarim icin 3 ekran yan yana (out/ruh_komple_<x>_ozet.png) + hepsi (out/ruh_komple_ozet.png).
import os, sys
from PIL import Image, ImageDraw
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
SETS = {"a": (["a_kar", "a_silah", "a_gel"], "A - Sekmeli Tezgah"), "b": (["b_kar", "b_silah", "b_gel"], "B - Vitrin Odasi"),
        "c": (["c_kar", "c_silah", "c_gel"], "C - Ocak Basi Defteri"), "d": (["d_kar", "d_detay", "d_gel"], "D - Kart Masasi")}
def sheet(rows, path, w):
    ims = [[Image.open(os.path.join(OUT, "ruh_komple_%s.png" % n)).convert("RGB") for n in names] for names, _ in rows]
    h = int(w * ims[0][0].height / ims[0][0].width)
    pad, lab = 12, 34
    S = Image.new("RGB", (3 * w + 4 * pad, len(rows) * (h + lab + pad) + pad), (20, 15, 11))
    d = ImageDraw.Draw(S)
    for r, (row, (names, title)) in enumerate(zip(ims, rows)):
        y = pad + r * (h + lab + pad)
        d.text((pad + 4, y + 8), title, fill=(242, 198, 116))
        for c, im in enumerate(row):
            S.paste(im.resize((w, h), Image.LANCZOS), (pad + c * (w + pad), y + lab))
    S.save(path)
    print(path)
keys = sys.argv[1:] or ["a", "b", "c", "d"]
for k in keys:
    sheet([SETS[k]], os.path.join(OUT, "ruh_komple_%s_ozet.png" % k), 1280)
if not sys.argv[1:]:
    sheet([SETS[k] for k in "abcd"], os.path.join(OUT, "ruh_komple_ozet.png"), 960)
