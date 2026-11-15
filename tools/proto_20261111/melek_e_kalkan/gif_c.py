"""Melek E C ailesi (baglanma noktasi) prototipi (oyuna bagli DEGIL): yakala.ps1 -Variants "c,c1,c2,c3,c4" -Tag "_c" karelerinden
out/shield_standart_c/karsilastirma.gif (C1-C4 tam sahne 2x2), yakin.gif (baglanti noktasi 3x yakin plan 2x2), ozet.png (C + C1-C4, 4 an).
Kullanim: python -I tools/proto_20261111/melek_e_kalkan/gif_c.py [shield_standart_c]
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
PROJ = ROOT.parents[2]
SRC = ROOT / "out" / (sys.argv[1] if len(sys.argv) > 1 else "shield_standart_c")
MODE = sys.argv[2] if len(sys.argv) > 2 else "c"  ## "c12": C1/C2 eski-yeni
NEW = [
    ("c1", "C1 - Bağ Halkası", "yüzeyde küçük ışık halkası, ip ortasına girer"),
    ("c2", "C2 - Işıyan Yama", "ip ucu çan ağzı, değdiği kenar mavi kalır"),
    ("c3", "C3 - Damar Saçak", "ip yüzeye kök gibi damar salar"),
    ("c4", "C4 - Sarmal Bağ", "ip iki kola ayrılıp baloncuğu sarar"),
]
OLD = ("c", "C (önceki)", "ip kenara değip duruyor")
if MODE == "c12":
    NEW = [
        ("c1", "C1 - Bağ Halkası (eski)", "küçük halka"),
        ("c1b", "C1b - Bağ Halkası (yeni)", "büyük, koyu hatlı, nefes alan halka"),
        ("c2", "C2 - Işıyan Yama (eski)", "soluk kenar"),
        ("c2b", "C2b - Işıyan Yama (yeni)", "kalın koyu hatlı şerit + içe dolum"),
    ]
    OLD = None
if MODE == "oyun":  ## madde 565: oyunun kendi bagi
    NEW = [
        ("oyun", "OYUNDA - Bağ Halkası", "E: baloncuk açık, ip baloncuğa bağlı"),
        ("oyun_e1", "OYUNDA - Kutsal Zırh (E1)", "halka + baloncuğu saran sarmal"),
    ]
    OLD = None
FONT = ImageFont.truetype(str(PROJ / "assets/fonts/m5x7.ttf"), 32)
FONT_S = ImageFont.truetype(str(PROJ / "assets/fonts/m5x7.ttf"), 16)
BG = (30, 22, 16)
INK = (242, 228, 196)
DIM = (176, 156, 124)
CAP_H = 44
PAD = 8
JOINT = (262, 92, 412, 232)  ## baglanti noktasinin cevresi (yakala.gd 520x280 kirpimi icinde)


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


def grid_gif(name, prep):
    seqs = [frames(v) for v, _, _ in NEW]
    n = min(len(s) for s in seqs)
    first = prep(Image.open(seqs[0][0]))
    pw, ph = first.size[0], first.size[1] + CAP_H
    rows_n = (len(NEW) + 1) // 2
    gw, gh = pw * 2 + PAD * 3, ph * rows_n + PAD * (rows_n + 1)
    out = []
    for i in range(n):
        g = Image.new("RGB", (gw, gh), BG)
        for k, (v, title, sub) in enumerate(NEW):
            p = panel(prep(Image.open(seqs[k][i])), title, sub)
            g.paste(p, (PAD + (k % 2) * (pw + PAD), PAD + (k // 2) * (ph + PAD)))
        out.append(g.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE))
    path = SRC / name
    out[0].save(path, save_all=True, append_images=out[1:], duration=67, loop=0, disposal=1)
    print("GIF", path, n, "kare", path.stat().st_size // 1024, "KB")


def zoom(img):
    c = img.convert("RGB").crop(JOINT)
    return c.resize((c.size[0] * 3, c.size[1] * 3), Image.NEAREST)


def main():
    grid_gif("karsilastirma.gif", lambda im: im.convert("RGB"))
    grid_gif("yakin.gif", zoom)
    rows = ([OLD] if OLD else []) + NEW
    seqs = [frames(v) for v, _, _ in rows]
    picks = [(11, "bağ kuruldu"), (14, "+0,2 sn"), (26, "dalga vardı"), (29, "+0,2 sn")]
    cw, ch = (JOINT[2] - JOINT[0]) * 2, (JOINT[3] - JOINT[1]) * 2
    lab_w = 300
    sheet = Image.new("RGB", (lab_w + len(picks) * (cw + PAD) + PAD, 34 + len(rows) * (ch + PAD) + PAD), BG)
    d = ImageDraw.Draw(sheet)
    for j, (_, txt) in enumerate(picks):
        d.text((lab_w + PAD + j * (cw + PAD), 4), txt, font=FONT, fill=DIM)
    for k, (v, title, sub) in enumerate(rows):
        y = 34 + PAD + k * (ch + PAD)
        d.text((8, y + 8), title, font=FONT, fill=INK)
        d.text((8, y + 40), sub, font=FONT_S, fill=DIM)
        for j, (fi, _) in enumerate(picks):
            im = Image.open(seqs[k][min(fi, len(seqs[k]) - 1)]).convert("RGB").crop(JOINT)
            sheet.paste(im.resize((cw, ch), Image.NEAREST), (lab_w + PAD + j * (cw + PAD), y))
    path = SRC / "ozet.png"
    sheet.save(path)
    print("OZET", path, sheet.size)


if __name__ == "__main__":
    main()
