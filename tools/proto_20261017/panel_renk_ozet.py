"""Panel rengi prototiplerinin özet sayfaları (madde 248; çekimler panel_renk_proto.gd).

python -I tools/proto_20261017/panel_renk_ozet.py
-> out/panel_renk/ozet_<palet>.png (eski = C seçilmeden önceki renkler, eski_*.png) (ana menü + tek + oda + çok, 2x2, 1920x1080'in yarısı)
-> out/panel_renk/ozet_hepsi.png (satır = palet, sütun = tek / oda / çok, 1/3 ölçek)
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "tools", "proto_20261017", "out", "panel_renk")
FONT = os.path.join(ROOT, "assets", "fonts", "m5x7.ttf")

NAMES = {
    "eski": "ESKİ - yeşil-camgöbeği",
    "a": "A - Kehribar Ocak",
    "b": "B - Ceviz Tahta",
    "c": "C - Gece Sıvası",
    "d": "D - Kızıl Kor",
}
SCREENS = [("tek", "Tek oyunculu"), ("oda", "Oda listesi + oda kur"), ("cok", "Çok oyunculu seçim")]
BG = (17, 13, 10)
GOLD = (244, 197, 110)
CREAM = (239, 226, 198)


def font(sz):
    return ImageFont.truetype(FONT, sz)


def half(name, k):
    im = Image.open(os.path.join(OUT, name)).convert("RGB")
    return im.resize((im.width // k, im.height // k), Image.LANCZOS)


def sheet(key):
    W, H, PAD, HEAD, LAB = 960, 540, 12, 64, 32
    out = Image.new("RGB", (PAD * 3 + W * 2, HEAD + (LAB + H + PAD) * 2), BG)
    d = ImageDraw.Draw(out)
    d.text((PAD, 8), NAMES[key], font=font(48), fill=GOLD)
    cells = [("ana_menu.png", "Ana menü (karşılaştırma)")] + [("%s_%s.png" % (key, s), t) for s, t in SCREENS]
    for i, (f, t) in enumerate(cells):
        x = PAD + (i % 2) * (W + PAD)
        y = HEAD + (i // 2) * (LAB + H + PAD)
        d.text((x, y), t, font=font(32), fill=CREAM)
        out.paste(half(f, 2), (x, y + LAB))
    out.save(os.path.join(OUT, "ozet_%s.png" % key))


def overview():
    W, H, PAD, LW, HEAD = 640, 360, 10, 300, 48
    keys = list(NAMES)
    out = Image.new("RGB", (LW + (W + PAD) * 3, HEAD + (H + PAD) * len(keys)), BG)
    d = ImageDraw.Draw(out)
    for j, (_, t) in enumerate(SCREENS):
        d.text((LW + j * (W + PAD), 6), t, font=font(32), fill=CREAM)
    for i, k in enumerate(keys):
        y = HEAD + i * (H + PAD)
        words = NAMES[k].split(" - ")
        d.text((PAD, y + 8), words[0], font=font(48), fill=GOLD)
        if len(words) > 1:
            d.text((PAD, y + 56), words[1], font=font(32), fill=CREAM)
        for j, (s, _) in enumerate(SCREENS):
            out.paste(half("%s_%s.png" % (k, s), 3), (LW + j * (W + PAD), y))
    out.save(os.path.join(OUT, "ozet_hepsi.png"))


if __name__ == "__main__":
    for k in NAMES:
        sheet(k)
    overview()
    print("tamam")
