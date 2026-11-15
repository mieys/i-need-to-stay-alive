"""Shaman E aura sınırı prototipleri (oyuna bağlı DEĞİL): aura_capture.gd karelerini birleştirir.

Kullanım: python -I tools/proto_20261111/shaman_aura/aura_gif.py [ham_klasor] [--alt kalabalik]
  ham_klasor varsayılan %TEMP%/shaman_aura_cap/oyun
Çıktı (tools/proto_20261111/shaman_aura/out/):
  karsilastirma.gif : 2x2, bütün daire (x0,45), açılış -> döngü -> sönme, 15 fps
  yakin.gif         : 2x2, geçiş noktası 1:1 (Büyücü Kız dışarıdan girer, şerit bağlanır)
  ozet.png          : sütun A-D; satırlar gündüz / gece / yakın
Renk: kare başına ortak palet, dither YOK (piksel sanatı bozulmasın).
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(HERE, "out")
FONT = os.path.join(ROOT, "assets", "fonts", "m5x7.ttf")
NAMES = {
    "A": "A - İnce Halka",
    "B": "B - Işıyan Kenar",
    "C": "C - Işık Perdesi",
    "D": "D - Köşebentler",
}
CODES = "ABCD"
GAP = 6
BAR = 40
BG = (24, 20, 16)
INK = (240, 226, 196)


def font(size):
    try:
        return ImageFont.truetype(FONT, size)
    except OSError:
        return ImageFont.load_default()


def label(img, text, size=32):
    out = Image.new("RGB", (img.width, img.height + BAR), BG)
    out.paste(img, (0, BAR))
    d = ImageDraw.Draw(out)
    d.text((10, (BAR - size) // 2 - 2), text, font=font(size), fill=INK)
    return out


def grid(cells, cols=2):
    w = max(c.width for c in cells)
    h = max(c.height for c in cells)
    rows = (len(cells) + cols - 1) // cols
    out = Image.new("RGB", (cols * w + (cols - 1) * GAP, rows * h + (rows - 1) * GAP), BG)
    for i, c in enumerate(cells):
        out.paste(c, ((i % cols) * (w + GAP), (i // cols) * (h + GAP)))
    return out


def frames_of(src, code, kind):
    out = []
    i = 0
    while True:
        p = os.path.join(src, "%s_%s_%03d.png" % (code, kind, i))
        if not os.path.exists(p):
            break
        out.append(p)
        i += 1
    return out


def save_gif(frames, path, ms):
    """Ortak 255 renk palet (birkaç karenin mozaiğinden) + önceki kareyle AYNI pikseller saydam indeks (255), disposal=1:
    zemin durağan olduğu için LZW çok daha iyi sıkışır (kare başı palet 40 MB veriyordu)."""
    import numpy as np
    picks = [frames[i] for i in sorted({0, len(frames) // 3, len(frames) // 2, 2 * len(frames) // 3, len(frames) - 1})]
    w, h = frames[0].size
    mosaic = Image.new("RGB", (w, h * len(picks)))
    for i, f in enumerate(picks):
        mosaic.paste(f, (0, i * h))
    pal_img = mosaic.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    palette = pal_img.getpalette()[: 255 * 3] + [0, 0, 0]
    out = []
    prev = None
    for f in frames:
        q = np.array(f.quantize(palette=pal_img, dither=Image.Dither.NONE), dtype=np.uint8)
        show = q.copy()
        if prev is not None:
            show[q == prev] = 255
        prev = q
        im = Image.fromarray(show, "P")
        im.putpalette(palette)
        im.info["transparency"] = 255
        out.append(im)
    out[0].save(path, save_all=True, append_images=out[1:], duration=ms, loop=0, optimize=False, disposal=1, transparency=255)
    print("yazildi", path, "%.1f MB" % (os.path.getsize(path) / 1e6), len(frames), "kare")


def build_gif(src, kind, path, scale=1.0, step=1):
    lists = {c: frames_of(src, c, kind) for c in CODES}
    n = min(len(v) for v in lists.values())
    if n == 0:
        print("kare yok:", kind)
        return
    frames = []
    for i in range(0, n, step):
        cells = []
        for c in CODES:
            im = Image.open(lists[c][i]).convert("RGB")
            if scale != 1.0:
                im = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
            cells.append(label(im, NAMES[c]))
        frames.append(grid(cells))
    save_gif(frames, path, 66 * step)


def fit(im, w):
    k = w / im.width
    return im.resize((w, round(im.height * k)), Image.LANCZOS)


def build_summary(src, path):
    col_w = 560
    rows = [("gündüz", "%s_tam_dongu.png"), ("gece", "gece_%s.png"), ("yakın 1:1", "%s_y_040.png")]
    cols = []
    for c in CODES:
        parts = []
        for title, pat in rows:
            p = os.path.join(src, pat % c)
            if not os.path.exists(p):
                continue
            im = Image.open(p).convert("RGB")
            im = fit(im, col_w) if im.width > col_w else im
            parts.append(label(im, "%s  %s" % (NAMES[c], title), 28))
        if parts:
            h = sum(x.height for x in parts) + GAP * (len(parts) - 1)
            col = Image.new("RGB", (col_w, h), BG)
            y = 0
            for x in parts:
                col.paste(x, (0, y))
                y += x.height + GAP
            cols.append(col)
    if cols:
        grid(cols, cols=len(cols)).save(path)
        print("yazildi", path)


MAPS = [
    ("ana", "Ana harita"),
    ("bataklik", "Kara Bataklık"),
    ("col", "Altın Kumlar"),
    ("batik_nekropol", "Batık Nekropol"),
    ("lagim_agi", "Lağım Ağı"),
    ("kalabalik", "Ana harita - savaşta"),
]


def build_game(base):
    """OYUNA ALINAN sınır (kod OYUN), harita başına bir çekim (aura_run.ps1 -Sub <harita> -Env "AU_CODES=OYUN;HARITA=<harita>")."""
    have = [(sub, name) for sub, name in MAPS if os.path.exists(os.path.join(base, sub, "OYUN_g_000.png"))]
    if not have:
        print("oyun karesi yok")
        return
    lists = {sub: frames_of(os.path.join(base, sub), "OYUN", "g") for sub, _ in have}
    n = min(len(v) for v in lists.values())
    frames = []
    for i in range(n):
        cells = [label(Image.open(lists[sub][i]).convert("RGB"), name) for sub, name in have]
        frames.append(grid(cells, cols=3))
    save_gif(frames, os.path.join(OUT, "oyunda.gif"), 66)
    cells = []
    for sub, name in have:
        p = os.path.join(base, sub, "OYUN_tam_dongu.png")
        if os.path.exists(p):
            cells.append(label(fit(Image.open(p).convert("RGB"), 560), name, 28))
    night = os.path.join(base, "ana", "gece_OYUN.png")
    if os.path.exists(night):
        cells.append(label(fit(Image.open(night).convert("RGB"), 560), "Ana harita - gece", 28))
    close = os.path.join(base, "ana", "OYUN_y_040.png")
    if os.path.exists(close):
        cells.append(label(Image.open(close).convert("RGB"), "yakın 1:1 - sınırı geçiş", 28))
    grid(cells, cols=4).save(os.path.join(OUT, "ozet_oyun.png"))
    print("yazildi", os.path.join(OUT, "ozet_oyun.png"))


def main():
    if "--oyun" in sys.argv:
        os.makedirs(OUT, exist_ok=True)
        build_game(os.path.join(os.environ.get("TEMP", "."), "shaman_aura_cap"))
        return
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    alt = ""
    if "--alt" in sys.argv:
        alt = sys.argv[sys.argv.index("--alt") + 1]
        args = [a for a in args if a != alt]
    sub = alt or "oyun"
    src = args[0] if args else os.path.join(os.environ.get("TEMP", "."), "shaman_aura_cap", sub)
    os.makedirs(OUT, exist_ok=True)
    tag = ("_" + alt) if alt else ""
    build_gif(src, "g", os.path.join(OUT, "karsilastirma%s.gif" % tag))
    build_gif(src, "y", os.path.join(OUT, "yakin%s.gif" % tag))
    build_summary(src, os.path.join(OUT, "ozet%s.png" % tag))


if __name__ == "__main__":
    main()
