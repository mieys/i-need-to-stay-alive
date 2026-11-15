"""Sovalye E "Koruma Bariyeri" prototipi (oyuna bagli DEGIL): yakala.ps1 karelerinden
out/karsilastirma.gif (SU AN + A-D, 15 fps, ortak palet, dither YOK) + out/ozet.png (secenek basina 4 an, Buyucu Kiz 3x)
+ out/yakin_<v>.gif (tek secenek, dostun cevresi 3x).
Kullanim: python -I tools/proto_20261111/sovalye_bariyer/gif.py
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
PROJ = ROOT.parents[2]
SRC = ROOT / "out" / "kareler"
OUT = ROOT / "out"
VARIANTS = [
    ("suan", "ŞU AN", "iki eğik şerit + dither'li baloncuk"),
    ("a", "A - Dönen Kalkanlar", "belde dönen 3 haçlı kalkan"),
    ("b", "B - Işık Sütunları", "ayak halkasında dönen 4 sütun"),
    ("c", "C - Kutsal Mühür", "ayakta dönen mühür + yükselen zerre"),
    ("d", "D - Kristal Kabuk", "dönen köşeli kristal küre"),
]
VARIANT_SETS = {
    "": VARIANTS,
    "a": [
        ("a", "A (ilk tur)", "düz şablon kalkan, 12 fps"),
        ("a1", "A1 - Çelik Kalkan", "3B bombeli çelik, gölge, 20 fps"),
        ("a2", "A2 - Işık Kalkanı", "yarı saydam ışık + kurdele + parıltı"),
        ("a3", "A3 - Altın Haç", "A1 + altın kenar ve haç"),
        ("a4", "A4 - Kalkan Çemberi", "A1 + belde ışık çemberi"),
    ],
    "buyu": [
        ("a", "A (ilk tur)", "düz şablon kalkan, 12 fps"),
        ("a5", "A5 - Işık Kuyruğu", "hale + kuyruklu iz + dökülen parıltı"),
        ("a6", "A6 - Ruh Alevi", "alev dilleri + alevli iz + korlar"),
        ("a7", "A7 - Yıldız Tozu", "göz kırpan yıldız tozu kuşağı"),
        ("a8", "A8 - Koruma Nabzı", "yayılan dalga, kalkanlar parlar"),
    ],
    "oyun": [
        ("oyun", "OYUNDA - A5 Işık Kuyruğu", "kısa iz, yerde ışık yok (oyunun betiği)"),
    ],
}
SET = sys.argv[1] if len(sys.argv) > 1 else ""
VARIANTS = VARIANT_SETS[SET]
SUFFIX = ("_" + SET) if SET else ""
FONT = ImageFont.truetype(str(PROJ / "assets/fonts/m5x7.ttf"), 32)
FONT_S = ImageFont.truetype(str(PROJ / "assets/fonts/m5x7.ttf"), 16)
BG = (30, 22, 16)
INK = (242, 228, 196)
DIM = (176, 156, 124)
CAP_H = 44
PAD = 8


def frames(v):
    return sorted((SRC / v).glob("f_*.png"))


def panel(img, title, sub):
    w, h = img.size
    out = Image.new("RGB", (w, h + CAP_H), BG)
    out.paste(img.convert("RGB"), (0, CAP_H))
    d = ImageDraw.Draw(out)
    d.text((8, 0), title, font=FONT, fill=INK)
    d.text((8, 26), sub, font=FONT_S, fill=DIM)
    return out


def save_gif(frames_rgb, path, ms):
    """Ortak palet (tum karelerden), dither YOK - kare basi 256 renk kaymasi olmasin (madde 564 ek 4)."""
    probe = Image.new("RGB", (frames_rgb[0].width, frames_rgb[0].height * 4))
    for j, k in enumerate(range(0, len(frames_rgb), max(1, len(frames_rgb) // 4))):
        if j < 4:
            probe.paste(frames_rgb[k], (0, j * frames_rgb[0].height))
    pal = probe.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in frames_rgb]
    q[0].save(path, save_all=True, append_images=q[1:], duration=ms, loop=0, disposal=1)
    print("GIF", path, len(q), "kare", path.stat().st_size // 1024, "KB")


def main():
    seqs = [frames(v) for v, _, _ in VARIANTS]
    n = min(len(s) for s in seqs)
    w, h = Image.open(seqs[0][0]).size
    pw, ph = w, h + CAP_H
    cols = 2
    rows = (len(VARIANTS) + 1) // cols
    gw, gh = pw * cols + PAD * (cols + 1), ph * rows + PAD * (rows + 1)
    out_frames = []
    for i in range(n):
        g = Image.new("RGB", (gw, gh), BG)
        for k, (v, title, sub) in enumerate(VARIANTS):
            p = panel(Image.open(seqs[k][i]), title, sub)
            g.paste(p, (PAD + (k % cols) * (pw + PAD), PAD + (k // cols) * (ph + PAD)))
        d = ImageDraw.Draw(g)
        lx, ly = PAD + (pw + PAD) + 12, PAD + (rows - 1) * (ph + PAD) + 20
        for j, txt in enumerate(["Şovalye E - Koruma Bariyeri", "yalnız dostun etrafındaki bariyer",
                                 "oyun ölçeği (zoom 2), gerçek çizici", "0,3 sn açılış, 4 sn kapanış"]):
            d.text((lx, ly + j * 30), txt, font=FONT if j == 0 else FONT_S, fill=INK if j == 0 else DIM)
        out_frames.append(g)
    save_gif(out_frames, OUT / f"karsilastirma{SUFFIX}.gif", 67)

    ## yakin: Buyucu Kiz (sag dost) cevresi 3x, secenek basina ayri GIF
    ax = w // 2 + int(round(60 * 8 / 3))  ## sag dost (Buyucu): 60 dunya px, 2,67 ekran px/dunya
    crop = (ax - 76, 12, ax + 76, h - 4)
    cw, ch = crop[2] - crop[0], crop[3] - crop[1]
    sc = 3
    for k, (v, title, sub) in enumerate(VARIANTS):
        fr = [panel(Image.open(seqs[k][i]).convert("RGB").crop(crop).resize((cw * sc, ch * sc), Image.NEAREST), title, sub)
              for i in range(n)]
        save_gif(fr, OUT / f"yakin_{v}.gif", 67)
    ## A ailesi: hepsi yan yana yakin (3x) tek GIF
    if SET:
        pw2 = cw * sc
        strip = []
        for i in range(n):
            g = Image.new("RGB", (len(VARIANTS) * (pw2 + PAD) + PAD, ch * sc + CAP_H + 2 * PAD), BG)
            for k, (v, title, sub) in enumerate(VARIANTS):
                im = Image.open(seqs[k][i]).convert("RGB").crop(crop).resize((pw2, ch * sc), Image.NEAREST)
                g.paste(panel(im, title, sub), (PAD + k * (pw2 + PAD), PAD))
            strip.append(g)
        save_gif(strip, OUT / f"yakin_hepsi{SUFFIX}.gif", 67)

    ## ozet: secenek basina 4 an
    picks = [(7, "açılış"), (30, "döngü"), (40, "döngü +0,7 sn"), (62, "kapanış")]
    lab_w = 250
    sheet = Image.new("RGB", (lab_w + len(picks) * (cw * sc + PAD) + PAD, 34 + len(VARIANTS) * (ch * sc + PAD) + PAD), BG)
    d = ImageDraw.Draw(sheet)
    for j, (fi, txt) in enumerate(picks):
        d.text((lab_w + PAD + j * (cw * sc + PAD), 2), txt, font=FONT, fill=DIM)
    for k, (v, title, sub) in enumerate(VARIANTS):
        y = 34 + PAD + k * (ch * sc + PAD)
        d.text((8, y + 8), title, font=FONT, fill=INK)
        d.text((8, y + 40), sub, font=FONT_S, fill=DIM)
        for j, (fi, _) in enumerate(picks):
            im = Image.open(seqs[k][min(fi, n - 1)]).convert("RGB").crop(crop).resize((cw * sc, ch * sc), Image.NEAREST)
            sheet.paste(im, (lab_w + PAD + j * (cw * sc + PAD), y))
    sheet.save(OUT / f"ozet{SUFFIX}.png")
    print("OZET", OUT / f"ozet{SUFFIX}.png", sheet.size)


if __name__ == "__main__":
    main()
