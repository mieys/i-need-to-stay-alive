"""Gün ışığı x4 + sisli hava x3 prototip karşılaştırma sayfaları (madde 282, oyuna bağlı DEĞİL).

Girdi : out/kare/<etiket>/f_###.png (gunes_sis_capture.gd, 1280x720 = oyun 720p, 1 dünya px = 2 ekran px, kare = 1/12 sn)
Çıktı : out/gunes_ozet.gif   - Şu an + A-D (+ açıklama paneli), 3x2 ızgara, yarı boyut (1 dünya px = 1 piksel)
        out/sis_ozet.gif     - Açık (şu an) + Sis 1-3, 2x2, yarı boyut
        out/sis_gece.png     - aynısı gece (saat 465), tek kare
        out/tek/<etiket>.gif - her sürüm tam boyut (1280x720, oyundaki gibi)
Çalıştır: python tools/proto_20261019/gunes_sis/gunes_sis_sayfa.py
"""
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
KARE = os.path.join(OUT, "kare")
PROJ = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
FONT = os.path.join(PROJ, "assets", "fonts", "PixelifySans-SemiBold.ttf")
DUR = 83

GUNES = [
    ("simdi", "Şu an"),
    ("A", "A  Işık Perdesi"),
    ("B", "B  Ağaç Arası Huzme"),
    ("C", "C  Bulut Arası Güneş"),
    ("D", "D  Altın Pus"),
]
GUNES_NOT = [
    "GÜN IŞIĞI - 4 prototip (öğle, oyuncu sağa yürüyor)",
    "",
    "A  az sayıda geniş ışık perdesi, düz kademeli,",
    "   nefes alır; perdenin içinde toz zerreleri parlar",
    "B  huzme sadece ağaçların yanında: taçların",
    "   arasından sol alta süzülür, açık çayırda yok",
    "C  huzme yok: bulut arası güneş sıcak,",
    "   bulut gölgesi SERİN (mavimsi) - renk değişir",
    "D  şekil yok: havada altın pus (sağ üst),",
    "   parlak yüzeylerde sıcak parlama",
]
SIS = [
    ("acik", "Açık hava (şu an)"),
    ("S1", "Sis 1  Yer Sisi"),
    ("S2", "Sis 2  Ölü Pus"),
    ("S3", "Sis 3  Sis Perdesi + Ruh Işıkları"),
]


def font(size):
    try:
        return ImageFont.truetype(FONT, size)
    except OSError:
        return ImageFont.load_default()


def frames(tag):
    d = os.path.join(KARE, tag)
    if not os.path.isdir(d):
        return []
    return [os.path.join(d, f) for f in sorted(os.listdir(d)) if f.endswith(".png")]


def label(img, text, f):
    dr = ImageDraw.Draw(img)
    w = dr.textlength(text, font=f)
    dr.rectangle((6, 6, 6 + w + 14, 6 + f.size + 10), fill=(24, 20, 16))
    dr.text((13, 9), text, font=f, fill=(244, 226, 180))


def note_panel(size, lines, f):
    p = Image.new("RGB", size, (30, 26, 22))
    dr = ImageDraw.Draw(p)
    y = 18
    for i, ln in enumerate(lines):
        dr.text((18, y), ln, font=f, fill=(244, 226, 180) if i == 0 else (214, 204, 182))
        y += f.size + 9
    return p


def to_gif(imgs, path):
    q = [im.quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE) for im in imgs]
    q[0].save(path, save_all=True, append_images=q[1:], duration=DUR, loop=0)
    print(path, len(q), "kare", os.path.getsize(path) // 1024, "KB")


def grid(items, cols, half, note=None, frame_count=None):
    seqs = [frames(t) for t, _ in items]
    n = frame_count or min(len(s) for s in seqs if s)
    pw, ph = (640, 360) if half else (1280, 720)
    rows = (len(items) + (1 if note else 0) + cols - 1) // cols
    f = font(16 if half else 22)
    out = []
    for i in range(n):
        sheet = Image.new("RGB", (pw * cols, ph * rows), (20, 18, 15))
        for k, (tag, name) in enumerate(items):
            seq = seqs[k]
            if not seq:
                continue
            im = Image.open(seq[min(i, len(seq) - 1)]).convert("RGB")
            if half:
                im = im.resize((pw, ph), Image.NEAREST)
            label(im, name, f)
            sheet.paste(im, ((k % cols) * pw, (k // cols) * ph))
        if note:
            k = len(items)
            sheet.paste(note_panel((pw, ph), note, font(15)), ((k % cols) * pw, (k // cols) * ph))
        out.append(sheet)
    return out


def main():
    os.makedirs(os.path.join(OUT, "tek"), exist_ok=True)
    to_gif(grid(GUNES, 3, True, GUNES_NOT), os.path.join(OUT, "gunes_ozet.gif"))
    to_gif(grid(SIS, 2, True), os.path.join(OUT, "sis_ozet.gif"))
    gece = [(t + "_t465", n + "  (gece)") for t, n in SIS]
    if all(frames(t) for t, _ in gece):
        grid(gece, 2, True, frame_count=1)[0].save(os.path.join(OUT, "sis_gece.png"))
        print(os.path.join(OUT, "sis_gece.png"))
    for tag, name in GUNES + SIS:
        seq = frames(tag)
        if len(seq) > 1:
            f = font(22)
            imgs = []
            for p in seq:
                im = Image.open(p).convert("RGB")
                label(im, name, f)
                imgs.append(im)
            to_gif(imgs, os.path.join(OUT, "tek", tag + ".gif"))


if __name__ == "__main__":
    main()
