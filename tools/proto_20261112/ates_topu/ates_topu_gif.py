# Ateş Asası ateş topu prototipleri: ates_topu_capture.gd karelerinden 2x2 karşılaştırma GIF'i + durağan özet (2026-11-12).
# Çalıştır: python -I tools/proto_20261112/ates_topu/ates_topu_gif.py
import os, json
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "out", "oyun")
OUT = os.path.join(HERE, "out")
CODES = ["A", "B", "C", "D"]
LABELS = {"A": "A  Kor Topu", "B": "B  Kuyruklu Kor", "C": "C  Dönen Kor", "D": "D  Kor Taşı"}
HDR = 40
GAP = 6
NF = 70
SCALE = 0.75


def font(sz):
    for p in (r"C:\Windows\Fonts\segoeuib.ttf", r"C:\Windows\Fonts\arialbd.ttf"):
        if os.path.exists(p):
            return ImageFont.truetype(p, sz)
    return ImageFont.load_default()


F_HDR = font(26)


def panel(im, label):
    im = im.convert("RGB")
    im = im.resize((int(im.width * SCALE), int(im.height * SCALE)), Image.NEAREST)
    p = Image.new("RGB", (im.width, im.height + HDR), (20, 14, 10))
    p.paste(im, (0, HDR))
    ImageDraw.Draw(p).text((12, 6), label, fill=(255, 226, 160), font=F_HDR)
    return p


def grid(i):
    tiles = [panel(Image.open(os.path.join(SRC, "sag_%s_%02d.png" % (c, i))), LABELS[c]) for c in CODES]
    w, h = tiles[0].size
    g = Image.new("RGB", (w * 2 + GAP, h * 2 + GAP), (8, 6, 4))
    for k, t in enumerate(tiles):
        g.paste(t, ((k % 2) * (w + GAP), (k // 2) * (h + GAP)))
    return g


def main():
    frames = [grid(i) for i in range(NF)]
    # durağan özet: her kod için top / vuruş / alevlenme anları yan yana
    picks = [6, 12, 26, 30]
    rows = []
    for c in CODES:
        row = [Image.open(os.path.join(SRC, "sag_%s_%02d.png" % (c, i))).convert("RGB") for i in picks]
        w, h = row[0].size
        r = Image.new("RGB", (w * len(row), h + HDR), (20, 14, 10))
        for k, im in enumerate(row):
            r.paste(im, (k * w, HDR))
        ImageDraw.Draw(r).text((12, 6), LABELS[c], fill=(255, 226, 160), font=F_HDR)
        rows.append(r.resize((r.width // 2, r.height // 2), Image.LANCZOS))
    s = Image.new("RGB", (rows[0].width, sum(r.height for r in rows)), (8, 6, 4))
    y = 0
    for r in rows:
        s.paste(r, (0, y))
        y += r.height
    s.save(os.path.join(OUT, "ozet.png"))
    pal = frames[20].quantize(colors=255, method=Image.Quantize.MEDIANCUT)
    q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
    path = os.path.join(OUT, "karsilastirma.gif")
    tm = json.load(open(os.path.join(SRC, "zamanlar.json"), encoding="utf-8"))
    spans = [tm["sag_" + c][-1] / (NF - 1) for c in CODES]
    dur = int(round(sum(spans) / len(spans) / 10.0)) * 10
    q[0].save(path, save_all=True, append_images=q[1:], duration=dur, loop=0, optimize=False)
    print(path, frames[0].size, dur, "ms/kare", "%.1f MB" % (os.path.getsize(path) / 1e6))


if __name__ == "__main__":
    main()
