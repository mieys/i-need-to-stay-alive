"""Gök ışığı + yansıma prototip karşılaştırma sayfaları (2026-11-16, oyuna bağlı DEĞİL).

Girdi : out/kare/<etiket>_t<saat>/f_###.png (gok_isik_capture.gd, 1280x720 = oyun 1080p'nin ortası, 1 dünya px = 2 ekran px, kare = 1/12 sn)
Çıktı : out/ozet_gunduz.gif - Şu an + A/B/C öğlen (saat 150), 2x2, yarı boyut (1 dünya px = 1 piksel)
        out/ozet_gece.gif   - aynısı gece yarısı (saat 465)
        out/ozet.png        - tek kare: üst sıra gündüz, alt sıra gece (4 sütun)
        out/tek/<etiket>_t<saat>.gif - her sürüm tam boyut (oyundaki piksel boyu)
Çalıştır: python tools/proto_20261116/gok_isik/gok_isik_sayfa.py [kare_no_ozet_png]
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
KARE = os.path.join(OUT, "kare")
PROJ = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
FONT = os.path.join(PROJ, "assets", "fonts", "PixelifySans-SemiBold.ttf")
DUR = 83

TAGS = [
    ("simdi", "Şu an"),
    ("A", "A  Altın Huzme + Pırıltı"),
    ("B", "B  Gökyüzü Aynası"),
    ("C", "C  Işık Kuyusu"),
]
TIMES = [(150, "gündüz"), (465, "gece")]


def font(size):
    try:
        return ImageFont.truetype(FONT, size)
    except OSError:
        return ImageFont.load_default()


def frames(tag, saat):
    d = os.path.join(KARE, "%s_t%d" % (tag, saat))
    if not os.path.isdir(d):
        return []
    return [os.path.join(d, f) for f in sorted(os.listdir(d)) if f.endswith(".png")]


def label(img, text, f):
    dr = ImageDraw.Draw(img)
    w = dr.textlength(text, font=f)
    dr.rectangle((6, 6, 6 + w + 14, 6 + f.size + 10), fill=(24, 20, 16))
    dr.text((13, 9), text, font=f, fill=(244, 226, 180))


def to_gif(imgs, path):
    q = [im.quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE) for im in imgs]
    q[0].save(path, save_all=True, append_images=q[1:], duration=DUR, loop=0)
    print(path, len(q), "kare", os.path.getsize(path) // 1024, "KB")


def grid(saat, ad):
    seqs = [frames(t, saat) for t, _ in TAGS]
    if not all(seqs):
        return []
    n = min(len(s) for s in seqs)
    f = font(16)
    out = []
    for i in range(n):
        sheet = Image.new("RGB", (1280, 720), (20, 18, 15))
        for k, (tag, name) in enumerate(TAGS):
            im = Image.open(seqs[k][i]).convert("RGB").resize((640, 360), Image.NEAREST)
            label(im, "%s  (%s)" % (name, ad), f)
            sheet.paste(im, ((k % 2) * 640, (k // 2) * 360))
        out.append(sheet)
    return out


def still(idx):
    cw, ch = 480, 270
    sheet = Image.new("RGB", (cw * 4, ch * 2), (20, 18, 15))
    f = font(14)
    for r, (saat, ad) in enumerate(TIMES):
        for k, (tag, name) in enumerate(TAGS):
            seq = frames(tag, saat)
            if not seq:
                continue
            im = Image.open(seq[min(idx, len(seq) - 1)]).convert("RGB").resize((cw, ch), Image.LANCZOS)
            label(im, "%s (%s)" % (name, ad), f)
            sheet.paste(im, (k * cw, r * ch))
    p = os.path.join(OUT, "ozet.png")
    sheet.save(p)
    print(p)


def main():
    idx = next((int(a) for a in sys.argv[1:] if a.isdigit()), 24)
    os.makedirs(os.path.join(OUT, "tek"), exist_ok=True)
    still(idx)
    if "--sadece-png" in sys.argv:
        return
    for saat, ad in TIMES:
        g = grid(saat, ad)
        if g:
            to_gif(g, os.path.join(OUT, "ozet_%s.gif" % ("gunduz" if saat < 330 else "gece")))
        for tag, name in TAGS:
            seq = frames(tag, saat)
            if len(seq) > 1:
                f = font(22)
                imgs = []
                for p in seq:
                    im = Image.open(p).convert("RGB")
                    label(im, "%s  (%s)" % (name, ad), f)
                    imgs.append(im)
                to_gif(imgs, os.path.join(OUT, "tek", "%s_t%d.gif" % (tag, saat)))


if __name__ == "__main__":
    main()
