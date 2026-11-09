# Ateş Asası YENİ alev prototipleri: ates_alev_capture.gd karelerinden 3x2 karşılaştırma GIF'i + durağan PNG (2026-11-09).
# Çalıştır: python -I tools/proto_20261109/ates_alev_gif.py
import os, json
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "out", "ates_alev", "oyun")
OUT = os.path.join(HERE, "out", "ates_alev")
CODES = ["now", "A", "B", "C", "D"]
LABELS = {"now": "ŞU AN", "A": "A  Sakin Nefes", "B": "B  Alev Topları", "C": "C  Alev Dalgası", "D": "D  Kor Yelpazesi"}
NOTES = [
    ("A", "bugünkü koni, karakter pikselinde;", "ateş opak, uç dumana döner"),
    ("B", "ayrı alev topları (Terraria gibi);", "aralarından yaratık görünür"),
    ("C", "menzile ilerleyen ince alev", "cepheleri, en az kaplayan"),
    ("D", "kısa namlu alevi +", "menzile uçuşan kor çizgileri"),
]
HDR = 44
GAP = 6
NF = 24


def font(sz):
    for p in (r"C:\Windows\Fonts\segoeuib.ttf", r"C:\Windows\Fonts\arialbd.ttf"):
        if os.path.exists(p):
            return ImageFont.truetype(p, sz)
    return ImageFont.load_default()


F_HDR, F_TXT, F_SM = font(28), font(24), font(20)


def panel(im, label):
    p = Image.new("RGB", (im.width, im.height + HDR), (20, 14, 10))
    p.paste(im.convert("RGB"), (0, HDR))
    ImageDraw.Draw(p).text((14, 7), label, fill=(255, 226, 160), font=F_HDR)
    return p


def legend(w, h):
    p = Image.new("RGB", (w, h + HDR), (24, 18, 14))
    d = ImageDraw.Draw(p)
    d.text((14, 7), "Notlar", fill=(255, 226, 160), font=F_HDR)
    y = HDR + 14
    for code, l1, l2 in NOTES:
        d.text((16, y), code, fill=(246, 176, 98), font=F_TXT)
        d.text((48, y), l1, fill=(236, 220, 196), font=F_SM)
        d.text((48, y + 24), l2, fill=(236, 220, 196), font=F_SM)
        y += 60
    y += 6
    for line in ("A-D karakterin ALTINDA (efekt katmanı),", "ŞU AN bugünkü gibi üstte.", "Hasar, menzil, koni hepsinde aynı."):
        d.text((16, y), line, fill=(200, 186, 160), font=F_SM)
        y += 26
    return p


def build(sc):
    frames = []
    for i in range(NF):
        tiles = [panel(Image.open(os.path.join(SRC, "%s_%s_%02d.png" % (sc, c, i))), LABELS[c]) for c in CODES]
        w, h = tiles[0].size
        tiles.append(legend(w, h - HDR))
        g = Image.new("RGB", (w * 3 + GAP * 2, h * 2 + GAP), (8, 6, 4))
        for k, t in enumerate(tiles):
            g.paste(t, ((k % 3) * (w + GAP), (k // 3) * (h + GAP)))
        frames.append(g)
    frames[8].save(os.path.join(OUT, "ates_alev_%s.png" % sc))
    pal = frames[8].quantize(colors=255, method=Image.Quantize.MEDIANCUT)
    q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
    path = os.path.join(OUT, "ates_alev_%s.gif" % sc)
    # gerçek hız: çekim aralığının ortalaması (GIF 10 ms adımlı)
    tm = json.load(open(os.path.join(SRC, "zamanlar.json"), encoding="utf-8"))
    spans = [tm["%s_%s" % (sc, c)][-1] / (NF - 1) for c in CODES if "%s_%s" % (sc, c) in tm]
    dur = int(round(sum(spans) / len(spans) / 10.0)) * 10
    q[0].save(path, save_all=True, append_images=q[1:], duration=dur, loop=0, optimize=False)
    print(path, frames[0].size, dur, "ms/kare", "%.1f MB" % (os.path.getsize(path) / 1e6))


if __name__ == "__main__":
    for sc in ("sag", "asagi"):
        build(sc)
